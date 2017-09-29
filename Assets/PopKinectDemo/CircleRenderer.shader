Shader "PopKinect/CircleRenderer"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		CircleColour("CircleColour", COLOR ) = (0.5,0.5,0.5,1)
		RadiusScale("RadiusScale", Range(1,10) ) = 1
		RingThickness("RingThickness", Range(0.01,0.5) ) = 0.3
		ScoreMax("ScoreMax", Range(1,1000) ) = 10

		RefineRadiusMult0("RefineRadiusMult0", Range(0,2) ) = 0.5
		RefineRadiusMult1("RefineRadiusMult1", Range(0,2) ) = 0.80
		RefineRadiusMult2("RefineRadiusMult2", Range(0,2) ) = 0.85
		RefineRadiusMult3("RefineRadiusMult3", Range(0,2) ) = 0.95
		RefineRadiusMult4("RefineRadiusMult4", Range(0,2) ) = 1.0
		RefineRadiusMult5("RefineRadiusMult5", Range(0,2) ) = 1.1
		RefineRadiusMult6("RefineRadiusMult6", Range(0,2) ) = 1.2
		RefineRadiusMult7("RefineRadiusMult7", Range(0,2) ) = 1.3
		ShowRefineRadiuses("ShowRefineRadiuses", Range(0,1) ) = 1
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

			#define MAX_CIRCLES	50
			float4 Circles[MAX_CIRCLES];
			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;
			float4 CircleColour;
			float RingThickness;
			float ScoreMax;


			float RefineRadiusMult0;
			float RefineRadiusMult1;
			float RefineRadiusMult2;
			float RefineRadiusMult3;
			float RefineRadiusMult4;
			float RefineRadiusMult5;
			float RefineRadiusMult6;
			float RefineRadiusMult7;
			float ShowRefineRadiuses;
			#define SHOW_REFINE_RADIUSES	( ShowRefineRadiuses > 0.5f )

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			bool InRing(float Radius,float Mult,float Distance)
			{
				
				float Outer = Radius * Mult;
				float Inner = Outer * (1-RingThickness);

				if (  (Distance <= Outer) && (Distance>=Inner) )
					return true;
				return false;
			}

			float InsideCircleScore(float2 xy,float4 Circle)
			{
				float Distance = distance( Circle.xy, xy );

				int Render = 0;
				Render += InRing( Circle.z, 1, Distance );
				if ( SHOW_REFINE_RADIUSES )
				{
					Render += InRing( Circle.z, RefineRadiusMult0, Distance );
					Render += InRing( Circle.z, RefineRadiusMult1, Distance );
					Render += InRing( Circle.z, RefineRadiusMult2, Distance );
					Render += InRing( Circle.z, RefineRadiusMult3, Distance );
					Render += InRing( Circle.z, RefineRadiusMult4, Distance );
					Render += InRing( Circle.z, RefineRadiusMult5, Distance );
					Render += InRing( Circle.z, RefineRadiusMult6, Distance );
					Render += InRing( Circle.z, RefineRadiusMult7, Distance );
				}
				if ( Render > 0 )
					return Circle.w;
				return 0;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				int CircleCount = 0;
				i.uv.y = 1 - i.uv.y;

				float2 xy = i.uv * _MainTex_TexelSize.zw;
				float BestScore = 0;

				for ( int c=0;	c<MAX_CIRCLES;	c++ )
				//for ( int c=0;	c<10;	c++ )
				{
					float Score = InsideCircleScore( xy, Circles[c] );
					BestScore = max( BestScore, Score );
				}

				float4 rgba = tex2D(_MainTex, i.uv);

				if ( BestScore > 0 )
				{
					BestScore /= ScoreMax;
					return float4( NormalToRedGreen( BestScore ), 1 );
				}

				return rgba;
			}
			ENDCG
		}
	}
}
