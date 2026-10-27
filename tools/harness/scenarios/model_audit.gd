extends HarnessScenario
## The model audit: finds geometric defects and triangles never seen in every model, and lists
## them for a fix pass. Informational: it fails only on a script error. Headless by default; a
## rendered run shoots the flagged models close at four headings.
##
## Every building type at every level, built for its level's tier as the gallery builds it
## (BuildingModels.create, BuildingModels.tier_of); every unit type at every tier, near and far
## (UnitModels.build at detail 1 and UnitModels.FAR_DETAIL); and the colonist and the automaton
## at stance (Figures). Each model's body and each moving part (BuildingModels.MOVE_META) are read
## back from their meshes, every surface, and split into parts: triangles joined along an edge that
## exactly two of them share, on one surface (layer and flags), so a part stacked flush on another
## (whose edges three or four triangles share) stays apart from it. A part is named
## `body#k` or `mover<m>#k`, with its bounds' centre, size and triangles.
##
## The probes cast rays through a physics space of the model's own (PhysicsServer3D), the opaque
## body, the body's HOLO triangles and the moving parts at rest each a body of its own:
##
## - **cross**, **pierce**, **poke**: each edge of a part, shrunk by EPS at both ends so a part standing on
##   another only touches it, is cast against the body; a pair of parts crosses when an edge of
##   one crosses a triangle of the other. Per crossing pair, the length of each part's edges inside
##   the other, sampled every EDGE_SAMPLE units (a point is inside a part when rays along +X and
##   +Z both cross it an odd number of times: parts have no bottom face, so a vertical ray would
##   not tell). An edge crossing the other part twice with both ends outside it pierces it: a part
##   passing through another and out of its far side. Crossing pairs are counted on the model's
##   line (most are mounts: a pipe sunk in a tank); piercing pairs are findings, a poke when an
##   end sticks out by less than POKE_STUB (an overlong part nicking through), its `stub=` said.
## - **zfight**: a seen triangle with a triangle of another part within ZFIGHT_GAP of its centre,
##   facing the same way (COPLANAR_COS): two faces sharing a plane.
## - **float**: a part whose lowest point is over FLOAT_GAP above the ground and whose bounds,
##   grown FLOAT_GAP, meet no other part's (the moving parts' at rest included). Tagged `bob` when
##   it carries Surf.BOB (a hovering ring is meant to) and `holo` for a hologram.
## - **below**: a part whose lowest point is under -BELOW_SLACK.
## - **hidden**: a part none of whose triangles is ever seen (below), `in=` the part enclosing its
##   centre when one does.
## - **dup**, **degen**: triangles with the same three corners in the same winding as another in the
##   mesh (a back face, the same corners wound the other way, is not one); triangles of no area
##   (DEGEN_AREA).
## - **brush**, **seat**, **mount**: each moving part (a node carrying BuildingModels.MOVE_META)
##   posed about its pivot as Motion.transform_at poses it, turned by an angle or shifted along its
##   axis rather than sampled on the clock: at rest and every MOTION_STEP degrees of a SPIN's turn,
##   a SWING from -amplitude to +amplitude every MOTION_STEP, both ends, a SLIDE at SLIDE_POSES.
##   At each pose its edges are cast against the body and the body's edges against it, per pair of
##   its part and a body part the poses touching (`of=` the poses, `away=` the farthest crossing
##   from the motion's axis through the pivot). A pair that does not touch at rest is a brush: it
##   only meets the body in motion. One that does is a mount when every crossing lies within
##   MOUNT_RADIUS of the axis, else a seat (resting on or through the body away from its pivot: a
##   judgment). A rider is posed only with its carrier at rest, not carried; BOB is not applied; a
##   part that spins in the shaders (Surf.SPIN, the gunship's rotors) is read as static body and
##   never posed; the pairs of moving parts, BOB and the riders carried are model_clash's.
## - **aim**: an aiming part's pitch sweep against the other moving parts, model_clash's own
##   (_travel, _pitch_sweep, read as model_clash reads a model): any pose touching a part other than
##   the one that turns it (which carries it) is a finding.
##   KNOWN marks the contacts already on record.
## - **round**: a part whose vertices lie in rings about an axis (X, Y, Z or the one its faces'
##   normals turn about, through the circumcentre of three of its corners on one level, so a part
##   swept over an arc counts, else through their mean), its levels and rings grouped by RING_GAP
##   (_cluster), evenly spaced but for one gap (its sides: a whole turn's at that spacing), with more
##   sides than its radius warrants on screen: the least sides whose chords stray SAGITTA_PX or less from the circle at
##   SCREEN_HEIGHT pixels for the camera's height in world units, never under FLOOR_SIDES: `wide=`
##   at the wide zoom (IsoCamera.MAX_ZOOM_SIZE) and `play=` at the closest zoom the model is drawn at
##   (Spec.zoom: a building, a unit's near version and a figure at IsoCamera.MIN_ZOOM_SIZE, a unit's
##   far version at BattleUnits.FAR_ZOOM, where the battle swaps it in). Its surplus is its triangles
##   times the share of its sides over `play=`, times its seen share (`surplus_wide=` the same over
##   `wide=`).
##
## **Seen**: a triangle is seen when, from some heading of HEADINGS round the model at the camera's
## pitch (IsoCamera.PITCH_DEG), it faces the camera and a ray from one of its four sample points
## towards the camera meets nothing opaque (a moving part's triangles also meet the other moving
## parts at rest; a body's do not, so what a moving part covers only at rest still counts as seen).
## A point under the ground is never seen. Separately, `fixed=` counts the triangles unseen from
## the base camera's one heading (IsoCamera.YAW_DEG), for buildings, which never turn: informative
## only, since those faces still cast shadows and a camera that turns would show them. An unseen
## triangle is put in the first kind it fits: `ground` (facing down at no heading, on the ground,
## within UNDERSIDE_GAP), `onpart` (likewise, on a part within UNDERSIDE_GAP below it), `air` (facing
## down at no heading), `inner` (of a round part, facing its axis), `buried` (its centre inside
## another part), `occluded` (the rest: behind other parts from every heading). The model's waste
## is its unseen triangles, its duplicates, its degenerate triangles and its rounds' surplus; the
## outline's share of it is counted as `ink=`, the unseen triangles the outline also carries.
##
## Each model gets one MODEL line, each finding one FIND line, both key=value (part names carry no
## space); then SUMMARY lines: the totals per kind, the top twenty models by waste and the top ten
## by body triangles. A headless run writes the flagged models (FLAG_KINDS) with each finding's
## point to FLAGS_FILE, stamped with the MD5s of the sources the findings depend on (_stamp); a
## rendered run reads it, or audits first when it is missing or its stamp differs (saying so) and
## writes it, and shoots the flagged models
## close at four headings, a marker drawn over each point through the geometry in its kind's colour
## (MARKER_COLOURS). The whole roster takes about three minutes headless. Thresholds are in model
## units (a model built for another footprint is scaled on the field).

const ClashScript := preload("res://tools/harness/scenarios/model_clash.gd")

