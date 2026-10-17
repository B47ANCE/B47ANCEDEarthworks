local API = require "groundWorks/API"
local Observer = {}
local history = setmetatable({}, {__mode="k"})
local installed = false
local counts = {events=0, ignored=0, seeded=0, recorded=0, deduplicated=0,
    disabled=0, discontinuities=0, failed=0}

local function call(object, method)
    if not object then return nil end
    local ok, result = pcall(function() return object[method](object) end)
    if ok then return result,true end
    return nil,false
end

local function finite(value)
    return type(value)=="number" and value==value and value~=math.huge and value~=-math.huge
end

local function position(square)
    local x,y,z = call(square,"getX"),call(square,"getY"),call(square,"getZ")
    if not finite(x) or not finite(y) or not finite(z)
        or x%1~=0 or y%1~=0 or z%1~=0 then return nil end
    return {x=x,y=y,z=z}
end

local function settings()
    local root = rawget(_G,"SandboxVars")
    return type(root)=="table" and type(root.groundWorks)=="table" and root.groundWorks or {}
end

local function observe(subject)
    counts.events = counts.events+1
    if not subject then return false,"animal required" end
    local predicate = rawget(_G,"instanceof")
    local ok,animal = false,false
    if type(predicate)=="function" then ok,animal=pcall(predicate,subject,"IsoAnimal") end
    if not ok or animal~=true then
        history[subject]=nil;counts.ignored=counts.ignored+1;return true,"not an animal"
    end
    if type(rawget(_G,"isClient"))=="function" and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function" and isServer()==true) then
        history[subject]=nil;return false,"non-authority"
    end
    local options = settings()
    if options.EnableAnimalTraffic==false then
        history[subject]=nil;counts.disabled=counts.disabled+1;return true,"animal traffic disabled"
    end
    -- Missing state cannot establish an animal walking on a loaded square.
    local vehicle,vehicleKnown=call(subject,"getVehicle")
    if call(subject,"isDead")~=false or not vehicleKnown or vehicle~=nil then
        history[subject]=nil;counts.ignored=counts.ignored+1;return true,"animal is not walking"
    end
    local square = call(subject,"getCurrentSquare")
    local current = position(square)
    local getTime = rawget(_G,"getGameTime")
    local time = type(getTime)=="function" and getTime() or nil
    local age = call(time,"getWorldAgeHours")
    if not current or not finite(age) or age<0 then
        history[subject]=nil;return false,"animal position or world age unavailable"
    end
    current.age=age
    local prior = history[subject]
    history[subject]=current
    if not prior then counts.seeded=counts.seeded+1;return true,"animal position seeded" end
    if current.z~=prior.z or math.abs(current.x-prior.x)>1 or math.abs(current.y-prior.y)>1
        or age<prior.age or age-prior.age>1 then
        counts.discontinuities=counts.discontinuities+1;return true,"animal travel discontinuity"
    end
    if current.x==prior.x and current.y==prior.y then
        counts.deduplicated=counts.deduplicated+1;return true,"same square"
    end
    local recovery=tonumber(options.WearRecoveryPerDay)
    if not finite(recovery) then recovery=.05 end
    recovery=math.max(0,math.min(10,recovery))
    local accepted,result=API.reportTraffic(square,"animal",1,age,recovery)
    if accepted~=true then counts.ignored=counts.ignored+1;return true,result end
    counts.recorded=counts.recorded+1
    return true,result
end

function Observer.observeAnimal(subject)
    local ok,accepted,result=pcall(observe,subject)
    if not ok then
        if subject then history[subject]=nil end
        counts.failed=counts.failed+1;return false,"animal traffic observation failed"
    end
    if accepted~=true then counts.failed=counts.failed+1 end
    return accepted,result
end

function Observer.getDiagnostics()
    local result={installed=installed}
    for key,value in pairs(counts) do result[key]=value end
    return result
end

function Observer.install(events)
    if installed then return true,"already installed" end
    local event=type(events)=="table" and events.OnPlayerMove or nil
    if type(event)~="table" or type(event.Add)~="function" then return false,"OnPlayerMove unavailable" end
    -- IsoAnimal can reach this inherited movement event. The player observer
    -- excludes it, and this observer independently owns only animal wear.
    event.Add(Observer.observeAnimal)
    installed=true
    return true
end

API.AnimalTrafficObserver=Observer
return Observer
