
class "ArgumentCountClassException" extends "ClassException" {

}

function ArgumentCountClassException:initialise( String message, Number.allowsNil level )
    message = "Incorrect number of arguments: " .. message
    self:super( message, level )
end