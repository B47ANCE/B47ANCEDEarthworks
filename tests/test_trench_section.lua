package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/TrenchSection"]=nil
_G.groundWorks=nil
require "groundWorks/API"
local TrenchSection=require "groundWorks/TrenchSection"
TrenchSection._resetForTests()

assert(TrenchSection.register{id="test.straight",length=3}~=nil)
assert(TrenchSection.register{id="test.ramp",length=4,ramp=true}~=nil)
assert(TrenchSection.get("test.straight").length==3)

local plan,err=TrenchSection.plan(10,20,"test.straight","east","op.1")
assert(plan and err==nil,"straight plan must succeed")
assert(plan.schemaVersion==1 and #plan.cells==3 and #plan.openings==3)
assert(plan.cells[1].x==10 and plan.cells[1].y==20 and plan.cells[1].z==-1)
assert(plan.cells[2].x==11 and plan.cells[3].x==12,"cells must extend east")
assert(plan.cells[1].walls.west==true,"west end must have a wall")
assert(plan.cells[3].walls.east==true,"east end must have a wall")
assert(plan.cells[2].walls.west==false and plan.cells[2].walls.east==false,"interior ends are open")
assert(plan.cells[1].walls.north==true and plan.cells[1].walls.south==true,"sides must have walls")
assert(type(plan.walls)=="table" and plan.walls.north~=nil and plan.walls.west~=nil,"plan must carry wall sprites")

local rampPlan=TrenchSection.plan(10,20,"test.ramp","north","op.2")
assert(rampPlan and #rampPlan.cells==4 and rampPlan.ramp==true)
assert(rampPlan.cells[1].y==20 and rampPlan.cells[4].y==17,"ramp must extend north")

assert(TrenchSection.plan(10,20,"test.missing","east","op.3")==nil,"unknown section must fail")
local dupOk=pcall(function()TrenchSection.register{id="test.straight",length=3}end)
assert(dupOk==false,"duplicate section id must be rejected")

local surface={x=10,y=20,z=0}
function surface:getX()return self.x end
function surface:getY()return self.y end
function surface:getFloor()return nil end

local function makeAdapter(failFloor)
    local squares={}
    local function key(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
    squares[key(surface.x,surface.y,0)]=surface
    local function sq(x,y,z)
        local k=key(x,y,z)
        if not squares[k]then
            local s={x=x,y=y,z=z,floor=nil}
            function s:getFloor()return self.floor end
            squares[k]=s
        end
        return squares[k]
    end
    local placed=0;local removed=0;local walls=0
    return{
        getOrCreateSquare=function(x,y,z)return sq(x,y,z)end,
        getSquare=function(x,y,z)return sq(x,y,z)end,
        placeFloor=function(square,sprite,op)
            if failFloor then return false end
            square.floor={sprite=sprite,op=op};placed=placed+1;return true end,
        placeWall=function(square,sprite,side)walls=walls+1;return true end,
        removeFloor=function(square)square.floor=nil;removed=removed+1;return true end,
        setConstructed=function()return true end,
        verifyFloor=function(x,y,z,op)local s=squares[key(x,y,z)];return s and s.floor and s.floor.op==op end,
        removeObject=function()return true end,
        _placed=function()return placed end,
        _removed=function()return removed end,
        _walls=function()return walls end,
        _floorAt=function(x,y,z)local s=squares[key(x,y,z)];return s and s.floor or nil end,
    }
end

local ok,receipt=TrenchSection.commit(surface,"test.straight","east","op.commit.1",makeAdapter())
assert(ok and receipt.committed==true)
assert(#receipt.cells==3 and #receipt.openings==3)
assert(receipt.cells[1].verified==true)

local wallAdapter=makeAdapter()
local wallOk=TrenchSection.commit(surface,"test.straight","east","op.commit.walls",wallAdapter)
assert(wallOk and wallAdapter._walls()==8,"a straight section must place 8 wall objects")

local failAdapter=makeAdapter(true)
local failOk,failReason,failReceipt=TrenchSection.commit(surface,"test.straight","east","op.commit.2",failAdapter)
assert(failOk==false and failReceipt.committed==false and failReceipt.rolledBack==true,"failed commit must roll back")

local clientAdapter=makeAdapter()
isClient=function()return true end
isServer=function()return false end
assert(TrenchSection.commit(surface,"test.straight","east","op.commit.3",clientAdapter)==false,"clients must not commit")
isClient=nil;isServer=nil

TrenchSection._resetForTests()
print("groundWorks trench-section prefab checks passed")
