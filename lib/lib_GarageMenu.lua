
--
-- lib_GarageMenu
--   by: Red 5 Studios
--		a menu used for customizing parts in the Sinvironment

GarageMenu = {};

require "table";
require "lib/lib_Colors"
require "lib/lib_Items"
require "lib/lib_QuickFocusBox"
require "lib/lib_ScenePlane"
require "lib/lib_Button3D"
require "lib/lib_EventDispatcher"

--[[
Usage:
	GarageMenu.Sleep();				-- releases resources
	GarageMenu.WakeUp();			-- prepares GarageMenu for duty
	GarageMenu.SetContext(fields);	-- supply data to help provide context for the appearance of Preview's
	GarageMenu.ResetContext();		-- resets context
	GarageMenu.OnEscape = function	-- called when user presses Escape (optional)

	ROOTMENU = GarageMenu.CreateRootMenu();
	ROOTMENU:AttachToEntity(entityId);
	ROOTMENU:Remove();
	ROOTMENU:Open([dur]);
	ROOTMENU:Close([dur]);
	ROOTMENU:GetAnchor()
	ROOTMENU.OnSelect = function(SUBMENU);
	list_of_MENUs = ROOTMENU:GetSubMenus();

	SUBMENU = ROOTMENU.CreateSubMenu(allow_reselection);	-- creates an instance of the GarageMenu; if allow_reselection is true, selecting the same item multiple times will fire OnSelect each time
	SUBMENU = ROOTMENU.GetActiveSubMenu();					-- returns the active sub menu
	SUBMENU:Remove();
	SUBMENU:SetLabel(text);
	SUBMENU:SetOptions(options);
	SUBMENU:SelectOption(idx, [highlight_only=false]);
	local item = SUBMENU:GetOption()
	GALLERY = SUBMENU:GetGallery();
	SUBMENU.OnSelect = function(idx);
	SUBMENU.OnInspect = function();
	SUBMENU.OnBrowse = function();
	SUBMENU:SetLevel(LEVEL);
	local LEVEL = SUBMENU:GetLevel();
	
	GALLERY = GarageMenu.CreateGallery(rows, columns);
	GALLERY:Remove();
	GALLERY:Open(dur);
	GALLERY:Close(dur);
	GALLERY:SetOpenCloseParams(open_params, close_params);
	GALLERY:SetTooltipParams(equipped_params, hover_params)
	GALLERY:LoadOptions(options, SUBMENU);
	GALLERY:DisplayOptions(scroll_offset, dur);
	GALLERY:HighlightIndex(idx)
	
	PREVIEW = GarageMenu.CreatePreview(type, value[, GALLERY]);
	PREVIEW:Remove();
	PREVIEW:GetWidget();	-- to be deprecated when transition to 3D is completed
	PREVIEW:GetAnchor();
}
--]]


local ROOTMENU_API = {};
local SUBMENU_API = {};
local PREVIEW_API = {};
local GALLERY_API = {};

local w_ROOTMENUS = {};
local w_SUBMENUS = {};
local w_PREVIEWS = {};

local w_POPUP_MENU = {};	-- holds the root menus
local w_GALLERY;			-- displays rows of options
local g_active = false;
local g_preview_lod = 'high';
local g_ornament_lod = 'high';
local d_context = {};
local g_moused_PREVIEW = nil;	-- currently moused-over PREVIEW

-- PUBLIC CONSTANTS
--GarageMenu.LEVEL_OFF = 0;		-- standby mode
GarageMenu.LEVEL_COMPACT = 1;	-- collapsed into a single button mode
GarageMenu.LEVEL_INSPECT = 2;	-- expanded to show current selection
GarageMenu.LEVEL_BROWSE = 3;	-- displays a list of available options

-- level transition durations (seconds)
GarageMenu.LEVEL_COMPACT_DUR = 0.3;
GarageMenu.LEVEL_INSPECT_DUR = 0.3;
GarageMenu.LEVEL_BROWSE_DUR = 0.3;

GarageMenu.TINT_UI = Component.LookupColor("sinvironment_ui");
--GarageMenu.TINT_UI = {r=1.6, g=1.6, b=2};
GarageMenu.TINT_UI_AMBER = Component.LookupColor("sinvironment_ui_hot");
--GarageMenu.TINT_UI_HOT = {r=GarageMenu.TINT_UI_AMBER.red*2, g=GarageMenu.TINT_UI_AMBER.green*2, b=GarageMenu.TINT_UI_AMBER.blue*2};
GarageMenu.TINT_UI_HOT = {r=0.6, g=0.6, b=1};
GarageMenu.TINT_UI_RED = {r=1, g=0.1, b=.1};

GarageMenu.EMPTY_SLOT = {type="empty", eligibility=true, empty=true};

-- PRIVATE CONSTANTS
local SUBMENU_HEIGHT = 17;
local SUBMENU_SPACING = SUBMENU_HEIGHT+10;
local ROOTMENU_FRAME = Component.CreateFrame("TrackingFrame");

local Preview_HandleType = {};		-- table of methods for creating preview models
local PRIVATE = {};

ROOTMENU_FRAME:BindEvent("OnEscape", function()
	ROOTMENU_FRAME:ReleaseFocus();
	if (GarageMenu.OnEscape) then
		GarageMenu.OnEscape();
	end
end);

-- Functions

function GarageMenu.CreateRootMenu()
	local ROOTMENU = {};
	ROOTMENU.idx = #w_ROOTMENUS+1;
	ROOTMENU.GROUP = Component.CreateWidget('<Group dimensions="dock:fill"/>', ROOTMENU_FRAME);
	ROOTMENU.SMIs = {};
	ROOTMENU.active_SUBMENU = nil;
	w_ROOTMENUS[ROOTMENU.idx] = ROOTMENU;
	
	local RMI = {handle=ROOTMENU.idx};	-- Root Menu Interface
	local mt = {__index = function(t,key) return ROOTMENU_API[key]; end };
	setmetatable(RMI, mt);
	
	ROOTMENU.RMI = RMI;
	return RMI;
end

function GarageMenu.CreatePreview(type, value, GALLERY)
	local PREVIEW = {
		idx		= #w_PREVIEWS+1,
		type	= type,
		value	= value,
		fade_alpha = 1,	-- alpha set from :Fade
	};
	w_PREVIEWS[PREVIEW.idx] = PREVIEW;
	
	PREVIEW.RENDER_TARGET_NAME = "preview_rt_"..PREVIEW.idx;
	Component.CreateRenderTarget(PREVIEW.RENDER_TARGET_NAME, 160, 160);
	PREVIEW.TEXTURE_FRAME = Component.CreateFrame("TextureFrame", PREVIEW.RENDER_TARGET_NAME);
	PREVIEW.TEXTURE_FRAME:SetTexture(PREVIEW.RENDER_TARGET_NAME);
	
	PREVIEW.GROUP = Component.CreateWidget(
	[[<Group dimensions="dock:fill">
		<Text name="label" dimensions="dock:fill" style="font:Narrow_13; valign:top; halign:left; color:ffffff; wrap:true"/>
		<Group name="price" dimensions="left:0; right:100%-16; height:16; bottom:100%">
			<Text name="text" dimensions="left:0; right:100%-100t; height:100%" style="font:Narrow_15B; valign:bottom; halign:right; color:FFFFFF"/>
			<StillArt name="type" dimensions="right:100%; width:100t; height:100%" style="texture:currency_new; region:crystite_16"/>
		</Group>
	</Group>]], PREVIEW.TEXTURE_FRAME);
	PREVIEW.LABEL = PREVIEW.GROUP:GetChild("label");
	PREVIEW.PRICE = {GROUP=PREVIEW.GROUP:GetChild("price")};
	PREVIEW.PRICE.TEXT = PREVIEW.PRICE.GROUP:GetChild("text");
	PREVIEW.PRICE.ART = PREVIEW.PRICE.GROUP:GetChild("type");
	PREVIEW.QFB = QuickFocusBox.Create(PREVIEW.GROUP);
	
	PREVIEW.QFB:BindEvent("OnMouseDown", function()
		PREVIEW.PVI:OnMouseDown(GALLERY);
	end);
	PREVIEW.QFB:BindEvent("OnMouseEnter", function()
		PREVIEW.PVI:OnMouseEnter(GALLERY);
	end);
	PREVIEW.QFB:BindEvent("OnMouseLeave", function()
		PREVIEW.PVI:OnMouseLeave(GALLERY);
	end);
	if (GALLERY) then
		PREVIEW.QFB:BindEvent("OnScroll", function(args)
			GALLERY:OnScroll(args);
		end);
	end
	
	PREVIEW.ANCHOR = Component.CreateAnchor("preview");
	PREVIEW.CONTAINER_SO = Component.CreateSceneObject("garage_container"); -- garage_container
	PREVIEW.CONTAINER_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
	PREVIEW.CONTAINER_SO:SetParam("translation", {x=0, y=0, z=0});
	PREVIEW.CONTAINER_SO:SetParam("scale", {x=1, y=1, z=1});
	PREVIEW.CONTAINER_SO:SetParam("tint", GarageMenu.TINT_UI);
	
	-- set up
	PREVIEW.LABEL:SetText(value.name or value.localized_name or (type..": "..tostring(value.id)));
	
	if (Preview_HandleType[type]) then 
		Preview_HandleType[type](PREVIEW, value, d_context);
		if (PREVIEW.MODEL) then
			PREVIEW.MODEL_ANCHOR = Sinvironment.GetModelAnchor(PREVIEW.MODEL);
			PREVIEW.MODEL_ANCHOR:SetParent(PREVIEW.ANCHOR);
		end
	else
		warn("No preview method exists for type '"..type.."'!");
		PREVIEW.ITEM_SO = Component.CreateSceneObject("box");	-- temp
		--PREVIEW.ITEM_SO:SetTexture("gradients");
		PREVIEW.ITEM_SO:SetParam("scale", {x=.1, y=.1, z=.1});
		PREVIEW.ITEM_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
	end
	
	if (PREVIEW.ITEM_SO) then
		PREVIEW.ITEM_SO_ANCHOR = PREVIEW.ITEM_SO:GetAnchor();
	end
	
	if (value.cost and value.cost.amount > 0) then
		PREVIEW.PRICE.TEXT:SetText(value.cost.amount);
		if (value.cost.type) then
			PREVIEW.PRICE.ART:SetRegion(value.cost.type.."_16")
		else
			PREVIEW.PRICE.ART:SetRegion("crystite_16");
		end
		PREVIEW.PRICE.GROUP:Show(true);
	elseif (value.founders_only) then
		PREVIEW.PRICE.TEXT:SetText("*");
		PREVIEW.PRICE.GROUP:Show(true);
		PREVIEW.PRICE.ART:Show(false);
		--PREVIEW.PRICE.ART:SetTexture("icons", "Army");
	else
		PREVIEW.PRICE.GROUP:Show(false);
	end
	
	PREVIEW.UI_SO = Component.CreateSceneObject("plane");
	PREVIEW.UI_SO:SetTextureFrame(PREVIEW.TEXTURE_FRAME);
	PREVIEW.UI_SO:SetParam("scale", {x=.32, y=.32, z=.32});
	PREVIEW.UI_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
	PREVIEW.UI_SO:SetParam("tint", GarageMenu.TINT_UI);
	
	local PVI = {handle=PREVIEW.idx};	-- PreView Interface
	setmetatable(PVI, {__index = function(t,key) return PREVIEW_API[key]; end });
	PREVIEW.PVI = PVI;
	
	PREVIEW.PVI:OnMouseLeave();
	PREVIEW.PVI:SetEligibility(value.eligibility);
	
	return PVI;
