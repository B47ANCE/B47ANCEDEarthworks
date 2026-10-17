local root=tostring(arg[0]):gsub("\\","/"):match("^(.*)/review/tests/")or"."
package.path=root.."/groundWorks/42/media/lua/shared/?.lua;"..root.."/groundWorks/42/media/lua/server/?.lua;"..root.."/groundWorks/42/media/lua/client/?.lua"
local client,server=false,false
function isClient()return client end
function isServer()return server end
function getText(key,...)return key end
function getGameTime()return{getWorldAgeHours=function()return 24 end}end
function getTimestampMs()return 1788636947708 end
function sendItemStats()end
function sendServerCommand()end
function sendAddItemToContainer()end
function sendRemoveItemFromContainer()end
function ZombRand()return 1 end
Fluid={Water="water",Petrol="petrol"}
function getSprite(name)return{getName=function()return name end}end
local function list(values)
    local l=values or{}
    function l:size()return#self end
    function l:isEmpty()return#self==0 end
    function l:get(i)return self[i+1]end
    return l
end
function getActivatedMods()return list({"CATConstruction"})end
local API=require "groundWorks/Load"
local Cavity,Jobs,Persistence=API.Cavity,API.EarthworkJobs,API.EarthworkPersistence
local grid={}
local function key(x,y,z)return x..":"..y..":"..z end
local function square(x,y,z,floor)
    local s={x=x,y=y,z=z,data={},floor=floor,objects=list(),moving=list(),world=list(),bodies=list()}
    function s:getX()return self.x end
    function s:getY()return self.y end
    function s:getZ()return self.z end
    function s:getModData()return self.data end
    function s:transmitModdata()end
    function s:getFloor()return self.floor end
    function s:getRoom()return nil end
    function s:getBuilding()return nil end
    function s:isFree()return true end
    function s:getObjects()return self.objects end
    function s:getMovingObjects()return self.moving end
    function s:getStaticMovingObjects()return self.bodies end
    function s:getWorldObjects()return self.world end
    grid[key(x,y,z)]=s;return s
end
local function floor(s)
    local f={data={}}
    function f:getModData()return self.data end
    function f:getSquare()return s end
    s.floor=f;return f
end
local cell={getGridSquare=function(_,x,y,z)return grid[key(x,y,z)]end}
function getCell()return cell end
API.inspectSurface=function(s)return{natural=s.z==0,water=false,material="soil"}end
local adapter={
    validateSprite=function()return true end,isValidSquare=function(_,_,z)return z>=-8 end,
    getSquare=function(x,y,z)return grid[key(x,y,z)]end,
    isEmptySquare=function(s)return not s.floor and#s.objects==0 end,
    createSquare=function(x,y,z)return square(x,y,z)end,
    connectSquare=function()return true end,addFloor=function(s)return floor(s)end,
    tagObject=function(o,id)o.data[Cavity.ROOT_KEY]={operationId=id};return true end,
    recalculate=function()return true end,transmitObject=function()return true end,verify=function()return true end,
    tagOpening=function(s,id)s.data[Cavity.OPENING_KEY]={schemaVersion=1,operationId=id};s.floor=nil;return true end,
    verifyOpening=function(s)return not s.floor end,
    untagOpening=function(s)s.data[Cavity.OPENING_KEY]=nil;floor(s);return true end,
    openToSky=function(s)s.floor=nil;return true end,
    restoreFloor=function(s)floor(s);return true end,
    removeObject=function(s)s.floor=nil;return true end,
    setFloorSprite=function()return true end,
}
require('groundWorks/CavityEngine').adapter=function()return adapter end
local Hand=API.HandTools
local function container()
    local c={items=list()}
    function c:getItems()return self.items end
    function c:contains(item)for _,i in ipairs(self.items)do if item==i then return true end end;return false end
    function c:AddItem(item)table.insert(self.items,item);item.container=self;return item end
    function c:Remove(item)for n,i in ipairs(self.items)do if i==item then table.remove(self.items,n);item.container=nil;break end end end
    function c:getFirstTypeRecurse()return nil end
    return c
end
local function item(full,uses,fluid)
    local i={full=full,condition=10,uses=uses or 1,fluid=fluid}
    function i:getFullType()return self.full end
    function i:getCondition()return self.condition end
    function i:setCondition(n)self.condition=n end
    function i:getCurrentUsesFloat()return self.uses end
    function i:getFluidContainer()return self.fluid end
    function i:getContainer()return self.container end
    function i:Use()self.uses=self.uses-0.25 end
    function i:hasTag()return false end
    return i
end
local inventory=container()
local shovel=inventory:AddItem(item('Base.Shovel'))
local player={x=11.5,y=10.5,z=0,primary=shovel}
function player:getX()return self.x end
function player:getY()return self.y end
function player:getZ()return self.z end
function player:getCurrentSquare()return grid[key(math.floor(self.x),math.floor(self.y),math.floor(self.z))]end
function player:getInventory()return inventory end
function player:getPrimaryHandItem()return self.primary end
function player:getSecondaryHandItem()end
function player:getUsername()return 'review' end
function player:getVehicle()return nil end
function player:isDead()return false end
function player:Say()end
function player:removeFromHands()end
local function fluid(kind,amount)
    local f={kind=kind,amount=amount}
    function f:getAmount()return self.amount end
    function f:isPureFluid(k)return self.kind==k end
    function f:removeFluid(n)self.amount=self.amount-n end
    return f
end
local count=0
local function test(name,fn)
    local ok,err=pcall(fn)
    assert(ok,name..": "..tostring(err))
    count=count+1;print('PASS '..name)
