
--
-- lib_GridList
--   by: Ryan Strals
--		used for creating a grid of objects.

require "lib/lib_table"

GridList = {};

local LIST_API = {}
local ITEM_API = {}

local lf = {}

local GRIDLIST_METATABLE = {
	__index = function(t,key) return LIST_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in GRIDLIST"); end
};

local GRIDITEM_METATABLE = {
	__index = function(t,key) return ITEM_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in GRIDITEM"); end
};

--[[
Usage:
	---------------------------
	LIST API
	---------------------------
	GRIDLIST = GridList.Create(PARENT)				-- Creates a GridList object and returns it.
	
	GRIDLIST:SetDirection(string)					-- string is either "vertical" or "horizontal".
	GRIDLIST:SetRowCap(number)						-- Sets the amount of items per row to display, and if needed, updates the object to display it.
	GRIDLIST:SetGridSize(number)					-- Defines the size of the items in the grid, then updates the list.
	GRIDLIST:SetGridSpacing(string, value)			-- string is either "vertical" or "horizontal", sets the spacing type provided to value.
	GRIDLIST:DisplayBorders(bool)					-- Shows the borders around the grids based on the bool.
	GRIDLIST:ClearRows(bool)						-- Clears all rows, but does not forget the items in the list unless bool is true.

	GRIDLIST:Refresh()								-- Clears all rows and re-creates the list, not needed for normal use.

	GRIDLIST:Destroy()								-- Destroys the GRIDLIST.

	---------------------------
	ITEM API
	---------------------------
	GRIDITEM = GRIDLIST:AddToGrid(WIDGET)			-- Adds a widget to the grid and returns the object to you.

	GRIDITEM:ParamPlateTo(param, value[, duration])	-- Takes a parameter (string), a value (number), and optionally a duration to set/param a parameter on the border and backplate.
	GRIDITEM:DisplayBorder(bool)					-- Lets you turn the border and backplate on and off.

	GRIDITEM:Destroy()								-- Removes the GRIDITEM from the GRIDLIST and destroys the object.
}
--]]

local c_DefaultColumnCount = 5
local c_DefaultGridSize = 64
local c_DefaultGridSpacing = 6

local bp_GridListWidget = [[<ListLayout name="List" dimensions="left:0; top:0; height:0; width:100%" style="reverse:false; vertical:true; vpadding:]] .. c_DefaultGridSpacing .. [["/>]]
local bp_GridRowWidget = [[<ListLayout name="Row" dimensions="dock:fill" style="reverse:false; horizontal:true; hpadding:]] .. c_DefaultGridSpacing .. [["/>]]

local bp_GridItemWidget = [[<Group name="Item" dimensions="left:0; top:0; height:]] .. c_DefaultGridSize .. [[; width:]] .. c_DefaultGridSize .. [[">
								<Border name="backplate" dimensions="height:100%+4; width:100%+4; center-x:50%; center-y:50%" class="ButtonSolid" style="visible:false; tint:#111111; alpha:.5; exposure:1; eatsmice:false; saturation:1"/>
								<Border name="border" dimensions="height:100%+4; width:100%+4; center-x:50%; center-y:50%" class="ButtonBorder" style="visible:false; tint:#3F3F3F; alpha:.65; eatsmice:false"/>
								<Group name="foster" dimensions="dock:fill"/>
							</Group>]]

---------------------------
-- API

-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide", "IsVisible", "GetBounds", "SetVPadding", "GetLength", "SetHPadding"
}

for _, method_name in pairs(COMMON_METHODS) do
	LIST_API[method_name] = function(LIST_API, ...)
		return LIST_API.GROUP[method_name](LIST_API.GROUP, ...)
	end
end

for _, method_name in pairs(COMMON_METHODS) do
	ITEM_API[method_name] = function(ITEM_API, ...)
		return ITEM_API.GROUP[method_name](ITEM_API.GROUP, ...)
	end
end

