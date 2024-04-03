Shader "Chapter7/NormalMapWorldSpace"
{
    // 在切线空间下计算法线贴图
    Properties
    {
        [MainTexture] _BaseMap("Base Map (RGB) Smoothness / Alpha (A)", 2D) = "white" {}
        [MainColor]   _BaseColor("Base Color", Color) = (1, 1, 1, 1)

        [NoScaleOffset] _BumpMap("Normal Map", 2D) = "bump" {}
        _BumpScale("Scale", Float) = 1.0

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
                float3x3 worldTBN : TEXCOORD2;
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
                // 计算法线切线转世界空间矩阵
                float3 binormal = cross(v.normal, v.tangent.xyz) * v.tangent.w;
                binormal =  TransformObjectToWorldNormal(binormal);
                float4 tangentWS = float4(TransformObjectToWorldNormal(v.tangent.xyz), v.tangent.w);
                o.worldTBN = float3x3(v.tangent.xyz, binormal, normalInputs.normalWS);                

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


                // 法线贴图计算
                float3 normal = UnpackNormal(SAMPLE_TEXTURE2D(_BumpMap, sampler_BumpMap, i.uv));
                normal.xy *= _BumpScale;
                normal.z = sqrt(1 - saturate(dot(normal.xy, normal.xy)));//通过xy值计算z值，确保z为正
                normal = mul(i.worldTBN ,normal);

                // Albedo
                float3 albedo = baseMap *  _BaseColor.rgb;

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, normal, Ambient);
                Ambient *= albedo;

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,normal));
                float3 Diffuse = lightCol*albedo*lambert;
                
                //高光反射 Specular Blinn-Phong     
                float gloss = lerp(8,255,_Gloss);// 计算高光反射系数
                float3 halfDir = normalize(lightDir + viewDir);
                float3 Specular = _Specular.xyz * lightCol * pow(saturate(dot( normal, halfDir)), gloss) ;// 高光反射

                return float4( Ambient + Diffuse + Specular, 1.0f);
            }
            ENDHLSL
        }
    }
}
