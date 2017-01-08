
-- ------------------------------------------
-- lib_ContextualMenu
--   by: Brian Blose
-- ------------------------------------------

--[[
	w_Menus = {
		[1] = {
			GROUP
			menu_path = <menu_path_array>
			highlighted = <entry_id> or nil
			entries = {
				<entry_id> = {
					GROUP
				}
			}
		}
		...
	}
--]]

if ContextualMenu then
	return nil
end
ContextualMenu = {}		--table of global functions
local ContextApi = {}	--table of context menu api functions
local MenuApi = {}		--table of (sub)menu api functions
local EntryApi = {}		--table of entry api functions
local lf = {}			--table of local functions
local CreateEntry = {}	--table of entry creation functions
local UpdateEntry = {}	--table of entry update functions
local lcb = {}			--table of liaison callback functions

--require "unicode"
require "math"
require "table"
require "lib/lib_table"
require "lib/lib_TextFormat"
require "lib/lib_MultiArt"
require "lib/lib_RowScroller"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_ComponentName = Component.GetInfo()

local c_EntryHeight = 27
local c_DividerHeight = 1
local c_MaxContentHeight = (15 * (c_EntryHeight + c_DividerHeight)) - c_DividerHeight
local c_MenuPadding = 2
local c_ScrollerTopPadding = 13
local c_ScrollerBottomPadding = 21
local c_MenuWidth = 260
local c_MinHeight = 0--71

local c_AutoCloseDur = 0.5
local c_AnimDur = 0.1
local c_DisabledAlpha = 0.2
local c_UncheckedAlpha = 0.05

ContextualMenu.default_label_color = "#708EC1"
ContextualMenu.default_font = "UbuntuMedium_9"

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local bp_Frame = 
	[[<PanelFrame dimensions="dock:fill" topmost="true" unfreezable="true" depth="1">
		<Children>
			<FocusBox name="screen_focus" dimensions="dock:fill"/>
		</Children>
	</PanelFrame>]]

--Menu Framework blueprints
local bp_ContextMenu = 
	[[<FocusBox dimensions="dock:fill">
		<Group name="menu" dimensions="left:]]..c_MenuPadding..[[; right:100%-]]..c_MenuPadding..[[; top:]]..c_MenuPadding..[[; bottom:100%-]]..c_MenuPadding..[[">
			<StillArt dimensions="left:-44; top:-45; width:52; height:74;" style="texture:ContextMenu; region:topLeft; eatsmice:false;"/>
			<StillArt dimensions="right:100%+45; top:-45; width:56; height:74;" style="texture:ContextMenu; region:topRight; eatsmice:false;"/>
			<StillArt dimensions="left:8; right:100%-11; top:-45; height:74;" style="texture:ContextMenu; region:topCenterStretch; eatsmice:false;"/>
			<StillArt dimensions="left:-44; top:29; width:52; bottom:100%-32;" style="texture:ContextMenu; region:centerLeftStretch; eatsmice:false;"/>
			<StillArt dimensions="right:100%+45; top:29; width:56; bottom:100%-32;" style="texture:ContextMenu; region:centerRightStretch; eatsmice:false;"/>
			<StillArt dimensions="left:8; right:100%-11; top:29; bottom:100%-32;" style="texture:ContextMenu; region:centerStretch; eatsmice:false;"/>
			<StillArt dimensions="left:-44; bottom:100%+44; width:52; height:76;" style="texture:ContextMenu; region:bottomLeft; eatsmice:false;"/>
			<StillArt dimensions="right:100%+45; bottom:100%+44; width:134; height:76;" style="texture:ContextMenu; region:bottomRight; eatsmice:false;"/>
			<StillArt dimensions="left:8; right:100%-89; bottom:100%+44; height:76;" style="texture:ContextMenu; region:bottomCenterStretch; eatsmice:false;"/>
			<Group name="orphanage" dimensions="dock:fill" style="visible:false"/>
			<Group name="scroller" dimensions="top:]]..c_ScrollerTopPadding..[[; bottom:100%-]]..c_ScrollerBottomPadding..[[; left:0; right:100%"/>
		</Group>
	</FocusBox>]]

local bp_Divider = [[<StillArt dimensions="dock:fill" style="texture:ContextMenu; region:divider"/>]]

