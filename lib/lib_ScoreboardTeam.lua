
--
-- Scoreboard Team Lib **Used to create a customized team widget for a scoreboard**
--
require "lib/lib_ScoreboardPlayer"
require "lib/lib_Colors"

if SCOREBOARD_TEAM_LIB then
	return
end

-- ------------------------------------------
-- GLOBALS
-- ------------------------------------------
SCOREBOARD_TEAM_LIB = {} -- Used for creation of object

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local SCOREBOARD_TEAM_BP = [[
	<Group name="HeaderGroup" dimensions="center-x:50%; center-y:130; height:70; width:954" >
		<StillArt name="HeaderBG" dimensions="dock:fill" style="texture:colors; region:white; alpha:0.1; eatsmice:false;"/>
		<StillArt name="Icon" dimensions="center-x:50%; center-y:50%; height:35; width:35" style="texture:SurvivorIcon;"/>
		<Text name="TeamName" dimensions="center-x:_; center-y:_; height:_; width:_" style="font:Demi_16; alpha:1; drop-shadow:true;"/>
		<StillArt name="Line" dimensions="center-x:_; center-y:_; height:3; width:893" style="texture:colors; region:white; alpha:1;"/>
		<Group name="ColumnHeaderGroup" dimensions="dock:fill"/>
	</Group>
]]

local COLUMN_HEADER_BP = [[
	<Text dimensions="center-x:_; center-y:_; height:_; width:80" style="font:Demi_10; halign:center; color:B2B2B2; wrap:true; alpha:1; drop-shadow:true;"/>
]]

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_ScoreFormat = "%03d"

local c_LineWidth = 893
local c_LineWidthNoIcon = 960

local c_IconLeftOffset = 9
local c_IconTopOffset = 7
local c_ColHeaderTopOffset = 13

local c_ColHeaderLeftOffsetDefault = 395
local c_FinalColHeaderOffsetDefault = 897

-- used for spacing the team name along the left axis
local c_DistanceFromIcon = 18
local c_DistanceWithoutIcon = 15

local c_BankNumColHeaders = 7

local c_TeamWidthOffset = 30
local c_TeamPanelAlignOffset = -4
local c_DistanceBetweenTeams = 20

-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local SCOREBOARD_TEAM_API = {} -- Used for object methods
local BANK_COL_HEADER_WIDGETS = {}
local SCOREBOARD_TEAM_MT = {__index=function(_, inKey) return SCOREBOARD_TEAM_API[inKey] end}

local g_NameLeftOffset = 67
local g_NameTopOffset = 15

local g_LineLeftOffset = 67
local g_LineTopOffset = 50


local g_DistanceBetweenColHeaders = nil

local g_PLAYER_WIDGETS = {}
local g_TEAM_WIDGETS = {}

local g_ColHeaderLeftOffset = c_ColHeaderLeftOffsetDefault
local g_FinalColHeaderOffset = c_FinalColHeaderOffsetDefault

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
function SCOREBOARD_TEAM_LIB.CreateScoreboardTeams(teamArgs)
	local numTeamArgs = #teamArgs
	if numTeamArgs <= 0 then return end

	for idx,args in ipairs(teamArgs) do		
		local HEADER_WIDGET = pf.InitTeamHeaderData(args.parent, args)
		
		-- set column header names and spacing
		pf.SetColHeaders(args.maxNumColumnHeaders, args.columnHeaderKeys, HEADER_WIDGET.HEADER_BG)
		
		-- store opposing team indexes
		if numTeamArgs > 1 then
			for i=1, numTeamArgs, 1 do
				if i ~= idx then
					table.insert(HEADER_WIDGET.enemyTeamIndexes, i)
				end
			end
		end
		
		local columnHeaderArgs = {
			["numColHeaders"] = #args.columnHeaderKeys,
			["maxNumColHeaders"] = c_BankNumColHeaders,
			["colHeaderOffset"] = g_ColHeaderLeftOffset,
			["distBetweenColHeaders"] = g_DistanceBetweenColHeaders,
		}
		pf.CreateMaxPlayers(HEADER_WIDGET, args.maxNumPlayers, columnHeaderArgs, args)
		
		SCOREBOARD_TEAM_API.SetTeamName(HEADER_WIDGET, args.teamName and Component.LookupText(args.teamName) or nil)
		SCOREBOARD_TEAM_API.SetTeamIcon(HEADER_WIDGET, args.teamIcon)
		
		g_TEAM_WIDGETS[idx] = HEADER_WIDGET
	end
	
	pf.AdjustTeamPanelOffsets()
	
	return g_TEAM_WIDGETS
