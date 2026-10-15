// The surface flags a kit mesh carries in UV2.y and the time-driven effects they turn on
// (docs/reference/art-style.md, **Animation**), shared by toon.gdshader (through
// toon_common.gdshaderinc), ink.gdshader and holo.gdshader, so an outline follows its part and a
// hologram moves like any other. The flags are bits of the integer in UV2.y; a part's phase, 0 to
// 1 in 1/254 steps, is in COLOR.a (surf_phase) and offsets its effect's cycle. No uniforms:
// every instance of a mesh animates alike, from TIME.

const int FLAG_UNLIT = 1;
const int FLAG_GLOSSY = 2;
const int FLAG_PULSE = 4;
const int FLAG_BLINK = 8;
const int FLAG_FLICKER = 16;
const int FLAG_FLOW = 32;
const int FLAG_FLOW_U = 64;
const int FLAG_BOB = 128;
const int FLAG_JITTER = 256;
const int FLAG_HOLO = 512;

// PULSE: the colour swells between PULSE_LOW and 1 on a sine of PULSE_PERIOD seconds.
const float PULSE_PERIOD = 1.6;
const float PULSE_LOW = 0.55;
// BLINK: lit BLINK_ON seconds of every BLINK_PERIOD, at BLINK_LOW the rest.
const float BLINK_PERIOD = 1.2;
const float BLINK_ON = 0.2;
const float BLINK_LOW = 0.35;
// FLICKER: a new on/off draw FLICKER_RATE times a second, on FLICKER_ON of the time.
const float FLICKER_RATE = 24.0;
const float FLICKER_ON = 0.4;
// FLOW, FLOW_U: texture repeats a second per unit of (phase - 0.5).
const float FLOW_SPEED = 4.0;
// BOB: a lift along world Y of BOB_HEIGHT on a sine of BOB_PERIOD seconds.
const float BOB_PERIOD = 2.4;
const float BOB_HEIGHT = 0.08;
// JITTER: each vertex moves up to JITTER_REACH units, to a new spot JITTER_RATE times a second.
const float JITTER_RATE = 20.0;
const float JITTER_REACH = 0.04;

int surf_flags(vec2 uv2) {
	return int(uv2.y + 0.5);
}

bool has_flag(int flags, int bit) {
	return (flags & bit) != 0;
}

// A part's phase from its vertex colour's alpha, which holds it in 254 steps (LowPolyMesh._emit
// writes (round(phase * 254) + 0.25) / 255, the same byte whether the store rounds or truncates),
// so 0.5, a FLOW part standing still, comes back exactly.
float surf_phase(vec4 colour) {
	return round(colour.a * 255.0) / 254.0;
}

float effect_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

// Where a vertex of a part goes, in the mesh's own space: BOB lifts it along world Y, JITTER
// shakes it, and FLICKER collapses the whole part to the origin while it is off, so it draws
// nothing (a discard would cost every fragment of the shared material its early depth test).
// `model` turns only about axes and scales uniformly, so its inverse is its transpose over the
// scale squared.
vec3 effect_vertex(vec3 vertex, int flags, float phase, mat4 model) {
	if (has_flag(flags, FLAG_FLICKER)
			&& effect_hash(vec3(floor(TIME * FLICKER_RATE), phase * 97.0, 7.0)) >= FLICKER_ON) {
		return vec3(0.0);
	}
	vec3 moved = vertex;
	if (has_flag(flags, FLAG_BOB)) {
		float lift = BOB_HEIGHT * sin(TAU * (TIME / BOB_PERIOD + phase));
		moved += transpose(mat3(model)) * vec3(0.0, lift, 0.0) / dot(model[0].xyz, model[0].xyz);
	}
	if (has_flag(flags, FLAG_JITTER)) {
		vec3 cell = floor(vertex * 1000.0) + floor(TIME * JITTER_RATE);
		vec3 shake = vec3(effect_hash(cell), effect_hash(cell + 17.0), effect_hash(cell + 41.0)) * 2.0 - 1.0;
		moved += shake * JITTER_REACH;
	}
	return moved;
}

// How bright a part is now, 0 to 1: PULSE and BLINK.
float effect_light(int flags, float phase) {
	float light = 1.0;
	if (has_flag(flags, FLAG_PULSE)) {
		light *= mix(PULSE_LOW, 1.0, 0.5 + 0.5 * sin(TAU * (TIME / PULSE_PERIOD + phase)));
	}
	if (has_flag(flags, FLAG_BLINK)) {
		light *= fract(TIME / BLINK_PERIOD + phase) < BLINK_ON / BLINK_PERIOD ? 1.0 : BLINK_LOW;
	}
	return light;
}

// The part's texture coordinates now: FLOW scrolls them along V, FLOW_U along U.
vec2 effect_uv(vec2 uv, int flags, float phase) {
	float shift = mod(TIME * (phase - 0.5) * FLOW_SPEED, 1.0);
	if (has_flag(flags, FLAG_FLOW)) {
		uv.y -= shift;
	}
	if (has_flag(flags, FLAG_FLOW_U)) {
		uv.x -= shift;
	}
	return uv;
}