function GridList.Create(PARENT)
	assert(PARENT, "You did not provide a valid parent to create the GridList to.")

	local GROUP = Component.CreateWidget(bp_GridListWidget, PARENT)

	local GRIDLIST = {
		GROUP = GROUP,

		-- The parent we're creating to.
		PARENT = PARENT,

		-- Where we store our grid objects.
		FOSTER_GROUP = Component.CreateWidget('<Group dimensions="height:0; width:0; left:0; top:0" style="visible:false; eatsmice:false"/>', PARENT),

		-- Our event dispatcher, currently not used.
		DISPATCHER = nil,

		-- All items we are displaying in our grid.
		ITEMS = {},

		-- All rows we have items created to.
		ROWS = {},

		-- All of our grids that are currently created.
		GRIDS = {},

		-- Total width/height of the list. 
		total_size = 0,

		-- Default size of the items in the list.
		grid_size = c_DefaultGridSize,

		-- The index of our objects
		index = 0,

		-- Our default number of items per row.
		column_count = c_DefaultColumnCount,

		-- Whether or not to show borders.
		display_borders = false,

		-- Our spacing for rows and columns.
		vertical_spacing = c_DefaultGridSpacing,
		horizontal_spacing = c_DefaultGridSpacing,

		-- Whether or not this is a vertical grid.
		is_vertical = false
	}

	-- Create our dispatcher so we can send out events.
	GRIDLIST.DISPATCHER = EventDispatcher.Create(GRIDLIST);

	-- Apply our metatable so we can perform methods on our new object.
	setmetatable(GRIDLIST, GRIDLIST_METATABLE)

	return GRIDLIST
end

-- Grid List
function LIST_API.SetDirection(GRIDLIST, style)
	local is_vertical = (style == "vertical")

	GRIDLIST.is_vertical = is_vertical

	GRIDLIST.GROUP:SetVertical(not(is_vertical))
	for _ROW in pairs(GRIDLIST.ROWS) do
		ROW:SetVertical(is_vertical)
	end
end

function LIST_API.AddToGrid(GRIDLIST, ITEM)
	assert(Component.IsWidget(ITEM), "You did not specify a valid widget to add to the grid.")

	local item_index = lf.FindIndex(GRIDLIST.ITEMS)
	GRIDLIST.ITEMS[item_index] = ITEM

	return lf.DisplayItem(GRIDLIST, ITEM, item_index)
end

function LIST_API.SetGridSize(GRIDLIST, size)
	assert(size, "You did not specify a size for the items.")

	GRIDLIST.grid_size = size

	local rowWidth = GRIDLIST.grid_size
	local rowHeight = GRIDLIST.grid_size

	if GRIDLIST.is_vertical then
		rowHeight = GRIDLIST.vertical_spacing
	end

	for _,ROW in pairs(GRIDLIST.ROWS) do
		ROW:SetDims("left:0; top:0; height:" .. rowHeight .. "; width:" .. rowWidth)
	end
end

function LIST_API.SetGridSpacing(GRIDLIST, spacingType, value)
	local spacing_type = GRIDLIST[unicode.lower(spacingType) .. "_spacing"]
	assert(spacing_type and value, "You did not provide a valid type and value for spacing.")

	spacing_type = value

	if not(GRIDLIST.is_vertical) then
		if spacingType == "vertical" then
			GRIDLIST:SetVPadding(value)
		else
			for _,ROW in pairs(GRIDLIST.ROWS) do
				ROW:SetHPadding(value)
			end
		end
	else
		if spacingType == "vertical" then
			GRIDLIST:SetHPadding(value)
		else
			for _,ROW in pairs(GRIDLIST.ROWS) do
				ROW:SetVPadding(value)
			end
		end
	end
end

function LIST_API.SetRowCap(GRIDLIST, count)
	assert(count, "You did not specify a number for the columns.")

	GRIDLIST.column_count = count
	GRIDLIST.index = 0

	if #GRIDLIST.ITEMS > 0 or #GRIDLIST.ROWS > 0 then
		GRIDLIST:Refresh()
	end
end

function LIST_API.ClearRows(GRIDLIST)
	for idx,ROW in pairs(GRIDLIST.ROWS) do
		Component.RemoveWidget(ROW)
	end

	GRIDLIST.ROWS = {}

	GRIDLIST.index = 0
end

function LIST_API.ClearItems(GRIDLIST)
	GRIDLIST.ITEMS = {}
	
	GRIDLIST:ClearRows()
end

function LIST_API.DisplayBorders(GRIDLIST, bool)
	GRIDLIST.display_borders = bool

	for _,GRID in pairs(GRIDLIST.GRIDS) do
		GRID:DisplayBorder(true)
	end
end

function LIST_API.Refresh(GRIDLIST)
	GRIDLIST:ClearRows()

	for idx,ITEM in pairs(GRIDLIST.ITEMS) do
		lf.DisplayItem(GRIDLIST, ITEM, idx)
	end
end

