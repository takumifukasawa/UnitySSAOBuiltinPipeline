Shader "Hidden/Custom/SSAO"
{
    HLSLINCLUDE
    // StdLib.hlsl holds pre-configured vertex shaders (VertDefault), varying structs (VaryingsDefault), and most of the data you need to write common effects.
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);
    // Lerp the pixel color with the luminance using the _Blend uniform.
    float _Blend;
    float _DepthOrNormal;
    float4x4 _ViewMatrix;
    float4x4 _ViewProjectionMatrix;
    float4x4 _ProjectionMatrix;
    float4x4 _InverseViewMatrix;
    float4x4 _InverseViewProjectionMatrix;
    float4x4 _InverseProjectionMatrix;
    float4 _SamplingPoints[64];
    float _OcclusionSampleLength;
    float _OcclusionMinDistance;
    float _OcclusionMaxDistance;
    float _OcclusionStrength;

    // --------------------------------------------------------------------------
    // start: partial include from UnityCG.cginc
    // --------------------------------------------------------------------------

    // inline float DecodeFloatRG(float2 enc)
    // {
    //     float2 kDecodeDot = float2(1.0, 1 / 255.0);
    //     return dot(enc, kDecodeDot);
    // }

    // inline void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
    // {
    //     depth = DecodeFloatRG (enc.zw);
    //     normal = DecodeViewNormalStereo (enc);
    // }

    // --------------------------------------------------------------------------
    // end: partial include from UnityCG.cginc
    // --------------------------------------------------------------------------

    // ------------------------------------------------------------------------------------------------
    // ref: https://github.com/Unity-Technologies/PostProcessing/blob/v2/PostProcessing/Shaders/Builtins/ScalableAO.hlsl
    // ------------------------------------------------------------------------------------------------

    // Boundary check for depth sampler
    // (returns a very large value if it lies out of bounds)
    float CheckBounds(float2 uv, float d)
    {
        float ob = any(uv < 0) + any(uv > 1);
        #if defined(UNITY_REVERSED_Z)
        ob += (d <= 0.00001);
        #else
        ob += (d >= 0.99999);
        #endif
        return ob * 1e8;
    }

    // Depth/normal sampling functions
    // ビュー空間のカメラからの距離
    float SampleDepth(float2 uv)
    {
        float d = Linear01Depth(SAMPLE_DEPTH_TEXTURE_LOD(
            _CameraDepthTexture,
            sampler_CameraDepthTexture,
            UnityStereoTransformScreenSpaceTex(uv),
            0
        ));
        // _ProjectionParams.z ... camera far clip
        // カメラからの距離なので linear01 depth に far clip をかけてる
        return _ProjectionParams.y + d * _ProjectionParams.z + CheckBounds(uv, d);
    }

    // ビュー空間の法線
    float3 SampleNormal(float2 uv)
    {
        #if defined(SOURCE_GBUFFER)
    float3 norm = SAMPLE_TEXTURE2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv).xyz;
    norm = norm * 2 - any(norm); // gets (0,0,0) when norm == 0
    norm = mul((float3x3)unity_WorldToCamera, norm);
        #if defined(VALIDATE_NORMALS)
    norm = normalize(norm);
        #endif
    return norm;
        #else
        float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        return DecodeViewNormalStereo(cdn) * float3(1.0, 1.0, -1.0);
        #endif
    }

    float SampleDepthNormal(float2 uv, out float3 normal)
    {
        normal = SampleNormal(UnityStereoTransformScreenSpaceTex(uv));
        return SampleDepth(uv);
    }

    float3 SampleViewNormal(float2 uv)
    {
        float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        return DecodeViewNormalStereo(cdn) * float3(1., 1., 1.);
    }

    // ------------------------------------------------------------------------------------------------
    // ------------------------------------------------------------------------------------------------

    float3 ReconstructWorldPositionFromDepth(float2 screenUV, float depth)
    {
        // TODO: depthはgraphicsAPIを考慮している必要があるはず
        float4 clipPos = float4(screenUV * 2.0 - 1.0, depth, 1.0);
        #if UNITY_UV_STARTS_AT_TOP
        clipPos.y = -clipPos.y;
        #endif
        float4 worldPos = mul(_InverseViewProjectionMatrix, clipPos);
        return worldPos.xyz / worldPos.w;
    }

    float3 ReconstructViewPositionFromDepth(float2 screenUV, float depth)
    {
        // TODO: depthはgraphicsAPIを考慮している必要があるはず
        float4 clipPos = float4(screenUV * 2.0 - 1.0, depth, 1.0);
        #if UNITY_UV_STARTS_AT_TOP
        clipPos.y = -clipPos.y;
        #endif
        float4 viewPos = mul(_InverseProjectionMatrix, clipPos);
        return viewPos.xyz / viewPos.w;
    }

    float SampleRawDepth(float2 uv)
    {
        float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(
            _CameraDepthTexture,
            sampler_CameraDepthTexture,
            UnityStereoTransformScreenSpaceTex(uv),
            0
        );
        return rawDepth;
    }

    float SampleLinear01Depth(float2 uv)
    {
        float rawDepth = SampleRawDepth(uv);
        float depth = Linear01Depth(rawDepth);
        return depth;
    }

    // ------------------------------------------------------------------------------------------------

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float4 color = float4(1, 1, 1, 1);

        float2 uv = i.texcoord.xy;

        float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

        // float4 cameraDepthNormalColor = SAMPLE_TEXTURE2D(
        //     _CameraDepthNormalsTexture,
        //     sampler_CameraDepthNormalsTexture,
        //     i.texcoord
        // );

        // 1: depth normal から復号する場合。ただしDecodeFloatRGの値がちょっと謎
        // float rawDepth = DecodeFloatRG(cameraDepthNormalColor.zw);
        // float depth = Linear01Depth(1. - rawDepth);

        // 2: depth から参照する場合
        float rawDepth = SampleRawDepth(i.texcoord);
        // float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(
        //     _CameraDepthTexture,
        //     sampler_CameraDepthTexture,
        //     UnityStereoTransformScreenSpaceTex(i.texcoord),
        //     0
        // );

        float depth = SampleLinear01Depth(i.texcoord);

        float3 worldPosition = ReconstructWorldPositionFromDepth(i.texcoord, rawDepth);
        float3 viewPosition = ReconstructViewPositionFromDepth(i.texcoord, rawDepth);

        float3 viewNormal = SampleViewNormal(i.texcoord);
        float3 worldNormal = mul((float3x3)_InverseViewMatrix, viewNormal);

        // color.rgb = lerp(
        //     baseColor.rgb,
        //     lerp(float3(depth, depth, depth), worldNormal, _DepthOrNormal),
        //     _Blend.xxx
        // );

        int sampleCount = 64;

        int occludedCount = 0;

        for (int i = 0; i < sampleCount; i++)
        {
            float4 offset = _SamplingPoints[i];
            offset.w = 0;

            // 1: world -> view -> clip
            // float4 offsetWorldPosition = float4(worldPosition, 1.) + offset * _OcclusionSampleLength;
            // float4 offsetViewPosition = mul(_ViewMatrix, offsetWorldPosition);
            // float4 offsetClipPosition = mul(_ViewProjectionMatrix, offsetWorldPosition);

            // 2: view -> clip
            float4 offsetViewPosition = float4(viewPosition, 1.) + offset * _OcclusionSampleLength;
            float4 offsetClipPosition = mul(_ProjectionMatrix, offsetViewPosition);

            #if UNITY_UV_STARTS_AT_TOP
            offsetClipPosition.y = -offsetClipPosition.y;
            #endif

            // TODO: zを考慮してあるべき
            float2 samplingCoord = (offsetClipPosition.xy / offsetClipPosition.w) * 0.5 + 0.5;
            float samplingRawDepth = SampleRawDepth(samplingCoord);
            float3 samplingViewPosition = ReconstructViewPositionFromDepth(samplingCoord, samplingRawDepth);
            float dist = abs(samplingViewPosition.z - offsetViewPosition.z);
            if (dist < _OcclusionMinDistance || _OcclusionMaxDistance < dist)
            {
                continue;
            }

            // 対象の点のdepth値が現在のdepth値よりも小さかったら（= 対象の点が現在の点よりもカメラに近かったら）
            if (samplingViewPosition.z > offsetViewPosition.z)
            {
                occludedCount++;
            }
        }

        float aoRate = (float)occludedCount / (float)sampleCount;

        color.rgb = lerp(
            float3(1., 1., 1.),
            float3(0., 0., 0.),
            aoRate * _OcclusionStrength
        );

        color.a = 1;
        return color;
    }
    ENDHLSL
    SubShader
    {
        Cull Off ZWrite Off ZTest Always
        Pass
        {
            HLSLPROGRAM
            #pragma vertex VertDefault
            #pragma fragment Frag
            ENDHLSL
        }
    }
}
