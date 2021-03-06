
local MIN_CHAR = 0
local MAX_CHAR = 255

local MAX_VISIBLE = 5
local PREVIEW_SPACING = 10
local RESIZE_MARGIN_SIZE = 5

class "FontStudioApplicationContainer" extends "ApplicationContainer" {
    
    characterEditorView = InterfaceOutlet( "characterEditorView" );
    saveButton = InterfaceOutlet( "saveButton" );
    visibleCharacters = {};
    documentContents = false;
    previewViews = {};

    animationPercentage = 0;
    currentCharacter = false;

}

function FontStudioApplicationContainer:initialise( ... )
	self:super( ... )
	self:event( ReadyInterfaceEvent, self.onReady)
    self:event( Event.KEY_DOWN, self.onKeyDown )
end

function FontStudioApplicationContainer:onReady( ReadyInterfaceEvent event, Event.phases phase )
    FontDocument:open( "src/fonts/Napier.sfont" )

    local document = self.application.document
    self.documentContents = document.contents
    -- self.characterEditorView.character = document.contents.characters[97]
    -- self.previewView.characterByte = 97
    -- self.previewView.x = math.ceil( ( self.width - self.previewView.width ) / 2 )
    self.currentCharacter = 97

    -- document.contents = "Hello!"
    -- document:save()
end

function FontStudioApplicationContainer:onKeyDown( Event event, Event.phases phase )
    local keyCode = event.keyCode

    if keyCode == keys.left then
        self.currentCharacter = self.currentCharacter - 1
    elseif keyCode == keys.right then
        self.currentCharacter = self.currentCharacter + 1
    end
end

function FontStudioApplicationContainer.currentCharacter:set( currentCharacter )
    local oldCharacter = self.currentCharacter
    if oldCharacter == currentCharacter or currentCharacter < MIN_CHAR or currentCharacter > MAX_CHAR then return end
    self.currentCharacter = currentCharacter

    local characterEditorView, documentContents = self.characterEditorView, self.documentContents
    log(characterEditorView)
    if not characterEditorView.character then
        characterEditorView.character = documentContents.characters[currentCharacter]
    else
        characterEditorView.nextCharacter = documentContents.characters[currentCharacter]
        self:animate( 'animationPercentage', 1, 0.25, function() self.animationPercentage = 0 end, nil, nil, false )
    end

    local characters, characterEditorView, width, height, scale = documentContents.characters, self.characterEditorView, self.width, self.height, characterEditorView.scale
    local y = math.ceil( ( height - documentContents.height * scale ) / 2 )
    local positions = {}

    local spacing = 2 * scale

    local currentWidth = characters[currentCharacter].width * scale
    local leftX, rightX = math.floor( ( width - currentWidth ) / 2 ) - spacing - RESIZE_MARGIN_SIZE, math.ceil( ( width + currentWidth ) / 2 ) + spacing + RESIZE_MARGIN_SIZE

    local i = currentCharacter
    positions[currentCharacter] = math.floor( ( width - currentWidth ) / 2 )

    while rightX < width and i <= MAX_CHAR do
        i = i + 1
        positions[i] = rightX
        rightX = rightX + characters[i].width * scale + spacing
    end

    i = currentCharacter
    while leftX > 1 and i >= MIN_CHAR do
        i = i - 1
        leftX = leftX - characters[i].width * scale - spacing
        positions[i] = leftX
    end

    local previewViews = self.previewViews
    local time, easing = 0.5

    local _self = self
    for char, view in pairs( previewViews ) do
        -- remove not longer used views
        if not positions[char] then
            if char > currentCharacter then
                previewViews[char]:animate( "x",  width + 1, time, function() _self:remove( self ) end, easing )
            else
                previewViews[char]:animate( "x",  1 - previewViews[char].width, time, function() _self:remove( self ) end, easing )
            end
            previewViews[char] = nil
        end
    end

    for char, x in pairs( positions ) do
        if previewViews[char] then
            previewViews[char]:animate( "x",  x, time, nil, easing )
            previewViews[char].isActive = char == currentCharacter
        else
            local startX = char < currentCharacter and 1 - characters[char].width or 1 + width
            log(startX)
            previewViews[char] = self:insert( CharacterPreviewView( { x = startX, y = y, characterByte = char, isActive = char == currentCharacter } ) )
            previewViews[char]:animate( "x",  x, time, nil, easing )
        end
    end

    self:sendToFront( characterEditorView )
end

function FontStudioApplicationContainer.animationPercentage:set( animationPercentage )
    self.animationPercentage = animationPercentage
    self.characterEditorView.animationPercentage = animationPercentage
end

function FontStudioApplicationContainer:onSaveButton()
    self.application.document:save()
end