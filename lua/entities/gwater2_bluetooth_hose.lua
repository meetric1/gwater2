---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Bluetooth Hose"
ENT.Author			= "AndrewEathan"
ENT.Purpose			= "Use it to turn it on"
ENT.Instructions	= ""
ENT.Spawnable 		= true

function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "Enabled")
end

function ENT:Initialize()
	if CLIENT then return end
	
	self:SetModel("models/props_c17/GasPipes006a.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self:SetCollisionGroup(COLLISION_GROUP_WORLD)
end

function ENT:Use()
	self:EmitSound("buttons/lever1.wav")
	self:SetEnabled(!self:GetEnabled())
end

if SERVER then return end

function ENT:Think()
	if !gwater2 then return end

	if self:GetEnabled() then
		local pos = self:LocalToWorld(Vector(-7, 0, 25))
		local ang = self:LocalToWorldAngles(Angle(180, 0, 0))
		local vel = self:GetVelocity()

		gwater2.solver:AddParticle(pos + VectorRand(-2, 2), {vel = ang:Forward() * 3 + self:GetVelocity() * FrameTime()})
	end
	
	self:SetNextClientThink(CurTime() + 0.05)
end