local API=require 'groundWorks/API'
local Terrain=require 'groundWorks/CavityTerrain'
local Boundary={KEY='groundWorks.boundary.v1',SUPPORT_KEY='groundWorks.support.v1'}
-- These are the native unfinished-pool retaining faces, not underground fill
-- cubes. Sprite geometry determines the N/W side; no shared sprite is edited.
Boundary.EARTH={north='walls_commercial_03_49',west='walls_commercial_03_48'}
Boundary.FRAME={north='carpentry_02_101',west='carpentry_02_100'}
local function authority()return not isClient()end
local function marker(object)
    local md=object and object:getModData()
    return md and md[Boundary.KEY]
end
local function edgeObjects(square,north)
    local result={}
    if square then for i=0,square:getObjects():size()-1 do
        local object=square:getObjects():get(i);local md=marker(object)
        if md and md.north==north then result[#result+1]=object end
    end end
    return result
end
local function open(square)
    if not square then return false end
    local md=square:getModData()['groundWorks.cavity.v1']
    return md and md.status=='created'and(md.role=='cavity'or md.role=='shaft')and not md.sealed
end
function Boundary.place(edge,kind,operationId)
    if not authority()then return nil,'non-authority'end
    local square,err=Terrain.prepare(edge.x,edge.y,edge.z)
    if not square then return nil,err end
    for _,object in ipairs(edgeObjects(square,edge.north))do
        local md=marker(object)
        if md.kind==kind or md.kind=='frame'then return object,false end
    end
    local sprite=(kind=='frame'and Boundary.FRAME or Boundary.EARTH)[edge.north and'north'or'west']
    if not getSprite(sprite)then return nil,'Native perimeter sprite is unavailable.'end
    local object
    if kind=='frame'then
        object=IsoThumpable.new(getCell(),square,sprite,edge.north,{})
        object:setName('WoodenWallFrame');object:setCanPassThrough(false)
        object:setIsThumpable(true);object:setIsDismantable(true)
        object:setMaxHealth(150);object:setHealth(150)
        object:setCanBarricade(true);object:setBlockAllTheSquare(false)
        object:getModData()['need:Base.Plank']='2';object:getModData()['need:Base.Nails']='2'
    else
        object=IsoObject.getNew(square,sprite,'Excavation retaining face',false)
    end
    if not object then return nil,'Perimeter object creation failed.'end
    object:getModData()[Boundary.KEY]={north=edge.north,kind=kind,operationId=operationId}
    local replaced={}
    local ok,why=pcall(function()
        if kind=='frame'then
            square:AddSpecialObject(object)
            if isServer()then object:transmitCompleteItemToClients()end
        else square:transmitAddObjectToSquare(object,-1)end
        assert(object:getObjectIndex()>=0,'Perimeter object was not added.')
        -- Replace only our old earth face. Never claim or remove another mod's wall.
        if kind=='frame'then
            for _,old in ipairs(edgeObjects(square,edge.north))do
                if old~=object and marker(old).kind=='earth'then
                    replaced[#replaced+1]=old;square:transmitRemoveItemFromSquare(old)
                end
            end
        end
        assert(Terrain.refresh(square,true)~=false,'Perimeter refresh failed.')
    end)
    if not ok then
        local restored=pcall(function()
            if object:getObjectIndex()>=0 then square:transmitRemoveItemFromSquare(object)end
            for _,old in ipairs(replaced)do
                if old:getObjectIndex()<0 then square:transmitAddObjectToSquare(old,-1)end
            end
        end)
        return nil,'Perimeter placement failed: '..tostring(why)..(restored and''or' (inspection required)')
    end
    return object,true
end
function Boundary.removeEarth(edge)
    if not authority()then return false end
    local square=getCell():getGridSquare(edge.x,edge.y,edge.z)
    for _,object in ipairs(edgeObjects(square,edge.north))do
        if marker(object).kind=='earth'then square:transmitRemoveItemFromSquare(object)end
    end
    if square then Terrain.refresh(square,true)end
    return true
end
function Boundary.reconcileColumn(surface)
    if not authority()then return false,'non-authority'end
    local receipt=API.Cavity.inspect(surface)
    if not receipt or receipt.status~='created'or receipt.sealed then return true end
    local cell=getCell();local x,y=surface:getX(),surface:getY()
    for z=-1,receipt.cavity.z,-1 do
        local square=cell:getGridSquare(x,y,z)
        if square then
            local edges={
                {x=x,y=y,z=z,north=true,nx=x,ny=y-1},
                {x=x,y=y,z=z,north=false,nx=x-1,ny=y},
                {x=x,y=y+1,z=z,north=true,nx=x,ny=y+1},
                {x=x+1,y=y,z=z,north=false,nx=x+1,ny=y},
            }
            for _,edge in ipairs(edges)do
                local neighbor=cell:getGridSquare(edge.nx,edge.ny,z)
                if open(neighbor)then Boundary.removeEarth(edge)
                elseif not neighbor or not neighbor:getRoom()then
                    local object,why=Boundary.place(edge,'earth',receipt.operationId)
                    if not object then return false,why end
                end
            end
        end
    end
    Terrain.synchronizeView(x,y,receipt.cavity.z)
    Terrain.refreshView();return true
end
function Boundary.clearColumn(surface)
    if not authority()then return false end
    local receipt=API.Cavity.inspect(surface)
    if not receipt or not receipt.cells then return true end
    local x,y=surface:getX(),surface:getY()
    for _,target in ipairs(receipt.cells)do
        for _,edge in ipairs({{x=x,y=y,z=target.z,north=true},{x=x,y=y,z=target.z,north=false},
            {x=x,y=y+1,z=target.z,north=true},{x=x+1,y=y,z=target.z,north=false}})do
            Boundary.removeEarth(edge)
        end
    end
    return true
end
-- Closing one column changes the exposed perimeter of its four neighbors.
-- Run after the closed column's cavity markers have been removed, otherwise
-- open() would still treat the filled column as part of the shared cavity.
function Boundary.reconcileNeighbors(surface)
    if not authority()then return false,'non-authority'end
    local x,y=surface:getX(),surface:getY()
    for _,offset in ipairs({{0,-1},{-1,0},{0,1},{1,0}})do
        local neighbor=getCell():getGridSquare(x+offset[1],y+offset[2],0)
        if neighbor then
            local receipt=API.Cavity.inspect(neighbor)
            if receipt and receipt.status=='created'and not receipt.sealed then
                local ok,why=Boundary.reconcileColumn(neighbor)
                if not ok then return false,why end
            end
        end
    end
    return true
end
return Boundary
