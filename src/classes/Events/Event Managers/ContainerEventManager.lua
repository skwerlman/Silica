
class "ContainerEventManager" extends "EventManager" {}

--[[
	@desc Perfoms the appropriate handles for the given event and then trickles them down through the owner's children
	@param [Event] event -- the event to handle
	@return [boolean] stopPropagation -- whether no further handles should recieve this event
]]
function ContainerEventManager:handleEvent( event )
	local sender = event.sender
	local isSentToSender = not sender or ( self == sender and event.isSentToSender )
	if isSentToSender and self:handleEventPhase( event, Event.phases.BEFORE ) then
		return true
	end

	if event.isSentToChildren then
		local owner = self.owner
		local children = owner.children
		local eventClass = event.class
		for i = #children, 1, -1 do
			local childView = children[i]
			local childViewEvent = childView.event
			if childView:typeOf( Container ) or childViewEvent:hasConnections( eventClass ) then
				if childView:hitTestEvent( event, owner ) then
					event:makeRelative( childView )
					if childViewEvent:handleEvent( event ) then
						return true
					end
					event:makeRelative( owner )
				else

				end
			end
		end
	end
	if isSentToSender and self:handleEventPhase( event, Event.phases.AFTER ) then
		return true
	end
end
