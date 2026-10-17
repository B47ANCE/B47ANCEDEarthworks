require 'TimedActions/ISTimedActionQueue'
local Hand=require 'groundWorks/HandTools'
local Action=require 'groundWorks/ISGroundWorksSpoilAction'
local function queue(player,square,direction,barrow)ISTimedActionQueue.add(Action:new(player,square,direction,barrow))end
local function menu(index,context,objects,test)
    if test then return end
    local player=getSpecificPlayer(index)
    if not player or player:getVehicle()then return end
    local seen={}
    for _,object in ipairs(objects)do
        local square=object:getSquare()
        square=square and Hand.openingSquare(square)
        if square and not seen[square]then
            seen[square]=true
            local job=Hand.jobAt(square)
            if job and job.status=='excavated'and Hand.squareReachable(player,square)then
                context:addOption('Bag excavation spoil',player,queue,square,'bag')
                context:addOption('Return bagged soil for backfill',player,queue,square,'return')
                local Wheelbarrow=require 'groundWorks/Wheelbarrow'
                if Wheelbarrow.canHandle(player,Wheelbarrow.nearby(player))then
                    context:addOption('Bag spoil into wheelbarrow sacks',player,queue,square,'bag',true)
                    context:addOption('Return soil from wheelbarrow sacks',player,queue,square,'return',true)
                end
                return
            end
        end
    end
end
Events.OnFillWorldObjectContextMenu.Add(menu)
return menu
