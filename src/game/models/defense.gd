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
static var DENSE := Surf.make(MaterialKit.Layer.HULL_DENSE, MaterialKit.HULL_MID)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE)
static var ARMOUR_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, 1.0, Surf.LIT, true)
static var BARREL := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 1.0, Surf.LIT, true)
static var RIBBED := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var HAZARD_FINE := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0)
static var GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
static var LASER := _glow(MaterialKit.DEFENCE)
static var PLASMA := _glow(MaterialKit.ANTIMATTER)


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
	p.pivot = Vector3(0, top + 0.12, 0)
	p.speed = 0.4
	var head := p.spin
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
	Parts.plinth(m, 3, 0.25)
	m.prism(0.5, 0.45, 0.2, 8, Vector3(0, 0.25, 0), Parts.surf("hull"), Parts.OCTAGON)
	var top := Vector3(0, 1.6, 0)
	for degrees: float in [30.0, 150.0, 270.0]:
		var foot := Parts.around(1.0, degrees, 0.25)
		m.strut(foot, top, 0.14, Parts.surf("hull_light"))
		m.box(Vector3(0.3, 0.12, 0.3), foot - Vector3(0, 0.02, 0), Parts.surf(Parts.accent(level, 4, "hull")))
	if level >= 2:
		m.prism(0.3, 0.2, 0.25, 6, top - Vector3(0, 0.1, 0), Parts.surf("metal"))
	var radius := 0.5 + 0.06 * level
	var centre := top + Vector3(0, radius * 0.8, 0)
	m.orb(radius, 8, 4, centre, Parts.surf("glow_green"))
	if level >= 3:
		m.ring(radius + 0.05, radius + 0.2, 0.08, 10, centre - Vector3(0, 0.04, 0), Parts.surf("metal"))


static func build_flak_cannon(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.4)
	m.prism(0.5, 0.38, 1.0, 6, Vector3(0, 0.4, 0), Parts.surf("hull"))
	p.pivot = Vector3(0, 1.4, 0)
	p.speed = 0.5
	var head := p.spin
	head.box(Vector3(0.95, 0.6, 0.8), Vector3(0, 0, -0.15), Parts.surf("hull_light"))
	if level >= 4:
		head.box(Vector3(0.97, 0.1, 0.82), Vector3(0, 0.4, -0.15), Parts.surf("gold"))
	for x: float in [-0.2, 0.2]:
		for z: float in [-0.05, 0.2]:
			var muzzle := Vector3(x, 0.45, z) + LowPolyMesh.turn(Vector3(0, 1.3, 0), Vector3(35, 0, 0))
			head.prism(0.09, 0.07, 1.3, 6, Vector3(x, 0.45, z), Parts.surf("metal"), Vector3(35, 0, 0))
			head.box(Vector3(0.12, 0.1, 0.12), muzzle - Vector3(0, 0.05, 0), Parts.surf("glow_orange"))
	if level >= 2:
		head.box(Vector3(0.3, 0.2, 0.3), Vector3(0, 0.6, -0.4), Parts.surf("hull_dark"))
	if level >= 3:
		for x: float in [-0.6, 0.6]:
			head.prism(0.25, 0.25, 0.24, 8, Vector3(x - 0.12 * signf(x), 0.3, -0.15), Parts.surf("hull_dark"),
				Vector3(0, 0, -90 * signf(x)))


static func build_arc_tower(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.35)
	var height := 1.4 + 0.15 * level
	m.prism(0.4, 0.18, height, 6, Vector3(0, 0.35, 0), Parts.surf("hull"))
	var coil := Parts.accent(level, 4, "metal")
	var coils := 1 + level
	for i: int in coils:
		var t := (i + 0.5) / coils
		var radius := lerpf(0.4, 0.18, t)
		m.ring(radius, radius + 0.2, 0.08, 6, Vector3(0, 0.35 + height * t, 0), Parts.surf(coil))
	var top := 0.35 + height
	m.prism(0.12, 0.1, 0.2, 6, Vector3(0, top, 0), Parts.surf("metal_dark"))
	var orb := 0.32 + 0.04 * level
	m.orb(orb, 8, 4, Vector3(0, top + 0.2 + orb * 0.9, 0), Parts.surf("glow_cyan"))


static func build_cloaked_sentry(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.92, 0.85, 0.25, 8, Vector3.ZERO, Parts.surf("hull_dark"), Parts.OCTAGON)
	if level >= 3:
		m.prism(0.93, 0.93, 0.05, 8, Vector3(0, 0.18, 0), Parts.surf("gold"), Parts.OCTAGON)
	m.prism(0.62, 0.6, 0.06, 8, Vector3(0, 0.25, 0), Parts.surf("hull"), Parts.OCTAGON)
	for yaw: float in [45.0, -45.0]:
		m.box(Vector3(1.1, 0.03, 0.06), Vector3(0, 0.31, 0), Parts.surf("glow_cyan"), Vector3(0, yaw, 0))
	if level >= 2:
		m.ring(0.6, 0.67, 0.04, 8, Vector3(0, 0.25, 0), Parts.surf("glow_cyan"), Parts.OCTAGON)


