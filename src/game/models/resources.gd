extends RefCounted
## Models of the resource buildings: the drone bay, the collectors and the storage, standing
## on square slabs (tanks, drills).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


static func build_drone_bay(p: Parts, _level: int) -> void:
	var m := p.body
	m.prism(0.92, 0.88, 0.15, 8, Vector3.ZERO, Palette.surf("hull_dark"), Parts.OCTAGON)
	m.ring(0.55, 0.68, 0.04, 12, Vector3(0, 0.15, 0), Palette.surf("hazard"))
	for i: int in 4:
		m.box(Vector3(0.1, 0.06, 0.1), Parts.around(0.75, 45 + 90 * i, 0.15), Palette.surf("glow_cyan"))
	p.pivot = Vector3(0, 0.95, 0)
	p.speed = 1.6
	var drone := p.spin
	drone.box(Vector3(0.36, 0.12, 0.36), Vector3(0, -0.06, 0), Palette.surf("metal"))
	drone.orb(0.08, 6, 3, Vector3(0, -0.1, 0), Palette.surf("glow_cyan"))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		drone.box(Vector3(0.18, 0.03, 0.18), Vector3(corner.x * 0.28, 0.0, corner.y * 0.28), Palette.surf("hull_light"))


static func build_metal_extractor(p: Parts, level: int) -> void:
	var m := p.body
	var paint := Parts.accent(level, 5, "orange")
	Parts.slab(m, 3, 0.3)
	var height := 1.5 + 0.2 * level
	var tower := Vector3(-0.75, 0.3, -0.75)
	m.box(Vector3(0.5, height, 0.5), tower, Palette.surf(paint))
	m.box(Vector3(0.85, 0.35, 0.85), tower + Vector3(0, height, 0), Palette.surf("hull_light"))
	var beam_y := 0.3 + height + 0.1
	if level >= 3:
		var left := Vector3(-0.75, 0.3, 1.0)
		var right := Vector3(1.0, 0.3, -0.75)
		m.box(Vector3(0.22, height, 0.22), left, Palette.surf(paint))
		m.box(Vector3(0.22, height, 0.22), right, Palette.surf(paint))
		m.strut(Vector3(left.x, beam_y - 0.1, left.z), Vector3(right.x, beam_y - 0.1, right.z), 0.24, Palette.surf("hull_light"))
	else:
		m.strut(Vector3(-0.6, beam_y, -0.6), Vector3(0.2, beam_y, 0.2), 0.22, Palette.surf("hull_light"))
	if level >= 2:
		m.dome(0.38, 0.3, 6, 2, Vector3(0.85, 0.3, 0.85), Palette.surf("metal_dark"))
	if level >= 4:
		m.box(Vector3(0.5, 0.45, 0.6), Vector3(-1.0, 0.3, 0.55), Palette.surf("hull"))
		m.box(Vector3(0.14, 0.14, 0.14), tower + Vector3(0.3, height + 0.1, 0.3), Palette.surf("glow_orange"))
	p.pivot = Vector3(0.12, 0.3, 0.12)
	p.speed = 3.0
	p.spin.prism(0.05, 0.3 + 0.03 * level, 0.75, 5, Vector3.ZERO, Palette.surf("metal"))
	p.spin.box(Vector3(0.35, 0.15, 0.35), Vector3(0, 0.75, 0), Palette.surf("metal_dark"))
	p.spin.prism(0.07, 0.07, beam_y - 0.3 - 0.9, 4, Vector3(0, 0.9, 0), Palette.surf("metal_dark"))


## [x, z, height, radius, tilt x, tilt z] of each crystal shard, in the order levels add them.
const SHARDS := [
	[-0.55, 0.45, 1.5, 0.3, 12, -10],
	[0.6, -0.4, 1.3, 0.26, -12, 12],
	[0.55, 0.7, 1.1, 0.24, 14, 14],
	[-0.75, -0.5, 1.2, 0.25, -10, -14],
	[1.0, 0.15, 0.9, 0.2, 0, 18],
	[-0.1, 1.0, 0.95, 0.2, 18, 0],
	[0.15, -1.0, 0.85, 0.2, -16, 0],
]


static func build_crystal_harvester(p: Parts, level: int) -> void:
	var m := p.body
	Parts.slab(m, 3, 0.25)
	for i: int in 2 + level:
		var shard: Array = SHARDS[i]
		var foot := Vector3(shard[0], 0.25, shard[1])
		var height: float = shard[2]
		var radius: float = shard[3]
		m.cone(radius, height, 4, foot, Palette.surf("glow_magenta"), Vector3(shard[4], 0, shard[5]))
	m.prism(0.16, 0.11, 1.5, 6, Vector3(0, 0.25, 0), Palette.surf(Parts.accent(level, 5, "metal_dark")))
	p.pivot = Vector3(0, 1.75, 0)
	p.speed = 1.2
	p.spin.box(Vector3(1.8, 0.08, 0.14), Vector3.ZERO, Palette.surf("hull_light"))
	p.spin.box(Vector3(0.16, 0.16, 0.22), Vector3(0.85, -0.04, 0), Palette.surf("glow_gold" if level >= 5 else "glow_cyan"))


