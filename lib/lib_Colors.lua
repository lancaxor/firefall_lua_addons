
--
-- lib_Colors
--   by: John Su
--
-- For reading and manipulating colors

--[[
-- INTERFACE

	COLOR = Colors.Create(base)			-- [base] can be either a table or a string
											(either a name or a "RRGGBB" / "AARRGGBB" / "RRGGBB,A%" format)
											returns a COLOR object
												
	COLOR = Colors.Mix(color_1, color_2, interp)
										-- interpolates a color between color_1 (interp = 0) and color_2 (interp = 1)
										
	COLOR_PRODUCT = Colors.Multiply(color, scalars)
										-- [scalars] is a table of {r,g,b,a}, or a single number
											returns a multiplied version of the input COLOR, multiplying only the supplied channels
	COLOR_SUM = Colors.Add(color, offset)
										-- [offset] is a table of {r,g,b,a} offsets, or a single number
											returns a summed version of the input color, adding only the supplied channels
	
	COLOR = Colors.MakeGradient(type, input)
										-- creates a gradient of colors; valid types are:
											"condition" - input goes from 0->1 (red->yellow->white)
											
	{h,s,v} = Colors.toHSV(base)		-- returns a hue/saturation/value table from an input color
	
	linear = Colors.sRGBtoLinear(color) -- transforms srgb range to linear range for use by scene objects and 3d gui
	
	COLOR public members:
		COLOR.a	= alpha [0,1]	(defaults to 1)
		COLOR.r	= red [0,1]		(defaults to 0)
		COLOR.g	= green [0,1]	(defaults to 0)
		COLOR.b	= blue [0,1]	(defaults to 0)
		
	COLOR get/set methods:
		COLOR.h = hue [0,360]
		COLOR.s = saturation [0,1]
		COLOR.v = value [0,1]
	
	COLOR methods:
		COLOR:toRGB()					-- returns a string of format "#RRGGBB"
		COLOR:toARGB()					-- returns a string of format "#AARRGGBB"
		COLOR:toRGBA()					-- returns a string of format "#RRGGBB,A%"
		COLOR:toTable()					-- returns a table with {r,g,b,a} (normalized)
		COLOR:toHSV()					-- returns a table with {h,s,v} (hue [0,360], saturation [0,1], value [0,1]); can be supplied to Colors.Create()
		COLOR:Clone()					-- returns a clone of the COLOR		
		COLOR:Multiply(scalar)			-- multiplies channels (in place); [scalar] can be a single number or an {r,g,b,a} table of scalars
		COLOR:Add(offset)				-- sums channels (in place); [offset] can be a single number or an {r,g,b,a} table of offsets
		
		COLOR:toRGB565()				-- returns an integer representation of the color in 16-bit space
--]]

Colors = {};

require "math"
require "unicode"

local COLORS_API = {};
local PRIVATE = {};

local CHANNELS = {"r","g","b","a"};
local GETSET = {"h", "s", "v"};

function Colors.Create(ref)
	local COLOR = PRIVATE.CreateColor();
	local rgb = PRIVATE.CreateRgbTable(ref);
	
	COLOR.r = rgb.r or COLOR.r;
	COLOR.g = rgb.g or COLOR.g;
	COLOR.b = rgb.b or COLOR.b;
	COLOR.a = rgb.a or COLOR.a;
	
	return COLOR;
end

function Colors.Mix(COLOR_A, COLOR_B, interp)
	interp = interp or 0.5
	local COLOR_C = PRIVATE.CreateColor();
	COLOR_A = PRIVATE.EnsureCOLOR(COLOR_A);
	COLOR_B = PRIVATE.EnsureCOLOR(COLOR_B);
	for i,c in ipairs(CHANNELS) do
		COLOR_C[c] = COLOR_A[c]*(1-interp) + COLOR_B[c]*interp;
	end
	return COLOR_C;
end

function Colors.Add(COLOR, offset)
	local COLOR_SUM;
	if (not PRIVATE.IsCOLOR(COLOR)) then
		COLOR_SUM = Colors.Create(COLOR);
	else
		COLOR_SUM = COLOR:Clone();
	end
	COLOR_SUM:Add(offset);
	return COLOR_SUM;
end

