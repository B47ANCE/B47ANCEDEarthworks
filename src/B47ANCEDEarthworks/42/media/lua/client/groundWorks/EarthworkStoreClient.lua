local API=require "groundWorks/Load"
local Persistence=API.EarthworkPersistence
local Client={}
function Client.receive(key,store)
    if key~=Persistence.STORE_KEY or not isClient() then return end
    local ok,err=Persistence.attachStore(store)
    if not ok then print("[groundWorks] Earthwork snapshot rejected: "..tostring(err))end
end
function Client.request()
    if isClient()then ModData.request(Persistence.STORE_KEY)end
end
Events.OnReceiveGlobalModData.Add(Client.receive)
Events.OnConnected.Add(Client.request)
Events.OnGameStart.Add(Client.request)
return Client
