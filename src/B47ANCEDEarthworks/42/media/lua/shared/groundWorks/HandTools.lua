local groundWorks=require "groundWorks/API"
local VolumeTypes=require "groundWorks/VolumeTypes"
local Providers=require "groundWorks/EarthworkProviders"
local HandTools={
    PROVIDER_ID="groundWorks.handTool.v1",
    WORK_REQUIRED=20,
    MAX_RANGE=2.5,
    ACTIONS={
        {id="trench",volumeType="groundWorks.trench",labelKey="ContextMenu_groundWorks_DigTrench"},
        {id="moat",volumeType="groundWorks.moat",labelKey="ContextMenu_groundWorks_DigMoat"},
        {id="grave",volumeType="groundWorks.grave",labelKey="ContextMenu_groundWorks_DigGrave"},
        {id="openPit",volumeType="groundWorks.openPit",labelKey="ContextMenu_groundWorks_DigOpenPit"},
        {id="basement",volumeType="groundWorks.basement",labelKey="ContextMenu_groundWorks_DigBasement"},
        {id="burnPit",volumeType="groundWorks.burnPit",labelKey="ContextMenu_groundWorks_DigBurnPit"},
        {id="foundation",volumeType="groundWorks.foundation",labelKey="ContextMenu_groundWorks_DigFoundation"},
    },
}

local KNOWN={
    ["Base.Shovel"]={kind="shovel",work=10,maxTime=80,anim="Shovel",wear=1},
    ["Base.Shovel2"]={kind="shovel",work=10,maxTime=80,anim="Shovel",wear=1},
    ["Base.HandShovel"]={kind="trowel",work=5,maxTime=60,anim="Shovel",wear=1},
    ["Base.GardenHoe"]={kind="hoe",work=6,maxTime=70,anim="Shovel",wear=1},
    ["Base.PickAxe"]={kind="pick",work=12,maxTime=90,anim="PickAxe",wear=1},
    ["Base.PickAxeForged"]={kind="pick",work=12,maxTime=90,anim="PickAxe",wear=1},
    ["Base.AxeStone"]={kind="pick",work=8,maxTime=100,anim="PickAxe",wear=1},
}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return nil end
    local ran,result=pcall(fn,object,...)
    return ran and result or nil
end
local function sandbox()
    local root=rawget(_G,"SandboxVars")
    return type(root)=="table"and root.groundWorks or nil
end
local function copyTool(item,spec)
    return{item=item,fullType=call(item,"getFullType")or spec.fullType,kind=spec.kind,work=spec.work,
        maxTime=spec.maxTime,anim=spec.anim,wear=spec.wear}
end
local function lowered(value)return tostring(value or""):lower()end
local function fullType(item)return tostring(call(item,"getFullType")or"")end

if not Providers.get(HandTools.PROVIDER_ID)then
    Providers.register{
        id=HandTools.PROVIDER_ID,kind="manual",
        capabilities={excavate=true,fill=true,transferSoil=true,deposit=true},
        maxWorkPerOperation=16,maxSoilPerOperation=16,
    }
end

function HandTools.enabled()
    local settings=sandbox()
    if type(settings)~="table"then return true end
    return settings.EnableHandExcavation~=false
end

function HandTools.worldCommitEnabled()
    return HandTools.enabled()
end

function HandTools.inspectItem(item)
    if not item then return nil end
    if call(item,"isBroken")==true then return nil end
    local condition=tonumber(call(item,"getCondition")or 1)or 1
    if condition<=0 then return nil end
    local full=fullType(item)
    local known=KNOWN[full]
    if known then local tool=copyTool(item,known);tool.fullType=full;return tool end
    local digType=call(item,"getDigType")
    local shovel=digType=="Shovel"or digType=="Trowel"or digType=="Hoe"
    local pick=digType=="PickAxe"
    local name=lowered(full)
    if shovel or name:find("shovel",1,true)or name:find("trowel",1,true)then
        return copyTool(item,{kind="shovel",work=10,maxTime=80,anim="Shovel",wear=1,fullType=full})
    end
    if pick or name:find("pickaxe",1,true)or name:find("pick_axe",1,true)then
        return copyTool(item,{kind="pick",work=12,maxTime=90,anim="PickAxe",wear=1,fullType=full})
    end
    return nil
