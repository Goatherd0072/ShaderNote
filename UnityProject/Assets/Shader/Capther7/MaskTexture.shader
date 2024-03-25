Shader "Chapter7/MaskTexture"
{
    // 遮罩纹理
    Properties
    {
        [MainTexture] _BaseMap("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Scale", Float) = 1.0

        _SpecularMask ("Specular Mask", 2D) = "white" {}
        _SpecularMaskScale ("Specular Mask Scale", Float) = 1.0
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(0, 1)) = 0.5

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
            // 以下行声明 _BaseMap_ST 变量，以便可以
            // 在片元着色器中使用 _BaseMap 变量。为了
            // 使平铺和偏移有效，有必要使用 _ST 后缀。
            float4 _BaseMap_ST;
            float4 _BumpMap_ST;
            float4 _SpecularMask_ST;
        CBUFFER_END
        ENDHLSL
    }

    SubShader
    {
        Name "Lambert"
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline"  "LightMode"="UniversalForward" }
        LOD 200

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // light
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

            float4 _BaseColor;
            float4 _Specular;
            float _Gloss;
            float _BumpScale;
            float _SpecularMaskScale;
            TEXTURE2D( _BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D( _BumpMap);
            SAMPLER(sampler_BumpMap);
            TEXTURE2D( _SpecularMask);
            SAMPLER(sampler_SpecularMask);

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                float2 uv : TEXCOORD0;
                float2 lightmapUV	: TEXCOORD1;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 PosCS : SV_POSITION;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 PosWS : NORMAL1;
                float3 normalWS: POSITION1;
                float3x3 TangentTBN : TEXCOORD2;
            };
            
            Varyings vert (Attributes v)
            {
                Varyings o;
                
                // 坐标处理
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal);
                o.PosCS = positionInputs.positionCS;
                o.PosWS = positionInputs.positionWS;
                o.normalWS = normalInputs.normalWS;
                
                //计算光照信息
                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);

                // 法线贴图
                // 计算切线空间转换矩阵
                float3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;//tangent.w这是切线空间的手性（handedness），通常用于指示切线空间的方向。它可以是1或-1。
                float3x3 TBN = float3x3(v.tangent.xyz, binormal, v.normal);
                //TBN是一个正交矩阵，因为它的列向量是归一化且互相正交的。这个矩阵将对象空间中的向量转换到切线空间
                o.TangentTBN = TBN;

                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                return o;
            }

            float4 frag (Varyings i) : SV_Target
            {
                float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);

                // Get Baked GI 
                half3 Ambient = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

                // light info
                // 获取主光源
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float4 lightCol = float4(mainLight.color, 1.0f);

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.PosWS);//视角方向
                // 将光照方向和视角方向转换到切线空间
                lightDir = mul(i.TangentTBN, lightDir);
                viewDir = mul(i.TangentTBN, viewDir);

                // 法线贴图计算
                float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                normal.xy *= _BumpScale;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));//通过xy值计算z值，确保z为正

                // Albedo
                float3 albedo = SAMPLE_TEXTURE2D(_BaseMap,sampler_BaseMap,i.uv) *  _BaseColor.rgb;

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, normal, Ambient);
                Ambient *= albedo;

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,normal));
                float4 Diffuse = float4( lightCol*albedo*lambert, 1.0f );
                
                //高光反射 Specular Blinn-Phong     
                float gloss = lerp(8,255,_Gloss);// 计算高光反射系数
                float3 halfDir = normalize(lightDir + viewDir);

                //Specular Mask
                float specMask = SAMPLE_TEXTURE2D(_SpecularMask, sampler_SpecularMask, i.uv).r * _SpecularMaskScale;
                float4 Specular = _Specular * lightCol * pow(saturate(dot( normal, halfDir)), gloss) * specMask ;// 高光反射

                return float4( Ambient, 1.0f) + Diffuse + Specular;
            }
            ENDHLSL
        }
    }
}
