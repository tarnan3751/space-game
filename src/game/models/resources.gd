extends RefCounted
## Models of the resource buildings: the drone bay, the collectors and the storage, each on
## the concrete foundation pad. Each carries its resource's colour (metal, crystal,
## antimatter) as its accent and its glow; the drone bay's is energy cyan, the HUD's drones.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


## The drone bay's glow is energy cyan, the HUD's colour for drones.
static var BAY_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var BAY_WINDOWS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ENERGY, 2.0, Surf.GLOSSY)
static var DECK_PLATE := Surf.make(MaterialKit.Layer.GRATING, MaterialKit.HULL_MID, 2.0)
static var CRATE := Surf.make(MaterialKit.Layer.HULL_DENSE, MaterialKit.HULL_MID, 2.0)
static var HAZARD_RING := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 1.0, Surf.LIT, true)

## The drone bay's landing deck: its middle and the height of its top.
const BAY_DECK := Vector3(0.2, 0.0, 0.2)
const BAY_DECK_TOP := 0.26


## An open landing deck with a hazard ring and landing lights, a drone parked in its docking
## cradle, a raised control booth on the far corner with a rotating beacon on its roof, a fuel
## tank and a stack of crates. One level, so it is complete at once, gold on the booth's roof.
static func build_drone_bay(p: Parts, _level: int) -> void:
	var m := p.body
	Parts.foundation(m, 2)
	m.lathe(PackedVector2Array([
		Vector2(0.66, 0), Vector2(0.66, 0.1), Vector2(0.62, BAY_DECK_TOP - Parts.PAD_HEIGHT),
		Vector2(0, BAY_DECK_TOP - Parts.PAD_HEIGHT),
	]), 20, BAY_DECK + Vector3(0, Parts.PAD_HEIGHT, 0), Parts.HULL_MID_ROUND)
	var top := BAY_DECK + Vector3(0, BAY_DECK_TOP, 0)
	m.disc(0.5, 20, top + Vector3(0, 0.005, 0), DECK_PLATE)
	m.lathe(PackedVector2Array([Vector2(0.56, 0), Vector2(0.56, 0.02), Vector2(0.44, 0.02)]), 20, top, HAZARD_RING)
	for k: int in 6:
		Parts.landing_light(m, top + Parts.around(0.6, 30 + 60 * k, 0), 0.09, BAY_GLOW)
	# The docking cradle: two rails under the drone and a clamp at each end.
	for side: float in [-1.0, 1.0]:
		var rail := top + LowPolyMesh.turn(Vector3(side * 0.13, 0, 0), Vector3(0, 45, 0))
		m.box_chamfered(Vector3(0.07, 0.06, 0.5), 0.02, rail, Parts.GUNMETAL, Vector3(0, 45, 0))
		var clamp := top + LowPolyMesh.turn(Vector3(0, 0, side * 0.27), Vector3(0, 45, 0))
		m.box_chamfered(Vector3(0.16, 0.16, 0.06), 0.02, clamp, Parts.HAZARD, Vector3(0, 45, 0))
	_drone(m, top + Vector3(0, 0.06, 0))

	# The control booth on the far corner: a column, a glazed cab, a gold-rimmed roof (its one
	# level is its top level) and a ladder.
	var booth := Vector3(-0.5, Parts.PAD_HEIGHT, -0.5)
	m.box_chamfered(Vector3(0.44, 0.7, 0.44), 0.05, booth, Parts.HULL_LIGHT)
	var cab := booth + Vector3(0, 0.7, 0)
	m.box_chamfered(Vector3(0.62, 0.34, 0.62), 0.06, cab, Parts.HULL_LIGHT)
	m.box(Vector3(0.64, 0.14, 0.64), cab + Vector3(0, 0.12, 0), BAY_WINDOWS)
	m.box_chamfered(Vector3(0.68, 0.06, 0.68), 0.03, cab + Vector3(0, 0.34, 0), Parts.GOLD_TRIM)
	Parts.ladder(m, booth + Vector3(0.24, 0, 0.05), 0.7, 0.2, 90.0, Parts.ROD)
	p.pivot = cab + Vector3(0, 0.4, 0)
	p.speed = 2.4
	_beacon(p.spin)

	# A fuel tank on the left corner, crates on the right.
	var tank := Vector3(-0.58, Parts.PAD_HEIGHT, 0.5)
	for end: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.24, 0.1, 0.08), 0.02, tank + Vector3(0, 0, end * 0.14), Parts.HULL_DARK)
	m.tube(0, 0.13, 0.5, 12, tank + Vector3(0, 0.2, -0.25), Parts.HULL_LIGHT_ROUND, Vector3(90, 0, 0))
	m.box_chamfered(Vector3(0.3, 0.26, 0.3), 0.04, Vector3(0.55, Parts.PAD_HEIGHT, -0.55), CRATE, Vector3(0, 20, 0))
	m.box_chamfered(Vector3(0.22, 0.2, 0.22), 0.04, Vector3(0.6, Parts.PAD_HEIGHT + 0.26, -0.52), CRATE, Vector3(0, -10, 0))


## A collector drone parked on the deck: a saucer body with a glowing eye and a glass canopy,
## and four ducted rotors on short arms (a duct and the blur of its rotor).
static func _drone(m: LowPolyMesh, pos: Vector3) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0.1, 0), Vector2(0.2, 0.05), Vector2(0.21, 0.09), Vector2(0.15, 0.14), Vector2(0, 0.15),
	]), 12, pos, Parts.HULL_LIGHT_ROUND)
	m.dome(0.09, 0.08, 10, 3, pos + Vector3(0, 0.13, 0), Parts.GLASS)
	m.box_chamfered(Vector3(0.12, 0.05, 0.05), 0.015, pos + LowPolyMesh.turn(Vector3(0, 0.05, 0.19), Vector3(0, 45, 0)),
		BAY_GLOW, Vector3(0, 45, 0))
	for k: int in 4:
		var degrees := 90.0 * k
		var hub := pos + Parts.around(0.3, degrees, 0.06)
		m.strut(pos + Parts.around(0.15, degrees, 0.07), hub, 0.05, Parts.ROD)
		m.lathe(PackedVector2Array([Vector2(0.115, 0), Vector2(0.115, 0.06), Vector2(0.08, 0.06)]), 10,
			hub - Vector3(0, 0.02, 0), Parts.HULL_MID_ROUND)
		m.disc(0.08, 10, hub + Vector3(0, 0.02, 0), Parts.GUNMETAL)


