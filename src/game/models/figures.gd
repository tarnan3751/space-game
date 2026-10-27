class_name Figures
extends RefCounted
## The humanoid figures, in the comic style (docs/reference/art-style.md, **Figures**): the
## colonist, the human crew in a spacesuit, and the automaton, the humanoid robot that shares its
## skeleton. Both are built from rounded LowPolyMesh parts painted from the material kit (lathes,
## orbs, domes and heavily chamfered boxes; no bare box anywhere) and posed.
##
## The figure contract:
## - A figure is added to a LowPolyMesh the caller owns, every part of it in that one mesh. It
##   stands with the soles of its feet on `foot`, faces +Z turned `yaw` degrees about +Y, and is
##   COLONIST_HEIGHT or AUTOMATON_HEIGHT tall times `scale` (to its helmet's top, or its head's
##   top under the antenna).
## - Its proportion is `heads`, its height over its head unit (the helmet's diameter; the
##   automaton's neck and head block): PRIMARY_HEADS by default.
## - A Pose is the joint angles. The skeleton (_skeleton) turns them into a Transform3D per joint,
##   from the pelvis out: the waist, the neck, each shoulder, elbow and wrist, each hip, knee and
##   ankle, the pelvis lowered so the lower foot stands on `foot`. Each segment (the head, the
##   torso, each upper arm, forearm, hand, thigh, shin and foot) is built by a function of its
##   own from its joint's transform, the segment hanging along the joint's -Y, so posing is only
##   changing angles, and a unit pipeline can later build each segment on its own. joints() hands
##   the posed skeleton to a caller that adds to a figure or seats it.
## - Nothing here moves: there are no moving parts and no Motion. The poses are static, but for a
##   rigged build: built in the neutral() pose with a Rigging (walk_rig), its segments carry rig
##   channels (Rig, LowPolyMesh.rig) that the shaders turn in battle, the legs walking and the arms
##   following their channel. Without one (the study poses, the seated pilot) nothing is rigged.
## - A figure's ink line is FIGURE_INK of the full width (LowPolyMesh.ink) on its limbs, hands, feet
##   and small parts, and FIGURE_INK_MASS on its three big masses (the helmet's orb or the
##   automaton's head block, the torso, the backpack or the power unit), so the figure keeps an
##   outline at the battle zoom: each builder sets it for its own parts and puts the mesh's value
##   back after, so a figure in a building's mesh (the escort troopers) is thin and the rest of that
##   mesh is not.

## How tall each figure stands at scale 1, and the primary proportion, in head units.
const COLONIST_HEIGHT := 0.8
const AUTOMATON_HEIGHT := 0.9
const PRIMARY_HEADS := 3.5

## The share of the full ink width a figure is outlined at: about 25 pixels tall at the gameplay
## zoom, it would drown in the buildings' line. FIGURE_INK on the limbs, hands, feet and small
## parts; FIGURE_INK_MASS on the big masses (the helmet's orb, the torso, the backpack), whose line
## at FIGURE_INK went under a pixel at camera size 24 and left the figure soft.
const FIGURE_INK := 0.5
const FIGURE_INK_MASS := 0.75

## The figure's left (+X, since it faces +Z) and right sides, indexing a Pose's and Joints' pairs.
const SIDES: Array[float] = [1.0, -1.0]

## The visor's glass: a deep blue-black, glossy, so its specular disc and the ENERGY highlight
## streak are what light it.
const VISOR_TINT := Color("1f2a4d")

## The figures' own surfaces: the army orange, smooth: on the plate layer (ARMY_PLATE, which the
## machines share), and flat (ARMY_SMALL) for the figures' small orange parts, all under 0.2 across
## (the chest plates, the shoulder pads, the helmet stripe, the gloves, the kneepads, the tank's
## caps, the automaton's thigh plates and toe caps), where the plate layer's panel seams would cut a
## part into quarters; the visor and its highlight streak (too thin for an outline); and the small
## glows, under 0.06 across and so not inked: the colonist's chest lamp (its one emissive element),
## the automaton's core in ENERGY and its antenna bulb in ARMY. The rest are Parts' surfaces, the
## security bot's and the ore hauler's among them, used where they are needed rather than copied
## here, since Parts calls into Figures while its own surfaces are still being made: the suit and
## the automaton's armour, thighs and upper arms Parts.HULL_LIGHT_ROUND, the suit's elbows, boots
## and backpack and the automaton's shins and forearms Parts.HULL_MID_ROUND, the automaton's foot
## pads Parts.HULL_MID, the belt, tank, automaton's joints and hands Parts.GUNMETAL, the boots'
## soles and the power unit Parts.HULL_DARK_ROUND, the automaton's visor band Parts.HULL_DARK, its
## visor slit and fan Parts.ESCORT_EYE, its antenna Parts.ROD. Shared: never change one.
static var ARMY_PLATE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.LIT, true)
static var ARMY_SMALL := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.ARMY, 1.0, Surf.LIT, true)
static var VISOR := Surf.make(MaterialKit.Layer.GLASS, VISOR_TINT, 1.0, Surf.GLOSSY, true)
static var VISOR_GLINT := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ENERGY, 1.0, Surf.GLOSSY, true, false)
static var LAMP_SMALL := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true, false)
static var BULB := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT, true, false)


