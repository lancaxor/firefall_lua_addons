
-- ------------------------------------------
-- lib_PopupBanner
--   by: James Harless
-- ------------------------------------------

--[[ Usage:
	BANNER = PopupBanner.Create(PARENT[, style])		-- Creates a PopupBanner
	BANNER:Destroy()									-- Removes the PopupBanner

	ContainerWidget = BANNER:GetBody()			
	
	BANNER:Open([dur])									-- Opens PopupBanner
	BANNER:Close([dur])									-- Closes PopupBanner
	BANNER:Display([text, dur, color, show_flash])		-- Opens and Closes PopupBanner within a period of time
	BANNER:SetText(text)
	BANNER:SetDuration(dur)
	BANNER:SetColor(color)
	BANNER:EnableFlash(enable)
	BANNER:ShowHotkey(enable)							-- Show Hotkey binding below plate. (only on large)
	BANNER:SetHotkeyBinding(category, action)			-- Sets key from category and action from keybindings
--]]

if PopupBanner then
	return
end
local c_WidgetPadding = 5

PopupBanner = {
	OPEN_DUR = 0.5,
	CLOSE_DUR = 0.5,
}

require "lib/lib_Colors"
require "lib/lib_InputIcon"
require "lib/lib_TextFormat"

local BANNER_ANI = {}
local BANNER_API = {}
local PRIVATE = {}

local STYLE_PRIMARY = "primary"
local STYLE_SECONDARY = "secondary" -- or nil
local STYLE_TERTIARY = "tertiary"
local STYLE_CONTENT = "content"

PVP_STYLES = {
	SMALL = "SMALL",
	TWO_LINE = "TWO_LINE",
	LARGE = "LARGE"
}

local ANIMATION = 
{
	MANUAL 		= 1,	-- Manual, Open / Close Calls
	FADE 		= 2,	-- Automatic, Fade in/out
	SWEEP 		= 3,	-- Automatic, Flipbook sweep animation for new style
	SCROLL_OPEN = 4,
	BURST		= 5,
}

local MODE_CLOSE = 1
local MODE_OPEN = 2

local DEFAULT_COLOR = "#FFFFFF"
local DEFAULT_DURATION = 3

local BP_BANNER_PRIMARY = 
	[[<Group dimensions="left:0; top:0; width:100%; height:40">
		<Group name="SizingGroup" dimensions="left:0; top:0; width:0; height:100%;">
			<Group name="clip" dimensions="dock:fill;" style="clip-children:true;">
				<Text name="label" dimensions="left:0; top:0; height:100%; width:100%;" style="font:Demi_20; valign:center; halign:center; color:orange; drop-shadow:true;" />
			</Group>
			<FlipBook name="Sweep" dimensions="height:80; aspect:2.77; center-y:50%; right:100%+55;" style="texture:GoldTextSweep; visible:false;" fps="75" frameWidth="466" frameHeight="168" frameCount="80" />
		</Group>
	</Group>]]

local BP_BANNER_SECONDARY =
	[[<Group dimensions="left:0; top:0; width:100%; height:25">
		<Group name="SizingGroup" dimensions="left:0; top:0; width:0; height:100%;">
			<Group name="clip" dimensions="dock:fill;" style="clip-children:true;">
				<Text name="label" dimensions="left:0; top:0; height:100%; width:100%;" style="font:Demi_16; valign:center; halign:center; color:white; drop-shadow:true;" />
			</Group>
			<FlipBook name="Sweep" dimensions="height:60; aspect:2.77; center-y:50%; right:100%+55;" style="texture:GoldTextSweep; saturation:0; visible:false;" fps="75" frameWidth="466" frameHeight="168" frameCount="80" />
		</Group>
	</Group>]]

local BP_BANNER_TERTIARY =
	[[<Group dimensions="left:0; top:0; width:100%; height:25">
		<Text name="label" dimensions="dock:fill;" style="font:Demi_16; valign:center; halign:center; color:white; drop-shadow:true;" />
	</Group>]]

local BP_BANNER_CONTENT = 
	[[<Group dimensions="dock:fill">
		<Group name="icon_foster" dimensions="center-x:50%; bottom:100%-6; width:100%; height:100%-6" style="visible:false" />
		<Group name="background" dimensions="top:0; height:100%-6; width:100%" >
			<StillArt name="shadow" dimensions="dock:fill" style="texture:Notification; region:background; alpha:0" />
			<Group name="contents" dimensions="center-x:50%; center-y:50%; width:100%; height:100%;"/>
		</Group>
		<StillArt name="footer" dimensions="top:100%-6; height:55; width:450" style="texture:Notification; region:footer; alpha:0" />
		<Text name="label_hotkey" dimensions="center-x:50%; bottom:100%+25; width:100%; height:15" style="font:UbuntuMedium_10; halign:center; valign:center; wrap:false; clip:false; visible:false"/>
		<StillArt name="plate" dimensions="bottom:100%-1; height:6; width:441" style="texture:Notification; region:base; alpha:0" >
			<StillArt name="flash" dimensions="center-y:50%; center-x:50%; height:64; width:50%" style="texture:starburst; alpha:0; exposure:0.25" />
		</StillArt>
	</Group>]]

