extends HarnessScenario
## The environment on a fresh base (docs/reference/art-style.md, **Environment**). Checks that the
## terrain, the perimeter, the rocks and the outcrops are each a body with an ink outline that casts
## no shadow (the terrain's body none either, the perimeter's one); that the perimeter's body is two
## surfaces, the toon's and the holograms' (its fence); that the background is a sky drawn by a
## shader; that no rock or rubble vertex comes within the perimeter's reach out of the field, beside
## the sides or in the corners (its own vertices' farthest), or inside a mesa's reach (its fillet's
## outer edge); the terrain's triangle budget; that
## each mesa's own geometry (BaseView.mesa_indices) is closed but along its fillet's outer edge, sunk
## MESA_SINK under the ground, has no degenerate triangle and lies on terrain_height everywhere
## else, and that its rim stays within MESA_RIM_RISE of its top all round; that no part of an
## outcrop comes within OUTCROP_GAP of the field; that along each side of the field, EDGE_OUT units out, the ground is uneven (its height
## spreads by more than EDGE_SPREAD) and low (never over EDGE_HIGHEST), and the distance at which
## the relief is full (BaseView.blend_end) wanders by more than BLEND_WANDER; that at the widest
## zoom in a WIDE window, the focus at each corner of its bounds, the ray from every screen corner
## meets the terrain; and that in a WIDER window, focused on the field's nearest corner, it does
## not, so the sky shows; and, rendered only, that at the start zoom, focused EDGE_VIEW in from the
## field's far corner, the ground just inside the field's two far sides and just outside them
## differs by under EDGE_STEP (_check_edge_step), and
## that in the widest shot the field's quarters and two flat stretches of the ring average to the
## same shade, the value noise they share divided out (_check_field_shade). Screenshots: the
## start zoom, the far sides at it, the closest on the field, the closest on a point where four of the field texture's
## tiles meet (nothing should show where they do), a wider stretch of the field, the perimeter at
## the middle of each side, a side and a corner of it at the closest zoom, the widest in the WIDE
## window and in the WIDER one on the nearest corner (stars beyond the ring, no bare colour), the
## widest in the WIDEST one on the field's left corner (the sky's haze band beyond the ring's lower
## left), a crater, an outcrop and the first mesa's wall centred
## (its foot and rim), then the mesa wider, its foot at the closest zoom and its ledge (for the
## perimeter, the crater, the outcrop and the mesa the camera's bounds are widened, as a player
## cannot centre the view off the field).

const TERRAIN_BUDGET := 38000
## How closely the mesas' geometry lies on terrain_height, at its points and at these weights of
## each triangle's corners.
const MESA_FIT := 0.02
const MESA_SAMPLES: Array[Vector3] = [Vector3(1.0, 1.0, 1.0) / 3.0, Vector3(0.6, 0.2, 0.2),
	Vector3(0.2, 0.6, 0.2), Vector3(0.2, 0.2, 0.6)]
const OUTCROP_GAP := 4.0
const EDGE_OUT := 3.8
const EDGE_SPREAD := 0.1
const EDGE_HIGHEST := 0.4
const BLEND_WANDER := 3.0
const WIDE := Vector2i(1560, 720)
## A window wider than the ring fills at the widest zoom, where the sky shows.
const WIDER := Vector2i(1400, 400)
## Wider still (4:1), for the sky's haze band beyond the ring's lower left.
const WIDEST := Vector2i(1600, 400)
## The field's shade against the ring's in the widest shot: the centres of the field's four
## quarters (clear of the buildings), two flat stretches of the ring, the box averaged round each
## in pixels, and how far the two averages may differ in HSL lightness and saturation.
const FIELD_QUARTERS: Array[Vector3] = [Vector3(-12, 0, -12), Vector3(12, 0, -12), Vector3(12, 0, 12),
	Vector3(-12, 0, 12)]
