class_name Motion
extends RefCounted
## How a moving part of a model moves about its pivot (Parts.moving,
## docs/reference/art-style.md, **Animation**): it spins, swings or slides, eased. A Motion is
## built with spin(), swing() or slide(), shared by every view of the model, and never changed;
## BuildingView asks it for the part's transform at clock() each frame.
##
## clock() is the game's one animation clock: seconds from a monotonic clock, wrapping every
## WRAP_SECONDS as the shaders' time did, so a period that divides it never jumps. main.gd sets it
## once a frame (tick) and hands the same value to the shaders as the anim_time global, so a
## moving part and its surface effects keep step.
##
## SWING and SLIDE move between -amplitude and +amplitude on a wave s(u) of the cycle's share u,
## from -1 to 1. At s = -1 the part is at its rest turned or moved by -amplitude: a HAMMER rests
## (and strikes) there and is lifted at +amplitude, a RECOIL kicks out to +amplitude and eases
## back to rest at -amplitude.

enum Kind { SPIN, SWING, SLIDE }
## LINEAR: a triangle wave. SMOOTH: a sine. HAMMER: a slow rise over 70 % of the cycle, a fast
## fall over 10 %, a hold at rest for 20 %: press arms, pile drivers. RECOIL: its mirror, a fast
## rise over 10 %, a slow fall over 70 %, a hold for 20 %: a gun barrel's kick.
enum Ease { LINEAR, SMOOTH, HAMMER, RECOIL }

var kind: Kind = Kind.SPIN
var easing: Ease = Ease.SMOOTH
## Unit length.
var axis := Vector3.UP
## SPIN: radians a second.
var rate := 0.0
## SWING: degrees; SLIDE: world units.
var amplitude := 0.0
## SWING and SLIDE: seconds a cycle.
var period := 1.0
## SWING and SLIDE: 0 to 1, where in its cycle the part is at time 0.
var phase := 0.0

const WRAP_SECONDS := 3600
static var _clock: float = 0.0


## The animation clock now, in seconds, as of this frame's tick().
static func clock() -> float:
	return _clock


## Reads the monotonic clock into clock() and returns it; main.gd calls it once a frame, before
## the views animate.
static func tick() -> float:
	_clock = (Time.get_ticks_usec() % (WRAP_SECONDS * 1000000)) / 1000000.0
	return _clock


## Continuous rotation about `axis` through the pivot at `rate` radians a second.
static func spin(new_axis: Vector3, new_rate: float) -> Motion:
	var motion := Motion.new()
	motion.kind = Kind.SPIN
	motion.axis = new_axis.normalized()
	motion.rate = new_rate
	return motion


## Rotation about `axis` through the pivot, between -amplitude and +amplitude degrees.
static func swing(new_axis: Vector3, new_amplitude: float, new_period: float, new_phase: float = 0.0,
		new_ease: Ease = Ease.SMOOTH) -> Motion:
	return _wave(Kind.SWING, new_axis, new_amplitude, new_period, new_phase, new_ease)


## Translation along `axis`, between -amplitude and +amplitude units from the pivot.
static func slide(new_axis: Vector3, new_amplitude: float, new_period: float, new_phase: float = 0.0,
		new_ease: Ease = Ease.SMOOTH) -> Motion:
	return _wave(Kind.SLIDE, new_axis, new_amplitude, new_period, new_phase, new_ease)


## The part's transform at `time` seconds, its node resting at `rest` (the pivot). Allocates
## nothing.
func transform_at(time: float, rest: Vector3) -> Transform3D:
	match kind:
		Kind.SPIN, Kind.SWING:
			return Transform3D(Basis(axis, angle_at(time)), rest)
		_:
			return Transform3D(Basis.IDENTITY, rest + axis * amplitude * wave(time))


## SPIN and SWING: the part's angle about `axis` at `time`, in radians; 0 for a slide.
func angle_at(time: float) -> float:
	match kind:
		Kind.SPIN:
			return fmod(rate * time, TAU)
		Kind.SWING:
			return deg_to_rad(amplitude) * wave(time)
	return 0.0


## SWING and SLIDE: where in its swing the part is at `time`, from -1 to 1.
func wave(time: float) -> float:
	var u := fposmod(time / period + phase, 1.0)
	match easing:
		Ease.LINEAR:
			return 1.0 - 4.0 * absf(u - 0.5)
		Ease.SMOOTH:
			return sin(TAU * u)
		Ease.HAMMER:
			if u < 0.7:
				return -1.0 + 2.0 * smoothstep(0.0, 0.7, u)
			if u < 0.8:
				var fall := (u - 0.7) / 0.1
				return 1.0 - 2.0 * fall * fall
			return -1.0
		_:
			return recoil(u)


## The RECOIL wave at the cycle's share `u` (0 to 1), from -1 to 1: a fast rise over 10 %, a slow
## fall over 70 %, a hold at -1 for 20 %. BuildingView.fired() kicks an aiming part on it once.
static func recoil(u: float) -> float:
	if u < 0.1:
		var kick := u / 0.1
		return -1.0 + 2.0 * (1.0 - (1.0 - kick) * (1.0 - kick))
	if u < 0.8:
		return 1.0 - 2.0 * smoothstep(0.1, 0.8, u)
	return -1.0


static func _wave(new_kind: Kind, new_axis: Vector3, new_amplitude: float, new_period: float,
		new_phase: float, new_ease: Ease) -> Motion:
	var motion := Motion.new()
	motion.kind = new_kind
	motion.axis = new_axis.normalized()
	motion.amplitude = new_amplitude
	motion.period = new_period
	motion.phase = new_phase
	motion.easing = new_ease
	return motion
