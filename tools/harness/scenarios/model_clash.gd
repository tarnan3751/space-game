extends HarnessScenario
## The clash rule's check (docs/reference/art-style.md, **The clash rule**): no moving part of a
## model crosses another over its whole motion, rigid and with BOB applied. Headless; it takes no
## screenshots.
##
## For every type and level in the catalog, built for its level's tier (BuildingModels.tier_of) as
## the gallery builds it, and for every unit type at Base and at Crown (UnitModels.create, as the
## unit gallery builds it), each moving part (a node carrying BuildingModels.MOVE_META) and the
## static body are read back from their meshes, every surface, holograms included, in the model's
## own space. Two parts cross when an edge of one's triangles crosses a triangle of the other
## (Geometry3D.segment_intersects_triangle), tested only inside the overlap of their posed bounds
## and through a spatial hash of CELL-sized cells.
##
## A part of the body that moves in the shaders (Surf.MOVE: a building's idle part folded into its
## body, the gunship's rotors) is read back as a moving part of its own, its pivot and Motion
## decoded from CUSTOM0 and CUSTOM3 (Motion.from_channels), as the shaders move it.
##
## - Every pair of moving parts is posed together on the clock, as BuildingView poses them
##   (Motion.transform_at): sampled every pair step (the smaller part's step: a SPIN's
##   SPIN_STEP degrees, a SWING's period over SWING_SAMPLES, a SLIDE's over SLIDE_SAMPLES) over the
##   longer part's cycle, or the turn of one SPIN against another about a parallel axis, at most
##   PAIR_WINDOW seconds. Any crossing fails the model.
## - Every moving part against the static body: a SPIN every SPIN_STEP degrees, a SWING at
##   SWING_POSES poses from -amplitude to +amplitude, a SLIDE at SLIDE_POSES. Counted per part as
##   the poses at which it touches the body, never failed: a built-in mount (a pivot sunk in the
##   body) is the one allowed contact, and telling a mount from a clash is the review's judgment.
## - A second pass with BOB applied, where either side has BOB vertices: each such vertex lifted
##   along Y by BOB_HEIGHT * sin(TAU * (t / BOB_PERIOD + phase)), as effects.gdshaderinc lifts it
##   (its flag the bit Surf.BOB of UV2.y, its phase round(alpha * 255) / 254 of the vertex
##   colour), on the clock with the parts' poses, at least BOB_SAMPLES samples a BOB period over
##   at least one. Pairs fail on a crossing; the body's are counted.
##
## - A moving part that rides another (BuildingModels.RIDES_META, Parts.riding) is posed on the clock
##   carried by it, as BuildingView carries it; against the body its own poses are taken with the
##   part it rides at rest, and so against the part it rides: counted as for the body ("on its
##   carrier"), not paired, since a ring round a barrel is mounted on it.
## - An aiming part (a moving part with a `muzzle` socket, which BuildingView turns towards its
##   target in battle) is also turned through a whole turn about +Y, every SPIN_STEP degrees, about
##   its pivot or the pivot of the part it rides (which turns it), and, when it pitches (a
##   `trunnion` socket), at every PITCH_STEP of its travel (BattleView.PITCH_LIMITS or
##   LOB_ELEVATION), both ends included, at each: counted against the body as its "aim sweep",
##   never failed, for the review. A pitching part's poses across its travel are also tested
##   against the part that turns it and every other moving part (as _pitch_sweep poses them),
##   counted per part as its "pitch sweep".
##
## Each model with moving parts gets one line: its parts and motions, its pair crossings and its
## poses touching the body per part.

## Degrees between the elevations a pitching part's travel is sampled at, both ends included.
const PITCH_STEP := 10.0
## Degrees a SPIN turns between samples.
const SPIN_STEP := 10.0
## Poses of a SWING and of a SLIDE against the body, both ends included.
const SWING_POSES := 9
const SLIDE_POSES := 5
## Samples a cycle of a SWING and of a SLIDE on the clock (a SMOOTH swing's 16 give nine poses).
const SWING_SAMPLES := 16
const SLIDE_SAMPLES := 8
## The longest stretch of the clock a pair is sampled over, in seconds.
const PAIR_WINDOW := 60.0
## As effects.gdshaderinc: BOB's lift and period.
const BOB_HEIGHT := 0.08
const BOB_PERIOD := 2.4
const BOB_SAMPLES := 8
## The spatial hash's cell, in model units, and the slack round an overlap.
const CELL := 0.25
const SLACK := 0.001


