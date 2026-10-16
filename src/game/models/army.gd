extends RefCounted
## Models of the army buildings, in the comic style (docs/reference/art-style.md): hull-light
## halls and towers on concrete pads, army orange on one or two surfaces and in one glow,
## gunmetal machinery, gold trim from the Gold tier (Parts.tier). They move (docs/reference/art-style.md,
## **Animation**): surface effects on the lamps, glows, screens, goo, sparks and smoke, and moving
## parts (Parts.moving) for the hangar door, the cranes, the press arms, the dishes, the telescope,
## the stirrer, the hologram cadet, the simulator's gimbal rings, the searchlight and, from the
## Obsidian tier, the rings hovering round the lab's hologram, over the foundry's big vat and round
## the beacon's tower.
##
## The Hangar, the Cadet Academy, the Fabricator and the Research Lab have ten levels, the Heavy
## Fabricator and the Nanite Foundry eight, the Drydock and the Alliance Beacon seven, through the
## higher tiers (docs/reference/art-style.md, **Tiers**): chrome with cyan strips, then obsidian
## veined violet with crystal inlays and a hovering ring, drone or platform, then gold filigree
## over the obsidian and the antimatter core glowing, with, on the hangar, the academy and the
## drydock, an escort as the fourth moving part. The army's orange stays its accent through them, and the foundry's goo stays
## green. The surfaces follow the tier (_plating, _strip, _glow, _trim), the parts the level.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. Each builds
## its level as a run of additions (`if level >= 3:` adds the second bay), so the levels of a
## type read as one building growing.

## The army's surfaces: its orange accent and glow, the round and armoured hulls.
static var ORANGE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY)
static var ORANGE_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.LIT, true)
static var GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT, true)
static var HULL_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var MID_ROUND := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var ARMOUR_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var DARK_PLATE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var GOLD_ROUND := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
static var PIPE := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 2.0, Surf.LIT, true)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID)
static var ROLLER := Surf.make(MaterialKit.Layer.VENT, MaterialKit.ARMY, 2.0)
static var BELT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 3.0)
## A screen showing nanite goo, its rows scrolling.
static var GOO_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.NANITE_GREEN, 1.0, Surf.FLOW, false,
	true, 0.7)

## The animated surfaces (docs/reference/art-style.md, **Animation**). Lamps that chase, sparks
## that flicker apart and puffs that bob out of step take their phases through phased().
## The army glow pulsing (furnace mouths, reactors, engines) and blinking (lamps).
static var GLOW_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.PULSE,
	true)
static var LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var HOT_PULSE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.PULSE)
## Molten metal running out along V, at two speeds.
static var POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.FLOW, false, true,
	0.7)
static var HOT_POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLOW, false,
	true, 0.8)
## Sparks: flickering, and flickering and shaking off a welder.
static var SPARK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLICKER)
static var SPARK_ARC := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0,
	Surf.UNLIT | Surf.FLICKER | Surf.JITTER)
static var WELD_BLINK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK,
	true)
## A screen whose rows scroll; phased() sets its speed.
static var SCREEN_FLOW := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.CORE_GLASS, 1.0, Surf.FLOW)
## The lit hangar inside an opening door: an orange glow, its stripes rising.
static var INTERIOR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 2.0, Surf.UNLIT | Surf.FLOW, false,
	false, 0.35)
## Goo rising behind glass (phased() sets its speed), goo swirling in an open vat, its bubbles,
## and the pipes carrying it along.
static var GOO_FLOW := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN, 1.0,
	Surf.UNLIT | Surf.FLOW, true, true, 0.3)
static var GOO_SWIRL := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN, 1.0,
	Surf.UNLIT | Surf.FLOW_U, false, true, 0.65)
## A bubble is the goo's green half way to white, so it flashes brighter than the goo and
## shows as a dim green dot between flashes; too small for an outline.
static var BUBBLE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.NANITE_GREEN.lerp(Color.WHITE, 0.5), 1.0,
	Surf.UNLIT | Surf.BLINK, true, false)
static var PIPE_FLOW := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.FLOW, true, true,
	0.3)
## Glass glowing on a pulse: the hangar's control cab, the fabricator's roof windows.
static var CAB_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0,
	Surf.GLOSSY | Surf.PULSE, true)
static var WINDOW_GLOW := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.PULSE)
## Holograms, and the beacon's floating emitter and spike.
static var HOLOGRAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO | Surf.BOB, true)
static var HOLO_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.ENERGY, 1.0, Surf.HOLO, true)
static var ORB_BOB := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0,
	Surf.UNLIT | Surf.PULSE | Surf.BOB, true)
static var GOLD_BOB := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB,
	true)
static var GUNMETAL_BOB := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true)
## The academy's target silhouettes, blinking on in turn; its drill grid, flickering; its
## searchlight's lens and beam.
static var TARGET := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO | Surf.BLINK)
static var DRILL_GRID := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.FLICKER)
static var SEARCH_LENS := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var SEARCH_BEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.HOLO, true)
## The high tiers' own (docs/reference/art-style.md, **Tiers**), beside the shared ones on Parts.
## The hangar's, shared by the others: a cyan lamp blinking in a chase; the violet glow of an
## obsidian level, a rib pulsing; crystal inlays and shards pulsing; gold filigree smooth shaded,
## for rings; a violet hologram; an obsidian ring hovering on BOB with its violet rim, on one phase
## so they bob together.
static var CYAN_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var VIOLET_RIB := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
static var FILIGREE_ROUND := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 2.0, Surf.GLOSSY, true)
static var HOLO_VIOLET := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.HOLO | Surf.BOB, true)
static var HOVER := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.6)
static var HOVER_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, 0.6)
## The antimatter core where it must read from across the base (the Hangar's crests, the
## Academy's band and halo, the Fabricator's furnace): a light violet, unlit and steady, so it is
## the brightest thing on the model where CORE_GLOW's pulse would dim it (as the collectors'
## BRIGHT_CORE in resources.gd).
static var BRIGHT_CORE := Surf.make(MaterialKit.Layer.GLOW, Color("c9a2ff"), 1.0, Surf.UNLIT, true)
## The academy's: a violet panel whose coarse stripes rise as the walls' fields do; the
## searchlight's lens and beam in cyan; the drill grid violet; the drill drone's glass and eye,
## bobbing with the hovering obsidian (HOVER's phase).
static var VIOLET_PANEL := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0 / 3.0, Surf.UNLIT | Surf.FLOW, false,
	true, 0.45)
static var CYAN_LENS := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var CYAN_BEAM := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO, true)
static var VIOLET_GRID := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.FLICKER)
static var DRONE_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CORE_GLASS, 1.0, Surf.GLOSSY | Surf.BOB, true, true,
	0.6)
static var DRONE_EYE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BOB, true, true, 0.6)
## The Crown cadet's halo: BRIGHT_CORE's light violet, solid, bobbing out of step with the cadet.
static var BRIGHT_HALO := Surf.make(MaterialKit.Layer.GLOW, Color("c9a2ff"), 1.0, Surf.UNLIT | Surf.BOB, true, true, 0.5)
## The fabricator's: chrome roller doors, crystal-lit smoke.
static var CHROME_ROLLER := Surf.make(MaterialKit.Layer.VENT, Parts.CHROME_TINT, 2.0, Surf.GLOSSY)
static var CRYSTAL_SMOKE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.HOLO | Surf.BOB, true)
## The heavy fabricator's: the pour and its hot core in crystal pink; the violet sparks.
static var CRYSTAL_POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.FLOW, false, true,
	0.7)
static var HOT_CRYSTAL_POUR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL.lerp(Color.WHITE, 0.5), 1.0,
	Surf.UNLIT | Surf.FLOW, false, true, 0.8)
static var VIOLET_SPARK := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.FLICKER)
## The research lab's: screens glowing cyan, their rows scrolling (phased() sets the speed).
static var CYAN_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.FLOW)
## The nanite foundry's: cyan pipes, their bands flowing; the goo brighter, rising and swirling;
## the hovering stirrer ring's crystal vanes, bobbing with it (HOVER's phase).
static var CYAN_PIPE := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.ENERGY, 2.0, Surf.UNLIT | Surf.FLOW, true, true, 0.3)
static var GOO_BRIGHT := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN.lerp(Color.WHITE, 0.3), 1.0,
	Surf.UNLIT | Surf.FLOW, true, true, 0.3)
static var GOO_BRIGHT_SWIRL := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.NANITE_GREEN.lerp(Color.WHITE, 0.3), 1.0,
	Surf.UNLIT | Surf.FLOW_U, false, true, 0.65)
static var HOVER_CRYSTAL := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB,
	false, true, 0.6)
## The drydock's: the welders' sparks cyan, then crystal (and the crystal arcs off them); the
## hovering crane platform's deck and cab, bobbing with its rim (HOVER's phase).
static var CYAN_SPARK_ARC := Parts.spark(MaterialKit.ENERGY)
static var CRYSTAL_SPARK_ARC := Parts.spark(MaterialKit.CRYSTAL)
static var HOVER_PLATE := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, false, true, 0.6)
static var HOVER_CHROME := Surf.make(MaterialKit.Layer.CHROME, Parts.CHROME_TINT, 1.0, Surf.GLOSSY | Surf.BOB, false, true, 0.6)
## Filigree for thin parts at Crown (the drydock's gantry posts, the beacon's legs): Parts.FILIGREE's
## bands at about a third the repeats, so a thin part reads as banded gold, not as dashes.
static var FILIGREE_LEG := Surf.make(MaterialKit.Layer.BANDS, MaterialKit.CORE_GOLD, 0.7, Surf.GLOSSY)
## The alliance beacon's: the rings' lights violet, blinking; the emitter orb crystal, then the
## antimatter core's bright violet, bobbing with its spike (phase 0, as ORB_BOB).
static var VIOLET_LAMP := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var CRYSTAL_ORB := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true)
static var BRIGHT_ORB := Surf.make(MaterialKit.Layer.GLOW, Color("c9a2ff"), 1.0, Surf.UNLIT | Surf.BOB, true)
## The hangar's marshaller bot, every part bobbing together: its hull, hazard shoulders,
## gunmetal arms and thruster, orange cap, its visor glowing cyan, its wands a hot orange light
## with no ink, so they glow rather than read as sticks.
static var MARSHAL_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 2.0, Surf.BOB, false, true, 0.2)
static var MARSHAL_HAZARD := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 2.0, Surf.BOB, false, true, 0.2)
static var MARSHAL_METAL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.GUNMETAL, 1.0, Surf.BOB, true, true, 0.2)
static var MARSHAL_VISOR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BOB, true, true, 0.2)
static var MARSHAL_CAP := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ARMY, 1.0, Surf.BOB, true, true, 0.2)
static var MARSHAL_WAND := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY.lerp(Color.WHITE, 0.25), 1.0,
	Surf.UNLIT | Surf.BOB, true, false, 0.2)

## Where the L10 marshaller hovers: on the apron before the main door, over the lamps.
const MARSHAL_AT := Vector3(-1.0, 0.65, 1.85)


