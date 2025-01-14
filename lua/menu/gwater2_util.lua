AddCSLuaFile()

if SERVER or not gwater2 then return end

gwater2.cursor_busy = nil

local localed_cache = {}
-- TODO: this is horrible.
local function get_localised(loc, a,b,c,d,e)
	a,b,c,d,e = a or "", b or "", c or "", d or "", e or ""
	if localed_cache[loc..a..b..c..d..e] then return localed_cache[loc..a..b..c..d..e] end
	localed_cache[loc..a..b..c..d..e] = language.GetPhrase("gwater2.menu."..loc):gsub("^%s+", ""):format(a,b,c,d,e)
	return localed_cache[loc..a..b..c..d..e]
end

local function is_hovered_any(panel)
	if panel:IsHovered() then return true end
	for k,v in pairs(panel:GetChildren()) do
		if v.IsEditing and v:IsEditing() then
			return true
		end
		if v.IsDown and v:IsDown() then
			return true
		end
		if is_hovered_any(v) then
			return true
		end
	end
	return false
end

local _styling = include("menu/gwater2_styling.lua")

local function emit_sound(type)
	if not gwater2.options.read_config().sounds then return end
	surface.PlaySound("gwater2/menu/"..type..".wav")
end

local function set_gwater_parameter(option, val, ply)
	if val == nil then return end -- wtf

	local param = gwater2.options.initialised[option]

	assert(param, "Parameter does not exist: "..option)

	gwater2.parameters[option] = val

	if IsValid(param[2]) and ply != LocalPlayer() then
		param[2].block = true
		if param[1].type != "color" then 
      		param[2]:SetValue(val)
		else
			param[2]:SetColor(val)
		end
		param[2].block = false
	end
	
	if param[1].func then
		if param[1].func(val, param) then return end
	end

	if gwater2[option] then
		gwater2[option] = val
		local radius = gwater2.solver:GetParameter("radius")
		if option == "surface_tension" then	-- hack hack hack! this parameter scales based on radius
			local r1 = val / radius^4	-- cant think of a name for this variable rn
			local r2 = val / math.min(radius * 1.3, 15)^4
			gwater2.solver:SetParameter(option, r1)
			gwater2.options.solver:SetParameter(option, r2)
		elseif option == "fluid_rest_distance" or option == "collision_distance" or option == "solid_rest_distance" then -- hack hack hack! this parameter scales based on radius
			local r1 = val * radius
			local r2 = val * math.min(radius * 1.3, 15)
			gwater2.solver:SetParameter(option, r1)
			gwater2.options.solver:SetParameter(option, r2)
		elseif option == "cohesion" then	-- also scales by radius
			local r1 = math.min(val / radius * 10, 1)
			local r2 = math.min(val / (radius * 1.3) * 10, 1)
			gwater2.solver:SetParameter(option, r1)
			gwater2.options.solver:SetParameter(option, r2)
		end
		return
	end

	gwater2.solver:SetParameter(option, val)

	if option == "gravity" then val = -val end	-- hack hack hack! y coordinate is considered down in screenspace!
	if option == "radius" then 					-- hack hack hack! radius needs to edit multiple parameters!
		gwater2.solver:SetParameter("surface_tension", gwater2["surface_tension"] / val^4)	-- literally no idea why this is a power of 4
		gwater2.solver:SetParameter("fluid_rest_distance", val * gwater2["fluid_rest_distance"])
		gwater2.solver:SetParameter("solid_rest_distance", val * gwater2["solid_rest_distance"])
		gwater2.solver:SetParameter("collision_distance", val * gwater2["collision_distance"])
		gwater2.solver:SetParameter("cohesion", math.min(gwater2["cohesion"] / val * 10, 1))
		
		if val > 15 then val = 15 end	-- explody
		val = val * 1.3
		gwater2.options.solver:SetParameter("surface_tension", gwater2["surface_tension"] / val^4)
		gwater2.options.solver:SetParameter("fluid_rest_distance", val * gwater2["fluid_rest_distance"])
		gwater2.options.solver:SetParameter("solid_rest_distance", val * gwater2["solid_rest_distance"])
		gwater2.options.solver:SetParameter("collision_distance", val * gwater2["collision_distance"])
		gwater2.options.solver:SetParameter("cohesion", math.min(gwater2["cohesion"] / val * 10, 1))
	end

	if option ~= "diffuse_threshold" and option ~= "dynamic_friction" then -- hack hack hack! fluid preview doesn't use diffuse particles
		gwater2.options.solver:SetParameter(option, val)
	end
