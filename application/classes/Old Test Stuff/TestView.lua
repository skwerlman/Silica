
class "TestView" extends "View" {

	width = false;
	height = false;

}

function TestView:initialise( ... )
	self:super( ... )
end

function TestView:initialiseCanvas( ... )
	self:super( ... )
	self.canvas.fillColour = Graphics.colours.RED
end

function TestView.width:set( width )
	self:super( width )
    width = self.width
end