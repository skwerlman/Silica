
class "ChildAddedInterfaceEvent" extends "InterfaceEvent" {
	eventType = "interface_child_added";
	childView = false; -- the added child
	isSentToChildren = false;
}

--[[
	@constructor
	@desc Creates a child added event from the arguments
	@param [View] childView -- the added child
]]
function ChildAddedInterfaceEvent:initialise( childView )
	self.childView = childView
end