## The booth's rotating beacon: a dark housing with two glowing lenses back to back under a cap.
static func _beacon(s: LowPolyMesh) -> void:
	s.prism(0.1, 0.09, 0.05, 12, Vector3.ZERO, Parts.HULL_DARK_ROUND)
	s.prism(0.06, 0.06, 0.14, 12, Vector3(0, 0.05, 0), BAY_GLOW)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(0.09, 0.12, 0.06), Vector3(side * 0.07, 0.06, 0), BAY_GLOW, Vector3(0, 90, 0))
	s.prism(0.11, 0.08, 0.05, 12, Vector3(0, 0.19, 0), Parts.HULL_DARK_ROUND)


## Each resource building's accent (a lit plate) and its emissive, in its resource's colour.
static var METAL_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL)
static var METAL_ACCENT_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL, 1.0, Surf.LIT, true)
static var METAL_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.METAL, 1.0, Surf.UNLIT, true)
static var METAL_ORE := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.METAL, 2.0)
static var CRYSTAL_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.CRYSTAL)
## The emitter's prongs: too thin for the outline.
static var CRYSTAL_PRONG := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.CRYSTAL, 1.0, Surf.LIT, false, false)
static var CRYSTAL_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT, true)
static var CRYSTAL_SHARD := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.5, Surf.GLOSSY)
## A laser beam: too thin for the outline.
static var CRYSTAL_BEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT, true, false)
static var LEG := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var BELT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.GUNMETAL, 3.0)
static var STACK := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var SOOT := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.INK)
static var ENGINE_VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 2.0)
static var ROCK := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK_LIT)
static var DRILL_BIT := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_LIGHT, 3.0, Surf.LIT, true)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var PYLON_ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)

## The metal extractor's drill axis, its derrick's legs (degrees around the axis, meeting
## LEG_TOP from the axis under the crown), the derrick's height by level, and the share of the
## legs' height the drill's top drive reaches (low enough that its sweep clears the legs).
const DRILL := Vector3(-0.3, 0, -0.3)
const DERRICK_LEGS := [80.0, 200.0, 320.0]
const DERRICK_HEIGHTS := [1.65, 1.75, 1.95, 2.05, 2.15]
const LEG_TOP := 0.22
const DRIVE_TOP := 0.75
const BRACE := 0.42
## Its hoppers (the second from L4, each fed by a conveyor from the collar), the height of a
## hopper's rim, and the exhaust stacks on its engine house by level:
## [x, z, height above the roof].
const HOPPERS := [Vector3(-0.82, 0, 0.8), Vector3(0.55, 0, 0.95)]
const HOPPER_RIM := 0.72
const ENGINE_HOUSE := Vector3(0.8, 0, 0.05)
const STACKS := [[0.95, -0.15, 0.7], [0.98, 0.25, 0.85], [0.62, -0.2, 0.55]]


