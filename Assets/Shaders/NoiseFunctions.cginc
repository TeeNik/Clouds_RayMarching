float hash(float p) { p = frac(p * 0.011); p *= p + 7.5; p *= p + p; return frac(p); }

float noise(float3 x) {
	const float3 step = float3(110, 241, 171);
	float3 i = floor(x);
	float3 f = frac(x);
	float n = dot(i, step);
	float3 u = f * f * (3.0 - 2.0 * f);
	return lerp(lerp(lerp(hash(n + dot(step, float3(0, 0, 0))), hash(n + dot(step, float3(1, 0, 0))), u.x),
		lerp(hash(n + dot(step, float3(0, 1, 0))), hash(n + dot(step, float3(1, 1, 0))), u.x), u.y),
		lerp(lerp(hash(n + dot(step, float3(0, 0, 1))), hash(n + dot(step, float3(1, 0, 1))), u.x),
			lerp(hash(n + dot(step, float3(0, 1, 1))), hash(n + dot(step, float3(1, 1, 1))), u.x), u.y), u.z);
}

float fbm(float3 x) {
	float v = 0.0;
	float a = 0.5;
	int NUM_NOISE_OCTAVES = 4;
	for (int i = 0; i < NUM_NOISE_OCTAVES; ++i) {
		v += a * noise(x);
		x = x * 2.0;
		a *= 0.5;
	}
	return v;
}

float pattern(in float3 p, float timeScale)
{
	float t = _Time.y * timeScale;
	float3 q = float3(fbm(p + float3(0.0, 0.0, 0.0) + t), fbm(p + float3(5.2, 1.3, 4.1) + t), fbm(p + float3(2.2, 5.7, 1.8) + t));

	float3 r = float3(fbm(p + 4.0 * q + float3(1.7, 9.2, 3.7)),
		fbm(p + 4.0 * q + float3(8.3, 2.8, 6.4)), fbm(p + 4.0 * q + float3(2.6, 3.5, 9.3)));

	return fbm(p + 4.0 * r);
}