## Heights and radii closer than this are one level and one ring of a round part, and a corner this
## close to a fitted circle is on it.
const RING_GAP := 0.002
## Corners closer than this are one point when parts are told apart.
const WELD := 0.0005
## How far an edge is shrunk at each end, and rays start off a face.
const EPS := 0.0005
## Units between the samples along an edge when its length inside another part is measured.
const EDGE_SAMPLE := 0.02
## A part floats when its lowest point is higher than this and its grown bounds meet no other's.
const FLOAT_GAP := 0.02
## A part's lowest point may dip this far under the ground.
const BELOW_SLACK := 0.01
## A down-facing triangle this close over the ground or a part is an underside on it.
const UNDERSIDE_GAP := 0.01
## Two faces closer than this along their normal, facing within COPLANAR_COS, share a plane.
const ZFIGHT_GAP := 0.001
const COPLANAR_COS := 0.99
## A piercing edge sticking out of the part it pierces by less than this is a poke.
const POKE_STUB := 0.03
## A triangle with less than this area is degenerate.
const DEGEN_AREA := 1e-8
## Headings round the model the camera looks from, at its pitch.
const HEADINGS := 16
## Degrees between a moving part's poses; a SLIDE's poses, both ends included.
const MOTION_STEP := 10.0
const SLIDE_POSES := 5
## A moving part's crossings with the body within this of its axis are a mount.
const MOUNT_RADIUS := 0.15
## The screen a round part's sides are judged on: a phone's height in pixels, the chord's stray.
const SCREEN_HEIGHT := 1080.0
const SAGITTA_PX := 0.5
## The fewest sides a round part is judged to need (docs/reference/art-style.md: 8 under 0.15).
const FLOOR_SIDES := 8
## A part needs this many triangles to be tested for being round.
const ROUND_MIN_TRIS := 12
## Rays are cast this far.
const RAY_LENGTH := 40.0
## The most hits a ray is followed through.
const MAX_HITS := 64
## Kinds of finding that flag a model for the rendered shots, each with its weight in the model's
## score; the rendered run shoots the highest-scoring model of each type (ties to the lowest
## level), the highest scores first, up to SHOT_LIMIT models. A float tagged bob or holo does not
## flag; pierce and poke do not (they are mostly mounts and need the list, not a shot).
const FLAG_KINDS := {"brush": 8, "aim": 8, "below": 6, "float": 5, "zfight": 4, "dup": 4, "seat": 2}
const SHOT_LIMIT := 40
## The rendered shots' marker colour per kind of finding.
const MARKER_COLOURS := {
	"brush": Color(1.0, 0.1, 0.1), "aim": Color(1.0, 0.1, 0.1), "seat": Color(1.0, 0.6, 0.0),
	"zfight": Color(0.0, 1.0, 1.0), "float": Color(1.0, 0.0, 1.0), "below": Color(1.0, 0.0, 1.0),
	"dup": Color(1.0, 1.0, 0.0),
}
## Where a headless run leaves the flagged models for a rendered run (tools/harness/out is gitignored).
const FLAGS_FILE := "res://tools/harness/out/model_audit.flags"
## The sources the flags file is stamped with (_stamp), all that change the findings: these and every
## script in STAMPED_DIR.
const STAMPED := [
	"res://src/game/low_poly_mesh.gd", "res://src/game/unit_models.gd", "res://src/game/building_models.gd",
	"res://src/game/surf.gd", "res://src/game/motion.gd", "res://src/game/battle_view.gd",
	"res://data/buildings.json", "res://data/units.json",
	"res://tools/harness/scenarios/model_audit.gd", "res://tools/harness/scenarios/model_clash.gd",
]
const STAMPED_DIR := "res://src/game/models"
## Contacts on record, by model label: the finding is still listed, marked known.
const KNOWN := {
	"plasma_mortar 7 obsidian":
		"the barrel brushes the loader arm at two yaws of its pitch sweep (docs/plans/model-animation-pass.md)",
}
## Physics layers: the opaque body, its holograms, the moving parts at rest.
const OPAQUE := 1
const HOLO := 2
const MOVERS := 4


## A mesh read back as a triangle soup, split into parts.
class Soup:
	var points := PackedVector3Array()
	var normals := PackedVector3Array()
	var flags := PackedInt32Array()
	var layers := PackedInt32Array()
	var outlined := PackedByteArray()
	## Per triangle: whether it has no area (DEGEN_AREA).
	var degen := PackedByteArray()
	## Per triangle: its part.
	var comp := PackedInt32Array()
	var comps := 0
	var boxes: Array[AABB] = []
	var comp_tris := PackedInt32Array()
	var comp_flags := PackedInt32Array()
	## Per part: its round axis's point and direction, its sides (0 when not round), its radius.
	var round_at := PackedVector3Array()
	var round_axis := PackedVector3Array()
	var sides := PackedInt32Array()
	var radius := PackedFloat32Array()
	## Per triangle: seen from some heading; unseen from the fixed camera.
	var seen := PackedByteArray()
	var unseen_fixed := PackedByteArray()
	var name := "body"
	## A moving part's pivot and motion; null motion for the body.
	var pivot := Vector3.ZERO
	var motion: Motion = null


## One model to audit: its label (type, level, tier, and for a unit its detail) and how it is built.
class Spec:
	var label := ""
	var kind := ""
	var type := ""
	var level := 0
	var tier := 0
	var detail := 1.0
	var size := 0
	## The closest camera size it is judged at for its rounds' sides (_specs).
	var zoom := 0.0


## The views' directions towards the camera, the fixed camera's index among them.
var _views: Array[Vector3] = []
var _fixed_view := 0
## The current model's physics space, its bodies by RID (each [soup index, triangle map]).
var _space := RID()
var _state: PhysicsDirectSpaceState3D
var _rids := {}
var _owned: Array[RID] = []
var _ray := PhysicsRayQueryParameters3D.new()
## The current model's soups: the body, then each moving part.
var _soups: Array[Soup] = []
var _clash: ClashScript
## Per model label: [Spec, Array of [kind, point]] for the flagged models.
var _flagged := {}
## The run's MODEL rows for the summary: [label, body triangles, waste].
var _rows: Array = []
var _totals := {}


func run(main: MainScript) -> void:
	_clash = ClashScript.new()
	for h: int in HEADINGS:
		var yaw := TAU * h / HEADINGS
		var pitch := deg_to_rad(-IsoCamera.PITCH_DEG)
		_views.append(Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)))
	_fixed_view = roundi(IsoCamera.YAW_DEG / 360.0 * HEADINGS) % HEADINGS
	_ray.hit_back_faces = true
	var specs := _specs(main.state.catalog)
	var stamp := _stamp()
	if harness.headless or not _flags_current(stamp):
		for spec: Spec in specs:
			var model := _build(spec)
			await _audit(spec, model)
			model.free()
		_summarise()
		_write_flags(stamp)
	else:
		_read_flags(specs)
	if not harness.headless:
		await _shoot(main)


## Every model the audit covers, in order: buildings, units, figures.
func _specs(catalog: Catalog) -> Array[Spec]:
	var specs: Array[Spec] = []
	for type: String in catalog.types():
		for level: int in range(1, catalog.max_level(type) + 1):
			var spec := Spec.new()
			spec.kind = "building"
			spec.type = type
			spec.level = level
			spec.tier = BuildingModels.tier_of(catalog, type, level)
			spec.size = catalog.size_of(type)
			spec.zoom = IsoCamera.MIN_ZOOM_SIZE
			spec.label = "%s %d %s" % [type, level, _tier_name(spec.tier)]
			specs.append(spec)
	for type: String in catalog.unit_types():
		for tier: int in Parts.Tier.values():
			for far: bool in [false, true]:
				var spec := Spec.new()
				spec.kind = "unit"
				spec.type = type
				spec.tier = tier
				spec.detail = UnitModels.FAR_DETAIL if far else 1.0
				spec.zoom = BattleUnits.FAR_ZOOM if far else IsoCamera.MIN_ZOOM_SIZE
				spec.label = "unit_%s 0 %s%s" % [type, _tier_name(tier), "_far" if far else ""]
				specs.append(spec)
	for figure: String in ["colonist", "automaton"]:
		var spec := Spec.new()
		spec.kind = "figure"
		spec.type = figure
		spec.label = "figure_%s 0 base" % figure
		spec.zoom = IsoCamera.MIN_ZOOM_SIZE
		specs.append(spec)
	return specs


func _tier_name(tier: int) -> String:
	return str(Parts.Tier.keys()[tier]).to_lower()


func _build(spec: Spec) -> Node3D:
	match spec.kind:
		"building":
			return BuildingModels.create(spec.type, spec.level, spec.size, spec.tier)
		"unit":
			return UnitModels.instantiate(UnitModels.build(spec.type, spec.tier, spec.detail))
	var p := Parts.new()
	if spec.type == "colonist":
		Figures.colonist(p.body, Vector3.ZERO, 0.0, Figures.stance())
	else:
		Figures.automaton(p.body, Vector3.ZERO, 0.0, Figures.stance())
	return BuildingModels.instantiate(p)


