extends RefCounted
## Models of the army buildings: halls and domes with big doors, on slabs.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


static func build_hangar(p: Parts, level: int) -> void:
	var m := p.body
	Parts.slab(m, 5, 0.15)
	var height := 1.4 + 0.15 * level
	var front := 1.0
	m.box(Vector3(4.0, height, 3.0), Vector3(0, 0.15, -0.5), Parts.surf("hull"))
	var stripe := Parts.accent(level, 5, "hazard")
	for x: float in [-1.2, 0.0, 1.2]:
		m.box(Vector3(0.22, 0.04, 2.8), Vector3(x, 0.15 + height, -0.5), Parts.surf(stripe))
	for i: int in 3:
		Parts.plate(m, Vector2(0.18, 0.7), Vector3(-1.2 + 1.2 * i, 0.151, 1.6), "hazard", 30)
	var bays := mini(level, 3)
	var bay := 3.8 / bays
	for i: int in bays:
		var x := -1.9 + bay * (i + 0.5)
		m.box(Vector3(bay - 0.3, height - 0.35, 0.1), Vector3(x, 0.15, front), Parts.surf("window"))
		m.box(Vector3(bay - 0.3, 0.08, 0.08), Vector3(x, height - 0.1, front + 0.02), Parts.surf("glow_orange"))
	for i: int in bays + 1:
		m.box(Vector3(0.2, height, 0.2), Vector3(-1.9 + bay * i, 0.15, front), Parts.surf("hull_light"))
	if level >= 4:
		var tower := Vector3(1.5, 0.15, -1.55)
		m.box(Vector3(0.9, height + 1.0, 0.9), tower, Parts.surf("hull_light"))
		m.box(Vector3(0.94, 0.2, 0.94), tower + Vector3(0, height + 0.6, 0), Parts.surf("glow_blue"))
		m.prism(0.04, 0.03, 0.6, 4, tower + Vector3(0, height + 1.0, 0), Parts.surf("metal"))


static func build_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var paint := Parts.accent(level, 5, "orange")
	Parts.slab(m, 3, 0.2)
	var height := 1.0 + 0.1 * level
	var body := Vector3(-0.25, 0.2, -0.3)
	m.box(Vector3(2.0, height, 1.7), body, Parts.surf("hull_light"))
	m.box(Vector3(2.04, 0.12, 1.74), body + Vector3(0, height * 0.6, 0), Parts.surf(paint))
	m.box(Vector3(0.8, 0.7, 0.08), Vector3(-0.25, 0.2, 0.56), Parts.surf("window"))
	var top := 0.2 + height
	var stack := 1.0 + 0.15 * level
	m.prism(0.2, 0.17, stack, 6, Vector3(-0.85, top, -0.8), Parts.surf("metal_dark"))
	m.prism(0.19, 0.19, 0.1, 6, Vector3(-0.85, top + stack - 0.12, -0.8), Parts.surf("glow_orange"))
	if level >= 2:
		m.prism(0.16, 0.14, stack * 0.7, 6, Vector3(-0.35, top, -0.85), Parts.surf("metal_dark"))
		m.prism(0.15, 0.15, 0.08, 6, Vector3(-0.35, top + stack * 0.7 - 0.1, -0.85), Parts.surf("glow_orange"))
	m.box(Vector3(0.7, 0.3, 0.45), Vector3(0.95, 0.2, 0.15), Parts.surf("hull_dark"))
	m.box(Vector3(0.7, 0.03, 0.08), Vector3(0.95, 0.5, 0.0), Parts.surf(paint))
	m.box(Vector3(0.7, 0.03, 0.08), Vector3(0.95, 0.5, 0.3), Parts.surf(paint))
	m.box(Vector3(0.25, 0.25, 0.25), Vector3(1.05, 0.5, 0.15), Parts.surf("orange"))
	if level >= 3:
		m.wedge(Vector3(1.9, 0.35, 0.7), body + Vector3(0.0, height, 0.4), Parts.surf("hull"))
		m.wedge(Vector3(1.9, 0.35, 0.7), body + Vector3(0.0, height, -0.3), Parts.surf("hull"))
	if level >= 4:
		m.box(Vector3(0.14, 0.9, 0.14), Vector3(0.55, top, -0.8), Parts.surf("hull_dark"))
		m.strut(Vector3(0.55, top + 0.85, -0.8), Vector3(1.1, top + 0.6, 0.15), 0.1, Parts.surf(paint))


