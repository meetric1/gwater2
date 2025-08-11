#include <BaseVSShader.h>

#include "shaders/inc/GWaterNormals_vs30.inc"
#include "shaders/inc/GWaterNormals_ps30.inc"

BEGIN_VS_SHADER(GWaterNormals, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(DEPTHFIX, SHADER_PARAM_TYPE_BOOL, "0", "Depth fix enabled/disabled")
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {
	
}

SHADER_INIT {

}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	SHADOW_STATE {
		pShaderShadow->VertexShaderVertexFormat(VERTEX_GWATER2, 1, 0, 0);
		pShaderShadow->EnableAlphaWrites(true);	// we write to the alpha channel

		DECLARE_STATIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterNormals_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterNormals_ps30);
	}

	DYNAMIC_STATE {

		// constants
		const float radius = params[RADIUS]->GetFloatValue();
		const bool depthfix = params[DEPTHFIX]->GetIntValue();

		pShaderAPI->SetPixelShaderConstant(0, &radius);

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterNormals_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
		SET_DYNAMIC_PIXEL_SHADER_COMBO(DEPTH, depthfix);
		SET_DYNAMIC_PIXEL_SHADER(GWaterNormals_ps30);
		
	}
	
	Draw();

}

END_SHADER