local groundWorks=require "groundWorks/API"
local VolumeTypes=require "groundWorks/VolumeTypes"
local Experiment=require "groundWorks/ExcavationExperiment"
local Cavity={
    ROOT_KEY="groundWorks.cavity.v1",OPENING_KEY="groundWorks.cavity.opening.v1",
    SCHEMA_VERSION=1,FLOOR_SPRITE=Experiment.FLOOR_SPRITE,MAX_OPENINGS=1024,LIVE_MAX_DEPTH=VolumeTypes.MAX_DEPTH,
    OPENING_SPRITE="blends_natural_01_64",
    FILL_SPRITES={
        water={"blends_natural_02_0","blends_natural_02_4","floors_interior_tilesandwood_01_19"},
        concrete={"floors_construction_01_0","floors_interior_tilesandwood_01_7","carpentry_02_56"},
        fuel={"floors_burnt_01_0","floors_burnt_01_1","blends_natural_01_80"},
        soil={"blends_natural_01_64","blends_natural_01_80"},
    },
}
local openings={}
local openingCount=0

local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function call(object,method,...)
    if not object then return nil,false end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil,false end
    local called,result=pcall(fn,object,...);return result,called
end
local function coordinate(square,method)
    local value,ok=call(square,method);value=ok and finite(value)or nil
    return value and value==math.floor(value)and value or nil
end
local function canWrite()
    return not(type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))
end
local function operation(value)return type(value)=="string"and value~=""and#value<=128 end
local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,child in pairs(value)do result[copy(key,seen)]=copy(child,seen)end
    seen[value]=nil;return result
end
local function data(square)
    local result,ok=call(square,"getModData")
    return ok and type(result)=="table"and result or nil,"surface square ModData unavailable"
