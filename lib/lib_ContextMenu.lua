
--
-- lib_ContextMenu
--  by: James Harless
--
-- Creates Menu widgets when requested on the fly, destroyed when closed.



--[[

	local CONTEXTMENU = ContextMenu.Create()			-- Creates the ContextMenu Object

	CONTEXTMENU:SetTitle(title, color)					-- Sets the title and color of Root Menu


	CONTEXTMENU:BindOnSelect(function[, args])			-- binds a function with the following returns as args when a Button is selected
															- menu, id of the entry's menu
															- id, unique id for the button that was pressed within the menu
															- value, value set at entry's creation if no value is is passed in place
																	(some items will return a value based on state)


	CONTEXTMENU:BindOnRequest(function[, args])			-- binds a function with the following returns the following args when called
															- MENU, menu object that accepts calls listed below
															- menu_id, requested menu id for creating new objects

															
	MENU Entries:
	MENU:AddMenu(params)								-- Creates a Menu which will return to OnRequest
															- label, sets the text of the menu
															- label_key, sets the text using lookup text (will override label)
															- menu, sets the menu_id of a new menu when moused over
	
	MENU:AddButton(params)								-- accepts the following params as a table
															- label, sets the text of the button
															- label_key, sets the text using lookup text (will override label)
															- id, sets the return id of the button
															- disable, dims and disables interactability
															- texture, sets the icon texture
															- region, sets the icon region
															- tint, sets the icon tint
	MENU:Addlabel(params)								-- accepts the following params as a table
															- label, sets the text of the button
															- label_key, sets the text using lookup text (will override label)
															- id, sets the return id of the button
															- disable, dims and disables interactability
															- texture, sets the icon texture
															- region, sets the icon region
															- tint, sets the icon tint
															
	MENU:AddCheck(params)								-- accepts the following params as a table
															- label, sets the text of the check button
															- label_key, sets the text using lookup text (will override label)
															- id, sets the return id of the button
															- checked, sets the state of the check button (true being checked)
															- disable, dims and disables interactability
															- radio_id, will link a group of check buttons in the menu that share the same radio_id into a group of radio style buttons, for normal checkboxes leave nil
															
	MENU:AddSeparator()									-- Creates a thin 1px Separator
	
--]]



if ContextMenu then
	return nil
end
ContextMenu = {}


require "math"
require "table"

require "lib/lib_RowScroller"


-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local PRIVATE = {}

local CONTEXT_API = {};
local CONTEXTMENU_METATABLE = {
	__index = function(t,key) return CONTEXT_API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in CONTEXTMENU"); end
}

local MENU_API = {};
local MENU_METATABLE = {
	__index = function(t,key) return MENU_API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in MENU"); end
}

local DIRECTION_UP = 0
local DIRECTION_DOWN = 1
local DIRECTION_LEFT = 0
local DIRECTION_RIGHT = 1

local BUTTON_HEIGHT = 23
local HEADER_HEIGHT = 26
local BLANK_HEIGHT = 5
local SEPERATOR_HEIGHT = 1

local ROWSCROLLER_SPACING = 2
local ROWSCROLLER_MAX_HEIGHT = 400

local DISABLED_ALPHA = 0.2

local MENU_MAXHEIGHT = 760
local MENU_WIDTH = 240
local MENU_SPACING = 10
local MENU_VMOUSEOFFSET = 3 + MENU_SPACING
local MENU_HMOUSEOFFSET = 10 + MENU_SPACING
local MENU_MAXBUTTONS = 10

local GROUP_HIGHLIGHT = [[<Group name="highlight" dimensions="left:0; right:100%; top:0; bottom:100%;" style="alpha:0"><Border id="highlight" dimensions="left:0; right:100%; top:0; bottom:100%;" class="ButtonSolid" style="alpha:0.3; tint:#888888; exposure:0.2" /></Group>]]

-- PanelFrame, used for detecting if the cursor leaves bounds
local bp_Frame = [[<PanelFrame dimensions="dock:fill" topmost="true" depth="1"/>]]
local bp_ScreenFocus = [[<FocusBox dimensions="dock:fill" />]]

