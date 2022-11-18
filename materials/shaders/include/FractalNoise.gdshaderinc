// Shader Utils for Godot - https://github.com/henriksod/GodotShaderUtils

// Modified noise functions from Unity to Godot by Henrik Söderlund
// Code inherited from https://github.com/SebLague/Solar-System

// Problem to access these files when FractalNoise included from compute shader
// for some reason
#ifndef MATH_GDSHADERINC
	#include "res://materials/shaders/include/Math.gdshaderinc"
#endif

#ifndef SIMPLEXNOISE_GDSHADERINC
	#include "res://materials/shaders/include/SimplexNoise.gdshaderinc"
#endif

float simpleNoise_6(vec3 pos, int numLayers, float scale, float persistence, float lacunarity, float multiplier) {
	float noiseSum = 0.0;
	float amplitude = 1.0;
	float frequency = scale;
	for (int i = 0; i < numLayers; i ++) {
		noiseSum += snoise(pos * frequency) * amplitude;
		amplitude *= persistence;
		frequency *= lacunarity;
	}
	return noiseSum * multiplier;
}


float simpleNoise_3(vec3 pos, float scale, float multiplier) {
	const int numLayers = 4;
	const float persistence = .5;
	const float lacunarity = 2.0;

	return simpleNoise_6(pos, numLayers, scale, persistence, lacunarity, multiplier);
}

float simpleNoise_1(vec3 pos) {
	const float scale = 1.0;
	const float multiplier = 1.0;

	return simpleNoise_3(pos, scale, multiplier);
}

float simpleNoise_2(vec3 pos, vec4 params[3]) {
	// Extract parameters for readability
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;
	float verticalShift = params[2].x;

	// Sum up noise layers
	float noiseSum = 0.0;
	float amplitude = 1.0;
	float frequency = scale;
	for (int i = 0; i < numLayers; i ++) {
		noiseSum += snoise(pos * frequency + offset) * amplitude;
		amplitude *= persistence;
		frequency *= lacunarity;
	}
	return noiseSum * multiplier + verticalShift;
}

// Simple noise, but with smaller values dampened
float dampenedSimpleNoise(vec3 pos, vec4 params[3]) {
	// Parameters
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;
    float gain = 1.2;

	// Sum up noise layers
	float noiseSum = 0.0;
    float amplitude = 1.0;
    float frequency = scale;
    float weight = 1.0;

    for (int i = 0; i < numLayers; i ++) {
        float noiseVal = snoise(pos * frequency + offset) * .5 + .5;
        noiseVal *= weight;
        weight = saturate(noiseVal * gain);

        noiseSum += noiseVal * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
	return noiseSum * multiplier;
}

// Noise very roughly in range 0-1
float continentNoise(vec3 pos, vec4 params[3]) {
	// Parameters
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;
    float gain = 1.0;

	// Sum up noise layers
	float noiseSum = 0.0;
    float amplitude = 1.0;
    float frequency = scale;
    float weight = 1.0;

    for (int i = 0; i < numLayers; i ++) {
        float noiseVal = snoise(pos * frequency + offset) * .5 + .5;
        noiseVal *= weight;
        weight = saturate(noiseVal * gain);

        noiseSum += noiseVal * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
	return noiseSum;
}

float simpleNoise2_2(vec3 pos, vec4 params[3]) {
	// Parameters
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;

	// Sum up noise layers
    float noiseSum = 0.0;
    float amplitude = 1.0;
    float frequency = scale;
    for (int i = 0; i < numLayers; i ++) {
        float noiseVal = snoise(pos * frequency + offset);
        noiseSum += (noiseVal+1.0)*.5 * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    return noiseSum;
}

float simpleNoiseMusgrave(vec3 pos, vec4 params[3], float o) {
	// Parameters
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;

    // first octave
  
    float result = snoise(pos) + o;
    pos *= lacunarity;
    

	// Sum up noise layers
    float amplitude = 1.0;
    float frequency = scale * lacunarity;
    float weight = result;

    for (int i = 1; i < numLayers; i ++) {
        weight = min(1.0, weight);
        float signal = (snoise(pos * frequency) + o) * pow (abs(frequency), -persistence);
        result += weight * signal;
        weight *= signal;
        //amplitude *= persistence;
        frequency *= lacunarity;
        pos *= lacunarity;
    }

    return result * multiplier;
}

float ridgidNoise(vec3 pos, vec4 params[3]) {
	// Extract parameters for readability
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;
	float power = params[2].x;
    float gain = params[2].y;
    float verticalShift = params[2].z;

	// Sum up noise layers
	float noiseSum = 0.0;
    float amplitude = 1.0;
    float frequency = scale;
    float ridgeWeight = 1.0;

    for (int i = 0; i < numLayers; i ++) {
        float noiseVal = 1.0 - abs(snoise(pos * frequency + offset));
        noiseVal = pow(abs(noiseVal), power);
        noiseVal *= ridgeWeight;
        ridgeWeight = saturate(noiseVal * gain);

        noiseSum += noiseVal * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
	return noiseSum * multiplier + verticalShift;
}

// Sample the noise several times at small offsets from the centre and average the result
// This reduces some of the harsh jaggedness that can occur
float smoothedRidgidNoise(vec3 pos, vec4 params[3]) {
    vec3 sphereNormal = normalize(pos);
    vec3 axisA = cross(sphereNormal, vec3(0,1,0));
    vec3 axisB = cross(sphereNormal, axisA);

    float offsetDst = params[2].w * 0.01;
    float sample0 = ridgidNoise(pos, params);
    float sample1 = ridgidNoise(pos - axisA * offsetDst, params);
    float sample2 = ridgidNoise(pos + axisA * offsetDst, params);
    float sample3 = ridgidNoise(pos - axisB * offsetDst, params);
    float sample4 = ridgidNoise(pos + axisB * offsetDst, params);
    return (sample0 + sample1 + sample2 + sample3 + sample4) / 5.0;
}

float ridgidNoise2(vec3 pos, vec4 params[3]) {
	// Parameters
	vec3 offset = params[0].xyz;
	int numLayers = int(params[0].w);
	float persistence = params[1].x;
	float lacunarity = params[1].y;
	float scale = params[1].z;
	float multiplier = params[1].w;
	float power = params[2].x;

	// Sum up noise layers
	float noiseSum = 0.0;
    float amplitude = 1.0;
    float frequency = scale;
    float ridgeWeight = 1.0;

    for (int i = 0; i < numLayers; i ++) {
        float noiseVal = 1.0 - abs(snoise(pos * frequency + offset));
        noiseVal = (noiseVal * .5 + .5);
        noiseVal *= ridgeWeight;
        ridgeWeight = saturate(noiseVal);

        noiseSum += noiseVal * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    noiseSum = 1.0 - abs(noiseSum*2.0-1.0);
    noiseSum = pow(abs(noiseSum), power);
	return noiseSum * multiplier;
}

vec4 fractalNoiseGrad(vec3 pos, int numLayers, float scale, float persistence, float lacunarity) {
    vec4 noise = vec4(0.0);
    float amplitude = 1.0;
    float frequency = scale;
    for (int i = 0; i < numLayers; i ++) {
        noise += snoise_grad(pos * frequency) * amplitude;
        amplitude *= persistence;
        frequency *= lacunarity;
    }
    return noise;
}