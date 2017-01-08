
--
-- Visual Slotter - provides the base interface for slotting objects on a model
--   by: John Su
--

--[[

Usage:
	VisualSlotter.Activate(true/false)	
	VisualSlotter.ActivateModel(model_handle)	
	VisualSlotter.ActivateRegion(region_idx)
	VisualSlotter.LockZoom(min_zoom, max_zoom)
	success = VisualSlotter.BackOut()
	
	VisualSlotter.OnSubmit		-- called when left clicking
	VisualSlotter.OnBack		-- called when right-clicking

	VisualSlotter.StartMouseDrag()	-- start mouse rotation of the model and the camera (usually called in OnSubmit on mouse down, stopped at mouse up)

	VisualSlotter.SwitchToManualCamera({pos={x,y,z}, aim={x,y,z}[, zoom]});
	VisualSlotter.SwitchToAnimatedCamera(model[, hardpoint="HP_Camera"])
	VisualSlotter.SwitchToAnchorCamera({pos=anchor, aim=anchor[, zoom]});
	
	BUTTON3D = VisualSlotter.AddTopCornerButton({texture, region, label, OnMouseDown})
	
	REGION = VisualSlotter.CreateRegion(idx, SLOTS_list, methods)
		- methods can be nil or contain any of the following methods:
		-    OnSelect(REGION, slot_idx), gets called whenever an entry in the root menu is selected
	
	REGION = VisualSlotter.GetActiveRegion()
	REGION = VisualSlotter.GetRegion(idx)
	REGION:Activate(true/false)
	REGION:AddSlot(SLOT)
	REGION:Destroy()
	
	SLOT = VisualSlotter.CreateSlot(label, slot_info, methods)
	SLOT:Destroy()
	SLOT:RefreshOptions()
	SLOT:Open([dur])	-- opens this slot
	
	if .GetEligibility is defined in methods, the following return values are accepted:
		VisualSlotter.CAN_SLOT
		VisualSlotter.CAN_ALMOST_SLOT
		VisualSlotter.CAN_NEVER_SLOT
	
	VisualSlotter is also an EventDispatcher delegate, dispatching the following events:
		- OnMouseDown_Stage
		- OnMouseUp_Stage
		- OnRightMouse_Stage

--]]

VisualSlotter = {};

require "table";
require "lib/lib_GarageMenu";
require "lib/lib_ScenePlane";
require "lib/lib_Button3D";
require "lib/lib_EventDispatcher";
require "lib/lib_Vector";
--require "./helpers/SNV_ModelViewer";

local PRIVATE = {};

VisualSlotter.CAN_SLOT = true;			-- all green
VisualSlotter.CAN_ALMOST_SLOT = 0;		-- you need to meet some requirements first
VisualSlotter.CAN_NEVER_SLOT = false;	-- you can never do it

-- private members
local g_active = false;
local g_model;
local g_activeREGION;
local w_REGIONS = {};
local w_PLEASE_WAIT = nil;
local w_BACK_BUTTON;
local w_TOPCORNER_BUTTONS;
local w_CLICKCAPTURE;
local g_DISPATCHER = EventDispatcher.Create();

-- model rotation / camera control
local cb_mouseDrag;
local cb_UpdateCam;
local g_mouseX;
local g_mouseY;
local g_initialCam = { pos={x=0, y=-3.9, z=3.4}, aim={x=0, y=0, z=3.35} };
local g_camBrake;
local g_cam;
local g_camTarget;
local g_camZoom = 0;
local g_zoomConstraints = {min=0, max=0.5};
local g_aimZOffset;
local g_aimZOffsetMax = 0.6;

local CAM_MANUAL = "man";
local CAM_ANIMATED = "anm";
local CAM_ANCHOR = "nch";
local g_cameraMode = CAM_MANUAL;

