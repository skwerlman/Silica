
class "SeparatorMask" extends "Mask" {

    

}

function SeparatorMask:initialise( Number x, Number y, Number width, Number height )
    local pixels = {}
    local i = 1
    for y = 1, height do
        if y % 2 == 1 then
            for x = 1, width do
                pixels[(y - 1) * width + x] = x % 2 == 1
            end
        end
    end

    self:super( x, y, width, height, pixels )
end