class_name BuildingView
extends Node3D
## Visual for one building: its model (or a scaffold while first being built), a
## footprint tile for selection/placement feedback, and a floating timer label, raised above
## the construction drone's flight while one works over the site.
## Holds no game state; BaseView and PlacementController push state into it.
##
## The meshes are shared, so a state shows by overriding an instance's material with another
## shared one from MaterialKit, never a new material: a selected or lifted building's outlines
## turn core gold (ink_selected) until both end, when the override is cleared (null); a
## placement ghost keeps plain ink outlines, lifted as it is, and its bodies take the valid or
## invalid ghost tint (set_ghost) for as long as it lives. In battle (BattleView) a hit whitens the
## bodies for a moment (set_flash, MaterialKit.hit_flash), and an EMP burst dims them grey while the
## building is disabled (set_disabled, MaterialKit.disabled). A rival colony's building carries the
## faction tint (set_rival, MaterialKit.rival), and its flash and its grey are the tinted ones
## (hit_flash_rival, disabled_rival).
##
## In battle a defence whose head carries a `muzzle` socket (a moving part's, LowPolyMesh.socket)
## aims it: BattleView turns the head towards its target (aim_at) and, once it has had none for
## AIM_IDLE_SECONDS, eases it back into its idle Motion (idle_aim), which it then follows again. The
## aim turns the head about +Y: an idle Motion that turns it about +Y too (a scan) gives way to the
## aim, any other (the orbital cannon's elevation) runs on under it. Each shot kicks the head back
## along its muzzle by its type's weapon record's `recoil` (fired, Weapons): the head's pose is its
## aim's yaw, then its idle Motion, then the kick. A defence whose aiming part has a `trunnion`
## socket also pitches its barrels towards the elevation BattleView asks for, about that point and
## across its muzzle: the part with the `muzzle` itself when it turns (the missile battery's
## launcher), or, when it rides the head (the laser turret's barrels), that rider, the head only
## turning; the kick then slides the pitching part along its pitched muzzle. A moving part that
## rides another (Parts.riding) is carried by it. A defence whose
## muzzle is on its body, or that has none, never aims. socket_point() and socket_direction() give
## a socket where it is now, in the world. While an EMP burst has the building disabled
## (set_disabled) every moving part holds its pose, and on waking snaps back to the clock's; a
## cloaked defence fades in when it is revealed (set_reveal).
##
## While the building is busy a ConstructionDrone works over it, driven from _process, and a moving
## part whose figure marches on the clock (BuildingModels.MARCH_META) is hidden, since its legs
## would step on while its round holds; when the work ends the drone leaves, and if the view is
## freed first (a finished level replaces it) BaseView hands the leaving drone over (release_drone).

enum Footprint { NONE, SELECTED, VALID, INVALID }

const FOOTPRINT_COLORS := {
	Footprint.SELECTED: Color(0.31, 0.84, 0.9, 0.4),
	Footprint.VALID: Color(0.3, 0.9, 0.45, 0.6),
	Footprint.INVALID: Color(0.95, 0.3, 0.3, 0.65),
}
const LIFT_HEIGHT := 0.35
## The timer label's text, in font pixels, and its outline (the stroke reaches a quarter of
## outline_size out): about 2 px of ink round the text at the starting zoom.
const LABEL_FONT_SIZE := 48
const LABEL_OUTLINE_SIZE := 20
## While a drone works over the site, the label's centre sits this far above the highest point
## the drone reaches, so the text never overlaps its flight.
const LABEL_OVER_DRONE := 0.5
## How long an aiming head holds its last aim with no target before it returns to its idle swing,
## in seconds of battle, and how close (radians) it comes to the swing before following it again.
const AIM_IDLE_SECONDS := 2.5
const AIM_SETTLED := 0.02
## How long a shot's kick takes, in seconds of battle, on Motion.recoil's wave, out fast and back
## slowly (its reach is the type's weapon record's, fired()).
const RECOIL_SECONDS := 0.25
## A revealed defence's fade in (set_reveal): MaterialKit.reveal's steps, its outlines showing from
## the second.
const REVEAL_STEPS := 3

