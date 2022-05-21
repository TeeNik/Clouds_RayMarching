using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering.PostProcessing;
using UnityEngine.UI;

[System.Serializable]
public class LightSourceInfo
{
    public Transform Transform;
    public Color Color;
}

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class CloudRaymarchingCamera : SceneViewFilter
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
    [SerializeField] private TextureGenerator detailsTextureGenerator = null;

    public Vector3 Offset;
    public Shader Shader;
    public Color CloudColor;
    public float SphereRadius = 0.1f;
    public List<LightSourceInfo> LightSources = new List<LightSourceInfo>();
    public float DetailsWeight = 0.0f;

    private Material raymarchMat;

    public Shader BlurShader;
    private Material blurMaterial;


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

    private readonly int cloudColorId = Shader.PropertyToID("_CloudColor");

    private void Start()
    {
        raymarchMat = new Material(Shader);
        blurMaterial = new Material(BlurShader);

        if (textureGenerator)
        {
            Texture3D noiseTexture = textureGenerator.Generate();
            raymarchMat.SetTexture("_Volume", noiseTexture);
            textureGenerator.OnSettingsChanged += (tex) =>
            {
                raymarchMat.SetTexture("_Volume", tex);
            };
        }

        if(detailsTextureGenerator)
        {
            Texture3D noiseTexture = detailsTextureGenerator.Generate();
            raymarchMat.SetTexture("_DetailsVolume", noiseTexture);
            detailsTextureGenerator.OnSettingsChanged += (tex) =>
            {
                raymarchMat.SetTexture("_DetailsVolume", tex);
            };
        }
    }

    private void Update()
    {
        Vector3 eulers = new Vector3(0.0f, sunSpeedSlider.value * Time.deltaTime, 0.0f);
        sun.Rotate(eulers, Space.World);
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (!raymarchMat)
        {
            Graphics.Blit(source, destination);
            return;
        }

        raymarchMat.SetFloat("_MaxDistance", MaxDistance);

        raymarchMat.SetVector(posId, sphere.position);
        raymarchMat.SetFloat(radiusId, SphereRadius);
        raymarchMat.SetVector(cubeMinBound, cube.position - cube.localScale * 0.5f);
        raymarchMat.SetVector(cubeMaxBound, cube.position + cube.localScale * 0.5f);
        raymarchMat.SetFloat(coverageId, coverageSlider.value);
        raymarchMat.SetFloat(densityId, densitySlider.value);
        raymarchMat.SetFloat(absortionId, absortionSlider.value);
        raymarchMat.SetInt(jitterId, (int)jitterSlider.value);
        raymarchMat.SetFloat(frameCountId, Time.frameCount);
        raymarchMat.SetFloat("_DetailsWeight", DetailsWeight);
        ppLayer.antialiasingMode = taaToggle.isOn ? PostProcessLayer.Antialiasing.TemporalAntialiasing : PostProcessLayer.Antialiasing.None;

        raymarchMat.SetVector(cloudColorId, CloudColor.linear);

        raymarchMat.SetVector("_Offset", Offset);
        
        SetupLightInfo();

        raymarchMat.SetTexture("_Background", source);

        Graphics.Blit(source, destination, raymarchMat);

        RenderTexture rt = RenderTexture.GetTemporary(source.width, source.height);
        Graphics.Blit(source, rt, raymarchMat);
        Graphics.Blit(rt, destination, blurMaterial);
        RenderTexture.ReleaseTemporary(rt);
    }

    private void SetupLightInfo()
    {
        if(LightSources.Count > 0)
        {
            Vector4[] lightTransform = new Vector4[LightSources.Count];
            Color[] lightColor = new Color[LightSources.Count];
            for (int i = 0; i < LightSources.Count; i++)
            {
                var tr = LightSources[i].Transform;
                var pos = tr.position;
                lightTransform[i] = new Vector4(pos.x, pos.y, pos.z, tr.localScale.x);
                lightColor[i] = LightSources[i].Color;
            }
            raymarchMat.SetVectorArray("_lightTransforms", lightTransform);
            raymarchMat.SetColorArray("_lightColors", lightColor);
        }
    }
}