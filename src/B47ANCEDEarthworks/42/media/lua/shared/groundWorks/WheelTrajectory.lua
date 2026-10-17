local Trajectory={}

local function finite(value)
    value=tonumber(value)
    if not value or value~=value or value==math.huge or value==-math.huge then return nil end
    return value
end

local function append(result,seen,x,y,z,limit)
    local key=tostring(x)..":"..tostring(y)..":"..tostring(z)
    if seen[key]then return true end
    if #result>=limit then return false end
    seen[key]=true
    result[#result+1]={x=x,y=y,z=z,key=key}
    return true
end

-- Returns every tile touched by a continuous wheel-center segment. The caller
-- must provide its own explicit work bound; gameplay policy owns that limit.
function Trajectory.trace(previous,current,maxTiles)
    if type(previous)~="table"or type(current)~="table"then return nil,"coordinates required"end
    local x0,y0,z0=finite(previous.x),finite(previous.y),finite(previous.z)
    local x1,y1,z1=finite(current.x),finite(current.y),finite(current.z)
    local limit=tonumber(maxTiles)
    if not x0 or not y0 or not z0 or not x1 or not y1 or not z1 then return nil,"finite coordinates required"end
    if not limit or limit<1 or limit~=math.floor(limit)then return nil,"positive integer tile bound required"end
    local tileZ=math.floor(z0)
    if math.floor(z1)~=tileZ then return nil,"cross-level segment unsupported"end

    local tileX,tileY=math.floor(x0),math.floor(y0)
    local endX,endY=math.floor(x1),math.floor(y1)
    local result,seen={},{}
    if not append(result,seen,tileX,tileY,tileZ,limit)then return nil,"tile bound exceeded"end
    if tileX==endX and tileY==endY then return result end

    local dx,dy=x1-x0,y1-y0
    local stepX=dx>0 and 1 or(dx<0 and-1 or 0)
    local stepY=dy>0 and 1 or(dy<0 and-1 or 0)
    local deltaX=stepX==0 and math.huge or math.abs(1/dx)
    local deltaY=stepY==0 and math.huge or math.abs(1/dy)
    local nextX=stepX>0 and(tileX+1)or tileX
    local nextY=stepY>0 and(tileY+1)or tileY
    local maxX=stepX==0 and math.huge or(nextX-x0)/dx
    local maxY=stepY==0 and math.huge or(nextY-y0)/dy

    while tileX~=endX or tileY~=endY do
        if maxX<maxY then
            tileX=tileX+stepX;maxX=maxX+deltaX
            if not append(result,seen,tileX,tileY,tileZ,limit)then return nil,"tile bound exceeded"end
        elseif maxY<maxX then
            tileY=tileY+stepY;maxY=maxY+deltaY
            if not append(result,seen,tileX,tileY,tileZ,limit)then return nil,"tile bound exceeded"end
        else
            if not append(result,seen,tileX+stepX,tileY,tileZ,limit)
                or not append(result,seen,tileX,tileY+stepY,tileZ,limit)then return nil,"tile bound exceeded"end
            tileX=tileX+stepX;tileY=tileY+stepY
            maxX=maxX+deltaX;maxY=maxY+deltaY
            if not append(result,seen,tileX,tileY,tileZ,limit)then return nil,"tile bound exceeded"end
        end
    end
    return result
end

return Trajectory
