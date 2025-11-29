local Eval = require("Excavation/Eval")
local DiggingAPI = require("Excavation/DiggingAPI")

local CACHE_ARRAY_LIST = ArrayList.new()


---@class BaseDigAction : ISBaseTimedAction
---@field digTool InventoryItem
---@field handle integer
---@field material "dirt"|"stone"
local BaseDigAction = ISBaseTimedAction:derive("BaseDigAction")
BaseDigAction.__index = BaseDigAction


BaseDigAction.SACKS_NEEDED = 0
BaseDigAction.STONE_REWARD = 0


function BaseDigAction:complete()
    -- when build cheat is on don't do anything to items
    if not self.character:isBuildCheat() then
        local inventory = self.character:getInventory()
        if self.material == "dirt" and self.SACKS_NEEDED > 0 then
            local sacks = inventory:getSomeEval(Eval.canCarryDirt, self.SACKS_NEEDED)
            for i = 0, self.SACKS_NEEDED - 1 do
                inventory:Remove(sacks:get(i))
            end
            sendRemoveItemsFromContainer(inventory, sacks)

            local items = inventory:addItems(ItemKey.Drainable.DIRTBAG, self.SACKS_NEEDED)
            sendAddItemsToContainer(inventory, items--[[@as ArrayList<InventoryItem>]])
        elseif self.material == "stone" and self.STONE_REWARD > 0 then
            local stones = inventory:addItems(ItemKey.Weapon.STONE_2, self.STONE_REWARD)
            sendAddItemsToContainer(inventory, stones--[[@as ArrayList<InventoryItem>]])
        end
    end

    return true
end


function BaseDigAction:perform()
    self:stopCommon()
    ISBaseTimedAction.perform(self)
end


function BaseDigAction:stop()
    self:stopCommon()
    ISBaseTimedAction.stop(self)
end


function BaseDigAction:stopCommon()
    self.digTool:setJobDelta(0)
    self.character:getEmitter():stopSound(self.handle)
end


function BaseDigAction:start()
    self.digTool = self.character:getPrimaryHandItem()
    self:setActionAnim(BuildingHelper.getShovelAnim(self.digTool))
    self.digTool:setJobType(getText("IGUI_Excavation_Dig"))
    self.handle = self.character:getEmitter():playSound("Shoveling")
end


function BaseDigAction:update()
    self.digTool:setJobDelta(self:getJobDelta())
    self.character:setMetabolicTarget(Metabolics.HeavyWork)
    local emitter = self.character:getEmitter()
    if not emitter:isPlaying(self.handle) then
        self.handle = emitter:playSound("Shoveling")
    end
end


function BaseDigAction:isValid()
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
function BaseDigAction.canBePerformed(character, material, square)
    local canDig, reason = DiggingAPI.characterCanDig(character, material)
    if not canDig then
        return canDig, reason
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
---@return self
function BaseDigAction:new(character, material)
    assert(
        self ~= BaseDigAction,
        "tried to instantiate abstract BaseDigAction"
    )

    local o = ISBaseTimedAction.new(self, character) ---@as BaseDigAction

    o.material = material

    return o
end

return BaseDigAction