local COLOR_BLUE = Component.LookupColor("sinvironment_ui");
local COLOR_AMBER = Component.LookupColor("sinvironment_ui_hot");
local COLOR_HOT_AMBER = {r=COLOR_AMBER.red*2, g=COLOR_AMBER.green*2, b=COLOR_AMBER.blue*2};

-------------------
-- VisualSlotter --
-------------------

g_DISPATCHER:Delegate(VisualSlotter);

function VisualSlotter.Activate(active)
	active = active ~= nil and active ~= false
	if (active ~= g_active) then
		g_active = active;
		if (active) then
			g_cam       = { pos = Vec3.Copy(g_initialCam.pos), aim = Vec3.Copy(g_initialCam.aim) };
			g_camTarget = { pos = Vec3.Copy(g_initialCam.pos), aim = Vec3.Copy(g_initialCam.aim) };
			g_cameraMode = CAM_MANUAL;
			g_camBrake = 2;
			PRIVATE.UpdateAimZOffset(0);
			g_camZoom = 0;
			
			GarageMenu.WakeUp();
						
			-- set up back input capturer
			w_CLICKCAPTURE = {};
			w_CLICKCAPTURE.SP = ScenePlane.CreateWithRenderTarget(4,4);
			w_CLICKCAPTURE.SP:BindToTextureFrame();
			w_CLICKCAPTURE.SP.ANCHOR:SetParam("scale", {x=32, y=32, z=32});
			w_CLICKCAPTURE.QFB = QuickFocusBox.Create(w_CLICKCAPTURE.SP.FRAME);
			w_CLICKCAPTURE.QFB:BindEvent("OnMouseDown", function()
				g_DISPATCHER:DispatchEvent("OnMouseDown_Stage");
				assert(VisualSlotter.OnSubmit, "VisualSlotter.OnSubmit is not bound to a function");
				VisualSlotter.OnSubmit();
			end);
			w_CLICKCAPTURE.QFB:BindEvent("OnMouseUp", function()
				g_DISPATCHER:DispatchEvent("OnMouseUp_Stage");
			end);
			w_CLICKCAPTURE.QFB:BindEvent("OnRightMouse", function()
				g_DISPATCHER:DispatchEvent("OnRightMouse_Stage");
				assert(VisualSlotter.OnBack, "VisualSlotter.OnBack is not a defined function");
				VisualSlotter.OnBack();
			end);
			w_CLICKCAPTURE.QFB:BindEvent("OnScroll", function(args)
				g_camZoom = mathex.clamp(g_camZoom - args.amount * 0.05, g_zoomConstraints.min, g_zoomConstraints.max);
				PRIVATE.StartUpdateManualCamera();
			end);
			--Component.CreateWidget([[<StillArt dimensions="dock:fill" style="texture:error; eatsmice:false"/>]], w_CLICKCAPTURE.QFB.WIDGET);
			
			-- Create the "Waiting" element
			assert(not w_PLEASE_WAIT);
			w_PLEASE_WAIT = {
				ANCHOR = Component.CreateAnchor(),
				OBJECTS = {
					BASE={SO=Component.CreateSceneObject("NewYou_Radial_Button_01A1")},
					ROLL1={SO=Component.CreateSceneObject("NewYou_Radial_Button_01B1")},
					ROLL2={SO=Component.CreateSceneObject("NewYou_Radial_Button_01C1")},
				},
				SP = ScenePlane.CreateWithRenderTarget(512, 32),
			}
			w_PLEASE_WAIT.ANCHOR:SetParam("translation", {x=0,y=-2,z=2.5});
			w_PLEASE_WAIT.ANCHOR:SetParam("rotation", {axis={x=1,y=0,z=0}, angle=100});
			for k,v in pairs(w_PLEASE_WAIT.OBJECTS) do
				v.SO:SetParam("tint", COLOR_BLUE);
				v.ANCHOR = v.SO:GetAnchor();
				v.ANCHOR:SetParent(w_PLEASE_WAIT.ANCHOR);
			end
			w_PLEASE_WAIT.SP.ANCHOR:SetParent(w_PLEASE_WAIT.ANCHOR);
			w_PLEASE_WAIT.SP.ANCHOR:SetParam("scale", {x=.5,y=.5,z=.5/16});
			w_PLEASE_WAIT.SP.ANCHOR:SetParam("translation", {x=0,y=0,z=-.1});
			
			w_PLEASE_WAIT.OBJECTS.ROLL1.SO:Show(false);
			w_PLEASE_WAIT.OBJECTS.ROLL2.SO:Show(false);
			w_PLEASE_WAIT.OBJECTS.BASE.SO:Show(false);
			
			w_PLEASE_WAIT.TEXT = Component.CreateWidget(
				[[<Text dimensions="dock:fill" style="font:Demi_15; halign:center; valign:center"/>]],
				w_PLEASE_WAIT.SP.FRAME);
			
			--[[
			local TEST = BUTTON_Create({});
			Component.CreateWidget('<StillArt dimensions="dock:fill" style="texture:icons; region:aid"/>', TEST.GROUP);
			TEST.ANCHOR:SetParam("translation", {x=0,y=-1,z=2.35});
			TEST.ANCHOR:SetParam("scale", {x=3,y=3,z=3});
			--]]
			
			w_TOPCORNER_BUTTONS = {
				ANCHOR = Component.CreateAnchor(),
				BUTTONS = {},
			};
			w_TOPCORNER_BUTTONS.ANCHOR:SetParam("translation", {x=-1.2,y=-1.6,z=3.05});
			w_TOPCORNER_BUTTONS.ANCHOR:SetParam("rotation", {axis={x=0,y=-0,z=1.1}, angle=-30});			
		else
			VisualSlotter.ActivateModel(nil);
			for idx,REGION in pairs(w_REGIONS) do
				REGION:Activate(false);
			end
			GarageMenu.Sleep();
			
			-- destroy back input capturer
			w_CLICKCAPTURE.QFB:Destroy();
			w_CLICKCAPTURE.SP:Destroy();
			
			--Destroy "Waiting" element
			Component.RemoveAnchor(w_PLEASE_WAIT.ANCHOR)
			for k,v in pairs(w_PLEASE_WAIT.OBJECTS) do
				Component.RemoveSceneObject(v.SO);
			end
			Component.RemoveWidget(w_PLEASE_WAIT.TEXT);
			w_PLEASE_WAIT.SP:Destroy();
			w_PLEASE_WAIT = nil;
			
			for k,BUTTON in pairs(w_TOPCORNER_BUTTONS.BUTTONS) do
				BUTTON:Destroy();
			end			
			Component.RemoveAnchor(w_TOPCORNER_BUTTONS.ANCHOR);
			w_TOPCORNER_BUTTONS = nil;
		end
	end
