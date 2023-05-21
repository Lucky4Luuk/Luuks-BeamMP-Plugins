-- Luuks permission plugin, works with all my plugins!
-- The goal is to have a generic permission system that
-- I can modify to work for whatever I want, and so
-- my friends only need to have 1 config file to manage
-- permissions for all my plugins.

-- Features:
-- : Customizable ranks with custom permission level
-- : Easily modifiable permission file, with hotreloading!

local config_path = "Resources/Server/luuks_permissions/config/luuks_perms.json"
local config_path_dir_only = "Resources/Server/luuks_permissions/config/"

local ranks = {} -- ranks["rank"] = level
local perms = {} -- perms["name"] = "rank"

local function ends_with(str, ending)
   return ending == "" or str:sub(-#ending) == ending
end

-- From: https://stackoverflow.com/a/7615129
function strsplit(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end

function LuuksPerms_CheckPermission(player_name)
    local result = {}
    result.rank = perms[player_name] or "Default"
    result.level = ranks[result.rank] or 0
    return result
end

function LuuksPerms_CheckPermissionID(player_id)
    return LuuksPerms_CheckPermission(MP.GetPlayerName(player_id))
end

local function LoadConfig()
    -- Create a default config file if it does not yet exist
    if not FS.IsFile(config_path) then
        print("Config file missing or somehow a directory! Recreating it...")
        if FS.Exists(config_path) then FS.Remove(config_path) end
        if FS.IsFile(config_path_dir_only) then FS.Remove(config_path_dir_only) end
        if not FS.Exists(config_path_dir_only) then FS.CreateDirectory(config_path_dir_only) end
        local file = io.open(config_path, "w")
        local empty_conf = {}

        empty_conf.ranks = {}
        empty_conf.perms = {}

        empty_conf.ranks["Default"] = 0
        empty_conf.ranks["Admin"] = 10
        empty_conf.perms["luuk-bepis"] = "Default"
        local json = Util.JsonEncode(empty_conf)
        file:write(json)
        file:close()
    end

    -- Load perms data from config file
    local file = io.open(config_path, "r")
    local json_str = file:read("*all")
    file:close()
    local json = Util.JsonDecode(json_str)
    if json == nil then
        print("Broken permissions file! Permissions will NOT work!")
        -- TODO: Add reminder in the beammp chat whenever anyone joins?
    else
        ranks = json.ranks
        perms = json.perms
    end
end

function FileChangedHandler(path)
    path = path:gsub("\\", "/")
    if path == config_path then
        print("Changed detected in permission config file, reloading...")
        LoadConfig()
    end
end

function InitHandler()
    LoadConfig()
end

function CommandHandler(sender_id, sender_name, message)
    local split = strsplit(message, " ")
    if split[1] == "/rank" then
        local name = split[2] or sender_name
        local rank_info = LuuksPerms_CheckPermission(name)
        MP.SendChatMessage(sender_id, name .. "'s rank: " .. rank_info.rank .. " (" .. tostring(rank_info.level) .. ")")
        return 1
    end
end

-- Register for global use, in case that's useful after BeamMP fixes the global event issues
MP.RegisterEvent("LuuksPerms_CheckPermission", "LuuksPerms_CheckPermission")
MP.RegisterEvent("LuuksPerms_CheckPermissionID", "LuuksPerms_CheckPermissionID")

MP.RegisterEvent("onInit", "InitHandler")
MP.RegisterEvent("onChatMessage", "CommandHandler")
MP.RegisterEvent("onFileChanged", "FileChangedHandler")
