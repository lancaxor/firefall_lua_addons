--skuly realinfo v1.3.3
-- ------------------------------------------
-- LIB_ITEMS
--   by: various
-- ------------------------------------------

--[[
	API:
	
	color = LIB_ITEMS.GetItemColor(args)						-- Returns rarity/type color of the item in color key string form
																	args = (iteminfo table) or (item userdata)
																
	color = LIB_ITEMS.GetModuleColorValue(slotColor, filled)	-- Returns the color string for a module slot based on module slotColor and it's filled state
																	slotColor = the value received from Game.GetModuleSlotsForItem(itemTypeId)
																	filled = whether there is a module in the slot or not
																	
	table = LIB_ITEMS.GetModuleTypeInfo(subTypeId)				-- Returns type of item the module is used in and the color of the module
																	subTypeId = subTypeId from the itemInfo
																	
	table = LIB_ITEMS.GetValidSlotsForModule(module_color)		--Returns a table of the slot types that a module will work in
																	module_color = color of the module
																
	color = LIB_ITEMS.GetResourceQualityColor(quality)			-- Returns rarity color of the item in hex color
																	quality = the resource's quality number (0-1000)
																
	textFormat = LIB_ITEMS.GetNameTextFormat(item_ref, args)	-- Returns a TextFormat for displaying an item's name (see lib_TextFormat)
																	item_ref can be an item sdb_id or an ItemInfo table
																	args is an optional table that may include .quantity and/or .quality for resources
																
	string = LIB_ITEMS.GetBasicName(item_ref)					-- returns a basic name as a string, without "^Q" or "^CY" in the name
	
	{matches=(int), has_cert={[cert_id]=(bool)}} = LIB_ITEMS.FindMostEligibleFrame(player_certs, item_certs)
																-- Returns one of the player's frame with the most fulfilled certs for the item certs
																
	stat_table = LIB_ITEMS.GetResourceStats(resource_type)		-- Returns a table containing resource stat info

	table = LIB_ITEMS.GetUpgradesStats(itemInfo)				--Returns a table with tinkering upgrade info on an item; {level=#, crits=#}

	TOOLTIPS:
	
		TOOLTIP = LIB_ITEMS.CreateToolTip(PARENT)	-- creates a TOOLTIP widget on a PARENT widget/frame
		TOOLTIP:Destroy();							-- removes the TOOLTIP
		WIDGET = TOOLTIP:GetWidget()				-- returns the container widget
		{width, height} = TOOLTIP:GetBounds();		-- returns the pixel dimensions of the TOOLTIP
		TOOLTIP:SetContext(context);				-- supply a context in which to display item info, to show qualifications
														context = {
															frameTypeId = battleframe type id
														}
		TOOLTIP:DisplayInfo(itemInfo);				-- sets the tooltip's item info
		TOOLTIP:CompareAgainst(itemInfo);			-- compares the tooltip's current item against another
		TOOLTIP:DisplayTag(loc_tag_key);			-- displays a tag, localized by text key (e.g. "equipped", "new")
--]]

local g_version = "1.3.3"
LIB_ITEMS = {}
verchecktime = {}
local lf = {}
require "math";
require "table";
require "unicode";

require "lib/lib_WebCache";
require "lib/lib_Callback2";
require "lib/lib_Colors";
require "lib/lib_TextFormat";
require "lib/lib_math";
require "lib/lib_SubTypeIds"
require "lib/lib_table";
require "lib/lib_Unlocks"
require "lib/lib_Slash"
Unlocks.Subscribe("certificate")
LIB_SLASH.UnbindCallback("marketeer")

local enablemarket = {
	status = Component.GetSetting("market")
	}
	
local marketeer
local GEAR_SLOT_PRIMARY_WEAPON = 1;



--[[ USED_LOCALIZATION_KEYS
MODULE_COLOR_RED
MODULE_COLOR_YELLOW
MODULE_COLOR_BLUE
MODULE_COLOR_ORANGE
MODULE_COLOR_PURPLE
MODULE_COLOR_GREEN
MODULE_COLOR_PRISMATIC

STAT_DAMAGEPERSECOND
STAT_BULLETSPERSECOND
STAT_HEALTHPERROUND
STAT_RANGE
STAT_RELOADTIME
STAT_CLIPSIZE
STAT_RATING
STAT_JUMPHEIGHT
STAT_RUNSPEED
STAT_HEALTH
STAT_SPEED
STAT_CONSTRAINTS
STAT_BOOST
STAT_REDUCE
STAT_MAXAMMO
STAT_SPLASHRADIUS
STAT_MASS
STAT_POWER
STAT_CPU
STAT_QUALITY
STAT_SPREAD
STAT_DAMAGEPERROUND
--]]
local GEAR_SLOT_FRAME = 0;
local c_WeaponStatValues = {}
c_WeaponStatValues["Headshot Damage"] = true
c_WeaponStatValues["Weapon Damage "] = true
c_WeaponStatValues["Rate of Fire"] = true
c_WeaponStatValues["Weapon Range "] = true
c_WeaponStatValues["Weapon Chargeup"] = true
c_WeaponStatValues["Weapon Spread"] = true
c_WeaponStatValues["Weapon Reload Speed"] = true
c_WeaponStatValues["Weapon Scope Zoom"] = true


-- ------------------------------------------
-- GLOBAL CONSTANTS
-- ------------------------------------------
-- these were in Durability.lua, but let's use the same thresholds for the garage etc.
LIB_ITEMS.C_MaxDurability = 1000;
LIB_ITEMS.C_DurabilityConditionGood = 0.5;	-- >50% = you're good to mind your own business (no notice)
LIB_ITEMS.C_DurabilityConditionPoor = 0.2;	-- >20% = heads up: not doing so hot (brief notice)
LIB_ITEMS.C_DurabilityConditionCritical = 0.1;	-- >10% = urgent (long notice); <10% = perma notice
LIB_ITEMS.C_IgnoreStats = { --MPU was using this table, until we deleted it; other external stuff might need it later?
	["ammoPerBurst"] = "ammoPerBurst",
	["roundsPerBurst"] = "roundsPerBurst",
	--["damagePerRound"] = "damagePerRound",
	["roundsPerMinute"] = "roundsPerMinute",	-- redundant with DPS
	["maxAmmo"] = "maxAmmo",					--Seems to be repeated with the Total Ammo Capacity attribute
	["rating"] = "rating",
	["repairPoints"] = "repairPoints",
}
LIB_ITEMS.C_StatPriorities = {
	damagePerSecond = "zzzz" 						--Most players look for DPS first
}

-- ------------------------------------------
-- LOCAL CONSTANTS
-- ------------------------------------------
local c_BOOST_COLOR = "#00FF80";
local c_DROP_COLOR = "#FF5C5C";
local c_CRITICAL_COLOR = "#FF4040";
local c_LABEL_COLOR = "#CCCCCC";
local c_STAT_COLOR = "#FFFFFF";	-- e.g. "Splash Radius"
local c_STAT_COLOR_ABILITY = "#F5C358";	-- e.g. "2.00m"
local c_COLON_SPACING = ": ";

local c_RarityValues = {
	["salvage"]			= 0,
	["common"]			= 1,
	["uncommon"]		= 2,
	["rare"]			= 3,
	["epic"]			= 4,
	["legendary"]		= 5,
}

-- these are stats based on percentage
local c_PercentageStat = {
	[1151] = true,		-- Power Mod %
	[1152] = true,		-- Mass Mod %
	[1159] = true,		-- Repair Pool Mod %
}

local c_ValidSlotsForModules = {
	red			= {red=true,  yellow=false, blue=false, prismatic=true},
	yellow		= {red=false, yellow=true,  blue=false, prismatic=true},
	orange		= {red=true,  yellow=true,  blue=false, prismatic=true},
	blue		= {red=false, yellow=false, blue=true,  prismatic=true},
	purple		= {red=true,  yellow=false, blue=true,  prismatic=true},
	green		= {red=false, yellow=true,  blue=true,  prismatic=true},
	prismatic	= {red=true,  yellow=true,  blue=true,  prismatic=true},
}

local c_ModuleTypeColorLookup = {
	-- weapons
	["3628"] = {type = "any",			color = "red"},
	["3629"] = {type = "any",			color = "blue"},
	["3630"] = {type = "any",			color = "yellow"},
	["3631"] = {type = "any",			color = "purple"},
	["3632"] = {type = "any",			color = "green"},
	["3633"] = {type = "any",			color = "orange"},
	["3634"] = {type = "weapon",			color = "prismatic"}, -- not in use
	-- abilities (depricated)
	["3636"] = {type = "ability_module",	color = "red"},
	["3637"] = {type = "ability_module",	color = "blue"},
	["3638"] = {type = "ability_module",	color = "yellow"},
	["3638"] = {type = "ability_module",	color = "purple"},
	["3640"] = {type = "ability_module",	color = "green"},
	["3641"] = {type = "ability_module",	color = "orange"},
	["3642"] = {type = "ability_module",	color = "prismatic"}, -- not in use
}

local c_ModuleTypeStatLineKey = {
	weapon = "WEAPON_MODULE_STAT_LABEL",
	ability_module = "ABILITY_MODULE_STAT_LABEL",
}

local c_ModuleColorToKey = {
	red		= "redModuleContainerKey",
	yellow	= "yellowModuleContainerKey",
	blue	= "blueModuleContainerKey",
}

local c_ModuleGroupHeight = 22
local c_ModuleItemHeight = 18
local c_EliteIconOffset = 42

local bp_ModulePip = [[<StillArt dimensions="height:7; width:7; left:0; top:0" style="texture:GarageParts; region:ModulePreview_empty;"/>]]

-- Right now, there's one for all tooltips, could be refactored so every tooltip has its own
local g_PaperdollInst = nil
local c_PaperdollUpscale = 2

local g_hasEliteRequirement = false;

local webCacheBuy = {}
local webCacheSell = {}

local weapontable1 = {}
local weapontable2 = {}

function OnComponentLoad()
     -- do stuff
end



-- ------------------------------------------
-- LIB_ITEMS FUNCTIONS
-- ------------------------------------------
function LIB_ITEMS.GetItemColor(args)
	if type(args) ~= "table" then
		args = Game.GetItemInfoByType(args)
	end
	if type(args) == "table" then
		if args.type == "powerup" then
			return "powerup"
		elseif args.rarity then
			return args.rarity
		end
	end
	warn("Invalid iteminfo var sent to LIB_ITEMS.GetItemColor: "..tostring(args))
	return "unknown_rarity"
end

function LIB_ITEMS.GetRarityValue(rarity)
	local value
	if not rarity or not c_RarityValues[rarity] then
		value = -1
	else
		value = c_RarityValues[rarity]
	end
	return value
end

function LIB_ITEMS.GetModuleColorValue(slotColor, filled)
	local tint = "module_"..slotColor
	if filled then
		tint = tint.."_full"
	else
		tint = tint.."_empty"
	end
	return tint
end

function LIB_ITEMS.GetModulePipRegion(filled)
	local region = "ModulePreview_"
	if filled then
		region = region.."full"
	else
		region = region.."empty"
	end
	return region
end

function LIB_ITEMS.GetModuleTypeInfo(subTypeId)
	subTypeId = tostring(subTypeId)
	return _table.copy(c_ModuleTypeColorLookup[subTypeId])
end

function LIB_ITEMS.GetValidSlotsForModule(module_color)
	return _table.copy(c_ValidSlotsForModules[module_color])
end

function LIB_ITEMS.HasRequiredItemCerts(itemInfo, frameId)
	if type(itemInfo) ~= "table" then return false end
	local req_certs = itemInfo.certifications
	if #req_certs == 0 then
		return true
	end
	
	if not frameId then
		local loadoutInfo = Player.GetCurrentLoadout()
		if loadoutInfo then
			frameId = loadoutInfo.item_types.chassis
		end
	end
	
	for _, certId in pairs(req_certs) do
		if not Unlocks.HasUnlock("certificate", certId, frameId) then
			return false
		end
	end
	return true
end

function LIB_ITEMS.GetMatchingEquippedItemInfo(itemInfo)
	if type(itemInfo) ~= "table" then return nil end
	--find gear type for equipped gear matching
	local gear_type
	
	if itemInfo.weaponType then 
		local resource_id = tonumber(itemInfo.subTypeId)
		repeat
			resource_id = tonumber(resource_id)
			if resource_id == 59 then
				gear_type = "primary_weapon"
			elseif resource_id == 60 then
				gear_type = "secondary_weapon"
			end
			if not gear_type then
				resource_id = Game.GetResourceTypeInfo(resource_id).parentResourceTypeId
			end
		until gear_type or not resource_id
	elseif itemInfo.moduleType then
		gear_type = itemInfo.moduleType
	end
	--early out if not of a correct type
	if not gear_type then return nil end

	--early out if item is not equippable
	if not LIB_ITEMS.HasRequiredItemCerts(itemInfo) then
		return nil
	end
	--find matching equipped items info
	local equippedItemInfo
	local loadout = Player.GetCurrentLoadout()
	if gear_type == "primary_weapon" or gear_type == "secondary_weapon" then
		local data = loadout.items[gear_type]
		if data then
			if data.item_guid then
				equippedItemInfo = Player.GetItemInfo(data.item_guid);
			elseif data.item_sdb_id then
				equippedItemInfo = Game.GetItemInfoByType(data.item_sdb_id);
			end
		end
	elseif unicode.match(gear_type, "^Battleframe %a-") or gear_type == "Operating System" then
		for _, data in ipairs(loadout.modules.chassis) do
			local info
			if data.item_guid then
				info = Player.GetItemInfo(data.item_guid);
			elseif data.item_sdb_id then
				info = Game.GetItemInfoByType(data.item_sdb_id);
			end
			if info and info.moduleType == gear_type then
				equippedItemInfo = info
				break
			end
		end
	elseif itemInfo.abilityId then
		for _, data in ipairs(loadout.modules.backpack) do
			local info
			if data.item_guid then
				info = Player.GetItemInfo(data.item_guid);
			elseif data.item_sdb_id then
				info = Game.GetItemInfoByType(data.item_sdb_id);
			end
			if info and info.moduleType == gear_type then
				equippedItemInfo = info
				break
			end
		end
	end
	return equippedItemInfo
end

function LIB_ITEMS.GetResourceQualityColor(quality) --deprecated
	warn("LIB_ITEMS.GetResourceQualityColor IS DEPRECATED")
	if type(quality) == "number" then
		if quality >= 1000 then
			return "legendary"
		elseif quality >= 901 then
			return "epic"
		elseif quality >= 701 then
			return "rare"
		elseif quality >= 401 then
			return "uncommon"
		else
			return "common"
		end
	else
		warn("Invalid quality var sent to LIB_ITEMS.GetResourceQualityColor(number)")
		return "common"
	end
end

function LIB_ITEMS.GetNameTextFormat( item_ref, args )
	local itemInfo = item_ref;
	if (type(itemInfo) ~= "table") then
		itemInfo = Game.GetItemInfoByType(item_ref);
		assert(itemInfo, "bad item ref: "..tostring(item_ref));
	end
	args = args or {rarity = itemInfo.rarity} --quality = item_ref.quality};
	local TF = TextFormat.Create();
	
	local item_name = tostring(itemInfo.name);
	local my_string = item_name;
	local quantity = args.quantity or itemInfo.quantity
	if quantity and (quantity ~= 1 or (itemInfo.flags.resource and itemInfo.type ~= "powerup" and itemInfo.type ~= "item_module")) then
		my_string = Component.LookupText("N_OF_X", Component.LookupText("QUANTITY_FORMAT", quantity), item_name);
	end
	TF:AppendColor(args.rarity or LIB_ITEMS.GetItemColor(itemInfo));
	TF:AppendText(my_string);
	return TF;
