
--
-- lib_MenuList
--   by: James Harless
--

--[[
	MENULIST = MenuList.Create(PARENT)		-- Creates a MenuList Object
	
	TREE = MENULIST:AddTree(Name)			-- Name
	
	NODE = MENULIST:AddNode(node_args)		-- tree_args
												.name : node name
												.icon : icon
												.foster_icon : icon foster
												.tree : TREE or Tree Name will act as a child node if a valid parent is defined
												.lock : bool, locks the node
												

	MENULIST:RemoveTree(name)				-- Removes the Tree
	MENULIST:RemoveNode(tree, name)			-- Removes the Node
	
	MENULIST:ExpandNode(name)
	MENULIST:CollapseNode(name)																


	TREE = MENULIST:GetTree(name)
	TREE:Expand()
	TREE:Collapse()
	TREE:Remove()
	
	NODE = MENULIST:GetNode(tree, node)
	NODE = TREE:GetNode(name)
	NODE:Select()
	NODE:Remove()
	NODE:Lock()
	NODE:Unlock()
--]]

if MenuList then
	return nil
end
MenuList = {}

require "table"
require "math"
--require "unicode"
require "lib/lib_RowScroller"
require "lib/lib_EventDispatcher"
require "lib/lib_HoloPlate"

require "lib/lib_Colors"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
--local MENULIST = Component.GetWidget("MenuList")
--local FOSTER = Component.GetWidget("MenuList_Foster")
--local ROWSCROLLER = RowScroller.Create(MENULIST)

local lf = {}
local MENU_API = {}
local TREE_API = {}
local NODE_API = {}

local Menu_MT = {__index = function(self, key) return MENU_API[key] end}
local Tree_MT = {__index = function(self, key) return TREE_API[key] end}
local Node_MT = {__index = function(self, key) return NODE_API[key] end}

local SOUND_CLICK		= "select_item"
local SOUND_RESIZE		= "resize_menuitem"
local SOUND_ROLLOVER	= "rollover"

local BUTTON_TREE_HEIGHT = 29
local BUTTON_NODE_HEIGHT = 27

local TREE_PADDING = 20
local NODE_PADDING = 1

local MENU_DUR = 0.25			-- Adjust
local TREE_DUR = 0.25			-- Adjust
local TREE_ARROW_DUR = 0.25		-- Adjust
local TREE_ARROW_DOWN = 0.5
local TREE_ARROW_RIGHT = 0.25

local NODE_DEFAULT = "#0F0F0F"
local NODE_HIGHLIGHT = "#1A2128"
local NODE_SELECTED = "#364353"
local NODE_TEXT_DEFAULT = "#FFFFFF"
local NODE_TEXT_SELECTED = Component.LookupColor("orange")
local NODE_BORDER = "#123844"

local MODE_INACTIVE = 0
local MODE_ACTIVE = 1

local BP_MENULIST = [[<Group dimensions="dock:fill">
	<Group name="fosterholding" dimensions="dock:fill" style="visible:false" />
	<FocusBox name="focus" dimensions="dock:fill"/>
	<ListLayout name="list" dimensions="dock:fill" style="vpadding:]]..TREE_PADDING..[["/>
</Group>]]

local BP_TREE = [[<Group dimensions="left:0; top:0; width:100%; bottom:100%;" style="clip-children:true">
	<Button name="button" dimensions="left:0; top:0; width:100%; height:]]..BUTTON_TREE_HEIGHT..[[;" style="font:Demi_11;"/>
	<ListLayout name="list" dimensions="left:0; top:31; right:100%; bottom:100%" style="vpadding:]]..NODE_PADDING..[["/>
</Group>]]

local BP_TREE_LABEL = [[<Group dimensions="dock:fill">
	<Text name="title" dimensions="left:10; right:100%-10; center-y:50%; height:100%;" style="font:UbuntuBold_12; halign:left; valign:center; alpha:1; wrap:false"/>
	<Text name="info" dimensions="left:10; right:100%-31; center-y:50%; height:100%;" style="font:UbuntuMedium_12; halign:right; valign:center; alpha:1; wrap:false; color:orange"/>
	<Animation name="arrow" mesh="rotater" style="texture:arrows; region:up; percent:]]..TREE_ARROW_RIGHT..[[; alpha:0.6" dimensions="right:100%-10; height:12; width:12; center-y:50%"/>
</Group>]]

