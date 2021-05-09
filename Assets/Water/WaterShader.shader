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

			float boxSphere(float3 pos)
			{
				//float3 boxPoint = mul(_RotationMat, float4(pos - _Box.xyz, 1)).xyz;
				float3 boxPoint = pos - _Box.xyz;
				float sphere = sdSphere(boxPoint - _Sphere.xyz, _Sphere.w);
				float box = sdRoundBox(boxPoint, _Box.www, 0.5);
				float result = opSmoothSubtraction(sphere, box, 0.5);
				return result;
			}

			float random(float3 st) {
				return frac(sin(dot(st.xyz,
					float3(12.9898, 78.233, 51.489))) *
					43758.5453123);
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

			float map(float3 pos)
			{
				float t = _Time.y * _TimeScale;

				float sphere = sdSphere(pos, 1.75) + noise(pos * 1.0 + t * 0.75);
				float t1 = sphere;

				t1 = smin(t1, sdSphere(pos + float3(1.8, 0.0, 0.0), 0.2), 2.0);
				t1 = smin(t1, sdSphere(pos + float3(-1.8, 0.0, -1.0), 0.2), 2.0);

				return t1;


				if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				{
					float modX = pMod1(pos.x, _ModInterval.x);
					float modY = pMod1(pos.y, _ModInterval.y);
					float modZ = pMod1(pos.z, _ModInterval.z);
				}

				float4 vs1 = cos(t * float4(0.87, 1.13, 1.2, 1.0) + float4(0.0, 3.32, 0.97, 2.85)) * float4(-1.7, 2.1, 2.37, -1.9);
				float4 vs2 = cos(t * float4(1.07, 0.93, 1.1, 0.81) + float4(0.3, 3.02, 1.15, 2.97)) * float4(1.77, -1.81, 1.47, 1.9);
				
				float4 sphere1 = float4(vs1.x, 0.0, vs1.y, 1.0);
				float4 sphere2 = float4(vs1.z, vs1.w, vs2.z, 0.9);
				float4 sphere3 = float4(vs2.x, vs2.y, vs2.w, 0.8);
				
				float sp1 = sdSphere(pos - sphere1.xyz, sphere1.w);
				float sp2 = sdSphere(pos - sphere2.xyz, sphere2.w);
				float sp3 = sdSphere(pos - sphere3.xyz, sphere3.w);
				
				float sp12 = opSmoothUnion(sp1, sp2, 0.5);
				float sp123 = opSmoothUnion(sp12, sp3, 0.5);
				return sp123;
				
				return sdSphere(pos - _Sphere.xyz, _Sphere.w);

				float torus = sdTorus(pos - _Torus.xyz, float2(_Torus.w, 0.4));

				float ground = sdPlane(pos, float4(0, 1, 0, 0));
				float bs = boxSphere(pos);
				float bt = opSmoothUnion(bs, torus, 0.5);
				
				return opU(ground, bt);

			}

			float map2(float3 pos) {

				//float sphere = distSphere(pos, 1.0) + noise(pos * 1.2 + vec3(-0.3) + iTime*0.2);
				float sphere = sdSphere(pos, 0.45);

				sphere = smin(sphere, sdSphere(pos + float3(-0.4, 0.0, -1.0), 0.04), 5.0);
				sphere = smin(sphere, sdSphere(pos + float3(-0.5, -0.75, 0.0), 0.05), 50.0);
				sphere = smin(sphere, sdSphere(pos + float3(0.5, 0.7, 0.5), 0.1), 5.0);

				return sphere;
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

			void renderColor2(float3 ro, float3 rd, inout float3 color, float3 currPos)
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
			}

			void raymarching2(float3 ro, float3 rd, inout float3 color, float depth)
			{
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
						renderColor2(ro, rd, color, pos);
						break;
					}
					t += dist;
				}
			}

			float3 renderColor(float3 ro, float3 rd, float3 currPos, float depth)
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
				float3 color2 = float3(0.5, 0.5, 0.5);
				raymarching2(currPos, refract(rd, normal, 0.85), color, depth);
				//renderRayMarch2( currPos, rayDirection, color2 );

				//color = color2;
				//color = normal;
				//color *= vec3(mix(0.25,1.0,shadowVal));

				color *= float3(lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao), lerp(0.8, 1.0, ao));
				return color;
			}

			float BeerLambert(float absorptionCoefficient, float distanceTraveled)
			{
				return exp(-absorptionCoefficient * distanceTraveled);
			}

			float GetLightAttenuation(float distanceToLight)
			{
				return 1.0 / pow(distanceToLight, 1);
			}

			float4 getShading1(in float3 ro, in float3 rd, float depth)
			{
				float volumeDepth = 0.0f;
				float opaqueVisibility = 1.0f;
				const float marchSize = _MarchSize;
				float3 volumetricColor;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					volumeDepth += marchSize;
					if (volumeDepth > _MaxDistance) {
						break;
					}

					float3 pos = ro + volumeDepth * rd;
					bool isInVolume = map(pos) < _Accuracy;
					if (isInVolume)
					{
						//opaqueVisibility -= 0.01;
						//opaqueVisibility = max(0, opaqueVisibility);

						float previousOpaqueVisibility = opaqueVisibility;
						opaqueVisibility *= BeerLambert(0.5, marchSize);
						float absorptionFromMarch = previousOpaqueVisibility - opaqueVisibility;
						
						//float lightDistance = _WorldSpaceLightPos0 - pos;
						//float3 lightColor = _LightColor * GetLightAttenuation(lightDistance);
						volumetricColor += absorptionFromMarch * _LightColor;
					}
				}
				return float4(volumetricColor, 1-opaqueVisibility);
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
						break;
					}

					float3 pos = ro + rd * t;
					float dist = map(pos);
					if (dist < _Accuracy) //hit
					{
						float4 shading = float4(renderColor(ro, rd, pos, depth), 0.5);
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
				
				//fixed3 col = tex2D(_MainTex, i.uv + (result.r / 5) * result.w);
				fixed3 col = tex2D(_MainTex, i.uv);

				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
