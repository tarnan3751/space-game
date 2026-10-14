class_name LowPolyMesh
extends RefCounted
## Builds one flat-shaded ArrayMesh surface out of simple parts. Every face has vertices and a
## normal of its own (nothing is shared across faces, so the shading is flat) and UVs at one
## Palette cell, so a whole model is a single surface drawn with Palette.material().
##
## A part is placed by `pos`, the centre of its base (an orb's centre), and `rot`, Euler
## degrees applied Z, then X, then Y (Godot's default order); its size arguments scale it.
## Round parts are lathes: a profile of (radius, height) points spun around +Y in `sides`
## steps. Bottom faces are left out, since the camera always looks down on the base.

var _vertices := PackedVector3Array()
var _normals := PackedVector3Array()
var _uvs := PackedVector2Array()


func triangle_count() -> int:
	return _vertices.size() / 3


## The mesh, with the palette material on its one surface. Call once the parts are added.
func to_mesh() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, Palette.material())
	return mesh


## `offset` turned by `rot` (Euler degrees, as for the parts), to place a part on a turned one.
static func turn(offset: Vector3, rot: Vector3) -> Vector3:
	return _basis(rot) * offset


# --- Faces -----------------------------------------------------------------------

## One face. Corners are counter-clockwise seen from the front.
func triangle(a: Vector3, b: Vector3, c: Vector3, color: String) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var uv := Palette.uv(color)
	# Godot's front faces wind clockwise.
	_vertices.append(a)
	_vertices.append(c)
	_vertices.append(b)
	for i: int in 3:
		_normals.append(normal)
		_uvs.append(uv)


## A flat convex face; corners counter-clockwise seen from the front.
func polygon(corners: PackedVector3Array, color: String) -> void:
	for i: int in range(1, corners.size() - 1):
		triangle(corners[0], corners[i], corners[i + 1], color)


# --- Parts -----------------------------------------------------------------------