--Generic Entry bits
local bp_Pulse = [[<StillArt name="pulse" dimensions="top:0; bottom:100%; left:0; right:100%" style="texture:colors; region:white; tint:orange; alpha:0; eatsmice:false"/>]]
local bp_Highlight = [[<StillArt name="highlight" dimensions="top:-9; bottom:100%+9; left:0; right:100%" style="texture:ContextMenu; region:highlight; alpha:0; eatsmice:false"/>]]
local bp_Icon = [[<Group name="icon" dimensions="center-y:50%; height:100%-8; left:10; width:100t-8"/>]] --Container for multiart
local bp_LabelGroup =
	[[<Group name="label_group" dimensions="top:0; bottom:100%; left:30; right:100%-10">
		<Text name="label" dimensions="dock:fill" style="font:]]..ContextualMenu.default_font..[[; halign:left; valign:center; wrap:true; leading-mult:1.3;"/>
	</Group>]]

--Entry blueprints
local bp_SubMenu =
	[[<FocusBox dimensions="dock:fill">
		]]..bp_Highlight..[[
		]]..bp_Icon..[[
		<StillArt name="sub_arrow" dimensions="right:100%-10; center-y:50%; width:100t-12; height:100%-12" style="texture:arrows; region:stylized_right; visible:true; alpha:1" />
		]]..bp_LabelGroup..[[
	</FocusBox>]]

local bp_Label =
	[[<FocusBox dimensions="dock:fill">
		]]..bp_Icon..[[
		]]..bp_LabelGroup..[[
	</FocusBox>]]

local bp_Button =
	[[<FocusBox dimensions="dock:fill" class="ui_button">
		]]..bp_Pulse..[[
		]]..bp_Highlight..[[
		]]..bp_Icon..[[
		]]..bp_LabelGroup..[[
	</FocusBox>]]

local bp_Check =
	[[<FocusBox dimensions="dock:fill" class="ui_button">
		]]..bp_Highlight..[[
		]]..bp_Icon..[[
		]]..bp_LabelGroup..[[
	</FocusBox>]]



-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local w_FRAME
local w_Menus = {}
local g_Counter = 0
local g_ActiveMenuIndex = 0
local g_ActiveContextMenu

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function ContextualMenu.Create()
	local CONTEXTMENU = {
		id = "__root",
		menu_path = {},
	}
	lf.InitMenuData(CONTEXTMENU)
	for k, v in pairs(ContextApi) do
		CONTEXTMENU[k] = v
	end
	
	return CONTEXTMENU
end

-- ------------------------------------------
-- CONTEXT MENU API FUNCTIONS
-- ------------------------------------------
function ContextApi.Show(CONTEXTMENU, manual_bind_box, vert_placement)
	assert(type(CONTEXTMENU) == "table" and CONTEXTMENU.Show, "use :Show instead of .Show")
	if w_FRAME then
		warn("Only one context menu at a time")
		return
	end
	g_ActiveMenuIndex = 1
	w_FRAME = Component.CreateFrame(bp_Frame)
	local SCREENFOCUS = w_FRAME:GetChild("screen_focus")
	w_FRAME:BindEvent("OnEscape", function()
		CONTEXTMENU:Hide()
	end)
	w_FRAME:BindEvent("OnOpen", function()
		if CONTEXTMENU.OnOpen then
			CONTEXTMENU.OnOpen()
		end
	end)
	w_FRAME:BindEvent("OnClose", function()
		if CONTEXTMENU.OnClose then
			CONTEXTMENU.OnClose()
		end
		lf.CleanUp()
	end)
	SCREENFOCUS:BindEvent("OnMouseDown", function()
		CONTEXTMENU:Hide()
	end)
	local MENU = lf.CreateMenu(CONTEXTMENU)
	lf.PopulateMenu(MENU, CONTEXTMENU)
	lf.PositionMenu(MENU, manual_bind_box, vert_placement)
	g_ActiveContextMenu = CONTEXTMENU
	w_FRAME:Show()
end

function ContextApi.Hide(CONTEXTMENU)
	assert(type(CONTEXTMENU) == "table" and CONTEXTMENU.Hide, "use :Hide instead of .Hide")
	if w_FRAME then
		w_FRAME:Hide()
	end
