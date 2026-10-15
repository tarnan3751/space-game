class_name HudIcon
extends Control
## A HUD badge drawn in code, vector, from no asset file: the icon at the left end of each
## resource meter, and the drone at the centre of the drone ring (`DroneRing`)
## (docs/reference/hud.md, **Top bar**). Each part of a silhouette is a flat fill in the
## icon's colour, with a lighter highlight facet and a 2.5 px ink outline, over a 2 px ink
## offset shadow under the whole icon. The shapes are laid out in a 40-unit box, scaled to
## the rect they are painted into. A control draws only when it is built or resized, and the
## whole icon is one triangle array, so one draw call (`Pen`).

## The box the silhouettes are laid out in, in units.
const BOX := 40.0
const OUTLINE := 2.5
## Inner edges between the facets of one part.
const EDGE := 2.0
## The drone's rotors' outline: thinner, so a small rotor keeps a light disc inside its rim.
const ROTOR_OUTLINE := 1.5
const SHADOW_OFFSET := Vector2(2, 2)

## "metal", "crystal", "antimatter" or "drones"; anything else draws a plain gem.
var kind: String = ""
var color: Color = Color.WHITE


func _draw() -> void:
	var pen := Pen.new()
	paint(pen, kind, Rect2(Vector2.ZERO, size), color)
	pen.draw(self)


## Adds the `icon`, fitted to `rect`, to `pen`: every part's shadow, then the parts.
static func paint(pen: Pen, icon: String, rect: Rect2, tint: Color) -> void:
	pen.fit(rect)
	for shadow: bool in [true, false]:
		pen.shadow = shadow
		match icon:
			"metal":
				_ingot(pen, tint)
			"crystal":
				_shards(pen, tint)
			"antimatter":
				_orb(pen, tint)
			"drones":
				_drone(pen, tint)
			_:
				_gem(pen, tint)
	pen.shadow = false


## A bar seen from the front and a little above: a trapezoid front, a lighter top face and a
## darker end.
static func _ingot(pen: Pen, tint: Color) -> void:
	var front_left := Vector2(4, 32)
	var front_right := Vector2(27, 32)
	var top_left := Vector2(8, 20)
	var top_right := Vector2(23, 20)
	var depth := Vector2(8, -8)
	var outline := PackedVector2Array([front_left, front_right, front_right + depth,
		top_right + depth, top_left + depth, top_left])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([top_left, top_right, top_right + depth, top_left + depth]), tint.lightened(0.45))
	pen.facet(PackedVector2Array([front_right, top_right, top_right + depth, front_right + depth]), tint.darkened(0.25))
	pen.edge(PackedVector2Array([top_left, top_right, front_right]))
	pen.edge(PackedVector2Array([top_right, top_right + depth]))
	pen.outline(outline)


## A tall kite with a smaller one leaning on it, each with a lighter left face.
static func _shards(pen: Pen, tint: Color) -> void:
	_kite(pen, tint, Vector2(9, 11), Vector2(16, 20), Vector2(13, 36), Vector2(3, 24))
	_kite(pen, tint, Vector2(24, 3), Vector2(34, 16), Vector2(23, 37), Vector2(15, 17))


static func _kite(pen: Pen, tint: Color, top: Vector2, right: Vector2, bottom: Vector2, left: Vector2) -> void:
	var outline := PackedVector2Array([top, right, bottom, left])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([top, bottom, left]), tint.lightened(0.45))
	pen.edge(PackedVector2Array([top, bottom]))
	pen.outline(outline)


## An orb with an orbit ring tilted across it: the ring's far half behind the orb, its near
## half in front.
static func _orb(pen: Pen, tint: Color) -> void:
	var centre := Vector2(20, 20)
	var ring_radii := Vector2(18, 6.5)
	var tilt := -0.38
	var ring_color := tint.lightened(0.35)
	pen.band(_ellipse(centre, ring_radii, PI, TAU, 12, tilt), ring_color)
	var orb := _ellipse(centre, Vector2(11, 11), 0.0, TAU, 24)
	pen.shape(orb, tint)
	pen.facet(_ellipse(Vector2(16.5, 15.5), Vector2(4.5, 3.5), 0.0, TAU, 12, -0.6), tint.lightened(0.55))
	pen.outline(orb)
	pen.band(_ellipse(centre, ring_radii, 0.0, PI, 12, tilt), ring_color)


