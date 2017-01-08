
-- ------------------------------------------
-- lib_PlayerContextualMenu
--   by: Brian Blose
-- ------------------------------------------

--[[ Usage:
	PlayerMenu.Show(playerName, reason, offline)	--triggers a player contextual menu for the specified player, 
														the reason is a string to define what interface/reason is triggering this so options can be whitelisted/blacklisted based on reason
														offline is a bool for if the player is known to be offline
													
	PlayerMenu.BindOnShow(func)						--registers the component as wanting to be able to add options to any triggered menus
														func is the function that will run when a menu is triggered for determining what options to add to the menu
														func(playerName, reason, offline) will be fired
													
	All the following methods can be triggered as PlayerMenu:<method> or SUBMENU:<method> where PlayerMenu adds an option to the root menu and SUBMENU is defined as the return of AddMenu
		make sure to use :<method> and not .<method> to fire the function call
													
	SUBMENU = PlayerMenu:AddMenu(params)			--creates a submenu with params as they are defined in lib_ContextMenu {label, label_key, menu}
														returns SUBMENU that inherits :AddMenu method plus all the following methods
													
	PlayerMenu:AddButton(params, func)				--creates a button option with params as defined in lib_ContextMenu {label, label_key, id, disable, texture, region, tint}
														func will be fired when the button is clicked with an arg of the id
													
	PlayerMenu:AddLabel(params)						--creates a label with params as defined in lib_ContextMenu {label, label_key, id, disable, texture, region, tint}
													
	PlayerMenu:AddCheck(params, func)				--creates a checkbox option with params as defined in lib_ContextMenu {label, label_key, id, disable, checked, radio_id}
														func will be fired when the checkbox is clicked with an arg of the checked state in boolean
													
	PlayerMenu:AddSeparator()						--adds a thin seperator line to the menu
--]]

PlayerMenu = {}
local lf = {} --table of local functions
local lcb = {} --table of liaison callback functions

require "table"
require "lib/lib_table"
require "lib/lib_Liaison"
require "lib/lib_Callback2"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local c_ComponentName = Component.GetInfo()

-- ------------------------------------------
-- VARIABLES
-- ------------------------------------------
local d_EntryData = {}
local d_EntryFuncs = {}
local f_OnMenuShow
local f_OnMenuClose
local cb_UpdateParams = Callback2.Create()
local g_Counter = 1

-- ------------------------------------------
-- GLOBAL FUNCTIONS
-- ------------------------------------------
function PlayerMenu.Show(playerName, reason, offline)
	Liaison.RemoteCall("PlayerContextualMenu", "Show", playerName, reason, offline)
end

function PlayerMenu.BindOnShow(func)
	assert(type(func) == "function", "PlayerMenu.BindOnShow requires param1 to be a function")
	Liaison.RemoteCall("PlayerContextualMenu", "RegisterOnShow", c_ComponentName)
	f_OnMenuShow = function(playerName, reason, offline)
		func(playerName, reason, offline)
		lf.SendEntries()
	end
end

function PlayerMenu.BindOnClose(func)
	assert(type(func) == "function", "PlayerMenu.BindOnClose requires param1 to be a function")
	Liaison.RemoteCall("PlayerContextualMenu", "RegisterOnClose", c_ComponentName)
	f_OnMenuClose = func
end

