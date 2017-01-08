
--
-- Wallet - provides an interface to finding out how much money you have, and spending it
--   by: John Su
--

--[[

Usage:
	Wallet.Refresh([cb_function])	-- refreshes funds (asynchronous); calls [cb_function] when done if defined
	Wallet.GetFunds()				-- returns a table of available funds (cached from Refresh)
	Wallet.PromptCurrencySpend(currencies, prompt_text, cb_function)
									-- [currency] = a table of currencies using this format: {type=string or number, cost=number}
									-- [prompt_text] = The item this purchase will buy. For example, buying a frame would display its name.
									-- calls [cb_function](response) when the player takes action, with response being true/false for Y/N
	Wallet.Subscribe(...)			-- attempts to keep an updated cache on the funds listed.
											Valid currencies are: "crystite", "credits", "redbeans", "pilot_tokens"
	Wallet.DisplayBalance(...)		-- shows the balance(s) of current available funds.
	Wallet.Foster( parent_widget )	-- fosters wallet to parent widget

	Wallet is also an EventDispatcher, dispatching the following events:
		"OnUpdate"	-- triggers when funds have been updated

	Wallet.Create(parent, [param_table]) 		-- Creates and returns a WALLET object. 
					param_table = {		 		-- Use the API below on the returned object to display currencies.
						parent = WIDGET 	-- The parent to create the object to.
						currencies = table	-- What currencies to display, it will use Wallet.DEFAULT_CURRENCIES to create the wallet when nothing is specified.
						style = string		-- align can either be vertical or horizontal, by default it is horizontal.
						show_tooltip = bool	-- If show_tooltip is true it will display a list of all currencies whenever you mouse over the Currency object.
					}						-- by default it will not be shown.

	WALLET:SetCurrencies(table)				-- SetCurrencies is used to change the default currencies and/or the order of them.
					table = {
						string,			-- You can supply strings, (If you supply a string it needs to be present in the default currencies table.)
						number,			-- or you can supply item_sdb_ids.
						{name=string, icon={...}, [value=number, updateFunc=func]} -- You can also supply custom values which require a string, an icon table which contains a texture and/or region or just a url,
					}															   -- and finally an optional updateFunc which it can call to get an updated value for your entry.

	WALLET:SetDisabledCurrencies(table)		-- Lets you 'disable' currencies by making them transparent to draw attention to other currencies in your list.
											-- table = {		-- Format essentially follows the above table for :SetCurrencies, but for custom currencies you must send the name of your custom currency to match against.
												string,			-- :SetDisabledCurrencies will search for the currencies you provide and if it finds them, it will make them transparent.
												number,
												...
											}

	WALLET:EnableTooltip(bool)				-- If true, the tooltip of all currencies will be shown, otherwise if false it will not be shown.

	WALLET:AddCurrencyToList(currency)		-- [currency] = a string, number, or table. If it is a string, it needs to be present in REGION_MAPPING to be recognized.
											-- If it is a number, it needs to be an item sdb id from which information can be pulled from.
											-- If it is a table, it must follow this format: {name=string, icon={...}, [value=number, updateFunc=func]}

	WALLET:CalculateCurrencyWidth()			-- This will refresh the size of all currencies and at the same time return to you the length of the list.

	WALLET:Refresh()						-- This will force all of the currencies to update their values.

	WALLET:ClearCurrencies()				-- This will wipe all of the currencies in the list.

	WALLET:SetCompact(bool)					-- If true, all values will be compacted. e.g. 100,000 to 100k.

	WALLET:Destroy()						-- Destroys the WALLET object and cleans up created widgets.
--]]

-- public API
Wallet = {};


require "lib/lib_Liaison";
require "lib/lib_Tooltip"
require "lib/lib_Items"
require "lib/lib_math"
require "lib/lib_EventDispatcher";

local g_DISPATCHER = EventDispatcher.Create(Wallet);

