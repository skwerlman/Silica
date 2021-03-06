
class "SiblingRemovedInterfaceEvent" extends "InterfaceEvent" {

    static = {
        eventType = "interface_sibling_removed";
    };
	view = false; -- the new sibling that was removed
	isSentToChildren = Boolean( false );

}

--[[
	@constructor
	@desc Creates a siblings changed event from the arguments
	@param [View] view -- the removed sibling view
]]
function SiblingRemovedInterfaceEvent:initialise( view )
	self.view = view
end