enum Aim { IDLE, AIMING, RETURNING }

var building_id: int = 0
var building_type: String = ""
## The finished level the model shows; 0 while the building is first being constructed.
var building_level: int = 0
var footprint_size: int = 1

var _model: Node3D
var _scaffold: Node3D
var _footprint: MeshInstance3D
var _footprint_material: StandardMaterial3D
var _label: Label3D
## The models' and the scaffold's mesh instances: bodies and ink outlines.
var _bodies: Array[MeshInstance3D] = []
var _outlines: Array[MeshInstance3D] = []
var _selected: bool = false
var _lifted: bool = false
## A placement ghost's body tint (set_ghost), null for any other view. A ghost's outlines stay
## plain ink though it is lifted.
var _ghost_tint: Material = null
## Whether the bodies carry the hit flash now (set_flash), and whether the building is disabled
## (set_disabled), which tints them grey while no flash is on.
var _flashed: bool = false
var _disabled: bool = false
## Whether the bodies carry the faction tint (set_rival).
var _rival: bool = false
## Whether the outlines carry the selected ink now.
var _inked: bool = false
## The model's moving parts, each with its Motion and its rest position. They are posed at
## Motion.clock(), the shaders' clock, while the building is idle; while it is busy they hold
## their last pose, and on resuming they snap to the clock's.
var _movers: Array[Node3D] = []
var _motions: Array[Motion] = []
var _rests: PackedVector3Array = PackedVector3Array()
## Per moving part, the index of the one it rides (BuildingModels.RIDES_META), -1 for none; a part
## rides one made before it, so posing in order poses the carrier first.
var _rides := PackedInt32Array()
var _animate: bool = true
## The moving parts whose figures march on the clock (BuildingModels.MARCH_META), hidden while busy.
var _marching: Array[Node3D] = []
## BaseView's merged wall mesh draws this building, so its own model is hidden (set_merged).
var _merged: bool = false
## The builder drone over the site while the building is busy, and while it leaves.
var _drone: ConstructionDrone = null
## The sockets by name (LowPolyMesh.Socket) and the node each is on (the model's root or a moving
## part's node).
var _sockets: Dictionary[String, LowPolyMesh.Socket] = {}
var _socket_nodes: Dictionary[String, Node3D] = {}
## The moving part that turns to aim, -1 for none (the view never aims): the one carrying the
## `muzzle`, or the one that part rides; the way its muzzle faces as built (radians about +Y from
## +Z), whether it aims, follows its Motion or returns to it, its yaw while it aims or returns, and
## the seconds since it last had a target.
var _aim_index: int = -1
var _aim_heading: float = 0.0
var _aim: Aim = Aim.IDLE
var _aim_yaw: float = 0.0
var _aim_wait: float = 0.0
## Whether the aiming head's idle Motion turns it about +Y (a scan the aim takes over), the way its
## muzzle faces in its own space (the kick's), the battle's clock as the last aim call gave it, and
## when the head last fired and how far that shot kicks it (fired).
var _aim_turns: bool = true
var _muzzle_direction := Vector3.FORWARD
## The moving part that pitches (the one carrying the `muzzle`, when it has a `trunnion` socket),
## -1 for none; its trunnion and the axis it pitches about (raising the muzzle), in its own space;
## the muzzle's elevation as built (radians); and its pitch from that, now and wanted.
var _pitch_index: int = -1
var _trunnion := Vector3.ZERO
var _pitch_axis := Vector3.RIGHT
var _built_elevation: float = 0.0
var _pitch: float = 0.0
var _pitch_wanted: float = 0.0
var _now: float = 0.0
var _fired_at: float = -INF
var _kick_reach: float = 0.0
## The step of the reveal's fade the bodies show (set_reveal), -1 for none.
var _reveal_step: int = -1


