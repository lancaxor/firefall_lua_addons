
-- ------------------------------------------
-- lib_ButtonDropList
--   by: Michael Weschler
-- ------------------------------------------
-- Alternate styled Dropdown list that is shown below a button


--[[ Usage:
	DROPDOWN = ButtonDropList.Create(PARENT)	-- Creates a DropDown List
	DROPDOWN:Enable([bool]) -- Sets the button enabled/disabled
	bool = DROPDOWN:IsEnabled() -- returns true if button is enabled/disabled
	DROPDOWN:TintButton(color, [dur, delay, method]) -- tints the button
	DROPDOWN:SetText(text) -- Sets the button label text
	DROPDOWN:FosterLabel(WIDGET) -- Fosters a widget as the button label
	DROPDOWN:Pulse([should_pulse, args]) -- Pulses the button, see lib_Button for args explanation
	DROPDOWN:ToggleList() -- Toggles showing the list
	DROPDOWN:ShowList([show]) -- Shows/hides the list
	bool = DROPDOWN:IsListVisible() -- returns true if the list is visible
	DROPDOWN:TintList(color) -- tints the list background
	DROPDOWN:Destroy() -- destroys the list
	DROPDOWN:ClearList() -- clears all items in the list
	DROPDOWN:RemoveItem(index) -- Removes the item at the specified index
	ITEM = DROPDOWN:AddHeader(text) -- Adds an accented header item
	ITEM = DROPDOWN:AddSelectable(text) -- Adds a selectible(button) item
	ITEM = DROPDOWN:AddCheck(text) -- Adds a checkbox item
	ITEM = DROPDOWN:AddSeparator() -- Adds a separator item
	
	DROPDOWN supports common Widget methods(SetDims, Show, etc)
	
	-- ITEM API --
	
	ITEM:SetText(text) -- sets the text
	ITEM:SetTextKey(key) -- sets the text via a key
	ITEM:Destroy() -- destroys this item object
	ITEM:SetTextColor(color) -- sets the text color
	ITEM:Bind(function) -- binds a function for on click or check toggle
	ITEM:SetCheck(checked) -- sets the check if it is a checkbox item
	bool = ITEM:GetCheck() -- returns true if the checkbox is checked. checkbox items only
	ITEM:Enable([enabled]) -- Sets the item enabled
	ITEM:Disable([disabled]) -- Sets the item disabled
	bool = ITEM:IsEnabled() -- returns true if the item is enabled
--]]

if ButtonDropList then
	return
end

ButtonDropList = {}
local BDL_API = {}
local ITEM_API = {}
local PRIVATE = {}


require "lib/lib_Callback2"
require "lib/lib_EventDispatcher"

-- ------------------------------------------
-- Constants
-- ------------------------------------------

local DropListAlt_MT = {__index = function(self, key) return BDL_API[key] end}
local Item_MT = {__index = function(self, key) return ITEM_API[key] end}
local Destroyed_MT = {__index = function(self, key) error("Object has been destroyed, cannot index") end}

local SURROUND_PADDING = 6
local DROP_PADDING = 10
local DEFAULT_TINT = "#222222"
local HEADER_COLOR = "#EABF01"
local CHECK_SIZE = 18
local CHECK_SPACER = 25
local DEFAULT_HEIGHT = 24

local BP_BDL = [[<Group dimensions="dock:fill">
		<Border name="surround" class="ButtonSolid" dimensions="left:-]]..SURROUND_PADDING..[[; right:100%+]]..SURROUND_PADDING..[[; top:-]]..SURROUND_PADDING..[[; bottom:100%+]]..(SURROUND_PADDING + 5)..[[" style="alpha:0; tint:]]..DEFAULT_TINT..[[; exposure:0;"/>
		<Button name="button" dimensions="dock:fill" style="font:Demi_11;"/>
	</Group>]]

local BP_FRAME = [[<PanelFrame dimensions="dock:fill" topmost="true" depth="1"/>]]
local BP_SCREENFOCUS = [[<Group dimensions="dock:fill">
		<FocusBox name="focus" dimensions="dock:fill" style="cursor:sys_arrow"/>
		<FocusBox name="button" dimensions="dock:fill" class="ui_button"/>
	</Group>]]

local BP_DROPDOWN = [[<Group dimensions="dock:fill" style="clip-children:true">
		<Border name="background" class="ButtonSolid" dimensions="dock:fill" style="exposure:0"/>
		<ListLayout name="list" dimensions="dock:fill" style="vpadding:3; clip-children:true"/>
	</Group>]]
