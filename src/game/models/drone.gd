extends RefCounted
## The builder drone that works on a building site (ConstructionDrone), and its laser. The drone
## is a saucer with a hazard band round each rotor's duct and a tool arm under its nose ending in
## a glowing emitter lens. It is built round its own centre with its front along +Z, so the drone
## can turn and tilt about that point. The drone bay parks the same drone on its deck (add_drone,
## parked): turned so its rotors stand on the axes, every part bobbing together, its rotors the
## bay's unlit blurs.
##
## BuildingModels builds and caches each of the three (create_drone, create_drone_effect). The
## beam's core and sheath, the flare's dome, its sparks and the rotor blur each have a surface of
## their own, and each is animated by the shaders (docs/reference/art-style.md, **Animation**):
## the beam's core pulses and its sheath's bands flow from the emitter to the hit point, the dome
## pulses, the sparks flicker and shake, each on its own phase, and the rotors are hologram discs
## whose hazard stripes spin.

## The eye and the emitter lens.
static var GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var DUCT_BAND := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0, Surf.LIT, true)
## The rotors' blur: hologram discs of pale glass, untinted, whose diagonal streak sweeps round
## the disc as a blur arc as U scrolls; ROTOR_SPEEDS gives each its phase, the pairs
## counter-rotating.
static var ROTOR := Surf.make(MaterialKit.Layer.GLASS, Color.WHITE, 1.0, Surf.HOLO | Surf.FLOW_U)
## The laser and its flare: unlit and not outlined. The beam is a white-hot core, BEAM_CORE (a
## near-white cyan, pulsing), in a soft glow sheath, BEAM_SHEATH: a hologram on the bands layer,
## a broad bright band ink-edged on its leading side, at 2 repeats a unit; its V falls from the
## emitter to the hit point (a face's V is minus its height), so its flow phase is below 0.5 to
## carry the bands towards the hit point as pulses. The flare's dome is a bright cyan; its sparks
## are hazard yellow and white-hot by turns, on phases k / SPARKS.size().
const WHITE_HOT := Color("d8fbff")
static var BEAM_CORE := Surf.make(MaterialKit.Layer.GLOW, WHITE_HOT, 1.0, Surf.UNLIT | Surf.PULSE, true, false)
static var BEAM_SHEATH := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.ENERGY, 2.0,
	Surf.HOLO | Surf.FLOW, true, false, 0.15)
static var FLARE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY.lerp(Color.WHITE, 0.3), 1.0, Surf.UNLIT | Surf.PULSE, true,
	false)
static var SPARK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0,
	Surf.UNLIT | Surf.FLICKER | Surf.JITTER, false, false)
static var SPARK_HOT := Surf.make(MaterialKit.Layer.GLOW, WHITE_HOT, 1.0,
	Surf.UNLIT | Surf.FLICKER | Surf.JITTER, false, false)

## The parked drone idles: every part of it bobs together, on PARKED_PHASE, which is also the
## speed its rotor blurs turn at (FLOW_U). The blurs are on the screen layer, whose lit segments
## run round a disc, and unlit, not holograms, so the bay has no transparent surface.
const PARKED_PHASE := 0.9
const PARKED_YAW := 45.0
static var PARKED_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.BOB, true, true, PARKED_PHASE)
static var PARKED_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0, Surf.GLOSSY | Surf.BOB, true, true,
	PARKED_PHASE)
static var PARKED_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BOB, true, true, PARKED_PHASE)
static var PARKED_ROD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true, false, PARKED_PHASE)
## The parked drone's ducts are army orange, the bay's accent, so it reads on the deck.
static var PARKED_DUCT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.BOB, true, true, PARKED_PHASE)
static var PARKED_BAND := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0, Surf.BOB, true, true, PARKED_PHASE)
static var PARKED_GUNMETAL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true, true, PARKED_PHASE)
static var PARKED_ROTOR := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ENERGY, 4.0, Surf.UNLIT | Surf.FLOW_U | Surf.BOB, false,
	true, PARKED_PHASE)

## The bottom of the saucer, below the drone's centre.
const BASE := Vector3(0, -0.07, 0)
## The tool arm: its knuckle under the body's front, its end, and the emitter lens's centre,
## where the beam starts.
const KNUCKLE := Vector3(0, -0.05, 0.12)
const ARM_END := Vector3(0, -0.12, 0.22)
const EMITTER := Vector3(0, -0.15, 0.265)
## The beam's core and its sheath, across.
const BEAM_WIDTH := 0.07
const SHEATH_WIDTH := 0.2
const FLARE_RADIUS := 0.17
## Each spark's length beyond the flare's edge, round it in turn: their tips 0.3 to 0.45 out, so
## the burst reads at camera size 10.
const SPARKS := [0.3, 0.18, 0.26, 0.2, 0.31, 0.16, 0.24, 0.21]
const SPARK_WIDTH := 0.09
## How steeply the sparks rise off the face, their tips' height a share of their length: the
## yellow ones low, the white-hot ones steep, so the burst stands out of the face.
const SPARK_RISE := [0.7, 1.4]
## Each rotor's FLOW_U phase, round the drone in turn: its spin's speed and direction.
const ROTOR_SPEEDS := [0.92, 0.08, 0.96, 0.04]


