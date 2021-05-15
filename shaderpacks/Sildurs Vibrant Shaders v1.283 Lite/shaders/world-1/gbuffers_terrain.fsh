#version 120
#extension GL_ARB_shader_texture_lod : enable //This extension must always be enabled to prevent issues with amd linux drivers
/* DRAWBUFFERS:0 */

#define gbuffers_terrain
#include "/shaders.settings"

/* Don't remove me
const int gcolorFormat = RGBA16;
const int colortex1Format = RGB10_A2;
const int colortex2Format = RGBA16;
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA16;
const int gaux2Format = R11F_G11F_B10F;
const int gaux3Format = R11F_G11F_B10F;		
const int gaux4Format = R11F_G11F_B10F;	
-----------------------------------------*/

varying vec4 color;
varying vec4 texcoord;
varying vec4 normal;

uniform sampler2D texture;
//uniform sampler2D specular;

//encode normal in two channel (xy),torch and material(z) and sky lightmap (w)
vec4 encode (vec3 n){
    float p = sqrt(n.z*8+8);
    return vec4(n.xy/p + 0.5,texcoord.z,texcoord.w);
}

vec3 RGB2YCoCg(vec3 c){
		return vec3( 0.25*c.r+0.5*c.g+0.25*c.b, 0.5*c.r-0.5*c.b +0.5, -0.25*c.r+0.5*c.g-0.25*c.b +0.5);
}
vec3 newnormal = normal.xyz;
#if nMap >= 1
varying float block;
bool isblock = block > 0.0 || block < 0.0; //workaround for 1.16 bugs on block entities
uniform sampler2D normals;
varying float dist;
varying vec3 viewVector;
varying mat3 tbnMatrix;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

mat2 mipmap = mat2(dFdx(vtexcoord.xy*vtexcoordam.pq), dFdy(vtexcoord.xy*vtexcoordam.pq));	
vec4 readNormal(in vec2 coord){
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,mipmap[0],mipmap[1]);
}

vec4 calcPOM(vec4 albedo){
	vec2 newCoord = vtexcoord.xy*vtexcoordam.pq+vtexcoordam.st;
#if nMap == 2
	if (dist < POM_DIST && viewVector.z < 0.0 && readNormal(vtexcoord.xy).a < 1.0){
		const float res_stepths = 0.33 * POM_RES;
		vec2 pstepth = viewVector.xy * POM_DEPTH / (-viewVector.z * POM_RES);
		vec2 coord = vtexcoord.xy;
		for (int i= 0; i < res_stepths && (readNormal(coord.xy).a < 1.0-float(i)/POM_RES); ++i) coord += pstepth;
	
		newCoord = fract(coord.xy)*vtexcoordam.pq+vtexcoordam.st;
	}
#endif
	//vec4 specularity = texture2DGradARB(specular, newCoord, dcdx, dcdy);
	vec3 bumpMapping = texture2DGradARB(normals, newCoord, mipmap[0],mipmap[1]).rgb*2.0-1.0;
	newnormal = normalize(bumpMapping * tbnMatrix);

return albedo = texture2DGradARB(texture, newCoord, mipmap[0],mipmap[1])*color;
}
#endif

float encodeVec2(float x, float y){
    const vec2 constant1 = vec2(1.0, 256.0) / 65535.0;
    vec2 temp = floor(vec2(x,y) * 255.0);
	return temp.x*constant1.x+temp.y*constant1.y;
}

void main() {

	vec4 albedo = texture2D(texture, texcoord.xy)*color;
	#if nMap >= 1
 	if(isblock)albedo = calcPOM(albedo);
	#endif

	 albedo.a = (albedo.a > 0.1)?normal.a*0.5+0.5:0.0;

	vec4 normalmat = clamp(encode(newnormal),0.0,1.0);	
	gl_FragData[0] = vec4(encodeVec2(albedo.x,normalmat.x),encodeVec2(albedo.y,normalmat.y),encodeVec2(albedo.z,normalmat.z),encodeVec2(normalmat.w,albedo.w));
	//gl_FragData[2] = specularity;
}