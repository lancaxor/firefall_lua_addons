
--
-- Glow Header Lib **Used to create a screen header widget with a glow background
--
if GLOW_HEADER_LIB then
	return
end

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local GLOW_HEADER_BP = [[
	<Group name="HeaderGroup" dimensions="center-x:50%; center-y:30; width:_; height:_" >
		<StillArt name="glow" dimensions="center-x:50%; center-y:_; width:572; height:200" style="alpha:.8; texture:BGInnerHeaderGlow"/>
		<StillArt name="bg_left" dimensions="center-x:50%; center-y:_; width:125; height:72" style="texture:BGHeaderPlate; region:left"/>
		<StillArt name="bg_center" dimensions="center-x:50%; center-y:_; width:82; height:72" style="texture:BGHeaderPlate; region:center"/>
		<StillArt name="bg_right" dimensions="center-x:50%; center-y:_; width:125; height:72" style="texture:BGHeaderPlate; region:right"/>
		<Text name="title" dimensions="center-x:50%; center-y:50%; height:20; width:100%;" style="alpha:1; font:Demi_23; halign:center;"/>
	</Group>
]]

local TEAM_BP = [[
	<Group dimensions="dock:fill">
		<Group dimensions="center-x:50%; top:50%+56; height:16; width:21" style="alpha:1"/>
	</Group>
]]

-- ------------------------------------------
-- GLOBALS
-- ------------------------------------------
GLOW_HEADER_LIB = {}

-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local GLOW_HEADER_API = {} -- Used for object methods
local GLOW_HEADER_MT = {
	__index=function(_, inKey) return GLOW_HEADER_API[inKey] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in CONTEXTMENU"); end
}

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
function GLOW_HEADER_LIB.CreateGlowHeader(PARENT_)
	assert(PARENT_, "Must supply a parent widget for CreateVIPWidget")
	
	local WIDGET = Component.CreateWidget(GLOW_HEADER_BP, PARENT_)
	local GLOW_HEADER_WIDGET = {
		GROUP = WIDGET,
		PARENT = PARENT_,
		TITLE = WIDGET:GetChild("title"),
		LEFT_BG = WIDGET:GetChild("bg_left"),
		CENTER_BG = WIDGET:GetChild("bg_center"),
		RIGHT_BG = WIDGET:GetChild("bg_right"),
		GLOW = WIDGET:GetChild("glow"),
	}
	
	setmetatable(GLOW_HEADER_WIDGET, GLOW_HEADER_MT)
	
	return GLOW_HEADER_WIDGET
end

function GLOW_HEADER_API.SetText(WIDGET, text)
	WIDGET.TITLE:SetText(text)
	pf.ResizeHeader(WIDGET)
end

-- ------------------------------------------
-- PRIVATE API
-- ------------------------------------------
function pf.ResizeHeader(WIDGET)
	local textDims = WIDGET.TITLE:GetTextDims()
	local textWidth = textDims.width
	
	WIDGET.CENTER_BG:MoveTo("width:"..tostring(math.max(0, textWidth - 125)), dur)
	WIDGET.LEFT_BG:MoveTo("center-x:50%-"..tostring((math.max(125,textWidth)) / 2) .. "; center-y:_; height:_; width:_;", dur)
	WIDGET.RIGHT_BG:MoveTo("center-x:50%+"..tostring((math.max(125,textWidth)) / 2), dur)
	WIDGET.GLOW:MoveTo("width:"..tostring(textWidth + 320), dur)
end
