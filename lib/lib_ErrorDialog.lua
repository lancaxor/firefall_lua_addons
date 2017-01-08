
--
-- ErrorDialog - template lib for handling errors, and for presenting options to the player
--				ideally we never see this, but it should help the failure cases not be silently critical failures
--   by: John Su
--

--[[

Usage:
	err_string = ErrorDialog.ParseWebError(web_err)	-- formats a web error into a human-readable error string
	ErrorDialog.Display(err[, OnEscape])	-- displays an error; if err = nil, will call Hide() instead
												err only supports strings and widgets at the moment
												'OnEscape' is an optional function to pass; will be called if the user tries to 'esc' out
											
	ErrorDialog.Hide()						-- hides the error dialog; NOTE: this also clears out all the options
	
	ErrorDialog.ResetOptions()						-- clears all options from the dialog
	ErrorDialog.AddOption(label, OnPress[, args])	-- adds an option to the error screen.
													label = string to be used to label the button
													OnPress = function to run when button is pressed
													args = optional table with following optional params:
														color = color of button
	ErrorDialog.SetOptions(options)				-- same as ResetOptions() followed by AddOption() for each element in the [options] arg
													[options] should be an int-indexed array of the format:
														options[i] = {label=(string), OnPress=(function), args=(table)}
														- where 'args' is optional
	ErrorDialog.CLOSE_OPTION					-- quick option to just close the window; can be included in SetOptions' options,
													or passed directly into ErrorDialog.AddOption as the sole parameter
--]]

-- public API
ErrorDialog = {};

require "unicode"
require "lib/lib_Callback2";
require "lib/lib_RoundedPopupWindow";


-- private API
local OPTION_API = {};

-- private locals
local o_POPUP = nil;	-- PopupWindow.Create
local TEXT_WIDG = nil;
local DIALOG_FRAME = Component.CreateFrame("PanelFrame", "_lib_ErrorDialog");
DIALOG_FRAME:SetDepth(-5);
local OPTIONS_GROUP = Component.CreateWidget('<Group dimensions="bottom:100%-10; height:24; width:100%"/>', DIALOG_FRAME);
local CB2_CleanUp = Callback2.Create();
local o_BUTTONS = {};
local g_OnEscape = nil;		-- handler
local g_restoreInputMode = nil;
local g_FOSTER_ERR = nil;	-- the widget that represents the error, fostered into the window
local AddOption, ArrangeOptions, ResizeWindow; -- functions
local bp_Button = [[<Button dimensions="dock:fill" style="font:Demi_10; clicksound:button_press"/>]]

-- constants
local DEFAULT_ERROR_BUTTON_COLOR = "#FF8060";
ErrorDialog.CLOSE_OPTION = {label=Component.LookupText("Close"), OnPress=function() ErrorDialog.Hide() end};

function OnExit()
	if (g_OnEscape) then
		g_OnEscape();
	end
	ErrorDialog.Hide();
end

DIALOG_FRAME:Show(false);
DIALOG_FRAME:SetDims("center-x:50%; center-y:50%; width:500; height:300;");
DIALOG_FRAME:BindEvent("OnEscape", OnExit);
DIALOG_FRAME:BindEvent("OnClose", function()
	--Component.SetInputMode(g_restoreInputMode);
	g_restoreInputMode = nil;
end);

function ErrorDialog.Display(err, OnEscape)
	-- unfoster error
	if (g_FOSTER_ERR) then
		Component.FosterWidget(g_FOSTER_ERR, nil);
		g_FOSTER_ERR = nil;
	end
		
	if (err) then
		CB2_CleanUp:Cancel();
		if (not o_POPUP) then
			o_POPUP = RoundedPopupWindow.Create(DIALOG_FRAME);
			o_POPUP:SetTitle(Component.LookupText("ERROR"));
			o_POPUP:EnableClose(true, OnExit)	-- creates an 'X' button in the title
			o_POPUP:TintBack("#502020");
			TEXT_WIDG = Component.CreateWidget('<Text dimensions="width:100%; top:0; bottom:100%-40" style="font:Demi_13; halign:center; valign:center; wrap:true; clip:true"/>',
								o_POPUP:GetBody());
			
			assert(not DIALOG_FRAME:IsVisible());
			g_restoreInputMode = Component.GetInputMode();
			--Component.SetInputMode("cursor");
			DIALOG_FRAME:Show(true);
			Component.FosterWidget(OPTIONS_GROUP, o_POPUP:GetBody());
		end
		o_POPUP:Open();
		
		if (type(err) == "string") then
			TEXT_WIDG:SetText(err);
		elseif (Component.IsWidget(err)) then
			TEXT_WIDG:SetText("");
			g_FOSTER_ERR = err;
			Component.FosterWidget(g_FOSTER_ERR, o_POPUP:GetBody());
		end
		g_OnEscape = OnEscape;
		ErrorDialog.ResetOptions();
	else
		ErrorDialog.Hide();
	end
