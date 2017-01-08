
--
-- lib_OverlayTips
--   by: Paul Schultz
--
-- For marking a UI up with an overlay of help tips.

--[[

-- INTERFACE

	OverlayTips.RegisterByWidget(widget, tipStringKey[, trackingFrame, font, textColor])	-- Register [widget] to show the string whose key is [tipStringKey]. Optionally
																							provide a [font] and [textColor] to not use this component's defaults.
																							[widget] can be a widget reference or path.
																				
	OverlayTips.RegisterByDims(widget, tipStringKey, dims[, font, textColor])				-- Register [widget] to show the string whose key is [tipStringKey]. Position
																							with [dims] instead of widget. Optionally provide a [font] and [textColor] to
																							not use this component's defaults. [widget] can be a widget reference or path.
																				
	OverlayTips.SetDefaultFont(fontStr)														-- Set a default font for this component's overlay tips, (e.g. "Bold_10")
	
	OverlayTips.SetDefaultTipColor(tintStr)													-- Set a default tint for the text in this component's overlay tips (e.g. "ff00dd")
	
	OverlayTips.RegisterTipShowWidget(tipShowWidget)										-- Show the overlay's 'Hide' button ([?]) over top of [tipShowWidget]
	
	visible = OverlayTips.Visible()															-- Returns true or false depending on whether or not tips are being shown
	
	OverlayTips.ToggleShow()																-- Shows tips if they're being hidden. Hides them if they're being shown
	
	OverlayTips.ShowTips()																	-- Shows all tips plus overlay and tips button
	
	OverlayTips.HideTips()																	-- Hides all tips plus overlay and tips button
	
	OverlayTips.Finalize()																	-- Destroys created tips and forgets everything you ever told it

--]]


if OverlayTips then
	return nil;
end
OverlayTips = {};


g_visible = false;
local PRIVATE = {};

local DEFAULT_DEFAULT_FONT = "Bold_10";
local DEFAULT_DEFAULT_COLOR = "dddd00";

local registeredWidgets = {}
local tipWidgets = {}
local screenWidget = nil;
local registeredTipsButtonWidget = nil;
local toggleTipsButton = nil;
local defaultFont = DEFAULT_DEFAULT_FONT;
local defaultColor = DEFAULT_DEFAULT_COLOR;

local ELEMENTS = {};

local KING_OF_PANELS_DEPTH = -120; -- or whatever it takes to be king these days









-- for adding all of the widgets we need to track on the overlay, along with their required localized text key and font info?
function OverlayTips.RegisterByWidget(widget, tipStringKey, trackingFrame, font, textColor)


























end

function OverlayTips.RegisterByDims(widget, tipStringKey, dims, font, textColor)

























end


function OverlayTips.SetDefaultFont(fontStr)



end

function OverlayTips.SetDefaultTipColor(tintStr)



end

function OverlayTips.RegisterTipShowWidget(tipShowWidget)



end

function OverlayTips.Visible()



end

function OverlayTips.ToggleShow()







end

function OverlayTips.ShowTips()















end

function OverlayTips.HideTips()





end

function OverlayTips.Finalize()






end



























































































































