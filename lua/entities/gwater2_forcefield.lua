---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Forcefield"
ENT.Author			= "Meetric / Jn"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable   	= true
ENT.Editable		= true

function ENT:Initialize()
	if CLIENT then return end

    self:SetModel("models/hunter/blocks/cube05x05x05.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
end

if CLIENT then
	function ENT:Draw()
		render.DrawWireframeBox(self:GetPos(), Angle(0, 0, 0), -Vector(12,12,12), Vector(12,12,12), Color(0, 255, 0), true)

		render.DrawWireframeSphere(self:GetPos(), self:GetRadius(), 15, 15, Color(0, 255, 0), true)
	end
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos + Vector(0, 5, 0))
	ent:Spawn()
	ent:Activate()

    ent:SetRadius(1000)
    ent:SetStrength(50)
    ent:SetMode(0)
    ent:SetLinear(1)
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)

	return ent
end

function ENT:SetupDataTables()
    self:NetworkVar("Float", 0, "Radius", {KeyName = "Radius", Edit = {type = "Float", order = 0, min = 0, max = 2000}})
	self:NetworkVar("Float", 1, "Strength", {KeyName = "Strength", Edit = {type = "Float", order = 1, min = -200, max = 200}})
	self:NetworkVar("Bool", 0, "Linear", {KeyName = "Linear", Edit = {type = "Bool", order = 2}})
	self:NetworkVar("Int", 0, "Mode", {KeyName = "Force Mode", Edit = {type = "Int", order = 3, min = 0, max = 2}})

	if SERVER then
		-- wiremod integration
		if WireLib ~= nil then
			WireLib.CreateInputs(self, {
				"Radius",
				"Strength",
				"Linear",
				"Mode"})
		end
		return
	end

	hook.Add("gwater2_tick_drains", self, function()
		gwater2.solver:AddForceField(self:GetPos(), self:GetRadius(), -self:GetStrength(), self:GetMode(), self:GetLinear())
	end)
end
-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Radius" then
		return self:SetRadius(math.max(0, math.min(2000, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(-200, math.min(200, val)))
	end
	if name == "Linear" then
		return self:SetLinear(val > 0)
	end
	if name == "Mode" then
		return self:SetMode(math.max(0, math.min(2, val)))
	end
end