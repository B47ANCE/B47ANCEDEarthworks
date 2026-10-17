local Barrow=require 'groundWorks/Wheelbarrow'
local Heavy=require 'groundWorks/HeavyObjectIntegration'
local Transactions={ID='groundWorks.wheelbarrow.v1'}
local function identity(object)
    local data=object:getModData()
    if not data.wheelbarrowId then
        Transactions.serial=(Transactions.serial or 0)+1
        data.wheelbarrowId='barrow.'..getTimestampMs()..'.'..Transactions.serial
    end
    return data.wheelbarrowId
end
local function resolve(id)
    local objects=getCell():getPushableObjectList()
    for i=0,math.min(objects:size(),4096)-1 do
        local object=objects:get(i)
        if Barrow.isWheelbarrow(object)and object:getModData().wheelbarrowId==id then return object end
    end
end
local function release(actor,object)
    if actor:getDragObject()==object then actor:setDragObject(nil)end
    if actor:getDragObject()==object then return false,'Native controller did not release.'end
    object:getModData().wheelbarrowOperator=nil
    return true,{}
end
function Transactions.install()
    if Transactions.installed then return true end
    if isClient()or not getActivatedMods():contains('itjustWorks')then return false end
    local owner=require 'itjustWorks/HeavyObjects';Heavy.attach(owner)
    owner.registerProvider{id=Transactions.ID,priority=100,matches=Barrow.isWheelbarrow,
        getStableId=identity,resolveStableId=resolve,getActorId=function(actor)return actor:getUsername()end,
        observe=function(actor,object)
            local allowed,reason=Barrow.canHandle(actor,object)
            local operator=object:getModData().wheelbarrowOperator
            if operator and operator~=actor:getUsername()then allowed=false;reason='Another worker has reserved the wheelbarrow.'end
            if actor:getDragObject()and actor:getDragObject()~=object then allowed=false;reason='Release the other object first.'end
            return{operations={push={supported=true,eligible=allowed==true,reason=reason}}}
        end,
        reserve=function(actor,object)object:getModData().wheelbarrowOperator=actor:getUsername();return true,{}end,
        start=function(actor,object)
            actor:setDragObject(object)
            return actor:getDragObject()==object,{}
        end,
        complete=release,cancel=release}
    Transactions.installed=true
    return true
end
function Transactions.advance(actor,object,phase,id)
    if not Transactions.install()then return false,'Heavy-object framework unavailable.'end
    return Heavy.advance(actor,object,'push',phase,id)
end
return Transactions
