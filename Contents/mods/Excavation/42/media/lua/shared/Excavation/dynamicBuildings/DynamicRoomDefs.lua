local RoomBuilder = require("Excavation/dynamicBuildings/RoomBuilder")
local MetaGrid = require("Excavation/dynamicBuildings/MetaGrid")

local BUILDING_EDITOR = BuildingRoomsEditor.getInstance()


---@namespace Excavation.dynamicBuildings


---@class Position
---@field x integer
---@field y integer
---@field z integer


---@class VirtualRoom
---@field rects VirtualRoom.Rect[]
---@field portals Position[] Squares the room has portals to.

---@class VirtualRoom.Rect
---@field x integer
---@field y integer
---@field length integer
---@field width integer


---@class VirtualLevel
---@field rooms VirtualRoom[]
---@field level integer
---@field portals Position[] Squares the level has portals to.


---@class VirtualBuilding
---@field levels VirtualLevel[]


---@param x integer
---@param y integer
---@param z integer
---@return VirtualLevel
---@nodiscard
local function createLevel(x, y, z)
    ---@type VirtualRoom[]
    local rooms = {
        RoomBuilder.buildRoomFrom(x, y, z)
    }

    local portals = {}
    -- ---@diagnostic disable-next-line: need-check-nil
    -- for i = 1, #rooms[1].portals do
    --     ---@diagnostic disable-next-line: need-check-nil
    --     local portalPos = rooms[1].portals[i]
    --     if portalPos[3] ~= z then
    --         table.insert(portals, portalPos)
    --     else
    --         -- TODO: if the square is in an already existing room, drop it
    --         --  (incase a room has two portals to the same room)
    --         ---@diagnostic disable-next-line: need-check-nil
    --         table.insert(rooms, RoomBuilder.buildRoomFrom(portalPos.x, portalPos.y, portalPos.z))
    --     end
    -- end

    return {
        level = z,
        rooms = rooms,
        portals = portals
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
            for k = 1, #room.rects do
                local rect = room.rects[k]
                roomInstance:addRectangle(rect.x, rect.y, rect.width, rect.length)
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
    assert(MetaGrid.getSquare(x, y, z) == true, "attempted to create dynamic building at non-excavated square")

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


-- FIXME: this will definitely cause intense lag loading highly excavated areas, as it will scan for and create a new building
--  for every single square in that building
-- FIXME: building is not made toxic on reload because generator is already on before the building is created

Events.LoadGridsquare.Add(function(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if MetaGrid.getSquare(x, y, z) then
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
--  if possible, merge the actual building and the basement into one
--  else just propagate the toxic status to neighbours

---@param square IsoGridSquare
function DynamicRoomDefs.addSquare(square)
    -- TODO: get existing neighbouring building(s) and rebuild them
    -- TODO: delay creation of buildings until end of each tick so we don't create buildings n times when n adjacent tiles are modified
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    MetaGrid.setSquare(x, y, z)

    removeBuildingIfPresent(x + 1, y, z)
    removeBuildingIfPresent(x - 1, y, z)
    removeBuildingIfPresent(x, y + 1, z)
    removeBuildingIfPresent(x, y - 1, z)

    createRoomOnSquare(x, y, z)
end


return DynamicRoomDefs