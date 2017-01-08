
--
-- UserKeybinds
--   by: John Su
--		a helper lib for extended functionality with user keybinds

--[[

	local KEYSET = UserKeybinds.Create;
		> Creates a keyset object which can bind multiple keys to an action
		
	UserKeybinds.RegisterCustomKey(custom_id, display_name, args)
		> Registers a keybind in the interface that can be rebound by the user
			custom_id is a unique string that is used to identify this key
			display_name is the localized text under which this will appear in the options
			args is an optional table with the following optional fields:
				args.default = default keybind; can be a keycode or a keystring
	
	local keycode = UserKeybinds.GetCustomKey(custom_id)
		> Gets the custom keycode bound to this key; if unbound, will use the default set when it was registered	
		
	local keycode = UserKeybinds.GetGameKeycode(category_name, action_name)
		> gets the keycode currently bound to that game action (e.g. UserKeybinds.GetGameKeycode())
	___________________________
		
	KEYSET API:
	
	KEYSET:Destroy()
		> Unregisters all actions
		
	KEYSET:RegisterAction(action_name, bind[, trigger="press"])
		> Binds an action to a function; 'bind' can be either a string or a function
		  if 'bind' is nil, the action is unregistered
		  trigger can be "press", "release", or "toggle"

	KEYSET:UnregisterAction(action_name)
		> Unregisters the action and removes all binding to it
		
	KEYSET:BindKey(action_name, key[, idx=1])
		> Binds a key to an action in the 'idx' slot. 'idx' can be any valid
		  supplying a nil key unbinds it
	
	local keycode = KEYSET:GetKeybind(action_name[, idx=1])
		> Returns the keycode bound to the action in that slot
	
	local keycodes = KEYSET:GetKeybinds(action_name)
		> Returns a table of keycodes bound to that action
			keycodes[idx] = keycode
	
	local keybinds = KEYSET:ExportKeybinds()
		> Returns a table of keybinds of the format:
			keybinds[action_name][idx] = keycode
	
	KEYSET:ImportKeybinds(keybinds)
		> Imports a table of keybinds of the format:
			keybinds[action_name][idx] = keycode
		
	KEYSET:Activate(active)
		> enabled/disables actions w/o losing binds; keyset is active on creation
	
	local active = KEYSET:IsActive()
		> returns the active/inactive state of the keyset

--]]

UserKeybinds = {};

require "unicode";

local KEYSET_API = {};
local DEFAULT_IDX = 1;	-- default idx to use when unspecified
local g_KEYSET_counter = 0;
local g_Binds = {};	-- g_Binds[unique_id] = action
local g_CustomKeys = {};	-- populated from UserKeybinds.RegisterCustomKey

function UserKeybinds.Create()
	-- #KEYSET def
	local KEYSET = {
		id = g_KEYSET_counter,
		_action_counter = 1,
		active = true,
		actions = {},	-- actions[action_name] = action (see '#action def')
		keybinds = {},	-- keybinds[action_name][idx] = bind (see '#bind def')
	};
	g_KEYSET_counter = g_KEYSET_counter + 1;
	
	for k,v in pairs(KEYSET_API) do
		KEYSET[k] = v;
	end
	return KEYSET;
end

function UserKeybinds.GetGameKeycode(category_name, action_name)
	local keybindings = System.GetKeyBindings(category_name, false) or {};
	local action = keybindings[action_name] or {};
	return (action[1] or action[2] or {}).keycode;
end

function UserKeybinds.RegisterCustomKey(custom_id, display_name, args)
	assert(not g_CustomKeys[custom_id], "'"..custom_id.."' already registered!");
	args = args or {};
	local default = args.default;
	if (default and type(default) == "string") then
		-- convert to keycode
		local temp_act_id = Component.GetInfo().."._temp_userkeybind";
		Component.RegisterKeyAction(temp_act_id, "nil");		
		Component.BindUserKey(temp_act_id, default);
		default = Component.GetUserBoundKey(temp_act_id);
		Component.UnregisterKeyAction(temp_act_id);
	end
	local post_args = {
		custom_id = custom_id,
		display_name = display_name,
		defaults = {default},
	}
	g_CustomKeys[custom_id] = post_args;
	Component.PostMessage("Options:Main", "register_custom_key", tostring(post_args));
end

function UserKeybinds.GetCustomKey(custom_id)
	local keybinds = Component.GetSetting("options", "custom_keys");
	if (keybinds and keybinds[custom_id]) then
		-- return saved overrides
		return keybinds[custom_id];
	else
		-- return defaults
		local reg = g_CustomKeys[custom_id];
		assert(reg, "'"..custom_id.."' has not been registered yet!");
		return reg.defaults[1];	
	end
end

----------------
-- KEYSET API --
----------------

function KEYSET_API.Destroy(KEYSET)
	for action_name,_ in pairs(KEYSET.actions) do
		KEYSET:UnregisterAction(action_name);
	end
	for k,v in pairs(KEYSET) do
		KEYSET[k] = nil;
	end
