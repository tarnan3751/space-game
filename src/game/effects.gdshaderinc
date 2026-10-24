// The surface flags a kit mesh carries in UV2.y and the time-driven effects they turn on
// (docs/reference/art-style.md, **Animation**), shared by toon.gdshader (through
// toon_common.gdshaderinc), ink.gdshader and holo.gdshader, so an outline follows its part and a
// hologram moves like any other. The flags are bits of the integer in UV2.y; a part's phase, 0 to
// 1 in 1/254 steps, is in COLOR.a (surf_phase) and offsets its effect's cycle. No per-instance
// uniforms: every instance of a mesh animates alike, from anim_time, but for a battle's MultiMesh
// instances, whose custom data carries their gait, hit flash and fade (effect_gait, below).

// The game's animation clock in seconds, wrapping every hour: main.gd sets it once a frame from
// the clock Motion.clock() returns, so the moving parts BuildingView poses keep step with these
// effects (a muzzle's BLINK on its barrel's kick). Declared under [shader_globals] in
// project.godot. Used instead of TIME, whose zero is the engine's first drawn frame.
global uniform float anim_time;

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
const int FLAG_LIGHTNING = 1024;
const int FLAG_RISE = 2048;
const int FLAG_SPIN = 4096;

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
// LIGHTNING: with FLICKER and JITTER, a lightning arc's slower crackle, the same on every arc: a
// new on/off draw LIGHTNING_FLICKER_RATE times a second, on LIGHTNING_ON of the time, and a new
// shake LIGHTNING_JITTER_RATE times a second.
const float LIGHTNING_FLICKER_RATE = 7.0;
const float LIGHTNING_ON = 0.6;
const float LIGHTNING_JITTER_RATE = 5.0;
// RISE: a climb of RISE_HEIGHT along world Y over RISE_PERIOD seconds, from the part's phase,
// drifting RISE_DRIFT world units sideways by the top, then a restart (holo.gdshader fades it in
// at the start and out by the top, so the restart does not show).
const float RISE_PERIOD = 3.0;
const float RISE_HEIGHT = 0.7;
const vec3 RISE_DRIFT = vec3(0.12, 0.0, 0.08);

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

// SPIN (LowPolyMesh.spin): a vertex turned about the vertical line through spin.xyz by spin.w
// radians a second on the clock, as Motion.spin turns a moving part about +Y (Basis(UP, angle));
// a normal is turned the same way with a zero pivot. The pivot and the rate are in CUSTOM0, which a
// mesh with no spinning part does not carry, so it is read only under the flag.
vec3 effect_spin(vec3 vertex, int flags, vec4 spin) {
	if (!has_flag(flags, FLAG_SPIN)) {
		return vertex;
	}
	float angle = spin.w * anim_time;
	float c = cos(angle);
	float s = sin(angle);
	vec3 off = vertex - spin.xyz;
	return spin.xyz + vec3(off.x * c + off.z * s, off.y, -off.x * s + off.z * c);
}

// The battle's per-instance state (BattleUnits and BattleEffects draw from MultiMeshes whose
// custom data reaches the shaders as INSTANCE_CUSTOM): x the gait's phase, in steps; y how much of
// the gait shows, 0 standing (or hovering) to 1 striding; z the hit flash, 0 to 1; w the fade, 0 to
// 1. Every other instance reads zeros, so nothing here changes it.
//
// The gait (effect_gait) is the Clash hop: once a step the model lifts GAIT_HOP off the ground on
// a half sine and lands squashed by GAIT_SQUASH, leaning forward (+Z) by GAIT_LEAN and swaying
// GAIT_SWAY to either side in turn, each a shear growing with the vertex's height, so the feet
// stay planted while the head moves most. The hit flash whitens the colour by FLASH_WHITE at its
// height (toon.gdshader); the fade thins the outline (ink.gdshader) and a hologram's alpha
// (holo.gdshader), while BattleUnits shrinks the instance itself.
const float GAIT_HOP = 0.09;
const float GAIT_SQUASH = 0.1;
const float GAIT_LEAN = 0.16;
const float GAIT_SWAY = 0.05;
const float FLASH_WHITE = 0.75;

