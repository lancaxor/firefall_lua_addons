
--
-- lib_LightWindow
--   by: John Su
--
--	This is a small light-weight window

require "table"

-- LightWindow Interface:
LightWindow = {
	OPEN_DUR = 0.4,
	CLOSE_DUR = 0.4,
	
	STYLE_NORMAL = "normal",
	--Right Aligned
	STYLE_ANCHOR_RIGHT = "anchor_right",
	STYLE_ANCHOR_BOTTOM_RIGHT = "anchor_bottom_right",
	STYLE_HEAVY_ANCHOR_TOP_RIGHT = "heavy_anchor_top_right",
	STYLE_SHELVER_RIGHT = "shelver_right",
	STYLE_SHELF_RIGHT = "shelf_right",
	--Left Aligned
	STYLE_ANCHOR_LEFT = "anchor_left",
	STYLE_ANCHOR_TOP_LEFT = "anchor_top_left",
	STYLE_ANCHOR_BOTTOM_LEFT = "anchor_bottom_left",
	STYLE_SHELVER_LEFT = "shelver_left",
	STYLE_SHELF_LEFT = "shelf_left",
};

require "unicode"

--[[ INTERFACE
	WINDOW = LightWindow.Create(parent[, style, name])	-- style may be "normal", "open_left", or "open_right"
	WINDOW:TintFrame(color[, dur])
	WINDOW:TintBack(color[, dur])
	WINDOW:SetClipChildren(true/false)
	true/false = WINDOW:GetClipChildren()
	WINDOW:Remove()
	<GroupWidget> = WINDOW:GetBody()
--]]


-- constants
-- local frame styles
local FSTYLE_NONE = 0;
local FSTYLE_SINGLE = 1;	-- corner only
local FSTYLE_DOUBLE = 2;	-- corner only
local FSTYLE_THICK = 3;		-- corner  & bridge
local FSTYLE_SHELF = 4;		-- corner only
local FSTYLE_FADE = 5;		-- bridge only
local FSTYLE_SOLID = 6;		-- bridge only

local pf = {};	-- private functions

-- variables


LightWindow.Create = function(PARENT, style, name)
	local WINDOW = pf.WINDOW_Create(PARENT, style, name);
	return WINDOW;
end

pf.DimsToString = function(dims)
	local str = "";
	for dim,val in pairs(dims) do
		str = str..dim..":"..val[1];
		if (val[2] and val[2] ~= 0) then
			if (val[2] > 0) then	str = str.."+"..val[2].."%";
			else					str = str..val[2].."%";
			end
		end
		str = str.."; ";
	end
	return str;
end

-- WINDOW

