AddCSLuaFile()

if SERVER or not gwater2 then return end

if gwater2.__PARAMS__ then return gwater2.__PARAMS__ end

local styling = include("menu/gwater2_styling.lua")
local _util = include("menu/gwater2_util.lua")

local parameters = {
	["001-Physics Parameters"] = {
		["001-Adhesion"] = {
			min=0,
			max=0.2,
			decimals=3,
			type="scratch"
		},
		["002-Cohesion"] = {
			min=0,
			max=2,
			decimals=3,
			type="scratch"
		},
		["003-Radius"] = {
			min=1,
			max=100,
			decimals=1,
			type="scratch"
		},
		["004-Gravity"] = {
			min=-30.48,
			max=30.48,
			decimals=2,
			type="scratch"
		},
		["005-Viscosity"] = {
			min=0,
			max=20,
			decimals=2,
			type="scratch"
		},
		["006-Surface Tension"] = {
			min=0,
			max=1,
			decimals=3,
			type="scratch"
		},
		["007-Timescale"] = {
			min=0,
			max=2,
			decimals=3,
			type="scratch"
		}
	},
	["002-Advanced Physics Parameters"] = {
		["002-Collision Distance"] = {
			min=0.1,
			max=1,
			decimals=2,
			type="scratch"
		},
		["001-Fluid Rest Distance"] = {
			min=0.55,
			max=0.85,
			decimals=2,
			type="scratch"
		},
		["003-Dynamic Friction"] = {
			min=0,
			max=1,
			decimals=2,
			type="scratch"
		},
		["004-Vorticity Confinement"] = {
			min=0,
			max=200,
			decimals=0,
			type="scratch"
		}
	},
	["003-Sound Parameters"] = {
		["001-Sound Pitch"] = {
			min=0,
			max=2,
			decimals=2,
			type="scratch",
			setup = function(slider)
				slider:SetValue(gwater2.parameters.sound_pitch)
			end,
			func = function(val)
				return true
			end
		},
		["002-Sound Volume"] = {
			min=0,
			max=2,
			decimals=2,
			type="scratch",
			setup = function(slider)
				slider:SetValue(gwater2.parameters.sound_volume)
			end,
			func = function(val)
				return true
			end
		},
	}
}
local visuals = {
	["001-Diffuse Threshold"] = {
		min=1,
		max=500,
		decimals=1,
		type="scratch"
	},
	["002-Diffuse Lifetime"] = {
		min=0,
		max=20,
		decimals=1,
		type="scratch"
	},
	["006-Color"] = {
		type="color",
		setup=function(mixer)
			mixer:SetColor(gwater2.parameters.color)
		end,
		func=function(col)
			local finalpass = Material("gwater2/finalpass")
			finalpass:SetVector4D("$color2", 
				col.r * gwater2.parameters.color_value_multiplier,
				col.g * gwater2.parameters.color_value_multiplier,
				col.b * gwater2.parameters.color_value_multiplier,
				col.a
			)
			return true
		end
	},
	["007-Color Value Multiplier"] = {
		type="scratch",
		min=0,
		max=3,
		decimals=2,
		setup=function(scratch)
			scratch:SetValue(gwater2.parameters.color_value_multiplier)
		end,
		func=function(val)
			local col = gwater2.parameters.color
			local finalpass = Material("gwater2/finalpass")
			finalpass:SetVector4D("$color2", 
				col.r * val, 
				col.g * val, 
				col.b * val, 
				col.a
			)
			return true
		end
	},
	["008-Reflectance"] = {
		type="scratch",
		min=1,
		max=10,
		decimals=3,
		func=function(val)
			local finalpass = Material("gwater2/finalpass")
			finalpass:SetFloat("$ior", val)
			return true
		end,
		setup=function(slider)
			local finalpass = Material("gwater2/finalpass")
			slider:SetValue(finalpass:GetFloat("$ior"))
			return true
		end
	}
}

