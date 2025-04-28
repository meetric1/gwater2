AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Emitter"
ENT.Author			= "Meetric"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable   	= true
ENT.Editable		= true

function ENT:Initialize()
	if CLIENT then return end

	self:SetModel("models/mechanics/wheels/wheel_speed_72.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Active",
			"Radius",
			"Strength",
			"Spread",
			"Lifetime"
		})
	end
end

-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Active" then
		return self:SetOn(val > 0)
	end
	if name == "Radius" then
		return self:SetRadius(math.max(1, math.min(20, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(1, math.min(100, val)))
	end
	if name == "Spread" then
		return self:SetSpread(math.max(1, math.min(2, val)))
	end
	if name == "Lifetime" then
		return self:SetLifetime(math.max(0, math.min(100, val)))
	end
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:Spawn()
	ent:Activate()

	ent:SetRadius(6)
	ent:SetStrength(10)
	ent:SetSpread(1)
	ent:SetLifetime(0)
	ent:SetOn(false)
	--ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:SetMaterial("phoenix_storms/gear")

	return ent
end

function ENT:Use(_, _, type)
	self:EmitSound("buttons/lever1.wav")
	self:SetOn(not self:GetOn())
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Radius", {KeyName = "Radius", Edit = {type = "Int", order = 0, min = 1, max = 20}})
	self:NetworkVar("Float", 0, "Spread", {KeyName = "Spread", Edit = {type = "Float", order = 2, min = 1, max = 2}})
	self:NetworkVar("Float", 1, "Lifetime", {KeyName = "Lifetime", Edit = {type = "Float", order = 3, min = 0, max = 100}})
	self:NetworkVar("Float", 2, "Strength", {KeyName = "Strength", Edit = {type = "Float", order = 4, min = 1, max = 100}})
	self:NetworkVar("Bool", 0, "On", {KeyName = "On", Edit = {type = "Bool", order = 5}})

	if SERVER then return end

	-- runs per client FleX frame, this may be different per client.
	-- more particles might be spawned depending on the client, but this setup allows for laminar flow, which I think looks better
	-- The alternative is running a gwater2.AddCylinder in a serverside Think hook, however with that setup different clients may see different results
	hook.Add("gwater2_tick_particles", self, function()
		if !self:GetOn() then return end

		local particle_radius = gwater2.solver:GetParameter("radius")
		local radius = self:GetRadius()
		local spread = self:GetSpread()
		local strength = self:GetStrength()

		local mat = Matrix()
		mat:SetScale(Vector(spread, spread, spread))
		mat:SetAngles(self:GetAngles())
		--mat:SetAngles(self:LocalToWorldAngles(Angle(0, CurTime() * 200, 0)))
		mat:SetTranslation(self:GetPos() + self:GetUp() * (6 + particle_radius) * math.Rand(0.999, 1))
	 
		local lifetime = self:GetLifetime()
		if lifetime <= 0 then lifetime = nil end

		gwater2.solver:AddCylinder(mat, Vector(radius, radius, 1), {vel = self:GetUp() * strength, lifetime = lifetime})
	end)
end

function ENT:Draw()
	self:DrawModel()

	local pos, ang = self:GetPos(), self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), 180)
	pos = pos + ang:Up()*7

	cam.Start3D2D(pos, ang, 0.1)
		draw.DrawText("Emitter", "DermaDefault", 0, -72, color_white, TEXT_ALIGN_CENTER)

		draw.DrawText(language.GetPhrase("gwater2.ent.emitter.side"), "DermaLarge", 0, -24, color_white, TEXT_ALIGN_CENTER)

		draw.DrawText(string.format(
			language.GetPhrase("gwater2.ent."..(self:GetOn() and "on" or "off")).."  "..
			language.GetPhrase("gwater2.ent.strength").."  "..
			language.GetPhrase("gwater2.ent.radius").."  "..
			language.GetPhrase("gwater2.ent.spread").."  "..
			language.GetPhrase("gwater2.ent.lifetime"),
			self:GetStrength() or "?", self:GetRadius() or "?", self:GetSpread() or "?", self:GetLifetime() or "?"
		), "DermaDefault", 0, 96, color_white, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end
