
--
-- lib_QueueButton
--   by: James Harless
--

--[[ Usage:
		QUEUEBUTTON = QueueButton.Create(parent)				-- Creates a queue button object
		QUEUEBUTTON:OnEvent(QB, args)							-- Updates Queuebutton on the following events,
																	my_match_queue_response
																	on_match_queue_update
																	on_match_force_unqueue

		QUEUEBUTTON:SetSelectedQueues(table or number)			-- selected queues to queue for
		
		QUEUEBUTTON:UseLFG(bool)								-- Use alternate LFG queuing and strings

		QUEUEBUTTON:IsOpenWorld()								-- returns true if the player is in the open world (New Eden or alike zones)

		QUEUEBUTTON:IsInQueue()									-- returns true if the player is in any queue
		
		QUEUEBUTTON:SkipMatchmaking(bool)						-- sets the queue to skip matchmaking, (disabled when using LFG)
--]]



if QueueButton then
	return nil
end
QueueButton = {}


require "unicode"
require "lib/lib_table"

require "lib/lib_Spinner"
require "lib/lib_EventDispatcher"

-- ------------------------------------------
-- CONSTANTS
-- ------------------------------------------

local API = {}
local lf = {}
local ef = {}
local QB_METATABLE = {
	__index = function(t,key) return API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in QueueButton"); end
};

local MODE_NONE = -1
local MODE_AVAILABLE = 1
local MODE_INQUEUE = 2
local MODE_SELECTQUEUE = 3
local MODE_INSTANCE = 4
local MODE_WAITING = 5
local MODE_SERVERLAUNCH = 6
local MODE_NOTLEADER = 7

local SOUND_CONFIRM		= "Play_UI_Login_Confirm"

local BP_QUEUEGROUP = [[
	<Group dimensions="left:0; top:0; height:100%; width:100%">
		<Group name="button_fostering" dimensions="dock:fill" style="visible:false">
			<!-- General -->
			<Group name="general" dimensions="dock:fill">
				<Text name="label" key="QB_START" dimensions="dock:fill" style="font:Demi_13; halign:center; valign:center;" />	
			</Group>
			<!-- General -->
			<!-- In Queue -->
			<Group name="inqueue" dimensions="dock:fill">
				<Text key="QB_LEAVE" dimensions="left:0; right:100%; top:0; bottom:50%;" style="font:Demi_11; halign:center; valign:bottom;" />
				<Text key="QB_SEARCHING" dimensions="left:0; right:100%; top:50%; bottom:100%;" style="font:Demi_10; halign:center; valign:top; color:salvage" />
			</Group>
			<!-- In Queue -->
		</Group>

		<Group name="spinner" dimensions="left:0.065%; center-y:50%; height:90%; aspect:1" style="visible:false" />
		<Button name="button" dimensions="center-y:50%; right:100%; height:100%; width:100%" class="ButtonSuccess" style="font:Demi_11; clicksound:button_press" />
	</Group>]]

	
