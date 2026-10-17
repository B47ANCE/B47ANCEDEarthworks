local groundWorks=require "groundWorks/API"
local Projects={ROOT_KEY="groundWorks.project.v1",SCHEMA_VERSION=1,MAX_REQUIREMENTS=16,MAX_OPERATIONS=64}

local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function canWrite()return not(type(rawget(_G,"isClient"))=="function"and isClient()==true and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))end
local function data(square)
    if not square or type(square.getModData)~="function"then return nil,"square ModData unavailable"end
    local ok,result=pcall(square.getModData,square);if not ok or type(result)~="table"then return nil,"square ModData unavailable"end
    return result
end
local function state(square)
    local root,err=data(square);if not root then return nil,err end
    local current=root[Projects.ROOT_KEY]
    if current==nil then return nil,"no ground project"end
    if type(current)~="table"or current.schemaVersion~=1 or type(current.operationId)~="string"
        or type(current.projectType)~="string"or type(current.status)~="string"
        or type(current.requirements)~="table"or type(current.materials)~="table"
        or type(current.processedOperations)~="table"or current.materialRecovery~=nil and type(current.materialRecovery)~="table"
        or current.worldRecovery~=nil and type(current.worldRecovery)~="table"
        then return nil,"unsupported or malformed ground project"end
    return current