end

function HandTools.inspectMedia(item)
    if not item then return nil end
    local full=fullType(item)
    local name=lowered(full)
    local function media(kind,consume,anim)
        return{item=item,fullType=full,media=kind,consume=consume or"use",anim=anim or"Pour",maxTime=50}
    end
    local fluid=call(item,"getFluidContainer")
    if fluid then
        local amount=tonumber(call(fluid,"getAmount"))or 0
        if amount<=0 then return nil end
        local fluids=rawget(_G,"Fluid")
        if fluids then
            for _,entry in ipairs({{"water",fluids.Water},{"fuel",fluids.Petrol}})do
                if entry[2]and call(fluid,"isPureFluid",entry[2])==true then
                    local source=media(entry[1],"fluid","Pour")
                    source.amount=math.min(1,amount)
                    return source
                end
            end
        end
        return nil
    end
    local uses=tonumber(call(item,"getCurrentUsesFloat"))or tonumber(call(item,"getUsedDelta"))
    if uses and uses<=0 then return nil end
    if full=="Base.BucketConcreteFull"then
        return media("concrete","use","Pour")
    end
    if full=="Base.Dirtbag"then
        return media("soil","use","Shovel")
    end
    return nil
end

function HandTools.inspectIgniter(item)
    if not item then return nil end
    local full=fullType(item)
    local name=lowered(full)
    local uses=tonumber(call(item,"getCurrentUsesFloat"))or 0
    if uses<=0 then return nil end
    if full=="Base.Matches"or full=="Base.Lighter"or full=="Base.LighterDisposable"or full=="Base.LighterBBQ"then
        return{item=item,fullType=full,kind="igniter",anim="Craft",maxTime=40}
    end
end

local function scan(container,depth,inspector)
    if not container or depth>4 then return nil end
    local items=call(container,"getItems")
    local size=math.floor(tonumber(call(items,"size"))or 0)
    for index=0,size-1 do
        local item=call(items,"get",index)
        local found=inspector(item)
        if found then return found end
        found=scan(call(item,"getInventory"),depth+1,inspector)
        if found then return found end
    end
end

function HandTools.findTool(player)
    if not player then return nil,"player required"end
    local equipped=HandTools.inspectItem(call(player,"getPrimaryHandItem"))
    if equipped then equipped.equipped=true;return equipped end
    local bag=scan(call(player,"getInventory"),0,HandTools.inspectItem)
    if bag then return bag end
    return nil,getText("IGUI_groundWorks_NeedTool")
end

function HandTools.findMedia(player,media)
    if not player then return nil end
    local function match(item)
        local found=HandTools.inspectMedia(item)
        if found and(not media or found.media==media)then return found end
    end
    local equipped=match(call(player,"getPrimaryHandItem"))or match(call(player,"getSecondaryHandItem"))
    if equipped then return equipped end
    return scan(call(player,"getInventory"),0,match)
end

function HandTools.findIgniter(player)
    if not player then return nil end
    local equipped=HandTools.inspectIgniter(call(player,"getPrimaryHandItem"))or HandTools.inspectIgniter(call(player,"getSecondaryHandItem"))
    if equipped then return equipped end
    return scan(call(player,"getInventory"),0,HandTools.inspectIgniter)
end

function HandTools.squareReachable(player,square)
    if not player or not square then return false,"square required"end
    local z=tonumber(call(square,"getZ"))
    local pz=tonumber(call(player,"getZ"))
    if not z or not pz or z>0 or pz>0 then return false,getText("IGUI_groundWorks_DigGroundLevel")end
    local dx=(tonumber(call(player,"getX"))or 0)-(tonumber(call(square,"getX"))or 0)-0.5
    local dy=(tonumber(call(player,"getY"))or 0)-(tonumber(call(square,"getY"))or 0)-0.5
    if dx*dx+dy*dy>HandTools.MAX_RANGE*HandTools.MAX_RANGE then
        local same=math.floor(tonumber(call(player,"getX"))or 0)==math.floor(tonumber(call(square,"getX"))or 0)
            and math.floor(tonumber(call(player,"getY"))or 0)==math.floor(tonumber(call(square,"getY"))or 0)
        if not same then return false,getText("IGUI_groundWorks_HandTooFar")end
    end
    if math.floor(pz)~=z then
        local here=call(player,"getCurrentSquare")
        local receipt=here and groundWorks.Cavity and groundWorks.Cavity.inspect(here)
        local opening=type(receipt)=="table"and receipt.opening
        if not opening or receipt.status~="created"or receipt.sealed==true
            or z~=0 or opening.x~=call(square,"getX")or opening.y~=call(square,"getY")then
            return false,getText("IGUI_groundWorks_HandTooFar")
        end
    else
        local here=call(player,"getCurrentSquare")
        if here and call(here,"isBlockedTo",square)==true then return false,"The work square is blocked."end
    end
    return true
