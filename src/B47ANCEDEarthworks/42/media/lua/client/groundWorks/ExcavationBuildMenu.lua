require "ISUI/ISPanel"
require "ISUI/ISComboBox"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "TimedActions/ISTimedActionQueue"
local Presets = require "groundWorks/ExcavationPresets"
local Build = require "groundWorks/ExcavationBuild"
local BuildAction = require "groundWorks/ISGroundWorksBuildAction"

local Menu = {}
local windows = {}
local directionLabels = { north="North", east="East", south="South", west="West" }
local labels = { ["Base.Plank"]="Planks", ["Base.Nails"]="Nails" }

local function inside(player)
    return player and Build.isInside and Build.isInside(player) == true
end

local function notify(player,message)
    if player and player.Say then player:Say(tostring(message)) end
end

local function cloneSpec(spec)
    return {presetId=spec.presetId,direction=spec.direction,x=spec.x,y=spec.y,z=spec.z}
end

local function clockTime()
    return getTimestampMs and getTimestampMs() or 0
end

local function inspect(player,spec)
    local valid, result, failedDetails = Build.check(player,spec)
    return valid == true, valid and result or failedDetails, valid and nil or tostring(result)
end

local function queue(player,spec)
    local valid, details, reason = inspect(player,spec)
    if not valid then notify(player,reason); return false end
    local tool = details and details.tool
    local item = tool and tool.item
    if item and ISInventoryPaneContextMenu then
        ISInventoryPaneContextMenu.transferIfNeeded(player,item)
    end
    ISTimedActionQueue.add(BuildAction:new(player,spec))
    return true
end

-- Vanilla registers the legacy building base from its server Lua directory
-- after client scripts start loading. Resolve it only when a world is active.
ISGroundWorksBuildCursor = {Type="ISGroundWorksBuildCursor"}
local function ensureCursorClass()
    if ISGroundWorksBuildCursor._nativeBaseReady then return true end
    if not ISBuildingObject then require "BuildingObjects/ISBuildingObject" end
    if not ISBuildingObject then return false end
    setmetatable(ISGroundWorksBuildCursor,ISBuildingObject)
    ISBuildingObject.__index = ISBuildingObject
    ISGroundWorksBuildCursor._nativeBaseReady = true
    return true
end

function ISGroundWorksBuildCursor:getSprite()
    self.spec.direction = Presets.DIRECTIONS[self.nSprite or 1]
    return self.sprite
end

-- Keep the chosen underground anchor while the mouse confirms the blueprint.
-- Native keyboard/controller rotation still changes nSprite normally.
function ISGroundWorksBuildCursor:rotateMouse(x,y)
end

function ISGroundWorksBuildCursor:refresh(force)
    local now = clockTime()
    local direction = Presets.DIRECTIONS[self.nSprite or 1]
    if force or not self.checkedAt or now == 0 or now-self.checkedAt >= 250
        or self.checkedDirection ~= direction then
        self.spec.direction = direction
        self.valid, self.details, self.reason = inspect(self.character,self.spec)
        self.plan = self.details and self.details.plan or Presets.plan(self.spec)
        self.checkedAt = now
        self.checkedDirection = direction
    end
end

function ISGroundWorksBuildCursor:isValid(square)
    self:refresh(false)
    return inside(self.character) and self.valid == true
end

function ISGroundWorksBuildCursor:render(x,y,z,square)
    self:refresh(false)
    if not self.plan then return end
    local color = self.valid and getCore():getGoodHighlitedColor() or getCore():getBadHighlitedColor()
    local sprite = self:getFloorCursorSprite()
    for _,cell in ipairs(self.plan.cells) do
        sprite:RenderGhostTileColor(cell.x,cell.y,cell.z,color:getR(),color:getG(),color:getB(),0.65)
    end
    for _,edge in ipairs(self.plan.edges) do
        local frame = edge.north and self.frameNorth or self.frameWest
        frame:RenderGhostTileColor(edge.x,edge.y,edge.z,color:getR(),color:getG(),color:getB(),0.6)
    end
    -- A blue anchor distinguishes the occupied starting tile and direction.
    sprite:RenderGhostTileColor(self.spec.x,self.spec.y,self.spec.z,0.25,0.65,1.0,0.85)
end

function ISGroundWorksBuildCursor:create(x,y,z,north,sprite)
    self:refresh(true)
    if not self.valid then notify(self.character,self.reason); return end
    getCell():setDrag(nil,self.player)
    queue(self.character,cloneSpec(self.spec))
end

function ISGroundWorksBuildCursor:tryBuild(x,y,z)
    self:create(x,y,z)
end

