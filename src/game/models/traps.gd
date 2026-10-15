extends RefCounted
## Models of the traps, in the comic style (docs/reference/art-style.md): low, squat devices on
## concrete pads, gunmetal casings banded in hazard stripes, one warning glow each, gold trim
## at the top level, each well inside its footprint and its budget. Each is animated by its
## surfaces alone (docs/reference/art-style.md, **Animation**): warning lights BLINK, glows PULSE,
## the gravity trap's vortex streams inward.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. Each builds
## its level as a run of additions, so the levels of a type read as one trap growing.

## Hazard stripes at three times the kit's scale, so a narrow band still shows several.
static var HAZARD_FINE := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0, Surf.LIT, true)
static var CASING := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 2.0, Surf.LIT, true)
static var CASING_MID := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var RED := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT, true)
## Warning lights, blinking; phased per lamp so a ring of them chases.
static var RED_BLINK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var RED_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var VIOLET := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, true)
static var VIOLET_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The glow layer's stripes run along U, so a vortex's glow streams along V (FLOW), its stripes
## drawn larger (0.4) so they show on so small a part: at 0.3, about two units a second inward (V
## grows outward on the throat and along each swirl strip, from its inner end to its outer one).
static var VIOLET_INFLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 0.4,
	Surf.UNLIT | Surf.FLOW, true, true, 0.3)
## The vortex's swirl: thin violet strips, too thin for an outline, streaming inward.
static var SWIRL := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 0.4, Surf.UNLIT | Surf.FLOW,
	true, false, 0.3)
static var YELLOW_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The flak mine's sensor lens, flashing.
static var LENS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0, Surf.GLOSSY | Surf.BLINK, true)
## The mega mine's seams: a dim red glow, too thin for an outline, swelling faintly.
static var SEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE.darkened(0.45), 1.0,
	Surf.UNLIT | Surf.PULSE, true, false)
## The dark throat of the gravity trap's vortex.
static var VOID := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.INK, 1.0, Surf.LIT, true)
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)


## A low domed disc on a hazard rim, spikes round its crown and a red warning light. More
## spikes at 2, a second light at 3. The lights blink in turn.
static func build_proximity_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	m.ring(0.27, 0.33, 0.07, 16, base, HAZARD_FINE)
	m.lathe(PackedVector2Array([
		Vector2(0.29, 0), Vector2(0.29, 0.09), Vector2(0.24, 0.14), Vector2(0.1, 0.17), Vector2(0, 0.175),
	]), 16, base, CASING)
	var spikes: Array[int] = [3, 5, 6]
	var count := spikes[level - 1]
	for i: int in count:
		var degrees := 90.0 + 360.0 * i / count
		var out := Parts.around(1.0, degrees, 0.0)
		m.cone(0.035, 0.13, 8, Parts.around(0.18, degrees, 0.0) + base + Vector3(0, 0.14, 0),
			CASING_MID, Parts.facing(out * 0.4 + Vector3.UP))
	m.dome(0.07, 0.07, 16, 3, base + Vector3(0, 0.162, 0), RED_BLINK)
	if level >= 3:
		m.ring(0.07, 0.1, 0.03, 16, base + Vector3(0, 0.152, 0), GOLD_ROUND)
		m.dome(0.04, 0.04, 16, 3, Parts.around(0.31, 45, 0.07) + base, RED_BLINK.phased(0.5))


