local BaseDigAction = require("Excavation/timedActions/BaseDigAction")
local DiggingAPI = require("Excavation/DiggingAPI")
local IsoObjectUtils = require("Starlit/IsoObjectUtils")
local TimedActionUtils = require("Starlit/timedActions/TimedActionUtils")
local Eval = require("Excavation/Eval")


---@class DigStairsAction : BaseDigAction
---@field square IsoGridSquare
---@field orientation "south"|"east"
local DigStairsAction = BaseDigAction:derive("ExcavationDigStairsAction")
DigStairsAction.__index = DigStairsAction


DigStairsAction.SACKS_NEEDED = 6
DigStairsAction.STONE_REWARD = 6


---@type BodyPartType[]
local STRAIN_BODY_PARTS = {
    BodyPartType.Hand_R,
    BodyPartType.ForeArm_R,
    BodyPartType.UpperArm_R,
    BodyPartType.Hand_L,
    BodyPartType.ForeArm_L,
    BodyPartType.UpperArm_L,
    BodyPartType.Torso_Upper,
    BodyPartType.Torso_Lower
}


function DigStairsAction:complete()
    local x, y, z = self.square:getX(), self.square:getY(), self.square:getZ()
    if self.orientation == "south" then
        -- TODO: this creates and then destroys internal walls
        -- to optimise this DiggingAPI needs a way to open an area of squares and calculate the necessary walls once
        for i = 1, 3 do
            -- remove the floor above the stairs
            DiggingAPI.digFloor(getSquare(x, y + i, z))

            -- clear the square below
            local belowSquare = IsoObjectUtils.getOrCreateSquare(x, y + i, z - 1)
            DiggingAPI.digSquare(x, y + i, z - 1)

            -- add the stair object
            -- TODO: these sprites don't quite reach the next level - looks good enough imo but should be fixed
            local obj = IsoObject.getNew(
                belowSquare,
                "fixtures_excavation_01_" .. tostring(6 - i),
                "",
                false
            )
            belowSquare:transmitAddObjectToSquare(obj, -1)
        end

        local endSquare = IsoObjectUtils.getOrCreateSquare(x, y + 4, z - 1)
        if not endSquare:hasFloor() then
            DiggingAPI.digSquare(x, y + 4, z - 1)
        end
    else
        for i = 1, 3 do
            DiggingAPI.digFloor(getSquare(x + i, y, z))

            local belowSquare = IsoObjectUtils.getOrCreateSquare(x + i, y, z - 1)
            DiggingAPI.digSquare(x + i, y, z - 1)

            local obj = IsoObject.getNew(
                belowSquare,
                "fixtures_excavation_01_" .. tostring(3 - i),
                "",
                false
            )
            belowSquare:transmitAddObjectToSquare(obj, -1)
        end

        local endSquare = IsoObjectUtils.getOrCreateSquare(x + 4, y, z - 1)
        if not endSquare:getFloor() then
            DiggingAPI.digSquare(x + 4, y, z - 1)
        end
    end

    local inverseStrengthLevel = 10 - self.character:getPerkLevel(Perks.Strength)

    self.character:addArmMuscleStrain(3 + 4 * inverseStrengthLevel / 10)
    self.character:addBackMuscleStrain(2 + 2 * inverseStrengthLevel / 10)

    local bodyDamage = self.character:getBodyDamage()
    for i = 1, #STRAIN_BODY_PARTS do
        syncBodyPart(
            bodyDamage:getBodyPart(STRAIN_BODY_PARTS[i]),
            BodyPartSyncPacket.BD_stiffness
        )
    end

    local stats = self.character:getStats()
    stats:remove(CharacterStat.ENDURANCE, 0.4 + inverseStrengthLevel / 80)
    sendPlayerStat(self.character, SyncPlayerStatsPacket.Stat_Endurance)

    -- FIXME: even numbered floors flicker until their chunk has gone offscreen
    -- this is probably related to every 2 floors sharing a texture
    -- calling FBORenderLevels#clearCache() fixes it but not exposed, maybe tis will make it accessible

    return BaseDigAction.complete(self)
end


function DigStairsAction:waitToStart()
    self.character:faceDirection(self.orientation == "south" and IsoDirections.S or IsoDirections.E)
    return self.character:shouldBeTurning()
end


-- TODO: isValid that checks the area below hasn't been dug into and area hasn't been obstructed

---@param orientation "south"|"east"|nil
function DigStairsAction.canBePerformed(character, material, square, orientation)
    if square then
        ---@cast orientation -nil
        local z = square:getZ()

        if not square:hasFloor() or not DiggingAPI.isSquareClear(square, nil, character) then
            return false
        end

        local x, y = square:getX(), square:getY()
        local endSquare
        if orientation == "south" then
            for i = 1, 3 do
                local square = getSquare(x, y + i, z)
                if not DiggingAPI.canDigDownFrom(square)
                        or not DiggingAPI.isSquareClear(square, orientation, character) then
                    return false
                end
            end

            endSquare = getSquare(x, y + 4, z - 1)
        else
            for i = 1, 3 do
                local square = getSquare(x + i, y, z)
                if not DiggingAPI.canDigDownFrom(square)
                        or not DiggingAPI.isSquareClear(square, orientation, character) then
                    return false
                end
            end

            endSquare = getSquare(x + 4, y, z - 1)
        end

        -- it's fine if the end square isn't in playable area, but if it is must have a floor and be accessible
        if endSquare and (IsoObjectUtils.isInPlayableArea(endSquare)
                and not endSquare:hasFloor() or endSquare:has("BlocksPlacement")) then
            return false
        end
    end

    local inventory = character:getInventory()
    if inventory:getCountEvalRecurse(Eval.canCarryDirt) < DigStairsAction.SACKS_NEEDED then
        return false, "Tooltip_Excavation_NeedDirtSack", DigStairsAction.SACKS_NEEDED
    end

    return BaseDigAction.canBePerformed(character, material, square)
end

---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@return boolean success
function DigStairsAction.queueNew(character, square, orientation)
    ISTimedActionQueue.add(
        ISWalkToTimedAction:new(character, square)
    )

    local material = square:getZ() <= DiggingAPI.STONE_LEVEL and "stone" or "dirt"
    if material == "stone" then
        if not TimedActionUtils.transferAndEquipFirstEval(character, Eval.canDigStone) then
            return false
        end
    else
        if not character:getInventory():getSomeEvalRecurse(
                Eval.canCarryDirt,
                DigStairsAction.SACKS_NEEDED
                ) then
            return false
        end

        TimedActionUtils.transferSomeValid(
            character,
            nil,
            Eval.canCarryDirt,
            nil,
            DigStairsAction.SACKS_NEEDED
        )

        if not TimedActionUtils.transferAndEquipFirstEval(character, Eval.canDigDirt) then
            return false
        end
    end

    ISTimedActionQueue.add(
        DigStairsAction:new(character, square, orientation, material)
    )

    return true
end


function DigStairsAction:getDuration()
    if self.character:isTimedActionInstant() then
        return 1
    end

    return 1000
end


---@param character IsoGameCharacter
---@param square IsoGridSquare
---@param orientation "south"|"east"
---@param material "stone"|"dirt"
---@return DigStairsAction
function DigStairsAction:new(character, square, orientation, material)
    local o = BaseDigAction.new(self, character, material) ---@as DigStairsAction

    o.square = square
    o.orientation = orientation
    o.maxTime = o:getDuration()

    return o
end


_G[DigStairsAction.Type] = DigStairsAction


return DigStairsAction