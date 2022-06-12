using System;
using System.Collections;
using System.Collections.Generic;
using System.Diagnostics;
using UnityEngine;

public class ComputeShaderSpheres : MonoBehaviour
{
    public ComputeShader Shader;
    public int SphereAmount = 17;
    public float Radius = 20.0f;
    public GameObject SpherePrefab;

    private ComputeBuffer ResultBuffer;
    private int KernelID;
    private uint ThreadGroupSize;
    private Vector3[] Output;
    private Transform[] Spheres;

    void Start()
    {
        KernelID = Shader.FindKernel("Spheres");
        Shader.GetKernelThreadGroupSizes(KernelID, out ThreadGroupSize, out _, out _);
        ResultBuffer = new ComputeBuffer(SphereAmount, sizeof(float) * 3);
        Output = new Vector3[SphereAmount];

        Spheres = new Transform[SphereAmount];
        for(int i = 0; i < SphereAmount; ++i)
        {
            Spheres[i] = Instantiate(SpherePrefab, transform).transform;
        }
    }

    void Update()
    {
        var timer = new Stopwatch();
        timer.Start();

        Shader.SetBuffer(KernelID, "Result", ResultBuffer);
        Shader.SetFloat("Time", Time.time);
        int threadGroup = (int)((SphereAmount + (ThreadGroupSize - 1)) / ThreadGroupSize);
        Shader.Dispatch(KernelID, threadGroup, 1, 1);
        ResultBuffer.GetData(Output);

        for (int i = 0; i < Spheres.Length; ++i)
        {
            Transform sphere = Spheres[i];
            //sphere.localPosition = Output[i];
            sphere.localPosition = GetSphereDir(i);
        }

        timer.Stop();
        print("Time taken: " + timer.ElapsedMilliseconds);
    }

    float rand1dTo1d(float value, float mutator = 0.546f)
    {
        float random = (Mathf.Sin(value + mutator) * 143758.5453f) % 1;
        return random;
    }

    Vector3 rand1dTo3d(float value)
    {
        return new Vector3(
            rand1dTo1d(value, 3.9812f),
            rand1dTo1d(value, 7.1536f),
            rand1dTo1d(value, 5.7241f)
            );
    }

    private Vector3 GetSphereDir(int id)
    {
        Vector3 baseDir = Vector3.Normalize(rand1dTo3d(id) - Vector3.one * 0.5f) * (rand1dTo1d(id) * 0.9f + 0.1f);
        Vector3 orthogonal = Vector3.Normalize(Vector3.Cross(baseDir, rand1dTo3d(id + 7.1393f) - Vector3.one * 0.5f)) * (rand1dTo1d(id + 3.7443f) * 0.9f + 0.1f); ;
        float scaledTime = Time.time * 2 + rand1dTo1d(id) * 845.12547f;
        Vector3 dir = baseDir * Mathf.Sin(scaledTime) + orthogonal * Mathf.Cos(scaledTime);
        return dir * Radius;
    }

    private void OnDestroy()
    {
        ResultBuffer.Dispose();
    }
}
