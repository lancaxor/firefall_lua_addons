
--
-- lib_PaintShop
--   by: Red 5 Studios
--		a menu used for decorating bodies WITH GLITTER AWWW YEAH ~*_*~

--[[
Usage:
	PaintShop.Activate(true/false);
	success = PaintShop.BackOut();
	PainShop.UpdateBackButton(BUTTON);
	
	PaintShop.BeginPlaceDecal(model, decal_id, matrix, type);
	PaintShop.FinishPlaceDecal(accept);
	
	PaintShop.BeginEditPattern(model, patterns, editingPatternIdx);
	PaintShop.FinishEditPattern(action);  -- action can be "accept", "revert", or "delete"
	
	PaintShop.IsEditing();
	PaintShop.SetSlots(slot_list);
	PaintShop.SetRootMenu(rootmenu);
		- Sets an existing root menu. If this function is not called, the PaintShop will create and own one.
		- The slots in the menu should be a superset of slot_list passed into SetSlots.
	
	SLOT = PaintShop.FindSlot(slot_info);	-- finds the slot with matching slot_info	
	SLOT = PaintShop.CreateSlot(label, slot_info, methods);
	SLOT:Destroy();
	SLOT:RefreshOption();
	
	SLOT:BeginPlacement();
	SLOT:EndPlacement();
	
	SLOT also implements EventDispatcher methods, and dispatches the following events:
		- "BeginPlaceDecal"   : called from PaintShop.BeginPlaceDecal
		- "FinishPlaceDecal"  : called from PaintShop.FinishPlaceDecal
		- "BeginEditPattern"  : called from PaintShop.BeginEditPattern
		- "FinishEditPattern" : called from PaintShop.FinishEditPattern
}
--]]

PaintShop = {};

require "lib/lib_GarageMenu";
require "lib/lib_ScenePlane";
require "lib/lib_QuickFocusBox";
require "lib/lib_EventDispatcher";
require "lib/lib_VisualSlotter";

local PRIVATE = {};
local PLACEMENT_API = {};

local MODE_OFF = 0;
local MODE_OVERVIEW = 1;
local MODE_PLACE_DECAL = 2;
local MODE_EDIT_PATTERN = 3;

local DECAL_COLOR = "4294967295";	-- this is the only color accepted by the web at the moment

local w_SLOTS = {};
local w_PLACEMENT_UI = {};
local w_BACK_BUTTON_EXT;	-- Back Button (externally owned)
local g_ROOTMENU;
local g_owns_root_menu = false;
local g_mode = MODE_OFF;
local g_model = nil;
local g_placing_decal_id = nil;
local g_editing_pattern_id = nil;

-- See tsTattooPlacer::Key
local DECAL_KEYS =
{
	LEFT		 = 0,
	RIGHT		 = 1,
	DOWN		 = 2,
	UP			 = 3,
	ROTATE_LEFT  = 4,
	ROTATE_RIGHT = 5,
	SCALE_X_DOWN = 6,
	SCALE_X_UP   = 7,
	SCALE_Y_DOWN = 8,
	SCALE_Y_UP   = 9,
	SCALE_DOWN   = 10,
	SCALE_UP	 = 11
}

-- See tsCziPatternPlacer::Key
local PATTERN_KEYS =
{
	LEFT		 = 0,
	RIGHT		 = 1,
	DOWN		 = 2,
	UP			 = 3,
	ROTATE_LEFT  = 4,
	ROTATE_RIGHT = 5,
	SCALE_DOWN   = 6,
	SCALE_UP	 = 7
}

--------------------
-- Main Interface --
--------------------

function PaintShop.Activate(active)
	if ((g_mode ~= MODE_OFF) == active) then
		return;
	end
	if (active) then
		PRIVATE.ChangeMode(MODE_OVERVIEW);
		VisualSlotter:AddHandler("OnMouseDown_Stage", PRIVATE.OnMouseDown_Stage);
		VisualSlotter:AddHandler("OnMouseUp_Stage", PRIVATE.OnMouseUp_Stage);
	else
		w_BACK_BUTTON_EXT = nil;
		PRIVATE.ChangeMode(MODE_OFF);
		VisualSlotter:RemoveHandler("OnMouseDown_Stage", PRIVATE.OnMouseDown_Stage);
		VisualSlotter:RemoveHandler("OnMouseUp_Stage", PRIVATE.OnMouseUp_Stage);
	end
