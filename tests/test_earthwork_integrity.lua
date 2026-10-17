package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API";local Integrity=dofile(arg[1])
local store={schemaVersion=1,jobs={},cellOwners={},stockpiles={},processedOperations={}}
assert(Integrity.audit(store).valid)
store.jobs.a={schemaVersion=1,id="a",status="active",workRequired=2,workCompleted=1,soilVolume=3,looseSoil=0,reservedBackfillSoil=0,
    topology={count=1,cells={{key="1:2:0"}}}};store.cellOwners["1:2:0"]="a"
assert(Integrity.audit(store).valid)
store.cellOwners["1:2:0"]="other";local audit=Integrity.audit(store);assert(not audit.valid and audit.errorCount==2)
store.cellOwners["1:2:0"]="a";store.jobs.a.looseSoil=-1;assert(not Integrity.audit(store).valid)
store.jobs.a.looseSoil=0;store.stockpiles.p={schemaVersion=1,id="p",capacity=2,soil=3};assert(not Integrity.audit(store).valid)
print("groundWorks persisted earthwork integrity checks passed")
