class_name UnitModels
extends RefCounted
## The army's unit models, built in code from LowPolyMesh parts painted from the material kit, one
## per unit type in data/units.json (docs/reference/art-style.md, **Units**), as BuildingModels
## builds the buildings'. The contract a unit model keeps: origin on the ground under the unit's
## middle, +Y up, facing +Z; a hovering or flying unit is built at its height over that point.
##
## A model is what BuildingModels.create makes: a Node3D holding the body's MeshInstance3D and its
## ink outline's, and no moving part (MAX_MOVING): the battle draws every unit of a type from one
## MultiMesh (BattleView), so a unit is one mesh and its outline. What turns is a part tagged with
## LowPolyMesh.set_motion (the gunship's rotors), which the shaders spin; what moves is a part tagged with
## LowPolyMesh.rig (the ranger's legs, arms and rifle), which the shaders turn by the battle
## instance's state (Rig); hovering, bobbing, flames and lamps are surface flags (Surf.BOB, PULSE,
## BLINK). A unit's muzzle is a socket (LowPolyMesh.socket), which the battle fires from. The
## meshes are built once per type and tier and shared.
##
## One shape per type: a unit's tier (Parts.Tier) repaints its machine's hull (hull()), panels
## (panel()), trim (trim()) and glows (glow()) only, as the buildings' tiers do. tier_of() takes it from the data: a level researched at a
## Research Lab level takes the band of the Command Center level that lab level requires, and level
## 1 is Base.
##
## Every limb, wheel, turret, rotor and canopy is built by a function of its own from a pivot
## transform, as Figures builds a figure's segments, so the battle view can later tag or move the
## segments without rebuilding a model. The figures (Figures.colonist and Figures.automaton) carry
## their thinner ink (Figures.FIGURE_INK), and so does what an infantry unit wears and carries; a
## machine carries the full line.
##
## This file dispatches and holds the tier palette and the shared helpers; each type's builder is
## a static build_<type>(p: Parts) in its file under src/game/models/: infantry (ranger, breacher,
## jet_trooper, brawler), vehicles (dune_runner, siege_walker, hover_tank, titan) and aircraft
## (skimmer, gunship, bomber).

const InfantryModels := preload("res://src/game/models/infantry.gd")
const VehicleModels := preload("res://src/game/models/vehicles.gd")
const AircraftModels := preload("res://src/game/models/aircraft.gd")

## The far version's share of sides and rings (LowPolyMesh.detail): what the battle draws at the
## wider zooms, where a unit is a few dozen pixels tall.
const FAR_DETAIL := 0.5

## Moving parts a unit model may have: none, since a unit is drawn from a MultiMesh of its one
## mesh; a rotor spins through LowPolyMesh.set_motion instead.
const MAX_MOVING := 0

## The glows' tint per tier: the kit's energy cyan to Chrome, then near-white violets, a pale one
## at Obsidian and a whiter one at Crown. A unit's glows are small and pulse down to 0.55, so the
## buildings' violets (ANTIMATTER, the cores' C9A2FF) sink into the violet field and read as holes;
## these stay glows against the field and the obsidian hull.
const GLOW_TINTS: Array[Color] = [
	MaterialKit.ENERGY, MaterialKit.ENERGY, MaterialKit.ENERGY, Color("dcc4ff"), Color("ead6ff"),
]

## Crown's trim: gold filigree, the bands layer in core gold, at a finer repeat than the
## buildings' (Parts.FILIGREE) so a unit's small plates still show a band.
static var CROWN_TRIM := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 5.0, Surf.GLOSSY)
static var CROWN_TRIM_ROUND := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 5.0, Surf.GLOSSY, true)
## Obsidian's and Crown's panels: the buildings' violet veins (Parts.VEINS) in the cores' bright
## violet, so they read as glowing panels on a unit's small faces, and still, at phase 0, since a
## phase is shared by every effect of a part and a hovering unit bobs every part on phase 0; a FLOW
## phase would put its veins out of step.
const VEIN_TINT := Color("c9a2ff")
static var VEINS := Surf.make(MaterialKit.Layer.VEINS, VEIN_TINT, 1.0, Surf.UNLIT)
static var VEINS_ROUND := Surf.make(MaterialKit.Layer.VEINS, VEIN_TINT, 1.0, Surf.UNLIT, true)