## Audits one model: reads it, splits it, casts the probes, says its findings and its line.
func _audit(spec: Spec, model: Node3D) -> void:
	_soups.clear()
	var outline_tris := 0
	var body := Soup.new()
	var outline_keys := {}
	var movers: Array[Node3D] = []
	for child: Node in model.get_children():
		if child is MeshInstance3D:
			var mesh := (child as MeshInstance3D).mesh
			if child.has_meta(BuildingModels.OUTLINE_META):
				outline_tris += _outline_keys(mesh, outline_keys)
			else:
				_read(mesh, body)
		elif child.has_meta(BuildingModels.MOVE_META):
			movers.append(child as Node3D)
	_mark_outlined(body, outline_keys)
	_soups.append(body)
	for m: int in movers.size():
		var soup := Soup.new()
		soup.name = "mover%d" % (m + 1)
		soup.pivot = movers[m].position
		soup.motion = movers[m].get_meta(BuildingModels.MOVE_META)
		var keys := {}
		for grandchild: Node in movers[m].get_children():
			if grandchild is MeshInstance3D:
				if grandchild.has_meta(BuildingModels.OUTLINE_META):
					outline_tris += _outline_keys((grandchild as MeshInstance3D).mesh, keys)
				else:
					_read((grandchild as MeshInstance3D).mesh, soup)
		_mark_outlined(soup, keys)
		_soups.append(soup)
	for soup: Soup in _soups:
		_split(soup)
		_find_rounds(soup)
	_make_space()
	await harness.frames(1)
	_state = PhysicsServer3D.space_get_direct_state(_space)

	var finds: Array = []
	for s: int in _soups.size():
		_visibility(s)
	var unseen := {"ground": 0, "onpart": 0, "air": 0, "inner": 0, "buried": 0, "occluded": 0}
	var ink := 0
	var unseen_fixed := 0
	var hidden_tris := 0
	for s: int in _soups.size():
		var soup := _soups[s]
		var comp_seen := PackedInt32Array()
		comp_seen.resize(soup.comps)
		var comp_live := PackedInt32Array()
		comp_live.resize(soup.comps)
		for t: int in soup.comp.size():
			if soup.degen[t]:
				continue
			comp_live[soup.comp[t]] += 1
			if soup.motion == null and soup.unseen_fixed[t]:
				unseen_fixed += 1
			if soup.seen[t]:
				comp_seen[soup.comp[t]] += 1
				continue
			unseen[_unseen_kind(s, t)] += 1
			if soup.outlined[t]:
				ink += 1
		for c: int in soup.comps:
			if comp_seen[c] == 0 and comp_live[c] > 0:
				hidden_tris += soup.comp_tris[c]
				var inside := _enclosing(s, c)
				finds.append(["hidden", _part(s, c), inside, 0, soup.comp_tris[c], soup.boxes[c].get_center() + soup.pivot])
	var crossing := _cross_body(finds)
	var body_edges := _edge_list(body) if _soups.size() > 1 else PackedInt32Array()
	for s: int in range(1, _soups.size()):
		_mover_poses(s, body_edges, finds)
	_zfight(finds)
	_floats(finds)
	var dups := 0
	var degens := 0
	for s: int in _soups.size():
		var counted := _dup_degen(s, finds)
		dups += counted.x
		degens += counted.y
	var surplus := 0.0
	var surplus_wide := 0.0
	var rounds := 0
	for s: int in _soups.size():
		var soup := _soups[s]
		for c: int in soup.comps:
			if soup.sides[c] == 0:
				continue
			rounds += 1
			var seen_share := _seen_share(soup, c)
			var play := _warranted(soup.radius[c], spec.zoom)
			var wide := _warranted(soup.radius[c], IsoCamera.MAX_ZOOM_SIZE)
			if soup.sides[c] > play:
				var extra := soup.comp_tris[c] * (1.0 - float(play) / soup.sides[c]) * seen_share
				surplus += extra
				surplus_wide += soup.comp_tris[c] * (1.0 - float(wide) / soup.sides[c]) * seen_share
				finds.append(["round", _part(s, c), "sides=%d,play=%d,wide=%d,r=%.3f" % [soup.sides[c], play, wide,
					soup.radius[c]], soup.sides[c], roundi(extra), soup.boxes[c].get_center()])
	_aim(spec, model, finds)
	_free_space()

	var body_tris := body.comp.size()
	var mover_tris := 0
	for s: int in range(1, _soups.size()):
		mover_tris += _soups[s].comp.size()
	var unseen_total := 0
	for kind: String in unseen:
		unseen_total += int(unseen[kind])
		_totals[kind] = int(_totals.get(kind, 0)) + int(unseen[kind])
	var waste := unseen_total + dups + degens + roundi(surplus)
	var kinds := _kind_split()
	var kind_counts := {}
	for f: Array in finds:
		kind_counts[f[0]] = int(kind_counts.get(f[0], 0)) + 1
		_totals["find_" + str(f[0])] = int(_totals.get("find_" + str(f[0]), 0)) + 1
	_totals["dup"] = int(_totals.get("dup", 0)) + dups
	_totals["degen"] = int(_totals.get("degen", 0)) + degens
	_totals["surplus"] = float(_totals.get("surplus", 0.0)) + surplus
	_totals["surplus_wide"] = float(_totals.get("surplus_wide", 0.0)) + surplus_wide
	_totals["ink"] = int(_totals.get("ink", 0)) + ink
	_totals["body"] = int(_totals.get("body", 0)) + body_tris + mover_tris
	_totals["outline"] = int(_totals.get("outline", 0)) + outline_tris
	_totals["hidden_tris"] = int(_totals.get("hidden_tris", 0)) + hidden_tris
	var known := ""
	for f: Array in finds:
		var tag := " known=1" if KNOWN.has(spec.label) and (f[0] == "aim" or f[0] == "brush") else ""
		known = KNOWN.get(spec.label, "") if tag != "" else known
		say("FIND model=%s kind=%s a=%s b=%s count=%d tris=%d at=%s%s" % [spec.label.replace(" ", "/"), f[0], f[1], f[2],
			f[3], f[4], _vec(f[5]), tag])
		if FLAG_KINDS.has(f[0]) and not (f[0] == "float" and (str(f[1]).contains("bob") or str(f[1]).contains("holo"))):
			if not _flagged.has(spec.label):
				_flagged[spec.label] = []
			(_flagged[spec.label] as Array).append([f[0], f[5]])
	if known != "":
		say("KNOWN model=%s: %s" % [spec.label.replace(" ", "/"), known])
	say(("MODEL model=%s body=%d movers=%d outline=%d parts=%d kinds=%s unseen=%d ground=%d onpart=%d air=%d inner=%d"
		+ " buried=%d occluded=%d ink=%d fixed=%d hidden=%d rounds=%d surplus=%d surplus_wide=%d dup=%d degen=%d waste=%d"
		+ " crossing_pairs=%d finds=%s") % [spec.label.replace(" ", "/"), body_tris, mover_tris, outline_tris,
		_part_count(), kinds, unseen_total, unseen["ground"], unseen["onpart"], unseen["air"], unseen["inner"],
		unseen["buried"], unseen["occluded"],
		ink, unseen_fixed, hidden_tris, rounds, roundi(surplus), roundi(surplus_wide), dups, degens, waste, crossing,
		_counts(kind_counts)])
	_rows.append([spec.label, body_tris + mover_tris, waste, unseen_total, roundi(surplus), outline_tris])


## Adds a mesh's triangles, every surface, to `soup`, with their flat normals, flags and layers.
func _read(mesh: Mesh, soup: Soup) -> void:
	for surface: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		for k: int in range(0, vertices.size(), 3):
			var a := vertices[k]
			var b := vertices[k + 1]
			var c := vertices[k + 2]
			soup.points.append(a)
			soup.points.append(b)
			soup.points.append(c)
			# Godot's front faces wind clockwise (LowPolyMesh._emit).
			soup.normals.append((c - a).cross(b - a).normalized())
			soup.degen.append(1 if (c - a).cross(b - a).length() * 0.5 < DEGEN_AREA else 0)
			soup.layers.append(roundi(uv2s[k].x))
			soup.flags.append(roundi(uv2s[k].y))


## Adds an outline mesh's triangles to `keys`; returns how many it has.
func _outline_keys(mesh: Mesh, keys: Dictionary) -> int:
	var count := 0
	for surface: int in mesh.get_surface_count():
		var vertices: PackedVector3Array = mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]
		for k: int in range(0, vertices.size(), 3):
			keys[_tri_key(vertices[k], vertices[k + 1], vertices[k + 2])] = true
			count += 1
	return count


func _mark_outlined(soup: Soup, keys: Dictionary) -> void:
	soup.outlined.resize(soup.normals.size())
	for t: int in soup.normals.size():
		soup.outlined[t] = 1 if keys.has(_tri_key(soup.points[t * 3], soup.points[t * 3 + 1], soup.points[t * 3 + 2])) else 0


func _q(p: Vector3) -> Vector3i:
	return Vector3i(roundi(p.x / WELD), roundi(p.y / WELD), roundi(p.z / WELD))


## A triangle's corners, welded and in order, whatever its winding.
func _tri_key(a: Vector3, b: Vector3, c: Vector3) -> Array:
	var keys: Array[Vector3i] = [_q(a), _q(b), _q(c)]
	keys.sort()
	return keys


## A triangle's corners, welded, from the least in their winding order: a face and its back face
## (a part meant to show from both sides) differ.
func _wound_key(a: Vector3, b: Vector3, c: Vector3) -> Array:
	var keys: Array[Vector3i] = [_q(a), _q(b), _q(c)]
	var first := 0
	for k: int in [1, 2]:
		if keys[k] < keys[first]:
			first = k
	return [keys[first], keys[(first + 1) % 3], keys[(first + 2) % 3]]


func _edge_key(a: Vector3i, b: Vector3i, surface: int) -> Array:
	return [a, b, surface] if a < b else [b, a, surface]


