local Eval = require("Excavation/Eval")
local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")
local DigCursor = require("Excavation/DigCursor")
local DigStairsCursor = require("Excavation/DigStairsCursor")
local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local Version = require("Starlit/Version")

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

        local canDig, reason, arg = DigSquareAction.canBePerformed(player, material)

        if not canDig then
            ---@cast reason -nil
            option.notAvailable = true
            option.toolTip = ISToolTip:new()
            option.toolTip.description = badColourString .. getText(reason, arg)
        end
    end
end

---@param player IsoPlayer
---@param square IsoGridSquare
---@param context ISContextMenu
ContextMenu.doDigStairsOption = function(player, square, context)
    local z = square:getZ()
    if z <= -1 and not SandboxVars.Excavation.DisableDepthLimit or z <= -32 then
        return
    end

    local option = context:addOption(
        getText("IGUI_Excavation_DigStairs"), player, ContextMenu.onDigStairs)

    local material = z <= DiggingAPI.STONE_LEVEL and "stone" or "dirt"

    local canDig, reason, arg = DigStairsAction.canBePerformed(player, material)

    if not canDig then
        ---@cast reason -nil
        option.notAvailable = true
        option.toolTip = ISToolTip:new()
        option.toolTip.description = badColourString .. getText(reason, arg)
    end
end

---@param player IsoPlayer
---@param context ISContextMenu
ContextMenu.fixMissingSheetRopeOption = function(player, context)
    -- mostly just copy pasted from vanilla since it's a temp fix anyway
    local fetch = ISWorldObjectContextMenu.fetchVars
    local hoppableObject = fetch.hoppableN or fetch.hoppableW or fetch.thumpableWindow

    local inventory = player:getInventory()

    if hoppableObject ~= nil and not fetch.invincibleWindow and not fetch.window then
        if hoppableObject:canAddSheetRope() and player:getCurrentSquare():getZ() <= 0 and
                (hoppableObject:getSprite():getProperties():Is("TieSheetRope") or (inventory:containsTypeRecurse("Nails") and inventory:containsTypeRecurse("Hammer"))) then
            if (inventory:getItemCountRecurse("SheetRope") >= hoppableObject:countAddSheetRope()) then
                if hoppableObject:getSprite():getProperties():Is("TieSheetRope") then
                    context:addGetUpOption(getText("ContextMenu_Tie_escape_rope_sheet"), nil, ISWorldObjectContextMenu.onAddSheetRope, hoppableObject, player:getIndex(), true);
                else
                    context:addGetUpOption(getText("ContextMenu_Nail_escape_rope_sheet"), nil, ISWorldObjectContextMenu.onAddSheetRope, hoppableObject, player:getIndex(), true);
                end
            end
            if (inventory:getItemCountRecurse("Rope") >= hoppableObject:countAddSheetRope()) then
                if hoppableObject:getSprite():getProperties():Is("TieSheetRope") then
                    context:addGetUpOption(getText("ContextMenu_Tie_escape_rope"), nil, ISWorldObjectContextMenu.onAddSheetRope, hoppableObject, player:getIndex(), false);
                else
                    context:addGetUpOption(getText("ContextMenu_Nail_escape_rope"), nil, ISWorldObjectContextMenu.onAddSheetRope, hoppableObject, player:getIndex(), false);
                end
            end
        end
        if hoppableObject:haveSheetRope() then
            context:addGetUpOption(getText("ContextMenu_Remove_escape_rope"), nil, ISWorldObjectContextMenu.onRemoveSheetRope, hoppableObject, player:getIndex());
        end
    end

    if fetch.window ~= nil and not fetch.invincibleWindow then
        if fetch.window:canAddSheetRope() and player:getCurrentSquare():getZ() <= 0 and not fetch.window:isBarricaded() and inventory:containsTypeRecurse("Nails") and inventory:containsTypeRecurse("Hammer") then
            if (inventory:getItemCountRecurse("SheetRope") >= fetch.window:countAddSheetRope()) then
                context:addGetUpOption(getText("ContextMenu_Nail_escape_rope_sheet"), nil, ISWorldObjectContextMenu.onAddSheetRope, fetch.window, player:getIndex(), true);
            elseif (inventory:getItemCountRecurse("Rope") >= fetch.window:countAddSheetRope()) then
                context:addGetUpOption(getText("ContextMenu_Nail_escape_rope"), nil, ISWorldObjectContextMenu.onAddSheetRope, fetch.window, player:getIndex(), false);
            end
        end
        if fetch.window:haveSheetRope() then
            context:addGetUpOption(getText("ContextMenu_Remove_escape_rope"), nil, ISWorldObjectContextMenu.onRemoveSheetRope, fetch.window, player:getIndex());
        end
    end
end

---@type Callback_OnFillWorldObjectContextMenu
ContextMenu.fillContextMenu = function(playerNum, context, worldObjects, test)
    local player = getSpecificPlayer(playerNum)

    ContextMenu.fixMissingSheetRopeOption(player, context)

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

-- hack to fix sheet ropes below 0 not being removed
local old_complete = ISRemoveSheetRope.complete
---@diagnostic disable-next-line: duplicate-set-field
ISRemoveSheetRope.complete = function(self)
    local z = self.window:getZ()
    if z >= 0 then
        local x, y = self.window:getX(), self.window:getY()

        local topSquare = self.window:getSquare()
        local deleteProperty
        if self.window:isNorthHoppable() then
            if IsoObjectUtils.getFirst(topSquare, IsoFlagType.climbSheetTopN) then
                deleteProperty = IsoFlagType.climbSheetN
            else
                deleteProperty = IsoFlagType.climbSheetS
                y = y - 1
            end
        else
            if IsoObjectUtils.getFirst(topSquare, IsoFlagType.climbSheetTopW) then
                deleteProperty = IsoFlagType.climbSheetW
            else
                deleteProperty = IsoFlagType.climbSheetE
                x = x - 1
            end
        end

        -- scan to see if this sheet rope actually goes underground
        for i = z, 0, -1 do
            local square = getSquare(x, y, i)

            if not square or square:TreatAsSolidFloor() then
                return old_complete(self)
            end
        end

        for i = 0, -32, -1 do
            local square = getSquare(x, y, i)
            if not square then
                return old_complete(self)
            end

            local objects = square:getLuaTileObjectList() --[=[@as IsoObject[]]=]
            for j = 1, #objects do
                local object = objects[j]
                if object:getProperties():Is(deleteProperty) then
                    square:transmitRemoveItemFromSquare(object)
                    self.character:getInventory():AddItem(object:getName())
                    break
                end
            end

            if square:TreatAsSolidFloor() then
                return old_complete(self)
            end
        end
    end

    return old_complete(self)
end

-- TODO: temp, move this somewhere else
Events.OnGameStart.Add(function()
    -- 1.3.1 is required due to cursor isValidInternal only being added in that version
    Version.ensureVersion(1, 3, 1)
end)

return ContextMenu