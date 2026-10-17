local API=require "groundWorks/Load"
local Experiment=API.ExcavationExperiment
local Engine=require "groundWorks/CavityEngine"
local Server={MODULE="groundWorks",CREATE="excavationExperiment",STATUS="excavationExperimentStatus",installed=false}

local function call(object,method,...)
    if not object then return nil,false end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil,false end
    local called,result=pcall(fn,object,...);return result,called
end
local function debugAllowed(player)
    if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then return true end
    local access,ok=call(player,"getAccessLevel");return ok and tostring(access):lower()=="admin"
end
local function surfaceFor(player,args)
    local square=player and player:getCurrentSquare()or nil;if not square then return nil end
    if type(args)~="table"or tonumber(args.x)~=square:getX()or tonumber(args.y)~=square:getY()or tonumber(args.z)~=square:getZ()then return nil end
    return square
end
function Server.onClientCommand(module,command,player,args)
    if module~=Server.MODULE or(command~=Server.CREATE and command~=Server.STATUS)then return end
    if not debugAllowed(player)then print("[groundWorks][ExcavationExperiment] rejected: debug/admin required");return end
    local surface=surfaceFor(player,args);if not surface then print("[groundWorks][ExcavationExperiment] rejected: stand on the exact target square");return end
    local adapter=Engine.adapter()
    if command==Server.STATUS then
        local status,err=Experiment.verifyCurrent(surface,adapter)
        print("[groundWorks][ExcavationExperiment] status="..tostring(status and status.status or err)..
            " squareResolved="..tostring(status and status.squareResolved).." floorResolved="..tostring(status and status.floorResolved)..
            " geometryResolved="..tostring(status and status.geometryResolved).." requiresInspection="..tostring(status and status.requiresInspection));return
    end
    local ok,result,details=Experiment.execute(surface,args.operationId,adapter,{volumeType="groundWorks.openPit",experimental=true,actor=player})
    local receipt=type(result)=="table"and result or details
    print("[groundWorks][ExcavationExperiment] ok="..tostring(ok).." result="..tostring(type(result)=="string"and result or receipt and receipt.status))
end
function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnClientCommand or type(events.OnClientCommand.Add)~="function"then return false,"OnClientCommand unavailable"end
    events.OnClientCommand.Add(Server.onClientCommand);Server.installed=true;return true
end
return Server