static func build_gravity_well(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.92, 0.85, 0.2, 8, Vector3.ZERO, Parts.surf("hull_dark"), Parts.OCTAGON)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.14, 1.2, 0.14), Vector3(side * 0.48, 0.2, -side * 0.48), Parts.surf(Parts.accent(level, 3, "hull_light")),
			Vector3(0, 45, 0))
		m.box(Vector3(0.2, 0.08, 0.2), Vector3(side * 0.48, 1.4, -side * 0.48), Parts.surf("glow_violet"), Vector3(0, 45, 0))
	m.prism(0.25, 0.18, 0.35, 6, Vector3(0, 0.2, 0), Parts.surf("hull"))
	m.orb(0.15, 6, 3, Vector3(0, 1.0, 0), Parts.surf("glow_violet"))
	p.pivot = Vector3(0, 1.0, 0)
	p.speed = 1.5
	p.spin.ring(0.45, 0.58, 0.1, 10, Vector3(0, 0, -0.05), Parts.surf("glow_violet"), Vector3(90, 0, 0))
	if level >= 2:
		p.spin.ring(0.28, 0.38, 0.08, 8, Vector3(0.04, 0, 0), Parts.surf("glow_violet"), Vector3(0, 0, 90))


static func build_emp_tower(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.35)
	var height := 1.9 + 0.3 * level
	m.prism(0.5, 0.28, height, 6, Vector3(0, 0.35, 0), Parts.surf("hull"))
	var top := 0.35 + height
	m.ring(0.28, 0.62, 0.16, 8, Vector3(0, top - 0.35, 0), Parts.surf("hazard"))
	if level >= 2:
		m.ring(0.38, 0.6, 0.1, 8, Vector3(0, 0.35 + height * 0.45, 0), Parts.surf(Parts.accent(level, 3, "hazard")))
	m.dome(0.3, 0.3, 6, 2, Vector3(0, top, 0), Parts.surf("glow_blue"))
	if level >= 3:
		for degrees: float in [45.0, 135.0, 225.0, 315.0]:
			m.pyramid(0.12, 0.35, Parts.around(0.5, degrees, top - 0.19), Parts.surf("gold"))


static func build_railgun(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.35)
	m.box(Vector3(1.1, 0.5, 1.1), Vector3(0, 0.35, 0), Parts.surf("hull"), Vector3(0, 45, 0))
	if level >= 2:
		for side: float in [-1.0, 1.0]:
			m.box(Vector3(0.3, 0.4, 0.5), Vector3(side * 0.55, 0.35, side * 0.55), Parts.surf("hull_light"), Vector3(0, 45, 0))
	var back := Vector3(-0.85, 0.95, 0.85)
	var muzzle := Vector3(0.95 + 0.05 * level, 1.15, -0.95 - 0.05 * level)
	m.box(Vector3(0.6, 0.4, 0.6), back + Vector3(0.2, -0.15, -0.2), Parts.surf("hull_dark"), Vector3(0, 45, 0))
	var side_offset := Vector3(0.085, 0, 0.085)
	var rail := Parts.accent(level, 3, "metal")
	m.strut(back + side_offset, muzzle + side_offset, 0.1, Parts.surf(rail))
	m.strut(back - side_offset, muzzle - side_offset, 0.1, Parts.surf(rail))
	for t: float in [0.35, 0.55, 0.75]:
		m.box(Vector3(0.2, 0.14, 0.2), back.lerp(muzzle, t) - Vector3(0, 0.07, 0), Parts.surf("glow_cyan"), Vector3(0, 45, 0))


static func build_ion_beam(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.9, 0.85, 0.25, 6, Vector3.ZERO, Parts.surf("hull_dark"))
	var height := 1.1 + 0.3 * level
	m.prism(0.2, 0.13, height, 6, Vector3(0, 0.25, 0), Parts.surf("hull_light"))
	var top := 0.25 + height
	m.ring(0.13, 0.3, 0.12, 8, Vector3(0, top - 0.1, 0), Parts.surf(Parts.accent(level, 2, "metal")))
	m.orb(0.22, 8, 3, Vector3(0, top + 0.2, 0), Parts.surf("glow_red"))
	if level >= 2:
		m.cone(0.06, 0.3, 4, Vector3(0, top + 0.38, 0), Parts.surf("gold"))


static func build_orbital_cannon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.85, 1.75, 0.4, 8, Vector3.ZERO, Parts.surf("hull_dark"), Parts.OCTAGON)
	m.prism(1.25, 1.15, 0.35, 8, Vector3(0, 0.4, 0), Parts.surf("hull"), Parts.OCTAGON)
	m.prism(0.4, 0.3, 0.5, 6, Vector3(0, 0.75, 0), Parts.surf("hull_light"))
	var dish := 1.2 if level < 2 else 1.4
	var aim := Vector3(40, 135, 0)
	var centre := Vector3(0, 1.25, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.15, 0), Vector2(dish, 0.45), Vector2(dish - 0.12, 0.5), Vector2(0, 0.15),
	]), 10, centre, Parts.surf("white"), aim)
	m.cone(0.12, 1.2, 6, centre + LowPolyMesh.turn(Vector3(0, 0.15, 0), aim), Parts.surf("glow_blue"), aim)
	if level >= 2:
		m.ring(dish - 0.12, dish + 0.02, 0.06, 10, centre + LowPolyMesh.turn(Vector3(0, 0.45, 0), aim), Parts.surf("gold"), aim)
		for degrees: float in [45.0, 225.0]:
			var pylon := Parts.around(1.45, degrees, 0.4)
			m.prism(0.14, 0.1, 0.8, 4, pylon, Parts.surf("hull_light"))
			m.pyramid(0.16, 0.2, pylon + Vector3(0, 0.8, 0), Parts.surf("glow_blue"))


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


## `origin` plus `local` turned by `rot`: a point on a turned part.
static func _at(origin: Vector3, local: Vector3, rot: Vector3) -> Vector3:
	return origin + LowPolyMesh.turn(local, rot)


static func _glow(tint: Color) -> Surf:
	return Surf.make(MaterialKit.Layer.GLOW, tint, 1.0, Surf.UNLIT, true)
