
--
-- lib_Attract
--   by: Paul Schultz
--
-- For attaching, animating and removing a UI element meant to attract the user's attention

--[[

-- INTERFACE

	Attract.AttachAttractor(hostWidgetGroup, [toScale = 1])				-- Attach attractor widgetry to a host widget that has the supporting hooks set up. You'll need a group
																		for the foreground and background, set to the .AHF and .AHB members of the host widget respectively.
																		Use 'toScale' to size the attractor appropriately.
																				
	Attract.KickAttractor(hostWidgetGroup)								-- Starts the attractor animation. The background will loop but the foreground plays just once and disappears.
																				
	Attract.HideAttractor(hostWidgetGroup, [hideBeginDelay = 2.5],		-- Hides all of the attractor pieces after 'hideBeginDelay' seconds, over 'hideDuration' seconds.
											[hideDuration = 0.5])
--]]
require "lib/lib_math"
require "lib/lib_Vector"
require "lib/lib_Callback2"

if Attract then
	return nil;
end
Attract = {};


g_visible = false;
local PRIVATE = {};

local ATTRACT_BACK_RECIPE = [[<Group name="rotatyBits" dimensions="height:160;width:160" style="visible:false">
				<Animation id="flare1" name="flare1" dimensions="dock:fill" mesh="rotater" style="texture:Attract; region:flare; alpha:0.3; exposure:1.0; tint:A0E0FF"/>
				<Animation id="flare2" name="flare2" dimensions="dock:fill" mesh="rotater" style="texture:Attract; region:flare2; alpha:0.3; exposure:1.0; tint:A0E0FF"/>
				<Animation id="flare4" name="flare4" dimensions="dock:fill" mesh="rotater" style="texture:Attract; region:flare4; alpha:1; exposure:1.0; tint:A0E0FF"/>
				<Animation id="flare3" name="flare3" dimensions="dock:fill" mesh="rotater" style="texture:Attract; region:flare3; alpha:1; exposure:1.0; tint:A0E0FF"/>
				<StillArt name="glow1" dimensions="center-x:50%; center-y:50%; height:100%; aspect:1.0" style="exposure:1.0; alpha:1; tint:#0077ff; texture:gradients; region:sphere; eatsmice:false"/>
				<StillArt name="glow2" dimensions="center-x:50%; center-y:50%; height:90%; aspect:1.0" style="exposure:1.0; alpha:1; tint:#FFFFFF; texture:gradients; region:sphere; eatsmice:false"/>
			</Group>]]

local ATTRACT_FRONT_RECIPE = [[<Group name="rotatyBits" dimensions="height:160;width:160" style="visible:false">
				<Animation id="reticle4" name="reticle4" dimensions="center-x:50%; center-y:50%; height:116%; aspect:1.0" mesh="rotater" style="texture:Attract; region:reticle4; alpha:1; exposure:1.0;"/>
				<Animation id="reticle1" name="reticle1" dimensions="center-x:50%; center-y:50%; height:117%; aspect:1.0" mesh="rotater" style="texture:Attract; region:reticle1; alpha:1; exposure:1.0;"/>
				<Animation id="reticle2" name="reticle2" dimensions="center-x:50%; center-y:50%; height:108%; aspect:1.0" mesh="rotater" style="texture:Attract; region:reticle2; alpha:1; exposure:1.0;"/>
				<Animation id="reticle3" name="reticle3" dimensions="center-x:50%; center-y:50%; height:100%; aspect:1.0" mesh="rotater" style="texture:Attract; region:reticle3; alpha:1; exposure:1.0;"/>
				<Animation id="reticle5" name="reticle5" dimensions="center-x:50%; center-y:50%; height:112%; aspect:1.0" mesh="rotater" style="texture:Attract; region:reticle5; alpha:1; exposure:1.0;"/>
			</Group>]]

local ARROW_RECIPE = [[<Group name="Arrow" dimensions="height:63;width:63" style="visible:false; eatsmice:false">
				<Animation id="arrow" name="arrow" dimensions="dock:fill" mesh="rotater" style="texture:Attract; region:arrow; alpha:1; exposure:1.0; eatsmice:false"/>
			</Group>]]

local c_stepDistance = 19
local c_NumArrows = 20
local c_ArrowSpawnDelay = 0.04
local cb_arrowLine
local cb_showArrows
local g_StartPos = Vector.New(2)
local g_EndPos = Vector.New(2)
local g_CurArrowPos = Vector.New(2)
local g_ArrowList = {}
local g_curArrowIndex = 1
local g_ArrowHost
local g_Dir = Vector.New(2)
local g_LRScalar = -1 --if -1, the arrows are going from left to right, otherwise the arrows are going right to left
local g_leadArrow

