shader_type spatial;
render_mode unshaded, depth_draw_never, depth_prepass_alpha;

#include "res://materials/shaders/include/Math.gdshaderinc"
#include "res://materials/shaders/include/Noise.gdshaderinc"

uniform sampler2D MainTex;

uniform float ScreenWidth = 1280.0;
uniform float ScreenHeight = 720.0;

uniform sampler2D BlueNoise;
uniform sampler2D BakedOpticalDepth;

uniform vec3 DirToSun = vec3(0.0, 1.0, 0.0);

uniform vec3 PlanetCentre = vec3(0);
uniform float AtmosphereRadius;
uniform float OceanRadius;
uniform float PlanetRadius;

// Paramaters
uniform int NumInScatteringPoints;
uniform int NumOpticalDepthPoints;
uniform float Intensity;
uniform vec3 ScatteringCoefficients;
uniform float DitherStrength;
uniform float DitherScale;
uniform float DensityFalloff;

varying vec2 vUv;
varying vec3 viewVector;

const vec2 vertices[3] = {vec2(-1,-1), vec2(3,-1), vec2(-1, 3)};

void vertex() {
	// Generate triangle in clip space
	POSITION = vec4(vertices[VERTEX_ID],0.0,1.0);
    UV = 0.5 * POSITION.xy + vec2(0.5, 0.5);
	vUv = UV;
	
	// View vector in world space
	viewVector = (INV_PROJECTION_MATRIX * vec4(UV * 2.0 - 1.0, 0.0, 1.0)).xyz;
	viewVector = (INV_VIEW_MATRIX * vec4(viewVector, 0.0)).xyz;
}

vec2 squareUV(vec2 uv) {
	float width = ScreenWidth;
	float height = ScreenHeight;
	float scale = 1000.0;
	float x = uv.x * width;
	float y = uv.y * height;
	return vec2(x/scale, y/scale);
}

float densityAtPoint(vec3 densitySamplePoint) {
	float heightAboveSurface = length(densitySamplePoint - PlanetCentre) - PlanetRadius;
	float height01 = heightAboveSurface / (AtmosphereRadius - PlanetRadius);
	float localDensity = exp(-height01 * DensityFalloff) * (1.0 - height01);
	return localDensity;
}

float opticalDepthBaked(vec3 rayOrigin, vec3 rayDir) {
	float height = length(rayOrigin - PlanetCentre) - PlanetRadius;
	float height01 = saturate(height / (AtmosphereRadius - PlanetRadius));

	// In order to avoid a black sphere appearing when the dot product is -1, I
	// add an epsilon value to uvX.
	const float epsilon = 0.002;
	float uvX = 1.0 - (dot(normalize(rayOrigin - PlanetCentre), rayDir) * .5 + .5) + epsilon;
	return texture(BakedOpticalDepth, vec2(uvX, height01)).r;
}

float opticalDepthBaked2(vec3 rayOrigin, vec3 rayDir, float rayLength) {
	vec3 endPoint = rayOrigin + rayDir * rayLength;
	float d = dot(rayDir, normalize(rayOrigin-PlanetCentre));
	float opticalDepth = 0.0;

	const float blendStrength = 1.5;
	float w = saturate(d * blendStrength + .5);
	
	float d1 = opticalDepthBaked(rayOrigin, rayDir) - opticalDepthBaked(endPoint, rayDir);
	float d2 = opticalDepthBaked(endPoint, -rayDir) - opticalDepthBaked(rayOrigin, -rayDir);

	opticalDepth = mix(d2, d1, w);
	return opticalDepth;
}

vec3 calculateLight(
	vec3 rayOrigin, vec3 rayDir, float rayLength, vec3 originalCol, vec2 uv
) {
	float blueNoise = textureLod(BlueNoise, squareUV(uv) * DitherScale, 0.0).r;
	blueNoise = (blueNoise - 0.5) * DitherStrength;
	
	vec3 inScatterPoint = rayOrigin;
	float stepSize = rayLength / float(NumInScatteringPoints - 1);
	vec3 inScatteredLight = vec3(0);
	float viewRayOpticalDepth = 0.0;

	for (int i = 0; i < NumInScatteringPoints; i ++) {
		float sunRayOpticalDepth = opticalDepthBaked(
			inScatterPoint + DirToSun * DitherStrength, DirToSun);
		float localDensity = densityAtPoint(inScatterPoint);
		viewRayOpticalDepth = opticalDepthBaked2(
			rayOrigin, rayDir, stepSize * float(i));
		vec3 transmittance = exp(
			-(sunRayOpticalDepth + viewRayOpticalDepth)
			* ScatteringCoefficients
		);

		// Only add light if we are not at the far back of the planet with respect to the direction
		// to sun. This removes unwanted artifacs appearing. However, it also cuts the far end
		// of the atmosphere a bit. There might be a better solution to get rid of the artifacts...
		if (dot(inScatterPoint, DirToSun) / PlanetRadius > -0.99) {
			inScatteredLight += localDensity * transmittance;
		}
		inScatterPoint += rayDir * stepSize;
	}
	
	inScatteredLight *= ScatteringCoefficients * Intensity * stepSize / PlanetRadius;
	inScatteredLight += blueNoise * 0.01;

	// Attenuate brightness of original col (i.e light reflected from planet surfaces)
	// This is a hacky mess, TODO: figure out a proper way to do this
	const float brightnessAdaptionStrength = 0.15;
	const float reflectedLightOutScatterStrength = 3.0;
	float brightnessAdaption = dot(inScatteredLight,vec3(1)) * brightnessAdaptionStrength;
	float brightnessSum = viewRayOpticalDepth * Intensity * reflectedLightOutScatterStrength + brightnessAdaption;
	float reflectedLightStrength = exp(-brightnessSum);
	float hdrStrength = saturate(dot(originalCol,vec3(1))/3.0-1.0);
	reflectedLightStrength = mix(reflectedLightStrength, 1.0, hdrStrength);
	vec3 reflectedLight = originalCol;

	vec3 finalCol = reflectedLight + inScatteredLight;
	
	return finalCol;
}

void fragment() {
	vec4 originalCol = texture(MainTex, SCREEN_UV);
	
	vec3 view_pos = depth(DEPTH_TEXTURE, SCREEN_UV, INV_PROJECTION_MATRIX);
	float linear_depth = -view_pos.z;

	// Distance from fragment point to camera?
	float viewLength = length(viewVector);

	linear_depth *= viewLength;
	
	vec3 rayPos = CAMERA_POSITION_WORLD;
	vec3 rayDir = normalize(viewVector);
	
	vec2 ocean_hit = raySphere(PlanetCentre, OceanRadius, rayPos, rayDir);
	float dstToOcean = ocean_hit.x;
	float dstToSurface = min(linear_depth, dstToOcean);
	
	vec2 hit = raySphere(PlanetCentre, AtmosphereRadius, rayPos, rayDir);
	float dstToAtmosphere = hit.x;
	float dstThroughAtmosphere = min(hit.y, dstToSurface - dstToAtmosphere);

	vec4 finalCol = originalCol;
	
	if (dstThroughAtmosphere > 0.0) {
		const float epsilon = 0.0001;
		vec3 pointInAtmosphere = rayPos + rayDir * (dstToAtmosphere + epsilon);
		
		vec3 light = calculateLight(
			pointInAtmosphere,
			rayDir,
			dstThroughAtmosphere - epsilon * 2.0,
			originalCol.rgb,
			SCREEN_UV
		);
		finalCol = vec4(light, 1.0);
	}

	ALBEDO = finalCol.rgb;
}
