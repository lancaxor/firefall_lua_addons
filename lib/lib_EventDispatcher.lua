
--
-- lib_EventDispatcher
--   by: Red 5 Studios
--		an event listener/dispatcher system for abstracting flow

--[[
	EventDispatcher.Create([target=nil, auto_delegate=true]);
		> Returns a DISPATCHER object; [target] will be included in every event dispatched
			if [target] is a valid delgate and [auto_delegate] is true, will autorun DISPATCHER:Delegate([target])
	
	DISPATCHER:AddHandler(event, handler[, priority=0])
		> calls function [handler] when [event] is dispatched. Higher [priority] handlers fire first.
			if the [handler] is already added, this call will just update its priority
			[event] can be a number or string
	DISPATCHER:RemoveHandler(event, handler)
		> removes [handler] from event subscription
	DISPATCHER:HasHandler(event)
		> Returns if there are handlers for this event
	
	DISPATCHER:DispatchEvent(event[, args={}]);
		> calls all handlers added to [event]. Handlers are called with the [args] parameter
			args.target and args.event will automatically be populated if undefined
	
	DISPATCHER:Destroy();
		> cleans up the dispatcher object
		
	DISPATCHER:Delegate(rep);
		> allows [rep] to call select DISPATCHER methods directly from itself (e.g. rep:DispatchEvent())
			DISPATCHER can only have at most one delegate at a time; [rep] may be a table (or nil, for no delegate)
--]]

EventDispatcher = {};

require "table";

local DISPATCHER_API = {};
local PRIVATE = {};

local DELEGATE_METHODS = {
	"AddHandler",
	"RemoveHandler",
	"GetHandlers",
	"DispatchEvent",
}

function EventDispatcher.Create(target, auto_delegate)
	local DISPATCHER = {target=target, events={}};
	for k,v in pairs(DISPATCHER_API) do
		DISPATCHER[k] = v;
	end

	if (target and auto_delegate ~= false and type(target) == "table") then
		DISPATCHER:Delegate(target);
	end
	
	return DISPATCHER;
end

-- DISPATCHER API

function DISPATCHER_API:AddHandler(event, handler, priority)
	assert(event, "invalid event ("..tostring(event)..")");
	assert(type(handler) == "function", "handler must be a function");
	local handlers = self.events[event];
	if (not handlers) then
		handlers = {};
		self.events[event] = handlers;
	end
	local entry = PRIVATE.FindInKey("handler", handler, handlers);
	if (not entry) then
		entry = {handler=handler};
		table.insert(handlers, entry);
	end
	entry.priority = priority or 0;
	table.sort(handlers, PRIVATE.SortHandlers);
end

function DISPATCHER_API:RemoveHandler(event, handler)
	local handlers = self.events[event];
	if (handlers) then
		local entry, idx = PRIVATE.FindInKey("handler", handler, handlers);
		if (idx) then
			table.remove(handlers, idx);
		end
	end
end

function DISPATCHER_API:HasHandler(event)
	for i,entry in ipairs(self.events[event] or {}) do
		return true;
	end
	return false;
end

function DISPATCHER_API:DispatchEvent(event, args)
	local handlers = self.events[event];
	if (handlers) then
		args = args or {};
		args.target = args.target or self.target;
		args.event = args.event or event;
		
		self.abort_dispatch = false;

		local handlers_copy = {};	-- in case the handler adds/removes handlers
		for i,entry in ipairs(handlers) do
			handlers_copy[i] = entry;
		end
		for i,entry in ipairs(handlers_copy) do
			local args_copy = {};
			for k,v in pairs(args) do
				args_copy[k] = v;
			end
			entry.handler(args_copy);
		end
	end
end

function DISPATCHER_API:Destroy()
	self.target = nil;
	self.events = nil;
	self:Delegate(nil);
	for k,v in pairs(DISPATCHER_API) do
		self[k] = nil;
	end
end

function DISPATCHER_API:Delegate(rep)
	-- remove methods from old representative
	if (self.rep) then
		for i,name in ipairs(DELEGATE_METHODS) do
			self.rep[name] = nil;
		end
	end
	self.rep = rep;
	-- add methods to new representative
	if (self.rep) then
		assert(type(rep) == "table", "can only delegate to tables");
		local DISPATCHER = self;
		for i,name in ipairs(DELEGATE_METHODS) do
			rep[name] = function(...)
                local arg = {...};
				arg[1] = DISPATCHER;
				DISPATCHER[name](unpack(arg));
			end
		end
	end
end

-- PRIVATE

function PRIVATE.FindInKey(key, match, inTable)
	for k,v in pairs(inTable) do
		if (v[key] == match) then
			return v,k;
		end
	end
end

function PRIVATE.Find(match, inTable)
	for k,v in pairs(inTable) do
		if (v == match) then
			return k,v;
		end
	end
end

function PRIVATE.SortHandlers(A, B)
	return A.priority > B.priority;
end
