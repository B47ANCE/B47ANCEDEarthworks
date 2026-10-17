local groundWorks=require "groundWorks/API"
local WheelContacts=require "groundWorks/WheelContacts"
local WheelWear=require "groundWorks/WheelWear"

local TrafficObserver={}
local lastSquareByPlayer=setmetatable({},{__mode="k"})
local installed=false
local diagnostics={events=0,recorded=0,deduplicated=0,disabled=0,vehicle=0,vehicleRecorded=0,
    vehicleDisabled=0,animalExcluded=0,ignored=0,failed=0,contactSamples=0,contacts=0,
    unsupportedContacts=0,crossedTiles=0,resolvedTiles=0,unresolvedTiles=0,seededVehicles=0}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function() return object[method] end)
    if not ok or type(fn)~="function" then return nil end
    local called,result=pcall(fn,object,...)
    if called then return result end
    return nil
end

local function isAnimal(subject)
    local predicate=rawget(_G,"instanceof")
    if type(predicate)~="function" then return false end
    local ok,result=pcall(predicate,subject,"IsoAnimal")
    return ok and result==true
end

local function enabled(kind)
    local root=rawget(_G,"SandboxVars")
    local settings=type(root)=="table" and root.groundWorks or nil
    if type(settings)~="table"then return true end
    if kind=="vehicle"then return settings.EnableVehicleTraffic~=false end
    return settings.EnablePlayerFootTraffic~=false
end

local function recoveryRate()
    local root=rawget(_G,"SandboxVars")
    local settings=type(root)=="table" and root.groundWorks or nil
    local value=type(settings)=="table" and tonumber(settings.WearRecoveryPerDay) or .05
    if not value or value~=value then return .05 end
    return math.max(0,math.min(10,value))
end

local function worldAge()
    local getTime=rawget(_G,"getGameTime")
    if type(getTime)~="function" then return nil end
    local ok,time=pcall(getTime)
    if not ok or not time then return nil end
    local age=call(time,"getWorldAgeHours")
    return type(age)=="number" and age==age and age~=math.huge and age~=-math.huge and age or nil
end

local function squareKey(square)
    local x=call(square,"getX")
    local y=call(square,"getY")
    local z=call(square,"getZ")
    if type(x)~="number" or type(y)~="number" or type(z)~="number" then return nil end
    return tostring(math.floor(x))..":"..tostring(math.floor(y))..":"..tostring(math.floor(z))
end

local function resolveSquare(x,y,z)
    local getter=rawget(_G,"getCell")
    if type(getter)~="function"then return nil end
    local ok,cell=pcall(getter);if not ok or not cell then return nil end
    return call(cell,"getGridSquare",x,y,z)
end

local function observeVehicle(vehicle)
    diagnostics.vehicle=diagnostics.vehicle+1
    if not enabled("vehicle")then
        WheelWear.clear(vehicle);diagnostics.disabled=diagnostics.disabled+1
        diagnostics.vehicleDisabled=diagnostics.vehicleDisabled+1
        return true,"vehicle traffic disabled"
    end
    local sample,err=WheelContacts.sample(vehicle)
    if not sample then WheelWear.clear(vehicle);diagnostics.failed=diagnostics.failed+1;return false,err end
    diagnostics.contactSamples=diagnostics.contactSamples+1
    diagnostics.contacts=diagnostics.contacts+#sample.contacts
    diagnostics.unsupportedContacts=diagnostics.unsupportedContacts+#(sample.unsupported or{})
    local plan,planErr=WheelWear.plan(vehicle,sample,resolveSquare)
    if not plan then WheelWear.clear(vehicle);diagnostics.failed=diagnostics.failed+1;return false,planErr end
    if plan.seeded>0 then diagnostics.seededVehicles=diagnostics.seededVehicles+1;return true,"wheel contacts seeded"end
    diagnostics.crossedTiles=diagnostics.crossedTiles+(plan.crossed or 0)
    diagnostics.resolvedTiles=diagnostics.resolvedTiles+plan.resolved
    diagnostics.unresolvedTiles=diagnostics.unresolvedTiles+plan.unresolved
    if #plan.tiles==0 then diagnostics.deduplicated=diagnostics.deduplicated+1;return true,"no resolved wheel travel"end
    local age=worldAge()
    if age==nil then diagnostics.failed=diagnostics.failed+1;return false,"world age unavailable"end
    local acceptedCount=0
    for _,entry in ipairs(plan.tiles)do
        local ok,accepted,result=pcall(groundWorks.reportTraffic,entry.square,"vehicle",1,age,recoveryRate())
        if not ok then diagnostics.failed=diagnostics.failed+1;return false,"traffic provider error"end
        if accepted==true then acceptedCount=acceptedCount+1
        else diagnostics.ignored=diagnostics.ignored+1 end
    end
    diagnostics.recorded=diagnostics.recorded+acceptedCount
    diagnostics.vehicleRecorded=diagnostics.vehicleRecorded+acceptedCount
    return true,{reported=acceptedCount,resolved=plan.resolved,unresolved=plan.unresolved}
