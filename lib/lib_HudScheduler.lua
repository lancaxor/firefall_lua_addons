
--
-- lib_HudScheduler
--   by: John Su
--
--	Schedules portions of the HUD with the HUD Manager

--[[ INTERFACE
	HudScheduler.Request(area, callback_func, callback_params);		-- [area] is a string, callback_func is called when ready;
	HudScheduler.Release();
	* only 1 outstanding request through HudScheduler.Request may be allowed at a time; call HudScheduler.Release() to release
	
	HUD_SLOT = HudScheduler.CreateSlot(area, callback_func, callback_params);	-- [area] is a string, callback_func is called when ready
	HUD_SLOT:Request();
	HUD_SLOT:Release();
	HUD_SLOT:Finalize();
--]]

HudScheduler = {};		-- interface

require "table"
require "lib/lib_Liaison"

-- constants
local PF = {};			-- Private Functions

local STATE_DORMANT	= 0;
local STATE_STANDBY	= 1;
local STATE_ACTIVE	= 2;

-- variables
local g_slotCounter = 0;
local MY_SLOT;			-- Component's global HUD_SLOT
local d_activeSLOTS = {};

-- HudScheduler Interface:
HudScheduler.CreateSlot = function(area, callback_func, ... )
	local HUD_SLOT = { id=(Component.GetInfo().."-"..g_slotCounter) };
	g_slotCounter = g_slotCounter+1;
	HUD_SLOT.request = {
		id=HUD_SLOT.id,
		area=area,
		callback=Liaison.GetPath()
	}
	HUD_SLOT.func = callback_func;
	HUD_SLOT.arg = {...};
	HUD_SLOT.state = STATE_DORMANT;
	
	-- bind functions
	HUD_SLOT.Request = PF.SLOT_Request;
	HUD_SLOT.Release = PF.SLOT_Release;
	HUD_SLOT.Finalize = PF.SLOT_Finalize;
	
	return HUD_SLOT;
end

HudScheduler.Request = function(area, callback_func, ...)
	if (MY_SLOT) then
		HudScheduler.Release()
		warn("Outstanding HudScheduler request was canceled");
	end
	MY_SLOT = HudScheduler.CreateSlot(area, callback_func, unpack({...}));
	MY_SLOT:Request();
end

HudScheduler.Release = function()
	if (MY_SLOT) then
		MY_SLOT:Release();
		MY_SLOT:Finalize();
		MY_SLOT = nil;
	end
end

-- Misc
PF.SLOT_Request = function(HUD_SLOT, priority)
	if (HUD_SLOT.state ~= STATE_DORMANT) then
		if (HUD_SLOT.state == STATE_ACTIVE) then
			error("This slot is still in effect!");
		else
			error("This slot is already in line!");
		end
	end
	HUD_SLOT.state = STATE_STANDBY;
	HUD_SLOT.request.release = false;
	if type(priority) == "number" then
		HUD_SLOT.request.priority = priority
	else
		HUD_SLOT.request.priority = priority and 1 or nil;
	end

	Component.GenerateEvent("MY_USE_HUD_REQUEST", HUD_SLOT.request);
	d_activeSLOTS[HUD_SLOT.id] = HUD_SLOT;
end

PF.SLOT_Release = function(HUD_SLOT)
	if (HUD_SLOT.state ~= STATE_DORMANT) then
		HUD_SLOT.state = STATE_DORMANT;
		HUD_SLOT.request.release = true;
		Component.GenerateEvent("MY_USE_HUD_REQUEST", HUD_SLOT.request);
		d_activeSLOTS[HUD_SLOT.id] = nil;
	end
end

PF.SLOT_Finalize = function(HUD_SLOT)
	HUD_SLOT:Release();
	for k,v in pairs(HUD_SLOT) do
		HUD_SLOT[k] = nil;
	end
end

-- Events
Liaison.BindMessage("hud_available", function(id)
	local HUD_SLOT = d_activeSLOTS[id];
	-- HUD_SLOT might be nil if the request was cancelled in the same frame
	if (HUD_SLOT) then
		HUD_SLOT.state = STATE_ACTIVE;
		HUD_SLOT.func(unpack(HUD_SLOT.arg));
	end
end);
