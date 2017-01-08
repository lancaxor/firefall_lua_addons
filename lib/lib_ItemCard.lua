
--
-- lib_ItemCard
--   by: James Harless
--

--[[ Usage:
	CARD = ItemCard.Create(PARENT, size)			-- Creates an ItemCard
	CARD:Destroy()									-- Removes the Card

	CARD:GetGroup()									-- returns ItemCard Widget

	CARD:LoadItem([itemid, guid, itemtable])		-- Loads an item and its properties into the card
	CARD:SetCompareItem([itemid, guid, itemtable])	-- Stores the item to compare against into that card
	CARD:LoadMailItem([itemid, guid, itemtable])	-- Flags ItemCard for Mail
	
	CARD:ClearItem()								-- Clears all item data

	CARD:SetQuantity(quantity)						-- Sets quantity
	CARD:HideQuantity(bool)							-- Hides quantity
	
	CARD:HideBackPlate(bool)						-- Hides backplate
	
	CARD:SetRarity(rarity)							-- forces rarity on backplate, text and tooltip border
	
	CARD:IsItemId(item_id)							-- returns false/true depending on item_id supplied
	CARD:GetItemId()								-- returns item_id of currently loaded item
	CARD:GetItemSdbId()								-- returns item_sdb_id of currently loaded item
	CARD:GetName()									-- returns item name
	CARD:GetDescription()							-- returns item desc
	CARD:GetRarity()								-- returns item rarity (salvage, common, uncommon, rare, epic, legendary)
	CARD:GetQuantity()								-- returns item quantity
	CARD:IsResource()								-- returns true if item is a resource
	CARD:IsMailItem()								-- returns true if itemid is from the mail system

	CARD:SetSize(newSize)							-- Sets Card Size ( 16, 32, 48, 64, 96 ) or ( tiny, small, medium, default, large )
	CARD:GetCardSize()								-- returns card size

	CARD:GetIconGroup()								-- returns widget used for drag and drop or shadowing
	CARD:IsIconLoaded()								-- returns false/true depending if the icon is loaded or not

	CARD:SetGridWidth(width [, spacing])			-- Sets the Width of the grid you wish the card to reside in, with optional spacing
	CARD:SetGridSpacing(size)						-- Sets space space between cards
	CARD:DisableGrid()								-- Disables grid mode
	CARD:SetPosition(index, dur, finish)			-- Sets card position and movement into position
	CARD:SlideIntoPosition(index, dur, finish)		-- Sets card position and forces a slide effect if it were moving offscreen to onscreen
	CARD:Refresh()									-- Refreshes the card's grid position

	CARD:GetToolTipInfo()							-- returns a copy of itemInfo
	CARD:SetTag(value)								-- Sets a tag for the card
	CARD:GetTag()									-- returns the tag
	CARD:EnableTooltip(bool)						-- Enables tooltips on mouseover
	CARD:DisableTooltip(bool)						-- Disabled tooltips
	CARD:HideTooltip()								-- Hide the active tooltip
	CARD:DisplayTooltipQuantity(bool)				-- Should the tooltip show the quantity
	
	CARD:SetDragDropAcceptTypes(typesString)		-- Sets the type of drag/drop events (such as "item_sdb_id") that the card will accept
	CARD:GetDropInfo()								-- Returns the details of an accepted drop
	
	CARD:EnableDropTarget(bool)						-- Enables or disables drop target widget (for mouse up)

	CARD:Enable()									-- Turns the card on, making it fully lit and reactive to mouse activity
	CARD:Disable()									-- Dims the card and makes it inactive to mouse activity
	CARD:IsEnabled()								-- returns false/true depending on enabled state
	
	
	CARD is also an EventDispatcher (see lib_EventDispatcher) which dispatches the following events:
		"OnMouseEnter",
		"OnMouseLeave",
		"OnMouseDown",
		"OnMouseUp",
		"OnRightMouse",
		"OnIconLoaded",
		"OnDragDrop",

--]]

ItemCard = {}

require "unicode"
require "lib/lib_Callback2"
require "lib/lib_Items"
require "lib/lib_Table"
require "lib/lib_MultiArt"
require "lib/lib_Colors"
require "lib/lib_Shader"
require "lib/lib_Tooltip"
require "lib/lib_SubTypeIds"
require "lib/lib_EventDispatcher"

