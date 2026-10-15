class_name ConstructionDrone
extends Node3D
## The builder drone over a building that is being constructed or upgraded
## (docs/reference/art-style.md, **Construction drone**). Its BuildingView spawns it when the
## building turns busy and drives it each frame (advance); when the building is done the drone
## leaves, rising out of sight, and frees itself.
##
## It arrives from above the footprint's centre, then cycles: it orbits the site, banking into
## the turn and facing its motion; swoops to hover over a work point on the building, tilts its
## nose down and cuts at the point with a laser that throws sparks; and climbs back to the orbit.
##
## A work point lies on the surface of what the site shows (the scaffold or the model): at spawn
## the faces of its body mesh that face the camera (normal . view > WORK_FACING, up-facing ones
## included) and reach between WORK_LOW and WORK_HIGH of its height are kept, and each shot
## picks one of them, a height in that band and a point across the face at that height, from a
## hash of the building's id and the shot count, so a run repeats. The drone hovers HOVER above
## the point, nudged HOVER_OUT outward along the face's horizontal normal, with its lowest point
## (tilted to fire, at the bottom of its bob) held at least CLEARANCE above the site's top, and
## the beam slants down to the point. The orbit is held as high, so a tall site's corners stay
## clear, and so is the start of the climb when it leaves, over what the site shows by then (a
## finished level's model may be taller than the scaffold it worked on).
##
## It sits at its view's origin, the footprint's centre on the ground, and moves its children:
## the drone model (a body and its outline, built at the drone bay's size and shown SCALE times
## larger), the beam (a unit-length mesh under a node stretched
## from the emitter to the work point) and the flare at that point. That is four instances, made
## at spawn; nothing is allocated per frame. If its view is freed while it leaves (a finished
## level replaces the view), release() hands it to another parent and it drives itself.

enum Phase { ARRIVE, ORBIT, TO_WORK, FIRE, FROM_WORK, LEAVE }

const DroneModels := preload("res://src/game/models/drone.gd")

## It arrives from this far above the orbit's height over the footprint's centre.
const ARRIVE_HEIGHT := 3.5
const ARRIVE_SECONDS := 0.8
const ORBIT_HEIGHT := 1.4
## The orbit's radius is half the footprint plus this.
const ORBIT_MARGIN := 0.45
const BOB := 0.08
const BOB_PERIOD := 1.8
const BANK_DEGREES := 12.0
## Units a second, along the orbit and on average to and from a work point.
const SPEED := 0.9
const ORBIT_SECONDS := 2.2
## The model is built at the drone bay's parked drone's size and shown this much larger.
const SCALE := 1.4
## A work point is on a face towards the camera, between these shares of the site's height.
const WORK_FACING := 0.3
const WORK_LOW := 0.3
const WORK_HIGH := 0.8
## It hovers this far above a work point while it fires, this far out from the face, and with
## its lowest point at least this far above the site's top.
const HOVER := 0.9
const HOVER_OUT := 0.3
const CLEARANCE := 0.3
const TILT_DEGREES := 15.0
const FIRE_SECONDS := 1.3
const LEAVE_HEIGHT := 3.5
const LEAVE_SECONDS := 0.7
## How quickly its heading and tilt follow their targets, per second.
const TURN_RATE := 6.0

var _seed: int = 0
var _radius: float = 1.0
var _height: float = 1.0
## The work faces: three corners each, and one normal each.
var _faces: PackedVector3Array = PackedVector3Array()
var _face_normals: PackedVector3Array = PackedVector3Array()
## How far the model reaches below its centre, tilted to fire.
var _drop: float = 0.0
## ORBIT_HEIGHT, or higher to clear a tall site.
var _orbit_height: float = ORBIT_HEIGHT
var _hover_normal: Vector3 = Vector3.ZERO
var _phase: Phase = Phase.ARRIVE
## Seconds into the current phase, and since spawning (the bob).
var _time: float = 0.0
var _clock: float = 0.0
var _angle: float = 0.0
var _shots: int = 0
## Where it is, without the bob; a move between two points goes from _from to _to.
var _path: Vector3 = Vector3.ZERO
var _from: Vector3 = Vector3.ZERO
var _to: Vector3 = Vector3.ZERO
var _duration: float = 1.0
var _work: Vector3 = Vector3.ZERO
var _yaw: float = 0.0
var _pitch: float = 0.0
var _roll: float = 0.0
var _body: Node3D
var _beam: Node3D
var _flare: MeshInstance3D


