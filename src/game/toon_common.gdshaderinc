// The comic style's lighting, shared by toon.gdshader and ground.gdshader
// (docs/reference/art-style.md, **Light and shading**): a light() that quantises the key
// light, its shadow included, into three bands, darkens the shadow band with a screen-space
// halftone and draws a hard-edged specular disc on glossy surfaces; and the surface flags a
// mesh carries in UV2.y. There is no rim light: with the orthographic camera a fresnel rim falls
// under the ink outline, which does that job.
//
// The Compatibility renderer adds the shadow-casting key light in a pass of its own, already
// tonemapped and in sRGB, on top of the ambient light and the emission. The band values are
// therefore tuned by eye for the art style's three tones (lit 1.0, mid 0.78, shadow 0.55 and
// cool), not taken as linear factors.

// UV2.y: 0 lit, 1 unlit (emissive), 2 glossy.
const float FLAG_UNLIT = 1.0;
const float FLAG_GLOSSY = 2.0;

// The band edges on NdotL times the shadow term, and the width of their smoothstep.
const float LIT_EDGE = 0.55;
const float SHADOW_EDGE = 0.15;
const float BAND_SOFTNESS = 0.02;
// The key light's share in each band.
const vec3 BAND_LIT = vec3(0.62);
const vec3 BAND_MID = vec3(0.4);
const vec3 BAND_SHADOW = vec3(0.12) * vec3(0.82, 0.84, 1.0);

// The halftone: a dot grid turned 45 degrees, its period in pixels at 720p (scaled with the
// viewport height), the share of each cell a dot covers, and how much of the shadow band's
// light a dot takes away.
const float HALFTONE_PERIOD = 4.0;
const float HALFTONE_COVERAGE = 0.35;
const float HALFTONE_DARKEN = 0.6;

// Cel specular: the threshold on NdotH, and the strength of the white disc.
const float SPECULAR_EDGE = 0.92;
const float SPECULAR_STRENGTH = 0.35;

bool is_unlit(vec2 uv2) {
	return abs(uv2.y - FLAG_UNLIT) < 0.5;
}

// 1 inside a halftone dot at this pixel, 0 outside, antialiased over a pixel.
float halftone(vec2 frag_coord, float viewport_height) {
	float cells_per_px = 720.0 / (viewport_height * HALFTONE_PERIOD);
	vec2 p = frag_coord * cells_per_px;
	p = vec2(p.x + p.y, p.x - p.y) * 0.70710678;
	float d = length(fract(p) - 0.5);
	float radius = sqrt(HALFTONE_COVERAGE / PI);
	return 1.0 - smoothstep(radius - 0.5 * cells_per_px, radius + 0.5 * cells_per_px, d);
}

// Unlit surfaces take no light: their ALBEDO is black and their colour is all emission. The
// shadow term is stepped at 0.5 first: filtered across a shadow-map texel, it would cross the
// band edges and leave a fringe of the mid band along every shadow's edge.
void light() {
	if (!is_unlit(UV2)) {
		float ndl = dot(NORMAL, LIGHT) * step(0.5, ATTENUATION);
		float half_soft = BAND_SOFTNESS * 0.5;
		float mid = smoothstep(SHADOW_EDGE - half_soft, SHADOW_EDGE + half_soft, ndl);
		float lit = smoothstep(LIT_EDGE - half_soft, LIT_EDGE + half_soft, ndl);
		vec3 band = mix(mix(BAND_SHADOW, BAND_MID, mid), BAND_LIT, lit);
		band *= 1.0 - HALFTONE_DARKEN * (1.0 - mid) * halftone(FRAGCOORD.xy, VIEWPORT_SIZE.y);
		DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
		if (UV2.y > FLAG_GLOSSY - 0.5) {
			float disc = smoothstep(SPECULAR_EDGE - 0.005, SPECULAR_EDGE + 0.005, dot(NORMAL, normalize(LIGHT + VIEW)));
			SPECULAR_LIGHT += disc * lit * SPECULAR_STRENGTH * LIGHT_COLOR / PI;
		}
	}
}
