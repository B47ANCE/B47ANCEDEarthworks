local groundWorks=require "groundWorks/API"
local Experiment={ROOT_KEY="groundWorks.excavationExperiment.v1",SCHEMA_VERSION=1,FLOOR_SPRITE="blends_natural_01_64"}

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
local function adapterValid(adapter)
    if type(adapter)~="table"then return false end
    for _,name in ipairs({"validateSprite","isValidSquare","getSquare","createSquare","connectSquare","addFloor","tagObject","recalculate","transmitObject","verify"})do
        if type(adapter[name])~="function"then return false end
    end
    return true
end
local function setFailure(surface,receipt,reason,createdSquare,createdObject,adapter)
    receipt.status="failed";receipt.reason=tostring(reason or"experimental transaction failed"):sub(1,256)
    receipt.rollbackAttempted=createdObject~=nil;receipt.objectRolledBack=false
    if createdObject and type(adapter.removeObject)=="function"then
        local ok,result=pcall(adapter.removeObject,createdSquare,createdObject)
        receipt.objectRolledBack=ok and result==true
    end
    receipt.requiresInspection=createdSquare~=nil or(createdObject~=nil and not receipt.objectRolledBack)
    receipt.topologyUncertain=createdSquare~=nil
    transmit(surface)
    return false,receipt.requiresInspection and"experimental excavation requires inspection"or receipt.reason,copy(receipt)
end

function Experiment.plan(surface)
    local x,y,z=coordinate(surface,"getX"),coordinate(surface,"getY"),coordinate(surface,"getZ")
    if not x or not y or not z then return nil,"integer surface coordinates required"end
    if z~=0 then return nil,"experimental excavation requires z=0 surface"end
    return{schemaVersion=1,surface={x=x,y=y,z=z},cells={{x=x,y=y,z=-1}},floorSprite=Experiment.FLOOR_SPRITE}
end

function Experiment.inspect(surface)
    return require("groundWorks/Cavity").inspect(surface)
end

function Experiment.execute(surface,operationId,adapter,options)
    local Cavity=require "groundWorks/Cavity"
    options=type(options)=="table"and options or{}
    if options.volumeType==nil then options.volumeType="groundWorks.openPit"end
    if options.experimental==nil then options.experimental=true end
    return Cavity.execute(surface,operationId,adapter,options)
end

function Experiment.verifyCurrent(surface,adapter)
    local Cavity=require "groundWorks/Cavity"
    return Cavity.verifyCurrent(surface,adapter)
end

function Experiment.verifyCurrentLegacy(surface,adapter)
    if type(adapter)~="table"or type(adapter.getSquare)~="function"or type(adapter.verify)~="function"then
        return nil,"inspection adapter required"
    end
    local receipt,err=Experiment.inspect(surface);if not receipt then return nil,err end
    if receipt.status~="created"or type(receipt.cells)~="table"or type(receipt.cells[1])~="table"then
        return{status=receipt.status,geometryResolved=false,requiresInspection=receipt.requiresInspection==true}
    end
    local target=receipt.cells[1]
    local plan=Experiment.plan(surface)
    if not plan or target.x~=plan.cells[1].x or target.y~=plan.cells[1].y or target.z~=-1
        or #receipt.cells~=1 or not operation(receipt.operationId) or receipt.floorSprite~=Experiment.FLOOR_SPRITE then
        return{status="unsupported",geometryResolved=false,requiresInspection=true}
    end
    local resolved,square=pcall(adapter.getSquare,target.x,target.y,target.z)
    if not resolved then return{status=receipt.status,geometryResolved=false,requiresInspection=true,reason="square lookup failed"}end
    local floor=square and call(square,"getFloor")or nil
    local checked,verified=true,false
    if square and floor then checked,verified=pcall(adapter.verify,target.x,target.y,target.z,square,floor,receipt.operationId)end
    local ok=checked and verified==true
    return{status=receipt.status,operationId=receipt.operationId,geometryResolved=ok,
        squareResolved=square~=nil,floorResolved=floor~=nil,requiresInspection=receipt.requiresInspection==true or not ok}
end

groundWorks.ExcavationExperiment=Experiment
return Experiment
