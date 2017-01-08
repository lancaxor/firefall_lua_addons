
-- ------------------------------------------
-- lib_Slash
--   by: Brian Blose
-- ------------------------------------------

LIB_SLASH = {}

require "unicode"
require "math"
require "lib/lib_Liaison"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local PRIVATE = {}
local SLASH_ERROR = "SLASH_ERROR: "

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
LIB_SLASH.BindCallback = function(tbl)
	--[[Usage: LIB_SLASH.BindCallback({(slash_list or slash_list_key), (description or description_key), func})
		slash_list = localized string containing comma seperated words for parsing into a slash list.  ie "stuck, unstuck" will allow /stuck or /unstuck to be valid commands for the function
		slash_list_key = a key_string used to get the localized slash_list off of the DB
		description = localized string that appears when you use /help to define what the slash command does or how it works. Try to keep it brief
		description_key = a key_string used to get the localized description off of the DB
		func = the function that gets called when the slash command is used
			[func] will be called with a single parameter [arg],
			where [arg] is an int-indexed array of parameters following the slash command,
			which can also be accessed as a single string in [arg.text]
			(ex. '/robocommand kill "all humans" 100' -> arg = {"kill", "all humans", "100", text="kill \"all humans\" 100"}
		autocomplete_name = [optional] param index in which a name is expected for player name autocompete, ie "/invite <name> <msg>" the index for the name is 1
	--]]
	if not tbl or type(tbl) ~= "table" then
		warn(SLASH_ERROR.."Usage: LIB_SLASH.BindCallback({slash_list=string, description=string, func=function})")
		return nil
	end
	local err = PRIVATE.ProcessList(tbl)
	if err then
		warn(SLASH_ERROR..err.."\n"..tostring(tbl))
		return nil
	elseif not tbl.func or type(tbl.func) ~= "function" then
		warn(SLASH_ERROR.."no function defined to the table's func".."\n"..tostring(tbl))
		return nil
	end
	PRIVATE.ProcessDescription(tbl)
	
	local msgType = "slash_"..tbl.slash_list
	Liaison.BindMessage(msgType, function(data)
		local arg = PRIVATE.ParseArgs(data)
		tbl.func(arg)
	end)
	
	Component.GenerateEvent("MY_SLASH_HANDLER", {action="register", slashlist=tbl.slash_list, replytype=msgType, reply=Liaison.GetPath(), description=tbl.description, autocomplete_name=tbl.autocomplete_name})
end

LIB_SLASH.UnbindCallback = function(list, isKey)
	--[[Usage: LIB_SLASH.UnbindCallback(list, isKey)
		list = the slash_list or the slash_list_key used in the binding
		isKey = if nil or false then the list will be treated as a slash_list; else it will be treated as a slash_list_key
	--]]
	local tbl = {}
	if isKey then
		tbl.slash_list_key = list
	else
		tbl.slash_list = list
	end
	Component.GenerateEvent("MY_SLASH_HANDLER", {action="unregister", slashlist=list})
end

-- ------------------------------------------
-- PRIVATE FUNCTIONS
-- ------------------------------------------
PRIVATE.ProcessList = function(tbl)
	-- Ensure the slash list is present as expected
	-- Returns nil if all is good, error reason if it isn't
	local err = nil
	if tbl.slash_list_key then
		if type(tbl.slash_list_key) ~= "string" then
			err = "slash_list_key is not a string"
		elseif tbl.slash_list_key == "" then
			err = "slash_list_key is an empty string"
		else
			tbl.slash_list, failed = Component.LookupText(tbl.slash_list_key)
			if failed or unicode.find(tbl.slash_list, "?UIKey") then -- the unicode.find is temp til the failed mechcanic works
				err = "slash_list_key: '"..tbl.slash_list_key.."' was not found in the Localization DB"
			end
			tbl.slash_list_key = nil
		end
	elseif tbl.slash_list then
		if type(tbl.slash_list) ~= "string" then
			err = "slash_list is not a string"
		elseif tbl.slash_list == "" then
			err = "slash_list is an empty string"
		end
	else
		err = "Slash commands require either a slash_list or a slash_list_key entry in a table to work"
	end
	return err
end

PRIVATE.ProcessDescription = function(tbl)
	local missing = false
	if tbl.description_key then
		if type(tbl.description_key) == "string" and tbl.description_key ~= "" then
			tbl.description = Component.LookupText(tbl.description_key)
		else
			missing = true
		end
		tbl.description_key = nil
	elseif tbl.description then
		if type(tbl.description) ~= "string" or tbl.description == "" then
			missing = true
		end
	else
		missing = true
	end
	if missing then
		tbl.description = Component.LookupText("SLASH_HELP_MISSING_DESCRIPTION")
	end
end

PRIVATE.FindString = function(look_in, to_find, start_idx, end_idx)
	-- difference being it returns end_idx+1 instead of nil if to_find is not found
	local i = unicode.find(look_in, to_find, start_idx)
	if i then
		return i
	else
		return end_idx+1
	end
end

PRIVATE.ParseArgs = function(line)
	local args = {text=line};
	-- parse
	local line_len = unicode.len(line)
	if line_len > 0 then
		local in_quotes = false
		local i_start = 1
		local i_quote = PRIVATE.FindString(line, "\"", i_start, line_len)
		local i_space = PRIVATE.FindString(line, " ", i_start, line_len)
		local i_next = 0
		while i_start <= line_len do
			-- get token end
			if in_quotes then
				-- get end quote
				i_next = PRIVATE.FindString(line, "\"", i_quote+1, line_len)
				-- get next breaks
				i_quote = PRIVATE.FindString(line, "\"", i_next+1, line_len)
				i_space = PRIVATE.FindString(line, " ", i_next+1, line_len)
				in_quotes = false
			else
				if i_quote < i_space then
					i_next = i_quote
					in_quotes = true
				else
					i_next = i_space
					-- get next space
					i_space = PRIVATE.FindString(line, " ", i_next+1, line_len)
				end
			end
			
			if i_next > i_start then
				local token = unicode.sub(line, i_start, i_next-1)
				args[#args+1] = token
			end
			
			i_start = i_next+1
		end
	end
	return args;
end
