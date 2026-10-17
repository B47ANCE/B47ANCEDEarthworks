local API={inspectSurface=function(square)return{providerId="vanilla.floor",material="natural",natural=true,
    water=false,trafficWear=true,wearResistance=.75,floor=square:getFloor()}end,
    getWearState=function()return{stage="WORN",wear=23,traffic={foot=4,animal=2,vehicle=1}}end}
package.preload["groundWorks/API"]=function()return API end
local function properties(values)return{has=function(_,name)return values[name]~=nil end,get=function(_,name)return values[name]end}end
local function object(sprite,values)
    local self={sprite={getName=function()return sprite end,getProperties=function()return properties(values or{})end}}
    function self:getSprite()return self.sprite end;function self:getObjectName()return"IsoObject"end;function self:getName()return"Test"end
    return self
end
local floor=object("blends_natural_01_0",{solidfloor=true,grassFloor="1"});local overlay=object("overlay",{FloorOverlay=true})
local values={floor,overlay};local list={size=function()return#values end,get=function(_,index)return values[index+1]end}
local square={getX=function()return 10 end,getY=function()return 20 end,getZ=function()return 0 end,isOutside=function()return true end,
    getRoom=function()return nil end,getFloor=function()return floor end,getObjects=function()return list end}
local Probe=dofile(arg[1]);local result=assert(Probe.sample(square))
assert(result.x==10 and result.y==20 and result.z==0 and result.outside and not result.hasRoom)
assert(result.surface.material=="natural"and result.surfaceError==nil and result.wear.stage=="WORN"and result.wear.animal==2)
assert(result.objectCount==2 and#result.objects==2 and result.objects[1].isFloor and result.objects[2].properties.FloorOverlay==true)
getPlayer=function()return{getCurrentSquare=function()return square end}end
assert(Probe.printCurrent())
local many={};for index=1,Probe.MAX_OBJECTS+3 do many[index]=object("tile"..index,{})end
square.getObjects=function()return{size=function()return#many end,get=function(_,index)return many[index+1]end}end
result=assert(Probe.sample(square));assert(result.truncated and#result.objects==Probe.MAX_OBJECTS)
assert(Probe.sample(nil)==nil)
package.preload["groundWorks/API"]=nil;package.loaded["groundWorks/API"]=nil
print("groundWorks bounded current-square surface probe checks passed")