local BP_HEADER = [[ <Group dimensions="left:0; top:0; width:100%; height:100%">
		<Text name="text" dimensions="left:]]..DROP_PADDING..[[; top:0; width:100; height:18;" style="font:UbuntuMedium_10; padding:0; valign:center;"/>
	</Group>]]
	
local BP_SELECTABLE = [[<FocusBox name="focus" dimensions="left:0; top:0; width:100%; height:100%" class="ui_button">
		<Border name="highlight" dimensions="dock:fill" class="ButtonSolid" style="alpha:0"/>
		<Text name="text" dimensions="left:]]..DROP_PADDING..[[; top:0; width:100; height:18;" style="font:UbuntuMedium_9; padding:0; valign:center;"/>
	</FocusBox>]]
	
local BP_CHECK = [[<Group dimensions="left:0; top:0; width:100%; height:100%">
		<CheckBox name="check" dimensions="left:]]..DROP_PADDING..[[; top:0; width:]]..CHECK_SIZE..[[; height:]]..CHECK_SIZE..[[;" style="font:UbuntuMedium_9;"/>
	</Group>]]
	
local BP_SEPARATOR = [[<Group dimensions="left:0; top:0; width:100%; height:]]..(DEFAULT_HEIGHT / 4)..[[">
		<StillArt dimensions="left:]]..(DROP_PADDING / 2)..[[; center-y:50%; right:100%-5; height:1" style="texture:colors; region:white; tint:#555555"/>
	</Group>]]
-- ------------------------------------------
-- BDL Interface
-- ------------------------------------------

function ButtonDropList.Create(PARENT)
	local WIDGET = Component.CreateWidget(BP_BDL, PARENT)
	local BDL =
	{
		GROUP 		= WIDGET,
		BUTTON 		= WIDGET:GetChild("button"),
		SURROUND 	= WIDGET:GetChild("surround"),
		FRAME		= false,
		FOCUS_GRP	= false,
		FOCUS		= false,
		DROPDOWN	= false,
		visible		= false,
		tint		= false,
		list_items 	= {},
	}
	
	setmetatable(BDL, DropListAlt_MT)
	
	BDL.BUTTON:BindEvent("OnSubmit", function() BDL.ToggleList(BDL) end)
	--BDL.BUTTON:SetPressSound("button_press")
	
	PRIVATE.SetupFrame(BDL)
	
	return BDL
end

-- ------------------------------------------
-- BDL Object functions
-- ------------------------------------------

local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	BDL_API[method_name] = function(BDL, ...)
		return BDL.GROUP[method_name](BDL.GROUP, ...);
	end
end

function BDL_API:Enable()
	self.BUTTON:Enable()
end

function BDL_API:Disable()
	self.BUTTON:Disable()
end

function BDL_API:IsEnabled()
	return self.BUTTON:IsEnabled()
end

function BDL_API:TintButton(color, dur, delay, method)
	if dur then
		self.BUTTON:ParamTo("tint", color, dur, delay, method)
	else
		self.BUTTON:ParamTo("tint", color)
	end
end

function BDL_API:SetText(text)
	self.BUTTON:SetText(text)
end

function BDL_API:Pulse(should_pulse, args)
	--self.BUTTON:Pulse(should_pulse, args)
end

function BDL_API:ToggleList()
	self:ShowList(not self:IsListVisible())
end

function BDL_API:ShowList(show)
	if show == nil then
		show = not self.visible
	end
	if self.visible ~= show then
		System.PlaySound("button_press")
	end
	PRIVATE.ShowDropDown(self, show)
	
	self.visible = show
end

function BDL_API:IsListVisible()
	return self.visible
end

function BDL_API:TintList(color)
	self.tint = color
	self.SURROUND:SetParam("tint", color)
end

function BDL_API:Destroy()
	self:ClearList()
	if self.DROPDOWN then
		Component.RemoveFrame(self.DROPDOWN.FRAME)
	end
	Component.RemoveWidget(self.GROUP)
	setmetatable(self, Destroyed_MT)
end

function BDL_API:ClearList()
	for _, item in ipairs(self.list_items) do
		item:Destroy()
	end
	
	self.list_items = {}
end

function BDL_API:RemoveItem(index)
	local item = self.list_items[index]
	item:Destroy()
	self.list_items[index] = nil
