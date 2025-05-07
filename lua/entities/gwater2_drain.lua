AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "GWater2"
ENT.PrintName    = "Drain"
ENT.Author       = "Meetric"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = true
ENT.Editable	 = true

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Radius", {KeyName = "Radius", Edit = {type = "Float", order = 0, min = 0, max = 100}})
	self:NetworkVar("Float", 1, "Strength", {KeyName = "Strength", Edit = {type = "Float", order = 1, min = 0, max = 200}})

	if SERVER then return end

	hook.Add("gwater2_tick_drains", self, function()
		gwater2.solver:AddForceField(self:GetPos(), self:GetRadius(), -self:GetStrength(), 0, true)

		local removed = gwater2.solver:RemoveSphere(gwater2.quick_matrix(self:GetPos(), nil, self:GetRadius()))
		if removed > 0 then
			self:EmitSound("player/footsteps/slosh" .. math.random(1,4) .. ".wav", 60)
		end
	end)
end

function ENT:Initialize()
	if CLIENT then return end
	self:SetModel("models/xqm/button3.mdl")
	self:SetMaterial("phoenix_storms/dome")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)

	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Radius",
			"Strength"
		})
	end
end

-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Radius" then
		return self:SetRadius(math.max(0, math.min(100, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(0, math.min(200, val)))
	end
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:Spawn()
	ent:Activate()

	ent:SetRadius(20)
	ent:SetStrength(100)
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)

	return ent
end

function ENT:Draw()
	self:DrawModel()
	local pos, ang = self:GetPos(), self:GetAngles()
	ang:RotateAroundAxis(ang:Right(), 180)
	pos = pos + ang:Up()*0.25
	cam.Start3D2D(pos, ang, 0.05)
		draw.DrawText("Drain", "DermaDefault", 0, -72, color_white, TEXT_ALIGN_CENTER)
		draw.DrawText(language.GetPhrase("gwater2.ent.drain.side"), "DermaLarge", 0, -24, color_white, TEXT_ALIGN_CENTER)
		draw.DrawText(string.format(
			language.GetPhrase("gwater2.ent.strength").."  "..
			language.GetPhrase("gwater2.ent.radius"), self:GetStrength() or "?", self:GetRadius() or "?"
		), "DermaDefault", 0, 96, color_white, TEXT_ALIGN_CENTER)
	cam.End3D2D()
end