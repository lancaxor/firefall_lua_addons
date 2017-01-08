require "unicode"
require "math"
require "string"
require "table"
require "lib/lib_InterfaceOptions"
require "lib/lib_Slash"
require "lib/lib_ChatLib"

local CHAT_TAG = '[API]'
local CHAT_TAG_DEBUG = '[API DEBUGGER]'

local options = {
    keyname = 'value'
}


function OnComponentLoad(args)
    SetSlashEventHandlers()
end 


-- Set callback for chat commands
function SetSlashEventHandlers()

    LIB_SLASH.BindCallback( { slash_list = "api", description = "/api save", func = OnSlashHandler });
end

-- Callback function for slash command
function OnSlashHandler(args)

    LoadGlobals();
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

---------------------------------------------------

local seen={}
local globalVars = {}
local globalVarsList = {}
local currentVarData = ''

-- variable name, text
function dump(itemName,i)
    seen[itemName]=true
    local s={}
    local n=0
    for k in pairs(itemName) do
        n=n+1 s[n]=k
    end
    table.sort(s)
    for k,v in ipairs(s) do
        --print(i,v)
        save(tostring(i), tostring(v))
        v=itemName[v]
        if type(v)=="table" and not seen[v] then
            dump(v,i.."\t")
        end
    end
end

function LoadGlobals()
    Print("Loading...");
    -- dump(_G,'');
    for key, value in pairs(_G) do
        dump(value, '')
        globalVars[key] = currentVarData
        currentVarData = ''
    end

    outRow()
--    local url = 'http://echodata.loc/?data=' .. finalData.. '&tag=api_data&group=firefall_vars'
--    HTTP.IssueRequest(url, "GET", nil, function(arg, err) end)
    Print("Loaded!");
end

function outRow() 
    local key, data= next(globalVars)
    if key == nil then
        return
    end

    local url = 'http://echodata.loc/?data=' .. finalData.. '&tag=' .. key .. '&group=firefall_vars'
    HTTP.IssueRequest(url, "GET", nil, function(arg, err)
        outRow()
    end)
end

function save(prefix, data)
    currentVarData = currentVarData.. prefix .. data .. '\n'
    -- local url = 'http://echodata.loc/?data=' .. data .. '&tag=' .. container .. '&group=firefall_vars'
    -- HTTP.IssueRequest(url, "GET", nil, function(arg, err) 
    --end);
end