#version 120
/* DRAWBUFFERS:2 */

#define gbuffers_texturedblock
#include "shaders.settings"

varying vec4 color;
varying vec2 texcoord;
varying vec3 ambientNdotL;
uniform sampler2D texture;

void main() {

	vec4 albedo = texture2D(texture, texcoord.xy)*color;

	vec3 finalColor = pow(albedo.rgb,vec3(2.2)) * ambientNdotL.rgb;

	gl_FragData[0] = vec4(finalColor, albedo.a);	
}