function Colors.Multiply(COLOR, scalar)
	local COLOR_PRODUCT;
	if (not PRIVATE.IsCOLOR(COLOR)) then
		COLOR_PRODUCT = Colors.Create(COLOR);
	else
		COLOR_PRODUCT = COLOR:Clone();
	end
	COLOR_PRODUCT:Multiply(scalar);
	return COLOR_PRODUCT;
end

function Colors.MakeGradient(type, input)
	if (type == "condition") then
		percent = math.max(0, math.min(input, 1));
		return Colors.Create({
			r=1,
			g=math.min(1,1.5*percent),
			b=math.max(0,1-3*(1-percent)),
		});
	elseif (type == "warning") then
		-- light warning (pale yellow) to heavy warning (deep orange); no red, since red = error
		percent = math.max(0, math.min(input, 1));
		return Colors.Create({
			r=1,
			g=math.min(1, 1.2 - .66*percent),
			b=math.max(0, .66 - .33*percent),
		});
	else
		error("invalid type '"..type.."'; see lib_Colors.lua for valid types");
	end
end

function Colors.toHSV(ref)
	local rgb = PRIVATE.CreateRgbTable(ref);
	return PRIVATE.RGBtoHSV(rgb.r, rgb.g, rgb.b);
end

function Colors.sRGBtoLinear(input)
	local rgb = PRIVATE.CreateRgbTable(input);
	local linear = {};
	for i,c in ipairs(CHANNELS) do
		if c == "a" then break end
		linear[c] = PRIVATE.sRGBtoLinear(rgb[c]);
	end
	return linear;
end

function Colors.MatchColorOnWidget(WIDGET, baseColor, newColor)
	local baseHSV = Colors.toHSV(baseColor)
	local newHSV = Colors.toHSV(newColor)

	local hueOffset = math.abs(baseHSV.h - newHSV.h) / 360
	WIDGET:SetParam("hue", hueOffset)

	WIDGET:SetParam("saturation", newHSV.s)
end

---------------
-- COLOR API --
---------------
local COLORS_METATABLE = {
	__index = function(t,key) return COLORS_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in COLOR"); end
 };

function PRIVATE.CreateColor()
	local COLOR = {r=0,g=0,b=0,a=1};
	-- copy methods
	setmetatable(COLOR, COLORS_METATABLE);
	return COLOR;
end

function PRIVATE.CreateRgbTable(ref)
	local ref_type = type(ref);
	if (ref_type == "string") then
		local rgb = Component.LookupColor(ref);
		assert(rgb, "invalid color: "..tostring(ref));
		return {r=rgb.r, g=rgb.g, b=rgb.b, a=rgb.a};
	elseif (ref_type == "number") then
		error("number to rgb conversion not supported yet");
	elseif (ref_type == "table") then
		if (ref.h and ref.s and ref.v) then
			-- construct from an HSV table
			return PRIVATE.HSVtoRGB(ref.h, ref.s, ref.v);
		end
		return ref;
	else
		error("invalid color: "..tostring(ref));
	end
end

function COLORS_API.toRGB(COLOR)
	return unicode.format("#%02X%02X%02X", PRIVATE.ConstrainHex(COLOR.r), PRIVATE.ConstrainHex(COLOR.g), PRIVATE.ConstrainHex(COLOR.b));
end

function COLORS_API.toRGBA(COLOR)
	return unicode.format("#%02X%02X%02X,%d%%", PRIVATE.ConstrainHex(COLOR.r), PRIVATE.ConstrainHex(COLOR.g), PRIVATE.ConstrainHex(COLOR.b),
												PRIVATE.ConstrainPct(COLOR.a));
end

function COLORS_API.toARGB(COLOR)
	return unicode.format("#%02X02X%02X%02X", PRIVATE.ConstrainPct(COLOR.a),
							PRIVATE.ConstrainHex(COLOR.r), PRIVATE.ConstrainHex(COLOR.g), PRIVATE.ConstrainHex(COLOR.b));
end

function COLORS_API.toTable(COLOR)
	return {a=COLOR.a, r=COLOR.r, g=COLOR.g, b=COLOR.b};
end

