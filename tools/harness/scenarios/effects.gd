extends HarnessScenario
## The animation rig (docs/reference/art-style.md, **Animation**): a test part for each surface
## effect and each kind of moving part, built with LowPolyMesh and Parts and assembled as a
## model is (BuildingModels.instantiate: the body, its outline, a node per moving part), in two
## rows across the screen on the field, the base's own views hidden.
##
## The first row: a PULSE orb, a ring of eight BLINK lamps at phases k/8, a cluster of FLICKER
## sparks, a FLOW pipe on the pipe layer, a FLOW_U disc on the hazard layer, a BOB orb with its
## outline, a crackling arc (UNLIT, FLICKER and JITTER strips), and a HOLO prism on a pedestal,
## then the same again with the pedestal ghost-tinted. The second row: moving parts that SPIN
## about Y, SWING about X (SMOOTH), SLIDE along X (HAMMER) and SLIDE along Z (RECOIL), and one
## made only of FLICKER sparks, which has no outline. The scenario moves the moving parts
## itself, with Motion.transform_at at Motion.clock(), as BuildingView does. It poses them from
## the tree's process_frame, which fires before main.gd's _process ticks the clock, so it ticks
## the clock itself first (Motion.tick()), so the parts match this frame's shaders as a view's do.
##
## Headless it checks each part's surfaces and flags, the outline's channels, the instance
## counts and that the moving parts move. Rendered it frames the rig at the closest zoom and
## screenshots it 0.0, 0.3 and 0.9 seconds after a settle, and checks that every part's region
## of the screen changes between the shots.

const SPACING := 1.75
const ROW_GAP := 3.2
const ZOOM_SIZE := 10.0
const SETTLE_SECONDS := 0.5
const SETTLE_FRAMES := 10
## A region changes when this many of its pixels differ by more than PIXEL_DELTA in a channel.
const CHANGED_PIXELS := 12
const PIXEL_DELTA := 0.04

## Each rig part: {"name", "node", "surfaces" (the body's surface count), "flags" (bits every
## vertex of surface 0 carries), "outlined" (whether the body has an outline)}.
var _rig: Array[Dictionary] = []
var _movers: Array[Node3D] = []
var _motions: Array[Motion] = []
var _rests := PackedVector3Array()
var _main: MainScript


func run(main: MainScript) -> void:
	_main = main
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var root := Node3D.new()
	main.add_child(root)
	_build_rig()
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	var across := Vector3(view_basis.x.x, 0, view_basis.x.z).normalized()
	var down := Vector3(view_basis.z.x, 0, view_basis.z.z).normalized()
	var rows: Array[Array] = [[], []]
	for part: Dictionary in _rig:
		rows[int(part["row"])].append(part)
	for row: int in rows.size():
		var count := rows[row].size()
		for k: int in count:
			var part: Dictionary = rows[row][k]
			var node: Node3D = part["node"]
			node.position = across * SPACING * (k - (count - 1) * 0.5) + down * ROW_GAP * (row - 0.5)
			root.add_child(node)
			_collect_movers(node)

	_check_parts()
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
	check(moved == _movers.size() and moved == 5, "%d of %d moving parts moved in 10 frames" % [moved, _movers.size()])

	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / ZOOM_SIZE, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(Vector3.ZERO))
	# The window shows a frame or more behind the scene, and the first frames compile the rig's
	# shaders: wait for both a settle and a run of frames before the first shot.
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	await frames(SETTLE_FRAMES)
	var shots: Array[Image] = []
	for at: Array in [[0.0, "0.0s"], [0.3, "0.3s"], [0.6, "0.9s"]]:
		var wait: float = at[0]
		if wait > 0.0:
			await main.get_tree().create_timer(wait).timeout
		await screenshot("rig-" + str(at[1]))
		if not harness.headless:
			shots.append(main.get_viewport().get_texture().get_image())
	if not shots.is_empty():
		_check_regions(shots)
	main.get_tree().process_frame.disconnect(update)
	root.queue_free()


