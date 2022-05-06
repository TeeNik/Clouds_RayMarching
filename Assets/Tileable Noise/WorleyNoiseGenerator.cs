using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[System.Serializable]
public class WorleyNoiseSettings
{
    public int seed;
    public int numDivisionsA = 5;
    public int numDivisionsB = 10;
    public int numDivisionsC = 15;

    public float persistence = .5f;
    public int tile = 1;
    public bool invert = true;
}

public class WorleyNoiseGenerator : TextureGenerator
{

    const int computeThreadGroupSize = 8;
    public const string detailNoiseName = "DetailNoise";
    public const string shapeNoiseName = "ShapeNoise";

    public enum CloudNoiseType { Shape, Detail }
    public enum TextureChannel { R, G, B, A }

    [Header("Editor Settings")]
    public CloudNoiseType activeTextureType;
    public TextureChannel activeChannel;
    public bool autoUpdate;
    public bool logComputeTime;

    public WorleyNoiseSettings shapeSettings;
    public ComputeShader noiseCompute;

    // Internal
    List<ComputeBuffer> buffersToRelease;

    public override Texture3D Generate()
    {
        CreateRenderTexture();
        if (noiseCompute)
        {
            var timer = System.Diagnostics.Stopwatch.StartNew();
            buffersToRelease = new List<ComputeBuffer>();

            // Set values:

            // Set noise gen kernel data:
            noiseCompute.SetTexture(0, "Result", Texture);
            var minMaxBuffer = CreateBuffer(new int[] { int.MaxValue, 0 }, sizeof(int), "minMax", 0);
            UpdateWorley(shapeSettings);
            noiseCompute.SetTexture(0, "Result", Texture);

            // Dispatch noise gen kernel
            int numThreadGroups = Mathf.CeilToInt(Settings.Resolution / (float)computeThreadGroupSize);
            noiseCompute.Dispatch(0, numThreadGroups, numThreadGroups, numThreadGroups);

            // Set normalization kernel data:
            //noiseCompute.SetBuffer(1, "minMax", minMaxBuffer);
            //noiseCompute.SetTexture(1, "Result", Texture);
            //// Dispatch normalization kernel
            //noiseCompute.Dispatch(1, numThreadGroups, numThreadGroups, numThreadGroups);

            if (logComputeTime)
            {
                // Get minmax data just to force main thread to wait until compute shaders are finished.
                // This allows us to measure the execution time.
                var minMax = new int[2];
                minMaxBuffer.GetData(minMax);

                Debug.Log($"Noise Generation: {timer.ElapsedMilliseconds}ms");
            }

            // Release buffers
            foreach (var buffer in buffersToRelease)
            {
                buffer.Release();
            }
        }

        return SaveAsset();
    }

    void UpdateWorley(WorleyNoiseSettings settings)
    {
        var prng = new System.Random(settings.seed);
        CreateWorleyPointsBuffer(prng, settings.numDivisionsA, "pointsA");
        CreateWorleyPointsBuffer(prng, settings.numDivisionsB, "pointsB");
        CreateWorleyPointsBuffer(prng, settings.numDivisionsC, "pointsC");

        noiseCompute.SetInt("numCellsA", settings.numDivisionsA);
        noiseCompute.SetInt("numCellsB", settings.numDivisionsB);
        noiseCompute.SetInt("numCellsC", settings.numDivisionsC);
        noiseCompute.SetBool("invertNoise", settings.invert);
        noiseCompute.SetInt("tile", settings.tile);

    }

    void CreateWorleyPointsBuffer(System.Random prng, int numCellsPerAxis, string bufferName)
    {
        var points = new Vector3[numCellsPerAxis * numCellsPerAxis * numCellsPerAxis];
        float cellSize = 1f / numCellsPerAxis;

        for (int x = 0; x < numCellsPerAxis; x++)
        {
            for (int y = 0; y < numCellsPerAxis; y++)
            {
                for (int z = 0; z < numCellsPerAxis; z++)
                {
                    float randomX = (float)prng.NextDouble();
                    float randomY = (float)prng.NextDouble();
                    float randomZ = (float)prng.NextDouble();
                    Vector3 randomOffset = new Vector3(randomX, randomY, randomZ) * cellSize;
                    Vector3 cellCorner = new Vector3(x, y, z) * cellSize;

                    int index = x + numCellsPerAxis * (y + z * numCellsPerAxis);
                    points[index] = cellCorner + randomOffset;
                }
            }
        }

        CreateBuffer(points, sizeof(float) * 3, bufferName);
    }

    // Create buffer with some data, and set in shader. Also add to list of buffers to be released
    ComputeBuffer CreateBuffer(System.Array data, int stride, string bufferName, int kernel = 0)
    {
        var buffer = new ComputeBuffer(data.Length, stride, ComputeBufferType.Structured);
        buffersToRelease.Add(buffer);
        buffer.SetData(data);
        noiseCompute.SetBuffer(kernel, bufferName, buffer);
        return buffer;
    }
}