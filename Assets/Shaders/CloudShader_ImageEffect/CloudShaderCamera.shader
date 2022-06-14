Shader "TeeNik/CloudShaderCamera"
{
	Properties
	{
	}

		SubShader
	{
		Tags
		{
			"Queue" = "Transparent"
			"IgnoreProjector" = "True"
			"RenderType" = "Transparent"
		}

		Cull Off
		ZWrite Off
		ZTest Always

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "CloudRaymarching.cginc"

			uniform sampler2D _CameraDepthTexture;

			float _Density;
			float _Absortion;

			float3 _CloudColor;
			float _CloudHeight;
			float3 _ShadowColor;

			float _Coverage;
			float3 _CloudVelocity;

			sampler3D _Volume;
			sampler3D _DetailsVolume;
			sampler2D _MainTex;

			float _SphereRadius;
			float3 _SpherePos;

			float3 _CubeMinBound;
			float3 _CubeMaxBound;

			int _JitterEnabled;
			int _FrameCount;

			float _DetailsWeight;

			float4 _lightColors[LIGHT_COUNT];
			float4 _lightTransforms[LIGHT_COUNT];

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
				float4 worldPos : TEXCOORD2;
			};

			v2f vert(appdata v)
			{
				v2f o;
				v.vertex.z = 0.1;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				o.worldPos = mul(unity_ObjectToWorld, v.vertex);
				float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
				o.ray = mul(unity_CameraToWorld, float4(viewVector, 0));
				return o;
			}

			half4 frag(v2f i) : SV_Target
			{

				float3 rd = normalize(i.ray);
				float3 ro = _WorldSpaceCameraPos;

				_FrameCount %= 8.0;
				float2 frameCount = float2(_FrameCount, -_FrameCount);

				float roJitter = IGN(i.vertex.xy + frameCount);
				float3 roJittered = ro + (rd * roJitter * _JitterEnabled);

				// sphere
				SphereInfo sphereInfo;
				sphereInfo.pos = _SpherePos;
				sphereInfo.radius = _SphereRadius;

				//cube
				CubeInfo cubeInfo;
				cubeInfo.minBound = _CubeMinBound;
				cubeInfo.maxBound = _CubeMaxBound;

				// perlin noise
				//PerlinInfo perlinInfo;
				//perlinInfo.cutOff = 1.0 - _Coverage;
				//perlinInfo.octaves = _Octaves;
				//perlinInfo.freq = _Frequency;
				//perlinInfo.amp = _Amplitude;
				//perlinInfo.lacunarity = _Lacunarity;
				//perlinInfo.persistence = _Persistence;
				//perlinInfo.offset = _CloudVelocity;
				//perlinInfo.detailsWeight = _DetailsWeight;

				// cloud
				CloudInfo cloudInfo;
				cloudInfo.density = _Density;
				cloudInfo.absortion = _Absortion;
				cloudInfo.cloudColor = _CloudColor;
				cloudInfo.shadowColor = _ShadowColor;
				cloudInfo.offset = _CloudVelocity * _Time.y;
				cloudInfo.volume = _Volume;
				cloudInfo.height = _CloudHeight;
				cloudInfo.cutOff = 1.0 - _Coverage;
				cloudInfo.detailsVolume = _DetailsVolume;
				cloudInfo.detailsWeight = _DetailsWeight;

				LightInfo lightInfo;
				lightInfo.lightDir = _WorldSpaceLightPos0.xyz;
				lightInfo.ambient = _CloudColor;


				for (int j = 0; j < LIGHT_COUNT; ++j)
				{
					lightInfo.lightSources[j].transform = _lightTransforms[j];
					lightInfo.lightSources[j].color = _lightColors[j];
				}

				float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv).r);
				depth *= length(i.ray);

				fixed3 back = tex2D(_MainTex, i.uv);
				float4 o = march(ro, roJittered, rd, lightInfo, depth, cubeInfo, cloudInfo, sphereInfo);
				return half4(o.rgb + back * (1 - o.a), 1.0);
			}

			ENDCG
		}
	}
}
