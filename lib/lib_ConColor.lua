
-- ------------------------------------------
-- lib_ConColor
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
	stage = ConColor.GetStage(target_level, my_level)					--returns 1-5 depending on the stage of level diff
	color = ConColor.GetStageColor(stage)								--returns a color depending on the stage 1-5
	color = ConColor.GetColor(target_level, my_level)					--returns a color depending on the level diff
--]]

if ConColor then
	return nil
end
ConColor = {}
local lf = {}

--require "unicode"
--require "math"
--require "table"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_ConColorThresholds
local c_ConColors = {"con_grey", "con_green", "con_yellow", "con_red", "con_skull"}

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function ConColor.GetStage(target_level, my_level)
	if not my_level then
		my_level = Player.GetEffectiveLevel()
	end
	
	if not c_ConColorThresholds then
		lf.InitThresholds()
	end
	
	local level_diff = target_level - my_level
	
	local stage = 1
	if level_diff <= c_ConColorThresholds.grey then
		stage = 1
	elseif level_diff <= c_ConColorThresholds.green then
		stage = 2
	elseif level_diff <= c_ConColorThresholds.yellow then
		stage = 3
	elseif level_diff <= c_ConColorThresholds.red then
		stage = 4
	elseif level_diff <= c_ConColorThresholds.skull then
		stage = 5
	end
	return stage
end

function ConColor.GetStageColor(stage)
	return c_ConColors[stage]
end

function ConColor.GetColor(target_level, my_level)
	return ConColor.GetStageColor(ConColor.GetStage(target_level, my_level))
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.InitThresholds()
	c_ConColorThresholds = {
		grey = tonumber(System.GetCvar("level_con.grey")),
		green = tonumber(System.GetCvar("level_con.green")),
		yellow = tonumber(System.GetCvar("level_con.yellow")),
		red = tonumber(System.GetCvar("level_con.red")),
		skull = tonumber(System.GetCvar("level_con.skull")),
	}
end

