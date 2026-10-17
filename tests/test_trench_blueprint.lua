package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/TrenchSection"]=nil
package.loaded["groundWorks/TrenchBlueprint"]=nil
_G.groundWorks=nil
require "groundWorks/API"
require "groundWorks/TrenchSection"
local TrenchBlueprint=require "groundWorks/TrenchBlueprint"

local marker={modData={}}
function marker:getModData()return self.modData end

local ok,bp=TrenchBlueprint.mark(marker,"groundWorks.trenchSection.straight","east","op.mark")
assert(ok and bp.sectionId=="groundWorks.trenchSection.straight" and bp.direction=="east","mark must record the blueprint")
assert(TrenchBlueprint.read(marker).sectionId=="groundWorks.trenchSection.straight","read must return the blueprint")

local badMark=TrenchBlueprint.mark(marker,"groundWorks.trenchSection.missing","east","op.bad")
assert(badMark==false,"unknown section must be rejected")

local defMark=TrenchBlueprint.mark(marker,"groundWorks.trenchSection.ramp","diagonal","op.def")
assert(defMark==true and TrenchBlueprint.read(marker).direction=="east","invalid direction must default to east")

local detached=TrenchBlueprint.read(marker)
detached.sectionId="corrupted"
assert(TrenchBlueprint.read(marker).sectionId~="corrupted","read must return a detached view")

assert(TrenchBlueprint.clear(marker))
assert(TrenchBlueprint.read(marker)==nil,"clear must remove the blueprint")

local props={values={grassFloor="true"}}
function props:has(key)return self.values[key]~=nil end
function props:get(key)return self.values[key] end
local sprite={name="blends_natural_01_8",properties=props}
function sprite:getName()return self.name end
function sprite:getProperties()return self.properties end
local floor={sprite=sprite}
function floor:getSprite()return self.sprite end
local surface={floor=floor,modData={}}
function surface:getFloor()return self.floor end
function surface:getModData()return self.modData end
function surface:getX()return 10 end
function surface:getY()return 20 end
function surface:getZ()return 0 end

local function makeAdapter()
    local squares={}
    local function key(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
    squares[key(10,20,0)]=surface
    local function sq(x,y,z)
        local k=key(x,y,z)
        if not squares[k]then
            local s={x=x,y=y,z=z,floor=nil}
            function s:getFloor()return self.floor end
            squares[k]=s
        end
        return squares[k]
    end
    local committed={}
    return{
        getOrCreateSquare=function(x,y,z)return sq(x,y,z)end,
        getSquare=function(x,y,z)return sq(x,y,z)end,
        placeFloor=function(square,sprite,op)square.floor={sprite=sprite,op=op};return true end,
        placeWall=function()return true end,
        removeFloor=function(square)square.floor=nil;return true end,
        setConstructed=function()return true end,
        verifyFloor=function(x,y,z,op)local s=squares[key(x,y,z)];return s and s.floor and s.floor.op==op end,
        removeObject=function()return true end,
    }
end

TrenchBlueprint.mark(marker,"groundWorks.trenchSection.straight","north","op.dig")
local bp=TrenchBlueprint.read(marker)
local digOk,receipt=TrenchBlueprint.dig(surface,bp,"op.dig.1",makeAdapter())
assert(digOk and receipt.committed==true and receipt.direction=="north","dig must commit the section")

local paved={floor=nil,modData={}}
function paved:getFloor()return self.floor end
function paved:getModData()return self.modData end
function paved:getX()return 10 end
function paved:getY()return 20 end
local pavedBp={schemaVersion=1,sectionId="groundWorks.trenchSection.straight",direction="east"}
local pavedOk=TrenchBlueprint.dig(paved,pavedBp,"op.dig.2",makeAdapter())
assert(pavedOk==false,"dig must reject non-natural ground")

isClient=function()return true end
isServer=function()return false end
assert(TrenchBlueprint.mark(marker,"groundWorks.trenchSection.straight","east","op.c")==false,"clients must not mark")
isClient=nil;isServer=nil

print("groundWorks trench-blueprint checks passed")
