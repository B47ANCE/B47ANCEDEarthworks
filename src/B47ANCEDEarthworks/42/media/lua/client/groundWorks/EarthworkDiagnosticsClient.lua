function groundWorksEarthworkStatus()
    local player=getPlayer();if not player then print("[groundWorks][Earthworks] no player");return false end
    sendClientCommand(player,"groundWorks","earthworkStatus",{});return true
end
if type(rawget(_G,"isDebugEnabled"))=="function"and isDebugEnabled()==true then
    print("[groundWorks][Earthworks] Debug status command ready: groundWorksEarthworkStatus()")
end
