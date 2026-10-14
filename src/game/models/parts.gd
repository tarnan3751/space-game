class_name Parts
extends RefCounted
## A building model while it is built (BuildingModels.create): the static body, the part that
## spins around `pivot` at `speed` radians a second, and the helpers the per-category model
## files (src/game/models/) share.

## Octagons are turned so their flat sides face along X and Z.
const OCTAGON := Vector3(0, 22.5, 0)

var body := LowPolyMesh.new()
var spin := LowPolyMesh.new()
var pivot := Vector3.ZERO
var speed := 0.0


## Gold on the top level, `normal` below it.
static func accent(level: int, top: int, normal: String) -> String:
	return "gold" if level >= top else normal


## The square slab resource and army buildings stand on.
static func slab(m: LowPolyMesh, size: float, height: float) -> void:
	m.box(Vector3(0.88 * size, height, 0.88 * size), Vector3.ZERO, Palette.surf("hull_dark"))


## The octagonal plinth defences stand on.
static func plinth(m: LowPolyMesh, size: float, height: float) -> void:
	m.prism(0.47 * size, 0.44 * size, height, 8, Vector3.ZERO, Palette.surf("hull_dark"), OCTAGON)


## A point on a circle of `radius` around the Y axis, at `degrees` from +X towards +Z.
static func around(radius: float, degrees: float, y: float) -> Vector3:
	var angle := deg_to_rad(degrees)
	return Vector3(radius * cos(angle), y, radius * sin(angle))


## A flat rectangle facing up, turned `yaw` degrees: stripes and markings, two triangles.
static func plate(m: LowPolyMesh, size: Vector2, pos: Vector3, color: String, yaw: float) -> void:
	var turn := Vector3(0, yaw, 0)
	var h := size * 0.5
	m.polygon(PackedVector3Array([
		pos + LowPolyMesh.turn(Vector3(-h.x, 0, -h.y), turn),
		pos + LowPolyMesh.turn(Vector3(-h.x, 0, h.y), turn),
		pos + LowPolyMesh.turn(Vector3(h.x, 0, h.y), turn),
		pos + LowPolyMesh.turn(Vector3(h.x, 0, -h.y), turn),
	]), Palette.surf(color))
