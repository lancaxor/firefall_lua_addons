
--
-- lib_Waypoint
--	by: John Su
--
--	for creating waypoints (NOTE: You *PROBABLY* don't want to use this. Try making a MapMarker instead, and showing it on HUD)

--[[ INTERFACE
	WAYPOINT = Waypoint.Create()			-- creates a waypoint
	
	WAYPOINT:Destroy();
	
	MULTIART = WAYPOINT:GetIcon()		--	see lib_MultiArt
	WAYPOINT:SetTitle(text)
	
	WAYPOINT:Show(visible)
	WAYPOINT:SetPriority(priority)		-- sets the priority of this waypoint (for orderly presentation on HUD)
	
	WAYPOINT:BindToPosition(pos)		-- places WAYPOINT at position pos = {x,y,z}
	WAYPOINT:BindToEntity(entityId)		-- places WAYPOINT on entity
	
	WAYPOINT:GetBoundEntity()			-- gets waypoints's bound entity
	WAYPOINT:GetPosition()				-- gets position of waypoints
	
	WAYPOINT:Ping([color])				-- draws attention to self with a colored ping (defaults to "glow")
	
	WAYPOINT is also an EventDispatcher that receives the following events:
		- "OnGotFocus"		-- player has looked at this waypoint
		- "OnLostFocus"		-- player has looked away
		- "OnEdgeTrip"		-- the waypoint has entered/left an edge of the screen
--]]

Waypoint = {};	-- external interface

require "lib/lib_Liaison"
require "lib/lib_MultiArt"
require "lib/lib_EventDispatcher"



-- constants
local LFRAME = Liaison.GetFrame();
local COMP_ID = Component.GetInfo();

local PRIVATE = {};
local WAYPOINT_API = {};
local o_WAYPOINTS = {};
local g_counter = 0;	-- component-unique counter

-------------------
-- Waypoint API --
-------------------

function Waypoint.Create()
	g_counter = g_counter + 1;
	local WAYPOINT = {
		id = COMP_ID.."_"..g_counter,
		ICON = MultiArt.Create(LFRAME),
		title = "",
		pos = nil,
		entityId = nil,
		visible = true,
		priority = 0,
		DISPATCHER = nil,
	}
	WAYPOINT.DISPATCHER = EventDispatcher.Create(WAYPOINT);
	WAYPOINT.DISPATCHER:Delegate(WAYPOINT);
	
	-- method binding
	for k,v in pairs(WAYPOINT_API) do
		WAYPOINT[k] = v;
	end
	
	o_WAYPOINTS[WAYPOINT.id] = WAYPOINT;
	PRIVATE.SendWaypointMessage("create_waypoint", {
		id = WAYPOINT.id,
		COMP_ID = COMP_ID,
		ICON_PATH = WAYPOINT.ICON:GetPath(),
		liaison = Liaison.GetPath(),
	});
	
	return WAYPOINT;
end

------------------
-- WAYPOINT API --
------------------

function WAYPOINT_API.Destroy(WAYPOINT)
	o_WAYPOINTS[WAYPOINT.id] = nil;
	
	WAYPOINT.DISPATCHER:Destroy();
	PRIVATE.SendWaypointMessage("destroy_waypoint", {id=WAYPOINT.id});
	
	WAYPOINT.ICON:Destroy();
	
	-- gut it
	for k,v in pairs(WAYPOINT) do
		WAYPOINT[k] = nil;
	end
end

function WAYPOINT_API.GetIcon(WAYPOINT)
	return WAYPOINT.ICON;
end

function WAYPOINT_API.BindToPosition(WAYPOINT, pos)
	WAYPOINT.pos = {x=pos.x, y=pos.y, z=pos.z};
	WAYPOINT.entityId = nil;
	PRIVATE.SendWaypointMessage("bind_waypoint", {id=WAYPOINT.id, pos=pos});
end

function WAYPOINT_API.BindToEntity(WAYPOINT, entityId)
	WAYPOINT.pos = nil;
	WAYPOINT.entityId = entityId;
	PRIVATE.SendWaypointMessage("bind_waypoint", {id=WAYPOINT.id, entityId=entityId});
end

function WAYPOINT_API.GetPosition(WAYPOINT)
	return WAYPOINT.pos;
end

function WAYPOINT_API.GetEntityId(WAYPOINT)
	return WAYPOINT.entityId;
end

function WAYPOINT_API.SetTitle(WAYPOINT, title)
	WAYPOINT.title = title;
	PRIVATE.SendWaypointMessage("set_title", {id=WAYPOINT.id, title=title});
end

function WAYPOINT_API.SetBody(WAYPOINT, body)
	PRIVATE.SendWaypointMessage("set_body", {id=WAYPOINT.id, body=body})
end

function WAYPOINT_API.Show(WAYPOINT, visible)
	if (WAYPOINT.visible ~= visible) then
		WAYPOINT.visible = visible;
		PRIVATE.SendWaypointMessage("show_waypoint", {id=WAYPOINT.id, visible=visible});
	end
end

function WAYPOINT_API.SetPriority(WAYPOINT, priority)
	if (priority ~= WAYPOINT.priority) then
		WAYPOINT.priority = priority or 0;
		PRIVATE.SendWaypointMessage("set_priority", {id=WAYPOINT.id, priority=priority});
	end
end

function WAYPOINT_API.SetGoldenPath(WAYPOINT, isGoldenPath)
	PRIVATE.SendWaypointMessage("set_golden_path", {id=WAYPOINT.id, isGoldenPath=isGoldenPath})
end

function WAYPOINT_API.Ping(WAYPOINT, color)
	PRIVATE.SendWaypointMessage("ping_waypoint", {id=WAYPOINT.id, color=(color or "glow")});
end

function WAYPOINT_API.SetThemeColor(WAYPOINT, color)
	PRIVATE.SendWaypointMessage("set_waypoint_color", {id=WAYPOINT.id, color=color})
end

function WAYPOINT_API.SetMapMarkerId(WAYPOINT, id)
	PRIVATE.SendWaypointMessage("set_mapmarker_id", {id=WAYPOINT.id, mapmarker_id=id})
end

function WAYPOINT_API.SetIconAnchor(WAYPOINT, show)
	PRIVATE.SendWaypointMessage("set_icon_anchor", {id=WAYPOINT.id, set_icon_anchor=show})
end

--------------------
-- MISC FUNCTIONS --
--------------------

function PRIVATE.SendWaypointMessage(type, data)
	Liaison.RemoteCall("Waypoints", "OnLiaisonMessage", type, data);
end

Liaison.BindMessage("lib_Waypoint_Event", function(args)
	args = jsontotable(args);
	local WAYPOINT = o_WAYPOINTS[args.id];
	if (WAYPOINT) then
		WAYPOINT:DispatchEvent(args.event, args.args);
	end
end);
