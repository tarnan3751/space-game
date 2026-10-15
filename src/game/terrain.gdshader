shader_type spatial;
render_mode ambient_light_disabled;

// The terrain ring's body (MaterialKit.terrain; docs/reference/art-style.md, **Environment**): a
// drawn surface over the per-vertex tint (the vertex colour, which BaseView paints by slope and
// place), lit by toon_common's light() like the buildings and the field. Over the tint, in world
// space:
// - the field's grain and its large value noise (field_marks), on the same cells as the field's,
//   so the grain runs on unbroken from the field under the curb;
// - on flats and dunes, the field texture's marks (craters, pits, pebbles, cracks), projected from
//   above in tiles MARK_TILE units square, each one of the atlas's four tiles from its cell hash,
//   mirrored or not from its cell hash, and turned by its place (field_marks' turn_by_place), so
//   no two touching tiles look the same; toned and lit from sun_across as on the field;
// - across slopes between RIPPLES_FROM and RIPPLES_TO degrees, wind ripples: ridges along the
//   height's contours, so they run across the slope, perpendicular to its fall, each leaning
//   gently towards the fall on its long side and steeply against it on its short side, those
//   sides lit or shaded by the way they lean against the sun, with a thin ink line along the
//   crest on its shaded side, broken into strokes on a value noise of each ripple's own. Their
//   spacing is RIPPLE_SPACING on a slope of RIPPLE_SLOPE degrees (closer on steeper ground, wider
//   on gentler), wanders on a value noise RIPPLE_WANDER_CELLS across, and they fade out where it
//   falls under RIPPLE_PX pixels;
// - on steep faces (mesa and crater walls), the rock texture's strata, projected along the face's
//   facing axis (x or z, by the normal's larger horizontal part, blended over a few degrees where
//   they meet) with its image y down the face, ROCK_TILE units a tile. Its lean is lit from the
//   sun in three dimensions, so a band's top edge, leaning up, is lit and its underside shaded.
// The marks give way to the strata between STRATA_FROM and STRATA_FULL degrees. The rock texture
// holds the field texture's channels: R and G the lean (x along the face, y down it), B ink, A
// tone.

#include "res://src/game/toon_common.gdshaderinc"
#include "res://src/game/field_marks.gdshaderinc"

uniform sampler2D field : filter_linear_mipmap, repeat_enable;
uniform sampler2D rock : filter_linear_mipmap, repeat_enable;
uniform vec4 terrain_light : source_color = vec4(0.478, 0.451, 0.89, 1.0);
uniform vec4 terrain_dark : source_color = vec4(0.243, 0.22, 0.549, 1.0);
uniform vec4 rock_lit : source_color = vec4(0.463, 0.545, 0.788, 1.0);
uniform vec4 ink_color : source_color = vec4(0.106, 0.102, 0.18, 1.0);
// The field's size in cells: the ring's cells are the field's, carried on outwards.
uniform vec2 grid_size = vec2(40.0, 40.0);
// Towards the key light across the ground, in world x and z: BaseView's SUN_ACROSS.
uniform vec2 sun_across = vec2(-0.5, 0.866);

// The key light's elevation in radians: main.gd's sun is pitched 55 degrees down.
const float SUN_ELEVATION = 0.9599;
// Units a tile of the field texture's marks spans on the ring, and the offsets of the cell hash
// that picks a tile's variant and whether it is mirrored (its turn comes from its place).
const float MARK_TILE = 6.0;
const float VARIANT_HASH = 95.0;
const float MIRROR_HASH = 79.0;
// The macro value noise, as on the field: its period in cells and its strength either way.
const float MACRO_CELLS = 12.0;
const float MACRO = 0.06;
// The slopes, in degrees, at which the ripples start, are full, start to fade and are gone, and at
// which the marks start to give way to the strata and the strata are full.
const float RIPPLES_FROM = 14.0;
const float RIPPLES_FULL = 18.0;
const float RIPPLES_FADE = 22.0;
const float RIPPLES_TO = 26.0;
const float STRATA_FROM = 28.0;
const float STRATA_FULL = 38.0;
// The ripples: their spacing in units on a slope of RIPPLE_SLOPE degrees, the period of the value
// noise their spacing wanders on and how many ripples it shifts them by either way; the share of
// a period their steep side takes; how far each side leans; how strongly their sides and their
// ink line show; the ink line's width in pixels at a 720 px viewport height; and the period in
// pixels under which they fade out.
const float RIPPLE_SPACING = 0.6;
const float RIPPLE_SLOPE = 22.0;
const float RIPPLE_WANDER_CELLS = 5.0;
const float RIPPLE_WANDER = 3.5;
const float RIPPLE_STEEP = 0.3;
const float RIPPLE_GENTLE_LEAN = 0.3;
const float RIPPLE_STEEP_LEAN = 0.9;
const float RIPPLE_SHOWS = 0.8;
const float RIPPLE_INK = 0.6;
const float RIPPLE_INK_PX = 1.0;
const float RIPPLE_PX = 3.0;
// The ripples' ink strokes: the value noise they break on, its lattice RIPPLE_STROKE_CELLS units
// across and offset by each ripple's count, and the share of it under which a stroke breaks.
const float RIPPLE_STROKE_CELLS = 0.8;
const float RIPPLE_BREAK = 0.35;
// Units a tile of the rock texture spans on a steep face, and the spread of the blend between its
// x- and z-facing projections, in the difference of the normal's horizontal parts.
const float ROCK_TILE = 4.0;
const float FACING_BLEND = 0.1;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = (MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz;
}

