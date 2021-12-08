-------------------------------------------------------------------------------------------
------------------------------------ADVANCED CONFIGURATION------------------------------------
-------------------------------------------------------------------------------------------
-- In-Game Message (For Advanced Users)
function sendMessage(message, scope)
    TriggerClientEvent('chat:addMessage', scope, {    ----------------------------------------------------------------------------
           color = Config.messageColor,               --- Have a custom chat plugin? Want to change the text format of messages?
           multiline = true,                          --- Edit the TriggerClientEvent() function so it fits your needs!
           args = {"[StaffWatch] "..message}          ----------------------------------------------------------------------------
    })
end


-------------------------------------------------------------------------------------------
---------------DO NOT EDIT BELOW THIS LINE UNLESS YOU ARE A LEGIT DEVELOPER----------------
-------------------------------------------------------------------------------------------
local staffwatch = "https://beta.staffwatch.app"

--Player Connection
AddEventHandler("playerConnecting", function(name, setReason, deferrals)
    
    deferrals.defer()

    local identifiers = {}

    local identifiers_count = GetNumPlayerIdentifiers(source)
    for i = 0, identifiers_count - 1 do
        local splitArr = splitstring(GetPlayerIdentifier(source, i), ":")
        identifiers[splitArr[1]] = splitArr[2]
    end

    PerformHttpRequest(staffwatch .. '/api/playerJoin', function(err, res, headers)
        if (err and err ~= 201 and not res) then
            if (Config.systemFailureOverride) then
                print('Error occured while allowing a player to join, StaffWatch will allow the user to join anyway to prevent any issues.')
                print(err)
                deferrals.update("⚠️ StaffWatch failed to authenticate your connection! You will automatically join in 5 seconds, but server development should be contacted! ⚠️")
                Wait(5000)
                deferrals.done()
                return
            else
                deferrals.done("⚠️ Unable to connect to StaffWatch servers. Please try again later. ⚠️")
                return
            end
        end
        local data = json.decode(res)
        if not data.canJoin or data.banned then
            local message = [[
            ⚠️ You Are Banned From This Server ⚠️
            --------------------------------------
            📝 Reason: {reason}
            👻 Staff: {staff}
            ⏰ Expires: {expiration}
            --------------------------------------
            ⚙️ Banned Using StaffWatch.app
            --------------------------------------
            📞 Appeals: {appeals}
            ]]
            message = inputReplace(message, "reason", data.banReason)
            message = inputReplace(message, "expiration", data.banExpiration)
            message = inputReplace(message, "staff", data.staffName)
            message = inputReplace(message, "appeals", Config.appeal)
            deferrals.done(message)
            return
        end
        for x = 1, 6 do
            deferrals.update("Verifying User 💙")
            Wait(200)
            deferrals.update("Verifying User 🧡")
            Wait(200)
        end
        deferrals.update("Verified! You're ready to play! ✅")
        Wait(2000)
        deferrals.done()
    end, 'POST', json.encode({secret = Config.secret, name = GetPlayerName(source), identifiers = identifiers}), { ["Content-Type"] = 'application/json' })

end)

Citizen.CreateThread(function()
    while true do

        local players = {}

        -- Get All Players
        for _, playerId in ipairs(GetPlayers()) do

            local name = GetPlayerName(playerId)

            local steamid = nil
            local license = nil
            local discord = nil
            local xbl = nil
            local liveid = nil
            local ip = nil

            for k,v in pairs(GetPlayerIdentifiers(playerId))do
                if string.sub(v, 1, string.len("steam:")) == "steam:" then
                    steamid = splitstring(v, ":")[2]
                elseif string.sub(v, 1, string.len("license:")) == "license:" then
                    license = splitstring(v, ":")[2]
                elseif string.sub(v, 1, string.len("xbl:")) == "xbl:" then
                    xbl  = splitstring(v, ":")[2]
                elseif string.sub(v, 1, string.len("ip:")) == "ip:" then
                    ip = splitstring(v, ":")[2]
                elseif string.sub(v, 1, string.len("discord:")) == "discord:" then
                    discord = splitstring(v, ":")[2]
                elseif string.sub(v, 1, string.len("live:")) == "live:" then
                    liveid = splitstring(v, ":")[2]
                end
            end

            table.insert(players, {ingame_id = playerId, name = name, steamid = steamid, license = license, discord = discord, xbl = xbl, live = liveid, ip = ip})

        end
        
        -- Send to API
        PerformHttpRequest(staffwatch .. '/api/updateServer', function(err, res, headers)
            if err and err ~= 201 and not res then
                if err == 429 then
                    return
                else
                    print('-------------------------------')
                    print('Failed to send data  to API - Returned')
                    print(err)
                    print(res)
                    print('-------------------------------')
                end
            end

            local responseTable = json.decode(res)
	    if responseTable then
                for _, cmd in ipairs(responseTable.commandQueue) do
                    ExecuteCommand(cmd.command)
                end
	    end

        end, 'POST', json.encode({secret = Config.secret, data = players}), { ["Content-Type"] = 'application/json' })

        Wait(5000)
    end
end)

