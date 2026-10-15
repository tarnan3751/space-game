extends RefCounted
## Models of the army buildings, in the comic style (docs/reference/art-style.md): hull-light
## halls and towers on concrete pads, army orange on one or two surfaces and in one glow,
## gunmetal machinery, gold trim at the top level. They move (docs/reference/art-style.md,
## **Animation**): surface effects on the lamps, glows, screens, goo, sparks and smoke, and moving
## parts (Parts.moving) for the hangar door, the cranes, the press arms, the dishes, the telescope
## and the stirrer.
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
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
static var PIPE := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 2.0, Surf.LIT, true)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID)
static var ROLLER := Surf.make(MaterialKit.Layer.VENT, MaterialKit.ARMY, 2.0)
static var BELT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 3.0)
## A screen showing nanite goo, its rows scrolling.
static var GOO_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.NANITE_GREEN, 1.0, Surf.FLOW, false,
	true, 0.7)

## The animated surfaces (docs/reference/art-style.md, **Animation**). Lamps that chase, sparks
## that flicker apart and puffs that bob out of step take their phases through phased().
## The army glow pulsing (furnace mouths, reactors, engines) and blinking (lamps).
static var GLOW_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.PULSE,
	true)
static var LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var HOT_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.PULSE)
## Molten metal running out along V, at two speeds.
static var POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.FLOW, false, true,
	0.7)
static var HOT_POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLOW, false,
	true, 0.8)
## Sparks: flickering, and flickering and shaking off a welder.
static var SPARK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLICKER)
static var SPARK_ARC := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0,
	Surf.UNLIT | Surf.FLICKER | Surf.JITTER)
static var WELD_BLINK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK,
	true)
## A screen whose rows scroll; phased() sets its speed.
static var SCREEN_FLOW := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.CORE_GLASS, 1.0, Surf.FLOW)
## The lit hangar inside an opening door: an orange glow, its stripes rising.
static var INTERIOR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 2.0, Surf.UNLIT | Surf.FLOW, false,
	false, 0.35)
## Goo rising behind glass (phased() sets its speed), goo swirling in an open vat, its bubbles,
## and the pipes carrying it along.
static var GOO_FLOW := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN, 1.0,
	Surf.UNLIT | Surf.FLOW, true, true, 0.3)
static var GOO_SWIRL := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN, 1.0,
	Surf.UNLIT | Surf.FLOW_U, false, true, 0.65)
## A bubble is the goo's green half way to white, so it flashes brighter than the goo and
## shows as a dim green dot between flashes; too small for an outline.
static var BUBBLE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.NANITE_GREEN.lerp(Color.WHITE, 0.5), 1.0,
	Surf.UNLIT | Surf.BLINK, true, false)
static var PIPE_FLOW := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.FLOW, true, true,
	0.3)
## Glass glowing on a pulse: the hangar's control cab, the fabricator's roof windows.
static var CAB_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0,
	Surf.GLOSSY | Surf.PULSE, true)
static var WINDOW_GLOW := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.PULSE)
## Holograms, and the beacon's floating emitter and spike.
static var HOLOGRAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO | Surf.BOB, true)
static var HOLO_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.ENERGY, 1.0, Surf.HOLO, true)
static var ORB_BOB := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0,
	Surf.UNLIT | Surf.PULSE | Surf.BOB, true)
static var GOLD_BOB := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB,
	true)
static var GUNMETAL_BOB := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true)