end

local function empty() end

local function panel_paint(self, w, h)
	if gwater2.cursor_busy ~= self and gwater2.cursor_busy ~= nil and IsValid(gwater2.cursor_busy) then return end
	local hovered = is_hovered_any(self)
	local tab = self.tab
	local label = self.label
	if hovered and not self.washovered then
		self.default_help_text = tab.help_text:GetText()
		self.washovered = true
		gwater2.cursor_busy = self
		tab.help_text:SetText(get_localised(self.parameter_locale_name..".desc"))
		emit_sound("rollover")
		label:SetColor(label.fancycolor_hovered or Color(187, 245, 255))
	elseif not hovered and self.washovered then
		self.washovered = false
		gwater2.cursor_busy = nil
		if tab.help_text:GetText() == get_localised(self.parameter_locale_name..".desc") then
			tab.help_text:SetText(self.default_help_text)
		end
		label:SetColor(label.fancycolor or Color(255, 255, 255))
	end
end
local slider_functions = {
	init_setvalue = function(panel)
		local parameter_id = panel.parameter
		local slider = panel.slider
		slider:SetValue(gwater2[parameter_id] or
					    gwater2.parameters[parameter_id] or gwater2.defaults[parameter_id] or
						gwater2.solver:GetParameter(parameter_id))
	end,
	reset = function(self)
		local parent = self:GetParent()
		local parameter_id = parent.parameter
		parent.slider:SetValue(gwater2.defaults[parameter_id])	
		emit_sound("reset")
	end,
	onvaluechanged = function(self, val)
		if self.block then return end

		local parent = self:GetParent()
		local decimals = self:GetDecimals()
		if val ~= math.Round(val, decimals) then
			self:SetValue(math.Round(val, decimals))
			return
		end
		local parameter = parent.parameter_table
		local parameter_id = parent.parameter

		gwater2.parameters[parameter_id] = val
		if parameter.nosync then
			return set_gwater_parameter(parameter_id, val)
		end
		gwater2.ChangeParameter(parameter_id, val, false)
	end,
	onvaluechanged_final = function(self)
		--             knob->Slider--->slider
		local slider = self:GetParent():GetParent()
		local parent = slider:GetParent()
		local parameter_id = parent.parameter
		local parameter = parent.parameter_table
		local slider = parent.slider
		local val = math.Round(slider:GetValue(), slider:GetDecimals())
		if parameter.nosync then
			return set_gwater_parameter(parameter_id, val)
		end
		gwater2.ChangeParameter(parameter_id, val, true)
	end
}
local color_functions = {
	init_setvalue = function(panel)
		local parameter_id = panel.parameter
		panel.mixer:SetColor(gwater2.parameters[parameter_id] or gwater2.defaults[parameter_id])
	end,
	reset = function(self)
		local parent = self:GetParent()
		local parameter_id = parent.parameter
		parent.mixer:SetColor(Color(gwater2.defaults[parameter_id]:Unpack()))
		emit_sound("reset")
	end,
	onvaluechanged = function(self, val)
		--mixer.editing = true
		-- TODO: find something to reset editing to false when user stops editing color
		if self.block then return end
		-- "color" doesn't even have color metatable
		val = Color(val.r, val.g, val.b, val.a)

		local parent = self:GetParent()
		local parameter_id = parent.parameter

		gwater2.parameters[parameter_id] = val
		if parent.parameter_table.nosync then
			return set_gwater_parameter(parameter_id, val)
		end
		gwater2.ChangeParameter(parameter_id, val, true) -- TODO: ^
	end,
	onvaluechanged_final = empty
}
local check_functions = {
	init_setvalue = function(panel)
		local parameter_id = panel.parameter
		panel.check:SetValue(gwater2.parameters[parameter_id] or gwater2.defaults[parameter_id])
	end,
	reset = function(self)
		local parent = self:GetParent()
		local parameter_id = parent.parameter
		parent.check:SetValue(gwater2.defaults[parameter_id])
		emit_sound("reset")
	end,
	onvaluechanged = function(self, val) -- all checkbox edits are final
		if self.block then return end
		emit_sound("toggle")

		local parent = self:GetParent()
		local parameter_id = parent.parameter

		gwater2.parameters[parameter_id] = val
		if parent.parameter_table.nosync then
			return set_gwater_parameter(parameter_id, val)
		end
		gwater2.ChangeParameter(parameter_id, val, true)
	end
}

