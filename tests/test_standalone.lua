-- No external activation, import, provider fallback or vehicle-book issuance.
isClient=function()return false end;isServer=function()return false end
local attempts={}
local original=require
require=function(name)
    assert(not name:find('CATConstruction',1,true)and not name:find('B47ANCEDKnowledgeAndWisdom',1,true),'standalone load attempted an external dependency')
    attempts[name]=true;return original(name)
end
getActivatedMods=function()return{contains=function()return true end,size=function()return 0 end,get=function()end}end
local API=require'groundWorks/Load'
local Providers=API.EarthworkProviders
for _,provider in pairs(Providers.definitions)do assert(provider.kind~='machine','bundled machine adapter remains')end
assert(next(API.Integration.KIND_PROVIDERS)==nil)
assert(API.providerIdForKind('excavator')==nil and API.providerIdForVehicle({kind='excavator',groundWorksProviderId='external'})==nil)
local metadata={groundWorksManualIssued='saved-reference'}
local called=0;local vehicle={getModData=function()return metadata end,getPartById=function()called=called+1;error('retired hook touched cargo')end}
assert(not require('groundWorks/VehicleManuals').ensure(vehicle))
assert(called==0 and metadata.groundWorksManualIssued=='saved-reference')
local Work=require'groundWorks/RouteWork'
for _,option in ipairs(Work.OPTIONS)do assert(option.route~='groundWorks.concreteRoad','unavailable machine-only menu entry remains')end
assert(API.ConstructedRoutes.get('groundWorks.concreteRoad').requiresMachine,'old route definition must not become manually constructible')
print('Standalone loader, no bundled machine providers, inert issuance and saved route safety passed')
