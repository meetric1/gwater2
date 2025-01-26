--if CLIENT then return end

local GWATER2_PARTICLES_TO_SWIM = 40

-- swim code provided by kodya (with permission)
local gravity_convar = GetConVar("sv_gravity")
local function in_water(ply) 
	if gwater2.parameters.player_interaction == false then return false end
	if ply:OnGround() then return false end
	return ply:GetNW2Int("GWATER2_CONTACTS", 0) >= GWATER2_PARTICLES_TO_SWIM
end

hook.Add("CalcMainActivity", "gwater2_swimming", function(ply)
	if not in_water(ply) or ply:InVehicle() then return end
	return ACT_MP_SWIM, -1
end)

local function do_swim(ply, move)
	if not in_water(ply) then return end

	local vel = move:GetVelocity()
	local ang = move:GetMoveAngles()

	local acel =
	(ang:Forward() * move:GetForwardSpeed()) +
	(ang:Right() * move:GetSideSpeed()) +
	(ang:Up() * move:GetUpSpeed())

	local aceldir = acel:GetNormalized()
	local acelspeed = math.min(acel:Length(), ply:GetMaxSpeed())
	acel = aceldir * acelspeed * (gwater2.parameters["swimspeed"] or 2)

	if bit.band(move:GetButtons(), IN_JUMP) ~= 0 then
		acel.z = acel.z + ply:GetMaxSpeed()
	end

	vel = vel + acel * FrameTime()
	vel = vel * (1 - FrameTime() * 2)

	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * (gwater2.parameters["swimbuoyancy"] or 0.49)
	vel.z = vel.z + FrameTime() * gravity

	move:SetVelocity(vel * (1 - (gwater2.parameters.swimfriction or 0)))
end

local function do_multiply(ply)
	if ply:GetNW2Int("GWATER2_CONTACTS", 0) < (gwater2.parameters["multiplyparticles"] or 60) then
		if not ply.GWATER2_MULTIPLIED then return end
		ply:SetWalkSpeed(ply.GWATER2_MULTIPLIED[1])
		ply:SetRunSpeed(ply.GWATER2_MULTIPLIED[2])
		ply:SetJumpPower(ply.GWATER2_MULTIPLIED[3])
		ply.GWATER2_MULTIPLIED = nil
		return
	end
	if ply.GWATER2_MULTIPLIED then return end
	ply.GWATER2_MULTIPLIED = {ply:GetWalkSpeed(), ply:GetRunSpeed(), ply:GetJumpPower()}
	ply:SetWalkSpeed(ply.GWATER2_MULTIPLIED[1] * (gwater2.parameters["multiplywalk"] or 1))
	ply:SetRunSpeed(ply.GWATER2_MULTIPLIED[2] * (gwater2.parameters["multiplywalk"] or 1))
	ply:SetJumpPower(ply.GWATER2_MULTIPLIED[3] * (gwater2.parameters["multiplyjump"] or 1))
end

-- serverside ONLY
local function do_damage(ply)	
	if (gwater2.parameters.touchdamage or 0) == 0 then return end
	if ply:GetNW2Int("GWATER2_CONTACTS", 0) < (gwater2.parameters["multiplyparticles"] or 60) then return end

	if gwater2.parameters.touchdamage > 0 then
		ply:TakeDamage(gwater2.parameters.touchdamage)
	else
		ply:SetHealth(math.min(ply:GetMaxHealth(), ply:Health() + -gwater2.parameters["touchdamage"]))
	end
end

hook.Add("Move", "gwater2_swimming", function(ply, move)
	if gwater2.parameters.player_interaction == false then return end

	if SERVER then
		ply:SetNW2Int("GWATER2_CONTACTS", ply.GWATER2_CONTACTS or 0)
	end

	do_swim(ply, move)
	do_multiply(ply)

	if SERVER then
		do_damage(ply)
	end
end)

hook.Add("FinishMove", "gwater2_swimming", function(ply, move)
	if not in_water(ply) then return end
	local vel = move:GetVelocity()
	local pgrav = ply:GetGravity() == 0 and 1 or ply:GetGravity()
	local gravity = pgrav * gravity_convar:GetFloat() * 0.5

	vel.z = vel.z + FrameTime() * gravity
	move:SetVelocity(vel)
end)

-- cancel fall damage when in water
hook.Add("GetFallDamage", "gwater2_swimming", function(ply, speed)
	if ply:GetNW2Int("GWATER2_CONTACTS", 0) < GWATER2_PARTICLES_TO_SWIM then return end

	ply:EmitSound("Physics.WaterSplash")
	return 0
end)

if SERVER then
	-- explosions caused by props, rpg rockets, etc
	hook.Add("OnEntityCreated", "gwater2_explosion", function(ent)
		if !IsValid(ent) or ent:GetClass() ~= "env_explosion" then return end

		timer.Simple(0, function()	-- wait for datatables to be set up
			if !IsValid(ent) then return end

			gwater2.AddForceField(ent:GetPos(), 250, 150, 1, true)
		end)
	end)

	-- Best I could do for grenade detection. has a few problems:
		-- does not detect instantly, can be a couple ticks behind
		-- grenades that get exploded by other grenades (chain grenade explosions) are not detected
	hook.Add("EntityRemoved", "gwater2_explosion", function(ent)
		if !IsValid(ent) or ent:GetClass() ~= "npc_grenade_frag" then return end

		-- the grenade will explode (and is not just being removed with remover tool)
		if ent:GetInternalVariable("m_flDetonateTime") ~= -CurTime() then	
			gwater2.AddForceField(ent:GetPos(), 250, 100, 1, true)
		end
	end)

	-- gravity gun pickup code moved to "entities/gwater2_pickup.lua"
end

return in_water