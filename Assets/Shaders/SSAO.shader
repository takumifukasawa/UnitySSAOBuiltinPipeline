Shader "Hidden/Custom/SSAO"
{
    HLSLINCLUDE
    // StdLib.hlsl holds pre-configured vertex shaders (VertDefault), varying structs (VaryingsDefault), and most of the data you need to write common effects.
    #include "Packages/com.unity.postprocessing/PostProcessing/Shaders/StdLib.hlsl"
    TEXTURE2D_SAMPLER2D(_MainTex, sampler_MainTex);
    TEXTURE2D_SAMPLER2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture);
    // Lerp the pixel color with the luminance using the _Blend uniform.
    float _Blend;
    float _DepthOrNormal;
    float4x4 _ViewToWorld;

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

    float4 Frag(VaryingsDefault i) : SV_Target
    {
        float4 color = float4(1, 1, 1, 1);

        float4 baseColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.texcoord);
        float4 cameraDepthNormalColor = SAMPLE_TEXTURE2D(
            _CameraDepthNormalsTexture,
            sampler_CameraDepthNormalsTexture,
            i.texcoord
        );
        float depth = DecodeFloatRG(cameraDepthNormalColor.zw);
        float3 normal = DecodeViewNormalStereo(cameraDepthNormalColor);
        normal = mul((float3x3)_ViewToWorld, normal);

        color.rgb = lerp(
            baseColor.rgb,
            lerp(float3(depth, depth, depth), normal, _DepthOrNormal),
            _Blend.xxx
        );

        // color.rgb = float3(depth, depth, depth);

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
