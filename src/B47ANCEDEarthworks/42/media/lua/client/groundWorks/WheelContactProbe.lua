local Contacts=require "groundWorks/WheelContacts"
local Probe={}
local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...);if called then return result end
end
function Probe.sample(vehicle)
    local result,err=Contacts.sample(vehicle)
    if not result then return nil,err end
    result.vehicle=vehicle
    result.count=result.declared
    for _,contact in ipairs(result.contacts)do
        local x,y,z=contact.x,contact.y,contact.z
        local cell=type(getCell)=="function"and getCell()or nil
        local square=cell and call(cell,"getGridSquare",math.floor(x),math.floor(y),math.floor(z))or nil
        contact.tileX=math.floor(x);contact.tileY=math.floor(y);contact.tileZ=math.floor(z);contact.squareResolved=square~=nil
    end
    return result
end
function Probe.printCurrent()
    local player=type(getPlayer)=="function"and getPlayer()or nil;local vehicle=call(player,"getVehicle")
    if not vehicle then print("[groundWorks][WheelProbe] Enter a vehicle first");return false end
    local sample,err=Probe.sample(vehicle);if not sample then print("[groundWorks][WheelProbe] FAIL "..tostring(err));return false end
    print("[groundWorks][WheelProbe] contacts="..sample.count)
    for _,contact in ipairs(sample.contacts)do
        print(string.format("[groundWorks][WheelProbe] %s index=%d world=%.3f,%.3f,%.3f tile=%d,%d,%d resolved=%s",
            contact.id,contact.index,contact.x,contact.y,contact.z,contact.tileX,contact.tileY,contact.tileZ,tostring(contact.squareResolved)))
    end
    for _,contact in ipairs(sample.unsupported or{})do
        print(string.format("[groundWorks][WheelProbe] unsupported %s index=%d reason=%s",contact.id,contact.index,tostring(contact.reason)))
    end
    return true
end
groundWorksWheelProbe=function()return Probe.printCurrent()end
print("[groundWorks][WheelProbe] Ready: enter a vehicle and run groundWorksWheelProbe()")
return Probe
