extends HarnessScenario
## The environment on a fresh base (docs/reference/art-style.md, **Environment**). Checks that the
## terrain, the perimeter, the rocks and the outcrops are each a body with an ink outline that casts
## no shadow (the terrain's body none either, the perimeter's one); that the perimeter's body is two
## surfaces, the toon's and the holograms' (its fence); that the background is a sky drawn by a
## shader; that no rock or rubble vertex comes within the perimeter's reach out of the field, beside
## the sides or in the corners (its own vertices' farthest); the terrain's triangle budget; that no part of an outcrop comes within OUTCROP_GAP of the
## field; that along each side of the field, EDGE_OUT units out, the ground is uneven (its height
## spreads by more than EDGE_SPREAD) and low (never over EDGE_HIGHEST), and the distance at which
## the relief is full (BaseView.blend_end) wanders by more than BLEND_WANDER; that at the widest
## zoom in a WIDE window, the focus at each corner of its bounds, the ray from every screen corner
## meets the terrain; and that in a WIDER window, focused on the field's nearest corner, it does
## not, so the sky shows; and, rendered only, that in the widest shot the field's quarters and two
## flat stretches of the ring average to the same shade (_check_field_shade). Screenshots: the
## start zoom, the closest on the field, the closest on a point where four of the field texture's
## tiles meet (nothing should show where they do), a wider stretch of the field, the perimeter at
## the middle of each side, a side and a corner of it at the closest zoom, the widest in the WIDE
## window and in the WIDER one on the nearest corner (stars beyond the ring, no bare colour), the
## widest in the WIDEST one on the field's left corner (the sky's haze band beyond the ring's lower
## left), a crater, an outcrop and the first mesa's wall centred
## (its foot and rim), then the mesa wider (for the perimeter, the crater, the outcrop and the mesa
## the camera's bounds are widened, as a player cannot centre the view off the field).

const TERRAIN_BUDGET := 38000
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
const FIELD_QUARTERS: Array[Vector3] = [Vector3(-10, 0, -10), Vector3(10, 0, -10), Vector3(10, 0, 10),
	Vector3(-10, 0, 10)]
const RING_FLATS: Array[Vector3] = [Vector3(9, 0, -26.5), Vector3(26, 0, -9.5)]
const SHADE_BOX := Vector2i(80, 40)
const SHADE_L := 0.01
const SHADE_S := 0.02


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
	await _shot(main, "closest-field", view.cell_to_world(Vector2i(9, 9), 1), IsoCamera.MIN_ZOOM_SIZE)
	# Cells (12, 28) are a corner of the field texture's tiles, which are 4 cells square.
	var tile_corner := field.position + Vector2(12, 28)
	await _shot(main, "tile-corner", Vector3(tile_corner.x, 0.0, tile_corner.y), IsoCamera.MIN_ZOOM_SIZE)
	await _shot(main, "tiles", view.cell_to_world(Vector2i(12, 26), 1), 12.0)
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
	main.camera.bounds = field


## Whether the field renders in the ring's shade (docs/reference/art-style.md, **Colour**): the
## average colour of SHADE_BOX round each of FIELD_QUARTERS and of RING_FLATS on the frame just
## shown, each in sRGB, agree within SHADE_L in HSL lightness and SHADE_S in saturation. A
## rendered run only: a headless one draws nothing.
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
			for y: int in SHADE_BOX.y:
				for x: int in SHADE_BOX.x:
					sum += image.get_pixelv(corner + Vector2i(x, y))
		var average := sum / float(spots.size() * SHADE_BOX.x * SHADE_BOX.y)
		var high := maxf(average.r, maxf(average.g, average.b))
		var low := minf(average.r, minf(average.g, average.b))
		var lightness := (high + low) * 0.5
		hsl.append(Vector2(lightness, (high - low) / (1.0 - absf(2.0 * lightness - 1.0))))
	check(absf(hsl[0].x - hsl[1].x) <= SHADE_L and absf(hsl[0].y - hsl[1].y) <= SHADE_S,
		"in the widest shot the field renders L %.3f S %.3f, the ring's flats L %.3f S %.3f"
		% [hsl[0].x, hsl[0].y, hsl[1].x, hsl[1].y])


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
