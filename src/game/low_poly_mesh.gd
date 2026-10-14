class_name LowPolyMesh
extends RefCounted
## Builds a model out of simple parts painted from the material kit
## (docs/reference/art-style.md): the body mesh, drawn with MaterialKit.toon(), and its ink
## outline, a second mesh drawn with MaterialKit.ink(). Both are unindexed triangle lists.
##
## A part is placed by `pos`, the centre of its base (an orb's centre), and `rot`, Euler
## degrees applied Z, then X, then Y (Godot's default order); its size arguments scale it.
## Round parts are lathes: a profile of (radius, height) points spun around +Y in `sides`
## steps. Bottom faces are left out of boxes and lathes, since the camera always looks down on
## the base.
##
## Every part is painted with a Surf. A face's UVs are its corners' positions in the part's own
## space, before `pos` and `rot`, projected along the dominant axis of its normal and times the
## Surf's uv_scale, so a texture repeat covers one world unit by default. Round parts take U
## from the angle around their axis (a whole number of repeats around, so bands wrap) and V
## from the distance along the profile, or from the radius on a cap or a disc. UV2 carries the
## layer and the flags, the vertex colour the tint. A flat part has a normal per face; a smooth
## part averages the normals of its faces that meet at less than SMOOTH_ANGLE, so curves shade
## smoothly while caps and chamfers stay hard.
##
## The outline holds the triangles of every part whose Surf has outline on, with the face
## normals averaged by position across the whole mesh, so the hull the ink shader pushes out
## along them stays closed at hard edges.

## Faces of a smooth part that meet at a smaller angle than this share normals.
const SMOOTH_ANGLE := 40.0
const SMOOTH_COS := 0.766
## Corners closer than this (world units) are one point when normals are averaged.
const WELD := 0.001

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()
var _uv2s := PackedVector2Array()
var _colors := PackedColorArray()
## Per triangle: its flat normal, whether it is outlined, and whether it stays hard in a smooth
## part (lathe caps, discs).
var _face_normals := PackedVector3Array()
var _outlined := PackedByteArray()
var _hard := PackedByteArray()


## Triangles in the body mesh.
func triangle_count() -> int:
	return _vertices.size() / 3


## The body, with the toon material. Call once the parts are added.
func to_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_COLOR] = _colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, MaterialKit.toon())
	return mesh


## The ink outline, with the ink material; null when no part is outlined.
func to_outline_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var sums: Dictionary[Vector3i, Vector3] = {}
	for t: int in _outlined.size():
		if _outlined[t] == 0:
			continue
		for i: int in range(t * 3, t * 3 + 3):
			vertices.append(_vertices[i])
			var key := _weld(_vertices[i])
			var sum: Vector3 = sums.get(key, Vector3.ZERO)
			sums[key] = sum + _face_normals[t] * _corner_angle(i)
	if vertices.is_empty():
		return null
	var normals := PackedVector3Array()
	for vertex: Vector3 in vertices:
		normals.append(sums[_weld(vertex)].normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, MaterialKit.ink())
	return mesh


## `offset` turned by `rot` (Euler degrees, as for the parts), to place a part on a turned one.
static func turn(offset: Vector3, rot: Vector3) -> Vector3:
	return _basis(rot) * offset


# --- Faces -----------------------------------------------------------------------

## One face. Corners are counter-clockwise seen from the front. Built directly, with no arrays
## along the way, since the terrain adds some 15,000 of them; the UVs are the planar ones _face
## gives, and a single face has nothing to smooth.
func triangle(a: Vector3, b: Vector3, c: Vector3, surf: Surf) -> void:
	var facing := (b - a).cross(c - a)
	var normal := facing.normalized()
	var axis := facing.abs()
	var k := surf.uv_scale
	if axis.x >= axis.y and axis.x >= axis.z:
		var u := -signf(facing.x) * k
		_emit(a, b, c, Vector2(u * a.z, -k * a.y), Vector2(u * b.z, -k * b.y), Vector2(u * c.z, -k * c.y),
			normal, surf, false)
	elif axis.y >= axis.z:
		_emit(a, b, c, Vector2(a.x, a.z) * k, Vector2(b.x, b.z) * k, Vector2(c.x, c.z) * k, normal, surf,
			false)
	else:
		var u := signf(facing.z) * k
		_emit(a, b, c, Vector2(u * a.x, -k * a.y), Vector2(u * b.x, -k * b.y), Vector2(u * c.x, -k * c.y),
			normal, surf, false)


