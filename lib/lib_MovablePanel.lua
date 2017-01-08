
-- ------------------------------------------
-- lib_MovablePanel
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
	MovablePanel.ConfigFrame(params)					--allows a panel frame to be movable and resizable
															--params.frame = frame name or reference; required
															--params.MOVABLE_PARENT = widget reference that will be the parent for the focusbox that controls movablity
																--should be in the title bar section
															--params.RESIZABLE_PARENT = widget reference that will be the parent for the focusbox that controls resizability
																--should be in the bottom right corner; grab point dots for visualization
															--params.min_height = number optional; min frame height for resizing
															--params.max_height = number optional; max frame height for resizing; set to same as min to disable resizing height
															--params.min_width = number optional; min frame width for resizing
															--params.max_width = number optional; max frame width for resizing; set to same as min to disable resizing width
															--params.step_height = number optional; height will increment in pixels based on step size
															--params.step_width = number optional; width will increment in pixels based on step size
															Functions: fire without params
															--params.OnReposition = function optional; fires when the lib is forced to move the frame due to out of bounds concerns
															--params.OnResize = function optional; fires when the frame changes in size, either do to size constraits or player resizing
															--params.OnMoveStart = function optional; fires when the player starts moving the frame
															--params.OnMoveStop = function optional; fires when the player stops moving the frame
															--params.OnResizeStart = function optional; fires when the player starts resizing the frame
															--params.OnResizeStop = function optional; fires when the player stops resizing the frame
	MovablePanel.UpdateConfig(params)					--allows for updating a frame's config
															--same as above, though it ignores MOVABLE_PARENT and RESIZABLE_PARENT
--]]

if MovablePanel then
	return nil
end
MovablePanel = {}
local lf = {}

--require "unicode"
require "math"
--require "table"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_MovableSavePrefix = "_MovablePanelMovable_"
local c_ResizableSavePrefix = "_MovablePanelResizable_"
local c_ResolutionChangedEvent = "MY_MOVABLE_PANEL_RESOLUTION_CHANGED"

local c_DotStyle = "texture:colors; region:white; alpha:0.5; eatsmice:false;"

local bp_MovableAnchor = 
	[[<FocusBox dimensions="dock:fill" style="cursor:sys_sizeall; visible:false;"/>]]
local bp_ResizableAnchor = 
	[[<FocusBox dimensions="dock:fill" style="cursor:sys_sizenwse; visible:false;">
		<StillArt dimensions="right:100%-3; bottom:100%-3; height:2; width:2" style="]]..c_DotStyle..[["/>
		<StillArt dimensions="right:100%-7; bottom:100%-3; height:2; width:2" style="]]..c_DotStyle..[["/>
		<StillArt dimensions="right:100%-11; bottom:100%-3; height:2; width:2" style="]]..c_DotStyle..[["/>
		<StillArt dimensions="right:100%-3; bottom:100%-7; height:2; width:2" style="]]..c_DotStyle..[["/>
		<StillArt dimensions="right:100%-7; bottom:100%-7; height:2; width:2" style="]]..c_DotStyle..[["/>
		<StillArt dimensions="right:100%-3; bottom:100%-11; height:2; width:2" style="]]..c_DotStyle..[["/>
	</FocusBox>]]

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_MovableFrames = {}
local g_ResizeName = nil
local g_MovableName = nil

-- ------------------------------------------
-- GLOBAL EVENT FUNCTIONS
-- ------------------------------------------
function _MovablePanelOnResolutionChanged(args)
	for name, _ in pairs(g_MovableFrames) do
		lf.EnsureFrameOnScreen(name)
	end
end
callback(function()
	Component.BindEvent(c_ResolutionChangedEvent, "_MovablePanelOnResolutionChanged")
end, nil, 0.001)

function _MovablePanelResizeDragDrop(args)
	if args.done then
		lf.OnResizeStop()
	else
		lf.ResizingLoop()
	end
end

function _MovablePanelMoveDragDrop(args)
	if args.done then
		lf.OnMovableStop()
	end