## Call once, before adding to the tree. `level` picks the model (level 1's while it is 0),
## built for `tier`, the shown level's (BuildingModels.tier_of).
func setup(id: int, type: String, level: int, size: int, tier: int) -> void:
	building_id = id
	building_type = type
	building_level = level
	footprint_size = size

	_model = BuildingModels.create(type, maxi(level, 1), size, tier)
	add_child(_model)
	_collect_movers(_model)
	_collect_sockets(_model)
	_scaffold = BuildingModels.create_scaffold(size)
	add_child(_scaffold)
	_collect_meshes(_model)
	_collect_meshes(_scaffold)

	var plane := PlaneMesh.new()
	# Full footprint plus a small rim, so it shows around the model's base slab.
	plane.size = Vector2(size, size) + Vector2(0.3, 0.3)
	_footprint_material = StandardMaterial3D.new()
	_footprint_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_footprint_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_footprint = MeshInstance3D.new()
	_footprint.mesh = plane
	_footprint.material_override = _footprint_material
	_footprint.position = Vector3(0, 0.03, 0)
	add_child(_footprint)

	# In the HUD's font and colours, its own Lilita One, ink-outlined.
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.font = Hud.BODY_FONT
	_label.font_size = LABEL_FONT_SIZE
	_label.outline_size = LABEL_OUTLINE_SIZE
	_label.pixel_size = 0.016
	_label.modulate = Hud.TEXT
	_label.outline_modulate = Hud.INK
	_label.position = Vector3(0, _label_height(), 0)
	add_child(_label)

	set_footprint(Footprint.NONE)
	show_status(1, false, 1, 0)


func _ready() -> void:
	# Nothing to animate (walls, traps) costs nothing per frame. Not in setup(): entering the
	# tree turns processing on for any script with _process.
	set_process(not _movers.is_empty())


## level 0 = first construction (scaffold). busy = constructing or upgrading.
func show_status(level: int, busy: bool, target_level: int, seconds_left: int) -> void:
	_model.visible = level >= 1 and not _merged
	_scaffold.visible = level < 1
	_animate = level >= 1 and not busy
	for mover: Node3D in _marching:
		mover.visible = not busy
	_label.visible = busy
	if busy and _drone == null:
		_drone = ConstructionDrone.new()
		_drone.setup(building_id, footprint_size, _scaffold if level < 1 else _model)
		add_child(_drone)
		_place_label()
		set_process(true)
	elif not busy and _drone != null:
		_drone.leave(site_height())
	if busy:
		var what := "Building" if level < 1 else "Lv %d" % target_level
		_label.text = "%s  %s" % [what, Format.duration(seconds_left)]


## The footprint tile; SELECTED also inks the outlines in gold.
func set_footprint(mode: Footprint) -> void:
	_footprint.visible = mode != Footprint.NONE
	if mode != Footprint.NONE:
		_footprint_material.albedo_color = FOOTPRINT_COLORS[mode]
	_selected = mode == Footprint.SELECTED
	_update_outlines()


## A wall that BaseView's merged wall mesh draws hides its model; the footprint tile, the
## label and the lift stay the view's. The scaffold, shown while the level is 0, is untouched.
## Its outlines go with the model, so a merged wall shows no gold when it is selected.
func set_merged(on: bool) -> void:
	_merged = on
	_model.visible = not on and not _scaffold.visible


## Whether the view draws its own model: finished, and not drawn by the merged wall mesh.
func is_model_visible() -> bool:
	return _model.visible


## Raised slightly while being dragged, so it reads as "picked up", with gold outlines (a
## ghost's stay plain). A drone working over the site follows it up or down, and so does the
## label over the drone.
func set_lifted(lifted: bool) -> void:
	var height := LIFT_HEIGHT if lifted else 0.0
	_model.position = Vector3(0, height, 0)
	_scaffold.position = Vector3(0, height, 0)
	_lifted = lifted
	_update_outlines()
	if _drone != null and not _drone.is_leaving():
		_drone.set_site_top(site_height())
		_place_label()