local API = {}
local lf = {}
local ITEMCARD_METATABLE = {
	__index = function(t,key) return API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ITEM"); end
};

local c_WebAssetHost
local FALLBACK_RARITY = "unknown_rarity"

local c_CardRarityValues = {
	["unknown_rarity"]	= -1,
	["salvage"]			= 0,
	["common"]			= 1,
	["uncommon"]		= 2,
	["rare"]			= 3,
	["epic"]			= 4,
	["legendary"]		= 5,
}

local c_CardRarityColors = {
	["unknown_rarity"]	= Component.LookupColor("unknown_rarity"),
	["salvage"]			= Component.LookupColor("salvage"),
	["common"]			= Component.LookupColor("common"),
	["uncommon"]		= Component.LookupColor("uncommon"),
	["rare"]			= Component.LookupColor("rare"),
	["epic"]			= Component.LookupColor("epic"),
	["legendary"]		= Component.LookupColor("legendary"),
}

local c_CardFosterWidth = 300
local c_CardIconUrl = "%s/assets/items/%s/%s.png"
local c_CardDims = "width:_; height:_; top:%s; left:%s"
local c_CardDefaultIcon = 231706
local c_CardSpacing = 3
local c_CardSaturationDisabled = 0.3
local c_CardSizes = {
	["tiny"]		= 16,
	["small"]		= 32,
	["medium"]		= 48,
	["default"]		= 64,
	["large"]		= 96,
	["dock:fill"]	= 64,
	["fill"]		= 96,
}


local c_Animation_Frames = 24	-- Total number of regions to use, make sure they're numbered as such ( 01, 05, 15, or 001, 050, 100 or 0001, 0050, 0100, 1000 )
local c_Speed_Mod = 0.8			-- Speed mod, currently set to 1.5 seconds

local c_comparedItem

local cb_ShowToolTip = Callback2.Create()

local BP_ITEMCARD = [[
	<Group dimensions="center-x:50%; center-y:50%; height:64; width:64">
		<Group name="tt_foster" dimensions="left:0; top:0; height:100%; width:]]..c_CardFosterWidth..[[" style="visible:false"/>
		<Group name="attractHookBack" dimensions="dock:fill" />
		<Group name="hidden_group" dimensions="dock:fill"/>
		<StillArt name="backplate" dimensions="dock:fill" style="texture:ItemPlate; region:Square"/>
		
		<Group name="icon" dimensions="dock:fill" />	<!-- MultiArt -->
		<Text name="quantity" dimensions="left:4; bottom:100%-4; width:100%; height:18" style="font:UbuntuRegular_10; drop-shadow:true; valign:bottom; wrap:false; clip:false; visible:false" />
		<Group name="flags" dimensions="dock:fill">
			<StillArt name="unlim_icon" dimensions="height:26.5%; width:51.5%; right:100%-2; bottom:100%-2" style="texture:FeatherIcon; alpha:1; visible:false"/>
		</Group>
		<Group name="attractHookFront" dimensions="dock:fill" />
		<DropTarget name="drop_target" dimensions="dock:fill">
			<FocusBox name="focus" dimensions="dock:fill"/>
		</DropTarget>
	</Group>]]

local BP_BROKEN = [[<StillArt dimensions="dock:fill" style="texture:icons; region:broken_gear; tint:#DD0000; exposure:0.1; alpha:0.6; visible:false"/>]]	
	
local BP_FLIPBOOK = [[<FlipBook style="texture:technique_awaken; eatsmice:false; exposure:1.0" dimensions="dock:fill" frameWidth="84" fps="30"/>]]

ItemCard.Sound_OnDrag = "Play_UI_Login_Back"
ItemCard.Sound_OnDrop = "Play_UI_Login_Back"

