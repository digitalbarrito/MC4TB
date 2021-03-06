#version 120
/* DRAWBUFFERS:02 */ //0=gcolor, 2=gnormal for normals

varying vec4 color;

uniform int isEyeInWater;
const int GL_LINEAR = 9729;
const int GL_EXP = 2048;
uniform int fogMode;

void main() {

	gl_FragData[0] = color;
	if (fogMode == GL_EXP) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
	} else if (fogMode == GL_LINEAR) {
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, clamp((gl_FogFragCoord - gl_Fog.start) * gl_Fog.scale, 0.0, 1.0));
	} else if (isEyeInWater == 1.0 || isEyeInWater == 2.0){
		gl_FragData[0].rgb = mix(gl_FragData[0].rgb, gl_Fog.color.rgb, 1.0 - clamp(exp(-gl_Fog.density * gl_FogFragCoord), 0.0, 1.0));
	}
    gl_FragData[1] = vec4(0.0); //fills normal buffer with 0.0, improves overall performance
}
