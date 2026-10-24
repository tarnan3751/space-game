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
##   changing angles, and a unit pipeline can later build each segment on its own.
## - Nothing here moves: there are no moving parts and no Motion. The poses are static.

## How tall each figure stands at scale 1, and the primary proportion, in head units.
const COLONIST_HEIGHT := 0.8
const AUTOMATON_HEIGHT := 0.9
const PRIMARY_HEADS := 3.5

## The figure's left (+X, since it faces +Z) and right sides, indexing a Pose's and Joints' pairs.
const SIDES: Array[float] = [1.0, -1.0]

## The visor's glass: a deep blue-black, glossy, so its specular disc and the ENERGY highlight
## streak are what light it.
const VISOR_TINT := Color("1f2a4d")

## The figures' own surfaces: the army-orange chest plates, shoulder pads and helmet stripe, smooth;
## the visor and its highlight streak (too thin for an outline); and the small glows, under 0.06
## across and so not inked: the colonist's chest lamp (its one emissive element), the automaton's
## core in ENERGY and its antenna bulb in ARMY. The rest are Parts' surfaces, the security bot's
## and the ore hauler's among them, used where they are needed rather than copied here, since
## Parts calls into Figures while its own surfaces are still being made: the suit and the
## automaton's armour Parts.HULL_LIGHT_ROUND, the suit's joints and the automaton's limbs
## Parts.HULL_MID_ROUND, the belt, tank, automaton's joints and hands Parts.GUNMETAL, the gloves,
## boots, backpack and power unit Parts.HULL_DARK_ROUND, the automaton's visor band and foot pads
## Parts.HULL_DARK, its visor slit and fan Parts.ESCORT_EYE, its pistons Parts.ROD. Shared: never
## change one.
static var ARMY_PLATE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.LIT, true)
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


## A colonist in a spacesuit, `heads` tall: a round helmet with a dark curved visor and an orange
## stripe on a ring collar, a broad suit tapering to a belt, orange shoulder pads and chest plate
## with a glowing lamp, round-jointed tapered limbs, big gloves and boots, a backpack with a tank.
static func colonist(m: LowPolyMesh, foot: Vector3, yaw: float, pose: Pose, heads: float = PRIMARY_HEADS,
		scale: float = 1.0) -> void:
	var b := _body(COLONIST_HEIGHT * scale, heads)
	b.sole_back = 0.062 * b.k
	b.sole_front = 0.111 * b.k
	var j := _skeleton(b, pose, foot, yaw)
	_helmet(m, j.neck, b)
	_suit_torso(m, j.waist, b)
	for s: int in 2:
		_suit_upper_arm(m, j.shoulders[s], b)
		_suit_forearm(m, j.elbows[s], b)
		_glove(m, j.wrists[s], b)
		_suit_thigh(m, j.hips[s], b)
		_suit_shin(m, j.knees[s], b)
		_boot(m, j.ankles[s], b)


## An automaton, the humanoid robot, on the colonist's skeleton: a cream sensor block for a head
## with one wide glowing visor slit and a short antenna, a cream chest armoured orange round a
## glowing core, gunmetal joint orbs at every joint, hull-mid tapered limbs with pistons along the
## forearms and shins, gunmetal hands, broad flat foot pads and a dorsal power unit.
static func automaton(m: LowPolyMesh, foot: Vector3, yaw: float, pose: Pose, heads: float = PRIMARY_HEADS,
		scale: float = 1.0) -> void:
	var b := _body(AUTOMATON_HEIGHT * scale, heads)
	b.sole_back = 0.06 * b.k
	b.sole_front = 0.12 * b.k
	var j := _skeleton(b, pose, foot, yaw)
	_sensor_head(m, j.neck, b)
	_robot_torso(m, j.waist, b)
	for s: int in 2:
		_robot_upper_arm(m, j.shoulders[s], b)
		_robot_forearm(m, j.elbows[s], b, SIDES[s])
		_robot_hand(m, j.wrists[s], b)
		_robot_thigh(m, j.hips[s], b)
		_robot_shin(m, j.knees[s], b, SIDES[s])
		_foot_pad(m, j.ankles[s], b)


# --- The skeleton ----------------------------------------------------------------

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
	m.orb(r, 16, 6, xf * centre, Parts.HULL_LIGHT_ROUND, _rot(xf))
	_shell(m, xf, centre, r * 1.03, r * 0.08, -32.0, 26.0, 38.0, 142.0, VISOR, 2)
	_shell(m, xf, centre, r * 1.045, r * 0.02, 12.0, 19.0, 62.0, 98.0, VISOR_GLINT, 1)
	# The stripe: a band round the helmet's X axis, from the nape over the crown to the visor's top.
	var half := 0.024 * k
	m.tube(r * 0.9, r * 1.025, half * 2.0, 12, xf * (centre + Vector3(half, 0, 0)), ARMY_PLATE,
		_rot(xf, Vector3(0, 0, 90)), -120.0, 46.0)


