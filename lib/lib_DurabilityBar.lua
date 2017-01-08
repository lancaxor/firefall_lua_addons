
--
-- lib_DurabilityBar
--  by: James Harless
--
-- Creates dual bars used to display item durability for user legability

--[[


--]]


if DurabilityBar then
	return nil
end
DurabilityBar = {}

require "math"
require "unicode"
require "lib/lib_Math"
require "lib/lib_Colors"
require "lib/lib_Items"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------
local PRIVATE = {}

local DUALBAR_API = {};
local DUALBAR_API_METATABLE = {
	__index = function(t,key) return DUALBAR_API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in DurabilityBar"); end
}

local SINGLEBAR_API = {};
local SINGLEBAR_API_METATABLE = {
	__index = function(t,key) return SINGLEBAR_API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in Singular Bar"); end
}

local MOVE_DURATION 	= 0.3

local TINT_BOARDER		= "#8E8E8E"
local TINT_DURABILITY 	= "#47CAFF"

local DURABILITY_MAX 	= 1000

local BP_DUALBAR = 
	[[<Group dimensions="left:0; right:100%; top:0; height:100%">
		<Border dimensions="dock:fill" class="ButtonBorder" style="padding:3; tint:]]..TINT_BOARDER..[["/>
		<Group name="bar_thick" dimensions="left:2; right:100%-2; top:2; bottom:100%-2;"> 
			<Group name="bars" dimensions="left:0; top:0; width:100%; height:100%;" >
				<Group name="main" dimensions="left:0%; top:0; right:0%; height:100%;" >
					<StillArt name="art" dimensions="dock:fill" style="texture:Repair; region:bar; hotpoint:0.5; exposure:0.4; alpha:1; xwrap:5; xwrap:17"/>
					<Group name="edge" dimensions="left:0; top:0; width:100%; height:100%" style="clip-children:true">
						<StillArt name="gradient" dimensions="right:100%; top:0; height:100%; width:79" style="texture:Repair; region:gradient; hotpoint:0.6; exposure:0.2; alpha:1"/>
					</Group>
				</Group>
				<Group name="shadow" dimensions="left:0%; top:0; right:0%; height:100%;" >
					<StillArt name="art" dimensions="dock:fill" style="texture:colors; region:white; alpha:0.4;"/>
				</Group>
			</Group>
		</Group>
		<Text name="label" key="{0}" dimensions="left:2; right:100%-2; top:2; height:17;" style="font:UbuntuMedium_9; halign:left; valign:center;" />
	</Group>]]

-- ------------------------------------------
-- DURABILITY BAR
-- ------------------------------------------
function DurabilityBar.Create(parent)
	local GROUP = Component.CreateWidget(BP_DUALBAR, parent)
	local DUALBAR = {
		GROUP = GROUP,
		LABEL = GROUP:GetChild("label"),
		
		DURABILITY = PRIVATE.SetupBarGroup(GROUP:GetChild("bar_thick")),
		
		-- Item Info
		itemName = "Unknown Item",
		itemColor = "#FFFFFF",
	}
	
	setmetatable(DUALBAR, DUALBAR_API_METATABLE)
	
	DUALBAR.DURABILITY:SetTint(TINT_DURABILITY)
	
	return DUALBAR
end

-- ------------------------------------------
-- DUALBAR_API
-- ------------------------------------------
function DUALBAR_API.SetDurability(DUALBAR, current, shadow)
	local pct = current / DURABILITY_MAX
	local shadow_pct = pct
	if shadow and current < shadow then
		shadow_pct = shadow / DURABILITY_MAX
	end
	DUALBAR.DURABILITY:PercentTo(pct, shadow_pct)
	DUALBAR.LABEL:SetText(_math.MakeReadable(current))
end

function DUALBAR_API.SetPool(DUALBAR, current, shadow)

end

function DUALBAR_API.Destroy(DUALBAR)
	Component.RemoveWidget(DUALBAR.GROUP)
	DUALBAR = nil
end

function DUALBAR_API.EnableTooltip(DUALBAR, state)
	
end

function DUALBAR_API.SetItemName(DUALBAR, name)
	DUALBAR.itemName = name
end

function DUALBAR_API.SetItemColor(DUALBAR, color)
	DUALBAR.itemColor = color
end

-- ------------------------------------------
-- SINGLEBAR_API
-- ------------------------------------------
function SINGLEBAR_API.SetTint(BAR, tint)
	local hsv_grad = Colors.toHSV(tint)
	hsv_grad.v = 1
	
	local hsv_shad = Colors.toHSV(tint)
	hsv_shad.v = 1	
	
	BAR.MAIN_ART:SetParam("tint", tint)
	--BAR.LINES:SetParam("tint", tint)
	BAR.GRADIENT:SetParam("tint", Colors.Create(hsv_grad))
	BAR.SHADOW_ART:SetParam("tint",  tint)
end

function SINGLEBAR_API.SetPercent(BAR, pct, shadow_pct)
	local percent = pct*100
	local shadow_percent = percent
	if shadow_pct then
		shadow_percent = shadow_pct * 100
	end
	
	BAR.MAIN:SetDims("left:0; top:_; right:"..percent.."%")
	BAR.SHADOW:SetDims("left:"..percent.."; top:_; right:"..shadow_percent.."%")
end

function SINGLEBAR_API.PercentTo(BAR, pct, shadow_pct)
	local percent = pct*100
	local shadow_percent = percent
	if shadow_pct then
		shadow_percent = shadow_pct * 100
	end
	
	BAR.MAIN:MoveTo("left:_; top:_; right:"..percent.."%", MOVE_DURATION, "smooth")
	BAR.SHADOW:MoveTo("left:"..percent.."%; top:_; right:"..shadow_percent.."%", MOVE_DURATION, "smooth")
end

-- ------------------------------------------
-- PRIVATE
-- ------------------------------------------
function PRIVATE.SetupBarGroup(GROUP)
	local SINGLEBAR = {
		GROUP = GROUP,
		MAIN = GROUP:GetChild("bars.main"),
		MAIN_ART = GROUP:GetChild("bars.main.art"),
		GRADIENT = GROUP:GetChild("bars.main.edge.gradient"),
		SHADOW = GROUP:GetChild("bars.shadow"),
		SHADOW_ART = GROUP:GetChild("bars.shadow.art"),
		
		-- Variables
		current = 0,
		pool = 100,
	}
	setmetatable(SINGLEBAR, SINGLEBAR_API_METATABLE)
	
	return SINGLEBAR
end
