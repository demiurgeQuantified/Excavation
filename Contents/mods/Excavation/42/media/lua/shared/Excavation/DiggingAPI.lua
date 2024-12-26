local IsoObjectUtils = require("Starlit/IsoObjectUtils")

local DiggingAPI = {}

DiggingAPI.WALL_NORTH = "walls_underground_dirt_0"
DiggingAPI.WALL_WEST = "walls_underground_dirt_1"
DiggingAPI.WALL_CORNER_NORTHWEST = "walls_underground_dirt_2"
DiggingAPI.WALL_CORNER_SOUTHEAST = "walls_underground_dirt_3"
DiggingAPI.FLOOR = "blends_natural_01_64"

---@param x integer
---@param y integer
---@param z integer
local addCornerIfNeeded = function(x, y, z)
    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)
    if not square:getWall() then
        local obj = IsoObject.getNew(square, DiggingAPI.WALL_CORNER_SOUTHEAST, "", false)
        square:transmitAddObjectToSquare(obj, -1)
    end
end

---@param square IsoGridSquare
local removeCorner = function(square)
    local corner = square:getWallSE()
    if not corner then return end
    if corner:getSprite():getName() == DiggingAPI.WALL_CORNER_SOUTHEAST then
        square:transmitRemoveItemFromSquare(corner)
    end
end

---@param square IsoGridSquare
---@param side "north"|"west"
local addWall = function(square, side)
    local sprite
    local existingWall = square:getWall(side ~= "north")
    if existingWall then
        local existingWallTexture = existingWall:getSprite():getName()
        if existingWallTexture == (side == "north" and DiggingAPI.WALL_WEST or DiggingAPI.WALL_NORTH) then
            square:transmitRemoveItemFromSquare(existingWall)
            sprite = DiggingAPI.WALL_CORNER_NORTHWEST
        end
    end
    if not sprite then
        sprite = side == "north" and DiggingAPI.WALL_NORTH or DiggingAPI.WALL_WEST
    end
    local obj = IsoObject.getNew(square, sprite, "", false)
    square:transmitAddObjectToSquare(obj, -1)
end

local objectSpriteBlacklist = {
    ["underground_01_0"] = true,
    ["underground_01_1"] = true
}

local removeBlacklistedObjects = function(square)
    local objects = square:getLuaTileObjectList() --[=[@as IsoObject[]]=]
    for i = 1, #objects do
        local object = objects[i]
        if objectSpriteBlacklist[object:getSprite():getName()] then
            square:transmitRemoveItemFromSquare(object)
            break
        end
    end
end

---@param x integer
---@param y integer
---@param z integer
DiggingAPI.digSquare = function(x, y, z)
    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)

    removeBlacklistedObjects(square)

    if not square:getFloor() then
        -- addFloor triggers some weird vanilla underground block stuff lol
        local obj = IsoObject.getNew(square, DiggingAPI.FLOOR, "", false)
        square:transmitAddObjectToSquare(obj, -1)
    end

    -- TODO: patch ISDestroyStuff to leave a dirt wall when underground, require dirt walls to dig, only remove dirt walls automatically
    -- TODO: allow building new walls on top of dirt walls

    local southOrEastWallAdded = false

    local southEastSquare = IsoObjectUtils.getOrCreateSquare(x + 1, y + 1, z)

    -- south
    local southSquare = IsoObjectUtils.getOrCreateSquare(x, y + 1, z)
    if southSquare:getFloor() then
        IsoObjectUtils.removeWall(southSquare, "north")
        removeCorner(southEastSquare)
    else
        addWall(southSquare, "north")
        southOrEastWallAdded = true
        removeCorner(southSquare)
    end
    removeBlacklistedObjects(southSquare)

    -- east
    local eastSquare = IsoObjectUtils.getOrCreateSquare(x + 1, y, z)
    if eastSquare:getFloor() then
        IsoObjectUtils.removeWall(eastSquare, "west")
        removeCorner(southEastSquare)
    else
        addWall(eastSquare, "west")
        southOrEastWallAdded = true
        removeCorner(eastSquare)
    end
    removeBlacklistedObjects(eastSquare)

    if southOrEastWallAdded then
        addCornerIfNeeded(x + 1, y + 1, z)
    end

    local northOrWestWallAdded = false

    -- north
    local northSquare = IsoObjectUtils.getOrCreateSquare(x, y - 1, z)
    if not northSquare:getFloor() then
        addWall(square, "north")
        addCornerIfNeeded(x + 1, y, z)
        northOrWestWallAdded = true
    else
        IsoObjectUtils.removeWall(square, "north")
        removeCorner(eastSquare)
    end
    removeBlacklistedObjects(northSquare)

    -- west
    local westSquare = IsoObjectUtils.getOrCreateSquare(x - 1, y, z)
    if not westSquare:getFloor() then
        addWall(square, "west")
        addCornerIfNeeded(x, y + 1, z)
        northOrWestWallAdded = true
    else
        IsoObjectUtils.removeWall(square, "west")
        removeCorner(southSquare)
    end
    removeBlacklistedObjects(westSquare)

    if northOrWestWallAdded then
        removeCorner(square)
    end

    -- FIXME: dug out squares are not considered within IsoRegions or IsoRooms so they aren't considered indoors
    -- this means they are not protected from rain and they reduce boredom
    -- seems like no regions below zero is a hard engine limitation

    buildUtil.setHaveConstruction(square, true)

    -- ExcavationMetaGrid.addSquare(square)

    -- not sure exactly what these do, but adding them fixed a bunch of lighting/visibility bugs
    IsoRegions.squareChanged(square)
    square:RecalcProperties()
    square:RecalcAllWithNeighbours(true)
end

return DiggingAPI