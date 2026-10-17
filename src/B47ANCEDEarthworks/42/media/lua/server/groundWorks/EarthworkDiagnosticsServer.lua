local API=require "groundWorks/Load"
local Server={MODULE="groundWorks",COMMAND="earthworkStatus",installed=false}

local function call(object,method)
    if not object then return nil,false end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil,false end
    local called,result=pcall(fn,object);return result,called
end
local function debugAllowed(player)
    if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then return true end
    local access,ok=call(player,"getAccessLevel");return ok and tostring(access):lower()=="admin"
end
local function statuses(values)
    local names={};for name in pairs(values)do names[#names+1]=name end;table.sort(names)
    local result={};for _,name in ipairs(names)do result[#result+1]=name.."="..tostring(values[name])end;return table.concat(result,",")
end
function Server.onClientCommand(module,command,player)
    if module~=Server.MODULE or command~=Server.COMMAND then return end
    if not debugAllowed(player)then print("[groundWorks][Earthworks] rejected: debug/admin required");return end
    local store,storeErr=API.EarthworkPersistence.getStore();if not store then print("[groundWorks][Earthworks] unavailable: "..tostring(storeErr));return end
    local audit=API.EarthworkIntegrity.audit(store);local summary,summaryErr=API.EarthworkDiagnostics.summary(store)
    if not summary then print("[groundWorks][Earthworks] unavailable: "..tostring(summaryErr));return end
    print("[groundWorks][Earthworks] integrity="..tostring(audit.valid).." errors="..tostring(audit.errorCount)..
        " jobs="..tostring(summary.jobs).." reservedCells="..tostring(summary.reservedCells).." stockpiles="..tostring(summary.stockpiles)..
        " looseSoil="..tostring(summary.looseSoil).." stockpiledSoil="..tostring(summary.stockpiledSoil)..
        " reservedBackfill="..tostring(summary.reservedBackfillSoil).." statuses="..statuses(summary.statuses))
end
function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnClientCommand or type(events.OnClientCommand.Add)~="function"then return false,"OnClientCommand unavailable"end
    events.OnClientCommand.Add(Server.onClientCommand);Server.installed=true;return true
end
return Server
