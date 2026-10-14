extends RefCounted
## Models of the core: the Command Center, plus the scaffold shown while a building is first
## built and the hull block an unknown type gets (both by footprint size, not level).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.

## Where the Command Center's antennae stand, in the order levels add them (degrees).
const ANTENNAE := [200.0, 340.0, 100.0, 20.0]


static func build_command_center(p: Parts, level: int) -> void:
	var m := p.body
	var trim := Parts.accent(level, 5, "hull_light")
	var beacon := "glow_gold" if level >= 5 else "glow_cyan"
	m.prism(1.8, 1.72, 0.35, 6, Vector3.ZERO, Parts.surf("hull_dark"))
	m.prism(1.72, 1.68, 0.08, 6, Vector3(0, 0.35, 0), Parts.surf(trim))
	for i: int in 6:
		m.box(Vector3(0.16, 0.1, 0.16), Parts.around(1.42, 30 + 60 * i, 0.43), Parts.surf("glow_cyan"))
	var body_height := 0.9 + 0.18 * level
	m.prism(1.15, 1.0, body_height, 6, Vector3(0, 0.43, 0), Parts.surf("hull"))
	var top := 0.43 + body_height
	if level >= 2:
		m.prism(1.1, 1.08, 0.14, 6, Vector3(0, 0.43 + body_height * 0.45, 0), Parts.surf("glow_cyan"))
	m.dome(0.85, 0.7, 8, 3, Vector3(0, top, 0), Parts.surf("metal"))
	var mast := 0.8 + 0.15 * level
	m.prism(0.06, 0.04, mast, 4, Vector3(0, top + 0.6, 0), Parts.surf("metal"))
	m.orb(0.13, 6, 3, Vector3(0, top + 0.72 + mast, 0), Parts.surf(beacon))
	for i: int in level - 1:
		var degrees: float = ANTENNAE[i]
		var foot := Parts.around(0.93, degrees, top)
		var height := 0.5 + 0.12 * i
		m.prism(0.04, 0.03, height, 4, foot, Parts.surf("metal"))
		m.pyramid(0.1, 0.12, foot + Vector3(0, height, 0), Parts.surf("gold" if level >= 5 else "glow_red"))
	if level >= 3:
		var annex := Parts.around(1.2, -45, 0.43)
		m.prism(0.45, 0.4, 0.45, 6, annex, Parts.surf("hull"))
		m.dome(0.4, 0.35, 6, 2, annex + Vector3(0, 0.45, 0), Parts.surf("white"))
	if level >= 4:
		var annex := Parts.around(1.2, 135, 0.43)
		m.box(Vector3(0.6, 0.55, 0.6), annex, Parts.surf("hull_light"), Vector3(0, 45, 0))
		m.box(Vector3(0.64, 0.12, 0.64), annex + Vector3(0, 0.3, 0), Parts.surf("glow_cyan"), Vector3(0, 45, 0))
	p.pivot = Vector3(0, top + 0.6 + mast * 0.45, 0)
	p.speed = 0.8
	p.spin.box(Vector3(0.9, 0.05, 0.22), Vector3(0.3, 0, 0), Parts.surf("hull_light"))
	p.spin.box(Vector3(0.12, 0.12, 0.28), Vector3(0.75, -0.03, 0), Parts.surf("glow_cyan"))


static func build_scaffold(p: Parts, size: int) -> void:
	var m := p.body
	var n := float(size)
	var half := 0.4 * n
	m.box(Vector3(0.9 * n, 0.12, 0.9 * n), Vector3.ZERO, Parts.surf("hull_dark"))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.box(Vector3(0.12, 1.0, 0.12), Vector3(corner.x * half, 0.12, corner.y * half), Parts.surf("hazard"))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.9 * n, 0.1, 0.1), Vector3(0, 1.05, side * half), Parts.surf("hazard"))
		m.box(Vector3(0.1, 0.1, 0.9 * n), Vector3(side * half, 0.95, 0), Parts.surf("hazard"))
	m.strut(Vector3(-half, 0.12, half), Vector3(half, 1.05, half), 0.08, Parts.surf("hazard"))


## Unknown types: a hull block with a hazard stripe.
static func build_generic(p: Parts, size: int) -> void:
	var n := float(size)
	p.body.box(Vector3(0.8 * n, 0.8, 0.8 * n), Vector3.ZERO, Parts.surf("hull_light"))
	p.body.box(Vector3(0.82 * n, 0.14, 0.82 * n), Vector3(0, 0.45, 0), Parts.surf("hazard"))
