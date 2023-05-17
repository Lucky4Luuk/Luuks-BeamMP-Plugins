local print_edits = true

local vehicle_data = {}

-- From: https://stackoverflow.com/a/24622157
function table_diff(a, b)
    local ret = {}

    for ak, av in pairs(a) do
        for bk, bv in pairs(b) do
            if ak == bk then
                -- We have found one to compare!
                if type(av) ~= type(bv) then
                    ret[bk] = bv
                else
                    if type(bv) == "table" then
                        ret[bk] = table_diff(av, bv)
                    else
                        if av ~= bv then
                            ret[bk] = bv
                        end
                    end
                end
            end
        end
    end

    return ret
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

function combine_strings(t, join)
    local s = ""
    local join = join or ""
    for i, str in ipairs(t) do
        s = s .. str
        if i < #t then s = s .. join end
    end
    return s
end

function VehicleSpawnHandler(player_id, vehicle_id, data)
    local split_data = strsplit(data, ":")
    local tmp = {}
    for i=4,#split_data do
        table.insert(tmp, split_data[i])
    end
    data = combine_strings(tmp, ":")

    vehicle_data[player_id] = vehicle_data[player_id] or {} -- Create if it doesn't yet exist
    vehicle_data[player_id][vehicle_id] = Util.JsonDecode(data)
end

function VehicleEditHandler(player_id, vehicle_id, new)
    local split_data = strsplit(new, ":")
    local tmp = {}
    for i=2,#split_data do
        table.insert(tmp, split_data[i])
    end
    new = combine_strings(tmp, ":")
    new = Util.JsonDecode(new)

    local old = vehicle_data[player_id][vehicle_id]
    local diff = table_diff(old, new)
    vehicle_data[player_id][vehicle_id] = new
    local pname = MP.GetPlayerName(player_id)
    MP.SendChatMessage(-1, pname .. "'s changes: " .. dump(diff))
end

function VehicleDeleteHandler(player_id, vehicle_id)
    vehicle_data[player_id][vehicle_id] = nil
end

function CommandHandler(sender_id, sender_name, message)
    if message == "/toggle_edit_messages" then
        local fut = MP.TriggerGlobalEvent("LuuksPerms_CheckPermission", sender_name)
        while not fut:IsDone() do
            MP.Sleep(100)
        end
        local results = fut:GetResults()
        for k, v in pairs(results) do results[k] = Util.JsonDecode(Util.JsonEncode(v)) end
        local rank_info = results[1]
        print(rank_info)
        for k, v in pairs(rank_info) do print(k .. ": " .. v) end
        print(rank_info.level)
        print(rank_info["level"])
        if rank_info.level > 2 then
            print_edits = not print_edits
            local status = "disabled"
            if print_edits then status = "enabled" end
            MP.SendChatMessage(sender_id, "Edit messages are now " .. status .. "!")
        else
            MP.SendChatMessage(sender_id, "You are not allowed to run this command!")
        end
        return 1
    end
end

MP.RegisterEvent("onVehicleSpawn", "VehicleSpawnHandler")
MP.RegisterEvent("onVehicleEdited", "VehicleEditHandler")
MP.RegisterEvent("onVehicleDeleted", "VehicleDeleteHandler")
MP.RegisterEvent("onChatMessage", "CommandHandler")
