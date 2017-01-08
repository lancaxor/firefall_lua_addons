
-- ------------------------------------------
-- lib_ProgressBar - Creates a Progress Bar Widget
--   by: Ken Cheung
-- ------------------------------------------

--[[ Usage:
	PROGRESS_BAR = ProgressBar.Create(PARENT)			-- creates a ProgressBar
	PROGRESS_BAR:Tint(fg_color, bg_color)				-- colors the foreground and background
	PROGRESS_BAR:UpdateSize()							-- Updates the size of the progress bar to match its parent's
	PROGRESS_BAR:SetHeight(height)						-- Set progress bar's height
	PROGRESS_BAR:SetPercent(percent, dur, ...)			-- set progress percent [0-1]
	PROGRESS_BAR:QueuePercent(percent, dur, ...)		-- queue progress bar animation
	PROGRESS_BAR:GetPercent()							-- returns progress percent [0-1]
	PROGRESS_BAR:SetFGParam( param, value, dur, ...)	-- set foreground param
	PROGRESS_BAR:QueueFGParam( param, value, dur, ...)	-- queue foreground param animation
	PROGRESS_BAR:CycleFGParam( param, value, dur, ...)	-- cycle foreground param animation
	PROGRESS_BAR:SetBGParam( param, value, dur, ...)	-- set background param
	PROGRESS_BAR:QueueBGParam( param, value, dur, ...)	-- queue background param animation
	PROGRESS_BAR:CycleBGParam( param, value, dur, ...)	-- cycle background param animation
--]]

ProgressBar = {}

require "math";

local PROGRESS_BAR_API = {};
local PROGRESS_BAR_METATABLE = {
	__index = function(t,key) return PROGRESS_BAR_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in ProgressBar"); end
};

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

ProgressBar.DEFAULT_COLOR = "#0E7192";
ProgressBar.DEFAULT_BLUE_COLOR = "#4cacff";
ProgressBar.DEFAULT_WHITE_COLOR = "#9C9C9C";
ProgressBar.DEFAULT_GREEN_COLOR = "#629E0A";
ProgressBar.DEFAULT_RED_COLOR = "#8E0909";
ProgressBar.DEFAULT_YELLOW_COLOR = "#FFFF00";

local BP_PROGRESS_BAR = {
	blueprint = [[<Group dimensions="left:0; width:100%; center-y:50%; height:22">
		<Group name="bg" dimensions="dock:fill">
			<StillArt name="left" dimensions="left:0; right:15; top:0; height:100%" style="texture:ExpandableProgressBar; region:bg_left;"/>
			<StillArt name="middle" dimensions="left:15; right:100%-13; top:0; height:100%" style="texture:ExpandableProgressBar; region:bg_mid; xwrap:15"/>
			<StillArt name="right" dimensions="left:100%-13; right:100%; top:0; height:100%" style="texture:ExpandableProgressBar; region:bg_right;"/>
		</Group>
		<Group name="fg" dimensions="dock:fill" style="clip-children:true">
			<StillArt name="left" dimensions="left:0; right:15; top:0; height:100%" style="texture:ExpandableProgressBar; region:fg_left;"/>
			<StillArt name="middle" dimensions="left:15; right:100%-13; top:0; height:100%" style="texture:ExpandableProgressBar; region:fg_mid; xwrap:15"/>
			<StillArt name="right" dimensions="left:100%-13; right:100%; top:0; height:100%" style="texture:ExpandableProgressBar; region:fg_right;"/>
		</Group>
	</Group>]],
	left_cap_width = 15,
	right_cap_width = 13,
	}
	
	
------------------------
-- Frontend Interface --
------------------------

function ProgressBar.Create(PARENT)
	local WIDGET = Component.CreateWidget(BP_PROGRESS_BAR.blueprint, PARENT);
	
	local PROGRESS_BAR = {
		GROUP = WIDGET,

		BG = WIDGET:GetChild("bg"),
		BG_LEFT = WIDGET:GetChild("bg.left"),
		BG_MIDDLE = WIDGET:GetChild("bg.middle"),
		BG_RIGHT = WIDGET:GetChild("bg.right"),
		
		FG = WIDGET:GetChild("fg"),
		FG_LEFT = WIDGET:GetChild("fg.left"),
		FG_MIDDLE = WIDGET:GetChild("fg.middle"),
		FG_RIGHT = WIDGET:GetChild("fg.right"),
		
		fg_tint = ProgressBar.DEFAULT_COLOR,
		bg_tint = ProgressBar.DEFAULT_COLOR,
		blueprint = BP_PROGRESS_BAR;
		value = 1;
	}
	
	--foster fg bits to WIDGET so they position correctly while their parent handles the clipping/mask effect
	Component.FosterWidget(PROGRESS_BAR.FG_LEFT, WIDGET, "dims")
	Component.FosterWidget(PROGRESS_BAR.FG_MIDDLE, WIDGET, "dims")
	Component.FosterWidget(PROGRESS_BAR.FG_RIGHT, WIDGET, "dims")
	
	setmetatable(PROGRESS_BAR, PROGRESS_BAR_METATABLE);
	PROGRESS_BAR:Tint(ProgressBar.DEFAULT_COLOR, ProgressBar.DEFAULT_COLOR);
	PROGRESS_BAR:UpdateSize();

	return PROGRESS_BAR;
