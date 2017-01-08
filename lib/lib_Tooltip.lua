

--
-- lib_Tooltip
--	by: John Su
--
--	for showing a 2D tooltip that follows the mouse

--[[

	Tooltip.Show(string/WIDGET[, args])	-- shows either a string or a WIDGET in the tooltip (TextFormat also supported)
											if nil/false, hides the tooltip
											args: an optional table with optional params:
												- width (number): tooltip will be resized to match this width
												- height (number): tooltip will be resized to match this height
												- halign (string): "left" "right" or "center"; will align the string
												- frame_color (string/number): tooltip framing will be tinted to this color
												- delay (number): number of seconds to delay until the tooltip appears
--]]

-- create an alias for now to point "ToolTip" to "Tooltip"
ToolTip = {};
setmetatable(ToolTip, {__index = function(t,key)
	warn("ToolTip has been renamed to Tooltip ('t' vs 'T'); please update calls.");
	return Tooltip[key];
end});


require "lib/lib_TextFormat"

Tooltip = {};
local PRIVATE = {};

local ELEMENTS = {};

local cb_DisplayTooltip = nil

-- create elements
ELEMENTS.FRAME = Component.CreateFrame("OverlayFrame");
ELEMENTS.GROUP = Component.CreateWidget([[<Group dimensions="dock:fill">
		<Border dimensions="center-x:50%; center-y:50%; width:100%-2; height:100%-2" class="ButtonSolid" style="tint:#000000; alpha:0.9; padding:4"/> 
		<Border name="rim" dimensions="dock:fill" class="ButtonBorder" style="alpha:0.1; exposure:1.0; padding:4"/>
		<Group name="contents" dimensions="left:5; right:100%-5; top:5; bottom:100%-5"/>
</Group>]], ELEMENTS.FRAME);
ELEMENTS.RIM = ELEMENTS.GROUP:GetChild("rim");
ELEMENTS.CONTENT_HOLDER = ELEMENTS.GROUP:GetChild("contents");
ELEMENTS.TEXT = Component.CreateWidget('<Text name="text" dimensions="dock:fill" style="font:Demi_10; halign:center; valign:center; wrap:true; padding:0"/>', ELEMENTS.CONTENT_HOLDER);
ELEMENTS.FOSTER_WIDGET = nil;
ELEMENTS.FRAME:SetParam("alpha", 0);

function Tooltip.Show(tip, args)
	if cb_DisplayTooltip then
		cancel_callback(cb_DisplayTooltip)
		cb_DisplayTooltip = nil
	end
	if (ELEMENTS.FOSTER_WIDGET) then
		-- drop the current foster widget
		if (Component.IsWidget(ELEMENTS.FOSTER_WIDGET)) then
			Component.FosterWidget(ELEMENTS.FOSTER_WIDGET, nil);
		end
		ELEMENTS.FOSTER_WIDGET = nil;
	end
	args = args or {};	-- helps us avoid doing an 'if args' check before accessing
	if (not tip) then
		if type(args.delay) == "number" and args.delay > 0 then
			cb_DisplayTooltip = callback(function()
				cb_DisplayTooltip = nil;
				PRIVATE.HideTooltip()
			end, nil, args.delay)
		else
			PRIVATE.HideTooltip()
		end
	else
		if type(args.delay) == "number" and args.delay > 0 then
			cb_DisplayTooltip = callback(function()
				cb_DisplayTooltip = nil;
				PRIVATE.ShowTooltip(tip, args)
			end, nil, args.delay)
		else
			PRIVATE.ShowTooltip(tip, args)
		end
	end
end

function PRIVATE.HideTooltip()
	ELEMENTS.FRAME:ParamTo("alpha", 0, 0.05);
end

function PRIVATE.ShowTooltip(tip, args)
	local bounds;
	local tipType = type(tip);
	if (tipType == "number") then
		tip = tostring(tip);
		tipType = "string";
	end
	if (tipType == "string" or TextFormat.IsTextFormat(tip)) then	-- string or TextFormat
		TextFormat.Clear(ELEMENTS.TEXT);
		if (tipType == "string") then
			ELEMENTS.TEXT:SetText(tip);
		else
			tip:ApplyTo(ELEMENTS.TEXT);
		end
		ELEMENTS.TEXT:SetAlignment("halign", args.halign or "center");
		
		ELEMENTS.GROUP:SetDims("left:_; top:_; width:"..((args.width or 400)+20).."; height:100%");	-- defaults dims for text
		bounds = ELEMENTS.TEXT:GetTextDims(tip, false);
		-- pad it
		bounds.width = bounds.width + 8;
		bounds.height = bounds.height + 8;
	elseif (Component.IsWidget(tip)) then
		ELEMENTS.TEXT:SetText("");
		-- foster this child
		ELEMENTS.FOSTER_WIDGET = tip;
		Component.FosterWidget(ELEMENTS.FOSTER_WIDGET, ELEMENTS.CONTENT_HOLDER, "full");
		bounds = ELEMENTS.FOSTER_WIDGET:GetBounds();
	else
		error("bad tip ("..(type(tip)).."); must be string or widget");
	end
	-- substitute explicit bounds
	bounds.width = args.width or bounds.width;
	bounds.height = args.height or bounds.height
	
	ELEMENTS.RIM:SetParam("tint", args.frame_color or "#ffffff");
	ELEMENTS.RIM:SetParam("alpha", args.alpha or 0.1)
	
	-- resize
	local mouseX, mouseY = Component.GetCursorPos();
	local screen_width, screen_height = Component.GetScreenSize();
	local group_halign, group_valign;
	if mouseX + bounds.width + 40 < screen_width then
		group_halign = "left:50%+20"
	elseif mouseX > bounds.width + 20 then
		group_halign = "right:50%-10"
	elseif screen_width < bounds.width then
		group_halign = "left:50%-"..mouseX - 20
	else
		group_halign = "left:50%-"..mouseX / screen_width * bounds.width
	end
	if mouseY + bounds.height + 40 < screen_height then
		group_valign = "top:50%+20"
	elseif mouseY > bounds.height + 20 then
		group_valign = "bottom:50%-10"
	elseif screen_height < bounds.height then
		group_valign = "top:50%-"..mouseY - 20
	else
		group_valign = "top:50%-"..mouseY / screen_height * bounds.height
	end
	ELEMENTS.GROUP:SetDims("relative:cursor; "..group_halign.."; "..group_valign.."; width:"..(bounds.width+10).."; height:"..(bounds.height+10));
	ELEMENTS.FRAME:ParamTo("alpha", 1, 0.05);
end
