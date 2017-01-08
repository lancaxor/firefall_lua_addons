
-------------------------------------------------------------------------------------------------
-- Character Card Library
-- By: Ali Wallick
--
-- Default Display: [LevelBadge] [VIP] [BattleframeIcon] [Army][Name]
--
-- API:
-- CharacterCard = CharCard.CreateCard(PARENT_WIDGET, [idOrInfo, options])
--	- idOrInfo: entityID or table of manual player info
--		- If nothing supplied, will use self
--	- Option Table- table of c_CardOptions indexed numerically based on the visual order. 
--		- If none provided default listed above will be used.
--
-- CharacterCard:UpdateDisplay([idOrInfo])
--	- Optional entity ID or table of info. 
--		- If none supplied, will pull from stored entity ID/info. If no stored ID will use self.
--
-- CharacterCard:GetGroup()
--	- Return the (ListLayout) WIDGET containing the character card widgets
--
-- NOTES:
-- - The widget group will automatically resize itself to the width of the child widgets and is center justified on the x axis 
-- - If passing in a manual info table, following info should be included if available (levels will default to 0, others won't show):
-- 		- LevelBadge: level, effective_level, elite_level
--		- PVP: pvp_rank
--		- VIP: vip_level(BACKEND NOT CURRENTLY IMPLEMENTED!)
--		- Battleframe Icon: frame_icon_id
--		- Name/Army: name (string formatted as "[Army] Name")
--
--
-- TO DO: 
-- - Add ability to change options after creating Card
-- - Remove aspect ratio workaround if/when list layout is fixed
-- - Allow user to specify justification
-- - Allow user to specify font size
-------------------------------------------------------------------------------------------------

if CharCard then
	return
end

CharCard = {}

require "lib/lib_Vip"
require "lib/lib_LevelBadge"
require "lib/lib_PVPRank"

---------------------------------------------------
-- Constants
---------------------------------------------------
c_CardOptions = {
	Level 		= "level",
	Vip 		= "vip",
	Battleframe = "battleframe",
	Army 		= "army",
	Name 		= "name",
	PVPRank 	= "pvp_rank", 
}

local c_DefaultOptions = {c_CardOptions.Level, c_CardOptions.Vip, c_CardOptions.Battleframe, c_CardOptions.Army, c_CardOptions.Name}

local bp_CharCard = [[ <ListLayout name="CardGroup" dimensions="top:0; center-x:50%; width:100%; height:100%" style="horizontal:true; hpadding:3; ignore_other_dim:true" /> ]]
local bp_Options = {
	level 		= [[ <Group name="level" dimensions="left:0; top:0; height:100%; aspect:1.0" /> ]],
	vip 		= [[ <Group name="vip" dimensions="left:0; top:0; height:100%; aspect:1.5"/> ]],
	battleframe = [[ <Icon name="battleframe" dimensions="left:0; top:0; height:100%; aspect:1.0"/> ]],
	army		= [[ <Text name="army" dimensions="left:0; top:0; height:100%; width:10;" style="font:Demi_10; halign:left; valign:center;"/> ]],
	name		= [[ <Text name="name" dimensions="left:0; top:0; height:100%; width:10;" style="font:Demi_10; halign:left; valign:center;"/> ]],
	pvp_rank	= [[ <Group name="pvp_rank" dimensions="left:0; top:0; height:100%; aspect:0.75"/> ]]
}

local c_Aspects = {
	level 		= "1.0",
	vip 		= "1.5",
	battleframe = "1.0",
	pvp_rank	= "0.75",
}

local lf = {}
local CHAR_API = {}
local CHAR_MT = {__index=function(_, key) return CHAR_API[key] end}

---------------------------------------------------
-- Globals
---------------------------------------------------

---------------------------------------------------
-- API
---------------------------------------------------
-- Optional Entity ID or manual table of info. If not given, use self.
-- Optional options, If not use c_DefaultOptions
function CharCard.CreateCard(PARENT_, idOrInfo, options)
	assert(PARENT_, "Must supply a parent widget for CharCard.CreateCard")

	local WIDGET = Component.CreateWidget(bp_CharCard, PARENT_)
	local cardOptions = type(options) == "table" and options or c_DefaultOptions

	local CARD_WIDGET = {
		GROUP = WIDGET,
		PARENT = PARENT_,
		options = cardOptions
	}

	for index, option in pairs(cardOptions) do
		if bp_Options[option] then
			CARD_WIDGET[option] = Component.CreateWidget(bp_Options[option], WIDGET)
		else
			warn("lib_CharCard: Invalid Character Card Option")
		end
	end

	if type(idOrInfo) == "number" or type(ifOrInfo) == "table" then
		CARD_WIDGET.entityInfo = idOrInfo
	end

	setmetatable(CARD_WIDGET, CHAR_MT)

	CARD_WIDGET:SetupBadges()

	return CARD_WIDGET
end

function CHAR_API.GetGroup(CARD_WIDGET)
	return CARD_WIDGET.GROUP
end

function CHAR_API.GetElement(CARD_WIDGET, element)
	if not CARD_WIDGET[element] then
		warn("Element (" .. tostring(element) .. ") does not exist within CARD_WIDGET")
	end

	-- Specific cases for lib elements
	local BADGE
	if element == c_CardOptions.Level then
		BADGE = CARD_WIDGET.LEVEL_BADGE
	elseif element == c_CardOptions.Vip then
		BADGE = CARD_WIDGET.PVP_BADGE
	elseif element == c_CardOptions.PVPRank then
		BADGE = CARD_WIDGET.PVP_BADGE
	end

	return (BADGE or CARD_WIDGET[element])
end

function CHAR_API.SetupBadges(CARD_WIDGET)
	local LEVEL = CARD_WIDGET["level"]
	if LEVEL and not CARD_WIDGET.LEVEL_BADGE then
		CARD_WIDGET.LEVEL_BADGE = LVL_BADGE_LIB.CreateLevelBadge(LEVEL)
	end

	local VIP = CARD_WIDGET["vip"]
	if VIP and not CARD_WIDGET.VIP_BADGE then
		CARD_WIDGET.VIP_BADGE = VIPLIB.CreateVIPBadge(VIP)
	end

	local PVP = CARD_WIDGET["pvp_rank"]
	if PVP and not CARD_WIDGET.PVP_BADGE then
		CARD_WIDGET.PVP_BADGE = PVP_RANK_LIB.CreatePVPBadge(PVP)
	end
end

-- Optional Entity ID or manual table of info. If not given, use info from Create or self.
function CHAR_API.UpdateDisplay(CARD_WIDGET, idOrInfo)
	
	if type(idOrInfo) == "number" or type(idOrInfo) == "table" then
		CARD_WIDGET.entityInfo = idOrInfo
	end
	
	local info
	if type(CARD_WIDGET.entityInfo) == "table" then
		info = CARD_WIDGET.entityInfo
	else
		local entityID = CARD_WIDGET.entityInfo or Player.GetTargetId() -- get self if nil

		info = Game.GetTargetInfo(entityID)
		if info == nil then return end
	end

	CARD_WIDGET:SetupBadges()

	local LEVEL = CARD_WIDGET["level"]
	if LEVEL then
		CARD_WIDGET.LEVEL_BADGE:UpdateDisplay(info)
		lf.SetWidthOnAspect(LEVEL, "level")
	end

	local VIP = CARD_WIDGET["vip"]
	if VIP then
		CARD_WIDGET.VIP_BADGE:UpdateDisplay(info)
		lf.SetWidthOnAspect(VIP, "vip")
	end

	local PVP = CARD_WIDGET["pvp_rank"]
	if PVP then
		CARD_WIDGET.PVP_BADGE:UpdateDisplay(info)
		PVP:SetDims("left:0; width:" .. CARD_WIDGET.PVP_BADGE:GetWidth() )
	end

	local BATTLEFRAME = CARD_WIDGET.GROUP:GetChild("battleframe")
	if BATTLEFRAME then
		if info.frame_icon_id then
			BATTLEFRAME:SetIcon(info.frame_icon_id)
		end
		BATTLEFRAME:Show(info.frame_icon_id ~= nil)
		BATTLEFRAME:SetDims("top:0; left:0;")
		lf.SetWidthOnAspect(BATTLEFRAME, "battleframe")
	end

	local army = unicode.match(info.name, "^(%[.+%])")
	local ARMY = CARD_WIDGET.GROUP:GetChild("army")
	if ARMY then
		if army then
			ARMY:SetText(army)
			local armyWidth = ARMY:GetTextDims().width
			ARMY:SetDims("width:" .. armyWidth)
		end

		ARMY:Show(army ~= nil)
	end

	local name = unicode.match(info.name, "%s?([^%[%]]+)$")
	local NAME = CARD_WIDGET.GROUP:GetChild("name")
	if NAME then
		if name then
			NAME:SetText(name)
			local nameWidth = NAME:GetTextDims().width
			NAME:SetDims("width:" .. nameWidth)
		end

		NAME:Show(name ~= nil)
	end

	local width = CARD_WIDGET.GROUP:GetContentBounds().width
	CARD_WIDGET.GROUP:SetDims("center-x:50%; width:" .. width)
end

function CHAR_API.SetNameColor(CARD_WIDGET, color)
	local NAME = CARD_WIDGET.GROUP:GetChild("name")
	if NAME then
		NAME:SetTextColor(color)
	end
	local ARMY = CARD_WIDGET.GROUP:GetChild("army")
	if ARMY then
		ARMY:SetTextColor(color)
	end
end

function CHAR_API.SetNameFont(CARD_WIDGET, font)
	local NAME = CARD_WIDGET.GROUP:GetChild("name")
	if NAME then
		NAME:SetFont(font)
	end
	local ARMY = CARD_WIDGET.GROUP:GetChild("army")
	if ARMY then
		ARMY:SetFont(font)
	end
end

function CHAR_API.SetBattleframeTint(CARD_WIDGET, tint)
	local BFRAME = CARD_WIDGET.GROUP:GetChild("battleframe")
	if BFRAME then
		BFRAME:SetParam("tint", tint)
	end
end

---------------------------------------------------
-- Private Functions
---------------------------------------------------
-- Hackery to get around ListLayout issues with aspect ratio
function lf.SetWidthOnAspect(WIDGET, index)
	local width = WIDGET:GetBounds().height * c_Aspects[index]
	WIDGET:SetDims("width:" .. width)
end