## Splits a soup into parts: triangles joined across an edge exactly two triangles of one surface
## share. Fills each part's bounds, triangles and flags.
func _split(soup: Soup) -> void:
	var count := soup.normals.size()
	var edges := {}
	for t: int in count:
		var surface := soup.layers[t] * 65536 + soup.flags[t]
		for side: int in 3:
			var a := _q(soup.points[t * 3 + side])
			var b := _q(soup.points[t * 3 + (side + 1) % 3])
			if a == b:
				continue
			var key := _edge_key(a, b, surface)
			var seen: Vector3i = edges.get(key, Vector3i(0, -1, -1))
			if seen.x == 0:
				edges[key] = Vector3i(1, t, -1)
			elif seen.x == 1:
				edges[key] = Vector3i(2, seen.y, t)
			else:
				edges[key] = Vector3i(seen.x + 1, seen.y, seen.z)
	var parent := PackedInt32Array()
	parent.resize(count)
	for t: int in count:
		parent[t] = t
	for joined: Vector3i in edges.values():
		if joined.x == 2:
			var a := _root(parent, joined.y)
			var b := _root(parent, joined.z)
			if a != b:
				parent[maxi(a, b)] = mini(a, b)
	var ids := {}
	soup.comp.resize(count)
	for t: int in count:
		var r := _root(parent, t)
		if not ids.has(r):
			ids[r] = ids.size()
			soup.boxes.append(AABB(soup.points[t * 3], Vector3.ZERO))
			soup.comp_tris.append(0)
			soup.comp_flags.append(0)
		var c: int = ids[r]
		soup.comp[t] = c
		soup.comp_tris[c] += 1
		soup.comp_flags[c] |= soup.flags[t]
		for corner: int in 3:
			soup.boxes[c] = soup.boxes[c].expand(soup.points[t * 3 + corner])
	soup.comps = ids.size()
	soup.seen.resize(count)
	soup.unseen_fixed.resize(count)


func _root(parent: PackedInt32Array, t: int) -> int:
	var r := t
	while parent[r] != r:
		r = parent[r]
	var k := t
	while parent[k] != r:
		var next := parent[k]
		parent[k] = r
		k = next
	return r


## Finds each part's round axis and sides: its vertices in rings about an axis, evenly spaced.
func _find_rounds(soup: Soup) -> void:
	soup.round_at.resize(soup.comps)
	soup.round_axis.resize(soup.comps)
	soup.sides.resize(soup.comps)
	soup.radius.resize(soup.comps)
	var corners: Array[PackedVector3Array] = []
	var normals: Array[Dictionary] = []
	for c: int in soup.comps:
		corners.append(PackedVector3Array())
		normals.append({})
	var seen := {}
	for t: int in soup.comp.size():
		var c := soup.comp[t]
		if soup.comp_tris[c] < ROUND_MIN_TRIS:
			continue
		normals[c][Vector3i((soup.normals[t] * 100.0).round())] = soup.normals[t]
		for corner: int in 3:
			var p := soup.points[t * 3 + corner]
			var key := [c, _q(p)]
			if not seen.has(key):
				seen[key] = true
				corners[c].append(p)
	for c: int in soup.comps:
		if soup.comp_tris[c] < ROUND_MIN_TRIS:
			continue
		var centre := Vector3.ZERO
		for p: Vector3 in corners[c]:
			centre += p
		centre /= corners[c].size()
		var axes: Array[Vector3] = [Vector3.UP, Vector3.RIGHT, Vector3.BACK, _normal_axis(normals[c].values())]
		for axis: Vector3 in axes:
			if axis == Vector3.ZERO:
				continue
			var on_axis := _axis_point(corners[c], centre, axis)
			var found := _rings(corners[c], on_axis, axis)
			if found.x == 0 and on_axis != centre:
				on_axis = centre
				found = _rings(corners[c], centre, axis)
			if found.x > 0:
				soup.sides[c] = int(found.x)
				soup.radius[c] = found.y
				soup.round_at[c] = on_axis
				soup.round_axis[c] = axis
				break


## The axis the normals turn about: the direction least along them (power iteration on their
## spread, the two largest directions crossed). Zero when it cannot tell.
func _normal_axis(normals: Array) -> Vector3:
	if normals.size() < 6:
		return Vector3.ZERO
	var m := Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
	for n: Vector3 in normals:
		m.x += n * n.x
		m.y += n * n.y
		m.z += n * n.z
	var first := _dominant(m, Vector3(0.3, 0.5, 0.7))
	var lambda := first.dot(m * first)
	var rest := m
	rest.x -= first * (lambda * first.x)
	rest.y -= first * (lambda * first.y)
	rest.z -= first * (lambda * first.z)
	var second := _dominant(rest, first.cross(Vector3(0.6, 0.3, -0.2)).normalized())
	var axis := first.cross(second)
	return axis.normalized() if axis.length() > 0.5 else Vector3.ZERO


func _dominant(m: Basis, start: Vector3) -> Vector3:
	var v := start.normalized()
	for k: int in 40:
		var next := m * v
		if next.length() < 1e-9:
			return v
		v = next.normalized()
	return v


## A point on the axis along `axis` that `points` turn about: on the level (by height along the axis
## from `mean`, their mean) with the most corners, the circumcentre of the corner farthest from the
## level's mean, the one farthest from that, and the third that leaves the most of the level's
## corners on the circle, trying each pair of the four corners farthest from the level's mean (one
## may be on the axis, where a part swept over an arc closes); so a part swept over an arc, whose
## mean sits off its axis, is still found.
## `mean` when no level has three corners that span a triangle.
func _axis_point(points: PackedVector3Array, mean: Vector3, axis: Vector3) -> Vector3:
	var heights := PackedFloat32Array()
	for p: Vector3 in points:
		heights.append((p - mean).dot(axis))
	var ids := _cluster(heights)
	var levels := {}
	for k: int in points.size():
		if not levels.has(ids[k]):
			levels[ids[k]] = []
		(levels[ids[k]] as Array).append(points[k])
	var level: Array = []
	for group: Array in levels.values():
		if group.size() > level.size():
			level = group
	if level.size() < 3:
		return mean
	var middle := Vector3.ZERO
	for p: Vector3 in level:
		middle += p
	middle /= level.size()
	var outer := level.duplicate()
	outer.sort_custom(func(p: Vector3, q: Vector3) -> bool:
		return p.distance_squared_to(middle) > q.distance_squared_to(middle))
	outer = outer.slice(0, 4)
	var best := mean
	var most := 0
	var bounds := AABB(level[0], Vector3.ZERO)
	for p: Vector3 in level:
		bounds = bounds.expand(p)
	for pair: Vector2i in [Vector2i(0, 1), Vector2i(0, 2), Vector2i(0, 3), Vector2i(1, 2), Vector2i(1, 3), Vector2i(2, 3)]:
		if pair.y >= outer.size():
			continue
		var fit := _circle_fit(level, bounds, outer[pair.x], outer[pair.y])
		if int(fit[1]) > most:
			most = int(fit[1])
			best = fit[0] as Vector3
	return best + axis * (mean - best).dot(axis) if most > 0 else mean


## The circumcentre through `a`, `b` and the corner of `level` that leaves the most of its corners on
## the circle (within RING_GAP), and how many: [centre, count]. A circumcentre outside the level's
## `bounds` grown by their own size (a nearly straight triple's far centre) is not taken; grown,
## since an arc under a half turn has its centre outside its own corners' bounds.
func _circle_fit(level: Array, bounds: AABB, a: Vector3, b: Vector3) -> Array:
	var near := bounds.grow(bounds.size.length())
	var best := Vector3.ZERO
	var most := 0
	for c: Vector3 in level:
		var ab := b - a
		var ac := c - a
		var n := ab.cross(ac)
		if n.length_squared() < 1e-12:
			continue
		var circumcentre := a + (n.cross(ab) * ac.length_squared() + ac.cross(n) * ab.length_squared()) \
			/ (2.0 * n.length_squared())
		if not near.has_point(circumcentre):
			continue
		var radius := circumcentre.distance_to(a)
		var on := 0
		for p: Vector3 in level:
			if absf(p.distance_to(circumcentre) - radius) <= RING_GAP:
				on += 1
		if on > most:
			most = on
			best = circumcentre
	return [best, most]


## Ids grouping `values`: sorted, cut where neighbours are more than RING_GAP apart, so a value on
## either side of a fixed bin's edge stays with its neighbours.
func _cluster(values: PackedFloat32Array) -> PackedInt32Array:
	var order: Array[Vector2] = []
	for k: int in values.size():
		order.append(Vector2(values[k], k))
	order.sort()
	var ids := PackedInt32Array()
	ids.resize(values.size())
	var id := 0
	for k: int in order.size():
		if k > 0 and order[k].x - order[k - 1].x > RING_GAP:
			id += 1
		ids[int(order[k].y)] = id
	return ids


