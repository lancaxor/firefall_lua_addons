
--
-- lib_MapMarker
--	by: John Su
--
--	Create an marker on the map / radar

--[[ INTERFACE
	MARKER = MapMarker.Create([marker_id])	-- creates a map marker with optional id (if specified, must be globally unique)
	MapMarker.SelectOnMap(marker_id)		-- opens the world map and selects the marker

	MapMarker.QueryMarkers(callback_func[, filter_args])
											-- calls callback_func(markers), where 
												markers = {
													[i] = {
														markerId,
														entityId,
														pos = {x,y,z},
														tags = {[tag]=true},
													}
												};
											filter_args is an optional table which supports the following elements:
												.distance + .position : returns markers within a given distance from a position
												.is_on_hud : returns markers which are on the HUD
												.is_on_radar : returns markers which are on the Radar
												.is_on_map : returns marker which are on the Map
	
	MARKER:Destroy();
	
	MULTIART = MARKER:GetIcon()	--	see lib_MultiArt
	markerId = MARKER:GetId()	-- gets the marker id
	
	MARKER:SetTitle(text)
	MARKER:SetSubtitle(text)
	GROUP_WIDGET = MARKER:GetBody()
	MARKER:SetBodyText(text)
	
	MARKER:ShowOnWorldMap(visible[, min_zoom, max_zoom])
									-- visible by default
										min/max zoom is are the levels at which the marker is visible on the WorldMap
										(0 = zoomed in, 1=zoomed out. See MapMarker.ZOOM_* for other constants)
	MARKER:SetTags(tags)			-- sets an table of tags (see MapMarker.TAG_* for constants)
										table may be int- or tag- indexed
	MARKER:ShowOnHud(visible)		-- invisible by default
	MARKER:ShowTrail(visible[, args])	-- show a navigation trail
											args is an optional table with members:
												- refresh_rate: number of seconds between refreshes
												- display_dur: number of seconds to display this for
	MARKER:SetHudPriority(priority)	-- sets visual priority for the marker on the HUD
	MARKER:ShowOnRadar(visible)		-- visible by default
	MARKER:SetIconEdge(visible)	-- not anchored by default
	MARKER:SetRadarEdgeMode(mode)	-- behavior for the marker when it reaches the edge of the radar
										MapMarker.EDGE_NONE		-- (default) disappears on the edge
										MapMarker.EDGE_CULLED	-- disappears on the edge, replaced by an arrow
																	for this mode, [param] is the color of the arrow
										MapMarker.EDGE_ALWAYS	-- extent locks regardless of culling range
	
	MARKER:SetThemeColor(color)		-- sets the color of the selection ring on the map / arrow on radar
	
	MARKER:BindToPosition(pos[, priority])
									-- places MARKER at position pos = {x,y,z}
										priority defaults to 0; MARKERs with greater/equal priority replace the lower
	MARKER:BindToEntity(entityId[, priority])
									-- places MARKER on entity
										priority defaults to 0; MARKERs with greater/equal priority replace the lower
	
	MARKER:GetBoundEntity()			-- gets marker's bound entity
	MARKER:GetPosition()			-- gets position of marker
	MARKER:SelectOnMap()			-- same as MapMarker.SelectOnMap(MARKER:GetId())
	
	MARKER:SetContextNodes(nodes)	-- sets context commands for world map
	
	MARKER:SetDistanceLatch(min,max)-- sets the distance latch on the marker (for firing the "OnDistanceTrip" event)
	
	MARKER:Ping([map_repititions=1])-- draws attention to this marker, map_repititions = how many times to pulse on map/radar
	
	MARKER is also an EventDispatcher delegate (see lib_EventDispatcher)
		Events:
			"OnGotFocus"	(cursor over from WorldMap)
			"OnLostFocus"	(cursor leave from WorldMap)
			"OnMapInspect"	(inspecting from WorldMap)
			"OnMapShelve"	(leaving inspection from WorldMap)
			"OnGotHudFocus"		(look over from game)
			"OnLostHudFocus"	(look leave from game)
			"OnHudEdgeTrip"		(waypoint goes over an edge of the screen)
			"OnDistanceTrip"	(marker leaves the distances set in :SetDistanceLatch)
			
			"OnDestroyed"	(destroyed from script)

	M_PROXY = MapMarker.CreateProxy(marker_id)
									-- creates a map marker proxy; basically allows you to expose the mapmarker
										(but not hide or modify)
	M_PROXY:Destroy()
	marker_id = M_PROXY:GetId()		-- returns the base marker_id that it was created from
	
	M_PROXY also shares the following methods with MARKER:
		:ShowOnWorldMap
		:ShowOnHud
		:ShowOnRadar
		:ShowIconOnEdge
		:SetRadarEdgeMode
		:SetHudPriority
		:SelectOnMap
		:SetContextNodes
		:Ping
		:ShowTrail
		
	M_PROXY also dispatches the same events as MARKER, as well as
		"OnMarkerLost"		(base marker has been removed)
	
--]]

