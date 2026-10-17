local API=require "groundWorks/API"
local Probe={MAX_OBJECTS=64}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return nil end
    local called,value=pcall(fn,object,...)
    if called then return value end
    return nil
end

local function finite(value)
    value=tonumber(value)
    return value and value==value and value~=math.huge and value~=-math.huge and value or nil
end

local function spriteName(object)
    local sprite=call(object,"getSprite")
    return tostring(call(sprite,"getName")or call(object,"getSpriteName")or call(object,"getTextureName")or"")
end

local PROPERTY_NAMES={"solidfloor","diamondFloor","attachedFloor","IsFloorAttached","FloorOverlay",
    "FloorAttachmentN","FloorAttachmentE","FloorAttachmentS","FloorAttachmentW","grassFloor","GRASS_FLOOR","water"}

local function propertiesFor(object)
    local sprite=call(object,"getSprite")
    local properties=call(sprite,"getProperties")or call(object,"getProperties")
    local result={}
    for _,name in ipairs(PROPERTY_NAMES)do
        local present=call(properties,"has",name)
        local value=call(properties,"get",name)
        if present==true or value~=nil then result[name]=value==nil and true or value end
    end
    return result
end

function Probe.sample(square)
    if not square then return nil,"square required"end
    local x,y,z=finite(call(square,"getX")),finite(call(square,"getY")),finite(call(square,"getZ"))
    if not x or not y or not z then return nil,"square coordinates unavailable"end
    local surface,surfaceError=API.inspectSurface(square)
    local wear,wearError=API.getWearState(square)
    local floor=call(square,"getFloor")
    local objects=call(square,"getObjects")
    local size=math.max(0,math.floor(finite(call(objects,"size"))or 0))
    local result={x=x,y=y,z=z,outside=call(square,"isOutside")==true,hasRoom=call(square,"getRoom")~=nil,
        floorSprite=spriteName(floor),surfaceError=surface and nil or tostring(surfaceError),
        wearError=wear and nil or tostring(wearError),objects={},
        truncated=size>Probe.MAX_OBJECTS,objectCount=size,
        wear={stage=tostring(wear and wear.stage or"UNTOUCHED"),value=finite(wear and wear.wear)or 0,
            foot=finite(wear and wear.traffic and wear.traffic.foot)or 0,
            animal=finite(wear and wear.traffic and wear.traffic.animal)or 0,
            vehicle=finite(wear and wear.traffic and wear.traffic.vehicle)or 0}}
    if surface then result.surfaceError=nil end
    if wear then result.wearError=nil end
    if surface then
        result.surface={providerId=surface.providerId,material=surface.material,natural=surface.natural==true,
            water=surface.water==true,trafficWear=surface.trafficWear~=false,wearResistance=finite(surface.wearResistance)}
    end
    for index=0,math.min(size,Probe.MAX_OBJECTS)-1 do
        local object=call(objects,"get",index)
        result.objects[#result.objects+1]={index=index,isFloor=object==floor,sprite=spriteName(object),
            objectName=tostring(call(object,"getObjectName")or""),name=tostring(call(object,"getName")or""),
            properties=propertiesFor(object)}
    end
    return result
end

local function propertyText(properties)
    local values={}
    for _,name in ipairs(PROPERTY_NAMES)do
        if properties[name]~=nil then values[#values+1]=name.."="..tostring(properties[name])end
    end
    return #values>0 and table.concat(values,",")or"-"
end

function Probe.printCurrent()
    local player=type(getPlayer)=="function"and getPlayer()or nil
    local result,err=Probe.sample(call(player,"getCurrentSquare")or call(player,"getSquare"))
    if not result then print("[groundWorks][SurfaceProbe] FAIL "..tostring(err));return false end
    local surface=result.surface
    print(string.format("[groundWorks][SurfaceProbe] square=%d,%d,%d outside=%s room=%s floor=%s objects=%d truncated=%s",
        result.x,result.y,result.z,tostring(result.outside),tostring(result.hasRoom),result.floorSprite,
        result.objectCount,tostring(result.truncated)))
    if surface then
        print("[groundWorks][SurfaceProbe] surface provider="..tostring(surface.providerId).." material="..
            tostring(surface.material).." natural="..tostring(surface.natural).." water="..tostring(surface.water)..
            " trafficWear="..tostring(surface.trafficWear).." resistance="..tostring(surface.wearResistance))
    else print("[groundWorks][SurfaceProbe] surface unavailable: "..tostring(result.surfaceError))end
    print("[groundWorks][SurfaceProbe] wear stage="..result.wear.stage.." value="..result.wear.value..
        " foot="..result.wear.foot.." animal="..result.wear.animal.." vehicle="..result.wear.vehicle)
    for _,object in ipairs(result.objects)do
        print("[groundWorks][SurfaceProbe] object["..object.index.."] floor="..tostring(object.isFloor)..
            " sprite="..object.sprite.." objectName="..object.objectName.." name="..object.name..
            " properties="..propertyText(object.properties))
    end
    return true,result
end

groundWorksSurfaceProbe=function()return Probe.printCurrent()end
print("[groundWorks][SurfaceProbe] Ready: stand on a test surface and run groundWorksSurfaceProbe()")
return Probe
