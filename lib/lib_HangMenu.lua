
--
-- lib_HangMenu
--   by: John Su
--
--	This is the menu that hangs from the upper left corner; it is mouse operated


--[[ INTERFACE
	MENU = HangMenu.CreateMenu(parent[, name])
	MENU:SetTitle(title)
	MENU:ClearItems()		> clears all menu items
	MENU:Remove()			> destroys the menu
	ITEM = MENU:AddItem(name, callback)

	NOTE: MENU dims - top-left = pole begin, bottom = top of menu list
--]]

require "table"

warn("lib_HangMenu has been deprecated")
HangMenu = {};

-- constants
local ITEM_HEIGHT = 31;
local ITEM_SPACING = 2;
local NO_SELECT_IDX = 0;
local SELECT_DUR = 0.0625;
local ITEM_REFOCUS_DUR = 0.1;
local MIN_WIDTH = 220;
local RIGHT_MARGIN = 50;

-- variables
local w_ITEMS = {};	-- holds references to ITEM's for callbacks

-- HangMenu Interface:

HangMenu.CreateMenu = function(PARENT, name)
	local MENU = HangMenu_MENU_Create(PARENT, name);
	return MENU;
end

-- MENU

function HangMenu_MENU_Create(PARENT, name)
	-- create widget
	local MENU = {GROUP=Component.CreateWidget(
		[=[<Group dimensions="left:30; top:0; bottom:54; right:100%">
			<Group name="body" dimensions="left:2; width:220; top:100%; height:0">
				<Group name="back" dimensions="dock:fill">
					<StillArt dimensions="dock:fill" style="texture:gradients; region:white_left; alpha:0.6; shadow:1"/>
					<StillArt dimensions="dock:fill" style="texture:colors; region:white; alpha:0.02; shadow:1"/>
				</Group>
				<Group name="items" dimensions="left:0; right:100%-50; top:0; bottom:100%"/>
				<StillArt name="select" dimensions="left:100%-42; top:0; bottom:0; width:6" class="Glowing" style="texture:colors; region:white"/>
				<Text name="title" dimensions="left:0; right:100%; height:25; bottom:-2" style="font:Demi_17; valign:bottom; halign:left; wrap:false; clip:false; bgcolor:#00000000; glow:#AA0033AA;"/>
			</Group>
			<StillArt name="pole" dimensions="center-x:0%; width:3; top:0; bottom:100%" class="Glowing" style="texture:colors; region:white"/>
		</Group>]=], PARENT, name)};
	
	-- create widget references
	MENU.POLE = MENU.GROUP:GetChild("pole");
	MENU.BODY = MENU.GROUP:GetChild("body");
	MENU.TITLE = MENU.BODY:GetChild("title");
	MENU.ITEMS = {GROUP=MENU.BODY:GetChild("items")};
	MENU.SELECT = MENU.BODY:GetChild("select");
	
	-- initialize
	HangMenu_MENU_Resize(MENU, 0);
	MENU.idx = NO_SELECT_IDX;
	
	-- assign functions
	MENU.SetTitle = HangMenu_MENU_SetTitle;
	MENU.AddItem = HangMenu_MENU_AddItem;
	MENU.ClearItems = HangMenu_MENU_ClearItems;
	MENU.SelectItem = HangMenu_MENU_SelectItem;
	MENU.Submit = HangMenu_MENU_Submit;
	MENU.Remove = HangMenu_MENU_Destroy;
	
	-- forward widget functions
	function MENU:GetDims(...)		return self.GROUP:GetDims(unpack({...}));		end
	function MENU:SetDims(...)		return self.GROUP:SetDims(unpack({...}));		end
	function MENU:MoveTo(...)		return self.GROUP:MoveTo(unpack({...}));		end
	function MENU:QueueMove(...)	return self.GROUP:QueueMove(unpack({...}));	    end
	function MENU:FinishMove(...)	return self.GROUP:FinishMove(unpack({...}));	end
	function MENU:GetParam(...)		return self.GROUP:GetParam(unpack({...}));	    end
	function MENU:SetParam(...)		return self.GROUP:SetParam(unpack({...}));	    end
	function MENU:ParamTo(...)		return self.GROUP:ParamTo(unpack({...}));		end
	function MENU:QueueParam(...)	return self.GROUP:QueueParam(unpack({...}));	end
	function MENU:FinishParam(...)	return self.GROUP:FinishParam(unpack({...}));	end
	function MENU:Show(...)			return self.GROUP:Show(unpack({...}));		    end
	
	return MENU;
end

function HangMenu_MENU_Destroy(MENU)
	MENU:ClearItems();
	Component.RemoveWidget(MENU.GROUP);
	for k,v in pairs(MENU) do
		MENU[k] = nil;
	end
end

function HangMenu_MENU_SetTitle(MENU, label)
	MENU.TITLE:SetText(label);
end

function HangMenu_MENU_ClearItems(MENU)
	for i = 1, #MENU.ITEMS do
		HangMenu_ITEM_Destroy(MENU.ITEMS[i]);
	end
	HangMenu_MENU_Resize(MENU, 0);
end

