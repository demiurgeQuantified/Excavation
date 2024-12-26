local Eval = require("Excavation/Eval")
local DigSquareAction = require("Excavation/timedActions/DigSquareAction")

local badColour = getCore():getBadHighlitedColor()
badColour = table.newarray(badColour:getR(), badColour:getG(), badColour:getB())
local badColourString = string.format(" <RGB:%f,%f,%f> ", badColour[1], badColour[2], badColour[3])

-- annoying that these have to be in server...
---@module "Excavation/DigCursor"
local DigCursor
Events.OnInitGlobalModData.Add(function()
    DigCursor = require("Excavation/DigCursor")
end)

local CACHE_ARRAY_LIST = ArrayList.new()

---@param player IsoPlayer
local onDig = function(player)
    getCell():setDrag(DigCursor.new(player), player:getPlayerNum())
end

Events.OnFillWorldObjectContextMenu.Add(
    function (playerNum, context, worldObjects, test)
        local player = getSpecificPlayer(playerNum)
        local square = player:getSquare()
        if not square or square:getZ() >= 0 then return end

        local targetSquare = worldObjects[1] and worldObjects[1]:getSquare()
        if not targetSquare then return end
        local inventory = player:getInventory()
        if not inventory:containsEvalRecurse(Eval.canDig) then return end

        local option = context:addOption(
            getText("IGUI_Excavation_Dig"), player, onDig)

        local cantDigReason
        if inventory:getSomeEvalRecurse(
                Eval.canCarryDirt, DigSquareAction.SACKS_NEEDED, CACHE_ARRAY_LIST):size() < DigSquareAction.SACKS_NEEDED then
            cantDigReason = getText(
                "Tooltip_Excavation_NeedDirtSack", DigSquareAction.SACKS_NEEDED)
        elseif player:getMoodleLevel(MoodleType.Endurance) >= 1 then
            cantDigReason = getText("Tooltip_Excavation_TooExhausted")
        end

        if cantDigReason then
            option.notAvailable = true
            -- TODO: is it worth caching one of these?
            option.toolTip = ISToolTip:new()
            option.toolTip.description = badColourString .. cantDigReason
        end

        CACHE_ARRAY_LIST:clear()
    end)
