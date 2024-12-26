local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")

---@class DigStairsAction : ISBaseTimedAction
---@field character IsoGameCharacter
---@field originSquare IsoGridSquare
---@field orientation "south"|"east"
local DigStairsAction = ISBaseTimedAction:derive("DigStairsAction")
DigStairsAction.__index = DigStairsAction

DigStairsAction.SACKS_NEEDED = 6

DigStairsAction.perform = function(self)
    local x, y, z = self.originSquare:getX(), self.originSquare:getY(), self.originSquare:getZ()
    if self.orientation == "south" then
        -- TODO: this creates and then destroys internal walls
        -- to optimise this DiggingAPI needs a way to open an area of squares and calculate the necessary walls once
        for i = 1, 4 do
            local square = IsoObjectUtils.getOrCreateSquare(x, y + i, z - 1)
            if not square:getFloor() then
                DiggingAPI.digSquare(x, y + i, z - 1)
            end
        end
        for i = 1, 3 do
            local square = getSquare(x, y + i, z)
            square:transmitRemoveItemFromSquare(square:getFloor())
        end
    else
        for i = 1, 4 do
            local square = IsoObjectUtils.getOrCreateSquare(x + i, y, z - 1)
            if not square:getFloor() then
                DiggingAPI.digSquare(x + i, y, z - 1)
            end
        end
        for i = 1, 3 do
            local square = getSquare(x + i, y, z)
            square:transmitRemoveItemFromSquare(square:getFloor())
        end
    end
    -- TODO: add stairs lol
    -- TODO: endurance loss and muscle strain
    -- TODO: seems like cutaway and maybe lighting is buggy until a reload/building something in the pit
    ISBaseTimedAction.perform(self)
end

DigStairsAction.isValid = function(self)
    return true
end

---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@return boolean success
DigStairsAction.queueNew = function(character, square, orientation)
    -- TODO
    ISTimedActionQueue.add(
        DigStairsAction.new(character, square, orientation)
    )
    return true
end

---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@return DigStairsAction
DigStairsAction.new = function(character, square, orientation)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, DigStairsAction) ---@cast o DigStairsAction

    o.maxTime = character:isTimedActionInstant() and 1 or 1000
    o.originSquare = square
    o.orientation = orientation

    return o
end

return DigStairsAction