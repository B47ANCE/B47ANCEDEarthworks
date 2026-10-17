local API=require "groundWorks/Load"
local Cavity=API.Cavity
local Jobs=API.EarthworkJobs
local Persistence=API.EarthworkPersistence
local Engine=require "groundWorks/CavityEngine"
local Observer={installed=false,TICK_INTERVAL=10,MAX_OBJECTS=64,tick=0,seen={}}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...);if called then return result end
end
local function canWrite()
    return not(type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))
end
local function isType(object,name)
    local predicate=rawget(_G,"instanceof")
    if type(predicate)~="function"or not object then return false end
    local ok,result=pcall(predicate,object,name)
    return ok and result==true
end
local function corpseItem(item)
    if not item then return false end
    local ok,result=pcall(function()
        if type(item.isCorpse)=="function"and item:isCorpse()==true then return true end
        local full=type(item.getFullType)=="function"and tostring(item:getFullType())or""
        return full:find("Corpse",1,true)~=nil
    end)
    return ok and result==true
end
local function squareAt(x,y,z)
    local getter=rawget(_G,"getCell")
    if type(getter)~="function"then return nil end
    local ok,cell=pcall(getter);if not ok or not cell then return nil end
    return call(cell,"getGridSquare",x,y,z)
end
local function collect(square)
    local result={}
    local function addAll(list)
        local size=list and call(list,"size")or 0
        size=math.max(0,math.min(Observer.MAX_OBJECTS,math.floor(tonumber(size)or 0)))
        for index=0,size-1 do
            local object=call(list,"get",index)
            if object then result[#result+1]=object end
        end
    end
    addAll(call(square,"getWorldObjects"))
    addAll(call(square,"getStaticMovingObjects"))
    addAll(call(square,"getDeadBodys"))
    addAll(call(square,"getDeadBodies"))
    return result
end
local function identity(object)
    return tostring(object)
end
local function restoreItem(opening,item)
    if not item then return end
    call(opening,"AddWorldInventoryItem",item,0.5,0.5,0)
end
local function relocateItem(opening,cavity,object)
    local item=call(object,"getItem")
    if not item then return false,"world item has no inventory item"end
    if isServer()then call(opening,"transmitRemoveItemFromSquare",object)end
    if not isServer()then call(opening,"RemoveTileObject",object)end
    call(item,"setWorldItem",nil)
    local world=call(cavity,"AddWorldInventoryItem",item,0.5,0.5,0)
    if not world then
        restoreItem(opening,item)
        return false,"cavity rejected world item; restored to opening"
    end
    return true,"item"
end
local function relocateBody(opening,cavity,object)
    local x,y,z=call(cavity,"getX"),call(cavity,"getY"),call(cavity,"getZ")
    x,y,z=tonumber(x),tonumber(y),tonumber(z)
    if not x or not y or not z then return false,"cavity coordinates unavailable"end
    local ok=pcall(function()
        opening:removeCorpse(object,false)
        object:setX(x+0.5);object:setY(y+0.5);object:setZ(z)
        if type(object.setLx)=="function"then object:setLx(x+0.5);object:setLy(y+0.5);object:setLz(z)end
        if type(object.setCurrentSquare)=="function"then object:setCurrentSquare(cavity)end
        if type(object.setSquare)=="function"then object:setSquare(cavity)end
        cavity:addCorpse(object,false)
    end)
    if not ok then return false,"corpse relocate raised"end
    local nowZ=tonumber(call(object,"getZ"))
    local nowSquare=call(object,"getSquare")
    if nowZ~=z and nowSquare~=cavity then return false,"corpse remained on the opening"end
    return true,"body"
end
local function classify(object)
    if isType(object,"IsoDeadBody")then return"body",object end
    if isType(object,"IsoWorldInventoryObject")then
        local item=call(object,"getItem")
        if corpseItem(item)then return"body",object end
        return"item",object
    end
    return nil
end
local function depositLedger(record,media)
    local store=Persistence.getStore()
    if not store or type(record.jobId)~="string"then return true,0 end
    local age=rawget(_G,"getGameTime")
    local worldAge=0
    if type(age)=="function"then
        local ok,time=pcall(age)
        worldAge=ok and time and call(time,"getWorldAgeHours")or 0
    end
    local operationId=string.format("deposit:%s:%s:%d:%.3f",tostring(record.jobId),media,Observer.seq or 0,tonumber(worldAge)or 0)
    Observer.seq=(Observer.seq or 0)+1
    local ok,result=Jobs.deposit(store,record.jobId,media,1,operationId,"groundWorks.cavity.manual.v1",{source="opening"})
    if ok==true then
        if Persistence and type(rawget(_G,"ModData"))=="table"and isServer()and ModData.transmit then
            pcall(ModData.transmit,Persistence.STORE_KEY)
        end
        return true,(type(result)=="table"and result.accepted)or 1
    end
    return false,result
end

function Observer.scan()
    if not canWrite()then return end
    for _,record in ipairs(Cavity.listOpenings())do
        local opening=squareAt(record.x,record.y,0)
        local cavity=squareAt(record.cavityX or record.x,record.cavityY or record.y,record.cavityZ or-1)
        if opening and cavity and not call(opening,"getFloor")and record.sealed~=true and record.surfaceCap~="sealed"then
            local key=tostring(record.x)..":"..tostring(record.y)
            Observer.seen[key]={}
            local occupancy=type(record.occupancy)=="table"and record.occupancy or{}
            for _,object in ipairs(collect(opening))do
                local id=identity(object)
                if not Observer.seen[key][id]then
                    local media=classify(object)
                    if media=="item"and occupancy.receiveItems~=false then
                        local moved,moveErr=relocateItem(opening,cavity,object)
                        if moved then
                            Observer.seen[key][id]=true
                            depositLedger(record,"item")
                        else print("[groundWorks][CavityDeposit] item stayed on opening: "..tostring(moveErr))end
                    elseif media=="body"and occupancy.receiveBodies==true then
                        local moved,moveErr
                        if isType(object,"IsoDeadBody")then moved,moveErr=relocateBody(opening,cavity,object)
                        else moved,moveErr=relocateItem(opening,cavity,object)end
                        if moved then
                            Observer.seen[key][id]=true
                            depositLedger(record,"body")
                        else print("[groundWorks][CavityDeposit] corpse stayed on opening: "..tostring(moveErr))end
                    elseif media then
                        Observer.seen[key][id]=true
                    end
                end
            end
        end
        if opening and cavity and record.jobId then
            local store=Persistence.getStore()
            local job=store and store.jobs[record.jobId]
            if job and job.occupants then
                local items,bodies=0,0
                local seen={}
                local receipt=Cavity.inspect(opening)
                for _,location in ipairs(receipt.cells or{})do
                    local sq=squareAt(location.x,location.y,location.z)
                    if sq then for _,object in ipairs(collect(sq))do
                        if not seen[object]then
                            seen[object]=true
                            local media=classify(object)
                            if media=="item"then items=items+1 elseif media=="body"then bodies=bodies+1 end
                        end
                    end end
                end
                if job.occupants.items~=items or job.occupants.bodies~=bodies then
                    job.occupants.items=items;job.occupants.bodies=bodies
                    if isServer()then ModData.transmit(Persistence.STORE_KEY)end
                end
            end
        end
    end
end

function Observer.install(events)
    if Observer.installed then return true end
    if not events then return false,"events required"end
    if events.OnTick and type(events.OnTick.Add)=="function"then
        events.OnTick.Add(function()
            Observer.tick=Observer.tick+1
            if Observer.tick<Observer.TICK_INTERVAL then return end
            Observer.tick=0
            Observer.scan()
        end)
    else return false,"OnTick unavailable"end
    if events.LoadGridsquare and type(events.LoadGridsquare.Add)=="function"then
        events.LoadGridsquare.Add(function(square)
            if not square or call(square,"getZ")~=0 then return end
            local receipt=Cavity.inspect(square)
            if type(receipt)=="table"and receipt.status=="created"and receipt.sealed~=true and receipt.surfaceCap~="sealed"
                and(receipt.role=="opening"or receipt.openingTagged==true or receipt.opening)then
                local x,y=call(square,"getX"),call(square,"getY")
                local cavity=type(receipt.cavity)=="table"and receipt.cavity or{}
                Cavity.registerOpening({
                    x=x,y=y,z=0,cavityX=cavity.x or x,cavityY=cavity.y or y,cavityZ=receipt.fillFloorZ or cavity.z or receipt.targetDepth and-(receipt.targetDepth)or-1,
                    operationId=receipt.operationId,jobId=receipt.jobId,volumeType=receipt.volumeType,
                    occupancy=receipt.occupancy,surfaceCap=receipt.surfaceCap,targetDepth=receipt.targetDepth,sealed=false,
                    shaft=true,
                })
                if canWrite()then pcall(Cavity.ensureLiveShaft,square,Engine.adapter())end
            end
        end)
    end
    Observer.installed=true
    return true
end

return Observer
