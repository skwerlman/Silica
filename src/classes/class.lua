
-- Class Construction --

class = {
    folders = {};
    tables = {};
}

local classes, interfaces = {}, {}
local valueTypes = {}
local compiledClassDetails, compiledInstances, compiledStatics = {}, {}, {}
local currentlyConstructing, expectedName -- the class that is currently being constructed
local constructingEnvironment, constructorProxy, constructingFunctionArguments, currentCompiledClass
local stripFunctionArguments, loadProperties, compileClass, loadPropertiesTableSection, checkValue, constructSuper, isInterface, pseudoReference
local allLockedGetters, allLockedSetters = {}, {}
local isLoadingProperties
local interface

local application -- the running application

local TYPETABLE_NAME, TYPETABLE_TYPE, TYPETABLE_CLASS, TYPETABLE_ALLOWS_NIL, TYPETABLE_IS_VAR_ARG, TYPETABLE_IS_ENUM, TYPETABLE_ENUM_ITEM_TYPE, TYPETABLE_HAS_DEFAULT_VALUE, TYPETABLE_IS_DEFAULT_VALUE_REFERENCE, TYPETABLE_DEFAULT_VALUE = 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
local FUNCTIONTABLE_FUNCTION = 1
local VALUE_TYPE_UID = {} -- just a unique identifier to indicate that this is a valueType
local REFERENCE_UID = {} -- just a unique identifier to indicate that this is a valueType

local RESERVED_NAMES = { super = true, static = true, metatable = true, class = true, raw = true, application = true, className = true, typeOf = true, isDefined = true, isDefinedProperty = true, isDefinedFunction = true }

-- Create the value types --

