// Shader Utils for Godot - https://github.com/henriksod/GodotShaderUtils

// Modified noise functions from Unity to Godot by Henrik Söderlund
// Code inherited from https://github.com/SebLague/Solar-System

// Problem to access these files when Triplanar included from compute shader
// for some reason
#ifndef MATH_GDSHADERINC
	#include "res://materials/shaders/include/Math.gdshaderinc"
#endif

#ifndef TRIPLANAR_GDSHADERINC
#define TRIPLANAR_GDSHADERINC

vec3 UnpackNormal(vec4 packednormal)
{
    vec3 normal;
    normal.xy = packednormal.wy * 2.0 - 1.0;
    normal.z = sqrt(1.0 - normal.x * normal.x - normal.y * normal.y);
    return normal;
}

vec4 triplanar(vec3 vertPos, vec3 normal, float scale, sampler2D tex) {

	// Calculate triplanar coordinates
	vec2 uvX = vertPos.zy * scale;
	vec2 uvY = vertPos.xz * scale;
	vec2 uvZ = vertPos.xy * scale;

	vec4 colX = texture(tex, uvX);
	vec4 colY = texture(tex, uvY);
	vec4 colZ = texture(tex, uvZ);
	// Square normal to make all values positive + increase blend sharpness
	vec3 blendWeight = normal * normal;
	// Divide blend weight by the sum of its components. This will make x + y + z = 1
	blendWeight /= dot(blendWeight, vec3(1.0));
	return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
}

vec4 triplanarOffset(vec3 vertPos, vec3 normal, float scale, vec2 offset, sampler2D tex) {
	// Triplanar
	vec2 uvX = vertPos.zy * scale + offset;
	vec2 uvY = vertPos.xz * scale + offset;
	vec2 uvZ = vertPos.xy * scale + offset;
	
	vec4 colX = texture(tex, uvX);
	vec4 colY = texture(tex, uvY);
	vec4 colZ = texture(tex, uvZ);
	
	// Square normal to make all values positive + increase blend sharpness
	vec3 blendWeight = normal * normal;
	// Divide blend weight by the sum of its components. This will make x + y + z = 1
	blendWeight /= dot(blendWeight, vec3(1,1,1));
	return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
}

vec3 ObjectToTangentVector(vec4 tangent, vec3 normal, vec3 objectSpaceVector) {
	vec3 normalizedTangent = normalize(tangent.xyz);
	vec3 binormal = cross(normal, normalizedTangent) * tangent.w;
	mat3 rot = mat3 (normalizedTangent, binormal, normal);
	return rot * objectSpaceVector;
}

// Reoriented Normal Mapping
// http://blog.selfshadow.com/publications/blending-in-detail/
// Altered to take normals (-1 to 1 ranges) rather than unsigned normal maps (0 to 1 ranges)
vec3 blend_rnm(vec3 n1, vec3 n2)
{
	n1.z += 1.0;
	n2.xy = -n2.xy;

	return n1 * dot(n1, n2) / n1.z - n2;
}

// Sample normal map with triplanar coordinates
// Returned normal will be in obj/world space (depending whether pos/normal are given in obj or world space)
// Based on: medium.com/@bgolus/normal-mapping-for-a-triplanar-shader-10bf39dca05a
vec3 triplanarNormal(vec3 vertPos, vec3 normal, float scale, vec2 offset, sampler2D normalMap) {
	vec3 absNormal = abs(normal);

	// Calculate triplanar blend
	vec3 blendWeight = saturate3(pow(normal, vec3(4.0)));
	// Divide blend weight by the sum of its components. This will make x + y + z = 1
	blendWeight /= dot(blendWeight, vec3(1.0));

	// Calculate triplanar coordinates
	vec2 uvX = vertPos.zy * scale + offset;
	vec2 uvY = vertPos.xz * scale + offset;
	vec2 uvZ = vertPos.xy * scale + offset;

	// Sample tangent space normal maps
	// UnpackNormal puts values in range [-1, 1] (and accounts for DXT5nm compression)
	vec3 tangentNormalX = UnpackNormal(texture(normalMap, uvX));
	vec3 tangentNormalY = UnpackNormal(texture(normalMap, uvY));
	vec3 tangentNormalZ = UnpackNormal(texture(normalMap, uvZ));

	// Swizzle normals to match tangent space and apply reoriented normal mapping blend
	tangentNormalX = blend_rnm(vec3(normal.zy, absNormal.x), tangentNormalX);
	tangentNormalY = blend_rnm(vec3(normal.xz, absNormal.y), tangentNormalY);
	tangentNormalZ = blend_rnm(vec3(normal.xy, absNormal.z), tangentNormalZ);

	// Apply input normal sign to tangent space Z
	vec3 axisSign = sign(normal);
	tangentNormalX.z *= axisSign.x;
	tangentNormalY.z *= axisSign.y;
	tangentNormalZ.z *= axisSign.z;

	// Swizzle tangent normals to match input normal and blend together
	vec3 outputNormal = normalize(
		tangentNormalX.zyx * blendWeight.x +
		tangentNormalY.xzy * blendWeight.y +
		tangentNormalZ.xyz * blendWeight.z
	);

	return outputNormal;
}

vec3 triplanarNormalTangentSpace(vec3 vertPos, vec3 normal, float scale, vec4 tangent, sampler2D normalMap) {
	vec3 textureNormal = triplanarNormal(vertPos, normal, scale, vec2(0.0), normalMap);
	return ObjectToTangentVector(tangent, normal, textureNormal);
}

vec3 triplanarNormalTangentSpaceWithOffset(vec3 vertPos, vec3 normal, float scale, vec2 offset, vec4 tangent, sampler2D normalMap) {
	vec3 textureNormal = triplanarNormal(vertPos, normal, scale, offset, normalMap);
	return ObjectToTangentVector(tangent, normal, textureNormal);
}

// https://bgolus.medium.com/normal-mapping-for-a-triplanar-shader-10bf39dca05a#d655
vec3 triplanarNormalUDN(vec3 vertPos, vec3 normal, float scale, vec2 offset, sampler2D normalMap) {
	// Calculate triplanar blend
	vec3 blendWeight = saturate3(normal*normal*normal*normal);
	// Divide blend weight by the sum of its components. This will make x + y + z = 1
	blendWeight /= dot(blendWeight, vec3(1));
	
	// Triplanar uvs
	vec2 uvX = vertPos.zy * scale + offset; // x facing plane
	vec2 uvY = vertPos.xz * scale + offset; // y facing plane
	vec2 uvZ = vertPos.xy * scale + offset; // z facing plane
	// Tangent space normal maps
	vec3 tnormalX = UnpackNormal(texture(normalMap, uvX));
	vec3 tnormalY = UnpackNormal(texture(normalMap, uvY));
	vec3 tnormalZ = UnpackNormal(texture(normalMap, uvZ));
	// Swizzle tangent normals into world space and zero out "z"
	tnormalX = vec3(0.0, tnormalX.yx);
	tnormalY = vec3(tnormalY.x, 0.0, tnormalY.y);
	tnormalZ = vec3(tnormalZ.xy, 0.0);
	// Triblend normals and add to world normal
	vec3 worldNormal = normalize(
	    tnormalX.zyx * blendWeight.x +
	    tnormalY.xzy * blendWeight.y +
	    tnormalZ.xyz * blendWeight.z +
		normal
	    );
		
	return worldNormal;
}

#endif