end

function ErrorDialog.ParseWebError(web_err)
	local text
	if web_err.data and web_err.data.code then
		text = Component.LookupText(web_err.data.code)
		if text and text ~= "" then
			




			return text
		end
	end
	if web_err.code then
		text = Component.LookupText(web_err.code)
		if text and text ~= "" then
			




			return text
		end
	end
	if web_err.data and web_err.data.message and web_err.data.message ~= "" then
		return web_err.data.message
	end
	if web_err.message and web_err.message ~= "" then
		return web_err.message
	end
	return unicode.format("error %s: %s", tostring(web_err.status or "unknown"), tostring(web_err.message or "unknown"))
end

function ErrorDialog.Hide()
	if (o_POPUP) then
		local dur = RoundedPopupWindow.CLOSE_DUR;
		o_POPUP:Close(dur);
		CB2_CleanUp:Reschedule(dur);
	end
end

function ErrorDialog.AddOption(label, OnPress, args)
	if (type(label) == "table") then
		-- treat this as three params in one
		local params = label;
		AddOption(params.label, params.OnPress, params.args);
	else
		AddOption(label, OnPress, args);
	end
	ArrangeButtons();
	ResizeWindow();
end

function ErrorDialog.ResetOptions()
	for _,BUTTON in ipairs(o_BUTTONS) do
		Component.RemoveWidget(BUTTON);
	end
	o_BUTTONS = {};
end

function ErrorDialog.SetOptions(options)
	ErrorDialog.ResetOptions();	
	assert(type(options) == "table", "options must be a table");
	for i,args in ipairs(options) do
		AddOption(args.label, args.OnPress, args.args);
	end
	ArrangeButtons();
	ResizeWindow();
end

-- local functions

local function CleanUpPopUp()
	if (o_POPUP) then
		o_POPUP:Remove();
		o_POPUP = nil;
		TEXT_WIDG = nil;
		DIALOG_FRAME:Show(false);
		ErrorDialog.ResetOptions();	
	end
end
CB2_CleanUp:Bind(CleanUpPopUp);

function AddOption(label, onPress, args)
	local BUTTON = Component.CreateWidget(bp_Button, OPTIONS_GROUP);
	o_BUTTONS[#o_BUTTONS + 1] = BUTTON;
	BUTTON:SetText(label);
	BUTTON:SetDims("center-x:50%; width:"..(100/#o_BUTTONS).."%");
	BUTTON:Autosize("center");
	BUTTON:ParamTo("tint", DEFAULT_ERROR_BUTTON_COLOR, 0);
	if (args) then
		if (args.color) then
			BUTTON:ParamTo("tint", args.color, 0);
		end
	end
	BUTTON:BindEvent("OnMouseUp", function()
		onPress();
	end);
	return BUTTON;
end

function ArrangeButtons()
	local n = #o_BUTTONS;
	for i=1, n do 
		local BUTTON = o_BUTTONS[i];
		BUTTON:SetDims("center-x:"..(100*i/(n+1)).."%; width:_");
	end
end

function ResizeWindow(dur)
	if( g_FOSTER_ERR ) then
		dur = dur or 0;
		DIALOG_FRAME:SetDims("width:500; center-x:_");
		local textDims = g_FOSTER_ERR:GetBounds(false);
		textDims.width = math.max(textDims.width, #o_BUTTONS * 120);	-- allocate some space for the buttons, too
		DIALOG_FRAME:MoveTo("width:"..(textDims.width+150).."; height:"..(textDims.height+150), dur);
	elseif (TEXT_WIDG) then
		dur = dur or 0;
		DIALOG_FRAME:SetDims("width:500; center-x:_");
		local textDims = TEXT_WIDG:GetTextDims(false);
		textDims.width = math.max(textDims.width, #o_BUTTONS * 120);	-- allocate some space for the buttons, too
		DIALOG_FRAME:MoveTo("width:"..(textDims.width+150).."; height:"..(textDims.height+150), dur);
	end
end
