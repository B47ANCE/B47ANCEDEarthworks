package.loaded["groundWorks/API"]=nil;groundWorks=nil
require"groundWorks/API";local Providers=dofile(arg[1]);Providers._resetForTests()
local seen
local registered=Providers.register{id="groundWorks.manual.shovel",kind="manual",capabilities={excavate=true},maxWorkPerOperation=10,
    validate=function(capability,amount,context)seen=context;context.actor="changed";return capability=="excavate"and amount<=5,"too much"end}
assert(registered.capabilities.excavate and not registered.capabilities.fill)
registered.capabilities.excavate=false;assert(Providers.get("groundWorks.manual.shovel").capabilities.excavate)
local context={actor="survivor",nested={value=1}}
local grant=assert(Providers.authorize("groundWorks.manual.shovel","excavate",5,context))
assert(grant.providerKind=="manual"and grant.amount==5 and context.actor=="survivor"and seen~=context)
assert(not Providers.authorize("groundWorks.manual.shovel","fill",1,{}))
assert(not Providers.authorize("groundWorks.manual.shovel","excavate",11,{}))
assert(not Providers.authorize("groundWorks.manual.shovel","excavate",6,{}))
Providers.register{id="groundWorks.machine.fixture",kind="machine",requiredModId="fixture.localVehicles",capabilities={excavate=true,fill=true,transferSoil=true},
    maxWorkPerOperation=100,maxSoilPerOperation=25}
assert(not Providers.isAvailable("groundWorks.machine.fixture"))
assert(not Providers.authorize("groundWorks.machine.fixture","excavate",100,{}))
assert(#Providers.listAvailable()==1 and Providers.listAvailable()[1].kind=="manual")
local active={}
getActivatedMods=function()return{size=function()return#active end,get=function(_,index)return active[index+1]end}end
assert(not Providers.isAvailable("groundWorks.machine.fixture"))
active={"fixture.localVehicles.extra"}
assert(not Providers.isAvailable("groundWorks.machine.fixture"),"dependency IDs must match exactly")
active={"fixture.localVehicles"}
assert(Providers.isAvailable("groundWorks.machine.fixture") and #Providers.listAvailable()==2)
assert(Providers.authorize("groundWorks.machine.fixture","excavate",100,{}))
assert(Providers.authorize("groundWorks.machine.fixture","fill",100,{}))
assert(Providers.authorize("groundWorks.machine.fixture","transferSoil",25,{}))
assert(not Providers.authorize("groundWorks.machine.fixture","transferSoil",26,{}))
active={}
assert(not Providers.authorize("groundWorks.machine.fixture","fill",1,{}),"removing the optional mod must disable new machine work")
assert(Providers.authorize("groundWorks.manual.shovel","excavate",1,{}),"manual work must remain independent")
getActivatedMods=function()error("lookup failed")end
assert(not Providers.isAvailable("groundWorks.machine.fixture"))
assert(Providers.isAvailable("groundWorks.manual.shovel"))
assert(not pcall(Providers.register,{id="missing.dependency",kind="machine",capabilities={excavate=true},maxWorkPerOperation=1}))
assert(Providers.get("missing.dependency")==nil)
local throwing=Providers.register{id="groundWorks.integration.throw",kind="integration",capabilities={excavate=true},maxWorkPerOperation=1,
    validate=function()error("provider failure")end}
assert(throwing.id and not Providers.authorize(throwing.id,"excavate",1,{}))
local ok=pcall(Providers.register,{id="groundWorks.manual.shovel",kind="manual",capabilities={excavate=true},maxWorkPerOperation=1});assert(not ok)
print("groundWorks protected earthwork-provider checks passed")
