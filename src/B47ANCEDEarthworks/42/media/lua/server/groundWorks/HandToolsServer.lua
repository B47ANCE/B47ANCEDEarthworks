local API=require "groundWorks/Load"
local HandTools=API.HandTools
local Jobs=API.EarthworkJobs
local Persistence=API.EarthworkPersistence
local Cavity=API.Cavity
local VolumeRuntime=API.VolumeRuntime
local Engine=require "groundWorks/CavityEngine"
local VolumeTypes=API.VolumeTypes
local Server={MODULE="groundWorks",COMMANDS={handExcavate=true,handOperate=true},RESULT="handOperateResult",installed=false}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...);if called then return result end
end
local function canWrite()
    return not(type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))
end
local function transmitStore()
    if isServer()and ModData and type(ModData.transmit)=="function"then pcall(ModData.transmit,Persistence.STORE_KEY)end
end
local function respond(player,ok,message,extra)
    extra=type(extra)=="table"and extra or{}
    extra.ok=ok==true;extra.message=tostring(message or"")
    if isServer()then
        sendServerCommand(player,Server.MODULE,Server.RESULT,extra)
    elseif player and player.Say then player:Say(extra.message)end
    print("[groundWorks][HandTools] "..tostring(extra.ok).." "..extra.message)
end
local function squareAt(player,args)
    if type(args)~="table"then return nil end
    local x,y,z=tonumber(args.x),tonumber(args.y),tonumber(args.z)
    if not x or not y or not z then return nil end
    local cell=getCell();if not cell then return nil end
    local square=cell:getGridSquare(x,y,z)
    if not square then return nil end
    local reach=HandTools.squareReachable(player,square)
    if not reach then return nil end
    return square
end
local function matchingTool(player,fullType)
    local tool=HandTools.findTool(player)
    if not tool then return nil end
    if type(fullType)=="string"and fullType~=""and tool.fullType~=fullType then
        local primary=HandTools.inspectItem(call(player,"getPrimaryHandItem"))
        if primary and primary.fullType==fullType then return primary end
    end
    return tool
end
local function wearTool(player,tool)
    local item=tool and tool.item
    if not item then return end
    local wear=tonumber(tool.wear)or 0
    if wear<=0 then return end
    if type(ZombRand)=="function"and ZombRand(20)~=0 then return end
    local condition=tonumber(call(item,"getCondition"))or 0
    pcall(function()item:setCondition(math.max(0,condition-wear))end)
    if isServer()then pcall(function()sendItemStats(item)end)end
end
local function consumeItem(player,source,amount)
    local item=source and source.item
    if not item then return false end
    local container=call(item,"getContainer")
    if not container or call(container,"contains",item)~=true then return false end
    local ok,result=pcall(function()
        if source.consume=="fluid"then
            local fluid=item:getFluidContainer()
            local before=fluid:getAmount()
            if before<amount then return false end
            fluid:removeFluid(amount)
            sendItemStats(item)
            return fluid:getAmount()<before
        end
        if (tonumber(call(item,"getCurrentUsesFloat"))or 0)<=0 then return false end
        item:Use()
        sendItemStats(item)
        return true
    end)
    return ok and result==true
end
local function maybeFillBag(player,job,square,operationId)
    if not job or (tonumber(job.looseSoil)or 0)<1 then return nil end
    local opening=HandTools.openingSquare(square)
    local ok=require('groundWorks/SpoilExchange').perform(player,opening,'bag',operationId..'.bag')
    return ok and 'Base.Dirtbag' or nil
end
local function pourMaterial(player,store,job,source,media,operationId)
    -- Validate using the same job rules before consuming anything. Lua executes
    -- the real commit without yielding between this preview and consumption.
    local preview={schemaVersion=store.schemaVersion,jobs={[job.id]=Jobs.snapshot(store,job.id)},
        cellOwners=store.cellOwners,stockpiles=store.stockpiles,processedOperations={}}
    local requested=source.amount or 1
    local allowed,result=Jobs.pour(preview,job.id,media,requested,operationId,HandTools.PROVIDER_ID,{})
    if not allowed then return false,result end
    if result.duplicate then return true,result end
    if not consumeItem(player,source,result.accepted)then return false,getText("IGUI_groundWorks_NeedMedia")end
    return Jobs.pour(store,job.id,media,result.accepted,operationId,HandTools.PROVIDER_ID,{actor=call(player,"getUsername")})