end

function ContextApi.IsVisible(CONTEXTMENU)
	assert(type(CONTEXTMENU) == "table" and CONTEXTMENU.Hide, "use :IsVisible instead of .IsVisible")
	return w_FRAME ~= nil
end

function ContextApi.BindOnOpen(CONTEXTMENU, func)
	assert(type(CONTEXTMENU) == "table" and CONTEXTMENU.BindOnClose, "use :BindOnOpen instead of .BindOnOpen")
	assert(type(func) == "function", "missing function")
	CONTEXTMENU.OnOpen = func
end

function ContextApi.BindOnClose(CONTEXTMENU, func)
	assert(type(CONTEXTMENU) == "table" and CONTEXTMENU.BindOnClose, "use :BindOnClose instead of .BindOnClose")
	assert(type(func) == "function", "missing function")
	CONTEXTMENU.OnClose = func
end

-- ------------------------------------------
-- MENU API FUNCTIONS
-- ------------------------------------------
function MenuApi.AddMenu(MENU, params)
	assert(type(MENU) == "table" and MENU.AddMenu, "use :AddMenu instead of .AddMenu")
	assert(type(params) == "table", "missing params table; MENU:AddMenu(params)")
	local SUBMENU = params
	lf.InitEntryData(SUBMENU, MENU)
	--init entry specific parts
	SUBMENU.type = "submenu"
	lf.InitMenuData(SUBMENU)
	
	
	return SUBMENU
end

function MenuApi.AddLabel(MENU, params)
	assert(type(MENU) == "table" and MENU.AddLabel, "use :AddLabel instead of .AddLabel")
	assert(type(params) == "table", "missing params table; MENU:AddLabel(params)")
	local LABEL = params
	lf.InitEntryData(LABEL, MENU)
	--init entry specific parts
	LABEL.type = "label"
	
	return LABEL
end

function MenuApi.AddButton(MENU, params, func)
	func = func or function() log("NoFunc") end --TODO: Remove
	assert(type(MENU) == "table" and MENU.AddButton, "use :AddButton instead of .AddButton")
	assert(type(params) == "table", "missing params table; MENU:AddButton(params, function)")
	assert(type(func) == "function", "missing function")
	local BUTTON = params
	lf.InitEntryData(BUTTON, MENU)
	--init entry specific parts
	BUTTON.type = "button"
	BUTTON.OnClick = func
	
	return BUTTON
end

function MenuApi.PulseButton(MENU, id)
	local entry = MENU.entries[id]
	if entry == nil then 
		warn("MenuApi.PulseButton could not find menu entry with id "..tostring(id))
		return nil
	end

	local WIDGET = lf.GetEntryWidgets(entry)
	if WIDGET == nil then
		warn("MenuApi.PulseButton could not find button widget with id "..tostring(id))
		return nil
	end

	local pulse = WIDGET.GROUP:GetChild("pulse")
	pulse:CycleParam("alpha", 1, 0.5)
end

function MenuApi.AddCheck(MENU, params, func)
	func = func or function() log("NoFunc") end --TODO: Remove
	assert(type(MENU) == "table" and MENU.AddCheck, "use :AddCheck instead of .AddCheck")
	assert(type(params) == "table", "missing params table; MENU:AddCheck(params, function)")
	assert(type(func) == "function", "missing function")
	local CHECK = params
	lf.InitEntryData(CHECK, MENU)
	--init entry specific parts
	CHECK.type = "check"
	CHECK.OnClick = func
	
	return CHECK
end

function MenuApi.CreateRadioGroup(MENU, params)
	assert(type(MENU) == "table" and MENU.CreateRadioGroup, "use :CreateRadioGroup instead of .CreateRadioGroup")
	local RADIO = params or {}
	lf.EnforceId(RADIO)
	--init entry specific parts
	RADIO.type = "radio"
	RADIO.entries = {}
	MENU.groups[RADIO.id] = RADIO
	
	return RADIO
end