end

function LIB_ITEMS.GetBasicName( item_ref )
	local basic_name;
	if (type(item_ref) == "table") then
		-- itemInfo
		basic_name = item_ref.name;
	elseif (type(item_ref) == "string") then
		-- name
		basic_name = item_ref;
	else
		-- sdb id
		local itemInfo = Game.GetItemInfoByType(item_ref);
		assert(itemInfo, "bad item ref: "..tostring(item_ref));
		basic_name = itemInfo.name;
	end
	
	basic_name = unicode.gsub(basic_name, "%^Q", "");
	basic_name = unicode.gsub(basic_name, "%^CY", "");
	return basic_name;
end

function LIB_ITEMS.StripColorBBCode(desc)
	return unicode.gsub(desc or "", "%[/?color.-%]", "")
end


function LIB_ITEMS.FindMostEligibleFrame( player_certs, item_certs )
	local most_eligible = {matches=0, has_cert={}};
	for frameId, my_certs in pairs(player_certs) do
		local eligibility = { matches = 0, has_cert={} };
				
		for i, certId in pairs(item_certs) do
			local id = tostring(certId);
			if(my_certs[id]) then
				eligibility.matches = eligibility.matches+1;
				eligibility.has_cert[id] = true;
			else
				eligibility.matches = -1;
				break;
			end
		end
		
		if( eligibility.matches > most_eligible.matches )then
			most_eligible = eligibility;
		end
	end
	return most_eligible;
end

function LIB_ITEMS.GetResourceStats(resource_type)
	--"{Version}-{SDB ID}-{Quality}-{Stat1}-{Stat2}-{Stat3}-{Stat4}-{Stat5}-{unused}-{unused}"
	local split_values = {}
	for value, k in unicode.gmatch(resource_type, "(%w+)(%-)") do
		table.insert(split_values, _math.BaseNToBase10(value,36));
	end
	return {["sdb_id"] = split_values[2],
			["quality"] = split_values[3],
			["stat1"] = split_values[4],
			["stat2"] = split_values[5],
			["stat3"] = split_values[6],
			["stat4"] = split_values[7],
			["stat5"] = split_values[8]
			};
end

function LIB_ITEMS.GetUpgradesStats(itemInfo)--Gets tinkering upgrades
	return lf.GetUpgradesStats(itemInfo)
end

-- ------------------------------------------
-- ITEM TOOLTIP FUNCTIONS
-- ------------------------------------------
local TOOLTIP_API = {};

