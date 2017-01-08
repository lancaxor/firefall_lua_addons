
-- ------------------------------------------
-- lib_ChatLib
--   by: Brian Blose
-- ------------------------------------------

ChatLib = {}

require "unicode"
require "table"
require "lib/lib_math"
require "lib/lib_table"
require "lib/lib_Liaison"
require "lib/lib_Items"
require "lib/lib_Tooltip"
require "lib/lib_TextFormat"
require "lib/lib_ContextualMenu"
require "lib/lib_PlayerContextualMenu"
require "lib/lib_MovablePanel"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local ProcessLink = {}
local lf = {} --table of local functions
local lcb = {} --table for liaison callbacks

local TOOLTIP_FRAME = false		--gets created upon first use
local TOOLTIP_POPUP = false		--gets created upon first use
local TOOLTIP_STICKY = false	--gets created upon first use

local c_ItemLinkId			= "i"
local c_CoordLinkId			= "c"
local c_PlayerLinkId		= "p"

local c_Endcap				= "~"	--needs to be a unique char to prevent false matches
local c_PairBreak			= "|"
local c_DataBreak			= ":"
local c_NegDataBreak		= ";"

local c_VisualStartCap		= "["
local c_VisualStopCap		= "]"

local c_PreserveDecimal		= 10000

local c_ChatComponent = "chat"
local c_ComponentName = Component.GetInfo()

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_IgnoreListNeedsUpdating = true
local g_RegisteredToReceiveIgnoreListUpdates = false
local g_IgnoreList
local g_NormalizedPlayerName
local g_CustomLinkTypes = {}
local g_CustomCoordMenuOptions = {}

-- ------------------------------------------
-- GENERAL FUNCTIONS
-- ------------------------------------------
ChatLib.SystemMessage = function(args)
	--[[
		System messages appear on whichever tab is active, used for direct feedback based on player action (ie: whispering an offline player, doing a slash command wrong)
		args.text = translated text
		args.key = localization key string
		args.replace = replace system for the key string. Works as either a string for a single replace or as an array for multiple ones
		args.replace_key = replace system for the key string. Splices a single keystring into another
	--]]
	args.channel = "system"
	Component.GenerateEvent("MY_SYSTEM_MESSAGE", {json=tostring(args)})
end

ChatLib.Notification = function(args)
	--[[
		Notification messages appear on selected tabs, used for feedback that triggers via events outside of the player's control (ie: friend online/offline messages)
		args.text = translated text
		args.key = localization key string
		args.replace = replace system for the key string. Works as either a string for a single replace or as an array for multiple ones
		args.replace_key = replace system for the key string. Splices a single keystring into another
	--]]
	args.channel = "notification"
	Component.GenerateEvent("MY_SYSTEM_MESSAGE", {json=tostring(args)})
end

ChatLib.ChatFormatMessage = function(TF, channel, author, author_id)
	--[[ Usage:
		TF =  chat message in TextFormat from from lib_TextFormat
		channel = channel the message will appear in, nil/false means whisper
		author = author of the message, not required
		author_id = use nil/false if the author is not a player's name, else use char_id/true; used to determine if the name is clickable for a player contextual menu popup
	--]]
	assert(TextFormat.IsTextFormat(TF), "ChatLib.ChatFormatMessage: first param must be a TextFormat obj")
	local params = {
		message_TF = TF,
		channel = channel,
		author = author,
		author_id = author_id,
	}
	Component.GenerateEvent("MY_CHAT_TEXT_FORMAT_MESSAGE", {json=tostring(params)})
end

ChatLib.AddTextToChatInput = function(args)
	--[[
		Used to add text to the current text in the chat's input box
		NOTE: will be ignored if not currently in cursor mode as the input box only is visible at that time
		args.text = text to add to chat's input box
		args.replaces = and array of replace tables for replacing the text with different text for sending ie: item links should have text that is readable with a replace that is the encoded link
				match = string that will be replaced, normally will bet he same as args.text
				replace = string that will replace the match string in the text on sending
	--]]
	Component.GenerateEvent("MY_ADD_CHAT_INPUT", {json=tostring(args)})
end

