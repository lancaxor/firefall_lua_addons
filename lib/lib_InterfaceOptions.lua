
-- ------------------------------------------
-- lib_InterfaceOptions
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
Base Functions:
	InterfaceOptions.AddMovableFrame(table)
		frame = [GUI or name] the var for the frame or the name of the frame
		scalable = [boolean] defines if the frame should be scalable
		label or label_key = [string] the frame's label or the SDB key string for the label

	InterfaceOptions.SaveVersion(number)    --optional function
		if not used then the assumed version is 1
		Use to ignore saved values if the saved version number is different then the current one

	InterfaceOptions.SetCallbackFunc(func [, title])    --required function
		this may only be called once and it must be done during ON_COMPONENT_LOAD
		func must be a function if you have options or false/nil if you just have movable frames without options
			the func will recieve (id, val) as args
		title is an optional override for the options header/root label, by default it uses the title assigned in the xml

	InterfaceOptions.NotifyOnDefaults(boolean)    --optional function
		this will fire the func supplied by SetCallbackFunc with the id of "__DEFAULT", incase you want to know when the user default all the options

	InterfaceOptions.NotifyOnLoaded(boolean)    --optional function
		this will fire the func supplied by SetCallbackFunc with the id of "__LOADED", incase you want to know when all the options are finished loading

	InterfaceOptions.NotifyOnDisplay(boolean)    --optional function
		this will fire the func supplied by SetCallbackFunc with the id of "__DISPLAY" and a boolean value for if the interface options are visible
		Useful for conditionally displayed UI to display a dummy version for interface configuring

	InterfaceOptions.NotifyOnResize(boolean)    --optional function
		this will fire the func supplied by SetCallbackFunc with the id of "__RESIZE", incase you need to handle any frames getting resized

