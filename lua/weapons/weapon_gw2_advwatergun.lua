SWEP.PrintName = "Advanced Water Gun"
    
SWEP.Author = "googer_" 
SWEP.Purpose = "shoots water"
SWEP.Instructions = "you'll figure it out"
SWEP.Category = "GWater2" 
SWEP.DrawAmmo       = false
SWEP.DrawCrosshair	= true
SWEP.DrawWeaponInfoBox = false

SWEP.Spawnable = true
SWEP.AdminOnly = false

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false
SWEP.Weight = 1

SWEP.Primary.ClipSize      = -1
SWEP.Primary.DefaultClip   = -1
SWEP.Primary.Automatic     = true
SWEP.Primary.Ammo          = "none"
SWEP.Primary.Delay = 0

SWEP.Base = "weapon_base"

SWEP.Secondary.ClipSize		= -1
SWEP.Secondary.DefaultClip	= -1
SWEP.Secondary.Automatic	= false
SWEP.Secondary.Ammo		= "none"
SWEP.Secondary.Delay = 0

SWEP.ViewModelFlip		= false
SWEP.ViewModelFOV		= 70
SWEP.ViewModel			= "models/weapons/c_pistol.mdl" 
SWEP.WorldModel			= "models/weapons/w_pistol.mdl"
SWEP.UseHands           = true

if CLIENT then
	SWEP.ParticleVelocity = CreateClientConVar("gwater2_gun_velocity",  10, true, true, "",   0,  100)
	SWEP.ParticleDistance = CreateClientConVar("gwater2_gun_distance", 250, true, true, "", 100, 1000)
	SWEP.ParticleSpread   = CreateClientConVar("gwater2_gun_spread",     1, true, true, "", 0.1,   10)

	-- 1 is cylinder (default) (introduced in 0.5b iirc)
	-- 2 is box (introduced in 0.1b)
	SWEP.SpawnMode  = CreateClientConVar("gwater2_gun_spawnmode", 1, true, true, "", 1, 2)
end

local function fuckgarry(w, s)
	if SERVER then 
		if game.SinglePlayer() then 
			w:CallOnClient(s) 
		end
		return true
	end
	return IsFirstTimePredicted()
end

function SWEP:Initialize()

end 

function SWEP:PrimaryAttack()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!

	local owner = self:GetOwner()
	local forward = owner:GetAimVector()
	
	local pos = util.QuickTrace(owner:EyePos(),
								forward * owner:GetInfoNum("gwater2_gun_distance", 250),
								owner).HitPos

	local mode = math.floor(owner:GetInfoNum("gwater2_gun_spawnmode", 1))

	pos = pos + forward * -(gwater2.parameters.radius or 10)
	pos = owner:EyePos() + (
		(pos - owner:EyePos()) *
		(gwater2.parameters.fluid_rest_distance or 0.55)
	)
    local eyeangles = owner:EyeAngles()
    local owneraddvel = owner:GetVelocity():Dot(forward) * forward / 25.4
	if mode == 1 then
		gwater2.AddCylinder(
			gwater2.quick_matrix(
				pos,
				eyeangles + Angle(90, 0, 0),
				owner:GetInfoNum("gwater2_gun_spread", 1)),
			Vector(4 * owner:GetInfoNum("gwater2_gun_spread", 1), 4 * owner:GetInfoNum("gwater2_gun_spread", 1), 1),
			{vel = forward * owner:GetInfoNum("gwater2_gun_velocity", 10) + owneraddvel}
		)
		self:SetNextPrimaryFire(CurTime() + 1/60*2)
	end
	if mode == 2 then
		local size = 4 * owner:GetInfoNum("gwater2_gun_spread", 1)
		pos = pos + owner:GetAimVector() * (gwater2.parameters.radius or 10) * (size+1)
		pos = pos + owner:GetAimVector() * -(gwater2.parameters.radius or 10) * 5
		gwater2.AddCube(
			gwater2.quick_matrix(
				pos,
				eyeangles + Angle(90, 0, 0),
				owner:GetInfoNum("gwater2_gun_spread", 1)),
				Vector(size, size, size),
				{vel = forward * owner:GetInfoNum("gwater2_gun_velocity", 10) + owneraddvel}
		)
		self:SetNextPrimaryFire(CurTime() + 1/60*size*2)
	end
    if CurTime() - (self.GWATER2_LastEmitSound or 0) > 0.1 then
        self:EmitSound("Water.ImpactSoft")
        self.GWATER2_LastEmitSound = CurTime()
    end
