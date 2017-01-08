
--
-- Button 3D - Creates a cool 3D Button
--   by: John Su
--

--[[

Usage:
	BUTTON = Button3D.Create()
	BUTTON:Destroy()
	BUTTON:SetLabel(text, position)
	BUTTON:SetTexture(texture, region)
	BUTTON:BindEvent(event_name, function)
	BUTTON:Enable(enabled)
	BUTTON:Highlight(highlighted, dur)
	BUTTON:Flash(dur)
	BUTTON:Pulse(pulsing, args)	-- args may be a table containing 'color' (default COLOR_AMBER) or 'period' (default 1.5)
--]]

Button3D = {};

require "lib/lib_QuickFocusBox";
require "lib/lib_Callback2";

local BUTTON_API = {};

function Button3D.Create(callbacks, label_args)
	return BUTTON_API.Create(callbacks, label_args);
end

-- private members
local w_BUTTONS = {};
local PRIVATE_PulseButton;

-- constants
local COLOR_BLUE = Component.LookupColor("sinvironment_ui");
local COLOR_AMBER = Component.LookupColor("sinvironment_ui_hot");
local COLOR_HOT_AMBER = {r=COLOR_AMBER.red*2, g=COLOR_AMBER.green*2, b=COLOR_AMBER.blue*2};
local COLOR_DISABLED = {r=COLOR_BLUE.r*.4+.3, g=COLOR_BLUE.g*.4+.3, b=COLOR_BLUE.b*.4+.3, a=.25};

------------
-- BUTTON --
------------
function BUTTON_API.Create()
	local BUTTON = {
		idx = #w_BUTTONS+1,
		highlighted = false,
		enabled = true,
		BINDS={},
	};
	w_BUTTONS[BUTTON.idx] = BUTTON;
	
	BUTTON.ANCHOR = Component.CreateAnchor();
	BUTTON.OBJECTS = {
		BASE={SO=Component.CreateSceneObject("NewYou_Radial_Button_01A1")},
		ROLLOVER={SO=Component.CreateSceneObject("NewYou_Radial_Button_01B1")},
		--BACKANIM={SO=Component.CreateSceneObject("NewYou_Radial_Button_01C1")},
		HIGHLIGHT={SO=Component.CreateSceneObject("NewYou_Radial_Button_01D1")},
		--TOOLTIP_BACK={SO=Component.CreateSceneObject("NewYou_Radial_Button_01E1")},
		--TOOLTIP_BACK2={SO=Component.CreateSceneObject("NewYou_Radial_Button_01F1")},
	};
	for k,v in pairs(BUTTON.OBJECTS) do
		v.ANCHOR = v.SO:GetAnchor();
		v.ANCHOR:SetParent(BUTTON.ANCHOR);
		v.SO:SetParam("alpha", 0);
		v.SO:SetParam("tint", COLOR_BLUE);
	end
	BUTTON.OBJECTS.BASE.SO:SetParam("alpha", 1);
	
	BUTTON.TFRAME = Component.CreateFrame("TrackingFrame");
	BUTTON.TFRAME:SetInteractable(true);
	BUTTON.TFRAME_ANCHOR = BUTTON.TFRAME:GetAnchor();
	BUTTON.TFRAME_ANCHOR:SetParam("scale", {x=.1, y=.1, z=.1});
	BUTTON.TFRAME_ANCHOR:SetParent(BUTTON.ANCHOR);
	
	BUTTON.CB2_PulseButton = Callback2.Create();
	BUTTON.CB2_PulseButton:Bind(PRIVATE_PulseButton, BUTTON, {});
	
	BUTTON.WIDGET = Component.CreateWidget([[<Group dimensions="dock:fill">
		<Group name="group" dimensions="center-x:50%; center-y:50%; width:40%; height:40%"/>
	</Group>]], BUTTON.TFRAME);
	BUTTON.QFB = QuickFocusBox.Create(BUTTON.WIDGET);
	BUTTON.QFB:BindEvent("OnMouseEnter", function()
		if (BUTTON.enabled) then
			BUTTON:Highlight(true);
			BUTTON:FireEvent("OnMouseEnter");
		end
	end);
	BUTTON.QFB:BindEvent("OnMouseLeave", function()
		if (BUTTON.enabled) then
			BUTTON:Highlight(false);
			BUTTON:FireEvent("OnMouseLeave");
		end
	end);
	BUTTON.QFB:BindEvent("OnMouseDown", function()
		if (BUTTON.enabled) then
			System.PlaySound("Play_SFX_UI_AbilitySelect03_v4");
			BUTTON:Flash(60);
			BUTTON:FireEvent("OnMouseDown");
		end
	end);
	BUTTON.QFB:BindEvent("OnMouseUp", function()
		if (BUTTON.enabled) then
			--System.PlaySound("Play_SFX_UI_AbilitySelect03_v4");
			BUTTON:Flash(.2);
			BUTTON:FireEvent("OnMouseUp");
		end
	end);
	BUTTON.QFB:BindEvent("OnRightMouse", function()
		if (BUTTON.enabled) then
			System.PlaySound("Play_SFX_UI_AbilitySelect03_v4");
			BUTTON:Flash(.2);
			BUTTON:FireEvent("OnRightMouse");
		end
	end);
	BUTTON.GROUP = BUTTON.WIDGET:GetChild("group");
	
	for k,method in pairs(BUTTON_API) do
		BUTTON[k] = method;
	end
	return BUTTON;
end

