shader_type spatial;
render_mode ambient_light_disabled;

// Buildable ground: the material kit's regolith layer in the ground tint, a slight tone
// variation per cell, and a cell grid that is faint by default and brighter while placing
// (BaseView.set_grid_highlight sets line_strength), all under the comic style's light
// (toon_common): the three bands, the halftone in the shadow band. Cells are 1 world unit; the
// plane is centred on 0. base_color is the ground tint (MaterialKit.GROUND), as on the terrain
// around it; BaseView sets kit and layer from MaterialKit.

#include "res://src/game/toon_common.gdshaderinc"

uniform sampler2DArray kit : source_color, filter_linear_mipmap, repeat_enable;
uniform float layer = 15.0;
uniform vec4 base_color : source_color = vec4(0.43, 0.4, 0.52, 1.0);
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
	// Two samples at different scales and angles, so no cell repeats its neighbour's dust.
	vec2 turned = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8)) * cell;
	vec3 regolith = 0.5 * (texture(kit, vec3(cell * 0.25, layer)).rgb + texture(kit, vec3(turned * 0.14, layer)).rgb);
	vec3 ground = regolith * base_color.rgb * (0.95 + 0.1 * cell_tone(floor(cell)));
	ALBEDO = mix(ground, line_color.rgb, line * line_strength);
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
