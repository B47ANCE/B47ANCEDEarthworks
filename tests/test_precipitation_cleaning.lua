package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/PrecipitationCleaning"]=nil
_G.groundWorks=nil
local API=require "groundWorks/API"
local Cleaning=require "groundWorks/PrecipitationCleaning"

local props={values={grassFloor="true"}}
function props:has(key) return self.values[key]~=nil end
function props:get(key) return self.values[key] end
local sprite={name="blends_natural_01_8",properties=props}
function sprite:getName() return self.name end
function sprite:getProperties() return self.properties end
local floor={sprite=sprite}
function floor:getSprite() return self.sprite end
local square={floor=floor,modData={},x=10,y=20,z=0}
function square:getFloor() return self.floor end
function square:getModData() return self.modData end
function square:getX() return self.x end
function square:getY() return self.y end
function square:getZ() return self.z end
function square:isOutside()return true end

assert(Cleaning.available()==false,"consumer must start unavailable")
assert(not Cleaning.exposureFor(square),"exposure read must fail while unavailable")

assert(API.reportTraffic(square,"foot",60,100,0))
local wearAfterTraffic=API.getWearState(square).wear
assert(wearAfterTraffic>0)
local ok,state=API.applySurfaceCleaning(square,200,30)
assert(ok and state.wear==wearAfterTraffic-30,"surface cleaning must reduce wear by a bounded amount")
assert(API.applySurfaceCleaning(square,50,0))
assert(API.getWearState(square).wear==wearAfterTraffic-30,"zero cleaning must not mutate wear")
for _,age in ipairs({0/0,math.huge,-math.huge,-1})do
    assert(API.applySurfaceCleaning(square,age,10)==false,"invalid age must be rejected")
end
assert(API.getWearState(square).wear==wearAfterTraffic-30,"invalid age must not mutate wear")
local overshoot,overshootState=API.applySurfaceCleaning(square,300,1000)
assert(overshoot and overshootState.wear==0,"cleaning amount must clamp to the wear floor")

local exposureState={}
local fakeExposure={registered=nil}
function fakeExposure.inspect(targetId)
    if not exposureState[targetId] then return nil,"target exposure unavailable" end
    local v=exposureState[targetId]
    return{rainExposure=v.rain or 0,snowExposure=v.snow or 0,sheltered=v.sheltered==true}
end
function fakeExposure.registerProvider(definition) fakeExposure.registered=definition end

Cleaning.attach(fakeExposure)
assert(Cleaning.available()==true,"attached consumer must be available")
assert(Cleaning.surfaceTargetId(square)=="groundWorks.surface.10.20.0","stable surface identity required")
assert(Cleaning.registerSurfaceProvider()==true,"provider registration must succeed")
assert(type(fakeExposure.registered)=="table" and fakeExposure.registered.id=="groundWorks.surface.v1","provider must register with the groundWorks id")
assert(fakeExposure.registered.matches(square)==true,"provider must match groundWorks surfaces")
local described=fakeExposure.registered.describe(square,{sheltered=true})
assert(described.targetId=="groundWorks.surface.10.20.0" and described.regionId=="groundWorks"
    and described.loaded==true and described.sheltered==true,"provider description must be bounded and stable")
assert(Cleaning.registerSurfaceProvider()==true,"provider registration must be idempotent")

exposureState["groundWorks.surface.10.20.0"]={rain=5,snow=2,sheltered=false}
local ev=assert(Cleaning.exposureFor(square))
assert(ev.rain==5 and ev.snow==2 and ev.sheltered==false,"exposure read must be bounded")

API.applySurfaceCleaning(square,400,0)
API.reportTraffic(square,"foot",30,400,0)
local beforeRain=API.getWearState(square).wear
local cleanOk,cleanState=Cleaning.applyCleaning(square,500,{rainRate=1,snowRate=0,maxCleaning=20})
assert(cleanOk and cleanState.wear==beforeRain,'First observation must establish a baseline.')
exposureState['groundWorks.surface.10.20.0'].rain=10
cleanOk,cleanState=Cleaning.applyCleaning(square,501,{rainRate=1,snowRate=0,maxCleaning=20})
assert(cleanOk and cleanState.wear==beforeRain-5,"rain exposure must clean by the configured rate")
assert(Cleaning.applyCleaning(square,501))
assert(API.getWearState(square).wear==beforeRain-5,'Repeated exposure must not clean twice.')

exposureState["groundWorks.surface.10.20.0"].sheltered=true
local beforeSheltered=API.getWearState(square).wear
local shelteredOk,shelteredState=Cleaning.applyCleaning(square,500)
assert(shelteredOk and shelteredState.wear==beforeSheltered,"sheltered surfaces must not be cleaned")

exposureState["groundWorks.surface.10.20.0"].sheltered=false
exposureState["groundWorks.surface.10.20.0"].rain=1000
local currentWear=API.getWearState(square).wear
local flooredOk,flooredState=Cleaning.applyCleaning(square,600,{rainRate=1,maxCleaning=20,minimumWear=currentWear-3})
assert(flooredOk and flooredState.wear==currentWear-3,"minimumWear floor must cap cleaning")

Cleaning.attach(nil)
assert(Cleaning.available()==false,"detach must restore unavailable state")
print("groundWorks precipitation-cleaning consumer checks passed")

-- API audit regression, host fixture only.

local Cleaning=require "groundWorks/PrecipitationCleaning"
local provider
assert(Cleaning.attach({inspect=function()end,registerProvider=function(p)provider=p end}))
assert(Cleaning.registerSurfaceProvider())
local sq={roof=true}
function sq:getX()return 1 end
function sq:getY()return 2 end
function sq:getZ()return 0 end
function sq:getRoom()return nil end
function sq:isOutside()return true end
function sq:haveRoofFull()return self.roof end
assert(provider.describe(sq,{}).sheltered==true,"roofed outdoor square was exposed to precipitation")
sq.roof=false
assert(provider.describe(sq,{}).sheltered==false,"open outdoor square must remain exposed")
assert(provider.describe(sq,{sheltered=true}).sheltered==true,"explicit owner shelter fact must remain authoritative")

Cleaning.attach(nil)
