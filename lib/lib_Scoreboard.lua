
--
-- Scoreboard Team Lib **Used to create a customized team widget for a scoreboard**
--
require "math"
require "lib/lib_ScoreboardTeam"

if SCOREBOARD_LIB then
	return
end

-- ------------------------------------------
-- GLOBALS
-- ------------------------------------------
SCOREBOARD_LIB = {} -- Used for creation of object

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_initNumDefaultVisibleRows = 6
local c_initMaxNumPlayers = 12

local c_RankPointScore = 10045
local c_PointsScored   = 10067
local c_Assists        = 10075
local c_Steals         = 10079
local c_ShotBlocks     = 10080
local c_Kills          = 10007
local c_HealingDealt   = 10026

local c_RoundsSurvived     = 10174
local c_NumTimesAsSoldier  = 10170
local c_SurvivalTime       = 10153
local c_TotalConverted 	   = 10259

local c_Deaths       = 10009
local c_KDR          = 10006
local c_KillAssists  = 10107
local c_DamageDealt  = 10033

local c_GameTypeNames = {
	["Jetball"] = "SCORE_JETBALL_MODE",
	["Hunter"] = "SCORE_HUNTER_MODE",
	["TDM"] = "SCORE_TDM_MODE",
	["FFA"] = "SCORE_FFA_MODE",
}

local c_ColumnHeaders = {
	["Jetball"]			= {{"SCORE_RANK", "SCORE_POINTS_SCORED", "SCORE_ASSISTS", "SCORE_STEALS", "SCORE_SHOTBLOCKS", "SCORE_KILLS", "SCORE_HEALING_DEALT"},
						   {"SCORE_RANK", "SCORE_POINTS_SCORED", "SCORE_ASSISTS", "SCORE_STEALS", "SCORE_SHOTBLOCKS", "SCORE_KILLS", "SCORE_HEALING_DEALT"}},
	["Hunter"]			= {{"SCORE_RANK", "SCORE_ROUNDS_SURVIVED", "SCORE_SURVIVAL_TIME", "SCORE_DAMAGE_DEALT", "SCORE_SOLDIER_TIMES", "SCORE_TOTAL_CONVERTED"},
					       {"SCORE_RANK", "SCORE_ROUNDS_SURVIVED", "SCORE_SURVIVAL_TIME", "SCORE_DAMAGE_DEALT", "SCORE_SOLDIER_TIMES", "SCORE_TOTAL_CONVERTED"}},
	["TDM"]				= {{"SCORE_RANK", "SCORE_KILLS_DEATHS", "SCORES_KD_RATIO", "SCORE_KILL_ASSISTS", "SCORE_DAMAGE_DEALT", "SCORE_HEALING_DEALT"},
					       {"SCORE_RANK", "SCORE_KILLS_DEATHS", "SCORES_KD_RATIO", "SCORE_KILL_ASSISTS", "SCORE_DAMAGE_DEALT", "SCORE_HEALING_DEALT"}},
	["FFA"]				= {{"SCORE_RANK", "SCORE_KILLS_DEATHS", "SCORES_KD_RATIO", "SCORE_DAMAGE_DEALT"}},
}

local c_DefaultStats = {
	["Jetball"]			= {{"0", "0", "0", "0", "0", "0", "0"},
						   {"0", "0", "0", "0", "0", "0", "0"}},
	["Hunter"]			= {{"0", "0", "0", "0", "0", "0"},
					       {"0", "0", "0", "0", "0", "0"}},
	["TDM"]				= {{"0", "0/0", "0.00", "0", "0", "0"},
					       {"0", "0/0", "0.00", "0", "0", "0"}},
	["FFA"]				= {{"0", "0/0", "0.00", "0"}},
}