end

function VisualSlotter.LockZoom(min_zoom, max_zoom)
	if (not max_zoom) then
		-- treat this as VisualSlotter.LockZoom(zoom_level)
		max_zoom = min_zoom;
	end
	assert(type(min_zoom) == "number");
	assert(type(max_zoom) == "number");
	g_zoomConstraints = {min=min_zoom, max=max_zoom};
	g_camZoom = mathex.clamp(g_camZoom, g_zoomConstraints.min, g_zoomConstraints.max);

	if (g_active) then
		PRIVATE.StartUpdateManualCamera();
	end
end


function VisualSlotter.ActivateModel(model)
	if (g_model) then
		Sinvironment.EnableMouseFocus(g_model, false);
	end
	g_model = model;
	if (g_model) then
		local hack_ignore_head = Component.GetInfo() == "battleframegarage";
		Sinvironment.EnableMouseFocus(g_model, true, hack_ignore_head);
	end
end

function VisualSlotter.ActivateRegion(region_idx)
	if (g_activeREGION) then
		g_activeREGION:Activate(false);
	end
	if (region_idx) then
		local REGION = w_REGIONS[region_idx];
		REGION:Activate(true);
	end
end

function VisualSlotter.StartMouseDrag(max_vertical_offset)
	if (max_vertical_offset) then
		g_aimZOffsetMax = max_vertical_offset;
		PRIVATE.UpdateAimZOffset(g_aimZOffset);
	end
	if (cb_mouseDrag) then
		execute_callback(cb_mouseDrag);
	else
		g_mouseX, g_mouseY = Component.GetCursorPos();
		PRIVATE.UpdateMouseDrag();
	end
