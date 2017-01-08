
-- ------------------------------------------
-- lib_table
--   by: Brian Blose
-- ------------------------------------------

_table = {}
local lf = {}

require "table"

_table.copy = function(object)
	--returns an unlinked copy the object/table including metatables recursively
	local lookup_table = {}
	local function _copy(object)
		if type(object) ~= "table" then
			return object
		elseif lookup_table[object] then
			return lookup_table[object]
		end
		local new_table = {}
		lookup_table[object] = new_table
		for index, value in pairs(object) do
			new_table[_copy(index)] = _copy(value)
		end
		return setmetatable(new_table, getmetatable(object))
	end
	return _copy(object)
end

_table.isequal = function(tbl1, tbl2, use_isequal_compare)
	assert(type(tbl1) == "table", "_table.isequal first param must be a table")
	assert(type(tbl2) == "table", "_table.isequal second param must be a table")
	if tbl1 == tbl2 then
		--early out incase they are references to the same table
		return true
	end
	--check every key of tbl1 to verify it matches tbl2
	for k, v1 in pairs(tbl1) do
		local v2 = tbl2[k]
		local t1 = type(v1)
		local t2 = type(v2)
		local is_equal = false
		if t1 == "table" or t2 == "table" then
			if t1 == t2 then
				--recursive compare of 2 table values
				is_equal = _table.isequal(v1, v2)
			end
		elseif v1 == v2 then
			--try quick compare first
			is_equal = true
		elseif use_isequal_compare then
			--isequal compares number values of various var types ie: 123 as a string and 123 as a number will return true
			is_equal = isequal(v1, v2)
		end
		if not is_equal then
			return false
		end
	end
	for k, v in pairs(tbl2) do
		if tbl1[k] == nil then
			--found a key on tbl2 that is not on tbl1
			return false
		end
	end
	return true
end

_table.sort = function(oldtbl, func)
	local newtbl = {}
	local bool
	newtbl[1] = oldtbl[1]
	for i = 2, #oldtbl do
		for k = 1, #newtbl do
			bool = func(oldtbl[i], newtbl[k])
			if bool then
				table.insert(newtbl, k, oldtbl[i])
				break
			elseif k == #newtbl then
				table.insert(newtbl, oldtbl[i])
			end
		end
	end
	return newtbl
end

_table.find = function(tbl, match_func)
	for k,v in pairs(tbl) do
		if (match_func(v)) then
			return k,v;
		end
	end
end