local BP_NODE = [[<FocusBox dimensions="left:0; top:0; width:100%; height:]]..BUTTON_NODE_HEIGHT..[[;" class="ui_button">
	<Border name="backdrop" dimensions="dock:fill" class="RoundedBorders" style="padding:4; tint:]]..NODE_DEFAULT..[[; alpha:1;" />
	<Border name="outer" dimensions="dock:fill" class="ButtonBorder" style="tint:]]..NODE_BORDER..[["/>
	<StillArt name="icon" dimensions="left:17; top:2; width:23; height:23;" style="texture:SysIconTexture; eatsmice:false"/>
	<Text name="title" dimensions="left:43; right:100%-5; top:4; bottom:100%-4;" style="font:UbuntuMedium_11; halign:left; valign:center; alpha:1; wrap:false"/>
	<Text name="info" dimensions="left:43; right:100%-5; top:4; bottom:100%-4;" style="font:UbuntuMedium_11; halign:right; valign:center; alpha:1; wrap:false"/>
</FocusBox>]]


-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------

function MenuList.Create(PARENT)
	local MENU = {
		FOSTER = Component.CreateWidget([[<Group dimensions="dock:fill" style="visible:false" />]], PARENT),
		ROWSCROLLER = RowScroller.Create(PARENT),
		
		-- Trees
		TREES = {},
		NODES = {},
		Tree_Count = 0,
		
		-- Variables
		selected = 0,
		parent_height = PARENT:GetBounds().height - 8,
	}
	MENU.DISPATCHER = EventDispatcher.Create()
	MENU.DISPATCHER:Delegate(MENU)
	MENU.ROWSCROLLER:SetSpacing(8)
	MENU.ROWSCROLLER:SetSliderMargin(25, 6)
	
	setmetatable(MENU, Menu_MT)

	return MENU
end


-- ------------------------------------------
--  MENULIST API
-- ------------------------------------------

function MENU_API.AddTree(MENULIST, args)
	local TREE = lf.CreateTree(MENULIST, args)
	-- Add TREE to MENULIST
	return TREE
end

function MENU_API.AddNode(MENULIST, Tree, args)
	local TREE = MENULIST.TREES[Tree]
	local NODE = lf.CreateNode(TREE, MENULIST, args)
	return NODE
end

function MENU_API.GetTree(MENULIST, tree)
	if MENULIST.TREES[tree] then
		return MENULIST.TREES[tree]
	else
		warn("Tree Not Found!")
	end
end

function MENU_API.CollapseTrees(MENULIST)
	for _, TREE in pairs(MENULIST.TREES) do
		--if TREE.collapsed == false then
			lf.CollapseTree(TREE, MENULIST)
		--end
	end
end

function MENU_API.SelectNode(MENULIST, tree_name, node_id, use_index)
	local TREE = MENULIST.TREES[tree_name]
	if TREE then
		lf.AutoExpandTree(TREE, MENULIST)
		local node_id = node_id or TREE.autoselect or 1
		local nodeType = type(node_id)
		if nodeType == "number" then
			lf.Node_SetSelectedById(node_id, TREE, MENULIST)
		elseif nodeType == "string" then
			lf.Node_SetSelectedByName(node_id, TREE, MENULIST)
		else
			error("Node_Id must be string or number!")
		end
		lf.MenuList_RefreshHeight(MENULIST)
	else
		warn("No Tree by that name found!")
	end
end

function MENU_API.SelectNodeById(MENULIST, tree_name, node_id)
	local TREE = MENULIST.TREES[tree_name]
	if TREE then
		lf.AutoExpandTree(TREE, MENULIST)
		local node_id = node_id or TREE.autoselect or 1
		lf.Node_SetSelectedById(node_id, TREE, MENULIST)
		lf.MenuList_RefreshHeight(MENULIST)
	else
		warn("No Tree by that name found!")
	end
end

function MENU_API.SelectNodeByIndex(MENULIST, tree_name, node_index)
	local TREE = MENULIST.TREES[tree_name]
	if TREE then
		lf.AutoExpandTree(TREE, MENULIST)
		local node_index = node_index or 1
		lf.Node_SetSelectedByIndex(node_index, TREE, MENULIST)
		lf.MenuList_RefreshHeight(MENULIST)
	else
		warn("No Tree by that name found!")
	end
