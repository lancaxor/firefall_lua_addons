
--
-- lib_ContextWheel
--	by: John Su
--
--	for creating context-dependent NavWheel nodes

--[[

	CONTEXT = ContextWheel.Create(context)		-- creates a CONTEXT object
													[context] can be either "map" or "hud" depending on which wheel you want it to appear in
	
	CONTEXT:SetNodes(NODES)						-- [NODES] is a table of NODEs created from NavWheel.CreateNode() (see lib_NavWheel)
													these NODES are parented into the appropriate parent node depending on the CONTEXT's constructor
	CONTEXT:Activate(active)					-- [active] is a true/false boolean
													use this to manually activate a CONTEXT
	CONTEXT:Destroy()							-- cleans up the CONTEXT; does not destroy the NODEs associated with it
--]]

ContextWheel = {};

local CONTEXT_API = {};
local CONTEXT_METATABLE = {
	__index = function(t,key) return CONTEXT_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in CONTEXT"); end
};
local CONTEXT_NODE_MAPPING = {
	["hud"]	= "hud_context",
	["map"]	= "map_root",
}
local OnNodeDestroyed;

function ContextWheel.Create(context)
	if (not CONTEXT_NODE_MAPPING[context]) then
		error("bad context '"..tostring(context).."'; supports 'hud' or 'map'");
	end

	local CONTEXT = {
		active		= false,	-- authority on being 'active'
		NODES		= {},		-- int-indexed array of Navwheel Nodes
		context		= context,	-- where to put the nodes (CONTEXT_NODE_MAPPING key)
	};
	CONTEXT.OnNodeDestroyed = function(args)
		for i,NODE in ipairs(CONTEXT.NODES) do
			if (NODE == args.target) then
				table.remove(CONTEXT.NODES, i);
				return;
			end
		end
	end
	
	setmetatable(CONTEXT, CONTEXT_METATABLE);
	
	return CONTEXT;
end

------------------------
-- CONTEXT(WHEEL) API --
------------------------

function CONTEXT_API.Destroy(CONTEXT)
	CONTEXT:Activate(false);
	CONTEXT:SetNodes(nil);
	for k,v in pairs(CONTEXT) do
		CONTEXT[k] = nil;
	end
	setmetatable(CONTEXT, nil);
end

function CONTEXT_API.Activate(CONTEXT, active)
	if (CONTEXT.active ~= active) then
		CONTEXT.active = active;
		local context_node = nil;
		if (active) then
			context_node = CONTEXT_NODE_MAPPING[CONTEXT.context];
		end
		for i,NODE in ipairs(CONTEXT.NODES) do
			NODE:SetParent(context_node);
		end
	end
end

function CONTEXT_API.SetNodes(CONTEXT, NODES)
	-- clear out old node
	for i,NODE in ipairs(CONTEXT.NODES) do
		NODE:RemoveHandler("OnDestroyed", CONTEXT.OnNodeDestroyed);
	end
	CONTEXT.NODES = {};
	
	if (NODES) then
		if (type(NODES) == "table") then
			for i,NODE in ipairs(NODES) do
				CONTEXT.NODES[i] = NODE;
				NODE:AddHandler("OnDestroyed", CONTEXT.OnNodeDestroyed);
			end
		else
			-- single item
			CONTEXT.NODES[1] = NODE;
			NODE:AddHandler("OnDestroyed", CONTEXT.OnNodeDestroyed);
		end
	end
end
