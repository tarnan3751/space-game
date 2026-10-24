extends HarnessScenario
## The part rig, sockets and defence aim (docs/reference/art-style.md, **Rig** and **Sockets**;
## docs/reference/battle-view.md, **Aim and muzzles**), proven on the ranger and the laser turret.
##
## Part 1, the poses: a row of rangers on the field, the base's own views hidden, each one instance
## of one MultiMesh (the shaders read a pose from INSTANCE_CUSTOM only there) given a fixed state
## (POSES): standing, walking at three phases, aiming half and fully raised, and a shot's kick at
## two moments; turned in profile, facing the screen's left, so the stride and the raise show.
## Checks on the CPU, through Rig's mirror of the shaders' angles, posing every vertex of the mesh
## (its CUSTOM1 and CUSTOM2): at each walking phase the forward leg is the one the phase says and
## no point dips below the ground; the muzzle socket points LOW_READY (30 degrees down) as built,
## within AIM_SLACK of level fully aimed, and kicked up by a shot.
##
## Part 2, a battle: a laser turret and the Command Center against rangers deployed by script,
## framed on the turret. Checks: the turret's head turns to within AIM_TOLERANCE of its target
## while it fires; each of its bolts leaves one of its muzzle sockets, alternating; a ranger's
## bolts leave its posed muzzle socket.
##
## Rendered, the screenshots: "poses-24", "poses-8" and "poses-4" (the row at the gameplay zoom,
## close, and its walking rangers closer),
## "battle-walk-24" and "battle-walk-10" (the rangers walking in), "battle-shot-24" and
## "battle-shot-10" (the battle paused just after a turret's shot: the head turned to its target,
## a bolt at a barrel tip with its flash, the rangers aiming), "battle-ranger-6" (a ranger close,
## aiming, paused just after its shot, its flash on the rifle's muzzle).

## [label, x, y]: the instance state (Rig) of each ranger in the row.
const POSES: Array[Array] = [
	["standing", 0.0, 0.0],
	["walking, left leg forward", 0.5, 1.0],
	["walking, legs passing", 1.0, 1.0],
	["walking, right leg forward", 1.5, 1.0],
	["aim half raised", 1.0, -0.5],
	["aimed", 1.0, -1.0],
	["shot, at the kick", 0.0, -1.0],
	["shot, easing back", 0.12, -1.0],
]
const SPACING := 1.0
const PROFILE := -90.0
const GROUND_SLACK := 0.005
const AIM_SLACK := 0.12
const AIM_TOLERANCE := 10.0
## How far a turret's bolt may start from the muzzle socket it left: the shake of a hit
## (BattleView.SHAKE) moves the turret after its shot, either way.
const SOCKET_SLACK := 0.12
const SETTLE_SECONDS := 0.5
const SETTLE_FRAMES := 10
## The battle: the turret's id and level, the rangers deployed, the tick the walk is shot at, and
## the most frames a wait takes.
const TURRET := 2
const TURRET_LEVEL := 3
const RANGERS := 6
const WALK_TICK := 40
const MAX_WAIT_FRAMES := 3000

var _turret_shots: Array[String] = []
var _bolts_seen := 0
var _worst_aim := 0.0
var _ranger_bolts := 0
var _ranger_bad := 0
var _last_shooter := 0


func run(main: MainScript) -> void:
	await _poses(main)
	await _battle(main)