## A drone in three-quarter view, from the front-left and above: a saucer body, the icon's
## mass (a darker underside band, a lighter top facet), under a canopy, an ink eye at its front,
## and four small rotors on short arms, thinly outlined, the front two larger (a quarter of the
## box) and lower, the rear two higher and partly behind the body.
static func _drone(pen: Pen, tint: Color) -> void:
	var arm_color := tint.darkened(0.35)
	var rotor_color := tint.lightened(0.5)
	# [x, y, half width] of each rotor.
	for rear: Vector3 in [Vector3(10.5, 12.5, 3.8), Vector3(29.5, 12, 3.5)]:
		pen.band(PackedVector2Array([Vector2(20, 18), Vector2(rear.x, rear.y)]), arm_color)
		_rotor(pen, Vector2(rear.x, rear.y), rear.z, rotor_color)
	# The saucer, the icon's mass: the top face's upper half, then the underside's lower half
	# 4 lower.
	var top_centre := Vector2(20, 18.5)
	var radii := Vector2(11, 6)
	var drop := Vector2(0, 4)
	var body := _ellipse(top_centre, radii, PI, TAU, 14)
	body.append_array(_ellipse(top_centre + drop, radii, 0.0, PI, 14))
	pen.shape(body, tint)
	var rim := _ellipse(top_centre, radii, 0.0, PI, 14)
	var underside := rim.duplicate()
	var bottom := _ellipse(top_centre + drop, radii, 0.0, PI, 14)
	bottom.reverse()
	underside.append_array(bottom)
	pen.facet(underside, tint.darkened(0.3))
	pen.facet(_ellipse(Vector2(13.8, 17.5), Vector2(3, 1.6), 0.0, TAU, 10, -0.3), tint.lightened(0.45))
	pen.outline(body)
	# The canopy, a dome on the top face inked along its crown only, and the eye on the front of
	# the underside. Few inner lines, so the saucer stays a mass of colour at the ring's size.
	var dome := _ellipse(Vector2(20.5, 18), Vector2(6, 5.5), PI, TAU, 12)
	var canopy := dome.duplicate()
	canopy.append_array(_ellipse(Vector2(20.5, 18), Vector2(6, 2.2), 0.0, PI, 12))
	pen.shape(canopy, tint.lightened(0.55))
	pen.facet(_ellipse(Vector2(18.5, 15.2), Vector2(2, 1.3), 0.0, TAU, 8, -0.5), Color(1, 1, 1, 0.85))
	pen.edge(dome)
	pen.facet(_ellipse(Vector2(17, 26.6), Vector2(2.4, 1.4), 0.0, TAU, 10), Hud.INK)
	for front: Vector3 in [Vector3(33.5, 29.5, 4.8), Vector3(6.5, 30.5, 5.2)]:
		var root := Vector2(20 + signf(front.x - 20) * 8.0, 25.5)
		pen.band(PackedVector2Array([root, Vector2(front.x, front.y)]), arm_color)
		_rotor(pen, Vector2(front.x, front.y), front.z, rotor_color)


## A rotor seen from 35 degrees up: an ellipse `half_width` across each way of its centre, with
## a highlight facet and a thin outline.
static func _rotor(pen: Pen, centre: Vector2, half_width: float, fill: Color) -> void:
	var radii := Vector2(half_width, half_width * 0.56)
	var disc := _ellipse(centre, radii, 0.0, TAU, 16)
	pen.shape(disc, fill)
	pen.facet(_ellipse(centre - radii * Vector2(0.25, 0.2), radii * 0.45, 0.0, TAU, 10), Color(1, 1, 1, 0.7))
	pen.outline(disc, ROTOR_OUTLINE)


## A cut gem, for a resource with no silhouette of its own.
static func _gem(pen: Pen, tint: Color) -> void:
	var outline := PackedVector2Array([Vector2(12, 8), Vector2(28, 8), Vector2(35, 17), Vector2(20, 35), Vector2(5, 17)])
	pen.shape(outline, tint)
	pen.facet(PackedVector2Array([Vector2(12, 8), Vector2(20, 17), Vector2(5, 17)]), tint.lightened(0.45))
	pen.edge(PackedVector2Array([Vector2(5, 17), Vector2(35, 17)]))
	pen.outline(outline)


## Points along an ellipse round `centre` from angle `from` to `to`, rotated by `tilt`; a whole
## turn does not repeat its first point.
static func _ellipse(centre: Vector2, radii: Vector2, from: float, to: float, steps: int,
		tilt: float = 0.0) -> PackedVector2Array:
	var points := PackedVector2Array()
	var count := steps if is_equal_approx(to - from, TAU) else steps + 1
	for i: int in count:
		var angle := from + (to - from) * i / steps
		points.append(centre + (Vector2(cos(angle), sin(angle)) * radii).rotated(tilt))
	return points


