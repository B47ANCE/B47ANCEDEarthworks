isClient=function()return false end;isServer=function()return false end
local API=require 'groundWorks/API'
API.inspectSurface=function()return{trafficWear=true}end
local Visual=require 'groundWorks/WornSurface'
local floor={data={}}
function floor:getModData()return self.data end
function floor:getOverlaySprite()return self.overlay end
function floor:setOverlaySprite(name,r,g,b,a)
    self.overlay=name~=''and{getName=function()return name end}or nil;self.alpha=a
end
local square={getFloor=function()return floor end}
assert(Visual.apply(square,'WORN'));assert(floor.alpha==.3)
assert(Visual.remove(square));assert(not floor.overlay)
floor:setOverlaySprite('foreign')
assert(Visual.apply(square,'BARE'));assert(floor.overlay:getName()=='foreign','Foreign overlays must survive.')
floor:setOverlaySprite('');assert(Visual.apply(square,'BARE'))
floor:setOverlaySprite('foreign');assert(Visual.remove(square));assert(floor.overlay:getName()=='foreign')
print('Worn overlay ownership, stage intensity and removal passed')
