extends RefCounted
## Models of the army buildings, in the comic style (docs/reference/art-style.md): hull-light
## halls and towers on concrete pads, army orange on one or two surfaces and in one glow,
## gunmetal machinery, gold trim at the top level.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. Each builds
## its level as a run of additions (`if level >= 3:` adds the second bay), so the levels of a
## type read as one building growing.

## The army's surfaces: its orange accent and glow, the round and armoured hulls.
static var ORANGE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY)
static var ORANGE_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.LIT, true)
static var GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT, true)
static var HULL_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var MID_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var ARMOUR_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var DARK_PLATE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var DARK_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK, 1.0, Surf.LIT, true)
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
static var PIPE := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 2.0, Surf.LIT, true)
static var PIPE_LIGHT := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID)
static var ROLLER := Surf.make(MaterialKit.Layer.VENT, MaterialKit.ARMY, 2.0)
static var BELT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 3.0)
static var SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.CORE_GLASS)
## Yellow heat: a furnace's core, welding sparks.
static var HOT := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT)
## Nanite goo behind glass, and a screen showing it.
static var GOO := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN, 1.0, Surf.UNLIT, true)
static var GOO_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.NANITE_GREEN)


## A long vaulted hangar: the main bay with its striped door, the control tower in the back
## corner, landing lights along the apron. Wider door at 2 and 3, a second bay at 3, roof
## dishes at 4.
static func build_hangar(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 5)
	var doors: Array[float] = [1.3, 1.6, 1.9]
	_vault(m, Vector3(-1.0, g, -2.25), 2.6, 3.6, 0.75, doors[mini(level, 3) - 1], level)
	if level >= 3:
		_vault(m, Vector3(1.35, g, -0.9), 1.8, 2.25, 0.55, 1.2, level)
	else:
		m.disc(0.75, 24, Vector3(1.35, g + 0.002, 0.2), Parts.HAZARD)
		m.disc(0.6, 24, Vector3(1.35, g + 0.004, 0.2), ARMOUR)
	var lights := 4 + level
	for i: int in lights:
		var x := -1.85 + 3.9 * i / (lights - 1)
		Parts.landing_light(m, Vector3(x, g, 2.05), 0.11, GLOW)
	# The control tower.
	var tower := Vector3(1.45, g, -1.65)
	m.box_chamfered(Vector3(0.95, 0.3, 0.95), 0.06, tower, ARMOUR)
	var shaft := 1.0 + 0.06 * level
	m.prism(0.3, 0.25, shaft, 16, tower + Vector3(0, 0.3, 0), MID_ROUND)
	var cab := tower + Vector3(0, 0.3 + shaft, 0)
	m.prism(0.42, 0.42, 0.1, 16, cab, HULL_ROUND)
	m.ring(0.41, 0.44, 0.05, 16, cab + Vector3(0, 0.03, 0), GLOW)
	m.prism(0.42, 0.5, 0.34, 16, cab + Vector3(0, 0.1, 0), Parts.GLASS)
	m.lathe(PackedVector2Array([
		Vector2(0.56, 0), Vector2(0.56, 0.06), Vector2(0.4, 0.16), Vector2(0, 0.16),
	]), 16, cab + Vector3(0, 0.44, 0), GOLD_ROUND if level >= 5 else HULL_ROUND)
	Parts.mast(m, cab + Vector3(0.12, 0.6, -0.1), 0.3 + 0.03 * level, 0.06, GLOW)
	if level >= 2:
		# Fuel tanks on the apron, beside the main door.
		for z: float in [1.68, 1.92]:
			Parts.tank(m, 0.1, 0.32, Vector3(-2.2, g, z), ORANGE_ROUND, 0.03)
	if level >= 4:
		_roof_dish(m, Vector3(-1.0, g + 1.98, -1.5), 0.5, level)
		_roof_dish(m, Vector3(1.35, g + 1.38, -0.4), 0.32, level)


