local function vector(x,y,z)return{x=function()return x end,y=function()return y end,z=function()return z end}end
Vector3f={new=function()return vector(0,0,0)end}
BaseVehicle={MAX_WHEELS=8}
local wheels={{id="FrontLeft",x=-1,y=2,z=0},{id="FrontRight",x=1,y=2,z=0}}
local tires={FrontLeft={item={}},FrontRight={item={}}}
local script={getWheelCount=function()return#wheels end,getWheel=function(_,index)local w=wheels[index+1];return{
    getId=function()return w.id end,getOffset=function()return vector(w.x,w.y,w.z)end}end}
local vehicle={getScript=function()return script end,
    getPartById=function(_,id)local tire=tires[id:sub(5)];if not tire then return nil end;return{getInventoryItem=function()return tire.item end}end,
    getWorldPos=function(_,offset)return vector(offset:x()+10,offset:y()+20,offset:z())end}
local Contacts=dofile(arg[1])
local sample=assert(Contacts.sample(vehicle))
assert(sample.declared==2 and#sample.contacts==2 and#sample.unsupported==0)
assert(sample.contacts[1].id=="FrontLeft"and sample.contacts[1].x==9 and sample.contacts[2].y==22)
tires.FrontLeft.item=nil
sample=assert(Contacts.sample(vehicle))
assert(#sample.contacts==1 and#sample.unsupported==1 and sample.unsupported[1].id=="FrontLeft",
    "removed tires must not be fabricated as supported contacts")
tires.FrontLeft=nil
assert(Contacts.sample(vehicle)==nil,"unknown tire/contact mapping must fail closed")
tires.FrontLeft={item={}};wheels[2].id="FrontLeft"
assert(Contacts.sample(vehicle)==nil,"duplicate contact identity must fail closed")
wheels[2].id="FrontRight";BaseVehicle.MAX_WHEELS=1
assert(Contacts.sample(vehicle)==nil,"engine contact bound must be enforced")
print("groundWorks verified installed-wheel contact sampling checks passed")
