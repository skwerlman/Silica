
class "SymbolButton" extends "Button" {
    
    symbol = false;
    symbolObject = false;

}

function SymbolButton:initialiseCanvas()
    self.super:initialiseCanvas()
    local canvas = self.canvas
    self.textObject.isVisible = false
    local symbolObject = canvas:insert( SymbolObject( 1 + self.leftMargin, 5, self.symbol ) )
    self.theme:connect( symbolObject, "fillColour", "symbolColour" )
    self.symbolObject = symbolObject
end

function SymbolButton:setSymbol( symbol )
    if type( symbol ) == "string" then
        symbol = Symbol.fromName( symbol )
    end
    self.symbol = symbol
    self.symbolObject.symbol = symbol
    self.needsAutosize = true
end

function SymbolButton:autosize()
    local symbol = self.symbol
    if symbol then
        self.width = symbol.width + self.leftMargin + self.rightMargin + 1
        self.height = symbol.height + 9
    end
    self.needsAutosize = false
end

function SymbolButton:setIsPressed( isPressed )
    self.super:setIsPressed( isPressed )
    local symbolObject = self.symbolObject
    symbolObject.x = isPressed and self.leftMargin + 2 or self.leftMargin + 1
    symbolObject.y = isPressed and 6 or 5
end