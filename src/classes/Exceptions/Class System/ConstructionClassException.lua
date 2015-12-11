
class "ConstructionClassException" extends "ClassException" {

}

function ConstructionClassException:initialise( String message, Number.allowsNil level )
    message = "Error occured during class construction: " .. message
    self:super( message, level )
end
