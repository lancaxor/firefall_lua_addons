-----------------------------------------------------
-- Options framework by CookieDuster
-----------------------------------------------------
-- Guess it's time to name this already, but whatever
-- It's not just options either, but who cares
-----------------------------------------------------

----------------------------------------------------- expand on this
-- Public functions
--  - UpdateVisibility
--  - Init
--  - GetData
--  - SetData
--  - GetSetting
--  - SetSetting
--  - GetText
--  - SetText
--  - SetParam
-- Options menu elements
--  - AddCheckBox
--  - AddDropDown
--  - AddSlider
--  - AddColorPicker
--  - AddTextInput
--  - AddElement
--  - GenerateOptionsLookupTable (global)
-- Setting handlers
--  - ProcessEnabled
--  - ProcessCheckBox
--  - ProcessNumeric
--  - ProcessPrefix
--  - ProcessSuffix
--  - ProcessVerticalAlignment
--  - ProcessHorizontalAlignment
--  - ProcessFont
--  - ProcessColor
-- Internal functions
--  - HandleCallback
--  - SetupOptionValues
--  - GetUniqueName
-- Tables
--  - HALIGNMENTS
--  - VALIGNMENTS
--  - FONTS
--  - SOUNDS
-- Globals for convenience
--  - TableToList
--  - TableIndexToList
--  - TableToCommaDelimitedList
--  - TableIndexToCommaDelimitedList
--  - Inc
--  - Dec
----------------------------------------------------- 

require "lib/lib_InterfaceOptions"

UiElement = {}
UiElement.__index = UiElement

setmetatable( UiElement, { __call = function( cls, ... ) return cls.new( ... ) end, } ) -- wth is this

--------------
-- Constructor
--------------

function UiElement:new(args)
	local self = {}
	if (args.label == nil) then
		warn("No label specified")
		return nil
	end
	if (args.scalable == nil) then args.scalable = true end
	if  (args.frame ~= nil) then
		self.frame = Component.GetFrame(args.frame)
		InterfaceOptions.AddMovableFrame({frame = self.frame, label = args.label, scalable = args.scalable})
		--self.frame = Component.GetFrame(args.frame)
	end
	local self = setmetatable({}, UiElement)
	self.label = args.label
	self.id = args.id
	self.settings = {}
	self.elements = {}
	self.data = {}
	--local tmp = Component.GetSetting("persistent_settings") ---- to do: persistent flag to data structure
	
	return self
end


---------------------------
-- Generic public functions
---------------------------

function UiElement:Init()
	--needs to be defined in instances
end

function UiElement:UpdateVisibility(element, args) -- element, {arg1, arg2, arg3...}
	for index, item in pairs(args) do
		if(item == false) then
			self.elements[element]:Hide()
			return
		end
	end
	self.elements[element]:Show()
end

function UiElement:GetAttachedElement(arg) -- id
	return self.settings[arg].element
end

function UiElement:SetAttachedElement(args) -- {id, value}
	self.settings[self:GetUniqueName(args.id)].element = args.value
	return args.value
end

function UiElement:GetSetting(arg) -- id
	if (self.settings[self:GetUniqueName(arg)] == nil) then
		warn("GetSetting: \""..arg.."\" has no value!")
		return nil
	end
	return self.settings[self:GetUniqueName(arg)].value
end

function UiElement:SetSetting(args) -- {id, value} -- this is pointless
	self.settings[self:GetUniqueName(args.id)].value = args.value
	return args.value
end

function UiElement:GetData(id, value, value2) -- id
	if (value2 ~= nil) then
		return self.data[id][value][value2]
	elseif (value ~= nil) then
		return self.data[id][value]
	else
		return self.data[id]
	end
end

function UiElement:SetData(element, value, value2, value3)
	if (value3 ~= nil) then
		if(self.data[element][value] == nil) then self.data[element][value] = {} end
		self.data[element][value][value2] = value3
		--if(self.data[element].persistent == true) then Component.SaveSetting("")  -- to do: persistent flag
		return value3
	elseif (value2 ~= nil) then
		if(self.data[element] == nil) then self.data[element] = {} end
		self.data[element][value] = value2
		return value2
	elseif (value ~= nil) then
		self.data[element] = value
		return value
	end
end

function UiElement:DeleteData(element, value) -- id, value
	if (value == nil) then
		self.data[element] = nil
	else
		self.data[element][value] = nil
	end
	return nil
