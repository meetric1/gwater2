AddCSLuaFile()

if SERVER or not gwater2 then return end

gwater2.VERSION = "1.0"

local just_closed = false

gwater2.options = gwater2.options or {
	solver = FlexSolver(1000, 1), -- that 2D-solver is available to everyone
	blur_passes = CreateClientConVar("gwater2_blur_passes", "3", true),
	absorption = CreateClientConVar("gwater2_absorption", "1", true),
	depth_fix = CreateClientConVar("gwater2_depth_fix", "0", true),
	simulation_fps = CreateClientConVar("gwater2_fps", "60", true),
	menu_key = CreateClientConVar("gwater2_menukey", tostring(KEY_G), true),
	menu_tab = CreateClientConVar("gwater2_menutab", "1", true),
	player_collision = CreateClientConVar("gwater2_player_collision", "1", true),
	render_mirrors = CreateClientConVar("gwater2_render_mirrors", "0", true),
	diffuse_enabled = CreateClientConVar("gwater2_diffuse_enabled", "1", true),

	config_cache = nil,

	write_config = function(tbl)
		local real = gwater2.options.read_config()
		for k,v in pairs(real) do
			if tbl[k] == nil then tbl[k] = v end
		end
		file.Write("gwater2/config.txt", util.TableToJSON(tbl))
		gwater2.options.config_cache = tbl
	end,
	read_config = function()
		if gwater2.options.config_cache then return gwater2.options.config_cache end
		gwater2.options.config_cache = util.JSONToTable(file.Read("gwater2/config.txt") or "{}")
		return gwater2.options.config_cache
	end,

	initialised = {},
}

-- kinda hacky
gwater2.parameters.blur_passes = gwater2.options.blur_passes:GetInt()
gwater2.parameters.absorption = gwater2.options.absorption:GetBool()
gwater2.parameters.depth_fix = gwater2.options.depth_fix:GetBool()
gwater2.parameters.simulation_fps = gwater2.options.simulation_fps:GetInt()
gwater2.parameters.player_collision = gwater2.options.player_collision:GetBool()
gwater2.parameters.mirror_rendering = gwater2.options.render_mirrors:GetInt()
gwater2.parameters.diffuse_enabled = gwater2.options.diffuse_enabled:GetBool()

if not file.Exists("gwater2/config.txt", "DATA") then
	gwater2.options.write_config({
		["sounds"]=true,
		["animations"]=false,
		["preview"]=true
	})
end

local params = include("menu/gwater2_params.lua")
local paramstabs = include("menu/gwater2_paramstabs.lua")
local styling = include("menu/gwater2_styling.lua")
local _util = include("menu/gwater2_util.lua")
if not file.Exists("gwater2", "DATA") then file.CreateDir("gwater2") end
local presets = include("menu/gwater2_presets.lua")
local admin_only = GetConVar("gwater2_adminonly")

-- garry, sincerely... fuck you
timer.Simple(0, function() 
	Material("gwater2/volumetric"):SetFloat("$alpha", gwater2.options.absorption:GetBool() and 0.125 or 0)
	Material("gwater2/normals"):SetInt("$depthfix", gwater2.options.depth_fix:GetBool() and 1 or 0)

	net.Start("GWATER2_REQUESTCOLLISION")
	net.WriteBool(gwater2.options.player_collision:GetBool())
	net.SendToServer()

	gwater2.solver:EnableDiffuse(gwater2.options.diffuse_enabled:GetBool())
end)

gwater2.options.solver:SetParameter("gravity", 15.24)	-- flip gravity because y axis positive is down
gwater2.options.solver:SetParameter("static_friction", 0)	-- stop adhesion sticking to front and back walls
gwater2.options.solver:SetParameter("dynamic_friction", 0)	-- ^

-- regen radius defaults, as it is scaled in the preview
gwater2.options.solver:SetParameter("radius", 13)
gwater2.options.solver:SetParameter("surface_tension", gwater2["surface_tension"] / 13^4)
gwater2.options.solver:SetParameter("fluid_rest_distance", 13 * gwater2["fluid_rest_distance"])
gwater2.options.solver:SetParameter("solid_rest_distance", 13 * gwater2["solid_rest_distance"])
gwater2.options.solver:SetParameter("collision_distance", 13 * gwater2["collision_distance"])
gwater2.options.solver:SetParameter("cohesion", math.min(gwater2["cohesion"] / 13 * 10, 1))