local c_BUTTONDISPLAY = {
	["default"] = {
		[MODE_AVAILABLE] = {
			label="", text=false, foster="FOSTER_GENERAL",
			tint="button_success", button=true, event="available",
		},
		[MODE_INQUEUE] = {
			label="", text=false, foster="FOSTER_INQUEUE",
			tint="button_cancel", button=true, event="in_queue",
		},
		[MODE_SELECTQUEUE] = {
			label_key="QB_SELECT", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="select_queue",
		},
		[MODE_INSTANCE] = {
			label_key="QB_INSTANCE", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="instance",
		},
		[MODE_WAITING] = {
			label_key="QB_WAITING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="waiting",
		},
		[MODE_SERVERLAUNCH] = {
			label_key="QB_LAUNCHING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="server_launch",
		},
		[MODE_NOTLEADER] = {
			label_key="QB_NOTLEADER", text=true, foster="FOSTER_GENERAL",
			tint="button_success", button=false, event="unavailable",
		},
	},
	["campaign"] = {
		[MODE_AVAILABLE] = {
			label="", text=false, foster="FOSTER_GENERAL",
			tint="button_success", button=true, event="available",
		},
		[MODE_INQUEUE] = {
			label="", text=false, foster="FOSTER_INQUEUE",
			tint="button_cancel", button=true, event="in_queue",
		},
		[MODE_SELECTQUEUE] = {
			label_key="QB_SELECT", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="select_queue",
		},
		[MODE_INSTANCE] = {
			label_key="QB_INSTANCE", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="instance",
		},
		[MODE_WAITING] = {
			label_key="QB_WAITING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="waiting",
		},
		[MODE_SERVERLAUNCH] = {
			label_key="QB_LAUNCHING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="server_launch",
		},
		[MODE_NOTLEADER] = {
			label_key="QB_NOTLEADER", text=true, foster="FOSTER_GENERAL",
			tint="button_success", button=false, event="unavailable",
		},
	},
	["mission"] = {
		[MODE_AVAILABLE] = {
			label="", text=false, foster="FOSTER_GENERAL",
			tint="button_success", button=true, event="available",
		},
		[MODE_INQUEUE] = {
			label="", text=false, foster="FOSTER_INQUEUE",
			tint="button_cancel", button=true, event="in_queue",
		},
		[MODE_SELECTQUEUE] = {
			label_key="QB_SELECT", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="select_queue",
		},
		[MODE_INSTANCE] = {
			label_key="QB_INSTANCE", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="instance",
		},
		[MODE_WAITING] = {
			label_key="QB_WAITING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="waiting",
		},
		[MODE_SERVERLAUNCH] = {
			label_key="QB_LAUNCHING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="server_launch",
		},
		[MODE_NOTLEADER] = {
			label_key="QB_NOTLEADER", text=true, foster="FOSTER_GENERAL",
			tint="button_success", button=false, event="unavailable",
		},
	},
	["travel"] = {
		[MODE_AVAILABLE] = {
			label="", text=false, foster="FOSTER_GENERAL",
			tint="button_success", button=true, event="available",
		},
		[MODE_INQUEUE] = {
			label="", text=false, foster="FOSTER_INQUEUE",
			tint="button_cancel", button=true, event="in_queue",
		},
		[MODE_SELECTQUEUE] = {
			label_key="QB_SELECT", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="select_queue",
		},
		[MODE_INSTANCE] = {
			label_key="QB_INSTANCE", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="instance",
		},
		[MODE_WAITING] = {
			label_key="QB_WAITING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="waiting",
		},
		[MODE_SERVERLAUNCH] = {
			label_key="QB_LAUNCHING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="server_launch",
		},
		[MODE_NOTLEADER] = {
			label_key="QB_NOTLEADER", text=true, foster="FOSTER_GENERAL",
			tint="button_success", button=false, event="unavailable",
		},
	},
	["lfg"] = {
		[MODE_AVAILABLE] = {
			label="", text=false, foster="FOSTER_GENERAL",
			tint="button_success", button=true, event="available",
		},
		[MODE_INQUEUE] = {
			label="", text=false, foster="FOSTER_INQUEUE",
			tint="button_cancel", button=true, event="in_queue",
		},
		[MODE_SELECTQUEUE] = {
			label_key="QB_SELECT", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="select_queue",
		},
		[MODE_INSTANCE] = {
			label_key="QB_INSTANCE", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="instance",
		},
		[MODE_WAITING] = {
			label_key="QB_WAITING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="waiting",
		},
		[MODE_SERVERLAUNCH] = {
			label_key="QB_LAUNCHING", text=true, foster="FOSTER_GENERAL",
			tint="button_cancel", button=false, event="server_launch",
		},
		[MODE_NOTLEADER] = {
			label_key="QB_NOTLEADER", text=true, foster="FOSTER_GENERAL",
			tint="button_success", button=false, event="unavailable",
		},
	},
}

