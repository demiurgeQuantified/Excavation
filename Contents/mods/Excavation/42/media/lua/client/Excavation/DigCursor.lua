local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")

local MIN_HEIGHT = -32

---@param square IsoGridSquare
---@return boolean
local hasValidAdjacentSquare = function(square)
    local x, y, z = square:getX(), square:getY(), square:getZ()

    local squares = table.newarray() --[=[@as IsoGridSquare[]]=]
    table.insert(squares, getSquare(x - 1, y, z))
    table.insert(squares, getSquare(x + 1, y, z))
    table.insert(squares, getSquare(x, y - 1, z))
    table.insert(squares, getSquare(x, y + 1, z))

    for i = 1, #squares do
        if squares[i]:hasFloor() then
            return true
        end
    end
    return false
end

---@class DigCursor : Starlit.BaseSquareCursor
local DigCursor = {}
setmetatable(DigCursor, BaseSquareCursor)
DigCursor.__index = DigCursor

---@param square IsoGridSquare
DigCursor.select = function(self, square)
    DigSquareAction.queueNew(self.player, square:getX(), square:getY(), square:getZ())
    BaseSquareCursor.select(self, square) -- necessary to remove the cursor
end

---@param square IsoGridSquare
DigCursor.isValid = function(self, square)
    if not square then
        return false
    end

    local z = square:getZ()
    if z >= 0 then
        return false
    end

    if not hasValidAdjacentSquare(square) then
        return false
    end

    -- scan downwards for ground so that you can't dig in open pits
    local x, y = square:getX(), square:getY()
    for i = z, MIN_HEIGHT, -1 do
        local belowSquare = getSquare(x, y, i)
        if not belowSquare then
            break
        end
        if belowSquare:hasFloor() then
            return false
        end
    end
    return true
end

---@param player IsoPlayer
---@return DigCursor
DigCursor.new = function(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigCursor) ---@cast o DigCursor

    return o
end

return DigCursor