func _poses(main: MainScript) -> void:
	for view: BuildingView in main.base_view.views.values():
		view.visible = false
	var meshes := UnitModels.meshes("ranger", Parts.Tier.BASE)
	var arrays := meshes.body.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	check(arrays[Mesh.ARRAY_CUSTOM1] != null and arrays[Mesh.ARRAY_CUSTOM2] != null,
		"the ranger's mesh carries its rig in CUSTOM1 and CUSTOM2")
	var inner: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM1]
	var outer: PackedFloat32Array = arrays[Mesh.ARRAY_CUSTOM2]
	var socket: LowPolyMesh.Socket = meshes.sockets.get("muzzle")
	check(socket != null, "the ranger has a muzzle socket")
	if socket == null or inner.size() != vertices.size() * 4:
		return
	check(roundi(socket.rig.w) == Rig.AIM, "its muzzle is on the aim group")

	for spec: Array in POSES:
		var state := Color(spec[1], spec[2], 0, 0)
		var lowest := INF
		var knee_z := [0.0, 0.0]
		var knee_n := [0, 0]
		for i: int in vertices.size():
			var rig := Vector4(inner[i * 4], inner[i * 4 + 1], inner[i * 4 + 2], inner[i * 4 + 3])
			var rig2 := Vector4(outer[i * 4], outer[i * 4 + 1], outer[i * 4 + 2], outer[i * 4 + 3])
			var at := Rig.posed(vertices[i], rig, rig2, state)
			lowest = minf(lowest, at.y)
			var channel := roundi(rig.w)
			if channel == Rig.KNEE_L or channel == Rig.KNEE_R:
				var s := 0 if channel == Rig.KNEE_L else 1
				knee_z[s] += at.z
				knee_n[s] += 1
		var direction := Rig.posed_direction(socket.direction, socket.rig, socket.rig2, state)
		var left_z: float = knee_z[0] / maxi(1, knee_n[0])
		var right_z: float = knee_z[1] / maxi(1, knee_n[1])
		say("%s: lowest %.4f, shins' mean z left %.3f right %.3f, muzzle direction %s" % [spec[0], lowest, left_z,
			right_z, direction])
		check(lowest >= -GROUND_SLACK, "%s: no point below the ground (%.4f)" % [spec[0], lowest])
		match spec[0]:
			"walking, left leg forward":
				check(left_z > right_z + 0.05, "%s: the left leg is ahead" % spec[0])
			"walking, right leg forward":
				check(right_z > left_z + 0.05, "%s: the right leg is ahead" % spec[0])
			"standing":
				check(absf(direction.normalized().y + 0.5) < 0.05, "standing: the rifle points 30 degrees down")
			"aimed":
				check(absf(direction.y) < AIM_SLACK and direction.z > 0.9, "aimed: the rifle is level and forward")
			"shot, at the kick":
				check(direction.y > AIM_SLACK, "at the kick: the rifle is kicked up")

	var root := Node3D.new()
	main.add_child(root)
	var view_basis := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	var across := Vector3(view_basis.x.x, 0, view_basis.x.z).normalized()
	var down := Vector3(view_basis.z.x, 0, view_basis.z.z).normalized()
	var yaw := atan2(down.x, down.z) + deg_to_rad(PROFILE)
	var first := -(POSES.size() - 1) * SPACING * 0.5
	for mesh: Mesh in [meshes.body, meshes.outline]:
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.use_custom_data = true
		multimesh.mesh = mesh
		multimesh.instance_count = POSES.size()
		for k: int in POSES.size():
			multimesh.set_instance_transform(k, Transform3D(Basis(Vector3.UP, yaw), across * (first + SPACING * k)))
			multimesh.set_instance_color(k, Color.WHITE)
			multimesh.set_instance_custom_data(k, Color(POSES[k][1], POSES[k][2], 0, 0))
		var instance := MultiMeshInstance3D.new()
		instance.multimesh = multimesh
		root.add_child(instance)
	var middle := Vector3(0, 0.4, 0)
	await _frame(main, 24.0, middle)
	await screenshot("poses-24")
	await _frame(main, 8.0, middle)
	await screenshot("poses-8")
	await _frame(main, 4.0, across * (first + SPACING * 2.0) + middle)
	await screenshot("poses-4")
	root.queue_free()
	for view: BuildingView in main.base_view.views.values():
		view.visible = true


func _battle(main: MainScript) -> void:
	var setup := {
		"seed": 7,
		"attacker": {"army": {"ranger": RANGERS}, "unit_levels": {"ranger": 1}, "abilities": {}, "ability_levels": {}},
		"defender": {"buildings": [
			{"id": 1, "type": "command_center", "level": 1, "cell": [30, 22]},
			{"id": TURRET, "type": "laser_turret", "level": TURRET_LEVEL, "cell": [14, 22]},
		], "resources": {}},
		"commands": [],
	}
	var error := main.open_battle(setup, true)
	check(error == "", "the battle opens: '%s'" % error)
	if error != "":
		return
	var view: BattleView = main.battle
	var turret: BuildingView = view._views[TURRET]
	check(turret.can_aim(), "the laser turret's head aims (its muzzle is on its head)")
	var sockets := 0
	for name: String in BattleView.MUZZLES:
		if turret.has_socket(name):
			sockets += 1
	check(sockets == 2, "the level %d laser turret has two muzzle sockets (%d)" % [TURRET_LEVEL, sockets])
	var commands: Array[Dictionary] = []
	for k: int in RANGERS:
		commands.append({"op": "deploy", "tick": 2 * k, "unit": "ranger", "cell": [13 + k, 36]})
	view.script_commands(commands)
	main.get_tree().process_frame.connect(_on_frame.bind(view))
	var field_point := view.building_centre(TURRET) + Vector3(1.0, 0.4, 5.0)

	await _until(main, func() -> bool: return view.sim.tick >= WALK_TICK)
	view.speed = 0
	await _frame(main, 24.0, field_point)
	await screenshot("battle-walk-24")
	await _frame(main, 10.0, field_point)
	await screenshot("battle-walk-10")
	view.speed = 1

	await _until(main, func() -> bool: return _turret_shots.size() >= 3)
	check(_turret_shots.size() >= 3, "the turret fired three times (%d)" % _turret_shots.size())
	check(_worst_aim <= AIM_TOLERANCE, "every turret bolt left with the head facing its target (worst %.1f degrees)"
		% _worst_aim)
	for k: int in 3:
		check(_turret_shots[k] != "", "turret shot %d left a muzzle socket" % (k + 1))
		if k > 0:
			check(_turret_shots[k] != _turret_shots[k - 1], "turret shots %d and %d left different barrels (%s, %s)"
				% [k, k + 1, _turret_shots[k - 1], _turret_shots[k]])
	# The next shot: pause a frame after it, while its flash shows.
	var shots := _turret_shots.size()
	await _until(main, func() -> bool: return _turret_shots.size() > shots)
	await frames(1)
	view.speed = 0
	var target := view.sim.building_target(TURRET)
	check(target != 0, "the turret has a target")
	if target != 0:
		var to := view.units.aim_point(target) - turret.global_position
		var facing := turret.socket_direction("muzzle")
		var off := rad_to_deg(absf(angle_difference(atan2(facing.x, facing.z), atan2(to.x, to.z))))
		say("the head faces %.1f degrees off its target" % off)
		check(off <= AIM_TOLERANCE, "the head faces its target (%.1f degrees off, within %.0f)" % [off, AIM_TOLERANCE])
	await _frame(main, 24.0, view.building_centre(TURRET) + Vector3(0.5, 1.0, 2.0))
	await screenshot("battle-shot-24")
	await _frame(main, 10.0, view.building_centre(TURRET) + Vector3(0.5, 1.0, 2.0))
	await screenshot("battle-shot-10")
	view.speed = 1

	await _until(main, func() -> bool: return _ranger_bolts >= 2)
	check(_ranger_bolts >= 2, "rangers fired (%d bolts checked)" % _ranger_bolts)
	check(_ranger_bad == 0, "every ranger bolt left in front of its ranger, at its rifle, not its middle (%d did not)"
		% _ranger_bad)
	var shooter := _last_shooter
	await _until(main, func() -> bool: return _last_shooter != shooter and _last_shooter > 0)
	if _last_shooter > 0:
		view.speed = 0
		await _frame(main, 6.0, view.units.aim_point(_last_shooter))
		await screenshot("battle-ranger-6")
	view.speed = 1
	main.get_tree().process_frame.disconnect(_on_frame)
	view.surrender()
	await _until(main, func() -> bool: return view.sim.is_over())
	view.leave()
	await frames(2)


