#define PI 3.14159265359

float Hash(float f)
{
    return frac(sin(f) * 43758.5453);
}

float Hash21(float2 v)
{
    return Hash(dot(v, float2(253.14, 453.74)));
}

float Hash31(float3 v)
{
    return Hash(dot(v, float3(253.14, 453.74, 183.3)));
}

float3 Random3D(float3 p) {
    return frac(sin(float3(dot(p, float3(127.1, 311.7, 217.3)), dot(p, float3(269.5, 183.3, 431.1)), dot(p, float3(365.6, 749.9, 323.7)))) * 437158.5453);
}

float4 GetWorleyNoise3D(float3 uvw)
{
    float noise = 0.0;

    float3 p = floor(uvw);
    float3 f = frac(uvw);

    float4 res = float4(1.0, 1.0, 1.0, 1.0);
    for (int x = -1; x <= 1; ++x)
    {
        for (int y = -1; y <= 1; ++y)
        {
            for (int z = -1; z <= 1; ++z)
            {
                float3 gp = p + float3(x, y, z);	//grid point

                float3 v = Random3D(gp);

                float3 diff = gp + v - uvw;

                float d = length(diff);

                if (d < res.x)
                {
                    res.xyz = float3(d, res.x, res.y);
                }
                else if (d < res.y)
                {
                    res.xyz = float3(res.x, d, res.y);
                }
                else if (d < res.z)
                {
                    res.z = d;
                }

                res.w = Hash31(gp);
            }
        }
    }

    return 1.0 - res;
}

float fBMWorley(float3 x, float lacunarity, float gain, int numOctaves)
{
    float total = 0.0;
    float frequency = 1.0;
    float amplitude = 1.0;
    float totalAmplitude = 0.0;
    for (int i = 0; i < numOctaves; ++i)
    {
        totalAmplitude += amplitude;

        float4 n = GetWorleyNoise3D(x * frequency);
        total += amplitude * n.x;

        frequency *= lacunarity;
        amplitude *= gain;
    }

    return total / totalAmplitude;
}

float WorleyNormal(float3 p, float cutOff, int octaves, float3 offset, float frequency, float amplitude, float lacunarity, float persistence)
{
    float sum = 0.0;
    float maxAmp = 0.0;

    for (int i = 0; i < octaves; ++i)
    {
        float h = GetWorleyNoise3D((p + offset) * frequency);

        sum += h * amplitude;
        maxAmp += amplitude;

        frequency *= lacunarity;
        amplitude *= persistence;
    }

    sum = Remap01(sum, 0.0, maxAmp);
    sum = sum * step(cutOff, sum);

    return sum;
}