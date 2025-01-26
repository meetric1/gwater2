AddCSLuaFile()
local checkluatype = SF.CheckLuaType
local registerprivilege = SF.Permissions.registerPrivilege

-- TODO: rewrite? not sure if that's compatible with modern gw2

--- Library for using gwater2
-- @name gwaterlib
-- @class library
-- @libtbl gwater_library
SF.RegisterLibrary("gwaterlib")

local function main(instance)
	local gwater_library = instance.Libraries.gwaterlib
	local vec_meta, vwrap, vunwrap = instance.Types.Vector, instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap
	--- Spawns a GWater particle
	-- @client
	-- @param Vector pos
	-- @param Vector vel
	function gwater_library.addParticle(pos, vel)
		if LocalPlayer() == instance.player then
			gwater2.solver:AddParticle(vunwrap(pos), vunwrap(vel), 1, 1)
		end
	end

	--- Spawns a GWater particle cube
	-- @client
	-- @param Vector pos
	-- @param Vector vel
	-- @param Vector size
	-- @param number apart
	function gwater_library.addCube(pos, vel, size, apart)
		if LocalPlayer() == instance.player then
			gwater2.solver:AddCube(vunwrap(pos), vunwrap(vel), vunwrap(size), apart)
		end
	end

	--- Clears All Gwater
	-- @client
	function gwater_library.clearAllParticles()
		if LocalPlayer() == instance.player then
			gwater2.solver:Reset()
		end
	end

	--- Changes the chosen Gwater parameter.
	-- @client
	-- @param string parameter
	-- @param number value
	function gwater_library.setParameter(parameter, value)
		if LocalPlayer() == instance.player then
			gwater2.solver:SetParameter(parameter, value)
		end
	end

	--- Gets the chosen Gwater parameter.
	-- @client
	-- @param string parameter
	-- @return number value
	function gwater_library.getParameter(parameter)
		if LocalPlayer() == instance.player then
			return gwater2.solver:GetParameter(parameter)
		end
	end

	--- Applies a force field to GWater particles
	-- @client
	-- @param Vector pos The position of the force field
	-- @param number radius The radius of the force field
	-- @param number strength The strength of the force field
	-- @param number mode The mode of the force field. 0 = Attraction, 1 = Repulsion, 2 = Vortex
	-- @param boolean linear Whether the force field should be the same strength regardless of distance
	function gwater_library.applyForceField(pos, radius, strength, mode, linear)
		if LocalPlayer() == instance.player then
			gwater2.solver:AddForceField(vunwrap(pos), radius, strength, mode, linear)
		end
	end

	--- Called before the GWater solver ticks
	-- You should use this hook to apply forces to the particles
	-- @name gwater2_pretick
	-- @class hook
	-- @client
	SF.hookAdd("gwater2_pretick")
end

return main
