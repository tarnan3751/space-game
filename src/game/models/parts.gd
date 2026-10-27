class_name Parts
extends RefCounted
## A building model while it is built (BuildingModels.create): its tier, the static body, up
## to max_moving(tier) moving parts (moving()), and what the per-category model files
## (src/game/models/) share: the helpers, the common surfaces, and SURFACES, the table that
## paints the colour names the models were first written with onto the material kit
## (docs/reference/art-style.md).

## Octagons are turned so their flat sides face along X and Z.
const OCTAGON := Vector3(0, 22.5, 0)

## A level's theme, set by the Command Center band it is unlocked in
## (BuildingModels.tier_for_cc; docs/reference/art-style.md, **Tiers**).
enum Tier { BASE, GOLD, CHROME, OBSIDIAN, CROWN }

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

## The high tiers' shared surfaces (docs/reference/art-style.md, **Tiers**), named once for every
## model batch. Chrome: polished plating, pale cyan-white on the chrome layer and glossy, flat and smooth,
## and its cyan light strips, pulsing. Obsidian: dark glassy armour, flat and smooth, and the
## violet energy veins running through it (FLOW along V). Crown: gold filigree on the bands layer
## over the obsidian, and the antimatter core glowing in the body. Gold keeps GOLD_TRIM and
## GOLD_ROUND. Shared: never change one.
## Chrome's tint: a cool pale cyan-white, so polished plating parts from the cream hull-light.
const CHROME_TINT := Color("e6f4ff")
## Obsidian's tint: a deep ink violet, so the dark layer reads as violet glass, not a void.
const OBSIDIAN_TINT := Color("8a6ad8")
## The antimatter core's glow: a saturated violet, so it pops where ANTIMATTER reads pale.
const CORE_GLOW_TINT := Color("9b5cff")
static var CHROME := Surf.make(MaterialKit.Layer.CHROME, CHROME_TINT, 1.0, Surf.GLOSSY)
static var CHROME_ROUND := Surf.make(MaterialKit.Layer.CHROME, CHROME_TINT, 1.0, Surf.GLOSSY, true)
static var CYAN_STRIP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var OBSIDIAN := Surf.make(MaterialKit.Layer.OBSIDIAN, OBSIDIAN_TINT, 1.0, Surf.GLOSSY)
static var OBSIDIAN_ROUND := Surf.make(MaterialKit.Layer.OBSIDIAN, OBSIDIAN_TINT, 1.0, Surf.GLOSSY, true)
static var VEINS := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW, true, true, 0.7)
static var FILIGREE := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 2.0, Surf.GLOSSY)
static var CORE_GLOW := Surf.make(MaterialKit.Layer.GLOW, CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE, true)

static var _surfs: Dictionary[String, Surf] = {}


## Every SURFACES entry made when the script loads, on the main thread, so surf() only reads the
## table afterwards and a model may be built on another thread (ModelPreview's pictures).
static func _static_init() -> void:
	for name: String in SURFACES:
		surf(name)

## Moving parts a model of `model_tier` may have: three, and at Crown a fourth for its escort.
static func max_moving(model_tier: int) -> int:
	return 4 if model_tier >= Tier.CROWN else 3


## The level's Tier, set before the builder runs: a builder reads it, never the level, for
## the tier's surfaces (`p.tier >= Parts.Tier.GOLD` for gold trim).
var tier: int = Tier.BASE
var body := LowPolyMesh.new()
## Whether the model is only ever drawn upright (LowPolyMesh.upright): a building is, so its body
## and its moving parts that spin about +Y or slide leave the faces no camera sees out of their
## bodies. A builder whose model tilts turns it off before its first part (UnitModels.build, the
## drone's).
var upright := true:
	set(value):
		upright = value
		body.upright = value
