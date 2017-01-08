
--
-- lib_HudManager
--   by: James Harless / Brian Blose
--
--	Manages showing and hiding of hud elements

--[[Usage:
	Used to handle incoming and outgoing hud hide requests
	Incoming logic is restricted to a single basic white/black list logic per component
		if multiple pieces in a component need to hide based on different white/black list logic, then this will have to be handled manually without the support of this lib
	
	Incoming Events:
		HudManager.BlacklistReasons(list)		-- Array of what reasons should be ignored; ignored if active Whitelist; call before HudManager.BindOnShow
		HudManager.WhitelistReasons(list)		-- Array of what reasons are required; Supersedes Blacklist; call before HudManager.BindOnShow
		
		HudManager.BindOnShow(func)				-- Binds the supplied function for when MY_HUD_SHOW is heard; call during ON_COMPONENT_LOAD
													--func will be called as func(show, dur); show being the boolean based on the black/white lists; dur being the animation duration
													--calling this will bind MY_HUD_SHOW, so do not bind it as part of your component xml/lua code
		
		HudManager.IsVisible()					-- Returns true if HUD is visible based on black/white list params
		HudManager.IsHidden()					-- Returns true if HUD is hidden based on black/white list params
	
	Outgoing Requests:
		HudManager.HideRequest(reason, bool)	-- Fires a request to the HudManager.lua to hide based on the supplied reason; bool of false cancels the request
													--reasons should be unique per component to prevent interference
													--reasons that start with enc_ are reserved for server encounter code
													--reasons can not be "show", "dur", or "requests" as those are reserved for other values
--]]

if HudManager then
	return nil
end
HudManager = {}

local lf = {}

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_IncomingEvent = "MY_HUD_SHOW"
local c_OutgoingEvent = "MY_HIDE_HUD_REQUEST"

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_HudVisible = true
local f_OnEvent = nil
local g_WhiteList = nil
local g_BlackList = nil

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function HudManager.BindOnShow(func)
	assert(type(func) == "function", "HudManager.BindOnEvent() must be supplied a function!")
	if f_OnEvent then
		warn("Can only be called once")
	else
		Component.BindEvent(c_IncomingEvent, "LIBHUDMANAGER_OnHudEvent")
		f_OnEvent = func
	end
end

function HudManager.IsVisible()
	return g_HudVisible
end

function HudManager.IsHidden()
	return not g_HudVisible
end

function HudManager.BlacklistReasons(list)
	if type(list) == "table" then
		g_BlackList = list
	else
		g_BlackList = nil
	end
end

function HudManager.WhitelistReasons(list)
	if type(list) == "table" then
		g_WhiteList = list
	else
		g_WhiteList = nil
	end
end

function HudManager.HideRequest(reason, bool)
	Component.GenerateEvent(c_OutgoingEvent, {reason=reason, hide=bool})
end

-- ------------------------------------------
-- EVENT FUNCTIONS
-- ------------------------------------------
function LIBHUDMANAGER_OnHudEvent(args)
	local show = true
	if not args.show then --only hide has reasons
		if g_WhiteList then
			for _, reason in ipairs(g_WhiteList) do
				if args[reason] then
					show = false
					break
				end
			end
		elseif g_BlackList then
			local requests = args.requests
			for _, reason in ipairs(g_BlackList) do
				if args[reason] then
					requests = requests - 1
				end
			end
			if requests > 0 then
				show = false
			end
		else
			show = false
		end
	end
	if g_HudVisible ~= show then --only fire the func if the visiblity has changed
		g_HudVisible = show
		f_OnEvent(show, args.dur)
	end
end
