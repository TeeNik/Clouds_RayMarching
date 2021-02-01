Shader "TeeNik/RaymarchingShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Accuracy("Accuracy", Range(0.001, 0.1)) = 0.01
		_MaxIterations("MaxIterations", Range(0, 300)) = 64
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
			#include "DistanceFunctions.cginc"

			sampler2D _MainTex;

			float _Accuracy;
			int _MaxIterations;

			uniform sampler2D _CameraDepthTexture;
			uniform float4x4 _CamFrustum;
			uniform float4x4 _CamToWorld;
			uniform float _MaxDistance;

			uniform float4 _Sphere;
			uniform float4 _Box;

			uniform float3 _LightDir;
			uniform fixed4 _MainColor;
			uniform float3 _ModInterval;

			uniform float4x4 _RotationMat;

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
				float sphere = sdSphere(pos - _Sphere.xyz, _Sphere.w);
				float box = sdRoundBox(pos - _Box.xyz, _Box.www, 0.5);
				float result = opSmoothSubtraction(sphere, box, 0.5);
				return result;
			}

			float map(float3 pos)
			{
				//if (_ModInterval.x > 0 && _ModInterval.y > 0 && _ModInterval.z > 0)
				//{
				//	float modX = pMod1(pos.x, _ModInterval.x);
				//	float modY = pMod1(pos.y, _ModInterval.y);
				//	float modZ = pMod1(pos.z, _ModInterval.z);
				//}
				//float3 boxPoint = mul(_RotationMat, float4(pos - _Box.xyz, 1)).xyz;
				//float torus = sdTorus(pos - _Sphere.xyz, float2(1, .5));

				float ground = sdPlane(pos, float4(0, 1, 0, 0));
				float bs = boxSphere(pos);
				
				return opU(ground, bs);

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

			float3 getShading(float3 pos, float3 normal)
			{
				//directional light
				float light = dot(_WorldSpaceLightPos0, normal);
				return light;
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
						float3 normal = getNormal(pos);
						float3 shading = getShading(pos, normal);

						result = fixed4(_MainColor.rgb * shading, 1);
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

				return fixed4(col * (1.0 - result.w) + result.xyz * result.w, 1.0);
            }
            ENDCG
        }
    }
}
