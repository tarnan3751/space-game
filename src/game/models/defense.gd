extends RefCounted
## Models of the defences (docs/reference/art-style.md). Every defence stands on the family's
## squat armoured plinth, an octagon of gunmetal plate belted in defence red on its concrete
## pad, and glows in its weapon's own colour: laser red, plasma violet, arc electric blue, ion
## and railgun cyan, EMP yellow. Levels add barrels, armour, coils or capacitors to the same
## weapon; the top level adds gold trim.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. A part's
## heading is a yaw in degrees from +Z towards +X: the camera looks from the +X+Z corner, so
## yaw 45 faces the viewer and SCREEN_RIGHT runs across the screen, where a barrel shows its
## whole length. Parts.around() angles run the other way, from +X towards +Z.

## The yaw that runs a part to the right of the screen.
const SCREEN_RIGHT := 135.0

static var SHELL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var SHELL_MID := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var SHELL_DARK := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.LIT, true)
static var DENSE := Surf.make(MaterialKit.Layer.HULL_DENSE, MaterialKit.HULL_MID)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK)
static var POD := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE)
static var ARMOUR_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, 1.0, Surf.LIT, true)
static var BARREL := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 1.0, Surf.LIT, true)
static var RIBBED := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var HAZARD_FINE := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0)
static var GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
## The gravity well's dark core: glossy, so it catches a hard highlight.
static var CORE := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.HULL_DARK, 1.0, Surf.GLOSSY, true)
static var LENS := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ENERGY, 2.0, Surf.GLOSSY, true)
static var LASER := _glow(MaterialKit.DEFENCE)
static var PLASMA := _glow(MaterialKit.ANTIMATTER)
static var ARC := _glow(MaterialKit.ARC_BLUE)
static var ION := _glow(MaterialKit.ENERGY)
static var EMP := _glow(MaterialKit.HAZARD)
## The cloaked sentry's shimmer: energy cyan seen through a dim tint.
static var SHIMMER := _glow(MaterialKit.ENERGY.darkened(0.55))


static func build_laser_turret(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.2, 0.42)
	Parts.drum(m, 0.84, 0.12, 0.04, 24, Vector3(0, top, 0), SHELL_MID)
	for degrees: float in [135.0, 315.0]:
		_cell(m, Parts.around(1.42, degrees, Parts.PAD_HEIGHT), 0.3, LASER)
	if level >= 3:
		_cell(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT), 0.38, LASER)
	if level >= 4:
		for degrees: float in [0.0, 90.0]:
			m.box_chamfered(Vector3(0.62, 0.22, 0.08), 0.02, Parts.around(1.1, degrees, Parts.PAD_HEIGHT + 0.06), ARMOUR,
				Vector3(0, 90.0 - degrees, 0))
	# The head is built turned to SCREEN_RIGHT - 25, so a still frame shows the barrels' length.
	var head := p.moving(Vector3(0, top + 0.12, 0), Motion.spin(Vector3.UP, 0.4))
	var heading := Vector3(0, SCREEN_RIGHT - 25.0, 0)
	var along := Vector3(90, SCREEN_RIGHT - 25.0, 0)
	Parts.drum(head, 0.62, 0.32, 0.05, 20, Vector3.ZERO, SHELL)
	head.dome(0.57, 0.3, 20, 6, Vector3(0, 0.32, 0), SHELL)
	head.box_chamfered(Vector3(0.72, 0.38, 0.3), 0.06, LowPolyMesh.turn(Vector3(0, 0.1, 0.5), heading), DENSE, heading)
	var bore := 0.07 + 0.012 * level
	var length := 0.5 + 0.04 * level
	for x: float in [-0.18, 0.18]:
		var root := LowPolyMesh.turn(Vector3(x, 0.29, 0.5), heading)
		head.prism(bore, bore, length, 16, root, BARREL, along)
		head.tube(bore * 0.5, bore + 0.035, 0.12, 16, _at(root, Vector3(0, length - 0.1, 0), along),
			GOLD if level >= 5 else Parts.GUNMETAL, along)
		head.orb(bore * 0.85, 16, 8, _at(root, Vector3(0, length + 0.03, 0), along), LASER)
	if level >= 2:
		for side: float in [-1.0, 1.0]:
			head.box_chamfered(Vector3(0.14, 0.34, 0.62), 0.04, LowPolyMesh.turn(Vector3(side * 0.62, 0.04, 0.02), heading),
				ARMOUR, heading)
	if level >= 3:
		head.box_chamfered(Vector3(0.66, 0.3, 0.34), 0.05, LowPolyMesh.turn(Vector3(0, 0.14, 0.8), heading), VENT, heading)
		head.box(Vector3(0.42, 0.05, 0.02), LowPolyMesh.turn(Vector3(0, 0.33, 0.655), heading), LASER, heading)
	if level >= 4:
		head.box_chamfered(Vector3(0.62, 0.36, 0.34), 0.06, LowPolyMesh.turn(Vector3(0, 0.12, -0.62), heading), DENSE, heading)
		Parts.mast(head, LowPolyMesh.turn(Vector3(-0.28, 0.5, -0.25), heading), 0.4, 0.05, LASER)
	if level >= 5:
		Parts.torus(head, 0.63, 0.035, 24, 10, Vector3(0, 0.27, 0), GOLD)