## Marks the view as a placement ghost and tints its bodies for a spot it can (valid) or cannot
## take; its outlines stay plain ink.
func set_ghost(valid: bool) -> void:
	var material := MaterialKit.ghost_valid() if valid else MaterialKit.ghost_invalid()
	if material == _ghost_tint:
		return
	_ghost_tint = material
	_update_outlines()
	for body: MeshInstance3D in _bodies:
		if body.mesh.surface_get_material(0) == MaterialKit.toon():
			body.set_surface_override_material(0, material)


## Whitens the bodies (MaterialKit.hit_flash) for the moment the building is hit in battle, or
## clears it. A ghost keeps its tint.
func set_flash(on: bool) -> void:
	if on == _flashed or _ghost_tint != null:
		return
	_flashed = on
	_apply_tint()


## Dims the bodies grey (MaterialKit.disabled) while an EMP burst has the building disabled in
## battle, or clears it; a hit's flash shows over it. While it is disabled its moving parts hold
## their pose; cleared, they snap back to the clock's.
func set_disabled(on: bool) -> void:
	if on == _disabled or _ghost_tint != null:
		return
	_disabled = on
	_apply_tint()


## Whether the building shows as disabled (set_disabled).
func is_disabled() -> bool:
	return _disabled


## A revealed defence fading in, `share` of the way (0 to 1): its bodies take MaterialKit.reveal's
## steps, a bright tint thinning out, its outlines hidden for the first; at 1 it is itself again.
## A hit's flash shows over it.
func set_reveal(share: float) -> void:
	var step := -1 if share >= 1.0 else clampi(floori(share * REVEAL_STEPS), 0, REVEAL_STEPS - 1)
	if step == _reveal_step or _ghost_tint != null:
		return
	_reveal_step = step
	for outline: MeshInstance3D in _outlines:
		outline.visible = step != 0
	_apply_tint()


## The step of the reveal's fade the bodies show (set_reveal), -1 for none.
func reveal_step() -> int:
	return _reveal_step


## Gives the bodies a rival colony's faction tint (MaterialKit.rival), or takes it off; the
## outlines stay plain ink. For a battle's defender (BattleView), never a ghost.
func set_rival(on: bool) -> void:
	if on == _rival or _ghost_tint != null:
		return
	_rival = on
	_apply_tint()


## The bodies' material for the flash, the reveal, the grey and the faction tint: the flash over the
## reveal over the grey over the plain body, each in its rival version on a rival building, whose
## plain body is rival().
func _apply_tint() -> void:
	var material: Material = MaterialKit.rival() if _rival else null
	if _flashed:
		material = MaterialKit.hit_flash_rival() if _rival else MaterialKit.hit_flash()
	elif _reveal_step >= 0:
		material = MaterialKit.reveal(_reveal_step, _rival)
	elif _disabled:
		material = MaterialKit.disabled_rival() if _rival else MaterialKit.disabled()
	for body: MeshInstance3D in _bodies:
		if body.mesh.surface_get_material(0) == MaterialKit.toon():
			body.set_surface_override_material(0, material)


## The builder drone over the site (working or leaving), null when there is none.
func drone() -> ConstructionDrone:
	return _drone


## The top of what the view shows now, lift included: the scaffold while the level show_status
## was last given is 0, else the model. Not building_level: a view kept while it is dragged shows
## its finished model before it is rebuilt.
func site_height() -> float:
	var site := _scaffold if _scaffold.visible else _model
	return ConstructionDrone.top_of(site) + site.position.y


## Hands a drone that is still over the site to `parent`, where it finishes its work or its
## leaving: the view is about to be freed. Returns it, or null when there is none.
func release_drone(parent: Node) -> ConstructionDrone:
	var released := _drone
	if released != null:
		released.release(parent)
		_drone = null
	return released