-- some resource id's for convenience
Wallet.CRYSTITE_ID = "10";
Wallet.CREDITS_ID = "30101";
Wallet.PILOT_TOKENS_ID = "78038";
Wallet.RESEARCH_POINTS = "86154";

-- Default currencies to display.
Wallet.DEFAULT_CURRENCIES = {"redbeans", "credits", "crystite"}

-- String lookups for convenience from other components.
local RESOURCE_IDS = {
	["crystite"]		= "10",
	["credits"]			= "30101",
	["firefall_cash"]	= "143099",
	["pilot_tokens"]	= "78038",
	["research_points"] = "86154",
}

-- Static lookups for commonly-used currencies.
local REGION_MAPPING = {
	["crystite"]		= "crystite_16",
	["credits"]			= "credits_16",
	["redbeans"]		= "redbean_16",
	["pilot_tokens"]	= "pilot_token_16",
	["research_points"] = "researchpoint_16",
}

-- Static lookups for commonly-used currencies.
local NAME_MAPPING = {
	["crystite"]		= Component.LookupText("CRYSTITE"),
	["credits"]			= Component.LookupText("CREDITS"),
	["redbeans"]		= Component.LookupText("REDBEANS"),
	["pilot_tokens"]	= Component.LookupText("PILOT_TOKENS"),
	["research_points"] = Component.LookupText("RESEARCH_POINTS"),
}


-- Wallet UI API.
local API = {}

local lf = {}

local WALLET_METATABLE = {
	__index = function(t,key) return API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in WALLET"); end
};

-- private locals
local g_LiaisonPath = Liaison.GetPath();
local g_cachedFunds = {};
local p_cbSpendFunction;
local p_cbRefreshFunction;
local d_CreatedWallets = {}
local g_Tooltip = nil
local g_specialTooltip = nil

local c_currencyEntryHeight = 30 
local c_currencyPaddingHeight = 25

local bp_TooltipWidget = 	[[<Group dimensions="dock:fill">
								<Border class="FadedBorder" dimensions="dock:fill" style="eatsmice:false; tint:#000000; alpha:.5; exposure:0"/>
								<Text name="Text" dimensions="dock:fill" style="font:Demi_10; halign:center; valign:center"/>
							  </Group>]]

local bp_WalletItemWidget = [[<Group dimensions="dock:fill">
								<Group name="Icon" dimensions="right:100%; height:16; width:16; center-y:50%;" style="eatsmice:false"/>
								<Text name="Text" dimensions="right:100%-18; height:22; width:0; center-y:50%" style="font:Demi_10; halign:left; valign:center"/>
								<FocusBox name="Focus" dimensions="dock:fill"/>
								<Group name="Tooltip" dimensions="left:0; top:0; height:300; width:300" style="visible:false"/>
							</Group>]]

local bp_WalletOptionalItemWidget = 
							[[<Group dimensions="dock:fill" style="eatsmice:false">
								<Group name="Icon" dimensions="right:100%-15; height:16; width:16; center-y:50%" style="eatsmice:false"/>
								<Text name="Text" dimensions="right:100%-33; height:22; width:0; center-y:50%" style="font:Demi_10; halign:left; valign:center; eatsmice:false"/>
								<FocusBox name="Focus" dimensions="top:0;width:0;left:0;height:0"/>
							</Group>]]
							--<Text name="Test" dimensions="right:100%+18; height:22; width:0; center-y:50%" text="ASDF" style="font:Demi_10; halign:left; valign:center"/>

local bp_WalletListWidget = [[<ListLayout name="List" dimensions="dock:fill" style="horizontal:true; reverse:true; hpadding:0"/>]]

local bp_TooltipItemWidget = 	[[<Group dimensions="dock:fill">
									<Text name="Name" dimensions="left:5; width:0; height:22; top:0" style="halign:left; valign:center; font:Demi_9; color:PanelTitle"/>
									<Mask name="dash_lines" dimensions="left:0; right:100%; height:22; center-y:25%" maskdims="left:75; right:100%-85; height:100%; top:0" style="texture:DashLines; tint:#FFFFFF"/>
									<Text name="Quantity" dimensions="right:100%-25; width:0; height:22; top:0" style="halign:right; valign:center; font:Demi_9; color:#DADADA"/>
								</Group>]]

