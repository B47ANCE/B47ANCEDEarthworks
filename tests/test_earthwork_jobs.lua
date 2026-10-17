package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API";local Topology=dofile(arg[1]);package.loaded["groundWorks/TrenchTopology"]=Topology
local Providers=dofile(arg[2]);package.loaded["groundWorks/EarthworkProviders"]=Providers;Providers._resetForTests()
local Geometry=dofile(arg[3]);package.loaded["groundWorks/EarthworkGeometry"]=Geometry
local Jobs=dofile(arg[4]);local store=Jobs.newStore()
local function receipt(transaction,outcome)
    local result={schemaVersion=1,verified=true,operationId=transaction.operationId,jobId=transaction.plan.jobId,
        mode=transaction.mode,outcome=outcome,cells={}}
    for _,cell in ipairs(transaction.plan.cells)do result.cells[#result.cells+1]={surfaceKey=cell.surfaceKey,undergroundKey=cell.undergroundKey,verified=true}end
    return result
end
Providers.register{id="manual.shovel",kind="manual",capabilities={excavate=true,fill=true},maxWorkPerOperation=4,
    validate=function(_,_,context)return context.request.actor=="survivor","actor required"end}
local vehicleModActive=true
getActivatedMods=function()return{size=function()return vehicleModActive and 1 or 0 end,get=function()return"fixture.localVehicles"end}end
Providers.register{id="machine.fixture",kind="machine",requiredModId="fixture.localVehicles",capabilities={excavate=true,fill=true,transferSoil=true},
    maxWorkPerOperation=100,maxSoilPerOperation=100}
local spec={id="trench-a",type="trench",targetDepth=1,cells={{x=0,y=0,z=0},{x=1,y=0,z=0},{x=1,y=1,z=0}},
    workRequired=10,fillWorkRequired=8,soilVolume=30,createdBy="survivor"}
local ok,result=Jobs.create(store,spec,"create-a");assert(ok and result.job.status=="active"and result.job.topology.count==3)
vehicleModActive=false
assert(not Jobs.applyWork(store,"trench-a","excavate",100,"missing-mod","machine.fixture",{}))
assert(Jobs.snapshot(store,"trench-a").workCompleted==0,"unavailable machinery must not advance persisted work")
assert(not Jobs.create(store,{id="overlap",type="trench",targetDepth=1,cells={{x=1,y=0,z=0}},workRequired=1,fillWorkRequired=1,soilVolume=1},"create-b"))
assert(not Jobs.create(store,{id="depth",type="trench",targetDepth=5,cells={{x=5,y=5,z=0}},workRequired=1,fillWorkRequired=1,soilVolume=1},"create-c"))
ok,result=Jobs.applyWork(store,"trench-a","excavate",4,"dig-1","manual.shovel",{actor="survivor"});assert(ok and result.accepted==4 and not result.completed)
vehicleModActive=true
assert(Jobs.applyWork(store,"trench-a","excavate",4,"dig-1","manual.shovel",{actor="survivor"}))
assert(not Jobs.applyWork(store,"trench-a","excavate",5,"dig-over","manual.shovel",{actor="survivor"}))
ok,result=Jobs.applyWork(store,"trench-a","excavate",100,"dig-2","machine.fixture",{});assert(ok and result.accepted==6 and result.excess==94 and result.completed)
local snapshot=assert(Jobs.snapshot(store,"trench-a"));assert(snapshot.status=="ready_to_excavate"and snapshot.looseSoil==0)
ok,result=Jobs.beginGeometryCommit(store,"trench-a","geometry-1");assert(ok and result.transaction.mode=="excavate")
assert(not Jobs.resolveGeometryCommit(store,"trench-a","wrong","committed",{verified=true}))
ok,result=Jobs.resolveGeometryCommit(store,"trench-a","geometry-1","rolled_back",receipt(result.transaction,"rolled_back"));assert(ok and result.job.status=="ready_to_excavate")
ok,result=Jobs.beginGeometryCommit(store,"trench-a","geometry-2");assert(ok)
ok,result=Jobs.resolveGeometryCommit(store,"trench-a","geometry-2","committed",receipt(result.transaction,"committed"));assert(ok and result.job.status=="excavated"and result.job.looseSoil==30)
assert(Jobs.createStockpile(store,"pile-a",20,"pile-create"))
ok,result=Jobs.transferSoil(store,"trench-a","pile-a","to_stockpile",25,"soil-1","machine.fixture",{});assert(ok and result.accepted==20 and result.excess==5)
assert(not Jobs.beginBackfill(store,"trench-a","backfill-missing"))
ok,result=Jobs.transferSoil(store,"trench-a","pile-a","to_excavation",20,"soil-2","machine.fixture",{});assert(ok and result.accepted==20)
ok,result=Jobs.beginBackfill(store,"trench-a","backfill-begin");assert(ok and result.job.reservedBackfillSoil==30 and result.job.looseSoil==0)
ok,result=Jobs.applyWork(store,"trench-a","fill",4,"fill-1","manual.shovel",{actor="survivor"});assert(ok and not result.completed)
ok,result=Jobs.applyWork(store,"trench-a","fill",100,"fill-2","machine.fixture",{});assert(ok and result.accepted==4 and result.completed)
ok,result=Jobs.beginGeometryCommit(store,"trench-a","fill-geometry");assert(ok)
ok,result=Jobs.resolveGeometryCommit(store,"trench-a","fill-geometry","committed",receipt(result.transaction,"committed"));assert(ok and result.job.status=="filled")
for _,cell in ipairs(result.job.topology.cells)do assert(store.cellOwners[cell.key]==nil)end

local uncertain={id="trench-q",type="trench",targetDepth=1,cells={{x=10,y=10,z=0}},workRequired=1,fillWorkRequired=1,soilVolume=1}
assert(Jobs.create(store,uncertain,"create-q"));assert(Jobs.applyWork(store,"trench-q","excavate",1,"dig-q","machine.fixture",{}))
assert(Jobs.beginGeometryCommit(store,"trench-q","geometry-q"))
ok,result=Jobs.resolveGeometryCommit(store,"trench-q","geometry-q","uncertain",{reason="network"});assert(ok and result.job.status=="quarantined")
assert(not Jobs.applyWork(store,"trench-q","excavate",1,"later","machine.fixture",{}))

local cancelled={id="trench-c",type="trench",targetDepth=1,cells={{x=20,y=20,z=0}},workRequired=2,fillWorkRequired=2,soilVolume=2}
assert(Jobs.create(store,cancelled,"create-cancel"));assert(Jobs.cancel(store,"trench-c","cancel","changed plan"))
assert(Jobs.snapshot(store,"trench-c").status=="cancelled"and store.cellOwners["20:20:0"]==nil)
print("groundWorks authoritative earthwork-job ledger checks passed")
