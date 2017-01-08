
-- ------------------------------------------
-- lib_Time
--   by: Brian Blose
-- ------------------------------------------

--[[
Lib Usage:
	Time.BindOnTimeFormatChanged(func, ...)											--bind a function to be called whenever the 12/24 hour clock setting is changed
																						--extra params will be passed back to the called function
	Time.Is24HourModeActive()														--returns boolean on if the clock setting is set to use 24 hour time
	Time.GetTimeString(timestamp)													--returns 12/24 hour time string for timestamp ie: 02:34PM or 14:34
																						--if timestamp is nil, then it will use current time
	Time.GetSimpleDate(timestamp)													--returns the timestamp in abbreviated month and day - ie: "Sep 16"
																						--if timestamp is nil, then it will use current time
	Time.GetFullDate(timestamp)														--returns the full date in os locale aware order - ie: "09/16/98" or "16/09/98"
																						--if timestamp is nil, then it will use current time
	Time.IsSameDay(timestamp1, timestamp2)											--returns the true if the timestamps are from the same day
																						--if timestamp2 is nil, then it will use current time
	Time.IsSameYear(timestamp1, timestamp2)											--returns the true if the timestamps are from the same year
																						--if timestamp2 is nil, then it will use current time
	Time.GetTimezoneOffset()														--returns the local timezone offset from UTC in seconds
	Time.GetSecondsUntilUTC(timestamp)												--returns the number of seconds until UTC midnight
																						--if timestamp is nil, then it will use current time
	
Client API notes:
	System.GetLocalUnixTime() is a direct passthrough to lua's os.time() function
	System.GetDate() is a direct passthrough to lua's os.date() function
	
	System.GetDate() tags from http://www.lua.org/
	%a	abbreviated weekday name (e.g., Wed)
	%A	full weekday name (e.g., Wednesday)
	%b	abbreviated month name (e.g., Sep)
	%B	full month name (e.g., September)
	%c	date and time (e.g., 09/16/98 23:48:10)
	%d	day of the month (16) [01-31]
	%H	hour, using a 24-hour clock (23) [00-23]
	%I	hour, using a 12-hour clock (11) [01-12]
	%M	minute (48) [00-59]
	%m	month (09) [01-12]
	%p	either "am" or "pm" (pm)
	%S	second (10) [00-61]
	%w	weekday (3) [0-6 = Sunday-Saturday]
	%x	date (e.g., 09/16/98)
	%X	time (e.g., 23:48:10)
	%Y	full year (1998)
	%y	two-digit year (98) [00-99]
	%%	the character `%´
--]]

require "table"

Time = {}
local lf = {}

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_TimezoneOffset
local c_MonthAbrLocKeys =
{
	"MONTH_1_ABR",
	"MONTH_2_ABR",
	"MONTH_3_ABR",
	"MONTH_4_ABR",
	"MONTH_5_ABR",
	"MONTH_6_ABR",
	"MONTH_7_ABR",
	"MONTH_8_ABR",
	"MONTH_9_ABR",
	"MONTH_10_ABR",
	"MONTH_11_ABR",
	"MONTH_12_ABR",
}

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local g_Use24HourTime = false
local f_OnTimeFormatChanged

-- ------------------------------------------
-- EVENT FUNCTIONS
-- ------------------------------------------
function _OnTimeFormatChanged(args)
	--From Clock.lua; so one 24 hour option can control all time displays
	g_Use24HourTime = args.use_24_hour_time
	if f_OnTimeFormatChanged then
		f_OnTimeFormatChanged()
	end
end
callback(function()
	Component.BindEvent("MY_TIME_FORMAT_CHANGED", "_OnTimeFormatChanged")
end, nil, 0.001)

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function Time.BindOnTimeFormatChanged(func, ...)
	--bind a function to be called when "MY_TIME_FORMAT_CHANGED" gets fired
	if not f_OnTimeFormatChanged then
        local arg = {...};
		f_OnTimeFormatChanged = function()
			func(unpack(arg))
		end
	else
		warn("Time.BindOnTimeFormatChanged can only bind one function per component")
	end
end

function Time.Is24HourModeActive()
	--returns boolean for if the player has enabled 24 hour time for time formats
	return g_Use24HourTime
end

function Time.GetTimeString(timestamp)
	--returns the time of day in user choosen format as selected from Clock Interface Options
	timestamp = timestamp or System.GetLocalUnixTime()
	if g_Use24HourTime then
		return System.GetDate("%H:%M", timestamp)
	else
		return System.GetDate("%I:%M%p", timestamp)
	end
end

function Time.GetSimpleDate(timestamp)
	--returns the date in abbreviated month and day - ie: "Sep 16"
	timestamp = timestamp or System.GetLocalUnixTime()

	-- manually translate month to avoid issues with client locale not matching os' locale
	local month = System.GetDate("%m", timestamp) 
	month = Component.LookupText(c_MonthAbrLocKeys[tonumber(month)]) or ""

	return System.GetDate(tostring(month).." %d", timestamp)
end

function Time.GetFullDate(timestamp)
	--returns the full date in os locale aware order - ie: "09/16/98" or "16/09/98"
	timestamp = timestamp or System.GetLocalUnixTime()
	return System.GetDate("%x", timestamp)
end

function Time.IsSameDay(ts1, ts2)
	--returns the true if the timestamps are from the same day
	ts1 = System.GetDate("*t", ts1)
	ts2 = System.GetDate("*t", ts2 or System.GetLocalUnixTime())
	return ts1.yday == ts2.yday and ts1.year == ts2.year
end

function Time.IsSameYear(ts1, ts2)
	--returns the true if the timestamps are from the same year
	ts1 = System.GetDate("*t", ts1)
	ts2 = System.GetDate("*t", ts2 or System.GetLocalUnixTime())
	return ts1.year == ts2.year
end

function Time.TimeBetween(ts1, ts2)
	--returns the amount of months, days, hours, minutes between two timestamps
	local retVal = {}
	startTime = System.GetDate("*t", ts1)
	endTime = System.GetDate("*t", ts2)

	--calculate total days between timestamps
	local daysDiff = (endTime.yday + ((endTime.year-startTime.year)*365)) - startTime.yday

	retVal.months = math.floor(daysDiff/30)
	daysDiff = daysDiff % 30
	retVal.weeks = math.floor(daysDiff/7)
	daysDiff = daysDiff % 7
	
	retVal.seconds = endTime.sec - startTime.sec
	if retVal.seconds < 0 then
		retVal.seconds = retVal.seconds + 60
		endTime.min = endTime.min - 1
	end
	retVal.minutes = endTime.min - startTime.min
	if retVal.minutes < 0 then
		retVal.minutes = retVal.minutes + 60
		endTime.hour = endTime.hour - 1
	end
	retVal.hours = endTime.hour - startTime.hour
	if retVal.hours < 0 then
		retVal.hours = retVal.hours + 24
		daysDiff = daysDiff - 1
	end
	retVal.days = daysDiff

	return retVal
end

function Time.GetTimezoneOffset()
	--returns the local timezone offset from UTC in seconds
	if not c_TimezoneOffset then
		local local_time = System.GetLocalUnixTime(System.GetDate("*t"))
		local utc_time = System.GetLocalUnixTime(System.GetDate("!*t"))
		c_TimezoneOffset = local_time - utc_time
	end
	return c_TimezoneOffset
end

function Time.GetSecondsUntilUTC(timestamp)
	--returns the number of seconds until UTC midnight
	timestamp = timestamp or System.GetLocalUnixTime()
	timestamp = tonumber(timestamp)
	return 86400 - (timestamp % 86400)
end



