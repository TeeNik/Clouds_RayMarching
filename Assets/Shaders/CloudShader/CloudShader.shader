Shader "TeeNik/CloudShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Accuracy("Accuracy", Range(0.001, 0.1)) = 0.01
		_MaxIterations("MaxIterations", Range(0, 300)) = 64
		_RandomBorder("RandomBorder", Range(0.0, 1.0)) = .99

		_LightColor("LightColor", Color) = (1,1,1,1)
		_LightIntensity("LightIntensity", float) = 1.0

		_ShadowDistance("ShadowDistance", Vector) = (0,0,0)
		_ShadowIntensity("ShadowIntensity", float) = 1.0
		_ShadowPenumbra("ShadowPenumbra", float) = 1.0

		_AOStepsize("AOStepsize", float) = 1.0
		_AOIterations("AOIterations", float) = 1.0
		_AOIntensity("AOIntensity", float) = 1.0

		_AbsorptionCoefficient("AbsorptionCoefficient", float) = 0.25
		_LightAttenuation("LightAttenuation", float) = 1.0
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

			sampler2D _MainTex;

			float _Accuracy;
			int _MaxIterations;
			float _RandomBorder;

			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum;
			uniform float4x4 _CamToWorld;
			uniform float _MaxDistance;

			uniform float3 _LightPos;

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

			uniform float _AbsorptionCoefficient;
			uniform float _LightAttenuation;


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

			float sdPlane(float3 p)
			{
				return p.y;
			}

			float3 opU(float3 d1, float3 d2)
			{
				return (d1.x < d2.x) ? d1 : d2;
			}

			float sdSmoothUnion(float d1, float d2, float k)
			{
				float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
				return lerp(d2, d1, h) - k * h * (1.0 - h);
			}

			float3 Translate(float3 pos, float3 translate)
			{
				return pos -= translate;
			}

			float sdSphere(float3 p, float3 origin, float s)
			{
				p = Translate(p, origin);
				return length(p) - s;
			}

			float hash1(float n)
			{
				return frac(n * 17.0 * frac(n * 0.3183099));
			}

			float noise(in float3 x)
			{
				float3 p = floor(x);
				float3 w = frac(x);

				float3 u = w * w * w * (w * (w * 6.0 - 15.0) + 10.0);

				float n = p.x + 317.0 * p.y + 157.0 * p.z;

				float a = hash1(n + 0.0);
				float b = hash1(n + 1.0);
				float c = hash1(n + 317.0);
				float d = hash1(n + 318.0);
				float e = hash1(n + 157.0);
				float f = hash1(n + 158.0);
				float g = hash1(n + 474.0);
				float h = hash1(n + 475.0);

				float k0 = a;
				float k1 = b - a;
				float k2 = c - a;
				float k3 = e - a;
				float k4 = a - b - c + d;
				float k5 = a - c - e + g;
				float k6 = a - b - e + f;
				float k7 = -a + b + c - d + e - f - g + h;

				return -1.0 + 2.0 * (k0 + k1 * u.x + k2 * u.y + k3 * u.z + k4 * u.x * u.y + k5 * u.y * u.z + k6 * u.z * u.x + k7 * u.x * u.y * u.z);
			}

			const float3x3 m3 = float3x3(0.00, 0.80, 0.60,
				-0.80, 0.36, -0.48,
				-0.60, -0.48, 0.64);

			float fbm_4(in float3 x)
			{
				float f = 2.0;
				float s = 0.5;
				float a = 0.0;
				float b = 0.5;
				for (int i = 0; i < 4; i++)
				{
					float n = noise(x);
					a += b * n;
					b *= s;
					//x = mul(mul(m3, f), x);
					x = f * x;
				}
				return a;
			}

			float map(float3 pos)
			{
				float iTime = _Time.y * 1;
				float3 fbmCoord = (pos + 2.0 * float3(iTime, 0, iTime)) / 1.5;
				float sdfValue = sdSphere(pos, float3(-8.0, 2.0 + 20.0 * sin(iTime), -1), 5.6);
				sdfValue = sdSmoothUnion(sdfValue, sdSphere(pos, float3(8.0, 8.0 + 12.0 * cos(iTime), 3), 5.6), 3.0f);
				sdfValue = sdSmoothUnion(sdfValue, sdSphere(pos, float3(5.0 * sin(iTime), 3.0, 0), 8.0), 3.0) + 7.0 * fbm_4(fbmCoord / 3.2);
				//sdfValue = sdSmoothUnion(sdfValue, sdPlane(pos + float3(0, 0.4, 0)), 22.0);

				//float sdfValue = sdSphere(pos, float3(5.0 * sin(iTime), 3.0, 0), 8.0) + 7.0 * fbm_4(fbmCoord / 3.2);
				//float sphere = sdSphere(pos - _Sphere.xyz, _Sphere.w);
				return sdfValue;
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

			float3 getShading(float3 pos, float3 normal)
			{
				float3 result;
				//diffuse color
				float3 color = _MainColor.rgb;
				//directional light
				float3 light = (_LightColor * dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5) * _LightIntensity;
				//shadow
				float shadow = softShadow(pos, _WorldSpaceLightPos0, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;
				shadow = max(0.0, pow(shadow, _ShadowIntensity));
				//ambient occlusion
				float ao = ambientOcclusion(pos, normal);

				result = color * light * shadow * ao;
				return result;
			}

			float BeerLambert(float absorptionCoefficient, float distanceTraveled)
			{
				return exp(-absorptionCoefficient * distanceTraveled);
			}

			float GetLightAttenuation(float distanceToLight)
			{
				return 1.0 / pow(distanceToLight, _LightAttenuation);
			}

			float GetFogDensity(float3 position, float sdfDistance)
			{
				const float maxSDFMultiplier = 1.0;
				bool insideSDF = sdfDistance < 0.0;
				float sdfMultiplier = insideSDF ? min(abs(sdfDistance), maxSDFMultiplier) : 0.0;
				return sdfMultiplier;
				//return sdfMultiplier * abs(fbm_4(position / 6.0) + 0.5);
			}

			float GetLightVisiblity(in float3 rayOrigin, in float3 rayDirection, in float maxT, in int maxSteps, float marchSize) {
				float t = 0.0f;
				float lightVisiblity = 1.0f;
				float signedDistance = 0.0;
				for (int i = 0; i < maxSteps; i++) {
					t += marchSize;
					if (t > maxT) break;

					float3 position = rayOrigin + t * rayDirection;
					signedDistance = map(position);
					if (signedDistance < 0.0) {
						float coeff = 0.1;
						coeff *= GetFogDensity(position, signedDistance);
						lightVisiblity *= BeerLambert(coeff, marchSize);
					}
				}
				return lightVisiblity;
			}

			float4 getShading1(float3 ro, float3 rd, float depth)
			{
				float volumeDepth = 0.0f;
				float opaqueVisibility = 1.0f;
				const float marchSize = 0.6f;
				float3 volumetricColor = 0.0;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					volumeDepth += marchSize;
					if (volumeDepth > _MaxDistance || volumeDepth > depth) {
						break;
					}

					float3 pos = ro + volumeDepth * rd;
					if (map(pos) < 0.0)
					{
						//opaqueVisibility -= 0.01;
						//opaqueVisibility = max(0, opaqueVisibility);

						float previousOpaqueVisibility = opaqueVisibility;
						opaqueVisibility *= BeerLambert(_AbsorptionCoefficient, marchSize);
						float absorptionFromMarch = previousOpaqueVisibility - opaqueVisibility;

						float lightDistance = length(_LightPos - pos);
						float3 lightColor = _LightColor * GetLightAttenuation(lightDistance);
						
						float3 lightDirection = pos - _LightPos;
						lightDirection = lightDirection / length(lightDirection);
						lightColor *= GetLightVisiblity(_LightPos, lightDirection, lightDistance, 25, marchSize * 1.3);

						//if (lightDistance < 10)
						//{
						//	lightColor.rgb = 1;
						//}
						//else {
						//	lightColor.rgb = 0;
						//}


						volumetricColor += absorptionFromMarch * lightColor;
					}
				}
				return float4(volumetricColor, 1 - opaqueVisibility);
			}

			fixed4 raymarching(float3 ro, float3 rd, float depth)
			{
				fixed4 result = fixed4(1, 1, 1, 1);
				float t = 0;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					if (t > _MaxDistance || t >= depth)
					{
						//environment
						result = fixed4(rd, 0);
						//result = fixed4(0,0,0,1);
						break;
					}

					float3 pos = ro + rd * t;

					float dist = map(pos);

					
					if (dist < _Accuracy) //hit
					{

						float3 normal = getNormal(pos);
						//float3 shading = getShading(pos, normal);
						//result = fixed4(shading, 1);

						float4 shading = getShading1(ro, rd, depth);
						result = fixed4(shading.xyz, shading.w);

						break;
					}

					t += dist;
				}

				return result;
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth *= length(i.ray);

				fixed3 col = tex2D(_MainTex, i.uv);
				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				fixed4 result = raymarching(rayOrigin, rayDirection, depth);
				
				//float3 st = float3(i.uv * _ScreenParams.xy, 0);
				//float fbm = fbm_4(st);
				//fixed4 color = fixed4(fbm, fbm, fbm, 1);
				//return color;

				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
