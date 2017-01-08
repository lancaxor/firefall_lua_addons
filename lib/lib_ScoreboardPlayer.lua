
--
-- Scoreboard Player Lib **Used to create a customized player widget for a scoreboard**
--
if SCOREBOARD_PLAYER_LIB then
	return
end
require "unicode"
require "lib/lib_Tooltip"
require "lib/lib_CharCard"
require "lib/lib_PlayerContextualMenu"

-- ------------------------------------------
-- GLOBALS
-- ------------------------------------------
SCOREBOARD_PLAYER_LIB = {} -- Used for creation of object

-- ------------------------------------------
-- BLUEPRINTS
-- ------------------------------------------
local SCOREBOARD_PLAYER_BP = [[
	<FocusBox dimensions="dock:fill">
		<Group name="PlayerRow" dimensions="center-x:_; center-y:_; width:_; height:25" >
			<Group name="Gray_Dark" dimensions="dock:fill" style="alpha:0">
				<StillArt name="gray_dark_left" dimensions="dock:fill" style="texture:GrayBarDark; region:left"/>
				<StillArt name="gray_dark_center" dimensions="dock:fill" style="texture:GrayBarDark; region:center"/>
				<StillArt name="gray_dark_right" dimensions="dock:fill" style="texture:GrayBarDark; region:right"/>
			</Group>
			
			<Group name="Gray_Light" dimensions="dock:fill" style="alpha:0">
				<StillArt name="gray_light_left" dimensions="dock:fill" style="texture:GrayBarLight; region:left"/>
				<StillArt name="gray_light_center" dimensions="dock:fill" style="texture:GrayBarLight; region:center"/>
				<StillArt name="gray_light_right" dimensions="dock:fill" style="texture:GrayBarLight; region:right"/>
			</Group>
			
			<Group name="Gray_Selected" dimensions="dock:fill" style="alpha:0">
				<StillArt name="gray_selected_left" dimensions="dock:fill" style="texture:SelectedGray; region:left"/>
				<StillArt name="gray_selected_center" dimensions="dock:fill" style="texture:SelectedGray; region:center"/>
				<StillArt name="gray_selected_right" dimensions="dock:fill" style="texture:SelectedGray; region:right"/>
			</Group>
			
			<Group name="Content" dimensions="dock:fill" style="alpha:0">
				<Group name="Char_Card" dimensions="center-x:_; center-y:_; height:70%; width:70%"/>
				<StillArt name="white_triangle" dimensions="center-x:_; center-y:_; width:11; height:11" style="texture:WhiteTriangle; alpha:0"/>
			</Group>
		</Group>
	</FocusBox>
]]

local PLAYER_TEXT_DATA_BP = [[
	<Text dimensions="dock:fill" style="font:Demi_10; halign:center; color:B2B2B2; alpha:1; drop-shadow:true;"/>
]]

local PLAYER_TEXT_TIMER_DATA_BP = [[
	<TextTimer dimensions="dock:fill" style="font:Demi_10; halign:center; color:B2B2B2; alpha:1; drop-shadow:true;"/>
]]

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_NumNonColumnRowData = 2 -- num mandatory player data displayed on scoreboards (player name and player index)
local c_ExposureFadeDur = .2
local c_DefaultPlayerName = "WWWWWWWWWWWWWWW"
local c_DefaultNumData = "99999"
local c_RowDataHighlightColor = "#FFFFFF"
local c_ColorDisabled = "#6E6E6E"
local c_PvpBadgeNumFontSize = 9
local c_RowSideWidth = 6

local c_HighlightSideWidth = 37
local c_HighlightWidthShrinkAmt = 69
local c_HighlightSideOffsetShrinkAmt = 16

-- data offsets
local c_RowCountNumOffset = 20
local c_CharCardOffset = 49
local c_SpacingBetweenNameAndCharCard = 8

-- ------------------------------------------
-- LOCAL VARIABLES
-- ------------------------------------------
local pf = {} -- private functions
local SCOREBOARD_PLAYER_API = {} -- Used for object methods
local SCOREBOARD_PLAYER_MT = {__index=function(_, inKey) return SCOREBOARD_PLAYER_API[inKey] end}

