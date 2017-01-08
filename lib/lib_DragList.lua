
--
-- lib_DragList
--	by: Michael Weschler
--
--	A List of items that can be dragged and reordered

--[[
		DRAGLIST = DragList.Create(PARENT) -- Creates a new drag list
		ROW = DRAGLIST:AddRow() -- Adds a new row to the list
		DRAGLIST:Reset() -- Removes all the rows from the list
		DRAGLIST:SetRowHeight(height, [dur]) -- Sets the height for all rows, will resize over a duration if provided
		DRAGLIST:EnableDrag([enabled]) -- Enables/disables dragging for rows
		DRAGLIST:UpdateSize([dur]) -- Refreshes the size of the list
		height = DRAGLIST:GetHeight() -- gets the height of the draglist
		DRAGLIST:Destroy() -- destroys the list and its rows
		DRAGLIST:LockTopTo(index) -- locks all rows from the top down to index
		
		DRAGLIST supports common widget methods(SetDims, Show, etc)
		DRAGLIST Dispatches the following events:
			OnReordered(from, to) -- when a row is moved from a positon to anouther
			
		--ROW API--
		ROW:SetWidget(WIDGET) -- sets the fostered widget to display
		ROW:Remove() -- removes this row from the list
		ROW:SetSize(bounds) -- sets the size of the row based on the bounds table(width/height)
		ROW:StartDrag() -- Starts dragging for this row
		index = ROW:GetIndex() -- gets the index of the row
		ROW:Lock([lock]) -- locks/unlocks the row from being moved
		ROW:Dispatches the following events:
			OnPositionChanged(position)
--]]

if DragList then
	return
end

DragList = {}
local lf = {}
local DL_API = {}
local ROW_API = {}

require "math"
require "lib/lib_EventDispatcher"

local BP_DL = [[<Group dimensions="dock:fill">
		<Group name="rows" dimensions="dock:fill"/>
		<Border name="highlight" dimensions="dock:fill" class="PanelSubBackDrop" style="alpha:0; tint:#c0c0c0"/>
	</Group>]]
local BP_ROW = [[<Group dimensions="dock:fill">
		<Border name="highlight" dimensions="dock:fill" class="ButtonBorder" style="alpha:0"/>
	</Group>]]
local BP_FRAME = [[<PanelFrame dimensions="dock:fill" topmost="true" depth="1"/>]]
local BP_SCREEN_WIDGET = [[<Group dimensions="dock:fill">
		<Group name="foster" dimensions="dock:fill"/>
		<FocusBox name="focus" dimensions="dock:fill"/>
		<Group name="drop_targets" dimensions="dock:fill"/>
	</Group>]]
	
-- ------------------------------------------
-- Variables
-- ------------------------------------------	

local g_DragRow = nil

-- ------------------------------------------
-- DL Interface
-- ------------------------------------------
local DragList_MT = {__index = function(self, key) return DL_API[key] end}

function DragList.Create(PARENT)
	local WIDGET = Component.CreateWidget(BP_DL, PARENT)
	local DL =
	{
		GROUP 				= WIDGET,
		ROW_GRP				= WIDGET:GetChild("rows"),
		HIGHLIGHT			= WIDGET:GetChild("highlight"),
		FRAME				= false,
		SCREEN_WIDGET 		= false,
		rows				= {},
		row_height			= 0,
		drag_start_index	= 0,
		height				= 0,
		drag_enabled		= true,
	}
	
	setmetatable(DL, DragList_MT)
	DL.DISPATCHER = EventDispatcher.Create(DL);
	DL.DISPATCHER:Delegate(DL)
	return DL
end

-- ------------------------------------------
-- BDL Object functions
-- ------------------------------------------

local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	DL_API[method_name] = function(DL, ...)
		return DL.GROUP[method_name](DL.GROUP, ...);
	end
end

function DL_API:AddRow()
	local ROW = ROW_API.CreateRow(self)
	table.insert(self.rows, ROW)
	self:UpdateSize()
	return ROW
end

function DL_API:Reset()
	for _, ROW in ipairs(self.rows) do
		ROW:Remove()
	end
	self.rows = {}
end

function DL_API:SetRowHeight(height, dur)
	assert(type(height)=="number")
	self.row_height = height
	self:UpdateSize(dur)
end

function DL_API:EnableDrag(enabled)
	if enabled == nil then
		enabled = true
	end
	self.drag_enabled = enabled 
	self:UpdateSize()
