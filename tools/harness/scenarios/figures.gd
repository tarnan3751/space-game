extends HarnessScenario
## The humanoid design study (docs/reference/art-style.md, **Figures**): the colonist and the
## automaton (Figures) for the owner to judge from screenshots. On the field, the base's own views
## hidden, a row across the screen, each figure on a small concrete pad, turned a little off the
## camera so its depth shows, the striding ones in profile, walking towards the screen's left, so
## the stride shows: the colonist at 3, 3.5 (the primary) and 4.25 heads in the stance, the primary
## colonist mid-stride, the automaton in the stance and mid-stride, and at the end of the row a
## level 1 Cadet Academy, a Base-tier 3x3, for scale.
##
## It logs each figure's body triangles, its top and its lowest point over its pad, and checks that
## every figure is within STUDY_BUDGET triangles, that its lowest point is on its pad (within
## GROUND_SLACK, so no foot sinks into it or floats over it) and that each stance figure stands its
## height (Figures.COLONIST_HEIGHT, or Figures.AUTOMATON_HEIGHT to the head under its antenna).
## Rendered, the screenshots, each a different frame:
## - "row-24": the whole row at camera size 24, the gameplay view: does a figure read as a
##   character at the zoom the game is played at?
## - "row-10": the row at size 10, the closest gameplay zoom: the proportions side by side.
## - "colonist-4", "automaton-4": the primary colonist and the automaton in the stance at size 4
##   (under the camera's own closest zoom, set directly): the forms, the joints and the paint.
## - "backs-10": the row at size 10 with every figure turned 180 degrees, so the backpack and the
##   power unit show.

const STUDY_BUDGET := 1500
const SPACING := 1.15
## How far past the last figure the academy's centre stands, along the row.
const ACADEMY_GAP := 2.7
const PAD_SIDE := 0.62
const PAD_HEIGHT := 0.06
## Degrees the figures are turned from facing the camera: a three-quarter view, and a profile for
## the striding ones, walking towards the screen's left with the front leg nearer the camera.
const TURN := 25.0
const STRIDE_TURN := -90.0
const HEIGHT_SLACK := 0.03
## How far a figure's lowest point may be from its pad's top.
const GROUND_SLACK := 0.005
const SETTLE_SECONDS := 0.5
const SETTLE_FRAMES := 10

var _figures: Array[Node3D] = []


func run(main: MainScript) -> void:
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var root := Node3D.new()
	main.add_child(root)
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	var across := Vector3(view_basis.x.x, 0, view_basis.x.z).normalized()
	var down := Vector3(view_basis.z.x, 0, view_basis.z.z).normalized()
	var facing := rad_to_deg(atan2(down.x, down.z)) + TURN

	# [name, automaton, heads, stride]
	var row: Array[Array] = [
		["colonist 3 heads, stance", false, 3.0, false],
		["colonist 3.5 heads, stance", false, Figures.PRIMARY_HEADS, false],
		["colonist 4.25 heads, stance", false, 4.25, false],
		["colonist 3.5 heads, mid-stride", false, Figures.PRIMARY_HEADS, true],
		["automaton 3.5 heads, stance", true, Figures.PRIMARY_HEADS, false],
		["automaton 3.5 heads, mid-stride", true, Figures.PRIMARY_HEADS, true],
	]
	var first := -(row.size() - 1 + ACADEMY_GAP / SPACING) * SPACING * 0.5
	for k: int in row.size():
		var spec: Array = row[k]
		var robot: bool = spec[1]
		var heads: float = spec[2]
		var walking: bool = spec[3]
		var p := Parts.new()
		var pose := Figures.stride() if walking else Figures.stance()
		var on_pad := Vector3(0, PAD_HEIGHT, 0)
		if robot:
			Figures.automaton(p.body, on_pad, 0.0, pose, heads)
		else:
			Figures.colonist(p.body, on_pad, 0.0, pose, heads)
		var triangles := p.body.triangle_count()
		var top := -INF
		var bottom := INF
		for vertex: Vector3 in p.body.to_arrays()[Mesh.ARRAY_VERTEX] as PackedVector3Array:
			top = maxf(top, vertex.y - PAD_HEIGHT)
			bottom = minf(bottom, vertex.y - PAD_HEIGHT)
		say("%s: %d body triangles, top %.3f, lowest %.4f" % [spec[0], triangles, top, bottom])
		check(triangles <= STUDY_BUDGET, "%s: %d body triangles (study budget %d)" % [spec[0], triangles, STUDY_BUDGET])
		check(absf(bottom) <= GROUND_SLACK, "%s: lowest point %.4f over its pad (within %.3f)" % [spec[0], bottom,
			GROUND_SLACK])
		if not walking and not robot:
			check(absf(top - Figures.COLONIST_HEIGHT) <= HEIGHT_SLACK, "%s stands %.3f (%.2f)" % [spec[0], top,
				Figures.COLONIST_HEIGHT])
		if not walking and robot:
			check(top >= Figures.AUTOMATON_HEIGHT - HEIGHT_SLACK and top <= Figures.AUTOMATON_HEIGHT + 0.12,
				"%s stands %.3f to its antenna's tip (%.2f to its head's top)" % [spec[0], top, Figures.AUTOMATON_HEIGHT])
		p.body.box_chamfered(Vector3(PAD_SIDE, PAD_HEIGHT, PAD_SIDE), 0.03, Vector3.ZERO, Parts.CONCRETE_PAD)
		var node := BuildingModels.instantiate(p)
		node.position = across * (first + SPACING * k)
		node.rotation.y = deg_to_rad(facing + (STRIDE_TURN - TURN if walking else 0.0))
		root.add_child(node)
		_figures.append(node)

	var academy := BuildingModels.create("cadet_academy", 1, 3, Parts.Tier.BASE)
	academy.position = across * (first + SPACING * (row.size() - 1) + ACADEMY_GAP)
	root.add_child(academy)
	var middle := across * (first + SPACING * (row.size() - 1 + ACADEMY_GAP / SPACING) * 0.5) + Vector3(0, 0.5, 0)

	await _frame(main, 24.0, middle)
	await screenshot("row-24")
	await _frame(main, 10.0, middle)
	await screenshot("row-10")
	await _frame(main, 4.0, _figures[1].position + Vector3(0, 0.42, 0))
	await screenshot("colonist-4")
	await _frame(main, 4.0, _figures[4].position + Vector3(0, 0.46, 0))
	await screenshot("automaton-4")
	for node: Node3D in _figures:
		node.rotation.y += PI
	await _frame(main, 10.0, middle)
	await screenshot("backs-10")
	root.queue_free()


## Sets the camera to `size` (under its own closest zoom directly) with `target` at the screen's
## centre, and lets the frame settle.
func _frame(main: MainScript, size: float, target: Vector3) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / maxf(size, IsoCamera.MIN_ZOOM_SIZE), centre)
	main.camera.size = size
	main.camera.pan(centre, centre - main.camera.unproject_position(target))
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	await frames(SETTLE_FRAMES)
