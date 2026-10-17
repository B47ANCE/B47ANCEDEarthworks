local Barrow=require 'groundWorks/Wheelbarrow'
local Bodies={}
function Bodies.check(actor,barrow,unloading)
    local ok,why=Barrow.canHandle(actor,barrow,unloading)
    if not ok then return false,why end
    if actor:getDragObject()then return false,'Release the wheelbarrow before handling a body.'end
    local owner=barrow:getModData().wheelbarrowOperator
    if owner and owner~=actor:getUsername()then return false,'Another worker is using this wheelbarrow.'end
    return true
end
function Bodies.canLoad(actor,barrow,target)
    local ok,why=Bodies.check(actor,barrow)
    if not ok then return false,why end
    if not actor:isDraggingCorpse()or not target or actor:getGrapplingTarget()~=target then return false,'Drag a body beside the wheelbarrow first.'end
    -- Let the installed engine evaluate corpse conversion weight and container
    -- suitability. Never invent a corpse item or discard its native contents.
    local containers=actor:getContextWorldSuitableContainersToDropCorpseInObjects({barrow})
    local container=barrow:getContainer()
    for i=0,containers:size()-1 do if containers:get(i)==container then return true end end
    return false,'The body does not fit in the wheelbarrow.'
end
function Bodies.canUnload(actor,barrow,item)
    local ok,why=Bodies.check(actor,barrow,true)
    if not ok then return false,why end
    if actor:isDraggingCorpse()then return false,'Put down the body you are already dragging.'end
    local container=barrow:getContainer()
    return item and item:isHumanCorpse()and item:getContainer()==container and container:contains(item)or false,'Body is no longer in this wheelbarrow.'
end
return Bodies