const RING_FLATS: Array[Vector3] = [Vector3(15.5, 0, -30), Vector3(30, 0, -1)]
const SHADE_BOX := Vector2i(80, 40)
const SHADE_L := 0.01
const SHADE_S := 0.02
## The ground shaders' macro value noise (ground.gdshader, terrain.gdshader): its period in cells and
## its strength either way.
const MACRO_CELLS := 12.0
const MACRO := 0.06
## The step at the field's edge at the start zoom, the focus EDGE_VIEW in from the field's far
## corner along each axis (so the two far sides show as far as the start view showed them on the
## 40x40 field, whose far corner lay that far from its centre): on each side whose strip outside the edge lies
## clear of the perimeter (the two far from the camera, by the screen corner each faces, with its
## outward direction), the ground EDGE_IN inside the edge and EDGE_IN outside it, sampled every
## EDGE_EVERY cells along the side in a box of EDGE_BOX pixels, and the most the medians of the two
## may differ in any channel, in 255ths.
const EDGE_SIDES := {"top-left": Vector2(-1, 0), "top-right": Vector2(0, -1)}
const EDGE_VIEW := 20.0
const EDGE_IN := 0.5
const EDGE_EVERY := 1
const EDGE_BOX := Vector2i(8, 4)
const EDGE_STEP := 3


