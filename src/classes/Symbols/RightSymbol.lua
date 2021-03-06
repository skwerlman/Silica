
class "RightSymbol" extends "Symbol" {

    static = {
        symbolName =  String( "right" );
    };

}

function RightSymbol.static:initialise()
    local path = Path( self.width, self.height, 4, 1 )
    path:lineTo( 7, 4 )
    path:lineTo( 4, 7 )
    path:lineTo( 4, 5 )
    path:lineTo( 1, 5 )
    path:lineTo( 1, 3 )
    path:lineTo( 4, 3 )
    path:lineTo( 4, 1 )
    path:close()

    self:super( path )
end