## At the start of each frame, before anything moves: a bolt started last frame (the newest, by
## BattleEffects.bolts_fired) is checked. A turret's must start at one of its muzzle sockets (the
## head is posed as it fired); a ranger's in front of the nearest attacking ranger, towards the
## building it attacks, at its rifle and away from its middle.
func _on_frame(view: BattleView) -> void:
	if view.effects.bolts_fired == _bolts_seen:
		return
	_bolts_seen = view.effects.bolts_fired
	var from := view.effects.last_bolt_from
	if view.effects.last_bolt_color == BattleView.DEFENCE_SHOT:
		var turret: BuildingView = view._views.get(TURRET)
		var matched := ""
		for name: String in BattleView.MUZZLES:
			if turret != null and turret.has_socket(name) and turret.socket_point(name).distance_to(from) < SOCKET_SLACK:
				matched = name
		_turret_shots.append(matched)
		var target := view.sim.building_target(TURRET)
		if turret != null and target != 0:
			var to := view.units.aim_point(target) - turret.global_position
			var facing := turret.socket_direction("muzzle")
			var off := rad_to_deg(absf(angle_difference(atan2(facing.x, facing.z), atan2(to.x, to.z))))
			say("turret shot from %s, the head %.1f degrees off its target" % [matched, off])
			_worst_aim = maxf(_worst_aim, off)
	elif view.effects.last_bolt_color == BattleView.UNIT_SHOT:
		var nearest := 0
		var best := INF
		for unit: int in range(1, view.sim.unit_count() + 1):
			if view.sim.unit_state(unit) != BattleArmy.ATTACKING:
				continue
			var d := Vector2(from.x, from.z).distance_to(Vector2(view.units.aim_point(unit).x, view.units.aim_point(unit).z))
			if d < best:
				best = d
				nearest = unit
		if nearest == 0:
			return
		var at := view.units.aim_point(nearest)
		var ahead := view.building_centre(view.sim.unit_target(nearest)) - at
		var off := Vector2(from.x - at.x, from.z - at.z)
		_ranger_bolts += 1
		_last_shooter = nearest
		if off.length() < 0.1 or off.length() > 0.6 or off.normalized().dot(Vector2(ahead.x, ahead.z).normalized()) < 0.3:
			_ranger_bad += 1


## Awaits frames until `done` holds, or MAX_WAIT_FRAMES.
func _until(main: MainScript, done: Callable) -> void:
	var waited := 0
	while not done.call() and waited < MAX_WAIT_FRAMES:
		await main.get_tree().process_frame
		waited += 1


## Sets the camera to `size` (under its own closest zoom directly) with `target` at the screen's
## centre, and lets the frame settle.
func _frame(main: MainScript, size: float, target: Vector3) -> void:
	var centre := main.get_viewport().get_visible_rect().size * 0.5
	main.camera.zoom_at(main.camera.size / maxf(size, IsoCamera.MIN_ZOOM_SIZE), centre)
	main.camera.size = size
	main.camera.pan(centre, centre - main.camera.unproject_position(target))
	await main.get_tree().create_timer(SETTLE_SECONDS).timeout
	await frames(SETTLE_FRAMES)