## The moving parts, each with its pivot and Motion, in the order moving() made them.
var movers: Array[LowPolyMesh] = []
var pivots := PackedVector3Array()
var motions: Array[Motion] = []
## Per moving part, the index of the moving part it rides (riding()), -1 for none.
var rides := PackedInt32Array()


func _init() -> void:
	body.upright = upright


## A new moving part, which moves about `pivot` as `motion` says: build it in its own space,
## with the pivot at its origin. It is upright (LowPolyMesh.upright) when the model is and its
## motion spins about +Y or slides.
func moving(pivot: Vector3, motion: Motion) -> LowPolyMesh:
	assert(movers.size() < max_moving(tier), "a model has at most %d moving parts" % max_moving(tier))
	var mesh := LowPolyMesh.new()
	mesh.upright = upright and (motion.kind == Motion.Kind.SLIDE
		or (motion.kind == Motion.Kind.SPIN and absf(motion.axis.y) > 0.9999))
	movers.append(mesh)
	pivots.append(pivot)
	motions.append(motion)
	rides.append(-1)
	return mesh


## A new moving part that rides the moving part `on` (one moving() or riding() made): it moves
## about `pivot` (in the model's space, `on` at rest) as `motion` says, and is carried by whatever
## moves `on` (BuildingView poses it after `on`'s motion and aim): a ring round a barrel that aims.
## Built as moving() builds one, and counted with them.
func riding(on: LowPolyMesh, pivot: Vector3, motion: Motion) -> LowPolyMesh:
	var mesh := moving(pivot, motion)
	mesh.carrier = on
	rides[rides.size() - 1] = movers.find(on)
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


## Radians a second every spinning radar dish turns at, one speed across the base: brisk enough
## to read in a second of play.
const DISH_RATE := 1.6


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


# --- The post family: masts, dish posts and lamp posts (docs/reference/art-style.md, **Shared shapes**)

## Nothing structural is thinner than this across: under it a part reads as a scratch at the
## overview and as ink stacked on ink close up.
const STRUCTURAL_MIN := 0.14
## A tapered mast's radius at its foot and at its top, and how far its foot flares past it.
const MAST_FOOT_RADIUS := 0.09
const MAST_TOP_RADIUS := 0.07
const MAST_FLARE := 0.03
## A dish post's width; a lamp post's pole's width and its bulb's radius.
const DISH_POST_WIDTH := 0.16
const LAMP_POLE_WIDTH := 0.1
const LAMP_BULB_RADIUS := 0.12
## A lamp post's pole: cream and never inked, so a pole this thin reads as a light line on the
## violet ground, not as a line of ink; the bulb carries the outline.
static var LAMP_POLE := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true, false)


## A mast standing on `foot`, `height` tall, on `surface` (a smooth one, so it shades round): a
## lathe tapering from MAST_FOOT_RADIUS to MAST_TOP_RADIUS over a foot flared MAST_FLARE wider,
## `sides` round (12; 8 where a budget is tight); with a `bulb` of `bulb_radius` sitting on its top.
## Returns the top's centre.
static func tapered_mast(m: LowPolyMesh, foot: Vector3, height: float, surface: Surf, bulb_radius: float = 0.0,
		bulb: Surf = null, sides: int = 12) -> Vector3:
	var flare := MAST_FOOT_RADIUS + MAST_FLARE
	m.lathe(PackedVector2Array([
		Vector2(flare, 0), Vector2(flare, 0.05), Vector2(MAST_FOOT_RADIUS, 0.1),
		Vector2(MAST_TOP_RADIUS, height), Vector2(0, height),
	]), sides, foot, surface)
	var top := foot + Vector3(0, height, 0)
	if bulb != null:
		m.orb(bulb_radius, 12, 6, top + Vector3(0, bulb_radius * 0.7, 0), bulb)
	return top


