shader_type spatial;
render_mode unshaded, depth_draw_never, depth_prepass_alpha;

#include "res://materials/shaders/include/Math.gdshaderinc"
#include "res://materials/shaders/include/FractalNoise.gdshaderinc"
#include "res://materials/shaders/include/CellularNoise.gdshaderinc"
#include "res://materials/shaders/include/Triplanar.gdshaderinc"

#define R 1.1

uniform sampler2D MainTex;
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;

uniform float ZNear = 0.1;

uniform vec4 ColA : source_color;
uniform vec4 ColB : source_color;
uniform vec4 SpecularCol : source_color;
uniform float DepthMultiplier = 0.5;
uniform float AlphaMultiplier = 3;
uniform float Smoothness = 0.92;
uniform sampler2D WaveNormalA;
uniform sampler2D WaveNormalB;
uniform float WaveStrength = 0.15;
uniform float WaveNormalScale = 15.0;
uniform float WaveSpeed = 0.5;
uniform float ShoreWaveHeight = 0.1;
uniform float PlanetScale = 200.0;
uniform vec3 OceanCentre = vec3(0.0);
uniform float OceanRadius = 190.0;
uniform vec3 DirToSun = vec3(0.0, 1.0, 0.0);
uniform float SpecularIntensity = 0.5;
uniform sampler2D FoamNoiseTexture;
uniform vec4 FoamColor : source_color = vec4(1);
uniform float FoamNoiseScale = 1.0;
uniform float FoamFalloffDistance = 0.5;
uniform float FoamLeadingEdgeFalloff = 1.0;
uniform float FoamEdgeFalloffBias = 0.5;
uniform float RefractionScale = 1.0;

varying vec3 viewVector;

const vec2 vertices[3] = {vec2(-1,-1), vec2(3,-1), vec2(-1, 3)};

float wave(in vec2 uv, in vec2 center, in float radius) {
    vec2 s = uv - center;
    float r = length(s);
    float h = sin(r * 100.0 + float(TIME) * 5.0) * 0.1 * (radius - r);    
    if(r >= radius) {
        return 0.0;
    } else {
        return h;
	}
}

float computeH(in vec2 uv) {
    return wave(uv, vec2(0.0, 0.0), 0.9)
         + wave(uv, vec2(1.0, 0.0), 0.9)
         + wave(uv, vec2(0.5, 1.0), 0.9)
         + 0.5;
}

vec2 displacement(float h, vec2 delta) {
    vec2 beta = asin(sin(delta) / R);
    vec2 x = tan(delta - beta);
    return x*h;
}

float derivativeX(vec2 uv, float e) {
    float h = computeH(uv);
    float h1 = computeH(uv + vec2(e, 0.0));
    float dh = h1 - h;
    return dh / (e);
}

float derivativeY(vec2 uv, float e) {
    float h = computeH(uv - vec2(0.0, e));
    float h1 = computeH(uv + vec2(0.0, e));
    float dh = h1 - h;
    return dh / (2.0 * e);
}

vec2 derivative(vec2 uv, vec2 e) {
    return vec2(derivativeX(uv, e.x), derivativeY(uv, e.y));
}

void vertex() {
	// Generate triangle in clip space
	POSITION = vec4(vertices[VERTEX_ID],0.0,1.0);
    UV = 0.5 * POSITION.xy + vec2(0.5, 0.5);
	
	// View vector in world space
	viewVector = (INV_PROJECTION_MATRIX * vec4(UV * 2.0 - 1.0, 0.0, 1.0)).xyz;
	viewVector = (INV_VIEW_MATRIX * vec4(viewVector, 0.0)).xyz;
}

vec3 normal_from_depth(vec3 view_pos) {

	vec3 normal = normalize(cross(dFdx(view_pos), dFdy(view_pos)));
	
	return normal;
}

