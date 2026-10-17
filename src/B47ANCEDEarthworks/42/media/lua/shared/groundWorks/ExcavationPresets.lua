local groundWorks = require "groundWorks/API"

local Presets = {}
Presets.DIRECTIONS = { "north", "east", "south", "west" }

local definitions = {
    { id="trench_1x3", label="Trench 1 x 3", kind="trench", width=1, length=3 },
    { id="trench_1x5", label="Trench 1 x 5", kind="trench", width=1, length=5 },
    { id="trench_1x7", label="Trench 1 x 7", kind="trench", width=1, length=7 },
    { id="moat_2x3", label="Moat 2 x 3", kind="moat", width=2, length=3 },
    { id="moat_2x5", label="Moat 2 x 5", kind="moat", width=2, length=5 },
    { id="moat_2x7", label="Moat 2 x 7", kind="moat", width=2, length=7 },
    { id="basement_3x3", label="Basement 3 x 3", kind="basement", width=3, length=3 },
    { id="basement_3x5", label="Basement 3 x 5", kind="basement", width=3, length=5 },
    { id="basement_5x5", label="Basement 5 x 5", kind="basement", width=5, length=5 },
    { id="basement_7x7", label="Basement 7 x 7", kind="basement", width=7, length=7 },
}
local byId = {}
for _, definition in ipairs(definitions) do
    definition.volumeType = "groundWorks." .. definition.kind
    definition.maxDepth = definition.kind == "basement" and 8 or 4
    byId[definition.id] = definition
end

local function copy(source)
    local result = {}
    for key, value in pairs(source) do result[key] = value end
    return result
end

function Presets.get(id)
    local definition = byId[id]
    return definition and copy(definition) or nil
end

function Presets.list(kind)
    local result = {}
    for _, definition in ipairs(definitions) do
        if not kind or definition.kind == kind then result[#result+1] = copy(definition) end
    end
    return result
end

local function integer(value)
    return type(value) == "number" and value == value and value ~= math.huge
        and value ~= -math.huge and value == math.floor(value)
end

local function key(x, y)
    return tostring(x) .. ":" .. tostring(y)
end

-- The anchor is the player's existing underground tile. Length points in the
-- chosen direction; width extends clockwise from that direction. All callers
-- use these exact cells, including preview, inventory checks, and server work.
function Presets.plan(spec)
    if type(spec) ~= "table" then return nil, "Choose an excavation recipe." end
    local definition = byId[spec.presetId]
    if not definition then return nil, "Unknown excavation recipe." end
    if not integer(spec.x) or not integer(spec.y) or not integer(spec.z)
        or spec.z >= 0 or spec.z < -32 then
        return nil, "Choose an underground excavation level." end
    if -spec.z > definition.maxDepth then
        return nil, "This excavation type supports up to " .. definition.maxDepth .. " levels."
    end
    local direction = spec.direction
    local forwardX, forwardY, sideX, sideY
    if direction == "north" then forwardX, forwardY, sideX, sideY = 0, -1, 1, 0
    elseif direction == "east" then forwardX, forwardY, sideX, sideY = 1, 0, 0, 1
    elseif direction == "south" then forwardX, forwardY, sideX, sideY = 0, 1, -1, 0
    elseif direction == "west" then forwardX, forwardY, sideX, sideY = -1, 0, 0, -1
    else return nil, "Choose north, east, south, or west." end

    local plan = {
        presetId=definition.id, label=definition.label, kind=definition.kind,
        volumeType=definition.volumeType, direction=direction,
        x=spec.x, y=spec.y, z=spec.z, depth=-spec.z,
        width=definition.width, length=definition.length,
        cells={}, edges={},
        minX=spec.x, maxX=spec.x, minY=spec.y, maxY=spec.y,
    }
    local occupied = {}
    for lengthOffset=0, definition.length-1 do
        for widthOffset=0, definition.width-1 do
            local x = spec.x + forwardX*lengthOffset + sideX*widthOffset
            local y = spec.y + forwardY*lengthOffset + sideY*widthOffset
            plan.cells[#plan.cells+1] = { x=x, y=y, z=spec.z }
            occupied[key(x, y)] = true
            plan.minX, plan.maxX = math.min(plan.minX,x), math.max(plan.maxX,x)
            plan.minY, plan.maxY = math.min(plan.minY,y), math.max(plan.maxY,y)
        end
    end
    -- Native walls are owned by the square south/east of their N/W edge.
    -- Test only this plan's perimeter; no shared internal frame is produced.
    for _, cell in ipairs(plan.cells) do
        local x, y = cell.x, cell.y
        if not occupied[key(x,y-1)] then
            plan.edges[#plan.edges+1] = {x=x,y=y,z=spec.z,north=true}
        end
        if not occupied[key(x-1,y)] then
            plan.edges[#plan.edges+1] = {x=x,y=y,z=spec.z,north=false}
        end
        if not occupied[key(x,y+1)] then
            plan.edges[#plan.edges+1] = {x=x,y=y+1,z=spec.z,north=true}
        end
        if not occupied[key(x+1,y)] then
            plan.edges[#plan.edges+1] = {x=x+1,y=y,z=spec.z,north=false}
        end
    end
    plan.cellCount = #plan.cells
    plan.edgeCount = #plan.edges
    plan.sizeX, plan.sizeY = plan.maxX-plan.minX+1, plan.maxY-plan.minY+1
    return plan
end

groundWorks.ExcavationPresets = Presets
return Presets
