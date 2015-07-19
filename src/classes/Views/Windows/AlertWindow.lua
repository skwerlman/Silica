
class "AlertWindow" extends "Window" {
	interfaceName = "alert";
	okayButton = InterfaceOutlet( "okayButton" );
}

function AlertWindow:initialise( ... )
	self.super:initialise( ... )

	self:event( Event.INTERFACE_LOADED, self.onInterfaceLoaded )
	self:event( Event.INTERFACE_READY, self.onReady )

	self.width = 100
	self.height = 40
end

function AlertWindow:onReady( event )
	self:centre()
	self:focus()
	self.okayButton:focus()
end
