-- Simple server-sided replay recorder, to be used with my custom replay viewer.
-- NOTE: Do NOT use right now! It keeps track of ALL events and keeps writing them ALL to a file.
--       This might result in poor server performance!
-- TODO: Append latest changes to replay file instead of writing them all at once.
-- TODO: Track onVehicleReset.
-- TODO: Support /marker to add Marker events, so the RC can easily go back to something they marked.

local is_recording = false
local replay_ms = 40 -- 40ms between replay ticks = 25fps replay

local RS = {}
RS.players = {}
RS.vehicles = {}
RS.timer = MP.CreateTimer()
RS.flush_timer = MP.CreateTimer()
RS.events = {}

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

function CreateReplayEvent(kind, player_id, vehicle_id, data)
    local event = {}
    event.time = RS.timer:GetCurrent()
    event.kind = kind
    event.player_id = player_id
    event.vehicle_id = vehicle_id
    event.data = data
    return event
end

-- First gathers needed information, like connected players, then starts the
-- event timer that records the replay.
function StartRecording()
    -- Remove any existing replay
    if FS.Exists("ReplayPlugin/latest.rpl") then
        FS.Remove("ReplayPlugin/latest.rpl")
    end

    -- Restart all timers
    RS.timer = MP.CreateTimer()
    RS.flush_timer = MP.CreateTimer()

    -- Reset the event list
    RS.events = {}

    -- Enable recording flag
    is_recording = true

    -- Collect initial information on players and vehicles spawned
    local players = MP.GetPlayers()
    for id, name in pairs(players) do
        PlayerJoinHandler(id)
        RS.vehicles[id] = {}
        local vehicles = MP.GetPlayerVehicles(id) or {}
        for vid, veh_data in pairs(vehicles) do
            -- Push the vehicle spawn event to the event buffer
            VehicleSpawnHandler(id, vid, veh_data)
        end
    end

    MP.CreateEventTimer("ReplayTick", replay_ms)
end

-- Simply cancels the event timer that records the replay and updates the state
-- to reflect this
function StopRecording()
    print("replay ended")
    FlushReplay()
    -- Cancel event timer and update state to reflect this
    is_recording = false
    MP.CancelEventTimer("ReplayTick")

    local new_name = "ReplayPlugin/replay-"..os.date("%Y-%b-%d_%H-%M-%S")..".rpl"
    os.rename("ReplayPlugin/latest.rpl", new_name)
    MP.SendChatMessage(-1, "Replay saved as " .. new_name)
end

function ReplayCommandHandler(sender_id, sender_name, message)
    local fut = MP.TriggerGlobalEvent("LuuksPerms_CheckPermission", sender_name)
    while not fut:IsDone() do
        MP.Sleep(100)
    end
    local results = fut:GetResults()
    for k, v in pairs(results) do results[k] = Util.JsonDecode(Util.JsonEncode(v)) end
    local rank_info = results[1]
    if rank_info.level > 2 then
        if message == "/startreplay" then
            if is_recording then
                MP.SendChatMessage(sender_id, "Replay has already been started!")
            else
                MP.SendChatMessage(-1, "Replay started by " .. sender_name)
                StartRecording()
            end
            return 1
        elseif message == "/stopreplay" then
            if is_recording then
                MP.SendChatMessage(-1, "Replay stopped by " .. sender_name)
                StopRecording()
            else
                MP.SendChatMessage(sender_id, "Replay wasn't started!")
            end
            return 1
        end
    end
    return 0
end

-- TODO: Every x ticks, save the data to a file
function ReplayTick()
    for player_id, vehicles in pairs(RS.vehicles) do
        for vehicle_id, vehicle_data in pairs(vehicles) do
            local raw_pos = MP.GetPositionRaw(player_id, vehicle_id)
            if raw_pos ~= nil then
                raw_pos.tim = nil
                local event = CreateReplayEvent("EVENT_VEH_POS", player_id, vehicle_id, raw_pos)
                table.insert(RS.events, event)
            end
        end
    end

    if RS.flush_timer:GetCurrent() > 15 then
        RS.flush_timer = MP.CreateTimer()
        FlushReplay()
    end
end

-- Flushes the latest replay information to a file
-- TODO: Append to the file instead, so we only write the new events.
--       There's a lot of lagspikes in the replays right now, very bad.
function FlushReplay()
    local json = Util.JsonEncode(RS.events)
    local file = io.open("ReplayPlugin/latest.rpl", "w")
    file:write(json)
    file:close()
end

