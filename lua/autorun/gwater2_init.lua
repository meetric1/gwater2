AddCSLuaFile()

include("gwater2_swimming.lua")

if SERVER then 
	return 
end

require((BRANCH == "x86-64" or BRANCH == "chromium" ) and "gwater2" or "gwater2_main")	-- carrying
include("gwater2_shaders.lua")

-- GetMeshConvexes but for client
local function unfucked_get_mesh(ent, raw)
	-- Physics object exists
	local phys = ent:GetPhysicsObject()
	if phys:IsValid() then return phys:GetMesh() end

	local model = ent:GetModel()
	local is_ragdoll = util.IsValidRagdoll(model)
	local convexes

	if !is_ragdoll or raw then
		local cs_ent = ents.CreateClientProp(model)
		local phys = cs_ent:GetPhysicsObject()
		convexes = phys:IsValid() and (raw and phys:GetMesh() or phys:GetMeshConvexes())
		cs_ent:Remove()
	else 
		local cs_ent = ClientsideRagdoll(model)
		convexes = {}
		for i = 0, cs_ent:GetPhysicsObjectCount() - 1 do
			table.insert(convexes, cs_ent:GetPhysicsObjectNum(i):GetMesh())
		end
		cs_ent:Remove()
	end

	return convexes
end

-- adds entity to FlexSolver
local function add_prop(ent)
	if !IsValid(ent) or !ent:IsSolid() or ent:IsWeapon() or !ent:GetModel() then return end

	-- Note: if we want to respect no collide from the tool or context menu, check for COLLISION_GROUP_WORLD
	-- if ent:GetCollisionGroup() == COLLISION_GROUP_WORLD or (IsValid(ent:GetPhysicsObject()) and (!ent:GetPhysicsObject():IsCollisionEnabled())) then return end

	local convexes = unfucked_get_mesh(ent)
	if !convexes then return end

	if #convexes < 16 then	-- too many convexes to be worth calculating
		for k, v in ipairs(convexes) do
			if #v <= 64 * 3 then	-- hardcoded limits.. No more than 64 planes per convex as it is a FleX limitation
				gwater2.solver:AddConvexMesh(ent:EntIndex(), v, ent:GetPos(), ent:GetAngles())
			else
				gwater2.solver:AddConcaveMesh(ent:EntIndex(), v, ent:GetPos(), ent:GetAngles())
			end
		end
	else
		gwater2.solver:AddConcaveMesh(ent:EntIndex(), unfucked_get_mesh(ent, true), ent:GetPos(), ent:GetAngles())
	end

end