func _build_rig() -> void:
	var glow := MaterialKit.Layer.GLOW
	# A PULSE orb.
	var p := Parts.new()
	p.body.orb(0.35, 16, 6, Vector3(0, 0.5, 0), Surf.make(glow, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true))
	_add("pulse", p, 0, Surf.UNLIT | Surf.PULSE)
	# Eight BLINK lamps round a ring, phases k/8, so they chase.
	p = Parts.new()
	var lamp := Surf.make(glow, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.BLINK, true)
	Parts.torus(p.body, 0.42, 0.04, 16, 6, Vector3(0, 0.05, 0), Parts.HULL_DARK_ROUND)
	for k: int in 8:
		p.body.orb(0.09, 12, 4, Parts.around(0.42, 45.0 * k, 0.16), lamp.phased(k / 8.0))
	_add("blink", p, 0, 0)
	# A cluster of FLICKER sparks, each with its own phase, round a post.
	p = Parts.new()
	p.body.prism(0.06, 0.06, 0.6, 8, Vector3.ZERO, Parts.GUNMETAL)
	var spark := Surf.make(glow, MaterialKit.CORE_GOLD, 1.0, Surf.UNLIT | Surf.FLICKER)
	for k: int in 8:
		p.body.orb(0.06, 8, 3, Parts.around(0.22, 45.0 * k, 0.45 + 0.05 * (k % 3)), spark.phased(k / 8.0 + 0.03))
	_add("flicker", p, 0, 0)
	# A FLOW pipe on the pipe layer, a repeat a second forward.
	p = Parts.new()
	Parts.pipe(p.body, Vector3(0, 0.15, -0.5), Vector3(0, 0.15, 0.5), 0.16,
		Surf.make(MaterialKit.Layer.PIPE, MaterialKit.NANITE_GREEN, 2.0, Surf.UNLIT | Surf.FLOW, true, true, 0.75))
	_add("flow", p, 0, Surf.FLOW)
	# A FLOW_U disc: the hazard layer, whose stripes cross U (the glow layer's run along it, so it
	# would show no turn), turning round the disc.
	p = Parts.new()
	p.body.disc(0.45, 24, Vector3(0, 0.3, 0), Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 1.0, Surf.FLOW_U, false, true, 0.75))
	_add("flow_u", p, 0, Surf.FLOW_U)
	# A BOB orb with its outline.
	p = Parts.new()
	p.body.orb(0.3, 16, 6, Vector3(0, 0.6, 0), Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.BOB, true))
	_add("bob", p, 0, Surf.BOB)
	# A crackling arc between two posts: five strips of short segments, so JITTER has corners to
	# shake, each flickering on its own phase.
	p = Parts.new()
	for side: float in [-1.0, 1.0]:
		p.body.prism(0.07, 0.05, 0.7, 8, Vector3(side * 0.55, 0, 0), Parts.GUNMETAL)
	var arc := Surf.make(glow, MaterialKit.ARC_BLUE, 1.0, Surf.UNLIT | Surf.FLICKER | Surf.JITTER)
	for strip: int in 5:
		var surface := arc.phased(strip / 5.0)
		for k: int in 8:
			var a := Vector3(-0.55 + 1.1 * k / 8.0, 0.66 + 0.04 * sin(k + strip), 0)
			var b := Vector3(-0.55 + 1.1 * (k + 1) / 8.0, 0.66 + 0.04 * sin(k + 1 + strip), 0)
			p.body.strut(a, b, 0.025, surface)
	_add("arc", p, 0, 0)
	# A HOLO prism on a pedestal, plain and with the pedestal ghost-tinted.
	for ghost: bool in [false, true]:
		p = Parts.new()
		Parts.drum(p.body, 0.32, 0.18, 0.04, 16, Vector3.ZERO, Parts.HULL_DARK_ROUND)
		p.body.prism(0.26, 0.18, 0.7, 6, Vector3(0, 0.2, 0), Surf.make(glow, MaterialKit.ENERGY, 1.0, Surf.HOLO))
		var part := _add("holo_ghost" if ghost else "holo", p, 0, 0)
		part["surfaces"] = 2
		if ghost:
			var body := _body(part["node"])
			body.set_surface_override_material(0, MaterialKit.ghost_valid())

	# The moving parts, each on a post: an arm spinning about Y, a pendulum swinging about X, a
	# block hammering along X, one recoiling along Z, and a cluster of sparks turning about Y.
	p = Parts.new()
	p.body.prism(0.08, 0.08, 0.6, 8, Vector3.ZERO, Parts.GUNMETAL)
	var arm := p.moving(Vector3(0, 0.6, 0), Motion.spin(Vector3.UP, 2.0))
	arm.box_chamfered(Vector3(0.9, 0.1, 0.14), 0.03, Vector3.ZERO, Parts.surf("orange"))
	_add("spin", p, 1, 0)
	p = Parts.new()
	p.body.box_chamfered(Vector3(0.8, 0.1, 0.12), 0.03, Vector3(0, 1.0, 0), Parts.HULL_MID)
	for side: float in [-1.0, 1.0]:
		p.body.prism(0.05, 0.05, 1.0, 8, Vector3(side * 0.38, 0, 0), Parts.GUNMETAL)
	var pendulum := p.moving(Vector3(0, 1.0, 0), Motion.swing(Vector3.RIGHT, 40.0, 1.6))
	pendulum.box(Vector3(0.05, 0.5, 0.05), Vector3(0, -0.55, 0), Parts.GUNMETAL)
	pendulum.orb(0.12, 12, 4, Vector3(0, -0.6, 0), Parts.surf("red"))
	_add("swing", p, 1, 0)
	p = Parts.new()
	p.body.box_chamfered(Vector3(1.2, 0.12, 0.3), 0.03, Vector3.ZERO, Parts.HULL_DARK)
	var hammer := p.moving(Vector3(0, 0.12, 0), Motion.slide(Vector3.RIGHT, 0.3, 1.5, 0.0, Motion.Ease.HAMMER))
	hammer.box_chamfered(Vector3(0.3, 0.3, 0.26), 0.04, Vector3.ZERO, Parts.HAZARD)
	_add("slide_hammer", p, 1, 0)
	p = Parts.new()
	p.body.box_chamfered(Vector3(0.3, 0.3, 0.3), 0.04, Vector3.ZERO, Parts.HULL_DARK)
	var barrel := p.moving(Vector3(0, 0.15, 0), Motion.slide(Vector3.BACK, 0.2, 1.5, 0.0, Motion.Ease.RECOIL))
	Parts.pipe(barrel, Vector3(0, 0, -0.1), Vector3(0, 0, 0.55), 0.07, Parts.GUNMETAL)
	_add("slide_recoil", p, 1, 0)
	p = Parts.new()
	p.body.prism(0.06, 0.06, 0.5, 8, Vector3.ZERO, Parts.GUNMETAL)
	var sparks := p.moving(Vector3(0, 0.55, 0), Motion.spin(Vector3.UP, 3.0))
	for k: int in 6:
		sparks.orb(0.05, 8, 3, Parts.around(0.3, 60.0 * k, 0.0), spark.phased(k / 6.0))
	_add("flicker_mover", p, 1, 0)


