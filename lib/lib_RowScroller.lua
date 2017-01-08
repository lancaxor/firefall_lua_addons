
-- ------------------------------------------
-- lib_RowScroller
--   by: John Su
-- creates a window that can scroll between rows
-- ------------------------------------------

--[[ Usage:
	SCROLLER = RowScroller.Create(PARENT)		-- creates a SCROLLER object
													[PARENT] is either a frame or a widget
	SCROLLER:Destroy()							-- removes this object
	
	SCROLLER:SetSlider(SLIDER[, GROUP])			-- designates the [SLIDER] widget for the scroller; can be replaced with RowScroller.SLIDER_DEFAULT to make a new one
													if the default is not used, and [GROUP] is specified, [GROUP] is fostered into the SCROLLER
													otherwise the [SLIDER] itself is fostered
	SCROLLER:ShowSlider(visible)				-- if [visible] is true or false, that will set the visibility of the slider
													if [visible] is "auto", it will show/hide itself as necessary (default state)
	SCROLLER:SetSliderMargin(max_margin, min_margin) -- sets the margin that is set aside for the slider when it appears (max_margin) and disappears (min_margin)
	SCROLLER:ShowSliderOnLeft(left)				-- sets the scroller to show on the left or not
	bool = SCROLLER:IsScrollable()				-- returns true if the body is larger then the container and therefore scrollable
	
	SCROLLER:SetScrollStep(px)					-- how many pixels to scroll per turn of the mouse wheel (default: RowScroller.DEFAULT_SCROLL_STEP)
	SCROLLER:ScrollSteps(delta)					-- simulate a mouse scroll
													
	SCROLLER:SetSpacing(px)						-- set the spacing between rows (defaults to RowScroller.DEFAULT_SPACING)
	px = SCROLLER:GetSpacing()					-- get the spacing between rows
	
	count = SCROLLER:GetRowCount()				-- gets the number of rows in the SCROLLER
	SCROLLER:ClipChildren(boolean)				-- sets whether the scroller should clip the rows at the top and bottom of the container; default true
														note any rows that are fully scoped out will always be hidden
	SCROLLER:UpdateSize([dims, dur])			-- updates the scroller (so the slider can resize) according to [dims] over [dur] seconds (default 0)
													[dims] should be a table optional fields .width and .height; if either (or both) are missing, current dims are used

	SCROLLER:LockUpdates()						-- prevents SCROLLER from updating rows (will stack; useful for if adding/removing many entries at once)
	SCROLLER:UnlockUpdates()					-- allows SCROLLER to update rows again (will stack; use when finished adding/removing many entries)
	
	WIDGET = SCROLLER:GetContainer()			-- returns the container widget
	{width, height} = SCROLLER:GetContentSize()	-- returns the maximum width and cumulative height of all rows
	SCROLLER:ScrollToPercent(pct, dur)			-- scrolls [pct]% of the way down (0-1) over [dur] seconds (defaults to RowScroller.SCROLL_DUR)
	SCROLLER:ScrollToRow(row_idx, dur)			-- scrolls so that the row is at the top, over [dur] seconds (defaults to RowScroller.SCROLL_DUR)
													[row_idx] can be either an integer or the WIDGET used to add the row
	pct = SCROLLER:GetScrollPercent()			-- get how far the SCROLLER has been scrolled (0-1)
	idx = SCROLLER:GetScrollIndex()				-- get the index of the row that is at the top of the SCROLLER (may be a fraction)
	
	SCROLLER also employs an EventDispatcher (see lib_EventDispatcher), and dispatches the following events:
	
		"OnScroll"		: the mouse has been scrolled
		"OnScrollTo"	: when the Scroller's position is adjusted; returns with args {pct, idx}
		"OnScrollHeightChanged"		: the scrollable area has changed with args {height, hidden} (both in pixels)
		"OnSliderShow"	: when the Scroller's slider appears or disappears; args = {visible}
		
	ROW = SCROLLER:AddRow([ref_val, insert_pos])	-- adds a row at [insert_pos] (defaults to bottom of row)
														ref_val can be any unique table index; if it is a WIDGET, it is automatically fostered and matches its bounds
														if ref_val is non-unique or is a number, ROW cannot be retrieved via SCROLLER:GetRow(ref_val)
														returns a ROW object
	ROW = SCROLLER:GetRow(ref_val/idx)				-- gets a ROW object by ref_val or by row index/position
	SCROLLER = ROW:GetScroller()					-- gets the ROW's owning SCROLLER
	
	ROW:SetWidget(WIDGET)						-- fosters a WIDGET into the ROW
	ref_val = ROW:GetValue()					-- get the ROW's ref_val which it was created with
	ROW:MoveTo(new_idx[, dur])							-- repositions a row to a new position [new_idx]
	ROW:ClipChildren(boolean)					-- sets whether the row should clip its contents; default true
	ROW:UpdateSize([dims, dur])					-- updates the spacing in the SCROLLER according to the [dims] (table with .width and .height)
													if [dims] or one of its field is unspecified, the fostered WIDGET's current bounds are used
													arrangement occurs over [dur] seconds (default 0)
	{width, height} = ROW:GetSize()				-- returns the ROW's current size
	pos = ROW:GetTop()							-- gets the top position of the ROW
	idx = ROW:GetIdx()							-- gets the row's index, in case you forgot it
	ROW:Remove()								-- removes the ROW from its SCROLLER; the reference becomes invalid
	is_visible = ROW:IsVisible()				-- returns true if any part of the ROW is within the viewable window
	
	SCROLLER:Reset()							-- clears out all ROW's; will fire "OnRemoved" events as the row is destroyed
	
	ROW also employs an EventDispatcher (see lib_EventDispatcher), and dispatches the following events:
	
		"OnMouseEnter"		: the mouse has hovered over this ROW
		"OnMouseLeave"		: the mouse has left this ROW
		"OnMouseDown"		: the mouse has been clicked; left button
		"OnMouseUp"			: the mouse has been released; left button
		"OnRightMouse"		: the mouse has been clicked; right button
		"OnScoped"			: the ROW has either entered or left the viewable window (args.visible = boolean; 'true' = visible)
		"OnRemoved"			: the ROW has been removed, either manually or orphaned by its resetting SCROLLER
--]]

