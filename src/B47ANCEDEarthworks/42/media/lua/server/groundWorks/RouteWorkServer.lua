local Routes=require 'groundWorks/ConstructedRoutes'
local Work=require 'groundWorks/RouteWork'
local Server={}
function Server.perform(player,square,args)
    if isClient()then return false,'non-authority'end
    local id=args and args.operationId
    if type(id)~='string'or#id==0 or#id>96 or id:find('[%c]')then return false,'bounded operation ID required'end
    local allowed,plan=Work.plan(player,square,args.op,args.volumeType)
    if not allowed then return false,plan end
    local ok,result
    if args.op=='routeStart'then
        ok,result=Routes.begin(square,args.volumeType,id,{actor=player})
    elseif args.op=='routeSupply'then
        local source=plan.source
        ok,result=Routes.contributeMaterial(square,source.material,1,id,{
            id='groundWorks.handRoute.inventory.v1',consume=function(accepted)
                local consumed,reason=Work.consumeMaterial(source,accepted)
                if not consumed then return false,reason end
                return true,id
            end},{})
    else
        ok,result=Routes.advanceWork(square,plan.tool.work,id,player:getUsername())
    end
    if not ok then return false,type(result)=='string'and result or'Route action requires inspection.'end
    local snapshot=Routes.snapshot(square)
    if snapshot and snapshot.project.status=='ready'then
        local committed,reason=Routes.commit(square,id..'.surface')
        if not committed then return false,'Route recorded; surface completion needs inspection: '..tostring(reason)end
        return true,'Route completed.'
    end
    local progress=Work.progress(square)
    local message=args.op=='routeStart'and'Route marked out.'or args.op=='routeSupply'and'Route material supplied.'or'Route work recorded.'
    if progress then message=message..' Work: '..tostring(progress.workCompleted)..'/'..tostring(progress.workRequired)..'.'end
    return true,message,progress
end
return Server
