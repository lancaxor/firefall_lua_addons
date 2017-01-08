
--
-- lib_Keybind
--   by: Brian Blose
--

LIB_KEYBIND = {}

--CONSTANTS
local c_Categories = {
	Movement	= "Movement",
	Combat		= "Combat",
	Social		= "Social",
	Interface	= "Interface",
	Vehicle		= "Vehicle",
}

local c_ModifierKeyCode = {
	control		= 17,
	alt			= 18,
}

--FUNCTIONS

--[[LIB_KEYBIND
args.Group = string of keybinding group
args.Action = string of the name of the binding
args.Index = optional number of 1 or 2 for primary or secondary binding
]]
LIB_KEYBIND.GetKeyBind = function(args)
	local keybind, keytext
	if args.Group and c_Categories[args.Group] and args.Action then
		if args.Index ~= 1 or args.Index ~= 2 then args.Index = 1 end
		keybind = System.GetKeyBindings(args.Group, false)[args.Action]
		keytext = System.GetKeycodeString(keybind[args.Index].keycode)
		if keytext == "`" then keytext = "~" end
		if keybind[args.Index].alt then
			keytext = System.GetKeycodeString(c_ModifierKeyCode[System.GetModifierKey()]).."-"..keytext
		end
		if (not keytext or keytext == "") and args.Index == 1 then
			args.Index = 2
			keytext = LIB_KEYBIND.GetKeyBind(args)
		end
		if keytext and keytext ~= "" then
			return keytext
		end
	end
	warn("Invalid LIB_KEYBIND.GetKeyBind params: Group="..tostring(args.Group).." | Action="..tostring(args.Action).." | Index="..tostring(args.Index))
	return "ERROR"
end
