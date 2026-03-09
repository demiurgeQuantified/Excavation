local Eval = require("Excavation/Eval")

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


DiggingAPI.STONE_LEVEL = -2


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


return DiggingAPI