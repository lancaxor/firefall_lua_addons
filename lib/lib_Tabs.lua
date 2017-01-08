
--
-- lib_Tabs
--	by: James Harless
--
--	Fast tabs, anywhere!

--[[
	TABS = Tabs.Create(...)							-- Creates predefined number of tabs within a panel, with an option to skip tab bodies.
														- Accepts Widget, number, and bool in any order

	TABS:SetTab(params)								-- Adjusts text, id and icons for a tab
	
	TABS:Select(number)								-- Selects a tab by index					
	TABS:SelectById(string or number)				-- Selects a tab by id
	
	TABS:GetBody(number)							-- returns tab lower group widget by index
	TABS:GetBodyById(string or number)				-- returns tab lower group widget by id

	TABS:Highlight(bool)							--shows/hides the highlight

	
	TABS also dispatches the following events:
		"OnTabChanged"

--]]

if Tabs then
	return nil
end
Tabs = {}

require "table"
require "lib/lib_MultiArt"
require "lib/lib_EventDispatcher";

local lf = {}

local API = {};
local TABOBJECT_METATABLE = {
	__index = function(t,key) return API[key] end,
	__newindex = function(t,k,v) error("Cannot write to value '"..k.."' in TABS"); end
}

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

Tabs.Bar_Height = 45

local HEIGHT_TAB = Tabs.Bar_Height
local ICON_HEIGHT = HEIGHT_TAB * 0.6	-- 60% of bar height

local TAB_NONE = 0
local TAB_LEFT = 1
local TAB_RIGHT = 2
local TAB_CENTER = 3

local c_TabFormat = {
	[TAB_LEFT] = {
		fill = false,
		alignment = {
			"left:1; top:1; height:5; width:5;",
			"left:6; top:1; height:5; right:100%-1;",
			"left:1; top:6; bottom:100%-6; width:5;",
			"left:1; right:100%-1; bottom:100%-1; height:5;",
			"left:6; right:100%-1; top:6; bottom:100%-6;",
		},
		outline = {
			left = true,
			right = true,
		},
		textures = {
			{ "PanelParts", "Circle_TL" },
		},
	},
	
	[TAB_RIGHT] = {
		fill = false,
		alignment = {
			"right:100%-1; top:1; height:5; width:5;",
			"left:1; right:100%-6; top:1; height:5;",
			"left:1; top:6; bottom:100%-6; width:5;",
			"left:1; right:100%-1; bottom:100%-1; height:5;",
			"left:6; right:100%-1; top:6; bottom:100%-6;",
		},
		outline = {
			left = true,
			right = true,
		},
		textures = {
			{ "PanelParts", "Circle_TR" },
		},
	},
	
	[TAB_CENTER] = {
		fill = true,
		alignment = {},
		outline = {
			left = true,
			right = true,
		},
		textures = {},
	},
}

local COLOR_TAB_DEFAULT = "#FFFFFF"
local COLOR_TAB_SELECTED = Component.LookupColor("ui")
local COLOR_TAB_DISABLED = "#555555"

local BP_GROUP_FULL = 
	[[<Group dimensions="dock:fill">
		<Group name="tabs" dimensions="left:0; top:0; height:]]..HEIGHT_TAB..[[; width:100%" />
		<Group name="panel" dimensions="left:0; top:]]..HEIGHT_TAB..[[; bottom:100%; width:100%" />
	</Group>]]

local BP_GROUP_TABS = 
	[[<Group dimensions="left:0; top:0; height:]]..HEIGHT_TAB..[[; width:100%">
		<Group name="tabs" dimensions="dock:fill" />
	</Group>]]

