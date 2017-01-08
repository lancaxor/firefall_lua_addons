
--
-- Lvl Badge Lib
--

-- 
-- If passing in a manual info table, following info should be included if available (will default to 0):
-- level, effective_level, elite_level
--

if LVL_BADGE_LIB then
	return
end

LVL_BADGE_LIB = {} -- Used for creation of object

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local LVL_BADGE_BP = [[
	<Group name="IconGroup" dimensions="dock:fill" >
		<StillArt name="bg" dimensions="dock:fill;" style="texture:LevelChevronBG;" />
		<StillArt name="eliteIcon" dimensions="center-x:50%; center-y:94%; width:50; height:30;" style="texture:EliteIndicator; visible:false; exposure:0.5;" />
		<GlyphMap name="level" dimensions="left:0; right:95%; top:0; height:70%" style="texture:glyph_aag; kerning-mult:0.75; halign:center; valign:center;"
			lineheight="16" charset="1234567890"/>
		<StillArt name="levelArrow" dimensions="center-x:50%; width:40%; aspect:1.5; top:40%" style="texture:LevelArrow; region:down; visible:false"/>
	</Group>
]]

-- ------------------------------------------
-- GLOBAL VARIABLES
-- ------------------------------------------
LVL_BADGE_LIB = {}

-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local LVL_BADGE_API = {} -- Used for object methods
local LVL_BADGE_MT = {__index=function(_, inKey) return LVL_BADGE_API[inKey] end}

local g_PlayerLevel = 0

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
-- Entity ID Optional. Will use self if nothing inputted
function LVL_BADGE_LIB.CreateLevelBadge(PARENT_, idOrInfo)
	assert(PARENT_, "Must supply a parent widget for CreateVIPWidget")
	
	local WIDGET = Component.CreateWidget(LVL_BADGE_BP, PARENT_)
	local LVL_BADGE_WIDGET = {
		FOCUS = WIDGET,
		PARENT = PARENT_,
		BG = WIDGET:GetChild("bg"),
		LEVEL = WIDGET:GetChild("level"),
		ELITE_ICON = WIDGET:GetChild("eliteIcon"),
		ARROW = WIDGET:GetChild("levelArrow"),
	}

	if type(idOrInfo) == "number" or type(ifOrInfo) == "table" then
		LVL_BADGE_WIDGET.entityInfo = idOrInfo
	end

	setmetatable(LVL_BADGE_WIDGET, LVL_BADGE_MT)

	return LVL_BADGE_WIDGET
end

--call on player ready or future change event
-- Entity ID Optional. Will use entityID given in Create or self if nothing inputted
function LVL_BADGE_API.UpdateDisplay(LVL_WIDGET, idOrInfo)
	if type(idOrInfo) == "number" or type(idOrInfo) == "table" then
		LVL_WIDGET.entityInfo = idOrInfo
	end

	if type(LVL_WIDGET.entityInfo) == "table" then
		info = LVL_WIDGET.entityInfo
	else
		local entityID = LVL_WIDGET.entityInfo or Player.GetTargetId()

		info = Game.GetTargetInfo(entityID)
		if info == nil then return end
	end

	local currLevel = info.level or 0
	local effectiveLevel = info.effective_level or info.level
	local eliteLevel = info.elite_level or 0
	local showElite = (info.battleframeMaxLevel and currLevel >= info.battleframeMaxLevel) and eliteLevel > 0

	local levelChanged = pf.UpdateLevelArrow(LVL_WIDGET.ARROW, LVL_WIDGET.LEVEL, effectiveLevel, currLevel)
	eliteLevel = levelChanged and 0 or eliteLevel -- Change elite level to 0 after showElite so we don't get false negative
	eliteLevel = showElite and eliteLevel or 0

	local parentBounds = LVL_WIDGET.PARENT:GetBounds()
	
	pf.UpdatePlayerLevel(LVL_WIDGET.LEVEL, effectiveLevel, eliteLevel, levelChanged)
	
	LVL_WIDGET.LEVEL:SetLineHeight(parentBounds.height/2.2)
	LVL_WIDGET.ELITE_ICON:SetDims("center-x:_; center-y:_; width:"..(parentBounds.width*1.4).."; height:"..(parentBounds.height/1.1)..";")
	
	LVL_WIDGET.LEVEL:Show(true)
	LVL_WIDGET.ELITE_ICON:Show(showElite)

	local color = "#FFFFFF"
	if showElite then
		color = Component.LookupColor("elite")
	end

	LVL_WIDGET.BG:SetParam("tint", color)
end

-- ------------------------------------------
-- PRIVATE API
-- ------------------------------------------
function pf.UpdatePlayerLevel(GLYPHS, effectiveLevel, eliteLevel, levelChanged)
	local displayLevel = effectiveLevel

	if eliteLevel and eliteLevel > 0 then
		displayLevel = eliteLevel
	end

	GLYPHS:SetText( displayLevel );
end

function pf.UpdateLevelArrow(ARROW, GLYPH, effectiveLevel, currLevel)
	local show_arrow = false

	if effectiveLevel and currLevel and effectiveLevel ~= currLevel and effectiveLevel > 0 then
		show_arrow = true
		if effectiveLevel < currLevel then
			ARROW:SetDims("width:40%; aspect:1.5; top:55%;")
			ARROW:SetRegion("down")
			ARROW:SetParam("tint", "downlevel")
			GLYPH:SetParam("tint", "downlevel")
		else
			ARROW:SetDims("width:40%; aspect:1.5; top:-10%;")
			ARROW:SetRegion("up")
			ARROW:SetParam("tint", "uplevel")
			GLYPH:SetParam("tint", "uplevel")
		end
	else
		GLYPH:SetParam("tint", "white")
	end

	ARROW:Show(show_arrow)

	return show_arrow
end
