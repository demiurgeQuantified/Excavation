local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")
local DigStairsAction = require("Excavation/timedActions/DigStairsAction")
local DiggingAPI = require("Excavation/DiggingAPI")

local CORE = getCore()
---@type IsoSprite[]
local STAIRS_SPRITES_SOUTH = table.newarray(
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_5"),
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_4"),
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_3")
)
---@type IsoSprite[]
local STAIRS_SPRITES_EAST = table.newarray(
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_2"),
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_1"),
    IsoSpriteManager.instance:getSprite("fixtures_excavation_01_0")
)

---@class DigStairsCursor : starlit.BaseSquareCursor
---@field orientation "south"|"east"
local DigStairsCursor = {}
setmetatable(DigStairsCursor, BaseSquareCursor)
DigStairsCursor.__index = DigStairsCursor


function DigStairsCursor:select(square)
    DigStairsAction.queueNew(self.player, square, self.orientation)
    BaseSquareCursor.select(self, square)
end


---@param square IsoGridSquare
---@return boolean
function DigStairsCursor:isValidInternal(square)
    if not square then
        return false
    end

    local material = DiggingAPI.getMaterialAtCoords(
        square:getX(), square:getY(), square:getZ() - 1)
    if not material then
        return false
    end

    if not DigStairsAction.canBePerformed(self.player, material, square, self.orientation) then
        return false
    end

    return true
end


function DigStairsCursor:render(x, y, z, square)
    -- TODO: individual colours for each square so the player can tell why/where they can't dig
    local hc = getCore():getGoodHighlitedColor()
    if not self:isValid(square) then
        hc = getCore():getBadHighlitedColor()
    end

    local floorCursorSprite = ISBuildingObject:getFloorCursorSprite() --[[@as IsoSprite]]
    floorCursorSprite:RenderGhostTileColor(x, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
    if self.orientation == "south" then
        for i = 1, 3 do
            -- STAIRS_SPRITES_SOUTH[i]:RenderGhostTileColor(x, y + i, z - 1, hc:getR(), hc:getG(), hc:getB(), 0.6)
            floorCursorSprite:RenderGhostTileColor(x, y + i, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
        end
        floorCursorSprite:RenderGhostTileColor(x, y + 4, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
    else
        for i = 1, 3 do
            -- STAIRS_SPRITES_EAST[i]:RenderGhostTileColor(x + i, y, z - 1, hc:getR(), hc:getG(), hc:getB(), 0.6)
            floorCursorSprite:RenderGhostTileColor(x + i, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
        end
        floorCursorSprite:RenderGhostTileColor(x + 4, y, z, hc:getR(), hc:getG(), hc:getB(), 0.8)
    end
end


function DigStairsCursor:rotate()
    self.orientation = self.orientation == "south" and "east" or "south"
end


function DigStairsCursor:keyPressed(key)
    -- TODO: should also be able to rotate by dragging the mouse
    if CORE:isKey("Rotate building", key) then
        self:rotate()
    end
end


function DigStairsCursor:onJoypadPressLB(joypadData)
    self:rotate()
end


function DigStairsCursor:onJoypadPressRB(joypadData)
    self:rotate()
end


function DigStairsCursor:getAPrompt()
    local square = getSquare(self.xJoypad, self.yJoypad, self.zJoypad)
    return self:isValid(square) and getText("IGUI_Excavation_DigStairs") or nil
end


function DigStairsCursor:getLBPrompt()
    return getText("IGUI_Controller_RotateLeft")
end


function DigStairsCursor:getRBPrompt()
    return getText("IGUI_Controller_RotateRight")
end


---@param player IsoPlayer
---@return DigStairsCursor
function DigStairsCursor.new(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigStairsCursor) ---@cast o DigStairsCursor

    o.orientation = "south"

    return o
end


return DigStairsCursor