-- ------------------------------------------
-- EVENTS
-- ------------------------------------------
function OnMouseEnter(WIDGET)
	if pf.IsRowContentVisible(WIDGET) and WIDGET:GetStat("name") ~= Game.GetTargetInfo(Player.GetTargetId()).name then
		WIDGET.CURR_LEFT:SetParam("exposure", 1, c_ExposureFadeDur)
		WIDGET.CURR_CENTER:SetParam("exposure", 1, c_ExposureFadeDur)
		WIDGET.CURR_RIGHT:SetParam("exposure", 1, c_ExposureFadeDur)
	end
end

function OnMouseLeave(WIDGET)
	if pf.IsRowContentVisible(WIDGET) and WIDGET:GetStat("name") ~= Game.GetTargetInfo(Player.GetTargetId()).name then
		WIDGET.CURR_LEFT:SetParam("exposure", 0, c_ExposureFadeDur)
		WIDGET.CURR_CENTER:SetParam("exposure", 0, c_ExposureFadeDur)
		WIDGET.CURR_RIGHT:SetParam("exposure", 0, c_ExposureFadeDur)
	end
end

function OnRightMouse(WIDGET)
	if pf.IsRowContentVisible(WIDGET) and WIDGET:GetStat("name") ~= Game.GetTargetInfo(Player.GetTargetId()).name then
		PlayerMenu.Show(WIDGET:GetStat("name"), "Scoreboard")
	end
end

-- ------------------------------------------
-- PUBLIC API
-- ------------------------------------------
function SCOREBOARD_PLAYER_LIB.CreateScoreboardPlayer(args)
	local WIDGET = pf.CreateScoreboardPlayerWidget(args)
	pf.InitAssets(WIDGET, args.teamArgs)
	return WIDGET
end

function SCOREBOARD_PLAYER_API.ShowPlayer(WIDGET)
	WIDGET.CURR_GROUP:SetParam("alpha", 1)
	WIDGET:ShowContent()
end

function SCOREBOARD_PLAYER_API.HidePlayer(WIDGET)
	WIDGET.CURR_GROUP:SetParam("alpha", 0)
	WIDGET:HideContent()
end

function SCOREBOARD_PLAYER_API.ShowContent(WIDGET)
	WIDGET.CONTENT_GROUP:SetParam("alpha", 1)
end

function SCOREBOARD_PLAYER_API.HideContent(WIDGET)
	WIDGET.ROW_TEXT_DATA_WIDGETS["name"]:SetText("WWWWWWWWWWWWWWW") --set name back to default, just in case
	WIDGET.CONTENT_GROUP:SetParam("alpha", 0)
end

function SCOREBOARD_PLAYER_API.GetStat(WIDGET, index)
	return WIDGET.ROW_TEXT_DATA_WIDGETS[index]:GetText()
end

function SCOREBOARD_PLAYER_API.GetAllStats(WIDGET)
	local resultData = {}
	resultData["name"] = WIDGET:GetStat("name")
	
	for i=1, #WIDGET.ROW_TEXT_DATA_WIDGETS, 1 do
		resultData[i] = WIDGET:GetStat(i)
	end
	
	return resultData
end

function SCOREBOARD_PLAYER_API.SetTimerStatCol(WIDGET, timerColIndex)
	WIDGET.TIMER:SetDims(WIDGET.ROW_TEXT_DATA_WIDGETS[timerColIndex]:GetDims())
	WIDGET.TIMER:Show()
	WIDGET.TIMER:StartTimer(5,true)
	
	WIDGET.ROW_TEXT_DATA_WIDGETS[timerColIndex]:SetParam("alpha", 0) -- hide the old col value and replace it with the timer
end

function SCOREBOARD_PLAYER_API.SetStat(WIDGET, index, val)
	WIDGET.ROW_TEXT_DATA_WIDGETS[index]:SetText(tostring(val))
end

function SCOREBOARD_PLAYER_API.GetStatWidget(WIDGET, index)
	return WIDGET.ROW_TEXT_DATA_WIDGETS[index]
end

