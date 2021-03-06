
class "LeftSymbol" extends "Symbol" {

    static = {
        symbolName = String( "left" );
    };

}

function LeftSymbol.static:initialise()
    local path = Path( self.width, self.height, 4, 1 )
    path:lineTo( 4, 3 )
    path:lineTo( 7, 3 )
    path:lineTo( 7, 5 )
    path:lineTo( 4, 5 )
    path:lineTo( 4, 7 )
    path:lineTo( 1, 4 )
    path:close()

    self:super( path )
end
