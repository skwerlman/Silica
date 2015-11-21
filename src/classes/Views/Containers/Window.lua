
class "Window" extends "Container" {
	-- separatorObject = false;	
	-- shadowObject = false;
	-- barObject = false;
	barHeight = 7;

	container = false;
    closeButton = false;
    minimiseButton = false;
    maximiseButton = false;
    isEnabled = false;

	dragX = false;
	dragY = false;
    isDragging = false;
    isResizingX = false;
	isResizingY = false;

    minWidth = 60;
    minHeight = 40;
    maxWidth = 300;
    maxHeight = 150;

    isCanvasHitTested = false;
}

--[[
	@constructor
	@desc Initialise a application container instance
	@param [table] properties -- the properties for the view
]]
function Window:initialise( ... )
	self:super( ... )
    self.closeButton = self:insert( CloseWindowButton( { x = 1, y = 1, window = self } ))
    self.minimiseButton = self:insert( MinimiseWindowButton( { x = 9, y = 1, window = self } ))
    self.maximiseButton = self:insert( MaximiseWindowButton( { x = 17, y = 1, window = self } ))

    self:loadInterface()
    
    self:event( MouseDownEvent, self.onMouseDownBefore, Event.phases.BEFORE )
    self:event( MouseDownEvent, self.onMouseDownAfter, Event.phases.AFTER )
    self.event:connectGlobal( MouseDragEvent, self.onGlobalMouseDrag )
    self.event:connectGlobal( MouseUpEvent, self.onGlobalMouseUp, Event.phases.BEFORE )
    self:event( LoadedInterfaceEvent, self.onInterfaceLoaded )
end

--[[
    @desc Sets up the canvas and it's graphics objects
]]
function Window:initialiseCanvas()
    self:super()
    -- self.canvas.fillColour = Graphics.colours.GREEN
	local barHeight = self.barHeight
    local shadowObject = self.canvas:insert( RoundedRectangle( 3, 4, self.width - 2, self.height - 3 ) )
    local barObject = self.canvas:insert( RoundedRectangle( 1, 1, self.width - 2, barHeight ) )
    local separatorObject = self.canvas:insert( Rectangle( 1, barHeight + 1, self.width - 2, 1 ) )

    self.theme:connect( barObject, "fillColour", "barColour" )
    self.theme:connect( barObject, "topRadius", "topCornerRadius" )
    self.theme:connect( separatorObject, "fillColour", "separatorColour" )
    self.theme:connect( shadowObject, "topRadius", "topCornerRadius" )
    self.theme:connect( shadowObject, "bottomRadius", "bottomCornerRadius" )
    self.theme:connect( shadowObject, "fillColour", "shadowColour" )
    self.shadowObject = shadowObject
	self.barObject = barObject
	self.separatorObject = separatorObject
end

--[[
    @desc Loads the interface specified by the self.interfaceName interface name
]]
function Window:loadInterface()
    local interfaceName = self.interfaceName
    if interfaceName then
        local barHeight = self.barHeight
        local x, y, width, height = 1, barHeight + 2, self.width - 2, self.height - barHeight - 5
        local container = Interface( interfaceName, WindowContainer ).container
        container.x = x
        container.y = y
        container.width = width
        container.height = height
        self.container = self:insert( container )
    else
        self.container = self:insert( WindowContainer( { x = x, y = y, width = width, height = height } ) )
    end
end

function Window.height:set( height )
    height = math.max( math.min( height, self.maxHeight ), self.minHeight )
    self:super( height )
    self.shadowObject.height = height - 3
    local container = self.container
    if container then container.height = height - self.barHeight - 5 end
end

function Window.width:set( width )
    width = math.max( math.min( width, self.maxWidth ), self.minWidth )
    self:super( width )
    self.shadowObject.width = width - 2
    self.barObject.width = width - 2
    self.separatorObject.width = width - 2
    local container = self.container
    if container then container.width = width - 2 end