Option Creation Functions:
	Note Temp WIP Feature:
		all the following options support a table field of subtab which should be an array of strings, except AddChoiceEntry which isn't really an option
		this will place the option into a sub-tab based on those fields
		ie: InterfaceOptions.AddCheckBox({id="wip", label="wip", default=true, subtab={"Sub1","Sub2"}})
			Interface>ComponentName>Sub1>Sub2  is the tab tree in which you will find this option
		to place multiple option in the same sub-tab, they will all need to have the same subtab array
		there is currently no limit to the depth of nested sub-tabs outside of the indenting the tabs get
		This sub-tab system might get a facelift in the future when R5 components start using it more

	InterfaceOptions.AddMultiArt(table)
		id = [string] unique identifier
		url = [string] url of a WebImage						--use 1 out of the 3; url, icon, or texture
		icon = [number] id of an Icon
		texture = [string] texture name of a Texture			--will accept textures defined in the components xml as well as the human_skin
		region = [string][optional] region name for a Texture
		width = [number] width for the image					--use 2 out of the 3; height, width, or aspect
		height = [number] height for the image
		aspect = [number] height for the image
		padding = [number][optional] padding + height determines how much height the entry takes up
		y_offset = [string][optional] +number or -number; center-y:50%"..y_offset; offsets the image from the center of the entry
		x_offset = [string][optional] +number or -number; center-x:50%"..x_offset; offsets the image from the center of the entry
		tint = [string][optional] tint to apply to the image
		OnClickUrl = [string][optional] OnClick of the image will open an external browser to the supplied url

	InterfaceOptions.AddButton(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		Note: a button will trigger the SetCallbackFunc witht he id and no value whenever it is clicked

	InterfaceOptions.StartGroup(table)
		label or label_key = [string] the option's label or the SDB key string for the label
		checkbox = [boolean][optional] this adds a checkbox to the group which will have a working value as well as collapse the group when it is unchecked, useful if a group of options has a disable option
			the following are only needed if checkbox is true
			id = [string] unique identifier
			tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
			default = [boolean] the default value for the option
		Note: nested groups are not supported, each StartGroup needs to have a StopGroup before a new start can be triggered.

	InterfaceOptions.StopGroup()
		Note: nested groups are not supported, each StartGroup needs to have a StopGroup before a new start can be triggered.
		no params needed

	InterfaceOptions.AddCheckBox(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		default = [boolean] the default value for the option

	InterfaceOptions.AddSlider(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		default = [number] the default value for the option
		min = [number] the minimum range
		max = [number] the maximum range
		inc = [number] the increment amounts
		multi = [number][optional] muliples the value with the multi for displaying, used with percents that are 0-1 to display as 0-100 with a multi of 100
		format = [string][optional] the format to use in unicode.format(format, value) for the displayed value, does not affect value's value, use '%0.0f' instead of '%d' for integers
		prefix = [string][optional] prefix for the displayed number
		suffix = [string][optional] suffix for the displayed number, useful for adding '%' or 's' for percents and seconds

	InterfaceOptions.AddTextInput(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		default = [string] the default value for the option
		numeric = [boolean][optional][default: false] enforces only numeric chars [0123456789-.]
		masked = [boolean][optional][default: false] masks the text with ********, this is a visual only mask, the saved value will not be masked
		whitespace = [boolean][optional][default: true] whether to allow spaces or not
		maxlen = [number][optional][default: 256] max char length of the text input box

	InterfaceOptions.AddColorPicker(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		default = [table] the default value for the option
			tint = [string] the RRGGBB hex color code
			alpha = [number range: 0 -- 1][optional] alpha value if the alpha is to be adjustable
			exposure = [number range: -1 -- 1][optional] exposure value if the exposure is to be adjustable

	InterfaceOptions.AddChoiceMenu(table)
		id = [string] unique identifier
		label or label_key = [string] the option's label or the SDB key string for the label
		tooltip or tooltip_key = [string][optional] like label except displays on mouseover in a popup if present
		default = [string] the default value for the option, must link up with a choice's val
		NOTE: all values from a ListMenu come back as strings, even if the entries value was defined as a number

	InterfaceOptions.AddChoiceEntry(table)
		menuId = [string] the AddListMenu id that this choice is attacted to
		label or label_key = [string] the choice's label or the SDB key string for the label
		val = [string] the value for the choice entry

Option Manipulation Functions:
	InterfaceOptions.DisableOption(ID, bool)
		ID = [string] the option id that you want to disable
		bool = [boolean] true = disabled, false = enabled
	InterfaceOptions.EnableOption(ID, bool)
		ID = [string] the option id that you want to disable
		bool = [boolean] true = enabled, false = disabled
	InterfaceOptions.UpdateLabel(ID, label[, key])
		ID = [string] the option id that you want to disable
		label = [string] the new label for the option, or keystring if key is true
		key = [boolean][optional] whether the label is a key_string that needs to be lookedup first

Frame Manipulation Functions:
	InterfaceOptions.ChangeFrameHeight(frame, val)
		frame = [GUI or name] the var for the frame or the name of the frame
		val = [number] new frame height

	InterfaceOptions.ChangeFrameWidth(frame, val)
		frame = [GUI or name] the var for the frame or the name of the frame
		val = [number] new frame width

	InterfaceOptions.UpdateMovableFrame(frame)
		frame = [GUI or name] the var for the frame or the name of the frame
		used if the frame had to be tinkered with and you want to get it realigned and the position saved

	InterfaceOptions.DisableFrameMobility(frame, bool)
		frame = [GUI or name] the var for the frame or the name of the frame
		bool = [boolean] true = removes the frames mobility outline, false = displays it
--]]

InterfaceOptions = {}	--table for all the global function

--require "unicode"
require "table"
require "lib/lib_math"
require "lib/lib_table"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_SaveVersion = "_Options_Version"
local c_DefaultVersion = 1
local c_SaveFrameDims = "FrameDims:"
local c_SaveFrameScale = "FrameScale:"
local c_SaveFrameSize = "FrameSize:"
local c_SaveOption = "Option"
local c_FileName, c_OptionTitle = Component.GetInfo()
local c_ReplyPath = Liaison.GetPath()
local f_CallbackFunction

local lf = {}			--table for local functions
local lcb = {}			--table for liasion callback functions

local c_ResizablePadding = 20
local c_ArtStyles = {
	enabled = {
		glow = "#AA0055ff",
		alpha = 0.5,
		exposure = 0.3,
	},
	highlighted = {
		glow = "#AA0055ff",
		alpha = 0.9,
		exposure = 0.5,
	},
}

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local w_FRAMES = {}
local w_PANELS = {}
local d_Options = {}
local w_MultiArt = {}

local g_SaveVersion = c_DefaultVersion
local g_NotifyOnDefault = false
local g_NotifyOnLoaded = false
local g_NotifyOnDisplay = false
local g_NotifyOnResize = false
local g_Highlighted = false
local g_ShowPanels = false
local g_Dragging = false
local g_LoadingFinished = false				--becomes true after the options Screen reports that it finished initing
local g_PostToMainQueue = {}				--a queue for options that need to change their disable status, only used while (g_LoadingFinished == false)
local g_HasOnLoadRan = false

local g_ResizeName
local g_ResizePin
local g_ResizeResize

-- Incase you want to force all options to use default settings on load, set to true
local g_UseDefaultSettings = false
-- Incase you want to prevent all options from saving their new settings
local g_SaveSettings = true

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
-- ___ FOR OPTIONS
InterfaceOptions.SaveVersion = function(number)
	if type(number) == "number" or type(number) == "string" then
		g_SaveVersion = number
	else
		warn("SaveVersion param must be a number or a string")
	end
end

InterfaceOptions.SetCallbackFunc = function(func, title)
	if type(func) == "function" then
		if f_CallbackFunction == nil then
			f_CallbackFunction = func
			if title then c_OptionTitle = Component.RemoveLocalizationTracking(title) end
			callback(lf.OnLoad, nil, 0.05) --See Option's Interface.lua for OnLoad Timeline before changing
		end
	elseif not func and #d_Options == 0 then
		if f_CallbackFunction == nil then
			f_CallbackFunction = false
			callback(lf.OnLoad, nil, 0.05) --See Option's Interface.lua for OnLoad Timeline before changing
		end
	else
		error("Bad SetCallbackFunc param, Must be a function if Options are present")
	end
end

InterfaceOptions.NotifyOnDefaults = function(bool)
	if type(bool) == "boolean" then
		g_NotifyOnDefault = bool
	end
end

InterfaceOptions.NotifyOnLoaded = function(bool)
	if type(bool) == "boolean" then
		g_NotifyOnLoaded = bool
	end
end

InterfaceOptions.NotifyOnDisplay = function(bool)
	if type(bool) == "boolean" then
		g_NotifyOnDisplay = bool
	end
end

InterfaceOptions.NotifyOnResize  = function(bool)
	if type(bool) == "boolean" then
		g_NotifyOnResize = bool
	end
end

InterfaceOptions.AddCheckBox = function(option)
	option = lf.GetBaseOption(option)
	option.type = "checkbox" --used in the save keystring, do not change
	table.insert(d_Options, option)
end

InterfaceOptions.AddSlider = function(option)
	option = lf.GetBaseOption(option)
	option.type = "slider" --used in the save keystring, do not change
	option.default = math.max(math.min(option.default, option.max), option.min)
	table.insert(d_Options, option)
end

InterfaceOptions.AddTextInput = function(option)
	option = lf.GetBaseOption(option)
	option.type = "textinput" --used in the save keystring, do not change
	table.insert(d_Options, option)
end

InterfaceOptions.AddColorPicker = function(option)
	option = lf.GetBaseOption(option)
	option.type = "colorpicker" --used in the save keystring, do not change
	table.insert(d_Options, option)
end

InterfaceOptions.AddChoiceMenu = function(option)
	option = lf.GetBaseOption(option)
	option.type = "listmenu" --used in the save keystring, do not change
	option.list = {}
	table.insert(d_Options, option)
end

InterfaceOptions.AddChoiceEntry = function(tbl)
	if tbl.label_key then
		tbl.label = Component.LookupText(tbl.label_key)
		tbl.label_key = nil
	end
	local option = lf.FindOption(tbl.menuId)
	table.insert(option.list, tbl)
end

InterfaceOptions.StartGroup = function(option)
	option = lf.GetBaseOption(option)
	option.type = "StartGroup" --used in the save keystring, do not change
	table.insert(d_Options, option)
end

InterfaceOptions.StopGroup = function(option)
	if type(option) ~= "table" then
		option = {}
	end
	option.type = "StopGroup"
	table.insert(d_Options, option)
end

InterfaceOptions.AddMultiArt = function(option)
	option.type = "MultiArt" --used in the save keystring, do not change
	if option.texture then
		local id = #w_MultiArt + 1
		local widget = Component.CreateWidget("<StillArt dimensions='dock:fill' style='texture:colors; region:white;'/>", Liaison.GetFrame())
		table.insert(w_MultiArt, widget)
		widget:SetTexture(option.texture)
		if option.region then
			widget:SetRegion(option.region)
		end
		if option.tint then
			widget:SetParam("tint", option.tint)
			option.tint = nil
		end
		option.texture, option.region = nil, nil
		option.foster = id
	end
	table.insert(d_Options, option)
end

InterfaceOptions.AddButton = function(option)
	option = lf.GetBaseOption(option)
	option.type = "Button" --used in the save keystring, do not change
	table.insert(d_Options, option)
end

InterfaceOptions.DisableOption = function(ID, bool)
	if lf.FindOption(ID) then
		local com = "DisableOption"
		local data = {id=ID, bool=bool, filename=c_FileName}
		lf.PostToMain(com, data, true)
	else
		warn("No Option with this id: "..ID)
	end
end
InterfaceOptions.EnableOption = function(ID, bool)
	InterfaceOptions.DisableOption(ID, not bool)
end

InterfaceOptions.UpdateLabel = function(ID, new_label, key)
	if lf.FindOption(ID) then
		if key then
			new_label = Component.LookupText(new_label)
		end
		local com = "UpdateLabel"
		local data = {id=ID, label=new_label, filename=c_FileName}
		lf.PostToMain(com, data, true)
	else
		warn("No Option with this id: "..ID)
	end
end

-- ___ FOR FRAMES
InterfaceOptions.AddMovableFrame = function(tbl)
	assert(not(tbl.scalable and tbl.resizable), "Resizable and Scalable are currently mutually exclusive")
	local name, FRAME = lf.GetFrameName(tbl.frame)
	if w_FRAMES[name] then
		warn("Frame already added as a movable frame")
		return nil
	end
	w_FRAMES[name] = {FRAME=FRAME, scalable=tbl.scalable, resizable=tbl.resizable}
	if tbl.scalable then
		w_FRAMES[name].currentScale = 100
	end
	local bounds = w_FRAMES[name].FRAME:GetBounds(false)
	w_FRAMES[name].height = bounds.height
	w_FRAMES[name].width = bounds.width
	w_PANELS[name] = lf.CreateMovablePanel(name, tbl.resizable)
	w_PANELS[name].FRAME:SetDims(FRAME:GetInitialDims())
	if tbl.label_key then
		w_PANELS[name].label = Component.LookupText(tbl.label_key)
	elseif tbl.label then
		w_PANELS[name].label = tbl.label
	else
		w_PANELS[name].label = "Error: No Label"
	end
	lf.ModPanel(name)
	if g_HasOnLoadRan then
		lf.LoadFrameDims(name)
	end
	if g_ShowPanels then
		lf.ShowPanel(name)
	end
end

InterfaceOptions.RemoveMovableFrame = function(frame)
	local name, FRAME = lf.GetFrameName(frame)
	if w_FRAMES[name] and w_PANELS[name] then
		Component.RemoveFrame(w_PANELS[name].FRAME)
		for k,v in pairs(w_FRAMES[name]) do
			w_FRAMES[name][k] = nil
		end
		w_FRAMES[name] = nil
		for k,v in pairs(w_PANELS[name]) do
			w_PANELS[name] = nil
		end
		w_PANELS[name] = nil
		lf.SaveSetting(c_SaveFrameScale..name, nil)
		lf.SaveSetting(c_SaveFrameDims..name, nil)
		lf.SaveSetting(c_SaveFrameSize..name, nil)
	else
		warn("Frame not found")
	end
end

InterfaceOptions.ChangeFrameHeight = function(frame, val)
	local name, FRAME = lf.GetFrameName(frame)
	w_FRAMES[name].FRAME:SetDims(lf.CreateDims(name).."width:_; height:"..val)
	w_FRAMES[name].height = val
	lf.ApplyScale(name)
end

InterfaceOptions.ChangeFrameWidth = function(frame, val)
	local name, FRAME = lf.GetFrameName(frame)
	w_FRAMES[name].FRAME:SetDims(lf.CreateDims(name).."height:_; width:"..val)
	w_FRAMES[name].width = val
	lf.ApplyScale(name)
end

InterfaceOptions.UpdateMovableFrame = function(frame, dur)
	local name, FRAME = lf.GetFrameName(frame)
	lf.MoveToDims(name, lf.GetBindings(name)..lf.GetSizeDims(name), dur)
	lf.ApplyScale(name)
end

InterfaceOptions.DisableFrameMobility = function(frame, bool)
	local name, FRAME = lf.GetFrameName(frame)
	local PANEL = w_PANELS[name]
	PANEL.Disabled = bool
	if g_ShowPanels then
		if bool then
			PANEL.FRAME:Hide(true, 0.25)
			PANEL.FRAME:ParamTo("alpha", 0, 0.25, 0, "ease-out")
		else
			PANEL.FRAME:Show(not bool)
			PANEL.FRAME:ParamTo("alpha", 1, 0.25, 0, "ease-out")
		end
	end
end

InterfaceOptions.OpenToMyOptions = function()
	local data = {filename=c_FileName}
	lf.PostToMain("OpenInterfaceOptions", data)
end

-- ------------------------------------------
-- EVENTS
-- ------------------------------------------
lf.OnLoad = function()
	--DEMO MODE CHECK
	local demoMode = System.GetConfig("Demo", "DemoMode")
	if (demoMode == "1") then
		--if we are in demo mode, don't load/save saved settings
		g_UseDefaultSettings = true
		g_SaveSettings = false
	end
	--VERSION CHECK
	local version = Component.GetSetting(c_SaveVersion)
	local updateVersion = false
	if not version then 
		updateVersion = true
		version = c_DefaultVersion
	end
	if version ~= g_SaveVersion then
		log("Version Mismatch: "..c_FileName)
		updateVersion = true
		g_UseDefaultSettings = true
	end
	if updateVersion then
		lf.SaveSetting(c_SaveVersion, g_SaveVersion)
	end
	--LOAD SAVED FRAME DIMS
	for name, _ in pairs(w_FRAMES) do
		lf.LoadFrameDims(name)
	end
	--LOAD SAVED SETTING VALUES
	for i, option in ipairs(d_Options) do
		if option.id then
			local saved = Component.GetSetting(c_SaveOption.."-"..option.type..":"..option.id)
			if saved ~= nil and not g_UseDefaultSettings then --if using saved value
				local goodSave = true
				if option.type == "listmenu" then --make sure listmenu option is still there
					local found = false
					for _, entry in ipairs(option.list) do
						if entry.val == saved then
							found = true
						end
					end
					if not found then
						goodSave = false
					end
				elseif option.type == "slider" then --make sure saved value is within range
					if saved < option.min or saved > option.max then
						goodSave = false
					end
				end
				if goodSave then --use good saved value
					option.value = _table.copy(saved)
					option.saved = _table.copy(saved)
				else --bad saved value: reset to default
					option.value = _table.copy(option.default)
					option.saved = _table.copy(option.default)
				end
			else --no saved value: use default
				option.value = _table.copy(option.default)
				option.saved = _table.copy(option.default)
				if g_UseDefaultSettings then
					lf.SaveSetting(c_SaveOption.."-"..option.type..":"..option.id, nil)
				end
			end
		end
	end
	g_HasOnLoadRan = true
	-- REGISTER WITH MAIN
	local data = {filename=c_FileName, displayname=c_OptionTitle, options=d_Options, reply=c_ReplyPath, isAddon=Component.IsAddon()}
	lf.PostToMain("Register", data)
	-- SEND INITIAL SETTINGS TO PARENT
	for i, option in ipairs(d_Options) do
		--sending all options, even ones at default value, expect Button as they are a fire on click type
		--this allows the option selection code to be able to init settings aswell
		if option.type ~= "Button" then
			lf.SendToParent(option)
		end
	end
	if g_NotifyOnLoaded and f_CallbackFunction then
		--tells the component that the options are done loading if it cared to know about this
		f_CallbackFunction("__LOADED", nil)
	end
end

function lf.OnMouseEnter(args)
	if not g_ShowPanels then return end
	local name = args.widget:GetTag()
	g_Highlighted = name
	lf.ModPanel(name)
	lf.ShowFrameTooltip(name)
end

function lf.OnMouseLeave(args)
	if not g_ShowPanels then return end
	local name = args.widget:GetTag()
	g_Highlighted = nil
	lf.ModPanel(name)
	lf.HideFrameTooltip(name)
end

function lf.OnMouseDown(args)
	if not g_ShowPanels then return end
	local name = args.widget:GetTag()
	lf.PostToMain("Dragging", "true")
	w_PANELS[name].FRAME:SetDepth(0)
	if w_FRAMES[name].scalable and w_FRAMES[name].currentScale ~= 100 then
		-- s_=screen, f_=frame, c_=cursor
		local c_X, c_Y = Component.GetCursorPos()
		local s_width, s_height = Component.GetScreenSize(false)
		local f_scale = w_FRAMES[name].currentScale/100
		local f_height = w_FRAMES[name].height
		local f_width = w_FRAMES[name].width
		
		local d = w_FRAMES[name].currentDims
		local dim_string = lf.GetSizeDims(name)
		if d.Ybound == "top" then
			local y = (f_height * f_scale - f_height) * ((c_Y - (s_height * (d.Ypct/100))) / (f_height * f_scale))
			dim_string = dim_string..d.Ybound..":"..((d.Ypct/100)*s_height)+y.."; "
		elseif d.Ybound == "bottom" then
			local y = (f_height * f_scale - f_height) * (((s_height * (d.Ypct/100)) - c_Y) / (f_height * f_scale))
			dim_string = dim_string..d.Ybound..":"..((d.Ypct/100)*s_height)-y.."; "
		elseif d.Ybound == "center-y" then
			if (s_height * (d.Ypct/100)) - c_Y < 0 then
				local y = (f_height * f_scale - f_height) * ((c_Y - (s_height * (d.Ypct/100))) / (f_height * f_scale))
				dim_string = dim_string..d.Ybound..":"..((d.Ypct/100)*s_height)+y.."; "
			else
				local y = (f_height * f_scale - f_height) * (((s_height * (d.Ypct/100)) - c_Y) / (f_height * f_scale))
				dim_string = dim_string..d.Ybound..":"..((d.Ypct/100)*s_height)-y.."; "
			end
		end
		if d.Xbound == "left" then
			local x = (f_width * f_scale - f_width) * ((c_X - (s_width * (d.Xpct/100))) / (f_width * f_scale))
			dim_string = dim_string..d.Xbound..":"..((d.Xpct/100)*s_width)+x.."; "
		elseif d.Xbound == "right" then
			local x = (f_width * f_scale - f_width) * (((s_width * (d.Xpct/100)) - c_X) / (f_width * f_scale))
			dim_string = dim_string..d.Xbound..":"..((d.Xpct/100)*s_width)-x.."; "
		elseif d.Xbound == "center-x" then
			if (s_width * (d.Xpct/100)) - c_X < 0 then
				local x = (f_width * f_scale - f_width) * ((c_X - (s_width * (d.Xpct/100))) / (f_width * f_scale))
				dim_string = dim_string..d.Xbound..":"..((d.Xpct/100)*s_width)+x.."; "
			else
				local x = (f_width * f_scale - f_width) * (((s_width * (d.Xpct/100)) - c_X) / (f_width * f_scale))
				dim_string = dim_string..d.Xbound..":"..((d.Xpct/100)*s_width)-x.."; "
			end
		end
		w_FRAMES[name].FRAME:SetDims(dim_string)
		w_FRAMES[name].FRAME:SetParam("ScaleX", f_scale)
	end
	w_PANELS[name].FRAME:SetDims("relative:cursor")
	w_FRAMES[name].FRAME:SetDims("relative:cursor")
end

function lf.OnMouseUp(args)
	if not g_ShowPanels then return end
	local name = args.widget:GetTag()
	lf.PostToMain("Dragging", "false")
	w_PANELS[name].FRAME:SetDims("relative:screen")
	w_FRAMES[name].FRAME:SetDims("relative:screen")
	w_PANELS[name].FRAME:SetDepth(lf.GetDepthValue(name))
	lf.MoveToDims(name, lf.GetBindings(name)..lf.GetSizeDims(name))
	
	local frame = w_FRAMES[name]
	lf.SaveSetting(c_SaveFrameDims..name, frame.currentDims)
end

function lf.OnMouseResizeStart(args, pin, resize)
	if not g_ShowPanels then return end
	local name = args.widget:GetTag()
	g_ResizeName = name
	g_ResizePin = pin
	g_ResizeResize = resize
	lf.PostToMain("Dragging", "true")
	Component.BeginDragDrop(nil, nil, "InterfaceOptions_ResizeDragDrop")
end

function lf.OnMouseResizeStop()
	if not g_ShowPanels then return end
	local name = g_ResizeName
	g_ResizeName = nil
	g_ResizePin = nil
	g_ResizeResize = nil
	lf.PostToMain("Dragging", "false")
	lf.MoveToDims(name, lf.GetBindings(name)..lf.GetHeightWidth(name))
	
	lf.SaveSetting(c_SaveFrameSize..name, lf.GetHeightWidth(name))
	if g_NotifyOnResize then
		f_CallbackFunction("__RESIZE", nil)
	end
end

function InterfaceOptions_ResizeDragDrop(args)
	if args.done then
		lf.OnMouseResizeStop()
	else
		lf.ResizingLoop()
	end
end

function lf.ResizingLoop()
	local name = g_ResizeName
	local pin = g_ResizePin
	local resize = g_ResizeResize
	local dim_string = ""
	local s_width, s_height = Component.GetScreenSize(true)
	local c_X, c_Y = Component.GetCursorPos()
	local pos = w_PANELS[name].FRAME:GetBounds(false)
	if resize.y and pin.y then
		local dim
		if pin.y == "top" and c_Y - pos[pin.y] >= 50 then
			dim = _math.clamp(c_Y + (c_ResizablePadding/2), 0, s_height)
		elseif pin.y == "bottom" and pos[pin.y] - c_Y >= 50 then
			dim = _math.clamp(c_Y - (c_ResizablePadding/2), 0, s_height)
		end
		if dim then
			dim_string = dim_string..pin.y..":"..pos[pin.y].."; "..resize.y..":"..dim.."; "
		end
	end
	if resize.x and pin.x then
		if w_PANELS[name].aspect ~= 0 then
			dim_string = dim_string..pin.x..":"..pos[pin.x].."; aspect:"..w_PANELS[name].aspect.."; "
		else
			local dim
			if pin.x == "left" and c_X - pos[pin.x] >= 50 then
				dim = _math.clamp(c_X + (c_ResizablePadding/2), 0, s_width)
			elseif pin.x == "right" and pos[pin.x] - c_X >= 50 then
				dim = _math.clamp(c_X - (c_ResizablePadding/2), 0, s_width)
			end
			if dim then
				dim_string = dim_string..pin.x..":"..pos[pin.x].."; "..resize.x..":"..dim.."; "
			end
		end
	end
	if dim_string ~= "" then
		lf.MoveToDims(name, dim_string)
	end
end

function lf.OnScroll(args)
	if not g_ShowPanels then return end
	if not g_Dragging then
		local name = args.widget:GetTag()
		local frame = w_FRAMES[name]
		if frame.scalable then
			local delta = args.amount * 5
			frame.currentScale = math.max(math.min(frame.currentScale - delta, 200), 50)
			lf.ApplyScale(name)
			if g_Highlighted == name then
				lf.ShowFrameTooltip(name)
			end
			frame.savedScale = frame.currentScale
			lf.SaveSetting(c_SaveFrameScale..name, frame.currentScale)
		end
	end
end

-- ------------------------------------------
-- LIASION CALLBACK FUNCTIONS
-- ------------------------------------------
lcb.ShowPanels = function()
	g_ShowPanels = true
	for name, PANEL in pairs(w_PANELS) do
		lf.ShowPanel(name)
	end
end

lcb.HidePanels = function()
	g_ShowPanels = false
	for name, PANEL in pairs(w_PANELS) do
		PANEL.FRAME:Hide(true, 0.25)
		PANEL.FRAME:ParamTo("alpha", 0, 0.25, 0, "ease-out")
		local FRAME = w_FRAMES[name]
		FRAME.FRAME:SetDepth(FRAME.depth)
	end
	if g_Highlighted then
		local name = g_Highlighted
		g_Highlighted = nil
		lf.ModPanel(name)
		lf.HideFrameTooltip(name)
	end
end

lcb.Dragging = function(bool)
	g_Dragging = bool == "true"
end

lcb.LoadingFinished = function()
	g_LoadingFinished = true
	for com, temp in pairs(g_PostToMainQueue) do
		for ID, data in pairs(temp) do
			lf.PostToMain(com, data)
		end
	end
	g_PostToMainQueue = {}
end

lcb.ApplyDefaults = function()
	for name, frame in pairs(w_FRAMES) do
		if frame.scalable then
			frame.currentScale = 100
		end
		lf.ApplyScale(name)
		lf.MoveToDims(name, frame.FRAME:GetInitialDims())
		lf.MoveToDims(name, lf.GetBindings(name)..lf.GetHeightWidth(name))
		lf.SaveSetting(c_SaveFrameScale..name, nil)
		lf.SaveSetting(c_SaveFrameDims..name, nil)
		lf.SaveSetting(c_SaveFrameSize..name, nil)
	end
	if g_NotifyOnDefault and f_CallbackFunction then
		f_CallbackFunction("__DEFAULT", nil)
	end
end

lcb.SetOption = function(tbl)
	tbl = jsontotable(tbl)
	local option
	if tbl.index and d_Options[tbl.index].id == tbl.id then
		option = d_Options[tbl.index]
	else
		option = lf.FindOption(tbl.id)
	end
	
	if option.value ~= tbl.value then
		--only SendToParent if the new value is different from the old one
		--no need to waste time setting an option that is already in place
		option.value = _table.copy(tbl.value)
		lf.SendToParent(option)
		if option.default == tbl.value then --if we are going back to the default value then delete the saved value
			lf.SaveSetting(c_SaveOption.."-"..option.type..":"..option.id, nil)
		else
			lf.SaveSetting(c_SaveOption.."-"..option.type..":"..option.id, option.value)
		end
	end
end

lcb.OptionButtonOnClick = function(tbl)
	tbl = jsontotable(tbl)
	local option
	if tbl.index and d_Options[tbl.index].id == tbl.id then
		option = d_Options[tbl.index]
	else
		option = lf.FindOption(tbl.id)
	end
	lf.SendToParent(option)
end

lcb.OptionsVisible = function(bool)
	bool = bool == "true"
	if g_NotifyOnDisplay and f_CallbackFunction then
		f_CallbackFunction("__DISPLAY", bool)
	end
end

lcb.FosterMultiArt = function(tbl)
	tbl = jsontotable(tbl)
	if tbl.location then
		Component.FosterWidget(w_MultiArt[tbl.foster], tbl.location, "full")
	else
		Component.FosterWidget(w_MultiArt[tbl.foster], nil)
	end
end

Liaison.BindMessageTable(lcb)

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
lf.PostToMain = function(com, data, require_loaded)
	if require_loaded and not g_LoadingFinished then
		if not g_PostToMainQueue[com] then g_PostToMainQueue[com] = {} end
		g_PostToMainQueue[com][data.id] = data
		return
	end
	if type(data) == "table" then
		data = tostring(data)
	end
	Liaison.SendMessage("Options", com, data)
end

lf.SendToParent = function(option)
	local val = option.value
	if option.type == "checkbox" then
		val = (val == true or val == "true")
	end
	if f_CallbackFunction and option.id then
		f_CallbackFunction(option.id, val)
	end
end

lf.ShowPanel = function(name)
	local PANEL = w_PANELS[name]
	if not PANEL.Disabled then
		PANEL.FRAME:Show()
		PANEL.FRAME:ParamTo("alpha", 1, 0.25, 0, "ease-out")
		local FRAME = w_FRAMES[name]
		FRAME.depth = FRAME.FRAME:GetDepth()
		FRAME.FRAME:SetDepth(99999999)
	end
end

lf.MoveToDims = function(name, dims, dur)
	if dur then
		w_FRAMES[name].FRAME:MoveTo(dims, dur)
		w_PANELS[name].FRAME:MoveTo(dims, dur)
	else
		w_FRAMES[name].FRAME:SetDims(dims)
		w_PANELS[name].FRAME:SetDims(dims)
	end
end

lf.ApplyScale = function(name)
	local scale
	if w_FRAMES[name].scalable then
		scale = w_FRAMES[name].currentScale/100
	else
		scale = 1
	end
	--Set the Scale to the Frame
	w_FRAMES[name].FRAME:SetParam("ScaleX", scale)
	w_FRAMES[name].FRAME:SetParam("ScaleY", scale)
	--Resize the Panel so that it is the same size as the scaled frame. Makes a few things better/easier.
	w_PANELS[name].FRAME:SetDims(lf.CreateDims(name).."height:"..(w_FRAMES[name].height*scale).."; width:"..(w_FRAMES[name].width*scale))
	w_PANELS[name].FRAME:SetDepth(lf.GetDepthValue(name))
end

lf.ModPanel = function(name)
	local panel = w_PANELS[name]
	local style
	panel.NAME:SetText(panel.label)
	if g_Highlighted == name then
		style = "highlighted"
	else
		style = "enabled"
	end
	for k, v in pairs(c_ArtStyles[style]) do
		panel.BORDER:SetParam(k, v)
	end
end

lf.SaveSetting = function(id, val)
	if g_SaveSettings then
		Component.SaveSetting(id, val)
	end
end

lf.LoadFrameDims = function(name)
	local frame = w_FRAMES[name]
	local saved_dims = Component.GetSetting(c_SaveFrameDims..name)
	local saved_size
	if frame.resizable then
		saved_size = Component.GetSetting(c_SaveFrameSize..name)
	end
	local resize = false
	local dims
	local size
	if saved_dims and not g_UseDefaultSettings then
		frame.currentDims = saved_dims
		dims = lf.CreateDims(name)
	else
		dims = lf.GetBindings(name)
	end
	if saved_size and not g_UseDefaultSettings then
		resize = true
		size = saved_size
	else
		size = lf.GetHeightWidth(name)
	end
	lf.MoveToDims(name, dims..size)
	if resize then
		f_CallbackFunction("__RESIZE", nil)
	end
	if frame.scalable then
		local saved_scalable = Component.GetSetting(c_SaveFrameScale..name)
		if saved_scalable and not g_UseDefaultSettings then
			frame.savedScale = saved_scalable
			frame.currentScale = saved_scalable
			lf.ApplyScale(name)
		else
			frame.savedScale = 100
			frame.currentScale = 100
		end
	end
	if g_UseDefaultSettings then
		lf.SaveSetting(c_SaveFrameScale..name, nil)
		lf.SaveSetting(c_SaveFrameDims..name, nil)
		lf.SaveSetting(c_SaveFrameSize..name, nil)
	end
end

-- ------------------------------------------
-- UTILITY/RETURN FUNCTIONS
-- ------------------------------------------
lf.CreateMovablePanel = function(name, resizable)
	local PANEL = {}
	PANEL.FRAME = Component.CreateFrame("PanelFrame")
	PANEL.FRAME:Hide()
	PANEL.FRAME:BindEvent("OnEscape", function() lf.PostToMain("OnEscape", nil) end)
	PANEL.BORDER = Component.CreateWidget([=[<Border dimensions="left:-5; right:100%+5; top:-5; bottom:100%+5;" class="ElectricHUD" style="texture:PanelParts; eatsmice:false; padding:10;
			region-topleft:FrameOutline_TL;
			region-top:FrameOutline_T;
			region-topright:FrameOutline_TR;
			region-left:FrameOutline_L;
			region-center:Transparent;
			region-right:FrameOutline_R;
			region-bottomleft:FrameOutline_BL;
			region-bottom:FrameOutline_B;
			region-bottomright:FrameOutline_BR;"/>]=], PANEL.FRAME)
	PANEL.NAME = Component.CreateWidget([=[<Text dimensions="left:-5; right:100%+5; top:-5; bottom:100%+5;" style="font:UbuntuMediumItalic_9; halign:center; valign:center; clip:true; wrap:true"/>]=], PANEL.FRAME)
	local FOCUSBOX = Component.CreateWidget([=[<FocusBox dimensions="dock:fill" style="cursor:sys_sizeall"/>]=], PANEL.FRAME)
	FOCUSBOX:SetTag(name)
	FOCUSBOX:BindEvent("OnMouseEnter", lf.OnMouseEnter)
	FOCUSBOX:BindEvent("OnMouseLeave", lf.OnMouseLeave)
	FOCUSBOX:BindEvent("OnMouseDown", lf.OnMouseDown)
	FOCUSBOX:BindEvent("OnMouseUp", lf.OnMouseUp)
	FOCUSBOX:BindEvent("OnScroll", lf.OnScroll)
	
	local function ConfigFocusBox(FOCUSBOX, name, pin, resize)
		FOCUSBOX:SetTag(name)
		FOCUSBOX:BindEvent("OnMouseDown", function(args)
			lf.OnMouseResizeStart(args, pin, resize) 
		end)
		FOCUSBOX:BindEvent("OnMouseEnter", lf.OnMouseEnter)
		FOCUSBOX:BindEvent("OnMouseLeave", lf.OnMouseLeave)
	end
	if resizable then
		PANEL.aspect = lf.GetAspectValue(name)
		--top left
		FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='top:0; height:"..c_ResizablePadding.."; left:0; width:"..c_ResizablePadding..";' style='cursor:sys_sizenwse'/>", PANEL.FRAME)
		ConfigFocusBox(FOCUSBOX, name, {y="bottom",x="right"}, {y="top",x="left"})
		--top right
		FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='top:0; height:"..c_ResizablePadding.."; right:100%; width:"..c_ResizablePadding..";' style='cursor:sys_sizenesw'/>", PANEL.FRAME)
		ConfigFocusBox(FOCUSBOX, name, {y="bottom",x="left"}, {y="top",x="right"})
		--bottom left
		FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='bottom:100%; height:"..c_ResizablePadding.."; left:0; width:"..c_ResizablePadding..";' style='cursor:sys_sizenesw'/>", PANEL.FRAME)
		ConfigFocusBox(FOCUSBOX, name, {y="top",x="right"}, {y="bottom",x="left"})
		--bottom right
		FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='bottom:100%; height:"..c_ResizablePadding.."; right:100%; width:"..c_ResizablePadding..";' style='cursor:sys_sizenwse'/>", PANEL.FRAME)
		ConfigFocusBox(FOCUSBOX, name, {y="top",x="left"}, {y="bottom",x="right"})
		if PANEL.aspect == 0 then
			--top
			FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='top:0; height:"..c_ResizablePadding.."; left:"..c_ResizablePadding.."; right:100%-"..c_ResizablePadding..";' style='cursor:sys_sizens'/>", PANEL.FRAME)
			ConfigFocusBox(FOCUSBOX, name, {y="bottom"}, {y="top"})
			--bottom
			FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='bottom:100%; height:"..c_ResizablePadding.."; left:"..c_ResizablePadding.."; right:100%-"..c_ResizablePadding..";' style='cursor:sys_sizens'/>", PANEL.FRAME)
			ConfigFocusBox(FOCUSBOX, name, {y="top"}, {y="bottom"})
			--left
			FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='left:0; width:"..c_ResizablePadding.."; top:"..c_ResizablePadding.."; bottom:100%-"..c_ResizablePadding..";' style='cursor:sys_sizewe'/>", PANEL.FRAME)
			ConfigFocusBox(FOCUSBOX, name, {x="right"}, {x="left"})
			--right
			FOCUSBOX = Component.CreateWidget("<FocusBox dimensions='right:100%; width:"..c_ResizablePadding.."; top:"..c_ResizablePadding.."; bottom:100%-"..c_ResizablePadding..";' style='cursor:sys_sizewe'/>", PANEL.FRAME)
			ConfigFocusBox(FOCUSBOX, name, {x="left"}, {x="right"})
		end
	end
	return PANEL
end

lf.GetBindings = function(name)
	local bounds = w_FRAMES[name].FRAME:GetBounds(false)
	w_FRAMES[name].height = bounds.height
	w_FRAMES[name].width = bounds.width
	w_FRAMES[name].aspect = lf.GetAspectValue(name)
	local panel = w_PANELS[name]
	local s_width, s_height = Component.GetScreenSize(true)
	local pos = panel.FRAME:GetBounds(true)
	pos.centerX = (pos.width/2) + pos.left
	pos.centerY = (pos.height/2) + pos.top
	local Xbound, Xpct, Ybound, Ypct
	--Find the X binding
	if s_width*(1/3) >= pos.centerX then
		--center of the frame is in the left third
		Xbound = "left"
		if pos.left < 0 then 
			Xpct = 0 
		else
			Xpct = (pos.left / s_width)*100
		end
	elseif s_width*(2/3) <= pos.centerX then
		--center of the frame is in the right third
		Xbound = "right"
		if pos.right > s_width then 
			Xpct = 100 
		else
			Xpct = (pos.right / s_width)*100
		end
	else
		--center of the frame is in the middle third
		Xbound = "center-x"
		Xpct = (pos.centerX / s_width)*100
	end
	--Find the Y binding
	if s_height*(1/3) >= pos.centerY then
		--center of the frame is in the top third
		Ybound = "top"
		if pos.top < 0 then 
			Ypct = 0 
		else
			Ypct = (pos.top / s_height)*100
		end
	elseif s_height*(2/3) <= pos.centerY then
		--center of the frame is in the bottom third
		Ybound = "bottom"
		if pos.bottom > s_height then 
			Ypct = 100 
		else
			Ypct = (pos.bottom / s_height)*100
		end
	else
		--center of the frame is in the middle third
		Ybound = "center-y"
		Ypct = (pos.centerY / s_height)*100
	end
	w_FRAMES[name].currentDims = {Xbound=Xbound, Xpct=Xpct, Ybound=Ybound, Ypct=Ypct}
	return lf.CreateDims(name)
end

lf.CreateDims = function(name)
	local d = w_FRAMES[name].currentDims
	if d and d.Xbound and d.Xpct and d.Ybound and d.Ypct then
		return d.Xbound..":"..d.Xpct.."%; "..d.Ybound..":"..d.Ypct.."%; "
	else
		return lf.GetBindings(name)
	end
end

lf.FindOption = function(id)
	for i, option in ipairs(d_Options) do
		if option.id == id then
			return option
		end
	end
	return false
end

lf.GetFrameName = function(frame)
	local name, FRAME
	if type(frame) == "string" then
		name = frame
		FRAME = Component.GetFrame(frame)
	else
		name = frame:GetInfo()
		FRAME = frame
	end
	return name, FRAME
end

lf.GetDepthValue = function(name)
	local bounds = w_PANELS[name].FRAME:GetBounds()
	return bounds.height * bounds.width
end

lf.GetBaseOption = function(option)
	if not option.label_key and not option.label then
		option.label = "ERR:Missing label"
	end
	return option
end

lf.GetSizeDims = function(name)
	local frame = w_FRAMES[name]
	if not w_FRAMES[name].aspect then
		w_FRAMES[name].aspect = lf.GetAspectValue(name)
	end
	if w_FRAMES[name].aspect ~= 0 then
		return "height:_; aspect:_; "
	else
		return "height:_; width:_; "
	end
end

lf.GetHeightWidth = function(name)
	-- Used to initially switch frames with funky percent dims to pixel values as scaling flips out otherwise.
	local d = w_FRAMES[name].FRAME:GetDims()
	local s_width, s_height = Component.GetScreenSize(true)
	local height, width
	if d.aspect ~= 0 then
		if d.axis == "yaxis" then
			height = (((d.bottom.orth_percent-d.top.orth_percent)/100)*s_width) + (((d.bottom.percent-d.top.percent)/100)*s_height) + (d.bottom.offset-d.top.offset)
			return "height:"..height.."; width:"..height*d.aspect.."; "
		elseif d.axis == "xaxis" then
			width = (((d.right.orth_percent-d.left.orth_percent)/100)*s_height) + (((d.right.percent-d.left.percent)/100)*s_width) + (d.right.offset-d.left.offset)
			return "width:"..width.."; height:"..width/d.aspect.."; "
		end
	else
		height = (((d.bottom.orth_percent-d.top.orth_percent)/100)*s_width) + (((d.bottom.percent-d.top.percent)/100)*s_height) + (d.bottom.offset-d.top.offset)
		width = (((d.right.orth_percent-d.left.orth_percent)/100)*s_height) + (((d.right.percent-d.left.percent)/100)*s_width) + (d.right.offset-d.left.offset)
		return "height:"..height.."; width:"..width.."; "
	end
end

lf.GetAspectValue = function(name)
	local dims = w_FRAMES[name].FRAME:GetDims()
	return dims.aspect
end

lf.ShowFrameTooltip = function(name)
	local data = {
		show		= true,
		title		= w_PANELS[name].label,
		scale		= w_FRAMES[name].currentScale,
		resizable	= w_FRAMES[name].resizable,
	}
	lf.PostToMain("Tooltip", data)
end

lf.HideFrameTooltip = function(name)
	local data = {show=false, title=w_PANELS[name].label}
	lf.PostToMain("Tooltip", data)
end