## A part read back from its mesh: its triangles' corners (three a triangle) in its own space,
## its distinct edges as pairs of corner indices, the corners that BOB with their phases.
class Shape:
	var points := PackedVector3Array()
	var edges := PackedInt32Array()
	var bob := PackedInt32Array()
	var phases := PackedFloat32Array()
	var box := AABB()
	var motion: Motion
	var pivot := Vector3.ZERO
	## The part it rides (Parts.riding), null for none.
	var carrier: Shape = null
	## Whether it aims in battle (its node carries a `muzzle` socket), and, for one that pitches its
	## barrels (a `trunnion` socket too), the trunnion in its own space, the axis it pitches about
	## (raising the muzzle) and its pitches across its travel, every PITCH_STEP and both ends, from its
	## built elevation.
	var aims := false
	var trunnion := Vector3.ZERO
	var pitch_axis := Vector3.RIGHT
	var pitches := PackedFloat32Array([0.0])


## Where the last crossing _edges_cross found is, in the model's space.
var _hit := Vector3.ZERO
## The run's totals: models, moving parts, pairs and pairs crossing.
var _models := 0
var _moving := 0
var _pairs := 0
var _crossings := 0


func run(main: MainScript) -> void:
	var catalog: Catalog = main.state.catalog
	for type: String in catalog.types():
		for level: int in range(1, catalog.max_level(type) + 1):
			var tier := BuildingModels.tier_of(catalog, type, level)
			_check_model("%s %d" % [type, level], BuildingModels.create(type, level, catalog.size_of(type), tier))
	for type: String in catalog.unit_types():
		for tier: int in [Parts.Tier.BASE, Parts.Tier.CROWN]:
			_check_model("unit %s at %s" % [type, str(Parts.Tier.keys()[tier]).to_lower()], UnitModels.create(type, tier))
	say("%d models, %d moving parts, %d pairs, %d crossing" % [_models, _moving, _pairs, _crossings])


## Reads back `model`'s body and moving parts, checks every pair of its moving parts and counts
## each one's poses touching the body, says it as `label`, and frees it.
func _check_model(label: String, model: Node3D) -> void:
	var type := label.get_slice(" ", 0)
	var lift := BOB_HEIGHT / model.scale.y
	var body := Shape.new()
	var parts: Array[Shape] = []
	var spins := {}
	for child: Node in model.get_children():
		if child is MeshInstance3D and not child.has_meta(BuildingModels.OUTLINE_META):
			_read((child as MeshInstance3D).mesh, body, spins)
		elif child.has_meta(BuildingModels.MOVE_META):
			var part := Shape.new()
			part.motion = child.get_meta(BuildingModels.MOVE_META)
			part.pivot = (child as Node3D).position
			if child.has_meta(BuildingModels.RIDES_META):
				part.carrier = parts[int(child.get_meta(BuildingModels.RIDES_META))]
			if child.has_meta(BuildingModels.SOCKETS_META):
				var sockets: Dictionary = child.get_meta(BuildingModels.SOCKETS_META)
				part.aims = sockets.has("muzzle")
				if part.aims and sockets.has("trunnion"):
					_travel(part, type, sockets["muzzle"], sockets["trunnion"])
			for grandchild: Node in child.get_children():
				if grandchild is MeshInstance3D and not grandchild.has_meta(BuildingModels.OUTLINE_META):
					_read((grandchild as MeshInstance3D).mesh, part)
			parts.append(part)
	for entry: Array in spins.values():
		parts.append(entry[0])
	model.free()
	_models += 1
	if parts.is_empty():
		return
	_moving += parts.size()
	var pair_hits := PackedStringArray()
	for i: int in parts.size():
		for j: int in range(i + 1, parts.size()):
			if parts[j].carrier == parts[i] or parts[i].carrier == parts[j]:
				continue
			_pairs += 1
			var at := _pair_crossing(parts[i], parts[j], 0.0)
			var with_bob := ""
			if at < 0.0 and (not parts[i].bob.is_empty() or not parts[j].bob.is_empty()):
				at = _pair_crossing(parts[i], parts[j], lift)
				with_bob = " with BOB"
			if at >= 0.0:
				pair_hits.append("parts %d and %d at %.2f s%s, at %s" % [i + 1, j + 1, at, with_bob, _hit])
	_crossings += pair_hits.size()
	var touching := PackedStringArray()
	var motions := PackedStringArray()
	for i: int in parts.size():
		motions.append("%d %s" % [i + 1, str(Motion.Kind.keys()[parts[i].motion.kind]).to_lower()])
		touching.append("%d %s" % [i + 1, _body_contact(parts[i], body, lift)])
		if parts[i].carrier != null:
			touching.append("%d on its carrier %s" % [i + 1, _body_contact(parts[i], _at_rest(parts[i].carrier), lift)])
		if parts[i].aims:
			touching.append("%d's aim sweep %s" % [i + 1, _aim_sweep(parts[i], body)])
			if parts[i].pitches.size() > 1:
				touching.append("%d's pitch sweep %s" % [i + 1, _pitch_sweep(parts[i], parts)])
	check(pair_hits.is_empty(), "%s: %d moving part(s) (%s), %s; against the body: %s" % [label, parts.size(),
		", ".join(motions), "no pair crossing" if pair_hits.is_empty() else "pairs crossing: " + ", ".join(pair_hits),
		", ".join(touching)])


