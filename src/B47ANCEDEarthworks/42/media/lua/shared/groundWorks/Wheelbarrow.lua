local groundWorks=require "groundWorks/API"

-- Lua-only feasibility surface for a native Build 42 pushable. Runtime calls
-- are deliberately guarded so an unavailable binding fails as probe evidence
-- instead of corrupting world membership.
local Wheelbarrow={
    TYPE="groundWorks:wheelbarrow",
    SCHEMA_VERSION=1,
    DEFAULT_SPRITE="carpentry_02_80", -- temporary feasibility-spike art
    CAPACITY=100,
    EMPTY_WEIGHT=6,
}

local function call(object,method,...)
    if not object then return false,nil,"missing object" end
    local ok,fn=pcall(function()return object[method]end)
    if not ok or type(fn)~="function"then return false,nil,"missing method: "..method end
    local ran,result=pcall(fn,object,...)
    return ran,result,ran and nil or tostring(result)
end

function Wheelbarrow.isWheelbarrow(object)
    if not object then return false end
    local native=false
    if type(rawget(_G,"instanceof"))=="function"then
        local ok,result=pcall(instanceof,object,"IsoPushableObject")
        native=ok and result==true
    else
        local ok,name=call(object,"getObjectName")
        native=ok and(name=="Pushable"or name=="WheelieBin")
    end
    if not native then return false end
    local ok,data=call(object,"getModData")
    return ok and type(data)=="table"and data.theWorksType==Wheelbarrow.TYPE
        and tonumber(data.version)==Wheelbarrow.SCHEMA_VERSION
end

function Wheelbarrow.tag(object)
    local ok,data,err=call(object,"getModData")
    if not ok or type(data)~="table"then return false,err or"modData unavailable"end
    data.theWorksType=Wheelbarrow.TYPE
    data.version=Wheelbarrow.SCHEMA_VERSION
    return true
end

function Wheelbarrow.createContainer(object,square)
    if not rawget(_G,"ItemContainer")or type(ItemContainer.new)~="function"then
        return nil,"ItemContainer constructor unavailable"
    end
    local ok,container=pcall(ItemContainer.new,"groundWorksWheelbarrow",square,object,1,1)
    if not ok or not container then return nil,"ItemContainer construction failed: "..tostring(container)end
    call(container,"setCapacity",Wheelbarrow.CAPACITY)
    call(container,"setParent",object)
    call(container,"setSourceGrid",square)
    local assigned=call(object,"setContainer",container)
    if not assigned then return nil,"pushable rejected container"end
    return container
end

function Wheelbarrow.spawn(square,spriteName)
    if type(isClient)=='function'and isClient()then return nil,'server authority required'end
    if not square then return nil,"square required"end
    local cell=type(rawget(_G,"getCell"))=="function"and getCell()or nil
    if not cell then return nil,"cell unavailable"end
    if not rawget(_G,"IsoPushableObject")or type(IsoPushableObject.new)~="function"then
        return nil,"IsoPushableObject constructor unavailable to Lua"
    end
    local sprite=nil
    if type(rawget(_G,"getSprite"))=="function"then
        local ok,result=pcall(getSprite,spriteName or Wheelbarrow.DEFAULT_SPRITE)
        if ok then sprite=result end
    end
    if not sprite then return nil,"sprite unavailable: "..tostring(spriteName or Wheelbarrow.DEFAULT_SPRITE)end
    local ok,object=pcall(IsoPushableObject.new,cell,square,sprite)
    if not ok or not object then return nil,"IsoPushableObject construction failed: "..tostring(object)end
    local tagged,tagErr=Wheelbarrow.tag(object)
    if not tagged then Wheelbarrow.remove(object);return nil,tagErr end
    local container,containerErr=Wheelbarrow.createContainer(object,square)
    if not container then Wheelbarrow.remove(object);return nil,containerErr end
    call(object,"setWeight",Wheelbarrow.EMPTY_WEIGHT)
    call(object,"setOutlineOnMouseover",true)
    local existsOk,exists=call(object,"isExistInTheWorld")
    if existsOk and exists==false then call(object,"addToWorld")end
    return object
