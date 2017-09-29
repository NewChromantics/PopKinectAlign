Shader "PopKinect/CircleRenderer"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		CircleColour("CircleColour", COLOR ) = (0.5,0.5,0.5,1)
		RadiusScale("RadiusScale", Range(1,10) ) = 1
		RingThickness("RingThickness", Range(0.01,0.5) ) = 0.3
		ScoreMax("ScoreMax", Range(1,1000) ) = 10
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
			float RadiusScale;
			float RingThickness;
			float ScoreMax;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				//o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uv = v.uv;
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float InsideCircleScore(float2 xy,float4 Circle)
			{
				float Distance = distance( Circle.xy, xy );
				Circle.z *= RadiusScale;

				float Outer = Circle.z;
				float Inner = Outer * (1-RingThickness);

				if (  (Distance <= Outer) && (Distance>=Inner) )
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
