

--
-- TextFormat
--	and aide in advanced text presentation
--   by: John Su
--

--[[

	TF = TextFormat.Create(args);	-- create a new TextFormat; can supply initial string or another TextFormat to copy
	TextFormat.Clear(TEXT_WIDGET)	-- removes formatting from a TextWidget
	strings = TextFormat.IsolateString(str, pattern[, init, plain] )
									-- isolates a sub-string from a larger string, and returns up to three cuts of the original string:
										length of [strings] is the number of pieces the string was cut into
										strings[i] = a sub-string of the original string; one of these will match [pattern]
										strings.find_idx = 1,2, or 3; represents which index the [pattern] argument can be found in.
											if find_idx is nil, then [pattern] was not found.
	TextFormat.HandleString(string, default_handler, special_handlers)
									-- runs a number of functions on an input string
										[special_handlers] is a string-indexed table:
										-	special_handlers[sub_string] = function(sub_string, start_idx, end_idx)
										each occurrence of [sub_string] in [string] will have this function run on it
										default_handler(sub_string, start_idx, end_idx) is called on every sub string that is not indexed in [special_handlers]
										handlers will be called in order sub strings occur in the [string]
	TextFormat.IsTextFormat(obj)	-- returns true if [obj] is a TextFormat object
	TextFormat.ApplyMetaTable(TF)	-- Reapplies the TF metetable to a TF object;
										useful when receiving a TF from another component as the metatable functions gets stripped off making the TF unuseable

	TextFormat.GetTimeString( seconds )	-- return a time
										
	TF:Clear()						-- clears all formatting
	TF:AppendText(string)			-- appends a string
	TF:AppendTextKey(key[, ...])	-- appends a localized string
	TF:AppendFocusText(string, events)
	TF:AppendFocusTextKey(string, events)
	TF:AppendColor(color);			-- appends a color
	TF:AppendWidget(WIDGET[, args])	-- appends a widget (will be nested into a TextMarker Widget)
										args = {
											align = "top", "center", or "bottom" (defaults to "center")
											width = number (defaults to WIDGET's bound's width)
											height = number (defaults to WIDGET's bound's height)
											y_offset = number or dims string (defaults to 0)
										}
										NOTE: This will require a TextFormat.Clear() call to clean up if applied
	TF:AppendScaleScript(string[, args]) -- appends a sub/super script (like AppendWidget, will require TextFormat.Clear() after applied)
										args = {
											align = "top", "center", or "bottom" (defaults to "top")
											scale = number (defaults to 0.5)
											y_offset = number or dims string (defaults to 0)
										}	
	TF:AppendArt(args)					-- appends a MultiArt image (will be nested into a TextMarker Widget), if text size is changed AppendArt will need to be reapplied
										args = {
											texture = string, texture to use for image
											region = string, region of texture to use for image
											icon_id = number, assetid to use for the image (DDS assets only)
											url = string, web url to use for image source
											tint = string, tint in hex string for coloring multiart images
											text_dims = {
												xalign = string, dim with value to use for xalign (left:5, center-x:50%)
												yalign = string, dim with value to use for yalign (bottom:5, center-y:50%)
												height = 1
												aspect = number, 0 - 1 based on aspect of height
											}
											dims = string, raw set of dims to use for aligning and sizing the art
											align = "top", "center", or "bottom" (defaults to "center")
											width = number (defaults to WIDGET's bound's height based on aspect)
											height = number (defaults to WIDGET's bound's height)
											y_offset = number or dims string (defaults to 0)
										}
										NOTE: This will require a TextFormat.Clear() call to clean up if applied
										
	TF:ApplyTo(TEXT_WIDGET)			-- applies formatting to a TextWidget
	TF:Concat(TEXT_FORMAT)			-- adds TEXT_FORMAT to the current one
	string = TF:GetString()			-- gets whole string
	len = TF:GetLength()			-- gets length of string
	
	TF1 + TF2 = TF3					-- concatenates two TextFormats
	
	TF_CLONE = TF:Clone()			-- returns a copy of this object
	
	TF is garbage collection safe, and does not require a destructor

--]]

