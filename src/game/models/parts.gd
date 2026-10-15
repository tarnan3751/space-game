class_name Parts
extends RefCounted
## A building model while it is built (BuildingModels.create): the static body, up to
## MAX_MOVING moving parts (moving()), and what the per-category model files
## (src/game/models/) share: the helpers, the common surfaces, and SURFACES, the table that
## paints the colour names the models were first written with onto the material kit
## (docs/reference/art-style.md).

## Octagons are turned so their flat sides face along X and Z.
const OCTAGON := Vector3(0, 22.5, 0)

## Each colour name the models use, as a kit surface: [layer, tint, flags, smooth]. Hulls take
## the hull layer, metals the plate layer, the glows the glow layer unlit in their category's
## accent colour, hazard the fixed-colour hazard layer.
const SURFACES := {
	"hull": [MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, Surf.LIT, false],
	"hull_light": [MaterialKit.Layer.HULL, MaterialKit.HULL_MID, Surf.LIT, false],
	"hull_dark": [MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, Surf.LIT, false],
	"metal": [MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, Surf.LIT, true],
	"metal_dark": [MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK, Surf.LIT, true],
	"white": [MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, Surf.LIT, true],
	"window": [MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, Surf.GLOSSY, false],
	"orange": [MaterialKit.Layer.PLATE, MaterialKit.ARMY, Surf.LIT, false],
	"red": [MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, Surf.LIT, false],
	"hazard": [MaterialKit.Layer.HAZARD, Color.WHITE, Surf.LIT, false],
	"gold": [MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, Surf.GLOSSY, false],
	"glow_cyan": [MaterialKit.Layer.GLOW, MaterialKit.ENERGY, Surf.UNLIT, true],
	"glow_orange": [MaterialKit.Layer.GLOW, MaterialKit.ARMY, Surf.UNLIT, true],
	"glow_magenta": [MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, Surf.UNLIT, true],
	"glow_violet": [MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, Surf.UNLIT, true],
	"glow_green": [MaterialKit.Layer.GLOW, MaterialKit.NANITE_GREEN, Surf.UNLIT, true],
	"glow_red": [MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, Surf.UNLIT, true],
	"glow_blue": [MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, Surf.UNLIT, true],
	"glow_gold": [MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, Surf.UNLIT, true],
}

## Common surfaces of the art style, for the model passes. Shared: never change one.
static var CONCRETE_PAD := Surf.make(MaterialKit.Layer.CONCRETE, MaterialKit.CONCRETE)
static var HULL_LIGHT := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT)
static var HULL_MID := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID)
static var HULL_DARK := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK)
static var GUNMETAL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.LIT, true)
static var HAZARD := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE)
static var GOLD_TRIM := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY)
static var GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0, Surf.GLOSSY, true)
## Smooth versions for round parts (drums, tanks, collars, caps), so the cel bands sweep
## across them in arcs. Shared: never change one.
static var HULL_LIGHT_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var HULL_MID_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var HULL_DARK_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.LIT, true)
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)

static var _surfs: Dictionary[String, Surf] = {}

## Moving parts a model may have.
const MAX_MOVING := 3

var body := LowPolyMesh.new()
## The moving parts, each with its pivot and Motion, in the order moving() made them.
var movers: Array[LowPolyMesh] = []
var pivots := PackedVector3Array()
var motions: Array[Motion] = []


## A new moving part, which moves about `pivot` as `motion` says: build it in its own space,
## with the pivot at its origin.
func moving(pivot: Vector3, motion: Motion) -> LowPolyMesh:
	assert(movers.size() < MAX_MOVING, "a model has at most %d moving parts" % MAX_MOVING)
	var mesh := LowPolyMesh.new()
	movers.append(mesh)
	pivots.append(pivot)
	motions.append(motion)
	return mesh


## The kit surface of a colour name in SURFACES, made once and shared.
static func surf(name: String) -> Surf:
	if not _surfs.has(name):
		if not SURFACES.has(name):
			push_error("Parts has no surface '%s'" % name)
			return HULL_LIGHT
		var row: Array = SURFACES[name]
		_surfs[name] = Surf.make(row[0], row[1], 1.0, row[2], row[3])
	return _surfs[name]


## Gold on the top level, `normal` below it.
static func accent(level: int, top: int, normal: String) -> String:
	return "gold" if level >= top else normal


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
	]), surf(color))


# --- Shapes of the comic style, shared by the model files ---------------------------

## The foundation pad's height and its inset from the edge of the footprint.
const PAD_HEIGHT := 0.12
const PAD_INSET := 0.1

## A thin rod (an antenna, a ladder rail): too thin for an outline, so left out of it.
static var ROD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.GUNMETAL, 1.0, Surf.LIT, true, false)


## The foundation pad every building stands on: a chamfered concrete slab under the whole
## footprint of `size` cells, inset PAD_INSET, PAD_HEIGHT high.
static func foundation(m: LowPolyMesh, size: int) -> void:
	var side := size - 2.0 * PAD_INSET
	m.box_chamfered(Vector3(side, PAD_HEIGHT, side), 0.05, Vector3.ZERO, CONCRETE_PAD)