## A flat convex face; corners counter-clockwise seen from the front.
func polygon(corners: PackedVector3Array, surf: Surf) -> void:
	var start := _vertices.size()
	_face(corners, Transform3D.IDENTITY, surf)
	_finish(start, surf)


# --- Parts -----------------------------------------------------------------------

func box(size: Vector3, pos: Vector3, surf: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	var xf := Transform3D(_basis(rot), pos)
	var h := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var c := PackedVector3Array([
		Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	])
	_face(PackedVector3Array([c[4], c[7], c[6], c[5]]), xf, surf)
	_face(PackedVector3Array([c[1], c[5], c[6], c[2]]), xf, surf)
	_face(PackedVector3Array([c[3], c[7], c[4], c[0]]), xf, surf)
	_face(PackedVector3Array([c[2], c[6], c[7], c[3]]), xf, surf)
	_face(PackedVector3Array([c[0], c[4], c[5], c[1]]), xf, surf)
	_finish(start, surf)


## A box whose top and vertical edges are bevelled `chamfer` wide; its bottom edges stay square,
## since a part stands on something. 30 triangles.
func box_chamfered(size: Vector3, chamfer: float, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	var xf := Transform3D(_basis(rot), pos)
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var top := size.y
	var shoulder := size.y - chamfer
	var centre := Vector3(0, size.y * 0.5, 0)
	_face_out(PackedVector3Array([
		Vector3(-hx + chamfer, top, -hz + chamfer), Vector3(-hx + chamfer, top, hz - chamfer),
		Vector3(hx - chamfer, top, hz - chamfer), Vector3(hx - chamfer, top, -hz + chamfer),
	]), centre, xf, surf)
	# Each side: its face, the bevel above it, and the bevel and the corner after it, going
	# round in the order of `sides`.
	var sides: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for k: int in 4:
		var s := sides[k]
		var n := sides[(k + 1) % 4]
		if k % 2 == 0:
			# A side facing +X or -X, from corner s to corner n.
			_face_out(PackedVector3Array([
				Vector3(s.x * hx, 0, s.y * (hz - chamfer)), Vector3(s.x * hx, shoulder, s.y * (hz - chamfer)),
				Vector3(s.x * hx, shoulder, n.y * (hz - chamfer)), Vector3(s.x * hx, 0, n.y * (hz - chamfer)),
			]), centre, xf, surf)
			_face_out(PackedVector3Array([
				Vector3(s.x * hx, shoulder, s.y * (hz - chamfer)), Vector3(s.x * (hx - chamfer), top, s.y * (hz - chamfer)),
				Vector3(s.x * (hx - chamfer), top, n.y * (hz - chamfer)), Vector3(s.x * hx, shoulder, n.y * (hz - chamfer)),
			]), centre, xf, surf)
		else:
			# A side facing +Z or -Z.
			_face_out(PackedVector3Array([
				Vector3(s.x * (hx - chamfer), 0, s.y * hz), Vector3(s.x * (hx - chamfer), shoulder, s.y * hz),
				Vector3(n.x * (hx - chamfer), shoulder, s.y * hz), Vector3(n.x * (hx - chamfer), 0, s.y * hz),
			]), centre, xf, surf)
			_face_out(PackedVector3Array([
				Vector3(s.x * (hx - chamfer), shoulder, s.y * hz), Vector3(s.x * (hx - chamfer), top, s.y * (hz - chamfer)),
				Vector3(n.x * (hx - chamfer), top, s.y * (hz - chamfer)), Vector3(n.x * (hx - chamfer), shoulder, s.y * hz),
			]), centre, xf, surf)
	for s: Vector2 in sides:
		_face_out(PackedVector3Array([
			Vector3(s.x * hx, 0, s.y * (hz - chamfer)), Vector3(s.x * hx, shoulder, s.y * (hz - chamfer)),
			Vector3(s.x * (hx - chamfer), shoulder, s.y * hz), Vector3(s.x * (hx - chamfer), 0, s.y * hz),
		]), centre, xf, surf)
		_face_out(PackedVector3Array([
			Vector3(s.x * (hx - chamfer), top, s.y * (hz - chamfer)), Vector3(s.x * hx, shoulder, s.y * (hz - chamfer)),
			Vector3(s.x * (hx - chamfer), shoulder, s.y * hz),
		]), centre, xf, surf)
	_finish(start, surf)


## A ramp: full height along its -Z edge, sloping to nothing along its +Z edge.
func wedge(size: Vector3, pos: Vector3, surf: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	var xf := Transform3D(_basis(rot), pos)
	var h := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var back_low_l := Vector3(-h.x, 0, -h.z)
	var back_low_r := Vector3(h.x, 0, -h.z)
	var back_top_l := Vector3(-h.x, h.y, -h.z)
	var back_top_r := Vector3(h.x, h.y, -h.z)
	var front_l := Vector3(-h.x, 0, h.z)
	var front_r := Vector3(h.x, 0, h.z)
	_face(PackedVector3Array([back_top_l, front_l, front_r, back_top_r]), xf, surf)
	_face(PackedVector3Array([back_low_l, back_top_l, back_top_r, back_low_r]), xf, surf)
	_face(PackedVector3Array([back_low_r, back_top_r, front_r]), xf, surf)
	_face(PackedVector3Array([front_l, back_top_l, back_low_l]), xf, surf)
	_finish(start, surf)


## A box from `from` to `to`, `width` thick: legs, braces, pipes, rails.
func strut(from: Vector3, to: Vector3, width: float, surf: Surf) -> void:
	var along := to - from
	var length := along.length()
	if length <= 0.0:
		return
	var dir := along / length
	var pitch := rad_to_deg(acos(clampf(dir.y, -1.0, 1.0)))
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	box(Vector3(width, length, width), from, surf, Vector3(pitch, yaw, 0))


## A cylinder with `sides` faces, tapering from `bottom_radius` to `top_radius`.
func prism(bottom_radius: float, top_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array([Vector2(bottom_radius, 0)])
	if top_radius > 0.0:
		profile.append(Vector2(top_radius, height))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, surf, rot)


func cone(radius: float, height: float, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(radius, 0.0, height, sides, pos, surf, rot)


## A four-sided cone whose square base is `width` across, edges along X and Z.
func pyramid(width: float, height: float, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(width * 0.5 * sqrt(2.0), 0.0, height, 4, pos, surf, rot + Vector3(0, 45, 0))


## A hemisphere squashed to `height`, in `rings` bands.
func dome(radius: float, height: float, sides: int, rings: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array()
	for k: int in rings:
		var angle := PI * 0.5 * k / rings
		profile.append(Vector2(radius * cos(angle), height * sin(angle)))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, surf, rot)


## A sphere centred on `pos`, in `rings` bands from pole to pole.
func orb(radius: float, sides: int, rings: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array([Vector2(0, -radius)])
	for k: int in range(1, rings):
		var angle := PI * k / rings - PI * 0.5
		profile.append(Vector2(radius * cos(angle), radius * sin(angle)))
	profile.append(Vector2(0, radius))
	lathe(profile, sides, pos, surf, rot)


## A flat annulus with walls: a band, a collar, a hoop. Open underneath.
func ring(inner_radius: float, outer_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	lathe(PackedVector2Array([
		Vector2(outer_radius, 0), Vector2(outer_radius, height),
		Vector2(inner_radius, height), Vector2(inner_radius, 0),
	]), sides, pos, surf, rot)


## A hollow cylinder closed at both ends: a pipe, a barrel with a bore. Unlike a ring it has
## its bottom face, so it reads from any angle when turned on its side.
func tube(inner_radius: float, outer_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO) -> void:
	lathe(PackedVector2Array([
		Vector2(outer_radius, 0), Vector2(outer_radius, height),
		Vector2(inner_radius, height), Vector2(inner_radius, 0), Vector2(outer_radius, 0),
	]), sides, pos, surf, rot)


## A flat regular polygon facing up: a pad marking, a glow plate.
func disc(radius: float, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	_fan(radius, 0.0, sides, Transform3D(_basis(rot), pos), surf, _repeats(radius, surf))
	_finish(start, surf)


## Spins `profile` (x = radius, y = height, from the bottom outside up) around +Y. A point at
## radius 0 closes the shape: a flat cap when it is level with its neighbour, else an apex.
func lathe(profile: PackedVector2Array, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	var xf := Transform3D(_basis(rot), pos)
	var last := profile.size() - 1
	var flat_top := profile[last].x == 0.0 and last > 0 and profile[last - 1].y == profile[last].y
	var widest := 0.0
	var arc := PackedFloat32Array([0.0])
	for i: int in last:
		arc.append(arc[i] + profile[i].distance_to(profile[i + 1]))
	for point: Vector2 in profile:
		widest = maxf(widest, point.x)
	var repeats := _repeats(widest, surf)
	for j: int in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var u0 := repeats * float(j) / sides
		var u1 := repeats * float(j + 1) / sides
		var um := (u0 + u1) * 0.5
		for i: int in last:
			var p := profile[i]
			var q := profile[i + 1]
			if p.x == 0.0 and q.x == 0.0:
				continue
			if flat_top and i == last - 1:
				continue
			var lower_a := Vector3(p.x * cos(a0), p.y, p.x * sin(a0))
			var lower_b := Vector3(p.x * cos(a1), p.y, p.x * sin(a1))
			var upper_b := Vector3(q.x * cos(a1), q.y, q.x * sin(a1))
			var upper_a := Vector3(q.x * cos(a0), q.y, q.x * sin(a0))
			var vp := -arc[i] * surf.uv_scale
			var vq := -arc[i + 1] * surf.uv_scale
			if p.x == 0.0:
				_tri(xf * lower_a, xf * upper_a, xf * upper_b,
					Vector2(um, vp), Vector2(u0, vq), Vector2(u1, vq), surf, false)
			elif q.x == 0.0:
				_tri(xf * lower_a, xf * upper_a, xf * lower_b,
					Vector2(u0, vp), Vector2(um, vq), Vector2(u1, vp), surf, false)
			else:
				_tri(xf * lower_a, xf * upper_a, xf * upper_b,
					Vector2(u0, vp), Vector2(u0, vq), Vector2(u1, vq), surf, false)
				_tri(xf * lower_a, xf * upper_b, xf * lower_b,
					Vector2(u0, vp), Vector2(u1, vq), Vector2(u1, vp), surf, false)
	if flat_top:
		_fan(profile[last - 1].x, profile[last].y, sides, xf, surf, repeats)
	_finish(start, surf)


static func _basis(rot: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))


# --- Internals -------------------------------------------------------------------

## A flat face (a convex polygon, counter-clockwise from the front) given in a part's own
## space, UV-mapped by projection along its normal's dominant axis, then placed by `xf`.
func _face(corners: PackedVector3Array, xf: Transform3D, surf: Surf) -> void:
	var facing := _newell(corners)
	var normal := facing.abs()
	var signs := facing.sign()
	var uvs := PackedVector2Array()
	for corner: Vector3 in corners:
		var uv: Vector2
		if normal.x >= normal.y and normal.x >= normal.z:
			uv = Vector2(-signs.x * corner.z, -corner.y)
		elif normal.y >= normal.z:
			uv = Vector2(corner.x, corner.z)
		else:
			uv = Vector2(signs.z * corner.x, -corner.y)
		uvs.append(uv * surf.uv_scale)
	for i: int in range(1, corners.size() - 1):
		_tri(xf * corners[0], xf * corners[i], xf * corners[i + 1], uvs[0], uvs[i], uvs[i + 1], surf, false)


## A face of a convex part, turned to face away from `centre` whatever order its corners are in.
func _face_out(corners: PackedVector3Array, centre: Vector3, xf: Transform3D, surf: Surf) -> void:
	var middle := Vector3.ZERO
	for corner: Vector3 in corners:
		middle += corner / corners.size()
	if _newell(corners).dot(middle - centre) < 0.0:
		corners.reverse()
	_face(corners, xf, surf)


## A flat polygon of `sides` facing up at `height`, as a fan from its centre with polar UVs
## (U around, V the radius): a lathe's cap or a disc. Its faces stay hard in a smooth part.
func _fan(radius: float, height: float, sides: int, xf: Transform3D, surf: Surf, repeats: int) -> void:
	var centre := Vector3(0, height, 0)
	var v := radius * surf.uv_scale
	for j: int in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		var u0 := repeats * float(j) / sides
		var u1 := repeats * float(j + 1) / sides
		_tri(xf * centre, xf * Vector3(radius * cos(a1), height, radius * sin(a1)),
			xf * Vector3(radius * cos(a0), height, radius * sin(a0)),
			Vector2((u0 + u1) * 0.5, 0.0), Vector2(u1, v), Vector2(u0, v), surf, true)


## One triangle, corners counter-clockwise from the front, appended with its flat normal.
func _tri(a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2,
		surf: Surf, hard: bool) -> void:
	_emit(a, b, c, uv_a, uv_b, uv_c, (b - a).cross(c - a).normalized(), surf, hard)


## Appends one triangle with its flat normal. Unrolled: every triangle of every mesh comes here.
func _emit(a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2,
		normal: Vector3, surf: Surf, hard: bool) -> void:
	# Godot's front faces wind clockwise.
	_vertices.append(a)
	_vertices.append(c)
	_vertices.append(b)
	_uvs.append(uv_a)
	_uvs.append(uv_c)
	_uvs.append(uv_b)
	_normals.append(normal)
	_normals.append(normal)
	_normals.append(normal)
	var uv2 := Vector2(surf.layer, surf.flags)
	_uv2s.append(uv2)
	_uv2s.append(uv2)
	_uv2s.append(uv2)
	var tint := surf.tint
	_colors.append(tint)
	_colors.append(tint)
	_colors.append(tint)
	_face_normals.append(normal)
	_outlined.append(1 if surf.outline else 0)
	_hard.append(1 if hard else 0)


## Ends a part begun at vertex `start`: a smooth one gets its shared normals.
func _finish(start: int, surf: Surf) -> void:
	if not surf.smooth:
		return
	var groups: Dictionary[Vector3i, PackedInt32Array] = {}
	for i: int in range(start, _vertices.size()):
		if _hard[i / 3] == 1:
			continue
		var key := _weld(_vertices[i])
		if not groups.has(key):
			groups[key] = PackedInt32Array()
		groups[key].append(i)
	for members: PackedInt32Array in groups.values():
		for i: int in members:
			var own := _face_normals[i / 3]
			var sum := Vector3.ZERO
			for j: int in members:
				var other := _face_normals[j / 3]
				if own.dot(other) >= SMOOTH_COS:
					sum += other * _corner_angle(j)
			if sum != Vector3.ZERO:
				_normals[i] = sum.normalized()


## Whole texture repeats around a circle of `radius`, about one per world unit at uv_scale 1.
static func _repeats(radius: float, surf: Surf) -> int:
	return maxi(1, roundi(TAU * radius * surf.uv_scale))


## The angle of the triangle at vertex `i`, which weights its normal in an average.
func _corner_angle(i: int) -> float:
	var first := i - i % 3
	var p := _vertices[i]
	var b := _vertices[first + (i - first + 1) % 3]
	var c := _vertices[first + (i - first + 2) % 3]
	return (b - p).angle_to(c - p)


static func _weld(point: Vector3) -> Vector3i:
	return Vector3i(roundi(point.x / WELD), roundi(point.y / WELD), roundi(point.z / WELD))


## A polygon's normal by Newell's method: robust to a degenerate first corner. Not normalized.
static func _newell(corners: PackedVector3Array) -> Vector3:
	var normal := Vector3.ZERO
	for i: int in corners.size():
		var a := corners[i]
		var b := corners[(i + 1) % corners.size()]
		normal += Vector3((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y))
	return normal
