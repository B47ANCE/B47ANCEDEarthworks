local API=require 'groundWorks/API'
local Cleaning=require 'groundWorks/PrecipitationCleaning'
local Rain={MAX_TRACKED=2048,BATCH=128,points={},order={},cursor=1}
local exposure,weather
local function authority()return not isClient()end
function Rain.track(square)
    if not authority()or not square or not square:getModData()[API.STATE_KEY]then return end
    local id=Cleaning.surfaceTargetId(square)
    if Rain.points[id]then return end
    if #Rain.order>=Rain.MAX_TRACKED then Rain.points[table.remove(Rain.order,1)]=nil end
    Rain.points[id]={x=square:getX(),y=square:getY(),z=square:getZ(),fresh=true}
    Rain.order[#Rain.order+1]=id
end
function Rain.step()
    if not authority()then return end
    if not weather then
        if not getActivatedMods():contains('weatherWorks')then return end
        weather=require 'weatherWorks/API';exposure=require 'weatherWorks/PrecipitationExposure'
        Cleaning.attach(exposure);Cleaning.registerSurfaceProvider()
    end
    local snapshot=weather.sample()
    if not snapshot then return end
    local candidates={}
    for _=1,math.min(#Rain.order,Rain.BATCH)do
        if Rain.cursor>#Rain.order then Rain.cursor=1 end
        local point=Rain.points[Rain.order[Rain.cursor]];Rain.cursor=Rain.cursor+1
        local square=getCell():getGridSquare(point.x,point.y,point.z)
        if square then
            if point.fresh then
                exposure.process({worldAgeHours=snapshot.worldAgeHours,precipitation=0,snowStrength=0},{square})
                Cleaning.applyCleaning(square,snapshot.worldAgeHours)
                point.fresh=false
            end
            candidates[#candidates+1]=square
        else point.fresh=true end
    end
    local ok=exposure.process(snapshot,candidates)
    if ok then for _,square in ipairs(candidates)do Cleaning.applyCleaning(square,snapshot.worldAgeHours)end end
end
function Rain.install(events)
    if Rain.installed then return end
    API.registerWearListener('groundWorks.rainTargets',Rain.track)
    events.LoadGridsquare.Add(Rain.track)
    events.EveryTenMinutes.Add(Rain.step)
    Rain.installed=true
end
return Rain
