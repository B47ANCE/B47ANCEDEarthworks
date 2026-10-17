local groundWorks=require "groundWorks/API"
local Topology=require "groundWorks/TrenchTopology"
local VolumeTypes=require "groundWorks/VolumeTypes"
local Providers=require "groundWorks/EarthworkProviders"
local Geometry=require "groundWorks/EarthworkGeometry"
local Jobs={SCHEMA_VERSION=1,MAX_JOBS=1024,MAX_OPERATIONS=128,MAX_AMOUNT=1000000}

local POUR_MEDIA={soil=true,water=true,concrete=true,fuel=true}
local DEPOSIT_MEDIA={item=true,body=true}

local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
local function canWrite()
    return not(type(rawget(_G,"isClient"))=="function"and isClient()==true
        and not(type(rawget(_G,"isServer"))=="function"and isServer()==true))
end
local function identifier(value,limit)return type(value)=="string"and value~=""and#value<=(limit or 128)end
local function copy(value,seen)
    if type(value)~="table"then return value end seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,child in pairs(value)do result[copy(key,seen)]=copy(child,seen)end;seen[value]=nil;return result
end
local function storeValid(store)
    return type(store)=="table"and store.schemaVersion==1 and type(store.jobs)=="table"
        and type(store.cellOwners)=="table"and type(store.stockpiles)=="table"and type(store.processedOperations)=="table"
