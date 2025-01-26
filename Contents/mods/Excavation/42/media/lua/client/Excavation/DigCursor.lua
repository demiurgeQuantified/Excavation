local DigSquareAction = require("Excavation/timedActions/DigSquareAction")
local BaseSquareCursor = require("Starlit/client/BaseSquareCursor")
local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local Config = require("Excavation/Config")

---@type {string : true}
local DIGGABLE_SPRITES = {}
for _, sprite in pairs(DiggingAPI.DIRT) do
    DIGGABLE_SPRITES[sprite] = true
end
for _, sprite in pairs(DiggingAPI.STONE) do
    DIGGABLE_SPRITES[sprite] = true
end

---@class DigCursor : Starlit.BaseSquareCursor
local DigCursor = {}
setmetatable(DigCursor, BaseSquareCursor)
DigCursor.__index = DigCursor

DigCursor.select = function(self, square)
    local z = square:getZ()
    DigSquareAction.queueNew(
        self.player, square:getX(), square:getY(), z,
        z < DiggingAPI.STONE_LEVEL and "stone" or "dirt")

    BaseSquareCursor.select(self, square, Config.hideCursorAfterDigging:getValue())
end

DigCursor.isValidInternal = function(self, square)
    if not square then
        return false
    end

    local material = DiggingAPI.getMaterialAt(square)
    if not material then
        return false
    end

    return DigSquareAction.canBePerformed(self.player, material, square)
end

---@param player IsoPlayer
---@return DigCursor
DigCursor.new = function(player)
    local o = BaseSquareCursor.new(player)
    setmetatable(o, DigCursor) ---@cast o DigCursor

    return o
end

-- fixes the annoying blocks spawning when you click out of bounds
Events.OnDoTileBuilding2.Add(function(cursor, bRender,
                                                x, y, z, square)
    if z >= 0 then return end
    for x = x - 1, x + 1 do
        for y = y - 1, y + 1 do
            local square = getSquare(x, y, z)
            if square then
                square:removeUnderground()
            end
        end
    end
end)

-- evil server folder client code
Events.OnInitGlobalModData.Add(function()
    -- don't allow sledgehammering dirt/stone tiles
    local old_canDestroy = ISDestroyCursor.canDestroy
    ---@param object IsoObject
    ISDestroyCursor.canDestroy = function(self, object)
        local spriteName = object:getSprite():getName()
        if spriteName and DIGGABLE_SPRITES[spriteName] then
            return false
        end

        return old_canDestroy(self, object)
    end
end)

-- replace sledgehammered exterior walls underground with dirt/stone
local old_complete = ISDestroyStuffAction.complete
ISDestroyStuffAction.complete = function(self)
    local originalReturnValue = old_complete(self)

    local square = self.item--[[@as IsoObject]]:getSquare()
    local z = square:getZ()
    if z >= 0 then
        return originalReturnValue
    end

    local hasFloor = square:hasFloor()
    local material = z > DiggingAPI.STONE_LEVEL and DiggingAPI.DIRT or DiggingAPI.STONE
    local properties = self.item--[[@as IsoObject]]:getProperties()
    local sprite
    if properties:Is(IsoFlagType.WallN) then
        local neighbour = square:getAdjacentSquare(IsoDirections.N)
        if not hasFloor or not neighbour:hasFloor() then
            local westWall = IsoObjectUtils.getWall(square, "west")
            -- if there's already a west wall, delete it so we can replace it with the merged sprite
            if westWall and westWall:getSprite():getName() == material.wallWest then
                square:transmitRemoveItemFromSquare(westWall)
                sprite = material.wallCornerNorthwest
            else
                sprite = material.wallNorth
            end
        else
            -- add a corner if appropriate when demolishing near a diggable material
            local westWall = IsoObjectUtils.getWall(neighbour, "west")
            local northWall = IsoObjectUtils.getWall(square:getAdjacentSquare(IsoDirections.W), "north")
            if westWall and northWall
                    and (DIGGABLE_SPRITES[westWall:getSprite():getName()]
                        or DIGGABLE_SPRITES[northWall:getSprite():getName()]) then
                square:transmitAddObjectToSquare(
                    IsoObject.getNew(square, material.wallCornerSoutheast, "", false), -1)
            end
        end
    elseif properties:Is(IsoFlagType.WallW) then
        local neighbour = square:getAdjacentSquare(IsoDirections.W)
        if not hasFloor or not neighbour:hasFloor() then
            local northWall = IsoObjectUtils.getWall(square, "north")
            if northWall and northWall:getSprite():getName() == material.wallNorth then
                square:transmitRemoveItemFromSquare(northWall)
                sprite = material.wallCornerNorthwest
            else
                sprite = material.wallWest
            end
        else
            local northWall = IsoObjectUtils.getWall(neighbour, "north")
            local westWall = IsoObjectUtils.getWall(square:getAdjacentSquare(IsoDirections.N), "north")
            if northWall and westWall
                    and (DIGGABLE_SPRITES[northWall:getSprite():getName()]
                        or DIGGABLE_SPRITES[westWall:getSprite():getName()]) then
                square:transmitAddObjectToSquare(
                    IsoObject.getNew(square, material.wallCornerSoutheast, "", false), -1)
            end
        end
    elseif properties:Is(IsoFlagType.WallSE) then
        if not hasFloor or not square:getAdjacentSquare(IsoDirections.NW):hasFloor() then
            sprite = material.wallCornerSoutheast
        end
    elseif properties:Is(IsoFlagType.WallNW) then
        if self.cornerCounter == 0 then -- north
            if not hasFloor or not square:getAdjacentSquare(IsoDirections.N):hasFloor() then
                sprite = material.wallNorth
            end
        elseif not hasFloor or not square:getAdjacentSquare(IsoDirections.W):hasFloor() then -- west
            sprite = material.wallWest
        end
    end

    if sprite then
        square:transmitAddObjectToSquare(
            IsoObject.getNew(square, sprite, "", false), -1)
    end

    return originalReturnValue
end

return DigCursor