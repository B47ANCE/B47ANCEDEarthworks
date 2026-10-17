local API = require "groundWorks/Load"
local Build = require "groundWorks/ExcavationBuild"
local Engine = require "groundWorks/CavityEngine"
local Cavity = API.Cavity
local Collapse = {MAX_SCAN=1024, MAX_ELAPSED_HOURS=1/60}
local eligibleTypes = {
    ["groundWorks.trench"]=true,
    ["groundWorks.moat"]=true,
    ["groundWorks.basement"]=true,
}

local function call(object,method,...)
    if not object then return nil end
    local found,fn=pcall(function()return object[method]end)
    if not found or type(fn)~="function"then return nil end
    local ok,result=pcall(fn,object,...)
    if ok then return result end
end

local function finite(value)
    return type(value)=="number"and value==value and value~=math.huge and value~=-math.huge
end

local function settings()
    local values=SandboxVars and SandboxVars.groundWorks or {}
    local rate=values.CollapseChancePerHour
    if not finite(rate)then rate=0.01 end
    return values.EnableCollapse~=false,values.CollapseKills~=false,math.max(0,math.min(1,rate))
end

local function metadata(square)
    local root=call(square,"getModData")
    return type(root)=="table"and root or nil
end

local function transmit(square)
    call(square,"transmitModdata")
end

local function markCollapsed(square,operationId,now)
    local root=metadata(square)
    if not root then return end
    for _,key in ipairs({Cavity.ROOT_KEY,Cavity.OPENING_KEY,API.ExcavationExperiment.ROOT_KEY})do
        local record=root[key]
        if type(record)=="table"and record.operationId==operationId then
            record.collapsed=true
            record.sealed=true
            record.surfaceCap="sealed"
            record.collapseState="collapsed"
            record.collapsedAt=now
            record.occupancy={stand=false,receiveItems=false,receiveBodies=false,receiveFluids=false,ignite=false,pourSolid=false}
        end
    end
    transmit(square)
end

