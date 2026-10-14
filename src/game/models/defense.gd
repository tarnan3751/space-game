extends RefCounted
## Models of the defences, on octagonal plinths.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


static func build_laser_turret(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.45)
	m.prism(1.0, 0.95, 0.12, 8, Vector3(0, 0.45, 0), Parts.surf("hull"), Parts.OCTAGON)
	p.pivot = Vector3(0, 0.57, 0)
	p.speed = 0.4
	var head := p.spin
	var radius := 0.6 + 0.03 * level
	head.prism(radius, radius - 0.05, 0.35, 8, Vector3.ZERO, Parts.surf("hull_light"))
	head.dome(radius - 0.05, 0.3, 8, 2, Vector3(0, 0.35, 0), Parts.surf("hull_light"))
	if level >= 5:
		head.prism(radius + 0.03, radius + 0.03, 0.08, 8, Vector3(0, 0.15, 0), Parts.surf("gold"))
	if level >= 2:
		head.box(Vector3(0.5, 0.28, 0.3), Vector3(0, 0.22, radius - 0.1), Parts.surf("hull"))
	if level >= 4:
		for x: float in [-1.0, 1.0]:
			head.box(Vector3(0.12, 0.3, 0.5), Vector3(x * (radius + 0.02), 0.05, -0.1), Parts.surf("hull_dark"))
	var length := 0.85 + 0.05 * level
	var barrels: Array[float] = [0.0]
	if level >= 3:
		barrels = [-0.16, 0.16]
	for x: float in barrels:
		head.prism(0.09, 0.08, length, 6, Vector3(x, 0.36, 0.25), Parts.surf("metal"), Vector3(90, 0, 0))
		head.orb(0.1, 6, 3, Vector3(x, 0.36, 0.3 + length), Parts.surf("glow_cyan"))


static func build_missile_battery(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.4)
	m.box(Vector3(0.9, 0.45, 0.9), Vector3(0, 0.4, 0), Parts.surf("hull"), Vector3(0, 45, 0))
	var columns := 2 if level < 3 else (3 if level < 5 else 4)
	var width := columns * 0.38 + 0.2
	var aim := Vector3(-30, 45, 0)
	var base := Vector3(0, 0.85, 0)
	m.box(Vector3(width, 0.85, 1.0), base, Parts.surf("hull_light"), aim)
	m.box(Vector3(width + 0.04, 0.1, 1.04), base + LowPolyMesh.turn(Vector3(0, 0.4, 0), aim),
		Parts.surf(Parts.accent(level, 5, "red")), aim)
	var tube_aim := aim + Vector3(90, 0, 0)
	for column: int in columns:
		for row: int in 2:
			var face := Vector3(-0.19 * (columns - 1) + 0.38 * column, 0.22 + 0.4 * row, 0.5)
			var mouth := base + LowPolyMesh.turn(face, aim)
			m.prism(0.14, 0.14, 0.06, 6, mouth, Parts.surf("window"), tube_aim)
			m.cone(0.08, 0.14, 4, mouth, Parts.surf("glow_red"), tube_aim)


static func build_plasma_mortar(p: Parts, level: int) -> void:
	var m := p.body
	Parts.plinth(m, 3, 0.35)
	m.prism(0.6, 0.55, 0.3, 8, Vector3(0, 0.35, 0), Parts.surf("hull"), Parts.OCTAGON)
	var rim := 1.0 + 0.05 * level
	var bowl := Vector3(0, 0.65, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.6, 0), Vector2(rim, 0.75), Vector2(rim - 0.15, 0.8), Vector2(0.45, 0.25),
	]), 10, bowl, Parts.surf("metal_dark"))
	m.disc(0.46, 10, bowl + Vector3(0, 0.25, 0), Parts.surf("glow_orange"))
	m.orb(0.32, 6, 3, bowl + Vector3(0, 0.45, 0), Parts.surf("glow_orange"))
	if level >= 2:
		for degrees: float in [0.0, 90.0, 180.0, 270.0]:
			m.strut(Parts.around(1.05, degrees + 45, 0.35), Parts.around(0.85, degrees + 45, 1.15), 0.12, Parts.surf("hull_light"))
	if level >= 3:
		m.ring(rim - 0.15, rim + 0.03, 0.06, 10, bowl + Vector3(0, 0.8, 0), Parts.surf(Parts.accent(level, 4, "hazard")))


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