local function make_title_label(tab, txt)
	local label = tab:Add("DLabel")
	label:SetText(txt)
	label:SetColor(Color(187, 245, 255))
	label:SetFont("GWater2Title")
	label:Dock(TOP)
	label:SetMouseInputEnabled(true)
	label:SizeToContents()
	local defhelptext = nil

	return label
end
local function make_parameter_scratch(tab, locale_parameter_name, parameter_name, parameter)
	local panel = tab:Add("DPanel")
	panel.tab = tab
	panel.Paint = nil
	panel:Dock(TOP)
	
	local slider = panel:Add("DNumSlider")
	function slider.Scratch:GetTextValue()
		local decimals = self:GetDecimals()
		if decimals == 0 then
			return string.format("%i", self:GetFloatValue())
		end
		if decimals < 0 then
			return string.format("%i", math.floor(self:GetFloatValue() / 10^decimals) * 10^decimals)
		end

		return string.format("%." .. decimals .. "f", self:GetFloatValue())
	end
	panel.slider = slider
	slider:SetMinMax(parameter.min, parameter.max)
	slider:SetText(get_localised(locale_parameter_name))

	local label = slider.Label
	panel.label = label
	label:SetFont("GWater2Param")
	label:SizeToContents()
	label:SetWidth(label:GetSize() * 1.1)
	label:SetColor(Color(255, 255, 255))

	local parameter_id = string.lower(parameter_name):gsub(" ", "_")
	panel.parameter = parameter_id
	panel.parameter_table = parameter
	panel.parameter_locale_name = locale_parameter_name

	pcall(slider_functions.init_setvalue, panel)
	-- if we can't get parameter, let's hope .setup() does that for us
	slider:SetDecimals(parameter.decimals)

	local button = panel:Add("DButton")
	panel.button = button
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button:SetWide(button:GetTall())
	button:Dock(RIGHT)
	button.Paint = nil
	button.DoClick = slider_functions.reset

	slider:Dock(FILL)
	slider:DockMargin(0, 0, 0, 0)

	-- not sure why this is required. for some reason just makes it work
	slider.PerformLayout = empty
	
	slider.TextArea:SizeToContents()

	-- call custom setup function
	if parameter.setup then parameter.setup(slider) end

	gwater2.options.initialised[parameter_id] = {parameter, slider}

	button.DoClick = slider_functions.reset
	slider.Slider.Knob.DoClick = slider_functions.onvaluechanged_final
	slider.OnValueChanged = slider_functions.onvaluechanged
	panel.Paint = panel_paint

	function slider.Slider.Knob:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 125)
		surface.DrawRect(w/4, 0, w/2, h)
	
		if panel.washovered then
			surface.SetDrawColor(panel.label.fancycolor_hovered or Color(187, 245, 255))
		else
			surface.SetDrawColor(panel.label.fancycolor or Color(255, 255, 255))
		end
		surface.DrawOutlinedRect(w/4, 0, w/2, h)
	end

	if not gwater2.parameters[parameter_id] then
		gwater2.parameters[parameter_id] = slider:GetValue()
		gwater2.defaults[parameter_id] = slider:GetValue()
	end

	panel:SetTall(panel:GetTall()+2)

	return panel