-- Main Menu Canvas, has 10px space around window
local bp_ContextMenu = [[<FocusBox dimensions="dock:fill">
		<Group name="menu" dimensions="left:]]..MENU_SPACING..[[; right:100%-]]..MENU_SPACING..[[; top:]]..MENU_SPACING..[[; bottom:100%-]]..MENU_SPACING..[[">
			<Group name="foster_parent" dimensions="left:5; right:100%-5; top:5; bottom:100%-5" style="visible:false"/>
			<Group name="header" dimensions="top:0; left:0; width:100%; height:]]..HEADER_HEIGHT..[[">
				<Group dimensions="dock:fill" >
					<Border dimensions="dock:fill" class="ButtonBorder" style="alpha:0.05; exposure:1.0; padding:4"/>
					<Border dimensions="left:1; right:100%-1; top:1; bottom:100%-1" class="PanelSubBackDrop" style="padding:3; tint:#41494F; alpha:1"/>
					<Border dimensions="left:1; right:100%-1; top:1; bottom:100%-1; " class="ButtonFade" style="padding:3; tint:#1C1F22"/>
				</Group>
				<Text name="title" dimensions="left:8; right:100%; top:0; bottom:100%" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:false; color:orange"/>
			</Group>
			<Group name="body" dimensions="left:0; right:100%; top:]]..(HEADER_HEIGHT + 2)..[[; bottom:100%;" >
				<Border dimensions="center-x:50%; center-y:50%; width:100%-2; height:100%-2" class="ButtonSolid" style="tint:#000000; alpha:0.9; padding:4"/> 
				<Border name="rim" dimensions="dock:fill" class="ButtonBorder" style="alpha:0.2; exposure:0.7; padding:4"/>
				<Group name="scroller" dimensions="left:3; right:100%-3; top:1; bottom:100%-1"/>
			</Group>
		</Group>
</FocusBox>]]

-- Menu Button
local bp_MenuButton = [[<FocusBox dimensions="left:0; top:0; width:100%; height:]]..BUTTON_HEIGHT..[[">
	]]..GROUP_HIGHLIGHT..[[
	<StillArt name="sub_arrow" dimensions="right:100%-10; center-y:50%; width:7; height:9" style="texture:arrows; region:right; visible:true; alpha:0.6" />
	<Text name="label" dimensions="center-y:50%; height:100%; left:5; right:100%-5" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:true;"/>
</FocusBox>]]

-- Simple Label
local bp_Label = [[<Group dimensions="left:0; top:0; width:100%; height:]]..BUTTON_HEIGHT..[[">
	<StillArt name="icon" dimensions="left:10; center-y:50%; width:12; height:12" style="texture:icons; region:blank;" />
	<Text name="label" dimensions="center-y:50%; height:100%; left:26; right:100%-5" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:true;"/>
</Group>]]

-- Simple Button
local bp_Button = [[<FocusBox dimensions="left:0; top:0; width:100%; height:]]..BUTTON_HEIGHT..[[" class="ui_button">
	]]..GROUP_HIGHLIGHT..[[
	<StillArt name="icon" dimensions="left:10; center-y:50%; width:12; height:12" style="texture:icons; region:blank;" />
	<Text name="label" dimensions="center-y:50%; height:100%; left:26; right:100%-5" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:true;"/>
</FocusBox>]]

-- Simple Check Button
local bp_CheckButton = [[<FocusBox dimensions="left:0; top:0; width:100%; height:]]..BUTTON_HEIGHT..[[" class="ui_button">
	]]..GROUP_HIGHLIGHT..[[
	<StillArt name="check" dimensions="left:2; center-y:50%; height:115%; aspect:1" style="texture:CheckBox_White; region:check; tint:#AAFF0A; alpha:0;"/>
	<Text name="label" dimensions="center-y:50%; height:100%; left:26; right:100%-5" style="font:UbuntuMedium_9; halign:left; valign:center; wrap:true;"/>
</FocusBox>]]

-- Blank, no interaction
local bp_Blank = [[<Group dimensions="left:0; top:0; width:100%; height:]]..BLANK_HEIGHT..[["/>]]

-- Separator, no interaction
local bp_Separator = [[<Group dimensions="left:0; top:0; width:100%; height:]]..SEPERATOR_HEIGHT..[[">
	<StillArt dimensions="left:2; top:0; right:100%-2; height:1" style="texture:Colors; region:white; alpha:0.15" />
</Group>]]

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local cb_CloseContextMenu

-- ------------------------------------------
-- CONTEXTMENU
-- ------------------------------------------
function ContextMenu.Create()
	-- Creates a Context Object, not the functioning frames as they're created on the fly for performance reasons.
	local CONTEXTMENU = {
		-- Widget Holders
		FRAME = false,				-- Created on the Fly
		FOCUS = false,				-- Created with Frame
		WIDGETS = {					-- Created as needed
			MENU = {},
			ENTRY = {},
		},
		
		-- Variables
		title = false, --"Untitled Menu",	-- Title Name
		title_color = "orange",
		options = {},				-- Menu Tree
		
		open = {},					-- Open Menus (below root)
		selection = {},				-- {{index, "menu_id"}, {index, "menu_id"}} prior menu index
		horizontal = DIRECTION_RIGHT,
	
		pending_entries = {},
	
		OnRequest_Func = function() end,	-- Empty Function
		OnSelect_Func = function() end,		-- Empty Function
	}
	
	setmetatable(CONTEXTMENU, CONTEXTMENU_METATABLE)

	return CONTEXTMENU
end

