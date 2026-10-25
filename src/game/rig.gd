class_name Rig
extends RefCounted
## The part rig (docs/reference/art-style.md, **Rig**): the channels a model's parts move with in
## the vertex shader, and their angles, mirrored here for the CPU, so a view can pose a point the
## way the shaders pose the part it is on (a muzzle socket on a rigged arm, posed()).
##
## A rigged part carries two joints per vertex (LowPolyMesh.rig and rig2): its own (pivot,
## channel) in CUSTOM1 and the one it hangs from in CUSTOM2, both in the model's space as built.
## The shaders move a vertex by its own joint first, then by the parent's, so a shin turns about
## the knee and then, with the thigh, about the hip. Each channel takes its amount from the battle
## instance's state (INSTANCE_CUSTOM, effects.gdshaderinc): x the gait's phase in steps (two a
## cycle) while y >= 0, or on a hovering model (which never hops) BANK_BASE plus its bank in
## radians, so a level flight is told from the zero state of a model drawn outside a battle; while
## y < 0, x is the fire phase f (0 at a shot, 1 by the next) plus 2 for an odd shot (the parity p,
## so a twin weapon's two sides take turns); y the gait's share while >= 0, minus the aim's share
## while < 0. Any instance outside a battle's MultiMeshes reads zeros: every channel at rest, the
## model as built.
##
## The channel table. Each row is the same in effects.gdshaderinc (rig_amount and its callers);
## change both together. walk = max(y, 0), s = sin(PI x), aim = max(-y, 0), p = 1 for x >= 2
## else 0, f = x - 2 p, kick = aim (1 - smoothstep(0, RECOIL_SPAN, f)), punch = aim
## sin(PI min(f / PUNCH_SPAN, 1)), on the side whose turn it is (left on p 0, right on p 1),
## flying = 1 when x >= BANK_BASE - 1 and y >= 0 (a hovering model in battle) else 0, and
## battle = 1 when y < 0 or flying, else 0.
## Most channels turn about an axis through the pivot; SLIDE moves by the stamp's vector and
## THRUST scales about the pivot.
##
##   id  channel        kind   angle or amount
##   1   HIP_L          X      -HIP_SWING walk s: the left thigh forward while s > 0
##   2   HIP_R          X      +HIP_SWING walk s
##   3   KNEE_L         X      KNEE_BEND walk max(-s, 0): the left knee bends while its leg is behind
##   4   KNEE_R         X      KNEE_BEND walk max(s, 0)
##   5   AIM            X      -(AIM_RAISE aim + RECOIL_KICK kick): the arms and the gun raised to aim,
##                             kicked up by each shot
##   6   SHOULDER_L     X      ARM_SWING walk s (the arm's counter-swing) - PUNCH_SWING punch(left)
##   7   SHOULDER_R     X      -ARM_SWING walk s - PUNCH_SWING punch(right)
##   8   ELBOW_L        X      -ELBOW_BEND walk max(-s, 0) + PUNCH_REACH punch(left): bent further
##                             as the arm swings forward, straightened by a punch
##   9   ELBOW_R        X      -ELBOW_BEND walk max(s, 0) + PUNCH_REACH punch(right)
##   10  WHEEL          X      PI x: a turn every cycle, so the phase's wrap at 2 never jumps
##   12  BANK           Z      (x - BANK_BASE) flying (a hovering model's roll into a turn)
##   13  SLIDE          move   the stamp's vector times kick: a barrel's recoil
##   14  BAY_L          Z      BAY_OPEN smoothstep(0, 1, aim): a bay door hinged on its left edge
##   15  BAY_R          Z      -BAY_OPEN smoothstep(0, 1, aim)
##   16  SLIDE_L        move   the stamp's vector times kick on p 0: the left gun of a pair
##   17  SLIDE_R        move   the stamp's vector times kick on p 1
##   18  HIP_HEAVY_L    X      -HEAVY_HIP walk s: a walker's hips, as HIP_L at half the swing
##   19  HIP_HEAVY_R    X      HEAVY_HIP walk s
##   20  KNEE_HEAVY_L   X      HEAVY_KNEE walk max(-s, 0)
##   21  KNEE_HEAVY_R   X      HEAVY_KNEE walk max(s, 0)
##   22  THRUST         scale  1 + THRUST_FLUTTER battle sin(TAU (THRUST_RATE anim_time + 0.37 pivot.x))
##                             - THRUST_IDLE aim: a flame flickering in battle (still outside one, as
##                             every row is at a zero state), shorter while it hovers to fire
##
## A vertex carrying Surf.MARCH (a building's figure, LowPolyMesh.flags) reads the state
## (2 fract(MARCH_RATE anim_time), 1) in place of a zero one: it walks on the clock, the same as the
## shaders' march (effect_rig). Any other state it reads as it is. Nothing poses a point on a
## marching part on the CPU, so angle() and posed() take the state as given.
##
## Reserved: 11 YAW (Y). A model that needs a channel at another amplitude gets a variant row of
## its own with its own id and constant, never per-instance data: the instance's state is the same
## four numbers for every model.