end

function KEYSET_API.RegisterAction(KEYSET, action_name, bind, trigger)
	if (not bind) then
		KEYSET:UnregisterAction(action_name);
		return;
	end
	assert(type(bind) == "function", "'bind' must be a function (or nil)");
	
	local action = KEYSET.actions[action_name];
	if (not action) then
		-- #action def
		action = {
			unique_id = KEYSET.id.."_"..KEYSET._action_counter.."(ukb)",	-- unique id for registering action w/ Component
			name = action_name,
		};
		KEYSET.actions[action_name] = action;
		KEYSET.keybinds[action_name] = {};
		KEYSET._action_counter = KEYSET._action_counter + 1;
		g_Binds[action.unique_id] = action;
	end
	trigger = trigger or "press";
	
	-- update all existing binds
	for idx, bind in pairs(KEYSET.keybinds[action_name]) do
		Component.RegisterKeyAction(bind.reg_id, "_UserKeybinds_Handler", action.trigger);
	end
	
	action.bind = bind;
	action.trigger = trigger;
end

function KEYSET_API.UnregisterAction(KEYSET, action_name)
	local action = KEYSET.actions[action_name];
	if (action) then
		local binds = KEYSET.keybinds[action_name];
		if (binds) then
			for idx,bind in pairs(binds) do
				local reg_id = action.unique_id.."."..tostring(idx);
				Component.UnregisterKeyAction(reg_id);
			end
			KEYSET.keybinds[action_name] = nil;
		end
	
		g_Binds[action.unique_id] = nil;
		KEYSET.actions[action_name] = nil;
	end
end

function KEYSET_API.BindKey(KEYSET, action_name, keycode, idx)
	idx = idx or DEFAULT_IDX;
	local binds = KEYSET.keybinds[action_name];
	assert(binds, "action not registered");
	
	local bind = binds[idx];
	if (keycode) then
		local action = KEYSET.actions[action_name];
		if (not bind) then			
			-- #bind def
			bind = {
				reg_id = action.unique_id.."."..tostring(idx),	-- the id by which this slotted action is registered
				keycode = keycode,
			}
			binds[idx] = bind;
		end
		
		-- each slotted bind is registered and slotted to its own action
		Component.RegisterKeyAction(bind.reg_id, "_UserKeybinds_Handler", action.trigger);		
		Component.BindUserKey(bind.reg_id, keycode);
		bind.keycode = Component.GetUserBoundKey(bind.reg_id);
		if (not KEYSET.active) then
			-- we do this AFTER so that the assignment above is a number instead of a string (to prevent future lookups)
			Component.BindUserKey(bind.reg_id, 0);
		end
	else
		if (bind) then
			-- unregister/unbind this key
			Component.UnregisterKeyAction(bind.reg_id);
			binds[idx] = nil;
		end
	end
end

function KEYSET_API.GetKeybind(KEYSET, action_name, idx)
	idx = idx or DEFAULT_IDX;
	local binds = KEYSET.keybinds[action_name];
	assert(binds, "action not registered");
	if (binds[idx]) then
		return binds[idx].keycode;
	end
end

function KEYSET_API.GetKeybinds(action_name)
	local binds = KEYSET.keybinds[action_name];
	if (binds) then
		local ret = {};
		for idx,bind in pairs(binds) do
			ret[idx] = bind.keycode;
		end
		return ret;
	else
		return nil;
	end
end

function KEYSET_API.ExportKeybinds(KEYSET)
	local export = {};
	for action_name, binds in pairs(KEYSET.keybinds) do
		export[action_name] = {};
		for idx,bind in pairs(binds) do
			if (bind.keycode and bind.keycode ~= 0) then
				export[action_name][idx] = bind.keycode;
			end
		end
	end
	return export;
end

function KEYSET_API.ImportKeybinds(KEYSET, import)
	for action_name, slots in pairs(import) do
		for idx, keycode in pairs(slots) do
			KEYSET:BindKey(action_name, keycode, idx);
		end
	end
end

function KEYSET_API.Activate(KEYSET, active)
	if (KEYSET.active ~= active) then
		KEYSET.active = active;
		for action_name, binds in pairs(KEYSET.keybinds) do
			for idx,bind in pairs(binds) do
				if (active) then
					-- reapply binding
					Component.BindUserKey(bind.reg_id, bind.keycode);
				else
					-- unbind key (but keep record)
					Component.BindUserKey(bind.reg_id, 0);
				end
			end
		end
	end
end
	
function KEYSET_API.IsActive(KEYSET)
	return KEYSET.active;
end

-- global handler

function _UserKeybinds_Handler(arg)
	local unique_id = unicode.sub(arg.name, 1, unicode.find(arg.name, ".", 1, true)-1);
	local action = 	g_Binds[unique_id];
	arg.name = action.name;
	action.bind(arg);
end