end

function TrafficObserver.observeVehicle(vehicle)
    if not vehicle then return false,"vehicle required"end
    if type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true)then
        WheelWear.clear(vehicle);return false,"non-authority"
    end
    local ok,accepted,result=pcall(observeVehicle,vehicle)
    if not ok then
        WheelWear.clear(vehicle);diagnostics.failed=diagnostics.failed+1
        return false,"vehicle observation failed"
    end
    return accepted,result
end

function TrafficObserver.observePlayer(player)
    diagnostics.events=diagnostics.events+1
    if not player then diagnostics.failed=diagnostics.failed+1;return false,"player required" end
    -- Build 42 IsoAnimal inherits IsoPlayer and may reach OnPlayerMove. Animal
    -- traffic has separate ownership and must never inherit player wear or its
    -- sandbox control accidentally.
    if isAnimal(player) then
        lastSquareByPlayer[player]=nil
        diagnostics.animalExcluded=diagnostics.animalExcluded+1
        return true,"animal traffic requires its dedicated provider"
    end
    local vehicle=call(player,"getVehicle")
    if vehicle then return TrafficObserver.observeVehicle(vehicle)end
    local kind=vehicle and"vehicle"or"foot"
    local square=call(player,"getCurrentSquare")
    local key=squareKey(square)
    if not square or not key then diagnostics.failed=diagnostics.failed+1;return false,"current square unavailable" end
    if lastSquareByPlayer[player]==key then
        diagnostics.deduplicated=diagnostics.deduplicated+1
        return true,"same square"
    end
    lastSquareByPlayer[player]=key
    if not enabled(kind) then
        diagnostics.disabled=diagnostics.disabled+1
        return true,kind.." traffic disabled"
    end
    local age=worldAge()
    if age==nil then diagnostics.failed=diagnostics.failed+1;return false,"world age unavailable" end
    local ok,accepted,result=pcall(groundWorks.reportTraffic,square,kind,1,age,recoveryRate())
    if not ok then diagnostics.failed=diagnostics.failed+1;return false,"traffic provider error" end
    if accepted~=true then diagnostics.ignored=diagnostics.ignored+1;return true,result or "traffic ignored" end
    diagnostics.recorded=diagnostics.recorded+1
    return true,result
end

function TrafficObserver.getDiagnostics()
    local result={installed=installed}
    for key,value in pairs(diagnostics) do result[key]=value end
    return result
end

function TrafficObserver.install(events)
    if installed then return true,"already installed" end
    local event=type(events)=="table" and events.OnPlayerMove or nil
    if type(event)~="table" or type(event.Add)~="function" then return false,"OnPlayerMove unavailable" end
    event.Add(function(player)
        local ok,err=TrafficObserver.observePlayer(player)
        if not ok and print then print("[groundWorks] Player traffic observation failed safely: "..tostring(err)) end
    end)
    installed=true
    return true
end

groundWorks.TrafficObserver=TrafficObserver
return TrafficObserver
