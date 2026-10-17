local groundWorks=require "groundWorks/API"
local Cavity=require "groundWorks/Cavity"
local VolumeRuntime={LIVE_MAX_DEPTH=Cavity.LIVE_MAX_DEPTH}

local function fillOf(job)
    return type(job)=="table"and type(job.fill)=="table"and job.fill or{}
end
local function totals(fill)
    return(tonumber(fill.soil)or 0)+(tonumber(fill.water)or 0)+(tonumber(fill.concrete)or 0)+(tonumber(fill.fuel)or 0)
end

function VolumeRuntime.sync(surface,job,adapter)
    if not surface or type(job)~="table"or type(adapter)~="table"then return false,"surface, job and adapter required"end
    local fill=fillOf(job)
    local capacity=tonumber(job.soilVolume)or 1
    if job.status=="filled"then return Cavity.close(surface,adapter)end
    if job.surfaceCap=="sealed"or(tonumber(fill.concrete)or 0)>=capacity then
        return Cavity.seal(surface,adapter,job)
    end
    if totals(fill)>0 then return Cavity.applyFill(surface,adapter,job)end
    return true,job
end

function VolumeRuntime.ignite(surface,adapter)
    return Cavity.ignite(surface,adapter)
end

function VolumeRuntime.close(surface,adapter)
    return Cavity.close(surface,adapter)
end

groundWorks.VolumeRuntime=VolumeRuntime
return VolumeRuntime
