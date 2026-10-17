groundWorks=rawget(_G,"groundWorks") or {}
groundWorks.VERSION="0.17.0"
-- Preserve the status API for consumers; rendering is owned by the vanilla engine.
-- Return a fresh snapshot so callers cannot enable a renderer through this API.
function groundWorks.getVisibilityStatus()
    return {available=false,active=false,mode='vanilla'}
end
groundWorks.SurfaceProviders=groundWorks.SurfaceProviders or {}
groundWorks.ProjectTypes=groundWorks.ProjectTypes or {}
groundWorks.STATE_KEY="groundWorks.surface.v1"
local wearListeners={}
local wearListenerCount=0

function groundWorks.registerWearListener(id,callback)
    assert(type(id)=="string"and id~=""and#id<=96,"bounded wear listener ID required")
    assert(type(callback)=="function","wear listener callback required")
    if not wearListeners[id]then
        assert(wearListenerCount<16,"wear listener limit reached")
        wearListenerCount=wearListenerCount+1
    end
    wearListeners[id]=callback
end

local function wearChanged(square)
    for _,callback in pairs(wearListeners)do pcall(callback,square)end
end

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function() return object[method] end)
    if not ok or type(fn)~="function" then return nil end
    local called,result=pcall(fn,object,...)
    return called and result or nil
end
local function value(object,key,method)
    if key and type(object)=="table" and object[key]~=nil then return object[key] end
    return call(object,method)
end
local function property(properties,name)
    if not properties then return nil end
    local has=call(properties,"has",name)
    if has==true then return true end
    return call(properties,"get",name)
end
local function canWrite()
    if type(rawget(_G,"isClient"))=="function" and isClient() and not (type(rawget(_G,"isServer"))=="function" and isServer()) then return false end
    return true
end
local function clamp(value,low,high) return math.max(low,math.min(high,tonumber(value) or low)) end
local function projectView(definition)
    if type(definition)~="table"then return nil end
    return{id=definition.id,domain=definition.domain,validate=definition.validate}
end
local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,entry in pairs(value)do result[copy(key,seen)]=copy(entry,seen)end
    seen[value]=nil;return result
end
local function wearView(current)
    current=type(current)=="table"and current or{}
    local result=copy(current);local traffic=type(result.traffic)=="table"and result.traffic or{}
    result.schemaVersion=tonumber(result.schemaVersion)or 1
    result.traffic={foot=tonumber(traffic.foot)or 0,animal=tonumber(traffic.animal)or 0,vehicle=tonumber(traffic.vehicle)or 0}
    result.wear=tonumber(result.wear)or 0;result.stage=result.stage or"UNTOUCHED"
    result.lastTrafficWorldAge=tonumber(result.lastTrafficWorldAge)
    result.lastUpdateWorldAge=tonumber(result.lastUpdateWorldAge)
    return result
end

function groundWorks.registerProjectType(definition)
    assert(type(definition)=="table" and type(definition.id)=="string" and definition.id~="","project type id required")
    assert(definition.domain=="excavation" or definition.domain=="surface","project domain must be excavation or surface")
    assert(type(definition.validate)=="function","project validation callback required")
    assert(not groundWorks.ProjectTypes[definition.id],"duplicate groundWorks project type: "..definition.id)
    local registered={id=definition.id,domain=definition.domain,validate=definition.validate}
    groundWorks.ProjectTypes[registered.id]=registered
    return projectView(registered)
end

function groundWorks.getProjectType(id) return projectView(groundWorks.ProjectTypes[id]) end

function groundWorks.validateProject(id,context)
    local definition=groundWorks.ProjectTypes[id]
    if not definition then return false,"unknown project type" end
    context=type(context)=="table" and context or {}
    if not context.square then return false,"square required" end
    local ok,allowed,reason=pcall(definition.validate,context)
    if not ok then return false,"project validation error" end
    if allowed~=true then return false,reason or "project rejected" end
    return true,projectView(definition)
end

