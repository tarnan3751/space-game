shader_type spatial;
render_mode ambient_light_disabled;

// The body of every kit mesh (MaterialKit.toon): the layer of the kit each vertex names in
// UV2.x, multiplied by its tint (the vertex colour, which vertex() and fragment() read as the
// stored sRGB value: no material of the kit converts it), lit by toon_common's light(). The texture's alpha is its emission
// mask; an unlit surface (UV2.y 1) is pure emission. A placement ghost's material mixes
// ghost_tint in by its alpha (MaterialKit.ghost_valid and ghost_invalid, and a building's hit
// flash, MaterialKit.hit_flash); the shared body material leaves it at 0. A rival colony's
// buildings take `rival` 1 (MaterialKit.rival and hit_flash_rival), which turns them a green
// faction: orange teal, gold verdigris, violet emerald, the cream hull cooler (toon_common's
// rival_tint). A battle's MultiMesh
// instance hops, leans and flashes by its INSTANCE_CUSTOM (effects.gdshaderinc, effect_gait); any
// other instance reads zeros there.
//
// The surface flags in UV2.y animate a part from anim_time, offset by its phase in COLOR.a
// (effects.gdshaderinc): the vertex moves (MOVE, RIG, BOB, JITTER, FLICKER), the texture scrolls (FLOW,
// FLOW_U) and the colour, emission included, brightens and dims (PULSE, BLINK).

#include "res://src/game/toon_common.gdshaderinc"

uniform sampler2DArray kit : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 ghost_tint : source_color = vec4(1.0, 1.0, 1.0, 0.0);
// 1 on a rival colony's buildings and walls in an expedition battle, 0 everywhere else.
uniform float rival = 0.0;
// While set (not 0), the anim_time at which this instance's MOVE parts hold their pose
// (effects.gdshaderinc, move_clock): BuildingView sets it while the building is busy or disabled.
instance uniform float move_hold = 0.0;

varying float hit_flash;

void vertex() {
	int flags = surf_flags(UV2);
	float phase = surf_phase(COLOR);
	effect_move(flags, CUSTOM0, CUSTOM3, move_clock(move_hold), phase, VERTEX, NORMAL);
	effect_rig(flags, CUSTOM1, CUSTOM2, INSTANCE_CUSTOM, VERTEX, NORMAL);
	VERTEX = effect_vertex(effect_gait(VERTEX, INSTANCE_CUSTOM), move_after_flags(flags), phase, MODEL_MATRIX);
	hit_flash = INSTANCE_CUSTOM.z;
	if (rival > 0.5) {
		COLOR.rgb = rival_tint(COLOR.rgb, UV2);
	}
}

void fragment() {
	int flags = surf_flags(UV2);
	float phase = surf_phase(COLOR);
	vec4 texel = texture(kit, vec3(effect_uv(UV, flags, phase), UV2.x));
	vec3 albedo = mix(texel.rgb * COLOR.rgb, ghost_tint.rgb, ghost_tint.a) * effect_light(flags, phase);
	albedo = mix(albedo, vec3(1.0), hit_flash * FLASH_WHITE);
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
