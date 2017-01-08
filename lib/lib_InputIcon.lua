
--
-- lib_InputIcon
--   by: John Su
--

--[[
====== USE =====

	InputIcon.CreateVisual(parent, name)	- returns a VISUAL item; see api below
	InputIcon.GetTexture(key)				- returns (texture, region); [key] can be either a keycode or string
	
	VISUAL:SetBind(keybind, autosize)		- [keybind] is a table with elements {keycode, alt}
											  [autosize] is a bool to automatically resize VISUAL to native dims (defaults to true)
	{width, height} = VISUAL:GetNativeDims()	- returns native width/height of VISUAL
	VISUAL:GetGroup()						- returns VISUAL's container Group widget
	VISUAL:Destroy()						- cleans up VISUAL
	VISUAL can also accept standard Group Widget commands

===============
--]]

require "table"

InputIcon = {};

--CONSTANTS
local ALIASES = {
	["Left Mouse"] = "mouse1",
	["Right Mouse"] = "mouse2",
	["Middle Mouse"] = "mouse3",
	["Mouse 4"] = "mouse4",
	["Mouse 5"] = "mouse5",
	["Mouse 6"] = "mouse6",
	["Mouse 7"] = "mouse7",
	["Mouse 8"] = "mouse8",
	["Wheel Up"] = "mwheelup",
	["Wheel Down"] = "mwheeldown",
	["DPad-Up"] = "DpadUp",
	["DPad-Down"] = "DpadDown",
	["DPad-Left"] = "DpadLeft",
	["DPad-Right"] = "DpadRight",
	
	["Gamepad Start"] = "GP_Start",
	["Gamepad Back"] = "GP_Back",
	["Gamepad A"] = "GP_A",
	["Gamepad B"] = "GP_B",
	["Gamepad X"] = "GP_X",
	["Gamepad Y"] = "GP_Y",
	["L-Trigger"] = "GP_LTrigger",
	["R-Trigger"] = "GP_RTrigger",
	["L-Shoulder"] = "GP_LShoulder",
	["R-Shoulder"] = "GP_RShoulder",
	["L-Thumb Click"] = "GP_LThumbClick",
	["R-Thumb Click"] = "GP_RThumbClick",
	
	["`"] = "Tilde",
	["-"] = "Minus",
	["="] = "Equals",
	["["] = "OpenBracket",
	["]"] = "CloseBracket",
	[";"] = "SemiColon",
	["'"] = "Quote",
	[","] = "LessThan",
	["."] = "GreaterThan",
	["/"] = "F-Slash",
	["\\"] = "B-Slash",
	["PgDn"] = "PageDown",
	["PgUp"] = "PageUp",
	["Num /"] = "Num_Divide",
	["Num *"] = "Num_Mult",
	["Num *"] = "Num_Mult",
	
	["Caps Lock"] = "CAPS",
	["Right Shift"] = "R-Shift",
	
	["NONE"] = "blank",
}

local OVERRIDES = {
	[160] = "L-Shift",
	[161] = "R-Shift",
	[162] = "L-Ctrl",
	[163] = "R-Ctrl",
	[164] = "L-Alt",
	[165] = "R-Alt",
}

local c_ModifierKeyIcon = {
	control		= "ctrl",
	alt			= "alt",
}

local c_ModifierKeyCode = {
	control		= 17,
	alt			= 18,
}

local MIN_WIDTH = 25

--FUNCTIONS
local PRIVATE = {};

InputIcon.GetTexture = function(key)
	if (not key or key == 0) then
		return "IconsInput", "blank";
	end
	local keyString;
	if (type(key) == "number") then
		keyString = OVERRIDES[key];
		if not keyString then
			keyString = System.GetKeycodeString(key);
		end
	elseif (type(key) == "string") then
		keyString = key;
	else
		error("Key must be either a string or keycode (integer), not a "..type(key)..": "..tostring(key));
	end
	local alias = ALIASES[keyString];
	if (alias) then
		keyString = alias;
	end
	
	local texture = "IconsInput";
	local region = keyString;
	
	local locale = System.GetLocale();
	-- try to get the locale version, if available
	local localeRegion = region.."_"..locale;
	if (locale ~= "en" and Component.CheckTextureExists(texture, localeRegion)) then
		region = localeRegion;
	elseif (not Component.CheckTextureExists(texture, region)) then
		region = "error";
	end

	return texture, region;