end
local function make_parameter_color(tab, locale_parameter_name, parameter_name, parameter)
	local panel = tab:Add("DPanel")
	panel.tab = tab
	panel.Paint = nil
	panel:Dock(TOP)
	panel:SetTall(150)

	local label = panel:Add("DLabel")
	panel.label = label
	label:SetText(get_localised(locale_parameter_name))
	label:SetColor(Color(255, 255, 255))
	label:SetFont("GWater2Param")
	label:Dock(LEFT)
	label:SetMouseInputEnabled(true)
	label:SizeToContents()

	local parameter_id = string.lower(parameter_name):gsub(" ", "_")
	panel.parameter = parameter_id
	panel.parameter_table = parameter
	panel.parameter_locale_name = locale_parameter_name

	pcall(color_functions.init_setvalue, panel)
	-- if we can't get parameter, let's hope .setup() does that for us

	local mixer = panel:Add("DColorMixer")
	panel.mixer = mixer
	mixer:Dock(FILL)
	mixer:DockPadding(5, 0, 5, 0)
	mixer:SetPalette(false)
	mixer:SetLabel()
	mixer:SetAlphaBar(true)
	mixer:SetWangs(true)
	-- mixer:SetColor(gwater2.parameters[parameter_id]) 

	local button = panel:Add("DButton")
	panel.button = button
	button:Dock(RIGHT)
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button:SetWide(button:GetTall())
	button.Paint = nil

	panel:SizeToContents()

	if parameter.setup then parameter.setup(mixer) end

	gwater2.options.initialised[parameter_id] = {parameter, mixer}

	-- TODO: find something to reset editing to false when user stops editing color
	button.DoClick = color_functions.reset
	mixer.ValueChanged = color_functions.onvaluechanged
	panel.Paint = panel_paint

	if not gwater2.parameters[parameter_id] then
		gwater2.parameters[parameter_id] = mixer:GetColor()
		gwater2.defaults[parameter_id] = mixer:GetColor()
	end

	panel:SetTall(panel:GetTall()+5)

	return panel
end
local function make_parameter_check(tab, locale_parameter_name, parameter_name, parameter)
	local panel = tab:Add("DPanel")
	panel.tab = tab
	panel.Paint = nil
	panel:Dock(TOP)
	local label = panel:Add("DLabel")
	panel.label = label
	label:SetText(get_localised(locale_parameter_name))
	label:SetColor(Color(255, 255, 255))
	label:SetFont("GWater2Param")
	label:Dock(LEFT)
	label:SetMouseInputEnabled(true)
	label:SizeToContents()

	local check = panel:Add("DCheckBoxLabel")
	panel.check = check
	check:Dock(FILL)
	check:DockMargin(5, 0, 5, 0)
	check:SetText("")
	local button = panel:Add("DButton")
	panel.button = button
	button:Dock(RIGHT)
	button:SetText("")
	button:SetImage("icon16/arrow_refresh.png")
	button:SetWide(button:GetTall())
	button.Paint = nil

	local parameter_id = string.lower(parameter_name):gsub(" ", "_")
	panel.parameter = parameter_id
	panel.parameter_table = parameter
	panel.parameter_locale_name = locale_parameter_name

	pcall(check_functions.init_setvalue, panel)
	-- if we can't get parameter, let's hope .setup() does that for us
	if parameter.setup then parameter.setup(check) end

	gwater2.options.initialised[parameter_id] = {parameter, check}

	button.DoClick = check_functions.reset
	check.OnChange = check_functions.onvaluechanged
	panel.Paint = panel_paint
	function check.Button:Paint(w, h)
		surface.SetDrawColor(0, 0, 0, 125)
		surface.DrawRect(0, 0, w, h)

		if panel.washovered then
			surface.SetDrawColor(panel.label.fancycolor_hovered or Color(187, 245, 255))
		else
			surface.SetDrawColor(panel.label.fancycolor or Color(255, 255, 255))
		end
	
		if self:GetChecked() then
			surface.DrawRect(3, 3, w-6, h-6)
		end

		surface.DrawOutlinedRect(0, 0, w, h)
	end

	if not gwater2.parameters[parameter_id] then
		gwater2.parameters[parameter_id] = check:GetChecked()
		gwater2.defaults[parameter_id] = check:GetChecked()
	end

	panel:SetTall(panel:GetTall()+5)

	return panel
end

return {
	make_title_label=make_title_label,
	make_parameter_check=make_parameter_check,
	make_parameter_color=make_parameter_color,
	make_parameter_scratch=make_parameter_scratch,
	set_gwater_parameter=set_gwater_parameter,
	get_localised=get_localised,
	emit_sound=emit_sound,
	is_hovered_any=is_hovered_any
}