// How far a lean `lean` (x along the face, y down it, from the rock texture) on a face whose
// texture runs along `along` leans towards the sun `sun`.
float face_lit(vec2 lean, vec3 along, vec3 sun) {
	return dot(lean.x * along - lean.y * vec3(0.0, 1.0, 0.0), sun);
}

void fragment() {
	vec3 normal = normalize(world_normal);
	float slope = degrees(acos(clamp(normal.y, 0.0, 1.0)));
	float strata = smoothstep(STRATA_FROM, STRATA_FULL, slope);
	vec2 cell = world_pos.xz + grid_size * 0.5;
	vec2 cells_per_px = vec2(length(vec2(dFdx(cell.x), dFdy(cell.x))), length(vec2(dFdx(cell.y), dFdy(cell.y))));
	float px_scale = VIEWPORT_SIZE.y / 720.0;

	vec3 albedo = COLOR.rgb * grain(cell, cells_per_px);

	mat2 turn;
	vec4 marks = field_marks(field, cell, MARK_TILE, vec2(VARIANT_HASH, MIRROR_HASH), true, turn);
	vec3 marked = shade_marks(albedo, marks, turn, sun_across, terrain_light.rgb, terrain_dark.rgb, ink_color.rgb);
	albedo = mix(albedo, marked, 1.0 - strata);

	// The ripples, along the contours: their phase rises one a ripple uphill.
	float rise = RIPPLE_SPACING * tan(radians(RIPPLE_SLOPE));
	float phase = world_pos.y / rise + RIPPLE_WANDER * (2.0 * value_noise(world_pos.xz / RIPPLE_WANDER_CELLS) - 1.0);
	float per_px = max(fwidth(phase), 0.0001);
	float t = fract(phase);
	// 1 on the steep side, at the end of each period, antialiased over a pixel at each edge.
	float steep = clamp((t - (1.0 - RIPPLE_STEEP)) / per_px + 0.5, 0.0, 1.0) * clamp((1.0 - t) / per_px + 0.5, 0.0, 1.0);
	// Downhill across the ground; the gentle side leans that way, the steep side against it.
	vec2 fall = normalize(normal.xz + vec2(0.00001, 0.0));
	float facing = dot(fall, sun_across);
	float lit = mix(RIPPLE_GENTLE_LEAN, -RIPPLE_STEEP_LEAN, steep) * facing;
	float ripples = smoothstep(RIPPLES_FROM, RIPPLES_FULL, slope) * (1.0 - smoothstep(RIPPLES_FADE, RIPPLES_TO, slope))
		* (1.0 - smoothstep(1.0 / (RIPPLE_PX + 1.0), 1.0 / RIPPLE_PX, per_px));
	albedo = mix(albedo, terrain_light.rgb, smoothstep(LEAN_FROM, LEAN_FULL, lit) * ripples * RIPPLE_SHOWS);
	albedo = mix(albedo, terrain_dark.rgb, smoothstep(LEAN_FROM, LEAN_FULL, -lit) * ripples * RIPPLE_SHOWS);
	// The crest, at the steep side's start, inked on whichever side of it is shaded: the steep
	// side when it leans away from the sun, else the gentle side.
	float ink_width = RIPPLE_INK_PX * px_scale;
	float crest_px = (t - (1.0 - RIPPLE_STEEP)) / per_px + (facing > 0.0 ? -0.5 : 0.5) * ink_width;
	float stroke = smoothstep(RIPPLE_BREAK - 0.05, RIPPLE_BREAK + 0.05,
		value_noise(world_pos.xz / RIPPLE_STROKE_CELLS + floor(phase) * 17.0));
	albedo = mix(albedo, ink_color.rgb, ink_line(abs(crest_px), ink_width) * stroke * ripples * RIPPLE_INK);

	// The strata, from the x- and the z-facing projection.
	vec3 sun = vec3(sun_across.x * cos(SUN_ELEVATION), sin(SUN_ELEVATION), sun_across.y * cos(SUN_ELEVATION));
	float x_facing = smoothstep(-FACING_BLEND, FACING_BLEND, abs(normal.x) - abs(normal.z));
	vec4 rock_x = texture(rock, vec2(world_pos.z, -world_pos.y) / ROCK_TILE);
	vec4 rock_z = texture(rock, vec2(world_pos.x, -world_pos.y) / ROCK_TILE);
	vec4 rock_texel = mix(rock_z, rock_x, x_facing);
	float rock_lean = mix(face_lit(rock_z.rg * 2.0 - 1.0, vec3(1.0, 0.0, 0.0), sun),
		face_lit(rock_x.rg * 2.0 - 1.0, vec3(0.0, 0.0, 1.0), sun), x_facing);
	vec3 rocky = albedo;
	rocky = mix(rocky, rock_lit.rgb, clamp(2.0 * rock_texel.a - 1.0, 0.0, 1.0));
	rocky = mix(rocky, rock_lit.rgb, smoothstep(LEAN_FROM, LEAN_FULL, rock_lean));
	rocky = mix(rocky, terrain_dark.rgb, smoothstep(LEAN_FROM, LEAN_FULL, -rock_lean));
	rocky = mix(rocky, ink_color.rgb, rock_texel.b);
	albedo = mix(albedo, rocky, strata);

	albedo *= 1.0 + MACRO * (2.0 * value_noise(cell / MACRO_CELLS) - 1.0);
	ALBEDO = albedo;
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
