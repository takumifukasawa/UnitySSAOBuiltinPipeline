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
    float4x4 _ViewProjectionMatrix;
    float4 _ProjectionMatrix;
    float4x4 _InverseViewMatrix;
    float4x4 _InverseViewProjectionMatrix;
    float4x4 _InverseProjectionMatrix;
    float4 _SamplingPoints[64];

    // --------------------------------------------------------------------------
    // start: partial include from UnityCG.cginc
    // --------------------------------------------------------------------------

    inline float DecodeFloatRG(float2 enc)
    {
        float2 kDecodeDot = float2(1.0, 1 / 255.0);
        return dot(enc, kDecodeDot);
    }

    // inline void DecodeDepthNormal( float4 enc, out float depth, out float3 normal )
    // {
    //     depth = DecodeFloatRG (enc.zw);
    //     normal = DecodeViewNormalStereo (enc);
    // }

    // --------------------------------------------------------------------------
    // end: partial include from UnityCG.cginc
    // --------------------------------------------------------------------------

    // float SampleDepth(float2 uv, float3 offset)
    // {
    //     float4 cameraDepthNormalColor = SAMPLE_TEXTURE2D(
    //         _CameraDepthNormalsTexture,
    //         sampler_CameraDepthNormalsTexture,
    //         uv
    //     );
    //     float depth = DecodeFloatRG(cameraDepthNormalColor.zw);
    //     return depth;
    // }

    // ref: https://github.com/Unity-Technologies/PostProcessing/blob/v2/PostProcessing/Shaders/Builtins/ScalableAO.hlsl
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
    float SampleDepth(float2 uv)
    {
        float d = Linear01Depth(SAMPLE_DEPTH_TEXTURE_LOD(_CameraDepthTexture, sampler_CameraDepthTexture,
                                                         UnityStereoTransformScreenSpaceTex(uv), 0));
        return d * _ProjectionParams.z + CheckBounds(uv, d);
    }

    float3 SampleViewNormal(float2 uv)
    {
        float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uv);
        return DecodeViewNormalStereo(cdn) * float3(1., 1., 1.);
    }

    float3 ReconstructWorldPositionFromDepth(float2 screenUV, float depth)
    {
        float4 clipPos = float4(screenUV * 2.0 - 1.0, depth, 1.0);
        #if UNITY_UV_STARTS_AT_TOP
        clipPos.y = -clipPos.y;
        #endif
        float4 worldPos = mul(_InverseViewProjectionMatrix, clipPos);
        return worldPos.xyz / worldPos.w;
    }

    float3 ReconstructViewPositionFromDepth(float2 screenUV, float depth)
    {
        float4 clipPos = float4(screenUV * 2.0 - 1.0, depth, 1.0);
        #if UNITY_UV_STARTS_AT_TOP
        clipPos.y = -clipPos.y;
        #endif
        float4 worldPos = mul(_InverseProjectionMatrix, clipPos);
        return worldPos.xyz / worldPos.w;
    }

    float4 ComputeClipSpacePosition(float2 positionNDC, float deviceDepth)
    {
        float4 positionCS = float4(positionNDC * 2.0 - 1.0, deviceDepth, 1.0);

        #if UNITY_UV_STARTS_AT_TOP
        // Our world space, view space, screen space and NDC space are Y-up.
        // Our clip space is flipped upside-down due to poor legacy Unity design.
        // The flip is baked into the projection matrix, so we only have to flip
        // manually when going from CS to NDC and back.
        positionCS.y = -positionCS.y;
        #endif

        return positionCS;
    }


    float3 ComputeWorldSpacePosition(float2 positionNDC, float deviceDepth, float4x4 invViewProjMatrix)
    {
        float4 positionCS = ComputeClipSpacePosition(positionNDC, deviceDepth);
        float4 hpositionWS = mul(invViewProjMatrix, positionCS);
        return hpositionWS.xyz / hpositionWS.w;
    }


    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float4 color = float4(1, 1, 1, 1);

        float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
        float4 cameraDepthNormalColor = SAMPLE_TEXTURE2D(
            _CameraDepthNormalsTexture,
            sampler_CameraDepthNormalsTexture,
            i.texcoord
        );

        // 1: depth normal から復号する場合。ただしDecodeFloatRGの値がちょっと謎
        // float rawDepth = DecodeFloatRG(cameraDepthNormalColor.zw);
        // float depth = Linear01Depth(1. - rawDepth);

        // 2: depth から参照する場合
        float rawDepth = SAMPLE_DEPTH_TEXTURE_LOD(
            _CameraDepthTexture,
            sampler_CameraDepthTexture,
            UnityStereoTransformScreenSpaceTex(i.texcoord),
            0
        );
        float depth = Linear01Depth(rawDepth);
        float3 worldPosition = ReconstructWorldPositionFromDepth(i.texcoord, rawDepth);
        float3 viewPosition = ReconstructViewPositionFromDepth(i.texcoord, rawDepth);
        // float3 worldPosition = ComputeWorldSpacePosition(i.texcoord, rawDepth, _InverseViewProjectionMatrix);

        // float3 samplingWorldPosition = worldPosition + _SamplingPoints[0].xyz;
        // float4 samplingClipPosition = mul(_ViewProjectionMatrix, float4(samplingWorldPosition, 1.0));

        float3 viewNormal = SampleViewNormal(i.texcoord);
        float3 worldNormal = mul((float3x3)_InverseViewMatrix, viewNormal);

        color.rgb = lerp(
            baseColor.rgb,
            lerp(float3(depth, depth, depth), worldNormal, _DepthOrNormal),
            _Blend.xxx
        );

        float d = SampleDepth(i.texcoord);
        float ld = Linear01Depth(d);
        d = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, i.texcoord);

        float viewDepth = DecodeFloatRG(cameraDepthNormalColor.zw);

        color.rgb = worldPosition;
        color.rgb = viewPosition;
        color.rgb = float3(rawDepth, rawDepth, rawDepth);
        color.rgb = float3(d, d, d);
        color.rgb = float3(viewDepth, viewDepth, viewDepth);
        // color.r = step(.07, color.r);
        // color.g = 0;
        // color.b = 0;

        // color.rgb = lerp(
        //     color.rgb,
        //     float3(1, 1, 1),
        //     step(0.99, depth)
        // );

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
