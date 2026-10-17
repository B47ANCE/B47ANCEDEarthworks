isClient=function()return false end;isServer=function()return false end
local store={}
local API={EarthworkPersistence={getStore=function()return store end},EarthworkProviders={
    get=function()return{kind='machine',capabilities={excavate=true}}end,isAvailable=function()return true end,
    authorize=function(_,_,amount)return{amount=amount}end}}
package.loaded['groundWorks/Load']=API
local checked=0
package.loaded['groundWorks/ExcavationBuild']={check=function()checked=checked+1;return true,{missingLayers=3,plan={cells={}}}end}
package.loaded['groundWorks/CavityBoundary']={}
package.loaded['groundWorks/CavityTerrain']={}
package.loaded['groundWorks/CavityEngine']={}
local vehicle={};local player={getUsername=function()return 'worker'end,getVehicle=function()return vehicle end}
function vehicle:getDriver()return player end
local Server=require 'groundWorks/ExcavationBuildServer'
local allowed=true
Server.registerMachineValidator('provider',function()return allowed,'machine rejected'end)
local spec={presetId='trench_1x3',x=1,y=2,z=-1,direction='east'}
assert(Server.beginMachine(player,spec,'provider','project'))
assert(Server.applyMachineWork(player,'project',24,'work.1'))
assert(store.excavationProjects.project.workCompleted==24)
assert(Server.applyMachineWork(player,'project',24,'work.1'))
assert(store.excavationProjects.project.workCompleted==24)
allowed=false;assert(not Server.applyMachineWork(player,'project',24,'work.2'))
assert(store.excavationProjects.project.workCompleted==24)
allowed=true;spec.x=3;assert(not Server.beginMachine(player,spec,'provider','project'))
store.excavationProjects.project.status='needs_inspection'
assert(not Server.applyMachineWork(player,'project',24,'work.1'),'Failed geometry must stay failed on replay.')
print('Machine provider revalidation, work replay, identity conflict and quarantine passed')