end

function SCOREBOARD_TEAM_LIB.SetStatOffsets(left_offset, right_offset)

	--replace nil arguments with default values and return early if no changes need to be made
	left_offset = left_offset or c_ColHeaderLeftOffsetDefault
	right_offset = right_offset or c_FinalColHeaderOffsetDefault
	if left_offset == g_ColHeaderLeftOffset and right_offset == g_FinalColHeaderOffset then
		return
	end

	g_ColHeaderLeftOffset = left_offset
	g_FinalColHeaderOffset = right_offset

	for _, team in pairs(g_TEAM_WIDGETS) do
		--update header positions
		pf.UpdateColHeadersDims(team.COL_HEADER_GROUP)

		--update players' stats positions
		for _, player in pairs(team.PLAYERS) do
			player:SetStatOffsets(g_ColHeaderLeftOffset, g_DistanceBetweenColHeaders)
		end
	end

end

function SCOREBOARD_TEAM_API.SetTeamIcon(WIDGET, teamIcon)
	if teamIcon then
		pf.EnableIconMode(WIDGET, true)
		WIDGET.ICON:SetTexture("PVPAssets", teamIcon)		
	else
		pf.EnableIconMode(WIDGET, false)
	end
end

function SCOREBOARD_TEAM_API.SetPlayerContentOverrideColor(WIDGET, overrideColor)
	WIDGET.playerOverrideColor = overrideColor
end

function SCOREBOARD_TEAM_API.SetTeamColor(WIDGET, teamColor)
	WIDGET.HEADER_BG:SetParam("tint", teamColor)
	WIDGET.LINE:SetParam("tint", teamColor)
	WIDGET.TEAM_NAME_TEXT:SetParam("color", teamColor)
	Colors.MatchColorOnWidget(WIDGET.ICON, "F97B00", teamColor)
		
	for i=1, #WIDGET.PLAYERS, 1 do
		WIDGET.PLAYERS[i]:SetColor(teamColor, WIDGET.playerOverrideColor and WIDGET.playerOverrideColor or nil, WIDGET.disabledStatColIds and WIDGET.disabledStatColIds or nil)
	end
end

function SCOREBOARD_TEAM_API.SetTeamName(WIDGET, teamName)
	WIDGET.teamName = teamName
	UpdateTeamNameAndScore(WIDGET)
end

function SCOREBOARD_TEAM_API.SetTeamScore(WIDGET, score)
	WIDGET.teamScore = score
	UpdateTeamNameAndScore(WIDGET)
end

function SCOREBOARD_TEAM_API.IncTeamScore(WIDGET)
	WIDGET.teamScore = WIDGET.teamScore + 1
	UpdateTeamNameAndScore(WIDGET)
end

function SCOREBOARD_TEAM_API.DecTeamScore(WIDGET)
	WIDGET.teamScore = WIDGET.teamScore - 1
	UpdateTeamNameAndScore(WIDGET)
end

function SCOREBOARD_TEAM_API.HideOne(WIDGET)
	WIDGET.PLAYERS[WIDGET.maxNumDefaultVisible - WIDGET.currNumHidden]:HidePlayer()
	WIDGET.currNumHidden = WIDGET.currNumHidden + 1
end

function SCOREBOARD_TEAM_API.UnhideOne(WIDGET)
	WIDGET.currNumHidden = WIDGET.currNumHidden - 1
	WIDGET.PLAYERS[WIDGET.maxNumDefaultVisible - WIDGET.currNumHidden]:ShowPlayer()
	WIDGET.PLAYERS[WIDGET.maxNumDefaultVisible - WIDGET.currNumHidden]:HideContent()
