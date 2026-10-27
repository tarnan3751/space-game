class_name LowPolyMesh
extends RefCounted
## Builds a model out of simple parts painted from the material kit
## (docs/reference/art-style.md): the body mesh, drawn with MaterialKit.toon() (its HOLO parts in
## a second surface on MaterialKit.holo()), and its ink outline, a second mesh drawn with
## MaterialKit.ink(). Both are unindexed triangle lists.
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
## layer and the flags, the vertex colour the tint and, in its alpha, the phase. A flat part
## has a normal per face; a smooth part averages the normals of its faces that meet at less than
## SMOOTH_ANGLE, so curves shade smoothly while caps and chamfers stay hard.
##
## The outline holds the triangles of every part whose Surf has outline on and none of
## Surf.NO_OUTLINE's flags, with the face normals averaged by position across the whole mesh, so
## the hull the ink shader pushes out along them stays closed at hard edges. Each part's line is
## `ink` times the full width, as `ink` was when the part was added: 1.0, the full line, but on
## the figures' parts (Figures.FIGURE_INK and FIGURE_INK_MASS). It goes into the outline's UV as
## the line's thinning, 1 - ink, so a mesh without UV draws the full line.
##
## A part added while a Motion is set (set_motion) moves in the shaders (Surf.MOVE) about the
## pivot set with it, on the animation clock, as BuildingView moves a moving part's node: it spins,
## swings or slides, eased. The motion goes into CUSTOM0 and CUSTOM3 (four floats a vertex each,
## Motion.channel0 and channel3) on the body and the outline, which a mesh with no moving part leaves
## out, so the part is part of the one mesh and costs no draw of its own (the gunship's rotors).
## stamp_motion() does the same to a moving part built on its own, with its pivot at its origin,
## and append_arrays() merges it into a model's body (BuildingModels folds its idle parts so).
##
## A part added while `rig` is set turns with a rig channel (Rig, Surf.RIG): rig is the part's own
## joint (pivot x, y, z, channel), rig2 the joint it hangs from, so a shin turns about the knee and
## then, with the thigh, about the hip. They go into CUSTOM1 and CUSTOM2 (four floats a vertex
## each) on the body and the outline, which a mesh with no rigged part leaves out; the shaders turn
## the part by the angle its channel takes from the battle instance's state (INSTANCE_CUSTOM).
##
## A socket (socket()) is a named point with a direction on the model, in the mesh's own space (a
## moving part's own, for a socket on a moving part), carrying the rig stamps current when it was
## added, so a muzzle on a rigged arm can be posed as the arm is (Rig.posed).
##
## `detail`, below 1, builds a far version of a model: every round part with that share of its
## sides (at least MIN_SIDES, never more than asked) and its rings (at least MIN_RINGS), and its
## smooth parts smoothed up to 65 degrees (FAR_SMOOTH_COS), so the fewer sides still shade as a curve. The
## battle draws its units from such a version at the wider zooms (UnitModels.meshes).

## Faces of a smooth part that meet at a smaller angle than this share normals.
const SMOOTH_ANGLE := 40.0
const SMOOTH_COS := 0.766
## A far version's (detail below 1) least sides and rings, and its smoothing angle.
const MIN_SIDES := 6
const MIN_RINGS := 2
const FAR_SMOOTH_COS := 0.423
## Corners closer than this (world units) are one point when normals are averaged.
const WELD := 0.001
## The custom vertex channels and their format shifts, in step.
const CUSTOM_CHANNELS: Array[int] = [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]
const CUSTOM_SHIFTS: Array[int] = [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT,
	Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]

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
## Per triangle: `ink` when it was added.
var _inks := PackedFloat32Array()
## Per triangle: 0, or 1 + the index in _move_list of the motion it was added with; the list holds
## each motion's two channels (CUSTOM0, CUSTOM3) as two entries.
var _move_of := PackedByteArray()
var _move_list := PackedVector4Array()
## Per triangle: 0, or 1 + the index in _rig_list of the pair (rig, rig2) it was added with; the
## list holds each pair as two entries.
var _rig_of := PackedByteArray()
var _rig_list := PackedVector4Array()