function MenuApi.CreateMultiSelectGroup(MENU, params)
	assert(type(MENU) == "table" and MENU.CreateMultiSelectGroup, "use :CreateMultiSelectGroup instead of .CreateMultiSelectGroup")
	local MULTI = params or {}
	lf.EnforceId(MULTI)
	--init entry specific parts
	MULTI.type = "multi"
	MULTI.entries = {}
	MULTI.min_checked = MULTI.min_checked or 0
	MENU.groups[MULTI.id] = MULTI
	
	return MULTI
end

-- ------------------------------------------
-- ENTRY API FUNCTIONS
-- ------------------------------------------
function EntryApi.UpdateParams(entry, params)
	assert(type(entry) == "table" and entry.UpdateParams, "use :UpdateParams instead of .UpdateParams")
	assert(type(params) == "table", "missing params table; ENTRY:UpdateParams(params)")
	for k, v in pairs(params) do
		entry[k] = v
	end
	local ENTRY = lf.GetEntryWidgets(entry)
	if ENTRY then
		local MENU = w_Menus[#entry.menu_path]
		UpdateEntry[entry.type](ENTRY, entry, MENU)
	end
end

-- ------------------------------------------
-- MENU LOCAL FUNCTIONS
-- ------------------------------------------
function lf.CreateMenu(menu)
	local MENU = {entries = {}}
	MENU.groups = menu.groups
	MENU.menu_path = _table.copy(menu.menu_path)
	table.insert(MENU.menu_path, menu.id)
	table.insert(w_Menus, MENU)
	MENU.GROUP = Component.CreateWidget(bp_ContextMenu, w_FRAME)
	MENU.ORPHANAGE = MENU.GROUP:GetChild("menu.orphanage")
	MENU.SCROLLER_CONTAINER = MENU.GROUP:GetChild("menu.scroller")
	MENU.ROWSCROLLER = RowScroller.Create(MENU.SCROLLER_CONTAINER)
	MENU.ROWSCROLLER:LockUpdates()
	MENU.ROWSCROLLER:SetSpacing(0)
	MENU.GROUP:BindEvent("OnMouseEnter", function()
		g_ActiveMenuIndex = #MENU.menu_path
		for i = 1, #w_Menus do
			local M = w_Menus[i]
			if M and M.highlighted then
				local ENTRY = M.entries[M.highlighted]
				lf.UpdateHighlight(ENTRY, ENTRY.entry, M)
			end
		end
	end)
	return MENU
end

function lf.DestroyMenu(MENU)
	for _, ENTRY in pairs(MENU.entries) do
		TextFormat.Clear(ENTRY.LABEL)
	end
	MENU.ROWSCROLLER:Destroy()
	Component.RemoveWidget(MENU.GROUP)
	w_Menus[#MENU.menu_path] = nil
	for k, v in pairs(MENU) do
		MENU[k] = nil
	end
end

function lf.PopulateMenu(MENU, menu)
	local previous_group = nil
	for i, id in ipairs(menu.ordered_entries) do
		local entry = menu.entries[id]
		if i ~= 1 then
			local DIVIDER = Component.CreateWidget(bp_Divider, MENU.ORPHANAGE)
			local ROW = MENU.ROWSCROLLER:AddRow()
			ROW:SetWidget(DIVIDER)
			ROW:UpdateSize({height=c_DividerHeight})
			if previous_group and previous_group == entry.group then
				--don't show dividers between 2 entries of the same group
				DIVIDER:Hide()
			end
			previous_group = entry.group
		end
		local ENTRY = CreateEntry[entry.type](entry, MENU)
		ENTRY.entry = entry
		UpdateEntry[entry.type](ENTRY, entry, MENU)
		local ROW = MENU.ROWSCROLLER:AddRow()
		ROW:SetWidget(ENTRY.GROUP)
		ROW:ClipChildren(false)
		ROW:UpdateSize({height=c_EntryHeight})
	end
end

function lf.PositionMenu(MENU, manual_bind_box, vert_placement)
	local frame_dims = w_FRAME:GetBounds()
	local frame_width = frame_dims.width
	local frame_height = frame_dims.height
	local height = MENU.ROWSCROLLER:GetContentSize().height
	MENU.ROWSCROLLER:ClipChildren(height > c_MaxContentHeight)
	height = math.min(height, c_MaxContentHeight) + (2 * c_MenuPadding) + c_ScrollerTopPadding + c_ScrollerBottomPadding
	height = math.max(c_MinHeight, height)
	local bind_box = {}
	local menu_index = #MENU.menu_path
	if manual_bind_box then
		bind_box = manual_bind_box
		if vert_placement then
			bind_box.top = bind_box.top - c_MenuPadding
			bind_box.bottom = bind_box.bottom + c_MenuPadding
			bind_box.height = bind_box.bottom - bind_box.top
		else
			bind_box.left = bind_box.left - c_MenuPadding
			bind_box.right = bind_box.right + c_MenuPadding
			bind_box.width = bind_box.right - bind_box.left
		end
	elseif menu_index == 1 then
		local cursor_x, cursor_y = Component.GetCursorPos()
		local screen_width, _ = Component.GetScreenSize(false)
		if frame_width < screen_width then
			--fix for eye infinity offset
			local offset = (screen_width-frame_width)/2
			cursor_x = cursor_x - offset
		end
		bind_box.left = math.max(0, cursor_x-c_MenuPadding)
		bind_box.right = math.min(frame_width, cursor_x+c_MenuPadding)
		bind_box.top = math.max(0, cursor_y-c_MenuPadding)
		bind_box.bottom = math.min(frame_height, cursor_y+c_MenuPadding)
		bind_box.width = 0
	else
		local SUBMENU = w_Menus[menu_index-1]
		bind_box = SUBMENU.entries[MENU.menu_path[menu_index]].GROUP:GetBounds()
		local container_dims = SUBMENU.SCROLLER_CONTAINER:GetBounds()
		bind_box.left = container_dims.left - c_MenuPadding
		bind_box.right = container_dims.right + c_MenuPadding
		bind_box.width = bind_box.right - bind_box.left
	end
	
	local dims = ""
	if vert_placement then
		if bind_box.top + bind_box.height + height < frame_height then
			dims = dims.."top:"..bind_box.top + bind_box.height.."; "
		else
			dims = dims.."bottom:"..bind_box.bottom - bind_box.height.."; "
		end
		if bind_box.left + c_MenuWidth < frame_width then
			dims = dims.."left:"..bind_box.left-c_MenuPadding.."; "
		else
			dims = dims.."right:"..bind_box.right+c_MenuPadding.."; "
		end
	else
		if bind_box.left + bind_box.width + c_MenuWidth < frame_width then
			dims = dims.."left:"..bind_box.left + bind_box.width.."; "
		else
			dims = dims.."right:"..bind_box.right - bind_box.width.."; "
		end
		if bind_box.top + height < frame_height then
			dims = dims.."top:"..bind_box.top-c_ScrollerTopPadding-c_MenuPadding.."; "
		else
			dims = dims.."bottom:"..bind_box.bottom+c_ScrollerBottomPadding+c_MenuPadding.."; "
		end
	end
	dims = dims.."height:"..height.."; width:"..c_MenuWidth
	MENU.GROUP:SetDims(dims)
	MENU.ROWSCROLLER:UpdateSize(MENU.SCROLLER_CONTAINER:GetBounds())
	MENU.ROWSCROLLER:UnlockUpdates()
end

-- ------------------------------------------
-- ENTRY LOCAL FUNCTIONS
-- ------------------------------------------
function CreateEntry.submenu(entry, MENU)
	local ENTRY = lf.GetEntryWidgets(entry)
	ENTRY.GROUP = Component.CreateWidget(bp_SubMenu, MENU.ORPHANAGE)
	ENTRY.HIGHLIGHT = ENTRY.GROUP:GetChild("highlight")
	ENTRY.ICON_GROUP = ENTRY.GROUP:GetChild("icon")
	ENTRY.LABEL_GROUP = ENTRY.GROUP:GetChild("label_group")
	ENTRY.LABEL = ENTRY.LABEL_GROUP:GetChild("label")
	ENTRY.ARROW = ENTRY.GROUP:GetChild("sub_arrow")
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function()
		lf.UpdateSubmenus(ENTRY, entry, MENU)
		lf.UpdateHighlight(ENTRY, entry, MENU, true)
	end)
	
	return ENTRY
end

function UpdateEntry.submenu(ENTRY, entry, MENU)
	lf.UpdateIcon(ENTRY, entry, MENU)
	lf.UpdateLabel(ENTRY, entry, MENU)
	lf.UpdateHighlight(ENTRY, entry, MENU)
	
	ENTRY.ARROW:ParamTo("alpha", entry.disable and c_DisabledAlpha or 1, c_AnimDur)
	ENTRY.GROUP:SetCursor((entry.disable or entry.uninteractable) and "sys_arrow" or "sys_hand")
end

function CreateEntry.label(entry, MENU)
	local ENTRY = lf.GetEntryWidgets(entry)
	ENTRY.GROUP = Component.CreateWidget(bp_Label, MENU.ORPHANAGE)
	ENTRY.ICON_GROUP = ENTRY.GROUP:GetChild("icon")
	ENTRY.LABEL_GROUP = ENTRY.GROUP:GetChild("label_group")
	ENTRY.LABEL = ENTRY.LABEL_GROUP:GetChild("label")
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function()
		lf.UpdateSubmenus(ENTRY, entry, MENU)
		lf.UpdateHighlight(ENTRY, entry, MENU, true)
	end)
	
	return ENTRY