func run(main: MainScript) -> void:
	var view := main.base_view
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each: the body, its outline, and whether the body may cast a shadow.
	var pairs := {"terrain": [view.terrain, view.terrain_outline, false],
		"perimeter": [view.boundary, view.boundary_outline, true], "rocks": [view.rocks, view.rocks_outline, true],
		"outcrops": [view.outcrops, view.outcrops_outline, true]}
	for name: String in pairs:
		var body: MeshInstance3D = pairs[name][0]
		var outline: MeshInstance3D = pairs[name][1]
		check(body != null and body.mesh != null and outline != null and outline.mesh != null
			and outline.cast_shadow == off and outline.mesh.surface_get_material(0) == MaterialKit.ink()
			and (pairs[name][2] or body.cast_shadow == off), "the %s: a body and an ink outline casting no shadow" % name)
	var sky: Sky = null
	for child: Node in main.get_children():
		if child is WorldEnvironment:
			var environment := (child as WorldEnvironment).environment
			if environment.background_mode == Environment.BG_SKY:
				sky = environment.sky
	check(sky != null and sky.sky_material is ShaderMaterial, "the background is a sky drawn by a shader")
	var perimeter := view.boundary.mesh
	check(view.boundary.cast_shadow != off and perimeter.get_surface_count() == 2
		and perimeter.surface_get_material(0) == MaterialKit.toon()
		and perimeter.surface_get_material(1) == MaterialKit.holo(),
		"the perimeter: its body casts a shadow, in two surfaces, the toon's and the fence's holograms'")
	var triangles := view.terrain.mesh.get_faces().size() / 3
	check(triangles <= TERRAIN_BUDGET, "the terrain has %d triangles, within %d" % [triangles, TERRAIN_BUDGET])
	for k: int in view.mesas.size():
		_check_mesa(view, k)
	var field := view.area()
	var nearest := INF
	for at: Vector3 in view.outcrops.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		nearest = minf(nearest, (Vector2(absf(at.x), absf(at.z)) - field.end).max(Vector2.ZERO).length())
	check(nearest >= OUTCROP_GAP, "%d outcrops, the nearest %.1f from the field" % [view.outcrop_spots.size(), nearest])
	# No rock or rubble vertex within the perimeter's reach out of the field, measured from its own
	# mesh: along the sides (the kerb's band) and in the corners' quadrants (the cut, the corner
	# pylons and their footings). The rocks' placement rule does not ensure it.
	var reach := Vector2.ZERO
	for surface: int in perimeter.get_surface_count():
		for at: Vector3 in perimeter.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			reach = _widen_reach(reach, _out_of(field, at))
	var closest := Vector2(INF, INF)
	for surface: int in view.rocks.mesh.get_surface_count():
		for at: Vector3 in view.rocks.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			var out := _out_of(field, at)
			if out.x > 0.0 and out.y > 0.0:
				closest.y = minf(closest.y, out.length())
			else:
				closest.x = minf(closest.x, out.length())
	check(closest.x > reach.x and closest.y > reach.y,
		"the rocks keep off the perimeter: nearest %.2f out beside a side (it reaches %.2f), %.2f in a corner (%.2f)"
		% [closest.x, reach.x, closest.y, reach.y])
	# Nor inside a mesa's reach: its fillet's outer edge in the direction of each vertex.
	var gap := INF
	for surface: int in view.rocks.mesh.get_surface_count():
		for at: Vector3 in view.rocks.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
			for k: int in view.mesas.size():
				var away := Vector2(at.x - view.mesas[k].x, at.z - view.mesas[k].y)
				# The outline reaches at most 1.18 radii from the middle.
				if away.length() < view.mesas[k].z * 1.18 + BaseView.MESA_FOOT + BaseView.MESA_APRON + 1.0:
					var profile := view.mesa_profile(k, away.angle())
					gap = minf(gap, away.length() - profile[profile.size() - 1].x)
	check(gap > 0.0, "the rocks keep off the mesas: the nearest vertex %.2f outside a mesa's reach" % gap)
	# Each side by the screen corner it faces, and its outward direction in world x and z.
	var sides := {"top-left": Vector2(-1, 0), "top-right": Vector2(0, -1), "bottom-right": Vector2(1, 0),
		"bottom-left": Vector2(0, 1)}
	for side: String in sides:
		var out: Vector2 = sides[side]
		# The lowest and highest ground, and the nearest and farthest the relief is full.
		var heights := Vector2(INF, -INF)
		var full := Vector2(INF, -INF)
		for k: int in 40:
			var along := Vector2(out.y, out.x) * field.end * ((k + 0.5) / 20.0 - 1.0)
			var at := out * (field.end + Vector2.ONE * EDGE_OUT) + along
			var height := view.terrain_height(at.x, at.y)
			var full_out := view.blend_end(at.x, at.y)
			heights = Vector2(minf(heights.x, height), maxf(heights.y, height))
			full = Vector2(minf(full.x, full_out), maxf(full.y, full_out))
		check(heights.y - heights.x > EDGE_SPREAD and heights.y <= EDGE_HIGHEST and full.y - full.x > BLEND_WANDER,
			"%.1f out from the %s side the ground is %.2f to %.2f high, its relief full %.1f to %.1f out"
			% [EDGE_OUT, side, heights.x, heights.y, full.x, full.y])
	await _shot(main, "start", Vector3.ZERO, main.camera.size)
	var far := field.position + Vector2.ONE * EDGE_VIEW
	await _shot(main, "far-sides", Vector3(far.x, 0.0, far.y), IsoCamera.START_ZOOM_SIZE)
	_check_edge_step(main)
	await _shot(main, "closest-field", view.cell_to_world(Vector2i(13, 13), 1), IsoCamera.MIN_ZOOM_SIZE)
	# Cells (16, 32) are a corner of the field texture's tiles, which are 4 cells square.
	var tile_corner := field.position + Vector2(16, 32)
	await _shot(main, "tile-corner", Vector3(tile_corner.x, 0.0, tile_corner.y), IsoCamera.MIN_ZOOM_SIZE)
	await _shot(main, "tiles", view.cell_to_world(Vector2i(16, 30), 1), 12.0)
	main.camera.bounds = field.grow(BaseView.TERRAIN_EXTENT - field.end.x)
	var curb := field.end + Vector2.ONE * (BaseView.CURB_GAP + BaseView.CURB_WIDTH * 0.5)
	for side: String in sides:
		var out: Vector2 = sides[side]
		await _shot(main, "edge-" + side, Vector3(out.x * curb.x, 0.0, out.y * curb.y), 16.0)
	await _shot(main, "perimeter-side", Vector3(0.0, 0.0, curb.y), IsoCamera.MIN_ZOOM_SIZE)
	await _shot(main, "perimeter-corner", Vector3(curb.x, 0.0, curb.y), IsoCamera.MIN_ZOOM_SIZE)
	main.camera.bounds = field
	main.get_window().size = WIDE
	main.camera.zoom_at(main.camera.size / IsoCamera.MAX_ZOOM_SIZE, Vector2.ZERO)
	for corner: Vector2 in [field.position, field.end, field.end * Vector2(1, -1), field.end * Vector2(-1, 1)]:
		main.camera.focus = Vector3(corner.x, 0.0, corner.y)
		main.camera.nudge(Vector3.ZERO)
		check(_ring_fills_view(view, main.camera, float(WIDE.x) / WIDE.y),
			"the ring fills a %s view at the widest zoom focused on %s" % [WIDE, corner])
	await _shot(main, "widest-wide", Vector3.ZERO, IsoCamera.MAX_ZOOM_SIZE)
	_check_field_shade(main)
	main.get_window().size = WIDER
	main.camera.focus = Vector3(field.end.x, 0.0, field.end.y)
	main.camera.nudge(Vector3.ZERO)
	check(not _ring_fills_view(view, main.camera, float(WIDER.x) / WIDER.y),
		"a %s view at the widest zoom focused on %s sees past the ring" % [WIDER, field.end])
	await _shot(main, "widest-wider", Vector3(field.end.x, 0.0, field.end.y), IsoCamera.MAX_ZOOM_SIZE)
	# The haze band lies across the lower left of the sky: the field's left corner in a wider window.
	main.get_window().size = WIDEST
	var left := Vector3(field.position.x, 0.0, field.end.y)
	await _shot(main, "widest-haze", left, IsoCamera.MAX_ZOOM_SIZE)
	say("haze shot in a %s window" % main.get_window().size)
	main.get_window().size = WIDE
	main.camera.bounds = field.grow(BaseView.TERRAIN_EXTENT - field.end.x)
	await _shot(main, "crater", Vector3(view.craters[0].x, 0.0, view.craters[0].y), 24.0)
	await _shot(main, "outcrop", view.outcrop_spots[0], 12.0)
	# The first mesa's wall where it faces the camera (+x, +z), its foot and its rim.
	var mesa := view.mesas[0]
	var facing := Vector3(mesa.x, mesa.w * 0.5, mesa.y) + Vector3(1.0, 0.0, 1.0).normalized() * mesa.z
	await _shot(main, "mesa", facing, IsoCamera.MIN_ZOOM_SIZE)
	await _shot(main, "mesas", Vector3(mesa.x, mesa.w * 0.5, mesa.y), 24.0)
	# Its foot where it faces the camera, half way out along the fillet, and the middle of its ledge.
	var turn := PI * 0.25
	var profile := view.mesa_profile(0, turn)
	var out := Vector3(cos(turn), 0.0, sin(turn))
	var foot := Vector3(mesa.x, 0.0, mesa.y) + out * (profile[BaseView.MESA_FILLET_TOP].x + profile[profile.size() - 1].x) * 0.5
	await _shot(main, "mesa-foot", Vector3(foot.x, view.terrain_height(foot.x, foot.z), foot.z), IsoCamera.MIN_ZOOM_SIZE)
	var ledge := view.mesa_ledges[0]
	turn = ledge.x + ledge.y * 0.5
	profile = view.mesa_profile(0, turn)
	out = Vector3(cos(turn), 0.0, sin(turn))
	var step := profile[BaseView.MESA_RIM + 2]
	await _shot(main, "mesa-ledge", Vector3(mesa.x, step.y, mesa.y) + out * step.x, 12.0)
	main.camera.bounds = field


