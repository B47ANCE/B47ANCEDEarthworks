-- Native terrain and renderer maintenance only. No renderer replacement and no
-- camera/visibility overrides. Geometry changes belong to the server (or SP).
local Terrain = {}

local function clientOnly()
    return type(isClient) == "function" and isClient()
        and not (type(isServer) == "function" and isServer())
end

local function dedicated()
    return type(isServer) == "function" and isServer()
        and not (type(isClient) == "function" and isClient())
end

local function invoke(object, method, ...)
    if not object then return nil, false end
    local ok, fn = pcall(function() return object[method] end)
    if not ok or type(fn) ~= "function" then return nil, false end
    local called, result = pcall(fn, object, ...)
    return result, called
end

local function validCoordinate(value)
    return type(value) == "number" and value == math.floor(value)
        and value ~= math.huge and value ~= -math.huge
end

-- FBO render textures group levels in pairs (-2/-1, -4/-3, ...).
-- Extend before connecting a square. Never shrink a pre-existing chunk.
function Terrain.normalizeChunk(chunk, z)
    if not chunk then return false, "terrain chunk is not loaded" end
    local lower = math.min(chunk:getMinLevel(), z)
    if lower < 0 then lower = math.floor(lower / 2) * 2 end
    local upper = math.max(chunk:getMaxLevel(), z)
    if lower ~= chunk:getMinLevel() or upper ~= chunk:getMaxLevel() then
        chunk:setMinMaxLevel(lower, upper)
    end
    return true
end

function Terrain.isUndergroundObject(object)
    if not object then return false end
    -- Native terrain fillers are ordinary static objects. A mod container or
    -- player construction using the same sprite must remain protected.
    if type(instanceof) == "function" and (not instanceof(object, "IsoObject")
            or instanceof(object, "IsoThumpable")) then return false end
    if invoke(object, "getContainer") ~= nil then return false end
    local md = invoke(object, "getModData")
    if type(md) == "table" then
        for _ in pairs(md) do return false end
    end
    local name = invoke(object, "getTile")
    if type(name) ~= "string" then
        local sprite = invoke(object, "getSprite")
        name = invoke(sprite, "getName")
    end
    return type(name) == "string" and name:match("^underground_01_%d+$") ~= nil
end

function Terrain.clearUnderground(square)
    if clientOnly() then return false, "terrain changes require server authority" end
    if not square then return false, "terrain square is unavailable" end
    local objects = square:getObjects()
    local removed = 0
    for i = objects:size() - 1, 0, -1 do
        local object = objects:get(i)
        if Terrain.isUndergroundObject(object) then
            -- Unlike removeUnderground(), this updates native world state and
            -- broadcasts removal. Vanilla's helper removes just one raw entry.
            square:transmitRemoveItemFromSquare(object)
            removed = removed + 1
        end
    end
    if removed > 0 then Terrain.refresh(square) end
    return true, removed
end

-- Native IsoObject.isGrass recognizes these two grass sprite families.
-- Deliberately exclude the broader isGrassLike list (plants, leaves, crops,
-- groundcover) and any object with foreign ownership or construction data.
function Terrain.isNativeGrassObject(object)
    if not object then return false end
    if type(instanceof)=="function"and(not instanceof(object,"IsoObject")
        or instanceof(object,"IsoThumpable")or instanceof(object,"IsoTree"))then return false end
    if invoke(object,"getContainer")~=nil then return false end
    local md=invoke(object,"getModData")
    if type(md)=="table"then for _ in pairs(md)do return false end end
    local sprite=invoke(object,"getSprite")
    local name=invoke(sprite,"getName")
    if type(name)~="string"then return false end
    return(name:match("^blends_grassoverlays_01_%d+$")~=nil
        or name:match("^e_newgrass_%d+_%d+$")~=nil)
        and invoke(object,"isGrass")==true
end

function Terrain.clearSurfaceGrass(square)
    if clientOnly()then return false,"terrain changes require server authority"end
    if not square or square:getZ()~=0 then return true,0 end
    local objects,removed=square:getObjects(),0
    for index=objects:size()-1,0,-1 do
        local object=objects:get(index)
        if Terrain.isNativeGrassObject(object)then
            square:transmitRemoveItemFromSquare(object);removed=removed+1
        end
    end
    if removed>0 then Terrain.refresh(square)end
    return true,removed
