Shader "TeeNik/TestShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Accuracy("Accuracy", Range(0.001, 0.1)) = 0.01
		_MaxIterations("MaxIterations", float) = 64

		_LightColor("LightColor", Color) = (1,1,1,1)
		_LightIntensity("LightIntensity", float) = 1.0

		_ShadowDistance("ShadowDistance", Vector) = (0,0,0)
		_ShadowIntensity("ShadowIntensity", float) = 1.0
		_ShadowPenumbra("ShadowPenumbra", float) = 1.0

		_AOStepsize("AOStepsize", float) = 1.0
		_AOIterations("AOIterations", float) = 1.0
		_AOIntensity("AOIntensity", float) = 1.0

		_MarchSize("_MarchSize", float) = 0.05
		_TimeScale("_TimeScale", Range(0.0, 1.0)) = 1.0

		_ReflectionIntesity("ReflectionIntesity", Range(0.0, 1.0)) = 0.5
    }
    SubShader
    {
        // No culling or depth
        Cull Off ZWrite Off ZTest Always

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
			#pragma target 3.0

            #include "UnityCG.cginc"
			#include "../DistanceFunctions.cginc"
			#include "../NoiseFunctions.cginc"

			sampler2D _MainTex;

			float _Accuracy;
			int _MaxIterations;
			float _RandomBorder;

			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum;
			uniform float4x4 _CamToWorld;
			uniform float _MaxDistance;

			uniform float4 _Sphere;
			uniform float4 _Box;
			uniform float4 _Torus;
			uniform float4x4 _RotationMat;

			uniform fixed4 _MainColor;
			uniform float3 _ModInterval;

			uniform float3 _LightDir;
			uniform fixed4 _LightColor;
			uniform float _LightIntensity;

			uniform float3 _ShadowDistance;
			uniform float _ShadowIntensity;
			uniform float _ShadowPenumbra;

			uniform float _AOStepsize;
			uniform float _AOIterations;
			uniform float _AOIntensity;

			uniform float _MarchSize;
			uniform float _TimeScale;

			uniform float _ReflectionIntesity;

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
				float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
				float3 ray : TEXCOORD1;
            };

            v2f vert (appdata v)
            {
                v2f o;
				half index = v.vertex.z;
				v.vertex.z = 0.1;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;

				o.ray = _CamFrustum[(int)index].xyz;
				o.ray /= abs(o.ray.z);
				o.ray = mul(_CamToWorld, o.ray);

                return o;
            }


			float BeerLambert(float absorptionCoefficient, float distanceTraveled)
			{
				return exp(-absorptionCoefficient * distanceTraveled);
			}

			float GetLightAttenuation(float distanceToLight)
			{
				return 1.0 / pow(distanceToLight, 1);
			}

			float3 applyFog(float3 ro, float3 rd, in float3 rgb, in float distance)
			{
				float a = 0.5;
				float b = 0.45;
				float e = 2.72;
				float fogAmount = (a / b) * pow(e, -ro.y * b) * (1.0 - pow(e, -distance * rd.y * b)) / rd.y;
				//float fogAmount = 1.0 - pow(1.5, -distance * 0.005);
				float3  fogColor = _LightColor; // float3(1, 1, 1);
				return lerp(rgb, fogColor, fogAmount);
			}

			float map(float3 pos)
			{
				_ModInterval = float3(12, 1, 12);
				if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				{
					float modX = pMod1(pos.x, _ModInterval.x);
					//float modY = pMod1(pos.y, _ModInterval.y);
					float modZ = pMod1(pos.z, _ModInterval.z);
				}

				float height = 10;
				float result = sdBox(pos - float3(0, height * 0.5, 0), float3(3, height, 3));
				//result = opU(result, sdBox(pos - float3(0, -0.5 * height, 0), float3(10, 0.5, 10)));
				return result;
			}

			float3 getNormal(float3 pos)
			{
				const float2 offset = float2(0.001, 0.0);
				float3 normal = float3(
					map(pos + offset.xyy) - map(pos - offset.xyy),
					map(pos + offset.yxy) - map(pos - offset.yxy),
					map(pos + offset.yyx) - map(pos - offset.yyx));
				return normalize(normal);
			}

			float hardShadow(float3 ro, float3 rd, float mint, float maxt)
			{
				for (float t = mint; t < maxt;)
				{
					float h = map(ro + rd * t);
					if (h < 0.001)
					{
						return 0.0;
					}
					t += h;
				}
				return 1.0;
			}

			float softShadow(float3 ro, float3 rd, float mint, float maxt, float k)
			{
				float result = 1.0;
				for (float t = mint; t < maxt;)
				{
					float h = map(ro + rd * t);
					if (h < 0.001)
					{
						return 0.0;
					}
					result = min(result, k * h / t);
					t += h;
				}
				return result;
			}

			float ambientOcclusion(float3 pos, float3 normal)
			{
				float step = _AOStepsize;
				float ao = 0.0;
				float dist;
				for (int i = 1; i <= _AOIterations; ++i)
				{
					dist = step * i;
					ao += max(0.0, (dist - map(pos + normal * dist)) / dist);
				}
				return 1 - ao * _AOIntensity;
			}

			float3 renderColor(float3 ro, float3 rd, float3 currPos, float depth)
			{
				float time = _Time.y * _TimeScale;
				float3 color = float3(1.0, 1.0, 1.0);
				float3 lightDir = normalize(float3(1.0, 0.4, 0.0));
				float3 normal = getNormal(currPos);

				float3 light = (_LightColor * dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5) * _LightIntensity;
				float3 lightPos = float3(0, 20, 0);
				float attenuation = 1.0 - length(currPos - lightPos) / 65;
				light *= attenuation;

				float roughness = 0.05;
				float specPower = 1. / (roughness * roughness);
				float specStrength = (specPower + 8.) / (4. * 2 * PI);

				color = float3(1, 1, 1) * 0.35 * light;

				return color;
			}

			fixed4 raymarching(float3 ro, float3 rd, float depth, inout float3 pos)
			{
				fixed4 result = fixed4(0, 0, 0, 0);
				float t = 0;

				float dst = _MaxDistance;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					if (t > _MaxDistance || t >= depth)
					{
						//environment
						//result = fixed4(rd, 0);
						break;
					}

					pos = ro + rd * t;
					float dist = map(pos);
					if (dist < _Accuracy) //hit
					{
						float4 shading = float4(renderColor(ro, rd, pos, depth), 0.5);
						dst = length(pos - ro);
						result = fixed4(shading.xyz, 1.0);
						break;
					}
					t += dist;
				}
				result.xyz = applyFog(ro, rd, result.xyz, dst);
				result.w = 1.0;
				return result;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth *= length(i.ray);

				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				
				float3 hitPos;
				fixed4 result = raymarching(rayOrigin, rayDirection, depth, hitPos);
				if (result.w > 0.0)
				{
					float3 normal = getNormal(hitPos);
					float3 reflectedDir = normalize(reflect(rayDirection, normal));
					result += raymarching(hitPos + (reflectedDir * 0.01), reflectedDir, depth, hitPos) * _ReflectionIntesity;
				}
				//fixed3 col = tex2D(_MainTex, i.uv + (result.r / 5) * result.w);


				fixed3 col = tex2D(_MainTex, i.uv);

				float t = pow((((1. + sin(_Time.y * 10.) * .5)
					* .8 + sin(_Time.y * cos(i.uv.y) * 41415.92653) * .0125)
					* 1.5 + sin(_Time.y * 7.) * .5), 5.);

				float4 c1 = tex2D(_MainTex, i.uv + float2(t * .002, .0));
				float4 c2 = tex2D(_MainTex, i.uv + float2(t * .005, .0));
				float4 c3 = tex2D(_MainTex, i.uv + float2(t * .009, .0));

				float noise = hash((hash(i.uv.x) + i.uv.y) * _Time.y) * .055;
				fixed3 back = fixed3(1, 1, 1) * 0.25;

				float4 gold = float4(232, 185, 32, 255.0) / 255;
				float p = pattern(float3(i.uv, 0.0) * 10, 0.0);
				p = smoothstep(0.55, 1.0, p) * 1.5;
				return p * gold;

				return fixed4(back * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
