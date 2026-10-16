extends RefCounted
## Models of the traps, in the comic style (docs/reference/art-style.md): low, squat devices on
## concrete pads, gunmetal casings banded in hazard stripes, one warning glow each, gold trim
## from the Gold tier (Parts.tier), each well inside its footprint and its budget, and low (a 1x1
## trap under 1.0 unit, the Mega Mine under 1.6), as traps read as ground hazards. From the
## Chrome tier (Parts.Tier) each is grown: chrome with cyan light, then obsidian with glowing
## violet vein panels on the faces the camera sees, glowing crystals and a hovering ring, then
## gold filigree and a violet core lens under a small gold crown; traps have no escort. Most are
## animated by their surfaces alone (docs/reference/art-style.md, **Animation**): warning lights
## BLINK in a chase, glows PULSE, the vortex streams inward, hovering rings BOB; from the Obsidian
## tier the Gravity Trap's and the Mega Mine's hovering rings turn (their one moving part).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. Each builds
## its level as a run of additions, so the levels of a type read as one trap growing; the levels
## from the Chrome tier on are built by a _grown_<type> of their own, the trap's parts made bigger.

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

## The high tiers' own (docs/reference/art-style.md, **Tiers**). Chase lamps blinking in each
## tier's light: cyan, violet, gold. The Obsidian tier's glowing violet vein panels on the faces
## the camera sees (the siphon's: the glow layer's stripes drawn a third as fine and lifted up the
## panel by FLOW), too thin a shell to ink; its crystals glowing; and its hovering element, a
## violet ring bobbing round the trap. The Crown tier's core lens: a light violet, brighter than
## CORE_GLOW (the other files' bright core, here pulsing).
static var CYAN_BLINK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var VIOLET_BLINK := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var GOLD_BLINK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var VEIN_PANEL := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0 / 3.0, Surf.UNLIT | Surf.FLOW, false,
	false, 0.45)
static var CRYSTAL_GLOW := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
static var HOVER_GLOW := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, 0.7)
const CORE_LIGHT := Color("c9a2ff")
static var BRIGHT_CORE := Surf.make(MaterialKit.Layer.GLOW, CORE_LIGHT, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The Chrome tier's vortex, cyan, streaming inward as the violet one does; the Obsidian tier's
## hovering crystal ring and its Crown tier's gold one, bobbing with the violet ring's phase.
static var CYAN_INFLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 0.4, Surf.UNLIT | Surf.FLOW, true, true, 0.3)
static var CYAN_SWIRL := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 0.4, Surf.UNLIT | Surf.FLOW, true, false, 0.3)
static var HOVER_CRYSTAL := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB,
	false, true, 0.7)
static var HOVER_GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
## The Mega Mine's seams by tier, too thin to ink: cyan and violet glowing, swelling in turn,
## then gold filigree; and its hovering ring's obsidian, bobbing with the violet ring's phase.
static var CYAN_SEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true, false)
static var VIOLET_SEAM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE, true, false)
static var GOLD_SEAM := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 2.0, Surf.GLOSSY, false, false)
static var HOVER_OBSIDIAN := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true,
	0.7)
## The Obsidian fuse: the core lens's light violet, steady, so it never dims to grey.
static var BRIGHT_FUSE := Surf.make(MaterialKit.Layer.GLOW, CORE_LIGHT, 1.0, Surf.UNLIT)
## The horizontal directions towards the camera (IsoCamera's yaw, 45 degrees round from +X):
## the vein panels go round them.
const CAMERA_SIDE: Array[float] = [5.0, 45.0, 85.0]


