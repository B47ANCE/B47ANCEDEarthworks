isClient=function()return false end
getActivatedMods=function()return{contains=function()return true end}end
local API=require 'groundWorks/API'
local age=1
local weather={sample=function()return{worldAgeHours=age,precipitation=1,snowStrength=0}end}
package.loaded['weatherWorks/API']=weather
local exposure=require 'weatherWorks/PrecipitationExposure';assert(exposure.attachStore({}))
local props={has=function(_,k)return k=='grassFloor'end,get=function()return 'true'end}
local sprite={getName=function()return 'blends_natural_01_8'end,getProperties=function()return props end}
local square={data={},getX=function()return 1 end,getY=function()return 2 end,getZ=function()return 0 end,
    getFloor=function()return{getSprite=function()return sprite end}end,isOutside=function()return true end}
function square:getModData()return self.data end
local loaded=true
getCell=function()return{getGridSquare=function()return loaded and square end}end
assert(API.reportTraffic(square,'foot',40,1,0))
local before=API.getWearState(square).wear
local Rain=require 'groundWorks/RainCleaningServer'
Rain.track(square);Rain.step();assert(API.getWearState(square).wear==before)
age=2;Rain.step();assert(API.getWearState(square).wear==before-1)
Rain.step();assert(API.getWearState(square).wear==before-1)
loaded=false;age=3;Rain.step();loaded=true;age=20;Rain.step()
assert(API.getWearState(square).wear==before-1,'Unloaded exposure must not become retroactive cleaning.')
age=21;Rain.step();assert(API.getWearState(square).wear==before-2)
print('Automatic cleaning cadence, no replay, and unloaded baseline passed')
