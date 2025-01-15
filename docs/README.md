# GWater 2 Public API

![cl] `gwater2.solver: FlexSolver` \
&nbsp;&nbsp;   FlexSolver used for world water. \
![cl] `gwater2.renderer: FlexRenderer` \
&nbsp;&nbsp;   FlexRenderer used for world water.

![cl] `gwater2.reset_solver(err: boolean)` \
&nbsp;&nbsp;   Creates map collider and initializes world bounds. \
![sh] `gwater2.quick_matrix(pos: Vector?, ang: Angle?, scale: number?) -> VMatrix: mtrx` \
&nbsp;&nbsp;   Creates quick matrix.

![sv] `gwater2.ChangeParameter(parameter: string, value: any, final: boolean, sender: Player?)` \
&nbsp;&nbsp;   Gets parameter' value from solver. \
&nbsp;&nbsp;   See below for valid parameter list.

![sh] `gwater2.ResetSolver()` \
&nbsp;&nbsp;   Resets solver on every client, removing all regular and diffuse particles. \
![sh] `gwater2.RemoveCloth()` \
&nbsp;&nbsp;   Resets solver cloth on every client, removing all regular particles associated with cloth.

![sv] `gwater2.AddCloth(mtrx: VMatrix, size: Vector, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds cloth. \
&nbsp;&nbsp;   Matrix translation specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![sv] `gwater2.AddParticle(pos: Vector, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds a single particle. \
![sv] `gwater2.AddCylinder(mtrx: VMatrix, size: number, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds cylinder of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![sv] `gwater2.AddCube(mtrx: VMatrix, size: number, particle_data: ParticleData?))` \
&nbsp;&nbsp;   Adds cube of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![sv] `gwater2.AddSphere(mtrx: VMatrix, radius: number, particle_data: ParticleData?))` \
&nbsp;&nbsp;   Adds sphere of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
![sv] `gwater2.AddForceField(pos: Vector, radius: number, strength: number, mode: integer, linear: boolean)` \
&nbsp;&nbsp;   Adds particle forcefield. \
![sv] `gwater2.AddModel(mtrx: VMatrix, model: string, particle_data: ParticleData?) -> boolean: success` \
&nbsp;&nbsp;   Adds particles in form of model. \
![sv] `gwater2.RemoveSphere(mtrx: VMatrix)` \
&nbsp;&nbsp;   **THIS IS NOT AN ACTUAL FUNCTION YET** \
&nbsp;&nbsp;   Removes sphere of particles. \
&nbsp;&nbsp;   Matrix translarion specifies position. \
&nbsp;&nbsp;   Matrix scale specifies size. \
![sv] `gwater2.RemoveCube(mtrx: VMatrix)` \
&nbsp;&nbsp;   **THIS IS NOT AN ACTUAL FUNCTION YET** \
&nbsp;&nbsp;   Removes cube of particles. \
&nbsp;&nbsp;   Matrix translarion specifies position. \
&nbsp;&nbsp;   Matrix scale specifies size.

# GWater 2 Internal API
## ![cl] FlexSolver
![cl] `FlexSolver(limit: integer, diffuse_limit: integer?) -> FlexSolver: solver` \
&nbsp;&nbsp;   Creates new FlexSolver object with specified max particle and diffuse limits. \
&nbsp;&nbsp;   If `diffuse_limit` is unspecified, defaults to `limit`

![cl] `FlexSolver:Destroy()` \
&nbsp;&nbsp;   Destroys FlexSolver, freeing up all buffers and removing all particles. \
&nbsp;&nbsp;   Trying to use destroyed FlexSolver will result in nil index errors. \
![cl] `FlexSolver:InitBounds(mins: Vector, maxs: Vector)` \
&nbsp;&nbsp;   Initialises simulation bounds. Particles won't be able to leave this space. \
![cl] `FlexSolver:Tick(delta: number) -> boolean: ticked` \
&nbsp;&nbsp;   Ticks solver with specified delta (time that has passed since last tick, in seconds). \
&nbsp;&nbsp;   Parameters may behave incorrectly with different deltas. \
&nbsp;&nbsp;   High or low deltas can result in particles passing through stuff or becoming invalid.

![cl] `FlexSolver:AddMapCollider(idx: integer, mapname: string)` \
&nbsp;&nbsp;   Attempts to add a collider from map bsp. \
![cl] `FlexSolver:AddConcaveCollider(idx: integer, concave: table<Vector>, pos: Vector?, ang: Angle?)` \
&nbsp;&nbsp;   Adds concave collider. \
&nbsp;&nbsp;   `concave` parameter has to be a sequential table with length divisible by 3, with each 3 vertices specifying a triangle. \
![cl] `FlexSolver:AddConvexCollider(idx: integer, convex: table<Vector>, pos: Vector?, ang: Angle?)` \
&nbsp;&nbsp;   Adds a convex collider. \
&nbsp;&nbsp;   `convex` parameter has to be a sequential table with length divisible by 3, with each 3 vertices specifying a triangle. \
![cl] `FlexSolver:RemoveCollider(idx: integer)`
&nbsp;&nbsp;   Removes collider with specified index. \
&nbsp;&nbsp;   Does nothing if collider doesn't exist.

![cl] `FlexSolver:SetColliderEnabled(idx: integer, enabled: bool)` \
&nbsp;&nbsp;   Enables collider. \
![cl] `FlexSolver:SetColliderPos(idx: integer, pos: Vector, dont_lerp: boolean?)` \
&nbsp;&nbsp;   Sets collider position, telling FleX that it moved unless `dont_lerp` is true. \
![cl] `FlexSolver:SetColliderAng(idx: integer, ang: Angle, dont_lerp: boolean?)` \
&nbsp;&nbsp;   Sets collider angle, telling FleX that it rotated unless `dont_lerp` is true.

![cl] `FlexSolver:ApplyContacts(radius: unknown, dampening1: unknown, buoyancy: unknown, dampening2: unknown)` \
&nbsp;&nbsp;   TODO: Write description. \
![cl] `FlexSolver:IterateColliders(iterator: unknown)` \
&nbsp;&nbsp;   TODO: Write description.

![cl] `FlexSolver:GetMaxDiffuseParticles() -> integer: max_diffuse` \
&nbsp;&nbsp;   Returns solver' diffuse particles limit. \
![cl] `FlexSolver:GetMaxParticles() -> integer: max_particles` \
&nbsp;&nbsp;   Returns solver' regular particles limit. \
![cl] `FlexSolver:GetActiveDiffuseParticles() -> integer: active_diffuse` \
&nbsp;&nbsp;   Returns active (alive and simulated) diffuse particles count. \
&nbsp;&nbsp;   This will sometimes return the previous active value after a solver reset. \
&nbsp;&nbsp;   To get around this, do a check with normal particles: \
```lua
 local diffuse = solver:GetActiveDiffuseParticles()
 if solver:GetActiveParticles() <= 0 then
     diffuse = 0
 end