local BP_BANNER_LIST = [[
	<ListLayout dimensions="dock:fill;" style="vertical:true; vpadding:5;" />
]]

local BP_BANNER_PVP_SMALL = [[
	<Group dimensions="width:300; height:100; center-x:50%; center-y:50%;">
		<Group name="Background" dimensions="dock:fill;">
			<StillArt name="Background" dimensions="dock:fill;" style="texture:PVPAssets; region:banner_fade_black" />
			<StillArt name="TopBorder" dimensions="width:100%; height:21; center-x:50%; bottom:10;" style="texture:PVPAssets; region:grey_line; blendmode:additive;" />
			<StillArt name="BottomBorder" dimensions="width:100%; height:21; center-x:50%; top:100%-10;" style="texture:PVPAssets; region:grey_line; blendmode:additive; invert-y:true" />
		</Group>
		<ListLayout name="Foreground" dimensions="height:100%-25; center-y:50%; width:100%; center-x:50%;" style="vertical:true; vpadding:8;">
			<Group name="TopRow" dimensions="top:0; left:0; width:100%; height:50%-2;" style="horizontal:true; hpadding:5;">
				<StillArt name="Icon" dimensions="center-x:50%; center-y:50%; height:150%; aspect:1.0" />
				<Text name="Text" dimensions="top:0; left:0; width:100%; height:100%;" style="font:Demi_12; halign:center; valign:center; wrap:false;" />
			</Group>
			<Text name="SubText" dimensions="top:0; left:0; width:100%; height:50%-2;" style="font:Demi_10; halign:center; valign:center; wrap:true;" />
		</ListLayout>
	</Group>
]]

local BP_BANNER_PVP_TWO_LINE = [[
	<Group dimensions="width:500; height:100; center-x:50%; center-y:50%;">
		<Group name="Background" dimensions="dock:fill;">
			<StillArt name="Background" dimensions="dock:fill;" style="texture:PVPAssets; region:banner_fade_black" />
			<StillArt name="TopBorder" dimensions="width:404; height:23; center-x:50%; bottom:10;" style="texture:PVPAssets; region:banner_top_grey;" />
			<StillArt name="BottomBorder" dimensions="width:404; height:24; center-x:50%; top:100%-10;" style="texture:PVPAssets; region:banner_bottom_grey;" />
		</Group>
		<ListLayout name="Foreground" dimensions="height:100%-25; center-y:50%; width:100%; center-x:50%;" style="vertical:true; vpadding:8; clip-children:true;">
			<Text name="Text" dimensions="top:0; left:0; width:100%; height:50%-2;" style="font:Demi_16; halign:center; valign:center;" />
			<Text name="SubText" dimensions="top:0; left:0; width:100%; height:50%-2;" style="font:Demi_10; halign:center; valign:center;" />
		</ListLayout>
		<Group name="Animation" dimensions="center-x:50%; center-y:50%; width:1419; aspect:5.14;" style="visible:false">
			<StillArt name="Top" dimensions="top:0; left:0; width:100%; height:50%;" style="texture:PVPAssets; region:yellow_fade;" />
			<StillArt name="Bottom" dimensions="top:50%; left:0; width:100%; bottom:100%;" style="texture:PVPAssets; region:yellow_fade; invert-y:true;" />
		</Group>
	</Group>
]]

local BP_BANNER_PVP_LARGE = [[
	<Group dimensions="width:800; height:100; center-x:50%; center-y:50%;">
		<Group name="Banner" dimensions="dock:fill;">
			<Group name="Background" dimensions="dock:fill;">
				<StillArt name="Background" dimensions="dock:fill;" style="texture:PVPAssets; region:banner_fade_black" />
				<StillArt name="TopBorder" dimensions="width:100%; height:138; center-x:50%; bottom:10;" style="texture:PVPAssets; region:grey_fade; blendmode:additive;" />
				<StillArt name="BottomBorder" dimensions="width:100%; height:138; center-x:50%; top:100%-10;" style="texture:PVPAssets; region:grey_fade; blendmode:additive; invert-y:true" />
			</Group>
			<ListLayout name="Foreground" dimensions="height:100%-25; center-y:50%; width:100%; center-x:50%;" style="vertical:true; vpadding:8;">
				<Text name="Text" dimensions="top:0; left:0; width:100%; height:50%-2;" style="font:Demi_30; halign:center; valign:center;" />
				<Text name="SubText" dimensions="top:0; left:0; width:100%; height:50%-2;" style="font:Demi_16; halign:center; valign:center;" />
			</ListLayout>
		</Group>
		<Group name="Animation" dimensions="dock:fill">
			<StillArt name="LeftScroll" dimensions="right:0; center-y:50%; width:148; height:152;" style="texture:PVPAssets; region:hilite_streak_orange; alpha:0;" />
			<StillArt name="RightScroll" dimensions="left:100%; center-y:50%; width:148; height:152;" style="texture:PVPAssets; region:hilite_streak_orange; invert-x:true; alpha:0;" />
			<Flipbook name="LeftFlipbook" dimensions="right:50%; center-y:50%; width:550; height:400;" fps="30" frameWidth="550" frameHeight="400" frameCount="34" style="texture:FlipbookPVPLargeOrange; visible:false" />
			<Flipbook name="RightFlipbook" dimensions="left:50%; center-y:50%; width:550; height:400;" fps="30" frameWidth="550" frameHeight="400" frameCount="34" style="texture:FlipbookPVPLargeOrange; invert-x:true; visible:false" />
		</Group>
	</Group>
]]