end

function UpdateEntry.label(ENTRY, entry, MENU)
	lf.UpdateIcon(ENTRY, entry, MENU)
	lf.UpdateLabel(ENTRY, entry, MENU)
	lf.UpdateHighlight(ENTRY, entry, MENU)
end

function CreateEntry.button(entry, MENU)
	local ENTRY = lf.GetEntryWidgets(entry)
	ENTRY.GROUP = Component.CreateWidget(bp_Button, MENU.ORPHANAGE)
	ENTRY.HIGHLIGHT = ENTRY.GROUP:GetChild("highlight")
	ENTRY.ICON_GROUP = ENTRY.GROUP:GetChild("icon")
	ENTRY.LABEL_GROUP = ENTRY.GROUP:GetChild("label_group")
	ENTRY.LABEL = ENTRY.LABEL_GROUP:GetChild("label")
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function()
		lf.UpdateSubmenus(ENTRY, entry, MENU)
		lf.UpdateHighlight(ENTRY, entry, MENU, true)
	end)
	ENTRY.GROUP:BindEvent("OnMouseDown", function()
		if not entry.disable and not entry.uninteractable then
			System.PlaySound("button_press")
			entry.OnClick({id=entry.id})
			g_ActiveContextMenu:Hide()
		end
	end)
	
	return ENTRY
