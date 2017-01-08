
--
-- lib_RoundedPopupWindow
--   by: John Su
--
--	This is a small window that pops up, typically anchored to another element (TODO)

--[[ INTERFACE
WINDOW = RoundedPopupWindow.Create(parent[, name, layout])
WINDOW:SetTitle(title[, color, halign])
WINDOW:EnableClose(enabled[, OnClose_func])	-- creates an 'X' button in the title
											   clicking it will close the window and call OnClose_func(WINDOW), if specified
WINDOW:Open([dur])				-- animates an opening sequence
WINDOW:Close([dur])				-- animates a closing sequence
WINDOW:Remove()					-- removes instance of the window
WINDOW:TintBack(tint)
WINDOW:ResizeBody(dims)
<GroupWidget> = WINDOW:GetBody()
<GroupWidget> = WINDOW:GetHeader()

CONSTANTS:
RoundedPopupWindow.OPEN_DUR	-- default open animation duration
RoundedPopupWindow.CLOSE_DUR	-- default close animation duration
--]]

require "table"

-- RoundedPopupWindow Interface:
RoundedPopupWindow = {
	OPEN_DUR = 0.2,
	CLOSE_DUR = 0.2,
	DEFAULT_BACK_TINT = "#000000",
};

-- constants
local pf = {};	-- private functions
local c_TopOffset = 0;	--main Body dim offsets, used for sizing the popup based on the needed body size
local c_BottomOffset = 0;
local c_LeftOffset = 0;
local c_RightOffset = 0;

-- variables
local g_myWindows = {};

local LAYOUTS = {
default = [=[<FocusBox dimensions="dock:fill">
			<Border name="main_body" dimensions="left:0; right:100%; top:0; bottom:100%" class="RoundedBorders" style="padding:6" >
				<Group name="contents" dimensions="left:]=]..c_LeftOffset..[=[; right:100%-]=]..c_RightOffset..[=[; top:]=]..c_TopOffset..[=[; bottom:100%-]=]..c_BottomOffset..[=[" style="alpha:0"/>
			</Border>
			<Border name="header" dimensions="left:0; right:100%; height:36; top:-8" style="clip-children:false; padding:6" class="RoundedBorders">
				<Group name="contents" dimensions="left:20; right:100%-20; center-y:50%; height:100%">
					<Text name="title" dimensions="dock:fill" style="font:Demi_11; halign:center; valign:center; wrap:false; clip:false; color:PanelTitle"/>
				</Group>
			</Border>
		</FocusBox>]=],
		
panel = [=[<FocusBox dimensions="dock:fill">
			<Border name="main_body" dimensions="left:0; right:100%; top:0; bottom:100%" class="PanelBackDrop">
				<Group name="contents" dimensions="left:]=]..c_LeftOffset..[=[; right:100%-]=]..c_RightOffset..[=[; top:]=]..c_TopOffset..[=[; bottom:100%-]=]..c_BottomOffset..[=[" style="alpha:0"/>
			</Border>
			<Border name="header" dimensions="left:0; right:100%; height:36; top:-8" style="clip-children:false;" class="PanelBackDrop">
				<Group name="contents" dimensions="left:20; right:100%-20; center-y:50%; height:100%">
					<Text name="title" dimensions="dock:fill" style="font:Demi_11; halign:center; valign:center; wrap:false; clip:false; color:PanelTitle"/>
				</Group>
			</Border>
		</FocusBox>]=],
}


RoundedPopupWindow.Create = function(PARENT, name, layout)
	local WINDOW = pf.WINDOW_Create(PARENT, name, layout);
	-- tag and register
	WINDOW.tag = #g_myWindows+1;
	g_myWindows[WINDOW.tag] = WINDOW;
	return WINDOW;
end

-- WINDOW

