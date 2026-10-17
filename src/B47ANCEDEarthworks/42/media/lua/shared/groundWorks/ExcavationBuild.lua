local API=require 'groundWorks/API'
local Hand=require 'groundWorks/HandTools'
local Presets=require 'groundWorks/ExcavationPresets'
local Terrain=require 'groundWorks/CavityTerrain'
local Build={SUPPORT_KEY='groundWorks.support.v1',WALL_KEY='groundWorks.boundary.v1'}
local function call(o,m,...)
    if not o then return nil end
    local ok,f=pcall(function()return o[m]end)
    if ok and type(f)=='function'then local ran,v=pcall(f,o,...);if ran then return v end end
end
local function key(x,y,z)return x..':'..y..':'..z end
function Build.plan(spec)return Presets.plan(spec)end
function Build.isInside(player)
    local square=call(player,'getCurrentSquare')
    if not square or math.floor(call(player,'getZ')or 0)>=0 then return false end
    local receipt=API.Cavity and API.Cavity.inspect(square)
    return receipt and receipt.status=='created'and receipt.role=='cavity'
        and (receipt.volumeType=='groundWorks.trench'or receipt.volumeType=='groundWorks.moat'or receipt.volumeType=='groundWorks.basement')
        and square:getFloor()~=nil and receipt.sealed~=true or false
