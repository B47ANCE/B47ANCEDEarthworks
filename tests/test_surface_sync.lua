package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require "groundWorks/API"
local Sync=dofile(arg[1])
local server=true
isServer=function()return server end
isClient=function()return false end
local loaded={}
getCell=function()return{getGridSquare=function(_,x)return loaded[x]end}end
local function square(x)
    local s={modData={},floor={sprite={name="blends_natural_01_0"}},sent=0}
    function s:getX()return x end
    function s:getY()return 0 end
    function s:getZ()return 0 end
    function s:getModData()return self.modData end
    function s:transmitModdata()self.sent=self.sent+1 end
    loaded[x]=s;return s
end
local tick,load
assert(not Sync.install({}))
assert(Sync.install({OnTick={Add=function(fn)tick=fn end},LoadGridsquare={Add=function(fn)load=fn end}}))
assert(Sync.install({}))
local function batch()for _=1,Sync.TICK_INTERVAL do tick()end end
local s=square(1)
API.registerWearListener("fixture.throw",function()error("listener failure")end)
assert(API.reportTraffic(s,"foot",20,1))
assert(API.reportTraffic(s,"animal",2,1))
assert(Sync.getDiagnostics().pending==1 and s.sent==0,"traffic changes coalesce before transmission")
batch();assert(s.sent==1 and Sync.getDiagnostics().pending==0)
assert(API.integrateRecovery(s,25,1));batch();assert(s.sent==2,"recovery must also synchronize")
load(square(2));assert(Sync.getDiagnostics().pending==0,"pristine streamed squares need no sync")
load(s);batch();assert(s.sent==3,"persisted wear is scheduled on square load")
assert(API.reportTraffic(s,"foot",1,26));loaded[1]=nil
batch();assert(s.sent==3 and Sync.getDiagnostics().unloaded==1,"stale square objects cannot transmit")
loaded[1]=s;load(s)
local attempts=0
s.transmitModdata=function(self)attempts=attempts+1;if attempts<2 then error("network temporarily unavailable")end;self.sent=self.sent+1 end
batch();assert(Sync.getDiagnostics().pending==1)
batch();assert(s.sent==4 and Sync.getDiagnostics().pending==0,"transient sends retry within the queue")
s.transmitModdata=function()error("persistent failure")end
load(s);batch();batch();batch()
assert(Sync.getDiagnostics().pending==0,"permanent failure must not monopolize the queue")
for x=10,10+Sync.MAX_PENDING-1 do local target=square(x);assert(API.reportTraffic(target,"foot",1,1))end
assert(Sync.getDiagnostics().pending==Sync.MAX_PENDING)
assert(not Sync.enqueue(square(9999)) and Sync.getDiagnostics().dropped==1)
batch();assert(Sync.getDiagnostics().pending==Sync.MAX_PENDING-Sync.BATCH_SIZE)
for _=1,Sync.MAX_PENDING/Sync.BATCH_SIZE-1 do batch()end
assert(Sync.getDiagnostics().pending==0,"ring queue must drain its full bound")
local nextSquare=square(10000);assert(API.reportTraffic(nextSquare,"foot",1,1));batch()
assert(nextSquare.sent==1,"queue wraps and remains reusable")
server=false
assert(not Sync.enqueue(nextSquare));assert(API.reportTraffic(nextSquare,"foot",1,2));batch()
assert(nextSquare.sent==1,"single player never makes server replication calls")
local status=Sync.getDiagnostics();status.sent=-1;assert(Sync.getDiagnostics().sent>0)
print("groundWorks bounded coalesced surface synchronization checks passed")
