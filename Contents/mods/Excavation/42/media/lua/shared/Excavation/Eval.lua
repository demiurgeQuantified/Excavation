local Eval = {}

---@type ItemContainer_Predicate
Eval.canCarryDirt = function(item)
    return item:hasTag("HoldDirt")
end

---@type ItemContainer_Predicate
Eval.canDigDirt = function(item)
    return item:hasTag("DigGrave") and not item:isBroken()
end

---@type ItemContainer_Predicate
Eval.canDigStone = function(item)
    return item:hasTag("PickAxe") and not item:isBroken()
end

return Eval