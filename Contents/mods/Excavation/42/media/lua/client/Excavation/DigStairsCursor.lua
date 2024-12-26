local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")

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

    local z = square:getZ()
    if z <= -32 or z > 0 or not square:getFloor() then
        return false
    end

    local x, y = square:getX(), square:getY()
    if self.orientation == "south" then
        for i = 1, 3 do
            if not self:canDigDown(x, y + i, z) then
                return false
            end
        end

        local endSquare = getSquare(x, y + 4, z - 1)
        -- we don't check isSquareClear here because the previous one already checked for walls between them
        if endSquare and not endSquare:isFreeOrMidair(true) then
            return false
        end
    else
        for i = 1, 3 do
            if not self:canDigDown(x + i, y, z) then
                return false
            end
        end

        local endSquare = getSquare(x + 4, y, z - 1)
        if endSquare and not endSquare:isFreeOrMidair(true) then
            return false
        end
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

---@param x integer
---@param y integer
---@param z integer
DigStairsCursor.canDigDown = function(self, x, y, z)
    local upperSquare = getSquare(x, y, z)
    -- upper square must be dug out
    if not upperSquare or not self:isSquareClear(upperSquare) then
        return false
    end

    local lowerSquare = getSquare(x, y, z - 1)
    -- it's ok if lower square doesn't exist yet, but if it does it must not already be dug out
    if lowerSquare and lowerSquare:hasFloor() then
        return false
    end

    return true
end

---@param square IsoGridSquare
---@return boolean
DigStairsCursor.isSquareClear = function(self, square)
    if not square:hasFloor() then
        return false
    end

    local isSouth = self.orientation == "south"
    local neighbour = isSouth and square:getS() or square:getE()
    if neighbour then
        local objects = neighbour:getLuaTileObjectList() --[=[@as IsoObject[]]=]
        for i = 1, #objects do
            local object = objects[i]
            local sprite = object:getSprite()
            -- copied from buildutils U_U
            if (sprite and sprite:getProperties():Is(isSouth and IsoFlagType.collideN or IsoFlagType.collideW))
                    or ((instanceof(object, "IsoThumpable") and object:getNorth() == isSouth) and not object:isCorner() and not object:isFloor())
                    or (instanceof(object, "IsoWindow") and object:getNorth() == isSouth)
                    or (instanceof(object, "IsoDoor") and object:getNorth() == isSouth) then
                return false
            end
        end
    end
    return square:isFreeOrMidair(true)
end

DigStairsCursor.keyPressed = function(self, key)
    if CORE:isKey("Rotate building", key) then
        self.orientation = self.orientation == "south" and "east" or "south"
    end
end

-- TODO: should also be able to rotate by dragging the mouse

---@param player IsoPlayer
---@return DigStairsCursor
DigStairsCursor.new = function(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigStairsCursor) ---@cast o DigStairsCursor
    o.orientation = "south"

    return o
end

return DigStairsCursor