## Adds a mesh's triangles, every surface, to `shape`, with its distinct edges and its BOB corners.
## With `spins`, a triangle that moves in the shaders (Surf.MOVE, its pivot and motion in CUSTOM0 and
## CUSTOM3) goes instead to the part of its motion in `spins` (made on first use, keyed by the two
## channels), in that part's own space: a moving part of the body is checked as a moving part.
func _read(mesh: Mesh, shape: Shape, spins: Dictionary = {}) -> void:
	var seen := {}
	for surface: int in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var uv2s: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV2]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var custom: Variant = arrays[Mesh.ARRAY_CUSTOM0]
		var spin_data: PackedFloat32Array = custom if typeof(custom) == TYPE_PACKED_FLOAT32_ARRAY else PackedFloat32Array()
		var custom3: Variant = arrays[Mesh.ARRAY_CUSTOM3]
		var motion_data: PackedFloat32Array = custom3 if typeof(custom3) == TYPE_PACKED_FLOAT32_ARRAY else PackedFloat32Array()
		for k: int in range(0, vertices.size(), 3):
			var into := shape
			var origin := Vector3.ZERO
			if (roundi(uv2s[k].y) & Surf.MOVE) != 0 and not spin_data.is_empty():
				var c0 := Vector4(spin_data[k * 4], spin_data[k * 4 + 1], spin_data[k * 4 + 2], spin_data[k * 4 + 3])
				var c3 := Vector4(motion_data[k * 4], motion_data[k * 4 + 1], motion_data[k * 4 + 2], motion_data[k * 4 + 3])
				var key := [c0, c3]
				if not spins.has(key):
					var part := Shape.new()
					part.pivot = Vector3(c0.x, c0.y, c0.z)
					part.motion = Motion.from_channels(c0, c3)
					spins[key] = [part, {}]
				var entry: Array = spins[key]
				into = entry[0]
				origin = into.pivot
				_add_triangle(into, entry[1], vertices, uv2s, colours, k, origin)
				continue
			_add_triangle(into, seen, vertices, uv2s, colours, k, origin)
	_bound(shape)
	for entry: Array in spins.values():
		_bound(entry[0])


