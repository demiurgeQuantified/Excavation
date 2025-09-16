local RoomBuilder = require("Excavation/dynamicBuildings/RoomBuilder")
local Utils = require("Excavation/dynamicBuildings/Utils")


---@namespace Excavation.dynamicBuildings


---@class BuildingBuilder
---@field levels table<integer, VirtualRoom[]>
local BuildingBuilder = {}
BuildingBuilder.__index = BuildingBuilder


---@param x integer
---@param y integer
---@param z integer
---@return VirtualRoom | nil
function BuildingBuilder:getRoomAt(x, y, z)
    local level = self.levels[z]
    if not level then
        return nil
    end

    for i = 1, #level do
        local room = level[i]
        if Utils.isWithinRoom(room, x, y, z) then
            return room
        end
    end

    return nil
end


---@param x integer
---@param y integer
---@param z integer
function BuildingBuilder:buildRoom(x, y, z)
    if not self.levels[z] then
        self.levels[z] = {}
    end

    local room = RoomBuilder.buildRoomFrom(x, y, z)
    table.insert(self.levels[z], room)

    for i = 1, #room.portals do
        local portalPos = room.portals[i]
        if portalPos.z < 0 and not self:getRoomAt(portalPos.x, portalPos.y, portalPos.z) then
            self:buildRoom(portalPos.x, portalPos.y, portalPos.z)
        end
    end

    return room
end


---@param x integer
---@param y integer
---@param z integer
---@return VirtualBuilding
---@nodiscard
function BuildingBuilder.buildBuildingFrom(x, y, z)
    local builder = BuildingBuilder.new()
    builder:buildRoom(x, y, z)

    ---@type VirtualBuilding
    local building = {
        levels = {}
    }

    for z, level in pairs(builder.levels) do
        table.insert(
            building.levels,
            {
                level = z,
                rooms = level
            }
        )
    end

    return building
end


---@return BuildingBuilder
---@nodiscard
function BuildingBuilder.new()
    return setmetatable(
        {
            levels = {}
        },
        BuildingBuilder
    )
end


return BuildingBuilder