Shader "TeeNik/WaterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_ConcreteTexture("ConcreteTexture", 2D) = "white" {}

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

		_WallColor("WallColor", Color) = (1,1,1,1)
		_FogColor("FogColor", Color) = (1,1,1,1)
		_BackgroundColor("BackgroundColor", Color) = (1,1,1,1)
		_Offset("Offset", Vector) = (0,0,0)
		_OctohedronColor("OctohedronColor", Color) = (0.1, 0.1, 0.1, 1)

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

			sampler2D _MainTex;
			sampler2D _ConcreteTexture;

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

			uniform fixed4 _WallColor;
			uniform fixed4 _FogColor;
			uniform fixed4 _BackgroundColor;
			uniform float3 _Offset;
			uniform fixed4 _OctohedronColor;

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

			float hash(float n) { return frac(sin(n) * 753.5453123); }
			float noise(in float3 x)
			{
				float3 p = floor(x);
				float3 f = frac(x);
				f = f * f * (3.0 - 2.0 * f);

				float n = p.x + p.y * 157.0 + 113.0 * p.z;
				return lerp(lerp(lerp(hash(n + 0.0), hash(n + 1.0), f.x),
					lerp(hash(n + 157.0), hash(n + 158.0), f.x), f.y),
					lerp(lerp(hash(n + 113.0), hash(n + 114.0), f.x),
						lerp(hash(n + 270.0), hash(n + 271.0), f.x), f.y), f.z);
			}

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

			float sm(float a, float b, float m, float v)
			{
				return smoothstep(a / m, b / m, v / m);
			}

			float4 getTimeSequence()
			{
				float t = _Time.y * _TimeScale;
				
				float m = 9.0;

				float x = sm(1.0, 2.0, m, t % m);
				float y = sm(1.0, 1.5, m, t % m) * (1.0 - sm(1.75, 1.8, m, t % m));

				float z = sm(2.1, 2.6, m, t % m) * (1.0 - sm(2.6, 3.1, m, t % m)); //torus 1
				float w = sm(3.1, 3.6, m, t % m) * (1.0 - sm(3.6, 4.1, m, t % m)); //torus 2

				return float4(x, y, z, w);
			}

			float4 getTimeSequence2()
			{
				float t = _Time.y * _TimeScale;
				float m = 9.0;
				//octahedron
				float x = sm(1.7, 1.8, m, t % m) * (1.0 - sm(2.2, 2.4, m, t % m)) + sm(2.8, 2.9, m, t % m) * (1.0 - sm(3.25, 3.45, m, t % m))
					+ sm(3.8, 3.9, m, t % m) * (1.0 - sm(4.3, 4.5, m, t % m))
					+ sm(5.9, 6.0, m, t % m) * (1.0 - sm(7.0, 7.0, m, t % m));

				float y = sm(5.8, 6.8, m, t % m) * (1.0 - sm(7.7, 8.0, m, t % m)); //globe
				float z = sm(7.2, 7.2, m, t % m); //hiding octahedron
				
				float w = sm(4.2, 5.2, m, t % m) * (1.0 - sm(5.2, 6.2, m, t % m)); //double torus
				
				return float4(x, y, z, w);
			}

			float map(float3 p)
			{
				float result = 10000.0;
				float3 pos = p - _Offset;

				float t = _Time.y * _TimeScale / 2.0;

				float4 curve = getTimeSequence();
				float4 curve2 = getTimeSequence2();

				if (ceil(curve2.x) > 0.0)
				{
					float octahedron = sdOctahedron(pos, 1.5 * curve2.x) + 0.15 * fbm_4(pos * 2.25 + t);
					result = opU(result, octahedron);
				}

				if (ceil(curve2.w > 0.0))
				{
					float3 tp = mul(rotateX(-PI / 4 * t), float4(pos, 1.0)).xyz;
					tp = mul(rotateZ(5 * t), float4(tp, 1.0)).xyz;
					float torus = sdTorus(tp, float2(2.5 * curve2.w, 0.5)) + 0.7 * fbm_4(tp * 1.25 + t);
				
					float3 tp2 = mul(rotateX(PI / 4 * t), float4(pos, 1.0)).xyz;
					tp2 = mul(rotateZ(-5 * t), float4(tp2, 1.0)).xyz;
					float torus2 = sdTorus(tp2, float2(3.25 * curve2.w, 0.5)) + 0.7 * fbm_4(tp2 * 1.25 + t);
				
					return opSmoothUnion(result, opSmoothUnion(torus, torus2, 1.0), 1.0);
				}

				if (ceil(curve.z) > 0.0)
				{
					float3 torusPoint1 = mul(rotateZ(PI / 4), float4(pos, 1.0)).xyz;
					torusPoint1 = mul(rotateY(5 * t), float4(torusPoint1, 1.0)).xyz;
					float torus1 = sdTorus(torusPoint1, float2(2.0 * curve.z, 0.5)) + 0.7 * fbm_4(torusPoint1 * 1.25 + t);
					return opSmoothUnion(result, torus1, 1.0);
				}
				
				if (ceil(curve.w) > 0.0)
				{
					float3 torusPoint2 = mul(rotateZ(-PI / 4), float4(pos, 1.0)).xyz;
					torusPoint2 = mul(rotateY(5 * t), float4(torusPoint2, 1.0)).xyz;
					float torus2 = sdTorus(torusPoint2, float2(2.0 * curve.w, 0.5)) + 0.7 * fbm_4(torusPoint2 * 1.25 + t);
					return opSmoothUnion(result, torus2, 1.0);
				}

				if (ceil(curve.y) > 0.0)
				{
					float radius = 3.0 * (abs(sin(curve.x * PI / 2 + PI / 2)));

					float4 vs1 = cos(7.5 * t * float4(0.87, 1.13, 1.2, 1.0) + float4(0.0, 3.32, 0.97, 2.85)) * float4(-1.7, 2.1, 2.37, -1.9) * (radius * 0.4);
					float4 vs2 = cos(7.5 * t * float4(1.07, 0.93, 1.1, 0.81) + float4(0.3, 3.02, 1.15, 2.97)) * float4(1.77, -1.81, 1.47, 1.9) * (radius * 0.4);

					float scale = curve.y * 0.5;
					float4 sphere1 = float4(vs1.x, 0.0, vs1.y, scale);
					float4 sphere2 = float4(vs1.z, vs1.w, vs2.z, scale);
					float4 sphere3 = float4(0.0, vs2.x, vs2.y, scale);
					float4 sphere4 = float4(vs2.w, vs2.x, 0.0, scale);

					float sp1 = sdSphere(pos - sphere1.xyz, sphere1.w) + 0.25 * fbm_4(pos * 2.25 + t) * curve.y;
					float sp2 = sdSphere(pos - sphere2.xyz, sphere2.w) + 0.25 * fbm_4(pos * 2.25 + t) * curve.y;
					float sp3 = sdSphere(pos - sphere3.xyz, sphere3.w) + 0.25 * fbm_4(pos * 2.25 + t) * curve.y;
					float sp4 = sdSphere(pos - sphere4.xyz, sphere4.w) + 0.25 * fbm_4(pos * 2.25 + t) * curve.y;

					float sp12 = opSmoothUnion(sp1, sp2, 1.0);
					float sp123 = opSmoothUnion(sp12, sp3, 1.0);
					float sp1234 = opSmoothUnion(sp123, sp4, 1.0);

					return opSmoothUnion(result, sp1234, 1.0);
				}

				if (ceil(curve2.y) > 0.0)
				{
					float globeScale = 3.0 * pow(curve2.y, 3);
					float noisePower = 1.5 * pow(curve2.y / 1.5, 2);
					float3 globePos = mul(rotateX(2 * PI * t), float4(pos, 1.0)).xyz;
					float globe = sdSphere(globePos, globeScale) + fbm_4(pos * noisePower + t * 5.0);
					return opU(result, globe);
				}

				return result;
			}

			float map2(float3 p, bool checkTime = false) 
			{
				float t = _Time.y * _TimeScale / 2;
				float3 curve = getTimeSequence();
				float3 curve2 = getTimeSequence2();
				float radius = 3.0 * (sin(curve.x * PI / 2 + PI / 2));
				float3 pos = p - _Offset;
				float octahedron = sdOctahedron(pos, 1.0);

				float result = 10000.0;

				if (checkTime & curve2.z >= 1.0)
				{
					return result;
				}

				result = octahedron;
				float3 sphere1Point = mul(rotateY(2 * PI * curve.x), float4(pos, 1.0)).xyz;
				//result = opU(result, sdSphere(sphere1Point + float3(radius, 0.0, 0.0), 0.3 * (1.0 - curve.y)));
				//result = opU(result, sdSphere(sphere1Point + float3(-radius, 0.0, 0.0), 0.3 * (1.0 - curve.y)));

				float4 vs1 = cos(7.5 * t * float4(0.87, 1.13, 1.2, 1.0) + float4(0.0, 3.32, 0.97, 2.85)) * float4(-1.7, 2.1, 2.37, -1.9) * (radius * 0.4);
				float4 vs2 = cos(7.5 * t * float4(1.07, 0.93, 1.1, 0.81) + float4(0.3, 3.02, 1.15, 2.97)) * float4(1.77, -1.81, 1.47, 1.9) * (radius * 0.4);

				float scale = 0.3 * (1.0 - curve.y);
				float4 sphere1 = float4(vs1.x, 0.0, vs1.y, scale);
				float4 sphere2 = float4(vs1.z, vs1.w, vs2.z, scale);
				float4 sphere3 = float4(0.0, vs2.x, vs2.y, scale);
				float4 sphere4 = float4(vs2.w, vs2.x, 0.0, scale);

				float sp1 = sdSphere(pos - sphere1.xyz, sphere1.w);
				float sp2 = sdSphere(pos - sphere2.xyz, sphere2.w);
				float sp3 = sdSphere(pos - sphere3.xyz, sphere3.w);
				float sp4 = sdSphere(pos - sphere4.xyz, sphere4.w);

				float sp12 = opSmoothUnion(sp1, sp2, 0.5);
				float sp123 = opSmoothUnion(sp12, sp3, 0.5);
				float sp1234 = opSmoothUnion(sp123, sp4, 0.5);

				result = opU(result, sp1234);
				return result;
			}

			float3 getFogColor()
			{
				float4 curve = getTimeSequence();
				float4 curve2 = getTimeSequence2();
				float value = max(max(max(curve.z, curve.w), curve2.y), curve2.w);
				float3 color = lerp(_FogColor, float3(1, 0, 0), value * value);
				return color;
			}

			float3 fog(float3 ro, float3 rd, in float3 rgb, in float distance)
			{
				const float a = 0.5;
				const float b = 0.45;
				const float e = 2.72;
				float fogAmount = (a / b) * pow(e, -ro.y * b) * (1.0 - pow(e, -distance * rd.y * b)) / rd.y;
				float3  fogColor = _FogColor;
				fogAmount = clamp(0, 1, fogAmount);
				return lerp(rgb, getFogColor(), fogAmount);
			}

			float mapRoom(float3 pos)
			{
				float3 p = pos;
				_ModInterval = float3(15, 1, 15);
				if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				{
					float modX = pMod1(p.x, _ModInterval.x);
					//float modY = pMod1(p.y, _ModInterval.y);
					float modZ = pMod1(p.z, _ModInterval.z);
				}

				float height = 10;
				//float result = 10000;
				float result = sdBox(p - float3(0, -0.5 * height, 0), float3(10, 0.5, 10));
				result = opU(result, sdBox(p - float3(0, height * 0.5, 0), float3(3, height, 3)));

				//for (int i = -10; i < 10; ++i)
				//{
				//	for (int j = -10; j < 10; ++j)
				//	{
				//		result = opU(result, sdBox(p - float3(i * 15, height * 0.5, j * 15), float3(3, height, 3)));
				//	}
				//}

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

			float3 getNormal2(float3 pos)
			{
				const float2 offset = float2(0.001, 0.0);
				float3 normal = float3(
					map2(pos + offset.xyy) - map2(pos - offset.xyy),
					map2(pos + offset.yxy) - map2(pos - offset.yxy),
					map2(pos + offset.yyx) - map2(pos - offset.yyx));
				return normalize(normal);
			}

			float3 getNormalRoom(float3 pos)
			{
				const float2 offset = float2(0.001, 0.0);
				float3 normal = float3(
					mapRoom(pos + offset.xyy) - mapRoom(pos - offset.xyy),
					mapRoom(pos + offset.yxy) - mapRoom(pos - offset.yxy),
					mapRoom(pos + offset.yyx) - mapRoom(pos - offset.yyx));
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
					float3 pos = ro + rd * t;
					float h = min(map(pos), map2(pos, true));
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

			float4 renderColor2(float3 ro, float3 rd, float3 color, float3 currPos)
			{
				float time = _Time.y * _TimeScale;
				float3 normal = getNormal2(currPos);
				float3 light = (_LightColor * dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5) * _LightIntensity;
				color = _OctohedronColor * light;

				float n = noise(currPos * 1000 ) * 2 - 1;
				n *= dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5;
				n *= n;

				color += (n * 0.15);

				return float4(color, 1.0);
			}

			float4 renderColorRoom(float3 ro, float3 rd, float3 currPos)
			{
				float3 normal = getNormalRoom(currPos);
				float3 light = (_LightColor * dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5) * _LightIntensity;
				float shadowVal = softShadow(currPos, _WorldSpaceLightPos0, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;
				shadowVal = max(0.0, pow(shadowVal, _ShadowIntensity));
				//float3 color = float3(0.75, 0.75, 0.75) * light * shadowVal;

				float3 lightPos = float3(0, 20, 0);
				float attenuation = 1.0 - length(currPos - lightPos) / 65;
				light *= attenuation;

				float3 color = _WallColor * light * shadowVal;
				
				float n = noise(currPos * 1000) * 2 - 1;
				n *= dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5;
				n *= n;
				color += (n * 0.05);
				//color += noise;

				return float4(color, 1.0);
			}

			fixed4 raymarching2(float3 ro, float3 rd, float3 color, float depth)
			{
				fixed4 result = fixed4(1, 1, 1, 0.0);
				float t = 0;
				for (int i = 0; i < _MaxIterations; ++i)
				{
					if (t > _MaxDistance || t >= depth)
					{
						//environment
						break;
					}

					float3 pos = ro + rd * t;
					float dist = map2(pos);
					if (dist < _Accuracy) //hit
					{
						result = fixed4(renderColor2(ro, rd, color, pos));
						break;
					}
					t += dist;
				}
				return result;
			}

			float4 renderColor(float3 ro, float3 rd, float3 currPos, float depth)
			{
				float time = _Time.y * _TimeScale;
				float3 color = float3(1.0, 1.0, 1.0);
				float3 lightDir = normalize(float3(1.0, 0.4, 0.0));
				float3 normal = getNormal(currPos);
				float3 normal_distorted = getNormal(currPos + noise(currPos * 1.5 + float3(0.0, 0.0, sin(time * 0.75))));
				float ao = ambientOcclusion(currPos - normal * 0.01, normal);

				float ndotl = abs(dot(-rd, normal));
				float ndotl_distorted = abs(dot(-rd, normal_distorted));
				float rim = pow(1.0 - ndotl, 6.0);
				float rim_distorted = pow(1.0 - ndotl_distorted, 6.0);

				color = lerp(color, normal * 0.5 + float3(0.5, 0.5, 0.5), rim_distorted + 0.1);
				color += rim;

				// refracted ray-march into the inside area
				fixed4 rm2 = raymarching2(currPos, refract(rd, normal, 0.85), color, depth);
				color *= rm2;

				color *= float3(lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao));

				return float4(1.0 - color, max(0.5, rm2.w));
			}

			fixed4 raymarchingBackground(float3 ro, float3 rd, float depth)
			{
				fixed4 result = _BackgroundColor;
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

					float3 pos = ro + rd * t;
					float dist = mapRoom(pos);
					if (dist < _Accuracy) //hit
					{
						float4 shading = renderColorRoom(ro, rd, pos);
						result = fixed4(shading.xyz, shading.w);
						dst = length(pos - ro);
						break;
					}
					t += dist;
				}
				result.xyz = fog(ro, rd, result.xyz, dst);
				return result;
			}

			fixed4 raymarching(float3 ro, float3 rd, float depth)
			{
				fixed4 result = fixed4(1, 1, 1, 0.0);
				float t = 0;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					if (t > _MaxDistance || t >= depth)
					{
						//environment
						result = fixed4(rd, 0);
						break;
					}

					float3 pos = ro + rd * t;
					//float m = map(pos);
					//float m2 = map2(pos, true);
					//float dist = min(m, m2);
					//if (dist < _Accuracy) //hit
					//{
					//	if (m < m2)
					//	{
					//		float4 shading = renderColor(ro, rd, pos, depth);
					//		result = fixed4(shading.xyz, shading.w);
					//		break;
					//	}
					//	else
					//	{
					//		float4 shading = renderColor2(ro, rd, float3(1, 1, 1), pos);
					//		result = fixed4(shading.xyz, shading.w);
					//		break;
					//	}
					//}


					float dist = map2(pos);
					if (dist < _Accuracy) //hit
					{
						float4 shading = renderColor2(ro, rd, float3(1, 1, 1), pos);
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

				float3 rayDirection = normalize(i.ray.xyz);
				float3 rayOrigin = _WorldSpaceCameraPos;
				
				fixed4 result = raymarching(rayOrigin, rayDirection, depth);

				fixed4 col = raymarchingBackground(rayOrigin, rayDirection, depth);
				if (result.w > 0.0 & result.w < 1.0)
				{
					col = tex2D(_MainTex, i.uv);
				}
				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