end

function VisualSlotter.SwitchToManualCamera(cam)
	g_camTarget = cam;
	g_cameraMode = CAM_MANUAL;
	if (cam.zoom) then
		g_camZoom = mathex.clamp(cam.zoom, g_zoomConstraints.min, g_zoomConstraints.max);
	end
	PRIVATE.StartUpdateManualCamera();
end

function VisualSlotter.SwitchToAnimatedCamera(model, hardpoint)
	-- Stop lerp of manual camera
	if (cb_UpdateCam) then
		cancel_callback(cb_UpdateCam);
		cb_UpdateCam = nil;
	end	

	g_cameraMode = CAM_ANIMATED;
	Sinvironment.SetAnimatedCamera(model, hardpoint or "HP_Camera");
end

function VisualSlotter.SwitchToAnchorCamera(cam)
	g_camTarget = cam;
	g_cameraMode = CAM_ANCHOR;
	if (cam.zoom) then
		g_camZoom = mathex.clamp(cam.zoom, g_zoomConstraints.min, g_zoomConstraints.max);
	end
	PRIVATE.StartUpdateManualCamera();
end

function VisualSlotter.ResetCamera(aimAtHeadFraction)
	PRIVATE.UpdateAimZOffset((aimAtHeadFraction or 0) * g_aimZOffsetMax);
	g_camZoom = 0;

	PRIVATE.StartUpdateManualCamera();
end

function VisualSlotter.BackOut()
	-- returns number of steps left it can back out from
	if (g_activeREGION) then
		local SUBMENU = g_activeREGION.ROOTMENU:GetActiveSubMenu();
		if (SUBMENU) then
			SUBMENU:SetLevel(GarageMenu.LEVEL_COMPACT, GarageMenu.LEVEL_COMPACT_DUR);
			VisualSlotter.ActivateRegion(g_activeREGION.idx);
			return 1;
		else
			g_activeREGION:Activate(false);
			return 0;
		end
	end
	return false;
end

function VisualSlotter.PleaseWait(message)
	if (not w_PLEASE_WAIT) then
		return;
	end
	
	function WaitSpin()
		if (not w_PLEASE_WAIT) then
			return;
		end
		
		local dur = .5;
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:SetParam("rotation", {axis={x=0,y=1,z=0}, angle=0});
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=120}, dur/3);
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=240}, dur/3);
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=360}, dur/3);
		
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:SetParam("rotation", {axis={x=0,y=1,z=0}, angle=0});
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=-120}, dur/3);
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=-240}, dur/3);
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:QueueParam("rotation", {axis={x=0,y=1,z=0}, angle=-360}, dur/3);
		
		w_PLEASE_WAIT.cb_WaitSpin = callback(WaitSpin, nil, dur);
	end

	if (message) then
		w_PLEASE_WAIT.ANCHOR:ParamTo("rotation", {axis={x=1,y=0,z=0}, angle=0}, .25);
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:Show(true);
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:Show(true);
		w_PLEASE_WAIT.OBJECTS.BASE.SO:Show(true);
		if (not w_PLEASE_WAIT.cb_WaitSpin) then
			WaitSpin();
		end
		w_PLEASE_WAIT.TEXT:SetText(message);
		w_PLEASE_WAIT.TEXT:ParamTo("alpha", 1.0, .2);
	else
		w_PLEASE_WAIT.OBJECTS.ROLL1.SO:Show(false, .25);
		w_PLEASE_WAIT.OBJECTS.ROLL2.SO:Show(false, .25);
		w_PLEASE_WAIT.OBJECTS.BASE.SO:Show(false, .25);
		w_PLEASE_WAIT.ANCHOR:ParamTo("rotation", {axis={x=1,y=0,z=0}, angle=120}, .25);
		if (w_PLEASE_WAIT.cb_WaitSpin) then
			cancel_callback(w_PLEASE_WAIT.cb_WaitSpin);
			w_PLEASE_WAIT.cb_WaitSpin = nil;
		end
		w_PLEASE_WAIT.TEXT:ParamTo("alpha", 0, .2);
	end