local function get_map_vertices()
	local all_vertices = {}
	for _, brush in ipairs(game.GetWorld():GetBrushSurfaces()) do
		local vertices = brush:GetVertices()
		for i = 3, #vertices do
			all_vertices[#all_vertices + 1] = vertices[1]
			all_vertices[#all_vertices + 1] = vertices[i - 1]
			all_vertices[#all_vertices + 1] = vertices[i]
		end
	end

	return all_vertices
end

gwater2 = {
	solver = FlexSolver(100000),
	renderer = FlexRenderer(46),
	new_ticker = true,
	material = Material("gwater2/finalpass"),--Material("vgui/circle"),--Material("sprites/sent_ball"),
	update_meshes = function(index, id, rep)
		if id == 0 then return end	-- skip, entity is world

		local ent = Entity(id)
		if !IsValid(ent) then 
			gwater2.solver:RemoveMesh(id)
		else 
			if !util.IsValidRagdoll(ent:GetModel()) then
				gwater2.solver:UpdateMesh(index, ent:GetPos(), ent:GetAngles())	
			else
				-- horrible code for proper ragdoll collision. Still breaks half the time. Fuck source
				local bone_index = ent:TranslatePhysBoneToBone(rep)
				local pos, ang = ent:GetBonePosition(bone_index)
				if !pos or pos == ent:GetPos() then 	-- wtf?
					local bone = ent:GetBoneMatrix(bone_index)
					if bone then
						pos = bone:GetTranslation()
						ang = bone:GetAngles()
					else
						pos = ent:GetPos()
						ang = ent:GetAngles()
					end
				end
				gwater2.solver:UpdateMesh(index, pos, ang)
			end
		end
	end,
	reset_solver = function(err)
		xpcall(function()
			gwater2.solver:AddMapMesh(0, game.GetMap())
		end, function(e)
			gwater2.solver:AddConcaveMesh(0, get_map_vertices(), Vector(), Angle())
			if !err then
				ErrorNoHaltWithStack("[GWater2]: Map BSP structure is unsupported. Reverting to brushes. Collision WILL have holes!")
			end
		end)

		for k, ent in ipairs(ents.GetAll()) do
			add_prop(ent)
		end

		gwater2.solver:InitBounds(Vector(-16384, -16384, -16384), Vector(16384, 16384, 16384))	-- source bounds
	end
}

-- setup percentage values (used in menu)
gwater2["surface_tension"] = gwater2.solver:GetParameter("surface_tension") * gwater2.solver:GetParameter("radius")^4	-- dont ask me why its a power of 4
gwater2["fluid_rest_distance"] = gwater2.solver:GetParameter("fluid_rest_distance") / gwater2.solver:GetParameter("radius")
gwater2["collision_distance"] = gwater2.solver:GetParameter("collision_distance") / gwater2.solver:GetParameter("radius")
gwater2["cohesion"] = gwater2.solver:GetParameter("cohesion") * gwater2.solver:GetParameter("radius") * 0.1	-- cohesion scales by radius, for some reason..
gwater2["blur_passes"] = 3
-- watergun specific
gwater2["size"] = 4
gwater2["density"] = 1
gwater2["forward_velocity"] = 100
-- reaction force specific
gwater2["force_multiplier"] = 0.01
gwater2["force_buoyancy"] = 0
gwater2["force_dampening"] = 0

-- tick particle solver
local last_systime = os.clock()
local limit_fps = 1 / 60
local average_frametime = limit_fps
local function gwater_tick()
	if gwater2.new_ticker then return end

	-- Defined in C++
	GWATER2_QuickHackRemoveMeASAP(LocalPlayer():EntIndex(), 0)	-- TODO: REMOVE THIS HACKY SHIT!!!!!!!!!!!!!
	LocalPlayer().GWATER2_CONTACTS = 0

	local systime = os.clock()
	if gwater2.solver:Tick(limit_fps, 1) then
		hook.Run("gwater2_pretick")	-- not actually pretick
		average_frametime = average_frametime + (limit_fps - average_frametime) * 0.03
		last_systime = systime	// smooth out fps

		gwater2.renderer:BuildMeshes(gwater2.solver, 0.15)
	end
end

local function gwater_tick2()
	last_systime = os.clock()
	gwater2.solver:ApplyContacts(limit_fps * gwater2["force_multiplier"], 3, gwater2["force_buoyancy"], gwater2["force_dampening"])
	local particles_in_radius = gwater2.solver:GetParticlesInRadius(LocalPlayer():GetPos() + LocalPlayer():OBBCenter(), gwater2.solver:GetParameter("fluid_rest_distance") * 3, GWATER2_PARTICLES_TO_SWIM)
	GWATER2_QuickHackRemoveMeASAP(	-- TODO: REMOVE THIS HACKY SHIT!!!!!!!!!!!!!
		LocalPlayer():EntIndex(), 
		particles_in_radius
	)
	LocalPlayer().GWATER2_CONTACTS = particles_in_radius

	gwater2.solver:IterateMeshes(gwater2.update_meshes)
	hook.Run("gwater2_pretick")
	if gwater2.solver:Tick(FrameTime(), 0) then
		gwater2.renderer:BuildMeshes(gwater2.solver, 0.15)
	end
end

// run whenever possible, as often as possible. we dont know when flex will finish calculations
local no = function() end
hook.Add("PreRender", "gwater_tick", gwater_tick)
hook.Add("PostRender", "gwater_tick", gwater_tick)
hook.Add("Think", "gwater_tick", function()
	if gwater2.new_ticker then return end
	gwater2.solver:IterateMeshes(gwater2.update_meshes)
end)

timer.Create("gwater2_tick", 0, 0, function()
	if !gwater2.new_ticker then return end
	gwater_tick2()
end)

hook.Add("InitPostEntity", "gwater2_addprop", gwater2.reset_solver)
hook.Add("OnEntityCreated", "gwater2_addprop", function(ent) timer.Simple(0, function() add_prop(ent) end) end)	// timer.0 so data values are setup correctly

hook.Add("gwater2_pretick", "gwater2_gravgun_grab", function()
	local lp = LocalPlayer()
	if !lp:KeyDown(IN_ATTACK2) then return end
	if IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer():GetActiveWeapon():GetClass() == "weapon_physcannon" then
		gwater2.solver:AddForceField(LocalPlayer():EyePos() + LocalPlayer():GetAimVector() * 170, 150, -200, 0, true)
	end
end)

hook.Add("Think", "gwater2_gravgun_punt", function()	-- + LocalPlayer():GetAimVector() * 85
	local lp = LocalPlayer()
	if !lp:KeyPressed(IN_ATTACK) then return end
	if IsValid(LocalPlayer():GetActiveWeapon()) and LocalPlayer():GetActiveWeapon():GetClass() == "weapon_physcannon" then
		gwater2.solver:AddForceField(LocalPlayer():EyePos(), 320, 200, 1, false)
	end
end)