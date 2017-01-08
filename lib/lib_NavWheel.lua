
--
-- lib_NavWheel
--   by: John Su
--
--	an interface for operating the NavWheel

--[[ INTERFACE

NavWheel.*:

	NavWheel.OpenNode(node_id[, activate])
										-- opens the navwheel directly to the node
											if [activate] (defaults to true), will open or perform action on the node
	NavWheel.NavigateToNode(node_id[, activate, dur_mult])
										-- navigates to a node from the current position
											if [activate] is true (defaults to false), will open or perform action on the node
											[dur_mult] is a multiplier for the animation duration (defaults to 1)
	NavWheel.ChangeForm(form)			-- changes NavWheel form:
											NavWheel.FORM_STANDARD	-> standard form
											NavWheel.FORM_MAP		-> wheel is shifted to the right to call out the center
	NavWheel.Close()					-- closes the navwheel
	
	NODE = NavWheel.CreateNode([id]);
								-- creates a NODE object, with an optional string id to reference it
									id's are global across components, and uniqueness is enforced

NODE.*: (see NavWheel.CreateNode())
	
	id = NODE:GetId();			-- returns the NODE's id as a string
	NODE:Destroy();				-- destroys the NODE, orphaning its children and releasing its id
	
	MULTIART = NODE:GetIcon()	-- returns the MultiArt (see lib_MultiArt) that is used as the icon
	
	NODE:SetTitle(string)		-- set the title
	NODE:SetDescription(string)	-- set the description
	
	NODE:SetAction(function)	-- set the click action (will remove child NODEs)
	
	NODE:SetParent(parent_id[, sort_weight])
								-- sets the NODE as a child NODE to the node with the matching id.
									NODE will be removed from its current parent, and if id ~= nil, attached to the new.
									[sort_weight] is a number used to help sort the parent NODE's children (default is 0)
	NODE:Activate(active)		-- setting 'active' to false is equivalent to NODE:SetParent(nil),
								   except that if you then set 'active' to true, it will return the NODE to it's prior position
								   
	parent_id, sort_weight = NODE:GetParent()
								-- returns the current parent_id and sort_weight of the NODE (set from NODE:SetParent)
								
	child_count = NODE:GetChildCount()
								-- returns the number of children
	
	NODE will also dispatch the following events: (see lib_EventDispatcher for API)
		"OnGotFocus"	-- node is highlighted/selected from NavWheel
		"OnLostFocus"	-- ^ node is not
		"OnOpen"		-- (if with children) the node's contents are opened for display
		"OnClose"		-- (if opened) the node's contents are closed
		"OnAction"		-- (if with action) the node is clicked on by the user
		"OnParentOpen"	-- the node's parent was opened (ie - this node is now displayed)
		"OnChildCountUpdate"	-- the node's child count has updated; arg.count = integer
		"OnDestroyed"	-- the node has been destroyed
--]]

NavWheel = {};			-- Main API

require "lib/lib_Liaison";
require "lib/lib_MultiArt";
require "lib/lib_EventDispatcher";

local NODE_API = {};	-- NODE API
local PRIVATE = {};		-- Private functions

------------------------
-- NavWheel Constants --
------------------------

NavWheel.FORM_STANDARD	= "standard";
NavWheel.FORM_MAP		= "aside";


local NODE_ORPHANAGE = Liaison.GetFrame();
local g_unique_counter = 0;	-- counts nodes
local w_NODES = {};			-- NODEs, indexed by id

------------------
-- NavWheel API --
------------------

function NavWheel.OpenNode(node_id, activate)
	activate = activate ~= false;
	assert(type(node_id) == "string", "must supply a node id");
	PRIVATE.MessageNavWheel("open_node", {id=node_id, activate=activate});
end

function NavWheel.Close()
	PRIVATE.MessageNavWheel("close");
end

function NavWheel.NavigateToNode(node_id, activate, dur_mult)
	activate = activate ~= false;
	assert(type(node_id) == "string", "must supply a node id");
	PRIVATE.MessageNavWheel("navigate_to", {id=node_id, activate=activate, dur_mult=(dur_mult or 1)});
end

function NavWheel.ChangeForm(form)
	PRIVATE.MessageNavWheel("change_form", {form=form});
end