func _add(name: String, p: Parts, row: int, flags: int) -> Dictionary:
	var part := {"name": name, "node": BuildingModels.instantiate(p), "row": row, "surfaces": 1, "flags": flags}
	_rig.append(part)
	return part


## Checks every rig part's meshes: the surface count and flags of its body, its instances
## within the eight-instance budget, every body outlined unless all its parts are never outlined,
## the outline carrying UV2 and colour, and UV2 stored uncompressed (float32, so the flag bits
## are exact).
func _check_parts() -> void:
	for part: Dictionary in _rig:
		var node: Node3D = part["node"]
		var name: String = part["name"]
		var body := _body(node)
		var mesh := body.mesh
		var flags: int = part["flags"]
		var all_flagged := true
		var uv2s: PackedVector2Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_TEX_UV2]
		var phases := {}
		for i: int in uv2s.size():
			all_flagged = all_flagged and (roundi(uv2s[i].y) & flags) == flags
		for colour: Color in (mesh.surface_get_arrays(0)[Mesh.ARRAY_COLOR] as PackedColorArray):
			phases[snappedf(colour.a, 0.01)] = true
		var holo_ok := true
		if mesh.get_surface_count() > 1:
			holo_ok = mesh.surface_get_material(1) == MaterialKit.holo() \
				and body.get_surface_override_material(1) == null
		var instances := node.find_children("*", "MeshInstance3D", true, false).size()
		var uncompressed: bool = (mesh.surface_get_format(0) & Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES) == 0
		check(mesh.get_surface_count() == part["surfaces"] and all_flagged and holo_ok and instances <= 8
			and uncompressed, "%s: %d surface(s), flags %d on every vertex %s, %d instance(s), %d phase(s), UV2 uncompressed %s"
			% [name, mesh.get_surface_count(), flags, all_flagged, instances, phases.size(), uncompressed])
		for mover: Node in node.get_children():
			if mover.has_meta(BuildingModels.MOVE_META):
				var outlines := mover.get_children().filter(
					func(child: Node) -> bool: return child.has_meta(BuildingModels.OUTLINE_META)).size()
				var expected := 0 if name == "flicker_mover" else 1
				check(outlines == expected, "%s: its moving part has %d outline(s), %d expected" % [name, outlines, expected])
	var bob := _outline(_part("bob")["node"])
	var format: int = bob.mesh.surface_get_format(0)
	check((format & Mesh.ARRAY_FORMAT_TEX_UV2) != 0 and (format & Mesh.ARRAY_FORMAT_COLOR) != 0,
		"the BOB orb's outline carries UV2 and colour")
	var arc_outline := _outline(_part("arc")["node"])
	var arc_triangles := (arc_outline.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	check(arc_triangles == _posts_triangles(), "the arc's outline holds only its posts (%d triangles)" % arc_triangles)
	_check_phases()
	check(_body(_part("holo_ghost")["node"]).get_surface_override_material(0) == MaterialKit.ghost_valid(),
		"the ghost-tinted pedestal takes the ghost tint, its hologram keeps the holo material")


## Checks that a phase survives the mesh's 8-bit colour store: read back and decoded as the
## shaders' surf_phase does, 0.5 (a FLOW part standing still) is exactly 0.5, and every k/8 is
## within half a step of 1/254.
func _check_phases() -> void:
	var m := LowPolyMesh.new()
	var surface := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.FLOW)
	for k: int in 9:
		m.box(Vector3.ONE * 0.1, Vector3(k, 0, 0), surface.phased(k / 8.0))
	var colours: PackedColorArray = m.to_mesh().surface_get_arrays(0)[Mesh.ARRAY_COLOR]
	var per_part := colours.size() / 9
	var worst := 0.0
	var half := -1.0
	for k: int in 9:
		var phase := roundi(colours[k * per_part].a * 255.0) / 254.0
		worst = maxf(worst, absf(phase - k / 8.0))
		if k == 4:
			half = phase
	check(half == 0.5 and worst <= 0.5 / 254.0 + 0.000001,
		"a phase of 0.5 reads back as %.6f, every k/8 within %.6f" % [half, worst])


