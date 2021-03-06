
class "HomeSymbol" extends "Symbol" {

    static = {
        symbolName = String( "home" );
        width = Number( 9 );
        height = Number( 9 );
    };

}

function HomeSymbol.static:initialise()
    local path = Path( self.width, self.height, 5, 1 )
    path:lineTo( 9, 5 )
    path:lineTo( 8, 5 )
    path:lineTo( 8, 9 )
    path:lineTo( 6, 9 )
    path:lineTo( 6, 6 )
    path:lineTo( 4, 6 )
    path:lineTo( 4, 9 )
    path:lineTo( 2, 9 )
    path:lineTo( 2, 5 )
    path:lineTo( 1, 5 )
    path:close()

    self:super( path )
end