function ISGroundWorksBuildCursor:new(player,spec)
    if not ensureCursorClass() then return nil end
    local cursor = {}
    setmetatable(cursor,self)
    self.__index = self
    cursor:init()
    cursor.character, cursor.player = player, player:getPlayerNum()
    cursor.spec = cloneSpec(spec)
    cursor.noNeedHammer, cursor.skipBuildAction, cursor.skipWalk2 = true,true,true
    cursor.dragNilAfterPlace = true
    cursor:setSprite("carpentry_02_56")
    cursor:setNorthSprite("carpentry_02_56")
    cursor.frameNorth, cursor.frameWest = IsoSprite.new(), IsoSprite.new()
    cursor.frameNorth:LoadFramesNoDirPageSimple("carpentry_02_101")
    cursor.frameWest:LoadFramesNoDirPageSimple("carpentry_02_100")
    for index,direction in ipairs(Presets.DIRECTIONS) do
        if direction == spec.direction then cursor.nSprite = index end
    end
    cursor:refresh(true)
    return cursor
end

ISGroundWorksBuildPanel = ISPanel:derive("ISGroundWorksBuildPanel")

function ISGroundWorksBuildPanel:currentSpec()
    local recipe = self.recipe.options[self.recipe.selected]
    local direction = self.direction.options[self.direction.selected]
    if not recipe or not direction then return nil end
    return {
        presetId=recipe.data,direction=direction.data,
        x=self.anchorX,y=self.anchorY,z=self.anchorZ,
    }
end

