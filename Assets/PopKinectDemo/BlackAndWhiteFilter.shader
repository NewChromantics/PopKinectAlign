Shader "PopKinect/Black and white"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		BlackMax("BlackMax", Range(0,0.5) ) = 0.4
		InvertColourMatch("InvertColourMatch", Range(0,1) ) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			// make fog work
			#pragma multi_compile_fog

			#pragma multi_compile __ DATA_OUTPUT

			#include "UnityCG.cginc"
			#include "../PopUnityCommon/PopCommon.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				UNITY_FOG_COORDS(1)
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			float BlackMax;

			#define SampleCount	30

			float MinWhiteScore;
			float MinBlackScore;

			#define RADIUS_COUNT	5
			float Radius0;
			float Radius1;
			float Radius2;
			float Radius3;
			float Radius4;

			float InvertColourMatch;
			#define INVERT_COLOUR_MATCH	( InvertColourMatch > 0.5f )

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			bool IsBlack(float2 uv)
			{
				fixed4 rgb = tex2D(_MainTex, uv);
				float Blackness = max( rgb.x, max( rgb.y, rgb.z ) );

				if ( Blackness > BlackMax )
					return false;
				return true;
			}

		
			bool IsBlackSample(float2 uv,float RadiusPx,float AngleDegrees)
			{
				float AngleRad = radians(AngleDegrees);
				float Offsetx = cos( AngleRad ) * RadiusPx;
				float Offsety = sin( AngleRad ) * RadiusPx;

				float2 Offsetuv = float2( Offsetx, Offsety ) * _MainTex_TexelSize.xy;
				uv += Offsetuv;

				return IsBlack( uv );
			}

			float GetBlackScore(float2 uv,float RadiusPx)
			{
				float BlackCount = 0;
				for ( int s=0;	s<SampleCount;	s++ )
				{
					float t = s / (float)SampleCount;
					float Angle = t * 360.0f;
					BlackCount += IsBlackSample( uv, RadiusPx, Angle );
				}
				BlackCount /= (float)SampleCount;
				return BlackCount;
			}


			float GetTotalScore(float WhiteScore,float BlackScore)
			{
				WhiteScore = 1 - WhiteScore;

				float InnerScore = WhiteScore;
				float OuterScore = BlackScore;
				if ( INVERT_COLOUR_MATCH )
				{
					InnerScore = 1 - InnerScore;
					OuterScore = 1 - OuterScore;
				}

				if ( InnerScore < MinWhiteScore )
					return 0;
				if ( OuterScore < MinBlackScore )
					return 0;
				
				float Score = (InnerScore + OuterScore);
				float MinScore = (MinWhiteScore + MinBlackScore);
				Score = Range( MinScore, 1+1, Score );
				return Score;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv;

				if ( IsBlack(uv) )
					return float4(0,0,0,1);
				else
					return float4(1,1,1,1);
			}
			ENDCG
		}
	}
}