## The outline triangles of the arc's two posts, built alone.
func _posts_triangles() -> int:
	var m := LowPolyMesh.new()
	for side: float in [-1.0, 1.0]:
		m.prism(0.07, 0.05, 0.7, 8, Vector3(side * 0.55, 0, 0), Parts.GUNMETAL)
	return m.triangle_count()


## Checks that each rig part's region of the screen changed between the shots: between the first
## two for every part, or between any two for the flickering ones, which can be off in both.
func _check_regions(shots: Array[Image]) -> void:
	var camera: IsoCamera = _main.camera
	var unit := _main.get_viewport().get_visible_rect().size.y / camera.size
	var half := int(unit * 0.75)
	for part: Dictionary in _rig:
		var node: Node3D = part["node"]
		var at := camera.unproject_position(node.global_position + Vector3(0, 0.45, 0))
		var region := Rect2i(Vector2i(at) - Vector2i(half, half), Vector2i(half, half) * 2)
		region = region.intersection(Rect2i(Vector2i.ZERO, shots[0].get_size()))
		var first := _changed(shots[0], shots[1], region)
		var any := maxi(first, maxi(_changed(shots[1], shots[2], region), _changed(shots[0], shots[2], region)))
		var name: String = part["name"]
		var flickers := name in ["flicker", "arc", "flicker_mover"]
		var changed := any if flickers else first
		check(changed >= CHANGED_PIXELS, "%s: %d pixels of its %dx%d region changed%s" % [name, changed,
			region.size.x, region.size.y, " (any two shots)" if flickers else " (first two shots)"])


func _changed(a: Image, b: Image, region: Rect2i) -> int:
	var count := 0
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			if maxf(maxf(absf(ca.r - cb.r), absf(ca.g - cb.g)), absf(ca.b - cb.b)) > PIXEL_DELTA:
				count += 1
	return count


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


func _part(name: String) -> Dictionary:
	for part: Dictionary in _rig:
		if part["name"] == name:
			return part
	return {}


func _body(node: Node3D) -> MeshInstance3D:
	for child: Node in node.get_children():
		if child is MeshInstance3D and not child.has_meta(BuildingModels.OUTLINE_META):
			return child as MeshInstance3D
	return null


func _outline(node: Node3D) -> MeshInstance3D:
	for child: Node in node.get_children():
		if child is MeshInstance3D and child.has_meta(BuildingModels.OUTLINE_META):
			return child as MeshInstance3D
	return null
