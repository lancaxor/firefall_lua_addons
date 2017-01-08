
--
-- lib_HudNote
--   by: John Su
--
--	Helper for creating HUD Notes

--[[ INTERFACE
	HUDNOTE = HudNote.Create()
	HUDNOTE:SetTitle(title[, subtitle])
	HUDNOTE:SetSubtitle(subtitle)
	
	HUDNOTE:SetIconTexture(texture, region)	-- incompatible with SetIconWidget
	HUDNOTE:SetIconWidget(WIDGET)			-- incompatible with SetIconTexture
	
	HUDNOTE:SetDescription(description)		-- incompatible with SetBodyWidget
	HUDNOTE:SetBodyWidget(WIDGET)			-- incompatible with SetDescription
	HUDNOTE:SetBodyHeight(height)			-- pixels; requires SetBodyWidget
	
	HUDNOTE:SetTags(tags)					-- tags is an int-indexed table of strings
	HUDNOTE:Countdown(seconds)				-- starts a timer on the HUDNOTE - must be called after HUDNOTE:Post(); if a timeout was set via SetTimeout then this will refresh the timeout callback to the updated timer
	HUDNOTE:SetTimeout(seconds, function)	-- will auto start a HUDNOTE:Countdown() on HUDNOTE:Post(); creates a callback to trigger the function; HUDNOTE:Remove() cancels the callback; used for questions that timeout
	
	HUDNOTE.SetPopupSound(sound)			-- sets the sound file to play when the popup triggers, false will disable the popup sound, nil(or not calling) will use the default popup sound
	
	HUDNOTE:SetPrompt(idx, label, callback_function, params...)	-- idx can be 1 or 2
	
	HUDNOTE:Post(params)					-- sends HUDNOTE to screen; can be applied once, params is an optional table for suppling extra params for the post
												--nopopup = boolean, default false, supresses the center screen popup
												--lock = time in seconds or nil, default nil, lock will force the popup to stay til the note is destroyed or the number of seconds passes (for very important popups)
												--ping = boolean, default false, plays a ping on each pulse while this notification is new (for notes that should be responded to in a timely fashion)
	
	HUDNOTE:Remove()						-- removes and finalizes HUDNOTE

--]]

HudNote = {};			-- interface

require "lib/lib_Liaison"
require "lib/lib_Callback2"
--require "lib/lib_EventDispatcher"

-- constants
local PF = {};			-- Private Functions

-- variables
local d_INTERNAL_NOTES = {};	-- holds NOTE data (title, body, etc.)
local d_IdToHandle = {};		-- d_IdToHandle[id] = handle
local g_handle_counter = 0;		-- incrementer for unique id's

