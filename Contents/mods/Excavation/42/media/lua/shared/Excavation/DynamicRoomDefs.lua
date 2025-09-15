local BUILDING_EDITOR = BuildingRoomsEditor.getInstance()


---@type {[integer]: table<integer, table<integer, boolean>>, version: 1} | nil
local modData
Events.OnInitGlobalModData.Add(function()
    modData = ModData.getOrCreate("Excavation.DynamicRoomDefs")
    modData.version = 1
end)


---@class VirtualRoom
---@field squares [integer, integer, integer]

---@class VirtualLevel
---@field rooms VirtualRoom[]
---@field level integer

---@class VirtualBuilding
---@field levels VirtualLevel[]


---@param x integer
---@param y integer
---@param z integer
---@return string
local function getPosHash(x, y, z)
    return string.format("%d,%d,%d", x, y, z)
end


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


---@alias RoomBuilder.Square [integer, integer, integer]

---@class RoomBuilder
---@field seenSquares table<string, boolean>
---@field squareStack RoomBuilder.Square[]
local RoomBuilder = {}
RoomBuilder.__index = RoomBuilder


---@param x integer
---@param y integer
---@param z integer
function RoomBuilder:addSquareIfValid(x, y, z)
    local hash = getPosHash(x, y, z)
    if not self.seenSquares[hash] and getSquare(x, y, z) then
        local pos = {x, y, z}
        table.insert(self.squareStack, pos)
        self.seenSquares[hash] = true
    end
end


---@return RoomBuilder
function RoomBuilder.new()
    local o = setmetatable(
        {
            seenSquares = {},
            squareStack = table.newarray()
        },
        RoomBuilder
    )

    return o
end


---@param x integer
---@param y integer
---@param z integer
---@return VirtualRoom
---@nodiscard
local function createRoom(x, y, z)
    assert(getSquare(x, y, z) == true, "attempted to create virtual room at non-excavated square")

    local squares = table.newarray()

    local builder = RoomBuilder.new()
    builder.squareStack = table.newarray()
    builder.seenSquares = {
        [getPosHash(x, y, z)] = true
    }

    builder.squareStack[1] = {x, y, z}
    while #builder.squareStack > 0 do
        local square = table.remove(builder.squareStack)
        local x = square[1]
        local y = square[2]
        local z = square[3]

        builder:addSquareIfValid(x + 1, y, z)
        builder:addSquareIfValid(x - 1, y, z)
        builder:addSquareIfValid(x, y + 1, z)
        builder:addSquareIfValid(x, y - 1, z)

        table.insert(squares, square)
    end

    return {
        squares = squares
    }
end


---@param x integer
---@param y integer
---@param z integer
---@return VirtualLevel
---@nodiscard
local function createLevel(x, y, z)
    return {
        level = z,
        rooms = {createRoom(x, y, z)}
    }
end


---@param building VirtualBuilding
local function instantiateBuilding(building)
    local buildingInstance = BUILDING_EDITOR:createBuilding()
    for i = 1, #building.levels do
        local level = building.levels[i]
        for j = 1, #level.rooms do
            local room = level.rooms[j]
            local roomInstance = buildingInstance:createRoom(level.level)
            -- FIXME: the squares should be compressed into rectangles
            --  just draw straight lines across one axis, and merge neighbouring lines with the same start and end points
            for k = 1, #room.squares do
                local square = room.squares[k]
                roomInstance:addRectangle(square[1], square[2], 1, 1)
            end
        end
    end
    BUILDING_EDITOR:applyChanges(false)
end


---@param x integer
---@param y integer
---@param z integer
---@return VirtualBuilding
---@nodiscard
local function createBuilding(x, y, z)
    assert(z < 0, "attempted to create dynamic building above ground")
    assert(getSquare(x, y, z) == true, "attempted to create dynamic building at non-excavated square")

    return {
        levels = {createLevel(x, y, z)}
    }
end


---@param x integer
---@param y integer
---@param z integer
local function createBuildingOnSquare(x, y, z)
    local building = createBuilding(x, y, z)
    instantiateBuilding(building)
end


---@param x integer
---@param y integer
---@param z integer
local function createRoomOnSquare(x, y, z)
    -- local building = BUILDING_EDITOR:createBuilding()
    -- local room = building:createRoom(z)
    -- room:addRectangle(x, y, 1, 1)
    -- BUILDING_EDITOR:applyChanges(false)
    createBuildingOnSquare(x, y, z)
end


-- FIXME: this will definitely cause intense lag in highly excavated areas, as it will scan for and create a new building
--  for every single square in that building
-- FIXME: building is not made toxic on reload because generator is already on before the building is created

Events.LoadGridsquare.Add(function(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if getSquare(x, y, z) then
        createRoomOnSquare(x, y, z)
    end
end)


---@param x integer
---@param y integer
---@param z integer
---@return BREBuilding | nil
---@nodiscard
local function getBuildingAt(x, y, z)
    for i = 0, BUILDING_EDITOR:getBuildingCount() - 1 do
        local building = BUILDING_EDITOR:getBuildingByIndex(i)
        if building:getRoomIndexAt(x, y, z) ~= -1 then
            return building
        end
    end

    return nil
end


---@param x integer
---@param y integer
---@param z integer
local function removeBuildingIfPresent(x, y, z)
    local building = getBuildingAt(x, y, z)
    if building then
        BUILDING_EDITOR:removeBuilding(building)
    end
end


local DynamicRoomDefs = {}


-- TODO: current implementation considers all neighboring excavated areas as part of the same room
--  it would be better to determine walled off areas and make them separate rooms or buildings depending on whether they are connected

-- FIXME: as the excavated area is a separate building, fumes do not spread from it to an above ground structure or vanilla basement


---@param square IsoGridSquare
function DynamicRoomDefs.addSquare(square)
    -- TODO: get existing neighbouring building(s) and rebuild them
    -- TODO: delay creation of buildings until end of each tick so we don't create buildings n times when n adjacent tiles are modified
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    setSquare(x, y, z)

    removeBuildingIfPresent(x + 1, y, z)
    removeBuildingIfPresent(x - 1, y, z)
    removeBuildingIfPresent(x, y + 1, z)
    removeBuildingIfPresent(x, y - 1, z)

    createRoomOnSquare(x, y, z)
end


return DynamicRoomDefs