## A dish post standing on `foot`, `height` tall: a chamfered square column DISH_POST_WIDTH
## across on `surface`, turned `yaw` degrees. Returns its top's centre, where a dish's
## turntable stands.
static func dish_post(m: LowPolyMesh, foot: Vector3, height: float, surface: Surf, yaw: float = 0.0) -> Vector3:
	m.box_chamfered(Vector3(DISH_POST_WIDTH, height, DISH_POST_WIDTH), 0.04, foot, surface, Vector3(0, yaw, 0))
	return foot + Vector3(0, height, 0)


## A lamp post standing on `foot`, its bulb's centre `height` up: a pole LAMP_POLE_WIDTH across on
## `pole` (LAMP_POLE, never inked, unless a caller gives its own) and a bulb of LAMP_BULB_RADIUS
## on `bulb`, which carries the outline. Returns the bulb's centre.
static func lamp_post(m: LowPolyMesh, foot: Vector3, height: float, bulb: Surf, pole: Surf = LAMP_POLE) -> Vector3:
	m.prism(LAMP_POLE_WIDTH * 0.5, LAMP_POLE_WIDTH * 0.5, height, 8, foot, pole)
	var at := foot + Vector3(0, height, 0)
	m.orb(LAMP_BULB_RADIUS, 12, 6, at, bulb)
	return at


# --- Effects shared by the model files (docs/reference/art-style.md, **Animation**) ----

## A crackling arc's radius: its segments are three-sided tubes about 0.03 across.
const ARC_RADIUS := 0.02

## Smoke puffs: pale hologram smoke, rising and fading; HULL_MID is too faint against the violet
## ground.
static var SMOKE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HULL_LIGHT, 1.0, Surf.HOLO | Surf.RISE, true)


## A crackling arc's surface: a glow in `tint` that flickers and shakes at the LIGHTNING rates,
## the same slow crackle on every arc.
static func spark(tint: Color) -> Surf:
	return Surf.make(MaterialKit.Layer.GLOW, tint, 1.0, Surf.UNLIT | Surf.FLICKER | Surf.JITTER | Surf.LIGHTNING)


## A current: the pipe layer's ribbed bands glowing in `tint` and flowing at the FLOW speed
## `phase` (above 0.5 along V: towards a pipe's far end, a box's +Z on its top).
static func current(tint: Color, phase: float) -> Surf:
	return Surf.make(MaterialKit.Layer.PIPE, tint, 3.0, Surf.UNLIT | Surf.FLOW, true, true, phase)


## The BLINK phase of lamp `k` of `count` lit in turn, lamp 0 first: a chase.
static func chase(k: int, count: int) -> float:
	return fposmod(-float(k) / count, 1.0)


## A point `radius` from a sphere's centre, at around() angle `at.x` and elevation `at.y`
## (degrees).
static func on_sphere(radius: float, at: Vector2) -> Vector3:
	var elevation := deg_to_rad(at.y)
	return around(radius * cos(elevation), at.x, radius * sin(elevation))


## A crackling arc from `from` to `to`: `segments` thin three-sided tubes, the corners between
## them kinked `kink` to either side of the straight line in turn, so JITTER has corners to
## shake. Built for a spark() surface, which is never outlined; give each arc its own phase of
## it, so the arcs flicker apart.
static func arc(m: LowPolyMesh, from: Vector3, to: Vector3, segments: int, kink: float, surface: Surf) -> void:
	var along := (to - from).normalized()
	var side := along.cross(Vector3.UP)
	if side.length() < 0.1:
		side = along.cross(Vector3.RIGHT)
	side = side.normalized()
	var last := from
	for k: int in range(1, segments + 1):
		var point := from.lerp(to, float(k) / segments)
		if k < segments:
			point += side * kink * (1.0 if k % 2 == 1 else -1.0)
		pipe(m, last, point, ARC_RADIUS, surface, 3, false)
		last = point


