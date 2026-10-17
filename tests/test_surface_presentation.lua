package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/SurfacePresentation"]=nil
_G.groundWorks=nil
local API=require "groundWorks/API"
local Presentation=require "groundWorks/SurfacePresentation"
Presentation._resetForTests()

local props={values={grassFloor="true"}}
function props:has(key) return self.values[key]~=nil end
function props:get(key) return self.values[key] end
local sprite={name="blends_natural_01_8",properties=props}
function sprite:getName() return self.name end
function sprite:getProperties() return self.properties end
local floor={sprite=sprite}
function floor:getSprite() return self.sprite end
local square={floor=floor,modData={}}
function square:getFloor() return self.floor end
function square:getModData() return self.modData end

local applied=0;local removed=0;local lastStage=nil
Presentation.registerLayerProvider{
    id="test.layer.v1",
    layerFor=function(stage)
        if stage=="WORN"then return "overlay"end
        if stage=="BARE"or stage=="ESTABLISHED_PATH"then return "base"end
        return "none"
    end,
    apply=function(sq,stage) applied=applied+1;lastStage=stage;return true end,
    remove=function(sq) removed=removed+1;return true end,
}
assert(Presentation.providerCount()==1)

local ok,view=Presentation.present(square)
assert(ok and view.presentedStage=="UNTOUCHED" and view.layer=="none","initial presentation must be inert")

API.reportTraffic(square,"foot",16,100,0)
assert(API.getWearState(square).stage=="WORN")
local ok2,view2=Presentation.present(square,200)
assert(ok2 and view2.layer=="overlay" and view2.presentedStage=="WORN" and applied==1,"stage transition must apply the overlay layer")
local ok3,view3=Presentation.present(square,200)
assert(ok3 and applied==1,"unchanged stage must not re-apply presentation")

API.reportTraffic(square,"foot",30,200,0)
assert(API.getWearState(square).stage=="BARE")
local ok4,view4=Presentation.present(square,300)
assert(ok4 and view4.layer=="base" and removed==1 and applied==2,"layer change must remove the old layer then apply the new one")

local hiddenOk,hiddenView=Presentation.hide(square)
assert(hiddenOk and hiddenView.hidden==true and removed==2,"hide must remove the visual and mark hidden")
local hiddenAgain,hiddenAgainView=Presentation.hide(square)
assert(hiddenAgain and hiddenAgainView.hidden and removed==2,"hide must be idempotent")
local unhideOk,unhideView=Presentation.unhide(square)
assert(unhideOk and unhideView.hidden==false and applied==3,"unhide must re-present the current stage")

local cleanupOk=Presentation.cleanup(square)
assert(cleanupOk and removed==3,"cleanup must remove the visual and clear state")
assert(square.modData[Presentation.STATE_KEY]==nil,"cleanup must clear presentation state")
local inspectAfterCleanup=Presentation.inspect(square)
assert(inspectAfterCleanup.presentedStage=="UNTOUCHED" and inspectAfterCleanup.layer=="none","cleanup must reset inspection to defaults")

-- fail-closed apply
local failProvider
Presentation.registerLayerProvider{
    id="test.fail.v1",priority=100,
    layerFor=function()return "base"end,
    apply=function() return false end,
    remove=function()return true end,
}
API.reportTraffic(square,"foot",100,300,0)
assert(API.getWearState(square).stage=="ESTABLISHED_PATH")
local failOk,failReason=Presentation.present(square,400)
assert(failOk==false and failReason=="native presentation apply was not verified","rejected apply must fail closed")

-- throwing apply
Presentation.registerLayerProvider{
    id="test.throw.v1",priority=200,
    layerFor=function()return "overlay"end,
    apply=function() error("boom") end,
    remove=function()return true end,
}
local throwOk,throwReason=Presentation.present(square,500)
assert(throwOk==false and throwReason=="native presentation apply was not verified","throwing apply must be contained")

-- malformed presentation state must quarantine
square.modData[Presentation.STATE_KEY]={schemaVersion=99,layer="overlay"}
assert(Presentation.present(square)==false)

-- duplicate provider rejected
local dupOk=pcall(function()
    Presentation.registerLayerProvider{id="test.layer.v1",layerFor=function()return"none"end}
end)
assert(dupOk==false,"duplicate provider id must be rejected")

-- non-authority
isClient=function() return true end
isServer=function() return false end
square.modData[Presentation.STATE_KEY]=nil
assert(Presentation.present(square)==false,"clients must not present surfaces")
isClient=nil;isServer=nil

Presentation._resetForTests()
print("groundWorks surface-presentation lifecycle checks passed")
