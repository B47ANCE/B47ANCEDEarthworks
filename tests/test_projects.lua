package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API";local Projects=dofile(arg[1])
local props={has=function(_,k)return k=="grassFloor"end,get=function()return"true"end}
local sprite={getName=function()return"blends_natural_01_8"end,getProperties=function()return props end}
local floor={getSprite=function()return sprite end};local squareData={}
local square={getFloor=function()return floor end,getModData=function()return squareData end,transmitModdata=function(self)self.sent=(self.sent or 0)+1 end}
local ok,result=Projects.begin(square,"groundWorks.constructedPath","begin-1",{workRequired=10,requirements={Gravel=3},worldAgeHours=4})
assert(ok and not result.duplicate and result.state.status=="active")
assert(Projects.begin(square,"groundWorks.constructedPath","begin-1",{workRequired=10}))
assert(not Projects.begin(square,"groundWorks.trench","begin-2",{workRequired=5}))
ok,result=Projects.contribute(square,"Gravel",5,"material-1");assert(ok and result.accepted==3 and result.excess==2)
assert(Projects.contribute(square,"Gravel",5,"material-1"))
ok,result=Projects.advance(square,4,"work-1","worker-a");assert(ok and not result.completed and result.state.workCompleted==4)
ok,result=Projects.advance(square,20,"work-2","worker-a");assert(ok and result.completed and result.accepted==6)
local snapshot=assert(Projects.snapshot(square));assert(snapshot.status=="completed"and snapshot.result.projectType=="groundWorks.constructedPath")
assert(squareData[API.STATE_KEY].stage=="CONSTRUCTED"and squareData[API.STATE_KEY].projectResult.domain=="surface")
local secondData={};local second={getFloor=function()return floor end,getModData=function()return secondData end}
assert(Projects.begin(second,"groundWorks.trench","trench-1",{workRequired=5}))
assert(Projects.cancel(second,"cancel-1","changed plan"));assert(Projects.snapshot(second).status=="cancelled")
local transactionData={};local transactionSquare={getFloor=function()return floor end,getModData=function()return transactionData end,
    transmitModdata=function()end}
assert(Projects.begin(transactionSquare,"groundWorks.constructedRoad","road-1",{workRequired=5,requirements={Aggregate=4}}))
local consumed=0
ok,result=Projects.contributeTransaction(transactionSquare,"Aggregate",6,"material-tx-1",{id="fixture.inventory",
    consume=function(amount,context)consumed=consumed+amount;assert(context.worker=="a");return true,"items:1,2"end},{worker="a"})
assert(ok and result.accepted==4 and result.excess==2 and consumed==4 and result.receipt=="items:1,2")
assert(Projects.inspectMaterialRecovery(transactionSquare).status=="clear")
assert(Projects.contributeTransaction(transactionSquare,"Aggregate",6,"material-tx-1",{id="fixture.inventory",consume=function()error("replay consumed")end}))
local rejectedData={};local rejected={getFloor=function()return floor end,getModData=function()return rejectedData end}
assert(Projects.begin(rejected,"groundWorks.constructedPath","reject-1",{workRequired=1,requirements={Stone=1}}))
assert(not Projects.contributeTransaction(rejected,"Stone",1,"reject-tx",{id="fixture.reject",consume=function()return false,"missing"end}))
assert(Projects.inspectMaterialRecovery(rejected).status=="clear")
local uncertainData={};local uncertain={getFloor=function()return floor end,getModData=function()return uncertainData end}
assert(Projects.begin(uncertain,"groundWorks.constructedPath","uncertain-1",{workRequired=1,requirements={Stone=1}}))
assert(not Projects.contributeTransaction(uncertain,"Stone",1,"uncertain-tx",{id="fixture.throw",consume=function()error("unknown")end}))
assert(Projects.inspectMaterialRecovery(uncertain).status=="inspection_required")
assert(not Projects.contribute(uncertain,"Stone",1,"later")and not Projects.advance(uncertain,1,"work","worker")
    and not Projects.cancel(uncertain,"cancel","unsafe"),"uncertain material state must quarantine project mutation")
local deferredData={};local deferred={getFloor=function()return floor end,getModData=function()return deferredData end,transmitModdata=function()end}
assert(Projects.begin(deferred,"groundWorks.constructedPath","defer-1",{workRequired=1,deferCommit=true}))
ok,result=Projects.advance(deferred,1,"defer-work","worker");assert(ok and result.ready and not result.completed and result.state.status=="ready")
local commits=0
ok,result=Projects.commitReady(deferred,"defer-commit",{id="fixture.world",commit=function()commits=commits+1;return true,{committed=true,after="road"}end},{})
assert(ok and result.state.status=="completed"and commits==1 and Projects.inspectWorldRecovery(deferred).status=="clear")
assert(Projects.commitReady(deferred,"defer-commit",{id="fixture.world",commit=function()error("duplicate")end},{})and commits==1)
local unsafeData={};local unsafe={getFloor=function()return floor end,getModData=function()return unsafeData end,transmitModdata=function()end}
assert(Projects.begin(unsafe,"groundWorks.constructedRoad","unsafe-1",{workRequired=1,deferCommit=true}))
assert(Projects.advance(unsafe,1,"unsafe-work","worker"))
assert(not Projects.commitReady(unsafe,"unsafe-commit",{id="fixture.unsafe",commit=function()return false,{committed=true,replicationUncertain=true}end},{}))
assert(Projects.inspectWorldRecovery(unsafe).requiresInspection and not Projects.cancel(unsafe,"unsafe-cancel","no"))
isClient=function()return true end;isServer=function()return false end
local third={getFloor=function()return floor end,getModData=function()return{}end};assert(not Projects.begin(third,"groundWorks.trench","client",{workRequired=1}))
print("groundWorks persistent project lifecycle checks passed")