end

function GarageMenu.CreateGallery(rows, columns)
	local GALLERY = GALLERY_API.Create(rows, columns);
	return GALLERY;
end

function GarageMenu.Sleep()
	if (g_active) then
		g_active = false;
		GALLERY_API.Remove(w_GALLERY);
		
		-- Clean up the Popup Menu
		Component.RemoveSceneObject(w_POPUP_MENU.BACKPLATE.SO);
		Component.RemoveSceneObject(w_POPUP_MENU.BACKING.SO);
		Component.RemoveAnchor(w_POPUP_MENU.ANCHOR);
	end
end

function GarageMenu.WakeUp()
	if (not g_active) then
		g_active = true;
		local COLS,ROWS = 3,3;
		w_GALLERY = GALLERY_API.Create(COLS, ROWS);
		
		-- Set up the Popup Menu
		w_POPUP_MENU.ANCHOR = Component.CreateAnchor();
		w_POPUP_MENU.BACKING = {SO=Component.CreateSceneObject("garage_anchor_frame")};
		
		local ROOTMENU_ANCHOR = ROOTMENU_FRAME:GetAnchor();
		ROOTMENU_FRAME:SetScene("sinvironment");
		ROOTMENU_FRAME:Show(true);
		ROOTMENU_ANCHOR:SetParent(w_POPUP_MENU.ANCHOR);
		ROOTMENU_ANCHOR:SetParam("translation", {x=.89,y=-.1,z=-.05});
		ROOTMENU_ANCHOR:SetParam("scale", {x=.125, y=.125, z=.125});
		
		w_POPUP_MENU.BACKING.ANCHOR = w_POPUP_MENU.BACKING.SO:GetAnchor();
		w_POPUP_MENU.BACKING.ANCHOR:SetParent(w_POPUP_MENU.ANCHOR);
		w_POPUP_MENU.BACKING.ANCHOR:SetParam("translation", {x=.8,y=0,z=-.150});
		w_POPUP_MENU.BACKING.ANCHOR:SetParam("scale", {x=1.35,y=1.35,z=1.35});
		
		w_POPUP_MENU.BACKING.SO:SetParam("tint", GarageMenu.TINT_UI);
		w_POPUP_MENU.ANCHOR:BindToCamera();
		w_POPUP_MENU.ANCHOR:SetParam("scale", {x=.0625, y=.0625, z=.0625});
		w_POPUP_MENU.ANCHOR:SetParam("translation", {x=0, y=.2, z=.015});
		w_POPUP_MENU.ANCHOR:SetParam("rotation", {axis={x=0, y=0, z=1}, angle=100});
		
		w_POPUP_MENU.BACKPLATE = {SO=Component.CreateSceneObject("plane")};
		w_POPUP_MENU.BACKPLATE.SO:SetParam("tint", {r=0, g=0, b=0, a=1.0});
		w_POPUP_MENU.BACKPLATE.SO:SetParam("scale", {x=1.5, y=2.5, z=2.0});
		w_POPUP_MENU.BACKPLATE.SO:SetSortOrder(12);
		w_POPUP_MENU.BACKPLATE.SO:SetTexture("gradients", "blur_square");
		w_POPUP_MENU.BACKPLATE.ANCHOR = w_POPUP_MENU.BACKPLATE.SO:GetAnchor();
		w_POPUP_MENU.BACKPLATE.ANCHOR:SetParent(w_POPUP_MENU.BACKING.ANCHOR);
		w_POPUP_MENU.BACKPLATE.ANCHOR:SetParam("translation", {x=.05,y=.2,z=0});
		
		w_POPUP_MENU.Show = function(visible, dur)
			local alpha;
			if (visible) then alpha = 1; else alpha = 0; end;

			w_POPUP_MENU.BACKPLATE.SO:ParamTo("alpha", alpha, dur);
			w_POPUP_MENU.BACKING.SO:ParamTo("alpha", alpha, dur);
			ROOTMENU_FRAME:ParamTo("alpha", alpha, dur);

			w_POPUP_MENU.BACKPLATE.SO:SetHitTestVisible(visible);
			w_POPUP_MENU.BACKING.SO:SetHitTestVisible(visible);
			ROOTMENU_FRAME:SetInteractable(visible);
		end
		w_POPUP_MENU.Show(false, 0);	-- start off hidden
	end
end

function GarageMenu.SetContext(fields)
	for k,v in pairs(fields) do
		d_context[k] = v;
	end
	
	-- default warpaint colors
	if (d_context.warpaint_colors) then
		if (PRIVATE.IsEmpty(d_context.warpaint_colors[1])) then
			-- use defaults from battleframe
			local bframe = d_context.battleframe;
			if (bframe and bframe.visuals) then
				d_context.warpaint_colors = bframe.visuals.warpaint_colors;
			else
				d_context.warpaint_colors = nil;
			end
		end
	end
end

function GarageMenu.ResetContext()
	d_context = {};
end

----------------
--  ROOTMENU  --
----------------

function ROOTMENU_API.AttachToEntity(RMI, entityId)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	ROOTMENU.GROUP:SetDims("left:0; right:100%; top:25%; bottom:75%");
end

function ROOTMENU_API.Remove(RMI)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	while (ROOTMENU.SMIs[1]) do
		ROOTMENU.SMIs[1]:Remove();
	end
	Component.RemoveWidget(ROOTMENU.GROUP);
	
	w_ROOTMENUS[ROOTMENU.idx] = nil;
	ROOTMENU.idx = nil;
	RMI.handle = nil;
end

function ROOTMENU_API.GetAnchor(RMI)
	return w_POPUP_MENU.ANCHOR;
end

function ROOTMENU_API.Open(RMI, dur)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	
	-- close all other ROOTMENU's
	for k,R in pairs(w_ROOTMENUS) do
		if (R.is_open and R ~= ROOTMENU) then
			R.RMI:Close(dur);
		end
	end
	
	dur = dur or 0.3;
	ROOTMENU.is_open = true;
	ROOTMENU.GROUP:ParamTo("alpha", 1.0, dur);
	ROOTMENU.GROUP:Show(true);
	local rotation = w_POPUP_MENU.ANCHOR:GetParam("rotation");
	if (rotation.angle * rotation.axis.z < -90) then
		w_POPUP_MENU.ANCHOR:SetParam("rotation", {axis={x=0, y=0, z=1}, angle=100});
	end
	w_POPUP_MENU.ANCHOR:ParamTo("rotation", {axis={x=0, y=0, z=1}, angle=30}, dur);
	w_POPUP_MENU.Show(true, dur);
	
	if (ROOTMENU.active_SUBMENU) then
		ROOTMENU.active_SUBMENU.SMI:SetLevel(GarageMenu.LEVEL_COMPACT, GarageMenu.LEVEL_COMPACT_DUR);
		ROOTMENU.active_SUBMENU = nil;
	end
end

function ROOTMENU_API.Close(RMI, dur)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	dur = dur or 0.3;
	ROOTMENU.is_open = false;
	ROOTMENU.GROUP:ParamTo("alpha", 0, dur);
	ROOTMENU.GROUP:Show(false, dur);
	w_POPUP_MENU.ANCHOR:ParamTo("rotation", {axis={x=0, y=0, z=1}, angle=-100}, dur);
	w_POPUP_MENU.Show(false, dur);
	
	if (ROOTMENU.active_SUBMENU) then
		ROOTMENU.active_SUBMENU.SMI:SetLevel(GarageMenu.LEVEL_COMPACT, GarageMenu.LEVEL_COMPACT_DUR);
		ROOTMENU.active_SUBMENU = nil;
	end
