isClient=function()return false end
local accessible=true
package.loaded['groundWorks/Wheelbarrow']={canHandle=function()return accessible,'inaccessible'end}
local Bodies=require 'groundWorks/WheelbarrowBodies'
local body={};local data={};local container={}
local barrow={getModData=function()return data end,getContainer=function()return container end}
local actor={dragging=true,target=body,room=true}
function actor:getDragObject()return self.pushable end
function actor:getUsername()return 'worker'end
function actor:isDraggingCorpse()return self.dragging end
function actor:getGrapplingTarget()return self.target end
function actor:getContextWorldSuitableContainersToDropCorpseInObjects(objects)
    assert(objects[1]==barrow)
    return{size=function()return self.room and 1 or 0 end,get=function()return container end}
end
assert(Bodies.canLoad(actor,barrow,body))
actor.room=false;assert(not Bodies.canLoad(actor,barrow,body));actor.room=true
assert(not Bodies.canLoad(actor,barrow,{}),'Changed corpse must invalidate queued load.')
actor.pushable=barrow;assert(not Bodies.canLoad(actor,barrow,body));actor.pushable=nil
data.wheelbarrowOperator='other';assert(not Bodies.canLoad(actor,barrow,body));data.wheelbarrowOperator=nil
accessible=false;assert(not Bodies.canLoad(actor,barrow,body));accessible=true
local item={isHumanCorpse=function()return true end,getContainer=function()return container end}
function container:contains(value)return value==item end
actor.dragging=false;assert(Bodies.canUnload(actor,barrow,item))
actor.dragging=true;assert(not Bodies.canUnload(actor,barrow,item));actor.dragging=false
item.getContainer=function()return{}end;assert(not Bodies.canUnload(actor,barrow,item))
isClient=function()return true end;assert(Bodies.check(actor,barrow))
print('Wheelbarrow bodies: capacity, identity, ownership, distance, changed inventory and multiplayer realm passed')
