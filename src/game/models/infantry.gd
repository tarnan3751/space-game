extends RefCounted
## The infantry's models (docs/reference/art-style.md, **Units**): the ranger, the breacher and the
## jet trooper, colonists (Figures.colonist), and the brawler, an automaton (Figures.automaton),
## each with what it wears and carries built on the figure's joints (Figures.joints), each piece a
## function of its own taking its joint's transform. What a figure wears and carries is drawn in
## the figures' thinner ink (Figures.FIGURE_INK), like the figure. The tier repaints the trim, the
## glows and the brawler's armour (UnitModels.trim, UnitModels.glow, UnitModels.hull); the suits keep
## the colonist's paint.

## The ranger's rifle, held at low ready: how far it reaches behind the grip hand and past the
## fore hand, the way it points (forward and 30 degrees down, raised level when it aims: Rig.AIM)
## and how far along it the fore hand holds it from the grip.
const STOCK_LENGTH := 0.1
const BARREL_LENGTH := 0.13
const LOW_READY := Vector3(0.0, -0.5, 0.866)
const FORE_SPAN := 0.07

## The breacher's colonist scale (0.85 tall) and the brawler's automaton scale (about 1.0 tall to
## its antenna, crouched).
const BREACHER_SCALE := 0.85 / Figures.COLONIST_HEIGHT
const BRAWLER_SCALE := 1.08

## How high the jet trooper's lower sole hovers.
const JET_HOVER := 0.5

## The breacher's fuse lamp: blinking red, at every tier, since it says the pack is live.
static var FUSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.BLINK, true, false)
## The jet trooper's stub wings: army-orange plate, flat.
static var ORANGE := Parts.surf("orange")


## The ranger: the colonist with a short rifle held at low ready and a pistol in a holster on the
## right thigh, rigged (Figures.walk_rig): its legs walk, and its arms and rifle are one group on
## Rig.AIM, raised to aim and kicked by each shot; the rifle's muzzle is its `muzzle` socket.
static func build_ranger(p: Parts) -> void:
	var m := p.body
	var pose := _low_ready()
	var j := Figures.joints(Vector3.ZERO, 0.0, pose)
	var rigging := Figures.walk_rig(j, Rig.AIM)
	Figures.colonist(m, Vector3.ZERO, 0.0, pose, Figures.PRIMARY_HEADS, 1.0, true, rigging)
	var ink := m.ink
	m.ink = Figures.FIGURE_INK
	var grip := _hand(j, 1, 1.0)
	m.rig = rigging.arms
	_rifle(m, grip, grip + LOW_READY.normalized() * FORE_SPAN, p.tier)
	m.rig = rigging.hips[1]
	_holster(m, j.hips[1], 1.0, -1.0)
	m.rig = Vector4.ZERO
	m.ink = ink


## The breacher: the colonist in a bulkier suit, 0.85 tall: plated shoulders and belly, heavy boots
## and a big charge pack on its back, hazard-striped, its fuse blinking.
static func build_breacher(p: Parts) -> void:
	var m := p.body
	var pose := Figures.stance()
	var k := BREACHER_SCALE
	Figures.colonist(m, Vector3.ZERO, 0.0, pose, Figures.PRIMARY_HEADS, k)
	var j := Figures.joints(Vector3.ZERO, 0.0, pose, Figures.PRIMARY_HEADS, k)
	var ink := m.ink
	m.ink = Figures.FIGURE_INK
	var top := _torso_top(j, k)
	_belly_plate(m, j.waist, top, k, p.tier)
	for s: int in 2:
		_pauldron(m, j.waist, j.shoulders[s].origin, k, Figures.SIDES[s], p.tier)
		_heavy_boot(m, j.ankles[s], k)
	_charge_pack(m, j.waist, top, k)
	m.ink = ink


## The jet trooper: the colonist flying, legs trailing, 0.5 over the ground, a jetpack on its back
## with two nozzles blowing flame cones and short stub wings; every part bobs together.
static func build_jet_trooper(p: Parts) -> void:
	var m := p.body
	var pose := _flying()
	var foot := Vector3(0, JET_HOVER, 0)
	m.flags = Surf.BOB
	Figures.colonist(m, foot, 0.0, pose)
	var j := Figures.joints(foot, 0.0, pose)
	var ink := m.ink
	m.ink = Figures.FIGURE_INK
	_jetpack(m, j.waist, _torso_top(j, 1.0), p.tier)
	m.ink = ink
	m.flags = 0