end

function DL_API:UpdateSize(dur)
	local height = 0
	for i, ROW in ipairs(self.rows) do
		local top = (i-1) *self.row_height
		
		if g_DragRow and g_DragRow:GetIndex() ~= self.drag_start_index then
			if i > self.drag_start_index or (g_DragRow:GetIndex() > self.drag_start_index and i >= self.drag_start_index) then
				top = top + self.row_height
			end
		end
		ROW:MoveTo("left:_; top:"..top.."; width:_; height:_", dur)
		height = height + self.row_height
	end
	local highlightOffset = self.drag_start_index - 1
	if g_DragRow and g_DragRow:GetIndex() < self.drag_start_index then
		highlightOffset = highlightOffset + 1
	end
	if self.drag_enabled then
		height = height + self.row_height
	end
	self.HIGHLIGHT:MoveTo("top:"..(highlightOffset * self.row_height).."; height:"..self.row_height, dur)
	self.GROUP:MoveTo("top:_; left:_; width:100%; height:"..height, dur)
	self.height = height
end

function DL_API:SwapRows(first, second)
	local firstRow = self.rows[first]
	local secondRow = self.rows[second]
	firstRow:SetIndex(second)
	secondRow:SetIndex(first)
	firstRow:DispatchEvent("OnPositionChanged", {position=second})
	secondRow:DispatchEvent("OnPositionChanged", {position=first})
	
	self.rows[second] = firstRow
	self.rows[first] = secondRow
end

function DL_API:GetHeight()
	return self.height
end

function DL_API:MoveRowTo(from, to)
	local lastPosition = from
	local direction = 1
	if from > to then
		direction = -direction
	end

	for i= from, to, direction do
		if i ~= lastPosition then
			self:SwapRows(lastPosition, i)
			lastPosition = i
		end
	end
	self:DispatchEvent("OnReordered", {from=from, to=to})
	self:UpdateSize(0.1)
	System.PlaySound("rollover")
end

function DL_API:SetHighlight(alpha, index)
	if index then
		self.HIGHLIGHT:SetDims("top:"..((index - 1) * self.row_height).."; height:"..self.row_height)
	end
	self.HIGHLIGHT:ParamTo("alpha", alpha, 0.1)
end

function DL_API:Destroy()
	self:Reset()
	self.DISPATCHER:Destroy()
end

function DL_API:LockTopTo(index)
	for i=1, index do 
		self.rows[i]:Lock()
	end
end

-- ------------------------------------------
-- BDL_ROW Object functions
-- ------------------------------------------

local DragListROW_MT = {__index = function(self, key) return ROW_API[key] end}
local Destroyed_MT = {__index = function(self, key) error("Object has been destroyed, cannot index") end}

for _, method_name in pairs(COMMON_METHODS) do
	ROW_API[method_name] = function(ROW, ...)
		return ROW.GROUP[method_name](ROW.GROUP, ...);
	end
end

function ROW_API.CreateRow(DL)
	local WIDGET = Component.CreateWidget(BP_ROW, DL.ROW_GRP)
	local ROW =
	{
		GROUP 		= WIDGET,
		HIGHLIGHT	= WIDGET:GetChild("highlight"),
		FOSTERED	= false,
		DL			= DL,
		index		= #DL.rows + 1,
		height		= 0,
	}
	
	setmetatable(ROW, DragListROW_MT)
	ROW.DISPATCHER = EventDispatcher.Create(ROW);
	ROW.DISPATCHER:Delegate(ROW)
	if ROW.index > 1 then
		local dims=DL.rows[ROW.index - 1]:GetDims()
		ROW:SetDims("left:0; top:"..dims.bottom.offset.."; width:_; height:_")
	end
	return ROW
end

function ROW_API:SetWidget(WIDGET)
	Component.FosterWidget(WIDGET, self.GROUP)
	self.FOSTERED = WIDGET
end

function ROW_API:Remove()
	table.remove(self.DL.rows, self.index)
	for i, ROW in ipairs(self.DL.rows) do
		ROW.index = i
	end
	Component.RemoveWidget(self.GROUP)
	setmetatable(self, Destroyed_MT)
end

function ROW_API:SetSize(bounds)
	assert(type(bounds)=="table" and bounds.height, "Expected a table with fields 'height'")
	self.GROUP:SetDims("top:0; left:0; width:100%; height:"..tostring(bounds.height))
	self.height = bounds.height
	self.DL:UpdateSize()
