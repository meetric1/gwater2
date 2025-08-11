#include <BaseVSShader.h>

#include "shaders/inc/GWaterVolumetric_vs30.inc"
#include "shaders/inc/GWaterVolumetric_ps30.inc"

BEGIN_VS_SHADER(GWaterVolumetric, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(ALPHA, SHADER_PARAM_TYPE_FLOAT, "0.025", "Amount of transparency")
	SHADER_PARAM(BASETEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Base texture")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {

}

SHADER_INIT{
	LoadTexture(BASETEXTURE);
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	

	SHADOW_STATE {
		pShaderShadow->VertexShaderVertexFormat(VERTEX_GWATER2, 1, 0, 0);
		
		// Transparent things (alpha 0 <= x <= 1)
		if (IS_FLAG_SET(MATERIAL_VAR_TRANSLUCENT)) {
			pShaderShadow->EnableDepthWrites(false);
			pShaderShadow->EnableBlending(true);

			// Additive vs multiplicitive
			if (IS_FLAG_SET(MATERIAL_VAR_ADDITIVE)) {
				pShaderShadow->BlendFunc(SHADER_BLEND_SRC_ALPHA, SHADER_BLEND_ONE);
			} else {
				pShaderShadow->BlendFunc(SHADER_BLEND_SRC_ALPHA, SHADER_BLEND_ONE_MINUS_SRC_ALPHA);
				//pShaderShadow->BlendFunc(SHADER_BLEND_ONE, SHADER_BLEND_ONE);
			}
		}
		
		// Transparent things (alpha = 0 or alpha = 1)
		pShaderShadow->EnableAlphaTest(IS_FLAG_SET(MATERIAL_VAR_ALPHATEST));
		pShaderShadow->EnableTexture(SHADER_SAMPLER0, true);

		DECLARE_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	DYNAMIC_STATE {
		// constants
		const float alpha = params[ALPHA]->GetFloatValue();

		pShaderAPI->SetPixelShaderConstant(0, &alpha);
		BindTexture(SHADER_SAMPLER0, BASETEXTURE);

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
		SET_DYNAMIC_PIXEL_SHADER(GWaterVolumetric_ps30);
	}

	Draw();

}

END_SHADER