end
function Build.inventory(player,includeGround)
    local result={};local queue={call(player,'getInventory')};local seen={};local count=0
    local index=1
    while index<=#queue and index<=64 do
        local container=queue[index];index=index+1
        if container and not seen[container]then
            seen[container]=true;local items=container:getItems()
            for i=0,items:size()-1 do
                count=count+1;if count>4096 then return result end
                local item=items:get(i);local id=item:getFullType()
                result[id]=result[id]or{};result[id][#result[id]+1]=item
                local nested=call(item,'getInventory');if nested and #queue<64 then queue[#queue+1]=nested end
            end
        end
    end
    if includeGround then
        local anchor=call(player,'getCurrentSquare')
        if anchor then for x=anchor:getX()-1,anchor:getX()+1 do for y=anchor:getY()-1,anchor:getY()+1 do
            local square=getCell():getGridSquare(x,y,anchor:getZ())
            if square and(not SafeHouse or SafeHouse.isSafehouseAllowInteract(square,player))then
                local objects=call(square,'getWorldObjects')
                if objects then for i=0,objects:size()-1 do
                    local item=call(objects:get(i),'getItem');local id=call(item,'getFullType')
                    if id=='Base.Plank'or id=='Base.Nails'then
                        count=count+1;if count>4096 then return result end
                        result[id]=result[id]or{};result[id][#result[id]+1]=item
                    end
                end end
            end
        end end end
    end
    return result
end
-- Loose framing supplies on an already excavated floor survive enlargement;
-- new excavation still protects every placed item on its future floor.
function Build.isLooseSupply(object)
    local item=call(object,'getItem')
    local id=call(item,'getFullType')
    return (id=='Base.Plank'or id=='Base.Nails')and call(item,'getWorldItem')==object
end
function Build.isOwnedBoundary(object)
    local md=call(object,'getModData')
    return type(md)=='table'and type(md[Build.WALL_KEY])=='table'
end
function Build.edgeFrame(edge)
    local square=getCell():getGridSquare(edge.x,edge.y,edge.z)
    if not square then return nil end
    local objects=square:getObjects()
    for i=0,objects:size()-1 do
        local object=objects:get(i);local md=object:getModData()[Build.WALL_KEY]
        if md and md.kind=='frame'and md.north==edge.north and(call(object,'getHealth')or 1)>0 then return object end
    end
end
function Build.isSecured(square)
    local md=square and square:getModData()[Build.SUPPORT_KEY]
    if not md or md.secured~=true or type(md.edges)~='table'then return false end
    for _,edge in ipairs(md.edges)do if not Build.edgeFrame(edge)then return false end end
    return true
end
function Build.clearSquare(square,actor,allowManagedFloor)
    if not square then return true end
    if square:getRoom()or square:getBuilding()then return false,'Existing underground rooms are protected.'end
    local objects=square:getObjects()
    local receipt=API.Cavity and API.Cavity.inspect(square)
    for i=0,objects:size()-1 do
        local object=objects:get(i)
        local ownFloor=allowManagedFloor and object==square:getFloor()and receipt and receipt.status=='created'
        local supply=allowManagedFloor and receipt and receipt.status=='created'and Build.isLooseSupply(object)
        if not ownFloor and not supply and not Terrain.isUndergroundObject(object)and not Build.isOwnedBoundary(object)then
            return false,'The footprint contains an existing floor, item, or placed object.'
        end
    end
    for _,getter in ipairs({'getMovingObjects','getStaticMovingObjects'})do
        local list=call(square,getter)
        if list then for i=0,list:size()-1 do if list:get(i)~=actor then return false,'Clear occupants and bodies from the footprint.'end end end
    end
    return true
end
function Build.check(player,spec,options)
    local plan,reason=Build.plan(spec)
    if not plan then return false,reason end
    options=options or{}
    local details={plan=plan,materials={},duration=1,missingLayers=0,frames=0,edges={}}
    local function reject(message)return false,message,details end
    if not Hand.enabled()or not player or call(player,'isDead')or(not options.machine and call(player,'getVehicle'))then return reject('An active builder on foot is required.')end
    if not options.machine and not Build.isInside(player)then return reject('Enter a groundWorks trench, moat, or basement to open construction.')end
    local pz=math.floor(player:getZ());local px,py=math.floor(player:getX()),math.floor(player:getY())
    if options.machine and(pz~=0 or not call(player,'getVehicle')or math.abs(px-spec.x)>12 or math.abs(py-spec.y)>12)then return reject('Operate a compatible machine within 12 tiles of the ground-level footprint.')end
    if not options.machine and(pz~=spec.z or px~=spec.x or py~=spec.y)then return reject('Stand on the preview anchor tile inside the excavation.')end
    local tool=Hand.findTool(player);details.tool=tool
    local cell=getCell();local depth=-spec.z
    local store=API.EarthworkPersistence and API.EarthworkPersistence.getStore()
    if not store then return reject('Earthwork records have not loaded yet.')end
    local opened={};local footprint={}
    for _,target in ipairs(plan.cells)do footprint[target.x..':'..target.y]=true end
    for _,target in ipairs(plan.cells)do
        local surface=cell:getGridSquare(target.x,target.y,0)
        if not surface or not surface:getChunk()then return reject('Every surface tile in the footprint must be loaded.')end
        if SafeHouse and not SafeHouse.isSafehouseAllowInteract(surface,player)then return reject('You cannot build in this safehouse.')end
        local receipt=API.Cavity.inspect(surface)
        local existing=receipt and receipt.status=='created'and receipt.sealed~=true
        local job=API.EarthworkJobs.jobAtCell(store,target.x,target.y,0)
        if existing then
            if receipt.volumeType~=plan.volumeType then return reject('This footprint overlaps a different excavation type.')end
            if not job or job.status~='excavated'then return reject('Finish existing excavation work before framing.')end
            local fill=job.fill or{}
            if (fill.soil or 0)+(fill.concrete or 0)+(fill.water or 0)+(fill.fuel or 0)>0 then return reject('Drain or empty the footprint before construction.')end
            if receipt.targetDepth~=depth then return reject('Existing columns must have the same depth as the builder.')end
            opened[key(target.x,target.y,spec.z)]=true
        else
            if job then return reject('The footprint contains another reserved project.')end
            if receipt and receipt.status~='clear'then return reject('An excavation in this footprint requires inspection.')end
            local preserveSurface=plan.volumeType=='groundWorks.basement'and(surface:getRoom()~=nil or surface:getBuilding()~=nil)
            if not surface:getFloor()or(not preserveSurface and not surface:isFree(false))then return reject('Clear the ground-floor footprint first.')end
            local allowed,why=API.validateVolume(plan.volumeType,{square=surface,actor=player})
            if not allowed then return reject(why)end
            details.missingLayers=details.missingLayers+depth
        end
        for z=-1,spec.z,-1 do
            local square=cell:getGridSquare(target.x,target.y,z)
            local clear,why=Build.clearSquare(square,player,existing)
            if not clear then return reject(why)end
            if square then for i=0,square:getObjects():size()-1 do
                local object=square:getObjects():get(i);local wall=object:getModData()[Build.WALL_KEY]
                if wall and wall.kind=='frame'then
                    local nx,ny=target.x-(wall.north and 0 or 1),target.y-(wall.north and 1 or 0)
                    if footprint[nx..':'..ny]then return reject('Dismantle the old internal framing before joining these spaces.')end
                end
            end end
        end
    end
    -- Every depth gets a perimeter; costs use exactly the edges the server stamps.
    for z=-1,spec.z,-1 do
        for _,edge in ipairs(plan.edges)do
            local e={x=edge.x,y=edge.y,z=z,north=edge.north}
            details.edges[#details.edges+1]=e
            local sq=cell:getGridSquare(e.x,e.y,z)
            local ownerSurface=cell:getGridSquare(e.x,e.y,0)
            if not ownerSurface or not ownerSurface:getChunk()then return reject('Every perimeter owner square must be loaded.')end
            if SafeHouse and not SafeHouse.isSafehouseAllowInteract(ownerSurface,player)then return reject('A perimeter frame would enter a protected safehouse.')end
            if sq then
                if sq:getRoom()or sq:getBuilding()then return reject('A perimeter frame would enter an existing underground room.')end
                for _,getter in ipairs({'getMovingObjects','getStaticMovingObjects'})do
                    local list=call(sq,getter)
                    if list then for i=0,list:size()-1 do if list:get(i)~=player then return reject('Clear occupants from every perimeter frame.')end end end
                end
                local objects=sq:getObjects()
                for i=0,objects:size()-1 do
                    local object=objects:get(i)
                    local receipt=API.Cavity.inspect(sq)
                    local supply=receipt and receipt.status=='created'and receipt.role=='cavity'and Build.isLooseSupply(object)
                    if not supply and not Terrain.isUndergroundObject(object)and not Build.isOwnedBoundary(object)and object~=sq:getFloor()then
                        return reject('An existing object blocks a perimeter frame.')
                    end
                end
            end
            if not Build.edgeFrame(e)then details.frames=details.frames+1 end
        end
    end
    details.materials={['Base.Plank']=details.frames*2,['Base.Nails']=details.frames*2}
    details.duration=math.max(20,math.ceil(details.missingLayers*(tool and tool.maxTime or 80)*Hand.WORK_REQUIRED/(tool and tool.work or 10)+details.frames*20))
    if options.machine then return true,details end
    if not tool then return reject('Carry a shovel, pickaxe, or other suitable digging tool.')end
    local inventory=Build.inventory(player,true);details.inventory=inventory
    local hammer
    for id,items in pairs(inventory)do
        for _,item in ipairs(items)do
            local known=id=='Base.Hammer'or id=='Base.BallPeenHammer'or id=='Base.HammerStone'
            local tag=not known and ItemTag and ItemTag.HAMMER and call(item,'hasTag',ItemTag.HAMMER)
            if(call(item,'getCondition')or 0)>0 and(known or tag)then hammer=item;break end
        end
        if hammer then break end
    end
    details.hammer=hammer
    if details.frames>0 and not hammer then return reject('Carry a usable hammer to build the wooden framing.')end
    for id,count in pairs(details.materials)do
        if #(inventory[id]or{})<count then return reject('Need '..count..' '..(id=='Base.Plank'and'planks'or'loose nails')..' for this footprint.')end
    end
    return true,details
end
API.ExcavationBuild=Build
return Build
