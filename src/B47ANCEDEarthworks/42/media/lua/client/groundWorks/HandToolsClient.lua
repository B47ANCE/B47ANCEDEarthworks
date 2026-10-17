require "ISUI/ISContextMenu"
require "TimedActions/ISTimedActionQueue"
pcall(require,"TimedActions/ISEquipWeaponAction")
require "groundWorks/ISGroundWorksDigAction"

local function say(player,ok,message)
    if player and player.Say then player:Say(tostring(message))end
    print("[groundWorks][HandTools] "..tostring(ok).." "..tostring(message))
end

local function squareFrom(worldObjects,player)
    for _,object in ipairs(worldObjects or{})do
        if object and object.getSquare then
            local square=object:getSquare()
            if square then return square end
        end
    end
    return player and player:getCurrentSquare()or nil
end

local function queueWork(player,square,details)
    if not details then return end
    square=details.opening or square
    if math.floor(player:getZ())==square:getZ()and luautils and luautils.walkAdj and luautils.walkAdj(player,square)==false then return end
    local tool=details.tool
    if tool and tool.item and ISInventoryPaneContextMenu then ISInventoryPaneContextMenu.transferIfNeeded(player,tool.item)end
    if tool and tool.item and ISEquipWeaponAction and player.getPrimaryHandItem and player:getPrimaryHandItem()~=tool.item then
        ISTimedActionQueue.add(ISEquipWeaponAction:new(player,tool.item,50,true,tool.kind~="trowel"))
    end
    ISTimedActionQueue.add(ISGroundWorksDigAction:new(player,square,tool,details.volumeType,details.op,details.media,details.sectionId,details.direction))
end

local function queueDig(player,square,volumeType)
    local ok,details=groundWorks.HandTools.canExcavate(player,square,volumeType)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end
local function queueRoute(player,square,op,routeId)
    local ok,details=require('groundWorks/RouteWork').plan(player,square,op,routeId)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end

local function queueDeepen(player,square)
    local ok,details=groundWorks.HandTools.canDeepen(player,square)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end

local function queueFill(player,square)
    local ok,details=groundWorks.HandTools.canFill(player,square)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end

local function queuePour(player,square,media)
    local ok,details=groundWorks.HandTools.canPour(player,square,media)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end

local function queueIgnite(player,square)
    local ok,details=groundWorks.HandTools.canIgnite(player,square)
    if not ok then say(player,false,details);return end
    queueWork(player,square,details)
end

local function addMenu(playerIndex,context,worldObjects,test)
    if not groundWorks or not groundWorks.HandTools or not groundWorks.HandTools.enabled()then return end
    local player=getSpecificPlayer(playerIndex)
    if not player or player:getVehicle()then return end
    local square=squareFrom(worldObjects,player)
    if not square then return end
    local HandTools=groundWorks.HandTools
    local any
    local function submenu()
        if test then return true end
        if not any then
            local root=context:addOption(getText("ContextMenu_groundWorks_HandExcavate"),nil,nil)
            any=ISContextMenu:getNew(context)
            context:addSubMenu(root,any)
        end
        return any
    end
    for _,action in ipairs(HandTools.ACTIONS)do
        local ok=HandTools.canExcavate(player,square,action.volumeType)
        if ok then
            local menu=submenu();if menu==true then return true end
            menu:addOption(getText(action.labelKey),player,queueDig,square,action.volumeType)
        end
    end
    local RouteWork=require 'groundWorks/RouteWork'
    for _,option in ipairs(RouteWork.OPTIONS)do
        local ok=RouteWork.plan(player,square,option.op,option.route)
        if ok then
            local menu=submenu();if menu==true then return true end
            menu:addOption(option.label,player,queueRoute,square,option.op,option.route)
        end
    end
    local deepenOk=HandTools.canDeepen(player,square)
    if deepenOk then
        local menu=submenu();if menu==true then return true end
        menu:addOption(getText("ContextMenu_groundWorks_DigDeeper"),player,queueDeepen,square)
    end
    local fillOk=HandTools.canFill(player,square)
    if fillOk then
        local menu=submenu();if menu==true then return true end
        menu:addOption(getText("ContextMenu_groundWorks_FillDirt"),player,queueFill,square)
    end
    for _,media in ipairs({"water","concrete","fuel"})do
        local pourOk=HandTools.canPour(player,square,media)
        if pourOk then
            local menu=submenu();if menu==true then return true end
            local key=media=="water"and"ContextMenu_groundWorks_PourWater"
                or media=="concrete"and"ContextMenu_groundWorks_PourConcrete"
                or"ContextMenu_groundWorks_AddFuel"
            menu:addOption(getText(key),player,queuePour,square,media)
        end
    end
    local igniteOk=HandTools.canIgnite(player,square)
    if igniteOk then
        local menu=submenu();if menu==true then return true end
        menu:addOption(getText("ContextMenu_groundWorks_LightFire"),player,queueIgnite,square)
    end
end

Events.OnFillWorldObjectContextMenu.Add(addMenu)

Events.OnServerCommand.Add(function(module,command,args)
    if module~="groundWorks"then return end
    if command~="handOperateResult"then return end
    local player=getPlayer()
    if player and type(args)=="table"and args.message then player:Say(tostring(args.message))end
end)

print("[groundWorks][HandTools] Native excavation, fill, pour and fire ready")