## A low domed disc on a hazard rim, spikes round its crown and a red warning light. More
## spikes at 2, a second light in a ring at 3, the ring gold from the Gold tier. The lights
## blink in turn.
static func build_proximity_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	if level >= 4:
		_grown_proximity_mine(p, level)
		return
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
		m.ring(0.07, 0.1, 0.03, 16, base + Vector3(0, 0.152, 0), GOLD_ROUND if p.tier >= Parts.Tier.GOLD else CASING_MID)
		m.dome(0.04, 0.04, 16, 3, Parts.around(0.31, 45, 0.07) + base, RED_BLINK.phased(0.5))


## Levels 4 to 6, the mine grown: a wider, taller dome on a wider hazard rim, a spike more a
## level and six warning lamps chasing round the rim. L4 (Chrome): a chrome dome banded in cyan,
## chrome spikes, cyan lamps, a chrome cap round the red light. L5 (Obsidian): an obsidian dome
## with glowing violet vein panels on the faces the camera sees, glowing crystal spikes, violet
## lamps, the cap gold, and a violet warning ring hovering round the dome at mid-height, clear of
## the crown. L6 (Crown): the dome banded in gold filigree, gold spikes, gold and violet lamps,
## and a big light-violet core lens pulsing on the crown in place of the red light, under a small
## gold crown.
static func _grown_proximity_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var radius := 0.34 + 0.02 * (level - 4)
	var height := 0.26 + 0.02 * (level - 4)
	m.ring(radius - 0.03, radius + 0.08, 0.08, 16, base, HAZARD_FINE)
	m.lathe(PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, height * 0.54), Vector2(radius * 0.85, height * 0.77),
		Vector2(radius * 0.38, height * 0.96), Vector2(0, height),
	]), 16, base, Parts.OBSIDIAN_ROUND if obsidian else Parts.CHROME_ROUND)
	var band := Parts.CYAN_STRIP
	if crown:
		band = Parts.FILIGREE
	elif obsidian:
		band = VIOLET_PULSE
	m.ring(radius - 0.002, radius + 0.015, 0.035, 16, base + Vector3(0, height * 0.35, 0), band)
	if level >= 5:
		var proud := radius + 0.008
		_vein_panels(m, PackedVector2Array([
			Vector2(proud, height * 0.5), Vector2(proud * 0.85, height * 0.78), Vector2(proud * 0.4, height * 0.97),
		]), base, 30.0)
	if level >= 6:
		# A second filigree band round the dome's shoulder.
		m.lathe(PackedVector2Array([Vector2(radius * 0.97, height * 0.6), Vector2(radius * 0.89, height * 0.72)]), 16,
			base + Vector3(0, 0.006, 0), Parts.FILIGREE)
	var spike := Parts.CHROME_ROUND
	if crown:
		spike = Parts.GOLD_ROUND
	elif obsidian:
		spike = CRYSTAL_GLOW
	var count := level + 2
	for i: int in count:
		var degrees := 90.0 + 360.0 * i / count
		var out := Parts.around(1.0, degrees, 0.0)
		m.cone(0.045, 0.17, 8, Parts.around(radius * 0.68, degrees, height * 0.78) + base,
			spike.phased(float(i) / count), Parts.facing(out * 0.5 + Vector3.UP))
	for i: int in 6:
		var lamp := CYAN_BLINK
		if crown:
			lamp = GOLD_BLINK if i % 2 == 0 else VIOLET_BLINK
		elif obsidian:
			lamp = VIOLET_BLINK
		m.dome(0.045, 0.045, 8, 2, Parts.around(radius + 0.045, 15.0 + 60.0 * i, 0.08) + base,
			lamp.phased(Parts.chase(i, 6)))
	var top := base + Vector3(0, height, 0)
	m.ring(0.08, 0.125, 0.04, 16, top - Vector3(0, 0.012, 0), GOLD_ROUND if obsidian else Parts.CHROME_ROUND)
	if level >= 6:
		m.dome(0.12, 0.11, 16, 3, top - Vector3(0, 0.006, 0), BRIGHT_CORE)
		_crown(m, top + Vector3(0, 0.04, 0), 0.15)
	else:
		m.dome(0.085, 0.08, 16, 3, top - Vector3(0, 0.006, 0), RED_BLINK)
	if level >= 5:
		# The warning ring hovering round the dome, outside the lamps.
		m.ring(radius + 0.1, radius + 0.16, 0.035, 24, base + Vector3(0, height * 0.6, 0), HOVER_GLOW)