end

function ROOTMENU_API.GetActiveSubMenu(RMI)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	if (ROOTMENU.active_SUBMENU) then
		return ROOTMENU.active_SUBMENU.SMI;
	end
	return nil;
end

function ROOTMENU_API.CreateSubMenu(RMI, allow_reselection)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	local SUBMENU = {idx=(#w_SUBMENUS+1), ROOTMENU=ROOTMENU};
	w_SUBMENUS[SUBMENU.idx] = SUBMENU;
	
	--[[
	SUBMENU = {
		idx			-- indexes into w_SUBMENUS
		ROOTMENU	-- parent object
		GROUP		-- main widget
		options		-- array of options for browsing
		PREVIEWS	-- PREVIEWs for browsing
		DISPATCHER	-- Event Dispatcher
		selected_idx -- index into [options]
		allow_reselection -- does selecting the same item multiple times fire the OnSelect event?
	}
	--]]
	
	SUBMENU.GROUP = Component.CreateWidget(
		[[<Group dimensions="dock:fill">
			<Text name="label" dimensions="dock:fill" style="halign:left; valign:center; font:Demi_13"/>
			<FocusBox name="main_focus" dimensions="dock:fill">
				<Events>
					<OnMouseDown bind="_GarageMenu_SubmenuMain_OnMouseDown"/>
					<OnMouseEnter bind="_GarageMenu_SubmenuMain_OnMouseEnter"/>
					<OnMouseLeave bind="_GarageMenu_SubmenuMain_OnMouseLeave"/>
				</Events>
			</FocusBox>
		</Group>]],
		ROOTMENU.GROUP);
	SUBMENU.LABEL = SUBMENU.GROUP:GetChild("label");
	SUBMENU.LABEL:SetTextColor(GarageMenu.TINT_UI_HOT);
	SUBMENU.FOCUS = SUBMENU.GROUP:GetChild("main_focus");
	SUBMENU.FOCUS:SetTag(SUBMENU.idx);
	SUBMENU.DISPATCHER = EventDispatcher.Create(SUBMENU);
	SUBMENU.PREVIEWS = {};
	SUBMENU.options = {};
	SUBMENU.allow_reselection = allow_reselection or false;
	
	SUBMENU.SELECTED_GROUP = Component.CreateWidget('<Group dimensions="left:100%+10; top:0; height:100; width:100"/>', SUBMENU.GROUP);
	SUBMENU.SELECTED_GROUP:SetParam("alpha", 0);
	
	SUBMENU.BROWSE_GROUP = Component.CreateWidget('<Group dimensions="left:100%+10; top:0; height:300; width:300"/>', SUBMENU.GROUP);
	SUBMENU.BROWSE_GROUP:SetParam("alpha", 0);
	
	local MI_idx = #ROOTMENU.SMIs + 1;
	SUBMENU.GROUP:SetDims("left:0; width:150; height:"..SUBMENU_HEIGHT.."; top:"..(SUBMENU_SPACING*(MI_idx-1)));
	
	local SMI = {handle=SUBMENU.idx};	-- SubMenu Interface
	local mt = {__index = function(t,key) return SUBMENU_API[key]; end };
	setmetatable(SMI, mt);
	
	SUBMENU.SMI = SMI;
	SUBMENU.DISPATCHER:Delegate(SUBMENU.SMI);
	
	table.insert(ROOTMENU.SMIs, SMI);
	return SMI;
end

function ROOTMENU_API.GetSubMenus(RMI)
	local ROOTMENU = PRIVATE.GetRootMenu(RMI);
	local submenus = {};
	if (#ROOTMENU.SMIs > 0) then
		for i = 1, #ROOTMENU.SMIs do
			submenus[i] = ROOTMENU.SMIs[i];
		end
	end
	return submenus;
end

---------------
--  SUBMENU  --
---------------

function SUBMENU_API.Remove(SMI)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	
	assert(not SUBMENU.ROOTMENU or SUBMENU.ROOTMENU.active_SUBMENU ~= SUBMENU, "close submenu before removing it");	
	Component.RemoveWidget(SUBMENU.GROUP);
	
	for i = 1, #SUBMENU.ROOTMENU.SMIs do
		if (SUBMENU.ROOTMENU.SMIs[i].handle == SMI.handle) then
			table.remove(SUBMENU.ROOTMENU.SMIs, i);
			break;
		end
	end
	
	w_SUBMENUS[SUBMENU.idx] = nil;
	SUBMENU.DISPATCHER:Destroy();
	SUBMENU.DISPATCHER = nil;
	SUBMENU.idx = nil;
	SUBMENU.SMI = nil;
	SMI.handle = nil;
end

function SUBMENU_API.SetLabel(SMI, text)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	SUBMENU.LABEL:SetText(text);
end

function _GarageMenu_SubmenuMain_OnMouseDown(args)
	local SUBMENU = w_SUBMENUS[tonumber(args.widget:GetTag())];
	--SUBMENU.SMI:SetLevel(GarageMenu.LEVEL_INSPECT, GarageMenu.LEVEL_INSPECT_DUR);
	SUBMENU.SMI:SetLevel(GarageMenu.LEVEL_BROWSE, GarageMenu.LEVEL_BROWSE_DUR);
	if (SUBMENU.ROOTMENU.RMI.OnSelect) then
		SUBMENU.ROOTMENU.RMI.OnSelect(SUBMENU.SMI);
	end
end

function _GarageMenu_SubmenuMain_OnMouseEnter(args)
	local SUBMENU = w_SUBMENUS[tonumber(args.widget:GetTag())];
	SUBMENU.moused = true;
	SUBMENU.LABEL:MoveTo("left:5; right:_", 0.2, 0, "ease-in");
	SUBMENU.LABEL:SetTextColor("#FFFFFF");
	SUBMENU.GROUP:ParamTo("alpha", 1.0, 0.2);
end

function _GarageMenu_SubmenuMain_OnMouseLeave(args)
	local SUBMENU = w_SUBMENUS[tonumber(args.widget:GetTag())];
	SUBMENU.moused = false;
	SUBMENU.LABEL:MoveTo("left:0; right:_", 0.2);
	SUBMENU.LABEL:SetTextColor(GarageMenu.TINT_UI_HOT);
	SUBMENU.GROUP:ParamTo("alpha", 1.0, 0.2);
end

function SUBMENU_API.SetOptions(SMI, options, skip_selection)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	-- options = {[i]={type, value}}
	
	assert(options, "invalid options list");
	SUBMENU.options = options;
	if( not skip_selection ) then
		SMI:SelectOption(nil);
	end
end

function SUBMENU_API.SelectOption(SMI, idx, highlight_only)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	SUBMENU.selected_idx = idx;
	local op;
	if (idx) then
		if SUBMENU.GALLERY and SUBMENU.GALLERY.options then
			--use the options from the gallery in case some options have been removed
			op = SUBMENU.GALLERY.options[idx]
		elseif SUBMENU.options then
			op = SUBMENU.options[idx];
		end
	end

	local optionChanged = op ~= SUBMENU.current_op;
	if (optionChanged) then
		SUBMENU.current_op = op;
		if (SUBMENU.GALLERY) then
			SUBMENU.GALLERY:HighlightIndex(idx);
		end
	end
	
	if ((optionChanged or SUBMENU.allow_reselection) and SUBMENU.SMI.OnSelect and not highlight_only) then
		SUBMENU.SMI.OnSelect(idx);
	end
end

function SUBMENU_API.GetOption(SMI)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	return SUBMENU.current_op;
end

function SUBMENU_API.GetGallery(SMI)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	return SUBMENU.GALLERY;
end

function SUBMENU_API.GetLevel(SMI)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	return SUBMENU.level;
end

function SUBMENU_API.SetLevel(SMI, level, dur)
	local SUBMENU = PRIVATE.GetSubMenu(SMI);
	
	-- maintain that only one SUBMENU per ROOTMENU can be above LEVEL_COMPACT level at any time
	local ROOTMENU = SUBMENU.ROOTMENU;
	if (level > GarageMenu.LEVEL_COMPACT) then
		if (ROOTMENU.active_SUBMENU and ROOTMENU.active_SUBMENU ~= SUBMENU) then
			-- level down prior active Submenu
			ROOTMENU.active_SUBMENU.SMI:SetLevel(GarageMenu.LEVEL_COMPACT, dur);
		end
		ROOTMENU.active_SUBMENU = SUBMENU;
	end
	
	local oldLevel = SUBMENU.level;
	
	if (oldLevel == GarageMenu.LEVEL_COMPACT) then
	elseif (oldLevel == GarageMenu.LEVEL_INSPECT) then
		SUBMENU.SELECTED_GROUP:ParamTo("alpha", 0, dur);
	elseif (oldLevel == GarageMenu.LEVEL_BROWSE) then
		SUBMENU.BROWSE_GROUP:ParamTo("alpha", 0, dur);
		w_GALLERY:Close(dur);
		SUBMENU.DISPATCHER:DispatchEvent("OnClose");
	end
	
	if (level == GarageMenu.LEVEL_COMPACT) then
		SUBMENU.LABEL:MoveTo("left:0; width:_", dur);		
		SUBMENU.SELECTED_GROUP:ParamTo("alpha", 0, dur);
	elseif (level == GarageMenu.LEVEL_INSPECT) then
		SUBMENU.LABEL:MoveTo("left:20; width:_", dur);
		SUBMENU.SELECTED_GROUP:ParamTo("alpha", 1, dur);
		if (SUBMENU.SMI.OnInspect) then
			SUBMENU.SMI.OnInspect();
		end
	elseif (level == GarageMenu.LEVEL_BROWSE) then
		-- clean up old Previews
		for k,PREVIEW in pairs(SUBMENU.PREVIEWS) do
			PREVIEW:Remove();
		end
		SUBMENU.PREVIEWS = {};
		-- populate with Previews
		if (#SUBMENU.options > 0) then
			if (not g_active) then
				GarageMenu.WakeUp();
			end
			w_GALLERY:LoadOptions(SUBMENU.options, SUBMENU.SMI);
		else
			warn("No options available!");
			w_GALLERY:LoadOptions({}, SUBMENU.SMI);
		end
		w_GALLERY:Open(dur);
		SUBMENU.BROWSE_GROUP:ParamTo("alpha", 1, dur);
		if (SUBMENU.SMI.OnBrowse) then
			SUBMENU.SMI.OnBrowse();
		end
		SUBMENU.DISPATCHER:DispatchEvent("OnOpen");
	end
	
	SUBMENU.level = level;
end

--------------------
--  GALLERY GRID  --
--------------------

GALLERY_API.anchor_level = {x=0, y=0, z=-.024};

function GALLERY_API.Create(ROWS, COLS)
	local GALLERY = {PREVIEWS={}, rows=ROWS, cols=COLS, idx="garage_gallery"};
	GALLERY.ANCHOR = Component.CreateAnchor(GALLERY.idx.."_anchor");
	GALLERY.PREVIEW_ANCHOR = Component.CreateAnchor(GALLERY.idx.."_preview_anchor");
	if (COLS <= 1) then
		GALLERY.FRAME_TOP = {SO=Component.CreateSceneObject("list_arrow_top_short")};
		GALLERY.FRAME_BOT = {SO=Component.CreateSceneObject("list_arrow_bottom_short")};
	elseif (COLS == 2) then
		GALLERY.FRAME_TOP = {SO=Component.CreateSceneObject("list_arrow_top_medium")};
		GALLERY.FRAME_BOT = {SO=Component.CreateSceneObject("list_arrow_bottom_medium")};
	else
		GALLERY.FRAME_TOP = {SO=Component.CreateSceneObject("list_arrow_top")};
		GALLERY.FRAME_BOT = {SO=Component.CreateSceneObject("list_arrow_bottom")};
	end
	
	local caps = {GALLERY.FRAME_TOP, GALLERY.FRAME_BOT};
	for i,v in ipairs(caps) do
		v.ANCHOR = v.SO:GetAnchor();
		v.ANCHOR:SetParent(GALLERY.ANCHOR);
		v.SO:SetParam("tint", GarageMenu.TINT_UI);
		
		v.SP = ScenePlane.CreateWithRenderTarget(4,4);
		v.SP:BindToTextureFrame();
		v.QFB = QuickFocusBox.Create(v.SP.FRAME);
		
		v.SP.ANCHOR:SetParent(v.ANCHOR);
		v.SP.SO:SetParam("scale", {x=1,y=1,z=.15});
		v.SP.SO:SetParam("translation", v.SO:GetParam("translation"));
		
		v.QFB:BindEvent("OnMouseEnter", function()
			if (not v.locked) then
				v.SO:ParamTo("tint", GarageMenu.TINT_UI_AMBER, .2, 0, "ease-in");
			end
		end);
		v.QFB:BindEvent("OnMouseLeave", function()
			v.SO:ParamTo("tint", GarageMenu.TINT_UI, .2, 0, "ease-in");
		end);
		v.QFB:BindEvent("OnMouseDown", function()
			if (not v.locked) then
				v.SO:SetParam("tint", GarageMenu.TINT_UI_HOT);
				v.SO:ParamTo("tint", GarageMenu.TINT_UI_AMBER, .2, 0, "ease-in");
				GALLERY:OnScroll({amount=i*2-3});
			end
		end);
	end
	
	GALLERY.FRAME_BACK = {SO=Component.CreateSceneObject("plane")}; -- plane
	GALLERY.FRAME_BACK.ANCHOR = GALLERY.FRAME_BACK.SO:GetAnchor();
	GALLERY.FRAME_BACK.ANCHOR:SetParent(GALLERY.ANCHOR);
	GALLERY.FRAME_BACK.ANCHOR:SetParam("translation", {x=0,y=.5,z=0});
	
	GALLERY.ANCHOR:SetParam("scale", {x=.05, y=.05, z=.05});
	GALLERY.ANCHOR:BindToCamera();
	
	GALLERY.PREVIEW_ANCHOR:SetParent(GALLERY.ANCHOR);
	
	local screenWidth, screenHeight = Component.GetScreenSize();
	local galleryOpenOffsetX = 0.075;
	-- assuming default of 0.075 is for 16:9 resolution, bring closer to center if resolution ratio is different
	galleryOpenOffsetX = _math.clamp(galleryOpenOffsetX * (0.5625 *screenWidth / screenHeight), 0.06, 0.075);	
	
	local s = 0.05;
	GALLERY.params = {open={
			translation={x=galleryOpenOffsetX,y=.18,z=GALLERY_API.anchor_level.z},
			rotation={axis={x=0,y=0,z=1}, angle=40},
		},
		closed={
			translation={x=0,y=3,z=GALLERY_API.anchor_level.z},
			rotation={axis={x=0,y=0,z=1}, angle=-90},
		},
		equipped_tooltip={
			translation={x=-.04,y=.2,z=-.02},
			rotation={axis={x=0,y=0,z=1}, angle=0},
			scale={x=s,y=s,z=s},
		},
		hover_tooltip={
			translation={x=.017,y=.2,z=-.02},
			rotation={axis={x=0,y=0,z=1}, angle=0},
			scale={x=s,y=s,z=s},
		},
	};
	
	-- set up focus box for back plate
	GALLERY.FRAME_BACK.RENDER_TARGET_NAME = GALLERY.idx.."_rt";
	Component.CreateRenderTarget(GALLERY.FRAME_BACK.RENDER_TARGET_NAME, 32,32);
	GALLERY.FRAME_BACK.TEXTURE_FRAME = Component.CreateFrame("TextureFrame");
	GALLERY.FRAME_BACK.TEXTURE_FRAME:SetTexture(GALLERY.FRAME_BACK.RENDER_TARGET_NAME);
	GALLERY.FRAME_BACK.SO:SetTextureFrame(GALLERY.FRAME_BACK.TEXTURE_FRAME);
	GALLERY.FRAME_BACK.QFB = QuickFocusBox.Create(GALLERY.FRAME_BACK.TEXTURE_FRAME);
	GALLERY.FRAME_BACK.QFB:BindEvent("OnScroll", function(args)
		GALLERY:OnScroll(args);
	end);
	
	GALLERY.options = {};
	GALLERY.display_offset = 0;	-- row idx offset
	GALLERY.preview_start_idx = 1;	-- first idx of loaded PREVIEW
	GALLERY.preview_end_idx = 0; -- last idx of loaded PREVIEW
	GALLERY.max_rows = 0;
	GALLERY.open = true;
	GALLERY.removed = false;
	
	GALLERY.BACKPLATE = {SO=Component.CreateSceneObject("plane")};
	GALLERY.BACKPLATE.SO:SetParam("tint", {r=0, g=0, b=0, a=1.0});
	GALLERY.BACKPLATE.SO:SetParam("scale", {x=2.5, y=2.5, z=2.5});
	GALLERY.BACKPLATE.SO:SetSortOrder(12);
	GALLERY.BACKPLATE.SO:SetTexture("gradients", "blur_square");
	GALLERY.BACKPLATE.ANCHOR = GALLERY.BACKPLATE.SO:GetAnchor();
	GALLERY.BACKPLATE.ANCHOR:SetParent(GALLERY.PREVIEW_ANCHOR);
	GALLERY.BACKPLATE.ANCHOR:SetParam("translation", {x=0,y=.2,z=0});
	
	GALLERY.SCROLL_PAGE = {	FRAME = Component.CreateFrame("TrackingFrame")	};
	GALLERY.SCROLL_PAGE.ANCHOR = GALLERY.SCROLL_PAGE.FRAME:GetAnchor();
	GALLERY.SCROLL_PAGE.TEXT = Component.CreateWidget([[
		<Text dimensions="dock:fill" style="font:Demi_9; halign:right; valign:center; visible:false"/>
	]], GALLERY.SCROLL_PAGE.FRAME);
	GALLERY.SCROLL_PAGE.ANCHOR:SetParent(GALLERY.FRAME_BOT.ANCHOR);
	GALLERY.SCROLL_PAGE.ANCHOR:SetParam("translation", {x=.20, y=-.15, z=0});
	GALLERY.SCROLL_PAGE.ANCHOR:SetParam("scale", {x=.25, y=.25, z=.25});
	
	local mt = {__index = function(t,key) return GALLERY_API[key]; end };
	setmetatable(GALLERY, mt);
	
	-- All scene objects
	GALLERY.AllSOs = { GALLERY.FRAME_TOP.SO, GALLERY.FRAME_BOT.SO, GALLERY.FRAME_BACK.SO, GALLERY.BACKPLATE.SO };	
	
	PRIVATE.AnimateGallery(GALLERY);
	GALLERY:Close(0);
		
	return GALLERY;
end

function GALLERY_API.Remove(GALLERY)
	if (GALLERY.removed) then
		return;
	end
	GALLERY.removed = true;
	-- Remove scene objects first since some use the render targets	
	for k,SO in pairs(GALLERY.AllSOs) do
		Component.RemoveSceneObject(SO);
	end
	GALLERY.AllSOs = {};

	GALLERY.FRAME_BACK.QFB:Destroy();
	Component.RemoveAnchor(GALLERY.ANCHOR);
	Component.RemoveAnchor(GALLERY.PREVIEW_ANCHOR);
	Component.RemoveRenderTarget(GALLERY.FRAME_BACK.RENDER_TARGET_NAME);
	Component.RemoveFrame(GALLERY.FRAME_BACK.TEXTURE_FRAME);
	Component.RemoveFrame(GALLERY.SCROLL_PAGE.FRAME);
	
	local caps = {GALLERY.FRAME_TOP, GALLERY.FRAME_BOT};
	for k,v in pairs(caps) do
		v.QFB:Destroy();
		v.SP:Destroy();
	end
	
	GALLERY:LoadOptions(nil);
	GALLERY.PREVIEWS = nil;
	GALLERY_SetSelectedTooltip(GALLERY, nil);
	
	if (GALLERY.cb_AnimateGallery) then
		cancel_callback(GALLERY.cb_AnimateGallery);
		GALLERY.cb_AnimateGallery = nil;
	end
end

function GALLERY_API.SetOpenCloseParams(GALLERY, open_params, close_params)
	for k,v in pairs(open_params) do
		GALLERY.params.open[k] = v;
	end
	for k,v in pairs(close_params) do
		GALLERY.params.closed[k] = v;
	end
end

function GALLERY_API.SetTooltipParams(GALLERY, equipped_params, hover_params)
	for k,v in pairs(equipped_params) do
		GALLERY.params.equipped_tooltip[k] = v;
	end
	for k,v in pairs(hover_params) do
		GALLERY.params.hover_tooltip[k] = v;
	end
end

function GALLERY_API.Open(GALLERY, dur)
	
	if (not GALLERY.open) then
		GALLERY.open = true;
		System.PlaySound("Play_SFX_NewYou_ItemMenuPopup");
		
		for key,val in pairs(GALLERY.params.open) do
			GALLERY.ANCHOR:ParamTo(key, val, dur);
		end
		local delay = dur;
		GALLERY.FRAME_TOP.ANCHOR:ParamTo("translation", {x=0,y=0,z=.55}, dur, delay);
		--GALLERY.FRAME_BOT.ANCHOR:ParamTo("translation", {x=0,y=0,z=-.55}, dur, delay);
		GALLERY.PREVIEW_ANCHOR:ParamTo("scale", {x=1, y=1, z=1}, dur, delay);
		GALLERY.PREVIEW_ANCHOR:ParamTo("rotation", {axis={x=1, y=0, z=0}, angle=0}, dur, delay);

		for k,SO in pairs(GALLERY.AllSOs) do
			SO:ParamTo("alpha", 1, dur, delay);
			SO:SetHitTestVisible(true);
		end
		for k,PREVIEW in pairs(GALLERY.PREVIEWS) do
			PREVIEW:Show(true, dur, delay);
		end

		w_POPUP_MENU.ANCHOR:ParamTo("rotation", {axis={x=0, y=0, z=1}, angle=-100}, dur);
		w_POPUP_MENU.Show(false, dur);
		
		if (GALLERY.selected_idx and GALLERY.options) then
			GALLERY_SetSelectedTooltip(GALLERY, GALLERY.options[GALLERY.selected_idx]);			
		end
		
		GALLERY:createGalleryLights(delay);
	end
end

function GALLERY_API.IsOpen(GALLERY)
	return GALLERY.open
end

function GALLERY_API.Close(GALLERY, dur)
	
	if (GALLERY.open) then
		GALLERY.open = false;
		GALLERY.FRAME_TOP.ANCHOR:ParamTo("translation", {x=0,y=0,z=0}, dur);
		GALLERY.FRAME_BOT.ANCHOR:ParamTo("translation", {x=0,y=0,z=0}, dur);
		GALLERY.PREVIEW_ANCHOR:ParamTo("scale", {x=1, y=.1, z=1}, dur);
		GALLERY.PREVIEW_ANCHOR:ParamTo("rotation", {axis={x=1, y=0, z=0}, angle=90}, dur);
		
		local delay = dur;
		for key,val in pairs(GALLERY.params.closed) do
			GALLERY.ANCHOR:ParamTo(key, val, dur, delay);
		end
		for k,SO in pairs(GALLERY.AllSOs) do
			SO:ParamTo("alpha", 0, dur, delay);
			SO:SetHitTestVisible(false);
		end
		for k,PREVIEW in pairs(GALLERY.PREVIEWS) do
			PREVIEW:Show(false, dur, delay);
		end
		GALLERY_SetSelectedTooltip(GALLERY, nil);
		
		GALLERY:destroyGalleryLights();
	end
end

-- those are hardcoded lights to light up objects in gallery. Its bind to the gallery anchor so its shouldnt be a problem to change gallery position
-- values was tried to be set in the way that they dont interact with any scene lighting
function GALLERY_API.createGalleryLights(GALLERY, delay)
	GALLERY.cb_createGalleryLights = callback(function()
		GALLERY.cb_createGalleryLights = nil;

		GALLERY.lightID = Sinvironment.CreateLight("omni");
		Sinvironment.SetLightColor(GALLERY.lightID, 0.8, 0.9, 1, 0.8);
		Sinvironment.SetLightFadeParams(GALLERY.lightID, 0, 0, 0.2, 0.2);
		Sinvironment.SetLightSize(GALLERY.lightID, 0.2, 0.0, 0.2);
		local lightAnchor = Sinvironment.GetLightAnchor(GALLERY.lightID);
		lightAnchor:SetParent(GALLERY.PREVIEW_ANCHOR);
		lightAnchor:SetParam("translation", {x=0.0, y=-0.2, z=0.0 }, 5);
	end, nil, delay or 0);
end

function GALLERY_API.destroyGalleryLights(GALLERY)
	if (GALLERY.cb_createGalleryLights) then
		cancel_callback(GALLERY.cb_createGalleryLights);
	end
	
	if (GALLERY.lightID ~= nil) then
		Sinvironment.RemoveLight(GALLERY.lightID);
	end
end

function GALLERY_API.LoadOptions(GALLERY, options, SUBMENU_SMI)
	-- clear out existing options
	for k,PREVIEW in pairs(GALLERY.PREVIEWS) do
		PREVIEW:Remove();
	end
	GALLERY.PREVIEWS = {};
	local SUBMENU;
	if (SUBMENU_SMI) then SUBMENU = PRIVATE.GetSubMenu(SUBMENU_SMI); end
	-- load in new options
	GALLERY.preview_start_idx = 1;
	GALLERY.preview_end_idx = 0;
	GALLERY.selected_idx = nil;

	--reject invalid entries
	if options == nil then
		GALLERY.options = nil
	else
		GALLERY.options = {}
		for i = 1, #options do
			if options[i].cost == nil or ((options[i].cost.amount == nil) or (options[i].cost.amount <= 0) or 
				(options[i].cost.type and Component.CheckTextureExists("currency_new", options[i].cost.type.."_16")))then
				table.insert(GALLERY.options, options[i])
			end
		end
	end
	
	GALLERY.SUBMENU = SUBMENU;
	if (SUBMENU) then
		SUBMENU.GALLERY = GALLERY;
		GALLERY.selected_idx = SUBMENU.selected_idx;
	end
	GALLERY.max_rows = 1;
	if (options and #options > 0) then
		GALLERY.max_rows = math.ceil(#options / GALLERY.cols);
		GALLERY:DisplayOptions(0, .2);
	end
end

function GALLERY_API.DisplayOptions(GALLERY, scroll_offset, dur)
	scroll_offset = math.max(0, math.min(scroll_offset, GALLERY.max_rows - GALLERY.rows));	
	local top_idx = scroll_offset * GALLERY.cols + 1;
	local start_idx = math.max(1, top_idx - GALLERY.cols);				-- start from one row above the top
	local end_idx = math.min(#GALLERY.options, top_idx + (GALLERY.rows+1) * GALLERY.cols - 1);	-- end one row below the bottom
	
	GALLERY.SCROLL_PAGE.TEXT:Show(GALLERY.max_rows > GALLERY.rows);
	GALLERY.SCROLL_PAGE.TEXT:SetText(tostring(scroll_offset + 1).."/"..tostring(GALLERY.max_rows - GALLERY.rows + 1));
	
	if (GALLERY.display_offset == scroll_offset and 
		GALLERY.preview_start_idx == start_idx and 
		GALLERY.preview_end_idx == end_idx) then
		-- don't bother
		return;
	end
	
	-- trim out the expired PREVIEWS
	if (GALLERY.preview_start_idx <= GALLERY.preview_end_idx) then
		-- only trim lists of 1 or more previews
		if (start_idx > GALLERY.preview_start_idx) then
			for i = GALLERY.preview_start_idx, math.min(start_idx-1, GALLERY.preview_end_idx) do
				if (GALLERY.PREVIEWS[i]) then
					GALLERY.PREVIEWS[i]:Remove();
					GALLERY.PREVIEWS[i] = nil;
				end
			end
		end
		if (end_idx < GALLERY.preview_end_idx) then
			for i = math.max(end_idx+1, GALLERY.preview_start_idx), GALLERY.preview_end_idx do
				if (GALLERY.PREVIEWS[i]) then
					GALLERY.PREVIEWS[i]:Remove();
					GALLERY.PREVIEWS[i] = nil;
				end
			end
		end
	end
	
	local shift_dir = scroll_offset - GALLERY.display_offset;
	GALLERY.preview_start_idx = start_idx;
	GALLERY.preview_end_idx = end_idx;
	GALLERY.display_offset = scroll_offset;
	
	System.PlaySound("Play_SFX_NewYou_GearRackScroll");
	
	local anim_remaining = nil;
	local anim_dur = dur;
	if (GALLERY.scroll_anim_start) then
		-- set anim_remaining to be a % of unfinished animation from previous call to DisplayOptions
		anim_remaining = 1 - System.GetElapsedTime(GALLERY.scroll_anim_start) / GALLERY.scroll_anim_dur;
		if (anim_remaining > 0) then
			anim_dur = anim_dur * (1-anim_remaining*.5);
		else
			anim_remaining = nil;
		end
	end	
	
	-- introduce (and arrange) PREVIEWS
	for i=start_idx, end_idx do
		local PREVIEW = GALLERY.PREVIEWS[i];
		local ANCHOR;
		
		local col = (i-1)%GALLERY.cols + 1;
		local row = math.floor((i-1)/GALLERY.cols)+1-scroll_offset;
		local depth = 0;
		-- convert out-of-bounds rows into depth for animation effect
		if (row > GALLERY.rows) then
			depth = row - GALLERY.rows;
			row = GALLERY.rows;
		elseif (row < 1) then
			depth = 1-row;
			row = 1;
		end
		
		local delay = 0;
		local ease = "smooth";
		local translation = {x=0, y=(.5*depth), z=(.5-(row-.5)/GALLERY.rows)};
		--translation.x = .95*(col-.5)/GALLERY.cols-.5;
		translation.x = .95*((col*2-1-GALLERY.cols)/6);
		
		if (PREVIEW) then
			ANCHOR = PREVIEW:GetAnchor();
			-- advance towards end if part of interruption
			if (anim_remaining and anim_remaining > .5) then
				ease = "ease-in";
			end
		else
			local option = GALLERY.options[i];
			PREVIEW = GarageMenu.CreatePreview(option.preview_type or option.type, option, GALLERY);
			if PREVIEW ~= nil then
				PREVIEW.OnClick = function()
					System.PlaySound("Play_SFX_NewYou_GenericConfirm");
					if (GALLERY.SUBMENU) then
						local prev_idx = GALLERY.SUBMENU.selected_idx;
						GALLERY.SUBMENU.SMI:SelectOption(i);
					else
						GALLERY:HighlightIndex(i);
						assert(GALLERY.OnSelect, "assign an OnSelect callback function to this GALLERY object");
						GALLERY.OnSelect(i);
					end
				end
				ANCHOR = PREVIEW:GetAnchor();
				ANCHOR:SetParent(GALLERY.PREVIEW_ANCHOR);
				ANCHOR:SetParam("translation", {x=translation.x, y=translation.y+.1, z=translation.z-.1}, anim_dur);
				PREVIEW:Fade(0,0);
				delay = (i-start_idx)/(GALLERY.rows*GALLERY.cols)*dur;
				ease = "ease-in";
				GALLERY.PREVIEWS[i] = PREVIEW;
			end
		end

		if PREVIEW then
		
			if (GALLERY.selected_idx == i) then
				PREVIEW:Highlight(true);
			end
			
			--ANCHOR:FinishParam("translation");
			ANCHOR:ParamTo("translation", translation, anim_dur, delay, ease);
			PREVIEW:Fade(1-depth, anim_dur);
		end
	end
	
	-- record animation times
	GALLERY.scroll_anim_start = System.GetClientTime();
	GALLERY.scroll_anim_dur = dur;
	
	-- show/hide top/bottom arrows
	GALLERY.FRAME_TOP.locked = (top_idx <= 1);
	GALLERY.FRAME_BOT.locked = (top_idx + GALLERY.rows * GALLERY.cols - 1 >= #GALLERY.options);
	local caps = {GALLERY.FRAME_TOP, GALLERY.FRAME_BOT};
	for k,v in pairs(caps) do
		if (v.locked) then
			v.SO:ParamTo("tint", GarageMenu.TINT_UI, dur*.25, 0, "ease-in");
			v.SO:ParamTo("alpha", .4, dur*.25);
		else
			v.SO:ParamTo("alpha", 1, dur*.25);
		end
	end
	
	-- reposition bottom framing to accomodate number of rows shown
	local shown_rows = math.min(math.ceil(#GALLERY.options/GALLERY.cols), GALLERY.rows);
	local bottom_level = 0.1 - (shown_rows-1) * 0.325;
	GALLERY.FRAME_BOT.ANCHOR:ParamTo("translation", {x=0,y=0,z=bottom_level}, dur);
end

function GALLERY_API.HighlightIndex(GALLERY, idx)
	if (GALLERY.selected_idx and GALLERY.PREVIEWS) then
		local PREVIEW = GALLERY.PREVIEWS[GALLERY.selected_idx];
		if (PREVIEW) then
			PREVIEW:Highlight(false);
		end		
	end
	GALLERY.selected_idx = idx;
	if (idx and GALLERY.PREVIEWS) then
		local PREVIEW = GALLERY.PREVIEWS[GALLERY.selected_idx];
		if (PREVIEW) then
			PREVIEW:Highlight(true);
		end
		
		GALLERY_SetSelectedTooltip(GALLERY, GALLERY.options[idx]);
	end
end

function GALLERY_API.OnScroll(GALLERY, args)
	if( not GALLERY.scroll_locked ) then
		local dur = 0.5;
		local offset = GALLERY.display_offset + args.amount;
		GALLERY:DisplayOptions(offset, dur);
		
		--GALLERY.scroll_locked = true;
		callback(function()
			GALLERY.scroll_locked = nil;
		end, nil, dur-0.1)
	end
end

function GALLERY_SetSelectedTooltip(GALLERY, item)
	if (item and item.item_guid) then
		if (not GALLERY.SELECTED_TOOLTIP) then
			GALLERY.SELECTED_TOOLTIP = TOOLTIP_Create(GALLERY.idx);
			-- mark as equipped
			GALLERY.SELECTED_TOOLTIP:Tint(GarageMenu.TINT_UI_AMBER);
		end
		GALLERY.SELECTED_TOOLTIP:DisplayItem(item);
		if (GALLERY.open) then
			GALLERY.SELECTED_TOOLTIP:Show(true, .2);
			GALLERY.SELECTED_TOOLTIP:ApplyParams(GALLERY.params.equipped_tooltip, .2);
		end
	elseif (GALLERY.SELECTED_TOOLTIP) then
		GALLERY.SELECTED_TOOLTIP:Finalize();
		GALLERY.SELECTED_TOOLTIP = nil;
	end
	-- Hide tooltip when we selected its item
	if (g_moused_PREVIEW and g_moused_PREVIEW.TOOLTIP) then
		g_moused_PREVIEW.TOOLTIP:Show(false, 0);
		g_moused_PREVIEW = nil;
	end
end

function GALLERY_CompareSelectedWith(GALLERY, TOOLTIP)
	local gallery_item;
	if (GALLERY and GALLERY.SELECTED_TOOLTIP) then
		gallery_item = GALLERY.SELECTED_TOOLTIP.itemInfo;
		if (not TOOLTIP or gallery_item == TOOLTIP.itemInfo) then
			GALLERY.SELECTED_TOOLTIP.TIP:CompareAgainst(nil);
		else
			GALLERY.SELECTED_TOOLTIP.TIP:CompareAgainst(TOOLTIP.itemInfo);
		end
	end
	if (TOOLTIP) then
		if (gallery_item == TOOLTIP.itemInfo) then
			TOOLTIP.TIP:CompareAgainst(nil);
			TOOLTIP:Show(false, 0);
		else
			TOOLTIP.TIP:CompareAgainst(gallery_item);
		end
	end
end

---------------
--  PREVIEW  --
---------------

function PREVIEW_API.Remove(PVI)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	PREVIEW.QFB:Destroy();
	
	Component.RemoveWidget(PREVIEW.GROUP);
	Component.RemoveFrame(PREVIEW.TEXTURE_FRAME);
	Component.RemoveRenderTarget(PREVIEW.RENDER_TARGET_NAME);
	
	Component.RemoveSceneObject(PREVIEW.CONTAINER_SO);
	Component.RemoveSceneObject(PREVIEW.UI_SO);
	Component.RemoveAnchor(PREVIEW.ANCHOR);
	
	if (PREVIEW.ITEM_SO) then
		Component.RemoveSceneObject(PREVIEW.ITEM_SO);
	else
		Sinvironment.RemoveModel(PREVIEW.MODEL);
	end
	if (PREVIEW.Unhandle) then
		PREVIEW:Unhandle();
	end
	
	if (PREVIEW.TOOLTIP) then
		PREVIEW.TOOLTIP:Finalize();
		PREVIEW.TOOLTIP = nil;
	end
	
	w_PREVIEWS[PREVIEW.idx] = nil;
	PREVIEW.idx = nil;
	PREVIEW.PVI = nil;
	PVI.handle = nil;
end

function PREVIEW_API.Show(PVI, visible, dur, delay)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	local SOs = { PREVIEW.CONTAINER_SO, PREVIEW.ITEM_SO, PREVIEW.UI_SO };
	local alpha;
	if (visible) then alpha = PREVIEW.fade_alpha; else alpha = 0; end;
	for k,SO in pairs(SOs) do
		SO:ParamTo("alpha", alpha, dur, delay);
		SO:SetHitTestVisible(visible);			
	end
end
	
function PREVIEW_API.GetWidget(PVI)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	return PREVIEW.GROUP;
end

function PREVIEW_API.GetAnchor(PVI)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	return PREVIEW.ANCHOR;
end

function PREVIEW_API.Fade(PVI, alpha, dur)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	if (PREVIEW.ITEM_SO) then
		PREVIEW.ITEM_SO:ParamTo("alpha", alpha, dur, 0, "linear");
	elseif (PREVIEW.MODEL) then
		Sinvironment.AlphaModelTo(PREVIEW.MODEL, alpha, dur);
	end
	PREVIEW.fade_alpha = alpha;
	
	PREVIEW.UI_SO:ParamTo("alpha", alpha, dur, 0, "linear");
	PREVIEW.CONTAINER_SO:ParamTo("alpha", alpha, dur, 0, "linear");
end

function PREVIEW_API.Highlight(PVI, highlight)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	PREVIEW.highlighted = highlight;
	local TINT = GarageMenu.TINT_UI;
	if (highlight) then
		TINT = GarageMenu.TINT_UI_AMBER;
	end
	local dur = .1;
	PREVIEW.UI_SO:SetParam("tint", "#FFFFFF");
	PREVIEW.CONTAINER_SO:SetParam("tint", "#FFFFFF");
	PRIVATE.Preview_UpdateColor(PREVIEW, dur);	
end

function PREVIEW_API.OnMouseDown(PVI, GALLERY)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	if (PREVIEW.PVI.OnClick) then
		PREVIEW.PVI.OnClick();
	end
end

function PREVIEW_API.OnMouseEnter(PVI, GALLERY)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	PREVIEW.mouse_over = true;
	local dur = 0.1;
	--PREVIEW.LABEL:ParamTo("alpha", 1.0, dur);
	(PREVIEW.ITEM_SO_ANCHOR or PREVIEW.MODEL_ANCHOR):ParamTo("translation", {x=0,y=-.05,z=0}, dur, 0, "ease-in");
	if (PREVIEW.PVI.OnMouseOver) then
		PREVIEW.PVI.OnMouseOver();
	end
	if (PREVIEW.value.item_guid and not PREVIEW.TOOLTIP) then
		PREVIEW.TOOLTIP = TOOLTIP_Create(PREVIEW.idx);
		PREVIEW.TOOLTIP:DisplayItem(PREVIEW.value);
		PREVIEW.TOOLTIP:Show(true, dur);
		if (GALLERY) then
			PREVIEW.TOOLTIP:ApplyParams(GALLERY.params.hover_tooltip, dur);			
			GALLERY_CompareSelectedWith(GALLERY, PREVIEW.TOOLTIP);
		end
	end
	g_moused_PREVIEW = PREVIEW;
end

function PREVIEW_API.OnMouseLeave(PVI, GALLERY)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	PREVIEW.mouse_over = false;
	local dur = 0.2;
	--PREVIEW.LABEL:ParamTo("alpha", 0.6, dur);
	(PREVIEW.ITEM_SO_ANCHOR or PREVIEW.MODEL_ANCHOR):ParamTo("translation", {x=0,y=0,z=0}, dur, 0, "smooth");
	if (PREVIEW.TOOLTIP) then
		PREVIEW.TOOLTIP:Finalize();
		PREVIEW.TOOLTIP = nil;		
	end
	
	if (g_moused_PREVIEW == PREVIEW) then
		g_moused_PREVIEW = nil;
		if (GALLERY) then
			GALLERY_CompareSelectedWith(GALLERY, nil);
		end
	end
end

function PREVIEW_API.SetEligibility(PVI, eligibility)
	local PREVIEW = PRIVATE.GetPreview(PVI);
	if (PREVIEW.eligibility ~= eligibility) then
		PREVIEW.eligibility = eligibility;
		PRIVATE.Preview_UpdateColor(PREVIEW, .2);
	end
end

-- Private functions

function PRIVATE.GetRootMenu(RMI) return w_ROOTMENUS[RMI.handle]; end
function PRIVATE.GetSubMenu(SMI) return w_SUBMENUS[SMI.handle]; end
function PRIVATE.GetPreview(PVI) return w_PREVIEWS[PVI.handle]; end

function PRIVATE.IsEmpty(item)
	return (not item or item.empty);
end

function PRIVATE.AnimateGallery(GALLERY)
	-- minor oscillations to sell the 3D-ness of the gallery?
	local dur = 8;
	--GALLERY.ANCHOR:ParamTo("rotation", {axis={x=0,y=0,z=1}, angle=30}, dur/2, 0, "smooth");
	--GALLERY.ANCHOR:QueueParam("rotation", {axis={x=0,y=0,z=1}, angle=29}, dur/2, 0, "smooth");
	GALLERY.cb_AnimateGallery = callback(PRIVATE.AnimateGallery, GALLERY, dur);	
end

function PRIVATE.Preview_UpdateColor(PREVIEW, dur)
	local TINT = GarageMenu.TINT_UI;
	if (PREVIEW.eligibility ~= false) then
		if (PREVIEW.highlighted) then
			TINT = GarageMenu.TINT_UI_AMBER;
		end		
	else
		TINT = GarageMenu.TINT_UI_RED;
	end
	PREVIEW.UI_SO:ParamTo("tint", TINT, dur);
	PREVIEW.CONTAINER_SO:ParamTo("tint", TINT, dur);
end

function PRIVATE.PrepareHeadModel(context, head_id)
	local model = Sinvironment.CreateModel(g_preview_lod, false);
	Sinvironment.LoadCharacterComponent(model, "head", head_id or context.head.id);	-- use the head as the body!	
	Sinvironment.LoadCharacterComponent(model, "head_accessory_a", (context.head_accessories[1] or {}).accessory_id);
	Sinvironment.LoadCharacterComponent(model, "head_accessory_b", (context.head_accessories[2] or {}).accessory_id);
	Sinvironment.LoadCharacterEyes(model, context.eyes_id);
		
	Sinvironment.SetCharacterWarpaint(model, context.warpaint_colors);
	
	for slot,orn in pairs(context.ornaments) do
		Sinvironment.LoadCharacterOrnament(model, slot, orn.remote_id);
	end
		
	return model;
end

function PRIVATE.CenterHeadModel(model)
	local bounds = Sinvironment.GetModelBounds(model);
	local scale = 1; --0.25 / math.max(math.max(bounds.width, bounds.height), bounds.depth);
	Sinvironment.SetModelScale(model, scale);
	Sinvironment.SetModelPosition(model, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	Sinvironment.SetModelOrientation(model, {axis={x=0, y=0, z=1}, angle=180});	
end

Preview_HandleType["empty"] = function(PREVIEW, item, context)
	PREVIEW.ITEM_SO = Component.CreateSceneObject("plane");
	PREVIEW.ITEM_SO:SetTexture("icons", "no");
	PREVIEW.ITEM_SO:SetParam("scale", {x=.1, y=.1, z=.1});
	PREVIEW.ITEM_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
	PREVIEW.LABEL:SetTextKey("None");
end

Preview_HandleType["head"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context, item.id);
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["hair"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "head_accessory_a", item.accessory_id);
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["facial_hair"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "head_accessory_b", item.accessory_id);
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["hair_color"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context);
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, { item });
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["eye"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context);
	Sinvironment.LoadCharacterEyes(PREVIEW.MODEL, item.id);
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["eye_color"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = PRIVATE.PrepareHeadModel(context);
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, { item });
	PRIVATE.CenterHeadModel(PREVIEW.MODEL);
end

Preview_HandleType["skin_color"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	
	Sinvironment.SetCharacterSex(PREVIEW.MODEL, context.gender.sex);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "main_armor", 75662);	-- new you civilian outfit	
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, { item });
	
	Sinvironment.SetModelScale(PREVIEW.MODEL, 0.125);
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=0,y=0,z=-.1125});
	Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0, y=0, z=1}, angle=180});
end

Preview_HandleType["ornaments"]   = function(PREVIEW, item, context)
	ornamentVisualRecordIds, displayAngle = Sinvironment.GetOrnamentVisuals(item.id, 0, context.race, context.gender.id);
	if (#ornamentVisualRecordIds == 0) then
		warn("no visual records for ornament "..tostring(item.id).." : "..tostring(context.race).." "..tostring(context.gender));
		ornamentVisualRecordIds[1] = 0;	-- Won't display anything, but at least it won't break everything else
	end;

	PREVIEW.ITEM_SO = Component.CreateSceneObject(table.concat(ornamentVisualRecordIds, ","));
	PREVIEW.ITEM_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);

	-- Hacky way to get earrings display properly (namely rotated)
	local bounds = PREVIEW.ITEM_SO:GetModelBounds();
	local scale  = 0.20 / math.max(math.max(bounds.width, bounds.height), bounds.depth);
	PREVIEW.ITEM_SO:SetParam("scale", {x=scale, y=scale, z=scale});
	PREVIEW.ITEM_SO:SetParam("rotation", {axis={x=0,y=0,z=1}, angle=displayAngle}, dur);
	PREVIEW.ITEM_SO:SetParam("translation", {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	PREVIEW.ITEM_SO:SetDisplayLod(g_ornament_lod);
end

Preview_HandleType["gender"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	local SEX_ENUM = {[0]="male", [1]="female"};
	local sex_name = SEX_ENUM[item.id];
	PREVIEW.LABEL:SetTextKey(sex_name);
	
	Sinvironment.SetCharacterSex(PREVIEW.MODEL, sex_name);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "main_armor", 75662);	-- new you civilian outfit	
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, context.warpaint_colors);
	
	Sinvironment.SetModelScale(PREVIEW.MODEL, 0.125);
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=0,y=0,z=-.1125});
	Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0, y=0, z=1}, angle=180});