function ItemCard.Create(PARENT, size)
	local GROUP = Component.CreateWidget(BP_ITEMCARD, PARENT)
	local CARD = {
		PARENT = PARENT,
		GROUP = GROUP,
		BACKPLATE = GROUP:GetChild("backplate"),
		ICON = MultiArt.Create(GROUP:GetChild("icon")),
		QUANTITY_TEXT = GROUP:GetChild("quantity"),
		FOCUS = GROUP:GetChild("drop_target.focus"),
		HIDDEN_GROUP = GROUP:GetChild("hidden_group"),
		DROP_TARGET = GROUP:GetChild("drop_target"),
		FOSTER = GROUP:GetChild("tt_foster"),
		FLAGS = GROUP:GetChild("flags"),
		UNLIM_ICON = GROUP:GetChild("flags.unlim_icon"),
		AHB = GROUP:GetChild("attractHookBack"),
		AHF = GROUP:GetChild("attractHookFront"),
		ATTRACT_DATA = {},
		BROKEN = false,
		ISNEW = false,

		TOOLTIP = false,

		-- Variables
		size = 64,

		-- Grid Sorting
		grid = {
			enabled = false,
			position = 0,
			width = 0,
			spacing = c_CardSpacing,
			max_per_row = 0,	-- Derived from width / card size
		},

		-- Item Information
		item_id = -1,
		name = "Empty Card",
		description = "",
		rarity = "common",
		rarity_value = -1,
		quantity = 0,
		item_sdb_id = -1,
		flags = {},
		resource_type = false,
		web_icon_id = c_CardDefaultIcon,
		icon_assetId = -1,
		itemInfo = {},
		showTooltip = true,
		showTooltipQuantity = false,
		is_enabled = true,
		is_ability_item = false,
		force_large_icon = false,
		is_mail_item = false,	-- mail items are stored in another inventory
		tag = false,			-- tag for determining the difference of this card from the others
		icon_loaded = false,
		hide_quantity = false,
		hide_backplate = false,
		show_flags = {
			is_broken = true,
			is_new = true,
		},
	}
	CARD.DISPATCHER = EventDispatcher.Create(CARD)
	CARD.DISPATCHER:Delegate(CARD)

	CARD.FOCUS:BindEvent("OnMouseEnter", function(args)
		lf.OnButtonMouseEnter(CARD, args)

		cb_ShowToolTip:Bind(function() 
			lf.ShowTooltip(CARD)
		end)
		cb_ShowToolTip:Schedule(0.1)
	end)
	CARD.FOCUS:BindEvent("OnMouseLeave", function(args)
		cb_ShowToolTip:Cancel()
		lf.OnButtonMouseLeave(CARD, args)
		lf.RemoveTooltip(CARD)
	end)
	CARD.FOCUS:BindEvent("OnMouseDown", function(args)
		lf.OnButtonMouseDown(CARD, args)
	end)
	CARD.FOCUS:BindEvent("OnMouseUp", function(args)
		lf.OnButtonMouseUp(CARD, args)
	end)
	CARD.FOCUS:BindEvent("OnRightMouse", function(args)
		lf.OnRightMouse(CARD, args)
	end)
	CARD.DROP_TARGET:BindEvent("OnDragDrop", function(args)
		lf.OnDragDrop(CARD, args)
	end)
	CARD.DROP_TARGET:BindEvent("OnDragLeave", function(args)
		lf.OnDragLeave(CARD, args)
	end)
	CARD.DROP_TARGET:BindEvent("OnDragEnter", function(args)
		lf.OnDragEnter(CARD, args)
	end)

	setmetatable(CARD, ITEMCARD_METATABLE)

	if size then
		CARD:SetSize(size)
	end
	return CARD
end

function ItemCard.PlaySound_OnDrag()
	lf.PlaySound(ItemCard.Sound_OnDrag)
end

function ItemCard.PlaySound_OnDrop()
	--lf.PlaySound(ItemCard.Sound_OnDrop)
end

------ --
-- API --
------ --
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide", "IsVisible", "GetBounds"
}
for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(API, ...)
		return API.GROUP[method_name](API.GROUP, ...)
	end
end

-- forward the following methods to the FOCUS widget
local FOCUS_METHODS = {"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus", "SetTag", "GetTag"}
for _, method_name in pairs(FOCUS_METHODS) do
	API[method_name] = function(API, ...)
		return API.FOCUS[method_name](API.FOCUS, ...);
	end
end

function API.Destroy(CARD)
	lf.RemoveTooltip(CARD)
	if CARD.ISNEW then
		Component.RemoveWidget(CARD.ISNEW)
	end
	if CARD.BROKEN then
		Component.RemoveWidget(CARD.BROKEN)
	end

	CARD.ICON:Destroy()
	CARD.DISPATCHER:Destroy()
	Component.RemoveWidget(CARD.GROUP)

	CARD = nil