## Whether the field renders in the ring's shade (docs/reference/art-style.md, **Colour**): the
## average colour of SHADE_BOX round each of FIELD_QUARTERS and of RING_FLATS on the frame just
## shown, each in sRGB, agree within SHADE_L in HSL lightness and SHADE_S in saturation. Each box's
## average is first divided by the macro value noise's factor at its middle (_macro), which the
## field and the ring share but which lies differently at the two sets of spots, so the check
## compares their tints (the factor shows one for one in the rendered sRGB values: measured with
## the noise off, each box renders its average over the factor, within 1/255). A rendered run
## only: a headless one draws nothing.
func _check_field_shade(main: MainScript) -> void:
	if harness.headless:
		say("the field's shade against the ring's skipped (headless)")
		return
	var image := main.get_viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / main.get_viewport().get_visible_rect().size
	var hsl: Array[Vector2] = []
	for spots: Array[Vector3] in [FIELD_QUARTERS, RING_FLATS]:
		var sum := Color(0, 0, 0)
		for at: Vector3 in spots:
			var corner := Vector2i(main.camera.unproject_position(at) * scale) - SHADE_BOX / 2
			var box := Color(0, 0, 0)
			for y: int in SHADE_BOX.y:
				for x: int in SHADE_BOX.x:
					box += image.get_pixelv(corner + Vector2i(x, y))
			sum += box / float(SHADE_BOX.x * SHADE_BOX.y) / _macro(main.base_view, at)
		var average := sum / float(spots.size())
		var high := maxf(average.r, maxf(average.g, average.b))
		var low := minf(average.r, minf(average.g, average.b))
		var lightness := (high + low) * 0.5
		hsl.append(Vector2(lightness, (high - low) / (1.0 - absf(2.0 * lightness - 1.0))))
	check(absf(hsl[0].x - hsl[1].x) <= SHADE_L and absf(hsl[0].y - hsl[1].y) <= SHADE_S,
		"in the widest shot the field renders L %.3f S %.3f, the ring's flats L %.3f S %.3f"
		% [hsl[0].x, hsl[0].y, hsl[1].x, hsl[1].y])