local BANNER_METATABLE = { __index = function(self,key) return BANNER_API[key] end }

function PopupBanner.Create(PARENT, style)
	assert(PARENT, "Missing Parent!")	
	local BANNER = {	
		-- Variables (all)
		text = "",
		duration = 5,
		flash_ani = false,
		
		-- Variables (content)
		foster = nil,
		mode = nil,	-- No mode on init
		show_hotkey = false,
		category = "Interface",
		action = "NotificationsMenu",
		wrapText = false,
	}

	if style == STYLE_PRIMARY or not ( style ) then
		BANNER.style = STYLE_PRIMARY
		BANNER.animation = ANIMATION.SWEEP
		BANNER.blueprint = BP_BANNER_PRIMARY
		local PARENT_GRP = Component.CreateWidget(BP_BANNER_LIST, PARENT)
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_PRIMARY, PARENT_GRP)
		BANNER.label = "SizingGroup.clip.label"
		BANNER.wrapText = true

	elseif style == STYLE_SECONDARY then
		BANNER.style = STYLE_SECONDARY
		BANNER.animation = ANIMATION.SWEEP
		BANNER.blueprint = BP_BANNER_SECONDARY
		local PARENT_GRP = Component.CreateWidget(BP_BANNER_LIST, PARENT)
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_SECONDARY, PARENT_GRP)
		BANNER.label = "SizingGroup.clip.label"
		BANNER.wrapText = true

	elseif style == STYLE_TERTIARY then
		BANNER.style = STYLE_TERTIARY
		BANNER.animation = ANIMATION.FADE
		BANNER.blueprint = BP_BANNER_TERTIARY
		local PARENT_GRP = Component.CreateWidget(BP_BANNER_LIST, PARENT)
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_TERTIARY, PARENT_GRP)
		BANNER.label = "label"
		BANNER.wrapText = true
		
	elseif style == STYLE_CONTENT then
		BANNER.style = STYLE_CONTENT
		BANNER.animation = ANIMATION.MANUAL
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_CONTENT, PARENT)
		BANNER.SHADOW = BANNER.GROUP:GetChild("background.shadow")
		BANNER.CONTENTS = BANNER.GROUP:GetChild("background.contents")
		BANNER.FOOTER = BANNER.GROUP:GetChild("footer")
		BANNER.PLATE = BANNER.GROUP:GetChild("plate")
		BANNER.FLASH = BANNER.GROUP:GetChild("plate.flash")
		BANNER.HOTKEY = BANNER.GROUP:GetChild("label_hotkey")
		
		-- Create Input Icon Visual
		BANNER.INPUTICON = InputIcon.CreateVisual(BANNER.GROUP:GetChild("icon_foster"), "input_key")
		
		-- Refresh Hotkey
		PRIVATE.RefreshHotkey(BANNER)
		
		-- Change Icon Visual Tint to Green with Blue Glow
		--BANNER.INPUTICON.ICON:SetParam("tint", Component.LookupColor("army"))
	elseif unicode.upper(style) == PVP_STYLES.SMALL then
		BANNER.style = PVP_STYLES.SMALL
		BANNER.animation = ANIMATION.FADE
		BANNER.blueprint = BP_BANNER_PVP_SMALL
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_PVP_SMALL, PARENT)
		BANNER.fgPadding = 20
		BANNER.label = "Foreground.TopRow.Text"
		BANNER.label2 = "Foreground.SubText"
		BANNER.icon = "Foreground.TopRow.Icon"
		BANNER.background = "background"

	elseif unicode.upper(style) == PVP_STYLES.TWO_LINE then
		BANNER.style = PVP_STYLES.TWO_LINE
		BANNER.animation = ANIMATION.SCROLL_OPEN
		BANNER.blueprint = BP_BANNER_PVP_TWO_LINE
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_PVP_TWO_LINE, PARENT)
		BANNER.fgPadding = 30
		BANNER.label = "Foreground.Text"
		BANNER.label2 = "Foreground.SubText"
		BANNER.background = "background"

	elseif unicode.upper(style) == PVP_STYLES.LARGE then
		BANNER.style = PVP_STYLES.LARGE
		BANNER.animation = ANIMATION.BURST
		BANNER.blueprint = BP_BANNER_PVP_LARGE
		BANNER.GROUP = Component.CreateWidget(BP_BANNER_PVP_LARGE, PARENT)
		BANNER.fgPadding = 40
		BANNER.label = "Banner.Foreground.Text"
		BANNER.label2 = "Banner.Foreground.SubText"
		BANNER.background = "Banner.Background"
	else
		error("Invalid style "..tostring(style))
	end
	
	setmetatable(BANNER, BANNER_METATABLE)

	if style == STYLE_CONTENT then
		BANNER:SetColor(DEFAULT_COLOR)
	end

	BANNER.GROUP:Show(false)
	
	return BANNER
