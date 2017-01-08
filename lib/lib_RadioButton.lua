
-- ------------------------------------------
-- RadioButton (Branch of CheckBox)
--   by: Red 5 Studios
-- ------------------------------------------

--[[ Usage:
	RADIOBUTTON = RadioButton.Create(PARENT)		-- creates a RadioButton
	RADIOBUTTON:Destroy()							-- Removes the RadioButton
	
	RADIOBUTTON:SetRadioType(type)					-- choose a 'check' or an 'x'
	RADIOBUTTON:TintCheck(tint)						-- changes the tint of the check; SetRadioType will auto apply the default color for that type
	RADIOBUTTON:SetRadio(checked)					-- manually sets the box to selected or unselected
	selected = RADIOBUTTON:IsSelected()				-- returns true if the box is checked; RADIOBUTTON:GetCheck() also works
	
	RADIOBUTTON:Enable([enabled])					-- Enables or Disables the RadioButton
	RADIOBUTTON:Disable([enabled])					-- Disables or Enables the RadioButton
	enabled = RADIOBUTTON:IsEnabled()				-- returns true if the RadioButton is enabled
	
	LINKGROUP = RadioButton.CreateLinkGroup(table)	-- Creates a LinkGroup composed of RadioButtons
	LINKGROUP:SetRadio(id)						-- Selects the Radio Button indexed by LinkGroup creation

	
	RADIOBUTTON is also an EventDispatcher (see lib_EventDispatcher) which dispatches the following events:
		"OnStateChanged",
		"OnScroll",
		"OnRightMouse",
		
		--These can be listened to via EventDispatcher or called as methods like RADIOBUTTON:OnMouseEnter() though note that this will also fire the EventDispatcher
		----This can be useful for if you want to have a focusbox that covers the RadioButton and a label so that the box and label can work/animate together
		"OnMouseEnter",
		"OnMouseLeave",
		"OnMouseDown",
		"OnMouseUp",
		"OnSubmit",
		"OnGotFocus",
		"OnLostFocus",
--]]

RadioButton = {}

require "lib/lib_Callback2"
require "lib/lib_EventDispatcher"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local PRIVATE = {}
local API = {}
local METATABLE = {
	__index = function(t,key) return API[key] end,
	__newindex = function(t,k,v) log(tostring(t)) log(tostring(k)) log(tostring(v)) error("cannot write to value '"..k.."' in WIDGET") end,
}


RadioButton.DEFAULT_BACKDROP_COLOR = "#000000"
RadioButton.DEFAULT_CLICKED_COLOR = "#444444"
RadioButton.DEFAULT_BORDER_COLOR = "#99FFFFFF"
RadioButton.DEFAULT_RADIO_COLOR = "#00B2FF"
RadioButton.DEFAULT_CHECK_COLOR = "#AAFF0A"
RadioButton.DEFAULT_X_COLOR = "#FF4444"

local c_MarkTypes = {
	radio = RadioButton.DEFAULT_RADIO_COLOR,
}

local bp_RadioButton =
	[[<FocusBox dimensions="dock:fill" class="ui_button">
		<StillArt name="backdrop" dimensions="dock:fill" style="texture:RadioButton_White; region:backdrop; tint:]]..RadioButton.DEFAULT_BACKDROP_COLOR..[[; alpha:1;"/>
		<StillArt name="border" dimensions="dock:fill" style="texture:RadioButton_White; region:border; tint:]]..RadioButton.DEFAULT_BORDER_COLOR..[[; alpha:1;"/>
		<StillArt name="radio" dimensions="dock:fill" style="texture:RadioButton_White; region:radio; tint:]]..RadioButton.DEFAULT_RADIO_COLOR..[[; alpha:0;"/>
	</FocusBox>]]

-- ------------------------------------------
-- FRONTEND FUNCTIONS
-- ------------------------------------------
RadioButton.Create = function(PARENT, mark)
	local FOCUS = Component.CreateWidget(bp_RadioButton, PARENT)
	
	local WIDGET = {
		GROUP = FOCUS,
		BACKDROP = FOCUS:GetChild("backdrop"),
		BORDER = FOCUS:GetChild("border"),
		RADIO = FOCUS:GetChild("radio"),
		checked = false,
		mouse_over = false,
		mouse_down = false,
		disabled = false,
		has_focus = false,
		LINK = false,
		link_id = false,
	}
	WIDGET.DISPATCHER = EventDispatcher.Create(WIDGET)
	WIDGET.DISPATCHER:Delegate(WIDGET)
	
	local used_events = {"OnMouseEnter", "OnMouseLeave", "OnMouseDown", "OnMouseUp", "OnSubmit", "OnGotFocus", "OnLostFocus"}
	for _, event in ipairs(used_events) do
		WIDGET.GROUP:BindEvent(event, function(args)
			API[event](WIDGET, args)
		end)
	end
	
	local other_events = {"OnScroll", "OnRightMouse"}
	for _, event in ipairs(other_events) do
		WIDGET.GROUP:BindEvent(event, function(args)
			WIDGET:DispatchEvent(event, args)
		end)
	end
	
	setmetatable(WIDGET, METATABLE)
	
	if mark then
		WIDGET:SetRadioType(mark)
	end
	
	PRIVATE.RefreshState(WIDGET, 0)
	return WIDGET
