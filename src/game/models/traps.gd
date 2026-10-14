extends RefCounted
## Models of the traps, in the comic style (docs/reference/art-style.md): low, squat devices on
## concrete pads, gunmetal casings banded in hazard stripes, one warning glow each, gold trim
## at the top level, each well inside its footprint and its budget.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. Each builds
## its level as a run of additions, so the levels of a type read as one trap growing.

## Hazard stripes at three times the kit's scale, so a narrow band still shows several.
static var HAZARD_FINE := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0, Surf.LIT, true)
static var CASING := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 2.0, Surf.LIT, true)
static var CASING_MID := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var RED := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT, true)
static var VIOLET := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, true)
## The vortex's swirl: thin violet strips, too thin for an outline.
static var SWIRL := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, true, false)
## The dark throat of the gravity trap's vortex.
static var VOID := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.INK, 1.0, Surf.LIT, true)
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)


## A low domed disc on a hazard rim, spikes round its crown and a red warning light. More
## spikes at 2, a second light at 3.
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
	m.dome(0.07, 0.07, 16, 3, base + Vector3(0, 0.162, 0), RED)
	if level >= 3:
		m.ring(0.07, 0.1, 0.03, 16, base + Vector3(0, 0.152, 0), GOLD_ROUND)
		m.dome(0.04, 0.04, 16, 3, Parts.around(0.31, 45, 0.07) + base, RED)


## A ring emitter round a dark funnel with a violet vortex at its bottom, coils on its rim. A
## second ring, in gold, hovering over it at 2.
static func build_grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	m.lathe(PackedVector2Array([
		Vector2(0.32, 0), Vector2(0.34, 0.05), Vector2(0.32, 0.11), Vector2(0.26, 0.135), Vector2(0.2, 0.12),
	]), 16, base, CASING_MID)
	m.lathe(PackedVector2Array([Vector2(0.2, 0.12), Vector2(0.1, 0.055)]), 16, base, VOID)
	m.lathe(PackedVector2Array([Vector2(0.1, 0.055), Vector2(0.04, 0.03), Vector2(0, 0.03)]), 16, base,
		VIOLET)
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
		m.ring(0.13, 0.15, 0.03, 16, hover + Vector3(0, 0.01, 0), VIOLET)


static func build_flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.14, 0.12, 0.15, 4, Vector3.ZERO, Parts.surf("hull_dark"))
	m.orb(0.27, 5, 3, Vector3(0, 0.38, 0), Parts.surf("hull"))
	var dot := "glow_gold" if level >= 3 else "glow_orange"
	for i: int in mini(level, 2):
		m.pyramid(0.14, 0.08, Parts.around(0.14 * i, 0, 0.58), Parts.surf(dot))


static func build_mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	m.prism(0.8, 0.75, 0.12, 6, Vector3.ZERO, Parts.surf("metal_dark"))
	for offset: float in [-0.3, 0.0, 0.3]:
		Parts.plate(m, Vector2(0.12, 0.7), Vector3(offset, 0.121, 0), "hazard", 30)
	for i: int in 3:
		m.pyramid(0.1, 0.05, Parts.around(0.55, 90 + 120 * i, 0.12), Parts.surf("glow_gold" if level >= 2 else "glow_red"))
