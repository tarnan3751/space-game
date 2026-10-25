class_name BattleEffects
extends Node3D
## The battle's effects (docs/reference/battle-view.md), each kind batched into one MultiMesh so a
## battle's worth of them costs a fixed handful of draws. A weapon's shot (fire(), by its Weapons
## record) flies as its own projectile: a glowing bolt of its size (lasers, rifle bolts, tracers,
## plasma, the orbital cannon's ball, shells; straight or on an arc, leaving smoke or glowing wisps
## behind), a missile on a lofted arc with its flame, a bomb falling from its bay, an EMP pulse ring
## travelling to its target, or a stretched glow between the ends (a railgun's instant streak, a
## held beam, the gravity well's vortex), or the arc tower's lightning with its branches. It
## leaves its muzzle with a flash (a comic star facing the camera, or a swelling ring) and lands
## by its record's impact (land()): sparks, a ring, a blast (a fireball, rings, smoke, a scorch,
## debris), a burst in the air, a plasma splash, a burn or EMP arcs, with a glow decal under it
## for its light (an additive disc on the ground: no light node). Under them: the impacts
## (expanding hologram discs that fade), the smoke puffs (trails, dust, smoke columns), the
## sparks, the debris (chunks thrown on arcs that settle and shrink away), the stun crackle on a
## stunned unit, the scorch marks, the strips fallen walls leave, the health bars, and the
## abilities' (a repair swarm's dome, an orbital strike's crosshair until it lands and its smoke
## after; each a Timed list). A shield generator's pool draws as a faint hologram dome of its own
## while it is up, flickering when it absorbs.
##
## BattleView and BattleUnits feed it from the sim's events and the view's clock (seconds of
## battle shown, which a faster speed runs faster); nothing here reads the sim. Each list is a
## fixed-size set of packed arrays with a live count, an ended entry swapped with the last, so a
## frame allocates nothing, and an entry may start later than it is added (a burst's later bolts,
## a death's blast), drawn at no size until then. A projectile that arrives calls `arrived` with
## the building and the unit it was aimed at (0 for none), for BattleView's hit flashes; an
## instant one (a streak, a beam, lightning) calls it at once.

## Floats per instance in a buffer: a 3D transform (three rows of four), a colour and custom data.
const FLOATS := 20
## How many of each can be on screen at once; more are dropped (the oldest stays).
const MAX_BOLTS := 384
const MAX_MISSILES := 64
const MAX_BOMBS := 32
const MAX_PULSES := 32
const MAX_BEAMS := 64
const MAX_RINGS := 64
## Gravity well vortices at once: one a held unit (a well reaching 12 cells holds every air unit
## in it; a full air raid is about a dozen in one well's reach), two instances each.
const MAX_VORTICES := 24
const MAX_SPARKS := 96
const MAX_DEBRIS := 192
const MAX_PUFFS := 384
const MAX_GLOWS := 128
const MAX_STUNS := 64
const MAX_IMPACTS := 256
const MAX_ARCS := 96
const MAX_SCORCH := 64
const MAX_BARS := 768
## The abilities' effects at once: swarm domes, strike markers, strike smoke.
const MAX_ABILITY_EFFECTS := 32
## Muzzle flashes at once, and how long one lasts.
const MAX_FLASHES := 128
const FLASH_SECONDS := 0.06
## A swarm dome's height for its radius; a strike's: how long its smoke rises from the landing
## and fades, how long its bolt falls from the sky before it lands (ten ticks), its width, and how
## far over the target's top its crosshair hovers and how big it is.
const DOME_HEIGHT := 0.45
const SMOKE_SECONDS := 1.1
const SKY_BOLT_SECONDS := 0.5
const SKY_BOLT_WIDTH := 0.22
const HOVER_OVER := 0.9
const HOVER_SIZE := 0.8
## The fireball's radius as a share of the strike's.
const FIREBALL_SHARE := 0.75
## A bolt's shortest flight.
const BOLT_MIN_SECONDS := 0.06
## A missile's shortest flight and least loft (world units); a bomb's fall (world units a second
## squared) and its shortest and longest drop.
const MISSILE_MIN_SECONDS := 0.25
const MISSILE_MIN_LOFT := 0.6
const BOMB_GRAVITY := 14.0
const BOMB_MIN_SECONDS := 0.3
const BOMB_MAX_SECONDS := 0.8
## How often a projectile with a trail leaves a puff (seconds of battle).
const TRAIL_STEP := 0.04
## A streak's life, a ring flash's, a burst of sparks', a glow decal's, a blast's fireball's (per
## size, small to big), a debris chunk's, and how fast debris falls.
const STREAK_SECONDS := 0.12
const RING_SECONDS := 0.22
const SPARK_SECONDS := 0.16
const GLOW_SECONDS := 0.28
const BLAST_SECONDS: Array[float] = [0.3, 0.36, 0.48]
const DEBRIS_SECONDS := 2.2
const DEBRIS_GRAVITY := 12.0
## How far short of the point it was aimed at a shot's impact lands at least (world units).
const SURFACE := 0.35
## How long a scorch mark lasts.
const SCORCH_SECONDS := 20.0
## A vortex: its strands' turns along the beam, how fast they turn (radians a second: their bands
## scroll towards the well), its fade in and out, its sheath's pulse (a second) and how far it
## swells, and how often its ends emit: a ring tightening round the held unit (its life, its size
## there), a ring sliding down the beam to the well (how long it takes, its size against the beam's
## width, how much it narrows on the way); and the well's own while it holds anything: a glow round
## its plinth, pulsing, and a swirl ring at its mouth.
const VORTEX_TURNS := 3
const VORTEX_SPIN := 6.0
const VORTEX_FADE_IN := 0.15
const VORTEX_FADE_OUT := 0.3
const VORTEX_PULSE := 1.5
const VORTEX_SWELL := 0.15
const VORTEX_RING_SECONDS := 0.5
const VORTEX_RING_SIZE := 0.55
const VORTEX_SLIDE_STEP := 0.3
const VORTEX_SLIDE_SECONDS := 0.7
const VORTEX_SLIDE_SIZE := 1.8
const VORTEX_SLIDE_NARROW := 0.55
const VORTEX_GLOW_STEP := 0.3
const VORTEX_SWIRL_STEP := 0.6
const VORTEX_SWIRL_SIZE := 0.75
const MAX_WELLS := 16
## A vortex's rings at once: the tightening one and the sliding ones (VORTEX_SLIDE_SECONDS over
## VORTEX_SLIDE_STEP, rounded up).
const VORTEX_RINGS := 4
## A strand's bands a turn (lilac and violet in turn).
const VORTEX_BANDS := 4
## The vortex's shader: unshaded, alpha-blended, both sides; it draws the mesh's part (UV.x) the
## instance's custom data x names and collapses the other to a point in vertex() (no fragments);
## the sheath's alpha falls from its colour's at the core's edge to nothing at its rim, by how
## square on its normal faces the view.
const VORTEX_SHADER := """shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;
varying float sheath;
void vertex() {
	if (abs(UV.x - INSTANCE_CUSTOM.x) > 0.5) {
		VERTEX = vec3(0.0);
	}
	sheath = 1.0 - UV.x;
}
void fragment() {
	float edge = mix(1.0, pow(abs(dot(normalize(NORMAL), VIEW)), 1.6), sheath);
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * edge;
}
"""
## The vortex's colours: its pale core, its strands' bands, its sheath (its alpha at the core's
## edge, falling to nothing at the rim), the sliding rings, the well's glow.
const VORTEX_CORE := Color("fff6ff")
const VORTEX_BAND := Color("e4b8ff")
const VORTEX_DEEP := Color("9b5cff")
const VORTEX_HAZE := Color(0.82, 0.55, 1.0, 0.5)
const VORTEX_GLOW := Color("f0d0ff")
## A smoke column's puffs: one this often, each lasting this long and rising this far.
const SMOKE_COLUMN_STEP := 0.25
const SMOKE_COLUMN_PUFF := 1.6
const SMOKE_COLUMN_RISE := 2.2
## An impact's life and how far it grows from its start.
const IMPACT_SECONDS := 0.32
const IMPACT_START := 0.25
## A lightning arc's life, and its main strike's thickness against a branch's.
const ARC_SECONDS := 0.28
const ARC_MAIN := 1.3
## The arcs' tint over their pale surface: the arc tower's blue, lightened.
const ARC_TINT := Color(0.62, 0.78, 1.0)
## A health bar's size in world units (the fill inside the ink back) and its ink border.
const BAR_SIZE := Vector2(0.7, 0.09)
const BAR_BORDER := 0.03
## A shield's dome is this tall for its radius, and flickers for this long, this often, when its
## pool absorbs, between full and SHIELD_FLICKER_FADE faded, brighter (SHIELD_FLICKER_BRIGHT) on its
## full beats; when the pool is gone it fades out over SHIELD_DROP_SECONDS, swelling a little, in a
## ring. The shield generators a battle can draw.
const SHIELD_HEIGHT := 0.55
const SHIELD_FLICKER_SECONDS := 0.3
const SHIELD_FLICKER_RATE := 20.0
const SHIELD_FLICKER_FADE := 0.55
const SHIELD_FLICKER_BRIGHT := 1.6
const SHIELD_DROP_SECONDS := 0.4
const SHIELD_DROP_SWELL := 0.08
const MAX_SHIELDS := 16

## Called with (building id, unit id) when a bolt aimed at either arrives.
var arrived: Callable
## Harness hooks, read by no game code: projectiles started so far, and where the last one started
## and its colour (the rig scenario's checks).
var bolts_fired: int = 0
var last_bolt_from := Vector3.ZERO
var last_bolt_color := Color.WHITE