func _process(delta: float) -> void:
	if _drone != null and not _drone.advance(delta):
		_drone = null
		set_process(not _movers.is_empty())
	if not _animate or _disabled:
		return
	var time := Motion.clock()
	for i: int in _movers.size():
		_pose(i, time)


## Poses moving part `i` at `time`: its Motion (the aiming head's aim, idle Motion and kick), carried
## by the part it rides as that part stands now.
func _pose(i: int, time: float) -> void:
	var pose: Transform3D
	if i == _aim_index:
		pose = _aim_pose(time)
	elif i == _pitch_index:
		# A rider that pitches follows its own idle Motion (an elevation swing) until it aims.
		if _aim == Aim.IDLE:
			pose = _motions[i].transform_at(time, _rests[i])
		else:
			pose = Transform3D(Basis.IDENTITY, _rests[i]) * _pitched()
	else:
		pose = _motions[i].transform_at(time, _rests[i])
	var on := _rides[i]
	if on >= 0:
		pose = _movers[on].transform * Transform3D(Basis.IDENTITY, -_rests[on]) * pose
	_movers[i].transform = pose


## The aiming head's pose at `time`: the aim's yaw (or its idle scan's), then the rest of its idle
## Motion, then the kick of its last shot back along its muzzle.
func _aim_pose(time: float) -> Transform3D:
	var yaw := _aim_yaw if _aim != Aim.IDLE else _idle_yaw(time)
	var pose := Transform3D(Basis(Vector3.UP, yaw), _rests[_aim_index])
	if _pitch_index == _aim_index:
		pose = pose * _pitched()
	# An idle that is not a scan runs under the aim, but gives way to a pitch while it aims.
	if not _aim_turns and (_pitch_index != _aim_index or _aim == Aim.IDLE):
		pose = pose * _motions[_aim_index].transform_at(time, Vector3.ZERO)
	if _pitch_index < 0:
		pose = pose * _kicked()
	return pose


## The pitching part's own turn: its pitch about its trunnion, then the kick along its pitched
## muzzle.
func _pitched() -> Transform3D:
	var pitch := Transform3D(Basis(_pitch_axis, _pitch), Vector3.ZERO)
	pitch = Transform3D(Basis.IDENTITY, _trunnion) * pitch * Transform3D(Basis.IDENTITY, -_trunnion)
	return pitch * _kicked()


## The kick of the last shot, back along the muzzle as built (in the kicked part's own space).
func _kicked() -> Transform3D:
	var kick := recoil_share()
	if kick <= 0.0:
		return Transform3D.IDENTITY
	return Transform3D(Basis.IDENTITY, -_muzzle_direction * _kick_reach * kick)


## The pitch its idle Motion gives the barrels at `time`: an elevation swing's (a SWING of the
## pitching part about the line it pitches about, through its trunnion: the orbital cannon's), so the
## aim takes the barrels up from where the swing has them and hands them back to it; 0 for any other.
func _idle_pitch(time: float) -> float:
	if _pitch_index < 0:
		return 0.0
	var idle := _motions[_pitch_index]
	var along := idle.axis.dot(_pitch_axis)
	if idle.kind != Motion.Kind.SWING or absf(along) < 0.999 or not _trunnion.is_zero_approx():
		return 0.0
	return idle.angle_at(time) * signf(along)


## The aiming head's yaw its idle Motion gives at `time`: its scan's, 0 when it does not turn about +Y.
func _idle_yaw(time: float) -> float:
	return _motions[_aim_index].angle_at(time) if _aim_turns else 0.0


## Whether the view has a head that aims (a `muzzle` socket on a moving part).
func can_aim() -> bool:
	return _aim_index >= 0