-- ------------------------------------------
-- QUEUEBUTTON
-- ------------------------------------------
function QueueButton.Create(PARENT)
	local GROUP = Component.CreateWidget(BP_QUEUEGROUP, PARENT)
	local QB = {
		GROUP = GROUP,
		SPINNER_GROUP = GROUP:GetChild("spinner"),
		BUTTON = GROUP:GetChild("button"),
		FOSTER_GENERAL = "QB_START",
		FOSTER_INQUEUE = "QB_LEAVE",
		
		FOSTER_LABEL = GROUP:GetChild("button_fostering.general.label"),
		
		-- Variables
		queued = false,
		display_mode = "default",
		uselfg = false,
		state = MODE_NONE,
		selected_queues = false,
		use_travel = false,
		skip_matchmaking = false,
	}
	QB.DISPATCHER = EventDispatcher.Create(QB)
	QB.DISPATCHER:Delegate(QB)
	
	QB.SPINNER = Spinner.Create(QB.SPINNER_GROUP)
	QB.SPINNER:SetDims("left:_; top:_; height:100%; width:100%;")
	
	QB.BUTTON:BindEvent("OnSubmit", function()
		lf.DoQueue(QB)
	end)
	lf.Button_Update(QB)



	setmetatable(QB, QB_METATABLE)



	return QB
end


-- ------------------------------------------
-- API FUNCTIONS
-- ------------------------------------------
function API.OnEvent(QB, args)
	if args and args.event and ef[args.event] then
		ef[args.event](QB, args)
	end
end

function API.SetSelectedQueues(QB, selected_queues)
	if type(selected_queues) == "number" then 
		QB.selected_queues = selected_queues
	elseif type(selected_queues) == "table" and #selected_queues > 0 then
		QB.selected_queues = _table.copy(selected_queues)
	else
		QB.selected_queues = false
	end
	lf.Button_Update(QB)
end

function API.IsOpenWorld(QB)
	return lf.IsOpenWorldZone(QB)
end

function API.IsInQueue(QB)
	return lf.IsInQueue(QB)
end

function API.IsPlayerGroupLeader()
	return lf.IsPlayerGroupLeader()
end

function API.SetDisplayMode(QB, mode)
	local mode = unicode.lower(mode)
	if c_BUTTONDISPLAY[mode] then
		QB.display_mode = mode
	else
		QB.display_mode = "default"
	end
end

function API.UseLFG(QB, bool)
	QB.uselfg = bool
end

function API.SkipMatchmaking(QB, skip)
	if skip == nil then
		skip = true
	end
	
	QB.skip_matchmaking = skip
end



-- ------------------------------------------
-- LOCAL FUNCTIONS
-- ------------------------------------------
-- Button
function lf.Button_Update(QB)
	local newstate = MODE_SELECTQUEUE
	if lf.IsInQueue(QB) and not Squad.IsLFG() then
		local matchData = Game.GetFoundMatch()
		if matchData and matchData.state == "WaitingForServer" then
			newstate = MODE_WAITING
		elseif matchData and matchData.state == "Launching" then
			newstate = MODE_SERVERLAUNCH
		else
			newstate = MODE_INQUEUE
		end
	elseif not lf.IsOpenWorldZone() then
		newstate = MODE_INSTANCE
	elseif not lf.IsPlayerGroupLeader() then
		newstate = MODE_NOTLEADER
	elseif ( QB.selected_queues ) then
		newstate = MODE_AVAILABLE
	end
	if QB.state ~= newstate then
		local oldstate = QB.state
		QB.state = newstate
		
		if oldstate == MODE_INQUEUE or oldstate == MODE_NONE then
			QB.SPINNER_GROUP:Hide(true, 0.15)
			QB.SPINNER_GROUP:ParamTo("alpha", 0, 0.15)
			QB.BUTTON:MoveTo("right:_; top:_; height:_; width:100%", 0.15)
			callback(function()
				QB.SPINNER:Stop()
			end, nil, 0.25)
		end
		
		if QB.state == MODE_INQUEUE then
			-- Show Spinner & Leave Queue Button
			QB.SPINNER:Play()
			QB.SPINNER_GROUP:Show(true, 0.15)
			QB.SPINNER_GROUP:ParamTo("alpha", 1, 0.15, 0.15)
			QB.BUTTON:MoveTo("right:_; top:_; height:_; width:70%", 0.15)
		end
		
		local display = lf.GetButtonDisplay(QB)
		QB:DispatchEvent("OnStatusUpdate", {event=display.event})
		
		if display.text then
			if display.label_key then
				QB.BUTTON:SetText(Component.LookupText(display.label_key))
			else
				QB.BUTTON:SetText(display.label)
			end
		else
			QB.BUTTON:SetTextKey(QB[display.foster])
		end

		QB.BUTTON:ParamTo("alpha",1, 0.15, 0.15)
		QB.BUTTON:ParamTo("tint", display.tint, 0)
		
		if QB.BUTTON.enabled ~= display.button then
			QB.BUTTON:Enable(display.button)
		end
	end
