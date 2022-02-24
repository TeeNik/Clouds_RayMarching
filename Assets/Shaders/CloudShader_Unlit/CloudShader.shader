Shader "Custom/CloudShader"
{
	Properties
	{
		_Density("Density", Range(0.0, 1.0)) = 0.04
		_Absortion("Absortion", Range(0.0, 20.0)) = 20.0

		_Coverage("Coverage", Range(0.0, 0.5)) = 0.42
		_Octaves("Octaves", Range(1, 8)) = 8
		_Offset("Offset", Vector) = (0.0, 0.005, 0.0, 0.0)
		_Frequency("Frequency", Float) = 3.0
		_Lacunarity("Lacunarity", Float) = 3.0

		[HideInInspector] _SphereRadius("SphereRadius", Float) = 0.5
		[HideInInspector] _SpherePos("SpherePos", Vector) = (0.0, 0.0, 0.0)

		[HideInInspector] _SpherePos("_CubeMinBound", Vector) = (0.0, 0.0, 0.0)
		[HideInInspector] _SpherePos("_CubeMaxBound", Vector) = (0.0, 0.0, 0.0)

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

			float _Density;
			float _Absortion;

			float _Coverage;
			int _Octaves;
			float3 _Offset;
			float _Frequency;
			float _Amplitude;

			float _Lacunarity;
			float _Persistence;

			float _SphereRadius;
			float3 _SpherePos;

			float3 _CubeMinBound;
			float3 _CubeMaxBound;

			int _JitterEnabled;
			int _FrameCount;

			struct appdata
			{
				float4 vertex : POSITION;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 wPos : TEXCOORD0;
			};

			v2f vert(appdata v)
			{
				v2f o;

				o.vertex = UnityObjectToClipPos(v.vertex);
				o.wPos = mul(unity_ObjectToWorld, v.vertex);

				return o;
			}

			half4 frag(v2f i) : SV_Target
			{
				float3 ro = _WorldSpaceCameraPos;
				float3 rd = normalize(i.wPos - ro);

				_FrameCount %= 8.0;
				float2 frameCount = float2(_FrameCount, -_FrameCount);

				float roJitter = IGN(i.vertex.xy + frameCount);
				float3 roJittered = ro + (rd * roJitter * _JitterEnabled);

				float3 lightDir = _WorldSpaceLightPos0.xyz;

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
				perlinInfo.offset = _Offset * _Time.y;
				perlinInfo.freq = _Frequency;
				perlinInfo.amp = _Amplitude;
				perlinInfo.lacunarity = _Lacunarity;
				perlinInfo.persistence = _Persistence;

				// cloud
				CloudInfo cloudInfo;
				cloudInfo.density = _Density;
				cloudInfo.absortion = _Absortion;

				float4 o = march(ro, roJittered, rd, lightDir, cubeInfo, perlinInfo, cloudInfo, sphereInfo);
				return half4(o.rgba);
			}

			ENDCG
		}
	}
}