MapMarker = {};	-- external interface

require "table"
require "lib/lib_Liaison"
require "lib/lib_MultiArt"
require "lib/lib_EventDispatcher"
require "lib/lib_ContextWheel"


-- Zoom Levels (0=zoomed out, 1=zoomed in)
MapMarker.ZOOM_MIN = 0;
MapMarker.ZOOM_TACTICAL_MIN = 0.75;
MapMarker.ZOOM_TACTICAL_MAX = 1.0;
MapMarker.ZOOM_OBJECTIVE_MIN = 0;
MapMarker.ZOOM_OBJECTIVE_MAX = 1.0;
MapMarker.ZOOM_REGION_MIN = 0;
MapMarker.ZOOM_REGION_MAX = 1;
MapMarker.ZOOM_MAX = 1;

-- Edge Modes
MapMarker.EDGE_NONE = 0;			-- disappears on the edge
MapMarker.EDGE_CULLED = 1;			-- extent locks with arrow icon
MapMarker.EDGE_ALWAYS = 2;			-- extent locks regardless of culling range

-- Tags
MapMarker.TAG_DEPLOYABLE = 'd';		-- generic deployables
MapMarker.TAG_PERSONAL = 'p';		-- player, player deployables, etc.
MapMarker.TAG_THREAT = 't';			-- enemies, warbringers
MapMarker.TAG_DYNAMIC_EVENT = 'e';	-- tornadoes, crashed thumpers
MapMarker.TAG_POI = 'i';			-- SIN Towers, important NPC's
MapMarker.TAG_SQUAD = 's';			-- squad
MapMarker.TAG_ARMY = 'a';			-- army
MapMarker.TAG_CAMPAIGN = 'c';		-- mission

MapMarker.DEFAULT_PING_DURATION = 1

-- constants
local LFRAME = Liaison.GetFrame();
local COMP_ID = Component.GetInfo();

local PRIVATE = {};
local MARKER_API = {};
local M_PROXY_API = {};
local w_MARKERS = {};
local w_M_PROXIES = {};
local g_counter = 1;	-- component-unique counter
local g_QueryMarkers_Callbacks = {};
local cb_AutoShow = nil;

-- local functions (defined later)
local SendMarkerMessage;
local AutoShow;

-------------------
-- MapMarker API --
-------------------

