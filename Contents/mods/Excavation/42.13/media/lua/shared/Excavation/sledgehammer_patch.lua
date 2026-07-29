-- This patch replaces sledgehammered walls underground with dirt/stone
-- The ability to sledgehammer underground walls in the first place is implemented in server/Excavation/destroycursor_patch

local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")


local old_complete = ISDestroyStuffAction.complete
function ISDestroyStuffAction:complete()
    local originalReturnValue = old_complete(self)

    local square = self.item:getSquare()
    local z = square:getZ()
    if z >= 0 then
        return originalReturnValue
    end

    local hasFloor = square:hasFloor()
    local material = z > DiggingAPI.STONE_LEVEL and DiggingAPI.DIRT or DiggingAPI.STONE
    local sprite
    if self.item:hasProperty(IsoFlagType.WallN) then
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
                    IsoObject.getNew(
                        square,
                        material.wallCornerSoutheast,
                        nil,
                        false
                    ),
                    -1
                )
            end
        end
    elseif self.item:hasProperty(IsoFlagType.WallW) then
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
                    IsoObject.getNew(
                        square,
                        material.wallCornerSoutheast,
                        nil,
                        false
                    ),
                    -1
                )
            end
        end
    elseif self.item:hasProperty(IsoFlagType.WallSE) then
        if not hasFloor or not square:getAdjacentSquare(IsoDirections.NW):hasFloor() then
            sprite = material.wallCornerSoutheast
        end
    elseif self.item:hasProperty(IsoFlagType.WallNW) then
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
            IsoObject.getNew(
                square,
                sprite,
                nil,
                false
            ),
            -1
        )
    end

    return originalReturnValue
end