## Adds the triangle at corner `k` to `shape`, moved by -`origin`, with its edges not yet `seen`
## and its BOB corners.
func _add_triangle(shape: Shape, seen: Dictionary, vertices: PackedVector3Array, uv2s: PackedVector2Array,
		colours: PackedColorArray, k: int, origin: Vector3) -> void:
	var base := shape.points.size()
	# A bobbing triangle's edges stay apart from a still one's along the same corners.
	var bobs := (roundi(uv2s[k].y) & Surf.BOB) != 0
	for corner: int in 3:
		shape.points.append(vertices[k + corner] - origin)
		if bobs:
			shape.bob.append(base + corner)
			shape.phases.append(roundf(colours[k + corner].a * 255.0) / 254.0)
	for side: int in 3:
		var a := base + side
		var b := base + (side + 1) % 3
		var key := [shape.points[a], shape.points[b], bobs] if _before(shape.points[a], shape.points[b]) \
			else [shape.points[b], shape.points[a], bobs]
		if not seen.has(key):
			seen[key] = true
			shape.edges.append(a)
			shape.edges.append(b)


func _bound(shape: Shape) -> void:
	if shape.points.is_empty():
		return
	shape.box = AABB(shape.points[0], Vector3.ZERO)
	for point: Vector3 in shape.points:
		shape.box = shape.box.expand(point)


func _before(a: Vector3, b: Vector3) -> bool:
	return a.x < b.x or (a.x == b.x and (a.y < b.y or (a.y == b.y and a.z < b.z)))


## The first sampled time at which two moving parts cross on the clock, with BOB's `lift` (0 for
## the rigid pass), or -1.
func _pair_crossing(a: Shape, b: Shape, lift: float) -> float:
	var step := minf(_step(a.motion), _step(b.motion))
	var window := maxf(_cycle(a.motion), _cycle(b.motion))
	for carrier: Shape in [a.carrier, b.carrier]:
		if carrier != null:
			step = minf(step, _step(carrier.motion))
			window = maxf(window, _cycle(carrier.motion))
	if a.motion.kind == Motion.Kind.SPIN and b.motion.kind == Motion.Kind.SPIN \
			and absf(a.motion.axis.dot(b.motion.axis)) > 0.999:
		var relative := absf(a.motion.rate * a.motion.axis.dot(b.motion.axis) - b.motion.rate)
		if relative > 0.0001:
			window = maxf(window, TAU / relative)
	if lift > 0.0:
		step = minf(step, BOB_PERIOD / BOB_SAMPLES)
		window = maxf(window, BOB_PERIOD)
	window = minf(window, PAIR_WINDOW)
	for k: int in ceili(window / step) + 1:
		var t := k * step
		var at_a := _pose_at(a, t)
		var at_b := _pose_at(b, t)
		var box_a := (at_a * a.box).grow(lift + SLACK)
		var box_b := (at_b * b.box).grow(lift + SLACK)
		if not box_a.intersects(box_b):
			continue
		if _crosses(_posed(a, at_a, t, lift), a.edges, _posed(b, at_b, t, lift), b.edges,
				box_a.intersection(box_b)):
			return t
	return -1.0


## How many of a moving part's poses touch the static body, rigid, and with BOB where either side
## has it: "a of n" or "a of n, b of m with BOB".
func _body_contact(part: Shape, body: Shape, lift: float) -> String:
	var poses := _poses(part.motion, part.pivot)
	var swept := AABB()
	for k: int in poses.size():
		swept = (poses[k] * part.box) if k == 0 else swept.merge(poses[k] * part.box)
	var near := _within(body, swept.grow(2.0 * lift + SLACK))
	var rigid := 0
	for at: Transform3D in poses:
		if not near.edges.is_empty() and _crosses(_posed(part, at, 0.0, 0.0), part.edges, near.points, near.edges,
				(at * part.box).grow(SLACK)):
			rigid += 1
	if part.bob.is_empty() and near.bob.is_empty():
		return "%d of %d" % [rigid, poses.size()]
	var step := minf(_step(part.motion), BOB_PERIOD / BOB_SAMPLES)
	var count := ceili(maxf(_cycle(part.motion), BOB_PERIOD) / step) + 1
	var bobbing := 0
	for k: int in count:
		var t := k * step
		var at := _pose_at(part, t)
		if not near.edges.is_empty() and _crosses(_posed(part, at, t, lift), part.edges,
				_posed(near, Transform3D.IDENTITY, t, lift), near.edges, (at * part.box).grow(lift + SLACK)):
			bobbing += 1
	return "%d of %d, %d of %d with BOB" % [rigid, poses.size(), bobbing, count]


