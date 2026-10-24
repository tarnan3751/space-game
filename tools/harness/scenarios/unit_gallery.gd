extends HarnessScenario
## The unit gallery (docs/reference/art-style.md, **Units**): every unit type in the catalog's
## order (UnitModels), each on a concrete pad, in five rows, one per tier, Base nearest the screen's
## bottom and each higher tier a row further back, a level 1 Cadet Academy (a Base-tier 3x3) at the
## end of each row for scale. The base's own views are hidden; the units are turned a little off the
## camera so their depth shows. A unit has no moving part (UnitModels.MAX_MOVING); the gunship's
## rotors are tagged with LowPolyMesh.spin and spun by the shaders. Any moving part a model did have
## the scenario would turn itself, each frame, as BuildingView turns a building's.
##
## Checks every type at every tier: the triangles (the body and the moving parts) within its
## budget (BUDGETS); at most UnitModels.MAX_MOVING moving parts and one body instance, each with its
## outline beside it on the ink material casting no shadow; every vertex's kit layer within the kit;
## its extent within SIZE_SLACK of the size table (SIZES: height, width across x, length along z, a
## spinning part's whole round included, about its pivot); a flying unit's lowest point within
## SIZE_SLACK of its hover height; and that no point, with BOB's lift taken off where it bobs, dips below its pad.
## Each unit's line says its triangles, instances and extent. It also logs a seated colonist's
## triangles with and without its legs (UnitModels.pilot leaves them out).
## Rendered, the screenshots, each a different frame, each checked in both modes to have every unit
## showing on the screen and clear of the HUD's Build, Template base and Reset base buttons:
## - "rows-24": the five rows at camera size 24, the gameplay view: each unit's silhouette, and the
##   tiers side by side.
## - "<tier>-10-1", "<tier>-10-2": each tier's row alone at size 10, in two halves.
## - "<type>-base-4", "<type>-crown-4": each unit alone at size 4 at Base and at Crown (under the
##   camera's own closest zoom, set directly): the forms, the paint and the pilots.
## - "backs-10-1", "backs-10-2": the Base row alone at size 10 in two halves, every unit turned 180
##   degrees.

## Body and moving parts' triangles a unit may have (a study value; step 5 fixes the real one).
const BUDGETS := {
	"ranger": 1800, "breacher": 1800, "jet_trooper": 1800, "brawler": 1800,
	"dune_runner": 2200, "skimmer": 2200, "hover_tank": 2200,
	"siege_walker": 3000, "gunship": 2600, "bomber": 2600, "titan": 4500,
}
## [height, width across x, length along z, hover] per type, in world units, the brief's size
## table; 0 where it gives none. A hovering unit's height is from its lowest point, its hover that
## lowest point over the ground.
const SIZES := {
	"ranger": [0.8, 0.0, 0.0, 0.0],
	"breacher": [0.85, 0.0, 0.0, 0.0],
	"jet_trooper": [0.8, 0.0, 0.0, 0.5],
	"brawler": [1.0, 0.0, 0.0, 0.0],
	"dune_runner": [0.7, 0.6, 1.0, 0.0],
	"skimmer": [0.0, 0.6, 0.6, 0.6],
	"siege_walker": [1.4, 1.0, 0.0, 0.0],
	"hover_tank": [0.8, 0.9, 1.3, 0.0],
	"titan": [2.5, 1.8, 0.0, 0.0],
	"gunship": [0.0, 1.6, 1.2, 1.2],
	"bomber": [0.0, 1.8, 1.0, 1.6],
}
## How far an extent may be from the table's, as a share of it.
const SIZE_SLACK := 0.2
## As effects.gdshaderinc: BOB's lift.
const BOB_HEIGHT := 0.08
## How far a point may dip under its pad's top.
const GROUND_SLACK := 0.005
const PAD_HEIGHT := 0.06
## The space between two pads along a row, the depth between the rows and how far past the last
## pad the academy's centre stands.
const GAP := 0.45
const ROW_DEPTH := 4.2
const ACADEMY_GAP := 2.4
## Degrees the units are turned from facing the camera: a three-quarter view.
const TURN := 25.0
const SETTLE_SECONDS := 0.5
const SETTLE_FRAMES := 10

var _row_nodes: Array[Node3D] = []
## The units per tier row, Base first, in the catalog's order.
var _rows: Array[Array] = []
## Every unit node and its model-space bounds (_check_unit), for the HUD check.
var _units: Array[Node3D] = []
var _bounds: Array[AABB] = []
var _labels := PackedStringArray()
var _movers: Array[Node3D] = []
var _motions: Array[Motion] = []
var _rests := PackedVector3Array()