-- Handles vehicle spawns
function VehicleSpawnHandler(player_id, vehicle_id, data)
    if not is_recording then return 0 end
    print("vehicle spawned")

    -- Push the vehicle spawn event to the event buffer
    local split_data = strsplit(data, ":")
    local tmp = {}
    for i=4,#split_data do
        table.insert(tmp, split_data[i])
    end
    local json_data = combine_strings(tmp, ":")
    local decoded = Util.JsonDecode(json_data)
    local event = CreateReplayEvent("EVENT_VEH_SPAWN", player_id, vehicle_id, decoded)
    table.insert(RS.events, event)

    local modified = decoded
    modified.pos = nil
    modified.rot = nil

    local vehicles = RS.vehicles[player_id] or {}
    vehicles[vehicle_id] = Util.JsonEncode(modified)
    RS.vehicles[player_id] = vehicles

    -- Trigger a client event to tell us the size of a specific vehicle
    local success = MP.TriggerClientEvent(player_id, "LUtil_GetVehicleSize", tostring(player_id).."-"..tostring(vehicle_id))
    if not success then
        MP.SendChatMessage(-1, "wah?")
    end

    return 0 -- Don't cancel
end

-- Handles vehicle edits
function VehicleEditHandler(player_id, vehicle_id, edit)
    if not is_recording then return 0 end
    print("vehicle edited")

    print(edit)
    local split_data = strsplit(edit, ":")
    local tmp = {}
    for i=2,#split_data do
        table.insert(tmp, split_data[i])
    end
    local json_data = combine_strings(tmp, ":")
    local decoded = Util.JsonDecode(json_data)
    local event = CreateReplayEvent("EVENT_VEH_EDIT", player_id, vehicle_id, decoded)
    table.insert(RS.events, event)

    local vehicles = RS.vehicles[player_id] or {}
    local current = vehicles[vehicle_id]
    local new = Util.JsonDiff(current, json_data)
    vehicles[vehicle_id] = Util.JsonDecode(json_data)
    RS.vehicles[player_id] = vehicles

    return 0 -- Don't cancel
end

-- Handles vehicle deletion
function VehicleDeleteHandler(player_id, vehicle_id)
    if not is_recording then return 0 end
    print("vehicle deleted")

    local event = CreateReplayEvent("EVENT_VEH_DEL", player_id, vehicle_id, nil)
    table.insert(RS.events, event)

    local vehicles = RS.vehicles[player_id] or {}
    vehicles[vehicle_id] = nil
    RS.vehicles[player_id] = vehicles
end

function VehicleSizeHandler(player_id, data)
    if not is_recording then return 0 end
    print("vehicle size")
    print(data)
    local split = strsplit(data, "-")
    local pid = tonumber(split[1])
    local vid = tonumber(split[2])
    local width = tonumber(split[3])
    local height = tonumber(split[4])
    local data = {}
    data.width = width
    data.height = height
    local event = CreateReplayEvent("EVENT_VEH_SIZE", pid, vid, data)
    table.insert(RS.events, event)
end

-- Handles player joining
function PlayerJoinHandler(player_id)
    local name = MP.GetPlayerName(player_id)
    local data = {}
    data.name = name
    local event = CreateReplayEvent("EVENT_PLAYER_JOIN", player_id, nil, data)
    table.insert(RS.events, event)

    RS.players[player_id] = name
end

-- Handles player leaving
function PlayerLeaveHandler(player_id)
    local event = CreateReplayEvent("EVENT_PLAYER_LEAVE", player_id, nil, nil)
    table.insert(RS.events, event)

    RS.players[player_id] = nil
end

-- Runs upon plugin initialization
function Startup()
    if not FS.IsDirectory("ReplayPlugin") then
        if FS.Exists("ReplayPlugin") then
            FS.Remove("ReplayPlugin")
        end
        FS.CreateDirectory("ReplayPlugin")
    end
end

-- Register all handler events used by the replay system
MP.RegisterEvent("onVehicleSpawn", "VehicleSpawnHandler")
MP.RegisterEvent("onVehicleEdited", "VehicleEditHandler")
MP.RegisterEvent("onVehicleDeleted", "VehicleDeleteHandler")
MP.RegisterEvent("LUtil_OnVehicleSize", "VehicleSizeHandler")

MP.RegisterEvent("onPlayerJoining", "PlayerJoinHandler")
MP.RegisterEvent("onPlayerDisconnect", "PlayerLeaveHandler")

-- Register other events, also used by the replay system
MP.RegisterEvent("ReplayTick", "ReplayTick")
MP.RegisterEvent("onChatMessage", "ReplayCommandHandler")
MP.RegisterEvent("onInit", "Startup")
