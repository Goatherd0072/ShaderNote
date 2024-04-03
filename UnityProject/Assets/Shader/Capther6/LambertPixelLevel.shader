Shader "Chapter6/Lambert_PixelLevel"
{
    Properties
    {
        [MainTexture] _MainTex ("Texture", 2D) = "white" {}
        _Diffuse ("Diffuse", Color) = (1,1,1,1)

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
                float2 lightmapUV	: TEXCOORD1;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 PosCS : SV_POSITION;
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
                float3 PosWS : TEXCOORD2;
                float3 normalWS: TEXCOORD3;
            };

            float4 _Diffuse;
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

                // o.normal = TransformObjectToWorldNormal(v.normal);
                // o.vertex = TransformObjectToHClip(v.vertex);

                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
                OUTPUT_SH(o.normalWS, o.vertexSH);

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                // Get Baked GI 
                half3 bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

                // lambert
                // light info
                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 lightCol = mainLight.color;

                float lambert = saturate(dot(i.normalWS, lightDir));
                float3 diffuse =  lightCol*_Diffuse.xyz*lambert;
                MixRealtimeAndBakedGI(mainLight, i.normalWS, bakedGI);
                // sample the texture
                float4 col =float4( bakedGI + diffuse, 1.0f);
                col*=baseMap;
                return col;
            }
            ENDHLSL
        }

    }
}
