require "TimedActions/ISBaseTimedAction"
require "groundWorks/Load"

ISGroundWorksDigAction=ISBaseTimedAction:derive("ISGroundWorksDigAction")

function ISGroundWorksDigAction:isValid()
    local HandTools=groundWorks and groundWorks.HandTools
    if not HandTools then return false end
    local op=self.op or"excavate"
    if op=='routeStart'or op=='routeSupply'or op=='routeWork'then
        local ok=require('groundWorks/RouteWork').plan(self.character,self.square,op,self.volumeType)
        return ok==true
    end
    if op=="fill"then local ok=HandTools.canFill(self.character,self.square);return ok==true end
    if op=="deepen"then local ok=HandTools.canDeepen(self.character,self.square);return ok==true end
    if op=="pour"then local ok=HandTools.canPour(self.character,self.square,self.media);return ok==true end
    if op=="ignite"then local ok=HandTools.canIgnite(self.character,self.square);return ok==true end
    local ok=HandTools.canExcavate(self.character,self.square,self.volumeType)
    return ok==true
end

function ISGroundWorksDigAction:waitToStart()
    if self.square then self.character:faceLocation(self.square:getX(),self.square:getY())end
    return self.character:shouldBeTurning()
end

function ISGroundWorksDigAction:start()
    local anim=self.anim or"Shovel"
    if self.item and (self.op=="excavate"or self.op=="deepen"or self.op=="fill")and BuildingHelper then
        anim=BuildingHelper.getShovelAnim(self.item)
    end
    if CharacterActionAnims and CharacterActionAnims[anim]then
        self:setActionAnim(CharacterActionAnims[anim])
    else
        self:setActionAnim(anim)
    end
    if self.item then
        pcall(function()self:setOverrideHandModels(self.item,nil)end)
    end
end

function ISGroundWorksDigAction:update()
    if self.op=="excavate"or self.op=="deepen"or self.op=="fill"then
        self.character:setMetabolicTarget(Metabolics.DiggingSpade)
    end
end

function ISGroundWorksDigAction:stop()
    ISBaseTimedAction.stop(self)
end

function ISGroundWorksDigAction:complete()
    if isClient() then return false end
    local Server=require "groundWorks/HandToolsServer"
    return Server.perform(self.character,{
        x=self.square:getX(),y=self.square:getY(),z=self.square:getZ(),
        volumeType=self.volumeType,operationId=self.operationId,
        fullType=self.item and self.item:getFullType()or self.fullType,
        op=self.op or"excavate",media=self.media,
        sectionId=self.sectionId,direction=self.direction,
    })==true
end

function ISGroundWorksDigAction:perform()
    ISBaseTimedAction.perform(self)
end

function ISGroundWorksDigAction:new(character,square,tool,volumeType,op,media,sectionId,direction)
    local o=ISBaseTimedAction.new(self,character)
    o.character=o.character or character
    o.square=square
    o.item=tool and tool.item or nil
    o.fullType=tool and tool.fullType or nil
    o.volumeType=volumeType
    o.op=op or"excavate"
    o.media=media
    o.sectionId=sectionId
    o.direction=direction
    o.anim=tool and tool.anim or"Shovel"
    o.maxTime=tool and tool.maxTime or 80
    o.stopOnWalk=true
    o.stopOnRun=true
    o.stopOnAim=true
    o.useProgressBar=true
    o.delivered=false
    local age=getGameTime()and getGameTime():getWorldAgeHours()or 0
    local stamp=type(getTimestampMs)=="function"and getTimestampMs()or 0
    ISGroundWorksDigAction.sequence=(ISGroundWorksDigAction.sequence or 0)+1
    o.operationId="hand:"..tostring(character:getUsername())..":"..tostring(stamp)..":"..tostring(ISGroundWorksDigAction.sequence)
    return o
end

function ISGroundWorksDigAction:getDuration()
    if self.character and self.character.isTimedActionInstant and self.character:isTimedActionInstant()then return 1 end
    return self.maxTime or 80
end
