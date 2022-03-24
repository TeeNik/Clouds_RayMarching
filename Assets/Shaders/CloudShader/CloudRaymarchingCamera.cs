using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UI;

public class CloudRaymarchingCamera : MonoBehaviour
{
    [Header("UI")]
    [SerializeField] private Slider sunSpeedSlider = null;
    [SerializeField] private Slider coverageSlider = null;
    [SerializeField] private Slider densitySlider = null;
    [SerializeField] private Slider absortionSlider = null;
    [SerializeField] private Slider jitterSlider = null;
    [SerializeField] private Toggle taaToggle = null;

    [Header("Components")]
    [SerializeField] private Transform sun = null;
    [SerializeField] private PostProcessLayer ppLayer = null;
    [SerializeField] private Transform sphere = null;
    [SerializeField] private Transform cube = null;
    [SerializeField] private TextureGenerator textureGenerator = null;

    public Vector3 Index;
    public Shader Shader;
    private Material raymarchMat;

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
    public float MaxDistance;

    private readonly int posId = Shader.PropertyToID("_SpherePos");
    private readonly int radiusId = Shader.PropertyToID("_SphereRadius");
    private readonly int cubeMinBound = Shader.PropertyToID("_CubeMinBound");
    private readonly int cubeMaxBound = Shader.PropertyToID("_CubeMaxBound");
    private readonly int coverageId = Shader.PropertyToID("_Coverage");
    private readonly int densityId = Shader.PropertyToID("_Density");
    private readonly int absortionId = Shader.PropertyToID("_Absortion");
    private readonly int jitterId = Shader.PropertyToID("_JitterEnabled");
    private readonly int frameCountId = Shader.PropertyToID("_FrameCount");

    private void Start()
    {
        raymarchMat = new Material(Shader);

        if (textureGenerator)
        {
            Texture3D noiseTexture = textureGenerator.Generate();
            raymarchMat.SetTexture("_Volume", noiseTexture);
        }
    }

    private void Update()
    {
        Vector3 eulers = new Vector3(0.0f, sunSpeedSlider.value * Time.deltaTime, 0.0f);
        sun.Rotate(eulers, Space.World);

        if (Input.GetKeyDown(KeyCode.G))
        {
            if (textureGenerator)
            {
                Texture3D noiseTexture = textureGenerator.Generate();
                raymarchMat.SetTexture("_Volume", noiseTexture);
            }
        }
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(source, destination, raymarchMat);

        raymarchMat.SetMatrix("_CamFrustum", CamFrustum(Camera));
        raymarchMat.SetMatrix("_CamToWorld", Camera.cameraToWorldMatrix);
        raymarchMat.SetFloat("_MaxDistance", MaxDistance);

        raymarchMat.SetVector(posId, sphere.position);
        raymarchMat.SetFloat(radiusId, sphere.localScale.x * 0.5f);
        raymarchMat.SetVector(cubeMinBound, cube.position - cube.localScale * 0.5f);
        raymarchMat.SetVector(cubeMaxBound, cube.position + cube.localScale * 0.5f);
        raymarchMat.SetFloat(coverageId, coverageSlider.value);
        raymarchMat.SetFloat(densityId, densitySlider.value);
        raymarchMat.SetFloat(absortionId, absortionSlider.value);
        raymarchMat.SetInt(jitterId, (int)jitterSlider.value);
        raymarchMat.SetFloat(frameCountId, Time.frameCount);
        ppLayer.antialiasingMode = taaToggle.isOn ? PostProcessLayer.Antialiasing.TemporalAntialiasing : PostProcessLayer.Antialiasing.None;

        raymarchMat.SetVector("_Index", Index);

        Matrix4x4 rotMatrix = Matrix4x4.TRS(
            Vector3.one,
            Quaternion.Euler(new Vector3(0, (Time.time * 100) % 360, (Time.time * 100) % 360)),
            Vector3.one
            );

        raymarchMat.SetMatrix("_RotationMat", rotMatrix.inverse);


        RenderTexture.active = destination;
        raymarchMat.SetTexture("_Background", source);
        GL.PushMatrix();
        GL.LoadOrtho();
        raymarchMat.SetPass(0);
        GL.Begin(GL.QUADS);

        //bottom left
        GL.MultiTexCoord2(0, 0.0f, 0.0f);
        GL.Vertex3(0.0f, 0.0f, 3.0f);
        //bottom right
        GL.MultiTexCoord2(0, 1.0f, 0.0f);
        GL.Vertex3(1.0f, 0.0f, 2.0f);
        //top right
        GL.MultiTexCoord2(0, 1.0f, 1.0f);
        GL.Vertex3(1.0f, 1.0f, 1.0f);
        //top left
        GL.MultiTexCoord2(0, 0.0f, 1.0f);
        GL.Vertex3(0.0f, 1.0f, 0.0f);

        GL.End();
        GL.PopMatrix();
    }

    Matrix4x4 CamFrustum(Camera cam)
    {
        Matrix4x4 frustum = Matrix4x4.identity;
        float fov = Mathf.Tan(cam.fieldOfView * 0.5f * Mathf.Deg2Rad);

        Vector3 goUp = Vector3.up * fov;
        Vector3 goRight = Vector3.right * fov * cam.aspect;

        Vector3 topLeft = -Vector3.forward - goRight + goUp;
        Vector3 topRight = -Vector3.forward + goRight + goUp;
        Vector3 bottomLeft = -Vector3.forward - goRight - goUp;
        Vector3 bottomRight = -Vector3.forward + goRight - goUp;

        frustum.SetRow(0, topLeft);
        frustum.SetRow(1, topRight);
        frustum.SetRow(2, bottomRight);
        frustum.SetRow(3, bottomLeft);

        return frustum;
    }
}