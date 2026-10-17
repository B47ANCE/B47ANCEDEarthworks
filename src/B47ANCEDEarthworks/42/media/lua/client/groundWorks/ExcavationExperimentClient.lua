local function send(command,extra)
    local player=getPlayer();local square=player and player:getCurrentSquare()or nil
    if not square then print("[groundWorks][OpenPit] no current square");return false end
    local args={x=square:getX(),y=square:getY(),z=square:getZ()}
    if type(extra)=="table"then for key,value in pairs(extra)do args[key]=value end end
    if command=="openPit"or command=="excavationExperiment"then
        local age=getGameTime()and getGameTime():getWorldAgeHours()or 0
        args.operationId=string.format("cavity:%d:%d:%d:%.3f",args.x,args.y,args.z,age)
    end
    local servers={
        openPit="groundWorks/OpenPitServer",openPitStatus="groundWorks/OpenPitServer",cavityClimb="groundWorks/OpenPitServer",
        excavationExperiment="groundWorks/ExcavationExperimentServer",excavationExperimentStatus="groundWorks/ExcavationExperimentServer",
    }
    if isClient and isClient() then
        sendClientCommand(player,"groundWorks",command,args)
    else
        local ok,server=pcall(require,servers[command]or"groundWorks/OpenPitServer")
        if ok and server and type(server.onClientCommand)=="function"then
            server.onClientCommand("groundWorks",command,player,args)
        else
            sendClientCommand(player,"groundWorks",command,args)
        end
    end
    return true
end
function groundWorksOpenPit()return send("openPit")end
function groundWorksOpenGrave()return send("openPit",{volumeType="groundWorks.grave"})end
function groundWorksOpenPitStatus()return send("openPitStatus")end
function groundWorksCavityClimb()return send("cavityClimb")end
function groundWorksExcavationExperiment()return send("excavationExperiment")end
function groundWorksExcavationExperimentStatus()return send("excavationExperimentStatus")end

local function liveEnabled()
    if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then return true end
    local root=rawget(_G,"SandboxVars")
    local settings=type(root)=="table"and root.groundWorks or nil
    return type(settings)=="table"and settings.EnableLiveOpenPit==true
end

local function addClimb(playerIndex,context,worldObjects,test)
    local player=getSpecificPlayer(playerIndex)
    local square=player and player:getCurrentSquare()or nil
    if not square then return end
    local Cavity=groundWorks and groundWorks.Cavity
    if not Cavity or type(Cavity.climbDestination)~="function"then return end
    local destination=Cavity.climbDestination(square)
    if not destination then
        for _,object in ipairs(worldObjects or{})do
            local clicked=object and object.getSquare and object:getSquare()or nil
            if clicked then
                destination=Cavity.climbDestination(clicked)
                if destination then break end
            end
        end
    end
    if not destination and type(getCell)=="function"then
        local cell=getCell()
        local x,y=math.floor(square:getX()),math.floor(square:getY())
        if cell then
            for dy=-1,1 do
                for dx=-1,1 do
                    local neighbor=cell:getGridSquare(x+dx,y+dy,0)
                    if neighbor then
                        destination=Cavity.climbDestination(neighbor)
                        if destination then break end
                    end
                end
                if destination then break end
            end
        end
    end
    if not destination then return end
    if test then return true end
    local label=destination.direction=="down"and getText("ContextMenu_groundWorks_ClimbIntoPit")or getText("ContextMenu_groundWorks_ClimbOutOfPit")
    context:addOption(label,player,function()send("cavityClimb")end)
end

Events.OnFillWorldObjectContextMenu.Add(addClimb)

Events.OnServerCommand.Add(function(module,command,args)
    if module~="groundWorks"or command~="cavityMove"or type(args)~="table"then return end
    for index=0,getNumActivePlayers()-1 do
        local player=getSpecificPlayer(index)
        if player and player:getOnlineID()==args.onlineId then
            local square=getCell():getGridSquare(args.x,args.y,args.z)
            if square then
                player:setX(args.x);player:setY(args.y);player:setZ(args.z)
                player:setLx(args.x);player:setLy(args.y);player:setLz(args.z)
                player:setCurrentSquare(square)
            end
        end
    end
end)

if liveEnabled()then
    print("[groundWorks][OpenPit] Live cavity commands ready: groundWorksOpenPit(), groundWorksOpenGrave(), groundWorksOpenPitStatus(), groundWorksCavityClimb()")
end
if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then
    print("[groundWorks][ExcavationExperiment] Debug-only commands ready: groundWorksExcavationExperiment(), groundWorksExcavationExperimentStatus()")
end
