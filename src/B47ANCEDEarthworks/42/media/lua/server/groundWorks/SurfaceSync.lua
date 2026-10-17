local API=require "groundWorks/API"
local Sync={MAX_PENDING=256,BATCH_SIZE=8,TICK_INTERVAL=10}
local pending,queue={},{}
local head,tail,size,ticks=1,0,0,0
local installed=false
local counters={queued=0,coalesced=0,sent=0,dropped=0,unloaded=0,failed=0}

local function server()
    return type(rawget(_G,"isServer"))=="function"and isServer()==true
end
local function call(object,method,...)
    local ok,fn=pcall(function()return object and object[method]end)
    if not ok or type(fn)~="function"then return nil,false end
    local called,value=pcall(fn,object,...)
    return value,called
end
local function coordinate(square,method)
    local value=call(square,method)
    if type(value)~="number"or value~=value or value==math.huge or value==-math.huge or value%1~=0 then return nil end
    return value
end

function Sync.enqueue(square)
    if not server()then return false,"server only"end
    local x,y,z=coordinate(square,"getX"),coordinate(square,"getY"),coordinate(square,"getZ")
    if not x or not y or not z then return false,"integer square coordinates required"end
    local key=x..":"..y..":"..z
    if pending[key]then
        pending[key].square=square;counters.coalesced=counters.coalesced+1;return true
    end
    if size>=Sync.MAX_PENDING then counters.dropped=counters.dropped+1;return false,"surface sync queue full"end
    local entry={key=key,x=x,y=y,z=z,square=square}
    tail=tail%Sync.MAX_PENDING+1;queue[tail]=entry;pending[key]=entry;size=size+1
    counters.queued=counters.queued+1;return true
end

function Sync.onSquareLoaded(square)
    if not server()then return end
    local root=call(square,"getModData")
    if type(root)=="table"and root[API.STATE_KEY]~=nil and API.getWearState(square)then Sync.enqueue(square)end
end

function Sync.onTick()
    ticks=ticks+1
    if not server()then
        pending={};queue={};head=1;tail=0;size=0;return
    end
    if ticks%Sync.TICK_INTERVAL~=0 then return end
    local getter=rawget(_G,"getCell")
    local ok,cell=false,nil
    if type(getter)=="function"then ok,cell=pcall(getter)end
    for _=1,math.min(size,Sync.BATCH_SIZE)do
        local entry=queue[head];queue[head]=nil;head=head%Sync.MAX_PENDING+1
        pending[entry.key]=nil;size=size-1
        local resolved=ok and call(cell,"getGridSquare",entry.x,entry.y,entry.z)or nil
        if resolved~=entry.square then counters.unloaded=counters.unloaded+1
        else
            local valid=API.getWearState(resolved)
            local called=pcall(function()
                if not valid then error("unsupported wear state")end
                resolved:transmitModdata()
            end)
            if called then counters.sent=counters.sent+1
            else
                counters.failed=counters.failed+1
                local attempts=(entry.attempts or 0)+1
                if attempts<3 and Sync.enqueue(resolved)then pending[entry.key].attempts=attempts end
            end
        end
    end
end

function Sync.getDiagnostics()
    local result={installed=installed,pending=size}
    for key,value in pairs(counters)do result[key]=value end
    return result
end

function Sync.install(events)
    if installed then return true,"already installed"end
    if type(events)~="table"or type(events.OnTick)~="table"or type(events.OnTick.Add)~="function"
        or type(events.LoadGridsquare)~="table"or type(events.LoadGridsquare.Add)~="function"then
        return false,"surface sync events unavailable"
    end
    API.registerWearListener("groundWorks.surfaceSync",Sync.enqueue)
    events.OnTick.Add(Sync.onTick);events.LoadGridsquare.Add(Sync.onSquareLoaded)
    installed=true;return true
end

API.SurfaceSync=Sync
return Sync
