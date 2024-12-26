local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")

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
    return square and square:getZ() < 0 and (not square:getFloor())
            and hasValidAdjacentSquare(square)
end

---@param player IsoPlayer
---@return DigCursor
DigCursor.new = function(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigCursor) ---@cast o DigCursor

    return o
end

return DigCursor