static func build_antimatter_siphon(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.35, 1.2, 0.35, 6, Vector3.ZERO, Palette.surf("hull_dark"))
	m.prism(0.8, 0.7, 0.25, 6, Vector3(0, 0.35, 0), Palette.surf("hull"))
	var spire := 2.0 + 0.3 * level
	m.prism(0.3, 0.07, spire, 6, Vector3(0, 0.6, 0), Palette.surf("metal"))
	m.orb(0.14, 6, 3, Vector3(0, 0.65 + spire, 0), Palette.surf("glow_violet"))
	for degrees: float in [30.0, 150.0, 270.0]:
		m.strut(Parts.around(1.0, degrees, 0.35), Parts.around(0.2, degrees, 1.5), 0.12, Palette.surf(Parts.accent(level, 3, "hull_light")))
	p.pivot = Vector3(0, 1.5, 0)
	p.speed = 1.4
	p.spin.ring(0.42, 0.62, 0.14, 8, Vector3.ZERO, Palette.surf("glow_violet"))
	if level >= 2:
		p.spin.ring(0.3, 0.44, 0.1, 8, Vector3(0, 0.55, 0), Palette.surf("glow_violet"))


static func build_metal_silo(p: Parts, level: int) -> void:
	_silo(p, level, "metal", "orange", "")


static func build_crystal_silo(p: Parts, level: int) -> void:
	_silo(p, level, "hull", "hull_light", "glow_magenta")


## Metal and crystal silos: tanks on a slab, more and taller with each level.
static func _silo(p: Parts, level: int, body: String, band: String, window: String) -> void:
	var m := p.body
	Parts.slab(m, 3, 0.25)
	var tanks: Array[Vector2] = [Vector2(-0.55, 0.55), Vector2(0.55, -0.55)]
	if level >= 3:
		tanks.push_front(Vector2(-0.6, -0.6))
	if level >= 4:
		tanks = [Vector2(-0.6, -0.6), Vector2(0.6, -0.6), Vector2(-0.6, 0.6), Vector2(0.6, 0.6)]
	var radius := 0.45 if tanks.size() == 2 else 0.42
	var height := 1.0 + 0.15 * level
	var trim := Parts.accent(level, 5, band)
	for spot: Vector2 in tanks:
		var base := Vector3(spot.x, 0.25, spot.y)
		m.prism(radius, radius, height, 8, base, Palette.surf(body))
		m.dome(radius, 0.3, 8, 2, base + Vector3(0, height, 0), Palette.surf("metal"))
		m.prism(radius + 0.04, radius + 0.04, 0.12, 8, base + Vector3(0, height * 0.6, 0), Palette.surf(trim))
		if window != "":
			m.box(Vector3(0.1, height - 0.45, 0.22), base + Parts.around(radius, 45, 0.2), Palette.surf(window), Vector3(0, -45, 0))
	if level >= 2:
		m.strut(Vector3(-0.55, 0.05 + height, 0.55), Vector3(0.55, 0.05 + height, -0.55), 0.16, Palette.surf(trim))


static func build_antimatter_vault(p: Parts, level: int) -> void:
	var m := p.body
	Parts.slab(m, 3, 0.2)
	var height := 0.9 + 0.2 * level
	m.box(Vector3(1.6, height, 1.6), Vector3(0, 0.2, 0), Palette.surf("hull"))
	m.box(Vector3(1.64, 0.07, 1.64), Vector3(0, 0.2 + height * 0.5, 0), Palette.surf("glow_violet"))
	m.box(Vector3(0.08, height, 0.08), Vector3(0.8, 0.2, 0), Palette.surf("glow_violet"))
	m.box(Vector3(0.08, height, 0.08), Vector3(0, 0.2, 0.8), Palette.surf("glow_violet"))
	var top := 0.2 + height
	m.box(Vector3(1.2, 0.15, 1.2), Vector3(0, top, 0), Palette.surf("hull_light"))
	if level >= 2:
		m.disc(0.4, 6, Vector3(0, top + 0.151, 0), Palette.surf("glow_violet"))
	var pylon := 1.1 + 0.25 * level
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var foot := Vector3(corner.x * 1.08, 0.2, corner.y * 1.08)
		m.prism(0.12, 0.09, pylon, 4, foot, Palette.surf(Parts.accent(level, 3, "hull_light")), Vector3(0, 45, 0))
		m.orb(0.12, 6, 2, foot + Vector3(0, pylon + 0.1, 0), Palette.surf("glow_violet"))
	if level >= 3:
		m.orb(0.25, 8, 3, Vector3(0, top + 0.6, 0), Palette.surf("glow_violet"))
