shader_type spatial;

uniform vec4 ShoreLow : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec2 HeightMinMax;
uniform float OceanLevel;
uniform float BodyScale;
uniform vec4 ShoreHigh : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 FlatLowA : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 FlatHighA : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 FlatLowB : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 FlatHighB : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 SteepLow : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform vec4 SteepHigh : source_color = vec4(0.000000, 0.000000, 0.000000, 1.000000);
uniform float FlatColBlend : hint_range(0, 3) = 1.5;
uniform float FlatColBlendNoise : hint_range(0, 1) = 0.30000001192093;
uniform float ShoreHeight : hint_range(0, 0.20000000298023) = 0.05000000074506;
uniform float ShoreBlend : hint_range(0, 0.20000000298023) = 0.02999999932945;
uniform float MaxFlatHeight : hint_range(0, 1) = 0.5;
uniform float SteepBands : hint_range(0, 20) = 8;
uniform float SteepBandStrength : hint_range(-1, 1) = 0.5;
uniform float SteepnessThreshold : hint_range(0, 1) = 0.5;
uniform float FlatToSteepBlend : hint_range(0, 0.30000001192093) = 0.10000000149012;
uniform float FlatToSteepNoise : hint_range(0, 0.20000000298023) = 0.10000000149012;
uniform float SnowLongitude : hint_range(0, 1) = 0.80000001192093;
uniform float UseSnowyPoles : hint_range(0, 1) = 0.0;
uniform vec4 SnowCol : source_color = vec4(1.000000, 1.000000, 1.000000, 1.000000);
uniform float SnowBlend : hint_range(0, 0.20000000298023) = 0.10000000149012;
uniform float SnowHighlight : hint_range(0, 2) = 1.20000004768372;
uniform float SnowNoiseA : hint_range(0, 10) = 5;
uniform float SnowNoiseB : hint_range(0, 10) = 4;
uniform float SnowSpecular : hint_range(0, 1) = 1;
uniform sampler2D NoiseTex;
uniform float NoiseScale = 1;
uniform float NoiseScale2 = 1;
uniform vec4 FresnelCol : source_color = vec4(1.000000, 1.000000, 1.000000, 1.000000);
uniform float FresnelStrengthNear = 2;
uniform float FresnelStrengthFar = 5;
uniform float FresnelPow = 2;
uniform float Glossiness : hint_range(0, 1) = 0.5;
uniform float Metallic : hint_range(0, 1) = 0;
uniform vec4 TestParams = vec4(0.000000, 0.000000, 0.000000, 0.000000);

// Varyings
varying float fresnel;
varying vec3 vVertPos;
varying vec3 vNormal;
varying vec2 vTerrainData1;
varying vec2 vTerrainData2;
varying vec3 vTangent;

vec4 triplanar(vec3 vertPos, vec3 normal, float scale, sampler2D tex) {
	// Triplanar
	vec2 uvX = vertPos.zy * scale;
	vec2 uvY = vertPos.xz * scale;
	vec2 uvZ = vertPos.xy * scale;
	
	vec4 colX = texture(tex, uvX);
	vec4 colY = texture(tex, uvY);
	vec4 colZ = texture(tex, uvZ);
	
	// Square normal to make all values positive + increase blend sharpness
	vec3 blendWeight = normal * normal;
	// Divide blend weight by the sum of its components. This will make x + y + z = 1
	blendWeight /= dot(blendWeight, vec3(1,1,1));
	return colX * blendWeight.x + colY * blendWeight.y + colZ * blendWeight.z;
}


float blend(float startHeight, float blendDst, float height) {
	return smoothstep(startHeight - blendDst / 2.0, startHeight + blendDst / 2.0, height);
}


float saturate(float value) {
	return min(max(value, 0.0), 1.0);
}


float remap01(float v, float minOld, float maxOld) {
	 return saturate((v-minOld) / (maxOld-minOld));
}

void vertex() {
	vVertPos = VERTEX;
	vNormal = NORMAL;
	vTerrainData1 = UV;
	vTerrainData2 = UV2;
	vTangent = TANGENT;
	
	// Fresnel (fade out when close to body)
	mat4 obj_to_world = MODEL_MATRIX;
	vec3 pos = VERTEX;
	vec3 normal = NORMAL;
	vec3 cam_pos_world = CAMERA_POSITION_WORLD;

	vec3 worldPos = (obj_to_world * vec4(pos, 1.0)).xyz;
	vec3 viewDir = normalize(worldPos - cam_pos_world);

	vec3 normWorld = normalize((obj_to_world * vec4(normal, 1.0)).xyz);

	vec3 bodyWorldCentre = (obj_to_world * vec4(0.0, 0.0, 0.0, 1.0)).xyz;

	float camRadiiFromSurface = (length(bodyWorldCentre - cam_pos_world) - BodyScale) / BodyScale;
	float fresnelT = smoothstep(0.0, 1.0, camRadiiFromSurface);
	float fresStrength = mix(FresnelStrengthNear, FresnelStrengthFar, fresnelT);

	fresnel = min(max(pow(dot(viewDir, normWorld) + 1.0, FresnelPow) * fresStrength, 0.0), 1.0);

}


