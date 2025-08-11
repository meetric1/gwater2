// DYNAMIC: "OPAQUE" "0..1"
// DYNAMIC: "NUM_LIGHTS"				"0..4"
// DYNAMIC: "HDR"						"0..1"
// STATIC: "FLASHLIGHT"					"0..1"
// STATIC: "FLASHLIGHTDEPTHFILTERMODE"	"0..2"

// DYNAMIC: "FLASHLIGHTSHADOWS"			"0..1" 

/*
	I am very new to GPU archetecture and shader optimization.

	Please for your own sake, do not copy or reference any of this file. 
	This is genuinely the most garbage piece of code I've ever written
*/

#include "common_flashlight_fxc.h"
#include "shader_constant_register_map.h" 
//#include "common_vertexlitgeneric_dx9.h"

float2 SCR_S			: register(c0);
float RADIUS			: register(c1);
float IOR 				: register(c2);
float REFLECTANCE 		: register(c3);
float4 COLOR2			: register(c4);
float3 cAmbientCube[6]	: register(c5);

PixelShaderLightInfo cLightInfo[3]			: register(PSREG_LIGHT_INFO_ARRAY); // c20 - c25, 2 registers each - 6 registers total (4th light spread across w's)
const float4 g_ShadowTweaks					: register(c26); // PSREG_ENVMAP_TINT__SHADOW_TWEAKS is supposed to be c2, we're using that already, so use c26 instead
const float4 g_FlashlightAttenuationFactors	: register(PSREG_FLASHLIGHT_ATTENUATION);			// c13, On non-flashlight pass
const float4 g_FlashlightPos_RimBoost		: register(PSREG_FLASHLIGHT_POSITION_RIM_BOOST); // c14
const float4x4 g_FlashlightWorldToTexture	: register(PSREG_FLASHLIGHT_TO_WORLD_TEXTURE); // c15

sampler NORMALS 				: register(s0);
sampler FRAMEBUFFER 			: register(s1);
samplerCUBE CUBEMAP				: register(s2);
sampler DEPTH					: register(s3);
sampler ShadowDepthSampler		: register(s4);	// Flashlight shadow depth map sampler
sampler NormalizeRandRotSampler	: register(s5);	// Normalization / RandomRotation samplers
sampler FlashlightSampler		: register(s6);	// Flashlight cookie

struct PS_INPUT {
	float2 P 			: VPOS;
	float2 coord		: TEXCOORD0;
	float3 view_dir		: TEXCOORD1;
	float3 pos			: TEXCOORD2;
	float4x4 proj		: TEXCOORD3; 
	float4 lightAtten	: TEXCOORD8; // Scalar light attenuation factors for FOUR lights
};

#define SUN_DIR float3(-0.377821, 0.520026, 0.766044)	// TODO: get from map OR get lighting data

#define SpecularExponent 200
#define g_FlashlightPos					g_FlashlightPos_RimBoost.xyz

bool is_zero(float3 i) {
	return i.x == 0 && i.y == 0 && i.z == 0;
}

// Assumes that incoming IOR is 1
float fresnel_schlicks(float cos_theta, float ior) {
    float r0 = (1.0 - ior) / (1.0 + ior);
    r0 = r0 * r0;
    return r0 + (1.0 - r0) * pow(1.0 - cos_theta, 5.0);
}

float4 final_output(float3 final) {
	return FinalOutput(float4(final, 1), 0, 0, TONEMAP_SCALE_LINEAR);
}

float3 do_flashlight(PS_INPUT i, float3 normal) {
	float3 reflected = float3(0, 0, 0);
	float3 diffuse = float3(0, 0, 0);
	float4 flashlightSpacePosition = mul(float4(i.pos, 1.0f), g_FlashlightWorldToTexture);
	if (flashlightSpacePosition.z > 0) {
		DoSpecularFlashlight(
			g_FlashlightPos,
			i.pos, 
			flashlightSpacePosition, 
			normal,
			g_FlashlightAttenuationFactors.xyz, 
			g_FlashlightAttenuationFactors.w,
			FlashlightSampler, 
			ShadowDepthSampler, 
			NormalizeRandRotSampler, 
			FLASHLIGHTDEPTHFILTERMODE, 
			FLASHLIGHTSHADOWS, 
			true, 
			i.P * SCR_S,
			SpecularExponent, 
			-i.view_dir, 
			false, 
			FRAMEBUFFER, 
			0, 
			g_ShadowTweaks,

			// These two values are output
			diffuse, 
			reflected
		);
	}

	#if OPAQUE
		return COLOR2.xyz * diffuse + reflected;
	#else
		return reflected;
	#endif
}

