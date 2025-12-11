local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local Eval = require("Excavation/Eval")

local CLIENT = isClient()

---@module "Excavation/ExcavationMetaGrid"
local ExcavationMetaGrid

-- TODO: functions that require this cannot be called by the client and should be moved into a separate module
if not CLIENT then
    Events.OnInitGlobalModData.Add(function()
        ExcavationMetaGrid = require("Excavation/ExcavationMetaGrid")
    end)
end


---@param t table
---@return boolean
---@nodiscard
local function isEmpty(t)
    for _,_ in pairs(t) do
        return false
    end
    return true
end


-- TODO: it might just be necessary to refresh every time the player changes negative z level lol

---@type table<integer, table<integer, starlit.Set<integer>?>?>
local invalidatedChunkLevels = {}


Events.OnTick.Add(function()
    for i = 0, getNumActivePlayers() - 1 do
        local player = getSpecificPlayer(i)
        if player then
            local z = math.floor(player:getZ())
            if invalidatedChunkLevels[z] then
                local zChunks = invalidatedChunkLevels[z]
                local chunk = player:getChunk()
                local x = chunk.wx ---@as integer
                if zChunks[x] then
                    local y = chunk.wy ---@as integer
                    if zChunks[x][y] then
                        chunk:invalidateRenderChunkLevel(z, FBORenderChunk.DIRTY_OBJECT_ADD)
                        zChunks[x][y] = nil
                        --print(string.format("[Excavation] Refreshed chunk %d,%d,%d", x, y, z))
                        -- cleanup extra memory
                        if isEmpty(zChunks[x]) then
                            zChunks[x] = nil
                            if isEmpty(zChunks) then
                                invalidatedChunkLevels[z] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end)


---@param x integer
---@param y integer
---@param z integer
local function queueChunkRefresh(x, y, z)
    x = (x - x % 8) / 8
    y = (y - y % 8) / 8
    invalidatedChunkLevels[z] = invalidatedChunkLevels[z] or {}
    invalidatedChunkLevels[z][x] = invalidatedChunkLevels[z][x] or {}
    invalidatedChunkLevels[z][x][y] = true
    --print(string.format("[Excavation] Queued chunk refresh %d,%d,%d", x, y, z))
end


local DiggingAPI = {}


---@class DiggingAPI.MaterialDefinition
---@field wallNorth string
---@field wallWest string
---@field wallCornerNorthwest string
---@field wallCornerSoutheast string
---@field floor string


---@type DiggingAPI.MaterialDefinition
DiggingAPI.DIRT = {
    wallNorth = "walls_underground_dirt_0",
    wallWest = "walls_underground_dirt_1",
    wallCornerNorthwest = "walls_underground_dirt_2",
    wallCornerSoutheast = "walls_underground_dirt_3",
    floor = "blends_natural_01_64"
}


-- TODO: these need to be different (even if identical) sprites from vanilla so they can be distinguished
---@type DiggingAPI.MaterialDefinition
DiggingAPI.STONE = {
    wallNorth = "walls_logs_97",
    wallWest = "walls_logs_96",
    wallCornerNorthwest = "walls_logs_98",
    wallCornerSoutheast = "walls_logs_99",
    floor = "floors_exterior_street_01_0"
    -- wallNorth = "walls_underground_dirt_4",
    -- wallWest = "walls_underground_dirt_5",
    -- wallCornerNorthwest = "walls_underground_dirt_6",
    -- wallCornerSoutheast = "walls_underground_dirt_7",
    -- floor = "floors_exterior_natural_01_10"
}


---@type starlit.Set<string>
local DIGGABLE_SPRITES = {}

for _, sprite in pairs(DiggingAPI.DIRT) do
    DIGGABLE_SPRITES[sprite] = true
end

for _, sprite in pairs(DiggingAPI.STONE) do
    DIGGABLE_SPRITES[sprite] = true
end


DiggingAPI.STONE_LEVEL = -2


---@param x integer
---@param y integer
---@param z integer
---@param material DiggingAPI.MaterialDefinition
local function addCornerIfNeeded(x, y, z, material)
    -- FIXME: why is this adding corners when digging behind a wall?
    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)
    if not square:getWall() then
        local obj = IsoObject.getNew(square, material.wallCornerSoutheast, "", false)
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
    local obj = IsoObject.getNew(square, sprite, "", false)
    square:transmitAddObjectToSquare(obj, -1)
    removeCorner(square)
end


---@type starlit.Set<string>
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


---@param character IsoGameCharacter
---@param material "dirt"|"stone"
---@return boolean canDig, string? reason
function DiggingAPI.characterCanDig(character, material)
    if character:getMoodles():getMoodleLevel(MoodleType.ENDURANCE) > 1 then
        return false, "Tooltip_Excavation_TooExhausted"
    end

    local inventory = character:getInventory()

    if material == "stone" then
        if not inventory:containsEvalRecurse(Eval.canDigStone) then
            return false, "Tooltip_Excavation_NeedPickaxeForStone"
        end
    elseif material == "dirt" then
        if not inventory:containsEvalRecurse(Eval.canDigDirt) then
            return false, "Tooltip_Excavation_NeedShovelForDirt"
        end
    end

    return true
