
local SHADOW_RATIO = 2 / 3
local SHADOW_COLOUR = Graphics.colours.GREY

class "Canvas" {
    
    width = Number;
    height = Number;
    owner = View.allowsNil;
    mask = Mask.allowsNil; -- the canvas' rectangle
    contentMask = Mask.allowsNil; -- the canvas' content

    pixels = Table( {} );

    shadows = Enum( Number, {
        SHADOW_RATIO = SHADOW_RATIO;
        SHADOW_COLOUR = SHADOW_COLOUR;
    } )

}

function Canvas:initialise( Number width, Number height, View.allowsNil owner )
    self.width = width
    self.height = height
    self.owner = owner
end

--[[
    @desc Creates a mask which covers the entire canvas
]]
function Canvas.mask:get()
    return RectangleMask( 1, 1, self.width, self.height )
end

--[[
    @desc Creates a mask which covers the filled pixels of the canvas
]]
function Canvas.contentMask:get()
    local pixels = {}
    local TRANSPARENT = Graphics.colours.TRANSPARENT
    for k, v in pairs( self.pixels ) do
        if v ~= TRANSPARENT then
            pixels[k] = true
        end
    end
    return Mask( 1, 1, self.width, self.height, pixels )
end

--[[
    @desc Clears all pixels from the canvas
]]
function Canvas:clear()
    self.pixels = {}
end

--[[
    @desc Hit test the current contents of the canvas
    @return Boolean didHit
]]
function Canvas:hitTest( Number x, Number y )
    local colour = self.pixels[ ( y - 1 ) * self.width + x ]
    return colour and colour ~= Graphics.colours.TRANSPARENT
end

--[[
    @desc Fills an area in the given mask with the given colour, defaulting to the entire canvas
]]
function Canvas:fill( Graphics.colours colour, Mask( self.mask ) mask )
    if colour == Graphics.colours.TRANSPARENT then return end
    local pixels, width, height = self.pixels, self.width, self.height
    local maskX, maskY, maskWidth, maskHeight = mask.x, mask.y, mask.width, mask.height
    for index, isFilled in pairs( mask.pixels ) do
        if isFilled then
            local x = (index - 1) % maskWidth + maskX
            local y = math.floor( ( index - 1) / maskWidth ) + maskY
            if x >= 1 and x <= width and y >= 1 and y <= height then
                pixels[( y - 1 ) * width + x] = colour
            end
        end
    end
end

--[[
    @desc Draws an outline around the given mask, defaulting to the canvas' content mask
]]
function Canvas:outline( Graphics.colours colour, Mask( self.contentMask ) mask, Number( 1 ) leftThickness, Number( leftThickness ) topThickness, Number( leftThickness ) rightThickness, Number( topThickness ) bottomThickness )
    if colour == Graphics.colours.TRANSPARENT then return end
    local width, height, pixels = self.width, self.height, self.pixels
    local maskX, maskY, maskWidth, maskHeight, maskPixels = mask and mask.x, mask and mask.y, mask and mask.width, mask and mask.height, mask and mask.pixels
    local function xScanline( min, max, inc, thickness )
        for y = 1, height do
            local distance = 0
            for x = min, max, inc do
                local mx = x - maskX + 1
                local my = y - maskY + 1
                if mx >= 1 and mx <= maskWidth and my >= 1 and my <= maskHeight and maskPixels[ (my - 1) * maskWidth + mx ] then
                    if distance < thickness then
                        distance = distance + 1
                        pixels[(y - 1) * width + x] = colour
                        if distance >= thickness then
                            break
                        end
                    end
                end
            end
        end
    end

    local function yScanline( min, max, inc, thickness )
        for x = 1, width do
            local distance = 0
            for y = min, max, inc do
                local mx = x - maskX + 1
                local my = y - maskY + 1
                if mx >= 1 and mx <= maskWidth and my >= 1 and my <= maskHeight and maskPixels[ (my - 1) * maskWidth + mx ] then
                    if distance < thickness then
                        distance = distance + 1
                        pixels[(y - 1) * width + x] = colour
                        if distance >= thickness then
                            break
                        end
                    end
                end
            end
        end
    end

    xScanline( 1, width, 1, leftThickness )
    xScanline( width, 1, -1, rightThickness )
    yScanline( 1, height, 1, topThickness )
    yScanline( height, 1, -1, bottomThickness )

    return pixels
