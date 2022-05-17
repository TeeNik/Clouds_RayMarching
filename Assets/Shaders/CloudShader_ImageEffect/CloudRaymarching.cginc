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
};

struct CloudInfo
{
    float density;
    float absortion;
    float3 cloudColor;
    float3 shadowColor;
    sampler3D volume;
    sampler3D detailsVolume;
    float3 offset;
};

struct LightSourceInfo
{
    float4 transform;
    float3 color;
};

struct LightInfo
{
    float3 ambient;
    float3 lightDir;

    LightSourceInfo lightSources[1];
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

float sampleDensity(float3 pos, PerlinInfo perlinInfo, CloudInfo cloudInfo, CubeInfo cube, SphereInfo sphere)
{
    float3 normalizedPos = (pos - cube.minBound) / (cube.maxBound - cube.minBound);
    normalizedPos = pos + cloudInfo.offset;
    
    float shape = tex3D(cloudInfo.volume, normalizedPos); 
    //float details = tex3D(cloudInfo.detailsVolume, normalizedPos);
    //float invDetails = 1 - details;
    //
    //float oneMinusShape = 1 - shape;
    //float detailErodeWeight = oneMinusShape * oneMinusShape * oneMinusShape;
    //float density = shape - details * detailErodeWeight;

    //float dist = length(pos - sphere.pos) / max(sphere.radius,0.001);
    //if (dist < 1.0)
    //{
    //    col *= smoothstep(0.6, 1.0, dist);
    //}
    return shape;
    
    return PerlinNormal(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
    return perlinfbm(normalizedPos, perlinInfo.freq, perlinInfo.octaves);
    return WorleyTilled(pos, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset, perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence);
}

float3 GetLight(int lightIndex, LightInfo lightInfo, CubeInfo cubeInfo, PerlinInfo perlinInfo,
    CloudInfo cloudInfo, SphereInfo sphereInfo, float density, float transmittance, float3 pos, int lightSteps)
{
    LightSourceInfo info = lightInfo.lightSources[lightIndex];
    float3 lightDir = info.transform.xyz - pos;
    float distToLight = length(lightDir);
    lightDir = normalize(lightDir);


    float c = smoothstep(0, 1, info.transform.w / distToLight);
    //return density;

    float marchStepSizeToLight = distToLight / (float)64;

    float3 lightRayPos = pos;
    float accumToLight = 0.0;

    for (int j = 0; j < 16; ++j)
    {
        float toLightSample = sampleDensity(lightRayPos, perlinInfo, cloudInfo, cubeInfo, sphereInfo);
        accumToLight += (toLightSample * marchStepSizeToLight);
        lightRayPos += (lightDir * marchStepSizeToLight);
    }

    float atten = exp(-accumToLight * cloudInfo.absortion);
    float3 absorbedLight = atten * info.color * c;
    return (absorbedLight * transmittance);
}

float4 march(float3 ro, float3 roJittered, float3 rd, LightInfo lightInfo, float depth, CubeInfo cubeInfo, PerlinInfo perlinInfo, CloudInfo cloudInfo, SphereInfo sphereInfo)
{
    float3 t1 = float3(0.0, 0.0, 0.0);
    float distToBox, distInsideBox;
    bool intersectsBox = rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, ro, 1/rd, distToBox, distInsideBox);

    if (!intersectsBox)
        return float4(0.0, 0.0, 0.0, 0.0);

    t1 = ro + rd * distToBox;
    const int MarchSteps = 64;
    const int LightSteps = 8;
    float marchStepSize = distInsideBox / (float)MarchSteps;

    float3 jitter = roJittered - ro;
    t1 += jitter * marchStepSize;

    float3 lightEnergy = float3(0.0f, 0.0f, 0.0f);
    float3 finalColor = float3(0, 0, 0);

    float transmittance = 1.0;

    for (int i = 0; i < MarchSteps; ++i)
    {
        if (length(t1 - ro) >= depth)
        {
            return(0, 0, 0, 0);
        }

        float fromCamSample = sampleDensity(t1, perlinInfo, cloudInfo, cubeInfo, sphereInfo);
        //return float4(fromCamSample, fromCamSample, fromCamSample, 1);

        if (fromCamSample > 0.01)
        {

            float cloudDensity = saturate(fromCamSample * cloudInfo.density);

            //start loop

            int numOfLights = 1;
            for (int i = 0; i < numOfLights; ++i)
            {
                finalColor += GetLight(i, lightInfo, cubeInfo, perlinInfo, cloudInfo, sphereInfo, cloudDensity, transmittance, t1, LightSteps);
            }

            float t2 = 0.0;
            float distInsideSphereToLight = 0.0;
            
            rayBoxDst(cubeInfo.minBound, cubeInfo.maxBound, t1, 1/ lightInfo.lightDir, t2, distInsideSphereToLight);
            
            //MarchSteps is used instead of LightSteps intentionally.
            //Small steps five much prettier result.
            //Maybe I can replace it with occlusion shadow later.
            float marchStepSizeToLight = distInsideSphereToLight / (float)MarchSteps;
            
            float3 lightRayPos = t1;
            float accumToLight = 0.0;
            
            for (int j = 0; j < LightSteps; ++j)
            {
                float toLightSample = sampleDensity(lightRayPos, perlinInfo, cloudInfo, cubeInfo, sphereInfo);
                accumToLight += (toLightSample * marchStepSizeToLight);
            
                lightRayPos += (lightInfo.lightDir * marchStepSizeToLight);
            }
            
            
            float atten = exp(-accumToLight * cloudInfo.absortion);
            float3 absorbedLight = atten * cloudDensity;
            
            lightEnergy += (absorbedLight * transmittance);
            finalColor += (absorbedLight * transmittance) * lightInfo.ambient;


            //end loop

            transmittance *= (1.0 - cloudDensity);

            if (transmittance < 0.01)
            {
                transmittance = 0;
                break;
            }
        }

        t1 += (rd * marchStepSize);
    }

    return float4(finalColor, 1.0 - transmittance);
}