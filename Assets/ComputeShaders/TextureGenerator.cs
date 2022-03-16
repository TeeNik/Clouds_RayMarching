using System.Collections;
using System.Collections.Generic;
using UnityEditor;
using UnityEngine;

public class TextureGenerator : MonoBehaviour
{
    public int Resolution;
    public ComputeShader ComputeShader;
    public string KernelName;
    public string AssetName;
    public ComputeShader Slicer;

    private RenderTexture Texture;
    private const int threadGroupSize = 32;

    public Material Material;
    public Texture3D TestTexture1;
    public Texture3D TestTexture2;
    bool textFlag = false;

    public float Coverage;
    public int Octaves;
    public float Frequency;
    public float Lacunarity;
    public float Amplitude;
    public float Persistence;

    public Texture3D Generate()
    {
        CreateRenderTexture();
        int kernel = ComputeShader.FindKernel(KernelName);
        ComputeShader.SetTexture(kernel, "Result", Texture);
        ComputeShader.SetInt("Resolution", Resolution);

        ComputeShader.SetFloat("Coverage", 1.0f - Coverage);
        ComputeShader.SetInt("Octaves", Octaves);
        ComputeShader.SetFloat("Frequency", Frequency);
        ComputeShader.SetFloat("Lacunarity", Lacunarity);
        ComputeShader.SetFloat("Amplitude", Amplitude);
        ComputeShader.SetFloat("Persistence", Persistence);

        ComputeShader.GetKernelThreadGroupSizes(kernel, out uint xGroupSize, out uint yGroupSize, out uint zGroupSize);
        ComputeShader.Dispatch(kernel, Resolution / (int)xGroupSize, Resolution / (int)yGroupSize, Resolution / (int)zGroupSize);

        return SaveAsset();
    }

    public void CreateRenderTexture()
    {
        var format = UnityEngine.Experimental.Rendering.GraphicsFormat.R16G16B16A16_UNorm;
        Texture = new RenderTexture(Resolution, Resolution, 0);
        Texture.graphicsFormat = format;
        Texture.volumeDepth = Resolution;
        Texture.enableRandomWrite = true;
        Texture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        Texture.name = name;
        Texture.Create();
        Texture.wrapMode = TextureWrapMode.Repeat;
        Texture.filterMode = FilterMode.Bilinear;
    }

    protected Texture2D ConvertFromRenderTexture(RenderTexture rt)
    {
        Texture2D output = new Texture2D(Resolution, Resolution);
        RenderTexture.active = rt;
        output.ReadPixels(new Rect(0, 0, Resolution, Resolution), 0, 0);
        output.Apply();
        return output;
    }

    public Texture3D SaveAsset()
    {
        string sceneName = UnityEditor.SceneManagement.EditorSceneManager.GetActiveScene().name;
        AssetName = sceneName + "_" + AssetName;
        Texture2D[] slices = new Texture2D[Resolution];

        int kernel = Slicer.FindKernel("CSMain");
        Slicer.SetInt("resolution", Resolution);
        Slicer.SetTexture(kernel, "Noise", Texture);

        for (int layer = 0; layer < Resolution; layer++)
        {
            var slice = new RenderTexture(Resolution, Resolution, 0);
            slice.dimension = UnityEngine.Rendering.TextureDimension.Tex2D;
            slice.enableRandomWrite = true;
            slice.Create();

            Slicer.SetTexture(kernel, "Result", slice);
            Slicer.SetInt("Layer", layer);
            int numThreadGroups = Mathf.CeilToInt(Resolution / (float)threadGroupSize);
            Slicer.Dispatch(kernel, numThreadGroups, numThreadGroups, 1);

            slices[layer] = ConvertFromRenderTexture(slice);

        }

        Texture3D output = Tex3DFromTex2DArray(slices, Resolution);
        //AssetDatabase.CreateAsset(output, "Assets/ComputeShaders/" + name + ".asset");
        //AssetDatabase.SaveAssets();
        //AssetDatabase.Refresh();
        return output;
    }

    Texture3D Tex3DFromTex2DArray(Texture2D[] slices, int resolution)
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
