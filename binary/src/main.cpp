// bsp parser requirements
// this MUST BE included before everything else because of conflicting source defines
#include "GMFS.h"
#include "BSPParser.h"

#include "GarrysMod/Lua/LuaShared.h"
#include "GarrysMod/Lua/Interface.h"

#include "flex_solver.h"
#include "flex_renderer.h"
#include "shader_inject.h"
#include "cdll_client_int.h"

#include "scanning/symbolfinder.hpp"	// for reaction forces

using namespace GarrysMod::Lua;

NvFlexLibrary* FLEX_LIBRARY = nullptr;	// "The heart of all that is FleX" - AE
ILuaShared* GLOBAL_LUA;			// used for flex error handling
int FLEXSOLVER_METATABLE = 0;
int FLEXRENDERER_METATABLE = 0;

typedef void* (__cdecl* UTIL_EntityByIndexFN)(int);
UTIL_EntityByIndexFN UTIL_EntityByIndex = nullptr;

float CM_2_INCH = 2.54 * 2.54;	// FleX is in centimeters, source is in inches. We need to convert units

/************************** Flex Solver LUA Interface *******************************/

#define GET_FLEXSOLVER(stack_pos) LUA->GetUserType<FlexSolver>(stack_pos, FLEXSOLVER_METATABLE)

// Frees the flex solver instance from memory
LUA_FUNCTION(FLEXSOLVER_GarbageCollect) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);

	FlexSolver* flex = GET_FLEXSOLVER(1);

	LUA->PushNil();
	LUA->SetMetaTable(-2);

	delete flex;
	return 0;
}

// ********** Adding particles ********** //

// Table on the top of the stack is parsed
// ParticleData = {velocity = Vector(), mass = 1}
Particle parse_particle(ILuaBase* LUA, int stack_pos) {
	Particle particle = Particle();

	if (LUA->GetType(stack_pos) == Type::Table) {
		// Get velocity (default = Vector())
		LUA->GetField(stack_pos, "vel");
		if (LUA->GetType(-1) == Type::Vector) {
			particle.vel = LUA->GetVector(-1) * CM_2_INCH;
		}
		LUA->Pop();

		// Get mass (default = 1)
		LUA->GetField(stack_pos, "mass");
		if (LUA->GetType(-1) == Type::Number) {
			particle.pos.w = 1.0 / LUA->GetNumber(-1);
		}
		LUA->Pop();

		// Gets phase (default = self colliding fluid)
		LUA->GetField(stack_pos, "phase");	// literally nobody is going to use this, but whatever
		if (LUA->GetType(-1) == Type::Number) {
			particle.phase = NvFlexMakePhase(0, LUA->GetNumber(-1));
		}
		LUA->Pop();

		// how long the fluid lasts in simulation seconds (default = infinite)
		LUA->GetField(stack_pos, "lifetime");
		if (LUA->GetType(-1) == Type::Number) {
			particle.lifetime = LUA->GetNumber(-1) * CM_2_INCH;		// dont forget to multiply by our fucked up timescale speedup
		}
		LUA->Pop();
	}

	return particle;
}

std::vector<Vector> parse_verts(ILuaBase* LUA, int stack_pos) {
	std::vector<Vector> verts;	// mnnmm yess... vector vector
	for (int i = 0; i < LUA->ObjLen(stack_pos); i++) {
		LUA->PushNumber(i + 1);	// dont forget lua is 1 indexed!
		LUA->GetTable(stack_pos);
		LUA->GetField(-1, "pos");

		verts.push_back(LUA->GetType(-2) == Type::Vector ? LUA->GetVector(-2) : LUA->GetVector());
		LUA->Pop(2); //pop table & position
	}
	return verts;
}

// scales vmatrix while preserving rotation and translation
void scale(VMatrix& mat, float scale) {
	mat[0][0] *= scale;
	mat[1][0] *= scale;
	mat[2][0] *= scale;

	mat[0][1] *= scale;
	mat[1][1] *= scale;
	mat[2][1] *= scale;

	mat[0][2] *= scale;
	mat[1][2] *= scale;
	mat[2][2] *= scale;
}