void fragment() {
	vec4 originalCol = texture(MainTex, SCREEN_UV);
	
	vec3 view_pos = depth(DEPTH_TEXTURE, SCREEN_UV, INV_PROJECTION_MATRIX);
	float linear_depth = -view_pos.z;

	// Distance from fragment point to camera?
	float viewLength = length(viewVector);

	linear_depth *= viewLength;
	
	// Simulate waves on shores
	float variedOceanRadius = OceanRadius - ShoreWaveHeight * sin(TIME + 0.5 * cos(TIME)); 
	
	vec3 rayPos = CAMERA_POSITION_WORLD;
	vec3 rayDir = viewVector / viewLength;
	
	vec2 hit = raySphere(OceanCentre, variedOceanRadius, rayPos, rayDir);
	float dstToOcean = hit.x;
	float dstThroughOcean = hit.y;
	vec3 rayOceanIntersectPos = rayPos + rayDir * dstToOcean - OceanCentre;
	
	float oceanDepth = dstThroughOcean - dstToOcean;
	
	// dst that view ray travels through ocean (before hitting terrain / exiting ocean)
	float oceanViewDepth = min(dstThroughOcean, linear_depth - dstToOcean);
	
	// Ocean normal
	vec3 oceanSphereNormal = normalize(rayOceanIntersectPos);
	
	// Water Refraction
	// https://gist.github.com/kmltml/2e2091c4ff2df84d26ac624ecc4beb14
	float h = computeH(SCREEN_UV);
	vec2 der = derivative(SCREEN_UV, vec2(1.0));
	vec2 delta = atan(der);
	vec2 refraction = RefractionScale * displacement(h, delta) / max(1.5, dstToOcean / 20.0);
	vec4 distortedOriginalCol = texture(MainTex, SCREEN_UV + refraction);
	
	vec4 finalCol = originalCol;
	float finalAlpha = 0.0;
	float alpha = 1.0;

	if (oceanViewDepth > 0.0) {

		vec3 clipPlanePos = rayPos + viewVector * ZNear;
		
		float dstAboveWater = length(clipPlanePos - OceanCentre) - variedOceanRadius;
		
		float t = 1.0 - exp(-oceanViewDepth / PlanetScale * DepthMultiplier);
		alpha =  1.0 - exp(-oceanViewDepth / PlanetScale * AlphaMultiplier);
		vec4 oceanCol = mix(ColA, ColB, t);
		
		vec4 params[3] = {
			vec4(0,0,0,1),	// offset (vec3), numLayers
			vec4(1,5,0.001,1), // persistence, lacunarity, scale, multiplier
			vec4(0,0,0,0) // verticalShift
		};
		float r1 = simpleNoise2_2(vec3(TIME * 0.0001) + oceanSphereNormal, params);
		float r2 = simpleNoise2_2(-vec3(TIME * 0.0001) + oceanSphereNormal, params);

		vec2 waveOffsetA = vec2(TIME * WaveSpeed * r1, TIME * WaveSpeed * r2);
		vec2 waveOffsetB = vec2(TIME * WaveSpeed * r2, TIME * WaveSpeed * r1);
		vec3 waveNormalA = triplanarNormalUDN(rayOceanIntersectPos, oceanSphereNormal, WaveNormalScale / PlanetScale, waveOffsetA, WaveNormalA);
		vec3 waveNormalB = triplanarNormalUDN(rayOceanIntersectPos, oceanSphereNormal, WaveNormalScale / PlanetScale, waveOffsetB, WaveNormalB);
		vec3 waveNormal = mix(waveNormalA, waveNormalB, 0.5);
		//waveNormal = normalize(mix(oceanSphereNormal, waveNormal, WaveStrength));
		waveNormal = normalize(oceanSphereNormal * waveNormal);

		float diffuseLighting = min(1.0, max(0.0, dot(oceanSphereNormal, DirToSun)));
		
		float specularAngle = acos(dot(reflect(DirToSun, waveNormal), rayDir));
		float specularExponent = specularAngle / (1.0 - Smoothness);
		float specularHighlight = exp(-specularExponent * specularExponent) * SpecularIntensity;
		
		oceanCol += specularHighlight;
		if (dstAboveWater > 0.0) {
			oceanCol *= SpecularCol;
		}
		oceanCol.rgb = saturate3(oceanCol.rgb);

		// Sample the mask
		float channelA = triplanarOffset(
			rayOceanIntersectPos,
			-oceanSphereNormal,
			FoamNoiseScale,
			waveOffsetA,
			FoamNoiseTexture).r; 
		float channelB = triplanarOffset(
			rayOceanIntersectPos,
			-oceanSphereNormal,
			FoamNoiseScale * 0.5,
			waveOffsetB,
			FoamNoiseTexture).b;  
				
		// Modify it to our liking
		float foamMask = (channelA + channelB) * 0.95;
		foamMask = pow(foamMask, 2);
		foamMask = saturate(foamMask);
		
		// Is this pixel in the leading edge?
		if(oceanViewDepth < FoamFalloffDistance * FoamLeadingEdgeFalloff)
		{
			// Modulate the surface alpha and the mask strength
			float leading = oceanViewDepth / (FoamFalloffDistance * FoamLeadingEdgeFalloff);
			//ALPHA = leading;
			foamMask *= leading;
		}
		
		// Calculate linear falloff value
		float falloff = 1.0 - (oceanViewDepth / FoamFalloffDistance) + FoamEdgeFalloffBias;

		// Color the foam
		vec3 edge = FoamColor.rgb * falloff;

		// Set the ocean color and depth
		finalCol = distortedOriginalCol * (1.0-alpha) + oceanCol * alpha;
		
		// Subtract mask value from foam gradient, then add the foam value to the final pixel color
		finalCol.rgb += saturate3(edge - vec3(foamMask));
		
		finalCol *= diffuseLighting;
		finalAlpha = 1.0;
	}

	ALBEDO = finalCol.rgb;
	ALPHA = finalAlpha;
}
