
--
-- Pagination - standardized pagination functionality
--   by: Terry Rizzi
--
--[[

Usage:
	Pagination.CreatePagination(args)
									-- [args] = a table of arguments sent to the Pagination class
	Pagination.Update(args)
--]]

Pagination = {} -- public API

require "lib/lib_Liaison";
require "lib/lib_math"


-- private locals
local g_LiaisonPath = Liaison.GetPath();
local cb_OnPaginationAction;

------------------------
--- GLOBAL FUNCTIONS  --
------------------------
function Pagination.CreatePagination(args, cb_OnAction)
	cb_OnPaginationAction = cb_OnAction
	args.liasonPath = g_LiaisonPath
	Component.PostMessage("Pagination:Main", "CreatePagination", tostring(args));
end

function Pagination.UpdatePagination(args)
	Component.PostMessage("Pagination:Main", "UpdatePagination", tostring(args));
end

function Pagination.ShowPagination(args)
	Component.PostMessage("Pagination:Main", "ShowPagination", tostring(args));
end

-----------------------
--- LOCAL FUNCTIONS  --
-----------------------
-- private handler
local function OnPaginationResponse(args)
	local data = jsontotable(args);
	cb_OnPaginationAction(data);
end
Liaison.BindMessage("Pagination_Action", OnPaginationResponse);
