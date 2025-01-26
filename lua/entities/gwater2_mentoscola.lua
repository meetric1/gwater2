---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"

ENT.Category		= "GWater2"
ENT.PrintName		= "Mentos with Cola"
ENT.Author			= "AndrewEathan"
ENT.Purpose			= "OH NO"
ENT.AdminOnly		= false
ENT.Instructions	= ""
ENT.Spawnable 		= true
ENT.Editable 		= true

function ENT:SetupDataTables()
	self:NetworkVar("Float", 0, "Strength",	{ KeyName = "Strength",	Edit = {type = "Float", order = 1, min = 0, max = 60}})
	self:NetworkVar("Float", 1, "DieTime",	{ KeyName = "DieTime",	Edit = {type = "Float", order = 2, min = 1, max = 20}})
end

if CLIENT then return end
-- SERVER

function ENT:Initialize()
	if WireLib then
		WireLib.CreateOutputs(self, {"Active"})
	end
	
	self.ACTIVATED = false
	self.FLOW_SOUND = CreateSound(self, "PhysicsCannister.ThrusterLoop")
	self:SetModel("models/props_junk/garbage_glassbottle003a.mdl")
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end

	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos + tr.HitNormal * 10)
	ent:Spawn()
	ent:Activate()
	
	ent:SetStrength(1)
	ent:SetDieTime(6)

	return ent
end

function ENT:Use()
	if self.ACTIVATED or self.START_TIME then return end

	self.ACTIVATED = true
	self:EmitSound("gwater2/soda_launch.wav")
	
	timer.Simple(1, function()
		if !IsValid(self) then return end

		self.START_TIME = CurTime()

		self.FLOW_SOUND:Play()
		self.FLOW_SOUND:ChangeVolume(1)
	end)
end

function ENT:TriggerInput(name, value)
	if name == "Active" and value > 0 then
		self:Use(self)
	end
end


function ENT:OnRemove()
	self.FLOW_SOUND:Stop()
end

function ENT:Think()
	self:NextThink(CurTime() + 0.03)

	if !self.ACTIVATED or !self.START_TIME then return end
	
	if self.START_TIME and CurTime() > self.START_TIME + self:GetDieTime() then
		self.START_TIME = nil
		self.ACTIVATED = false
		self.FLOW_SOUND:Stop()
		return true
	end

	local phys = self:GetPhysicsObject()
	if !IsValid(phys) then return end

	local pos = self:LocalToWorld(Vector(0, 0, 5))
	local ang = self:GetUp()
	local percent = 1 - (CurTime() - self.START_TIME) / self:GetDieTime()

	self.FLOW_SOUND:ChangeVolume(percent)
	util.ScreenShake(self:GetPos(), percent, 20, 1, 1000)
	phys:ApplyForceCenter(-self:GetUp() * percent * phys:GetMass() * 200 * self:GetStrength())

	--for i = 0, 20 * percent do
	--	gwater2.AddParticle(pos + VectorRand(-10, 10), {vel = VectorRand(-1, 1) * 25 * percent})
	--end
	
	for i = 0, 10 * percent do
		gwater2.AddParticle(
			self:LocalToWorld(Vector(0, 0, math.random(7, 40))), 
			{vel = ang * 10 * percent + VectorRand(-1, 1)}
		)
	end
	
	return true
end