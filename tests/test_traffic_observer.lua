local calls={}
local fakeAPI={reportTraffic=function(square,kind,amount,age,recoveryRate)
    calls[#calls+1]={square=square,kind=kind,amount=amount,age=age,recoveryRate=recoveryRate}
    return true,{stage="LIGHT_WEAR"}
end}
package.loaded["groundWorks/API"]=nil
package.preload["groundWorks/API"]=function() return fakeAPI end
local cleared=0
package.preload["groundWorks/WheelContacts"]=function()return{sample=function(vehicle)return vehicle.sample end}end
package.preload["groundWorks/WheelWear"]=function()return{
    plan=function(vehicle)return vehicle.plans[vehicle.planIndex]end,
    clear=function()cleared=cleared+1 end,
}end

SandboxVars={groundWorks={EnablePlayerFootTraffic=true,EnableVehicleTraffic=true,WearRecoveryPerDay=.25}}
getGameTime=function() return {getWorldAgeHours=function() return 42.5 end} end
instanceof=function(subject,className)
    return className=="IsoAnimal" and subject and subject.isAnimal==true
end

local Observer=dofile(arg[1])
local callback
assert(Observer.install({OnPlayerMove={Add=function(fn) callback=fn end}})==true)
assert(type(callback)=="function" and Observer.install({})==true,"install must be idempotent")

local function square(x,y,z)
    return {getX=function() return x end,getY=function() return y end,getZ=function() return z end}
end
local player={current=square(10,20,0),vehicle=nil}
function player:getCurrentSquare() return self.current end
function player:getVehicle() return self.vehicle end

callback(player)
assert(#calls==1 and calls[1].kind=="foot" and calls[1].amount==1 and calls[1].age==42.5)
assert(calls[1].recoveryRate==.25,"observer must use the server sandbox recovery rate")
callback(player)
assert(#calls==1,"movement frames inside one square must be deduplicated")

local animal={current=square(10,21,0),isAnimal=true}
function animal:getCurrentSquare() return self.current end
function animal:getVehicle() return nil end
callback(animal)
assert(#calls==1,"IsoAnimal must not inherit player foot-wear behavior")

player.current=square(11,20,0);callback(player)
assert(#calls==2,"entering a different square must report one contribution")

SandboxVars.groundWorks.EnablePlayerFootTraffic=false
player.current=square(12,20,0);callback(player)
assert(#calls==2,"disabled observation must not mutate traffic")

SandboxVars.groundWorks.EnablePlayerFootTraffic=true
local vehicle={sample={contacts={{id="L"},{id="R"}},unsupported={}},planIndex=1,plans={
    {seeded=2,tiles={},resolved=0,unresolved=0,contacts=2},
    {seeded=0,tiles={},resolved=0,unresolved=0,contacts=2,crossed=2},
    {seeded=0,tiles={{square=square(13,20,0)},{square=square(13,21,0)}},resolved=2,unresolved=0,contacts=2,crossed=2},
}}
player.vehicle=vehicle
callback(player)
assert(#calls==2,"first occupied-vehicle sample must seed without stationary wear")
vehicle.planIndex=2
local passenger={current=player.current,vehicle=vehicle}
function passenger:getCurrentSquare()return self.current end
function passenger:getVehicle()return self.vehicle end
callback(passenger)
assert(#calls==2,"multiple occupants must not multiply unchanged wheel paths")
vehicle.planIndex=3;callback(player)
assert(#calls==4 and calls[3].kind=="vehicle"and calls[4].kind=="vehicle",
    "one vehicle step must report every resolved deduplicated wheel tile")
SandboxVars.groundWorks.EnableVehicleTraffic=false
callback(player)
assert(#calls==4,"vehicle traffic sandbox toggle must prevent mutation")
assert(cleared==1,"disabled vehicle traffic must clear trajectory history")

player.vehicle=nil
player.current=square(16,20,0)
fakeAPI.reportTraffic=function() return false,"surface does not retain traffic wear" end
callback(player)

player.current=square(17,20,0)
fakeAPI.reportTraffic=function() error("provider failure") end
callback(player)
local report=Observer.getDiagnostics()
assert(report.installed and report.events==11 and report.recorded==4 and report.deduplicated==2)
assert(report.disabled==2 and report.vehicle==4 and report.vehicleRecorded==2 and report.vehicleDisabled==1)
assert(report.contactSamples==3 and report.contacts==6 and report.seededVehicles==1)
assert(report.crossedTiles==4 and report.resolvedTiles==2 and report.unresolvedTiles==0)
assert(report.animalExcluded==1 and report.ignored==1 and report.failed==1)

SandboxVars.groundWorks.EnableVehicleTraffic=true
vehicle.sample=nil
local priorCleared=cleared
assert(not Observer.observeVehicle(vehicle) and cleared==priorCleared+1,
    "missing wheel samples must clear stale trajectories")
vehicle.sample={contacts={},unsupported={}};vehicle.planIndex=99
assert(not Observer.observeVehicle(vehicle) and cleared==priorCleared+2,
    "rejected wheel plans must clear history so later samples can recover")
isClient=function()return true end;isServer=function()return false end
assert(not Observer.observeVehicle(vehicle) and cleared==priorCleared+3,
    "direct vehicle observation must reject client authority")
isClient=nil;isServer=nil

package.preload["groundWorks/API"]=nil
package.preload["groundWorks/WheelContacts"]=nil
package.preload["groundWorks/WheelWear"]=nil
package.loaded["groundWorks/API"]=nil
print("groundWorks bounded player traffic observer checks passed")