end

------------- --
-- BANNER API --
------------- --
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide",	"IsVisible", "GetBounds", "SetTag", "GetTag", "SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus"
};
for _, method_name in pairs(COMMON_METHODS) do
	BANNER_API[method_name] = function(BANNER, ...)
		return BANNER.GROUP[method_name](BANNER.GROUP, ...);
	end
end

function BANNER_API.Destroy(SELF)
	Component.RemoveWidget(SELF:GetBody())

	for k,v in pairs(SELF) do
		SELF[k] = nil
	end
end

function BANNER_API.GetBody(SELF)
	if SELF.style == STYLE_CONTENT then
		return SELF.CONTENTS
	elseif SELF.wrapText then
		return SELF.GROUP:GetParent()
	else
		return SELF.GROUP
	end
end


function BANNER_API.Open(SELF, dur)
	if SELF.style ~= STYLE_CONTENT then
		warn("Incompatable Style")
		return
	end
	BANNER_ANI[SELF.animation](SELF, MODE_OPEN, dur)
end

function BANNER_API.Close(SELF, dur)
	if SELF.style == STYLE_CONTENT then
		BANNER_ANI[SELF.animation](SELF, MODE_CLOSE, dur)

	elseif SELF.hideFuncs then
		PRIVATE.CloseBannerWithHideFuncs(SELF)

	else
		SELF:GetBody():ParamTo("alpha", 0, dur or c_BannerFadeLength)
	end	
end

function BANNER_API.Display(SELF, ...)
    local arg = {...}
	if SELF.style == STYLE_CONTENT then
		warn("Incompatable Style")
		return
	end
	if arg[1] then
		SELF:SetText(arg[1])
	end
	if arg[2] then
		SELF:SetDuration(arg[2])
	end
	if arg[3] then
		SELF:SetColor(arg[3])
	end
	SELF:EnableFlash(arg[4])

	local totalDuration = 0
	local args = BANNER_ANI[SELF.animation](SELF)
	-- Creating sub banners for wrapping
	if type(args) == "table" then
		totalDuration = totalDuration + PRIVATE.GenerateSubBanners(SELF, args)
		
	elseif type(args) == "number" then
		totalDuration = totalDuration + args
	end

	return totalDuration + c_BannerFadeLength
end

function BANNER_API.SetText(SELF, text, subtext)
	SELF.text = text
	SELF.subtext = subtext

	if SELF.label then
		SELF.GROUP:GetChild(SELF.label):SetText(SELF.text)
	end

	if SELF.label2 then
		SELF.GROUP:GetChild(SELF.label2):SetText(SELF.text)
	end
end

function BANNER_API.SetDuration(SELF, duration)
	if type(duration) == "number" then
		-- -1 is special case for infinite duration
		if duration == -1 then
			duration = 0
		elseif duration < 1 then
			duration = DEFAULT_DURATION
		end
		SELF.duration = duration
	else
		warn("Duration must be a number value!")
	end
end

function BANNER_API.SetColor(SELF, Color)
	PRIVATE.SetColors(SELF, Color)
end

BANNER_API.TintBack = BANNER_API.SetColor

function BANNER_API.EnableFlash(SELF, enable)
	SELF.flash_ani = enable
end

function BANNER_API.SetHotkeyBinding(category, action)
	SELF.category = category
	SELF.action = action
end

function BANNER_API.ShowHotkey(SELF, enable)
	SELF.show_hotkey = enable
	SELF.HOTKEY:Show(enable)
end

function BANNER_API.SetIcon(SELF, texture, region)
	SELF.texture = texture
	SELF.region = region

	if SELF.icon and texture then
		SELF.GROUP:GetChild(SELF.icon):SetTexture(texture, region)
	end
end