-- Commend Command
RegisterCommand('commend', function(source, args, rawCommand)
    remoteAction(source, args, rawCommand, 'commend')
end, false)

RegisterCommand('warn', function(source, args, rawCommand)
    remoteAction(source, args, rawCommand, 'warn')
end, false)

RegisterCommand('kick', function(source, args, rawCommand)
    remoteAction(source, args, rawCommand, 'kick')
end, false)

RegisterCommand('ban', function(source, args, rawCommand)
    remoteAction(source, args, rawCommand, 'ban')
end, false)

RegisterCommand('freeze', function(source, args, rawCommand)
    local isStaff = isStaff(source, function()
        local id = table.remove(args, 1)
        TriggerClientEvent('setFrozen', id, true)
        sendMessage('User frozen!', source)
    end)
end, false)

RegisterCommand('unfreeze', function(source, args, rawCommand)
    local isStaff = isStaff(source, function()
        local id = table.remove(args, 1)
        TriggerClientEvent('setFrozen', id, false)
        sendMessage('User unfrozen!', source)
    end)
end, false)

function isStaff(source, callback)
    local author = GetPlayerLicenseFromSource(source)
    PerformHttpRequest(staffwatch .. '/api/isStaff', function(err, res, headers)

        if res then
            if res == 'true' then
                callback()
                return
            else
                sendMessage('You do not permission to perform this action.', source)
                return
            end
        end

        if err then
            sendMessage('An unknown error occured. ' .. err, source)
        end

    end, 'POST', json.encode({
        secret = Config.secret,
        player_identifier = author
    }), { ["Content-Type"] = 'application/json' })
end

RegisterCommand('report', function(source, args, rawCommand)
    local reporting_player = GetPlayerLicenseFromSource(source)

    local id = table.remove(args, 1)
    if not id then
        sendMessage("You must provide a player ID!", source)
        return
    end
    local reported_player = GetPlayerLicenseFromSource(id)
    
    local reason = table.concat(args, " ")
    PerformHttpRequest(staffwatch .. '/api/reportPlayer', function(err, res, headers)

        if res then
            sendMessage(res, source)
            return
        end

        if err and err ~= 201 and err == 400 then
            sendMessage('Invalid arguments!', source)
            return
        end

        if err and err ~= 201 then
            sendMessage('An unknown error occured. ' .. err, source)
        else
            sendMessage('Report succesfully sent!', source)
        end

    end, 'POST', json.encode({
        secret = Config.secret,
        reporter_primary = reporting_player,
        reported_primary = reported_player,
        reason = reason,
    }), { ["Content-Type"] = 'application/json' })
end, false)

RegisterCommand('trustscore', function(source, args, rawCommand)
    local author = GetPlayerLicenseFromSource(source)
    PerformHttpRequest(staffwatch .. '/api/getTrust', function(err, res, headers)

        if res then
            sendMessage(res, source)
            return
        end

        if err then
            sendMessage('An unknown error occured. ' .. err, source)
        end

    end, 'POST', json.encode({
        secret = Config.secret,
        player_identifier = author
    }), { ["Content-Type"] = 'application/json' })
end, false)

function remoteAction(source, args, rawCommand, type)

    -- Get Provided ID
    local id = table.remove(args, 1)
    
    -- Require ID
    if not id then
        sendMessage('You must provide a valid ID and reason!', source)
        return
    end

    -- Declare Reason
    local reason = nil
    local duration = nil

    -- Special Ban Handling
    if type == 'ban' then
        local argString = table.concat(args, ' ')
        local combined = splitstring(argString, '?')
        reason = combined[1]
        duration = combined[2]
    else
        reason = table.concat(args, " ")
    end

    -- Send to API
    PerformHttpRequest(staffwatch .. '/api/remoteAction', function(err, res, headers)

        if res then
            sendMessage(res, source)
            return
        end

        if err and err ~= 201 and err == 400 then
            sendMessage('Invalid arguments!', source)
            return
        end

        if err and err ~= 201 and err == 403 then
            sendMessage('Invalid permissions, check that you have claimed a player on the panel!', source)
            return
        end

        if err and err ~= 201 and err ~= 201 then
            sendMessage('An unknown error occured. ' .. err, source)
        else
            sendMessage('Action succesful!', source)
        end

    end, 'POST', json.encode({
        key = 'license',
        type = type,
        secret = Config.secret,
        staff = GetPlayerLicenseFromSource(source),
        player = GetPlayerLicenseFromSource(id),
        reason = reason,
        duration = duration
    }), { ["Content-Type"] = 'application/json' })