end

function UpdateEntry.button(ENTRY, entry, MENU)
	lf.UpdateIcon(ENTRY, entry, MENU)
	lf.UpdateLabel(ENTRY, entry, MENU)
	lf.UpdateHighlight(ENTRY, entry, MENU)
	
	ENTRY.GROUP:SetCursor((entry.disable or entry.uninteractable) and "sys_arrow" or "sys_hand")
end

function CreateEntry.check(entry, MENU)
	local ENTRY = lf.GetEntryWidgets(entry)
	ENTRY.GROUP = Component.CreateWidget(bp_Button, MENU.ORPHANAGE)
	ENTRY.HIGHLIGHT = ENTRY.GROUP:GetChild("highlight")
	ENTRY.ICON_GROUP = ENTRY.GROUP:GetChild("icon")
	ENTRY.LABEL_GROUP = ENTRY.GROUP:GetChild("label_group")
	ENTRY.LABEL = ENTRY.LABEL_GROUP:GetChild("label")
	ENTRY.ICON = MultiArt.Create(ENTRY.ICON_GROUP)
	local group_type = entry.group and MENU.groups[entry.group].type
	if group_type == "radio" then
		ENTRY.ICON:SetTexture("RadioButton_White", "radio")
		ENTRY.ICON:SetParam("tint", "#00B2FF")
		ENTRY.ICON:SetDims("center-y:50%; center-x:50%; height:75%; width:75%")
	else
		ENTRY.ICON:SetTexture("DialogWidgets", "check")
		ENTRY.ICON:SetDims("center-y:50%; center-x:50%; height:60%; width:63%")
	end
	ENTRY.ICON:SetParam("alpha", 0)
	
	ENTRY.GROUP:BindEvent("OnMouseEnter", function()
		lf.UpdateSubmenus(ENTRY, entry, MENU)
		lf.UpdateHighlight(ENTRY, entry, MENU, true)
	end)
	ENTRY.GROUP:BindEvent("OnMouseDown", function()
		if not entry.disable and not entry.uninteractable then
			local ignore = false
			if group_type == "radio" then
				if not entry.checked then
					for id, e in pairs(MENU.groups[entry.group].entries) do
						if e.type == "check" and e.checked then
							e:UpdateParams({checked=false})
						end
					end
				else
					ignore = true
				end
			elseif group_type == "multi" then
				if entry.checked and MENU.groups[entry.group].min_checked > 0 then
					local checked = 0
					local unchecked = {}
					for id, e in pairs(MENU.groups[entry.group].entries) do
						if e.type == "check" and not e.disable and not entry.uninteractable then
							if e.checked then
								checked = checked + 1
							else
								local E = lf.GetEntryWidgets(e)
								if E then
									table.insert(unchecked, E)
								end
							end
						end
					end
					if checked <= MENU.groups[entry.group].min_checked then
						ignore = true
						System.PlaySound("button_cancel")
						for _, E in ipairs(unchecked) do
							E.ICON:FinishParam("alpha")
							for i = 1, 2 do
								E.ICON:QueueParam("alpha", 0.8, c_AnimDur)
								E.ICON:QueueParam("alpha", c_UncheckedAlpha, c_AnimDur)
							end
						end
					end
				end
			end
			if not ignore then
				entry.checked = not entry.checked
				ENTRY.ICON:ParamTo("alpha", entry.checked and 1 or c_UncheckedAlpha, c_AnimDur)
				System.PlaySound("button_press")
				local args = {id=entry.id, value=entry.checked}
				entry.OnClick(args)
			end
		end
	end)
	
	return ENTRY