function NavWheel.CreateNode(id)
	if (not id) then
		-- create unique id if not provided
		g_unique_counter = g_unique_counter + 1;
		id = Component.GetInfo().."_"..tostring(g_unique_counter);
	end
	
	-- struct def
	local NODE = {
		id			= id,
		ICON		= MultiArt.Create(NODE_ORPHANAGE),
		DISPATCHER	= nil,
		title		= nil,
		parent_id	= nil,
		sort_weight	= nil,
		desc		= nil,
		action		= nil,
		child_count	= 0,
		active		= true,
	}
	-- create event dispatcher
	NODE.DISPATCHER = EventDispatcher.Create(NODE);
	NODE.DISPATCHER:Delegate(NODE);
	
	-- bind functions
	for k,v in pairs(NODE_API) do
		NODE[k] = v;
	end
	
	-- bind action handler
	NODE:AddHandler("OnAction", function()
		if (NODE.action) then
			NODE.action();
		end
	end);
	
	-- bind child count update handler
	NODE:AddHandler("PreOnChildCountUpdate", function(args)
		NODE.child_count = args.count;
		NODE:DispatchEvent("OnChildCountUpdate", args);
	end);
	
	-- register
	assert(not w_NODES[id], "attempted to reuse NODE id: '"..tostring(id).."'");
	w_NODES[id] = NODE;
	
	-- activate remotely
	PRIVATE.MessageNavWheel("create", {
		id			= NODE.id,
		src_comp	= Component.GetInfo(),
		ICON		= NODE.ICON:GetPath(),
		liaison		= Liaison.GetPath(),
	});
	
	return NODE;
end


--------------
-- NODE API --
--------------

function NODE_API.Destroy(NODE)
	NODE.DISPATCHER:DispatchEvent("OnDestroyed");
	PRIVATE.MessageNavWheel("destroy", {
		id = NODE.id,
	});
	NODE.ICON:Destroy();
	NODE.DISPATCHER:Destroy();
	w_NODES[NODE.id] = nil;
	
	for k,v in pairs(NODE) do
		NODE[k] = nil;
	end
end

function NODE_API.GetId(NODE)
	return NODE.id;
end

function NODE_API.GetIcon(NODE)
	return NODE.ICON;
end

function NODE_API.GetChildCount(NODE)
	return NODE.child_count;
end

function NODE_API.Activate(NODE, active)
	if (active ~= NODE.active) then
		NODE.active = active;
		local parent_id = nil;
		if (active) then
			parent_id = NODE.parent_id;
		end
		PRIVATE.MessageNavWheel("set_parent", {
				id			= NODE.id,
				parent_id	= parent_id,
				sort_weight	= NODE.sort_weight,
			});
	end
end

function NODE_API.SetParent(NODE, parent_id, sort_weight)
	assert(parent_id == nil or type(parent_id) == "string", "invalid parent id; must be a string");
	if (NODE.parent_id ~= parent_id or 
		(sort_weight and sort_weight ~= NODE.sort_weight)) then
		NODE.parent_id = parent_id;
		NODE.sort_weight = sort_weight or NODE.sort_weight;
		if (NODE.active) then
			PRIVATE.MessageNavWheel("set_parent", {
				id			= NODE.id,
				parent_id	= parent_id,
				sort_weight	= sort_weight,
			});
		end
	end
end

function NODE_API.GetParent(NODE)
	return NODE.parent_id, NODE.sort_weight;
end

function NODE_API.SetAction(NODE, action)
	NODE.action = action;
end

function NODE_API.SetTitle(NODE, title)
	NODE.title = title;
	PRIVATE.MessageNavWheel("set_title", {
		id	= NODE.id,
		title = NODE.title,
	});
end

function NODE_API.SetDescription(NODE, description)
	NODE.desc = description;
	PRIVATE.MessageNavWheel("set_desc", {
		id	= NODE.id,
		desc = NODE.desc,
	});
end

-----------------------
-- PRIVATE Functions --
-----------------------

function PRIVATE.MessageNavWheel(type, args)
	-- message to NavWheel Component
	Component.PostMessage("NavWheel:Main", type, tostring(args));
end

-- initialization
Liaison.BindMessage("navwheel_event", function(args)
	args = jsontotable(args);
	local NODE = w_NODES[args.id];
	if (NODE) then
		NODE:DispatchEvent(args.event, args);
	end
end)

Liaison.BindMessage("navwheel_update", function(args)
	args = jsontotable(args);
	local NODE = w_NODES[args.id];
end)
