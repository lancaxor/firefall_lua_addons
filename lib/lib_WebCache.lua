
--
-- WebCache - provides an interface for caching queries from the web, as well as retrieving/refreshing it
--				only good for "GET" methods with no parameters.
--				Cached responses are shared across components
--   by: John Su
--

--[[

Usage:
	WebCache.Subscribe(url, OnUpdate[, autoRefresh])	-- subscribes to a url
														whenever a response comes back from that url, OnUpdate(response, error, params) will be called,
														'params' is the table of args POSTed to the url (may be nil)
														if 'autoRefresh' is true (default), WebCache.Request(url) will be implicitly called afterwards.
	WebCache.Unsubscribe(url, OnUpdate)					-- unsubscribes a function from a url
															
	WebCache.Request(url[, forceQueue])			-- issues an http request to the url
												No request will be made if one is already pending, unless [forceQueue] is true (default false)
												if [forceQueue] is true, one will be queued up
	WebCache.Post(url, params)					-- issues an http request to the url with the "POST" method and the given params	
	
	bool = WebCache.IsRequestPending([url])		-- returns if WebCache is waiting for a response from this url; if no url is specified, will check for any url
	
	cache = WebCache.GetCache(url[, post_params])	-- gets the last valid response from the requested url; returns 'nil' if none exists
													if [params] are supplied, gets the cached results from that particular Post
	
	age = WebCache.GetCacheAge(url[, post_params])	-- gets the age (in seconds) of the last valid response from the requested url; returns 'nil' if none exists
													if [params] are supplied, gets the cached age from that particular Post
	
	WebCache.ClearLocalCache(url[, post_params])		-- clears the local cache from memory
	
	WebCache.QuickUpdate(url[, post_params])	-- fires the subscribed OnUpdate function using the local cache; makes a request if not available
												Returns 'true' if a cache was used
	
	url = WebCache.MakeUrl(shortcut, ...)		-- form a URL, supplied with parameters. Valid calls are:
													"certs", "garage_slots", "gear_items", "frames_sale", "visuals"
--]]

-- public API
WebCache = {};

require "unicode";
require "lib/lib_Liaison";


-- private locals
local PRIVATE = {
	cache = {},		-- cache[url] = {timestamp, resp}
	handlers = {},	-- handlers[url][func] = function(resp, err)
	operators = {},	-- operators[ops] = System.GetOperatorSetting(ops)
	waiting = {},	-- waiting[url] = bool; waiting on response
};

-- url shortcuts
PRIVATE.url_shortcuts = {
	-- [shortcut] = {fmt=string, params={[i]=name}}
	crafting_certs	= {ops="clientapi_host",	fmt="/api/v3/characters/%s/manufacturing/certs",		params={"char_id"} },
	garage_slot		= {ops="clientapi_host",	fmt="/api/v3/characters/%s/garage_slots",				params={"char_id"} },

	frames_sale		= {ops="clientapi_host",	fmt="/api/v3/garage_slots/battleframes_for_sale",		params={} },
	visuals			= {ops="clientapi_host",	fmt="/api/v2/characters/%s/visuals",					params={"char_id"} },
	visuals_v2		= {ops="clientapi_host",	fmt="/api/v3/trade/products",							params={} },
	visual_loadouts	= {ops="clientapi_host",	fmt="/api/v2/characters/%s/visual_loadouts",			params={"char_id"} },
	
	zone_queue_ids	= {ops="clientapi_host",	fmt="/api/v1/zones/queue_ids",							params={} },
	workbenches 	= {ops="clientapi_host",	fmt="/api/v3/characters/%s/manufacturing/workbenches",	params={"char_id"} },
	manu_preview 	= {ops="clientapi_host",	fmt="/api/v3/characters/%s/manufacturing/preview",		params={"char_id"} },
	friends_list 	= {ops="ingame_host",		fmt="/api/v1/social/friend_list",						params={} },
	
	zone			= {ops="clientapi_host",	fmt="/api/v2/zone_settings/zone/%s",					params={"zoneid"} },	
	zone_context	= {ops="clientapi_host",	fmt="/api/v2/zone_settings/context/%s",					params={"context"} },
	zone_gametype	= {ops="clientapi_host",	fmt="/api/v2/zone_settings/gametype/%s",				params={"gametype"} },
	zone_list		= {ops="clientapi_host",	fmt="/api/v2/zone_settings",							params={} },
}

function PRIVATE.CallHandlers(url, ...)
	if (PRIVATE.handlers[url]) then
		for k,handler in pairs(PRIVATE.handlers[url]) do
			handler(...);
		end
	end
