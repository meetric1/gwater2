local params = include("menu/gwater2_params.lua")
local styling = include("menu/gwater2_styling.lua")
local util = include("menu/gwater2_util.lua")

local function init_tab_params(tabs, tab, tab_name, sname, sec, added_params, recursive)
	local pan = tab:Add("Panel")
	pan.help_text = tabs.help_text
	function pan:Paint(w, h) styling.draw_main_background(0, 0, w, h) end

	if recursive then
		util.make_title_label(pan, util.get_localised(tab_name .. "." .. sname:sub(5))).realkey = sname
	end

	for name, param in SortedPairs(sec) do
		if param.type == "scratch" then
			added_params[name:sub(5)] = util.make_parameter_scratch(pan, tab_name .. "." .. name:sub(5), name:sub(5), param)
		elseif param.type == "color" then
			added_params[name:sub(5)] = util.make_parameter_color(pan, tab_name .. "."..name:sub(5), name:sub(5), param)
		elseif param.type == "check" then
			added_params[name:sub(5)] = util.make_parameter_check(pan, tab_name .. "."..name:sub(5), name:sub(5), param)
		else
			error("got unknown parameter type in " .. tab_name .. " menu generation")
		end
	end

	local ttall = pan:GetTall()+5
	for _, i in pairs(pan:GetChildren()) do
		ttall = ttall + i:GetTall()
	end

	ttall = ttall - 20
	pan:SetTall(ttall)
	pan:Dock(TOP)
	pan:InvalidateChildren()
	pan:DockMargin(5, 5, 5, 5)
	pan:DockPadding(5, 5, 5, 5)
end

local function init_tab(tabs, tab_name, image, recursive)
	local tab = vgui.Create("DPanel", tabs)
	function tab:Paint() end
	tabs:AddSheet(util.get_localised(tab_name .. ".title"), tab, image).Tab.realname = tab_name
	tab = tab:Add("DScrollPanel")
	tab:Dock(FILL)

	styling.define_scrollbar(tab:GetVBar())

	local _ = tab:Add("DLabel") _:SetText(" ") _:SetFont("GWater2Title") _:Dock(TOP) _:SizeToContents() _:SetTall(_:GetTall() + 5)
	function _:Paint(w, h)
		draw.DrawText(util.get_localised(tab_name .. ".titletext"), "GWater2Title", 6, 6, Color(0, 0, 0), TEXT_ALIGN_LEFT)
		draw.DrawText(util.get_localised(tab_name .. ".titletext"), "GWater2Title", 5, 5, Color(187, 245, 255), TEXT_ALIGN_LEFT)
	end

	-- TODO: genuinely horrific code
	local added_params = {}
	if recursive then 
		for sname, sec in SortedPairs(params[tab_name]) do
			init_tab_params(tabs, tab, tab_name, sname, sec, added_params, true)
		end
	else
		init_tab_params(tabs, tab, tab_name, nil, params[tab_name], added_params, false)
	end
	
	return added_params, tab
end

local function parameters_tab(tabs)
	return init_tab(tabs, "Parameters", "icon16/cog.png", true)
end

local function visuals_tab(tabs)
	return init_tab(tabs, "Visuals", "icon16/picture.png")
end

local function performance_tab(tabs)
	return init_tab(tabs, "Performance", "icon16/application_xp_terminal.png", true)
end

local function interaction_tab(tabs)
	return init_tab(tabs, "Interactions", "icon16/chart_curve.png", true)
end

local function developer_tab(tabs)
	return init_tab(tabs, "Developer", "icon16/bug.png")
end

return {
	parameters_tab=parameters_tab,
	visuals_tab=visuals_tab,
	performance_tab=performance_tab,
	interaction_tab=interaction_tab,
	developer_tab=developer_tab
}