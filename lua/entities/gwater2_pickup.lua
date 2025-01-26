---@diagnostic disable: undefined-field, duplicate-set-field, undefined-global
AddCSLuaFile()

ENT.Type = "anim"
ENT.Base = "base_anim"

ENT.Category     = "GWater2"
ENT.PrintName    = "gravgun_pickup"
ENT.Author       = "Meetric"
ENT.Purpose      = ""
ENT.Instructions = ""
ENT.Spawnable    = false

-- This file includes multiplayer gravgun support for gwater2
-- this is done via a black hole esque entity which is teleported in front of the players eyes

function ENT:SetupDataTables()

	if SERVER then return end

	hook.Add("gwater2_tick_drains", self, function()
		gwater2.solver:AddForceField(self:GetPos(), 150, -150, 0, true)
	end)
end

if CLIENT then 
	function ENT:Draw()
		self:SetNoDraw(true)
	end

	return 
end

--- SERVER ---

local function is_valid_pickup(ply, key)
	if !IsValid(ply) then 
		return false 
	end

	if !ply:KeyDown(key or IN_ATTACK2) then 
		return false 
	end

	local weapon = ply:GetActiveWeapon()
	return IsValid(weapon) and weapon:GetClass() == "weapon_physcannon"
end

function ENT:UpdatePosition()
	local owner = self.GWATER2_PARENT
	self:SetPos(owner:EyePos() + owner:GetAimVector() * 170)
end

function ENT:Initialize()
	self:SetModel("models/maxofs2d/hover_basic.mdl")
	self:SetNotSolid(true)
	self:SetMoveType(MOVETYPE_NONE)
end

function ENT:Think()
	local owner = self.GWATER2_PARENT
	if !is_valid_pickup(owner) then 
		self:Remove()
		return
	end

	self:UpdatePosition()
	self:NextThink(CurTime())
	return true
end

hook.Add("KeyPress", "gwater2_gravgun", function(ply, key)
	if !IsValid(ply.GWATER2_PARENT) and is_valid_pickup(ply) then
		local force_field = ents.Create("gwater2_pickup")
		---@diagnostic disable-next-line: inject-field
		force_field.GWATER2_PARENT = ply
		ply.GWATER2_PARENT = force_field
		force_field:UpdatePosition()
		force_field:DrawShadow(false)
		force_field:Spawn()
	end
end)

hook.Add("Tick", "gwater2_gravgun", function()
	for _, ply in player.Iterator() do
		if is_valid_pickup(ply, IN_ATTACK) and (ply.GWATER2_PUNT or 0) < ply:GetActiveWeapon():GetNextPrimaryFire() then
			ply.GWATER2_PUNT = ply:GetActiveWeapon():GetNextPrimaryFire()
			gwater2.AddForceField(ply:EyePos(), 320, 200, 1, false)
		end
	end
end)