function SCOREBOARD_PLAYER_API.SetAllStats(WIDGET, newStats)
	pf.SetCharCard(WIDGET, newStats["pvpRank"], newStats["battleframeId"])
	pf.AssignNewName(WIDGET, newStats["name"])
	pf.HighlightIfPlayer(WIDGET)
	
	for i=1, #WIDGET.ROW_TEXT_DATA_WIDGETS, 1 do
		WIDGET:SetStat(i, newStats[i])
	end
end

function SCOREBOARD_PLAYER_API.SetColor(WIDGET, color, overrideColor, disabledStatColIds)
	WIDGET.currColor = color

	-- default row and highlight background assets should always be the team color
	WIDGET.CURR_LEFT:SetParam("tint", color)
	WIDGET.CURR_CENTER:SetParam("tint", color)
	WIDGET.CURR_RIGHT:SetParam("tint", color)
	WIDGET.GRAY_SELECTED_LEFT:SetParam("tint", color)
	WIDGET.GRAY_SELECTED_CENTER:SetParam("tint", color)
	WIDGET.GRAY_SELECTED_RIGHT:SetParam("tint", color)

	-- if this widget is for the current player and we have a data highlight color, then all other content in the row should be that color
	if WIDGET.colorHighlight then
		color = WIDGET.colorHighlight
	elseif overrideColor then
		color = overrideColor
	end
	
	if WIDGET.enableBFIcon then
		local BF_ICON = WIDGET.CHAR_CARD:GetElement(c_CardOptions.Battleframe)
		if BF_ICON then
			BF_ICON:SetParam("tint", color)
		end
	end
	
	if WIDGET.enablePvPRankIcon then
		local PVP_BADGE = WIDGET.CHAR_CARD:GetElement(c_CardOptions.PVPRank)
		if PVP_BADGE then
			PVP_BADGE:ShowLabel(true, c_PvpBadgeNumFontSize, color)
		end
	end
	
	WIDGET.WHITE_TRIANGLE:SetParam("tint", color)
	WIDGET.TIMER:SetTextColor(color)
	
	WIDGET.ROW_TEXT_DATA_WIDGETS["name"]:SetParam("color", color)	
	for i=1, #WIDGET.ROW_TEXT_DATA_WIDGETS, 1 do
		WIDGET.ROW_TEXT_DATA_WIDGETS[i]:SetParam("color", color)
	end
	
	if disabledStatColIds then
		for i=1, #disabledStatColIds, 1 do
			local index = disabledStatColIds[i]
			if WIDGET.TIMER and index == 3 then
				WIDGET.TIMER:SetTextColor(c_ColorDisabled)
			end
			WIDGET.ROW_TEXT_DATA_WIDGETS[index]:SetParam("color", c_ColorDisabled)
		end
	end
end

function SCOREBOARD_PLAYER_API.SetStatOffsets(WIDGET, left_offset, distance_between)
	for bankIndex=3, (WIDGET.numColData + c_NumNonColumnRowData), 1 do
		local i = bankIndex - 2
		local offset = (left_offset + (distance_between*(i-1)))
		WIDGET.ROW_TEXT_DATA_WIDGETS[i]:SetDims("center-x:0%+"..(offset).."; center-y:50%; height:10; width:10;")
	end
end

