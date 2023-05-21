-- A simple command framework. Supports my permission plugin (if installed)
-- and makes it much easier to support custom chat commands.

local command_handlers = {}
local luuks_perms_installed = false

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

-- From: https://stackoverflow.com/a/22831842
function starts_with(String,Start)
   return string.sub(String,1,string.len(Start))==Start
end

-- From: https://stackoverflow.com/a/27028488
function dump(o)
    if type(o) == 'table' then
        local s = '{ '
        for k,v in pairs(o) do
            if type(k) ~= 'number' then k = '"'..k..'"' end
            s = s .. '['..k..'] = ' .. dump(v) .. ','
        end
        return s .. '} '
    else
        return tostring(o)
    end
end

local function GetRankInfo(sender_name)
    if not luuks_perms_installed then
        local t = {}
        t.level = 0
        t.rank = "Default"
        return t
    end

    print(sender_name)

    local results = LuuksPerms_CheckPermission(sender_name)
    print(results)
    return results
end

-- Expects a table with the following format:
-- cmd_data.cmd_name = "cmd_name"       -- The command name. /cmd_name triggers the command!
-- cmd_data.event_name = "event_name"   -- The event to call to trigger the command handler
-- cmd_data.perm_level = 0              -- The permission level needed for the command (defaults to 0)
--
-- Commands get the following input:
-- data.sender_id = sender_id           -- Senders ID
-- data.sender_name = "sender_name"     -- Senders name
-- data.sender_rank.level = perm_level  -- Permission level of senders rank
-- data.sender_rank.rank = "rank_name"  -- Display name of senders rank
-- data.args = {"one", "two", "three"}  -- List of arguments passed to the function
--
-- NOTE: If used from another plugin that doesn't share the state, please be aware of
--       https://github.com/BeamMP/BeamMP-Server/issues/182
function RegisterCommandHandler(cmd_data)
    local cmd_name = cmd_data.cmd_name
    if cmd_name == nil then
        print("A plugin tried registering a command with no name!\nCommand data: " .. dump(cmd_data))
    end
    local event_name = cmd_data.event_name
    if event_name == nil then
        print("A plugin tried registering a command with no event name!\nCommand data: " .. dump(cmd_data))
    end
    local cmd_perm_level = cmd_data.perm_level or 0 -- Defaults to 0

    command_handlers[cmd_name] = cmd_data
end

function ChatMessageHandler(sender_id, sender_name, message)
    local rank_info = GetRankInfo(sender_name)
    print(rank_info)

    if starts_with(message, "/") then
        message = string.sub(message,2,string.len(message))
        local split = strsplit(message, " ")
        local cmd = split[1]
        local args = {}
        if #split > 1 then
            for i=2,#split do table.insert(args, split[i]) end
        end

        local cmd_data = command_handlers[cmd]
        if cmd_data == nil then
            MP.SendChatMessage(sender_id, "Unknown command!")
        else
            if rank_info.level >= cmd_data.perm_level then
                local cmd_args = {}
                cmd_args.sender_id = sender_id
                cmd_args.sender_name = sender_name
                cmd_args.sender_rank = rank_info
                cmd_args.args = args
                print(cmd_data)
                MP.TriggerLocalEvent(cmd_data.event_name, cmd_args)
            else
                MP.SendChatMessage(sender_id, "You do not have permission to run this command!")
            end
        end

        return 1
    end
    return 0
end

function InitHandler()
    luuks_perms_installed = DepIsInstalled("luuks_permissions")

    if not luuks_perms_installed then
        print("Luuks perms is not installed! Permission level will default to 0 for security.")
    end

    local cmd_data = {}
    cmd_data.cmd_name = "commands"
    cmd_data.event_name = "ListCommandHandlersCommand"
    cmd_data.perm_level = 0
    RegisterCommandHandler(cmd_data)
end

function ListCommandHandlersCommand(data)
    MP.SendChatMessage(data.sender_id, "TODO")
end

MP.RegisterEvent("onInit", "InitHandler")
MP.RegisterEvent("onChatMessage", "ChatMessageHandler")

MP.RegisterEvent("RegisterCommandHandler", "RegisterCommandHandler")

-- Custom commands
MP.RegisterEvent("ListCommandHandlersCommand", "ListCommandHandlersCommand")