pf.WINDOW_Create = function(PARENT, style, name)
	-- create widget
	
	if (not style) then
		style = LightWindow.STYLE_NORMAL;
	end
	local framing;
	local margins = {left=2, right=2, top=2, bottom=2};
	
	if ( style == LightWindow.STYLE_NORMAL ) then
		framing = {	TL=FSTYLE_DOUBLE,	TM=FSTYLE_SOLID,	TR=FSTYLE_SINGLE,
					ML=FSTYLE_SOLID,						MR=FSTYLE_SOLID,
					BL=FSTYLE_SINGLE,	BM=FSTYLE_SOLID,	BR=FSTYLE_DOUBLE};
		
	elseif ( style == LightWindow.STYLE_ANCHOR_LEFT ) then
		framing = {	TL=FSTYLE_SINGLE,	TM=FSTYLE_FADE,		TR=FSTYLE_NONE,
					ML=FSTYLE_SOLID,						MR=FSTYLE_NONE,
					BL=FSTYLE_SINGLE,	BM=FSTYLE_FADE,		BR=FSTYLE_NONE};
		
	elseif ( style == LightWindow.STYLE_ANCHOR_RIGHT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_FADE,		TR=FSTYLE_SINGLE,
					ML=FSTYLE_NONE,							MR=FSTYLE_SOLID,
					BL=FSTYLE_NONE,		BM=FSTYLE_FADE,		BR=FSTYLE_SINGLE};
		
	elseif ( style == LightWindow.STYLE_ANCHOR_TOP_LEFT ) then
		framing = {	TL=FSTYLE_SINGLE,	TM=FSTYLE_FADE,		TR=FSTYLE_NONE,
					ML=FSTYLE_SOLID,						MR=FSTYLE_NONE,
					BL=FSTYLE_NONE,		BM=FSTYLE_NONE,		BR=FSTYLE_NONE};
		
	elseif ( style == LightWindow.STYLE_ANCHOR_BOTTOM_RIGHT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_NONE,		TR=FSTYLE_NONE,
					ML=FSTYLE_NONE,							MR=FSTYLE_SOLID,
					BL=FSTYLE_NONE,		BM=FSTYLE_FADE,		BR=FSTYLE_SINGLE};
	
	elseif ( style == LightWindow.STYLE_ANCHOR_BOTTOM_LEFT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_NONE,		TR=FSTYLE_NONE,
					ML=FSTYLE_SOLID,						MR=FSTYLE_NONE,
					BL=FSTYLE_SINGLE,	BM=FSTYLE_FADE,		BR=FSTYLE_NONE};
	
	elseif ( style == LightWindow.STYLE_SHELVER_RIGHT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_FADE,		TR=FSTYLE_SINGLE,
					ML=FSTYLE_NONE,							MR=FSTYLE_SOLID,
					BL=FSTYLE_NONE,		BM=FSTYLE_FADE,		BR=FSTYLE_DOUBLE};
	
	elseif ( style == LightWindow.STYLE_SHELF_RIGHT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_NONE,		TR=FSTYLE_NONE,
					ML=FSTYLE_NONE,							MR=FSTYLE_NONE,
					BL=FSTYLE_NONE,		BM=FSTYLE_FADE,		BR=FSTYLE_SHELF};
	
	elseif ( style == LightWindow.STYLE_SHELVER_LEFT ) then
		framing = {	TL=FSTYLE_SINGLE,	TM=FSTYLE_FADE,		TR=FSTYLE_NONE,
					ML=FSTYLE_SOLID,						MR=FSTYLE_NONE,
					BL=FSTYLE_DOUBLE,	BM=FSTYLE_FADE,		BR=FSTYLE_NONE};
	
	elseif ( style == LightWindow.STYLE_SHELF_LEFT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_NONE,		TR=FSTYLE_NONE,
					ML=FSTYLE_NONE,							MR=FSTYLE_NONE,
					BL=FSTYLE_SHELF,	BM=FSTYLE_FADE,		BR=FSTYLE_NONE};
		
	elseif ( style == LightWindow.STYLE_HEAVY_ANCHOR_TOP_RIGHT ) then
		framing = {	TL=FSTYLE_NONE,		TM=FSTYLE_FADE,		TR=FSTYLE_THICK,
					ML=FSTYLE_NONE,							MR=FSTYLE_THICK,
					BL=FSTYLE_NONE,		BM=FSTYLE_NONE,		BR=FSTYLE_NONE};
		
	else
		warn("Style "..tostring(style).." not yet implemented.");
		framing = {TL=FSTYLE_NONE, TR=FSTYLE_NONE, BL=FSTYLE_NONE, BR=FSTYLE_NONE};
	end
	
	-- framing
	local defs = {};
	-- def[portion] = {dims={field={pixel[, percent]}, region}
	
	-- top left
	if (framing.TL == FSTYLE_SINGLE) then
		defs.TL = {dims={left={0,0}, top={0,0}, width={11}, height={9}}, region="lightFrame_corner1"};
	elseif (framing.TL == FSTYLE_DOUBLE) then
		defs.TL = {dims={left={0,0}, top={0,0}, width={13}, height={9}}, region="lightFrame_corner2"};
	elseif (framing.TL == FSTYLE_THICK) then
		defs.TL = {dims={left={0,0}, top={0,0}, width={21}, height={45}}, region="lightFrame_corner3"};
		margins.left = 10;
	end
	
	-- top right
	if (framing.TR == FSTYLE_SINGLE) then
		defs.TR = {dims={right={0,100}, top={0,0}, width={11}, height={9}}, region="lightFrame_corner1_mh"};
	elseif (framing.TR == FSTYLE_DOUBLE) then
		defs.TR = {dims={right={0,100}, top={0,0}, width={13}, height={9}}, region="lightFrame_corner2_mh"};
	elseif (framing.TR == FSTYLE_THICK) then
		defs.TR = {dims={right={0,100}, top={0,0}, width={21}, height={45}}, region="lightFrame_corner3_mh"};
		margins.right = 10;
	end
	
	-- bottom left
	if (framing.BL == FSTYLE_SINGLE) then
		defs.BL = {dims={left={0,0}, bottom={0,100}, width={11}, height={9}}, region="lightFrame_corner1_mv"};
	elseif (framing.BL == FSTYLE_DOUBLE) then
		defs.BL = {dims={left={0,0}, bottom={0,100}, width={13}, height={9}}, region="lightFrame_corner2_mv"};
	elseif (framing.BL == FSTYLE_SHELF) then
		defs.BL = {dims={left={0,0}, bottom={0,100}, width={9}, height={9}}, region="lightShelf_BL"};
	end
	
	-- bottom right
	if (framing.BR == FSTYLE_SINGLE) then
		defs.BR = {dims={right={0,100}, bottom={0,100}, width={11}, height={9}}, region="lightFrame_corner1_md"};
	elseif (framing.BR == FSTYLE_DOUBLE) then
		defs.BR = {dims={right={0,100}, bottom={0,100}, width={13}, height={9}}, region="lightFrame_corner2_md"};
	elseif (framing.BR == FSTYLE_SHELF) then
		defs.BR = {dims={right={0,100}, bottom={0,100}, width={9}, height={9}}, region="lightShelf_BR"};
	end
	
	-- top middle
	if (framing.TM ~= FSTYLE_NONE) then
		defs.TM = {dims={ top={0,0}, height={1}, left={0,0}, right={0,100} }};
		if (defs.TL) then
			defs.TM.dims.left = {defs.TL.dims.left[1]+defs.TL.dims.width[1], defs.TL.dims.left[2]};
		end
		if (defs.TR) then
			defs.TM.dims.right = {defs.TR.dims.right[1]-defs.TR.dims.width[1], defs.TR.dims.right[2]};
		end
		if (framing.TM == FSTYLE_SOLID) then
			defs.TM.dims.height = {9};
			defs.TM.region = "lightFrame_TM";
		elseif (framing.TM == FSTYLE_FADE) then
			if (framing.TL ~= FSTYLE_NONE) then
				defs.TM.region = "lightFrame_fade_TM";
			else
				defs.TM.region = "lightFrame_fade_TM_mh";
			end
		end
	end
	
	-- bottom middle
	if (framing.BM ~= FSTYLE_NONE) then
		defs.BM = {dims={ bottom={0,100}, height={1}, left={0,0}, right={0,100} }};
		if (defs.BL) then
			defs.BM.dims.left = {defs.BL.dims.left[1]+defs.BL.dims.width[1], defs.BL.dims.left[2]};
		end
		if (defs.BR) then
			defs.BM.dims.right = {defs.BR.dims.right[1]-defs.BR.dims.width[1], defs.BR.dims.right[2]};
		end
		if (framing.BM == FSTYLE_SOLID) then
			defs.BM.dims.height = {9};
			defs.BM.region = "lightFrame_BM";
		elseif (framing.BM == FSTYLE_FADE) then
			if (framing.BL ~= FSTYLE_NONE) then
				defs.BM.region = "lightFrame_fade_BM";
			else
				defs.BM.region = "lightFrame_fade_BM_mh";
			end
		end
	end
	
	-- middle left
	if (framing.ML == FSTYLE_SOLID) then
		defs.ML = {dims={ left={0,0}, width={11}, top={0,0}, bottom={0,100} }};
		if (defs.TL) then
			defs.ML.dims.top = {defs.TL.dims.top[1]+defs.TL.dims.height[1], defs.TL.dims.top[2]};
		end
		if (defs.BL) then
			defs.ML.dims.bottom = {defs.BL.dims.bottom[1]-defs.BL.dims.height[1], defs.BL.dims.bottom[2]};
		end
		defs.ML.region = "lightFrame_ML";
	end
	
	-- middle right
	if (framing.MR == FSTYLE_SOLID) then
		defs.MR = {dims={right={0,100},width={11},top={0,0},bottom={0,100}}};
		if (defs.TR) then
			defs.MR.dims.top = {defs.TR.dims.top[1]+defs.TR.dims.height[1], defs.TR.dims.top[2]};
		end
		if (defs.BR) then
			defs.MR.dims.bottom = {defs.BR.dims.bottom[1]-defs.BR.dims.height[1], defs.BR.dims.bottom[2]};
		end
		defs.MR.region = "lightFrame_ML_mh";
	end
	
	local fmt = [=[<Mask name="%s" maskdims="dock:fill" dimensions="%s" class="ElectricHUD" style="texture:Window_Light; region:%s"/>]=];
	
	local framing_def = "";
	for part,def in pairs(defs) do
		local def_str = unicode.format(fmt, part, pf.DimsToString(def.dims), def.region);
		framing_def = framing_def.."\n"..def_str;
	end
	
	-- shadows
	defs = {};
	if (framing.TL ~= FSTYLE_NONE) then
		defs.TL  = {dims={left={margins.left,0}, top={margins.top,0}, width={8}, height={8}}, region="backShade_corner"};
		defs.TLH = {dims={left={margins.left+8,0}, top={margins.top,0}, right={-margins.right,100}, height={8}}, region="backShade_horz"};
		defs.TLV = {dims={left={margins.left,0}, top={margins.top+8,0}, bottom={-margins.bottom,100}, width={8}}, region="backShade_vert"};
		defs.TLB = {dims={left={margins.left+8,0}, top={margins.top+8,0}, bottom={-margins.bottom,100}, right={-margins.right,100}}, region="backShade_body"};
	end
	if (framing.TR ~= FSTYLE_NONE) then
		defs.TR  = {dims={right={-margins.right,100}, top={margins.top,0}, width={8}, height={8}}, region="backShade_corner_mh"};
		defs.TRH = {dims={right={-margins.right-8,100}, top={margins.top,0}, left={margins.left,0}, height={8}}, region="backShade_horz_mh"};
		defs.TRV = {dims={right={-margins.right,100}, top={margins.top+8,0}, bottom={-margins.bottom,100}, width={8}}, region="backShade_vert_mh"};
		defs.TRB = {dims={right={-margins.right-8,100}, top={margins.top+8,0}, bottom={-margins.bottom,100}, left={margins.left,0}}, region="backShade_body_mh"};
	end
	if (framing.BL ~= FSTYLE_NONE) then
		defs.BL  = {dims={left={margins.left,0}, bottom={-margins.bottom,100}, width={8}, height={8}}, region="backShade_corner_mv"};
		defs.BLH = {dims={left={margins.left+8,0}, bottom={-margins.bottom,100}, right={-margins.right,100}, height={8}}, region="backShade_horz_mv"};
		defs.BLV = {dims={left={margins.left,0}, bottom={-margins.bottom-8,100}, top={margins.top,0}, width={8}}, region="backShade_vert_mv"};
		defs.BLB = {dims={left={margins.left+8,0}, bottom={-margins.bottom-8,100}, top={margins.top,0}, right={-margins.right,100}}, region="backShade_body_mv"};
	end
	if (framing.BR ~= FSTYLE_NONE) then
		defs.BR  = {dims={right={-margins.right,100}, bottom={-margins.bottom,100}, width={8}, height={8}}, region="backShade_corner_md"};
		defs.BRH = {dims={right={-margins.right-8,100}, bottom={-margins.bottom,100}, left={margins.left,0}, height={8}}, region="backShade_horz_md"};
		defs.BRV = {dims={right={-margins.right,100}, bottom={-margins.bottom-8,100}, top={margins.top,0}, width={8}}, region="backShade_vert_md"};
		defs.BRB = {dims={right={-margins.right-8,100}, bottom={-margins.bottom-8,100}, top={margins.top,0}, left={margins.left,0}}, region="backShade_body_md"};
	end	
	
	local shadow_def = "";
	fmt = [=[<StillArt name="%s" dimensions="%s" style="texture:Window_Light; tint:#000000; region:%s"/>]=];
	for part,def in pairs(defs) do
		local def_str = unicode.format(fmt, part, pf.DimsToString(def.dims), def.region);
		shadow_def = shadow_def.."\n"..def_str;
	end
	
	-- special framing
	local fram2_def = "";
	if (framing.ML == FSTYLE_THICK or framing.MR == FSTYLE_THICK) then
		defs = {};
		if (framing.ML == FSTYLE_THICK) then
			defs.TLM = {dims={left={0,0}, top={0,0}, width={21}, height={45}}, region="lightFrame_corner3_back"};
			defs.ML = {dims={left={0,0}, top={45,0}, width={21}, bottom={0,100}}, region="lightFrame_corner3_vert_back"};
		end
		if (framing.MR == FSTYLE_THICK) then
			defs.TRM = {dims={right={0,100}, top={0,0}, width={21}, height={45}}, region="lightFrame_corner3_back_mh"};
			defs.MR = {dims={right={0,100}, top={45,0}, width={21}, bottom={0,100}}, region="lightFrame_corner3_vert_back_mh"};
		end
		
		fmt = [=[<StillArt name="%s" dimensions="%s" style="texture:Window_Light; region:%s"/>]=];
		for part,def in pairs(defs) do
			local def_str = unicode.format(fmt, part, pf.DimsToString(def.dims), def.region);
			fram2_def = fram2_def.."\n"..def_str;
		end
	end
	
	local WINDOW = {GROUP=Component.CreateWidget(
		[=[<Group dimensions="dock:fill">
			<Group name="shadow" dimensions="left:0; right:100%; top:0; bottom:100%" style="alpha:0.5">
				]=]..shadow_def..[=[
			</Group>
			<Group name="body" dimensions="left:10; right:100%-10; top:8; bottom:100%-8" style="clip-children:true; alpha:1"/>
			<Group name="framing" dimensions="left:0; right:100%; top:0; bottom:100%" style="clip-children:true">
				<Group name="special" dimensions="dock:fill">
					]=]..fram2_def..[=[
				</Group>
				]=]..framing_def..[=[
			</Group>
			
		</Group>]=], PARENT, name)};
	
	-- create widget references
	WINDOW.BODY = WINDOW.GROUP:GetChild("body");
	WINDOW.FRAMING = {GROUP=WINDOW.GROUP:GetChild("framing")};
	WINDOW.SHADOW = {GROUP=WINDOW.GROUP:GetChild("shadow")};
	for i = 1, WINDOW.FRAMING.GROUP:GetChildCount() do
		local WIDGET = WINDOW.FRAMING.GROUP:GetChild(i);
		WINDOW.FRAMING[unicode.upper(WIDGET:GetName())] = WIDGET;
	end
	for i = 1, WINDOW.SHADOW.GROUP:GetChildCount() do
		local WIDGET = WINDOW.SHADOW.GROUP:GetChild(i);
		WINDOW.SHADOW[unicode.upper(WIDGET:GetName())] = WIDGET;
	end
	
	-- initialize
	
	-- assign functions
	WINDOW.Open = pf.WINDOW_Open;
	WINDOW.Close = pf.WINDOW_Close;
	WINDOW.GetBody = pf.WINDOW_GetBody;
	WINDOW.Remove = pf.WINDOW_Destroy;
	WINDOW.TintFrame = pf.WINDOW_TintFrame;
	WINDOW.TintBack = pf.WINDOW_TintBack;
	WINDOW.SetClipChildren = pf.WINDOW_SetClipChildren;
	WINDOW.GetClipChildren = pf.WINDOW_GetClipChildren;
	
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
	
	return WINDOW;
end

pf.WINDOW_Destroy = function(WINDOW)
	Component.RemoveWidget(WINDOW.GROUP);
	for k,v in pairs(WINDOW) do
		WINDOW[k] = nil;
	end
end

pf.WINDOW_SetClipChildren = function(WINDOW, clip)
	WINDOW.BODY:SetClipChildren(clip);
end

pf.WINDOW_GetClipChildren = function(WINDOW)
	return WINDOW.BODY:GetClipChildren();
end

pf.WINDOW_GetBody = function(WINDOW)
	return WINDOW.BODY;
end

pf.WINDOW_Open = function(WINDOW, total_dur)
	if (not total_dur) then
		total_dur = LightWindow.OPEN_DUR;
	end
	
	-- fade in body
	WINDOW.GROUP:ParamTo("alpha", 1, total_dur*.5, total_dur*.5);
end

pf.WINDOW_Close = function(WINDOW, dur)
	if (not total_dur) then
		total_dur = LightWindow.CLOSE_DUR;
	end
	
	-- fade out body
	WINDOW.GROUP:ParamTo("alpha", 0, total_dur*.5, 0);
end

pf.WINDOW_TintFrame = function(WINDOW, color, dur)
	if (not dur) then
		dur = 0;
	end
	local glow = color;
	if (type(glow) == "string") then
		glow = Component.LookupColor(glow);
		if (not glow) then
			warn(tostring(color));
		end
	end
	glow = "#80"..glow.rgb;
	for k,v in pairs(WINDOW.FRAMING) do
		if (k ~= "GROUP" and k ~= "SPECIAL") then
			v:ParamTo("tint", color, dur);
			v:ParamTo("glow", glow, dur);
		end
	end
end

pf.WINDOW_TintBack = function(WINDOW, color, dur)
	if (not dur) then
		dur = 0;
	end
	for k,v in pairs(WINDOW.SHADOW) do
		if (k ~= "GROUP") then
			v:ParamTo("tint", color, dur);
		end
	end
end