ChatLib.IsPlayerIgnored = function(name)
	--[[
		Supply a name to find out if the player is on the ignore list
		will always return false if called before the ON_PLAYER_READY event
	--]]
	if g_IgnoreListNeedsUpdating then
		if not g_NormalizedPlayerName and Player then --make sure the Player name space is loaded and ready
			g_NormalizedPlayerName = normalize(Player.GetInfo())
		end
		if g_NormalizedPlayerName then
			g_IgnoreList = Component.GetSetting(c_ChatComponent, "IGNORE_LIST_"..g_NormalizedPlayerName)
			g_IgnoreListNeedsUpdating = false
		end
		if not g_RegisteredToReceiveIgnoreListUpdates then
			Liaison.SendMessage(c_ChatComponent, "GetIgnoreListUpdates", c_ComponentName)
			g_RegisteredToReceiveIgnoreListUpdates = true
		end
	end
	if g_IgnoreList and g_IgnoreList[normalize(name)] then
		return true
	else
		return false
	end
end

ChatLib.StripArmyTag = function(name)
	--Strips army tags off of names
	assert(type(name) == "string", "Usage: name = ChatLib.StripArmyTag(name)")
	return unicode.gsub(name, "%s*%[.+%]%s*", "")
end

-- ------------------------------------------
-- TEXT LINK GENERAL FUNCTIONS
-- ------------------------------------------
ChatLib.GetEndcapString = function()
	-- this string starts and ends a link and is used to detect links
	---- it should never change, but just incae it needs to
	return c_Endcap
end

ChatLib.GetLinkTypeIdBreak = function()
	--this string is used to detect the link's type id
	---- endcap..linkId..linkTypeIdBreak
	return c_PairBreak
end

ChatLib.RegisterCustomLinkType = function(link_type, func)
	--[[ Usage:
		will tell chat to send the data of any receive links of supplied type to the supplied function
		the type muse be a unique type that is more then one letter as one letter types are reserved for vanilla use
		function will receive an args table with
			link_type = the same as what you used to register with
			link_data = the data of the link
			author = name of the person that sent the link
			channel = the chat channel used to to send the link
	--]]
	assert(type(link_type) == "string" and unicode.len(link_type) > 1, "param1 must be a string with more then one letter")
	assert(type(func) == "function", "param2 must be a function")
	g_CustomLinkTypes[link_type] = func
	Liaison.RemoteCall(c_ChatComponent, "RegisterCustomLinkType", link_type, c_ComponentName)
end

ChatLib.ProcessLink = function(typeId, data)
	if typeId and ProcessLink[typeId] then
		return ProcessLink[typeId](data)
	else
		--ignore links of an unhandled type, since this might be on purpose
		return nil
	end
end

-- ------------------------------------------
-- ITEM LINK FUNCTIONS
-- ------------------------------------------
ChatLib.EncodeItemLink = function(itemTypeId, hidden_modules, slotted_modules)
	assert(itemTypeId, "ChatLib.EncodeItemLink: itemTypeId is nil")
	hidden_modules = hidden_modules or {}
	slotted_modules = slotted_modules or {}
	itemTypeId = tostring(itemTypeId)
	local link = c_ItemLinkId..c_PairBreak..lf.Compress(itemTypeId)..c_PairBreak
	local hidden_modules_count = #hidden_modules
	for i = 1, hidden_modules_count do
		local moduleId = hidden_modules[i]
		if moduleId then
			link = link..lf.Compress(moduleId)
		end
		if i < hidden_modules_count then
			link = link..c_DataBreak
		end
	end
	link = link..c_PairBreak
	local slotted_modules_count = #slotted_modules
	for i = 1, slotted_modules_count do
		local moduleId = slotted_modules[i]
		if moduleId then
			link = link..lf.Compress(moduleId)
		end
		if i < slotted_modules_count then
			link = link..c_DataBreak
		end
	end
	return c_Endcap..link..c_Endcap
end

