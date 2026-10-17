package.loaded["groundWorks/API"]=nil;groundWorks=nil;require"groundWorks/API"
local Diagnostics=dofile(arg[1])
local store={schemaVersion=1,jobs={},cellOwners={a="a",b="b"},stockpiles={pile={soil=7}},processedOperations={}}
for _,id in ipairs({"charlie","alpha","bravo"})do store.jobs[id]={id=id,type="trench",status=id=="bravo"and"quarantined"or"active",
    topology={count=2},targetDepth=1,workCompleted=1,workRequired=4,fillWorkCompleted=0,fillWorkRequired=3,
    soilVolume=5,looseSoil=2,reservedBackfillSoil=id=="charlie"and 1 or 0}end
local summary=assert(Diagnostics.summary(store));assert(summary.jobs==3 and summary.stockpiles==1 and summary.reservedCells==2)
assert(summary.looseSoil==6 and summary.stockpiledSoil==7 and summary.reservedBackfillSoil==1)
assert(summary.statuses.active==2 and summary.statuses.quarantined==1)
local first=assert(Diagnostics.listJobs(store,nil,2));assert(first.jobs[1].id=="alpha"and first.jobs[2].id=="bravo"and first.nextCursor=="bravo")
local second=assert(Diagnostics.listJobs(store,first.nextCursor,2));assert(#second.jobs==1 and second.jobs[1].id=="charlie"and second.nextCursor==nil)
first.jobs[1].status="mutated";assert(store.jobs.alpha.status=="active")
assert(not Diagnostics.listJobs(store,"missing",2));assert(Diagnostics.listJobs(store,nil,1000).limit==64)
assert(Diagnostics.report(store,nil,1).page.total==3)
print("groundWorks bounded earthwork diagnostics checks passed")