local function collectPlayers(squares,surface,depth)
    local players,seen={},{}
    local function add(player)
        if not player or seen[player] or not instanceof(player,"IsoPlayer") or call(player,"isDead")==true then return end
        local x,y,z=call(player,"getX"),call(player,"getY"),call(player,"getZ")
        if not finite(x)or not finite(y)or not finite(z)then return end
        if math.floor(x)~=surface:getX()or math.floor(y)~=surface:getY()or z>=0 or z < -depth then return end
        seen[player]=true
        players[#players+1]=player
    end
    for _,square in ipairs(squares)do
        local moving=call(square,"getMovingObjects")
        if moving then for i=0,moving:size()-1 do add(moving:get(i))end end
    end
    -- A character changing levels may not yet be in the square's moving list.
    if isServer()and getOnlinePlayers then
        local online=getOnlinePlayers()
        if online then for i=0,online:size()-1 do add(online:get(i))end end
    elseif getSpecificPlayer then
        for index=0,3 do add(getSpecificPlayer(index))end
    end
    return players
end

-- Returns true only for a newly committed collapse. No command handler exposes
-- rollOverride; it is a deterministic seam for disposable-world/test checks.
function Collapse.evaluate(surface,rollOverride)
    if isClient()then return false,"non-authority"end
    local enabled,kills,rate=settings()
    if not enabled or rate<=0 then return false,"disabled"end
    if not surface or surface:getZ()~=0 or not surface:getChunk()then return false,"unloaded"end
    local receipt=Cavity.inspect(surface)
    if type(receipt)~="table"or receipt.status~="created"or not eligibleTypes[receipt.volumeType]then
        return false,"not an eligible excavation"end
    if receipt.collapsed or receipt.sealed or receipt.surfaceCap=="sealed"then return false,"sealed"end
    -- A house ceiling or player-built cover is preserved during restoration,
    -- but only intact perimeter framing grants protection from collapse.
    local depth=receipt.targetDepth
    if not finite(depth)or depth~=math.floor(depth)or depth<1 or depth>8 then return false,"invalid depth"end
    local store=API.EarthworkPersistence.getStore()
    local job=store and store.jobs and store.jobs[receipt.jobId]
    if not job or job.status~="excavated"then return false,"job unavailable"end
    local root=metadata(surface)
    local active=root and root[Cavity.ROOT_KEY]
    if type(active)~="table"then return false,"receipt unavailable"end
    local now=getGameTime():getWorldAgeHours()
    if not finite(now)then return false,"clock unavailable"end
    local previous=active.collapseLastCheck
    active.collapseLastCheck=now
    if not finite(previous)or previous>=now then return false,"armed"end
    -- An unloaded area accrues no catch-up collapse risk when it returns.
    local elapsed=math.min(now-previous,Collapse.MAX_ELAPSED_HOURS)
    local adapter=Engine.adapter()
    local squares={}
    local allSecured=true
    for z=-1,-depth,-1 do
        local square=adapter.getSquare(surface:getX(),surface:getY(),z)
        if not square or not square:getChunk()then return false,"unloaded"end
        local own=Cavity.inspect(square)
        if not own or own.operationId~=receipt.operationId then return false,"unowned geometry"end
        squares[#squares+1]=square
        local squareData=metadata(square)
        local support=squareData and squareData[Build.SUPPORT_KEY]
        if type(support)=="table"and type(support.edges)=="table"then
            for _,edge in ipairs(support.edges)do
                local edgeSquare=adapter.getSquare(edge.x,edge.y,edge.z)
                if not edgeSquare or not edgeSquare:getChunk()then return false,"unloaded support"end
            end
        end
        if not Build.isSecured(square)then allSecured=false end
    end
    if allSecured then return false,"secured"end
    local hourly=math.min(1,rate*depth)
    local probability=1-(1-hourly)^elapsed
    local roll=rollOverride
    if roll==nil then roll=ZombRand(1000000)/1000000 end
    if not finite(roll)or roll<0 or roll>=1 then return false,"invalid roll"end
    if roll>=probability then return false,"stable"end

    local players=collectPlayers(squares,surface,depth)
    local escapes={}
    for _,player in ipairs(players)do
        local _,_,landing=Cavity.climbLanding(player:getCurrentSquare(),adapter)
        escapes[player]=landing
        if not kills and not landing then return false,"no safe evacuation landing"end
        if kills and type(player.Kill)~="function"then return false,"native death action unavailable"end
    end
    -- In nonfatal mode move survivors first. If any move fails, never cap them.
    if not kills then
        for _,player in ipairs(players)do
            if Engine.movePlayer(player,escapes[player])~=true then return false,"evacuation failed"end
        end
    end
    -- Native restoration retains an existing floor and the objects above it.
    if adapter.restoreFloor(surface)~=true or not surface:getFloor()then return false,"surface restoration failed"end
    -- Persist the seal before effects: a reload or repeated call cannot kill a
    -- second survivor or reopen the collapse as an ordinary live excavation.
    markCollapsed(surface,receipt.operationId,now)
    for _,square in ipairs(squares)do markCollapsed(square,receipt.operationId,now)end
    job.surfaceCap="sealed"
    job.collapseState="collapsed"
    job.collapsedAt=now
    job.occupancy={stand=false,receiveItems=false,receiveBodies=false,receiveFluids=false,ignite=false,pourSolid=false}
    Cavity.unregisterOpening(surface:getX(),surface:getY())
    if isServer()and ModData then ModData.transmit(API.EarthworkPersistence.STORE_KEY)end
    for _,player in ipairs(players)do
        if kills then
            local ok=pcall(function()player:Kill(nil)end)
            if not ok or not player:isDead()then
                -- If another mod refuses death, use a prevalidated escape when
                -- one exists; never invoke damage repeatedly on the sealed site.
                if escapes[player]then Engine.movePlayer(player,escapes[player])end
                active.collapseEffectIncomplete=true
                transmit(surface)
            end
        else
            call(player,"Say","The excavation collapsed. You escaped to the surface.")
        end
    end
    return true,{x=surface:getX(),y=surface:getY(),depth=depth,players=#players,fatal=kills}
end

function Collapse.scan()
    if isClient()then return 0 end
    local collapsed=0
    local cell=getCell()
    if not cell then return 0 end
    local openings=Cavity.listOpenings()
    for index=1,math.min(#openings,Collapse.MAX_SCAN)do
        local opening=openings[index]
        local surface=cell:getGridSquare(opening.x,opening.y,0)
        if surface and surface:getChunk()then
            local ok,changed=pcall(Collapse.evaluate,surface)
            if ok and changed then collapsed=collapsed+1 end
            if not ok then print("[groundWorks][Collapse] Evaluation failed: "..tostring(changed))end
        end
    end
    return collapsed
end

function Collapse.install(events)
    if isClient()then return false,"non-authority"end
    if Collapse.installed then return true end
    if not events or not events.EveryOneMinute then return false,"minute event unavailable"end
    events.EveryOneMinute.Add(Collapse.scan)
    Collapse.installed=true
    return true
end

API.CavityCollapse=Collapse
return Collapse
