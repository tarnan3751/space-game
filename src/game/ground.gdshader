shader_type spatial;

// Buildable ground: dark regolith with a faint cell grid and checker so placement
// reads clearly on small screens. Cells are 1 world unit; the plane is centred on 0.

uniform vec4 base_color : source_color = vec4(0.17, 0.15, 0.24, 1.0);
uniform vec4 line_color : source_color = vec4(0.31, 0.84, 0.9, 1.0);
uniform vec2 grid_size = vec2(40.0, 40.0);
uniform float line_width = 0.05;
uniform float line_strength = 0.3;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 cell = world_pos.xz + grid_size * 0.5;
	vec2 to_line = abs(fract(cell - 0.5) - 0.5);
	float line = 1.0 - smoothstep(0.0, line_width, min(to_line.x, to_line.y));
	float checker = mod(floor(cell.x) + floor(cell.y), 2.0) * 0.02;
	ALBEDO = mix(base_color.rgb + vec3(checker), line_color.rgb, line * line_strength);
	ROUGHNESS = 0.95;
}
