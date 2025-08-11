#include "common_vs_fxc.h"

//  DYNAMIC: "NUM_LIGHTS"				"0..4"  

struct VS_INPUT {
	float4 vPos			: POSITION;		// Position
	float4 vTexCoord	: TEXCOORD0;	// Texture coordinates
};

struct VS_OUTPUT {
	float4 projPosSetup	: POSITION;
	float2 coord		: TEXCOORD0;
	float3 view_dir		: TEXCOORD1;
	float3 pos			: TEXCOORD2;
	float4x4 proj		: TEXCOORD3;	// Used in refraction
	float4 lightAtten	: TEXCOORD8; 	// Scalar light attenuation factors for FOUR lights
	//float psize			: PSIZE;
};

VS_OUTPUT main(const VS_INPUT v) {
	VS_OUTPUT o = (VS_OUTPUT)0;

	// Extract real position
	float3 world_pos;
	SkinPosition(0, v.vPos, 0, 0, world_pos);

	float4 vProjPos = mul(float4(world_pos, 1), cViewProj);
	//vProjPos.z = dot(float4(extruded_world_pos, 1), cViewProjZ);	// wtf does this even do?

	o.projPosSetup = vProjPos;
	o.coord = v.vTexCoord;
	o.view_dir = normalize(world_pos - cEyePos);
	o.proj = cViewProj;	
	o.pos = world_pos; 
	
	// Scalar attenuations for four lights
	o.lightAtten.xyz = float4(0,0,0,0);
	#if (NUM_LIGHTS > 0)
		o.lightAtten.x = GetVertexAttenForLight(world_pos, 0, false);
	#endif
	#if (NUM_LIGHTS > 1)
		o.lightAtten.y = GetVertexAttenForLight(world_pos, 1, false);
	#endif
	#if (NUM_LIGHTS > 2)
		o.lightAtten.z = GetVertexAttenForLight(world_pos, 2, false);
	#endif
	#if (NUM_LIGHTS > 3)
		o.lightAtten.w = GetVertexAttenForLight(world_pos, 3, false);
	#endif

	return o;
};