## A dish on a stub at `foot`, turned to the right of the view, with a glowing feed.
static func _roof_dish(m: LowPolyMesh, foot: Vector3, radius: float, level: int) -> void:
	var aim := Vector3(55, 135, 0)
	m.prism(0.07, 0.06, 0.22, 16, foot, Parts.GUNMETAL)
	var centre := foot + Vector3(0, 0.2, 0)
	Parts.dish(m, radius, radius * 0.38, centre, GOLD_ROUND if level >= 5 else HULL_ROUND, aim)
	var axis := LowPolyMesh.turn(Vector3.UP, aim)
	var focus := centre + axis * radius * 0.85
	Parts.pipe(m, centre + axis * radius * 0.1, focus, 0.025, Parts.ROD)
	m.orb(0.05, 16, 6, focus, GLOW)


## One bay of the hangar: walls, a barrel roof with orange ribs, and the striped door on its
## +Z end. `back` is the middle of its back wall on the pad.
static func _vault(m: LowPolyMesh, back: Vector3, width: float, length: float, wall: float,
		door: float, level: int) -> void:
	var radius := width * 0.5 - 0.005
	var front := back.z + length
	m.box_chamfered(Vector3(width, wall, length + 0.02), 0.06, back + Vector3(0, 0, length * 0.5 + 0.01),
		ARMOUR)
	var axis := back + Vector3(0, wall, 0)
	m.prism(radius, radius, length, 24, axis, HULL_ROUND, Vector3(90, 0, 0))
	var gable := PackedVector3Array()
	for k: int in 13:
		var angle := PI * k / 12
		gable.append(axis + Vector3(radius * cos(angle), radius * sin(angle), length + 0.012))
	m.polygon(gable, Parts.HULL_LIGHT)
	for k: int in 3:
		var z := back.z + length * (0.18 + 0.32 * k)
		m.ring(radius - 0.02, radius + 0.07, 0.14, 24, Vector3(back.x, axis.y, z), ORANGE_ROUND,
			Vector3(90, 0, 0))
	# The door: leaves with a hazard band, hazard posts, a lintel and a glow strip.
	var post := door * 0.5 + 0.08
	var height := wall + sqrt(radius * radius - (post + 0.08) * (post + 0.08)) - 0.2
	var z := front + 0.02
	var leaf := door / 4.0
	for i: int in 4:
		var x := back.x - door * 0.5 + leaf * (i + 0.5)
		m.box_chamfered(Vector3(leaf - 0.03, height, 0.08), 0.02, Vector3(x, back.y, z + 0.04), DARK_PLATE)
	m.box_chamfered(Vector3(door, 0.26, 0.1), 0.03, Vector3(back.x, back.y, z + 0.05), Parts.HAZARD)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.16, height + 0.14, 0.16), 0.04, Vector3(back.x + side * post, back.y, z + 0.08),
			Parts.HAZARD)
	m.box_chamfered(Vector3(door + 0.32, 0.14, 0.18), 0.04, Vector3(back.x, back.y + height, z + 0.09),
		Parts.GOLD_TRIM if level >= 5 else ORANGE)
	m.box(Vector3(door * 0.6, 0.06, 0.04), Vector3(back.x, back.y + height + 0.22, z), GLOW)


