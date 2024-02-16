Shader "Chapter6/Specular_VertexLevel"
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
        LOD 100

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
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
            };

            struct v2f
            {
                float4 color : COLOR;
                float4 PosCS : SV_POSITION;
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
                float3 PosWS = positionInputs.positionWS;
                float3 normalWS = normalInputs.normalWS;

                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, v.lightmapUV);
                OUTPUT_SH(normalWS, v.vertexSH);
                
                float2 uv = TRANSFORM_TEX(v.uv, _MainTex);

                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);

                // Get Baked GI 
                half3 Ambient = SAMPLE_GI(v.lightmapUV, v.vertexSH, normalWS);

                // light info
                // 获取主光源
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float4 lightCol = float4(mainLight.color, 1.0f);

                // Mix Realtime and Baked GI
                // 获取环境光照 Ambient
                MixRealtimeAndBakedGI(mainLight, normalWS, Ambient);

                // 漫反射 Diffuse
                float lambert  = saturate(dot(lightDir,normalWS));
                float4 Diffuse = lightCol*_Diffuse*lambert;
                
                //高光反射 Specular
                float3 reflectDir = normalize(reflect(lightDir, normalWS));//反射方向
                float3 viewDir = normalize(PosWS - _WorldSpaceCameraPos);//视角方向
                float gloss = lerp(8,255,_Gloss);// 计算高光反射系数
                float4 Specular = _Specular * lightCol * pow(saturate(dot( viewDir, reflectDir)), gloss) ;// 高光反射

                o.color =  float4( Ambient, 1.0f) + Diffuse + Specular;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                return i.color;
            }
            ENDHLSL
        }

    }
}
