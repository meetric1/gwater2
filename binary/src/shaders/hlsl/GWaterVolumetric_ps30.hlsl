float ALPHA				: register(c0);
sampler BASETEXTURE 	: register(s0);

struct PS_INPUT {
	float4 P 		: VPOS;
	float2 coord	: TEXCOORD0;
};

float4 main(PS_INPUT i) : COLOR {
	return tex2D(BASETEXTURE, i.coord) * ALPHA;
};