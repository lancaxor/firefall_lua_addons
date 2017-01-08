
--
-- PVP Rank Lib
--

-- 
-- If passing in a manual info table, following info should be included if available (will default to 0):
-- level, effective_level, elite_level
--

if PVP_RANK_LIB then
	return
end

PVP_RANK_LIB = {} -- Used for creation of object

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local bp_PVP_BADGE = [[
	<ListLayout name="IconGroup" dimensions="dock:fill" style="horizontal:true; hpadding:2;" >
		<StillArt name="rank" dimensions="top:0; left:0; height:100%; aspect:0.75;" style="texture:PVPRanks; region:rank_0;"/>
		<Text name="rankLabel" dimensions="top:0; left:0; height:100%; width:100%" style="visible:false; font:Demi_10; valign:center; halign:left;" />
	</ListLayout>
]]

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_IconDims = "top:0; left:0; height:100%; width:widthReplace;"

-- Based on what ranks we have textures for
local c_MinValidRank = 1
local c_MaxValidRank = 50

c_IconSizes = {
	default = {
		texture = "PVPRanks",
		aspect = 0.75,
	},

	small = {
		texture = "PVPRanks_Small",
		aspect = 1,
		regionSuffix = "_small"
	}
}

-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local PVP_RANK_API = {} -- Used for object methods
local PVP_RANK_MT = {__index=function(_, inKey) return PVP_RANK_API[inKey] end}

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
-- Entity ID Optional. Will use self if nothing inputted
function PVP_RANK_LIB.CreatePVPBadge(PARENT_, idOrInfo)
	assert(PARENT_, "Must supply a parent widget for CreatePVPBadge")
	
	local WIDGET = Component.CreateWidget(bp_PVP_BADGE, PARENT_)
	local PVP_BADGE_WIDGET = {
		FOCUS = WIDGET,
		PARENT = PARENT_,
		ICON = WIDGET:GetChild("rank"),
		LABEL = WIDGET:GetChild("rankLabel"),
		size = "default",
		showLabel = false,
	}

	if type(idOrInfo) == "number" or type(ifOrInfo) == "table" then
		PVP_BADGE_WIDGET.entityInfo = idOrInfo
	end

	setmetatable(PVP_BADGE_WIDGET, PVP_RANK_MT)

	return PVP_BADGE_WIDGET
end

function PVP_RANK_API.ShowLabel(PVP_WIDGET, show, font, color)
	PVP_WIDGET.showLabel = show

	if font then
		local fontStr = font
		if type(font) == "number" then
			fontStr = "Demi_" .. font
		end 

		PVP_WIDGET.LABEL:SetFont(fontStr)
	end

	if color then
		PVP_WIDGET.LABEL:SetTextColor(color)
	end
end

-- Can make this more generic if more sizes added, but this is easiest for user for now
function PVP_RANK_API.UseSmallIcon(PVP_WIDGET, small)
	PVP_WIDGET.size = small and "small" or "default"
end

function PVP_RANK_API.GetWidth(PVP_WIDGET)
	return PVP_WIDGET.FOCUS:GetBounds().width
end

--call on player ready or future change event
-- Entity ID Optional. Will use entityID given in Create or self if nothing inputted
function PVP_RANK_API.UpdateDisplay(PVP_WIDGET, idOrInfo)
	if type(idOrInfo) == "number" or type(idOrInfo) == "table" then
		PVP_WIDGET.entityInfo = idOrInfo
	end

	if type(PVP_WIDGET.entityInfo) == "table" then
		info = PVP_WIDGET.entityInfo
	else
		local entityID = PVP_WIDGET.entityInfo or Player.GetTargetId()

		info = Game.GetTargetInfo(entityID)
		if info == nil then return end
	end

	local rank = tointeger(info.pvp_rank or 0)
	rank = math.min(c_MaxValidRank, rank)
	rank = math.max(c_MinValidRank, rank)

	if not PVP_WIDGET.size or c_IconSizes[PVP_WIDGET.size] == nil then
		PVP_WIDGET.size = "default"
	end

	local texture = c_IconSizes[PVP_WIDGET.size].texture

	local region = "rank_" .. rank
	local regionSuffix = c_IconSizes[PVP_WIDGET.size].regionSuffix

	if regionSuffix then
		region = region .. regionSuffix
	end

	PVP_WIDGET.ICON:SetTexture(texture, region)
	
	local width = PVP_WIDGET.ICON:GetBounds().height * c_IconSizes[PVP_WIDGET.size].aspect
	PVP_WIDGET.ICON:SetDims(unicode.gsub(c_IconDims, "widthReplace", width))

	if PVP_WIDGET.showLabel then
		PVP_WIDGET.LABEL:SetText(rank)
		local textWidth = PVP_WIDGET.LABEL:GetTextDims().width
		PVP_WIDGET.LABEL:SetDims("left:0; width:" .. textWidth)
	else
		PVP_WIDGET.LABEL:SetDims("width:0")
	end

	PVP_WIDGET.LABEL:Show(PVP_WIDGET.showLabel)

	local groupWidth = PVP_WIDGET.FOCUS:GetContentBounds().width
	PVP_WIDGET.FOCUS:SetDims("top:0; height:100%; center-x:50%; width:" .. groupWidth)
end

function PVP_RANK_API.Show(PVP_WIDGET, show)
	if show == nil then
		show = true
	end

	PVP_WIDGET.FOCUS:Show(show)
end
