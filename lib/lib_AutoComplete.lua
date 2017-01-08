
-- ------------------------------------------
-- lib_AutoComplete
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
	AUTOCOMPLETE = AutoComplete.Create(PARENT[, params])			--Creates an AutoComplete Popup
																		--PARENT is the widget/frame that will be the parent for the popup
																		--params is an optional table to supply config info on create; all params have a matching Method
																			--params.special_type		special handling the uses a master db from the AutoComplete main component; see c_SpecialTypes for supported types; 
																				--following api gets disabled; SetCaseHandler, SetMatchMethod, AddEntries, RemoveEntries, ClearEntries
																			--params.OnClick			gets passed into AUTOCOMPLETE:SetOnClickHandler(func)
																			--params.CaseHandler		gets passed into AUTOCOMPLETE:SetCaseHandler(func)
																			--params.match_method		gets passed into AUTOCOMPLETE:SetMatchMethod(method)
																			--params.too_many_matches	gets passed into AUTOCOMPLETE:UseTooManyMatches(boolean)
																			--params.font				gets passed into AUTOCOMPLETE:SetFont(font)
																			--params.max_entries		gets passed into AUTOCOMPLETE:SetMaxEntries(max_entries)
																			--params.anchor_x			gets passed into AUTOCOMPLETE:SetAnchorX(dim)
																			--params.anchor_y			gets passed into AUTOCOMPLETE:SetAnchorY(dim)
																			
	AUTOCOMPLETE:Destroy()										--Removes it
	AUTOCOMPLETE:Show(boolean)									--Show/Hide the popup
	boolean = AUTOCOMPLETE:IsVisible()							--Returns if it is being displayed
																
	AUTOCOMPLETE:AddEntries(entries)							--entries can either be a string or an array of strings; adds the strings to a database for later matching
																	--Note: all leading and trailing whitespaces will be removed from entries
	AUTOCOMPLETE:RemoveEntries(entries))						--entries can either be a string or an array of strings; removes the strings from the database
	AUTOCOMPLETE:ClearEntries()									--clears the data base
	AUTOCOMPLETE:FindMatches(search)							--search is a string; searches the database for entries that match the search pattern supplied
	AUTOCOMPLETE:Next()											--Moves the Highlight to the next entry
	AUTOCOMPLETE:Previous()										--Moves the Highlight to the previous entry
	match, search = AUTOCOMPLETE:GetMatch()						--returns the highlighted entry and the search string
																	--match is the full matched string
																	--search is what you were using for the search
																
	AUTOCOMPLETE:SetOnClickHandler(func)						--func will be triggered when an entry is clicked on
																	--will need to run AUTOCOMPLETE:GetMatch() to get the match still
																	--if not supplied that mouse interaction is disabled
	AUTOCOMPLETE:SetCaseHandler(func)							--func for how to handle case sensitivity; default uses normalize
	AUTOCOMPLETE:SetMatchMethod(method)							--sets which match method to use from the following
																	--"phrase_start" = must match the beginning of the entry
																	--"word_start" = must match the beginning of a word in the entry
																	--"full_search" = will match any part of the entry
	AUTOCOMPLETE:UseTooManyMatches(boolean)						--when true and there are more matches then max, show "Too Many Matches" instead of the matches; false shows the first X matches
	AUTOCOMPLETE:SetFont(font)									--sets the font to be used
	AUTOCOMPLETE:SetMaxEntries(max_entries)						--sets the max number of matches that will be displayed for matching
	AUTOCOMPLETE:SetAnchorX(dim)								--Sets the X axis anchor point relative to PARENT; default is "center-x:50%"; width gets set automatically
	AUTOCOMPLETE:SetAnchorY(dim)								--Sets the Y axis anchor point relative to PARENT; default is "top:100%+2"; height gets set automatically
--]]

AutoComplete = {}

require "unicode"
require "math"
require "table"
require "lib/lib_table"
require "lib/lib_math"
require "lib/lib_InputIcon"
require "lib/lib_Callback2"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lf = {}
local api = {}
local lcb = {}
local c_ComponentName = Component.GetInfo()