## The construction drone, round its own centre. It banks and pitches in flight, and its laser
## and flare turn to the face they hit, so none of the three is upright (Parts.upright).
static func build_drone(p: Parts) -> void:
	p.upright = false
	add_drone(p.body, Vector3.ZERO, false)


## A saucer body with a glass canopy and a glowing eye at its front, four ducted rotors on arms
## at the diagonals, each duct banded in hazard stripes round a blur disc, and the tool arm, with
## its centre at `pos`. `parked`: the drone bay's, turned PARKED_YAW and idling (above).
static func add_drone(m: LowPolyMesh, pos: Vector3, parked: bool) -> void:
	var turn := Vector3(0, PARKED_YAW if parked else 0.0, 0)
	var hull := PARKED_HULL if parked else Parts.HULL_LIGHT_ROUND
	var glow := PARKED_GLOW if parked else GLOW
	var gunmetal := PARKED_GUNMETAL if parked else Parts.GUNMETAL
	var base := pos + BASE
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.1, 0), Vector2(0.2, 0.05), Vector2(0.21, 0.09), Vector2(0.15, 0.14),
		Vector2(0, 0.15),
	]), 12, base, hull)
	m.dome(0.09, 0.08, 10, 3, base + Vector3(0, 0.13, 0), PARKED_GLASS if parked else Parts.GLASS)
	m.box_chamfered(Vector3(0.12, 0.05, 0.05), 0.015, base + LowPolyMesh.turn(Vector3(0, 0.05, 0.19), turn), glow, turn)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k - turn.y
		var hub := base + Parts.around(0.3, degrees, 0.06)
		m.strut(base + Parts.around(0.15, degrees, 0.07), hub, 0.05, PARKED_ROD if parked else Parts.ROD)
		m.lathe(PackedVector2Array([Vector2(0.115, 0), Vector2(0.115, 0.06), Vector2(0.08, 0.06)]), 10,
			hub - Vector3(0, 0.02, 0), PARKED_DUCT if parked else Parts.HULL_MID_ROUND)
		m.ring(0.112, 0.127, 0.032, 12, hub - Vector3(0, 0.006, 0), PARKED_BAND if parked else DUCT_BAND)
		m.disc(0.085, 10, hub + Vector3(0, 0.02, 0), PARKED_ROTOR if parked else ROTOR.phased(ROTOR_SPEEDS[k]))
	var knuckle := pos + LowPolyMesh.turn(KNUCKLE, turn)
	var arm_end := pos + LowPolyMesh.turn(ARM_END, turn)
	var emitter := pos + LowPolyMesh.turn(EMITTER, turn)
	m.orb(0.035, 8, 4, knuckle, gunmetal)
	Parts.pipe(m, knuckle, arm_end, 0.025, gunmetal, 8, false)
	Parts.pipe(m, arm_end, emitter, 0.04, gunmetal, 10, false)
	m.orb(0.03, 8, 4, emitter, glow)


## The laser: a white-hot square rod one unit long up +Y from the origin, in a wider hologram
## sheath whose bands flow down it, stretched to its length by the node it hangs under. Boxes, not
## prisms: their planar UVs keep the texture as dense across the rod as along it, where a lathe's
## whole repeat round so thin a rod would mip the bands away.
static func build_beam(p: Parts) -> void:
	p.upright = false
	p.body.box(Vector3(BEAM_WIDTH, 1.0, BEAM_WIDTH), Vector3.ZERO, BEAM_CORE)
	p.body.box(Vector3(SHEATH_WIDTH, 1.0, SHEATH_WIDTH), Vector3.ZERO, BEAM_SHEATH)


## Where the laser hits: a small bright dome with spark shards fanned round it, hazard yellow and
## white-hot by turns, each one a thin triangle seen from both sides, rising from its root.
static func build_flare(p: Parts) -> void:
	p.upright = false
	var m := p.body
	m.dome(FLARE_RADIUS, FLARE_RADIUS * 0.8, 10, 3, Vector3.ZERO, FLARE)
	for k: int in SPARKS.size():
		var length: float = SPARKS[k]
		var degrees := 20.0 + 360.0 / SPARKS.size() * k
		var root := Parts.around(FLARE_RADIUS * 0.7, degrees, 0.02)
		var rise: float = SPARK_RISE[k % 2]
		var tip := Parts.around(FLARE_RADIUS + length, degrees, 0.02 + length * rise)
		var side := Parts.around(SPARK_WIDTH * 0.5, degrees + 90.0, 0)
		var spark := (SPARK if k % 2 == 0 else SPARK_HOT).phased(k / float(SPARKS.size()))
		m.triangle(root - side, root + side, tip, spark)
		m.triangle(root + side, root - side, tip, spark)
