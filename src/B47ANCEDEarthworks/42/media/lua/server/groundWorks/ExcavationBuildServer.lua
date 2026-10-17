local API=require 'groundWorks/Load'
local Build=require 'groundWorks/ExcavationBuild'
local Boundary=require 'groundWorks/CavityBoundary'
local Terrain=require 'groundWorks/CavityTerrain'
local Engine=require 'groundWorks/CavityEngine'
local Server={}
local machineValidators={}
function Server.registerMachineValidator(providerId,validator)
    assert(type(providerId)=='string'and type(validator)=='function','Provider ID and machine validator required.')
    assert(not machineValidators[providerId],'Machine validator already registered.')
    machineValidators[providerId]=validator
end
local function validMachine(player,providerId,spec)
    local vehicle=player and player:getVehicle()
    if not vehicle or vehicle:getDriver()~=player then return false,'Operate the machine from its driver seat.'end
    local validator=machineValidators[providerId]
    if validator then
        local ok,allowed,why=pcall(validator,player,vehicle,spec)
        return ok and allowed==true,why or'The machine rejected this footprint.'
    end
    local cat=rawget(_G,'CATConstruction')
    local definition=cat and cat.getVehicleDefinition and cat.getVehicleDefinition(vehicle)
    if not definition or API.providerIdForVehicle(definition)~=providerId then return false,'The operated vehicle does not match the excavation provider.'end
    local reach=tonumber(definition.reach)or 0
    local plan=Build.plan(spec)
    for _,target in ipairs(plan and plan.cells or{})do
        local dx,dy=vehicle:getX()-target.x-0.5,vehicle:getY()-target.y-0.5
        if dx*dx+dy*dy>reach*reach then return false,'Part of the footprint is beyond this machine\'s reach.'end
    end
    return true
end
local function validId(id)return type(id)=='string'and#id>0 and#id<=80 and not id:find('[%c]')end
local function store()return API.EarthworkPersistence.getStore()end
local function sync()if isServer()then ModData.transmit(API.EarthworkPersistence.STORE_KEY)end end
local function deepCopy(v)
    if type(v)~='table'then return v end
    local r={};for k,value in pairs(v)do r[k]=deepCopy(value)end;return r
