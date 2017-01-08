
--
-- lib_ItemSelection
--	by: John Su
--
--	creates a colorful list for presenting items to the player to select

--[[

	LIST = ItemSelection.CreateList(PARENT)		-- creates a LIST object
													[PARENT] is either a frame or a widget
	LIST:Open([open_down], [dur])				-- expands the list over [dur] seconds (defaults to ItemSelection.OPEN_DUR
													if [open_down] is true (default), the list opens downwards
	LIST:Close([dur])							-- collapses the list over [dur] seconds (defaults to ItemSelection.CLOSE_DUR)
													it collapses in the opposite direction that the list opened in
	is_open = LIST:IsOpen()						-- returns if the LIST is open or not
	
	LIST:SetDisplayCount(n)						-- sets the maximum number [n] of entries displayed	
	LIST:ScrollTo(i, [dur])						-- scrolls the top of the list to position [i] over [dur] seconds (defaults to ItemSelection.SCROLL_DUR)
	LIST:ScrollToPercent(pct, [dur])			-- scrolls [pct]% of the way down over [dur] seconds (defaults to ItemSelection.SCROLL_DUR)
	LIST:SetMaxAdjustment(amount)				-- sets the maximum adjustment for cumulative entries
	i = LIST:GetTopScroll()						-- gets the index [i] of the item at the top of the list
	{width, height} = LIST:GetMaxDims()			-- returns the max width and height of the entries as combined
	LIST:Reset()								-- removes all ENTRY objects from this list
	LIST:Sort(sort_func[, dur])					-- sorts ENTRY's based on function [sort_func]; entries are shuffled over [dur] seconds (default 0)
	
		LIST also employs an EventDispatcher (see lib_EventDispatcher), and dispatches the following events:
		
		"OnScroll"		: when the list is scrolled; args contain .delta (int) and .top_idx (int)
		"OnSelect"		: when the user clicks on an ENTRY; args contain .idx (int) and .ENTRY (ENTRY)
		"OnMouseEnter"	: when the user mouses over the list
		"OnMouseLeave"	: when the user mouses off the list
	
	
	ENTRY = LIST:AddEntry([args])				-- creates an ENTRY object to be nested in the LIST.
													[args], if supplied, can contain the following params:
														.quantity	-- number; displays how many in the stack
														.variable	-- boolean; if true, allows the quantity to be set by the user
	ENTRY = LIST:GetEntry(i)					-- returns the ENTRY object at index [i] in the LIST
	n = LIST:GetEntryCount()					-- returns the number of ENTRY objects [n] in the LIST
	
	ENTRY:Destroy()								-- destroyed the ENTRY and removes it from its LIST
	ENTRY:SetItemInfo(info, stackInfo)			-- info should be a table that at least contains the following (from Game.GetItemInfoByType(id)):
													.name	-- localized display string
													.rarity -- string ("salvage", "common", "epic", etc.)
													stackInfo may be a table with the following optional parameters:
													.amount -- the amount available in a stack (will allow a slider to appear)
													.quality -- the quality of this stack (for resources)
	info[, stackInfo] = ENTRY:GetItemInfo()		-- returns the info that was passed in
	
	ENTRY:AdjustAmount(amt)						-- manually adjust the amount
	ENTRY:SetBackColor(color)					-- sets the color of the back
	
		ENTRY also employs an EventDispatcher (see lib_EventDispatcher), and dispatches the following events:
	
		"OnMouseEnter"		: when the cursor is over the item
		"OnMouseLeave"		: when the cursor leaves the item
		"OnSelect"			: when the user clicks on the item		
		"OnAdjustQuantity"	: when the user adjusts the variable quantity
	
--]]

ItemSelection = {};

require "unicode";
require "lib/lib_EventDispatcher";
require "lib/lib_Items";
require "lib/lib_TextFormat";

ItemSelection.OPEN_DUR = .125;
ItemSelection.CLOSE_DUR = .125;
ItemSelection.SCROLL_DUR = .0675;

local ENTRY_HEIGHT = 25;	-- standard entry height
local ENTRY_SPACING = 28;
local ENTRY_GAP = ENTRY_SPACING-ENTRY_HEIGHT;
local ENTRY_ZERO = {top=0, height=0};	-- fake entry for aiding Entry spacing in the absence of a predecessor
local ADJUSTER_HEIGHT = 40;	-- standard ajuster height

local LIST_API = {};
local LIST_METATABLE = {
	__index = function(t,key) return LIST_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in LIST"); end
};

local ENTRY_API = {};
local ENTRY_METATABLE = {
	__index = function(t,key) return ENTRY_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ENTRY"); end
};

local BORDERS_API = {};

----------------
-- BLUEPRINTS --
----------------

local BP_LIST = [[<FocusBox dimensions="dock:fill" style="clip-children:true">
		<Border name="back" dimensions="dock:fill" class="SmallBorders"/>
		<FocusBox name="backFocus" dimensions="dock:fill"/>
		<Group name="entries" dimensions="dock:fill"/>
	</FocusBox>]];

local BP_ENTRY = [[<Group dimensions="dock:fill">
		<Border name="back" dimensions="dock:fill" class="SmallBorders"/>
		<Text name="label" dimensions="left:3; right:100%-5; center-y:50%; height:100%" style="halign:left; valign:center; font:Narrow_11"/>
		<FocusBox name="focus" dimensions="dock:fill"/>
	</Group>]];
	
local BP_SCROLLBAR = [[<Group dimensions="right:100%; width:0; height:100%">
		<StillArt name="back" dimensions="dock:fill" style="texture:Slider; region:back_v; ywrap:21"/>
		<Slider name="slider" dimensions="center-x:50%; width:66%; height:100%"/>
	</Group>]];

local BP_ADJUSTER = [[<Group dimensions="dock:fill">
		<Group name="slider_group" dimensions="right:100%; bottom:100%-3; right:100%; width:100%; height:16">
			<StillArt name="back" dimensions="center-y:50%; height:16; width:100%" style="texture:colors; region:black"/>
			<Slider name="slider" dimensions="center-y:50%; width:100%; height:16" class="SliderHorizontal" style="inverted:true"/>
		</Group>
		<Text name="text" dimensions="top:0; height:100%-16; left:0; right:100%" style="font:Narrow_11; halign:right; valign:center"/>
	</Group>]];

-------------
-- LIB API --
-------------

function ItemSelection.CreateList(PARENT)
	local WIDGET = Component.CreateWidget(BP_LIST, PARENT);
	
	local LIST = {
		GROUP = WIDGET,	-- actually a focusBox
		BACK = WIDGET:GetChild("back"),
		BACK_FOCUS = WIDGET:GetChild("backFocus");
		ENTRIES = {
			GROUP = WIDGET:GetChild("entries"),
		},
		--EVENT_DISPATCHER
		SCROLLBAR = {GROUP=nil, SLIDER=nil, BACK=nil}, 
		is_open = false,
		open_down = true,
		display_count = 5,
		scrollIdx = 1,	-- scroll index (entry)
		scrollable = 1,	-- scrollable height
		maxScroll = 1, -- last index to scroll to (entry)
		contentHeight = 0,	-- sum of entry heights
		max_adjust = 0,
	}
	LIST.BACK:SetParam("tint", 0);
	LIST.BACK_FOCUS:BindEvent("OnScroll", function(args)
		if (args.amount < 0) then
			LIST:ScrollTo(math.floor(LIST.scrollIdx-.1));
		else
			LIST:ScrollTo(math.ceil(LIST.scrollIdx+.1));
		end
	end);
	
	LIST.GROUP:BindEvent("OnMouseEnter", function()
		LIST:DispatchEvent("OnMouseEnter");
	end);
	LIST.GROUP:BindEvent("OnMouseLeave", function()
		LIST:DispatchEvent("OnMouseLeave");
	end);
	
	LIST.EVENT_DISPATCHER = EventDispatcher.Create(LIST);
	LIST.EVENT_DISPATCHER:Delegate(LIST);
	
	setmetatable(LIST, LIST_METATABLE);
	
	return LIST;
end

--------------
-- LIST API --
--------------
local	LIST_PRIVATE_UpdateSlider,
		LIST_PRIVATE_UpdateEntryPositions;

function LIST_API.Destroy(LIST)
	LIST:Reset();
	Component.RemoveWidget(LIST.GROUP);
	LIST.EVENT_DISPATCHER:Destroy();
	
	for k,v in pairs(LIST) do
		LIST[k] = nil;
	end
	setmetatable(LIST, nil);
end

function LIST_API.Reset(LIST)
	while (#LIST.ENTRIES > 0) do
		-- destroy from back to front, to reduce re-indexing times
		LIST.ENTRIES[#LIST.ENTRIES]:Destroy();
	end
end

function LIST_API.Sort(LIST, func, dur)
	if (#LIST.ENTRIES == 0) then
		-- no op
		return;
	end
	table.sort(LIST.ENTRIES, func);
	-- re-index
	for i=1, #LIST.ENTRIES do
		LIST.ENTRIES[i].idx = i;
	end
	LIST_PRIVATE_UpdateEntryPositions(LIST, 1, dur or 0);
end

function LIST_API.SetDisplayCount(LIST, n)
	LIST.display_count = n;
	LIST:ScrollTo(LIST.scrollIdx);
end

function LIST_API.Open(LIST, open_down, dur)
	LIST.is_open = true;
	LIST_API.open_down = (open_down ~= false);
	dur = dur or ItemSelection.OPEN_DUR;
	
	for idx, ENTRY in ipairs(LIST.ENTRIES) do
		ENTRY.GROUP:MoveTo("top:"..(ENTRY.top).."; height:"..ENTRY.height, dur);
	end
	if (LIST.SCROLLBAR.GROUP) then
		LIST.SCROLLBAR.GROUP:MoveTo("top:0; bottom:100%", dur);
	end
	LIST.BACK:MoveTo("top:0; bottom:100%", dur);
	LIST.GROUP:ParamTo("alpha", 1, dur);
	
	LIST_PRIVATE_UpdateSlider(LIST);
	LIST:ScrollTo(LIST.scrollIdx, dur);
end

function LIST_API.Close(LIST, dur)
	LIST.is_open = false;
	dur = dur or ItemSelection.CLOSE_DUR;
	-- collapse ENTRIES into top/bottom position
	local dims;
	local back_dims;
	local TOP_ENTRY = LIST.ENTRIES[LIST.scrollIdx] or ENTRY_ZERO;
	if (LIST_API.open_down) then
		dims = "top:"..(TOP_ENTRY.top).."; height:"..ENTRY_HEIGHT;
		back_dims = "top:0; height:"..ENTRY_HEIGHT;
	else
		dims = "top:"..(TOP_ENTRY.top - ENTRY_HEIGHT).."+100%; height:"..ENTRY_HEIGHT;
		back_dims = "bottom:100%; height:"..ENTRY_HEIGHT;
	end
	for idx, ENTRY in ipairs(LIST.ENTRIES) do
		ENTRY.GROUP:MoveTo(dims, dur);
	end
	if (LIST.SCROLLBAR.GROUP) then
		LIST.SCROLLBAR.GROUP:MoveTo(back_dims, dur);
	end
	LIST.BACK:MoveTo(back_dims, dur);
	LIST.GROUP:ParamTo("alpha", 0, dur);
end

function LIST_API.IsOpen(LIST)
	return LIST.is_open;
end

function LIST_API.AddEntry(LIST, args)
	local WIDGET = Component.CreateWidget(BP_ENTRY, LIST.ENTRIES.GROUP);
	
	local ENTRY = {
		LIST = LIST,
		GROUP = WIDGET,
		BORDERS = WIDGET:GetChild("back"),
		LABEL = WIDGET:GetChild("label"),
		ADJUSTER = {
			width = 0,
			cap = 1,
			OnStateChanged = function() end,	-- does nothing
			-- ADJUSTER = nil
		},
		FOCUSBOX = WIDGET:GetChild("focus"),
		idx = #LIST.ENTRIES + 1,
		itemInfo = false,
		stackInfo = false,
		--EVENT_DISPATCHER
		width = 0,
		top = 0,
		height = ENTRY_HEIGHT,
	};
	
	ENTRY.EVENT_DISPATCHER = EventDispatcher.Create(ENTRY);
	ENTRY.EVENT_DISPATCHER:Delegate(ENTRY);
	
	ENTRY.BORDERS:SetParam("exposure", -.5);
	
	-- bind FocusBox Events
	ENTRY.FOCUSBOX:BindEvent("OnMouseEnter", function()
		ENTRY:DispatchEvent("OnMouseEnter");
		ENTRY.BORDERS:ParamTo("exposure", 0.0, .01);
	end);
	ENTRY.FOCUSBOX:BindEvent("OnMouseLeave", function()
		ENTRY:DispatchEvent("OnMouseLeave");
		ENTRY.BORDERS:ParamTo("exposure", -.5, .1, 0, "ease-in");
	end);
	ENTRY.FOCUSBOX:BindEvent("OnMouseDown", function()
		ENTRY:DispatchEvent("OnSelect");
		ENTRY.BORDERS:SetParam("exposure", 0.5);
		ENTRY.BORDERS:ParamTo("exposure", 0, .2);
	end);
	ENTRY.FOCUSBOX:BindEvent("OnScroll", function(args)
		LIST:ScrollTo(LIST.scrollIdx + args.amount);
	end);
	
	LIST.ENTRIES[ENTRY.idx] = ENTRY;
	setmetatable(ENTRY, ENTRY_METATABLE);
	
	LIST_PRIVATE_UpdateEntryPositions(LIST, ENTRY.idx, 0);
	LIST_PRIVATE_UpdateSlider(LIST);
	
	return ENTRY;
end

function LIST_API.GetEntry(LIST, idx)
	return LIST.ENTRIES[idx];
end

function LIST_API.GetEntryCount(LIST)
	return #LIST.ENTRIES;
end

function LIST_API.ScrollTo(LIST, idx, dur)
	-- defaults
	idx = idx or LIST.scrollIdx;
	dur = dur or ItemSelection.SCROLL_DUR;
	-- constrain
	idx = math.max(1, math.min(idx, LIST.maxScroll));
	LIST.scrollIdx = idx;
	LIST.scrollable = LIST.contentHeight - LIST.GROUP:GetBounds().height;	-- refresh this whenever
	
	local entry_idx = math.floor(idx+.5);
	local ENTRY = LIST.ENTRIES[entry_idx] or ENTRY_ZERO;
	local offset = math.min(ENTRY.top + (idx%1) * ENTRY.height, LIST.scrollable);
	
	LIST.ENTRIES.GROUP:MoveTo("top:"..(-offset).."; height:100%", dur);
	if (LIST.SCROLLBAR.SLIDER) then
		LIST.SCROLLBAR.SLIDER:SetPercent(offset / LIST.scrollable);
	end
end

function LIST_API.ScrollToPercent(LIST, pct, dur)
	dur = dur or ItemSelection.SCROLL_DUR;
	
	local offset = LIST.scrollable * pct;
	
	-- find closest scroll idx
	LIST.scrollIdx = LIST.maxScroll;
	for i=1, #LIST.ENTRIES do
		if (LIST.ENTRIES[i].top >= offset) then
			LIST.scrollIdx = i;
			break;
		end
	end
	
	LIST.ENTRIES.GROUP:MoveTo("top:"..(-offset).."; height:100%", dur);
	if (LIST.SCROLLBAR.SLIDER) then
		LIST.SCROLLBAR.SLIDER:SetPercent(pct);
	end
end

function LIST_API.SetMaxAdjustment(LIST, amount)
	assert(amount >= 0, "cannot set negative max adjustments");
	LIST.max_adjust = amount;
end

function LIST_API.GetMaxDims(LIST)
	local dims = {width=0, height=LIST.contentHeight};
	for i, ENTRY in ipairs(LIST.ENTRIES) do
		dims.width = math.max(dims.width, ENTRY.width);
	end
	if (LIST.SCROLLBAR.SLIDER) then
		dims.width = dims.width + 22;	-- SCROLLBAR.GROUP width
	end
	
	return dims;
end

function LIST_PRIVATE_UpdateSlider(LIST)
	-- find out what we can fit on the last "page"
	local visible_height = LIST.GROUP:GetBounds().height;
	LIST.scrollable = LIST.contentHeight - visible_height;
	local last_page_height = 0;
	local n = #LIST.ENTRIES;
	local last_top_idx = n;
	if (n > 0) then
		for i=1, n do
			local idx = n-i+1;
			local ENTRY = LIST.ENTRIES[idx];
			visible_height = visible_height - ENTRY.height;
			if (visible_height <= 0) then
				-- that's the limit; stop here
				last_top_idx = idx + (-visible_height) / ENTRY.height;
				break;
			else
				-- we can safely show this entry at the top
				last_top_idx = idx;
				visible_height = visible_height - ENTRY_GAP;
			end
		end
	end
	
	LIST.maxScroll = last_top_idx;
	local dur = .1;
	
	if ((LIST.maxScroll > 1) ~= (LIST.SCROLLBAR.GROUP ~= nil)) then
		if (LIST.SCROLLBAR.GROUP) then
			Component.RemoveWidget(LIST.SCROLLBAR.GROUP);
			LIST.SCROLLBAR = {};
			LIST.ENTRIES.GROUP:MoveTo("left:_; right:100%", dur);
		else
			LIST.SCROLLBAR.GROUP = Component.CreateWidget(BP_SCROLLBAR, LIST.GROUP);
			LIST.SCROLLBAR.SLIDER = LIST.SCROLLBAR.GROUP:GetChild("slider");
			LIST.SCROLLBAR.GROUP:MoveTo("right:100%; width:22", dur);
			LIST.ENTRIES.GROUP:QueueMove("left:_; right:100%-22", dur);
			
			LIST.SCROLLBAR.SLIDER:BindEvent("OnStateChanged", function()
				LIST:ScrollToPercent(LIST.SCROLLBAR.SLIDER:GetPercent(), 0);
			end)
		end
	end
	if (LIST.SCROLLBAR.SLIDER) then
		LIST.SCROLLBAR.SLIDER:SetSteps(LIST.scrollable);
		LIST.SCROLLBAR.SLIDER:SetScrollSteps(ENTRY_HEIGHT);
		LIST.SCROLLBAR.SLIDER:SetJumpSteps(3*ENTRY_HEIGHT);
		LIST.SCROLLBAR.SLIDER:ParamTo("thumbsize", math.max(.2, 1/(LIST.maxScroll+1)), dur);
	end
end

function LIST_PRIVATE_UpdateEntryPositions(LIST, start_idx, dur)
	-- recalculates their positions and moves them into the right spot
	local n = #LIST.ENTRIES;
	local PREV_ENTRY = LIST.ENTRIES[start_idx-1] or ENTRY_ZERO;
	if (start_idx <= n) then
		for i=start_idx, n do
			local ENTRY = LIST.ENTRIES[i];
			ENTRY.top = PREV_ENTRY.top + PREV_ENTRY.height + ENTRY_GAP;
			ENTRY.GROUP:MoveTo("top:"..ENTRY.top.."; height:"..ENTRY.height, dur);
			PREV_ENTRY = ENTRY;
		end
		
		-- recalculate total height
		LIST.contentHeight = 0;
		for i=1, n do
			LIST.contentHeight = LIST.contentHeight + LIST.ENTRIES[i].height + ENTRY_GAP;
		end
	end
end

---------------
-- ENTRY API --
---------------

function ENTRY_API.Destroy(ENTRY)
	-- remove from LIST
	local LIST = ENTRY.LIST;
	table.remove(LIST.ENTRIES, ENTRY.idx);
	-- re-index trailing entries
	if (ENTRY.idx <= #LIST.ENTRIES) then
		for i=ENTRY.idx, #LIST.ENTRIES do
			LIST.ENTRIES[i].idx = i;
		end
	end
	LIST_PRIVATE_UpdateEntryPositions(LIST, ENTRY.idx, 0);
	
	ENTRY.EVENT_DISPATCHER:Destroy();
	
	Component.RemoveWidget(ENTRY.GROUP);
	for k,v in pairs(ENTRY) do
		ENTRY[k] = nil;
	end
	setmetatable(ENTRY, nil);
end

function ENTRY_API.SetItemInfo(ENTRY, itemInfo, stackInfo)
	ENTRY.itemInfo = itemInfo or false;
	ENTRY.stackInfo = stackInfo or false;
	TextFormat.Clear(ENTRY.LABEL);
	if (itemInfo) then
		local TF = LIB_ITEMS.GetNameTextFormat(itemInfo, {quality = (stackInfo or {}).quality});
		TF:ApplyTo(ENTRY.LABEL);
	else
		ENTRY.LABEL:SetText("");
	end
	
	-- show quantifier if necessary
	local use_quantifier = (stackInfo and stackInfo.amount and ENTRY.LIST.max_adjust ~= 1);
	if (use_quantifier) then



		if (not ENTRY.ADJUSTER.GROUP) then
			local WIDGET = Component.CreateWidget(BP_ADJUSTER, ENTRY.GROUP);
			ENTRY.ADJUSTER = {
				GROUP = WIDGET,
				SLIDER_GROUP = WIDGET:GetChild("slider_group"),
				SLIDER = WIDGET:GetChild("slider_group.slider"),
				TEXT = WIDGET:GetChild("text"),
			};
			function ENTRY.ADJUSTER.OnStateChanged()
				-- ensure we don't go over the max_adjust
				local max_select;
				if (ENTRY.LIST.max_adjust and ENTRY.LIST.max_adjust > 0) then
					local total = 0;
					for _, OTHER_ENTRY in ipairs(ENTRY.LIST.ENTRIES) do
						if (OTHER_ENTRY ~= ENTRY and OTHER_ENTRY.stackInfo) then
							total = total + OTHER_ENTRY.stackInfo.selected;
						end
					end
					max_select = ENTRY.LIST.max_adjust - total;
				else
					max_select = ENTRY.ADJUSTER.cap;
				end
				
				if (max_select < 0) then
					warn("there are more items selected than allowed! "..(total).."/"..tostring(ENTRY.ADJUSTER.cap));
					max_select = 0;
				end
				ENTRY.ADJUSTER.SLIDER:SetMaxPercent(math.min(1, max_select / ENTRY.ADJUSTER.cap + .01));	-- a 1% padding, so it can appear to "budge"
				
				local amt = math.floor(ENTRY.ADJUSTER.SLIDER:GetPercent() * ENTRY.ADJUSTER.cap + .5);
				if (amt > max_select) then
					amt = max_select;
					ENTRY.ADJUSTER.SLIDER:SetPercent(amt / ENTRY.ADJUSTER.cap);
				end
				stackInfo.selected = amt;
				ENTRY.ADJUSTER.TEXT:SetText(tonumber(stackInfo.selected).." / "..stackInfo.amount);
				ENTRY:DispatchEvent("OnAdjustQuantity", {amount=amt});
			end
			ENTRY.height = ADJUSTER_HEIGHT;
			ENTRY.LABEL:SetDims("top:0; height:100%-16");
			LIST_PRIVATE_UpdateEntryPositions(ENTRY.LIST, ENTRY.idx);
			ENTRY.ADJUSTER.SLIDER:BindEvent("OnStateChanged", ENTRY.ADJUSTER.OnStateChanged);
		end
		
		ENTRY.ADJUSTER.TEXT:SetText(stackInfo.amount.." / "..stackInfo.amount);
		ENTRY.ADJUSTER.width = ENTRY.ADJUSTER.TEXT:GetTextDims().width + 25;	-- see how much space we will need at max (+ padding)
		ENTRY.ADJUSTER.GROUP:SetDims("right:100%-5; width:100%-10");
		
		if (ENTRY.LIST.max_adjust > 1 and stackInfo.amount > 0) then
			ENTRY.ADJUSTER.cap = math.min(ENTRY.LIST.max_adjust, stackInfo.amount);
		else
			ENTRY.ADJUSTER.cap = math.max(stackInfo.amount, 1);
		end
		ENTRY.ADJUSTER.SLIDER:SetSteps(ENTRY.ADJUSTER.cap);
		ENTRY.ADJUSTER.SLIDER:SetJumpSteps(ENTRY.ADJUSTER.cap/10);
		ENTRY.ADJUSTER.SLIDER:SetPercent(0);
		ENTRY.ADJUSTER.OnStateChanged();
		
	elseif (ENTRY.ADJUSTER.TEXT) then
		ENTRY.ADJUSTER.TEXT:SetText("");
		ENTRY.ADJUSTER.width = 0;
	end
	
	ENTRY.width = ENTRY.LABEL:GetTextDims().width + ENTRY.ADJUSTER.width + 20;
end

function ENTRY_API.GetItemInfo(ENTRY)
	return ENTRY.itemInfo, ENTRY.stackInfo;
end

function ENTRY_API.AdjustAmount(ENTRY, amt)
	ENTRY.ADJUSTER.OnStateChanged();
	local pct = math.min(1, amt / ENTRY.ADJUSTER.cap);
	if (ENTRY.ADJUSTER.SLIDER and pct ~= ENTRY.ADJUSTER.SLIDER:GetPercent()) then
		ENTRY.ADJUSTER.SLIDER:SetPercent(pct);
		ENTRY.ADJUSTER.OnStateChanged();
	end
end

----------------
-- BORDER API --
----------------

function BORDERS_API.Create(PARENT)
	local BORDERS = {
		GROUP = Component.CreateWidget([[<Group dimensions="dock:fill">
			<StillArt name="center" dimensions="center-x:50%; center-y:50%; width:100%-16; height:100%-16" style="texture:SmallBorders; region:center"/>
			<StillArt name="top" dimensions="center-x:50%; top:0; width:100%-16; height:8" style="texture:SmallBorders; region:top"/>
			<StillArt name="bottom" dimensions="center-x:50%; bottom:100%; width:100%-16; height:8" style="texture:SmallBorders; region:bottom"/>
			<StillArt name="left" dimensions="left:0; center-y:50%; width:8; height:100%-16" style="texture:SmallBorders; region:left"/>
			<StillArt name="right" dimensions="right:100%; center-y:50%; width:8; height:100%-16" style="texture:SmallBorders; region:right"/>
			<StillArt name="TL" dimensions="left:0%; top:0%; width:8; height:8" style="texture:SmallBorders; region:TL"/>
			<StillArt name="TR" dimensions="right:100%; top:0%; width:8; height:8" style="texture:SmallBorders; region:TR"/>
			<StillArt name="BL" dimensions="left:0%; bottom:100%; width:8; height:8" style="texture:SmallBorders; region:BL"/>
			<StillArt name="BR" dimensions="right:100%; bottom:100%; width:8; height:8" style="texture:SmallBorders; region:BR"/>
		</Group>]], PARENT),
		PIECES = {},
	}
	for i=1, BORDERS.GROUP:GetChildCount() do
		local WIDGET = BORDERS.GROUP:GetChild(i);
		BORDERS.PIECES[WIDGET:GetName()] = WIDGET;
	end
	
	BORDERS.SetParam = BORDERS_API.SetParam;
	BORDERS.ParamTo = BORDERS_API.ParamTo;
	return BORDERS;
end

function BORDERS_API.SetParam(BORDERS, ...)
	for _, WIDGET in pairs(BORDERS.PIECES) do
		WIDGET:SetParam(...);
	end
end

function BORDERS_API.ParamTo(BORDERS, ...)
	for _, WIDGET in pairs(BORDERS.PIECES) do
		WIDGET:ParamTo(...);
	end
end
