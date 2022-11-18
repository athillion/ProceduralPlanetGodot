#[compute]

#version 450

#include "res://materials/shaders/include/Math.gdshaderinc"

#define PI 3.14159265359

layout(local_size_x = 16, local_size_y = 16) in;

layout(set = 0, binding = 0, rgba32f) writeonly uniform image2D target_image;

layout (set = 0, binding = 1, std430) restrict buffer ParamsBlock {
	float textureSize;
	float numOutScatteringSteps;
	float atmosphereRadius;
	float densityFalloff;
} params;

float densityAtPoint(vec2 densitySamplePoint) {
	float planetRadius = 1.0;
	vec2 planetCentre = vec2(0);

	float heightAboveSurface = length(densitySamplePoint - planetCentre) - planetRadius;
	float height01 = heightAboveSurface / (params.atmosphereRadius - planetRadius);
	float localDensity = exp(-height01 * params.densityFalloff) * (1.0 - height01);
	return localDensity;
}

float opticalDepth(vec2 rayOrigin, vec2 rayDir, float rayLength) {
	int numOpticalDepthPoints = int(params.numOutScatteringSteps);

	vec2 densitySamplePoint = rayOrigin;
	float stepSize = rayLength / float(numOpticalDepthPoints - 1);
	float opticalDepth = 0.0;

	for (int i = 0; i < numOpticalDepthPoints; i ++) {
		float localDensity = densityAtPoint(densitySamplePoint);
		opticalDepth += localDensity * stepSize;
		densitySamplePoint += rayDir * stepSize;
	}
	return opticalDepth;
}


float calculateOutScattering(vec2 inPoint, vec2 outPoint) {
	float planetRadius = 1.0;
	float skinWidth = planetRadius / 1000.0;
	

	float lightTravelDst = length(outPoint - inPoint);
	vec2 outScatterPoint = inPoint;
	vec2 rayDir = (outPoint - inPoint) / lightTravelDst;
	float stepSize = (lightTravelDst - skinWidth) / (params.numOutScatteringSteps);
	
	float outScatterAmount = 0.0;

	for (int i = 0; i < int(params.numOutScatteringSteps); i ++) {
		outScatterPoint += rayDir * stepSize;

		// height at planet surface = 0, at furthest extent of atmosphere = 1
		float height = length(outScatterPoint - 0.0) - planetRadius;

		float height01 = saturate(height / (params.atmosphereRadius - planetRadius));
		outScatterAmount += exp(-height01 * params.densityFalloff) * stepSize;
		
	}

	return outScatterAmount;
}

void main() {
	const float planetRadius = 1.0;

	ivec2 index = ivec2(gl_GlobalInvocationID.xy);
	ivec2 size = imageSize(target_image);
	if (index.x >= size.x || index.y >= size.y) {
		return;
	}

	vec2 uv = (vec2(index) + 0.5) / vec2(size);
	
	float height01 = uv.y;
	float angle = uv.x * PI;

	vec2 dir = vec2(sin(angle), cos(angle));
	float y = -2.0 * uv.x + 1.0;
	float x = sin(acos(y));
	dir = vec2(x,y);
	
	vec2 inPoint = vec2(0.0, mix(planetRadius, params.atmosphereRadius, height01));
	float dstThroughAtmosphere = raySphere(vec3(0.0), params.atmosphereRadius, vec3(inPoint,0.0), vec3(dir,0.0)).y;
	vec2 outPoint = inPoint + dir * raySphere(vec3(0.0), params.atmosphereRadius, vec3(inPoint,0.0), vec3(dir,0.0)).y;

	float outScattering = opticalDepth(inPoint + dir * 0.0001, dir, dstThroughAtmosphere-0.0002);
	
	imageStore(target_image, index, vec4(outScattering));
}