## A factory block under a sawtooth roof, smokestacks on a furnace box behind it, a conveyor
## out to a loading dock under an orange gantry crane. More stacks at 3 and 5, a second storey
## at 4.
static func build_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	var roof := g + 0.8
	m.box_chamfered(Vector3(1.7, 0.8, 1.6), 0.06, Vector3(-0.45, g, -0.5), Parts.HULL_LIGHT)
	for z: float in [-0.6, -0.15]:
		m.wedge(Vector3(1.6, 0.3, 0.45), Vector3(-0.45, roof, z + 0.225), MID_ROUND, Vector3(0, 180, 0))
		m.box(Vector3(1.45, 0.2, 0.03), Vector3(-0.45, roof + 0.04, z + 0.465), Parts.GLASS)
	if level >= 4:
		var storey := Vector3(-0.45, roof, -0.95)
		m.box_chamfered(Vector3(1.6, 0.5, 0.65), 0.06, storey, Parts.HULL_LIGHT)
		m.box(Vector3(1.3, 0.14, 0.03), storey + Vector3(0, 0.22, 0.33), GLOW)
		m.box_chamfered(Vector3(0.4, 0.14, 0.3), 0.04, storey + Vector3(-0.35, 0.5, 0), VENT)
	else:
		m.box_chamfered(Vector3(0.4, 0.14, 0.3), 0.04, Vector3(-0.8, roof, -0.95), VENT)
	# The front: an orange roller door and windows.
	m.box_chamfered(Vector3(0.62, 0.56, 0.06), 0.02, Vector3(-0.8, g, 0.32), ROLLER)
	m.box(Vector3(0.7, 0.05, 0.04), Vector3(-0.8, g + 0.62, 0.32), GLOW)
	for x: float in [-0.2, 0.17]:
		m.box_chamfered(Vector3(0.26, 0.24, 0.04), 0.02, Vector3(x, g + 0.32, 0.31), Parts.GLASS)
	if level >= 2:
		for x: float in [-1.26, 0.36]:
			m.box_chamfered(Vector3(0.1, 0.7, 0.1), 0.03, Vector3(x, g, 0.3), ARMOUR)
	# The conveyor from a hatch in the side wall out over the dock.
	m.box_chamfered(Vector3(0.06, 0.34, 0.4), 0.02, Vector3(0.42, g + 0.12, -0.15), DARK_PLATE)
	m.box_chamfered(Vector3(0.9, 0.08, 0.28), 0.02, Vector3(0.85, g + 0.3, -0.15), BELT)
	for x: float in [0.65, 1.15]:
		m.box_chamfered(Vector3(0.08, 0.3, 0.2), 0.02, Vector3(x, g, -0.15), Parts.GUNMETAL)
	m.box_chamfered(Vector3(0.18, 0.16, 0.18), 0.03, Vector3(0.75, g + 0.38, -0.15), ORANGE)
	# The loading dock and its crates.
	m.box_chamfered(Vector3(0.8, 0.2, 0.95), 0.04, Vector3(0.9, g, 0.8), ARMOUR)
	m.box(Vector3(0.8, 0.04, 0.12), Vector3(0.9, g + 0.2, 1.21), Parts.HAZARD)
	var crates: Array[Vector3] = [Vector3(0.75, 0, 0.55), Vector3(1.05, 0, 0.62), Vector3(0.8, 0, 0.9)]
	for i: int in mini(level + 1, 3):
		m.box_chamfered(Vector3(0.22, 0.2, 0.22), 0.03, crates[i] + Vector3(0, g + 0.2, 0), ORANGE)
	# The gantry crane over the dock.
	var top := g + 1.25
	for x: float in [0.57, 1.23]:
		for z: float in [0.4, 1.2]:
			m.box_chamfered(Vector3(0.08, top - g - 0.2, 0.08), 0.02, Vector3(x, g + 0.2, z), ORANGE)
		Parts.beam(m, Vector3(x, top, 0.33), Vector3(x, top, 1.27), 0.1, ORANGE)
	var bridge := 0.85
	Parts.beam(m, Vector3(0.5, top + 0.1, bridge), Vector3(1.3, top + 0.1, bridge), 0.1,
		Parts.GOLD_TRIM if level >= 5 else Parts.HULL_DARK)
	m.box_chamfered(Vector3(0.2, 0.12, 0.18), 0.03, Vector3(0.9, top - 0.02, bridge), Parts.GUNMETAL)
	m.prism(0.012, 0.012, 0.35, 8, Vector3(0.9, top - 0.37, bridge), Parts.ROD)
	m.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Vector3(0.9, top - 0.43, bridge), Parts.HAZARD)
	# Smokestacks on the furnace box.
	m.box_chamfered(Vector3(0.75, 0.35, 0.7), 0.05, Vector3(0.92, g, -0.92), DARK_PLATE)
	var stacks: Array[Vector3] = [
		Vector3(0.75, 0, -1.08), Vector3(1.1, 0, -0.78), Vector3(1.1, 0, -1.12), Vector3(0.72, 0, -0.72),
	]
	var counts: Array[int] = [2, 2, 3, 3, 4]
	for i: int in counts[level - 1]:
		var height := 1.2 - 0.18 * i + 0.05 * level
		_stack(m, stacks[i] + Vector3(0, g + 0.35, 0), 0.13, height, level)