## A drill rig: a tripod derrick over a spinning drill head, a conveyor carrying ore up into
## a hopper with a metal accent strip and glowing ore, and an engine house with exhaust
## stacks. L2 adds a stack and armour, L3 a bigger derrick with braces and a winch, L4 a
## second hopper and a third stack, L5 gold trim.
static func build_metal_extractor(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 5
	var height: float = DERRICK_HEIGHTS[level - 1]
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.lathe(PackedVector2Array([
		Vector2(0.48, 0), Vector2(0.48, 0.12), Vector2(0.42, 0.18), Vector2(0.3, 0.18),
		Vector2(0.3, 0.1), Vector2(0, 0.1),
	]), 24, DRILL + Vector3(0, ground, 0), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND)

	# The derrick: three legs on foot plates leaning in to a crown block.
	var leg_width := 0.1 if level < 3 else 0.14
	var crown := DRILL + Vector3(0, height - 0.04, 0)
	var feet: Array[Vector3] = []
	var tops: Array[Vector3] = []
	for degrees: float in DERRICK_LEGS:
		var foot := DRILL + Parts.around(0.95, degrees, ground)
		var top := DRILL + Parts.around(LEG_TOP, degrees, height)
		feet.append(foot)
		tops.append(top)
		m.box_chamfered(Vector3(0.24, 0.06, 0.24), 0.02, foot, Parts.HULL_DARK, Vector3(0, 90.0 - degrees, 0))
		m.strut(foot, top, leg_width, LEG)
	if level >= 3:
		# Braces from leg to leg, BRACE of the way up.
		for k: int in 3:
			var a := feet[k].lerp(tops[k], BRACE)
			var b := feet[(k + 1) % 3].lerp(tops[(k + 1) % 3], BRACE)
			m.strut(a, b, 0.08, LEG)
	m.box_chamfered(Vector3(0.6, 0.26, 0.6), 0.05, crown, Parts.HULL_LIGHT)
	m.box(Vector3(0.62, 0.07, 0.62), crown + Vector3(0, 0.07, 0), METAL_ACCENT)
	if gold:
		m.box_chamfered(Vector3(0.64, 0.06, 0.64), 0.02, crown + Vector3(0, 0.26, 0), Parts.GOLD_TRIM)
	if level >= 3:
		m.tube(0, 0.08, 0.36, 16, crown + Vector3(0.18, 0.36, -0.06), Parts.GUNMETAL, Vector3(0, 0, 90))
	Parts.landing_light(m, crown + Vector3(0.14, 0.26, 0.14), 0.09, METAL_GLOW)

	# The hoppers, each with a conveyor from the collar up over its rim.
	for k: int in 2 if level >= 4 else 1:
		var hopper: Vector3 = HOPPERS[k]
		var heading := (hopper - DRILL).normalized()
		_hopper(m, hopper + Vector3(0, ground, 0), gold)
		_belt(m, DRILL + heading * 0.32 + Vector3(0, ground + 0.2, 0),
			hopper - heading * 0.2 + Vector3(0, ground + HOPPER_RIM + 0.14, 0))

	# The engine house and its stacks.
	var house := ENGINE_HOUSE + Vector3(0, ground, 0)
	m.box_chamfered(Vector3(0.66, 0.5, 0.8), 0.06, house, Parts.HULL_LIGHT)
	m.box(Vector3(0.4, 0.24, 0.04), house + Vector3(0, 0.12, 0.4), ENGINE_VENT)
	m.box_chamfered(Vector3(0.7, 0.08, 0.84), 0.03, house + Vector3(0, 0.5, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID)
	if level >= 2:
		m.box_chamfered(Vector3(0.72, 0.18, 0.86), 0.04, house, ARMOUR)
	var stacks := 1 + (1 if level >= 2 else 0) + (1 if level >= 4 else 0)
	for k: int in stacks:
		var stack: Array = STACKS[k]
		var stack_height: float = stack[2]
		_stack(m, Vector3(stack[0], house.y + 0.58, stack[1]), stack_height, gold)

	p.pivot = DRILL + Vector3(0, ground + 0.1, 0)
	p.speed = 3.0
	_drill(p.spin, crown.y - p.pivot.y, ground + DRIVE_TOP * (height - ground) - p.pivot.y, gold)


## A square hopper on four legs, a metal accent strip round its rim and glowing ore heaped in it.
static func _hopper(m: LowPolyMesh, pos: Vector3, gold: bool) -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.box_chamfered(Vector3(0.07, 0.32, 0.07), 0.02, pos + Vector3(corner.x * 0.17, 0, corner.y * 0.17), Parts.GUNMETAL)
	var bin := pos + Vector3(0, HOPPER_RIM - 0.46, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.12, 0), Vector2(0.42, 0.34), Vector2(0.42, 0.46), Vector2(0.36, 0.46),
		Vector2(0.36, 0.38), Vector2(0, 0.38),
	]), 4, bin, Parts.HULL_MID, Vector3(0, 45, 0))
	m.lathe(PackedVector2Array([Vector2(0.43, 0), Vector2(0.43, 0.08), Vector2(0.36, 0.08)]), 4,
		bin + Vector3(0, 0.36, 0), Parts.GOLD_TRIM if gold else METAL_ACCENT, Vector3(0, 45, 0))
	m.pyramid(0.48, 0.14, bin + Vector3(0, 0.38, 0), METAL_ORE)


## A conveyor from `from` up to `to`: a belt between two rails, glowing ore on it, a trestle
## under its middle.
static func _belt(m: LowPolyMesh, from: Vector3, to: Vector3) -> void:
	var along := to - from
	var run := Vector2(along.x, along.z)
	var rot := Vector3(-rad_to_deg(atan2(along.y, run.length())), rad_to_deg(atan2(along.x, along.z)), 0)
	var length := along.length()
	var middle := (from + to) * 0.5
	m.box_chamfered(Vector3(0.26, 0.05, length), 0.015, middle, BELT, rot)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.06, 0.1, length), 0.02, middle + LowPolyMesh.turn(Vector3(side * 0.15, -0.02, 0), rot), Parts.HULL_MID, rot)
	for t: float in [0.25, 0.55, 0.85]:
		m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, from.lerp(to, t) + LowPolyMesh.turn(Vector3(0, 0.05, 0), rot),
			METAL_GLOW, rot + Vector3(0, 30 * t, 0))
	var foot := Vector3(middle.x, Parts.PAD_HEIGHT, middle.z)
	m.box(Vector3(0.08, middle.y - foot.y, 0.08), foot, Parts.GUNMETAL)


## An exhaust stack: a collar, a ribbed pipe, a lipped mouth with soot inside.
static func _stack(m: LowPolyMesh, pos: Vector3, height: float, gold: bool) -> void:
	m.prism(0.14, 0.13, 0.08, 16, pos - Vector3(0, 0.04, 0), Parts.HULL_DARK_ROUND)
	m.prism(0.09, 0.09, height, 16, pos, STACK)
	m.ring(0.07, 0.12, 0.08, 16, pos + Vector3(0, height, 0), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND)
	m.disc(0.07, 16, pos + Vector3(0, height + 0.04, 0), SOOT)


## The drill string that spins round the collar: a ribbed bit, auger flights, a square kelly
## `length` tall up into the crown, and a finned round top drive whose top is at `drive_top`.
static func _drill(s: LowPolyMesh, length: float, drive_top: float, gold: bool) -> void:
	s.lathe(PackedVector2Array([
		Vector2(0.04, -0.04), Vector2(0.18, 0.08), Vector2(0.27, 0.16), Vector2(0.27, 0.24),
		Vector2(0.16, 0.3), Vector2(0, 0.3),
	]), 16, Vector3.ZERO, DRILL_BIT)
	for k: int in 3:
		s.box_chamfered(Vector3(0.44, 0.05, 0.16), 0.02, Vector3(0, 0.36 + 0.14 * k, 0),
			Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT, Vector3(10, 60 * k, 0))
	s.box_chamfered(Vector3(0.12, length - 0.2, 0.12), 0.03, Vector3(0, 0.2, 0), Parts.GUNMETAL)
	var drive := Vector3(0, drive_top - 0.28, 0)
	s.lathe(PackedVector2Array([
		Vector2(0.15, 0), Vector2(0.15, 0.24), Vector2(0.12, 0.28), Vector2(0, 0.28),
	]), 16, drive, Parts.HULL_MID_ROUND)
	s.lathe(PackedVector2Array([Vector2(0.16, 0), Vector2(0.16, 0.07)]), 16, drive + Vector3(0, 0.15, 0), METAL_ACCENT_ROUND)
	for k: int in 4:
		s.box_chamfered(Vector3(0.06, 0.2, 0.08), 0.02, drive + Parts.around(0.17, 90 * k + 45, 0.02), Parts.HULL_DARK,
			Vector3(0, 45 - 90 * k, 0))


