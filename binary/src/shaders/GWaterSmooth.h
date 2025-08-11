#include <BaseVSShader.h>

#include "shaders/inc/GWaterVolumetric_vs30.inc"	// vertex shader is reused because I don't feel like recompiling another one
#include "shaders/inc/GWaterSmooth_ps30.inc"

BEGIN_VS_SHADER(GWaterSmooth, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(SCRS, SHADER_PARAM_TYPE_VEC2, "[1 1]", "Screen Size")
	SHADER_PARAM(NORMALTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of normals")
	SHADER_PARAM(DEPTHTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of depth")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {

}

SHADER_INIT {
	LoadTexture(NORMALTEXTURE);
	LoadTexture(DEPTHTEXTURE);
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	SHADOW_STATE {

		// Note: Removing VERTEX_COLOR makes the shader work on all objects (Like props)
		unsigned int flags = VERTEX_POSITION | VERTEX_NORMAL | VERTEX_TEXCOORD0_2D;
		pShaderShadow->VertexShaderVertexFormat(flags, 1, 0, 0);
		pShaderShadow->EnableTexture(SHADER_SAMPLER0, true);
		pShaderShadow->EnableTexture(SHADER_SAMPLER1, true);
		pShaderShadow->EnableAlphaWrites(true);	// We use and update the alpha channel

		DECLARE_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterSmooth_ps30);
		SET_STATIC_PIXEL_SHADER(GWaterSmooth_ps30);
	}

	DYNAMIC_STATE {
		// constants
		const float* scr_s = params[SCRS]->GetVecValue();
		const float radius = params[RADIUS]->GetFloatValue();

		pShaderAPI->SetPixelShaderConstant(0, scr_s);
		pShaderAPI->SetPixelShaderConstant(1, &radius);

		BindTexture(SHADER_SAMPLER0, NORMALTEXTURE);
		BindTexture(SHADER_SAMPLER1, DEPTHTEXTURE);

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);
		SET_DYNAMIC_VERTEX_SHADER(GWaterVolumetric_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterSmooth_ps30);
		SET_DYNAMIC_PIXEL_SHADER(GWaterSmooth_ps30);
	}

	Draw();

}

END_SHADER