function LIB_ITEMS.CreateToolTip(PARENT)
	local TOOLTIP = {};
	
	TOOLTIP.GROUP = Component.CreateWidget(
	[[<Group dimensions="dock:fill">
		<Group name="tag" dimensions="center-x:50%; bottom:0%-6; width:100%; height:15" style="visible:false;">
			<Group name="back" dimensions="dock:fill">
				<StillArt dimensions="right:20%+16; width:20%+32; center-y:50%; height:100%" style="texture:gradients; region:white_right; tint:#000000; alpha:0.8"/>
				<StillArt dimensions="left:20%+16; right:80%-16; center-y:50%; height:100%" style="texture:colors; region:white; tint:#000000; alpha:0.8"/>
				<StillArt dimensions="left:80%-16; width:20%+32; center-y:50%; height:100%" style="texture:gradients; region:white_left; tint:#000000; alpha:0.8"/>
			</Group>
			<Text name="text" key="EQUIPPED" dimensions="left:0; top:-1; height:100%; width:100%" style="font:UbuntuMedium_10; valign:center; halign:center; color:ffffff; wrap:false; leading-mult:1.2"/>
		</Group>
		<ListLayout name="layout" dimensions="dock:fill" style="vpadding:14;">
			<Text name="label" dimensions="dock:fill" style="font:Narrow_15B; valign:top; halign:left; color:#ffffff; wrap:true; leading-mult:1.2"/>
			<Group name="rank_levels" dimensions="top:0; left:0; width:250; height:24;" style="visible:false">
				<Group name="section_1" dimensions="left:0; top:0; bottom:100%; width:33%-1;">
					<StillArt dimensions="dock:fill" style="texture:colors; region:white; tint:#B5B6D5; alpha:0.1"/>
					<StillArt name="rank_1" dimensions="center-y:50%; center-x:20%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_2" dimensions="center-y:50%; center-x:50%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_3" dimensions="center-y:50%; center-x:80%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
				</Group>
				<Group name="section_2" dimensions="left:33%+2; top:0; bottom:100%; width:33%-1;" >
					<StillArt dimensions="dock:fill" style="texture:colors; region:white; tint:#B5B6D5; alpha:0.1"/>
					<StillArt name="rank_4" dimensions="center-y:50%; center-x:20%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_5" dimensions="center-y:50%; center-x:50%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_6" dimensions="center-y:50%; center-x:80%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
				</Group>
				<Group name="section_3" dimensions="right:100%; top:0; bottom:100%; width:33%-1;" >
					<StillArt dimensions="dock:fill" style="texture:colors; region:white; tint:#B5B6D5; alpha:0.1"/>
					<StillArt name="rank_7" dimensions="center-y:50%; center-x:20%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_8" dimensions="center-y:50%; center-x:50%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
					<StillArt name="rank_9" dimensions="center-y:50%; center-x:80%; width:28; height:28;" style="texture:UpgradeStars; region:empty"/>
				</Group>
			</Group>
			<Text name="description" dimensions="width:100%; height:0" style="font:Demi_10; valign:top; halign:left; alpha:1; wrap:true; leading-mult:1.5"/>
			<Group name="time_remaining" dimensions="width:100%; height:10" style="horizontal:true; hpadding:5; ignore_other_dim:true">
				<Text name="description" dimensions="left:0; top:0; width:0; height:100%" key="TIME_REMAINING" style="font:Demi_10; valign:top; halign:left;"/>
				<TextTimer name="timer" dimensions="left:0; top:0; width:100%; height:100%" style="font:Demi_10; format:%02.0h:%02.0m:%02.0s; text-color:orange; valign:top; halign:left;"/>
			</Group>
			<StillArt name="divider" dimensions="width:100%; height:2" style="texture:gradients; region:white_left; alpha:0.4;"/>
			<Text name="main_detail" dimensions="width:100%; height:0" style="font:UbuntuBold_12; valign:center; halign:left; color:#ffffff; wrap:true; leading-mult:1.5"/>
			<StillArt name="detail_divider" dimensions="width:100%; height:2" style="texture:gradients; region:white_left; alpha:0.4;"/>
			<Text name="detail" dimensions="width:100%; height:0" style="font:UbuntuMedium_10; valign:center; halign:left; color:#ffffff; wrap:true; leading-mult:1.5"/>
			<Text name="buyOrder" dimensions="width:100%; height:10" style="font:UbuntuMedium_10; valign:center; halign:left; color:#ffffff; wrap:true; leading-mult:1.5"  visible="false"/>
			<Text name="sellOrder" dimensions="width:100%; height:10" style="font:UbuntuMedium_10; valign:center; halign:left; color:#ffffff; wrap:true; leading-mult:1.5"  visible="false"/>
			<ListLayout name="modules_group" dimensions="left:0; right:100%; height:24" style="vpadding:1;">
				<Group dimensions="width:100%; height:25">
					<Border dimensions="left:0; top:0; height:25; width:100%" class="RoundedBorders" style="padding:6; tint:#27333F; alpha:0.8;" />
					<Text key="MODULES" dimensions="left:10; right:100%; top:7; height:10" style="font:Demi_10; halign:left; valign:center; color:#FFEC9D" />
				</Group>
				<Text name="modules" dimensions="left:10; right:100%; height:0" style="font:UbuntuMedium_10; wrap:true; padding:5;"/>
				<Group name="empty_group" dimensions="height:0; width:0; center-x:0; center-y:0" style="visible:false"/>
			</ListLayout>
			<ListLayout name="requirements_group" dimensions="left:0; right:100%; height:0" style="vpadding:7;">
				<Group dimensions="width:100%; height:25">
					<Border dimensions="left:0; top:0; height:25; width:100%" class="RoundedBorders" style="padding:6; tint:#27333F; alpha:0.8;" />
					<StillArt dimensions="left:6; top:2; height:22; width:22" style="texture:icons; region:danger; tint:#FFEC9D" />
					<Text key="REQUIREMENTS" dimensions="left:30; right:100%; top:7; height:10" style="font:Demi_10; halign:left; valign:center; color:#FFEC9D" />
				</Group>
				<Text name="requirements" dimensions="left:10; right:100%; height:0" style="font:UbuntuMedium_10; wrap:true; valign:center; halign:left; color:ffffff; leading-mult:1.5"/>
			</ListLayout>
			<Text name="cannot_trade" key="ITEM_CANNOT_TRADE" dimensions="width:100%; height:10" style="font:Demi_10; valign:top; halign:left; color:ffffff; alpha:1;" visible="false"/>
			<Group name="weightless" dimensions="width:100%; height:10" visible="false">
				<StillArt dimensions="width:33; height:17; left:4; top:0" style="texture:FeatherIcon"/>
				<Text key="ITEM_IS_WEIGHTLESS" dimensions="left:40; center-y:50%; height:10; width:0" style="font:Demi_10; valign:top; halign:left; color:ffffff; alpha:1;"/>
			</Group>
			<Group name="model" dimensions="height:50t; width:100%;" style="visible:false">
				<StillArt name="glow" dimensions="height:100%; width:95%; center-x:50%;" style="texture:gradients; region:sphere; alpha:0.4;"/>
				<StillArt name="paperdoll" dimensions="height:40t; width:90%; center-x:50%; center-y:50%;"/>
			</Group>
			<StillArt name="sub_divider" dimensions="width:100%; height:2" style="texture:gradients; region:white_left; alpha:0.4;"/>
			<Text name="sub_detail" dimensions="width:100%; height:0" style="font:UbuntuMedium_10; valign:center; halign:right; color:#ffffff; wrap:true; leading-mult:1.5"/>
		</ListLayout>
		<StillArt name="elite_icon" dimensions="center-x:10; width:40; aspect:1.77; top:0;" style="visible:true; texture:EliteIndicator;"/>
	</Group>]], PARENT);
	
	TOOLTIP.TAG = {GROUP = TOOLTIP.GROUP:GetChild("tag")};
	TOOLTIP.TAG.TEXT = TOOLTIP.TAG.GROUP:GetChild("text");
	TOOLTIP.LAYOUT = TOOLTIP.GROUP:GetChild("layout");
	TOOLTIP.LABEL = TOOLTIP.LAYOUT:GetChild("label");
	TOOLTIP.DESCRIPTION = TOOLTIP.LAYOUT:GetChild("description");
	TOOLTIP.TIMER = TOOLTIP.LAYOUT:GetChild("time_remaining");
	local timer_width = TOOLTIP.TIMER:GetChild("description"):GetTextDims().width;
	TOOLTIP.TIMER:GetChild("timer"):SetDims("left:"..tostring(timer_width+5))
	TOOLTIP.RANKS = TOOLTIP.LAYOUT:GetChild("rank_levels")
	TOOLTIP.REQUIREMENTS = {GROUP = TOOLTIP.LAYOUT:GetChild("requirements_group")};
	TOOLTIP.REQUIREMENTS.TEXT = TOOLTIP.REQUIREMENTS.GROUP:GetChild("requirements");
	TOOLTIP.MODULES = {GROUP = TOOLTIP.LAYOUT:GetChild("modules_group")};
	TOOLTIP.MODULES.SLOTS = TOOLTIP.MODULES.GROUP:GetChild("modules");
	TOOLTIP.MODULES.EMPTY_GROUP = TOOLTIP.MODULES.GROUP:GetChild("empty_group")
	TOOLTIP.DIVIDER = TOOLTIP.LAYOUT:GetChild("divider");
	TOOLTIP.DETAIL_DIVIDER = TOOLTIP.LAYOUT:GetChild("detail_divider");
	TOOLTIP.DETAIL_MAIN = TOOLTIP.LAYOUT:GetChild("main_detail")
	TOOLTIP.DETAIL = TOOLTIP.LAYOUT:GetChild("detail");
	TOOLTIP.BUYORDER = TOOLTIP.LAYOUT:GetChild("buyOrder");
	TOOLTIP.SELLORDER = TOOLTIP.LAYOUT:GetChild("sellOrder");
	TOOLTIP.CANNOT_TRADE = TOOLTIP.LAYOUT:GetChild("cannot_trade");
	TOOLTIP.WEIGHTLESS_GROUP = TOOLTIP.LAYOUT:GetChild("weightless")
	TOOLTIP.MODEL_GROUP = TOOLTIP.LAYOUT:GetChild("model")
	TOOLTIP.GLOW = TOOLTIP.MODEL_GROUP:GetChild("glow")
	TOOLTIP.PAPERDOLL = TOOLTIP.MODEL_GROUP:GetChild("paperdoll");
	TOOLTIP.SUB_DETAIL = TOOLTIP.LAYOUT:GetChild("sub_detail")
	TOOLTIP.SUB_DIVIDER = TOOLTIP.LAYOUT:GetChild("sub_divider")
	TOOLTIP.ELITE_ICON = TOOLTIP.GROUP:GetChild("elite_icon")
	TOOLTIP.context = nil;


	-- methods
	for k,method in pairs(TOOLTIP_API) do
		TOOLTIP[k] = method;
	end

	return TOOLTIP;
end

function TOOLTIP_API:Destroy()
	if not (g_PaperdollInst == nil) then
		Paperdoll.Delete(g_PaperdollInst)
		g_PaperdollInst = nil
	end
	Component.RemoveWidget(self.GROUP);
	for k,v in pairs(self) do
		self[k] = nil;
	end
end

function TOOLTIP_API:GetWidget()
	return self.GROUP;
end

function TOOLTIP_API:GetBounds()
	local bounds = self.LAYOUT:GetBounds();
	local length = self.LAYOUT:GetLength();
	bounds.height = length + 10;
	bounds.bottom = bounds.top + bounds.height;
	return bounds;
end

function TOOLTIP_API:SetContext(context)
	self.context = context;
end

function TOOLTIP_API:DisplayPaperdoll(bool)
	local display_paperdoll = (bool and self.itemInfo and self.itemInfo.type == "weapon" and g_PaperdollInst == nil)
	-- Only display the paperdoll if the tooltip will still fit on the screen
	local _, screenHeight =  Component.GetScreenSize(true)
	local validSize = (self:GetBounds().height + self.PAPERDOLL:GetBounds().height) <= screenHeight
	
	if display_paperdoll and validSize then
    	local bounds = self.PAPERDOLL:GetBounds()
        if (g_PaperdollInst == nil) then
		    g_PaperdollInst = Paperdoll.Create("LIB_ITEMS")
        end
        g_PaperdollInst.LoadItem(self.itemInfo.itemTypeId)
        g_PaperdollInst.SetLightingMultiplier(9)
        g_PaperdollInst.SetTextureSize(bounds.width * c_PaperdollUpscale, bounds.height * c_PaperdollUpscale)
        g_PaperdollInst.SetBloom(true, 1, 0.7)  -- default threshold (1) and a little less brightness (default is 0.5)
		g_PaperdollInst.SetRotation(-90)
		g_PaperdollInst.SetSpin(30)
        self.PAPERDOLL:SetTexture(g_PaperdollInst.GetTexture())
        self.GLOW:SetParam("tint", self.itemInfo.rarity or "#ffffff");
		self.MODEL_GROUP:Show()
	else
		self.MODEL_GROUP:Hide()
	end
end

-- Default true
function TOOLTIP_API:DisplayRequirements(bool)
	self.showRequirements = bool
end


function TOOLTIP_API:DisplayInfo(itemInfo, item_guid)
	assert(type(itemInfo) == "table", "LIB_ITEMS's DisplayInfo requires you pass in the itemInfo table")
	self.itemInfo = itemInfo;
	--local allStats = Player.GetAllStats();
	local allStatsById = lf.ParseAllStats();
	--Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text=tostring(allStats)})
	--log(tostring(allStats))
	
	--if verchecktime.time2 == nil then
	--local loaded = System.GetClientTime();
	--Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text=tostring(weaponhandling)})
	--Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text=tostring(allStats)})
	--verchecktime.time2 = loaded
	--end
	-- show info
	

	LIB_SLASH.UnbindCallback("marketeer")
	
	local loadedtime
	local currenttime
	local time3
	local timeleft
	local currenttime0 = System.GetClientTime();
	
	if verchecktime.time ~= nil then
	loadedtime = unicode.sub(tostring(verchecktime.time), 1, -4)
	currenttime = unicode.sub(tostring(currenttime0), 1, -4)
	time3 = tonumber(loadedtime) + 20
	end
	
if tonumber(currenttime) < tonumber(time3) then
		LIB_SLASH.BindCallback({slash_list = "marketeer", description = "Marketeer's", func=marketeer})
			else
		LIB_SLASH.UnbindCallback("marketeer")
