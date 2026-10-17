package.loaded["groundWorks/API"]=nil
_G.groundWorks=nil
local API=require "groundWorks/API"
local projectDefinition={id="test.protectedProject",domain="surface",validate=function()return true end}
local projectResult=API.registerProjectType(projectDefinition)
projectDefinition.validate=function()return false end;projectResult.validate=function()return false end
local projectOK,projectView=API.validateProject("test.protectedProject",{square={}})
assert(projectOK and projectView.domain=="surface","project registrations must snapshot callbacks")
projectView.domain="corrupted"
assert(API.getProjectType("test.protectedProject").domain=="surface","project lookups must be detached")
local cachedSurface={material="test",natural=true,water=false,wearResistance=1,trafficWear=true}
local surfaceDefinition={id="test.protectedSurface",priority=100,matches=function(s)return s.testSurface end,
    inspect=function()return cachedSurface end}
local surfaceResult=API.registerSurfaceProvider(surfaceDefinition)
surfaceDefinition.matches=function()return false end;surfaceResult.matches=function()return false end
local protectedSurface=assert(API.inspectSurface({testSurface=true}))
assert(protectedSurface.providerId=="test.protectedSurface"and cachedSurface.providerId==nil,
    "surface inspection must not decorate provider-owned state")
protectedSurface.material="corrupted"
assert(API.inspectSurface({testSurface=true}).material=="test","surface views must be detached")
local props={values={grassFloor="true"}}
function props:has(key) return self.values[key]~=nil end
function props:get(key) return self.values[key] end
local sprite={name="blends_natural_01_8",properties=props}
function sprite:getName() return self.name end
function sprite:getProperties() return self.properties end
local floor={sprite=sprite}
function floor:getSprite() return self.sprite end
local square={floor=floor,modData={},getZ=function()return 0 end}
function square:getFloor() return self.floor end
function square:getModData() return self.modData end
local surface=assert(API.inspectSurface(square))
assert(surface.material=="natural" and surface.natural==true)
assert(API.validateProject("groundWorks.trench",{square=square})==true)
assert(API.validateProject("groundWorks.basement",{square=square})==true)
assert(API.validateProject("missing",{square=square})==false)
local ok,state=API.reportTraffic(square,"foot",20,100)
assert(ok and state.stage=="WORN" and state.wear>20)
square.modData[API.STATE_KEY].projectResult={domain="surface",nested={complete=true}}
state.wear=0;state.traffic.foot=0
local protectedWear=API.getWearState(square)
assert(protectedWear.wear>20 and protectedWear.traffic.foot==20,
    "traffic results must not expose authoritative square ModData")
assert(protectedWear.projectResult.domain=="surface"and protectedWear.projectResult.nested.complete,
    "detached wear views must preserve established project-result metadata")
protectedWear.projectResult.nested.complete=false
assert(API.getWearState(square).projectResult.nested.complete,
    "nested wear metadata must also be detached from authoritative square ModData")
protectedWear.wear=0;protectedWear.traffic.foot=0
assert(API.getWearState(square).wear>20 and API.getWearState(square).traffic.foot==20,
    "wear-state lookups must return detached views")
local malformedData={[API.STATE_KEY]={schemaVersion=99,traffic={foot=10},wear=50}}
local malformedSquare={floor=floor,modData=malformedData}
function malformedSquare:getFloor()return self.floor end;function malformedSquare:getModData()return self.modData end
local malformedView,malformedReason=API.getWearState(malformedSquare)
assert(malformedView==nil and malformedReason=="unsupported or malformed surface state")
local malformedWrite,malformedWriteReason=API.reportTraffic(malformedSquare,"foot",1,100)
assert(malformedWrite==false and malformedWriteReason=="unsupported or malformed surface state"
    and malformedData[API.STATE_KEY].schemaVersion==99 and malformedData[API.STATE_KEY].wear==50,
    "unknown persisted surface state must be quarantined rather than overwritten")
local malformedRecovery,malformedRecoveryReason=API.integrateRecovery(malformedSquare,101,1)
assert(malformedRecovery==false and malformedRecoveryReason=="unsupported or malformed surface state"
    and malformedData[API.STATE_KEY].wear==50,"recovery must also quarantine unknown persisted state")
ok,state=API.reportTraffic(square,"vehicle",10,101)
assert(ok and state.stage=="ESTABLISHED_PATH")
ok,state=API.integrateRecovery(square,2401,1)
assert(ok and state.wear==0 and state.stage=="UNTOUCHED")
local recoverySquare={floor=floor,modData={}}
function recoverySquare:getFloor() return self.floor end
function recoverySquare:getModData() return self.modData end
assert(API.reportTraffic(recoverySquare,"foot",10,0,1))
local beforeRecovery=API.getWearState(recoverySquare).wear
assert(API.reportTraffic(recoverySquare,"foot",1,24,1))
local afterRecovery=API.getWearState(recoverySquare).wear
assert(math.abs(afterRecovery-(beforeRecovery-1+(1/.75)))<0.000001,
    "traffic must compose elapsed recovery before adding new wear")
assert(API.integrateRecovery(recoverySquare,48,1))
local once=API.getWearState(recoverySquare).wear
assert(API.integrateRecovery(recoverySquare,24,1))
assert(API.integrateRecovery(recoverySquare,48,1))
assert(API.getWearState(recoverySquare).wear==once,'stale clock must not replay elapsed recovery')
assert(API.reportTraffic(recoverySquare,'foot',0,24,1))
assert(API.integrateRecovery(recoverySquare,48,1))
assert(API.getWearState(recoverySquare).wear==once,'backdated traffic must not rewind recovery time')
for _,age in ipairs({0/0,math.huge,-math.huge,-1})do
    assert(not API.reportTraffic(recoverySquare,'foot',1,age))
    assert(not API.integrateRecovery(recoverySquare,age,1))
end
assert(API.getWearState(recoverySquare).wear==once,'invalid time must not change wear')
isClient=function() return true end
isServer=function() return false end
assert(API.reportTraffic(square,"foot",1,2402)==false)
print("groundWorks surface/traffic/recovery checks passed")
