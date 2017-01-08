
-- ------------------------------------------
-- lib_Spinner
--   by: James Harless
-- ------------------------------------------

--[[

	local SPINNER = Spinner.Create(PARENT)			-- Creates the Spinner Object
	
	SPINNER:Play([value])						-- Plays the Spinner Flipbook in a loop, value is the rate in which it players (0.66 default)
	SPINNER:PlayOnce([value])					-- Plays the Spinner Flipbook animation cycle once, value is the rate in which it players (0.66 default)
	SPINNER:Stop()								-- Stops the Spinner Animation on its current frame
	SPINNER:Destroy()							-- Removes the Spinner Object
	
	local CONTAINER = SPINNER:GetContents()		-- Returns the contents widget
--]]




if Spinner then
	return nil
end
Spinner = {}

require "table"
require "unicode"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

local API = {};
local SPINNER_METATABLE = {
	__index = function(t,key) return API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in SPINNER"); end
}
local lf = {}	-- Local Functions

local c_BOUNDS = 94		-- Default bounds for Art, do not alter flipbook height/width or else it looks turrible.
local c_SPEED_MOD = 0.66		-- Speed mod, currently set to 1.5 seconds

local BP_FLIPBOOK = [[<FlipBook style="texture:spinner; eatsmice:false" dimensions="top:0; left:0; height:]]..c_BOUNDS..[[;width:]]..c_BOUNDS..[[" fps="32" frameWidth="95">
	<Group name="contents" dimensions="dock:fill" />
</FlipBook>]]

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Spinner.Create(PARENT)
	local GROUP = Component.CreateWidget(BP_FLIPBOOK, PARENT)
	local SPINNER = {
		GROUP = GROUP,
	}

	setmetatable(SPINNER, SPINNER_METATABLE)
	
	return SPINNER
end

-- ------------------------------------------
--  SPINNER API
-- ------------------------------------------
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetDims", "SetDims", "MoveTo", "QueueMove", "FinishMove",
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"SetFocusable", "SetFocus", "ReleaseFocus", "HasFocus",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(SPINNER, ...)
		return SPINNER.GROUP[method_name](SPINNER.GROUP, ...);
	end
end

function API.Play(SPINNER, speed_mod)
	if not SPINNER.GROUP:IsRunning() then
		SPINNER.GROUP:Play(speed_mod or c_SPEED_MOD)
	end
end

function API.PlayOnce(SPINNER, speed_mod)
	if not SPINNER.GROUP:IsRunning() then
		SPINNER.GROUP:Play(speed_mod or c_SPEED_MOD, 1)
	end
end

function API.Stop(SPINNER)
	if SPINNER.GROUP:IsRunning() then
		SPINNER.GROUP:Stop()
	end
end

function API.GetContents(SPINNER)
	return SPINNER.GROUP:GetChild("contents")
end

function API.Destroy(SPINNER)
	SPINNER:Stop()
	Component.RemoveWidget(SPINNER.GROUP)
	for k in pairs(SPINNER) do
		SPINNER[k] = nil
	end
end