## A smokestack standing on `foot`: a ribbed pipe with an orange band and a glowing mouth.
static func _stack(m: LowPolyMesh, foot: Vector3, radius: float, height: float, level: int) -> void:
	m.prism(radius, radius * 0.8, height, 16, foot, PIPE)
	m.ring(radius * 0.8, radius * 1.12, 0.07, 16, foot + Vector3(0, height * 0.55, 0), ORANGE_ROUND)
	var mouth := foot + Vector3(0, height, 0)
	m.ring(radius * 0.55, radius * 0.95, 0.06, 16, mouth, GOLD_ROUND if level >= 5 else Parts.GUNMETAL)
	m.disc(radius * 0.56, 16, mouth + Vector3(0, 0.03, 0), GLOW)


## The bulky fabricator: an armoured hall with a furnace in its front, an orange press arm
## hammering an anvil beside it. A second arm at 2, a chimney cluster at 3.
static func build_heavy_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	var hall := Vector3(-0.42, g, -0.42)
	m.box_chamfered(Vector3(1.76, 1.0, 1.76), 0.08, hall, ARMOUR)
	m.box_chamfered(Vector3(1.2, 0.4, 1.2), 0.08, hall + Vector3(-0.18, 1.0, -0.18), DARK_PLATE)
	# Armour slabs down the sides.
	for z: float in [-1.0, -0.45, 0.1]:
		m.box_chamfered(Vector3(0.1, 0.8, 0.45), 0.03, Vector3(0.5, g + 0.06, z), ARMOUR)
	for x: float in [-1.12, 0.22]:
		m.box_chamfered(Vector3(0.36, 0.8, 0.1), 0.03, Vector3(x, g + 0.06, 0.5), ARMOUR)
	if level >= 2:
		for x: float in [-1.12, 0.22]:
			m.box_chamfered(Vector3(0.38, 0.12, 0.14), 0.03, Vector3(x, g + 0.86, 0.5), DARK_PLATE)
	# The furnace mouth and the glowing slag trough in front of it.
	var mouth := Vector3(-0.45, g, 0.48)
	m.box(Vector3(0.6, 0.55, 0.02), mouth, GLOW)
	m.box(Vector3(0.36, 0.32, 0.02), mouth + Vector3(0, 0, 0.01), HOT)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.14, 0.62, 0.16), 0.04, mouth + Vector3(side * 0.37, 0, 0.02), DARK_PLATE)
	m.box_chamfered(Vector3(0.9, 0.16, 0.2), 0.04, mouth + Vector3(0, 0.6, 0.03),
		Parts.GOLD_TRIM if level >= 3 else DARK_PLATE)
	m.box_chamfered(Vector3(0.36, 0.06, 0.75), 0.02, mouth + Vector3(0, 0, 0.42), DARK_PLATE)
	m.box(Vector3(0.2, 0.02, 0.72), mouth + Vector3(0, 0.06, 0.42), GLOW)
	m.box(Vector3(0.08, 0.02, 0.72), mouth + Vector3(0, 0.07, 0.42), HOT)
	# The press arms.
	_press_arm(m, Vector3(-0.15, g + 1.0, 0.1), Vector3(0.88, g, 0.85), level)
	if level >= 2:
		_press_arm(m, Vector3(-0.15, g + 1.0, -0.95), Vector3(0.88, g, -0.85), level)
	# Exhausts: one stack, a cluster of three at 3.
	_stack(m, Vector3(-0.95, g + 1.4, -0.95), 0.14, 0.55, level)
	if level >= 3:
		_stack(m, Vector3(-0.55, g + 1.4, -1.05), 0.12, 0.75, level)
		_stack(m, Vector3(-1.02, g + 1.4, -0.55), 0.1, 0.4, level)