-- HudNote Interface:
HudNote.Create = function()
	local HUDNOTE = {handle=g_handle_counter};
	g_handle_counter = g_handle_counter + 1;
	
	-- create NOTE data
	local NOTE = {
		id=(Component.GetInfo().."_"..g_handle_counter),
		replyTo=Liaison.GetPath(),
		active=false,
	};
	
	d_IdToHandle[NOTE.id] = HUDNOTE.handle;
	d_INTERNAL_NOTES[HUDNOTE.handle] = NOTE;
	
	-- API
	HUDNOTE.Remove = function(HUDNOTE)
		if (not HUDNOTE.handle) then
			error("invalid HUDNOTE object");
		end
		local NOTE = d_INTERNAL_NOTES[HUDNOTE.handle];
		d_IdToHandle[NOTE.id] = HUDNOTE.handle;
		d_INTERNAL_NOTES[HUDNOTE.handle] = nil;
		if (NOTE.active) then
			Component.GenerateEvent("MY_HUD_NOTE", {command="remove", id=NOTE.id});
		end
		if NOTE.onTimeout and NOTE.onTimeout.cb then
			NOTE.onTimeout.cb:Release()
			NOTE.onTimeout.cb = nil
		end
		NOTE.id = nil;
		NOTE.active = false;
		for k,v in pairs(HUDNOTE) do
			HUDNOTE[k] = nil;
		end
	end
	
	HUDNOTE.SetTitle = function(HUDNOTE, title, subtitle)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.title = title;
		if (subtitle) then
			NOTE.subtitle = subtitle;
		end
	end
	HUDNOTE.SetSubtitle = function(HUDNOTE, text)		PF.SetNoteField(HUDNOTE, "subtitle", text);	end
	HUDNOTE.SetDescription = function(HUDNOTE, text)	PF.SetNoteField(HUDNOTE, "body", text);		end
	HUDNOTE.SetTags = function(HUDNOTE, tags)			PF.SetNoteField(HUDNOTE, "tags", tags);	end
	HUDNOTE.SetIconTexture = function(HUDNOTE, texture, region)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.texture = texture;
		NOTE.region = region;
		NOTE.fosterIcon = nil;
	end
	HUDNOTE.SetIconWidget = function(HUDNOTE, WIDGET)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.fosterIcon = Component.GetInfo()..":"..WIDGET:GetPath();
		NOTE.texture = nil;
		NOTE.region = nil;
	end
	HUDNOTE.SetBodyWidget = function(HUDNOTE, WIDGET)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.fosterContent = Component.GetInfo()..":"..WIDGET:GetPath();
		NOTE.body = nil;
	end
	HUDNOTE.SetBodyHeight = function(HUDNOTE, height)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.contentHeight=height;
		if (NOTE.active) then
			Component.GenerateEvent("MY_HUD_NOTE", {command="resize", id=NOTE.id, contentHeight=height});
		end
	end
	HUDNOTE.SetPrompt = function(HUDNOTE, idx, label, func, ...)
		local NOTE = PF.GetNote(HUDNOTE);
		if (not NOTE.myPrompts) then
			NOTE.myPrompts = {prompts={}, callbacks={}};
		end
		NOTE.myPrompts.prompts[idx] = label;
		NOTE.myPrompts.callbacks[idx] = {func=func, arg={...}};
	end
	HUDNOTE.Countdown = function(HUDNOTE, duration)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.countdown = {duration=duration, start=System.GetClientTime()};
		Component.GenerateEvent("MY_HUD_NOTE", {command="countdown", id=NOTE.id, duration=duration});
		if NOTE.onTimeout and NOTE.onTimeout.cb then
			NOTE.onTimeout.cb:Reschedule(duration)
		end
	end
	HUDNOTE.SetTimeout = function(HUDNOTE, duration, func, ...)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.countdown = {duration=duration};
		NOTE.onTimeout = {func=func, arg={...}};
	end
	HUDNOTE.SetPopupSound = function(HUDNOTE, popup_sound)
		local NOTE = PF.GetNote(HUDNOTE);
		NOTE.popup_sound = popup_sound;
	end
	HUDNOTE.Post = function(HUDNOTE, params)
		local NOTE = PF.GetNote(HUDNOTE);
		if (NOTE.active) then
			error("You can only post a HudNote once!");
		end
		
		local hn_args = {
			command="post",
			id = NOTE.id,
			replyTo = NOTE.replyTo,
			prompts = NOTE.prompts,
			texture = NOTE.texture,
			region = NOTE.region,
			fosterIcon = NOTE.fosterIcon,
			fosterContent = NOTE.fosterContent,
			body = NOTE.body,
			contentHeight = NOTE.contentHeight,
			title = NOTE.title,
			subtitle = NOTE.subtitle,
			tags = NOTE.tags,
			popup_sound = NOTE.popup_sound,
			post = NOTE.post,
		};
		
		if params and type(params) == "table" then
			hn_args.lock = params.lock
			hn_args.nopopup = params.nopopup
			hn_args.ping = params.ping
		end
		
		if (not hn_args.prompts and NOTE.myPrompts) then
			hn_args.prompts = NOTE.myPrompts.prompts;
		end
		NOTE.active = (hn_args.prompts ~= nil);
		hn_args.post = NOTE.active;
		Component.GenerateEvent("MY_HUD_NOTE", {json=tostring(hn_args)});
		
		if NOTE.onTimeout and NOTE.countdown then
			NOTE.countdown.start = System.GetClientTime();
			local duration = NOTE.countdown.duration
			Component.GenerateEvent("MY_HUD_NOTE", {command="countdown", id=NOTE.id, duration=duration});
			NOTE.onTimeout.cb = Callback2.Create()
			NOTE.onTimeout.cb:Bind(function()
				local cb = NOTE.onTimeout;
				cb.func(unpack(cb.arg));
				NOTE.onTimeout = nil;
			end)
			NOTE.onTimeout.cb:Schedule(duration)
		end
	end
		
	return HUDNOTE;
end

-- MISC
PF.GetNote = function(HUDNOTE)
	return d_INTERNAL_NOTES[HUDNOTE.handle];
end

PF.SetNoteField = function(HUDNOTE, key, val)
	PF.GetNote(HUDNOTE)[key] = val;
end

Liaison.BindMessage("note_response", function(data)
	local reply = jsontotable(data);
	local handle = d_IdToHandle[reply.id];
	local NOTE = d_INTERNAL_NOTES[handle];
	local cb = NOTE.myPrompts.callbacks[reply.response];
	cb.func(unpack(cb.arg));
end);
