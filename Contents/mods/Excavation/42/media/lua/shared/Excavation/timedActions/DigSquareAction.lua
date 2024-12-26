local TimedActionUtils = require("Starlit/timedActions/TimedActionUtils")
local Eval = require("Excavation/Eval")

---@module "Excavation/DiggingAPI"
local DiggingAPI
Events.OnInitGlobalModData.Add(function()
    DiggingAPI = require("Excavation/DiggingAPI")
end)

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

---@class DigSquareAction : ISBaseTimedAction
---@field x integer
---@field y integer
---@field z integer
---@field digTool InventoryItem
---@field handle integer
---@field character IsoGameCharacter
local DigSquareAction = ISBaseTimedAction:derive("DigSquareAction")
DigSquareAction.__index = DigSquareAction

DigSquareAction.SACKS_NEEDED = 3

DigSquareAction.perform = function(self)
    self:stopCommon()
    DiggingAPI.digSquare(self.x, self.y, self.z)

    local inverseStrengthLevel = 10 - self.character:getPerkLevel(Perks.Strength)

    self.character:addArmMuscleStrain(2 + 3 * inverseStrengthLevel / 10)

    local stats = self.character:getStats()
    stats:setEndurance(stats:getEndurance() - (0.2 + inverseStrengthLevel / 80))

    -- when timed action cheat is on don't use sacks for easier debugging
    if not self.character:isTimedActionInstant() then
        local inventory = self.character:getInventory()
        local sacks = inventory:getSomeEval(Eval.canCarryDirt, DigSquareAction.SACKS_NEEDED)
        for i = 0, DigSquareAction.SACKS_NEEDED - 1 do
            inventory:Remove(sacks:get(i))
        end
        inventory:AddItems("Base.Dirtbag", DigSquareAction.SACKS_NEEDED)
        CACHE_ARRAY_LIST:clear()
    end

    ISBaseTimedAction.perform(self)
end

DigSquareAction.stop = function(self)
    self:stopCommon()
    ISBaseTimedAction.stop(self)
end

DigSquareAction.stopCommon = function(self)
    self.digTool:setJobDelta(0)
    self.character:getEmitter():stopSound(self.handle)
end

DigSquareAction.update = function(self)
    self.digTool:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
    local emitter = self.character:getEmitter()
    if not emitter:isPlaying(self.handle) then
        self.handle = emitter:playSound("Shoveling")
    end
    -- TODO: periodic player voice grunts?
end

DigSquareAction.start = function(self)
    self.digTool = self.character:getPrimaryHandItem()
    self:setActionAnim(BuildingHelper.getShovelAnim(self.digTool))
    self.digTool:setJobType(getText("IGUI_Excavation_Dig"))
    self.handle = self.character:getEmitter():playSound("Shoveling")
end

DigSquareAction.isValid = function(self)
    local primaryHandItem = self.character:getPrimaryHandItem()
    if not primaryHandItem or not Eval.canDig(primaryHandItem) then
        return false
    end

    local sacks = self.character:getInventory():getSomeEvalRecurse(
        Eval.canCarryDirt, DigSquareAction.SACKS_NEEDED, CACHE_ARRAY_LIST)
    if sacks:size() < DigSquareAction.SACKS_NEEDED then
        CACHE_ARRAY_LIST:clear()
        return false
    end
    CACHE_ARRAY_LIST:clear()

    return true
end

-- this doesn't work in b42 because complete() (where the equip actually applies)
-- doesn't run until after isValidStart
--
-- DigSquareAction.isValidStart = function(self)
--     -- local primaryHandItem = self.character:getPrimaryHandItem()
--     -- return primaryHandItem and Eval.canDig(primaryHandItem)
-- end

DigSquareAction.waitToStart = function(self)
    self.character:faceLocation(self.x, self.y)
    return self.character:shouldBeTurning()
end

---@param character IsoGameCharacter
---@param x integer
---@param y integer
---@param z integer
DigSquareAction.new = function(character, x, y, z)
    local o = ISBaseTimedAction:new(character)
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