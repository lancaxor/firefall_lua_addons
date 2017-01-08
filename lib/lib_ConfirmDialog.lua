
--
-- ConfirmDialog - generic message box showing method
--   by: Jason Lee
--

--[[

Usage:
	ConfirmDialog.OpenConfirmDialog(args)
									-- [args] = a table of arguments sent to the ConfirmDialog class
--]]

-- public API
ConfirmDialog = {};


require "lib/lib_Liaison";
require "lib/lib_math"


-- private locals
local g_LiaisonPath = Liaison.GetPath();
local p_cbConfirmFunction;


-- FUNCTIONS

function ConfirmDialog.OpenConfirmDialog(args, response)
	p_cbConfirmFunction = response
	args.confirmMethod = g_LiaisonPath
	
	Component.PostMessage("ConfirmDialog:Main", "CreateDialog", tostring(args));
end


-----------------------
--- LOCAL FUNCTIONS  --
-----------------------

-- private handlers

local function OnConfirmResponse(args)
	local dat = jsontotable(args);
	p_cbConfirmFunction(dat.response);
end
Liaison.BindMessage("ConfirmDialog_Action", OnConfirmResponse);
