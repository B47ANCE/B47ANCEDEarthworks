package.loaded["groundWorks/WheelTrajectory"]=nil
local Wear=dofile(arg[1])
local vehicle={}
local function sample(rows)return{contacts=rows,unsupported={}}end
local function contact(id,x,y)return{id=id,x=x,y=y,z=0,kind="wheel",supported=true}end
local squares={}
local function resolve(x,y,z)local key=x..":"..y..":"..z;squares[key]=squares[key]or{key=key};return squares[key]end

local plan=assert(Wear.plan(vehicle,sample({contact("L",0.2,0.2),contact("R",0.2,1.2)}),resolve))
assert(plan.seeded==2 and#plan.tiles==0,"first sample must seed without stationary wear")
plan=assert(Wear.plan(vehicle,sample({contact("L",0.2,0.2),contact("R",0.2,1.2)}),resolve))
assert(plan.crossed==0 and#plan.tiles==0,"stationary contacts must not create travel wear")
plan=assert(Wear.plan(vehicle,sample({contact("L",3.2,0.2),contact("R",3.2,1.2)}),resolve))
assert(plan.crossed==8 and plan.resolved==8,"each wheel trajectory must cover intermediate tiles")
local seen={}for _,row in ipairs(plan.tiles)do seen[row.key]=true end
assert(seen["1:0:0"]and seen["2:1:0"]and not seen["1:2:0"],"body-only tiles must not be attributed")

-- Both contacts crossing one tile produce one vehicle-step contribution.
Wear._resetForTests();vehicle={}
assert(Wear.plan(vehicle,sample({contact("A",0.2,0.2),contact("B",0.8,0.8)}),resolve))
plan=assert(Wear.plan(vehicle,sample({contact("A",1.2,0.2),contact("B",1.2,0.8)}),resolve))
local count=0 for _,row in ipairs(plan.tiles)do if row.key=="1:0:0"then count=count+1 end end
assert(count==1,"same tile must be deduplicated within a vehicle step")

-- Reordering is stable; a new contact seeds rather than joining old geometry.
plan=assert(Wear.plan(vehicle,sample({contact("B",2.2,0.8),contact("A",2.2,0.2),contact("C",50,50)}),resolve))
for _,row in ipairs(plan.tiles)do assert(row.key~="50:50:0","new contacts must not generate a fabricated path")end
local unresolved=assert(Wear.plan(vehicle,sample({contact("A",3.2,0.2),contact("B",3.2,0.8)}),function()return nil end))
assert(unresolved.resolved==0 and unresolved.unresolved>0,"unloaded tiles must remain unresolved")
assert(Wear.plan(vehicle,sample({contact("A",1000,0.2)}),resolve)==nil,"oversized motion must fail closed")
print("groundWorks per-wheel trajectory planning and tile deduplication checks passed")
