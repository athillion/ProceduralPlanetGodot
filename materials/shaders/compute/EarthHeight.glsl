#[compute]

#version 450

#include "res://materials/shaders/include/Math.gdshaderinc"
#include "res://materials/shaders/include/SimplexNoise.gdshaderinc"
#include "res://materials/shaders/include/FractalNoise.gdshaderinc"

layout(local_size_x = 512, local_size_y = 1, local_size_z = 1) in;

// For some reason a PackedVector3Array into buffer does not translate to vec3[].
// I had to set it to a float array and extract each component individually, then assemble
// the vec3 for each invocation.
layout (set = 0, binding = 0, std430) readonly buffer Vertices {
	float data[]; // vec3
} vertices;

layout (set = 0, binding = 1, std430) writeonly buffer Heights {
	float data[];
} heights;

layout (set = 0, binding = 2) restrict buffer ParamsBlock {
	float numVertices;
	float oceanDepthMultiplier;
	float oceanFloorDepth;
	float oceanFloorSmoothing;
	float mountainBlend;
} params;

layout (set = 0, binding = 3) restrict buffer NoiseParamsBlock {
	vec4 noiseParams_continents[3];
	vec4 noiseParams_mask[3];
	vec4 noiseParams_mountains[3];
} noise_params;

void main() {
	if (gl_GlobalInvocationID.x >= int(params.numVertices)) {
        return;
    }
	
	float x = vertices.data[gl_GlobalInvocationID.x * 3];
	float y = vertices.data[gl_GlobalInvocationID.x * 3 + 1];
	float z = vertices.data[gl_GlobalInvocationID.x * 3 + 2];

	vec3 pos = normalize(vec3(x,y,z));

	float continentShape = simpleNoise_2(pos, noise_params.noiseParams_continents);
	continentShape = smoothMax(continentShape, -params.oceanFloorDepth, params.oceanFloorSmoothing);

	if (continentShape < 0.0) {
		continentShape *= 1.0 + params.oceanDepthMultiplier;
	}

	float ridgeNoise = smoothedRidgidNoise(pos, noise_params.noiseParams_mountains);


	float mask = Blend(0.0, params.mountainBlend, simpleNoise_2(pos, noise_params.noiseParams_mask));
	// Calculate final height
	float finalHeight = 1.0 + continentShape * 0.01 + ridgeNoise * 0.01 * mask;

	// Set terrain data
	heights.data[gl_GlobalInvocationID.x] = finalHeight;
}




