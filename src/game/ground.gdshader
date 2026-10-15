shader_type spatial;
render_mode ambient_light_disabled;

// The buildable field (docs/reference/art-style.md, **The field**): one seamless levelled plain
// of regolith with scattered marks, an ink line along the field's edge, and the cell grid in
// holographic cyan, faint by default and brighter while placing (BaseView.set_grid_highlight sets
// line_strength); all under the comic style's light (toon_common): the three bands, the halftone
// in the shadow band. Cells are 1 world unit; the plane is centred on 0.
//
// The marks come from the field texture (assets/textures/field.png, tools/gen_textures.gd,
// _draw_field), an atlas of four tiles, quadrant column + 2 row, which holds weights, not colours:
// R and G the surface's lean across the tile (0.5 flat, 0 and 1 a full lean either way), B ink, A
// tone (0.5 neutral). Every channel is flat along a tile's edges, so nothing shows where one tile
// meets the next. The tints are MaterialKit roles, set by BaseView. The field is laid with tiles
// TILE cells square, each one of the four (its variant) in one of eight orientations (a quarter
// turn count, mirrored from 4 on), both from its cell hash, so the plain does not repeat. The lean
// is turned back into the field's axes and lit from sun_across, so however a tile lies its marks
// are lit from the sun: the side leaning towards it takes the light tint, the side leaning away
// the dark. The tone mixes towards the dark tint below 0.5 and towards the light above it.
// Everywhere the ground is the plate tint dusted at DUST_SHOWS with the field's base tint, with a
// fine grain in world space, so it runs on across the tiles, under the marks; a large value noise
// and a darkening towards the edge vary the plain further. The edge line is a fixed width in pixels
// at a 720 px viewport height, scaled with it, like the ink outline.

#include "res://src/game/toon_common.gdshaderinc"

uniform sampler2D field : filter_linear_mipmap, repeat_enable;
uniform vec4 field_color : source_color = vec4(0.416, 0.373, 0.659, 1.0);
uniform vec4 field_light : source_color = vec4(0.549, 0.51, 0.769, 1.0);
uniform vec4 field_dark : source_color = vec4(0.306, 0.267, 0.525, 1.0);
uniform vec4 plate_color : source_color = vec4(0.498, 0.478, 0.651, 1.0);
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.18, 1.0);
uniform vec4 line_color : source_color = vec4(0.31, 0.84, 0.9, 1.0);
uniform vec2 grid_size = vec2(40.0, 40.0);
uniform float line_width = 0.04;
uniform float line_strength = 0.1;
// Towards the key light across the ground, in cell x and y (world x and z): BaseView's SUN_ACROSS.
uniform vec2 sun_across = vec2(-0.5, 0.866);

// Cells a tile of the field texture spans.
const float TILE = 4.0;
// The offsets of the cell hash that picks a tile's variant and its orientation.
const float VARIANT_HASH = 30.0;
const float ORIENTATION_HASH = 27.0;
// How much of the field's base tint dusts the plate tint.
const float DUST_SHOWS = 0.6;
// The grain: value noise at GRAIN_CELLS repeats a cell, each octave GRAIN either way, faded out as
// its lattice falls under a pixel.
const vec2 GRAIN_CELLS = vec2(6.0, 12.0);
const float GRAIN = 0.035;
// The lean's light across the sun at which a mark's light or dark side starts and is full.
const float LEAN_FROM = 0.25;
const float LEAN_FULL = 0.4;
// The macro value noise: its period in cells and its strength either way. The darkening towards
// the edge, from half way out.
const float MACRO_CELLS = 12.0;
const float MACRO = 0.06;
const float EDGE_DARKEN = 0.1;
// The ink line's width along the field's edge, in pixels at a 720 px viewport height.
const float EDGE_PX = 3.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// A hash of a cell in [0, 1). The product inside its last fract reaches about 10,000, beyond
// medium precision, so it relies on highp floats, which the Compatibility renderer's fragment
// shaders have.
float cell_tone(vec2 cell) {
	vec2 p = fract(cell * vec2(0.1031, 0.1030));
	p += dot(p, p.yx + 33.33);
	return fract((p.x + p.y) * p.x);
}