end

-- Return a connected native square, preserving existing objects. Clearing
-- native earth is a separate explicit operation after caller preflight.
function Terrain.prepare(x, y, z)
    if clientOnly() then return nil, "terrain creation requires server authority" end
    if not validCoordinate(x) or not validCoordinate(y) or not validCoordinate(z) then
        return nil, "integer terrain coordinates required"
    end
    local cell, world = getCell(), getWorld()
    if not cell or not world or not world:isValidSquare(x, y, z) then
        return nil, "terrain location is outside the world"
    end
    local square = cell:getGridSquare(x, y, z)
    local reference = square or cell:getGridSquare(x, y, 0)
        or cell:getGridSquare(x, y, z + 1)
    local chunk = reference and reference:getChunk()
    if not chunk then return nil, "terrain chunk is not loaded" end
    Terrain.normalizeChunk(chunk, z)
    if not square then square = cell:createNewGridSquare(x, y, z, true) end
    if not square or square:getChunk() ~= chunk then
        return nil, "native terrain square could not be connected"
    end
    return square
end

function Terrain.addFloor(square, spriteName)
    if clientOnly() then return nil, "terrain creation requires server authority" end
    if not square then return nil, "terrain square is unavailable" end
    local floor = square:getFloor()
    if floor then return floor end
    if type(spriteName) ~= "string" or not getSprite(spriteName) then
        return nil, "terrain floor sprite is unavailable"
    end
    -- Native addFloor removes some decorations and prepares surrounding earth.
    -- Insert a native floor object instead, retaining our boundary wall when
    -- an adjacent excavation turns its storage square into a cavity floor.
    local objects = square:getObjects()
    for i = 0, objects:size() - 1 do
        local object = objects:get(i)
        local md = object:getModData()
        if not md or type(md["groundWorks.boundary.v1"]) ~= "table" then
            return nil, "terrain floor square contains other geometry"
        end
    end
    Terrain.normalizeChunk(square:getChunk(), square:getZ())
    floor = IsoObject.getNew(square, spriteName, nil, false)
    if not floor then return nil, "native terrain floor object is unavailable" end
    -- The cavity adapter tags ownership and broadcasts exactly once after
    -- creation succeeds. Sending here would publish an untagged duplicate.
    square:AddTileObject(floor)
    if not floor or square:getFloor() ~= floor then
        return nil, "native terrain floor creation failed"
    end
    Terrain.refresh(square)
    return floor
end

function Terrain.refreshView()
    if dedicated() then return end
    local cell = getCell()
    if not cell then return end
    local count = type(getNumActivePlayers) == "function" and getNumActivePlayers() or 1
    for index = 0, math.max(1, count) - 1 do
        local chunkMap = invoke(cell, "getChunkMap", index)
        invoke(chunkMap, "calculateZExtentsForChunkMap")
    end
    if type(invalidateLighting) == "function" then invalidateLighting() end
end

