local ExcavationMetaGrid = {}

---@class ExcavationMetaSquare
---@field isFloorRemoved true? Whether the floor is removed. Nil is used instead of false to compress save size.

---z,x,y for compression reasons
---@type table<integer, table<integer, table<integer, ExcavationMetaSquare>>>
local metaGrid

---@param square IsoGridSquare
---@return ExcavationMetaSquare?
local getMetaSquare = function(square)
    local zSlice = metaGrid[square:getZ()]
    if not zSlice then
        return nil
    end

    local zxSlice = zSlice[square:getX()]
    if not zxSlice then
        return nil
    end

    return zxSlice[square:getY()]
end

---@param square IsoGridSquare
---@return ExcavationMetaSquare
local getOrCreateMetaSquare = function(square)
    local z = square:getZ()
    metaGrid[z] = metaGrid[z] or {}
    local zSlice = metaGrid[z]

    local x = square:getX()
    zSlice[x] = zSlice[x] or {}
    local zxSlice = zSlice[x]

    local y = square:getY()
    local metaSquare = zxSlice[y]
    if not metaSquare then
        metaSquare = {}
        zxSlice[y] = metaSquare
    end

    return metaSquare
end

---@param square IsoGridSquare
ExcavationMetaGrid.onFloorRemoved = function(square)
    local metaSquare = getOrCreateMetaSquare(square)
    metaSquare.isFloorRemoved = true
end

---@param square IsoGridSquare
---@return boolean
ExcavationMetaGrid.isFloorRemoved = function(square)
    local metaSquare = getMetaSquare(square)
    return metaSquare and metaSquare.isFloorRemoved == true or false
end

Events.OnInitGlobalModData.Add(function()
    metaGrid = ModData.get("ExcavationMetaGrid")
    if not metaGrid then
        metaGrid = ModData.create("ExcavationMetaGrid")
        metaGrid.VERSION = 1
    end
end)

return ExcavationMetaGrid