LUA_FUNCTION(FLEXSOLVER_AddParticle) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Vector);	// transform (position)
	//LUA->CheckType(3, Type::Table);	// ParticleData

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Vector pos = LUA->GetVector(2);

	// Push table to top of stack
	LUA->Push(3);
	Particle particle = parse_particle(LUA, 3);
	particle.pos.x = pos.x;
	particle.pos.y = pos.y;
	particle.pos.z = pos.z;

	flex->add_particle(particle);

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddCube) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// transform
	LUA->CheckType(3, Type::Vector);	// size (x,y,z)
	//LUA->CheckType(4, Type::Table);	// ParticleData

	//gmod Vector and fleX float4
	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	Vector size = LUA->GetVector(3);
	scale(transform, flex->get_parameter("fluid_rest_distance"));

	LUA->Push(4);
	Particle data = parse_particle(LUA, 4);

	for (float z = 0; z < size.z; z++) {
		for (float y = 0; y < size.y; y++) {
			for (float x = 0; x < size.x; x++) {
				Vector pos = transform * (Vector(x + 0.5, y + 0.5, z + 0.5) - size / 2.0);

				data.pos.x = pos.x;
				data.pos.y = pos.y;
				data.pos.z = pos.z;
				if (!flex->add_particle(data)) return 0;
			}
		}
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddSphere) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// transform
	LUA->CheckType(3, Type::Number);	// size (radius)
	//LUA->CheckType(4, Type::Table);	// ParticleData

	//gmod Vector and fleX float4
	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	int size = LUA->GetNumber(3);
	scale(transform, flex->get_parameter("fluid_rest_distance"));

	LUA->Push(4);
	Particle data = parse_particle(LUA, 4);

	for (int z = -size + 1; z < size; z++) {
		for (int y = -size + 1; y < size; y++) {
			for (int x = -size + 1; x < size; x++) {
				if ((float)x * (float)x + (float)y * (float)y + (float)z * (float)z >= size * size) continue;

				Vector pos = transform * Vector(x, y, z);

				data.pos.x = pos.x;
				data.pos.y = pos.y;
				data.pos.z = pos.z;
				if (!flex->add_particle(data)) return 0;
			}
		}
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddCylinder) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// transform
	LUA->CheckType(3, Type::Vector);	// size (x=radius,z=height)
	//LUA->CheckType(4, Type::Table);	// ParticleData

	//gmod Vector and fleX float4
	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	Vector size = LUA->GetVector(3);
	scale(transform, flex->get_parameter("fluid_rest_distance"));

	LUA->Push(4);
	Particle data = parse_particle(LUA, 4);

	for (int z = -size.z + 1; z < size.z; z++) {
		for (int y = -size.y + 1; y < size.y; y++) {
			for (int x = -size.x + 1; x < size.x; x++) {
				if ((float)x * (float)x + (float)y * (float)y >= size.x * size.y) continue;

				Vector pos = transform * Vector(x, y, z);

				data.pos.x = pos.x;
				data.pos.y = pos.y;
				data.pos.z = pos.z;
				if (!flex->add_particle(data)) return 0;
			}
		}
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddMesh) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// Translation
	LUA->CheckType(3, Type::Table);		// Mesh data
	//LUA->CheckType(4, Type::Table);	// ParticleData

	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	Particle particle_data = parse_particle(LUA, 4);
	
	// Indices and vertices must be separated
	std::vector<Vector> verts = parse_verts(LUA, 3);

	// Size of data is invalid
	if (verts.size() % 3 != 0) {
		LUA->PushBool(false);
		return 1;
	}

	int* indices = (int*)malloc(verts.size() * sizeof(int));
	for (int i = 0; i < verts.size(); i++) indices[i] = i;
	
	// Triangulate data
	NvFlexExtAsset* asset = NvFlexExtCreateRigidFromMesh((float*)verts.data(), verts.size(), indices, verts.size(), flex->get_parameter("fluid_rest_distance"), 0);

	free(indices);
	// Data couldn't be triangulated
	if (!asset) {
		LUA->PushBool(false);
		return 1;
	}

	// Add Particles
	for (int i = 0; i < asset->numParticles; i++) {
		Vector pos = transform * ((Vector4D*)asset->particles)[i].AsVector3D();
		particle_data.pos.x = pos.x;
		particle_data.pos.y = pos.y;
		particle_data.pos.z = pos.z;

		flex->add_particle(particle_data);
	}

	NvFlexExtDestroyAsset(asset);

	LUA->PushBool(true);
	return 1;
}

LUA_FUNCTION(FLEXSOLVER_AddCloth) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// pos
	LUA->CheckType(3, Type::Vector);	// size
	//LUA->CheckType(4, Type::Table);	// ParticleData
	
	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	Vector size = LUA->GetVector(3);
	scale(transform, flex->get_parameter("solid_rest_distance"));

	LUA->Push(4);
	Particle data = parse_particle(LUA, 4);

	flex->add_cloth(transform, Vector2D(size.x, size.y), data);

	return 0;
}

// ********** Removing particles ********** //

LUA_FUNCTION(FLEXSOLVER_RemoveSphere) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// translation

	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	VMatrix transform_inverse; 
	if (!MatrixInverseGeneral(transform, transform_inverse)) {
		LUA->PushNumber(0);
		return 1;
	}

	Vector4D* particle_pos = flex->hosts.particle_smooth;
	float* particle_lifetime = flex->hosts.particle_lifetime;
	int* particle_active = flex->hosts.particle_active;
	int* particle_phase = flex->hosts.particle_phase;
	
	int particles_removed = 0;
	for (int i = 0; i < flex->get_active_particles(); i++) {
		int particle_index = particle_active[i];
		if (particle_phase[particle_index] != FlexPhase::WATER) continue;
		if ((transform_inverse * particle_pos[particle_index].AsVector3D()).LengthSqr() > 0.5 * 0.5) continue;

		particle_lifetime[particle_index] = 0;	// kill particle
		particles_removed++;
	}

	LUA->PushNumber(particles_removed);
	return 1;
}

LUA_FUNCTION(FLEXSOLVER_RemoveCube) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Matrix);	// transform

	FlexSolver* flex = GET_FLEXSOLVER(1);
	VMatrix transform = *LUA->GetUserType<VMatrix>(2, Type::Matrix);
	VMatrix transform_inverse;
	if (!MatrixInverseGeneral(transform, transform_inverse)) {
		LUA->PushNumber(0);
		return 1;
	}

	Vector4D* particle_pos = flex->hosts.particle_smooth;
	float* particle_lifetime = flex->hosts.particle_lifetime;
	int* particle_active = flex->hosts.particle_active;
	int* particle_phase = flex->hosts.particle_phase;

	int particles_removed = 0;
	for (int i = 0; i < flex->get_active_particles(); i++) {
		int particle_index = particle_active[i];
		if (particle_phase[particle_index] != FlexPhase::WATER) continue;
		Vector pos = transform_inverse * particle_pos[particle_index].AsVector3D();
		if (pos.x > 0.5 || pos.x < -0.5 || pos.y > 0.5 || pos.y < -0.5 || pos.z > 0.5 || pos.z < -0.5) continue;

		particle_lifetime[particle_index] = 0;	// kill particle
		particles_removed++;
	}

	LUA->PushNumber(particles_removed);
	return 1;
}

// ********** Collision creation / modification / destruction ********** //

// Adds a triangle collision mesh to a FlexSolver
LUA_FUNCTION(FLEXSOLVER_AddConcaveCollider) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Entity ID
	LUA->CheckType(3, Type::Table);		// Mesh data
	LUA->CheckType(4, Type::Vector);	// Initial Pos
	LUA->CheckType(5, Type::Angle);		// Initial Angle

	Vector pos = LUA->GetVector(4);
	QAngle ang = LUA->GetAngle(5);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	std::vector<Vector> verts = parse_verts(LUA, 3);
	FlexMesh mesh = FlexMesh(FLEX_LIBRARY, (int)LUA->GetNumber(2));
	if (!mesh.init_concave(verts, true)) {
		LUA->ThrowError("Tried to add concave mesh with invalid data (NumVertices is not a multiple of 3!)");
		return 0;
	}

	mesh.set_pos(pos);
	mesh.set_ang(ang);
	mesh.update();

	flex->add_mesh(mesh);

	return 0;
}

