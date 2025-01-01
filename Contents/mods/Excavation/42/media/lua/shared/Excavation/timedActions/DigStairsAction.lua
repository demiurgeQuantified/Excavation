local BaseDigAction = require("Excavation/timedActions/BaseDigAction")
local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local TimedActionUtils = require("Starlit/timedActions/TimedActionUtils")
local Eval = require("Excavation/Eval")

---@class DigStairsAction : BaseDigAction
---@field originSquare IsoGridSquare
---@field orientation "south"|"east"
local DigStairsAction = BaseDigAction:derive("DigStairsAction")
DigStairsAction.__index = DigStairsAction

DigStairsAction.SACKS_NEEDED = 6
DigStairsAction.STONE_REWARD = 6

DigStairsAction.perform = function(self)
    local x, y, z = self.originSquare:getX(), self.originSquare:getY(), self.originSquare:getZ()
    if self.orientation == "south" then
        -- TODO: this creates and then destroys internal walls
        -- to optimise this DiggingAPI needs a way to open an area of squares and calculate the necessary walls once
        for i = 1, 3 do
            -- remove the floor above the stairs
            DiggingAPI.digFloor(getSquare(x, y + i, z))

            -- clear the square below
            local belowSquare = IsoObjectUtils.getOrCreateSquare(x, y + i, z - 1)
            DiggingAPI.digSquare(x, y + i, z - 1)

            -- add the stair object
            -- TODO: these sprites don't quite reach the next level - looks good enough imo but should be fixed
            local obj = IsoObject.getNew(
                belowSquare, "fixtures_excavation_01_" .. tostring(6 - i), "", false)
            belowSquare:transmitAddObjectToSquare(obj, -1)
        end

        local endSquare = IsoObjectUtils.getOrCreateSquare(x, y + 4, z - 1)
        if not endSquare:hasFloor() then
            DiggingAPI.digSquare(x, y + 4, z - 1)
        end
    else
        for i = 1, 3 do
            DiggingAPI.digFloor(getSquare(x + i, y, z))

            local belowSquare = IsoObjectUtils.getOrCreateSquare(x + i, y, z - 1)
            DiggingAPI.digSquare(x + i, y, z - 1)

            local obj = IsoObject.getNew(
                belowSquare, "fixtures_excavation_01_" .. tostring(3 - i), "", false)
            belowSquare:transmitAddObjectToSquare(obj, -1)
        end

        local endSquare = IsoObjectUtils.getOrCreateSquare(x + 4, y, z - 1)
        if not endSquare:getFloor() then
            DiggingAPI.digSquare(x + 4, y, z - 1)
        end
    end

    local inverseStrengthLevel = 10 - self.character:getPerkLevel(Perks.Strength)

    self.character:addArmMuscleStrain(3 + 4 * inverseStrengthLevel / 10)
    self.character:addBackMuscleStrain(2 + 2 * inverseStrengthLevel / 10)

    local stats = self.character:getStats()
    stats:setEndurance(stats:getEndurance() - (0.4 + inverseStrengthLevel / 80))

    -- FIXME: even numbered floors flicker until their chunk has gone offscreen
    -- this is probably related to every 2 floors sharing a texture

    -- cutaway is just permanently buggy :/ i think the cutaway system just doesn't handle underground well right now
    BaseDigAction.perform(self)
end

DigStairsAction.waitToStart = function(self)
    self.character:faceDirection(self.orientation == "south" and IsoDirections.S or IsoDirections.E)
    return self.character:shouldBeTurning()
end

-- TODO: isValid that checks the area below hasn't been dug into and area hasn't been obstructed

---@param orientation "south"|"east"|nil
DigStairsAction.canBePerformed = function(character, material, square, orientation)
    if square then
        ---@cast orientation -nil
        local z = square:getZ()

        if not square:hasFloor() or not DiggingAPI.isSquareClear(square, nil, character) then
            return false
        end

        local x, y = square:getX(), square:getY()
        local endSquare
        if orientation == "south" then
            for i = 1, 3 do
                local square = getSquare(x, y + i, z)
                if not DiggingAPI.canDigDownFrom(square)
                        or not DiggingAPI.isSquareClear(square, orientation, character) then
                    return false
                end
            end

            endSquare = getSquare(x, y + 4, z - 1)
        else
            for i = 1, 3 do
                local square = getSquare(x + i, y, z)
                if not DiggingAPI.canDigDownFrom(square)
                        or not DiggingAPI.isSquareClear(square, orientation, character) then
                    return false
                end
            end

            endSquare = getSquare(x + 4, y, z - 1)
        end

        -- it's fine if the end square isn't in playable area, but if it is must have a floor and be accessible
        if endSquare and (IsoObjectUtils.isInPlayableArea(endSquare)
                and not endSquare:hasFloor() or endSquare:Is("BlocksPlacement")) then
            return false
        end
    end

    local inventory = character:getInventory()
    if inventory:getCountEvalRecurse(Eval.canCarryDirt) < DigStairsAction.SACKS_NEEDED then
        return false, "Tooltip_Excavation_NeedDirtSack", DigStairsAction.SACKS_NEEDED
    end

    return BaseDigAction.canBePerformed(character, material, square)
end

---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@return boolean success
DigStairsAction.queueNew = function(character, square, orientation)
    ISTimedActionQueue.add(
        ISWalkToTimedAction:new(character, square))

    local material = square:getZ() <= DiggingAPI.STONE_LEVEL and "stone" or "dirt"
    if material == "stone" then
        if not TimedActionUtils.transferAndEquipFirstEval(character, Eval.canDigStone) then
            return false
        end
    else
        if not character:getInventory():getSomeEvalRecurse(Eval.canCarryDirt,
                                                           DigStairsAction.SACKS_NEEDED) then
            return false
        end
        TimedActionUtils.transferSomeValid(
            character, nil,
            Eval.canCarryDirt, nil, DigStairsAction.SACKS_NEEDED)

        if not TimedActionUtils.transferAndEquipFirstEval(character, Eval.canDigDirt) then
            return false
        end
    end
    ISTimedActionQueue.add(
        DigStairsAction.new(
            character, square, orientation, material))
    return true
end

---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@param material "stone"|"dirt"
---@return DigStairsAction
DigStairsAction.new = function(character, square, orientation, material)
    local o = BaseDigAction.new(
        character, material)
    setmetatable(o, DigStairsAction) ---@cast o DigStairsAction

    o.maxTime = character:isTimedActionInstant() and 1 or 1000
    o.originSquare = square
    o.orientation = orientation

    return o
end

return DigStairsAction