## A part's pose on the clock at `t`, carried by the part it rides as BuildingView carries it.
func _pose_at(part: Shape, t: float) -> Transform3D:
	var at := part.motion.transform_at(t, part.pivot)
	if part.carrier != null:
		at = _pose_at(part.carrier, t) * Transform3D(Basis.IDENTITY, -part.carrier.pivot) * at
	return at


## A moving part's shape at rest in the model's space, to count another's contacts against it.
func _at_rest(part: Shape) -> Shape:
	var rest := Shape.new()
	for point: Vector3 in part.points:
		rest.points.append(point + part.pivot)
	rest.edges = part.edges
	rest.bob = part.bob
	rest.phases = part.phases
	rest.box = AABB(part.box.position + part.pivot, part.box.size)
	return rest


## A pitching part's travel (BattleView.PITCH_LIMITS or LOB_ELEVATION for `type`): its trunnion,
## its pitch axis and its pitches every PITCH_STEP across it, both ends included, from its `muzzle`
## socket's built elevation.
func _travel(part: Shape, type: String, muzzle: LowPolyMesh.Socket, trunnion: LowPolyMesh.Socket) -> void:
	var limits := Vector2.ZERO
	if BattleView.PITCH_LIMITS.has(type):
		limits = BattleView.PITCH_LIMITS[type]
	elif BattleView.LOB_ELEVATION.has(type):
		limits = BattleView.LOB_ELEVATION[type]
	else:
		return
	var facing := muzzle.direction.normalized()
	var built := asin(clampf(facing.y, -1.0, 1.0))
	part.trunnion = trunnion.position
	part.pitch_axis = Vector3(facing.x, 0.0, facing.z).cross(Vector3.UP).normalized()
	part.pitches = PackedFloat32Array()
	var elevation := limits.x
	while elevation < limits.y:
		part.pitches.append(deg_to_rad(elevation) - built)
		elevation += PITCH_STEP
	part.pitches.append(deg_to_rad(limits.y) - built)


## How many of an aiming part's poses through a whole turn about +Y (every SPIN_STEP degrees), the
## part it rides turning it about that part's pivot, and, for one that pitches, at every sampled
## elevation of its travel at each, touch the static body: "a of n".
func _aim_sweep(part: Shape, body: Shape) -> String:
	var poses: Array[Transform3D] = []
	var turner := part.carrier if part.carrier != null else part
	for k: int in roundi(360.0 / SPIN_STEP):
		var yaw := Transform3D(Basis(Vector3.UP, deg_to_rad(SPIN_STEP * k)), Vector3.ZERO)
		yaw = Transform3D(Basis.IDENTITY, turner.pivot) * yaw * Transform3D(Basis.IDENTITY, -turner.pivot)
		for pitch: float in part.pitches:
			var turn := Transform3D(Basis(part.pitch_axis, pitch), Vector3.ZERO)
			turn = Transform3D(Basis.IDENTITY, part.trunnion) * turn * Transform3D(Basis.IDENTITY, -part.trunnion)
			poses.append(yaw * Transform3D(Basis.IDENTITY, part.pivot) * turn)
	var swept := AABB()
	for k: int in poses.size():
		swept = (poses[k] * part.box) if k == 0 else swept.merge(poses[k] * part.box)
	var near := _within(body, swept.grow(SLACK))
	var touching := 0
	for at: Transform3D in poses:
		if not near.edges.is_empty() and _crosses(_posed(part, at, 0.0, 0.0), part.edges, near.points, near.edges,
				(at * part.box).grow(SLACK)):
			touching += 1
	return "%d of %d" % [touching, poses.size()]