end


RegisterServerEvent('checkStaffStatus')
AddEventHandler('checkStaffStatus', function()
    local playerSrc = source
    PerformHttpRequest(staffwatch .. '/api/isStaff', function(err, res, headers)
        if res == 'true' then
            TriggerClientEvent('setAsStaff', playerSrc, true)
        else
            TriggerClientEvent('setAsStaff', playerSrc, false)
        end
    end, 'POST', json.encode({
        secret = Config.secret,
        player_identifier = GetPlayerLicenseFromSource(playerSrc)
    }), { ["Content-Type"] = 'application/json' })
end)


-- RCON Announce
RegisterCommand("rcon_announce", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local message = table.concat(args, " ")
        sendMessage(message, -1)
    end
end, false)

-- RCON Report
RegisterCommand("rcon_report", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local message = table.concat(args, " ")
        TriggerClientEvent('sendReportToChat', -1, message)
    end
end, false)

-- RCON Commend User
RegisterCommand("rcon_commend", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local id = GetPlayerIDFromLicense(table.remove(args, 1))
        local name = GetPlayerName(id)
        local reason = table.concat(args, " ")
        sendMessage(name .. " (" .. id .. ") has been commended for " .. reason, -1)
        TriggerClientEvent('displayStaffMsg', id, '~g~You were commended for: ' .. reason)
    end
end, false)

-- RCON Warn User
RegisterCommand("rcon_warn", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local id = GetPlayerIDFromLicense(table.remove(args, 1))
        local name = GetPlayerName(id)
        local reason = table.concat(args, " ")
        sendMessage(name .. " (" .. id .. ") has been warned for " .. reason, -1)
        TriggerClientEvent('displayStaffMsg', id, 'You were warned for: ' .. reason)
    end
end, false)

-- RCON Kick User
RegisterCommand("rcon_kick", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local id = GetPlayerIDFromLicense(table.remove(args, 1))
        local name = GetPlayerName(id)
        local reason = table.concat(args, " ")
        DropPlayer(id, 'You have been kicked for: ' .. reason)
        sendMessage(name .. " (" .. id .. ") has been kicked for " .. reason, -1)
    end
end, false)

-- RCON Ban User
RegisterCommand("rcon_ban", function(source, args, rawCommand)
    if source == 0 or source == "console" then
        local id = GetPlayerIDFromLicense(table.remove(args, 1))
        local name = GetPlayerName(id)
        local reason = table.concat(args, " ")
        DropPlayer(id, 'You have been banned for: ' .. reason .. ' (Reconnect for additional information)')
        sendMessage(name .. " (" .. id .. ") has been banned for " .. reason, -1)
    end
end, false)

-- Logging System
RegisterNetEvent('staffwatch:logData')
AddEventHandler('staffwatch:logData', function(event_name, event_content)
    event_content = '<a href="/redirect-player?type=license&value=' .. GetPlayerLicenseFromSource(source) .. '">' .. GetPlayerName(source) .. '</a> (' .. source .. '): ' .. event_content
    PerformHttpRequest(staffwatch .. '/api/log', function(err, res, headers)
        if res then
            sendMessage(res, source)
            return
        end
        if err and err ~= 201 then
            print('Unable to send log to StaffWatch')
        end
    end, 'POST', json.encode({secret = Config.secret, event_name = event_name, event_content = event_content}), { ["Content-Type"] = 'application/json' })
end)

RegisterNetEvent('staffwatch:logDirect')
AddEventHandler('staffwatch:logDirect', function(event_name, event_content)
    PerformHttpRequest(staffwatch .. '/api/log', function(err, res, headers)
        if res then
            sendMessage(res, source)
            return
        end
        if err and err ~= 201 then
            print('Unable to send log to StaffWatch')
        end
    end, 'POST', json.encode({secret = Config.secret, event_name = event_name, event_content = event_content}), { ["Content-Type"] = 'application/json' })
end)

-- Player Join Logs
AddEventHandler('playerConnecting', function()
	TriggerEvent('staffwatch:logDirect', 'event', HighlightableLink(source)..' joined the server')
end)

-- Player Leave Logs
AddEventHandler('playerDropped', function()
	TriggerEvent('staffwatch:logDirect', 'event', HighlightableLink(source)..' left the server')
end)

-- Player Death
RegisterServerEvent('playerDied')
AddEventHandler('playerDied',function(message)
    TriggerEvent('staffwatch:logDirect', 'event', HighlightableLink(source) .. message)
end)

RegisterServerEvent('playerDiedFromPlayer')
AddEventHandler('playerDiedFromPlayer',function(message, killer_id)
    TriggerEvent('staffwatch:logDirect', 'event', HighlightableLink(killer_id) .. message .. HighlightableLink(source))
end)