--host will be the parent of the arrows.
--IMPORTANT: startPos and endPos are assumed to be in screen space
function Attract.ShowArrows(host, startPos, endPos, arrowScale, delay)
	if (type(delay) == "number") then
		cb_showArrows = callback(function () Attract.ShowArrows(host, startPos, endPos, arrowScale, nil) end, nil, delay);
		return;
	end
	cb_showArrows = nil
	Attract.HideArrows()

	if(host == nil or startPos == nil or endPos == nil) then
		log("***ATTRACT.SHOW_ARROWS GOT INVALID INPUT")
		log("***HOST = "..tostring(host))
		log("***START = "..tostring(startPos))
		log("***END = "..tostring(endPos))

		return;
	end

	g_StartPos = Vec2.Copy(startPos)
	g_EndPos = Vec2.Copy(endPos)
	g_ArrowHost = host
	arrowScale = arrowScale or 1

	--convert positions to host space
	local hostBounds = g_ArrowHost:GetBounds()
	local hostOrigin = {x = hostBounds.left, y = hostBounds.top}
	g_StartPos = Vec2.Sub(g_StartPos, hostOrigin)
	g_EndPos = Vec2.Sub(g_EndPos, hostOrigin)

	g_CurArrowPos = g_StartPos

	--get normalized vector from start to end
	g_Dir = Vec2.Normalize(Vec2.Sub(g_EndPos, g_StartPos))

	--calculate rotation where 1 = 360 degrees and -1 = -360 degrees (arrow starts off pointing right)
	g_LRScalar = -1
	local rotation = 0
	if(g_StartPos.x > g_EndPos.x) then
		g_LRScalar = 1
		--add 0.5 (180 degrees) to start the arrow pointing to the left
		rotation = 0.5
	end
	--the dot product will provide a number between -1 and 1 so we multiply it by 0.25 to get a number between -0.25 and 0.25 [-90 degrees, 90 degrees]
	rotation = rotation + (Vec2.Dot( {x = 0, y = -1}, g_Dir)*g_LRScalar)*0.25

	--animate the lead arrow from start to end
	g_leadArrow = {GROUP = Component.CreateWidget(ARROW_RECIPE, g_ArrowHost) }
	if(g_leadArrow) then
		--local lifespan = (Vec2.Distance(g_EndPos, g_StartPos)/c_stepDistance)*c_ArrowSpawnDelay
		g_leadArrow.GROUP:SetParam("alpha", 0);
		g_leadArrow.GROUP:QueueParam("alpha", 1, c_ArrowSpawnDelay, c_ArrowSpawnDelay)
		local targetPos = Vec2.Add(g_CurArrowPos, {x = g_Dir.x * c_stepDistance, y = g_Dir.y * c_stepDistance })
		g_leadArrow.GROUP:SetDims("center-y:"..targetPos.y.."; center-x:"..targetPos.x.."; width:"..63*arrowScale.."; height:"..63*arrowScale..";")
		g_leadArrow.ARROW = g_leadArrow.GROUP:GetChild("arrow")
		g_leadArrow.ARROW:Play(rotation,rotation,0,false)
		g_leadArrow.GROUP:Show();
	end

	--initialize trail arrows if necessary
	for index = 1, c_NumArrows do

		if(g_ArrowList[index] == nil) then
			g_ArrowList[index] = {GROUP = Component.CreateWidget(ARROW_RECIPE, g_ArrowHost) };
		end

		if (g_ArrowList[index]) then
			g_ArrowList[index].GROUP:SetParam("alpha", 0);
			g_ArrowList[index].GROUP:SetDims("center-y:_; center-x:_; width:"..63*arrowScale.."; height:"..63*arrowScale..";");
			g_ArrowList[index].ARROW = g_ArrowList[index].GROUP:GetChild("arrow");
			g_ArrowList[index].ARROW:Play(rotation,rotation,0,false);
		end
	end

	--start the chain of arrows:
	PRIVATE.ShowNextArrow()
end

function Attract.HideArrows()
	--stop the recurring arrow animations
	if cb_arrowLine then
		cancel_callback(cb_arrowLine)
		cb_arrowLine = nil
	end

	if cb_showArrows then
		cancel_callback(cb_showArrows)
		cb_showArrows = nil
	end

	--hide all the arrows
	for index, curArrow in pairs(g_ArrowList) do
		curArrow.GROUP:SetParam("alpha", 0)
	end

	--remove lead arrow
	if g_leadArrow  ~= nil then
		Component.RemoveWidget(g_leadArrow.GROUP);
		g_leadArrow = nil
	end
