extends RefCounted
## The builder drone that works on a building site (ConstructionDrone), and its laser: the drone
## bay's parked drone (resources.gd, _drone) with a builder's marks, a hazard band round each
## duct and a tool arm under its nose ending in a glowing emitter lens. It is built round its
## own centre with its front along +Z, so the drone can turn and tilt about that point.
##
## BuildingModels builds and caches each of the three (create_drone, create_drone_effect). The
## beam, the flare's dome, its sparks and the rotor blur each have a surface of their own, and
## each is animated by the shaders (docs/reference/art-style.md, **Animation**): the beam flows
## from the emitter to the hit point and pulses, the dome pulses, the sparks flicker and shake,
## each on its own phase, and the rotors are hologram discs whose hazard stripes spin.

## The eye and the emitter lens.
static var GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var DUCT_BAND := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0, Surf.LIT, true)
## The rotors' blur: hologram discs of pale glass, untinted, whose diagonal streak sweeps round
## the disc as a blur arc as U scrolls; ROTOR_SPEEDS gives each its phase, the pairs
## counter-rotating.
static var ROTOR := Surf.make(MaterialKit.Layer.GLASS, Color.WHITE, 1.0, Surf.HOLO | Surf.FLOW_U)
## The laser and its flare: unlit and too thin or small for the outline. The beam is on the bands
## layer, a broad bright band ink-edged on its leading side, at 2 repeats a unit; its V falls from
## the emitter to the hit point (a face's V is minus its height), so its flow phase is below 0.5
## to carry the bands towards the hit point as pulses. The sparks take phases k/5.
static var BEAM := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.ENERGY, 2.0,
	Surf.UNLIT | Surf.FLOW | Surf.PULSE, true, false, 0.15)
static var FLARE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true, false)
static var SPARK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0,
	Surf.UNLIT | Surf.FLICKER | Surf.JITTER, false, false)

## The bottom of the saucer, below the drone's centre.
const BASE := Vector3(0, -0.07, 0)
## The tool arm: its knuckle under the body's front, its end, and the emitter lens's centre,
## where the beam starts.
const KNUCKLE := Vector3(0, -0.05, 0.12)
const ARM_END := Vector3(0, -0.12, 0.22)
const EMITTER := Vector3(0, -0.15, 0.265)
const BEAM_WIDTH := 0.05
const FLARE_RADIUS := 0.14
## Each spark's length beyond the flare's edge, round it in turn: their tips about 0.25 out.
const SPARKS := [0.14, 0.08, 0.12, 0.09, 0.11]
const SPARK_WIDTH := 0.04
## Each rotor's FLOW_U phase, round the drone in turn: its spin's speed and direction.
const ROTOR_SPEEDS := [0.92, 0.08, 0.96, 0.04]


## A saucer body with a glass canopy and a glowing eye at its front, four ducted rotors on arms
## at the diagonals, each duct banded in hazard stripes round a blur disc, and the tool arm.
static func build_drone(p: Parts) -> void:
	var m := p.body
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.1, 0), Vector2(0.2, 0.05), Vector2(0.21, 0.09), Vector2(0.15, 0.14),
		Vector2(0, 0.15),
	]), 12, BASE, Parts.HULL_LIGHT_ROUND)
	m.dome(0.09, 0.08, 10, 3, BASE + Vector3(0, 0.13, 0), Parts.GLASS)
	m.box_chamfered(Vector3(0.12, 0.05, 0.05), 0.015, BASE + Vector3(0, 0.05, 0.19), GLOW)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		var hub := BASE + Parts.around(0.3, degrees, 0.06)
		m.strut(BASE + Parts.around(0.15, degrees, 0.07), hub, 0.05, Parts.ROD)
		m.lathe(PackedVector2Array([Vector2(0.115, 0), Vector2(0.115, 0.06), Vector2(0.08, 0.06)]), 10,
			hub - Vector3(0, 0.02, 0), Parts.HULL_MID_ROUND)
		m.ring(0.112, 0.127, 0.032, 12, hub - Vector3(0, 0.006, 0), DUCT_BAND)
		m.disc(0.085, 10, hub + Vector3(0, 0.02, 0), ROTOR.phased(ROTOR_SPEEDS[k]))
	m.orb(0.035, 8, 4, KNUCKLE, Parts.GUNMETAL)
	Parts.pipe(m, KNUCKLE, ARM_END, 0.025, Parts.GUNMETAL, 8, false)
	Parts.pipe(m, ARM_END, EMITTER, 0.04, Parts.GUNMETAL, 10, false)
	m.orb(0.03, 8, 4, EMITTER, GLOW)


## The laser: a thin square rod one unit long up +Y from the origin, stretched to its length by
## the node it hangs under. A box, not a prism: its planar UVs keep the texture as dense across
## the rod as along it, where a lathe's whole repeat round so thin a rod would mip the bands away.
static func build_beam(p: Parts) -> void:
	p.body.box(Vector3(BEAM_WIDTH, 1.0, BEAM_WIDTH), Vector3.ZERO, BEAM)


## Where the laser hits: a small glowing dome with hazard-yellow spark shards fanned round it,
## each one a thin triangle seen from both sides, rising a little from its root.
static func build_flare(p: Parts) -> void:
	var m := p.body
	m.dome(FLARE_RADIUS, FLARE_RADIUS * 0.8, 10, 3, Vector3.ZERO, FLARE)
	for k: int in SPARKS.size():
		var length: float = SPARKS[k]
		var degrees := 20.0 + 72.0 * k
		var root := Parts.around(FLARE_RADIUS * 0.7, degrees, 0.02)
		var tip := Parts.around(FLARE_RADIUS + length, degrees, 0.02 + length * 0.7)
		var side := Parts.around(SPARK_WIDTH * 0.5, degrees + 90.0, 0)
		var spark := SPARK.phased(k / float(SPARKS.size()))
		m.triangle(root - side, root + side, tip, spark)
		m.triangle(root + side, root - side, tip, spark)
