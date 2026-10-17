from pathlib import Path
from lupa import LuaRuntime
root=Path(__file__).resolve().parents[1]
lua=LuaRuntime()
base=root/'src/B47ANCEDEarthworks/42/media/lua'
lua.globals().package.path=';'.join((base/scope/'?.lua').as_posix() for scope in ('shared','server','client'))
source=(root/'docs/imported-0.13.1/contracts.lua').read_text(encoding='utf-8-sig').splitlines()
lua.execute('\n'.join(source[2:])+r"""
getActivatedMods=function()return list({})end
local target=square(150,150,0);floor(target)
player.x=150;player.y=151;player.z=0
shovel:setCondition(100);player.primary=shovel
local sprite=getSprite('blends_natural_01_0')
function target.floor:getSprite()return sprite end
function target.floor:setSprite(value)sprite=value end
function target:RecalcAllWithNeighbours()end
local Work=require 'groundWorks/RouteWork'
local bag=item('Base.Gravelbag',1);bag.getUseDelta=function()return .25 end;inventory:AddItem(bag)
local function action(op,id,route)
    return Server.perform(player,{x=150,y=150,z=0,op=op,operationId=id,volumeType=route})
end
assert(action('routeStart','route.start','groundWorks.gravelPath'))
assert(not Work.plan(player,target,'routeStart','groundWorks.concreteRoad'))
assert(action('routeSupply','route.supply.1'))
local uses=bag.uses
assert(action('routeSupply','route.supply.1')and bag.uses==uses,'replay must not consume again')
assert(action('routeSupply','route.supply.2'))
local route=API.ConstructedRoutes.snapshot(target)
assert(route.project.materials['Base.Gravelbag']==2)
for i=1,10 do assert(action('routeWork','route.work.'..i))end
assert(API.ConstructedRoutes.snapshot(target).project.status=='completed')
assert(sprite:getName()=='blends_street_01_55')
assert(not Work.plan(player,target,'routeWork'))
client=true
assert(not require('groundWorks/RouteWorkServer').perform(player,target,{op='routeWork',operationId='client'}))
client=false
API.ConstructedRoutes.register{id='test.machineOnly',projectType='groundWorks.constructedRoad',floorSprite='floors_construction_01_0',workRequired=10,requirements={},requiresMachine=true}
assert(not Work.plan(player,target,'routeStart','test.machineOnly'),'manual placement must reject machine-only designs')
local other=square(152,150,0);floor(other)
assert(not API.ConstructedRoutes.begin(other,'test.machineOnly','machine-only.manual'))
assert(API.ConstructedRoutes.begin(other,'test.machineOnly','machine-only.start',{providerKind='machine'}))
player.x=152;player.y=151
assert(not Work.plan(player,other,'routeWork'),'manual work must reject an existing machine-only route')
print('Hand route completion, material replay and machine-only design exclusions passed')
""")