const HIP_L := 1
const HIP_R := 2
const KNEE_L := 3
const KNEE_R := 4
const AIM := 5
const SHOULDER_L := 6
const SHOULDER_R := 7
const ELBOW_L := 8
const ELBOW_R := 9
const WHEEL := 10
const BANK := 12
const SLIDE := 13
const BAY_L := 14
const BAY_R := 15
const SLIDE_L := 16
const SLIDE_R := 17
const HIP_HEAVY_L := 18
const HIP_HEAVY_R := 19
const KNEE_HEAVY_L := 20
const KNEE_HEAVY_R := 21
const THRUST := 22

## The channels that read the aim's share or the fire phase: a model with any of them aims while
## it attacks (BattleUnits).
const AIMING: Array[int] = [AIM, SHOULDER_L, SHOULDER_R, ELBOW_L, ELBOW_R, SLIDE, BAY_L, BAY_R, SLIDE_L,
	SLIDE_R, THRUST]

## Radians, as effects.gdshaderinc has them: the hips' swing either way (44 degrees), the knee's
## bend (70), the aim's raise (30, a low-ready gun brought level) and a shot's kick (16); an arm's
## counter-swing (35) and its elbow's bend (30); a punch's swing forward at the shoulder (50) and
## its reach at the elbow (80); a bay door's opening (80); a walker's hips (22) and knees (40).
const HIP_SWING := 0.7679
const KNEE_BEND := 1.2217
const AIM_RAISE := 0.5236
const RECOIL_KICK := 0.2793
const ARM_SWING := 0.6109
const ELBOW_BEND := 0.5236
const PUNCH_SWING := 0.8727
const PUNCH_REACH := 1.3963
const BAY_OPEN := 1.3963
const HEAVY_HIP := 0.384
const HEAVY_KNEE := 0.6981
## The share of the fire phase a shot's kick takes to ease back, and a punch to go out and back.
const RECOIL_SPAN := 0.3
const PUNCH_SPAN := 0.5
## THRUST: the flicker's reach and rate (a second), and how much shorter a flame is at full aim.
const THRUST_FLUTTER := 0.2
const THRUST_RATE := 9.0
const THRUST_IDLE := 0.35
## What a hovering model's x carries besides its bank (BattleUnits): a zero state is not a flight.
const BANK_BASE := 4.0
## MARCH: walk cycles a second on the clock (two steps each).
const MARCH_RATE := 0.6


## A rig stamp (LowPolyMesh.rig, rig2): `channel` about `pivot` in the model's space (for SLIDE,
## SLIDE_L and SLIDE_R, `pivot` is the recoil's vector).
static func part(channel: int, pivot: Vector3) -> Vector4:
	return Vector4(pivot.x, pivot.y, pivot.z, channel)