## A press arm: a turret on the hall's roof at `shoulder`, a fat orange boom up to an elbow
## over an anvil standing at `anvil`, a hydraulic ram down from the elbow to a heavy head.
static func _press_arm(m: LowPolyMesh, shoulder: Vector3, anvil: Vector3, level: int) -> void:
	m.prism(0.3, 0.27, 0.24, 16, shoulder, Parts.GUNMETAL)
	var pivot := shoulder + Vector3(0, 0.36, 0)
	var elbow := Vector3(anvil.x, shoulder.y + 1.0, anvil.z)
	m.prism(0.2, 0.2, 0.36, 16, pivot + Vector3(0, 0, -0.18), Parts.GUNMETAL, Vector3(90, 0, 0))
	Parts.beam(m, pivot, elbow, 0.28, ORANGE, 0.06)
	Parts.pipe(m, shoulder + Vector3(0.18, 0.24, 0), elbow + Vector3(-0.08, -0.22, 0), 0.06, MID_ROUND)
	m.prism(0.19, 0.19, 0.34, 16, elbow + Vector3(0, 0, -0.17), Parts.GUNMETAL, Vector3(90, 0, 0))
	var head := anvil + Vector3(0, 0.66, 0)
	Parts.pipe(m, elbow, head + Vector3(0, 0.62, 0), 0.12, Parts.GUNMETAL)
	Parts.pipe(m, head + Vector3(0, 0.3, 0), head + Vector3(0, 0.66, 0), 0.07, MID_ROUND)
	m.box_chamfered(Vector3(0.46, 0.32, 0.46), 0.07, head, ORANGE)
	m.box(Vector3(0.48, 0.07, 0.48), head + Vector3(0, 0.04, 0),
		Parts.GOLD_TRIM if level >= 3 else Parts.HAZARD)
	m.box_chamfered(Vector3(0.52, 0.3, 0.52), 0.05, anvil, Parts.GUNMETAL)
	m.box(Vector3(0.54, 0.06, 0.54), anvil + Vector3(0, 0.2, 0), Parts.HAZARD)