## A ring emitter round a dark funnel with a violet vortex at its bottom, coils on its rim. A
## second ring hovering over it at 2, gold from the Gold tier. The emitter's lip and the hovering
## ring pulse; the
## vortex's glow streams inward down the funnel.
static func build_grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	if level >= 3:
		_grown_grav_trap(p, level)
		return
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
		m.ring(0.15, 0.23, 0.05, 16, hover, GOLD_ROUND if p.tier >= Parts.Tier.GOLD else CASING_MID)
		m.ring(0.13, 0.15, 0.03, 16, hover + Vector3(0, 0.01, 0), VIOLET_PULSE.phased(0.5))


## Levels 3 to 5, the trap grown: a wider, taller emitter round a deeper funnel, six swirl
## strips, round coils banded in light, the strut ring higher. L3 (Chrome): a chrome emitter and
## strut ring, the lip and the vortex cyan, chrome coils. L4 (Obsidian): an obsidian funnel with
## glowing violet vein panels on the faces the camera sees, the vortex violet, crystals glowing on
## the coils, and a crystal ring hovering round the emitter, turning, crystal shards on it. L5
## (Crown): a gold filigree rim, a violet core glowing at the funnel's bottom, the coils banded
## in the core's violet, the hovering ring gold with violet shards.
static func _grown_grav_trap(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var k := 1.0 + 0.05 * (level - 3)
	m.lathe(PackedVector2Array([
		Vector2(0.36 * k, 0), Vector2(0.385 * k, 0.06), Vector2(0.36 * k, 0.13), Vector2(0.29 * k, 0.16),
	]), 16, base, Parts.OBSIDIAN_ROUND if obsidian else Parts.CHROME_ROUND)
	m.lathe(PackedVector2Array([Vector2(0.29 * k, 0.16), Vector2(0.22 * k, 0.145)]), 16, base,
		VIOLET_PULSE if obsidian else Parts.CYAN_STRIP)
	m.lathe(PackedVector2Array([Vector2(0.22 * k, 0.145), Vector2(0.1, 0.06)]), 16, base, VOID)
	m.lathe(PackedVector2Array([Vector2(0.1, 0.06), Vector2(0.04, 0.035), Vector2(0, 0.035)]), 16, base,
		VIOLET_INFLOW if obsidian else CYAN_INFLOW)
	for i: int in 6:
		var degrees := 60.0 * i
		m.strut(Parts.around(0.2 * k, degrees, 0.14 - 0.01 * k) + base, Parts.around(0.1, degrees + 70.0, 0.062) + base,
			0.025, SWIRL if obsidian else CYAN_SWIRL)
	if level >= 4:
		_vein_panels(m, PackedVector2Array([
			Vector2(0.368 * k, 0.005), Vector2(0.393 * k, 0.06), Vector2(0.368 * k, 0.125),
		]), base, 30.0)
	if level >= 5:
		Parts.torus(m, 0.325 * k, 0.03, 16, 6, base + Vector3(0, 0.12, 0), Parts.FILIGREE)
		m.orb(0.06, 10, 5, base + Vector3(0, 0.08, 0), Parts.CORE_GLOW)
	for i: int in 3:
		var foot := Parts.around(0.37 * k, 30.0 + 120.0 * i, 0.0) + base
		Parts.drum(m, 0.06, 0.17, 0.02, 8, foot, Parts.OBSIDIAN_ROUND if obsidian else Parts.CHROME_ROUND)
		var band := Parts.CYAN_STRIP
		if crown:
			band = Parts.CORE_GLOW
		elif obsidian:
			band = VIOLET_PULSE
		m.ring(0.058, 0.072, 0.03, 8, foot + Vector3(0, 0.08, 0), band.phased(i / 3.0))
		if level >= 4:
			m.cone(0.04, 0.09, 8, foot + Vector3(0, 0.17, 0), CRYSTAL_GLOW.phased(i / 3.0))
	var ring := base + Vector3(0, 0.34, 0)
	for i: int in 3:
		var degrees := 90.0 + 120.0 * i
		m.strut(Parts.around(0.27 * k, degrees, 0.15) + base, Parts.around(0.21, degrees, 0.0) + ring, 0.03, Parts.ROD)
	m.ring(0.16, 0.25, 0.05, 16, ring, Parts.OBSIDIAN_ROUND if obsidian else Parts.CHROME_ROUND)
	m.ring(0.14, 0.16, 0.03, 16, ring + Vector3(0, 0.01, 0), VIOLET_PULSE.phased(0.5) if obsidian else Parts.CYAN_STRIP)
	if level >= 4:
		# The ring hovering round the emitter, outside the coils, turning with its shards.
		var s := p.moving(base + Vector3(0, 0.2, 0), Motion.spin(Vector3.UP, 0.8))
		s.ring(0.5, 0.56, 0.04, 24, Vector3.ZERO, HOVER_GOLD if crown else HOVER_CRYSTAL)
		for i: int in 4:
			s.cone(0.03, 0.1, 8, Parts.around(0.53, 45.0 + 90.0 * i, 0.04), HOVER_GLOW if crown else HOVER_CRYSTAL)


## A squat pod banded in hazard stripes with upward barrels round a sensor lens, their bores
## glowing. A barrel more at each level. The bores pulse in turn and the lens flashes.
static func build_flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 1)
	if level >= 4:
		_grown_flak_mine(p, level)
		return
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
		m.ring(0.075, 0.1, 0.025, 16, top, GOLD_ROUND if p.tier >= Parts.Tier.GOLD else CASING_MID)