-------------------- --
-- BANNER ANIMATIONS --
-------------------- --
c_SweepFadeLen = 0.1
c_AnimBufferWidth = 100
c_SpeedBase = 0.33
c_SpeedMultiplier = 0.5
c_BannerFadeLength = 0.5
BANNER_ANI[ANIMATION.SWEEP] = function (SELF, delay)
	if not delay then delay = 0 end
	local LABEL = SELF.GROUP:GetChild(SELF.label)
	local BANNER = SELF.GROUP:GetChild("SizingGroup") -- List layout means groups have to be left aligned, so use a subgroup

	LABEL:SetText(SELF.text)
	LABEL:SetDims("top:_; height:_; center-x:50%; width:" .. SELF.GROUP:GetBounds().width)
	local width = LABEL:GetTextDims().width + c_AnimBufferWidth

	local leftover, numChildren
	if LABEL:GetTextDims().width > LABEL:GetBounds().width then
		leftover = PRIVATE.GetTextWithinBounds(LABEL, SELF.text)
	end

	BANNER:SetDims("top:_; height:_; center-x:50%; width:" .. width)
	BANNER:SetDims("top:_; height:_; left:_; width:0")

	LABEL:SetParam("alpha", 1)
	LABEL:SetDims("left:0; top:_; height_; width:" .. width)

	SELF.GROUP:Show(true, delay)

	local screenPercent = width/Component.GetScreenSize(true)
	local animSpeed = c_SpeedBase + (screenPercent * c_SpeedMultiplier)

	local SWEEP = BANNER:GetChild("Sweep")
	callback ( function(FB)
		FB:Reset()
		FB:SetParam("alpha", 0)
		FB:Show()
		FB:ParamTo("alpha", 1, c_SweepFadeLen)
		FB:Play(animSpeed, 1, false, false)
	end, SWEEP, delay)

	local animLength = screenPercent * SWEEP:GetLength()

	callback ( function(FB)
		FB:ParamTo("alpha", 0, c_SweepFadeLen)
	end, SWEEP, animLength-c_SweepFadeLen+delay)

	callback( function(FB)
		FB:Hide()
		FB:Stop()
		FB:Reset()
	end, SWEEP, animLength+c_SweepFadeLen+delay)
	
	BANNER:MoveTo("top:_; left:_; height:_; width:" .. width, animLength, delay)

	-- For some reason the delay isn't working properly with this so sticking in a callback temporarily
	local hideFunc = function(BANNER_GRP, labelStr)
		local BANNER = BANNER_GRP:GetChild("SizingGroup")
		BANNER_GRP:GetChild(labelStr):ParamTo("alpha", 0, c_BannerFadeLength)
		BANNER:MoveTo("top:_; left:_; height:_; width:0;", 0, c_BannerFadeLength)
		BANNER_GRP:Show(false, c_BannerFadeLength)
	end

	return {leftover=leftover, totalLength=SELF.duration + animLength, hideFunc=hideFunc}
end

BANNER_ANI[ANIMATION.FADE] = function (SELF)
	local LABEL = SELF.GROUP:GetChild(SELF.label)

	LABEL:SetText(SELF.text or "")
	if not SELF.text or SELF.text == "" then
		LABEL:Hide()
	end

	if SELF.label2 then
		local SUB_TEXT = SELF.GROUP:GetChild(SELF.label2)

		if not SELF.subtext or SELF.subtext == "" then
			SUB_TEXT:Hide()
		end

		local subtextHeight = SUB_TEXT:GetTextDims().height
		SUB_TEXT:SetDims("top:0; height:" .. subtextHeight)
	end

	local leftover
	if SELF.wrapText and LABEL:GetTextDims().width > LABEL:GetBounds().width then
		leftover = PRIVATE.GetTextWithinBounds(LABEL, SELF.text)
	end

	local textDims = LABEL:GetTextDims()
	LABEL:SetDims("top:0; height:" .. textDims.height)

	if SELF.icon then
		local ICON = SELF.GROUP:GetChild(SELF.icon)
		ICON:Show(SELF.texture)
	end

	if not SELF.wrapText then
		SELF.GROUP:SetDims("center-x:50%; width:" .. (textDims.width+80))
	end

	local FG = SELF.GROUP:GetChild("Foreground")
	if FG then
		local TOP_ROW = FG:GetChild("TopRow")
		if TOP_ROW then
			TOP_ROW:SetDims("width:100%; height:" .. textDims.height)

			local insideWidth = textDims.width
			local left = (TOP_ROW:GetBounds().width - insideWidth)/2

			local ICON = SELF.GROUP:GetChild(SELF.icon)
			if SELF.texture then
				local iconWidth = ICON:GetBounds().height
				insideWidth = insideWidth + iconWidth
				left = (TOP_ROW:GetBounds().width - insideWidth)/2

				ICON:SetDims("left:" .. left .. "; width:" .. iconWidth)
				left = left + iconWidth + c_WidgetPadding
			end

			LABEL:SetDims("left:" .. left .. "; width:" .. textDims.width)
		end

		local fgHeight = FG:GetContentBounds().height
		FG:SetDims("center-y:50%; height:" .. fgHeight)
		SELF.GROUP:SetDims("center-y:50%; height:" .. tostring(fgHeight+(SELF.fgPadding or 0)))
	end

	SELF.GROUP:SetParam("alpha", 0)
	SELF.GROUP:Show()

	SELF.GROUP:QueueParam("alpha", 1, c_BannerFadeLength, 0, "smooth")

	local hideFunc = function(BANNER_GRP)
		BANNER_GRP:QueueParam("alpha", 0, c_BannerFadeLength, 0, "smooth")
		BANNER_GRP:Show(false, c_BannerFadeLength*2)
	end

	return {leftover=leftover, totalLength=SELF.duration + c_BannerFadeLength, hideFunc=hideFunc}