end

function MENU_API.RefreshSize(MENULIST)
	lf.MenuList_RefreshHeight(MENULIST)
end

function MENU_API.Close(MENULIST)
	MENU_API.CollapseTrees(MENULIST)
	local PREV_NODE = lf.GetNode(MENULIST.selected, MENULIST)
	lf.NodeButton_Deselect(PREV_NODE)
	MENULIST.selected = 0
end

function MENU_API.GetSelected(MENULIST)
	local NODE = lf.GetNode(MENULIST.selected, MENULIST)
	if NODE then
		local panel = NODE.panel
		return panel
	end
end

-- ------------------------------------------
--  TREE API
-- ------------------------------------------
function TREE_API.SetInfoText(TREE, info)
	TREE.INFO:SetText(info or "")
	TREE.INFO:Show( (info) )
end

function TREE_API.AutoSelectOnClick(TREE, index)
	TREE.autoselect = index
end

-- ------------------------------------------
--  NODE API
-- ------------------------------------------
function NODE_API.SetInfoText(NODE, info)
	NODE.INFO:SetText(info or "")
	NODE.INFO:Show( (info) )
end

-- ------------------------------------------
-- lf FUNCTIONS
-- ------------------------------------------
-- Menu List
function lf.MenuList_RefreshHeight(MENULIST)
	MENULIST.ROWSCROLLER:UpdateSize()
end

function lf.MenuListInsertTree(MENULIST, TREE)
	MENULIST.TREES[TREE.panel] = TREE
	MENULIST.Tree_Count = MENULIST.Tree_Count + 1
	lf.RefreshTreeHeight(TREE)
end

-- Tree
function lf.CreateTree(MENULIST, args)
	local title = args.title or "Untitled"
	local info = args.info

	local GROUP = Component.CreateWidget(BP_TREE, MENULIST.FOSTER)
	local LABEL_GROUP = Component.CreateWidget(BP_TREE_LABEL, GROUP:GetChild("button"))
	local TREE = {
		-- Widgets
		GROUP = GROUP,
		LIST = GROUP:GetChild("list"),
		BUTTON = GROUP:GetChild("button"),
		TITLE = LABEL_GROUP:GetChild("title"),
		INFO = LABEL_GROUP:GetChild("info"),
		ARROW = LABEL_GROUP:GetChild("arrow"),
		
		-- Nodes
		NODES = {}, -- Child Node Listing
		Node_Count = 0,
		
		-- Variables
		title = title,
		panel = args.panel,
		collapsed = true,
		collapsed_height = BUTTON_TREE_HEIGHT,
		expanded_height = BUTTON_TREE_HEIGHT,
		autoselect = false,
	}
	
	TREE.ROW = MENULIST.ROWSCROLLER:AddRow(GROUP)
	TREE.ROW:UpdateSize({height=BUTTON_TREE_HEIGHT})
	TREE.BUTTON:BindEvent("OnScroll", function(args)
		MENULIST.ROWSCROLLER:ScrollSteps(args.amount)
	end)
	TREE.BUTTON:BindEvent("OnSubmit", function()
		lf.TreeButton_OnSelect(TREE, MENULIST)
		System.PlaySound(SOUND_RESIZE)
	end)
	
	
	TREE.TITLE:SetText(title)
	TREE.INFO:Show( (info) )
	TREE.INFO:SetText(info or "")
	
	setmetatable(TREE, Tree_MT)
	lf.MenuListInsertTree(MENULIST, TREE)

	return TREE
end

function lf.TreeButton_OnSelect(TREE, MENULIST)
	if not TREE.collapsed then
		lf.CollapseTree(TREE, MENULIST)
	else
		lf.ExpandTree(TREE, MENULIST)
	end
end

function lf.CollapseTree(TREE, MENULIST)
	TREE.collapsed = true
	TREE.ARROW:PlayTo(TREE_ARROW_RIGHT, TREE_ARROW_DUR)
	
	TREE.ROW:UpdateSize({height=TREE.collapsed_height}, TREE_DUR)
end

