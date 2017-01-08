
-- ------------------------------------------
-- lib_Reticle
--   by: Brian Blose
-- ------------------------------------------

--[[ GUIDE ------------------------------------------------------------------------------------------------------------
All Reticles will either need to pass a function as a second param with LibReticle.RegisterWithManager or have a global ChangeMode function
Either Option will get passed 2 args of (newMode, duration)
The four modes are ...
	0 = Reticle Fully Disabled/Inactive
	1 = Reticle Temp Disabled due to reloading, weapon down, etc.
	2 = Reticle Active and ready to go
	3 = Reticle Active but Out of Ammo
duration may or maynot be passed in, please set a default duration if no duration was passed in
If it is supplied, then that is the time it takes before the weapon is ready to be fired and it should be used in the reticle animation

Most events for a reticle should check that the current mode is not 0/OFF so that they do not do anything while inactive.

There are currently 4 basic types of weapon Groups for Reticles
Sniper Rifles = SNIPER_RIFLE, LIGHT_SNIPER_RIFLE
	unique reticles that handle the scope and no-scope visuals
	no-scope: needs frame dims of dimensions="center-x:50%; center-y:50%; width:100%; height:100%; relative:aim" to have the crosshairs change size
	scope: should use a combo of fullscreen/static size visuals and relative:aim to handle the scopes delay in full accuracy
Turrets = AA_TURRET, AP_TURRET, MGV_TURRET
	special reticles for turrets
Accuracy Based Weapons = HEAVY_MG, LIGHT_MG, ASSAULT_RIFLE, SMG, SHOTGUN, FAMAS
	Weapons with accuracy that effects size of the reticle
	needs frame dims of dimensions="center-x:50%; center-y:50%; width:100%; height:100%; relative:aim" to have the crosshairs change size
Static Aim Weapons = PLASMA_CANNON, BIO_GUN, ENGINEER_BEAM, GRENADE_LAUNCHER
	Weapons without accuracy concerns and can't be sized based on relative:aim size percentages
	needs static sized frame dims that can either be relative to the screen or aim. If using aim then width/height needs to be static and not a percentage
--]] ------------------------------------------------------------------------------------------------------------------

LibReticle = {} --table for global functions

require "table"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lf = {} --table for private functions
local lcb = {} --table for liasion callback functions

local AIM_DEBUG_FRAME

-- MODES
local c_ModeOff			= 0		-- Reticle Fully Disabled/Inactive
local c_ModeStandby		= 1		-- Reticle Temp Disabled due to reloading, weapon down, etc.
local c_ModeActive		= 2		-- Reticle Active and ready to go
local c_ModeOutOfAmmo	= 3		-- Reticle Active but Out of Ammo

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local w_BaseParts = {}
local g_HealColor = "healing"
local g_HurtColor = "damage"
local g_CritColor = "damage"
local g_selfId
local f_ChangeMode

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
LibReticle.RegisterWithManager = function(data, OnChangeMode)
	--[[Usage: LibReticle.RegisterWithManager( { compatible, (label or key) }, ChangeMode_Function )
		key = string; Localization Key_String for the label
		label = string; label text that is either already localized or unlocalized
		compatible = array; Array of compatible weapon groups
			"HEAVY_MG","LIGHT_MG","PLASMA_CANNON","BIO_GUN","ENGINEER_BEAM","SNIPER_RIFLE","ASSAULT_RIFLE","SMG","GRENADE_LAUNCHER","SHOTGUN","FAMAS","AA_TURRET","MGV_TURRET","AP_TURRET"
		ChangeMode_Function =  optional second param to pass in the function that is used for the ChangeMode handler, if not used, then the code forces the use of a global ChangeMode function
	--]]
	if OnChangeMode and type(OnChangeMode) == "function" then
		f_ChangeMode = OnChangeMode
	end
	if type(data) ~= "table" then
		error(Component.GetInfo()..": Missing data table for LibReticle.RegisterWithManager")
		return nil
	end
	if data.key then
		data.label = Component.LookupText(data.key)
		data.key = nil
	end
	data.id = Component.GetInfo() -- id will be the file name of the reticle
	data.reply = Liaison.GetPath()
	Component.PostMessage("Reticle:Main", "__register", tostring(data))
	Liaison.BindMessageTable(lcb)
end

LibReticle.IsValidHitEvent = function(args)
	--[[Usage: LibReticle.IsValidHitEvent(Event args)
		used with a function that is bound to both ON_HIT_TARGET_PREDICT and ON_HIT_TARGET_CONFIRM
		lets the function know if it should ignore the event or not
	--]]
	if not args.damage then
		return false
	end
	if not g_selfId then
		g_selfId = Player.GetTargetId()
	end
	local valid = false
	if args.event == "on_hit_target_predict" and (args.damage > 0) and not isequal(g_selfId, args.entityId) and args.inflictorIsLocal then
		-- predict only works for damage and happens instantly;
		-- ignoring if you hit yourself or if one of your deployables did the hit
		valid = true
	elseif args.event == "on_hit_target_confirm" and (args.damage < 0 or args.heal) and not isequal(g_selfId, args.entityId) and args.inflictorIsLocal then
		-- confirm works for both damage and healing and has a short delay, this should not be used for damage feedback
		-- ignoring if you hit yourself or if one of your deployables did the hit
		valid = true
	end
	return valid