## [x, z, height, radius, tilt x, tilt z] of each crystal shard, in the order levels add them:
## two per level from three at L1, taller the later they come.
const SHARDS := [
	[0.0, 0.0, 1.05, 0.2, 0, 0],
	[-0.3, 0.22, 0.75, 0.15, 10, -16],
	[0.28, -0.2, 0.7, 0.14, -14, 14],
	[0.3, 0.32, 0.6, 0.13, 18, 16],
	[-0.38, -0.28, 0.72, 0.14, -16, -14],
	[0.05, 0.45, 0.62, 0.12, 24, 4],
	[0.48, 0.05, 0.66, 0.12, 2, 24],
	[-0.5, 0.02, 0.6, 0.12, 0, -22],
	[-0.02, -0.5, 0.64, 0.12, -24, 0],
	[0.42, 0.42, 0.5, 0.1, 20, 20],
	[-0.42, 0.42, 0.52, 0.1, 20, -20],
]
## The gantry's two legs, either side of the cluster across the camera's view, and the
## height of its beam by level.
const GANTRY_LEGS := [Vector3(-0.98, 0, 0.98), Vector3(0.98, 0, -0.98)]
const GANTRY_HEIGHTS := [1.9, 1.95, 2.0, 2.05, 2.1]


## A laser cutting gantry over a cluster of crystal shards on a rock bed, its focusing emitter
## turning under the beam and firing a glowing beam into the tallest shard. Every level adds
## two shards and the shards grow; L3 adds a containment ring round the cluster, L4 glowing
## pylons on it, L5 gold trim.
static func build_crystal_harvester(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 5
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.dome(0.8, 0.22, 8, 2, Vector3(0, ground, 0), ROCK)
	var growth := 1.0 + 0.05 * (level - 1)
	for i: int in 1 + 2 * level:
		var shard: Array = SHARDS[i]
		var foot := Vector3(shard[0], ground + 0.12, shard[1])
		var shard_height: float = shard[2]
		var radius: float = shard[3]
		_shard(m, foot, shard_height * growth, radius, Vector3(shard[4], 15 * i, shard[5]))
	if level >= 3:
		m.ring(0.86, 0.98, 0.16, 24, Vector3(0, ground, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)
		m.ring(0.88, 0.96, 0.03, 24, Vector3(0, ground + 0.16, 0), CRYSTAL_GLOW)
	if level >= 4:
		for k: int in 4:
			var post := Parts.around(0.92, 90 * k, ground)
			m.box_chamfered(Vector3(0.14, 0.42, 0.14), 0.03, post, Parts.HULL_LIGHT, Vector3(0, -90 * k, 0))
			m.orb(0.07, 12, 6, post + Vector3(0, 0.5, 0), CRYSTAL_GLOW)

	# The gantry: two legs on feet, a beam across with a crystal accent stripe, a carriage.
	var beam_y: float = GANTRY_HEIGHTS[level - 1]
	var yaw := Vector3(0, 45, 0)
	for leg: Vector3 in GANTRY_LEGS:
		var foot := leg + Vector3(0, ground, 0)
		m.box_chamfered(Vector3(0.42, 0.14, 0.42), 0.04, foot, Parts.HULL_DARK, yaw)
		m.box_chamfered(Vector3(0.24, beam_y - ground, 0.24), 0.05, foot, Parts.HULL_LIGHT, yaw)
		m.box(Vector3(0.26, 0.1, 0.26), foot + Vector3(0, 0.3, 0), Parts.HAZARD, yaw)
	var beam := Vector3(0, beam_y, 0)
	m.box_chamfered(Vector3(2.96, 0.24, 0.3), 0.05, beam, Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT, yaw)
	m.box(Vector3(2.4, 0.08, 0.32), beam + Vector3(0, 0.08, 0), CRYSTAL_ACCENT, yaw)
	m.box_chamfered(Vector3(0.44, 0.2, 0.44), 0.05, beam + Vector3(0, -0.06, 0), Parts.HULL_MID, yaw)
	m.box(Vector3(0.6, 0.12, 0.06), beam + LowPolyMesh.turn(Vector3(0, 0.06, 0.17), yaw), Parts.HAZARD, yaw)
	# A power box at the left leg's foot.
	m.box_chamfered(Vector3(0.3, 0.32, 0.22), 0.04, Vector3(-0.55, ground, 1.15), Parts.HULL_MID, Vector3(0, 0, 0))
	m.box(Vector3(0.18, 0.14, 0.03), Vector3(-0.55, ground + 0.1, 1.26), CRYSTAL_GLOW)

	var tallest := ground + 0.12 + float(SHARDS[0][2]) * growth
	p.pivot = beam + Vector3(0, -0.06, 0)
	p.speed = 1.6
	_emitter(p.spin, p.pivot.y - tallest, gold)


## A crystal shard: a six-sided column with a pointed tip, tilted, its facets glowing within.
static func _shard(m: LowPolyMesh, foot: Vector3, height: float, radius: float, rot: Vector3) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius * 0.85, 0), Vector2(radius, height * 0.2), Vector2(radius, height * 0.7),
		Vector2(0, height),
	]), 6, foot, CRYSTAL_SHARD, rot)


