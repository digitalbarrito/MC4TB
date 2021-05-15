#version 120
// Broken: damaged block wrong color, Slime entities due to blending mode. Parallax mapping causes issues with handheld enchant effects at some angles, lighting strike fix
// TODO: Free up buffer 1 completly, its still in use somewhere..
// Improve sky rendering, check land checks in composite0 and composite1
// Adjust movement for twisting_vines_plant, check tallgrass, improve soul torches, lanterns and campfires brightness since they cast less light
// maybe add chains to none diffuse

/* DRAWBUFFERS:0 */

#define gbuffers_terrain
#include "shaders.settings"

/* Don't remove me
const int gcolorFormat = RGBA16;
const int colortex1Format = RGB10_A2;
const int colortex2Format = RGBA16; //Entities etc
const int compositeFormat = R11F_G11F_B10F;
const int gaux1Format = RGBA16;
const int gaux2Format = R11F_G11F_B10F;
const int gaux3Format = R11F_G11F_B10F;		
const int gaux4Format = R11F_G11F_B10F;	
-----------------------------------------*/

varying vec4 color;
varying vec4 texcoord;
varying vec4 normal;
varying vec3 worldpos;
varying vec3 viewVector;
varying mat3 tbnMatrix;

uniform sampler2D texture;
//uniform sampler2D specular;
uniform sampler2D noisetex;

//encode normal in two channel (xy), emissive lightmap (z) and sky lightmap (w), blend mode must be disabled in shaders.properties for this to work without issues.
vec4 encode (vec3 n){
    return vec4(n.xy*inversesqrt(n.z*8.0+8.0) + 0.5, texcoord.zw);
}

vec3 RGB2YCoCg(vec3 c){
	return vec3( 0.25*c.r+0.5*c.g+0.25*c.b, 0.5*c.r-0.5*c.b +0.5, -0.25*c.r+0.5*c.g-0.25*c.b +0.5);
}
vec3 newnormal = normal.xyz;
#if nMap >= 1
#extension GL_ARB_shader_texture_lod : enable
uniform sampler2D normals;
varying float block;
bool isblock = block > 0.0 || block < 0.0; //workaround for 1.16 bugs on block entities
varying float dist;
varying vec4 vtexcoordam; // .st for add, .pq for mul
varying vec2 vtexcoord;

uniform ivec2 atlasSize; 
vec2 atlasAspect = vec2(atlasSize.y/float(atlasSize.x), atlasSize.x/float(atlasSize.y));

mat2 mipmap = mat2(dFdx(vtexcoord.xy*vtexcoordam.pq), dFdy(vtexcoord.xy*vtexcoordam.pq));	
vec4 readNormal(in vec2 coord){
	return texture2DGradARB(normals,fract(coord)*vtexcoordam.pq+vtexcoordam.st,mipmap[0],mipmap[1]);
}

vec4 calcPOM(vec4 albedo){
	vec2 newCoord = vtexcoord.xy*vtexcoordam.pq+vtexcoordam.st;
	#if nMap == 2
	if (dist < POM_DIST && viewVector.z < 0.0 && readNormal(vtexcoord.xy).a < 1.0){
		vec2 viewCorrection = max(vec2(vtexcoordam.q/vtexcoordam.p*atlasAspect.x,1.0), vec2(1.0,vtexcoordam.p/vtexcoordam.q*atlasAspect.y));
		const float res_stepths = 0.33 * POM_RES;
		vec2 pstepth = viewCorrection * viewVector.xy * POM_DEPTH / (-viewVector.z * POM_RES);
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

#if defined metallicRefl || defined polishedRefl
float calcNoise(vec2 coord){
	return sqrt(texture2D(noisetex, vec2(coord.x*1.25, coord.y*1.95)).x) * 0.45;
}

vec3 calcBump(vec2 coord){
	const vec2 deltaPos = vec2(0.25, 0.0);

	float h0 = calcNoise(coord);
	float h1 = calcNoise(coord + deltaPos.xy);
	float h2 = calcNoise(coord - deltaPos.xy);
	float h3 = calcNoise(coord + deltaPos.yx);
	float h4 = calcNoise(coord - deltaPos.yx);

	float xDelta = ((h1-h0)+(h0-h2));
	float yDelta = ((h3-h0)+(h0-h4));

	return vec3(vec2(xDelta,yDelta)*0.2, 0.8); //z = 1.0-0.5
}

vec3 calcParallax(vec3 pos){
	float getnoise = calcNoise(pos.xz);
	float height = 1.0;

	pos.xz += (getnoise * viewVector.xy) * height;
	
	return pos;
}
#endif

float encodeVec2(float x, float y){
    const vec2 constant1 = vec2(1.0, 256.0) / 65535.0;
    vec2 temp = floor(vec2(x,y) * 255.0);
	return temp.x*constant1.x+temp.y*constant1.y;
}
/*
uniform float frameTimeCounter;
float noise(){ //interleaved_gradientNoise
	return fract(52.9829189*fract(0.06711056*gl_FragCoord.x + 0.00583715*gl_FragCoord.y)+frameTimeCounter*51.9521);
}
*/
void main() {

	vec4 albedo = texture2D(texture, texcoord.xy)*color;
	#if nMap >= 1
 	if(isblock)albedo = calcPOM(albedo);
	#endif

	#if defined metallicRefl || defined polishedRefl
	bool isPolished = normal.a > 0.69 && normal.a < 0.71;
	bool isMetallic = normal.a > 0.89 && normal.a < 0.91;	
	#ifndef polishedRefl
		isPolished = false;
	#endif	
	#ifndef metallicRefl	
		isMetallic = false;
	#endif
	if(isMetallic || isPolished){
		vec3 bumpPos = worldpos;
		 	 bumpPos = calcParallax(bumpPos);
		vec3 bump = calcBump(bumpPos.xy);
		newnormal = normalize(bump * tbnMatrix);
	}
	#endif
	
	 albedo.a = (albedo.a > 0.1)?normal.a*0.5+0.5:0.0;

	//vec4 normalmat = clamp(noise()*exp2(-8.0)+encode(newnormal),0.0,1.0);	//filters albedo
	//vec4 normalmat = clamp(noise()/256.+encode(newnormal),0.,1.0);		//filters albedo
	vec4 normalmat = clamp(encode(newnormal),0.0,1.0);	
	gl_FragData[0] = vec4(encodeVec2(albedo.x,normalmat.x),encodeVec2(albedo.y,normalmat.y),encodeVec2(albedo.z,normalmat.z),encodeVec2(normalmat.w,albedo.w));
}