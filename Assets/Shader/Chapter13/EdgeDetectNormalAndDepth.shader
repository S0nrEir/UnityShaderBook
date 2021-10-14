//基于深度纹理和法线的3D边缘检测
Shader "ShaderBook/Chapter13/EdgeDetectNormalAndDepth" 
{
	Properties 
	{
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_EdgesOnly("Edges Only",Float) = 1.0
		_EdgeColor("Edge Color",Color) = (0,0,0,1)
		_BackGroundColor("BackGround Color",Color) = (1,1,1,1)
		_SampleDistance("SampleDistance",Float) = 1.0
		_Sensitivity("Sensitivity",Vector) = (1,1,1,1)
	}

	SubShader 
	{
		CGINCLUDE

		#include "UnityCG.cginc"

		//properties:
		sampler2D _MainTex;
		half4 _MainTex_TexelSize;

		fixed _EdgesOnly;
		fixed4 _EdgeColor;
		fixed4 _BackGroundColor;
		float _SampleDistance;
		half4 _Sensitivity;
		sampler2D _CameraDepthNormalsTexture;

		struct v2f
		{
			float4 pos : SV_POSITION;
			half2 uv[5] : TEXCOORD0;
		};

		//vertext:
		v2f vert(appdata_img v)
		{
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			half2 uv = v.texcoord;
			o.uv[0] = uv;

			#if UNITY_UV_STARTS_AT_TOP
				if(_MainTex_TexelSize.y < 0)
					uv.y = 1 - uv.y;
			#endif

			//剩下四组坐标存储了使用roberts算子时需要采样的纹理坐标，并且用distance控制采样距离
			o.uv[1] = uv + _MainTex_TexelSize.xy * half2(1,1) * _SampleDistance;
			o.uv[2] = uv + _MainTex_TexelSize.xy * half2(-1,-1) * _SampleDistance;
			o.uv[3] = uv + _MainTex_TexelSize.xy * half2(-1,1) * _SampleDistance;
			o.uv[4] = uv + _MainTex_TexelSize.xy * half2(1,-1) * _SampleDistance;

			return o;
		}

		half check_same(half4 center,half4 sample)
		{
			half2 center_normal = center.xy;
			float center_depth = DecodeFloatRG(center.zw);

			half2 sample_normal = sample.xy;
			float sample_depth = DecodeFloatRG(sample.zw);

			half2 diff_normal = abs(center_normal - sample_normal) * _Sensitivity.x;
			int is_same_normal = (diff_normal.x + diff_normal.y) < 0.1;

			float diff_depth = abs(center_depth - sample_depth) * _Sensitivity.y;
			int is_same_depth = diff_depth < 0.1 * center_depth;

			return is_same_normal * is_same_depth ? 1.0 : 0.0;
		}

		//fragment
		fixed4 frag(v2f i) : SV_Target
		{
			half4 sample_1 = tex2D(_CameraDepthNormalsTexture, i.uv[1]);//1,1
			half4 sample_2 = tex2D(_CameraDepthNormalsTexture, i.uv[2]);//-1,-1
			half4 sample_3 = tex2D(_CameraDepthNormalsTexture, i.uv[3]);//-1,1
			half4 sample_4 = tex2D(_CameraDepthNormalsTexture, i.uv[4]);//1,-1

			half edge = 1.0;

			edge *= check_same(sample_1,sample_2);
			edge *= check_same(sample_3,sample_4);

			fixed4 with_edge_color = lerp(_EdgeColor, tex2D(_MainTex, i.uv[0]), edge);
			fixed4 only_edge_color = lerp(_EdgeColor, _BackGroundColor, edge);

			return lerp(with_edge_color, only_edge_color, _EdgesOnly); 
		}

		ENDCG

		Pass
		{
			ZTest Always
			Cull Off
			Zwrite Off

			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			ENDCG
		}
	}
	FallBack Off
}