vec3 effect_gait(vec3 vertex, vec4 custom) {
	if (custom.y <= 0.0) {
		return vertex;
	}
	float stride = sin(PI * custom.x);
	float lift = abs(stride);
	vec3 moved = vertex;
	moved.y = vertex.y * (1.0 - GAIT_SQUASH * custom.y * (1.0 - lift)) + GAIT_HOP * custom.y * lift;
	moved.z += vertex.y * GAIT_LEAN * custom.y;
	moved.x += vertex.y * GAIT_SWAY * custom.y * stride;
	return moved;
}

// How far through its climb a RISE part is now, 0 to 1.
float rise_progress(float phase) {
	return fract(anim_time / RISE_PERIOD + phase);
}

// Where a vertex of a part goes, in the mesh's own space: BOB lifts it along world Y, RISE climbs
// it and drifts it in world space, JITTER shakes it, and FLICKER collapses the whole part to the
// origin while it is off, so it draws nothing (a discard would cost every fragment of the shared
// material its early depth test); LIGHTNING slows FLICKER and JITTER to the lightning rates.
// `model` turns only about axes and scales uniformly, so its inverse is its transpose over the
// scale squared.
vec3 effect_vertex(vec3 vertex, int flags, float phase, mat4 model) {
	bool lightning = has_flag(flags, FLAG_LIGHTNING);
	float flicker_rate = lightning ? LIGHTNING_FLICKER_RATE : FLICKER_RATE;
	float flicker_on = lightning ? LIGHTNING_ON : FLICKER_ON;
	if (has_flag(flags, FLAG_FLICKER)
			&& effect_hash(vec3(floor(anim_time * flicker_rate), phase * 97.0, 7.0)) >= flicker_on) {
		return vec3(0.0);
	}
	vec3 moved = vertex;
	if (has_flag(flags, FLAG_BOB)) {
		float lift = BOB_HEIGHT * sin(TAU * (anim_time / BOB_PERIOD + phase));
		moved += transpose(mat3(model)) * vec3(0.0, lift, 0.0) / dot(model[0].xyz, model[0].xyz);
	}
	if (has_flag(flags, FLAG_RISE)) {
		float t = rise_progress(phase);
		vec3 climb = vec3(0.0, t * RISE_HEIGHT, 0.0) + t * RISE_DRIFT;
		moved += transpose(mat3(model)) * climb / dot(model[0].xyz, model[0].xyz);
	}
	if (has_flag(flags, FLAG_JITTER)) {
		vec3 cell = floor(vertex * 1000.0) + floor(anim_time * (lightning ? LIGHTNING_JITTER_RATE : JITTER_RATE));
		vec3 shake = vec3(effect_hash(cell), effect_hash(cell + 17.0), effect_hash(cell + 41.0)) * 2.0 - 1.0;
		moved += shake * JITTER_REACH;
	}
	return moved;
}

// How bright a part is now, 0 to 1: PULSE and BLINK.
float effect_light(int flags, float phase) {
	float light = 1.0;
	if (has_flag(flags, FLAG_PULSE)) {
		light *= mix(PULSE_LOW, 1.0, 0.5 + 0.5 * sin(TAU * (anim_time / PULSE_PERIOD + phase)));
	}
	if (has_flag(flags, FLAG_BLINK)) {
		light *= fract(anim_time / BLINK_PERIOD + phase) < BLINK_ON / BLINK_PERIOD ? 1.0 : BLINK_LOW;
	}
	return light;
}

// The part's texture coordinates now: FLOW scrolls them along V, FLOW_U along U.
vec2 effect_uv(vec2 uv, int flags, float phase) {
	float shift = mod(anim_time * (phase - 0.5) * FLOW_SPEED, 1.0);
	if (has_flag(flags, FLAG_FLOW)) {
		uv.y -= shift;
	}
	if (has_flag(flags, FLAG_FLOW_U)) {
		uv.x -= shift;
	}
	return uv;
}