end

BANNER_ANI[ANIMATION.MANUAL] = function (SELF, mode, duration)
	if SELF.mode ~= mode then
		local dur = duration or PopupBanner.OPEN_DUR
		
		SELF.mode = mode
		if mode == MODE_OPEN then
			SELF.GROUP:Show(true)
			
			local base_alpha_intro_dur = 0.5 
			local base_alpha_intro_delay = 0
			local base_move_intro_dur = 0.3

			-- Start Base Animation	
			SELF.PLATE:SetParam("alpha", 0)
			SELF.PLATE:ParamTo("alpha", 0.8, base_alpha_intro_dur)
			
			SELF.PLATE:SetDims("height:_; bottom:100%+20")
			SELF.PLATE:MoveTo(SELF.PLATE:GetInitialDims(), base_move_intro_dur)
			
			-- Footer
			SELF.FOOTER:SetParam("alpha", 0)
			SELF.FOOTER:ParamTo("alpha", 1, 0.75)

			local content_alpha_intro_dur = 0.3
			local content_alpha_intro_delay = 0.5
			
			-- Content Display Animation
			SELF.CONTENTS:SetParam("alpha", 0)
			SELF.CONTENTS:ParamTo("alpha", 1, content_alpha_intro_dur, content_alpha_intro_delay)
			
			local shadow_alpha_intro_dur = 0.1
			local shadow_alpha_intro_delay = 0.1
			local shadow_move_intro_dur = 0.4
			local shadow_move_intro_delay = 0.1
			
			-- Shadow Backgroud Animation
			local content_bounds = SELF.CONTENTS:GetBounds(false)
		
			SELF.SHADOW:SetParam("alpha", 0)
			SELF.SHADOW:ParamTo("alpha", 0.9, shadow_alpha_intro_dur, shadow_alpha_intro_delay)
			SELF.SHADOW:MoveTo("height:_; width:"..content_bounds.width+400, shadow_move_intro_dur, shadow_move_intro_delay, "ease-out")
					
			if SELF.flash_ani then
				SELF.FLASH:SetParam("glow", SELF.colors.flash_glow)
				SELF.FLASH:SetParam("tint", SELF.colors.flash_tint)
				SELF.FLASH:SetParam("alpha", 0)
				SELF.FLASH:ParamTo("alpha", 1, 0.3)
				SELF.FLASH:QueueParam("alpha", 0, 0.3, 0.1)
				SELF.FLASH:SetDims("center-x:_; center-y:_; width:".. content_bounds.width/1.5 .."; height:220")
				SELF.FLASH:MoveTo("center-x:_; center-y:_; width:".. content_bounds.width+150 .."; height:10", 0.5,"ease-out")
			end
			
			-- Animate Hotkey
			if SELF.show_hotkey then
				SELF.HOTKEY:SetDims("bottom:100%+5")
				SELF.HOTKEY:MoveTo(SELF.HOTKEY:GetInitialDims(), 0.5, 0.2, "smooth")
				
				SELF.HOTKEY:SetParam("alpha", 0)
				SELF.HOTKEY:ParamTo("alpha", 1, 0.4, 0.2, "smooth")
			end
			
			-- Resize Group to match the Content
			SELF.GROUP:SetDims("height:"..content_bounds.height+46)
			
			-- Update Hotkey Icon
			PRIVATE.RefreshHotkey(SELF)
			
		elseif mode == MODE_CLOSE then
			SELF.GROUP:Show(false, dur)
			
			-- Close Animation
			SELF.PLATE:ParamTo("alpha", 0, dur*0.2, dur*0.8)
			SELF.PLATE:MoveTo("height:_; bottom:100%+10", dur*0.3, dur*0.7)
			
			SELF.FOOTER:ParamTo("alpha", 0, dur*0.6)
			
			SELF.SHADOW:MoveTo("width:0", dur*0.6, dur*0.4, "ease-in")
			SELF.SHADOW:ParamTo("alpha", 0, dur*0.3, dur*0.6)
			
			SELF.CONTENTS:QueueParam("alpha", 0, dur*0.3, dur*0.2)
		end
	end
end