-- Explosion Logging
local explosions = {}
explosions[1] = 'EXPLOSION_GRENADE'
explosions[2] = 'EXPLOSION_GRENADELAUNCHER'
explosions[3] = 'EXPLOSION_STICKYBOMB'
explosions[4] = 'EXPLOSION_MOLOTOV'
explosions[5] = 'EXPLOSION_ROCKET'
explosions[6] = 'EXPLOSION_TANKSHELL'
explosions[7] = 'EXPLOSION_HI_OCTANE'
explosions[8] = 'EXPLOSION_CAR'
explosions[9] = 'EXPLOSION_PLANE'
explosions[10] = 'EXPLOSION_PETROL_PUMP'
explosions[11] = 'EXPLOSION_BIKE'
explosions[12] = 'EXPLOSION_DIR_STEAM'
explosions[13] = 'EXPLOSION_DIR_FLAME'
explosions[14] = 'EXPLOSION_DIR_WATER_HYDRANT'
explosions[15] = 'EXPLOSION_DIR_GAS_CANISTER'
explosions[16] = 'EXPLOSION_BOAT'
explosions[17] = 'EXPLOSION_SHIP_DESTROY'
explosions[18] = 'EXPLOSION_TRUCK'
explosions[19] = 'EXPLOSION_BULLET'
explosions[20] = 'EXPLOSION_SMOKEGRENADELAUNCHER'
explosions[21] = 'EXPLOSION_SMOKEGRENADE'
explosions[22] = 'EXPLOSION_BZGAS'
explosions[23] = 'EXPLOSION_FLARE'
explosions[24] = 'EXPLOSION_GAS_CANISTER'
explosions[25] = 'EXPLOSION_EXTINGUISHER'
explosions[26] = 'EXPLOSION_PROGRAMMABLEAR'
explosions[27] = 'EXPLOSION_TRAIN'
explosions[28] = 'EXPLOSION_BARREL'
explosions[29] = 'EXPLOSION_PROPANE'
explosions[30] = 'EXPLOSION_BLIMP'
explosions[31] = 'EXPLOSION_DIR_FLAME_EXPLODE'
explosions[32] = 'EXPLOSION_TANKER'
explosions[33] = 'EXPLOSION_PLANE_ROCKET'
explosions[34] = 'EXPLOSION_VEHICLE_BULLET'
explosions[35] = 'EXPLOSION_GAS_TANK'
explosions[36] = 'EXPLOSION_BIRD_CRAP'

AddEventHandler("explosionEvent", function(sender, ev)
    local type = ev["explosionType"]
    if type == 0 then
        return
    end
    TriggerEvent('staffwatch:logDirect', 'event', HighlightableLink(sender) .. ' caused an explosion ('..explosions[type]..').')
end)

-- Required Functions
function HighlightableLink(source)
    return '<a href = "/redirect-player?type=license&value='..GetPlayerLicenseFromSource(source)..'">'..GetPlayerName(source)..'</a>'
end

function inputReplace(message, hint, content)
    return message:gsub("{" .. hint .. "}", content)
end

function GetPlayerIDFromLicense(license)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local playerLicense = nil
        for k,v in pairs(GetPlayerIdentifiers(playerId)) do
            if string.sub(v, 1, string.len("license:")) == "license:" then
                playerLicense = splitstring(v, ":")[2]
            end
        end
        if playerLicense == license then
            return playerId
        end
    end
    return nil
end

function GetPlayerLicenseFromID(searchingPlayer)
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        if playerId == searchingPlayer then
            print('Player found, finding license')
            local playerLicense = nil
            for k,v in pairs(GetPlayerIdentifiers(playerId)) do
                if string.sub(v, 1, string.len("license:")) == "license:" then
                    playerLicense = splitstring(v, ":")[2]
                end
            end
            print(playerLicense)
            return playerLicense
        end
    end
    return nil
end

function GetPlayerLicenseFromSource(source)
    local playerLicense = nil
    for k,v in pairs(GetPlayerIdentifiers(source)) do
        if string.sub(v, 1, string.len("license:")) == "license:" then
            playerLicense = splitstring(v, ":")[2]
        end
    end
    return playerLicense
end

function splitstring(str, delim)
    local t = {}

    for substr in string.gmatch(str, "[^".. delim.. "]*") do
        if substr ~= nil and string.len(substr) > 0 then
            table.insert(t,substr)
        end
    end

    return t
end

function urlencode(str)
    if (str) then
        str = string.gsub(str, "\n", "\r\n")
        str =
            string.gsub(
            str,
            "([^%w ])",
            function(c)
                return string.format("%%%02X", string.byte(c))
            end
        )
        str = string.gsub(str, " ", "+")
    end
    return str
end
