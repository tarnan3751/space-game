class_name Parts
extends RefCounted
## A building model while it is built (BuildingModels.create): the static body, the part that
## spins around `pivot` at `speed` radians a second, and what the per-category model files
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

static var _surfs: Dictionary[String, Surf] = {}

var body := LowPolyMesh.new()
var spin := LowPolyMesh.new()
var pivot := Vector3.ZERO
var speed := 0.0


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


## The square slab resource and army buildings stand on.
static func slab(m: LowPolyMesh, size: float, height: float) -> void:
	m.box(Vector3(0.88 * size, height, 0.88 * size), Vector3.ZERO, surf("hull_dark"))


## The octagonal plinth defences stand on.
static func plinth(m: LowPolyMesh, size: float, height: float) -> void:
	m.prism(0.47 * size, 0.44 * size, height, 8, Vector3.ZERO, surf("hull_dark"), OCTAGON)


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
