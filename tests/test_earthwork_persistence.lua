package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API"
package.preload["groundWorks/EarthworkJobs"]=function()return{newStore=function()return{schemaVersion=1,jobs={},cellOwners={},stockpiles={},processedOperations={}}end}end
local Integrity=dofile(arg[1]);package.loaded["groundWorks/EarthworkIntegrity"]=Integrity
local Persistence=dofile(arg[2]);Persistence._resetForTests()
local raw={};local ok,attached=Persistence.attachStore(raw);assert(ok and attached==raw and raw.schemaVersion==1)
assert(Persistence.getStore()==raw and Persistence.inspectAttachment().attached)
local existing={schemaVersion=1,jobs={},cellOwners={},stockpiles={},processedOperations={}}
assert(Persistence.attachStore(existing));assert(Persistence.getStore()==existing)
local corrupt={schemaVersion=1,jobs={a={schemaVersion=1,id="a",status="active",workRequired=1,workCompleted=0,soilVolume=1,looseSoil=0,
    reservedBackfillSoil=0,topology={count=1,cells={{key="1:1:0"}}}}},cellOwners={},stockpiles={},processedOperations={}}
assert(not Persistence.attachStore(corrupt));assert(string.find(Persistence.inspectAttachment().reason,"integrity failure",1,true))
assert(not Persistence.attachStore({schemaVersion=2,jobs={},cellOwners={},stockpiles={},processedOperations={}}))
local status=Persistence.inspectAttachment();assert(status.status=="quarantined"and status.reason=="future earthwork store schema"and not status.attached)
assert(not Persistence.attachStore({schemaVersion=1,jobs={}}));assert(Persistence.inspectAttachment().reason=="malformed earthwork store")
package.preload["groundWorks/EarthworkJobs"]=nil;package.loaded["groundWorks/EarthworkJobs"]=nil
package.loaded["groundWorks/EarthworkIntegrity"]=nil
print("groundWorks earthwork persistence attachment checks passed")
