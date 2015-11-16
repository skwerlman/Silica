
local eventClasses = {}

class "Event" {
	
	relativeView = false; -- the view that the event is relative of
	eventType = false;
    sender = false;

	isSentToChildren = true; -- whether the event will be passed to children
	isSentToSender = true; -- whether the event will be handled by the sender

}

--[[
	@static
	@desc Registers an Event subclass to a event type name (e.g. MouseDownEvent links with "mouse_down")
	@param [class] _class -- the class that was constructed
]]
function Event.register( eventType, subclass )
	eventClasses[eventType] = subclass
end

--[[
	@static
	@desc Registers an Event subclass after it has just been constructed
	@param [class] _class -- the class that was constructed
]]
function Event.constructed( _class )
	if _class.eventType then
		Event.register( _class.eventType, _class )
	end
end

--[[
	@static
	@desc Creates an event with the arguments in a table from os.pullEvent or similar function
	@param [Event.eventTypes] eventType -- the event type
	@param ... -- the event arguments
	@return [Event] event
]]
function Event.create( eventType, ... )
	if not eventType then error( "No event type given to Event.create!", 0 ) end

	local eventClass = eventClasses[eventType]
	if eventClass then
		return eventClass( ... )
	else
		return Event()
	end
end

--[[
	@instance
	@desc Make the event relative to the supplied view
	@param [View] view -- the view to be relative to
]]
function Event:makeRelative( view )
	self.relativeView = view
end
