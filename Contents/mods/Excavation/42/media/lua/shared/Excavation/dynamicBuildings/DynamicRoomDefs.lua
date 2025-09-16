require("Starlit/utils/Reflection")
local BuildingBuilder = require("Excavation/dynamicBuildings/BuildingBuilder")
local MetaGrid = require("Excavation/dynamicBuildings/MetaGrid")
local Utils = require("Excavation/dynamicBuildings/Utils")


local BUILDING_EDITOR = BuildingRoomsEditor.getInstance()

---@type ArrayList<IsoGenerator>
local ALL_GENERATORS = IsoGenerator.new(nil).AllGenerators


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


---@class VirtualBuilding
---@field levels VirtualLevel[]


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


---@type VirtualBuilding[]
local buildingsToAdd = table.newarray()


---@param x number
---@param y number
---@param z number
---@return boolean
---@nodiscard
local function hasPendingBuilding(x, y, z)
    for i = 1, #buildingsToAdd do
        if Utils.isWithinBuilding(buildingsToAdd[i], x, y, z) then
            return true
        end
    end

    return false
end


local function instantiatePendingBuildings()
    if #buildingsToAdd > 0 then
        for i = 1, #buildingsToAdd do
            instantiateBuilding(buildingsToAdd[i])
        end

        -- make buildings that have generators in them toxic
        for i = 0, ALL_GENERATORS:size() - 1 do
            local generator = ALL_GENERATORS:get(i)
            if hasPendingBuilding(generator:getX(), generator:getY(), generator:getZ()) then
                generator:getSquare():getBuilding():setToxic(true)
            end
        end

        buildingsToAdd = table.newarray()
    end
end

Events.OnTick.Add(instantiatePendingBuildings)


---@param x integer
---@param y integer
---@param z integer
local function createBuildingOnSquare(x, y, z)
    assert(z < 0, "attempted to create dynamic building above ground")
    assert(MetaGrid.getSquare(x, y, z) == true, "attempted to create dynamic building at non-excavated square")

    if not hasPendingBuilding(x, y, z) then
        local building = BuildingBuilder.buildBuildingFrom(x, y, z)
        table.insert(buildingsToAdd, building)
    end
end


Events.LoadGridsquare.Add(function(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    if MetaGrid.getSquare(x, y, z) then
        createBuildingOnSquare(x, y, z)
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

-- FIXME: if a building is partially loaded, when it becomes fully loaded the partial building will sometimes remain
--  overlapping with the full building

-- as the excavated area is a separate building, fumes do not spread from it to an above ground structure
--  this is also the vanilla behaviour so it may be fine to just ignore for consistency

---@param square IsoGridSquare
function DynamicRoomDefs.addSquare(square)
    local x = square:getX()
    local y = square:getY()
    local z = square:getZ()

    MetaGrid.setSquare(x, y, z)

    -- FIXME: don't remove neighbouring building if this square isn't connected to it

    removeBuildingIfPresent(x + 1, y, z)
    removeBuildingIfPresent(x - 1, y, z)
    removeBuildingIfPresent(x, y + 1, z)
    removeBuildingIfPresent(x, y - 1, z)

    createBuildingOnSquare(x, y, z)
end


return DynamicRoomDefs