end

function HandTools.openingSquare(square)
    if not square then return nil end
    local z=tonumber(call(square,"getZ"))or 0
    if z==0 then return square end
    local cell=rawget(_G,"getCell")
    if type(cell)~="function"then return square end
    local ok,grid=pcall(cell)
    if not ok or not grid then return square end
    return call(grid,"getGridSquare",math.floor(tonumber(call(square,"getX"))or 0),math.floor(tonumber(call(square,"getY"))or 0),0)or square
end

function HandTools.volumeId(value)
    local definition=VolumeTypes.get(value)
    if definition and definition.domain=="excavation"and definition.liveGeometry==true then return definition.id end
    if value==nil or value==""then return"groundWorks.openPit"end
    return nil,getText("IGUI_groundWorks_HandVolumeOnly")
end

function HandTools.jobAt(square)
    local opening=HandTools.openingSquare(square)
    local persistence=groundWorks.EarthworkPersistence
    local jobs=groundWorks.EarthworkJobs
    if not opening or not persistence or not jobs then return nil end
    local store=persistence.getStore and persistence.getStore()
    if not store then return nil end
    return jobs.jobAtCell(store,call(opening,"getX"),call(opening,"getY"),0)
end

function HandTools.receiptAt(square)
    local opening=HandTools.openingSquare(square)
    if not opening or not groundWorks.Cavity then return nil end
    return groundWorks.Cavity.inspect(opening)
end

local function findLiveOpening(player,square)
    local function created(target)
        local opening=HandTools.openingSquare(target)
        if not HandTools.squareReachable(player,opening)then return nil end
        local receipt=HandTools.receiptAt(opening)
        if type(receipt)=="table"and receipt.status=="created"and receipt.sealed~=true then return opening,receipt end
    end
    local opening,receipt=created(square)
    if opening then return opening,receipt end
    opening,receipt=created(call(player,"getCurrentSquare"))
    if opening then return opening,receipt end
    local here=call(player,"getCurrentSquare")
    local getter=rawget(_G,"getCell")
    local cell=type(getter)=="function"and getter()or nil
    local hx,hy=math.floor(tonumber(call(here,"getX"))or 0),math.floor(tonumber(call(here,"getY"))or 0)
    if not cell then return nil end
    for dy=-1,1 do
        for dx=-1,1 do
            opening,receipt=created(call(cell,"getGridSquare",hx+dx,hy+dy,0))
            if opening then return opening,receipt end
        end
    end
end

function HandTools.canExcavate(player,square,volumeType)
    if not HandTools.enabled()then return false,getText("IGUI_groundWorks_HandDisabled")end
    if call(player,"isDead")==true then return false,getText("IGUI_groundWorks_NeedSurvivor")end
    if call(player,"getVehicle")then return false,getText("IGUI_groundWorks_ExitVehicle")end
    local reach,reachErr=HandTools.squareReachable(player,square)
    if not reach then return false,reachErr end
    if tonumber(call(square,"getZ"))~=0 then return false,getText("IGUI_groundWorks_DigGroundLevel")end
    if math.floor(tonumber(call(player,"getZ"))or 1)~=0 then return false,getText("IGUI_groundWorks_DigGroundLevel")end
    if call(square,"isFree",false)==false then return false,"Clear the excavation square first."end
    local tool,toolErr=HandTools.findTool(player)
    if not tool then return false,toolErr end
    local volume,volumeErr=HandTools.volumeId(volumeType)
    if not volume then return false,volumeErr end
    if volume~="groundWorks.basement"and(call(square,"getRoom")or call(square,"getBuilding"))then return false,"Excavate this volume on open natural ground."end
    local allowed,reason=groundWorks.validateVolume(volume,{square=square,actor=player})
    if not allowed then return false,reason end
    local receipt=HandTools.receiptAt(square)
    if type(receipt)=="table"and(receipt.status=="created"or receipt.status=="creating")then
        return false,getText("IGUI_groundWorks_AlreadyOpen")
    end
    return true,{tool=tool,volumeType=volume,op="excavate"}