// Smooth value noise in [0, 1] on a lattice of 1, from cell_tone (offset, so it does not follow
// the tiles' picks).
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
	vec2 tile = floor(cell / TILE);
	// Cells per pixel along each axis, for the grain's fade and the lines drawn a fixed width on
	// screen.
	vec2 cells_per_px = vec2(length(vec2(dFdx(cell.x), dFdy(cell.x))), length(vec2(dFdx(cell.y), dFdy(cell.y))));

	// The tile's variant, and `turn`, which takes the tile's own axes to the variant's about its
	// middle: a quarter turn count, then mirrored from 4 on.
	float variant = floor(cell_tone(tile + VARIANT_HASH) * 4.0);
	float orientation = floor(cell_tone(tile + ORIENTATION_HASH) * 8.0);
	float angle = mod(orientation, 4.0) * PI * 0.5;
	float c = round(cos(angle));
	float s = round(sin(angle));
	float flip = orientation < 4.0 ? 1.0 : -1.0;
	mat2 turn = mat2(vec2(flip * c, s), vec2(-flip * s, c));
	vec2 at = turn * (fract(cell / TILE) - 0.5) + 0.5;
	vec2 uv = (vec2(mod(variant, 2.0), floor(variant * 0.5)) + at) * 0.5;
	// The gradients are the unturned, unbroken coordinates', so the mip does not jump where tiles
	// meet.
	vec2 across = cell / TILE * 0.5;
	vec4 marks = textureGrad(field, uv, dFdx(across), dFdy(across));

	vec3 albedo = mix(plate_color.rgb, field_color.rgb, DUST_SHOWS);
	vec2 grain_fade = 1.0 - smoothstep(0.5, 1.0, GRAIN_CELLS * max(cells_per_px.x, cells_per_px.y));
	albedo *= 1.0 + GRAIN * grain_fade.x * (2.0 * value_noise(cell * GRAIN_CELLS.x) - 1.0);
	albedo *= 1.0 + GRAIN * grain_fade.y * (2.0 * value_noise(cell * GRAIN_CELLS.y) - 1.0);
	albedo = mix(albedo, field_dark.rgb, clamp(1.0 - 2.0 * marks.a, 0.0, 1.0));
	albedo = mix(albedo, field_light.rgb, clamp(2.0 * marks.a - 1.0, 0.0, 1.0));
	// The lean, back in the field's axes: `turn` is orthogonal, so its inverse is its transpose.
	float lit = dot(transpose(turn) * (marks.rg * 2.0 - 1.0), sun_across);
	albedo = mix(albedo, field_light.rgb, smoothstep(LEAN_FROM, LEAN_FULL, lit));
	albedo = mix(albedo, field_dark.rgb, smoothstep(LEAN_FROM, LEAN_FULL, -lit));
	albedo = mix(albedo, ink_color.rgb, marks.b);

	albedo *= 1.0 + MACRO * (2.0 * value_noise(cell / MACRO_CELLS) - 1.0);
	vec2 out_from_centre = abs(cell / grid_size - 0.5) * 2.0;
	albedo *= 1.0 - EDGE_DARKEN * smoothstep(0.5, 1.0, max(out_from_centre.x, out_from_centre.y));

	float px_scale = VIEWPORT_SIZE.y / 720.0;
	vec2 to_edge = min(cell, grid_size - cell) / cells_per_px;
	albedo = mix(albedo, ink_color.rgb, ink_line(min(to_edge.x, to_edge.y), 2.0 * EDGE_PX * px_scale));

	vec2 to_line = abs(fract(cell - 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, line_width, min(to_line.x, to_line.y));
	ALBEDO = mix(albedo, line_color.rgb, line * line_strength);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