end

--[[
    @desc Draws the canvas to another canvas. If mask is provided the canvas content will be masked (mask pixels will be drawn, pixels not in the mask won't). Mask cordinates are relative to self, not the destination
]]
function Canvas:drawTo( Canvas destinationCanvas, Number x, Number y, Mask.allowsNil mask )
    local width, height = self.width, self.height
    local destinationWidth, destinationHeight, destinationPixels = destinationCanvas.width, destinationCanvas.height, destinationCanvas.pixels
    local TRANSPARENT = Graphics.colours.TRANSPARENT
    local maskX, maskY, maskWidth, maskHeight, maskPixels = mask and mask.x, mask and mask.y, mask and mask.width, mask and mask.height, mask and mask.pixels
    for index, colour in pairs( self.pixels ) do
        if colour and colour ~= TRANSPARENT then
            local _x = (index - 1) % width + x
            local _y = math.floor( ( index - 1) / width ) + y
            if _x >= 1 and _x <= destinationWidth and _y >= 1 and _y <= destinationHeight then
                local isOkay = true
                if mask then
                    local mx = _x - maskX + 1
                    local my = _y - maskY + 1
                    if mx >= 1 and mx <= maskWidth and my >= 1 and my <= maskHeight then
                        isOkay = maskPixels[ (my - 1) * maskWidth + mx ]
                    else
                        isOkay = false
                    end
                end
                if isOkay then
                    destinationPixels[( _y - 1 ) * destinationWidth + _x] = colour
                end
            end
        end
    end
end

--[[
    @desc Creates an image from the Canvas' pixels
]]
function Canvas:toImage()
    return Image.static:fromPixels( self.pixels, self.width, self.height )
end

--[[
    @desc Draws an image to the canvas, scaling the image if needed
]]
function Canvas:image( Image image, Number x, Number y, Number( image.width ) width, Number( image.height ) height )
    local pixels = image:getScaledPixels( width, height )
    local selfWidth, selfHeight, selfPixels = self.width, self.height, self.pixels
    local TRANSPARENT = Graphics.colours.TRANSPARENT
    local xLimit, yLimit = math.min( selfWidth, width + x - 1 ), math.min( selfHeight, height + y - 1 )
    for _y = y, yLimit do
        for _x = x, xLimit do
            local pixel = pixels[(_y - y) * width + (_x - x + 1)]
            if pixel and pixel ~= TRANSPARENT then
                selfPixels[(_y - 1) * selfWidth + _x] = pixel
            end
        end
    end
end

--[[
    @desc Draws a shadow mask to the parent's canvas
]]
function Canvas:drawShadow( Graphics.colours( SHADOW_COLOUR ) shadowColour, Number x, Number y, Number shadowSize, Mask( self.contentMask ) shadowMask )
    if shadowSize == 0 or shadowColour == Graphics.colours.TRANSPARENT then return end
    x = math.floor( x + shadowSize * SHADOW_RATIO + 0.5 )
    y = y + shadowSize
    local pixels, width, height = self.pixels, self.width, self.height
    local maskX, maskY, maskWidth, maskHeight = shadowMask.x, shadowMask.y, shadowMask.width, shadowMask.height
    for index, isFilled in pairs( shadowMask.pixels ) do
        if isFilled then
            local x = (index - 1) % maskWidth + maskX + x - 1
            local y = math.floor( ( index - 1) / maskWidth ) + maskY + y - 1
            if x >= 1 and x <= width and y >= 1 and y <= height then
                pixels[( y - 1 ) * width + x] = shadowColour
            end
        end
    end
end