## The macro value noise's factor on the ground's tint at `at`, as ground.gdshader and
## terrain.gdshader take it (MACRO either way on a lattice MACRO_CELLS cells across, field_marks'
## value_noise on the field's cells).
func _macro(view: BaseView, at: Vector3) -> float:
	var p := (Vector2(at.x, at.z) - view.area().position) / MACRO_CELLS
	var i := p.floor() + Vector2(50.0, 50.0)
	var f := p - p.floor()
	f = f * f * (Vector2(3.0, 3.0) - 2.0 * f)
	var noise := lerpf(lerpf(_cell_tone(i), _cell_tone(i + Vector2(1, 0)), f.x),
		lerpf(_cell_tone(i + Vector2(0, 1)), _cell_tone(i + Vector2(1, 1)), f.x), f.y)
	return 1.0 + MACRO * (2.0 * noise - 1.0)


## field_marks' cell_tone: a hash of a cell in [0, 1).
func _cell_tone(cell: Vector2) -> float:
	var p := Vector2(fposmod(cell.x * 0.1031, 1.0), fposmod(cell.y * 0.1030, 1.0))
	p += Vector2.ONE * p.dot(Vector2(p.y, p.x) + Vector2(33.33, 33.33))
	return fposmod((p.x + p.y) * p.x, 1.0)


