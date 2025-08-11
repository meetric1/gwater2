#include "common_vs_fxc.h"

struct VS_INPUT {
	float4 vPos					: POSITION;		// Position
	float4 vTexCoord			: TEXCOORD0;	// Texture coordinates
};

struct VS_OUTPUT {
	float4 projPosSetup	: POSITION;
	float4 world_coord	: TEXCOORD0;
};

VS_OUTPUT main(const VS_INPUT v)  {
	VS_OUTPUT o = (VS_OUTPUT)0;

	// Extract real position
	float3 world_pos;
	SkinPosition(0, v.vPos, 0, 0, world_pos);

	float4 vProjPos = mul(float4(world_pos, 1), cViewProj);
	//vProjPos.z = dot(float4(world_pos, 1), cViewProjZ);	// wtf does this even do?
	o.projPosSetup = vProjPos;
	o.world_coord = v.vTexCoord;
	return o;
};