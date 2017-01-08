require "unicode"
require "math"
require "string"
require "lib/lib_InterfaceOptions"
require "lib/lib_Slash"
require "lib/lib_ChatLib"

local CHAT_TAG = '[AGB]'
local CHAT_TAG_DEBUG = '[AGB DEBUGGER]'

local options = {
    keyname = 'value'
}


function OnComponentLoad(args)
    InterfaceOptions.SetCallbackFunc(OnOptionChange, 'Template')
    SetSlashEventHandlers()
end 

-- player loaded to zone
function OnPlayerReady(args)
end

-- Set callback for chat commands
function SetSlashEventHandlers()

    LIB_SLASH.BindCallback( { slash_list = "tmpl,template", description = "/template call the template", func = OnSlashHandler });
end

-- Callback function for slash command
function OnSlashHandler(args)

    local cmd = args[1] or nil
    -- handle cmd
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
    if key == 'keyname'  then
        options.keyname = value
    end
end