//  DYNAMIC: "DEPTH" "0..1"

float RADIUS				: register(c0);

struct PS_INPUT {
	float2 P 			: VPOS;
	float2 coord		: TEXCOORD0;
	float3 pos			: TEXCOORD1;
	float4x4 proj		: TEXCOORD2;
	float3x3 normal		: NORMAL0;	
};

struct PS_OUTPUT {
	float4 rt0			: COLOR0;
	float4 rt1			: COLOR1;
#if DEPTH
	float depth	 		: DEPTH0;
#endif
};

PS_OUTPUT main(const PS_INPUT i) {

	// kill pixels outside of sphere
	float2 offset = (i.coord - 0.5) * 2.0;
	float radius2 = dot(offset, offset);
	if (radius2 > 1) discard;

	// Calculate world normal from texture coords
	float bulge = sqrt(1 - radius2);
	float3 world_normal = normalize(mul(float3(offset.x, bulge, -offset.y), i.normal));

	// Standard mipmap calculation
	float2 uvdx = ddx(i.coord);
	float2 uvdy = ddy(i.coord);
	float uvdmax = 1.0 / sqrt(max(dot(uvdx, uvdx), dot(uvdy, uvdy)));	

	// Depth calculations
	float4 bulge_pos = mul(float4(i.pos.xyz + i.normal[1] * bulge * RADIUS, 1), i.proj);

	// Output colors to rendertargets
	PS_OUTPUT o = (PS_OUTPUT)0;
	o.rt0 = float4(world_normal, bulge_pos.z);
	//o.rt0 = float4(i.coord.x, i.coord.y, 0, bulge_pos.z);
	o.rt1 = float4(uvdmax, 0, 0, 1);
#if DEPTH
	o.depth = bulge_pos.z / bulge_pos.w;
#endif

	return o;
};