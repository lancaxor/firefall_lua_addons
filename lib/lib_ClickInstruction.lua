
--
-- lib_ClickInstruction
--   by: Chris Lierman
--

ClickInstruction = {}
local CI_API = {}
local PRIVATE = {}

--CONSTANTS

local bp_CI = 
	[=[<Group name="CI" dimensions="left:0; top:0; height:141; width:124;">
		<StillArt name="bg" dimensions="center-x:50%; center-y:50%; height:123; width:123;" style="texture:mouseHintBG; eatsmice:false"/>
		<StillArt name="mouse" dimensions="left:0; top:0; height:141; width:124;" style="texture:mouseHintUp; eatsmice:false"/>
		<StillArt name="mouseBtn" dimensions="left:0; top:0; height:141; width:124;" style="texture:mouseHintDown; alpha:0; eatsmice:false"/>
		<StillArt name="arrowH" dimensions="left:0; top:0; height:141; width:124;" style="texture:mouseHintHArrow; visible:false; eatsmice:false"/>
		<StillArt name="arrowV" dimensions="left:0; top:0; height:141; width:124;" style="texture:mouseHintVArrow; visible:false; eatsmice:false"/>
	</Group>]=]

local c_pulse_speed = 1

--VARIABLES

cb_arrow_anim = nil

--FUNCTIONS
function ClickInstruction.Create(PARENT)
	if PARENT == nil then
		warn("Attempt to create a ClickInstruction with an invalid parent")
		return
	end

	local WIDGET = Component.CreateWidget(bp_CI, PARENT)
	local CI = 
	{
		GROUP = WIDGET,
		BTN_IMG = WIDGET:GetChild("mouseBtn"),
		ARROW_H = WIDGET:GetChild("arrowH"),
		ARROW_V = WIDGET:GetChild("arrowV"),
		BG = WIDGET:GetChild("bg"),
	}

	-- function binds
	for k,method in pairs(CI_API) do
		CI[k] = method;
	end
	return CI
end


--------------
-- CI_API --
-------------

function CI_API.Destroy(CI)
	if cb_arrow_anim ~= nil then
		cb_arrow_anim:Stop()
	end

	if CI == nil or CI.GROUP == nil then
		return
	end

	Component.RemoveWidget(CI.GROUP);
	-- gut it
	for k,v in pairs(CI) do
		CI[k] = nil;
	end
end

function CI_API.ShowLeftClick(CI, shouldShow)
	if CI == nil or CI.BTN_IMG == nil then
		return
	end

	if shouldShow == nil or shouldShow == true then
		BTN_IMG:InvertHorizontal(false)
		PRIVATE.StartBtnAnim(CI)
	else
		CI.BTN_IMG:ParamTo("alpha", 0, 0.3)
	end
end

function CI_API.ShowRightClick(CI, shouldShow)
	if CI == nil or CI.BTN_IMG == nil then
		return
	end

	if shouldShow == nil or shouldShow == true then
		CI.BTN_IMG:InvertHorizontal(true)
		PRIVATE.StartBtnAnim(CI)
	else
		CI.BTN_IMG:ParamTo("alpha", 0, 0.3)
	end
end

function CI_API.ShowLeftArrow(CI, shouldShow)
	if CI == nil or CI.ARROW_H == nil then
		return
	end

	CI.ARROW_H:InvertHorizontal(false)
	CI.ARROW_H:Show(shouldshow ~= false)

	cb_arrow_anim = Callback2.CreateCycle(function() PRIVATE.LeftArrowAnim(CI) end)
	cb_arrow_anim:Run(1)
end

function CI_API.ShowRightArrow(CI, shouldShow)
	if CI == nil or CI.ARROW_H == nil then
		return
	end

	CI.ARROW_H:Show(shouldshow ~= false)
	CI.ARROW_H:InvertHorizontal(true)

	cb_arrow_anim = Callback2.CreateCycle(function() PRIVATE.RightArrowAnim(CI) end)
	cb_arrow_anim:Run(1)
end


function CI_API.ShowUpArrow(CI, shouldShow)
	if CI == nil or CI.ARROW_V == nil then
		return
	end

	CI.ARROW_V:SetRegion("up")
	CI.ARROW_V:Show(shouldshow ~= false)

	cb_arrow_anim = Callback2.CreateCycle(function() PRIVATE.UpArrowAnim(CI) end)
	cb_arrow_anim:Run(1)
end


function CI_API.ShowDownArrow(CI, shouldShow)
	log("***SHOW DOWN ARROW")
	if CI == nil or CI.ARROW_V == nil then
		return
	end

	CI.ARROW_V:SetRegion("down")
	CI.ARROW_V:Show(shouldshow ~= false)

	cb_arrow_anim = Callback2.CreateCycle(function() PRIVATE.DownArrowAnim(CI) end)
	cb_arrow_anim:Run(1)
end

-------------
-- PRIVATE --
-------------

function PRIVATE.StartBtnAnim(CI)
	if CI == nil or CI.BTN_IMG == nil then
		return
	end

	CI.BTN_IMG:SetParam("alpha", 0)
	CI.BTN_IMG:CycleParam("alpha", 1, 0.5, 0)
end

function PRIVATE.LeftArrowAnim(CI)
	CI.ARROW_H:QueueMove("left:-12; top:0; height:_; width:_;", 0.5, 0, "ease-in")
	CI.ARROW_H:QueueMove("left:0; top:0; height:_; width:_;", 0.5, 0, "ease-out")
end

function PRIVATE.RightArrowAnim(CI)
	CI.ARROW_H:QueueMove("left:12; top:0; height:_; width:_;", 0.5, 0, "ease-in")
	CI.ARROW_H:QueueMove("left:0; top:0; height:_; width:_;", 0.5, 0, "ease-out")
end

function PRIVATE.UpArrowAnim(CI)
	CI.ARROW_V:QueueMove("left:0; top:-12; height:_; width:_;", 0.5, 0, "ease-in")
	CI.ARROW_V:QueueMove("left:0; top:0; height:_; width:_;", 0.5, 0, "ease-out")
end

function PRIVATE.DownArrowAnim(CI)
	CI.ARROW_V:QueueMove("left:0; top:12; height:_; width:_;", 0.5, 0, "ease-in")
	CI.ARROW_V:QueueMove("left:0; top:0; height:_; width:_;", 0.5, 0, "ease-out")
end