```
![cl] `FlexSolver:GetActiveDiffuseParticlesPos() -> Vector: pos` \
&nbsp;&nbsp;   Gets average position of all active (alive and simulated) diffuse particles. \
![cl] `FlexSolver:GetActiveParticles() -> integer: active_particles` \
&nbsp;&nbsp;   Returns active (alive and simulated) regular particles count. \
![cl] `FlexSolver:GetParticlesInRadius(pos: Vector, radius: number, search_limit: integer?) -> integer: in_radius` \
&nbsp;&nbsp;   Returns amount of particles in `radius` near `pos`. \
&nbsp;&nbsp;   `search_limit` limits amount of particles returned, increasing performance.

![cl] `FlexSolver:GetParameter(parameter: string) -> number: value` \
&nbsp;&nbsp;   Gets parameter' value from solver. Will error if parameter is invalid.\
&nbsp;&nbsp;   See below for valid parameters. \
![cl] `FlexSolver:SetParameter(parameter: string, value: number)` \
&nbsp;&nbsp;   Sets parameter' value in solver. Will error if parameter is invalid. \
&nbsp;&nbsp;   See below for valid parameters. \
![cl] `FlexSolver:EnableDiffuse(enable: boolean)` \
&nbsp;&nbsp;   Enables or disables diffuse particles.

![cl] `FlexSolver:Reset()` \
&nbsp;&nbsp;   Resets solver, removing all regular and diffuse particles. \
![cl] `FlexSolver:ResetCloth()` \
&nbsp;&nbsp;   Resets solver cloth, removing all regular particles associated with cloth. \
![cl] `FlexSolver:ResetDiffuse()` \
&nbsp;&nbsp;   Resets solver diffuse particles, removing all of them. \

![cl] `FlexSolver:AddCloth(mtrx: VMatrix, size: Vector, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds cloth. \
&nbsp;&nbsp;   Matrix translarion specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![cl] `FlexSolver:AddParticle(pos: Vector, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds a single particle. \
![cl] `FlexSolver:AddCylinder(mtrx: VMatrix, size: number, particle_data: ParticleData?)` \
&nbsp;&nbsp;   Adds cylinder of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![cl] `FlexSolver:AddCube(mtrx: VMatrix, size: number, particle_data: ParticleData?))` \
&nbsp;&nbsp;   Adds cube of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
&nbsp;&nbsp;   Matrix rotation specifies rotation. \
![cl] `FlexSolver:AddSphere(mtrx: VMatrix, radius: number, particle_data: ParticleData?))` \
&nbsp;&nbsp;   Adds sphere of particles. \
&nbsp;&nbsp;   Matrix translation specifies position. \
![cl] `FlexSolver:AddForceField(pos: Vector, radius: number, strength: number, mode: integer, linear: boolean)` \
&nbsp;&nbsp;   Adds particle forcefield. \
![cl] `FlexSolver:AddMesh(mtrx: VMatrix, mesh: table<Vector>, particle_data: ParticleData?) -> boolean: success` \
&nbsp;&nbsp;   Adds mesh...? \
&nbsp;&nbsp;   TODO: Do further testing. \
![cl] `FlexSolver:RemoveSphere(mtrx: VMatrix)` \
&nbsp;&nbsp;   Removes sphere of particles. \
&nbsp;&nbsp;   Matrix translarion specifies position. \
&nbsp;&nbsp;   Matrix scale specifies size. \
![cl] `FlexSolver:RemoveCube(mtrx: VMatrix)` \
&nbsp;&nbsp;   Removes cube of particles. \
&nbsp;&nbsp;   Matrix translarion specifies position. \
&nbsp;&nbsp;   Matrix scale specifies size.

![cl] `FlexSolver:RenderParticles(iterator: fun(pos: Vector))` \
&nbsp;&nbsp;   Iterates over all particle and calls a function to render particles.

## FlexRenderer
![cl] `FlexRenderer() -> FlexRenderer: renderer` \
&nbsp;&nbsp;   Creates new FlexRenderer object.

![cl] `FlexRenderer:BuildMeshes(solver: FlexSolver, diffuse_radius: radius, cull: boolean)` \
&nbsp;&nbsp;   Builds meshes of FlexSolver object. \
![cl] `FlexRenderer:DrawCloth()` \
&nbsp;&nbsp;   Draws cloth meshes. \
![cl] `FlexRenderer:DrawWater()` \
&nbsp;&nbsp;   Draws water meshes. \
![cl] `FlexRenderer:DrawDiffuse()` \
&nbsp;&nbsp;   Draws diffuse meshes.

## Utilities
![cl] `GWATER2_SET_CONTACTS(entindex: integer, contacts: integer)` \
&nbsp;&nbsp;   Will actually work only if client is listen server host. \
&nbsp;&nbsp;   Sets `Entity(entindex).GWATER2_CONTACTS` on server without networking.

[sv]: https://i.imgur.com/ms7VOvb.png "Server"
[sh]: https://i.imgur.com/OEu9WCI.png "Shared"
[cl]: https://i.imgur.com/Ob2t9EU.png "Client"
