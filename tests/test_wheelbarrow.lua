groundWorks={inspectSurface=function(square)return square.surface end}
package.loaded["groundWorks/API"]=groundWorks

local Wheelbarrow=dofile(arg[1])

local data={}
local container={weight=14,getContentsWeight=function(self)return self.weight end}
local object={
    getObjectName=function()return"Pushable"end,
    getModData=function()return data end,
    getContainer=function()return container end,
}

assert(not Wheelbarrow.isWheelbarrow(object),"untagged pushable must not be adopted")
assert(Wheelbarrow.tag(object))
assert(Wheelbarrow.isWheelbarrow(object),"native type plus persistent identity must match")
data.version=2
assert(not Wheelbarrow.isWheelbarrow(object),"unknown identity schema must fail closed")
data.version=1

local load=Wheelbarrow.getLoad(object)
assert(load.emptyWeight==6 and load.contentsWeight==14 and load.grossWeight==20,
    "gross load must use the native container contents")
assert(Wheelbarrow.getTerrainResistance({surface={material="paved road"}})==1)
assert(Wheelbarrow.getTerrainResistance({surface={material="mud"}})==2)
assert(Wheelbarrow.getTerrainResistance({surface={material="dirt"}})==1.35)
assert(Wheelbarrow.isTrenchSquare({getZ=function()return-1 end}))
assert(Wheelbarrow.isTrenchSquare({getZ=function()return 0 end,getModData=function()return{["groundWorks.trench.open.v1"]=true}end}))
assert(not Wheelbarrow.isTrenchSquare({getZ=function()return 0 end,getModData=function()return{}end}))

print("groundWorks verified wheelbarrow identity, native load, terrain, and trench policy checks passed")
local square={getZ=function()return 0 end,getModData=function()return{}end,isBlockedTo=function()return false end}
function object:getSquare()return square end
function object:getX()return 0 end;function object:getY()return 0 end
local actor={getSquare=function()return square end,isDead=function()return false end,getVehicle=function()end,
    getX=function()return 1 end,getY=function()return 0 end}
assert(Wheelbarrow.canHandle(actor,object))
container.weight=101;assert(not Wheelbarrow.canHandle(actor,object));container.weight=14
groundWorks.Cavity={inspect=function()return{status='created',sealed=false}end}
assert(Wheelbarrow.isTrenchSquare(square),'Current cavity receipts must block wheelbarrow handling.')
assert(not Wheelbarrow.canHandle(actor,object))
groundWorks.Cavity=nil
isClient=function()return true end
assert(not Wheelbarrow.spawn(square));assert(not Wheelbarrow.remove(object))
isClient=nil
print('Wheelbarrow overload, current cavity and client mutation rejection passed')
