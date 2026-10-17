local groundWorks=require "groundWorks/API"
local Providers={MAX_ID=96,MAX_WORK=1000000,MAX_ACTIVE_MODS=4096,definitions={}}

local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function copy(value,seen)
    if type(value)~="table"then return value end seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,child in pairs(value)do result[copy(key,seen)]=copy(child,seen)end;seen[value]=nil;return result
end
local function capabilityView(values)
    values=type(values)=="table"and values or{}
    return{excavate=values.excavate==true,fill=values.fill==true,transferSoil=values.transferSoil==true,deposit=values.deposit==true}
end
local function view(definition)
    if not definition then return nil end
    return{id=definition.id,kind=definition.kind,requiredModId=definition.requiredModId,capabilities=copy(definition.capabilities),
        maxWorkPerOperation=definition.maxWorkPerOperation,maxSoilPerOperation=definition.maxSoilPerOperation}
end

-- Check the current game's enabled mods, including local mods. A Workshop ID
-- or a directory existing on disk is not evidence that a provider can run.
local function dependencyAvailable(definition)
    if not definition.requiredModId then return true end
    local getter=rawget(_G,"getActivatedMods")
    if type(getter)~="function"then return false,"active mod list unavailable"end
    local ok,active=pcall(function()
        local mods=getter();if not mods then return false end
        local count=mods:size()
        if type(count)~="number"or count~=count or count<0 or count>Providers.MAX_ACTIVE_MODS or count%1~=0 then return false end
        for index=0,count-1 do
            if mods:get(index)==definition.requiredModId then return true end
        end
        return false
    end)
    if not ok then return false,"active mod lookup failed"end
    if active~=true then return false,"required vehicle/integration mod is not active"end
    return true
end

function Providers.register(definition)
    assert(type(definition)=="table","earthwork provider definition required")
    assert(type(definition.id)=="string"and definition.id~=""and#definition.id<=Providers.MAX_ID,"bounded provider ID required")
    assert(definition.kind=="manual"or definition.kind=="machine"or definition.kind=="integration","provider kind must be manual, machine, or integration")
    local requiredModId=definition.requiredModId
    assert(requiredModId==nil or(type(requiredModId)=="string"and requiredModId~=""and#requiredModId<=128
        and not requiredModId:find("[%c]")),"bounded required mod ID expected")
    assert(definition.kind~="machine"or requiredModId~=nil,"machine provider requires its vehicle mod ID")
    assert(not Providers.definitions[definition.id],"duplicate earthwork provider: "..definition.id)
    local capabilities=capabilityView(definition.capabilities)
    assert(capabilities.excavate or capabilities.fill or capabilities.transferSoil or capabilities.deposit,"at least one earthwork capability required")
    local maxWork=finite(definition.maxWorkPerOperation);assert(maxWork and maxWork>0 and maxWork<=Providers.MAX_WORK,"bounded positive work limit required")
    local maxSoil=finite(definition.maxSoilPerOperation or maxWork);assert(maxSoil and maxSoil>0 and maxSoil<=Providers.MAX_WORK,"bounded positive soil limit required")
    assert(definition.validate==nil or type(definition.validate)=="function","provider validation callback must be a function")
    Providers.definitions[definition.id]={id=definition.id,kind=definition.kind,requiredModId=requiredModId,capabilities=capabilities,
        maxWorkPerOperation=maxWork,maxSoilPerOperation=maxSoil,validate=definition.validate}
    return view(Providers.definitions[definition.id])
end

function Providers.get(id)return view(Providers.definitions[id])end

function Providers.isAvailable(id)
    local definition=Providers.definitions[id];if not definition then return false,"unknown earthwork provider"end
    return dependencyAvailable(definition)
end

-- Menus can use this catalog without loading optional vehicle modules.
function Providers.listAvailable()
    local result={}
    for _,definition in pairs(Providers.definitions)do
        if dependencyAvailable(definition)then result[#result+1]=view(definition)end
    end
    table.sort(result,function(a,b)return a.id<b.id end)
    return result
end

function Providers.authorize(id,capability,requested,context)
    local definition=Providers.definitions[id];if not definition then return nil,"unknown earthwork provider"end
    local available,dependencyErr=dependencyAvailable(definition);if not available then return nil,dependencyErr end
    if capability~="excavate"and capability~="fill"and capability~="transferSoil"and capability~="deposit"then return nil,"unknown earthwork capability"end
    if definition.capabilities[capability]~=true then return nil,"provider does not support "..capability end
    requested=finite(requested);if not requested or requested<=0 then return nil,"positive finite amount required"end
    local limit=(capability=="transferSoil"or capability=="deposit")and definition.maxSoilPerOperation or definition.maxWorkPerOperation
    if requested>limit then return nil,"provider operation exceeds declared bound"end
    local protected=copy(type(context)=="table"and context or{})
    if definition.validate then
        local ok,allowed,reason=pcall(definition.validate,capability,requested,protected)
        if not ok then return nil,"earthwork provider validation error"end
        if allowed~=true then return nil,tostring(reason or"earthwork provider rejected operation"):sub(1,160)end
    end
    return{providerId=definition.id,providerKind=definition.kind,capability=capability,amount=requested,
        maxWorkPerOperation=definition.maxWorkPerOperation,maxSoilPerOperation=definition.maxSoilPerOperation}
end

function Providers._resetForTests()Providers.definitions={}end

Providers.register{
    id="groundWorks.cavity.manual.v1",kind="manual",
    capabilities={excavate=true,fill=true,transferSoil=true,deposit=true},
    maxWorkPerOperation=1000,maxSoilPerOperation=1000,
}

groundWorks.EarthworkProviders=Providers
return Providers