-- ------------------------------------------
-- CONTEXT_API
-- ------------------------------------------
function CONTEXT_API.Show(CONTEXTMENU)
	-- Generates & Shows the Context Menu Root with Entries
	
	-- Generate the Frame
	PRIVATE.CreateFrame(CONTEXTMENU)
	
	-- Request Root Menu
	local MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id="root", title=CONTEXTMENU.title, title_color=CONTEXTMENU.title_color})
	
	-- Set Initial Mouse Alignment
	local alignment = PRIVATE.GetScreenPosition(CONTEXTMENU, MENU, nil, nil, true)
	MENU.GROUP:SetDims(alignment.halign.."; "..alignment.valign.."; width:"..MENU_WIDTH.."; height:_; relative:screen")
	
	-- Open Menu
	MENU:Open()
	
	-- Root menu begins with nothing selected, anything selected below root will be added
	CONTEXTMENU.selection = {}
	
	-- Show, 'nuff said
	CONTEXTMENU.FRAME:Show()
	System.PlaySound("switch_change")
end

function CONTEXT_API.Hide(CONTEXTMENU)
	-- Clean up Menu Entry Widgets
	for _,ENTRY in pairs(CONTEXTMENU.WIDGETS.ENTRY) do
		Component.RemoveWidget(ENTRY.GROUP)
		ENTRY = nil
	end
	CONTEXTMENU.WIDGETS.ENTRY = {}
	
	-- Clean up Menus
	for _,MENU in pairs(CONTEXTMENU.WIDGETS.MENU) do
		MENU.ROWSCROLLER:Destroy()
		Component.RemoveWidget(MENU.GROUP)
		MENU = nil
	end
	CONTEXTMENU.WIDGETS.MENU = {}
	
	-- Remove Frame
	PRIVATE.DestroyFrame(CONTEXTMENU)
end

function CONTEXT_API.Refresh(CONTEXTMENU)
	-- Clean up Menu Entry Widgets
	for _, ENTRY in pairs(CONTEXTMENU.WIDGETS.ENTRY) do
		Component.RemoveWidget(ENTRY.GROUP)
		ENTRY = nil
	end
	CONTEXTMENU.WIDGETS.ENTRY = {}
	
	--save tree
	local tree = {}
	for _, MENU in pairs(CONTEXTMENU.WIDGETS.MENU) do
		if MENU.IsOpen and MENU.parent_menus[#MENU.parent_menus] ~= MENU.id then
			local temp = MENU.parent_menus
			table.insert(temp, MENU.id)
			for _, id in ipairs(temp) do
				table.insert(tree, {id=id, init_x=CONTEXTMENU.WIDGETS.MENU[id].init_x, init_y=CONTEXTMENU.WIDGETS.MENU[id].init_y})
			end
			break
		end
	end
	
	-- Clean up Menus
	for _, MENU in pairs(CONTEXTMENU.WIDGETS.MENU) do
		MENU.ROWSCROLLER:Destroy()
		Component.RemoveWidget(MENU.GROUP)
		MENU = nil
	end
	CONTEXTMENU.WIDGETS.MENU = {}
	
	-- Recreate
	for i, data in ipairs(tree) do
		local MENU
		local header = false
		if i > 1 then
			local parent = tree[i-1].id
			local PARENT_MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=parent})
			local parent_menus = PARENT_MENU:GetParents()
			PARENT_MENU:AddParent(parent)
			MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=data.id, parent_menus=parent_menus})
		else
			MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id="root", title=CONTEXTMENU.title, title_color=CONTEXTMENU.title_color})
			header = true
		end

		local alignment = PRIVATE.GetScreenPosition(CONTEXTMENU, MENU, data.init_x, data.init_y, header)
		MENU.GROUP:SetDims(alignment.halign.."; "..alignment.valign.."; width:"..MENU_WIDTH.."; height:_; relative:screen")
		MENU:Open()
	end
end


function CONTEXT_API.BindOnSelect(CONTEXTMENU, OnSelect_Func)
	if type(OnSelect_Func) == "function" then
		CONTEXTMENU.OnSelect_Func = OnSelect_Func
	else
		warn("Binding must be a function!")
	end
end


function CONTEXT_API.BindOnRequest(CONTEXTMENU, OnRequest_Func)
	if type(OnRequest_Func) == "function" then
		CONTEXTMENU.OnRequest_Func = OnRequest_Func
	else
		warn("Binding must be a function!")
	end
end

function CONTEXT_API.SetTitle(CONTEXTMENU, title, color)
	CONTEXTMENU.title = title
	CONTEXTMENU.title_color = color or CONTEXTMENU.title_color
end

function CONTEXT_API.AddMenu(CONTEXTMENU, params)
	params.type = "menu"
	params.label = PRIVATE.LabelCheck(params)
	table.insert(CONTEXTMENU.pending_entries, params)
end

