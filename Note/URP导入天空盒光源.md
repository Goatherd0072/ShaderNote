---
title: URP如何导入天空盒光源

category:  URP

tags: [URP,Shader]
---

# URP导入天空盒光源

urp版本为14.0.9

首先需要在传入数据中定义lightmapUV 或 vertexSH，具体方法如下

```c#
struct v2f
{
    float2 uv : TEXCOORD0;
    DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 1);
};
```

DECLARE_LIGHTMAP_OR_SH 方法在 URP源码Lighting.hlsl中定义数字表示其为第几号TEXCOORD，下面为源码定义内容

```c#
#if defined(LIGHTMAP_ON)
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) float2 lmName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT) OUT.xy = lightmapUV.xy * lightmapScaleOffset.xy + lightmapScaleOffset.zw;
    #define OUTPUT_SH(normalWS, OUT)
#else
    #define DECLARE_LIGHTMAP_OR_SH(lmName, shName, index) half3 shName : TEXCOORD##index
    #define OUTPUT_LIGHTMAP_UV(lightmapUV, lightmapScaleOffset, OUT)
    #define OUTPUT_SH(normalWS, OUT) OUT.xyz = SampleSHVertex(normalWS)
#endif
```

在结构体中定义后，在VS或者PS中，通过调用方法获取

```C#
OUTPUT_LIGHTMAP_UV(v.lightmapUV, unity_LightmapST, o.lightmapUV);
OUTPUT_SH(o.normalWS, o.vertexSH);
```

在 URP源码GlobalIllumination.hlsl中，可以看到，会从lightmap和probes中获取GI

SH是[球谐函数](https://zh.wikipedia.org/wiki/%E7%90%83%E8%B0%90%E5%87%BD%E6%95%B0)的缩写

```C#
// We either sample GI from baked lightmap or from probes.
// If lightmap: sampleData.xy = lightmapUV
// If probe: sampleData.xyz = L2 SH terms
#if defined(LIGHTMAP_ON) && defined(DYNAMICLIGHTMAP_ON)
#define SAMPLE_GI(staticLmName, dynamicLmName, shName, normalWSName) SampleLightmap(staticLmName, dynamicLmName, normalWSName)
#elif defined(DYNAMICLIGHTMAP_ON)
#define SAMPLE_GI(staticLmName, dynamicLmName, shName, normalWSName) SampleLightmap(0, dynamicLmName, normalWSName)
#elif defined(LIGHTMAP_ON)
#define SAMPLE_GI(staticLmName, shName, normalWSName) SampleLightmap(staticLmName, 0, normalWSName)
#else
#define SAMPLE_GI(staticLmName, shName, normalWSName) SampleSHPixel(shName, normalWSName)
#endif
```

之后使用SAMPLE_GI 方法即可得到天空盒的光

```C#
 half3 bakedGI = SAMPLE_GI(i.lightmapUV, i.vertexSH, i.normalWS);

MixRealtimeAndBakedGI(mainLight, i.normalWS, bakedGI); //好像不写也可以有效果，待后续查明作用
```

示例总览：

以Lambert光照为参考

```c#
Shader "Custorm/Lambert_PixelLevel"
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
                float4 lightCol = float4(mainLight.color, 1.0f);

                float lambert = saturate(dot(i.normalWS, lightDir));
                float4 diffuse =  lightCol*_Diffuse*lambert;
                MixRealtimeAndBakedGI(mainLight, i.normalWS, bakedGI);
                // sample the texture
                float4 col =float4( bakedGI, 1.0f)+ diffuse;
                col*=baseMap;
                return col;
            }
            ENDHLSL
        }

    }
}
```

