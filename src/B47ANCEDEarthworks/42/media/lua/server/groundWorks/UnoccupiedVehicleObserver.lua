local API=require "groundWorks/API"
local Traffic=require "groundWorks/TrafficObserver"
local Wear=require "groundWorks/WheelWear"
local Observer={BATCH_SIZE=8,TICK_INTERVAL=10,MAX_SEATS=32,MAX_GAP_TICKS=120}
local installed=false
local tick,cursor,generation=0,0,1
local wasEnabled=false
local visits=setmetatable({},{__mode="k"})
local counts={batches=0,visited=0,observed=0,occupied=0,failed=0,disabled=0,reseeded=0}

local function integer(value,limit)
    return type(value)=="number"and value==value and value>=0 and value<=limit and value%1==0
end

local function call(object,method,...)
    if not object then return nil,false end
    local found,fn=pcall(function()return object[method]end)
    if not found or type(fn)~="function"then return nil,false end
    local ok,value=pcall(fn,object,...)
    return value,ok
end

local function enabled()
    local root=rawget(_G,"SandboxVars")
    local options=type(root)=="table"and root.groundWorks or nil
    return type(options)~="table"or(options.EnableVehicleTraffic~=false and options.EnableUnoccupiedVehicleTraffic~=false)
end

local function inspectVehicle(vehicle)
    local seats,known=call(vehicle,"getMaxPassengers")
    if not known or not integer(seats,Observer.MAX_SEATS)then
        visits[vehicle]=nil;Wear.clear(vehicle);counts.failed=counts.failed+1;return
    end
    for seat=0,seats-1 do
        local occupant,ok=call(vehicle,"getCharacter",seat)
        if not ok then visits[vehicle]=nil;Wear.clear(vehicle);counts.failed=counts.failed+1;return end
        if occupant~=nil then
            visits[vehicle]=nil;counts.occupied=counts.occupied+1;return
        end
    end
    local square,resolved=call(vehicle,"getCurrentSquare")
    if not resolved or not square then
        visits[vehicle]=nil;Wear.clear(vehicle);counts.failed=counts.failed+1;return
    end
    local previous=visits[vehicle]
    if not previous or previous.generation~=generation or tick-previous.tick>Observer.MAX_GAP_TICKS then
        Wear.clear(vehicle);counts.reseeded=counts.reseeded+1
    end
    visits[vehicle]={tick=tick,generation=generation}
    local ok,accepted=pcall(Traffic.observeVehicle,vehicle)
    if not ok or accepted~=true then
        visits[vehicle]=nil;Wear.clear(vehicle);counts.failed=counts.failed+1;return
    end
    counts.observed=counts.observed+1
end

function Observer.onTick()
    tick=tick+1
    local authority=not(type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))
    if not authority or not enabled()then
        if wasEnabled then generation=generation+1 end
        wasEnabled=false;cursor=0;counts.disabled=counts.disabled+1;return
    end
    wasEnabled=true
    if tick%Observer.TICK_INTERVAL~=0 then return end
    counts.batches=counts.batches+1
    local getter=rawget(_G,"getCell")
    local ok,cell=false,nil
    if type(getter)=="function"then ok,cell=pcall(getter)end
    local vehicles,listOk=call(ok and cell or nil,"getVehicles")
    local count,countOk=call(listOk and vehicles or nil,"size")
    if not countOk or not integer(count,1000000)then
        generation=generation+1;cursor=0;counts.failed=counts.failed+1;return
    end
    if count==0 then generation=generation+1;cursor=0;return end
    local seen={}
    for _=1,math.min(count,Observer.BATCH_SIZE)do
        local index=cursor%count;cursor=(index+1)%count
        local vehicle,found=call(vehicles,"get",index)
        if found and vehicle and not seen[vehicle]then
            seen[vehicle]=true;counts.visited=counts.visited+1
            inspectVehicle(vehicle)
        elseif not found then counts.failed=counts.failed+1 end
    end
end

function Observer.getDiagnostics()
    local result={installed=installed,cursor=cursor}
    for key,value in pairs(counts)do result[key]=value end
    return result
end

function Observer.install(events)
    if installed then return true,"already installed"end
    local event=type(events)=="table"and events.OnTick or nil
    if type(event)~="table"or type(event.Add)~="function"then return false,"OnTick unavailable"end
    event.Add(Observer.onTick);installed=true;return true
end

API.UnoccupiedVehicleObserver=Observer
return Observer