end

function API.GetGroup(CARD)
	return CARD.GROUP
end

-- Mail items
function API.LoadMailItem(CARD, item)
	CARD.is_mail_item = true
	return lf.LoadItem(CARD, item)
end

function API.LoadItem(CARD, item, tag)
	CARD:SetTag(tag)
	return lf.LoadItem(CARD, item)
end

function API.SetCompareItem(CARD, item)
	c_comparedItem = _table.copy(item)
end

function API.ClearItem(CARD)
	lf.ClearItem(CARD)
end

function API.GetItemId(CARD)
	return CARD.item_id
end

function API.GetItemSdbId(CARD)
	return CARD.item_sdb_id
end

function API.GetName(CARD)
	return CARD.name
end

function API.GetDescription(CARD)
	return CARD.description
end

function API.GetRarity(CARD)
	return CARD.rarity
end

function API.GetQuantity(CARD)
	return CARD.quantity
end

function API.IsResource(CARD)
	return (CARD.resource_type ~= nil)
end

function API.IsMailItem(CARD)
	return CARD.is_mail_item
end

function API.IsIconLoaded(CARD)
	return CARD.icon_loaded
end

function API.IsItemId(CARD, item_id)
	return isequal(CARD.item_id, item_id)
end

function API.SetQuantity(CARD, quantity)
	lf.SetQuantity(CARD, quantity)
end

function API.SetRarity(CARD, rarity)
	lf.SetRarity(CARD, rarity)
end

function API.HideQuantity(CARD, state)
	if state ~= CARD.hide_quantity then
		CARD.hide_quantity = state
		CARD.QUANTITY_TEXT:Hide(state)
	end
end

function API.HideBackPlate(CARD, bool)
	CARD.hide_backplate = bool
	CARD.BACKPLATE:Hide(bool)
	lf.ResizeIcon(CARD)
end

function API.FadeCard(CARD, bool, dur)
	dur = dur or 0
	local ICON = CARD.ICON[unicode.upper(tostring(CARD.ICON.type))]
	if bool then
		Shader.SetShaderGrayscale(ICON)
		Shader.SetShaderGrayscale(CARD.BACKPLATE)
		CARD.BACKPLATE:ParamTo("alpha", 0.3, dur)
		CARD.GROUP:ParamTo("alpha", 0.3, dur)
		CARD.ICON:ParamTo("tint", "#444444", dur)
	else
		Shader.SetShaderNormal(CARD.BACKPLATE)
		Shader.SetShaderNormal(ICON)
		CARD.BACKPLATE:ParamTo("alpha", 1, dur)
		CARD.GROUP:ParamTo("alpha", 1, dur)
		CARD.ICON:ParamTo("tint", "#FFFFFF", dur)
	end
end

function API.ForceLargeIcon(CARD, bool)
	CARD.force_large_icon = bool or false
	if CARD:HaveItemInfo() then
		lf.SetIcon(CARD)
	end
end

function API.SetSize(CARD, newSize)
	--if not lf.IsValidSize(newSize) then
	--	return nil
	--end
	if CARD.size ~= newSize then
		CARD.size = newSize
		
		local dims = lf.GetCardDims(CARD)
		CARD.GROUP:SetDims("center-x:_; center-y:_; height:"..dims.."; width:"..dims)
		
		lf.SetIcon(CARD)
		lf.SetRarity(CARD)
	end
end

function API.SetGridWidth(CARD, width, spacing)
	CARD.grid.enabled = true
	CARD.grid.width = width
	if spacing then
		CARD:SetGridSpacing(spacing)
	end
	CARD.grid.max_per_row =  math.floor(width / (lf.GetCardDims(CARD) + CARD.grid.spacing))
end

function API.SetGridSpacing(CARD, size)
	CARD.grid.spacing = size
end

function API.DisableGrid(CARD)
	CARD.grid = {
		enabled = false,
		position = 0,
		width = 0,
		spacing = c_CardSpacing,
		max_per_row = 0,
	}
	CARD:SetDims("left:0; top:0")
end

