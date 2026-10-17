require 'TimedActions/ISDropCorpseIntoContainer'
require 'TimedActions/ISGrabCorpseItem'
local Bodies=require 'groundWorks/WheelbarrowBodies'
ISWheelbarrowLoadBody=ISDropCorpseIntoContainer:derive('ISWheelbarrowLoadBody')
function ISWheelbarrowLoadBody:isValid()
    return Bodies.canLoad(self.character,self.barrow,self.grappledChar)and ISDropCorpseIntoContainer.isValid(self)
end
function ISWheelbarrowLoadBody:complete()
    if not self:isValid()then return false end
    return ISDropCorpseIntoContainer.complete(self)
end
function ISWheelbarrowLoadBody:perform()
    if self:isValid()then ISDropCorpseIntoContainer.perform(self)
    else ISBaseTimedAction.perform(self)end
end
function ISWheelbarrowLoadBody:new(actor,barrow)
    local action=ISDropCorpseIntoContainer.new(self,actor,barrow:getContainer())
    action.barrow=barrow
    return action
end
ISWheelbarrowUnloadBody=ISGrabCorpseItem:derive('ISWheelbarrowUnloadBody')
function ISWheelbarrowUnloadBody:isValid()
    return Bodies.canUnload(self.character,self.barrow,self.item)and ISGrabCorpseItem.isValid(self)
end
function ISWheelbarrowUnloadBody:complete()
    if not self:isValid()then return false end
    return ISGrabCorpseItem.complete(self)
end
function ISWheelbarrowUnloadBody:new(actor,barrow,item)
    local action=ISGrabCorpseItem.new(self,actor,item)
    action.barrow=barrow
    return action
end
return{load=ISWheelbarrowLoadBody,unload=ISWheelbarrowUnloadBody}