local c_Metatable = {
	__index = function(t,key) return api[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in AutoComplete"); end
};

local c_Separator = "~" --needs to be a unique char to prevent false matches
local c_NonSeparator = "[^"..c_Separator.."]*"
local c_MatchMethods = {
	phrase_start	= c_Separator.."(STRING"..c_NonSeparator..")",
	word_start		= c_Separator.."("..c_NonSeparator.."%f[^"..c_Separator.."%s]STRING"..c_NonSeparator..")",
	full_search		= c_Separator.."("..c_NonSeparator.."STRING"..c_NonSeparator..")",
}
local c_SpecialTypes = {
	name = "FindNameMatches",				--database of player names
}

local c_HighlightAlpha = 0.15
local c_Padding = 6
local c_ArrowToTextPadding = 3
local c_ResizeDelay = 0.001
local c_HeaderColor = "orange"
local c_EntryColor = "#FFFFFF"
local c_TypedColor = "#00BFFF"
local c_DefaultFont = "UbuntuMedium_10"
local c_DefaultTextStyle = "font:"..c_DefaultFont.."; valign:center; halign:left; "

local bp_AutoComplete =
	[[<Group dimensions="center-x:50%; top:100%+2; width:240; height:20" style="alpha:0">
		<Border dimensions="center-x:50%; center-y:50%; width:100%-2; height:100%-2" class="ButtonSolid" style="tint:#000000; alpha:0.9; padding:4"/> 
		<Border dimensions="dock:fill" class="ButtonBorder" style="alpha:0.2; exposure:1.0; padding:4"/>
		<ListLayout name="list" dimensions="top:]]..c_Padding..[[; bottom:100%-]]..c_Padding..[[; left:]]..c_Padding..[[; right:100%-]]..c_Padding..[[;" style="vpadding:2"/>
	</Group>]]

local bp_HeaderLine = 
	[[<Group dimensions="dock:fill">
		<Text name="text" dimensions="left:160t; right:100%; center-y:50%-1; height:100%" style="]]..c_DefaultTextStyle..[[color:]]..c_HeaderColor..[[" key="{Init text for sizing}"/>
	</Group>]]

local bp_EntryLine = 
	[[<Group dimensions="dock:fill">
		<StillArt name="highlight" dimensions="dock:fill" style="texture:colors; region:white; eatsmice:false; alpha:0"/>
		<Text name="text" dimensions="dock:fill" style="]]..c_DefaultTextStyle..[["/>
		<FocusBox name="focus" dimensions="dock:fill" class="ui_button"/>
	</Group>]]

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_PendingData = {}
local g_PendingIndex = 0

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function AutoComplete.Create(PARENT, params)
	params = params or {}
	local AC = {
		special_type = false,										--special type that intergrates with the AutoComplete component
		CaseHandler = normalize,									--function for dealing with case sensitivity
		OnClick = false,											--function to send entry to if clicked on
		font = c_DefaultFont,										--text font used
		too_many_matches = false,									--when true use too many matches display, when false display first set of matching matches until max_entries
		line_height = 1,											--height of each text line
		anchor_x = "center-x",										--horizontal anchor point
		anchor_y = "top",											--vertical anchor point
		highlight_index = -1,										--index of entry that is currently highlighted
		match_method = "full_search",								--method of pattern matching
		match_string = c_MatchMethods.full_search,					--pattern matching string
		search = "",												--the search string used for matching entries
		entries_string = "",										--string of entries used for searching
		entries = {},												--table of entries
		matches = {},												--table of matched entries
		cb_ResizeParts = Callback2.Create(),						--callback to handle parts size updating, prevents multiple calls per frame
		cb_ResizeGroup = Callback2.Create(),						--callback to handle group size updating, prevents multiple calls per frame
	}
	
	--create group with the frame as the parent so it appears on top of all other widgets
	AC.GROUP = Component.CreateWidget(bp_AutoComplete, PARENT:GetFrame())
	--foster with dims only so it is placed via the parent but still topmost draw order
	Component.FosterWidget(AC.GROUP, PARENT, "dims")
	--Init all the bits
	AC.LIST = AC.GROUP:GetChild("list")
	AC.HEADER_GROUP = Component.CreateWidget(bp_HeaderLine, AC.LIST)
	AC.TITLE = AC.HEADER_GROUP:GetChild("text")
	AC.TAB_ICON = InputIcon.CreateVisual(AC.HEADER_GROUP)
	AC.TAB_ICON:SetDims("left:0; center-y:50%-1; width:160t; height:100%")
	AC.TAB_ICON:SetBind({keycode=9}, false)
	AC.UP_ARROW = InputIcon.CreateVisual(AC.GROUP)
	AC.UP_ARROW:SetBind({keycode=38}, false)
	AC.DOWN_ARROW = InputIcon.CreateVisual(AC.GROUP)
	AC.DOWN_ARROW:SetBind({keycode=40}, false)
	AC.ENTRIES = {}
	--setup Resize callbacks to prevent multiple resizings per frame update
	AC.cb_ResizeParts:Bind(lf.ResizeParts, AC)
	AC.cb_ResizeGroup:Bind(lf.ResizeGroup, AC)
	lf.QueueResizeParts(AC)
	--lock down the AutoComplete OBJECT
	setmetatable(AC, c_Metatable)
	--setup any params that got passed in
	if params.special_type and c_SpecialTypes[params.special_type] then
		AC.special_type = c_SpecialTypes[params.special_type]
	end
	if params.OnClick then
		AC:SetOnClickHandler(params.OnClick)
	end
	if params.CaseHandler then
		AC:SetCaseHandler(params.CaseHandler)
	end
	if params.match_method then
		AC:SetMatchMethod(params.match_method)
	end
	if params.too_many_matches ~= nil then
		AC:UseTooManyMatches(params.too_many_matches)
	end
	if params.font then
		AC:SetFont(params.font)
	end
	if params.max_entries then
		AC:SetMaxEntries(params.max_entries)
	end
	if params.anchor_x then
		AC:SetAnchorX(params.anchor_x)
	end
	if params.anchor_y then
		AC:SetAnchorY(params.anchor_y)
	end
	return AC
end

-- ------------------------------------------
-- API FUNCTIONS
-- ------------------------------------------
function api.Show(AC, bool)
	if bool then
		AC.GROUP:ParamTo("alpha", 1, 0.1)
		AC.GROUP:Show(true)
	else
		AC.GROUP:ParamTo("alpha", 0, 0.1)
		AC.GROUP:Hide(true, 0.1)
	end
end

function api.IsVisible(AC)
	return AC.GROUP:IsVisible()
end

function api.Destroy(AC)
	AC.cb_ResizeParts:Release()
	AC.cb_ResizeGroup:Release()
	Component.RemoveWidget(AC.GROUP)
	for k, v in pairs(AC) do
		AC[k] = nil
	end
end

function api.AddEntries(AC, entries)
	assert(not AC.special_type, "AUTOCOMPLETE:AddEntries() is not supported with special_type")
	local var_type = type(entries)
	if var_type == "string" then
		lf.AddEntry(AC, entries)
	elseif var_type == "table" then
		for _, entry in ipairs(entries) do
			lf.AddEntry(AC, entry)
		end
	end
	lf.UpdateExistingMatch(AC)
end

function api.RemoveEntries(AC, entries)
	assert(not AC.special_type, "AUTOCOMPLETE:RemoveEntries() is not supported with special_type")
	local var_type = type(entries)
	if var_type == "string" then
		lf.RemoveEntry(AC, entries)
	elseif var_type == "table" then
		for _, entry in ipairs(entries) do
			lf.RemoveEntry(AC, entry)
		end
	end
	lf.UpdateExistingMatch(AC)
end

function api.ClearEntries(AC)
	assert(not AC.special_type, "AUTOCOMPLETE:ClearEntries() is not supported with special_type")
	AC.entries = {}
	AC.entries_string = ""
	lf.UpdateExistingMatch(AC)
end

function api.SetMaxEntries(AC, max_entries)
	assert(type(max_entries) == "number" and max_entries >= 1, "AutoComplete SetMaxEntries must be an integer greater then 0")
	local entries = #AC.ENTRIES
	if entries < max_entries then --add entries
		for i = entries+1, max_entries do
			local ENTRY = {GROUP=Component.CreateWidget(bp_EntryLine, AC.LIST)}
			ENTRY.GROUP:SetDims("top:_; height:"..AC.line_height)
			ENTRY.HIGHLIGHT = ENTRY.GROUP:GetChild("highlight")
			ENTRY.TEXT = ENTRY.GROUP:GetChild("text")
			ENTRY.TEXT:SetFont(AC.font)
			ENTRY.FOCUS = ENTRY.GROUP:GetChild("focus")
			ENTRY.FOCUS:Show(AC.OnClick)
			ENTRY.FOCUS:BindEvent("OnMouseEnter", function() lf.SetHighlight(AC, i) end)
			ENTRY.FOCUS:BindEvent("OnMouseDown", function() AC.OnClick() end)
			table.insert(AC.ENTRIES, ENTRY)
		end
	elseif entries > max_entries then --remove entries
		for i = entries, max_entries+1, -1 do
			if AC.highlight_index == i then
				lf.MoveHighlight(AC, -1)
			end
			Component.RemoveWidget(AC.ENTRIES[i])
			table.remove(AC.ENTRIES, i)
		end
	else --no change, skip ResizeGroup
		return
	end
	lf.QueueResizeGroup(AC)
end

function api.SetOnClickHandler(AC, func)
	if type(func) == "function" then
		AC.OnClick = func
	else
		AC.OnClick = false
	end
	for _, ENTRY in ipairs(AC.ENTRIES) do
		ENTRY.FOCUS:Show(AC.OnClick)
	end
end

function api.SetCaseHandler(AC, func)
	assert(not AC.special_type, "AUTOCOMPLETE:SetCaseHandler() is not supported with special_type")
	assert(type(func) == "function", "AutoComplete CaseHandler must be a function")
	AC.CaseHandler = func
	if #AC.entries > 0 then
		--convert existing entries into new format
		local temp = _table.copy(AC.entries)
		AC.entries = {}
		for k, v in pairs(temp) do
			lf.AddEntry(AC, v)
		end
	end
end

function api.SetFont(AC, font)
	AC.TITLE:SetFont(font)
	for _, ENTRY in ipairs(AC.ENTRIES) do
		ENTRY.TEXT:SetFont(font)
	end
	AC.font = font
	lf.QueueResizeParts(AC)
end

function api.SetAnchorX(AC, dim)
	AC.GROUP:SetDims("width:_; "..dim)
	local anchor = unicode.gsub(dim, ":.+", "")
	AC.anchor_x = anchor
end

function api.SetAnchorY(AC, dim)
	AC.GROUP:SetDims("height:_; "..dim)
	local anchor = unicode.gsub(dim, ":.+", "")
	AC.anchor_y = anchor
end

function api.UseTooManyMatches(AC, bool)
	if bool then --covert non-boolean values
		AC.too_many_matches = true
	else
		AC.too_many_matches = false
	end
end

function api.SetMatchMethod(AC, method)
	assert(not AC.special_type, "AUTOCOMPLETE:SetMatchMethod() is not supported with special_type")
	match_string = c_MatchMethods[method]
	if match_string then
		AC.match_string = match_string
		AC.match_method = method
	end
end

function api.FindMatches(AC, search)
	if search == "" then return nil end
	if AC.special_type then
		Liaison.RemoteCall("AutoComplete", AC.special_type, search, c_ComponentName, "SpecialTypeHandler", lf.SetPendingData(AC))
	else
		local key, value = lf.HandleCase(AC, search)
		key = unicode.gsub(key, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
		if key == "" then return nil end
		if not AC:IsVisible() then
			lf.UpdateEntriesString(AC)
		end
		AC.search = value
		AC.matches = {}
		local match_string = unicode.gsub(AC.match_string, "STRING", key)
		for match in unicode.gmatch(AC.entries_string, match_string) do
			local tbl = {}
			tbl.text =  AC.entries[match]
			if AC.match_method == "word_start" then
				tbl.start = 0
				repeat
					tbl.start, tbl.stop = unicode.find(match, key, tbl.start+1)
				until tbl.start == 1 or unicode.sub(tbl.text, tbl.start-1, tbl.start-1) == " "
				tbl.word_start = true
			else
				tbl.start, tbl.stop = unicode.find(match, key)
				tbl.word_start = tbl.start == 1 or unicode.sub(tbl.text, tbl.start-1, tbl.start-1) == " "
			end
			table.insert(AC.matches, tbl)
		end
		lf.DisplaySearch(AC)
	end
end

function api.Next(AC)
	lf.MoveHighlight(AC, 1)
end

function api.Previous(AC)
	lf.MoveHighlight(AC, -1)
end

function api.GetMatch(AC)
	local search = AC.search
	AC.search = ""
	AC:Show(false)
	if AC.highlight_index == -1 then 
		return nil, nil
	else
		return AC.ENTRIES[AC.highlight_index].TEXT:GetText(), search
	end
end

-- ------------------------------------------
-- REMOTE FUNCTIONS
-- ------------------------------------------
function lcb.SpecialTypeHandler(index, matches, search)
	local AC = lf.GetPendingData(index)
	AC.search = search
	AC.matches = matches
	lf.DisplaySearch(AC)
end
Liaison.BindCallTable(lcb)

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.QueueResizeParts(AC)
	AC.cb_ResizeParts:Reschedule(c_ResizeDelay)
end

function lf.ResizeParts(AC)
	local line_height = AC.TITLE:GetLineHeight()
	if AC.line_height == line_height then --early out if height didn't change
		return
	end
	AC.line_height = line_height
	AC.HEADER_GROUP:SetDims("top:_; height:"..line_height)
	AC.UP_ARROW:SetDims("right:100%-"..c_Padding.."; top:"..c_Padding.."; width:"..(line_height*1.4).."; height:"..line_height)
	AC.DOWN_ARROW:SetDims("right:100%-"..c_Padding.."; bottom:100%-"..c_Padding.."; width:"..(line_height*1.4).."; height:"..line_height)
	for _, ENTRY in ipairs(AC.ENTRIES) do
		ENTRY.GROUP:SetDims("top:_; height:"..line_height)
	end
	lf.QueueResizeGroup(AC)
end

function lf.QueueResizeGroup(AC)
	AC.cb_ResizeGroup:Reschedule(c_ResizeDelay)
end

function lf.ResizeGroup(AC)
	--get header width
	local width = AC.TITLE:GetTextDims().width
	if AC.TAB_ICON:IsVisible() then
		width = width + AC.TAB_ICON:GetBounds().width
	end
	--compare with entry widths
	for _, ENTRY in ipairs(AC.ENTRIES) do
		width = math.max(width, ENTRY.TEXT:GetTextDims().width)
	end
	--add arrow width
	if AC.UP_ARROW:IsVisible() then
		width = width + AC.UP_ARROW:GetBounds().width + c_ArrowToTextPadding
	end
	--add padding
	width = width + (c_Padding*2) + 8
	local height = (c_Padding*2) + AC.LIST:GetLength()
	--set dims
	AC.GROUP:SetDims(AC.anchor_y..":_; "..AC.anchor_x..":_; height:"..height.."; width:"..width)
end

function lf.AddEntry(AC, entry)
	if type(entry) ~= "string" or entry == "" then return nil end
	local key, value = lf.HandleCase(AC, entry)
	if not AC.entries[key] then
		AC.entries[key] = value
	end
end

function lf.RemoveEntry(AC, entry)
	if type(entry) ~= "string" or entry == "" then return nil end
	local key, value = lf.HandleCase(AC, entry)
	AC.entries[key] = nil
end

function lf.UpdateExistingMatch(AC)
	if AC.search and AC:IsVisible() then
		lf.UpdateEntriesString(AC)
		AC:FindMatches(AC.search)
	end
end

function lf.MoveHighlight(AC, amount)
	if AC.highlight_index == -1 then return nil end
	local count = math.min(#AC.ENTRIES, #AC.matches)
	local new_hightlight = AC.highlight_index + amount
	if new_hightlight == 0 then
		new_hightlight = count
	elseif new_hightlight > count then
		new_hightlight = 1
	end
	lf.SetHighlight(AC, new_hightlight)
end

function lf.SetHighlight(AC, index)
	if 0 > index or index > #AC.matches then return nil end
	AC.ENTRIES[AC.highlight_index].HIGHLIGHT:SetParam("alpha", 0)
	AC.highlight_index = index
	AC.ENTRIES[index].HIGHLIGHT:SetParam("alpha", c_HighlightAlpha)
end

function lf.HandleCase(AC, str)
	str = unicode.gsub(str, "^%s+", "") --remove leading spaces
	str = unicode.gsub(str, "%s+$", "") --remove trailing spaces
	local key = AC.CaseHandler(str)
	if unicode.len(key) ~= unicode.len(str) then
		--normalize strips out the spaces, so lets add them back in
		for i, space in unicode.gmatch(str, "()(%s+)") do
			key = unicode.gsub(key, "^("..unicode.sub(key, 1, i-1)..")", "%1"..space)
		end
	end
	return key, str
end

function lf.UpdateEntriesString(AC)
	AC.entries_string = ""
	for key, entry in pairs(AC.entries) do
		AC.entries_string = AC.entries_string..c_Separator..key
	end
end

function lf.DisplayList(AC)
	local show_arrows = false
	local num_matches = #AC.matches
	local max_matches = #AC.ENTRIES
	if AC.too_many_matches and num_matches > max_matches then
		AC.highlight_index = -1
		AC.TITLE:SetTextKey("CHAT_AUTOCOMPLETE_TOO_MANY_MATCHES")
		AC.TITLE:SetDims("right:_; left:0;")
		AC.TAB_ICON:Hide()
		for i = 1, max_matches do
			lf.DisplayTextInEntry(AC, i, nil, show_arrows)
		end
	elseif num_matches == 0 then
		AC.highlight_index = -1
		AC.TITLE:SetTextKey("CHAT_AUTOCOMPLETE_NO_MATCHES")
		AC.TITLE:SetDims("right:_; left:0;")
		AC.TAB_ICON:Hide()
		for i = 1, max_matches do
			lf.DisplayTextInEntry(AC, i, nil, show_arrows)
		end
	else
		AC.highlight_index = _math.clamp(AC.highlight_index, 1, math.min(num_matches, max_matches))
		AC.TITLE:SetTextKey("CHAT_AUTOCOMPLETE_SELECTS_HIGHLIGHTED")
		AC.TITLE:SetDims("left:160t; right:_;")
		AC.TAB_ICON:Show()
		show_arrows = num_matches > 1
		for i = 1, max_matches do
			lf.DisplayTextInEntry(AC, i, AC.matches[i], show_arrows)
		end
	end
	AC.UP_ARROW:Show(show_arrows)
	AC.DOWN_ARROW:Show(show_arrows)
	lf.QueueResizeGroup(AC)
end

function lf.DisplayTextInEntry(AC, i, match, show_arrows)
	if match then
		AC.ENTRIES[i].TEXT:SetText(match.text)
		AC.ENTRIES[i].TEXT:SetTextColor(c_EntryColor)
		AC.ENTRIES[i].TEXT:SetTextColor(c_TypedColor, nil, match.start, match.stop)
		if show_arrows then
			AC.ENTRIES[i].GROUP:SetDims("left:_; width:100%-"..AC.UP_ARROW:GetBounds().width + c_ArrowToTextPadding)
		else
			AC.ENTRIES[i].GROUP:SetDims("left:_; width:100%")
		end
		if AC.highlight_index == i then
			AC.ENTRIES[i].HIGHLIGHT:SetParam("alpha", c_HighlightAlpha)
		else
			AC.ENTRIES[i].HIGHLIGHT:SetParam("alpha", 0)
		end
		AC.ENTRIES[i].GROUP:Show()
	else
		AC.ENTRIES[i].TEXT:SetText("")
		AC.ENTRIES[i].GROUP:Hide()
	end
end

function lf.SortMatches(a, b)
	if a.word_start ~= b.word_start then
		return a.word_start
	elseif a.start ~= b.start then
		return a.start < b.start
	else
		return a.text < b.text
	end
end

function lf.DisplaySearch(AC)
	table.sort(AC.matches, lf.SortMatches)
	lf.DisplayList(AC)
	AC:Show(true)
end

function lf.SetPendingData(AC)
	g_PendingIndex = g_PendingIndex + 1
	g_PendingData[g_PendingIndex] = AC
	return g_PendingIndex
end

function lf.GetPendingData(index)
	local AC = g_PendingData[index]
	g_PendingData[index] = nil
	return AC
end
