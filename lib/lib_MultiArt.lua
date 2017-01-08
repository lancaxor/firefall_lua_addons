
--
-- lib_MultiArt
--   by: John Su
--
--	a flexible widget capable of acting as a StillArt, Icon, WebIcon, Shadow, or even Text widget

--[[ INTERFACE
	MULTIART = MultiArt.Create(parent)
	MULTIART:Destroy();
	
	MULTIART implements the folllowing generic methods:
		- GetDims
		- SetDims
		- MoveTo
		- QueueMove
		- FinishMove
		- GetParams
		- SetParams
		- ParamTo
		- QueueParam
		- RepeatParams
		- FinishParam
		- CycleParam
		- Show
		- Hide
		- IsVisible
		- GetBounds
		- IsMouseEater
		- EatMice
		- GetGroup()		-- returns an instance of the base Group widget
		- Reset()			-- completely clears itself
		- Foster(WIDGET)	-- fosters a widget to itself
	
	MULTIART also implements the following Widget specific methods:
	(Note: Calling any methods below will switch the MULTIART's mode, clearing any settings specific to that widget )
	
	StillArt:
		- SetTexture
		- GetTexture
		- SetRegion
		- GetRegion
	
	Icon:
		- SetIcon
		- GetIcon
		- ClearIcon
		
	WebImage:
		- SetUrl
		- GetUrl
		- ClearUrl
		
	Shadow:
		- SetTarget
	
	Text:
		- GetText
		- SetText
		- SetTextKey
		- SetKerningMult
		- SetLeadingMult
		- GetNumLines
		- GetLineHeight
		- GetTextDims
		- SetAlignment
		- GetAlignment
		- SetFont
		- SetUnderline
		- SetTextColor
--]]

MultiArt = {};

require "unicode"
require "table"

-- constants
local WIDGETS = {
	Group	= {
		key = "GROUP",
		methods={
			"GetDims",
			"SetDims",
			"MoveTo",
			"QueueMove",
			"FinishMove",
			"Show",
			"Hide",
			"IsVisible",
			"GetBounds",
			"IsMouseEater",
			"EatMice",
			"GetPath",
		},
	},
	
	StillArt	= {
		key = "STILLART",
		methods={
			"SetTexture",
			"GetTexture",
			"SetRegion",
			"GetRegion",
		},
	},
	
	Icon	= {
		key = "ICON",
		methods={
			"SetIcon",
			"GetIcon",
			"ClearIcon",
			"GetOriginalBounds"
		},
	},
	
	WebImage	= {
		key = "WEBIMAGE",
		methods={
			"SetUrl",
			"GetUrl",
			"ClearUrl",
		},
		style='fixed-bounds:true',
	},
	
	Shadow	= {
		key = "SHADOW",
		methods={
			"SetTarget",
		},
	},
	
	Text = {
		key = "TEXT",
		methods={
			"GetText",
			"SetText",
			"SetTextKey",
			"SetKerningMult",
			"SetLeadingMult",
			"GetNumLines",
			"GetLineHeight",
			"GetTextDims",
			"SetAlignment",
			"GetAlignment",
			"SetFont",
			"SetUnderline",
			"SetTextColor",
		},
	},
	
}

local PARAM_GROUP = 0;
local PARAM_WIDGET = 1;

local PARAMS = {
	saturation	= PARAM_WIDGET,
	exposure	= PARAM_WIDGET,
	shadow		= PARAM_WIDGET,
	hotpoint	= PARAM_WIDGET,
	tint		= PARAM_WIDGET,
	glow		= PARAM_WIDGET,
	alpha		= PARAM_GROUP,
	scalex		= PARAM_GROUP,
	scaley		= PARAM_GROUP,
};

local PARAM_METHODS = {
	"GetParam",
	"SetParam",
	"ParamTo",
	"QueueParam",
	"RepeatParams",
	"FinishParam",
	"CycleParam",
	"EatMice"
}

-- interface
local MULTIART_API = {};

local g_counter = 0;
local SetType;	-- function declaration below

function MultiArt.Create(parent)
	g_counter = g_counter+1;
	local MULTIART = {GROUP=Component.CreateWidget('<Group dimensions="dock:fill" name="MA'..(g_counter)..'"/>', parent),
					WIDGET=nil,
					type=nil,
					params={}};
	
	-- Grab all the widget methods
	for widget_type, widget in pairs(WIDGETS) do
		for m,method_name in pairs(widget.methods) do
			MULTIART[method_name] = function(...)
                local arg = {...}
				arg[1] = MULTIART[widget.key];
				if (not arg[1]) then
					SetType(MULTIART, widget_type);
					arg[1] = MULTIART[widget.key];
				end
				return arg[1][method_name](unpack(arg));
			end
		end
	end
	
	-- parameter methods
	for k, method_name in pairs(PARAM_METHODS) do
		MULTIART[method_name] = function(...)
            local arg = {...}
			local param_name = arg[2];
			if (PARAMS[unicode.lower(tostring(param_name))] == PARAM_GROUP) then
				arg[1] = MULTIART.GROUP;
			elseif (MULTIART.type) then
				arg[1] = MULTIART[WIDGETS[MULTIART.type].key];
			else
				--cache for later and abort
				if (arg[3]) then
					MULTIART.params[param_name] = arg[3];
				end
				return nil;
			end
			return arg[1][method_name](unpack(arg));
		end
	end
	
	-- MultiArt methods
	for k,v in pairs(MULTIART_API) do
		MULTIART[k] = v;
	end
	
	return MULTIART;
end


SetType = function(MULTIART, widget_type)
	-- Note: should never call with widget_type="Group"
	if (MULTIART.type ~= widget_type) then
		if (MULTIART.type) then
			local key = WIDGETS[MULTIART.type].key;
			local WIDGET = MULTIART[key]
			
			-- finish up and save params
			for p_name, p_type in pairs(PARAMS) do
				if (p_type == PARAM_WIDGET) then
					WIDGET:FinishParam(p_name);
					MULTIART.params[p_name] = WIDGET:GetParam(p_name);
				end
			end
			
			-- clean up previous widget
			Component.RemoveWidget(WIDGET);
			MULTIART[key] = nil;
		end
		MULTIART.type = widget_type;
		if widget_type then
			local key = WIDGETS[widget_type].key;
			local style = WIDGETS[widget_type].style;
			if (style) then
				MULTIART[key] = Component.CreateWidget("<"..widget_type..' dimensions="dock:fill\" style="'..style..'"/>', MULTIART.GROUP);
			else
				MULTIART[key] = Component.CreateWidget("<"..widget_type..' dimensions="dock:fill\"/>', MULTIART.GROUP);
			end
			
			-- restore saved params
			for p_name, val in pairs(MULTIART.params) do
				MULTIART[key]:SetParam(p_name, val);
			end
		end
	end
end

function MULTIART_API:GetGroup()
	return self.GROUP;
end

function MULTIART_API:Reset()
	SetType(self, nil);
	self.params = {};
end

function MULTIART_API:Destroy()
	SetType(self, nil);
	Component.RemoveWidget(self.GROUP);
	for k,v in pairs(self) do
		self[k] = nil;
	end
end

function MULTIART_API:Foster(WIDGET)
	Component.FosterWidget(WIDGET, self.GROUP);
end