BANNER_ANI[ANIMATION.SCROLL_OPEN] = function (SELF)
	local TEXT = SELF.GROUP:GetChild(SELF.label)
	local SUB_TEXT = SELF.GROUP:GetChild(SELF.label2)

	TEXT:SetText(SELF.text or "")
	SUB_TEXT:SetText(SELF.subtext or "")

	if not SELF.text or SELF.text == "" then
		TEXT:Hide()
	end

	if not SELF.subtext or SELF.subtext == "" then
		SUB_TEXT:Hide()
	end

	local textHeight = TEXT:GetTextDims().height
	TEXT:SetDims("top:0; height:" .. textHeight)
	local subtextHeight = SUB_TEXT:GetTextDims().height
	SUB_TEXT:SetDims("top:0; height:" .. subtextHeight)

	local FG = SELF.GROUP:GetChild("Foreground")
	local fgHeight = FG:GetContentBounds().height
	FG:SetDims("center-y:50%; height:100%-" .. SELF.fgPadding)

	local testLen = c_BannerFadeLength

	local totalFinalHeight = fgHeight+(SELF.fgPadding or 0)
	
	SELF.GROUP:QueueMove("center-y:50%; height:0", 0)
	SELF.GROUP:SetParam("alpha", 0)
	TEXT:SetParam("alpha", 0)
	SUB_TEXT:SetParam("alpha", 0)
	SELF.GROUP:Show()

	SELF.GROUP:QueueParam("alpha", 1, testLen/4, 0, "smooth")
	TEXT:QueueParam("alpha", 1, testLen/2, testLen/2, "smooth")
	SUB_TEXT:QueueParam("alpha", 1, testLen/2, testLen/4*3, "smooth")
	SELF.GROUP:QueueMove("center-y:50%; height:" ..totalFinalHeight, testLen/2, 0, "smooth")

	local ANIM_GRP = SELF.GROUP:GetChild("Animation")
	ANIM_GRP:SetDims("width:0; center-x:50%; center-y:50%; aspect:5.14;")
	ANIM_GRP:MoveTo("width:200%; center-x:50%; center-y:50%; aspect:5.14;", testLen)

	local hideFunc = function(BANNER_GRP)
		if Component.IsWidget(BANNER_GRP) then
			BANNER_GRP:QueueParam("alpha", 0, c_BannerFadeLength, 0, "smooth")
			BANNER_GRP:Show(false, c_BannerFadeLength)
		end
	end

	return {totalLength=SELF.duration + c_BannerFadeLength, hideFunc=hideFunc}
end

BANNER_ANI[ANIMATION.BURST] = function (SELF)
	local c_ScrollLen = 0.5
	local c_BaseAnimColor = "F97B00"

	local TEXT = SELF.GROUP:GetChild(SELF.label)
	local SUB_TEXT = SELF.GROUP:GetChild(SELF.label2)

	TEXT:SetText(SELF.text or "")
	SUB_TEXT:SetText(SELF.subtext or "")

	if not SELF.text or SELF.text == "" then
		TEXT:Hide()
	end

	if not SELF.subtext or SELF.subtext == "" then
		SUB_TEXT:Hide()
	end

	local textHeight = TEXT:GetTextDims().height
	TEXT:SetDims("top:0; height:" .. textHeight)
	local subtextHeight = SUB_TEXT:GetTextDims().height
	SUB_TEXT:SetDims("top:0; height:" .. subtextHeight)

	local FG = SELF.GROUP:GetChild("Banner.Foreground")
	local fgHeight = FG:GetContentBounds().height
	FG:SetDims("center-y:50%; height:" .. fgHeight)
	SELF.GROUP:SetDims("center-y:50%; height:" .. tostring(fgHeight+(SELF.fgPadding or 0)))

	SELF.GROUP:Show()

	local BANNER = SELF.GROUP:GetChild("Banner")
	BANNER:SetParam("alpha", 0)

	local ANIM_GRP = SELF.GROUP:GetChild("Animation")
	if SELF.color then
		for i=1, ANIM_GRP:GetChildCount() do
			Colors.MatchColorOnWidget(ANIM_GRP:GetChild(i), c_BaseAnimColor, SELF.color)
		end
	end

	local LEFT_SCROLL = ANIM_GRP:GetChild("LeftScroll")
	local RIGHT_SCROLL = ANIM_GRP:GetChild("RightScroll")
	LEFT_SCROLL:MoveTo("width:_; right:50%;", c_ScrollLen)
	RIGHT_SCROLL:MoveTo("width:_; left:50%;", c_ScrollLen)
	LEFT_SCROLL:QueueParam("alpha", 1, c_ScrollLen, 0, "ease-out")
	RIGHT_SCROLL:QueueParam("alpha", 1, c_ScrollLen, 0, "ease-out")
	LEFT_SCROLL:QueueParam("alpha", 0, c_ScrollLen/2, 0, "ease-in")
	RIGHT_SCROLL:QueueParam("alpha", 0, c_ScrollLen/2, 0, "ease-in")

	local LEFT_FB = ANIM_GRP:GetChild("LeftFlipbook")
	local RIGHT_FB = ANIM_GRP:GetChild("RightFlipbook")
	LEFT_FB:Show(true, c_ScrollLen)
	RIGHT_FB:Show(true, c_ScrollLen)
	LEFT_FB:Play(1, 1, false, false, c_ScrollLen)
	RIGHT_FB:Play(1, 1, false, false, c_ScrollLen)

	BANNER:QueueParam("alpha", 1, c_BannerFadeLength, c_ScrollLen, "smooth")

	local timeToFade = SELF.duration + c_BannerFadeLength + c_ScrollLen

	local hideFunc = function(GROUP)
		if Component.IsWidget(GROUP) then
			GROUP:QueueParam("alpha", 0, c_BannerFadeLength, 0, "smooth")
			GROUP:Show(false, c_BannerFadeLength)
		end
	end

	return {totalLength = SELF.duration + c_BannerFadeLength + c_ScrollLen, hideFunc=hideFunc}
