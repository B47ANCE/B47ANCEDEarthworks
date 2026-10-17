-- CAT owns the text; Knowledge & Wisdom owns the physical items and knowledge.
-- Called by CAT's authority-side loaded-vehicle recovery pass.
local Manuals={}
function Manuals.ensure(vehicle)
    if isClient and isClient()then return false end
    if not vehicle or type(vehicle.getPartById)~='function'then return false end
    local mods=getActivatedMods and getActivatedMods()
    if not mods or not mods:contains('CATConstruction')or not mods:contains('B47ANCEDEarthworks')
        or not mods:contains('B47ANCEDKnowledgeAndWisdom')then return false end
    local loaded,CC=pcall(require,'CATConstruction/Catalog')
    if not loaded or type(CC)~='table'or type(CC.getVehicleDefinition)~='function'then return false end
    local definition=CC.getVehicleDefinition(vehicle)
    if not definition or type(definition.id)~='string'or#definition.id==0 or#definition.id>96 then return false end
    local part=vehicle:getPartById('GloveBox')
    local container=part and part:getItemContainer()
    if not container then return false end
    local data=part:getModData()
    if type(data)~='table'then return false end
    local itemType='B47ANCEDKnowledgeAndWisdom.CC_Manual_'..definition.id
    -- Old saves can retain either the old book or its issuance marker. Neither
    -- allows another book to be spawned, even if the original was taken away.
    local legacyItemType='experienceWorks.CC_Manual_'..definition.id
    if data.groundWorksManualIssued==itemType or data.groundWorksManualIssued==legacyItemType then return true end
    -- The item framework is optional. Retry if it becomes available later.
    if not ScriptManager or not ScriptManager.instance or not ScriptManager.instance:FindItem(itemType)then return false end
    if not container:contains(itemType)and not container:contains(legacyItemType)then
        local item=container:AddItem(itemType)
        if not item then return false end
        if isServer and isServer()then sendAddItemToContainer(container,item)end
    end
    -- Persist issuance, not possession: taking a manual must never refill it.
    data.groundWorksManualIssued=itemType
    if isServer and isServer()then vehicle:transmitPartModData(part)end
    return true
end
return Manuals