## How far a pilot's helmet shows over its windscreen's top edge, in helmet radii (seat_under()):
## a little over one, so the visor shows whole past the glass in front of it.
const SEAT_SHOW := 1.25

static var _cache: Dictionary[String, BuildingModels.Meshes] = {}
static var _glows: Dictionary[String, Surf] = {}
## Guards _glows: a unit model may be built on another thread (ModelPreview's pictures).
static var _glows_lock: Mutex = Mutex.new()
static var _warned: Dictionary[String, bool] = {}


## The Tier of `type` at `level`: Base at level 1; above it, the band (BuildingModels.tier_for_cc)
## of the Command Center level that the Research Lab level it requires (`requires_lab`) requires.
static func tier_of(catalog: Catalog, type: String, level: int) -> int:
	if level <= 1:
		return Parts.Tier.BASE
	var lab := int(catalog.unit_level_stats(type, level).get("requires_lab", 1))
	return BuildingModels.tier_of(catalog, catalog.research_type, lab)


## The model of `type` built for `tier` (tier_of), cached by type and tier.
static func create(type: String, tier: int) -> Node3D:
	return BuildingModels.assemble(meshes(type, tier))


## The meshes of `type` built for `tier`, cached by type, tier and version: the body and its
## outline, for a caller that draws them itself (BattleView's MultiMeshes); `far` for the version
## with fewer sides (FAR_DETAIL) the battle draws at the wider zooms.
static func meshes(type: String, tier: int, far: bool = false) -> BuildingModels.Meshes:
	var key := "%s/%d%s" % [type, tier, "/far" if far else ""]
	var built: BuildingModels.Meshes = _cache.get(key)
	if built == null:
		built = BuildingModels.meshes_of(build(type, tier, FAR_DETAIL if far else 1.0))
		_cache[key] = built
	return built


## A model's nodes for parts `p` a caller built, uncached.
static func instantiate(p: Parts) -> Node3D:
	return BuildingModels.assemble(BuildingModels.meshes_of(p))


## The parts of `type` built for `tier`, uncached: for create() and for a caller that reads them
## (the gallery's counts); at `detail` below 1, its far version (LowPolyMesh.detail). An unknown
## type gets a plain marker and one warning.
static func build(type: String, tier: int, detail: float = 1.0) -> Parts:
	var p := Parts.new()
	p.tier = tier
	# A unit turns to its heading, banks, kicks and rolls as it dies: never upright (Parts.upright).
	p.upright = false
	p.body.detail = detail
	# The far version is drawn from BattleUnits.FAR_ZOOM out, the near one at the camera's closest.
	p.body.zoom = BattleUnits.FAR_ZOOM if detail < 1.0 else IsoCamera.MIN_ZOOM_SIZE
	match type:
		"ranger":
			InfantryModels.build_ranger(p)
		"breacher":
			InfantryModels.build_breacher(p)
		"jet_trooper":
			InfantryModels.build_jet_trooper(p)
		"brawler":
			InfantryModels.build_brawler(p)
		"dune_runner":
			VehicleModels.build_dune_runner(p)
		"siege_walker":
			VehicleModels.build_siege_walker(p)
		"hover_tank":
			VehicleModels.build_hover_tank(p)
		"titan":
			VehicleModels.build_titan(p)
		"skimmer":
			AircraftModels.build_skimmer(p)
		"gunship":
			AircraftModels.build_gunship(p)
		"bomber":
			AircraftModels.build_bomber(p)
		_:
			if not _warned.has(type):
				_warned[type] = true
				push_warning("No model for unit type '%s'; showing a marker" % type)
			p.body.box_chamfered(Vector3(0.4, 0.5, 0.4), 0.06, Vector3.ZERO, Parts.HULL_MID)
	assert(p.movers.size() <= MAX_MOVING, "a unit model has at most %d moving parts" % MAX_MOVING)
	return p


# --- The tier palette ---------------------------------------------------------------
# As the buildings' tiers (docs/reference/art-style.md, **Tiers**): a machine's hull is cream at
# Base and Gold, chrome at Chrome, obsidian at Obsidian and Crown; its panels hull mid, then violet
# veins from Obsidian; its trim hull mid, gold, cyan strips, chrome on the obsidian, and gold
# filigree at Crown. The crews keep their own paint.

