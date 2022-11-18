#[compute]

#version 450

#include "res://materials/shaders/include/Math.gdshaderinc"
#include "res://materials/shaders/include/SimplexNoise.gdshaderinc"
#include "res://materials/shaders/include/FractalNoise.gdshaderinc"

layout(local_size_x = 512) in;

// For some reason a PackedVector3Array into buffer does not translate to vec3[].
// I had to set it to a float array and extract each component individually, then assemble
// the vec3 for each invocation.
layout (set = 0, binding = 0, std430) restrict buffer Vertices {
	float data[]; // vec3
} vertices;

layout (set = 0, binding = 1) restrict buffer ParamsBlock { // TODO: uniform buffer
	float numVertices;
	float maxStrength;
} params;

vec3 perturb(vec3 pos) {
	float scale = 50.0;
	float fx = simpleNoise_6(pos * 1.0, 2, scale, .5, 2.0, 1.0);
	float fy = simpleNoise_6(pos * 2.0, 2, scale, .5, 2.0, 1.0);
	float fz = simpleNoise_6(pos * 3.0, 2, scale, .5, 2.0, 1.0);
	vec3 offset = vec3(fx, fy, fz);
	offset = smoothstep(-1.0,1.0,offset) * 2.0 -1.0;
	return offset;
}

void main() {
	if (gl_GlobalInvocationID.x >= int(params.numVertices)) {
        return;
    }
	
	float x = vertices.data[gl_GlobalInvocationID.x * 3];
	float y = vertices.data[gl_GlobalInvocationID.x * 3 + 1];
	float z = vertices.data[gl_GlobalInvocationID.x * 3 + 2];

	vec3 pos = normalize(vec3(x,y,z));

	float height = length(pos);

	vec3 offset = perturb(pos);
	vec3 newPos = pos + offset * params.maxStrength;

	newPos = normalize(newPos) * height;

	// Update vertices
	vertices.data[gl_GlobalInvocationID.x * 3]     = newPos.x;
	vertices.data[gl_GlobalInvocationID.x * 3 + 1] = newPos.y;
	vertices.data[gl_GlobalInvocationID.x * 3 + 2] = newPos.z;
}

