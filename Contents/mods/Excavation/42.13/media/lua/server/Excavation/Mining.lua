if isClient() then
    return
end

local ExcavationMetaGrid = require("Excavation/ExcavationMetaGrid")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local DiggingAPI = require("Excavation/DiggingAPI")


---@type table<string, true?>
local DIGGABLE_SPRITES = {}

for _, sprite in pairs(DiggingAPI.DIRT) do
    DIGGABLE_SPRITES[sprite] = true
end

for _, sprite in pairs(DiggingAPI.STONE) do
    DIGGABLE_SPRITES[sprite] = true
end



-- TODO: it might just be necessary to refresh every time the player changes negative z level lol

-- ---@type table<integer, table<integer, table<integer, true?>?>?>
-- local invalidatedChunkLevels = {}


-- Events.OnTick.Add(function()
--     for i = 0, getNumActivePlayers() - 1 do
--         local player = getSpecificPlayer(i)
--         if player then
--             local z = math.floor(player:getZ())
--             if invalidatedChunkLevels[z] then
--                 local zChunks = invalidatedChunkLevels[z]
--                 local chunk = player:getChunk()
--                 ---@diagnostic disable-next-line: undefined-field
--                 local x = chunk.wx ---@as integer
--                 if zChunks[x] then
--                     ---@diagnostic disable-next-line: undefined-field
--                     local y = chunk.wy ---@as integer
--                     if zChunks[x][y] then
--                         chunk:invalidateRenderChunkLevel(z, FBORenderChunk.DIRTY_OBJECT_ADD)
--                         zChunks[x][y] = nil
--                         --print(string.format("[Excavation] Refreshed chunk %d,%d,%d", x, y, z))
--                         -- cleanup extra memory
--                         if isEmpty(zChunks[x]) then
--                             zChunks[x] = nil
--                             if isEmpty(zChunks) then
--                                 invalidatedChunkLevels[z] = nil
--                             end
--                         end
--                     end
--                 end
--             end
--         end
--     end
-- end)


-- ---@param x integer
-- ---@param y integer
-- ---@param z integer
-- local function queueChunkRefresh(x, y, z)
--     x = math.floor((x - x % 8) / 8)
--     y = math.floor((y - y % 8) / 8)
--     invalidatedChunkLevels[z] = invalidatedChunkLevels[z] or {}
--     invalidatedChunkLevels[z][x] = invalidatedChunkLevels[z][x] or {}
--     invalidatedChunkLevels[z][x][y] = true
--     --print(string.format("[Excavation] Queued chunk refresh %d,%d,%d", x, y, z))
-- end


---@param x integer
---@param y integer
---@param z integer
---@param material DiggingAPI.MaterialDefinition
local function addCornerIfNeeded(x, y, z, material)
    -- FIXME: why is this adding corners when digging behind a wall?
    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)
    if not square:getWall() then
        local obj = IsoObject.getNew(square, material.wallCornerSoutheast, nil, false)
        square:transmitAddObjectToSquare(obj, -1)
    end
end


---@param square IsoGridSquare
local function removeCorner(square)
    local corner = square:getWallSE()
    if not corner then return end
    local spriteName = corner:getSprite():getName()
    if spriteName == DiggingAPI.DIRT.wallCornerSoutheast
            or spriteName == DiggingAPI.STONE.wallCornerSoutheast then
        square:transmitRemoveItemFromSquare(corner)
    end
end


---@param square IsoGridSquare
---@param side "north"|"west"
local function digWall(square, side)
    -- TODO: optimise this, this searches for the wall twice
    local wall = IsoObjectUtils.getWall(square, side)
    if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
        IsoObjectUtils.removeWall(square, side)
    end
end


---@param square IsoGridSquare
---@param material DiggingAPI.MaterialDefinition
---@param side "north"|"west"
local function addWall(square, material, side)
    if IsoObjectUtils.getWall(square, side) then
        return
    end
    local sprite
    local existingWall = IsoObjectUtils.getWall(square,
                                                            side == "north" and "west" or "north")
    if existingWall then
        local existingWallTexture = existingWall:getSprite():getName()
        if existingWallTexture == (side == "north" and material.wallWest or material.wallNorth) then
            square:transmitRemoveItemFromSquare(existingWall)
            sprite = material.wallCornerNorthwest
        end
    end
    if not sprite then
        sprite = side == "north" and material.wallNorth or material.wallWest
    end
    local obj = IsoObject.getNew(square, sprite, nil, false)
    square:transmitAddObjectToSquare(obj, -1)
    removeCorner(square)
end


---@type table<string, true?>
local objectSpriteBlacklist = {
    ["underground_01_0"] = true,
    ["underground_01_1"] = true
}