## A long vaulted hangar: the main bay with its striped door, the control tower in the back
## corner, landing lights along the apron. Wider door at 2 and 3, a second bay at 3, roof
## dishes at 4. The main bay's door rises over its lit inside and drops again, the lights chase
## along the apron, the cab's glass pulses and a radar turns on its roof; from 4 the big roof
## dish sweeps.
static func build_hangar(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 5)
	var doors: Array[float] = [1.3, 1.6, 1.9]
	_vault(p, Vector3(-1.0, g, -2.25), 2.6, 3.6, 0.75, doors[mini(level, 3) - 1], level, true)
	if level >= 3:
		_vault(p, Vector3(1.35, g, -0.9), 1.8, 2.25, 0.55, 1.2, level, false)
	else:
		m.disc(0.75, 24, Vector3(1.35, g + 0.002, 0.2), Parts.HAZARD)
		m.disc(0.6, 24, Vector3(1.35, g + 0.004, 0.2), ARMOUR)
	var lights := 4 + level
	for i: int in lights:
		var x := -1.85 + 3.9 * i / (lights - 1)
		Parts.landing_light(m, Vector3(x, g, 2.05), 0.11, LAMP.phased(float(i) / lights))
	# The control tower.
	var tower := Vector3(1.45, g, -1.65)
	m.box_chamfered(Vector3(0.95, 0.3, 0.95), 0.06, tower, ARMOUR)
	var shaft := 1.0 + 0.06 * level
	m.prism(0.3, 0.25, shaft, 16, tower + Vector3(0, 0.3, 0), MID_ROUND)
	var cab := tower + Vector3(0, 0.3 + shaft, 0)
	m.prism(0.42, 0.42, 0.1, 16, cab, HULL_ROUND)
	m.ring(0.41, 0.44, 0.05, 16, cab + Vector3(0, 0.03, 0), GLOW)
	m.prism(0.42, 0.5, 0.34, 16, cab + Vector3(0, 0.1, 0), CAB_GLASS)
	m.lathe(PackedVector2Array([
		Vector2(0.56, 0), Vector2(0.56, 0.06), Vector2(0.4, 0.16), Vector2(0, 0.16),
	]), 16, cab + Vector3(0, 0.44, 0), GOLD_ROUND if level >= 5 else HULL_ROUND)
	Parts.mast(m, cab + Vector3(0.12, 0.6, -0.1), 0.3 + 0.03 * level, 0.06, GLOW)
	# The radar turning on the cab's roof, clear of the mast.
	var stub := cab + Vector3(-0.14, 0.6, 0.12)
	m.prism(0.05, 0.04, 0.12, 12, stub, Parts.GUNMETAL)
	var radar := p.moving(stub + Vector3(0, 0.12, 0), Motion.spin(Vector3.UP, 1.2))
	radar.box_chamfered(Vector3(0.08, 0.08, 0.08), 0.02, Vector3.ZERO, Parts.GUNMETAL)
	var tilt := Vector3(60, 90, 0)
	var hub := Vector3(0, 0.08, 0)
	Parts.dish(radar, 0.18, 0.07, hub, GOLD_ROUND if level >= 5 else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(radar, hub + axis * 0.03, hub + axis * 0.15, 0.015, Parts.ROD)
	radar.orb(0.03, 10, 4, hub + axis * 0.15, GLOW)
	if level >= 2:
		# Fuel tanks on the apron, beside the main door.
		for z: float in [1.68, 1.92]:
			Parts.tank(m, 0.1, 0.32, Vector3(-2.2, g, z), ORANGE_ROUND, 0.03)
	if level >= 4:
		_roof_dish(p, Vector3(-1.0, g + 1.98, -1.5), 0.5, level, true)
		_roof_dish(p, Vector3(1.35, g + 1.38, -0.4), 0.32, level, false)


## A dish on a stub at `foot`, turned to the right of the view, with a glowing feed. One that
## `sweeps` stands on a taller stub, clear of the roof, and swings to and fro about it.
static func _roof_dish(p: Parts, foot: Vector3, radius: float, level: int, sweeps: bool) -> void:
	var aim := Vector3(55, 135, 0)
	var stub := 0.42 if sweeps else 0.22
	p.body.prism(0.07, 0.06, stub, 16, foot, Parts.GUNMETAL)
	var m := p.body
	var centre := foot + Vector3(0, stub - 0.02, 0)
	if sweeps:
		m = p.moving(centre, Motion.swing(Vector3.UP, 30.0, 7.0))
		centre = Vector3.ZERO
	Parts.dish(m, radius, radius * 0.38, centre, GOLD_ROUND if level >= 5 else HULL_ROUND, aim)
	var axis := LowPolyMesh.turn(Vector3.UP, aim)
	var focus := centre + axis * radius * 0.85
	Parts.pipe(m, centre + axis * radius * 0.1, focus, 0.025, Parts.ROD)
	m.orb(0.05, 16, 6, focus, GLOW)


## One bay of the hangar: walls, a barrel roof with orange ribs, and the striped door on its
## +Z end. `back` is the middle of its back wall on the pad. A door that `opens` is a moving
## part: it rises behind its lintel and a hood over it, as far as the roof leaves room, and the
## lit bay shows under it.
static func _vault(p: Parts, back: Vector3, width: float, length: float, wall: float,
		door: float, level: int, opens: bool) -> void:
	var m := p.body
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
		var rib_z := back.z + length * (0.18 + 0.32 * k)
		m.ring(radius - 0.02, radius + 0.07, 0.14, 24, Vector3(back.x, axis.y, rib_z), ORANGE_ROUND,
			Vector3(90, 0, 0))
	# The door: leaves with a hazard band, hazard posts, a lintel and a glow strip.
	var post := door * 0.5 + 0.08
	var height := wall + sqrt(radius * radius - (post + 0.08) * (post + 0.08)) - 0.2
	var z := front + 0.02
	var leaves := m
	var at := Vector3(back.x, back.y, z)
	var strip := back.y + height + 0.22
	if opens:
		# The hood over the lintel reaches as high as the roof allows over the door's corners;
		# the door stands a little proud of the lit inside, and rises to the hood's top.
		var corner := door * 0.5 + 0.04
		var hood := back.y + wall + sqrt(radius * radius - corner * corner) - 0.03
		var rise := hood - back.y - height - 0.04
		m.box_chamfered(Vector3(door + 0.04, hood - back.y - height - 0.14, 0.16), 0.03,
			Vector3(back.x, back.y + height + 0.14, z + 0.08), ARMOUR)
		m.box(Vector3(door, rise + 0.06, 0.008), Vector3(back.x, back.y, z + 0.006), INTERIOR)
		strip = (back.y + height + 0.14 + hood) * 0.5 - 0.03
		leaves = p.moving(at + Vector3(0, rise * 0.5, 0), Motion.slide(Vector3.UP, rise * 0.5, 6.0))
		at = Vector3(0, 0, 0.015)
	var leaf := door / 4.0
	for i: int in 4:
		var x := -door * 0.5 + leaf * (i + 0.5)
		leaves.box_chamfered(Vector3(leaf - 0.03, height, 0.08), 0.02, at + Vector3(x, 0, 0.04), DARK_PLATE)
	leaves.box_chamfered(Vector3(door, 0.26, 0.1), 0.03, at + Vector3(0, 0, 0.05), Parts.HAZARD)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.16, height + 0.14, 0.16), 0.04, Vector3(back.x + side * post, back.y, z + 0.08),
			Parts.HAZARD)
	m.box_chamfered(Vector3(door + 0.32, 0.14, 0.18), 0.04, Vector3(back.x, back.y + height, z + 0.09),
		Parts.GOLD_TRIM if level >= 5 else ORANGE)
	m.box(Vector3(door * 0.6, 0.06, 0.04), Vector3(back.x, strip, z + (0.15 if opens else 0.0)), GLOW)


