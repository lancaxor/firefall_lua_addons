

-- ------------------------------------------
-- HoloPlate - Creates the elements for lib_Button, as well as the rules for coloring it
--   by: John Su
-- ------------------------------------------

--[[ Usage:
	PLATE = HoloPlate.Create(PARENT)			-- creates the PLATE
	PLATE:Destroy()							-- Removes the widgets
	
	PLATE:SetRadius(radius)					-- scale the radius of the corners (default: 5)
	
	PLATE:SetColor(color)							-- tints the skin according to a ruleset
	PLATE:ColorTo(color, dur[, delay, smooth])		-- tints the skin according to a ruleset
	PLATE:QueueColor(color, dur[, delay, smooth])	-- tints the skin according to a ruleset
	
	PLATE.OUTER	-- the rim (border widget)
	PLATE.INNER	-- the inside (border widget)
	PLATE.LINES	-- the scanlines (stillart widget)
	PLATE.SHADE	-- the shadow (border widget)
--]]

HoloPlate = {}

require "lib/lib_Colors";
require "math";

local PLATE_API = {};
local PLATE_METATABLE = {
	__index = function(t,key) return PLATE_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ITEM"); end
};

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

local BP_INNER = '<Border name="inner" dimensions="dock:fill" class="ButtonSolid"/>';
local BP_OUTER = '<Border name="outer" dimensions="dock:fill" class="ButtonBorder"/>';
local BP_SHADE = '<Border name="shade" dimensions="dock:fill" class="ButtonFade"/>';
local BP_LINES = '<StillArt name="lines" dimensions="center-x:50%; center-y:50%; width:100%-4; height:100%-4" class="Scanlines" style="exposure:0; alpha:0.2"/>';

local BASE_PADDING = 10;
local BASE_RADIUS = 5;
local FADE_PADDING_RATIO = 6/BASE_PADDING;
local SHADE_ALPHA = 0.8;
local LINES_ALPHA = 0.4;

local AnimateColor;

------------------------
-- Frontend Interface --
------------------------

function HoloPlate.Create(PARENT)
	local PLATE = {
		INNER = Component.CreateWidget(BP_INNER, PARENT),
		LINES = Component.CreateWidget(BP_LINES, PARENT),
		SHADE = Component.CreateWidget(BP_SHADE, PARENT),
		OUTER = Component.CreateWidget(BP_OUTER, PARENT),
	};
	
	setmetatable(PLATE, PLATE_METATABLE);
	return PLATE;
end

----------------
-- PLATE API --
----------------

function PLATE_API.Destroy(PLATE)
	for k,v in pairs(PLATE) do
		Component.RemoveWidget(v);
		PLATE[k] = nil;
	end
	setmetatable(PLATE, nil);
end

function PLATE_API.SetRadius(PLATE, radius)
	local padding = BASE_PADDING * radius / BASE_RADIUS;
	PLATE.INNER:SetPadding(padding);
	PLATE.OUTER:SetPadding(padding);
	PLATE.SHADE:SetPadding(padding * FADE_PADDING_RATIO);
end

function PLATE_API.SetColor(PLATE, color)
	AnimateColor(PLATE, color, "SetParam");
end
function PLATE_API.ColorTo(PLATE, color, ...)
	AnimateColor(PLATE, color, "ParamTo", ...);
end
function PLATE_API.QueueColor(PLATE, color, ...)
	AnimateColor(PLATE, color, "QueueParam", ...);
end
function PLATE_API.CycleColor(PLATE, color, ...)
	AnimateColor(PLATE, color, "CycleParam", ...);
end

AnimateColor = function(PLATE, color, method, ...)
	assert(color);
	local COLOR_base = Colors.Create(color);
	local hsv_base = COLOR_base:toHSV();
	--local COLOR_rim = Colors.Create( {h=hsv_base.h, s=hsv_base.s*(1-hsv_base.v), v=(hsv_base.v+.4)} );	-- gets white
	local COLOR_rim = Colors.Create( {h=hsv_base.h, s=hsv_base.s, v=(hsv_base.v+.2)} );
	
	local hsv_dark = {h=hsv_base.h, s=hsv_base.s+.5, v=(hsv_base.v-.5)};
	if (hsv_dark.h >= 30 and hsv_dark.h <= 60) then
		-- yellow to orange
		hsv_dark.h = (hsv_dark.h-30)*.5 + 30;
	end
	local COLOR_dark = Colors.Create( hsv_dark );
	COLOR_base:Multiply(1.1);	-- to counter the scanelines
	
	PLATE.INNER[method](PLATE.INNER, "tint", COLOR_base, ...);
	PLATE.OUTER[method](PLATE.OUTER, "tint", COLOR_rim, ...);
	COLOR_dark.a = COLOR_base.a * SHADE_ALPHA;
	PLATE.SHADE[method](PLATE.SHADE, "tint", COLOR_dark, ...);
	COLOR_dark.a = COLOR_base.a * LINES_ALPHA;
	PLATE.LINES[method](PLATE.LINES, "tint", COLOR_dark, ...);
end
