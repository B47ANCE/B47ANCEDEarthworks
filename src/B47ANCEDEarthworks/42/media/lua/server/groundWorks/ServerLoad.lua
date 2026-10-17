local API=require "groundWorks/Load"
local SurfaceSync=require "groundWorks/SurfaceSync"
local syncOk,syncErr=SurfaceSync.install(Events)
if not syncOk and print then print("[groundWorks] Surface synchronization unavailable: "..tostring(syncErr))end
local AnimalTrafficObserver=require "groundWorks/AnimalTrafficObserver"
local animalOk,animalErr=AnimalTrafficObserver.install(Events)
if not animalOk and print then print("[groundWorks] Animal traffic observer unavailable: "..tostring(animalErr))end
local TrafficObserver=require "groundWorks/TrafficObserver"
local ok,err=TrafficObserver.install(Events)
if not ok and print then print("[groundWorks] Player traffic observer unavailable: "..tostring(err)) end
local UnoccupiedVehicleObserver=require "groundWorks/UnoccupiedVehicleObserver"
local unoccupiedOk,unoccupiedErr=UnoccupiedVehicleObserver.install(Events)
if not unoccupiedOk and print then print("[groundWorks] Unoccupied vehicle observer unavailable: "..tostring(unoccupiedErr))end
local ExperimentServer=require "groundWorks/ExcavationExperimentServer"
local experimentOk,experimentErr=ExperimentServer.install(Events)
if not experimentOk and print then print("[groundWorks] Excavation experiment unavailable: "..tostring(experimentErr))end
local OpenPitServer=require "groundWorks/OpenPitServer"
local openPitOk,openPitErr=OpenPitServer.install(Events)
if not openPitOk and print then print("[groundWorks] Open pit cavity unavailable: "..tostring(openPitErr))end
local CavityDepositObserver=require "groundWorks/CavityDepositObserver"
local depositOk,depositErr=CavityDepositObserver.install(Events)
if not depositOk and print then print("[groundWorks] Cavity deposit observer unavailable: "..tostring(depositErr))end
local HandToolsServer=require "groundWorks/HandToolsServer"
local handOk,handErr=HandToolsServer.install(Events)
if not handOk and print then print("[groundWorks] Hand-tool excavation unavailable: "..tostring(handErr))end
local EarthworkStoreServer=require "groundWorks/EarthworkStoreServer"
local storeOk,storeErr=EarthworkStoreServer.install(Events)
if not storeOk and print then print("[groundWorks] Earthwork store unavailable: "..tostring(storeErr))end
local EarthworkDiagnosticsServer=require "groundWorks/EarthworkDiagnosticsServer"
local diagnosticsOk,diagnosticsErr=EarthworkDiagnosticsServer.install(Events)
if not diagnosticsOk and print then print("[groundWorks] Earthwork diagnostics unavailable: "..tostring(diagnosticsErr))end
local SurfacePresentation=require "groundWorks/SurfacePresentation"
require('groundWorks/WornSurface').install()
local presentationOk=SurfacePresentation.install()
if not presentationOk and print then print("[groundWorks] Surface presentation unavailable")end
require('groundWorks/CavityCollapse').install(Events)
require('groundWorks/RainCleaningServer').install(Events)
require('groundWorks/WheelbarrowServer').install(Events)
pcall(require('groundWorks/WheelbarrowTransactions').install)
return API