end

function Wheelbarrow.remove(object)
    if type(isClient)=='function'and isClient()then return false,'server authority required'end
    if not Wheelbarrow.isWheelbarrow(object)then return false,"wheelbarrow required"end
    local _,container=call(object,'getContainer')
    if container then
        local ok,empty=call(container,'isEmpty')
        if not ok or empty~=true then return false,'Empty the wheelbarrow before removing it.'end
    end
    call(object,"removeFromWorld")
    call(object,"removeFromSquare")
    return true
end

function Wheelbarrow.getLoad(object)
    local _,container=call(object,"getContainer")
    local contents=0
    if container then local ok,value=call(container,"getContentsWeight");if ok then contents=tonumber(value)or 0 end end
    return{emptyWeight=Wheelbarrow.EMPTY_WEIGHT,contentsWeight=contents,grossWeight=Wheelbarrow.EMPTY_WEIGHT+contents}
end

function Wheelbarrow.getTerrainResistance(square)
    if not square then return 2 end
    local inspected=groundWorks.inspectSurface and groundWorks.inspectSurface(square)or nil
    local material=type(inspected)=="table"and tostring(inspected.material or inspected.kind or""):lower()or""
    if material:find("road",1,true)or material:find("paved",1,true)or material:find("floor",1,true)then return 1 end
    if material:find("mud",1,true)or material:find("loose",1,true)then return 2 end
    return 1.35
end

function Wheelbarrow.isTrenchSquare(square)
    if not square then return false end
    local z=tonumber(square:getZ())or 0
    if z<0 then return true end
    local data=type(square.getModData)=="function"and square:getModData()or nil
    if type(data)=='table'and data['groundWorks.trench.open.v1']~=nil then return true end
    local cavity=groundWorks.Cavity
    local receipt=cavity and cavity.inspect and cavity.inspect(square)
    return type(receipt)=='table'and receipt.status=='created'and receipt.sealed~=true
end

function Wheelbarrow.nearby(character,radius)
    local square=character and character:getSquare()
    if not square then return nil end
    radius=math.min(2,math.max(0,tonumber(radius)or 2))
    for x=square:getX()-radius,square:getX()+radius do for y=square:getY()-radius,square:getY()+radius do
        local target=getCell():getGridSquare(x,y,square:getZ())
        local objects=target and target:getMovingObjects()
        if objects then for i=0,objects:size()-1 do
            local object=objects:get(i)
            if Wheelbarrow.isWheelbarrow(object)and not square:isBlockedTo(target)then return object end
        end end
    end end
end

function Wheelbarrow.canHandle(character,object,unloading)
    if not character or character:isDead()or character:getVehicle()or not Wheelbarrow.isWheelbarrow(object)then return false,'Active worker and wheelbarrow required.'end
    local square=object:getSquare();local here=character:getSquare()
    if not square or not here or square:getZ()~=here:getZ()or Wheelbarrow.isTrenchSquare(square)or Wheelbarrow.isTrenchSquare(here)then return false,'Keep the wheelbarrow on solid ground.'end
    local dx,dy=character:getX()-object:getX(),character:getY()-object:getY()
    if dx*dx+dy*dy>6.25 or here:isBlockedTo(square)then return false,'Stand beside the wheelbarrow.'end
    if SafeHouse and not SafeHouse.isSafehouseAllowInteract(square,character)then return false,'No permission to handle this wheelbarrow.'end
    local _,container=call(object,'getContainer')
    local load=Wheelbarrow.getLoad(object)
    if not container or (not unloading and load.contentsWeight>Wheelbarrow.CAPACITY)then return false,'The wheelbarrow is overloaded.'end
    return true
end

groundWorks.Wheelbarrow=Wheelbarrow
return Wheelbarrow