static func build_missile_battery(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.2, 0.36)
	Parts.drum(m, 0.8, 0.2, 0.05, 24, Vector3(0, top, 0), SHELL_MID)
	var deck := top + 0.2
	_crate(m, Parts.around(1.42, 315.0, Parts.PAD_HEIGHT))
	if level >= 3:
		_crate(m, Parts.around(1.42, 135.0, Parts.PAD_HEIGHT))
	var columns := 2 if level < 3 else 3
	var rows := 2 if level < 4 else 3
	var width := columns * 0.34 + 0.2
	var height := rows * 0.34 + 0.2
	var depth := 0.9
	var yaw := 100.0
	var heading := Vector3(0, yaw, 0)
	var aim := Vector3(-32, yaw, 0)
	var trunnion := Vector3(0, deck + 0.62, 0)
	var trim := GOLD if level >= 5 else Parts.GUNMETAL
	for side: float in [-1.0, 1.0]:
		var arm := LowPolyMesh.turn(Vector3(side * (width * 0.5 + 0.1), 0, 0), heading)
		m.box_chamfered(Vector3(0.16, 0.72, 0.46), 0.04, Vector3(arm.x, deck, arm.z), SHELL, heading)
		m.prism(0.12, 0.12, 0.06, 16, trunnion + LowPolyMesh.turn(Vector3(side * (width * 0.5 + 0.17), 0, 0), heading),
			trim, heading + Vector3(0, 0, -90 * side))
	m.box_chamfered(Vector3(width, height, depth), 0.06, _at(trunnion, Vector3(0, -height * 0.5, 0), aim), SHELL, aim)
	m.box_chamfered(Vector3(width + 0.04, height + 0.04, 0.16), 0.03,
		_at(trunnion, Vector3(0, -height * 0.5 - 0.02, depth * 0.5 - 0.22), aim), HAZARD_FINE, aim)
	var tube_aim := aim + Vector3(90, 0, 0)
	for column: int in columns:
		for row: int in rows:
			var face := Vector3((column - (columns - 1) * 0.5) * 0.34, (row - (rows - 1) * 0.5) * 0.34, depth * 0.5 - 0.04)
			var mouth := _at(trunnion, face, aim)
			m.tube(0.1, 0.14, 0.1, 16, mouth, Parts.GUNMETAL, tube_aim)
			m.cone(0.085, 0.2, 16, mouth, LASER, tube_aim)
	if level >= 2:
		m.box_chamfered(Vector3(width * 0.8, 0.05, depth * 0.45), 0.02,
			_at(trunnion, Vector3(0, height * 0.5, -0.12), aim), ARMOUR, aim)
		Parts.mast(m, Parts.around(0.95, 225.0, top), 0.7, 0.06, LASER)
	if level >= 5:
		_crate(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT))
		m.box_chamfered(Vector3(width + 0.05, height + 0.05, 0.08), 0.02,
			_at(trunnion, Vector3(0, -height * 0.5 - 0.025, -depth * 0.5 + 0.02), aim), GOLD, aim)