function API.SetPosition(CARD, index, dur, finish)
	if CARD.grid.enabled then
		CARD.grid.position = index
		local dims = lf.GetCardPositionDims(CARD, index)
		local position_dims = unicode.format(c_CardDims, dims.top, dims.left)
		if not dur then
			CARD.GROUP:SetDims(position_dims)
		else
			CARD.GROUP:MoveTo(position_dims, dur, finish or "ease-out")
		end
	end
end

function API.SlideIntoPosition(CARD, index, dur, finish)
	if CARD.grid.enabled then
		CARD.grid.position = index
		local dims = lf.GetCardPositionDims(CARD, index)
		CARD.GROUP:SetDims(unicode.format(c_CardDims, dims.top, dims.left_init))
		CARD.GROUP:MoveTo(unicode.format(c_CardDims, dims.top, dims.left), dur, finish or "ease-out")
	end
end

function API.Refresh(CARD)
	-- Used after standard changes
	if CARD.grid.enabled then
		CARD:SetPosition(CARD.grid.position)
	end
end

function API.GetToolTipInfo(CARD)
	return _table.copy(CARD.itemInfo)
end

function API.GetCardSize(CARD)
	return lf.GetCardDims(CARD)
end

function API.SetTag(CARD, tag)
	if tag ~= nil and type(tag) ~= "table" then
		CARD.tag = tag
	end
end

function API.GetTag(CARD)
	return CARD.tag
end

function API.EnableTooltip(CARD, ...)
    local nArgs = select('#', ...)
    local arg = {...}
	CARD.showTooltip = arg[1] or nArgs == 0
	
	if not CARD.showTooltip then
		lf.RemoveTooltip(CARD)
	end
end

function API.DisableTooltip(CARD, ...)
    local nArgs = select('#', ...)
    local arg = {...}
	CARD:EnableTooltip(not (arg[1] or nArgs == 0))
end

function API.DisplayTooltipQuantity(CARD, show)
	if show then
		CARD.showTooltipQuantity = true
	else
		CARD.showTooltipQuantity = false
	end
end

function API.SetDragDropAcceptTypes(CARD, types)
	CARD.DROP_TARGET:SetAcceptTypes(types)
end

function API.GetDropInfo(CARD)
	return CARD.DROP_TARGET:GetDropInfo();
end

function API.EnableDropTarget(CARD, bool)
	CARD.DROP_TARGET:Show(bool)
end

function API.Enable(CARD)
	lf.SetEnabled(CARD, true)
	lf.RefreshCardColoration(CARD)
end

function API.Disable(CARD)
	lf.SetEnabled(CARD, false)
	lf.RefreshCardColoration(CARD)
end

function API.IsEnabled(CARD)
	return CARD.is_enabled
end

function API.GetIconGroup(CARD)
	return CARD.ICON:GetGroup()
end

function API.ShowTooltip(CARD)
	return lf.ShowTooltip(CARD)
end

function API.HideTooltip(CARD)
	return lf.RemoveTooltip(CARD)
end

function API.HaveItemInfo(CARD)
	return type(CARD.itemInfo) == "table" and CARD.itemInfo.type ~= nil
end

-------------- --
-- MOUSE FOCUS --
-------------- --
function lf.OnButtonMouseEnter(CARD, args)
	CARD.ICON:ParamTo("exposure", 0.3, 0.3)
	CARD:DispatchEvent("OnMouseEnter", args)
end

function lf.OnButtonMouseLeave(CARD, args)
	CARD.ICON:ParamTo("exposure", 0, 0.3)
	CARD:DispatchEvent("OnMouseLeave", args)
end

function lf.OnButtonMouseDown(CARD, args)
	CARD:DispatchEvent("OnMouseDown", args)
end

function lf.OnButtonMouseUp(CARD, args)
	CARD:DispatchEvent("OnMouseUp", args)
end

function lf.OnRightMouse(CARD, args)
	CARD:DispatchEvent("OnRightMouse", args)
end

function lf.OnDragDrop(CARD, args)
	CARD:DispatchEvent("OnDragDrop", args)
end

function lf.OnDragLeave(CARD, args)
	CARD:DispatchEvent("OnDragLeave", args)
end

function lf.OnDragEnter(CARD, args)
	CARD:DispatchEvent("OnDragEnter", args)
end

------------------ --
-- LOCAL FUNCTIONS --
------------------ --
function lf.SetEnabled(CARD, is_enabled)
	CARD.is_enabled = is_enabled
	CARD.FOCUS:Show(is_enabled)