end
test('vanilla shovel is available without CAT',function()assert(Hand.inspectItem(shovel));assert(API.consumer().HandTools==Hand)end)
test('empty bottle is not water',function()assert(not Hand.inspectMedia(item('Base.WaterBottle',1,fluid('water',0))))end)
test('pure water quantity is bounded',function()local m=Hand.inspectMedia(item('Base.Bucket',1,fluid('water',0.4)));assert(m.media=='water'and m.amount==0.4)end)
test('petrol stays fuel',function()assert(Hand.inspectMedia(item('Base.PetrolCan',1,fluid('petrol',4))).media=='fuel')end)
test('other liquids and dry powder are rejected',function()assert(not Hand.inspectMedia(item('Base.Bottle',1,fluid('bleach',2))));assert(not Hand.inspectMedia(item('Base.ConcretePowder')))end)
test('empty concrete and dirt bags are rejected',function()assert(not Hand.inspectMedia(item('Base.BucketConcreteFull',0)));assert(not Hand.inspectMedia(item('Base.Dirtbag',0)))end)
square(11,10,0,true)
local surface=square(10,10,0,true)
test('different floor cannot excavate remotely',function()player.z=-2;assert(not Hand.squareReachable(player,surface));player.z=0 end)
test('basements accept an existing house ground floor',function()
    local original=API.inspectSurface
    API.inspectSurface=function()return{natural=false,water=false,material='constructed'}end
    assert(API.validateVolume('groundWorks.basement',{square=surface,actor=player}))
    assert(not API.validateVolume('groundWorks.trench',{square=surface,actor=player}))
    API.inspectSurface=original
end)
test('pre-existing underground rooms are protected',function()
    local other=square(20,20,0,true);square(20,20,-1,true)
    local ok=Cavity.execute(other,'existing-room',adapter,{volumeType='groundWorks.basement'})
    assert(not ok and other.floor and grid[key(20,20,-1)].floor)
end)
local store=Jobs.newStore();assert(Persistence.attachStore(store))
local Server=require 'groundWorks/HandToolsServer'
local function work(op,id,media)
    return Server.perform(player,{op=op,operationId=id,media=media,volumeType='groundWorks.basement',x=10,y=10,z=0})
end
test('first shovel action records progress',function()assert(work('excavate','dig1'));assert(Jobs.jobAtCell(store,10,10,0).workCompleted==10)end)
test('duplicate action does not add work',function()assert(work('excavate','dig1'));assert(Jobs.jobAtCell(store,10,10,0).workCompleted==10)end)
test('second shovel action opens real adapter geometry',function()assert(work('excavate','dig2'));assert(not surface.floor);assert(Cavity.inspect(surface).status=='created');assert(Jobs.jobAtCell(store,10,10,0).status=='excavated')end)
test('two more swings deepen to level two',function()assert(work('deepen','deep1'));assert(work('deepen','deep2'));assert(Cavity.inspect(surface).targetDepth==2);assert(not grid[key(10,10,-1)].floor);assert(grid[key(10,10,-2)].floor)end)
test('cover built by player survives shaft maintenance',function()floor(surface);assert(Cavity.ensureLiveShaft(surface,adapter));assert(surface.floor);surface.floor=nil end)
test('a living occupant blocks backfill',function()local bottom=grid[key(10,10,-2)];bottom.moving[1]=player;assert(not Hand.canFill(player,surface));bottom.moving[1]=nil end)
test('a missing landing blocks climb out',function()grid[key(11,10,0)].floor=nil;assert(not Cavity.climbLanding(grid[key(10,10,-2)],adapter));floor(grid[key(11,10,0)])end)
test('soil backfill closes and releases the cell',function()assert(work('fill','fill1'));assert(work('fill','fill2'));assert(surface.floor);assert(not Jobs.jobAtCell(store,10,10,0));assert(not grid[key(10,10,-2)].data[Cavity.ROOT_KEY])end)
test('same location can be dug again after backfill',function()assert(work('excavate','redig1'));assert(work('excavate','redig2'));assert(Cavity.inspect(surface).status=='created')end)
test('nested concrete bucket consumes one use',function()
    local bucket=item('Base.BucketConcreteFull');inventory:AddItem(bucket)
    local nested=container();nested:AddItem(bucket) -- discovery still retains the reference, consumption follows the real container
    assert(work('pour','concrete1','concrete'));assert(bucket.uses==0.75)
end)
test('replayed pour never consumes twice',function()local bucket=inventory.items[#inventory.items];assert(work('pour','concrete1','concrete'));assert(bucket.uses==0.75)end)
test('filled cavity rejects further material without consuming it',function()local bucket=inventory.items[#inventory.items];assert(not work('pour','concrete2','concrete'));assert(bucket.uses==0.75)end)
test('saved job store passes integrity validation',function()assert(API.EarthworkIntegrity.audit(store).valid);assert(Persistence.attachStore(store))end)
test('MP raw hand command cannot bypass timed action',function()server=true;assert(not Server.onClientCommand('groundWorks','handOperate',player,{op='excavate'}));server=false end)
test('client rejects authoritative job mutations',function()client=true;assert(not Jobs.beginBackfill(store,'anything','client1'));client=false end)
test('client receives job store snapshot',function()
    Events=setmetatable({},{__index=function(t,k)local v={Add=function()end};rawset(t,k,v);return v end})
    client=true;local sync=require 'groundWorks/EarthworkStoreClient';sync.receive(Persistence.STORE_KEY,store);assert(Persistence.getStore()==store);client=false
end)
print('CONTRACTS PASSED '..count)