-- FUNCTIONS

function Wallet.Refresh(cb_function)
	p_cbRefreshFunction = cb_function or p_cbRefreshFunction;
	Component.PostMessage("Wallet:Main", "Refresh", tostring({reply_to=g_LiaisonPath}));
end

function Wallet.GetFunds()
	-- return copy of funds
	local funds = {};
	for k,v in pairs(g_cachedFunds) do
		funds[k] = v;
	end
	return funds;
end

function Wallet.PromptCurrencySpend(currencies, prompt_text, cb_function)
	p_cbSpendFunction = cb_function;
	Component.PostMessage("Wallet:Main", "PromptCurrencySpend", tostring({currencies=currencies, prompt_text=prompt_text, reply_to=g_LiaisonPath}));
end

function Wallet.PromptHide()
	if p_cbSpendFunction then
		Component.PostMessage("Wallet:Main", "HidePrompt", "[]");
	end
end

function Wallet.DisplayBalance(...)
	local types = {};
    local nArgs = select('#', ...)
    local arg = {...}
	if (nArgs > 0) then
		for i=1, nArgs do
			types[i] = arg[i];
		end
	end
	Component.PostMessage("Wallet:Main", "DisplayBalance", tostring(types));
end

function Wallet.Subscribe(...)
	local types = {};
    local nArgs = select('#', ...)
    local arg = {...}
	if (nArgs > 0) then
		for i=1, nArgs do
			types[i] = arg[i];
		end
	else
		types = nil;
	end
	Component.PostMessage("Wallet:Main", "Subscribe", tostring({reply_to=g_LiaisonPath, list=types}));
end

function Wallet.Foster( parent_widget )
	Component.FosterWidget("Wallet:balance", parent_widget );
end

-----------------------------
-----	Wallet UI API	-----
-----------------------------

function Wallet.Create(args)
	assert(args.parent, "You did not provide a valid parent to create the Wallet to.")

	args.currencies = (args.currencies or Wallet.DEFAULT_CURRENCIES)

	local GROUP = Component.CreateWidget(bp_WalletListWidget, args.parent)
	GROUP:SetDims("height:22; top:_")

	local WALLET = {
		GROUP = GROUP,

		-- Our event dispatcher, currently used to send out OnSizeUpdate events.
		DISPATCHER = nil,

		-- All currency widgets currently created.
		CURRENCIES = {},

		-- Total width/height of the currency list. 
		total_size = 0,

		-- The index of our object in d_CreatedWallets
		index = 0,

		-- Our group widget to create our tooltips to.
		tooltip_group = Component.CreateWidget('<Group dimensions="height:300; width:300; center-x:50%; center-y:50%" style="visible:false"/>', args.parent),

		-- To let us know if this is a vertical list.
		is_vertical = (args.style == "vertical"),

		-- Whether or not to show the tooltip.
		show_tooltip = args.show_tooltip,

		-- Whether or not to compact the currencies, false by default.
		do_compact = false
	}

	-- Apply the style of the wallet.
	WALLET.GROUP:SetHorizontal(not(WALLET.is_vertical))

	if args.compact ~= nil then
		WALLET.do_compact = args.compact
	end

	-- Create our dispatcher so we can send out events.
	WALLET.DISPATCHER = EventDispatcher.Create(WALLET);

	-- Apply our metatable so we can perform methods on our new object.
	setmetatable(WALLET, WALLET_METATABLE)

	-- Create the list of currencies.
	for _,CURRENCY in pairs(args.currencies) do
		WALLET:AddCurrencyToList(CURRENCY)
	end

	-- Update the width of the currencies.
	WALLET:CalculateCurrencyWidth()

	-- Add our new wallet to a table for easy updating.
	WALLET.index = lf.GetNewIndex()

	d_CreatedWallets[WALLET.index] = WALLET

	return WALLET