## A factory block under a sawtooth roof, smokestacks on a furnace box behind it, a conveyor
## out to a loading dock under an orange gantry crane. More stacks at 3 and 5, a second storey
## at 4. The roof windows pulse orange, the crane's trolley runs to and fro along its bridge
## with the hook, the dock's lamp blinks and the stacks puff smoke.
static func build_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	var roof := g + 0.8
	m.box_chamfered(Vector3(1.7, 0.8, 1.6), 0.06, Vector3(-0.45, g, -0.5), Parts.HULL_LIGHT)
	for k: int in 2:
		var z := -0.6 + 0.45 * k
		m.wedge(Vector3(1.6, 0.3, 0.45), Vector3(-0.45, roof, z + 0.225), MID_ROUND, Vector3(0, 180, 0))
		m.box(Vector3(1.45, 0.2, 0.03), Vector3(-0.45, roof + 0.04, z + 0.465), WINDOW_GLOW.phased(0.5 * k))
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
	Parts.landing_light(m, Vector3(1.2, g + 0.2, 1.07), 0.06, LAMP)
	# The gantry crane over the dock.
	var top := g + 1.25
	for x: float in [0.57, 1.23]:
		for z: float in [0.4, 1.2]:
			m.box_chamfered(Vector3(0.08, top - g - 0.2, 0.08), 0.02, Vector3(x, g + 0.2, z), ORANGE)
		Parts.beam(m, Vector3(x, top, 0.33), Vector3(x, top, 1.27), 0.1, ORANGE)
	var bridge := 0.85
	Parts.beam(m, Vector3(0.5, top + 0.1, bridge), Vector3(1.3, top + 0.1, bridge), 0.1,
		Parts.GOLD_TRIM if level >= 5 else Parts.HULL_DARK)
	# The trolley rides on the bridge, its hook hanging through it, from rail to rail.
	var trolley := p.moving(Vector3(0.9, top, bridge), Motion.slide(Vector3.RIGHT, 0.25, 5.0))
	trolley.box_chamfered(Vector3(0.2, 0.12, 0.18), 0.03, Vector3(0, 0.15, 0), Parts.GUNMETAL)
	trolley.prism(0.012, 0.012, 0.52, 8, Vector3(0, -0.37, 0), Parts.ROD)
	trolley.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Vector3(0, -0.43, 0), Parts.HAZARD)
	# Smokestacks on the furnace box.
	m.box_chamfered(Vector3(0.75, 0.35, 0.7), 0.05, Vector3(0.92, g, -0.92), DARK_PLATE)
	var stacks: Array[Vector3] = [
		Vector3(0.75, 0, -1.08), Vector3(1.1, 0, -0.78), Vector3(1.1, 0, -1.12), Vector3(0.72, 0, -0.72),
	]
	var counts: Array[int] = [2, 2, 3, 3, 4]
	for i: int in counts[level - 1]:
		var height := 1.2 - 0.18 * i + 0.05 * level
		var foot := stacks[i] + Vector3(0, g + 0.35, 0)
		_stack(m, foot, 0.13, height, level)
		Parts.puffs(m, foot + Vector3(0, height, 0), 0.29 * i)


## A smokestack standing on `foot`: a ribbed pipe with an orange band and a glowing mouth.
static func _stack(m: LowPolyMesh, foot: Vector3, radius: float, height: float, level: int) -> void:
	m.prism(radius, radius * 0.8, height, 16, foot, PIPE)
	m.ring(radius * 0.8, radius * 1.12, 0.07, 16, foot + Vector3(0, height * 0.55, 0), ORANGE_ROUND)
	var mouth := foot + Vector3(0, height, 0)
	m.ring(radius * 0.55, radius * 0.95, 0.06, 16, mouth, GOLD_ROUND if level >= 5 else Parts.GUNMETAL)
	m.disc(radius * 0.56, 16, mouth + Vector3(0, 0.03, 0), GLOW)


