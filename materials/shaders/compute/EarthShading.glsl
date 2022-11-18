#[compute]

#version 450

#include "res://materials/shaders/include/Math.gdshaderinc"
#include "res://materials/shaders/include/SimplexNoise.gdshaderinc"
#include "res://materials/shaders/include/FractalNoise.gdshaderinc"

layout(local_size_x = 512) in;

// For some reason a PackedVector3Array into buffer does not translate to vec3[].
// I had to set it to a float array and extract each component individually, then assemble
// the vec3 for each invocation.
layout (set = 0, binding = 0, std430) readonly buffer Vertices {
	float data[]; // vec3
} vertices;

layout (set = 0, binding = 1, std430) writeonly buffer ShadingData {
	float data[]; // vec4
} shadingData;

layout (set = 0, binding = 2) restrict buffer ParamsBlock { // TODO: uniform buffer
	float numVertices;
} params;

// Noise settings
layout (set = 0, binding = 3) restrict buffer NoiseParamsBlock { // TODO: uniform buffer
	vec4 noiseParams_detailWarp[3];
	vec4 noiseParams_detail[3];
	vec4 noiseParams_large[3];
	vec4 noiseParams_small[3];
	// Second warp
	vec4 noiseParams_warp2[3];
	vec4 noiseParams_noise2[3];
} noise_params;

void main() {
	if (gl_GlobalInvocationID.x >= int(params.numVertices)) {
        return;
    }
	
	float x = vertices.data[gl_GlobalInvocationID.x * 3];
	float y = vertices.data[gl_GlobalInvocationID.x * 3 + 1];
	float z = vertices.data[gl_GlobalInvocationID.x * 3 + 2];

	vec3 pos = normalize(vec3(x,y,z));

	// Large, low frequency noise
	float largeNoise = simpleNoise_2(pos, noise_params.noiseParams_large);
	float smallNoise = simpleNoise_2(pos, noise_params.noiseParams_small);
	
	// Warped detail noise
	float detailWarp = simpleNoise_2(pos, noise_params.noiseParams_detailWarp);
	float detailNoise = simpleNoise_2(pos + detailWarp * 0.1, noise_params.noiseParams_detail);
	
	// Second warp noise
	vec3 warpOffset2;
	warpOffset2.x = simpleNoise_2(pos, noise_params.noiseParams_warp2);
	warpOffset2.y = simpleNoise_2(pos + 99999.0, noise_params.noiseParams_warp2);
	warpOffset2.z = simpleNoise_2(pos - 99999.0, noise_params.noiseParams_warp2);
	float warpedNoise2 = simpleNoise_2(pos + warpOffset2 * 0.1, noise_params.noiseParams_noise2);
	
	// Set shading data
	shadingData.data[gl_GlobalInvocationID.x * 4] = largeNoise;
	shadingData.data[gl_GlobalInvocationID.x * 4 + 1] = detailNoise;
	shadingData.data[gl_GlobalInvocationID.x * 4 + 2] = smallNoise;
	shadingData.data[gl_GlobalInvocationID.x * 4 + 3] = warpedNoise2;
}