// Adds a convex collision mesh to a FlexSolver
LUA_FUNCTION(FLEXSOLVER_AddConvexCollider) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Entity ID
	LUA->CheckType(3, Type::Table);		// Mesh data
	LUA->CheckType(4, Type::Vector);	// Initial Pos
	LUA->CheckType(5, Type::Angle);		// Initial Angle

	Vector pos = LUA->GetVector(4);
	QAngle ang = LUA->GetAngle(5);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	std::vector<Vector> verts = parse_verts(LUA, 3);

	FlexMesh mesh = FlexMesh(FLEX_LIBRARY, (int)LUA->GetNumber(2));
	if (!mesh.init_convex(verts, true)) {
		LUA->ThrowError("Tried to add convex mesh with invalid data (NumVertices is not a multiple of 3!)");
		return 0;
	}

	mesh.set_pos(pos);
	mesh.set_ang(ang);
	mesh.update();

	flex->add_mesh(mesh);

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddMapCollider) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);
	LUA->CheckString(3);	// Map name

	FlexSolver* flex = GET_FLEXSOLVER(1);

	// Get path, check if it exists
	std::string path = "maps/" + (std::string)LUA->GetString(3) + ".bsp";
	if (!FileSystem::Exists(path.c_str(), "GAME")) {
		LUA->ThrowError(("Map path " + path + " not found! (Is the map subscribed to?)").c_str());
		return 0;
	}

	// Path exists, load data
	FileHandle_t file = FileSystem::Open(path.c_str(), "rb", "GAME");
	uint32_t filesize = FileSystem::Size(file);
	uint8_t* data = (uint8_t*)malloc(filesize);
	if (data == nullptr) {
		LUA->ThrowError("Map collision data failed to load! (Unsupported BSP Format)");
		return 0;
	}
	FileSystem::Read(data, filesize, file);
	FileSystem::Close(file);

	BSPMap map = BSPMap(data, filesize, false);
	FlexMesh mesh = FlexMesh(FLEX_LIBRARY, (int)LUA->GetNumber(2));
	if (!mesh.init_concave((Vector*)map.GetVertices(), map.GetNumVertices(), false)) {
		free(data);
		LUA->ThrowError("Tried to add map mesh with invalid data (NumVertices is 0 or not a multiple of 3!)");

		return 0;
	}

	// Map collider
	flex->add_mesh(mesh);

	free(data);
	return 0;
}

// Updates position of a collider
LUA_FUNCTION(FLEXSOLVER_SetColliderPos) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Mesh ID
	LUA->CheckType(3, Type::Vector);	// Prop Pos
	//LUA->CheckType(4, Type::Bool);	// Update previous position

	FlexSolver* flex = GET_FLEXSOLVER(1);
	int index = (int)LUA->GetNumber(2);
	if (index < 0 || index >= flex->meshes.size()) return 0;

	flex->meshes[index].set_pos(LUA->GetVector(3));

	// Update previous position if desired
	if (LUA->GetBool(4)) {
		flex->meshes[index].update();
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_SetColliderAng) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Mesh ID
	LUA->CheckType(3, Type::Angle);		// Prop angle
	//LUA->CheckType(4, Type::Bool);	// Update previous position

	FlexSolver* flex = GET_FLEXSOLVER(1);
	int index = (int)LUA->GetNumber(2);
	if (index < 0 || index >= flex->meshes.size()) return 0;

	flex->meshes[index].set_ang(LUA->GetAngle(3));

	// Update previous position if desired
	if (LUA->GetBool(4)) {
		flex->meshes[index].update();
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_SetColliderEnabled) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);				// Mesh ID
	LUA->CheckType(3, Type::Bool);		// Enable collisions?

	FlexSolver* flex = GET_FLEXSOLVER(1);
	int index = (int)LUA->GetNumber(2);
	if (index < 0 || index >= flex->meshes.size()) return 0;

	flex->meshes[index].set_collide(LUA->GetBool(3));

	return 0;
}

// Removes all meshes associated with the entity id
LUA_FUNCTION(FLEXSOLVER_RemoveCollider) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2); // Entity ID

	FlexSolver* flex = GET_FLEXSOLVER(1);
	flex->remove_mesh(LUA->GetNumber(2));

	return 0;
}

// Runs a lua function with some data on all FlexMeshes stored in a FlexSolver
// This is faster then returning a table of values and using ipairs and also allows removal / additions during function execution
// first parameter is the index of the mesh inside the vector
// second parameter is the entity id associated that was given during AddMesh
// third parameter is the number of reoccurring id's in a row (eg. given id's 0,1,1,1 the parameter would be 2 at the end of execution since 1 was repeated two more times)
// ^the third parameter sounds confusing but its useful for multi-joint entities such as ragdolls/players/npcs
LUA_FUNCTION(FLEXSOLVER_IterateColliders) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Function);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	int i = 0;
	int repeat = 0;
	int previous_id;
	for (FlexMesh mesh : flex->meshes) {
		int id = mesh.get_entity_id();

		repeat = (i != 0 && previous_id == id) ? repeat + 1 : 0;	// if (same as last time) {repeat = repeat + 1} else {repeat = 0}
		previous_id = id;

		// func(i, id, repeat)
		LUA->Push(2);
		LUA->PushNumber(i);
		LUA->PushNumber(id);
		LUA->PushNumber(repeat);
		LUA->PCall(3, 0, 0);

		i++;
	}

	return 0;
}

// ********** Miscellaneous ********** //

LUA_FUNCTION(FLEXSOLVER_Tick) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);	// Delta Time

	FlexSolver* flex = GET_FLEXSOLVER(1);
	LUA->PushBool(flex->tick(LUA->GetNumber(2) * CM_2_INCH, (NvFlexMapFlags)LUA->GetNumber(3)));

	return 1;
}