## Turns the aiming head towards the world point `point` at `rate` and pitches its barrels towards
## `elevation` (radians over level, its muzzle's) at `pitch_rate` (each the share of the way a
## second, as an exponential rate), for `step` seconds of battle, the battle's clock at `now`; from
## its idle swing, it starts from where the swing has it.
func aim_at(point: Vector3, elevation: float, now: float, step: float, rate: float, pitch_rate: float) -> void:
	if _aim_index < 0:
		return
	_now = now
	if _aim == Aim.IDLE:
		_aim_yaw = _idle_yaw(Motion.clock())
		_pitch = _idle_pitch(Motion.clock())
	_aim = Aim.AIMING
	_aim_wait = 0.0
	_aim_yaw = lerp_angle(_aim_yaw, _aim_wanted(point), 1.0 - exp(-rate * step))
	if _pitch_index >= 0:
		_pitch_wanted = elevation - _built_elevation
		_pitch = lerpf(_pitch, _pitch_wanted, 1.0 - exp(-pitch_rate * step))
	_pose_aim()


## How far (radians) the aiming head is from facing the world point `point`, or its barrels from
## the elevation last asked for (aim_at), whichever is more.
func aim_error(point: Vector3) -> float:
	if _aim_index < 0:
		return 0.0
	var yaw := _aim_yaw if _aim != Aim.IDLE else _idle_yaw(Motion.clock())
	return maxf(absf(angle_difference(yaw, _aim_wanted(point))), absf(_pitch_wanted - _pitch))


## Whether the view pitches its barrels (its aiming part has a `trunnion` socket).
func can_pitch() -> bool:
	return _pitch_index >= 0


## The barrels' elevation now (radians over level, the muzzle's as built plus its pitch).
func elevation() -> float:
	return _built_elevation + _pitch


## Where the barrels pitch about, in the world: the trunnion as it stands now (the view's origin
## for a view that does not pitch).
func pitch_origin() -> Vector3:
	if _pitch_index < 0:
		return global_position
	return _movers[_pitch_index].global_transform * _trunnion


## The aiming head has no target for `step` seconds of battle, the battle's clock at `now`: it holds
## its aim, then after AIM_IDLE_SECONDS eases back to its idle swing at `rate` and follows it again.
func idle_aim(now: float, step: float, rate: float) -> void:
	_now = now
	match _aim:
		Aim.AIMING:
			_aim_wait += step
			if _aim_wait >= AIM_IDLE_SECONDS:
				_aim = Aim.RETURNING
		Aim.RETURNING:
			var swing := _idle_yaw(Motion.clock())
			var elevation := _idle_pitch(Motion.clock())
			_aim_yaw = lerp_angle(_aim_yaw, swing, 1.0 - exp(-rate * step))
			_pitch = lerpf(_pitch, elevation, 1.0 - exp(-rate * step))
			_pitch_wanted = elevation
			if absf(angle_difference(_aim_yaw, swing)) < AIM_SETTLED and absf(_pitch - elevation) < AIM_SETTLED:
				_aim = Aim.IDLE
				_pitch = 0.0
			_pose_aim()


## The head's yaw (from its rest) that faces the world point `point`.
func _aim_wanted(point: Vector3) -> float:
	var at := _movers[_aim_index].global_position
	return atan2(point.x - at.x, point.z - at.z) - _aim_heading


## The aiming head fired at `now` on the battle's clock: it kicks back along its muzzle by `reach`
## (world units, its type's Weapons record's `recoil`) over RECOIL_SECONDS. BattleView calls it as
## a shot leaves a muzzle (_muzzle).
func fired(now: float, reach: float) -> void:
	if _aim_index < 0 or _disabled:
		return
	_now = now
	_fired_at = now
	_kick_reach = reach
	_pose_aim()


## How far into its kick the aiming head is now, 0 (at rest) to 1 (fully back); 0 for a view that
## never aims or has not fired lately.
func recoil_share() -> float:
	var u := (_now - _fired_at) / RECOIL_SECONDS
	if u < 0.0 or u >= 1.0:
		return 0.0
	return (Motion.recoil(u * 0.8) + 1.0) * 0.5


