local Contacts={MAX_CONTACTS=32}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...)
    if called then return result end
end

local function finite(value)
    value=tonumber(value)
    if not value or value~=value or value==math.huge or value==-math.huge then return nil end
    return value
end

local function component(vector,axis)
    return finite(call(vector,axis)or call(vector,"get"..string.upper(axis)))
end

local function boundedId(value)
    value=tostring(value or"")
    if value==""or#value>64 then return nil end
    return value
end

-- Script wheel geometry and installed tire parts are both required. A script
-- wheel with no tire item is reported as unsupported rather than fabricated as
-- a terrain contact. Nonstandard tracks require their own explicit provider.
function Contacts.sample(vehicle)
    local script=call(vehicle,"getScript")
    local count=finite(call(script,"getWheelCount"))
    local vehicleType=rawget(_G,"BaseVehicle")
    local engineMaximum=vehicleType and finite(vehicleType.MAX_WHEELS)or nil
    local maximum=engineMaximum and math.min(Contacts.MAX_CONTACTS,math.floor(engineMaximum))or nil
    if not script or not count or count<1 or count~=math.floor(count)then return nil,"vehicle wheel script unavailable"end
    if not maximum or maximum<1 then return nil,"BaseVehicle.MAX_WHEELS unavailable"end
    if count>maximum then return nil,"vehicle wheel count exceeds engine bound"end
    local vectorType=rawget(_G,"Vector3f")
    if not vectorType or type(vectorType.new)~="function"then return nil,"Vector3f unavailable"end
    local result={declared=count,contacts={},unsupported={},source="script-wheel-installed-tire"}
    local seen={}
    for index=0,count-1 do
        local wheel=call(script,"getWheel",index)
        local id=boundedId(call(wheel,"getId"))
        if not wheel or not id then return nil,"wheel identity unavailable: "..tostring(index)end
        if seen[id]then return nil,"duplicate wheel identity: "..id end
        seen[id]=true
        local tire=call(vehicle,"getPartById","Tire"..id)
        if not tire then return nil,"wheel tire part unavailable: "..id end
        if call(tire,"getInventoryItem")==nil then
            result.unsupported[#result.unsupported+1]={id=id,index=index,reason="tire missing; contact semantics unverified"}
        else
            local offset=call(wheel,"getOffset")
            local out=vectorType.new()
            local world=offset and call(vehicle,"getWorldPos",offset,out)or nil
            local x,y,z=component(world,"x"),component(world,"y"),component(world,"z")
            if not x or not y or not z then return nil,"wheel transform unavailable: "..id end
            result.contacts[#result.contacts+1]={id=id,index=index,x=x,y=y,z=z,kind="wheel",supported=true}
        end
    end
    return result
end

return Contacts