## Whether `points` lie in rings about the line through `centre` along `axis`: grouped by their
## height along it and their distance from it (_cluster), the widest ring of at least six corners evenly spaced
## round it, but for one gap (a part swept over an arc). (sides, radius), or zeros.
func _rings(points: PackedVector3Array, centre: Vector3, axis: Vector3) -> Vector2:
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side)
	var heights := PackedFloat32Array()
	var radii := PackedFloat32Array()
	var angles := PackedFloat32Array()
	for p: Vector3 in points:
		var d := p - centre
		var h := d.dot(axis)
		var off := d - axis * h
		if off.length() < 1e-4:
			continue
		heights.append(h)
		radii.append(off.length())
		angles.append(fposmod(atan2(off.dot(up), off.dot(side)), TAU))
	var levels := {}
	var level_ids := _cluster(heights)
	for k: int in heights.size():
		if not levels.has(level_ids[k]):
			levels[level_ids[k]] = PackedInt32Array()
		levels[level_ids[k]] = (levels[level_ids[k]] as PackedInt32Array) + PackedInt32Array([k])
	var best := PackedFloat32Array()
	var best_radius := 0.0
	for members: PackedInt32Array in levels.values():
		var level_radii := PackedFloat32Array()
		for k: int in members:
			level_radii.append(radii[k])
		var ring_ids := _cluster(level_radii)
		var rings := {}
		for m: int in members.size():
			if not rings.has(ring_ids[m]):
				rings[ring_ids[m]] = []
			(rings[ring_ids[m]] as Array).append(members[m])
		for ring: Array in rings.values():
			if ring.size() < 6:
				continue
			var radius := 0.0
			for k: int in ring:
				radius += radii[k]
			radius /= ring.size()
			if radius > best_radius:
				best_radius = radius
				best = PackedFloat32Array()
				for k: int in ring:
					best.append(angles[k])
	if best.is_empty():
		return Vector2.ZERO
	best.sort()
	var gaps := PackedFloat32Array()
	for k: int in best.size():
		var next := best[(k + 1) % best.size()] + (TAU if k == best.size() - 1 else 0.0)
		gaps.append(next - best[k])
	var least := INF
	for gap: float in gaps:
		if gap > 0.002:
			least = minf(least, gap)
	if least == INF:
		return Vector2.ZERO
	var odd := 0
	for gap: float in gaps:
		if gap > 0.002 and absf(gap - least) > 0.02:
			odd += 1
	if odd > 1:
		return Vector2.ZERO
	var sides := roundi(TAU / least)
	if sides < 6:
		return Vector2.ZERO
	return Vector2(sides, best_radius)


## The least sides a round part of `radius` needs at camera size `zoom` (SAGITTA_PX on SCREEN_HEIGHT).
func _warranted(radius: float, zoom: float) -> int:
	var px := radius * SCREEN_HEIGHT / zoom
	if px <= SAGITTA_PX * 2.0:
		return FLOOR_SIDES
	return maxi(FLOOR_SIDES, ceili(PI / acos(1.0 - SAGITTA_PX / px)))


## The model's physics space: the opaque body, its holograms, the moving parts at rest.
func _make_space() -> void:
	_space = PhysicsServer3D.space_create()
	PhysicsServer3D.space_set_active(_space, true)
	_owned = [_space]
	_rids.clear()
	for s: int in _soups.size():
		var soup := _soups[s]
		var opaque := PackedInt32Array()
		var holo := PackedInt32Array()
		for t: int in soup.comp.size():
			if (soup.flags[t] & Surf.HOLO) != 0:
				holo.append(t)
			else:
				opaque.append(t)
		var at := Transform3D(Basis.IDENTITY, soup.pivot)
		if s == 0:
			_add_body(s, opaque, OPAQUE, at)
			_add_body(s, holo, HOLO, at)
		else:
			var all := opaque.duplicate()
			all.append_array(holo)
			_add_body(s, all, MOVERS, at)


func _add_body(s: int, triangles: PackedInt32Array, layer: int, at: Transform3D) -> void:
	if triangles.is_empty():
		return
	var soup := _soups[s]
	var faces := PackedVector3Array()
	for t: int in triangles:
		faces.append(soup.points[t * 3])
		faces.append(soup.points[t * 3 + 1])
		faces.append(soup.points[t * 3 + 2])
	var shape := PhysicsServer3D.concave_polygon_shape_create()
	PhysicsServer3D.shape_set_data(shape, {"faces": faces, "backface_collision": true})
	var body := PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_STATIC)
	PhysicsServer3D.body_add_shape(body, shape)
	PhysicsServer3D.body_set_collision_layer(body, layer)
	PhysicsServer3D.body_set_state(body, PhysicsServer3D.BODY_STATE_TRANSFORM, at)
	PhysicsServer3D.body_set_space(body, _space)
	_rids[body] = [s, triangles]
	_owned.append(shape)
	_owned.append(body)


func _free_space() -> void:
	for k: int in range(_owned.size() - 1, -1, -1):
		PhysicsServer3D.free_rid(_owned[k])
	_owned.clear()
	_rids.clear()
	_state = null


## Whether anything on `mask` lies between `from` and `to`.
func _blocked(from: Vector3, to: Vector3, mask: int) -> bool:
	_ray.from = from
	_ray.to = to
	_ray.collision_mask = mask
	return not _state.intersect_ray(_ray).is_empty()


## Every hit from `from` to `to` on `mask`, in order: each [soup, triangle, position].
func _hits(from: Vector3, to: Vector3, mask: int) -> Array:
	var hits: Array = []
	var dir := (to - from).normalized()
	_ray.collision_mask = mask
	_ray.from = from
	_ray.to = to
	for k: int in MAX_HITS:
		var hit := _state.intersect_ray(_ray)
		if hit.is_empty():
			break
		var entry: Array = _rids.get(hit["rid"], [])
		var position: Vector3 = hit["position"]
		if not entry.is_empty():
			var map: PackedInt32Array = entry[1]
			hits.append([entry[0], map[int(hit["face_index"])], position])
		_ray.from = position + dir * 1e-5
		if (_ray.from - from).length() >= (to - from).length():
			break
	return hits


## Which triangles of soup `s` are seen (from some heading) and which are unseen from the fixed one.
func _visibility(s: int) -> void:
	var soup := _soups[s]
	var mask := OPAQUE if s == 0 else OPAQUE | MOVERS
	for t: int in soup.comp.size():
		var n := soup.normals[t]
		var a := soup.points[t * 3] + soup.pivot
		var b := soup.points[t * 3 + 1] + soup.pivot
		var c := soup.points[t * 3 + 2] + soup.pivot
		var samples: Array[Vector3] = [(a + b + c) / 3.0, a * 0.8 + (b + c) * 0.1, b * 0.8 + (a + c) * 0.1,
			c * 0.8 + (a + b) * 0.1]
		soup.unseen_fixed[t] = 0 if _seen_from(samples, n, _views[_fixed_view], mask) else 1
		var seen := soup.unseen_fixed[t] == 0
		if not seen:
			for h: int in HEADINGS:
				if h != _fixed_view and _seen_from(samples, n, _views[h], mask):
					seen = true
					break
		soup.seen[t] = 1 if seen else 0


func _seen_from(samples: Array[Vector3], n: Vector3, view: Vector3, mask: int) -> bool:
	if n.dot(view) <= 0.02:
		return false
	for p: Vector3 in samples:
		var from := p + n * EPS
		if from.y < -EPS:
			continue
		if not _blocked(from, from + view * RAY_LENGTH, mask):
			return true
	return false


## The kind of unseen triangle `t` of soup `s` (the class comment's order).
func _unseen_kind(s: int, t: int) -> String:
	var soup := _soups[s]
	var n := soup.normals[t]
	var centre := (soup.points[t * 3] + soup.points[t * 3 + 1] + soup.points[t * 3 + 2]) / 3.0 + soup.pivot
	var faces_any := false
	for view: Vector3 in _views:
		if n.dot(view) > 0.02:
			faces_any = true
			break
	if not faces_any:
		if centre.y <= UNDERSIDE_GAP:
			return "ground"
		if _blocked(centre - n * EPS, centre + Vector3.DOWN * (UNDERSIDE_GAP + EPS), OPAQUE | HOLO | MOVERS):
			return "onpart"
		return "air"
	var c := soup.comp[t]
	if soup.sides[c] > 0:
		var axis := soup.round_axis[c]
		var d := centre - soup.pivot - soup.round_at[c]
		var radial := d - axis * d.dot(axis)
		if radial.dot(n) < 0.0:
			return "inner"
	var inside := _inside(centre - n * EPS)
	for key: Array in inside:
		if not (key[0] == s and key[1] == c):
			return "buried"
	return "occluded"


