Shader "RenderObj"
{
    Properties
    {
        _BaseColor("Color", Color) = (1,1,1,1)
        _BaseMap("Albedo", 2D) = "white" {}
        _Smoothness("Smoothness", Range(0,1)) = 0.5
        _Metallic("Metallic", Range(0,1)) = 0.0
    }

    SubShader
    {
        Tags 
        { 
            "RenderType" = "Opaque" 
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        LOD 300

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore
            #pragma multi_compile_instancing
            #pragma multi_compile_fog
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma vertex LitPassVertex
            #pragma fragment LitPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3;
                half4 fogFactorAndVertexLight : TEXCOORD4;
                float4 shadowCoord : TEXCOORD5;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct vertData
            {
                float3 pos;
                float2 uvs;
                float3 norms;
            };

            CBUFFER_START(UnityPerMaterial)
                float4 _BaseColor;
                float4 _BaseMap_ST;
                float _Smoothness;
                float _Metallic;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);

            #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                StructuredBuffer<vertData> vertsBuff;
                StructuredBuffer<int> triBuff;
            #endif

            float4x4 TRSMatrix;
            float4x4 invTRSMatrix;

            Varyings LitPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                    int bufferIndex = triBuff[input.vertexID];
                    vertData vData = vertsBuff[bufferIndex];
                    
                    float3 positionOS = vData.pos;
                    float3 normalOS = vData.norms;
                    float2 uv = vData.uvs;
                #else
                    float3 positionOS = input.positionOS.xyz;
                    float3 normalOS = input.normalOS;
                    float2 uv = input.texcoord;
                #endif

                // Normal 정규화 및 검증
                normalOS = normalize(normalOS);
                if (length(normalOS) < 0.01)
                {
                    normalOS = float3(0, 1, 0);
                }

                VertexPositionInputs vertexInput = GetVertexPositionInputs(positionOS);
                VertexNormalInputs normalInput = GetVertexNormalInputs(normalOS);

                output.uv = TRANSFORM_TEX(uv, _BaseMap);
                output.positionWS = vertexInput.positionWS;
                output.positionCS = vertexInput.positionCS;
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = GetWorldSpaceViewDir(vertexInput.positionWS);

                half3 vertexLight = VertexLighting(vertexInput.positionWS, normalInput.normalWS);
                half fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
                output.fogFactorAndVertexLight = half4(fogFactor, vertexLight);

                output.shadowCoord = GetShadowCoord(vertexInput);

                return output;
            }

            half4 LitPassFragment(Varyings input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                // 텍스처 샘플링
                half4 albedoAlpha = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv);
                
                // Material 색상
                half3 albedo = albedoAlpha.rgb * _BaseColor.rgb;
                half alpha = albedoAlpha.a * _BaseColor.a;

                // Normal 정규화
                half3 normalWS = normalize(input.normalWS);
                half3 viewDirWS = SafeNormalize(input.viewDirWS);
                
                // InputData 설정
                InputData inputData;
                inputData.positionWS = input.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = viewDirWS;
                inputData.shadowCoord = input.shadowCoord;
                inputData.fogCoord = input.fogFactorAndVertexLight.x;
                inputData.vertexLighting = input.fogFactorAndVertexLight.yzw;
                inputData.bakedGI = half3(0, 0, 0); // GI는 나중에 추가
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
                inputData.shadowMask = half4(1, 1, 1, 1);

                // SurfaceData 설정
                SurfaceData surfaceData;
                surfaceData.albedo = albedo;
                surfaceData.specular = half3(0, 0, 0);
                surfaceData.metallic = _Metallic;
                surfaceData.smoothness = _Smoothness;
                surfaceData.normalTS = half3(0, 0, 1);
                surfaceData.emission = half3(0, 0, 0);
                surfaceData.occlusion = 1.0;
                surfaceData.alpha = alpha;
                surfaceData.clearCoatMask = 0.0;
                surfaceData.clearCoatSmoothness = 0.0;

                // Main Light 계산
                Light mainLight = GetMainLight(inputData.shadowCoord);
                
                // Diffuse lighting (Lambert)
                half NdotL = saturate(dot(normalWS, mainLight.direction));
                half3 diffuse = mainLight.color * NdotL * mainLight.shadowAttenuation;
                
                // Specular lighting (Blinn-Phong)
                half3 halfDir = normalize(mainLight.direction + viewDirWS);
                half NdotH = saturate(dot(normalWS, halfDir));
                half specularPower = exp2(10 * _Smoothness + 1); // 2^(10*smoothness + 1)
                half3 specular = mainLight.color * pow(NdotH, specularPower) * _Smoothness * mainLight.shadowAttenuation;
                
                // Ambient light (간접광)
                half3 ambient = half3(0.2, 0.2, 0.2); // 기본 환경광
                
                // Rim lighting (입체감 강화)
                half rim = 1.0 - saturate(dot(viewDirWS, normalWS));
                rim = pow(rim, 3.0); // 가장자리 강조
                half3 rimLight = rim * half3(0.3, 0.3, 0.3);
                
                // 최종 색상 계산
                half3 lighting = diffuse + ambient + specular + rimLight;
                half4 color = half4(albedo * lighting, alpha);
                
                // 입체감을 위한 추가 조명 (Additional Lights)
                #ifdef _ADDITIONAL_LIGHTS
                    uint pixelLightCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, inputData.positionWS);
                        half NdotL2 = saturate(dot(normalWS, light.direction));
                        color.rgb += albedo * light.color * NdotL2 * light.distanceAttenuation * light.shadowAttenuation;
                    }
                #endif

                // Fog 적용
                color.rgb = MixFog(color.rgb, inputData.fogCoord);

                return color;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster" }

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore
            #pragma multi_compile_instancing
            #pragma multi_compile _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct vertData
            {
                float3 pos;
                float2 uvs;
                float3 norms;
            };

            #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                StructuredBuffer<vertData> vertsBuff;
                StructuredBuffer<int> triBuff;
            #endif

            float3 _LightDirection;
            float3 _LightPosition;

            Varyings ShadowPassVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                    int bufferIndex = triBuff[input.vertexID];
                    vertData vData = vertsBuff[bufferIndex];
                    float3 positionOS = vData.pos;
                    float3 normalOS = vData.norms;
                #else
                    float3 positionOS = input.positionOS.xyz;
                    float3 normalOS = input.normalOS;
                #endif

                normalOS = normalize(normalOS);
                if (length(normalOS) < 0.01)
                {
                    normalOS = float3(0, 1, 0);
                }

                float3 positionWS = TransformObjectToWorld(positionOS);
                float3 normalWS = TransformObjectToWorldNormal(normalOS);

                #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                    float3 lightDirectionWS = normalize(_LightPosition - positionWS);
                #else
                    float3 lightDirectionWS = _LightDirection;
                #endif

                output.positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

                #if UNITY_REVERSED_Z
                    output.positionCS.z = min(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #else
                    output.positionCS.z = max(output.positionCS.z, UNITY_NEAR_CLIP_VALUE);
                #endif

                return output;
            }

            half4 ShadowPassFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags { "LightMode" = "DepthOnly" }

            ZWrite On
            ColorMask 0
            Cull Back

            HLSLPROGRAM
            #pragma target 4.5
            #pragma exclude_renderers gles gles3 glcore
            #pragma multi_compile_instancing

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                uint vertexID : SV_VertexID;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            struct vertData
            {
                float3 pos;
                float2 uvs;
                float3 norms;
            };

            #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                StructuredBuffer<vertData> vertsBuff;
                StructuredBuffer<int> triBuff;
            #endif

            Varyings DepthOnlyVertex(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                #if defined(SHADER_API_D3D11) || defined(SHADER_API_VULKAN) || defined(SHADER_API_METAL)
                    int bufferIndex = triBuff[input.vertexID];
                    vertData vData = vertsBuff[bufferIndex];
                    float3 positionOS = vData.pos;
                #else
                    float3 positionOS = input.positionOS.xyz;
                #endif

                output.positionCS = TransformObjectToHClip(positionOS);
                return output;
            }

            half4 DepthOnlyFragment(Varyings input) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                return 0;
            }
            ENDHLSL
        }
    }

    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
