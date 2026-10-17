local groundWorks=require "groundWorks/API"

-- Optional derived visuals. Providers must verify both application and removal.
-- With no provider the semantic wear system remains usable on its own.
local Presentation={STATE_KEY="groundWorks.presentation.v1",MAX_PROVIDERS=16}
local providers={}
local function authoritative()
    return not(type(isClient)=="function"and isClient()==true)
end
local function validId(value,maximum)return type(value)=="string"and value~=""and#value<=maximum and not value:find("[%c]")end
local function validLayer(value)return value=="none"or value=="overlay"or value=="base"end
local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function transmit(square)
    if square and type(square.transmitModdata)=="function"then square:transmitModdata()end
end

function Presentation.registerLayerProvider(definition)
    assert(type(definition)=="table"and validId(definition.id,96),"bounded layer provider id required")
    assert(type(definition.layerFor)=="function","layerFor(stage) callback required")
    assert(type(definition.apply)=="function"and type(definition.remove)=="function","verified apply and remove callbacks required")
    for _,provider in ipairs(providers)do assert(provider.id~=definition.id,"duplicate layer provider: "..definition.id)end
    assert(#providers<Presentation.MAX_PROVIDERS,"layer provider limit reached")
    local provider={id=definition.id,priority=finite(definition.priority)or 0,
        layerFor=definition.layerFor,apply=definition.apply,remove=definition.remove}
    providers[#providers+1]=provider
    table.sort(providers,function(a,b)return a.priority==b.priority and a.id<b.id or a.priority>b.priority end)
    return{id=provider.id,priority=provider.priority}
end
function Presentation.providerCount()return#providers end
local function providerById(id)
    for _,provider in ipairs(providers)do if provider.id==id then return provider end end
end
local function stageLayer(stage)
    for _,provider in ipairs(providers)do
        local ok,value=pcall(provider.layerFor,stage)
        if not ok or not validLayer(value)then return nil,nil,"native layer selection failed"end
        if value~="none"then return value,provider end
    end
    return"none",nil
end
local function data(square)
    if not square or type(square.getModData)~="function"then return nil,"square ModData unavailable"end
    local ok,result=pcall(square.getModData,square)
    if not ok or type(result)~="table"then return nil,"square ModData unavailable"end
    return result
end
local function state(square,create)
    local root,err=data(square);if not root then return nil,err end
    local current=root[Presentation.STATE_KEY]
    if current==nil and create then
        current={schemaVersion=1,presentedStage="UNTOUCHED",layer="none",hidden=false,ownerId="groundWorks"}
        root[Presentation.STATE_KEY]=current
    end
    if current==nil then return nil,"no presentation state"end
    if type(current)~="table"or current.schemaVersion~=1 or not validLayer(current.layer)then
        return nil,"unsupported or malformed presentation state"
    end
    return current
end
local function view(square)
    local current,err=state(square,false)
    if not current then
        if err=="no presentation state"then return{presentedStage="UNTOUCHED",layer="none",hidden=false,ownerId=nil}end
        return nil,err
    end
    return{presentedStage=current.presentedStage,layer=current.layer,hidden=current.hidden==true,
        ownerId=current.ownerId,providerId=current.providerId,requiresInspection=current.requiresInspection==true}
end
local function invoke(provider,method,square,stage)
    if not provider then return false,"native layer provider unavailable"end
    local ok,result=pcall(provider[method],square,stage)
    if not ok or result~=true then return false,"native presentation "..method.." was not verified"end
    return true
end
local function removeCurrent(square,current)
    if current.layer=="none"or current.hidden then return true end
    return invoke(providerById(current.providerId),"remove",square)
end
local function failed(square,current,pending)
    current.requiresInspection=true
    current.pendingProviderId=pending and pending.id or nil
    transmit(square)
end

function Presentation.present(square)
    if not authoritative()then return false,"non-authority"end
    local current,err=state(square,true);if not current then return false,err end
    if current.requiresInspection then return false,"presentation requires cleanup before retry"end
    if current.hidden then return true,view(square)end
    local wear=groundWorks.getWearState(square)
    local stage=type(wear)=="table"and wear.stage or"UNTOUCHED"
    local layer,provider,layerErr=stageLayer(stage)
    if not layer then return false,layerErr end
    local providerId=provider and provider.id or nil
    if current.presentedStage==stage and current.layer==layer and current.providerId==providerId then return true,view(square)end
    local old=providerById(current.providerId)
    local removed,reason=removeCurrent(square,current)
    if not removed then failed(square,current);return false,reason end
    if provider then
        local applied,applyErr=invoke(provider,"apply",square,stage)
        if not applied then
            local cleaned=invoke(provider,"remove",square)
            local restored=current.layer=="none"or invoke(old,"apply",square,current.presentedStage)
            if not cleaned or not restored then failed(square,current,provider)end
            return false,applyErr
        end
    end
    current.presentedStage=stage;current.layer=layer;current.providerId=providerId
    current.ownerId="groundWorks"
    transmit(square)
    return true,view(square)
end

function Presentation.hide(square)
    if not authoritative()then return false,"non-authority"end
    local current,err=state(square,true);if not current then return false,err end
    if current.requiresInspection then return false,"presentation requires cleanup before retry"end
    if not current.hidden then
        local removed,reason=removeCurrent(square,current)
        if not removed then failed(square,current);return false,reason end
        current.hidden=true;transmit(square)
    end
    return true,view(square)
end
function Presentation.unhide(square)
    if not authoritative()then return false,"non-authority"end
    local current,err=state(square,true);if not current then return false,err end
    if current.requiresInspection then return false,"presentation requires cleanup before retry"end
    if not current.hidden then return Presentation.present(square)end
    local wear=groundWorks.getWearState(square)
    local stage=type(wear)=="table"and wear.stage or"UNTOUCHED"
    local layer,provider,layerErr=stageLayer(stage)
    if not layer then return false,layerErr end
    if provider then
        local applied,reason=invoke(provider,"apply",square,stage)
        if not applied then
            if not invoke(provider,"remove",square)then failed(square,current,provider)end
            return false,reason
        end
    end
    current.hidden=false;current.presentedStage=stage;current.layer=layer
    current.providerId=provider and provider.id or nil
    transmit(square)
    return true,view(square)
end
function Presentation.cleanup(square)
    if not authoritative()then return false,"non-authority"end
    local current,err=state(square,false)
    if not current then return err=="no presentation state",err end
    if current.pendingProviderId then
        local removed,reason=invoke(providerById(current.pendingProviderId),"remove",square)
        if not removed then return false,reason end
    end
    if current.layer~="none"and(not current.hidden or current.requiresInspection)
        and current.providerId~=current.pendingProviderId then
        local removed,reason=invoke(providerById(current.providerId),"remove",square)
        if not removed then return false,reason end
    end
    local root=data(square);root[Presentation.STATE_KEY]=nil;transmit(square)
    return true
end
function Presentation.reconcile(square)
    local root,err=data(square);if not root then return false,err end
    if root[Presentation.STATE_KEY]==nil and root[groundWorks.STATE_KEY]==nil then return true end
    return Presentation.present(square)
end
function Presentation.inspect(square)return view(square)end
function Presentation.install(events)
    if not Presentation.installed then
        groundWorks.registerWearListener("groundWorks.presentation",function(square)Presentation.present(square)end)
        Presentation.installed=true
    end
    events=events or rawget(_G,"Events")
    if not Presentation.loadInstalled and events and events.LoadGridsquare and type(events.LoadGridsquare.Add)=="function"then
        events.LoadGridsquare.Add(Presentation.reconcile)
        Presentation.loadInstalled=true
    end
    return true
end
function Presentation._resetForTests()providers={};Presentation.installed=false;Presentation.loadInstalled=false end
groundWorks.SurfacePresentation=Presentation
return Presentation