## The parts `point` (model space) is inside: rays along +X and +Z both cross them an odd number of
## times. Each [soup, part].
func _inside(point: Vector3) -> Array:
	var counts := {}
	for dir: Vector3 in [Vector3.RIGHT, Vector3.BACK]:
		var odd := {}
		for hit: Array in _hits(point, point + dir * RAY_LENGTH, OPAQUE | HOLO | MOVERS):
			var s: int = hit[0]
			var key := [s, _soups[s].comp[int(hit[1])]]
			odd[key] = not bool(odd.get(key, false))
		for key: Array in odd:
			if odd[key]:
				counts[key] = int(counts.get(key, 0)) + 1
	var inside: Array = []
	for key: Array in counts:
		if counts[key] == 2:
			inside.append(key)
	return inside


## The part enclosing part `c` of soup `s`'s centre, by name, or "-".
func _enclosing(s: int, c: int) -> String:
	for key: Array in _inside(_soups[s].boxes[c].get_center() + _soups[s].pivot):
		if not (key[0] == s and key[1] == c):
			return _part(int(key[0]), int(key[1]))
	return "-"


## The body's parts crossing each other: per pair, the edges crossing and the length inside each
## other; a pair with an edge piercing is a finding. Returns the crossing pairs.
func _cross_body(finds: Array) -> int:
	var soup := _soups[0]
	var pairs := {}
	var pierces := {}
	var stubs := {}
	var points := {}
	var done := {}
	for t: int in soup.comp.size():
		var a := soup.comp[t]
		for side: int in 3:
			var from := soup.points[t * 3 + side]
			var to := soup.points[t * 3 + (side + 1) % 3]
			var key := [a, _edge_key(_q(from), _q(to), 0)]
			if done.has(key) or from.distance_to(to) < 4.0 * EPS:
				continue
			done[key] = true
			var dir := (to - from).normalized()
			var per := {}
			var first := {}
			var last := {}
			for hit: Array in _hits(from + dir * EPS, to - dir * EPS, OPAQUE | HOLO):
				var b := soup.comp[int(hit[1])]
				if b == a:
					continue
				per[b] = int(per.get(b, 0)) + 1
				var position: Vector3 = hit[2]
				if not first.has(b):
					first[b] = position
				last[b] = position
				var pair := Vector2i(mini(a, b), maxi(a, b))
				if not points.has(pair):
					points[pair] = hit[2]
			for b: int in per:
				var pair := Vector2i(mini(a, b), maxi(a, b))
				pairs[pair] = int(pairs.get(pair, 0)) + int(per[b])
				if int(per[b]) >= 2 and not _inside_part(from, 0, b) and not _inside_part(to, 0, b):
					pierces[pair] = int(pierces.get(pair, 0)) + 1
					var stub := minf(from.distance_to(first[b]), to.distance_to(last[b]))
					stubs[pair] = minf(float(stubs.get(pair, INF)), stub)
	for pair: Vector2i in pierces:
		var depth := "in=%.2f/%.2f" % [_length_inside(0, pair.x, pair.y), _length_inside(0, pair.y, pair.x)]
		var stub := float(stubs[pair])
		finds.append(["poke" if stub < POKE_STUB else "pierce", _part(0, pair.x) + "," + depth + ",stub=%.3f" % stub,
			_part(0, pair.y), int(pierces[pair]), int(pairs[pair]), points[pair]])
	return pairs.size()


func _inside_part(point: Vector3, s: int, c: int) -> bool:
	for key: Array in _inside(point):
		if key[0] == s and key[1] == c:
			return true
	return false


## The length of part `a`'s edges (soup `s`) inside part `b`, sampled every EDGE_SAMPLE.
func _length_inside(s: int, a: int, b: int) -> float:
	var soup := _soups[s]
	var box := soup.boxes[b].grow(EPS)
	var length := 0.0
	var done := {}
	for t: int in soup.comp.size():
		if soup.comp[t] != a:
			continue
		for side: int in 3:
			var from := soup.points[t * 3 + side]
			var to := soup.points[t * 3 + (side + 1) % 3]
			var key := _edge_key(_q(from), _q(to), 0)
			if done.has(key):
				continue
			done[key] = true
			var steps := maxi(1, ceili(from.distance_to(to) / EDGE_SAMPLE))
			for k: int in steps:
				var p := from.lerp(to, (k + 0.5) / steps)
				if box.has_point(p) and _inside_part(p, s, b):
					length += from.distance_to(to) / steps
	return length


## A moving part's poses against the body: per pair of its part and a body part, the poses touching,
## its edges cast against the body and the body's edges against it posed (into its rest space, by the
## pose's inverse, so the space stays still), and a body part whose corner lies inside it posed (one
## wholly inside crosses no edge): a brush when it does not touch at rest (a finding);
## touching at rest, a mount when every crossing lies within MOUNT_RADIUS of the axis, else a seat
## (a finding).
func _mover_poses(s: int, body_edges: PackedInt32Array, finds: Array) -> void:
	var soup := _soups[s]
	var body := _soups[0]
	var poses := _poses(soup.motion)
	var touched := {}
	var at_rest := {}
	var far := {}
	var where := {}
	var edges := _edge_list(soup)
	var body_first := PackedInt32Array()
	body_first.resize(body.comps)
	body_first.fill(-1)
	for t: int in body.comp.size():
		if body_first[body.comp[t]] < 0:
			body_first[body.comp[t]] = t * 3
	var rest_box := AABB(soup.boxes[0].position, soup.boxes[0].size)
	for c: int in soup.comps:
		rest_box = rest_box.merge(soup.boxes[c])
	rest_box.position += soup.pivot
	for pose: Transform3D in poses:
		var at := Transform3D(Basis.IDENTITY, soup.pivot) * pose
		var moved := at * Transform3D(Basis.IDENTITY, -soup.pivot)
		var back := moved.affine_inverse()
		var hit_now := {}
		var crossings: Array = []
		for e: int in range(0, edges.size(), 2):
			var from := at * soup.points[edges[e]]
			var to := at * soup.points[edges[e + 1]]
			if from.distance_to(to) < 4.0 * EPS:
				continue
			var dir := (to - from).normalized()
			var mine := soup.comp[edges[e] / 3]
			for hit: Array in _hits(from + dir * EPS, to - dir * EPS, OPAQUE | HOLO):
				crossings.append([Vector2i(mine, body.comp[int(hit[1])]), hit[2]])
		var posed_box := (moved * rest_box).grow(EPS)
		# A body part wholly inside the posed part crosses no edge either way: one corner of it inside.
		for c: int in body.comps:
			if not posed_box.intersects(body.boxes[c]):
				continue
			var corner := body.points[body_first[c]]
			for key: Array in _inside(back * corner):
				if int(key[0]) == s:
					crossings.append([Vector2i(int(key[1]), c), corner])
		for e: int in range(0, body_edges.size(), 2):
			var from := body.points[body_edges[e]]
			var to := body.points[body_edges[e + 1]]
			if from.distance_to(to) < 4.0 * EPS or not posed_box.intersects(AABB(from, Vector3.ZERO).expand(to)):
				continue
			var dir := (to - from).normalized()
			for hit: Array in _hits(back * (from + dir * EPS), back * (to - dir * EPS), MOVERS):
				if int(hit[0]) == s:
					crossings.append([Vector2i(soup.comp[int(hit[1])], body.comp[body_edges[e] / 3]), moved * (hit[2] as Vector3)])
		for crossing: Array in crossings:
			var pair: Vector2i = crossing[0]
			var position: Vector3 = crossing[1]
			hit_now[pair] = true
			var off := position - soup.pivot
			var away := (off - soup.motion.axis * off.dot(soup.motion.axis)).length()
			if away > float(far.get(pair, -1.0)):
				far[pair] = away
				where[pair] = position
		for pair: Vector2i in hit_now:
			touched[pair] = int(touched.get(pair, 0)) + 1
			if pose == Transform3D.IDENTITY:
				at_rest[pair] = true
	for pair: Vector2i in touched:
		var kind := "brush"
		if at_rest.has(pair):
			kind = "mount" if float(far[pair]) <= MOUNT_RADIUS else "seat"
		finds.append([kind, _part(s, pair.x), _part(0, pair.y) + ",of=%d,away=%.2f" % [poses.size(), float(far[pair])],
			int(touched[pair]), soup.comp_tris[pair.x], where[pair]])


## A soup's distinct edges, each part's own, as pairs of corner indices.
func _edge_list(soup: Soup) -> PackedInt32Array:
	var done := {}
	var edges := PackedInt32Array()
	for t: int in soup.comp.size():
		for side: int in 3:
			var i := t * 3 + side
			var j := t * 3 + (side + 1) % 3
			var key := _edge_key(_q(soup.points[i]), _q(soup.points[j]), soup.comp[t])
			if not done.has(key):
				done[key] = true
				edges.append(i)
				edges.append(j)
	return edges