## The torso on the waist joint `xf`: the suit broad at the chest, in at the waist and out again
## at the hips, a gunmetal belt, the orange chest plate with a glowing lamp, orange shoulder pads
## over the arm joints, and the backpack with its tank.
static func _suit_torso(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	var top := b.neck_y - 0.015 * k
	m.lathe(PackedVector2Array([
		Vector2(0.078 * k, -0.06 * k), Vector2(0.088 * k, -0.015 * k), Vector2(0.078 * k, top * 0.2),
		Vector2(0.104 * k, top * 0.62), Vector2(0.098 * k, top * 0.86), Vector2(0.07 * k, top * 0.98),
		Vector2(0, top),
	]), 12, xf.origin, Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.lathe(PackedVector2Array([
		Vector2(0.088 * k, top * 0.12), Vector2(0.088 * k, top * 0.25), Vector2(0.06 * k, top * 0.27),
	]), 12, xf.origin, Parts.GUNMETAL, _rot(xf))
	# The chest plate: a curved sector over the front of the chest, standing proud of the suit.
	m.lathe(PackedVector2Array([
		Vector2(0.094 * k, top * 0.42), Vector2(0.11 * k, top * 0.62), Vector2(0.103 * k, top * 0.86),
		Vector2(0.083 * k, top * 0.86), Vector2(0.09 * k, top * 0.62), Vector2(0.074 * k, top * 0.42),
	]), 16, xf.origin, ARMY_PLATE, _rot(xf), 45.0, 135.0)
	m.orb(0.024 * k, 8, 3, xf * Vector3(0.036 * k, top * 0.66, 0.104 * k), LAMP_SMALL, _rot(xf))
	for side: float in SIDES:
		m.dome(0.066 * k, 0.056 * k, 12, 2, xf * Vector3(side * b.shoulder_x, b.shoulder_y + 0.008 * k, 0), ARMY_PLATE,
			_rot(xf, Vector3(0, 0, -side * 28.0)))
	var pack := Vector3(0, top * 0.36, -0.1 * k)
	m.box_chamfered(Vector3(0.17, 0.21, 0.09) * k, 0.035 * k, xf * pack, Parts.HULL_DARK_ROUND, _rot(xf))
	# The tank: a capsule lying across the top of the pack.
	var length := 0.18 * k
	var tank_radius := 0.036 * k
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(tank_radius, tank_radius * 0.7), Vector2(tank_radius, length - tank_radius * 0.7),
		Vector2(0, length),
	]), 10, xf * (pack + Vector3(length * 0.5, 0.21 * k + tank_radius * 0.6, -0.01 * k)), Parts.GUNMETAL,
		_rot(xf, Vector3(0, 0, 90)))