## Whether the field meets the ring without a step in tone (docs/reference/art-style.md, **Colour**):
## on each of EDGE_SIDES, on the frame just shown, the per-channel median of the boxes EDGE_IN inside
## the field's edge and of those EDGE_IN outside it, every EDGE_EVERY cells along the side where
## both lie on screen clear of the HUD's controls (_hud_rects), so the marks fall out, differ by
## under EDGE_STEP in every channel. A rendered run only: a headless one draws nothing.
func _check_edge_step(main: MainScript) -> void:
	if harness.headless:
		say("the step at the field's edge skipped (headless)")
		return
	var image := main.get_viewport().get_texture().get_image()
	var scale := Vector2(image.get_size()) / main.get_viewport().get_visible_rect().size
	var screen := Rect2i(Vector2i.ZERO, image.get_size())
	var hud := _hud_rects(main, scale)
	var field := main.base_view.area()
	for side: String in EDGE_SIDES:
		var out: Vector2 = EDGE_SIDES[side]
		var along := Vector2(absf(out.y), absf(out.x))
		var edge := absf(out.dot(field.end))
		var span := int(along.dot(field.end))
		# Each channel's pixels inside the edge, then outside it.
		var pixels: Array[Array] = [[], [], [], [], [], []]
		var points := 0
		for k: int in range(-span + EDGE_EVERY, span, EDGE_EVERY):
			var boxes: Array[Rect2i] = []
			for depth: float in [-EDGE_IN, EDGE_IN]:
				var at := out * (edge + depth) + along * k
				var middle := Vector2i(main.camera.unproject_position(Vector3(at.x, 0.0, at.y)) * scale)
				boxes.append(Rect2i(middle - EDGE_BOX / 2, EDGE_BOX))
			var covered := false
			for box: Rect2i in boxes:
				covered = covered or not screen.encloses(box)
				for control: Rect2i in hud:
					covered = covered or control.intersects(box)
			if covered:
				continue
			points += 1
			for b: int in 2:
				for y: int in EDGE_BOX.y:
					for x: int in EDGE_BOX.x:
						var pixel := image.get_pixelv(boxes[b].position + Vector2i(x, y))
						for c: int in 3:
							pixels[b * 3 + c].append(pixel[c])
		var medians: Array[Color] = []
		var step := 0
		for b: int in 2:
			var median := Color()
			for c: int in 3:
				var channel := pixels[b * 3 + c]
				channel.sort()
				median[c] = channel[channel.size() / 2] if points > 0 else 0.0
			medians.append(median)
		for c: int in 3:
			step = maxi(step, absi(roundi(medians[0][c] * 255.0) - roundi(medians[1][c] * 255.0)))
		check(points > 0 and step < EDGE_STEP,
			"at the start zoom the %s side's ground is %s inside the edge, %s outside, at %d points: a step of %d/255"
			% [side, medians[0].to_html(false), medians[1].to_html(false), points, step])


## The HUD's controls over the world on a fresh base, in image pixels: the top bar's meters and
## drone ring, the Build button, and in a debug build the Template base and Reset base buttons.
func _hud_rects(main: MainScript, scale: Vector2) -> Array[Rect2i]:
	var hud := main.hud
	var controls: Array[Control] = [hud.drones_panel(), hud.build_button(), hud.template_button(), hud.reset_button()]
	for res: String in main.catalog.resources:
		controls.append(hud.resource_panel(res))
	var rects: Array[Rect2i] = []
	for control: Control in controls:
		if control != null and control.is_visible_in_tree():
			var rect := control.get_global_rect()
			rects.append(Rect2i(Rect2(rect.position * scale, rect.size * scale)))
	return rects


