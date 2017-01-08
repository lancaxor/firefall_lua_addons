
-- ------------------------------------------
-- Callback2
--   by: John Su
-- ------------------------------------------
--	automatic callback management with extended functionality
--	can handle more than 32 running callbacks, and >1 hour durations

--[[ Usage:
	Callback2.FireAndForget(func, param, delay)	<- fires and forgets a standard callback; cleans self up when executing
	CB2 = Callback2.Create()				<- Creates a Callback2 instance
	CB2:Release()						<- cleans self up
	CB2:Bind(func, [...])				<- binds to a function with optional arguments
	CB2:Schedule(delay)					<- executes function in [delay] seconds
	CB2:Execute()						<- executes a callback immediately
	CB2:Cancel()							<- cancels a callback if queued
	CB2:Reschedule(delay)				<- changes time of callback to new delay
	CB2:Delay(seconds)					<- appends [seconds] to the remaining time on the callback; schedules a callback if not running
	CB2:Pause()							<- pauses a pending callback (no action if not scheduled)
	CB2:Unpause()						<- resumes a paused callback (no action if not paused)
	seconds = CB2:GetRemainingTime()		<- returns time until callback is executed (nil if no callback pending)
	... = CB2:GetArgs()					<- returns callback's args
	is_pending = CB2:Pending()			<- returns true if callback is pending
	
	CYCLE = Callback2.CreateCycle(func, params...)	<- creates a cyclical callback
	CYCLE:Run(period[, dur_len])			<- runs the cycle at a given frequency for up to a certain duration (default: infinite)
	CYCLE:Stop()							<- stops the cycle
	CYCLE:Release()						<- cleans self up
	
	count = Callback2.CountCallbacks([only_pending=false])	<- returns number of callbacks; if [only_pending] is true, only counts pending callbacks
	Callback2.SecureCallbacks()			<- replaces the global 'callback', 'cancel_callback', and 'execute_callback' with more secure calls that assert on invalidated handles; callbacks created before will not be able to be canceled or executed via the updated global functions
--]]

Callback2 = {}
local CB2_API = {}
local CYCLE_API = {}
local Private = {}

require "math"
require "table"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local MAX_CALLBACK_TIME = 3600				-- engine does not support callbacks of greater than 60 minutes

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local o_CB2s = {}							-- all the CB2's
local o_PendingCB2s = {}					-- only the Pending CB2's
local cb_ProcessCBs
local g_checkStamp = nil					-- time at which cb_ProcessCBs was set
local g_checkDelay = 0						-- delay for which cb_ProcessCBs was waiting

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Callback2.Create()
	return Private.CreateCB2()
end

function Callback2.CountCallbacks(only_pending)
	local count = 0
	for _,CB2 in pairs(o_CB2s) do
		if (not only_pending or CB2:Pending()) then
			count = count + 1
		end
	end
	return count
end

function Callback2.FireAndForget(func, param, delay)
	local CB2 = Callback2.Create()
	CB2:Bind(function(arg)
		func(arg)
		CB2:Release()
	end, param)
	CB2:Schedule(delay)
end

function Callback2.CreateCycle(func, ...)
	local CYCLE = {
		start_time = nil,
		CB2 = Private.CreateCB2(),
		func = nil,
	}
    local arg = {...};
	CYCLE.func = function()
		func(unpack(arg))
	end
	for k,v in pairs(CYCLE_API) do
		CYCLE[k] = v
	end
	return CYCLE
end

function Callback2.SecureCallbacks()
	-- get a handle on the original calls
	local _native_callback = callback
	local _native_execute_callback = execute_callback
	local _native_cancel_callback = cancel_callback

	-- replace calls with secured versions
	callback = function(func, param, delay)
		local secure_cb = {}
		secure_cb.handle = _native_callback(function()
				secure_cb.handle = nil
				func(param)
			end, nil, delay)
		return secure_cb
	end

	execute_callback = function(secure_cb)
		assert(secure_cb.handle, "invalid callback")
		_native_execute_callback(secure_cb.handle)
	end

	cancel_callback = function(secure_cb)
		assert(secure_cb.handle, "invalid callback")
		_native_cancel_callback(secure_cb.handle)
		secure_cb.handle = nil
	end
end

-- ------------------------------------------
-- CALLBACK2 API FUNCTIONS
-- ------------------------------------------
function CB2_API.Release(CB2)
	-- not really much to do here, but if clean up is required in the future, it helps if this is already being called
	CB2:Cancel()
	o_CB2s[CB2] = nil
	for k,v in pairs(CB2) do
		CB2[k] = nil
	end
end

function CB2_API.Schedule(CB2, delay)
	assert(Private.IsValidDelay(delay), "bad delay")
	assert(CB2.func, "unbound callback")
	if (CB2.call_time) then
		warn("Callback already in progress; canceling previous callback...")
	end
	
	if (delay > 0) then
		CB2.call_time = System.GetClientTime()
		CB2.delay = delay
		Private.QueueCB2(CB2)
	else
		-- immediate callback
		Private.ExecuteCB2(CB2)
	end
end

function CB2_API.Execute(CB2)
	if (CB2.call_time) then
		Private.ExecuteCB2(CB2)
	else
		assert(CB2.func, "unbound callback!")
		CB2.func(CB2_API.GetArgs(CB2))
	end
end