end

function VisualSlotter.AddTopCornerButton(args)
	local BUTTON = Button3D.Create();
	BUTTON:BindEvent("OnMouseDown", args.OnMouseDown);
	BUTTON:SetLabel(args.label, 1);
	BUTTON:SetTexture(args.texture, args.region);
	
	local idx = #w_TOPCORNER_BUTTONS.BUTTONS+1;
	w_TOPCORNER_BUTTONS.BUTTONS[idx] = BUTTON;
	BUTTON.ANCHOR:SetParent(w_TOPCORNER_BUTTONS.ANCHOR);
	BUTTON.ANCHOR:SetParam("translation", {x=(idx-1)*.2, y=0,z=0});
	
	return BUTTON;
end

-------------------
-- PRIVATE PARTS --
-------------------

function PRIVATE.Balls()
	log("Ahhh yeahhh!");
end

function PRIVATE.StartUpdateManualCamera()
	if (g_cameraMode ~= CAM_ANIMATED) then
		if (cb_UpdateCam) then
			execute_callback(cb_UpdateCam);
		else
			PRIVATE.UpdateCamera();
		end
	end
end

function PRIVATE.UpdateCamera()
	cb_UpdateCam = nil;

	local posTarget, aimTarget;
	if (g_cameraMode == CAM_MANUAL) then
		posTarget = g_camTarget.pos;
		aimTarget = g_camTarget.aim;
	elseif (g_cameraMode == CAM_ANCHOR) then
		-- pos and aim are anchors!
		posTarget = g_camTarget.pos:GetTransform().position;
		aimTarget = g_camTarget.aim:GetTransform().position;
	else
		-- we really shouldn't be in here
		return;
	end

	-- Camera zoom moves the camera closer to the aim target
	local offsetFac = g_camZoom * 1.5 + 0.25;
	posTarget = Vec3.Add(Vec3.Lerp(posTarget, aimTarget, g_camZoom), Vec3.New(0, 0, g_posZOffset * offsetFac));
	aimTarget = Vec3.Add(					  aimTarget			   , Vec3.New(0, 0, g_posZOffset * offsetFac));

	-- Lerp the camera towards the target with a lerp factor depending on the time step
	local f = 1 - 1 / (1 + g_camBrake * System.GetFrameDuration());
	g_cam.pos = Vec3.Lerp(g_cam.pos, posTarget, f);
	g_cam.aim = Vec3.Lerp(g_cam.aim, aimTarget, f);
		
	Sinvironment.SetManualCamera(g_cam.pos, g_cam.aim, 0);		
	
	if (g_active) then
		if (Vec3.Distance(g_cam.pos, posTarget) > 0.01 or 
			Vec3.Distance(g_cam.aim, aimTarget) > 0.01) then
			-- Still ways to go, schedule callback that's executed every frame
			cb_UpdateCam = callback(PRIVATE.UpdateCamera, nil, 0.001);
		else
			-- cancel rotation
			g_camBrake = 5;
			if (g_cameraMode == CAM_ANCHOR) then
				-- update less aggressively, looking for changes
				cb_UpdateCam = callback(PRIVATE.UpdateCamera, nil, 0.5);
			end
		end
	end
	
end

