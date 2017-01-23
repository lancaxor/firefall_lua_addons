require "unicode"
require "math"
require "string"
require "lib/lib_InterfaceOptions"
require "lib/lib_Slash"
require "lib/lib_ChatLib"
require "lib/lib_Callback2"
require "lib/lib_Debug";

local CHAT_TAG = '[AGB]'
local CHAT_TAG_DEBUG = '[AGB DEBUGGER]'

local flagRestart = false
local flagReviewingSquad = false
local RestartCallback = {}       -- Callback2
local timeout = 60 -- seconds untill the bounty will be restarted
local player_afk = false

local OPTIONS = {
    active = false,
    autoStartOnLoad = false,
    debugMode = false,
    stopOnAfk = false,
    timeout = 300,
    restartByTimeout = true
}

local kickList = {}

function OnComponentLoad(args)
    InterfaceOptions.SetCallbackFunc(OnOptionChange, 'AutoGroupBounty')
    InterfaceOptions.AddCheckBox({id="active", label="Is Active", default=OPTIONS.active})
    InterfaceOptions.AddCheckBox({id="autoStartOnLoad", label="Start on player load", default=OPTIONS.autoStartOnLoad})
    InterfaceOptions.AddCheckBox({id="stopOnAfk", label="Pause if user is AFK", default=OPTIONS.stopOnAfk})
    InterfaceOptions.AddCheckBox({id="debugMode", label="Debug mode", default=OPTIONS.debugMode})
    InterfaceOptions.AddCheckBox({id="restartByTimeout", label="Restart By Timeout", default=OPTIONS.restartByTimeout})
    InterfaceOptions.AddSlider({id="timeout", max=600, min=10, inc=10, suffix="s", label="Number of request bounty try", default=OPTIONS.timeout})
    SetSlashEventHandlers()

    RestartCallback = Callback2.Create()
    RestartCallback:Bind(CallbackRestartGroupBounty)
end 

-- someone joined my squad
function OnSquadRosterUpdate(args)

    PrintDbg('Squad roster update...')
    if not OPTIONS.active then return end
    if flagReviewingSquad then return end
    flagReviewingSquad = true
    local myInfo = Player.GetInfo()
    Debug.Log('player info', myInfo)
    PrintDbg('Its active!...')

    if not Player.HasActiveGroupBounty() then -- kicked or smth like this
        PrintDbg('Squad roster update: restarting...')
        RestartGroupBounty()
        flagReviewingSquad = false
        return
    end
    Debug.Log('Before getting roster')
    local squadRoster = Squad.GetRoster()
    local squadLeader = Squad.GetLeader()
    Debug.Log('squad roster')
    Debug.Log(squadRoster)
    Debug.Log('squad leader')
    Debug.Log(squadLeader)
    -- check if I am leader
    -- get user nickname
    -- Squad.GetLeader
    -- Squad.Kick
    flagReviewingSquad = false
end

-- player's AFK status was changed
function OnAfkChanged(args)
    isAfk = args.isAfk
    if not OPTIONS.active or not OPTIONS.stopOnAfk then return end
    PrintDbg('User AFK status was changed to ' .. (isAfk and 'AFK' or 'NOT AFK'))
    player_afk = isAfk
    if isAfk then
        RestartCallback:Pause()
    else
        RestartCallback:Unpause()
        RestartCallback:Execute()
    end
end

-- player loaded to zone
function OnPlayerReady(args)
    if not OPTIONS.active then
        return
    end
    Debug.EnableLogging(OPTIONS.debugMode)
    Print(OPTIONS.active and 'Status: Running' or 'Status: Stopped')
    if OPTIONS.autoStartOnLoad then
        GetGroupBounty();
    end
end

--  join group bounty
function GetGroupBounty()

    if not OPTIONS.active then
        return
    end

    if Player.HasActiveGroupBounty() then
        PrintDbg('Has Active Bounty: ' .. tostring(hasActiveBounty))
        RestartGroupBounty()
        return
    end

    PrintDbg('Requesting bounty...')
    if OPTIONS.restartByTimeout then
        RestartCallback:Reschedule(OPTIONS.timeout)   -- RequestGroupBounty may be failed so we must use RestartCallback here, not in Callback
    end
    Player.RequestGroupBounty()
end

-- bounty was cancelled
function OnCancelGroupBounty(args)
    RestartCallback:Cancel()
    if flagRestart then
        flagRestart = false
        GetGroupBounty()
     end
end