TextFormat = {};
require "table"
require "unicode"
require "lib/lib_Multiart"
require "lib/lib_Callback2"
require "lib/lib_EventDispatcher"

local TF_API = {};
local INMARK_API = {};
local TF_METATABLE = {
	__index = function(t,key) return TF_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in TEXTFORMAT"); end,
	__add = function(t,obj)
		local SUM = TextFormat.Create(t);
		return SUM:Concat(obj);
	end,
	__gc = function(self)
		self.formats = nil;
	end,
};

local o_MARKED_TEXTWIDGETS = {};	-- o_MARKED_TEXTWIDGETS[TEXT_WIDGET] = {[i]=TEXTMARKER_WIDGET}
local DEFAULT_COLOR = "#FFFFFF";

local c_ComponentName = Component.GetInfo()
local g_UniqueIdCounter = 0

--FUNCTIONS
local AppendTextFormat;
local GetUniqueId
local INMARK_Create;

function TextFormat.Create(args)
	local TF = {
		formats = {
			{	-- int-indexed
				text = "",
				color = nil,
				inline_MARK = nil,	-- goes in at front
				len = 0,
				idx = 1,
			},
		},
		focusable_text = {},
		total_text = "",
		default_color = DEFAULT_COLOR,
	};
	if (args) then
		if (type(args) == "string") then
			TF.formats[1].text = args;
			TF.formats[1].len = unicode.len(args);
			TF.total_text = args;
		elseif TextFormat.IsTextFormat(obj) then
			for i,fmt in ipairs(args.formats) do
				TF.formats[i] = {
					text = fmt.text,
					color = fmt.color,
					len = fmt.len,
					idx = fmt.idx,
				};
			end
			TF.total_text = args.total_text;
			TF.default_color = args.default_color;
		else
			warn("constructor can be either a string or another TextFormat");
		end
	end
	TextFormat.ApplyMetaTable(TF)
	return TF;
end

function TextFormat.Clear(TEXT_WIDGET)
	local MARKED = o_MARKED_TEXTWIDGETS[TEXT_WIDGET];
	if (MARKED) then
		-- remove all the widget
		for k,INMARK in pairs(MARKED) do
			INMARK_API.CleanUp(INMARK)
		end
		o_MARKED_TEXTWIDGETS[TEXT_WIDGET] = nil;
	end
	-- clear the string
	TEXT_WIDGET:SetTextColor(DEFAULT_COLOR);
	TEXT_WIDGET:SetText("");
end

