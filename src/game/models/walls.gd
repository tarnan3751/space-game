extends RefCounted
## Models of the walls (at most 40 triangles).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.

## The glow strip of a wall, by level.
const WALL_GLOWS := ["glow_cyan", "glow_green", "glow_magenta", "glow_red", "glow_gold"]


static func build_barrier_wall(p: Parts, level: int) -> void:
	var m := p.body
	var height := 0.5 + 0.06 * level
	m.box(Vector3(0.86, height, 0.86), Vector3.ZERO, Parts.surf("hull"))
	m.box(Vector3(0.74, 0.22, 0.74), Vector3(0, height, 0), Parts.surf("hull_light"))
	m.box(Vector3(0.76, 0.06, 0.34), Vector3(0, height + 0.2, 0), Parts.surf(WALL_GLOWS[level - 1]))
