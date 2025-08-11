#include <BaseVSShader.h>

#include "shaders/inc/GWaterFinalpass_vs30.inc"
#include "shaders/inc/GWaterFinalpass_ps30.inc"
#include "cpp_shader_constant_register_map.h"

ConVar* gwater2_hdr_fix;

BEGIN_VS_SHADER(GWaterFinalpass, "gwater2 helper")

// Shader parameters
BEGIN_SHADER_PARAMS
	SHADER_PARAM(RADIUS, SHADER_PARAM_TYPE_FLOAT, "1", "Radius of particles")
	SHADER_PARAM(NORMALTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of smoothed normals")
	SHADER_PARAM(SCREENTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Texture of screen")
	SHADER_PARAM(DEPTHTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "lights/white", "Depth texture")
	SHADER_PARAM(IOR, SHADER_PARAM_TYPE_FLOAT, "1.333", "Ior of water")
	SHADER_PARAM(COLOR2, SHADER_PARAM_TYPE_COLOR, "[1.0 1.0 1.0 1.0]", "Color of water. Alpha channel represents absorption amount")
	//SHADER_PARAM(ABSORPTIONMULTIPLIER, SHADER_PARAM_TYPE_FLOAT, "1", "Absorbsion multiplier")
	SHADER_PARAM(REFLECTANCE, SHADER_PARAM_TYPE_FLOAT, "0.0", "Reflectance of water")
	SHADER_PARAM(ENVMAP, SHADER_PARAM_TYPE_TEXTURE, "env_cubemap", "envmap")
	SHADER_PARAM(FLASHLIGHTTEXTURE, SHADER_PARAM_TYPE_TEXTURE, "effects/flashlight001", "Flashlight")
END_SHADER_PARAMS

SHADER_INIT_PARAMS() {
	if (g_pHardwareConfig->SupportsBorderColor()) {
		params[FLASHLIGHTTEXTURE]->SetStringValue("effects/flashlight_border");
	} else {
		params[FLASHLIGHTTEXTURE]->SetStringValue("effects/flashlight001");
	}

	// This shader can be used with hw skinning
	SET_FLAGS2(MATERIAL_VAR2_SUPPORTS_HW_SKINNING);
	SET_FLAGS2(MATERIAL_VAR2_LIGHTING_VERTEX_LIT);
	SET_FLAGS2(MATERIAL_VAR2_SUPPORTS_FLASHLIGHT);
}

SHADER_INIT {
	if (params[ENVMAP]->IsDefined()) {
		LoadCubeMap(ENVMAP, TEXTUREFLAGS_SRGB);
	}
	if (params[SCREENTEXTURE]->IsDefined()) {
		LoadTexture(SCREENTEXTURE);
	}
	if (params[NORMALTEXTURE]->IsDefined()) {
		LoadTexture(NORMALTEXTURE);
	}
	if (params[DEPTHTEXTURE]->IsDefined()) {
		LoadTexture(DEPTHTEXTURE);
	}
	if (FLASHLIGHTTEXTURE != -1) {
		LoadTexture(FLASHLIGHTTEXTURE, TEXTUREFLAGS_SRGB);
	}
}

SHADER_FALLBACK{
	return NULL;
}

SHADER_DRAW {
	bool bHasFlashlight = UsingFlashlight(params);
	SHADOW_STATE {
		// Note: Removing VERTEX_COLOR makes the shader work on all objects (Like props)
		pShaderShadow->VertexShaderVertexFormat(VERTEX_GWATER2, 1, 0, 0);
		pShaderShadow->EnableTexture(SHADER_SAMPLER0, true);	// Smoothed normals texture
		pShaderShadow->EnableTexture(SHADER_SAMPLER1, true);	// Screen texture
		pShaderShadow->EnableTexture(SHADER_SAMPLER2, true);	// Cubemap
		pShaderShadow->EnableTexture(SHADER_SAMPLER3, true);	// Depth

		int nShadowFilterMode = 0;

		if (bHasFlashlight) { 
			if (SCREENTEXTURE != -1) {
				SetAdditiveBlendingShadowState(SCREENTEXTURE, true);
			}
			pShaderShadow->EnableBlending(true);
			pShaderShadow->EnableDepthWrites(false);

			// Be sure not to write to dest alpha
			pShaderShadow->EnableAlphaWrites(false);

			nShadowFilterMode = g_pHardwareConfig->GetShadowFilterMode();	// Based upon vendor and device dependent formats

			pShaderShadow->EnableTexture(SHADER_SAMPLER4, true);	// Shadow depth map
			pShaderShadow->SetShadowDepthFiltering(SHADER_SAMPLER4);
			pShaderShadow->EnableSRGBRead(SHADER_SAMPLER4, false);
			pShaderShadow->EnableTexture(SHADER_SAMPLER5, true);	// Noise map
			pShaderShadow->EnableTexture(SHADER_SAMPLER6, true);	// Flashlight cookie
			pShaderShadow->EnableSRGBRead(SHADER_SAMPLER6, true);
		} else {
			if (SCREENTEXTURE != -1) {
				SetDefaultBlendingShadowState(SCREENTEXTURE, true);
			}
		}
		
		DECLARE_STATIC_VERTEX_SHADER(GWaterFinalpass_vs30);
		SET_STATIC_VERTEX_SHADER(GWaterFinalpass_vs30);

		DECLARE_STATIC_PIXEL_SHADER(GWaterFinalpass_ps30);
		SET_STATIC_PIXEL_SHADER_COMBO(FLASHLIGHT, bHasFlashlight);
		SET_STATIC_PIXEL_SHADER_COMBO(FLASHLIGHTDEPTHFILTERMODE, nShadowFilterMode);
		SET_STATIC_PIXEL_SHADER(GWaterFinalpass_ps30);
	}

	DYNAMIC_STATE {
		// constants
		int scr_x, scr_y; pShaderAPI->GetBackBufferDimensions(scr_x, scr_y);
		const float scr_s[2] = { 1.0 / scr_x, 1.0 / scr_y };
		float radius = params[RADIUS]->GetFloatValue();
		float ior = params[IOR]->GetFloatValue();
		float reflectance = params[REFLECTANCE]->GetFloatValue();
		const float* color2 = params[COLOR2]->GetVecValue();
		const float color2_normalized[4] = { color2[0] / 255.0, color2[1] / 255.0, color2[2] / 255.0, color2[3] / 255.0 };

		pShaderAPI->SetPixelShaderConstant(0, scr_s);
		pShaderAPI->SetPixelShaderConstant(1, &radius);
		pShaderAPI->SetPixelShaderConstant(2, &ior);
		pShaderAPI->SetPixelShaderConstant(3, &reflectance);
		pShaderAPI->SetPixelShaderConstant(4, color2_normalized);
		pShaderAPI->SetPixelShaderStateAmbientLightCube(5, false);

		/*
		CMatRenderContextPtr pRenderContext(materials);

		// Yoinked from viewrender.cpp (in a water detection function of all things, ironic..)
		VMatrix viewMatrix, projectionMatrix, viewProjectionMatrix, inverseViewProjectionMatrix;
		pRenderContext->GetMatrix(MATERIAL_VIEW, &viewMatrix);
		pRenderContext->GetMatrix(MATERIAL_PROJECTION, &projectionMatrix);
		MatrixMultiply(projectionMatrix, viewMatrix, viewProjectionMatrix);
		MatrixInverseGeneral(viewProjectionMatrix, inverseViewProjectionMatrix);

		float matrix[16];
		for (int i = 0; i < 16; i++) {
			int x = i % 4;
			int y = i / 4;
			matrix[i] = inverseViewProjectionMatrix[y][x];
		}*/ 
		BindTexture(SHADER_SAMPLER0, NORMALTEXTURE);
		BindTexture(SHADER_SAMPLER1, SCREENTEXTURE);
		BindTexture(SHADER_SAMPLER2, ENVMAP);
		BindTexture(SHADER_SAMPLER3, DEPTHTEXTURE);

		// Flashlight (lamp) shit

		pShaderAPI->CommitPixelShaderLighting(PSREG_LIGHT_INFO_ARRAY);
		LightState_t lightState = { 0, false, false };
		bool bFlashlightShadows = false;
		if (bHasFlashlight) {
			//Assert(info.m_nFlashlightTexture >= 0 && info.m_nFlashlightTextureFrame >= 0);
			BindTexture(SHADER_SAMPLER6, FLASHLIGHTTEXTURE, FLASHLIGHTTEXTUREFRAME);
			VMatrix worldToTexture;
			ITexture* pFlashlightDepthTexture;
			FlashlightState_t state = pShaderAPI->GetFlashlightStateEx(worldToTexture, &pFlashlightDepthTexture);
			bFlashlightShadows = state.m_bEnableShadows && (pFlashlightDepthTexture != NULL);

			SetFlashLightColorFromState(state, pShaderAPI, PSREG_FLASHLIGHT_COLOR);

			if (pFlashlightDepthTexture && g_pConfig->ShadowDepthTexture() && state.m_bEnableShadows)
			{
				BindTexture(SHADER_SAMPLER4, pFlashlightDepthTexture, 0);
				pShaderAPI->BindStandardTexture(SHADER_SAMPLER5, TEXTURE_SHADOW_NOISE_2D);
			}

			float atten[4], pos[4], tweaks[4];

			const FlashlightState_t& flashlightState = pShaderAPI->GetFlashlightState(worldToTexture);
			SetFlashLightColorFromState(flashlightState, pShaderAPI, PSREG_FLASHLIGHT_COLOR);

			BindTexture(SHADER_SAMPLER6, flashlightState.m_pSpotlightTexture, flashlightState.m_nSpotlightTextureFrame);

			atten[0] = flashlightState.m_fConstantAtten;		// Set the flashlight attenuation factors
			atten[1] = flashlightState.m_fLinearAtten;
			atten[2] = flashlightState.m_fQuadraticAtten;
			atten[3] = flashlightState.m_FarZ;
			pShaderAPI->SetPixelShaderConstant(PSREG_FLASHLIGHT_ATTENUATION, atten, 1);

			pos[0] = flashlightState.m_vecLightOrigin[0];		// Set the flashlight origin
			pos[1] = flashlightState.m_vecLightOrigin[1];
			pos[2] = flashlightState.m_vecLightOrigin[2];
			pShaderAPI->SetPixelShaderConstant(PSREG_FLASHLIGHT_POSITION_RIM_BOOST, pos, 1);

			pShaderAPI->SetPixelShaderConstant(PSREG_FLASHLIGHT_TO_WORLD_TEXTURE, worldToTexture.Base(), 4);

			// Tweaks associated with a given flashlight
			tweaks[0] = ShadowFilterFromState(flashlightState);
			tweaks[1] = ShadowAttenFromState(flashlightState);
			HashShadow2DJitter(flashlightState.m_flShadowJitterSeed, &tweaks[2], &tweaks[3]);
			pShaderAPI->SetPixelShaderConstant(26, tweaks, 1); // PSREG_ENVMAP_TINT__SHADOW_TWEAKS is c2, we're using that already for the cubemap, so use c26 instead.

			// Dimensions of screen, used for screen-space noise map sampling
			float vScreenScale[4] = { 1280.0f / 32.0f, 720.0f / 32.0f, 0, 0 };
			int nWidth, nHeight;
			pShaderAPI->GetBackBufferDimensions(nWidth, nHeight);
			vScreenScale[0] = (float)nWidth / 32.0f;
			vScreenScale[1] = (float)nHeight / 32.0f;
			pShaderAPI->SetPixelShaderConstant(PSREG_FLASHLIGHT_SCREEN_SCALE, vScreenScale, 1);
		} else {
			pShaderAPI->GetDX9LightState(&lightState);
		}

		DECLARE_DYNAMIC_VERTEX_SHADER(GWaterFinalpass_vs30);
		SET_DYNAMIC_VERTEX_SHADER_COMBO(NUM_LIGHTS, lightState.m_nNumLights);
		SET_DYNAMIC_VERTEX_SHADER(GWaterFinalpass_vs30);

		DECLARE_DYNAMIC_PIXEL_SHADER(GWaterFinalpass_ps30);
		SET_DYNAMIC_PIXEL_SHADER_COMBO(NUM_LIGHTS, lightState.m_nNumLights);
		SET_DYNAMIC_PIXEL_SHADER_COMBO(FLASHLIGHTSHADOWS, bFlashlightShadows);
		SET_DYNAMIC_PIXEL_SHADER_COMBO(OPAQUE, color2[3] > 254);
		SET_DYNAMIC_PIXEL_SHADER_COMBO(HDR, gwater2_hdr_fix->GetInt());
		SET_DYNAMIC_PIXEL_SHADER(GWaterFinalpass_ps30);

		//pShaderAPI->SetVertexShaderConstant(4, matrix, 4, true);	// FORCE into cModelViewProj!
	} 

	Draw();
}

END_SHADER