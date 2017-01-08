
-- ------------------------------------------
-- lib_Shader
--   by: Shaun Whitt
-- ------------------------------------------
-- Functions for modifying shaders on UI Widgets

Shader = {}
local lf = {}

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_Shaders = {
	normal = 0,
	grayscale = 1,
	mask = 2,
	gradient_mask = 3,
}

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Shader.SetShader(WIDGET, shader)
	local shaderId = c_Shaders[shader]
	assert(shaderId, "Invalid shader")
	lf.SetShader(WIDGET, shaderId)
end

function Shader.SetShaderNormal(WIDGET)
	lf.SetShader(WIDGET, c_Shaders.normal)
end

function Shader.SetShaderGrayscale(WIDGET)
	lf.SetShader(WIDGET, c_Shaders.grayscale)
end

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
function lf.SetShader(WIDGET, shaderId)
	if WIDGET then
		WIDGET:SetShader(shaderId)
	end
end