## The brawler: the automaton made heavier, crouched low with its guard up: big fists, broad
## shoulder plates and an armoured girdle round its middle, its armour taking the tier's hull.
static func build_brawler(p: Parts) -> void:
	var m := p.body
	var pose := _guard()
	var s := BRAWLER_SCALE
	var k := s * Figures.AUTOMATON_HEIGHT / Figures.COLONIST_HEIGHT
	Figures.automaton(m, Vector3.ZERO, 0.0, pose, Figures.PRIMARY_HEADS, s)
	var j := Figures.joints(Vector3.ZERO, 0.0, pose, Figures.PRIMARY_HEADS, s, true)
	var ink := m.ink
	m.ink = Figures.FIGURE_INK
	_girdle(m, j.waist, _torso_top(j, k), k, p.tier)
	for side: int in 2:
		_shoulder_plate(m, j.waist, j.shoulders[side].origin, k, Figures.SIDES[side], p.tier)
		_fist(m, j.wrists[side], k, p.tier)
	m.ink = ink


# --- Poses ---------------------------------------------------------------------------

## Low ready, on the neutral pose (Figures.neutral) the rig walks from: the right hand at the grip
## in front of the belly, its forearm brought in, the left arm reaching down and forward to the fore
## end, so the rifle points forward and down (LOW_READY).
static func _low_ready() -> Figures.Pose:
	var pose := Figures.neutral()
	pose.shoulder_swing = PackedFloat32Array([46.0, -10.0])
	pose.shoulder_out = PackedFloat32Array([-26.0, -40.0])
	pose.elbow = PackedFloat32Array([0.0, 70.0])
	return pose


## Flying: leaning into the flight, head up, arms a little back and out, the legs trailing with the
## knees bent and the toes pointed.
static func _flying() -> Figures.Pose:
	var pose := Figures.Pose.new()
	pose.torso = Vector3(16, 4, 0)
	pose.head = Vector3(-14, -6, 0)
	pose.shoulder_swing = PackedFloat32Array([-12.0, -16.0])
	pose.shoulder_out = PackedFloat32Array([26.0, 22.0])
	pose.elbow = PackedFloat32Array([24.0, 30.0])
	pose.hip_swing = PackedFloat32Array([-14.0, -4.0])
	pose.hip_out = PackedFloat32Array([5.0, 6.0])
	pose.knee = PackedFloat32Array([38.0, 24.0])
	pose.foot_pitch = PackedFloat32Array([34.0, 28.0])
	return pose


## The brawler's guard: crouched, feet wide, leaning in, both fists up in front of the chest.
static func _guard() -> Figures.Pose:
	var pose := Figures.Pose.new()
	pose.torso = Vector3(12, 8, 0)
	pose.head = Vector3(-8, -6, 0)
	pose.shoulder_swing = PackedFloat32Array([40.0, 30.0])
	pose.shoulder_out = PackedFloat32Array([30.0, 26.0])
	pose.elbow = PackedFloat32Array([82.0, 92.0])
	pose.hip_swing = PackedFloat32Array([18.0, 4.0])
	pose.hip_out = PackedFloat32Array([16.0, 14.0])
	pose.knee = PackedFloat32Array([36.0, 22.0])
	pose.foot_pitch = PackedFloat32Array([0.0, 0.0])
	return pose


# --- Shared ----------------------------------------------------------------------------

## The middle of side `s`'s hand, from the wrist down, of a figure `k` times the colonist's size.
static func _hand(j: Figures.Joints, s: int, k: float) -> Vector3:
	return j.wrists[s] * Vector3(0, -0.042 * k, 0)


## The torso's height from the waist to its collar (Figures' torso top), of a figure `k` times the
## colonist's size.
static func _torso_top(j: Figures.Joints, k: float) -> float:
	return (j.waist.affine_inverse() * j.neck.origin).y - 0.015 * k


# --- The ranger's ------------------------------------------------------------------------