end

-- ------------------------------------------
-- LINKGROUP FUNCTIONS
-- ------------------------------------------
local LINKGROUP_PRIVATE = {}

function RadioButton.CreateLinkGroup(RadioTable)
	local LINKGROUP = {
		-- Variables
		RadioButtons = {},
		selected_radio = -1,
		
		-- Functions
		Select = LINKGROUP_PRIVATE.Select,
		SetRadio = LINKGROUP_PRIVATE.SetRadio,
		Unlink = LINKGROUP_PRIVATE.Unlink,
	}
	for radio_id, RADIO in ipairs(RadioTable) do
		assert(type(RADIO) == "table", "Entry ["..radio_id.."] is not a RadioButton")
		assert(RADIO.link_id == false, "RadioButton ["..radio_id.."] is already linked to a LinkGroup")
		PRIVATE.CreateLink(RADIO, LINKGROUP, radio_id)
	end
	LINKGROUP.RadioButtons = RadioTable
	LINKGROUP.Select = LINKGROUP_PRIVATE.Select
	
	return LINKGROUP
end

function LINKGROUP_PRIVATE.Unlink(LINKGROUP)
	for i=1, #LINKGROUP.RadioButtons do
		PRIVATE.ClearLink(LINKGROUP.RadioButtons[i])
	end
	LINKGROUP = nil
end

function LINKGROUP_PRIVATE.Select(LINKGROUP, radio_id)
	if LINKGROUP.RadioButtons[LINKGROUP.selected_radio] then
		LINKGROUP.RadioButtons[LINKGROUP.selected_radio]:OnLinkGroupSubmit(false)
	end
	LINKGROUP.selected_radio = radio_id
end

function LINKGROUP_PRIVATE.SetRadio(LINKGROUP, radio_id)
	LINKGROUP_PRIVATE.Select(LINKGROUP, radio_id)
	LINKGROUP.RadioButtons[radio_id]:SetRadio(true)
end

-- ------------------------------------------
-- WIDGET API
-- ------------------------------------------
local COMMON_METHODS = { -- forward the following methods to the GROUP widget
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag", "EatMice",
}
for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(WIDGET, ...)
		return WIDGET.GROUP[method_name](WIDGET.GROUP, ...)
	end
end

API.Destroy = function(WIDGET)
	WIDGET.DISPATCHER:Destroy()
	Component.RemoveWidget(WIDGET.GROUP)
	for k,v in pairs(WIDGET) do
		WIDGET[k] = nil
	end
end

API.TintCheck = function(WIDGET, tint)
	WIDGET.RADIO:SetParam("tint", tint)
end

API.SetRadioType = function(WIDGET, mark)
	local tint = c_MarkTypes[mark]
	if tint then
		WIDGET.RADIO:SetRegion(mark)
		WIDGET:TintCheck(tint)
	else
		warn("Invalid CheckBox CheckType: "..mark)
	end
end

API.SetRadio = function(WIDGET, checked, from_user)
	-- can't take nil, or will messy up the metatable
	local new_state
	if checked then
		new_state = true
	else
		new_state = false
	end
	if WIDGET.checked ~= new_state then
		WIDGET.checked = new_state
		PRIVATE.RefreshState(WIDGET)
		PRIVATE.OnStateChanged(WIDGET, from_user)
	end
end

API.IsSelected = function(WIDGET)
	return WIDGET.checked
end
API.GetCheck = API.IsSelected --Compatiblity with CheckBox Widget

API.Enable = function(WIDGET, ...)
	--allow NULL to work as true to mimic Show() and nil to work as false to mimic Show(nil)
	if arg[1] or arg.n == 0 then
		WIDGET.disabled = false
	else
		WIDGET.disabled = true
	end
	PRIVATE.RefreshState(WIDGET)
end

API.Disable = function(WIDGET, ...) --inverted Enable
    local nArgs = select('#', ...)
    local arg = {...}
	WIDGET:Enable(not (arg[1] or nArgs == 0))
