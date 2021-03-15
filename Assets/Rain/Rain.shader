Shader "Unlit/Rain"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_Size("Size", float) = 1
		_T("Time", float) = 1
		_Distortion("Distortion", range(-5, 5)) = 1
		_Blur("Blur", range(0, 1)) = 1
	}
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
			#define PI 3,14159
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float _Size, _T, _Distortion, _Blur;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

			float random(float2 p)
			{
				p = frac(p * float2(456.123, 759.32));
				p += dot(p, p + 78.624);
				return frac(p.x * p.y);
			}

			fixed4 frag(v2f i) : SV_Target
			{
				float t = fmod(_Time.y * 0 + _T, 7200);
				float4 col = 0;

				float2 aspect = float2(2, 1);
				float2 uv = i.uv * _Size * aspect;
				float timeOffset = t * 0.25;
				uv.y += timeOffset;
				float2 gv = frac(uv) - 0.5;
				float2 id = floor(uv);

				float n = random(id); // 0 1
				t += n * 2 * PI;

				float w = i.uv.y * 10;
				float x = (n - 0.5) * .8; // -.4 .4
				x += (0.4 - abs(x)) * sin(3 * w) * pow(sin(w), 6) * 0.45;

				float y = -sin(t + sin(t + sin(t) * 0.5)) * 0.45;
				y -= (gv.x - x) * (gv.x - x); //change shape of drop

				float2 dropPos = (gv - float2(x, y)) / aspect;
				float drop = smoothstep(.05, .03, length(dropPos));

				float2 trailPos = (gv - float2(x, timeOffset)) / aspect;
				trailPos.y = (frac(trailPos.y * 8) - 0.5) / 8;
				float trail = smoothstep(.03, .01, length(trailPos));
				float fogTrail = smoothstep(-0.05, 0.05, dropPos.y);
				fogTrail *= smoothstep(0.5, y, gv.y);
				fogTrail *= smoothstep(.05, .04, abs(dropPos.x));

				trail *= fogTrail;

				col += fogTrail * 0.5;
				col += trail;
				col += drop;

				float2 offset = drop * dropPos + trail * trailPos;

				//debug grid
				//if (gv.x > .48 || gv.y > .49) col = float4(1, 0, 0, 1);

				float blur = _Blur * 7 * (1.0 - fogTrail);
				col = tex2Dlod(_MainTex, float4(i.uv + offset * _Distortion, 0, blur));
				col *= 0.5;

				//col *= 0; col.rg = drop * dropPos * 10;

                return col;
            }
            ENDCG
        }
    }
}
