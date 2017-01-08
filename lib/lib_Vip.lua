
--[[ VIP LIB add descriptions
]]

if VIPLIB then
	return
end

require "lib/lib_Shader"

VIPLIB = {}

local lf = {}
local VIP_API = {}
local VIP_MT = {__index=function(_, key) return VIP_API[key] end}

local VIP_BP = [[<FocusBox dimensions="dock:fill">
		<StillArt name="art" dimensions="dock:fill" style="texture:vip_icon; eatsmice:false"/>
		<GlyphMap name="level" dimensions="center-x:54%; center-y:58%; height:_; width:_;" style="texture:vip_glyph; eatsmice:false; halign:center; valign:center; padding:0; kerning-mult:0.6; baseline:1;"
			lineheight="10" charset="1234567890"/>
	</FocusBox>
]]

local g_VipLevel = 0

function VIPLIB.CreateVIPBadge(PARENT_, idOrInfo)
	assert(PARENT_, "Must supply a parent widget for CreateVIPWidget")
	local WIDGET = Component.CreateWidget(VIP_BP, PARENT_)
	local VIP_WIDGET = {
		FOCUS = WIDGET,
		PARENT = PARENT_,
		ART = WIDGET:GetChild("art"),
		LEVEL = WIDGET:GetChild("level"),
	}

	if type(idOrInfo) == "number" or type(ifOrInfo) == "table" then
		VIP_WIDGET.entityInfo = idOrInfo
	end

	VIP_WIDGET.FOCUS:BindEvent("OnMouseEnter", function() lf.VipMouseEnter(VIP_WIDGET) end)
	VIP_WIDGET.FOCUS:BindEvent("OnMouseLeave", function() lf.VipMouseLeave(VIP_WIDGET) end)
	VIP_WIDGET.FOCUS:BindEvent("OnMouseUp", function() lf.VipMouseUp(VIP_WIDGET) end)

	setmetatable(VIP_WIDGET, VIP_MT)

	return VIP_WIDGET
end

--call on player ready or future change event
function VIP_API.UpdateDisplay(VIP_WIDGET, shouldBeNormal, idOrInfo)
	if type(idOrInfo) == "number" or type(idOrInfo) == "table" then
		VIP_WIDGET.entityInfo = idOrInfo
	end
	-- TO DO: if LVL_BADGE_WIDGET.entityInfo use that entity ID instead of self. See lib_LevelBadge

	g_VipLevel =  0--(g_VipLevel + 1) % 21
	lf.SetDimsAndKerning(VIP_WIDGET.LEVEL, g_VipLevel)
	
	local parentBounds = VIP_WIDGET.PARENT:GetBounds()
	VIP_WIDGET.LEVEL:SetLineHeight(parentBounds.height/3)

	VIP_WIDGET.LEVEL:SetText(tostring(g_VipLevel))
	local vipTime = Player.GetVIPTime()
	if vipTime ~= nil or shouldBeNormal then
		Shader.SetShaderNormal(VIP_WIDGET.ART)
	else
		Shader.SetShaderGrayscale(VIP_WIDGET.ART)
	end
	--callback(function() VIP_WIDGET:UpdateDisplay() end, nil, 1)
end

function lf.VipMouseEnter(VIP_WIDGET)
	VIP_WIDGET.ART:ParamTo("exposure", 0.3, 0.2)
end

function lf.VipMouseLeave(VIP_WIDGET)
	VIP_WIDGET.ART:ParamTo("exposure", 0, 0.2)
end

function lf.VipMouseUp(VIP_WIDGET)
	Component.GenerateEvent("MY_WEBUI_TOGGLE", {panel="vip"})
end

function lf.SetDimsAndKerning(GLYPHS, level)
	local dims
	local kerning
	if level < 10 or level == 11 then
		dims = "left:_; height:_; center-y:_; right:85%;"
		kerning = 0.6
	elseif level < 20 then
		dims = "left:_; height:_; center-y:_; right:83%;"
		kerning = 0.6
	else
		dims = "left:_; height:_; center-y:_; right:92%;"
		kerning = 0.75
	end
	GLYPHS:SetDims(dims)
	GLYPHS:SetKerningMult(kerning)
end