## A long vaulted hangar: the main bay with its striped door, the control tower in the back
## corner, landing lights along the apron. Wider door at 2 and 3, a second bay at 3, roof
## dishes at 4. The main bay's door rises over its lit inside and drops again, the lights chase
## along the apron, the cab's glass pulses and a radar turns on its roof; from 4 the big roof
## dish sweeps.
##
## From 6 the tower grows taller at each level and the apron's lights stand in two rows before
## the main door, chasing apart: L6 chrome roofs with cyan ribs, a chrome tower with cyan strips
## and a bigger radar dish, chrome lamps, a skiff parked on a pad on the apron; L7 a third, small
## bay on the apron's right and a chrome gallery round the tower; L8 obsidian walls and tower,
## violet-veined doors, ribs glowing violet, crystal beacons in the second row, crystal inlays on
## the tower; L9 a landing ring hovering over the skiff, obsidian rimmed in violet, and a second
## gallery; L10 an obsidian roof under gold filigree ribs with the antimatter core glowing in
## broad bands along its crests, filigree banners on the bays' gables and bands up the tower, a
## violet core beacon on a gold spire atop it, and a marshaller bot hovering on the apron before
## the main door, rocking as it waves its glowing wands, as its escort.
static func build_hangar(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	Parts.foundation(m, 5)
	var doors: Array[float] = [1.3, 1.6, 1.9]
	_vault(p, Vector3(-1.0, g, -2.25), 2.6, 3.6, 0.75, doors[mini(level, 3) - 1], true, level)
	if level >= 3:
		_vault(p, Vector3(1.35, g, -0.9), 1.8, 2.25, 0.55, 1.2, false, level)
	else:
		m.disc(0.75, 24, Vector3(1.35, g + 0.002, 0.2), Parts.HAZARD)
		m.disc(0.6, 24, Vector3(1.35, g + 0.004, 0.2), ARMOUR)
	if level < 6:
		var lights := 4 + level
		for i: int in lights:
			var x := -1.85 + 3.9 * i / (lights - 1)
			Parts.landing_light(m, Vector3(x, g, 2.05), 0.11, LAMP.phased(float(i) / lights))
	else:
		_apron(p, level)
	# The control tower, taller from 6.
	var tower := Vector3(1.45, g, -1.65)
	m.box_chamfered(Vector3(0.95, 0.3, 0.95), 0.06, tower, _plating(p.tier, ARMOUR))
	var extra: Array[float] = [0.0, 0.45, 0.75, 1.05, 1.3, 1.4]
	var shaft := 1.0 + 0.06 * level + extra[clampi(level - 5, 0, 5)]
	m.prism(0.3, 0.25, shaft, 16, tower + Vector3(0, 0.3, 0), _plating(p.tier, MID_ROUND, true))
	if level >= 6:
		_tower_dress(m, tower + Vector3(0, 0.3, 0), shaft, level, p.tier)
	var cab := tower + Vector3(0, 0.3 + shaft, 0)
	m.prism(0.42, 0.42, 0.1, 16, cab, HULL_ROUND)
	m.ring(0.41, 0.44, 0.05, 16, cab + Vector3(0, 0.03, 0), GLOW)
	m.prism(0.42, 0.5, 0.34, 16, cab + Vector3(0, 0.1, 0), CAB_GLASS)
	m.lathe(PackedVector2Array([
		Vector2(0.56, 0), Vector2(0.56, 0.06), Vector2(0.4, 0.16), Vector2(0, 0.16),
	]), 16, cab + Vector3(0, 0.44, 0), GOLD_ROUND if p.tier >= Parts.Tier.GOLD else HULL_ROUND)
	if level >= 10:
		_crown_beacon(m, cab + Vector3(0.12, 0.6, -0.1), 0.62)
	else:
		Parts.mast(m, cab + Vector3(0.12, 0.6, -0.1), 0.3 + 0.03 * level, 0.06, GLOW)
	# The radar turning on the cab's roof, clear of the mast; bigger from 6.
	var big := 1.45 if level >= 6 else 1.0
	var stub := cab + Vector3(-0.14, 0.6, 0.12)
	m.prism(0.05, 0.04, 0.12, 12, stub, Parts.GUNMETAL)
	var radar := p.moving(stub + Vector3(0, 0.12, 0), Motion.spin(Vector3.UP, 1.2))
	radar.box_chamfered(Vector3(0.08, 0.08, 0.08), 0.02, Vector3.ZERO, Parts.GUNMETAL)
	var tilt := Vector3(60, 90, 0)
	var hub := Vector3(0, 0.08, 0)
	Parts.dish(radar, 0.18 * big, 0.07 * big, hub, GOLD_ROUND if p.tier >= Parts.Tier.GOLD else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(radar, hub + axis * 0.03, hub + axis * 0.15 * big, 0.015, Parts.ROD)
	radar.orb(0.03 * big, 10, 4, hub + axis * 0.15 * big, CYAN_LAMP if chrome else GLOW)
	if level >= 2:
		# Fuel tanks on the apron, beside the main door.
		for z: float in [1.68, 1.92]:
			Parts.tank(m, 0.1, 0.32, Vector3(-2.2, g, z), ORANGE_ROUND, 0.03)
	if level >= 4:
		_roof_dish(p, Vector3(-1.0, g + 1.98, -1.5), 0.5, true)
		_roof_dish(p, Vector3(1.35, g + 1.38, -0.4), 0.32, false)
	if level >= 7:
		_vault(p, Vector3(1.75, g, 1.58), 1.0, 0.85, 0.4, 0.5, false, level)
	if obsidian:
		# Crystal inlays on the tower's base, facing the camera.
		for face: Vector3 in [Vector3(0, 0, 1), Vector3(1, 0, 0)]:
			m.prism(0.14, 0.14, 0.04, 4, tower + face * 0.475 + Vector3(0, 0.15, 0), INLAY,
				Vector3(90, 90.0 * face.x, 0))
	if level >= 10:
		_marshaller(p, MARSHAL_AT + Vector3(0, g, 0))


## The hangar's marshaller from 10, hovering at `at` before the main door, facing the apron (+Z):
## a stubby hover-bot, its hull striped hazard over the shoulders, a cyan visor across its face
## under an orange cap, a thruster under it, holding two glowing orange wands angled up and out,
## drawn at 1.8 times its size so it reads at the gameplay zoom. A moving part, it rocks
## 20 degrees either way about the vertical through its middle as it waves ships in; every part
## bobs together.
static func _marshaller(p: Parts, at: Vector3) -> void:
	const K := 1.8
	var bot := p.moving(at, Motion.swing(Vector3.UP, 20.0, 2.5))
	bot.box_chamfered(Vector3(0.32, 0.28, 0.24) * K, 0.06 * K, Vector3(0, -0.14, 0) * K, MARSHAL_HULL)
	bot.box(Vector3(0.24, 0.07, 0.02) * K, Vector3(0, 0.02, 0.12) * K, MARSHAL_VISOR)
	bot.dome(0.1 * K, 0.07 * K, 10, 2, Vector3(0, 0.14, 0) * K, MARSHAL_CAP)
	bot.prism(0.08 * K, 0.06 * K, 0.07 * K, 10, Vector3(0, -0.21, 0) * K, MARSHAL_METAL)
	for side: float in [-1.0, 1.0]:
		bot.box_chamfered(Vector3(0.1, 0.1, 0.2) * K, 0.03 * K, Vector3(side * 0.19, 0.0, 0) * K, MARSHAL_HAZARD)
		var hand := Vector3(side * 0.34, 0.16, 0.06) * K
		Parts.beam(bot, Vector3(side * 0.22, 0.05, 0.02) * K, hand, 0.05 * K, MARSHAL_METAL, 0.015 * K)
		var up := Vector3(side * 0.45, 1.0, 0.15).normalized()
		bot.prism(0.05 * K, 0.04 * K, 0.34 * K, 8, hand, MARSHAL_WAND, Parts.facing(up))


## The apron from 6 (_hangar's): two rows of lamps before the main door chasing apart, chrome
## housings, the front row orange, the back row cyan (crystal beacons from the Obsidian tier); a
## hazard pad left of the second bay's door with a skiff parked on it; from 9 a landing ring
## hovering over the skiff, obsidian with a violet rim, a violet hologram ring over it.
static func _apron(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var housing := _plating(p.tier, Parts.GUNMETAL, true)
	var lights := level - 1
	for i: int in lights:
		var x := -1.85 + 1.9 * i / (lights - 1)
		Parts.landing_light(m, Vector3(x, g, 1.98), 0.11, LAMP.phased(Parts.chase(i, lights)), housing)
		var back := Vector3(x + 0.95 / (lights - 1), g, 2.3)
		if i == lights - 1:
			continue
		if p.tier >= Parts.Tier.OBSIDIAN:
			m.prism(0.07, 0.06, 0.05, 8, back, Parts.OBSIDIAN, Parts.OCTAGON)
			m.cone(0.045, 0.2, 8, back + Vector3(0, 0.05, 0), INLAY.phased(Parts.chase(lights - 2 - i, lights - 1)))
		else:
			Parts.landing_light(m, back, 0.075, CYAN_LAMP.phased(Parts.chase(lights - 2 - i, lights - 1)), housing)
	var pad := Vector3(0.62, g, 1.92)
	m.disc(0.42, 24, pad + Vector3(0, 0.002, 0), Parts.HAZARD)
	m.disc(0.34, 24, pad + Vector3(0, 0.004, 0), _plating(p.tier, ARMOUR))
	_parked_skiff(m, pad + Vector3(0, 0.004, 0), p.tier)
	if level >= 9:
		var ring := pad + Vector3(0, 0.85, 0)
		m.ring(0.3, 0.42, 0.06, 24, ring, HOVER)
		m.lathe(PackedVector2Array([Vector2(0.425, 0.01), Vector2(0.425, 0.05)]), 24, ring, HOVER_RIM)
		m.lathe(PackedVector2Array([Vector2(0.4, 0.062), Vector2(0.32, 0.062)]), 24, ring, HOVER_RIM)
		m.ring(0.16, 0.2, 0.03, 24, ring + Vector3(0, 0.16, 0), HOLO_VIOLET)


## A skiff parked on `foot`, nose to +X: a chamfered hull on landing skids, a glass canopy, two
## engine pods with glowing nozzles, an orange nose and a light strip down its back (_strip), its
## hull chrome at the Chrome tier, obsidian from Obsidian.
static func _parked_skiff(m: LowPolyMesh, foot: Vector3, tier: int) -> void:
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.44, 0.04, 0.05), 0.015, foot + Vector3(0, 0, side * 0.12), Parts.GUNMETAL)
	var hull := foot + Vector3(0, 0.08, 0)
	m.box_chamfered(Vector3(0.56, 0.12, 0.3), 0.04, hull, _plating(tier, Parts.HULL_LIGHT))
	m.box_chamfered(Vector3(0.2, 0.06, 0.16), 0.03, hull + Vector3(0.22, 0.02, 0), ORANGE)
	m.dome(0.1, 0.08, 12, 3, hull + Vector3(0.08, 0.12, 0), Parts.GLASS)
	m.box(Vector3(0.3, 0.015, 0.05), hull + Vector3(-0.12, 0.12, 0), _strip(tier))
	for side: float in [-1.0, 1.0]:
		var pod := hull + Vector3(-0.22, 0.03, side * 0.19)
		m.prism(0.055, 0.05, 0.22, 12, pod, Parts.GUNMETAL, Vector3(0, 0, 90))
		m.disc(0.04, 12, pod + Vector3(-0.221, 0, 0), GLOW_PULSE, Vector3(0, 0, 90))


## The tower's dress from 6, on its shaft from `foot` up `shaft`: four light strips up it
## (cyan, violet veins from the Obsidian tier); from 7 a gallery round it half way up, a second
## from 9; at 10 gold filigree bands round it.
static func _tower_dress(m: LowPolyMesh, foot: Vector3, shaft: float, level: int, tier: int) -> void:
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		m.box(Vector3(0.07, shaft - 0.2, 0.03), foot + Parts.around(0.265, degrees, 0.1), _strip(tier),
			Vector3(0, 90.0 - degrees, 0))
	var galleries: Array[float] = []
	if level >= 7:
		galleries.append(0.45)
	if level >= 9:
		galleries.append(0.75)
	for share: float in galleries:
		var at := foot + Vector3(0, shaft * share, 0)
		m.lathe(PackedVector2Array([
			Vector2(0.28, 0), Vector2(0.48, 0.04), Vector2(0.48, 0.1), Vector2(0.27, 0.1),
		]), 16, at, _plating(tier, ARMOUR_ROUND, true))
		m.lathe(PackedVector2Array([Vector2(0.485, 0.03), Vector2(0.485, 0.08)]), 16, at, _glow(tier))
	if level >= 10:
		for y: float in [0.25, shaft - 0.15]:
			m.lathe(PackedVector2Array([Vector2(0.31, 0), Vector2(0.31, 0.1)]), 16, foot + Vector3(0, y, 0), FILIGREE_ROUND)


## The Crown tier's beacon: a gold spire `height` tall on `foot` under a gold crown of four
## prongs round a violet antimatter core, pulsing.
static func _crown_beacon(m: LowPolyMesh, foot: Vector3, height: float) -> void:
	m.prism(0.06, 0.035, height, 12, foot, GOLD_ROUND)
	var top := foot + Vector3(0, height, 0)
	m.ring(0.05, 0.12, 0.05, 12, top - Vector3(0, 0.03, 0), GOLD_ROUND)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		m.cone(0.03, 0.18, 8, top + Parts.around(0.1, degrees, 0.0), GOLD_ROUND,
			Parts.facing(Parts.around(0.35, degrees, 1.0)))
	m.orb(0.1, 12, 6, top + Vector3(0, 0.12, 0), Parts.CORE_GLOW)


## A surface in the tier's plating: obsidian from the Obsidian tier, chrome at the Chrome tier,
## `base` below it. `smooth` picks the round versions.
static func _plating(tier: int, base: Surf, smooth: bool = false) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN_ROUND if smooth else Parts.OBSIDIAN
	if tier >= Parts.Tier.CHROME:
		return Parts.CHROME_ROUND if smooth else Parts.CHROME
	return base


## A light strip by tier: violet veins from the Obsidian tier, cyan below it.
static func _strip(tier: int) -> Surf:
	return Parts.VEINS if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP


## A band of light by tier: violet from the Obsidian tier, cyan below it.
static func _glow(tier: int) -> Surf:
	return VIOLET_RIB if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP


## A trim by tier: gold filigree at Crown, gold trim from the Gold tier, `base` below it.
static func _trim(tier: int, base: Surf) -> Surf:
	if tier >= Parts.Tier.CROWN:
		return Parts.FILIGREE
	return Parts.GOLD_TRIM if tier >= Parts.Tier.GOLD else base


## A dish on a stub at `foot`, turned to the right of the view, with a glowing feed. One that
## `sweeps` stands on a taller stub, clear of the roof, and swings to and fro about it.
static func _roof_dish(p: Parts, foot: Vector3, radius: float, sweeps: bool) -> void:
	var aim := Vector3(55, 135, 0)
	var stub := 0.42 if sweeps else 0.22
	p.body.prism(0.07, 0.06, stub, 16, foot, Parts.GUNMETAL)
	var m := p.body
	var centre := foot + Vector3(0, stub - 0.02, 0)
	if sweeps:
		m = p.moving(centre, Motion.swing(Vector3.UP, 30.0, 7.0))
		centre = Vector3.ZERO
	Parts.dish(m, radius, radius * 0.38, centre, GOLD_ROUND if p.tier >= Parts.Tier.GOLD else HULL_ROUND, aim)
	var axis := LowPolyMesh.turn(Vector3.UP, aim)
	var focus := centre + axis * radius * 0.85
	Parts.pipe(m, centre + axis * radius * 0.1, focus, 0.025, Parts.ROD)
	m.orb(0.05, 16, 6, focus, GLOW)


## One bay of the hangar: walls, a barrel roof with orange ribs, and the striped door on its
## +Z end. `back` is the middle of its back wall on the pad. A door that `opens` is a moving
## part: it rises behind its lintel and a hood over it, as far as the roof leaves room, and the
## lit bay shows under it. The tier paints it (_hangar's levels): from Chrome a chrome roof
## with cyan ribs and a cyan strip along its +X wall; from Obsidian obsidian walls, veined door
## leaves and ribs glowing violet; at Crown an obsidian roof under filigree ribs, and from 10 the
## antimatter core glowing in a broad band along its crest and a filigree banner with a violet
## emblem on a gable wide enough for it.
static func _vault(p: Parts, back: Vector3, width: float, length: float, wall: float,
		door: float, opens: bool, level: int) -> void:
	var m := p.body
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var radius := width * 0.5 - 0.005
	var front := back.z + length
	m.box_chamfered(Vector3(width, wall, length + 0.02), 0.06, back + Vector3(0, 0, length * 0.5 + 0.01),
		Parts.OBSIDIAN if obsidian else ARMOUR)
	var axis := back + Vector3(0, wall, 0)
	# The barrel roof: the half of a cylinder lying along +Z that stands above the walls,
	# which, turned so, is 180 to 360 degrees round its own axis.
	var roof := Parts.OBSIDIAN_ROUND if crown else (Parts.CHROME_ROUND if chrome else HULL_ROUND)
	m.prism(radius, radius, length, 24, axis, roof, Vector3(90, 0, 0), 180.0, 360.0)
	var gable := PackedVector3Array()
	for k: int in 13:
		var angle := PI * k / 12
		gable.append(axis + Vector3(radius * cos(angle), radius * sin(angle), length + 0.012))
	m.polygon(gable, Parts.OBSIDIAN if crown else (Parts.CHROME if chrome else Parts.HULL_LIGHT))
	var rib := ORANGE_ROUND
	if crown:
		rib = FILIGREE_ROUND
	elif obsidian:
		rib = VIOLET_RIB
	elif chrome:
		rib = Parts.CYAN_STRIP
	for k: int in 3:
		var rib_z := back.z + length * (0.18 + 0.32 * k)
		m.ring(radius - 0.02, radius + 0.07, 0.14, 24, Vector3(back.x, axis.y, rib_z), rib.phased(k / 3.0) if obsidian and not crown else rib,
			Vector3(90, 0, 0))
	if chrome:
		m.box(Vector3(0.02, 0.07, length - 0.1), Vector3(back.x + width * 0.5 + 0.005, back.y + wall - 0.17, back.z + length * 0.5),
			_glow(p.tier))
	# The door: leaves with a hazard band, hazard posts, a lintel and a glow strip.
	var post := door * 0.5 + 0.08
	var height := wall + sqrt(radius * radius - (post + 0.08) * (post + 0.08)) - 0.2
	var z := front + 0.02
	var leaves := m
	var at := Vector3(back.x, back.y, z)
	var strip := back.y + height + 0.22
	var above := strip + 0.03
	if opens:
		# The hood over the lintel reaches as high as the roof allows over the door's corners;
		# the door stands a little proud of the lit inside, and rises to the hood's top.
		var corner := door * 0.5 + 0.04
		var hood := back.y + wall + sqrt(radius * radius - corner * corner) - 0.03
		var rise := hood - back.y - height - 0.04
		m.box_chamfered(Vector3(door + 0.04, hood - back.y - height - 0.14, 0.16), 0.03,
			Vector3(back.x, back.y + height + 0.14, z + 0.08), ARMOUR)
		m.box(Vector3(door, rise + 0.06, 0.008), Vector3(back.x, back.y, z + 0.006), INTERIOR)
		strip = (back.y + height + 0.14 + hood) * 0.5 - 0.03
		above = hood
		leaves = p.moving(at + Vector3(0, rise * 0.5, 0), Motion.slide(Vector3.UP, rise * 0.5, 6.0))
		at = Vector3(0, 0, 0.015)
	var leaf := door / 4.0
	for i: int in 4:
		var x := -door * 0.5 + leaf * (i + 0.5)
		leaves.box_chamfered(Vector3(leaf - 0.03, height, 0.08), 0.02, at + Vector3(x, 0, 0.04), Parts.VEINS if obsidian else DARK_PLATE)
	leaves.box_chamfered(Vector3(door, 0.26, 0.1), 0.03, at + Vector3(0, 0, 0.05), Parts.HAZARD)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.16, height + 0.14, 0.16), 0.04, Vector3(back.x + side * post, back.y, z + 0.08),
			Parts.HAZARD)
	m.box_chamfered(Vector3(door + 0.32, 0.14, 0.18), 0.04, Vector3(back.x, back.y + height, z + 0.09),
		Parts.GOLD_TRIM if p.tier >= Parts.Tier.GOLD else ORANGE)
	m.box(Vector3(door * 0.6, 0.06, 0.04), Vector3(back.x, strip, z + (0.15 if opens else 0.0)), GLOW)
	var crest := axis.y + radius
	if level >= 10:
		# The antimatter core's glow along the roof's crest: a band of the barrel 16 degrees wide,
		# just proud of it, under the ribs.
		m.prism(radius + 0.012, radius + 0.012, length - 0.1, 24, axis + Vector3(0, 0, 0.05), BRIGHT_CORE,
			Vector3(90, 0, 0), 262.0, 278.0)
	if level >= 10 and crest - above >= 0.3:
		# A filigree banner on the gable over the door, a violet emblem glowing on it.
		var tall := crest - above - 0.12
		var wide := minf(0.5, 2.0 * sqrt(radius * radius - (above + 0.04 - axis.y) * (above + 0.04 - axis.y)) - 0.2)
		var banner := Vector3(back.x, above + 0.04, z)
		m.box(Vector3(wide, tall, 0.025), banner, Parts.FILIGREE)
		m.prism(0.08, 0.08, 0.02, 12, banner + Vector3(0, tall * 0.5, 0.0125), Parts.CORE_GLOW, Vector3(90, 0, 0))