## The share of the full ink width the parts added from now on are outlined at: 1.0, the full
## line, but where a caller thins it for its own parts and puts it back after.
var ink: float = 1.0
## Flags added to every part added from now on (Surf.flags), as `ink` is kept: none, but where a
## caller sets Surf.BOB for a hovering unit's whole build, its figures' parts included, and puts
## it back after.
var flags: int = 0
## A tint the parts added from now on take in place of their own (Surf.tint), as `ink` is kept:
## none (alpha 0), but where a caller paints a whole figure one colour, a hologram's.
var tint := Color(0, 0, 0, 0)
## The spin given to the parts added from now on, as `ink` is kept: (pivot x, y, z, radians a
## second) about the mesh's +Y; a zero rate, the default, spins nothing. Sets the motion
## (set_motion) to a Motion.spin about +Y.
var spin: Vector4 = Vector4.ZERO:
	set(value):
		spin = value
		set_motion(Vector3(value.x, value.y, value.z), Motion.spin(Vector3.UP, value.w) if value.w != 0.0 else null)
## The motion given to the parts added from now on (set_motion), null for none, and its pivot.
var _motion: Motion = null
var _motion_pivot := Vector3.ZERO
## The rig given to the parts added from now on, as `ink` is kept: the part's own joint (pivot x,
## y, z, channel; Rig.part) and the joint it hangs from (rig2); channel 0, the default, turns
## nothing.
var rig: Vector4 = Vector4.ZERO
var rig2: Vector4 = Vector4.ZERO
## The share of their sides and rings round parts are built with; set before the first part.
var detail: float = 1.0
## The named points added with socket(), by name.
var sockets: Dictionary[String, Socket] = {}


## A named point on a model with the direction it faces (a muzzle and where it fires), in the
## mesh's own space, and the rig stamps it was added under (LowPolyMesh.rig and rig2).
class Socket:
	extends RefCounted
	var position := Vector3.ZERO
	var direction := Vector3.FORWARD
	var rig := Vector4.ZERO
	var rig2 := Vector4.ZERO


## Adds the socket `name` at `position` facing `direction`, turning with the rig set now.
func socket(name: String, position: Vector3, direction: Vector3) -> void:
	var s := Socket.new()
	s.position = position
	s.direction = direction.normalized()
	s.rig = rig
	s.rig2 = rig2
	sockets[name] = s


## Moves the parts added from now on as `motion` says about `pivot` (in the mesh's space), in the
## shaders, as `ink` is kept; a null motion, the default, moves nothing.
func set_motion(pivot: Vector3, motion: Motion) -> void:
	_motion = motion
	_motion_pivot = pivot


## Whether any part added carries the surface flag `flag` (Surf).
func has_flag(flag: int) -> bool:
	for uv2: Vector2 in _uv2s:
		if (roundi(uv2.y) & flag) != 0:
			return true
	return false


## Triangles in the body mesh, both surfaces.
func triangle_count() -> int:
	return _vertices.size() / 3


## The body: the opaque parts on the toon material, then, when there are any, the HOLO parts
## on the hologram material, each a surface; with no opaque part the holograms are surface 0.
## Call once the parts are added.
func to_mesh() -> ArrayMesh:
	return body_mesh(to_arrays(), holo_arrays())


## A body from its opaque surface's arrays and its HOLO surface's (to_arrays, holo_arrays, or
## merged ones, append_arrays), each a surface when it has a triangle, on the toon and the hologram
## material.
static func body_mesh(opaque: Array, holo: Array) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var surfaces: Array[Array] = [opaque, holo]
	for k: int in surfaces.size():
		var arrays := surfaces[k]
		if arrays.is_empty() or (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format_of(arrays))
		mesh.surface_set_material(mesh.get_surface_count() - 1, MaterialKit.holo() if k == 1 else MaterialKit.toon())
	return mesh


## The HOLO parts' surface arrays, as to_arrays() gives the others'; empty when there is none.
func holo_arrays() -> Array:
	return _select(true) if _has_holo() else []


