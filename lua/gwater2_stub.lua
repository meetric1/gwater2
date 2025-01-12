------- FLEX SOLVER --------
local flexsolver_stub = {plimit = 0, flimit = 0, pcur = 0, fcur = 0, parms = {}}

function FlexSolver(part_limit, foam_limit)
    local flexsolver = table.Copy(flexsolver_stub)
    flexsolver.plimit = part_limit
    flexsolver.flimit = foam_limit or part_limit
    flexsolver.pcur = math.floor(part_limit / 2)
    return flexsolver    
end

-- destroy, bounds and tick
function flexsolver_stub:Destroy() end
function flexsolver_stub:InitBounds(mins, maxs) end
function flexsolver_stub:Tick(delta) end

-- collider stubs
function flexsolver_stub:AddMapCollider(idx, mapname) end
function flexsolver_stub:AddConcaveCollider(idx, concave) end
function flexsolver_stub:AddConvexCollider(idx, convex) end
function flexsolver_stub:RemoveCollider(idx) end

function flexsolver_stub:SetColliderEnabled(idx, enabled) end
function flexsolver_stub:SetColliderPos(idx, pos) end
function flexsolver_stub:SetColliderAng(idx, ang) end

function flexsolver_stub:ApplyContacts(radius, dampening1, buoyancy, dampening2) end
function flexsolver_stub:IterateColliders(iterator) end

-- particle count
function flexsolver_stub:GetMaxDiffuseParticles() return self.flimit end
function flexsolver_stub:GetMaxParticles() return self.plimit end
function flexsolver_stub:GetActiveDiffuseParticles() return self.fcur end
function flexsolver_stub:GetActiveParticles() return self.pcur end
function flexsolver_stub:GetParticlesInRadius(pos, radius) return 0 end

-- parameters
function flexsolver_stub:GetParameter(name) return self.parms[name] or 0 end
function flexsolver_stub:SetParameter(name, val) self.parms[name] = val end
function flexsolver_stub:EnableDiffuse(enable) end

-- reset
function flexsolver_stub:Reset() self.fcur = 0 self.pcur = 0 end
function flexsolver_stub:ResetCloth() end

-- add
function flexsolver_stub:AddCloth(mtrx, size, xtra) end
function flexsolver_stub:AddParticle(pos, xtra) end
function flexsolver_stub:AddCylinder(mtrx, size, xtra) end
function flexsolver_stub:AddCube(mtrx, size, xtra) end
function flexsolver_stub:AddSphere(mtrx, radius, xtra) end
function flexsolver_stub:AddForcefield(pos, radius, strength, mode, linear) end

-- draw
function flexsolver_stub:RenderParticles(iterator) end
------ FLEX SOLVER END ------

------- FLEX RENDERER -------
local flexrenderer_stub = {}

function FlexRenderer()
    local flexrenderer = table.Copy(flexrenderer_stub)
    return flexrenderer
end

-- draw stuff
function flexrenderer_stub:DrawCloth() end
function flexrenderer_stub:DrawWater() end
function flexrenderer_stub:DrawDiffuse() end

-- build meshes
function flexrenderer_stub:BuildMeshes(solver, diffuse_radius, cull) end
----- FLEX RENDERER END -----

----- RANDOM FUNCTIONS ------
function GWATER2_SET_CONTACTS(idx, contacts) end