## Effects that each last from a start for some seconds at a point with a radius and a colour,
## drawn from one MultiMesh: a fixed-size set of packed arrays and a live count, an ended entry
## swapped with the last.
class Timed:
	## How an entry is placed: on the ground scaled by its radius (GROUND), the same turned to
	## face the camera (FACING: a flat mesh stood up in the view's plane), a column falling from
	## SKY onto its point over its life (FALLING: the mesh one unit tall, its radius the
	## column's width), or rising its `lift` and swelling from its point (RISING).
	## POP: swells to its radius and back to nothing over its life (an opaque flash, which
	## cannot fade). FLASH: faces the camera as FACING does, at its radius at once, shrinking to
	## nothing over its life (a muzzle flash, which shows on the frame it is fired). SWELL: faces
	## the camera, growing to its radius (a ring flash). BURST: faces the camera, flying out past
	## its radius and gone by the end (sparks). GLOW: on the ground at its radius, its colour
	## fading to nothing (an additive glow decal, which fades by its colour). CLOUD: faces the camera,
	## rising its `lift` and swelling as RISING does, its colour's alpha fading by its share of its
	## life raised to `fade_power` (a smoke puff, on a material that fades by its colour). MARK: on
	## the ground at its radius, shrinking away over the last MARK_SHRINK of its life (a scorch).
	enum Mode { GROUND, FACING, FALLING, RISING, POP, FLASH, SWELL, BURST, GLOW, CLOUD, MARK }
	var mode: Mode = Mode.GROUND
	## The camera's plane, for the modes facing it: its right, its up, towards it.
	var facing := Basis()
	var multimesh: MultiMesh
	var buffer: Instances
	var count := 0
	var at := PackedVector3Array()
	var radius := PackedFloat32Array()
	var start := PackedFloat32Array()
	var seconds := PackedFloat32Array()
	var color := PackedColorArray()
	var lift := PackedFloat32Array()
	## Whether the buffer was last handed over with nothing in it.
	var _empty := false

	func _init(mesh: MultiMesh, capacity: int, how: Mode = Mode.GROUND) -> void:
		mode = how
		multimesh = mesh
		buffer = Instances.new(capacity)
		at.resize(capacity)
		radius.resize(capacity)
		start.resize(capacity)
		seconds.resize(capacity)
		color.resize(capacity)
		lift.resize(capacity)

	func add(point: Vector3, size: float, now: float, length: float, tint: Color, rise: float = RISE) -> void:
		if count == at.size() or size <= 0.0:
			return
		at[count] = point
		radius[count] = size
		start[count] = now
		seconds[count] = maxf(length, 0.001)
		color[count] = tint
		lift[count] = rise
		count += 1

	## Ends now every entry at `point`'s ground spot (x and z), so it is dropped on the next draw.
	func end_at(point: Vector3, now: float) -> void:
		for i: int in count:
			if absf(at[i].x - point.x) < 0.01 and absf(at[i].z - point.z) < 0.01:
				seconds[i] = maxf(0.001, now - start[i])

	func remove(i: int) -> void:
		count -= 1
		at[i] = at[count]
		radius[i] = radius[count]
		start[i] = start[count]
		seconds[i] = seconds[count]
		color[i] = color[count]
		lift[i] = lift[count]

	## Drops the entries ended by `now` and writes the rest by `mode` (scaled by their radius, its
	## height `height` times it on the ground, faded by their share of their life raised to
	## `fade_power`, 0 for none); an entry whose start is still to come is written at no size. Hands
	## the buffer to the MultiMesh, unless it was empty and still is.
	func draw(now: float, height: float, fade_power: float) -> void:
		if count == 0 and _empty:
			return
		var i := 0
		while i < count:
			var t := (now - start[i]) / seconds[i]
			if t >= 1.0:
				remove(i)
				continue
			var fade := pow(clampf(t, 0.0, 1.0), fade_power) if fade_power > 0.0 else 0.0
			var r := radius[i] if t >= 0.0 else 0.0
			var k := clampf(t, 0.0, 1.0)
			var basis := Basis.from_scale(Vector3(r, r * height, r))
			var origin := at[i]
			var tint := color[i]
			match mode:
				Mode.FACING:
					# The mesh's up to the view's towards, its z to the view's down: a turn, not a mirror,
					# so the faces keep their winding.
					basis = Basis(facing.x * r, facing.z * r, -facing.y * r)
				Mode.FLASH:
					var left := r * (1.0 - k)
					basis = Basis(facing.x * left, facing.z * left, -facing.y * left)
				Mode.SWELL:
					var grown := r * (0.35 + 0.65 * sqrt(k))
					basis = Basis(facing.x * grown, facing.z * grown, -facing.y * grown)
				Mode.BURST:
					var out := r * (0.6 + 0.6 * k) * (1.0 - k * k * k)
					basis = Basis(facing.x * out, facing.z * out, -facing.y * out)
				Mode.FALLING:
					var length := SKY * k
					basis = Basis.from_scale(Vector3(r, maxf(length, 0.001), r))
					origin = at[i] + Vector3.UP * (SKY - length)
				Mode.POP:
					var pop := r * sin(PI * pow(k, POP_EASE))
					basis = Basis.from_scale(Vector3(pop, pop * height, pop))
				Mode.RISING:
					var grow := r * (0.6 + 0.8 * k)
					basis = Basis.from_scale(Vector3(grow, grow, grow))
					origin = at[i] + Vector3.UP * (lift[i] * k)
				Mode.GLOW:
					tint = tint * (1.0 - k)
				Mode.CLOUD:
					var swell := r * (0.6 + 0.8 * k)
					basis = Basis(facing.x * swell, facing.z * swell, -facing.y * swell)
					origin = at[i] + Vector3.UP * (lift[i] * k)
					tint.a *= 1.0 - fade
				Mode.MARK:
					var left := r * clampf((1.0 - k) / MARK_SHRINK, 0.0, 1.0)
					basis = Basis.from_scale(Vector3(left, 1.0, left))
			buffer.put(i, basis, origin, tint, Color(0, 0, 0, fade))
			i += 1
		multimesh.buffer = buffer.data
		multimesh.visible_instance_count = count
		_empty = count == 0


## A POP entry's swell: its life's share raised to this, so it is near its full size a third of the
## way in and shrinks slowly after.
const POP_EASE := 0.55
## The share of a MARK's life over which it shrinks away.
const MARK_SHRINK := 0.25
## Where a falling column starts, and how far a rising entry climbs over its life by default
## (world units).
const SKY := 8.0
const RISE := 1.6


## A MultiMesh's buffer (TRANSFORM_3D, colours, custom data: FLOATS a instance), written in place,
## for BattleEffects and BattleUnits.
class Instances:
	var data := PackedFloat32Array()

	func _init(count: int) -> void:
		data.resize(count * FLOATS)

	## Instance `i`: its basis and origin, its colour and its custom data.
	func put(i: int, basis: Basis, origin: Vector3, color: Color, custom: Color) -> void:
		var k := i * FLOATS
		data[k] = basis.x.x
		data[k + 1] = basis.y.x
		data[k + 2] = basis.z.x
		data[k + 3] = origin.x
		data[k + 4] = basis.x.y
		data[k + 5] = basis.y.y
		data[k + 6] = basis.z.y
		data[k + 7] = origin.y
		data[k + 8] = basis.x.z
		data[k + 9] = basis.y.z
		data[k + 10] = basis.z.z
		data[k + 11] = origin.z
		data[k + 12] = color.r
		data[k + 13] = color.g
		data[k + 14] = color.b
		data[k + 15] = color.a
		data[k + 16] = custom.r
		data[k + 17] = custom.g
		data[k + 18] = custom.b
		data[k + 19] = custom.a


## Projectiles in flight from one MultiMesh, each from a start to an end over its seconds: on an
## arc `arc` high over the straight line (0 for straight), or falling (a bomb: carried along at
## its speed, dropping under gravity); its mesh along +Z, `width` across and `length` along (a
## pulse grows across as it flies). Each keeps what it was aimed at, its impact's size (0 for
## none) and its record, and when its trail leaves its next puff.
class Flights:
	var multimesh: MultiMesh
	var buffer: Instances
	var count := 0
	var grows := false
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	var start := PackedFloat32Array()
	var seconds := PackedFloat32Array()
	var arc := PackedFloat32Array()
	var width := PackedFloat32Array()
	var length := PackedFloat32Array()
	var impact := PackedFloat32Array()
	var trail_at := PackedFloat32Array()
	var falls := PackedByteArray()
	var color := PackedColorArray()
	var building := PackedInt32Array()
	var unit := PackedInt32Array()
	var weapon: Array[Weapons.Weapon] = []
	var _empty := false

	func _init(mesh: MultiMesh, capacity: int, grow: bool = false) -> void:
		multimesh = mesh
		grows = grow
		buffer = Instances.new(capacity)
		from.resize(capacity)
		to.resize(capacity)
		start.resize(capacity)
		seconds.resize(capacity)
		arc.resize(capacity)
		width.resize(capacity)
		length.resize(capacity)
		impact.resize(capacity)
		trail_at.resize(capacity)
		falls.resize(capacity)
		color.resize(capacity)
		building.resize(capacity)
		unit.resize(capacity)
		weapon.resize(capacity)

	func add(a: Vector3, b: Vector3, now: float, flight: float, peak: float, across: float, along: float,
			tint: Color, size: float, record: Weapons.Weapon, aimed_building: int, aimed_unit: int,
			fall: bool = false) -> void:
		if count == from.size():
			return
		var i := count
		count += 1
		from[i] = a
		to[i] = b
		start[i] = now
		seconds[i] = maxf(flight, 0.001)
		arc[i] = peak
		width[i] = across
		length[i] = along
		color[i] = tint
		impact[i] = size
		weapon[i] = record
		building[i] = aimed_building
		unit[i] = aimed_unit
		falls[i] = 1 if fall else 0
		trail_at[i] = now

	func remove(i: int) -> void:
		count -= 1
		var last := count
		from[i] = from[last]
		to[i] = to[last]
		start[i] = start[last]
		seconds[i] = seconds[last]
		arc[i] = arc[last]
		width[i] = width[last]
		length[i] = length[last]
		impact[i] = impact[last]
		trail_at[i] = trail_at[last]
		falls[i] = falls[last]
		color[i] = color[last]
		building[i] = building[last]
		unit[i] = unit[last]
		weapon[i] = weapon[last]
		weapon[last] = null

	## Where entry `i` is at `t` of its flight.
	func point(i: int, t: float) -> Vector3:
		if falls[i] == 1:
			var along := from[i].lerp(to[i], t)
			return Vector3(along.x, lerpf(from[i].y, to[i].y, t * t), along.z)
		return from[i].lerp(to[i], t) + Vector3.UP * (arc[i] * 4.0 * t * (1.0 - t))

	## The way entry `i` is heading at `t` of its flight.
	func heading(i: int, t: float) -> Vector3:
		var line := to[i] - from[i]
		if falls[i] == 1:
			return Vector3(line.x, line.y * 2.0 * t, line.z)
		return line + Vector3.UP * (arc[i] * 4.0 * (1.0 - 2.0 * t))


## Stretched glows from one MultiMesh, each from a start to an end (a unit-long mesh along +Z,
## scaled to the distance), `width` across, thinning to nothing over its seconds by its share of
## its life raised to `power` (1: a streak fading at once; higher: a beam held, then gone).
class Beams:
	var multimesh: MultiMesh
	var buffer: Instances
	var count := 0
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	var start := PackedFloat32Array()
	var seconds := PackedFloat32Array()
	var width := PackedFloat32Array()
	var power := PackedFloat32Array()
	var color := PackedColorArray()
	var _empty := false

	func _init(mesh: MultiMesh, capacity: int) -> void:
		multimesh = mesh
		buffer = Instances.new(capacity)
		from.resize(capacity)
		to.resize(capacity)
		start.resize(capacity)
		seconds.resize(capacity)
		width.resize(capacity)
		power.resize(capacity)
		color.resize(capacity)

	func add(a: Vector3, b: Vector3, now: float, length: float, across: float, thinning: float, tint: Color) -> void:
		if count == from.size() or a.distance_squared_to(b) < 0.0001:
			return
		from[count] = a
		to[count] = b
		start[count] = now
		seconds[count] = maxf(length, 0.001)
		width[count] = across
		power[count] = thinning
		color[count] = tint
		count += 1

	func remove(i: int) -> void:
		count -= 1
		from[i] = from[count]
		to[i] = to[count]
		start[i] = start[count]
		seconds[i] = seconds[count]
		width[i] = width[count]
		power[i] = power[count]
		color[i] = color[count]

	func draw(now: float) -> void:
		if count == 0 and _empty:
			return
		var i := 0
		while i < count:
			var t := (now - start[i]) / seconds[i]
			if t >= 1.0:
				remove(i)
				continue
			var across := width[i] * (1.0 - pow(maxf(t, 0.0), power[i])) if t >= 0.0 else 0.0
			var line := to[i] - from[i]
			buffer.put(i, BattleEffects.along(line.normalized(), across, line.length()), from[i], color[i],
				Color(0, 0, 0, 0))
			i += 1
		multimesh.buffer = buffer.data
		multimesh.visible_instance_count = count
		_empty = count == 0


