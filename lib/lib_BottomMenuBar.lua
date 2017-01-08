
--
-- lib_BottomMenuBar
--   by: Brian Blose
--

-- deprecated lib

--[[USAGE
LIB_BMB_Init(table)
table = {
	[width] = <number> width of each option
	[iconmode] = <boolean> true if using icons instead of labels
	[dur] = <number> seconds to animate between options
	[centerY] = <string> center-y dim for the bar
	frame = <frame> frame that this is being attached to
	options = <array>
	options[i] = {
		[text] = <string> label of the option
		[key] = <string> key string of the label
		[init] = <function> function to run on the creation on the option
		[finalize] = <function> function to run on the deletion on the option
		select = <function> function to run when the option is seleceted/clicked
		[unselect] = <function> function to run when the option is unseleceted
	}
}
--]]

--WIDGETS
local BAR = nil

--CONSTANTS
local LABEL_WIDTH = 700
local label_width = 230
local icon width = 40
local default_dur = 0.3
local default_centerY = "90%"

--GLOBAL VARIABLES
LIB_BMB_ActiveScreen = nil

--LOCAL VARIABLES
local g_dur
local g_exitclicked = false

--EVENTS
function LIB_BMB_ExitOnClick(args)
	if not g_exitclicked then
		g_exitclicked = true
		BAR.EXIT.action()
	end
end

function LIB_BMB_OnClick(args)
	LIB_BMB_Select(tonumber(args.widget:GetTag()), g_dur)
end

function LIB_BMB_OnEnter(args)
	args.widget:GetParent():GetChild("text"):ParamTo("glow", "glow", 0.1)
end

function LIB_BMB_OnLeave(args)
	args.widget:GetParent():GetChild("text"):ParamTo("glow", "invis", 0.1)
end

--FUNCTIONS
function LIB_BMB_Init(args)
	if not args.width then
		if args.iconmode then
			args.width = icon_width
		else
			args.width = label_width
		end
	end
	if args.dur then
		g_dur = args.dur
	else
		g_dur = default_dur
	end
	if not args.centerY then args.centerY = default_centerY end
	local num = #args.options
	local dim
	BAR = {GROUP=Component.CreateWidget("<Group dimensions='bottom:100%; height:141; left:0%; right:100%'/>", args.frame)}
	BAR.ART = Component.CreateWidget("<Group dimensions='dock:fill'/>", BAR.GROUP)
	Component.CreateWidget("<StillArt dimensions='top:0; bottom:100%; left:50%-"..(LABEL_WIDTH/2).."; width:100' style='texture:BottomMenuBar; region:bg_left'/>", BAR.ART)
	Component.CreateWidget("<StillArt dimensions='top:0; bottom:100%; center-x:50%; width:"..(LABEL_WIDTH-200).."' style='texture:BottomMenuBar; region:bg_middle'/>", BAR.ART)
	Component.CreateWidget("<StillArt dimensions='top:0; bottom:100%; right:50%+"..(LABEL_WIDTH/2).."; width:100' style='texture:BottomMenuBar; region:bg_right'/>", BAR.ART)
	Component.CreateWidget("<StillArt dimensions='top:0; bottom:100%; left:0; right:50%-"..(LABEL_WIDTH/2).."' style='texture:BottomMenuBar; region:bg_caps'/>", BAR.ART)
	Component.CreateWidget("<StillArt dimensions='top:0; bottom:100%; right:100%; left:50%+"..(LABEL_WIDTH/2).."' style='texture:BottomMenuBar; region:bg_caps'/>", BAR.ART)
	BAR.HEADER = {GROUP=Component.CreateWidget("<Group dimensions='top:20; bottom:65; center-x:50%; width:"..LABEL_WIDTH.."'/>", BAR.GROUP)}
	BAR.HEADER.TITLE = Component.CreateWidget("<Text dimensions='dock:fill' style='font:Demi_17; halign:center; valign:top; wrap:false; clip:false; alpha:0.85'/>", BAR.HEADER.GROUP)
	BAR.HEADER.SUBTITLE = Component.CreateWidget("<Text dimensions='dock:fill' style='font:Demi_9; halign:center; valign:bottom; wrap:false; clip:false; alpha:0.5'/>", BAR.HEADER.GROUP)
	BAR.SLIDER = Component.CreateWidget("<StillArt dimensions='top:71; height:43; center-x:50%; width:187' style='texture:BottomMenuBar; region:slider;'/>", BAR.GROUP)
	BAR.OPTION_GROUP = Component.CreateWidget("<Group dimensions='left:0; right:100%; top:71; height:43;'/>", BAR.GROUP)
	BAR.OPTIONS = {}
	for i, option in ipairs(args.options) do
		BAR.OPTIONS[i] = option
		dim = (i - ((num / 2) + 0.5)) * args.width
		if dim < 0 then
			dim = tostring(dim)
		else
			dim = "+"..tostring(dim)
		end
		BAR.OPTIONS[i].dimOffset = dim
		BAR.OPTIONS[i].GROUP = Component.CreateWidget(
			[[<Group dimensions='center-x:50%]]..dim..[[; width:]]..args.width..[[; top:0; bottom:100%'>
				<Text name='text' dimensions='dock:fill' style='font:Demi_17; halign:center; valign:center; wrap:false; clip:false; alpha:0.5; glow:invis;'/>
				<FocusBox dimensions='dock:fill' tag=']]..i..[['>
					<Events>
						<OnMouseDown bind='LIB_BMB_OnClick'/>
						<OnMouseEnter bind='LIB_BMB_OnEnter'/>
						<OnMouseLeave bind='LIB_BMB_OnLeave'/>
						<OnScroll bind='LIB_BMB_Scroll'/>
					</Events>
				</FocusBox>
			</Group>]], BAR.OPTION_GROUP)
		BAR.OPTIONS[i].TEXT = BAR.OPTIONS[i].GROUP:GetChild("text")
		BAR.OPTIONS[i].TEXT:SetText(option.label)
		if option.finalize then
			option.finalize()
		end
		if option.init then
			option.init()
		end
	end
	if args.exit then
		BAR.EXIT = {}
		BAR.EXIT.GROUP = Component.CreateWidget(
			[[<Group dimensions='right:100%; width:500; bottom:96; height:71'>
				<StillArt dimensions='top:0; bottom:100%; left:0; width:50' style='texture:BottomMenuBar; region:button_left; eatsmice:false'/>
				<StillArt dimensions='top:0; bottom:100%; left:50; right:100%-50' style='texture:BottomMenuBar; region:button_middle; eatsmice:false'/>
				<StillArt dimensions='top:0; bottom:100%; right:100%; width:50' style='texture:BottomMenuBar; region:button_right; eatsmice:false'/>
				<Text name='text' dimensions='left:5; right:100%; top:0; height:50' style='font:Demi_18; halign:center; valign:center; wrap:false; clip:false; alpha:1; glow:invis;'/>
				<FocusBox dimensions='left:0; right:100%; top:0; height:45'>
					<Events>
						<OnMouseDown bind='LIB_BMB_ExitOnClick'/>
						<OnMouseEnter bind='LIB_BMB_OnEnter'/>
						<OnMouseLeave bind='LIB_BMB_OnLeave'/>
						<OnScroll bind='LIB_BMB_Scroll'/>
					</Events>
				</FocusBox>
			</Group>]], BAR.GROUP)
		BAR.EXIT.TEXT = BAR.EXIT.GROUP:GetChild("text")
		BAR.EXIT.TEXT:SetText(args.exit.label)
		BAR.EXIT.GROUP:SetDims("right:_; width:"..BAR.EXIT.TEXT:GetTextDims(true).width + 70)
		BAR.EXIT.action = args.exit.action
		g_exitclicked = false
	end
	if not args.default then args.default = 1 end
	LIB_BMB_Select(args.default, 0)