function CONTEXT_API.AddButton(CONTEXTMENU, params)
	params.type = "button"
	params.label = PRIVATE.LabelCheck(params)
	table.insert(CONTEXTMENU.pending_entries, params)
end

function CONTEXT_API.AddLabel(CONTEXTMENU, params)
	params.type = "label"
	params.label = PRIVATE.LabelCheck(params)
	table.insert(CONTEXTMENU.pending_entries, params)
end

function CONTEXT_API.AddCheck(CONTEXTMENU, params)
	params.type = "check"
	params.label = PRIVATE.LabelCheck(params)
	table.insert(CONTEXTMENU.pending_entries, params)
end

function CONTEXT_API.AddSeparator(CONTEXTMENU)
	table.insert(CONTEXTMENU.pending_entries, {type="seperator"}) 
end

-- ------------------------------------------
-- MENU
-- ------------------------------------------
function PRIVATE.CreateMenu(CONTEXTMENU, params)
	local GROUP = Component.CreateWidget(bp_ContextMenu, CONTEXTMENU.FRAME)
	local MENU = {
		GROUP = GROUP,
		
		-- Header
		HEADER = GROUP:GetChild("menu.header"),
		TITLE = GROUP:GetChild("menu.header.title"),
		
		-- Body
		BODY = GROUP:GetChild("menu.body"),
		SLIDER = GROUP:GetChild("menu.body.slider"),
		SCROLLER = GROUP:GetChild("menu.body.scroller"),
		FOSTER = GROUP:GetChild("menu.foster_parent"),
	
		-- Variables
		title = params.title,
		title_color = params.title_color or CONTEXTMENU.title_color,
		id = params.id,
		parent_menus = {},	-- Parent Menus
		
		offset = 0,
		IsOpen = false,
		isSubMenu = false,
		init_x = false,
		init_y = false,
	}
	
	MENU.GROUP:SetTag(tostring(params.id))
	MENU.ROWSCROLLER = RowScroller.Create(MENU.SCROLLER)
	MENU.ROWSCROLLER:SetSlider(RowScroller.SLIDER_DEFAULT)
	MENU.ROWSCROLLER:SetSpacing(ROWSCROLLER_SPACING)
	
	MENU.GROUP:BindEvent("OnMouseEnter", function(args)
		MENU:Open()
	end)
	
	setmetatable(MENU, MENU_METATABLE)
	
	CONTEXTMENU.WIDGETS.MENU[params.id] = MENU
	
	return MENU
end

-- ------------------------------------------
-- MENU_API
-- ------------------------------------------
function MENU_API.GetBounds(MENU)
	return MENU.GROUP:GetBounds()
end

function MENU_API.SetTitle(MENU)
	if MENU.title then
		MENU.TITLE:SetText(MENU.title)
		MENU.offset = HEADER_HEIGHT+2
		if MENU.title_color then
			MENU.TITLE:SetTextColor(MENU.title_color)
		end
	else
		MENU.HEADER:Hide()
		MENU.BODY:SetDims("left:_; top:0")
	end
end

function MENU_API.AddRow(MENU, ENTRY)
	local ROW = MENU.ROWSCROLLER:AddRow(ENTRY.tag)
	ROW:SetWidget(ENTRY.GROUP)
	ROW:UpdateSize({height=ENTRY.GROUP:GetBounds().height})
end

function MENU_API.UpdateParentMenus(MENU, parents)
	if not parents then return nil end
	for k,v in ipairs(parents) do
		MENU.parent_menus[k] = v
	end
end

function MENU_API.GetParents(MENU)
	return MENU.parent_menus
end

function MENU_API.Open(MENU)
	MENU.IsOpen = true
	MENU.GROUP:Show()
end

function MENU_API.Close(MENU)
	MENU.IsOpen = false
	MENU.GROUP:Hide()
end

function MENU_API.AddParent(MENU, parent)
	if not PRIVATE.IsEqualList(parent, MENU.parent_menus) then
		table.insert(MENU.parent_menus, parent)
	end
end

function MENU_API.ButtonClose(MENU)
	-- Used for Menu Buttons, allows MENU:Open() override when mouse enters.
	MENU.IsOpen = false
	MENU.GROUP:Hide(true, 0.1)
end

