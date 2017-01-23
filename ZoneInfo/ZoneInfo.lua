-----------------------------------------------------------------------------------
-- ZoneInfo by CookieDuster
-----------------------------------------------------------------------------------
-- Inspired by TinyOnlineList
-- Uses Fing by Kristakis
-- Thanks to Whraith for testing
-----------------------------------------------------------------------------------

require "math";
require "string";
require "table";
require "lib/lib_InterfaceOptions"
require "lib/lib_Slash"
require "lib/lib_Callback2"
require "./lib/Fing"
require "./lib/lib_CDOptions"
require "lib/lib_Debug"

local StringFind = string.find 
local StringSub = string.sub
local StringLen = string.len
local StringLower = string.lower
local StringMatch = string.match
local StringGsub = string.gsub

------------
-- CONSTANTS
------------

local OPTIONSLOOKUPTABLE = {} -- generated later, functions as a constant
InterfaceOptions.NotifyOnDisplay(true)
InterfaceOptions.NotifyOnLoaded(true)
local PLUGIN_NAME = "ZoneInfo"


------------
-- VARIABLES
------------


local CUI = {} -- container for everything

function OnComponentLoad()
	CUI.Common = UiElement:new({label="Common", id="common"})
	CUI.Common:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil})
	CUI.Common:AddTextInput({id="dateformat", label="Date format", default=true, tooltip="Use os.date format string", default="%Y-%m-%d (%A) %H:%M:%S"})
	
	CUI.Common:StartGroup({id="systemmessages", label="System message on zone change"})
	CUI.Common:AddCheckBox({id="loginlast", label="Last in zone", default=false, callback=nil, element=nil})
	CUI.Common:AddCheckBox({id="loginid", label="Zone ID", default=false, callback=nil, element=nil})
	CUI.Common:AddCheckBox({id="loginfing", label="Zone FING", default=false, callback=nil, element=nil})
	--CUI.Common:AddCheckBox({id="loginplayers", label="Number of players", default=false, callback=nil, element=nil})
	CUI.Common:StopGroup()

	CUI.Id = UiElement:new({frame="ZoneInfoIdFrame", label="Zone ID", scalable=true, id="id"})
	CUI.Id:AddElement({id="text", xmlid="ZoneInfoIdText"})
	CUI.Id:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Zone ID"})
	CUI.Id:AddTextInput({id="prefix", label="Prefix", default="ID: ", callback="ProcessPrefix", element="text", subtab="Zone ID"})
	CUI.Id:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Zone ID"})
	CUI.Id:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Zone ID"})
	CUI.Id:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Zone ID"})
	CUI.Id:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Zone ID"})
	CUI.Id:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Zone ID"})
	
	CUI.Army = UiElement:new({frame="ZoneInfoArmyFrame", label="Army counter", scalable=true, id="army"})
	CUI.Army:AddElement({id="text", xmlid="ZoneInfoArmyText"})
	CUI.Army:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Army counter"})
	CUI.Army:AddTextInput({id="prefix", label="Prefix", default="Army: ", callback="ProcessPrefix", element="text", subtab="Army counter"})
	CUI.Army:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Army counter"})
	CUI.Army:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Army counter"})
	CUI.Army:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Army counter"})
	CUI.Army:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Army counter"})
	CUI.Army:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Army counter"})
	CUI.Army:AddCheckBox({id="slashnames", label="Display names in slash command", default=false, callback=nil, element=nil, subtab="Army counter"})
	CUI.Army:AddTextInput({id="slashlimit", label="Display name limit in slash command", default=30, numeric=true, callback="ProcessNumeric", subtab="Army counter"})
	
	CUI.ArmyList = UiElement:new({frame="ZoneInfoArmyListFrame", label="Army list", scalable=true, id="armylist"})
	CUI.ArmyList:AddElement({id="text", xmlid="ZoneInfoArmyListText"})
	CUI.ArmyList:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Army list"})
	CUI.ArmyList:AddTextInput({id="prefix", label="Prefix", default="Army:", callback="ProcessPrefix", element="text", subtab="Army list"})
	CUI.ArmyList:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Army list"})
	CUI.ArmyList:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Army list"})
	CUI.ArmyList:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Army list"})
	CUI.ArmyList:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Army list"})
	CUI.ArmyList:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Army list"})
	CUI.ArmyList:AddTextInput({id="limit", label="Display name limit", default=30, numeric=true, element="text", callback="ProcessNumeric", subtab="Army list"})
	CUI.ArmyList:AddCheckBox({id="hidealone", label="Hide when alone", default=true, callback=nil, element=nil, subtab="Army list"})

	CUI.Nearby = UiElement:new({frame="ZoneInfoNearbyFrame", label="Nearby counter", scalable=true, id="nearby"})
	CUI.Nearby:AddElement({id="text", xmlid="ZoneInfoNearbyText"})
	CUI.Nearby:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Nearby counter"})
	CUI.Nearby:AddTextInput({id="prefix", label="Prefix", default="Nearby: ", callback="ProcessPrefix", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Nearby counter"})
	CUI.Nearby:AddCheckBox({id="slashnames", label="Display names in slash command", default=false, callback=nil, element=nil, subtab="Nearby counter"})
	CUI.Nearby:AddTextInput({id="slashlimit", label="Display name limit in slash command", default=30, numeric=true, callback="ProcessNumeric", subtab="Nearby counter"})

	CUI.NearbyList = UiElement:new({frame="ZoneInfoNearbyListFrame", label="Nearby list", scalable=true, id="nearbylist"})
	CUI.NearbyList:AddElement({id="text", xmlid="ZoneInfoNearbyListText"})
	CUI.NearbyList:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Nearby list"})
	CUI.NearbyList:AddTextInput({id="prefix", label="Prefix", default="Nearby:", callback="ProcessPrefix", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Nearby list"})
	CUI.NearbyList:AddTextInput({id="limit", label="Display name limit", default=30, numeric=true, element="text", callback="ProcessNumeric", subtab="Nearby list"})
	CUI.NearbyList:AddCheckBox({id="hidealone", label="Hide when alone", default=true, callback=nil, element=nil, subtab="Nearby list"})

	CUI.Friend = UiElement:new({frame="ZoneInfoFriendFrame", label="Friend counter", scalable=true, id="Friend"})
	CUI.Friend:AddElement({id="text", xmlid="ZoneInfoFriendText"})
	CUI.Friend:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Friend counter"})
	CUI.Friend:AddTextInput({id="prefix", label="Prefix", default="Friends: ", callback="ProcessPrefix", element="text", subtab="Friend counter"})
	CUI.Friend:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Friend counter"})
	CUI.Friend:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Friend counter"})
	CUI.Friend:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Friend counter"})
	CUI.Friend:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Friend counter"})
	CUI.Friend:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Friend counter"})
	CUI.Friend:AddCheckBox({id="slashnames", label="Display names in slash command", default=false, callback=nil, element=nil, subtab="Friend counter"})
	CUI.Friend:AddTextInput({id="slashlimit", label="Display name limit in slash command", default=30, numeric=true, callback="ProcessNumeric", subtab="Friend counter"})

	CUI.FriendList = UiElement:new({frame="ZoneInfoFriendListFrame", label="Friend list", scalable=true, id="Friendlist"})
	CUI.FriendList:AddElement({id="text", xmlid="ZoneInfoFriendListText"})
	CUI.FriendList:AddCheckBox({id="enabled", label="Enabled", default=true, callback="ProcessFrameEnabled", element=nil, subtab="Friend list"})
	CUI.FriendList:AddTextInput({id="prefix", label="Prefix", default="Friends:", callback="ProcessPrefix", element="text", subtab="Friend list"})
	CUI.FriendList:AddTextInput({id="suffix", label="Suffix", default="", callback="ProcessSuffix", element="text", subtab="Friend list"})
	CUI.FriendList:AddDropDown({id="valign", label="Vertical alignment", options=VALIGNMENTS, default="top", callback="ProcessVerticalAlignment", element="text", subtab="Friend list"})
	CUI.FriendList:AddDropDown({id="halign", label="Horizontal alignment", options=HALIGNMENTS, default="left", callback="ProcessHorizontalAlignment", element="text", subtab="Friend list"})
	CUI.FriendList:AddDropDown({id="font", label="Font", options=FONTS, default="Demi_10", callback="ProcessFont", element="text", subtab="Friend list"})
	CUI.FriendList:AddColorPicker({id="color", label="Color", default={alpha = 0.8, tint = "FFFFFF", exposure = 0}, callback="ProcessColor", element="text", subtab="Friend list"})
	CUI.FriendList:AddTextInput({id="limit", label="Display name limit", default=30, numeric=true, element="text", callback="ProcessNumeric", subtab="Friend list"})
	CUI.FriendList:AddCheckBox({id="hidealone", label="Hide when alone", default=true, callback=nil, element=nil, subtab="Friend list"})
	
	OPTIONSLOOKUPTABLE = GenerateOptionsLookupTable(CUI)

	InterfaceOptions.SetCallbackFunc(HandleInterfaceCallback, "ZoneInfo")	
	CUI.Id:SetData("iddb", Component.GetSetting("iddb"))

	CUI.Common.SlashUpdate = function(self)
		SystemMessage("Updating display...", "ZoneInfo")
		Initialize()
	end
	
	CUI.Nearby.DisplayList = function(self)
		local list = Game.GetAvailableTargets()
		local validlist = {}
		local counter = 0
		local name = Player.GetInfo()
		for index, item in pairs(list) do
			local info = Game.GetTargetInfo(item)
			if (info.type == "character" and info.isNpc == false and info.name ~= name) then
				--validlist[tostring(item)] = tostring(info.name)
				validlist[tostring(item)] = "["..tostring(info.battleframe).."] "..tostring(info.name).." ("..tostring(info.level)..")"
				counter = counter + 1
			end
		end
		if(CUI.Nearby:GetSetting("slashnames") == true) then
			SystemMessage(TableToCommaDelimitedList(validlist, CUI.Nearby:GetSetting("slashlimit")), "ZoneInfo")
		end
		SystemMessage("Nearby players: "..counter, "ZoneInfo")
	end

	CUI.Army.DisplayList = function(self)
		if(CUI.Army:GetSetting("slashnames") == true) then
			SystemMessage(TableIndexToCommaDelimitedList(CUI.ArmyList:GetData("players"), CUI.Army:GetSetting("slashlimit")))
		end
		SystemMessage("Online army members: "..CUI.Army:GetData("count"))
	end
	
	CUI.Id.DisplayId = function(self)
		SystemMessage("Zone ID: "..tostring(Chat.WriteInstanceKey()))
	end
	
	CUI.Common.ProcessFrameEnabled = function(self, poption, pvalue)
		CUI.Common:UpdateVisibility()
	end

	CUI.Common.UpdateVisibility = function(self, args)
		if (args == nil) then args = {} end
		for item, value in pairs(CUI) do
			local added = 0
			if(item == "Common") then
				--nothing
			elseif(item == "ArmyList") then
				table.insert(args, not (CUI.ArmyList:GetSetting("hidealone") and (CUI.Army:GetData("count") == 1 or CUI.Army:GetData("count") == 0 or CUI.Army:GetData("count") == nil)))
				added = added + 1
			elseif(item == "FriendList") then
				table.insert(args, not (CUI.FriendList:GetSetting("hidealone") and (CUI.Friend:GetData("count") == 0 or CUI.Friend:GetData("count") == nil)))
				added = added + 1
			elseif(item == "NearbyList") then
				table.insert(args, not (CUI.NearbyList:GetSetting("hidealone") and (CUI.Nearby:GetData("count") == 0 or CUI.Nearby:GetData("count") == nil)))
				added = added + 1
			end
			
			if item ~= "Common" then
				table.insert(args, CUI[item]:GetSetting("enabled"))
				table.insert(args, CUI.Common:GetSetting("enabled"))
				added = added + 2
				CUI[item]:UpdateVisibility("text", args)
				for i=1,added do
					table.remove(args, #args) -- if it looks stupid, but it works, it ain't stupid
				end
			end
		end
	end
	
	CUI.Id.Init = function(self, force)
		local id = tostring(Chat.WriteInstanceKey())
		self:SetData("id", id)
		self:SetData("iddb", id, tonumber(System.GetLocalUnixTime()))
		Component.SaveSetting("iddb", self:GetData("iddb"))
		self:SetText(id)
		self:SetData("ready", true)
	end
	
	CUI.Id.Clear = function(self, force)
		CUI.Id:SetData("iddb", {})
		Component.SaveSetting("iddb", {})
		SystemMessage("Cleared last login database.", "ZoneInfo")
	end
	
	CUI.Id.DisplayLastLogin = function(self)
		local timestamp = CUI.Id:GetData("iddb", tostring(Chat.WriteInstanceKey()))
		if timestamp then
			SystemMessage("Last login to current shard: "..System.GetDate(CUI.Common:GetSetting("dateformat"), timestamp))
		else
			SystemMessage("Last login to current shard: never")
		end
	end
	
	CUI.Id.SetText = function(self, text)
		self.elements.text:SetText(tostring(self:GetSetting("prefix"))..text..tostring(self:GetSetting("suffix")))
	end
	
	CUI.Army.Init = function(self, force)
		local url = System.GetOperatorSetting("ingame_host").."/armies.json?page=1&per_page=3" 
		
		if army_roster and not force then -- we know the roster
			CUI.Army:ListHandler(army_roster)
		elseif army_path then -- we know the path, but not the roster
			GetRoster()
		else -- don't even know the army path
			AsyncRequest(url, "get", nil, ProcessArmyPath)
		end
	end
	
	function ProcessArmyPath(args)
		for index,item in pairs(args.tabs) do
			if item.class == "tab_icon_army_details" then
				army_path = item.path
				break
			end
		end
		GetRoster()
	end
	
	function GetRoster()
		if army_path then
			local url = System.GetOperatorSetting("ingame_host")..army_path..".json"
			AsyncRequest(url, "get", nil, StoreArmyRoster)
		end	
	end
	
	function StoreArmyRoster(resp)
		army_roster = resp.army_roster
		CUI.Army:ListHandler(army_roster)
	end
	
	CUI.Army.ListHandler = function(self, list)
		local count = 0
		local players = {}
		for i, member in pairs(list) do
			if (Chat.GetUserInfo(member.name) ~= nil) then
				players[member.name] = 1
				count = count + 1
			end
		end
		CUI.Army:SetData("count", count)
		CUI.ArmyList:SetData("players", players)
		CUI.Army:SetText(count)
		CUI.ArmyList:SetText(players)
		CUI.Army:SetData("ready", true)
		CUI.ArmyList:SetData("ready", true)
		CUI.ArmyList:UpdateVisibility("text", {CUI.Common:GetData("hud"), CUI.Common:GetSetting("enabled"), CUI.ArmyList:GetSetting("enabled"), not (CUI.ArmyList:GetSetting("hidealone") and (CUI.Army:GetData("count") == 1 or CUI.Army:GetData("count") == 0 or CUI.Army:GetData("count") == nil))})
		if not ArmyCountTimer then 
			ArmyCountTimer = Callback2.Create()
			ArmyCountTimer:Bind(function() CUI.Army:Init(true) end)
		end
		ArmyCountTimer:Reschedule(300)
	end

	CUI.Army.SetText = function(self, text)
		self.elements.text:SetText(self:GetSetting("prefix")..text..self:GetSetting("suffix"))
	end
	
	CUI.ArmyList.Init = function(self, text)
		--CUI.Army:Init()
	end
	
	CUI.ArmyList.SetText = function(self, text)
		self.elements.text:SetText(self:GetSetting("prefix").."\n"..TableIndexToList(text, self:GetSetting("limit"))..self:GetSetting("suffix"))
	end
	
	CUI.Nearby.Init = function (self, force)
		self:SetData("players", {})
		local list = Game.GetAvailableTargets()
		local validlist = {}
		local counter = 0
		local name = Player.GetInfo()
		for index, item in pairs(list) do
			local info = Game.GetTargetInfo(item)
			if (info.name and info.type == "character" and info.isNpc == false and tostring(info.name) ~= tostring(name)) then
				if (self:GetData("players", item) == nil) then

                    ---- here is user info
                    Debug.Log(info)
					validlist[tostring(item)] = "["..tostring(info.battleframe).. "] "..tostring(info.name).." ("..tostring(info.level) .. "/" .. tostring(info.elite_level) .. ")"
					counter = counter + 1
				end
			end
		end
		self:SetData("players", validlist)
		self:SetData("count", counter)
		self:SetText(counter)
		CUI.NearbyList:SetText(TableToOrderedList(validlist, CUI.NearbyList:GetSetting("limit")))
		self:SetData("ready", true)
		CUI.NearbyList:SetData("ready", true)
		if not NearbyTimer then
			NearbyTimer = Callback2.Create()
			NearbyTimer:Bind(function() CUI.Nearby:Init() end)
		end
		NearbyTimer:Schedule(60)
		if not NearbyTick then
			NearbyTick = Callback2.CreateCycle(CUI.Nearby.Tick, self)
			NearbyTick:Run(3)
		end
	end

	CUI.Nearby.Update = function(self, id, name, action)
		if not is_options_init then
			return
		end
		local player_name = Player.GetInfo()
		if tostring(player_name) == tostring(name) then
			return
		end
		if(action == 1) then
			self:SetData("players", id, name)
			self:SetData("count", self:GetData("count") + 1)
		elseif(action == -1) then
			self:DeleteData("players", id)
			self:SetData("count", self:GetData("count") - 1)
		else
			return nil
		end
	end
	
	CUI.Nearby.Tick = function (self)
		CUI.Nearby:SetText(self:GetData("count"))
		CUI.NearbyList:SetText(TableToOrderedList(CUI.Nearby:GetData("players"), CUI.NearbyList:GetSetting("limit")))
		CUI.NearbyList:UpdateVisibility("text", {CUI.Common:GetData("hud"), CUI.Common:GetSetting("enabled"), CUI.NearbyList:GetSetting("enabled"), not (CUI.NearbyList:GetSetting("hidealone") and (CUI.Nearby:GetData("count") == 0 or CUI.Nearby:GetData("count") == nil))})
	end

	CUI.Nearby.SetText = function(self, text)
		if self:GetSetting("prefix") then
			self.elements.text:SetText(self:GetSetting("prefix")..text..tostring(self:GetSetting("suffix")))
		else
			Callback2.FireAndForget(function() CUI.Nearby:SetText(text) end, nil, 0.5)
		end
	end

	CUI.NearbyList.SetText = function(self, text)
		if not self:GetSetting("prefix") then
			Callback2.FireAndForget(function() CUI.NearbyList:SetText(text) end, nil, 0.5)
		else
			self.elements.text:SetText(tostring(self:GetSetting("prefix")).."\n"..tostring(text)..tostring(self:GetSetting("suffix")))
		end
	end
	
	CUI.Friend.Init = function(self, force)
		local count = 0
		if not FriendsTimer then
			FriendsTimer = Callback2.Create()
			FriendsTimer:Bind(CUI.Friend.Init)
		end
		if not online_friends then online_friends = {} end
		if not online_friend_count then online_friend_count = 0 end
		local friends = nil --Friends.GetList()
		
		if friends == nil and not FriendsTimer:Pending() then
			FriendsTimer:Schedule(1)
			return
		end
		if friends ~= nil then
			for _,v in pairs(friends) do
				if(v.status_type == "AVAILABLE") then 
					online_friends[v.player_name] = true
					online_friend_count = online_friend_count + 1
					CUI.FriendList:SetData("players", v.unique_name, {name = v.player_name})
				end
			end
		end
		CUI.Friend:SetData("count", count)
		CUI.Friend:SetData("ready", true)
		CUI.Friend:SetText(online_friend_count)
		CUI.FriendList:SetText(TableIndexToList(online_friends))
		is_friend_init = true
		CUI.FriendList:UpdateVisibility("text", {CUI.Common:GetData("hud"), CUI.Common:GetSetting("enabled"), CUI.FriendList:GetSetting("enabled"), not (CUI.FriendList:GetSetting("hidealone") and (online_friend_count == 0 or online_friend_count == nil))})
		if not FriendsTimer:Pending() then
			FriendsTimer:Schedule(60)

		end
	end
	
	
	CUI.Friend.Update = function(self, args)
		if not is_friend_init then
			return
		end
		local name = Player.GetInfo()
		if args.unique_name == name then return end -- why is this even needed
		if args.status_type == "AVAILABLE" then
			if not online_friends[args.player_name] then
				online_friends[args.player_name] = true
				online_friend_count = online_friend_count + 1
			end
			--[[
			if (CUI.FriendList:GetData("players", args.unique_name) ~= nil) then return	end
			CUI.Friend:SetData("count", CUI.Friend:GetData("count") + 1)
			CUI.FriendList:SetData("players", args.unique_name, {name = args.player_name})
			--]]
		elseif args.status_type == "OFFLINE" then
			if online_friends[args.player_name] then
				online_friends[args.player_name] = nil
				online_friend_count = online_friend_count - 1
			end
			--[[
			if CUI.FriendList:GetData("players", args.unique_name) == nil then return end
			CUI.Friend:SetData("count", CUI.Friend:GetData("count") - 1)
			CUI.FriendList:DeleteData("players", args.unique_name)
			--]]
		end
		CUI.Friend:SetText(online_friend_count)
		
		CUI.FriendList:SetText(TableIndexToList(online_friends))
		
		
		CUI.FriendList:UpdateVisibility("text", {CUI.Common:GetData("hud"), CUI.Common:GetSetting("enabled"), CUI.FriendList:GetSetting("enabled"), not (CUI.FriendList:GetSetting("hidealone") and (online_friend_count == 0 or online_friend_count == nil))})
	end
	
	CUI.Friend.SetText = function(self, text)
		self.elements.text:SetText(tostring(self:GetSetting("prefix"))..tostring(text)..tostring(self:GetSetting("suffix")))
	end

	CUI.FriendList.Init = function(self, force)
		--CUI.Friend:Init()
	end
	
	CUI.FriendList.SetText = function(self, text)
		--[[
		local limit = CUI.FriendList:GetSetting("limit")
		local tmp = ""
		local count = 0
		for _,v in pairs(text) do -- custom TableToOrderedList
			tmp = tmp.."\n"..v.name
			count = count + 1
			if (limit ~= 0 and limit ~= nil and count >= limit) then break end
		end
		--]]
		self.elements.text:SetText(tostring(self:GetSetting("prefix")).."\n"..text..tostring(self:GetSetting("suffix")))
	end
	
	LIB_SLASH.BindCallback({slash_list = "zt", description = "[ZoneInfo] display", func=Test})
	LIB_SLASH.BindCallback({slash_list = "zup, zupdate", description = "[ZoneInfo]  Force refresh display", func=CUI.Common.SlashUpdate})
	LIB_SLASH.BindCallback({slash_list = "zne, nearby", description = "[ZoneInfo] List nearby players", func=CUI.Nearby.DisplayList})
	LIB_SLASH.BindCallback({slash_list = "zac, armycount", description = "[ZoneInfo] Displays number of army members online", func=CUI.Army.DisplayList})
	LIB_SLASH.BindCallback({slash_list = "zid, zoneid, id", description = "[ZoneInfo] Displays zone ID", func=CUI.Id.DisplayId})
	LIB_SLASH.BindCallback({slash_list = "ziddbc", description = "[ZoneInfo] Clears the Zone ID database", func=CUI.Id.Clear})
	LIB_SLASH.BindCallback({slash_list = "zll", description = "[ZoneInfo] Displays last login to zone", func=CUI.Id.DisplayLastLogin})
	
	Debug.EnableLogging(true)
--OnComponentLoad
end

function HandleInterfaceCallback(pid, pvalue)
	if (pid == "__LOADED") then
		OnOptionsLoaded()
	elseif (pid == "__DISPLAY") then
		return
	end	
	if (OPTIONSLOOKUPTABLE[pid]) then
		CUI[OPTIONSLOOKUPTABLE[pid]]:HandleCallback({id=pid, value=pvalue})
	end
end


------------
-- FUNCTIONS
------------

function Test(args)
	log("Test: "..tostring(args.text))
end

function OnEnterZone(args)
	
end

function OnPlayerReady(args)
	InitStuff()
end

function InitFriends()

end

function OnOptionsLoaded()
	is_options_init = true
end

function InitStuff()
	if not is_options_init then
		Callback2.FireAndForget(InitStuff, nil, 1)
		return
	end
	
	if(CUI.Common:GetSetting("loginid")) then
		CUI.Id.DisplayId()
	end
	if(CUI.Common:GetSetting("loginlast")) then
		CUI.Id.DisplayLastLogin()
	end
	
	if is_counters_init then return end

	CUI.Nearby:Init()
	CUI.Id:Init()
	CUI.Friend:Init()
	CUI.Army:Init()
	is_counters_init = true
end

function OnChannelJoin(args)
	if(args.channel == "zone") then
		-- nothing anymore
	elseif args.channel == "army" then
		
	end
end

function OnHudShow(args)
	CUI.Common:SetData("hud", args.show)
	CUI.Common:UpdateVisibility({args.show})
end

function OnPlayerJoinedChatChannel(args)
	if(args.channel == "zone") then
		
	elseif (args.channel == "army") then
		CUI.Army:Init()
	end
end

function OnPlayerLeftChatChannel(args)
	if(args.channel == "zone") then
		
	elseif (args.channel == "army") then
		CUI.Army:Init()
	end
end

function OnUiEntityAvailable(args)
	if args.type == "character" then
		if not is_options_init then
			return
		end
		local info = Game.GetTargetInfo(args.entityId)
		local id = tostring(args.entityId)
		if (info.isNpc == false and CUI.Nearby:GetData("players", id) == nil) then

        -- someone become visible
        -- use frame_icon_id
			local name = "["..tostring(info.battleframe) .. "] "..tostring(info.name).." ("..tostring(info.level) .. "/" .. tostring(info.elite_level) ..")"--tostring(info.name)
            Debug.Log(info);
			CUI.Nearby:Update(id, name, 1)
		end
	end
end

function OnUiEntityLost(args)
	local id = tostring(args.entityId)
	if not is_options_init then
		return
	end
	if (CUI.Nearby:GetData("players", id) ~= nil) then
		CUI.Nearby:Update(id, nil, -1)
	end
end

function OnFriendStatusChanged(args)
	CUI.Friend:Update(args)
end

function AsyncRequest(url, method, postdata, callback, ...) --- calls callback(returned_rable, unpack(arg))
	assert(url, "URL missing")
	assert(method, "Method missing")
	assert(string.upper(method) ~= "POST" or postdata, "POST data missing")
	assert(callback, "Callback missing")
	assert(type(callback) == "function", "Callback must be function type")
	
	if not HTTP.IsRequestPending(url) then
		HTTP.IssueRequest(url, method, postdata, function(resp, err) AsyncResponse(resp, err, callback, arg) end)
	else
		Callback2.FireAndForget(function() AsyncRequest(url, method, postdata, callback, unpack(arg)) end, nil, 1)
	end
end

function AsyncResponse(resp, err, callback, args)
	if err then
		error("Async request failure:\n"..tostring(err))
		return
	end
	if resp then
        if args == nil then return end
		callback(resp, unpack(args))
	end
end

function TableIndexToList(args, delimiter, limit)
	local list = ""
	local count = 0
	if(limit == 0) then limit = nil end
	for index, item in spairs(args, function(t,a,b) return StringLower(GetUniqueName(b)) > StringLower(GetUniqueName(a)) end) do
		if(count == 0) then list = list..index else list = list.."\n"..index end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

function TableToOrderedList(args, limit)
	local list = ""
	local count = 0
	for index, item in spairs(args, function(t,a,b) return StringLower(GetUniqueName(t[b])) > StringLower(GetUniqueName(t[a])) end) do
		if(count == 0) then list = list..item else list = list.."\n"..item end
		count = count + 1
		if (limit ~= 0 and limit ~= nil and count >= limit) then break end
	end
	return list
end

function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end
	
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function GetUniqueName(name)
	assert(name, "Name missing")
    local _, tag_end = StringFind(name, ".*] ")
	if tag_end then
		return StringSub(name, tag_end+1)
	else
		return name
	end
end