function MapMarker.Create(id, encounterMarkerId, markerType)
	if (not id) then
		id = COMP_ID.."_"..g_counter;
	else
		id = tostring(id);
	end
	assert(not w_MARKERS[id], "attempted to reuse marker id '"..id.."'");
	g_counter = g_counter+1;
	
	local GROUP = Component.CreateWidget('<Group name="MM'..g_counter..'" dimensions="dock:fill"/>', LFRAME);
	local MARKER = {
		id = id,
		encounterMarkerId = encounterMarkerId or "no id provided",
		markerType = markerType or "no type provided",
		isGoldenPath = isequal(markerType,449),
		pos = nil,
		entityId = nil,
		GROUP = GROUP,
		ICON = MultiArt.Create(GROUP),
		visibility = {
			worldmap = true,
			radar = false,
			hud = false,
		},
		radar_edge = MapMarker.EDGE_NONE,
		hud_priority = 0,
		zoom = {min=MapMarker.ZOOM_MIN,
				max=MapMarker.ZOOM_MAX },
		CONTEXT = nil,
		activated = false,	-- map action'd
		set_icon_anchor = false,
	};
	MARKER.TITLE_TEXT	= Component.CreateWidget('<Text name="title" dimensions="dock:fill"/>', GROUP);
	MARKER.BODY			= Component.CreateWidget('<Group name="body" dimensions="dock:fill"/>', GROUP);
	MARKER.BODY_TEXT	= Component.CreateWidget('<Text name="text" dimensions="dock:fill"/>', MARKER.BODY);
	
	MARKER.DISPATCHER = EventDispatcher.Create(MARKER);
	MARKER.DISPATCHER:Delegate(MARKER);
	
	-- Context Wheel activation
	MARKER.DISPATCHER:AddHandler("OnMapInspect", function()
		MARKER.activated = true;
		if (MARKER.CONTEXT) then
			MARKER.CONTEXT:Activate(true);
		end
	end);
	MARKER.DISPATCHER:AddHandler("OnMapShelve", function()
		MARKER.activated = false;
		if (MARKER.CONTEXT) then
			MARKER.CONTEXT:Activate(false);
		end
	end);
	
	-- function binds
	for k,method in pairs(MARKER_API) do
		MARKER[k] = method;
	end
	
	MARKER.autoshow = true;
	if (not cb_AutoShow) then
		cb_AutoShow = callback(AutoShow, nil, 0.01);
	end
	
	w_MARKERS[MARKER.id] = MARKER;
	
	SendMarkerMessage("create_marker", {
		id=MARKER.id,
		encounterMarkerId=MARKER.encounterMarkerId,
		markerType=MARKER.markerType,
		COMP=COMP_ID,
		ICON_PATH=MARKER.ICON:GetPath(),
		TITLE_PATH=MARKER.TITLE_TEXT:GetPath(),
		BODY_PATH=MARKER.BODY:GetPath(),
		liaison=Liaison.GetPath(),
		isGoldenPath = isGoldenPath
	});
	return MARKER;
end

function MapMarker.SelectOnMap(marker_id)
	assert(marker_id, "invalid map marker id");
	SendMarkerMessage("select_marker", {id=marker_id});
end

