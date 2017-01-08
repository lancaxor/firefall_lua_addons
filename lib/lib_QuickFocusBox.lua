
--
-- quickly creates a FocuxBox with bindings
--   by: John Su
--

--[[ Usage

	QFB = QuickFocusBox.Create(PARENT)
		// Creates a SCENE_PLANE tied to a render target
	
	QFB:Destroy()
		// Cleans up the focus box
		
	QFB:BindEvent(event_name, function)
		// Binds an event to a function
	
	properties:
		QFB.WIDGET	-- the FocuxBox widget that's created
		QFB.BINDS	-- table of bound functions (indexed by event name)

--]]

QuickFocusBox = {};

local counter = 0;
local w_QFBs = {};

function QuickFocusBox.Create(PARENT)
	local idx = #w_QFBs+1;
	local QFB = {idx=idx};
	QFB.WIDGET = Component.CreateWidget([[<FocusBox dimensions="dock:fill"/>]], PARENT);
	QFB.WIDGET:SetTag(idx);
	QFB.BINDS = {};
	
	function QFB:Destroy()
		Component.RemoveWidget(self.WIDGET);
		w_QFBs[self.idx] = nil;
		for k,v in pairs(self) do
			self[k] = nil;
		end
	end
	
	function QFB:BindEvent(event_name, func)
		self.BINDS[event_name] = func;
		if (func) then
			self.WIDGET:BindEvent(event_name, "_QuickFocusBox_Event");
		else
			self.WIDGET:BindEvent(event_name, nil);
		end
	end
	
	w_QFBs[idx] = QFB;
	return QFB;
end

-- EVENTS

function _QuickFocusBox_Event(args)
	local QFB = w_QFBs[tonumber(args.widget:GetTag())];
	local func = QFB.BINDS[args.event];
	func(args);
end