local c_StatLookup = {
	["Jetball"]			= {{[c_RankPointScore] = 1,
							[c_PointsScored]   = 2,
							[c_Assists]        = 3,
							[c_Steals]         = 4,
							[c_ShotBlocks]     = 5,
							[c_Kills]          = 6,
							[c_HealingDealt]   = 7,},
						   {[c_RankPointScore] = 1,
							[c_PointsScored]   = 2,
							[c_Assists]        = 3,
							[c_Steals]         = 4,
							[c_ShotBlocks]     = 5,
							[c_Kills]          = 6,
							[c_HealingDealt]   = 7,}},
							
	["Hunter"]			= {{[c_RankPointScore]     = 1,
							[c_RoundsSurvived]     = 2,
							[c_SurvivalTime]       = 3,
							[c_DamageDealt]        = 4,
							[c_NumTimesAsSoldier]  = 5,
							[c_TotalConverted]     = 6,},
					       {[c_RankPointScore]     = 1,
							[c_RoundsSurvived]     = 2,
							[c_SurvivalTime]       = 3,
							[c_DamageDealt]        = 4,
							[c_NumTimesAsSoldier]  = 5,
							[c_TotalConverted]     = 6,}},
							
	["TDM"]				= {{[c_RankPointScore] = 1,
							[c_Kills]          = 2,
							[c_Deaths]         = 2,
							[c_KDR]            = 3,
							[c_KillAssists]    = 4,
							[c_DamageDealt]    = 5,
							[c_HealingDealt]   = 6,},
					       {[c_RankPointScore] = 1,
							[c_Deaths]         = 2,
							[c_Kills]          = 2,
							[c_KDR]            = 3,
							[c_KillAssists]    = 4,
							[c_DamageDealt]    = 5,
							[c_HealingDealt]   = 6,}},
							
	["FFA"]				= {{[c_RankPointScore] = 1,
							[c_Kills]          = 2,
							[c_Deaths]         = 2,
							[c_KDR]            = 3,
							[c_DamageDealt]    = 4,}},
}
-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local SCOREBOARD_API = {} -- Used for object methods
local SCOREBOARD_MT = {__index=function(_, inKey) return SCOREBOARD_API[inKey] end}

local g_GameType = nil
local g_TEAM_PARENTS = {}

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
function SCOREBOARD_LIB.CreateScoreboard(args)
	g_GameType = args.gametype
	g_TEAM_PARENTS = args.PARENTS
	
	if not g_GameType or not g_TEAM_PARENTS then return end
	
	local numColHeaders = #c_ColumnHeaders[g_GameType][1]
	local maxNumColHeaderKeys = numColHeaders
	for i, _ in ipairs(c_ColumnHeaders[g_GameType]) do
		numColHeaders = #c_ColumnHeaders[g_GameType][i]
		local nextNumColHeaders = 0
		if c_ColumnHeaders[g_GameType][i+1] then
			nextNumColHeaders = #c_ColumnHeaders[g_GameType][i+1]
			maxNumColHeaderKeys = numColHeaders > nextNumColHeaders and numColHeaders or nextNumColHeaders
		end
	end
	
	local numTeams = #c_ColumnHeaders[g_GameType]	
	local teamArgs = {}

	for i=1, numTeams, 1 do
		local standardArgs = {
			disabledStatColIds = nil,
			parent = g_TEAM_PARENTS[i],
			teamName = args.teamNames[i],
			teamIcon = args.teamIcons[i],
			columnHeaderKeys = c_ColumnHeaders[g_GameType][i],
			showBFIcon = false,
			numDefaultVisibleRows = c_initNumDefaultVisibleRows,
			maxNumPlayers = c_initMaxNumPlayers,
			maxNumColumnHeaders = maxNumColHeaderKeys,
			enablePvPRankIcon = true,
			enableBFIcon = true,
		}
		
		if g_GameType == "Hunter" then
			standardArgs.enableBFIcon = false
			standardArgs.disabledStatColIds = i == 1 and {6} or {2, 3, 4, 5}
		elseif g_GameType == "FFA" then
			standardArgs.teamName = nil
			standardArgs.teamIcon = nil
			standardArgs.numDefaultVisibleRows = 12
		end
		
		if args.hideDisabledStatCol then
			standardArgs.disabledStatColIds = nil
		end
	
		table.insert(teamArgs, standardArgs)
	end
	
	local SCOREBOARD_WIDGET = {
		TEAM_WIDGETS = SCOREBOARD_TEAM_LIB.CreateScoreboardTeams(teamArgs),
	}
	setmetatable(SCOREBOARD_WIDGET, SCOREBOARD_MT)
	
	return SCOREBOARD_WIDGET
end
function SCOREBOARD_LIB.SetStatOffsets(left_offset, right_offset)
	SCOREBOARD_TEAM_LIB.SetStatOffsets(left_offset, right_offset)
end
function SCOREBOARD_API.AddPlayer(WIDGET, playerName, teamId, pvpRank, battleframeId)	if (not g_GameType) then return end
	
	teamId = tonumber(teamId)
	if g_GameType == "FFA" then -- ignore team ids for free-for-all since they'll be passing multiple different team ids even though there's only one team
		teamId = 1
	end

	local defaultStats = c_DefaultStats[g_GameType][teamId]
	if WIDGET.TEAM_WIDGETS and #WIDGET.TEAM_WIDGETS > 0 then
		defaultStats["name"] = playerName -- swap out the default name with the player's name
		defaultStats["pvpRank"] = pvpRank
		defaultStats["battleframeId"] = battleframeId
		WIDGET.TEAM_WIDGETS[teamId]:AddPlayer(defaultStats, c_IsStaticScoreboard) --todo: don't pass default stats, instead pass Player.GetScoreboard stats once we're able to get all stats from Player.GetScoreboard()
	end