end

-------------------- --
-- PRIVATE FUNCTIONS --
-------------------- --
function PRIVATE.SetColors(self, color)
	self.color = color
	if self.style == STYLE_CONTENT then
		local basetint = Colors.Create(color)
		-- Decrease color saturation for flash texture
		local flashtint = Colors.toHSV(basetint)
		flashtint.s = flashtint.s * 0.2
		self.colors = {
			label_tint=basetint:toRGB(),
			flash_glow=basetint:toRGBA(),
			flash_tint=Colors.Create(flashtint):toRGB()
		}
	elseif PVP_STYLES[self.style] ~= nil then
		local BG_GROUP = self.GROUP:GetChild(self.background)
		for i=1, BG_GROUP:GetChildCount() do
			BG_GROUP:GetChild(i):SetParam("tint", color)
		end
		self.GROUP:GetChild(self.label2 or self.label):SetTextColor(color)
	else
		self.GROUP:GetChild(self.label):SetTextColor(color)
	end
end

function PRIVATE.RefreshHotkey(SELF)
		-- Capture Hotkey
		local bindinggroup = System.GetKeyBindings(SELF.category, false)[SELF.action]
		local actionkey = bindinggroup[1] or bindinggroup[2]
		-- Set Icon Art
		SELF.INPUTICON:SetBind(actionkey)
		
		-- Capture Texture Region dims
		local icon_dims = Component.GetTextureInfo(SELF.INPUTICON.ICON:GetTexture())
		
		-- Setup TextFormat
		local TF = TextFormat.Create()
		TextFormat.HandleString(Component.LookupText("PRESS_KEY_TO_VIEW"), function(str)
			TF:AppendText(str)
		end,
			{
				["<KEY>"] = function(str)
					TF:AppendWidget(SELF.GROUP:GetChild("icon_foster.input_key"), {width=icon_dims.width})
				end,
			}
		)
		TF:ApplyTo(SELF.HOTKEY)	
end

function PRIVATE.GetTextWithinBounds(WIDGET, text)
	local fitText = text
	WIDGET:SetText(fitText)

	while WIDGET:GetTextDims().width > WIDGET:GetBounds().width do
		fitText = unicode.match(fitText, "^(.+) .-$")
		
		-- One long word
		if fitText == nil then
			WIDGET:SetText(text)
			return
		end

		WIDGET:SetText(fitText)
	end

	return unicode.match(text, "^" .. fitText .. " (.+)$")
end

function PRIVATE.GenerateSubBanners(BANNER, args)
	local totalDuration = args.totalLength
	local delay = args.totalLength - BANNER.duration
	local hideFuncs = {args.hideFunc}
	while args.leftover do
		local SUB_BANNER = PRIVATE.CreateSubBanner(BANNER, args.leftover)
		args = BANNER_ANI[BANNER.animation](SUB_BANNER, delay)
		delay = delay + args.totalLength - BANNER.duration
		totalDuration = totalDuration + args.totalLength
		table.insert(hideFuncs, args.hideFunc)
	end

	BANNER.hideFuncs = hideFuncs

	-- Otherwise manual close
	if BANNER.duration > 0 then
		callback( function ()
			PRIVATE.CloseBannerWithHideFuncs(BANNER)
		end, nil, totalDuration)
	end

	-- return full length of duration with fades
	return totalDuration
end

function PRIVATE.CloseBannerWithHideFuncs(BANNER)
	if not BANNER.hideFuncs then return end

	local PARENT_GRP = BANNER:GetBody()

	if BANNER.wrapText then
		-- callback may fire after the destroy process, we need to check to make sure it still exists
		if BANNER.hideFuncs then
			for i, hideFunc in pairs(BANNER.hideFuncs) do
				if PARENT_GRP and Component.IsWidget(PARENT_GRP) and PARENT_GRP:GetChildCount() >= i and BANNER.label then
					hideFunc(PARENT_GRP:GetChild(i), BANNER.label)
				end
			end
		end
	else
		if PARENT_GRP and Component.IsWidget(PARENT_GRP) then
			BANNER.hideFuncs[1](PARENT_GRP)
		end
	end
end

function PRIVATE.CreateSubBanner(SELF, leftover)
	local SUB_BANNER = {}
	SUB_BANNER.text = leftover
	SUB_BANNER.GROUP = Component.CreateWidget(SELF.blueprint, SELF.GROUP:GetParent())
	SUB_BANNER.label = SELF.label
	SUB_BANNER.duration = SELF.duration
	SUB_BANNER.wrapText = SELF.wrapText

	if SELF.color then
		SUB_BANNER.GROUP:GetChild(SUB_BANNER.label):SetTextColor(SELF.color)
	end

	return SUB_BANNER
end