end
local function remember(id,ok,message)
    local s=store();s.buildReceipts=s.buildReceipts or{}
    s.buildReceipts[#s.buildReceipts+1]={id=id,ok=ok,message=message}
    while #s.buildReceipts>256 do table.remove(s.buildReceipts,1)end
    sync();return ok,message
end
local function previous(id)
    for _,r in ipairs(store().buildReceipts or{})do if r.id==id then return r end end
end
Server.check=Build.check
local function removeNewColumns(created)
    local verified=true;local s=store()
    for i=#created,1,-1 do
        local c=created[i]
        Boundary.clearColumn(c.surface)
        local receipt=API.Cavity.inspect(c.surface)
        local closed=receipt and receipt.status=='clear'or API.Cavity.close(c.surface,Engine.adapter())
        if closed then
            s.jobs[c.jobId]=nil
            s.cellOwners[c.surface:getX()..':'..c.surface:getY()..':0']=nil
        else verified=false end
    end
    return verified
end
local function excavate(plan,player,id)
    local created={};local s=store()
    local ok,why=pcall(function()
        for index,target in ipairs(plan.cells)do
            local surface=getCell():getGridSquare(target.x,target.y,0)
            local receipt=API.Cavity.inspect(surface)
            if not receipt or receipt.status~='created'then
                local jobId='build:'..id..':'..index
                local done,result=API.EarthworkJobs.create(s,{
                    id=jobId,type=plan.volumeType,targetDepth=plan.depth,
                    cells={{x=target.x,y=target.y,z=0}},workRequired=20*plan.depth,
                    fillWorkRequired=20*plan.depth,soilVolume=plan.depth,createdBy=player:getUsername(),
                    worldAgeHours=getGameTime():getWorldAgeHours(),
                },id..':job:'..index)
                assert(done,tostring(result))
                created[#created+1]={surface=surface,jobId=jobId}
                assert(API.EarthworkJobs.applyWork(s,jobId,'excavate',20*plan.depth,id..':work:'..index,'groundWorks.cavity.manual.v1',{}))
                local job,opened=require('groundWorks/MachineGeometry').excavate(surface,s,jobId,id..':'..index,plan.volumeType,player,
                    {preserveSurface=plan.volumeType=='groundWorks.basement'and(surface:getRoom()~=nil or surface:getBuilding()~=nil)})
                assert(opened,'A footprint column could not be excavated.')
            end
        end
        -- Final pass clears regenerated native dirt and joins adjacent columns.
        for _,target in ipairs(plan.cells)do
            local surface=getCell():getGridSquare(target.x,target.y,0)
            assert(Boundary.reconcileColumn(surface))
            for z=-1,plan.z,-1 do
                local square=getCell():getGridSquare(target.x,target.y,z)
                assert(Terrain.clearUnderground(square))
                Terrain.refresh(square,true)
            end
        end
    end)
    if not ok then
        local rolled=removeNewColumns(created)
        return false,tostring(why)..(rolled and' (new columns restored)'or' (world inspection required)'),created
    end
    return true,created
end
function Server.perform(player,spec)
    if isClient()then return false,'non-authority'end
    if not store()or not spec or not validId(spec.operationId)then return false,'A loaded store and bounded operation ID are required.'end
    local id=spec.operationId;local prior=previous(id)
    if prior then return prior.ok,prior.message end
    local allowed,details=Build.check(player,spec)
    if not allowed then return false,details end
    local consumed={};local newFrames={};local priorEarth={};local priorSupport={};local created
    local seenEarth={}
    for _,target in ipairs(details.plan.cells)do for z=-1,spec.z,-1 do
        for _,point in ipairs({{target.x,target.y},{target.x+1,target.y},{target.x,target.y+1}})do
            local owner=getCell():getGridSquare(point[1],point[2],z)
            if owner then for i=0,owner:getObjects():size()-1 do
                local old=owner:getObjects():get(i);local md=old:getModData()[Build.WALL_KEY]
                if md and md.kind=='earth'and not seenEarth[old]then
                    seenEarth[old]=true;priorEarth[#priorEarth+1]={object=old,square=owner}
                end
            end end
        end
    end end
    -- Materials remain recoverable as the exact objects until all geometry has
    -- committed. No client request can skip the shared native timed action.
    local ok,why=pcall(function()
        for material,count in pairs(details.materials)do
            for index=1,count do
                local item=details.inventory[material][index];local container=item:getContainer()
                local world=item:getWorldItem();local square=world and world:getSquare()
                -- Ground items may also report the native virtual floor
                -- container. Removing from that container leaves the actual
                -- world item behind, so world ownership takes precedence.
                if world and square then
                    assert(square:getWorldObjects():contains(world),'A ground material moved.')
                    consumed[#consumed+1]={item=item,square=square,world=world}
                    square:transmitRemoveItemFromSquare(world)
                    assert(not square:getWorldObjects():contains(world),'Ground material consumption failed.')
                elseif container then
                    assert(container:contains(item),'A required material moved.')
                    consumed[#consumed+1]={item=item,container=container}
                    if isServer()then sendRemoveItemFromContainer(container,item)end
                    container:Remove(item)
                    assert(not container:contains(item),'Material consumption failed.')
                else
                    error('A required material moved.')
                end
            end
        end
        local dug,result=excavate(details.plan,player,id)
        assert(dug,result);created=result
        for _,edge in ipairs(details.edges)do
            local object,isNew=Boundary.place(edge,'frame',id)
            assert(object,tostring(isNew))
            if isNew then newFrames[#newFrames+1]=object end
        end
        -- A support record is valid only while every recorded frame survives.
        for _,target in ipairs(details.plan.cells)do
            for z=-1,spec.z,-1 do
                local square=getCell():getGridSquare(target.x,target.y,z)
                priorSupport[#priorSupport+1]={square=square,value=deepCopy(square:getModData()[Build.SUPPORT_KEY])}
                local edges={}
                for _,edge in ipairs(details.edges)do if edge.z==z then edges[#edges+1]=deepCopy(edge)end end
                square:getModData()[Build.SUPPORT_KEY]={secured=true,operationId=id,presetId=spec.presetId,edges=edges}
                square:transmitModdata()
            end
        end
        Terrain.synchronizeView(spec.x,spec.y,spec.z)
        Terrain.refreshView()
    end)
    if not ok then
        local recoveryErrors={}
        local function recover(action)
            local worked,reason=pcall(action)
            if not worked then recoveryErrors[#recoveryErrors+1]=tostring(reason)end
        end
        for i=#newFrames,1,-1 do
            local object=newFrames[i]
            recover(function()if object:getSquare()then object:getSquare():transmitRemoveItemFromSquare(object)end end)
        end
        for _,entry in ipairs(priorSupport)do
            entry.square:getModData()[Build.SUPPORT_KEY]=entry.value
            pcall(function()entry.square:transmitModdata()end)
        end
        if created then recover(function()assert(removeNewColumns(created),'New-column restoration needs inspection.')end)end
        for _,entry in ipairs(priorEarth)do
            -- Reinsert only the exact pre-existing retaining face removed by
            -- this transaction; a new column rollback needs no retained face.
            recover(function()
                if entry.object:getObjectIndex()<0 then
                    entry.square:transmitAddObjectToSquare(entry.object,-1)
                    Terrain.refresh(entry.square,true)
                end
            end)
        end
        for _,entry in ipairs(consumed)do
            recover(function()
                if entry.square then
                    if not entry.square:getWorldObjects():contains(entry.world)then
                        entry.square:AddWorldInventoryItem(entry.item,0.5,0.5,0)
                    end
                elseif not entry.container:contains(entry.item)then
                    entry.container:AddItem(entry.item)
                    if isServer()then sendAddItemToContainer(entry.container,entry.item)end
                end
            end)
        end
        return remember(id,false,'Construction stopped; '..(#recoveryErrors==0 and'materials returned. 'or'recovery needs inspection. ')..tostring(why))
    end
    return remember(id,true,'Excavation framed and secured.')
end

-- Server-side vehicle integration. Machine work opens the same native columns
-- and earns loose soil, but never supplies framing or marks a square secure.
function Server.beginMachine(player,spec,providerId,id)
    if isClient()or not store()or not validId(id)then return false,'Invalid machine operation.'end
    local allowed,details=Build.check(player,spec,{machine=true})
    if not allowed then return false,details end
    local machineOk,machineWhy=validMachine(player,providerId,spec)
    if not machineOk then return false,machineWhy end
    local provider=API.EarthworkProviders.get(providerId)
    if not provider or provider.kind~='machine'or not API.EarthworkProviders.isAvailable(providerId)then return false,'A compatible active machine provider is required.'end
    if not provider.capabilities.excavate then return false,'This machine cannot excavate.'end
    if details.missingLayers<=0 then return false,'This footprint is already excavated; enter it to frame it.'end
    local s=store();s.excavationProjects=s.excavationProjects or{}
    if s.excavationProjects[id]then
        local existing=s.excavationProjects[id];local p=existing.spec
        if existing.actor~=player:getUsername()or existing.providerId~=providerId or not p
            or p.x~=spec.x or p.y~=spec.y or p.z~=spec.z or p.presetId~=spec.presetId or p.direction~=spec.direction then
            return false,'Machine project identity conflict.'
        end
        return existing.status~='needs_inspection',deepCopy(existing)
    end
    local count=0;for _ in pairs(s.excavationProjects)do count=count+1 end
    if count>=64 then return false,'Machine excavation project limit reached.'end
    local project={id=id,spec={presetId=spec.presetId,x=spec.x,y=spec.y,z=spec.z,direction=spec.direction},
        providerId=providerId,actor=player:getUsername(),workRequired=details.missingLayers*20,workCompleted=0,
        status='active',operations={}}
    s.excavationProjects[id]=project;sync();return true,deepCopy(project)
end
function Server.applyMachineWork(player,id,amount,operationId)
    if isClient()or not store()or not validId(operationId)then return false,'Invalid machine operation.'end
    local project=store().excavationProjects and store().excavationProjects[id]
    if not project or project.actor~=player:getUsername()then return false,'Machine project unavailable.'end
    if project.operations[operationId]then return project.status~='needs_inspection',deepCopy(project)end
    if project.status~='active'then return false,'Machine project is not active.'end
    local allowed,details=Build.check(player,project.spec,{machine=true})
    if not allowed then return false,details end
    local machineOk,machineWhy=validMachine(player,project.providerId,project.spec)
    if not machineOk then return false,machineWhy end
    local authorization,why=API.EarthworkProviders.authorize(project.providerId,'excavate',amount,{actor=player:getUsername(),projectId=id})
    if not authorization then return false,why end
    project.workCompleted=math.min(project.workRequired,project.workCompleted+authorization.amount)
    project.operations[operationId]=true
    if project.workCompleted>=project.workRequired then
        local dug,result=excavate(details.plan,player,id)
        if not dug then project.status='needs_inspection';project.reason=result;sync();return false,result end
        project.status='excavated_unsecured'
    end
    sync();return true,deepCopy(project)
end
API.ExcavationBuildServer=Server
return Server
