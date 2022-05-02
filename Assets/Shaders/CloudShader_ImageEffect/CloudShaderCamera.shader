Shader "Custom/CloudShaderCamera"
{
	Properties
	{
		_Density("Density", Range(0.0, 1.0)) = 0.04
		_Absortion("Absortion", Range(0.0, 20.0)) = 20.0

		_CloudColor("CloudColor", Vector) = (1.0, 1.0, 1.0)
		_ShadowColor("ShadowColor", Vector) = (0.0, 0.0, 0.0)
		_NoiseScale("NoiseScale", float) = 1.0

		_Coverage("Coverage", Range(0.0, 1.0)) = 0.42
		_Octaves("Octaves", Range(1, 8)) = 8
		_Offset("Offset", Vector) = (0.0, 0.005, 0.0, 0.0)
		_Frequency("Frequency", Float) = 3.0
		_Lacunarity("Lacunarity", Float) = 3.0

		_Volume("Volume", 3D) = "white" {}
		_Index("Index", Vector) = (0.0, 0.0, 0.0)

		[HideInInspector] _SphereRadius("SphereRadius", Float) = 0.5
		[HideInInspector] _SpherePos("SpherePos", Vector) = (0.0, 0.0, 0.0)
						   
		[HideInInspector] _CubeMinBound("CubeMinBound", Vector) = (0.0, 0.0, 0.0)
		[HideInInspector] _CubeMaxBound("CubeMaxBound", Vector) = (0.0, 0.0, 0.0)
						   
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
			uniform float4x4 _CamFrustum;
			uniform float4x4 _CamToWorld;
			uniform float _MaxDistance;

			float _Density;
			float _Absortion;

			float3 _CloudColor;
			float3 _ShadowColor;
			float _NoiseScale;

			float _Coverage;
			int _Octaves;
			float3 _Offset;
			float _Frequency;
			float _Amplitude;

			float _Lacunarity;
			float _Persistence;

			sampler3D _Volume;
			sampler2D _Background;
			float3 _Index;

			float _SphereRadius;
			float3 _SpherePos;

			float3 _CubeMinBound;
			float3 _CubeMaxBound;

			int _JitterEnabled;
			int _FrameCount;

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

			v2f vert(appdata v)
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

			half4 frag(v2f i) : SV_Target
			{

				float3 rd = normalize(i.ray.xyz);
				float3 ro = _WorldSpaceCameraPos;

				//float3 ro = _WorldSpaceCameraPos;
				//float3 rd = normalize(i.wPos - ro);

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
				cubeInfo.index = _Index;

				// perlin noise
				PerlinInfo perlinInfo;
				perlinInfo.cutOff = 1.0 - _Coverage;
				perlinInfo.octaves = _Octaves;
				perlinInfo.offset = _Offset/* * _Time.y*/;
				perlinInfo.freq = _Frequency;
				perlinInfo.amp = _Amplitude;
				perlinInfo.lacunarity = _Lacunarity;
				perlinInfo.persistence = _Persistence;
				perlinInfo.noise = _Volume;

				// cloud
				CloudInfo cloudInfo;
				cloudInfo.density = _Density;
				cloudInfo.absortion = _Absortion;
				cloudInfo.cloudColor = _CloudColor;
				cloudInfo.shadowColor = _ShadowColor;

				//float n = GetWorleyNoise3D(i.wPos);
				//n = fbm(i.wPos * 10);
				//return half4(n, n, n, 1);

				//float n = (PerlinNormal(float3(i.uv, 0) * 1.77 * _NoiseScale, perlinInfo.cutOff, perlinInfo.octaves, perlinInfo.offset,
				//	perlinInfo.freq, perlinInfo.amp, perlinInfo.lacunarity, perlinInfo.persistence)) * 0.5;
				//n -= fbm(i.wPos * 10) * 0.105;
				//return half4(n, n, n, 1);


				//float3 pos = (i.wPos - _CubeMinBound) / (_CubeMaxBound - _CubeMinBound);
				//fixed4 col = tex3D(_Volume, pos);
				//return half4(col.xyz, 1);

				float depth = LinearEyeDepth(tex2D(_CameraDepthTexture, i.uv).r);
				depth *= length(i.ray);

				fixed3 back = tex2D(_Background, i.uv);

				float4 o = march(ro, roJittered, rd, lightDir, depth, cubeInfo, perlinInfo, cloudInfo, sphereInfo);
				return half4(o.rgb * o.a + back * (1 - o.a), 1.0);
			}

			ENDCG
		}
	}
}
