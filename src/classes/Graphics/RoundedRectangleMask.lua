
-- draws a corner with the given radius for the corner given
local function corner( pixels, width, height, radius, position ) -- position is a byte. first bit is 0 if top, second bit is 0 if left
    if radius <= 0 then return end
    
    local minDistance = radius
    if radius % 2 ~= 0 then -- doing this seems to magically make them look much better
        radius = radius + 0.75
    else
        radius = radius + 0.5
    end

    local centerX = ( bit.band( position, 2 ) == 0 ) and radius or width - radius + 1
    local centerY = ( bit.band( position, 1 ) == 0 ) and radius or height - radius + 1
    local minX = ( bit.band( position, 2 ) == 0 ) and 1 or width - minDistance + 1
    local minY = ( bit.band( position, 1 ) == 0 ) and 1 or height - minDistance + 1

    for x = minX, minX + radius - 1 do
        local xDistance = ( x - centerX ) ^ 2
        for y = minY, minY + radius - 1 do
            local distance = ( xDistance + ( y - centerY) ^ 2 ) ^ 0.5
            if distance <= minDistance then
                pixels[(y - 1) * width + x] = true
            end
        end
    end
end

class "RoundedRectangleMask" extends "Mask" {

    

}

function RoundedRectangleMask:initialise( Number x, Number y, Number width, Number height, Number topLeftRadius, Number( topLeftRadius ) topRightRadius, Number( topLeftRadius ) bottomLeftRadius, Number( topRightRadius ) bottomRightRadius )
    local pixels = {}

    corner( pixels, width, height, topLeftRadius, 0 )
    corner( pixels, width, height, topRightRadius, 2 )
    corner( pixels, width, height, bottomLeftRadius, 1 )
    corner( pixels, width, height, bottomRightRadius, 3 )

    local maxTopRadius = math.max( topLeftRadius, topRightRadius )
    for x = topLeftRadius + 1, width - topRightRadius do
        for y = 1, maxTopRadius do
            pixels[(y - 1) * width + x] = true
        end
    end

    local maxBottomRadius = math.max( bottomLeftRadius, bottomRightRadius )
    for x = bottomLeftRadius + 1, width - bottomRightRadius do
        for y = height - maxBottomRadius + 1, height do
            pixels[(y - 1) * width + x] = true
        end
    end

    for x = 1, width do
        for y = maxTopRadius + 1, height - maxBottomRadius do
            pixels[(y - 1) * width + x] = true
        end
    end

    self:super( x, y, width, height, pixels )
end