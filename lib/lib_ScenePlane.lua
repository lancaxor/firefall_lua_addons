
--
-- creates a SceneObject (plane) with a render target
--   by: John Su
--

--[[ Usage

	SCENE_PLANE = ScenePlane.Create(renderTarget[, region])
		// Creates a SCENE_PLANE tied to a render target
		
	SCENE_PLANE = ScenePlane.CreateWithRenderTarget(width, height)
		// Same as Create, but also creates a RenderTarget
		
	SCENE_PLANE:Destroy();
		// Cleans up object, and also removes render target if made through CreateWithRenderTarget
	
	SCENE_PLANE:BindToTextureFrame([TEXTURE_FRAME]);
		// Binds scene object to a texture frame (uses SCENE_PLANE.FRAME by default)
		
	_CreateTestObject([parentAnchor])
		// Creates a test box for quickly seeing scene object positions
		
	-- properties:
	SCENE_PLANE.SO = SceneObject
	SCENE_PLANE.ANCHOR = Anchor
	SCENE_PLANE.FRAME = TextureFrame
	SCENE_PLANE.TEXTURE = Texture name, if created

--]]

ScenePlane = {};

local counter = 0;

function ScenePlane.CreateWithRenderTarget(RT_width, RT_height)
	counter = counter+1;
	local RT = Component.GetInfo().."_lib_ScenePlane_RT_"..counter;
	assert(Component.CreateRenderTarget(RT, RT_width, RT_height), "could not create render target");
	local SPLANE = ScenePlane.Create(RT);
	SPLANE.TEXTURE = RT;
	return SPLANE;
end

function ScenePlane.Create(renderTarget, region)
	local SPLANE = {};
	SPLANE.SO = Component.CreateSceneObject("plane");
	SPLANE.ANCHOR = SPLANE.SO:GetAnchor();
	SPLANE.FRAME = Component.CreateFrame("TextureFrame");
	if (region) then
		SPLANE.FRAME:SetTexture(renderTarget, region);
		SPLANE.SO:SetTexture(renderTarget, region);
	else
		SPLANE.FRAME:SetTexture(renderTarget);
		SPLANE.SO:SetTexture(renderTarget);
	end
	SPLANE.Destroy = SPLANE_Destroy;
	SPLANE.BindToTextureFrame = SPLANE_BindToTextureFrame;
	return SPLANE;
end

function SPLANE_Destroy(SPLANE)
	if (SPLANE.TEXTURE) then
		Component.RemoveRenderTarget(SPLANE.TEXTURE);
	end
	Component.RemoveSceneObject(SPLANE.SO);
	Component.RemoveFrame(SPLANE.FRAME);
	for k,v in pairs(SPLANE) do
		SPLANE[k] = nil;
	end
end

function SPLANE_BindToTextureFrame(SPLANE, TFRAME)
	SPLANE.SO:SetTextureFrame(TFRAME or SPLANE.FRAME);
end

-- for debug
function ScenePlane._CreateTestObject(parentAnchor)
	local TSO = Component.CreateSceneObject("box");
	TSO:SetParam("scale", {x=.1, y=.1, z=.1});
	TSO:SetTexture("uierror");
	if (parentAnchor) then
		TSO:GetAnchor():SetParent(parentAnchor);
	end
	return TSO;
end
