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
    float4x4 _InverseViewMatrix;
    float4x4 _InverseViewProjectionMatrix;
    float4x4 _ViewProjectionMatrix;
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

    float SampleDepth(float2 uv, float3 offset)
    {
        float4 cameraDepthNormalColor = SAMPLE_TEXTURE2D(
            _CameraDepthNormalsTexture,
            sampler_CameraDepthNormalsTexture,
            uv
        );
        float depth = DecodeFloatRG(cameraDepthNormalColor.zw);
        return depth;
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

        float3 samplingWorldPosition = worldPosition + _SamplingPoints[0].xyz;
        float4 samplingClipPosition = mul(_ViewProjectionMatrix, float4(samplingWorldPosition, 1.0));

        // float4 cdn = SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, i.texcoord);
        // float3 viewNormal = float3(0., 0., 0.);
        // viewNormal = DecodeViewNormalStereo(cdn) * float3(1., 1., -1.);
        // // viewNormal = DecodeViewNormalStereo(cameraDepthNormalColor);
        float3 viewNormal = SampleViewNormal(i.texcoord);
        float3 worldNormal = mul((float3x3)_InverseViewMatrix, viewNormal);

        color.rgb = lerp(
            baseColor.rgb,
            lerp(float3(depth, depth, depth), worldNormal, _DepthOrNormal),
            _Blend.xxx
        );

        // color.rgb = viewNormal;
        color.rgb = worldNormal;
        // color.rgb = worldPosition;
        // color.r = step(.1, worldPosition.x);
        // color.g = 0.;
        // color.b = 0.;
        // color.rgb = float3(depth, depth, depth);
        // color.rgb = float3(rawDepth, rawDepth, rawDepth);

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
