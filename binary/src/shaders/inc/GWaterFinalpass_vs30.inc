// ALL SKIP STATEMENTS THAT AFFECT THIS SHADER!!!
// defined $LIGHTING_PREVIEW && defined $FASTPATH && $LIGHTING_PREVIEW && $FASTPATH

#pragma once
#include "shaderlib/cshader.h"
class GWaterFinalpass_vs30_Static_Index
{
public:
	GWaterFinalpass_vs30_Static_Index()
	{
	}

	int GetIndex() const
	{
		return 0;
	}
};

#define shaderStaticTest_GWaterFinalpass_vs30 1


class GWaterFinalpass_vs30_Dynamic_Index
{
	unsigned int m_nNUM_LIGHTS : 3;
#ifdef _DEBUG
	bool m_bNUM_LIGHTS : 1;
#endif	// _DEBUG
public:
	void SetNUM_LIGHTS( int i )
	{
		Assert( i >= 0 && i <= 4 );
		m_nNUM_LIGHTS = i;
#ifdef _DEBUG
		m_bNUM_LIGHTS = true;
#endif	// _DEBUG
	}

	GWaterFinalpass_vs30_Dynamic_Index()
	{
		m_nNUM_LIGHTS = 0;
#ifdef _DEBUG
		m_bNUM_LIGHTS = false;
#endif	// _DEBUG
	}

	int GetIndex() const
	{
		Assert( m_bNUM_LIGHTS );
		return ( 1 * m_nNUM_LIGHTS ) + 0;
	}
};

#define shaderDynamicTest_GWaterFinalpass_vs30 vsh_forgot_to_set_dynamic_NUM_LIGHTS