## Builds an icon (or the drone ring) as one triangle array, so it costs one draw call: the
## renderer draws every draw_polygon and draw_polyline on its own. Shapes are given in box
## units (fit() maps the box onto a rect); in the shadow pass only shadows are added. Strokes
## and shadows get a 1 px feather that fades to nothing, in place of the renderer's
## antialiasing; fills are left hard, since their outlines cover their edges.
class Pen:
	const FEATHER := 1.0

	var shadow: bool = false
	var _origin: Vector2 = Vector2.ZERO
	var _scale: float = 1.0
	## Lines thin with the icon below full size, so a small one is not all ink.
	var _thinning: float = 1.0
	var _points: PackedVector2Array = PackedVector2Array()
	var _colors: PackedColorArray = PackedColorArray()
	var _indices: PackedInt32Array = PackedInt32Array()

	## Maps the 40-unit box onto `rect`, centred, at the scale of its shorter side.
	func fit(rect: Rect2) -> void:
		_scale = minf(rect.size.x, rect.size.y) / HudIcon.BOX
		_origin = rect.position + (rect.size - Vector2.ONE * HudIcon.BOX * _scale) * 0.5
		_thinning = clampf(_scale, 0.6, 1.0)

	## A part's silhouette: its shadow in the shadow pass, else its flat fill.
	func shape(points: PackedVector2Array, fill: Color) -> void:
		if shadow:
			add_fill(place(points, HudIcon.SHADOW_OFFSET), Hud.SHADOW, true)
		else:
			add_fill(place(points), fill, false)

	func facet(points: PackedVector2Array, fill: Color) -> void:
		if not shadow:
			add_fill(place(points), fill, false)

	## An ink line between facets.
	func edge(points: PackedVector2Array) -> void:
		if not shadow:
			add_stroke(place(points), HudIcon.EDGE * _thinning, Hud.INK, false)

	func outline(points: PackedVector2Array, width: float = HudIcon.OUTLINE) -> void:
		if not shadow:
			add_stroke(place(points), width * _thinning, Hud.INK, true)

	## An open stroke with a shadow of its own: an ink band, and a core of `fill` unless the
	## band is ink itself.
	func band(points: PackedVector2Array, fill: Color) -> void:
		var width := 5.0 * _thinning
		if shadow:
			add_stroke(place(points, HudIcon.SHADOW_OFFSET), width, Hud.SHADOW, false)
			return
		add_stroke(place(points), width, Hud.INK, false)
		if fill != Hud.INK:
			add_stroke(place(points), width - 3.0 * _thinning, fill, false)

	func place(points: PackedVector2Array, offset: Vector2 = Vector2.ZERO) -> PackedVector2Array:
		var placed := PackedVector2Array()
		for point: Vector2 in points:
			placed.append(_origin + point * _scale + offset)
		return placed

	## A filled simple polygon, in pixels; `feathered` fades its edge out over FEATHER.
	func add_fill(at: PackedVector2Array, color: Color, feathered: bool) -> void:
		var base := _points.size()
		for point: Vector2 in at:
			_points.append(point)
			_colors.append(color)
		for index: int in Geometry2D.triangulate_polygon(at):
			_indices.append(base + index)
		if not feathered:
			return
		var count := at.size()
		# The normals point out of one winding and into the other.
		var outward := -1.0 if Geometry2D.is_point_in_polygon(at[0] + _normal(at, 0, true) * 0.5, at) else 1.0
		var fringe := _points.size()
		for i: int in count:
			_points.append(at[i] + _normal(at, i, true) * _miter(at, i, true) * FEATHER * outward)
			_colors.append(Color(color, 0.0))
		for i: int in count:
			var j := (i + 1) % count
			_quad(base + i, base + j, fringe + j, fringe + i)

	## A stroke along `at`, in pixels, `width` wide, with a feather either side.
	func add_stroke(at: PackedVector2Array, width: float, color: Color, closed: bool) -> void:
		var count := at.size()
		var base := _points.size()
		var clear := Color(color, 0.0)
		for i: int in count:
			var normal := _normal(at, i, closed)
			var reach := _miter(at, i, closed)
			var half := width * 0.5 * reach
			var fade := (width * 0.5 + FEATHER) * reach
			for side: float in [fade, half, -half, -fade]:
				_points.append(at[i] + normal * side)
			_colors.append_array(PackedColorArray([clear, color, color, clear]))
		var segments := count if closed else count - 1
		for i: int in segments:
			var a := base + i * 4
			var b := base + ((i + 1) % count) * 4
			for lane: int in 3:
				_quad(a + lane, a + lane + 1, b + lane + 1, b + lane)

	## Submits everything added as one triangle array on `item`'s canvas item.
	func draw(item: CanvasItem) -> void:
		if not _indices.is_empty():
			RenderingServer.canvas_item_add_triangle_array(item.get_canvas_item(), _indices, _points, _colors)

	func _quad(a: int, b: int, c: int, d: int) -> void:
		_indices.append_array(PackedInt32Array([a, b, c, a, c, d]))

	## The unit normal at point `i`: across the line there, or between its two segments at a
	## corner.
	func _normal(at: PackedVector2Array, i: int, closed: bool) -> Vector2:
		var count := at.size()
		var before := at[i] - at[(i - 1 + count) % count] if closed or i > 0 else Vector2.ZERO
		var after := at[(i + 1) % count] - at[i] if closed or i < count - 1 else Vector2.ZERO
		var sum := before.normalized().orthogonal() + after.normalized().orthogonal()
		return sum.normalized()

	## How much farther than on a straight line an edge sits from point `i` along its normal,
	## so a corner's sides keep their width; at most 3, for a very sharp corner.
	func _miter(at: PackedVector2Array, i: int, closed: bool) -> float:
		var count := at.size()
		if not closed and (i == 0 or i == count - 1):
			return 1.0
		var after := (at[(i + 1) % count] - at[i]).normalized().orthogonal()
		return 1.0 / maxf(_normal(at, i, closed).dot(after), 1.0 / 3.0)