## A figure's joint angles, in degrees. Pairs are [left, right]. Swings are forward (towards +Z),
## outs away from the body, bends forward for an elbow and back for a knee; a foot's pitch puts its
## toe down.
class Pose:
	extends RefCounted
	## The torso, about the waist: x leans it forward, y twists it.
	var torso := Vector3.ZERO
	## The head, about the neck, against the torso: x nods it forward, y turns it.
	var head := Vector3.ZERO
	var shoulder_swing := PackedFloat32Array([0.0, 0.0])
	var shoulder_out := PackedFloat32Array([0.0, 0.0])
	var elbow := PackedFloat32Array([0.0, 0.0])
	var hip_swing := PackedFloat32Array([0.0, 0.0])
	var hip_out := PackedFloat32Array([0.0, 0.0])
	var knee := PackedFloat32Array([0.0, 0.0])
	var foot_pitch := PackedFloat32Array([0.0, 0.0])


## A figure's lengths, from its height and proportion (_body). The joints' offsets are from the
## pelvis (hips, waist) or from the waist (shoulders, neck).
class Body:
	extends RefCounted
	## Widths and radii are given at COLONIST_HEIGHT and multiplied by this.
	var k := 1.0
	var head := 0.0
	var hip_x := 0.0
	var shoulder_x := 0.0
	var shoulder_y := 0.0
	var neck_y := 0.0
	var thigh := 0.0
	var shin := 0.0
	var ankle := 0.0
	## How far the sole reaches behind the ankle and in front of it, on the ground: a pitched foot
	## goes down at one of them.
	var sole_back := 0.0
	var sole_front := 0.0
	var upper_arm := 0.0
	var forearm := 0.0


## The rig stamps a rigged figure's segments carry (LowPolyMesh.rig, rig2; Rig.part), from walk_rig:
## each thigh turns about its hip, each shin and foot about its knee and then with the thigh about
## the hip; each upper arm about its shoulder, each forearm and hand about its elbow and then with
## the upper arm about the shoulder (the ranger's two arms on one stamp, so they move as a group);
## the head and the torso on `body`, the whole figure's joint (a flying figure's bank), which is
## also the parent of a segment with one joint of its own. A segment carries the first two of its
## chain's stamps that are set (a shin: knee, hip, body), so `body` reaches only segments with at
## most one joint of their own. Pairs are [left, right].
class Rigging:
	extends RefCounted
	var hips: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var knees: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var shoulders: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var elbows: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var body := Vector4.ZERO


## A posed skeleton: a Transform3D per joint, in the mesh's space. Each pair is [left, right].
class Joints:
	extends RefCounted
	var pelvis := Transform3D.IDENTITY
	var waist := Transform3D.IDENTITY
	var neck := Transform3D.IDENTITY
	var shoulders: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var elbows: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var wrists: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var hips: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var knees: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]
	var ankles: Array[Transform3D] = [Transform3D.IDENTITY, Transform3D.IDENTITY]


## Standing at ease: feet about shoulder width apart, knees a little bent, the torso tilted a few
## degrees forward and twisted a touch, the elbows bent and the arms a little out, no two sides
## alike.
static func stance() -> Pose:
	var pose := Pose.new()
	pose.torso = Vector3(6, 6, 0)
	pose.head = Vector3(-4, -8, 0)
	pose.shoulder_swing = PackedFloat32Array([8.0, -4.0])
	pose.shoulder_out = PackedFloat32Array([16.0, 12.0])
	pose.elbow = PackedFloat32Array([38.0, 24.0])
	pose.hip_swing = PackedFloat32Array([6.0, -5.0])
	pose.hip_out = PackedFloat32Array([11.0, 9.0])
	pose.knee = PackedFloat32Array([16.0, 10.0])
	pose.foot_pitch = PackedFloat32Array([-6.0, 5.0])
	return pose


## Standing straight, for a rigged build (walk_rig), which turns the legs from it: the legs straight
## down but for a touch of knee, a little apart, the torso tilted a few degrees forward with no
## twist (so the shoulders stay on one line across the figure, about which an arm group turns), the
## head level, the arms hanging a little forward and out. A caller sets the arms it holds a weapon
## with.
static func neutral() -> Pose:
	var pose := Pose.new()
	pose.torso = Vector3(4, 0, 0)
	pose.head = Vector3(-4, 0, 0)
	pose.shoulder_swing = PackedFloat32Array([6.0, 6.0])
	pose.shoulder_out = PackedFloat32Array([10.0, 10.0])
	pose.elbow = PackedFloat32Array([20.0, 20.0])
	pose.hip_swing = PackedFloat32Array([0.0, 0.0])
	pose.hip_out = PackedFloat32Array([5.0, 5.0])
	pose.knee = PackedFloat32Array([6.0, 6.0])
	pose.foot_pitch = PackedFloat32Array([0.0, 0.0])
	return pose