## A lab ring with screens around a central observatory dome, its telescope out of the slit,
## and a radar dish spinning on a mast in the corner. Antennas at 2 and 4, a second ring at 3.
static func build_research_lab(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	m.ring(1.08, 1.13, 0.1, 24, Vector3(0, g, 0), ORANGE_ROUND)
	m.lathe(PackedVector2Array([
		Vector2(1.08, 0), Vector2(1.08, 0.42), Vector2(1.0, 0.5), Vector2(0.66, 0.5), Vector2(0.66, 0),
	]), 24, Vector3(0, g, 0), HULL_ROUND)
	for degrees: float in [5.0, 45.0]:
		_screen(m, 1.085, degrees, g + 0.15, 0.36, 0.22)
	m.box_chamfered(Vector3(0.28, 0.34, 0.08), 0.03, Parts.around(1.07, 92, g), DARK_PLATE, Vector3(0, -2, 0))
	m.box(Vector3(0.34, 0.05, 0.04), Parts.around(1.1, 92, g + 0.38), GLOW, Vector3(0, -2, 0))
	var drum := 0.75
	if level >= 3:
		m.lathe(PackedVector2Array([
			Vector2(0.95, 0), Vector2(0.95, 0.24), Vector2(0.88, 0.3), Vector2(0.66, 0.3), Vector2(0.66, 0),
		]), 24, Vector3(0, g + 0.5, 0), MID_ROUND)
		for degrees: float in [25.0, 65.0]:
			_screen(m, 0.955, degrees, g + 0.56, 0.3, 0.16)
		drum = 1.05
	# The observatory: a drum, a dome with a dark slit and the telescope out of it.
	m.prism(0.63, 0.63, drum, 24, Vector3(0, g, 0), MID_ROUND)
	var centre := Vector3(0, g + drum, 0)
	m.ring(0.62, 0.69, 0.05, 24, centre, GLOW)
	if level >= 5:
		m.ring(0.62, 0.68, 0.05, 24, centre - Vector3(0, 0.08, 0), GOLD_ROUND)
	m.dome(0.62, 0.62, 16, 7, centre, HULL_ROUND)
	var across := Vector3(0.7071, 0, 0.7071)
	m.ring(0.6, 0.65, 0.18, 24, centre - across * 0.09, DARK_ROUND, Parts.facing(across))
	var aim := Vector3(0.42, 0.8, -0.42).normalized()
	Parts.pipe(m, centre + aim * 0.3, centre + aim * 0.95, 0.1, HULL_ROUND)
	m.ring(0.07, 0.13, 0.1, 16, centre + aim * 0.85, ORANGE_ROUND, Parts.facing(aim))
	m.disc(0.085, 16, centre + aim * 0.955, Parts.GLASS, Parts.facing(aim))
	if level >= 5:
		m.orb(0.07, 16, 6, centre + Vector3(0, 0.66, 0), GOLD_ROUND)
	# Antennas on the corners.
	if level >= 2:
		_antenna(m, Vector3(-0.98, g, -0.98), 1.3)
	if level >= 4:
		_antenna(m, Vector3(-1.0, g, 0.98), 1.0)
	# The radar mast against the ring, near enough the middle that the spinning dish's sweep
	# stays inside the footprint; the dish spins.
	var mast := Vector3(0.85, g, -0.85)
	m.prism(0.12, 0.11, 0.14, 16, mast, ARMOUR_ROUND)
	var height := 1.25 + 0.08 * level
	m.prism(0.08, 0.06, height, 16, mast + Vector3(0, 0.14, 0), Parts.GUNMETAL)
	p.pivot = mast + Vector3(0, 0.14 + height, 0)
	p.speed = 0.9
	var radar := p.spin
	radar.box_chamfered(Vector3(0.12, 0.16, 0.12), 0.03, Vector3.ZERO, Parts.GUNMETAL)
	var tilt := Vector3(60, 90, 0)
	var hub := Vector3(0, 0.14, 0)
	Parts.dish(radar, 0.38, 0.14, hub, GOLD_ROUND if level >= 5 else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(radar, hub + axis * 0.05, hub + axis * 0.32, 0.02, Parts.ROD)
	radar.orb(0.045, 16, 6, hub + axis * 0.32, GLOW)


## A flat screen on a round wall of `radius`, at `degrees` around it, its bottom at `y`.
static func _screen(m: LowPolyMesh, radius: float, degrees: float, y: float, width: float,
		height: float) -> void:
	m.box_chamfered(Vector3(width, height, 0.04), 0.015, Parts.around(radius, degrees, y), SCREEN,
		Vector3(0, 90 - degrees, 0))


## A sensor mast on a little foot: a thin rod with an orange bulb.
static func _antenna(m: LowPolyMesh, foot: Vector3, height: float) -> void:
	m.box_chamfered(Vector3(0.18, 0.1, 0.18), 0.03, foot, Parts.GUNMETAL)
	Parts.mast(m, foot + Vector3(0, 0.1, 0), height, 0.06, GLOW)


## Vats of glowing green nanite goo seen through glass bands, round a pump block, with pipes
## and their elbows running between them. A vat more at each level; gold rims at 4.
static func build_nanite_foundry(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	# The pump block in the middle, with goo screens and a vent.
	var pump := Vector3(0.1, g, 0.1)
	m.box_chamfered(Vector3(0.5, 0.45, 0.5), 0.05, pump, Parts.HULL_LIGHT)
	m.box_chamfered(Vector3(0.3, 0.18, 0.03), 0.01, pump + Vector3(0, 0.16, 0.25), GOO_SCREEN)
	m.box_chamfered(Vector3(0.03, 0.18, 0.3), 0.01, pump + Vector3(0.25, 0.16, 0), GOO_SCREEN)
	m.box_chamfered(Vector3(0.3, 0.1, 0.3), 0.03, pump + Vector3(0, 0.45, 0), VENT)
	# [position, radius, height] of each vat, in the order the levels add them.
	var vats: Array[Array] = [
		[Vector3(-0.62, g, -0.62), 0.5, 1.35],
		[Vector3(0.68, g, -0.72), 0.38, 1.0],
		[Vector3(-0.72, g, 0.66), 0.38, 0.9],
		[Vector3(0.78, g, 0.62), 0.32, 0.75],
		[Vector3(0.02, g, 1.0), 0.26, 0.6],
	]
	# An arch of pipe over from the big vat's lid into the next one's.
	var big: Vector3 = vats[0][0] + Vector3(0.3, 1.33, -0.02)
	var second: Vector3 = vats[1][0] + Vector3(-0.16, 0.98, 0.01)
	Parts.pipe_run(m, PackedVector3Array([
		big, big + Vector3(0, 0.2, 0), Vector3(second.x, big.y + 0.2, second.z), second,
	]), 0.05, PIPE_LIGHT, 12)
	for i: int in mini(level + 1, vats.size()):
		var spot: Vector3 = vats[i][0]
		var radius: float = vats[i][1]
		var height: float = vats[i][2]
		_vat(m, spot, radius, height, level)
		if i < 3:
			# Out of the vat's upper shell, down to the pad and along it into the pump.
			var toward := Vector3(pump.x - spot.x, 0, pump.z - spot.z).normalized()
			var high := spot + toward * (radius + 0.16) + Vector3(0, height * 0.8, 0)
			var low := Vector3(high.x, g + 0.1, high.z)
			Parts.pipe_run(m, PackedVector3Array([
				spot + toward * (radius - 0.04) + Vector3(0, height * 0.8, 0), high, low,
				pump + Vector3(0, 0.1, 0) - toward * 0.2,
			]), 0.05, PIPE_LIGHT, 12)
		else:
			# A short pipe across to the vat it stands next to.
			var next: Vector3 = vats[i - 2][0]
			var toward := Vector3(next.x - spot.x, 0, next.z - spot.z).normalized()
			var y := Vector3(0, height * 0.82, 0)
			Parts.pipe(m, spot + toward * (radius - 0.04) + y, next - toward * 0.2 + y, 0.05, PIPE_LIGHT,
				12, false)


## A vat standing on `foot`: an armoured lower shell, a band of glowing goo behind glass framed
## by rims, an upper shell with a chamfered lid and an orange cap. The rims are gold at the top
## level.
static func _vat(m: LowPolyMesh, foot: Vector3, radius: float, height: float, level: int) -> void:
	var band := height * 0.4
	var glass := height * 0.28
	var rim := radius + 0.035
	var gold := level >= 4
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, band - 0.05)]), 16, foot, ARMOUR_ROUND)
	m.lathe(PackedVector2Array([
		Vector2(radius, band - 0.05), Vector2(rim, band - 0.05), Vector2(rim, band), Vector2(radius - 0.03, band),
	]), 16, foot, GOLD_ROUND if gold else ARMOUR_ROUND)
	m.lathe(PackedVector2Array([Vector2(radius - 0.03, 0), Vector2(radius - 0.03, glass)]), 16,
		foot + Vector3(0, band, 0), GOO)
	var upper := band + glass
	var top := height - upper
	m.lathe(PackedVector2Array([Vector2(rim, 0), Vector2(rim, 0.05), Vector2(radius, 0.05)]), 16,
		foot + Vector3(0, upper, 0), GOLD_ROUND if gold else HULL_ROUND)
	m.lathe(PackedVector2Array([
		Vector2(radius, 0.05), Vector2(radius, top - 0.08), Vector2(radius - 0.08, top), Vector2(0, top),
	]), 16, foot + Vector3(0, upper, 0), HULL_ROUND)
	m.prism(radius * 0.42, radius * 0.34, 0.1, 16, foot + Vector3(0, height, 0), ORANGE_ROUND)