end

function BDL_API:AddHeader(text)
	local HEADER = PRIVATE.CreateItem("header", text, self.DROPDOWN.LIST)
	HEADER:SetTextColor(HEADER_COLOR)
	table.insert(self.list_items, HEADER)
	
	return HEADER
end

function BDL_API:AddSelectable(text)
	local SELECTABLE = PRIVATE.CreateItem("selectable", text, self.DROPDOWN.LIST)
	SELECTABLE.GROUP:BindEvent("OnMouseEnter", function()
		SELECTABLE.HIGHLIGHT:ParamTo("alpha", 0.3, 0.1)
		System.PlaySound("rollover")
	end)
	SELECTABLE.GROUP:BindEvent("OnMouseLeave", function()
		SELECTABLE.HIGHLIGHT:ParamTo("alpha", 0, 0.1)
	end)
	SELECTABLE.GROUP:BindEvent("OnMouseDown", function()
		SELECTABLE.HIGHLIGHT:ParamTo("alpha", 0.2, 0.1)
	end)
	SELECTABLE.GROUP:BindEvent("OnMouseUp", function()
		SELECTABLE.HIGHLIGHT:ParamTo("alpha", 0.3, 0.1)
		if SELECTABLE.click_action then
			self:ToggleList()
			System.PlaySound("button_press")
			SELECTABLE.click_action()
		end
	end)
	
	table.insert(self.list_items, SELECTABLE)
	
	return SELECTABLE
end

function BDL_API:AddCheck(text)
	local CHECK_ITEM = PRIVATE.CreateItem("check", text, self.DROPDOWN.LIST)
		
	CHECK_ITEM.CHECK:BindEvent("OnStateChanged", function()
		if CHECK_ITEM.click_action then
			CHECK_ITEM.click_action(CHECK_ITEM.CHECK:GetCheck())
		end
	end)
	


	table.insert(self.list_items, CHECK_ITEM)
	
	return CHECK_ITEM
end

function BDL_API:AddSeparator()
	local SEPARATOR_ITEM = PRIVATE.CreateItem("separator", "", self.DROPDOWN.LIST)
	
	table.insert(self.list_items, SEPARATOR_ITEM)
	
	return SEPARATOR_ITEM
end

-- ------------------------------------------
-- Private Functions
-- ------------------------------------------

function PRIVATE.ShowDropDown(self, show)
	if show then
		PRIVATE.UpdateDropPosition(self)
		self.FRAME:Show(true)
		self.SURROUND:SetParam("alpha", 1)
		local bounds = self.DROPDOWN.LIST:GetContentBounds()
		
		--resize items to all have the same width
		for i=1, self.DROPDOWN.LIST:GetChildCount() do
			self.DROPDOWN.LIST:GetChild(i):SetDims("top:_; left:_; height:_; width:"..tostring(bounds.width))
		end
		
		self.DROPDOWN.LIST:SetDims("top:"..(DROP_PADDING).."; left:5; width:0; height:0")
		self.DROPDOWN.LIST:MoveTo("top:_; left:_; width:"..bounds.width.."; height:"..bounds.height,0.1)
		self.DROPDOWN.GROUP:SetDims("top:_; left:_; width:0; height:0")
		self.DROPDOWN.GROUP:MoveTo("top:_; left:_; width:"..(bounds.width+DROP_PADDING).."; height:"..(bounds.height+(DROP_PADDING * 2)), 0.1)
	else
		self.FRAME:Show(false, 0.1)
		self.DROPDOWN.GROUP:MoveTo("top:_; left:_; width:0; height:0", 0.1)
		self.SURROUND:ParamTo("alpha", 0, 0.1, 0.1)
	end
end

function PRIVATE.CreateItem(item_type, text, PARENT)
	local BP
	if item_type == "header" then
		BP = BP_HEADER
	elseif item_type == "selectable" then
		BP = BP_SELECTABLE
	elseif item_type == "check" then
		BP = BP_CHECK
	elseif item_type == "separator" then
		BP = BP_SEPARATOR
	end
	local WIDGET = Component.CreateWidget(BP, PARENT)
	local ITEM = {
		GROUP = WIDGET,
		HIGHLIGHT = WIDGET:GetChild("highlight"),
		item_type = item_type,
		click_action = false,
		disabled = false,
	}

	if item_type == "check" then
		ITEM.CHECK = WIDGET:GetChild("check")
		ITEM.CHECK:SetText(text)
	else
		ITEM.TEXT = WIDGET:GetChild("text")
	end
	
	
	setmetatable(ITEM, Item_MT)
	
	if item_type ~= "separator" then
		ITEM:SetText(text)
	end
	
	return ITEM