end

function SWEP:Reload()
	if not gwater2 then return end
	if CLIENT then return end
	if not self:GetOwner():IsPlayer() then return end -- someone gave weapon to a non-player!!

	--local owner = self:GetOwner()
	--local forward = owner:EyeAngles():Forward()
	--gwater2.AddSphere(gwater2.quick_matrix(owner:EyePos() + forward * 250), 20, {vel = forward * 10})

	gwater2.ResetSolver()
end

local frame
local create_frame
function SWEP:SecondaryAttack()
	if not gwater2 then return end
	if SERVER then
		if not IsFirstTimePredicted() then return end
		return game.SinglePlayer() and self:CallOnClient("SecondaryAttack")
	end

	if IsValid(frame) then return frame:Close() end
	frame = create_frame(self)
end

if SERVER then return end

local _util = include("menu/gwater2_util.lua")
local styling = include("menu/gwater2_styling.lua")

hook.Add("GUIMousePressed", "gwater2_gunmenuclose", function(mouse_code, aim_vector)
	if not IsValid(frame) then return end

	local x, y = gui.MouseX(), gui.MouseY()
	local frame_x, frame_y = frame:GetPos()
	if x < frame_x or x > frame_x + frame:GetWide() or y < frame_y or y > frame_y + frame:GetTall() then
		frame:Close()
	end
end)

local hovered = nil

local function make_scratch(frame, locale_parameter_name, default, min, max, decimals, convar)
    local panel = frame:Add("DPanel")
	function panel:Paint()
		if IsValid(hovered) and hovered ~= self then return end

		if self.hovered and not _util.is_hovered_any(self) then
			hovered = nil
			self.hovered = false
			self.label:SetColor(Color(255, 255, 255))
		elseif not self.hovered and _util.is_hovered_any(self) then
			hovered = self
			self.hovered = true
			self.label:SetColor(Color(187, 245, 255))
			_util.emit_sound("rollover")
		end
	end
	panel:Dock(TOP)
	local label = panel:Add("DLabel")
	label:SetText(_util.get_localised(locale_parameter_name))
	label:SetColor(Color(255, 255, 255))
	label:SetFont("GWater2Param")
	label:SetMouseInputEnabled(true)
	label:SizeToContents()
	local slider = panel:Add("DNumSlider")
    slider:SetConVar(convar)
	slider:SetDecimals(decimals)
	slider:SetMinMax(min, max)
	local button = panel:Add("DButton")
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button:SetWide(button:GetTall())
	button.Paint = nil
	panel.label = label
	panel.slider = slider
	panel.button = button
	label:Dock(LEFT)
	button:Dock(RIGHT)

	slider:SetText("")
	slider:Dock(FILL)

	-- HACKHACKHACK!!! Docking information is not set properly until after all elements are loaded
	-- I want the weird arrow editor on the text part of the slider, so we need to move and resize the slider after
	-- ..all of the docking information is loaded
	slider.Paint = function(w, h)
		local pos_x, pos_y = slider:GetPos()
		local size_x, size_y = slider:GetSize()
		
		slider:Dock(NODOCK)
		slider:SetPos(pos_x - size_x / 1.45, pos_y)	-- magic numbers. blame DNumSlider for this shit
		slider:SetSize(size_x * 1.7, size_y)

		slider.Paint = nil
	end
	
	--slider.Label:Hide()

	slider.TextArea:SizeToContents()
	function button:DoClick()
		slider:SetValue(default)
		_util.emit_sound("reset")
	end


	panel:SetTall(panel:GetTall()+2)
    return panel