end

function LIB_BMB_Finalize()
	for index, tbl in pairs(BAR.OPTIONS) do
		if tbl.finalize then
			tbl.finalize()
		end
		Component.RemoveWidget(tbl.GROUP)
	end
	for i = BAR.ART:GetChildCount(), 1, -1 do
		Component.RemoveWidget(BAR.ART:GetChild(i))
	end
	Component.RemoveWidget(BAR.EXIT.GROUP)
	Component.RemoveWidget(BAR.GROUP)
	BAR = nil
	LIB_BMB_ActiveScreen = nil
end

function LIB_BMB_Select(index, dur)
	if LIB_BMB_ActiveScreen then
		if LIB_BMB_ActiveScreen == index then
			--do nothing
			return
		else
			LIB_BMB_Unselect(LIB_BMB_ActiveScreen, dur)
		end
	end
	LIB_BMB_ActiveScreen = index
	BAR.OPTIONS[index].TEXT:ParamTo("alpha", 1, dur)
	BAR.SLIDER:MoveTo("width:"..(BAR.OPTIONS[index].TEXT:GetTextDims(true).width + 40).."; center-x:50%"..BAR.OPTIONS[index].dimOffset, dur)
	if BAR.OPTIONS[index].title then
		BAR.HEADER.TITLE:SetText(BAR.OPTIONS[index].title)
	else
		BAR.HEADER.TITLE:SetText(BAR.OPTIONS[index].label)
	end
	if BAR.OPTIONS[index].subtitle then
		BAR.HEADER.SUBTITLE:SetText(BAR.OPTIONS[index].subtitle)
	else
		BAR.HEADER.SUBTITLE:SetText("\"Work In Progress\"")
	end
	if BAR.OPTIONS[index].select then
		BAR.OPTIONS[index].select()
	end
end

function LIB_BMB_Scroll(args)
	local delta = args
	if type(args) == "table" then
		if args.amount > 0 then
			delta = -1
		elseif args.amount < 0 then
			delta = 1
		else
			delta = 0
		end
	end
	if delta ~= 0 and BAR.OPTIONS[LIB_BMB_ActiveScreen + delta] then
		LIB_BMB_Select(LIB_BMB_ActiveScreen + delta, g_dur)
	end
end

function LIB_BMB_Unselect(index, dur)
	if BAR.OPTIONS[index].unselect then
		BAR.OPTIONS[index].unselect()
	end
	BAR.OPTIONS[index].TEXT:ParamTo("alpha", 0.5, dur)
end

function LIB_BMB_Show(bool)
     BAR.GROUP:Show(bool)
end