ChatLib.CreateItemLink = function(itemTypeId, hidden_modules, slotted_modules)
	assert(itemTypeId, "ChatLib.CreateItemLink: itemTypeId is nil")
	hidden_modules = hidden_modules or {}
	slotted_modules = slotted_modules or {}
	--get info for tooltips
	local itemInfo = Game.GetItemInfoByType(itemTypeId, hidden_modules, slotted_modules)
	local color = LIB_ITEMS.GetItemColor(itemInfo)
	local name = ChatLib.CreateItemText(itemInfo)
	--define events
	local events = {
		["OnMouseEnter"] = function()
			lf.EnsureTooltipPopupExists()
			TOOLTIP_POPUP:DisplayInfo(itemInfo)
			local compare_info = LIB_ITEMS.GetMatchingEquippedItemInfo(itemInfo)
			if compare_info then
				TOOLTIP_POPUP:CompareAgainst(compare_info)
			end
			TOOLTIP_POPUP:DisplayPaperdoll(true)
			local args = TOOLTIP_POPUP:GetBounds()
			args.delay = c_TooltipPopupDelay
			Tooltip.Show(TOOLTIP_POPUP.GROUP, args)
		end,
		["OnMouseLeave"] = function()
			Tooltip.Show(nil)
		end,
		["OnMouseDown"] = function()
			lf.EnsureTooltipStickyExists()
			TOOLTIP_FRAME:SetDims("right:_; width:300")
			TOOLTIP_STICKY:DisplayInfo(itemInfo)
			local bounds = TOOLTIP_STICKY:GetBounds()
			TOOLTIP_FRAME:SetDims("right:_; top:_; height:"..(bounds.height+20).."; width:"..(bounds.width+20))
			TOOLTIP_FRAME:Show()
		end,
		["OnRightMouse"] = function() --Perhaps this should be a context menu
			ChatLib.AddItemLinkToChatInput(itemTypeId, hidden_modules, slotted_modules)
		end,
	}
	--Process TF
	local TF = TextFormat.Create()
	TF:AppendColor(color)
	TF:AppendFocusText(name, events)
	return TF, name
end

ChatLib.CreateItemText = function(itemInfo)
	--process inline text
	local name = c_VisualStartCap..itemInfo.name..c_VisualStopCap
	return name
end

ChatLib.AddItemLinkToChatInput = function(itemTypeId, hidden_modules, slotted_modules)
	assert(itemTypeId, "ChatLib.AddItemLinkToChatInput: itemTypeId is nil")
	hidden_modules = hidden_modules or {}
	slotted_modules = slotted_modules or {}
	itemTypeId = tostring(itemTypeId)
	local itemInfo = Game.GetItemInfoByType(itemTypeId, hidden_modules, slotted_modules)
	local name = ChatLib.CreateItemText(itemInfo)
	local args = {
		text = name,
		replaces = {{
			match = name,
			replace = ChatLib.EncodeItemLink(itemTypeId, hidden_modules, slotted_modules)
		}},
	}
	ChatLib.AddTextToChatInput(args)
end

ProcessLink[c_ItemLinkId] = function(data)
	local itemTypeId
	local hidden_modules = {}
	local slotted_modules = {}
	local section = 1
	--process link data
	data = data..c_PairBreak --adding a closing pair break to make the gmatch easier
	local match_string = "(.-)(["..c_DataBreak..c_PairBreak.."])"
	for a, b in unicode.gmatch(data, match_string) do
		if a ~= "" then
			a = lf.Decompress(a)
		else
			--a = nil
		end
		if section == 1 then
			itemTypeId = a
		elseif section == 2 then
			table.insert(hidden_modules, a)
		elseif section == 3 then
			table.insert(slotted_modules, a)
		end
		if b == c_PairBreak then
			section = section + 1
		end
	end
	if itemTypeId then
		return ChatLib.CreateItemLink(itemTypeId, hidden_modules, slotted_modules)
	else
		return nil, nil
	end
end

-- ------------------------------------------
-- COORDINATE LINK FUNCTIONS
-- ------------------------------------------
ChatLib.EncodeCoordLink = function(pos, zoneId, instance, playerId)
	pos = pos or Player.GetPosition()
	zoneId = zoneId or Game.GetZoneId()
	instance = instance or Chat.WriteInstanceKey()
	playerId = playerId or Player.GetCharacterId()
	local link = c_CoordLinkId..c_PairBreak..lf.Compress(playerId, true)..c_DataBreak..lf.Compress(instance, true)..c_DataBreak..lf.Compress(zoneId)
	local function addToLink(loc)
		local value_break = c_DataBreak
		if loc < 0 then
			value_break = c_NegDataBreak
			loc = -loc
		end
		loc = math.floor(0.5 + (loc * c_PreserveDecimal))
		link = link..value_break..lf.Compress(loc)
	end
	addToLink(pos.x)
	addToLink(pos.y)
	addToLink(pos.z)
	return c_Endcap..link..c_Endcap
