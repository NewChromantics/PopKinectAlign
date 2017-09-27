Shader "PopKinect/Depth16Bit"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		MaxValue("MaxValue", Range(1,4000) ) = 1024
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

			float MaxValue;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				UNITY_TRANSFER_FOG(o,o.vertex);
				return o;
			}

			float Range(float Min,float Max,float Time)
{
	return (Time-Min) / (Max-Min);
}


			float Clamp01(float x) 
{ 
  return clamp( x, 0.0, 1.0 ); 
} 

			//	0 = red, 1=green
float3 NormalToRedGreen(float Value)
{
	if ( Value > 1 )
		return float3( 0,0,1 );
	Value = Clamp01( Value );
	if ( Value < 0.5 )
	{
		float Yellow = Range( 0.0, 0.5, Value );
		return float3( 1.0, Yellow, 0.0 );
	}
	float Yellow = Range( 1.0, 0.5, Value );
	return float3( Yellow, 1.0, 0.0 );
}

			fixed4 frag (v2f i) : SV_Target
			{
				float4 rgba = tex2D(_MainTex, i.uv);
				//float MaxComponentValue = 255;
				float MaxComponentValue = 65536;
				float Value = rgba.w * MaxComponentValue;
				rgba.xyz = NormalToRedGreen( Value / MaxValue );
				rgba.w = 1;
				return rgba;
			}
			ENDCG
		}
	}
}
