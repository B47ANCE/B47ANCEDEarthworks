package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API";local Geometry=dofile(arg[1])
local job={schemaVersion=1,id="trench-a",topology={cells={
    {x=4,y=8,z=0,variant="end_east",mask=2},{x=5,y=8,z=0,variant="end_west",mask=8}}}}
local plan=assert(Geometry.plan(job,"geometry-a","excavate"))
assert(plan.jobId=="trench-a"and plan.mode=="excavate"and#plan.cells==2)
assert(plan.cells[1].surfaceKey=="4:8:0"and plan.cells[1].undergroundKey=="4:8:-1")
local receipt={schemaVersion=1,verified=true,operationId="geometry-a",jobId="trench-a",mode="excavate",outcome="committed",cells={
    {surfaceKey="5:8:0",undergroundKey="5:8:-1",verified=true},
    {surfaceKey="4:8:0",undergroundKey="4:8:-1",verified=true}}}
assert(Geometry.verifyReceipt(plan,receipt,"committed"))
receipt.cells[2].verified=false;assert(not Geometry.verifyReceipt(plan,receipt,"committed"))
receipt.cells[2].verified=true;receipt.cells[2].undergroundKey="4:8:0";assert(not Geometry.verifyReceipt(plan,receipt,"committed"))
assert(not Geometry.plan(job,"geometry-a","unsupported"))
print("groundWorks bounded geometry-plan and receipt checks passed")