end

Preview_HandleType["voice_set"] = function(PREVIEW, item, context)
	PREVIEW.ITEM_SO = Component.CreateSceneObject("voiceprint");
	PREVIEW.ITEM_SO:SetParam("scale", {x=1, y=1, z=1});
	PREVIEW.ITEM_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
	PREVIEW.ITEM_SO:SetDisplayLod(g_ornament_lod);
end

Preview_HandleType["item"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	assert(item.type, tostring(item));
	Sinvironment.LoadItemType(PREVIEW.MODEL, item.itemTypeId);
	local bounds = Sinvironment.GetModelBounds(PREVIEW.MODEL);
	local size = math.max(math.max(bounds.width, bounds.height), bounds.depth);
	assert(size > 0, "Bad size for item "..tostring(item));
	--local scale = .50 * .25 + .50 * .3/size;
	local scale = .3 / size;
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	Sinvironment.SetModelScale(PREVIEW.MODEL, scale);
	
	if (item.type == "backpack") then
		Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0,y=0,z=1}, angle=180});
	elseif (item.type == "chassis") then
		Sinvironment.SetModelScale(PREVIEW.MODEL, .13);
	elseif (item.type == "weapon") then
		Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0, y=0, z=1}, angle=-90});	
		Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=bounds.y*scale, y=-bounds.x*scale, z=-bounds.z*scale});	-- Position needs to be rotated...
	else
		Sinvironment.SetModelScale(PREVIEW.MODEL, scale * .8);	-- scale this down so the sphere model doesn't obscure the title
	end