-- bounty was aborted
function OnBountyAbort(args)
    PrintDbg('Aborting bounty...')
    OnCancelGroupBounty(args)
end

-- bounty was rerolled
function OnBountyReroll(args)
    PrintDbg('Rerolling bounty...')
    OnCancelGroupBounty(args)
end

-- cancel the bounty and start new one
function RestartGroupBounty()
    if Player.HasActiveGroupBounty() then
        flagRestart = true
        Player.CancelGroupBounty()
    else
        GetGroupBounty()
    end
end

-- restart group bounty by timeout
function CallbackRestartGroupBounty()
    PrintDbg('Restarting group bounty by callback')
    RestartGroupBounty()
end

-- Stop addon, cancel group bounty, leave bounty squad
function AbortAutoGroup()
    flagRestart = false
    OPTIONS.active = false
    if Player.HasActiveGroupBounty() then
        Player.CancelGroupBounty()
    end
end

-- player has left current squad
function OnBountyCompleted()

    if OPTIONS.active then
        if OPTIONS.stopOnAfk and player_afk then return end
        GetGroupBounty()
    end
end

-- Set callback for chat commands
function SetSlashEventHandlers()

    LIB_SLASH.BindCallback( { slash_list = "agb,autogroupbounty", description = "/agb [start|stop|restart|status|help]", func = OnSlashAgbHandler });
end

-- Callback function for slash command
function OnSlashAgbHandler(args)

    local cmd = args[1] or nil
    local cmdParam = args[2] or nil

    if 'status' == cmd then
        local addonStatus = (OPTIONS.active and 'Status: Running' or 'Status: Stopped')
        local bountyStatus = (Player.HasActiveGroupBounty() and 'has bounty' or 'has no bounty')
        Print(addonStatus .. '; ' .. bountyStatus)    -- cond ? ex1 : ex2 => cond and ex1 or ex2
    elseif 'start' == cmd then
        if OPTIONS.active then
            Print('AutoGroupBounty addon is already running!')
        else
            OPTIONS.active = true
            Print('AutoGroupBounty addon was started!')
        end
        GetGroupBounty()
    elseif 'stop' == cmd then
        if not OPTIONS.active then
            Print('AutoGroupBounty is already stopped!')
        else
            OPTIONS.active = false
            Print('AutoGroupBounty addon was stopped!')
        end
    elseif 'abort' == cmd then
        AbortAutoGroup()
        Print('AutoGroupBounty was aborted!')
    elseif 'restart' == cmd then
        Print('Restarting group bounty...')
        RestartGroupBounty()
    elseif 'kicklist' == cmd then   -- show the kicklist
        if #kickList == 0 then
            Print('AGB kicklist is empty')
        else
            local result = 'Players in kicklist:\n'
            for key, value in pairs(kickList) do
                result = result .. value .. '\n'
            end
            Print(result)
        end
    elseif 'kickadd' == cmd then    -- add player to kicklist
        table.insert(kickList, cmdParam)
        Print('Player ' .. cmdParam .. ' was added to AGB kicklist')
    elseif 'kickremove' == cmd then -- remove player from kicklist
        local removed = false
        for key, value in pairs(kickList) do
            if value == cmdParam then
                table.remove(kickList, key)
                removed = true
                break
            end
        end
        if removed then 
            Print('Player ' .. cmdParam .. ' was removed from AGB kicklist')
        else 
            Print('Player ' .. cmdParam .. ' was not found in AGB kicklist') 
        end
    else
        Print('Usage: /agb [start|stop|status|help]')
    end
end

-- Print debug message in system channel
function PrintDbg(message)
    if OPTIONS.debugMode then
        Component.GenerateEvent('MY_SYSTEM_MESSAGE', {text=CHAT_TAG_DEBUG .. ' ' .. message});
    end
end

-- Print message in system channel
function Print(message)
    Component.GenerateEvent('MY_SYSTEM_MESSAGE', {text=string.format('%s %s', CHAT_TAG, tostring(message))});
end

-- option was changed in settings
function OnOptionChange(key, value)
    if key == 'active'  then
        OPTIONS.active = value
    elseif key == 'debugMode' then
        OPTIONS.debugMode = value
    elseif key == 'autoStartOnLoad' then
        OPTIONS.autoStartOnLoad = value
    elseif key == 'stopOnAfk' then
        OPTIONS.stopOnAfk = value
    elseif key == 'timeout' then
        OPTIONS.timeout = tonumber(value)
    elseif key == 'restartByTimeout' then
        OPTIONS.restartByTimeout = value
    end
end