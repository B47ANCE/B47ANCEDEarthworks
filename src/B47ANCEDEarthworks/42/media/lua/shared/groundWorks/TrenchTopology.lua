local Topology={MAX_CELLS=64}
local directions={{name="north",dx=0,dy=-1,bit=1},{name="east",dx=1,dy=0,bit=2},
    {name="south",dx=0,dy=1,bit=4},{name="west",dx=-1,dy=0,bit=8}}

local function integer(value)value=tonumber(value);return value and value==math.floor(value)and value or nil end
local function key(x,y,z)return tostring(x)..":"..tostring(y)..":"..tostring(z)end
local function copy(value)
    if type(value)~="table"then return value end local result={};for k,v in pairs(value)do result[k]=copy(v)end;return result
end
local variants={[0]="isolated",[1]="end_north",[2]="end_east",[4]="end_south",[8]="end_west",
    [3]="corner_northeast",[6]="corner_southeast",[12]="corner_southwest",[9]="corner_northwest",
    [5]="straight_north_south",[10]="straight_east_west",[7]="junction_north_east_south",
    [14]="junction_east_south_west",[13]="junction_south_west_north",[11]="junction_west_north_east",
    [15]="intersection"}

function Topology.cellKey(cell)
    if type(cell)~="table"then return nil end
    local x,y,z=integer(cell.x),integer(cell.y),integer(cell.z)
    return x and y and z and key(x,y,z)or nil
end

function Topology.analyze(cells,options)
    options=type(options)=="table"and options or{}
    if type(cells)~="table"or#cells<1 then return nil,"at least one trench cell required"end
    local maximum=integer(options.maxCells)or Topology.MAX_CELLS
    if maximum<1 or maximum>Topology.MAX_CELLS or#cells>maximum then return nil,"trench footprint exceeds cell bound"end
    local indexed,ordered,zLevel={}, {},nil
    for index,cell in ipairs(cells)do
        if type(cell)~="table"then return nil,"invalid trench cell at index "..index end
        local x,y,z=integer(cell.x),integer(cell.y),integer(cell.z)
        if not x or not y or not z then return nil,"integer trench coordinates required"end
        if zLevel==nil then zLevel=z elseif z~=zLevel then return nil,"one trench footprint cannot span levels"end
        local id=key(x,y,z);if indexed[id]then return nil,"duplicate trench cell"end
        local normalized={x=x,y=y,z=z,key=id};indexed[id]=normalized;ordered[#ordered+1]=normalized
    end
    table.sort(ordered,function(a,b)return a.z==b.z and(a.y==b.y and a.x<b.x or a.y<b.y)or a.z<b.z end)
    local queue,visited={ordered[1]}, {[ordered[1].key]=true};local cursor=1
    while cursor<=#queue do
        local cell=queue[cursor];cursor=cursor+1
        for _,direction in ipairs(directions)do
            local neighbour=indexed[key(cell.x+direction.dx,cell.y+direction.dy,cell.z)]
            if neighbour and not visited[neighbour.key]then visited[neighbour.key]=true;queue[#queue+1]=neighbour end
        end
    end
    if#queue~=#ordered then return nil,"trench footprint must be cardinally connected"end
    local result={schemaVersion=1,z=zLevel,count=#ordered,cells={}}
    for _,cell in ipairs(ordered)do
        local mask,connections=0,{}
        for _,direction in ipairs(directions)do
            if indexed[key(cell.x+direction.dx,cell.y+direction.dy,cell.z)]then
                mask=mask+direction.bit;connections[#connections+1]=direction.name
            end
        end
        result.cells[#result.cells+1]={x=cell.x,y=cell.y,z=cell.z,key=cell.key,mask=mask,
            connectionCount=#connections,connections=connections,variant=variants[mask]}
    end
    return copy(result)
end

return Topology