end

------------------------
---  COMMON METHODS  ---
------------------------

-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide", "IsVisible", "GetBounds", "GetLength", "GetContentBounds"
}

for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(API, ...)
		return API.GROUP[method_name](API.GROUP, ...)
	end
end

------------------------
---    WALLET API  	 ---
------------------------

function API.AddCurrencyToList(self, currency, isoptionalcurrency)
	--if currency added isn not a default currency and has no value, then don't add it to the list
	if currency == "firefall_cash" and Player.GetItemCount(RESOURCE_IDS[currency]) <= 0 then
		return
	end

	local GROUP = Component.CreateWidget(isoptionalcurrency and bp_WalletOptionalItemWidget or bp_WalletItemWidget, self.GROUP)

	-- Pull the name from our static lookup, if possible.
	local name = NAME_MAPPING[currency]

	GROUP:SetDims("height:22; width:100%+20;right:100%")
	local index = #self.CURRENCIES+1

	local CURRENCY = {
		GROUP = GROUP,

		TEXT = GROUP:GetChild("Text"),
		ICON = MultiArt.Create(GROUP:GetChild("Icon")),
		FOCUS = GROUP:GetChild("Focus"),
		TOOLTIP = GROUP:GetChild("Tooltip"),

		update_func = nil,	 	-- If our currency has a custom update func, it will go here.

		is_custom = nil,		-- To let us know if this currency is handling its own thing.

		is_optional = isoptionalcurrency,	-- If it should have a dropup list to change what currency it's displaying

		name = nil,

		currency = currency 	-- Our currency information, for easy reference.
	}

	if type(currency) == "number" or type(currency) == "string" then
		if REGION_MAPPING[currency] then 	-- If static texture is found, set the texture based on that.
			CURRENCY.ICON:SetTexture("currency_new", REGION_MAPPING[currency])
		else
			local itemInfo = nil		 	-- If instead we have currency we need to pull a url for, do that instead.

			if RESOURCE_IDS[currency] then 
				currency = RESOURCE_IDS[currency]

				CURRENCY.currency = currency
			end

			itemInfo = Game.GetItemInfoByType(currency)

			-- Somehow we don't have any item information, so return an error.
			assert(itemInfo, "What we had thought was a number did not have any itemInfo tied to it: " .. tostring(currency))

			-- Set the name variable to the proper value, as we have itemInfo.
			name = itemInfo.name

			CURRENCY.ICON:SetIcon(itemInfo.web_icon_id)
		end
	elseif type(currency) == "table" then	-- And finally if this is a custom currency, use its url/texture and/or region and value.
		name = currency.name

		if currency.icon then
			local icon = currency.icon
			if icon.texture then
				CURRENCY.ICON:SetTexture(icon.texture, icon.region)
			end
		end

		CURRENCY.is_custom = true

		CURRENCY.update_func = currency.update_func

		CURRENCY.TEXT:SetText(_math.MakeReadable(tointeger(currency.value)))
	end

	-- If somehow we don't have a name defined by this point, return an error and display what was sent to us.
	assert(name, "There is no name specified for this currency: " .. tostring(currency))

	CURRENCY.name = name

	if currency == RESOURCE_IDS["firefall_cash"] then -- if it's firefall cash
		CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() 
			if g_specialTooltip then g_specialTooltip:Destroy() g_specialTooltip = nil end

			local itemInfo = Game.GetItemInfoByType(currency)
			itemInfo.quantity = Player.GetItemCount(currency)
			itemInfo.item_level = nil
			g_specialTooltip = LIB_ITEMS.CreateToolTip(CURRENCY.TOOLTIP)

			g_specialTooltip:DisplayInfo(itemInfo)
			g_specialTooltip:DisplayPaperdoll(false)

			local tt_bounds = g_specialTooltip:GetBounds()
			Tooltip.Show(g_specialTooltip:GetWidget(), {width=tt_bounds.width, height=tt_bounds.height})
		end)

		CURRENCY.FOCUS:BindEvent("OnMouseLeave", function() 
			if g_specialTooltip then g_specialTooltip:Destroy() g_specialTooltip = nil end
			Tooltip.Show(false)
		end)
	elseif not self.show_tooltip then
		CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() lf.OnPriceEnter(CURRENCY.name, CURRENCY.GROUP) end)
		CURRENCY.FOCUS:BindEvent("OnMouseLeave", lf.OnPriceLeave)
	else
		CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() lf.ShowCurrencyTooltip(self) end)
		CURRENCY.FOCUS:BindEvent("OnMouseLeave", lf.HideCurrencyTooltip)
	end

	table.insert(self.CURRENCIES, CURRENCY)
	
	CURRENCY.ICON:EatMice(false)