## A ring emitter round a dark funnel with a violet vortex at its bottom, coils on its rim. A
## second ring, in gold, hovering over it at 2. The emitter's lip and the hovering ring pulse; the
## vortex's glow streams inward down the funnel.
static func build_grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	m.lathe(PackedVector2Array([
		Vector2(0.32, 0), Vector2(0.34, 0.05), Vector2(0.32, 0.11), Vector2(0.26, 0.135),
	]), 16, base, CASING_MID)
	m.lathe(PackedVector2Array([Vector2(0.26, 0.135), Vector2(0.2, 0.12)]), 16, base, VIOLET_PULSE)
	m.lathe(PackedVector2Array([Vector2(0.2, 0.12), Vector2(0.1, 0.055)]), 16, base, VOID)
	m.lathe(PackedVector2Array([Vector2(0.1, 0.055), Vector2(0.04, 0.03), Vector2(0, 0.03)]), 16, base,
		VIOLET_INFLOW)
	for i: int in 3:
		var degrees := 120.0 * i
		m.strut(Parts.around(0.19, degrees, 0.118) + base, Parts.around(0.1, degrees + 70.0, 0.058) + base,
			0.025, SWIRL)
	for i: int in 3:
		var degrees := 30.0 + 120.0 * i
		m.box_chamfered(Vector3(0.1, 0.1, 0.12), 0.02, Parts.around(0.3, degrees, 0.08) + base,
			HAZARD_FINE, Vector3(0, 90 - degrees, 0))
	if level >= 2:
		var hover := base + Vector3(0, 0.3, 0)
		for i: int in 3:
			var degrees := 90.0 + 120.0 * i
			m.strut(Parts.around(0.24, degrees, 0.12) + base, Parts.around(0.2, degrees, 0.0) + hover, 0.03,
				Parts.ROD)
		m.ring(0.15, 0.23, 0.05, 16, hover, GOLD_ROUND)
		m.ring(0.13, 0.15, 0.03, 16, hover + Vector3(0, 0.01, 0), VIOLET_PULSE.phased(0.5))


## A squat pod banded in hazard stripes with upward barrels round a sensor lens, their bores
## glowing. A barrel more at each level. The bores pulse in turn and the lens flashes.
static func build_flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	Parts.tank(m, 0.26, 0.2, base, CASING, 0.05)
	m.ring(0.26, 0.275, 0.07, 16, base + Vector3(0, 0.05, 0), HAZARD_FINE)
	var top := base + Vector3(0, 0.2, 0)
	var barrels := level + 1
	for i: int in barrels:
		var spot := Parts.around(0.15, 135.0 + 360.0 * i / barrels, 0.0) + top
		m.prism(0.05, 0.05, 0.16, 12, spot, CASING_MID)
		m.disc(0.032, 12, spot + Vector3(0, 0.161, 0), YELLOW_PULSE.phased(float(i) / barrels))
	m.dome(0.075, 0.07, 16, 3, top, LENS)
	if level >= 3:
		m.ring(0.075, 0.1, 0.025, 16, top, GOLD_ROUND)


## A big armoured dome on a hazard band, warning lights round its foot and a fuse cap on its
## crown. A thicker dome and more lights at 2. The lights chase round the band, glowing seams run
## up the dome between them, swelling faintly, and the fuse light pulses.
static func build_mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 2)
	m.ring(0.6, 0.72, 0.12, 24, base, HAZARD_FINE)
	var radius := 0.62 if level < 2 else 0.68
	var height := 0.42 if level < 2 else 0.54
	m.dome(radius, height, 24, 6, base + Vector3(0, 0.06, 0), CASING)
	if level >= 2:
		m.ring(radius - 0.02, radius + 0.04, 0.05, 24, base + Vector3(0, 0.1, 0), GOLD_ROUND)
	var lights := 4 if level < 2 else 6
	for i: int in lights:
		var degrees := 45.0 + 360.0 * i / lights
		m.dome(0.06, 0.06, 16, 3, Parts.around(0.67, degrees, 0.12) + base, RED_BLINK.phased(float(i) / lights))
		Parts.dome_seam(m, radius, height, base + Vector3(0, 0.06, 0), degrees + 180.0 / lights,
			SEAM.phased(float(i) / lights))
	var crown := base + Vector3(0, 0.06 + height - 0.02, 0)
	m.prism(0.13, 0.11, 0.08, 16, crown, CASING_MID)
	m.dome(0.07, 0.07, 16, 3, crown + Vector3(0, 0.08, 0), RED_PULSE)
	for i: int in 3:
		var degrees := 90.0 + 120.0 * i
		var foot := Parts.around(0.1, degrees, 0.06) + crown
		m.cone(0.025, 0.14, 8, foot, CASING_MID, Parts.facing(Parts.around(0.5, degrees, 1.0)))
