---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Base			= "base_gmodentity"
ENT.Type 			= "anim"

ENT.Category		= "GWater2"
ENT.PrintName		= "Shower Head"
ENT.Author			= "AndrewEathan"
ENT.Purpose			= "Functional GWater showerhead!"
ENT.Instructions	= ""
ENT.Editable		= true
ENT.Spawnable 		= true

function ENT:SetupDataTables()
	self:NetworkVar("Int", 0, "Density", {KeyName = "Density", Edit = {type = "Int", order = 0, min = 1, max = 20}})
	self:NetworkVar("Float", 0, "Lifetime", {KeyName = "Lifetime", Edit = {type = "Float", order = 1, min = 0, max = 100}})
	self:NetworkVar("Float", 1, "Strength", {KeyName = "Strength", Edit = {type = "Float", order = 2, min = 1, max = 10}})
	self:NetworkVar("Bool", 0, "On", {KeyName = "On", Edit = {type = "Bool", order = 3}})
end

function ENT:Initialize()
	if CLIENT then return end
	
	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Active",
			"Density",
			"Strength",
			"Lifetime"
		})
	end
	
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end

	local ent = ents.Create(class)
	ent:SetModel("models/props_wasteland/prison_lamp001a.mdl")
	ent:SetSkin(1)
	ent:PhysicsInit(SOLID_VPHYSICS)
	ent:SetMoveType(MOVETYPE_VPHYSICS)
	ent:SetSolid(SOLID_VPHYSICS)
	ent:SetUseType(SIMPLE_USE)
	ent:SetPos(tr.HitPos + tr.HitNormal * 10)
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:Spawn()
	ent:SetOn(false)
	ent:SetDensity(1)
	ent:SetStrength(1)
	ent:SetLifetime(0)

	return ent
end

-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Active" then
		return self:SetOn(val > 0)
	end
	if name == "Density" then
		return self:SetDensity(math.max(1, math.min(20, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(1, math.min(10, val)))
	end
	if name == "Lifetime" then
		return self:SetLifetime(math.max(0, math.min(100, val)))
	end
end

function ENT:Use(_, _, type)
	self:EmitSound("buttons/lever1.wav")
	self:SetOn(not self:GetOn())
end

if SERVER then return end

function ENT:Think()
	if !gwater2 then return end
	
	if self:GetOn() then
		local pos = self:LocalToWorld(Vector(0, 0, -20))
		local vel = self:GetVelocity() * FrameTime()
		local ppe = self:GetDensity()
		local fmul = self:GetStrength()
		local lifetime = self:GetLifetime()
		if lifetime <= 0 then lifetime = nil end

		for i = 0, ppe do
			gwater2.solver:AddParticle(
				pos + VectorRand(-10 + ppe, 10 - ppe), 
				{vel = self:GetUp() * -5 * fmul + vel, lifetime = lifetime})
		end
	end
	
	self:SetNextClientThink(CurTime() + 0.06)
end