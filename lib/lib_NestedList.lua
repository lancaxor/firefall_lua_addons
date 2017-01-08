
--
-- lib_NestedList
--	by: John Su
--
--	creates a list with expandable/collapsable items (uses lib_RowScroller)

--[[

	LIST = NestedList.Create(PARENT)
	(LIST is an implementation of RowScroller's SCROLLER; see lib_RowScroller for documentation)
	
	ITEM = LIST:CreateItem(ref_val[, insert_pos])
	(ITEM is an implementation of a RowScroller's ROW; see lib_RowScroller for documentation)
	LIST:GetChild(ref)		-- returns a child item, either by ref_val or row number
	LIST:GetChildCount()	-- returns the number of children

	LIST:Open([dur])		-- displays the LIST's children in [dur] seconds (defaults to NestedList.OPEN_DUR)
	LIST:Close([dur])		-- collapses the LIST's children in [dur] seconds (defaults to NestedList.OPEN_DUR)
	LIST:IsOpen([dur])		-- returns true if the LIST's children are displayed

	ITEM:Open([dur])		-- displays the ITEM's children (if any) in [dur] seconds (defaults to NestedList.OPEN_DUR)
	ITEM:Close([dur])		-- collapses the ITEM's children in [dur] seconds (defaults to NestedList.OPEN_DUR)
	ITEM:Show(visible)		-- shows or hides the ITEM (children too, if false)
	bool = ITEM:IsOpen()	-- returns true if the ITEM's children are displayed
	
	nested_ITEM = ITEM:CreateItem(ref_val[, insert_pos])	-- creates a child ITEM
	ITEM:Clear()			-- removes all the child items in this Item
	ITEM:GetChild(ref)		-- returns a child item, either by ref_val or row number
	ITEM:GetChildCount()	-- returns the number of children
	

	ITEM also dispatches the following events:
		"OnOpen"
		"OnClose"
		"OnItemAdded"	-- args = {ITEM}; for children being added
		"OnItemRemoved"	-- args = {ITEM}; for children being removed
		"OnParentOpen"
		"OnParentClose"
	
	-- the following are for aid in creating SUB_LISTs and ITEMs in a unified style:
	
		STYLEMENT = (LIST or ITEM):CreateStyledItem();
		-- this behaves exactly the same as a normal ITEM, but it also can do the following:
		WIDGET = STYLEMENT:GetWidget();	-- returns the container widget; put things in here
		STYLEMENT:SetLabel(text)			-- sets label
		STYLEMENT:ColorLabel(color)		-- sets label color
		STYLEMENT:TintBorder(color)		-- sets bg color
--]]

NestedList = {};

require "lib/lib_RowScroller";
require "lib/lib_EventDispatcher";
require "lib/lib_TextFormat";
require "lib/lib_HoloPlate";
require "lib/lib_Colors";
require "lib/lib_Callback2";


NestedList.OPEN_DUR = .15;
NestedList.CLOSE_DUR = .15;

local MAX_SPARES = 16;	-- maximum spare STYLEMENT widgets to keep on hand

local LIST_API = {};
local LIST_METATABLE = {
	__index = function(t,key) return LIST_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in LIST"); end
};

local ITEM_API = {};
local ITEM_METATABLE = {
	__index = function(t,key) return ITEM_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ITEM"); end
};

local NESTER_API = {};
local NESTER_METATABLE = {
	__index = function(t,key) return NESTER_API[key]; end,
};

local STYLED_API = {};

local SCROLLER_EVENTS = {"OnScroll", "OnScrollTo", "OnScrollHeightChanged", "OnSliderShow"};
local ROW_EVENTS = {"OnMouseDown", "OnMouseUp", "OnMouseEnter", "OnMouseLeave", "OnScoped", "OnRemoved"};
local EVENT_DISPATCHER_DELEGATE_METHODS = {"AddHandler", "DispatchEvent", "RemoveHandler", "HasHandler"};

local PRIVATE_CreateItem, PRIVATE_CreateNester, PRIVATE_ITEM_EnsureHasNester, PRIVATE_NESTER_PropagateDeltaChild, PRIVATE_ITEM_RecheckRecycling, PRIVATE_NESTER_PropagateVisibility;
local PRIVATE_ITEM_Expand, PRIVATE_ITEM_Collapse, PRIVATE_STYLEMENT_ShowListMode;
local PRIVATE_ForwardFunc;
local PRIVATE_GetFlatListPos;

-- blueprint for styled widgets

local BP_STYLEMENT = [[<Group dimensions="left:15; right:100%; top:0; height:20" class="ui_button">
	<Group name="plate" dimensions="dock:fill" style="visible:true"/>
	<Text name="state" dimensions="center-x:10; center-y:10; width:10; height:10;" style="font:Demi_10; halign:center; valign:center; padding:0" key="{+}"/>
	<Text name="label" dimensions="left:15; right:100%-3; top:0; height:100%" style="font:Demi_10; halign:left; valign:center; wrap:true"/>
</Group>]];

-------------
-- LIB API --
-------------

function NestedList.Create(PARENT)
	local LIST = {
		SCROLLER = RowScroller.Create(PARENT),
		--NESTER
		--DISPATCHER
		spare_STYLEMENTS = {},	-- for recycling styled items
	};
	LIST.NESTER = PRIVATE_CreateNester(LIST, nil);

	LIST.SCROLLER:SetSlider(RowScroller.SLIDER_DEFAULT);
	-- forward events
	for _,eventName in ipairs(SCROLLER_EVENTS) do
		LIST.SCROLLER:AddHandler(eventName, function(args)
			LIST.DISPATCHER:DispatchEvent(eventName, args);
		end);
	end

	LIST.DISPATCHER = EventDispatcher.Create(LIST);
	LIST.DISPATCHER:Delegate(LIST);
	
	setmetatable(LIST, LIST_METATABLE);
	
	return LIST;
end

--------------
-- LIST API --
--------------

-- forward scroller functions
local SCROLLER_FUNCS = {
	--"Destroy",
	"SetSlider",
	"ShowSlider",
	--"SetSpacing",
	"GetSpacing",
	"GetRowCount",
	"UpdateSize",
	"GetContainer",
	"GetContentSize",
	"ScrollToPercent",
	"ScrollToRow",
	"GetScrollPercent",
	"GetScrollIndex",
	"SetScrollStep",
	"LockUpdates",
	"UnlockUpdates",
	"GetRow",
	"Reset",
};
for _,funcName in ipairs(SCROLLER_FUNCS) do
	LIST_API[funcName] = function(LIST, ...)
		return LIST.SCROLLER[funcName](LIST.SCROLLER, ...);
	end
end

local NESTER_FUNCS = {
	"CreateItem",
	"CreateStyledItem",
	"GetChildCount",
	"IsOpen",
}
for _,funcName in ipairs(NESTER_FUNCS) do
	LIST_API[funcName] = function(LIST, ...)
		return LIST.NESTER[funcName](LIST.NESTER, ...);
	end
end

function LIST_API.Destroy(LIST)
	LIST.SCROLLER:Destroy();
	LIST.NESTER:Remove();
	LIST.DISPATCHER:Destroy();
	for k,v in pairs(LIST) do
		LIST[k] = nil;
	end
	setmetatable(LIST, nil);
end

function LIST_API.GetChild(LIST, ref)
	if (not LIST.NESTER) then
		return nil;
	elseif (type(ref) == "number") then
		return LIST.NESTER:GetChildAt(ref);
	else
		for i=1, #LIST.NESTER.child_ITEMS do
			local CHILD = LIST.NESTER.child_ITEMS[i];
			if (CHILD.ROW:GetValue() == ref) then
				return CHILD;
			end
		end
	end
end


function LIST_API.SetSpacing(LIST, ...)
	local ret = LIST.SCROLLER:SetSpacing(...);
	-- TODO: update LIST.NESTER's dims
	return ret;
end

function LIST_API.Open(LIST, ...)
	return LIST.NESTER:Open(true, ...);
end
function LIST_API.Close(LIST, ...)
	return LIST.NESTER:Open(false, ...);
end

----------------
-- NESTER API --
----------------
-- The Nester is the shared implementation between LIST and ITEM that allows them to add/remove ITEMS and open/close the list

function PRIVATE_CreateNester(PARENT_LIST, PARENT_ITEM)
	local NESTER = {
		PARENT_LIST = PARENT_LIST,
		PARENT_ITEM = PARENT_ITEM,
		child_ITEMS = {},			-- child_ITEMS[i] = ITEM
		generation = 0,				-- how nested is this item?
		is_shown = true,			-- am I, myself, shown?
		is_shown_from_top = true,	-- am I and all my parents shown?
		is_open = true,				-- am I, myself, open?
		is_open_from_top = true,	-- am I and all my parents open?
		descendant_count = 0,		-- number of ALL descendants, including children
	};
	if (PARENT_ITEM) then
		NESTER.is_shown = PARENT_ITEM.is_shown;	-- this must always match
	end
	NESTER.is_open_from_top = NESTER.is_open and (not PARENT_ITEM or PARENT_ITEM.PARENT_NESTER.is_open_from_top);
	NESTER.is_shown_from_top = NESTER.is_shown and (not PARENT_ITEM or PARENT_ITEM.PARENT_NESTER.is_shown_from_top);

	if (PARENT_ITEM) then
		NESTER.generation = PARENT_ITEM.PARENT_NESTER.generation + 1;
	end

	setmetatable(NESTER, NESTER_METATABLE);

	return NESTER;
end

function NESTER_API.Remove(NESTER)
	for k,ITEM in pairs(NESTER.child_ITEMS) do
		ITEM:Remove();
	end
	for k,v in pairs(NESTER) do
		NESTER[k] = nil;
	end
end

function NESTER_API.Open(NESTER, is_open, dur)
	if (NESTER.is_open ~= is_open) then
		NESTER.PARENT_LIST:LockUpdates();

		local default_dur, self_event, child_event;
		if (is_open) then
			default_dur = NestedList.OPEN_DUR;
			self_event = "OnOpen";
			parent_event = "OnParentOpen";
		else
			default_dur = NestedList.CLOSE_DUR;
			self_event = "OnClose";
			parent_event = "OnParentClose";
		end
		dur = dur or default_dur;

		NESTER.is_open = is_open;
		NESTER.is_open_from_top = NESTER.is_open and (not NESTER.PARENT_ITEM or NESTER.PARENT_ITEM.PARENT_NESTER.is_open_from_top);

		-- update self
		if (NESTER.PARENT_ITEM) then
			if (NESTER.PARENT_ITEM.PARENT_NESTER.is_open_from_top and NESTER.is_shown_from_top) then
				PRIVATE_ITEM_Expand(NESTER.PARENT_ITEM, dur);
			else
				PRIVATE_ITEM_Collapse(NESTER.PARENT_ITEM, dur);
			end
		end

		(NESTER.PARENT_ITEM or NESTER.PARENT_LIST):DispatchEvent(self_event);
		for i=1, #NESTER.child_ITEMS do
			local ITEM = NESTER.child_ITEMS[i];
			PRIVATE_NESTER_PropagateVisibility(ITEM, dur);
			ITEM:DispatchEvent(parent_event);
		end

		NESTER.PARENT_LIST:UnlockUpdates();
	end
end

function NESTER_API.Show(NESTER, is_shown, dur)
	if (NESTER.PARENT_ITEM) then
		assert(NESTER.PARENT_ITEM.is_shown == is_shown, "these should never be different");
	end

	if (NESTER.is_shown ~= is_shown) then
		NESTER.is_shown = is_shown;
		NESTER.is_shown_from_top = NESTER.is_shown and (not NESTER.PARENT_ITEM or NESTER.PARENT_ITEM.PARENT_NESTER.is_shown_from_top);

		dur = dur or 0.1;

		-- update self
		if (NESTER.PARENT_ITEM) then
			if (NESTER.PARENT_ITEM.PARENT_NESTER.is_open_from_top and NESTER.is_shown_from_top) then
				PRIVATE_ITEM_Expand(NESTER.PARENT_ITEM, dur);
			else
				PRIVATE_ITEM_Collapse(NESTER.PARENT_ITEM, dur);
			end
		end

		-- update children
		for i=1, #NESTER.child_ITEMS do
			local ITEM = NESTER.child_ITEMS[i];
			PRIVATE_NESTER_PropagateVisibility(ITEM, dur);
		end
	end
end

function NESTER_API.CanDisplay(NESTER)
	return NESTER.is_shown_from_top and (not NESTER.PARENT_ITEM or NESTER.PARENT_ITEM.PARENT_NESTER.is_open_from_top);
end

function PRIVATE_NESTER_PropagateVisibility(ITEM, animate_expansion)
	local is_visible = ITEM.PARENT_NESTER.is_open_from_top and ITEM.PARENT_NESTER.is_shown_from_top and ITEM.is_shown;
	if (ITEM.SUB_NESTER) then
		local is_open_from_top = ITEM.PARENT_NESTER.is_open_from_top and ITEM.SUB_NESTER.is_open;
		local is_shown_from_top = ITEM.PARENT_NESTER.is_shown_from_top and ITEM.SUB_NESTER.is_shown;
	
		-- update if any difference
		if (ITEM.SUB_NESTER.is_shown_from_top ~= is_shown_from_top or ITEM.SUB_NESTER.is_open_from_top ~= is_open_from_top) then
			ITEM.SUB_NESTER.is_shown_from_top = is_shown_from_top;
			ITEM.SUB_NESTER.is_open_from_top = is_open_from_top;
			-- and propagate to children
			for _,child_ITEM in pairs(ITEM.SUB_NESTER.child_ITEMS) do
				PRIVATE_NESTER_PropagateVisibility(child_ITEM, animate_expansion);
			end
		end
		is_visible = is_visible and is_shown_from_top;
	end

	-- animate expansion if applicable
	if (animate_expansion) then
		local dur = animate_expansion;
		if (is_visible) then
			PRIVATE_ITEM_Expand(ITEM, dur);
		else
			PRIVATE_ITEM_Collapse(ITEM, dur);
		end
	end
end

function NESTER_API.IsOpen(NESTER)
	return NESTER.is_open;
end

function NESTER_API.CreateItem(NESTER, ref_val, insert_pos)
	insert_pos = math.min(#NESTER.child_ITEMS + 1, insert_pos or (#NESTER.child_ITEMS + 1));
	local ITEM = PRIVATE_CreateItem(NESTER, false, ref_val, insert_pos);
	table.insert(NESTER.child_ITEMS, insert_pos, ITEM);
	PRIVATE_NESTER_PropagateDeltaChild(NESTER, 1);
	return ITEM;
end

function NESTER_API.CreateStyledItem(NESTER, ref_val, insert_pos)
	insert_pos = math.min(#NESTER.child_ITEMS + 1, insert_pos or (#NESTER.child_ITEMS + 1));
	local ITEM = PRIVATE_CreateItem(NESTER, true, ref_val, insert_pos);
	table.insert(NESTER.child_ITEMS, insert_pos, ITEM);
	PRIVATE_NESTER_PropagateDeltaChild(NESTER, 1);
	return ITEM;
end

-- for backwards compatability
function NESTER_API.CreateList(NESTER, ref_val, insert_pos)
	return NESTER:CreateItem(ref_val, insert_pos);
end

function NESTER_API.UnregisterItem(NESTER, ITEM)
	for i=1, #NESTER.child_ITEMS do
		local child_ITEM = NESTER.child_ITEMS[i];
		if (child_ITEM == ITEM) then
			table.remove(NESTER.child_ITEMS, i);
			PRIVATE_NESTER_PropagateDeltaChild(NESTER, -1);
			return;
		end
	end
end

function PRIVATE_NESTER_PropagateDeltaChild(NESTER, delta)
	-- propagate change in descendant_count up NESTER tree
	NESTER.descendant_count = NESTER.descendant_count + delta;
	if (NESTER.PARENT_ITEM) then
		PRIVATE_NESTER_PropagateDeltaChild(NESTER.PARENT_ITEM.PARENT_NESTER, delta);
	elseif (NESTER ~= NESTER.PARENT_LIST.NESTER) then
		-- end of the line; no more propagation 
		NESTER.PARENT_LIST.NESTER.descendant_count = NESTER.PARENT_LIST.NESTER.descendant_count + delta;
	end
end

function NESTER_API.GetChildAt(NESTER, idx)
	return NESTER.child_ITEMS[idx];
end

function NESTER_API.GetChildCount(NESTER)
	return #NESTER.child_ITEMS;
end

--------------
-- ITEM API --
--------------

function PRIVATE_CreateItem(NESTER, is_styled, ref_val, insert_pos)
	assert(insert_pos > 0 and insert_pos <= NESTER:GetChildCount()+1, "insert position is out of range");
	-- translate from relative insert_pos to absolute row_pos
	local row_pos = PRIVATE_GetFlatListPos(NESTER, insert_pos);

	local ITEM = {
		ROW = NESTER.PARENT_LIST.SCROLLER:AddRow(ref_val, row_pos),
		PARENT_NESTER = NESTER,
		SUB_NESTER = false,	-- no NESTER until you try to make a child
		ref_val = ref_val,
		item_size = {width=0, height=20},
		STYLEMENT = false,	-- "Styled Element"; only if is_styled
		is_expanded = true,
		is_shown = true,
	};
	ITEM.item_size = ITEM.ROW:GetSize();

	ITEM.DISPATCHER = EventDispatcher.Create(ITEM);
	ITEM.DISPATCHER:Delegate(ITEM);
	-- forward ROW events
	for _,evName in ipairs(ROW_EVENTS) do
		ITEM.ROW:AddHandler(evName, function(args)
			ITEM.DISPATCHER:DispatchEvent(evName, args);
		end);
	end
	
	-- update size on parent list
	if (PARENT_ITEM) then
		PARENT_ITEM:DispatchEvent("OnItemAdded", {ITEM=ITEM});
		ITEM:AddHandler("OnRemoved", function()
			PARENT_ITEM:DispatchEvent("OnItemRemoved", {ITEM=ITEM});
		end);
	else
		NESTER.PARENT_LIST:DispatchEvent("OnItemAdded", {ITEM=ITEM});
		ITEM:AddHandler("OnRemoved", function()
			NESTER.PARENT_LIST:DispatchEvent("OnItemRemoved", {ITEM=ITEM});
		end);
	end

	if (is_styled) then
		ITEM.STYLEMENT = {	-- Styled Element
			ITEM = ITEM,
			WIDGETS = nil,
			label_color = false,
			label_text = false,
			label_TextFormat = false,
		}
	
		ITEM.ROW:AddHandler("OnRemoved", function()
			PRIVATE_RecycleStyledItem(ITEM.STYLEMENT, false);
		end);

		ITEM.ROW:AddHandler("OnScoped", function(args)
			PRIVATE_RecycleStyledItem(ITEM.STYLEMENT, args.visible and ITEM.PARENT_NESTER:CanDisplay() and ITEM.is_shown);
		end);

		ITEM.item_size.height = 20;

		-- bind STYLED commands
		for k,Func in pairs(STYLED_API) do
			ITEM[k] = Func;
		end
	end

	setmetatable(ITEM, ITEM_METATABLE);

	ITEM.ROW:UpdateSize(ITEM.item_size);
	if (not NESTER.is_open_from_top) then
		PRIVATE_ITEM_Collapse(ITEM, 0);
	end

	if (is_styled) then
		PRIVATE_RecycleStyledItem(ITEM.STYLEMENT, ITEM.ROW:IsVisible());
	end

	return ITEM;	
end

-- forward scroller functions
local ROW_FUNCS = {
	--"MoveTo",
	--"UpdateSize",
	--"Remove",
	"IsVisible",
	"GetSize",
	"GetTop",
	"SetWidget",
	"GetWidget",
	"GetValue",
};
for _,funcName in ipairs(ROW_FUNCS) do
	ITEM_API[funcName] = function(ITEM, ...)
		return ITEM.ROW[funcName](ITEM.ROW, ...);
	end
end

function ITEM_API.MoveTo(ITEM, pos, ...)
	local current_pos = ITEM.ROW:GetIdx();
	local new_pos = PRIVATE_GetFlatListPos(ITEM.PARENT_NESTER, pos);
	if (new_pos ~= current_pos) then
		local delta_pos = new_pos - current_pos;
		-- shift self and children
		local num_to_move = 1;	-- myself
		if (ITEM.SUB_NESTER) then
			num_to_move = num_to_move + ITEM.SUB_NESTER.descendant_count;	-- and my kids
		end
		local SCROLLER = ITEM.PARENT_NESTER.PARENT_LIST.SCROLLER;
		for i=1, num_to_move do
			local src_idx;
			if (delta_pos > 0) then
				-- shifting down; start from the bottom, shuffle up
				src_idx = current_pos + num_to_move - i;
			else
				-- shifting up; start from the top, shuffle down
				src_idx = current_pos + i-1;
			end
			local ROW = SCROLLER:GetRow(src_idx);
			ROW:MoveTo(src_idx + delta_pos, ...);
		end
	end
end

function ITEM_API.Remove(ITEM)
	ITEM:Clear();	
	ITEM.PARENT_NESTER:UnregisterItem(ITEM);
	ITEM.ROW:Remove();	-- will recycle STYLEMENT
	if (ITEM.SUB_NESTER) then
		ITEM.SUB_NESTER:Remove();
	end
	ITEM.DISPATCHER:Destroy();
	
	for k,v in pairs(ITEM) do
		ITEM[k] = nil;
	end
	
	setmetatable(ITEM, nil);
end

function ITEM_API.UpdateSize(ITEM, dims, dur)
	if (ITEM.is_expanded) then
		ITEM.ROW:UpdateSize(dims, dur);
	end
	if (dims) then
		ITEM.item_size = {width=dims.width or ITEM.item_size.width, height=dims.height or ITEM.item_size.height};
	else
		local WIDGET = ITEM.ROW:GetWidget();
		if (WIDGET) then
			ITEM.item_size = WIDGET:GetBounds();
		end
	end
end

function ITEM_API.Open(ITEM, ...)
	PRIVATE_ITEM_EnsureHasNester(ITEM);
	if (ITEM.SUB_NESTER:GetChildCount() <= 0) then
		--error(tostring(ITEM));
	end
	if (ITEM.STYLEMENT and ITEM.STYLEMENT.WIDGETS) then
		ITEM.STYLEMENT.WIDGETS.STATE:SetText("-");
	end
	return ITEM.SUB_NESTER:Open(true, ...);
end
function ITEM_API.Close(ITEM, ...)
	PRIVATE_ITEM_EnsureHasNester(ITEM);
	if (ITEM.STYLEMENT and ITEM.STYLEMENT.WIDGETS) then
		ITEM.STYLEMENT.WIDGETS.STATE:SetText("+");
	end
	return ITEM.SUB_NESTER:Open(false, ...);
end
function ITEM_API.IsOpen(ITEM, ...)
	return (ITEM.SUB_NESTER and ITEM.SUB_NESTER:IsOpen(...));
end

function ITEM_API.Show(ITEM, is_shown)
	local dur = 0.1;
	ITEM.is_shown = is_shown;
	if (ITEM.SUB_NESTER) then
		ITEM.SUB_NESTER:Show(is_shown);
	else
		if (ITEM.PARENT_NESTER:CanDisplay() and ITEM.PARENT_NESTER:IsOpen() and is_shown) then
			PRIVATE_ITEM_Expand(ITEM, dur);
		else
			PRIVATE_ITEM_Collapse(ITEM, dur);
		end
	end
end

function ITEM_API.CreateItem(ITEM, ...)
	PRIVATE_ITEM_EnsureHasNester(ITEM);
	return ITEM.SUB_NESTER:CreateItem(...);
end

function ITEM_API.Clear(ITEM)
	if (ITEM.SUB_NESTER) then
		while (ITEM.SUB_NESTER:GetChildCount() > 0) do
			ITEM.SUB_NESTER:GetChildAt(1):Remove();
		end
	end
end

function ITEM_API.GetChild(ITEM, ref)
	assert(ITEM.SUB_NESTER, "this item has no children.");
	if (type(ref) == "number") then
		return ITEM.SUB_NESTER:GetChildAt(ref);
	else
		for i=1, #ITEM.SUB_NESTER.child_ITEMS do
			local CHILD = ITEM.SUB_NESTER.child_ITEMS[i];
			if (CHILD.ROW:GetValue() == ref) then
				return CHILD;
			end
		end
	end
end

function ITEM_API.GetChildCount(ITEM)
	if (ITEM.SUB_NESTER) then
		return ITEM.SUB_NESTER:GetChildCount();
	else
		return 0;
	end
end

function ITEM_API.CreateStyledItem(ITEM, ...)
	PRIVATE_ITEM_EnsureHasNester(ITEM);
	return ITEM.SUB_NESTER:CreateStyledItem(...);
end

function PRIVATE_ITEM_EnsureHasNester(ITEM)
	if (not ITEM.SUB_NESTER) then
		ITEM.SUB_NESTER = PRIVATE_CreateNester(ITEM.PARENT_NESTER.PARENT_LIST, ITEM);
		-- add sub-list open/close toggle
		ITEM:AddHandler("OnMouseDown", function()
			if (ITEM.SUB_NESTER:IsOpen()) then
				if (ITEM.STYLEMENT) then
					System.PlaySound("Play_UI_Beep_27");
				end
				ITEM:Close();
			else
				if (ITEM.STYLEMENT) then
					System.PlaySound("Play_UI_Beep_26");
				end
				ITEM:Open();
			end
		end);
		if (ITEM.STYLEMENT and ITEM.STYLEMENT.WIDGETS) then
			PRIVATE_STYLEMENT_ShowListMode(ITEM.STYLEMENT, true);			
		end
		if (ITEM.STYLEMENT) then
			ITEM:AddHandler("OnMouseEnter", function()
				System.PlaySound("Play_UI_Login_Keystroke");
			end);
		end
	end
end

---------------------
-- STYLED API --
---------------------

function STYLED_API.TintBorder(ITEM, tint)
	local STYLEMENT = ITEM.STYLEMENT;
	STYLEMENT.border_color = tint;
	if (STYLEMENT.WIDGETS) then
		STYLEMENT.WIDGETS.PLATE:SetColor(tint);
	end
end

function STYLED_API.ColorLabel(ITEM, color)
	local STYLEMENT = ITEM.STYLEMENT;
	STYLEMENT.label_color = color;
	STYLEMENT.label_TextFormat = false;
	if (STYLEMENT.WIDGETS) then
		STYLEMENT.WIDGETS.LABEL:SetTextColor(color);
	end
end

function STYLED_API.SetLabel(ITEM, text)
	local STYLEMENT = ITEM.STYLEMENT;
	STYLEMENT.label_text = text;
	STYLEMENT.label_TextFormat = false;
	if (STYLEMENT.WIDGETS) then
		STYLEMENT.WIDGETS.LABEL:SetText(text);
		PRIVATE_UpdateLabelSize(STYLEMENT)
	end
end

function STYLED_API.SetTextFormat(ITEM, TF)
	local STYLEMENT = ITEM.STYLEMENT;
	if (TF) then
		STYLEMENT.label_TextFormat = TextFormat.Create(TF);
		STYLEMENT.label_text = false;
	else
		STYLEMENT.label_TextFormat = false;
	end
	if (STYLEMENT.WIDGETS) then
		TextFormat.Clear(STYLEMENT.WIDGETS.LABEL);
		if (TF) then
			TF:ApplyTo(STYLEMENT.WIDGETS.LABEL);
		end
		PRIVATE_UpdateLabelSize(STYLEMENT)
	end
end

function PRIVATE_UpdateLabelSize(STYLEMENT)
	local num_lines = STYLEMENT.WIDGETS.LABEL:GetNumLines()
	local line_height = STYLEMENT.WIDGETS.LABEL:GetLineHeight()
	local height = num_lines * line_height + 4
	STYLEMENT.WIDGETS.GROUP:SetDims("top:_; height:"..height)
	STYLEMENT.ITEM:UpdateSize()
end

function PRIVATE_RecycleStyledItem(STYLEMENT, should_be_active)
	local SPARES = STYLEMENT.ITEM.PARENT_NESTER.PARENT_LIST.spare_STYLEMENTS;
	local WIDGETS;

	if (should_be_active and not STYLEMENT.WIDGETS) then
		WIDGETS = SPARES[#SPARES];
		if (WIDGETS) then
			-- check out
			SPARES[#SPARES] = nil;
		else
			-- create
			WIDGETS = { GROUP = Component.CreateWidget(BP_STYLEMENT, STYLEMENT.ITEM.PARENT_NESTER.PARENT_LIST:GetContainer()) };
			WIDGETS.LABEL = WIDGETS.GROUP:GetChild("label");
			WIDGETS.STATE = WIDGETS.GROUP:GetChild("state");
			WIDGETS.PLATE = HoloPlate.Create(WIDGETS.GROUP:GetChild("plate"));
		end

		WIDGETS.GROUP:Show();
		STYLEMENT.WIDGETS = WIDGETS;
		STYLEMENT.ITEM:SetWidget(WIDGETS.GROUP);

		-- apply
		-- indent
		STYLEMENT.WIDGETS.GROUP:SetDims("left:"..(STYLEMENT.ITEM.PARENT_NESTER.generation * 10).."; right:_");

		if (STYLEMENT.WIDGETS) then
			STYLEMENT.WIDGETS.PLATE:SetColor(STYLEMENT.border_color or "#FFFFFF");
		end

		PRIVATE_STYLEMENT_ShowListMode(STYLEMENT, STYLEMENT.ITEM.SUB_NESTER);		

		if (STYLEMENT.label_TextFormat) then
			STYLEMENT.label_TextFormat:ApplyTo(STYLEMENT.WIDGETS.LABEL);
		else
			TextFormat.Clear(STYLEMENT.WIDGETS.LABEL);
			STYLEMENT.WIDGETS.LABEL:SetText(STYLEMENT.label_text or "nothing");
			PRIVATE_UpdateLabelSize(STYLEMENT)
			STYLEMENT.WIDGETS.LABEL:SetTextColor(STYLEMENT.label_color or "#FFFFFF");
		end

	elseif (not should_be_active and STYLEMENT.WIDGETS) then
		WIDGETS = STYLEMENT.WIDGETS;
		STYLEMENT.ITEM:SetWidget(nil);
		STYLEMENT.WIDGETS = false;

		if (#SPARES < MAX_SPARES) then
			-- check in
			SPARES[#SPARES+1] = WIDGETS;
			WIDGETS.GROUP:Hide();

		elseif (Component.IsWidget(WIDGETS.GROUP)) then
			-- too many spares; discard
			Component.RemoveWidget(WIDGETS.GROUP);
			SPARES.created = (SPARES.created or 0) - 1;			
		end
	end
end

-------------
-- PRIVATE --
-------------

function PRIVATE_ForwardFunc(src_func, param1)
	return function(self, ...)
		return src_func(param1, ...);
	end
end

function PRIVATE_ITEM_Expand(ITEM, dur)





	if (not ITEM.is_expanded) then
		ITEM.is_expanded = true;

		-- restore size
		ITEM.ROW:UpdateSize(ITEM.item_size, dur);
		if (ITEM.STYLEMENT and ITEM.ROW:IsVisible()) then
			PRIVATE_RecycleStyledItem(ITEM.STYLEMENT, true);
		end
	end
end

function PRIVATE_ITEM_Collapse(ITEM, dur)



	if (ITEM.is_expanded) then
		ITEM.is_expanded = false;
		 
		-- shrink to 0
		ITEM.ROW:UpdateSize({height=-ITEM.PARENT_NESTER.PARENT_LIST.SCROLLER:GetSpacing()}, dur);
		if (ITEM.SUB_NESTER) then
			Callback2.FireAndForget(PRIVATE_ITEM_RecheckRecycling, ITEM.SUB_NESTER, dur);
		end
	end
end

function PRIVATE_ITEM_RecheckRecycling(ITEM)
	-- recycle children in/out; used with a callback so that items can be hidden after an animation
	if (not ITEM.is_expanded and ITEM.STYLEMENT) then
		PRIVATE_RecycleStyledItem(ITEM.STYLEMENT, false);
	end
end

function PRIVATE_STYLEMENT_ShowListMode(STYLEMENT, is_list)
	local WIDGETS = STYLEMENT.WIDGETS;
	if (is_list) then
		WIDGETS.STATE:Show(true);
		WIDGETS.LABEL:SetDims(WIDGETS.LABEL:GetInitialDims());
		if (STYLEMENT.ITEM.SUB_NESTER.is_open) then
			WIDGETS.STATE:SetText("-");
		else
			WIDGETS.STATE:SetText("+");
		end
	else
		WIDGETS.STATE:Show(false);
		WIDGETS.LABEL:SetDims("left:3; right:_");
	end
end

function PRIVATE_GetFlatListPos(PARENT_NESTER, child_relative_pos)
	-- constrain
	assert(child_relative_pos > 0 and child_relative_pos <= PARENT_NESTER:GetChildCount()+1);
	
	-- find base pos of parent
	local parent_pos = 0;
	if (PARENT_NESTER.PARENT_ITEM) then
		parent_pos = PARENT_NESTER.PARENT_ITEM.ROW:GetIdx();
	end

	-- move past siblings (and their descendants)
	local offset_pos = 1;	-- after parent
	if (child_relative_pos > 1) then
		for i=1, child_relative_pos-1 do
			local ITEM = PARENT_NESTER:GetChildAt(i);
			if (ITEM) then
				offset_pos = offset_pos + 1;	-- after siblings
				if (ITEM.SUB_NESTER) then
					offset_pos = offset_pos + ITEM.SUB_NESTER.descendant_count;	-- and their descendants
				end
			end
		end
	end

	return (parent_pos + offset_pos);
end