end

function lf.SetQuantity(CARD, quantity)
	if type(quantity) == "number" then
		CARD.quantity = quantity
		local abbr_quantity = _math.MakeReadable(CARD.quantity, true)

		local is_visible = (CARD.quantity > 1 and not CARD.hide_quantity)
		CARD.QUANTITY_TEXT:SetText(abbr_quantity)
		CARD.QUANTITY_TEXT:Show(is_visible)
	end
end

function lf.SetIcon(CARD)
	CARD.ICON:Reset()
	local ability_icon
	if CARD.is_ability_item and CARD.itemInfo.abilityId then
		local abilityinfo = Player.GetAbilityInfo(tonumber(CARD.itemInfo.abilityId))
		if abilityinfo then
			ability_icon = abilityinfo.iconId
			if not ability_icon then
				warn("ItemCard - Ability: "..tostring(CARD.itemInfo.abilityId).." does not have a valid icon id.")
			end
		else
			warn("ItemCard - Ability: " .. tostring(CARD.itemInfo.abilityId) .. " has no ability information!")
		end
	end
	if ability_icon then
		CARD.icon_assetId = ability_icon
		CARD.ICON:SetIcon(CARD.icon_assetId)
		CARD.icon_loaded = true
		CARD:DispatchEvent("OnIconLoaded", {web=false})
	else
		if not CARD.web_icon_id or CARD.web_icon_id == 0 then
			CARD.web_icon_id = c_CardDefaultIcon
			warn("Item: "..CARD.name.." ["..CARD.item_sdb_id.."] has no Icon Art!")
		end
		CARD.ICON:SetIcon(CARD.web_icon_id)
	end
	lf.ResizeIcon(CARD)
end

function lf.ResizeIcon(CARD)
	if CARD.hide_backplate then
		CARD.ICON:SetDims("dock:fill")
	else
		if CARD.is_ability_item then
			CARD.ICON:SetDims("center-x:50%; top:11%; bottom:89%; width:78t")
		else
			CARD.ICON:SetDims("center-x:50%; top:10%; bottom:95%; width:85t")
		end
	end
end

function lf.SetRarity(CARD)
	if (not c_CardRarityValues[CARD.rarity]) then
		warn("lib_ItemCard does not know what to do with rarity "..tostring(CARD.rarity)..", treating as "..FALLBACK_RARITY)
		CARD.rarity = FALLBACK_RARITY
	end
	CARD.rarity_value = c_CardRarityValues[CARD.rarity]
	lf.RefreshCardColoration(CARD)
end

function lf.RefreshCardColoration(CARD)
	local saturation = 1
	if not CARD.is_enabled then
		saturation = c_CardSaturationDisabled
	end
	
	local newHSV = Colors.toHSV(c_CardRarityColors[CARD.rarity])
	newHSV.s = newHSV.s * saturation
	
	local newColor = Colors.Create(newHSV)
	CARD.BACKPLATE:SetParam("tint", newColor)
	CARD.QUANTITY_TEXT:SetTextColor(newColor)
	CARD.ICON:SetParam("saturation", saturation)
end

function lf.GetWebAssetHost()
	if not c_WebAssetHost then
		c_WebAssetHost = System.GetOperatorSetting("web_asset_host")
	end
	return c_WebAssetHost
end

function lf.IsValidSize(region_size)
	if c_CardSizes[region_size] then
		return true
	end
	warn("Card Size "..region_size.." is not valid!")
	return false
end

function lf.GetCardDims(CARD)
	if type(CARD.size) == "string" then
		if CARD.size == "dock:fill" or CARD.size == "fill" then
			return CARD.PARENT:GetBounds().height
		else
			return c_CardSizes[CARD.size]
		end
	end
	return CARD.size
end

function lf.GetCardPositionDims(CARD, position)
	local index = position - 1
	local inc = math.floor(index / CARD.grid.max_per_row)
	local delta = (index % CARD.grid.max_per_row)

	local _size = lf.GetCardDims(CARD)
	local _t = ( inc * _size ) + ( inc * CARD.grid.spacing )
	local _l = ( delta * _size ) + ( delta * CARD.grid.spacing )
	local _linit = ( -1 * _size ) + ( -1 * CARD.grid.spacing )

	return {top=_t, left=_l, left_init=_linit}
