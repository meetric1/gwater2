#include "common_vs_fxc.h"

struct VS_INPUT {
	float4 vPos			: POSITION;	
	float4 vTexCoord	: TEXCOORD0;	// Texture coordinates
	float3 vNormal		: NORMAL0;
};

struct VS_OUTPUT {
	float4 projPosSetup	: POSITION;  // Register 0
	float4 coord		: TEXCOORD0; // Register 1
	float3 pos			: TEXCOORD1; // Register 2
	float4x4 proj		: TEXCOORD2; // Registers 3 4 5 6
	float3x3 normal		: NORMAL0;	 // Registers 7 8 9
};

VS_OUTPUT main(const VS_INPUT v) {
	VS_OUTPUT o = (VS_OUTPUT)0;
	
	// Extract real position
	float3 world_normal, world_pos;
	SkinPositionAndNormal(0, v.vPos, v.vNormal, 0, 0, world_pos, world_normal);

	float4 vProjPos = mul(float4(world_pos, 1), cViewProj);
	//vProjPos.z = dot(float4(extruded_world_pos, 1), cViewProjZ);	// wtf does this even do?

	o.projPosSetup = vProjPos;
	o.coord = v.vTexCoord;
	o.pos = world_pos;
	o.proj = cViewProj;		// Used in spherical depth

	float3 right = normalize(cross(world_normal, float3(0, 0, 1)));
	float3 up = cross(world_normal, right);
	o.normal = float3x3(
		-right.x, -right.y, -right.z,
		world_normal.x, world_normal.y, world_normal.z,
		-up.x, -up.y, -up.z
	);

	return o;
};