## A seam up a dome of `radius` and `height` standing on `pos`, at `degrees` round it: a chain of
## thin strips just proud of the surface, from its foot to under the crown (within 0.15 of the
## axis).
static func dome_seam(m: LowPolyMesh, radius: float, height: float, pos: Vector3, degrees: float,
		surface: Surf) -> void:
	const STEPS := 4
	const PROUD := 0.012
	var last := acos(0.15 / radius)
	var from := Vector3.ZERO
	for k: int in STEPS + 1:
		var angle := last * k / STEPS
		var at := around((radius + PROUD) * cos(angle), degrees, (height + PROUD) * sin(angle)) + pos
		if k > 0:
			m.strut(from, at, 0.03, surface)
		from = at


## Smoke rising from a stack's `mouth`: `count` puffs, orbs of `sides` and `rings` of mixed sizes
## (radii from 0.07, 0.017 more a puff), all starting just above the mouth on `surface` with RISE
## added, their phases spread evenly from `phase` so the column is always full: each climbs,
## drifts and fades (on a hologram surface) and starts again.
static func puffs(m: LowPolyMesh, mouth: Vector3, phase: float, count: int = 4, sides: int = 8,
		rings: int = 3, surface: Surf = SMOKE) -> void:
	var rising := Surf.make(surface.layer, surface.tint, surface.uv_scale, surface.flags | Surf.RISE, surface.smooth,
		surface.outline)
	for k: int in count:
		m.orb(0.07 + 0.017 * k, sides, rings, mouth + Vector3(0, 0.08, 0),
			rising.phased(fposmod(phase + float(k) / count, 1.0)))


# --- Escorts: the Crown tier's fourth moving part (docs/reference/art-style.md, **Tiers**) ---

## The escorts' surfaces: the drone's hull, eye and rotor blurs (unlit screen-layer discs whose
## segments run round, so no hologram surface); the skiff's hull, canopy, engines and glowing
## underside, all bobbing together. The troopers are Figures' colonists, on its surfaces.
static var ESCORT_EYE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var ESCORT_ROTOR := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ENERGY, 4.0, Surf.UNLIT | Surf.FLOW_U, false,
	true, 0.9)
static var SKIFF_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 2.0, Surf.BOB, false, true, 0.3)
static var SKIFF_CANOPY := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0, Surf.GLOSSY | Surf.BOB, true,
	true, 0.3)
static var SKIFF_ENGINE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true, true, 0.3)
static var SKIFF_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB,
	true, true, 0.3)
## The security bot's surfaces, every one bobbing together on GUARD_PHASE: cream hull armour,
## gunmetal pods and antenna, a dark chest plate, a gold lip, the red visor and antenna tip, and
## the cyan pod tips and thruster skirt.
const GUARD_PHASE := 0.6
static var GUARD_ARMOUR := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.BOB, false, true, GUARD_PHASE)
static var GUARD_GUNMETAL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true, true, GUARD_PHASE)
static var GUARD_CHEST := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.BOB, false, true, GUARD_PHASE)
static var GUARD_LIP := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, false, true,
	GUARD_PHASE)
static var GUARD_VISOR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, GUARD_PHASE)
static var GUARD_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, GUARD_PHASE)