end

----------------
-- PROGRESS BAR API --
----------------

function PROGRESS_BAR_API.Destroy(PROGRESS_BAR)
	Component.RemoveWidget(PROGRESS_BAR.GROUP);
	for k,v in pairs(PROGRESS_BAR) do
		PROGRESS_BAR[k] = nil;
	end
end

function PROGRESS_BAR_API.Show(PROGRESS_BAR, ...)
	PROGRESS_BAR.GROUP:Show(...);
end

function PROGRESS_BAR_API.Hide(PROGRESS_BAR, ...)
	PROGRESS_BAR.GROUP:Hide(...);
end

function PROGRESS_BAR_API.Tint(PROGRESS_BAR, fg_color, bg_color)
	fg_tint = fg_color
	PROGRESS_BAR.FG_LEFT:SetParam("tint", fg_color)
	PROGRESS_BAR.FG_MIDDLE:SetParam("tint", fg_color)
	PROGRESS_BAR.FG_RIGHT:SetParam("tint", fg_color)
	
	bg_tint = bg_color or fg_color
	PROGRESS_BAR.BG_LEFT:SetParam("tint", bg_color)
	PROGRESS_BAR.BG_MIDDLE:SetParam("tint", bg_color)
	PROGRESS_BAR.BG_RIGHT:SetParam("tint", bg_color)
end

function PROGRESS_BAR_API.UpdateSize(PROGRESS_BAR)
	local blueprint = PROGRESS_BAR.blueprint
	PROGRESS_BAR.FG_LEFT:SetDims("left:0; right:"..blueprint.left_cap_width)
	PROGRESS_BAR.FG_MIDDLE:SetDims("left:"..blueprint.left_cap_width.."; right:100%-"..blueprint.right_cap_width)
	PROGRESS_BAR.FG_RIGHT:SetDims("right:100%; left:100%-"..blueprint.right_cap_width)
	
	PROGRESS_BAR.BG_LEFT:SetDims("left:0; right:"..blueprint.left_cap_width)
	PROGRESS_BAR.BG_MIDDLE:SetDims("left:"..blueprint.left_cap_width.."; right:100%-"..blueprint.right_cap_width)
	PROGRESS_BAR.BG_RIGHT:SetDims("right:100%; left:100%-"..blueprint.right_cap_width)
end

function PROGRESS_BAR_API.SetHeight(PROGRESS_BAR, height)
	PROGRESS_BAR.GROUP:SetDims( "height:"..height );
end

function PROGRESS_BAR_API.SetPercent(PROGRESS_BAR, percent, dur, ...)
	local value = math.min(1, math.max(0, percent) );
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.value = value;
	PROGRESS_BAR.FG:MoveTo("left:0; right:"..(100*percent).."%", dur, ...);
end

function PROGRESS_BAR_API.QueuePercent(PROGRESS_BAR, percent, dur, ...)
	local value = math.min(1, math.max(0, percent) );
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.value = value;
	PROGRESS_BAR.FG:QueueMove("left:0; right:"..(100*percent).."%", dur, ...);
end

function PROGRESS_BAR_API.GetPercent(PROGRESS_BAR)
	return PROGRESS_BAR.value;
end

function PROGRESS_BAR_API.SetFGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.FG_LEFT:ParamTo(param, value, dur, ...);
	PROGRESS_BAR.FG_MIDDLE:ParamTo(param, value, dur, ...);
	PROGRESS_BAR.FG_RIGHT:ParamTo(param, value, dur, ...);
end

function PROGRESS_BAR_API.QueueFGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.FG_LEFT:QueueParam(param, value, dur, ...);
	PROGRESS_BAR.FG_MIDDLE:QueueParam(param, value, dur, ...);
	PROGRESS_BAR.FG_RIGHT:QueueParam(param, value, dur, ...);
end

function PROGRESS_BAR_API.CycleFGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.FG_LEFT:CycleParam(param, value, dur, ...);
	PROGRESS_BAR.FG_MIDDLE:CycleParam(param, value, dur, ...);
	PROGRESS_BAR.FG_RIGHT:CycleParam(param, value, dur, ...);
end

function PROGRESS_BAR_API.SetBGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.BG_LEFT:ParamTo(param, value, dur, ...);
	PROGRESS_BAR.BG_MIDDLE:ParamTo(param, value, dur, ...);
	PROGRESS_BAR.BG_RIGHT:ParamTo(param, value, dur, ...);
end

function PROGRESS_BAR_API.QueueBGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.BG_LEFT:QueueParam(param, value, dur, ...);
	PROGRESS_BAR.BG_MIDDLE:QueueParam(param, value, dur, ...);
	PROGRESS_BAR.BG_RIGHT:QueueParam(param, value, dur, ...);
end

function PROGRESS_BAR_API.CycleBGParam(PROGRESS_BAR, param, value, dur, ...)
	fg_tint = fg_color;
	if( not dur ) then
		dur = 0;
	end
	PROGRESS_BAR.BG_LEFT:CycleParam(param, value, dur, ...);
	PROGRESS_BAR.BG_MIDDLE:CycleParam(param, value, dur, ...);
	PROGRESS_BAR.BG_RIGHT:CycleParam(param, value, dur, ...);
end
