-- The GWater 2 Render Pipeline

local function get_gwater_rt(name, mult, depth) 
	mult = mult or 1
	return GetRenderTargetEx(name, ScrW() * mult, ScrH() * mult,
		RT_SIZE_DEFAULT,
		depth or 0,
		2 + 4 + 8 + 256,
		0,
		IMAGE_FORMAT_RGBA16161616F
	)
end

local cache_screen0 = render.GetScreenEffectTexture()
local cache_screen1 = render.GetScreenEffectTexture(1)
local cache_mipmap = get_gwater_rt("gwater2_mipmap", 1 / 1)
local cache_absorption = get_gwater_rt("gwater2_absorption", 1 / 4, MATERIAL_RT_DEPTH_NONE)
local cache_normals = get_gwater_rt("gwater2_normals", 1 / 1, MATERIAL_RT_DEPTH_SEPARATE)
local cache_blur = get_gwater_rt("gwater2_blur", 1 / 2)

local water = Material("gwater2/finalpass")
local water_blur = Material("gwater2/smooth")
local water_volumetric = Material("gwater2/volumetric")
local water_normals = Material("gwater2/normals")
local water_bubble = Material("gwater2/bubble")	-- bubbles
local water_mist = Material("gwater2/mist")
local black = Material("gwater2/black")
local cloth = Material("gwater2/cloth")

local blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true)
local blur_scale = CreateClientConVar("gwater2_blur_scale", "1", true)

local debug_absorption = CreateClientConVar("gwater2_debug_absorption", "0", false)
local debug_normals = CreateClientConVar("gwater2_debug_normals", "0", false)
local debug_mipmap = CreateClientConVar("gwater2_debug_mipmap", "0", false)

-- sets up a lighting origin in sourceengine
local csent
local function unfuck_lighting(pos0, pos1)
	if not IsValid(csent) then
		csent = ClientsideModel("error.mdl")
	end
	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)
	render.Model({model = "models/shadertest/envballs.mdl",pos = pos0, angle = EyeAngles()}, csent)	-- cubemap
	render.Model({model = "models/shadertest/vertexlit.mdl",pos = pos1, angle = EyeAngles()}, csent) 	-- lighting
	render.OverrideDepthEnable(false, false)
	render.OverrideColorWriteEnable(false, false)
end

local lightpos = EyePos()
local function do_cloth()
	unfuck_lighting(gwater2.cloth_pos, gwater2.cloth_pos)	-- fix cloth lighting, mostly
	render.SetMaterial(cloth)
	gwater2.renderer:DrawCloth()
	render.RenderFlashlights(function() gwater2.renderer:DrawCloth() end)

	-- setup water lighting
	--local tr = util.QuickTrace( EyePos(), LocalPlayer():EyeAngles():Forward() * 800, LocalPlayer())
	--local dist = math.min(230, (tr.HitPos - tr.StartPos):Length() / 1.5)	
	--lightpos = LerpVector(1.6 * FrameTime(), lightpos, EyePos() + (LocalPlayer():EyeAngles():Forward() * dist))	-- fucking hell
	unfuck_lighting(EyePos(), EyePos())	
end

local function do_absorption()
	render.UpdateScreenEffectTexture()	-- _rt_framebuffer is used in refraction shader

	-- depth absorption (disabled when opaque liquids are enabled)
	local _, _, _, a = water:GetVector4D("$color2")
	if water_volumetric:GetFloat("$alpha") ~= 0 and a > 0 and a < 255 then
		-- ANTIALIAS FIX! (courtesy of Xenthio)
			-- how it works: 
			-- Clear the main rendertarget, keeping depth
			-- Render to main buffer (still has depth), and copy the contents to another rendertarget
			-- Restore the main buffer

		-- clear screen w/o intruding translucents depth buffer
		render.SetMaterial(black)
		render.DrawScreenQuad()

		render.SetMaterial(water_volumetric)
		gwater2.renderer:DrawWater()
		render.CopyTexture(render.GetRenderTarget(), cache_absorption)
		render.DrawTextureToScreen(cache_screen0)

		--render.PushRenderTarget(cache_absorption)
		--render.SetMaterial(water_volumetric)
		--gwater2.renderer:DrawWater()
		--render.PopRenderTarget()
	else
		-- no absorption calculations, so just use solid color
		render.PushRenderTarget(cache_absorption)
		render.Clear(15, 15, 15, 10)
		render.PopRenderTarget()
	end
end

local function do_diffuse_inside()
	-- dont render bubbles underwater if opaque
	local _, _, _, a = water:GetVector4D("$color2")
	if a < 255 then
		-- Bubble particles inside water
		-- Make sure the water screen texture has bubbles but the normal framebuffer does not
		render.SetMaterial(water_bubble)
		render.UpdateScreenEffectTexture(1)
		gwater2.renderer:DrawDiffuse()
		render.RenderFlashlights(function() gwater2.renderer:DrawDiffuse() end)
		render.CopyTexture(render.GetRenderTarget(), cache_screen0)
		render.DrawTextureToScreen(cache_screen1)
	end
end

