
local DEFAULT_TIMESTAMP = 1417305600; -- default date 1/1/2015

local SAVED_PROPERTIES = { t = "mime"; c = "createdTimestamp"; o = "openedTimestamp"; m = "modifiedTimestamp"; i = "icon"; }

local g_tLuaKeywords = {
    [ "and" ] = true,
    [ "break" ] = true,
    [ "do" ] = true,
    [ "else" ] = true,
    [ "elseif" ] = true,
    [ "end" ] = true,
    [ "false" ] = true,
    [ "for" ] = true,
    [ "function" ] = true,
    [ "if" ] = true,
    [ "in" ] = true,
    [ "local" ] = true,
    [ "nil" ] = true,
    [ "not" ] = true,
    [ "or" ] = true,
    [ "repeat" ] = true,
    [ "return" ] = true,
    [ "then" ] = true,
    [ "true" ] = true,
    [ "until" ] = true,
    [ "while" ] = true,
}

local function serialise( t, tTracking )
    local sType = type(t)
    if sType == "table" then
        if tTracking[t] ~= nil then
            error( "Cannot serialize table with recursive entries", 0 )
        end
        tTracking[t] = true

        if next(t) == nil then
            return "{}"
        else
            local sResult = "{"
            local tSeen = {}
            for k,v in ipairs(t) do
                tSeen[k] = true
                sResult = sResult .. serialise( v, tTracking ) .. ";"
            end
            for k,v in pairs(t) do
                if not tSeen[k] then
                    local sEntry
                    if type(k) == "string" and not g_tLuaKeywords[k] and string.match( k, "^[%a_][%a%d_]*$" ) then
                        sEntry = k .. "=" .. serialise( v, tTracking ) .. ";"
                    else
                        sEntry = "[" .. serialise( k, tTracking ) .. "]=" .. serialise( v, tTracking ) .. ";"
                    end
                    sResult = sResult .. sEntry
                end
            end
            sResult = sResult:sub( 1, #sResult - 1 ) .. "}"
            return sResult
        end
    elseif sType == "string" then
        return string.format( "%q", t )
    elseif sType == "number" or sType == "boolean" or sType == "nil" then
        return tostring(t)
    else
        error( "Cannot serialize type "..sType, 0 )
    end
end

local EXTENSION_MIMES = {
    LUA = "text/lua";
    TXT = "text/plain";
    TEXT = "text/plain";
    IMAGE = "image/paint";
    NFP = "image/paint";
    NFT = "image/nft";
    SKCH = "image/sketch";
    SINTERFACE = "silica/interface";
    STHEME = "silica/theme";
    SCFG = "silica/config";
    SFONT = "silica/font";
    RESOURCEPKG = "package/resource";
    PACKAGE = "package/plain";
    APPLICATION = "silica/application";
}

class "Metadata" {
    
    file = false;
    metadataPath = false;

    mime = false; -- MIME mime of the file (e.g. image/nft)
    createdTimestamp = DEFAULT_TIMESTAMP;
    openedTimestamp = DEFAULT_TIMESTAMP;
    modifiedTimestamp = DEFAULT_TIMESTAMP;
    icon = false; -- by default, if this is empty it will get the default system icon for it. it allows for custom icons

    mimes = Enum( String, EXTENSION_MIMES );

}

function Metadata:initialise( file )
    self.file = file
    self.metadataPath = file.metadataPath
    self:load()
end

function Metadata:load()
    local metadataPath = self.metadataPath
    if fs.exists( metadataPath ) then
        local h = fs.open( metadataPath, "r" )
        if h then
            local properties = textutils.unserialize( h.readAll() )
            h.close()
            local raw = self.raw
            for key, value in pairs( properties ) do
                local propertyName = SAVED_PROPERTIES[key]
                if SAVED_PROPERTIES[key] then
                    raw[propertyName] = value
                end
            end
        end
    else
        local metadataFolderPath = self.file.parentPath .. "/.metadata"
        if fs.exists( metadataFolderPath ) then
            if not fs.isDir( metadataFolderPath ) then
                fs.delete( metadataFolderPath )
            end
        else
            log("make "..metadataFolderPath)
            fs.makeDir( metadataFolderPath )
        end
        self:create()
    end
end

function Metadata:save()
    local h = fs.open( self.metadataPath, "w" )
    if h then
        local properties = {}
        for shortKey, key in pairs( SAVED_PROPERTIES ) do
            local value = self[key]
            if value then
                properties[shortKey] = value
            end
        end
        h.write( serialise( properties, {} ) )
        h.close()
    end
end

function Metadata:serialise( allowedProperties )
    local properties = {}
    for shortKey, key in pairs( SAVED_PROPERTIES ) do
        local value = self[key]
        if value and ( not allowedProperties or allowedProperties[key] ) then
            properties[shortKey] = value
        end
    end
    return properties
end

-- TODO: do function aliases work?
Metadata:alias( Metadata.serialise, "serialize" )

-- create metadata for the file based on it's content
function Metadata:create()
    self:updateCreatedTimestamp()
    self:updateOpenedTimestamp()
    self:updateModifiedTimestamp()
    local file = self.file
    local path = file.path
    local extension = file.extension
    if extension then
        -- try to guess the MIME based on the extension
        if not EXTENSION_MIMES[ extension:upper() ] then
            error(extension:upper())
        end
        self.mime = EXTENSION_MIMES[ extension:upper() ] or "unknown"
    elseif fs.isDir( path ) then
        self.mime = "folder"
    end
    self:save()
end

function Metadata:delete()
    fs.delete( self.metadataPath )
    local oldParentMetadataPath = self.file.parentPath .. "/.metadata"
    if #fs.list( oldParentMetadataPath ) == 0 then
        fs.delete( oldParentMetadataPath )
    end
end

function Metadata:moveTo( folder )
    local folderMetadataFolderPath = folder.path .. "/.metadata"
    if not fs.exists( folderMetadataFolderPath ) then
        fs.makeDir( folderMetadataFolderPath )
    elseif fs.isDir( folderMetadataFolderPath ) then
        fs.delete( folderMetadataFolderPath )
        fs.makeDir( folderMetadataFolderPath )
    end
    local newMetadataPath = folderMetadataFolderPath .. "/" .. self.file.fullName
    fs.move( self.metadataPath, newMetadataPath )
    self.metadataPath = newMetadataPath
    local oldParentMetadataPath = self.file.parentPath .. "/.metadata"
    if #fs.list( oldParentMetadataPath ) == 0 then
        fs.delete( oldParentMetadataPath )
    end
end

function Metadata:copyTo( folder, newFile )
    local copyMetadataPath = folder.path .. "/.metadata/" .. self.file.fullName
    fs.copy( self.metadataPath, copyMetadataPath )
    newFile.metadata:updateModifiedTimestamp()
end

function Metadata:rename( fullName )
    local newMetadataPath = self.file.parentPath .. "/.metadata/" .. fullName
    fs.move( self.metadataPath, newMetadataPath )
    self.metadataPath = newMetadataPath
    self:updateModifiedTimestamp()
end

function Metadata:updateCreatedTimestamp()
    self.createdTimestamp = os.time()
end

function Metadata:updateOpenedTimestamp()
    self.openedTimestamp = os.time()
end

function Metadata:updateModifiedTimestamp()
    self.modifiedTimestamp = os.time()
end

function Metadata.createdTimestamp:set( createdTimestamp )
    self.createdTimestamp = createdTimestamp
    self:save()
end

function Metadata.openedTimestamp:set( openedTimestamp )
    self.openedTimestamp = openedTimestamp
    self:save()
end

function Metadata.modifiedTimestamp:set( modifiedTimestamp )
    self.modifiedTimestamp = modifiedTimestamp
    self:save()
end
