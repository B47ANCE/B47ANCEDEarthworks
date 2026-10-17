local groundWorks=require "groundWorks/API"

local Cleaning={CONSUMER_ID="groundWorks.precipitationCleaning.v1",STATE_KEY="groundWorks.precipitationCleaning.v1",providerRegistered=false}
local exposure=nil

local function finite(value)
    value=tonumber(value)
    return value and value==value and value~=math.huge and value~=-math.huge and value or nil
end

function Cleaning.attach(api)
    if exposure==api then return Cleaning.available()end
    exposure=type(api)=="table" and type(api.inspect)=="function" and api or nil
    Cleaning.providerRegistered=false
    return Cleaning.available()
end

function Cleaning.available() return exposure~=nil end

function Cleaning.surfaceTargetId(square)
    if not square then return nil end
    local okX,x=pcall(square.getX,square)
    local okY,y=pcall(square.getY,square)
    local okZ,z=pcall(square.getZ,square)
    if not okX or not okY or not okZ then return nil end
    x=tonumber(x);y=tonumber(y);z=tonumber(z)
    if not x or not y or not z then return nil end
    return "groundWorks.surface."..tostring(x).."."..tostring(y).."."..tostring(z)
end

local function sheltered(square,context)
    if type(context)=="table"and type(context.sheltered)=="boolean"then return context.sheltered end
    if type(square.getZ)=="function"and square:getZ()<0 then return true end
    if type(square.getRoom)=="function"and square:getRoom()~=nil then return true end
    if type(square.haveRoofFull)=="function"and square:haveRoofFull()==true then return true end
    if type(square.isOutside)=="function"then return square:isOutside()~=true end
    -- Unknown exposure must never count as confirmed outdoor rain.
    return true
end

-- Optional weatherWorks adapter. The owner may provide an explicit shelter
-- fact; otherwise only a confirmed native outdoor square receives exposure.
function Cleaning.registerSurfaceProvider()
    if not Cleaning.available() or type(exposure.registerProvider)~="function" then
        return false,"exposure provider registry unavailable"
    end
    if Cleaning.providerRegistered then return true end
    local ok,result=pcall(function()
        return exposure.registerProvider{
            id="groundWorks.surface.v1",
            matches=function(square) return Cleaning.surfaceTargetId(square)~=nil and groundWorks.inspectSurface(square)~=nil end,
            describe=function(square,context)
                local targetId=Cleaning.surfaceTargetId(square)
                if not targetId then return nil,"surface identity unavailable" end
                return {targetId=targetId,regionId="groundWorks",loaded=true,sheltered=sheltered(square,context)}
            end,
        }
    end)
    if not ok or result==false then return false,"exposure provider registration failed"end
    Cleaning.providerRegistered=true
    return true
end

function Cleaning.exposureFor(square)
    if not Cleaning.available() then return nil,"precipitation consumer unavailable" end
    if type(exposure.inspect)~="function" then return nil,"exposure inspection unavailable" end
    local targetId=Cleaning.surfaceTargetId(square)
    if not targetId then return nil,"surface identity unavailable" end
    local ok,view=pcall(exposure.inspect,targetId)
    if not ok then return nil,"exposure inspection failed" end
    if type(view)~="table" then return nil,"exposure state unavailable" end
    local rain=finite(view.rainExposure)or 0
    local snow=finite(view.snowExposure)or 0
    if rain<0 or snow<0 then return nil,"invalid precipitation exposure"end
    return {rain=rain,snow=snow,sheltered=view.sheltered~=false or sheltered(square)}
end

-- Consume only exposure accrued after the first observation. Repeated calls
-- for the same rain cannot repeatedly remove wear, and covered precipitation
-- is retired rather than saved for later cleaning. Counter resets rebase.
function Cleaning.applyCleaning(square,worldAgeHours,options)
    if type(isClient)=="function"and isClient()==true then return false,"non-authority"end
    if not Cleaning.available() then return false,"precipitation consumer unavailable" end
    if type(groundWorks.applySurfaceCleaning)~="function"then return false,"surface cleaning API unavailable"end
    local age=finite(worldAgeHours)
    if not age or age<0 then return false,"finite non-negative world age required"end
    local exposureView,err=Cleaning.exposureFor(square)
    if not exposureView then return false,err end
    if not square or type(square.getModData)~="function"then return false,"square ModData unavailable"end
    local root=square:getModData()
    if type(root)~="table"then return false,"square ModData unavailable"end
    local prior=root[Cleaning.STATE_KEY]
    if prior~=nil and(type(prior)~="table"or prior.schemaVersion~=1
        or not finite(prior.rain)or not finite(prior.snow))then return false,"unsupported cleaning state"end
    local rain=prior and math.max(0,exposureView.rain-prior.rain)or 0
    local snow=prior and math.max(0,exposureView.snow-prior.snow)or 0
    options=type(options)=="table" and options or{}
    local rainRate=math.max(0,finite(options.rainRate)or 1)
    local snowRate=math.max(0,finite(options.snowRate)or 0)
    local maxCleaning=math.max(0,math.min(100,finite(options.maxCleaning)or 20))
    local minimumWear=math.max(0,math.min(100,finite(options.minimumWear)or 0))
    local amount=exposureView.sheltered and 0 or math.min(rain*rainRate+snow*snowRate,maxCleaning)
    local current=groundWorks.getWearState(square)
    amount=math.min(amount,math.max(0,(current and finite(current.wear)or 0)-minimumWear))
    if amount>0 then
        local cleaned,result=groundWorks.applySurfaceCleaning(square,age,amount)
        if cleaned~=true then return false,result end
        current=result
    end
    root[Cleaning.STATE_KEY]={schemaVersion=1,rain=exposureView.rain,snow=exposureView.snow,lastWorldAgeHours=age}
    if type(square.transmitModdata)=="function"then square:transmitModdata()end
    return true,current
end

groundWorks.PrecipitationCleaning=Cleaning
return Cleaning