end

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function MovablePanel.ConfigFrame(args)
	if not args.frame then return nil end
	local name, FRAME = lf.GetFrameName(args.frame)
	if g_MovableFrames[name] then --already setup config, lets just do an update
		MovablePanel.UpdateConfig(args)
		return nil
	end
	args.frame = nil
	args.name = name
	args.FRAME = FRAME
	local anchor, size
	if args.MOVABLE_PARENT then
		args.movable = true
		anchor = Component.GetSetting(c_MovableSavePrefix..name)
		local FOCUSBOX = Component.CreateWidget(bp_MovableAnchor, args.MOVABLE_PARENT)
		FOCUSBOX:BindEvent("OnMouseDown", function() lf.OnMovableStart(name) end)
		FOCUSBOX:Show()
	end
	if args.RESIZABLE_PARENT then
		size = Component.GetSetting(c_ResizableSavePrefix..name)
		args.resizable = true
		args.min_width = args.min_width or 100
		args.max_width = args.max_width or 999999
		args.step_width = args.step_width or 1
		args.min_height = args.min_height or 100
		args.max_height = args.max_height or 999999
		args.step_height = args.step_height or 1
		args.resize_cursor = (args.min_width == args.max_width and "sys_sizens") or (args.min_height == args.max_height and "sys_sizewe") or "sys_sizenwse"
		local FOCUSBOX = Component.CreateWidget(bp_ResizableAnchor, args.RESIZABLE_PARENT)
		FOCUSBOX:BindEvent("OnMouseDown", function() lf.OnResizeStart(name) end)
		FOCUSBOX:Show()
		FOCUSBOX:SetCursor(args.resize_cursor)
	end
	g_MovableFrames[name] = args
	if anchor or size then
		lf.SetFrameDims(args, anchor, size)
		lf.EnsureFrameWithinSizeLimits(name)
		lf.EnsureFrameOnScreen(name)
		if args.OnResize and size then
			local bounds = lf.GetUnscaledFrameBounds(FRAME)
			args.OnResize({height=bounds.height, width=bounds.width, init=true})
		end
	end
end

function MovablePanel.UpdateConfig(args)
	if not args.frame then return nil end
	local name, FRAME = lf.GetFrameName(args.frame)
	args.frame = nil
	args.MOVABLE_PARENT = nil
	args.RESIZABLE_PARENT = nil
	for k, v in pairs(args) do
		g_MovableFrames[name][k] = v
	end
	lf.EnsureFrameWithinSizeLimits(name)
	lf.EnsureFrameOnScreen(name)
end

-- ------------------------------------------
-- LOCAL MOVABLE FUNCTIONS
-- ------------------------------------------
function lf.OnMovableStart(name)
	local frame = g_MovableFrames[name]
	if not frame then return nil end
	frame.FRAME:SetDims("relative:cursor")
	g_MovableName = name
	Component.BeginDragDrop(nil, nil, "_MovablePanelMoveDragDrop")
	Component.SetGlobalCursorOverride("sys_sizeall", true)
	if frame.OnMoveStart then
		frame.OnMoveStart()
	end
end

function lf.OnMovableStop()
	local frame = g_MovableFrames[g_MovableName]
	if not frame then return nil end
	g_MovableName = nil
	frame.FRAME:SetDims("relative:screen")
	lf.EnsureFrameOnScreen(frame.name)
	lf.SaveMovable(frame.name)
	Component.ClearGlobalCursorOverride()
	if frame.OnMoveStop then
		frame.OnMoveStop()
	end
end

function lf.SaveMovable(name)
	local frame = g_MovableFrames[name]
	if not frame then return nil end
	local s_width, s_height = lf.GetUiScreenSize()
	local pos = lf.GetScaledFrameBounds(frame.FRAME)
	pos.centerX = (pos.width/2) + pos.left
	pos.centerY = (pos.height/2) + pos.top
	local anchor = "center-x:"..((pos.centerX / s_width)*100).."%; center-y:"..((pos.centerY / s_height)*100).."%; "
	lf.SetFrameDims(frame, anchor, nil)
	Component.SaveSetting(c_MovableSavePrefix..name, anchor)
end

-- ------------------------------------------
-- LOCAL RESIZABLE FUNCTIONS
-- ------------------------------------------
function lf.OnResizeStart(name)
	local frame = g_MovableFrames[name]
	if not frame then return nil end
	g_ResizeName = name
	Component.BeginDragDrop(nil, nil, "_MovablePanelResizeDragDrop")
	Component.SetGlobalCursorOverride(frame.resize_cursor, true)
	if frame.OnResizeStart then
		frame.OnResizeStart()
	end
end

function lf.OnResizeStop()
	local frame = g_MovableFrames[g_ResizeName]
	if not frame then return nil end
	g_ResizeName = nil
	lf.SaveResize(frame.name)
	Component.ClearGlobalCursorOverride()
	if frame.OnResizeStop then
		frame.OnResizeStop()
	end
end