pf.WINDOW_Create = function(PARENT, name, layout)
	-- create widget
	if( layout ) then
		layout = LAYOUTS[layout];
	end
	
	if( not layout ) then
		layout = LAYOUTS.default;
	end
	
	local WINDOW = {GROUP=Component.CreateWidget(layout
		, PARENT, name)};
	
	-- create widget references
	WINDOW.BODY = {GROUP=WINDOW.GROUP:GetChild("main_body")};
	WINDOW.BODY.CONTENTS = WINDOW.BODY.GROUP:GetChild("contents");
	
	WINDOW.HEADER = {GROUP=WINDOW.GROUP:GetChild("header")};

	WINDOW.HEADER.CONTENTS = WINDOW.HEADER.GROUP:GetChild("contents");
	WINDOW.HEADER.TEXT = WINDOW.HEADER.CONTENTS:GetChild("title");
	
	WINDOW.can_close = false;	-- set by EnableClose
	WINDOW.OnClose = nil;		-- callback function set by EnableClose
	
	-- initialize
	pf.WINDOW_TintBack(WINDOW, RoundedPopupWindow.DEFAULT_BACK_TINT);
	pf.WINDOW_SetTitle(WINDOW, nil);
	pf.WINDOW_Close(WINDOW, 0);
	pf.WINDOW_Open(WINDOW);
	WINDOW.HEADER.GROUP:Show(false);
	
	-- assign functions
	WINDOW.SetTitle = pf.WINDOW_SetTitle;
	WINDOW.GetBody = pf.WINDOW_GetBody;
	WINDOW.GetHeader = pf.WINDOW_GetHeader;
	WINDOW.GetAdjustedSize = pf.WINDOW_GetAdjustedSize;
	WINDOW.Remove = pf.WINDOW_Destroy;
	WINDOW.TintBack = pf.WINDOW_TintBack;
	WINDOW.ResizeBody = pf.WINDOW_ResizeBody;
	WINDOW.Open = pf.WINDOW_Open;
	WINDOW.Close = pf.WINDOW_Close;
	WINDOW.EnableClose = pf.WINDOW_EnableClose;
	WINDOW.IsOpen = pf.WINDOW_IsOpen;
	
	-- forward widget functions
	function WINDOW:GetDims(...)		return self.GROUP:GetDims(unpack({...}));		end
	function WINDOW:SetDims(...)		return self.GROUP:SetDims(unpack({...}));		end
	function WINDOW:MoveTo(...)			return self.GROUP:MoveTo(unpack({...}));		end
	function WINDOW:QueueMove(...)		return self.GROUP:QueueMove(unpack({...})); 	end
	function WINDOW:FinishMove(...)		return self.GROUP:FinishMove(unpack({...}));	end
	function WINDOW:GetParam(...)		return self.GROUP:GetParam(unpack({...}));	    end
	function WINDOW:SetParam(...)		return self.GROUP:SetParam(unpack({...}));	    end
	function WINDOW:ParamTo(...)		return self.GROUP:ParamTo(unpack({...}));		end
	function WINDOW:QueueParam(...)		return self.GROUP:QueueParam(unpack({...}));	end
	function WINDOW:FinishParam(...)	return self.GROUP:FinishParam(unpack({...}));	end
	function WINDOW:BindEvent(...)		return self.GROUP:BindEvent(unpack({...}));	    end
	
	return WINDOW;
end

pf.WINDOW_Destroy = function(WINDOW)
	g_myWindows[WINDOW.tag] = nil;
	Component.RemoveWidget(WINDOW.GROUP);
	for k,v in pairs(WINDOW) do
		WINDOW[k] = nil;
	end
end

pf.WINDOW_SetTitle = function(WINDOW, label, color, halign)
	if (label) then
		WINDOW.HEADER.GROUP:Show(true);
		WINDOW.HEADER.TEXT:SetText(label);
		WINDOW.BODY.GROUP:SetDims("bottom:_; top:28");
		if( color )then
			WINDOW.HEADER.TEXT:SetTextColor(color);
		else
			WINDOW.HEADER.TEXT:SetTextColor("PanelTitle");
		end
		if( halign ) then
			WINDOW.HEADER.TEXT:SetAlignment("halign", halign);
		else
			WINDOW.HEADER.TEXT:SetAlignment("halign", "center");
		end
	else
		WINDOW.HEADER.GROUP:Show(false);
		WINDOW.HEADER.TEXT:SetText("");
		WINDOW.BODY.GROUP:SetDims("bottom:_; top:0");
	end
end

pf.WINDOW_GetBody = function(WINDOW)
	return WINDOW.BODY.CONTENTS;
end

pf.WINDOW_GetHeader = function(WINDOW)
	return WINDOW.HEADER.CONTENTS;
end

pf.WINDOW_GetAdjustedSize = function(WINDOW, tbl)
	if tbl and type(tbl) == "table" then
		if tbl.height then
			tbl.height = tbl.height + c_TopOffset + c_BottomOffset
			if WINDOW.HEADER.GROUP:IsVisible() then
				tbl.height = tbl.height + 28
			end
		end
		if tbl.width then
			tbl.width = tbl.width + c_LeftOffset + c_RightOffset
		end
		return tbl
	else
		return nil
	end
end

pf.WINDOW_IsOpen = function(WINDOW)
	return WINDOW.GROUP and WINDOW.GROUP:IsVisible()
end

pf.WINDOW_Open = function(WINDOW, total_dur)
	if (not total_dur) then
		total_dur = RoundedPopupWindow.OPEN_DUR;
	end
	
	WINDOW.HEADER.GROUP:SetDims("bottom:_; height:0");

	WINDOW.BODY.CONTENTS:SetParam("alpha", 0);
	WINDOW.BODY.CONTENTS:SetParam("alpha", 0);
	
	-- wind in clockwise from corners
	local delay = 0;
	local dur = total_dur*.9;
	
	WINDOW.GROUP:Show();
	
	-- drop down back
	delay = total_dur*.7;
	dur = total_dur*.3;

	WINDOW.BODY.GROUP:ParamTo("alpha", 1, dur, delay, "linear");
	
	-- raise header
	WINDOW.HEADER.GROUP:MoveTo("top:-12; height:36", dur, delay, "linear");
	WINDOW.HEADER.GROUP:ParamTo("alpha", 1, dur, delay, "linear");
	
	-- fade in body
	WINDOW.BODY.CONTENTS:ParamTo("alpha", 1, total_dur*.5, total_dur*.5);