## A training ground for human cadets: a barracks hall along the back of a drill yard, a parade
## plinth in the yard with a hologram cadet standing to attention over it, a flagpole flying a
## stiff orange pennant, holographic target posts down one side. A taller hall with a second row
## of windows and a gimballed flight-simulator pod at 2, a lecture room with an armour skirt on
## the hall's roof and a drill grid on the yard at 3, a watchtower, corner armour and a fourth
## target at 4, an armour plate on the lecture room's end and gold at 5. The bunk windows pulse
## on their own phases, the targets blink on in turn, the cadet bobs and turns slowly over the
## plinth's pulsing lens and the finial lamp blinks; from 2 the pod's gimbal rings spin, from 3
## the lecture room's board scrolls and the drill grid flickers, from 4 the tower's searchlight
## sweeps the yard. At 5 the cadet salutes under a hologram halo and the pennant's crest glows.
##
## From 6 the watchtower grows taller at each level and its searchlight is cyan: L6 a chrome hall
## with a cyan band between its window rows, a chrome plinth, lecture room and tower with cyan
## strips up it, a second simulator pod behind the plinth's left (its rings still) and a second
## column of target posts in front of it, a post more at each level to 8; L7 a third storey on
## the hall, a cyan window band across it;
## L8 an obsidian hall and tower, violet vein strips down the hall's front, the third storey's
## band glowing violet, the drill grid violet and crystal shards on the tower; L9 a drill drone
## hovering over the yard, an obsidian saucer rimmed in violet over a hologram scan cone; L10
## gold filigree on the hall's trims and round the plinth, the band glowing the antimatter core's
## light violet, a gold ring round the cadet's feet and a solid light-violet halo over it, a violet
## core beacon on the tower, and two troopers marching round a gold parade circle in the yard's
## front corner as its escort.
static func build_cadet_academy(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	Parts.foundation(m, 3)
	# The hall along the back, its front face at z = front.
	var height := 0.75 if level < 2 else 1.0
	var front := -0.62
	m.box_chamfered(Vector3(2.6, height, 0.7), 0.06, Vector3(0, g, front - 0.35), _plating(p.tier, Parts.HULL_LIGHT))
	var roof := g + height
	m.box_chamfered(Vector3(2.62, 0.08, 0.1), 0.02, Vector3(0, roof - 0.08, front), _trim(p.tier, DARK_PLATE))
	# The orange roller door between hazard posts, a glow strip over it.
	m.box_chamfered(Vector3(0.5, 0.5, 0.06), 0.02, Vector3(0, g, front), ROLLER)
	m.box(Vector3(0.5, 0.05, 0.04), Vector3(0, g + 0.53, front + 0.01), GLOW)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.08, 0.6, 0.08), 0.02, Vector3(side * 0.3, g, front + 0.02), Parts.HAZARD)
	# The bunk windows, a row more at 2.
	var rows: Array[float] = [0.3]
	if level >= 2:
		rows.append(0.6)
	var k := 0
	for y: float in rows:
		for x: float in [-1.05, -0.75, -0.45, 0.45, 0.75, 1.05]:
			m.box(Vector3(0.18, 0.12, 0.02), Vector3(x, g + y, front + 0.005),
				WINDOW_GLOW.phased(fposmod(0.37 * k, 1.0)))
			k += 1
	if level >= 4:
		# Armour plates round the hall's front corners.
		for side: float in [-1.0, 1.0]:
			m.box_chamfered(Vector3(0.1, height - 0.12, 0.4), 0.03, Vector3(side * 1.3, g, front - 0.16), ARMOUR)
	if level >= 6:
		# A band of light between the window rows; from the Obsidian tier vein strips down the
		# front between the windows.
		m.box(Vector3(2.4, 0.05, 0.02), Vector3(0, g + 0.48, front + 0.005), _glow(p.tier))
		if obsidian:
			for x: float in [-1.2, -0.9, -0.6, 0.6, 0.9, 1.2]:
				m.box(Vector3(0.06, height - 0.12, 0.02), Vector3(x, g + 0.03, front + 0.006), Parts.VEINS)
	if level >= 7:
		# The third storey, a broad window band across its front.
		m.box_chamfered(Vector3(2.5, 0.4, 0.66), 0.05, Vector3(0, roof, front - 0.35), _plating(p.tier, Parts.HULL_LIGHT))
		var band := Parts.CYAN_STRIP
		if p.tier >= Parts.Tier.CROWN:
			band = BRIGHT_CORE
		elif obsidian:
			band = VIOLET_PANEL
		m.box(Vector3(2.2, 0.16, 0.02), Vector3(0, roof + 0.1, front - 0.015), band)
		m.box_chamfered(Vector3(2.54, 0.07, 0.1), 0.02, Vector3(0, roof + 0.33, front - 0.03), _trim(p.tier, DARK_PLATE))
		roof += 0.4
	# The roof: a vent (on the lecture room from 3) and the loudspeaker horn facing the yard.
	var horn := Vector3(0.55, roof, -0.85)
	m.prism(0.03, 0.025, 0.26, 8, horn, Parts.GUNMETAL)
	var blare := Vector3(0, -0.25, 1).normalized()
	m.prism(0.025, 0.08, 0.14, 10, horn + Vector3(0, 0.24, 0), Parts.GUNMETAL, Parts.facing(blare))
	m.disc(0.07, 10, horn + Vector3(0, 0.24, 0) + blare * 0.142, DARK_PLATE, Parts.facing(blare))
	if level >= 3:
		# The lecture room: a glass band and a scrolling screen board on its front, antennas on top.
		var room := Vector3(-0.45, roof, -1.02)
		m.box_chamfered(Vector3(1.5, 0.45, 0.52), 0.05, room, Parts.CHROME if chrome else Parts.HULL_LIGHT)
		m.box_chamfered(Vector3(0.8, 0.12, 0.03), 0.01, room + Vector3(-0.28, 0.24, 0.26), Parts.GLASS)
		m.box_chamfered(Vector3(0.42, 0.26, 0.04), 0.015, room + Vector3(0.42, 0.1, 0.27), SCREEN_FLOW.phased(0.7))
		m.box_chamfered(Vector3(0.36, 0.12, 0.26), 0.04, room + Vector3(-0.4, 0.45, -0.03), VENT)
		# An armour skirt along its front, and at 5 a plate over its end.
		m.box_chamfered(Vector3(1.54, 0.09, 0.06), 0.02, room + Vector3(0, 0, 0.27), ARMOUR)
		if level >= 5:
			m.box_chamfered(Vector3(0.06, 0.36, 0.42), 0.02, room + Vector3(0.77, 0, 0), ARMOUR)
		_whip(m, room + Vector3(0.45, 0.45, -0.08), 0.5, GLOW)
		_whip(m, room + Vector3(-0.05, 0.45, 0.06), 0.35, GLOW)
	else:
		m.box_chamfered(Vector3(0.36, 0.12, 0.26), 0.04, Vector3(-0.6, roof, -1.05), VENT)
	# The drill yard: a dark floor with a hazard kerb along its front.
	m.box_chamfered(Vector3(2.5, 0.03, 1.82), 0.015, Vector3(0, g, 0.3), DARK_PLATE)
	var yard := g + 0.03
	m.box_chamfered(Vector3(2.6, 0.08, 0.1), 0.02, Vector3(0, g, 1.27), Parts.HAZARD)
	if level >= 3:
		# The drill grid flickering on the yard's floor.
		var grid := VIOLET_GRID if obsidian else DRILL_GRID
		for i: int in 4:
			_line(m, Vector2(1.4, 0.03), Vector3(-0.15, yard + 0.003, -0.35 + 0.4 * i), grid.phased(i / 8.0))
			_line(m, Vector2(0.03, 1.2), Vector3(-0.85 + 0.47 * i, yard + 0.003, 0.25),
				grid.phased((i + 4) / 8.0))
	# The target posts down the left side, their silhouettes blinking on in turn.
	var posts := 3 if level < 4 else 4
	for i: int in posts:
		var foot := Vector3(-1.12, yard, -0.42 + 0.38 * i)
		m.box_chamfered(Vector3(0.16, 0.06, 0.16), 0.02, foot, Parts.GUNMETAL)
		m.prism(0.025, 0.02, 0.3, 8, foot + Vector3(0, 0.06, 0), Parts.ROD)
		var lit := TARGET.phased(Parts.chase(i, posts))
		m.box(Vector3(0.02, 0.22, 0.18), foot + Vector3(0, 0.36, 0), lit)
		m.box(Vector3(0.02, 0.09, 0.09), foot + Vector3(0, 0.6, 0), lit)
	if level >= 6:
		# A second column of posts in front of the second pod, a post more at each level to 8.
		var more := mini(level - 4, 4)
		for i: int in more:
			var foot := Vector3(-0.78, yard, 0.2 + 0.25 * i)
			m.box_chamfered(Vector3(0.16, 0.06, 0.16), 0.02, foot, _plating(p.tier, Parts.GUNMETAL))
			m.prism(0.025, 0.02, 0.3, 8, foot + Vector3(0, 0.06, 0), Parts.ROD)
			var lit := TARGET.phased(Parts.chase(more - 1 - i, more))
			m.box(Vector3(0.02, 0.22, 0.18), foot + Vector3(0, 0.36, 0), lit)
			m.box(Vector3(0.02, 0.09, 0.09), foot + Vector3(0, 0.6, 0), lit)
	# The parade plinth: an armoured octagon with a rim and a projector lens, the cadet over it.
	var plinth := Vector3(0, yard, 0.3)
	Parts.drum(m, 0.32, 0.2, 0.05, 8, plinth, Parts.CHROME if chrome else ARMOUR, Parts.OCTAGON)
	var top := plinth + Vector3(0, 0.2, 0)
	Parts.drum(m, 0.34, 0.05, 0.02, 8, top - Vector3(0, 0.04, 0), Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT,
		Parts.OCTAGON)
	m.dome(0.1, 0.05, 10, 3, top + Vector3(0, 0.01, 0), GLOW_PULSE)
	if level >= 10:
		# Filigree round the plinth, a gold ring round the cadet's feet.
		m.lathe(PackedVector2Array([Vector2(0.33, 0), Vector2(0.33, 0.08)]), 8, plinth + Vector3(0, 0.05, 0), Parts.FILIGREE,
			Parts.OCTAGON)
		Parts.torus(m, 0.2, 0.025, 16, 6, top + Vector3(0, 0.01, 0), GOLD_ROUND)
	_cadet(p, top + Vector3(0, 0.14, 0), level)
	# The flagpole in the front corner, its finial lamp blinking, the pennant flying over the yard.
	var pole := Vector3(-1.15, yard, 1.08)
	m.box_chamfered(Vector3(0.18, 0.08, 0.18), 0.03, pole, ARMOUR)
	var rise := 1.25 + 0.07 * level
	_whip(m, pole + Vector3(0, 0.08, 0), rise, LAMP)
	var head := pole + Vector3(0, 0.08 + rise, 0)
	m.prism(0.045, 0.035, 0.05, 8, head - Vector3(0, 0.1, 0), GOLD_ROUND if gold else Parts.GUNMETAL)
	_pennant(m, head + Vector3(0.02, -0.12, 0), 0.5, 0.26, level)
	if level >= 2:
		_simulator(p, Vector3(0.92, yard, -0.05))
	if level >= 4:
		_watchtower(p, Vector3(1.0, roof, -1.0), level)
	if level >= 6:
		# The second pod behind the plinth's left, so the yard's front stays open.
		_simulator(p, Vector3(-0.62, yard, -0.25), false)
	if level >= 9:
		_drill_drone(m, Vector3(-0.35, yard + 1.05, 0.95))
	if level >= 10:
		# A gold parade circle inlaid in the yard's front corner, nearest the camera, the core
		# glowing at its middle, and the two troopers marching round it.
		var parade := Vector3(0.65, yard, 0.88)
		m.disc(0.2, 24, parade + Vector3(0, 0.003, 0), Parts.FILIGREE)
		m.disc(0.09, 16, parade + Vector3(0, 0.006, 0), BRIGHT_CORE)
		Parts.escort_troopers(p, 0.28, yard, 0.5, parade)


## The hologram cadet standing to attention, its feet on `foot`, built facing +Z: boots and legs,
## a chunky torso, arms at its sides, a round head under a peaked cap, all bobbing together. A
## moving part, it turns slowly about the vertical through its feet, a hologram's showcase turn.
## From 5 its right arm salutes and a halo floats over it out of step, at Crown a solid one in the
## core's light violet. A hologram is never inked, so its boxes go without chamfers, and the part
## has no outline but the Crown halo's.
static func _cadet(p: Parts, foot: Vector3, level: int) -> void:
	const K := 1.3
	var m := p.moving(foot, Motion.spin(Vector3.UP, 0.5))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.08, 0.2, 0.09) * K, Vector3(side * 0.05, 0, 0) * K, HOLOGRAM)
	m.box(Vector3(0.22, 0.2, 0.13) * K, Vector3(0, 0.2, 0) * K, HOLOGRAM)
	m.box(Vector3(0.06, 0.19, 0.07) * K, Vector3(0.145, 0.2, 0) * K, HOLOGRAM)
	if level >= 5:
		var elbow := Vector3(-0.24, 0.38, 0.05) * K
		m.strut(Vector3(-0.12, 0.37, 0) * K, elbow, 0.06 * K, HOLOGRAM)
		m.strut(elbow, Vector3(-0.06, 0.5, 0.07) * K, 0.055 * K, HOLOGRAM)
		if p.tier >= Parts.Tier.CROWN:
			m.ring(0.09 * K, 0.13 * K, 0.035, 12, Vector3(0, 0.64, 0) * K, BRIGHT_HALO)
		else:
			m.ring(0.09 * K, 0.12 * K, 0.02, 12, Vector3(0, 0.64, 0) * K, HOLOGRAM.phased(0.5))
	else:
		m.box(Vector3(0.06, 0.19, 0.07) * K, Vector3(-0.145, 0.2, 0) * K, HOLOGRAM)
	m.orb(0.07 * K, 12, 4, Vector3(0, 0.47, 0) * K, HOLOGRAM)
	Parts.drum(m, 0.078 * K, 0.04 * K, 0.01, 12, Vector3(0, 0.5, 0) * K, HOLOGRAM)
	m.box(Vector3(0.1, 0.015, 0.05) * K, Vector3(0, 0.5, 0.07) * K, HOLOGRAM)


## A stiff pennant flying from `root` on its pole towards +X: a triangle `length` long, its
## top edge level with the root and `depth` deep at the pole, its tip drooping a little. Its
## crest glows on both faces at the top level.
static func _pennant(m: LowPolyMesh, root: Vector3, length: float, depth: float, level: int) -> void:
	var t := Vector3(0, 0, 0.012)
	var a := root
	var b := root - Vector3(0, depth, 0)
	var c := root + Vector3(length, -depth * 0.4, 0)
	m.polygon(PackedVector3Array([a + t, b + t, c + t]), ORANGE)
	m.polygon(PackedVector3Array([a - t, c - t, b - t]), ORANGE)
	m.polygon(PackedVector3Array([a + t, c + t, c - t, a - t]), ORANGE)
	m.polygon(PackedVector3Array([b - t, c - t, c + t, b + t]), ORANGE)
	if level >= 5:
		var crest := root + Vector3(length * 0.3, -depth * 0.45, 0)
		m.disc(0.05, 12, crest + Vector3(0, 0, 0.015), GLOW_PULSE, Vector3(90, 0, 0))
		m.disc(0.05, 12, crest - Vector3(0, 0, 0.015), GLOW_PULSE, Vector3(-90, 0, 0))


## A whip antenna on a little foot at `foot`: a thin rod `height` tall ending in a small bulb on
## `bulb`, which carries the outline the rod is too thin for. Lighter than Parts.mast's bulb.
static func _whip(m: LowPolyMesh, foot: Vector3, height: float, bulb: Surf) -> void:
	m.prism(0.03, 0.022, height, 8, foot, Parts.ROD)
	m.orb(0.05, 10, 4, foot + Vector3(0, height, 0), bulb)


## A flat strip `size` across facing up at `pos`: a line of the drill grid, two triangles.
static func _line(m: LowPolyMesh, size: Vector2, pos: Vector3, surface: Surf) -> void:
	var h := size * 0.5
	m.polygon(PackedVector3Array([
		pos + Vector3(-h.x, 0, -h.y), pos + Vector3(-h.x, 0, h.y), pos + Vector3(h.x, 0, h.y),
		pos + Vector3(h.x, 0, -h.y),
	]), surface)


## The flight simulator standing on `foot`: a dark pod with a pulsing canopy on a stub, held in
## two gimbal rings that spin about a tilted axis, unless it `spins` not (the second pod's are
## part of the body). Tilted 45 degrees, the rings never come within 0.19 of the stub. Its base
## and rings are chrome from the Chrome tier.
static func _simulator(p: Parts, foot: Vector3, spins: bool = true) -> void:
	var m := p.body
	var plated := Parts.CHROME_ROUND if p.tier >= Parts.Tier.CHROME else ARMOUR_ROUND
	Parts.drum(m, 0.2, 0.1, 0.03, 16, foot, plated)
	m.prism(0.06, 0.05, 0.26, 8, foot + Vector3(0, 0.1, 0), Parts.GUNMETAL)
	var centre := foot + Vector3(0, 0.54, 0)
	m.orb(0.22, 16, 6, centre, Parts.HULL_DARK_ROUND)
	var view := Vector3(0.5, 0.25, 0.85).normalized()
	m.dome(0.12, 0.05, 16, 3, centre + view * 0.205, CAB_GLASS, Parts.facing(view))
	var rings := p.moving(centre, Motion.spin(Vector3(0.2, 1, 0.1), 0.9)) if spins else m
	var at := Vector3.ZERO if spins else centre
	for spec: Array in [[0.36, Vector3(45, 0, 0)], [0.3, Vector3(0, 0, -45)]]:
		var radius: float = spec[0]
		var tilt: Vector3 = spec[1]
		rings.tube(radius - 0.035, radius, 0.04, 24, at - LowPolyMesh.turn(Vector3(0, 0.02, 0), tilt),
			plated, tilt)