## The walking rig of a figure posed as `j` (neutral(), joints()): the legs on the hip and knee
## channels (`hip` and `knee`, the left's ids; the right's follow them), and the arms as one group
## on `arm_channel` (Rig.AIM for a gun held in both hands) about the shoulders' midpoint, or not
## rigged at 0.
static func walk_rig(j: Joints, arm_channel: int = 0, hip: int = Rig.HIP_L, knee: int = Rig.KNEE_L) -> Rigging:
	var rigging := Rigging.new()
	for s: int in 2:
		rigging.hips[s] = Rig.part(hip + s, j.hips[s].origin)
		rigging.knees[s] = Rig.part(knee + s, j.knees[s].origin)
	if arm_channel != 0:
		var arms := Rig.part(arm_channel, (j.shoulders[0].origin + j.shoulders[1].origin) * 0.5)
		rigging.shoulders = [arms, arms]
	return rigging


## The swinging arms of a rigging (walk_rig) for a figure posed as `j`: each upper arm on its
## SHOULDER channel and each forearm on its ELBOW channel, so they counter-swing as it walks (and
## punch as it attacks: Rig).
static func swing_arms(rigging: Rigging, j: Joints) -> void:
	for s: int in 2:
		rigging.shoulders[s] = Rig.part(Rig.SHOULDER_L + s, j.shoulders[s].origin)
		rigging.elbows[s] = Rig.part(Rig.ELBOW_L + s, j.elbows[s].origin)


## Mid-stride: walking upright, the left leg reaching forward with its knee bent and its heel coming
## down, the right nearly straight behind pushing off its toe, the arms counter-swung (the right
## forward with its elbow bent, the left back), the torso only a little forward and the head level.
static func stride() -> Pose:
	var pose := Pose.new()
	pose.torso = Vector3(4, -6, 0)
	pose.head = Vector3(-4, 4, 0)
	pose.shoulder_swing = PackedFloat32Array([-30.0, 32.0])
	pose.shoulder_out = PackedFloat32Array([7.0, 7.0])
	pose.elbow = PackedFloat32Array([14.0, 42.0])
	pose.hip_swing = PackedFloat32Array([34.0, -26.0])
	pose.hip_out = PackedFloat32Array([3.0, 3.0])
	pose.knee = PackedFloat32Array([18.0, 6.0])
	pose.foot_pitch = PackedFloat32Array([-14.0, 18.0])
	return pose


## Seated at the controls: the thighs level forward, the shins hanging straight down to feet flat
## on the floor, the torso upright and a touch back, both forearms reaching forward to the controls
## at chest height, the sides a little unalike. The lower sole stands on `foot`, so the seat goes
## under the pelvis (joints()).
static func seated() -> Pose:
	var pose := Pose.new()
	pose.torso = Vector3(-4, 4, 0)
	pose.head = Vector3(2, -6, 0)
	pose.shoulder_swing = PackedFloat32Array([42.0, 36.0])
	pose.shoulder_out = PackedFloat32Array([12.0, 10.0])
	pose.elbow = PackedFloat32Array([52.0, 60.0])
	pose.hip_swing = PackedFloat32Array([86.0, 82.0])
	pose.hip_out = PackedFloat32Array([9.0, 7.0])
	pose.knee = PackedFloat32Array([86.0, 82.0])
	pose.foot_pitch = PackedFloat32Array([0.0, 0.0])
	return pose


## A colonist in a spacesuit, `heads` tall: a round helmet with a dark curved visor and an orange
## stripe on a ring collar, a broad suit tapering to a belt, orange shoulder pads and chest plate
## with a glowing lamp, round-jointed tapered limbs with calves and orange kneepads, big orange
## gloves, chunky boots on dark soles, a backpack with a tank capped orange.
## Without `legs`, the thighs, shins and boots are left out (the legs still set where it sits): a
## pilot whose legs are hidden in its machine's hull. With `rigging` (walk_rig) its segments carry
## their rig stamps.
static func colonist(m: LowPolyMesh, foot: Vector3, yaw: float, pose: Pose, heads: float = PRIMARY_HEADS,
		scale: float = 1.0, legs: bool = true, rigging: Rigging = null) -> void:
	var b := _colonist_body(heads, scale)
	var j := _skeleton(b, pose, foot, yaw)
	var ink := m.ink
	m.ink = FIGURE_INK
	_rig_none(m, rigging)
	_helmet(m, j.neck, b)
	_suit_torso(m, j.waist, b)
	for s: int in 2:
		_rig_upper_arm(m, rigging, s)
		_suit_upper_arm(m, j.shoulders[s], b)
		_rig_forearm(m, rigging, s)
		_suit_forearm(m, j.elbows[s], b)
		_glove(m, j.wrists[s], b)
		if legs:
			_rig_thigh(m, rigging, s)
			_suit_thigh(m, j.hips[s], b)
			_rig_shin(m, rigging, s)
			_suit_shin(m, j.knees[s], b)
			_boot(m, j.ankles[s], b)
		_rig_none(m, rigging)
	m.ink = ink