end
		
		local lo = Player.GetCurrentLoadout()
		local adjustedprimary_weaponValue1
		local effectiveprimary_weaponValue1
		local adjustedprimary_weaponValue2
		local effectiveprimary_weaponValue2
		local test
		local test2
			if (lo and lo.items) then

		
		if (lo.items.primary_weapon) then
			local ii;
			
			if (lo.items.primary_weapon.item_guid) then
				ii = Player.GetItemInfo(lo.items.primary_weapon.item_guid);
			end
			
			if (not ii) then
				ii = Game.GetItemInfoByType(lo.items.primary_weapon.item_sdb_id);
			end
			
			if (ii and ii.attributes) then
			
				for _,statInfo in ipairs(ii.attributes) do
					--if c_WeaponStatValues[statInfo.dev_name] == true then
						adjustedprimary_weaponValue1 = Player.GetAttribute(tonumber(statInfo.stat_id), 1);
						effectiveprimary_weaponValue1 = StatPolicy(1, statInfo, adjustedprimary_weaponValue1);
						test = (unicode.format(statInfo.format, effectiveprimary_weaponValue1))
							weapontable1[statInfo.display_name] = test
							
					--end
					
					
				end
			end
		end
		
		if (lo.items.secondary_weapon) then
			local ii;
			
			if (lo.items.secondary_weapon.item_guid) then
				ii = Player.GetItemInfo(lo.items.secondary_weapon.item_guid);
			end
			
			if (not ii) then
				ii = Game.GetItemInfoByType(lo.items.secondary_weapon.item_sdb_id);
			end
			
			if (ii and ii.attributes) then
			
				for _,statInfo in ipairs(ii.attributes) do
					--if c_WeaponStatValues[statInfo.dev_name] == true then
						adjustedprimary_weaponValue2 = Player.GetAttribute(tonumber(statInfo.stat_id), 2);
						effectiveprimary_weaponValue2 = StatPolicy(2, statInfo, adjustedprimary_weaponValue2);
						test2 = (unicode.format(statInfo.format, effectiveprimary_weaponValue2))
							weapontable2[statInfo.display_name] = test2
						
				--end
				
			end
		end
		
		
	end
	end

	--vercheck()
	
	
	self.item_guid = item_guid or itemInfo.item_id or itemInfo.itemId or itemInfo.item_guid or itemInfo.itemTypeId or itemInfo.item_sdb_id
	if self.item_guid then
		self.itemProperties = Player.GetItemProperties(self.item_guid)
	end

	local TF = LIB_ITEMS.GetNameTextFormat(itemInfo, {rarity=itemInfo.rarity});
	TF:ApplyTo(self.LABEL);
	lf.ShrinkTextWidget( self.LABEL );
	
	lf.SetDescriptionText( self.DESCRIPTION, lf.GetItemDescription(itemInfo) );
	lf.SetTimer( self.TIMER, itemInfo.expireTime );
	lf.SetUpgradeRanks(self.RANKS, lf.GetUpgradesStats(itemInfo))
	local stats_lines = {};
	local main_stats_lines = {}
	local sub_stat_lines = {}
	
	
	local isEquipped = (itemInfo.dynamic_flags and itemInfo.dynamic_flags.is_equipped == true);
	if (itemInfo.attributes) then
		for k,v in pairs(itemInfo.attributes) do
		
				
			local perLevelCheck = v.per_level and v.per_level <= 0;

			--skuly
			local att = _table.copy(v)

			if att.value ~= 0 or att.value >= 0.01 then
				if c_PercentageStat[att.stat_id] then
					att.value = att.value * 100
				end
				
			
				if(allStatsById[att.stat_id] and att.value >= 0.0001 and perLevelCheck and isEquipped and itemInfo.type ~= "frame_module") then
				att.value = allStatsById[att.stat_id].current_value;
				att.ability = true
			end
			
			

	if v.display_name == "Health" then
					table.insert(main_stats_lines, lf.FormatAttributeToLine(att, 0, itemInfo.rarity, LIB_ITEMS.C_StatPriorities[name]));
			elseif v.display_name and itemInfo.type ~= "frame_module" then
					if isEquipped and itemInfo.type == "weapon" then
					if itemInfo.slotIdx == 1 then
					for k2,v2 in pairs(weapontable1) do
				if isequal(v.display_name, k2) then
					if k2 == "Magazine Size" then
						local omygod1 = Player.GetAttribute(1371, 0) or 0;
						local ammomag1 = tonumber(omygod1) / 100
						local ammomag2 = ammomag1 * tonumber(v2)
						local ammomag3 = math.floor(ammomag2)
						v2 = ammomag3
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Total Ammo Capacity" then	
						local omygod2 = Player.GetAttribute(1372, 0) or 0;
						local ammocap1 = tonumber(omygod2) / 100
						local ammocap2 = ammocap1 * tonumber(v2)
						local ammocap3 = math.floor(ammocap2)
						v2 = ammocap3
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Reload Speed" then	
						local omygod3 = Player.GetAttribute(1370, 0) or 0;
						local reload1 = tonumber(omygod3) / 100
						local reload2 = reload1 * tonumber(v2)
						local reload3 = reload2
						local val = (unicode.format(v.format, reload3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Ammo Regen (Magazine)" then
						local omygod4 = Player.GetAttribute(1371, 0) or 0;
						local ammoregen1 = tonumber(omygod4) / 100
						local ammoregen2 = ammoregen1 * tonumber(v2)
						local ammoregen3 = ammoregen2
						local val = (unicode.format(v.format, ammoregen3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Overheat Time (Magazine Size)" then
						local omygod5 = Player.GetAttribute(1371, 0) or 0;
						local heat1 = tonumber(omygod5) / 100
						local heat2 = heat1 * tonumber(v2)
						local heat3 = heat2
						local val = (unicode.format(v.format, heat3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Charge-up Duration" then
						v2 = v2
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Damage Per Round" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Bonus Critical Damage" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Range" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Rate of Fire" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Spread" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Weapon Handling" then
						v2 = v2
						
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
						else
						table.insert(stats_lines, lf.FormatAttributeToLine(att, 0, itemInfo.rarity, LIB_ITEMS.C_StatPriorities[name]) );
						end
				end
				
						end
					elseif itemInfo.slotIdx == 2 then
						for k2,v2 in pairs(weapontable2) do
				if isequal(v.display_name, k2) then
					if k2 == "Magazine Size" then
						local omygod1 = Player.GetAttribute(1371, 0) or 0;
						local ammomag1 = tonumber(omygod1) / 100
						local ammomag2 = ammomag1 * tonumber(v2)
						local ammomag3 = math.floor(ammomag2)
						v2 = ammomag3
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Total Ammo Capacity" then	
						local omygod2 = Player.GetAttribute(1372, 0) or 0;
						local ammocap1 = tonumber(omygod2) / 100
						local ammocap2 = ammocap1 * tonumber(v2)
						local ammocap3 = math.floor(ammocap2)
						v2 = ammocap3
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Reload Speed" then	
						local omygod3 = Player.GetAttribute(1370, 0) or 0;
						local reload1 = tonumber(omygod3) / 100
						local reload2 = reload1 * tonumber(v2)
						local reload3 = reload2
						local val = (unicode.format(v.format, reload3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Ammo Regen (Magazine)" then
						local omygod4 = Player.GetAttribute(1371, 0) or 0;
						local ammoregen1 = tonumber(omygod4) / 100
						local ammoregen2 = ammoregen1 * tonumber(v2)
						local ammoregen3 = ammoregen2
						local val = (unicode.format(v.format, ammoregen3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Overheat Time (Magazine Size)" then
						local omygod5 = Player.GetAttribute(1371, 0) or 0;
						local heat1 = tonumber(omygod5) / 100
						local heat2 = heat1 * tonumber(v2)
						local heat3 = heat2
						local val = (unicode.format(v.format, heat3))
						v2 = val
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
						elseif k2 == "Charge-up Duration" then
						v2 = v2
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Damage Per Round" then
						v2 = v2
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Bonus Critical Damage" then
						v2 = v2
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Range" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Rate of Fire" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Spread" then
						v2 = v2
					table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
					elseif k2 == "Weapon Handling" then
						v2 = v2
						
						table.insert(stats_lines, lf.FormatAttributeToLine2(v2, 0, itemInfo.rarity, v.display_name) );
						else
						table.insert(stats_lines, lf.FormatAttributeToLine(att, 0, itemInfo.rarity, LIB_ITEMS.C_StatPriorities[name]) );
						end

						end
						
						end
						
					end
						else
						table.insert(stats_lines, lf.FormatAttributeToLine(att, 0, itemInfo.rarity, LIB_ITEMS.C_StatPriorities[name]) );
						end
					else
				table.insert(stats_lines, lf.FormatAttributeToLine(att, 0, itemInfo.rarity, LIB_ITEMS.C_StatPriorities[name]) );
					end
			
				end
	
			end
		end
	


if (itemInfo.stats) then
		for name,v in pairs(itemInfo.stats) do
		local rofval
		local dpsval
		local dps
			if( not LIB_ITEMS.C_IgnoreStats[name] and (v ~= 0 or v >= 0.01)) then
			if isEquipped then
			if itemInfo.slotIdx == 1 then
			if lf.GetStatDisplayName(name) == "Damage Per Second" then
				for k2,v2 in pairs(weapontable1) do
						if k2 == "Rate of Fire" then
						rofval1 = v2:gsub('%a','')
						rofval = rofval1:gsub('%W','')
						end
						if k2 == "Damage Per Round" then
						dpsval = v2
						end
						local dps1 = (tonumber(dpsval)/tonumber(rofval)) * 1000
						local dps2 = tointeger(dps1)
						dps = reformatInt(dps2)
						end

				table.insert(stats_lines, lf.FormatStatToLine2(name, tostring(dps), nil, LIB_ITEMS.C_StatPriorities[name]));
				else
			table.insert(stats_lines, lf.FormatStatToLine(name, v, nil, LIB_ITEMS.C_StatPriorities[name]));
				end

				elseif itemInfo.slotIdx == 2 then
				if lf.GetStatDisplayName(name) == "Damage Per Second" then
				for k2,v2 in pairs(weapontable2) do
						--Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text=tostring(k2).." = "..tostring(itemInfo.display_name)})
						if k2 == "Rate of Fire" then
						rofval1 = v2:gsub('%a','')
						rofval = rofval1:gsub('%W','')
						
						end
						if k2 == "Damage Per Round" then
						dpsval = v2
						end
						local dps1 = (tonumber(dpsval)/tonumber(rofval)) * 1000
						local dps2 = tointeger(dps1)
						dps = reformatInt(dps2)
						end

				table.insert(stats_lines, lf.FormatStatToLine2(name, tostring(dps), nil, LIB_ITEMS.C_StatPriorities[name]));
				else
			table.insert(stats_lines, lf.FormatStatToLine(name, v, nil, LIB_ITEMS.C_StatPriorities[name]));
				end
				end
				
			else
			table.insert(stats_lines, lf.FormatStatToLine(name, v, nil, LIB_ITEMS.C_StatPriorities[name]));
				end
				
				
				

			end
		end
	end

	if (itemInfo.item_scalars) then
		for k,v in pairs(itemInfo.item_scalars) do
			if v ~= 0 or v >= 0.1 then
				table.insert(stats_lines, lf.FormatScalarsToLine(2, v));
			end
		end
	end


	if (itemInfo.character_scalars) then
		for k,v in pairs(itemInfo.character_scalars) do
			if v ~= 0 or v >= 0.1 then
				if v.name == "Power Rating" then
				if isEquipped then
					table.insert(main_stats_lines, lf.FormatScalarsToLine(3, v, 0, itemInfo.rarity, true));
				else
					table.insert(main_stats_lines, lf.FormatScalarsToLine(3, v, 0, itemInfo.rarity, false));
					end
				else
					table.insert(stats_lines, lf.FormatScalarsToLine(3, v));
				end
			end
		end
	end
	
	if self.itemProperties and self.itemProperties.flags and self.itemProperties.flags.is_bound ~= nil and not self.itemProperties.flags.is_permanent 
	and tonumber(self.itemInfo.subTypeId) ~= SubTypeIds.Consumable then
		local line = lf.FormatBoundToLine(self.itemProperties.flags.is_bound);
		if (line) then
			table.insert(sub_stat_lines, line);
		end
	end

	if self.itemProperties and self.itemProperties.flags and self.itemProperties.flags.is_pvp then
		local line = lf.FormatPVPToLine(self.itemProperties.flags.is_pvp);
		if (line) then
			table.insert(sub_stat_lines, line)
		end
	end

	
	if (itemInfo.durability) then
		local line = lf.FormatDurabilityToLine(itemInfo.durability);
		if (line) then
			table.insert(sub_stat_lines, line);
		end
	end
	
	-- display item level
	if itemInfo.item_level and itemInfo.item_level > 0 then
		table.insert(stats_lines, lf.FormatItemLevelToLine(itemInfo.item_level));
	end
	
	-- display item id for debugging
	if itemInfo.itemTypeId and Player.IsDevChar() then
		table.insert(stats_lines, lf.FormatSDBIdToLine(itemInfo.itemTypeId));
	end
	
	local has_requirements = false;
	local requirements_lines = {};
	
	-- display cert req's
	local line = lf.FormatCertsToLine(itemInfo.certifications, self.context);
	if (line) then
		table.insert(requirements_lines, line);
		has_requirements = true;
	end
	
	-- display elite level req
	g_hasEliteRequirement = false
	if itemInfo.elite_level and itemInfo.elite_level > 0 then
		local line = lf.FormatRequiredEliteLevelToLine(itemInfo.elite_level)
		if (line) then
			table.insert(requirements_lines, line);
			self.ELITE_ICON:SetDims("center-x:16; width:40; aspect:1.77; top:"..self.REQUIREMENTS.GROUP:GetDims().top.offset + c_EliteIconOffset)
			has_requirements = true;
			g_hasEliteRequirement = true
		end
	end
	self.ELITE_ICON:SetParam("alpha", g_hasEliteRequirement and 1 or 0)
	
	-- display level req
	if itemInfo.required_level and itemInfo.required_level > 1 then
		local line = lf.FormatRequiredLevelToLine(itemInfo.required_level)
		if (line) then
			table.insert(requirements_lines, line);
			has_requirements = true;
		end
	end
	
	if #stats_lines > 0 then
		self.DIVIDER:Show()
	else
		self.DETAIL_DIVIDER:Hide()
		self.SUB_DIVIDER:Hide()
		self.DIVIDER:Hide()
	end

	self.CANNOT_TRADE:Hide(self.itemProperties.flags and self.itemProperties.flags.is_tradable)
	

	--show market stats


marketeer = function(args)
		if args.text == "on" then
			enablemarket.status = true
			Component.SaveSetting("market", enablemarket.status)
		elseif args.text == "off" then
			enablemarket.status = false
			Component.SaveSetting("market", enablemarket.status)
			end
	end

	if enablemarket.status and (self.itemProperties.flags and self.itemProperties.flags.is_tradable and not self.itemProperties.flags.is_bound) and not isEquipped then
		if itemInfo.itemTypeId and webCacheBuy[tostring(itemInfo.itemTypeId)] then --used cached data
			local my_TF = TextFormat.Create();
						
			local buy_order = webCacheBuy[tostring(itemInfo.itemTypeId)].orders[1]
			my_TF:AppendColor(c_BOOST_COLOR);
			my_TF:AppendText("Buy Order Price"..c_COLON_SPACING)
			my_TF:AppendColor(c_STAT_COLOR)
						
			if not buy_order then
				my_TF:AppendText("N/A")
			else
				my_TF:AppendText(_math.MakeReadable(buy_order.price_per_unit))
							
			end

			-- set text
			TextFormat.Clear(self.BUYORDER);
			my_TF:ApplyTo(self.BUYORDER);
			self["TextFormat_"..self.BUYORDER:GetName()] = my_TF
			self.BUYORDER:Show();
			self.BUYORDER:SetDims( "height:"..self.BUYORDER:GetTextDims().height );
		else
			local token = ReturnTokenOfItem(itemInfo)
			IssueHTTPRequest(System.GetOperatorSetting("clientapi_host").."/api/v2/market/search/tokens/"..tostring(token), "GET", nil, function(args, err)
						if not webCacheBuy[tostring(itemInfo.itemTypeId)] then
							webCacheBuy[tostring(itemInfo.itemTypeId)] = args --cache the data
							Callback2.FireAndForget(function() webCacheBuy[tostring(itemInfo.itemTypeId)] = nil end, nil, 60) --have the cache time out
						end
						if not self.BUYORDER then return end --the tooltip was removed before the web server responded
						local my_TF = TextFormat.Create();
						local buy_order;
						if args ~= nil then
						buy_order = args.orders[1]
						end
						
						my_TF:AppendColor(c_BOOST_COLOR);
						my_TF:AppendText("Buy Order Price"..c_COLON_SPACING)
						my_TF:AppendColor(c_STAT_COLOR)
						
						if not buy_order then
							my_TF:AppendText("N/A")
						else
							my_TF:AppendText(_math.MakeReadable(buy_order.price_per_unit))
							
						end

						-- set text
						TextFormat.Clear(self.BUYORDER);
						my_TF:ApplyTo(self.BUYORDER);
						self["TextFormat_"..self.BUYORDER:GetName()] = my_TF
						self.BUYORDER:Show();
						self.BUYORDER:SetDims( "height:"..self.BUYORDER:GetTextDims().height );
			end)
		end


		if itemInfo.itemTypeId and webCacheSell[tostring(itemInfo.itemTypeId)] then --used cached data
			local text = "N/A"; --if there isn't anything for purchase, then the for loop won't run
			local my_TF = TextFormat.Create();
			my_TF:AppendColor(c_BOOST_COLOR);
			my_TF:AppendText("Selling Price"..c_COLON_SPACING)
			my_TF:AppendColor(c_STAT_COLOR)

			for _, ITEM in pairs(webCacheSell[tostring(itemInfo.itemTypeId)].results) do
				if(tostring(ReturnTokenOfItem(itemInfo)) == tostring(ITEM.item_token)) then
					if tonumber(ITEM.min_price) >= 1 then --there are sale orders --problem line
						text = _math.MakeReadable(ITEM.min_price)
						--ITEM.max_order_price
					end
				break
				end
			end
			-- set text
			my_TF:AppendText(text)
			TextFormat.Clear(self.SELLORDER);
			my_TF:ApplyTo(self.SELLORDER);
			self["TextFormat_"..self.SELLORDER:GetName()] = my_TF
			self.SELLORDER:Show();
			self.SELLORDER:SetDims( "height:"..self.SELLORDER:GetTextDims().height );
		else
			local token = ReturnTokenOfItem(itemInfo)
			IssueHTTPRequest(System.GetOperatorSetting("clientapi_host").."/api/v2/market/search/item_sdb_ids", "POST", {item_sdb_ids={token}}, function(args, err) 
						if not webCacheSell[tostring(itemInfo.itemTypeId)] then
							webCacheSell[tostring(itemInfo.itemTypeId)] = args --cache the data
							Callback2.FireAndForget(function() webCacheSell[tostring(itemInfo.itemTypeId)] = nil end, nil, 60) --have the cache time out
						end
						if not self.SELLORDER then return end --the tooltip was removed before the web server responded
						local text = "N/A"; --if there isn't anything for purchase, then the for loop won't run
						local my_TF = TextFormat.Create();
						my_TF:AppendColor(c_BOOST_COLOR);
						my_TF:AppendText("Selling Price"..c_COLON_SPACING)
						my_TF:AppendColor(c_STAT_COLOR)
						for _, ITEM in pairs(args.results) do
							if(tostring(token) == tostring(ITEM.item_token)) then
								if tonumber(ITEM.min_price) >= 1 then --there are sale orders --problem line
									text = _math.MakeReadable(ITEM.min_price)
									--ITEM.max_order_price
								end
							break
							end
						end

						-- set text
						my_TF:AppendText(text)
						TextFormat.Clear(self.SELLORDER);
						my_TF:ApplyTo(self.SELLORDER);
						self["TextFormat_"..self.SELLORDER:GetName()] = my_TF
						self.SELLORDER:Show();
						self.SELLORDER:SetDims( "height:"..self.SELLORDER:GetTextDims().height );
			end);
		end
	else 
		self.BUYORDER:Show(false);
		self.SELLORDER:Show(false);
	end

	self.WEIGHTLESS_GROUP:Show((itemInfo.flags.is_unlimited or itemInfo.flags.unlimited) and not(Game and Game.IsItemOfType(itemInfo.item_sdb_id, SubTypeIds.Currency)))

	-- Weapon/Ability Module Display
	local modules_lines = {}
	local has_modules = false
	local module_info = Game and Game.GetModuleSlotsForItem(itemInfo.itemTypeId)
	if module_info then
		self.module_slots = {}
		for idx, color in ipairs(module_info) do
			local tbl = {
				slotColor = color,
				slotIndex = idx,
			}
			if self.itemInfo.slotted_modules then
				tbl.moduleId = self.itemInfo.slotted_modules[idx]
			else
				tbl.moduleId = Player.GetSlottedItemAtIndex(self.item_guid, idx)
			end
			table.insert(self.module_slots, tbl)
		end
		if #self.module_slots > 0 then
			has_modules = true
			local line = lf.DisplayModules(self.MODULES.EMPTY_GROUP, self.module_slots)
			table.insert(modules_lines, line)
		end
	end
	lf.PrintLines( modules_lines, self.MODULES.SLOTS, self)
	self.MODULES.GROUP:Show(has_modules)
	self.MODULES.GROUP:SetDims("height:" .. self.MODULES.GROUP:GetLength())

	if #main_stats_lines > 0 then
		self.DETAIL_DIVIDER:Show()
		lf.PrintLines(main_stats_lines, self.DETAIL_MAIN, self)
	else
		self.DETAIL_DIVIDER:Hide()
		self.DETAIL_MAIN:Hide()
	end

	if #sub_stat_lines > 0 then
		self.SUB_DIVIDER:Show()
		lf.PrintLines(sub_stat_lines, self.SUB_DETAIL, self)
	else
		self.SUB_DETAIL:Hide()
		self.SUB_DIVIDER:Hide()
	end

	lf.PrintLines( stats_lines, self.DETAIL, self );
	lf.PrintLines( requirements_lines, self.REQUIREMENTS.TEXT, self, true );
	self.REQUIREMENTS.GROUP:Show(has_requirements and (self.showRequirements ~= false)); -- specifically false because nil means not set
	self.REQUIREMENTS.GROUP:SetDims("height:" .. self.REQUIREMENTS.GROUP:GetLength())
end

function TOOLTIP_API:CompareAgainst(itemInfo, item_guid)
	-- show differences in yourself
	assert(self.itemInfo, "Set own info before comparing against another");
	--self.itemInfo = this item's info
	--itemInfo = other item's info
	if ( itemInfo ) then
		item_guid = item_guid or itemInfo.item_id or itemInfo.itemId or itemInfo.item_guid
		
		LIB_ITEMS.GetNameTextFormat(self.itemInfo, {rarity=self.itemInfo.rarity}):ApplyTo(self.LABEL);
		lf.ShrinkTextWidget( self.LABEL );
		
		lf.SetDescriptionText( self.DESCRIPTION, lf.GetItemDescription(self.itemInfo) );
		local isEquipped = itemInfo.dynamic_flags and itemInfo.dynamic_flags.is_equipped == true;
		local mergedInfo = self.itemInfo;
		-- compare stats for weapons, ability modules, and frame modules
		mergedInfo = lf.MergeStats( self.itemInfo , itemInfo );
		-- format stats
		local stats_lines = {};
		local main_stats_lines = {}
		local sub_stat_lines = {}
		for k,att in pairs(mergedInfo.attributes or {}) do
			--if att.value ~= 0 then
			if att.value ~= 0 or att.value >= 0.1 then
				if att.display_name == "Health" then
					table.insert(main_stats_lines, lf.FormatAttributeToLine(att, att.delta, self.itemInfo.rarity, LIB_ITEMS.C_StatPriorities[k]));
				else
					table.insert(stats_lines, lf.FormatAttributeToLine(att, att.delta));
				end
			end
		end
		for name,v in pairs(mergedInfo.stats or {}) do
			if( not LIB_ITEMS.C_IgnoreStats[name] and (v ~= 0 or v >= 0.01)) then
				if( type(v) == "table" )then
					table.insert(stats_lines, lf.FormatStatToLine(name, v, v.delta, LIB_ITEMS.C_StatPriorities[name]));
				else
					table.insert(stats_lines, lf.FormatStatToLine(name, v, nil, LIB_ITEMS.C_StatPriorities[name]));
				end
			end
		end
		for k,v in pairs(mergedInfo.item_scalars or {}) do
			if v ~= 0 or v >= 0.01 then
				table.insert(stats_lines, lf.FormatScalarsToLine(2, v, v.delta));
			end
		end
		for k,v in pairs(mergedInfo.character_scalars or {}) do
			if v ~= 0 then
				if v.name == "Power Rating" then
					table.insert(main_stats_lines, lf.FormatScalarsToLine(3, v, v.delta, self.itemInfo.rarity));
				else
					table.insert(stats_lines, lf.FormatScalarsToLine(3, v, v.delta));
				end
			end
		end
		
		-- display item level
		if self.itemInfo.item_level and self.itemInfo.item_level > 0 then
			table.insert(stats_lines, lf.FormatItemLevelToLine(self.itemInfo.item_level, itemInfo.item_level));
		end
		
		-- display item id for debugging
		if self.itemInfo.itemTypeId and Player.IsDevChar() then
			table.insert(stats_lines, lf.FormatSDBIdToLine(self.itemInfo.itemTypeId));
		end
		
		if self.itemProperties and self.itemProperties.flags and self.itemProperties.flags.is_bound ~= nil then
			local line = lf.FormatBoundToLine(self.itemProperties.flags.is_bound);
			if (line) then
				table.insert(sub_stat_lines, line);
			end
		end

		if self.itemProperties and self.itemProperties.flags and self.itemProperties.flags.is_pvp then
			local line = lf.FormatPVPToLine(self.itemProperties.flags.is_pvp);
			if (line) then
				table.insert(sub_stat_lines, line)
			end
		end
	
		-- format durability
		if (self.itemInfo.durability) then
			local other_durability = itemInfo.durability or {};
			local line = lf.FormatDurabilityToLine(self.itemInfo.durability, other_durability);
			if (line) then
				table.insert(sub_stat_lines, line);
			end
		end
		
		-- format contraint data
		local has_requirements = false;
		local requirements_lines = {};
		
		-- display cert req's
		local line = lf.FormatCertsToLine(self.itemInfo.certifications, self.context);
		if (line) then
			table.insert(requirements_lines, line);
			has_requirements = true;
		end
		
		-- display elite level req
		g_hasEliteRequirement = false
		if self.itemInfo.elite_level and self.itemInfo.elite_level > 0 then
			local line = lf.FormatRequiredEliteLevelToLine(self.itemInfo.elite_level)
			if (line) then
				table.insert(requirements_lines, line);
				self.ELITE_ICON:SetDims("center-x:16; width:40; aspect:1.77; top:"..self.REQUIREMENTS.GROUP:GetDims().top.offset + c_EliteIconOffset)
				g_hasEliteRequirement = true
				has_requirements = true;
			end
		end
		self.ELITE_ICON:SetParam("alpha", g_hasEliteRequirement and 1 or 0)
		
		-- display level req
		if self.itemInfo.required_level and self.itemInfo.required_level > 1 then
			local line = lf.FormatRequiredLevelToLine(self.itemInfo.required_level)
			if (line) then
				table.insert(requirements_lines, line);
				has_requirements = true;
			end
		end
		
		if #stats_lines > 0 then
			self.DIVIDER:Show()
		else
			self.DETAIL_DIVIDER:Hide()
			self.DIVIDER:Hide()
		end

		if #main_stats_lines > 0 then
			self.DETAIL_DIVIDER:Show()
			lf.PrintLines( main_stats_lines, self.DETAIL_MAIN, self)
		else
			self.DETAIL_DIVIDER:Hide()
			self.DETAIL_MAIN:Hide()
		end

		if #sub_stat_lines > 0 then
			self.SUB_DIVIDER:Show()
			lf.PrintLines(sub_stat_lines, self.SUB_DETAIL, self)
		else
			self.SUB_DETAIL:Hide()
			self.SUB_DIVIDER:Hide()
		end

		lf.PrintLines( stats_lines, self.DETAIL, self );
		lf.PrintLines( requirements_lines, self.REQUIREMENTS.TEXT, self, true );
		self.REQUIREMENTS.GROUP:Show(has_requirements);
		self.REQUIREMENTS.GROUP:SetDims("height:" .. self.REQUIREMENTS.GROUP:GetLength())
	else
		self:DisplayInfo( self.itemInfo )
	end
end

function TOOLTIP_API:DisplayTag(tag)
	if (tag) then
		self.TAG.TEXT:SetTextKey( tag );
		local dims = self.TAG.TEXT:GetTextDims();
		local padding = self.TAG.TEXT:GetParam("padding")+5;
		self.TAG.GROUP:SetDims("center-x:_; center-y:_; width:"..(padding+dims.width).."; height:"..(padding+dims.height));
		self.TAG.GROUP:Show( true )
	else
		self.TAG.TEXT:SetText( "" );
		self.TAG.GROUP:Show( false )
	end
end


-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.SetDescriptionText(WIDGET, text)
	if unicode.len(text) > 0 then
		WIDGET:Show()
		local TF = TextFormat.Create()
		TF.default_color = "#7b8696"
		local function FormatText(str)
			TF:AppendText(str)
		end
		local handlers = {}
		TF:AddColorHandlers(handlers)
		TextFormat.HandleString(text, FormatText, handlers)
		TF:ApplyTo(WIDGET)
		lf.ShrinkTextWidget(WIDGET)
	else
		WIDGET:Hide()
	end
end

function lf.ParseAllStats()
	local allStats = Player.GetAllStats();
	local parsedStats = {};
	
	for k,stat in pairs(allStats.attribute_categories) do
		parsedStats[stat.stat_id] = stat;
	end

	for k,stat in pairs(allStats.item_attributes) do
		parsedStats[stat.stat_id] = stat;
	end
	
	return parsedStats;
end

function lf.SetTimer(WIDGET, time)
	if time then
		WIDGET:Show()
		WIDGET:GetChild("timer"):StopTimer()
		local time_to_expire = time - System.GetLocalUnixTime()
		WIDGET:GetChild("timer"):StartTimer(time_to_expire, true)

		WIDGET:SetDims("height:10");
		--lf.ShrinkTextWidget(WIDGET)
	else
		WIDGET:Hide()
		WIDGET:GetChild("timer"):StopTimer()
		WIDGET:SetDims("height:0");
	end
end

function lf.GetItemDescription(itemInfo)
	local resource_info = Game and Game.GetResourceTypeInfo(itemInfo.subTypeId)
	local str = ""
	if resource_info and resource_info.name then
		str = resource_info.name
	end
	while resource_info and not resource_info.market_category and resource_info.parentResourceTypeId do
		resource_info = Game.GetResourceTypeInfo(resource_info.parentResourceTypeId)
		if resource_info and resource_info.name then
			str = str..", "..resource_info.name
		end
	end
	if itemInfo.description then
		if unicode.len(str) > 0 then
			str = str.."\n\n"
		end
		str = str..itemInfo.description
	end

	if itemInfo.hidden_modules and next(itemInfo.hidden_modules) ~= nil then--#itemInfo.hidden_modules > 0 then
		if unicode.len(str) > 0 then
			str = str.."\n"
		end
		for _, moduleId in pairs(itemInfo.hidden_modules) do
			local moduleItemInfo = Game.GetItemInfoByType(moduleId)
			if moduleItemInfo.type then
				if unicode.len(str) > 0 then
					str = str.."\n"
				end
				str = str..moduleItemInfo.description
			end
		end
	end
	
	return str
end

function lf.SetUpgradeRanks(WIDGET, ranks)
	if ranks.level == 0 then
		WIDGET:Show(false)
	else
		WIDGET:Show(true)
		local index = 1
		for i=1, ranks.crits do
			if index > 0 and index < 10 then
				local SECTION = WIDGET:GetChild("section_"..math.floor(((index-1) / 3)+ 1))
				local RANK = SECTION:GetChild("rank_"..index)
				RANK:SetRegion("critical")
				index = index + 1
			end
		end
		for i = ranks.crits + 1, ranks.level do
			if index > 0 and index < 10 then
				local SECTION = WIDGET:GetChild("section_"..math.floor(((index-1) / 3)+ 1))
				local RANK = SECTION:GetChild("rank_"..index)
				RANK:SetRegion("normal")
				index = index + 1
			end
		end
	end
end

function lf.GetUpgradesStats(itemInfo)
	local level = 0
	local crits = 0
	if itemInfo.hidden_modules and next(itemInfo.hidden_modules) ~= nil then
		local module = itemInfo.hidden_modules[2]
		if module and Game.IsItemOfType(module, 3734) then
			local moduleInfo = Game.GetItemInfoByType(module)
			if moduleInfo and moduleInfo.tier and moduleInfo.tier.level then
				level = moduleInfo.tier.level
			end
		end
		module = itemInfo.hidden_modules[3]
		if module and Game.IsItemOfType(module, 3734) then
			local moduleInfo = Game.GetItemInfoByType(module)
			if moduleInfo and moduleInfo.tier and moduleInfo.tier.level then
				crits = moduleInfo.tier.level
			end
		end
	end
	return {level=level, crits=crits}
end

function lf.GetStatDisplayName( stat )
	local stat_name = Component.LookupText( "STAT_"..stat )
	if stat_name == nil or unicode.find(stat_name, "UIKeyNotFound") ~= nil then
		stat_name = stat
	end

	return stat_name
end

function lf.GetFormattedNumber(format, number)
	format = format or "%.2f"
	local str = unicode.format(format, number)
	--strip off trailing decimal zeros
	str = unicode.gsub(str, "(%d+)(%.0+)%f[%D]", "%1" )
	str = unicode.gsub(str, "(%d+%.%d-)(0+)%f[%D]", "%1" )
	return str
end

function lf.MergeStats( base, comp )
	-- lf.MergeStats takes stats and attributes and calculates the difference between the items
	local merged = {
		attributes = {},
		stats = {},
		item_scalars = {},
		character_scalars = {},
	};

	local alreadyusedstats = {}
	
	-- merge attribute data
	if base.attributes then
		-- populate existing attributes
		local compattributes_byid = {}
		if comp.attributes then
			for _,att in ipairs(comp.attributes) do
				if att.stat_id then
					compattributes_byid[att.stat_id] = att
				end
			end
		end
		for _, att in ipairs(base.attributes) do
			local statid = att.stat_id
			alreadyusedstats[statid] = true
			--[[local delta = compattributes_byid[statid] and att.value-compattributes_byid[statid].value or 0
			delta = delta < .05 and delta > -.05 and 0 or delta--]]
			merged.attributes[statid] = {
				stat_id = statid,
				value = att.value,
				display_name = att.display_name,
				format = att.format,
				inverse = att.inverse,
				min = att.min,
				max = att.max,
				display_order = display_order,
				delta = compattributes_byid[statid] and att.value-compattributes_byid[statid].value,
			}
		end

		--[[
		for i, att in ipairs(base.attributes) do
			log(tostring(att))
			merged.attributes[att.stat_id] = {
				stat_id = att.stat_id,
				value = att.value,
				display_name = att.display_name,
				format = att.format,
				inverse = att.inverse,
				min = att.min,
				max = att.max,
				display_order = display_order,
				delta = att.value,
			}
		end
		
		-- compare attributes
		if comp.attributes then
			for i, att in ipairs(comp.attributes) do
				if not merged.attributes[att.stat_id] then
					-- populate missing attributes
					merged.attributes[att.stat_id] = {
						stat_id = att.stat_id,
						value = 0,
						display_name = att.display_name,
						format = att.format,
						inverse = att.inverse,
						min = att.min,
						max = att.max,
						display_order = display_order,
						delta = 0-att.value,
					}
				else
					merged.attributes[att.stat_id].delta = merged.attributes[att.stat_id].value - att.value;
				end
			end
		end
		--]]
	end
	
	-- merge stat data
	--[ [TODO: max ammo stat is repeated because there's one version in the attributes section and a another one in the stats section
	if base.stats then
		for name, value in pairs(base.stats) do
			if not LIB_ITEMS.C_IgnoreStats[name] then
				local delta = value;
				if comp.stats and comp.stats[name] then
					delta = value - comp.stats[name];
				end
				merged.stats[name] = {
					value = value,
					delta = delta,
					inverse = false,--Nothing to invert right now
					--inverse = c_InvertStats[name],
				};
			end
		end
	end
	if comp.stats then
		for name, value in pairs(comp.stats) do
			if not LIB_ITEMS.C_IgnoreStats[name] and not merged.stats[name] then
				merged.stats[name] = {
					value = 0,
					delta = -value,
				};
			end
		end
	end
	--]]
	
		-- merge item_scalars data
	if base.item_scalars then
		-- populate existing item_scalars
		for i, v in ipairs(base.item_scalars) do
			local value = math.abs(v.value)
			merged.item_scalars[v.name] = {
				value = value,
				name = v.name,
				format = v.format,
				delta = value,
			}
		end
		
		-- compare item_scalars
		if comp.item_scalars then
			for i, v in ipairs(comp.item_scalars) do
				if not merged.item_scalars[v.name] then
					-- populate missing item_scalars
					merged.item_scalars[v.name] = {
						value = 0,
						name = v.name,
						format = v.format,
						delta = -math.abs(v.value),
					}
				else
					merged.item_scalars[v.name].delta = merged.item_scalars[v.name].value - math.abs(v.value);
				end
			end
		end 
	end
	
		-- merge character_scalars data
	if base.character_scalars then
		-- populate existing character_scalars
		for i, v in ipairs(base.character_scalars) do
			local value = math.abs(v.value)
			merged.character_scalars[v.name] = {
				value = value,
				name = v.name,
				format = v.format,
				delta = value,
			}
		end
		
		-- compare character_scalars
		if comp.character_scalars then
			for i, v in ipairs(comp.character_scalars) do
				if not merged.character_scalars[v.name] then
					-- populate missing character_scalars
					merged.character_scalars[v.name] = {
						value = 0,
						name = v.name,
						format = v.format,
						delta = -math.abs(v.value),
					}
				else
					merged.character_scalars[v.name].delta = merged.character_scalars[v.name].value - math.abs(v.value);
				end
			end
		end 
	end
	
	return merged;
end

function lf.SortAttributes(A,B)
	return A.sort_weight < B.sort_weight;
end

function lf.AppendFormattedDeltaString(line, delta, format, isboost)
	if (not format or format == "") then
		format = "%.2f";
	end
	local sign = "+";
	if (delta < 0) then
		sign = "";	-- negatives already have a '-'
	end
	local str = lf.GetFormattedNumber(format, delta)
	if str == "0" then return "" end
	str = sign..str;

	if isboost then
		line.textFormat:AppendColor(c_BOOST_COLOR);
	else
		line.textFormat:AppendColor(c_DROP_COLOR);
	end
	line.textFormat:AppendText(" ("..str..")");
end

function lf.FormatCertsToLine(item_certs, context)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = -1,
		sub_sort = 0,
	};
	
	local my_frame_id
	if (context and context.frameTypeId) then
		my_frame_id = tostring(context.frameTypeId)
	else
		local loadoutInfo = Player and Player.GetCurrentLoadout()
		if loadoutInfo then
			my_frame_id = tostring(loadoutInfo.item_types.chassis)
		end
	end
	
	-- order the item_certs
	local ordered_certs = {};
	for _, certId in pairs(item_certs) do
		table.insert(ordered_certs, certId);
	end

	if (#ordered_certs == 0) then
		-- early out
		return nil;
	end
	
	for i, certId in pairs(ordered_certs) do
		if not Unlocks.HasUnlock("certificate", certId, my_frame_id) then
			line.textFormat:AppendColor(c_CRITICAL_COLOR);
		else
			line.textFormat:AppendColor(c_LABEL_COLOR);
		end
		local certInfo = Game.GetCertificationInfo(certId);
		line.textFormat:AppendText(Component.LookupText("REQUIRES_CERT", certInfo.name));
		if (i < #ordered_certs) then
			line.textFormat:AppendText("\n");
		end
	end
	return line;
end

function lf.FormatStatToLine(stat_name, stat, delta, override_sub_sort)
	-- for use in lf.PrintLines
	local display_name = lf.GetStatDisplayName(stat_name);
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 2,
		sub_sort = override_sub_sort or display_name,
	};
	line.textFormat:AppendColor(c_LABEL_COLOR);
	line.textFormat:AppendText(display_name..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	if tonumber(stat) ~= -1 then
		line.textFormat:AppendText(lf.GetFormattedNumber("%.2f", stat))
	else
		line.textFormat:AppendText(lf.GetFormattedNumber("%.2f", stat.value))
	end
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line,delta, nil, (delta < 0) == stat.inverse))
	end
	return line;
end

function lf.FormatStatToLine2(stat_name, stat, delta, override_sub_sort)
	-- for use in lf.PrintLines
	local display_name = lf.GetStatDisplayName(stat_name);
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 2,
		sub_sort = override_sub_sort or display_name,
	};
	line.textFormat:AppendColor(c_LABEL_COLOR);
	line.textFormat:AppendText(display_name..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	line.textFormat:AppendText(tostring(stat))
	
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line,delta, nil, (delta < 0) == stat.inverse))
	end
	return line;
end



--[[
function lf.FormatStatToLine(stat_name, stat, delta, override_sub_sort, stat2, color)
	-- for use in lf.PrintLines
	local display_name = lf.GetStatDisplayName(stat_name);

	
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 2,
		sub_sort = override_sub_sort or display_name,
	};
	

	if tonumber(stat) ~= -1 then
	if isequal(stat2, stat) then
	line.textFormat:AppendColor(c_LABEL_COLOR);
	else
	line.textFormat:AppendColor(color);
	end
	else
	line.textFormat:AppendColor(c_LABEL_COLOR);
	end
	
	line.textFormat:AppendText(display_name..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);

	if tonumber(stat) ~= -1 then
		if isequal(stat2, stat) then
		line.textFormat:AppendText(lf.GetFormattedNumber("%.2f", stat))
		else
		line.textFormat:AppendText(lf.GetFormattedNumber("%.2f", stat2).." ("..lf.GetFormattedNumber("%.2f", stat)..")")
		end
	else
		line.textFormat:AppendText(lf.GetFormattedNumber("%.2f", stat.value))
	end
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line,delta, nil, (delta < 0) == stat.inverse))
	end

	
	return line;
end
--]]


function lf.FormatAttributeToLine2(att, delta, color, sorting)
	-- for use in lf.PrintLines
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 1,
		sub_sort = sorting,
	};
	local value_display
	value_display = tostring(att);
	

	line.textFormat:AppendColor(c_LABEL_COLOR);
	line.textFormat:AppendText(sorting..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	line.textFormat:AppendText(value_display);
	
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line, delta, att.format, (delta < 0) == att.inverse))
	end
	
	return line;