end

LibReticle.GetHitFeedbackColor = function(args)
	--[[Usage: LibReticle.GetHitFeedbackColor(Event args)
		used with a function that is bound to ON_HIT_TARGET_PREDICT and/or ON_HIT_TARGET_CONFIRM
		lets the function know what color of hit feedback to use
	--]]
	local color
	if args.heal or args.damage < 0 then
		color = g_HealColor
	elseif args.critical then
		color = g_CritColor
	else
		color = g_HurtColor
	end
	return color
end

LibReticle.ShowOutOfAmmoReticle = function(bool)
	--[[Usage: LibReticle.ShowOutOfAmmoReticle(boolean)
		used to turn on/off the main Out of Ammo reticle
		this should normally be used by most reticles
		allows sniper scopes to continue to work even when out of ammo
	--]]
	if bool then
		Component.PostMessage("Reticle:Main", "__outofammo", "show")
	else
		Component.PostMessage("Reticle:Main", "__outofammo", "hide")
	end
end

LibReticle.ToggleAimDebugFrame = function(bool)
	--[[Usage: LibReticle.ToggleAimDebugFrame([boolean])
		boolean: true will show; false wil hide; nil will toggle
		Creates/Destroys a Debug Frame that highlights the 'relative:aim' size for the specific reticle
		Yellow Square: Shows the size of the relative:aim bounding box
		Orange Circle: Shows the real accuracy deviation
	--]]
	if bool == nil then
		bool = (AIM_DEBUG_FRAME == nil)
	end
	if bool and not AIM_DEBUG_FRAME then
		AIM_DEBUG_FRAME = Component.CreateFrame("HudFrame")
		AIM_DEBUG_FRAME:SetDims("center-x:50%; center-y:50%; height:0; width:0; relative:aim;")
		AIM_DEBUG_FRAME:MoveTo("dock:fill; relative:aim;", 0.1, 0) --the debug frame seems to not show until it changes in size, this works around that
		Component.CreateWidget("<StillArt dimensions='dock:fill' style='texture:colors; region:white; tint:FFFF00; alpha:0.3'/>", AIM_DEBUG_FRAME)
		Component.CreateWidget("<StillArt dimensions='dock:fill' style='texture:PanelParts; region:Circle_White; tint:FF0000; alpha:0.3'/>", AIM_DEBUG_FRAME)
	elseif not bool and AIM_DEBUG_FRAME then
		for i = AIM_DEBUG_FRAME:GetChildCount(), 1, -1 do
			Component.RemoveWidget(AIM_DEBUG_FRAME:GetChild(i))
		end
		Component.RemoveFrame(AIM_DEBUG_FRAME)
		AIM_DEBUG_FRAME = nil
	end
end

LibReticle.FlagPartForColoring = function(WIDGET)
	--[[Usage: LibReticle.ToggleAimDebugFrame(WIDGET)
		WIDGET: adds the widget to a table for global coloring
	--]]
	table.insert(w_BaseParts, WIDGET)
end

LibReticle.FlagChildrenForColoring = function(GROUP)
	--[[Usage: LibReticle.ToggleAimDebugFrame(GROUP)
		GROUP: adds ALL the GROUP's children to a table for global coloring
	--]]
	for i = 1, GROUP:GetChildCount() do
		table.insert(w_BaseParts, GROUP:GetChild(i))
	end
end

-- ------------------------------------------
-- LIAISON CALLBACK FUNCTIONS
-- ------------------------------------------
lcb.activate = function(dur)
	lf.OnChangeMode(c_ModeActive, dur)
	if AIM_DEBUG_FRAME then
		AIM_DEBUG_FRAME:Show()
	end
end

lcb.standby = function(dur)
	lf.OnChangeMode(c_ModeStandby, dur)
end

lcb.deactivate = function(dur)
	lf.OnChangeMode(c_ModeOff, dur)
	if AIM_DEBUG_FRAME then
		AIM_DEBUG_FRAME:Hide()
	end
end

lcb.outofammo = function(dur)
	lf.OnChangeMode(c_ModeOutOfAmmo, dur)
end

lcb.BASE_COLOR = function(tint)
	for i, WIDGET in ipairs(w_BaseParts) do
		WIDGET:SetParam("tint", tint)
	end
end

lcb.GLOW_COLOR = function(glow)
	for i, WIDGET in ipairs(w_BaseParts) do
		WIDGET:SetParam("glow", glow)
	end
end

lcb.HEAL_COLOR = function(tint)
	g_HealColor = tint
end

lcb.HURT_COLOR = function(tint)
	g_HurtColor = tint
end

lcb.CRIT_COLOR = function(tint)
	g_CritColor = tint
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
lf.OnChangeMode = function(mode, dur)
	if f_ChangeMode then
		f_ChangeMode(mode, dur)
	else
		ChangeMode(mode, dur)
	end
end

