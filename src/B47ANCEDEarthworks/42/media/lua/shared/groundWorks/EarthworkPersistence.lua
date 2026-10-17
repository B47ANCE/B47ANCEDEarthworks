local groundWorks=require "groundWorks/API"
local Jobs=require "groundWorks/EarthworkJobs"
local Integrity=require "groundWorks/EarthworkIntegrity"
local Persistence={STORE_KEY="groundWorks.earthworks.v1",SCHEMA_VERSION=1,store=nil,status="unattached",reason=nil}

local function empty(values)
    if type(values)~="table"then return false end
    for _ in pairs(values)do return false end
    return true
end
local function valid(store)
    return type(store)=="table"and store.schemaVersion==1 and type(store.jobs)=="table"
        and type(store.cellOwners)=="table"and type(store.stockpiles)=="table"and type(store.processedOperations)=="table"
end
local function initialize(store)
    local created=Jobs.newStore();for key,value in pairs(created)do store[key]=value end
end

function Persistence.attachStore(store)
    if type(store)~="table"then Persistence.store=nil;Persistence.status="quarantined";Persistence.reason="earthwork store is not a table";return false,Persistence.reason end
    if store.schemaVersion==nil and empty(store)then initialize(store)end
    if not valid(store)then
        Persistence.store=nil;Persistence.status="quarantined"
        Persistence.reason=type(store.schemaVersion)=="number"and store.schemaVersion>1 and"future earthwork store schema"or"malformed earthwork store"
        return false,Persistence.reason
    end
    local audit=Integrity.audit(store)
    if not audit.valid then
        Persistence.store=nil;Persistence.status="quarantined";Persistence.reason="earthwork store integrity failure: "..tostring(audit.errors[1]or"unknown")
        return false,Persistence.reason
    end
    Persistence.store=store;Persistence.status="attached";Persistence.reason=nil;return true,store
end

function Persistence.getStore()return Persistence.store,Persistence.store and nil or Persistence.reason or"earthwork store unattached"end
function Persistence.inspectAttachment()return{schemaVersion=1,status=Persistence.status,reason=Persistence.reason,attached=Persistence.store~=nil}end
function Persistence._resetForTests()Persistence.store=nil;Persistence.status="unattached";Persistence.reason=nil end

groundWorks.EarthworkPersistence=Persistence
return Persistence
