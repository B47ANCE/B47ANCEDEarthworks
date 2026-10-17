local Trajectory=dofile(arg[1])
local function keys(points)local out={}for i,p in ipairs(points)do out[i]=p.key end return table.concat(out,",")end

assert(keys(assert(Trajectory.trace({x=.2,y=.2,z=0},{x=.8,y=.8,z=0},8)))=="0:0:0")
assert(keys(assert(Trajectory.trace({x=.2,y=.2,z=0},{x=3.2,y=.2,z=0},8)))=="0:0:0,1:0:0,2:0:0,3:0:0")
assert(keys(assert(Trajectory.trace({x=3.2,y=.2,z=0},{x=.2,y=.2,z=0},8)))=="3:0:0,2:0:0,1:0:0,0:0:0")
assert(keys(assert(Trajectory.trace({x=.5,y=.5,z=0},{x=2.5,y=2.5,z=0},16)))==
    "0:0:0,1:0:0,0:1:0,1:1:0,2:1:0,1:2:0,2:2:0","corner crossings must be supercovered")
assert(Trajectory.trace({x=0,y=0,z=0},{x=10,y=0,z=0},4)==nil,"bounded traversal must fail closed")
assert(Trajectory.trace({x=0,y=0,z=0},{x=1,y=0,z=1},8)==nil,"cross-level traversal must fail closed")
assert(Trajectory.trace({x=0/0,y=0,z=0},{x=1,y=0,z=0},8)==nil,"non-finite coordinates must fail closed")
assert(Trajectory.trace({x=0,y=0,z=0},{x=1,y=0,z=0})==nil,"caller must select the work bound")
print("groundWorks bounded wheel-trajectory supercover checks passed")