end

function InputIcon.CreateVisual(PARENT, name)
	local VISUAL = {GROUP=Component.CreateWidget('<Group name="'..(name or "")..'" dimensions="dock:fill"/>', PARENT)};
	VISUAL.ALT = Component.CreateWidget('<StillArt dimensions="dock:fill" class="none" style="visible:false; eatsmice:false"/>', VISUAL.GROUP);
	VISUAL.ICON = Component.CreateWidget('<StillArt dimensions="dock:fill" class="none" style="eatsmice:false"/>', VISUAL.GROUP);
	VISUAL.PLATE = Component.CreateWidget([[<Group dimensions="dock:fill" style="visible:false">
		<StillArt dimensions="left:0; right:7; top:0; bottom:100%;" class="none" style="eatsmice:false; texture:IconsInput; region:blank_l"/>
		<StillArt dimensions="left:7; right:100%-7; top:0; bottom:100%;" class="none" style="eatsmice:false; texture:IconsInput; region:blank_c"/>
		<StillArt dimensions="left:100%-7; right:100%; top:0; bottom:100%;" class="none" style="eatsmice:false; texture:IconsInput; region:blank_r"/>
	</Group>]], VISUAL.GROUP);
	VISUAL.TEXT = Component.CreateWidget(
		[[<Text dimensions="left:0; right:100%; top:2; height:100%" style="visible:false; padding:0; wrap:false; font:UbuntuBold_9; halign:center; valign:center; hotpoint:0; color:#FFFD00"/>]],
		VISUAL.GROUP);
	VISUAL.dims = {width=0, height=0};
	
	-- functions
	VISUAL.SetBind = PRIVATE.VISUAL_SetBind;
	VISUAL.GetGroup = PRIVATE.VISUAL_GetGroup;
	VISUAL.GetNativeDims = PRIVATE.VISUAL_GetNativeDims;
	VISUAL.Destroy = PRIVATE.VISUAL_Destroy;
	
	VISUAL.params = {alpha=VISUAL.GROUP:GetParam("alpha")};
	
	function VISUAL:Show(...)			return self.GROUP:Show(unpack({...})); end
	function VISUAL:Hide(...)			return self.GROUP:Hide(unpack({...})); end
	function VISUAL:IsVisible(...)		return self.GROUP:IsVisible(unpack({...})); end
	function VISUAL:GetBounds(...)		return self.GROUP:GetBounds(unpack({...})); end
	function VISUAL:GetParent(...)		return self.GROUP:GetParent(unpack({...})); end
	function VISUAL:GetPath(...)		return self.GROUP:GetPath(unpack({...})); end
	function VISUAL:GetDims(...)		return self.GROUP:GetDims(unpack({...})); end
	function VISUAL:SetDims(...)		return self.GROUP:SetDims(unpack({...})); end
	function VISUAL:MoveTo(...)			return self.GROUP:MoveTo(unpack({...})); end
	function VISUAL:QueueMove(...)		return self.GROUP:QueueMove(unpack({...})); end
	function VISUAL:FinishMove(...)		return self.GROUP:FinishMove(unpack({...})); end
	function VISUAL:GetParam(param)		return ( self.params[param] or self.ICON:GetParam(param) ); end
	function VISUAL:SetParam(...)		return PRIVATE.VISUAL_ParamAdjust(self, "SetParam", unpack({...})); end
	function VISUAL:ParamTo(...)		return PRIVATE.VISUAL_ParamAdjust(self, "ParamTo", unpack({...})); end
	function VISUAL:CycleParam(...)		return PRIVATE.VISUAL_ParamAdjust(self, "CycleParam", unpack({...})); end
	function VISUAL:QueueParam(...)		return PRIVATE.VISUAL_ParamAdjust(self, "QueueParam", unpack({...})); end
	function VISUAL:FinishParam(...)	return PRIVATE.VISUAL_ParamAdjust(self, "FinishParam", unpack({...})); end
	
	return VISUAL;
end

function PRIVATE.VISUAL_Destroy(VISUAL)
	Component.RemoveWidget(VISUAL.GROUP);
	for k,v in pairs(VISUAL) do
		VISUAL[k] = nil;
	end
