-- The retired renderer must stay unavailable on SP, client and dedicated sides.
local originalRequire=require
require=function(name)
    assert(not name:lower():find('fjl',1,true) and not name:find('FadedJava',1,true),
        'visibility status must not load a custom renderer')
    return originalRequire(name)
end
getModInfo=function()error('visibility must not discover an external renderer')end
getActivatedMods=function()error('visibility must not require external activation')end
luajava=setmetatable({},{__index=function()error('Java binding access is prohibited')end})
-- A reused table from an older module must not activate the retired renderer.
groundWorks={FJLVisibilityAvailable=true,FJLVisibilityActive=true}
package.loaded['groundWorks/API']=nil
local API=require 'groundWorks/API'
for _,side in ipairs({'sp','client','dedicated'})do
    isClient=function()return side=='client'end
    isServer=function()return side=='dedicated'end
    SandboxVars={groundWorks={EnableFJLVisibility=true}}
    local status=API.getVisibilityStatus()
    assert(status.available==false and status.active==false and status.mode=='vanilla',
        'legacy flags/settings cannot enable the retired renderer on '..side)
    status.available=true;status.active=true;status.mode='external'
    local nextStatus=API.getVisibilityStatus()
    assert(nextStatus~=status and not nextStatus.available and not nextStatus.active
        and nextStatus.mode=='vanilla','status snapshots must be detached')
end
print('Vanilla-only visibility status, legacy-setting rejection and detached snapshots passed')
