Shader "Chapter6/Lambert_VertexLevel"
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
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
            };

            struct v2f
            {
                float4 color : COLOR;
                float4 PosCS : SV_POSITION;
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

                // 计算skybox光照
                OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, v.lightmapUV);
                OUTPUT_SH(normalInputs.normalWS, v.vertexSH);
                half3 bakedGI = SAMPLE_GI(v.lvghtmapUV, v.vertexSH,normalInputs.normalWS);

                Light mainLight = GetMainLight();
                float3 lightDir = normalize(mainLight.direction);
                float3 lightCol = mainLight.color;

                float2 uv = TRANSFORM_TEX(v.uv, _MainTex);
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                
                float lambert = saturate(dot(normalInputs.normalWS, lightDir));
                float3 diffuse =  lightCol*_Diffuse.xyz*lambert;

                o.color = float4(bakedGI + diffuse ,1.0f);

                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float4 col = i.color;

                return col;
            }
            ENDHLSL
        }

    }
}