## The upper arm from the shoulder joint `xf`: a puffy tapered sleeve, its top under the shoulder
## pad.
static func _suit_upper_arm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	_limb(m, xf, b.upper_arm, 0.044 * b.k, 0.038 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The forearm from the elbow joint `xf`: the elbow's joint orb and a tapered sleeve.
static func _suit_forearm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.042 * b.k, 8, 4, xf.origin, Parts.HULL_MID_ROUND)
	_limb(m, xf, b.forearm, 0.04 * b.k, 0.034 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The glove from the wrist joint `xf`: a chunky rounded mitt, fatter than the sleeve.
static func _glove(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	_hang(m, xf, PackedVector2Array([
		Vector2(0.04 * k, -0.012 * k), Vector2(0.056 * k, 0.03 * k), Vector2(0.04 * k, 0.074 * k), Vector2(0, 0.084 * k),
	]), 10, Parts.HULL_DARK_ROUND)


## The thigh from the hip joint `xf`: a rounded hip and a puffy tapered leg.
static func _suit_thigh(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.056 * b.k, 8, 3, xf.origin, Parts.HULL_LIGHT_ROUND)
	_limb(m, xf, b.thigh, 0.058 * b.k, 0.05 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The shin from the knee joint `xf`: the knee's joint orb and a tapered leg.
static func _suit_shin(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.052 * b.k, 8, 4, xf.origin, Parts.HULL_MID_ROUND)
	_limb(m, xf, b.shin, 0.05 * b.k, 0.047 * b.k, Parts.HULL_LIGHT_ROUND, 12)


## The boot on the ankle joint `xf`: a chunky round shaft to the ground and a domed toe cap in
## front of it.
static func _boot(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.lathe(PackedVector2Array([
		Vector2(0.062 * k, -b.ankle), Vector2(0.064 * k, -b.ankle + 0.03 * k), Vector2(0.054 * k, 0.012 * k),
		Vector2(0, 0.012 * k),
	]), 10, xf.origin, Parts.HULL_DARK_ROUND, _rot(xf))
	m.dome(0.056 * k, 0.052 * k, 10, 2, xf * Vector3(0, -b.ankle, 0.055 * k), Parts.HULL_DARK_ROUND, _rot(xf))


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
	m.box_chamfered(Vector3(0.2 * k, tall, depth), 0.045 * k, xf * Vector3(0, base, 0), Parts.HULL_LIGHT_ROUND, _rot(xf))
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
	m.lathe(PackedVector2Array([
		Vector2(0.07 * k, top * 0.26), Vector2(0.094 * k, top * 0.5), Vector2(0.104 * k, top * 0.76),
		Vector2(0.096 * k, top * 0.92), Vector2(0.06 * k, top), Vector2(0, top),
	]), 12, xf.origin, Parts.HULL_LIGHT_ROUND, _rot(xf))
	m.lathe(PackedVector2Array([
		Vector2(0.097 * k, top * 0.46), Vector2(0.109 * k, top * 0.74), Vector2(0.1 * k, top * 0.9),
		Vector2(0.08 * k, top * 0.9), Vector2(0.09 * k, top * 0.74), Vector2(0.078 * k, top * 0.46),
	]), 16, xf.origin, ARMY_PLATE, _rot(xf), 35.0, 145.0)
	var core := Vector3(0, top * 0.68, 0.1 * k)
	m.ring(0.026 * k, 0.04 * k, 0.016 * k, 10, xf * core, Parts.GUNMETAL, _rot(xf, Vector3(90, 0, 0)))
	m.orb(0.028 * k, 8, 3, xf * core, LAMP_SMALL, _rot(xf))
	for side: float in SIDES:
		m.orb(0.05 * k, 8, 4, xf * Vector3(side * b.shoulder_x, b.shoulder_y, 0), Parts.GUNMETAL, _rot(xf))
	var unit := Vector3(0, top * 0.4, -0.095 * k)
	m.box_chamfered(Vector3(0.15, 0.19, 0.08) * k, 0.035 * k, xf * unit, Parts.HULL_DARK_ROUND, _rot(xf))
	var fan := unit + Vector3(0, 0.1 * k, -0.04 * k)
	Parts.drum(m, 0.05 * k, 0.025 * k, 0.01 * k, 10, xf * fan, Parts.GUNMETAL, _rot(xf, Vector3(-90, 0, 0)))
	m.disc(0.034 * k, 10, xf * (fan + Vector3(0, 0, -0.026 * k)), Parts.ESCORT_EYE, _rot(xf, Vector3(-90, 0, 0)))


## The upper arm from the shoulder joint `xf`: a slim tapered limb.
static func _robot_upper_arm(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	_limb(m, xf, b.upper_arm, 0.036 * b.k, 0.03 * b.k, Parts.HULL_MID_ROUND, 10)


## The forearm from the elbow joint `xf`: the elbow's joint orb, a tapered limb, and a piston rod
## along its outside on side `side`.
static func _robot_forearm(m: LowPolyMesh, xf: Transform3D, b: Body, side: float) -> void:
	var k := b.k
	m.orb(0.04 * k, 8, 4, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.forearm, 0.038 * k, 0.03 * k, Parts.HULL_MID_ROUND, 10)
	Parts.pipe(m, xf * Vector3(side * 0.042 * k, -0.02 * k, 0), xf * Vector3(side * 0.036 * k, -b.forearm + 0.01 * k, 0),
		0.008 * k, Parts.ROD, 8, false)


## The hand from the wrist joint `xf`: a gunmetal mitt.
static func _robot_hand(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	_hang(m, xf, PackedVector2Array([
		Vector2(0.034 * k, -0.01 * k), Vector2(0.05 * k, 0.026 * k), Vector2(0.036 * k, 0.066 * k), Vector2(0, 0.074 * k),
	]), 8, Parts.GUNMETAL)


## The thigh from the hip joint `xf`: the hip's joint orb and a tapered limb.
static func _robot_thigh(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	m.orb(0.046 * b.k, 8, 4, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.thigh, 0.046 * b.k, 0.038 * b.k, Parts.HULL_MID_ROUND, 10)


## The shin from the knee joint `xf`: the knee's joint orb, a calf-shaped limb, and a piston rod
## along its outside on side `side`.
static func _robot_shin(m: LowPolyMesh, xf: Transform3D, b: Body, side: float) -> void:
	var k := b.k
	m.orb(0.046 * k, 8, 4, xf.origin, Parts.GUNMETAL)
	_limb(m, xf, b.shin, 0.046 * k, 0.036 * k, Parts.HULL_MID_ROUND, 10)
	Parts.pipe(m, xf * Vector3(side * 0.052 * k, -0.02 * k, -0.01 * k), xf * Vector3(side * 0.043 * k, -b.shin, -0.01 * k),
		0.009 * k, Parts.ROD, 8, false)


## The foot on the ankle joint `xf`: a gunmetal ankle joint over a broad flat chamfered pad.
static func _foot_pad(m: LowPolyMesh, xf: Transform3D, b: Body) -> void:
	var k := b.k
	m.orb(0.036 * k, 8, 3, xf.origin, Parts.GUNMETAL)
	m.box_chamfered(Vector3(0.12, 0.045, 0.18) * k, 0.03 * k, xf * Vector3(0, -b.ankle, 0.03 * k), Parts.HULL_DARK, _rot(xf))