end


function lf.LoadItem(CARD, item)
	if not item then
		warn("No Item Data.")
		return nil
	end
	local item_id
	local item_sdb_id
	local itemInfo
	local quantity = 1
	local resource_type = false
	local attribute_modifiers = {}

	if type(item) == "table" then
		--Hacky McHack asks if we can get all of our code to use the same var names for ids
		item_id = item.itemId or item.item_id or item.item_guid
		item_sdb_id = item.item_sdb_id or item.itemTypeId or item.itemSdbId
		-- Display all the information
		if item.type then
			itemInfo = item
			quantity = item.quantity
		elseif item_id then
			quantity = item.quantity
			if( CARD.is_mail_item == true ) then
				itemInfo = Mail.GetItemInfo(item_id)
			else
				itemInfo = Player.GetItemInfo(item_id)
			end

			-- There's an item being displayed that doesn't exist in their inventory (mail received?)
			if not itemInfo then
				quantity = item.quantity
				itemInfo = Game.GetItemInfoByType(item_sdb_id)
				--if( item.rarity ) then
				--	itemInfo.rarity = item.rarity
				--end
			else
				--itemInfo.rarity = item.rarity

				if( itemInfo.durability and (type(itemInfo.durability) ~= "table")) then
					itemInfo.durability = { current = itemInfo.durability.current }
					if( itemInfo.repair_pool and itemInfo.repair_pool ~= nil ) then
						itemInfo.stats.repairPoints = itemInfo.repair_pool
					end
				elseif( type(itemInfo.durability) == "table" ) then
					if not itemInfo.stats then
						itemInfo.stats = {}
					end
					itemInfo.stats.repairPoints = itemInfo.durability.pool
				end

			end
		else
			quantity = item.quantity

			itemInfo = Game.GetItemInfoByType(item_sdb_id)
			if not itemInfo then
				warn("No Item Data for: "..tostring(item_sdb_id))
				return nil
			end

			if item.resource_type and unicode.len(item.resource_type) > 0 then
				-- get resource stats for tooltip
				local stat_vals = LIB_ITEMS.GetResourceStats(item.resource_type)
				local resource_stats = Game.GetResourceTypeInfo(itemInfo.subTypeId).resource_stats

				local resource_stat_index = 1
				for i=1,5 do
					local stat_val = stat_vals["stat"..tostring(i)]
					local res_stat = resource_stats[resource_stat_index]
					if res_stat and stat_val ~= 0 then
						itemInfo.stats[res_stat] = stat_val
						resource_stat_index = resource_stat_index + 1
					end
				end
			end
		end
	else
		-- Only show the item, no need to show quantity unless the component requests it
		itemInfo = Player and Player.GetItemInfo(item)
		if not itemInfo then
			if Game then
				itemInfo = Game.GetItemInfoByType(item)
			elseif System then
				itemInfo = System.GetItemInfo(item)
			end

			item_sdb_id = item
		else
			item_id = item
			item_sdb_id = itemInfo.itemTypeId or itemInfo.item_sdb_id
		end
	end
	if not itemInfo then
		warn("No Item Data for: "..tostring(item_id))
		return nil
	end

	CARD.item_id = item_id or false
	CARD.item_sdb_id = item_sdb_id or false
	CARD.name = itemInfo.name or ""
	CARD.description = itemInfo.description or ""
	CARD.rarity = itemInfo.rarity or FALLBACK_RARITY
	CARD.rarity_value = -1
	CARD.is_ability_item = (itemInfo.type == "ability_module")
	CARD.web_icon_id = itemInfo.web_icon_id or c_CardDefaultIcon
	CARD.icon_assetId = -1
	CARD.resource_type = resource_type
	CARD.icon_loaded = false
	CARD.itemInfo = itemInfo
	CARD.flags = itemInfo.flags or {}
	
	--PREVENT MEDICAL SYSTEM AND AUX WEAPON ABILITIES FROM BEING SET TO CIRCLE
	if CARD.is_ability_item and itemInfo.moduleType ~= "Medical System" and itemInfo.moduleType ~= "Auxiliary Weapon" then
		CARD.BACKPLATE:SetRegion("Circle")
	else
		CARD.BACKPLATE:SetRegion("Square")
	end
	
	if CARD.flags.is_broken and not CARD.BROKEN then
		CARD.BROKEN = Component.CreateWidget(BP_BROKEN,  CARD.FLAGS)
		CARD.BROKEN:SetDims("left:7%; top:14%; height:30%; width:30%;")
		CARD.BROKEN:Show()
	elseif CARD.BROKEN then
		CARD.BROKEN:Show(CARD.flags.is_broken)
	end

	if CARD.flags.is_new then
		if not CARD.ISNEW then
			CARD.ISNEW = Component.CreateWidget(BP_FLIPBOOK, CARD.FLAGS)
			CARD.ISNEW:SetDims("center-x:50%; center-y:50%; height:100%; width:100%")
		end
		CARD.ISNEW:Show()
		CARD.ISNEW:Play(.8)
	elseif CARD.ISNEW then
		Component.RemoveWidget(CARD.ISNEW)
		CARD.ISNEW = false
	end

	if CARD.item_sdb_id then
		CARD.UNLIM_ICON:Show((CARD.flags.is_unlimited or CARD.flags.unlimited) and not(Game and Game.IsItemOfType(CARD.item_sdb_id, SubTypeIds.Currency)))
	end
	
	lf.SetIcon(CARD)
	lf.SetRarity(CARD)
	lf.SetQuantity(CARD, quantity or 1)