local BP_TAB = 
	[[<Group dimensions="dock:fill" style="clip-children:true">
		<Group name="background" dimensions="dock:fill" >
			<StillArt name="fill" dimensions="left:1; right:100%-1; top:1; bottom:100%-1" style="texture:colors; region:white; tint:#000000"/>
			<StillArt name="1" dimensions="left:1; top:1; height:5; width:5;" style="texture:PanelParts; region:Circle_TL; tint:#000000"/>
			<StillArt name="2" dimensions="left:6; top:1; height:5; right:100%-1;" style="texture:colors; region:white; tint:#000000"/>
			<StillArt name="3" dimensions="left:1; top:6; bottom:100%-6; width:5;" style="texture:colors; region:white; tint:#000000"/>
			<StillArt name="4" dimensions="left:1; right:100%-1; bottom:100%-1; height:5;" style="texture:colors; region:white; tint:#000000"/>
			<StillArt name="5" dimensions="left:6; right:100%-1; top:6; bottom:100%-6;" style="texture:colors; region:white; tint:#000000"/>
		</Group>
		<Group name="outline" dimensions="dock:fill" style="alpha:0.15" >
			<StillArt name="top" dimensions="left:0; right:100%; top:0; height:1;" style="texture:colors; region:white"/>
			<StillArt name="left" dimensions="left:0; top:0; height:100%-1; width:1;" style="texture:colors; region:white"/>
			<StillArt name="right" dimensions="right:100%; top:0; height:100%-1; width:1;" style="texture:colors; region:white"/>
			<StillArt name="bottom" dimensions="left:0; right:100%; bottom:100%; height:1;" style="texture:colors; region:white"/>
		</Group>
		<StillArt name="glow" dimensions="left:-15.5%; width:120%; top:1; height:100" style="texture:GarageParts; region:topBattleFrameNameGlow; alpha:0"/>
		<ListLayout name="title" dimensions="center-x:50%; top:0; height:100%; width:100%;" style="horizontal:true; hpadding:3" >
			<Group name="icon" dimensions="left:0; top:0; height:100%; width:]]..HEIGHT_TAB..[[;" style="eatsmice:false; visible:false" />
			<Text name="label" dimensions="left:0; top:0; height:100%; width:100%;" style="font:Demi_11; padding:4; halign:center; valign:center; color:]]..COLOR_TAB_DEFAULT..[["/>
		</ListLayout>
		<StillArt name="highlightBG" dimensions="left:0; top:0; right:100%; bottom:100%;" style="texture:HighlightBGBlue; alpha:0;"/>
		<FlipBook name="sweep_flipbook" style="texture:SweepBlue; visible:false;" dimensions="left:0; center-y:50%; height:100%-6; width:100%;" fps="30" frameWidth="174"/>
		<FocusBox name="button" dimensions="dock:fill" class="ui_button" />
	</Group>]]


local SOUND_ONCHANGE = "Play_UI_Beep_45"

-- ------------------------------------------
-- TABS
-- ------------------------------------------

function Tabs.Create(...)
    local nArgs = select('#', ...)
    local arg = {...}
	assert(nArgs > 1, "Too few params!")
	assert(nArgs <= 3, "Too many params!")
	local count = 0
	local has_body = true
	local PARENT
	for i=1, nArgs do
		local param = arg[i]
		if type(param) == "number" then
			count = param
		elseif type(param) == "boolean" then
			has_body = param
		else
			PARENT = param
		end
	end
	assert(type(count) == "number" and count > 1, "Tab Count must be a number and greater than 1.")
	assert(PARENT, "Tabs must have a parent widget!")
	
	local GROUP
	if has_body then
		GROUP = Component.CreateWidget(BP_GROUP_FULL, PARENT)
	else
		GROUP = Component.CreateWidget(BP_GROUP_TABS, PARENT)
	end
	local TABOBJECT = {
		GROUP = GROUP,
		TAB_CONTAINER = GROUP:GetChild("tabs"),
		PANEL_CONTAINER = GROUP:GetChild("panel"),
		
		TABS = {},		-- Tab Widgets
		PANELS = {},	-- Panel Widgets
		
		id_lookup = {},	-- Tab ID lookup
		tab_count = count,	
		selected_tab = false,
		has_panels = has_body,
	}
	
	TABOBJECT.DISPATCHER = EventDispatcher.Create(TABOBJECT)
	TABOBJECT.DISPATCHER:Delegate(TABOBJECT)
	
	setmetatable(TABOBJECT, TABOBJECT_METATABLE)
	
	-- Generate Tabs
	for i=1, count do
		lf.CreateTab(TABOBJECT)
	end
	lf.RefreshTabAlignment(TABOBJECT)
	
	return TABOBJECT
end



-- ------------------------------------------
-- API
-- ------------------------------------------
-- forward the following methods to the GROUP widget
local COMMON_METHODS = {
	"GetParam", "SetParam", "ParamTo", "CycleParam", "QueueParam", "FinishParam",
	"Show", "Hide", "IsVisible", "GetBounds", "SetTag", "GetTag"
};
for _, method_name in pairs(COMMON_METHODS) do
	API[method_name] = function(TABPANEL, ...)
		return TABPANEL.GROUP[method_name](TABPANEL.GROUP, ...);
	end
end

function API.SetTab(TABPANEL, index, params)
	local TAB = TABPANEL.TABS[index]
	assert(TAB, "Tab "..index.." does not exist!")
	assert(type(params) == "table", "Params must be a table!")
	
	lf.SetId(TABPANEL, TAB, params)
	lf.SetText(TAB, params)
	lf.SetIcon(TAB, params)
	lf.SetTint(TAB, params)
	lf.AlignLabel(TAB)
