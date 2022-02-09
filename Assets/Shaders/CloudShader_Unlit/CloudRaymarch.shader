// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Unlit/CloudRaymarchVolume"
{
    Properties
    {
        _Volume("Volume", 3D) = "white" {}

        _NumSteps("NumSteps", float) = 64
        _StepSize("StepSize", float) = 0.02
        _DensityScale("DensityScale", float) = 0.15
        _Offset("Offset", Vector) = (0,0,0)

        _NumLightSteps("NumLightSteps", float) = 8
        _LightStepSize("LightStepSize", float) = 0.06

        _LightAbsorb("LightAbsorb", float) = 2.0
        _DarknessThreshold("DarknessThreshold", float) = 0.2
        _Transmittance("Transmittance", float) = 1

    }
    SubShader
    {
        //Tags { "RenderType"="Opaque" }
        Tags { "Queue" = "Transparent" "IgnoreProjector" = "True" "RenderType" = "Transparent" }
        LOD 100

        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "../DistanceFunctions.cginc"

            sampler3D _Volume;

            float _NumSteps;
            float _StepSize;
            float _DensityScale;
            float3 _Offset;

            float _NumLightSteps;
            float _LightStepSize;

            float _LightAbsorb;
            float _DarknessThreshold;
            float _Transmittance;

            struct appdata
            {
                float4 vertex : POSITION;
            };

            struct v2f
            {
                float4 vertex : SV_POSITION;
                float4 worldPos : TEXCOORD0;
            };

            v2f vert (appdata v)
            {
                v2f o;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.vertex = UnityObjectToClipPos(v.vertex);
                return o;
            }

            float3x3 m = float3x3(0.00, 0.80, 0.60,
                -0.80, 0.36, -0.48,
                -0.60, -0.48, 0.64);

            float hash(float n)
            {
                return frac(sin(n) * 43758.5453);
            }
            
            float noise(in float3 x)
            {
                float3 p = floor(x);
                float3 f = frac(x);
            
                f = f * f * (3.0 - 2.0 * f);
            
                float n = p.x + p.y * 57.0 + 113.0 * p.z;
            
                float res = lerp(lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
                    lerp(hash(n + 57.0), hash(n + 58.0), f.x), f.y),
                    lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
                        lerp(hash(n + 170.0), hash(n + 171.0), f.x), f.y), f.z);
                return res;
            }
            
            float fbm(float3 p)
            {
                float f;
                f = 0.5000 * noise(p); p = mul(m, p * 2.02);
                f += 0.2500 * noise(p); p = mul(m, p * 2.03);
                f += 0.1250 * noise(p); p = mul(m, p * 2.01);
                f += 0.0625 * noise(p);
                return f;
            }

            float3 hash33(float3 p3) {
                float3 p = frac(p3 * float3(.1031, .11369, .13787));
                p += dot(p, p.yxz + 19.19);
                return -1.0 + 2.0 * frac(float3((p.x + p.y) * p.z, (p.x + p.z) * p.y, (p.y + p.z) * p.x));
            }

            float worley(float3 p, float scale) {

                float3 id = floor(p * scale);
                float3 fd = frac(p * scale);

                float n = 0.;

                float minimalDist = 1.;


                for (float x = -1.; x <= 1.; x++) {
                    for (float y = -1.; y <= 1.; y++) {
                        for (float z = -1.; z <= 1.; z++) {

                            float3 coord = float3(x, y, z);
                            float3 rId = hash33(fmod(id + coord, scale)) * 0.5 + 0.5;

                            float3 r = coord + rId - fd;

                            float d = dot(r, r);

                            if (d < minimalDist) {
                                minimalDist = d;
                            }

                        }//z
                    }//y
                }//x

                return 1.0 - minimalDist;
            }
            
            float map(float3 p) 
            {
                float iTime = _Time.y * 1;
                float f = fbm(p - float3(0, 0.5, 1.0) * iTime * .25);
                float sph = sdSphere(p, 1.0) + f;
                return worley(p, 10);
            }

            //-------------------

            //float map(float3 pos)
            //{
            //    float iTime = _Time.y * 1;
            //    //float sphere = sdSphere(pos, 1) + 0.5 * fbm(pos * 10 * sin(iTime));
            //    float sphere = sdTorus(pos, float2(1, .5)) + 0.5 * fbm(pos * 10);
            //    //float sphere = sdSphere(pos, .5);
            //    return sphere;
            //}


            float3 raymarch(float3 rayOrigin, float3 rayDirection)
            {
                float density = 0;
                float transmission = 0;
                float lightAccumulation = 0;
                float finalLight = 0;
                float transmittance = _Transmittance;

                for (int i = 0; i < _NumSteps; ++i) {
                    rayOrigin += (rayDirection * _StepSize);

                    float3 offset = _Offset - mul(unity_ObjectToWorld, float4(0, 0, 0, 1));
                    float3 samplePos = rayOrigin + offset;

                    //if (map(samplePos) < 0.001)
                    {
                        density += map(samplePos) * _DensityScale;

                        float3 lightRayOrigin = samplePos;
                        for (int j = 0; j < _NumLightSteps; ++j) {
                            lightRayOrigin += _WorldSpaceLightPos0 * _LightStepSize;
                            
                            //add accuracy check
                            float lightDensity = map(lightRayOrigin);

                            lightAccumulation += lightDensity * _DensityScale;
                        }

                        float lightTransmission = exp(-lightAccumulation);
                        float shadow = _DarknessThreshold + lightTransmission * (1.0 - _DarknessThreshold);
                        finalLight += density * transmittance * shadow;
                        transmittance *= exp(-density * _LightAbsorb);
                    }


                    //float sampledDensity = map(samplePos);
                    //density += sampledDensity * _DensityScale;
                    //
                    //float3 lightRayOrigin = samplePos;
                    //for (int j = 0; j < _NumLightSteps; ++j) {
                    //    lightRayOrigin += _WorldSpaceLightPos0 * _LightStepSize;
                    //    float lightDensity = map(samplePos);
                    //    lightAccumulation += lightDensity * _DensityScale;
                    //}
                    //
                    //float lightTransmission = exp(-lightAccumulation);
                    //float shadow = _DarknessThreshold + lightTransmission * (1.0 - _DarknessThreshold);
                    //finalLight += density * transmittance * shadow;
                    //transmittance *= exp(-density * _LightAbsorb);

                }

                return float3(density, 0, 0);

                transmission = exp(-density);
                return float3(finalLight, transmission, transmittance);
            }

            fixed4 frag(v2f i) : SV_Target
            {
                //fixed4 col = tex3D(_MainTex, i.worldPos);

                //fixed4 col = i.worldPos;

                float3 rayDir = normalize(i.worldPos - _WorldSpaceCameraPos);
                //float3 col = raymarch(i.worldPos, rayDir);
                float3 col = map(i.worldPos);

                return fixed4(col.x, col.x, col.x, 1 - col.x);
                return fixed4(col.x, col.x, col.x, 1 - col.y);
            }
            ENDCG
        }
    }
}