static func build_plasma_mortar(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.25, 0.3)
	m.lathe(PackedVector2Array([
		Vector2(1.0, 0), Vector2(1.06, 0.12), Vector2(1.0, 0.26), Vector2(0.86, 0.32),
		Vector2(0.62, 0.32), Vector2(0.54, 0.2), Vector2(0.54, 0),
	]), 20, Vector3(0, top, 0), SHELL_MID)
	var seat := top + 0.32
	if level >= 2:
		for degrees: float in [135.0, 315.0]:
			_cell(m, Parts.around(1.42, degrees, Parts.PAD_HEIGHT), 0.32, PLASMA)
		for degrees: float in [0.0, 90.0, 180.0, 270.0]:
			m.box_chamfered(Vector3(0.14, 0.3, 0.3), 0.04, Parts.around(1.0, degrees + 45.0, top + 0.02), Parts.GUNMETAL,
				Vector3(0, 45.0 - degrees, 0))
	if level >= 3:
		m.lathe(PackedVector2Array([
			Vector2(0.86, 0), Vector2(0.86, 0.14), Vector2(0.78, 0.2), Vector2(0.6, 0.2),
			Vector2(0.54, 0.12), Vector2(0.54, 0),
		]), 20, Vector3(0, seat, 0), ARMOUR_ROUND)
		seat += 0.2
	# The plasma chamber: a glowing sphere sitting up on the ring, the barrel rising out of its
	# far side, so its near side shows over the cradle's low cheeks at every level.
	var chamber := 0.3 + 0.04 * level
	var breech := Vector3(0, seat + chamber, 0)
	var tilt := Vector3(34, SCREEN_RIGHT, 0)
	var heading := Vector3(0, SCREEN_RIGHT, 0)
	m.orb(chamber, 16, 8, breech, PLASMA)
	var band := GOLD if level >= 4 else Parts.GUNMETAL
	Parts.torus(m, chamber + 0.01, 0.045, 20, 10, breech - Vector3(0, 0.045, 0), band)
	for yaw: float in [30.0, 120.0]:
		var rib := Vector3(0, SCREEN_RIGHT + yaw, 90)
		Parts.torus(m, chamber + 0.01, 0.035, 16, 10, _at(breech, Vector3(0, -0.035, 0), rib), Parts.GUNMETAL, rib)
	for side: float in [-1.0, 1.0]:
		var cheek := LowPolyMesh.turn(Vector3(side * (chamber + 0.12), 0, 0.05), heading)
		m.box_chamfered(Vector3(0.14, 0.24, 0.5), 0.04, Vector3(cheek.x, seat - 0.1, cheek.z), SHELL, heading)
	var muzzle := 0.95
	var mouth := _at(breech, Vector3(0, chamber * 0.85, 0), tilt)
	m.lathe(PackedVector2Array([Vector2(0.3, -0.12), Vector2(0.44, 0.0), Vector2(0.44, muzzle - 0.24)]),
		20, mouth, SHELL, tilt)
	m.lathe(PackedVector2Array([
		Vector2(0.44, muzzle - 0.24), Vector2(0.52, muzzle - 0.18), Vector2(0.52, muzzle), Vector2(0.42, muzzle + 0.04),
		Vector2(0.32, muzzle - 0.04), Vector2(0.32, muzzle - 0.3),
	]), 20, mouth, GOLD if level >= 4 else SHELL, tilt)
	m.disc(0.32, 20, _at(mouth, Vector3(0, muzzle - 0.3, 0), tilt), PLASMA, tilt)
	m.tube(0.44, 0.47, 0.12, 20, _at(mouth, Vector3(0, 0.22, 0), tilt), ARMOUR_ROUND, tilt)


static func build_shield_generator(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.15, 0.3)
	Parts.drum(m, 0.9, 0.16, 0.04, 24, Vector3(0, top, 0), SHELL_MID)
	var foot := top + 0.16
	m.dome(0.84, 0.55, 20, 6, Vector3(0, foot, 0), SHELL)
	m.ring(0.8, 0.88, 0.05, 24, Vector3(0, foot, 0), ION)
	var orb_radius := 0.3 + 0.05 * level
	var orb := Vector3(0, top + 1.45 + 0.05 * level, 0)
	var knuckle := GOLD if level >= 4 else ARMOUR_ROUND
	for k: int in 3:
		var degrees := 75.0 + 120.0 * k
		var root := Parts.around(0.6, degrees, foot + 0.35)
		var elbow := Parts.around(1.0, degrees, foot + 0.72)
		var tip := Parts.around(0.44, degrees, orb.y - orb_radius * 0.75)
		# Two straight runs meeting under the knuckle, which hides the bend.
		Parts.pipe_run(m, PackedVector3Array([root, elbow]), 0.09, SHELL_DARK)
		Parts.pipe_run(m, PackedVector3Array([elbow, tip]), 0.09, SHELL_DARK)
		m.orb(0.15, 12, 6, elbow, knuckle)
		m.cone(0.11, 0.18, 16, tip, ION, Parts.facing(orb - tip))
		if level >= 2:
			Parts.torus(m, 0.13, 0.04, 12, 6, elbow.lerp(tip, 0.45), ION, Parts.facing(tip - elbow))
		if level >= 3:
			var short_degrees := degrees + 60.0
			var short_root := Parts.around(0.62, short_degrees, foot + 0.3)
			var short_tip := Parts.around(0.84, short_degrees, foot + 0.72)
			Parts.pipe_run(m, PackedVector3Array([short_root, short_tip]), 0.08, SHELL_DARK)
			m.orb(0.11, 12, 6, short_tip, knuckle)
	m.orb(orb_radius, 20, 8, orb, ION)
	if level >= 4:
		Parts.torus(m, orb_radius + 0.16, 0.035, 20, 10, orb - Vector3(0, 0.035, 0), GOLD, Vector3(18, 0, 10))