## The watchtower on the hall's roof at `foot`: an armoured base, a round shaft, a cab with
## pulsing glass under a crown (gold from the Gold tier), a small dish on its flank, and the
## searchlight on the crown sweeping the yard, its lens pulsing and a hologram beam out of it.
## From 6 its shaft grows 0.15 a level with light strips up it, its beam longer and both cyan;
## the tier plates it; from 8 crystal shards on its crown, at 10 a core beacon.
static func _watchtower(p: Parts, foot: Vector3, level: int) -> void:
	var m := p.body
	var grown := 0.15 * maxi(level - 5, 0)
	m.box_chamfered(Vector3(0.36, 0.08, 0.36), 0.03, foot, _plating(p.tier, ARMOUR))
	m.prism(0.13, 0.11, 0.6 + grown, 16, foot + Vector3(0, 0.08, 0), _plating(p.tier, MID_ROUND, true))
	if level >= 6:
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.box(Vector3(0.04, 0.5 + grown, 0.02), foot + Parts.around(0.12, degrees, 0.13), _strip(p.tier),
				Vector3(0, 90.0 - degrees, 0))
	var cab := foot + Vector3(0, 0.68 + grown, 0)
	m.box_chamfered(Vector3(0.36, 0.2, 0.36), 0.04, cab, _plating(p.tier, ARMOUR))
	m.box_chamfered(Vector3(0.28, 0.08, 0.02), 0.01, cab + Vector3(0, 0.07, 0.18), CAB_GLASS)
	m.box_chamfered(Vector3(0.02, 0.08, 0.28), 0.01, cab + Vector3(0.18, 0.07, 0), CAB_GLASS)
	m.box_chamfered(Vector3(0.4, 0.05, 0.4), 0.02, cab + Vector3(0, 0.2, 0),
		Parts.GOLD_TRIM if p.tier >= Parts.Tier.GOLD else DARK_PLATE)
	var aim := Vector3(-0.6, 0.75, 0.2)
	Parts.dish(m, 0.13, 0.05, cab + Vector3(-0.2, 0.08, 0), HULL_ROUND, Parts.facing(aim))
	if level >= 8:
		for z: float in [-0.13, 0.13]:
			m.cone(0.05, 0.2, 8, cab + Vector3(0.13, 0.25, z), INLAY.phased(0.5 + z), Parts.facing(Vector3(0.3, 1, z)))
	if level >= 10:
		_crown_beacon(m, cab + Vector3(-0.13, 0.25, -0.13), 0.4)
	var light := p.moving(cab + Vector3(0, 0.25, 0), Motion.swing(Vector3.UP, 25.0, 6.0))
	light.prism(0.05, 0.05, 0.06, 8, Vector3.ZERO, Parts.GUNMETAL)
	var beam := Vector3(-1.0, -1.9, 1.3).normalized()
	var lamp := Vector3(0, 0.12, 0)
	var cyan := p.tier >= Parts.Tier.CHROME
	Parts.drum(light, 0.08, 0.14, 0.02, 12, lamp - beam * 0.06, Parts.GUNMETAL, Parts.facing(beam))
	light.disc(0.065, 16, lamp + beam * 0.085, CYAN_LENS if cyan else SEARCH_LENS, Parts.facing(beam))
	# At 4 and 5, where the tower stands lowest, the beam stops short of the simulator's rings.
	var reach := 1.25 if level < 6 else 1.4 + grown * 0.6
	light.prism(0.06, 0.16, reach, 12, lamp + beam * 0.09, CYAN_BEAM if cyan else SEARCH_BEAM, Parts.facing(beam))


## The drill drone hovering over the yard from 9, `at` its centre: an obsidian saucer rimmed in
## violet with a glass canopy, a cyan eye to the camera and four rotor pods with violet discs,
## over a violet hologram scan cone, every part bobbing together (HOVER's phase).
static func _drill_drone(m: LowPolyMesh, at: Vector3) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0, -0.05), Vector2(0.15, -0.05), Vector2(0.21, -0.01), Vector2(0.19, 0.04), Vector2(0, 0.05),
	]), 16, at, HOVER)
	m.lathe(PackedVector2Array([Vector2(0.215, -0.02), Vector2(0.215, 0.015)]), 16, at, HOVER_RIM)
	m.dome(0.09, 0.08, 12, 3, at + Vector3(0, 0.045, 0), DRONE_GLASS)
	m.box(Vector3(0.1, 0.035, 0.03), at + Parts.around(0.2, 45.0, -0.03), DRONE_EYE, Vector3(0, 45, 0))
	for k: int in 4:
		var degrees := 90.0 * k
		m.box(Vector3(0.14, 0.03, 0.04), at + Parts.around(0.24, degrees, -0.015), HOVER, Vector3(0, -degrees, 0))
		var pod := at + Parts.around(0.3, degrees, -0.03)
		m.prism(0.07, 0.065, 0.05, 12, pod, HOVER)
		m.disc(0.06, 12, pod + Vector3(0, 0.052, 0), HOVER_RIM)
	m.prism(0.16, 0.04, 0.62, 12, at - Vector3(0, 0.68, 0), HOLO_VIOLET.phased(0.6))


## A factory block under a sawtooth roof, smokestacks on a furnace box behind it, a conveyor
## out to a loading dock under an orange gantry crane. More stacks at 3 and 5, a second storey
## at 4. The roof windows pulse orange, the crane's trolley runs to and fro along its bridge
## with the hook, the dock's lamp blinks and the stacks puff smoke.
##
## From 6 the stacks stand taller with chrome collars: L6 a chrome block, storey and sawtooth
## roof, chrome roller doors and cyan lamps chasing along the conveyor; L7 a second gantry crane
## over crates in the front yard, its trolley running too; L8 an obsidian sawtooth roof and
## storey, violet panels glowing on the storey, obsidian armour on the block's side and along its
## front's top, the furnace box obsidian with violet veins on its faces and a violet band round
## its top, the smoke crystal-lit; L9 crystal inlays on the armour and an assembler ring
## hovering over the dock, obsidian rimmed in violet; L10 gold filigree over the sawtooth roof and
## the cranes' bridges, the antimatter core glowing as a bright orb between gold prongs on the
## storey's roofline.
static func build_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	Parts.foundation(m, 3)
	var roof := g + 0.8
	var hull := Parts.CHROME if chrome else Parts.HULL_LIGHT
	m.box_chamfered(Vector3(1.7, 0.8, 1.6), 0.06, Vector3(-0.45, g, -0.5), hull)
	var saw := MID_ROUND
	if p.tier >= Parts.Tier.CROWN:
		saw = Parts.FILIGREE
	elif obsidian:
		saw = Parts.OBSIDIAN_ROUND
	elif chrome:
		saw = Parts.CHROME_ROUND
	for k: int in 2:
		var z := -0.6 + 0.45 * k
		m.wedge(Vector3(1.6, 0.3, 0.45), Vector3(-0.45, roof, z + 0.225), saw, Vector3(0, 180, 0))
		m.box(Vector3(1.45, 0.2, 0.03), Vector3(-0.45, roof + 0.04, z + 0.465), WINDOW_GLOW.phased(0.5 * k))
	if level >= 4:
		var storey := Vector3(-0.45, roof, -0.95)
		m.box_chamfered(Vector3(1.6, 0.5, 0.65), 0.06, storey, Parts.OBSIDIAN if obsidian else hull)
		m.box(Vector3(1.3, 0.14, 0.03), storey + Vector3(0, 0.22, 0.33), GLOW)
		if obsidian:
			m.box(Vector3(1.3, 0.08, 0.03), storey + Vector3(0, 0.08, 0.33), VIOLET_PANEL)
			m.box(Vector3(0.03, 0.3, 0.5), storey + Vector3(0.8, 0.1, 0), VIOLET_PANEL)
		m.box_chamfered(Vector3(0.4, 0.14, 0.3), 0.04, storey + Vector3(-0.35, 0.5, 0), VENT)
	else:
		m.box_chamfered(Vector3(0.4, 0.14, 0.3), 0.04, Vector3(-0.8, roof, -0.95), VENT)
	# The front: an orange roller door and windows.
	m.box_chamfered(Vector3(0.62, 0.56, 0.06), 0.02, Vector3(-0.8, g, 0.32), CHROME_ROLLER if chrome else ROLLER)
	m.box(Vector3(0.7, 0.05, 0.04), Vector3(-0.8, g + 0.62, 0.32), GLOW)
	for x: float in [-0.2, 0.17]:
		m.box_chamfered(Vector3(0.26, 0.24, 0.04), 0.02, Vector3(x, g + 0.32, 0.31), Parts.GLASS)
	if level >= 2:
		for x: float in [-1.26, 0.36]:
			m.box_chamfered(Vector3(0.1, 0.7, 0.1), 0.03, Vector3(x, g, 0.3), ARMOUR)
	if level >= 8:
		# Obsidian armour: plates down the block's side either side of a vein strip, a parapet
		# along its front's top over a violet band; crystal inlays on the plates from 9.
		for z: float in [-1.0, -0.62]:
			m.box_chamfered(Vector3(0.06, 0.62, 0.3), 0.02, Vector3(0.43, g + 0.1, z), Parts.OBSIDIAN)
			if level >= 9:
				m.prism(0.07, 0.07, 0.03, 4, Vector3(0.46, g + 0.5, z), INLAY.phased(0.5 + z), Vector3(90, 90, 0))
		m.box(Vector3(0.02, 0.62, 0.06), Vector3(0.425, g + 0.1, -0.81), Parts.VEINS)
		m.box_chamfered(Vector3(1.74, 0.1, 0.08), 0.02, Vector3(-0.45, roof - 0.1, 0.32), Parts.OBSIDIAN)
		m.box(Vector3(1.4, 0.04, 0.02), Vector3(-0.45, roof - 0.15, 0.34), VIOLET_RIB)
	# The conveyor from a hatch in the side wall out over the dock.
	m.box_chamfered(Vector3(0.06, 0.34, 0.4), 0.02, Vector3(0.42, g + 0.12, -0.15), DARK_PLATE)
	m.box_chamfered(Vector3(0.9, 0.08, 0.28), 0.02, Vector3(0.85, g + 0.3, -0.15), BELT)
	for x: float in [0.65, 1.15]:
		m.box_chamfered(Vector3(0.08, 0.3, 0.2), 0.02, Vector3(x, g, -0.15), Parts.GUNMETAL)
	m.box_chamfered(Vector3(0.18, 0.16, 0.18), 0.03, Vector3(0.75, g + 0.38, -0.15), ORANGE)
	if level >= 6:
		# Cyan lamps chasing out along the belt's side.
		for i: int in 5:
			m.box_chamfered(Vector3(0.08, 0.05, 0.03), 0.01, Vector3(0.5 + 0.17 * i, g + 0.32, 0.005),
				CYAN_LAMP.phased(Parts.chase(i, 5)))
	# The loading dock and its crates.
	m.box_chamfered(Vector3(0.8, 0.2, 0.95), 0.04, Vector3(0.9, g, 0.8), ARMOUR)
	m.box(Vector3(0.8, 0.04, 0.12), Vector3(0.9, g + 0.2, 1.21), Parts.HAZARD)
	var crates: Array[Vector3] = [Vector3(0.75, 0, 0.55), Vector3(1.05, 0, 0.62), Vector3(0.8, 0, 0.9)]
	for i: int in mini(level + 1, 3):
		m.box_chamfered(Vector3(0.22, 0.2, 0.22), 0.03, crates[i] + Vector3(0, g + 0.2, 0), ORANGE)
	Parts.landing_light(m, Vector3(1.2, g + 0.2, 1.07), 0.06, LAMP)
	# The gantry crane over the dock.
	var top := g + 1.25
	for x: float in [0.57, 1.23]:
		for z: float in [0.4, 1.2]:
			m.box_chamfered(Vector3(0.08, top - g - 0.2, 0.08), 0.02, Vector3(x, g + 0.2, z), ORANGE)
		Parts.beam(m, Vector3(x, top, 0.33), Vector3(x, top, 1.27), 0.1, ORANGE)
	var bridge := 0.85
	Parts.beam(m, Vector3(0.5, top + 0.1, bridge), Vector3(1.3, top + 0.1, bridge), 0.1, _trim(p.tier, Parts.HULL_DARK))
	# The trolley rides on the bridge, its hook hanging through it, from rail to rail.
	var trolley := p.moving(Vector3(0.9, top, bridge), Motion.slide(Vector3.RIGHT, 0.25, 5.0))
	trolley.box_chamfered(Vector3(0.2, 0.12, 0.18), 0.03, Vector3(0, 0.15, 0), Parts.GUNMETAL)
	trolley.prism(0.012, 0.012, 0.52, 8, Vector3(0, -0.37, 0), Parts.ROD)
	trolley.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Vector3(0, -0.43, 0), Parts.HAZARD)
	if level >= 7:
		_yard_crane(p)
	if level >= 9:
		# The assembler ring hovering over the dock, between the crates and the hook.
		var ring := Vector3(0.9, g + 0.62, 0.8)
		m.ring(0.26, 0.36, 0.06, 24, ring, HOVER)
		m.lathe(PackedVector2Array([Vector2(0.365, 0.01), Vector2(0.365, 0.05)]), 24, ring, HOVER_RIM)
		m.lathe(PackedVector2Array([Vector2(0.34, 0.062), Vector2(0.28, 0.062)]), 24, ring, HOVER_RIM)
	# Smokestacks on the furnace box.
	var furnace := Vector3(0.92, g, -0.92)
	m.box_chamfered(Vector3(0.75, 0.35, 0.7), 0.05, furnace, Parts.OBSIDIAN if obsidian else DARK_PLATE)
	if obsidian:
		# Violet veins on the faces the camera sees, a violet band round the top.
		m.box(Vector3(0.6, 0.24, 0.02), furnace + Vector3(0, 0.05, 0.355), Parts.VEINS)
		m.box(Vector3(0.02, 0.24, 0.55), furnace + Vector3(0.38, 0.05, 0), Parts.VEINS)
		m.lathe(PackedVector2Array([Vector2(0.52, 0), Vector2(0.52, 0.05)]), 4, furnace + Vector3(0, 0.27, 0), VIOLET_RIB,
			Vector3(0, 45, 0))
	var stacks: Array[Vector3] = [
		Vector3(0.75, 0, -1.08), Vector3(1.1, 0, -0.78), Vector3(1.1, 0, -1.12), Vector3(0.72, 0, -0.72),
	]
	var counts: Array[int] = [2, 2, 3, 3, 4]
	for i: int in counts[mini(level, 5) - 1]:
		var height := 1.2 - 0.18 * i + 0.05 * level + (0.25 if level >= 6 else 0.0)
		var foot := stacks[i] + Vector3(0, g + 0.35, 0)
		_stack(m, foot, 0.13, height, p.tier >= Parts.Tier.GOLD, Parts.CHROME_ROUND if level >= 6 else null)
		if obsidian:
			_crystal_puffs(m, foot + Vector3(0, height, 0), 0.29 * i)
		else:
			Parts.puffs(m, foot + Vector3(0, height, 0), 0.29 * i)
	if level >= 10:
		# The core furnace on the storey's roofline: the core, a bright orb, on a gold mount
		# between four gold prongs, a violet ring pulsing round its middle.
		var core := Vector3(0.0, roof + 0.5, -0.88)
		m.prism(0.3, 0.26, 0.08, 16, core, GOLD_ROUND)
		m.orb(0.26, 16, 6, core + Vector3(0, 0.34, 0), BRIGHT_CORE)
		Parts.torus(m, 0.3, 0.035, 24, 6, core + Vector3(0, 0.3, 0), Parts.CORE_GLOW)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.cone(0.035, 0.42, 8, core + Parts.around(0.27, degrees, 0.06), GOLD_ROUND,
				Parts.facing(Parts.around(0.25, degrees, 1.0)))


## A smokestack standing on `foot`: a ribbed pipe with an orange band and a glowing mouth, and
## with a `collar` surface two collars, at its foot and under its mouth.
static func _stack(m: LowPolyMesh, foot: Vector3, radius: float, height: float, gold: bool,
		collar: Surf = null) -> void:
	m.prism(radius, radius * 0.8, height, 16, foot, PIPE)
	m.ring(radius * 0.8, radius * 1.12, 0.07, 16, foot + Vector3(0, height * 0.55, 0), ORANGE_ROUND)
	if collar != null:
		m.ring(radius * 0.95, radius * 1.3, 0.1, 16, foot, collar)
		m.ring(radius * 0.8, radius * 1.15, 0.08, 16, foot + Vector3(0, height * 0.82, 0), collar)
	var mouth := foot + Vector3(0, height, 0)
	m.ring(radius * 0.55, radius * 0.95, 0.06, 16, mouth, GOLD_ROUND if gold else Parts.GUNMETAL)
	m.disc(radius * 0.56, 16, mouth + Vector3(0, 0.03, 0), GLOW)


## Crystal-lit smoke over a stack's `mouth`, as Parts.puffs but on CRYSTAL_SMOKE.
static func _crystal_puffs(m: LowPolyMesh, mouth: Vector3, phase: float) -> void:
	for k: int in 3:
		m.orb(0.06 + 0.025 * k, 10, 4, mouth + Vector3(0.02 * k, 0.12 + 0.17 * k, 0),
			CRYSTAL_SMOKE.phased(fposmod(phase + 0.3 * k, 1.0)))


