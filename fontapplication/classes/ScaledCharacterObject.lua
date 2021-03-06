
class "ScaledCharacterObject" extends "GraphicsObject" {

    character = false;
    scale = false;
    
}

function ScaledCharacterObject:initialise( x, y, character, scale )
    scale = scale or 1
    self:super( x, y, character and scale * character.width or 1, character and scale * #character or 1 )
    self.character = character
    self.scale = scale
end

function ScaledCharacterObject.character:set( character )
    self.character = character
    self:updateSize()
end

function ScaledCharacterObject.scale:set( scale )
    self.scale = scale
    self:updateSize()
end

function ScaledCharacterObject:updateSize()
    local character, scale = self.character, self.scale

    if character and scale then
        self.width = character.width * scale
        self.height = #character * scale
    end
end

function ScaledCharacterObject.isFilled:set( isFilled, x, y )
    local fill, scale = self.fill, self.scale

    if fill then
        for _x = 0, scale - 1 do
            local fillX = fill[x + _x]
            if not fillX then
                fillX = {}
                fill[x + _x] = fillX
            end
           for _y = 0, scale - 1 do
                fillX[y + _y] = isFilled
            end
        end
    end
    self.hasChanged = true
end

function ScaledCharacterObject.fill:get()
    if self.fill then return self.fill end

    local fill, character = {}, self.character
    if not character then return fill end
    local characterWidth, characterHeight, scale = character.width, #character, self.scale
    for y = 1, characterHeight do
        local characterY = character[y]
        for x = 1, characterWidth do
            local characterFill = characterY[x]
            for _x = 1 + (x - 1) * scale, x * scale do
                local fillX = fill[_x]
                if not fillX then
                    fillX = {}
                    fill[_x] = fillX
                end
               for _y = 1 + (y - 1) * scale, y * scale do
                    fillX[_y] = characterFill
                end
            end
        end
    end
    self.fill = fill
end
