local groundWorks=require "groundWorks/API"
local VolumeTypes={
    MAX_TYPES=32,MAX_DEPTH=8,MAX_ID=96,MAX_ITEMS_PER_CELL=16,MAX_BODIES_PER_CELL=8,
    definitions={},aliases={},count=0,
}

local SURFACE_CAPS={open=true,entered=true,sealed=true}
local DOMAINS={excavation=true,surface=true}
local MEDIA_NAMES={"soil","item","body","water","fuel","concrete"}
local OCCUPANCY_NAMES={"stand","receiveItems","receiveBodies","receiveFluids","ignite","pourSolid"}

local function copy(value,seen)
    if type(value)~="table"then return value end
    seen=seen or{};if seen[value]then return nil end;seen[value]=true
    local result={};for key,child in pairs(value)do result[copy(key,seen)]=copy(child,seen)end
    seen[value]=nil;return result
end
local function flagMap(values,names)
    values=type(values)=="table"and values or{}
    local result={}
    for _,name in ipairs(names)do result[name]=values[name]==true end
    return result
end
local function hasFlag(flags)
    for _,enabled in pairs(flags)do if enabled==true then return true end end
    return false
end
local function identifier(value,limit)
    return type(value)=="string"and value~=""and#value<=(limit or VolumeTypes.MAX_ID)and not value:find("[%c]")
end
local function jobTypeName(id)
    local short=id:match("%.([^%.]+)$")
    return short or id
end
local function view(definition)
    if not definition then return nil end
    return{
        id=definition.id,jobType=definition.jobType,domain=definition.domain,surfaceCap=definition.surfaceCap,
        maxDepth=definition.maxDepth,liveGeometry=definition.liveGeometry==true,
        occupancy=copy(definition.occupancy),fillMedia=copy(definition.fillMedia),validate=definition.validate,
    }
end

function VolumeTypes.register(definition)
    assert(type(definition)=="table","volume type definition required")
    assert(identifier(definition.id),"bounded volume type id required")
    assert(DOMAINS[definition.domain]==true,"volume domain must be excavation or surface")
    assert(SURFACE_CAPS[definition.surfaceCap]==true,"volume surfaceCap must be open, entered, or sealed")
    assert(type(definition.validate)=="function","volume validation callback required")
    assert(not VolumeTypes.definitions[definition.id],"duplicate groundWorks volume type: "..definition.id)
    local jobType=definition.jobType or jobTypeName(definition.id)
    assert(identifier(jobType,32),"bounded volume jobType required")
    assert(not VolumeTypes.aliases[jobType]and not VolumeTypes.aliases[definition.id],
        "duplicate groundWorks volume type alias: "..jobType)
    local maxDepth=tonumber(definition.maxDepth)or 1
    assert(maxDepth==math.floor(maxDepth)and maxDepth>=1 and maxDepth<=VolumeTypes.MAX_DEPTH,"bounded volume maxDepth required")
    local occupancy=flagMap(definition.occupancy,OCCUPANCY_NAMES)
    local fillMedia=flagMap(definition.fillMedia,MEDIA_NAMES)
    assert(hasFlag(occupancy)or hasFlag(fillMedia),"volume type requires occupancy or fill media")
    assert(VolumeTypes.count<VolumeTypes.MAX_TYPES,"too many volume types")
    local registered={
        id=definition.id,jobType=jobType,domain=definition.domain,surfaceCap=definition.surfaceCap,
        maxDepth=maxDepth,liveGeometry=definition.liveGeometry==true,occupancy=occupancy,fillMedia=fillMedia,
        validate=definition.validate,
    }
    VolumeTypes.definitions[registered.id]=registered
    VolumeTypes.aliases[registered.id]=registered.id
    VolumeTypes.aliases[jobType]=registered.id
    VolumeTypes.count=VolumeTypes.count+1
    return view(registered)
end

function VolumeTypes.get(id)
    if not identifier(id)then return nil end
    local resolved=VolumeTypes.aliases[id]or id
    return view(VolumeTypes.definitions[resolved])
end