-- ------------------------------------------
-- PRIVATE
-- ------------------------------------------
function PRIVATE.CreateFrame(CONTEXTMENU)
	if not CONTEXTMENU.FRAME then
		CONTEXTMENU.FRAME = Component.CreateFrame(bp_Frame, "ContextMenu."..Component.GetInfo())
		CONTEXTMENU.FOCUS = Component.CreateWidget(bp_ScreenFocus, CONTEXTMENU.FRAME)
		
		CONTEXTMENU.FRAME:BindEvent("OnEscape", function()
			PRIVATE.OnSelect(CONTEXTMENU, nil, "OnClose")
			CONTEXTMENU:Hide()
		end)
		
		local FOCUS = CONTEXTMENU.FOCUS
		FOCUS:BindEvent("OnMouseEnter", function()
			cb_CloseContextMenu = callback(function()
				cb_CloseContextMenu = nil
				PRIVATE.OnSelect(CONTEXTMENU, nil, "OnClose")
				CONTEXTMENU:Hide()
			end, nil, 0.5)
		end)
		FOCUS:BindEvent("OnMouseLeave", function()
			if cb_CloseContextMenu then
				cancel_callback(cb_CloseContextMenu)
				cb_CloseContextMenu = nil
			end
		end)
	end
end

function PRIVATE.DestroyFrame(CONTEXTMENU)
	if CONTEXTMENU.FRAME then
		Component.RemoveWidget(CONTEXTMENU.FOCUS)
		Component.RemoveFrame(CONTEXTMENU.FRAME)
		CONTEXTMENU.FRAME = false
		CONTEXTMENU.FOCUS = false
	end
end

function PRIVATE.RequestMenu(CONTEXTMENU, params)
	if not CONTEXTMENU.WIDGETS.MENU[params.id] then
		-- Create a new Menu
		local MENU = PRIVATE.CreateMenu(CONTEXTMENU, params)
		
		-- Request Root Menu Entires
		CONTEXTMENU.OnRequest_Func(CONTEXTMENU, params.id, MENU.parent)
		
		-- Generate Menu Entries from Requested
		PRIVATE.GenerateMenuWidgets(CONTEXTMENU, MENU)
		
		-- Set menu to not hide on loss of focus
		CONTEXTMENU.selection[params.id] = true
		
		-- Update Parents of Menu
		MENU:UpdateParentMenus(params.parent_menus)
	end
	
	return CONTEXTMENU.WIDGETS.MENU[params.id]
end

function PRIVATE.GenerateMenuWidgets(CONTEXTMENU, MENU)
	local pending = CONTEXTMENU.pending_entries
	
	if #CONTEXTMENU.pending_entries == 0 then
		warn("Menu "..MENU.id.." has 0 Entries!")
	end
	
	-- Set Title
	MENU:SetTitle()
	
	for index, data in ipairs(CONTEXTMENU.pending_entries) do
		if not data then data = {} end
		data.parent = MENU.id
		data.index = index
		if data.type == "button" then
			PRIVATE.AddButton(CONTEXTMENU, MENU, data)
		elseif data.type == "label" then
			PRIVATE.AddLabel(CONTEXTMENU, MENU, data)
		elseif data.type == "check" then
			PRIVATE.AddCheck(CONTEXTMENU, MENU, data)
		elseif data.type == "menu" then
			PRIVATE.AddMenu(CONTEXTMENU, MENU, data)
		elseif data.type == "seperator" then
			PRIVATE.AddSeparator(CONTEXTMENU, MENU, data)
		elseif data.type == "header" then
		
		
		end
	end
	CONTEXTMENU.pending_entries = {}
	
	PRIVATE.RefreshMenuSize(MENU)
end

function PRIVATE.RefreshMenuSize(MENU)
	local dims = MENU.ROWSCROLLER:GetContentSize()
	local height = dims.height+(MENU_SPACING*2)+(ROWSCROLLER_SPACING*2)+MENU.offset
	height = math.min(height, ROWSCROLLER_MAX_HEIGHT)
	MENU.GROUP:SetDims("top:_; height:"..height)
	MENU.ROWSCROLLER:UpdateSize()
end

