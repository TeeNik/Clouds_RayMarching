#include "Perlin3D.cginc"

struct SphereInfo
{
    float3 pos;
    float radius;
};

struct PerlinInfo
{
    float3 offset;
    int octaves;
    float cutOff;
    float freq;
    float amp;
    float lacunarity;
    float persistence;
};

struct CloudInfo
{
    float density;
    float absortion;
};

float IGN(float2 screenXy)
{
    const float3 magic = float3(0.06711056, 0.00583715, 52.9829189);

    return frac(magic.z * frac(dot(screenXy, magic.xy)));
}

bool raySphereIntersection(float3 ro, float3 rd, float3 s, float r, out float3 t1, out float3 t2)
{
    float t = dot(s - ro, rd);
    float3 p = ro + rd * t;

    float y = length(s - p);

    if (y < r)
    {
        float x = sqrt(r * r - y * y);

        float tx1 = t - x;
        float tx2 = t + x;

        t1 = t < 0.0 ? ro : ro + rd * tx1;
        t2 = ro + rd * tx2;

        return true;
    }

    return false;
}

float sphereDist(float3 pos, float3 s, float3 r)
{
    return distance(pos, s) - r;
}

float4 march(float3 ro, float3 roJittered, float3 rd, float3 lightDir, SphereInfo sphereInfo, PerlinInfo perlinInfo, CloudInfo cloudInfo)
{
    float s = sphereInfo.pos;
    float r = sphereInfo.radius;

    float3 t1 = float3(0.0, 0.0, 0.0);
    float3 t2 = float3(0.0, 0.0, 0.0);

    bool intersectsSphere = raySphereIntersection(ro, rd, s, r, t1, t2);

    if (!intersectsSphere)
        return float4(0.0, 0.0, 0.0, 0.0);

    const int MarchSteps = 8;
    float distInsideSphere = distance(t1, t2);
    float marchStepSize = distInsideSphere / (float)MarchSteps;

    float3 jitter = roJittered - ro;
    t1 += jitter * marchStepSize;

    float3 lightEnergy = float3(0.0f, 0.0f, 0.0f);
    float transmittance = 1.0;

    for (int i = 0; i < MarchSteps; ++i)
    {
        float fromCamSample = PerlinNormal(t1, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);

        if (fromCamSample > 0.01)
        {
            float3 t3 = 0.0;
            float3 t4 = 0.0;

            raySphereIntersection(t1, lightDir, s, r, t3, t4);
            float distInsideSphereToLight = distance(t1, t4);
            float marchStepSizeToLight = distInsideSphereToLight / (float)MarchSteps;

            float3 lightRayPos = t1;
            float accumToLight = 0.0;

            for (int j = 0; j < MarchSteps; ++j)
            {
                float toLightSample = PerlinNormal(lightRayPos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
                accumToLight += (toLightSample * marchStepSizeToLight);

                lightRayPos += (lightDir * marchStepSizeToLight);
            }

            float cloudDensity = saturate(fromCamSample * cloudInfo.density);

            float atten = exp(-accumToLight * cloudInfo.absortion);
            float3 absorbedLight = atten * cloudDensity;

            lightEnergy += (absorbedLight * transmittance);
            transmittance *= (1.0 - cloudDensity);
        }

        t1 += (rd * marchStepSize);
    }

    return float4(lightEnergy.rgb, 1.0 - transmittance);
}
