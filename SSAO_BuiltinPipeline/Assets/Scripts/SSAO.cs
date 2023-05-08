using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;
using Random = System.Random;

[Serializable]
[PostProcess(typeof(SSAORenderer), PostProcessEvent.AfterStack, "Custom/SSAO")]
public sealed class SSAO : PostProcessEffectSettings
{
    [FormerlySerializedAs("blend")] [Range(0f, 1f), Tooltip("SSAO effect intensity.")]
    public FloatParameter Blend = new FloatParameter { value = 0.5f };

    [FormerlySerializedAs("occlusion sample length")] [Range(0.01f, 5f), Tooltip("occ sample length")]
    public FloatParameter OcclusionSampleLength = new FloatParameter { value = 1f };

    [FormerlySerializedAs("occlusion min distance")] [Range(0f, 5f), Tooltip("occlusion min distance")]
    public FloatParameter OcclusionMinDistance = new FloatParameter { value = 0f };

    [FormerlySerializedAs("occlusion max distance")] [Range(0f, 5f), Tooltip("occlusion max distance")]
    public FloatParameter OcclusionMaxDistance = new FloatParameter { value = 5f };
    
    [FormerlySerializedAs("occlusion strength")] [Range(0f, 1f), Tooltip("occlusion strength")]
    public FloatParameter OcclusionStrength = new FloatParameter { value = 1f };
}

public sealed class SSAORenderer : PostProcessEffectRenderer<SSAO>
{
    private const int SAMPLING_POINTS_NUM = 64;

    private Vector4[] _samplingPoints = new Vector4[SAMPLING_POINTS_NUM];

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

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/SSAO"));
        sheet.properties.SetFloat("_Blend", settings.Blend);
        if (!_isCreatedSamplingPoints)
        {
            _isCreatedSamplingPoints = true;
            _samplingPoints = GetRandomPointsInUnitSphere();
            sheet.properties.SetVectorArray("_SamplingPoints", _samplingPoints);
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
        sheet.properties.SetFloat("_OcclusionStrength", settings.OcclusionStrength);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }

    /// <summary>
    /// 
    /// </summary>
    /// <returns></returns>
    static Vector4[] GetRandomPointsInUnitSphere()
    {
        var points = new List<Vector4>();
        while (points.Count < SAMPLING_POINTS_NUM)
        {
            var p = UnityEngine.Random.insideUnitSphere;
            points.Add(new Vector4(p.x, p.y, p.z, 0));
        }

        return points.ToArray();
    }
}
