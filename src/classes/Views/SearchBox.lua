
class "SearchBox" extends "TextBox" {
    
    placeholder = String( "Search..." ).allowsNil;

}

function SearchBox:initialiseCanvas()
    self:super()

    local symbolObject = SymbolObject( 8, 4, SearchSymbol )
    self.canvas:insert( symbolObject )

    self.theme:connect( symbolObject, "outlineColour", "searchSymbolColour" )
    
    self.symbolObject = symbolObject
end