function PRIVATE.UpdateMouseDrag()
	local mouseX,mouseY = Component.GetCursorPos();
	
	if (ModelViewer) then
		ModelViewer.SpinModel((g_mouseX - mouseX) * 2);
	end
	-- scale panning speed by camera's distance from target
	local dist = Vec3.Distance(g_cam.pos, g_cam.aim);
	PRIVATE.UpdateAimZOffset(g_aimZOffset + (mouseY - g_mouseY) * dist / 512);
	
	g_mouseX = mouseX;
	g_mouseY = mouseY;
	
	if (Component.GetMouseButtonState()) then
		-- Left mouse button still pressed, schedule callback
		cb_mouseDrag = callback(PRIVATE.UpdateMouseDrag, nil, 0.05);
	else
		-- Else cancel rotation
		cb_mouseDrag = nil;
	end
	
	-- Start updating cam for the offset
	PRIVATE.StartUpdateManualCamera();
end

function PRIVATE.UpdateAimZOffset(val)
	g_aimZOffset = mathex.clamp(val, -g_aimZOffsetMax, g_aimZOffsetMax);
	g_posZOffset = (math.exp(g_aimZOffset) - 1) * g_aimZOffsetMax;
end

------------
-- REGION --
------------

function VisualSlotter.CreateRegion(idx, SLOTS, methods)
	local REGION = {idx=idx};
	REGION.active = false;
	REGION.SLOTS = SLOTS or {};
	REGION.ROOTMENU = nil;
	
	-- bind functions
	REGION.Activate = REGION_Activate;
	REGION.AddSlot = REGION_AddSlot;
	REGION.RefreshOptions = REGION_RefreshOptions;
	REGION.Destroy = REGION_Destroy;
	
	if (methods) then
		REGION.OnSelect = methods.OnSelect;
	end
	
	assert(not w_REGIONS[REGION.idx], "Region already registered to "..idx);
	w_REGIONS[REGION.idx] = REGION;
	return REGION;
end

function REGION_Destroy(REGION)
	REGION:Activate(false);
	for k,SLOT in pairs(REGION.SLOTS) do
		SLOT:Destroy();
	end
	if (REGION.ROOTMENU) then
		REGION.ROOTMENU:Remove();
		REGION.ROOTMENU = nil;
	end
	
	w_REGIONS[REGION.idx] = nil;
	for k,v in pairs(REGION) do
		REGION[k] = nil;
	end
end

function VisualSlotter.GetActiveRegion()	return g_activeREGION;	end
function VisualSlotter.GetRegion(idx)		return w_REGIONS[idx];	end

function REGION_Activate(REGION, active, dur)
	if (active ~= REGION.active) then
		if (active) then
			if (g_activeREGION) then
				-- deactivate previous region
				g_activeREGION:Activate(false);
			end
			g_activeREGION = REGION;
			REGION.active = true;
			
			local ROOTMENU = REGION.ROOTMENU;
			if (not ROOTMENU) then
				-- create root/region menu
				ROOTMENU = GarageMenu.CreateRootMenu();
				if (REGION.OnSelect) then
					ROOTMENU.OnSelect = function(idx)
						for n, slot in ipairs(REGION.SLOTS) do
							if (slot.SUBMENU.handle == idx.handle) then
								REGION.OnSelect(REGION.idx, n);
								return;
							end
						end
					end
				end;
				
				-- load slots/submenus
				for i,SLOT in ipairs(REGION.SLOTS) do
					if not SLOT.hidden then
						local allow_reselection = SLOT.for_paintshop or false;
						local SUBMENU = ROOTMENU:CreateSubMenu(allow_reselection);
						SUBMENU:SetLabel(SLOT.label);
						SUBMENU.OnSelect = function(idx)
							if (not idx) then
								--warn("Nothing selected for "..SLOT.label.."; ignoring");
								return;
							end
							local item = SUBMENU:GetOption();
							-- Preview changes
							if (SLOT.Preview) then
								SLOT.Preview(item);
							end
							-- Apply changes
							SLOT.Apply(item);
							-- Misc
							if (SLOT.OnSelect) then
								SLOT.OnSelect(item);
							end
						end
						SLOT.SUBMENU = SUBMENU;
					end
					SLOT:RefreshOptions();
				end
				REGION.ROOTMENU = ROOTMENU;
			end
			
			ROOTMENU:AttachToEntity(g_model);
			ROOTMENU:Open(dur);
		else
			REGION.active = false;
			REGION.ROOTMENU:Close(dur);
			if (g_activeREGION == REGION) then
				g_activeREGION = nil;
			end
		end
	end