function lf.ResizingLoop()
	local frame = g_MovableFrames[g_ResizeName]
	if not frame then return nil end
	local s_width, s_height = lf.GetUiScreenSize()
	local c_X, c_Y = Component.GetCursorPos()
	local pos = lf.GetUnscaledFrameBounds(frame.FRAME)
	local anchor = "top:_; left:_; "
	local dim_width = "_"
	local diff_width = c_X - pos.left - frame.min_width
	if diff_width < 0 then diff_width = 0 end
	local width_steps = math.floor((diff_width / frame.step_width) + 0.5)
	local width = frame.min_width + (width_steps * frame.step_width)
	width = math.min(width, frame.max_width)
	if pos.left + width <= s_width and pos.width ~= width then
		dim_width = width
		pos.width = width
	end
	local dim_height = "_"
	local diff_height = c_Y - pos.top - frame.min_height
	if diff_height < 0 then diff_height = 0 end
	local height_steps = math.floor((diff_height / frame.step_height) + 0.5)
	local height = frame.min_height + (height_steps * frame.step_height)
	height = math.min(height, frame.max_height)
	if pos.top + height <= s_height and pos.height ~= height then
		dim_height = height
		pos.height = height
	end
	if dim_height ~= "_" or dim_width ~= "_" then
		local size = "height:"..dim_height.."; width:"..dim_width..";"
		lf.SetFrameDims(frame, anchor, size)
		if frame.OnResize then
			frame.OnResize({height=pos.height, width=pos.width, height_changed=(dim_height ~= "_"), width_changed=(dim_width ~= "_")})
		end
	end
end

function lf.SaveResize(name)
	local frame = g_MovableFrames[name]
	if not frame then return nil end
	local pos = lf.GetUnscaledFrameBounds(frame.FRAME)
	local size = "height:"..pos.height.."; width:"..pos.width..";"
	Component.SaveSetting(c_ResizableSavePrefix..name, size)
	lf.SaveMovable(name)
end

-- ------------------------------------------
-- LOCAL GENERAL FUNCTIONS
-- ------------------------------------------
function lf.EnsureFrameOnScreen(name)
	local frame = g_MovableFrames[name]
	if not frame then return nil end
	local s_width, s_height = lf.GetUiScreenSize()
	local pos = lf.GetScaledFrameBounds(frame.FRAME)

	if pos.width > s_width or pos.right > s_width then
		lf.SetFrameDims(frame, "right:100%; ", nil)
	elseif pos.left < 0 then
		lf.SetFrameDims(frame, "left:0; ", nil)
	end
	if pos.height > s_height or pos.top < 0 then
		lf.SetFrameDims(frame, "top:0; ", nil)
	elseif pos.bottom > s_height then
		lf.SetFrameDims(frame, "bottom:100%; ", nil)
	end
end

function lf.EnsureFrameWithinSizeLimits(name)
	local frame = g_MovableFrames[name]
	if not frame or not frame.resizable then return nil end
	local bounds = lf.GetUnscaledFrameBounds(frame.FRAME)
	local width = bounds.width
	if frame.min_width > bounds.width then
		width = frame.min_width
	elseif frame.max_width < bounds.width then
		width = frame.max_width
	elseif frame.step_width > 1 then 
		local extra_width = (bounds.width - frame.min_width) % frame.step_width
		if extra_width ~= 0 then
			if extra_width / frame.step_width > 0.5 then
				width = bounds.width + (frame.step_width - extra_width)
				width = math.min(width, frame.max_width)
			else
				width = bounds.width - extra_width
				width = math.max(width, frame.min_width)
			end
		end
	end
	local height = bounds.height
	if frame.min_height > bounds.height then
		height = frame.min_height
	elseif frame.max_height < bounds.height then
		height = frame.max_height
	elseif frame.step_height > 1 then 
		local extra_height = (bounds.height - frame.min_height) % frame.step_height
		if extra_height ~= 0 then
			if extra_height / frame.step_height > 0.5 then
				height = bounds.height + (frame.step_height - extra_height)
				height = math.min(height, frame.max_height)
			else
				height = bounds.height - extra_height
				height = math.max(height, frame.min_height)
			end
		end
	end
	local width_changed = width ~= bounds.width
	local height_changed = height ~= bounds.height
	if width_changed or height_changed then
		lf.SetFrameDims(frame, nil, "height:"..height.."; width:"..width..";")
		if frame.OnResize then
			frame.OnResize({height=height, width=width, height_changed=height_changed, width_changed=width_changed})
		end
	end
end

-- ------------------------------------------
-- LOCAL UTILITY FUNCTIONS
-- ------------------------------------------
function lf.GetFrameName(frame)
	local name, FRAME
	if type(frame) == "string" then
		name = frame
		FRAME = Component.GetFrame(frame)
	else
		name = frame:GetInfo()
		FRAME = frame
	end
	return name, FRAME
end

function lf.SetFrameDims(frame, anchor, size)
	anchor = anchor or "center-x:_; center-y:_; "
	size = size or "height:_; width:_;"
	frame.FRAME:SetDims(anchor..size)
	if frame.OnReposition then
		frame.OnReposition()
	end
end

function lf.GetFullScreenSize()
	return Component.GetScreenSize(false)
end

function lf.GetUiScreenSize()
	return Component.GetScreenSize(true)
end

function lf.GetScaledFrameBounds(FRAME)
	return FRAME:GetBounds(true)
end

function lf.GetUnscaledFrameBounds(FRAME)
	return FRAME:GetBounds(false)
end
