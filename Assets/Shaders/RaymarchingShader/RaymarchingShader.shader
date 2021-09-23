Shader "TeeNik/RaymarchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Accuracy("Accuracy", Range(0.001, 0.1)) = 0.01
		_MaxIterations("MaxIterations", float) = 64
		_RandomBorder("RandomBorder", Range(0.0, 1.0)) = .99

		_LightColor("LightColor", Color) = (1,1,1,1)
		_LightIntensity("LightIntensity", float) = 1.0

		_ShadowDistance("ShadowDistance", Vector) = (0,0,0)
		_ShadowIntensity("ShadowIntensity", float) = 1.0
		_ShadowPenumbra("ShadowPenumbra", float) = 1.0

		_AOStepsize("AOStepsize", float) = 1.0
		_AOIterations("AOIterations", float) = 1.0
		_AOIntensity("AOIntensity", float) = 1.0

		_TimeScale("AOIntensity", Range(0.0, 1.0)) = 1.0

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

			float map(float3 pos)
			{
				if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				{
					float modX = pMod1(pos.x, _ModInterval.x);
					float modY = pMod1(pos.y, _ModInterval.y);
					float modZ = pMod1(pos.z, _ModInterval.z);
				}

				float t = _Time.y * _TimeScale;
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

			fixed4 raymarching(float3 ro, float3 rd, float depth, inout float3 pos)
			{
				fixed4 result = fixed4(0, 0, 0, 0);
				float t = 0;

				for (int i = 0; i < _MaxIterations; ++i)
				{
					if (t > _MaxDistance || t >= depth)
					{
						//environment
						//result = fixed4(rd, 0);
						result = fixed4(0,0,0,0);
						break;
					}

					pos = ro + rd * t;
					float dist = map(pos);
					
					if (dist < _Accuracy) //hit
					{
						float3 normal = getNormal(pos);
						float3 shading = getShading(pos, normal);
						result = fixed4(shading, 1.0);
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

				float3 hitPos;
				fixed4 result = raymarching(rayOrigin, rayDirection, depth, hitPos);
				if (result.w > 0.0)
				{
					float3 normal = getNormal(hitPos);
					float3 reflectedDir = normalize(reflect(rayDirection, normal));
					result += raymarching(hitPos + (reflectedDir * 0.01), reflectedDir, depth, hitPos);
				}

				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