void fragment() {
	
	vec3 pos = vVertPos;
	vec3 normal = vNormal;
	vec2 uv = vTerrainData1;
	
	// Calculate steepness: 0 where totally flat, 1 at max steepness
	vec3 sphereNormal = normalize(pos);
	float steepness = 1.0 - dot(sphereNormal, normal);
	steepness = remap01(steepness, 0.0, 0.65);
	
	// Calculate heights
	float terrainHeight = length(pos);
	float shoreHeight = mix(HeightMinMax.x, 1.0, OceanLevel);
	float aboveShoreHeight01 = remap01(terrainHeight, shoreHeight, HeightMinMax.y);
	float flatHeight01 = remap01(aboveShoreHeight01, 0.0, MaxFlatHeight);
	
	// Sample noise texture at two different scales
	vec4 texNoise = triplanar(pos, normal, NoiseScale, NoiseTex);
	vec4 texNoise2 = triplanar(pos, normal, NoiseScale2, NoiseTex);
	
	// Flat terrain colour A and B
	float flatColBlendWeight = blend(0.0, FlatColBlend, (flatHeight01 - 0.5) + (texNoise.b - 0.5) * FlatColBlendNoise);
	vec3 flatTerrainColA = mix(FlatLowA, FlatHighA, flatColBlendWeight).rgb;
	flatTerrainColA = mix(flatTerrainColA, (FlatLowA.rgb + FlatHighA.rgb) / 2.0, dot(texNoise.rgb, vec3(1,1,1))/3.0);
	vec3 flatTerrainColB = mix(FlatLowB, FlatHighB, flatColBlendWeight).rgb;
	flatTerrainColB = mix(flatTerrainColB, (FlatLowB.rgb + FlatHighB.rgb) / 2.0, dot(texNoise.rgb, vec3(1,1,1))/3.0);
	
	// Biome
	float biomeWeight = blend(TestParams.x, TestParams.y, uv.x);
	biomeWeight = blend(0.0, TestParams.z, pos.x + uv.x * TestParams.x + uv.y * TestParams.y);
	vec3 flatTerrainCol = mix(flatTerrainColA, flatTerrainColB, biomeWeight);
	
	// Shore
	float shoreBlendWeight = 1.0 - blend(ShoreHeight, ShoreBlend, flatHeight01);
	vec4 shoreCol = mix(ShoreLow, ShoreHigh, remap01(aboveShoreHeight01, 0.0, ShoreHeight));
	shoreCol = mix(shoreCol, (ShoreLow + ShoreHigh) / 2.0, texNoise.g);
	flatTerrainCol = mix(flatTerrainCol, shoreCol.rgb, shoreBlendWeight);

	// Steep terrain colour
	vec3 sphereTangent = normalize(vec3(-sphereNormal.z, 0.0, sphereNormal.x));
	vec3 normalTangent = normalize(normal - sphereNormal * dot(normal, sphereNormal));
	float banding = dot(sphereTangent, normalTangent) * 0.5 + 0.5;
	banding = round(banding * (SteepBands + 1.0)) / SteepBands;
	banding = (abs(banding - 0.5) * 2.0 - 0.5) * SteepBandStrength;
	vec3 steepTerrainCol = mix(SteepLow, SteepHigh, banding).rgb;
	//vec3 steepTerrainCol = mix(SteepLow, SteepHigh, aboveShoreHeight01 + banding).rgb;
	
	// Flat to steep colour transition
	float flatBlendNoise = (texNoise2.r - 0.5) * FlatToSteepNoise;
	float flatStrength = 1.0 - blend(SteepnessThreshold + flatBlendNoise, FlatToSteepBlend, steepness);
	float flatHeightFalloff = 1.0 - blend(MaxFlatHeight + flatBlendNoise, FlatToSteepBlend, aboveShoreHeight01);
	flatStrength *= flatHeightFalloff;
	
	// Snowy poles
	float snowLineNoise = uv.y * SnowNoiseA * 0.01 + (texNoise.b - 0.5) * SnowNoiseB * 0.01;
	float snowWeight = blend(SnowLongitude, SnowBlend, abs(pos.y + snowLineNoise)) * UseSnowyPoles;
	float snowSpeckle = 1.0 - texNoise2.g * 0.5 * 0.1;
	vec3 snowCol = SnowCol.rgb * mix(1.0, SnowHighlight, aboveShoreHeight01 + banding) * snowSpeckle;
	
	// Set surface colour
	vec3 compositeCol = mix(steepTerrainCol, flatTerrainCol, flatStrength);
	compositeCol = mix(compositeCol, snowCol, snowWeight);
	compositeCol = mix(compositeCol, FresnelCol.rgb, fresnel);
	ALBEDO = compositeCol;
	
	// Glossiness
	float glossiness = dot(compositeCol, vec3(1.0, 1.0, 1.0)) / 3.0 * Glossiness;
	glossiness = max(glossiness, snowWeight * SnowSpecular);
	ROUGHNESS = 1.0 - glossiness;
	METALLIC = Metallic;
	
}
