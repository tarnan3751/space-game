extends HarnessScenario
## The tiers' swatches (docs/reference/art-style.md, **Tiers**): the reference the model batches
## and the coordinator's eye check. On the field, the base's own views hidden, two rows of five
## swatches across the screen, one per surface in _swatches()' order (Base hull-light, plate,
## gunmetal, gold trim, chrome; cyan strip, obsidian, veins, filigree, core glow), each a chamfered
## cube and a drum beside it (on the surface's smooth version where it has one), and before the
## rows a 3x3 pad with the four escorts (Parts.escort_drone, escort_skiff, escort_troopers,
## escort_guard) orbiting it. Left of the pad, the shared effects: a lightning arc between two posts
## on Parts.spark (the slow LIGHTNING crackle) beside a cluster of point sparks on plain FLICKER
## (the fast one); right of it, a stack with Parts.puffs rising from its mouth.
##
## It logs each swatch by index with its layer and flags, and checks that every swatch's layer is
## within the kit, that each escort is at most ESCORT_TRIANGLES body triangles (the troopers
## TROOPERS_TRIANGLES) and stays within the pad's extent (half its footprint plus 0.15) all the way
## round, and that the escorts move.
## It moves them itself, as the effects rig does (Motion.tick() first, then Motion.transform_at).
## Rendered, it frames the rows and the pad at ZOOM_SIZE (the closest zoom) and screenshots them,
## then again 0.3 and 1.0 seconds later, so FLOW, PULSE, the flickers and the orbits show.

const SPACING := 1.9
## The two rows of swatches and the pad, along the view's down direction on the ground.
const ROWS := [-1.6, 1.0]
const PER_ROW := 5
const PAD_AHEAD := 4.8
## The effects pieces beside the pad, along the view's across direction.
const SIDE_ACROSS := 3.4
const ZOOM_SIZE := 10.0
const ESCORT_TRIANGLES := 300
## The troopers' limit instead: two colonists at the figures' study budget (docs/reference/art-style.md,
## **Figures**).
const TROOPERS_TRIANGLES := 3000
const PAD_SIZE := 3
const SETTLE_SECONDS := 0.5
const SETTLE_FRAMES := 10

var _movers: Array[Node3D] = []
var _motions: Array[Motion] = []
var _rests := PackedVector3Array()


