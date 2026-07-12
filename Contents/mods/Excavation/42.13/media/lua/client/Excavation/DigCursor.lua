local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")
local DiggingAPI = require("Excavation/DiggingAPI")
local Config = require("Excavation/Config")


---@class DigCursor : starlit.BaseSquareCursor
local DigCursor = {}
setmetatable(DigCursor, BaseSquareCursor)
DigCursor.__index = DigCursor


function DigCursor:select(square)
    local z = square:getZ()
    DigSquareAction.queueNew(
        self:getPlayer(), square:getX(), square:getY(), z,
        z < DiggingAPI.STONE_LEVEL and "stone" or "dirt")

    BaseSquareCursor.select(self, square, Config.hideCursorAfterDigging)
end


function DigCursor:isValidInternal(square)
    if not square then
        return false
    end

    local material = DiggingAPI.getMaterialAt(square)
    if not material then
        return false
    end

    local result = DigSquareAction.canBePerformed(self:getPlayer(), material, square)
    return result
end


function DigCursor:getAPrompt()
    local square = getSquare(self.xJoypad, self.yJoypad, self.zJoypad)
    return self:isValid(square) and getText("IGUI_Excavation_DigWall") or nil
end


---@param player IsoPlayer
---@return DigCursor
function DigCursor.new(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigCursor) ---@cast o DigCursor

    return o
end


-- fixes the annoying blocks spawning when you click out of bounds
Events.OnDoTileBuilding2.Add(function(cursor, bRender,
                                                x, y, z, square)
    if z >= 0 then return end
    for x = x - 1, x + 1 do
        for y = y - 1, y + 1 do
            local square = getSquare(x, y, z)
            ---@diagnostic disable-next-line: unnecessary-if
            if square then
                square:removeUnderground()
            end
        end
    end
end)


return DigCursor