func run(main: MainScript) -> void:
	var catalog: Catalog = main.state.catalog
	var types := catalog.unit_types()
	check(types.size() == BUDGETS.size(), "the catalog has the %d unit types the gallery knows (%d)" % [BUDGETS.size(),
		types.size()])
	_log_pilot()
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var root := Node3D.new()
	main.add_child(root)
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	var across := Vector3(view_basis.x.x, 0, view_basis.x.z).normalized()
	var down := Vector3(view_basis.z.x, 0, view_basis.z.z).normalized()
	var facing := deg_to_rad(rad_to_deg(atan2(down.x, down.z)) + TURN)

	var sides := PackedFloat32Array()
	var length := 0.0
	for type: String in types:
		var size: Array = SIZES.get(type, [0.0, 0.6, 0.6, 0.0])
		var side := maxf(maxf(size[1], size[2]), 0.6) + 0.2
		sides.append(side)
		length += side + GAP
	var first := -(length + ACADEMY_GAP) * 0.5
	var tiers: Array = Parts.Tier.values()
	for tier: int in tiers:
		# Base nearest the screen's bottom, each higher tier a row further back.
		var back := (float(tiers.size() - 1) * 0.5 - tier) * ROW_DEPTH
		var row_node := Node3D.new()
		root.add_child(row_node)
		_row_nodes.append(row_node)
		var row: Array[Node3D] = []
		var along := first
		for k: int in types.size():
			var type := types[k]
			var centre := across * (along + sides[k] * 0.5) + down * back
			along += sides[k] + GAP
			var bounds := _check_unit(type, tier)
			var pad := LowPolyMesh.new()
			pad.box_chamfered(Vector3(sides[k], PAD_HEIGHT, sides[k]), 0.03, Vector3.ZERO, Parts.CONCRETE_PAD)
			var pad_node := MeshInstance3D.new()
			pad_node.mesh = pad.to_mesh()
			pad_node.position = centre
			pad_node.rotation.y = facing
			row_node.add_child(pad_node)
			var unit := UnitModels.create(type, tier)
			unit.position = centre + Vector3(0, PAD_HEIGHT, 0)
			unit.rotation.y = facing
			row_node.add_child(unit)
			_collect_movers(unit)
			row.append(unit)
			_units.append(unit)
			_bounds.append(bounds)
			_labels.append("%s at %s" % [type, _tier_name(tier)])
		var academy := BuildingModels.create("cadet_academy", 1, 3, Parts.Tier.BASE)
		academy.position = across * (along + ACADEMY_GAP - GAP) + down * back
		row_node.add_child(academy)
		_rows.append(row)

	var update := _update_movers
	main.get_tree().process_frame.connect(update)
	var middle := across * (first + (length + ACADEMY_GAP) * 0.5) + Vector3(0, 0.6, 0)
	await _shot(main, 24.0, middle, "rows-24")
	# The small units first, the four big machines in the second half: about as wide on the screen.
	var half := types.size() - 4
	for r: int in _rows.size():
		for part: int in 2:
			_show(r, _half(_rows[r], part, half))
			await _shot(main, 10.0, _half_middle(_rows[r], part, half), "%s-10-%d" % [_tier_name(r), part + 1])
	for r: int in [Parts.Tier.BASE, Parts.Tier.CROWN]:
		var row: Array = _rows[r]
		for k: int in types.size():
			var size: Array = SIZES.get(types[k], [0.8, 0.0, 0.0, 0.0])
			var high := maxf(size[0], 0.6) * 0.5 + float(size[3])
			_show(r, [row[k]])
			await _shot(main, 4.0, (row[k] as Node3D).position + Vector3(0, high, 0), "%s-%s-4" % [types[k], _tier_name(r)])
	var base_row: Array = _rows[Parts.Tier.BASE]
	for unit: Node3D in base_row:
		unit.rotation.y += PI
	for part: int in 2:
		_show(Parts.Tier.BASE, _half(base_row, part, half))
		await _shot(main, 10.0, _half_middle(base_row, part, half), "backs-10-%d" % (part + 1))
	main.get_tree().process_frame.disconnect(update)
	root.queue_free()


