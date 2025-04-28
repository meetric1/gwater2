AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category = "GWater2"
ENT.PrintName = "Transporter"
ENT.Author = "googer_"
ENT.Purpose = ""
ENT.Instructions = ""
ENT.Spawnable = true
ENT.Editable = true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "RadiusX", { KeyName = "RadiusX", Edit = { type = "Int", order = 0, min = 1, max = 20 } })
	self:NetworkVar("Int", 1, "RadiusY", { KeyName = "RadiusY", Edit = { type = "Int", order = 1, min = 1, max = 20 } })
	self:NetworkVar(
		"Float",
		0,
		"Strength",
		{ KeyName = "Strength", Edit = { type = "Float", order = 2, min = 1, max = 100 } }
	)
	self:NetworkVar("Bool", 0, "On", { KeyName = "On", Edit = { type = "Bool", order = 3 } })

	if SERVER then
		return
	end

	hook.Add("gwater2_tick_particles", self, function()
		self.link = self.link or IsValid(self:GetNWEntity("GWATER2_Link")) and self:GetNWEntity("GWATER2_Link")
		if not self:GetOn() then
			return
		end
		if not self.link then
			return
		end

		local particle_radius = gwater2.solver:GetParameter("radius")
		local half_particle_radius = particle_radius / 2
		local radiusx, radiusy = self:GetRadiusX(), self:GetRadiusY()
		local strength = self:GetStrength()

		local offset
		local center = self:GetPos() + self:GetUp() * (6 + particle_radius)
		for y = -radiusy, radiusy do
			if not self.link.GWATER2_particles_drained or self.link.GWATER2_particles_drained <= 0 then
				break
			end
			for x = -radiusx, radiusx do
				if (x * x) + (y * y) >= (radiusx * radiusy) then
					continue
				end
				offset = self:GetForward() * x * half_particle_radius + self:GetRight() * y * half_particle_radius
				gwater2.solver:AddParticle(center + offset, { vel = self:GetUp() * strength })
				self.link.GWATER2_particles_drained = self.link.GWATER2_particles_drained - 1
				if self.link.GWATER2_particles_drained <= 0 then
					break
				end
			end
		end
	end)
end

-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Active" then
		return self:SetOn(val > 0)
	end
	if name == "RadiusX" then
		return self:SetRadiusX(math.max(1, math.min(20, val)))
	end
	if name == "RadiusY" then
		return self:SetRadiusY(math.max(1, math.min(20, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(1, math.min(100, val)))
	end
end

function ENT:Initialize()
	if CLIENT then
		return
	end

	self:SetModel("models/mechanics/wheels/wheel_speed_72.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Active",
			"RadiusX",
			"RadiusY",
			"Strength",
		})
	end
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then
		return
	end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:Spawn()
	ent:Activate()

	ent:SetRadiusX(6)
	ent:SetRadiusY(6)
	ent:SetStrength(10)
	ent:SetOn(true)
	--ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:SetMaterial("phoenix_storms/gear")

	local ent2 = ents.Create("gwater2_transporter_send")
	ent2:SetPos(tr.HitPos + vector_up * 50)
	ent2:Spawn()
	ent2:Activate()
	ent2:SetRadius(20)
	ent2:SetStrength(100)
	ent2:SetCollisionGroup(COLLISION_GROUP_WORLD)
	hook.Run("PlayerSpawnedSENT", ply, ent2)
	ent.link = ent2
	ent2.link = ent
	ent:SetNWEntity("GWATER2_Link", ent2)
	ent2:SetNWEntity("GWATER2_Link", ent)

	return ent
end

function ENT:OnRemove()
	if not SERVER then
		return
	end
	if not IsValid(self.link) then
		return
	end
	self.link:Remove()
end

function ENT:Use(_, _, type)
	self:SetOn(not self:GetOn())
end

function ENT:Draw()
	self:DrawModel()

	self.link = self.link or IsValid(self:GetNWEntity("GWATER2_Link")) and self:GetNWEntity("GWATER2_Link")

	local pos, ang = self:GetPos(), self:GetAngles()
	ang:RotateAroundAxis(ang:Up(), 180)
	pos = pos + ang:Up() * 7

	cam.Start3D2D(pos, ang, 0.1)
	draw.DrawText("Transporter Exit", "DermaDefault", 0, -72, color_white, TEXT_ALIGN_CENTER)

	draw.DrawText("[" .. self:EntIndex() .. "]", "DermaDefault", 0, -48, color_white, TEXT_ALIGN_CENTER)

	--draw.RoundedBox(0, -150, -150, 300, 300, Color(0, 0, 0))
	draw.DrawText(language.GetPhrase("gwater2.ent.emitter.side"), "DermaLarge", 0, -24, color_white, TEXT_ALIGN_CENTER)

	if IsValid(self.link) then
		draw.DrawText(
			string.format(language.GetPhrase("gwater2.ent.transporter.link"), "[" .. self.link:EntIndex() .. "]"),
			"DermaDefault",
			0,
			48,
			color_white,
			TEXT_ALIGN_CENTER
		)

		draw.DrawText(
			string.format(language.GetPhrase("gwater2.ent.transporter.queue"), self.link.GWATER2_particles_drained),
			"DermaDefault",
			0,
			72,
			color_white,
			TEXT_ALIGN_CENTER
		)
	end

	draw.DrawText(
		string.format(
			language.GetPhrase("gwater2.ent." .. (self:GetOn() and "on" or "off"))
				.. "  "
				.. language.GetPhrase("gwater2.ent.strength")
				.. "  "
				.. language.GetPhrase("gwater2.ent.radius2"),
			self:GetStrength() or "?",
			self:GetRadiusX() or "?",
			self:GetRadiusY() or "?"
		),
		"DermaDefault",
		0,
		96,
		color_white,
		TEXT_ALIGN_CENTER
	)
	cam.End3D2D()
end
