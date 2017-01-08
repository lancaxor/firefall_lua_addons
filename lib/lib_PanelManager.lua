
-- ------------------------------------------
-- lib_PanelManager
--   by: Brian Blose
-- ------------------------------------------

--[[Usage:
	Used to streamline the process of closing open panels when a new panel tries to open
	
	PanelManager.RegisterFrame(frame, frameCloseFunc[, ...])			--Register your frame with a function to allow the PanelManager to close the frame when another frame opens
																			frame = the var for the frame or the name of the frame
																			frameCloseFunc = function used to close the frame
																			... = optional params that get passed into the frameCloseFunc
	PanelManager.OnShow(frame)											--Call whenever your frame opens(preferable on the OnOpen event)
																			frame = the var for the frame or the name of the frame
	PanelManager.OnHide(frame)											--Call whenever your frame closes(preferable on the OnClose event)
																			frame = the var for the frame or the name of the frame
--]]

PanelManager = {}

require "table"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lf = {} --local functions
local lcb = {} --Liaison callback functions
local c_ReplyPath = Liaison.GetPath()

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local d_CloseFrameFuncs = {}
local g_FrameVisible = {}

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
PanelManager.RegisterFrame = function(FRAME, ForceCloseFunc, ...)
	local frame = lf.GetFrameName(FRAME)
	if not d_CloseFrameFuncs[frame] then
        local arg = {...};
		d_CloseFrameFuncs[frame] = function()
			ForceCloseFunc(unpack(arg))
		end
		g_FrameVisible[frame] = false
	else
		warn("Already Registered") --reword message
	end
end

PanelManager.OnShow = function(FRAME)
	lf.SendToManager(FRAME, true)
end

PanelManager.OnHide = function(FRAME)
	lf.SendToManager(FRAME, false)
end

PanelManager.CloseActivePanel = function()
	Component.GenerateEvent("MY_PANEL_MANAGER", {eventclose=true})
end

-- ------------------------------------------
-- LIASION FUNCTIONS
-- ------------------------------------------
function lcb.PanelManagerHideFrame(frame)
	if d_CloseFrameFuncs[frame] then
		d_CloseFrameFuncs[frame]()
	else
		warn("Unknown Frame") --reword message
	end
end
Liaison.BindMessageTable(lcb)

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
function lf.SendToManager(FRAME, visible)
	local frame = lf.GetFrameName(FRAME)
	if g_FrameVisible[frame] ~= visible then
		g_FrameVisible[frame] = visible
		local tbl = {
			reply = c_ReplyPath,
			frame = frame,
			visible = visible,
		}
		if d_CloseFrameFuncs[frame] then
			Component.GenerateEvent("MY_PANEL_MANAGER", tbl)
		else
			warn("Must Register First") --reword message
		end
	end
end

-- ------------------------------------------
-- UTILITY/RETURN FUNCTIONS
-- ------------------------------------------
function lf.GetFrameName(FRAME)
	-- returns the frame name from either a string or a frame reference var
	if type(FRAME) == "string" then
		return FRAME
	else
		return FRAME:GetInfo()
	end
end