-- ------------------------------------------
-- ENTRY TYPES
-- ------------------------------------------
function PRIVATE.AddButton(CONTEXTMENU, MENU, params)
	local GROUP = Component.CreateWidget(bp_Button, MENU.FOSTER)
	local ENTRY = {
		GROUP = GROUP,
		ICON = GROUP:GetChild("icon"),
		LABEL = GROUP:GetChild("label"),
		HIGHLIGHT = GROUP:GetChild("highlight"),
		
		-- Variables
		id = params.id or params.index,
		tag = MENU.id.."."..params.index,
		index = params.index,
		label = params.label,
		color = params.color,
		color_start = params.color_start,
		color_end = params.color_end,
		params = params,		-- table ref
		disable = params.disable,
		OnSelect_Func = false,
		
		-- Return Values
		parent = MENU.id,
		value = params.value,
	}
	ENTRY.GROUP:SetTag(ENTRY.tag)
	ENTRY.LABEL:SetText(ENTRY.label)
	if ENTRY.color then
		if ENTRY.color_start and ENTRY.color_end then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start, ENTRY.color_end)
		elseif ENTRY.color_start then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start)
		else
			ENTRY.LABEL:SetTextColor(ENTRY.color)
		end
	end
	
	if ENTRY.disable then
		ENTRY.LABEL:SetParam("alpha", DISABLED_ALPHA)
		ENTRY.GROUP:SetCursor("sys_arrow")
	end
	
	if params.texture then
		ENTRY.ICON:SetTexture(params.texture, params.region)
		if params.tint then
			ENTRY.ICON:SetParam("tint", params.tint)
		end
	else
		ENTRY.ICON:Hide()
		ENTRY.LABEL:SetDims("left:5; top:_")
	end
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function(args)
		if not ENTRY.disable then
			PRIVATE.ButtonOnMouseEnter(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseLeave", function(args)
		if not ENTRY.disable then
			PRIVATE.ButtonOnMouseLeave(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseDown", function(args)
		if not ENTRY.disable then
			PRIVATE.ButtonOnMouseDown(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseUp", function(args)
		if not ENTRY.disable then
			PRIVATE.ButtonOnMouseUp(CONTEXTMENU, args)
		end
	end)
	
	MENU:AddRow(ENTRY)
	
	CONTEXTMENU.WIDGETS.ENTRY[ENTRY.tag] = ENTRY
end

function PRIVATE.AddLabel(CONTEXTMENU, MENU, params)
	local GROUP = Component.CreateWidget(bp_Label, MENU.FOSTER)
	local ENTRY = {
		GROUP = GROUP,
		ICON = GROUP:GetChild("icon"),
		LABEL = GROUP:GetChild("label"),
		
		-- Variables
		id = params.id or params.index,
		tag = MENU.id.."."..params.index,
		index = params.index,
		label = params.label,
		color = params.color,
		color_start = params.color_start,
		color_end = params.color_end,
		params = params,		-- table ref
		disable = params.disable,
		OnSelect_Func = false,
	}
	
	ENTRY.GROUP:SetTag(ENTRY.tag)
	ENTRY.LABEL:SetText(ENTRY.label)
	if ENTRY.color then
		if ENTRY.color_start and ENTRY.color_end then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start, ENTRY.color_end)
		elseif ENTRY.color_start then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start)
		else
			ENTRY.LABEL:SetTextColor(ENTRY.color)
		end
	end
	
	if ENTRY.disable then
		ENTRY.LABEL:SetParam("alpha", DISABLED_ALPHA)
		ENTRY.GROUP:SetCursor("sys_arrow")
	end
	
	if params.texture then
		ENTRY.ICON:SetTexture(params.texture, params.region)
		if params.tint then
			ENTRY.ICON:SetParam("tint", params.tint)
		end
	else
		ENTRY.ICON:Hide()
		ENTRY.LABEL:SetDims("left:5; top:_")
	end
	
	MENU:AddRow(ENTRY)
	
	CONTEXTMENU.WIDGETS.ENTRY[ENTRY.tag] = ENTRY
end

function PRIVATE.AddMenu(CONTEXTMENU, MENU, params)
	local GROUP = Component.CreateWidget(bp_MenuButton, MENU.FOSTER)
	local ENTRY = {
		GROUP = GROUP,
		ARROW = GROUP:GetChild("sub_arrow"),
		LABEL = GROUP:GetChild("label"),
		HIGHLIGHT = GROUP:GetChild("highlight"),
		
		-- Variables
		id = params.id or params.index,
		tag = MENU.id.."."..params.index,
		index = params.index,
		label = params.label,
		color = params.color,
		color_start = params.color_start,
		color_end = params.color_end,
		params = params,		-- table ref
		menu = params.menu,
	
		
		-- Return Values
		parent = MENU.id,
		value = params.value,
	}
	ENTRY.GROUP:SetTag(ENTRY.tag)
	ENTRY.LABEL:SetText(params.label)
	if ENTRY.color then
		if ENTRY.color_start and ENTRY.color_end then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start, ENTRY.color_end)
		elseif ENTRY.color_start then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start)
		else
			ENTRY.LABEL:SetTextColor(ENTRY.color)
		end
	end
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function(args)
		PRIVATE.ButtonMenuOnMouseEnter(CONTEXTMENU, args)
	end)
	ENTRY.GROUP:BindEvent("OnMouseLeave", function(args)
		PRIVATE.ButtonMenuOnMouseLeave(CONTEXTMENU, args)
	end)
	
	MENU:AddRow(ENTRY)
	
	CONTEXTMENU.WIDGETS.ENTRY[ENTRY.tag] = ENTRY
end