end


---@param square IsoGridSquare
---@return "dirt"|"stone"|nil
---@nodiscard
function DiggingAPI.getMaterialAt(square)
    return DiggingAPI.getMaterialAtCoords(square:getX(), square:getY(), square:getZ())
end


---@param x integer
---@param y integer
---@param z integer
---@return "dirt"|"stone"|nil
---@nodiscard
function DiggingAPI.getMaterialAtCoords(x, y, z)
    -- eventually this could be rewritten to e.g. return ores in specific locations
    if z >= 0 then
        return nil
    end
    if z >= DiggingAPI.STONE_LEVEL then
        return "dirt"
    else
        return "stone"
    end
end


function DiggingAPI.digFloor(square)
    assert(not CLIENT, "functions that modify terrain cannot be called on the client")
    IsoObjectUtils.removeFloor(square)
    IsoObjectUtils.removeAll(square, IsoFlagType.canBeRemoved)
    ExcavationMetaGrid.onFloorRemoved(square)
end


---@param floor IsoObject
function DiggingAPI.isDiggableFloor(floor)
    local spriteName = floor:getSprite():getName()
    if spriteName == DiggingAPI.STONE.floor
            or luautils.stringStarts(spriteName, "floors_exterior_natural")
            or luautils.stringStarts(spriteName, "blends_natural_01") then
        return true
    end
    return false
end


---@param square IsoGridSquare
---@param orientation "south"|"east"|nil
---@param exclude IsoMovingObject?
---@return boolean
---@nodiscard
function DiggingAPI.isSquareClear(square, orientation, exclude)
    -- FIXME: even grass has this lol
    if square:has("BlocksPlacement") then
        return false
    end

    if orientation then
        local isSouth = orientation == "south"
        local objects = square:getLuaTileObjectList() --[=[@as IsoObject[] ]=]
        for i = 1, #objects do
            local object = objects[i]
            local sprite = object:getSprite()
            -- copied from buildutils U_U
            if (sprite and sprite:getProperties():has(isSouth and IsoFlagType.collideN or IsoFlagType.collideW))
                    or (instanceof(object, "BarricadeAble") and object--[[@as BarricadeAble]]:getNorth() == isSouth
                        and ((not instanceof(object, "IsoThumpable")) or (not object--[[@as IsoThumpable]]:isCorner()) and not object:isFloor())) then
                return false
            end
        end
    end

    local movingObjects = square:getLuaMovingObjectList()
    return #movingObjects == 0 or (#movingObjects == 1 and movingObjects[1] == exclude)
end


---@param square IsoGridSquare
---@return boolean
---@nodiscard
function DiggingAPI.canDigDownFrom(square)
    local z = square:getZ()
    ---@diagnostic disable-next-line: undefined-field
    if z <= -32 or (z <= -1 and not SandboxVars.Excavation.DisableDepthLimit) then
        return false
    end

    -- upper square must be dug out
    local floor = square:getFloor()
    if not floor or not DiggingAPI.isDiggableFloor(floor) then
        return false
    end

    local lowerSquare = getSquare(square:getX(), square:getY(), z - 1)
    -- it's ok if lower square doesn't exist yet, but if it does it must not already be dug out
    if lowerSquare and lowerSquare:hasFloor() then
        return false
    end

    return true
end


---@param square IsoGridSquare
---@return boolean, string?
function DiggingAPI.canDig(square)
    local x, y, z = square:getX(), square:getY(), square:getZ()
    local aboveSquare = getSquare(x, y, z + 1)
    if aboveSquare and aboveSquare:isWaterSquare() then
        return false, "Tooltip_Excavation_WaterTile"
    end
    return true
end


---@param x integer
---@param y integer
---@param z integer
function DiggingAPI.digSquare(x, y, z)
    assert(not CLIENT, "functions that modify terrain cannot be called on the client")

    local square = IsoObjectUtils.getOrCreateSquare(x, y, z)

    -- TODO: digging east doesn't create an SE corner

    removeBlacklistedObjects(square)

    local floorMaterial = z <= DiggingAPI.STONE_LEVEL and DiggingAPI.STONE or DiggingAPI.DIRT

    if not square:getFloor() then
        -- addFloor triggers some weird vanilla underground block stuff lol
        local obj = IsoObject.getNew(square, floorMaterial.floor, "", false)
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
        local obj = IsoObject.getNew(square, wallMaterial.wallCornerSoutheast, "", false)
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

    queueChunkRefresh(x, y, z)
end


return DiggingAPI