Shader "PopKinect/Circle Filter"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		OriginalTexture ("OriginalTexture", 2D) = "white" {}
		BlackMax("BlackMax", Range(0,0.5) ) = 0.4
		Radius0("Radius0", Range(1,50) ) = 5
		Radius1("Radius1", Range(1,50) ) = 10
		Radius2("Radius2", Range(1,50) ) = 15
		Radius3("Radius3", Range(1,50) ) = 20
		Radius4("Radius4", Range(1,50) ) = 25
		Radius5("Radius5", Range(1,50) ) = 35
		Radius6("Radius6", Range(1,50) ) = 45
		Radius7("Radius7", Range(1,50) ) = 55

		RefineRadiusMult0("RefineRadiusMult0", Range(0,2) ) = 0.5
		RefineRadiusMult1("RefineRadiusMult1", Range(0,2) ) = 0.80
		RefineRadiusMult2("RefineRadiusMult2", Range(0,2) ) = 0.85
		RefineRadiusMult3("RefineRadiusMult3", Range(0,2) ) = 0.95
		RefineRadiusMult4("RefineRadiusMult4", Range(0,2) ) = 1.0
		RefineRadiusMult5("RefineRadiusMult5", Range(0,2) ) = 1.1
		RefineRadiusMult6("RefineRadiusMult6", Range(0,2) ) = 1.2
		RefineRadiusMult7("RefineRadiusMult7", Range(0,2) ) = 1.3
	

		MinWhiteScore("MinWhiteScore", Range(0,1) ) = 0.5
		MinBlackScore("MinBlackScore", Range(0,1) ) = 0.5
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
			sampler2D OriginalTexture;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			float BlackMax;

			#define SampleCount	30

			float MinWhiteScore;
			float MinBlackScore;

			#define RADIUS_COUNT	8
			float Radius0;
			float Radius1;
			float Radius2;
			float Radius3;
			float Radius4;
			float Radius5;
			float Radius6;
			float Radius7;

			float RefineRadiusMult0;
			float RefineRadiusMult1;
			float RefineRadiusMult2;
			float RefineRadiusMult3;
			float RefineRadiusMult4;
			float RefineRadiusMult5;
			float RefineRadiusMult6;
			float RefineRadiusMult7;


			#define IS_DATA_BLACK	-1
			#define IS_DATA_WHITE	-2
			#define IS_DATA_MAGIC(x)	( x < 0 )

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

				if ( rgb.x == IS_DATA_BLACK )
					return true;
				else if ( rgb.x == IS_DATA_WHITE )
					return false;

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
				float4 BadScore = tex2D(_MainTex, uv);
				bool UvIsBlack = IsBlack( uv );

				float Radiuses[RADIUS_COUNT];
				Radiuses[0] = Radius0;
				Radiuses[1] = Radius1;
				Radiuses[2] = Radius2;
				Radiuses[3] = Radius3;
				Radiuses[4] = Radius4;
				Radiuses[5] = Radius5;
				Radiuses[6] = Radius6;
				Radiuses[7] = Radius7;

				//	check for refining data mode
				#if defined(DATA_OUTPUT)
				if ( IS_DATA_MAGIC(BadScore.x) )
				{
					float LooseRadius = BadScore.z;
					Radiuses[7] = LooseRadius * RefineRadiusMult7;
					Radiuses[6] = LooseRadius * RefineRadiusMult6;
					Radiuses[5] = LooseRadius * RefineRadiusMult5;
					Radiuses[4] = LooseRadius * RefineRadiusMult4;
					Radiuses[3] = LooseRadius * RefineRadiusMult3;
					Radiuses[2] = LooseRadius * RefineRadiusMult2;
					Radiuses[1] = LooseRadius * RefineRadiusMult1;
					Radiuses[0] = LooseRadius * RefineRadiusMult0;
				}
				#endif



				float BlackScores[RADIUS_COUNT];
				for ( int r=0;	r<RADIUS_COUNT;	r++ )
				{
					BlackScores[r] = GetBlackScore( uv, Radiuses[r] );
				}

				float BestScore = 0;
				float ScorePairs[RADIUS_COUNT*RADIUS_COUNT];
				float BestOuterRadius = 0;

				/*
				for ( int i=0;	i<RADIUS_COUNT-1;	i++ )
				{
					for ( int o=i+1;	o<RADIUS_COUNT;	o++ )
					{
						float ThisScore = GetTotalScore( BlackScores[i], BlackScores[o] );
						ScorePairs[ScoreCount] = ThisScore;
						if ( ThisScore > BestScore )
						{
							BestScore = ThisScore;
							BestOuterRadius = Radiuses[o];
						}
					}
				}
				*/

				//	all smaller-radii should succeed
				for ( int o=1;	o<RADIUS_COUNT;	o++ )
				{
					float BestInnerScore = 0;
					float WorstInnerScore = 1;
					float AverageInnerScore = 0;
					for ( int i=0;	i<o;	i++ )
					{
						float InnerScore = GetTotalScore( BlackScores[i], BlackScores[o] );
						BestInnerScore = max( BestInnerScore, InnerScore );
						WorstInnerScore = min( WorstInnerScore, InnerScore );
						AverageInnerScore += InnerScore;
					}
					AverageInnerScore /= (float)o;

					float ThisScore = BestInnerScore;
					if ( ThisScore > BestScore )
					{
						BestScore = ThisScore;
						BestOuterRadius = Radiuses[o];
					}
				}
					



				#if defined(DATA_OUTPUT)
				float3 rgb = 0;
				rgb.x = UvIsBlack ? IS_DATA_BLACK : IS_DATA_WHITE;
				rgb.y = BestScore;
				rgb.z = BestOuterRadius;
				#else

				if ( BestScore == 0 )
					return BadScore;

				float3 rgb = NormalToRedGreen(BestScore);

				#endif

				return float4( rgb, 1 );
			}
			ENDCG
		}
	}
}
