float smin(float a, float b, float k)
{
	float res = exp(-k * a) + exp(-k * b);
	return -log(res) / k;
}

float sdPlane(float3 p, float4 n)
{
	return dot(p, n.xyz) + n.w;
}

// Sphere
// s: radius
float sdSphere(float3 p, float s)
{
	return length(p) - s;
}

// Box
// b: size of box in x/y/z
float sdBox(float3 p, float3 b)
{
	float3 d = abs(p) - b;
	return min(max(d.x, max(d.y, d.z)), 0.0) +
		length(max(d, 0.0));
}

float sdRoundBox(in float3 p, in float3 b, in float3 r)
{
	float3 q = abs(p) - b;
	return min(max(q.x, max(q.y, q.z)), 0) + length(max(q, 0)) - r;
}

float sdTorus(float3 p, float2 t)
{
	float2 q = float2(length(p.xz) - t.x, p.y);
	return length(q) - t.y;
}

// BOOLEAN OPERATORS //

// Union
float opU(float d1, float d2)
{
	return min(d1, d2);
}

// Subtraction
float opS(float d1, float d2)
{
	return max(-d1, d2);
}

// Intersection
float opI(float d1, float d2)
{
	return max(d1, d2);
}

float opSmoothUnion(float d1, float d2, float k) {
	float h = clamp(0.5 + 0.5 * (d2 - d1) / k, 0.0, 1.0);
	return lerp(d2, d1, h) - k * h * (1.0 - h);
}

float opSmoothSubtraction(float d1, float d2, float k) {
	float h = clamp(0.5 - 0.5 * (d2 + d1) / k, 0.0, 1.0);
	return lerp(d2, -d1, h) + k * h * (1.0 - h);
}

float opSmoothIntersection(float d1, float d2, float k) {
	float h = clamp(0.5 - 0.5 * (d2 - d1) / k, 0.0, 1.0);
	return lerp(d2, d1, h) + k * h * (1.0 - h);
}

// Mod Position Axis
float pMod1 (inout float p, float size)
{
	float halfsize = size * 0.5;
	float c = floor((p+halfsize)/size);
	p = fmod(p+halfsize,size)-halfsize;
	p = fmod(-p+halfsize,size)-halfsize;
	return c;
}

float4x4 rotateY(float angle)
{
	float c = cos(angle);
	float s = sin(angle);

	return float4x4(
		float4(c, 0, s, 0),
		float4(0, 1, 0, 0),
		float4(-s, 0, c, 0),
		float4(0, 0, 0, 1)
	);
}

/*
float opDisplace(in sdf3d primitive, in vec3 p)
{
	float d1 = primitive(p);
	float d2 = displacement(p);
	return d1 + d2;
}

float opTwist(in sdf3d primitive, in vec3 p, float k)
{
	float c = cos(k * p.y);
	float s = sin(k * p.y);
	mat2  m = mat2(c, -s, s, c);
	vec3  q = vec3(m * p.xz, p.y);
	return primitive(q);
}
*/