end

Preview_HandleType["backpack"] = Preview_HandleType["item"];
Preview_HandleType["weapon"] = Preview_HandleType["item"];
Preview_HandleType["ability_module"] = Preview_HandleType["item"];
Preview_HandleType["frame_module"] = Preview_HandleType["item"];

Preview_HandleType["chassis"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	assert(item.type, tostring(item));
	Sinvironment.SetCharacterSex(PREVIEW.MODEL, context.char_info.gender);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "main_armor", item.itemTypeId);
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, item.visuals.warpaint_colors);	-- armor, body suit, glow colors
	--Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, context.warpaint_colors);		-- skin, eye, hair
	
	local bounds = Sinvironment.GetModelBounds(PREVIEW.MODEL);
	local scale = .13;
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0,y=0,z=1}, angle=180});
	Sinvironment.SetModelScale(PREVIEW.MODEL, scale);
end

Preview_HandleType["warpaint_color"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	Sinvironment.SetCharacterSex(PREVIEW.MODEL, context.char_info.gender);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "main_armor", context.battleframe.itemTypeId);
	Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, {item} );
	
	local bounds = Sinvironment.GetModelBounds(PREVIEW.MODEL);
	local scale = .13;
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0,y=0,z=1}, angle=180});
	Sinvironment.SetModelScale(PREVIEW.MODEL, scale);
