using System;
using System.Collections.Generic;
using System.Linq;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;
using Random = System.Random;

[Serializable]
[PostProcess(typeof(SSAOHemisphereRenderer), PostProcessEvent.AfterStack, "Custom/SSAOHemisphere")]
public sealed class SSAOHemisphere : PostProcessEffectSettings
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

    [FormerlySerializedAs("occlusion strength")] [Range(0f, 1f), Tooltip("occlusion strength")]
    public FloatParameter OcclusionStrength = new FloatParameter { value = 1f };

    [FormerlySerializedAs("occlusion color")] [Tooltip("occlusion color")]
    public ColorParameter OcclusionColor = new ColorParameter { value = Color.black };
}

public sealed class SSAOHemisphereRenderer : PostProcessEffectRenderer<SSAOHemisphere>
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

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/SSAOHemisphere"));
        sheet.properties.SetFloat("_Blend", settings.Blend);
        if (!_isCreatedSamplingPoints)
        {
            _isCreatedSamplingPoints = true;
            _samplingPoints = GetRandomPointsInUnitHemisphere();
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
        sheet.properties.SetFloat("_OcclusionBias", settings.OcclusionBias);
        sheet.properties.SetFloat("_OcclusionStrength", settings.OcclusionStrength);

        sheet.properties.SetColor("_OcclusionColor", settings.OcclusionColor);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }

    /// <summary>
    /// 
    /// </summary>
    /// <returns></returns>
    static Vector4[] GetRandomPointsInUnitHemisphere()
    {
        var points = new List<Vector4>();
        while (points.Count < SAMPLING_POINTS_NUM)
        {
            var r1 = UnityEngine.Random.Range(0f, 1f);
            var r2 = UnityEngine.Random.Range(0f, 1f);
            var x = Mathf.Cos(2 * Mathf.PI * r1) * 2 * Mathf.Sqrt(r2 * (1 - r2));
            var y = Mathf.Sin(2 * Mathf.PI * r1) * 2 * Mathf.Sqrt(r2 * (1 - r2));
            var z = 1 - 2 * r2;
            z = Mathf.Abs(z);
            // for debug
            // Debug.Log($"x: {x}, y: {y}, z: {z}");
            points.Add(new Vector4(x, y, z, 0));
        }

        return points.ToArray();
    }
}