## The second gantry crane from 7, over the front yard: orange posts on rails along z, a bridge
## across them (gold filigree at Crown), crates under it, and its trolley running to and fro
## out of step with the first's.
static func _yard_crane(p: Parts) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var top := g + 1.0
	for x: float in [-1.22, -0.38]:
		for z: float in [0.55, 1.25]:
			m.box_chamfered(Vector3(0.08, top - g, 0.08), 0.02, Vector3(x, g, z), ORANGE)
		Parts.beam(m, Vector3(x, top, 0.48), Vector3(x, top, 1.32), 0.1, ORANGE)
	var bridge := 0.9
	Parts.beam(m, Vector3(-1.3, top + 0.1, bridge), Vector3(-0.3, top + 0.1, bridge), 0.1, _trim(p.tier, Parts.HULL_DARK))
	for spec: Vector3 in [Vector3(-1.0, 0, 0.72), Vector3(-0.62, 0, 1.08), Vector3(-0.66, 0.2, 1.06)]:
		m.box_chamfered(Vector3(0.22, 0.2, 0.22), 0.03, spec + Vector3(0, g, 0), ORANGE)
	var trolley := p.moving(Vector3(-0.8, top, bridge), Motion.slide(Vector3.RIGHT, 0.3, 6.0, 0.5))
	trolley.box_chamfered(Vector3(0.2, 0.12, 0.18), 0.03, Vector3(0, 0.15, 0), Parts.GUNMETAL)
	trolley.prism(0.012, 0.012, 0.4, 8, Vector3(0, -0.25, 0), Parts.ROD)
	trolley.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Vector3(0, -0.31, 0), Parts.HAZARD)


## The bulky fabricator: an armoured hall with a furnace in its front, an orange press arm
## hammering an anvil beside it. A second arm at 2, a chimney cluster at 3. The arms hammer
## in turn, sparks fly at the anvils, the furnace mouth pulses and the molten pour runs out of
## it.
##
## From 4 the stacks stand taller with chrome collars: L4 a chrome hall and roof block, cyan
## strips up the furnace mouth's posts, the press heads and the front slabs' caps chrome; L5 a
## fourth stack and a cyan band round the roof block; L6 the hall obsidian under chrome
## armour slabs, violet veins between the side slabs, a violet band round the hall's top and the
## pour crystal pink; L7 a forge ring hovering round each press head over its anvil, obsidian
## rimmed in violet; L8 gold filigree over the roof block and the hall's top, the antimatter core
## glowing in a crowned gold ring on the roof block and the anvils' sparks violet.
static func build_heavy_fabricator(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	Parts.foundation(m, 3)
	var hall := Vector3(-0.42, g, -0.42)
	m.box_chamfered(Vector3(1.76, 1.0, 1.76), 0.08, hall, _plating(p.tier, ARMOUR))
	var block := hall + Vector3(-0.18, 1.0, -0.18)
	var roof_surf := DARK_PLATE
	if crown:
		roof_surf = Parts.FILIGREE
	elif chrome:
		roof_surf = Parts.CHROME
	m.box_chamfered(Vector3(1.2, 0.4, 1.2), 0.08, block, roof_surf)
	# Armour slabs down the sides, chrome over the obsidian hall.
	var slab := Parts.CHROME if obsidian else ARMOUR
	for z: float in [-1.0, -0.45, 0.1]:
		m.box_chamfered(Vector3(0.1, 0.8, 0.45), 0.03, Vector3(0.5, g + 0.06, z), slab)
	for x: float in [-1.12, 0.22]:
		m.box_chamfered(Vector3(0.36, 0.8, 0.1), 0.03, Vector3(x, g + 0.06, 0.5), slab)
	if level >= 2:
		for x: float in [-1.12, 0.22]:
			m.box_chamfered(Vector3(0.38, 0.12, 0.14), 0.03, Vector3(x, g + 0.86, 0.5), Parts.CHROME if chrome else DARK_PLATE)
	if level >= 5:
		m.lathe(PackedVector2Array([Vector2(0.86, 0), Vector2(0.86, 0.1)]), 4, block + Vector3(0, 0.16, 0), _glow(p.tier),
			Vector3(0, 45, 0))
	if obsidian:
		# Violet veins between the side slabs, a violet band round the hall's top.
		for z: float in [-0.725, -0.175]:
			m.box(Vector3(0.02, 0.8, 0.08), Vector3(0.465, g + 0.08, z), VIOLET_PANEL)
		m.lathe(PackedVector2Array([Vector2(1.25, 0), Vector2(1.25, 0.06)]), 4, hall + Vector3(0, 0.88, 0), VIOLET_RIB,
			Vector3(0, 45, 0))
	if crown:
		# Filigree over the hall's top edge (the roof block is filigree), and the core furnace on
		# the block's top, the face the camera sees: a violet core dome in a gold ring under a crown.
		m.lathe(PackedVector2Array([Vector2(1.27, 0), Vector2(1.27, 0.12)]), 4, hall + Vector3(0, 0.88, 0), Parts.FILIGREE,
			Vector3(0, 45, 0))
		var core := block + Vector3(0.3, 0.4, 0.3)
		Parts.torus(m, 0.2, 0.04, 16, 6, core, GOLD_ROUND)
		m.dome(0.2, 0.22, 16, 6, core + Vector3(0, 0.02, 0), Parts.CORE_GLOW)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.cone(0.035, 0.2, 8, core + Parts.around(0.2, degrees, 0.06), GOLD_ROUND, Parts.facing(Parts.around(0.4, degrees, 1.0)))
	# The furnace mouth and the glowing slag trough in front of it.
	var mouth := Vector3(-0.45, g, 0.48)
	m.box(Vector3(0.6, 0.55, 0.02), mouth, GLOW_PULSE)
	m.box(Vector3(0.36, 0.32, 0.02), mouth + Vector3(0, 0, 0.01), HOT_PULSE.phased(0.5))
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.14, 0.62, 0.16), 0.04, mouth + Vector3(side * 0.37, 0, 0.02), DARK_PLATE)
		if level >= 4:
			m.box(Vector3(0.05, 0.48, 0.02), mouth + Vector3(side * 0.37, 0.06, 0.105), _glow(p.tier))
	m.box_chamfered(Vector3(0.9, 0.16, 0.2), 0.04, mouth + Vector3(0, 0.6, 0.03), _trim(p.tier, DARK_PLATE))
	m.box_chamfered(Vector3(0.36, 0.06, 0.75), 0.02, mouth + Vector3(0, 0, 0.42), DARK_PLATE)
	m.box(Vector3(0.2, 0.02, 0.72), mouth + Vector3(0, 0.06, 0.42), CRYSTAL_POUR if obsidian else POUR)
	m.box(Vector3(0.08, 0.02, 0.72), mouth + Vector3(0, 0.07, 0.42), HOT_CRYSTAL_POUR if obsidian else HOT_POUR)
	# The press arms, striking in turn.
	_press_arm(p, Vector3(-0.15, g + 1.0, 0.1), Vector3(0.88, g, 0.85), 0.0)
	if level >= 2:
		_press_arm(p, Vector3(-0.15, g + 1.0, -0.95), Vector3(0.88, g, -0.85), 0.5)
	# Exhausts: one stack, a cluster of three at 3, taller and collared from 4, four at 5.
	var gold := p.tier >= Parts.Tier.GOLD
	var taller := 0.2 if level >= 4 else 0.0
	var collar: Surf = Parts.CHROME_ROUND if level >= 4 else null
	_stack(m, Vector3(-0.95, g + 1.4, -0.95), 0.14, 0.55 + taller, gold, collar)
	if level >= 3:
		_stack(m, Vector3(-0.55, g + 1.4, -1.05), 0.12, 0.75 + taller, gold, collar)
		_stack(m, Vector3(-1.02, g + 1.4, -0.55), 0.1, 0.4 + taller, gold, collar)
	if level >= 5:
		_stack(m, Vector3(-0.6, g + 1.4, -0.6), 0.11, 0.6, gold, collar)
	if level >= 7:
		for anvil: Vector3 in [Vector3(0.88, g, 0.85), Vector3(0.88, g, -0.85)]:
			# A forge ring hovering round the press head's path over the anvil.
			var ring := anvil + Vector3(0, 0.72, 0)
			m.ring(0.36, 0.46, 0.06, 24, ring, HOVER)
			m.lathe(PackedVector2Array([Vector2(0.465, 0.01), Vector2(0.465, 0.05)]), 24, ring, HOVER_RIM)
			m.lathe(PackedVector2Array([Vector2(0.44, 0.062), Vector2(0.38, 0.062)]), 24, ring, HOVER_RIM)


## A press arm: a turret on the hall's roof at `shoulder`, a fat orange boom up to an elbow
## over an anvil standing at `anvil`, a hydraulic ram down from the elbow to a heavy head. The
## head and its piston are a moving part that hammers down onto the anvil, `phase` into its
## cycle, the piston sliding in the ram's cylinder; sparks flicker off the anvil's face.
## From the Chrome tier the head is chrome, at Crown the sparks violet.
static func _press_arm(p: Parts, shoulder: Vector3, anvil: Vector3, phase: float) -> void:
	var m := p.body
	m.prism(0.3, 0.27, 0.24, 16, shoulder, Parts.GUNMETAL)
	var pivot := shoulder + Vector3(0, 0.36, 0)
	var elbow := Vector3(anvil.x, shoulder.y + 1.0, anvil.z)
	m.prism(0.2, 0.2, 0.36, 16, pivot + Vector3(0, 0, -0.18), Parts.GUNMETAL, Vector3(90, 0, 0))
	Parts.beam(m, pivot, elbow, 0.28, ORANGE, 0.06)
	Parts.pipe(m, shoulder + Vector3(0.18, 0.24, 0), elbow + Vector3(-0.08, -0.22, 0), 0.06, MID_ROUND)
	m.prism(0.19, 0.19, 0.34, 16, elbow + Vector3(0, 0, -0.17), Parts.GUNMETAL, Vector3(90, 0, 0))
	Parts.pipe(m, elbow, anvil + Vector3(0, 1.28, 0), 0.12, Parts.GUNMETAL)
	# The head strikes the anvil's face (0.3 up) and lifts to 0.66, where it hung before it moved.
	var head := p.moving(anvil + Vector3(0, 0.48, 0),
		Motion.slide(Vector3.UP, 0.18, 2.4, phase, Motion.Ease.HAMMER))
	Parts.pipe(head, Vector3(0, 0.3, 0), Vector3(0, 1.1, 0), 0.07, MID_ROUND, 16, false)
	head.box_chamfered(Vector3(0.46, 0.32, 0.46), 0.07, Vector3.ZERO, Parts.CHROME if p.tier >= Parts.Tier.CHROME else ORANGE)
	head.box(Vector3(0.48, 0.07, 0.48), Vector3(0, 0.04, 0), Parts.GOLD_TRIM if p.tier >= Parts.Tier.GOLD else Parts.HAZARD)
	m.box_chamfered(Vector3(0.52, 0.3, 0.52), 0.05, anvil, Parts.GUNMETAL)
	m.box(Vector3(0.54, 0.06, 0.54), anvil + Vector3(0, 0.2, 0), Parts.HAZARD)
	for k: int in 6:
		var degrees := 15.0 + 60.0 * k
		var out := Parts.around(1.0, degrees, 0.5 + 0.2 * (k % 3))
		m.cone(0.035, 0.16, 8, anvil + Parts.around(0.3, degrees, 0.3),
			(VIOLET_SPARK if p.tier >= Parts.Tier.CROWN else SPARK).phased(fposmod(phase + k / 6.0 + 0.04, 1.0)), Parts.facing(out))


