#include "Perlin3D.cginc"
#include "WorleyNoise.cginc"
#include "../DistanceFunctions.cginc"
#include "../NoiseFunctions.cginc"

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
    float3 offset;
    int octaves;
    float cutOff;
    float freq;
    float amp;
    float lacunarity;
    float persistence;
    sampler3D noise;
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

float sampleDensity(float3 pos, PerlinInfo perlinInfo, CubeInfo cube)
{
    float iTime = _Time.y * 1;
    //float noise = PerlinNormal(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset,
    //    perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
    //float worley = (WorleyNormal(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset,
    //    perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence)) * 0.5;
    //return worley - fbm(pos * 20) * 0.35;

    //
    //if (sdfValue < 0.01)
    //{
    //    return 0.1;
    //} 
    //else {
    //    return 0.0f;
    //}
    //
    ////float sdfValue = sdSphere(pos - float3(-8.0, 2.0 + 20.0 * sin(iTime), -1), sphereInfo.radius);
    ////sdfValue = sdSmoothUnion(sdfValue, sdSphere(pos - float3(8.0, 8.0 + 12.0 * cos(iTime), 3), 5.6), 3.0f);
    ////sdfValue = sdSmoothUnion(sdfValue, sdSphere(pos - float3(5.0 * sin(iTime), 3.0, 0), 8.0), 3.0) + 7.0 * noise;
    //////sdfValue = sdSmoothUnion(sdfValue, sdPlane(pos + float3(0, 0.4, 0)), 22.0);
    //
    ////float sdfValue = sdSphere(pos, float3(5.0 * sin(iTime), 3.0, 0), 8.0) + 7.0 * fbm_4(fbmCoord / 3.2);
    ////float sphere = sdSphere(pos - _Sphere.xyz, _Sphere.w);
    //return sdfValue;
    //
    //
    //float cl = sdCappedCylinder(sphereInfo.pos - pos, 10, 1);
    //float tr = sdTorus(sphereInfo.pos - pos, float2(1.0, 0.5));
    //if(tr < 0.01)
    //{
    //    return 0.00;
    //
    //}

    float3 normalizedPos = (pos - cube.minBound) / (cube.maxBound - cube.minBound);
    fixed4 col = tex3D(perlinInfo.noise, normalizedPos);
    return col.x;

    return PerlinNormal(normalizedPos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
}

float4 march(float3 ro, float3 roJittered, float3 rd, float3 lightDir, CubeInfo cubeInfo, PerlinInfo perlinInfo, CloudInfo cloudInfo, SphereInfo sphereInfo)
{
    float3 t1 = float3(0.0, 0.0, 0.0);
    float distToBox, distInsideBox;
    bool intersectsBox = rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, ro, 1/rd, distToBox, distInsideBox);

    if (!intersectsBox)
        return float4(0.0, 0.0, 0.0, 0.0);

    t1 = ro + rd * distToBox;
    const int MarchSteps = 8;
    float marchStepSize = distInsideBox / (float)MarchSteps;

    float3 jitter = roJittered - ro;
    t1 += jitter * marchStepSize;

    float3 lightEnergy = float3(0.0f, 0.0f, 0.0f);
    float transmittance = 1.0;

    for (int i = 0; i < MarchSteps; ++i)
    {
        float fromCamSample = sampleDensity(t1, perlinInfo, cubeInfo);

        if (fromCamSample > 0.01)
        {
            float t2 = 0.0;
            float distInsideSphereToLight = 0.0;

            rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, t1, 1/lightDir, t2, distInsideSphereToLight);
            float marchStepSizeToLight = distInsideSphereToLight / (float)MarchSteps;

            float3 lightRayPos = t1;
            float accumToLight = 0.0;

            for (int j = 0; j < MarchSteps; ++j)
            {
                float toLightSample = sampleDensity(lightRayPos, perlinInfo, cubeInfo);
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

//march sphere
/*
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
*/