## The bulky fabricator: an armoured hall with a furnace in its front, an orange press arm
## hammering an anvil beside it. A second arm at 2, a chimney cluster at 3. The arms hammer
## in turn, sparks fly at the anvils, the furnace mouth pulses and the molten pour runs out of
## it.
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
	m.box(Vector3(0.6, 0.55, 0.02), mouth, GLOW_PULSE)
	m.box(Vector3(0.36, 0.32, 0.02), mouth + Vector3(0, 0, 0.01), HOT_PULSE.phased(0.5))
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.14, 0.62, 0.16), 0.04, mouth + Vector3(side * 0.37, 0, 0.02), DARK_PLATE)
	m.box_chamfered(Vector3(0.9, 0.16, 0.2), 0.04, mouth + Vector3(0, 0.6, 0.03),
		Parts.GOLD_TRIM if level >= 3 else DARK_PLATE)
	m.box_chamfered(Vector3(0.36, 0.06, 0.75), 0.02, mouth + Vector3(0, 0, 0.42), DARK_PLATE)
	m.box(Vector3(0.2, 0.02, 0.72), mouth + Vector3(0, 0.06, 0.42), POUR)
	m.box(Vector3(0.08, 0.02, 0.72), mouth + Vector3(0, 0.07, 0.42), HOT_POUR)
	# The press arms, striking in turn.
	_press_arm(p, Vector3(-0.15, g + 1.0, 0.1), Vector3(0.88, g, 0.85), level, 0.0)
	if level >= 2:
		_press_arm(p, Vector3(-0.15, g + 1.0, -0.95), Vector3(0.88, g, -0.85), level, 0.5)
	# Exhausts: one stack, a cluster of three at 3.
	_stack(m, Vector3(-0.95, g + 1.4, -0.95), 0.14, 0.55, level)
	if level >= 3:
		_stack(m, Vector3(-0.55, g + 1.4, -1.05), 0.12, 0.75, level)
		_stack(m, Vector3(-1.02, g + 1.4, -0.55), 0.1, 0.4, level)


## A press arm: a turret on the hall's roof at `shoulder`, a fat orange boom up to an elbow
## over an anvil standing at `anvil`, a hydraulic ram down from the elbow to a heavy head. The
## head and its piston are a moving part that hammers down onto the anvil, `phase` into its
## cycle, the piston sliding in the ram's cylinder; sparks flicker off the anvil's face.
static func _press_arm(p: Parts, shoulder: Vector3, anvil: Vector3, level: int, phase: float) -> void:
	var m := p.body
	m.prism(0.3, 0.27, 0.24, 16, shoulder, Parts.GUNMETAL)
	var pivot := shoulder + Vector3(0, 0.36, 0)
	var elbow := Vector3(anvil.x, shoulder.y + 1.0, anvil.z)
	m.prism(0.2, 0.2, 0.36, 16, pivot + Vector3(0, 0, -0.18), Parts.GUNMETAL, Vector3(90, 0, 0))
	Parts.beam(m, pivot, elbow, 0.28, ORANGE, 0.06)
	Parts.pipe(m, shoulder + Vector3(0.18, 0.24, 0), elbow + Vector3(-0.08, -0.22, 0), 0.06, MID_ROUND)
	m.prism(0.19, 0.19, 0.34, 16, elbow + Vector3(0, 0, -0.17), Parts.GUNMETAL, Vector3(90, 0, 0))
	Parts.pipe(m, elbow, anvil + Vector3(0, 1.28, 0), 0.12, Parts.GUNMETAL)
	# The head strikes the anvil's face (0.3 up) and lifts to 0.66, where it hung before it moved.
	var head := p.moving(anvil + Vector3(0, 0.48, 0),
		Motion.slide(Vector3.UP, 0.18, 2.4, phase, Motion.Ease.HAMMER))
	Parts.pipe(head, Vector3(0, 0.3, 0), Vector3(0, 1.1, 0), 0.07, MID_ROUND, 16, false)
	head.box_chamfered(Vector3(0.46, 0.32, 0.46), 0.07, Vector3.ZERO, ORANGE)
	head.box(Vector3(0.48, 0.07, 0.48), Vector3(0, 0.04, 0), Parts.GOLD_TRIM if level >= 3 else Parts.HAZARD)
	m.box_chamfered(Vector3(0.52, 0.3, 0.52), 0.05, anvil, Parts.GUNMETAL)
	m.box(Vector3(0.54, 0.06, 0.54), anvil + Vector3(0, 0.2, 0), Parts.HAZARD)
	for k: int in 6:
		var degrees := 15.0 + 60.0 * k
		var out := Parts.around(1.0, degrees, 0.5 + 0.2 * (k % 3))
		m.cone(0.035, 0.16, 8, anvil + Parts.around(0.3, degrees, 0.3),
			SPARK.phased(fposmod(phase + k / 6.0 + 0.04, 1.0)), Parts.facing(out))