## Logs a seated colonist's body triangles, with its legs and without them (UnitModels.pilot leaves
## them out): the count the art style reference quotes.
func _log_pilot() -> void:
	var counts := PackedInt32Array()
	for legs: bool in [true, false]:
		var m := LowPolyMesh.new()
		Figures.colonist(m, Vector3.ZERO, 0.0, Figures.seated(), Figures.PRIMARY_HEADS, 1.0, legs)
		counts.append(m.triangle_count())
	say("a seated colonist: %d body triangles, %d without its legs" % [counts[0], counts[1]])
	check(counts[1] < counts[0], "a colonist without its legs has fewer triangles (%d of %d)" % [counts[1], counts[0]])


## Half `part` (0 or 1) of `row`: its first `half` units or the rest.
func _half(row: Array, part: int, half: int) -> Array:
	return row.slice(0, half) if part == 0 else row.slice(half)


## The middle of half `part` of `row`, raised a little.
func _half_middle(row: Array, part: int, half: int) -> Vector3:
	var units := _half(row, part, half)
	return ((units[0] as Node3D).position + (units[units.size() - 1] as Node3D).position) * 0.5 + Vector3(0, 0.6, 0)


## Shows row `r` alone, its pads and academy, and of its units only those in `units`.
func _show(r: int, units: Array) -> void:
	for i: int in _row_nodes.size():
		_row_nodes[i].visible = i == r
	for unit: Node3D in _rows[r]:
		unit.visible = units.has(unit)


func _tier_name(tier: int) -> String:
	return str(Parts.Tier.keys()[tier]).to_lower()


## Frames the camera at `size` on `target`, checks that every unit showing is on the screen and
## clear of the HUD's buttons (Build, Template base, Reset base), and takes the screenshot `name`.
func _shot(main: MainScript, size: float, target: Vector3, name: String) -> void:
	await _frame(main, size, target)
	var screen := Rect2(Vector2.ZERO, main.get_viewport().get_visible_rect().size)
	# Centre the units showing a little left of and below the screen's middle, clear of the buttons
	# along its top right and its bottom right.
	var union := Rect2()
	for i: int in _units.size():
		if _units[i].is_visible_in_tree():
			var rect := _screen_rect(main, i)
			union = rect if union.size == Vector2.ZERO else union.merge(rect)
	main.camera.pan(screen.get_center(), screen.size * Vector2(0.45, 0.54) - union.get_center())
	await frames(SETTLE_FRAMES)
	var buttons: Array[Rect2] = []
	for button: Control in [main.hud.build_button(), main.hud.template_button(), main.hud.reset_button()]:
		if button.is_visible_in_tree():
			buttons.append(button.get_global_rect())
	var showing := 0
	var clear := 0
	var blocked := PackedStringArray()
	for i: int in _units.size():
		var unit := _units[i]
		if not unit.is_visible_in_tree():
			continue
		showing += 1
		var rect := _screen_rect(main, i)
		var hit := not screen.encloses(rect)
		for button: Rect2 in buttons:
			hit = hit or button.intersects(rect)
		if hit:
			blocked.append("%s at %s" % [_labels[i], rect])
		else:
			clear += 1
	check(blocked.is_empty(), "%s: %d of %d units on the screen and clear of the HUD's buttons%s" % [name, clear, showing,
		"" if blocked.is_empty() else ": not " + ", ".join(blocked)])
	await screenshot(name)


## The screen rectangle unit `i`'s bounds cover.
func _screen_rect(main: MainScript, i: int) -> Rect2:
	var box := _bounds[i]
	var xf := _units[i].global_transform
	var rect := Rect2(main.camera.unproject_position(xf * box.position), Vector2.ZERO)
	for corner: int in 8:
		rect = rect.expand(main.camera.unproject_position(xf * box.get_endpoint(corner)))
	return rect


