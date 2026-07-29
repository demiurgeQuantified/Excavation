-- This patch prevents sledgehammering dirt/stone tiles, and allows sledgehammering underground walls
-- The addition of dirt/stone tiles when sledgehammering walls is implemented in shared/Excavation/destroycursor_patch

local DiggingAPI = require("Excavation/DiggingAPI")


---@type table<string, true | nil>
local DIGGABLE_SPRITES = {}

for _, sprite in pairs(DiggingAPI.DIRT) do
    DIGGABLE_SPRITES[sprite] = true
end

for _, sprite in pairs(DiggingAPI.STONE) do
    DIGGABLE_SPRITES[sprite] = true
end


local function alwaysFalse()
	return false
end


-- don't allow sledgehammering dirt/stone tiles
local old_canDestroy = ISDestroyCursor.canDestroy
---@param object IsoObject
function ISDestroyCursor:canDestroy(object)
	local spriteName = object:getSprite():getName()
	if spriteName and DIGGABLE_SPRITES[spriteName] then
		return false
	end

	return old_canDestroy(self, object)
end


local old_isBasementWallAdjacentToTheVoid = ISDestroyCursor.isBasementWallAdjacentToTheVoid
function ISDestroyCursor:isBasementWallAdjacentToTheVoid(...)
	local old_north = IsoCell.isBasementWallAdjacentToTheVoid_North
	local old_west = IsoCell.isBasementWallAdjacentToTheVoid_West
	IsoCell.isBasementWallAdjacentToTheVoid_North = alwaysFalse
	IsoCell.isBasementWallAdjacentToTheVoid_West = alwaysFalse
	
	local result = old_isBasementWallAdjacentToTheVoid(self, ...)
	
	IsoCell.isBasementWallAdjacentToTheVoid_North = old_north
	IsoCell.isBasementWallAdjacentToTheVoid_West = old_west
	
	return result
end


local old_canDestroyNorth = ISDestroyCursor.canDestroyWall_North
function ISDestroyCursor:canDestroyWall_North(...)
	local old = IsoCell.isBasementWallAdjacentToTheVoid_North
	IsoCell.isBasementWallAdjacentToTheVoid_North = alwaysFalse
	
	local result = old_canDestroyNorth(self, ...)
	
	IsoCell.isBasementWallAdjacentToTheVoid_North = old
	
	return result
end


local old_canDestroyNorth = ISDestroyCursor.canDestroyWall_West
function ISDestroyCursor:canDestroyWall_West(...)
	local old = IsoCell.isBasementWallAdjacentToTheVoid_West
	IsoCell.isBasementWallAdjacentToTheVoid_West = alwaysFalse
	
	local result = old_canDestroyNorth(self, ...)
	
	IsoCell.isBasementWallAdjacentToTheVoid_West = old
	
	return result
end