function MapMarker.QueryMarkers(callback_func, filter_args)
	-- push this callback onto the queue (FIFO)
	g_QueryMarkers_Callbacks[#g_QueryMarkers_Callbacks+1] = callback_func;
	Liaison.RemoteCall("WorldMap", "MapMarker_QueryMarkers", Component.GetInfo(), filter_args);
end

function MapMarker.Ping(marker_id, map_reps, duration, reverse, texture)
	duration = duration or MapMarker.DEFAULT_PING_DURATION
	map_reps = map_reps or 1
	SendMarkerMessage("ping_marker", {id=marker_id, map_repetitions=map_reps, duration=duration, reverse=reverse, texture=texture});
	-- Return total time of ping
	return duration * map_reps
end

function MapMarker.PingType(marker_type, map_reps, duration, reverse, texture)
	duration = duration or MapMarker.DEFAULT_PING_DURATION
	map_reps = map_reps or 1
	SendMarkerMessage("ping_marker_type", {id=marker_type, map_repetitions=map_reps, duration=duration, reverse=reverse, texture=texture});
	-- Return total time of ping
	return duration * map_reps
end

function MapMarker.Highlight(marker_id, duration, focus)
	SendMarkerMessage("highlight_marker", {id=marker_id, dur=duration or 0, shouldFocus=focus or false});
end

function MapMarker.HighlightType(marker_type, duration)
	SendMarkerMessage("highlight_marker_type", {id=marker_type, dur=duration or 0});
end

function MapMarker.HighlightLoc(x, y, z, duration, focus)
	SendMarkerMessage("highlight_marker_at_loc", {x=x, y=y, z=z, dur=duration or 0, shouldFocus=focus or false})
end

function MapMarker.EndHighlight()
	SendMarkerMessage("end_highlight")
end

function MapMarker.GetEncounterMarkerId(marker_id)
	if w_MARKERS[marker_id] ~= nil then
		return w_MARKERS[marker_id].encounterMarkerId
	end
	return nil
end

----------------
-- MISC --
----------------

Liaison.BindCall("_OnResponse_QueryMarkers", function(list)
	local callback_func = g_QueryMarkers_Callbacks[1];
	table.remove(g_QueryMarkers_Callbacks, 1);
	callback_func(list);
end);

----------------
-- MARKER API --
----------------

function MARKER_API.Destroy(MARKER)	
	w_MARKERS[MARKER.id] = nil;
	
	MARKER.DISPATCHER:DispatchEvent("OnDestroyed");
	MARKER.DISPATCHER:Destroy();
	
	MARKER:ShowOnRadar(false);
	MARKER:SetContextNodes(nil);
	
	SendMarkerMessage("destroy_marker", {id=MARKER.id});
	MARKER.ICON:Destroy();
	Component.RemoveWidget(MARKER.GROUP);
	-- gut it
	for k,v in pairs(MARKER) do
		MARKER[k] = nil;
	end
end

function MARKER_API.GetIcon(MARKER)
	return MARKER.ICON;
end

function MARKER_API.GetId(MARKER)
	return MARKER.id;
end

function MARKER_API.SetTitle(MARKER, title_text)
	MARKER.TITLE_TEXT:SetText(title_text);
	SendMarkerMessage("set_title", {id=MARKER.id, text=title_text});
end

function MARKER_API.SetSubtitle(MARKER, subtitle_text)
	SendMarkerMessage("set_subtitle", {id=MARKER.id, text=subtitle_text});
end

function MARKER_API.SetBodyText(MARKER, body_text)
	MARKER.BODY_TEXT:SetText(body_text);
end

function MARKER_API.GetBody(MARKER)
	return MARKER.BODY;
end

function MARKER_API.BindToPosition(MARKER, pos)
	MARKER.pos = pos;
	MARKER.entityId = nil;
	SendMarkerMessage("bind_marker", {id=MARKER.id, pos=pos});
end

function MARKER_API.BindToEntity(MARKER, entityId)
	MARKER.pos = nil;
	MARKER.entityId = entityId;
	SendMarkerMessage("bind_marker", {id=MARKER.id, entityId=entityId});
end

function MARKER_API.GetBoundEntity(MARKER)
	return MARKER.entityId;
end

function MARKER_API.GetPosition(MARKER)
	if (MARKER.pos) then
		return MARKER.pos;
	elseif (MARKER.entityId) then
		local bounds = Game.GetTargetBounds(MARKER.entityId);
		if (bounds) then
			return {x=bounds.x, y=bounds.y, z=bounds.z};
		end
	end
	return nil;
end

function MARKER_API.SetTags(MARKER, tags)
	assert(not tags or type(tags) == "table", "tags must be a table (or nil)");
	local msg = { id=MARKER.id, tags={} };
	if (tags) then
		-- convert tags to tag-indexed array
		if (#tags > 0) then
			-- int indexed
			for i,tag in ipairs(tags) do
				msg.tags[tag] = true;
			end
		else
			-- tag indexed
			for tag, flagged in pairs(tags) do
				if (flagged) then
					msg.tags[k] = true;
				end
			end
		end
	end
	SendMarkerMessage("set_tags", msg);
end

function MARKER_API.ShowOnWorldMap(MARKER, visible, min_zoom, max_zoom)
	if (MARKER.visibility.worldmap ~= visible or
		(min_zoom and MARKER.zoom.min ~= min_zoom) or
		(max_zoom and MARKER.zoom.max ~= max_zoom) ) then
		MARKER.visibility.worldmap = visible;
		MARKER.zoom.min = min_zoom or MARKER.zoom.min;
		MARKER.zoom.max = max_zoom or min_zoom or MARKER.zoom.max;
		SendMarkerMessage("show_worldmarker", {id=MARKER.id, visible=visible, min_zoom=min_zoom, max_zoom=max_zoom});
	end
end

function MARKER_API.ShowOnHud(MARKER, visible)
	if (MARKER.visibility.hud ~= visible) then
		MARKER.visibility.hud = visible;
		SendMarkerMessage("show_hud", {id=MARKER.id, visible=visible});
	end
end

function MARKER_API.SetIconAnchor(MARKER, visible)
	if (MARKER.set_icon_anchor ~= visible) then
		MARKER.set_icon_anchor = visible;
		SendMarkerMessage("set_icon_anchor", {id=MARKER.id, visible=visible});
	end
end

function MARKER_API.ShowTrail(MARKER, visible, args)
	local margs = {
		id = MARKER.id,
		visible = visible;
	};
	if (args) then
		margs.refresh_rate = args.refresh_rate;
		margs.display_dur = args.display_dur;
	end
	SendMarkerMessage("show_trail", margs);
end

function MARKER_API.ShowOnRadar(MARKER, visible)
	MARKER.autoshow = false;
	if (MARKER.visibility.radar ~= visible) then
		MARKER.visibility.radar = visible;
		SendMarkerMessage("show_radar", {id=MARKER.id, visible=visible});

		if visible and MARKER.radar_edge == MapMarker.EDGE_NONE then
			MARKER:SetRadarEdgeMode(MapMarker.EDGE_CULLED)
		end
	end
end

function MARKER_API.SetRadarEdgeMode(MARKER, mode)
	if (MARKER.radar_edge ~= mode) then
		MARKER.radar_edge = mode;
		SendMarkerMessage("set_radar_edge", {id=MARKER.id, mode=mode});
	end
end

function MARKER_API.SetHudPriority(MARKER, priority)
	assert(priority);
	if (MARKER.hud_priority ~= priority) then
		MARKER.hud_priority = priority;
		SendMarkerMessage("set_hud_priority", {id=MARKER.id, priority=priority});
	end
end

function MARKER_API.SetGoldenPath(MARKER, isGoldenPath)
	MARKER.isGoldenPath = isGoldenPath
	if isGoldenPath then
		MARKER:SetThemeColor("mission")
	end
	SendMarkerMessage("set_golden_path", {id=MARKER.id, isGoldenPath=isGoldenPath})
end

function MARKER_API.SelectOnMap(MARKER)
	MapMarker.SelectOnMap(MARKER:GetId());
end

function MARKER_API.SetThemeColor(MARKER, color)
	SendMarkerMessage("set_theme_color", {id=MARKER.id, color=color});
end

function MARKER_API.SetContextNodes(MARKER, NODES)
	-- remove existing nodes
	if (MARKER.CONTEXT) then
		MARKER.CONTEXT:Destroy();
		MARKER.CONTEXT = nil;
	end
	if (NODES) then
		MARKER.CONTEXT = ContextWheel.Create("map");
		MARKER.CONTEXT:SetNodes(NODES);
		MARKER.CONTEXT:Activate(MARKER.activated);
	end
end

function MARKER_API.SetDistanceLatch(MARKER, min, max)
	SendMarkerMessage("set_distance_latch", {id=MARKER.id, min=min, max=max});
end

function MARKER_API.Ping(MARKER, map_repetitions, duration, reverse, texture)
	SendMarkerMessage("ping_marker", {id=MARKER.id, map_repetitions=map_repetitions or 1, duration=duration, reverse=reverse, texture=texture});
end

-----------------
-- M_PROXY API --
-----------------

function MapMarker.CreateProxy(marker_id)
	g_counter = g_counter+1;
	local proxy_id = COMP_ID.."_"..g_counter;
	assert(type(marker_id) == "string", "marker_id must be a string; ("..tostring(marker_id)..")");
	
	local M_PROXY = {
		proxy_id = proxy_id,
		marker_id = marker_id,
		visibility = {
			worldmap = false,
			radar = false,
			hud = false,
		},
		radar_edge = MapMarker.EDGE_NONE,
		hud_priority = 0,
		zoom = {min=MapMarker.ZOOM_MAX,		-- min/max switched up intentionally to create "negative" start up
				max=MapMarker.ZOOM_MIN },
		CONTEXT = nil,
		activated = false,	-- map action'd
	}
	M_PROXY.DISPATCHER = EventDispatcher.Create(M_PROXY);
	M_PROXY.DISPATCHER:Delegate(M_PROXY);
	
	-- Context Command activation
	M_PROXY.DISPATCHER:AddHandler("OnMapInspect", function()
		M_PROXY.activated = true;
		if (M_PROXY.CONTEXT) then
			M_PROXY.CONTEXT:Activate(true);
		end
	end);
	M_PROXY.DISPATCHER:AddHandler("OnMapShelve", function()
		M_PROXY.activated = false;
		if (M_PROXY.CONTEXT) then
			M_PROXY.CONTEXT:Activate(false);
		end
	end);
	
	for k,v in pairs (M_PROXY_API) do
		M_PROXY[k] = v;
	end
	
	w_M_PROXIES[proxy_id] = M_PROXY;
	
	SendMarkerMessage("proxy_create", {
		proxy_id=proxy_id,
		marker_id=marker_id,
		COMP=COMP_ID,
		liaison=Liaison.GetPath()
	});
	return M_PROXY;
end

function M_PROXY_API.Destroy(M_PROXY)
	w_M_PROXIES[M_PROXY.proxy_id] = nil;
	
	M_PROXY.DISPATCHER:DispatchEvent("OnDestroyed");
	M_PROXY.DISPATCHER:Destroy();
	
	SendMarkerMessage("proxy_destroy", {
		proxy_id = M_PROXY.proxy_id,
		marker_id = M_PROXY.marker_id,
	});
	M_PROXY:SetContextNodes(nil);
	
	-- gut it
	for k,v in pairs(M_PROXY) do
		M_PROXY[k] = nil;
	end
end

function M_PROXY_API.GetId(M_PROXY)
	return M_PROXY.marker_id;
end

function M_PROXY_API.ShowOnWorldMap(M_PROXY, visible, min_zoom, max_zoom)
	if (M_PROXY.visibility.worldmap ~= visible or
		(min_zoom and M_PROXY.zoom.min ~= min_zoom) or
		(max_zoom and M_PROXY.zoom.max ~= max_zoom) ) then
		M_PROXY.visibility.worldmap = visible;
		M_PROXY.zoom.min = min_zoom or M_PROXY.zoom.min;
		M_PROXY.zoom.max = max_zoom or min_zoom or M_PROXY.zoom.max;
		SendMarkerMessage("proxy_show_worldmap", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			show = visible,
			min_zoom = M_PROXY.zoom.min,
			max_zoom = M_PROXY.zoom.max,
		});
	end
end

function M_PROXY_API.ShowOnHud(M_PROXY, visible)
	if (M_PROXY.visibility.hud ~= visible) then
		M_PROXY.visibility.hud = visible;
		SendMarkerMessage("proxy_show_hud", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			show = visible,
		});
	end