function BUTTON_API:Destroy()
	if (self.LABEL) then
		Component.RemoveFrame(self.LABEL.FRAME);
	end
	self.CB2_PulseButton:Release();
	for k,v in pairs(self.OBJECTS) do
		Component.RemoveSceneObject(v.SO);
	end
	Component.RemoveFrame(self.TFRAME);
	Component.RemoveAnchor(self.ANCHOR);
	w_BUTTONS[self.idx] = nil;
	
	for k,v in pairs(self) do
		self[k] = nil;
	end
end

function BUTTON_API:SetLabel(text, pos)
	if (not self.LABEL) then
		self.LABEL = {FRAME=Component.CreateFrame("TrackingFrame")};
		self.LABEL.ANCHOR = self.LABEL.FRAME:GetAnchor();
		self.LABEL.ANCHOR:SetParent(self.ANCHOR);
		self.LABEL.TEXT = Component.CreateWidget(
			[[<Text dimensions="dock:fill" style="font:Demi_15; halign:center; valign:center"/>]],
			self.LABEL.FRAME);
		self.LABEL.FRAME:SetParam("alpha", 0);
	end
	self.LABEL.TEXT:SetText(text);
	self.LABEL.ANCHOR:SetParam("scale", {x=.1, y=.1, z=.1});
	self.LABEL.ANCHOR:SetParam("translation", {x=0, y=0, z=.1*(pos or 1)});
	self.LABEL.ANCHOR:SetParam("rotation", {axis={x=1, y=0, z=0}, angle=180});
end

function BUTTON_API:SetTexture(texture, region)
	if (not self.STILLART) then
		self.STILLART = Component.CreateWidget('<StillArt dimensions="dock:fill"/>', self.GROUP);		
	end
	self.STILLART:SetTexture(texture);
	if (region) then
		self.STILLART:SetRegion(region);
	end
	return self.STILLART;
end

function BUTTON_API:BindEvent(event_name, func)
	self.BINDS[event_name] = func;
end

function BUTTON_API:Enable(enabled)
	-- NOTE: do this to ensure self.enabled is a boolean - and nothing else
	if (enabled) then	self.enabled = true;
	else				self.enabled = false;
	end
	local tint = COLOR_DISABLED;
	if (self.enabled) then
		tint = COLOR_BLUE;
	end
	local dur = .2;
	local retint = {self.OBJECTS.HIGHLIGHT, self.OBJECTS.ROLLOVER, self.OBJECTS.BASE};
	for k,OBJ in pairs(retint) do
		OBJ.SO:ParamTo("tint", tint, dur);
	end
	self.GROUP:ParamTo("alpha", tonumber(self.enabled)/2+.5, dur);
end

function BUTTON_API:FireEvent(event_name)
	if (self.BINDS[event_name]) then
		self.BINDS[event_name]();
	end
end

function BUTTON_API:AddSceneObject(SCENE_OBJECT)
	local obj = {SO=SCENE_OBJECT, ANCHOR=SCENE_OBJECT:GetAnchor()};
	obj.ANCHOR:SetParent(self.ANCHOR);
	table.insert(self.OBJECTS, obj);
end

function BUTTON_API:Highlight(light, dur)
	local light_num = 1;
	local dur = dur or .2;
	local tint = COLOR_AMBER;
	if (not light) then
		light_num = 0;
		tint = COLOR_BLUE;
	end
	
	self.highlighted = light;
	self.OBJECTS.ROLLOVER.SO:ParamTo("alpha", light_num, .2);
	local retint = {self.OBJECTS.HIGHLIGHT, self.OBJECTS.ROLLOVER, self.OBJECTS.BASE};
	for k,OBJ in pairs(retint) do
		OBJ.SO:ParamTo("tint", tint, dur/2, 0, "ease-in");
	end
	if (self.LABEL) then
		self.LABEL.ANCHOR:ParamTo("rotation", {axis={x=1, y=0, z=0}, angle=90*(light_num-1)}, dur*.5);
		self.LABEL.FRAME:ParamTo("alpha", light_num, dur*.6);
	end	
	
	if (not self.highlighted and self.CB2_PulseButton:Pending()) then
		-- resume pulsing
		self.CB2_PulseButton:Execute();
	end
end

function BUTTON_API:Flash(dur)
	dur = dur or 0.4;
	self.OBJECTS.HIGHLIGHT.SO:SetParam("alpha", 1);
	self.OBJECTS.HIGHLIGHT.SO:ParamTo("alpha", 0, dur);
	
	local retint = {self.OBJECTS.HIGHLIGHT, self.OBJECTS.ROLLOVER, self.OBJECTS.BASE};
	for k,OBJ in pairs(retint) do
		OBJ.SO:SetParam("tint", COLOR_HOT_AMBER);
		OBJ.SO:ParamTo("tint", COLOR_AMBER, dur);
	end
end

function BUTTON_API:Pulse(should_pulse, args)
	if (self.CB2_PulseButton:Pending()) then
		self.CB2_PulseButton:Cancel();
	end
	if (should_pulse) then
		self.CB2_PulseButton:Bind(PRIVATE_PulseButton, self, args or {});
		self.CB2_PulseButton:Schedule(0);
	end
end

function PRIVATE_PulseButton(BUTTON, args)
	local retint = {BUTTON.OBJECTS.HIGHLIGHT, BUTTON.OBJECTS.ROLLOVER, BUTTON.OBJECTS.BASE};
	local dur = args.dur or 1.5;
	if (not BUTTON.highlighted) then
		for k,OBJ in pairs(retint) do
			OBJ.SO:ParamTo("tint", COLOR_BLUE, dur/2, 0, "smooth");
			OBJ.SO:QueueParam("tint", args.color or COLOR_AMBER, dur/2, 0, "smooth");
		end
	end
	BUTTON.CB2_PulseButton:Reschedule(dur);
end