end

function UpdateEntry.check(ENTRY, entry, MENU)
	lf.UpdateLabel(ENTRY, entry, MENU)
	lf.UpdateHighlight(ENTRY, entry, MENU)
	if entry.disable then
		ENTRY.ICON:ParamTo("alpha", entry.checked and c_DisabledAlpha or 0, c_AnimDur)
	else
		ENTRY.ICON:ParamTo("alpha", entry.checked and 1 or c_UncheckedAlpha, c_AnimDur)
	end
	
	ENTRY.GROUP:SetCursor((entry.disable or entry.uninteractable) and "sys_arrow" or "sys_hand")
end

function lf.UpdateHighlight(ENTRY, entry, MENU, show)
	local menu_index = #MENU.menu_path
	if show == true then
		if MENU.highlighted then
			local E = MENU.entries[MENU.highlighted]
			E.HIGHLIGHT:ParamTo("alpha", 0, c_AnimDur)
			MENU.highlighted = nil
		end
		if not entry.disable and not entry.uninteractable and entry.type ~= "label" then
			System.PlaySound("rollover")
			ENTRY.HIGHLIGHT:ParamTo("alpha", 1, c_AnimDur)
			MENU.highlighted = entry.id
		end
	elseif show == false then
		ENTRY.HIGHLIGHT:ParamTo("alpha", 0, c_AnimDur)
		if MENU.highlighted == entry.id then
			MENU.highlighted = nil
		end
	elseif entry.disable or entry.uninteractable then
		if MENU.highlighted == entry.id then
			ENTRY.HIGHLIGHT:ParamTo("alpha", 0, c_AnimDur)
			MENU.highlighted = nil
		end
	elseif g_ActiveMenuIndex ~= menu_index then
		if g_ActiveMenuIndex > menu_index and MENU.highlighted == entry.id then
			ENTRY.HIGHLIGHT:ParamTo("alpha", 0.3, c_AnimDur)
		elseif MENU.highlighted == entry.id then
			ENTRY.HIGHLIGHT:ParamTo("alpha", 0, c_AnimDur)
			MENU.highlighted = nil
		end
	end
end