end


function lf.FormatAttributeToLine(att, delta, color, override_sub_sort)
	-- for use in lf.PrintLines
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 1,
		--sub_sort = att.display_order or att.display_name,
		sub_sort = override_sub_sort or att.display_name,
	};

	local value_display;

	line.textFormat:AppendColor(c_LABEL_COLOR);
	
	
	if( att.format and att.format ~= "" ) then
		if (unicode.find(att.format, " %% ")) then
			warn("Bad format "..tostring(att.format));
			value_display = tostring(att.value);
		else
			value_display = lf.GetFormattedNumber(att.format, att.value);
		end
	else
		value_display = lf.GetFormattedNumber( "%.2f", att.value)
	end
	
	
	line.textFormat:AppendText(att.display_name..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	line.textFormat:AppendText(value_display);
	
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line, delta, att.format, (delta < 0) == att.inverse))
	end
	
	return line;
end


function lf.FormatScalarsToLine(super_sort, scaler, delta, color, equiped)
	-- for use in lf.PrintLines
	
	if scaler.name == "Power Rating" then
	if equiped then
	scaler.name = "Real-Info: v"..g_version.."\n".."Power Rating"
	else
	scaler.name = scaler.name
	end
	end
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = super_sort,
		sub_sort = scaler.name,
	};
	
	local value_display;
	local value = math.abs(scaler.value)
	if( scaler.format and scaler.format ~= "" ) then
		if (unicode.find(scaler.format, " %% ")) then
			warn("Bad format "..tostring(scaler.format));
			value_display = tostring(value);
		else
			value_display = lf.GetFormattedNumber(scaler.format, value);
		end
	else
		value_display = lf.GetFormattedNumber( "%.2f", value)
	end
	line.textFormat:AppendColor(color or c_LABEL_COLOR);
	line.textFormat:AppendText(scaler.name..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	line.textFormat:AppendText(value_display);
	
	if (delta and delta ~= 0) then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line, delta, scaler.format, delta > 0));
	end
	
	return line;
