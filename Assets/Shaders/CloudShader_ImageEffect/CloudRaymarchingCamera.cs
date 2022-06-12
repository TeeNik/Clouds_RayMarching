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
    public float Radius;
}

[RequireComponent(typeof(Camera))]
[ExecuteInEditMode, ImageEffectAllowedInSceneView]
public class CloudRaymarchingCamera : SceneViewFilter
{
    [Header("Settings")]
    [Range(0.0f, 50.0f)] public float SunSpeed = 25.0f;
    [Range(0.0f, 1.0f)] public float Coverage = 0.25f;
    [Range(0.0f, 2.0f)] public float Density = 0.5f;
    [Range(0.0f, 20.0f)] public float Absortion = 5.0f;
    public bool Jitter = true;
    [Range(0.0f, 1.0f)] public float CloudHeight = 0.5f;
    public Color CloudsColor;
    public Vector3 CloudsVelocity;

    [Header("Components")]
    [SerializeField] private Transform sun = null;
    [SerializeField] private Transform sphere = null;
    [SerializeField] private Transform cube = null;
    [SerializeField] private TextureGenerator textureGenerator = null;
    [SerializeField] private TextureGenerator detailsTextureGenerator = null;
    [SerializeField] private Shader shader = null;

    public float SphereRadius = 0.1f;
    public List<LightSourceInfo> LightSources = new List<LightSourceInfo>();
    public float DetailsWeight = 0.0f;

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

    private readonly int mainTexId = Shader.PropertyToID("_MainTex");
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
    private readonly int cloudVelocityId = Shader.PropertyToID("_CloudVelocity");
    private readonly int cloudHeightId = Shader.PropertyToID("_CloudHeight");

    private void Start()
    {
        raymarchMat = new Material(shader);

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
        Vector3 eulers = new Vector3(0.0f, SunSpeed * Time.deltaTime, 0.0f);
        sun.Rotate(eulers, Space.World);
    }
    private void OnPostRender()
    {
        if (raymarchMat != null)
        {
            raymarchMat.SetTexture(mainTexId, Camera.activeTexture);
            raymarchMat.SetVector(posId, sphere.position);
            raymarchMat.SetFloat(radiusId, SphereRadius);
            raymarchMat.SetVector(cubeMinBound, cube.position - cube.localScale * 0.5f);
            raymarchMat.SetVector(cubeMaxBound, cube.position + cube.localScale * 0.5f);
            raymarchMat.SetFloat(coverageId, Coverage);
            raymarchMat.SetFloat(densityId, Density);
            raymarchMat.SetFloat(absortionId, Absortion);
            raymarchMat.SetInt(jitterId, Jitter ? 1 : 0);
            raymarchMat.SetFloat(frameCountId, Time.frameCount);
            raymarchMat.SetFloat("_DetailsWeight", DetailsWeight);
            raymarchMat.SetVector(cloudVelocityId, CloudsVelocity);
            raymarchMat.SetVector(cloudColorId, CloudsColor.linear);
            raymarchMat.SetFloat(cloudHeightId, CloudHeight);
            SetupLightInfo();
            Graphics.Blit(Camera.activeTexture, Camera.activeTexture, raymarchMat);
        }
    }
    
    private void SetupLightInfo()
    {
        if(LightSources.Count > 0)
        {
            Vector4[] lightTransform = new Vector4[LightSources.Count];
            Color[] lightColor = new Color[LightSources.Count];
            for (int i = 0; i < LightSources.Count; i++)
            {
                var pos = LightSources[i].Transform.position;
                lightTransform[i] = new Vector4(pos.x, pos.y, pos.z, LightSources[i].Radius);
                lightColor[i] = LightSources[i].Color;
            }
            raymarchMat.SetVectorArray("_lightTransforms", lightTransform);
            raymarchMat.SetColorArray("_lightColors", lightColor);
        }
    }
}