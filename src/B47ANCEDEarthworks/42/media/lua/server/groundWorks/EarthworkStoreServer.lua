local API=require "groundWorks/Load"
local Persistence=API.EarthworkPersistence
local Server={installed=false}

function Server.initialize()
    if not ModData or type(ModData.getOrCreate)~="function"then return false,"GlobalModData unavailable"end
    return Persistence.attachStore(ModData.getOrCreate(Persistence.STORE_KEY))
end
function Server.transmit()
    local store,err=Persistence.getStore();if not store then return false,err end
    if isServer()and ModData and type(ModData.transmit)=="function"then ModData.transmit(Persistence.STORE_KEY)end
    return true
end
function Server.install(events)
    if Server.installed then return true end
    if not events or not events.OnInitGlobalModData or type(events.OnInitGlobalModData.Add)~="function"then return false,"OnInitGlobalModData unavailable"end
    events.OnInitGlobalModData.Add(Server.initialize);Server.installed=true;return true
end
return Server
