package.loaded["groundWorks/Load"]=nil
package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/Projects"]=nil
package.loaded["groundWorks/SurfaceMutation"]=nil
package.loaded["groundWorks/ConstructedRoutes"]=nil
package.loaded["groundWorks/ExcavationExperiment"]=nil
package.loaded["groundWorks/TrenchTopology"]=nil
package.loaded["groundWorks/EarthworkProviders"]=nil
package.loaded["groundWorks/EarthworkGeometry"]=nil
package.loaded["groundWorks/EarthworkJobs"]=nil
package.loaded["groundWorks/EarthworkIntegrity"]=nil
package.loaded["groundWorks/EarthworkPersistence"]=nil
package.loaded["groundWorks/EarthworkDiagnostics"]=nil
groundWorks=nil

local API=require "groundWorks/Load"

assert(API==groundWorks,"production Load must return the canonical API table")
assert(type(API.Projects)=="table","production Load must expose the project lifecycle")
assert(type(API.Projects.begin)=="function" and type(API.Projects.contributeTransaction)=="function",
    "production Load must expose project mutation entry points")
assert(type(API.SurfaceMutation)=="table" and type(API.replaceFloorSprite)=="function",
    "production Load must retain the surface-mutation adapter")
assert(type(API.ConstructedRoutes)=="table"and type(API.ConstructedRoutes.commit)=="function",
    "production Load must expose deferred constructed-route commits")
assert(type(API.WheelTrajectory)=="table" and type(API.WheelTrajectory.trace)=="function",
    "production Load must expose bounded wheel trajectory traversal")
assert(type(API.ExcavationExperiment)=="table"and type(API.ExcavationExperiment.execute)=="function",
    "production Load must expose the quarantined excavation experiment")
assert(type(API.TrenchTopology)=="table"and type(API.TrenchTopology.analyze)=="function",
    "production Load must expose trench topology")
assert(type(API.EarthworkProviders)=="table"and type(API.EarthworkProviders.authorize)=="function",
    "production Load must expose shared manual/machine work providers")
assert(type(API.EarthworkGeometry)=="table"and type(API.EarthworkGeometry.verifyReceipt)=="function",
    "production Load must expose bounded geometry transactions")
assert(type(API.EarthworkJobs)=="table"and type(API.EarthworkJobs.beginGeometryCommit)=="function",
    "production Load must expose authoritative earthwork jobs")
assert(type(API.EarthworkIntegrity)=="table"and type(API.EarthworkIntegrity.audit)=="function",
    "production Load must expose persisted-state integrity auditing")
assert(type(API.EarthworkPersistence)=="table"and type(API.EarthworkPersistence.attachStore)=="function",
    "production Load must expose persistent earthwork store attachment")
assert(type(API.EarthworkDiagnostics)=="table"and type(API.EarthworkDiagnostics.listJobs)=="function",
    "production Load must expose bounded earthwork diagnostics")

print("groundWorks production load-graph checks passed")