## A lab ring with screens around a central observatory dome, its telescope out of the slit,
## and a radar dish spinning on a mast in the corner. Antennas at 2 and 4, a second ring at 3.
## The screens scroll, each at its own speed, the slit pulses, the telescope nods along it, and
## from 3 a hologram of the lab's subject, an orb in two rings, floats over the dome.
static func build_research_lab(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 3)
	m.ring(1.08, 1.13, 0.1, 24, Vector3(0, g, 0), ORANGE_ROUND)
	m.lathe(PackedVector2Array([
		Vector2(1.08, 0), Vector2(1.08, 0.42), Vector2(1.0, 0.5), Vector2(0.66, 0.5), Vector2(0.66, 0),
	]), 24, Vector3(0, g, 0), HULL_ROUND)
	_screen(m, 1.085, 5.0, g + 0.15, 0.36, 0.22, 0.6)
	_screen(m, 1.085, 45.0, g + 0.15, 0.36, 0.22, 0.7)
	m.box_chamfered(Vector3(0.28, 0.34, 0.08), 0.03, Parts.around(1.07, 92, g), DARK_PLATE, Vector3(0, -2, 0))
	m.box(Vector3(0.34, 0.05, 0.04), Parts.around(1.1, 92, g + 0.38), GLOW, Vector3(0, -2, 0))
	var drum := 0.75
	if level >= 3:
		m.lathe(PackedVector2Array([
			Vector2(0.95, 0), Vector2(0.95, 0.24), Vector2(0.88, 0.3), Vector2(0.66, 0.3), Vector2(0.66, 0),
		]), 24, Vector3(0, g + 0.5, 0), MID_ROUND)
		_screen(m, 0.955, 25.0, g + 0.56, 0.3, 0.16, 0.65)
		_screen(m, 0.955, 65.0, g + 0.56, 0.3, 0.16, 0.8)
		drum = 1.05
	# The observatory: a drum, a dome with a dark slit and the telescope out of it.
	m.prism(0.63, 0.63, drum, 24, Vector3(0, g, 0), MID_ROUND)
	var centre := Vector3(0, g + drum, 0)
	m.ring(0.62, 0.69, 0.05, 24, centre, GLOW)
	if level >= 5:
		m.ring(0.62, 0.68, 0.05, 24, centre - Vector3(0, 0.08, 0), GOLD_ROUND)
	m.dome(0.62, 0.62, 16, 7, centre, HULL_ROUND)
	var across := Vector3(0.7071, 0, 0.7071)
	m.ring(0.6, 0.65, 0.18, 24, centre - across * 0.09, GLOW_PULSE, Parts.facing(across))
	# The telescope nods along the slit, about its trunnion at the dome's centre.
	var telescope := p.moving(centre, Motion.swing(across, 10.0, 8.0))
	var aim := Vector3(0.42, 0.8, -0.42).normalized()
	Parts.pipe(telescope, aim * 0.3, aim * 0.95, 0.1, HULL_ROUND)
	telescope.ring(0.07, 0.13, 0.1, 16, aim * 0.85, ORANGE_ROUND, Parts.facing(aim))
	telescope.disc(0.085, 16, aim * 0.955, Parts.GLASS, Parts.facing(aim))
	if level >= 5:
		m.orb(0.07, 16, 6, centre + Vector3(0, 0.66, 0), GOLD_ROUND)
	if level >= 3:
		# The hologram over the dome: an orb in two tilted rings, floating.
		var subject := centre + Vector3(0, 1.0, 0)
		m.orb(0.13, 12, 4, subject, HOLOGRAM)
		for tilt: Vector3 in [Vector3(35, 0, 0), Vector3(0, 0, -35)]:
			m.lathe(PackedVector2Array([Vector2(0.26, 0), Vector2(0.26, 0.025), Vector2(0.22, 0.025)]), 16,
				subject, HOLOGRAM, tilt)
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
	var radar := p.moving(mast + Vector3(0, 0.14 + height, 0), Motion.spin(Vector3.UP, 0.9))
	radar.box_chamfered(Vector3(0.12, 0.16, 0.12), 0.03, Vector3.ZERO, Parts.GUNMETAL)
	var tilt := Vector3(60, 90, 0)
	var hub := Vector3(0, 0.14, 0)
	Parts.dish(radar, 0.38, 0.14, hub, GOLD_ROUND if level >= 5 else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(radar, hub + axis * 0.05, hub + axis * 0.32, 0.02, Parts.ROD)
	radar.orb(0.045, 16, 6, hub + axis * 0.32, GLOW)


## A flat screen on a round wall of `radius`, at `degrees` around it, its bottom at `y`, its
## rows scrolling at the FLOW speed `speed`.
static func _screen(m: LowPolyMesh, radius: float, degrees: float, y: float, width: float,
		height: float, speed: float) -> void:
	m.box_chamfered(Vector3(width, height, 0.04), 0.015, Parts.around(radius, degrees, y),
		SCREEN_FLOW.phased(speed), Vector3(0, 90 - degrees, 0))


## A sensor mast on a little foot: a thin rod with an orange bulb.
static func _antenna(m: LowPolyMesh, foot: Vector3, height: float) -> void:
	m.box_chamfered(Vector3(0.18, 0.1, 0.18), 0.03, foot, Parts.GUNMETAL)
	Parts.mast(m, foot + Vector3(0, 0.1, 0), height, 0.06, GLOW)


## Vats of glowing green nanite goo seen through glass bands, round a pump block, with pipes
## and their elbows running between them. A vat more at each level; gold rims at 4. The goo
## rises in every vat and bubbles, the pipes and the pump's screens flow, and a stirrer turns in
## the big vat's open top.
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
	]), 0.05, PIPE_FLOW, 12)
	# The stirrer: a hub with two crossed paddles turning in the big vat's goo.
	var stirrer := p.moving(vats[0][0] + Vector3(0, 1.3, 0), Motion.spin(Vector3.UP, 1.6))
	stirrer.prism(0.08, 0.06, 0.12, 12, Vector3(0, -0.02, 0), ORANGE_ROUND)
	for yaw: float in [0.0, 90.0]:
		stirrer.box_chamfered(Vector3(0.44, 0.08, 0.05), 0.02, Vector3(0, -0.04, 0), ORANGE, Vector3(0, yaw, 0))
	for i: int in mini(level + 1, vats.size()):
		var spot: Vector3 = vats[i][0]
		var radius: float = vats[i][1]
		var height: float = vats[i][2]
		_vat(m, spot, radius, height, level, i)
		if i < 3:
			# Out of the vat's upper shell, down to the pad and along it into the pump.
			var toward := Vector3(pump.x - spot.x, 0, pump.z - spot.z).normalized()
			var high := spot + toward * (radius + 0.16) + Vector3(0, height * 0.8, 0)
			var low := Vector3(high.x, g + 0.1, high.z)
			Parts.pipe_run(m, PackedVector3Array([
				spot + toward * (radius - 0.04) + Vector3(0, height * 0.8, 0), high, low,
				pump + Vector3(0, 0.1, 0) - toward * 0.2,
			]), 0.05, PIPE_FLOW, 12)
		else:
			# A short pipe across to the vat it stands next to.
			var next: Vector3 = vats[i - 2][0]
			var toward := Vector3(next.x - spot.x, 0, next.z - spot.z).normalized()
			var y := Vector3(0, height * 0.82, 0)
			Parts.pipe(m, spot + toward * (radius - 0.04) + y, next - toward * 0.2 + y, 0.05, PIPE_FLOW,
				12, false)