// removes all particles in a flex solver
LUA_FUNCTION(FLEXSOLVER_Reset) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	flex->reset();

	return 0;
}

// removes all cloth related particles
LUA_FUNCTION(FLEXSOLVER_ResetCloth) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	flex->reset_cloth();

	return 0;
}

// removes all diffuse particles in a flex solver
LUA_FUNCTION(FLEXSOLVER_ResetDiffuse) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	flex->reset_diffuse();

	return 0;
}

// removes all diffuse particles in a flex solver
LUA_FUNCTION(FLEXSOLVER_EnableDiffuse) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Bool);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	bool enabled = LUA->GetBool(2);
	flex->enable_diffuse(enabled);

	return 0;
}

// Iterates through all particles and calls a lua function with 1 parameter (position)
LUA_FUNCTION(FLEXSOLVER_RenderParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Function);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	int* active = flex->hosts.particle_active;
	Vector4D* pos = flex->hosts.particle_smooth;
	for (int i = 0; i < flex->get_active_particles(); i++) {
		// render function
		LUA->Push(2);
		LUA->PushVector(pos[active[i]].AsVector3D());
		LUA->Call(1, 0);
	}

	return 0;
}

// Applies reaction forces on serverside objects
#include "vphysics_interface.h"
LUA_FUNCTION(FLEXSOLVER_ApplyContacts) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);	// radius
	LUA->CheckNumber(3);	// dampening
	LUA->CheckNumber(4);	// buoyancy 
	LUA->CheckNumber(5);	// dampening

	if (UTIL_EntityByIndex == nullptr) return 0;	// not hosting server

	FlexSolver* flex = GET_FLEXSOLVER(1);
	if (!flex->get_parameter("reaction_forces")) return 0;	// Coupling planes arent being generated.. bail

	Vector4D* particle_pos = flex->hosts.particle_smooth;
	Vector* particle_vel = flex->hosts.particle_vel;
	int* particle_active = flex->hosts.particle_active;
	/*
	Vector4D* contact_vel = (Vector4D*)flex->get_host("contact_vel");
	Vector4D* contact_planes = (Vector4D*)flex->get_host("contact_planes");

	int* contact_count = (int*)flex->get_host("contact_count");
	int* contact_indices = (int*)flex->get_host("contact_indices");*/
	
	//Vector4D* particle_pos = (Vector4D*)NvFlexMap(flex->get_buffer("particle_pos"), eNvFlexMapWait);
	//Vector* particle_vel = (Vector*)NvFlexMap(flex->get_buffer("particle_vel"), eNvFlexMapWait);

	// mapping planes stops random spazzing, but eats perf
	Vector4D* contact_vel = (Vector4D*)NvFlexMap(flex->buffers.contact_vel, eNvFlexMapWait);
	Vector4D* contact_planes = (Vector4D*)NvFlexMap(flex->buffers.contact_planes, eNvFlexMapWait);

	int* contact_count = (int*)NvFlexMap(flex->buffers.contact_count, eNvFlexMapWait);
	int* contact_indices = (int*)NvFlexMap(flex->buffers.contact_indices, eNvFlexMapWait);

	int max_contacts = flex->get_max_contacts();
	float radius = flex->get_parameter("radius");
	float volume_mul = LUA->GetNumber(2) * 4.f * M_PI * (radius * radius);	// Surface area of sphere equation
	float feedback_mul = LUA->GetNumber(3);
	float buoyancy_mul = LUA->GetNumber(4);
	float dampening_mul = LUA->GetNumber(5);

	std::vector<FlexMesh> meshes = flex->meshes;
	std::map<int, FlexMesh> forces;

	// Get all props and average them
	for (int i = 0; i < flex->get_active_particles(); i++) {
		int particle_index = particle_active[i];
		int plane_id = contact_indices[particle_index];
		for (int contact = 0; contact < contact_count[plane_id]; contact++) {
			int plane_index = plane_id * max_contacts + contact;
			//int vel_index = i * max_contacts + contact;

			float prop_id = (int)contact_vel[plane_index].w;
			if (prop_id < 0) break;	//	planes defined by FleX will return -1

			FlexMesh prop;
			try {
				prop = meshes.at(prop_id);
			} catch (std::exception e) {
				Warning("[GWater2 Internal Error]: Prevented Crash! Tried to access invalid entity %i!\n", prop_id);
				continue;
			}

			int prop_entity_id = prop.get_entity_id();
			
			Vector plane = contact_planes[plane_index].AsVector3D();
			Vector contact_pos = particle_pos[particle_index].AsVector3D() - plane * radius * 0.5;	// Particle position is not directly *on* plane
			Vector local_vel = particle_vel[particle_index] * flex->get_parameter("timescale");
			Vector impact_vel = (plane * fmin(local_vel.Dot(plane), 0) - contact_vel[plane_index].AsVector3D() * feedback_mul) * volume_mul;

			//phys->ApplyForceOffset(impact_vel, contact_pos);
			// dont really like this try/catch tbh
			try {
				FlexMesh& prop = forces.at(prop_entity_id);
				Vector4D pos = prop.get_pos(); pos += Vector4D(contact_pos.x, contact_pos.y, contact_pos.z, 1);	// main branch vector4d only has += operator? wtf?
				Vector4D ang = prop.get_ang(); ang += Vector4D(impact_vel.x, impact_vel.y, impact_vel.z, 0);	// ^
				prop.set_pos(pos);
				prop.set_ang(ang);
			}
			catch (std::exception e) {
				forces[prop_entity_id] = FlexMesh(FLEX_LIBRARY, prop_entity_id);
				forces[prop_entity_id].set_pos(Vector4D(contact_pos.x, contact_pos.y, contact_pos.z, 1));
				forces[prop_entity_id].set_ang(Vector4D(impact_vel.x, impact_vel.y, impact_vel.z, 0));
			}
		}
	}

	//NvFlexUnmap(flex->get_buffer("particle_pos"));
	//NvFlexUnmap(flex->get_buffer("particle_vel"));
	NvFlexUnmap(flex->buffers.contact_vel);
	NvFlexUnmap(flex->buffers.contact_planes);
	NvFlexUnmap(flex->buffers.contact_count);
	NvFlexUnmap(flex->buffers.contact_indices);

	// Now that we have all our contact data, iterate and apply forces
	for (std::pair<int, FlexMesh> force : forces) {
		float contacts = force.second.get_pos().w;
		Vector force_pos = force.second.get_pos().AsVector3D();
		Vector force_vel = force.second.get_ang().AsVector3D();

		// Average the position of the force
		force_pos /= contacts;
		
		// Apply the force
		void* ent = UTIL_EntityByIndex(force.first);

		if (ent == nullptr) {
			//Warning("Couldn't find entity!\n");
			continue;
		}
#ifdef WIN64
		IPhysicsObject* phys = *(IPhysicsObject**)((uint64_t)ent + 0x288);
#else
		IPhysicsObject* phys = *(IPhysicsObject**)((uint64_t)ent + 0x1e0);
#endif
		if (phys == nullptr) {
			//Warning("Couldn't find entity's physics object!\n");
			continue;
		}
		
		Vector prop_pos; phys->GetPosition(&prop_pos, NULL);
		
		// Dampening (completely faked. not at all accurate)
		Vector prop_vel; phys->GetVelocityAtPoint(force_pos, &prop_vel);
		force_vel -= prop_vel * dampening_mul;

		// Buoyancy (completely faked. not at all accurate)
		if (force_pos.z < prop_pos.z + phys->GetMassCenterLocalSpace().z) {
			force_vel += Vector(0, 0, volume_mul * buoyancy_mul);
		}

		// Cap amount of force (vphysics crashes can occur without it)
		float limit = 100 * phys->GetMass();
		if (force_vel.Dot(force_vel) > limit * limit) {
			force_vel = force_vel.Normalized() * limit;
		}

		phys->ApplyForceOffset(force_vel * CM_2_INCH - prop_vel, force_pos);
	}

	return 0;
}

