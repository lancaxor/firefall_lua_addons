
-- ------------------------------------------
-- lib_Unlocks
--   by: Brian Blose
-- ------------------------------------------

--[[ 
Description:
	Interfaces with UnlocksManager to streamline the handling of all the unlocks/certifications. 
	
Usage:
	Unlocks.Subscribe(unlock_type)													--Registers with UnlockManager to be kept up-to-date on changes to the unlock_type
																						--unlock_type = string; same strings that get passed into Player.GetUnlocksByType
																							--list of unlock_types can be found in MainUI/Backend/UnlocksManager/UnlocksManager.lua
	Unlocks.OnUpdate(unlock_type, func)												--Registers a func to be called whenever the unlock_type data gets changed
																						--unlock_type = string; same strings that get passed into Player.GetUnlocksByType
																						--func = function; this func will get called as func(unlock_data, unlock_type)
	unlock_data = Unlocks.Request(unlock_type)										--Returns the current table of unlock_data for the supplied unlock_type
	
	boolean = Unlocks.HasUnlock(unlock_type, unlock_id[, frame_id])					--Return true if you have the suppied unlock
																						--unlock_type = string; same strings that get passed into Player.GetUnlocksByType
																						--unlock_id = string; theid of the unlock, ussually a number id in string form
																						--frame_id = string [optional]; a chassis' item_sdb_id for frame specific searching
--]]

if Unlocks then
	return nil
end
Unlocks = {}

--require "unicode"
--require "math"
require "table"
require "lib/lib_table"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local lcb = {}
local lf = {}

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local d_MyUnlocks = {}
local g_OnUpdateCallbacks = {}
local g_Subscriptions = {}
local g_ComponentName = Component.GetInfo()

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Unlocks.Subscribe(unlock_type)
	if not Player or not Player.IsReady() then
		callback(Unlocks.Subscribe, unlock_type, 0.1)
	else
		lf.Subscribe(unlock_type)
	end
end

function Unlocks.OnUpdate(unlock_type, func)
	assert(type(func) == "function", "Usage: Unlocks.OnUpdate(unlock_type, func)")
	if not g_OnUpdateCallbacks[unlock_type] then
		g_OnUpdateCallbacks[unlock_type] = {}
	end
	table.insert(g_OnUpdateCallbacks[unlock_type], func)
end

function Unlocks.Request(unlock_type)
	if not g_Subscriptions[unlock_type] then --fallback for those that can't wait for the update
		return Player.GetUnlocksByType(unlock_type)
	else
		return _table.copy(d_MyUnlocks[unlock_type])
	end
end

function Unlocks.HasUnlock(unlock_type, unlock_id, frame_id)
	frame_id = tostring(frame_id)
	unlock_id = tostring(unlock_id)
	local unlocks
	if not g_Subscriptions[unlock_type] then --fallback for those that can't wait for the update
		unlocks = Player.GetUnlocksByType(unlock_type)
	else
		unlocks = d_MyUnlocks[unlock_type]
	end
	unlocks = unlocks[unlock_id]
	if unlocks and (unlocks.global or unlocks[frame_id]) then
		return true
	else
		return false
	end
end

-- ------------------------------------------
-- LIAISON FUNCTIONS
-- ------------------------------------------
function lcb.lib_OnUnlocksUpdated(unlock_type, unlock_data)
	d_MyUnlocks[unlock_type] = unlock_data or {}
	if g_OnUpdateCallbacks[unlock_type] then
		for _, func in ipairs(g_OnUpdateCallbacks[unlock_type]) do
			func(_table.copy(d_MyUnlocks[unlock_type]), unlock_type)
		end
	end
end
Liaison.BindCallTable(lcb)

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.Subscribe(unlock_type)
	if not g_Subscriptions[unlock_type] then
		g_Subscriptions[unlock_type] = true
		d_MyUnlocks[unlock_type] = {}
		Liaison.RemoteCall("UnlocksManager", "RegisterUnlockUpdates", g_ComponentName, unlock_type)
	end
end








