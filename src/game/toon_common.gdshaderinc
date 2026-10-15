// The comic style's lighting, shared by toon.gdshader, ground.gdshader and terrain.gdshader
// (docs/reference/art-style.md, **Light and shading**): a light() that quantises the key
// light's NdotL into three bands, darkens the shadow band with a screen-space halftone, lays the
// cast shadow over them as the shadow band through a dot screen (shadow_cover()) and draws a
// hard-edged specular disc on glossy surfaces. The surface flags a mesh
// carries in UV2.y, and their effects, are in effects.gdshaderinc. There is no rim light: with the orthographic camera a fresnel rim falls
// under the ink outline, which does that job.
//
// The Compatibility renderer adds the shadow-casting key light in a pass of its own, already
// tonemapped and in sRGB, on top of the ambient light and the emission. Ambient light added
// that way lifts every band (most of all in blue) by more than the shadow band's whole tone, so
// the shaders that include this file set render_mode ambient_light_disabled and the bands below
// carry the whole lit colour: each band's tone is then exact for every tint.

#include "res://src/game/effects.gdshaderinc"

// The band edges on NdotL, and the width of their smoothstep.
const float LIT_EDGE = 0.55;
const float SHADOW_EDGE = 0.15;
const float BAND_SOFTNESS = 0.02;
// The key light's share in each band, linear: the art style's sRGB tones of the albedo (lit 1.0,
// mid 0.78, shadow 0.55 in the cool tint (0.82, 0.84, 1.0)) raised to 2.2, the shadow band's
// cool tint divided by the key light's warm colour (FFF4E0) so it stays cool, and the shadow
// band nudged up by eye to make up for the halftone dots in it.
const vec3 BAND_LIT = vec3(1.0);
const vec3 BAND_MID = vec3(0.58);
const vec3 BAND_SHADOW = vec3(0.29) * vec3(0.64, 0.67, 1.0) / vec3(1.0, 0.905, 0.745);

// The halftone: a dot grid turned 45 degrees, its period in pixels at 720p (scaled with the
// viewport height), the share of each cell a dot covers, and how much of the shadow band a dot
// takes away (linear: 0.12 of its sRGB tone).
const float HALFTONE_PERIOD = 4.0;
const float HALFTONE_COVERAGE = 0.35;
const float HALFTONE_DARKEN = 0.245;

// The cast shadow's penumbra: where the filtered shadow term runs from fully shadowed to fully
// lit, the window shadow_cover()'s dot screen is spread over: the term at which a pixel is all
// shadow, and at which it is all lit.
const float PENUMBRA_DARK = 0.0;
const float PENUMBRA_LIT = 1.0;

// Cel specular: the threshold on NdotH, and the strength of the white disc.
const float SPECULAR_EDGE = 0.92;
const float SPECULAR_STRENGTH = 0.35;

bool is_unlit(vec2 uv2) {
	return has_flag(surf_flags(uv2), FLAG_UNLIT);
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

// How much of a pixel the cast shadow covers: the halftone's grid thresholded by `shade`, the
// cast shadow's share there. Its dots grow from nothing (shade 0) until they merge and cover the
// whole cell (shade 1), so a soft shadow's edge is drawn as a dot screen, not a grey ramp.
// Antialiased over a pixel like halftone(), without derivatives.
float shadow_cover(vec2 frag_coord, float viewport_height, float shade) {
	float cells_per_px = 720.0 / (viewport_height * HALFTONE_PERIOD);
	vec2 p = frag_coord * cells_per_px;
	p = vec2(p.x + p.y, p.x - p.y) * 0.70710678;
	float d = length(fract(p) - 0.5);
	float radius = sqrt(shade) * (0.70710678 + cells_per_px) - 0.5 * cells_per_px;
	return 1.0 - smoothstep(radius - 0.5 * cells_per_px, radius + 0.5 * cells_per_px, d);
}

// Unlit surfaces take no light: their ALBEDO is black and their colour is all emission. The cast
// shadow (ATTENUATION, filtered across the shadow map's texels) does not scale NdotL, which would
// leave a fringe of the mid band along every shadow's edge: the bands are worked out from NdotL
// alone, and the shadow band, with its halftone, is laid over them through shadow_cover()'s dots.
void light() {
	if (!is_unlit(UV2)) {
		float ndl = dot(NORMAL, LIGHT);
		float half_soft = BAND_SOFTNESS * 0.5;
		float mid = smoothstep(SHADOW_EDGE - half_soft, SHADOW_EDGE + half_soft, ndl);
		float lit = smoothstep(LIT_EDGE - half_soft, LIT_EDGE + half_soft, ndl);
		float dots = halftone(FRAGCOORD.xy, VIEWPORT_SIZE.y);
		vec3 band = mix(mix(BAND_SHADOW, BAND_MID, mid), BAND_LIT, lit);
		band *= 1.0 - HALFTONE_DARKEN * (1.0 - mid) * dots;
		float shade = clamp((PENUMBRA_LIT - ATTENUATION) / (PENUMBRA_LIT - PENUMBRA_DARK), 0.0, 1.0);
		float cover = shadow_cover(FRAGCOORD.xy, VIEWPORT_SIZE.y, shade);
		band = mix(band, BAND_SHADOW * (1.0 - HALFTONE_DARKEN * dots), cover);
		DIFFUSE_LIGHT += band * LIGHT_COLOR / PI;
		if (has_flag(surf_flags(UV2), FLAG_GLOSSY)) {
			float disc = smoothstep(SPECULAR_EDGE - 0.005, SPECULAR_EDGE + 0.005, dot(NORMAL, normalize(LIGHT + VIEW)));
			SPECULAR_LIGHT += disc * lit * (1.0 - cover) * SPECULAR_STRENGTH * LIGHT_COLOR / PI;
		}
	}
}
