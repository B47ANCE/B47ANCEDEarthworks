local groundWorks=require "groundWorks/API"
local Diagnostics={MAX_PAGE=64}

local function storeValid(store)
    return type(store)=="table"and store.schemaVersion==1 and type(store.jobs)=="table"and type(store.stockpiles)=="table"
end
local function boundedLimit(value)value=math.floor(tonumber(value)or 16);return math.max(1,math.min(Diagnostics.MAX_PAGE,value))end
local function ids(values)local result={};for id in pairs(values)do if type(id)=="string"then result[#result+1]=id end end;table.sort(result);return result end
local function jobRow(job)
    local fill=type(job.fill)=="table"and job.fill or{}
    local occupants=type(job.occupants)=="table"and job.occupants or{}
    return{id=job.id,type=job.type,volumeType=job.volumeType,status=job.status,cellCount=job.topology and job.topology.count or 0,targetDepth=job.targetDepth,
        surfaceCap=job.surfaceCap,workCompleted=job.workCompleted,workRequired=job.workRequired,fillWorkCompleted=job.fillWorkCompleted,
        fillWorkRequired=job.fillWorkRequired,soilVolume=job.soilVolume,looseSoil=job.looseSoil,
        reservedBackfillSoil=job.reservedBackfillSoil,fillSoil=tonumber(fill.soil)or 0,fillWater=tonumber(fill.water)or 0,
        fillConcrete=tonumber(fill.concrete)or 0,fillFuel=tonumber(fill.fuel)or 0,occupantItems=tonumber(occupants.items)or 0,
        occupantBodies=tonumber(occupants.bodies)or 0,geometryStatus=job.geometryTransaction and job.geometryTransaction.status or nil}
end

function Diagnostics.summary(store)
    if not storeValid(store)then return nil,"supported earthwork store required"end
    local result={schemaVersion=1,jobs=0,stockpiles=0,reservedCells=0,looseSoil=0,stockpiledSoil=0,
        reservedBackfillSoil=0,fillConcrete=0,occupantBodies=0,statuses={}}
    for _,job in pairs(store.jobs)do
        result.jobs=result.jobs+1;local status=tostring(job.status or"malformed");result.statuses[status]=(result.statuses[status]or 0)+1
        result.looseSoil=result.looseSoil+(tonumber(job.looseSoil)or 0)
        result.reservedBackfillSoil=result.reservedBackfillSoil+(tonumber(job.reservedBackfillSoil)or 0)
        local fill=type(job.fill)=="table"and job.fill or{}
        result.fillConcrete=result.fillConcrete+(tonumber(fill.concrete)or 0)
        local occupants=type(job.occupants)=="table"and job.occupants or{}
        result.occupantBodies=result.occupantBodies+(tonumber(occupants.bodies)or 0)
    end
    for _ in pairs(store.cellOwners or{})do result.reservedCells=result.reservedCells+1 end
    for _,pile in pairs(store.stockpiles)do result.stockpiles=result.stockpiles+1;result.stockpiledSoil=result.stockpiledSoil+(tonumber(pile.soil)or 0)end
    return result
end

function Diagnostics.listJobs(store,cursor,limit)
    if not storeValid(store)then return nil,"supported earthwork store required"end
    if cursor~=nil and(type(cursor)~="string"or store.jobs[cursor]==nil)then return nil,"invalid earthwork cursor"end
    local ordered=ids(store.jobs);local start=1
    if cursor then for index,id in ipairs(ordered)do if id==cursor then start=index+1;break end end end
    limit=boundedLimit(limit);local rows,nextCursor={},nil
    for index=start,math.min(#ordered,start+limit-1)do rows[#rows+1]=jobRow(store.jobs[ordered[index]])end
    if start+#rows-1<#ordered and#rows>0 then nextCursor=rows[#rows].id end
    return{schemaVersion=1,cursor=cursor,nextCursor=nextCursor,limit=limit,jobs=rows,total=#ordered}
end

function Diagnostics.report(store,cursor,limit)
    local summary,err=Diagnostics.summary(store);if not summary then return nil,err end
    local page,pageErr=Diagnostics.listJobs(store,cursor,limit);if not page then return nil,pageErr end
    return{schemaVersion=1,summary=summary,page=page}
end

groundWorks.EarthworkDiagnostics=Diagnostics
return Diagnostics
