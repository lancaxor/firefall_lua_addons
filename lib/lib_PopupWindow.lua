
--
-- lib_PopupWindow
--   by: John Su
--
--	This is a small window that pops up, typically anchored to another element (TODO)

--[[ INTERFACE
WINDOW = PopupWindow.Create(parent[, name])
WINDOW:SetTitle(title)
WINDOW:EnableClose(enabled[, OnClose_func])	-- creates an 'X' button in the title
											   clicking it will close the window and call OnClose_func(WINDOW), if specified
WINDOW:Open([dur])				-- animates an opening sequence
WINDOW:Close([dur])				-- animates a closing sequence
WINDOW:Remove()					-- removes instance of the window
WINDOW:TintBack(tint)
<GroupWidget> = WINDOW:GetBody()

CONSTANTS:
PopupWindow.OPEN_DUR	-- default open animation duration
PopupWindow.CLOSE_DUR	-- default close animation duration
--]]

-- PopupWindow Interface:
PopupWindow = {
	OPEN_DUR = 0.2,
	CLOSE_DUR = 0.2,
	DEFAULT_BACK_TINT = "#3F4A54",
};

require "unicode"
require "table"

-- constants
local pf = {};	-- private functions
local c_TopOffset = 5;	--main Body dim offsets, used for sizing the popup based on the needed body size
local c_BottomOffset = 10;
local c_LeftOffset = 23;
local c_RightOffset = 22;

-- variables
local g_myWindows = {};


PopupWindow.Create = function(PARENT, name)
	local WINDOW = pf.WINDOW_Create(PARENT, name);
	-- tag and register
	WINDOW.tag = #g_myWindows+1;
	g_myWindows[WINDOW.tag] = WINDOW;
	return WINDOW;
end

-- WINDOW