end

ChatLib.CreateCoordLink = function(pos, zoneId, playerId, instance)
	local same_zone = isequal(Game.GetZoneId(), zoneId)
	local same_instance = same_zone and Chat.CheckSameInstance(playerId, instance)
	local text = ChatLib.CreateCoordText(pos, zoneId, same_instance)
	local ShowContextMenu = function()
		local squad = Squad.GetRoster()
		local CONTEXTMENU = ContextualMenu.Create()
		if same_instance then
			CONTEXTMENU:AddLabel({label=unicode.sub(text, 2, -2), color=ContextualMenu.default_label_color})
		else
			CONTEXTMENU:AddLabel({label_key="TEXTLINK_DIFFERENT_INSTANCE", color=ContextualMenu.default_label_color})
		end
		




		CONTEXTMENU:AddButton({label_key="SET_WAYPOINT", disable=not same_instance}, function(args)
			Component.GenerateEvent("MY_PERSONAL_WAYPOINT_SET", {x=pos.x, y=pos.y, z=pos.z+1})
		end)
		if squad and squad.is_mine then
			CONTEXTMENU:AddButton({label_key="SET_SQUAD_WAYPOINT", disable=not same_instance}, function(args)
				Squad.SetWayPoint(pos.x, pos.y, pos.z+1) --lift the waypoint up off of the linking players feet
			end)
		end
		
		if g_CustomCoordMenuOptions.__root then
			local MatchBool = function(key, bool)
				if key == "same_zone" then
					return same_zone == bool
				elseif key == "same_instance" then
					return same_instance == bool
				elseif key == "in_squad" then
					return Squad.IsInSquad() == bool
				elseif key == "in_platoon" then
					return Platoon.IsInPlatoon() == bool
				elseif key == "in_group" then
					return (squad~=nil) == bool
				elseif key == "group_leader" then
					return squad and (squad.is_mine == bool)
				end
			end
			local AddCustomEntries
			AddCustomEntries = function(MENU, menu_id)
				for _, option in pairs(g_CustomCoordMenuOptions[menu_id]) do
					local show = true
					if option._show then
						for key, bool in pairs(option._show) do
							local value = MatchBool(key, bool)
							if value ~= nil then
								show = show and value
							end
							if not show then break end
						end
					elseif option._hide then
						for key, bool in pairs(option._hide) do
							local value = MatchBool(key, bool)
							if value ~= nil then
								show = show and value
							end
							if not show then break end
						end
						show = not show
					end
					if show then
						local enable = true
						if option._enable then
							for key, bool in pairs(option._enable) do
								local value = MatchBool(key, bool)
								if value ~= nil then
									enable = enable and value
								end
								if not enable then break end
							end
						elseif option._disable then
							for key, bool in pairs(option._disable) do
								local value = MatchBool(key, bool)
								if value ~= nil then
									enable = enable and value
								end
								if not enable then break end
							end
							enable = not enable
						end
						local params = _table.copy(option)
						params.disable = not enable
						local ENTRY = MENU[option.method](MENU, params, function(args)
							args.pos = pos
							args.zoneId = zoneId
							args.same_zone = same_zone
							args.same_instance = same_instance
							Liaison.RemoteCall(option.component, "CustomCoordLinkTriggered", menu_id, option.id, args)
						end)
						if option.method == "AddMenu" then
							AddCustomEntries(ENTRY, option.id)
						end
					end
				end
			end
			AddCustomEntries(CONTEXTMENU, "__root")
		end
		CONTEXTMENU:Show()
	end
	local events = {
		OnMouseDown = ShowContextMenu,
		OnRightMouse = ShowContextMenu,
	}
	--Process TF
	local TF = TextFormat.Create()
	TF:AppendColor("GenericTextLink")
	TF:AppendFocusText(text, events)
	return TF, text
end

