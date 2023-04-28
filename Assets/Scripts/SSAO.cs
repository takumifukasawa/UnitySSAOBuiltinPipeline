using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;

[Serializable]
[PostProcess(typeof(SSAORenderer), PostProcessEvent.AfterStack, "Custom/SSAO")]
public sealed class SSAO : PostProcessEffectSettings
{
    [Range(0f, 1f), Tooltip("SSAO effect intensity.")]
    public FloatParameter blend = new FloatParameter { value = 0.5f };

    [Range(0f, 1f), Tooltip("lerp, 0: depth ~ 1: normal")]
    public FloatParameter depthOrNormal = new FloatParameter { value = 0.5f };
}

public sealed class SSAORenderer : PostProcessEffectRenderer<SSAO>
{
    public override void Render(PostProcessRenderContext context)
    {
        var sheet = context.propertySheets.Get(Shader.Find("Hidden/Custom/SSAO"));
        sheet.properties.SetFloat("_Blend", settings.blend);
        sheet.properties.SetFloat("_DepthOrNormal", settings.depthOrNormal);
        var viewToWorld = Camera.main.cameraToWorldMatrix;
        sheet.properties.SetMatrix("_ViewToWorld", viewToWorld);
        context.command.BlitFullscreenTriangle(context.source, context.destination, sheet, 0);
    }

    public override void Init()
    {
        base.Init();
        // Debug.Log("hogehoge");
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