local function do_normals()
	local radius = gwater2.solver:GetParameter("radius")

	-- stencils are used to only blur the pixels we want
	---@diagnostic disable: param-type-mismatch
	render.SetStencilWriteMask(0xFF)
	render.SetStencilTestMask(0xFF)
	render.SetStencilReferenceValue(1)
	render.SetStencilCompareFunction(STENCIL_ALWAYS)
	render.SetStencilFailOperation(STENCIL_KEEP)
	render.SetStencilZFailOperation(STENCIL_KEEP)
	render.SetStencilPassOperation(STENCIL_REPLACE)
	render.ClearStencil()
	render.SetStencilEnable(true)

	-- grab normals
	water_normals:SetFloat("$radius", radius / 2)
	render.SetMaterial(water_normals)
	render.PushRenderTarget(cache_normals)
	render.SetRenderTargetEx(1, cache_mipmap)
	render.ClearDepth()
	gwater2.renderer:DrawWater()
	render.PopRenderTarget()
	render.SetRenderTargetEx(1, nil)

	render.SetStencilCompareFunction(STENCIL_EQUAL)
	render.SetStencilEnable(false)
	
	-- Blur normals
	local scrw = 1 / ScrW()
	local scrh = 1 / ScrH()

	water_blur:SetFloat("$radius", radius)
	water_blur:SetTexture("$depthtexture", cache_mipmap)
	render.SetMaterial(water_blur)
	for i = 1, blur_passes:GetInt() do
		local scale = (0.3 / i) * blur_scale:GetFloat()

		-- Blur X
		water_blur:SetTexture("$normaltexture", cache_normals)
		water_blur:SetVector("$scrs", Vector(scale * scrw, 0))
		render.SetStencilEnable(false)	-- cache_blur doesn't have a stencil buffer set up, so we cant use it
		render.PushRenderTarget(cache_blur)
		render.DrawScreenQuad()
		render.PopRenderTarget()
		
		-- Blur Y
		
		water_blur:SetTexture("$normaltexture", cache_blur)
		water_blur:SetVector("$scrs", Vector(0, scale * scrh))
		render.SetStencilEnable(i < blur_passes:GetInt())	-- disable stencils on last pass
		render.PushRenderTarget(cache_normals)
		render.DrawScreenQuad()
		render.PopRenderTarget()
	end
	
	render.SetStencilEnable(false)
	---@diagnostic enable: param-type-mismatch
end

local function do_finalpass()
	local radius = gwater2.solver:GetParameter("radius")

	-- Setup water material parameters
	water:SetFloat("$radius", radius * 1.5)
	water:SetFloat("$reflectance", blur_passes:GetBool() and 0.7 or 0)
	water:SetTexture("$normaltexture", cache_normals)
	water:SetTexture("$depthtexture", cache_absorption)
	render.SetMaterial(water)
	gwater2.renderer:DrawWater()
	render.RenderFlashlights(function() gwater2.renderer:DrawWater() end)

	render.SetMaterial(water_mist)
	gwater2.renderer:DrawDiffuse()
	render.RenderFlashlights(function() gwater2.renderer:DrawDiffuse() end)
end

hook.Add("RenderScene", "gwater2_render", function(eye_pos, eye_angles, fov)
	if gwater2.options.render_mirrors:GetInt() ~= 1 then return end

	cam.Start3D(eye_pos, eye_angles, fov)
		gwater2.renderer:BuildMeshes(gwater2.solver, 0.25, false)
	cam.End3D()
end)

-- vrmod does not render to the main RT, force enable mirror rendering
hook.Add("VRMod_Start", "gwater2_vrmodsupport", function(ply)
	if ply ~= LocalPlayer() then return end

	gwater2.options.render_mirrors:SetInt(1)
end)

-- gwater2 shader pipeline
local vrmod_material = Material("models/wireframe")
hook.Add("PostDrawOpaqueRenderables", "gwater2_render", function(depth, sky, sky3d)	--PreDrawViewModels
	if sky3d then return end	-- dont render in skybox
	if gwater2.solver:GetActiveParticles() < 1 then return end

 	-- dont render in mirrors unless specified
	local mirrors = gwater2.options.render_mirrors:GetInt()
	if mirrors ~= 1 then
		if mirrors == 0 and render.GetRenderTarget() then return end
		gwater2.renderer:BuildMeshes(gwater2.solver, 0.25, true)
	end

	do_cloth()

	-- vrmod is fucked. do this for now
	if vrmod and vrmod.IsPlayerInVR(LocalPlayer()) then
		render.SetMaterial(vrmod_material)
		gwater2.renderer:DrawWater()

		return 
	end
	
	-- Clear render targets
	render.ClearRenderTarget(cache_normals, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_mipmap, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_absorption, Color(0, 0, 0, 0))
	render.ClearRenderTarget(cache_blur, Color(0, 0, 0, 0))

	do_absorption()
	do_diffuse_inside()
	do_normals()
	do_finalpass()

	-- Debug Draw
	local dbg = 0
	if debug_absorption:GetBool() then render.DrawTextureToScreenRect(cache_absorption, ScrW() * 0.75, (ScrH() / 4) * dbg, ScrW() / 4, ScrH() / 4); dbg = dbg + 1 end
	if debug_normals:GetBool() then render.DrawTextureToScreenRect(cache_normals, ScrW() * 0.75, (ScrH() / 4) * dbg, ScrW() / 4, ScrH() / 4); dbg = dbg + 1 end
	if debug_mipmap:GetBool() then render.DrawTextureToScreenRect(cache_mipmap, ScrW() * 0.75, (ScrH() / 4) * dbg, ScrW() / 4, ScrH() / 4); dbg = dbg + 1 end

	--render.DrawTextureToScreenRect(cache_absorption, 0, 0, ScrW() / 4, ScrH() / 4)
end)

--hook.Add("NeedsDepthPass", "gwater2_depth", function()
--	DOFModeHack(true)	-- fixes npcs and stuff dissapearing
--	return true
--end)