end

Preview_HandleType["warpaint_pattern"] = function(PREVIEW, item, context)
	PREVIEW.MODEL = Sinvironment.CreateModel(g_preview_lod, false);
	Sinvironment.SetCharacterSex(PREVIEW.MODEL, context.char_info.gender);
	Sinvironment.LoadCharacterComponent(PREVIEW.MODEL, "main_armor", context.battleframe.itemTypeId);
	if (context.warpaint_colors and not PRIVATE.IsEmpty(context.warpaint_colors[1])) then
		Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, context.warpaint_colors);
	elseif (context.battleframe) then
		-- defaults
		Sinvironment.SetCharacterWarpaint(PREVIEW.MODEL, context.battleframe.visuals.warpaint_colors);
	end
	Sinvironment.SetPatterns(PREVIEW.MODEL, {item} );
	
	local bounds = Sinvironment.GetModelBounds(PREVIEW.MODEL);
	local scale = .13;
	Sinvironment.SetModelPosition(PREVIEW.MODEL, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
	Sinvironment.SetModelOrientation(PREVIEW.MODEL, {axis={x=0,y=0,z=1}, angle=180});
	Sinvironment.SetModelScale(PREVIEW.MODEL, scale);
end

Preview_HandleType["decal"] = function(PREVIEW, item, context)
	PREVIEW.ITEM_SO = Component.CreateSceneObject("plane");
	local aspectRatio = Sinvironment.SetTattooTextureOnSceneObject(PREVIEW.ITEM_SO, item.id);
	if(aspectRatio) then
		PREVIEW.ITEM_SO:GetAnchor():SetParent(PREVIEW.ANCHOR);
		PREVIEW.ITEM_SO:SetParam("scale", {x=.25*math.min(aspectRatio, 1.0),y=.25,z=.25/math.max(aspectRatio, 1.0)});
		PREVIEW.ITEM_SO:SetDisplayLod(g_ornament_lod);
	end
end

----------------
--  TOOL TIP  --
----------------

function TOOLTIP_Create(id)
	local TOOLTIP = {};
	TOOLTIP.ANCHOR = Component.CreateAnchor();
	TOOLTIP.SUB_ANCHOR = Component.CreateAnchor();	-- this one is for internal use and animation
	TOOLTIP.SUB_ANCHOR:SetParent(TOOLTIP.ANCHOR);
	
	TOOLTIP.FRAME = Component.CreateFrame("TrackingFrame");
	TOOLTIP.FRAME_ANCHOR = TOOLTIP.FRAME:GetAnchor();
	TOOLTIP.GROUP = Component.CreateWidget('<Group dimensions="dock:fill" style="clip-children:false"/>', TOOLTIP.FRAME);
	TOOLTIP.GROUP:SetDims("center-x:50%; center-y:50%; width:250; height:250");
	
	TOOLTIP.SHADOW = Component.CreateWidget('<StillArt dimensions="dock:fill" style="tint:#000000"/>', TOOLTIP.GROUP);
	TOOLTIP.SHADOW:SetDims("center-x:50%; center-y:50%; width:150%; height:150%");
	TOOLTIP.SHADOW:SetTexture("gradients", "blur_square");
	TOOLTIP.TIP = LIB_ITEMS.CreateToolTip(TOOLTIP.GROUP);
	TOOLTIP.TIP.GROUP:SetDims("center-x:50%; center-y:50%; width:100%-20; height:100%-20");
	
	TOOLTIP.BACKING = {SO=Component.CreateSceneObject("tooltip_backing")};
	TOOLTIP.BACKING.SO:GetAnchor():SetParent(TOOLTIP.SUB_ANCHOR);
	TOOLTIP.BACKING.SO:SetParam("scale", {x=.5,y=.5,z=.5});
	
	TOOLTIP.FRAME_ANCHOR:SetParent(TOOLTIP.SUB_ANCHOR);
	TOOLTIP.FRAME_ANCHOR:SetParam("scale", {x=.3, y=.3, z=.3});
	
	TOOLTIP.ANCHOR:BindToCamera();
	TOOLTIP.ANCHOR:SetParam("scale", {x=.035,y=.035,z=.035});
	
	-- methods
	TOOLTIP.Finalize = TOOLTIP_Finalize;
	TOOLTIP.DisplayItem = TOOLTIP_DisplayItem;
	TOOLTIP.Show = TOOLTIP_Show;
	TOOLTIP.ApplyParams = TOOLTIP_ApplyParams;
	TOOLTIP.Tint = TOOLTIP_Tint;
	
	TOOLTIP:Tint(GarageMenu.TINT_UI);
	
	return TOOLTIP;
end

function TOOLTIP_Finalize(TOOLTIP)
	TOOLTIP.TIP:Destroy();
	Component.RemoveFrame(TOOLTIP.FRAME);
	Component.RemoveSceneObject(TOOLTIP.BACKING.SO);
	Component.RemoveAnchor(TOOLTIP.SUB_ANCHOR);
	Component.RemoveAnchor(TOOLTIP.ANCHOR);
	TOOLTIP.itemInfo = nil;
end

function TOOLTIP_DisplayItem(TOOLTIP, itemInfo)
	TOOLTIP.itemInfo = itemInfo;
	TOOLTIP.TIP:DisplayInfo(itemInfo);
end

function TOOLTIP_Tint(TOOLTIP, tint)
	TOOLTIP.BACKING.SO:SetParam("tint", Colors.Multiply(tint, 2));
end

function TOOLTIP_Show(TOOLTIP, show, dur)
	local ANCHOR = TOOLTIP.ANCHOR;
	local alpha = 1;
	
	if (show) then
		TOOLTIP.SUB_ANCHOR:ParamTo("rotation", {axis={x=1,y=0,z=0}, angle=0}, dur);
	else
		TOOLTIP.SUB_ANCHOR:ParamTo("rotation", {axis={x=1,y=0,z=0}, angle=90}, dur);
		alpha = 0;
	end
	
	TOOLTIP.BACKING.SO:ParamTo("alpha", alpha, dur);
	TOOLTIP.FRAME:ParamTo("alpha", alpha, dur);
end

function TOOLTIP_ApplyParams(TOOLTIP, params, dur)
	if (params.BindTo) then
		if (params.BindTo == "camera") then
			TOOLTIP.ANCHOR:Camera();
		elseif (params.BindTo == "world") then
			TOOLTIP.ANCHOR:BindToWorld();
		else
			TOOLTIP.ANCHOR:SetParent(params.BindTo);
		end
	end
	TOOLTIP.ANCHOR:SetParam("translation", params.translation);
	TOOLTIP.ANCHOR:ParamTo("rotation", params.rotation, dur);
	TOOLTIP.ANCHOR:SetParam("scale", params.scale);
end
