
-- ------------------------------------------
-- lib_WebMessage
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
	The WebMessageHandler receives all the messages that come in via ON_WEB_MESSAGE_RECEIVED
	This lib allows components to be looped in on any message types that it cares about
--]]

WebMessage = {} --table of Global functions

--require "unicode"
--require "math"
--require "table"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lf = {} --table of local functions
local lcb = {} --table of Liaison Callback Functions

local c_ComponentName

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_LiaisonCallbacks = {}

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function WebMessage.Register(message_type, func)
	assert(type(message_type) == "string", "WebMessage.Register requires param1 to be a string")
	assert(type(func) == "function", "WebMessage.Register requires param2 to be a function")
	g_LiaisonCallbacks[message_type] = func
	Liaison.RemoteCall("WebMessageHandler", "RegisterWebMessage", message_type, lf.GetComponentName())
end

function WebMessage.Unregister(message_type)
	assert(type(message_type) == "string", "WebMessage.Unregister requires param1 to be a string")
	if g_LiaisonCallbacks[message_type] then
		g_LiaisonCallbacks[message_type] = nil
		Liaison.RemoteCall("WebMessageHandler", "UnregisterWebMessage", message_type, lf.GetComponentName())
	else
		warn("message_type is not currently registered")
	end
end

-- ------------------------------------------
-- LIAISON CALLBACK FUNCTIONS
-- ------------------------------------------
function lcb.OnWebMessage(args)
	if g_LiaisonCallbacks[args.message_type] then
		g_LiaisonCallbacks[args.message_type](args)
	end
end
Liaison.BindCallTable(lcb)

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.GetComponentName()
	if not c_ComponentName then
		c_ComponentName = Component.GetInfo()
	end
	return c_ComponentName
end

-- ------------------------------------------
-- UTILITY/RETURN FUNCTIONS
-- ------------------------------------------