function CB2_API.Cancel(CB2)
	if (CB2.call_time) then
		CB2.call_time = nil
		CB2.delay = nil
		o_PendingCB2s[CB2] = nil
	end
end

function CB2_API.Bind(CB2, func, ...)
	if (CB2.call_time) then
		error("callback in progress! Cancel/Execute before rebinding")
	end
	assert(func and type(func) == "function", "not a function")
	CB2.func = func
	CB2.params = {...}
end

function CB2_API.Reschedule(CB2, delay)
	assert(Private.IsValidDelay(delay), "bad delay")
	assert(CB2.func, "unbound callback")
	if (not CB2.call_time) then
		CB2_API.Schedule(CB2, delay)
		return
	end
	if (delay > 0) then
		CB2.call_time = System.GetClientTime()
		CB2.delay = delay
		Private.QueueCB2(CB2)
	else
		Private.ExecuteCB2(CB2)
	end
end

function CB2_API.Delay(CB2, seconds)
	assert(Private.IsValidDelay(seconds), "bad param")
	local new_time = (CB2:GetRemainingTime() or 0) + seconds
	CB2:Reschedule(new_time)
end

function CB2_API.Pause(CB2)
	CB2.delay = CB2:GetRemainingTime()
	CB2.call_time = nil
end

function CB2_API.Unpause(CB2)
	if (CB2.delay and not CB2.call_time) then
		CB2:Schedule(CB2.delay)
	end
end

function CB2_API.GetRemainingTime(CB2)
	if (not CB2.call_time) then
		return CB2.delay
	end
	return (CB2.delay - System.GetElapsedTime(CB2.call_time))
end

function CB2_API.GetArgs(CB2)
	if (CB2.params) then
		return unpack(CB2.params)
	else
		return nil
	end
end

function CB2_API.Pending(CB2)
	return (CB2.call_time ~= nil)
end

-- ------------------------------------------
-- CYCLE API FUNCTIONS
-- ------------------------------------------
function CYCLE_API.Run(CYCLE, period, len, delay)
	assert(Private.IsValidDelay(period) and period > 0, "Can't Run a cycle callback at <= 0")
	CYCLE.start_time = System.GetClientTime()
	CYCLE.CB2:Cancel()
	CYCLE.CB2:Bind(function()
		CYCLE.func()
		if (CYCLE.start_time ~= nil and (not len or System.GetElapsedTime(CYCLE.start_time) < len)) then
			CYCLE.CB2:Reschedule(period)
		end
	end)
	delay = delay or 0
	CYCLE.CB2:Reschedule(delay)
end

function CYCLE_API.Stop(CYCLE)
	CYCLE.CB2:Cancel()
	CYCLE.start_time = nil
end

function CYCLE_API.Release(CYCLE)
	CYCLE.CB2:Release()
	for k,v in pairs(CYCLE) do
		CYCLE[k] = nil
	end
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function Private.GetNextTime(to_execute)
	local next_time
	for k,CB2 in pairs(o_PendingCB2s) do
		if (CB2.call_time) then
			local remaining_time = CB2.delay - System.GetElapsedTime(CB2.call_time)
			if (remaining_time) then
				if (remaining_time > 0) then
					next_time = math.min(next_time or MAX_CALLBACK_TIME, remaining_time)
				elseif (to_execute) then
					to_execute[k] = CB2
				end
			end
		end
	end
	return next_time
end

function Private.ProcessCBs()
	cb_ProcessCBs = nil
	local to_execute = {}
	local next_check = Private.GetNextTime(to_execute)

	for k,CB2 in pairs(to_execute) do
		Private.ExecuteCB2(CB2)
	end
	if (next_check) then
		assert(next_check > 0)
		Private.UpdateCheckFrequency(next_check)
	end
end

function Private.UpdateCheckFrequency(next_check)
	if (not next_check) then
		-- 'next_check' is only passed in when called from Private.ProcessCBs
		next_check = Private.GetNextTime()
	end
	assert(next_check)
	if (cb_ProcessCBs) then
		local time_until_callback = g_checkDelay - System.GetElapsedTime(g_checkStamp)
		if (time_until_callback <= next_check) then
			-- already on track; don't do anything
			return
		end
		cancel_callback(cb_ProcessCBs)
	end
	-- enforce a non-zero duration callback (TODO: Investigate stack overflow)
	next_check = math.max(next_check, 0.001)
	g_checkStamp = System.GetClientTime()
	g_checkDelay = next_check
	cb_ProcessCBs = callback(Private.ProcessCBs, nil, next_check)
end

function Private.IsValidDelay(val)
	return (val and type(val) == "number" and val == val and val ~= math.huge and val ~= -math.huge)
end

function Private.QueueCB2(CB2)
	-- update the queue
	o_PendingCB2s[CB2] = CB2
	assert(CB2.call_time and CB2.delay > 0)
	Private.UpdateCheckFrequency()
end

function Private.ExecuteCB2(CB2)
	CB2.call_time = nil
	CB2.delay = nil
	o_PendingCB2s[CB2] = nil
	-- execute callback
	CB2.func(CB2_API.GetArgs(CB2))
end

function Private.CreateCB2()
	local CB2 = {call_time=nil, delay=nil, func=nil, params=nil}
	for k,method in pairs(CB2_API) do
		CB2[k] = method
	end
	o_CB2s[CB2] = CB2
	return CB2
end
















