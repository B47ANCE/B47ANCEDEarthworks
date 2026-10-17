package.loaded["groundWorks/API"]=nil;groundWorks=nil
local API=require"groundWorks/API";local Experiment=dofile(arg[1])
local props={has=function(_,key)return key=="grassFloor"end,get=function()return"true"end}
local sprite={getName=function()return"blends_natural_01_8"end,getProperties=function()return props end}
local floor={getSprite=function()return sprite end}
local function surface(x,y,z)
    local value={data={},x=x or 10,y=y or 20,z=z or 0,getFloor=function()return floor end}
    function value:getX()return self.x end;function value:getY()return self.y end;function value:getZ()return self.z end
    function value:getModData()return self.data end;function value:transmitModdata()self.sent=(self.sent or 0)+1 end
    return value
end
local squares={}
local function key(x,y,z)return x..":"..y..":"..z end
local function adapter(options)
    options=options or{};local result={removed=0}
    function result.validateSprite(name)return not options.spriteMissing and name==Experiment.FLOOR_SPRITE end
    function result.isValidSquare()return options.invalid~=true end
    function result.getSquare(x,y,z)return squares[key(x,y,z)]end
    function result.validateSurface()return options.surfaceRejected~=true,options.surfaceRejected and"occupied"or nil end
    function result.createSquare(x,y,z)local sq={x=x,y=y,z=z,getFloor=function(self)return self.floor end};result.created=sq;return sq end
    function result.connectSquare(square)if options.connectFailure then return false end;squares[key(square.x,square.y,square.z)]=square;return true end
    function result.addFloor(square,name)if options.floorFailure then return nil end;local object={data={},square=square,name=name};square.floor=object;return object end
    function result.tagObject(object,operationId)object.data[Experiment.ROOT_KEY]={operationId=operationId};return true end
    function result.recalculate()return options.recalcFailure~=true end
    function result.transmitObject()return options.transmitFailure~=true end
    function result.verify(x,y,z,square,object,operationId)
        return not options.verifyFailure and squares[key(x,y,z)]==square and square.floor==object
            and object.data[Experiment.ROOT_KEY].operationId==operationId
    end
    function result.tagOpening()return true end
    function result.verifyOpening()return true end
    function result.untagOpening()return true end
    function result.removeObject(square,object)result.removed=result.removed+1;square.floor=nil;object.square=nil;return true end
    return result
end
isClient=function()return false end;isServer=function()return true end
local target=surface();local plan=assert(Experiment.plan(target));assert(plan.cells[1].z==-1 and plan.cells[1].x==10)
local world=adapter();local ok,receipt=Experiment.execute(target,"experiment-1",world)
assert(ok and receipt.status=="created"and receipt.verifiedLocal and not receipt.requiresInspection)
local current=assert(Experiment.verifyCurrent(target,world));assert(current.geometryResolved and current.squareResolved and current.floorResolved)
ok,receipt=Experiment.execute(target,"experiment-1",world);assert(ok and receipt.duplicate)
assert(Experiment.inspect(target).status=="created")
squares={};current=assert(Experiment.verifyCurrent(target,world));assert(not current.geometryResolved and not current.squareResolved)

squares={};local rejected=surface();assert(not Experiment.execute(rejected,"rejected",adapter{surfaceRejected=true}))
assert(Experiment.inspect(rejected).status=="clear","preflight rejection must not create a receipt")
local invalid=surface();assert(not Experiment.execute(invalid,"invalid",adapter{invalid=true}))
assert(Experiment.inspect(invalid).status=="clear")

local missing=surface();world=adapter{spriteMissing=true}
assert(not Experiment.execute(missing,"missing-sprite",world))
assert(world.created==nil and missing.data[Experiment.ROOT_KEY]==nil,"missing sprite must reject before topology or receipt mutation")
world=adapter();world.validateSurface=function()error("native lookup failed")end
assert(not Experiment.execute(missing,"throwing-preflight",world) and world.created==nil)
assert(Experiment.inspect(missing).status=="clear")
world=adapter();world.getSquare=function()error("unavailable")end
local inspected=assert(Experiment.verifyCurrent(target,world))
assert(inspected.requiresInspection and not inspected.geometryResolved,"status lookup failure must be contained")
target.data["groundWorks.cavity.v1"].cells[1].x=999
inspected=assert(Experiment.verifyCurrent(target,adapter()))
assert(inspected.status=="unsupported" and inspected.requiresInspection,"foreign receipt coordinates cannot be verified")

squares={};local failed=surface();world=adapter{transmitFailure=true}
ok,receipt=Experiment.execute(failed,"failed",world);assert(not ok and type(receipt)=="string")
local failure=Experiment.inspect(failed);assert(failure.status=="failed"and failure.requiresInspection and failure.topologyUncertain)
assert(failure.objectRolledBack and world.removed==1,"only the created floor object should be rolled back")
assert(not Experiment.execute(failed,"later",adapter()),"quarantined surface must reject later execution")

isClient=function()return true end;isServer=function()return false end
assert(not Experiment.execute(surface(),"client",adapter()),"client mutation must be rejected")
print("groundWorks bounded excavation experiment checks passed")