## The focusing emitter under the gantry: a hub with three prongs round a glowing lens, and
## the beam from the lens `reach` down to the tallest shard.
static func _emitter(s: LowPolyMesh, reach: float, gold: bool) -> void:
	s.prism(0.16, 0.12, 0.1, 16, Vector3(0, -0.1, 0), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND)
	s.cone(0.12, 0.16, 16, Vector3(0, -0.1, 0), Parts.HULL_MID_ROUND, Vector3(180, 0, 0))
	for k: int in 3:
		var root := Parts.around(0.12, 120 * k, -0.1)
		var tip := Parts.around(0.07, 120 * k, -0.36)
		s.strut(root, Parts.around(0.2, 120 * k, -0.22), 0.05, CRYSTAL_PRONG)
		s.strut(Parts.around(0.2, 120 * k, -0.22), tip, 0.05, CRYSTAL_PRONG)
	s.orb(0.07, 12, 6, Vector3(0, -0.3, 0), CRYSTAL_GLOW)
	s.prism(0.035, 0.035, reach - 0.3, 8, Vector3(0, -reach, 0), CRYSTAL_BEAM)


static var ANTIMATTER_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ANTIMATTER)
static var ANTIMATTER_ACCENT_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ANTIMATTER, 1.0, Surf.LIT, true)
static var ANTIMATTER_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, true)
static var ANTIMATTER_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ANTIMATTER, 2.0, Surf.GLOSSY)

## The antimatter siphon's core (the torus turns round it), its field pylons (degrees, the
## camera's corner left open) and the coils on the torus by level.
const SIPHON_CORE := 1.3
const SIPHON_PYLONS := [105.0, 225.0, 345.0]
const SIPHON_COILS := [6, 9, 9]


## A magnetic torus turning round a glowing violet core on a pedestal, wound with field coils,
## three field pylons aiming glowing emitters at it, a capacitor piped to the pedestal.
## Unlocked at Command Center 4, so it looks advanced from L1. L2 adds coils, pylon armour and
## a second capacitor; L3 a second, larger torus tilted round the first, and gold trim.
static func build_antimatter_siphon(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 3
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.lathe(PackedVector2Array([
		Vector2(1.0, 0), Vector2(1.0, 0.14), Vector2(0.62, 0.26), Vector2(0.44, 0.5),
		Vector2(0.42, 0.66), Vector2(0.54, 0.78), Vector2(0, 0.78),
	]), 24, Vector3(0, ground, 0), Parts.HULL_MID_ROUND)
	m.lathe(PackedVector2Array([Vector2(1.04, 0), Vector2(1.04, 0.07), Vector2(0.99, 0.07)]), 24,
		Vector3(0, ground + 0.05, 0), Parts.GOLD_ROUND if gold else ANTIMATTER_ACCENT_ROUND)
	for k: int in 6:
		var degrees := 30.0 + 60.0 * k
		m.box(Vector3(0.1, 0.16, 0.04), Parts.around(0.44, degrees, ground + 0.42), ANTIMATTER_GLOW, Vector3(-8, 90.0 - degrees, 0))
	var cap := ground + 0.78
	m.prism(0.1, 0.08, SIPHON_CORE - cap, 16, Vector3(0, cap, 0), Parts.GUNMETAL)
	m.orb(0.27, 16, 8, Vector3(0, SIPHON_CORE, 0), ANTIMATTER_GLOW)

	for degrees: float in SIPHON_PYLONS:
		_field_pylon(m, degrees, level, gold)

	# Capacitors piped to the pedestal.
	_capacitor(m, Vector3(0.95, ground, 0.95), gold)
	Parts.pipe_run(m, PackedVector3Array([Vector3(0.82, ground + 0.26, 0.82), Vector3(0.48, ground + 0.32, 0.48)]),
		0.06, Parts.GUNMETAL, 8)
	if level >= 2:
		_capacitor(m, Vector3(-1.0, ground, 0.55), gold)
		Parts.pipe_run(m, PackedVector3Array([Vector3(-0.84, ground + 0.26, 0.47), Vector3(-0.58, ground + 0.32, 0.32)]),
			0.06, Parts.GUNMETAL, 8)

	p.pivot = Vector3(0, SIPHON_CORE, 0)
	p.speed = 1.4
	var s := p.spin
	Parts.torus(s, 0.72, 0.12, 24, 10, Vector3(0, -0.12, 0), Parts.HULL_LIGHT_ROUND)
	var coils: int = SIPHON_COILS[level - 1]
	for k: int in coils:
		var degrees := 360.0 * k / coils
		var yaw := Vector3(0, 90.0 - degrees, 0)
		s.box_chamfered(Vector3(0.12, 0.34, 0.36), 0.04, Parts.around(0.72, degrees, -0.17), Parts.HULL_DARK, yaw)
		s.box(Vector3(0.13, 0.06, 0.37), Parts.around(0.72, degrees, 0.04), ANTIMATTER_GLOW, yaw)
	if level >= 3:
		var tilt := Vector3(12, 0, 0)
		Parts.torus(s, 1.05, 0.07, 24, 10, -LowPolyMesh.turn(Vector3(0, 0.07, 0), tilt), Parts.GOLD_ROUND, tilt)


## A field pylon on the pedestal's rim: a column on a foot with an antimatter band, its
## emitter head leaning in towards the torus with a glowing tip.
static func _field_pylon(m: LowPolyMesh, degrees: float, level: int, gold: bool) -> void:
	var yaw := Vector3(0, 90.0 - degrees, 0)
	var foot := Parts.around(1.22, degrees, Parts.PAD_HEIGHT)
	var height := 1.3 + 0.08 * level
	m.box_chamfered(Vector3(0.32, 0.12, 0.32), 0.04, foot, Parts.HULL_DARK, yaw)
	m.box_chamfered(Vector3(0.18, height, 0.18), 0.04, foot, Parts.HULL_LIGHT, yaw)
	m.box(Vector3(0.2, 0.1, 0.2), foot + Vector3(0, height * 0.62, 0), ANTIMATTER_ACCENT, yaw)
	if level >= 2:
		m.box_chamfered(Vector3(0.24, 0.42, 0.24), 0.04, foot + Vector3(0, 0.12, 0), PYLON_ARMOUR, yaw)
	var head := foot + Vector3(0, height, 0)
	m.box_chamfered(Vector3(0.24, 0.12, 0.24), 0.04, head, Parts.GOLD_TRIM if gold else Parts.HULL_MID, yaw)
	var tilt := yaw + Vector3(-50, 0, 0)
	var inward := LowPolyMesh.turn(Vector3.UP, tilt)
	m.prism(0.08, 0.06, 0.26, 12, head + Vector3(0, 0.08, 0), Parts.HULL_MID_ROUND, tilt)
	m.orb(0.07 + 0.015 * level, 10, 5, head + Vector3(0, 0.08, 0) + inward * 0.3, ANTIMATTER_GLOW)


## A capacitor: an armoured block with a violet glass window and a glowing cap.
static func _capacitor(m: LowPolyMesh, pos: Vector3, gold: bool) -> void:
	m.box_chamfered(Vector3(0.38, 0.4, 0.38), 0.05, pos, Parts.HULL_MID)
	m.box(Vector3(0.24, 0.2, 0.4), pos + Vector3(0, 0.1, 0), ANTIMATTER_GLASS)
	m.box_chamfered(Vector3(0.26, 0.05, 0.26), 0.02, pos + Vector3(0, 0.4, 0), Parts.GOLD_TRIM if gold else ANTIMATTER_GLOW)


static var TANK := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_LIGHT, 1.5, Surf.LIT, true)
## The valve handwheels: too thin for the outline.
static var WHEEL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL, 1.0, Surf.LIT, true, false)
static var GOLD_WHEEL := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true, false)

