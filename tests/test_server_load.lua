local api={}
for _,name in ipairs({'CavityCollapse','WornSurface','RainCleaningServer'})do
    package.preload['groundWorks/'..name]=function()return{install=function()return true end}end
end
local installed=0
local animalInstalled=0
local unoccupiedInstalled=0
local syncInstalled=0
local commandInstalled=0
local events={OnPlayerMove={Add=function() end},OnClientCommand={Add=function()commandInstalled=commandInstalled+1 end}}
Events=events
package.loaded["groundWorks/SurfaceSync"]=nil
package.preload["groundWorks/SurfaceSync"]=function()
    return{install=function(received)assert(received==events);syncInstalled=syncInstalled+1;return true end}
end
package.loaded["groundWorks/UnoccupiedVehicleObserver"]=nil
package.preload["groundWorks/UnoccupiedVehicleObserver"]=function()
    return{install=function(received)assert(received==events);unoccupiedInstalled=unoccupiedInstalled+1;return true end}
end
package.loaded["groundWorks/AnimalTrafficObserver"]=nil
package.preload["groundWorks/AnimalTrafficObserver"]=function()
    return{install=function(received)assert(received==events);animalInstalled=animalInstalled+1;return true end}
end

for _,name in ipairs({"groundWorks/Load","groundWorks/TrafficObserver","groundWorks/ExcavationExperimentServer","groundWorks/EarthworkStoreServer","groundWorks/EarthworkDiagnosticsServer"}) do package.loaded[name]=nil end
package.preload["groundWorks/Load"]=function() return api end
package.preload["groundWorks/TrafficObserver"]=function()
    return {install=function(received)
        assert(received==events,"server loader must pass the engine event table")
        installed=installed+1
        return true
    end}
end
package.preload["groundWorks/ExcavationExperimentServer"]=function()
    return{install=function(received)assert(received==events);received.OnClientCommand.Add();return true end}
end
package.preload["groundWorks/EarthworkStoreServer"]=function()return{install=function(received)assert(received==events);return true end}end
package.preload["groundWorks/EarthworkDiagnosticsServer"]=function()
    return{install=function(received)assert(received==events);received.OnClientCommand.Add();return true end}
end

local extraInstalled=0
for _,name in ipairs({"OpenPitServer","CavityDepositObserver","HandToolsServer"})do
    package.preload["groundWorks/"..name]=function()return{install=function(received)
        assert(received==events);extraInstalled=extraInstalled+1;return true
    end}end
end
package.preload["groundWorks/WheelbarrowServer"]=function()
    return{install=function(received)assert(received==events);received.OnClientCommand.Add();return true end}
end
package.preload["groundWorks/WheelbarrowTransactions"]=function()return{install=function()return true end}end
assert(dofile(arg[1])==api,"server loader must return the canonical groundWorks API")
assert(extraInstalled==3,"all new cavity/hand-tool installers must run")
assert(installed==1,"server loader must install the traffic observer exactly once")
assert(animalInstalled==1,"server loader must install the independent animal observer")
assert(unoccupiedInstalled==1,"server loader must install the bounded unoccupied vehicle observer")
assert(syncInstalled==1,"server loader must install surface synchronization")
assert(commandInstalled==3,"server loader must install the bounded command handlers exactly once")

package.preload["groundWorks/Load"]=nil
package.preload["groundWorks/AnimalTrafficObserver"]=nil
package.preload["groundWorks/UnoccupiedVehicleObserver"]=nil
package.preload["groundWorks/SurfaceSync"]=nil
package.preload["groundWorks/TrafficObserver"]=nil
package.preload["groundWorks/ExcavationExperimentServer"]=nil
package.preload["groundWorks/EarthworkStoreServer"]=nil
package.preload["groundWorks/EarthworkDiagnosticsServer"]=nil
package.loaded["groundWorks/Load"]=nil
package.loaded["groundWorks/TrafficObserver"]=nil
print("groundWorks server production load-graph checks passed")