end

function ROW_API:StartDrag()
	if not self.DL.drag_enabled then
		return
	end
	
	if self.locked then
		return
	end
	
	local x, y = Component.GetCursorPos()
	self.DL.drag_start_index = self.index
	lf.SetupDragFrame(self.DL, self)
	Component.BeginDragDrop("row_index", tostring({index=self.index}))
	local bounds = self.GROUP:GetBounds()
	Component.FosterWidget(self.FOSTERED, self.DL.SCREEN_FOSTER)
	self.DL.SCREEN_FOSTER:SetDims("relative:cursor; left:"..(bounds.left-x).."; top:"..(bounds.top-y).."; width:"..bounds.width.."; height:"..bounds.height);
	self.DL:SetHighlight(0.20, self.index)
	g_DragRow = self
	g_DragRow:SetHighlight(1, "ui", 0.1)
	self.DL:DispatchEvent("OnDragStart")
end

function ROW_API:GetIndex()
	return self.index
end

function ROW_API:SetIndex(index)
	assert(type(index) == "number")
	self.index = index
end

function ROW_API:SetHighlight(alpha, tint, dur)
	self.HIGHLIGHT:ParamTo("alpha", alpha, dur)
	self.HIGHLIGHT:ParamTo("tint", tint, dur)
end

function ROW_API:Lock(lock)
	if lock == nil then
		lock = true
	end
	
	self.locked = lock
end

-- ------------------------------------------
-- local functions
-- ------------------------------------------

function lf.SetupDragFrame(DL)
	if DL.FRAME then
		warn("Attempted to create a Drag Frame when one already exists")
		return
	end
	
	DL.FRAME = Component.CreateFrame(BP_FRAME, "ScreenFrame")
	DL.FRAME:Show(true)
	DL.SCREEN_WIDGET = Component.CreateWidget(BP_SCREEN_WIDGET, DL.FRAME)
	DL.SCREEN_FOSTER = DL.SCREEN_WIDGET:GetChild("foster")
	DL.SCREEN_FOCUS = DL.SCREEN_WIDGET:GetChild("focus")
	DL.SCREEN_FOCUS:BindEvent("OnMouseUp", lf.EndDrag)
	DL.SCREEN_FOCUS:SetAsLastClickRecipient()
	lf.CreateDropTargets(DL)
end

function lf.CreateDropTargets(DL)
	local TARGET_GRP = DL.SCREEN_WIDGET:GetChild("drop_targets")
	local curX = Component.GetCursorPos()
	local listBounds = DL:GetBounds()
	for i, ROW in ipairs(DL.rows) do 
		if not ROW.locked then
			local rowBounds = ROW:GetBounds()
			local top = listBounds.top +((i-1) * DL.row_height)
			if DL.drag_start_index < i then
				top = top + (DL.row_height )
			end
			local DROP = Component.CreateWidget([[<DropTarget dimensions="left:]]..math.max((curX -rowBounds.width), 0)..[[; right:]]..(curX + rowBounds.width)..[[; top:]]..top..[[; bottom:]]..(top+DL.row_height)..[["/>]], TARGET_GRP)
			local dropIndex = ROW:GetIndex()
			DROP:SetAcceptTypes("row_index")
			DROP:BindEvent("OnDragEnter", function()
				if g_DragRow:GetIndex() ~= dropIndex then
					DL:MoveRowTo(g_DragRow:GetIndex(), dropIndex)
				end
			end)
			DROP:BindEvent("OnDragLeave", function()
			end)
			DROP:BindEvent("OnDragDrop", function()
				lf.EndDrag()
			end)
		end
	end
end

function lf.ClearFrame(DL)
	if not DL.FRAME then
		warn("Attempted to clear the frame when non exists")
		return
	end
	Component.RemoveWidget(DL.SCREEN_WIDGET)
	Component.RemoveFrame(DL.FRAME)
	DL.FRAME = false
	DL.SCREEN_WIDGET = false
	DL.SCREEN_FOCUS = false
end

function lf.EndDrag()
	local DL = g_DragRow.DL
	Component.FosterWidget(g_DragRow.FOSTERED, g_DragRow.GROUP)
	lf.ClearFrame(DL)
	DL:SetHighlight(0)
	g_DragRow:SetHighlight(0, "ui", 0.1)
	DL:DispatchEvent("OnDragEnd")
	g_DragRow = nil
	DL:UpdateSize(0.1)
end