func run(main: MainScript) -> void:
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var root := Node3D.new()
	main.add_child(root)
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	var across := Vector3(view_basis.x.x, 0, view_basis.x.z).normalized()
	var down := Vector3(view_basis.z.x, 0, view_basis.z.z).normalized()

	var swatches := _swatches()
	for k: int in swatches.size():
		var flat: Surf = swatches[k][1]
		var round: Surf = swatches[k][2]
		say("swatch %d: %s, layer %d (%s), flags %d" % [k + 1, swatches[k][0], flat.layer,
			MaterialKit.LAYERS[flat.layer] if flat.layer < MaterialKit.LAYERS.size() else "?", flat.flags])
		check(flat.layer < MaterialKit.LAYERS.size() and round.layer < MaterialKit.LAYERS.size(),
			"swatch %d (%s): its layers are within the kit's %d" % [k + 1, swatches[k][0], MaterialKit.LAYERS.size()])
		var p := Parts.new()
		p.body.box_chamfered(Vector3(0.8, 0.9, 0.8), 0.08, -across * 0.45, flat, Vector3(0, IsoCamera.YAW_DEG, 0))
		Parts.drum(p.body, 0.4, 0.9, 0.08, 24, across * 0.45, round)
		var node := BuildingModels.instantiate(p)
		var row: float = ROWS[k / PER_ROW]
		node.position = across * SPACING * (k % PER_ROW - (PER_ROW - 1) * 0.5) + down * row
		root.add_child(node)

	var pad := Parts.new()
	pad.tier = Parts.Tier.CROWN
	Parts.foundation(pad.body, PAD_SIZE)
	var escorts: Array[LowPolyMesh] = [
		Parts.escort_drone(pad, 1.3, 1.2, 0.8),
		Parts.escort_skiff(pad, 1.0, 0.7, -0.6),
		Parts.escort_troopers(pad, 1.3, Parts.PAD_HEIGHT, 0.4),
		Parts.escort_guard(pad, 1.0, 1.8, -0.5),
	]
	var names: Array[String] = ["drone", "skiff", "troopers", "guard"]
	var bound := PAD_SIZE * 0.5 + 0.15
	for k: int in escorts.size():
		var reach := 0.0
		var vertices: PackedVector3Array = escorts[k].to_mesh().surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for vertex: Vector3 in vertices:
			reach = maxf(reach, Vector2(vertex.x, vertex.z).length())
		var triangles := escorts[k].triangle_count()
		var limit := TROOPERS_TRIANGLES if names[k] == "troopers" else ESCORT_TRIANGLES
		check(triangles <= limit and reach <= bound, "the %s escort: %d body triangles (limit %d), reach %.2f round the pad (limit %.2f)"
			% [names[k], triangles, limit, reach, bound])
	var pad_node := BuildingModels.instantiate(pad)
	pad_node.position = down * PAD_AHEAD
	root.add_child(pad_node)
	_collect_movers(pad_node)

	var sparks := Parts.new()
	for side: float in [-1.0, 1.0]:
		Parts.drum(sparks.body, 0.08, 0.7, 0.03, 12, across * side * 0.45, Parts.GUNMETAL)
	Parts.arc(sparks.body, -across * 0.45 + Vector3(0, 0.65, 0), across * 0.45 + Vector3(0, 0.65, 0), 6, 0.06,
		Parts.spark(MaterialKit.ENERGY))
	var point := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLICKER, true, false)
	for k: int in 8:
		sparks.body.orb(0.05, 8, 3, Parts.around(0.2, 45.0 * k, 0.25 + 0.06 * (k % 3)) - down * 0.6, point.phased(k / 8.0))
	var sparks_node := BuildingModels.instantiate(sparks)
	sparks_node.position = down * PAD_AHEAD - across * SIDE_ACROSS
	root.add_child(sparks_node)

	var stack := Parts.new()
	Parts.drum(stack.body, 0.22, 0.25, 0.05, 16, Vector3.ZERO, Parts.HULL_DARK_ROUND)
	stack.body.prism(0.12, 0.1, 0.9, 16, Vector3(0, 0.25, 0), Parts.GUNMETAL)
	stack.body.ring(0.07, 0.13, 0.06, 16, Vector3(0, 1.15, 0), Parts.GOLD_ROUND)
	Parts.puffs(stack.body, Vector3(0, 1.21, 0), 0.0)
	var stack_node := BuildingModels.instantiate(stack)
	stack_node.position = down * PAD_AHEAD + across * SIDE_ACROSS
	root.add_child(stack_node)

	var update := _update_movers
	main.get_tree().process_frame.connect(update)
	var before: Array[Transform3D] = []
	for mover: Node3D in _movers:
		before.append(mover.transform)
	await frames(10)
	var moved := 0
	for i: int in _movers.size():
		if not _movers[i].transform.is_equal_approx(before[i]):
			moved += 1
	check(moved == escorts.size() and _movers.size() == escorts.size(),
		"%d of %d escorts moved in 10 frames" % [moved, _movers.size()])

	zoom_to(main, ZOOM_SIZE, down * 1.5)
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	await frames(SETTLE_FRAMES)
	await screenshot("swatches")
	await main.get_tree().create_timer(0.3).timeout
	await screenshot("swatches-soon")
	await main.get_tree().create_timer(0.7).timeout
	await screenshot("swatches-later")
	main.get_tree().process_frame.disconnect(update)
	root.queue_free()


## [name, the flat surface, the round one] per swatch, in order.
func _swatches() -> Array[Array]:
	var plate := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
	return [
		["base hull-light", Parts.HULL_LIGHT, Parts.HULL_LIGHT_ROUND],
		["plate", plate, plate],
		["gunmetal", Parts.GUNMETAL, Parts.GUNMETAL],
		["gold trim", Parts.GOLD_TRIM, Parts.GOLD_ROUND],
		["chrome", Parts.CHROME, Parts.CHROME_ROUND],
		["cyan strip", Parts.CYAN_STRIP, Parts.CYAN_STRIP],
		["obsidian", Parts.OBSIDIAN, Parts.OBSIDIAN_ROUND],
		["veins", Parts.VEINS, Parts.VEINS],
		["filigree", Parts.FILIGREE, Parts.FILIGREE],
		["core glow", Parts.CORE_GLOW, Parts.CORE_GLOW],
	]


func _update_movers() -> void:
	var time := Motion.tick()
	for i: int in _movers.size():
		_movers[i].transform = _motions[i].transform_at(time, _rests[i])


func _collect_movers(node: Node3D) -> void:
	for child: Node in node.get_children():
		if child.has_meta(BuildingModels.MOVE_META):
			var mover := child as Node3D
			_movers.append(mover)
			_motions.append(mover.get_meta(BuildingModels.MOVE_META) as Motion)
			_rests.append(mover.position)
