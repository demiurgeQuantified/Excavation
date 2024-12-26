local Eval = require("Excavation/Eval")

local CACHE_ARRAY_LIST = ArrayList.new()

---@class BaseDigAction : ISBaseTimedAction
---@field character IsoGameCharacter
---@field digTool InventoryItem
---@field handle integer
local BaseDigAction = ISBaseTimedAction:derive("BaseDigAction")
BaseDigAction.__index = BaseDigAction

BaseDigAction.SACKS_NEEDED = 0

BaseDigAction.perform = function(self)
    -- when timed action cheat is on don't use sacks for easier debugging
    if self.SACKS_NEEDED > 0 and not self.character:isTimedActionInstant() then
        local inventory = self.character:getInventory()
        local sacks = inventory:getSomeEval(Eval.canCarryDirt, self.SACKS_NEEDED, CACHE_ARRAY_LIST)
        for i = 0, self.SACKS_NEEDED - 1 do
            inventory:Remove(sacks:get(i))
        end
        inventory:AddItems("Base.Dirtbag", self.SACKS_NEEDED)
        CACHE_ARRAY_LIST:clear()
    end

    self:stopCommon()
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
    local sacks = self.character:getInventory():getSomeEvalRecurse(
        Eval.canCarryDirt, self.SACKS_NEEDED, CACHE_ARRAY_LIST)
    if sacks:size() < self.SACKS_NEEDED then
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

---@param character IsoGameCharacter
---@return BaseDigAction
BaseDigAction.new = function(character)
    local o = ISBaseTimedAction:new(character)
    setmetatable(o, BaseDigAction) ---@cast o BaseDigAction

    return o
end

return BaseDigAction