## A small quadrotor guard drone, a third the size of the drone bay's (times `scale`), orbiting
## the footprint's centre (or `centre` on the ground) `radius` out and `height` up at `rate`
## radians a second (a spin about +Y), its nose to its heading and its rotors a blur. About 0.12
## times `scale` across from its centre: keep its round within the extent. Returns the moving
## part.
static func escort_drone(p: Parts, radius: float, height: float, rate: float,
		centre: Vector3 = Vector3.ZERO, scale: float = 1.0) -> LowPolyMesh:
	var s := p.moving(centre + Vector3(0, height, 0), Motion.spin(Vector3.UP, rate))
	var at := Vector3(radius, 0, 0)
	var z := scale
	var heading := Vector3(0, 180.0 if rate > 0.0 else 0.0, 0)
	s.lathe(PackedVector2Array([
		Vector2(0, -0.025) * z, Vector2(0.04, -0.025) * z, Vector2(0.07, -0.008) * z, Vector2(0.065, 0.015) * z,
		Vector2(0, 0.025) * z,
	]), 10, at, HULL_LIGHT_ROUND)
	s.dome(0.03 * z, 0.025 * z, 8, 2, at + Vector3(0, 0.02, 0) * z, GLASS)
	s.box(Vector3(0.04, 0.018, 0.02) * z, at + LowPolyMesh.turn(Vector3(0, -0.01, 0.065) * z, heading), ESCORT_EYE, heading)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		var hub := at + around(0.1, degrees, 0.005) * z
		s.box(Vector3(0.07, 0.016, 0.02) * z, at + around(0.065, degrees, -0.003) * z, HULL_MID, Vector3(0, -degrees, 0))
		s.disc(0.035 * z, 8, hub, ESCORT_ROTOR.phased(0.9 if k % 2 == 0 else 0.1))
	return s


## A security bot patrolling round the footprint's centre (or `centre` on the ground) `radius` out
## and `height` up (its middle) at `rate` radians a second: a robust hover sentinel, unlike the
## drones and the skiff. A chunky chamfered cream hull body wider than tall, a gold lip round its
## foot, a dark chest plate under one wide red visor strip, two stubby gunmetal weapon pods on its
## shoulders with cyan tips, a short antenna nub and a thin cyan thruster skirt glowing round its
## lower edge, under the lip, where the camera sees it, every part bobbing together, `scale` times
## its own size (0.36 across its travel, 0.18 tall, 0.26 long). About 0.3 times `scale` from its
## centre to its pods' ends: keep its round within the extent. Returns the moving part.
static func escort_guard(p: Parts, radius: float, height: float, rate: float,
		centre: Vector3 = Vector3.ZERO, scale: float = 1.0) -> LowPolyMesh:
	var s := p.moving(centre + Vector3(0, height, 0), Motion.spin(Vector3.UP, rate))
	var at := Vector3(radius, 0, 0)
	var z := scale
	var heading := Vector3(0, 180.0 if rate > 0.0 else 0.0, 0)
	var forward := heading + Vector3(90, 0, 0)
	s.box_chamfered(Vector3(0.36, 0.18, 0.26) * z, 0.05 * z, at + Vector3(0, -0.09, 0) * z, GUARD_ARMOUR, heading)
	s.box_chamfered(Vector3(0.38, 0.035, 0.28) * z, 0.012 * z, at + Vector3(0, -0.09, 0) * z, GUARD_LIP, heading)
	s.box_chamfered(Vector3(0.22, 0.075, 0.03) * z, 0.012 * z, at + LowPolyMesh.turn(Vector3(0, -0.05, 0.13) * z, heading),
		GUARD_CHEST, heading)
	s.box_chamfered(Vector3(0.3, 0.045, 0.03) * z, 0.01 * z, at + LowPolyMesh.turn(Vector3(0, 0.03, 0.13) * z, heading),
		GUARD_VISOR, heading)
	for side: float in [-1.0, 1.0]:
		s.box_chamfered(Vector3(0.08, 0.08, 0.2) * z, 0.02 * z, at + LowPolyMesh.turn(Vector3(side * 0.21, 0, 0.05) * z, heading),
			GUARD_GUNMETAL, heading)
		s.disc(0.026 * z, 8, at + LowPolyMesh.turn(Vector3(side * 0.21, 0.04, 0.151) * z, heading), GUARD_GLOW, forward)
	s.box_chamfered(Vector3(0.39, 0.035, 0.29) * z, 0.01 * z, at + Vector3(0, -0.125, 0) * z, GUARD_GLOW, heading)
	var nub := at + LowPolyMesh.turn(Vector3(0.1, 0.09, -0.07) * z, heading)
	s.prism(0.03 * z, 0.024 * z, 0.06 * z, 8, nub, GUARD_GUNMETAL)
	s.dome(0.026 * z, 0.025 * z, 8, 2, nub + Vector3(0, 0.06, 0) * z, GUARD_VISOR)
	return s