## Gravity well vortices from one MultiMesh, each from a well's core (`from`) to the unit it holds
## (`to`), from its start for its seconds or until it is ended (end_vortices): two instances of one
## mesh (_vortex_mesh), its sheath (a soft violet tube, its alpha falling from the core's edge to
## its rim, pulsing) and its strands (a double helix of two strands the same way round a pale
## core, VORTEX_TURNS turns along the beam, banded lilac and violet, the bands wider than their
## gaps, turning so the bands scroll from the unit to the well), the instance's custom data x
## picking which part it draws (0 the sheath, 1 the strands). Every sheath is drawn before every
## strand: the sheaths take the low instances, the strands the ones after. Each keeps the well and
## the unit it is for. Its rings (a ring tightening round the unit, rings sliding down the beam)
## are worked out from its own clock each frame into _vortex_rings, so they end with it.
class Vortices:
	var multimesh: MultiMesh
	var buffer: Instances
	var count := 0
	var from := PackedVector3Array()
	var to := PackedVector3Array()
	var start := PackedFloat32Array()
	var seconds := PackedFloat32Array()
	var width := PackedFloat32Array()
	var well := PackedInt32Array()
	var unit := PackedInt32Array()
	var _empty := false

	func _init(mesh: MultiMesh, capacity: int) -> void:
		multimesh = mesh
		buffer = Instances.new(capacity * 2)
		from.resize(capacity)
		to.resize(capacity)
		start.resize(capacity)
		seconds.resize(capacity)
		width.resize(capacity)
		well.resize(capacity)
		unit.resize(capacity)

	func add(a: Vector3, b: Vector3, now: float, length: float, across: float, by: int, held: int) -> void:
		if count == from.size() or a.distance_squared_to(b) < 0.0001:
			return
		from[count] = a
		to[count] = b
		start[count] = now
		seconds[count] = maxf(length, 0.001)
		width[count] = across
		well[count] = by
		unit[count] = held
		count += 1

	func remove(i: int) -> void:
		count -= 1
		from[i] = from[count]
		to[i] = to[count]
		start[i] = start[count]
		seconds[i] = seconds[count]
		width[i] = width[count]
		well[i] = well[count]
		unit[i] = unit[count]


## Chunks thrown from a point, each with its velocity and spin: they fly under DEBRIS_GRAVITY, settle
## where they hit the ground and shrink away over the last quarter of their life.
class Debris:
	var multimesh: MultiMesh
	var buffer: Instances
	var count := 0
	var at := PackedVector3Array()
	var velocity := PackedVector3Array()
	var axis := PackedVector3Array()
	var start := PackedFloat32Array()
	var seconds := PackedFloat32Array()
	var size := PackedFloat32Array()
	var spin := PackedFloat32Array()
	var color := PackedColorArray()
	var _empty := false

	func _init(mesh: MultiMesh, capacity: int) -> void:
		multimesh = mesh
		buffer = Instances.new(capacity)
		at.resize(capacity)
		velocity.resize(capacity)
		axis.resize(capacity)
		start.resize(capacity)
		seconds.resize(capacity)
		size.resize(capacity)
		spin.resize(capacity)
		color.resize(capacity)

	func add(point: Vector3, speed: Vector3, turn: Vector3, rate: float, now: float, length: float, across: float,
			tint: Color) -> void:
		if count == at.size():
			return
		at[count] = point
		velocity[count] = speed
		axis[count] = turn
		spin[count] = rate
		start[count] = now
		seconds[count] = length
		size[count] = across
		color[count] = tint
		count += 1

	func remove(i: int) -> void:
		count -= 1
		at[i] = at[count]
		velocity[i] = velocity[count]
		axis[i] = axis[count]
		spin[i] = spin[count]
		start[i] = start[count]
		seconds[i] = seconds[count]
		size[i] = size[count]
		color[i] = color[count]

	func draw(now: float) -> void:
		if count == 0 and _empty:
			return
		var i := 0
		while i < count:
			var t := now - start[i]
			if t >= seconds[i]:
				remove(i)
				continue
			var s := size[i]
			if t < 0.0:
				buffer.put(i, Basis.from_scale(Vector3.ZERO), at[i], color[i], Color(0, 0, 0, 0))
				i += 1
				continue
			# Flying until it reaches the ground (its half size over it), then resting there.
			var rest := s * 0.35
			var v := velocity[i]
			var p := at[i]
			var g := DEBRIS_GRAVITY * 0.5
			var lands := (v.y + sqrt(maxf(0.0, v.y * v.y + 4.0 * g * (p.y - rest)))) / (2.0 * g)
			var flown := minf(t, lands)
			var where := p + v * flown + Vector3.DOWN * (g * flown * flown)
			where.y = maxf(where.y, rest)
			var shrink := clampf((seconds[i] - t) / (seconds[i] * 0.25), 0.0, 1.0)
			var basis := Basis(axis[i], spin[i] * flown).scaled(Vector3.ONE * s * shrink)
			buffer.put(i, basis, where, color[i], Color(0, 0, 0, 0))
			i += 1
		multimesh.buffer = buffer.data
		multimesh.visible_instance_count = count
		_empty = count == 0


static var BOLT := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.UNLIT, true, false)
## A bolt's soft edge: a hologram sheath round its bright core.
static var BOLT_SHEATH := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.HOLO, true)
static var IMPACT := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.HOLO, true)
static var ARC := Surf.make(MaterialKit.Layer.GLOW, Color("cfe9ff"), 1.0, Surf.UNLIT | Surf.JITTER | Surf.LIGHTNING)
static var SCORCH := Surf.make(MaterialKit.Layer.ROCK, Color("2c2838"), 1.0, Surf.LIT, false, false)
static var SHIELD := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO, true)
## The abilities': a white hologram the instance colour tints (the swarm's dome, the strike's
## crosshair, pulsing), and the strike's grey smoke, rising.
static var ABILITY_HOLO := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.HOLO, true)
static var MARKER := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.HOLO | Surf.PULSE, true)
static var STRIKE_SMOKE := Surf.make(MaterialKit.Layer.GLOW, Color("c9c2e0"), 1.0, Surf.HOLO, true)
## The strike's fireball: an opaque unlit dome the instance colour tints, popping.
static var FIREBALL := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.UNLIT, true, false)
## The strike's bolt from the sky: a bright unlit column the instance colour tints.
static var SKY_BOLT := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.UNLIT, true, false)
## A beam: an unlit glow whose texture flows along it.
static var BEAM := Surf.make(MaterialKit.Layer.GLOW, Color.WHITE, 1.0, Surf.UNLIT | Surf.FLOW, true, false)
## A debris chunk: lit plate the instance colour tints.
static var CHUNK := Surf.make(MaterialKit.Layer.PLATE, Color.WHITE, 1.0, Surf.LIT, false, false)
## The missile's: its hull, nose, fins and flame; the bomb's casing and fins.
static var MISSILE_HULL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true, false)
static var MISSILE_NOSE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, 1.0, Surf.LIT, true, false)
static var FINS := Surf.make(MaterialKit.Layer.HULL, MaterialKit.GUNMETAL, 1.0, Surf.LIT, false, false)
static var FLAME := Surf.make(MaterialKit.Layer.GLOW, Weapons.FLAME_ORANGE, 1.0, Surf.UNLIT, true, false)
static var FLAME_CORE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT, true, false)
static var BOMB_CASING := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.LIT, true, false)
static var BOMB_BAND := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT, true, false)

var _bolts: Flights
var _missiles: Flights
var _bombs: Flights
var _pulses: Flights
var _beams: Beams
var _vortices: Vortices
## The vortices' rings, written each frame from the vortices (VORTEX_RINGS a vortex), and their
## buffer.
var _vortex_rings: MultiMesh
var _vortex_ring_buffer: Instances
## The wells holding anything: their ids, their core, their plinth's rim radius, until when they
## hold (the latest of their vortices' ends), and when they next glow and swirl.
var _wells := PackedInt32Array()
var _well_core := PackedVector3Array()
var _well_rim := PackedFloat32Array()
var _well_until := PackedFloat32Array()
var _well_glow := PackedFloat32Array()
var _well_swirl := PackedFloat32Array()
var _debris: Debris

var _impacts: MultiMesh
var _impact_buffer: Instances
var _impact_count := 0
var _impact_at := PackedVector3Array()
var _impact_start := PackedFloat32Array()
var _impact_radius := PackedFloat32Array()
var _impact_color := PackedColorArray()
var _impact_seconds := PackedFloat32Array()

var _arcs: MultiMesh
var _arc_buffer: Instances
var _arc_count := 0
var _arc_from := PackedVector3Array()
var _arc_to := PackedVector3Array()
var _arc_start := PackedFloat32Array()
var _arc_width := PackedFloat32Array()

## The scorch marks, each from its start for SCORCH_SECONDS (a Timed list, MARK).
var _scorches: Timed

var _wall_rubble: MultiMesh
var _wall_rubble_outline: MultiMesh
var _wall_rubble_buffer: Instances
var _wall_rubble_count := 0

var _bars: MultiMesh
var _bar_buffer: Instances
var _bar_count := 0
## The camera's right and up, which every bar faces along (the camera never turns).
var _across := Vector3.RIGHT
var _up := Vector3.UP

## The swarms' domes, the strikes' markers and their smoke, the muzzle flashes, the ring flashes,
## the sparks, the smoke puffs, the glow decals and the stun crackles: each a Timed list over its
## MultiMesh.
var _domes: Timed
var _markers: Timed
var _hover_markers: Timed
var _sky_bolts: Timed
var _fireballs: Timed
var _flashes: Timed
var _smoke: Timed
var _rings: Timed
var _sparks: Timed
var _puffs: Timed
var _glows: Timed
var _stuns: Timed
## A counter the scattering of debris and puffs is drawn from, so it is the same every run.
var _scatter := 0

## The shield domes, one MultiMesh: per generator its instance, centre, radius, pool, when it last
## absorbed (-1 never) and when it dropped (-1 while up).
var _shield_domes: MultiMesh
var _shield_buffer: Instances
var _shields: Dictionary[int, int] = {}
var _shield_at: Dictionary[int, Vector3] = {}
var _shield_radius: Dictionary[int, float] = {}
var _shield_pool: Dictionary[int, int] = {}
var _shield_flicker: Dictionary[int, float] = {}
var _shield_drop: Dictionary[int, float] = {}