end

function UiElement:GetText(arg) -- id
	return self.elements[arg]:GetText()
end

function UiElement:SetText(element, value) -- id, value
	self.elements[element]:SetText(value)
	return value
end

function UiElement:SetParam(args) -- {id, param, value}
	self.elements[args.element]:SetParam(args.param, args.value)
	return args.value
end


------------------------
-- Options menu elements
------------------------

function UiElement:StartGroup(args) -- {id, label} -- just for show
    InterfaceOptions.StartGroup({id = args.id, label = args.label})
end

function UiElement:StopGroup() -- same here
    InterfaceOptions.StopGroup()
end

function UiElement:AddCheckBox(args) --{id, label, default, callback, element, subtab} -- nothing special except attaching the element
	args.id = self:GetUniqueName(args.id)
	InterfaceOptions.AddCheckBox({id = args.id, label = args.label, default = args.default, subtab = args.subtab})
	self:SetupOptionValues({id = args.id, default = args.default, callback = args.callback, element = args.element})
end

function UiElement:AddDropDown(args) -- {id, label, options, default, callback, element, subtab} -- automatic list generation, woo!
	args.id = self:GetUniqueName(args.id)
	if (#args.options == 0) then
		logw(args.id.." has no options!")
		return nil
	else
		if (args.default == nil) then args.default = false end
		InterfaceOptions.AddChoiceMenu({id = args.id, label = args.label, default = args.default, subtab = args.subtab})
		for _,v in ipairs(args.options) do
			InterfaceOptions.AddChoiceEntry({menuId = args.id, val = v.value, label = v.label, subtab = args.subtab} )
		end
		self:SetupOptionValues({id = args.id, default = args.default, callback = args.callback, element = args.element})
	end
end

function UiElement:AddColorPicker(args) --{id, label, default, callback, subtab, element} -- nothing special except attaching the element
	args.id = self:GetUniqueName(args.id)
    if (args.default == nil) then args.default = {alpha = 0.8, tint = "FFFFFF", exposure = 0} end
    InterfaceOptions.AddColorPicker({id = args.id, label = args.label, default = args.default, subtab = args.subtab})
	self:SetupOptionValues({id = args.id, default = args.default, callback = args.callback, element = args.element})
end

function UiElement:AddTextInput(args) -- {id, label, max, default, callback, element, numeric=false, masked=false, whitespace=true, subtab} -- nothing special except attaching the element
	args.id = self:GetUniqueName(args.id)
	if (args.default == nil) then args.default = "" end
	if (args.numeric == nil) then args.numeric = false end
	if (args.masked == nil) then args.masked = false end
	if (args.whitespace == nil) then args.whitespace = true end
	InterfaceOptions.AddTextInput({id = args.id, label = args.label, max = args.max, default = args.default, numeric = args.numeric, masked = args.masked, whitespace = args.whitespace, subtab = args.subtab})
	self:SetupOptionValues({id = args.id, default = args.default, callback = args.callback, element = args.element})
end

function UiElement:AddSlider(args) -- {id, label, max, min, increment, suffix, default=min, multi, subtab} -- nothing special except attaching the element
	args.id = self:GetUniqueName(args.id)
	if(args.default == nil) then args.default = args.min end
	if(args.suffix == nil) then args.suffix = "" end
	if(args.increment == nil) then args.increment = 1 end
	if(args.max == nil) then args.max = 100 end
	if(args.min == nil) then args.min = 1 end
	InterfaceOptions.AddSlider({id = args.id, label = args.label, default = args.default, min = args.min, max = args.max, inc = args.increment, suffix = args.suffix, multi = args.multi, subtab = args.subtab})
	self:SetupOptionValues({id = args.id, default = args.default, callback = args.callback, element = args.element})
end

function UiElement:AddElement(args) -- {id, xmlid} set up an element for use
	self.elements[args.id] = Component.GetWidget(args.xmlid)
end


function GenerateOptionsLookupTable(container) -- global to generate option lookup table for callbacks
	local lookuptable = {}
	for componentname, componentvalue in pairs(container) do
		for optionname, optionvalue in pairs(container[componentname].settings) do
			if (lookuptable[optionname] ~= nil) then -- every option has to be unique because there's no way to pass component name in the callback from options -- DEPRECATED by workaround, fix this
				logw("Duplicate option: "..optionname.."; previous value: "..lookuptable[optionname].."; new value: "..componentname)
			end
			lookuptable[optionname] = componentname
		end
	end
	return lookuptable
end


---------------------------
-- Generic setting handlers
---------------------------

function UiElement:ProcessCheckbox(poption, pvalue)
	-- already implemented in the handler
end

function UiElement:ProcessFont(poption, pvalue) -- for updating visuals
	local element = self.settings[poption].element
	local tmp = self.elements[element]:GetText()
	self.elements[element]:SetFont(pvalue)
	self.elements[element]:SetText(tmp)
end

function UiElement:ProcessColor(poption, pvalue) -- for updating visuals
	local element = self.settings[poption].element
	self.elements[element]:SetTextColor(self.settings[poption].value.tint)
	self.elements[element]:SetParam("exposure", self.settings[poption].value.exposure)
	self.elements[element]:SetParam("alpha", self.settings[poption].value.alpha)
end

function UiElement:ProcessSuffix(poption, pvalue) -- for updating visuals
	if(self:GetData("ready") == true) then self:Init() end -- should not rely on user defined variable
end

function UiElement:ProcessPrefix(poption, pvalue) -- for updating visuals
	if(self:GetData("ready") == true) then self:Init() end -- should not rely on user defined variable
end

--[[ -- glow is not supported
function UiElement:ProcessGlowEnable(poption, pvalue)
	local element = self:GetAttachedElement(poption)
	--self.settings[poption].value = (pvalue == true)
	if (self.settings[poption].value == true) then
		self.elements[element]:SetParam("glow", string.format("%02x", math.floor(self.settings[poption].value.alpha*255)) .. self.settings[poption].value.tint)
	else
		self.elements[element]:SetParam("glow", 0)
	end
end

function UiElement:ProcessGlowColor(poption, pvalue)
	local element = self:GetAttachedElement(poption)
	--self.settings[pelement].glowcolor = pvalue
	if (self.settings[poption].value == true) then
		self.elements[pelement]:SetParam("glow", string.format("%02x", math.floor(self.settings[pelement].glowcolor.alpha*255)) .. self.settings[pelement].glowcolor.tint)
	else
		self.elements[pelement]:SetParam("glow", 0)
	end
end
--]]

function UiElement:ProcessHorizontalAlignment(poption, pvalue) -- for updating visuals
	local element = self:GetAttachedElement(poption)
	local tmp = self.elements[element]:GetText()
	self.elements[element]:SetAlignment("halign", pvalue)
	self.elements[element]:SetText(tmp)
end

function UiElement:ProcessVerticalAlignment(poption, pvalue) -- for updating visuals
	local element = self:GetAttachedElement(poption)
	local tmp = self.elements[element]:GetText()
	self.elements[element]:SetAlignment("valign", pvalue)
	self.elements[element]:SetText(tmp)
end

function UiElement:ProcessFrameEnabled(poption, pvalue) -- for hiding the whole attached frame
	if self.frame then
		self.frame:Show(pvalue)
	end
	for index, item in pairs(self.elements) do
		self.elements[index]:Show(pvalue) -- quick'n'dirty hide
	end
end

function UiElement:ProcessNumeric(poption, pvalue) -- typecasting to store as number from text input
	self.settings[poption].value = tonumber(pvalue)
end

function UiElement:ProcessSound(poption, pvalue)
	if(self:GetData("ready") == true) then System.PlaySound(pvalue) end
end

---------------------
-- Internal functions
---------------------

function UiElement:GetUniqueName(arg) -- id -- get uniques option name
	return self.id.."_"..arg
end

function UiElement:HandleCallback(args) -- {id, value} -- process setting value and apply setting handler if specified
	self.settings[args.id].value = args.value
	local funcname = self.settings[args.id].callback
	if (funcname ~= nil) then
		self[funcname](self, args.id, args.value)
	end
end

function UiElement:SetupOptionValues(args) -- {id, element, funcame, value} -- set up basic setting containers for options menu element
	self.settings[args.id] = {}
	self.settings[args.id].callback = args.callback
	self.settings[args.id].element = args.element
	self.settings[args.id].value = args.value
end


----------------------------
-- Tables for dropdown lists
----------------------------

FONTS = { 
	{label = "Narrow 7", value = "Narrow_7"},
	{label = "Narrow 8", value = "Narrow_8"},
	{label = "Narrow 10", value = "Narrow_10"},
	{label = "Narrow 11", value = "Narrow_11"},
	{label = "Narrow 13", value = "Narrow_13"},
	{label = "Narrow 15", value = "Narrow_15"},
	{label = "Narrow 17", value = "Narrow_17"},
	{label = "Narrow 18", value = "Narrow_18"},
	{label = "Narrow 20", value = "Narrow_20"},
	{label = "Narrow 7B", value = "Narrow_7B"},
	{label = "Narrow 10B", value = "Narrow_10B"},
	{label = "Narrow 11B", value = "Narrow_11B"},
	{label = "Narrow 13B", value = "Narrow_13B"},
	{label = "Narrow 15B", value = "Narrow_15B"},
	{label = "Narrow 17B", value = "Narrow_17B"},
	{label = "Narrow 18B", value = "Narrow_18B"},
	{label = "Narrow 20B", value = "Narrow_20B"},
	{label = "Narrow 26B", value = "Narrow_26B"},
	{label = "Narrow 32B", value = "Narrow_32B"},
	{label = "Narrow 34B", value = "Narrow_34B"},
	{label = "Narrow 50B", value = "Narrow_50B"},
	{label = "Wide 7", value = "Wide_7"},
	{label = "Wide 8", value = "Wide_8"},
	{label = "Wide 10", value = "Wide_10"},
	{label = "Wide 11", value = "Wide_11"},
	{label = "Wide 13", value = "Wide_13"},
	{label = "Wide 15", value = "Wide_15"},
	{label = "Wide 17", value = "Wide_17"},
	{label = "Wide 18", value = "Wide_18"},
	{label = "Wide 20", value = "Wide_20"},
	{label = "Wide 24", value = "Wide_24"},
	{label = "Wide 7B", value = "Wide_7B"},
	{label = "Wide 8B", value = "Wide_8B"},
	{label = "Wide 10B", value = "Wide_10B"},
	{label = "Wide 11B", value = "Wide_11B"},
	{label = "Wide 13B", value = "Wide_13B"},
	{label = "Wide 15B", value = "Wide_15B"},
	{label = "Wide 17B", value = "Wide_17B"},
	{label = "Wide 18B", value = "Wide_18B"},
	{label = "Wide 20B", value = "Wide_20B"},
	{label = "Wide 25B", value = "Wide_25B"},
	{label = "Wide 34B", value = "Wide_34B"},
	{label = "Demi 7", value = "Demi_7"},
	{label = "Demi 8", value = "Demi_8"},
	{label = "Demi 9", value = "Demi_9"},
	{label = "Demi 10", value = "Demi_10"},
	{label = "Demi 11", value = "Demi_11"},
	{label = "Demi 12", value = "Demi_12"},
	{label = "Demi 13", value = "Demi_13"},
	{label = "Demi 15", value = "Demi_15"},
	{label = "Demi 17", value = "Demi_17"},
	{label = "Demi 18", value = "Demi_18"},
	{label = "Demi 20", value = "Demi_20"},
	{label = "Demi 23", value = "Demi_23"},
	{label = "Demi 25", value = "Demi_25"},
	{label = "Demi 30", value = "Demi_30"},
	{label = "Demi 33", value = "Demi_33"},
	{label = "Demi 35", value = "Demi_35"},
	{label = "Demi 40", value = "Demi_40"},
	{label = "Bold 7", value = "Bold_7"},
	{label = "Bold 8", value = "Bold_8"},
	{label = "Bold 9", value = "Bold_9"},
	{label = "Bold 10", value = "Bold_10"},
	{label = "Bold 11", value = "Bold_11"},
	{label = "Bold 13", value = "Bold_13"},
	{label = "Bold 15", value = "Bold_15"},
	{label = "Bold 17", value = "Bold_17"},
	{label = "Bold 19", value = "Bold_19"},
	{label = "Bold 26", value = "Bold_26"},
	{label = "Ubuntu Regular 7", value = "UbuntuRegular_7"},
	{label = "Ubuntu Regular 8", value = "UbuntuRegular_8"},
	{label = "Ubuntu Regular 9", value = "UbuntuRegular_9"},
	{label = "Ubuntu Regular 10", value = "UbuntuRegular_10"},
	{label = "Ubuntu Regular 11", value = "UbuntuRegular_11"},
	{label = "Ubuntu Regular 13", value = "UbuntuRegular_13"},
	{label = "Ubuntu Medium Italic 9", value = "UbuntuMediumItalic_9"},
	{label = "Ubuntu Medium Italic 11", value = "UbuntuMediumItalic_11"},
	{label = "Ubuntu Medium Italic 14", value = "UbuntuMediumItalic_14"},
	{label = "Ubuntu Medium 7", value = "UbuntuMedium_7"},
	{label = "Ubuntu Medium 8", value = "UbuntuMedium_8"},
	{label = "Ubuntu Medium 8", value = "UbuntuMedium_8"},
	{label = "Ubuntu Medium 9", value = "UbuntuMedium_9"},
	{label = "Ubuntu Medium 10", value = "UbuntuMedium_10"},
	{label = "Ubuntu Medium 11", value = "UbuntuMedium_11"},
	{label = "Ubuntu Medium 12", value = "UbuntuMedium_12"},
	{label = "Ubuntu Medium 14", value = "UbuntuMedium_14"},
	{label = "Ubuntu Medium 18", value = "UbuntuMedium_18"},
	{label = "Ubuntu Medium 50", value = "UbuntuMedium_50"},
	{label = "Ubuntu Bold 7", value = "UbuntuBold_7"},
	{label = "Ubuntu Bold 8", value = "UbuntuBold_8"},
	{label = "Ubuntu Bold 9", value = "UbuntuBold_9"},
	{label = "Ubuntu Bold 10", value = "UbuntuBold_10"},
	{label = "Ubuntu Bold 11", value = "UbuntuBold_11"},
	{label = "Ubuntu Bold 13", value = "UbuntuBold_13"},
	{label = "Ubuntu Bold 23", value = "UbuntuBold_23"},
	{label = "Ubuntu Bold 24", value = "UbuntuBold_24"},
	{label = "Ubuntu Bold 26", value = "UbuntuBold_26"},
}

VALIGNMENTS = {
	{label = "Top", value = "top"},
	{label = "Middle", value = "middle"},
	{label = "Bottom", value = "bottom"},
}

HALIGNMENTS = {
	{label = "Left", value = "left"},
	{label = "Middle", value = "middle"},
	{label = "Right", value = "right"},
}

--[[ --- alternate data structure
VALIGNMENTS2 = {
	top = {label = "Top", id = "top"},
	middle = {label = "Middle", id = "middle"},
	bottom = {label = "Bottom", id = "bottom"},
}

HALIGNMENTS2 = {
	left = {label = "Left", id = "left"},
	middle = {label = "Middle", id = "middle"},
	right = {label = "Right", id = "right"},
}--]]

SOUNDS = {
	{label = "Play_UI_Ability_Selection", value = "Play_UI_Ability_Selection"},
	{label = "Play_SFX_UI_SIN_CooldownFail", value = "Play_SFX_UI_SIN_CooldownFail"},
	{label = "Play_ui_abilities_cooldown_complete", value = "Play_ui_abilities_cooldown_complete"},
	{label = "Play_PAX_FirefallSplash_Victory", value = "Play_PAX_FirefallSplash_Victory"},
	{label = "Play_PAX_FirefallSplash_Defeat", value = "Play_PAX_FirefallSplash_Defeat"},
	{label = "Play_Vox_Emote_Groan", value = "Play_Vox_Emote_Groan"},
	{label = "Play_PAX_FirefallSplash_Unlock", value = "Play_PAX_FirefallSplash_Unlock"},
	{label = "Play_UI_Ticker_stStageIntro", value = "Play_UI_Ticker_stStageIntro"},
	{label = "Play_UI_Ticker_ndStageIntro", value = "Play_UI_Ticker_ndStageIntro"},
	{label = "Play_UI_Ticker_LoudSecondTick", value = "Play_UI_Ticker_LoudSecondTick"},
	{label = "Play_UI_Ticker_ZeroTick", value = "Play_UI_Ticker_ZeroTick"},
	{label = "Play_UI_SlideNotification", value = "Play_UI_SlideNotification"},
	{label = "Play_UI_Login_Back", value = "Play_UI_Login_Back"},
	{label = "Play_Click", value = "Play_Click"},
	{label = "Play_UI_Login_Confirm", value = "Play_UI_Login_Confirm"},
	{label = "Play_UI_Login_Keystroke", value = "Play_UI_Login_Keystroke"},
	{label = "Play_Vox_VoiceSetSelect", value = "Play_Vox_VoiceSetSelect"},
	{label = "Play_UI_CharacterCreate_Confirm", value = "Play_UI_CharacterCreate_Confirm"},
	{label = "Play_UI_Login_Click", value = "Play_UI_Login_Click"},
	{label = "Play_UI_Intermission", value = "Play_UI_Intermission"},
	{label = "Play_SFX_UI_Ding", value = "Play_SFX_UI_Ding"},
	{label = "Play_SFX_UI_AchievementEarned", value = "Play_SFX_UI_AchievementEarned"},
	{label = "Play_PvP_Confirmation", value = "Play_PvP_Confirmation"},
	{label = "Play_UI_SINView_Mode", value = "Play_UI_SINView_Mode"},
	{label = "Stop_UI_SINView_Mode", value = "Stop_UI_SINView_Mode"},
	{label = "Stop_SFX_UI_E_Initiate_Loop_Fail", value = "Stop_SFX_UI_E_Initiate_Loop_Fail"},
	{label = "Play_UI_SIN_ExtraInfo_On", value = "Play_UI_SIN_ExtraInfo_On"},
	{label = "Play_SFX_UI_Loot_Flyover", value = "Play_SFX_UI_Loot_Flyover"},
	{label = "Play_SFX_UI_Loot_Abilities", value = "Play_SFX_UI_Loot_Abilities"},
	{label = "Play_SFX_UI_Loot_Crystite", value = "Play_SFX_UI_Loot_Crystite"},
	{label = "Play_SFX_UI_Loot_Basic", value = "Play_SFX_UI_Loot_Basic"},
	{label = "Play_SFX_UI_Loot_Backpack_Pickup", value = "Play_SFX_UI_Loot_Backpack_Pickup"},
	{label = "Play_SFX_UI_Loot_Battleframe_Pickup", value = "Play_SFX_UI_Loot_Battleframe_Pickup"},
	{label = "Play_SFX_UI_Loot_PowerUp", value = "Play_SFX_UI_Loot_PowerUp"},
	{label = "Play_SFX_UI_Loot_Weapon_Pickup", value = "Play_SFX_UI_Loot_Weapon_Pickup"},
	{label = "Play_UI_NavWheel_Open", value = "Play_UI_NavWheel_Open"},
	{label = "Play_UI_NavWheel_Close", value = "Play_UI_NavWheel_Close"},
	{label = "Play_UI_NavWheel_MouseLeftButton", value = "Play_UI_NavWheel_MouseLeftButton"},
	{label = "Play_UI_NavWheel_MouseLeftButton_Initiate", value = "Play_UI_NavWheel_MouseLeftButton_Initiate"},
	{label = "Play_UI_NavWheel_MouseRightButton", value = "Play_UI_NavWheel_MouseRightButton"},
	{label = "Play_UI_HUDNotes_Unpin", value = "Play_UI_HUDNotes_Unpin"},
	{label = "Play_UI_HUDNotes_Pin", value = "Play_UI_HUDNotes_Pin"},
	{label = "Play_UI_SIN_Acquired", value = "Play_UI_SIN_Acquired"},
	{label = "Play_SFX_UI_TipPopUp", value = "Play_SFX_UI_TipPopUp"},
	{label = "Play_Vox_UI_Frame", value = "Play_Vox_UI_Frame"},
	{label = "Play_SFX_UI_GeneralAnnouncement", value = "Play_SFX_UI_GeneralAnnouncement"},
	{label = "Play_SFX_UI_End", value = "Play_SFX_UI_End"},
	{label = "Play_SFX_UI_Ticker", value = "Play_SFX_UI_Ticker"},
	{label = "Play_SFX_UI_FriendOnline", value = "Play_SFX_UI_FriendOnline"},
	{label = "Play_SFX_UI_FriendOffline", value = "Play_SFX_UI_FriendOffline"},
	{label = "Play_UI_Beep_", value = "Play_UI_Beep_"},
	{label = "Stop_SFX_NewYou_IntoAndLoop", value = "Stop_SFX_NewYou_IntoAndLoop"},
	{label = "Play_SFX_UI_WhisperTickle", value = "Play_SFX_UI_WhisperTickle"},
	{label = "Play_SFX_UI_AbilitySelect_v", value = "Play_SFX_UI_AbilitySelect_v"},
	{label = "Play_SFX_WebUI_Equip_Weapon", value = "Play_SFX_WebUI_Equip_Weapon"},
	{label = "Play_SFX_NewYou_BodySelectionHulaPopUp", value = "Play_SFX_NewYou_BodySelectionHulaPopUp"},
	{label = "Play_SFX_NewYou_IntoAndLoop", value = "Play_SFX_NewYou_IntoAndLoop"},
	{label = "Play_SFX_NewYou_GearRackScroll", value = "Play_SFX_NewYou_GearRackScroll"},
	{label = "Play_SFX_WebUI_Equip_Battleframe", value = "Play_SFX_WebUI_Equip_Battleframe"},
	{label = "Play_SFX_WebUI_Equip_BackpackModule", value = "Play_SFX_WebUI_Equip_BackpackModule"},
	{label = "Play_SFX_WebUI_Equip_BattleframeModule", value = "Play_SFX_WebUI_Equip_BattleframeModule"},
	{label = "Play_UI_MapMarker_GetFocus", value = "Play_UI_MapMarker_GetFocus"},
	{label = "Play_UI_Map_ZoomIn", value = "Play_UI_Map_ZoomIn"},
	{label = "Play_UI_MapOpen", value = "Play_UI_MapOpen"},
	{label = "Play_UI_Map_DetailClose", value = "Play_UI_Map_DetailClose"},
	{label = "Play_UI_MapClose", value = "Play_UI_MapClose"},
	{label = "Play_UI_Map_DetailOpen", value = "Play_UI_Map_DetailOpen"},
	{label = "Play_SFX_NewYou_GenericConfirm", value = "Play_SFX_NewYou_GenericConfirm"},
	{label = "Play_SFX_NewYou_ItemMenuPopup", value = "Play_SFX_NewYou_ItemMenuPopup"},
}

RESOURCES = {
	{label = "Aluminum", value = 77705},
	{label = "Anabolics", value = 77737},
	{label = "Biopolymer", value = 77714},
	{label = "Carbon", value = 77706},
	{label = "Ceramic", value = 77708},
	{label = "Copper", value = 77703},
	{label = "Iron", value = 77704},
	{label = "Methine", value = 77709},
	{label = "Nitrine", value = 77711},
	{label = "Octine", value = 77710},
	{label = "Petrochemical", value = 77713},
	{label = "Radine", value = 82419},
	{label = "Regenics", value = 77736},
	{label = "Silicate", value = 77707},
	{label = "Toxins", value = 77716},
	{label = "Xenografts", value = 77715},
}

--------------------------
-- Globals for convenience
--------------------------

-- Table to string conversion  -- to do: merge all table functions into one
function TableToList(args, limit)
	local list = ""
	local count = 0
	for index, item in pairs(args) do
		if(count == 0) then list = list..item else list = list.."\n"..item end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

function TableToCommaDelimitedList(args, limit)
	local list = ""
	local count = 0
	for index, item in pairs(args) do
		if(count == 0) then list = list..item else list = list..", "..item end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

function TableIndexToList(args, delimiter, limit)
	local list = ""
	local count = 0
	if(limit == 0) then limit = nil end
	for index, item in pairs(args) do
		if(count == 0) then list = list..index else list = list.."\n"..index end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

function TableIndexToCommaDelimitedList(args, limit) -- lol name
	local list = ""
	local count = 0
	if(limit == 0) then limit = nil end
	for index, item in pairs(args) do
		if(count == 0) then list = list..index else	list = list..", "..index end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

-- alias for system message with optional prefix
function SystemMessage(message, prefix)
	if prefix then
		Component.GenerateEvent("MY_CHAT_MESSAGE", {channel="system", text="["..tostring(prefix).."] "..tostring(message)})
	else
		Component.GenerateEvent("MY_CHAT_MESSAGE", {channel="system", text=tostring(message)})
	end
end

-- Increment
function Inc(t,v)
	if(v == nil) then
		return t + 1
	else
		return t + v
	end
end

-- Decrement
function Dec(t,v)
	if(v == nil) then
		return t - 1
	else
		return t - v
	end
end