## A moving part's poses about its pivot: at rest and every MOTION_STEP degrees of a SPIN's turn, a
## SWING from -amplitude to +amplitude every MOTION_STEP both ends included, a SLIDE at SLIDE_POSES.
func _poses(motion: Motion) -> Array[Transform3D]:
	var poses: Array[Transform3D] = [Transform3D.IDENTITY]
	match motion.kind:
		Motion.Kind.SPIN:
			for k: int in range(1, roundi(360.0 / MOTION_STEP)):
				poses.append(Transform3D(Basis(motion.axis, deg_to_rad(MOTION_STEP * k)), Vector3.ZERO))
		Motion.Kind.SWING:
			var angle := -motion.amplitude
			while angle < motion.amplitude:
				if absf(angle) > 0.001:
					poses.append(Transform3D(Basis(motion.axis, deg_to_rad(angle)), Vector3.ZERO))
				angle += MOTION_STEP
			poses.append(Transform3D(Basis(motion.axis, deg_to_rad(motion.amplitude)), Vector3.ZERO))
		_:
			for k: int in SLIDE_POSES:
				var u := 2.0 * k / (SLIDE_POSES - 1) - 1.0
				if absf(u) > 0.001:
					poses.append(Transform3D(Basis.IDENTITY, motion.axis * motion.amplitude * u))
	return poses


## Seen triangles with another part's triangle on their plane, facing the same way, per pair.
func _zfight(finds: Array) -> void:
	var pairs := {}
	var where := {}
	for s: int in _soups.size():
		var soup := _soups[s]
		var mask := OPAQUE | HOLO if s == 0 else OPAQUE | HOLO | MOVERS
		for t: int in soup.comp.size():
			if not soup.seen[t]:
				continue
			var n := soup.normals[t]
			var centre := (soup.points[t * 3] + soup.points[t * 3 + 1] + soup.points[t * 3 + 2]) / 3.0 + soup.pivot
			for hit: Array in _hits(centre + n * ZFIGHT_GAP, centre - n * ZFIGHT_GAP, mask):
				var o: int = hit[0]
				var other := _soups[o]
				var c := other.comp[int(hit[1])]
				if (o == s and c == soup.comp[t]) or other.normals[int(hit[1])].dot(n) < COPLANAR_COS:
					continue
				var key := [s, soup.comp[t], o, c]
				pairs[key] = int(pairs.get(key, 0)) + 1
				where[key] = centre
	for key: Array in pairs:
		finds.append(["zfight", _part(int(key[0]), int(key[1])), _part(int(key[2]), int(key[3])), int(pairs[key]),
			int(pairs[key]), where[key]])


## Parts whose lowest point is over FLOAT_GAP up and whose grown bounds meet no other part's;
## parts under the ground.
func _floats(finds: Array) -> void:
	var boxes: Array[AABB] = []
	var names: Array[Vector2i] = []
	for s: int in _soups.size():
		for c: int in _soups[s].comps:
			var box := _soups[s].boxes[c]
			boxes.append(AABB(box.position + _soups[s].pivot, box.size))
			names.append(Vector2i(s, c))
	for k: int in boxes.size():
		var s := names[k].x
		var c := names[k].y
		if _all_degen(_soups[s], c):
			continue
		if boxes[k].position.y < -BELOW_SLACK:
			finds.append(["below", _part(s, c), "low=%.3f" % boxes[k].position.y, 1, _soups[s].comp_tris[c],
				boxes[k].get_center()])
		if boxes[k].position.y <= FLOAT_GAP:
			continue
		var grown := boxes[k].grow(FLOAT_GAP)
		var alone := true
		for j: int in boxes.size():
			if j != k and grown.intersects(boxes[j]):
				alone = false
				break
		if alone:
			var tags := ""
			if (_soups[s].comp_flags[c] & Surf.BOB) != 0:
				tags += ",bob"
			if (_soups[s].comp_flags[c] & Surf.HOLO) != 0:
				tags += ",holo"
			finds.append(["float", _part(s, c) + tags, "low=%.3f" % boxes[k].position.y, 1, _soups[s].comp_tris[c],
				boxes[k].get_center()])


## Duplicate and degenerate triangles of soup `s`: (duplicates, degenerates); a finding per part
## that has any.
func _dup_degen(s: int, finds: Array) -> Vector2i:
	var soup := _soups[s]
	var seen := {}
	var dups := {}
	var degens := {}
	var total := Vector2i.ZERO
	for t: int in soup.comp.size():
		var a := soup.points[t * 3]
		var b := soup.points[t * 3 + 1]
		var c := soup.points[t * 3 + 2]
		var comp := soup.comp[t]
		if (b - a).cross(c - a).length() * 0.5 < DEGEN_AREA:
			degens[comp] = int(degens.get(comp, 0)) + 1
			total.y += 1
			continue
		var key := _wound_key(a, b, c)
		if seen.has(key):
			dups[comp] = int(dups.get(comp, 0)) + 1
			total.x += 1
		else:
			seen[key] = comp
	for comp: int in dups:
		finds.append(["dup", _part(s, comp), "-", int(dups[comp]), int(dups[comp]),
			soup.boxes[comp].get_center() + soup.pivot])
	for comp: int in degens:
		finds.append(["degen", _part(s, comp), "-", int(degens[comp]), int(degens[comp]),
			soup.boxes[comp].get_center() + soup.pivot])
	return total


func _all_degen(soup: Soup, c: int) -> bool:
	for t: int in soup.comp.size():
		if soup.comp[t] == c and not soup.degen[t]:
			return false
	return true


func _seen_share(soup: Soup, c: int) -> float:
	var seen := 0
	for t: int in soup.comp.size():
		if soup.comp[t] == c and soup.seen[t]:
			seen += 1
	return float(seen) / maxi(1, soup.comp_tris[c])


## An aiming part's pitch sweep against the other moving parts, as model_clash reads and sweeps it:
## a finding per moving part it touches.
func _aim(spec: Spec, model: Node3D, finds: Array) -> void:
	var body := ClashScript.Shape.new()
	var parts: Array[ClashScript.Shape] = []
	var spins := {}
	var any := false
	for child: Node in model.get_children():
		if child is MeshInstance3D and not child.has_meta(BuildingModels.OUTLINE_META):
			_clash._read((child as MeshInstance3D).mesh, body, spins)
		elif child.has_meta(BuildingModels.MOVE_META):
			var part := ClashScript.Shape.new()
			part.motion = child.get_meta(BuildingModels.MOVE_META)
			part.pivot = (child as Node3D).position
			if child.has_meta(BuildingModels.RIDES_META):
				part.carrier = parts[int(child.get_meta(BuildingModels.RIDES_META))]
			if child.has_meta(BuildingModels.SOCKETS_META):
				var sockets: Dictionary = child.get_meta(BuildingModels.SOCKETS_META)
				part.aims = sockets.has("muzzle")
				if part.aims and sockets.has("trunnion"):
					_clash._travel(part, spec.type, sockets["muzzle"], sockets["trunnion"])
					any = true
			for grandchild: Node in child.get_children():
				if grandchild is MeshInstance3D and not grandchild.has_meta(BuildingModels.OUTLINE_META):
					_clash._read((grandchild as MeshInstance3D).mesh, part)
			parts.append(part)
	if not any:
		return
	for i: int in parts.size():
		if not parts[i].aims or parts[i].pitches.size() <= 1:
			continue
		var tally := {}
		_clash._pitch_sweep(parts[i], parts, tally)
		var turner := parts[i].carrier
		for k: Variant in tally:
			if typeof(k) != TYPE_INT:
				continue
			var touching: int = tally[k]
			# The part that turns it carries it: a mount at every pose, as model_clash says.
			if touching == 0 or parts[int(k)] == turner:
				continue
			finds.append(["aim", "mover%d" % (i + 1), "mover%d,of=%d" % [int(k) + 1, int(tally["poses"])], touching, 0,
				parts[i].pivot + parts[i].trunnion])


## A part's name: its soup, index, bounds' centre and size in model space, triangles.
func _part(s: int, c: int) -> String:
	var soup := _soups[s]
	var box := soup.boxes[c]
	return "%s#%d[c=%s,s=%s,%dt,%s]" % [soup.name, c, _vec(box.get_center() + soup.pivot), _vec(box.size),
		soup.comp_tris[c], _layer_name(soup, c)]


func _layer_name(soup: Soup, c: int) -> String:
	for t: int in soup.comp.size():
		if soup.comp[t] == c:
			var layer := soup.layers[t]
			return str(MaterialKit.LAYERS[layer]) if layer >= 0 and layer < MaterialKit.LAYERS.size() else str(layer)
	return "?"


func _vec(v: Vector3) -> String:
	return "(%.2f,%.2f,%.2f)" % [v.x, v.y, v.z]


func _part_count() -> int:
	var count := 0
	for soup: Soup in _soups:
		count += soup.comps
	return count