LUA_FUNCTION(FLEXSOLVER_AddForceField) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Vector);
	LUA->CheckNumber(3);	// radius
	LUA->CheckNumber(4);	// strength
	LUA->CheckNumber(5);	// mode
	LUA->CheckType(6, Type::Bool);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Vector pos = LUA->GetVector(2);
	NvFlexExtForceField force_field;
	force_field.mPosition[0] = pos.x;
	force_field.mPosition[1] = pos.y;
	force_field.mPosition[2] = pos.z;
	force_field.mRadius = LUA->GetNumber(3);
	force_field.mStrength = LUA->GetNumber(4);
	force_field.mMode = (NvFlexExtForceMode)LUA->GetNumber(5);
	force_field.mLinearFalloff = LUA->GetBool(6);

	flex->add_force_field(force_field);

	return 0;
}

// Initializes a box (6 planes) with a mins and maxs on a FlexSolver
// Inputting nil disables the bounds.
LUA_FUNCTION(FLEXSOLVER_InitBounds) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	if (LUA->GetType(2) == Type::Vector && LUA->GetType(3) == Type::Vector) {
		flex->enable_bounds(LUA->GetVector(2), LUA->GetVector(3));
	} else {
		flex->disable_bounds();
	}
	
	return 0;
}

LUA_FUNCTION(FLEXSOLVER_SetParameter) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckString(2); // Param
	LUA->CheckNumber(3); // Number

	FlexSolver* flex = GET_FLEXSOLVER(1);
	bool succ = flex->set_parameter(LUA->GetString(2), LUA->GetNumber(3));
	if (!succ) LUA->ThrowError(("Attempt to set invalid parameter '" + (std::string)LUA->GetString(2) + "'").c_str());

	return 0;
}

// ********** Getters ********** //

LUA_FUNCTION(FLEXSOLVER_GetParameter) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckString(2); // Param

	FlexSolver* flex = GET_FLEXSOLVER(1);
	float value = flex->get_parameter(LUA->GetString(2));
	if (isnan(value)) LUA->ThrowError(("Attempt to get invalid parameter '" + (std::string)LUA->GetString(2) + "'").c_str());
	LUA->PushNumber(value);

	return 1;
}

LUA_FUNCTION(FLEXSOLVER_GetActiveParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	LUA->PushNumber(flex->get_active_particles());

	return 1;
}

LUA_FUNCTION(FLEXSOLVER_GetMaxParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	LUA->PushNumber(flex->get_max_particles());
	return 1;
}

LUA_FUNCTION(FLEXSOLVER_GetActiveDiffuseParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	LUA->PushNumber(flex->get_active_diffuse());

	return 1;
}

LUA_FUNCTION(FLEXSOLVER_GetMaxDiffuseParticles) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	FlexSolver* flex = GET_FLEXSOLVER(1);

	LUA->PushNumber(flex->get_max_diffuse_particles());
	return 1;
}

// gets average location of diffuse particles (used in sound)
LUA_FUNCTION(FLEXSOLVER_GetActiveDiffuseParticlesPos) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(2);
	FlexSolver* flex = GET_FLEXSOLVER(1);
	int iterator = LUA->GetNumber(2);

	Vector average_pos = Vector(0, 0, 0);
	int divider = 0;
	for (int i = 0; i < flex->get_active_diffuse(); i += iterator) {
		Vector4D pos = flex->hosts.diffuse_pos[i];
		average_pos += Vector(pos.x, pos.y, pos.z);
		divider++;
	}

	if (divider == 0) {
		average_pos = Vector(0, 0, 0);
	} else {
		average_pos /= (float)divider;
	}

	LUA->PushVector(average_pos);
	return 1;
}