end

function lf.FormatItemLevelToLine(level, compare_level)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = -9,
		sub_sort = "ItemLevel",
	};
	line.textFormat:AppendColor(c_LABEL_COLOR);
	line.textFormat:AppendText(Component.LookupText("ITEM_LEVEL")..c_COLON_SPACING)
	line.textFormat:AppendColor(c_STAT_COLOR)
	line.textFormat:AppendText(level)
	if compare_level and level ~= compare_level then
		line.textFormat:AppendText(lf.AppendFormattedDeltaString(line, level-compare_level, "%d", level > compare_level));
	end
	return line;
end

function lf.FormatRequiredLevelToLine(level)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = -2,
		sub_sort = 0,
	};
	local currentlevel = Player.GetLevel()
	if currentlevel < level then
		line.textFormat:AppendColor(c_CRITICAL_COLOR);
	else
		line.textFormat:AppendColor(c_LABEL_COLOR);
	end
	line.textFormat:AppendText(Component.LookupText("REQUIRES_LEVEL", level));
	return line;
end

function lf.FormatRequiredEliteLevelToLine(level)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = -2,
		sub_sort = 0,
	};
	
	local currentlevel = Player.GetEliteLevelsInfo_XpAndLevel().current_level
	if currentlevel < level then
		line.textFormat:AppendColor(c_CRITICAL_COLOR);
	else
		line.textFormat:AppendColor(c_LABEL_COLOR);
	end
	line.textFormat:AppendText(Component.LookupText("REQUIRES_ELITE_RANK", level));
	return line;
