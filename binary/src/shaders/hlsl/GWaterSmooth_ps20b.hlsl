sampler NORMALS : register(s0);
sampler DEPTH	: register(s1);
float2 SCR_S	: register(c0);
float RADIUS 	: register(c1);

#define RESOLUTION 4
#define THRESHOLD 0

struct PS_INPUT {
	float2 coord : TEXCOORD0;
};

// Algorithm smooths normals of particle (uses my own method) (separated into X and Y passes)
// Worked on this algorithm for multiple months, so it may be a little messy. Smoothing particle information is not easy..
float4 main(PS_INPUT i) : COLOR {
	float4 og_normal = tex2D(NORMALS, i.coord);
	//if (og_normal.w <= RADIUS) return float4(0, 0, 0, 0);	// Dont blur if too close.

	//float mipmap = tex2D(DEPTH, i.coord).x;
	// sm20 doesn't support ddx/ddy functions (Linux moment), so we need to remake them
	float2 uvdx = tex2D(DEPTH, i.coord).xy - tex2D(DEPTH, i.coord + float2(SCR_S.x, 0)).xy;
	float2 uvdy = tex2D(DEPTH, i.coord).xy - tex2D(DEPTH, i.coord + float2(0, SCR_S.y)).xy;
	float mipmap = 1.0 / sqrt(max(dot(uvdx, uvdx), dot(uvdy, uvdy)));

	float3 final_normal = og_normal.xyz;

	// Blurring right
	[unroll]
	for (int x = 1; x <= RESOLUTION; x++) {
		float2 texcoord_pos = i.coord + float2(x * SCR_S.x, x * SCR_S.y) * mipmap;		// Grabs adjacent pixel based on how much screen space the particle takes up

		// Is particle close enough	to be blended?		
		float4 neighbor_normal = tex2D(NORMALS, texcoord_pos);
		if (neighbor_normal.w - og_normal.w > RADIUS || neighbor_normal.w == 0) return og_normal;

		// Weigh smooth amount based on angle
		float cosTheta = dot(og_normal.xyz, neighbor_normal.xyz);
		if (cosTheta < THRESHOLD) break;
		//cosTheta = max(cosTheta, THRESHOLD);

		final_normal += neighbor_normal.xyz * cosTheta * cosTheta;
	}

	// Blurring left
	// (Identical to above loop^)
	[unroll]
	for (int x = -1; x >= -RESOLUTION; x--) {
		float2 texcoord_pos = i.coord + float2(x * SCR_S.x, x * SCR_S.y) * mipmap;
		float4 neighbor_normal = tex2D(NORMALS, texcoord_pos);
		if (neighbor_normal.w - og_normal.w > RADIUS || neighbor_normal.w == 0) return og_normal;
		float cosTheta = dot(og_normal.xyz, neighbor_normal.xyz);
		if (cosTheta < THRESHOLD) break;
		final_normal += neighbor_normal.xyz * cosTheta * cosTheta;
	}

	return float4(normalize(final_normal), og_normal.w);
};