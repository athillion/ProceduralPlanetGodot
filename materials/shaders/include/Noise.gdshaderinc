
#ifndef NOISE_GDSHADERINC
#define NOISE_GDSHADERINC

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(11.9898, 78.233))) * 43758.5453);
}

float blueNoise(vec2 U) {
    float v = 0.;
    for (int k=0; k<9; k++)
        v += hash( U + vec2(float(k%3-1),float(k/3-1)) ); 
    return .65*( 1.125*hash(U)- v/8.) + .5;
}

#endif