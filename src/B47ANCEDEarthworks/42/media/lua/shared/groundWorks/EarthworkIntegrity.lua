local groundWorks=require "groundWorks/API"
local Integrity={SCHEMA_VERSION=1,MAX_ERRORS=32,MAX_JOBS=1024,MAX_CELLS_PER_JOB=64}
local terminal={cancelled=true,filled=true}

local function finite(value)return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge end
local function add(result,message)
    result.errorCount=result.errorCount+1
    if#result.errors<Integrity.MAX_ERRORS then result.errors[#result.errors+1]=message end
end

function Integrity.audit(store)
    local result={schemaVersion=1,valid=true,errorCount=0,truncated=false,errors={},jobs=0,cells=0,stockpiles=0}
    if type(store)~="table"or store.schemaVersion~=1 or type(store.jobs)~="table"or type(store.cellOwners)~="table"
        or type(store.stockpiles)~="table"or type(store.processedOperations)~="table"then
        add(result,"unsupported earthwork store shape");result.valid=false;return result
    end
    local expected={}
    for id,job in pairs(store.jobs)do
        result.jobs=result.jobs+1
        if result.jobs>Integrity.MAX_JOBS then add(result,"job bound exceeded")end
        if type(id)~="string"or type(job)~="table"or job.schemaVersion~=1 or job.id~=id then add(result,"malformed job identity: "..tostring(id))
        elseif type(job.topology)~="table"or type(job.topology.cells)~="table"or#job.topology.cells<1 or#job.topology.cells>Integrity.MAX_CELLS_PER_JOB then
            add(result,"malformed job topology: "..id)
        else
            local observed={}
            if job.topology.count~=#job.topology.cells then add(result,"topology count mismatch: "..id)end
            for _,cell in ipairs(job.topology.cells)do
                local cellKey=type(cell)=="table"and cell.key or nil
                if type(cellKey)~="string"or observed[cellKey]then add(result,"malformed or duplicate job cell: "..id)
                else observed[cellKey]=true;result.cells=result.cells+1;if not terminal[job.status]then expected[cellKey]=id end end
            end
            if not finite(job.workRequired)or not finite(job.workCompleted)or job.workCompleted<0 or job.workCompleted>job.workRequired then add(result,"invalid excavation work ledger: "..id)end
            if not finite(job.soilVolume)or not finite(job.looseSoil)or not finite(job.reservedBackfillSoil)
                or job.soilVolume<=0 or job.looseSoil<0 or job.reservedBackfillSoil<0 then add(result,"invalid soil ledger: "..id)end
            if job.volumeType~=nil and type(job.volumeType)~="string"then add(result,"malformed volume type: "..id)end
            if job.fill~=nil then
                if type(job.fill)~="table"then add(result,"malformed fill ledger: "..id)
                else
                    for _,media in ipairs({"soil","water","concrete","fuel"})do
                        local value=job.fill[media]
                        if value~=nil and(not finite(value)or value<0)then add(result,"invalid fill media: "..id)end
                    end
                end
            end
            if job.occupants~=nil then
                if type(job.occupants)~="table"or not finite(job.occupants.items)or not finite(job.occupants.bodies)
                    or job.occupants.items<0 or job.occupants.bodies<0 then add(result,"invalid occupant ledger: "..id)end
            end
            if job.columns~=nil then
                if type(job.columns)~="table"or#job.columns~=#job.topology.cells then add(result,"malformed column ledger: "..id)end
            end
        end
    end
    for cellKey,owner in pairs(store.cellOwners)do
        if expected[cellKey]~=owner then add(result,"orphan or incorrect cell owner: "..tostring(cellKey))else expected[cellKey]=nil end
    end
    for cellKey in pairs(expected)do add(result,"missing cell reservation: "..cellKey)end
    for id,pile in pairs(store.stockpiles)do
        result.stockpiles=result.stockpiles+1
        if type(id)~="string"or type(pile)~="table"or pile.schemaVersion~=1 or pile.id~=id or not finite(pile.capacity)
            or not finite(pile.soil)or pile.capacity<=0 or pile.soil<0 or pile.soil>pile.capacity then add(result,"malformed stockpile: "..tostring(id))end
    end
    result.truncated=result.errorCount>#result.errors;result.valid=result.errorCount==0;return result
end

groundWorks.EarthworkIntegrity=Integrity
return Integrity
