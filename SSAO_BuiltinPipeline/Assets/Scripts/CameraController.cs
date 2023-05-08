using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class CameraController : MonoBehaviour
{
    [SerializeField]
    private Camera _camera;

    void OnEnable()
    {
        UpdateCameraDepthTextureMode();
    }

    private void Awake()
    {
        UpdateCameraDepthTextureMode();
    }

    private void Update()
    {
        UpdateCameraDepthTextureMode();
    }

    void UpdateCameraDepthTextureMode()
    {
        if (_camera != null)
        {
            _camera.depthTextureMode |= DepthTextureMode.DepthNormals;
            // _camera.depthTextureMode = DepthTextureMode.Depth;
        }
    }
}