static func build_flak_cannon(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.15, 0.35)
	var rise := 0.35 + 0.12 * level
	m.lathe(PackedVector2Array([
		Vector2(0.62, 0), Vector2(0.62, 0.12), Vector2(0.4, 0.26), Vector2(0.3, rise), Vector2(0, rise),
	]), 20, Vector3(0, top, 0), SHELL_MID)
	var deck := top + rise
	if level >= 2:
		for degrees: float in [45.0, 225.0, 315.0]:
			Parts.pipe_run(m, PackedVector3Array([Parts.around(0.95, degrees, top), Parts.around(0.34, degrees, deck - 0.05)]),
				0.045, Parts.GUNMETAL)
	_crate(m, Parts.around(1.42, 315.0, Parts.PAD_HEIGHT))
	var yaw := 120.0
	var heading := Vector3(0, yaw, 0)
	var tilt := Vector3(38, yaw, 0)
	var centre := Vector3(0, deck, 0)
	Parts.drum(m, 0.44, 0.1, 0.03, 20, centre, Parts.GUNMETAL)
	m.box_chamfered(Vector3(0.66, 0.54, 0.8), 0.07, centre + Vector3(0, 0.1, 0), SHELL, heading)
	m.box(Vector3(0.36, 0.05, 0.02), _at(centre, Vector3(0, 0.5, 0.401), heading), LASER, heading)
	if level >= 4:
		m.box_chamfered(Vector3(0.7, 0.07, 0.84), 0.02, centre + Vector3(0, 0.56, 0), GOLD, heading)
	var per_side := 2 if level < 3 else 3
	var pack := 0.08 + 0.13 * per_side
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(pack, 0.38, 0.56), 0.04, _at(centre, Vector3(side * (0.33 + pack * 0.5), 0.12, 0), heading),
			ARMOUR, heading)
		for k: int in per_side:
			var root := _at(centre, Vector3(side * (0.41 + 0.13 * k), 0.4, 0.05), heading)
			var length := 1.05
			m.prism(0.06, 0.06, length, 16, root, BARREL, tilt)
			m.tube(0.04, 0.085, 0.16, 16, _at(root, Vector3(0, length - 0.12, 0), tilt),
				GOLD if level >= 4 else Parts.GUNMETAL, tilt)
			m.orb(0.05, 12, 6, _at(root, Vector3(0, length + 0.05, 0), tilt), LASER)
		if level >= 3:
			m.prism(0.18, 0.18, 0.2, 16, _at(centre, Vector3(side * (0.33 + pack), 0.22, -0.12), heading),
				SHELL_MID, heading + Vector3(0, 0, -90 * side))
	var mast_foot := Parts.around(0.92, 135.0, top)
	m.prism(0.06, 0.05, deck + 0.45 - top, 16, mast_foot, Parts.GUNMETAL)
	var radar := p.moving(mast_foot + Vector3(0, deck + 0.45 - top, 0), Motion.spin(Vector3.UP, 1.2))
	var face := Vector3(70, 0, 0)
	radar.lathe(PackedVector2Array([
		Vector2(0.06, 0), Vector2(0.32, 0.1), Vector2(0.3, 0.13), Vector2(0, 0.04),
	]), 24, Vector3(0, 0.12, -0.08), SHELL, face)
	radar.prism(0.05, 0.05, 0.14, 16, Vector3.ZERO, Parts.GUNMETAL)
	radar.orb(0.05, 12, 6, Vector3(0, 0.12, 0) + LowPolyMesh.turn(Vector3(0, 0.25, 0), face), LASER)


static func build_arc_tower(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.1, 0.3)
	Parts.drum(m, 0.62, 0.24, 0.06, 20, Vector3(0, top, 0), SHELL_MID)
	var crown := _coil(m, Vector3(0, top + 0.24, 0), 0.85 + 0.2 * mini(level, 3), 0.5, level >= 4)
	var sphere := 0.28 + 0.03 * level
	m.orb(sphere, 16, 8, crown + Vector3(0, sphere * 0.85, 0), ARC)
	if level >= 2:
		for degrees: float in [0.0, 90.0, 180.0, 270.0]:
			var root := crown + Parts.around(0.42, degrees, 0.0)
			var tip := crown + Parts.around(0.66, degrees, -0.08)
			m.prism(0.025, 0.015, root.distance_to(tip), 8, root, Parts.ROD, Parts.facing(tip - root))
			m.orb(0.05, 8, 4, tip, ARC)
	if level >= 3:
		for degrees: float in [45.0, 225.0, 315.0]:
			_cell(m, Parts.around(1.42, degrees, Parts.PAD_HEIGHT), 0.42, ARC)
	if level >= 4:
		var twin := Parts.around(1.38, 135.0, Parts.PAD_HEIGHT)
		Parts.drum(m, 0.26, 0.16, 0.04, 16, twin, SHELL_MID)
		var twin_crown := _coil(m, twin + Vector3(0, 0.16, 0), 0.85, 0.26, true)
		m.orb(0.2, 16, 8, twin_crown + Vector3(0, 0.17, 0), ARC)


