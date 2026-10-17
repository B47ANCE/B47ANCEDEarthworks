package.loaded["groundWorks/API"]=nil;package.loaded["groundWorks/Projects"]=nil
package.loaded["groundWorks/SurfaceMutation"]=nil;groundWorks=nil
local Routes=dofile(arg[1])
Routes.register{id="fixture.gravelPath",projectType="groundWorks.constructedPath",floorSprite="fixture_gravel_01_0",
    workRequired=4,requirements={["Base.Gravelbag"]=2}}
local sprites={natural={name="natural"},fixture_gravel_01_0={name="fixture_gravel_01_0"}}
for _,value in pairs(sprites)do function value:getName()return self.name end end
local props={has=function(_,key)return key=="grassFloor"end,get=function()return"true"end}
function sprites.natural:getProperties()return props end
local floor={sprite=sprites.natural,getSprite=function(self)return self.sprite end,setSprite=function(self,value)self.sprite=value end,
    transmitUpdatedSpriteToClients=function(self)self.sent=(self.sent or 0)+1 end}
local root={};local square={getFloor=function()return floor end,getModData=function()return root end,
    transmitModdata=function(self)self.sent=(self.sent or 0)+1 end,RecalcAllWithNeighbours=function(self)self.recalc=(self.recalc or 0)+1 end}
isClient=function()return false end;isServer=function()return true end
local ok,result=Routes.begin(square,"fixture.gravelPath","begin",{});assert(ok and not result.duplicate)
local consumed=0
ok,result=Routes.contributeMaterial(square,"Base.Gravelbag",2,"material",{id="fixture.inventory",consume=function(amount)consumed=consumed+amount;return true,"two-bags"end},{})
assert(ok and consumed==2 and result.accepted==2)
ok,result=Routes.advanceWork(square,4,"work","worker");assert(ok and result.ready and floor.sprite==sprites.natural,"ready work must not mutate early")
ok,result=Routes.commit(square,"commit",{resolveSprite=function(name)return sprites[name]end});assert(ok and result.state.status=="completed")
assert(floor.sprite==sprites.fixture_gravel_01_0 and floor.sent==1 and square.recalc==1)
local snapshot=assert(Routes.snapshot(square));assert(snapshot.route.routeId=="fixture.gravelPath"and snapshot.project.result.commitReceipt.after=="fixture_gravel_01_0")
assert(Routes.commit(square,"commit",{resolveSprite=function()error("duplicate mutation")end}),"commit replay must be harmless")
local rollbackRoot={};local rollbackFloor={sprite=sprites.natural,getSprite=floor.getSprite,setSprite=function()error("write rejected")end}
local rollbackSquare={getFloor=function()return rollbackFloor end,getModData=function()return rollbackRoot end,transmitModdata=function()end,
    RecalcAllWithNeighbours=function()end}
assert(Routes.begin(rollbackSquare,"fixture.gravelPath","rollback-begin",{}))
assert(Routes.contributeMaterial(rollbackSquare,"Base.Gravelbag",2,"rollback-material",{id="fixture.inventory",consume=function()return true end},{}))
assert(Routes.advanceWork(rollbackSquare,4,"rollback-work","worker"))
assert(not Routes.commit(rollbackSquare,"rollback-commit",{resolveSprite=function(name)return sprites[name]end}))
local rollbackSnapshot=assert(Routes.snapshot(rollbackSquare));assert(rollbackSnapshot.project.status=="ready"and not rollbackSnapshot.worldRecovery.requiresInspection)
local Projects=require "groundWorks/Projects"
local conflictRoot={[Routes.ROOT_KEY]={schemaVersion=1,routeId="other"}}
local conflictSquare={getFloor=function()return rollbackFloor end,getModData=function()return conflictRoot end}
assert(not Routes.begin(conflictSquare,"fixture.gravelPath","conflict",{}))
assert(conflictRoot[Projects.ROOT_KEY]==nil,"metadata rejection must not leave a project behind")
conflictRoot[Routes.ROOT_KEY]=true
assert(not Routes.begin(conflictSquare,"fixture.gravelPath","malformed",{}),"malformed metadata must fail without throwing")
conflictRoot[Routes.ROOT_KEY]=nil
assert(Projects.begin(conflictSquare,"groundWorks.constructedPath","foreign",{workRequired=1,requirements={}}))
assert(not Routes.begin(conflictSquare,"fixture.gravelPath","foreign",{}),"operation replay cannot adopt a foreign project")
assert(conflictRoot[Routes.ROOT_KEY]==nil)
local cyclic={};cyclic.bad=cyclic
assert(not pcall(Routes.register,{id="fixture.invalid",projectType="groundWorks.constructedPath",floorSprite="fixture",workRequired=1,requirements=cyclic}))
assert(Routes.get("fixture.invalid")==nil)
assert(Routes.register{id="fixture.invalid",projectType="groundWorks.constructedPath",floorSprite="fixture",workRequired=1,requirements={["Base.Gravelbag"]="2"}}.requirements["Base.Gravelbag"]==2)
print("groundWorks constructed-route deferred commit checks passed")