end
local function requirements(values)
    if values==nil then return{}end
    assert(type(values)=="table","project requirements must be a table")
    local result,count={},0
    for id,value in pairs(values)do
        local amount=finite(value);assert(type(id)=="string"and id~=""and #id<=128 and amount and amount>0,"invalid project requirement")
        result[id]=amount;count=count+1;assert(count<=Projects.MAX_REQUIREMENTS,"too many project requirements")
    end
    return result
end
local function seen(current,id)
    for _,existing in ipairs(current.processedOperations)do if existing==id then return true end end
    return false
end
local function remember(current,id)
    current.processedOperations[#current.processedOperations+1]=id
    while #current.processedOperations>Projects.MAX_OPERATIONS do table.remove(current.processedOperations,1)end
end
local function operation(id)
    return type(id)=="string"and id~=""and #id<=128
end
local function copy(value)
    if type(value)~="table"then return value end local result={};for key,child in pairs(value)do result[key]=copy(child)end;return result
end
local function receiptSummary(value)
    if type(value)~="table"then return type(value)=="string"and value:sub(1,160)or value end
    local result,count={},0
    for key,child in pairs(value)do
        if count>=16 then result.truncated=true;break end
        if(type(key)=="string"or type(key)=="number")and(type(child)=="string"or type(child)=="number"or type(child)=="boolean")then
            result[key]=type(child)=="string"and child:sub(1,160)or child;count=count+1
        end
    end
    return result
end
local function transmit(square)if square and type(square.transmitModdata)=="function"then pcall(square.transmitModdata,square)end end
local function materialsComplete(current)
    for id,needed in pairs(current.requirements)do if (finite(current.materials[id])or 0)<needed then return false end end
    return true
end
local function complete(square,current,workerId,receipt)
    current.status="completed";current.result={schemaVersion=1,projectType=current.projectType,domain=current.domain,
        completedBy=tostring(workerId),commitReceipt=copy(receipt)}
    local root=data(square);local surface=root and root[groundWorks.STATE_KEY]
    if type(surface)~="table"then surface={schemaVersion=1,traffic={foot=0,animal=0,vehicle=0},wear=0,stage="UNTOUCHED"};root[groundWorks.STATE_KEY]=surface end
    surface.projectResult=copy(current.result)
    surface.stage=current.domain=="surface"and"CONSTRUCTED"or"EXCAVATED"
end
local function contribution(current,materialId,amount,operationId)
    if current.status~="active"then return nil,"project is not active"end
    if current.materialRecovery~=nil then return nil,"project material transaction requires inspection"end
    if seen(current,operationId)then return{duplicate=true,accepted=0,excess=amount}end
    local needed=current.requirements[materialId];if not needed then return nil,"material is not required"end
    amount=finite(amount);if not amount or amount<=0 then return nil,"positive material amount required"end
    local prior=finite(current.materials[materialId])or 0
    local accepted=math.min(amount,math.max(0,needed-prior));if accepted<=0 then return nil,"material requirement already satisfied"end
    return{duplicate=false,accepted=accepted,excess=amount-accepted,prior=prior}
end

function Projects.begin(square,projectType,operationId,spec)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    spec=type(spec)=="table"and spec or{}
    local valid,definition=groundWorks.validateProject(projectType,{square=square,actor=spec.actor})
    if not valid then return false,definition end
    local root,err=data(square);if not root then return false,err end
    local existing=root[Projects.ROOT_KEY]
    if existing~=nil then
        local current,currentErr=state(square);if not current then return false,currentErr end
        if current.operationId==operationId then return true,{duplicate=true,state=copy(current)}end
        return false,"square already has a ground project"
    end
    local total=finite(spec.workRequired);if not total or total<=0 or total>1000000 then return false,"bounded positive work target required"end
    local ok,needed=pcall(requirements,spec.requirements);if not ok then return false,needed end
    local current={schemaVersion=1,operationId=operationId,projectType=projectType,domain=definition.domain,
        status="active",workRequired=total,workCompleted=0,requirements=needed,materials={},
        processedOperations={operationId},createdWorldAgeHours=finite(spec.worldAgeHours),result=nil,
        deferCommit=spec.deferCommit==true,worldRecovery=nil}
    root[Projects.ROOT_KEY]=current;transmit(square)
    return true,{duplicate=false,state=copy(current)}
end
function Projects.contribute(square,materialId,amount,operationId)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    local current,err=state(square);if not current then return false,err end
    local plan,planErr=contribution(current,materialId,amount,operationId);if not plan then return false,planErr end
    if plan.duplicate then return true,{duplicate=true,state=copy(current)}end
    current.materials[materialId]=plan.prior+plan.accepted;remember(current,operationId);transmit(square)
    return true,{duplicate=false,accepted=plan.accepted,excess=plan.excess,state=copy(current)}
end
function Projects.contributeTransaction(square,materialId,amount,operationId,provider,context)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    if type(provider)~="table"or type(provider.id)~="string"or provider.id==""or#provider.id>96
        or type(provider.consume)~="function"then return false,"material-consumption provider required"end
    local current,err=state(square);if not current then return false,err end
    local plan,planErr=contribution(current,materialId,amount,operationId);if not plan then return false,planErr end
    if plan.duplicate then return true,{duplicate=true,state=copy(current)}end
    local record={schemaVersion=1,status="consuming",operationId=operationId,providerId=provider.id,
        materialId=materialId,offered=amount,accepted=plan.accepted,prior=plan.prior}
    current.materialRecovery=record;transmit(square)
    local ok,consumed,receipt=pcall(provider.consume,plan.accepted,copy(context or{}))
    if not ok then
        record.status="inspection_required";record.reason=tostring(consumed):sub(1,160);transmit(square)
        return false,"material consumption raised; inspection required",copy(record)
    end
    if consumed~=true then
        -- A false return is a provider guarantee that no material was consumed.
        current.materialRecovery=nil;transmit(square)
        return false,tostring(receipt or"material consumption rejected"):sub(1,160)
    end
    record.status="consumed";record.receipt=type(receipt)=="string"and receipt:sub(1,160)or nil;transmit(square)
    current.materials[materialId]=plan.prior+plan.accepted;remember(current,operationId)
    current.materialRecovery=nil;transmit(square)
    return true,{duplicate=false,accepted=plan.accepted,excess=plan.excess,state=copy(current),receipt=record.receipt}
end
function Projects.inspectMaterialRecovery(square)
    local current,err=state(square);if not current then return nil,err end
    local record=current.materialRecovery
    if record==nil then return{status="clear",requiresInspection=false}end
    if record.schemaVersion~=1 or type(record.operationId)~="string"or type(record.providerId)~="string"
        or type(record.materialId)~="string"then return{status="unsupported",requiresInspection=true}end
    local status=record.status=="consuming"and"inspection_required"or tostring(record.status or"inspection_required")
    return{status=status,requiresInspection=true,operationId=record.operationId,providerId=record.providerId,
        materialId=record.materialId,accepted=finite(record.accepted),reason=record.reason,receipt=record.receipt}
end
function Projects.advance(square,work,operationId,workerId)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    if workerId==nil or tostring(workerId)==""or #tostring(workerId)>128 then return false,"stable worker ID required"end
    local current,err=state(square);if not current then return false,err end
    if current.materialRecovery~=nil then return false,"project material transaction requires inspection"end
    if current.worldRecovery~=nil then return false,"project world transaction requires inspection"end
    if current.status~="active"then return false,"project is not active"end
    if seen(current,operationId)then return true,{duplicate=true,state=copy(current)}end
    work=finite(work);if not work or work<=0 then return false,"positive finite work required"end
    local accepted=math.min(work,current.workRequired-current.workCompleted)
    current.workCompleted=current.workCompleted+accepted;remember(current,operationId)
    local requirementsMet=current.workCompleted>=current.workRequired and materialsComplete(current)
    if requirementsMet then
        if current.deferCommit then current.status="ready";current.readyBy=tostring(workerId)
        else complete(square,current,workerId)end
    end
    transmit(square);return true,{duplicate=false,accepted=accepted,ready=current.status=="ready",completed=current.status=="completed",state=copy(current)}
end
function Projects.commitReady(square,operationId,provider,context)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    if type(provider)~="table"or type(provider.id)~="string"or provider.id==""or#provider.id>96
        or type(provider.commit)~="function"then return false,"world-commit provider required"end
    local current,err=state(square);if not current then return false,err end
    if current.materialRecovery~=nil then return false,"project material transaction requires inspection"end
    if current.worldRecovery~=nil then return false,"project world transaction requires inspection"end
    if current.status=="completed"and seen(current,operationId)then return true,{duplicate=true,state=copy(current)}end
    if current.status~="ready"or current.deferCommit~=true then return false,"project is not ready for world commit"end
    local record={schemaVersion=1,status="committing",operationId=operationId,providerId=provider.id}
    current.worldRecovery=record;transmit(square)
    local ok,committed,receipt=pcall(provider.commit,square,copy(context or{}))
    if not ok then
        record.status="inspection_required";record.reason=tostring(committed):sub(1,160);transmit(square)
        return false,"world commit raised; inspection required",copy(record)
    end
    if committed~=true then
        if type(receipt)=="table"and(receipt.committed==true or receipt.rolledBack~=true)then
            record.status="inspection_required";record.reason="world commit outcome uncertain";record.receipt=receiptSummary(receipt);transmit(square)
            return false,"world commit outcome uncertain; inspection required",copy(record)
        end
        current.worldRecovery=nil;transmit(square)
        return false,type(receipt)=="string"and receipt:sub(1,160)or"world commit rejected"
    end
    local summary=receiptSummary(receipt)
    current.worldRecovery=nil;remember(current,operationId);complete(square,current,current.readyBy or"unknown",summary);transmit(square)
    return true,{duplicate=false,state=copy(current),receipt=copy(summary)}
end
function Projects.inspectWorldRecovery(square)
    local current,err=state(square);if not current then return nil,err end
    local record=current.worldRecovery
    if record==nil then return{status="clear",requiresInspection=false}end
    if record.schemaVersion~=1 or type(record.operationId)~="string"or type(record.providerId)~="string"then
        return{status="unsupported",requiresInspection=true}
    end
    return{status=record.status=="committing"and"inspection_required"or tostring(record.status or"inspection_required"),
        requiresInspection=true,operationId=record.operationId,providerId=record.providerId,reason=record.reason,receipt=copy(record.receipt)}
end
function Projects.cancel(square,operationId,reason)
    if not canWrite()then return false,"non-authority"end
    if not operation(operationId)then return false,"bounded operation ID required"end
    local current,err=state(square);if not current then return false,err end
    if current.materialRecovery~=nil then return false,"project material transaction requires inspection"end
    if current.worldRecovery~=nil then return false,"project world transaction requires inspection"end
    if current.status~="active"then return false,"project is not active"end
    if seen(current,operationId)then return true,{duplicate=true,state=copy(current)}end
    current.status="cancelled";current.cancelReason=tostring(reason or"cancelled"):sub(1,256);remember(current,operationId);transmit(square)
    return true,{duplicate=false,state=copy(current)}
end
function Projects.snapshot(square)local current,err=state(square);return current and copy(current)or nil,err end

groundWorks.Projects=Projects
return Projects