end

function API.UpdateLabel(TABPANEL, params)
	assert(type(params) == "table", "Params must be a table!")
	local TAB = lf.GetTab(TABPANEL, params)
	assert(TAB, "need to supply an id or index for tab referencing in the params table")
	lf.SetText(TAB, params)
	lf.AlignLabel(TAB)
end

function API.EnableTab(TABPANEL, index, enabled)
	TABPANEL.TABS[index].enabled = enabled
	TABPANEL.TABS[index].BUTTON:Show(enabled)
	TABPANEL.TABS[index].LABEL:SetTextColor(TABPANEL.TABS[index].enabled and COLOR_TAB_DEFAULT or COLOR_TAB_DISABLED)
end








function API.Select(TABPANEL, index)
	if TABPANEL.TABS[index] then
		lf.TabSelect(TABPANEL, index, true)
	else
		warn("Tab "..tostring(index).." does not exist!")
	end
end

function API.SelectById(TABPANEL, id)
	local index = TABPANEL.id_lookup[id]
	TABPANEL:Select(index)
end

function API.DeselectTab(TABPANEL)
	if TABPANEL.selected_tab then
		lf.TabSelect(TABPANEL, TABPANEL.selected_tab, false)
	end
end

function API.GetBody(TABPANEL, index)
	assert(TABPANEL.has_panels, "Tabs does not have Body enabled!")
	if TABPANEL.PANELS[index] then
		return TABPANEL.PANELS[index]
	else
		warn("Tab "..tostring(index).." does not exist!")
	end
end

function API.GetBodyById(TABPANEL, index)
	local index = TABPANEL.id_lookup[id]
	if index then
		return TABPANEL:GetBody(index)
	end
end

function API.GetSelected(TABPANEL)
	local index = TABPANEL.selected_tab
	if index then
		return index, TABPANEL.id_lookup[index]
	end
end

function API.Highlight(TABPANEL, index, show)
	if show == nil then
		show = true
	end
	local TAB = TABPANEL.TABS[index]

	if show == true then
		--Repeatedly play the sweep animation behind the tab to draw attention to it
		if cb_sweepFX == nil then
			cb_sweepFX = Callback2.CreateCycle(function() lf.PlaySweepAnim(TAB.SWEEP_ANIM) end)
		else
			cb_sweepFX:Stop()
		end
		cb_sweepFX:Run(2)

		--fade in the background
		TAB.HIGHLIGHT:SetParam("alpha", 0)
		TAB.HIGHLIGHT:ParamTo("alpha", 1, 0.2)
	else
		if cb_sweepFX ~= nil then
			cb_sweepFX:Stop()
		end
		TAB.SWEEP_ANIM:ParamTo("alpha", 0, 0.2)

		--fade out the background
		TAB.HIGHLIGHT:ParamTo("alpha", 0, 0.2)
	end
end
-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------

function lf.PlaySweepAnim(SWEEP_ANIM)
	SWEEP_ANIM:Show()
	SWEEP_ANIM:SetParam("alpha", 1)
	SWEEP_ANIM:Play(1.0, 1, true, true)
end

