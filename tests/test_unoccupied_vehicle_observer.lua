local calls,clears={},{}
package.loaded["groundWorks/API"]={}
package.loaded["groundWorks/TrafficObserver"]={observeVehicle=function(vehicle)calls[#calls+1]=vehicle;return true end}
package.loaded["groundWorks/WheelWear"]={clear=function(vehicle)clears[#clears+1]=vehicle end}
local Observer=dofile(arg[1])
SandboxVars={groundWorks={EnableVehicleTraffic=true,EnableUnoccupiedVehicleTraffic=true}}
isClient=function()return false end
isServer=function()return false end
local vehicles={}
for index=1,20 do
    vehicles[index]={index=index,getMaxPassengers=function()return 2 end,
        getCharacter=function()return nil end,getCurrentSquare=function()return{}end}
end
getCell=function()return{getVehicles=function()return{
    size=function()return#vehicles end,get=function(_,index)return vehicles[index+1]end,
}end}end
local callback,installs=nil,0
assert(not Observer.install({}))
assert(Observer.install({OnTick={Add=function(fn)callback=fn;installs=installs+1 end}}))
assert(Observer.install({}) and installs==1)
local function batch()for _=1,Observer.TICK_INTERVAL do callback()end end
batch();assert(#calls==8 and #clears==8,"first bounded batch seeds selected vehicles")
batch();assert(#calls==16)
batch();assert(#calls==24 and #clears==20,"cursor wraps fairly without reseeding continuous samples")
for index=1,20 do assert(calls[index]==vehicles[index])end
vehicles[5].getCharacter=function(_,seat)return seat==1 and{}or nil end
vehicles[6].getMaxPassengers=function()return 99 end
vehicles[7].getCharacter=function()error("seat inaccessible")end
vehicles[8].getCurrentSquare=function()return nil end
batch();assert(#calls==28,"occupied, unknown occupancy and unresolved vehicles are skipped")
local diagnostic=Observer.getDiagnostics()
assert(diagnostic.occupied==1 and diagnostic.failed==3)
SandboxVars.groundWorks.EnableUnoccupiedVehicleTraffic=false
local before=#calls;batch();assert(#calls==before)
SandboxVars.groundWorks.EnableUnoccupiedVehicleTraffic=true
local beforeClear=#clears;batch()
assert(#calls==before+4 and #clears==beforeClear+7,"re-enable seeds, while occupied vehicles retain their occupied history")
SandboxVars.groundWorks.EnableVehicleTraffic=false
before=#calls;batch();assert(#calls==before,"master traffic toggle disables polling")
SandboxVars.groundWorks.EnableVehicleTraffic=true
isClient=function()return true end
batch();assert(#calls==before,"clients cannot poll/write authoritative vehicle wear")
isClient=function()return false end
getCell=function()error("cell unavailable")end
batch();assert(#calls==before,"cell lookup failure must be contained")
vehicles={vehicles[1],vehicles[1]}
getCell=function()return{getVehicles=function()return{size=function()return 2 end,get=function(_,i)return vehicles[i+1]end}end}end
batch();assert(#calls==before+1,"duplicate engine entries cannot duplicate one batch sample")
local traffic=package.loaded["groundWorks/TrafficObserver"]
traffic.observeVehicle=function()error("wheel observer error")end
batch();assert(Observer.getDiagnostics().failed>=5,"failed vehicle cannot terminate scheduler")
diagnostic=Observer.getDiagnostics();diagnostic.visited=-1
assert(Observer.getDiagnostics().visited>0)
print("groundWorks bounded unoccupied vehicle scheduling checks passed")