end

function lf.FormatSDBIdToLine(itemTypeId)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = -10,
		sub_sort = "SDB ID",
	};
	line.textFormat:AppendColor(c_LABEL_COLOR);
	line.textFormat:AppendText("SDB ID"..c_COLON_SPACING);
	line.textFormat:AppendColor(c_STAT_COLOR);
	line.textFormat:AppendText(itemTypeId);
	return line;
end

function lf.FormatBoundToLine(is_bound)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 5,
		sub_sort = 1,
	};
	if (is_bound) then
		line.textFormat:AppendColor(c_DROP_COLOR);
		line.textFormat:AppendText(Component.LookupText("ITEM_TOOLTIP_BOUND"))
	else
		line.textFormat:AppendColor(c_LABEL_COLOR);
		line.textFormat:AppendText(Component.LookupText("ITEM_TOOLTIP_BIND_EQUIP"))

	end
	
	return line;
end

function lf.FormatPVPToLine(is_pvp)
	local line = {
		textFormat = TextFormat.Create(),
		super_sort = 5,
		sub_sort = 1,
	};
	if (is_pvp) then
		line.textFormat:AppendColor(c_DROP_COLOR);
		line.textFormat:AppendText(Component.LookupText("ITEM_TOOLTIP_PVP"))
	end
	
	return line;
