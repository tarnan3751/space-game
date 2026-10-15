shader_type spatial;
render_mode ambient_light_disabled;

// The buildable field (docs/reference/art-style.md, **The field**): a plain of levelled landing
// plates, PLATE cells square, dusted with the field texture, with ink seams between the plates,
// an ink line along the field's edge, and the cell grid in holographic cyan, faint by default and
// brighter while placing (BaseView.set_grid_highlight sets line_strength); all under the comic
// style's light (toon_common): the three bands, the halftone in the shadow band. Cells are 1
// world unit; the plane is centred on 0.
//
// The field texture (assets/textures/field.png, one repeat per plate) holds weights, not
// colours (tools/gen_textures.gd, _draw_field): R dust noise, stepped here into two tones; G
// shade; B ink; A light (0.5) and a shard fleck (1). The tints are MaterialKit roles, set by
// BaseView. It is sampled twice: once shifted by an offset of each plate's own, so neighbouring
// plates do not repeat, for the craters, pebbles and cracks; and once turned and at a larger
// scale, for the dust's mottling, blobs one to two cells across that do not repeat with the
// plates. A plate is the plate tint dusted at DUST_SHOWS with the field's base tint; the light
// drifts lie over it in the field's light tint and half bury the craters under them, so the
// copies of the texture on a plate show different craters; elsewhere the craters' shading and
// ink are at full strength. A large value noise and a darkening towards the edge vary the plain
// further. The seams and the edge line
// are a fixed width in pixels at a 720 px viewport height, scaled with it, like the ink outline.

#include "res://src/game/toon_common.gdshaderinc"

uniform sampler2D field : filter_linear_mipmap, repeat_enable;
uniform vec4 field_color : source_color = vec4(0.416, 0.373, 0.659, 1.0);
uniform vec4 field_light : source_color = vec4(0.549, 0.51, 0.769, 1.0);
uniform vec4 field_dark : source_color = vec4(0.306, 0.267, 0.525, 1.0);
uniform vec4 plate_color : source_color = vec4(0.498, 0.478, 0.651, 1.0);
uniform vec4 fleck_color : source_color = vec4(0.886, 0.643, 1.0, 1.0);
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.18, 1.0);
uniform vec4 line_color : source_color = vec4(0.31, 0.84, 0.9, 1.0);
uniform vec2 grid_size = vec2(40.0, 40.0);
uniform float line_width = 0.04;
uniform float line_strength = 0.1;

// Cells a plate spans, and the field texture's repeats a cell.
const float PLATE = 4.0;
const float FIELD_REPEAT = 0.25;
// The dust's sample: its repeats a cell, turned about 37 degrees, and how much of the detail
// sample's dust is mixed in.
const float DUST_REPEAT = 0.31;
const float DUST_DETAIL = 0.3;
// The dust's two tones: where its noise steps from base to light.
const float DUST_STEP = 0.5;
const float DUST_SOFTNESS = 0.06;
// How much of the base dust covers a plate, how much of the craters a light drift buries, and how
// far a plate's tint varies either way.
const float DUST_SHOWS = 0.6;
const float DRIFT_BURIES = 0.95;
const float PLATE_TINT = 0.04;
// The macro value noise: its period in cells and its strength either way. The darkening towards
// the edge, from half way out.
const float MACRO_CELLS = 12.0;
const float MACRO = 0.06;
const float EDGE_DARKEN = 0.1;
// Ink line widths in pixels at a 720 px viewport height: the plate seams, the field's edge.
const float SEAM_PX = 2.0;
const float EDGE_PX = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A hash of a cell in [0, 1). Small intermediate values, so it holds at medium precision.
float cell_tone(vec2 cell) {
	vec2 p = fract(cell * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// Smooth value noise in [0, 1] on a lattice of 1, from cell_tone (offset, so it does not follow
// the plates' tints).
float value_noise(vec2 p) {
	vec2 i = floor(p) + 50.0;
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(cell_tone(i), cell_tone(i + vec2(1.0, 0.0)), f.x),
		mix(cell_tone(i + vec2(0.0, 1.0)), cell_tone(i + vec2(1.0, 1.0)), f.x), f.y);
}

// 1 within half of `width_px` pixels of a line, antialiased over a pixel; `to_line_px` is the
// distance to it in pixels.
float ink_line(float to_line_px, float width_px) {
	return 1.0 - smoothstep(width_px * 0.5 - 0.5, width_px * 0.5 + 0.5, to_line_px);
}

void fragment() {
	vec2 cell = world_pos.xz + grid_size * 0.5;
	vec2 plate = floor(cell / PLATE);

	// The plate's detail, from the texture moved by the plate's offset. The gradients are the
	// unmoved coordinates', so the mip does not jump at a seam.
	vec2 uv = cell * FIELD_REPEAT;
	vec2 shift = vec2(cell_tone(plate), cell_tone(plate + 17.0));
	vec4 detail = textureGrad(field, uv + shift, dFdx(uv), dFdy(uv));
	vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * cell;
	float dust = mix(texture(field, turned * DUST_REPEAT).r, detail.r, DUST_DETAIL);

	float drift = smoothstep(DUST_STEP - DUST_SOFTNESS * 0.5, DUST_STEP + DUST_SOFTNESS * 0.5, dust);
	vec3 plate_tint = plate_color.rgb * (1.0 + PLATE_TINT * (2.0 * cell_tone(plate) - 1.0));
	vec3 albedo = mix(mix(plate_tint, field_color.rgb, DUST_SHOWS), field_light.rgb, drift);
	float shown = 1.0 - DRIFT_BURIES * drift;
	albedo = mix(albedo, field_light.rgb, clamp(detail.a * 2.0, 0.0, 1.0) * shown);
	albedo = mix(albedo, fleck_color.rgb, clamp(detail.a * 2.0 - 1.0, 0.0, 1.0) * shown);
	albedo = mix(albedo, field_dark.rgb, detail.g * shown);
	albedo = mix(albedo, ink_color.rgb, detail.b * shown);

	albedo *= 1.0 + MACRO * (2.0 * value_noise(cell / MACRO_CELLS) - 1.0);
	vec2 out_from_centre = abs(cell / grid_size - 0.5) * 2.0;
	albedo *= 1.0 - EDGE_DARKEN * smoothstep(0.5, 1.0, max(out_from_centre.x, out_from_centre.y));

	// Pixels per cell along each axis, for the lines drawn a fixed width on screen.
	vec2 cells_per_px = vec2(length(vec2(dFdx(cell.x), dFdy(cell.x))), length(vec2(dFdx(cell.y), dFdy(cell.y))));
	float px_scale = VIEWPORT_SIZE.y / 720.0;
	vec2 to_seam = abs(fract(cell / PLATE - 0.5) - 0.5) * PLATE / cells_per_px;
	vec2 to_edge = min(cell, grid_size - cell) / cells_per_px;
	float seam = ink_line(min(to_seam.x, to_seam.y), SEAM_PX * px_scale);
	float edge = ink_line(min(to_edge.x, to_edge.y), 2.0 * EDGE_PX * px_scale);
	albedo = mix(albedo, ink_color.rgb, max(seam, edge));

	vec2 to_line = abs(fract(cell - 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, line_width, min(to_line.x, to_line.y));
	ALBEDO = mix(albedo, line_color.rgb, line * line_strength);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