## An automaton, the humanoid robot, on the colonist's skeleton: a cream sensor block for a head
## with one wide glowing visor slit and a short antenna, a cream chest armoured orange round a
## glowing core, gunmetal joint orbs, cream thighs plated orange and cream upper arms, hull-mid
## shins and forearms, gunmetal hands, tall foot pads with orange toe caps and a dorsal power unit.
## With `rigging` (walk_rig, on joints(..., true)) its segments carry their rig stamps.
static func automaton(m: LowPolyMesh, foot: Vector3, yaw: float, pose: Pose, heads: float = PRIMARY_HEADS,
		scale: float = 1.0, rigging: Rigging = null) -> void:
	var b := _automaton_body(heads, scale)
	var j := _skeleton(b, pose, foot, yaw)
	var ink := m.ink
	m.ink = FIGURE_INK
	_rig_none(m, rigging)
	_sensor_head(m, j.neck, b)
	_robot_torso(m, j.waist, b)
	for s: int in 2:
		_rig_upper_arm(m, rigging, s)
		_robot_upper_arm(m, j.shoulders[s], b)
		_rig_forearm(m, rigging, s)
		_robot_forearm(m, j.elbows[s], b)
		_robot_hand(m, j.wrists[s], b)
		_rig_thigh(m, rigging, s)
		_robot_thigh(m, j.hips[s], b)
		_rig_shin(m, rigging, s)
		_robot_shin(m, j.knees[s], b)
		_foot_pad(m, j.ankles[s], b)
		_rig_none(m, rigging)
	m.ink = ink


## The joints of a colonist, or with `robot` an automaton, as colonist() or automaton() poses it
## standing on `foot`: for a caller that adds to a figure (a rifle in its hands, a pack on its
## back) or seats it (the pelvis is where its seat goes).
static func joints(foot: Vector3, yaw: float, pose: Pose, heads: float = PRIMARY_HEADS, scale: float = 1.0,
		robot: bool = false) -> Joints:
	return _skeleton(_automaton_body(heads, scale) if robot else _colonist_body(heads, scale), pose, foot, yaw)


# --- The rig stamps (none without a Rigging) -----------------------------------------

static func _rig_upper_arm(m: LowPolyMesh, rigging: Rigging, s: int) -> void:
	if rigging != null:
		stamp(m, [rigging.shoulders[s], rigging.body])


static func _rig_forearm(m: LowPolyMesh, rigging: Rigging, s: int) -> void:
	if rigging != null:
		stamp(m, [rigging.elbows[s], rigging.shoulders[s], rigging.body])


static func _rig_thigh(m: LowPolyMesh, rigging: Rigging, s: int) -> void:
	if rigging != null:
		stamp(m, [rigging.hips[s], rigging.body])


static func _rig_shin(m: LowPolyMesh, rigging: Rigging, s: int) -> void:
	if rigging != null:
		stamp(m, [rigging.knees[s], rigging.hips[s], rigging.body])


static func _rig_none(m: LowPolyMesh, rigging: Rigging) -> void:
	if rigging != null:
		stamp(m, [rigging.body])


## Sets `m`'s rig and rig2 to the first two of `chain` (a segment's own joint first, then the ones
## it hangs from) that are set, zero where there are fewer.
static func stamp(m: LowPolyMesh, chain: Array[Vector4]) -> void:
	var found: Array[Vector4] = [Vector4.ZERO, Vector4.ZERO]
	var n := 0
	for joint: Vector4 in chain:
		if joint.w != 0.0 and n < 2:
			found[n] = joint
			n += 1
	m.rig = found[0]
	m.rig2 = found[1]


# --- The skeleton ----------------------------------------------------------------

## The colonist's lengths at `heads` and `scale`, its soles' reach included.
static func _colonist_body(heads: float, scale: float) -> Body:
	var b := _body(COLONIST_HEIGHT * scale, heads)
	b.sole_back = 0.062 * b.k
	b.sole_front = 0.111 * b.k
	return b


## The automaton's lengths at `heads` and `scale`, its foot pads' reach included.
static func _automaton_body(heads: float, scale: float) -> Body:
	var b := _body(AUTOMATON_HEIGHT * scale, heads)
	b.sole_back = 0.06 * b.k
	b.sole_front = 0.12 * b.k
	return b


## The lengths of a figure `height` tall and `heads` head units: the legs (to the hip joints,
## standing straight) 0.3 of the height at PRIMARY_HEADS, shorter with a bigger head, longer with a
## smaller one; the head unit the top 0.925 of a head over the neck; the torso between; the arms
## and the widths the same at any proportion.
static func _body(height: float, heads: float) -> Body:
	var b := Body.new()
	b.k = height / COLONIST_HEIGHT
	b.head = height / heads
	var legs := height * (0.3 + (heads - PRIMARY_HEADS) * 0.06)
	b.neck_y = height - b.head * 0.925 - legs
	b.shoulder_y = b.neck_y - 0.06 * b.k
	b.ankle = 0.055 * b.k
	b.thigh = (legs - b.ankle) * 0.5
	b.shin = b.thigh
	b.hip_x = 0.05 * b.k
	b.shoulder_x = 0.12 * b.k
	b.upper_arm = 0.12 * b.k
	b.forearm = 0.1 * b.k
	return b