end

function PRIVATE.HandleUpdate(url, resp, timestamp, post_params)
	-- post_params = the params used to POST to this url
	local cache = PRIVATE.cache[url];
	if (not cache) then
		cache = {post={}};
		PRIVATE.cache[url] = cache;
	end
	
	if (post_params) then
		cache.post[tostring(post_params)] = {timestamp=timestamp, resp=resp};
	else
		cache.timestamp = timestamp;
		cache.resp = resp;
	end
	PRIVATE.waiting[url] = nil;
	PRIVATE.CallHandlers(url, resp, nil, post_params);
end
Liaison.BindCall("_WebCache_OnResponse", PRIVATE.HandleUpdate);		-- this one comes as a reponse to (anyone's) Request
Liaison.BindCall("_WebCache_UpdateCache", PRIVATE.HandleUpdate);	-- this one comes as a response to Subscribe

function PRIVATE.HandleError(url, err, params)
	PRIVATE.waiting[url] = nil;
	PRIVATE.CallHandlers(url, nil, err, params);	
end
Liaison.BindCall("_WebCache_OnError", PRIVATE.HandleError);

function WebCache.Subscribe(url, OnUpdate, autoRefresh)
	assert(type(OnUpdate) == "function", "second parameter must be a function");
	
	local handlers = PRIVATE.handlers[url];
	if (not handlers) then
		handlers = {};
		PRIVATE.handlers[url] = handlers;
		if (autoRefresh) then
			PRIVATE.waiting[url] = true;
		end
		Liaison.RemoteCall("WebCache", "WC_Subscribe", Component.GetInfo(), url, autoRefresh);
	end
	handlers[OnUpdate] = OnUpdate;
end

function WebCache.Unsubscribe(url, OnUpdate)
	local handlers = PRIVATE.handlers[url];
	if (handlers) then
		handlers[OnUpdate] = nil;
		for k,v in pairs(handlers) do
			-- don't continue if we still have handlers
			return;
		end
		PRIVATE.handlers[url] = nil;
		Liaison.RemoteCall("WebCache", "WC_Unsubscribe", Component.GetInfo(), url);
	end
end

function WebCache.Request(url, forceQueue)
	if (PRIVATE.handlers[url]) then
		PRIVATE.waiting[url] = true;
	end
	Liaison.RemoteCall("WebCache", "WC_Request", url, forceQueue);
end

function WebCache.Post(url, params)
	if (PRIVATE.handlers[url]) then
		PRIVATE.waiting[url] = true;
	end
	Liaison.RemoteCall("WebCache", "WC_Post", url, params);
end

local function GetCacheTable(url, params)
	-- returns a cache table, which includes both timestamp and response
	local cache = PRIVATE.cache[url];
	if (cache) then
		if (params) then
			return cache.post[tostring(params)];
		end
		return cache;
	end
	return nil;
end

function WebCache.GetCache(url, params)
	-- more accurately, GetCache*Response*
	local cache = GetCacheTable(url, params);
	if (cache) then
		return cache.resp;
	end
	return nil;
end

function WebCache.GetCacheAge(url, params)
	local cache = GetCacheTable(url, params);
	if (cache) then
		return System.GetElapsedTime(cache.timestamp);
	end
	return nil;
end

function WebCache.ClearLocalCache(url, params)
	if (params) then
		if (PRIVATE.cache[url]) then
			PRIVATE.cache[url][tostring(params)] = nil;
		end
	else
		PRIVATE.cache[url] = nil;
	end
end

function WebCache.QuickUpdate(url, params)
	local cache = GetCacheTable(url, params);
	if (cache) then
		PRIVATE.CallHandlers(url, cache.resp, nil, params);
		return true;
	else
		if (params) then
			WebCache.Post(url, params);
		else
			WebCache.Request(url);
		end
		return false;
	end
end

function WebCache.MakeUrl(shortcut, ...)
	local entry = PRIVATE.url_shortcuts[shortcut];
	assert(entry, "no url under the shortcut "..tostring(shortcut));
	if (not PRIVATE.operators[entry.ops]) then
		PRIVATE.operators[entry.ops] = System.GetOperatorSetting(entry.ops);
	end
	assert(#entry.params == #{...}, "parameter count mismatch; should be "..tostring(entry.params));
	return PRIVATE.operators[entry.ops]..unicode.format(entry.fmt, ...);
end

function WebCache.IsRequestPending(url)
	if (url) then
		return PRIVATE.waiting[url];
	else
		for url,_ in pairs(PRIVATE.waiting) do
			return true;
		end
		return false;
	end
end
