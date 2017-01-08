
--
-- ScriptedTutorial helper
--   by: John Su
--
--	interface for scripted tutorials; helps centralize logic that would otherwise be spread out everywhere
--	works in conjunction with the ScriptedTutorial component; intended for use in other components

--[[ INTERFACE

	ScriptedTutorial.AddHandler(event, handler)		-- listens for events from the Head Honcho
	ScriptedTutorial.DispatchEvent(event, args)		-- let the central interface know something has happened
	ScriptedTutorial.HasFlag(flag)					-- checks if a particular flag has been set (flag = string)
	ScriptedTutorial.AddFlagHandler(flag, handler)	-- sets a handler for when a flag is set/unset (flag = string, handler = function({flag, val})
	ScriptedTutorial.RemoveFlagHandler(flag, handler)	-- removes a handler from when a flag is set/unset (flag = string, handler = function({flag, val})

--]]

ScriptedTutorial = {};

require "lib/lib_EventDispatcher"
require "lib/lib_Liaison"

-- VARIABLES

local g_EVENT_DISPATCHER = EventDispatcher.Create();
local g_flags = {};
local g_flag_handlers = {};	-- g_flag_handlers[flag_name] = function(flag_name, value)

local PRIVATE_Initialize;

-- FUNCTIONS (public)

function ScriptedTutorial.AddHandler(event, handler)
	g_EVENT_DISPATCHER:AddHandler(event, handler);
end

function ScriptedTutorial.DispatchEvent(event, args)
	Liaison.RemoteCall("ScriptedTutorial", "Remote_DispatchEvent", event, args);
end

function ScriptedTutorial.HasFlag(flag)
	return g_flags[flag];
end

function ScriptedTutorial.AddFlagHandler(flag, handler)
	assert(type(handler) == "function");
	g_EVENT_DISPATCHER:AddHandler("_flag_"..flag, handler);
end

function ScriptedTutorial.RemoveFlagHandler(flag, handler)
	assert(type(handler) == "function");
	g_EVENT_DISPATCHER:RemoveHandler("_flag_"..flag, handler);
end

-- FUNCTIONS (private)

function PRIVATE_Initialize()
	Liaison.BindCall("Remote_SetFlag",
		function(flag, val)
			if (val ~= g_flags[flag]) then
				g_flags[flag] = val;
				g_EVENT_DISPATCHER:DispatchEvent("_flag_"..flag, {flag=flag, val=val});
			end
		end
	);
	
	Liaison.BindCall("Remote_DispatchEvent",
		function(event, arg)
			g_EVENT_DISPATCHER:DispatchEvent(event, arg);
		end
	);
end
PRIVATE_Initialize();	-- call it immediately
