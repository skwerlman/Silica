class "StyleClassException" extends "ClassException" {

}

function StyleClassException:initialise( String message, Number.allowsNil level )
    message = "Naming/code styling was incorrect (the Silica code style should consistent across all programs and developers): " .. message
    self:super( message, level )
end