end

function lf.ClearItem(CARD)
	-- Item Information
	CARD.item_id = -1
	CARD.name = "New Card"
	CARD.description = ""
	CARD.rarity = "common"
	CARD.rarity_value = -1
	CARD.quantity = 0
	CARD.item_sdb_id = -1
	CARD.flags = {}
	CARD.resource_type = false
	CARD.web_icon_id = c_CardDefaultIcon
	CARD.icon_assetId = -1
	CARD.itemInfo = {}
	CARD.is_mail_item = false	-- mail items are stored in another inventory
	CARD.is_ability_item = false
	CARD.force_large_icon = false
	CARD.icon_loaded = false
	CARD.show_flags = {
		is_broken = true,
		is_new = true,
	}
	if CARD.ISNEW then
		Component.RemoveWidget(CARD.ISNEW)
		CARD.ISNEW = false
	end
	
	CARD.ICON:Reset()
	CARD.UNLIM_ICON:Hide()
	lf.SetRarity(CARD)
	lf.SetQuantity(CARD, CARD.quantity)
	lf.RefreshCardColoration(CARD)

	CARD.BACKPLATE:SetRegion("Square")
end

function lf.OnWebIconResponse(CARD, success, url)
	if success then
		CARD.icon_loaded = true
		CARD:DispatchEvent("OnIconLoaded", {web=true})
	end
end

-- Sound FX
function lf.PlaySound(sound_key)
	System.PlaySound(sound_key)
end

-- Tooltips
function lf.RequestTooltip(CARD)
	CARD.TOOLTIP = LIB_ITEMS.CreateToolTip(CARD.FOSTER)
	return CARD.TOOLTIP
end

function lf.RemoveTooltip(CARD)
	if CARD.TOOLTIP then
		CARD.TOOLTIP:Destroy()
		Tooltip.Show(false)

		CARD.TOOLTIP = false
	end
end

function lf.ShowTooltip(CARD)
	if CARD:HaveItemInfo() and CARD.showTooltip == true then
		local tt_info = CARD:GetToolTipInfo()
		if CARD.showTooltipQuantity then
			tt_info.quantity = CARD:GetQuantity()
		end
		local TOOLTIP = lf.RequestTooltip(CARD)
		local compare_info = c_comparedItem or LIB_ITEMS.GetMatchingEquippedItemInfo(tt_info)
		TOOLTIP:DisplayInfo(tt_info)
		if compare_info and not (isequal(tt_info.itemTypeId, compare_info.itemTypeId) and isequal(tt_info.itemId, compare_info.itemId)) then
			TOOLTIP:CompareAgainst(compare_info)
		end
		TOOLTIP:DisplayPaperdoll(true)
		local tt_bounds = TOOLTIP:GetBounds()
		Tooltip.Show(CARD.TOOLTIP:GetWidget(), {width=tt_bounds.width, height=tt_bounds.height, frame_color=c_CardRarityColors[CARD.rarity], alpha=0.3})
	end
end