end

function API.SetDisabledCurrencies(self, currencies)
	for _,dc in pairs(currencies) do
		for _,CURRENCY in pairs(self.CURRENCIES) do
			local dc_type = type(dc)

			local currency_type = CURRENCY.currency
			if RESOURCE_IDS[currency_type] then currency_type = RESOURCE_IDS[currency_type] end

			if (isequal(CURRENCY.currency, dc) or isequal(currency_type, dc)) or ((dc_type == "table") and isequal(dc.name == CURRENCY.currency.name)) then
				CURRENCY.GROUP:SetParam("alpha", .5)
			end
		end
	end
end

function API.CalculateCurrencyWidth(self)
	for _,CURRENCY in pairs(self.CURRENCIES) do
		local text_dims = CURRENCY.TEXT:GetTextDims().width

		if CURRENCY.is_optional then
			CURRENCY.GROUP:SetDims("width: "..text_dims+45)
			CURRENCY.TEXT:SetDims("width:" .. text_dims .. "; right:100%-43")
			CURRENCY.ICON:SetDims("width:18;right:100%-8")--..(a < 0 and a or "+"..a))
		else
			CURRENCY.GROUP:SetDims("width:" .. text_dims+30 .. "; right:_")
			CURRENCY.TEXT:SetDims("width:" .. text_dims .. "; right:_")
		end
	end

	-- Pull the length of our GROUP widget, this will pull either the full height of width depending on the alignment.
	self.total_size = self.GROUP:GetLength()

	-- Send out a dispatch event to let the component know the size of the list changed.
	self.DISPATCHER:DispatchEvent("OnSizeUpdate")

	-- Return the length just in case a component is asking for it.
	return self.total_size
end

function API.GetSingleCurrencyWidth(self,currencyindex)
	if currencyindex > #self.CURRENCIES then return end
	return self.CURRENCIES[currencyindex].TEXT:GetTextDims().width+30
end

function API.ClearCurrencies(self)
	for idx,CURRENCY in pairs(self.CURRENCIES) do
		Component.RemoveWidget(CURRENCY.GROUP)

		self.CURRENCIES[idx] = nil
	end
end

function API.SetCurrencies(self, args)
	assert(args, "args must not be nil.")

	self:ClearCurrencies()

	local opt = args.optionalcurrencyindex

	for i,CURRENCY in ipairs(args) do
		self:AddCurrencyToList(CURRENCY,i == opt)
	end
end

function API.Refresh(self)
	for _,CURRENCY in pairs(self.CURRENCIES) do
		local currency_amount = nil
		local currency_type = CURRENCY.currency

		-- If we have an id override defined for a string, use the id defined instead of a string.
		if RESOURCE_IDS[currency_type] then
			currency_type = RESOURCE_IDS[currency_type]
		end

		-- If either we have a cached version of this currency or it has an item_sdb_id we can get its value here.
		if not CURRENCY.is_custom and g_cachedFunds[currency_type] then
			currency_amount = g_cachedFunds[currency_type]
		elseif type(currency_type) ~= "table" then
			currency_amount = Player.GetItemCount(currency_type)
		end

		-- If this currency has an update function, run it to get the value.
		if CURRENCY.update_func then
			currency_amount = CURRENCY.update_func()
		end

		-- Set the text of the currency to its gathered value, compact if required.
		if currency_amount then
			CURRENCY.TEXT:SetText(_math.MakeReadable(tointeger(currency_amount), self.do_compact))
		end
	end

	Tooltip.Show(nil)
	if g_Tooltip and Component.IsWidget(g_Tooltip.GROUP) then
		Component.RemoveWidget(g_Tooltip.GROUP)

		g_Tooltip = nil
	end

	self:CalculateCurrencyWidth()
