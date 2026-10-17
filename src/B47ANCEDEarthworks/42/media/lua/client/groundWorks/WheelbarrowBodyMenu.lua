require 'TimedActions/ISTimedActionQueue'
local Barrow=require 'groundWorks/Wheelbarrow'
local Bodies=require 'groundWorks/WheelbarrowBodies'
local Actions=require 'groundWorks/ISWheelbarrowBodyActions'
local function load(actor,barrow)
    if Bodies.canLoad(actor,barrow,actor:getGrapplingTarget())then ISTimedActionQueue.add(Actions.load:new(actor,barrow))end
end
local function unload(actor,barrow,item)
    if Bodies.canUnload(actor,barrow,item)then ISTimedActionQueue.add(Actions.unload:new(actor,barrow,item))end
end
local function menu(index,context,objects,test)
    if test then return end
    local actor=getSpecificPlayer(index)
    local barrow=actor and Barrow.nearby(actor)
    if not barrow then return end
    if actor:isDraggingCorpse()then
        local option=context:addOption('Load dragged body into wheelbarrow',actor,load,barrow)
        option.notAvailable=not Bodies.canLoad(actor,barrow,actor:getGrapplingTarget())
    else
        local items=barrow:getContainer():getItems()
        for i=0,items:size()-1 do
            local item=items:get(i)
            if item:isHumanCorpse()then
                local option=context:addOption('Unload body from wheelbarrow: '..item:getDisplayName(),actor,unload,barrow,item)
                option.notAvailable=not Bodies.canUnload(actor,barrow,item)
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(menu)
return menu