function LIST_API.Destroy(GRIDLIST)
	Component.RemoveWidget(GRIDLIST.GROUP)
	GRIDLIST.DISPATCHER:Destroy()

	for idx in pairs(GRIDLIST) do
		GRIDLIST[idx] = nil
	end
end

-- Grid Item
function ITEM_API.ParamPlateTo(ITEM, param, value, duration)
	assert(param and value, "You did not specify a valid paramater and value.")

	duration = duration or 0

	ITEM.BORDER:ParamTo(param, value, duration)
	ITEM.BACKPLATE:ParamTo(param, value, duration)
end

function ITEM_API.DisplayBorder(ITEM, bool)
	ITEM.BORDER:Show(bool)
	ITEM.BACKPLATE:Show(bool)
end

function ITEM_API.Destroy(ITEM)
	Component.RemoveWidget(ITEM.GROUP)

	ITEM.GRIDLIST.ITEMS[ITEM.index] = nil

	ITEM.GRIDLIST:Refresh()
end

---------------------------
-- LOCAL FUNCTIONS

function lf.CreateItemRow(GRIDLIST)
	local ROW = Component.CreateWidget(bp_GridRowWidget, GRIDLIST.GROUP)
	if GRIDLIST.is_vertical then
		ROW:SetDims("left:0; top:0; height:" .. GRIDLIST.vertical_spacing .. "; width:" .. GRIDLIST.grid_size)
	else
		ROW:SetDims("left:0; top:0; height:" .. GRIDLIST.grid_size .. "; width:_")
	end

	if not GRIDLIST.is_vertical then
		ROW:SetHPadding(GRIDLIST.horizontal_spacing)
	else
		ROW:SetHorizontal(false)
		ROW:SetVPadding(GRIDLIST.horizontal_spacing)
	end

	return ROW
end

function lf.FindIndex(TABLE)
	for i = 1,#TABLE do
		if not TABLE[i] then return i end
	end

	return #TABLE+1
end

function lf.DisplayItem(GRIDLIST, ITEM, index)
	if type(ITEM) == "{nil}" then return nil end

	if GRIDLIST.index >= GRIDLIST.column_count or not GRIDLIST.ROWS[#GRIDLIST.ROWS] then
		GRIDLIST.index = 0

		GRIDLIST.ROWS[#GRIDLIST.ROWS+1] = lf.CreateItemRow(GRIDLIST)
	end

	GRIDLIST.index = GRIDLIST.index + 1

	-- Create our new widget to the most recent row.
	local GRID_ITEM = GRIDLIST.GRIDS[index] or nil
	if not GRIDLIST.GRIDS[index] then
		GRID_ITEM = lf.MakeGridWidget(GRIDLIST, ITEM, index)
	end

	lf.UpdateGridWidget(GRIDLIST, GRID_ITEM, GRIDLIST.ROWS[#GRIDLIST.ROWS])
	Component.FosterWidget(ITEM, GRID_ITEM.FOSTER_GROUP)

	GRIDLIST.GROUP:SetDims("height:" .. GRIDLIST:GetLength() .. "; top:_")

	return GRID_ITEM
end

function lf.UpdateGridWidget(GRIDLIST, GRID_ITEM, FOSTER_PARENT)
	GRID_ITEM.BORDER:Show(GRIDLIST.display_borders)
	GRID_ITEM.BACKPLATE:Show(GRIDLIST.display_borders)

	Component.FosterWidget(GRID_ITEM.GROUP, FOSTER_PARENT, "full")

	-- Apply our metatable so we can perform methods on our new object.
	setmetatable(GRID_ITEM, GRIDITEM_METATABLE)
end

function lf.MakeGridWidget(GRIDLIST, ITEM, index)
	local GROUP = Component.CreateWidget(bp_GridItemWidget, GRIDLIST.FOSTER_GROUP)
	GROUP:SetDims("height:" .. GRIDLIST.grid_size .. "; width:" .. GRIDLIST.grid_size .. "; center-y:50%; center-x:50%")

	local GRID_ITEM = {
		GROUP = GROUP,
		GRIDLIST = GRIDLIST,

		BORDER = GROUP:GetChild("border"),
		BACKPLATE = GROUP:GetChild("backplate"),
		FOSTER_GROUP = GROUP:GetChild("foster"),

		index = index
	}

	GRIDLIST.GRIDS[GRID_ITEM.index] = GRID_ITEM

	return GRID_ITEM
end