## The rifle from the grip hand `grip` to the fore hand `fore` and on: a gunmetal receiver
## between the hands, a stock of the tier's trim behind the grip, a magazine under it, a thin
## barrel past the fore hand and a glowing muzzle of the tier.
static func _rifle(m: LowPolyMesh, grip: Vector3, fore: Vector3, tier: int) -> void:
	var along := (fore - grip).normalized()
	var under := along.cross(Vector3.RIGHT if absf(along.x) < 0.9 else Vector3.FORWARD).normalized()
	if under.y > 0.0:
		under = -under
	Parts.beam(m, grip - along * 0.02, fore + along * 0.03, 0.05, Parts.GUNMETAL, 0.014)
	Parts.beam(m, grip - along * STOCK_LENGTH, grip - along * 0.015, 0.042, UnitModels.trim(tier), 0.012)
	var mag := grip + along * 0.06
	Parts.beam(m, mag, mag + under * 0.07, 0.034, Parts.HULL_DARK, 0.01)
	var muzzle := fore + along * BARREL_LENGTH
	Parts.pipe(m, fore + along * 0.02, muzzle, 0.013, Parts.ROD, 8)
	m.orb(0.022, 8, 3, muzzle, UnitModels.glow(tier, Surf.PULSE, false))
	m.socket("muzzle", muzzle, along)


## A holster on the thigh from the hip joint `hip`, on its outside (`side`, -1 the right): a dark
## chamfered pouch with a gunmetal pistol grip standing out of its top.
static func _holster(m: LowPolyMesh, hip: Transform3D, k: float, side: float) -> void:
	m.box_chamfered(Vector3(0.036, 0.1, 0.07) * k, 0.012 * k, hip * (Vector3(side * 0.066, -0.15, 0.0) * k), Parts.HULL_DARK,
		UnitModels.euler(hip))
	m.box_chamfered(Vector3(0.026, 0.05, 0.034) * k, 0.008 * k, hip * (Vector3(side * 0.066, -0.06, -0.012) * k),
		Parts.GUNMETAL, UnitModels.euler(hip, Vector3(-12, 0, 0)))


# --- The breacher's ------------------------------------------------------------------------

## The belly plate on the waist `xf` (the torso `top` high): a curved armour sector of the tier's
## trim over the front of the suit between the belt and the chest plate.
static func _belly_plate(m: LowPolyMesh, xf: Transform3D, top: float, k: float, tier: int) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0.1 * k, top * 0.22), Vector2(0.104 * k, top * 0.36), Vector2(0.1 * k, top * 0.46),
		Vector2(0.08 * k, top * 0.46), Vector2(0.084 * k, top * 0.36), Vector2(0.08 * k, top * 0.22),
	]), 16, xf.origin, UnitModels.trim(tier, true), UnitModels.euler(xf), 50.0, 130.0)


## A pauldron over the shoulder joint `shoulder` on side `side`: a broad dome of the tier's trim
## over the suit's orange pad, tilted out.
static func _pauldron(m: LowPolyMesh, waist: Transform3D, shoulder: Vector3, k: float, side: float, tier: int) -> void:
	m.dome(0.084 * k, 0.07 * k, 12, 2, shoulder + waist.basis * Vector3(side * 0.012, 0.014, 0) * k,
		UnitModels.trim(tier, true), UnitModels.euler(waist, Vector3(0, 0, -side * 30.0)))


## A heavy boot over the boot on the ankle joint `xf`: a fatter dark shell round its shaft.
static func _heavy_boot(m: LowPolyMesh, xf: Transform3D, k: float) -> void:
	var ankle := 0.055 * k
	m.lathe(PackedVector2Array([
		Vector2(0.076 * k, -ankle), Vector2(0.078 * k, -ankle + 0.04 * k), Vector2(0.066 * k, -ankle + 0.07 * k),
	]), 10, xf.origin, Parts.HULL_DARK_ROUND, UnitModels.euler(xf))


## The charge pack on the waist `xf`'s back: a big dark chamfered pack over the suit's backpack,
## rising behind the helmet so it shapes the breacher's outline, a hazard-striped band round it, a
## gunmetal detonator block on top and the fuse lamp on that.
static func _charge_pack(m: LowPolyMesh, xf: Transform3D, top: float, k: float) -> void:
	var pack := Vector3(0, top * 0.1, -0.175 * k)
	var tall := 0.46 * k
	m.box_chamfered(Vector3(0.28 * k, tall, 0.15 * k), 0.045 * k, xf * pack, Parts.HULL_DARK, UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.29, 0.08, 0.16) * k, 0.025 * k, xf * (pack + Vector3(0, tall * 0.42, 0)), Parts.HAZARD,
		UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.16, 0.05, 0.09) * k, 0.018 * k, xf * (pack + Vector3(0, tall - 0.01 * k, 0)), Parts.GUNMETAL,
		UnitModels.euler(xf))
	m.orb(0.026 * k, 8, 3, xf * (pack + Vector3(0.045 * k, tall + 0.065 * k, 0)), FUSE)