static func build_cloaked_sentry(p: Parts, level: int) -> void:
	var m := p.body
	Parts.foundation(m, 2)
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	m.ring(0.8, 0.86, 0.05, 6, base, SHIMMER)
	m.lathe(PackedVector2Array([
		Vector2(0.74, 0), Vector2(0.74, 0.2), Vector2(0.58, 0.34), Vector2(0, 0.34),
	]), 6, base, POD)
	m.ring(0.72, 0.77, 0.06, 6, base + Vector3(0, 0.08, 0), ARMOUR)
	for degrees: float in [30.0, 90.0]:
		m.box_chamfered(Vector3(0.36, 0.1, 0.03), 0.01, Parts.around(0.65, degrees, Parts.PAD_HEIGHT + 0.07), VENT,
			Vector3(0, 90.0 - degrees, 0))
	Parts.drum(m, 0.44, 0.05, 0.02, 6, base + Vector3(0, 0.34, 0), Parts.HULL_DARK)
	if level >= 3:
		m.ring(0.43, 0.47, 0.06, 6, base + Vector3(0, 0.34, 0), GOLD)
	var lid := base + Vector3(0, 0.39, 0)
	var guns: Array[float] = [0.0]
	if level >= 2:
		guns = [-0.17, 0.17]
	for offset: float in guns:
		var yaw := SCREEN_RIGHT - 30.0
		_sentry_gun(m, lid + LowPolyMesh.turn(Vector3(offset, 0, 0), Vector3(0, yaw, 0)), yaw)
	Parts.drum(m, 0.08, 0.14, 0.02, 16, base + Parts.around(0.3, 225.0, 0.34), Parts.GUNMETAL)
	m.orb(0.06, 12, 6, base + Parts.around(0.3, 225.0, 0.52), LASER)
	if level >= 2:
		m.ring(0.6, 0.64, 0.04, 6, base + Vector3(0, 0.36, 0), SHIMMER)
	if level >= 3:
		Parts.mast(m, base + Parts.around(0.36, 285.0, 0.34), 0.32, 0.045, LASER)


static func build_gravity_well(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 2, 0.8, 0.22)
	Parts.torus(m, 0.5, 0.08, 16, 10, Vector3(0, top, 0), SHELL_MID)
	m.disc(0.44, 20, Vector3(0, top + 0.01, 0), PLASMA)
	var core := Vector3(0, top + 0.7, 0)
	for k: int in 3:
		var degrees := 30.0 + 120.0 * k
		var foot := Parts.around(0.66, degrees, top)
		m.box_chamfered(Vector3(0.14, 0.82, 0.18), 0.04, foot, SHELL_MID, Vector3(0, 90.0 - degrees, 0))
		m.box_chamfered(Vector3(0.1, 0.08, 0.12), 0.02, foot + Vector3(0, 0.82, 0), PLASMA, Vector3(0, 90.0 - degrees, 0))
	m.orb(0.17, 12, 6, core, CORE)
	if level >= 2:
		_gyro(m, core, 0.38, 0.04, Vector3(62, 0, 25), SHELL)
	if level >= 3:
		_gyro(m, core, 0.29, 0.035, Vector3(-55, 0, -35), GOLD)
	var rotor := p.moving(core + Vector3(0, 0.5, 0), Motion.spin(Vector3.UP, 1.5))
	Parts.torus(rotor, 0.42, 0.05, 16, 10, Vector3(0, -0.05, 0), SHELL)
	Parts.drum(rotor, 0.1, 0.1, 0.03, 16, Vector3(0, -0.05, 0), Parts.GUNMETAL)
	for k: int in 3:
		var degrees := 120.0 * k
		rotor.box_chamfered(Vector3(0.36, 0.04, 0.09), 0.015, Parts.around(0.24, degrees, -0.02), SHELL_MID,
			Vector3(0, -degrees, 0))
		rotor.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Parts.around(0.42, degrees, 0.04), PLASMA, Vector3(0, -degrees, 0))


static func build_emp_tower(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.2, 0.3)
	m.box_chamfered(Vector3(0.9, 0.56, 0.9), 0.07, Vector3(0, top, 0), Parts.HULL_LIGHT)
	m.box_chamfered(Vector3(0.94, 0.12, 0.94), 0.03, Vector3(0, top + 0.38, 0), HAZARD_FINE)
	m.box_chamfered(Vector3(0.72, 0.5, 0.72), 0.06, Vector3(0, top + 0.56, 0), Parts.HULL_LIGHT)
	m.box_chamfered(Vector3(0.74, 0.16, 0.04), 0.01, Vector3(0, top + 0.16, 0.45), VENT)
	var neck := top + 1.06
	Parts.drum(m, 0.28, 0.12, 0.04, 16, Vector3(0, neck, 0), SHELL_MID)
	var cage := Vector3(0, neck + 0.12, 0)
	Parts.drum(m, 0.46, 0.08, 0.02, 16, cage, Parts.GUNMETAL)
	m.orb(0.22 + 0.03 * level, 16, 6, cage + Vector3(0, 0.34, 0), EMP)
	for k: int in 8:
		m.box(Vector3(0.05, 0.56, 0.05), Parts.around(0.4, 22.5 + 45.0 * k, cage.y + 0.08), Parts.ROD,
			Vector3(0, -22.5 - 45.0 * k, 0))
	Parts.torus(m, 0.4, 0.05, 16, 10, cage + Vector3(0, 0.62, 0), GOLD if level >= 3 else Parts.GUNMETAL)
	m.dome(0.22, 0.12, 16, 6, cage + Vector3(0, 0.67, 0), SHELL_MID)
	Parts.mast(m, cage + Vector3(0, 0.78, 0), 0.22, 0.05, EMP)
	var cans: Array[float] = [135.0, 315.0]
	if level >= 2:
		cans.append_array([45.0, 225.0])
	for degrees: float in cans:
		var can_top := _capacitor(m, Parts.around(0.94, degrees, top), 0.5, level < 3)
		if level >= 3:
			can_top = _capacitor(m, can_top, 0.36, true)
		Parts.pipe_run(m, PackedVector3Array([can_top, Parts.around(0.3, degrees, can_top.y)]), 0.035, Parts.GUNMETAL)