end

function SCOREBOARD_API.UpdateTeamColors(WIDGET, teamColors)
	if WIDGET.TEAM_WIDGETS and teamColors and #teamColors > 0 and #WIDGET.TEAM_WIDGETS > 0 then
		-- other players in the scoreboard are not shown with the team color in FFA
		local overrideColor = g_GameType == "FFA" and teamColors[2] or nil 
		
		for i=1, #WIDGET.TEAM_WIDGETS, 1 do
			WIDGET.TEAM_WIDGETS[i]:SetPlayerContentOverrideColor(overrideColor)
			WIDGET.TEAM_WIDGETS[i]:SetTeamColor(teamColors[i], g_GameType)
		end
	end
end

function SCOREBOARD_API.SyncWithWeb(WIDGET)
	local initData = Player.GetScoreBoard()
	if initData then
		for i=1, #initData, 1 do
			local dataInfo = initData[i]
			if dataInfo then
				local playerName = dataInfo.name
				local targetId = Game.GetTargetIdByName(playerName)
				local teamId = tonumber(initData[i].teamId)
				
				if g_GameType == "FFA" then -- ignore team ids for free-for-all since they'll be passing multiple different team ids even though there's only one team
					teamId = 1
				end

				if playerName and teamId then
					WIDGET:AddPlayer(playerName, teamId, dataInfo.pvp_rank, dataInfo.battleframe_id)
				end
					
				-- loop through the stat ids for the current game type
				local scoreboardStats = c_StatLookup[g_GameType][teamId]
				
				for statId, statColIdx in pairs(scoreboardStats) do
					local newStatVal = dataInfo.stats[statId]
					if newStatVal then
						--newStatVal = pf.ApplySpecialFormatting(playerName, teamId, statId, tonumber(newStatVal))
						if (g_GameType == "TDM" or g_GameType == "FFA") and (statId == c_Deaths or statId == c_Kills) then
							newStatVal = dataInfo.stats[c_Kills].."/"..dataInfo.stats[c_Deaths]
							
							-- calculate and set new kdr
							local kills = dataInfo.stats[c_Kills]
							local deaths = dataInfo.stats[c_Deaths]
							local kdrVal = kills / (deaths <= 0 and 1 or deaths)
							WIDGET.TEAM_WIDGETS[teamId]:SetPlayerStat(playerName, c_StatLookup[g_GameType][teamId][c_KDR], math.floor((kdrVal * 100) + .5)  * .01)
						end
						
						WIDGET.TEAM_WIDGETS[teamId]:SetPlayerStat(playerName, statColIdx, newStatVal)
					end
				end
			end
		end
	end
	WIDGET:UpdateTeamColors(g_TeamColors)
end

function SCOREBOARD_API.RemovePlayer(WIDGET, playerName, teamId)
	if (not g_GameType) then return end
	
	if WIDGET.TEAM_WIDGETS and #WIDGET.TEAM_WIDGETS > 0 then
		if g_GameType == "FFA" then -- ignore team ids for free-for-all since they'll be passing multiple different team ids even though there's only one team
			teamId = 1
		end
		WIDGET.TEAM_WIDGETS[tonumber(teamId)]:RemovePlayer(playerName)
	end
end

function SCOREBOARD_API.ClearScoreboard(WIDGET)
	for i=1, #WIDGET.TEAM_WIDGETS, 1 do
		WIDGET.TEAM_WIDGETS[i]:ResetTeam()
	end
end

function SCOREBOARD_API.SetStat(WIDGET, playerName, teamId, statId, statVal)
	if (not g_GameType) then return end;
	
	if g_GameType == "FFA" then -- ignore team ids for free-for-all since they'll be passing multiple different team ids even though there's only one team
		teamId = 1
	end
	
	local statSubStrIndex = (unicode.find(tostring(statId), ":") or 0) + 1
	statId = tonumber(unicode.sub(tostring(statId), statSubStrIndex))
	teamId = tonumber(teamId)
	local statTrackedId = c_StatLookup[g_GameType][teamId][statId]
	
	if statTrackedId then
		statTrackedId = tonumber(statTrackedId)
		if type(statVal) == "number" then
			if statId == c_SurvivalTime then
				local TIMER_WIDGET = WIDGET.TEAM_WIDGETS[teamId]:GetPlayerStatWidget(playerName, "Timer")
				TIMER_WIDGET:StartTimer(statVal)
				TIMER_WIDGET:StopTimer()
			else
				WIDGET.TEAM_WIDGETS[teamId]:AddPlayerStat(playerName, statTrackedId, statVal)
			end
		else
			WIDGET.TEAM_WIDGETS[teamId]:SetPlayerStat(playerName, statTrackedId, statVal)
		end
	end
end