-- ------------------------------------------
-- CONTEXT MENU ENTRY METHODS
-- ------------------------------------------
function PlayerMenu:AddMenu(params)
	if not f_OnMenuShow then return nil end
	assert(self.AddMenu, "use :AddMenu instead of .AddMenu")
	assert(type(params) == "table", "missing params")
	lf.EnforceId(params)
	local tbl = lf.FindMenu(self)
	local entry = {
		type = "AddMenu",
		params = params,
		menu = {},
	}
	table.insert(tbl, entry)
	local menu_index = _table.copy(self.menu_index or {})
	table.insert(menu_index, #tbl)
	local MENU = {}
	MENU.entry = entry
	MENU.menu_index = menu_index
	MENU.menu_id = params.menu
	MENU.AddMenu = PlayerMenu.AddMenu
	MENU.AddButton = PlayerMenu.AddButton
	MENU.AddLabel = PlayerMenu.AddLabel
	MENU.AddCheck = PlayerMenu.AddCheck
	MENU.AddSeparator = PlayerMenu.AddSeparator
	MENU.UpdateParams = lf.UpdateParams
	return MENU
end

function PlayerMenu:AddButton(params, func)
	if not f_OnMenuShow then return nil end
	assert(self.AddButton, "use :AddButton instead of .AddButton")
	assert(type(params) == "table", "missing params")
	assert(type(func) == "function", "missing function")
	lf.EnforceId(params)
	local tbl = lf.FindMenu(self)
	local entry = {
		type = "AddButton",
		params = params,
	}
	d_EntryFuncs[(self.menu_id or "root").."_"..params.id] = func
	table.insert(tbl, entry)
	local BUTTON = {}
	BUTTON.entry = entry
	BUTTON.UpdateParams = lf.UpdateParams
	return BUTTON
end

function PlayerMenu:AddLabel(params)
	if not f_OnMenuShow then return nil end
	assert(self.AddLabel, "use :AddLabel instead of .AddLabel")
	assert(type(params) == "table", "missing params")
	lf.EnforceId(params)
	local tbl = lf.FindMenu(self)
	local entry = {
		type = "AddLabel",
		params = params,
	}
	table.insert(tbl, entry)
	local LABEL = {}
	LABEL.entry = entry
	LABEL.UpdateParams = lf.UpdateParams
	return LABEL
end

function PlayerMenu:AddCheck(params, func)
	if not f_OnMenuShow then return nil end
	assert(self.AddCheck, "use :AddCheck instead of .AddCheck")
	assert(type(params) == "table", "missing params")
	assert(type(func) == "function", "missing function")
	lf.EnforceId(params)
	local tbl = lf.FindMenu(self)
	local entry = {
		type = "AddCheck",
		params = params,
	}
	d_EntryFuncs[(self.menu_id or "root").."_"..params.id] = func
	table.insert(tbl, entry)
	local CHECK = {}
	CHECK.entry = entry
	CHECK.UpdateParams = lf.UpdateParams
	return CHECK
end

function PlayerMenu:AddSeparator(params)
	if not f_OnMenuShow then return nil end
	assert(self.AddSeparator, "use :AddSeparator instead of .AddSeparator")
	params = params or {}
	lf.EnforceId(params)
	local tbl = lf.FindMenu(self)
	local entry = {
		type = "AddSeparator",
		params = params,
	}
	table.insert(tbl, entry)
	local SEPARATOR = {}
	SEPARATOR.entry = entry
	SEPARATOR.UpdateParams = lf.UpdateParams
	return SEPARATOR
end

-- ------------------------------------------
-- LIAISON CALLBACK FUNCTIONS
-- ------------------------------------------
function lcb.OnMenuShow(playerName, reason, offline)
	d_EntryData = {}
	d_EntryFuncs = {}
	f_OnMenuShow(playerName, reason, offline)
end

function lcb.OnMenuClose()
	d_EntryData = {}
	d_EntryFuncs = {}
	f_OnMenuClose()
end

function lcb.OnSelected(id, value)
	local func = d_EntryFuncs[id]
	assert(func, "function not found")
	func(value)
end
Liaison.BindCallTable(lcb)

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.FindMenu(self)
	local tbl = d_EntryData
	if self.menu_index then
		for _, index in ipairs(self.menu_index) do
			tbl = tbl[index].menu
		end
	end
	return tbl
end

function lf.EnforceId(params)
	if not params.id then
		params.id = "__"..c_ComponentName.."__"..g_Counter
		g_Counter = g_Counter + 1
	end
end

function lf:UpdateParams(params)
	assert(self.entry, "use :UpdateParams instead of .UpdateParams")
	assert(type(params) == "table", "missing params")
	--can't update ids, so make sure we don't try
	params.id = nil
	params.radio_id = nil
	params.menu = nil
	--update params
	for k, v in pairs(params) do
		self.entry.params[k] = v
	end
	--queue the changes to fire on the next frame
	cb_UpdateParams:Reschedule(0.01)
end

function lf.SendEntries()
	Liaison.RemoteCall("PlayerContextualMenu", "AddEntries", d_EntryData, c_ComponentName)
end

function lf.UpdateEntries()
	Liaison.RemoteCall("PlayerContextualMenu", "UpdateEntries", d_EntryData)
end
cb_UpdateParams:Bind(lf.UpdateEntries)













