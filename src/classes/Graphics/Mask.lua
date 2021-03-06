
local function shapeMode( self, mask, func )
    local selfX, selfY, selfWidth, selfHeight, selfPixels = self.x, self.y, self.width, self.height, self.pixels
    local maskX, maskY, maskWidth, maskHeight, maskPixels = mask.x, mask.y, mask.width, mask.height, mask.pixels
    local x, y = math.min( selfX, maskX ), math.min( selfY, maskY )
    local width, height = math.max( selfX + selfWidth, maskX + maskWidth ) - x, math.max( selfY + selfHeight, maskY + maskHeight ) - y
    local pixels = {}
    for _x = 1, width do
        for _y = 1, height do
            local _selfX, _selfY = x - selfX + _x, y - selfY + _y
            local selfPixel = nil
            if _selfX >= 1 and _selfY >= 1 and _selfX <= selfWidth and _selfY <= selfHeight then
                selfPixel = selfPixels[(_selfY - 1) * selfWidth + _selfX]
            end
            local _maskX, _maskY = x - maskX + _x, y - maskY + _y
            local maskPixel = nil
            if _maskX >= 1 and _maskY >= 1 and _maskX <= maskWidth and _maskY <= maskHeight then
                maskPixel = maskPixels[(_maskY - 1) * maskWidth + _maskX]
            end
            pixels[(_y - 1) * width + _x] = func( selfPixel, maskPixel )
        end
    end
    return Mask( x, y, width, height, pixels )
end

class "Mask" {
    
    x = Number;
    y = Number;
    width = Number;
    height = Number;

    pixels = Table;

}

function Mask:initialise( Number x, Number y, Number width, Number height, Table( {} ) pixels )
    self.x = x
    self.y = y
    self.width = width
    self.height = height
    self.pixels = pixels    
end

--[[
    @desc Subtract (remove 'true' pixels) the given Mask from self (doesn't change self, returns a new mask)
    @return Mask subtractedMask
]]
function Mask:subtract( Mask mask )
    return shapeMode( self, mask, function( selfPixel, maskPixel ) return selfPixel and not maskPixel end )
end

--[[
    @desc Intersect (remove 'true' pixels) the given Mask with self (doesn't change self, returns a new mask)
    @return Mask intersectedMask
]]
function Mask:intersect( Mask mask )
    return shapeMode( self, mask, function( selfPixel, maskPixel ) return selfPixel and maskPixel end )
end

--[[
    @desc Exclude (remove 'true' pixels) the given Mask from self (doesn't change self, returns a new mask)
    @return Mask excludedMask
]]
function Mask:exclude( Mask mask )
    return shapeMode( self, mask, function( selfPixel, maskPixel ) return ( not selfPixel and maskPixel ) or ( selfPixel and not maskPixel ) end ) -- can't use ~= as it might be nil
end

--[[
    @desc Merge (remove 'true' pixels) the given Mask with self (doesn't change self, returns a new mask)
    @return Mask mergedMask
]]
function Mask:add( Mask mask )
    return shapeMode( self, mask, function( selfPixel, maskPixel ) return selfPixel or maskPixel end )
end
