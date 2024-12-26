local BaseDigAction = require("Excavation/timedActions/BaseDigAction")
local TimedActionUtils = require("Starlit/timedActions/TimedActionUtils")
local Eval = require("Excavation/Eval")
local DiggingAPI = require("Excavation/DiggingAPI")

local CACHE_ARRAY_LIST = ArrayList.new()

---@param x integer
---@param y integer
---@param z integer
---@param character IsoGameCharacter
---@return IsoGridSquare?
local getClosestAdjacentSquare = function(x, y, z, character)
    local squares = table.newarray() --[=[@as IsoGridSquare[]]=]
    table.insert(squares, getSquare(x - 1, y, z))
    table.insert(squares, getSquare(x + 1, y, z))
    table.insert(squares, getSquare(x, y - 1, z))
    table.insert(squares, getSquare(x, y + 1, z))
    if #squares <= 1 then
        return squares[1]
    end

    local closest
    local closestDist = 1000000
    for i = 1, #squares do
        local square = squares[i]
        local dist = square:DistToProper(character)
        if dist < closestDist then
            closestDist = dist
            closest = square
        end
    end
    return closest
end

---@class DigSquareAction : BaseDigAction
---@field x integer
---@field y integer
---@field z integer
local DigSquareAction = BaseDigAction:derive("DigSquareAction")
DigSquareAction.__index = DigSquareAction

DigSquareAction.SACKS_NEEDED = 3

DigSquareAction.perform = function(self)
    DiggingAPI.digSquare(self.x, self.y, self.z)

    local inverseStrengthLevel = 10 - self.character:getPerkLevel(Perks.Strength)

    self.character:addArmMuscleStrain(2 + 3 * inverseStrengthLevel / 10)

    local stats = self.character:getStats()
    stats:setEndurance(stats:getEndurance() - (0.2 + inverseStrengthLevel / 80))

    BaseDigAction.perform(self)
end

DigSquareAction.isValid = function(self)
    local primaryHandItem = self.character:getPrimaryHandItem()
    if not primaryHandItem or not Eval.canDig(primaryHandItem) then
        return false
    end

    return BaseDigAction.isValid(self)
end

DigSquareAction.waitToStart = function(self)
    self.character:faceLocation(self.x, self.y)
    return self.character:shouldBeTurning()
end

---@param character IsoGameCharacter
---@param x integer
---@param y integer
---@param z integer
DigSquareAction.new = function(character, x, y, z)
    local o = BaseDigAction.new(character)
    setmetatable(o, DigSquareAction)

    o.x = x
    o.y = y
    o.z = z
    o.maxTime = character:isTimedActionInstant() and 1 or 500

    return o
end

---@param character IsoGameCharacter
---@param x integer
---@param y integer
---@param z integer
---@return boolean success
DigSquareAction.queueNew = function(character, x, y, z)
    local adjacentSquare = getClosestAdjacentSquare(x, y, z, character)
    if not adjacentSquare then return false end
    ISTimedActionQueue.add(
        ISWalkToTimedAction:new(character, adjacentSquare))

    if not character:getInventory():getSomeEvalRecurse(Eval.canCarryDirt, DigSquareAction.SACKS_NEEDED) then
        return false
    end
    TimedActionUtils.transferSomeValid(
        character, nil, Eval.canCarryDirt, nil,
        DigSquareAction.SACKS_NEEDED)

    if not TimedActionUtils.transferAndEquipFirstEval(character,
                                                      Eval.canDig,
                                                      "primary") then
        return false
    end

    ISTimedActionQueue.add(
        DigSquareAction.new(
            character, x, y, z)
    )

    return true
end

return DigSquareAction