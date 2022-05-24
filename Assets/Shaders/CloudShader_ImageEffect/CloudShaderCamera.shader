Shader "Custom/CloudShaderCamera"
{
	Properties
	{
		_Density("Density", Range(0.0, 1.0)) = 0.04
		_Absortion("Absortion", Range(0.0, 20.0)) = 20.0

		_CloudColor("CloudColor", Vector) = (1.0, 1.0, 1.0)
		_ShadowColor("ShadowColor", Vector) = (0.0, 0.0, 0.0)

		_Coverage("Coverage", Range(0.0, 1.0)) = 0.42
		_Octaves("Octaves", Range(1, 8)) = 8
		_Offset("Offset", Vector) = (0.0, 0.005, 0.0, 0.0)
		_Frequency("Frequency", Float) = 3.0
		_Lacunarity("Lacunarity", Float) = 3.0

		_Volume("Volume", 3D) = "white" {}

		[HideInInspector] _JitterEnabled("JitterEnabled", Range(0, 1)) = 1
		[HideInInspector] _FrameCount("FrameCount", Int) = 0.0
						 
		[HideInInspector] _Amplitude("Amplitude", Float) = 0.5
		[HideInInspector] _Persistence("Persistence", Float) = 0.5
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
		Blend SrcAlpha OneMinusSrcAlpha

		Pass
		{
			CGPROGRAM

			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "CloudRaymarching.cginc"

			uniform sampler2D _CameraDepthTexture;
			uniform float _MaxDistance;

			float _Density;
			float _Absortion;

			float3 _CloudColor;
			float3 _ShadowColor;

			float _Coverage;
			int _Octaves;
			float3 _Offset;
			float _Frequency;
			float _Amplitude;

			float _Lacunarity;
			float _Persistence;

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

			#define LIGHT_COUNT 1
			float3 _lightColors[LIGHT_COUNT];
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
				PerlinInfo perlinInfo;
				perlinInfo.cutOff = 1.0 - _Coverage;
				perlinInfo.octaves = _Octaves;
				perlinInfo.freq = _Frequency;
				perlinInfo.amp = _Amplitude;
				perlinInfo.lacunarity = _Lacunarity;
				perlinInfo.persistence = _Persistence;
				perlinInfo.offset = _Offset;
				perlinInfo.detailsWeight = _DetailsWeight;

				// cloud
				CloudInfo cloudInfo;
				cloudInfo.density = _Density;
				cloudInfo.absortion = _Absortion;
				cloudInfo.cloudColor = _CloudColor;
				cloudInfo.shadowColor = _ShadowColor;
				cloudInfo.offset = _Offset * _Time.y;
				cloudInfo.volume = _Volume;
				cloudInfo.detailsVolume = _DetailsVolume;

				LightInfo lightInfo;
				lightInfo.lightDir = _WorldSpaceLightPos0.xyz;
				lightInfo.ambient = _CloudColor;


				for (int j = 0; j < LIGHT_COUNT; ++j)
				{
					lightInfo.lightSources[j].transform = _lightTransforms[j];
					lightInfo.lightSources[j].color = _lightColors[j];
				}

				//float n = worleyFbm(float3(i.uv, 0) * 1, 5);
				//float pfbm = lerp(1., perlinfbm(float3(i.uv * 1., 0), 4., 7), .5);
				//n = abs(pfbm * 2. - 1.); // billowy perlin noise
				//return half4(n, n, n, 1);

				//float n = GetWorleyNoise3D(i.wPos);
				//n = fbm(i.wPos * 10);
				//return half4(n, n, n, 1);

				//float n = (PerlinNormal(float3(i.uv, 0) * 1.77, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset,
				//	perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence)) * 0.5;
				//n -= fbm(i.wPos * 10) * 0.105;
				//return half4(n, n, n, 1);


				//float3 pos = (i.wPos - _CubeMinBound) / (_CubeMaxBound - _CubeMinBound);
				//fixed4 col = tex3D(_Volume, pos);
				//return half4(col.xyz, 1);

				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth *= length(i.ray);

				fixed3 back = tex2D(_MainTex, i.uv);

				float4 o = march(ro, roJittered, rd, lightInfo, depth, cubeInfo, perlinInfo, cloudInfo, sphereInfo);
				return half4(o.rgb * o.a + back * (1 - o.a), 1.0);
			}

			ENDCG
		}
	}
}