## The joints of `b` posed as `pose`, standing on `foot` facing +Z turned `yaw` degrees: the legs
## posed from a pelvis at the origin first, to find how far the lower sole hangs (its heel or its
## toe, as its foot is pitched), then everything from the pelvis lifted so that sole is on `foot`.
static func _skeleton(b: Body, pose: Pose, foot: Vector3, yaw: float) -> Joints:
	var turn := Basis.from_euler(Vector3(0, deg_to_rad(yaw), 0))
	var lowest := 0.0
	for s: int in 2:
		var ankle := _leg(b, pose, Transform3D(turn, Vector3.ZERO), s)[2]
		for z: float in [-b.sole_back, b.sole_front]:
			lowest = minf(lowest, (ankle * Vector3(0, -b.ankle, z)).y)
	var j := Joints.new()
	j.pelvis = Transform3D(turn, foot - Vector3(0, lowest, 0))
	j.waist = j.pelvis * Transform3D(_basis(pose.torso), Vector3.ZERO)
	j.neck = j.waist * Transform3D(_basis(pose.head), Vector3(0, b.neck_y, 0))
	for s: int in 2:
		var side := SIDES[s]
		j.shoulders[s] = j.waist * Transform3D(_basis(Vector3(-pose.shoulder_swing[s], 0, side * pose.shoulder_out[s])),
			Vector3(side * b.shoulder_x, b.shoulder_y, 0))
		j.elbows[s] = j.shoulders[s] * Transform3D(_basis(Vector3(-pose.elbow[s], 0, 0)), Vector3(0, -b.upper_arm, 0))
		j.wrists[s] = j.elbows[s] * Transform3D(Basis.IDENTITY, Vector3(0, -b.forearm, 0))
		var leg := _leg(b, pose, j.pelvis, s)
		j.hips[s] = leg[0]
		j.knees[s] = leg[1]
		j.ankles[s] = leg[2]
	return j


## Side `s`'s hip, knee and ankle from `pelvis`. The ankle keeps the pelvis's heading, its foot
## pitched by the pose only, so a foot stays level whatever the leg does.
static func _leg(b: Body, pose: Pose, pelvis: Transform3D, s: int) -> Array[Transform3D]:
	var side := SIDES[s]
	var hip := pelvis * Transform3D(_basis(Vector3(-pose.hip_swing[s], 0, side * pose.hip_out[s])),
		Vector3(side * b.hip_x, 0, 0))
	var knee := hip * Transform3D(_basis(Vector3(pose.knee[s], 0, 0)), Vector3(0, -b.thigh, 0))
	var ankle := Transform3D(pelvis.basis * _basis(Vector3(pose.foot_pitch[s], 0, 0)), knee * Vector3(0, -b.shin, 0))
	return [hip, knee, ankle]


## The Basis of Euler `degrees`, in the order LowPolyMesh's parts take them.
static func _basis(degrees: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))


## The Euler degrees, as LowPolyMesh's parts take them, of the joint `xf` turned further by
## `degrees` in its own space.
static func _rot(xf: Transform3D, degrees: Vector3 = Vector3.ZERO) -> Vector3:
	var euler := (xf.basis * _basis(degrees)).get_euler()
	return Vector3(rad_to_deg(euler.x), rad_to_deg(euler.y), rad_to_deg(euler.z))


## A lathe hanging from the joint `xf` along its -Y: `profile` as LowPolyMesh.lathe takes it, its
## height measured down the segment from the joint.
static func _hang(m: LowPolyMesh, xf: Transform3D, profile: PackedVector2Array, sides: int, surface: Surf) -> void:
	m.lathe(profile, sides, xf.origin, surface, _rot(xf, Vector3(180, 0, 0)))


## A tapered limb segment from the joint `xf` down `length`, `top` to `bottom` in radius, open at
## both ends, which sit in the joint orbs; `sides` round.
static func _limb(m: LowPolyMesh, xf: Transform3D, length: float, top: float, bottom: float, surface: Surf,
		sides: int) -> void:
	_hang(m, xf, PackedVector2Array([Vector2(top, 0), Vector2(bottom, length)]), sides, surface)


## A sector of a sphere of `radius` round `centre` in the joint `xf`'s space, `depth` thick inwards,
## from elevation `low` to `high` and from `from_deg` to `to_deg` round its +Y (degrees, 90 the
## front): a visor, a plate on a round chest.
static func _shell(m: LowPolyMesh, xf: Transform3D, centre: Vector3, radius: float, depth: float, low: float,
		high: float, from_deg: float, to_deg: float, surface: Surf, steps: int = 3) -> void:
	var profile := PackedVector2Array()
	for i: int in steps + 1:
		var e := deg_to_rad(lerpf(low, high, float(i) / steps))
		profile.append(Vector2(radius * cos(e), radius * sin(e)))
	for i: int in range(steps, -1, -1):
		var e := deg_to_rad(lerpf(low, high, float(i) / steps))
		profile.append(Vector2((radius - depth) * cos(e), (radius - depth) * sin(e)))
	m.lathe(profile, 16, xf * centre, surface, _rot(xf), from_deg, to_deg)