end

function SCOREBOARD_TEAM_API.AddPlayer(WIDGET, rowStats, isStaticScoreboard)
	local i = 1
	
	if WIDGET.numActivePlayers > 0 and WIDGET.numActivePlayers < WIDGET.maxNumPlayers then
		while (tonumber(WIDGET.PLAYERS[i]:GetStat(1)) >= tonumber(rowStats[1])) and i <= WIDGET.numActivePlayers do
			i = i + 1
		end
		
		-- loop until we get to the end, swapping along the way
		while i <= WIDGET.numActivePlayers do
			local tempStoredStats = WIDGET.PLAYERS[i]:GetAllStats()
			tempStoredStats = WIDGET.PLAYERS[i]:GetAllStats()
			WIDGET.PLAYERS[i]:SetAllStats(rowStats)
			rowStats = tempStoredStats
			i = i + 1
		end
	end
	-- append to the empty slot at the end of the player list
	WIDGET.PLAYERS[i]:SetAllStats(rowStats)
	WIDGET.PLAYERS[i]:ShowPlayer()
	
	WIDGET.numActivePlayers = WIDGET.numActivePlayers + 1
	
	if WIDGET.numActivePlayers > WIDGET.maxNumDefaultVisible then
		-- remove from other widget
		g_TEAM_WIDGETS[WIDGET.enemyTeamIndexes[1]]:HideOne() -- todo determine which opposing team to remove a row from to add to this teams rows
	end
	
	if not isStaticScoreboard then -- don't adjust the positioning of the scoreboard, if it's a static scoreboard where the rows and data don't move/change
		pf.AdjustTeamPanelOffsets()
	end
end

