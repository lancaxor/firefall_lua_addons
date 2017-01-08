
-- ------------------------------------------
-- lib_Factions
--   by: Michael Weschler
-- ------------------------------------------

if FactionLib then
	return
end
FactionLib = {}

require "math"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_RepColors = {
	[-2]	= "FactionHated",
	[-1]	= "FactionUnfriendly",
	[0]		= "FactionNeutral",
	[1]		= "FactionFriendly",
	[2]		= "FactionExalted",
	[3]		= "FactionAgent",
}

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_Factions = nil

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function FactionLib.GetReputationLevel(factionId, reputation)
	local index = FactionLib.GetReputationLevelIndex(factionId, reputation)
	
	if not g_Factions then
		FactionLib.GetValidFactions()
	end
	
	local factionInfo = g_Factions[factionId]
	assert(factionInfo, "No valid faction found for id "..tostring(factionId))
	local levels = factionInfo.ranges
	assert(type(levels) == "table" and #levels > 0, "Can't get faction reputation level, no ranges!")
	
	return levels[index], levels[index + 1]
end

function FactionLib.GetReputationLevelIndex(factionId, reputation)
	if not g_Factions then
		FactionLib.GetValidFactions()
	end
	
	local factionInfo = g_Factions[factionId]
	assert(factionInfo, "No valid faction found for id "..tostring(factionId))
	local levels = factionInfo.ranges
	assert(type(levels) == "table" and #levels > 0, "Can't get faction reputation level, no ranges!")

	return Game.GetFactionRangeIndex(factionId, reputation)
end

function FactionLib.GetValidFactions()
	if not g_Factions then
		local count = Game.GetFactionCount()

		g_Factions = {}
		
		for i=1, count do
			local info = Game.GetFactionInfo(i)
			g_Factions[tostring(i)] = FactionLib.IsVisibleFaction(info) and info or nil
		end
	end

	return g_Factions
end

function FactionLib.GetReputationLevelPercentage(factionId, reputation)
	local repLevel, nextRepLevel = FactionLib.GetReputationLevel(factionId, reputation)

	local percent = 1
		
	--special case, no positive reputations
	if repLevel.minReputation < 0 and not nextRepLevel then
		nextRepLevel = {minReputation = 0}
	end

	if nextRepLevel then
		percent = (math.abs(reputation) - math.abs(repLevel.minReputation)) / (math.abs(nextRepLevel.minReputation) - math.abs(repLevel.minReputation))
		if reputation < 0 then --negative reputations grow/shrink in reverse
			percent = 1 - percent
		end
	end
	
	return percent
end

function FactionLib.GetReputationAmountString(factionId, reputation)
	local repLevel, nextRepLevel = FactionLib.GetReputationLevel(factionId, reputation)
	
	if not nextRepLevel and repLevel.minReputation < 0 then
		nextRepLevel = {minReputation=0}
	end

	if nextRepLevel then
		local current, target = 0
		if reputation >= 0 then
			current = reputation - repLevel.minReputation
			target = nextRepLevel.minReputation - repLevel.minReputation
		else
			current = math.abs(reputation - nextRepLevel.minReputation)
			target = math.abs(repLevel.minReputation - nextRepLevel.minReputation)
		end
		
		return (_math.MakeReadable(current).."/".._math.MakeReadable(target))
	else
		return Component.LookupText("FACTION_REPUTATION_MAX")
	end
end

function FactionLib.GetReputationColor(factionId, reputation)
	local index = FactionLib.GetReputationLevelIndex(factionId, reputation)

	if not g_Factions then
		FactionLib.GetValidFactions()
	end
	
	local factionInfo = g_Factions[factionId]
	assert(factionInfo, "No valid faction found for id "..tostring(factionId))
	local levels = factionInfo.ranges
	assert(type(levels) == "table" and #levels > 0, "Can't get faction reputation level, no ranges!")
	
	--find minrep 0 or nearest index
	local target = 1
	for i, level in ipairs(levels) do
		if math.abs(level.minReputation) < math.abs(levels[target].minReputation) then
			target = i
		end
	end
	
	--adjust target up one, for all negative reputation ranges
	if factionInfo.ranges[target].minReputation < 0 then
		target = target + 1
	end
	
	local relative = index - target
	local color = c_RepColors[relative]
	if not color then
		color = c_RepColors[0]
	end
	
	return color, relative
end

function FactionLib.IsVisibleFaction(info)
	if type(info) == "string" or type(info) == "number" then
		if not g_Factions then
			FactionLib.GetValidFactions()
		end
		info = g_Factions[tostring(info)]
	end
	
	return type(info) == "table" and type(info.ranges) == "table" and #info.ranges > 0
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------


