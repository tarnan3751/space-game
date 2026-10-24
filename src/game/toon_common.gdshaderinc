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

// The faction tint of a rival colony's buildings (toon.gdshader's `rival`, MaterialKit.rival): a
// green faction at every tier. The army-orange accent turns teal, the core gold (the Gold tier's
// trim, the Crown's filigree, the gold glows) a verdigris green-gold, the violet roles (antimatter,
// the veins, the antimatter core's and the bright cores' glows) emerald, glows included, and the
// warm cream hull is cooled by RIVAL_COOL. Each role is a window on hue, full within its FULL and
// gone by its EDGE, over a saturation floor. The hues and saturations are of the vertex tint as
// the shader reads it, the stored sRGB value (measured: a window round the linear hue caught
// nothing): orange sits at hue 0.078, core gold at 0.110, hazard yellow at 0.139 (kept), the
// violets at 0.72 to 0.74 and crystal at 0.78 (kept). The glass, chrome and obsidian layers keep
// their colour, and so do the outlines (ink.gdshader) and the ground, which have no such uniform.
const float ORANGE_HUE = 0.078;
const float ORANGE_FULL = 0.012;
const float ORANGE_EDGE = 0.025;
const float TEAL_HUE = 0.47;
const float TEAL_VALUE = 0.8;
const float GOLD_HUE = 0.110;
const float GOLD_FULL = 0.010;
const float GOLD_EDGE = 0.020;
const float VERDIGRIS_HUE = 0.24;
const float VERDIGRIS_VALUE = 0.75;
const float VIOLET_HUE = 0.728;
const float VIOLET_FULL = 0.018;
const float VIOLET_EDGE = 0.032;
const float EMERALD_HUE = 0.4;
const float EMERALD_VALUE = 0.9;
const vec3 RIVAL_COOL = vec3(0.92, 0.97, 1.07);
// The layers that keep their colour: glass, chrome and obsidian (MaterialKit.Layer).
const float LAYER_GLASS = 10.0;
const float LAYER_CHROME = 17.0;
const float LAYER_OBSIDIAN = 18.0;

vec3 rgb_to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

// How much of a role a tint is: 1 within `full` of `centre` on the hue circle, 0 from `edge`.
float hue_window(float hue, float centre, float full, float edge) {
	float away = abs(fract(hue - centre + 0.5) - 0.5);
	return 1.0 - smoothstep(full, edge, away);
}

vec3 rival_tint(vec3 tint, vec2 uv2) {
	float layer = uv2.x;
	if (abs(layer - LAYER_GLASS) < 0.5 || abs(layer - LAYER_CHROME) < 0.5 || abs(layer - LAYER_OBSIDIAN) < 0.5) {
		return tint;
	}
	vec3 hsv = rgb_to_hsv(tint);
	float orange = hue_window(hsv.x, ORANGE_HUE, ORANGE_FULL, ORANGE_EDGE) * smoothstep(0.5, 0.7, hsv.y);
	float gold = hue_window(hsv.x, GOLD_HUE, GOLD_FULL, GOLD_EDGE) * smoothstep(0.5, 0.65, hsv.y);
	float violet = hue_window(hsv.x, VIOLET_HUE, VIOLET_FULL, VIOLET_EDGE) * smoothstep(0.22, 0.32, hsv.y);
	// Cream: a warm, faintly coloured light tint; white (a layer with colours of its own) and the
	// cool greys are left as they are.
	float cream = smoothstep(0.02, 0.04, hsv.y) * (1.0 - smoothstep(0.2, 0.3, hsv.y))
		* (1.0 - smoothstep(0.15, 0.2, hsv.x)) * smoothstep(0.4, 0.6, hsv.z);
	vec3 result = mix(tint, tint * RIVAL_COOL, cream);
	result = mix(result, hsv_to_rgb(vec3(TEAL_HUE, hsv.y, hsv.z * TEAL_VALUE)), orange);
	result = mix(result, hsv_to_rgb(vec3(VERDIGRIS_HUE, hsv.y * 0.75, hsv.z * VERDIGRIS_VALUE)), gold);
	result = mix(result, hsv_to_rgb(vec3(EMERALD_HUE, clamp(hsv.y * 1.5, 0.0, 0.9), hsv.z * EMERALD_VALUE)), violet);
	return result;
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