end

API.IsEnabled = function(WIDGET)
	return not WIDGET.disabled
end

-- ------------------------------------------
-- WIDGET EVENTS/API
-- ------------------------------------------
-- All the event functions double as API incase you need to fake an event 
---- ie fake an OnMouseEnter and click when you mouse over and click a label you have for the checkbox
API.OnMouseEnter = function(WIDGET, args)
	if WIDGET.disabled then return nil end
	WIDGET.mouse_over = true
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnMouseEnter", args)
end

API.OnMouseLeave = function(WIDGET, args)
	if WIDGET.disabled then return nil end
	WIDGET.mouse_over = false
	WIDGET.mouse_down = false
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnMouseLeave", args)
end

API.OnMouseDown = function(WIDGET, args)
	if WIDGET.disabled or WIDGET.checked then return nil end
	WIDGET.mouse_down = true
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnMouseDown", args)
end

API.OnMouseUp = function(WIDGET, args)
	if WIDGET.disabled or WIDGET.checked then return nil end
	if WIDGET.mouse_down then
		WIDGET.mouse_down = false
		WIDGET.checked = true
		PRIVATE.RefreshState(WIDGET)
		PRIVATE.OnStateChanged(WIDGET, true)
		PRIVATE.LinkGroupSelected(WIDGET)
	end
	WIDGET:DispatchEvent("OnMouseUp", args)
end

API.OnSubmit = function(WIDGET, args)
	if WIDGET.disabled or WIDGET.checked then return nil end
	WIDGET.checked = true
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnSubmit", args)
	PRIVATE.OnStateChanged(WIDGET, true)
	PRIVATE.LinkGroupSelected(WIDGET)
end

API.OnGotFocus = function(WIDGET, args)
	if WIDGET.disabled then return nil end
	WIDGET.has_focus = true
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnGotFocus", args)
end

API.OnLostFocus = function(WIDGET, args)
	if WIDGET.disabled then return nil end
	WIDGET.has_focus = false
	PRIVATE.RefreshState(WIDGET)
	WIDGET:DispatchEvent("OnLostFocus", args)
end

API.OnLinkGroupSubmit = function(WIDGET, checked)
	WIDGET.checked = checked
	PRIVATE.RefreshState(WIDGET)
end

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
PRIVATE.CreateLink = function(WIDGET, LinkGroup, id)
	WIDGET.link_id = id
	WIDGET.LINK = LinkGroup
end

PRIVATE.ClearLink = function(WIDGET)
	WIDGET.link_id = false
	WIDGET.LINK = false
end

PRIVATE.LinkGroupSelected = function(WIDGET)
	if not ( WIDGET.link_id ) then return nil end
	WIDGET.LINK:Select(WIDGET.link_id)
end

PRIVATE.OnStateChanged = function(WIDGET, from_user)
	local args = {
		checked = WIDGET.checked,
		widget = WIDGET.GROUP,		--Compatiblity with RadioButton Widget
		user = from_user,			--Compatiblity with RadioButton Widget
	}
	if from_user then
		System.PlaySound("Play_Click021")
	end
	WIDGET:DispatchEvent("OnStateChanged", args)
end

PRIVATE.RefreshState = function(WIDGET, dur)
	dur = dur or .1
	local check_alpha
	
	if WIDGET.disabled then
		WIDGET.mouse_over = false
		WIDGET.mouse_down = false
		if WIDGET.has_focus then
			WIDGET.has_focus = false
			WIDGET.GROUP:ReleaseFocus()
		end
		WIDGET.GROUP:EatMice(false)
		WIDGET.GROUP:ParamTo("alpha", 0.2, dur)
	else
		WIDGET.GROUP:EatMice(true)
		WIDGET.GROUP:ParamTo("alpha", 1, dur)
	end
	
	if WIDGET.mouse_down then
		WIDGET.BACKDROP:ParamTo("tint", RadioButton.DEFAULT_CLICKED_COLOR, dur)
	else
		WIDGET.BACKDROP:ParamTo("tint", RadioButton.DEFAULT_BACKDROP_COLOR, dur)
	end
	
	if WIDGET.mouse_over or WIDGET:HasFocus() then
		WIDGET.BORDER:ParamTo("alpha", 1, dur)
		check_alpha = 1
	else
		WIDGET.BORDER:ParamTo("alpha", 0.6, dur)
		check_alpha = 0.6
	end
	
	if not WIDGET.checked then
		check_alpha = 0
	end
	WIDGET.RADIO:ParamTo("alpha", check_alpha, dur)
end
