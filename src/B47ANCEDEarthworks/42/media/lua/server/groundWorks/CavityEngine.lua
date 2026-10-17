local API=require "groundWorks/Load"
local Experiment=API.ExcavationExperiment
local Cavity=API.Cavity
local Terrain=require "groundWorks/CavityTerrain"
local Engine={}

local function call(object,method,...)
    if not object then return nil end
    local ok,fn=pcall(function()return object[method]end);if not ok or type(fn)~="function"then return nil end
    local called,result=pcall(fn,object,...);if called then return result end
end

local function spriteName(object)
    local sprite=object and call(object,"getSprite")
    return sprite and call(sprite,"getName")or nil
end

local function clearSolidFloor(square)
    if not square then return end
    pcall(function()square:setSolidFloor(false)end)
    pcall(function()square:setSolidFloorCached(false)end)
    local props=call(square,"getProperties")
    local flags=rawget(_G,"IsoFlagType")
    if props and flags then
        if flags.solidfloor then props:unset(flags.solidfloor)end
        if flags.transparentFloor then props:set(flags.transparentFloor)end
        if flags.trans then props:set(flags.trans)end
        if flags.openAir then props:set(flags.openAir)end
    end
end

local function restoreSolidFloor(square)
    if not square then return end
    pcall(function()square:setSolidFloor(true)end)
    pcall(function()square:setSolidFloorCached(true)end)
end

local function openToSky(square)
    if not square then return false end
    if square:getZ()<0 then
        local cleared=Terrain.clearUnderground(square)
        if not cleared then return false end
    end
    local root=call(square,"getModData")
    local floor=call(square,"getFloor")
    if type(root)=="table"then
        local floorData=floor and call(floor,"getModData")or nil
        root.groundWorksOpeningSprite=root.groundWorksOpeningSprite
            or(type(floorData)=="table"and floorData.groundWorksOpeningSprite)
            or spriteName(floor)
        if floor then root.groundWorksFloorRemoved=true end
    end
    if floor then
        if isServer()then call(square,"transmitRemoveItemFromSquare",floor)end
        if not isServer()then call(square,"RemoveTileObject",floor)end
        if Terrain.clearSurfaceGrass(square)~=true then return false end
    end
    clearSolidFloor(square)
    pcall(function()square:EnsureSurroundNotNull();square:RecalcAllWithNeighbours(true);square:setSquareChanged()end)
    Terrain.refresh(square)
    if type(square.transmitModdata)=="function"then square:transmitModdata()end
    return call(square,"getFloor")==nil
end

local function restoreFloor(square)
    if not square then return false end
    local root=call(square,"getModData")
    local original=type(root)=="table"and root.groundWorksOpeningSprite or nil
    if call(square,"getFloor")then restoreSolidFloor(square);return true end
    if type(original)=="string"and original~=""and type(getSprite)=="function"and getSprite(original)~=nil then
        local restored
        local ok=pcall(function()
            -- Restore only the removed floor. Native addFloor also deletes
            -- vegetation/noStart/water objects and can prepare extra earth.
            restored=assert(IsoObject.getNew(square,original,nil,false))
            square:AddTileObject(restored)
            assert(square:getFloor()==restored,'restored floor did not resolve')
            Terrain.refresh(square)
            if isServer()then restored:transmitCompleteItemToClients()end
        end)
        if not ok then
            if restored and restored:getObjectIndex()>=0 then square:transmitRemoveItemFromSquare(restored)end
            return false
        end
    end
    if not call(square,"getFloor")then return false end
    restoreSolidFloor(square)
    if type(root)=="table"then root.groundWorksOpeningSprite=nil;root.groundWorksFloorRemoved=nil end
    pcall(function()square:EnsureSurroundNotNull();square:RecalcAllWithNeighbours(true);square:setSquareChanged()end)
    if type(square.transmitModdata)=="function"then square:transmitModdata()end
    return true
end

function Engine.movePlayer(player,square)
    if not player or not square then return false,"player and square required"end
    local x,y,z=call(square,"getX"),call(square,"getY"),call(square,"getZ")
    x,y,z=tonumber(x),tonumber(y),tonumber(z)
    if not x or not y or not z then return false,"square coordinates unavailable"end
    x,y=x+0.5,y+0.5
    local ok=pcall(function()
        player:setX(x);player:setY(y);player:setZ(z)
        if type(player.setLx)=="function"then player:setLx(x);player:setLy(y);player:setLz(z)end
        if type(player.setCurrentSquare)=="function"then player:setCurrentSquare(square)end
    end)
    if not ok then return false,"player relocate failed"end
    local nowZ=call(player,"getZ")
    if isServer()and instanceof(player,"IsoPlayer")then
        sendServerCommand(player,"groundWorks","cavityMove",{x=x,y=y,z=z,onlineId=player:getOnlineID()})
    end
    return tonumber(nowZ)==z,tonumber(nowZ)==z and true or"player Z did not match cavity"
end

