local groundWorks=require "groundWorks/API"

local Heavy={CONSUMER_ID="groundWorks.heavyObject.v1"}
local api=nil

function Heavy.attach(heavyObjects)
    api=type(heavyObjects)=="table" and type(heavyObjects.inspect)=="function" and heavyObjects or nil
    return Heavy.available()
end

function Heavy.available() return api~=nil end

-- Preserve the owner's transaction identity and phase order; never turn a
-- capability inspection into an assumed successful movement.
function Heavy.advance(actor,target,action,phase,operationId)
    if type(isClient)=='function'and isClient()then return false,'non-authority'end
    if not api or type(api.advance)~='function'then return false,'heavy-object transactions unavailable'end
    local view,reason=Heavy.query(actor,target)
    if not view then return false,reason end
    return api.advance(actor,{schemaVersion=1,providerId=view.providerId,targetId=view.targetId,
        actorId=view.actorId,action=action,phase=phase,operationId=operationId})
end

local function sanitizeAction(entry)
    if type(entry)~="table" then return {supported=false,eligible=false,reason="UNSUPPORTED"}end
    return{supported=entry.supported==true,eligible=entry.eligible==true,
        reason=tostring(entry.reason or"UNSUPPORTED"):sub(1,160)}
end

-- Read-only capability consumption (EXT-17). Queries itjustWorks without
-- owning generic physics, movement, or foreign inventory state.
function Heavy.query(actor,target)
    if not Heavy.available() then return nil,"heavy-object consumer unavailable" end
    if type(api.inspect)~="function" then return nil,"heavy-object inspection unavailable" end
    local ok,view=pcall(api.inspect,actor,target)
    if not ok then return nil,"heavy-object inspection failed" end
    if type(view)~="table" then return nil,"unsupported heavy-object target" end
    local operations=type(view.operations)=="table" and view.operations or{}
    return{providerId=view.providerId,targetId=view.targetId,actorId=view.actorId,
        operations={push=sanitizeAction(operations.push),pull=sanitizeAction(operations.pull),carry=sanitizeAction(operations.carry)}}
end

function Heavy.supports(actor,target,action)
    local view,err=Heavy.query(actor,target)
    if not view then return false,err end
    local entry=view.operations[action]
    if not entry then return false,"unsupported heavy-object action" end
    if not entry.supported then return false,entry.reason end
    return true
end

function Heavy.eligible(actor,target,action)
    local view,err=Heavy.query(actor,target)
    if not view then return false,err end
    local entry=view.operations[action]
    if not entry then return false,"unsupported heavy-object action" end
    if not entry.supported then return false,entry.reason end
    if not entry.eligible then return false,entry.reason end
    return true
end

groundWorks.HeavyObjectIntegration=Heavy
return Heavy