## Call once, before adding to the tree: `id` seeds the work points, `size` is the footprint's
## in cells and `site` what is shown there (the scaffold or the model, its body the first child).
func setup(id: int, size: int, site: Node3D) -> void:
	_seed = id
	_radius = size * 0.5 + ORBIT_MARGIN
	_find_faces(site)
	_body = BuildingModels.create_drone()
	var bounds := (_body.get_child(0) as MeshInstance3D).mesh.get_aabb()
	var tilted := Basis(Vector3.RIGHT, deg_to_rad(TILT_DEGREES)) * SCALE
	for corner: int in 8:
		_drop = maxf(_drop, -(tilted * bounds.get_endpoint(corner)).y)
	_orbit_height = maxf(ORBIT_HEIGHT, _clear_of(_height))
	add_child(_body)
	_beam = Node3D.new()
	_beam.add_child(BuildingModels.create_drone_effect("beam"))
	_beam.visible = false
	add_child(_beam)
	_flare = BuildingModels.create_drone_effect("flare")
	_flare.visible = false
	add_child(_flare)
	_angle = TAU * (id % 8) / 8.0
	_from = Vector3(0, _orbit_height + ARRIVE_HEIGHT, 0)
	_to = _orbit_point(_angle)
	_path = _from
	_yaw = atan2(_to.x, _to.z)
	_place(0.0)


func _ready() -> void:
	# Its view drives it until release().
	set_process(false)


func _process(delta: float) -> void:
	advance(delta)


## Moves it on by `delta` seconds. False once it has left and freed itself.
func advance(delta: float) -> bool:
	_time += delta
	_clock += delta
	var last := _path
	match _phase:
		Phase.ARRIVE:
			_path = _from.lerp(_to, _ease_out(_time / ARRIVE_SECONDS))
			if _time >= ARRIVE_SECONDS:
				_begin(Phase.ORBIT)
		Phase.ORBIT:
			_angle += SPEED / _radius * delta
			_path = _orbit_point(_angle)
			if _time >= ORBIT_SECONDS:
				_work = _work_point()
				_shots += 1
				var hover := _work + Vector3(0, HOVER, 0) + _hover_normal * HOVER_OUT
				hover.y = maxf(hover.y, _clear_of(_height))
				_move_to(hover, Phase.TO_WORK)
		Phase.TO_WORK, Phase.FROM_WORK:
			_path = _from.lerp(_to, _ease_in_out(_time / _duration))
			if _time >= _duration:
				if _phase == Phase.TO_WORK:
					_begin(Phase.FIRE)
					_beam.visible = true
					_flare.visible = true
					_flare.position = _work
				else:
					_begin(Phase.ORBIT)
		Phase.FIRE:
			if _time >= FIRE_SECONDS:
				_beam.visible = false
				_flare.visible = false
				_angle = atan2(_path.z, _path.x)
				_move_to(_orbit_point(_angle), Phase.FROM_WORK)
		Phase.LEAVE:
			var t := minf(_time / LEAVE_SECONDS, 1.0)
			_path = _from + Vector3(0, LEAVE_HEIGHT * t * t, 0)
			if _time >= LEAVE_SECONDS:
				queue_free()
				return false
	_place(delta, last)
	return true


## Ends the work: it stops firing, climbs out of sight and frees itself. Once only. The climb
## starts no lower than clear of `site_top`, the top of what the site shows now: it is lifted
## there at once, so it is never inside a model that has just replaced the scaffold.
func leave(site_top: float) -> void:
	if _phase == Phase.LEAVE:
		return
	_beam.visible = false
	_flare.visible = false
	_from = _path
	_from.y = maxf(_from.y, _clear_of(site_top))
	_path = _from
	_place(0.0, _path)
	_begin(Phase.LEAVE)


## Moves it under `parent`, where it stays put in the world and drives itself: its view is about
## to be freed. Whoever releases it then tells it to leave.
func release(parent: Node) -> void:
	reparent(parent)
	set_process(true)


## The top of a site (a scaffold or a model, its body the first child), at its scale.
static func top_of(site: Node3D) -> float:
	return (site.get_child(0) as MeshInstance3D).mesh.get_aabb().end.y * site.scale.y


func is_leaving() -> bool:
	return _phase == Phase.LEAVE


## Whether the laser is on.
func is_firing() -> bool:
	return _phase == Phase.FIRE


## The drone model's position, in this node's space.
func drone_position() -> Vector3:
	return _body.position


## The site's top, in this node's space.
func site_height() -> float:
	return _height


## How far the model reaches below its centre, tilted to fire.
func reach_below() -> float:
	return _drop


## The beam's ends, in this node's space: the emitter and the work point.
func beam_ends() -> PackedVector3Array:
	return PackedVector3Array([_beam.position, _beam.position + _beam.basis.y])


func _begin(phase: Phase) -> void:
	_phase = phase
	_time = 0.0


func _move_to(target: Vector3, phase: Phase) -> void:
	_from = _path
	_to = target
	_duration = maxf(_from.distance_to(_to) / SPEED, 0.5)
	_begin(phase)


func _orbit_point(angle: float) -> Vector3:
	return Vector3(cos(angle) * _radius, _orbit_height, sin(angle) * _radius)


## The lowest height of its centre that keeps every part of it, tilted and at the bottom of its
## bob, CLEARANCE above `top`.
func _clear_of(top: float) -> float:
	return top + CLEARANCE + _drop + BOB


