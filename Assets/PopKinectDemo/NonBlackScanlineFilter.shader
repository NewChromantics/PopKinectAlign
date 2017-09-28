Shader "PopKinect/NonBlackScanlineFilter"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		BlackMax("BlackMax", Range(0,0.5) ) = 0.4
		ScanPixelStep("ScanPixelStep", Range(1,10) ) = 1
		ScanPixelCount("ScanPixelsCount", Range(1,100) ) = 10
		MinScore("MinScore", Range(0,1) ) = 0
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

			float ScanPixelStep;
			float ScanPixelCount;
			#define ScanPixelCount_max	20

			float MinScore;
			
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

			float GetNonBlackLength(float2 StartUv,float2 DeltaPx)
			{
				DeltaPx *= ScanPixelStep;
				
				[unroll(ScanPixelCount_max)]
				for ( int i=0;	i<ScanPixelCount_max;	i++	)
				{
					if ( i >= ScanPixelCount )
						break;

					float2 DeltaUv = (DeltaPx * (float)i);
					DeltaUv *= _MainTex_TexelSize.xy;

					float2 uv = StartUv + DeltaUv;
					if ( IsBlack(uv) )
						return i;
				}

				return ScanPixelCount;
			}

			bool OverMax(float Length)
			{
				return Length >= ScanPixelCount;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				float2 uv = i.uv;

				float4 BadScore = tex2D(_MainTex, uv);

				#define DIRECTIONS	8
				float2 Deltas[DIRECTIONS];
				Deltas[0] = float2(-1, 0);
				Deltas[1] = float2( 1, 0);
				Deltas[2] = float2( 0,-1);
				Deltas[3] = float2( 0, 1);
				Deltas[4] = float2(-1,-1);
				Deltas[5] = float2( 1,-1);
				Deltas[6] = float2( 1, 1);
				Deltas[7] = float2(-1, 1);
				float Lengths[DIRECTIONS];
				float LengthPairs[DIRECTIONS/2];
				LengthPairs[0] = 0;
				LengthPairs[1] = 0;
				LengthPairs[2] = 0;
				LengthPairs[3] = 0;

				float MaxLength = 0;
				for ( int i=0;	i<DIRECTIONS;	i++ )
				{
					float Length = GetNonBlackLength( uv, Deltas[i] );

					if ( OverMax(Length) )
						Length = 0;

					Lengths[i] = Length;

					LengthPairs[i/2] += Length;

					if ( OverMax(Length) || Length <= 0 )
						return BadScore;

					//MaxLength = max( MaxLength, Length );

					MaxLength = max( MaxLength, LengthPairs[i/2] );
				}



				float Score = MaxLength / (ScanPixelCount*2);

				if ( Score < MinScore )
					return BadScore;

				return float4( NormalToRedGreen(Score), 1 );

				return float4(0,1,0,1);
				/*
				float LengthX = LengthLeft + LengthRight;
				float LengthY = LengthUp + LengthDown;
				float LengthMax = ScanPixelCount * 4;
				
				float LongestLength = 0;
				//LongestLength = max( LongestLength, LengthX );
				//LongestLength = max( LongestLength, LengthY );
				LongestLength = LengthX + LengthY;

				float LengthNorm = LongestLength / LengthMax;

				float3 rgb = NormalToRedGreen( LengthNorm );

				if ( LengthNorm <= 0 || LengthNorm >= 1 )
					return float4(0,0,0,1);

				//rgb.xyz = !IsBlack(uv);

				return float4( rgb, 1 );

				return float4( LengthNorm, LengthNorm, LengthNorm, 1 );

				if ( IsBlack( i.uv ) )
				{
					return float4(0,0,0,1);
				}

				return float4(1,1,1,1);
				*/
			}
			ENDCG
		}
	}
}