function PRIVATE.AddCheck(CONTEXTMENU, MENU, params)
	local GROUP = Component.CreateWidget(bp_CheckButton, MENU.FOSTER)
	local ENTRY = {
		GROUP = GROUP,
		CHECK = GROUP:GetChild("check"),
		LABEL = GROUP:GetChild("label"),
		HIGHLIGHT = GROUP:GetChild("highlight"),
		
		-- Variables
		id = params.id or params.index,
		tag = MENU.id.."."..params.index,
		radio_id = params.radio_id,
		index = params.index,
		label = params.label,
		color = params.color,
		color_start = params.color_start,
		color_end = params.color_end,
		disable = params.disable,
		params = params,		-- table ref
		OnSelect_Func = false,
		
		
		-- Return Values
		parent = MENU.id,
		checked = params.checked,
	}
	ENTRY.GROUP:SetTag(ENTRY.tag)
	ENTRY.LABEL:SetText(params.label)
	if ENTRY.color then
		if ENTRY.color_start and ENTRY.color_end then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start, ENTRY.color_end)
		elseif ENTRY.color_start then
			ENTRY.LABEL:SetTextColor(ENTRY.color, nil, ENTRY.color_start)
		else
			ENTRY.LABEL:SetTextColor(ENTRY.color)
		end
	end
	
	if ENTRY.disable then
		ENTRY.LABEL:SetParam("alpha", DISABLED_ALPHA)
		ENTRY.GROUP:SetCursor("sys_arrow")
	end
	
	PRIVATE.CheckChangeState(ENTRY, ENTRY.checked)
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function(args)
		if not ENTRY.disable then
			PRIVATE.CheckOnMouseEnter(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseLeave", function(args)
		if not ENTRY.disable then
			PRIVATE.CheckOnMouseLeave(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseDown", function(args)
		if not ENTRY.disable then
			PRIVATE.CheckOnMouseDown(CONTEXTMENU, args)
		end
	end)
	ENTRY.GROUP:BindEvent("OnMouseUp", function(args)
		if not ENTRY.disable then
			PRIVATE.CheckOnMouseUp(CONTEXTMENU, args)
		end
	end)
	
	MENU:AddRow(ENTRY)
	
	CONTEXTMENU.WIDGETS.ENTRY[ENTRY.tag] = ENTRY
end

function PRIVATE.AddSeparator(CONTEXTMENU, MENU, params)
	local GROUP = Component.CreateWidget(bp_Separator, MENU.FOSTER)
	local ENTRY = {
		GROUP = GROUP,
		
		-- Variables
		tag = MENU.id.."."..params.index,
	}
	--ENTRY.GROUP:SetTag(ENTRY.tag)
	
	MENU:AddRow(ENTRY)
	
	CONTEXTMENU.WIDGETS.ENTRY[ENTRY.tag] = ENTRY
end

-- ------------------------------------------
-- BUTTON EVENTS
-- ------------------------------------------
function PRIVATE.OnSelect(CONTEXTMENU, ENTRY, ret_vals)
	if ENTRY and ENTRY.OnSelect_Func then
		ENTRY.OnSelect_Func(ret_vals)
	else
		CONTEXTMENU.OnSelect_Func(ret_vals)
	end
end

-- Button Menu Events
function PRIVATE.ButtonMenuOnMouseEnter(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0.7, 0.15, "smooth")
	
	local PARENT_MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=ENTRY.parent})
	
	local parent_menus = PARENT_MENU:GetParents()
	PARENT_MENU:AddParent(ENTRY.parent)
	
	-- Expand Menu
	local MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=ENTRY.menu, parent_menus=parent_menus})
	
	local dims_top = ENTRY.GROUP:GetBounds().top
	local dims_right = CONTEXTMENU.WIDGETS.MENU[ENTRY.parent].GROUP:GetBounds().right

	local alignment = PRIVATE.GetScreenPosition(CONTEXTMENU, MENU, dims_right, dims_top, false)
	MENU.GROUP:SetDims(alignment.halign.."; "..alignment.valign.."; width:"..MENU_WIDTH.."; height:_; relative:screen")
	MENU:Open()
end

function PRIVATE.ButtonMenuOnMouseLeave(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0, 0.1, "smooth")
	
	
	local MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=ENTRY.parent})
	--MENU.GROUP:ButtonClose()
	PRIVATE.OpenMenuCheck(CONTEXTMENU, MENU)
end

-- Button Standard Events
function PRIVATE.ButtonOnMouseEnter(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0.7, 0.15, "smooth")
	
	local MENU = PRIVATE.RequestMenu(CONTEXTMENU, {id=ENTRY.parent})
	PRIVATE.OpenMenuCheck(CONTEXTMENU, MENU)
end

function PRIVATE.ButtonOnMouseLeave(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0, 0.1, "smooth")
end

function PRIVATE.ButtonOnMouseDown(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 1, 0.1, "smooth")
end