static func build_railgun(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 3, 1.2, 0.34)
	Parts.drum(m, 0.86, 0.14, 0.04, 24, Vector3(0, top, 0), SHELL_MID)
	var deck := Vector3(0, top + 0.14, 0)
	var heading := Vector3(0, SCREEN_RIGHT, 0)
	var aim := Vector3(-6, SCREEN_RIGHT, 0)
	m.box_chamfered(Vector3(0.95, 0.46, 1.1), 0.08, _at(deck, Vector3(0, 0, -0.3), heading), Parts.HULL_LIGHT, heading)
	m.box_chamfered(Vector3(0.7, 0.3, 0.34), 0.05, _at(deck, Vector3(0, 0.46, -0.62), heading), VENT, heading)
	m.box(Vector3(0.36, 0.05, 0.02), _at(deck, Vector3(0, 0.6, -0.449), heading), ION, heading)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.05, 0.3, 0.8), 0.015, _at(deck, Vector3(side * 0.49, 0.08, -0.3), heading), ARMOUR,
			heading)
	m.box_chamfered(Vector3(0.6, 0.06, 0.3), 0.02, _at(deck, Vector3(0, 0.46, 0.0), heading), HAZARD_FINE, heading)
	var length := 1.8 + 0.3 * level
	var root := _at(deck, Vector3(0, 0.42, -1.0), heading)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.14, 0.26, length), 0.04, _at(root, Vector3(side * 0.16, 0, length * 0.5), aim),
			Parts.GUNMETAL, aim)
		m.box_chamfered(Vector3(0.16, 0.28, 0.16), 0.04, _at(root, Vector3(side * 0.16, -0.01, length - 0.08), aim),
			GOLD if level >= 3 else ARMOUR, aim)
	m.box(Vector3(0.14, 0.08, length - 0.5), _at(root, Vector3(0, 0.08, length * 0.5 + 0.15), aim), ION, aim)
	var collars := int((length - 0.7) / 0.5)
	for i: int in collars:
		m.box_chamfered(Vector3(0.56, 0.36, 0.12), 0.03, _at(root, Vector3(0, -0.06, 0.75 + 0.5 * i), aim), DENSE, aim)
	_bank(m, deck, heading, -1.0)
	if level >= 2:
		_bank(m, deck, heading, 1.0)
	if level >= 3:
		for k: int in 3:
			_cell(m, _at(deck, Vector3(-0.28 + 0.28 * k, 0, -1.18), heading), 0.4, ION, 0.12)


static func build_ion_beam(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 2, 0.78, 0.2)
	var head := Vector3(0, top + 0.85, 0)
	for k: int in 3:
		var degrees := 105.0 + 120.0 * k
		var foot := Parts.around(0.6, degrees, top)
		m.box_chamfered(Vector3(0.18, 0.08, 0.18), 0.03, foot, Parts.GUNMETAL, Vector3(0, -degrees, 0))
		Parts.pipe_run(m, PackedVector3Array([foot, Parts.around(0.18, degrees, head.y - 0.12)]), 0.05, Parts.GUNMETAL)
	var aim := Vector3(40, 100, 0)
	var housing := head - LowPolyMesh.turn(Vector3(0, 0.2, 0), aim)
	Parts.drum(m, 0.3, 0.34, 0.05, 20, housing, SHELL, aim)
	m.tube(0.26, 0.34, 0.06, 20, _at(housing, Vector3(0, 0.08, 0), aim), ARMOUR_ROUND, aim)
	var lens := _at(housing, Vector3(0, 0.3, 0), aim)
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.18, 0.04), Vector2(0.3, 0.1), Vector2(0.18, 0.17), Vector2(0, 0.21),
	]), 20, lens, LENS, aim)
	var rings := 2 if level < 2 else 4
	var reach := 0.0
	for i: int in rings:
		reach = 0.32 + 0.15 * i
		Parts.torus(m, 0.26 - 0.035 * i, 0.035, 16 - 2 * i, 10, _at(lens, Vector3(0, reach, 0), aim),
			GOLD if level >= 2 and i == 0 else SHELL_MID, aim)
	for k: int in 3:
		var spoke := _at(lens, Parts.around(0.27, 120.0 * k, 0.1), aim)
		var spoke_end := _at(lens, Parts.around(0.26 - 0.035 * (rings - 1), 120.0 * k, reach + 0.03), aim)
		m.prism(0.02, 0.02, spoke.distance_to(spoke_end), 8, spoke, Parts.ROD, Parts.facing(spoke_end - spoke))
	m.orb(0.07, 12, 6, _at(lens, Vector3(0, reach + 0.12, 0), aim), ION)


