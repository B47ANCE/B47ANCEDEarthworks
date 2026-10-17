local groundWorks=require "groundWorks/API"
local Projects=require "groundWorks/Projects"
local SurfaceMutation=require "groundWorks/SurfaceMutation"
local Routes={ROOT_KEY="groundWorks.route.v1",SCHEMA_VERSION=1,MAX_TYPES=32}
local definitions={};local definitionCount=0

local function copy(value)
    if type(value)~="table"then return value end local result={};for key,child in pairs(value)do result[key]=copy(child)end;return result
end
local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function data(square)
    if not square or type(square.getModData)~="function"then return nil,"square ModData unavailable"end
    local ok,result=pcall(square.getModData,square);if not ok or type(result)~="table"then return nil,"square ModData unavailable"end
    return result
end
local function transmit(square)if square and type(square.transmitModdata)=="function"then pcall(square.transmitModdata,square)end end
local function validId(value,maximum)return type(value)=="string"and value~=""and#value<=maximum and not value:find("[%c]")end

function Routes.register(definition)
    assert(type(definition)=="table"and validId(definition.id,96),"bounded route id required")
    assert(definition.projectType=="groundWorks.constructedPath"or definition.projectType=="groundWorks.constructedRoad","constructed route project type required")
    assert(validId(definition.floorSprite,128),"bounded floor sprite required")
    local work=finite(definition.workRequired);assert(work and work>0 and work<=1000000,"bounded positive work target required")
    assert(type(definition.requirements)=="table","exact material requirements required")
    assert(not definitions[definition.id],"duplicate constructed route type: "..definition.id)
    local required,count={},0
    for id,value in pairs(definition.requirements)do
        local amount=finite(value)
        assert(validId(id,128)and amount and amount>0 and amount<=1000000,"invalid route requirement")
        count=count+1;assert(count<=Projects.MAX_REQUIREMENTS,"too many route requirements")
        required[id]=amount
    end
    assert(definitionCount<Routes.MAX_TYPES,"too many constructed route types")
    definitions[definition.id]={id=definition.id,projectType=definition.projectType,floorSprite=definition.floorSprite,
        workRequired=work,requirements=required,requiresMachine=definition.requiresMachine==true}
    definitionCount=definitionCount+1
    return copy(definitions[definition.id])
end
function Routes.get(id)return definitions[id]and copy(definitions[id])or nil end
function Routes.begin(square,routeId,operationId,spec)
    local definition=definitions[routeId];if not definition then return false,"unknown constructed route type"end
    if definition.requiresMachine and(not spec or spec.providerKind~='machine')then return false,'This route requires construction machinery.'end
    local root,err=data(square);if not root then return false,err end
    local existing=root[Routes.ROOT_KEY]
    if existing~=nil and(type(existing)~="table"or existing.schemaVersion~=1
        or existing.routeId~=routeId or existing.projectType~=definition.projectType
        or existing.floorSprite~=definition.floorSprite)then return false,"route metadata conflict"end
    if root[Projects.ROOT_KEY]~=nil then
        local current=Projects.snapshot(square)
        if not current or not existing or current.projectType~=definition.projectType
            or current.deferCommit~=true then return false,"route project conflict"end
    elseif existing~=nil then return false,"route project missing"end
    spec=type(spec)=="table"and spec or{}
    local ok,result=Projects.begin(square,definition.projectType,operationId,{actor=spec.actor,worldAgeHours=spec.worldAgeHours,
        workRequired=definition.workRequired,requirements=definition.requirements,deferCommit=true})
    if not ok then return false,result end
    if existing then
        if existing.schemaVersion~=1 or existing.routeId~=routeId then return false,"route metadata conflict"end
        return true,{duplicate=true,route=copy(existing),project=result.state}
    end
    local route={schemaVersion=1,routeId=routeId,projectType=definition.projectType,floorSprite=definition.floorSprite}
    root[Routes.ROOT_KEY]=route;transmit(square)
    return true,{duplicate=false,route=copy(route),project=result.state}
end
function Routes.contributeMaterial(square,materialId,amount,operationId,provider,context)
    return Projects.contributeTransaction(square,materialId,amount,operationId,provider,context)
end
function Routes.advanceWork(square,work,operationId,workerId)return Projects.advance(square,work,operationId,workerId)end
function Routes.commit(square,operationId,options)
    local root,err=data(square);if not root then return false,err end
    local route=root[Routes.ROOT_KEY]
    if type(route)~="table"or route.schemaVersion~=1 or not definitions[route.routeId]
        or definitions[route.routeId].floorSprite~=route.floorSprite then return false,"unsupported or malformed route metadata"end
    options=type(options)=="table"and options or{}
    local provider={id="groundWorks.constructedRoute.floorSprite.v1",commit=function(target)
        local ok,receiptOrReason,details=SurfaceMutation.replaceFloorSprite(target,route.floorSprite,{
            resolveSprite=options.resolveSprite,requireRecalculation=options.requireRecalculation~=false})
        if ok then return true,receiptOrReason end
        return false,details or receiptOrReason
    end}
    return Projects.commitReady(square,operationId,provider,{routeId=route.routeId,floorSprite=route.floorSprite})
end
function Routes.snapshot(square)
    local root,err=data(square);if not root then return nil,err end
    local route=root[Routes.ROOT_KEY];if type(route)~="table"or route.schemaVersion~=1 then return nil,"no supported constructed route"end
    local project,projectErr=Projects.snapshot(square);if not project then return nil,projectErr end
    return{route=copy(route),project=project,worldRecovery=Projects.inspectWorldRecovery(square)}
end

-- Vanilla's gravel placement uses blends_street_01_55. Concrete uses the same
-- construction floor family as groundWorks cavity solid-fill surfaces.
Routes.register{id='groundWorks.gravelPath',projectType='groundWorks.constructedPath',
    floorSprite='blends_street_01_55',workRequired=100,requirements={['Base.Gravelbag']=2}}
Routes.register{id='groundWorks.concreteRoad',projectType='groundWorks.constructedRoad',
    floorSprite='floors_construction_01_0',workRequired=250,requiresMachine=true,
    requirements={['Base.Gravelbag']=4,['Base.BucketConcreteFull']=4}}
groundWorks.ConstructedRoutes=Routes
return Routes