end

function PRIVATE.SetupFrame(self)
	if self.FRAME then
		self.FRAME:Show(true)
		return
	end
	self.FRAME = Component.CreateFrame(BP_FRAME, "AltDropDown")
	self.FOCUS_GRP = Component.CreateWidget(BP_SCREENFOCUS, self.FRAME)
	self.FOCUS = self.FOCUS_GRP:GetChild("focus")
	self.FRAME:Show(false)
	local WIDGET = Component.CreateWidget(BP_DROPDOWN, self.FRAME)
	self.DROPDOWN = {
		GROUP = WIDGET,
		BTN_MASK = self.FOCUS_GRP:GetChild("button"),
		BACKGROUND = WIDGET:GetChild("background"),
		LIST = WIDGET:GetChild("list"),
	}
	
	self.FRAME:BindEvent("OnClose", function()
		self.SURROUND:ParamTo("alpha", 0, 0.1)
		self.visible = false
	end)
	
	local tint = self.tint or DEFAULT_TINT
	if tint then
		self.DROPDOWN.BACKGROUND:SetParam("tint", tint)
	end
	
	self.FOCUS:BindEvent("OnMouseDown", function()
		self:ShowList(false)
	end)
	
	self.DROPDOWN.BTN_MASK:BindEvent("OnMouseDown", function()
		self:ShowList(false)
	end)
	
	PRIVATE.UpdateDropPosition(self)
end

function PRIVATE.UpdateDropPosition(self)
	local bounds = self.SURROUND:GetBounds()
	local btn_bounds = self.GROUP:GetBounds()
	self.DROPDOWN.GROUP:SetDims("top:"..(bounds.bottom-8).."; left:"..bounds.left.."; width:_; height:_")
	self.DROPDOWN.BTN_MASK:SetDims("top:"..btn_bounds.top.."; left:"..btn_bounds.left.."; width:"..btn_bounds.width.."; height:"..btn_bounds.height)
end

-- ------------------------------------------
-- Item API
-- ------------------------------------------

function ITEM_API:SetText(text)
	local textWidth
	if self.CHECK then
		self.CHECK:SetText(text)
		textWidth = self.CHECK:GetTextDims().width + DROP_PADDING
	else
		self.TEXT:SetText(text)
		textWidth = self.TEXT:GetTextDims().width + DROP_PADDING
	end
	local groupWidth = textWidth + DROP_PADDING
	if self.CHECK then
		groupWidth = groupWidth + CHECK_SPACER
		self.CHECK:SetDims("top:3; left:_; width:"..(groupWidth).."; height:18")
	else
		self.TEXT:SetDims("top:3; left:_; width:"..(textWidth).."; height:18")
	end
	
	self.GROUP:SetDims("top:_; left:_; width:"..(groupWidth).."; height:"..DEFAULT_HEIGHT)
end

function ITEM_API:SetTextKey(key)
	local text = Component.LookupText(key)
	self:SetText(text)
end

function ITEM_API:Destroy()
	Component.RemoveWidget(self.GROUP)
	setmetatable(self, Destroyed_MT)
end

function ITEM_API:SetTextColor(color)
	if self.CHECK then
		self.CHECK:SetTextColor(color)
	else
		self.TEXT:SetTextColor(color)
	end
end

function ITEM_API:Bind(func)
	if type(func) ~= "function" then
		warn("Cannot bind a non-function")
		return
	end
	self.click_action = func
end

function ITEM_API:SetCheck(checked)
	if self.CHECK then
		self.CHECK:SetCheck(checked)
	else
		warn("Attempted to use SetCheck on a non-checkbox item")
	end
end

function ITEM_API:GetCheck()
	if self.CHECK then
		return self.CHECK:GetCheck()
	else
		warn("Attempted to use IsChecked on a non-checkbox item")
	end
end

function ITEM_API:Enable(enabled)
	self.disabled = not enabled
	if self.CHECK then
		self.CHECK:Enable(enabled)
	end
end

function ITEM_API:Disable(enabled)
	self:Enable(not enabled)
end

function ITEM_API:IsEnabled()
	return not self.disabled
end
