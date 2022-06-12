#include "../Utils/Perlin3D.cginc"
#include "../Utils/WorleyNoise.cginc"
#include "../Utils/DistanceFunctions.cginc"
#include "../Utils/NoiseFunctions.cginc"
#include "../Utils/TileablePerlinWorleyNoise.cginc"

struct SphereInfo
{
    float3 pos;
    float radius;
};

struct CubeInfo
{
    float3 minBound;
    float3 maxBound;
};

struct PerlinInfo
{
    int octaves;
    float cutOff;
    float freq;
    float amp;
    float lacunarity;
    float persistence;
    float3 offset;
    float detailsWeight;
};

struct CloudInfo
{
    float density;
    float absortion;
    float3 cloudColor;
    float3 shadowColor;
    sampler3D volume;
    float3 offset;
    float height;
    float cutOff;

    sampler3D detailsVolume;
    float detailsWeight;
};

#define LIGHT_COUNT 8

struct LightSourceInfo
{
    float4 transform;
    float4 color;
};

struct LightInfo
{
    float3 ambient;
    float3 lightDir;

    LightSourceInfo lightSources[LIGHT_COUNT];
};

#define MARCH_STEPS 128
#define LIGHT_STEPS 8

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

bool rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 invRaydir, out float distToBox, out float distInsideBox) {
    float3 t0 = (boundsMin - rayOrigin) * invRaydir;
    float3 t1 = (boundsMax - rayOrigin) * invRaydir;
    float3 tmin = min(t0, t1);
    float3 tmax = max(t0, t1);

    float dstA = max(max(tmin.x, tmin.y), tmin.z);
    float dstB = min(tmax.x, min(tmax.y, tmax.z));

    distToBox = max(0, dstA);
    distInsideBox = max(0, dstB - distToBox);
    return dstA <= dstB;
}

float sampleDensity(float3 pos, CloudInfo cloudInfo, CubeInfo cube, SphereInfo sphere)
{
    float3 normalizedPos = (pos - cube.minBound) / (cube.maxBound - cube.minBound);
    float3 samplePos = pos + cloudInfo.offset;
 
    float shape = tex3Dlod(cloudInfo.volume, float4(samplePos, 0));

    float add = 0.0;
    if (normalizedPos.y < cloudInfo.height)
    {
        if (normalizedPos.y < shape * cloudInfo.height)
        {
            add = shape;
        }
    }

    //float details = tex3Dlod(cloudInfo.detailsVolume, float4(samplePos, 0));
    //float oneMinusShape = 1 - shape;
    //float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
    //shape = shape - details * detailErodeWeight * cloudInfo.detailsWeight;

    //float dist = length(pos - sphere.pos) / max(sphere.radius,0.001);
    //if (dist < 1.0)
    //{
    //    col *= smoothstep(0.6, 1.0, dist);
    //}

    shape = shape * step(cloudInfo.cutOff, shape);
    return shape + add;
    
    //return PerlinNormal(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
    //return perlinfbm(samplePos, perlinInfo.freq, perlinInfo.octaves);
    //return WorleyTilled(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
}

inline float3 GetLight(int lightIndex, LightInfo lightInfo, CubeInfo cubeInfo,
    CloudInfo cloudInfo, SphereInfo sphereInfo, float density, float transmittance, float3 pos)
{
    float3 lightDir;
    float3 lightColor;
    float distToLight;

    //for dynamic lights
    if (lightIndex >= 0)
    {
        LightSourceInfo info = lightInfo.lightSources[lightIndex];
        lightDir = info.transform.xyz - pos;
        distToLight = length(lightDir);
        lightDir = normalize(lightDir);
        lightColor = info.color;
    
        float c = smoothstep(0, 1, info.transform.w / distToLight);
        c *= c;
        lightColor *= c;
        if (c < 0.01)
        {
            return float3(0, 0, 0);
        }
    }
    else //ambient
    {
        float t = 0.0f;
        rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, pos, 1 / lightInfo.lightDir, t, distToLight);
        lightDir = lightInfo.lightDir;
        lightColor = lightInfo.ambient;
    }

    //MarchSteps is used instead of LightSteps intentionally.
    //Small steps five much prettier result.
    //Maybe I can replace it with occlusion shadow later.
    float marchStepSizeToLight = distToLight / (float)MARCH_STEPS;
    float accumToLight = 0.0;

    for (int j = 0; j < LIGHT_STEPS; ++j)
    {
        float toLightSample = sampleDensity(pos, cloudInfo, cubeInfo, sphereInfo);
        accumToLight += (toLightSample * marchStepSizeToLight);
        pos += (lightDir * marchStepSizeToLight);
    }

    float atten = exp(-accumToLight * cloudInfo.absortion);
    float3 absorbedLight = atten * density;
    return (absorbedLight * transmittance) * lightColor;
}

float4 march(float3 ro, float3 roJittered, float3 rd, LightInfo lightInfo, float depth, CubeInfo cubeInfo, CloudInfo cloudInfo, SphereInfo sphereInfo)
{
    float3 pos = float3(0.0, 0.0, 0.0);
    float distToBox, distInsideBox;
    bool intersectsBox = rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, ro, 1/rd, distToBox, distInsideBox);

    if (!intersectsBox)
        return float4(0.0, 0.0, 0.0, 0.0);

    pos = ro + rd * distToBox;
    float marchStepSize = distInsideBox / (float)MARCH_STEPS;

    float3 jitter = roJittered - ro;
    pos += jitter * marchStepSize;

    float3 finalColor = float3(0, 0, 0);

    float transmittance = 1.0;

    for (int i = 0; i < MARCH_STEPS; ++i)
    {
        if (length(pos - ro) >= depth)
        {
            break;
        }

        float fromCamSample = sampleDensity(pos, cloudInfo, cubeInfo, sphereInfo);
        //return float4(fromCamSample, fromCamSample, fromCamSample, 1);

        if (fromCamSample > 0.01)
        {
            float cloudDensity = saturate(fromCamSample * cloudInfo.density);

            for (int i = -1; i < LIGHT_COUNT; ++i)
            {
                finalColor += GetLight(i, lightInfo, cubeInfo, cloudInfo, sphereInfo, cloudDensity, transmittance, pos);
            }

            transmittance *= (1.0 - cloudDensity);
            if (transmittance < 0.01)
            {
                transmittance = 0;
                break;
            }
        }

        pos += (rd * marchStepSize);
    }

    return float4(finalColor, 1.0 - transmittance);
}