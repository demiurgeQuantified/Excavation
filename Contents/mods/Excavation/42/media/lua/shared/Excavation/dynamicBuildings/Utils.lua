local Utils = {}


---@param x integer
---@param y integer
---@param z integer
---@return string
function Utils.getPosHash(x, y, z)
    return string.format("%d,%d,%d", x, y, z)
end


return Utils