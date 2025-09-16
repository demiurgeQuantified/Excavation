---@type {[integer]: table<integer, table<integer, boolean>>, version: 1} | nil
local modData
Events.OnInitGlobalModData.Add(function()
    modData = ModData.getOrCreate("Excavation.DynamicRoomDefs")
    modData.version = 1
end)


local MetaGrid = {}


---@param x integer
---@param y integer
---@param z integer
function MetaGrid.setSquare(x, y, z)
    assert(modData ~= nil, "mod data is not ready yet")

    if modData[x] == nil then
        modData[x] = {}
    end

    if modData[x][y] == nil then
        ---@diagnostic disable-next-line: need-check-nil
        modData[x][y] = {}
    end

    ---@diagnostic disable-next-line: need-check-nil
    modData[x][y][z] = true
end


---@param x integer
---@param y integer
---@param z integer
---@return boolean
function MetaGrid.getSquare(x, y, z)
    assert(modData ~= nil, "mod data is not ready yet")

    if modData[x] == nil or modData[x][y] == nil then
        return false
    end

    return modData[x][y][z]
end


return MetaGrid