## A lab ring with screens around a central observatory dome, its telescope out of the slit,
## and a radar dish spinning on a mast in the corner. Antennas at 2 and 4, a second ring at 3.
## The screens scroll, each at its own speed, the slit pulses, the telescope nods along it, and
## from 3 a hologram of the lab's subject, an orb in two rings, floats over the dome.
##
## From 6 the observatory rises as a tower, a wider storey on its drum taller at each level under a
## bigger dome, its telescope longer and turned out of the slit towards the camera, away from the
## radar's sweep: L6 a chrome tower and dome, cyan screens all round the ring and a band of light
## round its lip, chrome antennas, taller, with cyan lamps; L7 a third ring storey under a broad
## band of light; L8 the rings obsidian, violet vein panels between the screens, a crystal lens in
## the telescope and the hologram violet; L9 a ring of rings hovering round the hologram, raised
## clear of the telescope's nod, turning; L10 gold filigree bands on the rings and the dome's
## seams, a violet core beacon on the dome's crown and the hologram's rings gold.
static func build_research_lab(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var screen := CYAN_SCREEN if chrome else SCREEN_FLOW
	Parts.foundation(m, 3)
	m.ring(1.08, 1.13, 0.1, 24, Vector3(0, g, 0), ORANGE_ROUND)
	m.lathe(PackedVector2Array([
		Vector2(1.08, 0), Vector2(1.08, 0.42), Vector2(1.0, 0.5), Vector2(0.66, 0.5), Vector2(0.66, 0),
	]), 24, Vector3(0, g, 0), _plating(p.tier, HULL_ROUND, true))
	_screen(m, 1.085, 5.0, g + 0.15, 0.36, 0.22, 0.6, screen)
	_screen(m, 1.085, 45.0, g + 0.15, 0.36, 0.22, 0.7, screen)
	m.box_chamfered(Vector3(0.28, 0.34, 0.08), 0.03, Parts.around(1.07, 92, g), DARK_PLATE, Vector3(0, -2, 0))
	m.box(Vector3(0.34, 0.05, 0.04), Parts.around(1.1, 92, g + 0.38), GLOW, Vector3(0, -2, 0))
	if level >= 6:
		# Screens all round the ring, violet vein panels in their place from the Obsidian tier,
		# and a band of light round the ring's lip.
		var slots: Array[float] = [-75.0, -35.0, 25.0, 130.0, 170.0, 210.0]
		for k: int in slots.size():
			if obsidian:
				m.box(Vector3(0.3, 0.26, 0.03), Parts.around(1.09, slots[k], g + 0.13), VIOLET_PANEL,
					Vector3(0, 90 - slots[k], 0))
			else:
				_screen(m, 1.085, slots[k], g + 0.15, 0.3, 0.22, 0.55 + 0.05 * k, screen)
		m.lathe(PackedVector2Array([Vector2(1.084, 0), Vector2(1.084, 0.05)]), 24, Vector3(0, g + 0.36, 0),
			_lab_band(p.tier))
	var drum := 0.75
	if level >= 3:
		m.lathe(PackedVector2Array([
			Vector2(0.95, 0), Vector2(0.95, 0.24), Vector2(0.88, 0.3), Vector2(0.66, 0.3), Vector2(0.66, 0),
		]), 24, Vector3(0, g + 0.5, 0), _plating(p.tier, MID_ROUND, true))
		_screen(m, 0.955, 25.0, g + 0.56, 0.3, 0.16, 0.65, screen)
		_screen(m, 0.955, 65.0, g + 0.56, 0.3, 0.16, 0.8, screen)
		drum = 1.05
	if level >= 6:
		var upper: Array[float] = [-15.0, 105.0, 145.0]
		for k: int in upper.size():
			_screen(m, 0.955, upper[k], g + 0.56, 0.26, 0.16, 0.6 + 0.1 * k, screen)
		if crown:
			m.lathe(PackedVector2Array([Vector2(0.955, 0), Vector2(0.955, 0.04)]), 24, Vector3(0, g + 0.5, 0),
				FILIGREE_ROUND)
	if level >= 7:
		# The third ring storey, a broad band of light all round it.
		m.lathe(PackedVector2Array([
			Vector2(0.84, 0), Vector2(0.84, 0.2), Vector2(0.78, 0.25), Vector2(0.66, 0.25), Vector2(0.66, 0),
		]), 24, Vector3(0, g + 0.8, 0), _plating(p.tier, MID_ROUND, true))
		m.lathe(PackedVector2Array([Vector2(0.848, 0), Vector2(0.848, 0.18)]), 24, Vector3(0, g + 0.81, 0), _glow(p.tier))
		m.lathe(PackedVector2Array([Vector2(0.845, 0), Vector2(0.845, 0.035)]), 24, Vector3(0, g + 0.8, 0),
			_lab_band(p.tier))
	# The observatory: a drum, a dome with a dark slit and the telescope out of it.
	m.prism(0.63, 0.63, drum, 24, Vector3(0, g, 0), Parts.CHROME_ROUND if chrome else MID_ROUND)
	var centre := Vector3(0, g + drum, 0)
	if level >= 6:
		_lab_tower(p, centre, level)
		return
	m.ring(0.62, 0.69, 0.05, 24, centre, GLOW)
	if level >= 5:
		m.ring(0.62, 0.68, 0.05, 24, centre - Vector3(0, 0.08, 0), GOLD_ROUND if p.tier >= Parts.Tier.GOLD else MID_ROUND)
	m.dome(0.62, 0.62, 16, 7, centre, HULL_ROUND)
	var across := Vector3(0.7071, 0, 0.7071)
	m.ring(0.6, 0.65, 0.18, 24, centre - across * 0.09, GLOW_PULSE, Parts.facing(across))
	# The telescope nods along the slit, about its trunnion at the dome's centre.
	var telescope := p.moving(centre, Motion.swing(across, 10.0, 8.0))
	var aim := Vector3(0.42, 0.8, -0.42).normalized()
	Parts.pipe(telescope, aim * 0.3, aim * 0.95, 0.1, HULL_ROUND)
	telescope.ring(0.07, 0.13, 0.1, 16, aim * 0.85, ORANGE_ROUND, Parts.facing(aim))
	telescope.disc(0.085, 16, aim * 0.955, Parts.GLASS, Parts.facing(aim))
	if level >= 5:
		m.orb(0.07, 16, 6, centre + Vector3(0, 0.66, 0), GOLD_ROUND if p.tier >= Parts.Tier.GOLD else MID_ROUND)
	if level >= 3:
		# The hologram over the dome: an orb in two tilted rings, floating.
		var subject := centre + Vector3(0, 1.0, 0)
		m.orb(0.13, 12, 4, subject, HOLOGRAM)
		for tilt: Vector3 in [Vector3(35, 0, 0), Vector3(0, 0, -35)]:
			m.lathe(PackedVector2Array([Vector2(0.26, 0), Vector2(0.26, 0.025), Vector2(0.22, 0.025)]), 16,
				subject, HOLOGRAM, tilt)
	_lab_corners(p, level)


## The research lab's corners (_research_lab's): antennas at 2 and 4, and the radar mast against
## the ring, near enough the middle that the spinning dish's sweep stays inside the footprint
## and clear of the tower; the dish spins. From 6 the antennas stand taller each level on feet
## in the tier's plating, their bulbs lamps blinking in the tier's light.
static func _lab_corners(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	# Antennas on the corners.
	if level >= 6:
		var taller := 0.25 * (level - 5)
		var lamp := INLAY if p.tier >= Parts.Tier.OBSIDIAN else CYAN_LAMP
		if p.tier >= Parts.Tier.CROWN:
			lamp = BRIGHT_CORE
		var foot := _plating(p.tier, Parts.GUNMETAL)
		if p.tier >= Parts.Tier.CROWN:
			foot = Parts.GOLD_TRIM
		_antenna(m, Vector3(-0.98, g, -0.98), 1.3 + taller, foot, lamp)
		_antenna(m, Vector3(-1.0, g, 0.98), 1.0 + taller * 0.8, foot, lamp.phased(0.5))
	else:
		if level >= 2:
			_antenna(m, Vector3(-0.98, g, -0.98), 1.3)
		if level >= 4:
			_antenna(m, Vector3(-1.0, g, 0.98), 1.0)
	var mast := Vector3(0.85, g, -0.85)
	m.prism(0.12, 0.11, 0.14, 16, mast, _plating(p.tier, ARMOUR_ROUND, true))
	var height := 1.25 + 0.08 * level
	m.prism(0.08, 0.06, height, 16, mast + Vector3(0, 0.14, 0), Parts.GUNMETAL)
	var radar := p.moving(mast + Vector3(0, 0.14 + height, 0), Motion.spin(Vector3.UP, 0.9))
	radar.box_chamfered(Vector3(0.12, 0.16, 0.12), 0.03, Vector3.ZERO, Parts.GUNMETAL)
	var tilt := Vector3(60, 90, 0)
	var hub := Vector3(0, 0.14, 0)
	Parts.dish(radar, 0.38, 0.14, hub, GOLD_ROUND if p.tier >= Parts.Tier.GOLD else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(radar, hub + axis * 0.05, hub + axis * 0.32, 0.02, Parts.ROD)
	radar.orb(0.045, 16, 6, hub + axis * 0.32, CYAN_LAMP if p.tier >= Parts.Tier.CHROME else GLOW)


## The research lab's observatory tower from 6 (_research_lab's), on its drum's top at `foot`: a
## wider chrome storey, taller each level, with a band of light at its foot and window slits
## round it, under a bigger dome (chrome, with filigree seams at Crown) cut by the glowing slit;
## the longer telescope nodding along it, a crystal lens in it from the Obsidian tier; the
## hologram over the dome, violet from the Obsidian tier; from 9 a ring of rings hovering round
## it, turning, gold at Crown; at 10 a violet core beacon on the dome's crown under the hologram.
static func _lab_tower(p: Parts, foot: Vector3, level: int) -> void:
	var m := p.body
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var storeys: Array[float] = [0.45, 0.6, 0.95, 1.2, 1.5]
	var tall := storeys[mini(level, 10) - 6]
	m.lathe(PackedVector2Array([
		Vector2(0.63, 0), Vector2(0.7, 0.06), Vector2(0.7, tall), Vector2(0, tall),
	]), 24, foot, Parts.CHROME_ROUND)
	m.lathe(PackedVector2Array([Vector2(0.705, 0.08), Vector2(0.705, 0.14)]), 24, foot, _lab_band(p.tier))
	# Window slits round the storey's front, lit in the tier's light.
	for k: int in 5:
		var degrees := -35.0 + 40.0 * k
		m.box(Vector3(0.1, tall - 0.3, 0.03), Parts.around(0.7, degrees, foot.y + 0.2), _glow(p.tier).phased(k / 5.0),
			Vector3(0, 90 - degrees, 0))
	var centre := foot + Vector3(0, tall, 0)
	const R := 0.74
	m.ring(R - 0.02, R + 0.06, 0.06, 24, centre, GLOW)
	m.ring(R - 0.02, R + 0.05, 0.06, 24, centre - Vector3(0, 0.09, 0), GOLD_ROUND)
	m.dome(R, R, 16, 7, centre, Parts.CHROME_ROUND)
	if crown:
		for k: int in 8:
			Parts.dome_seam(m, R, R, centre, 22.5 + 45.0 * k, Parts.FILIGREE)
		m.lathe(PackedVector2Array([Vector2(R + 0.065, 0), Vector2(R + 0.065, 0.06)]), 24, centre, FILIGREE_ROUND)
	var across := Vector3(0.7071, 0, 0.7071)
	m.ring(R - 0.02, R + 0.04, 0.22, 24, centre - across * 0.11, GLOW_PULSE, Parts.facing(across))
	# The longer telescope, nodding along the slit, out of the slit's other side from the radar
	# mast, towards the camera, so it never meets the dish's sweep.
	var telescope := p.moving(centre, Motion.swing(across, 10.0, 8.0))
	var aim := Vector3(-0.42, 0.8, 0.42).normalized()
	Parts.pipe(telescope, aim * 0.35, aim * 1.25, 0.12, Parts.CHROME_ROUND)
	telescope.ring(0.09, 0.16, 0.12, 16, aim * 1.1, ORANGE_ROUND, Parts.facing(aim))
	if obsidian:
		telescope.dome(0.11, 0.07, 16, 3, aim * 1.25, INLAY, Parts.facing(aim))
	else:
		telescope.disc(0.105, 16, aim * 1.255, Parts.GLASS, Parts.facing(aim))
	# The hologram over the dome, higher from 9 so its ring of rings clears the telescope's nod,
	# and at 10 over the core beacon.
	var lifts: Array[float] = [0.45, 0.45, 0.45, 0.8, 0.95]
	var subject := centre + Vector3(0, R + lifts[mini(level, 10) - 6], 0)
	if level >= 10:
		# The core beacon on the dome's crown: a bright orb on a gold mount between gold prongs,
		# a violet ring round it; filigree bands round the storey.
		var core := centre + Vector3(0, R - 0.02, 0)
		m.prism(0.24, 0.2, 0.08, 16, core, GOLD_ROUND)
		m.orb(0.23, 16, 6, core + Vector3(0, 0.3, 0), BRIGHT_CORE)
		Parts.torus(m, 0.25, 0.035, 16, 6, core + Vector3(0, 0.25, 0), Parts.CORE_GLOW)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.cone(0.035, 0.38, 8, core + Parts.around(0.22, degrees, 0.05), GOLD_ROUND,
				Parts.facing(Parts.around(0.3, degrees, 1.0)))
		for y: float in [0.3, tall - 0.12]:
			m.lathe(PackedVector2Array([Vector2(0.71, 0), Vector2(0.71, 0.07)]), 24, foot + Vector3(0, y, 0), FILIGREE_ROUND)
	else:
		m.orb(0.08, 16, 6, centre + Vector3(0, R + 0.04, 0), GOLD_ROUND)
	var holo := HOLO_VIOLET if obsidian else HOLOGRAM
	m.orb(0.17, 12, 4, subject, holo)
	for tilt: Vector3 in [Vector3(35, 0, 0), Vector3(0, 0, -35)]:
		m.lathe(PackedVector2Array([Vector2(0.32, 0), Vector2(0.32, 0.03), Vector2(0.27, 0.03)]), 16,
			subject, GOLD_BOB if crown else holo, tilt)
	if level >= 9:
		# The ring of rings hovering round the hologram, turning: a ring with six upright rings
		# standing round it, obsidian rimmed in violet, gold at Crown.
		var gyro := p.moving(subject - Vector3(0, 0.05, 0), Motion.spin(Vector3.UP, -0.6))
		gyro.ring(0.44, 0.52, 0.05, 24, Vector3.ZERO, GOLD_BOB.phased(0.6) if crown else HOVER)
		for k: int in 6:
			var degrees := 60.0 * k
			Parts.torus(gyro, 0.075, 0.022, 8, 6, Parts.around(0.48, degrees, -0.045), HOVER_RIM,
				Vector3(90, 90 - degrees, 0))
	_lab_corners(p, level)


## The lab's band of light round a ring's lip: cyan at the Chrome tier, violet veins from the
## Obsidian tier, gold filigree at Crown.
static func _lab_band(tier: int) -> Surf:
	return FILIGREE_ROUND if tier >= Parts.Tier.CROWN else _strip(tier)


## A flat screen on a round wall of `radius`, at `degrees` around it, its bottom at `y`, its
## rows scrolling at the FLOW speed `speed`, on `surface` (SCREEN_FLOW unless given).
static func _screen(m: LowPolyMesh, radius: float, degrees: float, y: float, width: float,
		height: float, speed: float, surface: Surf = SCREEN_FLOW) -> void:
	m.box_chamfered(Vector3(width, height, 0.04), 0.015, Parts.around(radius, degrees, y),
		surface.phased(speed), Vector3(0, 90 - degrees, 0))


## A sensor mast on a little foot (gunmetal unless `foot_surf`): a thin rod with a bulb (orange
## unless `bulb`).
static func _antenna(m: LowPolyMesh, foot: Vector3, height: float, foot_surf: Surf = Parts.GUNMETAL,
		bulb: Surf = GLOW) -> void:
	m.box_chamfered(Vector3(0.18, 0.1, 0.18), 0.03, foot, foot_surf)
	Parts.mast(m, foot + Vector3(0, 0.1, 0), height, 0.06, bulb)


## Vats of glowing green nanite goo seen through glass bands, round a pump block, with pipes
## and their elbows running between them. A vat more at each level; gold rims at 4. The goo
## rises in every vat and bubbles, the pipes and the pump's screens flow, and a stirrer turns in
## the big vat's open top.
##
## From 5 the vats stand taller at each level and the pump block rises to a tower: L5 chrome vats
## with cyan rims, a chrome pump tower and cyan pipes; L6 a sixth vat, a tall column on the right;
## L7 obsidian
## vats veined violet, their rims glowing violet, crystal elbows on the pipes, the goo brighter
## in taller glass, and a stirrer ring hovering over the big vat, turning against the stirrer;
## L8 gold filigree rims and gold caps and the antimatter core glowing on the pump tower in a gold
## crown.
static func build_nanite_foundry(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	Parts.foundation(m, 3)
	# The pump block in the middle, with goo screens and a vent; a chrome tower from 5.
	var pump := Vector3(0.1, g, 0.1)
	var tower := 0.45
	if level >= 5:
		var towers: Array[float] = [0.75, 0.85, 1.0, 1.15]
		tower = towers[mini(level, 8) - 5]
		_pump_tower(p, pump, tower, level)
	else:
		m.box_chamfered(Vector3(0.5, 0.45, 0.5), 0.05, pump, Parts.HULL_LIGHT)
		m.box_chamfered(Vector3(0.3, 0.18, 0.03), 0.01, pump + Vector3(0, 0.16, 0.25), GOO_SCREEN)
		m.box_chamfered(Vector3(0.03, 0.18, 0.3), 0.01, pump + Vector3(0.25, 0.16, 0), GOO_SCREEN)
		m.box_chamfered(Vector3(0.3, 0.1, 0.3), 0.03, pump + Vector3(0, 0.45, 0), VENT)
	# [position, radius, height] of each vat, in the order the levels add them.
	var vats: Array[Array] = [
		[Vector3(-0.62, g, -0.62), 0.5, 1.35],
		[Vector3(0.68, g, -0.72), 0.38, 1.0],
		[Vector3(-0.72, g, 0.66), 0.38, 0.9],
		[Vector3(0.78, g, 0.62), 0.32, 0.75],
		[Vector3(0.02, g, 1.0), 0.26, 0.6],
	]
	if level >= 6:
		vats.append([Vector3(0.98, g, -0.02), 0.27, 1.25])
	# Taller vats from 5, the arch, the stirrer and the lids raised with the first two.
	var grows: Array[float] = [1.0, 1.25, 1.35, 1.55, 1.65]
	var grow := grows[clampi(level - 4, 0, 4)]
	var lids := Vector2(1.33, 0.98)
	var stir := 1.3
	if level >= 5:
		lids = Vector2(1.35 * grow - 0.02, 1.0 * grow - 0.02)
		stir = 1.35 * grow - 0.05
	var pipe := PIPE_FLOW
	if chrome:
		pipe = CYAN_PIPE
	# An arch of pipe over from the big vat's lid into the next one's.
	var big: Vector3 = vats[0][0] + Vector3(0.3, lids.x, -0.02)
	var second: Vector3 = vats[1][0] + Vector3(-0.16, lids.y, 0.01)
	_goo_pipe(m, PackedVector3Array([
		big, big + Vector3(0, 0.2, 0), Vector3(second.x, big.y + 0.2, second.z), second,
	]), pipe, obsidian)
	# The stirrer: a hub with two crossed paddles turning in the big vat's goo.
	var stirrer := p.moving(vats[0][0] + Vector3(0, stir, 0), Motion.spin(Vector3.UP, 1.6))
	stirrer.prism(0.08, 0.06, 0.12, 12, Vector3(0, -0.02, 0), ORANGE_ROUND)
	for yaw: float in [0.0, 90.0]:
		stirrer.box_chamfered(Vector3(0.44, 0.08, 0.05), 0.02, Vector3(0, -0.04, 0), ORANGE, Vector3(0, yaw, 0))
	for i: int in mini(level + 1, vats.size()):
		var spot: Vector3 = vats[i][0]
		var radius: float = vats[i][1]
		var height: float = vats[i][2]
		height *= grow
		_vat(m, spot, radius, height, p.tier, i, 0.36 if level >= 7 else 0.28)
		if i < 3 or i == 5:
			# Out of the vat's upper shell, down to the pad and along it into the pump.
			var toward := Vector3(pump.x - spot.x, 0, pump.z - spot.z).normalized()
			var high := spot + toward * (radius + 0.16) + Vector3(0, height * 0.8, 0)
			var low := Vector3(high.x, g + 0.1, high.z)
			_goo_pipe(m, PackedVector3Array([
				spot + toward * (radius - 0.04) + Vector3(0, height * 0.8, 0), high, low,
				pump + Vector3(0, 0.1, 0) - toward * 0.2,
			]), pipe, obsidian)
		else:
			# A short pipe across to the vat it stands next to.
			var next: Vector3 = vats[i - 2][0]
			var toward := Vector3(next.x - spot.x, 0, next.z - spot.z).normalized()
			var y := Vector3(0, height * 0.82, 0)
			Parts.pipe(m, spot + toward * (radius - 0.04) + y, next - toward * 0.2 + y, 0.05, pipe,
				12, false)
	if level >= 7:
		# The stirrer ring hovering over the big vat, turning against the stirrer: obsidian rimmed
		# in violet, four crystal vanes pointing in.
		var hover := p.moving(vats[0][0] + Vector3(0, stir + 0.42, 0), Motion.spin(Vector3.UP, -0.8))
		hover.ring(0.3, 0.42, 0.06, 24, Vector3.ZERO, HOVER)
		hover.lathe(PackedVector2Array([Vector2(0.425, 0.01), Vector2(0.425, 0.05)]), 24, Vector3.ZERO, HOVER_RIM)
		hover.lathe(PackedVector2Array([Vector2(0.4, 0.062), Vector2(0.32, 0.062)]), 24, Vector3.ZERO, HOVER_RIM)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			hover.cone(0.04, 0.16, 8, Parts.around(0.31, degrees, 0.03), HOVER_CRYSTAL,
				Parts.facing(Parts.around(-1.0, degrees, 0.0)))


## The pump tower from 5 (_nanite_foundry's), on `foot`, `tall` high: a chrome block with goo
## screens on its faces to the camera, a cyan band round its top and a vent on its roof; at 8 a
## filigree band and the antimatter core on the roof instead, a bright orb on a gold mount between
## gold prongs with a violet ring round it.
static func _pump_tower(p: Parts, foot: Vector3, tall: float, level: int) -> void:
	var m := p.body
	m.box_chamfered(Vector3(0.5, tall, 0.5), 0.05, foot, Parts.CHROME)
	for k: int in 2:
		var y := 0.16 + 0.3 * k
		m.box_chamfered(Vector3(0.3, 0.2, 0.03), 0.01, foot + Vector3(0, y, 0.25), GOO_SCREEN)
		m.box_chamfered(Vector3(0.03, 0.2, 0.3), 0.01, foot + Vector3(0.25, y, 0), GOO_SCREEN)
	var band := Parts.FILIGREE if level >= 8 else _glow(p.tier)
	m.lathe(PackedVector2Array([Vector2(0.37, 0), Vector2(0.37, 0.06)]), 4, foot + Vector3(0, tall - 0.12, 0), band,
		Vector3(0, 45, 0))
	var roof := foot + Vector3(0, tall, 0)
	if level < 8:
		m.box_chamfered(Vector3(0.3, 0.1, 0.3), 0.03, roof, VENT)
		return
	m.prism(0.22, 0.18, 0.08, 16, roof, GOLD_ROUND)
	m.orb(0.2, 16, 6, roof + Vector3(0, 0.28, 0), BRIGHT_CORE)
	Parts.torus(m, 0.22, 0.03, 16, 6, roof + Vector3(0, 0.24, 0), Parts.CORE_GLOW)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		m.cone(0.03, 0.34, 8, roof + Parts.around(0.2, degrees, 0.05), GOLD_ROUND,
			Parts.facing(Parts.around(0.3, degrees, 1.0)))


## A pipe of goo through `points` with ball elbows (Parts.pipe_run), on `surface`; with
## `crystal` a crystal knuckle glowing round each elbow.
static func _goo_pipe(m: LowPolyMesh, points: PackedVector3Array, surface: Surf, crystal: bool) -> void:
	Parts.pipe_run(m, points, 0.05, surface, 12)
	if crystal:
		for i: int in range(1, points.size() - 1):
			m.orb(0.085, 12, 4, points[i], INLAY.phased(0.3 * i))


## A vat standing on `foot`, the `index`th of the foundry's: an armoured lower shell, a band of
## glowing goo rising behind glass framed by rims, with bubbles blinking on it, and an upper
## shell with a chamfered lid and an orange cap. The first vat is open at the top instead, over
## a swirl of goo for the stirrer to turn in. `glass` is the goo band's share of the height. The
## tier paints it: gold rims from the Gold tier; chrome shells and cyan rims at the Chrome tier;
## obsidian shells veined violet, violet rims and the goo brighter from the Obsidian tier; at
## Crown filigree rims and gold caps.
static func _vat(m: LowPolyMesh, foot: Vector3, radius: float, height: float, tier: int, index: int,
		glass: float = 0.28) -> void:
	var band := height * 0.4
	var lit := height * glass
	var rim := radius + 0.035
	var gold := tier >= Parts.Tier.GOLD
	var bright := tier >= Parts.Tier.OBSIDIAN
	var lower := _plating(tier, ARMOUR_ROUND, true)
	var upper_shell := _plating(tier, HULL_ROUND, true)
	var rims := GOLD_ROUND if gold else ARMOUR_ROUND
	var upper_rim := GOLD_ROUND if gold else HULL_ROUND
	if tier >= Parts.Tier.CROWN:
		rims = FILIGREE_ROUND
		upper_rim = FILIGREE_ROUND
	elif tier >= Parts.Tier.CHROME:
		rims = _glow(tier)
		upper_rim = _glow(tier)
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, band - 0.05)]), 16, foot, lower)
	# The rim's underside faces the ground, which the camera never sees, so it is left out.
	m.lathe(PackedVector2Array([
		Vector2(rim, band - 0.05), Vector2(rim, band), Vector2(radius - 0.03, band),
	]), 16, foot, rims)
	m.lathe(PackedVector2Array([Vector2(radius - 0.03, 0), Vector2(radius - 0.03, lit)]), 16,
		foot + Vector3(0, band, 0), (GOO_BRIGHT if bright else GOO_FLOW).phased(0.27 + 0.02 * index))
	for k: int in 2:
		m.orb(0.045, 8, 2, foot + Parts.around(radius - 0.03, 25.0 + 40.0 * k + 7.0 * index,
			band + lit * (0.3 + 0.4 * k)), BUBBLE.phased(fposmod(0.37 * index + 0.5 * k, 1.0)))
	var upper := band + lit
	var top := height - upper
	m.lathe(PackedVector2Array([Vector2(rim, 0), Vector2(rim, 0.05), Vector2(radius, 0.05)]), 16,
		foot + Vector3(0, upper, 0), upper_rim)
	if bright:
		# Violet veins round the lower and the upper shell.
		m.lathe(PackedVector2Array([Vector2(radius + 0.005, 0), Vector2(radius + 0.005, 0.1)]), 16,
			foot + Vector3(0, band * 0.4, 0), Parts.VEINS)
		m.lathe(PackedVector2Array([Vector2(radius + 0.005, 0), Vector2(radius + 0.005, 0.1)]), 16,
			foot + Vector3(0, upper + 0.05 + (top - 0.13) * 0.45, 0), Parts.VEINS)
	if index == 0:
		m.lathe(PackedVector2Array([
			Vector2(radius, 0.05), Vector2(radius, top - 0.08), Vector2(radius - 0.08, top),
			Vector2(radius - 0.13, top), Vector2(radius - 0.13, top - 0.05),
		]), 16, foot + Vector3(0, upper, 0), upper_shell)
		m.disc(radius - 0.13, 16, foot + Vector3(0, height - 0.05, 0), GOO_BRIGHT_SWIRL if bright else GOO_SWIRL)
		return
	m.lathe(PackedVector2Array([
		Vector2(radius, 0.05), Vector2(radius, top - 0.08), Vector2(radius - 0.08, top), Vector2(0, top),
	]), 16, foot + Vector3(0, upper, 0), upper_shell)
	m.prism(radius * 0.42, radius * 0.34, 0.1, 16, foot + Vector3(0, height, 0),
		GOLD_ROUND if tier >= Parts.Tier.CROWN else ORANGE_ROUND)


