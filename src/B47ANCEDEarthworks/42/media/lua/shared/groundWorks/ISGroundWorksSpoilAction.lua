require 'TimedActions/ISBaseTimedAction'
local Hand=require 'groundWorks/HandTools'
ISGroundWorksSpoilAction=ISBaseTimedAction:derive('ISGroundWorksSpoilAction')
function ISGroundWorksSpoilAction:isValid()
    local square=getCell():getGridSquare(self.x,self.y,self.z)
    return not self.character:isDead()and not self.character:getVehicle()
        and square and Hand.squareReachable(self.character,square)and Hand.findTool(self.character)~=nil
end
function ISGroundWorksSpoilAction:getDuration()return self.character:isTimedActionInstant()and 1 or 100 end
function ISGroundWorksSpoilAction:start()self:setActionAnim('Dig')end
function ISGroundWorksSpoilAction:complete()
    if isClient()then return false end
    local ok,why=require('groundWorks/SpoilExchange').perform(self.character,
        getCell():getGridSquare(self.x,self.y,self.z),self.direction,self.operationId,nil,false,self.useWheelbarrow)
    self.character:Say(tostring(why))
    return ok
end
function ISGroundWorksSpoilAction:perform()ISBaseTimedAction.perform(self)end
function ISGroundWorksSpoilAction:new(character,square,direction,useWheelbarrow)
    local o=ISBaseTimedAction.new(self,character)
    o.x,o.y,o.z=square:getX(),square:getY(),square:getZ();o.direction=direction
    o.useWheelbarrow=useWheelbarrow==true
    ISGroundWorksSpoilAction.serial=(ISGroundWorksSpoilAction.serial or 0)+1
    o.operationId='spoil:'..character:getUsername()..':'..getTimestampMs()..':'..ISGroundWorksSpoilAction.serial
    o.maxTime=100;o.stopOnWalk=true;o.stopOnRun=true;o.stopOnAim=true
    return o
end
return ISGroundWorksSpoilAction