end
local function ensureJob(store,square,volumeType,operationId,player)
    local existing=Jobs.jobAtCell(store,square:getX(),square:getY(),0)
    if existing then
        local definition=VolumeTypes.get(volumeType)
        local wanted=definition and definition.jobType
        if existing.volumeType~=volumeType and existing.type~=wanted then
            return nil,existing.id,"this ground already has a different earthwork job"
        end
        if existing.status~="active"and existing.status~="ready_to_excavate"and existing.status~="geometry_committing"then
            return nil,existing.id,"this excavation is "..tostring(existing.status)
        end
        return existing,existing.id
    end
    local baseId=HandTools.jobId(square)
    local jobId=baseId
    local generation=0
    while store.jobs[jobId]do generation=generation+1;jobId=baseId..":"..generation end
    local username=tostring(call(player,"getUsername")or"hand")
    local ok,result=Jobs.create(store,{
        id=jobId,type=volumeType,targetDepth=1,workRequired=HandTools.WORK_REQUIRED,
        fillWorkRequired=HandTools.WORK_REQUIRED,soilVolume=1,
        cells={{x=math.floor(square:getX()),y=math.floor(square:getY()),z=0}},
        createdBy=username,worldAgeHours=getGameTime()and getGameTime():getWorldAgeHours()or nil,
    },operationId..".job")
    if not ok then return nil,jobId,result end
    return result.job,jobId
end
local MachineGeometry=require "groundWorks/MachineGeometry"
local commitLive=MachineGeometry.excavate
local closeLive=MachineGeometry.close

local function excavate(player,square,args)
    local volumeType=HandTools.volumeId(args and args.volumeType)
    local allowed,details=HandTools.canExcavate(player,square,volumeType)
    if not allowed then return false,details end
    local operationId=args.operationId
    local tool=matchingTool(player,args.fullType)or details.tool
    if not tool then return false,getText("IGUI_groundWorks_NeedTool")end
    local store=Persistence.getStore()
    if not store then return false,"earthwork store unattached"end
    local job,jobId,jobErr=ensureJob(store,square,details.volumeType,operationId,player)
    if not job then return false,tostring(jobErr or"could not start excavation")end
    if job.status=="active"then
        local applied,applyResult=Jobs.applyWork(store,jobId,"excavate",tool.work,operationId..".work",HandTools.PROVIDER_ID,{actor=call(player,"getUsername"),tool=tool.fullType})
        if not applied then return false,tostring(applyResult)end
        job=applyResult.job or Jobs.snapshot(store,jobId)
    end
    wearTool(player,tool)
    local bag
    local opened=false
    if job.status=="ready_to_excavate"then
        job,opened=commitLive(square,store,jobId,operationId,details.volumeType,player)
    end
    if opened then bag=maybeFillBag(player,job,square,operationId)end
    local completed=job and tonumber(job.workCompleted)or 0
    local required=job and tonumber(job.workRequired)or HandTools.WORK_REQUIRED
    local message
    if opened then message=getText("IGUI_groundWorks_PitOpen")
    elseif job and job.status=="excavated"then message=getText("IGUI_groundWorks_PitRecorded")
    elseif job and job.status=="quarantined"then message=getText("IGUI_groundWorks_PitUncertain")
    else message=getText("IGUI_groundWorks_Dug",tostring(math.floor(completed)),tostring(math.floor(required)))end
    if bag then message=message.." "..getText("IGUI_groundWorks_FilledDirtBag")end
    return true,message,{opened=opened==true,status=job and job.status,workCompleted=completed,workRequired=required}
end

local function deepen(player,square,args)
    local allowed,details=HandTools.canDeepen(player,square)
    if not allowed then return false,details end
    local opening=details.opening or HandTools.openingSquare(square)
    local operationId=args.operationId
    local tool=matchingTool(player,args.fullType)or details.tool
    if not tool then return false,getText("IGUI_groundWorks_NeedTool")end
    local store=Persistence.getStore()
    if not store then return false,"earthwork store unattached"end
    local job=Jobs.jobAtCell(store,opening:getX(),opening:getY(),0)
    if not job then return false,getText("IGUI_groundWorks_NeedOpenVolume")end
    local jobId=job.id
    if job.status=="excavated"then
        local begun,beginErr=Jobs.beginDeepen(store,jobId,operationId..".begin")
        if not begun then return false,tostring(beginErr)end
        job=Jobs.snapshot(store,jobId)
    end
    if job.status=="active"and job.pendingDeepen==true then
        local applied,applyResult=Jobs.applyWork(store,jobId,"excavate",tool.work,operationId..".work",HandTools.PROVIDER_ID,{actor=call(player,"getUsername"),tool=tool.fullType,deepen=true})
        if not applied then return false,tostring(applyResult)end
        job=applyResult.job or Jobs.snapshot(store,jobId)
        wearTool(player,tool)
    end
    local bag
    local opened=false
    if job.status=="ready_to_excavate"and job.pendingDeepen==true then
        local adapter=Engine.adapter()
        local worldOk,worldErr=Cavity.deepen(opening,operationId,adapter,{volumeType=details.volumeType,jobId=jobId,actor=player})
        if worldOk==true then
            local finished,finishErr=Jobs.finishDeepen(store,jobId,operationId..".finish")
            if not finished then return false,tostring(finishErr)end
            job=Jobs.snapshot(store,jobId)
            opened=true
            VolumeRuntime.sync(opening,job,adapter)
        else
            print("[groundWorks][HandTools] deepen failed: "..tostring(worldErr))
            local reason=tostring(worldErr or"")
            if reason:find("not valid",1,true)or reason:find("does not allow",1,true)then
                Jobs.abortDeepen(store,jobId,operationId..".abort")
                job=Jobs.snapshot(store,jobId)
            end
            return false,getText("IGUI_groundWorks_DeepenFailed"),{status=job and job.status}
        end
    end
    if opened then bag=maybeFillBag(player,job,square,operationId)end
    local completed=job and tonumber(job.workCompleted)or 0
    local required=job and tonumber(job.workRequired)or HandTools.WORK_REQUIRED
    local depth=job and tonumber(job.targetDepth)or 1
    local message
    if opened then message=getText("IGUI_groundWorks_Deeper",tostring(math.floor(depth)),tostring(math.floor(details.maxDepth or depth)))
    elseif job and job.status=="excavated"then message=getText("IGUI_groundWorks_PitRecorded")
    else message=getText("IGUI_groundWorks_DiggingDeeper",tostring(math.floor(completed)),tostring(math.floor(required)))end
    if bag then message=message.." "..getText("IGUI_groundWorks_FilledDirtBag")end
    return true,message,{opened=opened==true,status=job and job.status,workCompleted=completed,workRequired=required,targetDepth=depth}
