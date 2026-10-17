local API=require "groundWorks/Load"
local Cavity=API.Cavity
local Jobs=API.EarthworkJobs
local Persistence=API.EarthworkPersistence
local Engine=require "groundWorks/CavityEngine"
local Server={MODULE="groundWorks",CREATE="openPit",STATUS="openPitStatus",CLIMB="cavityClimb",installed=false}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...);if called then return result end
end
local function surfaceFor(player,args)
    local square=player and player:getCurrentSquare()or nil;if not square then return nil end
    if type(args)~="table"or tonumber(args.x)~=square:getX()or tonumber(args.y)~=square:getY()or tonumber(args.z)~=square:getZ()then return nil end
    return square
end
local function volumeId(args)
    local requested=type(args)=="table"and args.volumeType or nil
    if requested=="groundWorks.grave"or requested=="grave"then return"groundWorks.grave"end
    return"groundWorks.openPit"
end
local function ensureJob(surface,operationId,volumeType)
    local store=Persistence.getStore()
    if not store then return nil,nil,nil,"earthwork store unattached"end
    local x,y=math.floor(surface:getX()),math.floor(surface:getY())
    local jobId="cavity:"..tostring(x)..":"..tostring(y)
    local existing=Jobs.snapshot(store,jobId)
    if existing then return store,jobId,existing end
    local ok,result=Jobs.create(store,{
        id=jobId,type=volumeType,targetDepth=1,workRequired=1,fillWorkRequired=1,soilVolume=1,
        cells={{x=x,y=y,z=0}},createdBy="openPit",
    },operationId..".job")
    if not ok then return store,jobId,nil,result end
    return store,jobId,result.job
end
local function prepareGeometry(store,jobId,operationId)
    local current=Jobs.snapshot(store,jobId)
    if not current then return false,"unknown earthwork job"end
    if current.status=="active"then
        local ok,err=Jobs.applyWork(store,jobId,"excavate",1,operationId..".work","groundWorks.cavity.manual.v1",{actor="openPit"})
        if not ok then return false,err end
        current=Jobs.snapshot(store,jobId)
    end
    if current and current.status=="ready_to_excavate"then
        return Jobs.beginGeometryCommit(store,jobId,operationId..".geom")
    end
    return current and current.status=="geometry_committing",current and current.status
end

function Server.onClientCommand(module,command,player,args)
    if module~=Server.MODULE then return end
    if command~=Server.CREATE and command~=Server.STATUS and command~=Server.CLIMB then return end
    local adapter=Engine.adapter()
    if command==Server.CLIMB then
        local square=player and player:getCurrentSquare()or nil
        if not square then print("[groundWorks][OpenPit] climb rejected: no square");return end
        local destination,err,target=Cavity.climbFromPlayer(player,adapter)
        if not destination then print("[groundWorks][OpenPit] climb rejected: "..tostring(err));return end
        target=target or adapter.getSquare(destination.x,destination.y,destination.z)
        if not target then print("[groundWorks][OpenPit] climb rejected: destination missing");return end
        local moved,moveErr=Engine.movePlayer(player,target)
        print("[groundWorks][OpenPit] climb "..tostring(destination.direction).." ok="..tostring(moved==true).." "..tostring(moveErr or""))
        return
    end
    if not Cavity.liveEnabled()then print("[groundWorks][OpenPit] rejected: debug/admin or EnableLiveOpenPit required");return end
    local surface=surfaceFor(player,args);if not surface then print("[groundWorks][OpenPit] rejected: stand on the exact target square");return end
    if command==Server.STATUS then
        local status,err=Cavity.verifyCurrent(surface,adapter)
        print("[groundWorks][OpenPit] status="..tostring(status and status.status or err)..
            " squareResolved="..tostring(status and status.squareResolved).." floorResolved="..tostring(status and status.floorResolved)..
            " openingResolved="..tostring(status and status.openingResolved).." geometryResolved="..tostring(status and status.geometryResolved)..
            " requiresInspection="..tostring(status and status.requiresInspection))
        return
    end
    local volumeType=volumeId(args)
    local operationId=type(args)=="table"and type(args.operationId)=="string"and args.operationId or nil
    if type(operationId)~="string"then print("[groundWorks][OpenPit] rejected: operation ID required");return end
    local store,jobId,_,jobErr=ensureJob(surface,operationId,volumeType)
    if jobErr then print("[groundWorks][OpenPit] job: "..tostring(jobErr))end
    if store and jobId then prepareGeometry(store,jobId,operationId)end
    local ok,result,details=Cavity.execute(surface,operationId,adapter,{volumeType=volumeType,jobId=jobId,actor=player,experimental=false})
    local receipt=type(result)=="table"and result or details
    if store and jobId then
        local current=Jobs.snapshot(store,jobId)
        if current and current.status=="geometry_committing"then
            local geomOp=operationId..".geom"
            local plan=Cavity.plan(surface,{volumeType=volumeType})
            if ok then
                local geom=Cavity.geometryReceipt(plan,geomOp,jobId,"excavate","committed")
                local resolved,resolveErr=Jobs.resolveGeometryCommit(store,jobId,geomOp,"committed",geom)
                if not resolved then print("[groundWorks][OpenPit] geometry resolve: "..tostring(resolveErr))end
            else
                Jobs.resolveGeometryCommit(store,jobId,geomOp,"uncertain",{schemaVersion=1,operationId=geomOp,jobId=jobId,mode="excavate",verified=false,cells={}})
            end
        end
    end
    print("[groundWorks][OpenPit] ok="..tostring(ok).." result="..tostring(type(result)=="string"and result or receipt and receipt.status).." job="..tostring(jobId))
end

function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnClientCommand or type(events.OnClientCommand.Add)~="function"then return false,"OnClientCommand unavailable"end
    events.OnClientCommand.Add(Server.onClientCommand);Server.installed=true;return true
end
return Server