static func build_orbital_cannon(p: Parts, level: int) -> void:
	var m := p.body
	var top := _plinth(m, 4, 1.78, 0.32)
	Parts.drum(m, 1.38, 0.24, 0.07, 8, Vector3(0, top, 0), DENSE, Parts.OCTAGON)
	m.ring(1.34, 1.42, 0.07, 8, Vector3(0, top, 0), HAZARD_FINE, Parts.OCTAGON)
	var bunker := top + 0.24
	Parts.drum(m, 1.0, 0.16, 0.05, 24, Vector3(0, bunker, 0), SHELL_MID)
	var deck := bunker + 0.16
	var yaw := SCREEN_RIGHT + 12.0
	var heading := Vector3(0, yaw, 0)
	var aim := Vector3(47, yaw, 0)
	var trunnion := Vector3(0, deck + 0.36, 0)
	for side: float in [-1.0, 1.0]:
		var cheek := LowPolyMesh.turn(Vector3(side * 0.6, 0, 0), heading)
		m.box_chamfered(Vector3(0.2, 0.78, 1.15), 0.06, Vector3(cheek.x, deck, cheek.z), ARMOUR, heading)
		m.prism(0.22, 0.22, 0.1, 20, trunnion + LowPolyMesh.turn(Vector3(side * 0.7, 0, 0), heading),
			GOLD if level >= 2 else Parts.GUNMETAL, heading + Vector3(0, 0, -90 * side))
	m.box_chamfered(Vector3(0.96, 0.95, 0.96), 0.08, _at(trunnion, Vector3(0, -0.45, 0), aim), Parts.HULL_LIGHT, aim)
	var length := 1.2 + 0.15 * level
	var barrel := _at(trunnion, Vector3(0, 0.5, 0), aim)
	m.lathe(PackedVector2Array([
		Vector2(0.42, 0), Vector2(0.42, 0.22), Vector2(0.32, 0.36), Vector2(0.3, length),
	]), 24, barrel, Parts.GUNMETAL, aim)
	m.lathe(PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.42, 0.06), Vector2(0.42, 0.34), Vector2(0.26, 0.38), Vector2(0.22, 0.3),
	]), 24, _at(barrel, Vector3(0, length, 0), aim), SHELL, aim)
	m.disc(0.22, 20, _at(barrel, Vector3(0, length + 0.3, 0), aim), ION, aim)
	m.tube(0.42, 0.44, 0.08, 24, _at(barrel, Vector3(0, length + 0.12, 0), aim), GOLD if level >= 2 else ARMOUR_ROUND, aim)
	var coils := 2 + level
	for i: int in coils:
		var at := 0.5 + (length - 0.7) * i / (coils - 1)
		Parts.torus(m, 0.315, 0.04, 24, 10, _at(barrel, Vector3(0, at, 0), aim), ION, aim)
	if level >= 2:
		Parts.torus(m, 1.0, 0.04, 24, 10, Vector3(0, deck - 0.04, 0), GOLD)
	var mast := Parts.around(1.3, 135.0, top + 0.24)
	m.prism(0.08, 0.06, 0.9, 16, mast, Parts.GUNMETAL)
	var dish := mast + Vector3(0, 0.9, 0)
	var dish_aim := Vector3(55, SCREEN_RIGHT + 60.0, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.08, 0), Vector2(0.48, 0.16), Vector2(0.45, 0.2), Vector2(0, 0.06),
	]), 24, dish, SHELL, dish_aim)
	var feed := _at(dish, Vector3(0, 0.06, 0), dish_aim)
	var horn := _at(dish, Vector3(0, 0.42, 0), dish_aim)
	m.prism(0.02, 0.02, feed.distance_to(horn), 8, feed, Parts.ROD, Parts.facing(horn - feed))
	m.orb(0.06, 12, 6, horn, ION)
	for degrees: float in [45.0, 315.0]:
		m.box_chamfered(Vector3(0.5, 0.18, 0.04), 0.01, Parts.around(1.3, degrees, top + 0.05), VENT,
			Vector3(0, 90.0 - degrees, 0))
	var cells: Array[float] = [45.0, 315.0]
	if level >= 2:
		cells.append_array([135.0, 225.0])
	for degrees: float in cells:
		_cell(m, Parts.around(2.2, degrees, Parts.PAD_HEIGHT), 0.4, ION)


# --- Shared parts --------------------------------------------------------------------

## The family's plinth on its pad: an armoured octagon of gunmetal plate, `radius` to its
## corners and `height` tall, belted in defence red. Returns the height of its top.
static func _plinth(m: LowPolyMesh, size: int, radius: float, height: float) -> float:
	Parts.foundation(m, size)
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.drum(m, radius, height, 0.08, 8, base, Parts.GUNMETAL, Parts.OCTAGON)
	var belt := minf(0.08, height * 0.3)
	m.ring(radius - 0.04, radius + 0.03, belt, 8, base + Vector3(0, height * 0.45 - belt * 0.5, 0), ARMOUR, Parts.OCTAGON)
	return Parts.PAD_HEIGHT + height