end

function PRIVATE.VISUAL_ParamAdjust(VISUAL, methodName, param, ...)
    local arg = {...};
	if (arg[1]) then
		VISUAL.params[param] = arg[1];
	end
	if (param == "alpha") then
		VISUAL.GROUP[methodName](VISUAL.GROUP, param, unpack(arg));
	else
		VISUAL.ALT[methodName](VISUAL.ALT, param, unpack(arg));
		VISUAL.TEXT[methodName](VISUAL.TEXT, param, unpack(arg));
		VISUAL.ICON[methodName](VISUAL.ICON, param, unpack(arg));
		if (param == "tint" and methodName == "SetParam" or methodName == "ParamTo" or methodName == "QueueParam") then
			VISUAL.TEXT:SetTextColor("#FFFFFF", arg[1]);
		end
	end
end

function PRIVATE.VISUAL_SetBind(VISUAL, bind, autosize)
	local texture, region = InputIcon.GetTexture(bind.keycode);
	local alt_key = c_ModifierKeyIcon[System.GetModifierKey()]
	local dims
	
	if region == "error" then
		region = "blank"
		local text = System.GetKeycodeString(bind.keycode);
		VISUAL.TEXT:SetText(text);
		VISUAL.TEXT:Show(true)
		VISUAL.PLATE:Show(true)
		VISUAL.ICON:Show(false)
		texture_dims = Component.GetTextureInfo(texture, region);
		dims = VISUAL.TEXT:GetTextDims(false)
		dims.width = math.max(MIN_WIDTH, dims.width + 24)
		dims.height = texture_dims.height
		VISUAL.dims.width = dims.width
		VISUAL.dims.height = dims.height
	else
		VISUAL.ICON:SetTexture(texture,region);
		VISUAL.TEXT:Show(false)
		VISUAL.PLATE:Show(false)
		VISUAL.ICON:Show(true)
		dims = Component.GetTextureInfo(texture, region);
		VISUAL.dims.width = dims.width;
		VISUAL.dims.height = dims.height;
	end
	
	VISUAL.ALT:Show(bind.alt);
	if bind.alt and alt_key then
		VISUAL.ALT:SetTexture("IconsInput", alt_key);
		local alt_dims = Component.GetTextureInfo("IconsInput", alt_key);
		local SPACING = 1;
		VISUAL.dims.width = VISUAL.dims.width + alt_dims.width + SPACING;
		VISUAL.dims.height = math.max(VISUAL.dims.height, alt_dims.height);
		VISUAL.ALT:SetDims("left:0%; bottom:100%; width:" ..
						math.ceil(100*alt_dims.width/VISUAL.dims.width) .. "%; height:" ..
						math.ceil(100*alt_dims.height/VISUAL.dims.height) .. "%");
	end
	VISUAL.ICON:SetDims("right:100%; bottom:100%; width:" ..
						math.ceil(100*dims.width/VISUAL.dims.width) .. "%; height:" ..
						math.ceil(100*dims.height/VISUAL.dims.height) .. "%");
	
	VISUAL.PLATE:SetDims("right:100%; bottom:100%; width:" ..
						math.ceil(100*dims.width/VISUAL.dims.width) .. "%; height:" ..
						math.ceil(100*dims.height/VISUAL.dims.height) .. "%");
						
	VISUAL.TEXT:SetDims("right:100%; bottom:100%; width:" ..
						math.ceil(100*dims.width/VISUAL.dims.width) .. "%; height:" ..
						math.ceil(100*dims.height/VISUAL.dims.height) .. "%");
--	VISUAL.TEXT:SetDims("right:100%-1; center-y:50%; height:100%; width:" ..
--						math.ceil(100*dims.width/VISUAL.dims.width) .. "%;");
	
	if (autosize ~= false) then
		VISUAL:SetDims("center-y:_; center-x:_; width:".. VISUAL.dims.width .. "; height:" .. VISUAL.dims.height);
	end
end

function PRIVATE.VISUAL_GetNativeDims(VISUAL)
	return VISUAL.dims;
end

function PRIVATE.VISUAL_GetGroup(VISUAL)
	return VISUAL.GROUP;
end
