extends HarnessScenario
## The environment on a fresh base (docs/reference/art-style.md, **Environment**). Checks that the
## terrain, the curb, the rocks and the outcrops are each a body with an ink outline that casts no
## shadow (the terrain's and the curb's bodies none either); the terrain's triangle budget; that no
## part of an outcrop comes within OUTCROP_GAP of the field; that along each side of the field,
## EDGE_OUT units out, the ground is uneven (its height spreads by more than EDGE_SPREAD) and low
## (never over EDGE_HIGHEST), and the distance at which the relief is full (BaseView.blend_end)
## wanders by more than BLEND_WANDER; and that at the widest zoom in a WIDE window, the focus at
## each corner of its bounds, the ray from every screen corner meets the terrain. Screenshots: the
## start zoom, the closest on the field, the closest on a point where four of the field texture's
## tiles meet (nothing should show where they do), a wider stretch of the field, the curb at the
## middle of each side, the widest in the WIDE window, and a crater and an outcrop centred (for the
## curb, the crater and the outcrop the camera's bounds are widened, as a player cannot centre the
## view off the field).

const TERRAIN_BUDGET := 35000
const OUTCROP_GAP := 4.0
const EDGE_OUT := 3.0
const EDGE_SPREAD := 0.1
const EDGE_HIGHEST := 0.4
const BLEND_WANDER := 3.0
const WIDE := Vector2i(1560, 720)


func run(main: MainScript) -> void:
	var view := main.base_view
	var off := GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Each: the body, its outline, and whether the body may cast a shadow.
	var pairs := {"terrain": [view.terrain, view.terrain_outline, false],
		"curb": [view.boundary, view.boundary_outline, false], "rocks": [view.rocks, view.rocks_outline, true],
		"outcrops": [view.outcrops, view.outcrops_outline, true]}
	for name: String in pairs:
		var body: MeshInstance3D = pairs[name][0]
		var outline: MeshInstance3D = pairs[name][1]
		check(body != null and body.mesh != null and outline != null and outline.mesh != null
			and outline.cast_shadow == off and outline.mesh.surface_get_material(0) == MaterialKit.ink()
			and (pairs[name][2] or body.cast_shadow == off), "the %s: a body and an ink outline, no shadow" % name)
	var triangles := view.terrain.mesh.get_faces().size() / 3
	check(triangles <= TERRAIN_BUDGET, "the terrain has %d triangles, within %d" % [triangles, TERRAIN_BUDGET])
	var field := view.area()
	var nearest := INF
	for at: Vector3 in view.outcrops.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
		nearest = minf(nearest, (Vector2(absf(at.x), absf(at.z)) - field.end).max(Vector2.ZERO).length())
	check(nearest >= OUTCROP_GAP, "%d outcrops, the nearest %.1f from the field" % [view.outcrop_spots.size(), nearest])
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
			"%.0f out from the %s side the ground is %.2f to %.2f high, its relief full %.1f to %.1f out"
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
	main.camera.bounds = field
	main.get_window().size = WIDE
	main.camera.zoom_at(main.camera.size / IsoCamera.MAX_ZOOM_SIZE, Vector2.ZERO)
	for corner: Vector2 in [field.position, field.end, field.end * Vector2(1, -1), field.end * Vector2(-1, 1)]:
		main.camera.focus = Vector3(corner.x, 0.0, corner.y)
		main.camera.nudge(Vector3.ZERO)
		check(_ring_fills_view(view, main.camera, float(WIDE.x) / WIDE.y),
			"the ring fills a %s view at the widest zoom focused on %s" % [WIDE, corner])
	await _shot(main, "widest-wide", Vector3.ZERO, IsoCamera.MAX_ZOOM_SIZE)
	main.camera.bounds = field.grow(BaseView.TERRAIN_EXTENT - field.end.x)
	await _shot(main, "crater", Vector3(view.craters[0].x, 0.0, view.craters[0].y), 24.0)
	await _shot(main, "outcrop", view.outcrop_spots[0], 12.0)
	main.camera.bounds = field


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