## Poses the aiming head at once, so its sockets are where it now faces (_process poses it too).
func _pose_aim() -> void:
	_pose(_aim_index, Motion.clock())
	if _pitch_index > _aim_index:
		_pose(_pitch_index, Motion.clock())


## Whether the model has the socket `name`.
func has_socket(name: String) -> bool:
	return _sockets.has(name)


## Where the socket `name` is now, in the world (the view's origin if there is none).
func socket_point(name: String) -> Vector3:
	if not _sockets.has(name):
		return global_position
	return _socket_nodes[name].global_transform * _sockets[name].position


## The way the socket `name` faces now, in the world.
func socket_direction(name: String) -> Vector3:
	if not _sockets.has(name):
		return Vector3.FORWARD
	return (_socket_nodes[name].global_transform.basis * _sockets[name].direction).normalized()


## The timer label's height with no drone over the site.
func _label_height() -> float:
	return 1.4 + footprint_size * 0.4


## Holds the label LABEL_OVER_DRONE above the highest point the working drone reaches.
func _place_label() -> void:
	_label.position.y = maxf(_label_height(), _drone.ceiling() + LABEL_OVER_DRONE)


func _update_outlines() -> void:
	var inked := (_selected or _lifted) and _ghost_tint == null
	if inked == _inked:
		return
	_inked = inked
	var material: Material = MaterialKit.ink_selected() if inked else null
	for outline: MeshInstance3D in _outlines:
		outline.set_surface_override_material(0, material)


func _collect_meshes(node: Node) -> void:
	for child: Node in node.get_children():
		if child is MeshInstance3D:
			if child.has_meta(BuildingModels.OUTLINE_META):
				_outlines.append(child as MeshInstance3D)
			else:
				_bodies.append(child as MeshInstance3D)
		_collect_meshes(child)


func _collect_movers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Node3D and child.has_meta(BuildingModels.MOVE_META):
			var mover := child as Node3D
			_movers.append(mover)
			_motions.append(mover.get_meta(BuildingModels.MOVE_META) as Motion)
			_rests.append(mover.position)
			_rides.append(int(mover.get_meta(BuildingModels.RIDES_META, -1)))
			if mover.has_meta(BuildingModels.MARCH_META):
				_marching.append(mover)
		_collect_movers(child)


## The sockets of the model's root and of its moving parts; the moving part with a `muzzle` aims,
## turned by itself or by the part it rides, and pitches when it has a `trunnion`.
func _collect_sockets(root: Node3D) -> void:
	_add_sockets(root)
	for i: int in _movers.size():
		_add_sockets(_movers[i])
		if _socket_nodes.get("muzzle") == _movers[i]:
			_aim_index = i if _rides[i] < 0 else _rides[i]
			var facing := _sockets["muzzle"].direction.normalized()
			_aim_heading = atan2(facing.x, facing.z)
			_muzzle_direction = facing
			var idle := _motions[_aim_index]
			_aim_turns = idle.kind != Motion.Kind.SLIDE and idle.axis.dot(Vector3.UP) > 0.999
			if _socket_nodes.get("trunnion") == _movers[i]:
				_pitch_index = i
				_trunnion = _sockets["trunnion"].position
				_built_elevation = asin(clampf(facing.y, -1.0, 1.0))
				_pitch_axis = Vector3(facing.x, 0.0, facing.z).cross(Vector3.UP).normalized()


func _add_sockets(node: Node3D) -> void:
	if not node.has_meta(BuildingModels.SOCKETS_META):
		return
	var on: Dictionary[String, LowPolyMesh.Socket] = node.get_meta(BuildingModels.SOCKETS_META)
	for name: String in on:
		_sockets[name] = on[name]
		_socket_nodes[name] = node