## Keeps the faces of the site's body mesh, at the site's scale, that face the camera and
## reach into the work band; once, at spawn.
func _find_faces(site: Node3D) -> void:
	var mesh := (site.get_child(0) as MeshInstance3D).mesh
	_height = top_of(site)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var view := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0)).z
	for i: int in range(0, vertices.size(), 3):
		var normal := (normals[i] + normals[i + 1] + normals[i + 2]).normalized()
		var a := vertices[i] * site.scale
		var b := vertices[i + 1] * site.scale
		var c := vertices[i + 2] * site.scale
		if normal.dot(view) <= WORK_FACING or minf(a.y, minf(b.y, c.y)) > WORK_HIGH * _height \
				or maxf(a.y, maxf(b.y, c.y)) < WORK_LOW * _height:
			continue
		_faces.append(a)
		_faces.append(b)
		_faces.append(c)
		_face_normals.append(normal)


## A point on one of the work faces, from the hash of the building's id and the shot count: a
## height within both the band and the face, then a point along the face's line at that height
## (or across the face, when it is level). Also sets the face's outward direction for the hover.
func _work_point() -> Vector3:
	var h := _mix(_seed * 7919 + _shots)
	var g := _mix(h)
	var u := float(g & 0xFFFF) / 0xFFFF
	var v := float((g >> 16) & 0xFFFF) / 0xFFFF
	if _face_normals.is_empty():
		# A site with nothing towards the camera in the band (none is built so): its centre.
		_hover_normal = Vector3.ZERO
		return Vector3(0, lerpf(WORK_LOW, WORK_HIGH, u) * _height, 0)
	var face := h % _face_normals.size()
	var a := _faces[face * 3]
	var b := _faces[face * 3 + 1]
	var c := _faces[face * 3 + 2]
	var normal := _face_normals[face]
	_hover_normal = Vector3(normal.x, 0, normal.z)
	_hover_normal = _hover_normal.normalized() if _hover_normal.length() > 0.05 else Vector3.ZERO
	var low := maxf(WORK_LOW * _height, minf(a.y, minf(b.y, c.y)))
	var high := minf(WORK_HIGH * _height, maxf(a.y, maxf(b.y, c.y)))
	if high - low < 0.001:
		# A level face: a point across it.
		if u + v > 1.0:
			u = 1.0 - u
			v = 1.0 - v
		return a + (b - a) * u + (c - a) * v
	var y := lerpf(low, high, u)
	# Where the plane at y crosses the face's edges: two points, the line across the face.
	var first := Vector3.ZERO
	var second := Vector3.ZERO
	var found := 0
	for edge: int in 3:
		var p := _faces[face * 3 + edge]
		var q := _faces[face * 3 + (edge + 1) % 3]
		if found < 2 and p.y != q.y and (y - p.y) * (y - q.y) <= 0.0:
			var crossing := p.lerp(q, (y - p.y) / (q.y - p.y))
			if found == 0:
				first = crossing
			else:
				second = crossing
			found += 1
	return first.lerp(second if found == 2 else first, v)


## Sets the model's transform from the path, the bob and an attitude that eases towards its
## target: facing its motion across the ground, banked on the orbit, nose down while firing.
func _place(delta: float, last: Vector3 = Vector3.ZERO) -> void:
	var weight := 1.0 - exp(-TURN_RATE * delta)
	var motion := _path - last
	motion.y = 0.0
	if delta > 0.0 and motion.length() > 0.02 * delta:
		_yaw = lerp_angle(_yaw, atan2(motion.x, motion.z), weight)
	var bank := deg_to_rad(BANK_DEGREES) if _phase == Phase.ORBIT else 0.0
	var tilt := deg_to_rad(TILT_DEGREES) if _phase == Phase.FIRE else 0.0
	_roll = lerpf(_roll, bank, weight)
	_pitch = lerpf(_pitch, tilt, weight)
	var attitude := Basis(Vector3.UP, _yaw) * Basis(Vector3.RIGHT, _pitch) * Basis(Vector3.BACK, _roll) * SCALE
	var bob := Vector3(0, BOB * sin(TAU * _clock / BOB_PERIOD), 0)
	_body.transform = Transform3D(attitude, _path + bob)
	if _beam.visible:
		var emitter := _body.transform * DroneModels.EMITTER
		var length := _work - emitter
		var side := length.cross(Vector3.RIGHT).normalized()
		_beam.transform = Transform3D(Basis(side, length, side.cross(length.normalized())), emitter)


static func _ease_out(t: float) -> float:
	var left := 1.0 - minf(t, 1.0)
	return 1.0 - left * left


static func _ease_in_out(t: float) -> float:
	var s := minf(t, 1.0)
	return s * s * (3.0 - 2.0 * s)


## A 32-bit integer hash.
static func _mix(value: int) -> int:
	var x := value & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
	x = ((x ^ (x >> 16)) * 0x45D9F3B) & 0xFFFFFFFF
	return x ^ (x >> 16)