RowScroller = {};
local lf = {}

require "math";
require "lib/lib_EventDispatcher";
require "lib/lib_Callback2";
require "lib/lib_Liaison";

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
RowScroller.SLIDER_DEFAULT = {};
RowScroller.DEFAULT_SPACING = 3;
RowScroller.DEFAULT_SCROLL_STEP = 20;
RowScroller.SCROLL_DUR = 0.15;

local SCROLLER_API = {};
local SCROLLER_METATABLE = {
	__index = function(t,key) return SCROLLER_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in SCROLLER"); end
};

local ROW_API = {};
local ROW_ZERO = {idx=0, top=0, width=0, height=0};	-- fake row that "occupies" idx 0

-- ------------------------------------------
-- BLUEPRINTS --
-- ------------------------------------------
local bp_Scroller = [[<Group dimensions="dock:fill" style="clip-children:true">
		<FocusBox name="focus" dimensions="dock:fill" style="tabbable:false">
			<Group name="entries" dimensions="left:0; right:100%; top:0; bottom:100%"/>
			<Group name="slider" dimensions="right:100%; width:20; top:0; bottom:100%" style="visible:false"/>
		</FocusBox>
	</Group>]];
	
local bp_DefaultSlider = [[<Group dimensions="right:100%; width:21; top:0; bottom:100%">
		<StillArt name="back" dimensions="dock:fill" style="texture:Slider; region:back_v; ywrap:21"/>
		<Slider name="slider" dimensions="center-x:50%; width:66%; top:0; bottom:100%" style="tabbable:false"/>
	</Group>]];
	
local bp_Row = [[<FocusBox dimensions="dock:fill" style="clip-children:true; tabbable:false"/>]];

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_FosterRegistry = {};	-- g_FosterRegistry[CHILD_WIDGET] = owning_ROW; This is used to keep track of who's *supposed* to have the widget; "Latest is greatest"

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function RowScroller.Create(PARENT)
	local SCROLLER = {};
	
		SCROLLER.GROUP = Component.CreateWidget(bp_Scroller, PARENT);
		SCROLLER.FOCUS = SCROLLER.GROUP:GetChild("focus");
		SCROLLER.CONTAINER = SCROLLER.GROUP;
		SCROLLER.ROWS = {
			GROUP = SCROLLER.FOCUS:GetChild("entries"),
			[0] = ROW_ZERO,
			-- [idx] = [WIDGET] = ROW
		};
		SCROLLER.EVENT_DISPATCHER = EventDispatcher.Create(SCROLLER);
		SCROLLER.SLIDER = {
			GROUP = SCROLLER.FOCUS:GetChild("slider"),
			max_margin = 21,
			min_margin = 0,
			-- CONTAINER_WIDGET = nil
			-- SLIDER_WIDGET = nil
			should_show = false,
			visibility = "auto",	-- true/"auto"/false
			is_default = false,
			left_align = false,
		}
		
		SCROLLER.spacing = RowScroller.DEFAULT_SPACING;
		SCROLLER.scroll_height = 0;
		SCROLLER.scroll_steps = RowScroller.DEFAULT_SCROLL_STEP;
		SCROLLER.scroll_pct = 0;
		SCROLLER.scroll_idx = 0;
		SCROLLER.content_dims = {width=0, height=0};
		SCROLLER.container_dims = SCROLLER.CONTAINER:GetBounds();
		SCROLLER.cb_Scrolling = Callback2.Create()
		SCROLLER.cb_Scrolling:Bind(function() end)	--we don't need to do anything here as all we care about is if this is pending or not
		SCROLLER.scope_offsets = {top=0, bottom=0};
		SCROLLER.clip_children = true

		SCROLLER.update_locks = 0;
		SCROLLER.update_dirty = false;
		SCROLLER.update_from_idx = false;	-- which rows need to be updated (form there to end)
		SCROLLER.unlock_dur = 0;			-- duration over which to animate the unlock when it happens

		SCROLLER.recyled_ROWS = {};	-- recycling widgets made from bp_Row
		SCROLLER.HIDDEN_FOSTER = Component.CreateWidget('<Group dimensions="dock:fill" style="visible:false"/>', Liaison.GetFrame());	-- hidden group to hold on to fosters when recycling their rows
		Component.FosterWidget(SCROLLER.HIDDEN_FOSTER, SCROLLER.GROUP, "dims");	-- inherit the dims so that the childrens' bounds look the same
		
	-- bind scrolls on main focus
	SCROLLER.FOCUS:BindEvent("OnScroll", function(args)
		SCROLLER:OnScroll(args)
	end);
	
	SCROLLER.EVENT_DISPATCHER:Delegate(SCROLLER);
	
	setmetatable(SCROLLER, SCROLLER_METATABLE);
	
	return SCROLLER;