## The model's triangles by kind of part: round, box (up to 30 triangles), flat (one plane), other.
func _kind_split() -> String:
	var split := {"round": 0, "box": 0, "flat": 0, "other": 0}
	for soup: Soup in _soups:
		var first := {}
		var flat := {}
		for t: int in soup.comp.size():
			var c := soup.comp[t]
			if not first.has(c):
				first[c] = soup.normals[t]
				flat[c] = true
			elif (first[c] as Vector3).dot(soup.normals[t]) < 0.999:
				flat[c] = false
		for c: int in soup.comps:
			var kind := "other"
			if soup.sides[c] > 0:
				kind = "round"
			elif flat.get(c, false):
				kind = "flat"
			elif soup.comp_tris[c] <= 30:
				kind = "box"
			split[kind] = int(split[kind]) + soup.comp_tris[c]
	return "round:%d,box:%d,flat:%d,other:%d" % [split["round"], split["box"], split["flat"], split["other"]]


func _counts(counts: Dictionary) -> String:
	var said := PackedStringArray()
	for kind: String in counts:
		said.append("%s:%d" % [kind, counts[kind]])
	return ",".join(said) if not said.is_empty() else "-"


## The run's totals, the top twenty models by waste and the top ten by triangles.
func _summarise() -> void:
	var said := PackedStringArray()
	for key: String in _totals:
		said.append("%s=%d" % [key, roundi(float(_totals[key]))])
	say("SUMMARY totals models=%d %s" % [_rows.size(), " ".join(said)])
	var by_waste := _rows.duplicate()
	by_waste.sort_custom(func(a: Array, b: Array) -> bool: return _ranks_before(a, b, 2))
	for k: int in mini(20, by_waste.size()):
		var row: Array = by_waste[k]
		say("SUMMARY waste rank=%d model=%s waste=%d tris=%d unseen=%d surplus=%d outline=%d" % [k + 1,
			str(row[0]).replace(" ", "/"), row[2], row[1], row[3], row[4], row[5]])
	var by_total := _rows.duplicate()
	by_total.sort_custom(func(a: Array, b: Array) -> bool: return _ranks_before(a, b, 1))
	for k: int in mini(10, by_total.size()):
		var row: Array = by_total[k]
		say("SUMMARY total rank=%d model=%s tris=%d waste=%d outline=%d" % [k + 1, str(row[0]).replace(" ", "/"), row[1],
			row[2], row[5]])
	say("SUMMARY flagged=%d models (kinds %s)" % [_flagged.size(), ",".join(FLAG_KINDS.keys())])


## Whether summary row `a` ranks before `b` by column `column`, highest first, ties by label.
func _ranks_before(a: Array, b: Array, column: int) -> bool:
	return int(a[column]) > int(b[column]) or (int(a[column]) == int(b[column]) and str(a[0]) < str(b[0]))


## The model sources' stamp: the MD5 of their MD5s (STAMPED and every script under STAMPED_DIR).
func _stamp() -> String:
	var paths := PackedStringArray(STAMPED)
	for file: String in DirAccess.get_files_at(STAMPED_DIR):
		if file.ends_with(".gd"):
			paths.append(STAMPED_DIR.path_join(file))
	paths.sort()
	var sums := PackedStringArray()
	for path: String in paths:
		sums.append(FileAccess.get_md5(path))
	return "".join(sums).md5_text()


## Whether FLAGS_FILE was written from the model sources as they are now (its first line, `stamp`),
## saying why not when it was not.
func _flags_current(stamp: String) -> bool:
	if not FileAccess.file_exists(FLAGS_FILE):
		say("no %s: auditing before the shots" % FLAGS_FILE)
		return false
	var file := FileAccess.open(FLAGS_FILE, FileAccess.READ)
	var first := file.get_line()
	file.close()
	if first != "stamp " + stamp:
		say("%s is stale (its stamp %s, the model sources' %s): auditing before the shots" % [FLAGS_FILE,
			first.trim_prefix("stamp "), stamp])
		return false
	return true


## Writes the flagged models, each with its findings' kinds and points, for a rendered run, under its
## `stamp` line.
func _write_flags(stamp: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FLAGS_FILE).get_base_dir())
	var file := FileAccess.open(FLAGS_FILE, FileAccess.WRITE)
	if file == null:
		say("could not write %s" % FLAGS_FILE)
		return
	file.store_line("stamp " + stamp)
	for label: String in _flagged:
		var points := PackedStringArray()
		for entry: Array in _flagged[label]:
			var p: Vector3 = entry[1]
			points.append("%s:%f:%f:%f" % [entry[0], p.x, p.y, p.z])
		file.store_line("%s\t%s" % [label, ";".join(points)])
	file.close()
	say("wrote %d flagged models to %s" % [_flagged.size(), FLAGS_FILE])


func _read_flags(specs: Array[Spec]) -> void:
	var by_label := {}
	for spec: Spec in specs:
		by_label[spec.label] = spec
	var file := FileAccess.open(FLAGS_FILE, FileAccess.READ)
	while not file.eof_reached():
		var line := file.get_line()
		if line == "" or line.begins_with("stamp "):
			continue
		var fields := line.split("\t")
		var entries: Array = []
		for item: String in fields[1].split(";"):
			var bits := item.split(":")
			entries.append([bits[0], Vector3(bits[1].to_float(), bits[2].to_float(), bits[3].to_float())])
		if by_label.has(fields[0]):
			_flagged[fields[0]] = entries
	say("read %d flagged models from %s" % [_flagged.size(), FLAGS_FILE])


## Shoots the flagged models (FLAG_KINDS: the best of each type, up to SHOT_LIMIT) close at four headings,
## a marker over each finding's point in its kind's colour.
func _shoot(main: MainScript) -> void:
	var specs := {}
	for spec: Spec in _specs(main.state.catalog):
		specs[spec.label] = spec
	var best := {}
	for label: String in _flagged:
		var type := label.get_slice(" ", 0)
		if not best.has(type) or _score(label) > _score(best[type]):
			best[type] = label
	var labels: Array = best.values()
	labels.sort_custom(_more_findings)
	say("shooting %d of %d flagged models, one a type" % [mini(SHOT_LIMIT, labels.size()), _flagged.size()])
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var grid: Vector2i = main.state.catalog.grid_size
	var spot := main.base_view.cell_to_world(grid / 2, 1)
	var dots := {}
	for kind: String in MARKER_COLOURS:
		var marker := StandardMaterial3D.new()
		marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		marker.albedo_color = MARKER_COLOURS[kind]
		marker.no_depth_test = true
		var dot := SphereMesh.new()
		dot.radius = 0.035
		dot.height = 0.07
		dot.material = marker
		dots[kind] = dot
	for k: int in mini(SHOT_LIMIT, labels.size()):
		var label: String = labels[k]
		var spec: Spec = specs[label]
		var model := _build(spec)
		var kinds := {}
		for entry: Array in _flagged[label]:
			var mark := MeshInstance3D.new()
			mark.mesh = dots.get(entry[0], dots["brush"])
			mark.position = entry[1]
			mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			model.add_child(mark)
			kinds[entry[0]] = true
		var holder := Node3D.new()
		holder.position = spot
		holder.scale = model.scale
		model.scale = Vector3.ONE
		holder.add_child(model)
		main.add_child(holder)
		var bounds := _bounds(model)
		var size := clampf(maxf(bounds.size.y, maxf(bounds.size.x, bounds.size.z)) * holder.scale.x * 1.5, 1.5, 9.0)
		say("shooting %s (%s), %d marker(s), camera size %.1f" % [label, ",".join(kinds.keys()),
			(_flagged[label] as Array).size(), size])
		for heading: int in 4:
			holder.rotation.y = deg_to_rad(90.0 * heading)
			frame_world(main, size, spot + Vector3(0, bounds.get_center().y * holder.scale.y, 0))
			await frames(3)
			await screenshot("%s-h%d" % [label.replace(" ", "-"), heading * 90])
		holder.free()


func _more_findings(a: String, b: String) -> bool:
	return _score(a) > _score(b) or (_score(a) == _score(b) and a < b)


## A flagged model's score: its findings' weights (FLAG_KINDS) summed.
func _score(label: String) -> int:
	var score := 0
	for entry: Array in _flagged[label]:
		score += int(FLAG_KINDS.get(entry[0], 0))
	return score


## A model's bounds in its own space: its meshes', each moving part's at rest.
func _bounds(model: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for child: Node in model.get_children():
		var meshes: Array[MeshInstance3D] = []
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)
		elif child is Node3D:
			for grandchild: Node in child.get_children():
				if grandchild is MeshInstance3D:
					meshes.append(grandchild as MeshInstance3D)
		for mesh: MeshInstance3D in meshes:
			if mesh.mesh is SphereMesh:
				continue
			var at := (mesh.get_parent() as Node3D).transform * mesh.get_aabb() if mesh.get_parent() != model \
				else mesh.get_aabb()
			box = at if first else box.merge(at)
			first = false
	return box
