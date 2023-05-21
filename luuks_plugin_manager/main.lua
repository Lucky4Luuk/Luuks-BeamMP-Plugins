-- A plugin manager for all my plugins.
-- The goal of this plugin is to install, uninstall, active/deactivate and
-- auto update plugins.

-- TODO: Find a good way to make HTTP requests to download and auto update plugins.
-- TODO: Find a way to load plugins while the server is still running.
--       This will probably require loading plugins as part of this plugin
--       instead of loading them as actual BeamMP plugins.

function InitHandler()
    print("Hello from Luuks plugin manager!")
end

MP.RegisterEvent("onInit", "InitHandler")
