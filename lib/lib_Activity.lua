
--
-- lib_Activity
--	by: John Su
--
--	Create an activity for submission to the ActivityDirector

--[[ INTERFACE

	ACTIVITY = Activity.Create([activity_id])	-- creates an activity with optional id (if specified, must be globally unique)
	
	ACTIVITY:Destroy();
	
	MULTIART = ACTIVITY:GetIcon()	--	see lib_MultiArt; this is the icon that appears on the Activity Tracker
	activity_id = ACTIVITY:GetId()	-- gets the activity id
	
	ACTIVITY:SetTitle(text)			-- this is the simple title
	ACTIVITY:SetDescription(text)	-- this is the more detailed instruction
	
	ACTIVITY:SetLocation(pos)		-- sets the location of this activity (pos = {x,y,z} table, or nil)
	
	ACTIVITY:SetTags(tags_table)	-- tags this activity; indices don't matter, but values should be strings
	ACTIVITY:AddTags(tag1, tag2, ...)	-- appends tags; tags should be strings
	
	ACTIVITY is also an EventDispatcher delegate (see lib_EventDispatcher)
		Events:
			"OnPrioritized"		(given a new spot by the ActivityDirector; args={active=bool, rank=int})
	
--]]

Activity = {};	-- external interface

require "lib/lib_Liaison"
require "lib/lib_MultiArt"
require "lib/lib_EventDispatcher"


-- constants
local LFRAME = Liaison.GetFrame();
local COMP_ID = Component.GetInfo();

local PRIVATE = {};
local ACTIVITY_API = {};
local w_ACTIVITIES = {};
local g_counter = 1;	-- component-unique counter

-- local functions (defined later)
local SendActivityMessage;

------------------
-- Activity API --
------------------

function Activity.Create(id)
	if (not id) then
		id = COMP_ID.."_"..g_counter;
	else
		id = tostring(id);
	end
	assert(not w_ACTIVITIES[id], "attempted to reuse marker id '"..id.."'");
	g_counter = g_counter+1;
	
	local ACTIVITY = {
		id = id,
	};
	ACTIVITY.DISPATCHER = EventDispatcher.Create(ACTIVITY);
	ACTIVITY.DISPATCHER:Delegate(ACTIVITY);
	
	-- function binds
	for k,method in pairs(ACTIVITY_API) do
		ACTIVITY[k] = method;
	end
	
	w_ACTIVITIES[ACTIVITY.id] = ACTIVITY;
	
	SendActivityMessage("create_activity", {
		id=ACTIVITY.id,
		COMP=COMP_ID,
		liaison=Liaison.GetPath(),
	});
	return ACTIVITY;
end

----------------
-- ACTIVITY API --
----------------

function ACTIVITY_API.Destroy(ACTIVITY)	
	w_ACTIVITIES[ACTIVITY.id] = nil;
	
	ACTIVITY.DISPATCHER:DispatchEvent("OnDestroyed");
	ACTIVITY.DISPATCHER:Destroy();
	
	ACTIVITY:ShowOnRadar(false);
	ACTIVITY:SetContextNodes(nil);
	
	SendActivityMessage("destroy_marker", {id=ACTIVITY.id});
	ACTIVITY.ICON:Destroy();
	Component.RemoveWidget(ACTIVITY.GROUP);
	-- gut it
	for k,v in pairs(ACTIVITY) do
		ACTIVITY[k] = nil;
	end
end

function ACTIVITY_API.GetIcon(ACTIVITY)
	return ACTIVITY.ICON;
end

function ACTIVITY_API.GetId(ACTIVITY)
	return ACTIVITY.id;
end

--------------------
-- MISC FUNCTIONS --
--------------------

function SendActivityMessage(type, data)
	Liaison.RemoteCall("ActivityDirector", "OnLibActivityMessage", type, data);
end

Liaison.BindMessage("lib_Activity_Event", function(args)
	args = jsontotable(args);
	local ACTIVITY = w_ACTIVITIES[args.id];
	if (ACTIVITY) then
		ACTIVITY:DispatchEvent(args.event, args.args);
	end
end);
