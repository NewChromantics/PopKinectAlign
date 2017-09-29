Shader "PopKinect/Point Cloud"
{
	Properties
	{
		DepthTexture("DepthTexture", 2D ) = "black" {}
		DepthDistanceMin("DepthDistanceMin", Range(0,20) ) = 0.1
		DepthDistanceMax("DepthDistanceMax", Range(0,20) ) = 10
		DepthValueMax("DepthValueMax", Range(0,2048) ) = 2047
		ColourTexture("ColourTexture", 2D ) = "white" {}
		ColourFieldOfViewHorizontal("ColourFieldOfViewHorizontal", Range(0,180) ) = 58.5
		ColourFieldOfViewVertical("ColourFieldOfViewVertical", Range(0,180) ) = 45.6

		BeeScale("BeeScale", Range(0.01,1) ) = 0.1
		Billboard("Billboard", Range(0,1) ) = 1
		BeeAtlas("BeeAtlas", 2D ) = "white" {}
		ForceAtlasIndex("ForceAtlasIndex", Range(-1,3) ) = -1
		ClipRadius("ClipRadius", Range(0,1) ) = 1
		AtlasSectionScale("AtlasSectionScale", Range(0.5,3) ) = 1
		RandomAtlas("RandomAtlas", Range(0,1) ) = 0

		ColourMult("ColourMult", Range(1,2) ) = 1
		ColourSquaredFactor("ColourSquaredFactor", Range(0,1) ) = 0

		Debug_ClipRadius("Debug_ClipRadius", Range(0,1) ) = 0
		Debug_TriangleUv("Debug_TriangleUv", Range(0,1) ) = 0

		ClipInsideCameraRadius("ClipInsideCameraRadius", Range(0,1) ) = 0.5
		MinDistanceFromCamera("MinDistanceFromCamera", Range(0,1) ) = 0

		MinScreenSize("MinScreenSize", Range(0,0.1) ) = 0
		FogStrength("FogStrength", Range(0,1) ) = 1
	}
	SubShader
	{
		Tags { "RenderType"="Transparent" "Queue"="Transparent" }
		LOD 100
		Cull Off
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "../PopUnityCommon/PopCommon.cginc"

			struct appdata
			{
				float4 LocalPosition : POSITION;
				float2 TriangleIndex_CornerIndex : TEXCOORD0;
			};

			struct v2f
			{
				float4 ClipPos : SV_POSITION;
				float3 Colour : TEXCOORD0;
				float2 TexCoord : TEXCOORD1;
				float2 LocalPos : TEXCOORD3;
				float3 WorldPos : TEXCOORD4;
			};

			sampler2D DepthTexture;
			float DepthDistanceMin;
			float DepthDistanceMax;
			float DepthValueMax;

			sampler2D ColourTexture;
			float4 ColourTexture_TexelSize;
			float BeeScale;
			float MinScreenSize;
			float Billboard;
			float AtlasSectionScale;

			float ClipRadius;
			float Debug_ClipRadius;
			float Debug_TriangleUv;
			float RandomAtlas;

			float ColourMult;
			float ColourSquaredFactor;
			float FogStrength;

			float4x4 CameraLocalToWorldMatrix;
			float ClipInsideCameraRadius;		//	hide
			float MinDistanceFromCamera;		//	reposition

			float ColourFieldOfViewHorizontal;
			float ColourFieldOfViewVertical;

			#define DEBUG_CLIPRADIUS	( Debug_ClipRadius > 0.5f )
			#define DEBUG_TRIANGLEUV	( Debug_TriangleUv > 0.5f )

			#define ENABLE_RANDOMATLAS	( RandomAtlas > 0.5f )
			#define ENABLE_BILLBOARD	( Billboard > 0.5f )



			float GetScreenCorrectionScalar(float3 WorldPos,float3 LocalOffset)
			{
				float4 ViewCenter = mul( UNITY_MATRIX_V, float4(WorldPos,1) );
				float4 ViewOffset = ViewCenter + float4( LocalOffset, 0 );

				float4 ScreenCenter4 = mul( UNITY_MATRIX_P, ViewCenter );
				float4 ScreenOffset4 = mul( UNITY_MATRIX_P, ViewOffset );

				float2 ScreenCenter = ScreenCenter4.xy / ScreenCenter4.w;
				float2 ScreenOffset = ScreenOffset4.xy / ScreenOffset4.w;

				//	this should be (half) width in screenspace, so if its too small, we HOPE we can correct the view pos
				//	(technically its not, but should only affect when far away)
				float ScreenSize = length( ScreenCenter - ScreenOffset );
				if ( ScreenSize > MinScreenSize )
					return 1;

				return MinScreenSize / ScreenSize;					
			}

			float3 GetWorldPosition(float2 uv,out float Valid)
			{
				float Depth = tex2Dlod( DepthTexture, float4( uv, 0, 0 ) ).w;

				Depth *= 65536;
				Valid = Depth < DepthValueMax;

				Depth = Range( 0, DepthValueMax, Depth );
				Depth = lerp( DepthDistanceMin, DepthDistanceMax, Depth );


				float3 dir = float3(0,0,1);

				float anglex = (uv.x - 0.5f) * 2.0f;
				float fovhrad = radians( anglex * ColourFieldOfViewHorizontal );
				dir.x = tan (fovhrad);

				float angley = ( (1-uv.y) - 0.5f) * 2.0f;
				float fovvrad = radians( angley * ColourFieldOfViewVertical );
				dir.y = tan (fovvrad);

				dir *= Depth;

				float3 WorldPos = mul( UNITY_MATRIX_M, float4(dir,1) );
				return WorldPos;
			}

			v2f vert (appdata v)
			{
				v2f o;

				float4 LocalPos = v.LocalPosition;

				int BeeIndex = v.TriangleIndex_CornerIndex.x;
				//int Width = sqrt(10000);
				int Width = 100;
				int Height = 100;
				float x = BeeIndex % Width;
				float y = BeeIndex / Width;
				//float2 uv = float2( x, y ) * ColourTexture_TexelSize.xy;
				float2 uv = float2( x, y ) / float2( Width, Height );
				float ValidScale = 1;
				float3 WorldPos = GetWorldPosition( uv, ValidScale );

				float ScalarCorrection = GetScreenCorrectionScalar( WorldPos, LocalPos * BeeScale );

				//	gr: why am I using CameraLocalToWorldMatrix?
				//float3 CameraPos = mul( CameraLocalToWorldMatrix, float4(0,0,0,1) );
				float3 CameraPos = _WorldSpaceCameraPos;
				float3 DeltaToCamera = WorldPos - CameraPos;

				//	force distance to be away from camera
				float DistanceToCamera = length( DeltaToCamera );
				DistanceToCamera = max( DistanceToCamera, MinDistanceFromCamera );
				DeltaToCamera = normalize( DeltaToCamera ) * DistanceToCamera;
				WorldPos = CameraPos + DeltaToCamera;

				if ( ENABLE_BILLBOARD )
				{
					//	+ offset here is billboarding in view space
					float3 ViewPos = mul( UNITY_MATRIX_V, float4(WorldPos,1) ) + ( LocalPos * BeeScale * ScalarCorrection);
					o.ClipPos = mul( UNITY_MATRIX_P, float4(ViewPos,1) );
				}
				else
				{
					WorldPos += LocalPos * BeeScale;
					o.ClipPos = UnityWorldToClipPos( float4(WorldPos,1) );
				}


				if ( DistanceToCamera < ClipInsideCameraRadius )
				{
					o.ClipPos = 0;
				}

				o.ClipPos *= ValidScale;

				float IndexNorm = BeeIndex / 10000.0f;
				o.Colour = NormalToRedGreen( IndexNorm );


				o.TexCoord = uv;
				o.LocalPos = LocalPos;
				o.WorldPos = WorldPos;

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				if ( length( i.LocalPos ) > ClipRadius )
				{
					if ( DEBUG_CLIPRADIUS )
						return float4(1,0,0,1);
					discard;
				}

				float2 uv = i.TexCoord;

				if ( DEBUG_TRIANGLEUV )
				{
					if ( uv.x < 0 || uv.x > 1 || uv.y < 0 || uv.y > 1 )
						return float4(0,0,1,1);
					return float4( uv, 0, 1 );
				}

				float4 Colour = tex2D( ColourTexture, uv );
				return Colour;

			}
			ENDCG
		}
	}
}