## A vat standing on `foot`, the `index`th of the foundry's: an armoured lower shell, a band of
## glowing goo rising behind glass framed by rims, with bubbles blinking on it, and an upper
## shell with a chamfered lid and an orange cap. The first vat is open at the top instead, over
## a swirl of goo for the stirrer to turn in. The rims are gold at the top level.
static func _vat(m: LowPolyMesh, foot: Vector3, radius: float, height: float, level: int, index: int) -> void:
	var band := height * 0.4
	var glass := height * 0.28
	var rim := radius + 0.035
	var gold := level >= 4
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, band - 0.05)]), 16, foot, ARMOUR_ROUND)
	# The rim's underside faces the ground, which the camera never sees, so it is left out.
	m.lathe(PackedVector2Array([
		Vector2(rim, band - 0.05), Vector2(rim, band), Vector2(radius - 0.03, band),
	]), 16, foot, GOLD_ROUND if gold else ARMOUR_ROUND)
	m.lathe(PackedVector2Array([Vector2(radius - 0.03, 0), Vector2(radius - 0.03, glass)]), 16,
		foot + Vector3(0, band, 0), GOO_FLOW.phased(0.27 + 0.02 * index))
	for k: int in 2:
		m.orb(0.045, 8, 2, foot + Parts.around(radius - 0.03, 25.0 + 40.0 * k + 7.0 * index,
			band + glass * (0.3 + 0.4 * k)), BUBBLE.phased(fposmod(0.37 * index + 0.5 * k, 1.0)))
	var upper := band + glass
	var top := height - upper
	m.lathe(PackedVector2Array([Vector2(rim, 0), Vector2(rim, 0.05), Vector2(radius, 0.05)]), 16,
		foot + Vector3(0, upper, 0), GOLD_ROUND if gold else HULL_ROUND)
	if index == 0:
		m.lathe(PackedVector2Array([
			Vector2(radius, 0.05), Vector2(radius, top - 0.08), Vector2(radius - 0.08, top),
			Vector2(radius - 0.13, top), Vector2(radius - 0.13, top - 0.05),
		]), 16, foot + Vector3(0, upper, 0), HULL_ROUND)
		m.disc(radius - 0.13, 16, foot + Vector3(0, height - 0.05, 0), GOO_SWIRL)
		return
	m.lathe(PackedVector2Array([
		Vector2(radius, 0.05), Vector2(radius, top - 0.08), Vector2(radius - 0.08, top), Vector2(0, top),
	]), 16, foot + Vector3(0, upper, 0), HULL_ROUND)
	m.prism(radius * 0.42, radius * 0.34, 0.1, 16, foot + Vector3(0, height, 0), ORANGE_ROUND)