pf.WINDOW_Create = function(PARENT, name)
	-- create widget
	
	local WINDOW = {GROUP=Component.CreateWidget(
		[=[<FocusBox dimensions="dock:fill">
			<Group name="main_body" dimensions="left:0; right:100%; top:0; bottom:100%" style="clip-children:true">
				<Group name="backPlate" dimensions="left:23; right:100%-22; top:5; bottom:100%-10;" style="alpha:0.9">
					<StillArt name="TL" dimensions="left:0; top:0; width:10; height:10" style="texture:Window; region:back_TL; eatsmice:false"/>
					<StillArt name="TR" dimensions="right:100%; top:0; width:10; height:10" style="texture:Window; region:back_TR; eatsmice:false"/>
					<StillArt name="ML" dimensions="left:0; top:10; width:10; bottom:100%-16" style="texture:Window; region:back_ML; eatsmice:false"/>
					<StillArt name="MM" dimensions="left:10; top:0; right:100%-10; bottom:100%-16" style="texture:Window; region:back_M; ywrap:10; eatsmice:false"/>
					<StillArt name="MR" dimensions="right:100%; top:10; width:10; bottom:100%-16" style="texture:Window; region:back_MR; eatsmice:false"/>
					<StillArt name="BL" dimensions="left:0; bottom:100%; width:16; height:16" style="texture:Window; region:back_BL; eatsmice:false"/>
					<Mask name="BM" maskdims="height:100%; left:6; right:100%-6" dimensions="left:10; height:16; right:100%-10; bottom:100%" style="texture:Window; region:back_M; eatsmice:false"/>
					<StillArt name="BR" dimensions="right:100%; bottom:100%; width:16; height:16" style="texture:Window; region:back_BR; eatsmice:false"/>
				</Group>
				<Group name="margins" dimensions="left:0; right:100%; top:0; bottom:100%" style="alpha:0.4">
					<Mask name="TL" maskdims="dock:fill" dimensions="left:0; top:0; width:32; height:46" style="texture:Window; tint:#00060C; region:margin_TL; eatsmice:false"/>
					<Mask name="TR" maskdims="dock:fill" dimensions="width:28; top:0; right:100%; height:46" style="texture:Window; tint:#00060C; region:margin_TR; eatsmice:false"/>
					<Mask name="TLB" maskdims="dock:fill" dimensions="left:0; top:46; width:32; height:10%+5" style="texture:Window; tint:#00060C; region:margin_TL_Bridge; eatsmice:false"/>
					<Mask name="TLC" maskdims="dock:fill" dimensions="left:0; top:10%+51; width:32; height:8" style="texture:Window; tint:#00060C; region:margin_TL_Cap; eatsmice:false"/>
					<Mask name="ML" maskdims="dock:fill" dimensions="left:0; top:10%+59; width:32; bottom:100%-8" style="texture:Window; tint:#00060C; region:margin_L; eatsmice:false"/>
					<Mask name="MR" maskdims="dock:fill" dimensions="right:100%; top:46; width:28; bottom:100%-43" style="texture:Window; tint:#00060C; region:margin_R; eatsmice:false"/>
					<Mask name="BR" maskdims="dock:fill" dimensions="right:100%; bottom:100%-5; width:38; height:38" style="texture:Window; tint:#00060C; region:margin_BR; eatsmice:false"/>
				</Group>
				<Group name="frame" dimensions="left:0; right:100%; top:0; bottom:100%">
					<Mask name="TL" maskdims="dock:fill" dimensions="left:0; top:0; width:32; height:46" class="ElectricHUD" style="texture:Window; region:frame_TL; eatsmice:false"/>
					<Mask name="TM" maskdims="dock:fill" dimensions="left:32; top:0; right:100%-28; height:8" class="ElectricHUD" style="texture:Window; region:frame_TM; eatsmice:false"/>
					<Mask name="TR" maskdims="dock:fill" dimensions="width:28; top:0; right:100%; height:46" class="ElectricHUD" style="texture:Window; region:frame_TR; eatsmice:false"/>
					<Mask name="TLB" maskdims="dock:fill" dimensions="left:0; top:46; width:32; height:10%+5" class="ElectricHUD" style="texture:Window; region:frame_TL_Bridge; eatsmice:false"/>
					<Mask name="TLC" maskdims="dock:fill" dimensions="left:0; top:10%+51; width:32; height:8" class="ElectricHUD" style="texture:Window; region:frame_TL_Cap; eatsmice:false"/>
					<Mask name="ML" maskdims="dock:fill" dimensions="left:0; top:10%+59; width:32; bottom:100%-8" class="ElectricHUD" style="texture:Window; region:frame_L; eatsmice:false"/>
					<Mask name="MR" maskdims="dock:fill" dimensions="right:100%; top:46; width:28; bottom:100%-43" class="ElectricHUD" style="texture:Window; region:frame_R; eatsmice:false"/>
					<Mask name="BL" maskdims="dock:fill" dimensions="left:0; bottom:100%; width:60; height:8" class="ElectricHUD" style="texture:Window; region:frame_BL; eatsmice:false"/>
					<Mask name="BM" maskdims="dock:fill" dimensions="left:60; bottom:100%; right:100%-38; height:8" class="ElectricHUD" style="texture:Window; region:frame_BM; eatsmice:false"/>
					<Mask name="BR" maskdims="dock:fill" dimensions="right:100%; bottom:100%-5; width:38; height:38" class="ElectricHUD" style="texture:Window; region:frame_BR; eatsmice:false"/>
				</Group>
				<Group name="contents" dimensions="left:]=]..c_LeftOffset..[=[; right:100%-]=]..c_RightOffset..[=[; top:]=]..c_TopOffset..[=[; bottom:100%-]=]..c_BottomOffset..[=[" style="alpha:0"/>
			</Group>
			<Group name="header" dimensions="left:0; right:100%; height:36; top:-8" style="clip-children:true">
				<Group name="back" dimensions="dock:fill" style="alpha:0.65">
					<StillArt name="L" dimensions="left:19; top:0%; height:36; width:24" style="texture:Window; region:header_clip; eatsmice:false"/>
					<StillArt name="M" dimensions="left:43; top:0%; height:36; right:100%-38" style="texture:Window; region:header_mid; xwrap:8; eatsmice:false"/>
					<StillArt name="R" dimensions="right:100%-14; top:0%; height:36; width:24" style="texture:Window; region:header_clip_mh; eatsmice:false"/>
				</Group>
				<Group name="frame" dimensions="dock:fill">
					<StillArt name="L" dimensions="left:19; top:0%; height:36; width:24" class="ElectricHUD" style="texture:Window; region:frame_header_clip; eatsmice:false"/>
					<StillArt name="R" dimensions="right:100%-14; top:0%; height:36; width:24" class="ElectricHUD" style="texture:Window; region:frame_header_clip_mh; eatsmice:false"/>
				</Group>
				<Group name="contents" dimensions="left:41; right:100%-37; top:9; height:26">
					<Text name="title" dimensions="dock:fill" style="font:Demi_11; halign:left; valign:center; wrap:false; clip:false; padding:4"/>
				</Group>
			</Group>
			
		</FocusBox>]=], PARENT, name)};
	
	-- create widget references
	WINDOW.BODY = {GROUP=WINDOW.GROUP:GetChild("main_body")};
	WINDOW.BODY.CONTENTS = WINDOW.BODY.GROUP:GetChild("contents");
	WINDOW.BODY.FRAME = {GROUP=WINDOW.BODY.GROUP:GetChild("frame")};
	WINDOW.BODY.MARGINS = {GROUP=WINDOW.BODY.GROUP:GetChild("margins")};
	WINDOW.BODY.BACK = WINDOW.BODY.GROUP:GetChild("backPlate");
	WINDOW.HEADER = {GROUP=WINDOW.GROUP:GetChild("header")};
	WINDOW.HEADER.FRAME = {GROUP=WINDOW.HEADER.GROUP:GetChild("frame")};
	WINDOW.HEADER.BACK = WINDOW.HEADER.GROUP:GetChild("back");
	WINDOW.HEADER.CONTENTS = WINDOW.HEADER.GROUP:GetChild("contents");
	WINDOW.HEADER.TEXT = WINDOW.HEADER.CONTENTS:GetChild("title");
	for i = 1, WINDOW.BODY.FRAME.GROUP:GetChildCount() do
		local WIDGET = WINDOW.BODY.FRAME.GROUP:GetChild(i);
		WINDOW.BODY.FRAME[unicode.upper(WIDGET:GetName())] = WIDGET;
	end
	for i = 1, WINDOW.BODY.MARGINS.GROUP:GetChildCount() do
		local WIDGET = WINDOW.BODY.MARGINS.GROUP:GetChild(i);
		WINDOW.BODY.MARGINS[unicode.upper(WIDGET:GetName())] = WIDGET;
	end
	
	WINDOW.can_close = false;	-- set by EnableClose
	WINDOW.OnClose = nil;		-- callback function set by EnableClose
	
	-- initialize
	pf.WINDOW_TintBack(WINDOW, PopupWindow.DEFAULT_BACK_TINT);
	pf.WINDOW_SetTitle(WINDOW, nil);
	pf.WINDOW_Close(WINDOW, 0);
	pf.WINDOW_Open(WINDOW);
	WINDOW.HEADER.GROUP:Show(false);
	
	-- assign functions
	WINDOW.SetTitle = pf.WINDOW_SetTitle;
	WINDOW.GetBody = pf.WINDOW_GetBody;
	WINDOW.GetAdjustedSize = pf.WINDOW_GetAdjustedSize;
	WINDOW.Remove = pf.WINDOW_Destroy;
	WINDOW.TintBack = pf.WINDOW_TintBack;
	WINDOW.Open = pf.WINDOW_Open;
	WINDOW.Close = pf.WINDOW_Close;
	WINDOW.EnableClose = pf.WINDOW_EnableClose;
	
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

