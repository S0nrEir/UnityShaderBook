// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'
//水波效果
Shader "ShaderBook/Chapter15/WaterWave"
{
    Properties
    {
        //水面颜色
        _Color("Main Color",Color) = (0,0.15, 0.115, 1)
        //主纹理
        _MainTex("Main Tex",2D) = "white"{}
        //水波噪点法线图
        _WaveMap("Wave Map",2D) = "white"{}
        //用于菲尼尔反射的cubeMap
        _CubeMap("Cube Map",Cube) = "_Skybox"{}
        //水波速度
        _WaveXSpeed("Wave X Speed",Range(-0.1,0.1)) = 0.01
        _WaveYSpeed("Wave Y Speed",Range(-0.1,0.1)) = 0.01
        //折射发生时图像的扭曲程度
        _Distortion("Distortion",Range(0,100)) = 10
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Transparent"
            "RenderType" = "Opaque"
        }

        GrabPass{"_RefractionTex"}
        //dissolve
        Pass
        {
            CGPROGRAM

            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            //#include "AutoLight.cginc"

            #pragma vertex water_wave_vert
            #pragma fragment water_wave_frag
            #pragma multi_compile_fwdbase

            fixed4      _Color;
            sampler2D   _MainTex;
            float4      _MainTex_ST;
            sampler2D   _WaveMap;
            float4      _WaveMap_ST;
            samplerCUBE _CubeMap;
            fixed       _WaveXSpeed;
            fixed       _WaveYSpeed;
            float       _Distortion;
            sampler2D   _RefractionTex;
            float4      _RefractionTex_TexelSize;//采样做坐标偏移时需要用到这玩意
            

            struct a2v
            {
                float4 vertex   : POSITION;
                float3 normal   : NORMAL;
                float4 tangent  : TANGENT;
                float4 texcoord : TEXCOORD0;

            };

            struct v2f
            {
                float4 pos      : SV_POSITION;
                float4 scr_pos  : TEXCOORD0;
                float4 uv       : TEXCOORD1;
                float4 T_to_W_0 : TEXCOORD2;
                float4 T_to_W_1 : TEXCOORD3;
                float4 T_to_W_2 : TEXCOORD4;
            };

            v2f water_wave_vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.uv.zw = TRANSFORM_TEX(v.texcoord,_WaveMap);
                //得到对应被抓取屏幕图像的采样坐标(UnityCG.cginc)
                o.scr_pos = ComputeGrabScreenPos(o.pos);

                //获取顶点在世界空间下的坐标位置，法线方向，切线方向，副切线方向
                float3 world_pos = mul(unity_ObjectToWorld,v.vertex).xyz;
                fixed3 world_normal = UnityObjectToWorldNormal(v.normal);
                fixed3 world_tangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 world_binormal = cross(world_normal, world_tangent) * v.tangent.w;

                o.T_to_W_0 = float4(world_tangent.x, world_binormal.x, world_normal.x, world_pos.x);
                o.T_to_W_1 = float4(world_tangent.y, world_binormal.y, world_normal.y, world_pos.y);
                o.T_to_W_2 = float4(world_tangent.z, world_binormal.z, world_normal.z, world_pos.z);

                return o;
            }

            fixed4 water_wave_frag(v2f i) : SV_Target
            {
                float3 world_pos = float3(i.T_to_W_0.w, i.T_to_W_1.w, i.T_to_W_2.w);
                fixed3 view_direction = normalize(UnityWorldSpaceViewDir(world_pos));
                float2 speed = _Time.y * float2(_WaveXSpeed, _WaveYSpeed);
                //采样水波噪点图
                fixed3 bump_1 = UnpackNormal(tex2D(_WaveMap, i.uv.zw + speed)).rgb;
                fixed3 bump_2 = UnpackNormal(tex2D(_WaveMap, i.uv.zw - speed)).rgb;
                fixed3 bump = normalize(bump_1 + bump_2);

                float2 offset = bump.xy * _Distortion * _RefractionTex_TexelSize.xy;
                i.scr_pos.xy = offset * i.scr_pos.z + i.scr_pos.xy;
                fixed3 refr_color = tex2D(_RefractionTex,i.scr_pos.xy / i.scr_pos.w).rgb;

                bump = normalize(half3(
                                        dot(i.T_to_W_0.xyz,bump),
                                        dot(i.T_to_W_1.xyz,bump),
                                        dot(i.T_to_W_2.xyz,bump)
                                      )
                                );

                fixed4 tex_color = tex2D(_MainTex,i.uv.xy + speed);
                fixed3 refl_direction = reflect(-view_direction, bump);
                fixed3 refl_color = texCUBE(_CubeMap, refl_direction).rgb * tex_color.rgb * _Color.rgb;
                fixed fresnel = pow(1 - saturate(dot(view_direction,bump)), 4);
                fixed3 final_color = refl_color * fresnel + refr_color * (1 - fresnel);

                return fixed4(final_color,1);
                
            }

            ENDCG
        }
    }
    FallBack Off
}