## A power cell: a ribbed can `height` tall with a glowing cap.
static func _cell(m: LowPolyMesh, pos: Vector3, height: float, glow: Surf, radius: float = 0.17) -> void:
	Parts.drum(m, radius, height, 0.03, 16, pos, RIBBED)
	Parts.drum(m, radius * 0.6, 0.06, 0.02, 16, pos + Vector3(0, height, 0), glow)


## An ammunition crate on the pad, turned to the diagonal, with a hazard-striped lid.
static func _crate(m: LowPolyMesh, pos: Vector3) -> void:
	m.box_chamfered(Vector3(0.36, 0.26, 0.36), 0.04, pos, DENSE, Vector3(0, 45, 0))
	m.box_chamfered(Vector3(0.38, 0.06, 0.38), 0.02, pos + Vector3(0, 0.26, 0), HAZARD_FINE, Vector3(0, 45, 0))


## A capacitor can standing on `pos`, `height` tall. The can on top of a stack (`top`) wears the
## glowing band and the insulator cap. Returns the can's top.
static func _capacitor(m: LowPolyMesh, pos: Vector3, height: float, top: bool) -> Vector3:
	Parts.drum(m, 0.2, height, 0.04, 16, pos, RIBBED)
	if not top:
		return pos + Vector3(0, height, 0)
	m.ring(0.19, 0.225, 0.07, 16, pos + Vector3(0, height * 0.5, 0), EMP)
	Parts.drum(m, 0.12, 0.08, 0.02, 16, pos + Vector3(0, height, 0), Parts.GUNMETAL)
	return pos + Vector3(0, height + 0.08, 0)


## A bank of three capacitors along one side (`side` -1 or 1) of the railgun's housing.
static func _bank(m: LowPolyMesh, deck: Vector3, heading: Vector3, side: float) -> void:
	for k: int in 3:
		_cell(m, _at(deck, Vector3(side * 0.66, 0, -0.62 + 0.3 * k), heading), 0.4, ION, 0.12)


## The cloaked sentry's gun: a low head on the lid with a short barrel and a red sight.
static func _sentry_gun(m: LowPolyMesh, pos: Vector3, yaw: float) -> void:
	var heading := Vector3(0, yaw, 0)
	m.box_chamfered(Vector3(0.26, 0.15, 0.34), 0.04, pos, SHELL_MID, heading)
	var aim := Vector3(84, yaw, 0)
	m.prism(0.045, 0.045, 0.42, 16, _at(pos, Vector3(0, 0.08, 0.12), heading), BARREL, aim)
	m.box(Vector3(0.1, 0.04, 0.02), _at(pos, Vector3(0, 0.08, 0.171), heading), LASER, heading)


## A tesla coil standing on `base`: a dark column `height` tall stacked with white insulator
## skirts `flare` wide at the foot, crowned with a corona ring. Returns the crown's centre.
static func _coil(m: LowPolyMesh, base: Vector3, height: float, flare: float, gold: bool) -> Vector3:
	m.prism(flare * 0.4, flare * 0.28, height, 16, base, Parts.GUNMETAL)
	var skirts := maxi(3, int(height / 0.26))
	for i: int in skirts:
		var t := float(i) / skirts
		var column := lerpf(flare * 0.4, flare * 0.28, t + 0.3 / skirts)
		m.lathe(PackedVector2Array([
			Vector2(lerpf(flare, flare * 0.62, t), 0), Vector2(lerpf(flare, flare * 0.62, t), 0.05),
			Vector2(column, 0.09),
		]), 16, base + Vector3(0, height * t + 0.06, 0), SHELL)
	var crown := base + Vector3(0, height, 0)
	# A small coil's corona is a tiny ring, and takes fewer faces.
	var big := flare >= 0.4
	Parts.torus(m, flare * 0.8, flare * 0.16, 20 if big else 16, 12 if big else 6, crown - Vector3(0, flare * 0.16, 0),
		GOLD if gold else Parts.GUNMETAL)
	return crown


## A ring round the gravity well's core, tilted by `rot`, centred on `centre`.
static func _gyro(m: LowPolyMesh, centre: Vector3, major: float, minor: float, rot: Vector3, surf: Surf) -> void:
	Parts.torus(m, major, minor, 16, 10, centre - LowPolyMesh.turn(Vector3(0, minor, 0), rot), surf, rot)


## `origin` plus `local` turned by `rot`: a point on a turned part.
static func _at(origin: Vector3, local: Vector3, rot: Vector3) -> Vector3:
	return origin + LowPolyMesh.turn(local, rot)


static func _glow(tint: Color) -> Surf:
	return Surf.make(MaterialKit.Layer.GLOW, tint, 1.0, Surf.UNLIT, true)
