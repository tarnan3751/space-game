// The surface flags a kit mesh carries in UV2.y and the time-driven effects they turn on
// (docs/reference/art-style.md, **Animation**), shared by toon.gdshader (through
// toon_common.gdshaderinc), ink.gdshader and holo.gdshader, so an outline follows its part and a
// hologram moves like any other. The flags are bits of the integer in UV2.y; a part's phase, 0 to
// 1 in 1/254 steps, is in COLOR.a (surf_phase) and offsets its effect's cycle. No per-instance
// uniforms: every instance of a mesh animates alike, from anim_time, but for a battle's MultiMesh
// instances, whose custom data carries their gait, hit flash and fade (effect_gait, below), and for
// MOVE parts, which hold still while the shader's own move_hold instance uniform is set
// (move_clock, below).

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
const int FLAG_MOVE = 4096;
const int FLAG_RIG = 8192;
const int FLAG_MARCH = 16384;

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

// MOVE (LowPolyMesh.set_motion and stamp_motion, Motion.channel0 and channel3): a part that moves
// about its pivot as Motion.transform_at moves a moving part's node, a building's idle part folded
// into its body (BuildingModels) or a unit's rotor. Per vertex, CUSTOM0 is the pivot (xyz, in the
// mesh's space) and a code, (kind * 4 + easing) * 2 + phase, the phase 0 to 1; CUSTOM3 is the axis
// times the magnitude (xyz: a SPIN's radians a second, a SWING's amplitude in radians, a SLIDE's in
// units) and the period in seconds (w; a SPIN's is unused). The kinds and the easings are Motion's,
// in its order: SPIN, SWING, SLIDE; LINEAR, SMOOTH, HAMMER, RECOIL. A mesh with no moving part
// carries neither channel, so they are read only under the flag.
//
// The part moves on move_clock(hold): anim_time, or while the instance's move_hold is set (not 0)
// that time, at which it holds its pose (BuildingView, while the building is busy or disabled); its
// surface effects run on anim_time either way. Its FLICKER and JITTER act in its own space, before
// it moves, and its BOB and RISE after, as on a moving part's node (move_after_flags).
const int MOVE_SPIN = 0;
const int MOVE_SWING = 1;
const int MOVE_EASE_LINEAR = 0;
const int MOVE_EASE_SMOOTH = 1;
const int MOVE_EASE_HAMMER = 2;

float move_clock(float hold) {
	return hold != 0.0 ? hold : anim_time;
}

// Motion.wave's shape at the cycle's share u, from -1 to 1 (Motion.recoil for RECOIL).
float move_wave(int easing, float u) {
	if (easing == MOVE_EASE_LINEAR) {
		return 1.0 - 4.0 * abs(u - 0.5);
	}
	if (easing == MOVE_EASE_SMOOTH) {
		return sin(TAU * u);
	}
	if (easing == MOVE_EASE_HAMMER) {
		if (u < 0.7) {
			return -1.0 + 2.0 * smoothstep(0.0, 0.7, u);
		}
		if (u < 0.8) {
			float fall = (u - 0.7) / 0.1;
			return 1.0 - 2.0 * fall * fall;
		}
		return -1.0;
	}
	if (u < 0.1) {
		float kick = u / 0.1;
		return -1.0 + 2.0 * (1.0 - (1.0 - kick) * (1.0 - kick));
	}
	if (u < 0.8) {
		return 1.0 - 2.0 * smoothstep(0.1, 0.8, u);
	}
	return -1.0;
}

// The flags effect_vertex takes after a vertex has moved: a MOVE part's FLICKER and JITTER are
// done (effect_move).
int move_after_flags(int flags) {
	return has_flag(flags, FLAG_MOVE) ? flags & ~(FLAG_FLICKER | FLAG_JITTER) : flags;
}

// The battle's per-instance state (BattleUnits and BattleEffects draw from MultiMeshes whose
// custom data reaches the shaders as INSTANCE_CUSTOM): x the gait's phase, in steps; y how much of
// the gait shows, 0 standing (or hovering) to 1 striding; z the hit flash, 0 to 1; w the fade, 0 to
// 1. While a rigged unit aims, y is minus the aim's share and x the fire phase instead (RIG,
// below), and the gait shows nothing. Every other instance reads zeros, so nothing here changes it.
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