## Checks one unit type built for `tier`: its triangles, instances, layers, extent, hover and
## ground, and says them. Returns its bounds in model space, a spinning part's whole round included.
func _check_unit(type: String, tier: int) -> AABB:
	var name := "%s at %s" % [type, str(Parts.Tier.keys()[tier]).to_lower()]
	var p := UnitModels.build(type, tier)
	var triangles := p.body.triangle_count()
	for mover: LowPolyMesh in p.movers:
		triangles += mover.triangle_count()
	var budget: int = BUDGETS.get(type, 0)
	check(triangles <= budget, "%s: %d triangles (budget %d)" % [name, triangles, budget])

	var model := UnitModels.create(type, tier)
	var bodies := 0
	var instances := 0
	var outlines_ok := true
	var movers := 0
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var lowest_dip := INF
	var top_layer := 0
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := child as MeshInstance3D
		instances += 1
		if instance.has_meta(BuildingModels.OUTLINE_META):
			outlines_ok = outlines_ok and instance.mesh.surface_get_material(0) == MaterialKit.ink() \
				and instance.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			continue
		var parent := instance.get_parent() as Node3D
		var motion: Motion = parent.get_meta(BuildingModels.MOVE_META) if parent.has_meta(BuildingModels.MOVE_META) else null
		if motion != null:
			movers += 1
		else:
			bodies += 1
		var pivot := parent.position if motion != null else Vector3.ZERO
		for surface: int in instance.mesh.get_surface_count():
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
			var custom: Variant = arrays[Mesh.ARRAY_CUSTOM0]
			var spins: PackedFloat32Array = custom if typeof(custom) == TYPE_PACKED_FLOAT32_ARRAY else PackedFloat32Array()
			for i: int in vertices.size():
				var v := vertices[i]
				top_layer = maxi(top_layer, roundi(uv2s[i].x))
				var bob := BOB_HEIGHT if (roundi(uv2s[i].y) & Surf.BOB) != 0 else 0.0
				var y := pivot.y + v.y
				# A spinning part about +Y sweeps each point round a circle of its distance from the axis:
				# a moving part's about its node, a part tagged with LowPolyMesh.spin about its pivot.
				var reach := Vector2(v.x, v.z).length() if motion != null and motion.kind == Motion.Kind.SPIN else 0.0
				var at := pivot + v if reach == 0.0 else pivot + Vector3(0, v.y, 0)
				if (roundi(uv2s[i].y) & Surf.SPIN) != 0 and not spins.is_empty():
					var axis := Vector3(spins[i * 4], 0.0, spins[i * 4 + 2])
					reach = Vector2(v.x - axis.x, v.z - axis.z).length()
					at = axis + Vector3(0, v.y, 0)
				lo = lo.min(Vector3(at.x - reach, y, at.z - reach))
				hi = hi.max(Vector3(at.x + reach, y, at.z + reach))
				lowest_dip = minf(lowest_dip, y - bob)
	model.free()
	check(bodies == 1 and movers <= UnitModels.MAX_MOVING and instances <= 2 * (bodies + movers) and outlines_ok,
		"%s: %d body and %d moving instance(s), %d in all, outlines on ink casting no shadow" % [name, bodies, movers,
			instances])
	check(top_layer < MaterialKit.LAYERS.size(), "%s: kit layers within the kit (highest %d)" % [name, top_layer])
	var size: Array = SIZES.get(type, [0.0, 0.0, 0.0, 0.0])
	var hover: float = size[3]
	var height := hi.y - (lo.y if hover > 0.0 else 0.0)
	var measured := [height, hi.x - lo.x, hi.z - lo.z, lo.y]
	var labels := ["height", "width", "length", "hover"]
	var said := PackedStringArray()
	for i: int in 4:
		var want: float = size[i]
		said.append("%s %.2f" % [labels[i], measured[i]])
		if want > 0.0:
			check(absf(float(measured[i]) - want) <= want * SIZE_SLACK, "%s: %s %.2f (%.2f within %d%%)" % [name, labels[i],
				measured[i], want, roundi(SIZE_SLACK * 100.0)])
	check(lowest_dip >= -GROUND_SLACK, "%s: lowest point %.3f over its pad, bobbing down" % [name, lowest_dip])
	say("%s: %d triangles (budget %d), %d instances, %s, lowest bobbing %.3f" % [name, triangles, budget, instances,
		", ".join(said), lowest_dip])
	return AABB(lo, hi - lo)


func _collect_movers(node: Node3D) -> void:
	for child: Node in node.get_children():
		if child.has_meta(BuildingModels.MOVE_META):
			var mover := child as Node3D
			_movers.append(mover)
			_motions.append(mover.get_meta(BuildingModels.MOVE_META) as Motion)
			_rests.append(mover.position)


func _update_movers() -> void:
	var time := Motion.tick()
	for i: int in _movers.size():
		_movers[i].transform = _motions[i].transform_at(time, _rests[i])


## Sets the camera to `size` (under its own closest zoom directly) with `target` at the screen's
## centre, and lets the frame settle.
func _frame(main: MainScript, size: float, target: Vector3) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / maxf(size, IsoCamera.MIN_ZOOM_SIZE), centre)
	main.camera.size = size
	main.camera.pan(centre, centre - main.camera.unproject_position(target))
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	await frames(SETTLE_FRAMES)
