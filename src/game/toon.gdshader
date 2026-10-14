shader_type spatial;
render_mode ambient_light_disabled;

// The body of every kit mesh (MaterialKit.toon): the layer of the kit each vertex names in
// UV2.x, multiplied by its tint (the vertex colour, stored sRGB; the renderer hands it to the
// shader already in linear), lit by toon_common's light(). The texture's alpha is its emission
// mask; an unlit surface (UV2.y 1) is pure emission. A placement ghost's material mixes
// ghost_tint in by its alpha (MaterialKit.ghost_valid and ghost_invalid); the shared body
// material leaves it at 0.

#include "res://src/game/toon_common.gdshaderinc"

uniform sampler2DArray kit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 ghost_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec4 texel = texture(kit, vec3(UV, UV2.x));
	vec3 albedo = mix(texel.rgb * COLOR.rgb, ghost_tint.rgb, ghost_tint.a);
	if (is_unlit(UV2)) {
		ALBEDO = vec3(0.0);
		EMISSION = albedo;
	} else {
		ALBEDO = albedo;
		EMISSION = albedo * texel.a;
	}
	SPECULAR = 0.0;
	ROUGHNESS = 1.0;
}