// RIG (LowPolyMesh.rig, docs/reference/art-style.md, **Rig**): a vertex moved by its own joint
// (CUSTOM1: pivot xyz, channel) and then by the joint it hangs from (CUSTOM2), each by the amount
// its channel takes from the instance's state: x the gait's phase while y >= 0 (a hovering
// model's bank plus RIG_BANK_BASE, so a zero state is not a flight), the fire phase plus 2 on an
// odd shot while y < 0; y the gait's share while >= 0 and minus the aim's share while < 0. Most
// channels turn about an axis through the pivot; SLIDE, SLIDE_L and SLIDE_R move by the stamp's
// vector, THRUST scales about its pivot (flickering only in battle). The channel table
// is Rig's (src/game/rig.gd), which mirrors these functions for the CPU: change both together. A
// normal is turned the same way about zero pivots, and neither moved nor scaled. A mesh with no
// rigged part carries neither channel, so they are read only under the flag.
//
// MARCH (Surf.MARCH): a rigged part of a model that is not drawn in a battle's MultiMesh (a
// building's figure), whose instance state is zero, walks on the clock instead: x the gait's
// phase 2 fract(RIG_MARCH_RATE anim_time), two steps a cycle, and y 1, the full gait. Under any
// other state (a battle's instance) the flag does nothing.
const int RIG_HIP_L = 1;
const int RIG_HIP_R = 2;
const int RIG_KNEE_L = 3;
const int RIG_KNEE_R = 4;
const int RIG_AIM = 5;
const int RIG_SHOULDER_L = 6;
const int RIG_SHOULDER_R = 7;
const int RIG_ELBOW_L = 8;
const int RIG_ELBOW_R = 9;
const int RIG_WHEEL = 10;
const int RIG_BANK = 12;
const int RIG_SLIDE = 13;
const int RIG_BAY_L = 14;
const int RIG_BAY_R = 15;
const int RIG_SLIDE_L = 16;
const int RIG_SLIDE_R = 17;
const int RIG_HIP_HEAVY_L = 18;
const int RIG_HIP_HEAVY_R = 19;
const int RIG_KNEE_HEAVY_L = 20;
const int RIG_KNEE_HEAVY_R = 21;
const int RIG_THRUST = 22;
// Radians, as Rig has them: 44, 70, 30 and 16 degrees; 35 and 30; 50 and 80; 80; 22 and 40.
const float RIG_HIP_SWING = 0.7679;
const float RIG_KNEE_BEND = 1.2217;
const float RIG_AIM_RAISE = 0.5236;
const float RIG_RECOIL_KICK = 0.2793;
const float RIG_ARM_SWING = 0.6109;
const float RIG_ELBOW_BEND = 0.5236;
const float RIG_PUNCH_SWING = 0.8727;
const float RIG_PUNCH_REACH = 1.3963;
const float RIG_BAY_OPEN = 1.3963;
const float RIG_HEAVY_HIP = 0.384;
const float RIG_HEAVY_KNEE = 0.6981;
const float RIG_RECOIL_SPAN = 0.3;
const float RIG_PUNCH_SPAN = 0.5;
const float RIG_THRUST_FLUTTER = 0.2;
const float RIG_THRUST_RATE = 9.0;
const float RIG_THRUST_IDLE = 0.35;
const float RIG_BANK_BASE = 4.0;
const float RIG_MARCH_RATE = 0.6;

// How far `channel` moves for `state`: radians for a turning channel, the share of the vector for
// a slide, the scale for THRUST (whose pivot's x is `pivot_x`).
float rig_amount(int channel, vec4 state, float pivot_x) {
	float walk = max(state.y, 0.0);
	float s = sin(PI * state.x);
	float aim = max(-state.y, 0.0);
	float odd = state.x >= 2.0 ? 1.0 : 0.0;
	float fire = state.x - 2.0 * odd;
	float kick = aim * (1.0 - smoothstep(0.0, RIG_RECOIL_SPAN, fire));
	float punch = aim * sin(PI * min(fire / RIG_PUNCH_SPAN, 1.0));
	float flying = state.y >= 0.0 && state.x >= RIG_BANK_BASE - 1.0 ? 1.0 : 0.0;
	float battle = state.y < 0.0 ? 1.0 : flying;
	if (channel == RIG_HIP_L) {
		return -RIG_HIP_SWING * walk * s;
	}
	if (channel == RIG_HIP_R) {
		return RIG_HIP_SWING * walk * s;
	}
	if (channel == RIG_KNEE_L) {
		return RIG_KNEE_BEND * walk * max(-s, 0.0);
	}
	if (channel == RIG_KNEE_R) {
		return RIG_KNEE_BEND * walk * max(s, 0.0);
	}
	if (channel == RIG_AIM) {
		return -(RIG_AIM_RAISE * aim + RIG_RECOIL_KICK * kick);
	}
	if (channel == RIG_SHOULDER_L) {
		return RIG_ARM_SWING * walk * s - RIG_PUNCH_SWING * punch * (1.0 - odd);
	}
	if (channel == RIG_SHOULDER_R) {
		return -RIG_ARM_SWING * walk * s - RIG_PUNCH_SWING * punch * odd;
	}
	if (channel == RIG_ELBOW_L) {
		return -RIG_ELBOW_BEND * walk * max(-s, 0.0) + RIG_PUNCH_REACH * punch * (1.0 - odd);
	}
	if (channel == RIG_ELBOW_R) {
		return -RIG_ELBOW_BEND * walk * max(s, 0.0) + RIG_PUNCH_REACH * punch * odd;
	}
	if (channel == RIG_WHEEL) {
		return PI * state.x;
	}
	if (channel == RIG_BANK) {
		return (state.x - RIG_BANK_BASE) * flying;
	}
	if (channel == RIG_SLIDE) {
		return kick;
	}
	if (channel == RIG_BAY_L) {
		return RIG_BAY_OPEN * smoothstep(0.0, 1.0, aim);
	}
	if (channel == RIG_BAY_R) {
		return -RIG_BAY_OPEN * smoothstep(0.0, 1.0, aim);
	}
	if (channel == RIG_SLIDE_L) {
		return kick * (1.0 - odd);
	}
	if (channel == RIG_SLIDE_R) {
		return kick * odd;
	}
	if (channel == RIG_HIP_HEAVY_L) {
		return -RIG_HEAVY_HIP * walk * s;
	}
	if (channel == RIG_HIP_HEAVY_R) {
		return RIG_HEAVY_HIP * walk * s;
	}
	if (channel == RIG_KNEE_HEAVY_L) {
		return RIG_HEAVY_KNEE * walk * max(-s, 0.0);
	}
	if (channel == RIG_KNEE_HEAVY_R) {
		return RIG_HEAVY_KNEE * walk * max(s, 0.0);
	}
	if (channel == RIG_THRUST) {
		return 1.0 + RIG_THRUST_FLUTTER * battle * sin(TAU * (RIG_THRUST_RATE * anim_time + 0.37 * pivot_x))
			- RIG_THRUST_IDLE * aim;
	}
	return 0.0;
}