static func build_drydock(p: Parts, level: int) -> void:
	var m := p.body
	Parts.slab(m, 4, 0.15)
	for z: float in [-0.85, 0.85]:
		m.box(Vector3(3.2, 0.2, 0.18), Vector3(0, 0.15, z), Parts.surf("metal_dark"))
	for x: float in [-0.9, 0.0, 0.8]:
		m.box(Vector3(0.3, 0.4, 0.9), Vector3(x, 0.15, 0), Parts.surf("hull_dark"))
	m.box(Vector3(2.3, 0.55, 0.9), Vector3(-0.25, 0.55, 0), Parts.surf("hull_light"))
	m.wedge(Vector3(0.9, 0.55, 0.7), Vector3(1.25, 0.55, 0), Parts.surf("hull_light"), Vector3(0, 90, 0))
	m.box(Vector3(0.6, 0.35, 0.5), Vector3(-0.7, 1.1, 0), Parts.surf("hull"))
	m.box(Vector3(0.62, 0.08, 0.52), Vector3(-0.7, 1.32, 0), Parts.surf("glow_blue"))
	for z: float in [-0.22, 0.22]:
		m.box(Vector3(0.08, 0.22, 0.25), Vector3(-1.42, 0.7, z), Parts.surf("glow_cyan"))
	var frame := Parts.accent(level, 2, "hazard")
	var frames: Array[float] = [-1.0, 0.25]
	if level >= 2:
		frames.append(1.25)
	for x: float in frames:
		for z: float in [-1.15, 1.15]:
			m.box(Vector3(0.15, 1.7, 0.15), Vector3(x, 0.15, z), Parts.surf(frame))
		m.box(Vector3(0.15, 0.15, 2.45), Vector3(x, 1.85, 0), Parts.surf(frame))


