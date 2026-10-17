local calls={}
local api={reportTraffic=function(square,kind,amount,age,recovery)
    calls[#calls+1]={square=square,kind=kind,amount=amount,age=age,recovery=recovery}
    return true,{}
end}
package.loaded["groundWorks/API"]=api
local Observer=dofile(arg[1])
local age=5
getGameTime=function()return{getWorldAgeHours=function()return age end}end
isClient=function()return false end
isServer=function()return false end
instanceof=function(subject,class)return subject.animal==true and class=="IsoAnimal"end
SandboxVars={groundWorks={EnableAnimalTraffic=true,EnablePlayerFootTraffic=false,WearRecoveryPerDay=.2}}
local function square(x,y,z)
    return{getX=function()return x end,getY=function()return y end,getZ=function()return z or 0 end}
end
local animal={animal=true,current=square(1,1)}
function animal:getCurrentSquare()return self.current end
function animal:isDead()return self.dead==true end
function animal:getVehicle()return self.vehicle end
local callback,count
count=0
assert(not Observer.install({}))
assert(Observer.install({OnPlayerMove={Add=function(fn)callback=fn;count=count+1 end}}))
assert(Observer.install({}) and count==1)
assert(callback(animal) and #calls==0,"first observation seeds without wear")
assert(callback(animal) and #calls==0)
animal.current=square(2,1);assert(callback(animal))
assert(#calls==1 and calls[1].kind=="animal" and calls[1].amount==1 and calls[1].recovery==.2)
assert(calls[1].square==animal.current and calls[1].age==age)
animal.current=square(3,2);assert(callback(animal) and #calls==2,"adjacent diagonal travel counts once")
assert(callback({animal=false}) and #calls==2,"players cannot create animal wear")
SandboxVars.groundWorks.EnableAnimalTraffic=false
animal.current=square(4,2);assert(callback(animal) and #calls==2)
SandboxVars.groundWorks.EnableAnimalTraffic=true
assert(callback(animal) and #calls==2,"re-enabling must reseed")
animal.current=square(40,2);assert(callback(animal) and #calls==2,"teleport has no fabricated trail")
animal.current=square(41,2,1);assert(callback(animal) and #calls==2)
animal.vehicle={};animal.current=square(42,2,1);assert(callback(animal) and #calls==2)
animal.vehicle=nil;assert(callback(animal) and #calls==2)
animal.dead=true;animal.current=square(43,2,1);assert(callback(animal) and #calls==2)
animal.dead=false;assert(callback(animal) and #calls==2)
isClient=function()return true end
animal.current=square(44,2,1);assert(not callback(animal) and #calls==2,"client cannot mutate wear")
isClient=function()return false end
assert(callback(animal) and #calls==2)
age=7;animal.current=square(45,2,1);assert(callback(animal) and #calls==2,"stale travel must reseed")
age=6;animal.current=square(46,2,1);assert(callback(animal) and #calls==2,"time reversal must reseed")
animal.current=square(0/0,2);assert(not callback(animal) and #calls==2)
animal.current=square(47,2,1);assert(callback(animal) and #calls==2)
animal.current=square(48,2,1);assert(callback(animal) and #calls==3)
local snapshot=Observer.getDiagnostics();snapshot.recorded=999
assert(Observer.getDiagnostics().recorded==3)
api.reportTraffic=function()error("provider error")end
animal.current=square(49,2,1);assert(not callback(animal),"provider errors are contained")
assert(callback(animal),"failure clears history and reseeds")
getGameTime=function()error("clock error")end
assert(not callback(animal),"clock errors are contained")
getGameTime=function()return{getWorldAgeHours=function()return age end}end
animal.getVehicle=false;assert(callback(animal) and #calls==3,"unknown transport state cannot produce wear")
assert(Observer.getDiagnostics().installed)
print("groundWorks independent bounded animal traffic checks passed")
