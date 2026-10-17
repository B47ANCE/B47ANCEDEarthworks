isClient=function()return false end;isServer=function()return false end
local store={cellOwners={['1:2:0']='job'},jobs={job={status='excavated',looseSoil=2,soilVolume=2}}}
package.loaded['groundWorks/Load']={EarthworkPersistence={getStore=function()return store end},HandTools={squareReachable=function()return true end,findTool=function()return{}end}}
local function container()
    local c={items={},room=true}
    function c:contains(item)for _,v in ipairs(self.items)do if v==item then return true end end;return false end
    function c:AddItem(item)if self.fail then error('insertion failed')end;self.items[#self.items+1]=item;item.container=self;return item end
    function c:Remove(item)for i,v in ipairs(self.items)do if v==item then table.remove(self.items,i);item.container=nil;return end end end
    function c:getFirstTypeRecurse(kind)for _,v in ipairs(self.items)do if v.kind==kind then return v end end end
    function c:hasRoomFor()return self.room end
    return c
end
instanceItem=function(kind)
    local item={kind=kind,data={},uses=1}
    function item:getContainer()return self.container end
    function item:getModData()return self.data end
    function item:getUseDelta()return .25 end
    function item:setUsedDelta(value)self.uses=value end
    function item:getCurrentUsesFloat()return self.uses end
    return item
end
local inventory=container()
local actor={isDead=function()return false end,getVehicle=function()return nil end,getInventory=function()return inventory end,
    getUsername=function()return 'worker'end,removeFromHands=function()end}
local square={getX=function()return 1 end,getY=function()return 2 end,getZ=function()return 0 end}
local Exchange=require 'groundWorks/SpoilExchange'
local bag=instanceItem('Base.EmptySandbag');inventory:AddItem(bag)
assert(Exchange.perform(actor,square,'bag','bag.1'));assert(store.jobs.job.looseSoil==1)
local dirt=inventory.items[1];assert(dirt.kind=='Base.Dirtbag'and dirt.uses==.25)
assert(Exchange.perform(actor,square,'bag','bag.1'));assert(store.jobs.job.looseSoil==1 and #inventory.items==1)
assert(not Exchange.perform(actor,square,'return','bag.1'),'Conflicting replay must fail.')
assert(Exchange.perform(actor,square,'return','return.1'));assert(store.jobs.job.looseSoil==2)
assert(inventory.items[1].kind=='Base.EmptySandbag')
inventory.room=false;assert(not Exchange.perform(actor,square,'bag','full'));assert(store.jobs.job.looseSoil==2)
inventory.room=true
-- Failed insertion: restoring to a healthy original container is verified.
local source=container();local sack=instanceItem('Base.EmptySandbag');source:AddItem(sack)
inventory.getFirstTypeRecurse=function()return sack end;inventory.fail=true
assert(not Exchange.perform(actor,square,'bag','failure'))
assert(source:contains(sack)and store.jobs.job.looseSoil==2 and store.spoilOperations.failure.status=='rolled_back')
inventory.fail=false;inventory.getFirstTypeRecurse=nil
-- Use a fresh container containing a partly full dirt sack.
inventory=container();dirt=instanceItem('Base.Dirtbag');dirt.uses=.75;inventory:AddItem(dirt)
store.jobs.job.looseSoil=0
assert(Exchange.perform(actor,square,'return','partial'));assert(dirt.uses==.5 and store.jobs.job.looseSoil==1)
isClient=function()return true end
assert(not Exchange.perform(actor,square,'return','client'));assert(dirt.uses==.5)
print('Spoil conservation, replay identity, full containers, rollback, partial sacks and authority passed')