func box(size: Vector3, pos: Vector3, color: String, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := _basis(rot)
	var h := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var c: Array[Vector3] = []
	for corner: Vector3 in [
		Vector3(-h.x, 0, -h.z), Vector3(h.x, 0, -h.z), Vector3(h.x, 0, h.z), Vector3(-h.x, 0, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z),
	]:
		c.append(pos + basis * corner)
	polygon(PackedVector3Array([c[4], c[7], c[6], c[5]]), color)
	polygon(PackedVector3Array([c[1], c[5], c[6], c[2]]), color)
	polygon(PackedVector3Array([c[3], c[7], c[4], c[0]]), color)
	polygon(PackedVector3Array([c[2], c[6], c[7], c[3]]), color)
	polygon(PackedVector3Array([c[0], c[4], c[5], c[1]]), color)


## A ramp: full height along its -Z edge, sloping to nothing along its +Z edge.
func wedge(size: Vector3, pos: Vector3, color: String, rot: Vector3 = Vector3.ZERO) -> void:
	var basis := _basis(rot)
	var h := Vector3(size.x * 0.5, size.y, size.z * 0.5)
	var back_low_l := pos + basis * Vector3(-h.x, 0, -h.z)
	var back_low_r := pos + basis * Vector3(h.x, 0, -h.z)
	var back_top_l := pos + basis * Vector3(-h.x, h.y, -h.z)
	var back_top_r := pos + basis * Vector3(h.x, h.y, -h.z)
	var front_l := pos + basis * Vector3(-h.x, 0, h.z)
	var front_r := pos + basis * Vector3(h.x, 0, h.z)
	polygon(PackedVector3Array([back_top_l, front_l, front_r, back_top_r]), color)
	polygon(PackedVector3Array([back_low_l, back_top_l, back_top_r, back_low_r]), color)
	triangle(back_low_r, back_top_r, front_r, color)
	triangle(front_l, back_top_l, back_low_l, color)


## A box from `from` to `to`, `width` thick: legs, braces, pipes, rails.
func strut(from: Vector3, to: Vector3, width: float, color: String) -> void:
	var along := to - from
	var length := along.length()
	if length <= 0.0:
		return
	var dir := along / length
	var pitch := rad_to_deg(acos(clampf(dir.y, -1.0, 1.0)))
	var yaw := rad_to_deg(atan2(dir.x, dir.z))
	box(Vector3(width, length, width), from, color, Vector3(pitch, yaw, 0))


## A cylinder with `sides` faces, tapering from `bottom_radius` to `top_radius`.
func prism(bottom_radius: float, top_radius: float, height: float, sides: int, pos: Vector3,
		color: String, rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array([Vector2(bottom_radius, 0)])
	if top_radius > 0.0:
		profile.append(Vector2(top_radius, height))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, color, rot)


func cone(radius: float, height: float, sides: int, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(radius, 0.0, height, sides, pos, color, rot)


## A four-sided cone whose square base is `width` across, edges along X and Z.
func pyramid(width: float, height: float, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(width * 0.5 * sqrt(2.0), 0.0, height, 4, pos, color, rot + Vector3(0, 45, 0))


## A hemisphere squashed to `height`, in `rings` bands.
func dome(radius: float, height: float, sides: int, rings: int, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array()
	for k: int in rings:
		var angle := PI * 0.5 * k / rings
		profile.append(Vector2(radius * cos(angle), height * sin(angle)))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, color, rot)


## A sphere centred on `pos`, in `rings` bands from pole to pole.
func orb(radius: float, sides: int, rings: int, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array([Vector2(0, -radius)])
	for k: int in range(1, rings):
		var angle := PI * k / rings - PI * 0.5
		profile.append(Vector2(radius * cos(angle), radius * sin(angle)))
	profile.append(Vector2(0, radius))
	lathe(profile, sides, pos, color, rot)


## A flat annulus with walls: a band, a collar, a hoop.
func ring(inner_radius: float, outer_radius: float, height: float, sides: int, pos: Vector3,
		color: String, rot: Vector3 = Vector3.ZERO) -> void:
	lathe(PackedVector2Array([
		Vector2(outer_radius, 0), Vector2(outer_radius, height),
		Vector2(inner_radius, height), Vector2(inner_radius, 0),
	]), sides, pos, color, rot)


## A flat regular polygon facing up: a pad marking, a glow plate.
func disc(radius: float, sides: int, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	var basis := _basis(rot)
	var corners := PackedVector3Array()
	for j: int in range(sides - 1, -1, -1):
		var angle := TAU * j / sides
		corners.append(pos + basis * Vector3(radius * cos(angle), 0, radius * sin(angle)))
	polygon(corners, color)


## Spins `profile` (x = radius, y = height, from the bottom outside up) around +Y. A point at
## radius 0 closes the shape: a flat cap when it is level with its neighbour, else an apex.
func lathe(profile: PackedVector2Array, sides: int, pos: Vector3, color: String,
		rot: Vector3 = Vector3.ZERO) -> void:
	var basis := _basis(rot)
	var last := profile.size() - 1
	var flat_top := profile[last].x == 0.0 and last > 0 and profile[last - 1].y == profile[last].y
	for j: int in sides:
		var a0 := TAU * j / sides
		var a1 := TAU * (j + 1) / sides
		for i: int in last:
			var p := profile[i]
			var q := profile[i + 1]
			if p.x == 0.0 and q.x == 0.0:
				continue
			if flat_top and i == last - 1:
				continue
			var lower_a := pos + basis * Vector3(p.x * cos(a0), p.y, p.x * sin(a0))
			var lower_b := pos + basis * Vector3(p.x * cos(a1), p.y, p.x * sin(a1))
			var upper_b := pos + basis * Vector3(q.x * cos(a1), q.y, q.x * sin(a1))
			var upper_a := pos + basis * Vector3(q.x * cos(a0), q.y, q.x * sin(a0))
			if p.x == 0.0:
				triangle(lower_a, upper_a, upper_b, color)
			elif q.x == 0.0:
				triangle(lower_a, upper_a, lower_b, color)
			else:
				polygon(PackedVector3Array([lower_a, upper_a, upper_b, lower_b]), color)
	if flat_top:
		var r := profile[last - 1].x
		var y := profile[last].y
		var cap := PackedVector3Array()
		for j: int in range(sides - 1, -1, -1):
			var angle := TAU * j / sides
			cap.append(pos + basis * Vector3(r * cos(angle), y, r * sin(angle)))
		polygon(cap, color)


static func _basis(rot: Vector3) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z)))
