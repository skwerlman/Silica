
-- validates and parses values (so BLUE becomes Graphics.colours.BLUE)
class "Validator" {}

--[[
	@desc Gets a validation table from the given type name
	@param [string] typeName -- the type to validate against
	@return [Validator.validatorType] validatorType -- the table of valid values
]]
function Validator.static:validatorType( typeName )
	-- TODO: make validator types dynamic
	if typeName == "Graphics.colours" then
		return function( k ) return Graphics.colours[k] end
	elseif typeName == "Number" then
		return tonumber
	elseif typeName == "String" then
		return tostring
	elseif typeName == "Boolean" then
		return function( K ) local k = K:lower() if k == "true" then return true elseif k == "false" then return false end end
	elseif typeName == "Font" then
		return function( k ) return Font.static:fromName( k ) end
	elseif typeName == "Symbol" then
		return function( k ) return Symbol.static:fromName( k ) end
	else
		UnknownTypeValidationException( "Unknown validation type: '" .. typeName .. "'" )
	end
end

--[[
	@desc Validate a value against the given type
	@param value -- the value to validate
	@param [string] typeName -- the type to validate against
	@return [boolean] isValid -- whether the value is valid
]]
function Validator.static:isValid( value, typeName )
	local validatorType = self:validatorType( typeName )
	return validatorType( value ) ~= nil
end

--[[
	@desc Parse a value to the given type
	@param value -- the value to parse
	@param [string] typeName -- the type to parse to
	@return parsedValue -- the parsed value
]]
function Validator.static:parse( value, typeName )
	local validatorType = self:validatorType( typeName )
	return validatorType( value )
end
