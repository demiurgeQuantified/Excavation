local Eval = require("Excavation/Eval")
local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")
local DigCursor = require("Excavation/DigCursor")
local DigStairsCursor = require("Excavation/DigStairsCursor")
local DiggingAPI = require("Excavation/DiggingAPI")

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

---@param player IsoPlayer
---@param square IsoGridSquare
---@param context ISContextMenu
ContextMenu.doDigWallOption = function(player, square, context)
    local z = square:getZ()
    if z < 0 then
        local option = context:addOption(
            getText("IGUI_Excavation_DigWall"), player, ContextMenu.onDig)

        local material = z < DiggingAPI.STONE_LEVEL and "stone" or "dirt"

        local canDig, reason = DigSquareAction.canBePerformed(player, material)

        if not canDig then
            ---@cast reason -nil
            option.notAvailable = true
            option.toolTip = ISToolTip:new()
            option.toolTip.description = badColourString .. getText(reason)
        end
    end
end

ContextMenu.doDigStairsOption = function(player, square, context)
    local z = square:getZ()
    if z <= -1 and not SandboxVars.Excavation.DisableDepthLimit or z <= -32 then
        return
    end

    local option = context:addOption(
        getText("IGUI_Excavation_DigStairs"), player, ContextMenu.onDigStairs)

    local material = z <= DiggingAPI.STONE_LEVEL and "stone" or "dirt"

    local canDig, reason = DigStairsAction.canBePerformed(player, material)

    if not canDig then
        ---@cast reason -nil
        option.notAvailable = true
        option.toolTip = ISToolTip:new()
        option.toolTip.description = badColourString .. getText(reason)
    end
end

---@type Callback_OnFillWorldObjectContextMenu
ContextMenu.fillContextMenu = function(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)

    local targetSquare = worldObjects[1] and worldObjects[1]:getSquare()
    if not targetSquare then return end

    local square = player:getSquare()
    if not square then return end

    local inventory = player:getInventory()
    if not (inventory:containsEvalRecurse(Eval.canDigDirt)
            or inventory:containsEvalRecurse(Eval.canDigStone)) then
        return
    end

    if square:getZ() <= 0 then
        local digSubmenu = ISContextMenu:getNew(context)
        context:addSubMenu(
            context:addOption(getText("IGUI_Excavation_Dig")),
            digSubmenu)

        ContextMenu.doDigWallOption(player, square, digSubmenu)
        ContextMenu.doDigStairsOption(player, square, digSubmenu)
    end
end

Events.OnFillWorldObjectContextMenu.Add(ContextMenu.fillContextMenu)

return ContextMenu