end

function lf.GetButtonDisplay(QB)
	return c_BUTTONDISPLAY[QB.display_mode][QB.state]
end

-- Queue
function lf.DoQueue(QB)
	if not QB.selected_queues and not lf.IsInQueue(QB) then
		return nil
	end
	System.PlaySound(SOUND_CONFIRM)
	if not lf.IsInQueue(QB) then
		if QB.uselfg then
			Game.QueueForLFG(QB.selected_queues)
		else
			Game.QueueForPvP(QB.selected_queues, true, QB.skip_matchmaking)
		end
	else
		Game.QueueForPvP({}, false)
	end
end

function lf.IsInQueue(QB)
	if QB.queued then
		return true
	end
	local info = Game.GetPvPQueue()
	if info then
		return (#info.queues > 0)
	end
	return false
end

function lf.IsOpenWorldZone()
	local zoneId = Game.GetZoneId()
	local zoneinfo = Game.GetZoneInfo(zoneId)



	return isequal(unicode.lower(zoneinfo.zone_type), "openworld")

end

-- Group
function lf.IsPlayerInGroup()
	local name = Player.GetInfo()
	return (Squad.GetIndexOf(name))
end

function lf.IsPlayerGroupLeader()
	local squad = Squad.GetRoster()
	if not squad then
		return true
	end
	return squad.is_mine
end

function lf.GetGroupSize()
	if lf.IsPlayerInGroup() then
		return #Squad.GetRoster().members
	end
	return 1
end

function lf.IsGroupPlatoon()
	return Platoon.IsInPlatoon()
end

function lf.IsGroupValidSize(min, max)
	if lf.IsPlayerInGroup() then
		local size = lf.GetGroupSize()
		return ( min <= squad and max >= squad )
	else
		return true
	end
end

-- ------------------------------------------
-- EVENT FUNCTIONS
-- ------------------------------------------
ef["my_match_queue_response"] = function(QB, args)
	if type(args.queued) == "nil" then
		args.queued = false
	end
	QB.queued = args.queued
	lf.Button_Update(QB)
end

ef["on_match_queue_response"] = function(QB, args)
	if type(args.queued) == "nil" then
		args.queued = false
	end
	QB.queued = args.queued
	lf.Button_Update(QB)
end

ef["on_match_queue_update"] = function(QB, args)
	if type(args.queued) == "nil" then
		args.queued = false
	end
	QB.queued = args.queued
	lf.Button_Update(QB)
end

ef["on_match_force_unqueue"] = function(QB, args)
	if type(args.queued) == "nil" then
		args.queued = false
	end
	QB.queued = args.queued
	lf.Button_Update(QB)
end

ef["on_squad_join"] = function(QB, args)
	lf.Button_Update(QB)
end