// The axis a turning channel turns about, in the model's space: Z for the bank and the bay doors,
// X for the rest.
vec3 rig_axis(int channel) {
	if (channel == RIG_BANK || channel == RIG_BAY_L || channel == RIG_BAY_R) {
		return vec3(0.0, 0.0, 1.0);
	}
	return vec3(1.0, 0.0, 0.0);
}

// `v` (a point) and `n` (its normal) moved by the joint `joint` (pivot xyz, channel), the amount
// found once for both: turned as Godot's Basis(axis, angle) turns them, a point about the pivot.
void rig_move(inout vec3 v, inout vec3 n, vec4 joint, vec4 state) {
	int channel = int(joint.w + 0.5);
	if (channel == 0) {
		return;
	}
	float a = rig_amount(channel, state, joint.x);
	if (channel == RIG_SLIDE || channel == RIG_SLIDE_L || channel == RIG_SLIDE_R) {
		v += joint.xyz * a;
		return;
	}
	if (channel == RIG_THRUST) {
		v = joint.xyz + (v - joint.xyz) * a;
		return;
	}
	vec3 k = rig_axis(channel);
	float c = cos(a);
	float s = sin(a);
	vec3 off = v - joint.xyz;
	v = joint.xyz + off * c + cross(k, off) * s + k * dot(k, off) * (1.0 - c);
	n = n * c + cross(k, n) * s + k * dot(k, n) * (1.0 - c);
}

// A rigged vertex and its normal posed: by its own joint, then by its parent's (on the clock's
// march under MARCH at a zero state).
void effect_rig(int flags, vec4 joint, vec4 parent, vec4 state, inout vec3 v, inout vec3 n) {
	if (!has_flag(flags, FLAG_RIG)) {
		return;
	}
	vec4 posed = state;
	if (has_flag(flags, FLAG_MARCH) && state.x == 0.0 && state.y == 0.0) {
		posed.xy = vec2(2.0 * fract(RIG_MARCH_RATE * anim_time), 1.0);
	}
	rig_move(v, n, joint, posed);
	rig_move(v, n, parent, posed);
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

// A MOVE vertex `v` and its normal `n` moved at `time` (move_clock): in its own space, its FLICKER
// and JITTER, then turned about the axis through the pivot as Godot's Basis(axis, angle) turns
// (SPIN, SWING; the normal too) or slid along it (SLIDE).
void effect_move(int flags, vec4 c0, vec4 c3, float time, float phase, inout vec3 v, inout vec3 n) {
	if (!has_flag(flags, FLAG_MOVE)) {
		return;
	}
	int code = int(floor(c0.w * 0.5));
	float move_phase = c0.w - 2.0 * float(code);
	int kind = code / 4;
	int easing = code - kind * 4;
	vec3 local = effect_vertex(v - c0.xyz, flags & (FLAG_FLICKER | FLAG_JITTER | FLAG_LIGHTNING), phase, mat4(1.0));
	float wave = move_wave(easing, fract(time / c3.w + move_phase));
	float magnitude = length(c3.xyz);
	if (kind > MOVE_SWING) {
		v = c0.xyz + local + c3.xyz * wave;
		return;
	}
	if (magnitude <= 0.0) {
		v = c0.xyz + local;
		return;
	}
	vec3 k = c3.xyz / magnitude;
	float a = kind == MOVE_SPIN ? magnitude * time : magnitude * wave;
	float c = cos(a);
	float s = sin(a);
	v = c0.xyz + local * c + cross(k, local) * s + k * dot(k, local) * (1.0 - c);
	n = n * c + cross(k, n) * s + k * dot(k, n) * (1.0 - c);
}
