local Wheelbarrow=require "groundWorks/Wheelbarrow"

local Client={controlled=nil}

local function player()return type(rawget(_G,"getPlayer"))=="function"and getPlayer()or nil end

local function nearbyWheelbarrow(character,radius)
    local square=character and character:getSquare()or nil
    local cell=type(rawget(_G,"getCell"))=="function"and getCell()or nil
    if not square or not cell then return nil end
    radius=radius or 2
    for x=square:getX()-radius,square:getX()+radius do for y=square:getY()-radius,square:getY()+radius do
        local candidate=cell:getGridSquare(x,y,square:getZ())
        local moving=candidate and candidate:getMovingObjects()or nil
        if moving then for index=0,moving:size()-1 do
            local object=moving:get(index)
            if Wheelbarrow.isWheelbarrow(object)then return object end
        end end
    end end
    return nil
end

function Client.grab(character,object)
    character=character or player()
    if isClient()then
        sendClientCommand(character,'groundWorks','wheelbarrowGrab',{})
        return true
    end
    object=object or nearbyWheelbarrow(character)
    if not character or not Wheelbarrow.isWheelbarrow(object)then return false,"wheelbarrow not found"end
    local allowed,why=Wheelbarrow.canHandle(character,object)
    if not allowed then return false,why end
    if character:getDragObject()and character:getDragObject()~=object then return false,"player already controls a moving object"end
    if getActivatedMods():contains('itjustWorks')then
        local Transactions=require 'groundWorks/WheelbarrowTransactions'
        Client.sequence=(Client.sequence or 0)+1
        local id='barrow.'..getTimestampMs()..'.'..Client.sequence
        local ok,reason=Transactions.advance(character,object,'reserve',id)
        if not ok then return false,reason end
        ok,reason=Transactions.advance(character,object,'start',id)
        if not ok then Transactions.advance(character,object,'cancel',id);return false,reason end
        Client.transaction=id;Client.controlled=object;Client.character=character
        return true
    end
    character:setDragObject(object);Client.controlled=object;Client.character=character
    return character:getDragObject()==object
end

function Client.release(character)
    character=character or player();if not character then return false,"player unavailable"end
    if isClient()then
        sendClientCommand(character,'groundWorks','wheelbarrowRelease',{})
        return true
    end
    if Client.transaction and Client.controlled then
        local Transactions=require 'groundWorks/WheelbarrowTransactions'
        local ok=Transactions.advance(character,Client.controlled,'complete',Client.transaction)
        if not ok then Transactions.advance(character,Client.controlled,'cancel',Client.transaction)end
        Client.transaction=nil
    end
    if character:getDragObject()==Client.controlled or Wheelbarrow.isWheelbarrow(character:getDragObject())then
        character:setDragObject(nil)
    end
    Client.controlled=nil;Client.character=nil;return true
end

local function status()
    local character=player();local object=nearbyWheelbarrow(character)or Client.controlled
    if not object then print("[groundWorks wheelbarrow] not found");return nil end
    local square=object:getSquare();local container=object:getContainer();local load=Wheelbarrow.getLoad(object)
    local result={nativeClass=object:getObjectName(),x=object:getX(),y=object:getY(),z=object:getZ(),
        square=square and(square:getX()..","..square:getY()..","..square:getZ())or"nil",
        identified=Wheelbarrow.isWheelbarrow(object),container=container~=nil,
        itemCount=container and container:getItems():size()or 0,controllerActive=character and character:getDragObject()==object,
        collided=type(object.isCollided)=="function"and object:isCollided()or nil,
        grossWeight=load.grossWeight}
    for key,value in pairs(result)do print("[groundWorks wheelbarrow] "..key.."="..tostring(value))end
    return result
end

function groundWorksTestWheelbarrowSpawn()
    if isClient()then sendClientCommand(player(),'groundWorks','wheelbarrowSpawn',{});return true end
    local character=player();local square=character and character:getSquare()or nil
    local object,err=Wheelbarrow.spawn(square)
    print(object and"[groundWorks wheelbarrow] spawned"or("[groundWorks wheelbarrow] spawn failed: "..tostring(err)))
    return object,err
end
function groundWorksTestWheelbarrowStatus()return status()end
function groundWorksTestWheelbarrowFill()
    if isClient()or not getDebug or not getDebug()then return false,'Single-player debug probe only.'end
    local object=nearbyWheelbarrow(player())or Client.controlled
    local container=object and object:getContainer()or nil
    if not container then return false,"container unavailable"end
    local item=container:AddItem("Base.Dirtbag")
    return item~=nil,item
end
function groundWorksTestWheelbarrowRemove()
    if isClient()then sendClientCommand(player(),'groundWorks','wheelbarrowRemove',{});return true end
    local object=nearbyWheelbarrow(player())or Client.controlled
    Client.release();return Wheelbarrow.remove(object)
end
function groundWorksTestWheelbarrowStart()return Client.grab(player(),nearbyWheelbarrow(player()))end
function groundWorksTestWheelbarrowRelease()return Client.release()end

local function addMenu(playerIndex,context)
    local character=getSpecificPlayer(playerIndex);if not character then return end
    local object=nearbyWheelbarrow(character)
    if character:getDragObject()and Wheelbarrow.isWheelbarrow(character:getDragObject())then
        context:addOption("Release Wheelbarrow",character,Client.release)
    elseif object then context:addOption("Push Wheelbarrow",character,Client.grab,object)end
end

if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(addMenu)end
if Events and Events.OnPlayerUpdate then Events.OnPlayerUpdate.Add(function(character)
    if Client.controlled and character==Client.character then
        local allowed=Wheelbarrow.canHandle(character,Client.controlled)
        if not allowed or character:getDragObject()~=Client.controlled then Client.release(character)end
    end
end)end
if Events and Events.OnGameStart then Events.OnGameStart.Add(function()
    if isClient()then return end
    local objects=getCell():getPushableObjectList()
    for i=0,math.min(objects:size(),4096)-1 do
        local object=objects:get(i)
        if Wheelbarrow.isWheelbarrow(object)then object:getModData().wheelbarrowOperator=nil end
    end
end)end
if Events and Events.OnServerCommand then Events.OnServerCommand.Add(function(module,command,args)
    if module~='groundWorks'or command~='wheelbarrowResult'then return end
    local character=getPlayer()
    if character and type(args)=='table'and args.message then character:Say(tostring(args.message))end
end)end
return Client
