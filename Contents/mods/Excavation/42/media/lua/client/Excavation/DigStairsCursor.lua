local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")
local DiggingAPI = require("Excavation/DiggingAPI")

local CORE = getCore()

---@class DigStairsCursor : Starlit.BaseSquareCursor
---@field orientation "south"|"east"
local DigStairsCursor = {}
setmetatable(DigStairsCursor, BaseSquareCursor)
DigStairsCursor.__index = DigStairsCursor

DigStairsCursor.select = function(self, square)
    DigStairsAction.queueNew(self.player, square, self.orientation)
    BaseSquareCursor.select(self, square)
end

DigStairsCursor.isValid = function(self, square)
    if not square then
        return false
    end

    local material = DiggingAPI.getMaterialAtCoords(
        square:getX(), square:getY(), square:getZ() - 1)
    if not material then
        return false
    end

    if not DigStairsAction.canBePerformed(self.player, material, square, self.orientation) then
        return false
    end

    return true
end

DigStairsCursor.render = function(self, x, y, z, square)
    -- TODO: individual colours for each square so the player can tell why/where they can't dig
	local hc = getCore():getGoodHighlitedColor()
	if not self:isValid(square) then
		hc = getCore():getBadHighlitedColor()
	end

    local floorCursorSprite = ISBuildingObject:getFloorCursorSprite() --[[@as IsoSprite]]
	floorCursorSprite:RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
    if self.orientation == "south" then
        for i = 1, 4 do
            floorCursorSprite:RenderGhostTileColor(x, y + i, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
        end
    else
        for i = 1, 4 do
            floorCursorSprite:RenderGhostTileColor(x + i, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
        end
    end
end

DigStairsCursor.keyPressed = function(self, key)
    -- TODO: should also be able to rotate by dragging the mouse
    if CORE:isKey("Rotate building", key) then
        self.orientation = self.orientation == "south" and "east" or "south"
    end
end

---@param player IsoPlayer
---@return DigStairsCursor
DigStairsCursor.new = function(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigStairsCursor) ---@cast o DigStairsCursor
    o.orientation = "south"

    return o
end

return DigStairsCursor