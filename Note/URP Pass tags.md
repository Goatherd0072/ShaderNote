# URP Pass Tags

URP 和 Build-in有一大主要的区别就是对于光线的处理。Build-in采用多Pass渲染，每多一个动态光就多一个Pass，而URP则是使用单个Pass渲染光照。

[官方文档](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@16.0/manual/urp-shaders/urp-shaderlab-pass-tags.html)

## LightMode

Tag LightMode 的作用则是用于让渲染管线知道该不同阶段所需要用的Pass是什么。

如果没有给Tag赋值，则使用默认值  ***SRPDefaultUnlit*** 。

| **Property**             | **Description**                                              | **Description** 原文                                         |
| :----------------------- | :----------------------------------------------------------- | :----------------------------------------------------------- |
| **UniversalForward**     | 渲染 所有光照、几何体<br />前向渲染                          | The Pass renders object geometry and evaluates all light contributions. URP uses this tag value in the Forward Rendering Path. |
| **UniversalGBuffer**     | 渲染 几何体<br />延迟渲染                                    | The Pass renders object geometry without evaluating any light contribution. Use this tag value in Passes that Unity must execute in the Deferred Rendering Path. |
| **UniversalForwardOnly** | 渲染 所有光照、几何体<br />只能前向渲染                      | The Pass renders object geometry and evaluates all light contributions, similarly to when **LightMode** has the **UniversalForward** value. The difference from **UniversalForward** is that URP can use the Pass for both the Forward and the Deferred Rendering Paths. Use this value if a certain Pass must render objects with the Forward Rendering Path when URP is using the Deferred Rendering Path. For example, use this tag if URP renders a scene using the Deferred Rendering Path and the scene contains objects with shader data that does not fit the GBuffer, such as Clear Coat normals. If a shader must render in both the Forward and the Deferred Rendering Paths, declare two Passes with the `UniversalForward` and `UniversalGBuffer` tag values. If a shader must render using the Forward Rendering Path regardless of the Rendering Path that the URP Renderer uses, declare only a Pass with the `LightMode` tag set to `UniversalForwardOnly`. If you use the SSAO Renderer Feature, add a Pass with the `LightMode` tag set to `DepthNormalsOnly`. For more information, check the `DepthNormalsOnly` value. |
| **DepthNormalsOnly**     | 渲染 几何体<br />只能延迟渲染                                | Use this value in combination with `UniversalForwardOnly` in the Deferred Rendering Path. This value lets Unity render the shader in the Depth and normal prepass. In the Deferred Rendering Path, if the Pass with the `DepthNormalsOnly` tag value is missing, Unity does not generate the ambient occlusion around the Mesh. |
| **Universal2D**          | 渲染 所有2D光照、几何体<br />2D渲染                          | The Pass renders objects and evaluates 2D light contributions. URP uses this tag value in the 2D Renderer. |
| **ShadowCaster**         | 从灯光视角，渲染所有几何体到Shadow Map或者深度纹理(depth texture)中 | The Pass renders object depth from the perspective of lights into the Shadow map or a depth texture. |
| **DepthOnly**            | 将相机视角下的深度信息渲染成深度纹理。                       | The Pass renders only depth information from the perspective of a Camera into a depth texture. |
| **Meta**                 | Baking...<br />只有烘培和打包时候会执行                      | Unity executes this Pass only when baking lightmaps in the Unity Editor. Unity strips this Pass from shaders when building a Player. |
| **SRPDefaultUnlit**      | 使用这个Tag后，物体被渲染的时候会额外绘制一个Pass            | Use this `LightMode` tag value to draw an extra Pass when rendering objects. Application example: draw an object outline. This tag value is valid for both the Forward and the Deferred Rendering Paths. URP uses this tag value as the default value when a Pass does not have a `LightMode` tag. |
| **MotionVectors**        | add motion vector support                                    | Use this tag to add motion vector support to your shader. For more information, refer to [Motion vector pass for ShaderLab](https://docs.unity3d.com/Packages/com.unity.render-pipelines.universal@16.0/manual/features/motion-vectors.html#motion-vectors-in-shaderlab). |