function VolumeTypes.resolve(id)
    if not identifier(id)then return nil,"unsupported earthwork job type"end
    local resolved=VolumeTypes.aliases[id]
    local definition=resolved and VolumeTypes.definitions[resolved]or nil
    if not definition then return nil,"unsupported earthwork job type"end
    return view(definition)
end

function VolumeTypes.validate(id,context)
    local definition=VolumeTypes.get(id)
    if not definition then return false,"unknown volume type"end
    context=type(context)=="table"and context or{}
    if not context.square then return false,"square required"end
    local ok,allowed,reason=pcall(definition.validate,context)
    if not ok then return false,"volume validation error"end
    if allowed~=true then return false,reason or"volume rejected"end
    return true,definition
end

function VolumeTypes.maxItems(cellCount)
    cellCount=tonumber(cellCount)or 0
    return math.max(0,math.floor(cellCount))*VolumeTypes.MAX_ITEMS_PER_CELL
end
function VolumeTypes.maxBodies(cellCount)
    cellCount=tonumber(cellCount)or 0
    return math.max(0,math.floor(cellCount))*VolumeTypes.MAX_BODIES_PER_CELL
end

function VolumeTypes.list()
    local result={}
    for _,definition in pairs(VolumeTypes.definitions)do result[#result+1]=view(definition)end
    table.sort(result,function(a,b)return a.id<b.id end)
    return result
end

function VolumeTypes._resetForTests()
    VolumeTypes.definitions={};VolumeTypes.aliases={};VolumeTypes.count=0
end

local function naturalGround(context)
    local surface,err=groundWorks.inspectSurface(context.square)
    if not surface then return false,err end
    if surface.water then return false,"cannot build in water"end
    if not surface.natural then return false,"natural ground required"end
    return true
end

VolumeTypes.register{
    id="groundWorks.trench",jobType="trench",domain="excavation",surfaceCap="open",maxDepth=4,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveFluids=true},fillMedia={soil=true,water=true},validate=naturalGround,
}
VolumeTypes.register{
    id="groundWorks.moat",jobType="moat",domain="excavation",surfaceCap="open",maxDepth=4,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveFluids=true},fillMedia={soil=true,water=true},validate=naturalGround,
}
VolumeTypes.register{
    id="groundWorks.grave",jobType="grave",domain="excavation",surfaceCap="open",maxDepth=4,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveBodies=true},fillMedia={soil=true,item=true,body=true,concrete=true},
    validate=naturalGround,
}
VolumeTypes.register{
    id="groundWorks.openPit",jobType="openPit",domain="excavation",surfaceCap="open",maxDepth=VolumeTypes.MAX_DEPTH,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveBodies=true},fillMedia={soil=true,item=true,body=true,concrete=true},
    validate=naturalGround,
}
VolumeTypes.register{
    id="groundWorks.basement",jobType="basement",domain="excavation",surfaceCap="entered",maxDepth=VolumeTypes.MAX_DEPTH,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveBodies=true},fillMedia={soil=true,item=true,body=true,concrete=true},
    validate=function(context)return groundWorks.validateProject("groundWorks.basement",context)end,
}
VolumeTypes.register{
    id="groundWorks.burnPit",jobType="burnPit",domain="excavation",surfaceCap="open",maxDepth=4,liveGeometry=true,
    occupancy={stand=true,receiveItems=true,receiveBodies=true,ignite=true},
    fillMedia={soil=true,item=true,body=true,fuel=true},validate=naturalGround,
}
VolumeTypes.register{
    id="groundWorks.foundation",jobType="foundation",domain="excavation",surfaceCap="open",maxDepth=VolumeTypes.MAX_DEPTH,
    liveGeometry=true,occupancy={pourSolid=true},fillMedia={soil=true,concrete=true},validate=naturalGround,
}

function groundWorks.registerVolumeType(definition)return VolumeTypes.register(definition)end
function groundWorks.getVolumeType(id)return VolumeTypes.get(id)end
function groundWorks.listVolumeTypes()return VolumeTypes.list()end
function groundWorks.validateVolume(id,context)return VolumeTypes.validate(id,context)end
function groundWorks.resolveVolumeType(id)return VolumeTypes.resolve(id)end

groundWorks.VolumeTypes=VolumeTypes
return VolumeTypes
