Shader "Chapter10/Refract_CubeMap"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        _refractMap("Refract Map", Cube) = "_skybox" {}
        _RefractAmount("Refract Amount", Range(0, 1)) = 0.5
        _RefractRate("Refract Rate", Range(0, 1)) = 0.5

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
            // 以下行声明 _BaseMap_ST 变量，以便可以
            // 在片元着色器中使用 _BaseMap 变量。为了
            // 使平铺和偏移有效，有必要使用 _ST 后缀。
            float4 _BaseMap_ST;
            float4 _refractMap_ST;
        CBUFFER_END
        ENDHLSL
    }

    SubShader
    {
        Name "Lambert"
        Tags {
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"  
        }
        LOD 200

        Pass
        {
            Tags { "LightMode"="UniversalForward" }

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            // light
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

            // 接收阴影关键字
            // 材质
            #pragma shader_feature_local _RECEIVE_SHADOWS_OFF
            // 渲染管线
            #pragma multi_compile_fragment _ _SHADOWS_SOFT _SHADOWS_SOFT_LOW _SHADOWS_SOFT_MEDIUM _SHADOWS_SOFT_HIGH
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            

            #pragma shader_feature Enable_AdditionalLights
            //多光源计算的开关变量

            float4 _BaseColor;
            float _RefractAmount;
            float _RefractRate;

            TEXTURE2D( _BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURECUBE( _refractMap);
            SAMPLER(sampler_refractMap);

            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float2 lightmapUV	: TEXCOORD1;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 worldRefract : TEXCOORD2;
                float4 PosCS : SV_POSITION;
                float3 PosWS : NORMAL1;
                float3 normalWS: POSITION1;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal);
                o.PosCS = positionInputs.positionCS;
                o.PosWS = positionInputs.positionWS;
                o.normalWS = normalInputs.normalWS;

                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

                // 计算反射向量
                float3 worldView = GetCameraPositionWS() - o.PosWS;
                o.worldRefract = refract(-worldView, (o.normalWS), _RefractRate);
                return o;
            }

            float4 frag (Varyings i) : SV_Target
            {
                float4 baseMap = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, i.uv);
                float3 refractMap = SAMPLE_TEXTURECUBE(_refractMap, sampler_refractMap, i.worldRefract).xyz;

                // Get Baked GI 
                half3 Ambient = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

                // light info
                // 获取主光源
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 lightCol = mainLight.color;

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, i.normalWS, Ambient);

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,i.normalWS));
                float3 Diffuse = lightCol * _BaseColor.xyz  * baseMap.rgb * lambert;
                
                float3 output = Ambient + lerp(Diffuse, refractMap, _RefractAmount) * mainLight.distanceAttenuation;
                
                return float4(output , 1.0f);
            }
            ENDHLSL
        }

        Pass
        {
            Tags { "LightMode"="ShadowCaster" }
            ZWrite On
            ZTest LEqual
            Cull Off

            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"


            float3 _LightDirection;
            float3 _LightPosition;

            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Varyings
            {
                float4 pos : SV_POSITION;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                float3 worldPos = TransformObjectToWorld(v.vertex.xyz);
                float3 worldNormal = TransformObjectToWorldNormal(v.normal);
                o.pos = TransformWorldToHClip(ApplyShadowBias(worldPos, worldNormal, _LightDirection));
                return o;
            }

            float4 frag (Varyings i) : SV_Target
            {
                return 0;
            }

            ENDHLSL
        }
    }


}