function COLORS_API.toRGB565(COLOR)
	return ( math.floor(COLOR.r * 31) * 2048 + math.floor(COLOR.g * 63) * 32 + math.floor(COLOR.b * 31) );
end

function COLORS_API.toModelShaderParameter(COLOR)
	return {x=COLOR.r,y=COLOR.g,z=COLOR.b};
end

function COLORS_API.Clone(COLOR)
	local CLONE = {};
	for k,v in pairs(COLOR) do
		CLONE[k] = v;
	end
	setmetatable(CLONE, COLORS_METATABLE);
	return CLONE;
end

function COLORS_API.Multiply(COLOR, scalar)
	if (type(scalar) == "number") then
		scalar = {r=scalar, g=scalar, b=scalar};
	end
	for i,c in ipairs(CHANNELS) do
		if (scalar[c]) then
			COLOR[c] = COLOR[c] * scalar[c];
		end
	end
end

function COLORS_API.Add(COLOR, offset)
	if (type(offset) == "number") then
		offset = {r=offset, g=offset, b=offset};
	end
	for i,c in ipairs(CHANNELS) do
		if (offset[c]) then
			COLOR[c] = COLOR[c] + offset[c];
		end
	end
end

function COLORS_API.toHSV(COLOR)
	return PRIVATE.RGBtoHSV(COLOR.r, COLOR.g, COLOR.b);
end

----------
-- MISC --
----------

function PRIVATE.ConstrainHex(v)
	return math.max(0, math.min(v*255, 255));
end

function PRIVATE.ConstrainPct(v)
	return math.max(0, v*100);
end

function PRIVATE.IsCOLOR(COLOR)
	return (getmetatable(COLOR) == COLORS_METATABLE);
end

function PRIVATE.EnsureCOLOR(COLOR)
	-- makes sure the return value is a COLOR object
	if (PRIVATE.IsCOLOR(COLOR)) then
		return COLOR;
	else
		return Colors.Create(COLOR);
	end
end

function PRIVATE.RGBtoHSV(r,g,b)
	-- referenced from http://en.wikipedia.org/wiki/HSL_and_HSV#Formal_derivation
	local M = math.max(r, g, b);	-- max
	local m = math.min(r, g, b);	-- min
	local C = M - m;
	
	-- hue piecewise [0,6]
	local hue_p = 0;
	if (C ~= 0.0) then
		if (M == r) then
			hue_p = ((g-b)/C ) % 6;
		elseif (M == g) then
			hue_p = ((b-r)/C ) + 2;
		elseif (M == b) then
			hue_p = ((r-g)/C ) + 4;
		end
	end
	
	-- value
	local val = M;
	
	-- saturation
	local sat = 0;
	if (val ~= 0.0) then
		sat = C/val;
	end
	
	return {h=(hue_p*60), s=sat, v=val};
end

function PRIVATE.HSVtoRGB(hue, sat, val)
	-- http://en.wikipedia.org/wiki/HSL_and_HSV#From_HSV
	sat = math.max(0, math.min(sat, 1));
	val = math.max(0, math.min(val, 1));
	
	local C = val * sat;
	local hue_p = (hue % 360)/60;
	local X = C * ( 1 - math.abs(hue_p%2 - 1) );
	
	local rgb;
	if (hue_p < 1) then
		rgb = {r=C, g=X, b=0};
	elseif (hue_p < 2) then
		rgb = {r=X, g=C, b=0};
	elseif (hue_p < 3) then
		rgb = {r=0, g=C, b=X};
	elseif (hue_p < 4) then
		rgb = {r=0, g=X, b=C};
	elseif (hue_p < 5) then
		rgb = {r=X, g=0, b=C};
	elseif (hue_p <= 6) then
		rgb = {r=C, g=0, b=X};
	else
		rgb = {r=0, g=0, b=0};
	end
	
	local m = val - C;
	rgb.r = rgb.r + m;
	rgb.g = rgb.g + m;
	rgb.b = rgb.b + m;
	
	return rgb;
end

function PRIVATE.sRGBtoLinear(val)
	-- referenced from http://forums.cgsociety.org/archive/index.php/t-1045419.html
	if (val <= 0.03928) then
		return val/12.92;
	else
		return math.pow((val+0.055)/1.055, 2.4);
	end
end
