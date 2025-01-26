---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     	= "GWater2"
ENT.PrintName    	= "Transmuter"
ENT.Author       	= "Meetric"
ENT.Purpose      	= "Turns objects into water"
ENT.Instructions 	= "Touch it"
ENT.Spawnable    	= true
ENT.AdminOnly 	 	= true
ENT.RenderGroup 	= RENDERGROUP_OPAQUE	-- make sure water sees this object
ENT.GWATER2_TOUCHED = true

if CLIENT then return end
function ENT:SetupDataTables()
	self:NetworkVar("Bool", 0, "On", {KeyName = "On", Edit = {type = "Bool", order = 0}})
	if CLIENT then return end
	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Active"})
	end
end

-- wiremod integration
function ENT:TriggerInput(name, val)
	if name == "Active" then
		return self:SetOn(val > 0)
	end
end

function ENT:UpdateMaterial()
	self:SetSubMaterial(1, self:GetOn() and "models/alyx/emptool_glow" or "Models/effects/vol_light001")
end

function ENT:Initialize()
	self:SetModel("models/props_phx/construct/plastic/plastic_panel2x2.mdl")
	self:UpdateMaterial()
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:DrawShadow(false)
	self:SetUseType(SIMPLE_USE)
	self:SetTrigger(true)

	util.PrecacheModel("models/props_c17/oildrum001.mdl")
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos)
	ent:SetOn(true)
	ent:Spawn()
	ent:Activate()

	return ent
end

function ENT:StartTouch(ent)
	if !self:GetOn() or ent.GWATER2_TOUCHED or !self:GetTouchTrace().Hit then return end

	if ent:IsPlayer() then
		if ent:Alive() then
			ent:KillSilent()
			gwater2.AddModel(gwater2.quick_matrix(ent:GetPos(), nil, Vector(1, 1, 1.5)), "models/props_c17/oildrum001.mdl", {vel = ent:GetVelocity() * FrameTime()})
		end

		return
	end

	local phys = ent:GetPhysicsObject()
	if !IsValid(phys) then return end

	local extra = {
		ent_vel = phys:GetVelocity() * FrameTime(),
		ent_angvel = phys:GetAngleVelocity() * FrameTime()
	}
	local model = ent:GetModel()
	local transform = gwater2.quick_matrix(phys:GetPos(), phys:GetAngles())

	phys:EnableMotion(false)
	ent:SetNotSolid(true)
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	---@diagnostic disable-next-line: inject-field
	ent.GWATER2_TOUCHED = true
	--ent:Remove()

	-- net is too fast and can cause water to explode sometimes
	timer.Simple(0.0, function()
		gwater2.AddModel(transform, model, extra)
		SafeRemoveEntity(ent)
	end)
end

ENT.Touch = ENT.StartTouch

function ENT:Use(_, _, type)
	self:SetOn(!self:GetOn())
	self:UpdateMaterial()
end