## Call once, before adding to the tree. `walls` is how many walls could fall, `area` the field's
## AABB (every instance stays in it).
func setup(walls: int, area: AABB) -> void:
	# A bolt: a bright core in a soft sheath, a unit across, stretched along its flight.
	var bolt_mesh := LowPolyMesh.new()
	bolt_mesh.orb(0.28, 8, 4, Vector3.ZERO, BOLT)
	bolt_mesh.orb(0.5, 8, 4, Vector3.ZERO, BOLT_SHEATH)
	_bolts = Flights.new(_multimesh(bolt_mesh.to_mesh(), MAX_BOLTS, area, false), MAX_BOLTS)

	# A missile along +Z, its nose forward: a white hull, a red nose, four gunmetal fins at the
	# tail and an orange flame behind with a hot core.
	var missile := LowPolyMesh.new()
	Parts.pipe(missile, Vector3(0, 0, -0.15), Vector3(0, 0, 0.1), 0.045, MISSILE_HULL, 8, false)
	missile.cone(0.045, 0.09, 8, Vector3(0, 0, 0.1), MISSILE_NOSE, Parts.facing(Vector3.BACK))
	for k: int in 4:
		var out := Basis(Vector3.BACK, PI * 0.5 * k) * Vector3(0.06, 0, 0)
		missile.box(Vector3(0.012, 0.07, 0.07), out + Vector3(0, 0, -0.12), FINS, Vector3(0, 0, 90.0 * k + 90.0))
	missile.cone(0.04, 0.2, 8, Vector3(0, 0, -0.15), FLAME, Parts.facing(Vector3.FORWARD))
	missile.cone(0.022, 0.12, 6, Vector3(0, 0, -0.15), FLAME_CORE, Parts.facing(Vector3.FORWARD))
	_missiles = Flights.new(_multimesh(missile.to_mesh(), MAX_MISSILES, area, false), MAX_MISSILES)

	# A bomb along +Z, its nose forward: an orange casing, a hazard band, gunmetal fins.
	var bomb := LowPolyMesh.new()
	Parts.pipe(bomb, Vector3(0, 0, -0.08), Vector3(0, 0, 0.06), 0.065, BOMB_CASING, 10, false)
	bomb.dome(0.065, 0.07, 10, 3, Vector3(0, 0, 0.06), BOMB_CASING, Parts.facing(Vector3.BACK))
	bomb.cone(0.065, 0.06, 10, Vector3(0, 0, -0.08), BOMB_CASING, Parts.facing(Vector3.FORWARD))
	Parts.pipe(bomb, Vector3(0, 0, 0.0), Vector3(0, 0, 0.025), 0.068, BOMB_BAND, 10, false)
	for k: int in 4:
		var out := Basis(Vector3.BACK, PI * 0.5 * k) * Vector3(0.06, 0, 0)
		bomb.box(Vector3(0.01, 0.06, 0.06), out + Vector3(0, 0, -0.13), FINS, Vector3(0, 0, 90.0 * k + 90.0))
	_bombs = Flights.new(_multimesh(bomb.to_mesh(), MAX_BOMBS, area, false), MAX_BOMBS)

	# An EMP pulse: a unit-wide ring standing across its flight (+Z), growing as it goes.
	var pulse := LowPolyMesh.new()
	pulse.ring(0.36, 0.5, 0.1, 20, Vector3(0, 0, -0.05), BOLT, Vector3(90, 0, 0))
	_pulses = Flights.new(_multimesh(pulse.to_mesh(), MAX_PULSES, area, false), MAX_PULSES, true)

	# A beam: a six-sided rod a unit across and a unit long along +Z.
	var rod := LowPolyMesh.new()
	Parts.pipe(rod, Vector3.ZERO, Vector3(0, 0, 1), 0.5, BEAM, 6, false)
	_beams = Beams.new(_multimesh(rod.to_mesh(), MAX_BEAMS, area, false), MAX_BEAMS)
	# A vortex: two banded strands twisting round a pale core, a unit across and long along +Z.
	_vortices = Vortices.new(_multimesh(_vortex_mesh(), MAX_VORTICES * 2, area, false), MAX_VORTICES)
	# The vortices' rings: a unit-wide ring standing across +Z, as the pulses' (its own list, so it
	# never takes the EMP's places).
	_vortex_rings = _multimesh(pulse.to_mesh(), MAX_VORTICES * VORTEX_RINGS, area, false)
	_vortex_ring_buffer = Instances.new(MAX_VORTICES * VORTEX_RINGS)
	_wells.resize(MAX_WELLS)
	_well_core.resize(MAX_WELLS)
	_well_rim.resize(MAX_WELLS)
	_well_until.resize(MAX_WELLS)
	_well_glow.resize(MAX_WELLS)
	_well_swirl.resize(MAX_WELLS)
	_wells.fill(0)

	# A debris chunk: a chamfered block a unit across, with a wedge broken off it.
	var chunk := LowPolyMesh.new()
	chunk.box_chamfered(Vector3(1.0, 0.7, 0.85), 0.12, Vector3(0, -0.35, 0), CHUNK)
	chunk.wedge(Vector3(0.6, 0.35, 0.5), Vector3(0.1, 0.35, 0), CHUNK)
	_debris = Debris.new(_multimesh(chunk.to_mesh(), MAX_DEBRIS, area, false), MAX_DEBRIS)

	var disc := LowPolyMesh.new()
	disc.ring(0.32, 0.5, 0.05, 20, Vector3.ZERO, IMPACT)
	disc.disc(0.32, 20, Vector3(0, 0.01, 0), IMPACT)
	_impacts = _multimesh(disc.to_mesh(), MAX_IMPACTS, area, false)
	_impact_buffer = Instances.new(MAX_IMPACTS)
	_impact_at.resize(MAX_IMPACTS)
	_impact_start.resize(MAX_IMPACTS)
	_impact_radius.resize(MAX_IMPACTS)
	_impact_color.resize(MAX_IMPACTS)
	_impact_seconds.resize(MAX_IMPACTS)

	# A kinked strip along +Z from 0 to 1, stretched to each arc's length.
	var arc := LowPolyMesh.new()
	var last := Vector3.ZERO
	for k: int in range(1, 7):
		var point := Vector3(0.0, 0.0, k / 6.0) + (Vector3(0.12 if k % 2 == 1 else -0.12, 0.05, 0) if k < 6 else Vector3.ZERO)
		Parts.pipe(arc, last, point, 0.045, ARC, 3, false)
		last = point
	_arcs = _multimesh(arc.to_mesh(), MAX_ARCS, area, false)
	_arc_buffer = Instances.new(MAX_ARCS)
	_arc_from.resize(MAX_ARCS)
	_arc_to.resize(MAX_ARCS)
	_arc_start.resize(MAX_ARCS)
	_arc_width.resize(MAX_ARCS)

	var scorch := LowPolyMesh.new()
	scorch.disc(0.5, 12, Vector3.ZERO, SCORCH)
	_scorches = Timed.new(_multimesh(scorch.to_mesh(), MAX_SCORCH, area, false), MAX_SCORCH, Timed.Mode.MARK)

	var strip := BuildingModels.wall_rubble()
	_wall_rubble = _multimesh(strip.body, maxi(walls, 1), area, true)
	_wall_rubble_outline = _multimesh(strip.outline, maxi(walls, 1), area, false)
	_wall_rubble_buffer = Instances.new(maxi(walls, 1))

	var quad := ArrayMesh.new()
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-0.5, -0.5, 0), Vector3(0.5, 0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(-0.5, -0.5, 0), Vector3(-0.5, 0.5, 0), Vector3(0.5, 0.5, 0)])
	var white := PackedColorArray()
	white.resize(6)
	white.fill(Color.WHITE)
	arrays[Mesh.ARRAY_COLOR] = white
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var bar_material := StandardMaterial3D.new()
	bar_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_material.vertex_color_use_as_albedo = true
	bar_material.no_depth_test = true
	bar_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	bar_material.render_priority = 1
	quad.surface_set_material(0, bar_material)
	_bars = _multimesh(quad, MAX_BARS, area, false)
	_bar_buffer = Instances.new(MAX_BARS)
	var view := Basis.from_euler(Vector3(deg_to_rad(IsoCamera.PITCH_DEG), deg_to_rad(IsoCamera.YAW_DEG), 0.0))
	_across = view.x
	_up = view.y

	# A unit dome, scaled to a swarm's radius and DOME_HEIGHT of it.
	var dome := LowPolyMesh.new()
	dome.dome(1.0, 1.0, 24, 6, Vector3.ZERO, ABILITY_HOLO)
	_domes = Timed.new(_multimesh(dome.to_mesh(), MAX_ABILITY_EFFECTS, area, false), MAX_ABILITY_EFFECTS)
	# A unit crosshair on the ground: a ring and four ticks pointing in, scaled to a strike's radius.
	var marker := LowPolyMesh.new()
	marker.ring(0.86, 1.0, 0.04, 24, Vector3.ZERO, MARKER)
	for k: int in 4:
		marker.box(Vector3(0.1, 0.04, 0.45), Parts.around(0.62, 90.0 * k, 0.0), MARKER, Vector3(0, 90.0 * k, 0))
	marker.disc(0.12, 12, Vector3(0, 0.01, 0), MARKER)
	var marker_mesh := marker.to_mesh()
	_markers = Timed.new(_multimesh(marker_mesh, MAX_ABILITY_EFFECTS, area, false), MAX_ABILITY_EFFECTS)
	# The same crosshair stood up facing the camera, hovering over the target's top.
	_hover_markers = Timed.new(_multimesh(marker_mesh, MAX_ABILITY_EFFECTS, area, false), MAX_ABILITY_EFFECTS,
		Timed.Mode.FACING)
	_hover_markers.facing = view
	# The bolt from the sky: a column one unit tall, stretched as it falls.
	var column := LowPolyMesh.new()
	column.prism(0.5, 0.5, 1.0, 10, Vector3.ZERO, SKY_BOLT)
	_sky_bolts = Timed.new(_multimesh(column.to_mesh(), MAX_ABILITY_EFFECTS, area, false), MAX_ABILITY_EFFECTS,
		Timed.Mode.FALLING)
	# A fireball (a strike's, a blast's): a dome of unit radius, popping.
	var fireball := LowPolyMesh.new()
	fireball.dome(1.0, 1.0, 16, 4, Vector3.ZERO, FIREBALL)
	_fireballs = Timed.new(_multimesh(fireball.to_mesh(), MAX_ABILITY_EFFECTS * 2, area, false),
		MAX_ABILITY_EFFECTS * 2, Timed.Mode.POP)
	# A strike's smoke: puffs over the ground, a unit across, scaled to its radius, rising and
	# swelling from the landing.
	var smoke := LowPolyMesh.new()
	for k: int in 5:
		smoke.orb(0.22 + 0.04 * k, 8, 3, Parts.around(0.25 * (k % 3), 72.0 * k, 0.1 + 0.15 * k), STRIKE_SMOKE)
	_smoke = Timed.new(_multimesh(smoke.to_mesh(), MAX_ABILITY_EFFECTS, area, false), MAX_ABILITY_EFFECTS,
		Timed.Mode.RISING)
	# A muzzle flash: an eight-pointed star of unit radius, flat, its face up (FLASH turns it to the
	# camera).
	var star := LowPolyMesh.new()
	for k: int in 8:
		var a := Parts.around(1.0 if k % 2 == 0 else 0.42, 45.0 * k, 0.0)
		var b := Parts.around(1.0 if k % 2 == 1 else 0.42, 45.0 * (k + 1), 0.0)
		star.triangle(Vector3.ZERO, b, a, BOLT)
	_flashes = Timed.new(_multimesh(star.to_mesh(), MAX_FLASHES, area, false), MAX_FLASHES, Timed.Mode.FLASH)
	_flashes.facing = view
	# A ring flash: a flat ring of unit radius, its face up, swelling towards the camera.
	var ring := LowPolyMesh.new()
	for k: int in 24:
		var a_in := Parts.around(0.78, 15.0 * k, 0.0)
		var b_in := Parts.around(0.78, 15.0 * (k + 1), 0.0)
		var a_out := Parts.around(1.0, 15.0 * k, 0.0)
		var b_out := Parts.around(1.0, 15.0 * (k + 1), 0.0)
		_both_faces(ring, a_in, b_out, a_out)
		_both_faces(ring, a_in, b_in, b_out)
	_rings = Timed.new(_multimesh(ring.to_mesh(), MAX_RINGS, area, false), MAX_RINGS, Timed.Mode.SWELL)
	_rings.facing = view
	# Sparks: ten thin rays of unit reach round a gap, flat, their face up (BURST turns them to the
	# camera).
	var rays := LowPolyMesh.new()
	for k: int in 10:
		var angle := 36.0 * k + (9.0 if k % 2 == 0 else -6.0)
		var reach := 1.0 if k % 2 == 0 else 0.7
		var tip := Parts.around(reach, angle, 0.0)
		var left := Parts.around(0.3, angle - 6.0, 0.0)
		var right := Parts.around(0.3, angle + 6.0, 0.0)
		_both_faces(rays, left, tip, right)
	_sparks = Timed.new(_multimesh(rays.to_mesh(), MAX_SPARKS, area, false), MAX_SPARKS, Timed.Mode.BURST)
	_sparks.facing = view
	# A smoke puff: a soft disc of unit radius facing the camera, rising, swelling and fading.
	_puffs = Timed.new(_multimesh(_cloud_mesh(), MAX_PUFFS, area, false), MAX_PUFFS, Timed.Mode.CLOUD)
	_puffs.facing = view
	# A glow decal: a unit-radius disc on the ground, an additive radial glow.
	_glows = Timed.new(_multimesh(_glow_mesh(), MAX_GLOWS, area, false), MAX_GLOWS, Timed.Mode.GLOW)
	# A stun crackle: three jittering zigzag arcs round a unit ring, a unit tall.
	var crackle := LowPolyMesh.new()
	for k: int in 3:
		var from := Parts.around(1.0, 120.0 * k, 0.0)
		for s: int in 4:
			var to := Parts.around(1.0 if s % 2 == 1 else 0.7, 120.0 * k + 25.0 * (s + 1), 0.25 * (s + 1))
			Parts.pipe(crackle, from, to, 0.05, ARC, 3, false)
			from = to
	_stuns = Timed.new(_multimesh(crackle.to_mesh(), MAX_STUNS, area, false), MAX_STUNS)
	# A shield's dome, unit radius, SHIELD_HEIGHT tall.
	var shield := LowPolyMesh.new()
	shield.dome(1.0, SHIELD_HEIGHT, 24, 6, Vector3.ZERO, SHIELD)
	_shield_domes = _multimesh(shield.to_mesh(), MAX_SHIELDS, area, false)
	_shield_buffer = Instances.new(MAX_SHIELDS)