function lf.CreateTab(TABPANEL)	
	local index = #TABPANEL.TABS+1
	
	local GROUP = Component.CreateWidget(BP_TAB, TABPANEL.TAB_CONTAINER)
	local TAB = {
		GROUP = GROUP,
		BUTTON = GROUP:GetChild("button"),
		GLOW = GROUP:GetChild("glow"),
		TITLE = GROUP:GetChild("title"),
		LABEL = GROUP:GetChild("title.label"),
		ICON_GROUP = GROUP:GetChild("title.icon"),
		ICON = MultiArt.Create(GROUP:GetChild("title.icon")),
		HIGHLIGHT = GROUP:GetChild("highlightBG"),
		SWEEP_ANIM = GROUP:GetChild("sweep_flipbook"),
		
		BACKGROUND = {
			GROUP = GROUP:GetChild("background"),
			FILL = GROUP:GetChild("background.fill"),
			-- 1 - 5 populated below
		},
		OUTLINE = {
			GROUP = GROUP:GetChild("outline"),
			LEFT = GROUP:GetChild("outline.left"),
			RIGHT = GROUP:GetChild("outline.right"),
			BOTTOM = GROUP:GetChild("outline.right"),
		},
		PANEL = false,

		-- Variables
		index = index,
		id = index,
		selected = false,
		enabled = true,
		has_icon = false,
		tint = false,

		alignment = TAB_NONE,
	}

	for i=1, 5 do
		TAB.BACKGROUND[i] = GROUP:GetChild("background."..i)
	end
	
	TAB.ICON:SetDims("left:0; center-y:50%; height:80%; aspect:1;")
	
	TAB.BUTTON:BindEvent("OnMouseEnter", function(args)
	
	end)
	TAB.BUTTON:BindEvent("OnMouseLeave", function(args)
	
	end)
	TAB.BUTTON:BindEvent("OnMouseDown", function(args)
	
	end)
	TAB.BUTTON:BindEvent("OnMouseUp", function(args)
		lf.OnMouseUp(TABPANEL, TAB)
	end)
	
	lf.SetText(TAB, {label="Tab "..index})
	
	table.insert(TABPANEL.TABS, TAB)
	
	-- Create panel
	if TABPANEL.has_panels then
		local PANEL = Component.CreateWidget([[<Group dimensions="dock:fill" />]], TABPANEL.PANEL_CONTAINER)
		TABPANEL.PANELS[index] = PANEL
		PANEL:SetParam("alpha", 0)
		PANEL:Show(false)
		
		-- Give panel a reference in TAB
		TAB.PANEL = PANEL
	end
	
	lf.TabSelect(TABPANEL, index, false)

	return TAB
end

function lf.RefreshTabAlignment(TABPANEL)
	local width = 1 / TABPANEL.tab_count
	for index,TAB in ipairs(TABPANEL.TABS) do
		local tab_alignment
		if index == 1 then
			-- align Left
			tab_alignment = TAB_LEFT
		elseif TABPANEL.tab_count == index then
			-- align Right
			tab_alignment = TAB_RIGHT
		else
			-- align Center
			tab_alignment = TAB_CENTER
		end
		
		-- Only refresh tab art that have incorrect alignment or no alignment
		if TAB.alignment ~= tab_alignment then
			local tab_format = c_TabFormat[tab_alignment]
			TAB.BACKGROUND.FILL:Show(tab_format.fill)
			for i=1, #tab_format.alignment do
				TAB.BACKGROUND[i]:SetDims(tab_format.alignment[i])
			end
			for i=1, #tab_format.textures do
				TAB.BACKGROUND[i]:SetTexture(unpack(tab_format.textures[i]))
			end
			TAB.OUTLINE.LEFT:Show(tab_format.outline.left)
			TAB.OUTLINE.RIGHT:Show(tab_format.outline.right)
		end
		
		-- Refresh dims
		local dims = {
			"left:".. ((index-1) * width) * 100 .. "%",
			"right:".. (index * width) * 100 .. "%",
			"top:0",
			"height:100%",
		}

		TAB.GROUP:SetDims(table.concat(dims, ";"))	
	end
end

function lf.SetId(TABPANEL, TAB, params)
	if params.id then
		if TABPANEL.id_lookup[TAB.id] then
			TABPANEL.id_lookup[TAB.id] = nil
		end
		TAB.id = params.id
		TABPANEL.id_lookup[params.id] = TAB.index
	end
end

function lf.SetText(TAB, params)
	local text
	if params.label_key then
		text = Component.LookupText(params.label_key)
	elseif params.label then
		text = params.label
	end
	if text then
		TAB.LABEL:SetText(text)
	end
end

function lf.SetIcon(TAB, params)
	if params.no_tint_icon ~= nil then
		TAB.no_tint_icon = params.no_tint_icon
	end
	if params.url or params.texture then
		if params.url then
			TAB.has_icon = true
			TAB.ICON:SetUrl(icon.url)
		elseif params.texture then
			-- Cuts down an if statement
			local texture = {params.texture, params.region}
			local texture_dims = Component.GetTextureInfo(unpack(texture))
			if texture_dims then
				TAB.has_icon = true
				if texture_dims.height > ICON_HEIGHT then
					-- scale image bounds down
					local scale = ICON_HEIGHT / texture_dims.height
					texture_dims.height = texture_dims.height * scale
					texture_dims.width = texture_dims.width * scale
				end
				local dims = {
					"center-x:_",
					"center-y:_",
					"height:"..texture_dims.height,
					"width:"..texture_dims.width,
				}
				TAB.ICON:SetDims(table.concat(dims, ";"))
				TAB.ICON_GROUP:SetDims("left:_; top:_; height:_; width:"..texture_dims.width)
				TAB.ICON:SetTexture(unpack(texture))
			else
				TAB.has_icon = false
				warn("Tab "..TAB.index.." has an invalid icon: "..tostring(texture))
			end
		end
	else
		TAB.has_icon = false
	end
	TAB.ICON_GROUP:Show(TAB.has_icon)
