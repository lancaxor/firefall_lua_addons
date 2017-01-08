
-- ------------------------------------------
-- lib_Battleframes
--   by: Brian Blose
-- ------------------------------------------
-- function to get commonly used data dealing with battleframes

--[[ Usage:
Ordered Arrays
	archtype_array = Battleframes.GetArchtypeOrder()						--returns the archtype names in an ordered array
	chassisId_array = Battleframes.GetBattleframeOrder()					--returns chassis ids in an ordered array
Battleframe Info
	frameInfo_table = Battleframes.GetFrameInfo(chassisId)					--returns a table of all the following info
	certs_array = Battleframes.GetFrameCerts(chassisId)						--returns the certs that the battleframe grants for use with gear cert requirements
	name = Battleframes.GetFrameName(chassisId)								--returns the battleframe name
	description = Battleframes.GetFrameDescription(chassisId)				--returns the battleframe description
	web_icon = Battleframes.GetFrameWebIcon(chassisId)						--returns the battleframe web_icon url
	web_icon_stem = Battleframes.GetFrameWebIconStem(chassisId)				--returns the battleframe web_icon_stem
	archtype = Battleframes.GetFrameArchtype(chassisId)						--returns the battleframe archtype
--]]

Battleframes = {}
local lf = {}

--require "unicode"
--require "math"
require "table"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_MasterDatabase = {
	{archtype = "berzerker", battleframes = {		--assaults
		{chassisId=76164, certs={732}},					--assault
		{chassisId=76133, certs={733, 732}},			--firecat
		{chassisId=76132, certs={734, 732}},			--tigerclaw
	}},
	{archtype = "bunker", battleframes = {			--engineers
		{chassisId=75775, certs={735}},					--engineer
		{chassisId=76337, certs={736, 735}},			--electron
		{chassisId=76338, certs={737, 735}},			--bastion
	}},
	{archtype = "guardian", battleframes = {		--dreadnaughts
		{chassisId=75772, certs={741}},					--dreadnaught
		{chassisId=76331, certs={742, 741}},			--mammoth 
		{chassisId=76332, certs={743, 741}},			--rhino
		{chassisId=82360, certs={748, 741}},			--arsenal
	}},
	{archtype = "medic", battleframes = {			--biotechs
		{chassisId=75774, certs={738}},					--biotech
		{chassisId=76335, certs={739, 738}},			--dragonfly
		{chassisId=76336, certs={740, 738}},			--recluse
	}},
	{archtype = "recon", battleframes = {			--recons
		{chassisId=75773, certs={744}},					--recon
		{chassisId=76333, certs={745, 744}},			--nighthawk
		{chassisId=76334, certs={746, 744}},			--raptor
	}},
}

local c_ArchtypeOrder = {}
local c_BattleframeOrder = {}
local c_BattleframeInfo = {}

for _, archtype in ipairs(c_MasterDatabase) do
	table.insert(c_ArchtypeOrder, archtype.archtype)
	for _, battleframe in ipairs(archtype.battleframes) do
		table.insert(c_BattleframeOrder, battleframe.chassisId)
		c_BattleframeInfo[battleframe.chassisId] = {certs=battleframe.certs}
	end
end

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Battleframes.GetArchtypeOrder()
	return c_ArchtypeOrder
end

function Battleframes.GetBattleframeOrder()
	return c_BattleframeOrder
end

function Battleframes.GetFrameInfo(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo
end

function Battleframes.GetFrameCerts(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.certs
end

function Battleframes.GetFrameName(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.name
end

function Battleframes.GetFrameDescription(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.description
end

function Battleframes.GetFrameWebIcon(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.web_icon
end

function Battleframes.GetFrameWebIconStem(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.web_icon_stem
end

function Battleframes.GetFrameArchtype(chassisId)
	local frameInfo = lf.GetFrameInfoByChassis(chassisId)
	return frameInfo.archtype
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.GetFrameInfoByChassis(chassisId)
	local id = tonumber(chassisId)
	assert(0 < id and id < 9999999, "Invalid ChassisId") --ensure sdb_id
	local frameInfo = c_BattleframeInfo[id]
	if not frameInfo then
		warn("lib_Battleframes: Received unknown ChassisId '"..id.."'")
		frameInfo = {}
		c_BattleframeInfo[id] = frameInfo
	end
	if not frameInfo.name then
		lf.InitFrameInfo(frameInfo, chassisId)
	end
	return frameInfo
end

function lf.InitFrameInfo(frameInfo, chassisId)
	local itemInfo = Game.GetItemInfoByType(chassisId) or {}
	frameInfo.name = itemInfo.name
	frameInfo.description = itemInfo.description
	frameInfo.web_icon = itemInfo.web_icon
	frameInfo.web_icon_stem = itemInfo.web_icon_stem
	frameInfo.archtype = itemInfo.archtype
end