## A drydock: an orange gantry crane over a cradle holding a half-built ship, its nose plated,
## its stern still bare ribs, welders glowing where the gantries reach down. A bigger, more
## plated hull and a third gantry at 2. The bare stern is completed in a hologram of the hull
## to come, the first gantry rides its rails along the dock, the welds flash and throw sparks,
## and the reactor pulses (the engines too, at 2).
##
## From 3 the gantries stand taller at each level, the chocks lift the ship higher and the plating
## runs further aft, the hull growing from 5: L3 the gantries slim chrome cantilevers on posts at
## the back, braced, with cyan strips up the posts, so the camera sees the ship under their beams;
## a chrome hull, cradle and booth, an engine bank on the stern, its bells ringed in cyan, and the
## welders' sparks cyan, the reactor glowing through a port on the near flank; L4 a fourth gantry;
## L5 obsidian plates veined violet along the hull's spine and a broad violet band glowing on the
## chrome flank the camera sees, an obsidian cradle, crystal arcs crackling from the welders onto
## the hull; L6 a crane platform hovering over the hull between the gantries, obsidian rimmed in
## violet, a violet tractor beam down to it; L7 the ship complete, gold filigree gantries, the
## antimatter reactor's light violet in its port, along the near flank, in a band round the stern
## and under a gold-ringed blister, gold fins, and a launch skiff circling above the gantries as
## its escort.
static func build_drydock(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	Parts.foundation(m, 4)
	# The cradle: rails along the dock and hazard chocks under the hull; chrome from the Chrome
	# tier, obsidian from the Obsidian, banded in the tier's light.
	for z: float in [-0.45, 0.45]:
		m.box_chamfered(Vector3(3.5, 0.08, 0.16), 0.03, Vector3(0, g, z), _plating(p.tier, Parts.GUNMETAL))
	# From 3 the chocks stand taller each level, lifting the ship higher in the cradle.
	var lifts: Array[float] = [0.0, 0.0, 0.1, 0.15, 0.2, 0.25, 0.3]
	var lift := lifts[clampi(level, 1, 7) - 1]
	for x: float in [-1.15, -0.35, 0.45, 1.2]:
		m.box_chamfered(Vector3(0.24, 0.36 + lift, 0.86), 0.04, Vector3(x, g, 0), _plating(p.tier, Parts.HAZARD))
		if chrome:
			m.box(Vector3(0.26, 0.06, 0.88), Vector3(x, g + 0.22 + lift, 0), _strip(p.tier))
	# The hull lies along X, nose to +X. [distance from the stern, radius] down its profile.
	var scales: Array[float] = [1.0, 1.08, 1.08, 1.08, 1.15, 1.15, 1.2]
	var scale := scales[clampi(level, 1, 7) - 1]
	var stern := -1.65
	var axis_y := g + 0.36 + lift + 0.55 * scale
	var profile := PackedVector2Array([
		Vector2(0.38, 0), Vector2(0.52, 0.35), Vector2(0.56, 1.0), Vector2(0.54, 1.7),
		Vector2(0.44, 2.45), Vector2(0.24, 3.05), Vector2(0, 3.3),
	])
	var plating: Array[float] = [1.7, 1.0, 0.7, 0.45, 0.3, 0.15, 0.0]
	var plated_from := plating[clampi(level, 1, 7) - 1]
	var plated := PackedVector2Array()
	if level >= 3:
		plated.append(Vector2(_hull_radius(profile, plated_from) * scale, 0))
	for point: Vector2 in profile:
		if point.y >= plated_from and (level < 3 or point.y > plated_from):
			plated.append(Vector2(point.x * scale, point.y - plated_from))
	# Round parts lie along +X: their axis, +Y, turned onto +X.
	var lie := Vector3(0, 0, -90)
	m.lathe(plated, 24, Vector3(stern + plated_from, axis_y, 0), Parts.CHROME_ROUND if chrome else HULL_ROUND, lie)
	m.ring(0.46 * scale, 0.56 * scale, 0.12, 24, Vector3(stern + 2.3, axis_y, 0), ORANGE_ROUND, lie)
	var canopy := Vector3(stern + 2.55, axis_y + 0.36 * scale, 0)
	m.dome(0.2, 0.14, 16, 4, canopy, Parts.GLASS, Vector3(0, 0, -20))
	if level >= 5:
		_hull_plates(m, profile, Vector3(stern, axis_y, 0), scale, crown)
	if level < 7:
		# The hull to come, aft of the plating, a hologram round the ribs.
		var plan := PackedVector2Array([Vector2(0, 0)])
		for point: Vector2 in profile:
			if point.y <= plated_from:
				plan.append(Vector2(point.x * scale + 0.01, point.y))
		if level >= 3:
			plan.append(Vector2(_hull_radius(profile, plated_from) * scale + 0.01, plated_from))
		m.lathe(plan, 24, Vector3(stern, axis_y, 0), HOLO_HULL, lie)
		# Bare ribs aft of the plating, with a keel, a spine and stringers through them.
		var x := stern + 0.12
		while x < stern + plated_from - 0.05:
			var radius := _hull_radius(profile, x - stern) * scale
			m.ring(radius - 0.07, radius, 0.08, 24, Vector3(x, axis_y, 0), ARMOUR_ROUND, lie)
			x += 0.34
		var aft := Vector3(stern + 0.05, axis_y, 0)
		var fore := Vector3(stern + plated_from + 0.05, axis_y, 0)
		for offset: Vector3 in [Vector3(0, -0.5, 0), Vector3(0, 0.5, 0), Vector3(0, 0, 0.5), Vector3(0, 0, -0.5)]:
			Parts.beam(m, aft + offset * scale, fore + offset * scale, 0.06, Parts.GUNMETAL, 0.015)
	# The reactor glowing inside the bare ribs; engine bells on the stern at 2, an engine bank
	# from 3.
	if level < 3:
		m.orb(0.2, 16, 6, Vector3(stern + 0.75, axis_y, 0), GLOW_PULSE)
	else:
		# From 3, plated over, the reactor glows through a port on the near flank, aft, where the
		# camera sees it; the antimatter core's light violet at Crown.
		var port := Vector3(stern + 0.75, axis_y - 0.06, _hull_radius(profile, 0.75) * scale - 0.02)
		m.ring(0.12, 0.17, 0.05, 16, port, _plating(p.tier, Parts.GUNMETAL, true), Vector3(90, 0, 0))
		m.disc(0.125, 16, port + Vector3(0, 0, 0.045), BRIGHT_CORE if crown else GLOW_PULSE, Vector3(90, 0, 0))
	if level >= 3:
		_engine_bank(m, Vector3(stern, axis_y, 0), scale, p.tier, level)
	elif level >= 2:
		for z: float in [-0.2, 0.2]:
			m.prism(0.1, 0.17, 0.22, 16, Vector3(stern + 0.1, axis_y - 0.1, z), Parts.GUNMETAL, -lie)
			m.disc(0.14, 16, Vector3(stern - 0.125, axis_y - 0.1, z), GLOW_PULSE.phased(0.25), -lie)
	# The gantries, each with a welder reaching down to the hull. The first rides rails along
	# the dock, where the hull's radius hardly changes, so its welder stays on the hull.
	var tops: Array[float] = [1.95, 1.95, 2.3, 2.55, 2.75, 2.9, 3.05]
	var top := g + tops[clampi(level, 1, 7) - 1]
	var rails: Array[float] = [-1.6, 1.6]
	if level >= 3:
		rails = [-1.6]
	for z: float in rails:
		m.box_chamfered(Vector3(0.84, 0.03, 0.12), 0.01, Vector3(-0.75, g, z), Parts.GUNMETAL)
	var gantries: Array[float] = [-0.75, 0.55]
	if level >= 4:
		gantries = [-0.75, 0.15, 0.8, 1.45]
	elif level >= 2:
		gantries.append(1.45)
	var post := ORANGE
	var span := Parts.GOLD_TRIM if p.tier >= Parts.Tier.GOLD else ORANGE
	if crown:
		post = FILIGREE_LEG
		span = Parts.FILIGREE
	elif chrome:
		post = Parts.CHROME
	for k: int in gantries.size():
		var gx := gantries[k]
		var crane := m
		var at := Vector3(gx, 0, 0)
		if k == 0:
			crane = p.moving(at, Motion.slide(Vector3.RIGHT, 0.3, 7.0))
			at = Vector3.ZERO
		if level >= 3:
			# From 3 a slim cantilever on a post at the back, braced, its beam reaching out over the
			# hull, so the camera sees the ship under it; cyan strips up the post's faces to the
			# camera, below Crown.
			crane.box_chamfered(Vector3(0.24, 0.12, 0.24), 0.03, at + Vector3(0, g, -1.6), ORANGE)
			crane.box_chamfered(Vector3(0.12, top - g - 0.12, 0.12), 0.03, at + Vector3(0, g + 0.12, -1.6), post)
			if not crown:
				crane.box(Vector3(0.02, top - g - 0.3, 0.07), at + Vector3(0.061, g + 0.2, -1.6), Parts.CYAN_STRIP)
				crane.box(Vector3(0.07, top - g - 0.3, 0.02), at + Vector3(0, g + 0.2, -1.539), Parts.CYAN_STRIP)
			Parts.beam(crane, at + Vector3(0, top, -1.68), at + Vector3(0, top, 0.55), 0.13, span, 0.03)
			Parts.beam(crane, at + Vector3(0, top - 0.75, -1.58), at + Vector3(0, top - 0.02, -0.75), 0.06, post, 0.015)
		else:
			for z: float in [-1.6, 1.6]:
				crane.box_chamfered(Vector3(0.24, 0.12, 0.24), 0.03, at + Vector3(0, g, z), DARK_PLATE)
				crane.box_chamfered(Vector3(0.14, top - g - 0.12, 0.14), 0.03, at + Vector3(0, g + 0.12, z), post)
			Parts.beam(crane, at + Vector3(0, top, -1.7), at + Vector3(0, top, 1.7), 0.18, span, 0.04)
		var trolley := at + Vector3(0, top - 0.16, 0.25)
		crane.box_chamfered(Vector3(0.22, 0.14, 0.26), 0.03, trolley, ORANGE if chrome else Parts.GUNMETAL)
		var surface := axis_y + _hull_radius(profile, gx - stern) * scale
		var tip := at + Vector3(0, surface + 0.16, 0.25)
		Parts.pipe(crane, trolley, tip, 0.03, Parts.ROD)
		var spot := at + Vector3(0, surface + 0.04, 0.25)
		var phase := float(k) / gantries.size()
		if obsidian:
			_weld(crane, spot, phase, CRYSTAL_SPARK_ARC)
			# Crystal arcs crackling from the welder's tip onto the hull either side of the weld.
			for side: float in [-1.0, 1.0]:
				var hit := at + Vector3(side * 0.16, axis_y + _hull_radius(profile, gx + side * 0.16 - stern) * scale * 0.97, 0.22)
				Parts.arc(crane, tip + Vector3(side * 0.02, 0, 0), hit, 3, 0.03,
					CRYSTAL_SPARK_ARC.phased(fposmod(phase + 0.25 + 0.5 * side, 1.0)))
		else:
			_weld(crane, spot, phase, CYAN_SPARK_ARC if chrome else SPARK_ARC)
	# The control booth in the front corner.
	var booth := Vector3(-1.45, g, 1.4)
	m.box_chamfered(Vector3(0.5, 0.45, 0.4), 0.05, booth, _plating(p.tier, Parts.HULL_LIGHT))
	m.box_chamfered(Vector3(0.4, 0.16, 0.03), 0.01, booth + Vector3(0, 0.24, 0.2), Parts.GLASS)
	Parts.mast(m, booth + Vector3(0.12, 0.45, -0.08), 0.35, 0.05, GLOW)
	if level >= 6:
		_crane_platform(m, Vector3(0.475, top + 0.45, 0), axis_y + _hull_radius(profile, 0.475 - stern) * scale)
	if level >= 7:
		# The launch skiff circles above the gantries and the platform.
		Parts.escort_skiff(p, 1.55, top + 1.0, 0.5, Vector3.ZERO, 1.5)


## The engine bank on the drydock's stern from 3 (_drydock's), `stern` the hull's aft end on its
## axis: a block in the tier's plating, three engine bells out of it ringed in light (cyan, violet
## from the Obsidian tier) with their nozzles glowing; at 7 gold fins, the antimatter reactor
## glowing in a band round the stern and under a gold-ringed blister on its top, where the camera
## sees it.
static func _engine_bank(m: LowPolyMesh, stern: Vector3, scale: float, tier: int, level: int) -> void:
	var out := Vector3(0, 0, 90)
	m.box_chamfered(Vector3(0.3, 0.5 * scale, 0.7 * scale), 0.05, stern + Vector3(0.12, -0.25 * scale, 0),
		_plating(tier, Parts.GUNMETAL))
	for spec: Vector3 in [Vector3(0, 0.1, -0.2), Vector3(0, 0.1, 0.2), Vector3(0, -0.14, 0)]:
		var bell := stern + spec * scale
		m.prism(0.11, 0.16, 0.24, 16, bell + Vector3(-0.02, 0, 0), _plating(tier, Parts.GUNMETAL, true), out)
		m.ring(0.16, 0.185, 0.06, 16, bell + Vector3(-0.2, 0, 0), _glow(tier), out)
		m.disc(0.13, 16, bell + Vector3(-0.261, 0, 0), GLOW_PULSE.phased(0.25), out)
	if level < 7:
		return
	# Gold fins: two up and out over the stern, two out to the sides and down.
	for fin: Vector3 in [Vector3(0, 0.71, 0.71), Vector3(0, 0.71, -0.71), Vector3(0, -0.5, 0.87), Vector3(0, -0.5, -0.87)]:
		var root := stern + Vector3(0.45, 0, 0) + fin * 0.42 * scale
		var tip := root + fin * 0.34 + Vector3(-0.3, 0, 0)
		var back := root + Vector3(-0.42, 0, 0)
		var front := root + Vector3(0.35, 0, 0)
		var t := Vector3(0, -fin.z, fin.y) * 0.02
		m.polygon(PackedVector3Array([front + t, back + t, tip + t]), Parts.GOLD_TRIM)
		m.polygon(PackedVector3Array([front - t, tip - t, back - t]), Parts.GOLD_TRIM)
		m.polygon(PackedVector3Array([front + t, tip + t, tip - t, front - t]), Parts.GOLD_TRIM)
		m.polygon(PackedVector3Array([back - t, tip - t, tip + t, back + t]), Parts.GOLD_TRIM)
	# The reactor: a broad band of the core round the stern, a blister of it on top in a gold ring,
	# aft of the first gantry's reach.
	m.lathe(PackedVector2Array([Vector2(0.45 * scale, 0), Vector2(0.5 * scale, 0.26)]), 24, stern + Vector3(0.06, 0, 0),
		BRIGHT_CORE, Vector3(0, 0, -90))
	var blister := stern + Vector3(0.36, 0.5 * scale - 0.05, 0)
	Parts.torus(m, 0.22, 0.04, 16, 6, blister, GOLD_ROUND)
	m.dome(0.22, 0.2, 16, 4, blister + Vector3(0, 0.03, 0), BRIGHT_CORE)


## Obsidian plates along the hull's spine from 5 (_drydock's), `stern` the hull's aft end on its
## axis, each with a violet vein down it, and a broad violet band glowing beside them on the chrome
## flank the camera sees; at Crown the band is the antimatter reactor's light violet, and gold
## filigree bands go round the hull at the plates' ends.
static func _hull_plates(m: LowPolyMesh, profile: PackedVector2Array, stern: Vector3, scale: float, crown: bool) -> void:
	for plate: Vector2 in [Vector2(0.55, 1.4), Vector2(1.6, 2.4)]:
		_hull_strip(m, profile, stern, scale, plate, 0.012, Vector2(150, 210), Parts.OBSIDIAN_ROUND)
		_hull_strip(m, profile, stern, scale, plate + Vector2(0.06, -0.06), 0.022, Vector2(170, 190), Parts.VEINS)
		_hull_strip(m, profile, stern, scale, plate + Vector2(0.06, -0.06), 0.014, Vector2(106, 134),
			BRIGHT_CORE if crown else VIOLET_PANEL)
		if crown:
			for along: float in [plate.x - 0.05, plate.y]:
				_hull_strip(m, profile, stern, scale, Vector2(along, along + 0.05), 0.026, Vector2(0, 360), FILIGREE_ROUND)


## A strip over the hull from `along.x` to `along.y` from the stern (on its axis at `stern`),
## `proud` off it, swept round the hull between `degrees.x` and `degrees.y` (0 underneath, 90 to
## the camera's side, 180 on top).
static func _hull_strip(m: LowPolyMesh, profile: PackedVector2Array, stern: Vector3, scale: float, along: Vector2,
		proud: float, degrees: Vector2, surface: Surf) -> void:
	var section := PackedVector2Array()
	for k: int in 4:
		var at := lerpf(along.x, along.y, k / 3.0)
		section.append(Vector2(_hull_radius(profile, at) * scale + proud, at - along.x))
	m.lathe(section, 24, stern + Vector3(along.x, 0, 0), surface, Vector3(0, 0, -90), degrees.x, degrees.y)


## The crane platform hovering over the hull from 6, `at` its middle, above the gantries' beams
## between two of them: an obsidian deck rimmed in violet, a violet grid glowing on its top, a
## chrome crane cab on it, crystal lamps on its corners and a violet hologram tractor beam down to
## the hull's top at `hull_top`, every part bobbing with it (HOVER's phase).
static func _crane_platform(m: LowPolyMesh, at: Vector3, hull_top: float) -> void:
	m.box_chamfered(Vector3(0.6, 0.12, 1.3), 0.04, at, HOVER_PLATE)
	m.box(Vector3(0.62, 0.05, 1.32), at + Vector3(0, 0.03, 0), HOVER_RIM)
	m.box(Vector3(0.44, 0.01, 1.1), at + Vector3(0, 0.12, 0), HOVER_RIM)
	m.box_chamfered(Vector3(0.3, 0.2, 0.36), 0.04, at + Vector3(0, 0.12, -0.3), HOVER_CHROME)
	m.box(Vector3(0.24, 0.08, 0.01), at + Vector3(0, 0.2, -0.115), DRONE_EYE)
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		m.cone(0.05, 0.18, 8, at + Vector3(corner.x * 0.24, 0.12, corner.y * 0.58), HOVER_CRYSTAL)
	var drop := at.y - hull_top - 0.04
	m.prism(0.2, 0.1, drop, 12, at - Vector3(0, drop, 0), HOLO_VIOLET.phased(0.6))


## A welding point on the hull: a glowing arc flashing, `phase` into its blink, with hot sparks
## (`sparks`, hazard yellow unless given) flickering and shaking off it.
static func _weld(m: LowPolyMesh, spot: Vector3, phase: float, sparks_surf: Surf = SPARK_ARC) -> void:
	m.orb(0.08, 16, 6, spot, WELD_BLINK.phased(phase))
	var sparks: Array[Vector3] = [
		Vector3(1, 0.7, 0.3), Vector3(-0.4, 0.8, 0.9), Vector3(0.2, 0.6, -1), Vector3(-1, 0.5, -0.2),
		Vector3(0.6, 0.9, -0.5), Vector3(-0.3, 0.7, -0.8),
	]
	for i: int in sparks.size():
		var spark := sparks[i]
		m.cone(0.025, 0.18, 8, spot + spark.normalized() * 0.06,
			sparks_surf.phased(fposmod(phase + i / 6.0 + 0.05, 1.0)), Parts.facing(spark))


## The radius of the hull's `profile` at `along` from the stern, between its points.
static func _hull_radius(profile: PackedVector2Array, along: float) -> float:
	for i: int in profile.size() - 1:
		var a := profile[i]
		var b := profile[i + 1]
		if along <= b.y:
			return lerpf(a.x, b.x, clampf((along - a.y) / (b.y - a.y), 0.0, 1.0))
	return 0.0


## A transmitter tower: four legs tapering to an emitter orb, braced, ringed with lights, a
## big dish on its flank. Taller with a ring of lights more at each level. The rings blink in a
## chase up the tower, the dish circles it slowly on a collar, and the orb pulses and floats
## under a hologram halo.
##
## From 4 the tower climbs faster and the dish's collar sits between two rings: L4 chrome legs,
## base and ring housings, the rings' lights cyan; L5 a bigger dish and a broad band of light
## under each ring; L6 obsidian legs with violet veins down their faces, the rings' lights violet,
## a crystal emitter orb and an obsidian ring hovering round the tower's upper reach, turning,
## rimmed in violet; L7 gold filigree legs, the orb the antimatter core's bright violet
## under a gold halo and a violet hologram beam rising from it.
static func build_alliance_beacon(p: Parts, level: int) -> void:
	var m := p.body
	var g := Parts.PAD_HEIGHT
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	Parts.foundation(m, 3)
	m.box_chamfered(Vector3(1.9, 0.22, 1.9), 0.06, Vector3(0, g, 0), _plating(p.tier, ARMOUR))
	if obsidian:
		# A violet band glowing round the obsidian base, on the faces the camera sees.
		m.box(Vector3(1.7, 0.08, 0.02), Vector3(0, g + 0.07, 0.951), VIOLET_PANEL)
		m.box(Vector3(0.02, 0.08, 1.7), Vector3(0.951, g + 0.07, 0), VIOLET_PANEL)
	var foot := g + 0.22
	m.box_chamfered(Vector3(1.3, 0.14, 1.3), 0.05, Vector3(0, foot, 0), Parts.HULL_DARK)
	foot += 0.14
	var height := 1.0 + 0.21 * level
	if level >= 4:
		var heights: Array[float] = [2.2, 2.5, 2.85, 3.0]
		height = heights[mini(level, 7) - 4]
	var top := foot + height
	var base := 0.5
	var crown_width := 0.13
	# The dish's collar, at 0.4 of the height; from 4 half way between the two rings round it.
	var seat := 0.4
	if level >= 4:
		seat = (floorf(0.4 * (level + 1)) + 0.5) / (level + 1)
	var mount := foot + height * seat
	var leg := Parts.HULL_LIGHT
	if crown:
		leg = FILIGREE_LEG
	elif obsidian:
		leg = Parts.OBSIDIAN
	elif chrome:
		leg = Parts.CHROME
	var corners: Array[Vector2] = [Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
	for c: Vector2 in corners:
		Parts.beam(m, Vector3(c.x * base, foot, c.y * base), Vector3(c.x * crown_width, top, c.y * crown_width), 0.12,
			leg)
		if obsidian and not crown:
			# A violet vein down the leg's outer edge, standing proud of it, in two runs that stop
			# short of the turning dish collar's band.
			var out := Vector3(c.x, 0, c.y) * 0.06
			var low := Vector3(c.x * base, foot, c.y * base)
			var high := Vector3(c.x * crown_width, top, c.y * crown_width)
			for run: Vector2 in [Vector2(0.1, mount - 0.14 - foot), Vector2(mount + 0.14 - foot, height - 0.1)]:
				Parts.beam(m, low.lerp(high, run.x / height) + out, low.lerp(high, run.y / height) + out, 0.08,
					VIOLET_PANEL, 0.01)
	# Cross braces between the rings.
	var stops := PackedFloat32Array([0.0])
	for i: int in level:
		stops.append(float(i + 1) / (level + 1))
	stops.append(1.0)
	for k: int in stops.size() - 1:
		var lower := stops[k]
		var upper := stops[k + 1]
		for i: int in 4:
			var a := corners[i]
			var b := corners[(i + 1) % 4]
			var wl := lerpf(base, crown_width, lower)
			var wu := lerpf(base, crown_width, upper)
			m.strut(Vector3(a.x * wl, foot + height * lower, a.y * wl),
				Vector3(b.x * wu, foot + height * upper, b.y * wu), 0.04, Parts.ROD)
	# The rings of lights, blinking in turn from the bottom up.
	var rings := stops.size() - 2
	var lamp := LAMP
	if obsidian:
		lamp = VIOLET_LAMP
	elif chrome:
		lamp = CYAN_LAMP
	for k: int in range(1, stops.size() - 1):
		var y := foot + height * stops[k]
		var radius := lerpf(base, crown_width, stops[k]) * 1.42 + 0.1
		m.ring(radius - 0.12, radius, 0.08, 24, Vector3(0, y - 0.04, 0), Parts.CHROME_ROUND if chrome else ARMOUR_ROUND)
		m.ring(radius, radius + 0.035, 0.05, 24, Vector3(0, y - 0.025, 0),
			lamp.phased(fposmod(-float(k - 1) / rings, 1.0)))
		if level >= 5:
			# From 5 a broad band of light under each ring, cyan, violet from the Obsidian tier.
			m.ring(radius - 0.01, radius + 0.06, 0.07, 24, Vector3(0, y - 0.11, 0), _glow(p.tier).phased(k / 8.0))
	# The big dish facing out from the tower on a collar that turns about it, between the rings
	# of lights at every level, so the dish circles the tower slowly; bigger from 5.
	var collar := lerpf(base, crown_width, seat) * 1.42 + 0.1
	var dish := p.moving(Vector3(0, mount, 0), Motion.spin(Vector3.UP, 0.35))
	dish.ring(collar - 0.12, collar, 0.08, 24, Vector3(0, -0.04, 0), Parts.CHROME_ROUND if chrome else ARMOUR_ROUND)
	Parts.beam(dish, Vector3(collar - 0.02, 0, 0), Vector3(collar + 0.2, 0, 0), 0.1, Parts.CHROME if chrome else Parts.GUNMETAL)
	var tilt := Vector3(55, 90, 0)
	var dish_centre := Vector3(collar + 0.2, 0, 0)
	var size := 0.62 if level < 5 else 0.76
	Parts.dish(dish, size, 0.24 if level < 5 else 0.3, dish_centre, GOLD_ROUND if gold else HULL_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	Parts.pipe(dish, dish_centre + axis * 0.1, dish_centre + axis * (0.55 if level < 5 else 0.66), 0.025, Parts.ROD)
	dish.orb(0.06, 16, 6, dish_centre + axis * (0.55 if level < 5 else 0.66), CYAN_LAMP if chrome else GLOW)
	# The emitter at the top: a collar, the orb and its spike floating over it, and a hologram
	# halo floating over them out of step.
	m.prism(0.2, 0.16, 0.12, 16, Vector3(0, top, 0), GOLD_ROUND if gold else Parts.GUNMETAL)
	m.ring(0.2, 0.3, 0.06, 24, Vector3(0, top + 0.12, 0), ORANGE_ROUND)
	# The orb rests a bob's height over the collar, so it never sinks into it.
	var orb := 0.17 + 0.02 * level
	var lift := top + 0.12 + 0.08
	var glow := ORB_BOB
	if crown:
		glow = BRIGHT_ORB
	elif obsidian:
		glow = CRYSTAL_ORB
	m.orb(orb, 16, 8, Vector3(0, lift + orb, 0), glow)
	m.cone(0.05, 0.22, 16, Vector3(0, lift - 0.02 + orb * 2, 0), GOLD_BOB if gold else GUNMETAL_BOB)
	var halo := Vector3(0, lift + 0.12 + orb * 2, 0)
	if crown:
		# The gold halo over the core, and the hologram beam rising out of it.
		Parts.torus(m, 0.3, 0.035, 24, 8, halo, GOLD_BOB.phased(0.5))
		m.prism(0.1, 0.26, 0.42, 16, halo + Vector3(0, 0.06, 0), HOLO_VIOLET)
	else:
		m.ring(0.2, 0.26, 0.03, 24, halo, HOLOGRAM.phased(0.5))
	if level >= 6:
		# The obsidian ring hovering round the tower's upper reach, between two rings of lights,
		# turning slowly, rimmed in violet.
		var share := (level - 0.5) / (level + 1)
		var hover := p.moving(Vector3(0, foot + height * share - 0.03, 0), Motion.spin(Vector3.UP, -0.5))
		hover.ring(0.5, 0.64, 0.06, 24, Vector3.ZERO, HOVER)
		hover.lathe(PackedVector2Array([Vector2(0.645, 0.01), Vector2(0.645, 0.05)]), 24, Vector3.ZERO, HOVER_RIM)
		hover.lathe(PackedVector2Array([Vector2(0.62, 0.062), Vector2(0.52, 0.062)]), 24, Vector3.ZERO, HOVER_RIM)
		for k: int in 4:
			hover.cone(0.04, 0.16, 8, Parts.around(0.57, 90.0 * k, 0.06), HOVER_CRYSTAL)
