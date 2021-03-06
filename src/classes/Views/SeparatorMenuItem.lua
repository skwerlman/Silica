
class "SeparatorMenuItem" extends "MenuItem" {

	height = Number( 3 );
	width = Number( 51 );

    text = String( "" ); -- we give it a default value because we can't set it to .allowsNil

}

function SeparatorMenuItem:initialise( ... )
	self.super:super( ... ) -- by pass the normal menuitem's event connecting, we don't need to get any events
    self:event( ThemeChangedInterfaceEvent, self.updateSize )
    self:updateSize()
end

function SeparatorMenuItem:onDraw()
    local width, height, theme, canvas, isPressed = self.width, self.height, self.theme, self.canvas
    canvas:fill( theme:value( "fillColour" ) )
    local leftMargin = theme:value( "leftMargin" )
    local separatorX, separatorY, separatorWidth = 1 + leftMargin, 1 + theme:value( "topMargin" ), width - leftMargin - theme:value( "rightMargin" )
    canvas:fill( theme:value( "separatorColour" ), theme:value( "separatorIsDashed" ) and SeparatorMask( separatorX, separatorY, separatorWidth, 1 ) or RectangleMask( separatorX, separatorY, separatorWidth, 1 ) )
end

function SeparatorMenuItem:updateSize( ThemeChangedInterfaceEvent.allowsNil event, Event.phases.allowsNil phase )
    local theme = self.theme
    self.height = 1 + theme:value( "topMargin") + theme:value( "bottomMargin")
end