function Engine.adapter()
    local cell=getCell()
    return{
        validateSprite=function(name)
            local sprite=getSprite(name)
            return sprite~=nil and sprite:getName()==name
        end,
        isValidSquare=function(x,y,z)return getWorld():isValidSquare(x,y,z)==true end,
        getSquare=function(x,y,z)return cell:getGridSquare(x,y,z)end,
        isEmptySquare=function(square)
            if not square or square:getFloor()or square:getRoom()or square:getBuilding()then return false end
            if not square:getMovingObjects():isEmpty()or not square:getStaticMovingObjects():isEmpty()then return false end
            for i=0,square:getObjects():size()-1 do
                local object=square:getObjects():get(i)
                local boundary=object:getModData()['groundWorks.boundary.v1']
                if not Terrain.isUndergroundObject(object)and not(type(boundary)=='table'and boundary.kind=='earth')then return false end
            end
            return true
        end,
        validateSurface=function(surface,plan)
            if (surface:getRoom()~=nil or surface:getBuilding()~=nil)and(not plan or plan.volumeType~="groundWorks.basement")then return false,"use basement excavation inside buildings"end
            if not surface:getFloor()then return false,"natural floor required"end
            if plan and plan.preserveSurface then
                if plan.volumeType~='groundWorks.basement'or(not surface:getRoom()and not surface:getBuilding())then return false,'Only an existing house floor may be preserved.'end
            elseif not surface:isFree(false)then return false,"clear the excavation square first"end
            return true
        end,
        createSquare=Terrain.prepare,
        connectSquare=function(square)
            Terrain.normalizeChunk(square:getChunk(),square:getZ())
            return cell:getGridSquare(square:getX(),square:getY(),square:getZ())==square
        end,
        addFloor=function(square,sprite)
            assert(Terrain.clearUnderground(square))
            assert(Terrain.addFloor(square,sprite))
            restoreSolidFloor(square)
            return square:getFloor()
        end,
        tagObject=function(object,operationId)
            local data=object:getModData();if type(data)~="table"then return false end
            data[Experiment.ROOT_KEY]={schemaVersion=1,operationId=operationId}
            data[Cavity.ROOT_KEY]={schemaVersion=1,operationId=operationId,role="cavity"}
            return true
        end,
        recalculate=function(square)return Terrain.refresh(square)end,
        transmitObject=function(object)if isServer()then object:transmitCompleteItemToClients()end;return true end,
        verify=function(x,y,z,square,object,operationId)
            local resolved=cell:getGridSquare(x,y,z);if resolved~=square then return false end
            if object and square:getFloor()~=object then return false end
            local marker
            if object then marker=object:getModData()[Experiment.ROOT_KEY]or object:getModData()[Cavity.ROOT_KEY]end
            if type(marker)~="table"then
                local root=square:getModData()
                marker=type(root)=="table"and(root[Cavity.ROOT_KEY]or root[Experiment.ROOT_KEY])or nil
            end
            return type(marker)=="table"and marker.schemaVersion==1 and marker.operationId==operationId
        end,
        setFloorSprite=function(object,name)
            if not object or type(name)~="string"or name==""then return false end
            if type(getSprite)=="function"and getSprite(name)==nil then return false end
            local ok=pcall(function()
                if type(object.setSpriteFromName)=="function"then object:setSpriteFromName(name)
                else object:setSprite(name)end
                if isServer()and type(object.transmitUpdatedSpriteToClients)=="function"then
                    object:transmitUpdatedSpriteToClients()
                end
            end)
            return ok==true
        end,
        startFire=function(square)
            if not square then return false end
            local started=pcall(function()
                if IsoFireManager and IsoFireManager.StartFire then
                    IsoFireManager.StartFire(getCell(),square,true,80,0)
                elseif type(square.StartFire)=="function"then square:StartFire()
                elseif type(square.startFire)=="function"then square:startFire()
                else error("no fire API")end
            end)
            return started==true
        end,
        openToSky=openToSky,
        restoreFloor=restoreFloor,
        tagOpening=function(surface,operationId,spec)
            local root=surface:getModData();if type(root)~="table"then return false end
            local opening={schemaVersion=1,operationId=operationId,role="opening",jobId=spec and spec.jobId,volumeType=spec and spec.volumeType,shaft=true,preserveSurface=spec and spec.preserveSurface==true}
            root[Cavity.OPENING_KEY]=opening
            if type(surface.transmitModdata)=="function"then surface:transmitModdata()end
            if opening.preserveSurface then return call(surface,'getFloor')~=nil end
            return openToSky(surface)==true
        end,
        verifyOpening=function(surface,operationId)
            local root=surface:getModData()
            local marker=type(root)=="table"and(root[Cavity.OPENING_KEY]or root[Cavity.ROOT_KEY])or nil
            if type(marker)~="table"or marker.schemaVersion~=1 or marker.operationId~=operationId then return false end
            if marker.preserveSurface then return call(surface,'getFloor')~=nil end
            return call(surface,"getFloor")==nil
        end,
        untagOpening=function(surface)
            local root=surface:getModData()
            if type(root)=="table"then root[Cavity.OPENING_KEY]=nil end
            if not restoreFloor(surface)then return false end
            if type(surface.transmitModdata)=="function"then surface:transmitModdata()end
            return true
        end,
        finalizeCavity=function(surface)
            return require('groundWorks/CavityBoundary').reconcileColumn(surface)
        end,
        clearBoundaries=function(surface)
            return require('groundWorks/CavityBoundary').clearColumn(surface)
        end,
        finalizeClosure=function(surface)
            return require('groundWorks/CavityBoundary').reconcileNeighbors(surface)
        end,
        removeObject=function(square,object)
            if object:getSquare()~=square then return false end
            if isServer()then square:transmitRemoveItemFromSquare(object)end
            if not isServer()then square:RemoveTileObject(object)end
            return object:getSquare()==nil or square:getFloor()~=object
        end,
        movePlayer=Engine.movePlayer,
    }
end

return Engine