local performance = {
	["001-Physics"] = {
		["001-Iterations"] = {
			min=1,
			max=10,
			decimals=0,
			type="scratch",
			nosync=true,
			setup = function(slider)
				local label = slider:GetParent().label
				label.fancycolor = Color(250, 250, 0)
				label.fancycolor_hovered = Color(255, 255, 200)
				label:SetColor(label.fancycolor)
			end
		},
		["002-Substeps"] = {
			min=1,
			max=10,
			decimals=0,
			type="scratch",
			nosync=true,
			setup = function(slider)
				local label = slider:GetParent().label
				label.fancycolor = Color(255, 127, 0)
				label.fancycolor_hovered = Color(255, 200, 127)
				label:SetColor(label.fancycolor)
			end
		},
		["004-Particle Limit"] = {
			min=1,
			max=1000000,
			decimals=-3,
			type="scratch",
			nosync=true,
			func=function(_) return true end,
			setup=function(slider)
				local label = slider:GetParent().label
				label.fancycolor = Color(255, 0, 0)
				label.fancycolor_hovered = Color(255, 127, 127)
				label:SetColor(label.fancycolor)

				slider:SetValue(gwater2.solver:GetMaxParticles())
				local panel = slider:GetParent()
				local button = panel:Add("DImageButton")
				button:Dock(RIGHT)
				button:SetImage("icon16/accept.png")
				button:SizeToContents()
				button:SetKeepAspect(true)
				button:SetStretchToFit(false)
				button.Paint = nil
				panel.button_apply = button
				function button:DoClick()
					local frame = styling.create_blocking_frame()
					frame:SetSize(600, 300)
					frame:Center()
					frame:SetScreenLock(false)
					frame:ShowCloseButton(false)

					local label = frame:Add("DLabel")
					label:Dock(TOP)
					label:SetText(_util.get_localised("Performance.Particle Limit.title", math.floor(slider:GetValue())))
					label:SetFont("GWater2Title")
					label:SizeToContentsY()
					label.text = label:GetText()
					label:SetText("")
					function label:Paint(w, h) draw.DrawText(self.text, self:GetFont(), w / 2, 0, color_white, TEXT_ALIGN_CENTER) end

					local label2 = frame:Add("DLabel")
					label2:Dock(TOP)
					label2:SetText("\n" .. _util.get_localised("Performance.Particle Limit.warning"))
					label2:SetFont("DermaDefault")
					label2:SizeToContentsY()
					label2.text = label2:GetText()
					label2:SetText("")
					function label2:Paint(w, h) draw.DrawText(self.text, self:GetFont(), w / 2, 0, color_white, TEXT_ALIGN_CENTER) end

					local buttons = frame:Add("DPanel")
					function buttons:Paint() end
					buttons:Dock(BOTTOM)

					local confirm = vgui.Create("DImageButton", buttons)
					confirm:SetPos(600 * (3/4) - 10, 0)
					confirm:SetSize(20, 20)
					confirm:SetText("5")
					confirm:SetFont("GWater2TextMono")
					confirm:SetKeepAspect(true)
					confirm.Paint = nil
					function confirm:DoClick() 
						gwater2.solver:Destroy()
						gwater2.solver = FlexSolver(slider:GetValue())
						for name, value in pairs(gwater2.parameters) do
							_util.set_gwater_parameter(name, value)
						end
						gwater2.reset_solver(true)
						frame:Close()
						_util.emit_sound("select_ok")
					end

					confirm:SetEnabled(false)
					confirm:SetColor(Color(255, 255, 255))
					for i=1, 4 do
						timer.Simple(i, function()
							if not IsValid(confirm) then return end
							confirm:SetText(tostring(5-i))
						end)
					end
					timer.Simple(5, function()
						if not IsValid(confirm) then return end
						confirm:SetImage("icon16/accept.png")
						confirm:SetText("")
						confirm:SetEnabled(true)
					end)

					local deny = vgui.Create("DImageButton", buttons)
					deny:SetPos(600 * (1/4) - 10, 0)
					deny:SetSize(20, 20)
					deny:SetKeepAspect(true)
					deny:SetImage("icon16/cross.png")
					deny.Paint = nil
					function deny:DoClick() 
						frame:Close()
						_util.emit_sound("select_deny")
					end

					_util.emit_sound("confirm")
				end
			end
		},
		["003-Simulation FPS"] = {
			min=30,
			max=120,
			decimals=-1,
			type="scratch",
			nosync=true,
			func=function(n)
				gwater2.options.simulation_fps:SetInt(n)
				timer.Adjust("gwater2_tick", 1 / n)

				return true
			end,
			setup=function(slider)
				slider:SetValue(gwater2.options.simulation_fps:GetInt())

				local label = slider:GetParent().label
				label.fancycolor = Color(255, 127, 0)
				label.fancycolor_hovered = Color(255, 200, 127)
				label:SetColor(label.fancycolor)
			end
		},	
		["005-Player Collision"] = {
			type="check",
			nosync=true,
			func=function(val)
				gwater2.options.player_collision:SetBool(val)
				net.Start("GWATER2_REQUESTCOLLISION")
				net.WriteBool(val)
				net.SendToServer()
				return true
			end,
			setup=function(check)
				local label = check:GetParent().label
				label.fancycolor = Color(127, 255, 0)
				label.fancycolor_hovered = Color(200, 255, 127)
				label:SetColor(label.fancycolor)

				check:SetValue(gwater2.options.player_collision:GetBool())
			end
		},
	},
	["002-Visuals"] = {
		["006-Blur Passes"] = {
			min=0,
			max=4,
			decimals=0,
			type="scratch",
			nosync=true,
			func=function(n)
				gwater2.options.blur_passes:SetInt(n)
				return true
			end,
			setup=function(slider)
				slider:SetValue(gwater2.options.blur_passes:GetInt())

				local label = slider:GetParent().label
				label.fancycolor = Color(127, 255, 0)
				label.fancycolor_hovered = Color(200, 255, 150)
				label:SetColor(label.fancycolor)
			end
		},
		["005-Mirror Rendering"] = {
			min=0,
			max=2,
			decimals=0,
			type="scratch",
			nosync=true,
			func=function(n)
				gwater2.options.render_mirrors:SetInt(n)
				return true
			end,
			setup=function(slider)
				slider:SetValue(gwater2.options.render_mirrors:GetInt())

				local label = slider:GetParent().label
				label.fancycolor = Color(255, 255, 0)
				label.fancycolor_hovered = Color(255, 255, 200)
				label:SetColor(label.fancycolor)
			end
		},
		["007-Absorption"] = {
			type="check",
			nosync=true,
			func=function(val)
				local water_volumetric = Material("gwater2/volumetric")
				gwater2.options.absorption:SetBool(val)
				water_volumetric:SetFloat("$alpha", val and 0.125 or 0)
				return true
			end,
			setup=function(check)
				local label = check:GetParent().label
				label.fancycolor = Color(255, 255, 0)
				label.fancycolor_hovered = Color(255, 255, 200)
				label:SetColor(label.fancycolor)

				check:SetValue(gwater2.options.absorption:GetBool())
			end
		},
		["008-Depth Fix"] = {
			type="check",
			nosync=true,
			func=function(val)
				local water_normals = Material("gwater2/normals")
				gwater2.options.depth_fix:SetBool(val)
				water_normals:SetInt("$depthfix", val and 1 or 0)
				return true
			end,
			setup=function(check)
				local label = check:GetParent().label
				label.fancycolor = Color(255, 127, 0)
				label.fancycolor_hovered = Color(255, 200, 127)
				label:SetColor(label.fancycolor)

				check:SetValue(gwater2.options.depth_fix:GetBool())
			end
		},
		["010-Diffuse Enabled"] = {
			type="check",
			nosync=true,
			func=function(val)
				gwater2.solver:EnableDiffuse(val)
				gwater2.solver:ResetDiffuse()
				gwater2.options.diffuse_enabled:SetBool(val)
				return true
			end,
			setup=function(check)
				local label = check:GetParent().label
				label.fancycolor = Color(255, 255, 0)
				label.fancycolor_hovered = Color(255, 255, 200)
				label:SetColor(label.fancycolor)

				check:SetValue(gwater2.options.diffuse_enabled:GetBool())
			end
		}
	}
}
local interaction = {
	["001-Reaction Force Parameters"] = {
		["001-Reaction Forces"] = {
			type="check",
			func = function(val) 
				gwater2.solver:SetParameter("reaction_forces", val and 1 or 0)
				return true 
			end,
			setup=function(check) 
				check:SetChecked(gwater2.solver:GetParameter("reaction_forces") != 0) 
			end
		},
		["002-Force Multiplier"] = {
			min=0.001,
			max=0.025,
			decimals=3,
			type="scratch",
			func = function(val) return true end,
			setup = function(scratch) scratch:SetValue(gwater2.parameters.force_multiplier) end
		},
		["003-Force Buoyancy"] = {
			min=0,
			max=500,
			decimals=1,
			type="scratch",
			func = function(val) return true end,
			setup = function(scratch) scratch:SetValue(gwater2.parameters.force_buoyancy) end
		},
		["004-Force Dampening"] = {
			min=0,
			max=1,
			decimals=2,
			type="scratch",
			func = function(val) return true end,
			setup = function(scratch) scratch:SetValue(gwater2.parameters.force_dampening) end
		}
	},
	["002-Water Interactions"] = {
		["001-Player Interaction"] = {
			type="check",
			func = function(val) return true end,
			setup = function(check) check:SetValue(gwater2.parameters.player_interaction) end
		},
		-- all of these parameters are server-side only. let's tell our code that we handled them already
		["003-SwimSpeed"] = {
			type="scratch",
			min=-20,
			max=100,
			decimals=0,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['swimspeed'] or scratch:GetValue()) end
		},
		["004-SwimFriction"] = {
			type="scratch",
			min=0,
			max=0.75,
			decimals=3,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['swimfriction'] or scratch:GetValue()) end
		},
		["005-SwimBuoyancy"] = {
			type="scratch",
			min=-2,
			max=2,
			decimals=2,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['swimbuoyancy'] or scratch:GetValue()) end
		},
		["002-MultiplyParticles"] = {
			type="scratch",
			min=0,
			max=200,
			decimals=0,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['multiplyparticles'] or scratch:GetValue()) end
		},
		["008-MultiplyWalk"] = {
			type="scratch",
			min=0,
			max=2,
			decimals=2,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['multiplywalk'] or scratch:GetValue()) end
		},
		["009-MultiplyJump"] = {
			type="scratch",
			min=0,
			max=2,
			decimals=2,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['multiplyjump'] or scratch:GetValue()) end
		},
		["010-TouchDamage"] = {
			type="scratch",
			min=-10,
			max=10,
			decimals=0,
			func=function(val) return true end,
			setup=function(scratch) scratch:SetValue(gwater2.parameters['touchdamage'] or scratch:GetValue()) end
		},
	}
}
local developer = {
	["001-Anisotropy Scale"] = {
		min=0,
		max=2,
		decimals=2,
		type="scratch"
	},
	["002-Anisotropy Min"] = {
		min=-0.1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["003-Anisotropy Max"] = {
		min=0,
		max=2,
		decimals=2,
		type="scratch"
	},
	["004-static_friction"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["006-particle_friction"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["007-free_surface_drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["008-drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["009-lift"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["010-solid_rest_distance"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["011-smoothing"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["012-dissipation"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["013-damping"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["014-particle_collision_margin"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["015-shape_collision_margin"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["016-sleep_threshold"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["017-shock_propagation"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["018-restitution"] = {
		min=-10,
		max=10,
		decimals=2,
		type="scratch"
	},
	["019-max_speed"] = {
		min=-1e5,
		max=1e5,
		decimals=2,
		type="scratch"
	},
	["020-max_acceleration"] = {
		min=-1e5,
		max=1e5,
		decimals=2,
		type="scratch"
	},
	["022-solid_pressure"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["023-buoyancy"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["024-diffuse_buoyancy"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["025-diffuse_drag"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["026-relaxation_mode"] = {
		min=0,
		max=1,
		decimals=0,
		type="scratch"
	},
	["027-relaxation_factor"] = {
		min=-1,
		max=1,
		decimals=2,
		type="scratch"
	},
	["028-Show absorption debug"] = {
		type="check",
		func = function(val) GetConVar("gwater2_debug_absorption"):SetBool(val) return true end,
		setup = function(check) check:SetValue(GetConVar("gwater2_debug_absorption"):GetBool()) end
	},
	["030-Show mipmap debug"] = {
		type="check",
		func = function(val) GetConVar("gwater2_debug_mipmap"):SetBool(val) return true end,
		setup = function(check) check:SetValue(GetConVar("gwater2_debug_mipmap"):GetBool()) end
	},
	["031-Show normals debug"] = {
		type="check",
		func = function(val) GetConVar("gwater2_debug_normals"):SetBool(val) return true end,
		setup = function(check) check:SetValue(GetConVar("gwater2_debug_normals"):GetBool()) end
	},
}

gwater2.__PARAMS__ = {Parameters=parameters, Visuals=visuals, Performance=performance, Interactions=interaction, Developer=developer}
return gwater2.__PARAMS__