-- ------------------------------------------
-- PRIVATE API
-- ------------------------------------------
function pf.CreateScoreboardPlayerWidget(args)
	assert(args.PARENT, "Must supply a parent widget for CreateScoreboardPlayerWidget")
	
	local BP_WIDGET = Component.CreateWidget(SCOREBOARD_PLAYER_BP, args.PARENT)
	local PLAYER_GROUP = BP_WIDGET:GetChild("PlayerRow")
	local GD_GROUP_ = PLAYER_GROUP:GetChild("Gray_Dark")
	local GL_GROUP_ = PLAYER_GROUP:GetChild("Gray_Light")
	local GS_GROUP_ = PLAYER_GROUP:GetChild("Gray_Selected")
	local CONTENT_GROUP_ = PLAYER_GROUP:GetChild("Content")
	local WIDGET = {
		colorHighlight = nil,
		currColor = nil,
		rowIndex = args.rowIndex,
		numColData = args.headerArgs["numColHeaders"],
		maxNumColData = args.headerArgs["maxNumColHeaders"],
		distBetweenColHeaders = args.headerArgs["distBetweenColHeaders"],
		initColHeaderLeftOffset = args.headerArgs["colHeaderOffset"],
		enablePvPRankIcon = false,
		enableBFIcon = false,
		
		FOCUS = BP_WIDGET,
		PARENT = args.PARENT,
		TIMER = nil,
		CURR_GROUP = nil,
		CURR_LEFT = nil,
		CURR_CENTER = nil,
		CURR_RIGHT = nil,
		CHAR_CARD = nil,
		
		BANK_ROW_TEXT_DATA_WIDGETS = {},
		ROW_TEXT_DATA_WIDGETS = {},
		
		CONTENT_GROUP = CONTENT_GROUP_,
		CHAR_CARD_GROUP = CONTENT_GROUP_:GetChild("Char_Card"),
		WHITE_TRIANGLE = CONTENT_GROUP_:GetChild("white_triangle"),
		
		GD_GROUP = GD_GROUP_,
		GRAY_DARK_LEFT = GD_GROUP_:GetChild("gray_dark_left"),
		GRAY_DARK_CENTER = GD_GROUP_:GetChild("gray_dark_center"),
		GRAY_DARK_RIGHT = GD_GROUP_:GetChild("gray_dark_right"),
		
		GL_GROUP = GL_GROUP_,
		GRAY_LIGHT_LEFT = GL_GROUP_:GetChild("gray_light_left"),
		GRAY_LIGHT_CENTER = GL_GROUP_:GetChild("gray_light_center"),
		GRAY_LIGHT_RIGHT = GL_GROUP_:GetChild("gray_light_right"),
		
		GS_GROUP = GS_GROUP_,
		GRAY_SELECTED_LEFT = GS_GROUP_:GetChild("gray_selected_left"),
		GRAY_SELECTED_CENTER = GS_GROUP_:GetChild("gray_selected_center"),
		GRAY_SELECTED_RIGHT = GS_GROUP_:GetChild("gray_selected_right"),
	}
	setmetatable(WIDGET, SCOREBOARD_PLAYER_MT)
	
	WIDGET.TIMER = Component.CreateWidget(PLAYER_TEXT_TIMER_DATA_BP, WIDGET.CONTENT_GROUP)
	WIDGET.TIMER:Hide()
	
	WIDGET.FOCUS:BindEvent("OnMouseEnter", function() OnMouseEnter(WIDGET) end)
	WIDGET.FOCUS:BindEvent("OnMouseLeave", function() OnMouseLeave(WIDGET) end)
	WIDGET.FOCUS:BindEvent("OnRightMouse", function() OnRightMouse(WIDGET) end)
	
	return WIDGET
end

function pf.InitAssets(WIDGET, args)
	pf.ResizeAll(WIDGET.PARENT, WIDGET.GRAY_DARK_LEFT, WIDGET.GRAY_DARK_CENTER, WIDGET.GRAY_DARK_RIGHT)
	pf.ResizeAll(WIDGET.PARENT, WIDGET.GRAY_LIGHT_LEFT, WIDGET.GRAY_LIGHT_CENTER, WIDGET.GRAY_LIGHT_RIGHT)
	pf.ResizeAll(WIDGET.PARENT, WIDGET.GRAY_SELECTED_LEFT, WIDGET.GRAY_SELECTED_CENTER, WIDGET.GRAY_SELECTED_RIGHT, true)
	
	pf.InitRowBG(WIDGET)
	pf.InitWhiteTriangle(WIDGET)
	pf.InitCharCard(WIDGET, args)
	pf.InitRowTextWidgets(WIDGET)
end

function pf.ResizeAll(PARENT, LEFT, CENTER, RIGHT, isHighlight)
	local pWidth = PARENT:GetBounds().width
	
	local centerWidth = pWidth
	local sideWidth = c_RowSideWidth
	local sideOffset = pWidth / 2
	
	 if isHighlight then
		centerWidth = centerWidth - c_HighlightWidthShrinkAmt
		sideWidth = c_HighlightSideWidth
		sideOffset = sideOffset - c_HighlightSideOffsetShrinkAmt
	 end
	
	LEFT:SetDims("center-x:50%-"..sideOffset.."; width:"..sideWidth)
	CENTER:SetDims("width:"..centerWidth)
	RIGHT:SetDims("center-x:50%+"..sideOffset.."; width:"..sideWidth)