# --- Adding ----------------------------------------------------------------------

## `weapon` (a Weapons record) fired from `from` at `to`, from `now`: its projectile by its kind,
## landing by its impact (land()) of `impact` radius at least (none at 0) and calling `arrived`
## with `building` and `unit`, with its muzzle flash at `from` when `flash_on`. `seconds` is a
## flight the sim timed (a shell's, landing then); 0 flies at the record's speed. A burst draws
## its later shots `burst_gap` apart, each with its flash; only the first calls `arrived`.
func fire(weapon: Weapons.Weapon, from: Vector3, to: Vector3, building: int, unit: int, impact: float, now: float,
		flash_on: bool = true, seconds: float = 0.0) -> void:
	_count_shot(from, weapon.color)
	var distance := from.distance_to(to)
	match weapon.kind:
		Weapons.Kind.BOLT, Weapons.Kind.LASER, Weapons.Kind.TRACER, Weapons.Kind.PLASMA, Weapons.Kind.BALL, Weapons.Kind.SHELL:
			var flight := seconds if seconds > 0.0 else maxf(BOLT_MIN_SECONDS, distance / weapon.speed)
			for k: int in weapon.burst:
				var at := now + k * weapon.burst_gap
				_bolts.add(from, to, at, flight, distance * weapon.arc, weapon.width, weapon.length, weapon.color,
					impact, weapon, building if k == 0 else 0, unit if k == 0 else 0)
				if flash_on:
					_muzzle(weapon, from, at)
			return
		Weapons.Kind.MISSILE:
			var flight := seconds if seconds > 0.0 else maxf(MISSILE_MIN_SECONDS, distance / weapon.speed)
			_missiles.add(from, to, now, flight, maxf(MISSILE_MIN_LOFT, distance * weapon.arc), weapon.width,
				weapon.width, Color.WHITE, impact, weapon, building, unit)
			puff(from, 0.12, Weapons.SMOKE, now, 0.6, 0.25)
		Weapons.Kind.BOMB:
			var drop := maxf(from.y - to.y, 0.1)
			var flight := clampf(sqrt(2.0 * drop / BOMB_GRAVITY), BOMB_MIN_SECONDS, BOMB_MAX_SECONDS)
			_bombs.add(from, to, now, flight, 0.0, weapon.width, weapon.width, Color.WHITE, impact, weapon, building,
				unit, true)
		Weapons.Kind.PULSE:
			_pulses.add(from, to, now, maxf(BOLT_MIN_SECONDS, distance / weapon.speed), 0.0, weapon.width,
				weapon.width, weapon.color, impact, weapon, building, unit)
		Weapons.Kind.STREAK, Weapons.Kind.BEAM:
			var streak := weapon.kind == Weapons.Kind.STREAK
			var hold := STREAK_SECONDS if streak else (seconds if seconds > 0.0 else weapon.hold)
			_beams.add(from, to, now, hold, weapon.width, 1.0 if streak else 6.0, weapon.color)
			_arrive(weapon, from, to, impact, building, unit, now)
		Weapons.Kind.LIGHTNING:
			_strike(from, to, now)
			_arrive(weapon, from, to, impact, building, unit, now)
		_:
			_arrive(weapon, from, to, impact, building, unit, now)
	if flash_on:
		_muzzle(weapon, from, now)


## Where `weapon` lands at `at`, `size` across at least, from `now`: its record's impact and the
## glow decal of its light on the ground under it.
func land(weapon: Weapons.Weapon, at: Vector3, size: float, now: float) -> void:
	var r := maxf(size, weapon.impact_size)
	var c := weapon.color
	var ground := Vector3(at.x, 0.0, at.z)
	match weapon.impact:
		Weapons.Impact.SPARKS:
			sparks(at, r, c.lerp(Color.WHITE, 0.45), now)
			impact(at, r * 0.8, c, now, IMPACT_SECONDS * 0.7)
		Weapons.Impact.RING:
			impact(at, r, c, now)
		Weapons.Impact.BLAST_S:
			blast(at, r, 0, now)
		Weapons.Impact.BLAST_M:
			blast(at, r, 1, now)
		Weapons.Impact.BLAST_L:
			blast(at, r, 2, now)
		Weapons.Impact.AIR_BURST:
			air_burst(at, r, c, now)
		Weapons.Impact.SPLASH:
			impact(ground, r, c, now, IMPACT_SECONDS * 1.4)
			impact(ground + Vector3.UP * 0.1, r * 0.55, c.lerp(Color.WHITE, 0.4), now, IMPACT_SECONDS)
			sparks(at + Vector3.UP * 0.2, r * 0.7, c.lerp(Color.WHITE, 0.3), now)
			for k: int in 4:
				puff(ground + Parts.around(r * 0.5, 90.0 * k + 45.0, 0.15), r * 0.22, c, now + 0.03 * k, 0.6, 0.4)
		Weapons.Impact.BURN:
			impact(at, r, c, now, IMPACT_SECONDS * 1.2)
			sparks(at, r * 0.8, c.lerp(Color.WHITE, 0.5), now)
		Weapons.Impact.EMP:
			impact(at, r, c, now)
			stun(at, r, c, now, 0.3)
	if weapon.light > 0.0:
		glow(ground, weapon.light, c.lerp(Weapons.BLAST_CORE, 0.3), now)


## A blast at `at`, `radius` across, from `now`; `size` 0, 1 or 2 (small, medium, big): a star
## flash and a white-hot fireball popping, cooling to a smaller orange one as it shrinks (opaque
## domes, so the orange starts inside the white and shows as it goes), an orange ring on the ground
## and sparks; from medium smoke; a big one a second ring, debris and a scorch (any one when
## `scorched`: a mine's, a wreck's).
func blast(at: Vector3, radius: float, size: int, now: float, scorched: bool = false) -> void:
	var ground := Vector3(at.x, 0.0, at.z)
	var seconds: float = BLAST_SECONDS[size]
	var ball := blast_ball(radius, size)
	flash(at, ball * 1.6, Weapons.BLAST_CORE, now)
	_fireballs.add(at, ball, now, seconds, Weapons.BLAST_CORE)
	_fireballs.add(at, ball * 0.85, now + seconds * 0.45, seconds * 0.8, Weapons.BLAST_RIM)
	impact(ground, radius * 1.1, Weapons.BLAST_RIM, now, seconds * 1.3)
	sparks(at, radius * 0.9, Weapons.BLAST_CORE, now)
	if size >= 2 or scorched:
		scorch(ground, radius * 0.45, now)
	if size >= 1:
		for k: int in 2 + size:
			puff(ground + Parts.around(radius * 0.3, 120.0 * k + 30.0 * size, 0.2), radius * 0.3, Weapons.SMOKE,
				now + 0.08 + 0.05 * k, 1.2 + 0.3 * size, 0.8)
	if size >= 2:
		impact(ground + Vector3.UP * 0.1, radius * 1.6, Weapons.BLAST_RIM.lerp(Weapons.BLAST_CORE, 0.4), now + 0.05,
			seconds * 1.5)
		debris(ground + Vector3.UP * 0.2, 4, radius, 0.12, now, MaterialKit.HULL_DARK, MaterialKit.GUNMETAL)


