Shader "Chapter6/Blinn-Phong"
{
    Properties
    {
        [MainTexture] _MainTex ("Texture", 2D) = "white" {}
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(0, 1)) = 0.5

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        CBUFFER_START(UnityPerMaterial)
            // 以下行声明 _BaseMap_ST 变量，以便可以
            // 在片元着色器中使用 _BaseMap 变量。为了
            // 使平铺和偏移有效，有必要使用 _ST 后缀。
            float4 _MainTex_ST;
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


            struct Attributes
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
                float2 lightmapUV	: TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 PosCS : SV_POSITION;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 PosWS : NORMAL1;
                float3 normalWS: POSITION1;
            };

            float4 _Diffuse;
            float4 _Specular;
            float _Gloss;
            TEXTURE2D( _MainTex);
            SAMPLER(sampler_MainTex);
            

            v2f vert (Attributes v)
            {
                v2f o;
                
                VertexPositionInputs positionInputs = GetVertexPositionInputs(v.vertex.xyz);
                VertexNormalInputs normalInputs = GetVertexNormalInputs(v.normal);
                o.PosCS = positionInputs.positionCS;
                o.PosWS = positionInputs.positionWS;
                o.normalWS = normalInputs.normalWS;

                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);
                
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                // Get Baked GI 
                half3 Ambient = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

                // light info
                // 获取主光源
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float4 lightCol = float4(mainLight.color, 1.0f);

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, i.normalWS, Ambient);

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,i.normalWS));
                float4 Diffuse = lightCol*_Diffuse*lambert;
                
                //高光反射 Specular Blinn-Phong
                float3 viewDir = normalize(_WorldSpaceCameraPos - i.PosWS);//视角方向
                float gloss = lerp(8,255,_Gloss);// 计算高光反射系数
                float3 halfDir = normalize(lightDir + viewDir);
                float4 Specular = _Specular * lightCol * pow(saturate(dot( i.normalWS, halfDir)), gloss) ;// 高光反射

                return float4( Ambient, 1.0f) + Diffuse + Specular;
            }
            ENDHLSL
        }

    }
}
