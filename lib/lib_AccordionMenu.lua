
-- ------------------------------------------
-- Accordion Menu
--   by: James Harless
-- ------------------------------------------

--[[ Usage:	
--]]


if AccordionMenu then
	return nil
end
AccordionMenu = {}

require "math"


-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local API = {}
local lf = {}

local ACCORDIONMENU_METATABLE = {
	__index = function(t,key) return API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in AccordionMenu"); end
};

AccordionMenu.ALIGN_TOP = "top"
AccordionMenu.ALIGN_BOTTOM = "bottom"

local STATE_CLOSED = false
local STATE_OPEN = true

local HEADER_HEIGHT = 19
local HEADER_SPACER = 5
local HEADER_BORDER = 10

local STRIPE_HEIGHT = 12
local STRIPE_OFFSET = math.floor((HEADER_HEIGHT - STRIPE_HEIGHT) /2)
local STRIPE_SPACER = 5

local ALIGN_TOP = "top:0"
local ALIGN_BOTTOM = "bottom:100%"

local BP_BODY = [[<Group dimensions="dock:fill">
	<Border dimensions="dock:fill" class="PanelBackDrop" />
	<Group name="strip" dimensions="left:0; top:0; width:100%; height:]]..HEADER_HEIGHT+(HEADER_SPACER*2)..[[;" >
		<Group name="header" dimensions="left:0; top:]]..HEADER_SPACER..[[; width:100%; height:]]..HEADER_HEIGHT..[[;" >
			<StillArt name="stripe_l" dimensions="top:]]..STRIPE_OFFSET..[[; left:]]..STRIPE_SPACER..[[; height:]]..STRIPE_HEIGHT..[[; width:50%;" style="texture:menu_stripe; alpha:0.7" />
			<StillArt name="stripe_r" dimensions="top:]]..STRIPE_OFFSET..[[; right:100%-]]..STRIPE_SPACER..[[; height:]]..STRIPE_HEIGHT..[[; width:50%;" style="texture:menu_stripe; alpha:0.7" />
			<Group name="title" dimensions="center-x:50%; top:0; height:100%; width:0" >
				<Border dimensions="dock:fill" class="PanelBackDrop" />
				<Text name="label" dimensions="dock:fill" style="font:Demi_10; halign:center; valign:center; wrap:false; eatsmice:false; alpha:0.7" />
			</Group>
		</Group>
		<FocusBox name="focus" dimensions="dock:fill" />
	</Group>
	<Group name="body" dimensions="dock:fill" style="clip-children:true" />
</Group>]]



function AccordionMenu.Create(PARENT, alignment)
	local GROUP = Component.CreateWidget(BP_BODY, PARENT)
	local STRIP = GROUP:GetChild("strip")
	local AM = {
		GROUP = GROUP,
		STRIP = STRIP,
		BODY = GROUP:GetChild("body"),
	
		STRIPE_LEFT = STRIP:GetChild("header.stripe_l"),
		STRIPE_RIGHT = STRIP:GetChild("header.stripe_r"),
		TITLE = STRIP:GetChild("header.title"),
		LABEL = STRIP:GetChild("header.title.label"),
		FOCUS = STRIP:GetChild("focus"),
		
		alignment = ALIGN_BOTTOM,
		expanded = true,
	}
	AM.FOCUS:BindEvent("OnMouseUp", function(args)
		lf.OnMouseUp(AM)
	end)
	
	setmetatable(AM, ACCORDIONMENU_METATABLE)

	AM:SetAlignment(alignment or AccordionMenu.ALIGN_BOTTOM)
	lf.SetBodyAlignment(AM, false, 0)
	
	return AM
end






-- ------------------------------------------
-- ACCORDION MENU API
-- ------------------------------------------
function API.Destroy(AM)
	Component.RemoveWidget(AM.GROUP)
	for k,v in pairs(AM) do
		AM[k] = nil
	end
end

function API.GetContents(AM)
	return AM.CONTENTS
end

function API.SetAlignment(AM, alignment)
	local new_alignment = ALIGN_BOTTOM
	if alignment then
		assert(type(alignment) == "string", "Alignment must be a string!")
		if alignment == "top" then
			new_alignment = ALIGN_TOP
		end
	else
		warn("Invalid Alignment: Must be 'top' or 'bottom'.")
	end
	
	AM.alignment = new_alignment
	
	local strip_align = ALIGN_BOTTOM
	if AM.alignment == ALIGN_BOTTOM then
		strip_align = ALIGN_TOP
	end
	
	-- Update Alignment for Menu
	AM.STRIP:SetDims("left:0; width:100%; "..strip_align.."; height:"..HEADER_HEIGHT+(HEADER_SPACER*2))
	AM.BODY:SetDims("left:5; height:100%-10; width:100%-5; "..AM.alignment)
end

function API.SetTextKey(AM, text_key)
	AM:SetText(Component.LookupText(text_key))
end

function API.SetText(AM, text)
	AM.LABEL:SetText(text)
	
	local label_width = AM.LABEL:GetTextDims().width + (HEADER_BORDER*2)
	local center_offset = (label_width/2)+HEADER_BORDER
	AM.TITLE:SetDims("center-x:50%; top:0; height:100%; width:"..label_width)
	AM.STRIPE_LEFT:SetDims("top:"..STRIPE_OFFSET.."; left:"..STRIPE_SPACER.."; height:"..STRIPE_HEIGHT.."; width:50%-"..center_offset)
	AM.STRIPE_RIGHT:SetDims("top:"..STRIPE_OFFSET.."; right:100%-"..STRIPE_SPACER.."; height:"..STRIPE_HEIGHT.."; width:50%-"..center_offset)
	
	lf.RefreshBodyHeight(AM, dur)
end

-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
function lf.SetBodyAlignment(AM, state, dur)
	if AM.expanded ~= state then
		AM.expanded = state
		lf.RefreshBodyHeight(AM, dur)
	end
end

function lf.RefreshBodyHeight(AM, dur)
	local height
	if AM.expanded then
		height = "100%"
	else
		height = HEADER_HEIGHT + 10
	end
	AM.GROUP:MoveTo("left:0; width:100%;"..AM.alignment..";height:"..height, dur or 0, "smooth")
end

function lf.OnMouseUp(AM)
	lf.SetBodyAlignment(AM, not AM.expanded, 0.2)
end