## A blast of `radius` and `size`'s fireball's radius: how far its centre stands off what it hits.
static func blast_ball(radius: float, size: int) -> float:
	return radius * (0.45 + 0.06 * size)


## A burst in the air at `at`, `radius` across, in `color`, from `now`: a flash, sparks and dark
## puffs hanging where it went off.
func air_burst(at: Vector3, radius: float, color: Color, now: float) -> void:
	flash(at, radius, color.lerp(Color.WHITE, 0.4), now)
	_flashes.add(at, radius * 0.7, now + FLASH_SECONDS, FLASH_SECONDS, color)
	_fireballs.add(at, radius * 0.35, now, 0.22, color.lerp(Color.WHITE, 0.5))
	sparks(at, radius, color, now)
	for k: int in 4:
		puff(at + Parts.around(radius * 0.3, 90.0 * k, 0.05 * k), radius * 0.5, Weapons.DARK_SMOKE,
			now + 0.02 * k, 1.0, 0.15)


## A muzzle flash at `at`, `radius` across, in `color`, from `now`, for FLASH_SECONDS.
func flash(at: Vector3, radius: float, color: Color, now: float) -> void:
	_flashes.add(at, radius, now, FLASH_SECONDS, color)


## A ring flash at `at` swelling to `radius`, in `color`, from `now`, for RING_SECONDS.
func ring_flash(at: Vector3, radius: float, color: Color, now: float, seconds: float = RING_SECONDS) -> void:
	_rings.add(at, radius, now, seconds, color)


## A burst of sparks at `at` flying out to about `radius`, in `color`, from `now`.
func sparks(at: Vector3, radius: float, color: Color, now: float) -> void:
	_sparks.add(at, radius, now, SPARK_SECONDS, color)


## A puff of smoke at `at`, `radius` across, in `color`, from `now` for `seconds`, rising `rise`
## (world units) as it swells and fades.
func puff(at: Vector3, radius: float, color: Color, now: float, seconds: float, rise: float) -> void:
	_puffs.add(at, radius, now, seconds, color, rise)


## A column of dark smoke rising from `at` for `seconds` from `now`, its puffs about `radius`
## across, one every SMOKE_COLUMN_STEP, each rising SMOKE_COLUMN_RISE as it swells and fades.
func smoke_column(at: Vector3, radius: float, now: float, seconds: float) -> void:
	var puffs := int(seconds / SMOKE_COLUMN_STEP)
	for k: int in puffs:
		var drift := Parts.around(radius * 0.4 * _noise(9), 360.0 * _noise(10), 0.15)
		puff(at + drift, radius * (0.8 + 0.4 * _noise(11)), Weapons.SMOKE.lerp(Weapons.DARK_SMOKE, 0.4),
			now + k * SMOKE_COLUMN_STEP, SMOKE_COLUMN_PUFF, SMOKE_COLUMN_RISE)


## A glow decal on the ground at `at`, `radius` across, in `color`, from `now`, fading over
## `seconds`: the fake light under a flash or a blast.
func glow(at: Vector3, radius: float, color: Color, now: float, seconds: float = GLOW_SECONDS) -> void:
	_glows.add(Vector3(at.x, 0.03, at.z), radius, now, seconds, color)


## The crackle of a stun round `at`, `radius` across, in `color`, from `now` for `seconds`.
func stun(at: Vector3, radius: float, color: Color, now: float, seconds: float) -> void:
	_stuns.add(Vector3(at.x, maxf(at.y - radius * 0.5, 0.0), at.z), radius, now, seconds, color)


## Gravity well `well` (its `weapon` record), its core at `from`, its plinth `rim` across, holds
## unit `unit` at `to` from `now` for `seconds`: a vortex the record's width across between them
## (Vortices), and the well's own glow and swirl while it holds anything, once a well however many
## it holds.
func vortex(weapon: Weapons.Weapon, well: int, unit: int, from: Vector3, to: Vector3, rim: float, now: float,
		seconds: float) -> void:
	_count_shot(from, weapon.color)
	_vortices.add(from, to, now, seconds, weapon.width, well, unit)
	var k := _wells.find(well)
	if k < 0:
		k = _wells.find(0)
		if k < 0:
			return
		_wells[k] = well
		_well_glow[k] = now
		_well_swirl[k] = now
		_well_until[k] = now
	_well_core[k] = from
	_well_rim[k] = rim
	_well_until[k] = maxf(_well_until[k], now + seconds)


## Ends now (over VORTEX_FADE_OUT) every vortex of well `well` (0 for any) holding unit `unit` (0
## for any): a held unit died, or the well fell.
func end_vortices(well: int, unit: int, now: float) -> void:
	for i: int in _vortices.count:
		if (well == 0 or _vortices.well[i] == well) and (unit == 0 or _vortices.unit[i] == unit):
			var ends := now + VORTEX_FADE_OUT
			if _vortices.start[i] + _vortices.seconds[i] > ends:
				_vortices.seconds[i] = maxf(ends - _vortices.start[i], 0.001)
	for k: int in MAX_WELLS:
		if _wells[k] == 0:
			continue
		if well != 0:
			if _wells[k] == well:
				_well_until[k] = 0.0
			continue
		# A unit's end: the well holds on while any of its other vortices does.
		_well_until[k] = 0.0
		for i: int in _vortices.count:
			if _vortices.well[i] == _wells[k]:
				_well_until[k] = maxf(_well_until[k], _vortices.start[i] + _vortices.seconds[i])

## A stretched glow from `from` to `to`, `width` across, in `color`, from `now` for `seconds`,
## thinning by its share of its life raised to `power`.
func beam(from: Vector3, to: Vector3, width: float, color: Color, now: float, seconds: float, power: float) -> void:
	_beams.add(from, to, now, seconds, width, power, color)


## `count` debris chunks thrown from `at`, about `spread` far, each about `size` across, from
## `now`, in `color_a` and `color_b` by turns.
func debris(at: Vector3, count: int, spread: float, size: float, now: float, color_a: Color, color_b: Color) -> void:
	for k: int in count:
		var angle := TAU * (k + _noise(1)) / count
		var out := Vector3(cos(angle), 0.0, sin(angle)) * (spread * (1.2 + 1.4 * _noise(2)))
		var speed := out + Vector3.UP * (3.0 + 2.5 * _noise(3))
		var turn := Vector3(_noise(4) - 0.5, 1.0, _noise(5) - 0.5).normalized()
		_debris.add(at, speed, turn, 6.0 + 8.0 * _noise(6), now, DEBRIS_SECONDS * (0.8 + 0.4 * _noise(7)),
			size * (0.7 + 0.6 * _noise(8)), color_a if k % 2 == 0 else color_b)


## An impact at `at`, growing to `radius` and fading, in `color`, from `now`.
## `seconds` is its life, IMPACT_SECONDS by default.
func impact(at: Vector3, radius: float, color: Color, now: float, seconds: float = IMPACT_SECONDS) -> void:
	if _impact_count == MAX_IMPACTS or radius <= 0.0:
		return
	var i := _impact_count
	_impact_count += 1
	_impact_at[i] = at
	_impact_start[i] = now
	_impact_radius[i] = radius
	_impact_color[i] = color
	_impact_seconds[i] = seconds


## A lightning arc from `from` to `to`, from `now`, `width` times a branch's thickness.
func lightning(from: Vector3, to: Vector3, now: float, width: float = 1.0) -> void:
	if _arc_count == MAX_ARCS:
		return
	var i := _arc_count
	_arc_count += 1
	_arc_from[i] = from
	_arc_to[i] = to
	_arc_start[i] = now
	_arc_width[i] = width


## A scorch mark on the ground at `at`, `radius` across, from `start` (seconds of battle; at once
## by default) for SCORCH_SECONDS, shrinking away at the end, so the field clears.
func scorch(at: Vector3, radius: float, start: float = 0.0) -> void:
	_scorches.add(Vector3(at.x, 0.012, at.z), radius * 2.0, start, SCORCH_SECONDS, Color.WHITE)


## The strip a fallen wall leaves, on the cell centred at `at`, for the rest of the battle.
func wall_rubble(at: Vector3) -> void:
	if _wall_rubble_count == _wall_rubble.instance_count:
		return
	_wall_rubble_buffer.put(_wall_rubble_count, Basis(), at, Color.WHITE, Color(0, 0, 0, 0))
	_wall_rubble_count += 1
	for multimesh: MultiMesh in [_wall_rubble, _wall_rubble_outline]:
		multimesh.buffer = _wall_rubble_buffer.data
		multimesh.visible_instance_count = _wall_rubble_count


## A repair swarm at `at`, `radius` across, from `now` for `seconds`: a dome of `color` fading
## over its life.
func swarm(at: Vector3, radius: float, now: float, seconds: float, color: Color) -> void:
	_domes.add(Vector3(at.x, 0.0, at.z), radius, now, seconds, color)


## An orbital strike aimed at `at`, `radius` across, from `now` until it lands `seconds` later,
## over a target whose top stands `top` high: a pulsing ring of `color` on the ground at least
## `ground` across (wider than the footprint under it), the same crosshair hovering over the top
## facing the camera, and in the last SKY_BOLT_SECONDS a bright column falling from the sky onto
## the point.
func strike_marker(at: Vector3, radius: float, ground: float, top: float, now: float, seconds: float,
		color: Color) -> void:
	_markers.add(Vector3(at.x, 0.03, at.z), maxf(radius, ground), now, seconds, color)
	_hover_markers.add(Vector3(at.x, top + HOVER_OVER, at.z), HOVER_SIZE, now, seconds, color)
	var falls := minf(SKY_BOLT_SECONDS, seconds)
	_sky_bolts.add(Vector3(at.x, 0.0, at.z), SKY_BOLT_WIDTH, now + seconds - falls, falls, color.lerp(Color.WHITE, 0.55))


## A strike landed at `at`, `radius` across, at `now`, on buildings whose top stands `top` high:
## its marker, crosshair and bolt end; a white-hot fireball of `core` pops for `seconds` from half
## that height, so it shows over what it hits, inside a wider ring of `blast` on the ground; pale
## smoke rises and swells from it for SMOKE_SECONDS and fades.
func strike_landed(at: Vector3, radius: float, top: float, now: float, seconds: float, core: Color,
		blast_color: Color) -> void:
	_markers.end_at(at, now)
	_hover_markers.end_at(at, now)
	_sky_bolts.end_at(at, now)
	_fireballs.add(Vector3(at.x, top * 0.5, at.z), radius * FIREBALL_SHARE, now, seconds, core)
	impact(at, radius * 1.6, blast_color, now, seconds)
	impact(at + Vector3.UP * 0.1, radius * 0.9, blast_color.lerp(core, 0.5), now, seconds * 0.7)
	_smoke.add(Vector3(at.x, 0.0, at.z), radius * 0.9, now + seconds * 0.3, SMOKE_SECONDS, Color.WHITE)


