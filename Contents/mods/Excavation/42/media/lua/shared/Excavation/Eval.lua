local Eval = {}

---@type ItemContainer_Predicate
Eval.canCarryDirt = function(item)
    return item:hasTag("HoldDirt")
end

---@type ItemContainer_Predicate
Eval.canDig = function(item)
    return item:hasTag("DigGrave") and not item:isBroken()
end

return Eval