
interface "IDragDropDestination" {
    
    dropStyle = false; -- [DragDropManager.dropStyles] the desired style for what should occur on drop (i.e. instantly disappear, animated shrink, etc.)

}

--[[
    @desc Returns true if the destination is able to accept the given ClipboardData (if this returns true you MUST be able to accept it)
    @param [ClipboardData] data -- the clipboard data
    @return [boolean] canAccept
]]
function IDragDropDestination:canAcceptDragDrop( data )

--[[
    @desc Fired when a drag and drop view is dragged over your view. Update the view's apperance if desired
    @param [ClipboardData] data -- the clipboard data
]]
function IDragDropDestination:dragDropEntered( data, dragView )

--[[
    @desc Fired when a drag and drop view is moved over your view (this is also fired after immediately :dragDropEntered). Update the view's apperance if desired
    @param [ClipboardData] data -- the clipboard data
]]
function IDragDropDestination:dragDropMoved( data, dragView )

--[[
    @desc Fired when a drag and drop view is dragged over your view. Update the view's apperance if desired
    @param [ClipboardData] data -- the clipboard data
]]
function IDragDropDestination:dragDropExited( data, dragView )

--[[
    @desc Fired when a drag and drop view is dropped on your view. Do NOT remove the drop apperance here, :dragDropExited is called immediately after.
    @param [ClipboardData] data -- the incomming clipboard data
]]
function IDragDropDestination:dragDropDropped( data )