end

function M_PROXY_API.ShowOnRadar(M_PROXY, visible)
	if (M_PROXY.visibility.radar ~= visible) then
		M_PROXY.visibility.radar = visible;
		SendMarkerMessage("proxy_show_radar", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			show = visible,
		});
	end
end

function M_PROXY_API.SetIconAnchor(M_PROXY, visible)
	if (M_PROXY.set_icon_anchor ~= visible) then
		M_PROXY.set_icon_anchor = visible;
		SendMarkerMessage("proxy_set_icon_anchor", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			show = visible,
		});
	end
end

function M_PROXY_API.SetRadarEdgeMode(M_PROXY, mode)
	if (M_PROXY.radar_edge ~= mode) then
		M_PROXY.radar_edge = mode;
		SendMarkerMessage("proxy_radar_edge", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			mode = mode,
		});
	end
end

function M_PROXY_API.SetHudPriority(M_PROXY, priority)
	if (M_PROXY.hud_priority ~= priority) then
		M_PROXY.hud_priority = priority;
		SendMarkerMessage("proxy_hud_priority", {
			proxy_id = M_PROXY.proxy_id,
			marker_id = M_PROXY.marker_id,
			priority = priority,
		});
	end
end

function M_PROXY_API.SelectOnMap(M_PROXY)
	MapMarker.SelectOnMap(M_PROXY.marker_id);