function HangMenu_MENU_AddItem(MENU, label, callbackFunc)
	local ITEM = HangMenu_ITEM_Create(MENU, label, callbackFunc);	
	HangMenu_MENU_Resize(MENU, 0);
	if (#MENU.ITEMS == 1) then
		HangMenu_MENU_SelectItem(MENU, 1);
	end
	return ITEM;
end

function HangMenu_MENU_Resize(MENU, dur)
	local bottom = 0;
	local maxWidth = 0;
	for i = 1, #MENU.ITEMS do
		local ITEM = MENU.ITEMS[i];
		local top = bottom + ITEM_SPACING;
		bottom = top + ITEM_HEIGHT;
		ITEM.dims = {top=top, bottom=bottom};
		ITEM.GROUP:FinishMove();
		ITEM.GROUP:MoveTo("top:"..top.."; bottom:"..bottom, dur);
		maxWidth = math.max(maxWidth, ITEM.textWidth);
	end
	bottom = bottom + ITEM_SPACING + 4;
	MENU.POLE:MoveTo("top:_; bottom:100%+"..(bottom), dur);
	MENU.BODY:MoveTo("top:_; height:"..(bottom).."; left:_; width:"..math.max(maxWidth+RIGHT_MARGIN+15, MIN_WIDTH), dur);
end

function HangMenu_MENU_SelectItem(MENU, idx)
	HangMenu_MENU_Select(MENU, idx, SELECT_DUR);
end

function HangMenu_MENU_Submit(MENU)
	local ITEM = MENU.ITEMS[MENU.idx];
	if (ITEM) then
		ITEM.callback();
	end
end

function HangMenu_MENU_Select(MENU, idx, dur)
	-- resize ITEM's
	local PREV_ITEM = MENU.ITEMS[MENU.idx];
	local CURR_ITEM = MENU.ITEMS[idx];
	if (PREV_ITEM) then
		PREV_ITEM.selected = false;
		PREV_ITEM.GROUP:FinishMove();
		PREV_ITEM.BACK:ParamTo("alpha", 0.6, dur);
		PREV_ITEM.GROUP:MoveTo("left:_; right:100%", dur, 0, "linear");
	end
	if (CURR_ITEM) then
		CURR_ITEM.selected = true;
		CURR_ITEM.GROUP:FinishMove();
		CURR_ITEM.BACK:ParamTo("alpha", 1.0, dur);
		CURR_ITEM.GROUP:MoveTo("left:_; right:100%+5", dur, 0, "linear");
	end
	
	-- reposition SELECT
	if (idx == NO_SELECT_IDX) then
		MENU.SELECT:MoveTo("center-y:_; height:0", dur, 0, "linear");
	else
		MENU.SELECT:SetParam("alpha", .4);
		MENU.SELECT:ParamTo("alpha", 0, 0, dur);
		MENU.SELECT:QueueParam("alpha", 1, 0, .05);
		MENU.SELECT:MoveTo("top:"..(CURR_ITEM.dims.top+2).."; bottom:"..(CURR_ITEM.dims.bottom-2), dur, 0, "linear");
	end
	
	MENU.idx = idx;
end

-- ITEM
function HangMenu_ITEM_Create(MENU, label, callbackFunc)
	local ITEM = {GROUP=Component.CreateWidget(
		[=[<Group dimensions="dock:fill">
			<StillArt name="back_border" dimensions="dock:fill" style="texture:colors; region:black; alpha:0.4"/>
			<StillArt name="back" dimensions="left:5; right:100%-5; top:5; bottom:100%-5" style="texture:colors; region:black; alpha:0.6"/>
			<Text name="title" dimensions="left:5; right:100%; center-y:50%; height:100%-10" style="font:Demi_12; valign:center; halign:left; wrap:false; bgcolor:#00000000;"/>
			<FocusBox name="focus" dimensions="dock:fill">
				<Events>
					<OnMouseEnter bind="HangMenu_ITEM_OnMouseEnter"/>
					<OnMouseLeave bind="HangMenu_ITEM_OnMouseLeave"/>
					<OnMouseDown bind="HangMenu_ITEM_OnMouseDown"/>
				</Events>
			</FocusBox>
		</Group>]=], MENU.ITEMS.GROUP, name)};
	ITEM.TITLE = ITEM.GROUP:GetChild("title");
	ITEM.BACK = ITEM.GROUP:GetChild("back");
	ITEM.FOCUS = ITEM.GROUP:GetChild("focus");
	ITEM.MENU = MENU;
	
	ITEM.TITLE:SetText(label);
	ITEM.textWidth = ITEM.TITLE:GetTextDims(false).width;
	ITEM.callback = callbackFunc;
	ITEM.selected = false;
	ITEM.focus = false;
	
	-- register self in MENU
	ITEM.idx = #MENU.ITEMS+1;	-- MENU idx
	MENU.ITEMS[ITEM.idx] = ITEM;
	ITEM.id = #w_ITEMS+1;	-- global idx
	
	-- store in global table
	w_ITEMS[ITEM.id] = ITEM;
	ITEM.FOCUS:SetTag(ITEM.id);
	
	return ITEM;
end

function HangMenu_ITEM_Destroy(ITEM)
	Component.RemoveWidget(ITEM.GROUP);
	w_ITEMS[ITEM.id] = nil;
	ITEM.MENU.ITEMS[ITEM.idx] = nil;
	ITEM.idx = nil;
	ITEM.id = nil;
	ITEM.GROUP = nil;
	ITEM.MENU = nil;
end

function HangMenu_ITEM_OnMouseEnter(args)
	local ITEM = w_ITEMS[tonumber(args.widget:GetTag())];
	ITEM.focus = true;
	ITEM.GROUP:MoveTo("left:_; right:100%+5", ITEM_REFOCUS_DUR);
end

function HangMenu_ITEM_OnMouseLeave(args)
	local ITEM = w_ITEMS[tonumber(args.widget:GetTag())];
	ITEM.focus = false;
	if (not ITEM.selected) then
		ITEM.GROUP:MoveTo("left:_; right:100%", ITEM_REFOCUS_DUR);
	end
end

function HangMenu_ITEM_OnMouseDown(args)
	local ITEM = w_ITEMS[tonumber(args.widget:GetTag())];
	HangMenu_MENU_Select(ITEM.MENU, ITEM.idx, SELECT_DUR);
	ITEM.callback();
end
