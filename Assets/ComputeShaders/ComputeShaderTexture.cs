using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ComputeShaderTexture : MonoBehaviour
{
    public ComputeShader Shader;
    public int Size;

    private ComputeBuffer ResultBuffer;
    private int KernelID;
    private uint ThreadGroupSize;
    private RenderTexture RenderTexture;

    void Start()
    {
        RenderTexture = new RenderTexture(Size, Size, 24);
        RenderTexture.filterMode = FilterMode.Point;
        RenderTexture.enableRandomWrite = true;
        RenderTexture.Create();

        KernelID = Shader.FindKernel("CSMain");
        Shader.SetTexture(KernelID, "Result", RenderTexture);
        Shader.SetInt("Resolution", Size);
        Shader.GetKernelThreadGroupSizes(KernelID, out uint xGroupSize, out uint yGroupSize, out uint zGroupSize);
        Shader.Dispatch(KernelID, RenderTexture.width / (int)xGroupSize,
            RenderTexture.height / (int)yGroupSize, 1);
    }

    void Update()
    {
        
    }

    private void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        Graphics.Blit(RenderTexture, destination);
    }
}
