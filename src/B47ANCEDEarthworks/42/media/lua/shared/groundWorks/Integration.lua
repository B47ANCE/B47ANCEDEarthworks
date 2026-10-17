local groundWorks=require "groundWorks/API"
local Providers=require "groundWorks/EarthworkProviders"
local PrecipitationCleaning=require "groundWorks/PrecipitationCleaning"
local HeavyObjectIntegration=require "groundWorks/HeavyObjectIntegration"

-- No bundled vehicle adapters. Keep old query entry points inert for callers;
-- generic providers require their own explicit server-side registration.
local Integration={CONSUMER_API=3,KIND_PROVIDERS={}}
function Integration.providerIdForKind()return nil end
function Integration.providerIdForVehicle()return nil end

local function loadOptional(modId,path)
    if type(getActivatedMods)~="function"then return nil end
    local active,mods=pcall(getActivatedMods)
    if not active or not mods or type(mods.contains)~="function"then return nil end
    local checked,enabled=pcall(mods.contains,mods,modId)
    if not checked or enabled~=true then return nil end
    local ok,value=pcall(require,path)
    return ok and type(value)=="table" and value or nil
end

-- Attach optional cross-mod consumers when their provider contracts are
-- present. Absent, disabled, or unloadable integrations remain inert.
function Integration.attachOptionalConsumers()
    local precipitation=loadOptional("weatherWorks","weatherWorks/PrecipitationExposure")
    if precipitation then
        PrecipitationCleaning.attach(precipitation)
        PrecipitationCleaning.registerSurfaceProvider()
    end
    local heavy=loadOptional("itjustWorks","itjustWorks/HeavyObjects")
    if heavy then HeavyObjectIntegration.attach(heavy)end
    return Integration
end

function Integration.consumer()
    return{
        version=groundWorks.VERSION,
        consumerApi=Integration.CONSUMER_API,
        validateProject=groundWorks.validateProject,
        validateVolume=groundWorks.validateVolume,
        getVolumeType=groundWorks.getVolumeType,
        listVolumeTypes=groundWorks.listVolumeTypes,
        registerVolumeType=groundWorks.registerVolumeType,
        registerProjectType=groundWorks.registerProjectType,
        registerEarthworkProvider=function(definition)return Providers.register(definition)end,
        providerIdForKind=Integration.providerIdForKind,
        providerIdForVehicle=Integration.providerIdForVehicle,
        Projects=groundWorks.Projects,
        EarthworkJobs=groundWorks.EarthworkJobs,
        EarthworkProviders=groundWorks.EarthworkProviders,
        EarthworkPersistence=groundWorks.EarthworkPersistence,
        EarthworkGeometry=groundWorks.EarthworkGeometry,
        Cavity=groundWorks.Cavity,
        VolumeRuntime=groundWorks.VolumeRuntime,
        HandTools=groundWorks.HandTools,
        ExcavationPresets=groundWorks.ExcavationPresets,
        ExcavationBuild=groundWorks.ExcavationBuild,
        -- Machine callers run in the server realm and provide their normal
        -- vehicle-operation timing, fuel and animation before applying work.
        excavationServer=function()
            if type(isClient)=='function'and isClient()then return nil,'server only'end
            return require 'groundWorks/ExcavationBuildServer'
        end,
        PrecipitationCleaning=PrecipitationCleaning,
        HeavyObjectIntegration=HeavyObjectIntegration,
        inspectSurface=groundWorks.inspectSurface,
        reportTraffic=groundWorks.reportTraffic,
    }
end

groundWorks.Integration=Integration
groundWorks.providerIdForKind=Integration.providerIdForKind
groundWorks.providerIdForVehicle=Integration.providerIdForVehicle
groundWorks.consumer=Integration.consumer
return Integration
