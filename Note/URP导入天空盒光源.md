URP导入天空盒光源

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

