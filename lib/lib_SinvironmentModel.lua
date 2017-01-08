
--
-- lib_SinvironmentModel
--	by: John Su
--
--	for creating a more ui friendly model interface

--[[

	SINMODEL = SinvironmentModel.Create([LOD])	-- creates a SINMODEL object with an optional Level Of Detail (defaults to 'local_player')
	
	SINMODEL:IsValid()							-- returns if valid (invalidates when leaving Sinvironment)
	SINMODEL:Destroy();							-- removes the object and frees up resources
	
	ANCHOR = SINMODEL:GetAnchor()				-- returns a ui Anchor
	bounds = SINMODEL:GetBounds()				-- returns bounds {x,y,z, width,depth,height}
	
	SINMODEL:Show(visible)						-- marks the model as visible
	SINMODEL:Hide()								-- marks the model as invisible
	SINMODEL:IsVisible()						-- returns true if the model was marked as visible
	SINMODEL:SetScene(scene)					-- sets the scene of the SinModel (like ANCHOR:SetScene)
	
	SINMODEL also supports the :GetParam, :SetParam, :ParamTo, :QueueParam, and :FinishParam methods for the following parameters:
		"alpha", "scale"
	
	SINMODEL:Unload()							-- unloads the model; IsValid() will still return true, though
	SINMODEL:LoadItemType(itemTypeId)			-- loads a model based on the itemTypeId
	SINMODEL:Normalize([size])					-- centers model and, if size is specified, scales model to match
	SINMODEL:AutoSpin(frequency)				-- autospins the model at a given frequency (rotations per second)
	
--]]

SinvironmentModel = {};

require "lib/lib_Callback2";

local SINMODEL_API = {};
local SINMODEL_METATABLE = {
	__index = function(t,key) return SINMODEL_API[key]; end,
	__newindex = function(t,k,v) error("cannot write to value '"..k.."' in SINMODEL"); end
};
local PRIVATE = {};

function SinvironmentModel.Create(LOD)
	LOD = LOD or 'local_player';
	local HANDLE = Sinvironment.CreateModel(LOD, false);
	local SINMODEL = {
		HANDLE		= HANDLE,	-- Sinvironment Model handle
		INT_ANCHOR	= Sinvironment.GetModelAnchor(HANDLE),	-- internal anchor for model
		EXT_ANCHOR	= Component.CreateAnchor("SMX_"..tostring(HANDLE)),	-- external anchor for script
		ROTATER_CB2	= Callback2.Create(),
		LOD			= LOD,
		is_visible	= true,
		itemTypeId	= false,
	};
	SINMODEL.INT_ANCHOR:SetParent(SINMODEL.EXT_ANCHOR);
	
	setmetatable(SINMODEL, SINMODEL_METATABLE);
	
	return SINMODEL;
end

-----------------------------
-- SIN(VIRONMENT)MODEL API --
-----------------------------

function SINMODEL_API.Destroy(SINMODEL)
	Component.RemoveAnchor(SINMODEL.EXT_ANCHOR);
	if (Sinvironment.IsValidModel(SINMODEL.HANDLE)) then
		Sinvironment.RemoveModel(SINMODEL.HANDLE);
	end
	SINMODEL.ROTATER_CB2:Release();
	
	for k,v in pairs(SINMODEL) do
		SINMODEL[k] = nil;
	end
	setmetatable(SINMODEL, nil);
end

function SINMODEL_API.IsValid(SINMODEL)
	return Sinvironment.IsValidModel(SINMODEL.HANDLE);
end

function SINMODEL_API.Show(SINMODEL, visible)
	SINMODEL.is_visible = (visible ~= false);
	local lod = SINMODEL.LOD;
	if (not visible) then
		lod = "invisible";
	end
	Sinvironment.SetModelLOD(SINMODEL.HANDLE, lod);
end

function SINMODEL_API.Hide(SINMODEL)
	SINMODEL.is_visible = false;
	Sinvironment.SetModelLOD(SINMODEL.HANDLE, "invisible");
end

function SINMODEL_API.IsVisible(SINMODEL)
	return SINMODEL.is_visible;
end

function SINMODEL_API.GetAnchor(SINMODEL)
	return SINMODEL.EXT_ANCHOR;
end

function SINMODEL_API.SetScene(SINMODEL, ...)
	SINMODEL.INT_ANCHOR:SetScene(...);
	SINMODEL.EXT_ANCHOR:SetScene(...);
end

function SINMODEL_API.GetBounds(SINMODEL)
	assert(SINMODEL:IsValid(), "invalid SinModel");
	return Sinvironment.GetModelBounds(SINMODEL.HANDLE);
end