function lf.ExpandTree(TREE, MENULIST)
	TREE.collapsed = false
	TREE.ARROW:PlayTo(TREE_ARROW_DOWN, TREE_ARROW_DUR)
	
	TREE.ROW:UpdateSize({height=TREE.expanded_height}, TREE_DUR)
	
	if TREE.autoselect and #TREE.NODES > 0 then
		lf.Node_SetSelectedById(TREE.autoselect, TREE, MENULIST)
	end
end

function lf.AutoExpandTree(TREE, MENULIST)
	if TREE.collapsed then
		lf.TreeButton_OnSelect(TREE, MENULIST)
	end
end

function lf.RefreshTreeHeight(TREE)
	TREE.expanded_height = TREE.LIST:GetLength() + BUTTON_TREE_HEIGHT + 2
end

function lf.TreeInsertNode(MENULIST, TREE, NODE)
	local node_index = TREE.Node_Count + 1
	TREE.Node_Count = node_index
	table.insert(MENULIST.NODES, NODE)
	--table.insert(TREE.NODES, NODE.menu_index)
	TREE.NODES[NODE.id] = NODE.menu_index
	lf.RefreshTreeHeight(TREE)
end

function lf.AddNode(TREE, MENULIST, args)
	local NODE = lf.CreateNode(TREE, MENULIST, args)
	return NODE
end
-- Node

function lf.CreateNode(TREE, MENULIST, args)
	local title = args.title or "Untitled"
	local id = args.id or TREE.Node_Count + 1
	local info = args.info
	local texture = args.texture
	local region = args.region
	local notint = args.notint
	local panel = args.panel
	local data = args.data

	local GROUP = Component.CreateWidget(BP_NODE, TREE.LIST)
	local NODE = {
		-- Widgets
		GROUP = GROUP,
		BACKDROP = GROUP:GetChild("backdrop"),
		TITLE = GROUP:GetChild("title"),
		INFO = GROUP:GetChild("info"),
		ICON = GROUP:GetChild("icon"),
		
		-- Variables
		title = title,					-- Localized Name
		id = id,						-- Unique Id
		info = info,					-- Right Side Info
		texture = texture or "icons",	-- Texture
		region = region,				-- Icon Art
		notint = notint,				-- Allow Icon Tinting
		panel = panel,					-- Category panel
		data = data,					-- Category panel data
		
		parent = TREE.name,
		index = #TREE.NODES+1,
		menu_index = #MENULIST.NODES+1,
		
		locked = false,
		
		selected = false,
	}
	GROUP:BindEvent("OnMouseEnter", function(args)
		if not NODE.locked then
			local tint = NODE_HIGHLIGHT
			if NODE.selected then
				tint = NODE_SELECTED
			end
			NODE.BACKDROP:ParamTo("tint", tint, 0.2)
			System.PlaySound(SOUND_ROLLOVER)
		end
	end)
	GROUP:BindEvent("OnMouseLeave", function(args)
		local tint = NODE_DEFAULT
		if NODE.selected then
			tint = NODE_SELECTED
		end
		NODE.BACKDROP:ParamTo("tint", tint, 0.2)
	end)
	GROUP:BindEvent("OnMouseDown", function(args)
		--lf_OnButtonMouseDown(BUTTON, args);
	end)
	GROUP:BindEvent("OnMouseUp", function(args)
		if not NODE.locked and not lf.NodeButton_IsSelected(NODE, TREE, MENULIST) then
			lf.NodeButton_Select(NODE, TREE, MENULIST)
			System.PlaySound(SOUND_CLICK)
		end
	end)
	GROUP:BindEvent("OnScroll", function(args)
		MENULIST.ROWSCROLLER:ScrollSteps(args.amount)
	end)
	
	NODE.TITLE:SetText(title)
	
	NODE.INFO:Show( (info) )
	NODE.INFO:SetText(info or "")
	
	if texture and region then
		NODE.ICON:SetTexture(texture, region)
	elseif region then
		NODE.ICON:SetRegion(region)
	else
		NODE.ICON:Hide()
		NODE.TITLE:SetDims("left:17; right:_; top:_")
	end
	
	NODE.SetLock = function(NODE, state)
		if NODE.locked ~= state then
			NODE.locked = state
			if state then
				NODE.ICON:SetTexture("icons", "lock")
				NODE.TITLE:SetText(Component.LookupText("LOCKED"))
				NODE.ICON:SetParam("alpha", 0.5)
				NODE.TITLE:SetParam("alpha", 0.5)
			else
				NODE.ICON:SetTexture(NODE.texture, NODE.region)
				NODE.TITLE:SetText(NODE.title)
				NODE.ICON:SetParam("alpha", 1)
				NODE.TITLE:SetParam("alpha", 1)
			end
		
		end
	end
	
	setmetatable(NODE, Node_MT)
	lf.TreeInsertNode(MENULIST, TREE, NODE)

	return NODE