# --- The colonist's segments -------------------------------------------------------

## The helmet on the neck joint `xf`: a ring collar, the round helmet sitting on it, a dark curved
## visor across its front with a cyan glint, and an orange stripe over its crown front to back.
static func _helmet(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	var r := b.head * 0.5
	m.lathe(PackedVector2Array([
		Vector2(0.07 * k, -0.035 * k), Vector2(0.08 * k, -0.012 * k), Vector2(0.068 * k, 0.014 * k),
		Vector2(0, 0.014 * k),
	]), 12, xf.origin, Parts.HULL_MID_ROUND, _rot(xf))
	var centre := Vector3(0, b.head * 0.925 - r, 0)
	var ink := m.ink
	m.ink = FIGURE_INK_MASS
	m.orb(r, 16, 6, xf * centre, Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.ink = ink
	_shell(m, xf, centre, r * 1.03, r * 0.08, -32.0, 26.0, 38.0, 142.0, VISOR, 2)
	_shell(m, xf, centre, r * 1.045, r * 0.02, 12.0, 19.0, 62.0, 98.0, VISOR_GLINT, 1)
	# The stripe: a band round the helmet's X axis, from the nape over the crown to the visor's top.
	var half := 0.024 * k
	m.tube(r * 0.9, r * 1.025, half * 2.0, 12, xf * (centre + Vector3(half, 0, 0)), ARMY_SMALL,
		_rot(xf, Vector3(0, 0, 90)), -115.0, 46.0)


## The torso on the waist joint `xf`: the suit broad at the chest, in at the waist and out again
## at the hips, a gunmetal belt, the orange chest plate with a glowing lamp, orange shoulder pads
## over the arm joints, and the backpack with its gunmetal tank, capped orange at both ends.
static func _suit_torso(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	var top := b.neck_y - 0.015 * k
	var ink := m.ink
	m.ink = FIGURE_INK_MASS
	m.lathe(PackedVector2Array([
		Vector2(0.078 * k, -0.06 * k), Vector2(0.088 * k, -0.015 * k), Vector2(0.078 * k, top * 0.2),
		Vector2(0.104 * k, top * 0.62), Vector2(0.098 * k, top * 0.86), Vector2(0.07 * k, top * 0.98),
		Vector2(0, top),
	]), 12, xf.origin, Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.ink = ink
	m.lathe(PackedVector2Array([
		Vector2(0.088 * k, top * 0.12), Vector2(0.088 * k, top * 0.25), Vector2(0.06 * k, top * 0.27),
	]), 12, xf.origin, Parts.GUNMETAL, _rot(xf))
	# The chest plate: a curved sector over the front of the chest, standing proud of the suit.
	m.lathe(PackedVector2Array([
		Vector2(0.094 * k, top * 0.42), Vector2(0.11 * k, top * 0.62), Vector2(0.103 * k, top * 0.86),
		Vector2(0.083 * k, top * 0.86), Vector2(0.09 * k, top * 0.62), Vector2(0.074 * k, top * 0.42),
	]), 16, xf.origin, ARMY_SMALL, _rot(xf), 45.0, 135.0)
	m.orb(0.024 * k, 8, 3, xf * Vector3(0.036 * k, top * 0.66, 0.104 * k), LAMP_SMALL, _rot(xf))
	for side: float in SIDES:
		m.dome(0.066 * k, 0.056 * k, 12, 2, xf * Vector3(side * b.shoulder_x, b.shoulder_y + 0.008 * k, 0), ARMY_SMALL,
			_rot(xf, Vector3(0, 0, -side * 28.0)))
	var pack := Vector3(0, top * 0.36, -0.1 * k)
	m.ink = FIGURE_INK_MASS
	m.box_chamfered(Vector3(0.17, 0.21, 0.09) * k, 0.035 * k, xf * pack, Parts.HULL_MID_ROUND, _rot(xf))
	# The tank: a capsule lying across the top of the pack, its rounded ends orange caps.
	var length := 0.18 * k
	var tank_radius := 0.036 * k
	var cap := tank_radius * 0.7
	var tank := xf * (pack + Vector3(length * 0.5, 0.21 * k + tank_radius * 0.6, -0.01 * k))
	var along := _rot(xf, Vector3(0, 0, 90))
	m.lathe(PackedVector2Array([Vector2(0, 0), Vector2(tank_radius, cap)]), 10, tank, ARMY_SMALL, along)
	m.lathe(PackedVector2Array([Vector2(tank_radius, cap), Vector2(tank_radius, length - cap)]), 10, tank, Parts.GUNMETAL,
		along)
	m.lathe(PackedVector2Array([Vector2(tank_radius, length - cap), Vector2(0, length)]), 10, tank, ARMY_SMALL, along)
	m.ink = ink


## The upper arm from the shoulder joint `xf`: a puffy tapered sleeve, its top under the shoulder
## pad.
static func _suit_upper_arm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	_limb(m, xf, b.upper_arm, 0.052 * b.k, 0.046 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The forearm from the elbow joint `xf`: the elbow's joint orb and a sleeve flaring into a cuff
## over the glove.
static func _suit_forearm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.05 * b.k, 8, 3, xf.origin, Parts.HULL_MID_ROUND)
	_limb(m, xf, b.forearm, 0.044 * b.k, 0.048 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The glove from the wrist joint `xf`: a chunky rounded orange mitt, fatter than the cuff.
static func _glove(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	_hang(m, xf, PackedVector2Array([
		Vector2(0.046 * k, -0.012 * k), Vector2(0.064 * k, 0.032 * k), Vector2(0.048 * k, 0.08 * k), Vector2(0, 0.092 * k),
	]), 10, ARMY_SMALL)


## The thigh from the hip joint `xf`: a rounded hip and a puffy tapered leg.
static func _suit_thigh(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.066 * b.k, 8, 3, xf.origin, Parts.HULL_LIGHT_ROUND)
	_limb(m, xf, b.thigh, 0.07 * b.k, 0.06 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The shin from the knee joint `xf`: an orange kneepad over the knee and a leg swelling to a calf
## and in again to the boot.
static func _suit_shin(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.064 * b.k, 8, 3, xf.origin, ARMY_SMALL)
	_hang(m, xf, PackedVector2Array([
		Vector2(0.054 * b.k, 0), Vector2(0.06 * b.k, b.shin * 0.4), Vector2(0.048 * b.k, b.shin),
	]), 12, Parts.HULL_LIGHT_ROUND)


## The boot on the ankle joint `xf`: a chunky round shaft to the ground on a dark sole band, and a
## domed toe cap in front of it.
static func _boot(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	var sole := -b.ankle + 0.02 * k
	m.lathe(PackedVector2Array([Vector2(0.062 * k, -b.ankle), Vector2(0.066 * k, sole)]), 10, xf.origin,
		Parts.HULL_DARK_ROUND, _rot(xf))
	m.lathe(PackedVector2Array([Vector2(0.066 * k, sole), Vector2(0.056 * k, 0.012 * k), Vector2(0, 0.012 * k)]), 10,
		xf.origin, Parts.HULL_MID_ROUND, _rot(xf))
	m.dome(0.068 * k, 0.058 * k, 10, 2, xf * Vector3(0, -b.ankle, 0.043 * k), Parts.HULL_MID_ROUND, _rot(xf))


# --- The automaton's segments ------------------------------------------------------

## The sensor head on the neck joint `xf`: a gunmetal neck joint, a cream chamfered block with a
## dark visor band and one wide glowing slit across its front, gunmetal sensor ears and a short
## antenna with an orange bulb.
static func _sensor_head(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.orb(0.04 * k, 8, 4, xf.origin, Parts.GUNMETAL)
	var base := b.head * 0.14
	var tall := b.head * 0.925 - base
	var depth := 0.17 * k
	var ink := m.ink
	m.ink = FIGURE_INK_MASS
	m.box_chamfered(Vector3(0.2 * k, tall, depth), 0.045 * k, xf * Vector3(0, base, 0), Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.ink = ink
	var face := depth * 0.5
	m.box_chamfered(Vector3(0.18 * k, tall * 0.36, 0.03 * k), 0.012 * k, xf * Vector3(0, base + tall * 0.42, face - 0.01 * k),
		Parts.HULL_DARK, _rot(xf))
	m.box_chamfered(Vector3(0.15 * k, tall * 0.16, 0.03 * k), 0.01 * k, xf * Vector3(0, base + tall * 0.52, face + 0.002 * k),
		Parts.ESCORT_EYE, _rot(xf))
	for side: float in SIDES:
		m.prism(0.04 * k, 0.034 * k, 0.03 * k, 10, xf * Vector3(side * 0.1 * k, base + tall * 0.5, 0), Parts.GUNMETAL,
			_rot(xf, Vector3(0, 0, -side * 90.0)))
	var mast := Vector3(0.05 * k, base + tall, -0.03 * k)
	m.lathe(PackedVector2Array([Vector2(0.009 * k, 0), Vector2(0.007 * k, 0.07 * k)]), 8, xf * mast, Parts.ROD, _rot(xf))
	m.orb(0.022 * k, 8, 3, xf * (mast + Vector3(0, 0.07 * k, 0)), BULB, _rot(xf))


## The torso on the waist joint `xf`: a gunmetal pelvis block and waist actuator under a cream
## chest broad at the shoulders, its front plated orange round a glowing core in a gunmetal rim,
## gunmetal shoulder joints, and the dorsal power unit with its glowing fan.
static func _robot_torso(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	var top := b.neck_y - 0.015 * k
	m.box_chamfered(Vector3(0.17, 0.08, 0.11) * k, 0.03 * k, xf * Vector3(0, -0.05 * k, 0), Parts.GUNMETAL, _rot(xf))
	m.lathe(PackedVector2Array([
		Vector2(0.06 * k, 0.0), Vector2(0.064 * k, top * 0.1), Vector2(0.056 * k, top * 0.3),
	]), 12, xf.origin, Parts.GUNMETAL, _rot(xf))
	var ink := m.ink
	m.ink = FIGURE_INK_MASS
	m.lathe(PackedVector2Array([
		Vector2(0.07 * k, top * 0.26), Vector2(0.094 * k, top * 0.5), Vector2(0.104 * k, top * 0.76),
		Vector2(0.096 * k, top * 0.92), Vector2(0.06 * k, top), Vector2(0, top),
	]), 12, xf.origin, Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.ink = ink
	m.lathe(PackedVector2Array([
		Vector2(0.097 * k, top * 0.46), Vector2(0.109 * k, top * 0.74), Vector2(0.1 * k, top * 0.9),
		Vector2(0.08 * k, top * 0.9), Vector2(0.09 * k, top * 0.74), Vector2(0.078 * k, top * 0.46),
	]), 16, xf.origin, ARMY_SMALL, _rot(xf), 35.0, 145.0)
	var core := Vector3(0, top * 0.68, 0.1 * k)
	m.ring(0.026 * k, 0.04 * k, 0.016 * k, 10, xf * core, Parts.GUNMETAL, _rot(xf, Vector3(90, 0, 0)))
	m.orb(0.028 * k, 8, 3, xf * core, LAMP_SMALL, _rot(xf))
	for side: float in SIDES:
		m.orb(0.05 * k, 8, 4, xf * Vector3(side * b.shoulder_x, b.shoulder_y, 0), Parts.GUNMETAL, _rot(xf))
	var unit := Vector3(0, top * 0.4, -0.095 * k)
	m.ink = FIGURE_INK_MASS
	m.box_chamfered(Vector3(0.15, 0.19, 0.08) * k, 0.035 * k, xf * unit, Parts.HULL_DARK_ROUND, _rot(xf))
	m.ink = ink
	var fan := unit + Vector3(0, 0.1 * k, -0.04 * k)
	Parts.drum(m, 0.05 * k, 0.025 * k, 0.01 * k, 10, xf * fan, Parts.GUNMETAL, _rot(xf, Vector3(-90, 0, 0)))
	m.disc(0.034 * k, 10, xf * (fan + Vector3(0, 0, -0.026 * k)), Parts.ESCORT_EYE, _rot(xf, Vector3(-90, 0, 0)))


## The upper arm from the shoulder joint `xf`: a cream tapered limb.
static func _robot_upper_arm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	_limb(m, xf, b.upper_arm, 0.05 * b.k, 0.044 * b.k, Parts.HULL_LIGHT_ROUND, 10)


## The forearm from the elbow joint `xf`: the elbow's joint orb and a tapered limb.
static func _robot_forearm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.orb(0.05 * k, 8, 3, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.forearm, 0.05 * k, 0.042 * k, Parts.HULL_MID_ROUND, 10)


## The hand from the wrist joint `xf`: a gunmetal mitt.
static func _robot_hand(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	_hang(m, xf, PackedVector2Array([
		Vector2(0.034 * k, -0.01 * k), Vector2(0.05 * k, 0.026 * k), Vector2(0.036 * k, 0.066 * k), Vector2(0, 0.074 * k),
	]), 8, Parts.GUNMETAL)


## The thigh from the hip joint `xf`: the hip's joint orb, a cream tapered limb and an orange plate
## down its front, 0.1 by 0.12.
static func _robot_thigh(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.orb(0.058 * k, 8, 3, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.thigh, 0.064 * k, 0.056 * k, Parts.HULL_LIGHT_ROUND, 10)
	m.box_chamfered(Vector3(0.1, 0.12, 0.03) * k, 0.012 * k, xf * Vector3(0, -0.13 * k, 0.05 * k), ARMY_SMALL, _rot(xf))


## The shin from the knee joint `xf`: the knee's joint orb and a tapered limb.
static func _robot_shin(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.orb(0.058 * k, 8, 3, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.shin, 0.06 * k, 0.05 * k, Parts.HULL_MID_ROUND, 10)


## The foot on the ankle joint `xf`: a tall chamfered pad over the shin's foot, an orange toe cap
## over its front.
static func _foot_pad(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.box_chamfered(Vector3(0.12, 0.07, 0.18) * k, 0.03 * k, xf * Vector3(0, -b.ankle, 0.03 * k), Parts.HULL_MID, _rot(xf))
	# A step proud of the pad's front, so their faces never share a plane.
	m.box_chamfered(Vector3(0.128, 0.078, 0.05) * k, 0.024 * k, xf * Vector3(0, -b.ankle, 0.105 * k), ARMY_SMALL, _rot(xf))
