using System;
using UnityEditor;
using UnityEngine;

[ExecuteInEditMode]
public class TextureGenerator : MonoBehaviour
{
    public ComputeShader ComputeShader;
    public string KernelName;
    public ComputeShader Slicer;

    protected RenderTexture Texture;
    private const int threadGroupSize = 32;

    public NoiseSettings Settings;

    public System.Action<Texture3D> OnSettingsChanged;
    
    private NoiseSettings prevSettings;

    protected void IsSettingsChanged()
    {
        bool isChanged = !Settings.Equals(prevSettings);
        if(isChanged)
        {
            prevSettings = (NoiseSettings)Settings.Clone();
            OnSettingsChanged?.Invoke(Generate());
        }
    }

    protected void Update()
    {
        IsSettingsChanged();
    }

    public virtual Texture3D Generate()
    {
        CreateRenderTexture();
        int kernel = ComputeShader.FindKernel(KernelName);
        ComputeShader.SetTexture(kernel, "Result", Texture);
        ComputeShader.SetInt("Resolution", Settings.Resolution);

        ComputeShader.SetFloat("Coverage", 1.0f - Settings.Coverage);
        ComputeShader.SetInt("Octaves", Settings.Octaves);
        ComputeShader.SetFloat("Frequency", Settings.Frequency);
        ComputeShader.SetFloat("Lacunarity", Settings.Lacunarity);
        ComputeShader.SetFloat("Amplitude", Settings.Amplitude);
        ComputeShader.SetFloat("Persistence", Settings.Persistence);
        ComputeShader.SetVector("CellIndex", Settings.Index);
        ComputeShader.SetBool("IsDetails", Settings.IsDetails);

        ComputeShader.GetKernelThreadGroupSizes(kernel, out uint xGroupSize, out uint yGroupSize, out uint zGroupSize);
        ComputeShader.Dispatch(kernel, Settings.Resolution / (int)xGroupSize, Settings.Resolution / (int)yGroupSize, Settings.Resolution / (int)zGroupSize);

        return SaveAsset();
    }

    protected void CreateRenderTexture()
    {
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        Texture = new RenderTexture(Settings.Resolution, Settings.Resolution, 0);
        Texture.graphicsFormat = format;
        Texture.volumeDepth = Settings.Resolution;
        Texture.enableRandomWrite = true;
        Texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        Texture.name = name;
        Texture.Create();
        Texture.wrapMode = TextureWrapMode.Repeat;
        Texture.filterMode = FilterMode.Bilinear;
    }

    protected Texture2D ConvertFromRenderTexture(RenderTexture rt)
    {
        Texture2D output = new Texture2D(Settings.Resolution, Settings.Resolution);
        RenderTexture.active = rt;
        output.ReadPixels(new Rect(0, 0, Settings.Resolution, Settings.Resolution), 0, 0);
        output.Apply();
        return output;
    }

    protected Texture3D SaveAsset()
    {
        Texture2D[] slices = new Texture2D[Settings.Resolution];

        int kernel = Slicer.FindKernel("CSMain");
        Slicer.SetInt("resolution", Settings.Resolution);
        Slicer.SetTexture(kernel, "Noise", Texture);

        for (int layer = 0; layer < Settings.Resolution; layer++)
        {
            var slice = new RenderTexture(Settings.Resolution, Settings.Resolution, 0);
            slice.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
            slice.enableRandomWrite = true;
            slice.Create();

            Slicer.SetTexture(kernel, "Result", slice);
            Slicer.SetInt("Layer", layer);
            int numThreadGroups = Mathf.CeilToInt(Settings.Resolution / (float)threadGroupSize);
            Slicer.Dispatch(kernel, numThreadGroups, numThreadGroups, 1);

            slices[layer] = ConvertFromRenderTexture(slice);

        }

        Texture3D output = Tex3DFromTex2DArray(slices, Settings.Resolution);
        //string name = "NoiseVolume";
        //AssetDatabase.CreateAsset(output, "Assets/Shaders/ComputeShaders/" + name + ".asset");
        //AssetDatabase.SaveAssets();
        //AssetDatabase.Refresh();
        return output;
    }

    protected Texture3D Tex3DFromTex2DArray(Texture2D[] slices, int resolution)
    {
        Texture3D tex3D = new Texture3D(resolution, resolution, resolution, TextureFormat.ARGB32, false);
        tex3D.filterMode = FilterMode.Trilinear;
        Color[] outputPixels = tex3D.GetPixels();

        for (int z = 0; z < resolution; z++)
        {
            Color c = slices[z].GetPixel(0, 0);
            Color[] layerPixels = slices[z].GetPixels();
            for (int x = 0; x < resolution; x++)
                for (int y = 0; y < resolution; y++)
                {
                    outputPixels[x + resolution * (y + z * resolution)] = layerPixels[x + y * resolution];
                }
        }

        tex3D.SetPixels(outputPixels);
        tex3D.Apply();

        return tex3D;
    }
}
