
--
-- lib_EncounterTimer
--   by: Red 5 Studios
--		a helper for creating timers for encounters

--[[
Usage:
	local TIMER = EncounterShadowFields.Create(encounter_id, placer_id);
	TIMER:DestroyTimer();	-- cleans up self
	
	TIMER:Update();			-- updates timer info

--]]
if EncounterTimer then
	return nil
end
EncounterTimer = {};	-- external interface

local ENCTIMER_API = {};

function EncounterTimer.CreateTimer(encounterId, placer_id, bannerStyle )
	local idx = tostring(encounterId);
	local FIELDS = g_FIELDS;
	
	local TIMER = {
		encounterId = encounterId,
		idx = Component.GetInfo().."_"..tostring(encounterId),
	};
	
	local timer_args = {command="create", idx=TIMER.idx, foster=placer_id, isBanner=(bannerStyle == true), visible=false};
	Component.GenerateEvent("MOD_TIMER_EVENT", timer_args);
	Component.GenerateEvent("MOD_TIMER_EVENT", {command="show", isBanner=(bannerStyle == true), idx=TIMER.idx});
	
	-- methods:
	for k,v in pairs(ENCTIMER_API) do
		TIMER[k] = v;
	end
	
	return TIMER;
end

function ENCTIMER_API.DestroyTimer(TIMER)
	if (TIMER) then
		Component.GenerateEvent("MOD_TIMER_EVENT", {command="remove", idx=TIMER.idx});
		TIMER = nil;
	end
end

function ENCTIMER_API.Update( TIMER, newVal, args)
	if (TIMER) then
		if (TIMER.encounterId == tostring(args.encounter_id)) then
			TIMER.timer = newVal;
			if (newVal) then			
				-- update timer
				local timer_args = {command="update", idx=TIMER.idx};
				timer_args.hide_oncomplete = args.hide_oncomplete;
				if (TIMER.timer.remaining_secs) then
					timer_args.countDown = TIMER.timer.remaining_secs;
				elseif (TIMER.timer.elapsed_secs) then
					timer_args.countUp = TIMER.timer.elapsed_secs;
				end
				if (TIMER.timer.is_paused) then
					timer_args.count = timer_args.countDown or timer_args.countUp;
					timer_args.countDown = nil;
					timer_args.countUp = nil;
				end
				Component.GenerateEvent("MOD_TIMER_EVENT", timer_args);
				
				timer_args = {idx=TIMER.idx, command="show", visible=true};
				Component.GenerateEvent("MOD_TIMER_EVENT", timer_args);
			else
				local timer_args = {idx=TIMER.idx, command="show", visible=false};
				--Component.GenerateEvent("MOD_TIMER_EVENT", timer_args);
			end
		else
			warn("encounter timer conflict: "..tostring(TIMER.encounterId).." vs "..tostring(args.encounter_id));
		end
	end	
end

function ENCTIMER_API.Minimal(TIMER)
	if (TIMER) then
		Component.GenerateEvent("MOD_TIMER_EVENT", {minimal=true, idx=TIMER.idx});
		TIMER = nil;
	end
end