## A drydock: an orange gantry crane over a cradle holding a half-built ship, its nose plated,
## its stern still bare ribs, welders glowing where the gantries reach down. A bigger, more
## plated hull and a third gantry at 2. The bare stern is completed in a hologram of the hull
## to come, the first gantry rides its rails along the dock, the welds flash and throw sparks,
## and the reactor pulses (the engines too, at 2).
static func build_drydock(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	Parts.foundation(m, 4)
	# The cradle: rails along the dock and hazard chocks under the hull.
	for z: float in [-0.45, 0.45]:
		m.box_chamfered(Vector3(3.5, 0.08, 0.16), 0.03, Vector3(0, g, z), Parts.GUNMETAL)
	for x: float in [-1.15, -0.35, 0.45, 1.2]:
		m.box_chamfered(Vector3(0.24, 0.36, 0.86), 0.04, Vector3(x, g, 0), Parts.HAZARD)
	# The hull lies along X, nose to +X. [distance from the stern, radius] down its profile.
	var scale := 1.0 if level < 2 else 1.08
	var stern := -1.65
	var axis_y := g + 0.36 + 0.55 * scale
	var profile := PackedVector2Array([
		Vector2(0.38, 0), Vector2(0.52, 0.35), Vector2(0.56, 1.0), Vector2(0.54, 1.7),
		Vector2(0.44, 2.45), Vector2(0.24, 3.05), Vector2(0, 3.3),
	])
	var plated_from := 1.7 if level < 2 else 1.0
	var plated := PackedVector2Array()
	for point: Vector2 in profile:
		if point.y >= plated_from:
			plated.append(Vector2(point.x * scale, point.y - plated_from))
	# Round parts lie along +X: their axis, +Y, turned onto +X.
	var lie := Vector3(0, 0, -90)
	m.lathe(plated, 24, Vector3(stern + plated_from, axis_y, 0), HULL_ROUND, lie)
	m.ring(0.46 * scale, 0.56 * scale, 0.12, 24, Vector3(stern + 2.3, axis_y, 0), ORANGE_ROUND, lie)
	var canopy := Vector3(stern + 2.55, axis_y + 0.36 * scale, 0)
	m.dome(0.2, 0.14, 16, 4, canopy, Parts.GLASS, Vector3(0, 0, -20))
	# The hull to come, aft of the plating, a hologram round the ribs.
	var plan := PackedVector2Array([Vector2(0, 0)])
	for point: Vector2 in profile:
		if point.y <= plated_from:
			plan.append(Vector2(point.x * scale + 0.01, point.y))
	m.lathe(plan, 24, Vector3(stern, axis_y, 0), HOLO_HULL, lie)
	# Bare ribs aft of the plating, with a keel, a spine and stringers through them.
	var x := stern + 0.12
	while x < stern + plated_from - 0.05:
		var radius := _hull_radius(profile, x - stern) * scale
		m.ring(radius - 0.07, radius, 0.08, 24, Vector3(x, axis_y, 0), ARMOUR_ROUND, lie)
		x += 0.34
	var aft := Vector3(stern + 0.05, axis_y, 0)
	var fore := Vector3(stern + plated_from + 0.05, axis_y, 0)
	for offset: Vector3 in [Vector3(0, -0.5, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
		Parts.beam(m, aft + offset * scale, fore + offset * scale, 0.06, Parts.GUNMETAL, 0.015)
	# The reactor glowing inside the bare ribs; engine bells on the stern at 2.
	m.orb(0.2, 16, 6, Vector3(stern + 0.75, axis_y, 0), GLOW_PULSE)
	if level >= 2:
		for z: float in [-0.2, 0.2]:
			m.prism(0.1, 0.17, 0.22, 16, Vector3(stern + 0.1, axis_y - 0.1, z), Parts.GUNMETAL, -lie)
			m.disc(0.14, 16, Vector3(stern - 0.125, axis_y - 0.1, z), GLOW_PULSE.phased(0.25), -lie)
	# The gantries, each with a welder reaching down to the hull. The first rides rails along
	# the dock, where the hull's radius hardly changes, so its welder stays on the hull.
	var top := g + 1.95
	for z: float in [-1.6, 1.6]:
		m.box_chamfered(Vector3(0.84, 0.03, 0.12), 0.01, Vector3(-0.75, g, z), Parts.GUNMETAL)
	var gantries: Array[float] = [-0.75, 0.55]
	if level >= 2:
		gantries.append(1.45)
	for k: int in gantries.size():
		var gx := gantries[k]
		var crane := m
		var at := Vector3(gx, 0, 0)
		if k == 0:
			crane = p.moving(at, Motion.slide(Vector3.RIGHT, 0.3, 7.0))
			at = Vector3.ZERO
		for z: float in [-1.6, 1.6]:
			crane.box_chamfered(Vector3(0.24, 0.12, 0.24), 0.03, at + Vector3(0, g, z), DARK_PLATE)
			crane.box_chamfered(Vector3(0.14, top - g - 0.12, 0.14), 0.03, at + Vector3(0, g + 0.12, z), ORANGE)
		Parts.beam(crane, at + Vector3(0, top, -1.7), at + Vector3(0, top, 1.7), 0.18,
			Parts.GOLD_TRIM if level >= 2 else ORANGE, 0.04)
		var trolley := at + Vector3(0, top - 0.16, 0.25)
		crane.box_chamfered(Vector3(0.22, 0.14, 0.26), 0.03, trolley, Parts.GUNMETAL)
		var surface := axis_y + _hull_radius(profile, gx - stern) * scale
		var tip := at + Vector3(0, surface + 0.16, 0.25)
		Parts.pipe(crane, trolley, tip, 0.03, Parts.ROD)
		_weld(crane, at + Vector3(0, surface + 0.04, 0.25), float(k) / gantries.size())
	# The control booth in the front corner.
	var booth := Vector3(-1.45, g, 1.4)
	m.box_chamfered(Vector3(0.5, 0.45, 0.4), 0.05, booth, Parts.HULL_LIGHT)
	m.box_chamfered(Vector3(0.4, 0.16, 0.03), 0.01, booth + Vector3(0, 0.24, 0.2), Parts.GLASS)
	Parts.mast(m, booth + Vector3(0.12, 0.45, -0.08), 0.35, 0.05, GLOW)


## A welding point on the hull: a glowing arc flashing, `phase` into its blink, with hot sparks
## flickering and shaking off it.
static func _weld(m: LowPolyMesh, spot: Vector3, phase: float) -> void:
	m.orb(0.08, 16, 6, spot, WELD_BLINK.phased(phase))
	var sparks: Array[Vector3] = [
		Vector3(1, 0.7, 0.3), Vector3(-0.4, 0.8, 0.9), Vector3(0.2, 0.6, -1), Vector3(-1, 0.5, -0.2),
		Vector3(0.6, 0.9, -0.5), Vector3(-0.3, 0.7, -0.8),
	]
	for i: int in sparks.size():
		var spark := sparks[i]
		m.cone(0.025, 0.18, 8, spot + spark.normalized() * 0.06,
			SPARK_ARC.phased(fposmod(phase + i / 6.0 + 0.05, 1.0)), Parts.facing(spark))


## The radius of the hull's `profile` at `along` from the stern, between its points.
static func _hull_radius(profile: PackedVector2Array, along: float) -> float:
	for i: int in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if along <= b.y:
			return lerpf(a.x, b.x, clampf((along - a.y) / (b.y - a.y), 0.0, 1.0))
	return 0.0


## A transmitter tower: four legs tapering to an emitter orb, braced, ringed with lights, a
## big dish on its flank. Taller with a ring of lights more at each level. The rings blink in a
## chase up the tower, the dish circles it slowly on a collar, and the orb pulses and floats
## under a hologram halo.
static func build_alliance_beacon(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var gold := level >= 3
	Parts.foundation(m, 3)
	m.box_chamfered(Vector3(1.9, 0.22, 1.9), 0.06, Vector3(0, g, 0), ARMOUR)
	var foot := g + 0.22
	m.box_chamfered(Vector3(1.3, 0.14, 1.3), 0.05, Vector3(0, foot, 0), Parts.HULL_DARK)
	foot += 0.14
	var height := 1.0 + 0.21 * level
	var top := foot + height
	var base := 0.5
	var crown := 0.13
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for c: Vector2 in corners:
		Parts.beam(m, Vector3(c.x * base, foot, c.y * base), Vector3(c.x * crown, top, c.y * crown), 0.12,
			Parts.HULL_LIGHT)
	# Cross braces between the rings.
	var stops := PackedFloat32Array([0.0])
	for i: int in level:
		stops.append(float(i + 1) / (level + 1))
	stops.append(1.0)
	for k: int in stops.size() - 1:
		var lower := stops[k]
		var upper := stops[k + 1]
		for i: int in 4:
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			var wl := lerpf(base, crown, lower)
			var wu := lerpf(base, crown, upper)
			m.strut(Vector3(a.x * wl, foot + height * lower, a.y * wl),
				Vector3(b.x * wu, foot + height * upper, b.y * wu), 0.04, Parts.ROD)
	# The rings of lights, blinking in turn from the bottom up.
	var rings := stops.size() - 2
	for k: int in range(1, stops.size() - 1):
		var y := foot + height * stops[k]
		var radius := lerpf(base, crown, stops[k]) * 1.42 + 0.1
		m.ring(radius - 0.12, radius, 0.08, 24, Vector3(0, y - 0.04, 0), ARMOUR_ROUND)
		m.ring(radius, radius + 0.035, 0.05, 24, Vector3(0, y - 0.025, 0),
			LAMP.phased(fposmod(-float(k - 1) / rings, 1.0)))
	# The big dish facing out from the tower on a collar that turns about it, between the rings
	# of lights at every level, so the dish circles the tower slowly.
	var mount := foot + height * 0.4
	var collar := lerpf(base, crown, 0.4) * 1.42 + 0.1
	var dish := p.moving(Vector3(0, mount, 0), Motion.spin(Vector3.UP, 0.35))
	dish.ring(collar - 0.12, collar, 0.08, 24, Vector3(0, -0.04, 0), ARMOUR_ROUND)
	Parts.beam(dish, Vector3(collar - 0.02, 0, 0), Vector3(collar + 0.2, 0, 0), 0.1, Parts.GUNMETAL)
	var tilt := Vector3(55, 90, 0)
	var dish_centre := Vector3(collar + 0.2, 0, 0)
	Parts.dish(dish, 0.62, 0.24, dish_centre, GOLD_ROUND if gold else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(dish, dish_centre + axis * 0.1, dish_centre + axis * 0.55, 0.025, Parts.ROD)
	dish.orb(0.06, 16, 6, dish_centre + axis * 0.55, GLOW)
	# The emitter at the top: a collar, the orb and its spike floating over it, and a hologram
	# halo floating over them out of step.
	m.prism(0.2, 0.16, 0.12, 16, Vector3(0, top, 0), GOLD_ROUND if gold else Parts.GUNMETAL)
	m.ring(0.2, 0.3, 0.06, 24, Vector3(0, top + 0.12, 0), ORANGE_ROUND)
	# The orb rests a bob's height over the collar, so it never sinks into it.
	var orb := 0.17 + 0.02 * level
	var lift := top + 0.12 + 0.08
	m.orb(orb, 16, 8, Vector3(0, lift + orb, 0), ORB_BOB)
	m.cone(0.05, 0.22, 16, Vector3(0, lift - 0.02 + orb * 2, 0), GOLD_BOB if gold else GUNMETAL_BOB)
	m.ring(0.2, 0.26, 0.03, 24, Vector3(0, lift + 0.12 + orb * 2, 0), HOLOGRAM.phased(0.5))
