local Eval = require("Excavation/Eval")
local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")
local DigCursor = require("Excavation/DigCursor")
local DigStairsCursor = require("Excavation/DigStairsCursor")

local badColour = getCore():getBadHighlitedColor()
badColour = table.newarray(badColour:getR(), badColour:getG(), badColour:getB())
local badColourString = string.format(" <RGB:%f,%f,%f> ", badColour[1], badColour[2], badColour[3])

local ContextMenu = {}

---@param player IsoPlayer
ContextMenu.onDig = function(player)
    getCell():setDrag(DigCursor.new(player), player:getPlayerNum())
end

---@param player IsoPlayer
ContextMenu.onDigStairs = function(player)
    getCell():setDrag(DigStairsCursor.new(player), player:getPlayerNum())
end

---@type Callback_OnFillWorldObjectContextMenu
ContextMenu.fillContextMenu = function(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)

    local targetSquare = worldObjects[1] and worldObjects[1]:getSquare()
    if not targetSquare then return end

    local square = player:getSquare()
    if not square then return end

    local inventory = player:getInventory()
    if not inventory:containsEvalRecurse(Eval.canDig) then return end

    -- TODO: refactor needed lol

    local z = square:getZ()
    if z <= 0 then
        local digSubmenu = ISContextMenu:getNew(context)
        context:addSubMenu(
            context:addOption(getText("IGUI_Excavation_Dig")),
            digSubmenu)

        local numSacks = inventory:getCountEvalRecurse(Eval.canCarryDirt)

        if z < 0 then
            local option = digSubmenu:addOption(
                getText("IGUI_Excavation_DigWall"), player, ContextMenu.onDig)

            local cantDigReason
            if numSacks < DigSquareAction.SACKS_NEEDED then
                cantDigReason = getText(
                    "Tooltip_Excavation_NeedDirtSack", DigSquareAction.SACKS_NEEDED)
            elseif player:getMoodleLevel(MoodleType.Endurance) >= 2 then
                cantDigReason = getText("Tooltip_Excavation_TooExhausted")
            end

            if cantDigReason then
                option.notAvailable = true
                option.toolTip = ISToolTip:new()
                option.toolTip.description = badColourString .. cantDigReason
            end
        end

        if z > -32 then
            local option = digSubmenu:addOption(
                getText("IGUI_Excavation_DigStairs"), player, ContextMenu.onDigStairs)

            local cantDigReason
            if numSacks < DigStairsAction.SACKS_NEEDED then
                cantDigReason = getText(
                    "Tooltip_Excavation_NeedDirtSack", DigStairsAction.SACKS_NEEDED)
            elseif player:getMoodleLevel(MoodleType.Endurance) >= 2 then
                cantDigReason = getText("Tooltip_Excavation_TooExhausted")
            end

            if cantDigReason then
                option.notAvailable = true
                option.toolTip = ISToolTip:new()
                option.toolTip.description = badColourString .. cantDigReason
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.fillContextMenu)

return ContextMenu