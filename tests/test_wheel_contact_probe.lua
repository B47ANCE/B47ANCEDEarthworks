local offsets={{id="FrontLeft",x=-1,y=2,z=0},{id="FrontRight",x=1,y=2,z=0}}
local function vector(x,y,z)return{x=function()return x end,y=function()return y end,z=function()return z end}end
Vector3f={new=function()return vector(0,0,0)end}
BaseVehicle={MAX_WHEELS=32}
local script={getWheelCount=function()return#offsets end,getWheel=function(self,index)local value=offsets[index+1];return{
    getId=function()return value.id end,getOffset=function()return vector(value.x,value.y,value.z)end}end}
local vehicle={getScript=function()return script end,getWorldPos=function(self,offset)return vector(offset:x()+10,offset:y()+20,offset:z())end,
    getPartById=function(self,id)return{getInventoryItem=function()return{}end}end}
getCell=function()return{getGridSquare=function(self,x,y,z)return x==9 and y==22 and{}or nil end}end
getPlayer=function()return{getVehicle=function()return vehicle end}end
local Probe=dofile(arg[1]);local sample=assert(Probe.sample(vehicle))
assert(sample.count==2 and sample.contacts[1].id=="FrontLeft"and sample.contacts[1].x==9 and sample.contacts[1].squareResolved)
assert(sample.contacts[2].tileX==11 and not sample.contacts[2].squareResolved)
assert(Probe.printCurrent())
script.getWheelCount=function()return 33 end
assert(Probe.sample(vehicle)==nil,"oversized contact sets must fail closed")
print("groundWorks wheel-coordinate runtime probe checks passed")