end

function API.SetCompact(self, bool)
	if not bool then bool = false end

	self.do_compact = bool

	self:Refresh()
end

function API.EnableTooltip(self, bool)
	self.show_tooltip = bool

	for _,CURRENCY in pairs(self.CURRENCIES) do
		if CURRENCY.currency == RESOURCE_IDS["firefall_cash"] then -- if it's firefall cash
			CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() 
				if g_specialTooltip then g_specialTooltip:Destroy() g_specialTooltip = nil end

				local itemInfo = Game.GetItemInfoByType(CURRENCY.currency)
				itemInfo.quantity = Player.GetItemCount(CURRENCY.currency)
				itemInfo.item_level = nil
				g_specialTooltip = LIB_ITEMS.CreateToolTip(CURRENCY.TOOLTIP)

				g_specialTooltip:DisplayInfo(itemInfo)
				g_specialTooltip:DisplayPaperdoll(false)

				local tt_bounds = g_specialTooltip:GetBounds()
				Tooltip.Show(g_specialTooltip:GetWidget(), {width=tt_bounds.width, height=tt_bounds.height})
			end)

			CURRENCY.FOCUS:BindEvent("OnMouseLeave", function() 
				if g_specialTooltip then g_specialTooltip:Destroy() g_specialTooltip = nil end
				Tooltip.Show(false)
			end)
		elseif not bool then
			CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() lf.OnPriceEnter(CURRENCY.name, CURRENCY.GROUP) end)
			CURRENCY.FOCUS:BindEvent("OnMouseLeave", lf.OnPriceLeave)
		else
			CURRENCY.FOCUS:BindEvent("OnMouseEnter", function() lf.ShowCurrencyTooltip(self) end)
			CURRENCY.FOCUS:BindEvent("OnMouseLeave", lf.HideCurrencyTooltip)
		end
	end
end

function API.Destroy(self)
	-- Destroy our Wallet group.
	Component.RemoveWidget(self.GROUP)

	-- Remove the Wallet from our table.
	d_CreatedWallets[self.index] = nil

	-- Clear our the Wallet object.
	for idx in pairs(self) do self[idx] = nil end

	-- If somehow our tooltip is still displayed at the time of destruction, force it to hide itself.
	Tooltip.Show(false)
end

-----------------------
--- LOCAL FUNCTIONS  --
-----------------------

function lf.GetAmountOfRows(numberOfItems)
	local _,screenY = Component.GetScreenSize()
	local tooltipHeight = (c_currencyEntryHeight*numberOfItems+c_currencyPaddingHeight)

	if tooltipHeight >= screenY then
		local numberOfColumns = math.ceil(tooltipHeight/screenY)

		return math.ceil(numberOfItems/numberOfColumns)
	end
end

function lf.CreateTooltipColumn(parent)
	local COLUMN = Component.CreateWidget('<ListLayout name="List" dimensions="width:300; height:100; center-x:50%; center-y:50%" style="vpadding:6"/>', parent)
	COLUMN:SetDims("left:0; top:0; height:100%; width:_")

	COLUMN:SetVPadding(6)

	return COLUMN
end

function lf.ShowCurrencyTooltip(self)
	if g_Tooltip and Component.IsWidget(g_Tooltip.GROUP) then Component.RemoveWidget(g_Tooltip.GROUP) end

	g_Tooltip = lf.MakeCurrencyTooltip(self)

	local tt_bounds = g_Tooltip.GROUP:GetBounds()
	Tooltip.Show(g_Tooltip.GROUP, {width=tt_bounds.width, height=tt_bounds.height, frame_color="#DADADA"})
