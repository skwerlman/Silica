
class "DownSymbol" extends "Symbol" {

    static = {
        symbolName = String( "down" );
    };

}

function DownSymbol.static:initialise()
    local path = Path( self.width, self.height, 5, 1 )
    path:lineTo( 5, 1 )
    path:lineTo( 5, 4 )
    path:lineTo( 7, 4 )
    path:lineTo( 4, 7 )
    path:lineTo( 1, 4 )
    path:lineTo( 3, 4 )
    path:lineTo( 3, 1 )
    path:close()

    self:super( path )
end