end

function HandTools.canDeepen(player,square)
    if not HandTools.enabled()then return false,getText("IGUI_groundWorks_HandDisabled")end
    if call(player,"isDead")==true then return false,getText("IGUI_groundWorks_NeedSurvivor")end
    if call(player,"getVehicle")then return false,getText("IGUI_groundWorks_ExitVehicle")end
    local reach,reachErr=HandTools.squareReachable(player,square)
    if not reach then
        local here=call(player,"getCurrentSquare")
        reach,reachErr=HandTools.squareReachable(player,here)
        if not reach then return false,reachErr end
        square=here or square
    end
    local tool,toolErr=HandTools.findTool(player)
    if not tool then return false,toolErr end
    local opening,receipt=findLiveOpening(player,square)
    if type(receipt)~="table"or receipt.status~="created"or receipt.sealed==true then
        return false,getText("IGUI_groundWorks_NeedOpenVolume")
    end
    local job=HandTools.jobAt(opening)
    if not job then return false,getText("IGUI_groundWorks_NeedOpenVolume")end
    if groundWorks.Cavity.hasContents(opening,nil,player)then return false,getText("IGUI_groundWorks_HasOccupants")end
    local deepening=job.pendingDeepen==true and(job.status=="active"or job.status=="ready_to_excavate")
    if job.status~="excavated"and not deepening then
        return false,getText("IGUI_groundWorks_NeedOpenVolume")
    end
    local fill=job.fill or{}
    if job.surfaceCap=="sealed"or(tonumber(fill.concrete)or 0)>0 or(tonumber(fill.soil)or 0)>0
        or(tonumber(fill.water)or 0)>0 or(tonumber(fill.fuel)or 0)>0 then
        return false,getText("IGUI_groundWorks_HasFill")
    end
    local definition=VolumeTypes.get(job.volumeType or receipt.volumeType or job.type)
    local depth=math.max(1,math.floor(tonumber(job.targetDepth)or tonumber(receipt.targetDepth)or 1))
    local liveMax=groundWorks.Cavity and tonumber(groundWorks.Cavity.LIVE_MAX_DEPTH)or VolumeTypes.MAX_DEPTH
    local maxDepth=math.min(liveMax,definition and definition.maxDepth or 1)
    if deepening then
        -- work is already counted against the next level
    elseif depth>=maxDepth then
        return false,getText("IGUI_groundWorks_MaxDepth")
    end
    return true,{op="deepen",tool=tool,volumeType=receipt.volumeType or job.volumeType,opening=opening,depth=depth,maxDepth=maxDepth}
end

function HandTools.canStart(player,square,volumeType)
    return HandTools.canExcavate(player,square,volumeType)
end

local function excavatedContext(player,square)
    if not HandTools.enabled()then return nil,getText("IGUI_groundWorks_HandDisabled")end
    if call(player,"isDead")==true then return nil,getText("IGUI_groundWorks_NeedSurvivor")end
    if call(player,"getVehicle")then return nil,getText("IGUI_groundWorks_ExitVehicle")end
    local reach,reachErr=HandTools.squareReachable(player,square)
    if not reach then
        local here=call(player,"getCurrentSquare")
        reach,reachErr=HandTools.squareReachable(player,here)
        if not reach then return nil,reachErr end
    end
    local opening,receipt=findLiveOpening(player,square)
    if type(receipt)~="table"or receipt.status~="created"or receipt.sealed==true then
        return nil,getText("IGUI_groundWorks_NeedOpenVolume")
    end
    local job=HandTools.jobAt(opening)
    if job and job.status~="excavated"and job.status~="backfilling"and job.status~="ready_to_backfill"then
        return nil,getText("IGUI_groundWorks_NeedOpenVolume")
    end
    return{opening=opening,receipt=receipt,job=job,occupancy=receipt.occupancy or(job and job.occupancy)or{},fillMedia=receipt.fillMedia or(job and job.fillMedia)or{}}