end
local function transmit(square)call(square,"transmitModdata")end
local function cellKey(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
local function adapterValid(adapter)
    if type(adapter)~="table"then return false end
    for _,name in ipairs({"validateSprite","isValidSquare","getSquare","createSquare","connectSquare","addFloor","tagObject","recalculate","transmitObject","verify","tagOpening","verifyOpening","untagOpening"})do
        if type(adapter[name])~="function"then return false end
    end
    return true
end
local function volumeOf(options)
    options=type(options)=="table"and options or{}
    local definition=VolumeTypes.get(options.volumeType or"groundWorks.openPit")
    if not definition or definition.liveGeometry~=true then return nil,"live cavity volume type required"end
    return definition
end
local function liveDepth(definition,options)
    local requested=finite(options and options.targetDepth)or 1
    if requested~=math.floor(requested)then requested=1 end
    local maxDepth=math.min(Cavity.LIVE_MAX_DEPTH,definition and definition.maxDepth or 1)
    if requested<1 then requested=1 end
    if requested>maxDepth then requested=maxDepth end
    return requested
end
local function pickSprite(names)
    if type(getSprite)~="function"then return nil end
    for _,name in ipairs(names or{})do
        local sprite=getSprite(name)
        if sprite~=nil then return name end
    end
end
local function rollbackCreated(created,adapter)
    local rolled=true
    for index=#(created or{}),1,-1 do
        local entry=created[index]
        if entry and entry.object and type(adapter.removeObject)=="function"then
            local ok,result=pcall(adapter.removeObject,entry.square,entry.object)
            rolled=rolled and ok and result==true
        end
    end
    return rolled
end
local function setFailure(surface,receipt,reason,created,adapter,openingTagged)
    receipt.status="failed";receipt.reason=tostring(reason or"cavity transaction failed"):sub(1,256)
    receipt.rollbackAttempted=#(created or{})>0 or openingTagged==true;receipt.objectRolledBack=false;receipt.openingRolledBack=false
    if openingTagged and type(adapter.untagOpening)=="function"then
        local ok,result=pcall(adapter.untagOpening,surface)
        receipt.openingRolledBack=ok and result==true
    end
    receipt.objectRolledBack=rollbackCreated(created,adapter)
    receipt.requiresInspection=#(created or{})>0 or(receipt.rollbackAttempted and not receipt.objectRolledBack)or(openingTagged and not receipt.openingRolledBack)
    receipt.topologyUncertain=#(created or{})>0
    transmit(surface)
    return false,receipt.requiresInspection and"cavity excavation requires inspection"or receipt.reason,copy(receipt)
end

function Cavity.liveEnabled()
    if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then return true end
    local root=rawget(_G,"SandboxVars")
    local settings=type(root)=="table"and root.groundWorks or nil
    return type(settings)=="table"and settings.EnableLiveOpenPit==true
end

function Cavity.plan(surface,options)
    local definition,err=volumeOf(options)
    if not definition then return nil,err end
    local x,y,z=coordinate(surface,"getX"),coordinate(surface,"getY"),coordinate(surface,"getZ")
    if not x or not y or not z then return nil,"integer surface coordinates required"end
    if z~=0 then return nil,"live cavity requires z=0 surface"end
    local depth=liveDepth(definition,options)
    local cells={}
    for level=-1,-depth,-1 do cells[#cells+1]={x=x,y=y,z=level}end
    return{
        schemaVersion=1,volumeType=definition.id,jobType=definition.jobType,
        surface={x=x,y=y,z=z},opening={x=x,y=y,z=0},cavity={x=x,y=y,z=-depth},
        cells=cells,floorSprite=Cavity.FLOOR_SPRITE,openingSprite=Cavity.OPENING_SPRITE,targetDepth=depth,
        preserveSurface=definition.id=='groundWorks.basement'and options and options.preserveSurface==true or false,
        occupancy=copy(definition.occupancy),surfaceCap=definition.surfaceCap,fillMedia=copy(definition.fillMedia),
    }
end

function Cavity.inspect(square)
    local root,err=data(square);if not root then return nil,err end
    local receipt=root[Cavity.ROOT_KEY]or root[Cavity.OPENING_KEY]or root[Experiment.ROOT_KEY]
    if receipt==nil then return{status="clear",requiresInspection=false}end
    if type(receipt)~="table"or receipt.schemaVersion~=1 then return{status="unsupported",requiresInspection=true}end
    return copy(receipt)
end

function Cavity.openingRecord(square)
    local receipt=Cavity.inspect(square)
    if type(receipt)~="table"or receipt.status~="created"then return nil end
    if receipt.role~="opening"and receipt.opening==nil and not receipt.openingTagged then return nil end
    return receipt
end

function Cavity.registerOpening(record)
    if type(record)~="table"then return false,"opening record required"end
    local x,y=finite(record.x),finite(record.y)
    if not x or not y then return false,"opening coordinates required"end
    local key=cellKey(math.floor(x),math.floor(y),0)
    if openings[key]then openings[key]=copy(record);return true,openings[key]end
    if openingCount>=Cavity.MAX_OPENINGS then return false,"opening bound reached"end
    openings[key]=copy(record);openingCount=openingCount+1
    return true,openings[key]
end

function Cavity.unregisterOpening(x,y)
    local key=cellKey(math.floor(tonumber(x)or 0),math.floor(tonumber(y)or 0),0)
    if openings[key]then openings[key]=nil;openingCount=math.max(0,openingCount-1);return true end
    return false
end

function Cavity.listOpenings()
    local result={}
    for _,record in pairs(openings)do result[#result+1]=copy(record)end
    table.sort(result,function(a,b)
        if a.y==b.y then return(a.x or 0)<(b.x or 0)end
        return(a.y or 0)<(b.y or 0)
    end)
    return result
end

function Cavity.getOpening(x,y)
    return copy(openings[cellKey(math.floor(tonumber(x)or 0),math.floor(tonumber(y)or 0),0)])
end

function Cavity.climbDestination(square)
    local x,y,z=coordinate(square,"getX"),coordinate(square,"getY"),coordinate(square,"getZ")
    if not x or not y or not z then return nil,"integer square coordinates required"end
    local receipt=Cavity.inspect(square)
    if type(receipt)~="table"or receipt.status~="created"then return nil,"no live cavity on this square"end
    if receipt.sealed==true or receipt.surfaceCap=="sealed"then return nil,"this volume is sealed"end
    local depth=finite(receipt.targetDepth)or 1
    local opening=receipt.opening or receipt.surface or{x=x,y=y,z=0}
    local cavity=receipt.cavity or{x=x,y=y,z=-depth}
    local bottom=finite(receipt.fillFloorZ)or finite(cavity.z)or-depth
    if z==0 then
        if call(square,"getFloor")then return nil,"the excavation is covered; use its stairs or access opening"end
        return{x=cavity.x or x,y=cavity.y or y,z=bottom,direction="down",volumeType=receipt.volumeType}
    end
    if z<=0 and z>=bottom then
        return{x=opening.x or x,y=opening.y or y,z=0,direction="up",volumeType=receipt.volumeType}
    end
    return nil,"climb is only inside this cavity column"
end

function Cavity.climbLanding(square,adapter)
    local destination,err=Cavity.climbDestination(square)
    if not destination then return nil,err end
    if type(adapter)~="table"or type(adapter.getSquare)~="function"then return destination end
    local target=adapter.getSquare(destination.x,destination.y,destination.z)
    if destination.direction=="up"then
        local x,y=destination.x,destination.y
        for _,offset in ipairs({{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}})do
            local neighbor=adapter.getSquare(x+offset[1],y+offset[2],0)
            if neighbor and call(neighbor,"getFloor")and call(neighbor,"isFree",false)~=false then
                destination={x=x+offset[1],y=y+offset[2],z=0,direction="up",volumeType=destination.volumeType}
                target=neighbor
                break
            end
        end
        if not target or not call(target,"getFloor")or call(target,"isFree",false)==false then return nil,"no clear landing beside the opening"end
    end
    return destination,nil,target
end

function Cavity.climbFromPlayer(player,adapter)
    if call(player,"isDead")==true or call(player,"getVehicle")then return nil,"active survivor on foot required"end
    local square=call(player,"getCurrentSquare")
    if square and (coordinate(square,"getZ")or 1)>0 then return nil,"climb from the excavation level"end
    if square then
        local destination,err,target=Cavity.climbLanding(square,adapter)
        if destination then return destination,nil,target end
    end
    if not square then return nil,"integer square coordinates required"end
    if type(adapter)~="table"or type(adapter.getSquare)~="function"then return nil,"no live cavity on this square"end
    local x,y=coordinate(square,"getX"),coordinate(square,"getY")
    if not x or not y then return nil,"integer square coordinates required"end
    for _,offset in ipairs({{0,0},{1,0},{-1,0},{0,1},{0,-1},{1,1},{1,-1},{-1,1},{-1,-1}})do
        local record=Cavity.getOpening(x+offset[1],y+offset[2])
        if record and record.sealed~=true then
            local opening=adapter.getSquare(x+offset[1],y+offset[2],0)
            if opening then
                local destination,err,target=Cavity.climbLanding(opening,adapter)
                if destination then return destination,nil,target end
            end
        end
    end
    return nil,"no live cavity on this square"
end

function Cavity.verifyCurrent(surface,adapter)
    if type(adapter)~="table"or type(adapter.getSquare)~="function"or type(adapter.verify)~="function"then
        return nil,"inspection adapter required"
    end
    local receipt,err=Cavity.inspect(surface);if not receipt then return nil,err end
    if receipt.status~="created"or type(receipt.cells)~="table"or type(receipt.cells[1])~="table"then
        return{status=receipt.status,geometryResolved=false,requiresInspection=receipt.requiresInspection==true}
    end
    local target=receipt.cells[#receipt.cells]or receipt.cells[1]
    local plan=Cavity.plan(surface,{volumeType=receipt.volumeType,targetDepth=receipt.targetDepth})
    if not plan or not target or target.x~=plan.cavity.x or target.y~=plan.cavity.y or target.z~=plan.cavity.z
        or not operation(receipt.operationId)then
        return{status="unsupported",geometryResolved=false,requiresInspection=true}
    end
    local resolved,square=pcall(adapter.getSquare,target.x,target.y,target.z)
    if not resolved then return{status=receipt.status,geometryResolved=false,requiresInspection=true,reason="square lookup failed"}end
    local floor=square and call(square,"getFloor")or nil
    local checked,verified=true,false
    if square and floor then checked,verified=pcall(adapter.verify,target.x,target.y,target.z,square,floor,receipt.operationId)end
    local openingOk=true
    if type(adapter.verifyOpening)=="function"then
        local openingChecked,openingVerified=pcall(adapter.verifyOpening,surface,receipt.operationId)
        openingOk=openingChecked and openingVerified==true
    end
    local ok=checked and verified==true and openingOk
    return{status=receipt.status,operationId=receipt.operationId,geometryResolved=ok,openingResolved=openingOk,
        squareResolved=square~=nil,floorResolved=floor~=nil,requiresInspection=receipt.requiresInspection==true or not ok,
        volumeType=receipt.volumeType,jobId=receipt.jobId}
end

function Cavity.geometryReceipt(plan,operationId,jobId,mode,outcome)
    if type(plan)~="table"or type(plan.surface)~="table"or type(plan.cavity)~="table"then return nil,"cavity plan required"end
    local surfaceKey=cellKey(plan.surface.x,plan.surface.y,0)
    local undergroundKey=cellKey(plan.cavity.x,plan.cavity.y,plan.cavity.z)
    return{
        schemaVersion=1,operationId=operationId,jobId=jobId,mode=mode or"excavate",outcome=outcome,
        verified=outcome=="committed"or outcome=="rolled_back",targetDepth=plan.targetDepth or 1,
        cells={{surfaceKey=surfaceKey,undergroundKey=undergroundKey,openingKey=surfaceKey,cavityKey=undergroundKey,verified=true}},
    }
end

function Cavity.execute(surface,operationId,adapter,options)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    if not adapterValid(adapter)then return false,"complete cavity adapter required"end
    local definition,volumeErr=volumeOf(options)
    if not definition then return false,volumeErr end
    local root,err=data(surface);if not root then return false,err end
    local existing=root[Cavity.ROOT_KEY]or root[Experiment.ROOT_KEY]
    if existing~=nil then
        local snapshot=Cavity.inspect(surface)
        if type(snapshot)=="table"and snapshot.operationId==operationId and snapshot.status=="created"then
            snapshot.duplicate=true;return true,snapshot
        end
        if type(snapshot)=="table"and snapshot.status=="failed"and snapshot.requiresInspection~=true then
            root[Cavity.ROOT_KEY]=nil;root[Experiment.ROOT_KEY]=nil
        else
            return false,"surface already has a cavity receipt",snapshot
        end
    end
    local allowed,reason=VolumeTypes.validate(definition.id,{square=surface,actor=options and options.actor})
    if not allowed then return false,reason end
    local surfaceState,surfaceErr=groundWorks.inspectSurface(surface)
    if not surfaceState then return false,surfaceErr end
    if surfaceState.water or(not surfaceState.natural and definition.id~="groundWorks.basement")then return false,"pristine natural surface required"end
    local plan,planErr=Cavity.plan(surface,options);if not plan then return false,planErr end
    local checked,preflight,preflightReason=pcall(function()
        if adapter.validateSprite(plan.floorSprite)~=true then return false,"cavity floor sprite unavailable"end
        if type(adapter.validateSurface)=="function"then
            local surfaceAllowed,surfaceReason=adapter.validateSurface(surface,copy(plan))
            if surfaceAllowed~=true then return false,surfaceReason or"surface preflight rejected"end
        end
        for _,target in ipairs(plan.cells)do
            if adapter.isValidSquare(target.x,target.y,target.z)~=true then return false,"negative-Z target is not valid"end
            local existingSquare=adapter.getSquare(target.x,target.y,target.z)
            if existingSquare and not(type(adapter.isEmptySquare)=="function"and adapter.isEmptySquare(existingSquare)==true)then return false,"negative-Z target already exists"end
        end
        return true
    end)
    if not checked then return false,"cavity preflight lookup failed"end
    if preflight~=true then return false,tostring(preflightReason):sub(1,256)end

    local jobId=options and operation(options.jobId)and options.jobId or nil
    local receipt={schemaVersion=1,operationId=operationId,jobId=jobId,status="creating",requiresInspection=false,
        volumeType=definition.id,role="opening",surface=copy(plan.surface),opening=copy(plan.opening),cavity=copy(plan.cavity),
        cells=copy(plan.cells),floorSprite=plan.floorSprite,openingSprite=plan.openingSprite,openingTagged=false,
        preserveSurface=plan.preserveSurface,
        experimental=options and options.experimental==true or false,occupancy=copy(plan.occupancy),
        surfaceCap=plan.surfaceCap,fillMedia=copy(plan.fillMedia),targetDepth=plan.targetDepth,sealed=false,burning=false,shaft=true}
    root[Cavity.ROOT_KEY]=receipt
    root[Experiment.ROOT_KEY]={schemaVersion=1,operationId=operationId,status="creating",requiresInspection=false,
        surface=copy(plan.surface),cells=copy(plan.cells),floorSprite=plan.floorSprite,experimental=receipt.experimental}
    transmit(surface)
    local created,openingTagged={},false
    local ok,result=pcall(function()
        for _,target in ipairs(plan.cells)do
            local createdSquare=adapter.getSquare(target.x,target.y,target.z)or assert(adapter.createSquare(target.x,target.y,target.z),"square creation returned nil")
            assert(adapter.connectSquare(createdSquare)==true,"square connection failed")
            local createdObject=assert(adapter.addFloor(createdSquare,plan.floorSprite),"floor creation returned nil")
            created[#created+1]={square=createdSquare,object=createdObject,cell=target}
            assert(adapter.tagObject(createdObject,operationId)==true,"floor ownership tagging failed")
            assert(adapter.recalculate(createdSquare)==true,"square recalculation failed")
            assert(adapter.transmitObject(createdObject)==true,"floor transmission failed")
            assert(adapter.verify(target.x,target.y,target.z,createdSquare,createdObject,operationId)==true,"local verification failed")
            local cavityData=data(createdSquare)
            if cavityData then
                cavityData[Cavity.ROOT_KEY]={schemaVersion=1,operationId=operationId,jobId=jobId,status="created",
                    role=target.z==plan.cavity.z and"cavity"or"shaft",volumeType=definition.id,opening=copy(plan.opening),
                    cavity=copy(plan.cavity),targetDepth=plan.targetDepth,occupancy=copy(plan.occupancy),surfaceCap=plan.surfaceCap}
                transmit(createdSquare)
            end
            if target.z~=plan.cavity.z and type(adapter.openToSky)=="function"then
                assert(adapter.openToSky(createdSquare)==true,"shaft opening failed")
            end
        end
        receipt.openingSprite=plan.openingSprite
        openingTagged=true
        assert(adapter.tagOpening(surface,operationId,copy(receipt))==true,"opening tagging failed")
        assert(adapter.verifyOpening(surface,operationId)==true,"opening verification failed")
        return true
    end)
    if not ok or result~=true then return setFailure(surface,receipt,ok and"cavity transaction failed"or result,created,adapter,openingTagged)end
    receipt.status="created";receipt.requiresInspection=false;receipt.topologyUncertain=false;receipt.verifiedLocal=true;receipt.openingTagged=true
    root[Experiment.ROOT_KEY].status="created";root[Experiment.ROOT_KEY].requiresInspection=false
    root[Experiment.ROOT_KEY].verifiedLocal=true
    Cavity.registerOpening({x=plan.surface.x,y=plan.surface.y,z=0,cavityX=plan.cavity.x,cavityY=plan.cavity.y,cavityZ=plan.cavity.z,
        operationId=operationId,jobId=jobId,volumeType=definition.id,occupancy=copy(plan.occupancy),
        surfaceCap=plan.surfaceCap,targetDepth=plan.targetDepth,sealed=false,shaft=true})
    if type(adapter.finalizeCavity)=='function'then
        local finished,why=adapter.finalizeCavity(surface)
        if not finished then receipt.requiresInspection=true;receipt.reason=tostring(why);transmit(surface);return false,receipt.reason,copy(receipt)end
    end
    transmit(surface);return true,copy(receipt)
end

local function listObjects(square,getter)
    local result={}
    local list=call(square,getter)
    local size=math.max(0,math.floor(tonumber((call(list,"size")))or 0))
    for index=0,size-1 do
        local object=call(list,"get",index)
        if object then result[#result+1]=object end
    end
    return result
end

local function relocateColumn(from,to,adapter)
    if not from or not to or from==to then return end
    local tx,ty,tz=coordinate(to,"getX"),coordinate(to,"getY"),coordinate(to,"getZ")
    if not tx or not ty or not tz then return end
    for _,object in ipairs(listObjects(from,"getMovingObjects"))do
        if type(adapter.movePlayer)=="function"then pcall(adapter.movePlayer,object,to)
        else
            pcall(function()
                object:setX(tx+0.5);object:setY(ty+0.5);object:setZ(tz)
                if type(object.setLx)=="function"then object:setLx(tx+0.5);object:setLy(ty+0.5);object:setLz(tz)end
                if type(object.setCurrentSquare)=="function"then object:setCurrentSquare(to)end
            end)
        end
    end
    for _,getter in ipairs({"getDeadBodys","getDeadBodies"})do
        for _,object in ipairs(listObjects(from,getter))do
            pcall(function()
                object:setX(tx+0.5);object:setY(ty+0.5);object:setZ(tz)
                if type(object.setLx)=="function"then object:setLx(tx+0.5);object:setLy(ty+0.5);object:setLz(tz)end
                if type(object.setCurrentSquare)=="function"then object:setCurrentSquare(to)end
                if type(object.setSquare)=="function"then object:setSquare(to)end
            end)
        end
    end
    for _,object in ipairs(listObjects(from,"getWorldObjects"))do
        local item=call(object,"getItem")
        if item then
            if type(rawget(_G,"isServer"))=="function"and isServer()then call(from,"transmitRemoveItemFromSquare",object)end
            call(from,"RemoveTileObject",object)
            call(item,"setWorldItem",nil)
            call(to,"AddWorldInventoryItem",item,0.5,0.5,0)
        end
    end
end

local function writeColumnReceipt(square,payload)
    local root=data(square)
    if not root then return end
    root[Cavity.ROOT_KEY]=payload
    transmit(square)
end

function Cavity.ensureLiveShaft(surface,adapter)
    if not canWrite()then return false,"non-authority"end
    if type(adapter)~="table"or type(adapter.openToSky)~="function"then return false,"shaft adapter required"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"or receipt.sealed==true or receipt.surfaceCap=="sealed"then
        return false,"live cavity required"
    end
    -- Opening removal is performed during the transaction and saved by the game.
    -- Never remove a floor a player subsequently built over the cavity.
    if type(receipt.cells)=="table"and type(adapter.getSquare)=="function"then
        local bottom=receipt.cavity and finite(receipt.cavity.z)
        for _,cell in ipairs(receipt.cells)do
            if type(cell)=="table"and cell.z~=bottom then
                local square=adapter.getSquare(cell.x,cell.y,cell.z)
                if not square then return false,"shaft square is not loaded"end
            end
        end
    end
    return true
end

function Cavity.deepen(surface,operationId,adapter,options)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    if not adapterValid(adapter)then return false,"complete cavity adapter required"end
    if type(adapter.openToSky)~="function"then return false,"shaft adapter required"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"then return false,"live cavity required"end
    if receipt.sealed==true or receipt.surfaceCap=="sealed"then return false,"this volume is sealed"end
    if Cavity.hasContents(surface,adapter,options and options.actor)then return false,"remove other occupants before deepening"end
    -- A player may replace the bottom or add an intermediate floor after the
    -- excavation. Deepening must never open those unrelated constructions.
    for _,location in ipairs(receipt.cells or{})do
        local square=adapter.getSquare(location.x,location.y,location.z)
        local floor=square and call(square,'getFloor')
        if floor then
            local marker=call(floor,'getModData')
            marker=marker and(marker[Cavity.ROOT_KEY]or marker[Experiment.ROOT_KEY])
            if not marker or marker.operationId~=receipt.operationId then
                return false,'Dismantle the player-built floor inside this column before deepening.'
            end
        end
    end
    local definition=VolumeTypes.get(receipt.volumeType or(options and options.volumeType))
    local currentDepth=finite(receipt.targetDepth)or 1
    local maxDepth=math.min(Cavity.LIVE_MAX_DEPTH,definition and definition.maxDepth or 1)
    if currentDepth>=maxDepth then return false,"volume type does not allow that depth"end
    local nextDepth=currentDepth+1
    local x=receipt.opening and finite(receipt.opening.x)or coordinate(surface,"getX")
    local y=receipt.opening and finite(receipt.opening.y)or coordinate(surface,"getY")
    if not x or not y then return false,"opening coordinates required"end
    local newZ=-nextDepth
    local oldCavity=receipt.cavity or{x=x,y=y,z=-currentDepth}
    local plan={
        surface=copy(receipt.surface)or{x=x,y=y,z=0},
        opening=copy(receipt.opening)or{x=x,y=y,z=0},
        cavity={x=oldCavity.x or x,y=oldCavity.y or y,z=newZ},
        floorSprite=receipt.floorSprite or Cavity.FLOOR_SPRITE,
        occupancy=copy(receipt.occupancy),surfaceCap=receipt.surfaceCap,targetDepth=nextDepth,
    }
    local cells=type(receipt.cells)=="table"and copy(receipt.cells)or{}
    local hasCell=false
    for _,cell in ipairs(cells)do if type(cell)=="table"and cell.x==x and cell.y==y and cell.z==newZ then hasCell=true end end
    local checked,preflight,preflightReason=pcall(function()
        if adapter.validateSprite(plan.floorSprite)~=true then return false,"cavity floor sprite unavailable"end
        if adapter.isValidSquare(x,y,newZ)~=true then return false,"negative-Z target is not valid"end
        local existing=adapter.getSquare(x,y,newZ)
        if existing~=nil and not hasCell then
            local existingData=data(existing)
            local marker=existingData and(existingData[Cavity.ROOT_KEY]or existingData[Experiment.ROOT_KEY])or nil
            if (type(marker)~="table"or marker.operationId~=receipt.operationId)
                and not(type(adapter.isEmptySquare)=="function"and adapter.isEmptySquare(existing)==true)then
                return false,"negative-Z target already exists"
            end
        end
        return true
    end)
    if not checked then return false,"cavity deepen preflight lookup failed"end
    if preflight~=true then return false,tostring(preflightReason):sub(1,256)end

    local created,createdSquare={},nil
    local oldSquare=type(adapter.getSquare)=="function"and adapter.getSquare(oldCavity.x or x,oldCavity.y or y,oldCavity.z or-currentDepth)or nil
    local ok,result=pcall(function()
        local square=adapter.getSquare(x,y,newZ)
        if not square then
            square=assert(adapter.createSquare(x,y,newZ),"square creation returned nil")
            assert(adapter.connectSquare(square)==true,"square connection failed")
            local floor=assert(adapter.addFloor(square,plan.floorSprite),"floor creation returned nil")
            created[#created+1]={square=square,object=floor}
            assert(adapter.tagObject(floor,receipt.operationId)==true,"floor ownership tagging failed")
            assert(adapter.recalculate(square)==true,"square recalculation failed")
            assert(adapter.transmitObject(floor)==true,"floor transmission failed")
            assert(adapter.verify(x,y,newZ,square,floor,receipt.operationId)==true,"local verification failed")
            createdSquare=square
        else
            createdSquare=square
            local floor=call(square,"getFloor")
            if not floor then
                floor=assert(adapter.addFloor(square,plan.floorSprite),"floor creation returned nil")
                assert(adapter.tagObject(floor,receipt.operationId)==true,"floor ownership tagging failed")
                assert(adapter.recalculate(square)==true,"square recalculation failed")
                assert(adapter.transmitObject(floor)==true,"floor transmission failed")
            end
        end
        if oldSquare and oldSquare~=createdSquare then
            relocateColumn(oldSquare,createdSquare,adapter)
            assert(adapter.openToSky(oldSquare)==true,"old cavity could not open into the shaft")
        end
        return true
    end)
    if not ok or result~=true then
        rollbackCreated(created,adapter)
        return false,tostring(ok and"cavity deepen failed"or result):sub(1,256)
    end

    if not hasCell then cells[#cells+1]={x=x,y=y,z=newZ}end
    local columnPayload={
        schemaVersion=1,operationId=receipt.operationId,jobId=receipt.jobId,status="created",
        volumeType=receipt.volumeType,opening=copy(plan.opening),cavity=copy(plan.cavity),
        targetDepth=nextDepth,occupancy=copy(plan.occupancy),surfaceCap=plan.surfaceCap,shaft=true,
    }
    for _,cell in ipairs(cells)do
        local square=adapter.getSquare(cell.x,cell.y,cell.z)
        if square then
            local payload=copy(columnPayload)
            payload.role=cell.z==newZ and"cavity"or"shaft"
            writeColumnReceipt(square,payload)
            if cell.z~=newZ then pcall(adapter.openToSky,square)end
        end
    end
    local root=data(surface)
    if root and type(root[Cavity.ROOT_KEY])=="table"then
        local live=root[Cavity.ROOT_KEY]
        live.cells=cells;live.cavity=copy(plan.cavity);live.targetDepth=nextDepth;live.shaft=true;live.sealed=false
        live.openingTagged=true
    end
    Cavity.registerOpening({x=x,y=y,z=0,cavityX=plan.cavity.x,cavityY=plan.cavity.y,cavityZ=plan.cavity.z,
        operationId=receipt.operationId,jobId=receipt.jobId,volumeType=receipt.volumeType,occupancy=copy(plan.occupancy),
        surfaceCap=plan.surfaceCap,targetDepth=nextDepth,sealed=false,shaft=true})
    -- The access was opened during initial excavation. Deepening changes only
    -- the lower floor; preserve a house ceiling or any later player-built cover.
    if type(adapter.finalizeCavity)=='function'then
        local finished,why=adapter.finalizeCavity(surface)
        if not finished then return false,'New floor created; perimeter needs inspection: '..tostring(why)end
    end
    transmit(surface)
    return true,Cavity.inspect(surface)
end

local function cavityFloor(adapter,receipt)
    if type(adapter)~="table"or type(adapter.getSquare)~="function"or type(receipt)~="table"or type(receipt.cavity)~="table"then return nil end
    return adapter.getSquare(receipt.cavity.x,receipt.cavity.y,receipt.cavity.z)
end

function Cavity.hasContents(surface,adapter,ignoredActor)
    local receipt=Cavity.inspect(surface)
    if not receipt or not receipt.cells then return false end
    local grid=type(getCell)=="function"and getCell()or nil
    local players={}
    if type(getOnlinePlayers)=="function"then
        local online=getOnlinePlayers()
        for index=0,(tonumber((call(online,"size")))or 0)-1 do players[#players+1]=call(online,"get",index)end
    end
    if type(getNumActivePlayers)=="function"and type(getSpecificPlayer)=="function"then
        for index=0,getNumActivePlayers()-1 do players[#players+1]=getSpecificPlayer(index)end
    end
    for _,cell in ipairs(receipt.cells)do
        for _,player in ipairs(players)do
            if player~=ignoredActor and math.floor(tonumber((call(player,"getX")))or 0)==cell.x
                and math.floor(tonumber((call(player,"getY")))or 0)==cell.y
                and math.floor(tonumber((call(player,"getZ")))or 0)==cell.z then return true end
        end
        local square=adapter and adapter.getSquare(cell.x,cell.y,cell.z)
            or grid and call(grid,"getGridSquare",cell.x,cell.y,cell.z)
        if not square then return true end
        local placed=call(square,"getObjects")
        for index=0,(tonumber((call(placed,"size")))or 0)-1 do
            local object=call(placed,"get",index)
            local md=object and call(object,'getModData')
            local boundary=type(md)=='table'and md['groundWorks.boundary.v1']
            local terrain=groundWorks.CavityTerrain
            if object~=call(square,"getFloor")and not boundary
                and not(terrain and terrain.isUndergroundObject(object))then return true end
        end
        for _,getter in ipairs({"getMovingObjects","getStaticMovingObjects","getWorldObjects"})do
            local objects=call(square,getter)
            local size=tonumber((call(objects,"size")))or 0
            for index=0,size-1 do
                if call(objects,"get",index)~=ignoredActor then return true end
            end
        end
    end
    return false
end

function Cavity.applyFill(surface,adapter,job)
    if not canWrite()then return false,"non-authority"end
    if not adapterValid(adapter)and(type(adapter)~="table"or type(adapter.getSquare)~="function")then return false,"cavity adapter required"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"then return false,"live cavity required"end
    local fill=type(job)=="table"and type(job.fill)=="table"and job.fill or{}
    local best,amount="none",0
    for _,media in ipairs({"concrete","water","fuel","soil"})do
        local value=tonumber(fill[media])or 0
        if value>amount then best,amount=media,value end
    end
    if amount<=0 then return true,receipt end
    local sprite=pickSprite(Cavity.FILL_SPRITES[best])
    local square=cavityFloor(adapter,receipt)
    local depth=tonumber(receipt.targetDepth)or 1
    local capacity=tonumber(job and job.soilVolume)or depth
    local solid=(tonumber(fill.concrete)or 0)+(tonumber(fill.soil)or 0)
    local levels=math.min(depth-1,math.floor(solid/(capacity/depth)))
    if levels>0 then
        local standingZ=-depth+levels
        square=adapter.getSquare(receipt.cavity.x,receipt.cavity.y,standingZ)
        if not square then return false,"fill level is not loaded"end
        local existing=call(square,"getFloor")
        if not existing then
            existing=adapter.addFloor(square,sprite or receipt.floorSprite)
            if not existing or adapter.tagObject(existing,receipt.operationId)~=true then return false,"fill floor creation failed"end
            if adapter.recalculate(square)~=true or adapter.transmitObject(existing)~=true then return false,"fill floor update failed"end
        end
        local root=data(surface)
        root[Cavity.ROOT_KEY].fillFloorZ=standingZ
        receipt.fillFloorZ=standingZ
        local opening=Cavity.getOpening(receipt.surface.x,receipt.surface.y)
        if opening then opening.cavityZ=standingZ;Cavity.registerOpening(opening)end
    end
    local floor=square and call(square,"getFloor")
    if sprite and floor and type(adapter.setFloorSprite)=="function"then
        if adapter.setFloorSprite(floor,sprite)~=true then return false,"fill sprite update failed"end
    end
    receipt.fillVisual=best
    local root=data(surface)
    if root and root[Cavity.ROOT_KEY]then root[Cavity.ROOT_KEY].fillVisual=best;transmit(surface)end
    return true,copy(receipt)
end

function Cavity.seal(surface,adapter,job)
    if not canWrite()then return false,"non-authority"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"then return false,"live cavity required"end
    if Cavity.hasContents(surface,adapter)then return false,"cavity still has occupants"end
    local applied,applyErr=Cavity.applyFill(surface,adapter,job or{fill={concrete=1}})
    if not applied then return false,applyErr end
    if type(adapter.restoreFloor)=="function"and adapter.restoreFloor(surface)~=true then return false,"surface restoration failed"end
    local sprite=pickSprite(Cavity.FILL_SPRITES.concrete)or Cavity.OPENING_SPRITE
    local floor=call(surface,"getFloor")
    if not floor and type(adapter.addFloor)=="function"then
        pcall(adapter.addFloor,surface,sprite)
        floor=call(surface,"getFloor")
    end
    if floor and not receipt.preserveSurface and type(adapter.setFloorSprite)=="function"then pcall(adapter.setFloorSprite,floor,sprite)end
    if not floor then return false,"surface floor missing"end
    local root=data(surface)
    if root and type(root[Cavity.ROOT_KEY])=="table"then
        root[Cavity.ROOT_KEY].sealed=true;root[Cavity.ROOT_KEY].surfaceCap="sealed"
        root[Cavity.ROOT_KEY].occupancy={stand=false,receiveItems=false,receiveBodies=false,receiveFluids=false,ignite=false,pourSolid=false}
    end
    Cavity.unregisterOpening(receipt.surface and receipt.surface.x or call(surface,"getX"),receipt.surface and receipt.surface.y or call(surface,"getY"))
    transmit(surface)
    return true
end

function Cavity.close(surface,adapter)
    if not canWrite()then return false,"non-authority"end
    local receipt=Cavity.inspect(surface)
    if receipt and receipt.collapsed==true then return false,'Collapsed contents are preserved below the capped surface.'end
    if type(receipt)~="table"or(receipt.status~="created"and receipt.status~="failed")then return false,"live cavity required"end
    if Cavity.hasContents(surface,adapter)then return false,"cavity still has occupants"end
    for _,location in ipairs(receipt.cells or{})do
        local square=adapter.getSquare(location.x,location.y,location.z)
        local floor=square and call(square,"getFloor")
        if floor then
            local marker=call(floor,"getModData")
            marker=marker and(marker[Cavity.ROOT_KEY]or marker[Experiment.ROOT_KEY])
            if not marker or marker.operationId~=receipt.operationId then return false,"unowned floor in cavity"end
        end
    end
    if type(adapter.untagOpening)~="function"or adapter.untagOpening(surface)~=true then return false,"surface restoration failed"end
    if type(adapter.clearBoundaries)=='function'and adapter.clearBoundaries(surface)~=true then return false,'perimeter cleanup failed'end
    if type(receipt.cells)=="table"and type(adapter.getSquare)=="function"and type(adapter.removeObject)=="function"then
        for index=#receipt.cells,1,-1 do
            local cell=receipt.cells[index]
            local square=adapter.getSquare(cell.x,cell.y,cell.z)
            local floor=square and call(square,"getFloor")
            if square and floor then
                local marker=call(floor,"getModData")
                marker=marker and(marker[Cavity.ROOT_KEY]or marker[Experiment.ROOT_KEY])
                if not marker or marker.operationId~=receipt.operationId then return false,"unowned floor in cavity"end
                if adapter.removeObject(square,floor)~=true then return false,"cavity floor removal failed"end
            end
            local squareData=square and data(square)
            if squareData then
                squareData[Cavity.ROOT_KEY]=nil;squareData[Experiment.ROOT_KEY]=nil
                squareData.groundWorksOpeningSprite=nil;squareData.groundWorksFloorRemoved=nil
                squareData['groundWorks.support.v1']=nil
                transmit(square)
            end
        end
    end
    local root=data(surface)
    if root then root[Cavity.ROOT_KEY]=nil;root[Experiment.ROOT_KEY]=nil end
    Cavity.unregisterOpening(receipt.surface and receipt.surface.x or call(surface,"getX"),receipt.surface and receipt.surface.y or call(surface,"getY"))
    if type(adapter.finalizeClosure)=='function'then
        local checked,finished,why=pcall(adapter.finalizeClosure,surface)
        if not checked or finished~=true then
            receipt.status='failed';receipt.requiresInspection=true
            receipt.reason='Neighbor perimeter restoration failed: '..tostring(checked and why or finished)
            if root then root[Cavity.ROOT_KEY]=receipt end
            transmit(surface)
            return false,receipt.reason
        end
    end
    transmit(surface)
    return true
end

function Cavity.ignite(surface,adapter)
    if not canWrite()then return false,"non-authority"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"then return false,"live cavity required"end
    if type(receipt.occupancy)~="table"or receipt.occupancy.ignite~=true then return false,"volume does not ignite"end
    local square=cavityFloor(adapter,receipt)or surface
    local started=false
    if type(adapter.startFire)=="function"then
        local ok,result=pcall(adapter.startFire,square)
        started=ok and result==true
    end
    if not started then return false,"could not start a fire in this cavity"end
    local root=data(surface)
    if root and type(root[Cavity.ROOT_KEY])=="table"then root[Cavity.ROOT_KEY].burning=true;transmit(surface)end
    local record=Cavity.getOpening(receipt.surface and receipt.surface.x,receipt.surface and receipt.surface.y)
    if record then record.burning=true;Cavity.registerOpening(record)end
    return true
end

function Cavity._resetForTests()openings={};openingCount=0 end

groundWorks.Cavity=Cavity
return Cavity