## A shield generator `id`'s dome, centred on `at`, `radius` across the ground; MAX_SHIELDS at
## most.
func add_shield(id: int, at: Vector3, radius: float) -> void:
	if _shields.size() == MAX_SHIELDS:
		return
	_shields[id] = _shields.size()
	_shield_at[id] = at
	_shield_radius[id] = radius
	_shield_pool[id] = 0
	_shield_flicker[id] = -1.0
	_shield_drop[id] = -1.0
	_shield_domes.visible_instance_count = _shields.size()


## Shows generator `id`'s dome while its `pool` is up, flickering from `now` when it fell and
## fading out in a ring from `now` when it is gone.
func set_shield(id: int, pool: int, now: float) -> void:
	if not _shields.has(id):
		return
	if pool < _shield_pool[id]:
		_shield_flicker[id] = now
		if pool <= 0:
			_shield_drop[id] = now
			impact(_shield_at[id], _shield_radius[id], MaterialKit.ENERGY, now, SHIELD_DROP_SECONDS)
	elif pool > 0:
		_shield_drop[id] = -1.0
	_shield_pool[id] = pool


# --- Drawing ---------------------------------------------------------------------

## Draws everything at `now`, the battle's clock, and drops what has ended.
func draw(now: float) -> void:
	_draw_flights(_bolts, now)
	_draw_flights(_missiles, now)
	_draw_flights(_bombs, now)
	_draw_flights(_pulses, now)
	_beams.draw(now)
	_draw_vortices(now)
	_debris.draw(now)
	_draw_impacts(now)
	_draw_arcs(now)
	_domes.draw(now, DOME_HEIGHT, 1.0)
	_markers.draw(now, 1.0, 0.0)
	_hover_markers.draw(now, 1.0, 0.0)
	_sky_bolts.draw(now, 1.0, 0.0)
	_fireballs.draw(now, 1.0, 0.0)
	_flashes.draw(now, 1.0, 0.0)
	_rings.draw(now, 1.0, 0.0)
	_sparks.draw(now, 1.0, 0.0)
	_smoke.draw(now, 1.0, 2.0)
	_puffs.draw(now, 1.0, 1.5)
	_glows.draw(now, 1.0, 0.0)
	_stuns.draw(now, 1.0, 0.0)
	_draw_shields(now)
	_scorches.draw(now, 1.0, 0.0)


## Starts a frame's health bars.
func begin_bars() -> void:
	_bar_count = 0


## A health bar `fraction` full in `color` over `at`.
func bar(at: Vector3, fraction: float, color: Color) -> void:
	if _bar_count + 2 > MAX_BARS:
		return
	var back := Basis(_across * (BAR_SIZE.x + 2.0 * BAR_BORDER), _up * (BAR_SIZE.y + 2.0 * BAR_BORDER), Vector3.BACK)
	_bar_buffer.put(_bar_count, back, at, MaterialKit.INK, Color(0, 0, 0, 0))
	var fill := clampf(fraction, 0.0, 1.0)
	var front := Basis(_across * (BAR_SIZE.x * fill), _up * BAR_SIZE.y, Vector3.BACK)
	_bar_buffer.put(_bar_count + 1, front, at - _across * (BAR_SIZE.x * (1.0 - fill) * 0.5), color, Color(0, 0, 0, 0))
	_bar_count += 2


## Ends a frame's health bars and draws them.
func end_bars() -> void:
	_bars.buffer = _bar_buffer.data
	_bars.visible_instance_count = _bar_count


## A basis turning a mesh built along +Z to `forward` (a unit vector), `width` across and `length`
## along, right-handed so its faces keep their winding.
static func along(forward: Vector3, width: float, length: float) -> Basis:
	var side := forward.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.RIGHT
	side = side.normalized()
	var up := forward.cross(side)
	return Basis(side * width, up * width, forward * length)


## Each shield's dome: up, flickering (never hidden) for SHIELD_FLICKER_SECONDS after it absorbs,
## fading out after it drops, gone at no size.
func _draw_shields(now: float) -> void:
	if _shields.is_empty():
		return
	for id: int in _shields:
		var r := _shield_radius[id]
		var fade := 0.0
		var tint := Color.WHITE
		var since := now - _shield_flicker[id]
		if _shield_flicker[id] >= 0.0 and since < SHIELD_FLICKER_SECONDS:
			var beat := int(since * SHIELD_FLICKER_RATE) % 2 == 0
			fade = 0.0 if beat else SHIELD_FLICKER_FADE
			tint = Color.WHITE * (SHIELD_FLICKER_BRIGHT if beat else 1.0)
		if _shield_pool[id] <= 0:
			var gone := (now - _shield_drop[id]) / SHIELD_DROP_SECONDS if _shield_drop[id] >= 0.0 else 1.0
			fade = clampf(gone, 0.0, 1.0)
			r *= 1.0 + SHIELD_DROP_SWELL * fade if gone < 1.0 else 0.0
		_shield_buffer.put(_shields[id], Basis.from_scale(Vector3.ONE * r), _shield_at[id], tint, Color(0, 0, 0, fade))
	_shield_domes.buffer = _shield_buffer.data


func _count_shot(from: Vector3, color: Color) -> void:
	bolts_fired += 1
	last_bolt_from = from
	last_bolt_color = color


## `weapon`'s muzzle flash at `from` at `now`, by its record's shape; none at size 0.
func _muzzle(weapon: Weapons.Weapon, from: Vector3, now: float) -> void:
	if weapon.flash <= 0.0:
		return
	match weapon.flash_shape:
		Weapons.Flash.RING:
			ring_flash(from, weapon.flash, weapon.color.lerp(Color.WHITE, 0.3), now)
			flash(from, weapon.flash * 0.6, weapon.color, now)
		_:
			flash(from, weapon.flash, weapon.color, now)


## An instant weapon from `from` reached `to` at `now`: it lands on the near side of its target (when `impact` is above 0) and its
## target is told.
func _arrive(weapon: Weapons.Weapon, from: Vector3, to: Vector3, impact: float, building: int, unit: int,
		now: float) -> void:
	if impact > 0.0:
		land(weapon, _surface(from, to, stand_off(weapon, impact)), impact, now)
	if arrived.is_valid() and (building != 0 or unit != 0):
		arrived.call(building, unit)


## How far short of the point it was aimed at `weapon`'s impact of `size` lands: SURFACE, or a
## blast's fireball's radius when that is more, so the fireball stands clear of what it hits.
static func stand_off(weapon: Weapons.Weapon, size: float) -> float:
	var r := maxf(size, weapon.impact_size)
	match weapon.impact:
		Weapons.Impact.BLAST_S:
			return maxf(SURFACE, blast_ball(r, 0))
		Weapons.Impact.BLAST_M:
			return maxf(SURFACE, blast_ball(r, 1))
		Weapons.Impact.BLAST_L:
			return maxf(SURFACE, blast_ball(r, 2))
	return SURFACE


## Where a shot from `from` at `to` (a target's middle, a building's near face) lands: `back` short
## of it on the side it came from, and a little up, so its impact shows in front of what it hits
## rather than inside it.
func _surface(from: Vector3, to: Vector3, back: float) -> Vector3:
	var line := to - from
	line.y = 0.0
	if line.length_squared() < 0.0001:
		return to
	return to - line.normalized() * back + Vector3.UP * (SURFACE * 0.3)


## The arc tower's strike from `from` to `to` at `now`: a thick main arc and two branches forking
## off it towards the target.
func _strike(from: Vector3, to: Vector3, now: float) -> void:
	lightning(from, to, now, ARC_MAIN)
	var line := to - from
	var side := line.cross(Vector3.UP)
	side = side.normalized() if side.length_squared() > 0.0001 else Vector3.RIGHT
	for k: int in 2:
		var fork := from + line * (0.35 + 0.25 * k)
		var reach := line.length() * 0.3
		lightning(fork, fork + line.normalized() * reach * 0.6 + side * (reach * (0.6 if k == 0 else -0.6))
			+ Vector3.DOWN * reach * 0.2, now)


## The vortices at `now`: each one's sheath (the low instances) and strands (after), its sheath
## pulsing, its strands turning, faded in over VORTEX_FADE_IN and out over VORTEX_FADE_OUT; while
## it holds (not fading out), its rings from its own clock: a ring tightening round the unit, one
## every VORTEX_RING_SECONDS, and a ring sliding down the beam to the well, one every
## VORTEX_SLIDE_STEP, VORTEX_SLIDE_SECONDS on the way; they stop the moment it fades. Each
## well holding anything glows round its plinth (a pulsing decal every VORTEX_GLOW_STEP) and swirls
## at its mouth (a ring every VORTEX_SWIRL_STEP), once a well.
func _draw_vortices(now: float) -> void:
	var list := _vortices
	if list.count == 0 and list._empty:
		return
	var i := 0
	while i < list.count:
		if now - list.start[i] >= list.seconds[i]:
			list.remove(i)
			continue
		i += 1
	var n := list.count
	for v: int in n:
		var t := now - list.start[v]
		var left := list.seconds[v] - t
		var fade := clampf(t / VORTEX_FADE_IN, 0.0, 1.0) * clampf(left / VORTEX_FADE_OUT, 0.0, 1.0)
		var from := list.from[v]
		var to := list.to[v]
		var line := to - from
		var forward := line.normalized()
		var w := list.width[v]
		var tint := Color(1, 1, 1, fade)
		var sheath := w * (1.0 + VORTEX_SWELL * sin(TAU * VORTEX_PULSE * t))
		list.buffer.put(v, along(forward, sheath, line.length()), from, tint, Color(0, 0, 0, 0))
		list.buffer.put(n + v, Basis(forward, VORTEX_SPIN * t) * along(forward, w, line.length()), from, tint,
			Color(1, 0, 0, 0))
		# Its rings, none once it fades: the tightening ring, then the sliding ones.
		var r := v * VORTEX_RINGS
		var holding := left > VORTEX_FADE_OUT
		var u := fmod(t, VORTEX_RING_SECONDS) / VORTEX_RING_SECONDS
		var across := 2.0 * VORTEX_RING_SIZE * (1.5 - 0.5 * u) if holding else 0.0
		_vortex_ring_buffer.put(r, _rings.facing.scaled(Vector3.ONE * across), to, VORTEX_BAND, Color(0, 0, 0, 0))
		var newest := floorf(t / VORTEX_SLIDE_STEP)
		for k: int in VORTEX_RINGS - 1:
			var slid := (t - (newest - k) * VORTEX_SLIDE_STEP) / VORTEX_SLIDE_SECONDS
			var size := w * VORTEX_SLIDE_SIZE * (1.0 - VORTEX_SLIDE_NARROW * slid)
			if not holding or newest - k < 0.0 or slid >= 1.0:
				size = 0.0
			_vortex_ring_buffer.put(r + 1 + k, along(-forward, size, size), to.lerp(from, minf(slid, 1.0)), VORTEX_DEEP,
				Color(0, 0, 0, 0))
	list.multimesh.buffer = list.buffer.data
	list.multimesh.visible_instance_count = n * 2
	_vortex_rings.buffer = _vortex_ring_buffer.data
	_vortex_rings.visible_instance_count = n * VORTEX_RINGS
	list._empty = n == 0
	for k: int in MAX_WELLS:
		if _wells[k] == 0:
			continue
		if now >= _well_until[k] - VORTEX_FADE_OUT:
			_wells[k] = 0
			continue
		var core := _well_core[k]
		if now >= _well_glow[k]:
			_well_glow[k] = now + VORTEX_GLOW_STEP
			glow(Vector3(core.x, 0.0, core.z), _well_rim[k], VORTEX_GLOW, now, VORTEX_GLOW_STEP * 1.5)
		if now >= _well_swirl[k]:
			_well_swirl[k] = now + VORTEX_SWIRL_STEP
			_rings.add(core, VORTEX_SWIRL_SIZE, now, VORTEX_SWIRL_STEP, VORTEX_BAND)