function SCOREBOARD_TEAM_API.RemovePlayer(WIDGET, playerName)
	local foundIndex = pf.FindIndexPlayerWidgetByName(WIDGET, playerName)
	
	if foundIndex then
		local currIndex = foundIndex
		local nextIndex = currIndex + 1
		assert( WIDGET.numActivePlayers <= #WIDGET.PLAYERS, "numActivePlayers("..tostring(WIDGET.numActivePlayers)..") is greater than widgets in WIDGET.PLAYERS "..tostring(#WIDGET.PLAYERS))
		assert( #WIDGET.enemyTeamIndexes >= 1, "Expected at least one enemyTeamIndexes")
		assert(#g_TEAM_WIDGETS >= WIDGET.enemyTeamIndexes[1], "First enemyTeamIndexes does not match g_TEAM_WIDGETS count!")
		-- push all other players up so that there are no gaps on the scoreboard when removing a player
		while currIndex <= WIDGET.numActivePlayers and nextIndex <= #WIDGET.PLAYERS do
			local tempStoredStats = WIDGET.PLAYERS[nextIndex]:GetAllStats()
			WIDGET.PLAYERS[currIndex]:SetAllStats(tempStoredStats)
			currIndex = currIndex + 1
			nextIndex = nextIndex + 1
		end
		
		-- hide an entire colored column if necessary, otherwise just hide the content in the column instead of the entire column
		if WIDGET.numActivePlayers > WIDGET.maxNumDefaultVisible then
			WIDGET.PLAYERS[WIDGET.numActivePlayers]:HidePlayer()
			g_TEAM_WIDGETS[WIDGET.enemyTeamIndexes[1]]:UnhideOne() -- todo determine which opposing team to remove a row from to add to this teams rows
		else
			WIDGET.PLAYERS[WIDGET.numActivePlayers]:HideContent()
		end
		
		WIDGET.numActivePlayers = WIDGET.numActivePlayers - 1
		
		pf.AdjustTeamPanelOffsets()
	end
end

function SCOREBOARD_TEAM_API.SetPlayerStat(WIDGET, playerName, statIdx, newStatVal)
	local currIndex = pf.FindIndexPlayerWidgetByName(WIDGET, playerName)
	if not currIndex then return nil end
	WIDGET.PLAYERS[currIndex]:SetStat(statIdx, newStatVal)
	
	if statIdx == 1 then
		pf.SortByRankPointScore(WIDGET, currIndex, newStatVal)
	end
end

function SCOREBOARD_TEAM_API.GetPlayerStatWidget(WIDGET, playerName, statIdx)
	local currIndex = pf.FindIndexPlayerWidgetByName(WIDGET, playerName)
	if not currIndex then return nil end
	
	if statIdx == "Timer" then
		return WIDGET.PLAYERS[currIndex].TIMER
	end
	
	return WIDGET.PLAYERS[currIndex]:GetStatWidget(statIdx)
end

function SCOREBOARD_TEAM_API.AddPlayerStat(WIDGET, playerName, statIdx, newStatVal)
	local currIndex = pf.FindIndexPlayerWidgetByName(WIDGET, playerName)
	if not currIndex then return nil end
	newStatVal = newStatVal + tonumber(WIDGET.PLAYERS[currIndex]:GetStat(statIdx))
	WIDGET.PLAYERS[currIndex]:SetStat(statIdx, newStatVal)
	
	if statIdx == 1 then
		pf.SortByRankPointScore(WIDGET, currIndex, newStatVal)
	end
end

function SCOREBOARD_TEAM_API.ResetTeam(WIDGET)
	for i=1, WIDGET.numActivePlayers, 1 do
		WIDGET:RemovePlayer(WIDGET.PLAYERS[i]:GetStat("name"))
	end
	WIDGET:SetTeamScore(0)
end

function SCOREBOARD_TEAM_API.RefreshSquadTrackingTriangles(WIDGET)
	if not Squad.GetRoster() then return end
	
	for i=1, WIDGET.numActivePlayers, 1 do
		local playerName = WIDGET.PLAYERS[i]:GetStat("name")
		local shouldDisplayTriangle = Squad.GetIndexOf(playerName) and 1 or 0
		WIDGET.PLAYERS[i].WHITE_TRIANGLE:SetParam("alpha", shouldDisplayTriangle)
	end
end

-- ------------------------------------------
-- PRIVATE API
-- ------------------------------------------
function pf.SortByRankPointScore(WIDGET, currIndex, newStatVal)
	local oldStatVal = tonumber(WIDGET.PLAYERS[currIndex]:GetStat(1))
	if newStatVal > oldStatVal then -- going up
		local prev = currIndex - 1
		while prev > 0 and tonumber(WIDGET.PLAYERS[prev]:GetStat(1)) < newStatVal do
			pf.SwapPlayers(WIDGET, currIndex, prev)
			currIndex = prev
			prev = prev - 1
		end
	elseif newStatVal < oldStatVal then -- going down
		local next = currIndex + 1
		while next <= WIDGET.numActivePlayers and tonumber(WIDGET.PLAYERS[next]:GetStat(1)) > newStatVal do
			pf.SwapPlayers(WIDGET, currIndex, next)
			currIndex = next
			next = next + 1
		end
	end
end

function pf.AdjustTeamPanelOffsets()
	local panelOffset = 0
	local originOffset = g_TEAM_WIDGETS[1].PARENT:GetBounds()
	for i=1, #g_TEAM_WIDGETS - 1, 1 do
		local CURR_WIDGET = g_TEAM_WIDGETS[i]
		local ENEMY_WIDGET = g_TEAM_WIDGETS[CURR_WIDGET.enemyTeamIndexes[1]]
		local rowHeight = CURR_WIDGET.PLAYERS[1].CURR_CENTER:GetBounds().height
		
		local panelOffset = panelOffset + CURR_WIDGET.HEADER_BG:GetBounds().height + c_TeamPanelAlignOffset + c_DistanceBetweenTeams
		if CURR_WIDGET.numActivePlayers >= 0 and CURR_WIDGET.numActivePlayers <= CURR_WIDGET.maxNumDefaultVisible then
			panelOffset = panelOffset + (rowHeight * (CURR_WIDGET.maxNumDefaultVisible - CURR_WIDGET.currNumHidden))
		elseif CURR_WIDGET.numActivePlayers > CURR_WIDGET.maxNumDefaultVisible then
			panelOffset = panelOffset + (rowHeight * CURR_WIDGET.numActivePlayers)
		end
		g_TEAM_WIDGETS[i+1].PARENT:SetDims("left:_; top:"..(originOffset.top + panelOffset).."; width:_; height:_;")
	end
end

function pf.SwapPlayers(WIDGET, index1, index2)
	local stored1 = WIDGET.PLAYERS[index1]:GetAllStats()
	local stored2 = WIDGET.PLAYERS[index2]:GetAllStats()
	
	WIDGET.PLAYERS[index1]:SetAllStats(stored2)
	WIDGET.PLAYERS[index2]:SetAllStats(stored1)
end

function pf.InitTeamHeaderData(PARENT_, teamArgs)
	local WIDGET = pf.CreateWidgetFromBP(PARENT_, teamArgs)
	pf.CreateColHeaders(WIDGET, PARENT_)
	return WIDGET
end

function pf.FindIndexPlayerWidgetByName(WIDGET, playerName)
	for i=1, #WIDGET.PLAYERS, 1 do
		if WIDGET.PLAYERS[i]:GetStat("name") == playerName then
			return i
		end
	end
	return nil
end

function pf.CreateColHeaders(WIDGET, PARENT_)
	WIDGET.HEADER_BG:SetDims("width:"..(PARENT_:GetBounds().width - c_TeamWidthOffset))
	for i=1, c_BankNumColHeaders, 1 do
		BANK_COL_HEADER_WIDGETS[i] = Component.CreateWidget(COLUMN_HEADER_BP, WIDGET.COL_HEADER_GROUP)
	end
end

function pf.SetColHeaders(numOfCol, columnHeaderKeys, HEADER_BG)
	g_DistanceBetweenColHeaders = (1 / (numOfCol - 1)) * (g_FinalColHeaderOffset - g_ColHeaderLeftOffset)
	for i=1, numOfCol, 1 do
		BANK_COL_HEADER_WIDGETS[i]:SetText(Component.LookupText(columnHeaderKeys[i]))
		local leftOffset = (g_ColHeaderLeftOffset + (g_DistanceBetweenColHeaders*(i-1)))
		BANK_COL_HEADER_WIDGETS[i]:SetDims("center-x:0%+"..(leftOffset).."; center-y:50%+"..c_ColHeaderTopOffset.."; width:_;")
	end
end

function pf.UpdateColHeadersDims(COL_HEADER_WIDGETS)
	local num_header_widgets = COL_HEADER_WIDGETS:GetChildCount()
	if num_header_widgets >= 1 then
		g_DistanceBetweenColHeaders = (1 / (num_header_widgets - 1)) * (g_FinalColHeaderOffset - g_ColHeaderLeftOffset)
		for i=1, num_header_widgets, 1 do
			local leftOffset = (g_ColHeaderLeftOffset + (g_DistanceBetweenColHeaders*(i-1)))
			COL_HEADER_WIDGETS:GetChild(i):SetDims("center-x:0%+"..(leftOffset).."; center-y:50%+"..c_ColHeaderTopOffset.."; width:_;")
		end
	end
end

function pf.CalculateChildOffset(parentDim, childDim, offset)
	local offset = (parentDim/2 - childDim/2 - offset)
	return offset < 0 and "+"..(offset*-1) or "-"..offset
end

function pf.EnableIconMode(WIDGET, isIconModeEnabled)
	local iconWidth = WIDGET.ICON:GetBounds().width
	if isIconModeEnabled then
		WIDGET.ICON:SetParam("alpha", 1)
		g_NameLeftOffset = iconWidth + c_DistanceFromIcon
		-- g_LineLeftOffset = iconWidth + c_DistanceFromIcon
		--WIDGET.LINE:SetDims("center-x:_; width:"..c_LineWidthNoIcon - WIDGET.ICON:GetBounds().width - c_DistanceFromIcon)
	else
		WIDGET.ICON:SetParam("alpha", 0)
		g_NameLeftOffset = c_DistanceWithoutIcon
		-- g_LineLeftOffset = 0
		--WIDGET.LINE:SetDims("center-x:_; width:"..c_LineWidthNoIcon)
	end
	
	g_LineLeftOffset = 0
	WIDGET.LINE:SetDims("center-x:_; width:"..c_LineWidthNoIcon)
	
	--Set pos of all the things
	pf.SetChildWidgetsTopAndLeftOffset(WIDGET.HEADER_BG, WIDGET.ICON, c_IconLeftOffset, c_IconTopOffset)
	pf.SetChildWidgetsTopAndLeftOffset(WIDGET.HEADER_BG, WIDGET.LINE, g_LineLeftOffset, g_LineTopOffset)
	UpdateTeamNameAndScore(WIDGET)
end

function pf.SetChildWidgetsTopAndLeftOffset(PARENT, WIDGET, leftOffset, topOffset)
	local parentBounds = PARENT:GetBounds()
	local widgetBounds = WIDGET:GetBounds()
	local widgetLeftOffset = pf.CalculateChildOffset(parentBounds.width, widgetBounds.width, leftOffset)
	local widgetTopOffset = pf.CalculateChildOffset(parentBounds.height, widgetBounds.height, topOffset)
	
	WIDGET:SetDims("center-x:50%"..widgetLeftOffset.."; center-y:50%"..widgetTopOffset.."; width:_; height:_")
end

function pf.CreateWidgetFromBP(PARENT_, teamArgs)
	assert(PARENT_, "Must supply a parent widget for CreateWidgetFromBP")
	
	local BP_WIDGET = Component.CreateWidget(SCOREBOARD_TEAM_BP, PARENT_)
	local HEADER_WIDGET = {
		playerOverrideColor = nil,
		disabledStatColIds = teamArgs.disabledStatColIds,
		maxNumPlayers = teamArgs.maxNumPlayers,
		numActivePlayers = 0,
		maxNumDefaultVisible = teamArgs.numDefaultVisibleRows,
		currNumHidden = 0,
		enemyTeamIndexes = {},
		teamScore = 0,
		teamName = teamArgs.teamName,
		
		FOCUS = BP_WIDGET,
		PARENT = PARENT_,
		PLAYERS = {},
		HEADER_BG = BP_WIDGET:GetChild("HeaderBG"),
		LINE = BP_WIDGET:GetChild("Line"),
		ICON = BP_WIDGET:GetChild("Icon"),
		TEAM_NAME_TEXT = BP_WIDGET:GetChild("TeamName"),
		COL_HEADER_GROUP = BP_WIDGET:GetChild("ColumnHeaderGroup")
	}
	setmetatable(HEADER_WIDGET, SCOREBOARD_TEAM_MT)
	
	return HEADER_WIDGET
end

function UpdateTeamNameAndScore(WIDGET)
	if WIDGET.teamName then
		pf.SetChildWidgetsTopAndLeftOffset(WIDGET.HEADER_BG, WIDGET.TEAM_NAME_TEXT, g_NameLeftOffset, g_NameTopOffset)
		WIDGET.TEAM_NAME_TEXT:SetText(WIDGET.teamName.." - "..unicode.format(c_ScoreFormat, WIDGET.teamScore))
	end
end

function pf.CreateMaxPlayers(WIDGET, maxNumPlayers, columnHeaderKeys, teamArgs_)
	for i=1, maxNumPlayers, 1 do
		local playerArgs = {PARENT = WIDGET.FOCUS, rowIndex = i, headerArgs = columnHeaderKeys, teamArgs = teamArgs_}
		WIDGET.PLAYERS[i] = SCOREBOARD_PLAYER_LIB.CreateScoreboardPlayer(playerArgs)
		
		if i <= WIDGET.maxNumDefaultVisible then
			WIDGET.PLAYERS[i]:ShowPlayer()
			WIDGET.PLAYERS[i]:HideContent()
		end
	end
end
