Shader "Hidden/Custom/SSAOAngleBased"
{
    HLSLINCLUDE
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

    float _Blend;
    float4x4 _ViewMatrix;
    float4x4 _ViewProjectionMatrix;
    float4x4 _ProjectionMatrix;
    float4x4 _InverseViewMatrix;
    float4x4 _InverseViewProjectionMatrix;
    float4x4 _InverseProjectionMatrix;
    float _SamplingRotations[6];
    float _SamplingDistances[6];
    float _OcclusionSampleLength;
    float _OcclusionMinDistance;
    float _OcclusionMaxDistance;
    float _OcclusionBias;
    float _OcclusionStrength;
    float4 _OcclusionColor;

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

    // // ビュー空間の法線
    // float3 SampleNormal(float2 uv)
    // {
    //     #if defined(SOURCE_GBUFFER)
    // float3 norm = SAMPLE_TEXTURE2D(_CameraGBufferTexture2, sampler_CameraGBufferTexture2, uv).xyz;
    // norm = norm * 2 - any(norm); // gets (0,0,0) when norm == 0
    // norm = mul((float3x3)unity_WorldToCamera, norm);
    //     #if defined(VALIDATE_NORMALS)
    // norm = normalize(norm);
    //     #endif
    // return norm;
    //     #else
    //     float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
    //     return DecodeViewNormalStereo(cdn) * float3(1.0, 1.0, -1.0);
    //     #endif
    // }

    // float SampleDepthNormal(float2 uv, out float3 normal)
    // {
    //     normal = SampleNormal(UnityStereoTransformScreenSpaceTex(uv));
    //     return SampleDepth(uv);
    // }
    
    // ------------------------------------------------------------------------------------------------
    // ref: UnityCG.cginc
    // ------------------------------------------------------------------------------------------------

    float DecodeFloatRG(float2 enc)
    {
        float2 kDecodeDot = float2(1.0, 1 / 255.0);
        return dot(enc, kDecodeDot);
    }

    void DecodeDepthNormal(float4 enc, out float depth, out float3 normal)
    {
        depth = DecodeFloatRG(enc.zw);
        normal = DecodeViewNormalStereo(enc);
    }

    // ------------------------------------------------------------------------------------------------

    float3 ReconstructWorldPositionFromDepth(float2 screenUV, float rawDepth)
    {
        // TODO: depthはgraphicsAPIを考慮している必要があるはず
        float4 clipPos = float4(screenUV * 2.0 - 1.0, rawDepth, 1.0);
        #if UNITY_UV_STARTS_AT_TOP
        clipPos.y = -clipPos.y;
        #endif
        float4 worldPos = mul(_InverseViewProjectionMatrix, clipPos);
        return worldPos.xyz / worldPos.w;
    }

    float3 ReconstructViewPositionFromDepth(float2 screenUV, float rawDepth)
    {
        // TODO: depthはgraphicsAPIを考慮している必要があるはず
        float4 clipPos = float4(screenUV * 2.0 - 1.0, rawDepth, 1.0);
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

    float InverseLinear01Depth(float d)
    {
        // Linear01Depth
        // return 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);

        // d = 1.0 / (_ZBufferParams.x * z + _ZBufferParams.y);
        // d * (_ZBufferParams.x * z + _ZBufferParams.y) = 1.0;
        // _ZBufferParams.x * z * d + _ZBufferParams.y * d = 1.0;
        // _ZBufferParams.x * z * d = 1.0 - _ZBufferParams.y * d;
        // z = (1.0 - _ZBufferParams.y * d) / (_ZBufferParams.x * d);

        return (1 - _ZBufferParams.y * d) / (_ZBufferParams.x * d);
    }

    float3x3 GetTBNMatrix(float3 viewNormal)
    {
        float3 tangent = float3(1, 0, 0);
        float3 bitangent = float3(0, 1, 0);
        float3 normal = viewNormal;
        float3x3 tbn = float3x3(tangent, bitangent, normal);
        return tbn;
    }

    float2x2 GetRotationMatrix(float rad)
    {
        float c = cos(rad);
        float s = sin(rad);
        return float2x2(c, -s, s, c);
    }

    float4 SampleRawDepthByViewPosition(float3 viewPosition, float3 offset)
    {
        // 1: world -> view -> clip
        // float4 offsetWorldPosition = float4(worldPosition, 1.) + offset * _OcclusionSampleLength;
        // float4 offsetViewPosition = mul(_ViewMatrix, offsetWorldPosition);
        // float4 offsetClipPosition = mul(_ViewProjectionMatrix, offsetWorldPosition);

        // 2: view -> clip
        float4 offsetViewPosition = float4(viewPosition, 1.) + float4(offset, 0.);
        float4 offsetClipPosition = mul(_ProjectionMatrix, offsetViewPosition);

        #if UNITY_UV_STARTS_AT_TOP
        offsetClipPosition.y = -offsetClipPosition.y;
        #endif

        // TODO: reverse zを考慮してあるべき？
        float2 samplingCoord = (offsetClipPosition.xy / offsetClipPosition.w) * 0.5 + 0.5;
        float samplingRawDepth = SampleRawDepth(samplingCoord);

        return samplingRawDepth;
    }

    // ------------------------------------------------------------------------------------------------

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float4 color = float4(1, 1, 1, 1);

        float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

        // float rawDepth = SampleRawDepth(i.texcoord);
        // float depth = Linear01Depth(rawDepth);

        float depth = 0;
        float3 worldNormal = float3(0, 0, 0);
        float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.texcoord);
        DecodeDepthNormal(cdn, depth, worldNormal);
        float rawDepth = InverseLinear01Depth(depth);

        float3 worldPosition = ReconstructWorldPositionFromDepth(i.texcoord, rawDepth);
        float3 viewPosition = ReconstructViewPositionFromDepth(i.texcoord, rawDepth);
        float3 surfaceToCameraViewDir = -normalize(viewPosition);


        // test calc normal
        // float3 viewNormal = SampleViewNormal(i.texcoord);
        // float3 worldNormal = mul((float3x3)_InverseViewMatrix, viewNormal);

        float eps = .0001;

        // mask exists depth
        if (depth > 1. - eps)
        {
            return baseColor;
        }

        float occludedAcc = 0.;
        int samplingCount = 6;

        for (int j = 0; j < samplingCount; j++)
        {
            float2x2 rot = GetRotationMatrix(_SamplingRotations[j]);
            float2 offset = _SamplingDistances[j] * _OcclusionSampleLength;
            float3 offsetA = float3(mul(rot, offset), 0.);
            float3 offsetB = float3(-offsetA.xy, 0.);

            float2 rawDepthA = SampleRawDepthByViewPosition(viewPosition, offsetA);
            float2 rawDepthB = SampleRawDepthByViewPosition(viewPosition, offsetB);

            float3 viewPositionA = ReconstructViewPositionFromDepth(i.texcoord, rawDepthA);
            float3 viewPositionB = ReconstructViewPositionFromDepth(i.texcoord, rawDepthB);

            float distA = distance(viewPositionA.xyz, viewPosition.xyz);
            float distB = distance(viewPositionA.xyz, viewPosition.xyz);

            if (distA < _OcclusionMinDistance || _OcclusionMaxDistance < distA)
            {
                continue;
            }
            if (distB < _OcclusionMinDistance || _OcclusionMaxDistance < distB)
            {
                continue;
            }

            // pattern_1
            // float3 dirA = normalize(viewPositionA - viewPosition);
            // float3 dirB = normalize(viewPositionB - viewPosition);
            // float dotA = dot(dirA, surfaceToCameraViewDir);
            // float dotB = dot(dirB, surfaceToCameraViewDir);
            // float angleA = acos(dotA);
            // float angleB = acos(dotB);
            // float ao = 1. - saturate(min((angleA + angleB) / PI, 1.));

            // pattern_2
            // TODO: distanceが分母になる？
            float tanA = (viewPositionA.z - viewPosition.z) / distance(viewPositionA.xy, viewPosition.xy);
            float tanB = (viewPositionB.z - viewPosition.z) / distance(viewPositionB.xy, viewPosition.xy);
            // float tanA = distance(viewPositionA.xy, viewPosition.xy) / (viewPositionA.z - viewPosition.z);
            // float tanB = distance(viewPositionB.xy, viewPosition.xy) / (viewPositionB.z - viewPosition.z);
            float angleA = atan(tanA);
            float angleB = atan(tanB);
            float ao = saturate(min((angleA + angleB) / PI, 1.));

            // pattern_3
            // float3 dirA = normalize(viewPositionA - viewPosition);
            // float3 dirB = normalize(viewPositionB - viewPosition);
            // float dotDirs = dot(dirA, dirB);
            // float ao = saturate(min(1. - dotDirs, 1.));

            occludedAcc += ao;
        }

        float aoRate = occludedAcc / (float)samplingCount;

        // NOTE: 本当は環境光のみにAO項を考慮するのがよいが、forward x post process の場合は全体にかけちゃう
        color.rgb = lerp(
            baseColor,
            _OcclusionColor,
            aoRate * _OcclusionStrength
        );

        color.rgb = lerp(baseColor, color.rgb, _Blend);

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
