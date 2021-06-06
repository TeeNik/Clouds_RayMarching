using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class SupportCamera : MonoBehaviour
{

    public RaymarchingCamera RaymarchingCamera;

    private Camera _camera;
    public Camera Camera
    {
        get
        {
            if (!_camera)
            {
                _camera = GetComponent<Camera>();
            }
            return _camera;
        }
    }

    void Awake()
    {
        Camera.targetTexture = RaymarchingCamera.LabTexture;
    }
}
