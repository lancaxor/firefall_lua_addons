
--
-- lib_EncounterShadowFields
--   by: Red 5 Studios
--		a helper for responding to changing shadow fields in an Encounter

--[[
Usage:
	local FIELDS = EncounterShadowFields.Create(encounter_id);
	FIELDS:Finalize();	-- cleans up self
	
	FIELDS:AddListener(field_name, callback_func);	-- when [field_name] changes, will call
														[callback_func](new_value, args)
														where [args] contains {old_value, field_name, encounter_id}
	FIELDS:Update();	-- checks for updates and fires callback functions as necessary
	FIELDS:UpdateField(field_name, new_value);	-- manually update a field; this will trigger callback functions
	FIELDS:MarkDirty();	-- marks all fields to update on next request
	FIELDS:GetCached(field_name);			-- returns cached value
--]]

EncounterShadowFields = {};

require "table"
require "lib/lib_Callback2"

local FIELDS_API = {};
local lf = {}
local d_QueuedCallbacks = {}
local cb_QueueCallbacks = Callback2.Create()

function EncounterShadowFields.Create(encounter_id)
	local FIELDS = {encounter_id = encounter_id,
					callbacks = {},
					cache = {}};
	-- methods:
	for k,v in pairs(FIELDS_API) do
		FIELDS[k] = v;
	end
	
	return FIELDS;
end

function FIELDS_API.Finalize(FIELDS)
	-- just clear out
	for k,v in pairs(FIELDS) do
		FIELDS[k] = nil;
	end
end

function FIELDS_API.AddListener(FIELDS, field_name, callback_func)
	FIELDS.callbacks[field_name] = callback_func;
end

function FIELDS_API.GetFields(FIELDS)
	local newVals = Game.GetEncounterUiFields(FIELDS.encounter_id);
	local tbl = {}
	if newVals then
		for field_name, _ in pairs(newVals) do
			table.insert(tbl, field_name)
		end
	end
	return tbl
end

function FIELDS_API.HasField(FIELDS, field)
	local newVals = Game.GetEncounterUiFields(FIELDS.encounter_id);
	return newVals[field] ~= nil
end

function FIELDS_API.Update(FIELDS)
	local newVals = Game.GetEncounterUiFields(FIELDS.encounter_id);
	if (not newVals) then
		newVals = {};
	end
	for field_name,new_val in pairs(newVals) do
		FIELDS:UpdateField(field_name, new_val);
	end
	-- prune out lost values
	for field_name,old_val in pairs(FIELDS.cache) do
		if (newVals[field_name] == nil) then
			FIELDS:UpdateField(field_name, nil);
		end
	end
end

function FIELDS_API.UpdateField(FIELDS, field_name, new_val, suppress_callback)
	if (FIELDS.callbacks[field_name]) then
		local old_val = FIELDS.cache[field_name];
		local same_value = lf.IsValueSame(new_val, old_val)
		if not same_value then
			-- queue callback
			table.insert(d_QueuedCallbacks, function()
				if not FIELDS or not FIELDS.callbacks then --safety check in case finalize is called right after a update
					warn("FIELDS or FIELDS.callbacks is nil, within a queued callback. FIELDS = " .. tostring(FIELDS))
					return
				end
				FIELDS.callbacks[field_name](new_val, {old_value=old_val, field_name=field_name, encounter_id=FIELDS.encounter_id} )
			end)
			cb_QueueCallbacks:Reschedule(0.001)
		end
	end
	-- cache value
	FIELDS.cache[field_name] = new_val;
end

function FIELDS_API.MarkDirty( FIELDS )
	FIELDS.cache = {};
end

function FIELDS_API.GetCached(FIELDS, field_name)
	return FIELDS.cache[field_name];
end

function lf.FireCallbacks()
	for _, func in ipairs(d_QueuedCallbacks) do
		func()
	end
	d_QueuedCallbacks = {}
end
cb_QueueCallbacks:Bind(lf.FireCallbacks)

function lf.IsValueSame(new_val, old_val)
	local val_type = type(new_val)
	if val_type ~= "table" then
		return isequal(old_val, new_val)
	else
		if not old_val then
			return false
		else
			for k, v in pairs(new_val) do
				local same = lf.IsValueSame(v, old_val[k])
				if not same then
					return false
				end
			end
			return true
		end
	end
end




