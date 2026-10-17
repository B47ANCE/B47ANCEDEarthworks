local API=require 'groundWorks/API'
local Presentation=require 'groundWorks/SurfacePresentation'
local Visual={KEY='groundWorks.wornOverlay.v1',SPRITE='blends_natural_01_64'}
local opacity={LIGHT_WEAR=.12,WORN=.3,BARE=.65,ESTABLISHED_PATH=.9}
local function name(floor)
    local sprite=floor:getOverlaySprite()
    return sprite and sprite:getName()
end
function Visual.remove(square)
    local floor=square:getFloor()
    if not floor then return true end
    local data=floor:getModData()
    if not data[Visual.KEY]then return true end
    -- Another owner may have replaced our layer since the last observation.
    if name(floor)==Visual.SPRITE then
        floor:setOverlaySprite('')
        if floor:getOverlaySprite()then return false end
        if isServer()then floor:transmitUpdatedSpriteToClients()end
    end
    data[Visual.KEY]=nil
    return true
end
function Visual.apply(square,stage)
    local floor=square:getFloor()
    if not floor then return true end
    local surface=API.inspectSurface(square)
    if not surface or surface.water or surface.trafficWear==false then return true end
    if name(floor)and(name(floor)~=Visual.SPRITE or not floor:getModData()[Visual.KEY])then
        floor:getModData()[Visual.KEY]=nil
        return true
    end
    floor:getModData()[Visual.KEY]={stage=stage}
    floor:setOverlaySprite(Visual.SPRITE,1,1,1,opacity[stage]or 0)
    if name(floor)~=Visual.SPRITE then return false end
    if isServer()then floor:transmitUpdatedSpriteToClients()end
    return true
end
function Visual.install()
    if Visual.installed then return end
    Presentation.registerLayerProvider{id='groundWorks.wornOverlay',priority=-100,
        layerFor=function(stage)return opacity[stage]and'overlay'or'none'end,
        apply=Visual.apply,remove=Visual.remove}
    Visual.installed=true
    if Events and Events.LoadGridsquare then Events.LoadGridsquare.Add(function(square)
        local state=Presentation.inspect(square)
        if state and state.providerId=='groundWorks.wornOverlay'and not state.hidden and not state.requiresInspection then
            Visual.apply(square,state.presentedStage)
        end
    end)end
end
return Visual
