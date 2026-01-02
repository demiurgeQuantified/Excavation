local BaseDigAction = require("Excavation/timedActions/BaseDigAction")
local TimedActionUtils = require("Starlit/timedActions/TimedActionUtils")
local Eval = require("Excavation/Eval")
local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local modules = require("Starlit/modules")

---@module "Excavation/Mining"
local Mining = modules.delayedRequire("Excavation/Mining")


---@type table<string, true | nil>
local DIGGABLE_SPRITES = {}

for _, sprite in pairs(DiggingAPI.DIRT) do
    DIGGABLE_SPRITES[sprite] = true
end

for _, sprite in pairs(DiggingAPI.STONE) do
    DIGGABLE_SPRITES[sprite] = true
end


---@param square IsoGridSquare
---@return boolean
local isStandableSquare = function(square)
    if not square:hasFloor() or square:HasStairs() then
        return false
    end
    return true
end


---@param x integer
---@param y integer
---@param z integer
---@param character IsoGameCharacter
---@return IsoGridSquare?
local getClosestAdjacentSquare = function(x, y, z, character)
    local squares = table.newarray() --[=[@as IsoGridSquare[] ]=]
    local square = getSquare(x, y, z)

    local neighbour = square:getAdjacentSquare(IsoDirections.N)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(square, "north")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            table.insert(squares, neighbour)
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.W)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(square, "west")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            table.insert(squares, neighbour)
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.S)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(neighbour, "north")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            table.insert(squares, neighbour)
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.E)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(neighbour, "west")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            table.insert(squares, neighbour)
        end
    end

    if #squares <= 1 then
        return squares[1]
    end

    local closest
    local closestDist = 1000000.0
    for i = 1, #squares do
        local square = squares[i]
        local dist = square:DistToProper(character)
        if dist < closestDist then
            closestDist = dist
            closest = square
        end
    end
    return closest
end


---Returns the first standable square next to square with a diggable material between them
---@param square IsoGridSquare
---@return IsoGridSquare?
local getValidAdjacentSquare = function(square)
    local neighbour = square:getAdjacentSquare(IsoDirections.N)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(square, "north")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            return neighbour
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.W)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(square, "west")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            return neighbour
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.S)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(neighbour, "north")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            return neighbour
        end
    end

    neighbour = square:getAdjacentSquare(IsoDirections.E)
    if neighbour and isStandableSquare(neighbour) then
        local wall = IsoObjectUtils.getWall(neighbour, "west")
        if wall and DIGGABLE_SPRITES[wall:getSprite():getName()] then
            return neighbour
        end
    end
end


---@class DigSquareAction : BaseDigAction
---@field x integer
---@field y integer
---@field z integer
local DigSquareAction = BaseDigAction:derive("ExcavationDigSquareAction")
DigSquareAction.__index = DigSquareAction

DigSquareAction.SACKS_NEEDED = 3
DigSquareAction.STONE_REWARD = 3

-- TODO: isValid that checks the square hasn't already been dug into


---@type BodyPartType[]
local STRAIN_BODY_PARTS = {
    BodyPartType.Hand_R,
    BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_R,
    BodyPartType.Hand_L,
    BodyPartType.ForeArm_L,
    BodyPartType.UpperArm_L
}


function DigSquareAction.canBePerformed(character, material, square)
    if square then
        local canDig, reason = DiggingAPI.canDig(square)
        if not canDig then
            return false, reason
        end
        if not getValidAdjacentSquare(square) then
            return false, "Tooltip_Excavation_NoPath"
        end
    end

    if material == "dirt" then
        local inventory = character:getInventory()
        if inventory:getCountEvalRecurse(Eval.canCarryDirt) < DigSquareAction.SACKS_NEEDED then
            return false, "Tooltip_Excavation_NeedDirtSack", DigSquareAction.SACKS_NEEDED
        end
    end

    return BaseDigAction.canBePerformed(character, material, square)
end


function DigSquareAction:complete()
    Mining.mineSquare(self.x, self.y, self.z)

    local inverseStrengthLevel = 10 - self.character:getPerkLevel(Perks.Strength)

    self.character:addBothArmMuscleStrain(2 + 3 * inverseStrengthLevel / 10)
    local bodyDamage = self.character:getBodyDamage()
    for i = 1, #STRAIN_BODY_PARTS do
        syncBodyPart(
            bodyDamage:getBodyPart(STRAIN_BODY_PARTS[i]),
            BodyPartSyncPacket.BD_stiffness
        )
    end

    local stats = self.character:getStats()
    stats:remove(CharacterStat.ENDURANCE, 0.2 + inverseStrengthLevel / 80)
    sendPlayerStat(self.character, CharacterStat.ENDURANCE)

    return BaseDigAction.complete(self)
end


function DigSquareAction:waitToStart()
    self.character:faceLocation(self.x, self.y)
    return self.character:shouldBeTurning()
end


---@param character IsoGameCharacter
---@param x integer
---@param y integer
---@param z integer
---@param material "dirt"|"stone"
---@return boolean success
function DigSquareAction.queueNew(character, x, y, z, material)
    local adjacentSquare = getClosestAdjacentSquare(x, y, z, character)
    if not adjacentSquare then
        return false
    end

    ISTimedActionQueue.add(
        ISWalkToTimedAction:new(character, adjacentSquare)
    )

    if material == "dirt" then
        if not character:getInventory():getSomeEvalRecurse(Eval.canCarryDirt, DigSquareAction.SACKS_NEEDED) then
            return false
        end

        TimedActionUtils.transferSomeValid(
            character,
            nil,
            Eval.canCarryDirt,
            nil,
            DigSquareAction.SACKS_NEEDED
        )

        if not TimedActionUtils.transferAndEquipFirstEval(
                character,
                Eval.canDigDirt,
                "primary"
                ) then
            return false
        end
    else
        if not TimedActionUtils.transferAndEquipFirstEval(
                character,
                Eval.canDigStone,
                "primary"
                ) then
            return false
        end
    end

    ISTimedActionQueue.add(
        DigSquareAction:new(
            character,
            x,
            y,
            z,
            material
        )
    )

    return true
end


function DigSquareAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    return 500
end


---@param character IsoGameCharacter
---@param x integer
---@param y integer
---@param z integer
---@param material "dirt"|"stone"
function DigSquareAction:new(character, x, y, z, material)
    local o = BaseDigAction.new(self, character, material) ---@as DigSquareAction

    o.x = x
    o.y = y
    o.z = z

    o.maxTime = o:getDuration()

    return o
end


_G[DigSquareAction.Type] = DigSquareAction


return DigSquareAction