end

function PRIVATE.ShowNextArrow()
	cb_arrowLine = nil
	local curArrow = g_ArrowList[g_curArrowIndex]

	if curArrow == nil then
		return
	end

	--place the next arrow c_stepDistance along the line
	g_CurArrowPos = Vec2.Add(g_CurArrowPos, {x = g_Dir.x * c_stepDistance, y = g_Dir.y * c_stepDistance })

	--check for the end of the line
	if((g_LRScalar == -1 and g_CurArrowPos.x > g_EndPos.x) or 
		(g_LRScalar == 1 and g_CurArrowPos.x < g_EndPos.x)) then
		--Arrow animation finished so return before showing more arrows or creating the next callback.  
		--Previous arrows will fade out on their own.
		return
	end

	--play the fade in then fade out animations
	curArrow.GROUP:SetDims("center-x:"..g_CurArrowPos.x.."; width:_; center-y:"..g_CurArrowPos.y.."; height:_")
	curArrow.GROUP:SetParam("alpha", 0);
	curArrow.GROUP:QueueParam("alpha", 1, 0.03, 0);
	curArrow.GROUP:QueueParam("alpha", 0, 0.3, 0, "linear");
	curArrow.GROUP:Show();

	g_curArrowIndex = g_curArrowIndex + 1
	if g_curArrowIndex > c_NumArrows then
		g_curArrowIndex = 1
	end

	--move the lead arrow
	local nextPos = Vec2.Add(g_CurArrowPos, {x = g_Dir.x * c_stepDistance, y = g_Dir.y * c_stepDistance })
	if((g_LRScalar == -1 and nextPos.x > g_EndPos.x) or 
		(g_LRScalar == 1 and nextPos.x < g_EndPos.x)) then
		--move to the end and fade away
		g_leadArrow.GROUP:MoveTo("center-y:"..g_EndPos.y.."; center-x:"..g_EndPos.x.."; width:_; height:_;", c_ArrowSpawnDelay, "linear")
		g_leadArrow.GROUP:QueueParam("alpha", 0, 0.14, c_ArrowSpawnDelay+0.1)
	else
		g_leadArrow.GROUP:MoveTo("center-y:"..nextPos.y.."; center-x:"..nextPos.x.."; width:_; height:_;", c_ArrowSpawnDelay, "linear")
	end

	--This will display the next arrow in the line after a delay
	cb_arrowLine = callback(PRIVATE.ShowNextArrow, nil, c_ArrowSpawnDelay)
end


function Attract.KickAttractor(hostWidgetGroup, toScale, delay, fosterFront)
	if (type(delay) == "number" and delay > 0) then
		callback(function () Attract.KickAttractor(hostWidgetGroup, toScale, nil, fosterFront) end, nil, delay);
		return;
	end

	local scale = toScale or 1;
	
	if (not PRIVATE.HasAttractorAttached(hostWidgetGroup)) then
		PRIVATE.AttachAttractor(hostWidgetGroup, scale, fosterFront);
	end

	local reticleAnimTime = 0.5
	if (hostWidgetGroup.ATTRACT_DATA) then
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.GROUP:Show();
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.GROUP:SetParam("alpha", 1);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.FLARE1:Play(0, 1, 5, true);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.FLARE2:Play(0, 1, 7, true);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.FLARE3:Play(1, 0, 8, true);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.FLARE4:Play(1, 0, 10, true);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.GLOW2:CycleParam("alpha", 0, 1);

		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:Show();
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:SetParam("alpha", 1);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.RETICLE1:Play(0, 0.48, reticleAnimTime, false);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.RETICLE2:Play(0, 1.1, reticleAnimTime, false);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.RETICLE3:Play(0, 0.6, reticleAnimTime, false);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.RETICLE4:Play(0, 0.65, reticleAnimTime, false);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.RETICLE5:Play(0, 0.61, reticleAnimTime, false);

		local fullSize = 150; -- shrinking from 450% to 150% is the default
		local startScale = 3;
		local endSizeStr = tostring(fullSize * hostWidgetGroup.ATTRACT_DATA.attractScale);
		local startSizeStr = tostring(startScale * fullSize * hostWidgetGroup.ATTRACT_DATA.attractScale);
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:SetDims("height:"..startSizeStr.."%;width:"..startSizeStr.."%;center-x:50%;center-y:50%");
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:MoveTo("height:"..endSizeStr.."%;width:"..endSizeStr.."%;center-x:50%;center-y:50%", reticleAnimTime, 0, "ease-out");
		hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:ParamTo("alpha", 0, 0.3, reticleAnimTime+0.3);
	end