## Levels 4 and 5, the mine grown: a wider, taller pod, a barrel more a level, a bigger sensor
## lens raised on a collar over the barrels and four lamps round the pod blinking in turn. L4
## (Chrome): a chrome pod banded in cyan, chrome barrels with cyan bores, cyan lamps, a chrome
## collar. L5 (Crown): an obsidian pod banded in gold filigree with glowing violet vein panels on
## the faces the camera sees, gold barrels with violet bores, gold and violet lamps, a taller gold
## collar, and a big light-violet core lens pulsing in the sensor under a small gold crown.
static func _grown_flak_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	var crown := p.tier >= Parts.Tier.CROWN
	var radius := 0.3 + 0.02 * (level - 4)
	var height := 0.24 + 0.02 * (level - 4)
	Parts.tank(m, radius, height, base, Parts.OBSIDIAN_ROUND if crown else Parts.CHROME_ROUND, 0.06)
	m.ring(radius, radius + 0.018, 0.07, 16, base + Vector3(0, 0.02, 0), HAZARD_FINE)
	m.ring(radius - 0.002, radius + 0.012, 0.03, 16, base + Vector3(0, height - 0.075, 0),
		Parts.FILIGREE if crown else Parts.CYAN_STRIP)
	if level >= 5:
		_vein_panels(m, PackedVector2Array([Vector2(radius + 0.006, 0.09), Vector2(radius + 0.006, height - 0.075)]), base,
			30.0)
	for i: int in 4:
		var degrees := 15.0 + 90.0 * i
		var lamp := CYAN_BLINK
		if crown:
			lamp = GOLD_BLINK if i % 2 == 0 else VIOLET_BLINK
		m.dome(0.032, 0.035, 8, 2, Parts.around(radius, degrees, 0.125) + base, lamp.phased(Parts.chase(i, 4)),
			Parts.facing(Parts.around(1.0, degrees, 0.0)))
	var top := base + Vector3(0, height, 0)
	var barrels := level + 1
	for i: int in barrels:
		var spot := Parts.around(0.19, 135.0 + 360.0 * i / barrels, 0.0) + top
		m.prism(0.055, 0.05, 0.18, 12, spot, GOLD_ROUND if crown else Parts.CHROME_ROUND)
		m.disc(0.036, 12, spot + Vector3(0, 0.181, 0), (Parts.CORE_GLOW if crown else Parts.CYAN_STRIP).phased(float(i) / barrels))
	# The sensor raised on a collar over the barrels' mouths, higher at L5, its core lens bigger.
	var collar := 0.12 if level < 5 else 0.19
	Parts.drum(m, 0.11, collar, 0.02, 16, top, GOLD_ROUND if crown else Parts.CHROME_ROUND)
	var sensor := top + Vector3(0, collar, 0)
	if level >= 5:
		m.dome(0.115, 0.17, 16, 3, sensor - Vector3(0, 0.005, 0), BRIGHT_CORE)
		_crown(m, sensor + Vector3(0, 0.06, 0), 0.14)
	else:
		m.dome(0.095, 0.09, 16, 3, sensor, LENS)