// Gets the total number of particles near a specified location.
// 4th parameter specifies if the calculations should end early (small optimization to avoid looping over all particles)
// As of now this is a quick hack to get swimming working for 0.4b
LUA_FUNCTION(FLEXSOLVER_GetParticlesInRadius) {
	LUA->CheckType(1, FLEXSOLVER_METATABLE);
	LUA->CheckType(2, Type::Vector);
	LUA->CheckNumber(3);

	FlexSolver* flex = GET_FLEXSOLVER(1);
	Vector pos = LUA->GetVector(2);
	float radius = LUA->GetNumber(3) * LUA->GetNumber(3);	// calculation is squared to avoid sqrt()
	int early_exit = (int)LUA->GetNumber(4);	// returns 0 if nil

	int num_particles = 0;
	Vector4D* particle_pos = flex->hosts.particle_smooth;
	int* particle_active = flex->hosts.particle_active;
	int* particle_phase = flex->hosts.particle_phase;
	for (int i = 0; i < flex->get_active_particles(); i++) {
		int particle_index = particle_active[i];
		if (particle_phase[particle_index] != FlexPhase::WATER) continue;
		if (particle_pos[particle_index].AsVector3D().DistToSqr(pos) > radius) continue;

		num_particles++;
		if (early_exit && num_particles >= early_exit) break;
	}

	LUA->PushNumber(num_particles);
	return 1;
}


/*********************************** Flex Renderer LUA Interface *******************************************/

#define GET_FLEXRENDERER(stack_pos) LUA->GetUserType<FlexRenderer>(stack_pos, FLEXRENDERER_METATABLE)

// Frees the flex renderer and its allocated meshes from memory
LUA_FUNCTION(FLEXRENDERER_GarbageCollect) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	FlexRenderer* flex = GET_FLEXRENDERER(1);

	LUA->PushNil();
	LUA->SetMetaTable(-2);

	delete flex;
	return 0;
}

// FlexRenderer imesh related functions
// Builds all meshes related to FlexSolver
LUA_FUNCTION(FLEXRENDERER_BuildMeshes) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	LUA->CheckType(2, FLEXSOLVER_METATABLE);
	LUA->CheckNumber(3);
	GET_FLEXRENDERER(1)->build_meshes(GET_FLEXSOLVER(2), LUA->GetNumber(3), LUA->GetBool(4));

	return 0;
}

// Renders water IMesh* structs (built from func. above)
LUA_FUNCTION(FLEXRENDERER_DrawWater) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	GET_FLEXRENDERER(1)->draw_water();

	return 0;
}

// Renders diffuse IMesh* structs (built from func. above)
LUA_FUNCTION(FLEXRENDERER_DrawDiffuse) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	GET_FLEXRENDERER(1)->draw_diffuse();

	return 0;
}

// Renders cloth
LUA_FUNCTION(FLEXRENDERER_DrawCloth) {
	LUA->CheckType(1, FLEXRENDERER_METATABLE);
	GET_FLEXRENDERER(1)->draw_cloth();

	return 0;
}

/************************************* Global LUA Interface **********************************************/

#define ADD_FUNCTION(LUA, funcName, tblName) LUA->PushCFunction(funcName); LUA->SetField(-2, tblName)

// must be freed from memory
LUA_FUNCTION(NewFlexSolver) {
	LUA->CheckNumber(1);

	int max_particles = LUA->GetNumber(1);
	if (max_particles <= 0) LUA->ThrowError("Max Particles must be a positive number!");

	int max_diffuse_particles = LUA->GetNumber(2);
	if (LUA->GetType(2) != Type::Number) max_diffuse_particles = max_particles;
	if (max_diffuse_particles <= 0) LUA->ThrowError("Max Diffuse Particles must be a positive number!");

	FlexSolver* flex = new FlexSolver(FLEX_LIBRARY, max_particles, max_diffuse_particles);
	LUA->PushUserType(flex, FLEXSOLVER_METATABLE);
	LUA->PushMetaTable(FLEXSOLVER_METATABLE);	// Add our meta functions
	LUA->SetMetaTable(-2);

	/*
	NvFlexSolverCallback callback;
	callback.userData = LUA->GetUserdata();	// "DePriCatEd!!".. maybe add a function with identical or similar functionaliy... :/
	callback.function = [](NvFlexSolverCallbackParams p) {
		// hook.Call("GW2FlexCallback", nil, FlexSolver)
		GLOBAL_LUA->PushSpecial(SPECIAL_GLOB);
		GLOBAL_LUA->GetField(-1, "hook");
		GLOBAL_LUA->GetField(-1, "Call");
		GLOBAL_LUA->PushString("GW2FlexCallback");
		GLOBAL_LUA->PushNil();
		GLOBAL_LUA->PushUserdata(p.userData);	// ^
		GLOBAL_LUA->PushMetaTable(FLEXSOLVER_METATABLE);
		GLOBAL_LUA->SetMetaTable(-2);
		GLOBAL_LUA->PCall(3, 0, 0);
	};
	flex->add_callback(callback, eNvFlexStageUpdateEnd);*/

	return 1;
}

LUA_FUNCTION(NewFlexRenderer) {
	FlexRenderer* flex_renderer = new FlexRenderer();
	LUA->PushUserType(flex_renderer, FLEXRENDERER_METATABLE);
	LUA->PushMetaTable(FLEXRENDERER_METATABLE);
	LUA->SetMetaTable(-2);

	return 1;
}

LUA_FUNCTION(GWATER2_SET_CONTACTS) {
	LUA->CheckNumber(1);	// index
	LUA->CheckNumber(2);	// contacts

	ILuaBase* LUA_SERVER = (ILuaBase*)GLOBAL_LUA->GetLuaInterface(State::SERVER);
	if (LUA_SERVER) {

		// _G.Entity(index).GWATER2_CONTACTS = contacts;
		LUA_SERVER->PushSpecial(SPECIAL_GLOB);
		LUA_SERVER->GetField(-1, "Entity");
		if (LUA_SERVER->IsType(-1, Type::Function)) {
			LUA_SERVER->PushNumber(LUA->GetNumber(1));
			if (!LUA_SERVER->PCall(1, 1, 0)) {
				if (LUA_SERVER->IsType(-1, Type::Entity)) {
					//if (LUA_SERVER->GetMetaTable(-1)) {
						LUA_SERVER->PushNumber(LUA->GetNumber(2));
						LUA_SERVER->SetField(-2, "GWATER2_CONTACTS");
						//LUA_SERVER->Pop();	// Pop metatable
					//}
				}
				else {
					Warning("[GWater2 Internal Error]: _G.Entity() Is returning a non-entity! (%i)\n", LUA_SERVER->GetType(-1));
				}
				LUA_SERVER->Pop();	// Pop entity
			}
		}
		else {
			Warning("[GWater2 Internal Error]: _G.Entity Is returning a non-function! (%i)\n", LUA_SERVER->GetType(-1));
		}
		LUA_SERVER->Pop();	// Pop _G
	}

	return 0;
}