float3 do_absorption(PS_INPUT i) {
	float absorption_distance = tex2D(DEPTH, i.P * SCR_S).x * 100 * COLOR2.w;
	return exp((COLOR2.xyz - float3(1, 1, 1)) * absorption_distance);	// Beers law
}

// despite saying "do specular", this actually only calculates radiance from local area lights
// (also: does fresnel internally)
float3 do_specular(PS_INPUT i, float3 normal) {
	float3 specular_lighting;
	float3 rim_lighting;	// Unused

	PixelShaderDoSpecularLighting(
		i.pos, 
		normal,
		SpecularExponent, 
		-i.view_dir, 
		i.lightAtten,
		NUM_LIGHTS, 
		cLightInfo, 
		false, 
		0, 
		false, 
		FRAMEBUFFER, 
		0, 
		false, 
		1,
		specular_lighting, 
		rim_lighting
	);

	return specular_lighting;
}

float3 do_cubemap(PS_INPUT i, float3 normal) {
	#if HDR
		return pow(texCUBE(CUBEMAP, reflect(i.view_dir, normal)).xyz * ENV_MAP_SCALE, 1 / 2.2);
	#else
		return texCUBE(CUBEMAP, reflect(i.view_dir, normal)).xyz * ENV_MAP_SCALE;
	#endif
}

float3 do_diffuse(PS_INPUT i, float3 normal) {
	return COLOR2.xyz * (dot(normal, SUN_DIR) * 0.4 + 0.6);	// not accurate!

	// include "common_vertexlitgeneric_dx9.h" to use
	// may cause seizures
	/*return COLOR2.xyz * pow(PixelShaderDoLighting(
		i.pos, 
		normal,
		float3( 0.0f, 0.0f, 0.0f ), 
		false, 
		true, 
		i.lightAtten,
		cAmbientCube, 
		NormalizeRandRotSampler, 
		NUM_LIGHTS, 
		cLightInfo, 
		true,

		// These are dummy parameters:
		false, 
		1.0f,
		false, 
		NormalizeRandRotSampler //supposed to be BaseTextureSampler?
	), 1 / 2.2);*/
}

float3 do_refraction(PS_INPUT i, float3 normal) {
	// Calculate refraction vector in 3d space and project it to screen
	float3 offset = refract(i.view_dir, normal, 1.0 / IOR) * RADIUS * 2;	//normal * -RADIUS;//
	float4 uv = mul(float4(i.pos + offset, 1), i.proj); uv.xy /= uv.w; 

	float2 refract_pos = float2(uv.x / 2.0 + 0.5, 0.5 - uv.y / 2.0);	//-1,1 -> 0,1
	return tex2D(FRAMEBUFFER, refract_pos).xyz / LINEAR_LIGHT_SCALE;
}

float4 main(PS_INPUT i) : COLOR {
	// kill pixels outside of sphere
	float2 offset = (i.coord - 0.5) * 2.0;
	float radius2 = dot(offset, offset);
	if (radius2 > 1) discard;

	//i.view_dir = normalize(i.pos - i.view_dir);
	float3 smoothed_normal = tex2D(NORMALS, i.P * SCR_S).xyz;
	
	// Weight the normals forward, as the only visible part is facing the player
	smoothed_normal = normalize(smoothed_normal + i.view_dir * REFLECTANCE * clamp(-dot(i.view_dir, smoothed_normal), 0.5, 1));

	// Flashlight lighting (eg. a lamp is casting shadow)
	#if FLASHLIGHT
		return final_output(do_flashlight(i, smoothed_normal));
	#endif

	// Final lighting calculations
	#if OPAQUE
		return final_output(do_diffuse(i, smoothed_normal) + do_specular(i, smoothed_normal));

	#else // Translucent
		// incorrect fresnel calculation, but looks better
		float fresnel = min(fresnel_schlicks(max(dot(smoothed_normal, -i.view_dir), 0.0), IOR) + 0.05, 1);
		
		// Chat is this accurate??
		return final_output((1.0 - fresnel) * do_refraction(i, smoothed_normal) * do_absorption(i) + do_cubemap(i, smoothed_normal) * fresnel + do_specular(i, smoothed_normal));
	#endif
};