function ISGroundWorksBuildPanel:refresh()
    local spec = self:currentSpec()
    if not spec then return end
    self.valid, self.details, self.reason = inspect(self.playerObj,spec)
    self.plan = self.details and self.details.plan or Presets.plan(spec)
    self.materialLines = {}
    local materials = self.details and self.details.materials or {}
    local keys = {}
    for itemType in pairs(materials) do keys[#keys+1]=itemType end
    table.sort(keys)
    for _,itemType in ipairs(keys) do
        local name = labels[itemType] or itemType
        self.materialLines[#self.materialLines+1] = name .. ": " .. tostring(materials[itemType])
    end
    self.previewButton:setEnable(inside(self.playerObj))
    self.lastRefresh = clockTime()
end

function ISGroundWorksBuildPanel:onSelectionChanged(combo)
    if self.previewButton then self:refresh() end
end

function ISGroundWorksBuildPanel:onPreview()
    if not inside(self.playerObj) then
        notify(self.playerObj,getText("IGUI_groundWorks_EnterExcavationSupports"))
        return
    end
    local spec = self:currentSpec()
    if not spec then return end
    local cursor = ISGroundWorksBuildCursor:new(self.playerObj,spec)
    if not cursor then
        notify(self.playerObj,"The building controls are not ready yet. Reopen construction after the world finishes loading.")
        return
    end
    getCell():setDrag(cursor,self.playerObj:getPlayerNum())
    self:close()
    notify(self.playerObj,"Blueprint anchored at your tile. Rotate building changes direction; left-click builds, right-click cancels.")
end

function ISGroundWorksBuildPanel:close()
    self:setVisible(false)
    self:removeFromUIManager()
    windows[self.playerObj:getPlayerNum()] = nil
end

function ISGroundWorksBuildPanel:createChildren()
    ISPanel.createChildren(self)
    local row = self.lineHeight
    local controlY = 95
    self.recipe = ISComboBox:new(20,controlY,self.width-40,row+9,self,self.onSelectionChanged)
    self.recipe:initialise()
    self:addChild(self.recipe)
    local receipt = groundWorks.Cavity and groundWorks.Cavity.inspect(self.playerObj:getCurrentSquare())
    local selectedKind = receipt and receipt.volumeType
    local selected
    for index,definition in ipairs(Presets.list()) do
        self.recipe:addOptionWithData(definition.label,definition.id)
        if not selected and definition.volumeType == selectedKind then selected=index end
    end
    self.recipe.selected = selected or 1
    controlY = controlY+row+43
    self.direction = ISComboBox:new(20,controlY,self.width-40,row+9,self,self.onSelectionChanged)
    self.direction:initialise()
    self:addChild(self.direction)
    for _,direction in ipairs(Presets.DIRECTIONS) do
        self.direction:addOptionWithData(directionLabels[direction],direction)
    end
    self.bodyY = controlY+row+24
    self.previewButton = ISButton:new(20,self.height-row-28,230,row+9,"Preview footprint",self,self.onPreview)
    self.previewButton:initialise()
    self:addChild(self.previewButton)
    self.closeButton = ISButton:new(self.width-120,self.height-row-28,100,row+9,"Close",self,self.close)
    self.closeButton:initialise()
    self:addChild(self.closeButton)
    self:refresh()
end

local function drawWrapped(panel,text,x,y,width,color)
    local line = ""
    for word in tostring(text):gmatch("%S+") do
        local candidate = line == "" and word or line .. " " .. word
        if line ~= "" and getTextManager():MeasureStringX(UIFont.Small,candidate) > width then
            panel:drawText(line,x,y,color[1],color[2],color[3],1,UIFont.Small)
            y = y+panel.lineHeight
            line = word
        else line = candidate end
    end
    if line ~= "" then
        panel:drawText(line,x,y,color[1],color[2],color[3],1,UIFont.Small)
        y = y+panel.lineHeight
    end
    return y
end

function ISGroundWorksBuildPanel:prerender()
    ISPanel.prerender(self)
    if not self.recipe then return end
    local now = clockTime()
    if now == 0 or not self.lastRefresh or now-self.lastRefresh >= 500 then self:refresh() end
    local row = self.lineHeight
    self:drawText(getText("ContextMenu_groundWorks_Construction"),20,15,0.95,0.78,0.42,1,UIFont.Medium)
    self:drawText("Excavate and secure a preset footprint",20,43,0.85,0.85,0.85,1,UIFont.Small)
    self:drawText("Recipe",20,self.recipe.y-row,1,1,1,1,UIFont.Small)
    self:drawText("Direction",20,self.direction.y-row,1,1,1,1,UIFont.Small)
    local y = self.bodyY
    self:drawText("Level " .. tostring(self.anchorZ) .. " | Anchor " .. self.anchorX .. ", " .. self.anchorY,
        20,y,0.72,0.82,0.90,1,UIFont.Small)
    y = y+row+9
    if self.plan then
        self:drawText(tostring(#self.plan.cells) .. " floor tiles | " .. tostring(#self.plan.edges) .. " perimeter edges",
            20,y,1,1,1,1,UIFont.Small)
        y = y+row+7
    end
    if #self.materialLines > 0 then
        self:drawText("Materials required",20,y,0.95,0.78,0.42,1,UIFont.Small)
        y = y+row
        for _,line in ipairs(self.materialLines) do
            self:drawText(line,20,y,0.9,0.9,0.9,1,UIFont.Small)
            y = y+row
        end
    end
    if self.details and self.details.frames then
        self:drawText("Remaining: " .. tostring(self.details.missingLayers or 0) .. " excavation levels, "
            .. tostring(self.details.frames) .. " frames",20,y,0.9,0.9,0.9,1,UIFont.Small)
        y = y+row
    end
    y = y+8
    local status = self.valid and "Ready to preview and build." or self.reason or "Choose a recipe."
    y = drawWrapped(self,status,20,y,self.width-40,self.valid and {0.5,1,0.6} or {1,0.65,0.5})+8
    y = drawWrapped(self,"Already excavated tiles reduce the work. Completed framing secures the footprint against collapse.",
        20,y,self.width-40,{0.77,0.77,0.77})+6
    drawWrapped(self,"Preview includes the entire footprint. Blue marks your anchor. The building rotation key changes direction.",
        20,y,self.width-40,{0.77,0.77,0.77})
end

function ISGroundWorksBuildPanel:new(player)
    local width = 560
    local lineHeight = getTextManager():getFontHeight(UIFont.Small)
    local height = math.max(510,lineHeight*24+110)
    local panel = ISPanel.new(self,math.max(0,(getCore():getScreenWidth()-width)/2),
        math.max(0,(getCore():getScreenHeight()-height)/2),width,height)
    panel.playerObj = player
    panel.anchorX,panel.anchorY,panel.anchorZ = math.floor(player:getX()),math.floor(player:getY()),math.floor(player:getZ())
    panel.lineHeight = lineHeight
    panel.backgroundColor = {r=0.075,g=0.08,b=0.085,a=0.97}
    panel.borderColor = {r=0.55,g=0.4,b=0.2,a=1}
    panel.moveWithMouse = true
    return panel
end

function Menu.open(player)
    if not inside(player) then return end
    local index = player:getPlayerNum()
    if windows[index] then windows[index]:close() end
    local panel = ISGroundWorksBuildPanel:new(player)
    panel:initialise()
    panel:addToUIManager()
    windows[index] = panel
end

function Menu.onContext(playerIndex,context,worldObjects,test)
    local player = getSpecificPlayer(playerIndex)
    if not inside(player) then return end
    if test then return true end
    context:addOption(getText("ContextMenu_groundWorks_Construction"),player,Menu.open)
end

local function cancelCursor()
    local cell = getCell()
    if not cell then return end
    for index=0,3 do
        local drag = cell:getDrag(index)
        if drag and drag.Type == "ISGroundWorksBuildCursor" then cell:setDrag(nil,index) end
    end
end

if not groundWorks._excavationBuildMenuEvents then
    groundWorks._excavationBuildMenuEvents = true
    Events.OnFillWorldObjectContextMenu.Add(Menu.onContext)
    Events.OnRightMouseDown.Add(cancelCursor)
    Events.OnKeyPressed.Add(function(key)
        if Keyboard and key == Keyboard.KEY_ESCAPE then cancelCursor() end
    end)
end

groundWorks.ExcavationBuildMenu = Menu
return Menu