## A pitching part's poses at every sampled elevation of its travel at every SPIN_STEP of the turn (as
## _aim_sweep), against the part that turns it (its carrier, turned with it) and every other moving
## part (one riding the same carrier turned with it, any other at rest; a part riding the pitching
## one moves with it and is left out): "carrier a of n, part k b of n, ..." counting the poses that
## touch each. Into `tally`, when given, each other part's count by its index in `parts` and
## "poses" the poses swept, for a caller that reads the counts (model_audit).
func _pitch_sweep(part: Shape, parts: Array[Shape], tally: Dictionary = {}) -> String:
	var turner := part.carrier if part.carrier != null else part
	var others: Array[Shape] = []
	var names := PackedStringArray()
	var indices := PackedInt32Array()
	for k: int in parts.size():
		var other := parts[k]
		if other == part or _rides_on(other, part) or (other == turner and turner == part):
			continue
		others.append(other)
		indices.append(k)
		names.append("carrier" if other == turner else "part %d" % (k + 1))
	var counts := PackedInt32Array()
	counts.resize(others.size())
	var poses := 0
	for k: int in roundi(360.0 / SPIN_STEP):
		var yaw := Transform3D(Basis(Vector3.UP, deg_to_rad(SPIN_STEP * k)), Vector3.ZERO)
		yaw = Transform3D(Basis.IDENTITY, turner.pivot) * yaw * Transform3D(Basis.IDENTITY, -turner.pivot)
		for pitch: float in part.pitches:
			var turn := Transform3D(Basis(part.pitch_axis, pitch), Vector3.ZERO)
			turn = Transform3D(Basis.IDENTITY, part.trunnion) * turn * Transform3D(Basis.IDENTITY, -part.trunnion)
			var at := yaw * Transform3D(Basis.IDENTITY, part.pivot) * turn
			var points := _posed(part, at, 0.0, 0.0)
			var box := (at * part.box).grow(SLACK)
			poses += 1
			for o: int in others.size():
				var other := others[o]
				var moved := other == turner or _rides_on(other, turner)
				var other_at := (yaw if moved else Transform3D.IDENTITY) * Transform3D(Basis.IDENTITY, other.pivot)
				var other_box := (other_at * other.box).grow(SLACK)
				if box.intersects(other_box) and _crosses(points, part.edges, _posed(other, other_at, 0.0, 0.0), other.edges,
						box.intersection(other_box)):
					counts[o] += 1
	var said := PackedStringArray()
	tally["poses"] = poses
	for o: int in others.size():
		said.append("%s %d of %d" % [names[o], counts[o], poses])
		tally[indices[o]] = counts[o]
	return ", ".join(said) if not said.is_empty() else "no other part"


## Whether `part` rides `carrier`, directly or through the parts it rides.
func _rides_on(part: Shape, carrier: Shape) -> bool:
	var on := part.carrier
	while on != null:
		if on == carrier:
			return true
		on = on.carrier
	return false


## The body's triangles whose bounds meet `region`, as a shape of their own.
func _within(body: Shape, region: AABB) -> Shape:
	var near := Shape.new()
	var bobbing := {}
	for k: int in body.bob.size():
		bobbing[body.bob[k]] = body.phases[k]
	var seen := {}
	for k: int in range(0, body.points.size(), 3):
		var box := AABB(body.points[k], Vector3.ZERO).expand(body.points[k + 1]).expand(body.points[k + 2])
		if not box.grow(SLACK).intersects(region):
			continue
		var base := near.points.size()
		for corner: int in 3:
			near.points.append(body.points[k + corner])
			if bobbing.has(k + corner):
				near.bob.append(base + corner)
				near.phases.append(bobbing[k + corner])
		for side: int in 3:
			var a := base + side
			var b := base + (side + 1) % 3
			var key := [near.points[a], near.points[b], bobbing.has(k)] if _before(near.points[a], near.points[b]) \
				else [near.points[b], near.points[a], bobbing.has(k)]
			if not seen.has(key):
				seen[key] = true
				near.edges.append(a)
				near.edges.append(b)
	return near


## A part's poses against the body: a SPIN every SPIN_STEP degrees round a whole turn, a SWING at
## SWING_POSES and a SLIDE at SLIDE_POSES from -amplitude to +amplitude.
func _poses(motion: Motion, pivot: Vector3) -> Array[Transform3D]:
	var poses: Array[Transform3D] = []
	match motion.kind:
		Motion.Kind.SPIN:
			for k: int in roundi(360.0 / SPIN_STEP):
				poses.append(Transform3D(Basis(motion.axis, deg_to_rad(SPIN_STEP * k)), pivot))
		Motion.Kind.SWING:
			for k: int in SWING_POSES:
				var angle := deg_to_rad(motion.amplitude) * (2.0 * k / (SWING_POSES - 1) - 1.0)
				poses.append(Transform3D(Basis(motion.axis, angle), pivot))
		_:
			for k: int in SLIDE_POSES:
				poses.append(Transform3D(Basis.IDENTITY,
					pivot + motion.axis * motion.amplitude * (2.0 * k / (SLIDE_POSES - 1) - 1.0)))
	return poses


