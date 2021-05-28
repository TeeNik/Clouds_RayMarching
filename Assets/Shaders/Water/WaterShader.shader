Shader "TeeNik/WaterShader"
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
				
				float m = 8.0;

				float x = sm(1.0, 2.0, m, t % m);
				float y = sm(1.0, 1.5, m, t % m) * (1.0 - sm(1.75, 1.95, m, t % m));

				float z = sm(2.1, 3.1, m, t % m);
				float w = sm(3.25, 4.25, m, t % m);

				return float4(x, y, z, w);
			}

			float4 getTimeSequence2()
			{
				float t = _Time.y * _TimeScale;
				float m = 8.0;
				float x = sm(4.5, 6.0, m, t % m) * (1.0 - sm(7.0, 7.5, m, t % m));

				return float4(x, 0.0, 0.0, 0.0);
			}


			float map(float3 pos)
			{
				float t = _Time.y * _TimeScale / 2;
				float period = max(0, (t % 2) - 1);

				float4 curve = getTimeSequence();
				float4 curve2 = getTimeSequence2();

				float octahedron = sdOctahedron(pos, 0.95);// -0.15 * fbm_4(pos * 2.25 + t);
				//float octahedron = sdOctahedron(mul(rotateX(2 * PI * t), float4(pos, 1.0)).xyz, 2.5) - 0.25 * fbm_4(pos * 2.25 + t);
				//float octahedron2 = sdOctahedron(mul(rotateY(2 * PI * t), float4(mul(rotateZ(PI / 4), float4(pos, 1.0)).xyz, 1.0)).xyz, 2.5) - 0.25 * fbm_4(pos * 2.25 + t);
				//return opSmoothUnion(octahedron, octahedron2, 0.5);

				//float p = sdTorus(opTwist(mul(rotateY( PI * t), float4(pos, 1.0)).xyz, 0.5), float2(2.5, .75));
				//return p - 0.25 * fbm_4(pos * 2.25 + t);

				float3 torusPoint1 = mul(rotateZ(PI / 4), float4(pos, 1.0)).xyz;
				torusPoint1 = mul(rotateY(5 * t), float4(torusPoint1, 1.0)).xyz;
				float torus1 = sdTorus(torusPoint1, float2(2.0 * sin(PI * curve.z), 0.5)) + 0.7 * fbm_4(torusPoint1 * 1.25 + t);
				//torus1 *= 0.0;

				float3 torusPoint2 = mul(rotateZ(-PI / 4), float4(pos, 1.0)).xyz;
				torusPoint2 = mul(rotateY(5 * t), float4(torusPoint2, 1.0)).xyz;
				float torus2 = sdTorus(torusPoint2, float2(2.0 * sin(PI * curve.w), 0.5)) + 0.7 * fbm_4(torusPoint2 * 1.25 + t);
				//torus2 *= ceil(curve.w);

				float radius = 3.0 * (abs(sin(curve.x * PI / 2 + PI / 2)));
				float3 sphere1Point = mul(rotateY(2 * PI * curve.x), float4(pos, 1.0)).xyz;
				float t1 = sdSphere(sphere1Point + float3(radius, 0.0, 0.0), curve.y * 0.3) - 0.25 * fbm_4(pos * 2.25 + t) * curve.y;
				t1 = opU(t1, sdSphere(sphere1Point + float3(-radius, 0.0, 0.0), curve.y * 0.3) - 0.25 * fbm_4(pos * 2.25 + t) * curve.y);


				float globe = sdSphere(pos, 2.75 * curve2.x) + fbm_4(pos * 1.5 + t * 1.75);
				//return globe;

				t1 = opU(t1, torus1);
				t1 = opU(t1, torus2);
				t1 = opU(t1, globe);

				return smin(octahedron, t1, 4.0);

				if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				{
					float modX = pMod1(pos.x, _ModInterval.x);
					float modY = pMod1(pos.y, _ModInterval.y);
					float modZ = pMod1(pos.z, _ModInterval.z);
				}

				float4 vs1 = cos(t * float4(0.87, 1.13, 1.2, 1.0) + float4(0.0, 3.32, 0.97, 2.85)) * float4(-1.7, 2.1, 2.37, -1.9);
				float4 vs2 = cos(t * float4(1.07, 0.93, 1.1, 0.81) + float4(0.3, 3.02, 1.15, 2.97)) * float4(1.77, -1.81, 1.47, 1.9);
				
				float4 sphere1 = float4(vs1.x, 0.0, vs1.y, 2.0);
				float4 sphere2 = float4(vs1.z, vs1.w, vs2.z, 1.9);
				float4 sphere3 = float4(vs2.x, vs2.y, vs2.w, 1.8);
				
				float sp1 = sdSphere(pos - sphere1.xyz, sphere1.w) + noise(pos * 1.0 + t * 1.75);
				float sp2 = sdSphere(pos - sphere2.xyz, sphere2.w) + noise(pos * 1.0 + t * 1.75);
				float sp3 = sdSphere(pos - sphere3.xyz, sphere3.w) + noise(pos * 1.0 + t * 1.25);
				
				float sp12 = opSmoothUnion(sp1, sp2, 0.5);
				float sp123 = opSmoothUnion(sp12, sp3, 0.5);
				//sp123 = opSmoothUnion(sp123, sphere, 0.5);
				return sp123;
			}

			float map2(float3 pos) 
			{
				float t = _Time.y * _TimeScale / 2;
				float3 curve = getTimeSequence();
				float radius = 3.0 * (sin(curve.x * PI / 2 + PI / 2));

				float sphere = sdSphere(pos, 5.75) + noise(pos * 1.0 + t * 1.75);
				float torus = sdTorus(pos, float2(radius, 0.55)) + fbm_4(pos * 1.25 + t);
				float octahedron = sdOctahedron(pos, 1.0);

				float value = clamp(sin(t), 0.0, 1.0);
				//float t1 = sphere * value + octahedron * (1.0 - value);
				float t1 = sphere * 0.0 + octahedron;

				float3 sphere1Point = mul(rotateY(2 * PI * curve.x), float4(pos, 1.0)).xyz;
				//float3 sphere1Point = float4(pos, 1.0).xyz;

				t1 = opU(t1, sdSphere(sphere1Point + float3(radius, 0.0, 0.0), 0.2 * (1.0 - curve.y)));
				t1 = opU(t1, sdSphere(sphere1Point + float3(-radius, 0.0, 0.0), 0.2 * (1.0 - curve.y)));

				return t1;

				//float sphere = distSphere(pos, 1.0) + noise(pos * 1.2 + vec3(-0.3) + iTime*0.2);
				//float sphere = sdSphere(pos, 0.45);
				//
				//sphere = smin(sphere, sdSphere(pos + float3(-0.4, 0.0, -1.0), 0.04), 5.0);
				//sphere = smin(sphere, sdSphere(pos + float3(-0.5, -0.75, 0.0), 0.05), 50.0);
				//sphere = smin(sphere, sdSphere(pos + float3(0.5, 0.7, 0.5), 0.1), 5.0);
				//
				//return sphere;
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

			float4 renderColor2(float3 ro, float3 rd, float3 color, float3 currPos)
			{
				float time = _Time.y * _TimeScale;
				//vec3 lightDir = normalize(vec3(1.0,0.4,0.0));
				float3 normal = getNormal2(currPos);
				float3 normal_distorted = getNormal2(currPos + rd * noise(currPos * 2.5 + time * 2.0) * 0.75);

				float ndotl = abs(dot(-rd, normal));
				float ndotl_distorted = (dot(-rd, normal_distorted)) * 0.5 + 0.5;
				float rim = pow(1.0 - ndotl, 3.0);
				float rim_distorted = pow(1.0 - ndotl_distorted, 6.0);

				//color = mix( color, normal*0.5+vec3(0.5), rim_distorted+0.15 );
				//color = mix( vec3(0.0,0.1,0.6), color, rim*1.5 );
				color = lerp(refract(normal, rd, 0.5) * 0.5 + float3(0.5, 0.5, 0.5), color, rim);
				//color = mix( vec3(0.1), color, rim );
				color += rim * 0.6;

				float3 light = (_LightColor * dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5) * _LightIntensity;
				color = float3(0.1, 0.1, 0.1) * light;

				float random = noise(currPos);
				float3 S = normalize(random * 2 - 1);
				float3 Ns = normalize(lerp(normal, S, 0.5));

				float n = noise(currPos * 1000 ) * 2 - 1;
				n *= dot(_WorldSpaceLightPos0, normal) * 0.5 + 0.5;
				n *= n;

				color += (n * 0.15);

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
				//float shadowVal = shadow(currPos - rd * 0.01, lightDir);
				float shadowVal = softShadow(currPos, _WorldSpaceLightPos0, _ShadowDistance.x, _ShadowDistance.y, _ShadowPenumbra) * 0.5 + 0.5;
				shadowVal = max(0.0, pow(shadowVal, _ShadowIntensity));
				float ao = ambientOcclusion(currPos - normal * 0.01, normal);

				float ndotl = abs(dot(-rd, normal));
				float ndotl_distorted = abs(dot(-rd, normal_distorted));
				float rim = pow(1.0 - ndotl, 6.0);
				float rim_distorted = pow(1.0 - ndotl_distorted, 6.0);

				color = lerp(color, normal * 0.5 + float3(0.5, 0.5, 0.5), rim_distorted + 0.1);
				color += rim;
				//color = normal;

				// refracted ray-march into the inside area
				color *= raymarching2(currPos, refract(rd, normal, 0.85), color, depth);

				color *= float3(lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao));

				return float4(1.0 - color, 0.5);
			}

			fixed4 raymarching(float3 ro, float3 rd, float depth, inout float3 outPos)
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
					outPos = pos;
					float dist = min(map(pos), map2(pos));
					if (dist < _Accuracy) //hit
					{
						if (map(pos) < map2(pos))
						{
							float4 shading = renderColor(ro, rd, pos, depth);
							result = fixed4(shading.xyz, shading.w);
							break;
						}
						else 
						{
							float4 shading = renderColor2(ro, rd, float3(1,1,1), pos);
							result = fixed4(shading.xyz, shading.w);
							break;
						}

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
				float3 color = float3(0.0, 0.0, 0.0);
				//raymarching2(rayOrigin, rayDirection, color, depth);
				//fixed4 result = fixed4(color, 0.5);
				
				float3 pos = float3(0.0, 0.0, 0.0);
				fixed4 result = raymarching(rayOrigin, rayDirection, depth, pos);
				//fixed3 col = tex2D(_MainTex, i.uv + (result.r / 5) * result.w);

				fixed3 back = fixed3(0.6, i.uv.x, 1.0) * 0.5;

				fixed3 col = tex2D(_MainTex, i.uv);

				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