function PRIVATE.ButtonOnMouseUp(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	-- Action Performed and expected to send an event and self close.
	local ret_vals = {
		menu = ENTRY.parent,
		id = ENTRY.id or ENTRY.index,
		value = ENTRY.value or ENTRY.id,
	}
	PRIVATE.OnSelect(CONTEXTMENU, ENTRY, ret_vals )
	CONTEXTMENU:Hide()
end

-- Check
function PRIVATE.CheckOnMouseEnter(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0.7, 0.15, "smooth")
	ENTRY.CHECK:ParamTo("exposure", 0.3, 0.15)
end

function PRIVATE.CheckOnMouseLeave(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 0, 0.1, "smooth")
	ENTRY.CHECK:ParamTo("exposure", 0, 0.15)
end

function PRIVATE.CheckOnMouseDown(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	ENTRY.HIGHLIGHT:ParamTo("alpha", 1, 0.1, "smooth")
end

function PRIVATE.CheckOnMouseUp(CONTEXTMENU, args)
	local ENTRY = PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	if ENTRY.radio_id then
		for tag, E in pairs(CONTEXTMENU.WIDGETS.ENTRY) do
			if E.parent == ENTRY.parent and E.radio_id == ENTRY.radio_id then
				PRIVATE.CheckChangeState(E, false)
			end
		end
	end
	PRIVATE.CheckChangeState(ENTRY, not ENTRY.checked)
	local ret_vals = {
		menu = ENTRY.parent,
		id = ENTRY.id or ENTRY.index,
		value = ENTRY.checked,
	}
	PRIVATE.OnSelect(CONTEXTMENU, ENTRY, ret_vals )
end

function PRIVATE.CheckChangeState(ENTRY, state)
	local alpha = 0.05
	ENTRY.checked = state
	if ENTRY.checked then
		if not ENTRY.disable then
			alpha = 1
		else
			alpha = DISABLED_ALPHA
		end
	end
	ENTRY.CHECK:SetParam("alpha", alpha)
end

-- Open Menu Check, closes any loose menus
function PRIVATE.OpenMenuCheck(CONTEXTMENU, SELECTED_MENU)
	local menus = SELECTED_MENU:GetParents()	
	for id,MENU in pairs(CONTEXTMENU.WIDGETS.MENU) do
		if MENU.IsOpen and not isequal(id, SELECTED_MENU.id) and not PRIVATE.IsEqualList(id, menus) then
			MENU:Close()
		end	
	end
end

function PRIVATE.GetEntryByTag(CONTEXTMENU, args)
	local tag = args.widget:GetTag()
	if CONTEXTMENU.WIDGETS.ENTRY[tag] then
		return CONTEXTMENU.WIDGETS.ENTRY[tag]
	end
	error("Tag: "..tag.." not located in Entries!")
end


-- ------------------------------------------
-- UTILITY
-- ------------------------------------------
function PRIVATE.LabelCheck(params)
	if type(params.label_key) == "string" then
		return Component.LookupText(params.label_key)
	elseif not ( type(params.label) == "string" or type(params.label) == "number" ) then
		return "Untitled"
	end
	return params.label
end

function PRIVATE.IsEqualList(value, tbl)
	for i=1, #tbl do
		if isequal(value, tbl[i]) then
			return true
		end
	end
	return false
end

function PRIVATE.GetScreenPosition(CONTEXTMENU, MENU, coords_x, coords_y, has_header)
	-- Borrowed from Tooltips
	
	-- Get Root Position
	local _x, _y
	if coords_x and coords_y then
		_x, _y = coords_x, coords_y
		MENU.init_x, MENU.init_y = _x, _y
	else
		_x, _y = Component.GetCursorPos()
		MENU.init_x, MENU.init_y = _x, _y
	end
	
	local menu_bounds = MENU:GetBounds()
	local screen_width, screen_height = Component.GetScreenSize()
		
	local halign, valign, v_dir, h_dir
	if _x + (2 * MENU_WIDTH) < screen_width then
		CONTEXTMENU.horizontal = DIRECTION_RIGHT
		halign = "left:".._x-MENU_HMOUSEOFFSET
		h_dir = DIRECTION_LEFT
	else
		-- If submenu, defined by coords_x and coords-y offset by MENU_WIDTH
		CONTEXTMENU.horizontal = DIRECTION_LEFT
		local subMenuOffset = 0
		if (coords_x and coords_y) then
			subMenuOffset = MENU_WIDTH
		end
		halign = "right:".._x+MENU_HMOUSEOFFSET-subMenuOffset
		h_dir = DIRECTION_RIGHT
	end
	if (_y + menu_bounds.height < screen_height) then
		-- Cursor, facing Down
		local voffset = _y-MENU_VMOUSEOFFSET
		if has_header then
			voffset = voffset - (HEADER_HEIGHT + 2)
		end
		valign = "top:"..voffset
		v_dir = DIRECTION_DOWN
	else
		-- Cursor, facing Upwards
		local voffset = _y+MENU_VMOUSEOFFSET
		if not has_header then
			voffset = voffset + BUTTON_HEIGHT
		end
		valign = "bottom:"..voffset
		v_dir = DIRECTION_UP
	end
	
	return {halign=halign, valign=valign, v_dir=v_dir, h_dir=h_dir}
end