end

function pf.InitRowBG(WIDGET)
	local isEven = WIDGET.rowIndex % 2 == 0
	if isEven then
		pf.EnableLightGray(WIDGET)
	else
		pf.EnableDarkGray(WIDGET)
	end
	pf.StackPlayerRows(WIDGET)
end

function pf.EnableLightGray(WIDGET)
	WIDGET.CURR_LEFT = WIDGET.GRAY_LIGHT_LEFT
	WIDGET.CURR_CENTER = WIDGET.GRAY_LIGHT_CENTER
	WIDGET.CURR_RIGHT = WIDGET.GRAY_LIGHT_RIGHT
	WIDGET.CURR_GROUP = WIDGET.GL_GROUP
end

function pf.EnableDarkGray(WIDGET)
	WIDGET.CURR_LEFT = WIDGET.GRAY_DARK_LEFT
	WIDGET.CURR_CENTER = WIDGET.GRAY_DARK_CENTER
	WIDGET.CURR_RIGHT = WIDGET.GRAY_DARK_RIGHT
	WIDGET.CURR_GROUP = WIDGET.GD_GROUP
end

function pf.StackPlayerRows(WIDGET)
	if WIDGET.rowIndex > 0 then
		local rowHeight = WIDGET.CURR_CENTER:GetBounds().height -- each of these widgets should be the same height, so shouldn't matter which we use
		local teamHeaderHeight = (WIDGET.PARENT:GetBounds().height / 2) - 1 -- used to align the initial player row right underneath the team header
		local offsetStr = "center-y:"..(teamHeaderHeight + (rowHeight * WIDGET.rowIndex) - WIDGET.rowIndex - 1)..";"
		
		WIDGET.CURR_LEFT:SetDims(offsetStr)
		WIDGET.CURR_CENTER:SetDims(offsetStr)
		WIDGET.CURR_RIGHT:SetDims(offsetStr)
		
		WIDGET.GRAY_SELECTED_LEFT:SetDims(offsetStr)
		WIDGET.GRAY_SELECTED_CENTER:SetDims(offsetStr)
		WIDGET.GRAY_SELECTED_RIGHT:SetDims(offsetStr)
	end
end

function pf.InitWhiteTriangle(WIDGET)	
	local rowBounds = WIDGET.CURR_CENTER:GetBounds()
	local iconBounds = WIDGET.WHITE_TRIANGLE:GetBounds()
	local xOffsetToEdge = 2
	local xOffset = ((iconBounds.width / 2) - xOffsetToEdge)
	local yOffset = (rowBounds.height - (iconBounds.height / 2))
	
	WIDGET.WHITE_TRIANGLE:SetDims("center-x:"..xOffset.."; center-y:"..yOffset.."; width:_; height:_;")
end

function pf.InitCharCard(WIDGET, args)
	local options = {}
	
	WIDGET.enablePvPRankIcon = args.enablePvPRankIcon
	if args.enablePvPRankIcon then
		table.insert(options, c_CardOptions.PVPRank)
	end
	
	WIDGET.enableBFIcon = args.enableBFIcon
	if args.enableBFIcon then
		table.insert(options, c_CardOptions.Battleframe)
	end
	
	WIDGET.CHAR_CARD = CharCard.CreateCard(WIDGET.CHAR_CARD_GROUP, Player.GetTargetId(), options)
	local PVP_BADGE = WIDGET.CHAR_CARD:GetElement(c_CardOptions.PVPRank)
	PVP_BADGE:UseSmallIcon(true)
	PVP_BADGE:ShowLabel(true, c_PvpBadgeNumFontSize)
	WIDGET.CHAR_CARD:UpdateDisplay()
	pf.ResizeCharCard(WIDGET)	
end

function pf.InitRowTextWidgets(WIDGET)
	pf.CreateBankTextWidgets(WIDGET)
	pf.SetDefaultRowTextData(WIDGET)
end