end

function PaintShop.BackOut()
	-- returns number of steps left it can back out from
	if (g_mode == MODE_PLACE_DECAL) then
		PaintShop.FinishPlaceDecal(true);
		return 2;
	elseif (g_mode == MODE_EDIT_PATTERN) then
		PaintShop.FinishEditPattern("accept");
		return 2;
	elseif (g_mode == MODE_OVERVIEW) then
		if (g_ROOTMENU:GetActiveSubMenu()) then 
			g_ROOTMENU:Open(dur);
			return 1;
		else
			return false;
		end
	else
		return false;
	end
	
	return false;
end

function PaintShop.UpdateBackButton(BUTTON)
	if (g_mode == MODE_OVERVIEW) then
		local SUBMENU = g_ROOTMENU:GetActiveSubMenu();
		if (SUBMENU) then
			BUTTON.ANCHOR:SetParent(SUBMENU:GetGallery().ANCHOR);
			BUTTON.ANCHOR:SetParam("translation", {x=.35,y=-0.01,z=.65});
			BUTTON.ANCHOR:SetParam("scale", {x=.8, y=.8, z=.8});
		else
			BUTTON.ANCHOR:SetParent(g_ROOTMENU:GetAnchor());
			BUTTON.ANCHOR:SetParam("translation", {x=1.0,y=-.11,z=.14});
			BUTTON.ANCHOR:SetParam("scale", {x=.8, y=.8, z=.8});
		end
	end
	w_BACK_BUTTON_EXT = BUTTON;
end

function PaintShop.RefreshOptions()
	for i,SLOT in ipairs(w_SLOTS) do
		SLOT:RefreshOptions();
	end
end

function PaintShop.IsEditing()
	return g_mode == MODE_PLACE_DECAL or
		   g_mode == MODE_EDIT_PATTERN;
	
end

function PaintShop.SetSlots(slot_list)
	if (g_ROOTMENU) then
		g_ROOTMENU:Close(0);
	end
	for i,SLOT in ipairs(w_SLOTS) do
		SLOT:Destroy();
	end
		
	w_SLOTS = {};
	for i,SLOT in ipairs(slot_list) do
		w_SLOTS[i] = SLOT;
	end
	
	if (g_mode == MODE_OVERVIEW) then
		PRIVATE.LoadSlots();
		g_ROOTMENU:Open(0);
	end
end

function PaintShop.SetRootMenu(rootmenu)
	assert((not g_owns_root_menu) or (g_ROOTMENU == nil), "Must be called in 'off' mode with no existing root menu");
	g_owns_root_menu = (rootmenu == nil);
	g_ROOTMENU = rootmenu;
end

function PaintShop.BeginPlaceDecal(model, decal_id, matrix, _type)
	if (g_mode == MODE_PLACE_DECAL) then
		-- We were actually placing something, so reuse that matrix
		matrix = Sinvironment.GetTattooMatrix();
		Sinvironment.EndPlaceTattoo(false);
	end
	
	g_placing_decal_id = decal_id;
	g_model = model;
	
	Sinvironment.BeginPlaceTattoo(g_model, g_placing_decal_id, _type);
	if (matrix ~= nil) then
		Sinvironment.SetTattooMatrix(matrix);
	end

	local SLOT = PRIVATE.GetActiveSlot();
	if (SLOT) then
		SLOT:DispatchEvent("OnBeginPlaceDecal", {id=decal_id, type=_type});
	end			

	PRIVATE.ChangeMode(MODE_PLACE_DECAL);
end

function PaintShop.FinishPlaceDecal(accept)
	if (g_mode == MODE_PLACE_DECAL) then
		local args = { color = DECAL_COLOR, matrix = Sinvironment.GetTattooMatrix(), id = g_placing_decal_id };		
		
		g_placing_decal_id = nil;
		g_model = nil;
	
		Sinvironment.EndPlaceTattoo(accept);

		local SLOT = PRIVATE.GetActiveSlot();
		if (SLOT and accept) then
			SLOT:DispatchEvent("OnFinishPlaceDecal", args);
		end
			
		PRIVATE.ChangeMode(MODE_OVERVIEW);
	end