## A hover skiff patrolling round the footprint's centre (or `centre` on the ground) `radius` out
## and `height` up at `rate` radians a second: a chamfered hull with a glass canopy, two engine
## pods and a glowing underside, bobbing as it flies, `scale` times its own size. About 0.3 times
## `scale` from its centre to its engines' ends: keep its round within the extent. Returns the
## moving part.
static func escort_skiff(p: Parts, radius: float, height: float, rate: float,
		centre: Vector3 = Vector3.ZERO, scale: float = 1.0) -> LowPolyMesh:
	var s := p.moving(centre + Vector3(0, height, 0), Motion.spin(Vector3.UP, rate))
	var at := Vector3(radius, 0, 0)
	var z := scale
	var heading := Vector3(0, 180.0 if rate > 0.0 else 0.0, 0)
	s.box(Vector3(0.16, 0.012, 0.3) * z, at + Vector3(0, -0.012, 0) * z, SKIFF_GLOW, heading)
	s.box_chamfered(Vector3(0.18, 0.07, 0.34) * z, 0.025 * z, at, SKIFF_HULL, heading)
	s.dome(0.06 * z, 0.05 * z, 10, 3, at + LowPolyMesh.turn(Vector3(0, 0.07, 0.04) * z, heading), SKIFF_CANOPY)
	for side: float in [-1.0, 1.0]:
		var pod := at + LowPolyMesh.turn(Vector3(side * 0.11, 0.02, -0.14) * z, heading)
		s.prism(0.035 * z, 0.03 * z, 0.14 * z, 10, pod, SKIFF_ENGINE, heading + Vector3(-90, 0, 0))
		s.disc(0.028 * z, 10, pod + LowPolyMesh.turn(Vector3(0, 0, -0.141) * z, heading), SKIFF_GLOW, heading + Vector3(-90, 0, 0))
	return s


## Two troopers, colonists (Figures.colonist) mid-stride, marching a round about the footprint's
## centre (or `centre` on the ground) `radius` out at `height` (their feet) at `rate` radians a
## second, the second a pace behind the first. Each stands TROOPER_HEIGHT tall times `scale`, its
## arms and boots about 0.3 times `scale` from its centre: keep their round within the extent.
## Returns the moving part.
static func escort_troopers(p: Parts, radius: float, height: float, rate: float,
		centre: Vector3 = Vector3.ZERO, scale: float = 1.0) -> LowPolyMesh:
	var s := p.moving(centre + Vector3(0, height, 0), Motion.spin(Vector3.UP, rate))
	for k: int in 2:
		# The second trooper walks a pace (0.5 units times `scale`) behind the first along the round.
		var behind := 0.5 * scale / radius * k * (1.0 if rate > 0.0 else -1.0)
		var at := around(radius, rad_to_deg(behind), 0.0)
		var heading := Vector3(0, rad_to_deg(-behind) + (180.0 if rate > 0.0 else 0.0), 0)
		_trooper(s, at, heading, scale)
	return s


## How tall an escort trooper stands, its helmet's top: big enough to read as a soldier at the
## gameplay zoom. The colonist's height (Figures.COLONIST_HEIGHT).
const TROOPER_HEIGHT := 0.8


## One trooper standing at `foot`, facing `heading`: the colonist (Figures.colonist) mid-stride at
## the primary proportion, TROOPER_HEIGHT tall times `scale`.
static func _trooper(s: LowPolyMesh, foot: Vector3, heading: Vector3, scale: float) -> void:
	Figures.colonist(s, foot, heading.y, Figures.stride(), Figures.PRIMARY_HEADS, TROOPER_HEIGHT / Figures.COLONIST_HEIGHT * scale)