// `mat_antialias 0` but shit
/*LUA_FUNCTION(SetMSAAEnabled) {
	MaterialSystem_Config_t config = materials->GetCurrentConfigForVideoCard();
	config.m_nAAQuality = 0;
	config.m_nAASamples = 0;
	//config.m_nForceAnisotropicLevel = 1;
	//config.m_bShadowDepthTexture = false;
	//config.SetFlag(MATSYS_VIDCFG_FLAGS_FORCE_TRILINEAR, false);
	MaterialSystem_Config_t config_default = MaterialSystem_Config_t();
	//config.m_Flags = config_default.m_Flags;
	//config.m_DepthBias_ShadowMap = config_default.m_DepthBias_ShadowMap;
	//config.dxSupportLevel = config_default.dxSupportLevel;
	//config.m_SlopeScaleDepthBias_ShadowMap = config_default.m_SlopeScaleDepthBias_ShadowMap;
	materials->OverrideConfig(config, false);
	return 0;
}*/

GMOD_MODULE_OPEN() {
	Msg("[GWater2]: Module opened\n");
	Msg("[GWater2]: Loading lua_shared interface\n");

#ifdef _LINUX
	if (!Sys_LoadInterface("lua_shared.so", GMOD_LUASHARED_INTERFACE, NULL, (void**)&GLOBAL_LUA))
		LUA->ThrowError("[GWater2 Internal Error]: LuaShared failed to load!");
#else
	if (!Sys_LoadInterface("lua_shared.dll", GMOD_LUASHARED_INTERFACE, NULL, (void**)&GLOBAL_LUA))
		LUA->ThrowError("[GWater2 Internal Error]: LuaShared failed to load!");
#endif

	Msg("[GWater2]: Loading FleX instance\n");
	NvFlexInitDesc desc = NvFlexInitDesc();
	desc.computeType = eNvFlexD3D11;

#ifdef _LINUX
	desc.computeType = eNvFlexCUDA;	// no DirectX on linux
#endif

	FLEX_LIBRARY = NvFlexInit(
		NV_FLEX_VERSION,
		[](NvFlexErrorSeverity type, const char* message, const char* file, int line) {
			std::string error = "[GWater2 Internal Error]: " + (std::string)message + "\n";
			//ILuaBase* LUA = (ILuaBase*)GLOBAL_LUA->GetLuaInterface(State::CLIENT);
			//LUA->ThrowError(error.c_str());

			// Breaking out of call stack in FleX functions is BAD
			Warning(error.c_str());
		},
		&desc
	);

	if (FLEX_LIBRARY == nullptr) 
		LUA->ThrowError("[GWater2 Internal Error]: Nvidia FleX Failed to load! (Does your GPU meet the minimum requirements to run FleX?)");

	Msg("[GWater2]: Loading engine interface\n");
	if (!Sys_LoadInterface("engine", VENGINE_CLIENT_INTERFACE_VERSION, NULL, (void**)&engine))
		LUA->ThrowError("[GWater2 Internal Error]: C++ EngineClient failed to load!");

	Msg("[GWater2]: Loading materialsystem interface\n");
	if (!Sys_LoadInterface("materialsystem", MATERIAL_SYSTEM_INTERFACE_VERSION, NULL, (void**)&materials))
		LUA->ThrowError("[GWater2 Internal Error]: C++ Materialsystem failed to load!");

	//if (!Sys_LoadInterface("shaderapidx9", SHADER_DEVICE_INTERFACE_VERSION, NULL, (void**)&g_pShaderDevice))
	//	LUA->ThrowError("[GWater2 Internal Error]: C++ Shaderdevice failed to load!");

	//if (!Sys_LoadInterface("shaderapidx9", SHADERAPI_INTERFACE_VERSION, NULL, (void**)&g_pShaderAPI))
	//	LUA->ThrowError("[GWater2 Internal Error]: C++ Shaderapi failed to load!");

	//if (!Sys_LoadInterface("studiorender", STUDIO_RENDER_INTERFACE_VERSION, NULL, (void**)&g_pStudioRender)) 
	//	LUA->ThrowError("[GWater2 Internal Error]: C++ Studiorender failed to load!");

	// Defined in 'shader_inject.h'
	Msg("[GWater2]: Injecting shaders\n");
	if (!inject_shaders())
		LUA->ThrowError("[GWater2 Internal Error]: C++ Shadersystem failed to load!");

	// GMod filesystem (Used for bsp parser)
	Msg("[GWater2]: Loading gmfs\n");
	if (FileSystem::LoadFileSystem() != FILESYSTEM_STATUS::OK)
		LUA->ThrowError("[GWater2 Internal Error]: C++ Filesystem failed to load!");

	Msg("[GWater2]: Generating FlexSolver and FlexRenderer metatables\n");
	FLEXSOLVER_METATABLE = LUA->CreateMetaTable("FlexSolver");
	ADD_FUNCTION(LUA, FLEXSOLVER_GarbageCollect, "__gc");	// FlexMetaTable.__gc = FlexGC

	// FlexMetaTable.__index = {func1, func2, ...}
	LUA->CreateTable();
	ADD_FUNCTION(LUA, FLEXSOLVER_GarbageCollect, "Destroy");
	ADD_FUNCTION(LUA, FLEXSOLVER_Tick, "Tick");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddParticle, "AddParticle");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddCube, "AddCube");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddSphere, "AddSphere");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddCylinder, "AddCylinder");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddMesh, "AddMesh");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddCloth, "AddCloth");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddForceField, "AddForceField");
	ADD_FUNCTION(LUA, FLEXSOLVER_RemoveSphere, "RemoveSphere");
	ADD_FUNCTION(LUA, FLEXSOLVER_RemoveCube, "RemoveCube");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetMaxParticles, "GetMaxParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetMaxDiffuseParticles, "GetMaxDiffuseParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetActiveDiffuseParticlesPos, "GetActiveDiffuseParticlesPos");
	ADD_FUNCTION(LUA, FLEXSOLVER_EnableDiffuse, "EnableDiffuse");
	ADD_FUNCTION(LUA, FLEXSOLVER_RenderParticles, "RenderParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddConcaveCollider, "AddConcaveCollider");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddConvexCollider, "AddConvexCollider");
	ADD_FUNCTION(LUA, FLEXSOLVER_RemoveCollider, "RemoveCollider");
	ADD_FUNCTION(LUA, FLEXSOLVER_SetColliderPos, "SetColliderPos");
	ADD_FUNCTION(LUA, FLEXSOLVER_SetColliderAng, "SetColliderAng");
	ADD_FUNCTION(LUA, FLEXSOLVER_SetColliderEnabled, "SetColliderEnabled");
	ADD_FUNCTION(LUA, FLEXSOLVER_SetParameter, "SetParameter");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetParameter, "GetParameter");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetActiveParticles, "GetActiveParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetActiveDiffuseParticles, "GetActiveDiffuseParticles");
	ADD_FUNCTION(LUA, FLEXSOLVER_GetParticlesInRadius, "GetParticlesInRadius");
	ADD_FUNCTION(LUA, FLEXSOLVER_AddMapCollider, "AddMapCollider");
	ADD_FUNCTION(LUA, FLEXSOLVER_IterateColliders, "IterateColliders");
	ADD_FUNCTION(LUA, FLEXSOLVER_ApplyContacts, "ApplyContacts");
	ADD_FUNCTION(LUA, FLEXSOLVER_InitBounds, "InitBounds");
	ADD_FUNCTION(LUA, FLEXSOLVER_Reset, "Reset");
	ADD_FUNCTION(LUA, FLEXSOLVER_ResetCloth, "ResetCloth");
	ADD_FUNCTION(LUA, FLEXSOLVER_ResetDiffuse, "ResetDiffuse");
	LUA->SetField(-2, "__index");

	FLEXRENDERER_METATABLE = LUA->CreateMetaTable("FlexRenderer");
	ADD_FUNCTION(LUA, FLEXRENDERER_GarbageCollect, "__gc");	// FlexMetaTable.__gc = FlexGC

	// FlexMetaTable.__index = {func1, func2, ...}
	LUA->CreateTable();
	ADD_FUNCTION(LUA, FLEXRENDERER_GarbageCollect, "Destroy");
	ADD_FUNCTION(LUA, FLEXRENDERER_BuildMeshes, "BuildMeshes");
	ADD_FUNCTION(LUA, FLEXRENDERER_DrawWater, "DrawWater");
	ADD_FUNCTION(LUA, FLEXRENDERER_DrawDiffuse, "DrawDiffuse");
	ADD_FUNCTION(LUA, FLEXRENDERER_DrawCloth, "DrawCloth");
	LUA->SetField(-2, "__index");

	// _G.FlexSolver = NewFlexSolver
	LUA->PushSpecial(SPECIAL_GLOB);
		ADD_FUNCTION(LUA, NewFlexSolver, "FlexSolver");
		ADD_FUNCTION(LUA, NewFlexRenderer, "FlexRenderer");
		ADD_FUNCTION(LUA, GWATER2_SET_CONTACTS, "GWATER2_SET_CONTACTS");

		// gwater2_hdr_fix = ConVar("gwater2_hdr_fix", hdr_on, FCVAR_NONE);
		char hdr_on[2] = { 
			'0' + (g_pHardwareConfig->GetHDRType() != HDR_TYPE_NONE),
			0
		};

		Msg("[GWater2]: Creating gwater_hdr_fix ConVar %c\n", hdr_on[0]);

		LUA->GetField(-1, "CreateConVar");
		LUA->PushString("gwater2_hdr_fix");
		LUA->PushString(hdr_on);
		LUA->PushNumber(FCVAR_NONE);
		LUA->Call(3, 1);
		gwater2_hdr_fix = LUA->GetUserType<ConVar>(-1, Type::ConVar);
		gwater2_hdr_fix->SetValue(hdr_on);

		LUA->Pop();
	LUA->Pop();

	Msg("[GWater2]: Finding symbol for UTIL_EntityByIndex\n");
	// Get serverside physics objects from client DLL. Since server.dll exists in memory, we can find it and avoid networking.
	// Pretty sure this is what hacked clients do