pf.WINDOW_SetTitle = function(WINDOW, label)
	if (label) then
		WINDOW.HEADER.GROUP:Show(true);
		WINDOW.HEADER.TEXT:SetText(label);
		WINDOW.BODY.GROUP:SetDims("bottom:_; top:28");
	else
		WINDOW.HEADER.GROUP:Show(false);
		WINDOW.HEADER.TEXT:SetText("");
		WINDOW.BODY.GROUP:SetDims("bottom:_; top:0");
	end
end

pf.WINDOW_GetBody = function(WINDOW)
	return WINDOW.BODY.CONTENTS;
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

pf.WINDOW_Open = function(WINDOW, total_dur)
	if (not total_dur) then
		total_dur = PopupWindow.OPEN_DUR;
	end
	-- initialize animation state
	WINDOW.BODY.FRAME.TL:SetMaskDims("bottom:100%; height:0; left:0; width:8");
	WINDOW.BODY.FRAME.TLB:SetMaskDims("bottom:100%; height:0;");
	WINDOW.BODY.FRAME.TLC:SetMaskDims("bottom:100%; height:0;");
	WINDOW.BODY.FRAME.TM:SetMaskDims("left:0; width:0");
	WINDOW.BODY.FRAME.TR:SetMaskDims("left:0; width:0");
	
	WINDOW.BODY.FRAME.MR:SetMaskDims("top:0; height:0");
	WINDOW.BODY.FRAME.BR:SetMaskDims("right:100%; width:0");
	WINDOW.BODY.FRAME.BM:SetMaskDims("right:100%; width:0");
	WINDOW.BODY.FRAME.BL:SetMaskDims("right:100%; width:0");
	
	WINDOW.BODY.MARGINS.TLB:SetMaskDims("left:0; width:0");
	WINDOW.BODY.MARGINS.TLC:SetMaskDims("left:0; width:0");
	WINDOW.BODY.MARGINS.TL:SetMaskDims("left:0; width:0");
	WINDOW.BODY.MARGINS.ML:SetMaskDims("left:0; width:0");
	WINDOW.BODY.MARGINS.TR:SetMaskDims("right:100%; width:0");
	WINDOW.BODY.MARGINS.MR:SetMaskDims("right:100%; width:0");
	WINDOW.BODY.MARGINS.BR:SetMaskDims("right:100%; width:0");
	
	WINDOW.HEADER.GROUP:SetDims("bottom:_; height:0");
	WINDOW.BODY.BACK:SetDims("bottom:0; height:_");
	WINDOW.BODY.CONTENTS:SetParam("alpha", 0);
	
	-- wind in clockwise from corners
	local delay = 0;
	local dur = total_dur*.9;
	WINDOW.BODY.FRAME.TLC:MaskMoveTo("dock:fill", dur*.05, dur*.00+delay, "linear");
	WINDOW.BODY.FRAME.TLB:MaskMoveTo("dock:fill", dur*.10, dur*.05+delay, "linear");
	WINDOW.BODY.FRAME.TL:MaskMoveTo("bottom:100%; top:24", dur*.10, dur*.15+delay, "linear");
	WINDOW.BODY.FRAME.TL:QueueMask("dock:fill", dur*.10, 0, "linear");
	WINDOW.BODY.FRAME.TM:MaskMoveTo("dock:fill", dur*.45, dur*.35+delay, "linear");
	WINDOW.BODY.FRAME.TR:MaskMoveTo("dock:fill", dur*.20, dur*.80+delay, "linear");
	
	WINDOW.BODY.FRAME.MR:MaskMoveTo("dock:fill", dur*.30, delay, "linear");
	WINDOW.BODY.FRAME.BR:MaskMoveTo("dock:fill", dur*.10, dur*.30+delay, "linear");
	WINDOW.BODY.FRAME.BM:MaskMoveTo("dock:fill", dur*.40, dur*.40+delay, "linear");
	WINDOW.BODY.FRAME.BL:MaskMoveTo("dock:fill", dur*.20, dur*.80+delay, "linear");
	
	-- slide in side flaps
	delay = total_dur*.6;
	dur = total_dur*.4;
	WINDOW.BODY.MARGINS.TLB:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TLC:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TL:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.ML:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TR:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.MR:MaskMoveTo("dock:fill", dur, delay, "linear");
	WINDOW.BODY.MARGINS.BR:MaskMoveTo("dock:fill", dur, delay, "linear");
	
	-- drop down back
	delay = total_dur*.7;
	dur = total_dur*.3;
	WINDOW.BODY.BACK:MoveTo(WINDOW.BODY.BACK:GetInitialDims(), dur, delay, "linear");
	for i = 1, WINDOW.BODY.BACK:GetChildCount() do
		local PIECE = WINDOW.BODY.BACK:GetChild(i);
		PIECE:SetParam("exposure", 1);
		PIECE:ParamTo("exposure", 0, dur, delay);
	end
	
	-- raise header
	WINDOW.HEADER.GROUP:MoveTo("bottom:_; height:36", dur, delay, "linear");
	
	-- fade in body
	WINDOW.BODY.CONTENTS:ParamTo("alpha", 1, total_dur*.5, total_dur*.5);
