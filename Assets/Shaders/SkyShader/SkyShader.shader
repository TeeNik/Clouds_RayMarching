Shader "Unlit/SkyShader"
{
    Properties
    {
        _NoiseTexture("NoiseTexture", 2D) = "white" {}
        _NoiseScale("NoiseScale", Vector) = (1.0, 1.0, 0.0)
        _NoiseRotSpeed("NoiseRotSpeed", Float) = 1.0
        _GlitterOffset("GlitterOffset", Float) = 1.0
        _GlitterColor("GlitterColor", Color) = (0.0, 0.0, 0.0, 1.0)

        _TopColor("TopColor", Color) = (0.0, 0.0, 0.0, 1.0)
        _BottomColor("BottomColor", Color) = (0.0, 0.0, 0.0, 1.0)
        _Power("Power", Float) = 1.0
        _Tilling("Tilling", Vector) = (1.0, 1.0, 0.0)
        _StarsAmount("StarsAmount", Float) = 1.0
        _StarsSize("StarsSize", Float) = 1.0

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

            #include "UnityCG.cginc"
            #include "../Utils/Random.cginc"

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
                float4 worldPos : TEXCOORD2;
                float3 viewDir : TEXCOORD3;
            };

            sampler2D _NoiseTexture;
            float4 _NoiseTexture_ST;

            float2 _NoiseScale;
            float _NoiseRotSpeed;
            float _GlitterOffset;
            float4 _GlitterColor;

            float4 _TopColor;
            float4 _BottomColor;
            float _Power;
            float3 _Tilling;
            float _StarsAmount;
            float _StarsSize;

            float Remap(float In, float2 InMinMax, float2 OutMinMax)
            {
                return OutMinMax.x + (In - InMinMax.x) * (OutMinMax.y - OutMinMax.x) / (InMinMax.y - InMinMax.x);
            }

            float2 TilingAndOffset(float2 UV, float2 Tiling, float2 Offset)
            {
                return UV * Tiling + Offset;
            }

            float3 TilingAndOffset(float3 UV, float3 Tiling, float3 Offset)
            {
                return UV * Tiling + Offset;
            }

            inline float2 VoronoiRandomVector(float2 UV, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y * +offset) * 0.5 + 0.5, cos(UV.x * offset) * 0.5 + 0.5);
            }

            void Voronoi(float2 UV, float AngleOffset, float CellDensity, out float Out, out float Cells)
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float t = 8.0;
                float3 res = float3(8.0, 0.0, 0.0);

                for (int y = -1; y <= 1; y++)
                {
                    for (int x = -1; x <= 1; x++)
                    {
                        float2 lattice = float2(x, y);
                        float2 offset = VoronoiRandomVector(lattice + g, AngleOffset);
                        float d = distance(lattice + offset, f);
                        if (d < res.x)
                        {
                            res = float3(d, offset.x, offset.y);
                            Out = res.x;
                            Cells = res.y;
                        }
                    }
                }
            }

            float3 Hue(float3 In, float Offset)
            {
                float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
                float4 P = lerp(float4(In.bg, K.wz), float4(In.gb, K.xy), step(In.b, In.g));
                float4 Q = lerp(float4(P.xyw, In.r), float4(In.r, P.yzx), step(P.x, In.r));
                float D = Q.x - min(Q.w, Q.y);
                float E = 1e-10;
                float3 hsv = float3(abs(Q.z + (Q.w - Q.y) / (6.0 * D + E)), D / (Q.x + E), Q.x);

                float hue = hsv.x + Offset / 360;
                hsv.x = (hue < 0)
                    ? hue + 1
                    : (hue > 1)
                    ? hue - 1
                    : hue;

                float4 K2 = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
                float3 P2 = abs(frac(hsv.xxx + K2.xyz) * 6.0 - K2.www);
                return hsv.z * lerp(K2.xxx, saturate(P2 - K2.xxx), hsv.y);
            }

            inline float3 VoronoiRandomVector3D(float3 UV, float offset) {
                float3x3 m = float3x3(15.27, 47.63, 99.41, 89.98, 95.07, 38.39, 33.83, 51.06, 60.77);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float3(sin(UV.y * +offset) * 0.5 + 0.5, cos(UV.x * offset) * 0.5 + 0.5, sin(UV.z * offset) * 0.5 + 0.5);
            }

            void Voronoi3D(float3 UV, float AngleOffset, float CellDensity, out float Out, out float Cells) {
                float3 g = floor(UV * CellDensity);
                float3 f = frac(UV * CellDensity);
                float3 res = float3(8.0, 8.0, 8.0);

                for (int y = -1; y <= 1; y++) {
                    for (int x = -1; x <= 1; x++) {
                        for (int z = -1; z <= 1; z++) {
                            float3 lattice = float3(x, y, z);
                            float3 offset = VoronoiRandomVector3D(g + lattice, AngleOffset);
                            float3 v = lattice + offset - f;
                            float d = dot(v, v);

                            if (d < res.x) {
                                res.y = res.x;
                                res.x = d;
                                res.z = offset.x;
                            }
                            else if (d < res.y) {
                                res.y = d;
                            }
                        }
                    }
                }

                Out = res.x;
                Cells = res.z;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = normalize(WorldSpaceViewDir(v.vertex));
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float4 pos = i.worldPos;
                pos = normalize(pos);
                float mappedPos = Remap(pos.y, float2(-1, 1), float2(0, 1));
                float power = pow(mappedPos, _Power);
                float4 col = lerp(_BottomColor, _TopColor, power);
                
                float3 tilledPos = TilingAndOffset(pos, _Tilling.xyz, float3(0, 0, 0));
                float noise;
                float cells;
                Voronoi3D(tilledPos, 100, _StarsAmount, noise, cells);
                noise = saturate(noise);
                noise = 1 - noise;
                noise = pow(noise, _StarsSize);
                
                float starFlicker = rand3dTo1d(pos + (_Time.y));
                noise *= starFlicker;
                return col + noise;
            }
            ENDCG
        }
    }
}
