// The field's marks and grain, shared by ground.gdshader (the field) and terrain.gdshader (the
// ring round it) (docs/reference/art-style.md, **Environment**): the cell hash and value noise,
// the world-space grain, and the field texture's atlas laid in tiles, each tile one of its four
// variants in one of eight orientations, with the lean of its marks lit from the sun.
//
// The field texture (assets/textures/field.png, tools/gen_textures.gd, _draw_field) is an atlas of
// four tiles, quadrant column + 2 row, which holds weights, not colours: R and G the surface's
// lean across the tile (0.5 flat, 0 and 1 a full lean either way), B ink, A tone (0.5 neutral).
// Every channel is flat along a tile's edges, so nothing shows where one tile meets the next.

// The grain: value noise at GRAIN_CELLS repeats a cell, each octave GRAIN either way, faded out as
// its lattice falls under a pixel.
const vec2 GRAIN_CELLS = vec2(6.0, 12.0);
const float GRAIN = 0.035;
// The lean's light across the sun at which a mark's light or dark side starts and is full.
const float LEAN_FROM = 0.25;
const float LEAN_FULL = 0.4;

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

// The grain at `cell` (in cells, world x and z), as a factor on the albedo; `cells_per_px` is how
// many cells a pixel spans along each axis.
float grain(vec2 cell, vec2 cells_per_px) {
	vec2 grain_fade = 1.0 - smoothstep(0.5, 1.0, GRAIN_CELLS * max(cells_per_px.x, cells_per_px.y));
	return (1.0 + GRAIN * grain_fade.x * (2.0 * value_noise(cell * GRAIN_CELLS.x) - 1.0))
		* (1.0 + GRAIN * grain_fade.y * (2.0 * value_noise(cell * GRAIN_CELLS.y) - 1.0));
}

// The atlas's texel at `cell`, laid in tiles `tile_cells` square. The tile's variant and its
// orientation come from its cell hash at the offsets `hashes` (x the variant's, y the
// orientation's); `turn` takes the tile's own axes to the variant's about its middle: a quarter
// turn count, then mirrored from 4 on.
vec4 field_marks(sampler2D atlas, vec2 cell, float tile_cells, vec2 hashes, out mat2 turn) {
	vec2 tile = floor(cell / tile_cells);
	float variant = floor(cell_tone(tile + hashes.x) * 4.0);
	float orientation = floor(cell_tone(tile + hashes.y) * 8.0);
	float angle = mod(orientation, 4.0) * PI * 0.5;
	float c = round(cos(angle));
	float s = round(sin(angle));
	float flip = orientation < 4.0 ? 1.0 : -1.0;
	turn = mat2(vec2(flip * c, s), vec2(-flip * s, c));
	vec2 at = turn * (fract(cell / tile_cells) - 0.5) + 0.5;
	vec2 uv = (vec2(mod(variant, 2.0), floor(variant * 0.5)) + at) * 0.5;
	// The gradients are the unturned, unbroken coordinates', so the mip does not jump where tiles
	// meet.
	vec2 across = cell / tile_cells * 0.5;
	return textureGrad(atlas, uv, dFdx(across), dFdy(across));
}

// `albedo` with the marks of `marks` (a texel of the atlas, from field_marks with `turn`) on it:
// the tone mixes towards `dark` below 0.5 and towards `light` above it; the lean, turned back into
// the cells' axes, lit from `sun_across`: the side leaning towards the sun takes `light`, the side
// leaning away `dark`; then the ink.
vec3 shade_marks(vec3 albedo, vec4 marks, mat2 turn, vec2 sun_across, vec3 light, vec3 dark, vec3 ink) {
	albedo = mix(albedo, dark, clamp(1.0 - 2.0 * marks.a, 0.0, 1.0));
	albedo = mix(albedo, light, clamp(2.0 * marks.a - 1.0, 0.0, 1.0));
	// `turn` is orthogonal, so its inverse is its transpose.
	float lit = dot(transpose(turn) * (marks.rg * 2.0 - 1.0), sun_across);
	albedo = mix(albedo, light, smoothstep(LEAN_FROM, LEAN_FULL, lit));
	albedo = mix(albedo, dark, smoothstep(LEAN_FROM, LEAN_FULL, -lit));
	return mix(albedo, ink, marks.b);
}
