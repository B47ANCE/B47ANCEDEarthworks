package.loaded["groundWorks/API"]=nil
package.loaded["groundWorks/HeavyObjectIntegration"]=nil
_G.groundWorks=nil
require "groundWorks/API"
local Heavy=require "groundWorks/HeavyObjectIntegration"

assert(Heavy.available()==false,"consumer must start unavailable")
assert(not Heavy.query({},{}),"query must fail while unavailable")

local fakeApi={inspect=function()return nil end}
Heavy.attach(fakeApi)
assert(Heavy.available()==true,"attached consumer must be available")

fakeApi.inspect=function()
    return{providerId="p1",targetId="t1",actorId="a1",operations={carry={supported=true,eligible=true,reason="ok"}}}
end
local view=assert(Heavy.query({},{}))
assert(view.providerId=="p1" and view.targetId=="t1" and view.actorId=="a1")
assert(view.operations.carry.supported and view.operations.carry.eligible and view.operations.carry.reason=="ok")
assert(view.operations.push.supported==false and view.operations.push.eligible==false and view.operations.push.reason=="UNSUPPORTED")
assert(view.operations.pull.supported==false and view.operations.pull.reason=="UNSUPPORTED")

fakeApi.inspect=function()
    return{operations={carry={supported=true,eligible=false,reason="too heavy"},push={supported=true,eligible=true,reason="ok"}}}
end
assert(Heavy.supports({},{},"carry")==true,"supports reports supported even when ineligible")
assert(Heavy.eligible({},{},"carry")==false,"eligible must reject an ineligible supported action")
assert(Heavy.eligible({},{},"push")==true)
assert(Heavy.supports({},{},"pull")==false)
assert(not Heavy.supports({},{},"bogus"),"unknown actions must fail closed")

fakeApi.inspect=function()return nil end
assert(Heavy.query({},{})==nil,"unsupported target must return no view")

fakeApi.inspect=function() error("boom") end
assert(Heavy.query({},{})==nil,"inspection exceptions must be contained")

Heavy.attach(nil)
assert(Heavy.available()==false,"detach must restore unavailable state")
print("groundWorks heavy-object capability consumption checks passed")
local owner=require 'itjustWorks/HeavyObjects'
assert(owner.attachStore({}))
local target={};local commits=0
owner.registerProvider{id='test.heavy',matches=function(t)return t==target end,
    getStableId=function()return 'target'end,resolveStableId=function()return target end,getActorId=function()return 'actor'end,
    observe=function()return{operations={carry={supported=true,eligible=true}}}end,
    reserve=function()return true,{}end,start=function()return true,{}end,
    complete=function()commits=commits+1;return true,{}end,cancel=function()return true,{}end}
Heavy.attach(owner)
assert(not Heavy.advance({},target,'carry','complete','operation'))
assert(Heavy.advance({},target,'carry','reserve','operation'))
assert(Heavy.advance({},target,'carry','start','operation'))
assert(Heavy.advance({},target,'carry','complete','operation'))
assert(Heavy.advance({},target,'carry','complete','operation'));assert(commits==1)
assert(not Heavy.advance({},target,'push','reserve','operation'))
print('Heavy-object real framework ordering, replay and identity passed')
