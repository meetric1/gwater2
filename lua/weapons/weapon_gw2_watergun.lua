SWEP.PrintName = "Water Gun"
    
SWEP.Author = "Meetric" 
SWEP.Purpose = "Water Gun"
SWEP.Instructions = "Left Click to spawn water. Right click to spawn BIG water. Reload to reset"
SWEP.Category = "GWater2" 
SWEP.DrawAmmo       = true
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = true

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Weight = 1
SWEP.WepSelectIcon = CLIENT and surface.GetTextureID("entities/weapon_gw2_watergun_icon")

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = 0
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "Pistol"	-- needs to be something to show ammo
SWEP.Primary.Delay = 0

SWEP.Base = "weapon_base"

SWEP.Secondary.ClipSize      = -1
SWEP.Secondary.DefaultClip   = 0
SWEP.Secondary.Automatic     = false
SWEP.Secondary.Ammo          = "none"
SWEP.Secondary.Delay = 0

SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 70
SWEP.ViewModel			= "models/gwater2/water_gun.mdl" 
SWEP.WorldModel			= "models/weapons/w_pistol.mdl"
SWEP.UseHands           = true

local cardinal = {
	Vector(1, 0, 0),
	Vector(-1, 0, 0),
	Vector(0, 1, 0),
	Vector(0, -1, 0),
	Vector(0, 0, 1),
	Vector(0, 0, -1)
}

local function vector_abs(v)
	local abs = math.abs
	return Vector(abs(v[1]), abs(v[2]), abs(v[3]))
end

-- extrudes position from ground
local function trace_extrude(ply, size, extrude)

	local radius = gwater2.parameters.radius or 10
	local scale = radius * size * (gwater2.parameters.fluid_rest_distance or 0.65)
	local initial_trace = util.TraceLine({
		start = ply:EyePos(),
		endpos = ply:EyePos() + ply:EyeAngles():Right() * 20 - ply:EyeAngles():Up() * 8 + ply:GetAimVector() * 10 * math.max(extrude or radius, 5),
		filter = ply,
	})
	
	local end_pos = initial_trace.HitPos + initial_trace.HitNormal
	
	for i = 1, 6 do
		local direction = cardinal[i]--Vector(0, 0, -1)
		local area = (Vector(1, 1, 1) - vector_abs(direction)) * scale
		local trace_data = {
			start = end_pos,
			endpos = end_pos + direction * scale,
			mins = -area,
			maxs = area,
			filter = ply
		}

		local trace = util.TraceHull(trace_data)
		if trace.StartSolid then trace = util.TraceLine(trace_data) end

		if !trace.StartSolid and trace.Hit then
			end_pos = end_pos - (0.999 - trace.Fraction) * direction * scale
		end
	end

	return end_pos
end

function SWEP:PrimaryAttack()
	if CLIENT then return end
	
	local owner = self:GetOwner()
	local radius = gwater2.parameters.radius or 10
	local pos = trace_extrude(owner, 4) + VectorRand(-1, 1)

	gwater2.AddSphere(gwater2.quick_matrix(pos), 4, {vel = owner:EyeAngles():Forward() * math.max(radius, 5) + owner:GetVelocity() * FrameTime()})
	self:SetNextPrimaryFire(CurTime() + 1 / 13)
	owner:EmitSound("Water.ImpactSoft")
end

function SWEP:Reload()
	if CLIENT then return end

	gwater2.ResetSolver()
end

function SWEP:SecondaryAttack()
	if CLIENT then return end

	local owner = self:GetOwner()
	local radius = gwater2.parameters.radius or 10
	local pos = trace_extrude(owner, 20, 2.5 * radius) + VectorRand(-1, 1)

	gwater2.AddSphere(gwater2.quick_matrix(pos), 20, {vel = owner:EyeAngles():Forward() * math.Clamp(gwater2.parameters.radius or 10, 5, 10)})
	owner:EmitSound("NPC_CombineGunship.CannonStartSound")
	self:SetNextSecondaryFire(CurTime() + 1 / 4)
end

if SERVER then return end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
function SWEP:PostDrawViewModel(vm, weapon, ply)
	if !gwater2 then 
		cam.Start2D()
			local a = 255*(math.sin(CurTime()*2)+1)/2
			draw.DrawText(language.GetPhrase("gwater2.gun.adv.notloaded"), "Trebuchet24", ScrW() / 2 + 1, ScrH() / 2 - 36 + 1, Color(0, 0, 0, a), TEXT_ALIGN_CENTER)
			draw.DrawText(language.GetPhrase("gwater2.gun.adv.notloaded"), "Trebuchet24", ScrW() / 2, ScrH() / 2 - 36, Color(255, 0, 0, a), TEXT_ALIGN_CENTER)
		cam.End2D()

		return 
	end

	self.Weapon:SetClip1(gwater2.solver:GetMaxParticles() - gwater2.solver:GetActiveParticles())
end