function createValueType( name, typeStr, classType, destinationKey, destination )
    destination = destination or valueTypes
    destinationKey = destinationKey or name
    classType = classType or false
    local valueType = {
        VALUE_TYPE_UID;
        [TYPETABLE_TYPE] = typeStr;
        [TYPETABLE_CLASS] = classType;
        [TYPETABLE_ALLOWS_NIL] = false;
        [TYPETABLE_IS_VAR_ARG] = false;
        [TYPETABLE_IS_ENUM] = false;
        [TYPETABLE_ENUM_ITEM_TYPE] = false;
        [TYPETABLE_HAS_DEFAULT_VALUE] = false;
        [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
    }

    local metatable = {}
    function metatable:__call( ... )
        local valueInstance = {
            VALUE_TYPE_UID;
            [TYPETABLE_TYPE] = typeStr;
            [TYPETABLE_CLASS] = classType;
            [TYPETABLE_ALLOWS_NIL] = false;
            [TYPETABLE_IS_VAR_ARG] = false;
            [TYPETABLE_IS_ENUM] = false;
            [TYPETABLE_ENUM_ITEM_TYPE] = false;
            [TYPETABLE_HAS_DEFAULT_VALUE] = true;
            [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
        }

        local args = { ... }
        if #args == 1 and type( args[1] ) == "table" and args[1][0] == REFERENCE_UID then
            -- this is a reference value
            valueInstance[TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = true
            valueInstance[TYPETABLE_DEFAULT_VALUE] = args[1]
        elseif not classType then
            if #args >= 2 then
                error( "non-class types are only allowed 1 argument, the default value" , 2 )
            end
            valueInstance[TYPETABLE_DEFAULT_VALUE] = checkValue( args[1], valueInstance ) -- check the default value actually complies with the type if it's not a class (class default values are parsed as arguments)
        else
            for i, v in ipairs( args ) do
                valueInstance[TYPETABLE_DEFAULT_VALUE + i - 1] = v
            end
        end

        local metatable = {}
        function metatable:__index( k )
            if k == "allowsNil" then
                valueInstance[TYPETABLE_ALLOWS_NIL] = true
                return valueInstance
            elseif type( k ) ~= "number" then -- if it's a number it would've been trying to get a default value, don't error
                error( "tried to index '" .. k .. "', types only support .allowsNil" , 2 )
            end
        end

        function metatable:__newindex( k )
            error("attempt to set property of valueType", 2 )
        end

        local __tostring = "value type instance (w. default) '" .. name .. "': " ..  tostring( valueInstance ):sub( 8 )
        function metatable:__tostring() return __tostring end
        setmetatable( valueInstance, metatable )

        return valueInstance
    end

    function metatable:__index( k )
        if k == "allowsNil" then
            valueType[TYPETABLE_ALLOWS_NIL] = true -- this sets it for the type everywhere, we then MUST reset it once we've accessed it
            return valueType
        elseif type( k ) ~= "number" then -- if it's a number it would've been trying to get a default value, don't error
            error( "tried to index '" .. k .. "', types only support .allowsNil", 2 )
        end
    end

    function metatable:__newindex( k )
        error("attempt to set property of valueType", 2 )
    end

    local __tostring = "value type '" .. name .. "': " ..  tostring( valueType ):sub( 8 )
    function metatable:__tostring() return __tostring end
    setmetatable( valueType, metatable )

    rawset( destination, destinationKey, valueType ) -- if it's a enum of a class we need to set it on the class value type
    return valueType
end

createValueType( "Any", false )
createValueType( "String", "string" )
createValueType( "Boolean", "boolean" )
createValueType( "Number", "number" )
createValueType( "Table", "table" )
createValueType( "Function", "function" )
createValueType( "Thread", "thread" )
-- createValueType( "Class", "table" ) -- TODO: 

-- Create Enum Value type
 
local function createEnumType()
    local metatable = {}
    local valueType = {
        VALUE_TYPE_UID;
        [TYPETABLE_TYPE] = "table";
        [TYPETABLE_CLASS] = false;
        [TYPETABLE_ALLOWS_NIL] = false;
        [TYPETABLE_IS_VAR_ARG] = false;
        [TYPETABLE_IS_ENUM] = true;
        [TYPETABLE_ENUM_ITEM_TYPE] = false;
        [TYPETABLE_HAS_DEFAULT_VALUE] = false;
        [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
    }
    function metatable:__call( ... )
        local valueInstance = {
            VALUE_TYPE_UID;
            [TYPETABLE_TYPE] = "table";
            [TYPETABLE_CLASS] = false;
            [TYPETABLE_ALLOWS_NIL] = false;
            [TYPETABLE_IS_VAR_ARG] = false;
            [TYPETABLE_IS_ENUM] = true;
            [TYPETABLE_HAS_DEFAULT_VALUE] = true;
            [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
        }
        local args = { ... }
        if #args ~= 2 then
            error( "enums only support 2 arguments: valueType, table" , 2 )
        end
        local itemValueType = args[1]
        if type( itemValueType ) ~= "table" or itemValueType[1] ~= VALUE_TYPE_UID or itemValueType[TYPETABLE_HAS_DEFAULT_VALUE] then
            error( "1st argument must be ValueType without a default value" , 2 )
        end
        local values = args[2]
        if not type( value ) == "table" then
            error( "2nd argument must be table" , 2 )
        end
        valueInstance[TYPETABLE_ENUM_ITEM_TYPE] = itemValueType

        for k, v in pairs( values ) do
            if type( func ) == "function" then
                error( "function enum values must not be defined in properties table" , 2 )
            end
            if not type( k ) == "string" or not k:match( "^[_%u]+$" ) then
                error( "Enum keys must be all uppercase with _" , 2 )
            end

            checkValue( v, itemValueType ) -- check that the default values comply with the required type
        end

        valueInstance[TYPETABLE_DEFAULT_VALUE] = values

        local metatable = {}
        function metatable:__index( k )
            error( "Enum does not support .allowsNil or indexing other properties" , 2 )
        end

        function metatable:__newindex( k, v )
            error( "attempt to change enum valuetype" , 2 )
        end

        local __tostring = "value type instance (w. default & item type) 'Enum': " ..  tostring( valueInstance ):sub( 8 )
        function metatable:__tostring() return __tostring end
        setmetatable( valueInstance, metatable )

        return valueInstance
    end

    function metatable:__index( k )
        error( "Enum does not support .allowsNil or other properties" , 2 )
    end

    function metatable:__newindex( k )
        error("attempt to set property of Enum", 2 )
    end

    local __tostring = "value type 'Enum': " ..  tostring( valueType ):sub( 8 )
    function metatable:__tostring() return __tostring end
    setmetatable( valueType, metatable )

    valueTypes["Enum"] = valueType
end
createEnumType()

-- Create the class loading methods --

function class.get( name )
    return classes[name] or interfaces[name] or class.load( name )
end

function class.exists( name )
    for i, tbl in ipairs( class.tables ) do
        local f = tbl[name]
        if f then
            local g = f["text/lua"]
            if g then return g end
        end
    end

    for i, folder in ipairs( class.folders ) do
        local f = folder:find( name, Metadata.mimes.LUA )
        if f then
            return f.contents
        end
    end
end

function class.load( name, contents )
    if classes[name] or interfaces[name] then
        error( "class already loaded: "..name)
    end
    local oldConstructing, oldEnvironment, oldConstructorProxy, oldIsLoadingProperties, oldConstructingFunctionArguments, oldCurrentCompiled, oldIsInterface, oldExpectedName = currentlyConstructing, constructingEnvironment, constructorProxy, isLoadingProperties, constructingFunctionArguments, currentCompiledClass, isInterface, expectedName
    isLoadingProperties = false
    currentlyConstructing = nil

    expectedName = name
    constructingFunctionArguments = {}
    constructingEnvironment = { class = class, extends = extends, interface = interface, implements = implements }

    local compiledClass = {}
    createValueType( name, "table", compiledClass ) -- generate the value type for this class. the future table for the compiled class is used, which will be filled later
    currentCompiledClass = compiledClass

    -- TODO: load classes if we index _G with their name and they return nil. only allow self if it is within the static table
    local metatable = {}
    local selfPseudoReference = pseudoReference( "self" )
    function metatable:__index( key )
        local globalValue = _G[key]
        if globalValue then return globalValue end
        if key == "self" then return selfPseudoReference end
        -- if the value is nil see if we can find a class with that name and load it
        if class.exists( key ) then
            -- there should be a class with that name, load it
            local _class = class.load( key )
            -- if we're loading properties we want to return its valueType
            if isLoadingProperties then
                return valueTypes[key]
            else
                return _class
            end
        end
    end

    setmetatable( constructingEnvironment, metatable )

    local func, err = loadstring( stripFunctionArguments( name, contents ), name )
    if not func then
        error( "could not parse " .. name .. ": ".. err )
    else
        setfenv( func, constructingEnvironment )
        func()
    end


    if not currentlyConstructing then
        error( "expected a class/interface to be defined but it wasn't in file "..name )
    end

    compileClass( compiledClass, name )
    local wasInterface = isInterface
    constructingEnvironment, currentlyConstructing, constructorProxy, isLoadingProperties, constructingFunctionArguments, currentCompiledClass, isInterface, expectedName = oldEnvironment, oldConstructing, oldConstructorProxy, oldIsLoadingProperties, oldConstructingFunctionArguments, oldCurrentCompiled, oldIsInterface, oldExpectedName
    return wasInterface and interfaces[name] or classes[name]
end

function class.setApplication( newApplication )
    application = newApplication
end

-- Start loading the class and get the argument types from the functions --

function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local function loadClassLines( name, contents )
    local file = contents or class.exists( name )
    if not file then
        error( "Unable to find class " .. name )
    end
    local lines = lines( file, "\n" )
    return lines
end

function pseudoReference( name )
    local referenceTable = {
        [0] = REFERENCE_UID;
        name;
    }

    local metatable = {}
    function metatable:__index( key )
        table.insert( referenceTable, key )
        return referenceTable
    end

    function metatable:__newindex( key )
        error( "attempt to set pseudo reference value" )
    end
    setmetatable( referenceTable, metatable )

    return referenceTable
end

function stripFunctionArguments( name, contents )
    local classString = ""
    local foundTypeDeclaration = false
    for n, line in ipairs( loadClassLines( name, contents ) ) do
        if not foundTypeDeclaration then
            if line:match( "^%s*class%s*\"%w*\"" ) then
                isInterface = false
                foundTypeDeclaration = true
            elseif line:match( "^%s*interface%s*\"%w*\"" ) then
                isInterface = true
                foundTypeDeclaration = true
            end
        elseif line:sub( 1, 9 ) == "function " then
            -- get the components from the function declaration
            local isEnum = false
            local firstLevel, secondLevel, functionName, arguments = line:match( "^function " .. name .. "%.([_%w]+)%.([_%w]+):([_%w]+)%s*%((.*)%)%s*$" )
            if not firstLevel then
                firstLevel, functionName, arguments = line:match( "^function " .. name .. "%.([_%w]+):([_%w]+)%s*%((.*)%)%s*$" )
                if not firstLevel then
                    firstLevel, functionName, arguments = line:match( "^function " .. name .. "%.([_%w]+)%.([_%w]+)%s*%((.*)%)%s*$" ) -- for enums function
                    if not firstLevel then
                        functionName, arguments = line:match( "^function " .. name .. ":([_%w]+)%s*%((.*)%)%s*$" )
                        if not functionName or not arguments then
                            error(name..": "..n..": function malformed", 2 )
                        end
                    else
                        isEnum = true
                    end
                end
            end

            local valueTypeExtractionEnvironment = {}
            local pseudoReferences = {}
            local metatable = {}
            function metatable:__index( key )
                local globalValue = valueTypes[key]
                if globalValue then return globalValue end
                local pseudoReferenceValue = pseudoReferences[key]
                if pseudoReferenceValue then print("using pseudo "..key) return pseudoReferenceValue end
                -- if we're loading properties and the value is nil, see if we can find a class with that name and load it
                if class.exists( key ) then
                    -- there should be a class with that name, load it
                    class.load( key )
                    -- now we want to return its valueType
                    return valueTypes[key]
                else
                    error( "attempt to access undelcared value " .. key .. " in value type declaration ", 2 )
                end
            end
            setmetatable( valueTypeExtractionEnvironment, metatable )

            local previousI, i = 1, 1
            local argumentsTable, argumentSubstringPoints = {}, {}
            local argumentsString = ""
            if not arguments:match("^%s*$") then -- ignore empty brackets
                -- get the arguments and types from the brackets
                local openedBrackets = 0
                for i = 1, #arguments do
                    local char = arguments:sub( i, i )
                    if char == "(" then
                        openedBrackets = openedBrackets + 1
                    elseif char == ")" then
                        openedBrackets = openedBrackets - 1
                    elseif char == "," and openedBrackets == 0 then -- if this is a command separating 
                        table.insert( argumentSubstringPoints, { previousI, i - 1 } )
                        previousI = i + 1
                    end                
                end
                table.insert( argumentSubstringPoints, { previousI,} )
                local argumentSubstringPointsLength = #argumentSubstringPoints
                for i, points in ipairs( argumentSubstringPoints ) do
                    local argument = arguments:sub( points[1], points[2] )
                    local typeTable, type, argumentName
                    local isVarArg = false
                    if i == argumentSubstringPointsLength then
                        type, argumentName = argument:match( "^(.-)(%.%.%.)%s*$" )
                        if argumentName then
                            isVarArg = true
                        end
                    end
                    if not isVarArg then
                        type, argumentName = argument:match( "^(.-)([_%w]+)%s*$" )
                        if not type or not argumentName then
                            error( name .. ": " .. n .. ": argument formatting wrong", 0 )
                        end
                    end

                    -- extract the variable type from the argument declaration
                    if not type or type:match("^%s*$") then
                        -- type wasn't given
                        -- this is just a plain variable, we make it an Any( value ).allowsNil with the default being its default value. this acts identical to default Lua behaviour
                        typeTable = {
                            [TYPETABLE_NAME] = argumentName;
                            [TYPETABLE_TYPE] = false;
                            [TYPETABLE_CLASS] = false;
                            [TYPETABLE_ALLOWS_NIL] = true;
                            [TYPETABLE_IS_VAR_ARG] = isVarArg;
                            [TYPETABLE_IS_ENUM] = false;
                            [TYPETABLE_ENUM_ITEM_TYPE] = false;
                            [TYPETABLE_HAS_DEFAULT_VALUE] = true;
                            [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
                            [TYPETABLE_DEFAULT_VALUE] = nil;
                        }
                    else
                        local func = loadstring( "return " .. type, name )
                        if not func then
                            error("argument did bad: " .. name .. ": " .. n)
                        end
                        setfenv( func, valueTypeExtractionEnvironment )
                        value = func()

                        if not value then
                            error( name .. ": " .. n .. ": error extracting value type from " .. type )
                        elseif value[TYPETABLE_HAS_DEFAULT_VALUE] then -- this was created like String(), not String, so it created its own instance. hence we can use the value directly
                            value[TYPETABLE_NAME] = argumentName
                            typeTable = value
                            if argumentName == "width" then
                                print(serialise(value[TYPETABLE_DEFAULT_VALUE]))
                            end
                        else
                            -- this is the actual valueType table, we can't use it. we need to make a copy AND set allowsNil back to false as it may have been changed
                            typeTable = {
                                [TYPETABLE_NAME] = argumentName;
                            }

                            for i = TYPETABLE_TYPE, #value do
                                typeTable[i] = value[i]
                            end

                            value[TYPETABLE_ALLOWS_NIL] = false
                        end
                        typeTable[TYPETABLE_IS_VAR_ARG] = isVarArg;

                        if typeTable[TYPETABLE_TYPE] == "table" and i ~= argumentSubstringPoints then -- if it's a table add an item to the environment so it can be referenced
                            pseudoReferences[argumentName] = pseudoReference( argumentName )
                        end
                    end
                    table.insert( argumentsTable, typeTable )  
                    argumentsString = argumentsString .. argumentName .. ","
                end
            end


            argumentsString = argumentsString:sub(1, #argumentsString - 1) -- remove the trailing comma

            local replacementLine = "function " .. name
            -- store the types
            if firstLevel then
                replacementLine = replacementLine .. "." .. firstLevel
                local firstLevelTable = constructingFunctionArguments[firstLevel]
                if not firstLevelTable then
                    firstLevelTable = {}
                    constructingFunctionArguments[firstLevel] = firstLevelTable
                end

                if not isEnum and ( secondLevel or firstLevel ~= "static" ) then
                    -- as this is a getter or a setter force the type and name of argument to match the property
                    if functionName == "get" then
                        if #argumentsTable ~= 0 then
                            error( name .. ": " .. n .. ": getters cannot have any arguments" , 2 )
                        end
                    elseif functionName == "set" then
                        if #argumentsTable ~= 1 then
                            error( name .. ": " .. n .. ": setters can only have one argument" , 2 )
                        end
                        local tableItem = argumentsTable[1]
                        if tableItem[TYPETABLE_NAME] ~= (secondLevel and secondLevel or firstLevel) then
                            error( name .. ": " .. n .. ": setters argument must be called the same name as the property" , 2 )
                        end
                        if tableItem[TYPETABLE_TYPE] then
                            error( name .. ": " .. n .. ": setters argument should not indicate a type, it is automatically inferred" , 2 )
                        end
                    end
                end

                if secondLevel then
                    -- essentially a static getter/setter or enum function
                    replacementLine = replacementLine .. "." .. secondLevel
                    local secondLevelTable = firstLevelTable[firstLevel]
                    if not secondLevelTable then
                        secondLevelTable = {}
                        firstLevelTable[secondLevel] = secondLevelTable
                    end
                    secondLevelTable[functionName] = argumentsTable
                else                    
                    firstLevelTable[functionName] = argumentsTable
                end
            else
                constructingFunctionArguments[functionName] = argumentsTable
            end
            line = replacementLine .. ":" .. functionName .. "(" .. argumentsString .. ")" .. (isInterface and " end" or "")
        elseif isInterface and line:match( "^%s*end%s*$" ) then
            error( name .. ": " .. "interfaces mustnt use end with functions" , 2 )
        end
        classString = classString .. line .. "\n"
    end
    return classString
end

-- Being the creation of the class
local function constructClass( _, name )
    if name ~= expectedName then
        error( "wrong name, got "..name.." expected "..tostring(expectedName) ) -- wrong name
    end
    isInterface = false
    local constructing = {
        name = name;
        instanceProperties = {};
        instanceFunctions = {};
        prebuiltInstanceFunctions = {};
        instanceGetters = {};
        prebuiltInstanceGetters = {};
        instanceSetters = {};
        prebuiltInstanceSetters = {};
        staticProperties = {};
        staticFunctions = {};
        prebuiltStaticFunctions = {};
        staticGetters = {};
        prebuiltStaticGetters = {};
        staticSetters = {};
        prebuiltStaticSetters = {};
        metatableFunctions = {};
        aliases = {};
        enums = {};
        enumTypes = {};
        interfaces = {};
        typeOfCache = {};
    }

    classes[name] = true
    currentlyConstructing = constructing
    isLoadingProperties = true

    -- insert all the valueTypes in to the environment for property loading
    for name, valueType in pairs( valueTypes ) do
        constructingEnvironment[name] = valueType
    end

    return loadProperties
end

function interface( name )
    if #name < 2 or name:sub( 1, 1) ~= "I" then
        error('must start with I')
    end
    if name ~= expectedName then
        error( "wrong name" , 2 ) -- wrong name
    end
    isInterface = true
    local constructing = {
        name = name;
        instanceProperties = {};
        instanceFunctions = {};
        prebuiltInstanceFunctions = {};
        instanceGetters = {};
        prebuiltInstanceGetters = {};
        instanceSetters = {};
        prebuiltInstanceSetters = {};
        staticProperties = {};
        staticFunctions = {};
        prebuiltStaticFunctions = {};
        staticGetters = {};
        prebuiltStaticGetters = {};
        staticSetters = {};
        prebuiltStaticSetters = {};
        metatableFunctions = {};
        enums = {};
    }

    interfaces[name] = constructing
    currentlyConstructing = constructing
    isLoadingProperties = true
    return loadProperties
end

function extends( name )
    if isInterface then
        error("interfaces can't extend", 2 ) -- TODO: maybe make possible
    end
    if name ~= currentlyConstructing.name then
        local ext = class.get( name )
        local typeOfCache = currentlyConstructing.typeOfCache
        typeOfCache[ext] = true
        for k, v in pairs( compiledClassDetails[name].typeOfCache ) do
            typeOfCache[k] = v
        end

        currentlyConstructing.superName = name
    else
        error( "can't extend self" , 2 )
    end
    return loadProperties
end

function implements( name )
    if isInterface then
        error("interfaces can't implements", 2 )
    end
    if name ~= currentlyConstructing.name then
        local interface = class.get( name )
        currentlyConstructing.interfaces[name] = interface
        currentlyConstructing.typeOfCache[interface] = true
    else
        error( "can't extend self" , 2 )
    end
    return loadProperties
end

function loadProperties( propertiesTable )
    -- take all the valueTypes back out of the environment
    for name, valueType in pairs( valueTypes ) do
        constructingEnvironment[name] = nil
    end
    constructingEnvironment.self = nil -- and remove the pseudo type

    isLoadingProperties = false
    local staticPropertiesTable = propertiesTable.static
    local metatableProxy = {}
    local staticConstructorProxy = { }
    local constructorProxy = { static = staticConstructorProxy, metatable = metatableProxy } -- injected in to the loading class' environment. acts to recieve function creations

    local superName = currentlyConstructing.superName
    local compiledSuperDetails = superName and compiledClassDetails[superName]
    local enums = currentlyConstructing.enums
    local superEnums = compiledSuperDetails and compiledSuperDetails.enums
    loadPropertiesTableSection( propertiesTable, compiledSuperDetails and compiledSuperDetails.instanceProperties, currentlyConstructing.instanceProperties, constructorProxy, currentlyConstructing.instanceGetters, currentlyConstructing.instanceSetters, enums, "static", currentCompiledClass )
    if staticPropertiesTable then
        loadPropertiesTableSection( staticPropertiesTable, compiledSuperDetails and compiledSuperDetails.staticProperties, currentlyConstructing.staticProperties, staticConstructorProxy, currentlyConstructing.staticGetters, currentlyConstructing.staticSetters )
    end

    -- merge the super enums in to our enums
    local superOnlyEnums = {} -- enums that were not declared or change by self class
    if superEnums then
        for enumName, enum in pairs( superEnums ) do
            superOnlyEnums[enumName] = true
            local selfEnum = enums[enumName]
            if not selfEnum then
                enums[enumName] = enum
            else
                superOnlyEnums[enumName] = false
                if selfEnum[TYPETABLE_ENUM_ITEM_TYPE] ~= enum[TYPETABLE_ENUM_ITEM_TYPE] then
                    error( "cannot change type requirement of enum defined by super" , 2 )
                end
                for key, value in pairs( enum ) do
                    if selfEnum[key] then
                        error( "Cannot change value of enum value "..key )
                    else
                        selfEnum[key] = value
                    end
                end
            end
        end
    end

    -- Begin loading functions
    local enumTypes = currentlyConstructing.enumTypes
    for k, enum in pairs( enums ) do
        local selfTostring = "enum '" .. currentlyConstructing.name .. "." .. k .. "': " ..  tostring( enum ):match( "[%w]+$" )
        local __tostring = superOnlyEnums[k] and tostring( enum ) or selfTostring
        local enumValueType = propertiesTable[k] or superEnums[k]
        local itemValueType = enumValueType[TYPETABLE_ENUM_ITEM_TYPE]
        enumTypes[k] = itemValueType
        setmetatable( enum, {
            __newindex = function( _, key, func )
                if type( func ) ~= "function" then
                    error( "non-function enum values must be defined in properties table" , 2 )
                end
                if not type( key ) == "string" or not key:match( "^[_%u]+$" ) then
                    error( "Enum keys must be all uppercase with _" , 2 )
                end
                checkValue( func, itemValueType, nil, { self = self }, key )
                if superOnlyEnums[k] then
                    __tostring = selfTostring
                    superOnlyEnums[k] = false
                end
                rawset( enum, key, func )
            end,
            __tostring = function() return __tostring end
        } )
        constructorProxy[k] = enum
    end

    local aliases = {}
    currentlyConstructing.aliases = aliases

    local aliasable = {
        instance = {
            "instanceProperties";
            "instanceFunctions";
        };
        static = {
            "staticProperties";
            "staticFunctions";
        };
        enums = {
            "enums";
        };
    }
    local indexAliasTags = {}    
    for mainKey, subkeys in pairs( aliasable ) do
        aliases[mainKey] = {}
        local proxy = mainKey == "static" and staticConstructorProxy or constructorProxy
        for i, subkey in ipairs( subkeys ) do
            for k, v in pairs( currentlyConstructing[subkey] ) do
                indexAliasTags[proxy[k]] = { mainKey, k, subkey }
            end
        end
    end

    function constructorProxy:alias( value, newName )
        if type( newName ) ~= "string" then
            error( "correct: :alias(table/function, string)", 2 )
        end
        local aliasTag = indexAliasTags[value]
        if not aliasTag then
            error("can't alias undefined value", 2 )
        end
        local oldName = aliasTag[2]
        local mainTable = aliases[aliasTag[1]]

        if currentlyConstructing[aliasTag[3]][newName] then
            error( "attempt to overwrite property/function with alias "..newName)
        else
            mainTable[aliasTag[1]] = oldName
        end

        -- add the proxy item for the new alias
        rawset( constructorProxy, newName, constructorProxy[oldName] )
    end

    local instanceFunctions = currentlyConstructing.instanceFunctions
    setmetatable( constructorProxy, {
        __index = function( _, key )
            error( "attempted to access undefined property or function '" .. key .. "'", 2)
        end,
        __newindex = function( _, key, func )
            if RESERVED_NAMES[key] then
                error("reserved name "..key)
            end
            local arguments, functionTable = constructingFunctionArguments[key], { func }
            if not arguments then error("function decalared with invalid formatting", 2 ) end
            for i, argument in ipairs( arguments ) do
                table.insert( functionTable, argument )
            end
            instanceFunctions[key] = functionTable
            rawset( constructorProxy, key, func )
            indexAliasTags[func] = { "instance", key, "instanceFunctions" }
        end
    } )

    local metatableFunctions = currentlyConstructing.metatableFunctions
    setmetatable( metatableProxy, {
        __index = function( _, key )
            error( "attempted to access metatable property or function '" .. key .. "'", 2)
        end,
        __newindex = function( _, key, func )
            metatableFunctions[key] = func
        end
    } )

    local staticFunctions = currentlyConstructing.staticFunctions
    local staticFunctionArguments = constructingFunctionArguments.static
    setmetatable( staticConstructorProxy, {
        __index = function( _, key )
            error( "attempted to access undefined property or function '" .. key .. "'", 2)
        end,
        __newindex = function( _, key, func )
            if RESERVED_NAMES[key] then
                error("reserved name "..key)
            end
            local arguments, functionTable = staticFunctionArguments[key], { func }
            if not arguments then error("function decalared with invalid formatting", 2 ) end
            for i, argument in ipairs( arguments ) do
                table.insert( functionTable, argument )
            end
            staticFunctions[key] = functionTable
            rawset( staticConstructorProxy, key, func )
            indexAliasTags[func] = { "static", key, "staticFunctions" }
        end
    } )
    constructingEnvironment[currentlyConstructing.name] = constructorProxy
end

function loadPropertiesTableSection( fromTable, fromSuper, toTable, proxyTable, gettersTable, settersTable, enumsTable, ignoreKey, compiledClass )
    for propertyName, value in pairs( fromTable ) do
        if propertyName ~= ignoreKey then
            local isEnum = false
            if type( value ) == "table" and value[1] == VALUE_TYPE_UID then
                -- this is a value type
                if value[TYPETABLE_IS_ENUM] then
                    if not enumsTable then
                        error( "cannot use enums in static" , 2 )
                    elseif not value[TYPETABLE_HAS_DEFAULT_VALUE] then
                        error( "enums must be initialised" , 2 )
                    end
                    value[TYPETABLE_NAME] = propertyName
                    local values = value[TYPETABLE_DEFAULT_VALUE]
                    enumsTable[propertyName] = values -- we can use the value table directly
                    isEnum = true
                else
                    if ignoreKey then
                        local classType = value[TYPETABLE_CLASS]
                        -- TODO: type of!
                        if classType and classType == compiledClass then --classType:typeOf( "self??" ) then
                            -- don't allow value types that is type of self or are subclasses of self for non-static properties, that would cause an infinite loop
                            error( "self refernce not in static" , 2 )
                        end
                    end
                    if value[TYPETABLE_HAS_DEFAULT_VALUE] then -- this was created like String(), not String. hence we can use the value table directly
                        value[TYPETABLE_NAME] = propertyName
                        toTable[propertyName] = value
                    else
                        -- this is the actual valueType table, we can't use it. we need to make a copy AND set allowsNil back to false as it may have been changed
                        local uniqueValue = {
                            [TYPETABLE_NAME] = propertyName;
                        }

                        for i = TYPETABLE_TYPE, #value do
                            uniqueValue[i] = value[i]
                        end
                        toTable[propertyName] = uniqueValue

                        value[TYPETABLE_ALLOWS_NIL] = false
                    end
                end
            else
                -- this is just a plain variable, we make it an Any( value ).allowsNil with the default being its default value. this acts identical to default Lua behaviour
                toTable[propertyName] = {
                    [TYPETABLE_NAME] = propertyName;
                    [TYPETABLE_TYPE] = false;
                    [TYPETABLE_CLASS] = false;
                    [TYPETABLE_ALLOWS_NIL] = true;
                    [TYPETABLE_IS_VAR_ARG] = false;
                    [TYPETABLE_IS_ENUM] = false;
                    [TYPETABLE_ENUM_ITEM_TYPE] = false;
                    [TYPETABLE_HAS_DEFAULT_VALUE] = true;
                    [TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] = false;
                    [TYPETABLE_DEFAULT_VALUE] = value;
                }
            end
            if not isEnum then
                proxyTable[propertyName] = setmetatable( {}, {
                    __newindex = function( _, key, func )
                        if key == "get" then
                            if gettersTable[propertyName] then
                                error( "attempt to redefine getter for " .. propertyName )
                            else
                                gettersTable[propertyName] = func
                            end
                        elseif key == "set" then
                            if settersTable[propertyName] then
                                error( "attempt to redefine setter for " .. propertyName )
                            else
                                settersTable[propertyName] = func
                            end
                        else
                            error(":get and :set only", 2 )
                        end
                    end
                } )
            end
        end
    end

    if fromSuper then
        for propertyName, v in pairs( fromSuper ) do
            if not RESERVED_NAMES[propertyName] and not proxyTable[propertyName] then
                proxyTable[propertyName] = setmetatable( {}, {
                    __newindex = function(_, key, func)
                        if key == "get" then
                            gettersTable[propertyName] = func
                        elseif key == "set" then
                            settersTable[propertyName] = func
                        else
                            error(":get and :set only, not "..key)
                        end
                    end
                } )
            end
        end
    end
end

-- We have collected all the information about the class now, compile it in to the static class --

local function generateDefaultValue( typeTable )
    -- this asumes TYPETABLE_HAS_DEFAULT_VALUE is true and TYPETABLE_TYPE is "table" and should only be called when that is true
    local classType = typeTable[TYPETABLE_CLASS]
    if classType then
        return classType( unpack( typeTable, TYPETABLE_DEFAULT_VALUE ))
    else
        local defaultTable = typeTable[TYPETABLE_DEFAULT_VALUE]
        -- if it's a plain table make a deep copy of it
        local function uniqueTable( default )
            local new = {}
            for k, v in pairs( default ) do
                if type( v ) == "table" then
                    new[k] = uniqueTable( v )
                else
                    new[k] = v
                end
            end
            return new
        end
        return uniqueTable( defaultTable )
    end
end

function checkValue( value, typeTable, isSelf, context, circularKey ) -- TODO: error level and message based on where it's called form
    if value == nil  then
        -- if the value is nil try loading the default value
        local hasDefaultValue = typeTable[TYPETABLE_HAS_DEFAULT_VALUE]
        if hasDefaultValue then
            if typeTable[TYPETABLE_IS_DEFAULT_VALUE_REFERENCE] then
                -- this is a reference, we need to get the value out of the content
                if not context then
                    error( "attempted to use reference in invalid location (no context)" )
                end
                value = context
                for i, key in ipairs( context ) do
                    value = value[key]
                    -- TODO: circular references
                    -- if circularKey and circularKey[i] == key then
                        -- error( "attempted to make circular reference " )
                    -- end
                end
                -- don't return because we'll need to check if the value it gave was okay
            elseif typeTable[TYPETABLE_TYPE] ~= "table" then
                return typeTable[TYPETABLE_DEFAULT_VALUE]
            else
                return generateDefaultValue( typeTable )                
            end
        end
    end

    if value == nil  then
        -- if a default value couldn't be loaded and the argument doesn't accept nil then error
        if not typeTable[TYPETABLE_ALLOWS_NIL] then
            error("can't be nil", 2 )
        else
            -- otherwise, if nil is okay, continue with nil
            return nil
        end
    end

    local expectedType = typeTable[TYPETABLE_TYPE]
    if expectedType then
        if type( value ) == expectedType then
            local expectedClass = typeTable[TYPETABLE_CLASS]
            if expectedClass then
                if true or value.typeOf and value:typeOf( expectedClass ) then -- TODO: typeOf
                    return value
                end
            else
                return value
            end
        end
        if isSelf then
            error("self not passed to function, you probably used . instead of :", 3)
        else
            error(typeTable[TYPETABLE_NAME] .. " was wrong type, expected "..expectedType .. " got " .. type( value ), 4)
        end
    end
    return value
end

local function mergeProperties( classProperties, staticProperties )
    for k, staticTypeTable in pairs( staticProperties ) do
        if not classProperties[k] then
            -- subclass doesn't define the property, copy it
            classProperties[k] = staticTypeTable
        else
            -- subclass does define the property
            local classTypeTable = classProperties[k]

            -- ensure that the types and allows nil are the same
            if classTypeTable[TYPETABLE_NAME] ~= staticTypeTable[TYPETABLE_NAME] or classTypeTable[TYPETABLE_TYPE] ~= staticTypeTable[TYPETABLE_TYPE] or classTypeTable[TYPETABLE_CLASS] ~= staticTypeTable[TYPETABLE_CLASS] or classTypeTable[TYPETABLE_ALLOWS_NIL] ~= staticTypeTable[TYPETABLE_ALLOWS_NIL] then
                error("cannot change type or allows nil of super class' property", 2 )
            end
        end
    end
end

-- generate the actual class and flatten all super values
function compileClass( compiledClass, name )
    compiledClassDetails[name] = currentlyConstructing    
    if isInterface then
        interfaces[name] = compiledClass
        for k, v in pairs( currentlyConstructing ) do
            compiledClass[k] = v
        end
        local __tostring = "interface '" .. name .. "': " ..  tostring( compiledClass ):sub( 8 )
        setmetatable( compiledClass, { __tostring = function()
            return __tostring
        end } )
    else
        currentlyConstructing.typeTable = { "self", "table", type, false, false, false }

        local superName = currentlyConstructing.superName
        local compiledSuperDetails = superName and compiledClassDetails[superName] 

        -- add super properties and ensure they don't conflict
        if compiledSuperDetails then
            mergeProperties( currentlyConstructing.instanceProperties, compiledSuperDetails.instanceProperties )
            mergeProperties( currentlyConstructing.staticProperties, compiledSuperDetails.staticProperties )
        end

        -- all the properties and functions have been added now, check that the class complies with its interfaces
        for interfaceName, interface in pairs( currentlyConstructing.interfaces ) do
            local functionTables, propertyTables, getterSetterTables = { "instanceFunctions", "staticFunctions" }, { "instanceProperties", "staticProperties", "enums" }, { "instanceGetters", "staticGetters", "staticSetters", "instanceSetters" }
            for i, tableName in ipairs( functionTables ) do
                local classDefined = currentlyConstructing[tableName]
                for functionName, functionTable in pairs( interface[tableName] ) do
                    local classFunctionTable = classDefined[functionName]
                    if not classFunctionTable then
                        error( "class does not define function "..functionName )
                    end
                    for i, argument in ipairs( functionTable) do
                        if i > FUNCTIONTABLE_FUNCTION then
                            local classArgument = classFunctionTable[i]
                            if not classArgument then
                                error( "function does not declare argument "..argument[TYPETABLE_NAME])
                            elseif argument[TYPETABLE_TYPE] ~= classArgument[TYPETABLE_TYPE] or argument[TYPETABLE_CLASS] ~= classArgument[TYPETABLE_CLASS] or argument[TYPETABLE_ALLOWS_NIL] ~= classArgument[TYPETABLE_ALLOWS_NIL] or argument[TYPETABLE_HAS_DEFAULT_VALUE] ~= classArgument[TYPETABLE_HAS_DEFAULT_VALUE] or argument[TYPETABLE_DEFAULT_VALUE] ~= classArgument[TYPETABLE_DEFAULT_VALUE] then
                                error( "argument does use declare same type as interface", 2 )
                            end
                        end
                    end
                end
            end
            -- TODO: check properties and setters for interfaces too!!!
        end

        compiledClassDetails[name] = currentlyConstructing

        local static = {}
        local metatable = currentlyConstructing.metatableFunctions
        compiledClass.static = static
        compiledClass.metatable = metatable
        compiledClass.className = name
        compiledClass.super = classes[superName]

        local enumTypes = currentlyConstructing.enumTypes 
        local enums = currentlyConstructing.enums
        for k, enum in pairs( enums  ) do
            if not next( enum ) then
                error( "Enums must have at least one value" , 2 )
            end
            local __tostring = tostring( enum ) -- we already set the __tostring
            setmetatable( enum, {
                __newindex = function( _, key, func )
                    error("Attempt to alter immutable (enum) "..__tostring)
                end,
                __tostring = function() return __tostring end
            } )
            compiledClass[k] = enum

            -- create the value type for this enum
            local ownerName, enumName = __tostring:match( "enum '(%w*)%.(%w*)':" )
            if ownerName == name and enumName == k then -- only create the value type if we modified it. k should always == enumName but worth checking
                local itemValueType = enumTypes[enumName]
                local fullEnumName = ownerName .. "." .. enumName

                itemValueType = createValueType( fullEnumName, itemValueType[TYPETABLE_TYPE], itemValueType[TYPETABLE_CLASS], enumName, valueTypes[ownerName] )

                for k, v in pairs( enum ) do -- we need to add the enum's values so they can be used as default values
                    rawset( itemValueType, k, v )
                end
                rawset( valueTypes[ownerName], enumName, itemValueType )
            end
        end

        for newKey, oldKey in pairs( currentlyConstructing.aliases.enums) do
            if compiledClass[newKey] then
                error( "attempt to overwrite existing value with alias" , 2 )
            end

            compiledClass[newKey] = enums[oldKey]
        end

        local typeOfCache = currentlyConstructing.typeOfCache
        function compiledClass:typeOf( object )
            if not object then return false
            elseif type( object ) ~= "table" then
                return false
            elseif typeOfCache[object] then
                return true
            elseif self == object then
                return true
            end
            return false
        end

        if not metatable.__call then 
            function metatable:__call( ... )
                return spawnInstance( name, ... )
           end
        end
        compiledClass.spawn = function( ... ) return spawnInstance( name, ... ) end

        if not metatable.__tostring then 
            local __tostring = "class '" .. name .. "': " ..  tostring( compiledClass ):sub( 8 )
            function metatable:__tostring()
               return __tostring
            end
        end

        if not metatable.__newindex then 
            function metatable:__newindex( key, value )
                error("attempt to set class property", 2 )
            end
        end

        if not metatable.__index then 
            function metatable:__index( key )
                if key == "application" then
                    return application
                end
                error("attempt to get undefined class property "..key, 2)
            end
        end
        setmetatable( compiledClass, metatable )


        compileInstanceClass( name, compiledClass, static )
        classes[name] = compiledClass
        static = compileAndSpawnStatic( static, name, compiledClass )
    end
    currentlyConstructing = nil
    _G[name] = compiledClass
    constructingEnvironment[name] = compiledClass
    return compiledClass
end

local function constructSuper( prebuiltFunctions )
    if #prebuiltFunctions == 1 then return end
    local lastSuper
    for i = 1, #prebuiltFunctions - 1 do
        local super, func = {}, prebuiltFunctions[i]( lastSuper )
        local __tostring = "super " .. tostring(prebuiltFunctions[i])
        setmetatable( super, {
            __tostring = function() return __tostring end;
            __call = function( self, ... ) return func( ... ) end
        } )
        super.super = lastSuper
        lastSuper = super
    end
    return lastSuper
end

-- return the minimum and maximum number of arguments that can be usd on a function
local function argumentLimits( functionTable )
    local functionTableLength = #functionTable
    local maxArgs = functionTableLength - FUNCTIONTABLE_FUNCTION
    if maxArgs == 0 then return 0, 0, 0 end
    if functionTable[functionTableLength][TYPETABLE_IS_VAR_ARG] then -- the last value is ..., so there is no maximum
        maxArgs = math.huge
    end
    local minChecked = 0 -- the minimum number of arguments that need to be checkValued (so optionals can be loaded)
    for i = functionTableLength, FUNCTIONTABLE_FUNCTION + 1, -1 do
        local funcTbl = functionTable[i]
        if funcTbl[TYPETABLE_IS_VAR_ARG] then -- varargs are always optional
        elseif funcTbl[TYPETABLE_HAS_DEFAULT_VALUE] then
            minChecked = math.max( minChecked, i - 1 ) -- this value has a default value, so it will ALWAYS need to be checked
        elseif not funcTbl[TYPETABLE_ALLOWS_NIL] then
            return i - 1, maxArgs, minChecked
        end
    end

    return 0, maxArgs, minChecked
end

local function addPrebuilt( functionName, prebuiltFunction, prebuiltFunctions, superPrebuiltFunctions )
    local prebuilts = {}
    prebuiltFunctions[functionName] = prebuilts
    if superPrebuiltFunctions then
        local functions = superPrebuiltFunctions[functionName]
        if functions then
            for i, func in ipairs( functions ) do
                prebuilts[i] = func
            end
        end
    end
    prebuilts[#prebuilts + 1] = prebuiltFunction
    return prebuiltFunction( constructSuper( prebuilts ) )
end

local function addMissingSuper( superPrebuilt, prebuiltFunctions, outValues, definedIndexes )
    if superPrebuilt then
        for functionName, funcs in pairs( superPrebuilt ) do
            if not prebuiltFunctions[functionName] then
                prebuiltFunctions[functionName] = funcs -- TODO: check this doesn't cause issues due to using the same table
                if definedIndexes then definedIndexes[functionName] = functionName end
                outValues[functionName] = funcs[#funcs]( constructSuper( funcs ) )
            end
        end
    end
end

local function addFunctions( classFunctions, definedIndexes, prebuiltFunctions, superPrebuiltFunctions, outValues, selfTypeTable )
    for functionName, functionTable in pairs( classFunctions ) do
        definedIndexes[functionName] = functionName
        local func = functionTable[FUNCTIONTABLE_FUNCTION]
        local minArgs, maxArgs, minChecked = argumentLimits( functionTable )
        local varargTypeTable
        local functionTableLength = #functionTable
        if functionTableLength > FUNCTIONTABLE_FUNCTION and functionTable[functionTableLength][TYPETABLE_IS_VAR_ARG] then
            varargTypeTable = functionTable[functionTableLength]
        end
        local function prebuiltFunction( super )
            return function( self, ... )
                local arguments = { ... }
                local argumentsLength = #arguments
                if argumentsLength < minArgs or argumentsLength > maxArgs then
                    for i, v in ipairs(arguments) do
                        print(i .. ": "..tostring(v))
                    end
                    error( functionName .. ": wrong number of arguments, got "..argumentsLength.." expected between ".. minArgs .. " and " .. maxArgs, 2 )
                end

                local context = { self = self }
                local values = { checkValue( self, selfTypeTable, true, context, functionName ) }

                local argumentCount = (argumentsLength > minChecked and argumentsLength or minChecked)
                for i = 1 + FUNCTIONTABLE_FUNCTION, argumentCount + FUNCTIONTABLE_FUNCTION do
                    local valueType = (i > functionTableLength) and varargTypeTable or functionTable[i]
                    local valueName = valueType[TYPETABLE_NAME]
                    local value = checkValue( arguments[i - FUNCTIONTABLE_FUNCTION], valueType, context, valueName )
                    values[i] = value
                    if i < functionTableLength then
                        context[valueName] = value
                    end
                end

                local oldSuper = rawget( self, "super" )
                rawset( self, "super", super )
                local response = { func( unpack( values, 1, argumentCount + 1 ) ) }
                rawset( self, "super", oldSuper )
              
                return unpack( response )
            end
        end
        outValues[functionName] = addPrebuilt( functionName, prebuiltFunction, prebuiltFunctions, superPrebuiltFunctions )
    end
    addMissingSuper( superPrebuiltFunctions, prebuiltFunctions, outValues, definedIndexes )
end

local function addGetter( getters, properties, outGetters, prebuiltGetters, superPrebuiltGetters )
    for propertyName, getterFunction in pairs( getters ) do
        local propertyTypeTable = properties[propertyName]
        local function prebuiltGetter( super )
            return function( self )
                local oldSuper = rawget( self, "super" )
                rawset( self, "super", super )
                local lockedGetters = allLockedGetters[self]
                lockedGetters[propertyName] = true
                value = checkValue( getterFunction( self ), propertyTypeTable ) -- we know that this is defintely self as it's only called by the class system
                lockedGetters[propertyName] = false
                rawset( self, "super", oldSuper )
                return value
            end
        end
        outGetters[propertyName] = addPrebuilt( propertyName, prebuiltGetter, prebuiltGetters, superPrebuiltGetters )
    end
    addMissingSuper( superPrebuiltGetters, prebuiltGetters, outGetters )
end

local function addSetter( setters, properties, outSetters, prebuiltSetters, superPrebuiltSetters )
    for propertyName, setterFunction in pairs( setters ) do
        local propertyTypeTable = properties[propertyName]
        local function prebuiltSetter( super )
            return function( self, value )
                local oldSuper = rawget( self, "super" )
                rawset( self, "super", super )
                local lockedSetters = allLockedSetters[self]
                lockedSetters[propertyName] = true
                setterFunction( self, checkValue( value, propertyTypeTable ) ) -- we know that this is defintely self as it's only called by the class system
                lockedSetters[propertyName] = false
                rawset( self, "super", oldSuper )
                return value
            end
        end
        outSetters[propertyName] = addPrebuilt( propertyName, prebuiltSetter, prebuiltSetters, superPrebuiltSetters )
    end
    addMissingSuper( superPrebuiltSetters, prebuiltSetters, outSetters )
end

function compileInstanceClass( name, compiledClass, static )
    local initialValues, prebuiltGetters, prebuiltSetters, requireDefaultGeneration, definedIndexes, definedProperties = { static = static, class = compiledClass, }, {}, {}, {}, { static = "static", class = "class", typeOf = "typeOf", isDefined = "isDefined", isDefinedProperty = "isDefinedProperty", isDefinedFunction = "isDefinedFunction" }, { static = "static", class = "class" }
    local classDetails = compiledClassDetails[name]
    local superName = classDetails.superName
    local compiledSuperDetails = superName and compiledClassDetails[superName]
    local instanceProperties = classDetails.instanceProperties
    local selfTypeTable = classDetails.typeTable


    -- add default property values if they have them
    for propertyName, typeTable in pairs( instanceProperties ) do
        definedIndexes[propertyName] = propertyName
        definedProperties[propertyName] = propertyName

        if typeTable[TYPETABLE_HAS_DEFAULT_VALUE] then
            local defaultValue = typeTable[TYPETABLE_DEFAULT_VALUE]
            if ( typeTable[TYPETABLE_TYPE] or type( defaultValue ) ) ~= "table" then
                if typeTable[TYPETABLE_ALLOWS_NIL] and defaultValue ~= nil then -- there isn't a value here yet. don't assign the value yet, but if after initialisation there isn't a value an error will be thrown if it doesn't allow nil
                    initialValues[propertyName] = defaultValue
                end
            else
                requireDefaultGeneration[propertyName] = typeTable
            end
        end
    end

    local aliases = classDetails.aliases.instance
    for k, v in pairs( aliases ) do -- copy the aliases to definedIndexes
        definedIndexes[k] = v
        if definedProperties[v] then
            definedProperties[k] = v
        end
    end

    -- add the instance functions
    addFunctions( classDetails.instanceFunctions, definedIndexes, currentlyConstructing.prebuiltInstanceFunctions, compiledSuperDetails and compiledSuperDetails.prebuiltInstanceFunctions, initialValues, selfTypeTable )

    addGetter( classDetails.instanceGetters, instanceProperties, prebuiltGetters, currentlyConstructing.prebuiltInstanceGetters, compiledSuperDetails and compiledSuperDetails.prebuiltInstanceGetters )
    addSetter( classDetails.instanceSetters, instanceProperties, prebuiltSetters, currentlyConstructing.prebuiltInstanceSetters, compiledSuperDetails and compiledSuperDetails.prebuiltInstanceSetters )

    local typeOfCache = classDetails.typeOfCache
    function initialValues:typeOf( object )
        if not object then return false
        elseif type( object ) ~= "table" then
            return false
        elseif object == compiledClass then
            return true
        elseif typeOfCache[object] then
            return true
        elseif self == object then
            return true
        end
        return false
    end

    function initialValues:isDefined( key )
        return definedIndexes[key] ~= nil
    end

    function initialValues:isDefinedProperty( key )
        return definedProperties[key] ~= nil
    end

    function initialValues:isDefinedFunction( key )
        return definedProperties[key] ~= nil and definedIndexes[key] ~= nil
    end

    compiledInstances[name] = {
        initialValues = initialValues;
        prebuiltFunctions = prebuiltFunctions;
        prebuiltGetters = prebuiltGetters;
        prebuiltSetters = prebuiltSetters;
        requireDefaultGeneration = requireDefaultGeneration;
        definedIndexes = definedIndexes;
        definedProperties = definedProperties;
    }
end

function compileAndSpawnStatic( static, name, compiledClass )
    local classDetails = compiledClassDetails[name]
    local staticProperties = classDetails.staticProperties
    local selfTypeTable = classDetails.typeTable
    local superName = classDetails.superName
    local compiledSuperDetails = superName and compiledClassDetails[superName]

    local values, getters, setters = { class = compiledClass }, {}, {}

    local definedIndexes, definedProperties = { typeOf = "typeOf", class = "class", isDefinedProperty = "isDefinedProperty", isDefinedFunction = "isDefinedFunction" }, { class = "class" }
    for propertyName, typeTable in pairs( staticProperties ) do
        definedIndexes[propertyName] = propertyName
        definedProperties[propertyName] = propertyName
        if typeTable[TYPETABLE_HAS_DEFAULT_VALUE] then
            local defaultValue = typeTable[TYPETABLE_DEFAULT_VALUE]
            if ( typeTable[TYPETABLE_TYPE] or type( defaultValue ) ) ~= "table" then
                values[propertyName] = typeTable[TYPETABLE_DEFAULT_VALUE]
            else
                values[propertyName] = generateDefaultValue( typeTable )
            end
        end
    end

    local aliases = classDetails.aliases.static
    for k, v in pairs( aliases ) do -- copy the aliases to definedIndexes
        definedIndexes[k] = v
        if definedProperties[v] then
            definedProperties[k] = v
        end
    end

    addFunctions( classDetails.staticFunctions, definedIndexes, classDetails.prebuiltStaticFunctions, compiledSuperDetails and compiledSuperDetails.prebuiltStaticFunctions, values, selfTypeTable )

    local lockedGetters, lockedSetters = {}, {}
    allLockedGetters[static] = lockedGetters
    allLockedSetters[static] = lockedSetters

    addGetter( classDetails.staticGetters, staticProperties, getters, currentlyConstructing.prebuiltInstanceGetters, compiledSuperDetails and compiledSuperDetails.prebuiltStaticGetters )
    addSetter( classDetails.staticSetters, staticProperties, setters, currentlyConstructing.prebuiltInstanceSetters, compiledSuperDetails and compiledSuperDetails.prebuiltStaticSetters )

    local typeOfCache = classDetails.typeOfCache
    function static:typeOf( object )
        if not object then return false
        elseif type( object ) ~= "table" then
            return false
        elseif object == compiledClass then
            return true
        elseif typeOfCache[object] then
            return true
        elseif self == object then
            return true
        end
        return false
    end

    function static:isDefined( key )
        return definedIndexes[key] ~= nil
    end

    function static:isDefinedProperty( key )
        return definedProperties[key] ~= nil
    end

    function static:isDefinedFunction( key )
        return definedProperties[key] ~= nil and definedIndexes[key] ~= nil
    end

    local metatable = {}
    function metatable:__newindex( key, value )
        if RESERVED_NAMES[key] then error( "reserved name" , 2 ) end

        local locatedKey = definedProperties[key]
        if locatedKey then
            local setter = setters[locatedKey]
            if setter and not lockedSetters[locatedKey] then
                setter( self, value )
            else
                values[locatedKey] = checkValue( value, staticProperties[locatedKey], nil, { self = self }, key )
            end
        else
            error("attempt to set undefined property or function", 2 )
        end
    end

    function metatable:__index( key )
        local locatedKey = definedIndexes[key]
        if locatedKey then
            local getter = getters[locatedKey]
            if getter and not lockedGetters[locatedKey] then
                return getter( self )
            else
                return values[locatedKey]
            end
        elseif key == "application" then
            return application
        elseif key == "super" then
            error("function does not have super function", 2 )
        else
            error("attempt to get undefined property '"..key.."' from "..tostring( self ), 2)
        end
    end

    local __tostring = "static of '" .. name .. "': " ..  tostring( static ):sub( 8 )
    function metatable:__tostring ()
        return __tostring
    end

    static.metatable = metatable
    setmetatable( static, metatable )

    -- run the initialiser
    for i, key in ipairs( { "initialise", "intialize" } ) do
        if definedIndexes[key] then
            if definedProperties[key] then
                error( "initialise must be function, not property", 2 )
            end
            static[key]( static )
            break
        end
    end

    -- TODO: check for any nil values that aren't allowed to be nil

    return static
end


function spawnInstance( name, ... )
    local compiledInstance = compiledInstances[name]
    local classDetails = compiledClassDetails[name]
    local instanceProperties = classDetails.instanceProperties

    local values, getters, setters = {}, {}, {}

    for key, value in pairs( compiledInstance.initialValues ) do
        values[key] = value
    end

    -- for default values that are tables make them unique or create class instances
    for propertyName, typeTable in pairs( compiledInstance.requireDefaultGeneration ) do
        if propertyName == "handles" then log "Generating" end
        values[propertyName] = generateDefaultValue( typeTable )
    end

    local lockedGetters, lockedSetters = {}, {}

    -- unwrap the prebuilt getter/setter functions so we can use our unique locking tables
    for propertyName, func in pairs( compiledInstance.prebuiltGetters ) do
        getters[propertyName] = func
    end

    for propertyName, func in pairs( compiledInstance.prebuiltSetters ) do
        setters[propertyName] = func
    end

    local aliases = classDetails.aliases.instance

    local definedIndexes, definedProperties = compiledInstance.definedIndexes, compiledInstance.definedProperties
    local instance = {}
    allLockedGetters[instance] = lockedGetters
    allLockedSetters[instance] = lockedSetters
    local metatable = {}
    function metatable:__newindex( key, value )
        if RESERVED_NAMES[key] then error( "reserved name" , 2 ) end

        local locatedKey = definedProperties[key]
        if locatedKey then
            local setter = setters[locatedKey]
            if setter and not lockedSetters[locatedKey] then
                setter( self, value )
            else
                values[locatedKey] = checkValue( value, instanceProperties[locatedKey], nil, { self = self }, key )
            end
        else
            error("attempt to set undefined property or function", 2 )
        end
    end

    function metatable:__index( key )
        local locatedKey = definedIndexes[key]
        if locatedKey then
            local getter = getters[locatedKey]
            if getter and not lockedGetters[locatedKey] then
                return getter( self )
            else
                return values[locatedKey]
            end
        elseif key == "application" then
            return application
        elseif key == "super" then
            error("function does not have super function", 2 )
        else
            error("attempt to get undefined property '"..key.."' from "..tostring( self ), 2)
        end
    end

    local __tostring = "instance of '" .. name .. "': " ..  tostring( instance ):sub( 8 )
    function metatable:__tostring ()
        return __tostring
    end

    instance.metatable = metatable
    instance.raw = values
    setmetatable( instance, metatable )

    -- run the initialiser
    for i, key in ipairs( { "initialise", "intialize" } ) do
        if definedIndexes[key] then
            if definedProperties[key] then
                error( "initialise must be function, not property", 2 )
            end
            instance[key]( instance, ... )
            break
        end
    end

    -- TODO: check for any nil values that aren't allowed to be nil

    return instance
end

setmetatable( class, {
    __call = constructClass
} )