ChatLib.AddCoordMenuOption = function(args)
	--[[ Example args:
		--required
		func = function						--function to call when option is triggered
		method = "AddButton",				--context menu method
		- plus any other bits required by the context menu for the choosen method
		--optional
		menu_id = "__root",					--id of submenu if it is not in the root
		_show = {},							--table of required values grouped in AND logic; mutually exclusive with hide
		_hide = {},							--table of required values grouped in AND logic; mutually exclusive with show
		_enable = {},						--table of required values grouped in AND logic; mutually exclusive with disable
		_disable = {},						--table of required values grouped in AND logic; mutually exclusive with enable
		--show/hide/enable/disable options
		same_zone = bool					--requires the same_zone value to math the bool
		same_instance = bool				--requires the same_instance value to math the bool
		in_squad = bool						--requires bool == Squad.IsInSquad()
		in_platoon = bool					--requires bool == Platoon.IsInPlatoon()
		in_group = bool						--requires bool == (Squad.IsInSquad() or Platoon.IsInPlatoon())
		group_leader = bool					--requires bool == group.is_mine; check is skipped if not in a group
	--]]
	args.menu_id = args.menu_id or "__root"
	assert(args.id, "id is required for all options")
	if args.method == "AddMenu" and not g_CustomCoordMenuOptions[args.id] then
		g_CustomCoordMenuOptions[args.id] = {}
	end
	if not g_CustomCoordMenuOptions[args.menu_id] then
		g_CustomCoordMenuOptions[args.menu_id] = {}
	end
	g_CustomCoordMenuOptions[args.menu_id][args.id] = args
	if c_ComponentName ~= c_ChatComponent then
		args.component = c_ComponentName
		Liaison.RemoteCall(c_ChatComponent, "_ChatLib_AddCoordMenuOption", args)
	end
end
Liaison.BindCall("_ChatLib_AddCoordMenuOption", ChatLib.AddCoordMenuOption)

ChatLib.CreateCoordText = function(pos, zoneId, same_instance)
	local str = unicode.format("%0.0f, %0.0f", pos.x, pos.y)
	if not same_instance then
		local zone_info = Game.GetZoneInfo(zoneId)
		if zone_info then
			str = zone_info.main_title.." "..str
		end
	end
	return c_VisualStartCap..str..c_VisualStopCap
end

ProcessLink[c_CoordLinkId] = function(data)
	--process link data
	local match_string = "(.-)"..c_DataBreak.."(.-)"..c_DataBreak.."(.-)(["..c_DataBreak..c_NegDataBreak.."])(.-)(["..c_DataBreak..c_NegDataBreak.."])(.-)(["..c_DataBreak..c_NegDataBreak.."])(.+)"
	local playerId, instance, zoneId, x_sign, x, y_sign, y, z_sign, z = unicode.match(data, match_string)
	if playerId and instance and zoneId and x_sign and x and y_sign and y and y_sign and y then
		playerId = lf.Decompress(playerId, true)
		instance = lf.Decompress(instance, true)
		zoneId = lf.Decompress(zoneId)
		x = lf.Decompress(x)
		y = lf.Decompress(y)
		z = lf.Decompress(z)
		local pos = {}
		pos.x = (x / c_PreserveDecimal) * ((tonumber(x_sign == c_DataBreak) * 2) - 1)
		pos.y = (y / c_PreserveDecimal) * ((tonumber(y_sign == c_DataBreak) * 2) - 1)
		pos.z = (z / c_PreserveDecimal) * ((tonumber(z_sign == c_DataBreak) * 2) - 1)
		return ChatLib.CreateCoordLink(pos, zoneId, playerId, instance)
	else
		return nil, nil
	end
end

-- ------------------------------------------
-- PLAYER LINK FUNCTIONS
-- ------------------------------------------
ChatLib.EncodePlayerLink = function(playerName)
	if type(playerName) ~= "string" or playerName == "" then
		warn("EncodePlayerLink: invalid playername")
		return ""
	else
		return c_Endcap..c_PlayerLinkId..c_PairBreak..playerName..c_Endcap
	end
end

ChatLib.CreatePlayerLink = function(playerName)
	if type(playerName) == "string" and playerName ~= "" then
		local OnClick = function()
			PlayerMenu.Show(playerName, "PlayerLink")
		end
		local events = {
			OnMouseDown = OnClick,
			OnRightMouse = OnClick,
		}
		--Process TF
		local TF = TextFormat.Create()    
		TF:AppendFocusText(playerName, events)
		return TF, playerName
	else
		return nil, nil
	end