local function create_menu(init)
	local frame = vgui.Create("DFrame")
	frame:SetTitle("GWater2 " .. gwater2.VERSION .. ": Main Menu")
	--frame:SetSize(ScrW() * 0.8, ScrH() * 0.6)
	frame:SetSize(math.min(1000, ScrW() * 0.9), math.min(600, ScrH() * 0.9))
	frame:Center()
	frame:MakePopup()
	frame:SetScreenLock(true)
	function frame:Paint(w, h)
		-- darker background
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
		frame:SetVisible(false)
		just_closed = false
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

	gwater2.options.solver:Reset()

	local sim_preview = vgui.Create("DPanel", frame)
	local help_text = vgui.Create("DPanel", frame)
	local tabs = vgui.Create("DPropertySheet", frame)
	local divider = vgui.Create("DHorizontalDivider", frame)
	--sim_preview:Dock(LEFT)
	help_text:Dock(RIGHT)
	sim_preview:SetSize(frame:GetWide()*0.25, sim_preview:GetTall())

	divider:Dock(FILL)

	divider:SetLeft(sim_preview)
	divider:SetRight(tabs)
	divider:SetDividerWidth(4)
	divider:SetLeftWidth(sim_preview:GetWide())
	divider:SetLeftMin(20)

	local q_access = vgui.Create("DPanel", frame)
	q_access:Dock(BOTTOM)
	q_access:DockMargin(0, 5, 0, 0)
	function q_access:Paint(w, h) styling.draw_main_background(0, 0, w, h) end

	local qgun = q_access:Add("DImageButton")
	qgun:SetImage("icon16/gun.png")
	qgun:Dock(LEFT)
	qgun:DockMargin(2, 2, 2, 2)
	qgun:SetSize(q_access:GetTall() - 4, q_access:GetTall() - 4)
	qgun:SetTooltip(_util.get_localised("qaccess.Give Watergun"))
	function qgun:DoClick()
		RunConsoleCommand("gm_giveswep", "weapon_gw2_watergun")
	end

	local qreset = q_access:Add("DImageButton")
	qreset:SetImage("icon16/arrow_refresh.png")
	qreset:Dock(LEFT)
	qreset:DockMargin(2, 2, 2, 2)
	qreset:SetSize(q_access:GetTall() - 4, q_access:GetTall() - 4)
	qreset:SetTooltip(_util.get_localised("qaccess.Reset Solvers"))
	function qreset:DoClick()
		gwater2.options.solver:Reset()
		gwater2.ResetSolver()
		_util.emit_sound("reset")
	end

	local particle_material = nil
	local pixelated = "hell"

	local function get_weighted_pixels(x, y)
		local floor_x = math.floor(x)
		local floor_y = math.floor(y)
		local ceil_x = math.ceil(x)
		local ceil_y = math.ceil(y)
	  
		local frac_x = x - floor_x
		local frac_y = y - floor_y
	  
		local w1 = (1 - frac_x) * (1 - frac_y)
		local w2 = (frac_x) * (1 - frac_y)
		local w3 = (1 - frac_x) * (frac_y)
		local w4 = (frac_x) * (frac_y) 
	  
		return floor_x, floor_y, w1, ceil_x, floor_y, w2, floor_x, ceil_y, w3, ceil_x, ceil_y, w4
	end

	function sim_preview:Paint(w, h)
		styling.draw_main_background(0, 0, w, h)
		local x, y = sim_preview:LocalToScreen(0, 0)
		local function exp(v) return Vector(math.exp(v[1]), math.exp(v[2]), math.exp(v[3])) end
		local is_translucent = gwater2.parameters.color.a < 255
		local radius = gwater2.options.solver:GetParameter("radius")
		local collision_distance = gwater2.options.solver:GetParameter("collision_distance")

		local mat = Matrix()
		mat:SetTranslation(Vector(x + w / 3 + math.random(), 0, y + radius + 15))
		gwater2.options.solver:InitBounds(Vector(x - radius / 2, -collision_distance, y), Vector(x + w - radius / 2, collision_distance, y + h - radius / 2))
		gwater2.options.solver:AddCube(mat, Vector(4, 1, 1), {vel = Vector(0, 0, 7.5)})
		gwater2.options.solver:Tick(1 / 60)

		if gwater2.options.read_config().pixelate_preview ~= pixelated then
			pixelated = gwater2.options.read_config().pixelate_preview
			particle_material = CreateMaterial("gwater2_menu_material"..(gwater2.options.read_config().pixelate_preview and "_pix" or ""), "UnlitGeneric", {
				["$basetexture"] = (gwater2.options.read_config().pixelate_preview and "color/white" or "vgui/circle"),
				["$vertexcolor"] = 1,
				["$vertexalpha"] = 1,
				["$ignorez"] = 1
			})
		end

		surface.SetMaterial(particle_material)

		local pixelate = gwater2.options.read_config().pixelate_preview 

		local alpha = is_translucent and (pixelate and 50 or 150) or 255
		gwater2.options.solver:RenderParticles(function(pos)
			local depth = math.max((pos[3] - y) / 584, 0) * 20	-- ranges from 0 to 20 down
			local absorption = is_translucent and exp(
				(gwater2.parameters.color:ToVector() * gwater2.parameters.color_value_multiplier - Vector(1, 1, 1)) *
					gwater2.parameters.color.a / 255 * depth) or
				(gwater2.parameters.color:ToVector() * gwater2.parameters.color_value_multiplier)
			local px = pos[1] - x
			local py = pos[3] - y
			if pixelate then
				px, py = px / radius, py / radius
				local bx1, by1, w1, bx2, by2, w2, bx3, by3, w3, bx4, by4, w4 = get_weighted_pixels(px, py)
				bx1, by1 = bx1 * radius, by1 * radius
				bx2, by2 = bx2 * radius, by2 * radius
				bx3, by3 = bx3 * radius, by3 * radius
				bx4, by4 = bx4 * radius, by4 * radius
				local r, g, b = absorption[1] * 255, absorption[2] * 255, absorption[3] * 255

				surface.SetDrawColor(r, g, b, alpha*w1)
				surface.DrawTexturedRect(bx1, by1, radius, radius)

				surface.SetDrawColor(r, g, b, alpha*w2)
				surface.DrawTexturedRect(bx2, by2, radius, radius)

				surface.SetDrawColor(r, g, b, alpha*w3)
				surface.DrawTexturedRect(bx3, by3, radius, radius)

				surface.SetDrawColor(r, g, b, alpha*w4)
				surface.DrawTexturedRect(bx4, by4, radius, radius)

				--px = math.Round(px / radius) * radius
				--py = math.Round(py / radius) * radius
				return
			end

			surface.SetDrawColor(absorption[1] * 255, absorption[2] * 255, absorption[3] * 255, alpha)
			surface.DrawTexturedRect(px, py, radius, radius)
		end)


		styling.draw_main_background_outline(0, 0, w, h)

		styling.draw_main_background(0, 0, sim_preview:GetWide(), 30)
		draw.DrawText(_util.get_localised("Fluid Preview.title"), "GWater2Title", sim_preview:GetWide() / 2 + 1, 6, Color(0, 0, 0), TEXT_ALIGN_CENTER)
		draw.DrawText(_util.get_localised("Fluid Preview.title"), "GWater2Title", sim_preview:GetWide() / 2, 5, Color(187, 245, 255), TEXT_ALIGN_CENTER)
	end
	local reset = sim_preview:Add("DButton")
	reset:SetText("")
	reset:SetImage("icon16/arrow_refresh.png")
	reset:SetWide(reset:GetTall())
	reset.Paint = nil
	reset:SetPos(5, 5)
	function reset:DoClick()
		gwater2.options.solver:Reset()
		_util.emit_sound("reset")
	end

	if not gwater2.options.read_config().preview then
		sim_preview:SetVisible(false)
		divider:SetLeft(nil)
		divider:SetLeftWidth(0)
		divider:SetLeftMin(0)
		divider:SetDividerWidth(0)
	end

	help_text:SetSize(frame:GetWide()*0.25, help_text:GetTall())
	function help_text:Paint(w, h)
		styling.draw_main_background(0, 0, w, h)
		draw.DrawText(_util.get_localised("Explanation Area.title"), "GWater2Title", help_text:GetWide() / 2 + 1, 6, Color(0, 0, 0), TEXT_ALIGN_CENTER)
		draw.DrawText(_util.get_localised("Explanation Area.title"), "GWater2Title", help_text:GetWide() / 2, 5, Color(187, 245, 255), TEXT_ALIGN_CENTER)
	end
	--tabs:Dock(FILL)
	tabs:SetFadeTime(0)
	help_text = help_text:Add("DLabel")
	help_text:Dock(FILL)
	help_text:DockMargin(5, 5, 5, 5)
	help_text:SetTextInset(0, 24)
	help_text:SetWrap(true)
	help_text:SetColor(Color(255, 255, 255))
	help_text:SetContentAlignment(7)
	help_text:SetFont("GWater2Param")
	function tabs:Paint(w, h) styling.draw_main_background(0, 23, w, h-23) end

	function frame:OnKeyCodePressed(key)
		if key ~= gwater2.options.menu_key:GetInt() then return end
		frame:SetVisible(false)
		just_closed = true
	end

	frame.tabs = tabs

	local function about_tab(tabs)
		local tab = vgui.Create("DPanel", tabs)
		function tab:Paint() end
		tabs:AddSheet(_util.get_localised("About Tab.title"), tab, "icon16/exclamation.png").Tab.realname = "About Tab"
		tab = tab:Add("DScrollPanel")
		tab:Dock(FILL)

		styling.define_scrollbar(tab:GetVBar())

		local _ = tab:Add("DLabel") _:SetText(" ") _:SetFont("GWater2Title") _:Dock(TOP) _:SizeToContents()
		function _:Paint(w, h)
			draw.DrawText(_util.get_localised("About Tab.titletext", gwater2.VERSION), "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(_util.get_localised("About Tab.titletext", gwater2.VERSION), "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		local label = tab:Add("DLabel")
		label:Dock(TOP)
		label:DockMargin(5, 5, 5, 5)
		label:SetText(_util.get_localised("About Tab.welcome"))
		label:SetColor(Color(255, 255, 255))
		label:SetTextInset(5, 5)
		label:SetWrap(true)
		label:SetContentAlignment(7)
		label:SetFont("GWater2Param")
		
		label:SetPos(0, 0)
		label:SetTall(800)
		timer.Simple(0, function()
			local _, height = label:GetContentSize()
			label:SetTall(height)
		end)

		return tab
	end

	local function credits_tab(tabs)
		local tab = vgui.Create("DPanel", tabs)
		function tab:Paint() end

		tabs:AddSheet(_util.get_localised("Credits.title"), tab, "icon16/award_star_gold_3.png").Tab.realname = "Credits"
		tab = tab:Add("DScrollPanel")
		tab:Dock(FILL)

		styling.define_scrollbar(tab:GetVBar())

		local _ = tab:Add("DLabel") _:SetText(" ") _:SetFont("GWater2Title") _:Dock(TOP) _:SizeToContents()
		function _:Paint(w, h)
			draw.DrawText(_util.get_localised("Credits.titletext"), "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(_util.get_localised("Credits.titletext"), "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		local label = tab:Add("DLabel")
		label:Dock(TOP)
		label:DockMargin(5, 5, 5, 5)
		label:SetText(_util.get_localised("Credits.text"))
		label:SetColor(Color(255, 255, 255))
		label:SetTextInset(5, 5)
		label:SetWrap(true)
		label:SetContentAlignment(7)
		label:SetFont("GWater2Param")

		local patrons_table = {"<Failed to load patron data!>"}
		
		file.AsyncRead("data_static/gwater2/patrons.txt", "THIRDPARTY", function(name, path, status, data)
			if status != FSASYNC_OK then return end
			patrons_table = string.Split(data, "\n")
		end)

		-- Hi - Xenthio
		-- DONT FORGET TO ADD 'Xenthio' & 'NecrosVideos'

		local supporter_color = Color(171, 255, 163)
		
		label:SetPos(0, 0)
		function label:Paint(w, h)
			local _, height = self:GetContentSize()
			label:SetTall(math.max(#patrons_table * 20, 1000) + 440)	-- fuck this shit hack

			local top = math.max(math.floor((tab:GetVBar():GetScroll() - 440) / 20), 1)	-- only draw what we see
			for i = top, math.min(top + 30, #patrons_table) do
				draw.DrawText(patrons_table[i], "GWater2Param", 6, height + i * 20, supporter_color, TEXT_ALIGN_LEFT)
			end
		end

		return tab
	end

	local function menu_tab(tabs)
		local tab = vgui.Create("DPanel", tabs)
		function tab:Paint() end

		tabs:AddSheet(_util.get_localised("Menu.title"), tab, "icon16/css_valid.png").Tab.realname = "Menu"
		tab = tab:Add("DScrollPanel")
		tab:Dock(FILL)
		tab.help_text = tabs.help_text

		styling.define_scrollbar(tab:GetVBar())

		local _ = tab:Add("DLabel") _:SetText(" ") _:SetFont("GWater2Title") _:Dock(TOP) _:SizeToContents()
		function _:Paint(w, h)
			draw.DrawText(_util.get_localised("Menu.titletext"), "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
			draw.DrawText(_util.get_localised("Menu.titletext"), "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
		end

		_util.make_parameter_check(tab, "Menu.sounds", "Sounds", {
			nosync=true,
	        func=function(val)
	        	gwater2.options.write_config({["sounds"]=val})
	        	return true
	        end,
	        setup=function(check)
	        	check:GetParent().button:Remove()
	        	check:SetValue(gwater2.options.read_config().sounds)
	        	return true
	        end
    	})

    	_util.make_parameter_check(tab, "Menu.animations", "Animations", {
			nosync=true,
	        func=function(val)
	        	gwater2.options.write_config({["animations"]=val})
	        	return true
	        end,
	        setup=function(check)
	        	check:GetParent().button:Remove()
	        	check:SetValue(gwater2.options.read_config().animations)
	        	return true
	        end
    	})

    	_util.make_parameter_check(tab, "Menu.preview", "Preview", {
			nosync=true,
	        func=function(val)
	        	gwater2.options.write_config({["preview"]=val})
	        	sim_preview:SetVisible(val)
	        	if not val then
	        		divider:SetLeft(nil)
	        		divider:SetLeftWidth(0)
					divider:SetLeftMin(0)
					divider:SetDividerWidth(0)
	        	else
	        		divider:SetLeft(sim_preview)
	        		divider:SetLeftWidth(sim_preview:GetWide())
					divider:SetLeftMin(20)
					divider:SetDividerWidth(4)
	        	end
	        	frame:InvalidateLayout()
	        	return true
	        end,
	        setup=function(check)
	        	check:GetParent().button:Remove()
	        	check:SetValue(gwater2.options.read_config().preview)
	        	return true
	        end
    	})

    	_util.make_parameter_check(tab, "Menu.pixelate_preview", "Pixelate Preview", {
			nosync=true,
	        func=function(val)
	        	gwater2.options.write_config({["pixelate_preview"]=val})
	        	return true
	        end,
	        setup=function(check)
	        	check:GetParent().button:Remove()
	        	check:SetValue(gwater2.options.read_config().pixelate_preview)
	        	return true
	        end
    	})

		if LocalPlayer():IsSuperAdmin() then
			_util.make_parameter_check(tab, "Menu.admin_only", "Admin Only", {
				nosync=true,
				func=function(val)
					RunConsoleCommand("gwater2_adminonly", val and "1" or "0")
					return true
				end,
				setup=function(check)
					check:GetParent().button:Remove()
					check:SetValue(admin_only:GetBool())
					return true
				end
			})
		end
	end

	tabs.help_text = help_text

	help_text:SetText(_util.get_localised("About Tab.help"))
	
	about_tab(tabs)

	frame.params = {}	-- need to pass by reference into presets
	frame.params._parameters = paramstabs.parameters_tab(tabs)
	frame.params._visuals = paramstabs.visuals_tab(tabs)
	frame.params._interactions = paramstabs.interaction_tab(tabs)

	presets.presets_tab(tabs, frame.params)
	paramstabs.performance_tab(tabs)
	menu_tab(tabs)
	credits_tab(tabs)
	paramstabs.developer_tab(tabs)

	for _,tab in pairs(tabs:GetItems()) do
		local rt = tab
		tab = tab.Tab
		function tab:Paint(w, h)
			styling.draw_main_background(0, 0, w - 4, self:IsActive() and h - 4 or h)
			if tab.lastpush ~= nil then
				local delta = 1 - (RealTime() - tab.lastpush) * 2
				if RealTime() - tab.lastpush < 0.5 then
					surface.SetDrawColor(0, 127, 255, 255*delta)
					surface.DrawRect(0, 0, w - 4, self:IsActive() and h - 4 or h)
					surface.SetDrawColor(255, 255, 255, 255*delta)
					surface.DrawOutlinedRect(0, 0, w - 4, self:IsActive() and h - 4 or h)
				end
				if not gwater2.options.read_config().animations then return end
				local children = {}
				local function _(p)
					for __,child in pairs(p:GetChildren()) do
						children[#children+1] = child
						_(child)
					end
				end
				_(rt.Panel:GetChildren()[1])
				for i,v in pairs(children) do
					v:SetAlpha((1-delta-i/500)*255*4)
				end
			end
			surface.SetDrawColor(255, 255, 255, 255)
		end
	end

	tabs.Items = tabs.Items or {}

	-- force docking to work properly
	tabs:SetActiveTab(tabs.Items[gwater2.options.menu_tab:GetInt() ~= 1 and 1 or 2].Tab)

	function tabs:OnActiveTabChanged(_, new)
		help_text:SetText(_util.get_localised(new.realname..".help"))
		for k, v in ipairs(self.Items) do
			if v.Tab ~= new then continue end
			gwater2.options.menu_tab:SetInt(k)
			break
		end
		_util.emit_sound("select")
		new.lastpush = RealTime()
		help_text:GetParent():SetParent(new:GetPanel())
		help_text:GetParent():Dock(RIGHT)
		help_text:SetWide(help_text:GetWide()*2)
	end

	local cfg, sounds
	if init then
		cfg = gwater2.options.read_config()
		sounds = cfg.sounds
		cfg.sounds = false
	end
	pcall(function()	-- tab can invalidate itself if you are non-admin
		tabs:SetActiveTab(tabs.Items[gwater2.options.menu_tab:GetInt()].Tab)
	end)
	if init then
		cfg.sounds = sounds
	end

	return frame
end

surface.CreateFont("GWater2Param", {
    font = "Space Mono", 
    extended = false,
    size = 20,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

surface.CreateFont("GWater2Title", {
    font = "coolvetica", 
    extended = false,
    size = 24,
    weight = 500,
    blursize = 0,
    scanlines = 0,
    antialias = true,
    underline = false,
    italic = false,
    strikeout = false,
    symbol = false,
    rotary = false,
    shadow = false,
    additive = false,
    outline = false,
})

concommand.Add("gwater2_menu", function()
	if IsValid(gwater2.options.frame) then
		gwater2.options.frame:SetVisible(not gwater2.options.frame:IsVisible())
		gwater2.options.frame:Center()
		gwater2.options.solver:Reset()
		local tabs = gwater2.options.frame.tabs

		-- play sound and animate properly
		_util.emit_sound("select")
		tabs:GetActiveTab().lastpush = RealTime()

		-- should we show tabs?
		local tabs_enabled = !admin_only:GetBool() or LocalPlayer():IsAdmin()
		
		local items = tabs:GetItems()
		items[2].Tab:SetVisible(tabs_enabled) -- parameters
		items[3].Tab:SetVisible(tabs_enabled) -- visuals
		items[4].Tab:SetVisible(tabs_enabled) -- interactions
		items[5].Tab:SetVisible(tabs_enabled) -- presets
		items[9].Tab:SetVisible(tabs_enabled and GetConVar("developer"):GetInt() != 0) -- developer

		return
	end

	gwater2.options.frame = create_menu()
end)

hook.Add("GUIMousePressed", "gwater2_menuclose", function(mouse_code, aim_vector)
	if not IsValid(gwater2.options.frame) then return end

	local x, y = gui.MouseX(), gui.MouseY()
	local frame_x, frame_y = gwater2.options.frame:GetPos()
	if x < frame_x or x > frame_x + gwater2.options.frame:GetWide() or y < frame_y or y > frame_y + gwater2.options.frame:GetTall() then
		gwater2.options.frame:SetVisible(false)
	end
end)

hook.Add("PopulateToolMenu", "gwater2_menu", function()
    spawnmenu.AddToolMenuOption("Utilities", "GWater2", "gwater2_menu", "Menu Options", "", "", function(panel)
		panel:ClearControls()
		panel:Button("Open Menu", "gwater2_menu")
        panel:KeyBinder("Menu Key", "gwater2_menukey")
	end)
end)


-- initialse menu at loading time
hook.Add("Think", "GWATER2_InitializeMenu", function()
	if not admin_only then return end -- wait until we have the convar
	hook.Remove("Think", "GWATER2_InitializeMenu")
	gwater2.options.frame = create_menu(true)
	gwater2.options.frame:SetVisible(false)
end)

-- shit breaks in singleplayer due to predicted hooks
function gwater2.open_menu(ply, key)
	if !game.SinglePlayer() and !IsFirstTimePredicted() then return end

	if key != gwater2.options.menu_key:GetInt() or just_closed == true then return end
	RunConsoleCommand("gwater2_menu")
end

function gwater2.close_menu(ply, key)
	if !game.SinglePlayer() and !IsFirstTimePredicted() then return end

	if key != gwater2.options.menu_key:GetInt() then return end
	just_closed = false
end

if !game.SinglePlayer() then
	hook.Add("PlayerButtonDown", "gwater2_menu", gwater2.open_menu)
	hook.Add("PlayerButtonUp", "gwater2_menu", gwater2.close_menu)
end