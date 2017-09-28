Shader "PopKinect/Circle Filter"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		BlackMax("BlackMax", Range(0,0.5) ) = 0.4
		Radius0("Radius0", Range(1,50) ) = 5
		Radius1("Radius1", Range(1,50) ) = 10
		Radius2("Radius2", Range(1,50) ) = 15
		Radius3("Radius3", Range(1,50) ) = 20
		Radius4("Radius4", Range(1,50) ) = 25
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

			#define SampleCount	20

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
				Score = Range( MinScore, 2, Score );
				return Score;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float4 BadScore = tex2D(_MainTex, uv);

				float Radiuses[RADIUS_COUNT];
				Radiuses[0] = Radius0;
				Radiuses[1] = Radius1;
				Radiuses[2] = Radius2;
				Radiuses[3] = Radius3;
				Radiuses[4] = Radius4;
				float BlackScores[RADIUS_COUNT];
				BlackScores[1] = GetBlackScore( uv, Radius1 );
				BlackScores[2] = GetBlackScore( uv, Radius2 );
				BlackScores[3] = GetBlackScore( uv, Radius3 );
				BlackScores[4] = GetBlackScore( uv, Radius4 );

				for ( int r=0;	r<RADIUS_COUNT;	r++ )
				{
					BlackScores[r] = GetBlackScore( uv, Radiuses[r] );
				}

				float BestScore = 0;
				float ScorePairs[RADIUS_COUNT*RADIUS_COUNT];
				int ScoreCount = 0;
				for ( int i=0;	i<RADIUS_COUNT-1;	i++ )
				{
					for ( int o=i+1;	o<RADIUS_COUNT;	o++ )
					{
						ScorePairs[ScoreCount] = GetTotalScore( BlackScores[i], BlackScores[o] );
						BestScore = max( BestScore, ScorePairs[ScoreCount] );
						ScoreCount++;
					}
				}

				if ( BestScore < 0.01f )
					return BadScore;

				return float4( NormalToRedGreen(BestScore), 1 );
			}
			ENDCG
		}
	}
}
