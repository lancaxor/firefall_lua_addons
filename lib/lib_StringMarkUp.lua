
--
-- lib_StringMarkUp
--   by: Ken Cheung
--
--	This library is for inserting inputicons and widgets into display text

--[[ INTERFACE
	MSO = LibStringMarkUp.Create(text)	> create a Marked String Object
	
	MSO:ApplyTextMarkers(  text_widget )		> adds text markers to the widget
	MSO:CleanUpMarkers( [text_widget] )		> clears the marked up widget
--]]

LibStringMarkUp = {};

require "unicode"
require "lib/lib_InputIcon";
require "lib/lib_TextFormat";

local PRIVATE = {};

-- private members
local g_keybinds_dirty = true;
local d_keybinds = {};
local g_hasColorMarkers = false


-- LibTextMarkers Interface:
function LibStringMarkUp.Create( text )
	local MSO = {};
	text = Component.RemoveLocalizationTracking(text);
	MSO.ORIGNAL_TEXT = text;

	--test for color markers and remove them for now
	local TFTemp = TextFormat.Create()
	local function FormatTextTemp(text)
		TFTemp:AppendText(text)
	end
	local temp_handlers = {}
	TFTemp:AddColorHandlers(temp_handlers)
	TextFormat.HandleString(text, FormatTextTemp, temp_handlers)
	g_hasColorMarkers = TFTemp.total_text ~= MSO.ORIGNAL_TEXT
	text = TFTemp.total_text
		
	text = PRIVATE.SubstituteAbilities(text);
	
	MSO.SUBBED_TEXT, MSO.KEY_INSERTS = PRIVATE.SubstituteKeys(text);
	MSO.MARKERS = {};
	
	function MSO:ApplyTextMarkers( TEXT_WIDGET )
		self:CleanUpMarkers( TEXT_WIDGET ) ;
		
		TEXT_WIDGET:SetText( self.SUBBED_TEXT );		
		MSO.MARKERS[TEXT_WIDGET] = {};		
		if (#self.KEY_INSERTS > 0) then
			for i = 1, #self.KEY_INSERTS do
				local MARKER = {GROUP=Component.CreateWidget("<TextMarker dimensions=\"dock:fill\" style=\"valign:bottom; index:"..(self.KEY_INSERTS[i].position).."\"/>", TEXT_WIDGET)};
				MARKER.VISUAL = InputIcon.CreateVisual(MARKER.GROUP);
				MARKER.VISUAL:SetBind(self.KEY_INSERTS[i], true);
				--MARKER.VISUAL:SetParam("tint", "#80FFA0");
				local dims = MARKER.VISUAL:GetNativeDims();
				MARKER.GROUP:SetDims("left:0; top:0; width:"..dims.width.."; height:"..dims.height);
				MARKER.GROUP:SetAlign("center");
				
				table.insert(self.MARKERS[TEXT_WIDGET], MARKER);
			end
		end

		if g_hasColorMarkers then
			--get original text minus any key or ability markers
			local original_text = PRIVATE.SubstituteAbilities(MSO.ORIGNAL_TEXT);
			local text_no_keys, inserts = PRIVATE.SubstituteKeys(original_text);

			--handle color markers
			local TF = TextFormat.Create()
			local function FormatText(text)
				TF:AppendText(text)
			end
			local handlers = {}
			TF:AddColorHandlers(handlers)
			TextFormat.HandleString(text_no_keys, FormatText, handlers)
			TF:ApplyTo(TEXT_WIDGET)
		end
	end
	
	function MSO:CleanUpMarkers( TEXT_WIDGET ) 
		if(TEXT_WIDGET) then
			TEXT_WIDGET:SetText("");
			if ( self.MARKERS[TEXT_WIDGET] and #self.MARKERS[TEXT_WIDGET] > 0) then
				for k, MARKER in pairs(self.MARKERS[TEXT_WIDGET]) do
					Component.RemoveWidget(MARKER.GROUP);
				end
				self.MARKERS = {};
			end
		else
			for widget, GROUP in pairs(self.MARKERS) do
				for k, MARKER in pairs(GROUP) do
					Component.RemoveWidget(MARKER.GROUP);
				end
			end
		end
	end
	
	return MSO;
end

function LibStringMarkUp.UpdateKeybinds(bindstring)
	g_keybinds_dirty = true;
end

function LibStringMarkUp.GetKeybinds(bindstring)
	return PRIVATE.GetKeybinds(bindstring);
end

-- PRIVATE FUNCTIONS

function PRIVATE.SubstituteKeys(str)
	local keyBinds;
	local substitutions = 0;
	local newStr = "";
	local skip_chars = 0;	-- # of characters to skip from ConcatString (after successfully priming special KEY_ tokens)
	local inserts = {};

	local function ConcatString(substr)
		newStr = newStr..unicode.sub(substr, skip_chars+1);
		skip_chars = 0;
	end

	local function InsertKey(keycode, alt)
		table.insert(inserts, {
			alt = alt,
			keycode = keycode,
			position = unicode.len(newStr),
		});
	end

	TextFormat.HandleString(str,
		-- normal handler:
		ConcatString,

		-- special handlers:
		{
			-- Keybinds (bound in options; e.g. KEY_JUMP)
			["%[KEY_"] = function(substr, start_idx, end_idx)
				local token, token_start_idx, token_end_idx = PRIVATE.ExtractToken(str, start_idx, "%[KEY_", "%]");
				if (token) then
					substitutions = substitutions+1;
					skip_chars = #token+1;
					local binds = PRIVATE.GetKeybinds(token);
					if (binds) then
						for i, bind in ipairs(binds) do
							if (bind.keycode and bind.keycode ~= 0) then
								InsertKey(bind.keycode, bind.alt);								
								return;
							end
						end
					end
				else
					-- invalid format; just treat as a normal string
					return ConcatString(substr);
				end
			end,

			-- Keycodes (straight up numbers; eg. KEYCODE_025)
			["%[KEYCODE_"] = function(substr, start_idx, end_idx)
				local token, token_start_idx, token_end_idx = PRIVATE.ExtractToken(str, start_idx, "%[KEYCODE_", "%]");
				if (token) then
					local alt = false;	-- TODO: Settle on convention for representing alt in [KEYCODE_???]
					substitutions = substitutions+1;
					skip_chars = #token+1;
					InsertKey(tonumber(token), alt);
				else
					-- invalid format; just treat as a normal string
					return ConcatString(substr);
				end
			end,
		}
	);

	return newStr, inserts;
end

function PRIVATE.SubstituteAbilities(str)
	local abilities;
	local substitutions = 0;
	local newStr = "";
	local read_idx = 1;
	repeat
		local token, token_start_idx, token_end_idx = PRIVATE.ExtractToken(str, read_idx, "%[NAME_ABILITY", "%]");
		if (token) then
			newStr = newStr..unicode.sub(str, read_idx, token_start_idx-1);
			read_idx = token_end_idx;
			
			if (substitutions == 0) then
				abilities = Player.GetAbilities();
				abilities.slotted[5] = abilities.action;
			end
			substitutions = substitutions+1;
			
			token = tonumber(token);
			local subsToken;
			if (abilities.slotted[token]) then
				local abInfo = Player.GetAbilityInfo(abilities.slotted[token].abilityId);
				if (abInfo) then
					subsToken = abInfo.name;
				end
			end;
			if (not subsToken) then
				subsToken = Component.LookupText("ABILITY"..token);
			end
			newStr = newStr..subsToken;
		else
			break;
		end
	until (false)
	newStr = newStr..unicode.sub(str, read_idx);
	return newStr;
end

function PRIVATE.ExtractToken(str, search_start, tok_head, tok_tail)
	-- returns token_body, token_start_idx, token_end_idx;	idx are relative to str
	local tok_start = unicode.find(str, tok_head, search_start);
	if (tok_start) then
		local tok_end = unicode.find(str, tok_tail, tok_start+1);
		if (tok_end) then
			local token = unicode.sub(str, tok_start + unicode.len(tok_head)-1, tok_end-1);
			tok_end = tok_end + unicode.len(tok_tail)-1;
			return token, tok_start, tok_end;
		end
	end
	return nil;
end

function PRIVATE.GetKeybinds(bindstring)
	if (g_keybinds_dirty) then
		g_keybinds_dirty = false;
		d_keybinds = {
			Combat = System.GetKeyBindings("Combat", false),
			Movement = System.GetKeyBindings("Movement", false),
			Social = System.GetKeyBindings("Social", false),
			Interface = System.GetKeyBindings("Interface", false),
			Vehicle = System.GetKeyBindings("Vehicle", false),
		};
		-- uncase the keys
		for category,sets in pairs(d_keybinds) do
			local newSet = {};
			for action,binds in pairs(sets) do
				newSet[unicode.upper(action)] = binds;
			end
			d_keybinds[category] = newSet;
		end
	end
	bindstring = unicode.upper(bindstring);
	for idx,cat in pairs(d_keybinds) do
		if (cat[bindstring]) then
			return cat[bindstring];
		end
	end
	warn("could not find binding for "..tostring(bindstring));
end