function lf.UpdateSubmenus(ENTRY, entry, MENU)
	local menu_index = #entry.menu_path
	local is_active_submenu = entry.type == "submenu" and not entry.disable and not entry.uninteractable
	if #w_Menus > menu_index then
		local excess = 1
		if is_active_submenu then
			local path = _table.copy(entry.menu_path)
			table.insert(path, entry.id)
			if _table.isequal(path, w_Menus[menu_index+1].menu_path) then
				excess = 2
			end
		end
		for i = #w_Menus, menu_index+excess, -1 do
			lf.DestroyMenu(w_Menus[i])
		end
	end
	if is_active_submenu and #w_Menus == menu_index then
		local SUBMENU = lf.CreateMenu(entry)
		lf.PopulateMenu(SUBMENU, entry)
		lf.PositionMenu(SUBMENU)
	end
end

function lf.UpdateIcon(ENTRY, entry, MENU)
	if entry.icon then
		ENTRY.ICON_GROUP:Show()
		if not ENTRY.ICON then
			ENTRY.ICON = MultiArt.Create(ENTRY.ICON_GROUP)
		end
		if entry.icon.texture then
			ENTRY.ICON:SetTexture(entry.icon.texture, entry.icon.region)
		elseif entry.icon.url then
			ENTRY.ICON:SetUrl(entry.icon.url)
		elseif entry.icon.icon then
			ENTRY.ICON:SetIcon(entry.icon.icon)
		end
		if entry.icon.tint then
			ENTRY.ICON:SetParam("tint", entry.icon.tint)
		end
		ENTRY.ICON:SetParam("alpha", entry.disable and c_DisabledAlpha or 1)
	elseif ENTRY.ICON then
		ENTRY.ICON_GROUP:Hide()
		ENTRY.ICON:Destroy()
		ENTRY.ICON = nil
	end
end

function lf.UpdateLabel(ENTRY, entry, MENU)
	TextFormat.Clear(ENTRY.LABEL)
	if entry.label_foster then
		Component.FosterWidget(entry.label_foster, ENTRY.LABEL_GROUP, "full")
		ENTRY.fostered = entry.label_foster
		ENTRY.LABEL:Hide()
	else
		if ENTRY.fostered then
			Component.FosterWidget(ENTRY.fostered, nil)
		end
		ENTRY.LABEL:Show()
		if entry.color then
			ENTRY.LABEL:SetTextColor(entry.color)
		end
		if entry.label_TF then
			entry.label_TF:ApplyTo(ENTRY.LABEL)
		elseif entry.label_key then
			ENTRY.LABEL:SetTextKey(entry.label_key)
		elseif entry.label then
			ENTRY.LABEL:SetText(entry.label)
		else
			ENTRY.LABEL:SetText("Type: "..entry.type)
		end
	end
	ENTRY.LABEL_GROUP:SetParam("alpha", entry.disable and c_DisabledAlpha or 1)
	ENTRY.LABEL_GROUP:SetDims("right:_; left:"..(ENTRY.ICON and 30 or 10))
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.InitMenuData(menu)
	for k, v in pairs(MenuApi) do
		menu[k] = v
	end
	menu.entries = {}
	menu.groups = {}
	menu.ordered_entries = {}
end

function lf.InitEntryData(entry, menu)
	for k, v in pairs(EntryApi) do
		entry[k] = v
	end
	lf.EnforceId(entry)
	if entry.group then
		entry.group = entry.group.id
		menu.groups[entry.group].entries[entry.id] = entry
	end
	entry.menu_path = _table.copy(menu.menu_path)
	table.insert(entry.menu_path, menu.id)
	menu.entries[entry.id] = entry
	table.insert(menu.ordered_entries, entry.id)
end

function lf.EnforceId(entry)
	if not entry.id then
		entry.id = "__"..c_ComponentName.."__"..g_Counter
		g_Counter = g_Counter + 1
	end
end

function lf.GetEntryWidgets(entry)
	local MENU = w_Menus[#entry.menu_path]
	if _table.isequal(MENU.menu_path, entry.menu_path) then
		if not MENU.entries[entry.id] then
			MENU.entries[entry.id] = {}
		end
		return MENU.entries[entry.id]
	else
		return nil
	end
end

function lf.CleanUp()
	for i = #w_Menus, 1, -1 do
		lf.DestroyMenu(w_Menus[i])
	end
	Component.RemoveFrame(w_FRAME)
	w_FRAME = nil
	g_ActiveContextMenu = nil
end







