isClient=function()return false end;isServer=function()return false end
getActivatedMods=function()return{contains=function()return true end}end
getTimestampMs=function()return 1234 end
local owner=require 'itjustWorks/HeavyObjects';assert(owner.attachStore({}))
local data={theWorksType='groundWorks:wheelbarrow',version=1}
local square={getZ=function()return 0 end,getModData=function()return{}end,isBlockedTo=function()return false end}
local container={getContentsWeight=function()return 12 end}
local object={getObjectName=function()return 'Pushable'end,getModData=function()return data end,
    getSquare=function()return square end,getX=function()return 0 end,getY=function()return 0 end,getContainer=function()return container end}
getCell=function()return{getPushableObjectList=function()return{size=function()return 1 end,get=function()return object end}end}end
local function actor(name)
    local a={getUsername=function()return name end,getSquare=function()return square end,isDead=function()return false end,
        getVehicle=function()end,getX=function()return 1 end,getY=function()return 0 end}
    function a:getDragObject()return self.drag end
    function a:setDragObject(value)self.drag=value end
    return a
end
local first,second=actor('first'),actor('second')
local T=require 'groundWorks/WheelbarrowTransactions'
assert(T.advance(first,object,'reserve','first.1'))
assert(not T.advance(second,object,'reserve','second.1'),'Reserved wheelbarrow must reject another operator.')
assert(T.advance(first,object,'start','first.1'));assert(first.drag==object)
assert(T.advance(first,object,'complete','first.1'));assert(first.drag==nil and data.wheelbarrowOperator==nil)
assert(T.advance(second,object,'reserve','second.2'))
assert(T.advance(second,object,'start','second.2'))
second.getX=function()return 100 end
assert(not T.advance(second,object,'complete','second.2'))
assert(T.advance(second,object,'cancel','second.2'),'Cancellation must release even after losing eligibility.')
assert(second.drag==nil and data.wheelbarrowOperator==nil)
print('Wheelbarrow real-framework reservation, competing operators, completion and cancellation passed')