end

pf.WINDOW_Close = function(WINDOW, total_dur)
	if (not total_dur) then
		total_dur = RoundedPopupWindow.CLOSE_DUR;
	end
	-- wind out clockwise from corners
	local delay = 0;
	local dur = total_dur*.9;
	
	delay = total_dur*.0;
	dur = total_dur*.3;
	--WINDOW.BODY.GROUP:MoveTo("bottom:0; height:0", dur, delay, "linear");
	WINDOW.BODY.GROUP:ParamTo("alpha", 0, dur, delay, "linear");
	
	-- lower header
	WINDOW.HEADER.GROUP:MoveTo("bottom:_; height:0", dur, delay, "linear");
	WINDOW.HEADER.GROUP:ParamTo("alpha", 0, dur, delay, "linear");
	
	-- fade out body
	WINDOW.BODY.CONTENTS:ParamTo("alpha", 0, total_dur*.5, 0);
	WINDOW.GROUP:Hide(total_dur);
end

pf.WINDOW_TintBack = function(WINDOW, tint, dur, delay)
	if (not delay) then delay = 0; end;
	if (not dur) then dur = 0; end;
	--[[
	for i = 1, WINDOW.BODY.BACK:GetChildCount() do
		WINDOW.BODY.BACK:GetChild(i):ParamTo("tint", tint, dur, delay);
	end
	for i = 1, WINDOW.HEADER.BACK:GetChildCount() do
		WINDOW.HEADER.BACK:GetChild(i):ParamTo("tint", tint, dur, delay);
	end
	--]]
	
	WINDOW.BODY.GROUP:ParamTo("tint", tint, dur, delay);
	WINDOW.HEADER.GROUP:ParamTo("tint", tint, dur, delay);
end

pf.WINDOW_ResizeBody = function(WINDOW, dims)
	WINDOW.BODY.GROUP:SetDims(dims);
end

local X_OnMouseOver = function(arg)
	local WINDOW = pf.GetWindowFromTag(arg.widget:GetTag());
	local dur = 0.2;
	WINDOW.HEADER.X:ParamTo("glow", "#40FF2020", dur, 0, "ease-in");
	WINDOW.HEADER.X:ParamTo("tint", "#FF8080", dur, 0, "ease-in");
	--WINDOW.HEADER.X:ParamTo("alpha", 0.5, dur);
end

local X_OnMouseLeave = function(arg)
	local WINDOW = pf.GetWindowFromTag(arg.widget:GetTag());
	local dur = 0.2;
	WINDOW.pending_close = false;
	WINDOW.HEADER.X:ParamTo("glow", 0, dur, 0, "ease-in");
	WINDOW.HEADER.X:ParamTo("tint", "#FFFFFF", dur, 0, "ease-in");
end

local X_OnMouseDown = function(arg)
	local WINDOW = pf.GetWindowFromTag(arg.widget:GetTag());
	local dur = 0.1;
	WINDOW.HEADER.X:ParamTo("glow", "#F0FF2020", dur, 0, "ease-in");
	WINDOW.HEADER.X:ParamTo("tint", "#FFFFFF", dur, 0, "ease-in");
	WINDOW.pending_close = true;
end

local X_OnMouseUp = function(arg)
	local WINDOW = pf.GetWindowFromTag(arg.widget:GetTag());
	if (WINDOW.pending_close) then
		X_OnMouseOver(arg);
		WINDOW:Close();
		if (WINDOW.OnClose ~= nil) then
			WINDOW.OnClose(WINDOW);
		end
	end
end

pf.WINDOW_EnableClose = function(WINDOW, enabled, OnClose_func)
	if (enabled ~= WINDOW.can_close) then
		WINDOW.can_close = enabled;
		if (enabled) then
			-- create 'X'
			WINDOW.HEADER.X = Component.CreateWidget('<StillArt name="X" dimensions="right:100%-5; center-y:50%; width:11; height:11" style="texture:Window; region:X"/>'
			,WINDOW.HEADER.CONTENTS);
			WINDOW.HEADER.X_FOCUS = Component.CreateWidget('<FocusBox name="focus" dimensions="center-x:50%; center-y:50%; width:20; height:20;" style="cursor:sys_hand"/>', WINDOW.HEADER.X);
			WINDOW.HEADER.X_FOCUS:SetTag(WINDOW.tag);
			-- bind functions
			WINDOW.OnClose = OnClose_func;
			WINDOW.HEADER.X_FOCUS:BindEvent("OnMouseEnter", X_OnMouseOver);
			WINDOW.HEADER.X_FOCUS:BindEvent("OnMouseLeave", X_OnMouseLeave);
			WINDOW.HEADER.X_FOCUS:BindEvent("OnMouseDown", X_OnMouseDown);
			WINDOW.HEADER.X_FOCUS:BindEvent("OnMouseUp", X_OnMouseUp);
		else
			Component.RemoveWidget(WINDOW.HEADER.X);
		end
	end
end

function pf.GetWindowFromTag(tag)
	return g_myWindows[tonumber(tag)];
end