function pf.CreateBankTextWidgets(WIDGET)
	WIDGET.CONTENT_GROUP:SetDims(WIDGET.CURR_CENTER:GetDims())
	for i=1, WIDGET.maxNumColData + c_NumNonColumnRowData, 1 do
		WIDGET.BANK_ROW_TEXT_DATA_WIDGETS[i] = Component.CreateWidget(PLAYER_TEXT_DATA_BP, WIDGET.CONTENT_GROUP)
	end
end

function pf.SetDefaultRowTextData(WIDGET)
	WIDGET.ROW_TEXT_DATA_WIDGETS["idx"] = WIDGET.BANK_ROW_TEXT_DATA_WIDGETS[1]
	WIDGET.ROW_TEXT_DATA_WIDGETS["idx"]:SetText(tostring(WIDGET.rowIndex))
	WIDGET.ROW_TEXT_DATA_WIDGETS["idx"]:SetDims("center-x:0%+"..c_RowCountNumOffset.."; center-y:50%; height:10; width:10;")

	WIDGET.ROW_TEXT_DATA_WIDGETS["name"] = WIDGET.BANK_ROW_TEXT_DATA_WIDGETS[2]
	pf.AssignNewName(WIDGET, c_DefaultPlayerName)
	
	for bankIndex=3, (WIDGET.numColData + c_NumNonColumnRowData), 1 do
		local i = bankIndex - 2
		WIDGET.ROW_TEXT_DATA_WIDGETS[i] = WIDGET.BANK_ROW_TEXT_DATA_WIDGETS[bankIndex]
		WIDGET.ROW_TEXT_DATA_WIDGETS[i]:SetText(c_DefaultNumData)
		
		local leftOffset = (WIDGET.initColHeaderLeftOffset + (WIDGET.distBetweenColHeaders * (i-1)))
		WIDGET.ROW_TEXT_DATA_WIDGETS[i]:SetDims("center-x:0%+"..(leftOffset).."; center-y:50%; height:10; width:10;")
	end
end

function pf.HighlightIfPlayer(WIDGET)
	local playerInfo = Game.GetTargetInfo(Player.GetTargetId())
	local widgetName = WIDGET:GetStat("name")
	local isPlayer = (widgetName == playerInfo.name and 1 or 0)
	WIDGET.GS_GROUP:SetParam("alpha", isPlayer)
	WIDGET.colorHighlight = (widgetName == playerInfo.name and c_RowDataHighlightColor or nil)
	if WIDGET.currColor then WIDGET:SetColor(WIDGET.currColor) end -- do a color refresh to make sure the highlight is highlighting only the current player, such as for when they swap teams
end

function pf.AssignNewName(WIDGET, newName)
	WIDGET.ROW_TEXT_DATA_WIDGETS["name"]:SetText(newName)
	pf.UpdateNameDims(WIDGET)
end

function pf.UpdateNameDims(WIDGET)
	local textDims = WIDGET.ROW_TEXT_DATA_WIDGETS["name"]:GetTextDims()
	local playerNameOffset = WIDGET.CHAR_CARD.GROUP:GetLength() + c_SpacingBetweenNameAndCharCard
	WIDGET.ROW_TEXT_DATA_WIDGETS["name"]:SetDims("center-x:0%+"..(c_CharCardOffset + playerNameOffset + textDims.width/2).."; center-y:50%; height:10; width:10;")
end

function pf.IsRowContentVisible(WIDGET)
	return WIDGET.CONTENT_GROUP:GetParam("alpha") > 0
end

function pf.SetCharCard(WIDGET, pvpRank, battleframeId)
	local bfIcon = nil
	if battleframeId then
		local info = Game.GetItemInfoByType(battleframeId)
		bfIcon = info and info.web_icon_id or nil
	end
	WIDGET.CHAR_CARD:UpdateDisplay({pvp_rank = pvpRank, frame_icon_id = bfIcon, name=""})
	pf.ResizeCharCard(WIDGET)
end

function pf.ResizeCharCard(WIDGET)
	local cardWidth = WIDGET.CHAR_CARD.GROUP:GetLength()
	WIDGET.CHAR_CARD_GROUP:SetDims("center-x:0%+"..(c_CharCardOffset + (cardWidth/2)).."; center-y:_; width:20; height:75%;")
end