## The rotation (Euler degrees, as the LowPolyMesh parts take it) that turns +Y onto `dir`.
static func facing(dir: Vector3) -> Vector3:
	var unit := dir.normalized()
	return Vector3(rad_to_deg(acos(clampf(unit.y, -1.0, 1.0))), rad_to_deg(atan2(unit.x, unit.z)), 0)


## A round pipe from `from` to `to`, `radius` thick and `sides` round; capped at `to` unless
## that end is inside something.
static func pipe(m: LowPolyMesh, from: Vector3, to: Vector3, radius: float, surface: Surf,
		sides: int = 16, capped: bool = true) -> void:
	var length := from.distance_to(to)
	if length <= 0.0:
		return
	var profile := PackedVector2Array([Vector2(radius, 0), Vector2(radius, length)])
	if capped:
		profile.append(Vector2(0, length))
	m.lathe(profile, sides, from, surface, facing(to - from))


## A square beam from `from` to `to`, `width` thick, its edges chamfered `chamfer`: girders,
## booms, legs, gantry rails. Its square end is at `from`.
static func beam(m: LowPolyMesh, from: Vector3, to: Vector3, width: float, surface: Surf,
		chamfer: float = 0.03) -> void:
	var length := from.distance_to(to)
	if length <= 0.0:
		return
	m.box_chamfered(Vector3(width, length, width), chamfer, from, surface, facing(to - from))


## A pipe through `points`, `sides` round, with a ball elbow a little fatter than the pipe at
## each bend.
static func pipe_run(m: LowPolyMesh, points: PackedVector3Array, radius: float, surface: Surf,
		sides: int = 16) -> void:
	for i: int in points.size() - 1:
		pipe(m, points[i], points[i + 1], radius, surface, sides, i == points.size() - 2)
	for i: int in range(1, points.size() - 1):
		m.orb(radius * 1.3, sides, 4, points[i], surface)


## A round tank standing on `pos`: a wall of `radius` and `height` whose top edge is
## chamfered `chamfer` into a flat lid.
static func tank(m: LowPolyMesh, radius: float, height: float, pos: Vector3, surface: Surf,
		chamfer: float = 0.06, sides: int = 16) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, height - chamfer), Vector2(radius - chamfer, height),
		Vector2(0, height),
	]), sides, pos, surface)


## A dish of `radius`, `depth` deep: a bowl opening along +Y before `rot`, the centre of its
## back on `pos`. Radar and comms dishes.
static func dish(m: LowPolyMesh, radius: float, depth: float, pos: Vector3, surface: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(radius * 0.55, depth * 0.3), Vector2(radius, depth),
		Vector2(radius * 0.9, depth), Vector2(radius * 0.5, depth * 0.45), Vector2(0, depth * 0.3),
	]), 24, pos, surface, rot)


## A landing light standing on `pos`, `radius` wide: a squat housing and a glowing lens.
static func landing_light(m: LowPolyMesh, pos: Vector3, radius: float, lens: Surf,
		housing: Surf = GUNMETAL) -> void:
	m.prism(radius, radius * 0.85, radius * 0.5, 16, pos, housing)
	m.dome(radius * 0.7, radius * 0.7, 16, 3, pos + Vector3(0, radius * 0.5, 0), lens)


## A sensor mast: a thin rod from `foot` up `height`, ending in a bulb of `bulb_radius`,
## which carries the outline the rod is too thin for.
static func mast(m: LowPolyMesh, foot: Vector3, height: float, bulb_radius: float, bulb: Surf) -> void:
	m.prism(0.03, 0.022, height, 8, foot, ROD)
	m.orb(bulb_radius, 16, 6, foot + Vector3(0, height, 0), bulb)


## A cylinder whose top edge is bevelled `chamfer` wide, turned by `rot`: a drum, a turret
## ring, a tilted housing. With 8 sides and OCTAGON it is an armoured octagon.
static func drum(m: LowPolyMesh, radius: float, height: float, chamfer: float, sides: int,
		pos: Vector3, surface: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, height - chamfer), Vector2(radius - chamfer, height),
		Vector2(0, height),
	]), sides, pos, surface, rot)


## A ring of round section, `minor` thick around a circle of radius `major`, resting on `pos`
## (its bottom at pos.y, like box and prism): a coil, a corona, a gyro ring. Closed, so it
## reads at any tilt.
static func torus(m: LowPolyMesh, major: float, minor: float, sides: int, segments: int,
		pos: Vector3, surface: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array()
	for k: int in segments + 1:
		var angle := TAU * k / segments - PI * 0.5
		profile.append(Vector2(major + minor * cos(angle), minor + minor * sin(angle)))
	m.lathe(profile, sides, pos, surface, rot)


## A ladder `height` tall up a wall, `foot` the middle of its feet, its face turned `yaw`
## degrees from +Z: two rails and a rung every 0.16.
static func ladder(m: LowPolyMesh, foot: Vector3, height: float, width: float, yaw: float,
		surface: Surf) -> void:
	var turn := Vector3(0, yaw, 0)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.05, height, 0.05), foot + LowPolyMesh.turn(Vector3(side * width * 0.5, 0, 0), turn), surface, turn)
	for k: int in int((height - 0.06) / 0.16):
		m.box(Vector3(width, 0.035, 0.035), foot + Vector3(0, 0.12 + 0.16 * k, 0), surface, turn)
