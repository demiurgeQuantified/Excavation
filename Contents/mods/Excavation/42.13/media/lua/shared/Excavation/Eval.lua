local Eval = {}


---@param item InventoryItem
---@return boolean
Eval.canCarryDirt = function(item)
    return item:hasTag(ItemTag.HOLD_DIRT)
end


---@param item InventoryItem
---@return boolean
Eval.canDigDirt = function(item)
    return item:hasTag(ItemTag.DIG_GRAVE) and not item:isBroken()
end


---@param item InventoryItem
---@return boolean
Eval.canDigStone = function(item)
    return item:hasTag(ItemTag.PICK_AXE) and not item:isBroken()
end


return Eval