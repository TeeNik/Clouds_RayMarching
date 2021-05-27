#define PI 3.14

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

float sdRoundCone(float3 p, float r1, float r2, float h)
{
	float2 q = float2(length(p.xy), p.z);

	float b = (r1 - r2) / h;
	float a = sqrt(1.0 - b * b);
	float k = dot(q, float2(-b, a));

	if (k < 0.0) return length(q) - r1;
	if (k > a * h) return length(q - float2(0.0, h)) - r2;

	return dot(q, float2(a, b)) - r1;
}

float sdCappedTorus(in float3 p, in float3 sc, in float ra, in float rb)
{
	p.x = abs(p.x);
	float k = (sc.y * p.x > sc.x * p.z) ? dot(p.xz, sc) : length(p.xz);
	return sqrt(dot(p, p) + ra * ra - 2.0 * ra * k) - rb;
}

float sdOctahedron(float3 p, float s)
{
	p = abs(p);
	float m = p.x + p.y + p.z - s;
	float3 q;
	if (3.0 * p.x < m) q = p.xyz;
	else if (3.0 * p.y < m) q = p.yzx;
	else if (3.0 * p.z < m) q = p.zxy;
	else return m * 0.57735027;

	float k = clamp(0.5 * (q.z - q.y + s), 0.0, s);
	return length(float3(q.x, q.y - s + k, q.z - k));
}

float sdCappedCylinder(float3 p, float r, float h)
{
	float2 d = abs(float2(length(p.xy), p.z)) - float2(h, r);
	return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
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

float smin(float a, float b, float k)
{
	float res = exp(-k * a) + exp(-k * b);
	return -log(res) / k;
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

float4x4 rotateX(float angle)
{
	float c = cos(angle);
	float s = sin(angle);

	return float4x4(
		float4(1, 0, 0, 0),
		float4(0, c, -s, 0),
		float4(0, s, c, 0),
		float4(0, 0, 0, 1)
		);
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

float4x4 rotateZ(float angle)
{
	float c = cos(angle);
	float s = sin(angle);

	return float4x4(
		float4(c, -s, 0, 0),
		float4(s, c, 0, 0),
		float4(0, 0, 1, 0),
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
*/
float3 opTwist(float3 p, float k)
{
	float c = cos(k * p.y);
	float s = sin(k * p.y);
	float2x2  m = float2x2(c, -s, s, c);
	float3  q = float3(mul(m, p.xz), p.y);
	return q;
}