end
ProcessLink[c_PlayerLinkId] = ChatLib.CreatePlayerLink

-- ------------------------------------------
-- LIAISON CALLBACK FUNCTIONS
-- ------------------------------------------
function lcb.IgnoreListUpdated()
	g_IgnoreListNeedsUpdating = true
end

function lcb.ReceivedCustomLink(args)
	--args = {link_type, link_data, author, channel}
	local func = g_CustomLinkTypes[args.link_type]
	if func then
		func(args)
	else
		warn("Link Type: "..args.link_type.." was not registered by this component")
	end
end

function lcb.CustomCoordLinkTriggered(menu_id, id, args)
	if g_CustomCoordMenuOptions[menu_id] and g_CustomCoordMenuOptions[menu_id][id] then
		g_CustomCoordMenuOptions[menu_id][id].func(args)
	end
end
Liaison.BindCallTable(lcb)

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.EnsureTooltipFrameExists()
	if not TOOLTIP_FRAME then
		TOOLTIP_FRAME = Component.CreateFrame("PanelFrame", "ChatLib_TooltipFrame")
		TOOLTIP_FRAME:SetDims("right:75%; top:25%; width:300; height:400;")
		TOOLTIP_FRAME:SetDepth(-5)
		TOOLTIP_FRAME:Hide()
	end
end

function lf.EnsureTooltipPopupExists()
	if not TOOLTIP_POPUP then
		lf.EnsureTooltipFrameExists()
		local group = Component.CreateWidget([[<Group dimensions="dock:fill" style="visible:false"/>]], TOOLTIP_FRAME)
		TOOLTIP_POPUP = LIB_ITEMS.CreateToolTip(group)
	end
end

function lf.EnsureTooltipStickyExists()
	if not TOOLTIP_STICKY then
		lf.EnsureTooltipFrameExists()
		local GROUP = Component.CreateWidget(
			[[<Group dimensions="dock:fill">
				<Border dimensions="center-x:50%; center-y:50%; width:100%-2; height:100%-2" class="ButtonSolid" style="tint:#000000; alpha:0.75; padding:6"/> 
				<Border name="rim" dimensions="dock:fill" class="ButtonBorder" style="alpha:0.1; exposure:1.0; padding:6"/>
				<Group name="contents" dimensions="left:5; right:100%-5; top:5; bottom:100%-5"/>
			</Group>]], TOOLTIP_FRAME)
		local CONTENTS = GROUP:GetChild("contents")
		TOOLTIP_STICKY = LIB_ITEMS.CreateToolTip(CONTENTS)
		local MOVABLE_PARENT = Component.CreateWidget("<Group dimensions='dock:fill'/>", TOOLTIP_FRAME)
		MovablePanel.ConfigFrame({
			frame = TOOLTIP_FRAME,
			MOVABLE_PARENT = MOVABLE_PARENT,
		})
		local CLOSE_BUTTON = Component.CreateWidget(
			[[<FocusBox dimensions="right:100%-5; top:5; width:16; height:16;" class="ui_button">
				<Border class="SmallBorders" dimensions="dock:fill" style="alpha:0.5; padding:4"/>
				<StillArt name="X" dimensions="center-x:50%; center-y:50%; width:100%-8; height:100%-8" style="texture:Window; region:X; tint:#B82F06; eatsmice:false"/>
			</FocusBox>]], TOOLTIP_FRAME)
		
		CLOSE_BUTTON:BindEvent("OnMouseDown", function()
			TOOLTIP_FRAME:Hide()
		end)
		local X = CLOSE_BUTTON:GetChild("X")
		CLOSE_BUTTON:BindEvent("OnMouseEnter", function() X:ParamTo("exposure", 1, 0.15) end)
		CLOSE_BUTTON:BindEvent("OnMouseLeave", function() X:ParamTo("exposure", 0, 0.15) end)
	end
end

function lf.Compress(number, base)
	base = base or 64
	return _math.Base10ToBaseN(number, base)
end

function lf.Decompress(number, base)
	base = base or 64
	return _math.BaseNToBase10(number, base)
end
