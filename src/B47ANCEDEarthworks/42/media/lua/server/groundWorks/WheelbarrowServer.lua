local Barrow=require 'groundWorks/Wheelbarrow'

-- Server-authoritative wheelbarrow commands. Clients request spawn/grab/
-- release/remove; the server performs the native mutation and reserves the
-- operator through the optional itjustWorks heavy-object transaction.
local Server={MODULE='groundWorks',installed=false}

local function respond(player,ok,message)
    if isServer()then sendServerCommand(player,Server.MODULE,'wheelbarrowResult',{ok=ok==true,message=tostring(message or'')})end
end

local function reserve(player,object)
    if getActivatedMods():contains('itjustWorks')then
        local Transactions=require 'groundWorks/WheelbarrowTransactions'
        local id='barrow.'..tostring(getTimestampMs())
        local ok,reason=Transactions.advance(player,object,'reserve',id)
        if not ok then return false,reason end
        ok,reason=Transactions.advance(player,object,'start',id)
        if not ok then Transactions.advance(player,object,'cancel',id);return false,reason end
        return true,id
    end
    return true,nil
end

local function release(player,object,id)
    if object:getModData().wheelbarrowOperator then object:getModData().wheelbarrowOperator=nil end
    if getActivatedMods():contains('itjustWorks')then
        local Transactions=require 'groundWorks/WheelbarrowTransactions'
        if id then pcall(Transactions.advance,player,object,'complete',id)end
    end
    return true
end

function Server.onClientCommand(module,command,player,args)
    if module~=Server.MODULE then return end
    if command=='wheelbarrowSpawn'then
        local square=player and player:getSquare()
        local object,err=Barrow.spawn(square)
        if not object then respond(player,false,err);return end
        object:getModData().wheelbarrowOperator=nil
        respond(player,true,'Wheelbarrow spawned.')
    elseif command=='wheelbarrowGrab'then
        local object=Barrow.nearby(player)
        if not object then respond(player,false,'Wheelbarrow not found.');return end
        local allowed,why=Barrow.canHandle(player,object)
        if not allowed then respond(player,false,why);return end
        if player:getDragObject()and player:getDragObject()~=object then respond(player,false,'Release the object you are already moving.');return end
        local ok,id,reason=reserve(player,object)
        if not ok then respond(player,false,reason or 'Wheelbarrow is in use.');return end
        player:setDragObject(object)
        respond(player,player:getDragObject()==object,'Pushing wheelbarrow.')
    elseif command=='wheelbarrowRelease'then
        local object=player and player:getDragObject()
        if object and Barrow.isWheelbarrow(object)then
            release(player,object,nil)
            player:setDragObject(nil)
        end
        respond(player,true,'Released wheelbarrow.')
    elseif command=='wheelbarrowRemove'then
        local object=Barrow.nearby(player)or player:getDragObject()
        local removed,err=Barrow.remove(object)
        respond(player,removed==true,removed==true and'Wheelbarrow removed.'or tostring(err))
    end
end

function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnClientCommand or type(events.OnClientCommand.Add)~='function'then return false,'OnClientCommand unavailable'end
    events.OnClientCommand.Add(Server.onClientCommand);Server.installed=true;return true
end
return Server
