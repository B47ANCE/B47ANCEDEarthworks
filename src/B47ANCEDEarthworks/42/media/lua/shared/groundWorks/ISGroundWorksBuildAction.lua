require "TimedActions/ISBaseTimedAction"
local Build = require "groundWorks/ExcavationBuild"
local Hand = require "groundWorks/HandTools"

ISGroundWorksBuildAction = ISBaseTimedAction:derive("ISGroundWorksBuildAction")

function ISGroundWorksBuildAction:getSpec()
    return {
        presetId=self.presetId, direction=self.direction,
        x=self.x, y=self.y, z=self.z, operationId=self.operationId,
    }
end

function ISGroundWorksBuildAction:isValid()
    local player = self.character
    -- The vanilla timed-action engine asks this every update. The complete handler performs the
    -- full footprint/material/authority check immediately before committing.
    return self.preflightValid == true and Hand.enabled() and player ~= nil
        and not player:isDead() and not player:getVehicle()
        and math.floor(player:getX()) == self.x and math.floor(player:getY()) == self.y
        and math.floor(player:getZ()) == self.z and Build.isInside(player)
        and Hand.findTool(player) ~= nil
end

function ISGroundWorksBuildAction:getDuration()
    if self.character and self.character:isTimedActionInstant() then return 1 end
    return self.maxTime or 1
end

function ISGroundWorksBuildAction:waitToStart()
    local facing = { north={0,-1}, east={1,0}, south={0,1}, west={-1,0} }
    local offset = facing[self.direction] or facing.north
    self.character:faceLocation(self.x+offset[1], self.y+offset[2])
    return self.character:shouldBeTurning()
end

function ISGroundWorksBuildAction:start()
    local item = self.item
    local animation = self.anim or "Build"
    if CharacterActionAnims and CharacterActionAnims[animation] then
        animation = CharacterActionAnims[animation]
    end
    self:setActionAnim(animation)
    if item then self:setOverrideHandModels(item,nil) end
end

function ISGroundWorksBuildAction:update()
    self.character:setMetabolicTarget(Metabolics.DiggingSpade)
end

function ISGroundWorksBuildAction:complete()
    if isClient() then return false end
    return require("groundWorks/ExcavationBuildServer").perform(self.character,self:getSpec()) == true
end

function ISGroundWorksBuildAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISGroundWorksBuildAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISGroundWorksBuildAction:new(character,spec)
    local action = ISBaseTimedAction.new(self,character)
    action.character = character
    action.presetId, action.direction = spec.presetId, spec.direction
    action.x, action.y, action.z = spec.x, spec.y, spec.z
    ISGroundWorksBuildAction.sequence = (ISGroundWorksBuildAction.sequence or 0)+1
    local stamp = getTimestampMs and getTimestampMs() or 0
    action.operationId = spec.operationId or ("build:" .. character:getUsername() .. ":"
        .. tostring(stamp) .. ":" .. tostring(ISGroundWorksBuildAction.sequence))
    action.stopOnWalk, action.stopOnRun, action.stopOnAim = true, true, true
    action.useProgressBar = true
    local ok, details, failureDetails = Build.check(character, action:getSpec())
    action.preflightValid = ok == true
    details = ok and details or failureDetails
    action.maxTime = math.max(1, tonumber(details and details.duration) or 1)
    local tool = details and details.tool
    action.item, action.anim = tool and tool.item, tool and tool.anim
    return action
end

return ISGroundWorksBuildAction
