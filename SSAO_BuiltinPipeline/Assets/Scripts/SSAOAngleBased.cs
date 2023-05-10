using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;

[Serializable]
[PostProcess(typeof(SSAOAngleBasedRenderer), PostProcessEvent.AfterStack, "Custom/SSAOAngleBased")]
public sealed class SSAOAngleBased : PostProcessEffectSettings
{
    [FormerlySerializedAs("blend")] [Range(0f, 1f), Tooltip("SSAO effect intensity.")]
    public FloatParameter Blend = new FloatParameter { value = 0.5f };

    [FormerlySerializedAs("occlusion sample length")] [Range(0.01f, 5f), Tooltip("occ sample length")]
    public FloatParameter OcclusionSampleLength = new FloatParameter { value = 1f };

    [FormerlySerializedAs("occlusion min distance")] [Range(0f, 5f), Tooltip("occlusion min distance")]
    public FloatParameter OcclusionMinDistance = new FloatParameter { value = 0f };

    [FormerlySerializedAs("occlusion max distance")] [Range(0f, 5f), Tooltip("occlusion max distance")]
    public FloatParameter OcclusionMaxDistance = new FloatParameter { value = 5f };

    [FormerlySerializedAs("occlusion bias")] [Range(0f, 1f), Tooltip("occlusion bias")]
    public FloatParameter OcclusionBias = new FloatParameter { value = 0.001f };

    [FormerlySerializedAs("occlusion strength")] [Range(0f, 4f), Tooltip("occlusion strength")]
    public FloatParameter OcclusionStrength = new FloatParameter { value = 1f };
    
    [FormerlySerializedAs("occlusion power")] [Range(0.1f, 4f), Tooltip("occlusion power")]
    public FloatParameter OcclusionPower = new FloatParameter { value = 1f };

    [FormerlySerializedAs("occlusion color")] [Tooltip("occlusion color")]
    public ColorParameter OcclusionColor = new ColorParameter { value = Color.black };
}

public sealed class SSAOAngleBasedRenderer : PostProcessEffectRenderer<SSAOAngleBased>
{
    private bool _isCreatedSamplingPoints = false;

    /// <summary>
    /// 
    /// </summary>
    /// <param name="context"></param>
    public override void Render(PostProcessRenderContext context)
    {
        var viewMatrix = Camera.main.worldToCameraMatrix;
        var inverseViewMatrix = Camera.main.cameraToWorldMatrix;
        var projectionMatrix = GL.GetGPUProjectionMatrix(Camera.main.projectionMatrix, true);
        var viewProjectionMatrix = projectionMatrix * viewMatrix;
        var inverseViewProjectionMatrix = viewProjectionMatrix.inverse;
        var inverseProjectionMatrix = projectionMatrix.inverse;

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/SSAOAngleBased"));
        sheet.properties.SetFloat("_Blend", settings.Blend);
        if (!_isCreatedSamplingPoints)
        {
            var rotList = new List<float>();
            var lenList = new List<float>();
            var sampleCount = 6;
            for (int i = 0; i < sampleCount; i++)
            {
                // 任意の角度. できるだけ均等にバラけていた方がよい
                var pieceRad = (Mathf.PI * 2) / sampleCount;
                var rad = UnityEngine.Random.Range(
                    pieceRad * i,
                    pieceRad * (i + 1)
                );
                rotList.Add(rad);
                // 任意の長さの範囲. できるだけ均等にバラけていた方がよい
                var baseLen = 0.1f;
                var pieceLen = (1f - baseLen) / sampleCount;
                var len = UnityEngine.Random.Range(
                    baseLen + pieceLen * i,
                    baseLen + pieceLen * (i + 1)
                );
                Debug.Log($"piece rad: {pieceRad}, rad: {rad}, base len: {baseLen}, piece len: {pieceLen}, len: {len}");
                lenList.Add(len);
            }

            sheet.properties.SetFloatArray("_SamplingRotations", rotList.ToArray());
            sheet.properties.SetFloatArray("_SamplingDistances", lenList.ToArray());
            _isCreatedSamplingPoints = true;
        }

        sheet.properties.SetMatrix("_ViewMatrix", viewMatrix);
        sheet.properties.SetMatrix("_ViewProjectionMatrix", viewProjectionMatrix);
        sheet.properties.SetMatrix("_ProjectionMatrix", projectionMatrix);
        sheet.properties.SetMatrix("_InverseProjectionMatrix", inverseProjectionMatrix);
        sheet.properties.SetMatrix("_InverseViewProjectionMatrix", inverseViewProjectionMatrix);
        sheet.properties.SetMatrix("_InverseViewMatrix", inverseViewMatrix);

        sheet.properties.SetFloat("_OcclusionSampleLength", settings.OcclusionSampleLength);
        sheet.properties.SetFloat("_OcclusionMinDistance", settings.OcclusionMinDistance);
        sheet.properties.SetFloat("_OcclusionMaxDistance", settings.OcclusionMaxDistance);
        sheet.properties.SetFloat("_OcclusionBias", settings.OcclusionBias);
        sheet.properties.SetFloat("_OcclusionStrength", settings.OcclusionStrength);
        sheet.properties.SetFloat("_OcclusionPower", settings.OcclusionPower);

        sheet.properties.SetColor("_OcclusionColor", settings.OcclusionColor);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }
}