end

-- ------------------------------------------
-- SCROLLER API
-- ------------------------------------------
function SCROLLER_API.Destroy(SCROLLER)
	SCROLLER:Reset();
	Component.RemoveWidget(SCROLLER.GROUP);
	SCROLLER.EVENT_DISPATCHER:Destroy();
	SCROLLER.cb_Scrolling:Release()
	for k,v in pairs(SCROLLER) do
		SCROLLER[k] = nil;
	end
	setmetatable(SCROLLER, nil);
end

function SCROLLER_API.Reset(SCROLLER)
	SCROLLER:LockUpdates();
	while (#SCROLLER.ROWS > 0) do
		-- destroy from back to front, to reduce re-indexing times
		SCROLLER.ROWS[#SCROLLER.ROWS]:Remove();
	end
	SCROLLER:UnlockUpdates();
end

function SCROLLER_API.OnScroll(SCROLLER, args)
	if (SCROLLER.scroll_height > 0) then
		SCROLLER:ScrollSteps(args.amount);
	end
	SCROLLER:DispatchEvent("OnScroll", args);
end

function SCROLLER_API.SetScrollStep(SCROLLER, px)
	SCROLLER.scroll_steps = px or RowScroller.DEFAULT_SCROLL_STEP;
	if (SCROLLER.SLIDER.SLIDER_WIDGET) then
		SCROLLER.SLIDER.SLIDER_WIDGET:SetScrollSteps(px);
	end
end

function SCROLLER_API:ShowSliderOnLeft(left)
	self.SLIDER.left_align = left
	if left then
		self.SLIDER.GROUP:SetDims("left:1; top:_; width:_; height:_")
	else
		self.SLIDER.GROUP:SetDims("right:100%; top:_; width:_; height:_")
	end
end

function SCROLLER_API.ScrollSteps(SCROLLER, delta)
	if (SCROLLER.scroll_steps > 0 and SCROLLER.scroll_height > 0) then
		local new_pct = SCROLLER.scroll_pct + delta*SCROLLER.scroll_steps/SCROLLER.scroll_height;
		SCROLLER:ScrollToPercent(math.max(0, math.min(new_pct, 1)), 0);
		SCROLLER:DispatchEvent("OnScroll", {amount=delta});
	end
end

function SCROLLER_API.SetSlider(SCROLLER, SLIDER, GROUP)
	assert(not SCROLLER.SLIDER.SLIDER_WIDGET, "slider already set");
	if (SLIDER == RowScroller.SLIDER_DEFAULT) then
		SCROLLER.SLIDER.CONTAINER_WIDGET = Component.CreateWidget(bp_DefaultSlider, SCROLLER.SLIDER.GROUP);
		SCROLLER.SLIDER.SLIDER_WIDGET = SCROLLER.SLIDER.CONTAINER_WIDGET:GetChild("slider");
		SCROLLER.SLIDER.SLIDER_WIDGET:SetScrollSteps(SCROLLER.scroll_steps);
	else
		SCROLLER.SLIDER.CONTAINER_WIDGET = GROUP or SLIDER;
		SCROLLER.SLIDER.SLIDER_WIDGET = SLIDER;
		Component.FosterWidget(SCROLLER.SLIDER.CONTAINER_WIDGET, SCROLLER.SLIDER.GROUP, "full");
	end
	
	SCROLLER.SLIDER.SLIDER_WIDGET:BindEvent("OnStateChanged", function()
		SCROLLER:ScrollToPercent(SCROLLER.SLIDER.SLIDER_WIDGET:GetParam("percent"), 0);
	end)
end

function SCROLLER_API.ShowSlider(SCROLLER, visibility)
	if (visibility ~= SCROLLER.SLIDER.visibility) then
		SCROLLER.SLIDER.visibility = visibility;
		if (visibility == "auto") then
			lf.Scroller_DirectShowSlider(SCROLLER, SCROLLER.SLIDER.should_show);
		elseif (visibility) then
			lf.Scroller_DirectShowSlider(SCROLLER, true);
		else
			lf.Scroller_DirectShowSlider(SCROLLER, false);
		end
	end
end

function SCROLLER_API.IsScrollable(SCROLLER)
	return SCROLLER.SLIDER.should_show
end

function SCROLLER_API.SetSliderMargin(SCROLLER, max_margin, min_margin)
	SCROLLER.SLIDER.max_margin = max_margin or SCROLLER.SLIDER.max_margin;
	SCROLLER.SLIDER.min_margin = min_margin or SCROLLER.SLIDER.min_margin;
	if (SCROLLER.SLIDER.GROUP:IsVisible()) then
		if SCROLLER.SLIDER.left_align then
			SCROLLER.ROWS.GROUP:SetDims("right:100%; left:"..SCROLLER.SLIDER.max_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("right:100%; left:"..SCROLLER.SLIDER.max_margin);
		else
			SCROLLER.ROWS.GROUP:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.max_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.max_margin);
		end
	else
		if SCROLLER.SLIDER.left_align then
			SCROLLER.ROWS.GROUP:SetDims("right:100%; left:"..SCROLLER.SLIDER.min_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("right:100%; left:"..SCROLLER.SLIDER.min_margin);
		else
			SCROLLER.ROWS.GROUP:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.min_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.min_margin);
		end
	end
end

function SCROLLER_API.SetSpacing(SCROLLER, px)
	if (px ~= SCROLLER.spacing) then
		SCROLLER.content_dims.height = SCROLLER.content_dims.height + #SCROLLER.ROWS * (px - SCROLLER.spacing);
		SCROLLER.spacing = px;
		for i=1, #SCROLLER.ROWS do
			lf.Row_UpdatePos(SCROLLER.ROWS[i], 0);
		end
	end
	lf.Scroller_RecalcScrollingHeight(SCROLLER);
	lf.Scroller_UpdateRowScopes(SCROLLER, dur);
end

function SCROLLER_API.GetSpacing(SCROLLER)
	return SCROLLER.spacing;
end

function SCROLLER_API.AddRow(SCROLLER, ref_val, insert_pos)
	local ROW = ROW_API.Create(ref_val, SCROLLER);
	if (insert_pos and insert_pos ~= ROW.idx) then
		ROW:MoveTo(insert_pos);
	else
		lf.Row_UpdatePos(ROW, 0);
	end
	SCROLLER.content_dims.height = SCROLLER.content_dims.height + ROW.height + SCROLLER.spacing;
	lf.Scroller_UpdateRows(SCROLLER, ROW.idx, 0);
	return ROW;
end

function SCROLLER_API.RemoveRow(SCROLLER, row_idx)
	local ROW = SCROLLER.ROWS[row_idx];
	if (ROW) then
		ROW:Remove();
	end
end

function SCROLLER_API.GetRow(SCROLLER, row_ref)
	assert(row_ref, "invalid reference");
	return SCROLLER.ROWS[row_ref];
end

function SCROLLER_API.GetRowCount(SCROLLER)
	return #SCROLLER.ROWS;
end

function SCROLLER_API.ClipChildren(SCROLLER, bool)
	bool = not (bool == false) --treats nil as true
	SCROLLER.clip_children = bool
	SCROLLER.GROUP:SetClipChildren(bool)
end

function SCROLLER_API.UpdateSize(SCROLLER, dims, dur)
	if (not dims) then
		dims = SCROLLER.CONTAINER:GetBounds();
	end
	SCROLLER.container_dims = dims;
	lf.Scroller_RecalcScrollingHeight(SCROLLER);
	lf.Scroller_UpdateRowScopes(SCROLLER, dur);
end

function SCROLLER_API.GetContainer(SCROLLER)
	return SCROLLER.CONTAINER;
end

function SCROLLER_API.GetContentSize(SCROLLER)
	return {width=SCROLLER.content_dims.width, height=SCROLLER.content_dims.height};
end

function SCROLLER_API.ScrollToPercent(SCROLLER, pct, dur, ...)
	assert(0 <= pct and pct <= 1)
	SCROLLER.scroll_pct = pct;
	dur = dur or RowScroller.SCROLL_DUR;
	local scroll_height = math.max(0, SCROLLER.scroll_height);
	local offset = pct * scroll_height;
	
	-- update scroll_idx
	SCROLLER.scroll_idx = lf.Scroller_FindRowIdxAtPos(SCROLLER, offset, SCROLLER.scroll_idx);
	
	lf.Scroller_ScrollTo(SCROLLER, offset, SCROLLER.scroll_pct, dur, ...)
	
	SCROLLER:DispatchEvent("OnScrollTo", {idx=SCROLLER.scroll_idx, pct=SCROLLER.scroll_pct});
end

function SCROLLER_API.ScrollToRow(SCROLLER, row_idx, dur, ...)
	local ROW = SCROLLER.ROWS[row_idx];
	dur = dur or RowScroller.SCROLL_DUR;
	if (not ROW and type(row_idx) == "number") then
		ROW = SCROLLER.ROWS[math.floor(row_idx)];
	end
	assert(ROW, "not a row of this scroller");
	SCROLLER.scroll_idx = ROW.idx;
	local scroll_height = SCROLLER.scroll_height;
	local offset = ROW.top;
	if (offset > scroll_height) then
		-- constrain
		SCROLLER.scroll_idx = lf.Scroller_FindRowIdxAtPos(SCROLLER, offset, SCROLLER.scroll_idx);
		offset = scroll_height;
	end
	if (type(row_idx) == "number") then
		offset = offset + ROW.height * (row_idx%1);
	end
	if (scroll_height > 0) then
		SCROLLER.scroll_pct = offset / scroll_height;
	else
		SCROLLER.scroll_pct = 0;
	end
	
	lf.Scroller_ScrollTo(SCROLLER, offset, SCROLLER.scroll_pct, dur, ...)
	
	SCROLLER:DispatchEvent("OnScrollTo", {idx=SCROLLER.scroll_idx, pct=SCROLLER.scroll_pct});
end

function SCROLLER_API.GetScrollPercent(SCROLLER)
	return SCROLLER.scroll_pct;
end

function SCROLLER_API.GetScrollIndex(SCROLLER)
	return SCROLLER.scroll_idx;
end

function SCROLLER_API.LockUpdates(SCROLLER)
	SCROLLER.update_locks = SCROLLER.update_locks + 1;
end

function SCROLLER_API.UnlockUpdates(SCROLLER)
	SCROLLER.update_locks = SCROLLER.update_locks - 1;
	if (SCROLLER.update_locks < 0) then
		warn("More unlocks than locks on SCROLLER");
	end
	if (SCROLLER.update_locks <= 0 and SCROLLER.update_dirty) then
		SCROLLER.update_dirty = false;
		-- SCROLLER		
		lf.Scroller_UpdateRows(SCROLLER, nil, SCROLLER.unlock_dur);
	end
end

-- ------------------------------------------
-- ROW API
-- ------------------------------------------
function ROW_API.Create(ref_val, SCROLLER)
	local bounds = {width=0, height=0};
	local WIDGET = false;
	if (ref_val and Component.IsWidget(ref_val)) then
		WIDGET = ref_val;
		bounds = WIDGET:GetBounds();
	end
	local ROW = {
		ref_val = ref_val,
		GROUP = nil,	-- is a focus box; to be created when it scopes in
		WIDGET = WIDGET,
		SCROLLER = SCROLLER,
		DISPATCHER = nil,
		idx = #SCROLLER.ROWS+1,
		top = 0,
		width = bounds.width,
		height = bounds.height,
		clip_children = true,
		is_scoped = false,
	};
	if (WIDGET) then
		lf.Row_UpdateFostery(ROW, WIDGET, true);
		Component.FosterWidget(WIDGET, ROW.GROUP or ROW.SCROLLER.HIDDEN_FOSTER);
	end

	-- Event forwarding	
	ROW.DISPATCHER = EventDispatcher.Create(ROW);
	ROW.DISPATCHER:Delegate(ROW);
	
	for k,v in pairs(ROW_API) do
		ROW[k] = v;
	end
	
	-- register
	SCROLLER.ROWS[ROW.idx] = ROW;
	if (ref_val and type(ref_val) ~= "number" and not SCROLLER.ROWS[ref_val]) then
		SCROLLER.ROWS[ref_val] = ROW;
	end
	
	return ROW;
end

function ROW_API.Remove(ROW)
	local SCROLLER = ROW.SCROLLER;
	local row_idx = ROW.idx;
	if (SCROLLER.scroll_idx >= row_idx) then
		SCROLLER.scroll_idx = SCROLLER.scroll_idx-1;
	end
	lf.Row_Remove(ROW);
	lf.Scroller_UpdateRows(SCROLLER, row_idx, dur);
end

function ROW_API.SetWidget(ROW, WIDGET)
	if (ROW.WIDGET) then
		-- unfoster
		lf.Row_PracticeFoster(ROW, ROW.WIDGET, false);
		lf.Row_UpdateFostery(ROW, WIDGET, false);
		ROW.WIDGET = false;
	end
	if (WIDGET) then
		assert(Component.IsWidget(WIDGET));
		lf.Row_UpdateFostery(ROW, WIDGET, true);
		Component.FosterWidget(WIDGET, ROW.GROUP or ROW.SCROLLER.HIDDEN_FOSTER);
		ROW.WIDGET = WIDGET;
	end
end

function ROW_API.GetWidget(ROW)
	return ROW.WIDGET;
end

function ROW_API.GetValue(ROW)
	return ROW.ref_val;
end

function ROW_API.IsVisible(ROW)
	return ROW.is_scoped;
end

function ROW_API.UpdateSize(ROW, dims, dur)
	dur = dur or 0;
	local SCROLLER = ROW.SCROLLER;
	assert(SCROLLER, "not a valid ROW");
	if (not dims and ROW.WIDGET) then
		dims = ROW.WIDGET:GetBounds();
	else
		dims = dims or {};
		-- inherit previous values
		dims.width = dims.width or ROW.width;
		dims.height = dims.height or ROW.height;
	end
	local dims_dirty = false
	if (ROW.width ~= dims.width) then
		if (dims.width > SCROLLER.content_dims.width) then
			-- the new max width
			SCROLLER.content_dims.width = dims.width;
		elseif (ROW.width == SCROLLER.content_dims.width) then
			-- was the old max width; find the new one!
			ROW.width = dims.width;
			lf.Scroller_RecalcMaxWidth(SCROLLER)
		end
		ROW.width = dims.width;
		dims_dirty = true
	end
	local row_idx = nil;
	if (ROW.height ~= dims.height) then
		row_idx = ROW.idx;
		-- update cumulative height
		SCROLLER.content_dims.height = SCROLLER.content_dims.height + (dims.height - ROW.height);
		ROW.height = dims.height;
		if (ROW.GROUP) then
			if (ROW.height > 0) then
				ROW.GROUP:Show(true);
			else
				ROW.GROUP:Show(false, dur);
			end
		end
		dims_dirty = true
	end
	if dims_dirty then
		lf.Scroller_UpdateRows(SCROLLER, row_idx, dur);
	end
end

function ROW_API.GetSize(ROW)
	return {width=ROW.width, height=ROW.height};
end

function ROW_API.GetTop(ROW)
	return ROW.top;
end

function ROW_API.GetIdx(ROW)
	return ROW.idx;
end

function ROW_API.GetScroller(ROW)
	return ROW.SCROLLER;
end

function ROW_API.ClipChildren(ROW, bool)
	bool = not (bool == false) --treats nil as true
	ROW.clip_children = bool
	if ROW.GROUP then
		ROW.GROUP:SetClipChildren(bool)
	end
end

function ROW_API.MoveTo(ROW, new_idx, dur)
	local SCROLLER = ROW.SCROLLER;
	assert(SCROLLER, "not a valid ROW");
	assert(new_idx > 0 and new_idx <= #SCROLLER.ROWS, "new index out of bounds");
	local start_idx = math.min(ROW.idx, new_idx);
	local end_idx = math.max(ROW.idx, new_idx);
	table.remove(SCROLLER.ROWS, ROW.idx);
	table.insert(SCROLLER.ROWS, new_idx, ROW);
	dur = dur or 0;	
	if (start_idx <= end_idx) then
		local rows_locked = (SCROLLER.update_locks > 0);
		for i=start_idx, end_idx do
			-- reposition and re-index
			local ROW = SCROLLER.ROWS[i];
			ROW.idx = i;
			if (not rows_locked) then
				lf.Row_UpdatePos(ROW, dur);
			end
		end
		if (rows_locked) then
			-- don't call this if unlocked, since half its work was already done in lf.Row_UpdatePos
			lf.Scroller_UpdateRows(SCROLLER, start_idx, dur);
		else
			-- finish the other half of the update
			lf.Scroller_UpdateRowScopes(SCROLLER, dur);
		end
	end
end

-- ------------------------------------------
-- LOCAL SCROLLER FUNCTIONS
-- ------------------------------------------
function lf.Scroller_ScrollTo(SCROLLER, offset, pct, dur, ...)
	if dur <= 0 then
		SCROLLER.ROWS.GROUP:SetDims("top:"..(-offset).."; height:100%");
	else
		SCROLLER.ROWS.GROUP:MoveTo("top:"..(-offset).."; height:100%", dur, ...);
	end
	if (SCROLLER.SLIDER.SLIDER_WIDGET) then
		local cur_pct = SCROLLER.SLIDER.SLIDER_WIDGET:GetParam("percent");
		if cur_pct ~= pct then
			if dur <= 0 then
				SCROLLER.SLIDER.SLIDER_WIDGET:SetParam("percent", pct);
			else
				SCROLLER.SLIDER.SLIDER_WIDGET:ParamTo("percent", pct, dur, ...);
			end
		end
	end
	lf.Scroller_UpdateRowScopes(SCROLLER, dur);
	
	if dur and dur > 0 then
		SCROLLER.cb_Scrolling:Reschedule(dur)
	end
end

function lf.Scroller_RecalcMaxWidth(SCROLLER)
	SCROLLER.content_dims.width = 0;
	if (#SCROLLER.ROWS > 0) then
		for i = 1, #SCROLLER.ROWS do
			SCROLLER.content_dims.width = math.max(SCROLLER.content_dims.width, SCROLLER.ROWS[i].width);
		end
	end
end

function lf.Scroller_RecalcScrollingHeight(SCROLLER)
	local scroll_height = (SCROLLER.content_dims.height - SCROLLER.container_dims.height);
	if (scroll_height ~= SCROLLER.scroll_height) then
		SCROLLER.scroll_height = scroll_height;
		SCROLLER.SLIDER.should_show = scroll_height > 0;
		if (SCROLLER.SLIDER.should_show) then
			if (SCROLLER.SLIDER.visibility == "auto") then
				lf.Scroller_DirectShowSlider(SCROLLER, true);
			end
			
			if (SCROLLER.SLIDER.SLIDER_WIDGET) then
				SCROLLER.SLIDER.SLIDER_WIDGET:SetSteps(scroll_height);
				--SCROLLER.SLIDER.SLIDER_WIDGET:SetScrollSteps(SCROLLER.content_dims.height / #SCROLLER.ROWS);
				SCROLLER.SLIDER.SLIDER_WIDGET:SetJumpSteps(SCROLLER.container_dims.height);
				SCROLLER.SLIDER.SLIDER_WIDGET:SetParam("thumbsize", math.max(.2, SCROLLER.container_dims.height / SCROLLER.content_dims.height));
			end
			-- scroll to new bottom if necessary
			local current_scroll = -SCROLLER.ROWS.GROUP:GetDims(true).top.offset;
			if (current_scroll > scroll_height) then
				SCROLLER:ScrollToPercent(1);
			end
			-- maintain scroll percent, based on top index when not actively scrolling
			if not SCROLLER.cb_Scrolling:Pending() then
				local TOP_ROW = SCROLLER.ROWS[math.floor(SCROLLER.scroll_idx)];
				local offset = TOP_ROW.top + (TOP_ROW.height * (SCROLLER.scroll_idx%1));
				SCROLLER.scroll_pct = offset / scroll_height;
				if (SCROLLER.SLIDER.SLIDER_WIDGET) then
					SCROLLER.SLIDER.SLIDER_WIDGET:SetParam("percent", SCROLLER.scroll_pct);
				end
			end
		else
			if (SCROLLER.SLIDER.visibility == "auto") then
				lf.Scroller_DirectShowSlider(SCROLLER, false);
			end
			if (SCROLLER.SLIDER.SLIDER_WIDGET) then
				SCROLLER.SLIDER.SLIDER_WIDGET:SetSteps(0);
				SCROLLER.SLIDER.SLIDER_WIDGET:SetJumpSteps(SCROLLER.container_dims.height);
				SCROLLER.SLIDER.SLIDER_WIDGET:SetParam("thumbsize", 1);
			end
			SCROLLER:ScrollToPercent(0);
		end
		SCROLLER:DispatchEvent("OnScrollHeightChanged", {height=SCROLLER.content_dims.height, hidden=scroll_height});
	end
end

function lf.Scroller_FindRowIdxAtPos(SCROLLER, pos, start_idx)
	-- gets row index at position in SCROLLER
	if pos < 0 or pos > SCROLLER.content_dims.height then
		error("Bad pos: 0 <= "..tostring(pos).." <= "..tostring(SCROLLER.content_dims.height))
	end
	start_idx = start_idx or SCROLLER.scroll_idx;
	local ROW = SCROLLER.ROWS[math.floor(start_idx)];
	assert(ROW, "invalid start_idx: "..start_idx.."/"..#SCROLLER.ROWS);
	while (ROW.top > pos) do
		-- seek upwards
		ROW = SCROLLER.ROWS[ROW.idx-1];
	end
	while (ROW.top + ROW.height + SCROLLER.spacing < pos) do
		-- seek downards
		ROW = SCROLLER.ROWS[ROW.idx+1];
	end
	-- fine seeking
	if (ROW.height + SCROLLER.spacing > 0) then
		return (ROW.idx + (pos - ROW.top) / (ROW.height + SCROLLER.spacing));
	else
		return ROW.idx;
	end
end

function lf.Scroller_UpdateRowScopes(SCROLLER, dur)
	local dims = SCROLLER.ROWS.GROUP:GetDims(true);
	local scope_top = SCROLLER.scope_offsets.top - dims.top.offset;
	local scope_bottom = SCROLLER.scope_offsets.bottom + SCROLLER.container_dims.height - dims.top.offset;

	for idx=1, #SCROLLER.ROWS do
		local ROW = SCROLLER.ROWS[idx];
		local is_scoped = ROW.height > 0 and ROW.top + ROW.height >= scope_top and ROW.top <= scope_bottom
		if (is_scoped ~= ROW.is_scoped) then
			ROW.is_scoped = is_scoped;
			if (is_scoped) then
				lf.Row_Recycle(ROW, true, dur);
			else
				if (not dur or dur <= 0) then
					lf.Row_Recycle(ROW, false);
				else
					Callback2.FireAndForget(function()
						if (ROW.SCROLLER and not ROW.is_scoped) then
							lf.Row_Recycle(ROW, false);
						end
					end, nil, dur);
				end
			end
		end
	end
end

function lf.Scroller_DirectShowSlider(SCROLLER, visible)
	if (visible == SCROLLER.SLIDER.GROUP:IsVisible()) then
		return;	-- no change
	end
	SCROLLER:DispatchEvent("OnSliderShow", {visible=visible});
	
	if (visible) then
		if (not SCROLLER.SLIDER.SLIDER_WIDGET) then
			-- use default
			SCROLLER:SetSlider(RowScroller.SLIDER_DEFAULT);
		end
		SCROLLER.SLIDER.GROUP:Show(true);
		-- make room for slider
		SCROLLER.ROWS.GROUP:FinishMove();
		if SCROLLER.SLIDER.left_align then
			SCROLLER.ROWS.GROUP:SetDims("right:100%; left:"..SCROLLER.SLIDER.max_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("right:100%; left:"..SCROLLER.SLIDER.max_margin);
		else
			SCROLLER.ROWS.GROUP:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.max_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.max_margin);
		end
	else
		SCROLLER.SLIDER.GROUP:Show(false);
		-- fill space
		SCROLLER.ROWS.GROUP:FinishMove();
		if SCROLLER.SLIDER.left_align then
			SCROLLER.ROWS.GROUP:SetDims("right:100%; left:"..SCROLLER.SLIDER.min_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("right:100%; left:"..SCROLLER.SLIDER.min_margin);
		else
			SCROLLER.ROWS.GROUP:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.min_margin);
			SCROLLER.HIDDEN_FOSTER:SetDims("left:0; right:100%-"..SCROLLER.SLIDER.min_margin);
		end
	end
end

function lf.Scroller_UpdateRows(SCROLLER, idx, dur)
	if (idx) then
		if (SCROLLER.update_from_idx) then
			SCROLLER.update_from_idx = math.min(SCROLLER.update_from_idx, idx);
		else
			SCROLLER.update_from_idx = idx;
		end
	end
	if (SCROLLER.update_locks > 0) then
		SCROLLER.update_dirty = true;
		SCROLLER.unlock_dur = dur or 0;
		return;
	else
		if (SCROLLER.update_from_idx and SCROLLER.update_from_idx <= #SCROLLER.ROWS) then
			-- reposition affected rows
			for i = SCROLLER.update_from_idx, #SCROLLER.ROWS do
				lf.Row_UpdatePos(SCROLLER.ROWS[i], dur);
			end
		end
		SCROLLER.update_dirty = false;
		SCROLLER.update_from_idx = false;
		SCROLLER.unlock_dur = 0;

		lf.Scroller_UpdateRowScopes(SCROLLER, dur);
		lf.Scroller_RecalcScrollingHeight(SCROLLER);
	end
end

-- ------------------------------------------
-- LOCAL ROW FUNCTIONS
-- ------------------------------------------
function lf.Row_UpdatePos(ROW, dur)
	local PREV_ROW = ROW.SCROLLER.ROWS[ROW.idx-1];
	ROW.top = PREV_ROW.top + PREV_ROW.height + ROW.SCROLLER.spacing;
	if (ROW.GROUP) then
		ROW.GROUP:MoveTo("top:"..ROW.top.."; height:"..ROW.height, dur);
	end
end

function lf.Row_Remove(ROW)
	local SCROLLER = ROW.SCROLLER;
	if (ROW.idx ~= #SCROLLER.ROWS) then
		-- move to the end before removing, so we don't leave a gap
		ROW:MoveTo(#SCROLLER.ROWS);
	end
	
	-- unregister
	if (ROW.ref_val and type(ROW.ref_val) ~= "number") then
		SCROLLER.ROWS[ROW.ref_val] = nil;
	end
	SCROLLER.ROWS[ROW.idx] = nil;
	lf.Row_Recycle(ROW, false);

	ROW.DISPATCHER:DispatchEvent("OnRemoved");
	ROW.DISPATCHER:Destroy();
	ROW.DISPATCHER = false;
	
	-- update content dims
	if (ROW.width == SCROLLER.content_dims.width) then
		lf.Scroller_RecalcMaxWidth(SCROLLER);
	end
	SCROLLER.content_dims.height = SCROLLER.content_dims.height - (ROW.height + SCROLLER.spacing);
	
	for k,v in pairs(ROW) do
		ROW[k] = nil;
	end
end

function lf.Row_Recycle(ROW, should_be_active, dur)
	dur = dur or 0
	local SPARES = ROW.SCROLLER.recyled_ROWS;

	if (should_be_active and not ROW.GROUP) then
		ROW.GROUP = SPARES[#SPARES];
		if (ROW.GROUP) then
			-- check it out
			SPARES[#SPARES] = nil;
		else
			-- make one
			ROW.GROUP = Component.CreateWidget(bp_Row, ROW.SCROLLER.ROWS.GROUP);
		end

		-- update position & fosters
		ROW.GROUP:SetClipChildren(ROW.clip_children)
		ROW.GROUP:Show( ROW.height > 0 );
		
		local PREV_ROW = ROW.SCROLLER.ROWS[ROW.idx-1];
		if PREV_ROW.GROUP and dur > 0 then
			local prev_dims = PREV_ROW.GROUP:GetDims(false)
			ROW.GROUP:SetDims("top:"..prev_dims.bottom.offset + ROW.SCROLLER.spacing.."; height:"..ROW.height);
			ROW.GROUP:MoveTo("top:"..ROW.top.."; height:"..ROW.height, dur);
		else
			ROW.GROUP:SetDims("top:"..ROW.top.."; height:"..ROW.height);
		end
		
		if (ROW.WIDGET) then
			-- change foster parent
			lf.Row_PracticeFoster(ROW, ROW.WIDGET, true);
		end

		-- bind functions
		local FOCUS = ROW.GROUP;
		FOCUS:BindEvent("OnMouseEnter", function()
			if ROW.DISPATCHER then
				ROW.DISPATCHER:DispatchEvent("OnMouseEnter");
			end
		end);
		FOCUS:BindEvent("OnMouseLeave", function()
			if ROW.DISPATCHER then
				ROW.DISPATCHER:DispatchEvent("OnMouseLeave");
			end
		end);
		FOCUS:BindEvent("OnMouseDown", function()
			if ROW.DISPATCHER then
				ROW.DISPATCHER:DispatchEvent("OnMouseDown");
			end
		end);
		FOCUS:BindEvent("OnMouseUp", function()
			if ROW.DISPATCHER then
				ROW.DISPATCHER:DispatchEvent("OnMouseUp");
			end
		end);
		FOCUS:BindEvent("OnRightMouse", function()
			if ROW.DISPATCHER then
				ROW.DISPATCHER:DispatchEvent("OnRightMouse");
			end
		end);
		
	elseif (not should_be_active and ROW.GROUP) then
		if (#SPARES < 16) then
			-- check it in
			SPARES[#SPARES+1] = ROW.GROUP;
			ROW.GROUP:Show(false);
		else
			-- or remove it entirely, if it's exessive
			Component.RemoveWidget(ROW.GROUP);
		end

		if (ROW.WIDGET and Component.IsWidget(ROW.WIDGET)) then
			-- change foster parent
			lf.Row_PracticeFoster(ROW, ROW.WIDGET, false);
		end
		ROW.GROUP = nil;
	end

	ROW.DISPATCHER:DispatchEvent("OnScoped", {visible=should_be_active});
end

function lf.Row_PracticeFoster(ROW, CHILD_WIDGET, is_practicing)
	-- to avoid foster wars, will only move CHILD if it's currently housed by the registered FOSTER PARENT
	local CURRENT_FOSTER = g_FosterRegistry[CHILD_WIDGET];
	if (CURRENT_FOSTER == ROW and Component.IsWidget(CHILD_WIDGET)) then
		if (is_practicing) then
			-- yes, we know this child ("come here")
			Component.FosterWidget(CHILD_WIDGET, ROW.GROUP);
		else
			-- sorry, we're not home ("go away")
			Component.FosterWidget(CHILD_WIDGET, ROW.SCROLLER.HIDDEN_FOSTER);
		end
	end
end

function lf.Row_UpdateFostery(ROW, CHILD_WIDGET, will_adopt)
	-- make it official in these records!
	if (will_adopt) then
		-- latest is greatest
		g_FosterRegistry[CHILD_WIDGET] = ROW;
	elseif (g_FosterRegistry[CHILD_WIDGET] == ROW) then
		-- make homeless only if in this home
		g_FosterRegistry[CHILD_WIDGET] = nil
	end
end