end

local function make_explanation(frame, locale_string)
    local label = frame:Add("DLabel")
	label:SetText(_util.get_localised(locale_string))
	label:SetColor(Color(160, 200, 255))
	label:SetFont("GWater2Param")
    label:Dock(TOP)
    label:SetWide(frame:GetWide())
    --label:SetWrap(true)
    label:SizeToContents()
    return label
end

create_frame = function(self)
    local frame
	_util.emit_sound("select")
    -- gwater 2 main menu: steal his look!!!
    do -- so that we can collapse it
        frame = vgui.Create("DFrame")
        frame:SetSize(420, 260)
        frame:Center()
        frame:MakePopup()
        frame:SetTitle("GWater 2 " .. gwater2.VERSION .. ": Water Gun Menu")

        frame:SetScreenLock(true)
        function frame:Paint(w, h)
            -- darker background
            styling.draw_main_background(0, 0, w, h)
            styling.draw_main_background(0, 0, w, h)
            styling.draw_main_background(0, 0, w, h)
        end

        local minimize_btn = frame:GetChildren()[3]
        minimize_btn:SetVisible(false)
        local maximize_btn = frame:GetChildren()[2]
        maximize_btn:SetVisible(false)
        local close_btn = frame:GetChildren()[1]
        close_btn:SetVisible(false)

        local new_close_btn = vgui.Create("DButton", frame)
        new_close_btn:SetPos(frame:GetWide() - 20, 0)
        new_close_btn:SetSize(20, 20)
        new_close_btn:SetText("")

        function new_close_btn:DoClick()
            frame:Close()
        end

        function new_close_btn:Paint(w, h)
            if self:IsHovered() then
                surface.SetDrawColor(255, 0, 0, 127)
                surface.DrawRect(0, 0, w, h)
            end
            surface.SetDrawColor(255, 255, 255)
            surface.DrawOutlinedRect(0, 0, w, h)
            surface.DrawLine(5, 5, w - 5, h - 5)
            surface.DrawLine(w - 5, 5, 5, h - 5)
        end
    end

	local create = RealTime()
	local panel = frame:Add("DPanel")
	function panel:Paint()
		if not gwater2.options.read_config().animations then return end

		local delta = 1 - (RealTime() - create)

		local children = {}
		local function _(p)
			for __,child in pairs(p:GetChildren()) do
				children[#children+1] = child
				_(child)
			end
		end
		_(self)
		for i,v in pairs(children) do
			v:SetAlpha((1-delta-i/500)*255*4)
		end
	end
	panel:Dock(FILL)

    make_scratch(panel, "WaterGun.Velocity", 10, 0, 100, 2, "gwater2_gun_velocity")
    make_explanation(panel, "WaterGun.Velocity.Explanation")
    make_scratch(panel, "WaterGun.Distance", 250, 100, 1000, 2, "gwater2_gun_distance")
    make_explanation(panel, "WaterGun.Distance.Explanation")
    make_scratch(panel, "WaterGun.Spread", 1, 0.1, 10, 2, "gwater2_gun_spread")
    make_explanation(panel, "WaterGun.Spread.Explanation")
    make_scratch(panel, "WaterGun.SpawnMode", 1, 1, 2, 0, "gwater2_gun_spawnmode")
    make_explanation(panel, "WaterGun.SpawnMode.Explanation")

    return frame
end

function SWEP:DrawHUD()
	if not gwater2 then
		local a = 255*(math.sin(CurTime()*2)+1)/2
		draw.DrawText(language.GetPhrase("gwater2.gun.adv.notloaded"), "Trebuchet24", ScrW() / 2 + 1, ScrH() / 2 - 36 + 1, Color(0, 0, 0, a), TEXT_ALIGN_CENTER)
		draw.DrawText(language.GetPhrase("gwater2.gun.adv.notloaded"), "Trebuchet24", ScrW() / 2, ScrH() / 2 - 36, Color(255, 0, 0, a), TEXT_ALIGN_CENTER)
		return
	end
	--surface.DrawCircle(ScrW() / 2, ScrH() / 2, gwater2["size"] * gwater2["density"] * 4 * 10, 255, 255, 255, 255)
	draw.DrawText(language.GetPhrase("gwater2.gun.adv.controls.lclk"), "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.75, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText(language.GetPhrase("gwater2.gun.adv.controls.rclk"), "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.78, color_white, TEXT_ALIGN_RIGHT)
	draw.DrawText(language.GetPhrase("gwater2.gun.adv.controls.reload"), "CloseCaption_Normal", ScrW() * 0.99, ScrH() * 0.81, color_white, TEXT_ALIGN_RIGHT)
end

local function format_int(i)
	return tostring(i):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

-- visual counter on gun
function SWEP:PostDrawViewModel(vm, weapon, ply)
	if not gwater2 then return end
	local pos, ang = vm:GetBonePosition(39)--self:GetOwner():GetViewModel():GetBonePosition(0)
	if !pos or !ang then return end
	ang = ang + Angle(180, 0, -ang[3] * 2)
	pos = pos - ang:Right() * 1.5

	
	cam.Start3D2D(pos, ang, 0.03)
		local frac = gwater2.solver:GetActiveParticles() / gwater2.solver:GetMaxParticles()
		local text = format_int(gwater2.solver:GetActiveParticles()) .. " / " .. format_int(gwater2.solver:GetMaxParticles())
		local w,_ = surface.GetTextSize(
			format_int(gwater2.solver:GetMaxParticles()).." / "..format_int(gwater2.solver:GetMaxParticles()))
		draw.DrawText(text, "GWater2Param", 4, -24, Color(0, 0, 0, 255), TEXT_ALIGN_CENTER)
		draw.DrawText(text, "GWater2Param", 2, -26, color_white, TEXT_ALIGN_CENTER)
		draw.RoundedBox(8, -w/2, 0, frac*w, 20, Color(255, 255, 255, 255))
	cam.End3D2D()

	local angles = ply:EyeAngles()
	local pos = util.QuickTrace(ply:EyePos(),
								ply:GetAimVector() * self.ParticleDistance:GetFloat(),
								ply).HitPos + ply:GetAimVector() * -(gwater2.parameters.radius or 10)
	angles:RotateAroundAxis(angles:Right(), 90)
	if self.SpawnMode:GetInt() == 1 then
		cam.Start3D2D(pos, angles, 0.03)
			--surface.DrawCircle(0, 0, 160 * 5 * self.ParticleSpread:GetFloat(), 255, 255, 255, 255)
			for i=0,5,1 do
				local factor = math.ease.OutCubic(self.ParticleVelocity:GetFloat()/100*(i/5))
				surface.DrawCircle(0, 0, 160 * 5 * self.ParticleSpread:GetFloat() * (gwater2.parameters.radius or 10)/10
										- 160*3*(gwater2.parameters.radius or 10)/10*factor * self.ParticleSpread:GetFloat(),
										-- (((100-self.ParticleVelocity:GetFloat())*(math.log(i)+1)/2.6)/100),
										255, 255, 255, 255 * (1-factor))
			end
		cam.End3D2D()
	end
	if self.SpawnMode:GetInt() == 2 then
		pos = pos + ply:GetAimVector() * -(gwater2.parameters.radius or 10) * 5
		cam.Start3D2D(pos, angles, 0.03)
		local edge = Vector(4, 4, 4) * self.ParticleSpread:GetFloat()^2 * 2
		for i=0,5,1 do
			local factor = math.ease.OutCubic(self.ParticleVelocity:GetFloat()/100*(i/5))
			surface.SetDrawColor(255, 255, 255, 255 * (1-factor))
			local size = 160 * 3 * self.ParticleSpread:GetFloat()*(gwater2.parameters.radius or 10)/10
						 - 160*2*factor * self.ParticleSpread:GetFloat()*(gwater2.parameters.radius or 10)/10
			surface.DrawOutlinedRect(-size/2, -size/2, size, size, 2)
		end
		cam.End3D2D()
	end
end
