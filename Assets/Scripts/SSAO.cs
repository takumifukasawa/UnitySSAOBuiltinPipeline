using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.Serialization;

[Serializable]
[PostProcess(typeof(SSAORenderer), PostProcessEvent.AfterStack, "Custom/SSAO")]
public sealed class SSAO : PostProcessEffectSettings
{
    [FormerlySerializedAs("blend")] [Range(0f, 1f), Tooltip("SSAO effect intensity.")]
    public FloatParameter Blend = new FloatParameter { value = 0.5f };

    [FormerlySerializedAs("depthOrNormal")] [Range(0f, 1f), Tooltip("lerp, 0: depth ~ 1: normal")]
    public FloatParameter DepthOrNormal = new FloatParameter { value = 0.5f };
}

public sealed class SSAORenderer : PostProcessEffectRenderer<SSAO>
{
    private const int SAMPLING_POINTS_NUM = 64;

    private Vector4[] _samplingPoints = new Vector4[SAMPLING_POINTS_NUM];

    private bool _isCreatedSamplingPoints = false;

    public override void Render(PostProcessRenderContext context)
    {
        var viewMatrix = Camera.main.cameraToWorldMatrix;
        var projectionMatrix = Camera.main.projectionMatrix;
        var viewProjectionMatrix = projectionMatrix * viewMatrix;
        var inverseViewProjectionMatrix = viewProjectionMatrix.inverse;

        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/SSAO"));
        sheet.properties.SetFloat("_Blend", settings.Blend);
        sheet.properties.SetFloat("_DepthOrNormal", settings.DepthOrNormal);
        sheet.properties.SetMatrix("_InverseViewMatrix", viewMatrix);
        if (!_isCreatedSamplingPoints)
        {
            _isCreatedSamplingPoints = true;
            _samplingPoints = GetRandomPointsInUnitSphere();
            sheet.properties.SetVectorArray("_SamplingPoints", _samplingPoints);
        }

        sheet.properties.SetMatrix("_ProjectionMatrix", projectionMatrix);
        sheet.properties.SetMatrix("_InverseViewProjectionMatrix", inverseViewProjectionMatrix);
        sheet.properties.SetMatrix("_ViewProjectionMatrix", viewProjectionMatrix);

        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }

    /// <summary>
    /// 
    /// </summary>
    /// <returns></returns>
    static Vector4[] GetRandomPointsInUnitSphere()
    {
        var points = new Vector4[SAMPLING_POINTS_NUM];
        var rand = new System.Random();
        int i = 0;
        while (points.Length < SAMPLING_POINTS_NUM)
        {
            // while (points.Count < 64) {
            var x = (float)rand.NextDouble() * 2 - 1;
            var y = (float)rand.NextDouble() * 2 - 1;
            var z = (float)rand.NextDouble() * 2 - 1;
            var p = new Vector4(x, y, z, 1);
            if (p.magnitude <= 1)
            {
                points[i] = p;
            }
        }

        return points;
    }

    public override void Init()
    {
        base.Init();
        // _samplingPoints = GetRandomPointsInUnitSphere().ToArray();
    }

    /// <summary>
    /// 
    /// </summary>
    /// <returns></returns>
    // List<Vector3> GetRandomPointsInUnitSphere() {
    //     var points = new List<Vector3>();
    //     var rand = new System.Random();
    //     while (points.Count < 64) {
    //         var x = (float)rand.NextDouble() * 2 - 1;
    //         var y = (float)rand.NextDouble() * 2 - 1;
    //         var z = (float)rand.NextDouble() * 2 - 1;
    //         var p = new Vector3(x, y, z);
    //         if (p.magnitude <= 1) {
    //             points.Add(p);
    //         }
    //     }
    //     return points;
    // }
}