#ifdef WIN64
	// \x2A = "*"
	const uint8_t sig[] = "\x48\x83\xEC\x2A\x8B\xD1\x85\xC9\x7E\x2A\x48\x8B\x2A\x2A\x2A\x2A\x2A\x48\x8B";
#else
	const uint8_t sig[] = "\x55\x8B\xEC\x8B\x2A\x2A\x85\xD2\x2A\x2A\x8B\x0D\x2A\x2A\x2A\x2A\x52\x8B\x2A\xFF\x50\x2A\x8B\xC8\x85\xC9";
#endif
	SymbolFinder finder;
	void* UTIL_EntityByIndexAddr = finder.FindPatternFromBinary("server.dll", sig, sizeof(sig) - 1);
	if (UTIL_EntityByIndexAddr == nullptr) {
		Warning("[GWater2 Internal Error] Couldn't find UTIL_EntityByIndex!\n");
	}
	else {
		UTIL_EntityByIndex = (UTIL_EntityByIndexFN)UTIL_EntityByIndexAddr;
	}

	return 0;
}

// Called when the module is unloaded
GMOD_MODULE_CLOSE() {
	if (FLEX_LIBRARY) {
		NvFlexShutdown(FLEX_LIBRARY);
		FLEX_LIBRARY = nullptr;
	}

	// Defined in 'shader_inject.h'
	eject_shaders();

	return 0;
}