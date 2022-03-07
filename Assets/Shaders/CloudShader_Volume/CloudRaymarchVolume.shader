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

                    float sampledDensity = tex3D(_Volume, samplePos).r;
                    density += sampledDensity * _DensityScale;

                    float3 lightRayOrigin = samplePos;
                    for (int j = 0; j < _NumLightSteps; ++j) {
                        lightRayOrigin += _WorldSpaceLightPos0 * _LightStepSize;
                        float lightDensity = tex3D(_Volume, lightRayOrigin).r;
                        lightAccumulation += lightDensity * _DensityScale;
                    }
                    
                    float lightTransmission = exp(-lightAccumulation);
                    float shadow = _DarknessThreshold + lightTransmission * (1.0 - _DarknessThreshold);
                    finalLight += density * transmittance * shadow;
                    transmittance *= exp(-density * _LightAbsorb);

                }

                transmission = exp(-density);

                return float3(finalLight, transmission, transmittance);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //fixed4 col = tex3D(_MainTex, i.worldPos);

                //fixed4 col = i.worldPos;
                float3 col = raymarch(i.worldPos, i.worldPos - _WorldSpaceCameraPos);
                return fixed4(col.x, col.x, col.x, 1 - col.y);
            }
            ENDCG
        }
    }
}
