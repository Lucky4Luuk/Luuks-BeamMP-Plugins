-- Useful functionality for dependency checking
-- Checks for dependencies based on name, and checks if there is a plugin loaded
-- with that name. A better system is hopefully coming, but I have not had any
-- great ideas yet lol

function DepIsInstalled(dep)
    return FS.IsDirectory("Resources/Server/" .. dep)
end