function SINMODEL_API.Unload(SINMODEL)
	if (Sinvironment.IsValidModel(SINMODEL.HANDLE)) then
		local params = {
			translation = SINMODEL.INT_ANCHOR:GetParam("translation"),
			rotation = SINMODEL.INT_ANCHOR:GetParam("rotation"),
			scale = SINMODEL.INT_ANCHOR:GetParam("scale"),
		}
		Sinvironment.RemoveModel(SINMODEL.HANDLE);
		-- make a new empty one
		SINMODEL.HANDLE = Sinvironment.CreateModel(SINMODEL.LOD);
		-- replace the old internal anchor
		SINMODEL.INT_ANCHOR = Sinvironment.GetModelAnchor(SINMODEL.HANDLE);
		SINMODEL.INT_ANCHOR:SetParent(SINMODEL.EXT_ANCHOR);
		for pName,pVal in pairs(params) do
			SINMODEL.INT_ANCHOR:SetParam(pName, pVal);
		end
	end
end

function SINMODEL_API.LoadItemType(SINMODEL, itemTypeId)
	assert(SINMODEL:IsValid(), "invalid SinModel");
	if itemTypeId and (not isequal(SINMODEL.itemTypeId, itemTypeId)) then
		SINMODEL.itemTypeId = itemTypeId;
		return Sinvironment.LoadItemType(SINMODEL.HANDLE, itemTypeId);
	end
end

function SINMODEL_API.Normalize(SINMODEL, target_size)
	assert(SINMODEL:IsValid(), "invalid SinModel");
	local bounds = Sinvironment.GetModelBounds(SINMODEL.HANDLE);
	local scale = 1;
	if (target_size) then
		local dim_names = {"width", "height", "depth"};
		local avg_size = 0;
		local EXP = 4;	-- take the exponential average
		for _,d in pairs(dim_names) do
			local dim = bounds[d];
			avg_size = avg_size + math.pow(dim or 0, EXP);
		end
		avg_size = math.pow(avg_size / 3, 1/EXP);
		local current_size = avg_size;
		--current_size = dims[3] * math.max(dims[2], math.min(.1, dims[3]));	-- scale based on 2d slice
		--target_size = target_size * target_size;
		if (current_size > 0) then
			scale = target_size / current_size;
			Sinvironment.SetModelScale(SINMODEL.HANDLE, scale);
		end
	end
	Sinvironment.SetModelPosition(SINMODEL.HANDLE, {x=-bounds.x*scale, y=-bounds.y*scale, z=-bounds.z*scale});
end

function SINMODEL_API.AutoSpin(SINMODEL, frequency)
	assert(SINMODEL:IsValid(), "invalid SinModel");
	local rotation = SINMODEL.INT_ANCHOR:GetParam("rotation");
	if (frequency ~= 0) then
		local dur = 1/math.abs(frequency) * 2/3;
		SINMODEL.INT_ANCHOR:SetParam("rotation", rotation );
		for i=1,3 do
			SINMODEL.INT_ANCHOR:QueueParam("rotation", {angle=rotation.angle+(120*i*rotation.axis.z)%360, axis=rotation.axis}, dur, 0, "linear" );
		end
		SINMODEL.INT_ANCHOR:RepeatParams("rotation", 3 );
	else
		-- stop!
		SINMODEL.INT_ANCHOR:SetParam("rotation", rotation );
	end
end


-------------
-- PRIVATE --
-------------
function PRIVATE.RegisterParamMethods(attempt_count)
	if (not Sinvironment) then
		-- try again later
		callback(PRIVATE.RegisterParamMethods, attempt_count+1, 0.001+attempt_count*attempt_count);
		return;
	end
	-- forward param methods
	local PARAM_METHODS = {
		GetParam = {	alpha	= Sinvironment.GetModelAlpha,
						scale	= Sinvironment.GetModelScale,	},
		SetParam = {	alpha	= Sinvironment.SetModelAlpha,
						scale	= Sinvironment.SetModelScale,	},
		ParamTo = {		alpha	= Sinvironment.AlphaModelTo,
						scale	= Sinvironment.ScaleModelTo,	},
		QueueParam = {	alpha	= Sinvironment.QueueModelAlpha,
						scale	= Sinvironment.QueueModelScale,	},
		FinishParam = {	alpha	= Sinvironment.FinishModelAlpha,
						scale	= Sinvironment.FinishModelScale,	},
	};
	for method, lookups in pairs(PARAM_METHODS) do
		SINMODEL_API[method] = function(SINMODEL, param, ...)
			return lookups[param](SINMODEL.HANDLE, ...);
		end;
	end
end
PRIVATE.RegisterParamMethods(0);