## The metal silo's shell height by level; from L4 it stands as twin tanks.
const METAL_SILO_HEIGHTS := [0.9, 1.15, 1.4, 1.45, 1.45]
const TWIN_TANKS := [Vector3(-0.56, 0, 0.56), Vector3(0.56, 0, -0.56)]


## A squat riveted tank in plate bands on a round plinth, with an access ladder up its lit
## side and a glowing metal fill gauge, a hatch and a vent on its domed top. It grows taller
## to L3, stands as twin tanks joined by a catwalk from L4, and wears gold caps at L5.
static func build_metal_silo(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 5
	var height: float = METAL_SILO_HEIGHTS[level - 1]
	Parts.foundation(m, 3)
	if level < 4:
		_metal_tank(m, Vector3(0, Parts.PAD_HEIGHT, 0), 0.95, height, gold)
		if level >= 3:
			_valves(m, Vector3(0.62, Parts.PAD_HEIGHT, 0.62), gold)
		return
	for spot: Vector3 in TWIN_TANKS:
		_metal_tank(m, spot + Vector3(0, Parts.PAD_HEIGHT, 0), 0.66, height, gold)
	var deck := Parts.PAD_HEIGHT + 0.12 + height
	m.box_chamfered(Vector3(0.3, 0.06, 1.0), 0.02, Vector3(0, deck - 0.02, 0), DECK_PLATE, Vector3(0, 135, 0))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.05, 0.12, 1.0), LowPolyMesh.turn(Vector3(side * 0.15, 0, 0), Vector3(0, 135, 0)) + Vector3(0, deck, 0),
			Parts.ROD, Vector3(0, 135, 0))
	_valves(m, Vector3(0.66, Parts.PAD_HEIGHT, 0.66), gold)


## One metal tank standing at `base`: plinth, banded shell, gauge, ladder, domed top.
static func _metal_tank(m: LowPolyMesh, base: Vector3, radius: float, height: float, gold: bool) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.14, 0), Vector2(radius + 0.14, 0.08), Vector2(radius + 0.08, 0.12), Vector2(0, 0.12),
	]), 24, base, Parts.HULL_DARK_ROUND)
	var shell := base + Vector3(0, 0.12, 0)
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, height)]), 24, shell, TANK)
	var band_y := 0.0
	var k := 0
	while band_y < height - 0.2:
		_band(m, radius, shell + Vector3(0, band_y, 0), METAL_ACCENT_ROUND if k == 1 else Parts.HULL_MID_ROUND)
		band_y += 0.4
		k += 1
	_band(m, radius, shell + Vector3(0, height - 0.08, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)
	var top := shell + Vector3(0, height, 0)
	m.dome(radius, radius * 0.32, 24, 4, top, Parts.GOLD_ROUND if gold else TANK)
	m.prism(0.15, 0.13, 0.08, 16, top + Vector3(-0.12, radius * 0.3, -0.12), Parts.HULL_MID_ROUND)
	var vent := top + Vector3(0.2, radius * 0.24, -0.25)
	Parts.pipe_run(m, PackedVector3Array([vent, vent + Vector3(0, 0.2, 0), vent + Vector3(0.14, 0.2, 0)]), 0.045, Parts.GUNMETAL, 12)
	# The fill gauge on the camera's right, the ladder on the lit left.
	var gauge := Parts.around(radius, 15, 0.1) + shell
	var yaw := Vector3(0, 75, 0)
	m.box_chamfered(Vector3(0.18, height * 0.74, 0.08), 0.03, gauge, Parts.HULL_DARK, yaw)
	m.box(Vector3(0.09, height * 0.52, 0.1), gauge + Vector3(0, 0.04, 0), METAL_GLOW, yaw)
	Parts.ladder(m, Parts.around(radius + 0.06, 118, 0) + shell, height + 0.06, 0.2, 90.0 - 118.0, Parts.ROD)


## A plate band round a tank: its outer wall only, the shell fills it from above.
static func _band(m: LowPolyMesh, radius: float, pos: Vector3, surf: Surf) -> void:
	m.lathe(PackedVector2Array([Vector2(radius + 0.04, 0), Vector2(radius + 0.04, 0.08)]), 24, pos, surf)


## A valve manifold on the near corner: two pipes from the ground with handwheels.
static func _valves(m: LowPolyMesh, pos: Vector3, gold: bool) -> void:
	m.box_chamfered(Vector3(0.36, 0.08, 0.36), 0.03, pos, Parts.HULL_DARK, Vector3(0, 45, 0))
	for side: float in [-1.0, 1.0]:
		var foot := pos + LowPolyMesh.turn(Vector3(side * 0.1, 0.08, 0), Vector3(0, 45, 0))
		Parts.pipe_run(m, PackedVector3Array([foot, foot + Vector3(0, 0.26, 0), foot + Vector3(-0.22, 0.26, -0.22)]), 0.05, Parts.GUNMETAL, 12)
		Parts.torus(m, 0.07, 0.02, 10, 4, foot + Vector3(0, 0.14, 0), GOLD_WHEEL if gold else WHEEL)


static var CRYSTAL_PANEL := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CRYSTAL, 1.0, Surf.GLOSSY)

