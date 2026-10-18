local API=require 'groundWorks/Load'
local Exchange={}
local function publish(container,item,added)
    if isServer()then
        if added then sendAddItemToContainer(container,item)else sendRemoveItemFromContainer(container,item)end
    end
end
-- One excavation volume equals one Dirtbag use. Bags remain native inventory
-- objects, so hand carrying, loose piles and containers share mass.
function Exchange.perform(actor,square,direction,operationId,container,machine,useWheelbarrow)
    if isClient()then return false,'non-authority'end
    if type(operationId)~='string'or #operationId<1 or #operationId>160 then return false,'Invalid operation.'end
    if not actor or actor:isDead()or not square then return false,'Active worker and loaded ground required.'end
    if machine then
        return false,'Machine spoil exchange is unavailable.'
    else
        if actor:getVehicle()or not API.HandTools.squareReachable(actor,square)or not API.HandTools.findTool(actor)then
            return false,'Stand beside the excavation with a digging tool.'
        end
        container=actor:getInventory()
        if useWheelbarrow then
            local Wheelbarrow=require 'groundWorks/Wheelbarrow'
            local object=Wheelbarrow.nearby(actor)
            local allowed,why=Wheelbarrow.canHandle(actor,object)
            if not allowed then return false,why end
            container=object:getContainer()
        end
    end
    if SafeHouse and not SafeHouse.isSafehouseAllowInteract(square,actor)then return false,'No permission to work here.'end
    local store=API.EarthworkPersistence.getStore()
    if not store then return false,'Earthwork store unavailable.'end
    store.spoilOperations=store.spoilOperations or{};store.spoilOrder=store.spoilOrder or{}
    local prior=store.spoilOperations[operationId]
    local key=square:getX()..':'..square:getY()..':'..square:getZ()
    if prior then
        if prior.actor~=actor:getUsername()or prior.key~=key or prior.direction~=direction then return false,'Operation identity conflict.'end
        return prior.status=='completed',prior.reason or prior.status
    end
    local id=store.cellOwners[key];local job=id and store.jobs[id]
    if not job or job.status~='excavated'then return false,'A completed excavation is required.'end
    if direction~='bag'and direction~='return'then return false,'Unknown soil operation.'end
    if direction=='bag'and job.looseSoil<1 then return false,'No loose spoil remains.'end
    if direction=='return'and job.soilVolume-job.looseSoil<1 then return false,'Less than one soil unit is needed beside this excavation.'end
    if not container then return false,'Cargo container unavailable.'end
    local input=container:getFirstTypeRecurse(direction=='bag'and'Base.EmptySandbag'or'Base.Dirtbag')
    if not input then return false,direction=='bag'and'An empty sack is required.'or'A dirt sack is required.'end
    if input.getInventory and input:getInventory()and not input:getInventory():isEmpty()then return false,'Empty the sack first.'end
    local source=input:getContainer()
    if not source or not source:contains(input)then return false,'Sack moved.'end
    local delta=direction=='return'and input:getUseDelta()or nil
    local before=delta and input:getCurrentUsesFloat()or nil
    if delta and(delta<=0 or before+0.00001<delta)then return false,'Sack contains less than one soil unit.'end
    local partial=before and before>delta+.00001
    local output=not partial and instanceItem(direction=='bag'and'Base.Dirtbag'or'Base.EmptySandbag')or nil
    if not partial and not output then return false,'Sack item definition unavailable.'end
    if direction=='bag'then
        output:setUsedDelta(output:getUseDelta())
        output:getModData()['groundWorks.spoil.v1']={sourceJob=id}
    end
    if output and not container:hasRoomFor(actor,output)then return false,'Make room for the sack.'end
    local receipt={actor=actor:getUsername(),key=key,direction=direction,status='pending'}
    store.spoilOperations[operationId]=receipt;store.spoilOrder[#store.spoilOrder+1]=operationId
    local ok,why=pcall(function()
        if partial then input:setUsedDelta(before-delta)
        else
            actor:removeFromHands(input);source:Remove(input)
            assert(not source:contains(input),'Sack removal failed.')
            container:AddItem(output);assert(container:contains(output),'Sack insertion failed.')
        end
    end)
    if not ok then
        local restored=pcall(function()
            if partial then input:setUsedDelta(before)
            else
                if container:contains(output)then container:Remove(output)end
                if not source:contains(input)then source:AddItem(input)end
                assert(source:contains(input)and not container:contains(output))
            end
        end)
        receipt.status=restored and'rolled_back'or'needs_inspection';receipt.reason=tostring(why)
        return false,receipt.reason
    end
    job.looseSoil=job.looseSoil+(direction=='bag'and-1 or 1)
    receipt.status='completed'
    -- Never roll back a committed exchange because notification delivery fails.
    pcall(function()
        if partial then if isServer()then sendItemStats(input)end
        else publish(source,input,false);publish(container,output,true)end
        if isServer()then ModData.transmit(API.EarthworkPersistence.STORE_KEY)end
    end)
    while #store.spoilOrder>512 do
        local oldest=store.spoilOrder[1]
        if store.spoilOperations[oldest].status=='needs_inspection'then break end
        store.spoilOperations[table.remove(store.spoilOrder,1)]=nil
    end
    return true,direction=='bag'and'One soil unit bagged.'or'One soil unit returned for backfill.'
end
return Exchange
