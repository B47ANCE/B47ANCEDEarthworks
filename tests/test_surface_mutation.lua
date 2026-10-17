package.loaded["groundWorks/API"]=nil;groundWorks=nil
local Mutation=dofile(arg[1])
local sprites={old={name="old"},road={name="road"}}
for _,sprite in pairs(sprites)do function sprite:getName()return self.name end end
local floor={sprite=sprites.old}
function floor:getSprite()return self.sprite end
function floor:setSprite(sprite)if self.reject then return false end;self.sprite=sprite end
function floor:transmitUpdatedSpriteToClients()if self.transmitFails then error("network")end;self.sent=(self.sent or 0)+1 end
local square={floor=floor}
function square:getFloor()return self.floor end
function square:RecalcAllWithNeighbours()self.recalculated=(self.recalculated or 0)+1 end
local function resolver(name)return sprites[name]end

isClient=function()return false end;isServer=function()return true end
local ok,receipt=Mutation.replaceFloorSprite(square,"road",{resolveSprite=resolver,requireRecalculation=true})
assert(ok and receipt.before=="old"and receipt.after=="road"and floor.sent==1 and square.recalculated==1)
assert(Mutation.replaceFloorSprite(square,"road",{resolveSprite=resolver})==true,"same sprite must be idempotent")
assert(not Mutation.replaceFloorSprite(square,"missing",{resolveSprite=resolver})and floor.sprite==sprites.road)

floor.sprite=sprites.old;floor.reject=true
local failed,reason,details=Mutation.replaceFloorSprite(square,"road",{resolveSprite=resolver})
assert(not failed and details.rolledBack and reason:find("rollback verified",1,true)and floor.sprite==sprites.old)

floor.reject=false;floor.transmitFails=true
failed,reason,details=Mutation.replaceFloorSprite(square,"road",{resolveSprite=resolver})
assert(not failed and details.committed and details.replicationUncertain and floor.sprite==sprites.road,
    "unprovable replication must report committed recovery state rather than guessing rollback")

isClient=function()return true end;isServer=function()return false end
assert(Mutation.replaceFloorSprite(square,"old",{resolveSprite=resolver})==false and floor.sprite==sprites.road)
print("groundWorks recoverable native floor-sprite adapter checks passed")
