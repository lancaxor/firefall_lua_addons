
-- ------------------------------------------
-- lib_Debug
--   by: Brian Blose
-- ------------------------------------------

--[[Note to Addon Authors
This lib is design to supply an array of tools for debugging use that can be easily disable to reduce console spam and unneeded process time.
You can make an option for your addon to enable/disable a debug mode for your addon to allow other users to turn it on to help with bug fixing.

If you have any ideas for additional debug functions that you believe could be useful, make a request on the Addons section of the forums.
--]]

Debug = {}

require "math"
require "unicode"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lf = {} --table for local functions
local g_DebugMode = false

-- ------------------------------------------
-- CONSOLE LOGGING FUNCTIONS
-- ------------------------------------------
Debug.EnableLogging = function(bool) --allows you to enable/disable all the console logging functions to have a debug mode that is easy to turn on/off
	g_DebugMode = bool
end

Debug.IsLoggingEnabled = function() --returns true if you enabled logging
	return g_DebugMode
end

Debug.Event = function(args) --simple way to log an event's args with a label of the event name
	if g_DebugMode then
		args = args or {}
		log(lf.GetDebugLine()..unicode.upper(args.event or "NO_EVENT/FORCED_CALL")..": "..tostring(args))
	end
end

Debug.Table = function(label, tbl) --simple way to log a table with a supplied label
	if g_DebugMode then
		label = label or "NO LABEL:"
		log(lf.GetDebugLine()..tostring(label).." "..tostring(tbl))
	end
end

Debug.Divider = function(char, rep) --log that adds a visual divider, optional char to define the character used for the divider, and an optional rep to choose the repetition of the character
	if g_DebugMode then
		char = char or "-"
		rep = rep or 50
		log(lf.GetDebugLine()..unicode.rep(char, rep))
	end
end

Debug.Log = function(...) --log that accepts a dynamic amount of args and will concat them together with a space inbetween each
	if g_DebugMode then
		log(lf.GetDebugLine()..lf.ConcatArg(...))
	end
end

Debug.Warn = function(...) --warn that accepts a dynamic amount of args and will concat them together with a space inbetween each
	if g_DebugMode then
		warn(lf.ConcatArg(...))
	end
end

Debug.Error = function(...) --error that accepts a dynamic amount of args and will concat them together with a space inbetween each
	if g_DebugMode then
		error(lf.ConcatArg(...))
	end
end

-- ------------------------------------------
-- VARIABLE TESTING FUNCTIONS
-- ------------------------------------------
Debug.IsWeirdNumber = function(num) --to help handle and debug bad numbers
	if not (num == num) then -- NaN
		return true
	elseif num == math.huge then -- Inf
		return true
	elseif num == -math.huge then -- NegInf
		return true
	else
		return false
	end
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.GetDebugLine()
	--since log doesn't display the tail, get the info for the line that called the Debug function for appending to the message
	local info = debug_getinfo()
	local entry
	for _, entry in ipairs(info) do
		if entry.short_src ~= "lib/lib_Debug" then --find the line that first called lib_Debug
			return entry.short_src.."("..entry.currentline.."): "
		end
	end
	return "" --just in case
end

function lf.ConcatArg(...)
	local msg = ""
    for i = 1, select('#',...) do
		msg = msg..tostring(select(i, ...)).." "
    end
	return msg
end