## The crystal silo's hexagons are turned so a flat face looks at the camera; its container's
## corner radius and the height of one row of panels (a row per level, plus two).
const HEXAGON := Vector3(0, -15, 0)
const CRYSTAL_SILO_RADIUS := 0.86
const PANEL_ROW := 0.2


## A tall hexagonal container of glass panels glowing with the crystal inside, framed by
## corner posts and bands, under a chamfered lid with a crystal finial, on a hexagonal plinth
## with a feed pump at its side. It grows a row of panels a level; L5 adds gold on the lid
## and the bands.
static func build_crystal_silo(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 5
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	var radius := CRYSTAL_SILO_RADIUS
	m.lathe(PackedVector2Array([
		Vector2(1.12, 0), Vector2(1.12, 0.1), Vector2(1.04, 0.18), Vector2(0, 0.18),
	]), 6, Vector3(0, ground, 0), Parts.HULL_DARK, HEXAGON)
	var base := ground + 0.18
	var rows := level + 2
	var height := rows * PANEL_ROW
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, height)]), 6, Vector3(0, base, 0), CRYSTAL_PANEL, HEXAGON)
	for k: int in 6:
		var degrees := 15.0 + 60.0 * k
		m.box_chamfered(Vector3(0.13, height, 0.13), 0.03, Parts.around(radius, degrees, base), Parts.HULL_LIGHT,
			Vector3(0, 90.0 - degrees, 0))
	for row: int in rows + 1:
		var band := Parts.GOLD_TRIM if gold and row == rows else (CRYSTAL_ACCENT if row == 0 else Parts.HULL_LIGHT)
		m.lathe(PackedVector2Array([Vector2(radius + 0.04, 0), Vector2(radius + 0.04, 0.035), Vector2(radius, 0.035)]), 6,
			Vector3(0, base + row * PANEL_ROW - 0.0175, 0), band, HEXAGON)
	var lid := base + height + 0.03
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.08, 0), Vector2(radius + 0.08, 0.1), Vector2(radius - 0.12, 0.22), Vector2(0, 0.22),
	]), 6, Vector3(0, lid, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID, HEXAGON)
	m.lathe(PackedVector2Array([Vector2(0.24, 0), Vector2(0.24, 0.05), Vector2(0.2, 0.08), Vector2(0, 0.08)]), 6,
		Vector3(0, lid + 0.22, 0), Parts.HULL_DARK, HEXAGON)
	_shard(m, Vector3(0, lid + 0.28, 0), 0.46, 0.12, Vector3(0, 15, 0))
	Parts.landing_light(m, Vector3(0.4, lid + 0.18, 0.24), 0.09, CRYSTAL_GLOW)
	# A ladder up the face on the camera's right.
	var apothem := radius * cos(PI / 6.0)
	Parts.ladder(m, Parts.around(apothem + 0.05, 345, base), height + 0.06, 0.2, 90.0 - 345.0, Parts.ROD)

	# The feed pump on the lit side, piped into the bottom row.
	var pump := Vector3(-1.08, ground, 0.62)
	m.box_chamfered(Vector3(0.34, 0.36, 0.42), 0.05, pump, Parts.HULL_MID)
	m.box(Vector3(0.2, 0.1, 0.44), pump + Vector3(0, 0.2, 0), CRYSTAL_GLOW)
	Parts.pipe_run(m, PackedVector3Array([pump + Vector3(0.12, 0.26, -0.12), Vector3(-0.66, base + 0.15, 0.36)]), 0.055, Parts.GUNMETAL, 12)


static var VAULT_ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var VAULT_DOOR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var LID := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 1.5, Surf.LIT, true)
static var VAULT_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ANTIMATTER, 3.0)
static var VENT_CAP := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID, 3.0)
## A glow seam: thin enough to need no outline.
static var SEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, false, false)

## The antimatter vault's armoured cube, and its containment pylons' corners.
const VAULT_SIZE := 1.7
const VAULT_HEIGHT := 1.15
const VAULT_CHAMFER := 0.14
const VAULT_CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]