## How far `channel` moves for the instance state `state` (INSTANCE_CUSTOM): radians for a turning
## channel, the share of the vector for a slide, the scale for THRUST (whose pivot's x is `pivot_x`).
static func angle(channel: int, state: Color, pivot_x: float = 0.0) -> float:
	var walk := maxf(state.g, 0.0)
	var s := sin(PI * state.r)
	var aim := maxf(-state.g, 0.0)
	var odd := 1.0 if state.r >= 2.0 else 0.0
	var fire := state.r - 2.0 * odd
	var kick := aim * (1.0 - smoothstep(0.0, RECOIL_SPAN, fire))
	var punch := aim * sin(PI * minf(fire / PUNCH_SPAN, 1.0))
	var flying := 1.0 if state.g >= 0.0 and state.r >= BANK_BASE - 1.0 else 0.0
	var battle := 1.0 if state.g < 0.0 else flying
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
			return -(AIM_RAISE * aim + RECOIL_KICK * kick)
		SHOULDER_L:
			return ARM_SWING * walk * s - PUNCH_SWING * punch * (1.0 - odd)
		SHOULDER_R:
			return -ARM_SWING * walk * s - PUNCH_SWING * punch * odd
		ELBOW_L:
			return -ELBOW_BEND * walk * maxf(-s, 0.0) + PUNCH_REACH * punch * (1.0 - odd)
		ELBOW_R:
			return -ELBOW_BEND * walk * maxf(s, 0.0) + PUNCH_REACH * punch * odd
		WHEEL:
			return PI * state.r
		BANK:
			return (state.r - BANK_BASE) * flying
		SLIDE:
			return kick
		BAY_L:
			return BAY_OPEN * smoothstep(0.0, 1.0, aim)
		BAY_R:
			return -BAY_OPEN * smoothstep(0.0, 1.0, aim)
		SLIDE_L:
			return kick * (1.0 - odd)
		SLIDE_R:
			return kick * odd
		HIP_HEAVY_L:
			return -HEAVY_HIP * walk * s
		HIP_HEAVY_R:
			return HEAVY_HIP * walk * s
		KNEE_HEAVY_L:
			return HEAVY_KNEE * walk * maxf(-s, 0.0)
		KNEE_HEAVY_R:
			return HEAVY_KNEE * walk * maxf(s, 0.0)
		THRUST:
			return 1.0 + THRUST_FLUTTER * battle * sin(TAU * (THRUST_RATE * Motion.clock() + 0.37 * pivot_x)) \
				- THRUST_IDLE * aim
	return 0.0


## The axis a turning `channel` turns about, in the model's space.
static func axis(channel: int) -> Vector3:
	if channel == BANK or channel == BAY_L or channel == BAY_R:
		return Vector3.BACK
	return Vector3.RIGHT


## `point` (the model's space, as built) posed as the shaders pose a vertex rigged with `rig` and
## `rig2` for the instance state `state`.
static func posed(point: Vector3, rig: Vector4, rig2: Vector4, state: Color) -> Vector3:
	return _move(_move(point, rig, state, true), rig2, state, true)


## `direction` turned as posed() turns a point, its pivots left out.
static func posed_direction(direction: Vector3, rig: Vector4, rig2: Vector4, state: Color) -> Vector3:
	return _move(_move(direction, rig, state, false), rig2, state, false)


static func _move(v: Vector3, joint: Vector4, state: Color, point: bool) -> Vector3:
	var channel := roundi(joint.w)
	if channel == 0:
		return v
	var pivot := Vector3(joint.x, joint.y, joint.z)
	var a := angle(channel, state, joint.x)
	if channel == SLIDE or channel == SLIDE_L or channel == SLIDE_R:
		return v + pivot * a if point else v
	if channel == THRUST:
		return pivot + (v - pivot) * a if point else v
	if not point:
		pivot = Vector3.ZERO
	return pivot + Basis(axis(channel), a) * (v - pivot)
