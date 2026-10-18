local API=require 'groundWorks/API'
local Routes=require 'groundWorks/ConstructedRoutes'
local Hand=require 'groundWorks/HandTools'
local Work={}
local EPSILON=0.00001
local function finite(value)value=tonumber(value);return value and value==value and value~=math.huge and value~=-math.huge and value or nil end
Work.OPTIONS={
    {op='routeStart',route='groundWorks.gravelPath',label='Start gravel path'},
    {op='routeSupply',label='Supply route material'},
    {op='routeWork',label='Build route'},
}
local function material(player,requirements,supplied)
    local queue={player:getInventory()}
    local seen={}
    local visited=0
    local index=1
    while index<=#queue and index<=64 do
        local container=queue[index];index=index+1
        if container and not seen[container]then
            seen[container]=true
            local items=container:getItems()
            for i=0,items:size()-1 do
                visited=visited+1;if visited>256 then return nil end
                local item=items:get(i)
                local id=item:getFullType()
                local required=finite(requirements[id])
                if required and required-(finite(supplied[id])or 0)>=1-EPSILON then
                    local delta=type(item.getUseDelta)=='function'and finite(item:getUseDelta())
                    local uses=type(item.getCurrentUsesFloat)=='function'and finite(item:getCurrentUsesFloat())
                    if delta and delta>0 and delta<=1 and uses and uses+EPSILON>=delta and type(item.Use)=='function' then
                        return{item=item,container=container,material=id,delta=delta}
                    end
                end
                if item.getInventory then
                    local nested=item:getInventory()
                    if nested and #queue<64 then queue[#queue+1]=nested end
                end
            end
        end
    end
end
Work.findMaterial=material

-- Called inside Projects.contributeTransaction. False guarantees no mutation;
-- anything uncertain after Use raises so the material recovery record survives.
function Work.consumeMaterial(source,accepted)
    if type(source)~='table'or accepted~=1 or not finite(source.delta)then return false,'One material use is required.'end
    local item,container=source.item,source.container
    if not item or not container or item:getContainer()~=container or not container:contains(item)
        or item:getFullType()~=source.material then return false,'Material moved or changed.'end
    local before=finite(item:getCurrentUsesFloat())
    local delta=finite(item:getUseDelta())
    if not before or not delta or delta<=0 or delta>1 or before+EPSILON<delta
        or math.abs(delta-source.delta)>EPSILON then return false,'Material depleted or changed.'end
    item:Use()
    sendItemStats(item)
    local after=finite(item:getCurrentUsesFloat())
    if not after or math.abs((before-after)-delta)>EPSILON then error('Route material consumption requires inspection')end
    return true
end

function Work.progress(square)
    local snapshot,err=Routes.snapshot(square)
    if not snapshot then return nil,err end
    local project=snapshot.project
    return {routeId=snapshot.route.routeId,status=project.status,workCompleted=project.workCompleted,
        workRequired=project.workRequired,materials=project.materials,requirements=project.requirements}
end

function Work.plan(player,square,op,routeId)
    if not Hand.enabled()or not player or player:isDead()or player:getVehicle()then return false,'An active builder on foot is required.'end
    if not square or square:getZ()~=0 or not square:getFloor()then return false,'A ground-floor tile is required.'end
    local reachable,reason=Hand.squareReachable(player,square)
    if not reachable then return false,reason end
    if SafeHouse and not SafeHouse.isSafehouseAllowInteract(square,player)then return false,'You cannot build in this safehouse.'end
    if square.isFree and not square:isFree(false)then return false,'Clear the construction tile first.'end
    local tool=Hand.findTool(player)
    if op=='routeStart'then
        local route=Routes.get(routeId)
        if route and route.requiresMachine then return false,'This route requires construction machinery.'end
        if not route or not tool then return false,'A shovel or digging tool and route design are required.'end
        if API.Projects.snapshot(square)then return false,'This tile already has a project.'end
        local store=API.EarthworkPersistence and API.EarthworkPersistence.getStore()
        if store and API.EarthworkJobs.jobAtCell(store,square:getX(),square:getY(),square:getZ())then
            return false,'This tile already has an excavation job.'
        end
        local allowed,err=API.validateProject(route.projectType,{square=square,actor=player})
        if not allowed then return false,err end
        return true,{tool=tool,op=op,volumeType=routeId}
    end
    local snapshot,err=Routes.snapshot(square)
    if not snapshot then return false,err end
    local definition=Routes.get(snapshot.route.routeId)
    if definition and definition.requiresMachine then return false,'This route requires construction machinery.'end
    if snapshot.project.materialRecovery or snapshot.project.worldRecovery then return false,'This route requires inspection before more work.'end
    if snapshot.project.status~='active'and snapshot.project.status~='ready'then return false,'This route is not available for construction.'end
    if op=='routeSupply'then
        local source=material(player,snapshot.project.requirements,snapshot.project.materials)
        if not source then return false,'Carry a usable gravel bag or concrete bucket required by this route.'end
        return true,{op=op,source=source}
    elseif op=='routeWork'and tool then return true,{op=op,tool=tool}end
    return false,'A digging tool is required.'
end
return Work