end

function M_PROXY_API.SetContextNodes(M_PROXY, NODES, priority)
	return MARKER_API.SetContextNodes(M_PROXY, NODES, priority);
end

function M_PROXY_API.Ping(M_PROXY)
	SendMarkerMessage("ping_marker", {id=M_PROXY.marker_id});
end

function M_PROXY_API.ShowTrail(M_PROXY, visible, args)
	local margs = {
		id = M_PROXY.marker_id,
		visible = visible,
	};
	if (args) then
		margs.refresh_rate = args.refresh_rate;
		margs.display_dur = args.display_dur;
	end
	SendMarkerMessage("show_trail", margs);
end

--------------------
-- MISC FUNCTIONS --
--------------------

function SendMarkerMessage(method, data)
	Component.PostMessage("WorldMap:Main", method, tostring(data));
end

function AutoShow()
	cb_AutoShow = nil;
	for k,MARKER in pairs(w_MARKERS) do
		if (MARKER.autoshow) then
			MARKER.autoshow = nil;
			
			MARKER:ShowOnRadar(true);
		end
	end
end

Liaison.BindMessage("lib_MapMarker_Event", function(args)
	args = jsontotable(args);
	local MARKER = w_MARKERS[args.id];
	if (MARKER) then
		MARKER:DispatchEvent(args.event, args.args);
	end
end);

Liaison.BindMessage("lib_MapMarkerProxy_Event", function(args)
	args = jsontotable(args);
	local PROXY = w_M_PROXIES[args.id];
	if (PROXY) then
		PROXY:DispatchEvent(args.event, args.args);
	end
end);
