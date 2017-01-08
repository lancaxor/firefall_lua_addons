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
local flagInited = false
local RestartCallback = {}       -- Callback2
local timeout = 60 -- seconds untill the bounty will be restarted

local options = {
    active = false,
    autoStartOnLoad = false,
    debugMode = false,
    timeout = 300,
    restartByTimeout = true
}

function OnComponentLoad(args)
    InterfaceOptions.SetCallbackFunc(OnOptionChange, 'AutoGroupBounty')
    InterfaceOptions.AddCheckBox({id="active", label="Is Active", default=options.active})
    InterfaceOptions.AddCheckBox({id="autoStartOnLoad", label="Start on player load", default=options.autoStartOnLoad})
    InterfaceOptions.AddCheckBox({id="debugMode", label="Debug mode", default=options.debugMode})
    InterfaceOptions.AddCheckBox({id="restartByTimeout", label="Restart By Timeout", default=options.restartByTimeout})
    InterfaceOptions.AddSlider({id="timeout", max=600, min=10, inc=10, suffix="s", label="Number of request bounty try", default=options.timeout})
    SetSlashEventHandlers()

    RestartCallback = Callback2.Create()
    RestartCallback:Bind(CallbackRestartGroupBounty)
end 

-- player loaded to zone
function OnPlayerReady(args)
    if not options.active then
        return
    end
    Debug.EnableLogging(options.debugMode)
    init(true)
    Print(options.active and 'Status: Running' or 'Status: Stopped')
    if options.autoStartOnLoad then
        GetGroupBounty();
    end
end

function init(force)
--[[
    if not force or flagInited then return end

    RestartCallback = Callback2.Create()
    RestartCallback:Release()
    RestartCallback:Bind(CallbackRestartGroupBounty)
--]]
    flagInited = true
end

--  join group bounty
function GetGroupBounty()

    if not options.active then
        return
    end

    if Player.HasActiveGroupBounty() then
        PrintDbg('Has Active Bounty: ' .. tostring(hasActiveBounty))
        RestartGroupBounty()
        return
    end

    PrintDbg('Requesting bounty...')
    if options.restartByTimeout then
        Debug.Log('RestartCallback:')
        Debug.Log(RestartCallback)
        RestartCallback:Reschedule(options.timeout)   -- RequestGroupBounty may be failed so we must use RestartCallback here, not in Callback
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
    options.active = false
    if Player.HasActiveGroupBounty() then
        Player.CancelGroupBounty()
    end
end

-- player has left current squad
function OnBountyCompleted()
    if options.active then
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

    if 'status' == cmd then
        local addonStatus = (options.active and 'Status: Running' or 'Status: Stopped')
        local bountyStatus = (Player.HasActiveGroupBounty() and 'has bounty' or 'has no bounty')
        Print(addonStatus .. '; ' .. bountyStatus)    -- cond ? ex1 : ex2 => cond and ex1 or ex2
    elseif 'start' == cmd then
        if options.active then
            Print('AutoGroupBounty addon is already running!')
        else
            options.active = true
            init(true)
            Print('AutoGroupBounty addon was started!')
        end
        GetGroupBounty()
    elseif 'stop' == cmd then
        if not options.active then
            Print('AutoGroupBounty is already stopped!')
        else
            options.active = false
            Print('AutoGroupBounty addon was stopped!')
        end
    elseif 'abort' == cmd then
        AbortAutoGroup()
        Print('AutoGroupBounty was aborted!')
    elseif 'restart' == cmd then
        Print('Restarting group bounty...')
        RestartGroupBounty()
    else
        Print('Usage: /agb [start|stop|status|help]')
    end
end

-- Print debug message in system channel
function PrintDbg(message)
    if options.debugMode then
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
        options.active = value
    elseif key == 'debugMode' then
        options.debugMode = value
    elseif key == 'autoStartOnLoad' then
        options.autoStartOnLoad = value
    elseif key == 'timeout' then
        options.timeout = tonumber(value)
    elseif key == 'restartByTimeout' then
        options.restartByTimeout = value
    end
end