local Utils = require("Excavation/dynamicBuildings/Utils")
local MetaGrid = require("Excavation/dynamicBuildings/MetaGrid")


---@namespace Excavation.dynamicBuildings


---@param a Position
---@param b Position
---@return boolean
local function compXY(a, b)
    if b.x == a.x then
        return b.y > a.y
    end
    return b.x > a.x
end


---@param squares Position[]
---@return VirtualRoom.Rect[]
local function createRectStrips(squares)
    assert(#squares > 0, "attempted to create rects from zero squares")

    table.sort(squares, compXY)

    ---@type VirtualRoom.Rect[]
    local rects = table.newarray()

    ---@type Position
    local lastSquare = squares[1]---@as[[-nil]]
    ---@type VirtualRoom.Rect
    local currentRect = {
        x = lastSquare.x,
        y = lastSquare.y,
        length = 1,
        width = 1
    }
    table.insert(rects, currentRect)

    for i = 2, #squares do
        local square = squares[i]

        if square.x > lastSquare.x or square.y > lastSquare.y + 1 then
            currentRect = {
                x = square.x,
                y = square.y,
                length = 1,
                width = 1
            }
            table.insert(rects, currentRect)
        else
            currentRect.length = currentRect.length + 1
        end

        lastSquare = square
    end

    return rects
end


---@param strips VirtualRoom.Rect[]
---@return VirtualRoom.Rect[]
local function mergeNeighbouringStrips(strips)
    assert(#strips > 0, "tried to merge zero rects")

    -- sort strips by their x level
    ---@type table<integer, VirtualRoom.Rect[] | nil>
    local rectsByX = {}

    local minX = strips[1].x
    local maxX = strips[1].x
    rectsByX[strips[1].x] = {strips[1]}

    for i = 2, #strips do
        local rect = strips[i]
        if rect.x < minX then
            minX = rect.x
        elseif rect.x > maxX then
            maxX = rect.x
        end

        if not rectsByX[rect.x] then
            rectsByX[rect.x] = {}
        end
        table.insert(rectsByX[rect.x], rect)
    end

    local mergedRects = table.newarray()

    -- check for rects in neighbouring X levels, if y and length match then merge
    for x = minX, maxX - 1 do
        local rects = rectsByX[x] ---@as -nil
        for i = 1, #rects do
            local rect = rects[i]
            local nextRects = rectsByX[x + 1] ---@as -nil
            for j = #nextRects, 1, -1 do
                local nextRect = nextRects[j]
                if rect.y == nextRect.y and rect.length == nextRect.length then
                    -- merge the rects
                    rect.width = rect.width + 1
                    table.remove(nextRects, j)
                    table.insert(nextRects, rect)
                    break
                end
            end

            -- don't insert if this rect was already added when checking a previous x level
            if rect.x == x then
                table.insert(mergedRects, rect)
            end
        end
    end

    -- add maxX rects that were missed by the previous loop
    for i = 1, #rectsByX[maxX] do
        local rect = rectsByX[maxX][i]
        if rect.x == maxX then
            table.insert(mergedRects, rect)
        end
    end

    return mergedRects
end


---@param squares Position[]
---@return VirtualRoom.Rect[]
---@nodiscard
local function createRects(squares)
    local rects = createRectStrips(squares)
    rects = mergeNeighbouringStrips(rects)
    return rects
end


---@class RoomBuilder
---@field seenSquares table<string, boolean>
---@field squareStack Position[]
---@field portals Position[] Squares the room has portals to.
---@field currentSquare Position
local RoomBuilder = {}
RoomBuilder.__index = RoomBuilder


---@param x integer
---@param y integer
---@param z integer
function RoomBuilder:addSquareIfValid(x, y, z)
    local hash = Utils.getPosHash(x, y, z)
    if not self.seenSquares[hash] and MetaGrid.getSquare(x, y, z) then
        local currentSquare = getSquare(self.currentSquare.x, self.currentSquare.y, self.currentSquare.z)
        local square = getSquare(x, y, z)
        if not currentSquare:isWallTo(square) then
            local pos = {x = x, y = y, z = z}
            if currentSquare:isDoorTo(square) or currentSquare:isWindowTo(square) then
                table.insert(self.portals, pos)
            else
                table.insert(self.squareStack, pos)
                self.seenSquares[hash] = true
            end
        end
    end
end


---@param x integer
---@param y integer
---@param z integer
---@return VirtualRoom
---@nodiscard
function RoomBuilder.buildRoomFrom(x, y, z)
    assert(MetaGrid.getSquare(x, y, z) == true, "attempted to create virtual room at non-excavated square")

    ---@type Position[]
    local squares = table.newarray()

    local builder = RoomBuilder.new()
    builder.squareStack[1] = {
        x = x,
        y = y,
        z = z
    }
    builder.seenSquares[Utils.getPosHash(x, y, z)] = true

    while #builder.squareStack > 0 do
        builder.currentSquare = table.remove(builder.squareStack)
        local x = builder.currentSquare.x
        local y = builder.currentSquare.y
        local z = builder.currentSquare.z

        builder:addSquareIfValid(x + 1, y, z)
        builder:addSquareIfValid(x - 1, y, z)
        builder:addSquareIfValid(x, y + 1, z)
        builder:addSquareIfValid(x, y - 1, z)

        table.insert(squares, builder.currentSquare)
    end

    return {
        rects = createRects(squares),
        portals = builder.portals
    }
end


---@return RoomBuilder
function RoomBuilder.new()
    local o = setmetatable(
        {
            seenSquares = {},
            squareStack = table.newarray(),
            portals = table.newarray(),
            currentSquare = nil
        },
        RoomBuilder
    )

    return o
end


return RoomBuilder