local groundWorks=require "groundWorks/API"
local SurfaceMutation={}

local function call(object,method,...)
    local ok,fn=pcall(function()return object and object[method]end)
    if not ok or type(fn)~="function"then return nil,false end
    local called,value=pcall(fn,object,...);return called and value or nil,called
end
local function spriteName(floor)
    local sprite,ok=call(floor,"getSprite");if not ok or not sprite then return nil end
    local name,got=call(sprite,"getName");return got and type(name)=="string"and name~=""and name or nil
end
local function authoritative()
    return not(type(isClient)=="function"and isClient()==true and not(type(isServer)=="function"and isServer()==true))
end
local function resolveSprite(name,resolver)
    if type(resolver)=="function"then
        local ok,value=pcall(resolver,name);return ok and value or nil
    end
    if type(getSprite)=="function"then
        local ok,value=pcall(getSprite,name);return ok and value or nil
    end
    return nil
end
local function transmit(floor)
    if type(isServer)=="function"and isServer()==true then
        local _,ok=call(floor,"transmitUpdatedSpriteToClients");return ok
    end
    -- Single-player persistence follows the native floor object. Clients are
    -- rejected above; they never request an unvalidated sprite mutation here.
    return true
end

function SurfaceMutation.inspect(square)
    if not square then return nil,"square required"end
    local floor,ok=call(square,"getFloor");if not ok or not floor then return nil,"existing floor required"end
    local name=spriteName(floor);if not name then return nil,"current floor sprite identity unavailable"end
    return {floor=floor,spriteName=name}
end

function SurfaceMutation.replaceFloorSprite(square,targetName,options)
    if not authoritative()then return false,"non-authority"end
    if type(targetName)~="string"or targetName==""or #targetName>128 or targetName:find("[%c]",1)then
        return false,"valid target sprite name required"
    end
    options=type(options)=="table"and options or{}
    local before,err=SurfaceMutation.inspect(square);if not before then return false,err end
    if before.spriteName==targetName then return true,{changed=false,before=before.spriteName,after=targetName}end
    local target=resolveSprite(targetName,options.resolveSprite);if not target then return false,"target sprite unavailable"end
    local original=resolveSprite(before.spriteName,options.resolveSprite);if not original then return false,"rollback sprite unavailable"end
    local _,setOk=call(before.floor,"setSprite",target)
    if not setOk or spriteName(before.floor)~=targetName then
        call(before.floor,"setSprite",original)
        local restored=spriteName(before.floor)==before.spriteName
        return false,restored and"floor sprite write failed; rollback verified"or"floor sprite write failed; rollback unverified",
            {committed=false,rolledBack=restored,before=before.spriteName,target=targetName,current=spriteName(before.floor)}
    end
    local _,recalcOk=call(square,"RecalcAllWithNeighbours",true)
    if options.requireRecalculation==true and not recalcOk then
        call(before.floor,"setSprite",original);call(square,"RecalcAllWithNeighbours",true)
        local restored=spriteName(before.floor)==before.spriteName
        return false,restored and"floor recalculation unavailable; rollback verified"or"floor recalculation unavailable; rollback unverified",
            {committed=false,rolledBack=restored,before=before.spriteName,target=targetName,current=spriteName(before.floor)}
    end
    if not transmit(before.floor)then
        return false,"floor changed; replication outcome uncertain",
            {committed=true,replicationUncertain=true,before=before.spriteName,after=targetName,recalculated=recalcOk}
    end
    return true,{changed=true,committed=true,before=before.spriteName,after=targetName,
        replicationRequested=type(isServer)=="function"and isServer()==true,recalculated=recalcOk}
end

groundWorks.SurfaceMutation=SurfaceMutation
groundWorks.replaceFloorSprite=SurfaceMutation.replaceFloorSprite
return SurfaceMutation