static func build_alliance_beacon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.3, 1.2, 0.3, 6, Vector3.ZERO, Parts.surf("hull_dark"))
	m.box(Vector3(0.9, 0.3, 0.9), Vector3(0, 0.3, 0), Parts.surf("hull"), Vector3(0, 45, 0))
	var height := 2.0 + 0.3 * level
	m.prism(0.38, 0.12, height, 4, Vector3(0, 0.6, 0), Parts.surf(Parts.accent(level, 3, "hull_light")), Vector3(0, 45, 0))
	m.box(Vector3(0.6, 0.06, 0.6), Vector3(0, 0.6 + height * 0.4, 0), Parts.surf("hazard"), Vector3(0, 45, 0))
	if level >= 2:
		for degrees: float in [-45.0, 135.0]:
			var arm := Parts.around(0.55, degrees, 0.6 + height * 0.6)
			m.strut(Vector3(0, arm.y, 0), arm, 0.06, Parts.surf("metal"))
			m.disc(0.2, 6, arm, Parts.surf("white"), Vector3(0, -degrees, -60))
	var beacon := "glow_gold" if level >= 3 else "glow_cyan"
	m.orb(0.22 + 0.03 * level, 8, 3, Vector3(0, 0.75 + height + 0.1, 0), Parts.surf(beacon))