## The main hull of `tier` (plates, chassis, fuselage, armour); `smooth` for the smooth version.
static func hull(tier: int, smooth: bool = false) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN_ROUND if smooth else Parts.OBSIDIAN
	if tier == Parts.Tier.CHROME:
		return Parts.CHROME_ROUND if smooth else Parts.CHROME
	return Parts.HULL_LIGHT_ROUND if smooth else Parts.HULL_LIGHT


## The secondary panels of `tier` (thighs, wings, a dash): hull mid, then from Obsidian the violet
## veins, glowing through the dark hull.
static func panel(tier: int, smooth: bool = false) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return VEINS_ROUND if smooth else VEINS
	return Parts.HULL_MID_ROUND if smooth else Parts.HULL_MID


## A large hull surface that would leave a dark tier too dark: the hull to Chrome, the veins
## from Obsidian (the skimmer's saucer, the bomber's wings).
static func veined(tier: int, smooth: bool = false) -> Surf:
	return panel(tier, smooth) if tier >= Parts.Tier.OBSIDIAN else hull(tier, smooth)


## A machine's deck plate: the one camera-facing top plate every machine carries so that no tier
## reads as a dark lump from the camera, as the titan's deck cap does. A thin plate `size` standing
## on `pos`, turned `rot`, of the hull to Chrome and the veins from Obsidian (veined()), and from
## Gold up a strip of the tier's trim down its middle, half its width and 0.9 of its length: gold,
## the cyan light strip, chrome on the veins, Crown's gold filigree.
static func deck(m: LowPolyMesh, size: Vector3, pos: Vector3, tier: int, rot: Vector3 = Vector3.ZERO) -> void:
	m.box(size, pos, veined(tier), rot)
	if tier >= Parts.Tier.GOLD:
		m.box(Vector3(size.x * 0.5, size.y + 0.008, size.z * 0.9), pos, trim(tier), rot)


## The trim of `tier` (rims, caps, bands, collars, edges): hull mid at Base, then gold, the cyan
## light strips at Chrome, chrome on the obsidian and Crown's gold filigree.
static func trim(tier: int, smooth: bool = false) -> Surf:
	match tier:
		Parts.Tier.GOLD:
			return Parts.GOLD_ROUND if smooth else Parts.GOLD_TRIM
		Parts.Tier.CHROME:
			return Parts.CYAN_STRIP
		Parts.Tier.OBSIDIAN:
			return Parts.CHROME_ROUND if smooth else Parts.CHROME
		Parts.Tier.CROWN:
			return CROWN_TRIM_ROUND if smooth else CROWN_TRIM
	return Parts.HULL_MID_ROUND if smooth else Parts.HULL_MID


## A glow of `tier`: the glow layer in GLOW_TINTS[tier], unlit, smooth, with `flags` added (PULSE
## for flames, BLINK for a lamp) and PULSE from Chrome up, so a higher tier's glows are livelier;
## not outlined unless `outline` (a glow under 0.06 across). Made once per look and shared.
static func glow(tier: int, flags: int = 0, outline: bool = true) -> Surf:
	var all := Surf.UNLIT | flags | (Surf.PULSE if tier >= Parts.Tier.CHROME and (flags & Surf.BLINK) == 0 else 0)
	var key := "%d/%d/%s" % [tier, all, outline]
	_glows_lock.lock()
	if not _glows.has(key):
		_glows[key] = Surf.make(MaterialKit.Layer.GLOW, GLOW_TINTS[tier], 1.0, all, true, outline)
	var made: Surf = _glows[key]
	_glows_lock.unlock()
	return made


# --- Shared helpers -----------------------------------------------------------------

## The Euler degrees, as LowPolyMesh's parts take them, of the pivot `xf` turned further by
## `degrees` in its own space: to build a part in a segment's frame.
static func euler(xf: Transform3D, degrees: Vector3 = Vector3.ZERO) -> Vector3:
	var basis := xf.basis * Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z)))
	var e := basis.get_euler()
	return Vector3(rad_to_deg(e.x), rad_to_deg(e.y), rad_to_deg(e.z))