end

function lf.GetNode(id, MENULIST)
	if MENULIST.NODES[id] then
		return MENULIST.NODES[id]
	end
end

function lf.NodeButton_Deselect(NODE)
	if NODE then
		NODE.selected = false
		NODE.BACKDROP:ParamTo("tint", NODE_DEFAULT, 0.2)
		NODE.TITLE:SetTextColor(NODE_TEXT_DEFAULT)
		NODE.ICON:ParamTo("tint", NODE_TEXT_DEFAULT, 0.2)
	end
end

function lf.Node_SetSelectedByName(name, TREE, MENULIST)
	if type(name) == "string" then
		for _,NODE in pairs(MENULIST.NODES) do
			if isequal(NODE.title, name) and isequal(TREE.name, NODE.parent) then
				if isequal(MENULIST.selected, NODE.menu_index) then
					return nil
				end
				lf.NodeButton_Select(NODE, TREE, MENULIST)
				break
			end
		end
	end
end

function lf.Node_SetSelectedById(node_id, TREE, MENULIST)
	if type(node_id) == "number" then
		local index = TREE.NODES[node_id]
		if index then
			if isequal(MENULIST.selected, index) then
				return nil
			end
			local NODE = lf.GetNodeByIndex(index, MENULIST)
			lf.NodeButton_Select(NODE, TREE, MENULIST)
		end
	end
end

function lf.Node_SetSelectedByIndex(node_index, TREE, MENULIST)
	if type(node_id) == "number" then
		if node_index then
			if isequal(MENULIST.selected, node_index) then
				return nil
			end
			local NODE = lf.GetNodeByIndex(node_index, MENULIST)
			lf.NodeButton_Select(NODE, TREE, MENULIST)
		end
	end
end

function lf.Node_SetSelected(NODE, TREE, MENULIST)
	MENULIST.selected = NODE.menu_index
end

function lf.NodeButton_Refresh(NODE, TREE, MENULIST)
	local PREV_NODE = lf.GetNode(MENULIST.selected, MENULIST)
	lf.NodeButton_Deselect(PREV_NODE)
	NODE.TITLE:SetTextColor(NODE_TEXT_SELECTED)
	NODE.BACKDROP:ParamTo("tint", NODE_SELECTED, 0.2)
	NODE.ICON:ParamTo("tint", NODE_TEXT_SELECTED, 0.2)
	lf.NodeButton_OnClick(NODE, MENULIST)
	NODE.selected = true
end

function lf.NodeButton_Select(NODE, TREE, MENULIST)
	NODE.selected = true
	NODE.TITLE:SetTextColor(NODE_TEXT_SELECTED)
	NODE.BACKDROP:ParamTo("tint", NODE_SELECTED, 0.2)
	if not NODE.notint then
		NODE.ICON:ParamTo("tint", NODE_TEXT_SELECTED, 0.2)
	end
	local PREV_NODE = lf.GetNode(MENULIST.selected, MENULIST)
	lf.NodeButton_Deselect(PREV_NODE)
	lf.Node_SetSelected(NODE, TREE, MENULIST)
	lf.NodeButton_OnClick(NODE, MENULIST)
end

function lf.NodeButton_IsSelected(NODE, TREE, MENULIST)
	return ( MENULIST.selected == NODE.menu_index )
end

function lf.GetNodeByIndex(index, MENULIST)
	return MENULIST.NODES[index]
end

function lf.NodeButton_OnClick(NODE, MENULIST)
	MENULIST:DispatchEvent("OnSelect", {panel=NODE.panel, id=NODE.data})
end