end

function Attract.HideAttractor(hostWidgetGroup, hideBeginDelay, hideDuration)
	local hideBeginDelay = hideBeginDelay or 0;
	local hideDuration = hideDuration or 0.5;
	
	if (PRIVATE.HasAttractorAttached(hostWidgetGroup)) then
		if hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK ~= nil then
			hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK.GROUP:ParamTo("alpha", 0, hideDuration, hideBeginDelay);
		end
		if hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT ~= nil then
			hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT.GROUP:ParamTo("alpha", 0, hideDuration, hideBeginDelay);
		end
	end
end


-------------
-- PRIVATE --
-------------

function PRIVATE.AttachAttractor(hostWidgetGroup, toScale, fosterFront)
	local fgCreateSuccess = false;
	local bgCreateSuccess = false;
	toScale = toScale or 1;

	if (hostWidgetGroup) then
		if (PRIVATE.HasAttractorAttached(hostWidgetGroup)) then
			warn("lib_Attract.AttachAttractor has already been called on widget");
			return;
		end
	
		local bg = hostWidgetGroup.AHB;
		local fg = hostWidgetGroup.AHF;
		local fgParent = fg;

		if(fosterFront) then
			--If fosterFront is true, we create the front attract widget (fgAttractor) to the parent of the host and then foster to fg.
			--This prevents other sibling widgets from displaying on top of fgAttractor.
			fgParent = hostWidgetGroup.GROUP:GetParent()
		end
		
		if (bg and fg) then
			-- in the case of lib_ItemCard and other libs guarding their objects, the lib must create this for us or we'll get an error
			-- when their __newindex errors us.
			hostWidgetGroup.ATTRACT_DATA = {};	
		
			bgAttractor = {GROUP = Component.CreateWidget(ATTRACT_BACK_RECIPE, bg) };
			if (bgAttractor) then
				bgAttractor.GROUP:SetParam("scaleX", toScale);
				bgAttractor.GROUP:SetParam("scaleY", toScale);
				bgAttractor.FLARE1 = bgAttractor.GROUP:GetChild("flare1");
				bgAttractor.FLARE2 = bgAttractor.GROUP:GetChild("flare2");
				bgAttractor.FLARE3 = bgAttractor.GROUP:GetChild("flare3");
				bgAttractor.FLARE4 = bgAttractor.GROUP:GetChild("flare4");
				bgAttractor.GLOW2 = bgAttractor.GROUP:GetChild("glow2");
				bgCreateSuccess = true;
			end

			fgAttractor = {GROUP = Component.CreateWidget(ATTRACT_FRONT_RECIPE, fgParent) };
			if (fgAttractor) then
				fgAttractor.GROUP:SetParam("scaleX", toScale);
				fgAttractor.GROUP:SetParam("scaleY", toScale);
				fgAttractor.RETICLE1 = fgAttractor.GROUP:GetChild("reticle1");
				fgAttractor.RETICLE2 = fgAttractor.GROUP:GetChild("reticle2");
				fgAttractor.RETICLE3 = fgAttractor.GROUP:GetChild("reticle3");
				fgAttractor.RETICLE4 = fgAttractor.GROUP:GetChild("reticle4");
				fgAttractor.RETICLE5 = fgAttractor.GROUP:GetChild("reticle5");
				fgCreateSuccess = true;
				if(fosterFront) then
					Component.FosterWidget(fgAttractor.GROUP, fg, "dims")
				end
			end

			
			hostWidgetGroup.ATTRACT_DATA.ATTRACT_BACK = bgAttractor;
			hostWidgetGroup.ATTRACT_DATA.ATTRACT_FRONT = fgAttractor;
			hostWidgetGroup.ATTRACT_DATA.attractScale = toScale;
			hostWidgetGroup.ATTRACT_DATA.attractSetup = true;
		end
	end
	
	if (not(bgCreateSuccess and fgCreateSuccess)) then
		warn("lib_Attract.AttachAttractor failed, check that the host widget has AHB and AHF hooks");
	end
end

function PRIVATE.HasAttractorAttached(hostWidgetGroup)
	return hostWidgetGroup and hostWidgetGroup.ATTRACT_DATA and hostWidgetGroup.ATTRACT_DATA.attractSetup == true;
end