# --- The jet trooper's ------------------------------------------------------------------------

## The jetpack on the waist `xf`'s back: a pack over the suit's backpack (the tier's trim to Gold,
## its hull from Chrome), two gunmetal nozzles under its outer corners blowing pulsing flame cones
## of the tier's glow down past the legs, and two orange stub wings out of its sides.
static func _jetpack(m: LowPolyMesh, xf: Transform3D, top: float, tier: int) -> void:
	var pack := Vector3(0, top * 0.22, -0.165)
	m.box_chamfered(Vector3(0.24, 0.25, 0.11), 0.035, xf * pack,
		UnitModels.trim(tier) if tier < Parts.Tier.CHROME else UnitModels.hull(tier), UnitModels.euler(xf))
	for side: float in Figures.SIDES:
		_nozzle(m, xf * Transform3D(Basis.from_euler(Vector3(deg_to_rad(-20), 0, deg_to_rad(side * 14))),
			pack + Vector3(side * 0.105, 0.01, -0.01)), tier)
		_stub_wing(m, xf * Transform3D(Basis.IDENTITY, pack + Vector3(side * 0.11, 0.17, 0)), side)


## A nozzle hanging from `xf` along its -Y: a gunmetal bell and the long flame cone out of its
## mouth, unlit, pulsing, not inked.
static func _nozzle(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.lathe(PackedVector2Array([Vector2(0.032, 0.0), Vector2(0.04, 0.04), Vector2(0.056, 0.08)]), 10, xf.origin,
		Parts.GUNMETAL, UnitModels.euler(xf, Vector3(180, 0, 0)))
	m.cone(0.05, 0.38, 10, xf * Vector3(0, -0.075, 0), UnitModels.glow(tier, Surf.PULSE, false),
		UnitModels.euler(xf, Vector3(180, 0, 0)))


## A stub wing from `xf` out along its X to side `side`: a short orange plate swept back and
## tipped up a little.
static func _stub_wing(m: LowPolyMesh, xf: Transform3D, side: float) -> void:
	m.box_chamfered(Vector3(0.15, 0.026, 0.08), 0.01, xf * Vector3(side * 0.07, 0, 0), ORANGE,
		UnitModels.euler(xf, Vector3(0, side * 18.0, side * 12.0)))


# --- The brawler's ------------------------------------------------------------------------

## The girdle on the waist `xf`: a thick armour band of the tier's hull round the belly, under
## the orange chest.
static func _girdle(m: LowPolyMesh, xf: Transform3D, top: float, k: float, tier: int) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0.104 * k, top * 0.2), Vector2(0.118 * k, top * 0.32), Vector2(0.108 * k, top * 0.46),
	]), 12, xf.origin, UnitModels.hull(tier, true), UnitModels.euler(xf))


## A broad shoulder plate over the shoulder joint `shoulder` on side `side`, tilted out: orange to
## Gold, the tier's hull from Chrome, the brawler's armour taking its tier.
static func _shoulder_plate(m: LowPolyMesh, waist: Transform3D, shoulder: Vector3, k: float, side: float,
		tier: int) -> void:
	m.box_chamfered(Vector3(0.16, 0.05, 0.15) * k, 0.03 * k, shoulder + waist.basis * Vector3(side * 0.02, 0.03, 0) * k,
		ORANGE if tier < Parts.Tier.CHROME else UnitModels.hull(tier), UnitModels.euler(waist, Vector3(0, 0, -side * 24.0)))


## A big fist on the wrist joint `xf`, over the automaton's hand: a gunmetal mitt half again its
## size, a knuckle band of the tier's trim across it.
static func _fist(m: LowPolyMesh, xf: Transform3D, k: float, tier: int) -> void:
	var down := UnitModels.euler(xf, Vector3(180, 0, 0))
	m.lathe(PackedVector2Array([
		Vector2(0.048 * k, -0.012 * k), Vector2(0.074 * k, 0.03 * k), Vector2(0.066 * k, 0.09 * k), Vector2(0, 0.104 * k),
	]), 10, xf.origin, Parts.GUNMETAL, down)
	m.lathe(PackedVector2Array([Vector2(0.077 * k, 0.05 * k), Vector2(0.075 * k, 0.074 * k)]), 10,
		xf.origin, UnitModels.trim(tier, true), down)
