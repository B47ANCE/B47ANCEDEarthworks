local API=require "groundWorks/Load"
require "groundWorks/EarthworkStoreClient"
require "groundWorks/WheelContactProbe"
require "groundWorks/SurfaceProbe"
require "groundWorks/ExcavationExperimentClient"
require "groundWorks/HandToolsClient"
require "groundWorks/ExcavationBuildMenu"
API.CavityTerrain.installClient()
require "groundWorks/EarthworkDiagnosticsClient"
require "groundWorks/WheelbarrowClient"
require "groundWorks/WheelbarrowBodyMenu"
return API