## The opaque body's surface arrays (vertex, normal, UV, UV2, colour, and the motions' CUSTOM0 and
## CUSTOM3 when a part moves), for a caller that merges meshes itself (WallMesh); HOLO parts are left
## out.
func to_arrays() -> Array:
	if _has_holo():
		return _select(false)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _vertices
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_TEX_UV2] = _uv2s
	arrays[Mesh.ARRAY_COLOR] = _colors
	if not _move_list.is_empty() or not _rig_list.is_empty():
		var triangles := PackedInt32Array()
		for i: int in _vertices.size():
			triangles.append(i / 3)
		_add_moves(arrays, triangles)
		_add_rigs(arrays, triangles)
	return arrays


## The format flags add_surface_from_arrays takes for these arrays: CUSTOM0 and CUSTOM3 as four
## floats a vertex when a part moves, CUSTOM1 and CUSTOM2 likewise when a part is rigged, else none.
func format() -> int:
	var bits := 0
	if not _move_list.is_empty():
		bits |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
		bits |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT
	if not _rig_list.is_empty():
		bits |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
		bits |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT
	return bits


## The format flags for surface arrays as they are: four floats a vertex for each custom channel
## they carry.
static func format_of(arrays: Array) -> int:
	var bits := 0
	for c: int in CUSTOM_CHANNELS.size():
		if typeof(arrays[CUSTOM_CHANNELS[c]]) != TYPE_NIL:
			bits |= Mesh.ARRAY_CUSTOM_RGBA_FLOAT << CUSTOM_SHIFTS[c]
	return bits


## The ink outline, with the ink material; null when no part is outlined.
func to_outline_mesh() -> ArrayMesh:
	return outline_mesh(to_outline_arrays())


## An outline from its surface arrays (to_outline_arrays, or merged ones), with the ink material;
## null when they are empty.
static func outline_mesh(arrays: Array) -> ArrayMesh:
	if arrays.is_empty():
		return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, format_of(arrays))
	mesh.surface_set_material(0, MaterialKit.ink())
	return mesh


## The outline's surface arrays (vertex, normal, each part's UV2 and colour, which carry the flags
## and the phase, so the ink shader moves the outline with a bobbing or jittering part, its
## UV, which carries its line's thinning, (1 - ink, 0), the motions' CUSTOM0 and CUSTOM3 when a part
## moves and the rigs' CUSTOM1 and CUSTOM2 when a part is rigged); empty when no part is outlined.
func to_outline_arrays() -> Array:
	var vertices := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var triangles := PackedInt32Array()
	var sums: Dictionary[Vector3i, Vector3] = {}
	for t: int in _outlined.size():
		if _outlined[t] == 0:
			continue
		var thinning := Vector2(1.0 - _inks[t], 0.0)
		for i: int in range(t * 3, t * 3 + 3):
			vertices.append(_vertices[i])
			uvs.append(thinning)
			uv2s.append(_uv2s[i])
			colors.append(_colors[i])
			triangles.append(t)
			var key := _weld(_vertices[i])
			var sum: Vector3 = sums.get(key, Vector3.ZERO)
			sums[key] = sum + _face_normals[t] * _corner_angle(i)
	if vertices.is_empty():
		return []
	var normals := PackedVector3Array()
	for vertex: Vector3 in vertices:
		normals.append(sums[_weld(vertex)].normalized())
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	_add_moves(arrays, triangles)
	_add_rigs(arrays, triangles)
	return arrays


## The CUSTOM0 and CUSTOM3 channels for vertices of the triangles `triangles` (one entry a vertex),
## into `arrays`: each triangle's motion (Motion.channel0 and channel3), zeros where it does not
## move. Nothing when no part moves.
func _add_moves(arrays: Array, triangles: PackedInt32Array) -> void:
	if _move_list.is_empty():
		return
	var first := PackedFloat32Array()
	var second := PackedFloat32Array()
	first.resize(triangles.size() * 4)
	second.resize(triangles.size() * 4)
	for i: int in triangles.size():
		var k := _move_of[triangles[i]]
		var a := _move_list[(k - 1) * 2] if k > 0 else Vector4.ZERO
		var b := _move_list[(k - 1) * 2 + 1] if k > 0 else Vector4.ZERO
		for c: int in 4:
			first[i * 4 + c] = a[c]
			second[i * 4 + c] = b[c]
	arrays[Mesh.ARRAY_CUSTOM0] = first
	arrays[Mesh.ARRAY_CUSTOM3] = second


