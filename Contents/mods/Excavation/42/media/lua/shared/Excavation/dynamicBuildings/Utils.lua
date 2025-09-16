---@namespace Excavation.dynamicBuildings


local Utils = {}


---@param x integer
---@param y integer
---@param z integer
---@return string
function Utils.getPosHash(x, y, z)
    return string.format("%d,%d,%d", x, y, z)
end


---@param room VirtualRoom
---@param x integer
---@param y integer
---@param z integer
---@return boolean
function Utils.isWithinRoom(room, x, y, z)
    for i = 1, #room.rects do
        local rect = room.rects[i]
        if
            x >= rect.x and x < rect.x + rect.width 
            and y >= rect.y and y < rect.y + rect.length    
        then
            return true
        end
    end

    return false
end


---@param building VirtualBuilding
---@param x integer
---@param y integer
---@param z integer
---@return boolean
function Utils.isWithinBuilding(building, x, y, z)
    for i = 1, #building.levels do
        local level = building.levels[i]
        if level.level == z then
            for j = 1, #level.rooms do
                if Utils.isWithinRoom(level.rooms[j], x, y, z) then
                    return true
                end
            end
            break
        end
    end

    return false
end


return Utils