## A heavy chamfered armoured cube on a skirt, violet glow seams round it and up its corners,
## a round vault door with a handwheel facing the lit side, a control screen on the other,
## and a containment pylon on each corner. L2 adds an armoured domed lid and bigger pylons, L3
## bigger pylons again and gold trim.
static func build_antimatter_vault(p: Parts, level: int) -> void:
	var m := p.body
	var gold := level >= 3
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.box_chamfered(Vector3(2.1, 0.14, 2.1), 0.05, Vector3(0, ground, 0), ARMOUR)
	var floor := ground + 0.14
	var half := VAULT_SIZE * 0.5
	m.box_chamfered(Vector3(VAULT_SIZE, VAULT_HEIGHT, VAULT_SIZE), VAULT_CHAMFER, Vector3(0, floor, 0), VAULT_ARMOUR)
	# Seams: a band round the four faces, and one up each chamfered corner.
	for k: int in 4:
		var yaw := Vector3(0, 90 * k, 0)
		m.box(Vector3(VAULT_SIZE - 2 * VAULT_CHAMFER, 0.05, 0.02), LowPolyMesh.turn(Vector3(0, floor + 0.86, half), yaw), SEAM, yaw)
	for corner: Vector2 in VAULT_CORNERS:
		var edge := Vector3(corner.x, 0, corner.y) * (half - VAULT_CHAMFER * 0.5)
		m.box(Vector3(0.05, VAULT_HEIGHT - 0.2, 0.03), edge + Vector3(corner.x, 0, corner.y) * 0.012 + Vector3(0, floor + 0.06, 0),
			SEAM, Vector3(0, rad_to_deg(atan2(corner.x, corner.y)), 0))
	_vault_door(m, Vector3(0, floor + 0.52, half), gold)
	# The control screen on the shadowed face.
	m.box_chamfered(Vector3(0.06, 0.36, 0.56), 0.02, Vector3(half, floor + 0.5, 0), Parts.HULL_DARK)
	m.box(Vector3(0.02, 0.26, 0.44), Vector3(half + 0.05, floor + 0.55, 0), VAULT_SCREEN)

	var top := floor + VAULT_HEIGHT
	if level >= 2:
		m.prism(0.72, 0.68, 0.1, 24, Vector3(0, top, 0), Parts.HULL_DARK_ROUND)
		Parts.torus(m, 0.66, 0.035, 24, 6, Vector3(0, top + 0.065, 0), ANTIMATTER_GLOW)
		m.dome(0.62, 0.3, 24, 5, Vector3(0, top + 0.1, 0), LID)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.box_chamfered(Vector3(0.14, 0.2, 0.26), 0.03, Parts.around(0.6, degrees, top + 0.04),
				Parts.GOLD_TRIM if gold else Parts.HULL_MID, Vector3(0, 90.0 - degrees, 0))
		m.prism(0.18, 0.16, 0.06, 16, Vector3(0, top + 0.38, 0), Parts.HULL_DARK_ROUND)
		m.disc(0.12, 16, Vector3(0, top + 0.441, 0), ANTIMATTER_GLOW)
	else:
		m.box_chamfered(Vector3(0.7, 0.1, 0.7), 0.04, Vector3(0, top, 0), Parts.HULL_DARK)
		m.box(Vector3(0.5, 0.02, 0.5), Vector3(0, top + 0.1, 0), ANTIMATTER_GLOW)
	for k: int in 2:
		m.box_chamfered(Vector3(0.3, 0.08, 0.16), 0.02, Vector3(-0.5 + k, top, -0.62), VENT_CAP)

	var width := 0.24 + 0.05 * level
	var pylon_height := 0.85 + 0.2 * level
	for corner: Vector2 in VAULT_CORNERS:
		_containment_pylon(m, Vector3(corner.x * 1.06, ground + 0.14, corner.y * 1.06), width, pylon_height, gold)


## The vault door: a round plate in a rim, a hub and a three-spoke handwheel, violet lock
## lights round it.
static func _vault_door(m: LowPolyMesh, centre: Vector3, gold: bool) -> void:
	var facing := Vector3(90, 0, 0)
	m.tube(0, 0.4, 0.06, 24, centre, VAULT_DOOR, facing)
	Parts.torus(m, 0.42, 0.05, 24, 10, centre + Vector3(0, 0, -0.01), Parts.GOLD_ROUND if gold else Parts.GUNMETAL, facing)
	m.tube(0, 0.1, 0.08, 16, centre + Vector3(0, 0, 0.06), Parts.HULL_DARK_ROUND, facing)
	for k: int in 3:
		var spoke := Vector3(cos(PI * k / 3), sin(PI * k / 3), 0) * 0.24
		m.strut(centre + Vector3(0, 0, 0.11) - spoke, centre + Vector3(0, 0, 0.11) + spoke, 0.05, Parts.ROD)
	for k: int in 6:
		var angle := TAU * (k + 0.5) / 6
		m.box(Vector3(0.06, 0.06, 0.04), centre + Vector3(cos(angle) * 0.32, sin(angle) * 0.32 - 0.03, 0.05), ANTIMATTER_GLOW)


## A containment pylon: an armoured column on a foot with its glowing containment cell bared
## between two bars, under a cap whose emitter leans in towards the vault.
static func _containment_pylon(m: LowPolyMesh, foot: Vector3, width: float, height: float, gold: bool) -> void:
	var square := Vector3(0, 45, 0)
	m.box_chamfered(Vector3(width + 0.14, 0.12, width + 0.14), 0.04, foot, Parts.HULL_DARK)
	m.box_chamfered(Vector3(width, height * 0.36, width), 0.04, foot, PYLON_ARMOUR, square)
	m.prism(width * 0.36, width * 0.36, height * 0.34, 16, foot + Vector3(0, height * 0.36, 0), ANTIMATTER_GLOW)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.05, height * 0.34, 0.05), foot + LowPolyMesh.turn(Vector3(side * width * 0.4, height * 0.36, 0), square),
			Parts.ROD, square)
	m.box_chamfered(Vector3(width, height * 0.3, width), 0.04, foot + Vector3(0, height * 0.7, 0), PYLON_ARMOUR, square)
	var cap := foot + Vector3(0, height, 0)
	m.box_chamfered(Vector3(width + 0.08, 0.08, width + 0.08), 0.03, cap, Parts.GOLD_TRIM if gold else Parts.HULL_DARK, square)
	var inward := Vector3(-foot.x, 0, -foot.z).normalized()
	var lean := Vector3(40, rad_to_deg(atan2(inward.x, inward.z)), 0)
	var horn := cap + Vector3(0, 0.08, 0)
	m.prism(0.07, 0.05, 0.24, 16, horn, Parts.HULL_MID_ROUND, lean)
	m.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, horn + LowPolyMesh.turn(Vector3(0, 0.24, 0), lean), ANTIMATTER_GLOW, lean)