## A big armoured dome on a hazard band, warning lights round its foot and a fuse cap on its
## crown. A thicker dome and more lights at 2. The lights chase round the band, glowing seams run
## up the dome between them, swelling faintly, and the fuse light pulses.
static func build_mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	Parts.foundation(m, 2)
	if level >= 3:
		_grown_mega_mine(p, level)
		return
	m.ring(0.6, 0.72, 0.12, 24, base, HAZARD_FINE)
	var radius := 0.62 if level < 2 else 0.68
	var height := 0.42 if level < 2 else 0.54
	m.dome(radius, height, 24, 6, base + Vector3(0, 0.06, 0), CASING)
	if level >= 2:
		m.ring(radius - 0.02, radius + 0.04, 0.05, 24, base + Vector3(0, 0.1, 0),
			GOLD_ROUND if p.tier >= Parts.Tier.GOLD else CASING_MID)
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


## Levels 3 to 5, the mine grown: a wider, taller dome on a wider hazard band, eight lights
## chasing round it with glowing seams up the dome between them, a bigger fuse cap with a sensor
## mast. L3 (Chrome): a chrome dome with cyan seams and cyan lights, a chrome fuse cap round the
## red fuse light. L4 (Obsidian): an obsidian dome with violet vein seams and glowing violet vein
## panels on the faces the camera sees, violet lights, an obsidian cap with a crystal fuse glowing
## light violet, and a violet-rimmed obsidian ring hovering round the dome's waist, turning with its
## crystal studs. L5 (Crown): gold filigree seams and band, gold and violet lights, a violet core
## fuse under a gold crown on a gold cap, the hovering ring's rim gold and its studs violet.
static func _grown_mega_mine(p: Parts, level: int) -> void:
	var m := p.body
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var radius := 0.74 + 0.03 * (level - 3)
	var height := 0.62 + 0.05 * (level - 3)
	var foot := base + Vector3(0, 0.06, 0)
	m.ring(radius - 0.06, radius + 0.08, 0.13, 24, base, HAZARD_FINE)
	m.dome(radius, height, 24, 6, foot, Parts.OBSIDIAN_ROUND if obsidian else Parts.CHROME_ROUND)
	m.ring(radius - 0.02, radius + 0.04, 0.05, 24, base + Vector3(0, 0.1, 0), Parts.FILIGREE if crown else GOLD_ROUND)
	var seam := CYAN_SEAM
	var light := CYAN_BLINK
	if crown:
		seam = GOLD_SEAM
	elif obsidian:
		seam = VIOLET_SEAM
		light = VIOLET_BLINK
	for i: int in 8:
		var degrees := 45.0 * i
		if crown:
			light = GOLD_BLINK if i % 2 == 0 else VIOLET_BLINK
		m.dome(0.06, 0.06, 12, 3, Parts.around(radius + 0.02, degrees, 0.13) + base, light.phased(Parts.chase(i, 8)))
		Parts.dome_seam(m, radius, height, foot, degrees + 22.5, seam.phased(i / 8.0))
	if level >= 4:
		var panel := PackedVector2Array()
		for k: int in range(1, 6):
			var angle := PI * 0.5 * k / 6
			panel.append(Vector2((radius + 0.01) * cos(angle), (height + 0.01) * sin(angle)))
		_vein_panels(m, panel, foot, 30.0)
	var cap := base + Vector3(0, 0.06 + height - 0.02, 0)
	var cap_surf := Parts.CHROME_ROUND
	if crown:
		cap_surf = GOLD_ROUND
	elif obsidian:
		cap_surf = Parts.OBSIDIAN_ROUND
	m.prism(0.16, 0.13, 0.1, 16, cap, cap_surf)
	var fuse := cap + Vector3(0, 0.1, 0)
	if level >= 5:
		m.orb(0.09, 16, 6, fuse + Vector3(0, 0.08, 0), Parts.CORE_GLOW)
		_crown(m, fuse + Vector3(0, 0.12, 0), 0.12)
	elif level >= 4:
		m.prism(0.09, 0.03, 0.26, 8, fuse, BRIGHT_FUSE)
	else:
		m.dome(0.08, 0.08, 16, 3, fuse, RED_PULSE)
	for i: int in 3:
		var degrees := 90.0 + 120.0 * i
		m.cone(0.03, 0.16, 8, Parts.around(0.12, degrees, 0.07) + cap, GOLD_ROUND if crown else Parts.CHROME_ROUND,
			Parts.facing(Parts.around(0.5, degrees, 1.0)))
	Parts.mast(m, Parts.around(0.1, 150.0, 0.1) + cap, 0.22, 0.03, light.phased(0.5))
	if level >= 4:
		# The ring hovering round the dome's waist, turning with its studs.
		var s := p.moving(foot + Vector3(0, height * 0.45, 0), Motion.spin(Vector3.UP, 0.6))
		s.ring(0.75, 0.84, 0.05, 24, Vector3.ZERO, HOVER_OBSIDIAN)
		s.ring(0.84, 0.86, 0.035, 24, Vector3(0, 0.008, 0), HOVER_GOLD if crown else HOVER_GLOW)
		for i: int in 4:
			s.orb(0.045, 10, 4, Parts.around(0.795, 45.0 + 90.0 * i, 0.07), HOVER_GLOW if crown else HOVER_CRYSTAL)


## Glowing violet vein panels on a round part where the camera sees it: `profile` (radius and
## height from the bottom up, just proud of the surface, round +Y through `pos`) swept `width`
## degrees round each of CAMERA_SIDE, one segment at a time, so a panel is a shell with no end
## faces.
static func _vein_panels(m: LowPolyMesh, profile: PackedVector2Array, pos: Vector3, width: float) -> void:
	for centre: float in CAMERA_SIDE:
		for i: int in profile.size() - 1:
			m.lathe(PackedVector2Array([profile[i], profile[i + 1]]), 24, pos, VEIN_PANEL, Vector3.ZERO,
				centre - width * 0.5, centre + width * 0.5)


## A trap's small gold crown, the Crown tier's: a gold ring of `radius` standing on `pos` with
## five teeth round its top.
static func _crown(m: LowPolyMesh, pos: Vector3, radius: float) -> void:
	m.ring(radius - 0.025, radius, 0.03, 16, pos, GOLD_ROUND)
	for i: int in 5:
		m.cone(0.018, 0.06, 8, Parts.around(radius - 0.0125, 90.0 + 72.0 * i, 0.03) + pos, GOLD_ROUND)
