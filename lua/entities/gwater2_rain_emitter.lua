---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.Category		= "GWater2"
ENT.PrintName		= "Rain Emitter"
ENT.Author			= "Meetric / googer_"
ENT.Purpose			= ""
ENT.Instructions	= ""
ENT.Spawnable   	= true
ENT.Editable		= true
ENT.RenderGroup 	= RENDERGROUP_TRANSLUCENT

function ENT:Initialize()
	if CLIENT then return end

	self:SetModel("models/hunter/plates/plate16x16.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)

	-- wiremod integration
	if WireLib ~= nil then
		WireLib.CreateInputs(self, {
			"Active",
			"Density",
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
	if name == "Density" then
		return self:SetDensity(math.max(1, math.min(200, val)))
	end
	if name == "Strength" then
		return self:SetStrength(math.max(1, math.min(100, val)))
	end
	if name == "Lifetime" then
		return self:SetLifetime(math.max(0, math.min(100, val)))
	end
end

function ENT:SpawnFunction(ply, tr, class)
	if not tr.Hit then return end
	local ent = ents.Create(class)
	ent:SetPos(tr.HitPos + tr.HitNormal * 300)
	ent:Spawn()
	ent:Activate()

	ent:SetDensity(10)
	ent:SetStrength(1)
	ent:SetLifetime(0)
	ent:SetOn(true)
	ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
	ent:DrawShadow(false)

	return ent
end

function ENT:Use(_, _, type)
	self:EmitSound("buttons/lever1.wav")
	self:SetOn(not self:GetOn())
end

function ENT:SetupDataTables()
	self:NetworkVar("Int", 1, "Density", {KeyName = "Density", Edit = {type = "Int", order = 1, min = 1, max = 200}})
	self:NetworkVar("Float", 0, "Lifetime", {KeyName = "Lifetime", Edit = {type = "Float", order = 2, min = 0, max = 100}})
	self:NetworkVar("Float", 1, "Strength", {KeyName = "Strength", Edit = {type = "Float", order = 3, min = 1, max = 100}})
	self:NetworkVar("Bool", 0, "On", {KeyName = "On", Edit = {type = "Bool", order = 4}})

	if SERVER then return end

	local function vector_rand_range(v1, v2)
		return Vector(math.Rand(v1[1], v2[1]), math.Rand(v1[2], v2[2]), math.Rand(v1[3], v2[3]))
	end

	hook.Add("gwater2_tick_particles", self, function()
		if !self:GetOn() then return end

		local lifetime = self:GetLifetime()
		if lifetime <= 0 then lifetime = nil end

		for i = 1, self:GetDensity() do
			gwater2.solver:AddParticle(
				self:LocalToWorld(self:OBBCenter() + vector_rand_range(self:OBBMins(), self:OBBMaxs())), 
				{vel = -self:GetUp() * self:GetStrength(), lifetime = lifetime}
			)
		end
	end)
end

local function render_easyquad(pos, ang, sizex, sizey, winding)
	local p0 = ang:Forward() *  sizex
	local p1 = ang:Forward() * -sizex
	local p2 = ang:Right() 	 *  sizey
	local p3 = ang:Right() 	 * -sizey

	if winding then
		render.DrawQuad(
			pos + p0 + p2,
			pos + p0 + p3, 
			pos + p1 + p3, 
			pos + p1 + p2
		)
	else
		render.DrawQuad(
			pos + p1 + p3, 
			pos + p0 + p3, 
			pos + p0 + p2, 
			pos + p1 + p2
		)
	end
end

-- 3d parallax effect
local function unfuck_lighting(pos0, pos1)
	render.OverrideColorWriteEnable(true, false)
	render.OverrideDepthEnable(true, false)
	render.Model({model = "models/shadertest/vertexlit.mdl",pos = pos0, angle = EyeAngles()}) 	-- lighting
	render.OverrideDepthEnable(false, false)
	render.OverrideColorWriteEnable(false, false)
end

local cloud = Material("gwater2/clouds")
function ENT:Draw()
	if halo.RenderedEntity() == self then 
		self:DrawModel() 
		return
	end

	unfuck_lighting(self:GetPos())
	render.SetMaterial(cloud)

	local color = self:GetColor()
	cloud:SetVector4D("$color2", color.r / 255, color.g / 255, color.b / 255, 255)

	local obb = self:OBBMaxs()
	local width = obb[1]
	local length = obb[2]
	local height = obb[3]

	-- top
	for i = 0, 9 do
		cloud:SetInt("$frame", i)	-- slice of volume texture
		render_easyquad(self:GetPos() + self:GetUp() * i * height, self:GetAngles(), width, length)
	end

	-- bottom
	
	for i = 0, 9 do
		cloud:SetInt("$frame",  9 - i)
		render_easyquad(self:GetPos() + self:GetUp() * (9 - i) * height, self:GetAngles(), width, length, true)
	end
end