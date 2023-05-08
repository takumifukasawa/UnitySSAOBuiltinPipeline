Shader "Hidden/Custom/SSAO"
{
    HLSLINCLUDE
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"

    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    // TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    TEXTURE2D_SAMPLER2D(_CameraDepthTexture, sampler_CameraDepthTexture);

    float _Blend;
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
        const int SAMPLE_COUNT = 64;

        float4 color = float4(1, 1, 1, 1);

        float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);

        float rawDepth = SampleRawDepth(i.texcoord);
        float depth = Linear01Depth(rawDepth);

        float3 worldPosition = ReconstructWorldPositionFromDepth(i.texcoord, rawDepth);
        float3 viewPosition = ReconstructViewPositionFromDepth(i.texcoord, rawDepth);

        float eps = .0001;

        // mask exists depth
        if (depth > 1. - eps)
        {
            return baseColor;
        }

        int occludedCount = 0;
        int divCount = SAMPLE_COUNT;

        for (int j = 0; j < SAMPLE_COUNT; j++)
        {
            float4 offset = _SamplingPoints[j];
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

            // TODO: reverse zを考慮してあるべき？
            float2 samplingCoord = (offsetClipPosition.xy / offsetClipPosition.w) * 0.5 + 0.5;
            float samplingRawDepth = SampleRawDepth(samplingCoord);
            float3 samplingViewPosition = ReconstructViewPositionFromDepth(samplingCoord, samplingRawDepth);

            // NOTE: 遠距離の場合がうまくいってないかも
            // 現在のviewPositionとoffset済みのviewPositionが一定距離離れていたらor近すぎたら無視
            float dist = distance(samplingViewPosition.xyz, viewPosition.xyz);
            if (dist < _OcclusionMinDistance || _OcclusionMaxDistance < dist)
            {
                // divCount = max(1, divCount - 1);
                continue;
            }

            // 対象の点のdepth値が現在のdepth値よりも小さかったら遮蔽とみなす（= 対象の点が現在の点よりもカメラに近かったら）
            if (samplingViewPosition.z > offsetViewPosition.z)
            {
                occludedCount++;
            }
        }

        float aoRate = (float)occludedCount / (float)divCount;

        // NOTE: 本当は環境光のみにAO項を考慮するのがよいが、forward x post process の場合は全体にかけちゃう
        color.rgb = lerp(
            baseColor,
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
