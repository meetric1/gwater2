#pragma once
#include "shaderlib/cshader.h"
class GWaterNormals_ps30_Static_Index
{
public:
	GWaterNormals_ps30_Static_Index( )
	{
	}

	int GetIndex() const
	{
		return 0;
	}
};

#define shaderStaticTest_GWaterNormals_ps30 1


class GWaterNormals_ps30_Dynamic_Index
{
	unsigned int m_nDEPTH : 2;
#ifdef _DEBUG
	bool m_bDEPTH : 1;
#endif	// _DEBUG
public:
	void SetDEPTH( int i )
	{
		Assert( i >= 0 && i <= 1 );
		m_nDEPTH = i;
#ifdef _DEBUG
		m_bDEPTH = true;
#endif	// _DEBUG
	}

	GWaterNormals_ps30_Dynamic_Index( )
	{
		m_nDEPTH = 0;
#ifdef _DEBUG
		m_bDEPTH = false;
#endif	// _DEBUG
	}

	int GetIndex() const
	{
		Assert( m_bDEPTH );
		return ( 1 * m_nDEPTH ) + 0;
	}
};

#define shaderDynamicTest_GWaterNormals_ps30 psh_forgot_to_set_dynamic_DEPTH

