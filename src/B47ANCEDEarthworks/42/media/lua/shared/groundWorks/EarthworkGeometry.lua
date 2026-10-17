local groundWorks=require "groundWorks/API"
local VolumeTypes=require "groundWorks/VolumeTypes"
local Geometry={SCHEMA_VERSION=1,MAX_CELLS=64}

local function identifier(value)return type(value)=="string"and value~=""and#value<=128 end
local function key(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
local function copy(value)
    if type(value)~="table"then return value end
    local result={};for name,child in pairs(value)do result[name]=copy(child)end;return result
end
local function depthOf(job)
    local depth=tonumber(job and job.targetDepth)or 1
    if depth~=math.floor(depth)or depth<1 or depth>VolumeTypes.MAX_DEPTH then return nil end
    return depth
end

function Geometry.plan(job,operationId,mode)
    if type(job)~="table"or job.schemaVersion~=1 or type(job.topology)~="table"then return nil,"supported job required"end
    if not identifier(operationId)then return nil,"bounded operation ID required"end
    if mode~="excavate"and mode~="backfill"then return nil,"geometry mode must be excavate or backfill"end
    local source=job.topology.cells
    if type(source)~="table"or#source<1 or#source>Geometry.MAX_CELLS then return nil,"bounded topology required"end
    local depth=depthOf(job);if not depth then return nil,"bounded target depth required"end
    local plan={schemaVersion=1,operationId=operationId,jobId=job.id,mode=mode,targetDepth=depth,cells={}}
    for index,cell in ipairs(source)do
        if type(cell)~="table"or type(cell.x)~="number"or type(cell.y)~="number"or cell.z~=0 then
            return nil,"invalid topology cell at index "..index
        end
        local cavityKeys={}
        for z=-1,-depth,-1 do cavityKeys[#cavityKeys+1]=key(cell.x,cell.y,z)end
        plan.cells[#plan.cells+1]={
            surfaceKey=key(cell.x,cell.y,0),undergroundKey=key(cell.x,cell.y,-depth),
            openingKey=key(cell.x,cell.y,0),cavityKey=key(cell.x,cell.y,-1),cavityKeys=cavityKeys,
            x=cell.x,y=cell.y,surfaceZ=0,undergroundZ=-depth,targetDepth=depth,variant=cell.variant,mask=cell.mask,
        }
    end
    return copy(plan)
end

function Geometry.verifyReceipt(plan,receipt,outcome)
    if type(plan)~="table"or plan.schemaVersion~=1 or type(plan.cells)~="table"then return false,"supported geometry plan required"end
    if type(receipt)~="table"or receipt.schemaVersion~=1 or receipt.verified~=true then return false,"verified geometry receipt required"end
    if receipt.operationId~=plan.operationId or receipt.jobId~=plan.jobId or receipt.mode~=plan.mode then return false,"geometry receipt identity mismatch"end
    if outcome~="committed"and outcome~="rolled_back"then return false,"verifiable geometry outcome required"end
    if receipt.outcome~=outcome or type(receipt.cells)~="table"or#receipt.cells~=#plan.cells then return false,"geometry receipt coverage mismatch"end
    local expected={};for _,cell in ipairs(plan.cells)do expected[cell.surfaceKey.."|"..cell.undergroundKey]=true end
    local observed={}
    for _,cell in ipairs(receipt.cells)do
        if type(cell)~="table"or cell.verified~=true then return false,"every geometry receipt cell must be verified"end
        local identity=tostring(cell.surfaceKey or"").."|"..tostring(cell.undergroundKey or"")
        if not expected[identity]or observed[identity]then return false,"geometry receipt cell mismatch"end
        observed[identity]=true
    end
    return true
end

function Geometry.liveDepthAllowed(plan)
    local depth=tonumber(plan and plan.targetDepth)or 1
    return depth==math.floor(depth)and depth>=1 and depth<=VolumeTypes.MAX_DEPTH
end

groundWorks.EarthworkGeometry=Geometry
return Geometry