end

function PaintShop.BeginEditPattern(model, patterns, editingPatternIdx)
	if (g_mode == MODE_EDIT_PATTERN) then
		-- We were actually editing a pattern, so reuse that transform
		patterns[editingPatternIdx].transform = Sinvironment.GetPatternTransform();
		PaintShop.FinishEditPattern("revert");
	end
	
	g_editing_pattern_id = patterns[editingPatternIdx].id;
	g_model = model;
	
	Sinvironment.BeginEditPattern(g_model, patterns, editingPatternIdx);

	local SLOT = PRIVATE.GetActiveSlot();
	if (SLOT) then
		SLOT:DispatchEvent("OnBeginEditPattern", {slot=editingPatternIdx});
	end			

	PRIVATE.ChangeMode(MODE_EDIT_PATTERN);
end

function PaintShop.FinishEditPattern(action)
	if (g_mode == MODE_EDIT_PATTERN) then
		local args = { transform = Sinvironment.GetPatternTransform(), id = g_editing_pattern_id };		
		
		g_editing_pattern_id = nil;
		g_model = nil;
	
		Sinvironment.EndEditPattern(action);

		local SLOT = PRIVATE.GetActiveSlot();
		if (SLOT and action == "accept") then
			SLOT:DispatchEvent("OnFinishEditPattern", args);
		end
			
		PRIVATE.ChangeMode(MODE_OVERVIEW);
	end
end

function PaintShop.FindSlot(slot_info)
	-- find the corresponding SLOT
	for k,SLOT in pairs(w_SLOTS) do
		if (SLOT.slot_info == slot_info) then
			return SLOT;
		end
	end
	-- this can legally happen in the garage in UpdateChecklist() when you change plating (for instance) and then go to the paintshop
	return nil;
end

----------
-- SLOT --
----------

local SLOT_API = {};

function PaintShop.CreateSlot(label, slot_info, methods)
	local SLOT = {label=label, slot_info=slot_info};
	SLOT.for_paintshop = true;
	SLOT.my_list = nil;
	SLOT.SUBMENU = nil;
	SLOT.DISPATCHER = EventDispatcher.Create();
	SLOT.DISPATCHER:Delegate(SLOT);
	
	-- callbacks
	SLOT.Apply = methods.Apply;
	SLOT.IsPresent = methods.IsPresent;
	SLOT.GetOptions = methods.GetOptions;
	SLOT.OnSelect = methods.OnSelect;
	
	-- methods
	for k,v in pairs(SLOT_API) do
		SLOT[k] = v;
	end
	
	assert(SLOT.Apply, "methods param must contain a 'Apply(item)' function");
	assert(SLOT.IsPresent, "methods param must contain a 'IsPresent(item, context)' function");
	assert(SLOT.GetOptions, "methods param must contain a 'GetOptions(item, context)' function");
	
	return SLOT;
end

function SLOT_API.Destroy(SLOT)
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:Remove();
	end
	SLOT.DISPATCHER:Destroy();
	for k,v in pairs(SLOT) do
		SLOT[k] = nil;
	end
end

function SLOT_API.Dirty(SLOT)
	-- remove dirty lists
	SLOT.my_list = nil;
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:SetOptions({});
	end
end