## Stamps surface arrays of a part built in its own space, its pivot at the origin (to_arrays,
## holo_arrays, to_outline_arrays of a moving part), with `motion` about `pivot`: its vertices
## moved by the pivot into the model's space, Surf.MOVE on every vertex and the motion in CUSTOM0
## and CUSTOM3, so the shaders move it as BuildingView would move its node. The normals, the
## outline's averaged ones included, are kept as they are. Empty arrays are left alone.
static func stamp_motion(arrays: Array, pivot: Vector3, motion: Motion) -> void:
	if arrays.is_empty():
		return
	assert(typeof(arrays[Mesh.ARRAY_CUSTOM0]) == TYPE_NIL, "a part already moving in the shaders cannot be stamped again")
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
	var moved := PackedVector3Array()
	moved.resize(vertices.size())
	var flagged := PackedVector2Array()
	flagged.resize(uv2s.size())
	for i: int in vertices.size():
		moved[i] = vertices[i] + pivot
		flagged[i] = Vector2(uv2s[i].x, roundi(uv2s[i].y) | Surf.MOVE)
	var first := motion.channel0(pivot)
	var second := motion.channel3()
	var c0 := PackedFloat32Array()
	var c3 := PackedFloat32Array()
	c0.resize(vertices.size() * 4)
	c3.resize(vertices.size() * 4)
	for i: int in vertices.size():
		for c: int in 4:
			c0[i * 4 + c] = first[c]
			c3[i * 4 + c] = second[c]
	arrays[Mesh.ARRAY_VERTEX] = moved
	arrays[Mesh.ARRAY_TEX_UV2] = flagged
	arrays[Mesh.ARRAY_CUSTOM0] = c0
	arrays[Mesh.ARRAY_CUSTOM3] = c3