function TextFormat.IsolateString(str, pattern, ...)
	assert(type(str) == "string", "'str' is of the wrong type");
	assert(type(pattern) == "string", "'pattern' is of the wrong type");
	local strings = {};
	local find_start, find_end = unicode.find(str, pattern);
	if (find_start) then
		if (find_start > 1) then
			strings[#strings+1] = unicode.sub(str, 1, find_start-1, ...);
		end
		strings[#strings+1] = unicode.sub(str, find_start, find_end);
		strings.find_idx = #strings;
		if (find_end < unicode.len(str)) then
			strings[#strings+1] = unicode.sub(str, find_end+1);
		end
	else
		strings[1] = str;
	end
	return strings;
end

function TextFormat.HandleString(my_string, default_handler, special_handlers)
	assert(type(my_string) == "string");
	assert(type(default_handler) == "function");
	assert(type(special_handlers) == "table");
	local string_len = unicode.len(my_string);
	local parsings = {};
	for key,handler in pairs(special_handlers) do
		local start_idx = 1;
		while (start_idx and start_idx <= string_len) do
			local end_idx;
			start_idx, end_idx = unicode.find(my_string, key, start_idx);
			if (start_idx and end_idx and start_idx < end_idx) then
				local substr = unicode.sub(my_string, start_idx, end_idx)
				if( #substr < 1 ) then
					break;
				end
				
				parsings[#parsings+1] = {
					start_idx = start_idx,
					end_idx = end_idx,
					sub_string = substr,
					handler = handler,
				};
				start_idx = end_idx+1;
			else
				break;
			end
		end
	end
	table.sort(parsings, function(a,b) return a.start_idx < b.start_idx; end);
	local read_idx = 1;
	local parse_idx = 1;
	while(read_idx <= string_len and parsings[parse_idx]) do
		local parse = parsings[parse_idx];
		if (read_idx < parse.start_idx) then
			-- handle the default substring that precedes the parse
			local end_idx;
			local sub_string = unicode.sub(my_string, read_idx, parse.start_idx-1);
			default_handler(sub_string, read_idx, parse.start_idx-1);
		end
		-- handle the next parsing
		parse.handler(parse.sub_string, parse.start_idx, parse.end_idx);
		read_idx = parse.end_idx + 1;
		parse_idx = parse_idx + 1;
	end
	-- handle the leftover substring
	if (read_idx <= string_len) then
		local sub_string = unicode.sub(my_string, read_idx);
		default_handler(sub_string, read_idx, string_len);
	end
end

function TextFormat.IsTextFormat(obj)
	return (obj and getmetatable(obj) == TF_METATABLE);
end

function TextFormat.ApplyMetaTable(TF)
	setmetatable(TF, TF_METATABLE)
end

function TextFormat.GetTimeString( seconds )
	local minutes = seconds / 60;
	local hours = minutes / 60;
	local days = hours / 24;
	-- now modulo
	seconds = math.ceil(seconds) % 60;
	minutes = math.floor(minutes) % 60;
	hours = math.floor(hours) % 24;
	days = math.floor(days);
	-- format time
	local time_string;
	if (days >= 1) then
		time_string = Component.LookupText("TIME_IN_DAYS_AND_HOURS", days, hours);
	elseif (hours >= 1) then
		time_string = Component.LookupText("TIME_IN_HOURS_AND_MINUTES", hours, minutes);
	elseif (minutes >= 1) then
		time_string = Component.LookupText("TIME_IN_MINUTES_AND_SECONDS", minutes, seconds);
	else
		time_string = Component.LookupText("TIME_IN_SECONDS", seconds);
	end
	
	return time_string;
end

------------------------
-- T(EXT)F(ORMAT) API --
------------------------

function TF_API.Concat(TF, obj)
	local idx = #TF.formats;
	local fmt = TF.formats[idx];
	if (type(obj) == "string") then
		AppendTextFormat(TF, {
			text = obj,
			len = unicode.len(obj),
			color = fmt.color,
			inline_MARK = nil,
			idx = fmt.idx + fmt.len,
		}, idx);
	elseif TextFormat.IsTextFormat(obj) then
		for i,fmt in ipairs(obj.formats) do
			AppendTextFormat(TF, fmt, #TF.formats);
		end
		for FT_idx, tbl in pairs(obj.focusable_text) do
			TF.focusable_text[FT_idx] = tbl
		end
	else
		error("object of concatenation must be a string or TextFormat object");
	end
	return TF;
end

function TF_API.Clone(TF)
	return TextFormat.Create(TF);
end

function TF_API.AppendText(TF, str)
	str = str or "" --just encase we are trying to append nil
	local fmt = TF.formats[#TF.formats];
	fmt.text = fmt.text .. str;
	fmt.len = fmt.len + unicode.len(str);
	TF.total_text = TF.total_text .. str;
end

function TF_API.AppendTextKey(TF, key, ...)
	TF_API.AppendText(TF, Component.LookupText(key, ...));
end

function TF_API.AppendColor(TF, color)
	local fmt = TF.formats[#TF.formats];
	if (color == fmt.color) then
		-- no op
		return;
	elseif (fmt.len == 0 and not fmt.inline_MARK) then
		fmt.color = color;
	else
		-- add a new part
		fmt = {
			text = "",
			len = 0,
			color = color,
			inline_MARK = nil,
			idx = fmt.idx + fmt.len,
		}
		TF.formats[#TF.formats+1] = fmt;
	end
end

function TF_API.AppendWidget(TF, WIDGET, args)
	args = args or {};
	local INMARK_args = {
		widget = WIDGET,
		align = args.align or "center",
		width = args.width,
		height = args.height,
		y_offset = args.y_offset or 0,
	};
	
	local INMARK = INMARK_Create(TF, INMARK_args);	
end

function TF_API.AppendScaleScript(TF, str, args)
	args = args or {};
	local INMARK_args = {
		text = str,
		scale = args.scale or 0.5,
		align = args.align or "top",
		y_offset = args.y_offset or 0,
		word_piece = args.word_piece,
	};
	
	local INMARK = INMARK_Create(TF, INMARK_args);
end

function TF_API.AppendFocusText(TF, str, events)
	local function StringToTable(str)
		local texttable = {}
		for word, whitespace in unicode.gmatch(str, "(%S+)(%s*)") do
			table.insert(texttable, word)
			if whitespace ~= "" then
				table.insert(texttable, whitespace)
			end
		end
		return texttable
	end
	
	local sentence = StringToTable(str)
	local focustext_index = GetUniqueId()
	TF.focusable_text[focustext_index] = {
		mouse_entered = false,
		cb2_MouseEnter = Callback2.Create(),
		cb2_MouseLeave = Callback2.Create(),
	}
	for i=1, #sentence do
		local INMARK_args = {
			text = sentence[i],
			focus_tag = str,
			events = events or {},
			focustext_index = focustext_index,
		};
		if events.OnMouseDown or events.OnMouseUp or events.OnRightMouse or events.OnSubmit then
			INMARK_args.focus_cursor = "sys_hand"
		end
		
		local INMARK = INMARK_Create(TF, INMARK_args);
	end
end

function TF_API.AppendFocusTextKey(TF, key, ...)
	local replaces = {}
	local events = {}
    local nArgs = select('#', ...)
    local arg = {...}
	for i = 1, nArgs do
		if type(arg[i]) == "table" then
			events = arg[i]
		else
			table.insert(replaces, arg[i])
		end
	end
	TF_API.AppendFocusText(TF, Component.LookupText(key, unpack(replaces)), events);
end

function TF_API.AppendArt(TF, args)
	args = args or {};
	local INMARK_args = {
		art = { texture=args.texture, region=args.region, url=args.url, icon_id=args.icon_id },
		params = args.params or {},
		align = args.align or "center",
		y_offset = args.y_offset or 0,
		dims = args.dims,
		text_dims = args.text_dims,
		scale = args.scale or 1,
		use_line_tint = args.use_line_tint,
	};
	local params = {
		"saturation",	"exposure",
		"shadow",		"hotpoint",
		"glow",			"alpha",
		"tint",
	}
	for i=1, #params do
		if args[params[i]] then
			INMARK_args.params[params[i]] = args[params[i]]
		end
	end
	
	local INMARK = INMARK_Create(TF, INMARK_args);	
end

function TF_API.ApplyTo(TF, WIDGET)
	TextFormat.Clear(WIDGET);
	assert(WIDGET and WIDGET:GetType() == "Text", "not a TextWidget");
	WIDGET:SetText(TF.total_text);
	WIDGET:SetTextColor(TF.default_color);
	for i,fmt in ipairs(TF.formats) do
		if (fmt.len > 0) then
			WIDGET:SetTextColor(fmt.color or TF.default_color, nil, fmt.idx, fmt.idx + fmt.len-1);
		end
		if (fmt.inline_MARK) then
			INMARK_API.ApplyTo(fmt.inline_MARK, WIDGET, fmt.idx, TF);
			if (fmt.inline_MARK.TEXT_WIDGET) then
				fmt.inline_MARK.TEXT_WIDGET:SetTextColor(fmt.color or TF.default_color);
			end
		end
	end
end

function TF_API.GetString(TF)
	local str = ""
	for _, format in ipairs(TF.formats) do
		if format.inline_MARK and format.inline_MARK.text then
			str = str..format.inline_MARK.text
		end
		if format.text then
			str = str..format.text
		end
	end
	return str
end

function TF_API.GetLength(TF)
	return unicode.len(TF.total_text);
end

-- convert to TF_API
function TF_API.AddColorHandlers(TF, special_handlers)
	local color_stack={}
	local current_color = TF.default_color;
	local function FormatText(text)
		TF:AppendText(text)
	end
	
	special_handlers["%[color%=#?%w+%]"] = function(str)
		table.insert(color_stack, current_color);
		current_color = unicode.match(str, "=(#?%w+)");
		TF:AppendColor(current_color)
	end
	special_handlers["%[/color%]"] = function(str)
		if #color_stack > 0 then
			current_color = table.remove(color_stack);
		else
			current_color = TF.default_color;
		end
		TF:AppendColor(current_color)
	end
end

----------------------------
-- INLINE MARKER (INMARK) --
----------------------------
function INMARK_Create(TF, args)
	local INMARK = {
		align = args.align,
		scale = args.scale,
		-- these are optional
		foster_WIDGET = args.widget,
		text = args.text,
		y_offset = args.y_offset,
		-- focus text
		events = args.events,
		focus_tag = args.focus_tag,
		focustext_index = args.focustext_index,
		focus_cursor = args.focus_cursor,
		-- art
		art = args.art,
		params = args.params,
		dims = args.dims,
		text_dims = args.text_dims,
		use_line_tint = args.use_line_tint,
		word_piece = args.word_piece,
	};
	if (args.widget) then
		local widget_bounds = args.widget:GetBounds();
		INMARK.width = args.width or widget_bounds.width;
		INMARK.height = args.width or widget_bounds.height;
	end
	
	local prev_fmt = TF.formats[#TF.formats];
	local next_fmt = {
		text = "",
		color = prev_fmt.color,
		inline_MARK = INMARK,
		idx = prev_fmt.idx + prev_fmt.len,
		len = 0,
	}
	AppendTextFormat(TF, next_fmt, #TF.formats);
	
	return INMARK;
end

function INMARK_API.Destroy(INMARK)
	INMARK_API.CleanUp(INMARK)
	for k,v in pairs(INMARK) do
		INMARK[k] = nil;
	end
end

function INMARK_API.ApplyTo(INMARK, WIDGET, idx, TF)
	local TEXT_MARKER = Component.CreateWidget('<TextMarker dimensions="dock:fill"/>', WIDGET);
	TEXT_MARKER:SetWordPiece(INMARK.word_piece)
	if (INMARK.foster_WIDGET) then
		Component.FosterWidget(INMARK.foster_WIDGET, TEXT_MARKER);
	elseif (INMARK.events) then
		local params = {
			"saturation",	"exposure",
			"shadow",		"hotpoint",
			"glow",
		}
		INMARK.TEXT_WIDGET = Component.CreateWidget([[<Text dimensions="left:0; right:100%; top:-1; bottom:100%+1" style="padding:0; halign:right">
				<FocusBox name="focus" dimensions="left:-1; right:100%+1; top:0; bottom:100%"/>
			</Text>]], TEXT_MARKER);
		INMARK.TEXT_WIDGET:SetFont(WIDGET:GetFont())
		INMARK.TEXT_WIDGET:SetText(INMARK.text);
		INMARK.FOCUSBOX_WIDGET = INMARK.TEXT_WIDGET:GetChild("focus")
		if INMARK.focus_cursor then
			INMARK.FOCUSBOX_WIDGET:SetCursor(INMARK.focus_cursor)
		end
		local event_args = {tag = INMARK.focus_tag, widget = INMARK.TEXT_WIDGET}
		local function IsMouseEntered()
			return TF.focusable_text[INMARK.focustext_index].mouse_entered
		end
		local function SetMouseEntered(bool)
			TF.focusable_text[INMARK.focustext_index].mouse_entered = bool
		end
		local cb2_MouseEnter = TF.focusable_text[INMARK.focustext_index].cb2_MouseEnter
		cb2_MouseEnter:Bind(function()
			if not IsMouseEntered() then
				SetMouseEntered(true)
				INMARK:DispatchEvent("OnMouseEnter", event_args)
			end
		end)
		local cb2_MouseLeave = TF.focusable_text[INMARK.focustext_index].cb2_MouseLeave
		cb2_MouseLeave:Bind(function()
			if IsMouseEntered() then
				SetMouseEntered(false)
				INMARK:DispatchEvent("OnMouseLeave", event_args)
			end
		end)
		INMARK.DISPATCHER = EventDispatcher.Create(INMARK);
		INMARK.DISPATCHER:Delegate(INMARK);
		for i=1,#params do
			INMARK.TEXT_WIDGET:SetParam(params[i], WIDGET:GetParam(params[i]))
		end
		local use_hand_cursor = false
		for event, event_func in pairs(INMARK.events) do
			if event == "OnMouseEnter" then
				INMARK.FOCUSBOX_WIDGET:BindEvent(event, 
					function()
						if cb2_MouseLeave:Pending() then
							cb2_MouseLeave:Cancel()
						elseif cb2_MouseEnter:Pending() then
							cb2_MouseEnter:Cancel()
						elseif not IsMouseEntered() then
							cb2_MouseEnter:Schedule(0.001)
						end
					end)
			elseif event == "OnMouseLeave" then
				INMARK.FOCUSBOX_WIDGET:BindEvent(event, 
					function() 
						if cb2_MouseEnter:Pending() then
							cb2_MouseEnter:Cancel()
						elseif cb2_MouseLeave:Pending() then
							cb2_MouseLeave:Cancel()
						elseif IsMouseEntered() then
							cb2_MouseLeave:Schedule(0.001)
						end
					end)
			else
				INMARK.FOCUSBOX_WIDGET:BindEvent(event, 
					function()
						INMARK:DispatchEvent(event, event_args)
					end)
			end
			INMARK:AddHandler(event, function(args) event_func(args) end)
		end
		INMARK.align = WIDGET:GetAlignment("valign")
		local text_dims = INMARK.TEXT_WIDGET:GetTextDims(false);
		INMARK.width = text_dims.width - 2;
		INMARK.height = text_dims.height;
	elseif (INMARK.art) then
		INMARK.MULTIART = MultiArt.Create(TEXT_MARKER)
		if INMARK.art.texture then
			INMARK.MULTIART:SetTexture(INMARK.art.texture, INMARK.art.region)
		elseif INMARK.art.url then
			INMARK.MULTIART:SetUrl(INMARK.art.url)
		elseif INMARK.art.icon_id then
			INMARK.MULTIART:SetIcon(INMARK.art.icon_id)
		end
		if ( INMARK.art.url or INMARK.art.icon_id ) and ( INMARK.params["tint"] and not INMARK.params["saturation"] ) then
			INMARK.MULTIART:SetParam("saturation", 0)
		end
		for param,value in pairs(INMARK.params) do
			if (INMARK.MULTIART:GetParam(param)) then
				INMARK.MULTIART:SetParam(param, value)
			else
				warn("Incorrect Param Name: "..param)
			end
		end
		if INMARK.use_line_tint then
			INMARK.MULTIART:SetParam("tint", TF.default_color)
		end
		
		if INMARK.dims then
			INMARK.MULTIART:SetDims(INMARK.dims)
		else
			local xalign = "center-x:50%"
			local yalign = "center-y:50%"
			local height = WIDGET:GetLineHeight()
			local aspect = 1
			if INMARK.text_dims then
				if INMARK.text_dims.aspect then
					aspect = INMARK.text_dims.aspect
				end
				if INMARK.text_dims.line_height then
					height = height*INMARK.text_dims.line_height
				end
				if not INMARK.text_dims.xalign then
					if INMARK.align == unicode.lower("left") then
						xalign = "left:"
					elseif INMARK.align == unicode.lower("right") then
						xalign = "right:100%"
					end
				elseif INMARK.text_dims.xalign then
					xalign = INMARK.text_dims.xalign
				end
				if INMARK.text_dims.yalign then
					yalign = INMARK.text_dims.yalign
				elseif INMARK.y_offset then
					local yoffset = INMARK.y_offset
					if yoffset >= 0 then
						yoffset = "+"..yoffset
					end
					yalign = yalign..yoffset
				end
			end
			INMARK.MULTIART:SetDims(xalign.."; "..yalign.."; height:"..height.."; width:"..height*aspect)
		end
		INMARK.MULTIART:SetParam("scalex", INMARK.scale);
		INMARK.MULTIART:SetParam("scaley", INMARK.scale);
		
		local dims = INMARK.MULTIART:GetBounds();
		INMARK.width = dims.width;
		INMARK.height = dims.height;
	
	elseif (INMARK.text) then
		INMARK.TEXT_WIDGET = Component.CreateWidget('<Text dimensions="dock:fill" style="padding:0"/>', TEXT_MARKER);
		INMARK.TEXT_WIDGET:SetFont(WIDGET:GetFont());
		INMARK.TEXT_WIDGET:SetText(INMARK.text);
		INMARK.TEXT_WIDGET:SetParam("scalex", INMARK.scale);
		INMARK.TEXT_WIDGET:SetParam("scaley", INMARK.scale);
		INMARK.TEXT_WIDGET:SetDims("top:"..INMARK.y_offset);
		local text_dims = INMARK.TEXT_WIDGET:GetTextDims(false);
		INMARK.width = text_dims.width;
		INMARK.height = text_dims.height;
	else
		error("invalid marker in TextFormat");
	end
	
	TEXT_MARKER:SetDims("width:"..INMARK.width.."; height:"..INMARK.height);
	TEXT_MARKER:SetIndex(idx-1);
	TEXT_MARKER:SetAlign(INMARK.align);
	
	INMARK.TEXT_MARKER = TEXT_MARKER;
			
	local MARKED_TEXTS = o_MARKED_TEXTWIDGETS[WIDGET];
	if not (MARKED_TEXTS) then
		MARKED_TEXTS = {};
		o_MARKED_TEXTWIDGETS[WIDGET] = MARKED_TEXTS;
	end
	MARKED_TEXTS[#MARKED_TEXTS+1] = INMARK;
end

function INMARK_API.CleanUp(INMARK)
	if (INMARK.MULTIART) then
		INMARK.MULTIART:Destroy();
		INMARK.MULTIART = nil;
	end
	if (Component.IsWidget(INMARK.TEXT_MARKER)) then
		Component.RemoveWidget(INMARK.TEXT_MARKER);
	end
	INMARK.TEXT_MARKER = nil;
	INMARK.TEXT_WIDGET = nil;
end

-- PRIVATE

function AppendTextFormat(TF, append_fmt, add_after_idx)
	-- fmt = {text, color, inline_MARK, len, idx}
	local dest_fmt = TF.formats[add_after_idx];
	assert(dest_fmt);
	local adjust_from_idx;
	if (dest_fmt.color == append_fmt.color and not append_fmt.inline_MARK) then
		dest_fmt.text = dest_fmt.text .. append_fmt.text;
		dest_fmt.len = dest_fmt.len + append_fmt.len;
		adjust_from_idx = add_after_idx+1;
	else
		table.insert(TF.formats, add_after_idx+1,
			{
				text = append_fmt.text,
				color = append_fmt.color,
				inline_MARK = append_fmt.inline_MARK,
				len = append_fmt.len,
				idx = dest_fmt.idx + dest_fmt.len,
			}
		);
		adjust_from_idx = add_after_idx+2;
	end
	-- shift all subsequent chunks by inserted length
	while (adjust_from_idx < #TF.formats) do
		TF.formats[adjust_from_idx].idx = TF.formats[adjust_from_idx].idx + append_fmt.len;
		adjust_from_idx = adjust_from_idx + 1;
	end
	TF.total_text = TF.total_text .. append_fmt.text;
end

function GetUniqueId()
	g_UniqueIdCounter = g_UniqueIdCounter + 1
	return c_ComponentName.."_"..g_UniqueIdCounter
end
