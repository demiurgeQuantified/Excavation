local BUILDING_EDITOR = BuildingRoomsEditor.getInstance()


---@type table<integer, table<integer, table<integer, boolean>>> | nil
local modData
Events.OnInitGlobalModData.Add(function()
    modData = ModData.getOrCreate("Excavation.DynamicRoomDefs")
    modData.version = 1
end)


---@param x integer
---@param y integer
---@param z integer
local function setSquare(x, y, z)
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
local function getSquare(x, y, z)
    assert(modData ~= nil, "mod data is not ready yet")

    if modData[x] == nil or modData[x][y] == nil then
        return false
    end

    return modData[x][y][z]
end


---@param x integer
---@param y integer
---@param z integer
local function createRoomOnSquare(x, y, z)
    local building = BUILDING_EDITOR:createBuilding()
    local room = building:createRoom(z)
    room:addRectangle(x, y, 1, 1)
    BUILDING_EDITOR:applyChanges(false)
end


Events.LoadGridsquare.Add(function(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if getSquare(x, y, z) then
        createRoomOnSquare(x, y, z)
    end
end)


local DynamicRoomDefs = {}


-- FIXME: we need to merge neighboring squares into one room, and connected z levels into one building
--  the current implementation will probably cause problems sooner or later as it creates hundreds of buildings
--  also generator fumes only affect the building they're in, so it only affects one square :(

---@param square IsoGridSquare
function DynamicRoomDefs.addSquare(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    createRoomOnSquare(x, y, z)
    setSquare(x, y, z)
end


return DynamicRoomDefs