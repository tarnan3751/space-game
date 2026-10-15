shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, unshaded;

// The hologram surface of a kit mesh (MaterialKit.holo): every part whose Surf has the HOLO flag,
// which LowPolyMesh.to_mesh puts in a surface of its own, since it is transparent. Unlit: the
// kit layer times the tint at HOLO_ALPHA, scan bands drifting up through it, a rim where the
// view grazes the surface, and a "phase out" every HOLO_DIP_PERIOD seconds, when it fades to
// HOLO_DIP_ALPHA for HOLO_DIP_SECONDS, offset by the part's phase (surf_phase). The other effects
// (effects.gdshaderinc) apply as on any part. Holograms are never outlined, so the rim is a
// fresnel term here, unlike the toon shader.

#include "res://src/game/effects.gdshaderinc"

const float HOLO_ALPHA = 0.45;
// Scan bands: a sawtooth BAND_LENGTH world units long, moving up at BAND_SPEED units a second,
// adding up to BAND_BRIGHTEN.
const float BAND_LENGTH = 0.5;
const float BAND_SPEED = 0.4;
const float BAND_BRIGHTEN = 0.4;
const float HOLO_DIP_PERIOD = 2.6;
const float HOLO_DIP_SECONDS = 0.1;
const float HOLO_DIP_ALPHA = 0.2;
const float RIM_BRIGHTEN = 0.3;

uniform sampler2DArray kit : source_color, filter_linear_mipmap, repeat_enable;

varying float world_y;

void vertex() {
	VERTEX = effect_vertex(VERTEX, surf_flags(UV2), surf_phase(COLOR), MODEL_MATRIX);
	world_y = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	int flags = surf_flags(UV2);
	float phase = surf_phase(COLOR);
	vec4 texel = texture(kit, vec3(effect_uv(UV, flags, phase), UV2.x));
	float band = fract((world_y - TIME * BAND_SPEED) / BAND_LENGTH);
	float rim = smoothstep(0.5, 1.0, 1.0 - abs(dot(NORMAL, VIEW)));
	vec3 colour = texel.rgb * COLOR.rgb * effect_light(flags, phase);
	ALBEDO = colour * (1.0 + BAND_BRIGHTEN * band + RIM_BRIGHTEN * rim);
	bool dipped = fract(TIME / HOLO_DIP_PERIOD + phase) < HOLO_DIP_SECONDS / HOLO_DIP_PERIOD;
	ALPHA = dipped ? HOLO_DIP_ALPHA : HOLO_ALPHA;
}