end

pf.WINDOW_Close = function(WINDOW, total_dur)
	if (not total_dur) then
		total_dur = PopupWindow.CLOSE_DUR;
	end
	-- wind out clockwise from corners
	local delay = 0;
	local dur = total_dur*.9;
	WINDOW.BODY.FRAME.TLC:MaskMoveTo("top:0; height:0", dur*.05, delay, "linear");
	WINDOW.BODY.FRAME.TLB:MaskMoveTo("top:0; height:0", dur*.10, delay, "linear");
	WINDOW.BODY.FRAME.TL:MaskMoveTo("bottom:24; top:0", dur*.10, dur*.15 + delay, "linear");
	WINDOW.BODY.FRAME.TL:QueueMask("right:100%; width:0", dur*.10, 0, "linear");
	WINDOW.BODY.FRAME.TM:MaskMoveTo("right:100%; width:0", dur*.40, dur*.35+delay, "linear");
	WINDOW.BODY.FRAME.TR:MaskMoveTo("right:100%; width:0", dur*.20, dur*.75+delay, "linear");
	
	WINDOW.BODY.FRAME.MR:MaskMoveTo("bottom:100%; height:0", dur*.25, delay, "linear");
	WINDOW.BODY.FRAME.BR:MaskMoveTo("left:0; width:0", dur*.10, dur*.25+delay, "linear");
	WINDOW.BODY.FRAME.BM:MaskMoveTo("left:0; width:0", dur*.30, dur*.35+delay, "linear");
	WINDOW.BODY.FRAME.BL:MaskMoveTo("left:0; width:0", dur*.20, dur*.65+delay, "linear");
	
	-- slide out side flaps
	delay = total_dur*.0;
	dur = total_dur*.5;
	WINDOW.BODY.MARGINS.TLB:MaskMoveTo("left:0; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TLC:MaskMoveTo("left:0; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TL:MaskMoveTo("left:0; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.ML:MaskMoveTo("left:0; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.TR:MaskMoveTo("right:100%; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.MR:MaskMoveTo("right:100%; width:0", dur, delay, "linear");
	WINDOW.BODY.MARGINS.BR:MaskMoveTo("right:100%; width:0", dur, delay, "linear");
	
	-- raise back
	delay = total_dur*.0;
	dur = total_dur*.3;
	WINDOW.BODY.BACK:MoveTo("bottom:0; height:_", dur, delay, "linear");
	
	-- lower header
	WINDOW.HEADER.GROUP:MoveTo("bottom:_; height:0", dur, delay, "linear");
	
	-- fade out body
	WINDOW.BODY.CONTENTS:ParamTo("alpha", 0, total_dur*.5, 0);
end

pf.WINDOW_TintBack = function(WINDOW, tint, dur, delay)
	if (not delay) then delay = 0; end;
	if (not dur) then dur = 0; end;
	for i = 1, WINDOW.BODY.BACK:GetChildCount() do
		WINDOW.BODY.BACK:GetChild(i):ParamTo("tint", tint, dur, delay);
	end
	for i = 1, WINDOW.HEADER.BACK:GetChildCount() do
		WINDOW.HEADER.BACK:GetChild(i):ParamTo("tint", tint, dur, delay);
	end
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
			WINDOW.HEADER.X_FOCUS = Component.CreateWidget('<FocusBox name="focus" dimensions="center-x:50%; center-y:50%; width:20; height:20;"/>', WINDOW.HEADER.X);
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
