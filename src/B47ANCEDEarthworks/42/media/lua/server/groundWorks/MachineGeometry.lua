local API=require "groundWorks/Load"
local Jobs=API.EarthworkJobs
local Cavity=API.Cavity
local Engine=require "groundWorks/CavityEngine"
local VolumeRuntime=API.VolumeRuntime
local Geometry={}

local function authority()
    return not(type(isClient)=="function"and isClient()==true)
end
local function operation(value)
    return type(value)=="string"and#value>0 and#value<=120 and not value:find("[%c]")
end
local function singleColumn(surface,current)
    local topology=current and current.topology
    if type(topology)~="table"or type(topology.cells)~="table"or#topology.cells~=1 or topology.count~=1 then
        return false,"Multi-cell jobs require the footprint geometry API."
    end
    local cell=topology.cells[1]
    if not surface or surface:getZ()~=0 or cell.z~=0
        or cell.x~=surface:getX()or cell.y~=surface:getY()then
        return false,"Surface does not match the earthwork job footprint."
    end
    return true
end

-- Compatibility entry point for hand and machine providers. A receipt from
-- Cavity covers one column; never commit a larger job using that receipt.
function Geometry.excavate(surface,store,jobId,operationId,volumeType,player,context)
    local current,reason=Jobs.snapshot(store,jobId)
    if not authority()then return current,false,"non-authority"end
    if not operation(operationId)then return current,false,"bounded operation ID required"end
    if not current then return nil,false,reason end
    local allowed,err=singleColumn(surface,current)
    if not allowed then return current,false,err end
    if volumeType~=current.volumeType then return current,false,"Volume type does not match the earthwork job."end
    if current.status~="ready_to_excavate"then return current,false,"Earthwork job is not ready to excavate."end
    local preserveSurface=type(context)=='table'and context.preserveSurface==true
    local plan,planErr=Cavity.plan(surface,{volumeType=volumeType,targetDepth=current.targetDepth,preserveSurface=preserveSurface})
    if not plan then return current,false,planErr end
    local geomOp=operationId..".geom"
    local begun,beginErr=Jobs.beginGeometryCommit(store,jobId,geomOp)
    current=Jobs.snapshot(store,jobId)
    if not begun or not current or current.status~="geometry_committing"then return current,false,beginErr end
    local adapter=Engine.adapter()
    local called,result,execErr=pcall(Cavity.execute,surface,operationId,adapter,{
        volumeType=volumeType,jobId=jobId,actor=player,experimental=false,targetDepth=current.targetDepth,
        preserveSurface=preserveSurface,
    })
    local succeeded=called and result==true
    local failure=called and execErr or result
    local inspected,state=pcall(Cavity.inspect,surface)
    local unchanged=not succeeded and inspected and state
        and(state.status=="clear"or(state.status=="failed"and state.requiresInspection~=true))
    local outcome=succeeded and"committed"or unchanged and"rolled_back"or"uncertain"
    local receipt=Cavity.geometryReceipt(plan,geomOp,jobId,"excavate",outcome)
    local resolved,resolveErr=Jobs.resolveGeometryCommit(store,jobId,geomOp,outcome,receipt)
    if not resolved then
        Jobs.resolveGeometryCommit(store,jobId,geomOp,"uncertain",receipt)
        return Jobs.snapshot(store,jobId),false,"Geometry receipt requires inspection: "..tostring(resolveErr)
    end
    if not succeeded then
        return Jobs.snapshot(store,jobId),false,tostring(failure or"Cavity excavation failed.")
    end
    return Jobs.snapshot(store,jobId),true
end

function Geometry.close(surface,store,job,operationId)
    if not authority()then return job,false,"non-authority"end
    if not operation(operationId)then return job,false,"bounded operation ID required"end
    local current,err=Jobs.snapshot(store,job and job.id)
    if not current then return job,false,err end
    local allowed,reason=singleColumn(surface,current)
    if not allowed then return current,false,reason end
    local preview={schemaVersion=store.schemaVersion,jobs={[current.id]=current},
        cellOwners={},stockpiles={},processedOperations={}}
    local accepted,closeErr=Jobs.closeVolume(preview,current.id,operationId..".close")
    if not accepted then return Jobs.snapshot(store,current.id),false,closeErr end
    local called,worldOk,worldErr=pcall(VolumeRuntime.close,surface,Engine.adapter())
    if not called or worldOk~=true then return Jobs.snapshot(store,current.id),false,called and worldErr or worldOk end
    local closed,ledgerErr=Jobs.closeVolume(store,current.id,operationId..".close")
    if not closed then return Jobs.snapshot(store,current.id),false,ledgerErr end
    return Jobs.snapshot(store,current.id),true
end

return Geometry