function groundWorks.registerSurfaceProvider(definition)
    assert(type(definition)=="table" and type(definition.id)=="string" and type(definition.matches)=="function" and type(definition.inspect)=="function","surface provider id/matches/inspect required")
    for _,provider in ipairs(groundWorks.SurfaceProviders) do assert(provider.id~=definition.id,"duplicate groundWorks provider: "..definition.id) end
    local registered={id=definition.id,priority=tonumber(definition.priority)or 0,
        matches=definition.matches,inspect=definition.inspect}
    groundWorks.SurfaceProviders[#groundWorks.SurfaceProviders+1]=registered
    table.sort(groundWorks.SurfaceProviders,function(a,b) return a.priority==b.priority and a.id<b.id or a.priority>b.priority end)
    return{id=registered.id,priority=registered.priority,matches=registered.matches,inspect=registered.inspect}
end

function groundWorks.inspectSurface(square)
    if not square then return nil,"square required" end
    for _,provider in ipairs(groundWorks.SurfaceProviders) do
        local ok,matches=pcall(provider.matches,square)
        if ok and matches then
            local inspected,result=pcall(provider.inspect,square)
            if inspected and type(result)=="table" then
                local view={};for key,entry in pairs(result)do view[key]=entry end
                view.providerId=provider.id;return view
            end
        end
    end
    return nil,"unsupported surface"
end

local function state(square,create)
    local data=value(square,"modData","getModData")
    if type(data)~="table" then return nil,"square ModData unavailable" end
    local current=data[groundWorks.STATE_KEY]
    if current==nil and create then
        current={schemaVersion=1,traffic={foot=0,animal=0,vehicle=0},wear=0,stage="UNTOUCHED",lastTrafficWorldAge=nil,lastUpdateWorldAge=nil}
        data[groundWorks.STATE_KEY]=current
    end
    if current==nil then return nil,"no surface state" end
    if type(current)~="table"or current.schemaVersion~=1 or type(current.traffic)~="table"then
        return nil,"unsupported or malformed surface state"
    end
    return current
end

function groundWorks.getWearState(square)
    local current,err=state(square,false)
    if current then return wearView(current)end
    if err=="no surface state"then return wearView(nil)end
    return nil,err
end

function groundWorks.stageForWear(wear)
    wear=clamp(wear,0,100)
    if wear>=75 then return "ESTABLISHED_PATH" end
    if wear>=45 then return "BARE" end
    if wear>=20 then return "WORN" end
    if wear>=5 then return "LIGHT_WEAR" end
    return "UNTOUCHED"
end

function groundWorks.reportTraffic(square,kind,amount,worldAge,recoveryRatePerDay)
    if not canWrite() then return false,"non-authority" end
    if worldAge~=nil then
        worldAge=tonumber(worldAge)
        if not worldAge or worldAge~=worldAge or worldAge==math.huge or worldAge==-math.huge or worldAge<0 then
            return false,"finite non-negative world age required"
        end
    end
    local weights={foot=1,animal=1.5,vehicle=5}
    if not weights[kind] then return false,"unknown traffic kind" end
    local surface,surfaceErr=groundWorks.inspectSurface(square)
    if not surface then return false,surfaceErr end
    if surface.water or surface.trafficWear==false then return false,"surface does not retain traffic wear" end
    local current,err=state(square,true)
    if not current then return false,err end
    amount=clamp(amount,0,1000)
    worldAge=tonumber(worldAge)
    if worldAge then
        local previous=tonumber(current.lastUpdateWorldAge) or tonumber(current.lastTrafficWorldAge) or worldAge
        worldAge=math.max(worldAge,previous)
        local elapsedHours=math.max(0,worldAge-previous)
        local recovered=(elapsedHours/24)*math.max(0,tonumber(recoveryRatePerDay) or .05)
        current.wear=clamp((tonumber(current.wear) or 0)-recovered,0,100)
    end
    current.traffic[kind]=(tonumber(current.traffic[kind]) or 0)+amount
    local resistance=clamp(surface.wearResistance or 1,.1,100)
    current.wear=clamp((tonumber(current.wear) or 0)+(amount*weights[kind]/resistance),0,100)
    current.stage=groundWorks.stageForWear(current.wear)
    current.lastTrafficWorldAge=worldAge or current.lastTrafficWorldAge
    current.lastUpdateWorldAge=worldAge or current.lastUpdateWorldAge
    wearChanged(square)
    return true,wearView(current)
end

function groundWorks.integrateRecovery(square,worldAge,ratePerDay)
    if not canWrite() then return false,"non-authority" end
    local current,stateErr=state(square,false)
    if not current then
        if stateErr=="no surface state"then return true,groundWorks.getWearState(square)end
        return false,stateErr
    end
    worldAge=tonumber(worldAge)
    if not worldAge or worldAge~=worldAge or worldAge==math.huge or worldAge==-math.huge or worldAge<0 then return false,"finite non-negative world age required" end
    local previous=tonumber(current.lastUpdateWorldAge) or tonumber(current.lastTrafficWorldAge) or worldAge
    worldAge=math.max(worldAge,previous)
    local elapsedHours=math.max(0,worldAge-previous)
    local recovered=(elapsedHours/24)*math.max(0,tonumber(ratePerDay) or .05)
    current.wear=clamp((tonumber(current.wear) or 0)-recovered,0,100)
    current.stage=groundWorks.stageForWear(current.wear)
    current.lastUpdateWorldAge=worldAge
    wearChanged(square)
    return true,wearView(current)
end

function groundWorks.applySurfaceCleaning(square,worldAgeHours,cleaningAmount)
    if not canWrite() then return false,"non-authority" end
    local current,stateErr=state(square,false)
    if not current then
        if stateErr=="no surface state"then return true,groundWorks.getWearState(square)end
        return false,stateErr
    end
    local age=tonumber(worldAgeHours)
    if not age or age~=age or age==math.huge or age==-math.huge or age<0 then return false,"finite non-negative world age required" end
    local amount=clamp(cleaningAmount,0,100)
    if amount<=0 then return true,wearView(current)end
    local previous=tonumber(current.lastUpdateWorldAge) or tonumber(current.lastTrafficWorldAge) or age
    age=math.max(age,previous)
    current.wear=clamp((tonumber(current.wear) or 0)-amount,0,100)
    current.stage=groundWorks.stageForWear(current.wear)
    current.lastUpdateWorldAge=age
    wearChanged(square)
    return true,wearView(current)
end

groundWorks.registerSurfaceProvider{
    id="vanilla.floor",priority=-100,
    matches=function(square) return value(square,"floor","getFloor")~=nil end,
    inspect=function(square)
        local floor=value(square,"floor","getFloor")
        local sprite=value(floor,"sprite","getSprite")
        local name=tostring(value(sprite,"name","getName") or value(floor,"textureName","getTextureName") or "")
        local properties=value(sprite,"properties","getProperties") or value(floor,"properties","getProperties")
        local squareProperties=value(square,"properties","getProperties")
        local lowered=name:lower()
        local water=property(squareProperties,"water")==true or property(properties,"water")==true
        local grass=property(properties,"grassFloor")~=nil or property(properties,"GRASS_FLOOR")==true or lowered:find("blends_natural",1,true)~=nil
        local material="unknown"
        if water then material="water"
        elseif grass then material="natural"
        elseif lowered:find("gravel",1,true) then material="gravel"
        elseif lowered:find("dirt",1,true) or lowered:find("sand",1,true) then material="soil"
        elseif lowered:find("street",1,true) or lowered:find("road",1,true) then material="paved"
        elseif property(properties,"solidfloor")==true then material="constructed" end
        local resistance=({natural=.75,soil=1,gravel=4,paved=30,constructed=50,water=100})[material] or 10
        return {square=square,floor=floor,spriteName=name,material=material,natural=(material=="natural" or material=="soil"),water=water,wearResistance=resistance,trafficWear=(material~="water" and material~="constructed")}
    end,
}

local function naturalGround(context)
    local surface,err=groundWorks.inspectSurface(context.square)
    if not surface then return false,err end
    if surface.water then return false,"cannot build in water" end
    if not surface.natural then return false,"natural ground required" end
    return true
end

groundWorks.registerProjectType{id="groundWorks.trench",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.moat",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.grave",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.openPit",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.basement",domain="excavation",validate=function(context)
    local surface,err=groundWorks.inspectSurface(context.square)
    if not surface then return false,err end
    if surface.water then return false,"cannot excavate a basement in water"end
    if call(context.square,"getZ")~=0 then return false,"basement excavation starts on the ground floor"end
    return true
end}
groundWorks.registerProjectType{id="groundWorks.burnPit",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.foundation",domain="excavation",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.constructedPath",domain="surface",validate=naturalGround}
groundWorks.registerProjectType{id="groundWorks.constructedRoad",domain="surface",validate=naturalGround}

_G.groundWorks=groundWorks
return groundWorks
