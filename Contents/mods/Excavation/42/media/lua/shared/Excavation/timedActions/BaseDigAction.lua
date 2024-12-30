local Eval = require("Excavation/Eval")
local DiggingAPI = require("Excavation/DiggingAPI")

local CACHE_ARRAY_LIST = ArrayList.new()

---@class BaseDigAction : ISBaseTimedAction
---@field character IsoGameCharacter
---@field digTool InventoryItem
---@field handle integer
---@field material "dirt"|"stone"
local BaseDigAction = ISBaseTimedAction:derive("BaseDigAction")
BaseDigAction.__index = BaseDigAction

BaseDigAction.SACKS_NEEDED = 0
BaseDigAction.STONE_REWARD = 0

BaseDigAction.perform = function(self)
    self:stopCommon()

    -- when timed action cheat is on don't use sacks for easier debugging
    if self.material == "dirt" and self.SACKS_NEEDED > 0 and not self.character:isTimedActionInstant() then
        local inventory = self.character:getInventory()
        local sacks = inventory:getSomeEval(Eval.canCarryDirt, self.SACKS_NEEDED, CACHE_ARRAY_LIST)
        for i = 0, self.SACKS_NEEDED - 1 do
            inventory:Remove(sacks:get(i))
        end
        inventory:AddItems("Base.Dirtbag", self.SACKS_NEEDED)
        CACHE_ARRAY_LIST:clear()
    elseif self.material == "stone" and self.STONE_REWARD > 0 then
        self.character:getInventory():AddItems("Base.Stone2", self.STONE_REWARD)
    end

    ISBaseTimedAction.perform(self)
end

BaseDigAction.stop = function(self)
    self:stopCommon()
    ISBaseTimedAction.stop(self)
end

BaseDigAction.stopCommon = function(self)
    self.digTool:setJobDelta(0)
    self.character:getEmitter():stopSound(self.handle)
end

BaseDigAction.start = function(self)
    self.digTool = self.character:getPrimaryHandItem()
    self:setActionAnim(BuildingHelper.getShovelAnim(self.digTool))
    self.digTool:setJobType(getText("IGUI_Excavation_Dig"))
    self.handle = self.character:getEmitter():playSound("Shoveling")
end

BaseDigAction.update = function(self)
    self.digTool:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
    local emitter = self.character:getEmitter()
    if not emitter:isPlaying(self.handle) then
        self.handle = emitter:playSound("Shoveling")
    end
end

BaseDigAction.isValid = function(self)
    if self.material == "dirt" and self.SACKS_NEEDED > 0 then
        local sacks = self.character:getInventory():getSomeEvalRecurse(
            Eval.canCarryDirt, self.SACKS_NEEDED, CACHE_ARRAY_LIST)
        if sacks:size() < self.SACKS_NEEDED then
            CACHE_ARRAY_LIST:clear()
            return false
        end
        CACHE_ARRAY_LIST:clear()
    end

    local primaryHandItem = self.character:getPrimaryHandItem()
    if not primaryHandItem
            or (self.material == "dirt" and not Eval.canDigDirt(primaryHandItem))
            or (self.material == "stone" and not Eval.canDigStone(primaryHandItem)) then
        return false
    end

    return true
end

---@param character IsoGameCharacter
---@param material "stone"|"dirt"
---@param square IsoGridSquare?
---@return boolean canPerform, string? reason, any arg
BaseDigAction.canBePerformed = function(character, material, square)
    if material then
        local canDig, reason = DiggingAPI.characterCanDig(
            character, material)
        if not canDig then
            return canDig, reason
        end
    end

    return true
end

-- this doesn't work in b42 because complete() (where the equip actually applies)
-- doesn't run until after isValidStart
--
-- DigSquareAction.isValidStart = function(self)
--     -- local primaryHandItem = self.character:getPrimaryHandItem()
--     -- return primaryHandItem and Eval.canDig(primaryHandItem)
-- end

---@param character IsoGameCharacter
---@param material "dirt"|"stone"
---@return BaseDigAction
BaseDigAction.new = function(character, material)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, BaseDigAction) ---@cast o BaseDigAction

    o.material = material

    return o
end

return BaseDigAction