function SLOT_API.RefreshOptions(SLOT)
	SLOT.my_list = SLOT:GetOptions();
	if (not SLOT.my_list) then
		error("bad list returned on slot "..SLOT.label);
	elseif (#SLOT.my_list == 0) then
		--warn("empty list for slot "..SLOT.label);
	end
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:SetOptions(SLOT.my_list);
		for i,item in ipairs(SLOT.my_list) do
			if (SLOT.IsPresent(item)) then
				SLOT.SUBMENU:SelectOption(i, true);
				break;
			end
		end
		if (SLOT.SUBMENU:GetLevel() == GarageMenu.LEVEL_BROWSE) then
			-- refresh the previews
			local GALLERY = SLOT.SUBMENU:GetGallery();
			GALLERY:LoadOptions(SLOT.my_list, SLOT.SUBMENU);
		end
	end
end

-- PLACEMENT

function PLACEMENT_API:ActivatePlacementUI(active)
	if (active ~= self.active) then
		self.active = active;
		
		if (active) then
			-- CREATE
			self.ANCHOR = Component.CreateAnchor();
			self.SP = ScenePlane.CreateWithRenderTarget(256, 256);
			self.SP:BindToTextureFrame();
			self.SP.ANCHOR:SetParent(self.ANCHOR);
			--[[
			self.BACK = Component.CreateSceneObject("tooltip_backing");
			self.BACK:SetParam("scale", {x=.5, y=.5, z=.5});
			self.BACK:SetParam("tint", GarageMenu.TINT_UI);
			self.BACK:GetAnchor():SetParent(self.ANCHOR);
			--]]
			-- bind methods
			for k,v in pairs(PLACEMENT_API) do
				self[k] = v;
			end
			
			self.ANCHOR:SetParam("translation", {x=-.06,y=.18,z=-.032});
			self.ANCHOR:SetParam("scale", {x=.04, y=.04, z=.04});
			self.ANCHOR:BindToCamera();
			self:Close(0);
		else
			-- DESTROY
			self.focused_BUTTON = nil;
			--Component.RemoveSceneObject(self.BACK);
			self.SP:Destroy();
			Component.RemoveAnchor(w_PLACEMENT_UI.ANCHOR);
		end
	end
end

function PLACEMENT_API:Open(dur, mode)
	-- Create buttons
	local keyStateFunction = nil;
	local KEYS = nil;
	
	if (mode == MODE_PLACE_DECAL) then
		keyStateFunction = Sinvironment.SetTattooKeyState;
		KEYS = DECAL_KEYS;
	elseif (mode == MODE_EDIT_PATTERN) then
		keyStateFunction = Sinvironment.SetPatternKeyState;
		KEYS = PATTERN_KEYS;
	end
	
	-- create buttons
	self.BUTTONS = {};
	
	if (keyStateFunction ~= nil and KEYS ~= nil) then
		local transform_buttons = {
			{key=KEYS.UP,			pos={2,1},	texture="arrows",	  region="up"},
			{key=KEYS.DOWN,			pos={2,3},	texture="arrows",	  region="down"},
			{key=KEYS.LEFT,			pos={1,2},	texture="arrows",	  region="left"},
			{key=KEYS.RIGHT,		pos={3,2},	texture="arrows",	  region="right"},
			
			{key=KEYS.SCALE_DOWN,	pos={1,3},	texture="Plus_Minus", region="minus"},
			{key=KEYS.SCALE_UP,		pos={3,3},	texture="Plus_Minus", region="plus"},
			
			{key=KEYS.ROTATE_LEFT,	pos={1,1},	texture="arrows",	  region="turn_left_down"},
			{key=KEYS.ROTATE_RIGHT,	pos={3,1},	texture="arrows",	  region="turn_right_down"},
		}
		
		for i,v in ipairs(transform_buttons) do
			local BUTTON = self:CreateButton({texture=v.texture, region=v.region},
				{left=(v.pos[1]-1)/3, right=(v.pos[1]/3), top=(v.pos[2]-1)/3, bottom=v.pos[2]/3});
			BUTTON:AddHandler("OnPress", function()				
				keyStateFunction(v.key, true);
			end);
			BUTTON:AddHandler("OnRelease", function()
				keyStateFunction(v.key, false);
			end);
		end
	end

	-- Rotate in
	self.ANCHOR:ParamTo("rotation", {axis={x=0, y=0, z=1}, angle=-10}, dur);
end

function PLACEMENT_API:Close(dur)
	-- Rotate out
	self.ANCHOR:ParamTo("rotation", {axis={x=0, y=0, z=1}, angle=-160}, dur);
	
	-- Destroy buttons
	if (self.BUTTONS ~= nil) then
		for k,BUTTON in pairs(self.BUTTONS) do
			BUTTON:Destroy();
		end
	end
	self.BUTTONS = {};
	self.focused_BUTTON = nil;
end

function PLACEMENT_API:CreateButton(label, dims)
	local PLACEUI = self;
	
	local BUTTON = {GROUP=Component.CreateWidget([[<Group dimensions="dock:fill">
		<StillArt name="art" dimensions="center-x:50%; center-y:50%; width:50%; height:50%"/>
	</Group>]], PLACEUI.SP.FRAME)};
	BUTTON.ART = BUTTON.GROUP:GetChild("art");
	BUTTON.ART:SetParam("tint", GarageMenu.TINT_UI);
	BUTTON.ART:SetParam("exposure", 0.4);
	BUTTON.ART:SetParam("hotpoint", 0.6);
	if (label.texture) then
		BUTTON.ART:SetTexture(label.texture);
		if (label.region) then
			BUTTON.ART:SetRegion(label.region);
		end
	end
	if (label.params) then
		for k,v in pairs(label.params) do
			BUTTON.ART:SetParam(k, v);
		end
	end
	if (label.dims) then
		BUTTON.ART:SetDims(label.dims);
	end
	
	BUTTON.DISPATCHER = EventDispatcher.Create();
	BUTTON.DISPATCHER:Delegate(BUTTON);
	
	local function MouseUp()
		if (BUTTON.pressed) then
			BUTTON.pressed = false;
			BUTTON.DISPATCHER:DispatchEvent("OnRelease", {BUTTON=BUTTON});
		end
	end
	
	BUTTON.QFB = QuickFocusBox.Create(BUTTON.GROUP);
	BUTTON.QFB:BindEvent("OnMouseEnter", function()
		PLACEUI:FocusOnButton(BUTTON);
	end);
	BUTTON.QFB:BindEvent("OnMouseLeave", function()
		BUTTON:SetFocus(false, 0.2);
		MouseUp();
	end);
	BUTTON.QFB:BindEvent("OnMouseDown", function()
		BUTTON.pressed = true;
		BUTTON.DISPATCHER:DispatchEvent("OnPress", {BUTTON=BUTTON});
	end);
	BUTTON.QFB:BindEvent("OnMouseUp", MouseUp);
	
	BUTTON.SCENE_OBJ = Component.CreateSceneObject("garage_container");
	BUTTON.SCENE_OBJ:SetParam("tint", GarageMenu.TINT_UI);
	BUTTON.SCENE_OBJ:GetAnchor():SetParent(self.SP.ANCHOR);
	
	BUTTON.GROUP:SetDims({	left={percent=dims.left*100},	right={percent=dims.right*100},
							top={percent=dims.top*100},		bottom={percent=dims.bottom*100}});
	BUTTON.SCENE_OBJ:SetParam("scale", {x=4*(dims.right-dims.left), y=.1, z=4*(dims.bottom-dims.top)});
	BUTTON.SCENE_OBJ:SetParam("translation", {x=(dims.right+dims.left-1)/2, y=.1, z=-(dims.bottom+dims.top-1)/2});
	
	
	function BUTTON:Destroy()
		BUTTON.QFB:Destroy();
		BUTTON.DISPATCHER:Destroy();		
		Component.RemoveSceneObject(BUTTON.SCENE_OBJ);		
		Component.RemoveWidget(BUTTON.GROUP);
		BUTTON.SCENE_OBJ = nil;
		BUTTON.GROUP = nil;
	end
	
	function BUTTON:SetFocus(focused, dur)
		if (focused) then
			BUTTON.GROUP:ParamTo("alpha", 1, dur, 0, "ease-in");
			BUTTON.SCENE_OBJ:ParamTo("tint", GarageMenu.TINT_UI_AMBER, dur, 0, "ease-in");
		else
			BUTTON.GROUP:ParamTo("alpha", .6, dur, 0, "ease-in");
			BUTTON.SCENE_OBJ:ParamTo("tint", GarageMenu.TINT_UI, dur, 0, "ease-in");
		end
	end
	
	table.insert(self.BUTTONS, BUTTON);
	BUTTON:SetFocus(false, 0);
	
	return BUTTON;
end

function PLACEMENT_API:FocusOnButton(BUTTON)
	if (self.focused_BUTTON) then
		self.focused_BUTTON:SetFocus(false, 0.2);
	end
	self.focused_BUTTON = BUTTON;
	if (self.focused_BUTTON) then
		BUTTON:SetFocus(true, 0.1);
	end
end


-- PRIVATE

function PRIVATE.ChangeMode(mode)
	if (mode ~= g_mode) then
		local old_mode = g_mode;
		g_mode = mode;

		if (old_mode == MODE_OFF) then		
			if (g_owns_root_menu) then
				-- create root/region menu
				g_ROOTMENU = GarageMenu.CreateRootMenu();
				
				PRIVATE.LoadSlots();
				g_ROOTMENU:AttachToEntity(g_model);
				g_ROOTMENU:Open(dur);
			end
			
			PLACEMENT_API.ActivatePlacementUI(w_PLACEMENT_UI, true);
		elseif (old_mode == MODE_PLACE_DECAL) then
			w_PLACEMENT_UI:Close(.2);
			Sinvironment.EndPickTattooPosition();
			assert(not g_placing_decal_id, "Use FinishPlaceDecal instead of calling this directly");
		elseif (old_mode == MODE_EDIT_PATTERN) then
			w_PLACEMENT_UI:Close(.2);
			assert(not g_editing_pattern_id, "Use FinishEditPattern instead of calling this directly");
		end
		
		if (mode == MODE_OFF) then
			if (g_placing_decal_id) then
				PaintShop.FinishPlaceDecal(false);
			end
			if (g_editing_pattern_id) then
				PaintShop.FinishEditPattern("revert");
			end
			
			if (g_owns_root_menu) then
				-- clean up SUBMENUs
				g_ROOTMENU:Close(dur);
				for i,SLOT in ipairs(w_SLOTS) do
					if (SLOT.SUBMENU) then
						SLOT.SUBMENU:Remove();
						SLOT.SUBMENU = nil;
					end
				end
			
				g_ROOTMENU:Remove();
				g_ROOTMENU = nil;
			end
		
			w_PLACEMENT_UI:ActivatePlacementUI(false);
		elseif (mode == MODE_PLACE_DECAL or mode == MODE_EDIT_PATTERN) then
			w_PLACEMENT_UI:Open(.2, mode);
		end
		
		if (w_BACK_BUTTON_EXT) then
			PaintShop.UpdateBackButton(w_BACK_BUTTON_EXT);
		end
	end
end

function PRIVATE.GetActiveSlot()
	local SUBMENU = g_ROOTMENU:GetActiveSubMenu();
	if (SUBMENU) then
		for k,SLOT in pairs(w_SLOTS) do
			if (SLOT.SUBMENU == SUBMENU) then
				return SLOT;
			end
		end
	end
	return nil;
end

function PRIVATE.OnMouseDown_Stage(arg)
	-- start drag
	if (g_mode ~= MODE_PLACE_DECAL or not Sinvironment.BeginPickTattooPosition()) then
		-- Clicked on background or on model in non-placement mode
		-- --> Accept decal or go back
		VisualSlotter.StartMouseDrag();
		--PaintShop.OnBack();	-- do nothing, so we can safely rotate the model
	end
end

function PRIVATE.OnMouseUp_Stage(arg)
	if (g_mode == MODE_PLACE_DECAL) then
		-- end drag
		Sinvironment.EndPickTattooPosition();
	end
end

function PRIVATE.LoadSlots()
	-- load slots/submenus
	for i,SLOT in ipairs(w_SLOTS) do
		local SUBMENU = g_ROOTMENU:CreateSubMenu();
		SUBMENU:SetLabel(SLOT.label);
		SUBMENU.OnSelect = function()
			if (w_BACK_BUTTON_EXT) then
				PaintShop.UpdateBackButton(w_BACK_BUTTON_EXT);
			end
			local item = SUBMENU:GetOption();
			if (item) then
				SLOT.Apply(item);
			end
		end
		SUBMENU.OnBrowse = SUBMENU.OnSelect;
		SLOT.SUBMENU = SUBMENU;
		SLOT:RefreshOptions();
	end
end
