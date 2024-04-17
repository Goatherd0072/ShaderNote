Shader "Chapter10/Reflect"
{
    Properties
    {
        [MainTexture] _BaseMap("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SkyMap("Sky",Cube) = "_Skybox"{}

        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Scale", Float) = 1.0

        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(0, 1)) = 0.5
        [Toggle(Enable_AdditionalLights)] _AddLights ("AddLights", Float) = 1
        //多光源计算开关

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
            // 以下行声明 _BaseMap_ST 变量，以便可以
            // 在片元着色器中使用 _BaseMap 变量。为了
            // 使平铺和偏移有效，有必要使用 _ST 后缀。
            float4 _BaseMap_ST;
            float4 _BumpMap_ST;
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
            float4 _Specular;
            float _Gloss;
            float _BumpScale;
            TEXTURE2D( _BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D( _BumpMap);
            SAMPLER(sampler_BumpMap);


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
                float3 lightCol = mainLight.color;

                float3 viewDir = normalize(_WorldSpaceCameraPos - i.PosWS);//视角方向
                // 将光照方向和视角方向转换到切线空间
                lightDir = mul(i.TangentTBN, lightDir);
                viewDir = mul(i.TangentTBN, viewDir);

                // 法线贴图计算
                float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                normal.xy *= _BumpScale;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));//通过xy值计算z值，确保z为正

                // Albedo
                float3 albedo = baseMap.xyz *  _BaseColor.rgb;

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, normal, Ambient);
                Ambient *= mainLight.distanceAttenuation;
                Ambient *= albedo;

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,normal));
                float3 Diffuse = lightCol*albedo*lambert;
                
                //高光反射 Specular Blinn-Phong     
                float gloss = lerp(8,255,_Gloss);// 计算高光反射系数
                float3 halfDir = normalize(lightDir + viewDir);
                float3 Specular = _Specular.xyz * lightCol * pow(saturate(dot( normal, halfDir)), gloss) ;// 高光反射
                
                float3 output = Ambient + Diffuse + Specular;

                // 检测额外光源
                #ifdef Enable_AdditionalLights
                    int lightCount = GetAdditionalLightsCount();
                    //获取AddLight的数量和ID
                    for(int index = 0; index < lightCount; index++)
                    {
                        Light light = GetAdditionalLight(index, i.PosWS);     
                        //获取其它的副光源世界位置
                        
                        half3 diffuseAdd = light.color*_BaseColor.rgb * saturate(dot(light.direction , i.normalWS));
                        half3 halfDir1 = normalize(light.direction + viewDir);
                        half3 specularAdd = light.color * Specular.rgb * pow(saturate(dot(i.normalWS, halfDir1)), gloss);
                        //计算副光源的高光颜色
                        output += (diffuseAdd + specularAdd)*light.distanceAttenuation;
                        //上面单颜色增加新计算的颜色
                    }
                #endif

                return float4(output, 1.0f);
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