static func build_heavy_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var paint := Parts.accent(level, 3, "red")
	Parts.slab(m, 3, 0.2)
	var height := 1.3 + 0.15 * level
	m.box(Vector3(2.4, height, 2.0), Vector3(-0.1, 0.2, -0.2), Parts.surf("hull_dark"))
	m.box(Vector3(2.44, 0.14, 2.04), Vector3(-0.1, 0.2 + height * 0.7, -0.2), Parts.surf(paint))
	var top := 0.2 + height
	m.box(Vector3(1.4, 0.5, 1.2), Vector3(-0.4, top, -0.5), Parts.surf("hull"))
	m.box(Vector3(1.2, 0.95, 0.08), Vector3(0.1, 0.2, 0.81), Parts.surf("window"))
	m.box(Vector3(1.2, 0.08, 0.06), Vector3(0.1, 1.2, 0.84), Parts.surf("glow_red"))
	var stack := 1.1 + 0.2 * level
	var stacks: Array[float] = [-0.9, 0.55]
	if level >= 2:
		stacks.append(-0.2)
	for x: float in stacks:
		m.prism(0.22, 0.19, stack, 6, Vector3(x, top, -0.95), Parts.surf("metal_dark"))
		m.prism(0.21, 0.21, 0.1, 6, Vector3(x, top + stack - 0.12, -0.95), Parts.surf("glow_red"))


static func build_research_lab(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(1.42, 1.32, 0.3, 8, Vector3.ZERO, Parts.surf("hull_dark"), Parts.OCTAGON)
	if level >= 5:
		m.prism(1.44, 1.42, 0.06, 8, Vector3(0, 0.3, 0), Parts.surf("gold"), Parts.OCTAGON)
	m.prism(1.05, 1.0, 0.5, 8, Vector3(0, 0.3, 0), Parts.surf("hull_light"), Parts.OCTAGON)
	m.prism(1.03, 1.03, 0.14, 8, Vector3(0, 0.48, 0), Parts.surf("glow_blue"), Parts.OCTAGON)
	var dome := 0.85 + 0.05 * level
	m.dome(0.95, dome, 8, 3, Vector3(0, 0.8, 0), Parts.surf("white"))
	var post := Vector3(0.82, 0.3, -0.82)
	var reach := 1.0 + 0.1 * level
	m.prism(0.08, 0.06, reach, 4, post, Parts.surf("metal"))
	var dish := 1.3 if level >= 3 else 1.0
	var aim := Vector3(40, 135, 0)
	var centre := post + Vector3(0, reach, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.06, 0), Vector2(0.45 * dish, 0.18 * dish), Vector2(0.4 * dish, 0.21 * dish), Vector2(0, 0.06),
	]), 8, centre, Parts.surf("white"), aim)
	m.cone(0.05, 0.35, 4, centre + LowPolyMesh.turn(Vector3(0, 0.05, 0), aim), Parts.surf("glow_blue"), aim)
	if level >= 2:
		var annex := Vector3(-0.85, 0.3, 0.85)
		m.prism(0.38, 0.35, 0.35, 6, annex, Parts.surf("hull_light"))
		m.dome(0.36, 0.3, 6, 2, annex + Vector3(0, 0.35, 0), Parts.surf("white"))
	if level >= 4:
		m.prism(0.22, 0.18, 0.25, 8, Vector3(0, 0.75 + dome, 0), Parts.surf("glow_blue"))


static func build_nanite_foundry(p: Parts, level: int) -> void:
	var m := p.body
	Parts.slab(m, 3, 0.2)
	var vat := Vector3(-0.3, 0.2, -0.3)
	m.lathe(PackedVector2Array([
		Vector2(0.75, 0), Vector2(0.72, 1.1), Vector2(0.6, 1.1), Vector2(0.6, 0.95),
	]), 8, vat, Parts.surf("metal_dark"), Parts.OCTAGON)
	m.disc(0.6, 8, vat + Vector3(0, 0.95, 0), Parts.surf("glow_green"), Parts.OCTAGON)
	m.ring(0.73, 0.82, 0.12, 8, vat + Vector3(0, 0.5, 0), Parts.surf("glow_green"), Parts.OCTAGON)
	if level >= 4:
		m.ring(0.6, 0.76, 0.06, 8, vat + Vector3(0, 1.1, 0), Parts.surf("gold"), Parts.OCTAGON)
	var pump := Vector3(0.85, 0.2, 0.75)
	m.box(Vector3(0.6, 0.55, 0.6), pump, Parts.surf("hull_light"))
	m.strut(vat + Vector3(0.5, 0.75, 0.5), pump + Vector3(-0.1, 0.4, -0.1), 0.14, Parts.surf("metal"))
	m.prism(0.08, 0.08, 0.5, 4, pump + Vector3(0.15, 0.55, 0.15), Parts.surf("metal"))
	if level >= 2:
		var small := Vector3(0.85, 0.2, -0.85)
		m.prism(0.35, 0.33, 0.7, 8, small, Parts.surf("metal_dark"), Parts.OCTAGON)
		m.disc(0.3, 8, small + Vector3(0, 0.701, 0), Parts.surf("glow_green"), Parts.OCTAGON)
		m.strut(small + Vector3(-0.2, 0.45, 0.1), vat + Vector3(0.6, 0.45, -0.3), 0.12, Parts.surf("metal"))
	if level >= 3:
		m.prism(0.15, 0.12, 1.5, 6, Vector3(-1.0, 0.2, 0.9), Parts.surf("hull"))
		m.strut(Vector3(-0.95, 0.9, 0.85), vat + Vector3(-0.3, 0.9, 0.5), 0.1, Parts.surf("metal"))


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
