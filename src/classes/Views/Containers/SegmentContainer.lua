
local SHADOW_RATIO = Canvas.shadows.SHADOW_RATIO

class "SegmentContainer" extends "Container" {

	needsLayoutUpdate = false;	

}

--[[
	@desc Updates the location and size of the menu as well as the location and size of the menu items
]]
function SegmentContainer:updateLayout()
	if self.isVisible then
		local width = 0
		local height = 0
		local children = self.children
		local childrenCount = #children
		for i, childView in ipairs( children ) do
			height = math.max( height, childView.height )
			childView.x = width + 1
			childView.y = 1
			width = width + childView.width
			if i ~= childrenCount then
				width = width - math.floor( SHADOW_RATIO * childView.theme:value( "shadowSize", "default" ) + 0.5 )
			end
		end
		self.width = width
		self.height = height
	end
	self.needsLayoutUpdate = false
end

function SegmentContainer:update( deltaTime )
    self:super( deltaTime )
    if self.needsLayoutUpdate then
        self:updateLayout()
    end
end

function SegmentContainer:insert( ... )
	self:super( ... )
	self.needsLayoutUpdate = true
end

function SegmentContainer:removeChild( ... )
	self:super( ... )
	self.needsLayoutUpdate = true
end