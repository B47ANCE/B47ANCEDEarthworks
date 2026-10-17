local Trajectory=require "groundWorks/WheelTrajectory"
local WheelWear={MAX_CONTACTS=32,MAX_TILES_PER_CONTACT=64}
local histories=setmetatable({},{__mode="k"})

local function finite(value)
    return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end

local function validateContact(contact)
    return type(contact)=="table"and type(contact.id)=="string"and contact.id~=""and#contact.id<=64
        and contact.supported==true and finite(contact.x)and finite(contact.y)and finite(contact.z)
end

-- Produces loaded contacted squares without mutating wear. Histories are keyed
-- by stable wheel ID, so reordered/appearing contacts seed instead of joining
-- unrelated trajectories. Tile keys are deduplicated for one vehicle step.
function WheelWear.plan(vehicle,sample,resolveSquare)
    if not vehicle then return nil,"vehicle required"end
    if type(sample)~="table"or type(sample.contacts)~="table"then return nil,"contact sample required"end
    if type(resolveSquare)~="function"then return nil,"square resolver required"end
    if #sample.contacts>WheelWear.MAX_CONTACTS then return nil,"contact bound exceeded"end
    local current,ordered={},{}
    for _,contact in ipairs(sample.contacts)do
        if not validateContact(contact)then return nil,"invalid supported contact"end
        if current[contact.id]then return nil,"duplicate contact identity"end
        current[contact.id]={x=contact.x,y=contact.y,z=contact.z}
        ordered[#ordered+1]=contact.id
    end
    table.sort(ordered)
    local previous=histories[vehicle]
    if not previous then histories[vehicle]=current;return{seeded=#ordered,tiles={},resolved=0,unresolved=0,contacts=#ordered}end

    local tiles,seen={},{}
    for _,id in ipairs(ordered)do
        local before=previous[id]
        if before and(before.x~=current[id].x or before.y~=current[id].y or before.z~=current[id].z)then
            local traced,err=Trajectory.trace(before,current[id],WheelWear.MAX_TILES_PER_CONTACT)
            if not traced then return nil,"contact "..id.." trajectory rejected: "..tostring(err)end
            for _,tile in ipairs(traced)do
                if not seen[tile.key]then seen[tile.key]=true;tiles[#tiles+1]=tile end
            end
        end
    end
    table.sort(tiles,function(a,b)return a.key<b.key end)
    local squares,unresolved={},0
    for _,tile in ipairs(tiles)do
        local square=resolveSquare(tile.x,tile.y,tile.z)
        if square then squares[#squares+1]={key=tile.key,square=square}
        else unresolved=unresolved+1 end
    end
    histories[vehicle]=current
    return{seeded=0,tiles=squares,resolved=#squares,unresolved=unresolved,contacts=#ordered,crossed=#tiles}
end

function WheelWear.clear(vehicle)histories[vehicle]=nil end
function WheelWear._resetForTests()histories=setmetatable({},{__mode="k"})end
return WheelWear