## Seconds between a part's samples on the clock.
func _step(motion: Motion) -> float:
	match motion.kind:
		Motion.Kind.SPIN:
			return deg_to_rad(SPIN_STEP) / maxf(absf(motion.rate), 0.0001)
		Motion.Kind.SWING:
			return motion.period / SWING_SAMPLES
		_:
			return motion.period / SLIDE_SAMPLES


## Seconds a part takes to come back to a pose: a SPIN's turn, a SWING's or a SLIDE's period.
func _cycle(motion: Motion) -> float:
	if motion.kind == Motion.Kind.SPIN:
		return minf(TAU / maxf(absf(motion.rate), 0.0001), PAIR_WINDOW)
	return motion.period


## A shape's corners placed by `at`, each BOB corner lifted along Y at time `t` (no lift when
## `lift` is 0).
func _posed(shape: Shape, at: Transform3D, t: float, lift: float) -> PackedVector3Array:
	var points := at * shape.points
	if lift > 0.0:
		for k: int in shape.bob.size():
			points[shape.bob[k]].y += lift * sin(TAU * (t / BOB_PERIOD + shape.phases[k]))
	return points


## Whether an edge of `a` crosses a triangle of `b` or an edge of `b` one of `a`, both posed,
## looking only inside `region`.
func _crosses(a: PackedVector3Array, a_edges: PackedInt32Array, b: PackedVector3Array,
		b_edges: PackedInt32Array, region: AABB) -> bool:
	var region_grown := region.grow(SLACK)
	var a_cells := _hash(a, region_grown)
	if a_cells.is_empty():
		return false
	var b_cells := _hash(b, region_grown)
	if b_cells.is_empty():
		return false
	return _edges_cross(a, a_edges, b, b_cells, region_grown) or _edges_cross(b, b_edges, a, a_cells, region_grown)


## The triangles of `points` whose bounds meet `region`, by the CELL-sized cells their bounds
## cover there.
func _hash(points: PackedVector3Array, region: AABB) -> Dictionary:
	var cells := {}
	for k: int in range(0, points.size(), 3):
		var box := AABB(points[k], Vector3.ZERO).expand(points[k + 1]).expand(points[k + 2])
		if not box.grow(SLACK).intersects(region):
			continue
		var clip := box.grow(SLACK).intersection(region)
		var low := Vector3i((clip.position / CELL).floor())
		var high := Vector3i((clip.end / CELL).floor())
		for x: int in range(low.x, high.x + 1):
			for y: int in range(low.y, high.y + 1):
				for z: int in range(low.z, high.z + 1):
					var cell := Vector3i(x, y, z)
					if not cells.has(cell):
						cells[cell] = []
					(cells[cell] as Array).append(k)
	return cells


## Whether an edge of `points` within `region` crosses one of the hashed triangles of `others`.
func _edges_cross(points: PackedVector3Array, edges: PackedInt32Array, others: PackedVector3Array,
		cells: Dictionary, region: AABB) -> bool:
	for e: int in range(0, edges.size(), 2):
		var from := points[edges[e]]
		var to := points[edges[e + 1]]
		var box := AABB(from, Vector3.ZERO).expand(to)
		if not box.grow(SLACK).intersects(region):
			continue
		var clip := box.grow(SLACK).intersection(region)
		var low := Vector3i((clip.position / CELL).floor())
		var high := Vector3i((clip.end / CELL).floor())
		for x: int in range(low.x, high.x + 1):
			for y: int in range(low.y, high.y + 1):
				for z: int in range(low.z, high.z + 1):
					var tris: Array = cells.get(Vector3i(x, y, z), [])
					for k: int in tris:
						var hit: Variant = Geometry3D.segment_intersects_triangle(from, to, others[k], others[k + 1],
							others[k + 2])
						if hit != null:
							_hit = hit
							return true
	return false