end
local function remember(list,id)
    list[#list+1]=id;while#list>Jobs.MAX_OPERATIONS do table.remove(list,1)end
end
local function seen(list,id)for _,current in ipairs(list)do if current==id then return true end end;return false end
local function amount(value,label)
    value=finite(value);if not value or value<=0 or value>Jobs.MAX_AMOUNT then return nil,"bounded positive "..label.." required"end
    return value
end
local function job(store,id)
    if not storeValid(store)then return nil,"supported earthwork store required"end
    local current=store.jobs[id];if type(current)~="table"or current.schemaVersion~=1 then return nil,"unknown or malformed earthwork job"end
    return current
end
local function duplicate(current,operationId)return seen(current.processedOperations,operationId)end
local function grant(current,providerId,capability,requested,context)
    local protected={job=copy(current),request=copy(type(context)=="table"and context or{})}
    return Providers.authorize(providerId,capability,requested,protected)
end
local function fillTotals(fill)
    fill=type(fill)=="table"and fill or{}
    return(finite(fill.soil)or 0)+(finite(fill.water)or 0)+(finite(fill.concrete)or 0)+(finite(fill.fuel)or 0)
end
local function ensureVolumeFields(current)
    if type(current.fill)~="table"then current.fill={soil=0,water=0,concrete=0,fuel=0}end
    current.fill.soil=finite(current.fill.soil)or 0
    current.fill.water=finite(current.fill.water)or 0
    current.fill.concrete=finite(current.fill.concrete)or 0
    current.fill.fuel=finite(current.fill.fuel)or 0
    local cellCount=current.topology and current.topology.count or 1
    if type(current.occupants)~="table"then
        current.occupants={items=0,bodies=0,maxItems=VolumeTypes.maxItems(cellCount),maxBodies=VolumeTypes.maxBodies(cellCount)}
    end
    current.occupants.items=finite(current.occupants.items)or 0
    current.occupants.bodies=finite(current.occupants.bodies)or 0
    current.occupants.maxItems=finite(current.occupants.maxItems)or VolumeTypes.maxItems(cellCount)
    current.occupants.maxBodies=finite(current.occupants.maxBodies)or VolumeTypes.maxBodies(cellCount)
    if type(current.columns)~="table"then
        current.columns={}
        local share=(finite(current.soilVolume)or 0)/math.max(1,cellCount)
        for _,cell in ipairs(current.topology.cells)do
            current.columns[#current.columns+1]={x=cell.x,y=cell.y,filled=0,capacity=share,stack={}}
        end
    end
    if type(current.occupancy)~="table"then
        local definition=VolumeTypes.get(current.volumeType or current.type)
        current.occupancy=definition and copy(definition.occupancy)or{stand=false,receiveItems=false,receiveBodies=false,receiveFluids=false,ignite=false,pourSolid=false}
    end
    if type(current.fillMedia)~="table"then
        local definition=VolumeTypes.get(current.volumeType or current.type)
        current.fillMedia=definition and copy(definition.fillMedia)or{soil=true,item=false,body=false,water=false,fuel=false,concrete=false}
    end
end
local function pourIntoColumns(current,media,remaining)
    local accepted=0
    local depth=math.max(1,tonumber(current.targetDepth)or 1)
    local layerCap
    if#current.columns==0 then return 0,remaining end
    layerCap=(current.columns[1].capacity or 0)/depth
    if not finite(layerCap)or layerCap<=0 then return 0,remaining end
    for layer=1,depth do
        for _,col in ipairs(current.columns)do
            if remaining<=0 then break end
            col.stack=type(col.stack)=="table"and col.stack or{}
            col.filled=finite(col.filled)or 0
            local below=(layer-1)*layerCap
            local already=math.max(0,math.min(col.filled,layer*layerCap)-below)
            local room=layerCap-already
            if room>0 then
                local take=math.min(remaining,room)
                col.filled=col.filled+take
                local last=col.stack[#col.stack]
                if last and last.media==media then last.amount=(finite(last.amount)or 0)+take
                else col.stack[#col.stack+1]={media=media,amount=take}end
                remaining=remaining-take
                accepted=accepted+take
            end
        end
    end
    return accepted,remaining
end

function Jobs.newStore()
    return{schemaVersion=1,jobs={},cellOwners={},stockpiles={},processedOperations={}}
end

function Jobs.create(store,spec,operationId)
    if not canWrite()then return false,"non-authority"end
    if not storeValid(store)then return false,"supported earthwork store required"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    if seen(store.processedOperations,operationId)then return false,"store operation already processed"end
    spec=type(spec)=="table"and spec or{}
    if not identifier(spec.id,96)then return false,"bounded job ID required"end
    if store.jobs[spec.id]~=nil then return false,"earthwork job already exists"end
    local count=0;for _ in pairs(store.jobs)do count=count+1 end;if count>=Jobs.MAX_JOBS then return false,"earthwork job bound reached"end
    local definition,definitionErr=VolumeTypes.resolve(spec.volumeType or spec.type)
    if not definition then return false,definitionErr or"unsupported earthwork job type"end
    local depth=spec.targetDepth;if depth==nil then depth=1 end
    depth=finite(depth)
    if not depth or depth~=math.floor(depth)or depth<1 or depth>VolumeTypes.MAX_DEPTH then return false,"bounded target depth required"end
    if depth>definition.maxDepth then return false,"volume type does not allow that depth"end
    local work,workErr=amount(spec.workRequired,"work target");if not work then return false,workErr end
    local fillWork,fillErr=amount(spec.fillWorkRequired,"fill-work target");if not fillWork then return false,fillErr end
    local soil,soilErr=amount(spec.soilVolume,"soil volume");if not soil then return false,soilErr end
    local topology,topologyErr=Topology.analyze(spec.cells);if not topology then return false,topologyErr end
    if topology.z~=0 then return false,"initial trench footprint must be on z=0"end
    for _,cell in ipairs(topology.cells)do if store.cellOwners[cell.key]~=nil then return false,"earthwork cell already reserved"end end
    local share=soil/topology.count
    local columns={}
    for _,cell in ipairs(topology.cells)do
        columns[#columns+1]={x=cell.x,y=cell.y,filled=0,capacity=share,stack={}}
    end
    local current={schemaVersion=1,id=spec.id,type=definition.jobType,volumeType=definition.id,status="active",
        targetDepth=depth,surfaceCap=definition.surfaceCap,occupancy=copy(definition.occupancy),fillMedia=copy(definition.fillMedia),
        topology=topology,workRequired=work,workCompleted=0,fillWorkRequired=fillWork,fillWorkCompleted=0,soilVolume=soil,
        looseSoil=0,reservedBackfillSoil=0,fill={soil=0,water=0,concrete=0,fuel=0},
        occupants={items=0,bodies=0,maxItems=VolumeTypes.maxItems(topology.count),maxBodies=VolumeTypes.maxBodies(topology.count)},
        columns=columns,processedOperations={operationId},geometryTransaction=nil,
        createdWorldAgeHours=finite(spec.worldAgeHours),createdBy=identifier(spec.createdBy)and spec.createdBy or nil}
    store.jobs[current.id]=current;for _,cell in ipairs(topology.cells)do store.cellOwners[cell.key]=current.id end
    remember(store.processedOperations,operationId);return true,{duplicate=false,job=copy(current)}
end

function Jobs.snapshot(store,id)local current,err=job(store,id);return current and copy(current)or nil,err end

function Jobs.jobAtCell(store,x,y,z)
    if not storeValid(store)then return nil,"supported earthwork store required"end
    x,y,z=finite(x),finite(y),finite(z)
    if not x or not y or not z then return nil,"integer cell coordinates required"end
    local surfaceZ=z<0 and 0 or z
    local id=store.cellOwners[tostring(math.floor(x))..":"..tostring(math.floor(y))..":"..tostring(math.floor(surfaceZ))]
    if type(id)~="string"then return nil,"no earthwork job at cell"end
    local current,err=job(store,id)
    return current and copy(current)or nil,err
end

function Jobs.applyWork(store,id,capability,requested,operationId,providerId,context)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    local field,target,nextStatus
    if capability=="excavate"and current.status=="active"then
        field,target,nextStatus="workCompleted",current.workRequired,"ready_to_excavate"
    elseif capability=="fill"and current.status=="backfilling"then
        field,target,nextStatus="fillWorkCompleted",current.fillWorkRequired,"ready_to_backfill"
    else return false,"job status does not accept requested work"end
    local requestedAmount,amountErr=amount(requested,"work amount");if not requestedAmount then return false,amountErr end
    local authorized,authErr=grant(current,providerId,capability,requestedAmount,context);if not authorized then return false,authErr end
    local accepted=math.min(requestedAmount,target-current[field]);if accepted<=0 then return false,"work target already satisfied"end
    current[field]=current[field]+accepted;remember(current.processedOperations,operationId)
    local completed=current[field]>=target;if completed then current.status=nextStatus end
    return true,{duplicate=false,accepted=accepted,excess=requestedAmount-accepted,completed=completed,
        providerId=authorized.providerId,providerKind=authorized.providerKind,job=copy(current)}
end

function Jobs.beginGeometryCommit(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.pendingDeepen==true then return false,"deepen is not a geometry commit"end
    local mode
    if current.status=="ready_to_excavate"then mode="excavate"
    elseif current.status=="ready_to_backfill"then mode="backfill"
    else return false,"job is not ready for geometry commit"end
    local plan,planErr=Geometry.plan(current,operationId,mode);if not plan then return false,planErr end
    current.status="geometry_committing";current.geometryTransaction={schemaVersion=1,operationId=operationId,mode=mode,status="committing",plan=plan}
    remember(current.processedOperations,operationId);return true,{duplicate=false,transaction=copy(current.geometryTransaction),job=copy(current)}
end

function Jobs.resolveGeometryCommit(store,id,operationId,outcome,receipt)
    if not canWrite()then return false,"non-authority"end
    local current,err=job(store,id);if not current then return false,err end
    local transaction=current.geometryTransaction
    if current.status~="geometry_committing"or type(transaction)~="table"or transaction.operationId~=operationId then
        return false,"matching geometry transaction required"
    end
    receipt=type(receipt)=="table"and copy(receipt)or{}
    if outcome=="committed"then
        local verified,verifyErr=Geometry.verifyReceipt(transaction.plan,receipt,outcome);if not verified then return false,verifyErr end
        transaction.status="committed";transaction.receipt=receipt
        if transaction.mode=="excavate"then current.status="excavated";current.looseSoil=current.looseSoil+current.soilVolume
        else
            current.status="filled";current.reservedBackfillSoil=0;current.surfaceCap="sealed"
            for _,cell in ipairs(current.topology.cells)do if store.cellOwners[cell.key]==current.id then store.cellOwners[cell.key]=nil end end
        end
        return true,{outcome=outcome,job=copy(current)}
    end
    if outcome=="rolled_back"then
        local verified,verifyErr=Geometry.verifyReceipt(transaction.plan,receipt,outcome);if not verified then return false,verifyErr end
        transaction.status="rolled_back";transaction.receipt=receipt;current.geometryTransaction=nil
        current.status=transaction.mode=="excavate"and"ready_to_excavate"or"ready_to_backfill"
        return true,{outcome=outcome,job=copy(current)}
    end
    if outcome=="uncertain"then
        transaction.status="inspection_required";transaction.receipt=receipt;current.status="quarantined"
        return true,{outcome=outcome,job=copy(current)}
    end
    return false,"geometry outcome must be committed, rolled_back, or uncertain"
end

function Jobs.createStockpile(store,id,capacity,operationId)
    if not canWrite()then return false,"non-authority"end
    if not storeValid(store)then return false,"supported earthwork store required"end
    if not identifier(id,96)or not identifier(operationId)then return false,"bounded stockpile and operation IDs required"end
    if seen(store.processedOperations,operationId)then return true,{duplicate=true,stockpile=copy(store.stockpiles[id])}end
    if store.stockpiles[id]~=nil then return false,"stockpile already exists"end
    local maximum,err=amount(capacity,"stockpile capacity");if not maximum then return false,err end
    local pile={schemaVersion=1,id=id,capacity=maximum,soil=0,processedOperations={operationId}}
    store.stockpiles[id]=pile;remember(store.processedOperations,operationId);return true,{duplicate=false,stockpile=copy(pile)}
end

function Jobs.transferSoil(store,id,stockpileId,direction,requested,operationId,providerId,context)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current),stockpile=copy(store.stockpiles[stockpileId])}end
    if current.status~="excavated"then return false,"soil transfers require an excavated job"end
    local pile=store.stockpiles[stockpileId];if type(pile)~="table"or pile.schemaVersion~=1 then return false,"known stockpile required"end
    local requestedAmount,amountErr=amount(requested,"soil amount");if not requestedAmount then return false,amountErr end
    local authorized,authErr=grant(current,providerId,"transferSoil",requestedAmount,context);if not authorized then return false,authErr end
    local accepted
    if direction=="to_stockpile"then
        accepted=math.min(requestedAmount,current.looseSoil,pile.capacity-pile.soil)
        if accepted<=0 then return false,"no soil can be transferred to stockpile"end
        current.looseSoil=current.looseSoil-accepted;pile.soil=pile.soil+accepted
    elseif direction=="to_excavation"then
        accepted=math.min(requestedAmount,pile.soil,current.soilVolume-current.looseSoil)
        if accepted<=0 then return false,"no soil can be returned to excavation"end
        pile.soil=pile.soil-accepted;current.looseSoil=current.looseSoil+accepted
    else return false,"unknown soil-transfer direction"end
    remember(current.processedOperations,operationId);remember(pile.processedOperations,operationId)
    return true,{duplicate=false,accepted=accepted,excess=requestedAmount-accepted,providerId=authorized.providerId,
        job=copy(current),stockpile=copy(pile)}
end

function Jobs.deposit(store,id,media,requested,operationId,providerId,context)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    if not DEPOSIT_MEDIA[media]then return false,"deposit media must be item or body"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,accepted=0,excess=finite(requested)or 0,job=copy(current)}end
    if current.status~="excavated"then return false,"deposits require an excavated cavity"end
    ensureVolumeFields(current)
    if media=="item"and current.occupancy.receiveItems~=true then return false,"volume does not receive items"end
    if media=="body"and current.occupancy.receiveBodies~=true then return false,"volume does not receive bodies"end
    local requestedAmount,amountErr=amount(requested,"deposit amount");if not requestedAmount then return false,amountErr end
    local authorized,authErr=grant(current,providerId,"deposit",requestedAmount,context);if not authorized then return false,authErr end
    local field=media=="body"and"bodies"or"items"
    local maximum=media=="body"and current.occupants.maxBodies or current.occupants.maxItems
    local room=math.max(0,maximum-current.occupants[field])
    local accepted=math.min(requestedAmount,room)
    if accepted<=0 then return false,"cavity occupant bound reached"end
    current.occupants[field]=current.occupants[field]+accepted
    remember(current.processedOperations,operationId)
    return true,{duplicate=false,accepted=accepted,excess=requestedAmount-accepted,rejected=requestedAmount-accepted,
        providerId=authorized.providerId,job=copy(current)}
end

function Jobs.pour(store,id,media,requested,operationId,providerId,context)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    if not POUR_MEDIA[media]then return false,"pour media must be soil, water, concrete, or fuel"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,accepted=0,excess=finite(requested)or 0,job=copy(current)}end
    if current.status~="excavated"then return false,"pours require an excavated cavity"end
    ensureVolumeFields(current)
    if current.fillMedia[media]~=true then return false,"volume type does not accept "..media end
    local requestedAmount,amountErr=amount(requested,"pour amount");if not requestedAmount then return false,amountErr end
    local authorized,authErr=grant(current,providerId,"fill",requestedAmount,context);if not authorized then return false,authErr end
    local room=math.max(0,current.soilVolume-fillTotals(current.fill))
    local accepted=math.min(requestedAmount,room)
    if accepted<=0 then return false,"cavity fill capacity reached"end
    local poured=pourIntoColumns(current,media,accepted)
    current.fill[media]=(finite(current.fill[media])or 0)+poured
    if media=="concrete"and fillTotals(current.fill)>=current.soilVolume then current.surfaceCap="sealed"end
    remember(current.processedOperations,operationId)
    return true,{duplicate=false,accepted=poured,excess=requestedAmount-poured,liveWorld=true,
        providerId=authorized.providerId,job=copy(current)}
end

function Jobs.closeVolume(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.status~="excavated"and current.status~="ready_to_backfill"then return false,"volume is not ready to close"end
    ensureVolumeFields(current)
    if current.occupants.items>0 or current.occupants.bodies>0 then return false,"cavity still has occupants"end
    if(current.fill.water or 0)>0 or(current.fill.concrete or 0)>0 or(current.fill.fuel or 0)>0 then
        return false,"cavity has non-soil fill"
    end
    if(current.fill.soil or 0)<current.soilVolume and current.reservedBackfillSoil<current.soilVolume then
        return false,"soil fill is not complete"
    end
    current.status="filled";current.surfaceCap="sealed";current.reservedBackfillSoil=0
    remember(current.processedOperations,operationId)
    for _,cell in ipairs(current.topology.cells)do if store.cellOwners[cell.key]==current.id then store.cellOwners[cell.key]=nil end end
    return true,{duplicate=false,job=copy(current)}
end

function Jobs.beginDeepen(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.pendingDeepen==true and(current.status=="active"or current.status=="ready_to_excavate")then
        return true,{duplicate=false,job=copy(current),already=true}
    end
    if current.status~="excavated"then return false,"only an excavated job can be deepened"end
    ensureVolumeFields(current)
    if current.surfaceCap=="sealed"or(finite(current.fill.concrete)or 0)>0 then
        return false,"cavity has non-soil fill"
    end
    local definition=VolumeTypes.get(current.volumeType or current.type)
    local depth=math.max(1,math.floor(tonumber(current.targetDepth)or 1))
    local maxDepth=math.min(VolumeTypes.MAX_DEPTH,definition and definition.maxDepth or 1)
    if depth>=maxDepth then return false,"volume type does not allow that depth"end
    current.pendingDeepen=true
    current.workCompleted=0
    current.status="active"
    remember(current.processedOperations,operationId)
    return true,{duplicate=false,job=copy(current)}
end

function Jobs.finishDeepen(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.pendingDeepen~=true then return false,"matching deepen required"end
    if current.status~="ready_to_excavate"then return false,"job is not ready to deepen"end
    ensureVolumeFields(current)
    local depth=math.max(1,math.floor(tonumber(current.targetDepth)or 1))
    local definition=VolumeTypes.get(current.volumeType or current.type)
    local maxDepth=math.min(VolumeTypes.MAX_DEPTH,definition and definition.maxDepth or 1)
    if depth>=maxDepth then return false,"volume type does not allow that depth"end
    local layer=(finite(current.soilVolume)or 1)/depth
    if not finite(layer)or layer<=0 then layer=1 end
    current.targetDepth=depth+1
    current.soilVolume=(finite(current.soilVolume)or 0)+layer
    current.looseSoil=(finite(current.looseSoil)or 0)+layer
    local cellCount=math.max(1,current.topology and current.topology.count or 1)
    local share=layer/cellCount
    for _,col in ipairs(current.columns)do
        col.capacity=(finite(col.capacity)or 0)+share
    end
    current.pendingDeepen=nil
    current.workCompleted=current.workRequired
    current.status="excavated"
    remember(current.processedOperations,operationId)
    return true,{duplicate=false,job=copy(current)}
end

function Jobs.abortDeepen(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.pendingDeepen~=true then return false,"matching deepen required"end
    current.pendingDeepen=nil
    current.workCompleted=current.workRequired
    current.status="excavated"
    remember(current.processedOperations,operationId)
    return true,{duplicate=false,job=copy(current)}
end

function Jobs.beginBackfill(store,id,operationId)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.status~="excavated"then return false,"only an excavated job can be backfilled"end
    ensureVolumeFields(current)
    if current.occupants.items>0 or current.occupants.bodies>0 then return false,"cavity still has occupants"end
    if(current.fill.concrete or 0)>0 or(current.fill.water or 0)>0 or(current.fill.fuel or 0)>0 then
        return false,"cavity has non-soil fill"
    end
    if current.looseSoil<current.soilVolume then return false,"full excavation soil volume required for backfill"end
    current.looseSoil=current.looseSoil-current.soilVolume;current.reservedBackfillSoil=current.soilVolume
    current.fillWorkCompleted=0;current.status="backfilling";remember(current.processedOperations,operationId)
    return true,{duplicate=false,job=copy(current)}
end

function Jobs.cancel(store,id,operationId,reason)
    if not canWrite()then return false,"non-authority"end
    if not identifier(operationId)then return false,"bounded operation ID required"end
    local current,err=job(store,id);if not current then return false,err end
    if duplicate(current,operationId)then return true,{duplicate=true,job=copy(current)}end
    if current.status~="active"then return false,"only an uncommitted active job can be cancelled"end
    if current.pendingDeepen==true then return false,"cannot cancel a live shaft deepen"end
    current.status="cancelled";current.cancelReason=tostring(reason or"cancelled"):sub(1,256);remember(current.processedOperations,operationId)
    for _,cell in ipairs(current.topology.cells)do if store.cellOwners[cell.key]==current.id then store.cellOwners[cell.key]=nil end end
    return true,{duplicate=false,job=copy(current)}
end

groundWorks.EarthworkJobs=Jobs
return Jobs
