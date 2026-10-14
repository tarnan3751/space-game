extends RefCounted
## Models of the traps, nearly flush with the ground (at most 40 triangles).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


static func build_proximity_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.38, 0.34, 0.1, 6, Vector3.ZERO, Parts.surf("hull_light"))
	var dots := level + 1
	for i: int in dots:
		m.pyramid(0.1, 0.06, Parts.around(0.2, 360.0 * i / dots, 0.1), Parts.surf("glow_gold" if level >= 3 else "glow_red"))


static func build_grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	m.box(Vector3(0.76, 0.06, 0.76), Vector3.ZERO, Parts.surf("hull"))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.pyramid(0.14, 0.4, Vector3(corner.x * 0.27, 0.06, corner.y * 0.27), Parts.surf(Parts.accent(level, 2, "metal")))
	m.pyramid(0.24, 0.1, Vector3(0, 0.06, 0), Parts.surf("glow_violet"))


static func build_flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.14, 0.12, 0.15, 4, Vector3.ZERO, Parts.surf("hull_dark"))
	m.orb(0.27, 5, 3, Vector3(0, 0.38, 0), Parts.surf("hull"))
	var dot := "glow_gold" if level >= 3 else "glow_orange"
	for i: int in mini(level, 2):
		m.pyramid(0.14, 0.08, Parts.around(0.14 * i, 0, 0.58), Parts.surf(dot))


static func build_mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.8, 0.75, 0.12, 6, Vector3.ZERO, Parts.surf("metal_dark"))
	for offset: float in [-0.3, 0.0, 0.3]:
		Parts.plate(m, Vector2(0.12, 0.7), Vector3(offset, 0.121, 0), "hazard", 30)
	for i: int in 3:
		m.pyramid(0.1, 0.05, Parts.around(0.55, 90 + 120 * i, 0.12), Parts.surf("glow_gold" if level >= 2 else "glow_red"))