end

function lf.MakeCurrencyTooltip(self)
	local numberOfRows = nil
	local currencyTable = {}
	local sortedTable = {}
	local COLUMNS = {}

	local TOOLTIP = {GROUP=Component.CreateWidget('<ListLayout name="List" dimensions="width:300; height:100; center-x:50%; center-y:50%" style="vpadding:6; hpadding:1"/>', self.tooltip_group)}

	for idx,CURRENCY in pairs(g_cachedFunds) do
		local total = CURRENCY

		-- If the currency is not crystite, credits, or red beans, and has a value greater than one, add it to the list of currencies to create.
		local currencyInfo = Game.GetItemInfoByType(idx)
		if not isequal(idx, Wallet.CRYSTITE_ID) and not isequal(idx, Wallet.CREDITS_ID) and idx ~= "redbeans" and tonumber(total) > 0 and not currencyInfo.flags.hidden then
			table.insert(currencyTable, idx)
		end
	end

	-- Create our static currencies last.
	local staticCurrencies = {"credits", "crystite", "redbeans"}

	for _,CURRENCY in pairs(staticCurrencies) do
		table.insert(currencyTable, CURRENCY)
	end

	-- Grab our number of rows per column if we need to split into rows.
	numberOfRows = lf.GetAmountOfRows(#currencyTable)
	if numberOfRows then
		-- Turn our parent list into a horizontal list to allow for columns.
		TOOLTIP.GROUP:SetHorizontal(true)

		-- Create our first column.
		COLUMNS[1] = lf.CreateTooltipColumn(TOOLTIP.GROUP)
	end

	local index = 0

	for idx,CURRENCY in pairs(currencyTable) do
		table.insert(sortedTable, CURRENCY)
	end

	table.sort(sortedTable, function(a,b) return a<b end)

	for idx,CURRENCY in pairs(sortedTable) do
		-- If we are splitting into rows and our index is past the number of rows per column, create a new column.
		if numberOfRows and index >= numberOfRows then
			index = 0

			COLUMNS[#COLUMNS+1] = lf.CreateTooltipColumn(TOOLTIP.GROUP)
		end

		-- Create our new currency widget to either the newest column, or our parent list.
		lf.MakeCurrencyWidget(CURRENCY, COLUMNS[#COLUMNS] or TOOLTIP.GROUP)		

		index = index + 1
	end

	-- Autosize the tooltip the match the amount of entries and columns.
	local totalWidth = 0
	for _,COLUMN in pairs(COLUMNS) do
		totalWidth = totalWidth + COLUMN:GetBounds().width
	end

	TOOLTIP.GROUP:SetDims("height:" .. TOOLTIP.GROUP:GetLength())
	if totalWidth > 0 then
		TOOLTIP.GROUP:SetDims("height:" .. COLUMNS[1]:GetLength())
		TOOLTIP.GROUP:SetDims("width:" .. totalWidth)
	end

	return TOOLTIP
end

function lf.MakeCurrencyWidget(currency, parent)
	local GROUP = Component.CreateWidget(bp_TooltipItemWidget, parent)
	GROUP:SetDims("height:22; width:100%; top:0; left:0")

	local ENTRY = {
		GROUP = GROUP,

		NAME = GROUP:GetChild("Name"),
		QUANTITY = GROUP:GetChild("Quantity"),
		DASH_LINES = GROUP:GetChild("dash_lines"),
		ICON = MultiArt.Create(GROUP)
	}

	ENTRY.ICON:SetDims("height:25; width:25; right:100%; top:-2")

	local currencyType = currency
	if RESOURCE_IDS[currency] then currencyType = RESOURCE_IDS[currency] end

	local currencyInfo = g_cachedFunds[currencyType]
	local itemInfo = nil

	if type(currencyInfo) == "number" then
		itemInfo = Game.GetItemInfoByType(currencyType)
	end

	ENTRY.NAME:SetText(NAME_MAPPING[currencyType] or itemInfo.name)
	ENTRY.QUANTITY:SetText(_math.MakeReadable(currencyInfo))

	if REGION_MAPPING[currency] then 	-- If static texture is found, set the texture based on that.
		ENTRY.ICON:SetTexture("currency_new", REGION_MAPPING[currency])

		ENTRY.ICON:SetDims("height:16; width:16; right:100%-4; top:0")
	else
		-- Somehow we don't have any item information, so return an error.
		assert(itemInfo, "We do not have any item information for: " .. tostring(currencyType))

		-- Set the name variable to the proper value, as we have itemInfo.
		name = itemInfo.name

		ENTRY.ICON:SetIcon(itemInfo.web_icon_id)
	end

	local name_bounds = ENTRY.NAME:GetTextDims().width
	local quantity_bounds = ENTRY.QUANTITY:GetTextDims().width

	ENTRY.DASH_LINES:SetMaskDims("left:" .. name_bounds+15 .. "; right:100%-" .. quantity_bounds+31)
end

function lf.HideCurrencyTooltip()
	Tooltip.Show(false)
end

function lf.GetNewIndex()
	-- Loop 1 to the amount of max wallets to try and find a non-collision, then return it.
	for i = 1,#d_CreatedWallets do
		if not d_CreatedWallets[i] then return i end
	end

	return #d_CreatedWallets+1
end

function lf.OnPriceEnter(name, parent)
	if g_Tooltip then lf.OnPriceLeave() end

	-- Create our tooltip
	local GROUP = Component.CreateWidget(bp_TooltipWidget, parent)
	g_Tooltip = {
		GROUP = GROUP,

		TEXT = GROUP:GetChild("Text")
	}

	-- Set the name of the currency in the tooltip.
	g_Tooltip.TEXT:SetText(name)
	
	-- Resize the tooltip to match the dimensions.
	local tt_bounds = g_Tooltip.TEXT:GetTextDims()
	g_Tooltip.GROUP:SetDims("height:" .. tt_bounds.height+5 .. "; width:" .. tt_bounds.width+5)

	-- Show the tooltip.
	Tooltip.Show(g_Tooltip.GROUP, {width=tt_bounds.width, height=tt_bounds.height, frame_color="#DADADA"})
end

function lf.OnPriceLeave()
	Tooltip.Show(false)

	if g_Tooltip and Component.IsWidget(g_Tooltip.GROUP) then
		Component.RemoveWidget(g_Tooltip.GROUP)
	end

	g_Tooltip = nil
end

-- private handlers

local function OnWalletRefresh(args)
	g_cachedFunds = jsontotable(args);
	if (p_cbRefreshFunction) then
		p_cbRefreshFunction();
		p_cbRefreshFunction = nil;
	end
	g_DISPATCHER:DispatchEvent("OnUpdate");

	for _,OBJECT in pairs(d_CreatedWallets) do
		OBJECT:Refresh()
	end
end
Liaison.BindMessage("Wallet_Refresh", OnWalletRefresh);

local function OnWalletGetFunds(args)
	g_cachedFunds = args;
end
Liaison.BindMessage("Wallet_GetFunds", OnWalletGetFunds);

local function OnWalletRedBeanResponse(args)
	local dat = jsontotable(args);
	p_cbSpendFunction(dat.response);
	--p_cbSpendFunction = nil;
end
Liaison.BindMessage("Wallet_RedBeanAction", OnWalletRedBeanResponse);

local function OnWalletUpdate(args)
	g_cachedFunds = jsontotable(args);
	g_DISPATCHER:DispatchEvent("OnUpdate");

	for idx,OBJECT in pairs(d_CreatedWallets) do
		OBJECT:Refresh()
	end
end
Liaison.BindMessage("Wallet_Update", OnWalletUpdate);
