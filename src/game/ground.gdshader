shader_type spatial;

// Buildable ground: regolith with a slight tone variation per cell, and a cell grid that is
// faint by default and brighter while placing (BaseView.set_grid_highlight sets
// line_strength). Cells are 1 world unit; the plane is centred on 0. base_color is the
// ground tint of the material kit (MaterialKit.GROUND), as on the terrain around it.

uniform vec4 base_color : source_color = vec4(0.29, 0.26, 0.35, 1.0);
uniform vec4 line_color : source_color = vec4(0.31, 0.84, 0.9, 1.0);
uniform vec2 grid_size = vec2(40.0, 40.0);
uniform float line_width = 0.04;
uniform float line_strength = 0.1;

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

void fragment() {
	vec2 cell = world_pos.xz + grid_size * 0.5;
	vec2 to_line = abs(fract(cell - 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, line_width, min(to_line.x, to_line.y));
	vec3 ground = base_color.rgb * (0.95 + 0.1 * cell_tone(floor(cell)));
	ALBEDO = mix(ground, line_color.rgb, line * line_strength);
	ROUGHNESS = 1.0;
}