## Surface arrays that are `into` followed by `more` (both of the kit's layout: vertex, normal, UV,
## UV2 and colour, the outline's or the body's, and any custom channels), the custom channels
## that only one carries filled with zeros for the other's vertices. `into` may be empty. Neither
## is changed.
static func append_arrays(into: Array, more: Array) -> Array:
	if more.is_empty():
		return into
	if into.is_empty():
		return more
	var count := (into[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var added := (more[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	var vertices: PackedVector3Array = into[Mesh.ARRAY_VERTEX].duplicate()
	vertices.append_array(more[Mesh.ARRAY_VERTEX])
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var normals: PackedVector3Array = into[Mesh.ARRAY_NORMAL].duplicate()
	normals.append_array(more[Mesh.ARRAY_NORMAL])
	arrays[Mesh.ARRAY_NORMAL] = normals
	for slot: int in [Mesh.ARRAY_TEX_UV, Mesh.ARRAY_TEX_UV2]:
		var pairs: PackedVector2Array = into[slot].duplicate()
		pairs.append_array(more[slot])
		arrays[slot] = pairs
	var colors: PackedColorArray = into[Mesh.ARRAY_COLOR].duplicate()
	colors.append_array(more[Mesh.ARRAY_COLOR])
	arrays[Mesh.ARRAY_COLOR] = colors
	for slot: int in CUSTOM_CHANNELS:
		var in_into := typeof(into[slot]) != TYPE_NIL
		var in_more := typeof(more[slot]) != TYPE_NIL
		if not in_into and not in_more:
			continue
		var channel := PackedFloat32Array()
		if in_into:
			channel.append_array(into[slot])
		else:
			channel.resize(count * 4)
		if in_more:
			channel.append_array(more[slot])
		else:
			channel.resize((count + added) * 4)
		arrays[slot] = channel
	return arrays


## The CUSTOM1 and CUSTOM2 channels for vertices of the triangles `triangles` (one entry a
## vertex), into `arrays`: each triangle's rig and rig2, zeros where it is not rigged. Nothing when
## no part is rigged.
func _add_rigs(arrays: Array, triangles: PackedInt32Array) -> void:
	if _rig_list.is_empty():
		return
	var inner := PackedFloat32Array()
	var outer := PackedFloat32Array()
	inner.resize(triangles.size() * 4)
	outer.resize(triangles.size() * 4)
	for i: int in triangles.size():
		var k := _rig_of[triangles[i]]
		var a := _rig_list[(k - 1) * 2] if k > 0 else Vector4.ZERO
		var b := _rig_list[(k - 1) * 2 + 1] if k > 0 else Vector4.ZERO
		for c: int in 4:
			inner[i * 4 + c] = a[c]
			outer[i * 4 + c] = b[c]
	arrays[Mesh.ARRAY_CUSTOM1] = inner
	arrays[Mesh.ARRAY_CUSTOM2] = outer


## Whether any part is a hologram.
func _has_holo() -> bool:
	for uv2: Vector2 in _uv2s:
		if (roundi(uv2.y) & Surf.HOLO) != 0:
			return true
	return false


## The surface arrays of the HOLO triangles (`holo`) or of the others.
func _select(holo: bool) -> Array:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colors := PackedColorArray()
	var triangles := PackedInt32Array()
	for i: int in _vertices.size():
		if ((roundi(_uv2s[i].y) & Surf.HOLO) != 0) == holo:
			vertices.append(_vertices[i])
			normals.append(_normals[i])
			uvs.append(_uvs[i])
			uv2s.append(_uv2s[i])
			colors.append(_colors[i])
			triangles.append(i / 3)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colors
	_add_moves(arrays, triangles)
	_add_rigs(arrays, triangles)
	return arrays


## `offset` turned by `rot` (Euler degrees, as for the parts), to place a part on a turned one.
static func turn(offset: Vector3, rot: Vector3) -> Vector3:
	return _basis(rot) * offset


# --- Faces -----------------------------------------------------------------------

## One face. Corners are counter-clockwise seen from the front. Built directly, with no arrays
## along the way, for meshes made of many single faces (the scenery's rocks); the UVs are the
## planar ones _face gives, and a single face has nothing to smooth.
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


## A cylinder with `sides` faces, tapering from `bottom_radius` to `top_radius`; swept from
## `from_deg` to `to_deg` only, as lathe() says, for a half-vault.
func prism(bottom_radius: float, top_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO, from_deg: float = 0.0, to_deg: float = 360.0) -> void:
	var profile := PackedVector2Array([Vector2(bottom_radius, 0)])
	if top_radius > 0.0:
		profile.append(Vector2(top_radius, height))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, surf, rot, from_deg, to_deg)


func cone(radius: float, height: float, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(radius, 0.0, height, sides, pos, surf, rot)


## A four-sided cone whose square base is `width` across, edges along X and Z.
func pyramid(width: float, height: float, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	prism(width * 0.5 * sqrt(2.0), 0.0, height, 4, pos, surf, rot + Vector3(0, 45, 0))


## A hemisphere squashed to `height`, in `rings` bands; swept from `from_deg` to `to_deg` only,
## as lathe() says.
func dome(radius: float, height: float, sides: int, rings: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO, from_deg: float = 0.0, to_deg: float = 360.0) -> void:
	var profile := PackedVector2Array()
	rings = _rings(rings)
	for k: int in rings:
		var angle := PI * 0.5 * k / rings
		profile.append(Vector2(radius * cos(angle), height * sin(angle)))
	profile.append(Vector2(0, height))
	lathe(profile, sides, pos, surf, rot, from_deg, to_deg)


## A sphere centred on `pos`, in `rings` bands from pole to pole.
func orb(radius: float, sides: int, rings: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var profile := PackedVector2Array([Vector2(0, -radius)])
	rings = _rings(rings)
	for k: int in range(1, rings):
		var angle := PI * k / rings - PI * 0.5
		profile.append(Vector2(radius * cos(angle), radius * sin(angle)))
	profile.append(Vector2(0, radius))
	lathe(profile, sides, pos, surf, rot)


## A flat annulus with walls: a band, a collar, a hoop. Open underneath. Swept from `from_deg`
## to `to_deg` only, as lathe() says.
func ring(inner_radius: float, outer_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO, from_deg: float = 0.0, to_deg: float = 360.0) -> void:
	lathe(PackedVector2Array([
		Vector2(outer_radius, 0), Vector2(outer_radius, height),
		Vector2(inner_radius, height), Vector2(inner_radius, 0),
	]), sides, pos, surf, rot, from_deg, to_deg)


## A hollow cylinder closed at both ends: a pipe, a barrel with a bore. Unlike a ring it has
## its bottom face, so it reads from any angle when turned on its side. Swept from `from_deg`
## to `to_deg` only, as lathe() says.
func tube(inner_radius: float, outer_radius: float, height: float, sides: int, pos: Vector3,
		surf: Surf, rot: Vector3 = Vector3.ZERO, from_deg: float = 0.0, to_deg: float = 360.0) -> void:
	lathe(PackedVector2Array([
		Vector2(outer_radius, 0), Vector2(outer_radius, height),
		Vector2(inner_radius, height), Vector2(inner_radius, 0), Vector2(outer_radius, 0),
	]), sides, pos, surf, rot, from_deg, to_deg)


## A flat regular polygon facing up: a pad marking, a glow plate.
func disc(radius: float, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO) -> void:
	var start := _vertices.size()
	_fan(radius, 0.0, _sides(sides), Transform3D(_basis(rot), pos), surf, _repeats(radius, surf))
	_finish(start, surf)


## Spins `profile` (x = radius, y = height, from the bottom outside up) around +Y. A point at
## radius 0 closes the shape: a flat cap when it is level with its neighbour, else an apex.
## Given `from_deg` and `to_deg` less than a turn apart (degrees from +X towards +Z, as
## Parts.around), it sweeps only that arc, in as many of the `sides` steps as the arc spans, and
## closes each end with a flat face: the profile, closed through the axis when one of its ends
## is on it (keep that section convex). U still comes from the angle.
func lathe(profile: PackedVector2Array, sides: int, pos: Vector3, surf: Surf,
		rot: Vector3 = Vector3.ZERO, from_deg: float = 0.0, to_deg: float = 360.0) -> void:
	var start := _vertices.size()
	sides = _sides(sides)
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
	var from := 0.0
	var span := TAU
	var steps := sides
	var partial := to_deg - from_deg < 360.0
	if partial:
		from = deg_to_rad(from_deg)
		span = deg_to_rad(to_deg - from_deg)
		steps = maxi(1, roundi(sides * (to_deg - from_deg) / 360.0))
	# U from the angle; on a whole turn these are exactly repeats * j / sides.
	var u_from := repeats * (from / TAU)
	var u_span := repeats * (span / TAU)
	for j: int in steps:
		var a0 := from + span * j / steps
		var a1 := from + span * (j + 1) / steps
		var u0 := u_from + u_span * j / steps
		var u1 := u_from + u_span * (j + 1) / steps
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
		_fan(profile[last - 1].x, profile[last].y, steps, xf, surf, repeats, from, span)
	if partial:
		var section := _section(profile)
		_end_face(section, from, -1.0, xf, surf)
		_end_face(section, from + span, 1.0, xf, surf)
	_finish(start, surf)


## The cross-section a partial lathe's end faces close: `profile` closed through the axis when
## just one of its ends is on it, with repeated points dropped.
static func _section(profile: PackedVector2Array) -> PackedVector2Array:
	var first := profile[0]
	var end := profile[profile.size() - 1]
	var section := PackedVector2Array()
	if end.x == 0.0 and first.x != 0.0:
		section.append(Vector2(0.0, first.y))
	for point: Vector2 in profile:
		if section.is_empty() or point != section[section.size() - 1]:
			section.append(point)
	if first.x == 0.0 and end.x != 0.0:
		section.append(Vector2(0.0, end.y))
	if section.size() > 2 and section[0] == section[section.size() - 1]:
		section.remove_at(section.size() - 1)
	return section


## A partial lathe's end: `section` stood at `angle` round +Y, facing along the sweep's
## direction there times `onward` (-1 at its start, +1 at its end). Nothing for a section with no
## area (an open profile).
func _end_face(section: PackedVector2Array, angle: float, onward: float, xf: Transform3D, surf: Surf) -> void:
	var corners := PackedVector3Array()
	for point: Vector2 in section:
		corners.append(Vector3(point.x * cos(angle), point.y, point.x * sin(angle)))
	var out := Vector3(-sin(angle), 0.0, cos(angle)) * onward
	var facing := _newell(corners).dot(out)
	if absf(facing) < 1e-6:
		return
	if facing < 0.0:
		corners.reverse()
	_face(corners, xf, surf)


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
## (U around, V the radius): a lathe's cap or a disc. Its faces stay hard in a smooth part. A
## partial lathe's cap spans only its arc, `span` radians from `from`, in `sides` steps.
func _fan(radius: float, height: float, sides: int, xf: Transform3D, surf: Surf, repeats: int,
		from: float = 0.0, span: float = TAU) -> void:
	var centre := Vector3(0, height, 0)
	var v := radius * surf.uv_scale
	var u_from := repeats * (from / TAU)
	var u_span := repeats * (span / TAU)
	for j: int in sides:
		var a0 := from + span * j / sides
		var a1 := from + span * (j + 1) / sides
		var u0 := u_from + u_span * j / sides
		var u1 := u_from + u_span * (j + 1) / sides
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
	var moving := _motion != null
	var rigged := rig.w != 0.0 or rig2.w != 0.0
	var uv2 := Vector2(surf.layer, surf.flags | flags | (Surf.MOVE if moving else 0) | (Surf.RIG if rigged else 0))
	_uv2s.append(uv2)
	_uv2s.append(uv2)
	_uv2s.append(uv2)
	# The phase in 254 steps, a quarter step up so the 8-bit store keeps the byte whether it
	# rounds or truncates; surf_phase (effects.gdshaderinc) decodes it.
	var colour := Color(surf.tint if tint.a == 0.0 else tint, (roundi(surf.phase * 254.0) + 0.25) / 255.0)
	_colors.append(colour)
	_colors.append(colour)
	_colors.append(colour)
	_face_normals.append(normal)
	_outlined.append(1 if surf.outline and ((surf.flags | flags) & Surf.NO_OUTLINE) == 0 else 0)
	_hard.append(1 if hard else 0)
	_inks.append(ink)
	if moving:
		var first := _motion.channel0(_motion_pivot)
		var second := _motion.channel3()
		var found := -1
		for k: int in _move_list.size() / 2:
			if _move_list[k * 2] == first and _move_list[k * 2 + 1] == second:
				found = k
				break
		if found < 0:
			assert(_move_list.size() / 2 < 255, "a mesh has at most 255 motions")
			_move_list.append(first)
			_move_list.append(second)
			found = _move_list.size() / 2 - 1
		_move_of.append(found + 1)
	else:
		_move_of.append(0)
	if rigged:
		var found := -1
		for k: int in _rig_list.size() / 2:
			if _rig_list[k * 2] == rig and _rig_list[k * 2 + 1] == rig2:
				found = k
				break
		if found < 0:
			assert(_rig_list.size() / 2 < 255, "a mesh has at most 255 rigs")
			_rig_list.append(rig)
			_rig_list.append(rig2)
			found = _rig_list.size() / 2 - 1
		_rig_of.append(found + 1)
	else:
		_rig_of.append(0)


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
				if own.dot(other) >= (SMOOTH_COS if detail >= 1.0 else FAR_SMOOTH_COS):
					sum += other * _corner_angle(j)
			if sum != Vector3.ZERO:
				_normals[i] = sum.normalized()


## `sides` at this mesh's detail.
func _sides(sides: int) -> int:
	if detail >= 1.0:
		return sides
	return maxi(mini(sides, MIN_SIDES), roundi(sides * detail))


## `rings` at this mesh's detail.
func _rings(rings: int) -> int:
	if detail >= 1.0:
		return rings
	return maxi(mini(rings, MIN_RINGS), roundi(rings * detail))


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