end

function HandTools.canFill(player,square)
    if (tonumber(call(player,"getZ"))or 0)<0 then return false,getText("IGUI_groundWorks_HasOccupants")end
    local context,err=excavatedContext(player,square)
    if not context then return false,err end
    if groundWorks.Cavity.hasContents and groundWorks.Cavity.hasContents(context.opening)then
        return false,getText("IGUI_groundWorks_HasOccupants")
    end
    if context.fillMedia.soil~=true then return false,getText("IGUI_groundWorks_CannotFill")end
    local occupants=context.job and context.job.occupants
    if occupants and((tonumber(occupants.items)or 0)>0 or(tonumber(occupants.bodies)or 0)>0)then
        return false,getText("IGUI_groundWorks_HasOccupants")
    end
    local fill=context.job and context.job.fill or{}
    if(tonumber(fill.water)or 0)>0 or(tonumber(fill.concrete)or 0)>0 or(tonumber(fill.fuel)or 0)>0 then
        return false,getText("IGUI_groundWorks_HasFill")
    end
    local dirt=HandTools.findMedia(player,"soil")
    local tool=HandTools.findTool(player)
    if not dirt and not tool then return false,getText("IGUI_groundWorks_NeedDirt")end
    return true,{op="fill",tool=dirt or tool,media="soil",volumeType=context.receipt.volumeType,opening=context.opening}
end

function HandTools.canPour(player,square,media)
    local context,err=excavatedContext(player,square)
    if not context then return false,err end
    if media~="water"and media~="fuel"and media~="concrete"then return false,getText("IGUI_groundWorks_CannotPour")end
    if media=="concrete"and groundWorks.Cavity.hasContents and groundWorks.Cavity.hasContents(context.opening)then
        return false,getText("IGUI_groundWorks_HasOccupants")
    end
    local fill=context.job and context.job.fill or{}
    local total=(tonumber(fill.soil)or 0)+(tonumber(fill.water)or 0)+(tonumber(fill.concrete)or 0)+(tonumber(fill.fuel)or 0)
    if context.job and total>=(tonumber(context.job.soilVolume)or 1)then return false,"This excavation is full."end
    if media=="water"and context.occupancy.receiveFluids~=true and context.fillMedia.water~=true then
        return false,getText("IGUI_groundWorks_CannotPour")
    end
    if media=="concrete"and context.occupancy.pourSolid~=true and context.fillMedia.concrete~=true then
        return false,getText("IGUI_groundWorks_CannotPour")
    end
    if media=="fuel"and context.occupancy.ignite~=true and context.fillMedia.fuel~=true then
        return false,getText("IGUI_groundWorks_CannotPour")
    end
    if context.fillMedia[media]~=true then return false,getText("IGUI_groundWorks_CannotPour")end
    local source=HandTools.findMedia(player,media)
    if not source then return false,getText("IGUI_groundWorks_NeedMedia")end
    return true,{op="pour",tool=source,media=media,volumeType=context.receipt.volumeType,opening=context.opening}
end

function HandTools.canIgnite(player,square)
    local context,err=excavatedContext(player,square)
    if not context then return false,err end
    if context.occupancy.ignite~=true then return false,getText("IGUI_groundWorks_CannotIgnite")end
    local fill=context.job and context.job.fill or{}
    if(tonumber(fill.fuel)or 0)<=0 and context.receipt.fillVisual~="fuel"and context.receipt.burning~=true then
        return false,getText("IGUI_groundWorks_NeedFuel")
    end
    local igniter=HandTools.findIgniter(player)
    if not igniter then return false,getText("IGUI_groundWorks_NeedIgniter")end
    return true,{op="ignite",tool=igniter,volumeType=context.receipt.volumeType,opening=context.opening}
end

function HandTools.jobId(square)
    local opening=HandTools.openingSquare(square)or square
    local x,y=math.floor(tonumber(call(opening,"getX"))or 0),math.floor(tonumber(call(opening,"getY"))or 0)
    return"hand:"..tostring(x)..":"..tostring(y),x,y
end

groundWorks.HandTools=HandTools
return HandTools
