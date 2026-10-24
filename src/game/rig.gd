class_name Rig
extends RefCounted
## The part rig (docs/reference/art-style.md, **Rig**): the channels a model's parts turn with in
## the vertex shader, and their angles, mirrored here for the CPU, so a view can pose a point the
## way the shaders pose the part it is on (a muzzle socket on a rigged arm, posed()).
##
## A rigged part carries two joints per vertex (LowPolyMesh.rig and rig2): its own (pivot,
## channel) in CUSTOM1 and the one it hangs from in CUSTOM2, both in the model's space as built.
## The shaders turn a vertex about its own joint first, then about the parent's, so a shin turns
## about the knee and then, with the thigh, about the hip. Each channel has a fixed axis and takes
## its angle from the battle instance's state (INSTANCE_CUSTOM, effects.gdshaderinc): x the gait's
## phase in steps (two a cycle) while y >= 0, the fire phase (0 at a shot, 1 by the next) while
## y < 0; y the gait's share while >= 0, minus the aim's share while < 0. Any instance outside a
## battle's MultiMeshes reads zeros: every channel at 0, the model as built.
##
## The channel table. Each row is the same in effects.gdshaderinc (rig_angle, rig_axis); change
## both together. walk = max(y, 0), s = sin(PI x), aim = max(-y, 0),
## kick = aim (1 - smoothstep(0, RECOIL_SPAN, x)).
##
##   id  channel   axis  angle
##   1   HIP_L     X     -HIP_SWING walk s: the left thigh forward while s > 0
##   2   HIP_R     X     +HIP_SWING walk s
##   3   KNEE_L    X     KNEE_BEND walk max(-s, 0): the left knee bends while its leg is behind
##   4   KNEE_R    X     KNEE_BEND walk max(s, 0)
##   5   AIM       X     -(AIM_RAISE aim + RECOIL_KICK kick): the arms and the gun raised to aim,
##                       kicked up by each shot
##
## Reserved for the lanes that rig the rest of the roster (ids, axes and functions fixed, not yet
## built): 6, 7 SHOULDER_L, _R (X, an arm's counter-swing, +-ARM_SWING walk s); 8, 9 ELBOW_L, _R
## (X); 10 WHEEL (X, TAU x: whole turns a cycle, so the phase's wrap at 2 never jumps); 11 YAW (Y);
## 12 BANK (Z, x read as radians on a hovering model, which never hops); 13 SLIDE (a translation by
## the pivot's vector times kick: a barrel's recoil); 14 BAY (X, a bomb bay's doors or a hatch
## opening with aim); 15 FIST (X, a melee swing on the fire phase). A model that needs a channel at
## another amplitude (a mech's hip swinging less than a colonist's) gets a variant row of its own
## with its own id and constant, never per-instance data: the instance's state is the same four
## numbers for every model.

const HIP_L := 1
const HIP_R := 2
const KNEE_L := 3
const KNEE_R := 4
const AIM := 5

## Radians, as effects.gdshaderinc has them: the hips' swing either way (44 degrees), the knee's
## bend (70), the aim's raise (30, a low-ready gun brought level) and a shot's kick (16).
const HIP_SWING := 0.7679
const KNEE_BEND := 1.2217
const AIM_RAISE := 0.5236
const RECOIL_KICK := 0.2793
## The share of the fire phase a shot's kick takes to ease back.
const RECOIL_SPAN := 0.3


## A rig stamp (LowPolyMesh.rig, rig2): `channel` about `pivot` in the model's space.
static func part(channel: int, pivot: Vector3) -> Vector4:
	return Vector4(pivot.x, pivot.y, pivot.z, channel)


## The angle of `channel` in radians for the instance state `state` (INSTANCE_CUSTOM).
static func angle(channel: int, state: Color) -> float:
	var walk := maxf(state.g, 0.0)
	var s := sin(PI * state.r)
	var aim := maxf(-state.g, 0.0)
	match channel:
		HIP_L:
			return -HIP_SWING * walk * s
		HIP_R:
			return HIP_SWING * walk * s
		KNEE_L:
			return KNEE_BEND * walk * maxf(-s, 0.0)
		KNEE_R:
			return KNEE_BEND * walk * maxf(s, 0.0)
		AIM:
			var kick := aim * (1.0 - smoothstep(0.0, RECOIL_SPAN, state.r))
			return -(AIM_RAISE * aim + RECOIL_KICK * kick)
	return 0.0


## The axis `channel` turns about, in the model's space.
static func axis(_channel: int) -> Vector3:
	return Vector3.RIGHT


## `point` (the model's space, as built) posed as the shaders pose a vertex rigged with `rig` and
## `rig2` for the instance state `state`.
static func posed(point: Vector3, rig: Vector4, rig2: Vector4, state: Color) -> Vector3:
	return _turn(_turn(point, rig, state, true), rig2, state, true)


## `direction` turned as posed() turns a point, its pivots left out.
static func posed_direction(direction: Vector3, rig: Vector4, rig2: Vector4, state: Color) -> Vector3:
	return _turn(_turn(direction, rig, state, false), rig2, state, false)


static func _turn(v: Vector3, joint: Vector4, state: Color, about_pivot: bool) -> Vector3:
	var channel := roundi(joint.w)
	if channel == 0:
		return v
	var a := angle(channel, state)
	var pivot := Vector3(joint.x, joint.y, joint.z) if about_pivot else Vector3.ZERO
	return pivot + Basis(axis(channel), a) * (v - pivot)