## The pivot at `pos` turned by Euler `degrees` (as the parts take them).
static func pivot(pos: Vector3, degrees: Vector3 = Vector3.ZERO) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(deg_to_rad(degrees.x), deg_to_rad(degrees.y), deg_to_rad(degrees.z))), pos)


## A colonist seated at the controls (Figures.seated), its pelvis on `seat`, facing +Z turned
## `yaw`, `scale` times the colonist's size; without `legs` its legs are left out, hidden in the
## hull. Its own ink, as every figure's. Returns its joints, for the controls in its hands.
## seat_under() gives the seat's height that sinks it into its machine.
static func pilot(m: LowPolyMesh, seat: Vector3, yaw: float, scale: float, legs: bool = false) -> Figures.Joints:
	var pose := Figures.seated()
	var foot := seat - Figures.joints(Vector3.ZERO, yaw, pose, Figures.PRIMARY_HEADS, scale).pelvis.origin
	Figures.colonist(m, foot, yaw, pose, Figures.PRIMARY_HEADS, scale, legs)
	return Figures.joints(foot, yaw, pose, Figures.PRIMARY_HEADS, scale)


## The height of the seat that sits a pilot of `scale` (pilot()) in its machine: its helmet's top
## SEAT_SHOW helmet radii over `top`, the top edge of its windscreen (canopy()), so the helmet and
## its visor show over the glass and the rest of the pilot is in the hull.
static func seat_under(top: float, scale: float) -> float:
	var j := Figures.joints(Vector3.ZERO, 0.0, Figures.seated(), Figures.PRIMARY_HEADS, scale)
	var head := Figures.COLONIST_HEIGHT * scale / Figures.PRIMARY_HEADS
	var crown := (j.neck * Vector3(0, head * 0.925, 0)).y - j.pelvis.origin.y
	return top + head * 0.5 * SEAT_SHOW - crown


## The height of the top edge of a canopy() of `radius` rising `rise` degrees, over its pivot.
static func canopy_top(radius: float, rise: float) -> float:
	return radius * sin(deg_to_rad(rise))


## A canopy on the pivot `xf`: a curved glass windscreen of `radius` and `depth` thick wrapping
## the pivot's front (its +Z), rising `rise` degrees from its foot, swept from `from_deg` to
## `to_deg` round its +Y (90 dead ahead), in a gunmetal frame: a lip at its foot and a rim along its
## top edge. Open above and behind, so the pilot seated in it (pilot(), seat_under()) shows over it:
## the glass is opaque. The frame is gunmetal at every tier, so `_tier` is unused: the tier shows
## on the machine's deck plate (deck()) instead.
static func canopy(m: LowPolyMesh, xf: Transform3D, radius: float, depth: float, rise: float, from_deg: float,
		to_deg: float, _tier: int, sides: int = 24) -> void:
	const STEPS := 3
	var profile := PackedVector2Array()
	for i: int in STEPS + 1:
		var e := deg_to_rad(rise * i / STEPS)
		profile.append(Vector2(radius * cos(e), radius * sin(e)))
	for i: int in range(STEPS, -1, -1):
		var e := deg_to_rad(rise * i / STEPS)
		profile.append(Vector2((radius - depth) * cos(e), (radius - depth) * sin(e)))
	m.lathe(profile, sides, xf.origin, Parts.GLASS, euler(xf), from_deg, to_deg)
	# The frame's lip and rim: an outer wall and a top each, their inner walls hidden by the glass.
	var lip := depth * 1.2
	m.lathe(PackedVector2Array([
		Vector2(radius + depth * 0.6, 0), Vector2(radius + depth * 0.6, lip), Vector2(radius - depth * 1.5, lip),
	]), sides, xf.origin, Parts.GUNMETAL, euler(xf), from_deg - 4.0, to_deg + 4.0)
	var top := deg_to_rad(rise)
	var edge := (radius - depth * 0.5) * cos(top)
	var height := radius * sin(top)
	m.lathe(PackedVector2Array([
		Vector2(edge + depth, height - depth), Vector2(edge + depth, height + depth * 0.8),
		Vector2(edge - depth, height + depth * 0.8),
	]), sides, xf.origin, Parts.GUNMETAL, euler(xf), from_deg - 2.0, to_deg + 2.0)