end

local function fill(player,square,args)
    local allowed,details=HandTools.canFill(player,square)
    if not allowed then return false,details end
    local opening=details.opening or HandTools.openingSquare(square)
    local store=Persistence.getStore();if not store then return false,"earthwork store unattached"end
    local job=Jobs.jobAtCell(store,opening:getX(),opening:getY(),0)
    if not job then return false,getText("IGUI_groundWorks_NeedOpenVolume")end
    local operationId=args.operationId
    local source=job.status=="excavated"and HandTools.findMedia(player,"soil")or nil
    if source then
        local poured,pourErr=pourMaterial(player,store,job,source,"soil",operationId..".pour")
        if not poured then return false,tostring(pourErr)end
        job=Jobs.snapshot(store,job.id)
        local adapter=Engine.adapter()
        VolumeRuntime.sync(opening,job,adapter)
        if job and(tonumber(job.fill and job.fill.soil)or 0)>=(tonumber(job.soilVolume)or 1)then
            local closedJob,closed=closeLive(opening,store,job,operationId)
            job=closedJob or job
            if closed then return true,getText("IGUI_groundWorks_FilledIn"),{status=job and job.status}end
        end
        return true,getText("IGUI_groundWorks_AddedSoil"),{status=job and job.status}
    end
    local tool=matchingTool(player,args.fullType)or HandTools.findTool(player)
    if not tool then return false,getText("IGUI_groundWorks_NeedTool")end
    if job.status=="excavated"then
        local begun,beginErr=Jobs.beginBackfill(store,job.id,operationId..".backfill")
        if not begun then return false,tostring(beginErr)end
        job=Jobs.snapshot(store,job.id)
    end
    if job.status=="backfilling"then
        local applied,applyResult=Jobs.applyWork(store,job.id,"fill",tool.work,operationId..".work",HandTools.PROVIDER_ID,{actor=call(player,"getUsername")})
        if not applied then return false,tostring(applyResult)end
        job=applyResult.job or Jobs.snapshot(store,job.id)
    end
    wearTool(player,tool)
    if job.status=="ready_to_backfill"then
        local geomOp=operationId..".geom"
        Jobs.beginGeometryCommit(store,job.id,geomOp)
        job=Jobs.snapshot(store,job.id)
        local adapter=Engine.adapter()
        local closed=VolumeRuntime.close(opening,adapter)==true
        if job.status=="geometry_committing"then
            local Geometry=API.EarthworkGeometry
            local plan=Geometry.plan(job,geomOp,"backfill")
            if closed and plan then
                local receipt={schemaVersion=1,operationId=geomOp,jobId=job.id,mode="backfill",outcome="committed",verified=true,cells={}}
                for _,cell in ipairs(plan.cells)do
                    receipt.cells[#receipt.cells+1]={surfaceKey=cell.surfaceKey,undergroundKey=cell.undergroundKey,verified=true}
                end
                Jobs.resolveGeometryCommit(store,job.id,geomOp,"committed",receipt)
            else
                Jobs.resolveGeometryCommit(store,job.id,geomOp,closed and"committed"or"uncertain",{
                    schemaVersion=1,operationId=geomOp,jobId=job.id,mode="backfill",outcome=closed and"committed"or"uncertain",verified=closed==true,cells={},
                })
            end
            job=Jobs.snapshot(store,job.id)
        end
        if not closed then return false,getText("IGUI_groundWorks_PitUncertain"),{status=job and job.status}end
        return true,getText("IGUI_groundWorks_FilledIn"),{status=job and job.status}
    end
    local completed=job and tonumber(job.fillWorkCompleted)or 0
    local required=job and tonumber(job.fillWorkRequired)or HandTools.WORK_REQUIRED
    return true,getText("IGUI_groundWorks_Filling",tostring(math.floor(completed)),tostring(math.floor(required))),{status=job and job.status}
end

local function pour(player,square,args)
    local media=args.media
    local allowed,details=HandTools.canPour(player,square,media)
    if not allowed then return false,details end
    local opening=details.opening or HandTools.openingSquare(square)
    local store=Persistence.getStore();if not store then return false,"earthwork store unattached"end
    local job=Jobs.jobAtCell(store,opening:getX(),opening:getY(),0)
    if not job then return false,getText("IGUI_groundWorks_NeedOpenVolume")end
    local source=HandTools.findMedia(player,media)
    if not source then return false,getText("IGUI_groundWorks_NeedMedia")end
    local poured,pourErr=pourMaterial(player,store,job,source,media,args.operationId..".pour")
    if not poured then return false,tostring(pourErr)end
    job=Jobs.snapshot(store,job.id)
    local synced,syncErr=VolumeRuntime.sync(opening,job,Engine.adapter())
    if not synced then return false,"Material recorded; world update needs inspection: "..tostring(syncErr),{status=job.status}end
    if media=="water"then return true,getText("IGUI_groundWorks_PouredWater"),{status=job.status}
    elseif media=="concrete"then
        if job.surfaceCap=="sealed"then return true,getText("IGUI_groundWorks_SealedConcrete"),{status=job.status}end
        return true,getText("IGUI_groundWorks_PouredConcrete"),{status=job.status}
    elseif media=="fuel"then return true,getText("IGUI_groundWorks_AddedFuel"),{status=job.status}end
    return true,getText("IGUI_groundWorks_Poured"),{status=job.status}
end

local function ignite(player,square,args)
    local allowed,details=HandTools.canIgnite(player,square)
    if not allowed then return false,details end
    local opening=details.opening or HandTools.openingSquare(square)
    if not VolumeRuntime.ignite(opening,Engine.adapter())then return false,getText("IGUI_groundWorks_IgniteFailed")end
    details.tool.item:Use();sendItemStats(details.tool.item)
    return true,getText("IGUI_groundWorks_Ignited"),{status="excavated"}
end

function Server.perform(player,args)
    if not canWrite()then return end
    if not HandTools.enabled()then respond(player,false,getText("IGUI_groundWorks_HandDisabled"));return end
    local square=squareAt(player,args)
    if not square then respond(player,false,getText("IGUI_groundWorks_HandTooFar"));return end
    local operationId=type(args)=="table"and type(args.operationId)=="string"and args.operationId or nil
    if not operationId or operationId==""or#operationId>96 or operationId:find("[%c]")then respond(player,false,"bounded operation ID required");return false end
    local store=Persistence.getStore()
    if not store then respond(player,false,"earthwork store unattached");return false end
    store.handReceipts=store.handReceipts or{}
    for _,receipt in ipairs(store.handReceipts)do
        if receipt.id==operationId then return receipt.ok end
    end
    local op=type(args)=="table"and args.op or"excavate"
    local ok,message,extra
    if op=="excavate"then ok,message,extra=excavate(player,square,args)
    elseif op=="deepen"then ok,message,extra=deepen(player,square,args)
    elseif op=="fill"then ok,message,extra=fill(player,square,args)
    elseif op=="pour"then ok,message,extra=pour(player,square,args)
    elseif op=="ignite"then ok,message,extra=ignite(player,square,args)
    elseif op=='routeStart'or op=='routeSupply'or op=='routeWork'then
        ok,message=require('groundWorks/RouteWorkServer').perform(player,square,args)
    else ok,message=false,"unknown hand operation"end
    store.handReceipts[#store.handReceipts+1]={id=operationId,ok=ok==true}
    while#store.handReceipts>128 do table.remove(store.handReceipts,1)end
    transmitStore()
    respond(player,ok==true,message,extra)
    return ok==true
end

function Server.onClientCommand(module,command,player,args)
    if module~=Server.MODULE or not Server.COMMANDS[command]then return end
    -- MP work is accepted only through the native timed-action completion.
    if isServer()then return end
    return Server.perform(player,args)
end

function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnClientCommand or type(events.OnClientCommand.Add)~="function"then return false,"OnClientCommand unavailable"end
    events.OnClientCommand.Add(Server.onClientCommand);Server.installed=true;return true
end
return Server