end

function Window:onInterfaceLoaded( Event event, Event.phases phase )
    local currentContainer = self.container
    for i, childView in ipairs( self.children ) do
        if childView ~= currentContainer and childView:typeOf( WindowContainer ) then
            childView.x = 1
            childView.y = self.barHeight + 2
            childView.width = self.width - 2
            childView.height = self.height - self.barHeight - 5
            self:remove( self.container )
            self.container = childView
            break
        end
    end
end

function Window:updateThemeStyle()
    self.theme.style = self.isEnabled and "default" or "disabled"
end

function Window.isEnabled:set( isEnabled )
    self:super( isEnabled )
    self:updateThemeStyle()
end

--[[
    @desc Centres the window relative to it's parent (which should be the application container)
]]
function Window:centre()
    local parent = self.parent
    if parent then
        self.x = math.ceil( ( parent.width - self.width ) / 2)
        self.y = math.ceil( ( parent.height - self.height ) / 2)
    end
end

Window:alias( Window.centre, "center" )

--[[
    @desc Focus on the window, bringing it to the front and enabling controls whilst unfocusing other windows
]]
function Window:focus()
    if not self.isEnabled then
        self.application:clearFocus( Window )
        self.isEnabled = true
        self.parent:sendToFront( self )
        for i, sibling in ipairs( self:siblingsOfType( Window ) ) do
            sibling:unfocus()
        end
    end
end

--[[
    @desc Unfocus on the window, disabling controls
]]
function Window:unfocus()
    self.isEnabled = false
end

--[[
    @desc Fired when the mouse is pushed on the window bar before children have recieved the event. Makes the window front most and active
    @param [MouseDownEvent] event -- the mouse down event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Window:onMouseDownBefore( Event event, Event.phases phase )
    self:focus()
end

--[[
    @desc Fired when the mouse is pushed on the window bar after children have recieved the event. Starts dragging.
    @param [MouseDownEvent] event -- the mouse down event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Window:onMouseDownAfter( Event event, Event.phases phase )
    if self.isEnabled and event.mouseButton == MouseEvent.mouseButtons.LEFT then
        x = event.x
        y = event.y
        local width = self.width
        local height = self.height
        local isResizingX = x >= width - 6
        local isResizingY = y >= height - 8
        self.isResizingX = isResizingX
        self.isResizingY = isResizingY
        self.isDragging = not ( isResizingX or isResizingY )
        self.dragX = isResizingX and width - x or x
        self.dragY = isResizingY and height - y or y
    end
    return true
end

--[[
    @desc Fired when the mouse is dragged anywhere on screen. Moves the window if dragging
    @param [Event] event -- the mouse drag event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Window:onGlobalMouseDrag( Event event, Event.phases phase )
    if self.isEnabled and event.mouseButton == MouseEvent.mouseButtons.LEFT then
        local preventPropagation = false
        if self.isDragging then
            self.x = event.x - self.dragX + 1
            self.y = event.y - self.dragY + 1
            preventPropagation = true
        else
            if self.isResizingX then
                self.width = event.x - self.x + self.dragX + 1
                preventPropagation = true
            end
            if self.isResizingY then
                self.height = event.y - self.y + self.dragY + 1
                preventPropagation = true
            end
        end
        return preventPropagation
    end
end

--[[
    @desc Fired when the mouse is released anywhere on screen. Stops dragging
    @param [Event] event -- the mouse up event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Window:onGlobalMouseUp( Event event, Event.phases phase )
    if (self.isDragging or self.isResizingX or self.isResizingY ) and event.mouseButton == MouseEvent.mouseButtons.LEFT then
        self.dragX = false
        self.dragY = false
        self.isDragging = false
        self.isResizingX = false
        self.isResizingY = false
        return true
    end
end

--[[
    @desc Closes the window, removing it from the screen
]]
function Window:close()
    self.isVisible = false
    self.parent:remove( self )
end