## Mesa `k`'s own triangles in the terrain's body (BaseView.mesa_indices), its points merged by
## place, since the wall's bands have points of their own: every edge is shared by two triangles
## but along the fillet's outer edge, whose points lie MESA_SINK under the ground (terrain_height);
## no triangle is degenerate; every other point, and MESA_SAMPLES inside each triangle (the sunk
## edge raised to the ground), lies on terrain_height within MESA_FIT; and the rim, sampled every
## degree, is within MESA_RIM_RISE of the top.
func _check_mesa(view: BaseView, k: int) -> void:
	var arrays := view.terrain.mesh.surface_get_arrays(0)
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var span := view.mesa_indices[k]
	# Each place's id, and whether it lies MESA_SINK under the ground.
	var ids: Dictionary[Vector3i, int] = {}
	var sunk: Array[bool] = []
	var off := 0
	var worst := 0.0
	var degenerate := 0
	var edges: Dictionary[Vector2i, int] = {}
	for t: int in range(span.x, span.y, 3):
		var corners := PackedInt32Array()
		for c: int in 3:
			var at := points[index[t + c]]
			var key := Vector3i((at * 1000.0).round())
			if not ids.has(key):
				ids[key] = ids.size()
				var below := view.terrain_height(at.x, at.z) - at.y
				sunk.append(absf(below - BaseView.MESA_SINK) < 0.01)
				if not sunk[sunk.size() - 1]:
					worst = maxf(worst, absf(below))
					if absf(below) > MESA_FIT:
						off += 1
			corners.append(ids[key])
		var a := points[index[t]]
		if (points[index[t + 1]] - a).cross(points[index[t + 2]] - a).length() < 1e-5:
			degenerate += 1
		for weights: Vector3 in MESA_SAMPLES:
			var inside := Vector3.ZERO
			for c: int in 3:
				var lift := BaseView.MESA_SINK if sunk[corners[c]] else 0.0
				inside += (points[index[t + c]] + Vector3(0.0, lift, 0.0)) * weights[c]
			var miss := absf(view.terrain_height(inside.x, inside.z) - inside.y)
			worst = maxf(worst, miss)
			if miss > MESA_FIT:
				off += 1
		for c: int in 3:
			var edge := Vector2i(mini(corners[c], corners[(c + 1) % 3]), maxi(corners[c], corners[(c + 1) % 3]))
			edges[edge] = edges.get(edge, 0) + 1
	var open := 0
	var stray := 0
	var crowded := 0
	for edge: Vector2i in edges:
		if edges[edge] == 1:
			open += 1
			if not (sunk[edge.x] and sunk[edge.y]):
				stray += 1
		elif edges[edge] > 2:
			crowded += 1
	var mesa := view.mesas[k]
	var rim := Vector2(INF, -INF)
	for degree: int in 360:
		var height := view.mesa_profile(k, deg_to_rad(degree))[BaseView.MESA_RIM].y
		rim = Vector2(minf(rim.x, height), maxf(rim.y, height))
	check(open > 0 and stray == 0 and crowded == 0 and degenerate == 0 and off == 0
		and rim.x >= mesa.w - BaseView.MESA_RIM_RISE - 0.001 and rim.y <= mesa.w + BaseView.MESA_RIM_RISE + 0.001,
		("mesa %d: %d triangles, %d open edges (%d off the fillet's sunk edge), %d edges in more than two, "
		+ "%d degenerate, %d points off terrain_height (by %.3f at most, points and inside triangles), the rim %.2f to %.2f high on a top at %.2f")
		% [k, (span.y - span.x) / 3, open, stray, crowded, degenerate, off, worst, rim.x, rim.y, mesa.w])


## How far a point lies outside the field along x and along z (0 within its span).
func _out_of(field: Rect2, at: Vector3) -> Vector2:
	return (Vector2(absf(at.x), absf(at.z)) - field.end).max(Vector2.ZERO)


## `reach` (beside the sides, in the corners) widened to take in a point `out` out of the field.
func _widen_reach(reach: Vector2, out: Vector2) -> Vector2:
	if out.x > 0.0 and out.y > 0.0:
		return Vector2(reach.x, maxf(reach.y, out.length()))
	return Vector2(maxf(reach.x, out.length()), reach.y)


## Whether the ray from every corner of the camera's view, `aspect` wide, meets the terrain: marched
## in half-unit steps, it enters the terrain's extent above the ground (not under its raised edge)
## and meets the ground before it leaves the extent.
func _ring_fills_view(view: BaseView, camera: IsoCamera, aspect: float) -> bool:
	var basis := camera.global_basis
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var at := camera.global_position + (basis.x * corner.x * aspect + basis.y * corner.y) * camera.size * 0.5
		var above := false
		var inside := false
		for _step: int in 600:
			inside = maxf(absf(at.x), absf(at.z)) <= BaseView.TERRAIN_EXTENT
			if (inside and at.y <= view.terrain_height(at.x, at.z)) or (above and not inside):
				break
			above = above or inside
			at -= basis.z * 0.5
		if not (above and inside):
			return false
	return true


## Centres the view on `at` at camera size `size`, then screenshots it once the window caught up.
func _shot(main: MainScript, name: String, at: Vector3, size: float) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / size, centre)
	main.camera.pan(centre, centre - main.camera.unproject_position(at))
	await frames(6)
	await screenshot(name)