end

function REGION_AddSlot(REGION, slot)
	table.insert(REGION.slots, slot);
end

function REGION_RefreshOptions(REGION)
	for i,SLOT in ipairs(REGION.SLOTS) do
		SLOT:RefreshOptions();
	end
end

----------
-- SLOT --
----------
local DEFAULT_GetEligibility = function() return VisualSlotter.CAN_SLOT; end;

function VisualSlotter.CreateSlot(label, slot_info, methods)
	local SLOT = {label=label, slot_info=(slot_info or {min=1, max=1})};
	SLOT.item = nil;
	SLOT.active = false;
	SLOT.my_list = nil;
	SLOT.SUBMENU = nil;
	
	-- callbacks
	SLOT.Apply = methods.Apply;
	SLOT.Preview = methods.Preview;
	SLOT.IsPresent = methods.IsPresent;
	SLOT.GetEligibility = methods.GetEligibility or DEFAULT_GetEligibility;
	SLOT.GetOptions = methods.GetOptions;
	SLOT.OnSelect = methods.OnSelect;
	
	-- methods
	SLOT.Destroy = SLOT_Destroy;
	SLOT.Dirty = SLOT_Dirty;
	SLOT.RefreshOptions = SLOT_RefreshOptions;
	SLOT.Open = SLOT_Open;
	
	assert(SLOT.Apply, "methods param must contain a 'ApplyToContext(item)' function");
	assert(SLOT.IsPresent, "methods param must contain a 'IsPresent(item, context)' function");
	assert(SLOT.GetOptions, "methods param must contain a 'GetOptions(item, context)' function");
	
	return SLOT;
end

function SLOT_Destroy(SLOT)
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:Remove();
	end
	for k,v in pairs(SLOT) do
		SLOT[k] = nil;
	end
end

function SLOT_Dirty(SLOT)
	-- remove dirty lists
	SLOT.my_list = nil;
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:SetOptions({});
	end
end

function SLOT_RefreshOptions(SLOT, skip_selection)
	SLOT.my_list = SLOT:GetOptions();
	if (not SLOT.my_list) then
		error("bad list returned on slot "..SLOT.label);
	elseif (#SLOT.my_list == 0) then
		--warn("empty list for slot "..SLOT.label);
	end
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:SetOptions(SLOT.my_list, skip_selection);
		for i,item in ipairs(SLOT.my_list) do
			item.eligibility = SLOT.GetEligibility(item);
			if (SLOT.IsPresent(item) and not skip_selection) then
				SLOT.SUBMENU:SelectOption(i, true);
			end
		end
		if (SLOT.SUBMENU:GetLevel() == GarageMenu.LEVEL_BROWSE) then
			-- refresh the previews
			local GALLERY = SLOT.SUBMENU:GetGallery();
			GALLERY:LoadOptions(SLOT.my_list, SLOT.SUBMENU);
		end
	end
end

function SLOT_Open(SLOT, dur)
	if (SLOT.SUBMENU) then
		SLOT.SUBMENU:SetLevel(GarageMenu.LEVEL_BROWSE, dur or GarageMenu.LEVEL_BROWSE_DUR);
	else
		warn("no submenu for slot "..tostring(SLOT.label));
		log(tostring(SLOT));
	end
end