func _draw_flights(list: Flights, now: float) -> void:
	if list.count == 0 and list._empty:
		return
	var i := 0
	while i < list.count:
		var t := (now - list.start[i]) / list.seconds[i]
		if t >= 1.0:
			var weapon := list.weapon[i]
			var to := list.to[i]
			if list.impact[i] > 0.0:
				land(weapon, _surface(list.from[i], to, stand_off(weapon, list.impact[i])), list.impact[i], now)
			if arrived.is_valid() and (list.building[i] != 0 or list.unit[i] != 0):
				arrived.call(list.building[i], list.unit[i])
			list.remove(i)
			continue
		if t < 0.0:
			list.buffer.put(i, Basis.from_scale(Vector3.ZERO), list.from[i], list.color[i], Color(0, 0, 0, 0))
			i += 1
			continue
		var at := list.point(i, t)
		var heading := list.heading(i, t)
		var forward := heading.normalized() if heading.length_squared() > 0.000001 else Vector3.FORWARD
		var across := list.width[i] * ((0.4 + 1.4 * t) if list.grows else 1.0)
		list.buffer.put(i, along(forward, across, list.length[i] if not list.grows else across), at, list.color[i],
			Color(0, 0, 0, 0))
		var weapon := list.weapon[i]
		if weapon.trail != Weapons.Trail.NONE and now >= list.trail_at[i]:
			list.trail_at[i] = maxf(list.trail_at[i] + TRAIL_STEP, now)
			if weapon.trail == Weapons.Trail.SMOKE:
				puff(at - forward * 0.3 * list.width[i], 0.16, Weapons.SMOKE, now, 0.8, 0.25)
			else:
				puff(at - forward * list.length[i] * 0.4, list.width[i] * 0.45, weapon.color, now, 0.35, 0.05)
		i += 1
	list.multimesh.buffer = list.buffer.data
	list.multimesh.visible_instance_count = list.count
	list._empty = list.count == 0


func _draw_impacts(now: float) -> void:
	var i := 0
	while i < _impact_count:
		var t := (now - _impact_start[i]) / _impact_seconds[i]
		if t >= 1.0:
			_impact_count -= 1
			var last := _impact_count
			_impact_at[i] = _impact_at[last]
			_impact_start[i] = _impact_start[last]
			_impact_radius[i] = _impact_radius[last]
			_impact_color[i] = _impact_color[last]
			_impact_seconds[i] = _impact_seconds[last]
			continue
		var grow := lerpf(IMPACT_START, 1.0, 1.0 - (1.0 - t) * (1.0 - t)) * _impact_radius[i] * 2.0 if t >= 0.0 else 0.0
		var at := _impact_at[i]
		_impact_buffer.put(i, Basis.from_scale(Vector3(grow, grow, grow)), Vector3(at.x, at.y + 0.05, at.z),
			_impact_color[i], Color(0, 0, 0, maxf(t, 0.0) * maxf(t, 0.0)))
		i += 1
	_impacts.buffer = _impact_buffer.data
	_impacts.visible_instance_count = _impact_count


func _draw_arcs(now: float) -> void:
	var i := 0
	while i < _arc_count:
		if now - _arc_start[i] >= ARC_SECONDS:
			_arc_count -= 1
			var last := _arc_count
			_arc_from[i] = _arc_from[last]
			_arc_to[i] = _arc_to[last]
			_arc_start[i] = _arc_start[last]
			_arc_width[i] = _arc_width[last]
			continue
		var from := _arc_from[i]
		var along_arc := _arc_to[i] - from
		var forward := along_arc.normalized()
		var side := forward.cross(Vector3.UP)
		if side.length_squared() < 0.0001:
			side = Vector3.RIGHT
		side = side.normalized()
		var w := _arc_width[i]
		_arc_buffer.put(i, Basis(side * w, side.cross(forward) * w, along_arc), from, ARC_TINT, Color(0, 0, 0, 0))
		i += 1
	_arcs.buffer = _arc_buffer.data
	_arcs.visible_instance_count = _arc_count


## The triangle (a, b, c) of the unlit glow, facing both ways.
static func _both_faces(m: LowPolyMesh, a: Vector3, b: Vector3, c: Vector3) -> void:
	m.triangle(a, b, c, BOLT)
	m.triangle(a, c, b, BOLT)


## A number in [0, 1) from the scatter counter, a different one each call, the same every run.
func _noise(salt: int) -> float:
	_scatter += 1
	var x := sin(float(_scatter * 31 + salt * 977) * 12.9898) * 43758.5453
	return x - floorf(x)


## The glow decal's mesh: a unit-radius disc on the ground, white in the middle fading to nothing
## at its rim by its vertex colours, on an additive unshaded material; the instance colour tints
## and fades it.
static func _glow_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var sides := 24
	for k: int in sides:
		var a := TAU * k / sides
		var b := TAU * (k + 1) / sides
		for corner: Vector3 in [Vector3.ZERO, Vector3(cos(b), 0.0, sin(b)), Vector3(cos(a), 0.0, sin(a))]:
			vertices.append(corner)
			colors.append(Color.WHITE if corner == Vector3.ZERO else Color(0, 0, 0, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


## The vortex's mesh, a unit across and a unit long along +Z, in two parts its UV.x tells apart
## (VORTEX_SHADER draws the one the instance's custom data x names): the sheath (0), a sixteen-sided
## tube of radius 0.5 in VORTEX_HAZE, its normals out, so the shader fades it from the core's edge
## to its rim; and the strands (1): a pale core rod on the axis and a double helix of two strands
## (opposite each other, the same way round) winding VORTEX_TURNS turns round it, each band of a
## strand VORTEX_BANDS of a turn, lilac and violet in turn, two thirds of each band drawn and the
## rest a gap.
static func _vortex_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var sides := 16
	for k: int in sides:
		var a := Vector3(cos(TAU * k / sides), sin(TAU * k / sides), 0.0)
		var b := Vector3(cos(TAU * (k + 1) / sides), sin(TAU * (k + 1) / sides), 0.0)
		for corner: Vector3 in [a, b, b + Vector3.BACK * 2.0, a, b + Vector3.BACK * 2.0, a + Vector3.BACK * 2.0]:
			var ring := Vector3(corner.x, corner.y, 0.0)
			vertices.append(ring * 0.5 + Vector3(0, 0, corner.z * 0.5))
			normals.append(ring)
			colors.append(VORTEX_HAZE)
			uvs.append(Vector2(0, 0))
	var start := vertices.size()
	_vortex_tube(vertices, colors, Vector3(0, 0, 0), Vector3(0, 0, 1), 0.05, VORTEX_CORE)
	var steps_per_band := 4
	var bands := VORTEX_TURNS * VORTEX_BANDS
	for strand: int in 2:
		for band: int in bands:
			var tint := VORTEX_BAND if band % 2 == 0 else VORTEX_DEEP
			var last := Vector3.ZERO
			for k: int in steps_per_band + 1:
				# Two thirds of the band drawn, the rest its gap.
				var t := (band + (2.0 / 3.0) * k / steps_per_band) / bands
				var angle := TAU * VORTEX_TURNS * t + PI * strand
				var at := Vector3(cos(angle) * 0.34, sin(angle) * 0.34, t)
				if k > 0:
					_vortex_tube(vertices, colors, last, at, 0.085, tint)
				last = at
	for k: int in vertices.size() - start:
		normals.append(Vector3.UP)
		uvs.append(Vector2(1, 0))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shader := Shader.new()
	shader.code = VORTEX_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	mesh.surface_set_material(0, material)
	return mesh


## A square tube `radius` across from `a` to `b` in `color` into the arrays, its four faces.
static func _vortex_tube(vertices: PackedVector3Array, colors: PackedColorArray, a: Vector3, b: Vector3,
		radius: float, color: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.UP if absf(axis.y) < 0.9 else Vector3.RIGHT).normalized() * radius
	var up := axis.cross(side).normalized() * radius
	var ring: Array[Vector3] = [side, up, -side, -up]
	for k: int in 4:
		var p := ring[k]
		var q := ring[(k + 1) % 4]
		for corner: Vector3 in [a + p, b + p, b + q, a + p, b + q, a + q]:
			vertices.append(corner)
			colors.append(color)


## The smoke puff's mesh: a flat disc of unit radius, its face up (CLOUD turns it to the camera),
## opaque white in the middle, a little darker towards its edge and gone at its rim by its vertex
## colours, on an unshaded alpha-blended material; the instance colour tints it and its alpha fades
## it. No rim light, no scan bands: a soft comic puff.
static func _cloud_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var sides := 16
	var rings: Array[float] = [0.0, 0.55, 0.85, 1.0]
	var shades: Array[Color] = [Color(1, 1, 1, 1), Color(0.93, 0.93, 0.93, 1), Color(0.86, 0.86, 0.86, 0.7),
		Color(0.8, 0.8, 0.8, 0)]
	for k: int in sides:
		var a := TAU * k / sides
		var b := TAU * (k + 1) / sides
		for ring: int in range(1, rings.size()):
			var inner := rings[ring - 1]
			var outer := rings[ring]
			var a_in := Vector3(cos(a), 0.0, sin(a)) * inner
			var b_in := Vector3(cos(b), 0.0, sin(b)) * inner
			var a_out := Vector3(cos(a), 0.0, sin(a)) * outer
			var b_out := Vector3(cos(b), 0.0, sin(b)) * outer
			for corner: Array in [[a_in, ring - 1], [b_out, ring], [a_out, ring], [a_in, ring - 1], [b_in, ring - 1],
					[b_out, ring]]:
				vertices.append(corner[0])
				colors.append(shades[int(corner[1])])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	return mesh


## A MultiMesh of `mesh` for up to `count` instances with colours and custom data, none shown, its
## bounds the field's `area`, in an instance under this node casting a shadow when `shadow`.
func _multimesh(mesh: Mesh, count: int, area: AABB, shadow: bool) -> MultiMesh:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.use_custom_data = true
	multimesh.mesh = mesh
	multimesh.instance_count = count
	multimesh.visible_instance_count = 0
	multimesh.custom_aabb = area
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multimesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow \
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return multimesh