local function removeBlacklistedObjects(square)
    local objects = square:getLuaTileObjectList() --[=[@as IsoObject[] ]=]
    for i = #objects, 1, -1 do
        local object = objects[i]
        if objectSpriteBlacklist[object:getSprite():getName()] then
            square:transmitRemoveItemFromSquare(object)
            break
        end
    end
end


---@param square IsoGridSquare
---@return boolean
local function isDugOpen(square)
    return square:hasFloor() or ExcavationMetaGrid.isFloorRemoved(square)
end


local Mining = {}


function Mining.mineFloor(square)
    IsoObjectUtils.removeFloor(square)
    IsoObjectUtils.removeAll(square, IsoFlagType.canBeRemoved)
    ExcavationMetaGrid.onFloorRemoved(square)
end


---@param x integer
---@param y integer
---@param z integer
function Mining.mineSquare(x, y, z)
    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)

    -- TODO: digging east doesn't create an SE corner

    removeBlacklistedObjects(square)

    local floorMaterial = z <= DiggingAPI.STONE_LEVEL and DiggingAPI.STONE or DiggingAPI.DIRT

    if not square:getFloor() then
        -- addFloor triggers some weird vanilla underground block stuff lol
        local obj = IsoObject.getNew(square, floorMaterial.floor, nil, false)
        square:transmitAddObjectToSquare(obj, -1)
    end

    -- TODO: allow building new walls on top of dirt walls

    local wallMaterial = z < DiggingAPI.STONE_LEVEL and DiggingAPI.STONE or DiggingAPI.DIRT

    local southOrEastWallAdded = false
    local southEastSquare = IsoObjectUtils.getOrCreateSquare(x + 1, y + 1, z)

    -- south
    local southSquare = IsoObjectUtils.getOrCreateSquare(x, y + 1, z)
    if isDugOpen(southSquare) then
        digWall(southSquare, "north")
        removeCorner(southEastSquare)
    else
        addWall(southSquare, wallMaterial, "north")
        southOrEastWallAdded = true
    end
    removeBlacklistedObjects(southSquare)

    -- east
    local eastSquare = IsoObjectUtils.getOrCreateSquare(x + 1, y, z)
    if isDugOpen(eastSquare) then
        digWall(eastSquare, "west")
        removeCorner(southEastSquare)
    else
        addWall(eastSquare, wallMaterial, "west")
        southOrEastWallAdded = true
    end
    removeBlacklistedObjects(eastSquare)

    if southOrEastWallAdded then
        addCornerIfNeeded(x + 1, y + 1, z, wallMaterial)
    end

    local needsCornerAdded = true
    local northOrWestWallAdded = false

    -- north
    local northSquare = IsoObjectUtils.getOrCreateSquare(x, y - 1, z)
    if isDugOpen(northSquare) then
        digWall(square, "north")
        removeCorner(eastSquare)
        needsCornerAdded = needsCornerAdded and IsoObjectUtils.getWall(square, "west") ~= nil
    else
        addWall(square, wallMaterial, "north")
        addCornerIfNeeded(x + 1, y, z, wallMaterial)
        northOrWestWallAdded = true
    end
    removeBlacklistedObjects(northSquare)

    -- west
    local westSquare = IsoObjectUtils.getOrCreateSquare(x - 1, y, z)
    if isDugOpen(westSquare) then
        digWall(square, "west")
        removeCorner(southSquare)
        needsCornerAdded = needsCornerAdded and IsoObjectUtils.getWall(square, "north") ~= nil
    else
        addWall(square, wallMaterial, "west")
        addCornerIfNeeded(x, y + 1, z, wallMaterial)
        northOrWestWallAdded = true
    end
    removeBlacklistedObjects(westSquare)

    if needsCornerAdded then
        local obj = IsoObject.getNew(square, wallMaterial.wallCornerSoutheast, nil, false)
        square:transmitAddObjectToSquare(obj, -1)
    end

    if northOrWestWallAdded then
        removeCorner(square)
    end

    -- FIXME: dug out squares are not considered within IsoRegions or IsoRooms so they aren't considered indoors
    -- this means they are not protected from rain and they reduce boredom
    -- seems like no regions below zero is a hard engine limitation

    buildUtil.setHaveConstruction(square, true)

    square:setSquareChanged()

    for xOffset = -1, 1, 2 do
        for yOffset = -1, 1, 2 do
            local cornerSquare = getSquare(x + xOffset, y + yOffset, z)
            ---@diagnostic disable-next-line: unnecessary-if
            if cornerSquare then
                removeBlacklistedObjects(square)
            end
        end
    end

    -- doesn't make sense in MP
    -- queueChunkRefresh(x, y, z)
end


return Mining