-- Call once after a complete footprint changes its depth. Keep the nearby
-- loaded render chunks on a shared lower extent so adjacent FBO textures do
-- not retain different layouts during the change. This changes render/storage
-- extents only: it never creates terrain or changes unrelated objects.
function Terrain.synchronizeView(x, y, z)
    if dedicated() then return true, 0 end
    if not validCoordinate(x) or not validCoordinate(y) or not validCoordinate(z) then
        return false, "integer view coordinates required"
    end
    local cell = getCell()
    if not cell then return false, "terrain cell unavailable" end
    local chunks, lower = {}, z
    local count = type(getNumActivePlayers) == "function" and getNumActivePlayers() or 1
    for playerIndex = 0, math.max(1, count) - 1 do
        local map = invoke(cell, "getChunkMap", playerIndex)
        if map then
            local originX, originY = map:getWorldXMin(), map:getWorldYMin()
            -- Build 42.20 uses 8-square chunks, not Build 41's 10-square chunks.
            local localX, localY = math.floor(x / 8) - originX, math.floor(y / 8) - originY
            local width = math.floor(map:getWidthInTiles() / 8)
            for cx = math.max(0, localX - 3), math.min(width - 1, localX + 3) do
                for cy = math.max(0, localY - 3), math.min(width - 1, localY + 3) do
                    local chunk = map:getChunk(cx, cy)
                    if chunk then
                        chunks[chunk] = true
                        lower = math.min(lower, chunk:getMinLevel())
                    end
                end
            end
        end
    end
    if lower < 0 then lower = math.floor(lower / 2) * 2 end
    local changed = 0
    for chunk in pairs(chunks) do
        if chunk:getMinLevel() ~= lower then
            chunk:setMinMaxLevel(lower, chunk:getMaxLevel())
            invoke(chunk, "checkLightingLater_AllPlayers_AllLevels")
            for level = lower, chunk:getMaxLevel() do
                invoke(chunk, "invalidateVispolyChunkLevel", level)
            end
            invoke(chunk, "invalidateRenderChunkLevels", -1)
            changed = changed + 1
        end
    end
    Terrain.refreshView()
    return true, changed
end

function Terrain.refresh(square, deferView)
    if not square then return false end
    local chunk, z = square:getChunk(), square:getZ()
    if not chunk then return false end
    Terrain.normalizeChunk(chunk, z)
    square:RecalcAllWithNeighbours(true)
    square:setSquareChanged()
    invoke(square, "DirtySlice")
    invoke(chunk, "checkPhysicsLater", z)
    if not dedicated() then
        invoke(chunk, "checkLightingLater_AllPlayers_AllLevels")
        invoke(chunk, "invalidateVispolyChunkLevel", z)
        invoke(chunk, "invalidateRenderChunkLevels", -1)
        if not deferView then Terrain.refreshView() end
    end
    return true
end

-- Loaded authoritative cavity markers trigger bounded render refreshes. The
-- client never opens floors or removes earth on its own.
function Terrain.installClient()
    if Terrain.clientInstalled or dedicated() or not Events then return end
    Terrain.clientInstalled = true
    local pending, queued, views = {}, {}, {}
    local viewCount = 0
    local function owned(md)
        return md and (md["groundWorks.cavity.v1"]
            or md["groundWorks.cavity.opening.v1"]
            or md["groundWorks.excavationExperiment.v1"]
            or md["groundWorks.boundary.v1"])
    end
    local function queue(square)
        if not square or queued[square] or #pending >= 1024 then return end
        queued[square] = true
        pending[#pending + 1] = square
    end
    local function loaded(square)
        local md = square and square:getModData()
        if owned(md) then queue(square) end
    end
    local function added(object)
        if not object or not owned(invoke(object, "getModData")) then return end
        local square = invoke(object, "getSquare")
        queue(square)
        if square then
            -- The authoritative floor opening may have arrived separately.
            queue(getCell():getGridSquare(square:getX(), square:getY(), 0))
        end
    end
    local function update()
        if #pending == 0 and viewCount == 0 then return end
        for i = 1, math.min(#pending, 32) do
            local square = table.remove(pending)
            queued[square] = nil
            Terrain.refresh(square, true)
            local key = math.floor(square:getX() / 8) .. ":" .. math.floor(square:getY() / 8)
            local existing = views[key]
            if not existing or square:getZ() < existing.z then
                if not existing then viewCount = viewCount + 1 end
                views[key] = { x = square:getX(), y = square:getY(), z = square:getZ() }
            end
        end
        local refreshed = 0
        for key, view in pairs(views) do
            Terrain.synchronizeView(view.x, view.y, view.z)
            views[key] = nil
            viewCount = viewCount - 1
            refreshed = refreshed + 1
            if refreshed >= 4 then break end
        end
    end
    if Events.LoadGridsquare and Events.LoadGridsquare.Add then Events.LoadGridsquare.Add(loaded) end
    if Events.OnObjectAdded and Events.OnObjectAdded.Add then Events.OnObjectAdded.Add(added) end
    if Events.OnTick and Events.OnTick.Add then Events.OnTick.Add(update) end
end

return Terrain