end

function lf.FormatDurabilityToLine(durability, comp_durability)
	-- ignore comp_durability
	if type(durability) == "number" then
		durability = {current=durability}
	end
	if type(comp_durability) == "number" then
		comp_durability = {current=comp_durability}
	end
	if (durability and durability.current or durability.unbreakable) then
		local line = {
			textFormat = TextFormat.Create(),
			super_sort = 4,
			sub_sort = 1,
		};
		line.textFormat:AppendColor(c_LABEL_COLOR);
		line.textFormat:AppendText(unicode.format("%s: ", Component.LookupText("DURABILITY")));
		if (durability.unbreakable) then
			line.textFormat:AppendColor(Colors.MakeGradient("condition", 1));
			line.textFormat:AppendText(Component.LookupText("INFINITY_SYMBOL"));
		else
			line.textFormat:AppendColor(Colors.MakeGradient("condition", durability.current / LIB_ITEMS.C_MaxDurability));
			line.textFormat:AppendText(unicode.format("%d/%d", durability.current, LIB_ITEMS.C_MaxDurability));
		end
		
		return line;
	end
	--return nil;
end

function lf.PrintLines(lines, TEXT_WIDGET, TOOLTIP, isPrintingRequirements)
	-- lines[idx] = {display_text, super_sort, sub_sort, color}
	local sorted = {};
	
	for k,value in pairs(lines) do
		table.insert(sorted, value);
	end
	
	table.sort(sorted, function(A,B)
		-- super_sort: separates entries into 'categories'
		if A.super_sort ~= B.super_sort then
			-- sub_sort: sorting within categories
			return A.super_sort > B.super_sort;
		else
			return A.sub_sort > B.sub_sort;
		end
	end);
	
	local lines = {};
	local n = #sorted;
	if (n > 0) then
		local my_TF = TextFormat.Create();
		for i,entry in ipairs(sorted) do
			my_TF:Concat(entry.textFormat);
			if (i < n) then
				if(i == 1 and g_hasEliteRequirement and isPrintingRequirements) then -- elite level should always show as second req if it exists
					my_TF:AppendText("\n       ");
				else
					my_TF:AppendText("\n");
				end
			end
		end
		-- set text
		TextFormat.Clear(TEXT_WIDGET);
		my_TF:ApplyTo(TEXT_WIDGET);
		TOOLTIP["TextFormat_"..TEXT_WIDGET:GetName()] = my_TF
		TEXT_WIDGET:Show();
		TEXT_WIDGET:SetDims( "height:"..TEXT_WIDGET:GetTextDims().height );	
	else
		TOOLTIP["TextFormat_"..TEXT_WIDGET:GetName()] = nil
		TEXT_WIDGET:Show(false);
		TEXT_WIDGET:SetDims("height:0");
	end
end

function lf.DisplayModules(PARENT, module_slots)
	if module_slots then
		local line = {
			textFormat = TextFormat.Create(),
			super_sort=1,
			sub_sort=1
		}
		local first = true
		
		for idx, module_slot in ipairs(module_slots) do
			if not first then
				line.textFormat:AppendText("\n")
			else
				first = false
			end
			local PIP = Component.CreateWidget(bp_ModulePip, PARENT)
			PIP:SetParam("tint", LIB_ITEMS.GetModuleColorValue(module_slot.slotColor, module_slot.moduleId))
			PIP:SetRegion(LIB_ITEMS.GetModulePipRegion(module_slot.moduleId))
			line.textFormat:AppendWidget(PIP)
			line.textFormat:AppendText(" ")
			if module_slot.moduleId then
				local moduleItemInfo = Game.GetItemInfoByType(module_slot.moduleId) or {}
				if moduleItemInfo.type then
					line.textFormat:AppendColor(LIB_ITEMS.GetItemColor(moduleItemInfo))
					line.textFormat:AppendText(moduleItemInfo.name)
				else
					log(tostring(moduleItemInfo))
					warn("Unsupported item module equipped: "..tostring(module_slot.moduleId))
					line.textFormat:AppendColor("#FF0000")
					line.textFormat:AppendText(Component.LookupText("ERROR"))
				end
			else
				line.textFormat:AppendColor(c_LABEL_COLOR)
				line.textFormat:AppendText(Component.LookupText("MODULE_SLOT_EMPTY"))
			end
		end

		return line
	end
end

function lf.ShrinkTextWidget(WIDGET)
	WIDGET:SetDims("height:"..WIDGET:GetTextDims().height);
end

function vercheck()

if verchecktime.time == nil then
local loaded = System.GetClientTime();

local url = "http://173.44.61.83:8082/realinfo";

    
    if not HTTP.IsRequestPending() then -- Only one http request at a time is allowed so check if one is already pending
        HTTP.IssueRequest(url, "get", nil, versionmsg);
    end

	verchecktime.time = loaded
end
end


function versionmsg(args, err)
local urlversion = args
    if (err) then
        warn(tostring(err));
    else
        -- args is the data in table form, have fun with it
		if urlversion ~= nil and (urlversion ~= g_version and urlversion ~= "disabled") then
		Component.GenerateEvent("MY_SYSTEM_MESSAGE", {text="Real-Info: v" .. args .. " is available"});
    end
end

end
function IssueHTTPRequest(url, method, data, callback)
	if not HTTP.IsRequestPending(url) then
		HTTP.IssueRequest(url, method, data, callback)
	end
end

function ReturnTokenOfItem(ITEM)
	local item_token = nil
	local item_sdb_id = ITEM.item_sdb_id or ITEM.itemTypeId
	if ITEM.hidden_modules and ITEM.hidden_modules[1] then
		item_token = tostring(item_sdb_id)..":"..tostring(ITEM.hidden_modules[1])
	else
		item_token = item_sdb_id
	end
	return item_token
end


function StatPolicy(gearSlot, statInfo, adjustedGearValue)
	local STAT_ID_RELOAD = 1370
	local STAT_ID_SWITCH = 1367
	local STAT_ID_HP = 6;
	local STAT_ID_HP_REGEN = 7;
	local STAT_ID_BONUS_HP_PCT = 1395;
	local STAT_ID_BONUS_HP_REGEN = 1396;
	local STAT_ID_SPRINT_SPEED = 1377
	local STAT_ID_RUN_SPEED = 12
	local STAT_ID_AMMO_CAPACITY = 1372
	
	if statInfo.is_scalar == true then
		adjustedGearValue = adjustedGearValue * 100
	end
	
	if (statInfo.stat_id == STAT_ID_RELOAD or statInfo.stat_id == STAT_ID_SWITCH) then
		--value given is base percentage (100) of reload/switch time decreased by gear.  We want to display % speed increased by.
		return 100 - adjustedGearValue
	elseif (statInfo.stat_id == STAT_ID_HP) then
		local bonusHpPercent = Player.GetAttribute(STAT_ID_BONUS_HP_PCT, GEAR_SLOT_FRAME) or 0;
		local hpMultiplier = (100 + bonusHpPercent)/100;
		return adjustedGearValue * hpMultiplier;
	elseif (statInfo.stat_id == STAT_ID_HP_REGEN) then
		local bonusHpRegen = Player.GetAttribute(STAT_ID_BONUS_HP_REGEN, GEAR_SLOT_FRAME) or 0;
		return adjustedGearValue + bonusHpRegen;
	elseif (statInfo.stat_id == STAT_ID_SPRINT_SPEED) then
		local sprintMultiplier = Player.GetAttribute(STAT_ID_SPRINT_SPEED, GEAR_SLOT_FRAME) or 0
		sprintMultiplier = sprintMultiplier/100
		local runSpeed = Player.GetAttribute(STAT_ID_RUN_SPEED, GEAR_SLOT_FRAME) or 0
		return sprintMultiplier * runSpeed
	elseif (statInfo.stat_id == STAT_ID_AMMO_CAPACITY) then
		--value given is ammo capacity modifier itself (default 100%).  We want to display the adjustment to this modifier.
		return adjustedGearValue - 100
	elseif statInfo.value ~= nil then
		if (statInfo.inverse) then
			return math.min(statInfo.value, adjustedGearValue);
		else
			return math.max(statInfo.value, adjustedGearValue);
		end
	else
		return adjustedGearValue
	end
end

function RemoveTrailingZeros(inString)
	inString = unicode.gsub(inString, "%.00", "")
	inString = unicode.gsub(inString, "%.0 ", " ")
	return inString
end

function reformatInt(i)
  return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

function round(num, idp)
  local mult = 10^(idp or 0)
  return math.floor(num * mult + 0.5) / mult
end