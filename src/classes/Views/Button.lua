
local SHADOW_RATIO = Canvas.shadows.SHADOW_RATIO

class "Button" extends "View" {

    height = Number( 16 );
    width = Number( 36 );
    text = String( "" );

    isPressed = Boolean( false );
    isFocused = Boolean( false );
    isAutosized = Boolean( true );
    isFocusDismissable = Boolean( true );

    needsAutosize = Boolean( true );

}

--[[
    @desc Creates a button object and connects the event handlers
]]
function Button:initialise( ... )
    self:super( ... )

    self:event( MouseDownEvent, self.onMouseDown )
    self:event( KeyDownEvent, self.onKeyDown )
    self:event( KeyUpEvent, self.onKeyUp )
    self.event:connectGlobal( MouseUpEvent, self.onGlobalMouseUp, Event.phases.BEFORE )
end

function Button:onDraw()
    local width, height, theme, canvas, isPressed = self.width, self.height, self.theme, self.canvas, self.isPressed

    -- get all the shadow size details so we can adjust the compression as needed
    local defaultShadowSize = theme:value( "shadowSize", "default" )
    local shadowPressedSize = theme:value( "shadowSize", "pressed" )
    local shadowSize = theme:value( "shadowSize" )
    local shadowOffset = defaultShadowSize - shadowSize
    local shadowPressedOffset = defaultShadowSize - shadowPressedSize
    local shadowX = math.floor( shadowOffset * SHADOW_RATIO + 0.5 )

    -- background shape
    local roundedRectangle = RoundedRectangleMask( shadowX + 1, shadowOffset + 1, width - math.floor( shadowPressedOffset * SHADOW_RATIO + 0.5 ), height - shadowPressedOffset, theme:value( "cornerRadius" ) )
    canvas:fill( theme:value( "fillColour" ), roundedRectangle )
    canvas:outline( theme:value( "outlineColour" ), roundedRectangle, theme:value( "outlineThickness" ) )

    local leftMargin, rightMargin, topMargin, bottomMargin = theme:value( "leftMargin" ), theme:value( "rightMargin" ), theme:value( "topMargin" ), theme:value( "bottomMargin" )
    -- text
    canvas:fill( theme:value( "textColour" ),  TextMask( leftMargin + shadowX + 1, topMargin + 1 + shadowOffset, width - leftMargin - rightMargin, height - topMargin - bottomMargin, self.text, theme:value( "font" ) ) )

    self.shadowSize = shadowSize
end

function Button.text:set( text )
    self.text = text
    self.needsDraw = true
    self.needsAutosize = true
end

function Button:update( deltaTime )
    self:super( deltaTime )
    if self.needsAutosize then
        self:autosize()
    end
end

--[[
    @desc Automatically resizes the button, regardless of isAutosized value, to fit the text
]]
function Button:autosize()
    if self.isAutosized then
        local text, theme = self.text, self.theme
        local font = theme:value( "font" )
        local defaultShadowSize = theme:value( "shadowSize", "default" )
        local shadowSize = theme:value( "shadowSize", "pressed" )
        local shadowOffset = defaultShadowSize - shadowSize
        local shadowX = math.floor( shadowOffset * SHADOW_RATIO + 0.5 )
        self.width = font:getWidth( self.text ) + theme:value( "leftMargin" ) + theme:value( "rightMargin" ) + shadowX
        self.height = font.height + theme:value( "topMargin" ) + theme:value( "bottomMargin" ) + shadowOffset
    end
    self.needsAutosize = false
end

function Button:updateThemeStyle()
    self.theme.style = self.isEnabled and ( self.isPressed and "pressed" or ( self.isFocused and "focused" or "default" ) ) or "disabled"
end

function Button.isEnabled:set( isEnabled )
    self.isEnabled = isEnabled
    self:updateThemeStyle()
end

function Button.isPressed:set( isPressed )
    self.isPressed = isPressed
    self:updateThemeStyle()
end

function Button.isFocused:set( isFocused )
    self.isFocused = isFocused
    self:updateThemeStyle()
end

--[[
    @desc Fired when the mouse is released anywhere on screen. Removes the pressed appearance.
    @param [Event] event -- the mouse up event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Button:onGlobalMouseUp( MouseUpEvent event, Event.phases phase )
    if self.isPressed and event.mouseButton == MouseEvent.mouseButtons.LEFT then
        self.isPressed = false
        if self.isEnabled and self:hitTestEvent( event ) then
            self.event:handleEvent( ActionInterfaceEvent( self ) )
            local result = self.event:handleEvent( event )
            return result == nil and true or result
        end
    end
end

--[[
    @desc Fired when the mouse is pushed anywhere on screen. Adds the pressed appearance.
    @param [MouseDownEvent] event -- the mouse down event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Button:onMouseDown( MouseDownEvent event, Event.phases phase )
    if self.isEnabled and event.mouseButton == MouseEvent.mouseButtons.LEFT then
        self.isPressed = true
    end
    return true
end

--[[
    @desc Fired when a key is pressed down. Presses the button down if it isin focus and it was the enter key.
    @param [KeyDownEvent] event -- the key down event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Button:onKeyDown( KeyDownEvent event, Event.phases phase )
    if self.isEnabled and self.isFocused and event.keyCode == keys.enter then
        self.isPressed = true
        return true
    end
end

--[[
    @desc Fired when a key is pressed released. Fires the button action if the button is pressed, in focus and it was the enter key.
    @param [KeyUpEvent] event -- the key down event
    @return [boolean] preventPropagation -- prevent anyone else using the event
]]
function Button:onKeyUp( KeyUpEvent event, Event.phases phase )
    if self.isEnabled and self.isPressed and self.isFocused and event.keyCode == keys.enter then
        self.isPressed = false
        self.event:handleEvent( ActionInterfaceEvent( self ) )
        return true
    end
end