end

function lf.SetTint(TAB, params)
	if params.tint then
		TAB.tint = params.tint
	else
		TAB.tint = false
	end
	local glow_tint = TAB.tint or "#FFFFFF"
	local saturation = 1
	local hotpoint = 1
	if TAB.tint then
		saturation = 0
		hotpoint = 0.5
	end
	TAB.GLOW:SetParam("saturation", saturation)
	TAB.GLOW:SetParam("hotpoint", hotpoint)
	TAB.GLOW:SetParam("tint", glow_tint)
	if TAB.selected then
		local label_tint = TAB.tint or COLOR_TAB_SELECTED
		TAB.LABEL:SetTextColor(TAB.enabled and label_tint or "#555555")
		if not TAB.no_tint_icon then
			TAB.ICON:SetParam("tint", label_tint)
		end
	elseif not TAB.enabled then
		TAB.LABEL:SetTextColor("#555555")
	end
end

function lf.AlignLabel(TAB)
	if TAB.has_icon then
		local text_width = TAB.LABEL:GetTextDims().width
		TAB.LABEL:SetAlignment("halign", "left")
		TAB.LABEL:SetDims("left:_; top:_; height:_; width:"..text_width)
		TAB.TITLE:SetDims("center-x:_; top:_; height:_; width:"..text_width + 44)
	else
		TAB.LABEL:SetAlignment("halign", "center")
		TAB.LABEL:SetDims("dock:fill")
		TAB.TITLE:SetDims("dock:fill")
	end

end

function lf.GetLabelColor(TAB)
	return TAB.tint or COLOR_TAB_SELECTED
end

function lf.TabSelect(TABPANEL, index, state)
	local TAB = TABPANEL.TABS[index]
	if TAB.selected ~= state then
		-- Deselect previous Tab
		local prev_tab = TABPANEL.selected_tab
		if prev_tab ~= TAB.index then
			if prev_tab then
				lf.TabSelect(TABPANEL, prev_tab, false)
			end
		end
		
		TAB.selected = state
		if state then
			local selected_color = lf.GetLabelColor(TAB)
			TAB.BACKGROUND.GROUP:ParamTo("alpha", 0, 0.125)
			TAB.OUTLINE.GROUP:ParamTo("alpha", 0, 0.125)
			TAB.GLOW:ParamTo("alpha", 1, 0.15, 0.125)
			TAB.GLOW:ParamTo("exposure", 0.25, 0.25, 0.125)
			TAB.LABEL:SetTextColor(selected_color)
			if not TAB.no_tint_icon then
				TAB.ICON:SetParam("tint", selected_color)
			end
			
			TABPANEL.selected_tab = index
			TABPANEL:DispatchEvent("OnTabChanged", {index=TAB.index, id=TAB.id})
			lf.PanelShow(TAB, true)
		else
			TAB.BACKGROUND.GROUP:ParamTo("alpha", 1, 0.125, 0.125)
			TAB.OUTLINE.GROUP:ParamTo("alpha", 0.15, 0.125, 0.125)
			TAB.GLOW:ParamTo("alpha", 0, 0.125)
			TAB.GLOW:ParamTo("exposure", 0, 0.125)
			TAB.LABEL:SetTextColor(TAB.enabled and COLOR_TAB_DEFAULT or COLOR_TAB_DISABLED)
			if not TAB.no_tint_icon then
				TAB.ICON:SetParam("tint", COLOR_TAB_DEFAULT)
			end
			lf.PanelShow(TAB, false)
		end
	end
end

function lf.PanelShow(TAB, state)
	if TAB.PANEL then
		if state then
			TAB.PANEL:Show(true)
			TAB.PANEL:ParamTo("alpha", 1, 0.125, 0.125)
		else
			TAB.PANEL:Show(false, 0.125)
			TAB.PANEL:ParamTo("alpha", 0, 0.125)
		end
	end
end

function lf.OnMouseUp(TABPANEL, TAB)
	if not TAB.enabled then
		return nil
	end
	
	-- Select current tab
	lf.TabSelect(TABPANEL, TAB.index, true)
	System.PlaySound(SOUND_ONCHANGE)
end

function lf.GetTab(TABPANEL, params)
	local TAB
	if params.id then
		params.index = TABPANEL.id_lookup[params.id]
	end
	if params.index then
		return TABPANEL.TABS[params.index]
	end
end




