
--
-- lib_Liaison
--   by: John Su
--
--	for creating/referencing a Liaison frame to forward Component.PostMessage events

--[[ USAGE:
	--GENERAL FUNCTIONS
		Liaison.GetFrame()								-- returns the Liaison Frame (Invisible HUD Frame)
		Liaison.GetPath()								-- returns the full string path of the Liaison Frame (Component:Frame)
		Liaison.GetExternalPath(comp)					-- returns the full string path of another component's liaison
	--MESSAGE FUNCTIONS
		Liaison.BindMessage(msg_type, func)				-- binds a message with type to a callback function; func will be called with param [arg.data]
		Liaison.BindMessageTable(table)					-- binds a key-value pair list of message callbacks (table[msg_type] = func)
		Liaison.SendMessage(component, msg_type, data)	-- sends a message to another component's liaison
	--REMOTE FUNCTION CALL FUNCTIONS
		Liaison.BindCall(func_name, func)				-- binds an incoming RemoteCall to a handler function
		Liaison.BindCallTable(table)					-- binds a key-value pair list of RemoteCalls (table[msg_type] = func)
		Liaison.RemoteCall(component, func_name, ...)	-- makes a remote call to another component's Liaison
--]]

require "table"

Liaison = {};

local LIAISON_FRAME;
local d_Bindings = {};
local FRAME_NAME = "_Liaison";
local c_ComponentName = Component.GetInfo()

-- initialization
if (not LIAISON_FRAME) then
	LIAISON_FRAME = Component.CreateFrame("HudFrame", FRAME_NAME);
	LIAISON_FRAME:BindEvent("OnMessage", "_Liaison_OnMessage");
	LIAISON_FRAME:Show(false);
end

function _Liaison_OnMessage(arg)
	local cb = d_Bindings[arg.type];
	if (cb) then
		cb(arg.data);
	else
		warn("unhandled response: "..tostring(arg.type));
	end
end

-- ------------------------------------------
-- GENERAL FUNCTIONS
-- ------------------------------------------
function Liaison.GetFrame()
	return LIAISON_FRAME;
end

function Liaison.GetPath()
	return c_ComponentName..":"..Liaison.GetFrame():GetName();
end

function Liaison.GetExternalPath(comp)
	return comp..":"..FRAME_NAME;
end

-- ------------------------------------------
-- MESSAGE FUNCTIONS
-- ------------------------------------------
function Liaison.BindMessage(msg_type, func)
	if d_Bindings[msg_type] then
		warn("Liaison msg_type already bound: "..msg_type);
	else
		d_Bindings[msg_type] = func;
	end
end

function Liaison.BindMessageTable(tbl)
	for msg_type, func in pairs(tbl) do
		if d_Bindings[msg_type] then
			warn("Liaison msg_type already bound: "..msg_type);
		else
			d_Bindings[msg_type] = func;
		end
	end
end

function Liaison.SendMessage(component, msg_type, data)
	Component.PostMessage(component..":"..FRAME_NAME, msg_type, tostring(data));
end

-- ------------------------------------------
-- REMOTE FUNCTION CALL FUNCTIONS
-- ------------------------------------------
function Liaison.BindCall(func_name, func)
    if (func == nil) then
        warn("Cannot bind to a nil function to '"..func_name.."'")
        return
    end
	Liaison.BindMessage(func_name, function(data)
		func(unpack(jsontotable(data)));
	end)
end

function Liaison.BindCallTable(tbl)
	for func_name, func in pairs(tbl) do
		Liaison.BindCall(func_name, func)
	end
end

function Liaison.RemoteCall(component, func_name, ...)
	Liaison.SendMessage(component, func_name, tostring({...}));
end
