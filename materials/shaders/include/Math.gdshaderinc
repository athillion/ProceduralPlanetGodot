// Shader Utils for Godot - https://github.com/henriksod/GodotShaderUtils

#ifndef MATH_GDSHADERINC
#define MATH_GDSHADERINC

const float maxFloat = 3.402823466e+38;

float saturate(float value) {
	return min(max(value, 0.0), 1.0);
}

vec2 saturate2(vec2 value) {
	return min(max(value, 0.0), 1.0);
}

vec3 saturate3(vec3 value) {
	return min(max(value, 0.0), 1.0);
}

vec4 saturate4(vec4 value) {
	return min(max(value, 0.0), 1.0);
}

// Remap a value from one range to another
float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
	 return saturate(minNew + (v-minOld) * (maxNew - minNew) / (maxOld-minOld));
}

// Remap the components of a vector from one range to another
vec4 remap4(vec4 v, float minOld, float maxOld, float minNew, float maxNew) {
	 return saturate4(minNew + (v-minOld) * (maxNew - minNew) / (maxOld-minOld));//
}

// Remap a float value (with a known mininum and maximum) to a value between 0 and 1
float remap01(float v, float minOld, float maxOld) {
	 return saturate((v-minOld) / (maxOld-minOld));
}

// Remap a vec2 value (with a known mininum and maximum) to a value between 0 and 1
vec2 remap01_2(vec2 v, vec2 minOld, vec2 maxOld) {
	 return saturate2((v-minOld) / (maxOld-minOld));
}

// Smooth minimum of two values, controlled by smoothing factor k
// When k = 0, this behaves identically to min(a, b)
float smoothMin(float a, float b, float k) {
	 k = max(0.0, k);
	 // https://www.iquilezles.org/www/articles/smin/smin.htm
	 float h = max(0.0, min(1.0, (b - a + k) / (2.0 * k)));
	 return a * h + b * (1.0 - h) - k * h * (1.0 - h);
}

// Smooth maximum of two values, controlled by smoothing factor k
// When k = 0, this behaves identically to max(a, b)
float smoothMax(float a, float b, float k) {
	 k = min(0.0, -k);
	 float h = max(0.0, min(1.0, (b - a + k) / (2.0 * k)));
	 return a * h + b * (1.0 - h) - k * h * (1.0 - h);
}

float Blend(float startHeight, float blendDst, float height) {
	 return smoothstep(startHeight - blendDst / 2.0, startHeight + blendDst / 2.0, height);
}

vec3 depth(sampler2D tex, vec2 uv, mat4 inv_projection_matrix) {
	// Get depth value from DEPTH_TEXTURE
	float depth = texture(tex, uv).r;

	// Normalized Device Coordinates needs to be 0 to 1 in Z axis for Vulkan
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	
	// Convert between NDC and view space to get distance to camera
	vec4 view = inv_projection_matrix * vec4(ndc, 1.0);
	view.xyz /= view.w;

	return view.xyz; //-view.z;
}

// Returns vector (dstToSphere, dstThroughSphere)
// If ray origin is inside sphere, dstToSphere = 0
// If ray misses sphere, dstToSphere = maxValue; dstThroughSphere = 0
vec2 raySphere(vec3 sphereCentre, float sphereRadius, vec3 rayOrigin, vec3 rayDir) {
	vec3 offset = rayOrigin - sphereCentre;
	float a = 1.0; // Set to dot(rayDir, rayDir) if rayDir might not be normalized
	float b = 2.0 * dot(offset, rayDir);
	float c = dot (offset, offset) - sphereRadius * sphereRadius;
	float d = b * b - 4.0 * a * c; // Discriminant from quadratic formula

	// Number of intersections: 0 when d < 0; 1 when d = 0; 2 when d > 0
	if (d > 0.0) {
		float s = sqrt(d);
		float dstToSphereNear = max(0.0, (-b - s) / (2.0 * a));
		float dstToSphereFar = (-b + s) / (2.0 * a);

		// Ignore intersections that occur behind the ray
		if (dstToSphereFar >= 0.0) {
			return vec2(dstToSphereNear, dstToSphereFar - dstToSphereNear);
		}
	}
	// Ray did not intersect sphere
	return vec2(maxFloat, 0.0);
}

mat4 rotationMatrix(vec3 axis, float angle)
{
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    
    return transpose(mat4(vec4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0),
                vec4(oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0),
                vec4(oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0),
                vec4(0.0,                                0.0,                                0.0,                                1.0)));
}

#endif