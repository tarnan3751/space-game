extends RefCounted
## Models of the resource buildings: the drone bay, the collectors and the storage, each on
## the concrete foundation pad. Each carries its resource's colour (metal, crystal,
## antimatter) as its accent and its glow; the drone bay's is energy cyan, the HUD's drones.
##
## The drone bay and the collectors are modelled to their top levels, the top one Crown tier
## (BuildingModels.tier_of): from the Chrome tier their parts follow the level and their paint the
## tier, chrome with cyan strips, then obsidian with violet veins and a hovering element, then gold
## filigree, the antimatter core and a robot of their own as the fourth moving part, but for the
## drone bay and the siphon, which have none (docs/reference/art-style.md, **Tiers**), within 5
## units. So are the storages: the metal and crystal silos to L10, the
## antimatter vault to L8.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.


## The drone bay's glow is energy cyan, the HUD's colour for drones.
static var BAY_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var BAY_WINDOWS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ENERGY, 2.0, Surf.GLOSSY)
static var DECK_PLATE := Surf.make(MaterialKit.Layer.GRATING, MaterialKit.HULL_MID, 2.0)
static var CRATE := Surf.make(MaterialKit.Layer.HULL_DENSE, MaterialKit.HULL_MID, 2.0)
static var HAZARD_RING := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 1.0, Surf.LIT, true)
## The deck's landing lights, which blink in a chase round it, and the booth's scrolling screen.
static var BAY_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var BAY_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ENERGY, 3.0, Surf.FLOW, false, true, 0.6)
## The parked drone is the construction drone (DroneModels.add_drone), idling.
const DroneModels := preload("res://src/game/models/drone.gd")

## The drone bay's landing deck: its middle and the height of its top.
const BAY_DECK := Vector3(0.2, 0.0, 0.2)
const BAY_DECK_TOP := 0.26
## The second cradle's raised pad from L2, over the crates: its middle and the height of its top,
## and how far out its four legs stand from its middle along each axis.
const BAY_PAD := Vector3(0.52, 0.0, -0.56)
const BAY_PAD_TOP := 0.86
const BAY_PAD_LEGS := 0.3

## The high levels' own: the L2 landing strips' lamps chasing round the deck (cyan; violet at the
## Crown tier, between gold ones); the L3 gold trim on each parked drone's saucer, bobbing with
## it on the parked drone's phase; and the L3 beacon's lenses and its core, violet.
static var BAY_STRIP_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK)
static var BAY_CORE_LAMP := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.BLINK)
static var PARKED_GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true,
	DroneModels.PARKED_PHASE)
static var CORE_BEACON := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT, true)


## An open landing deck with a hazard ring and a chase of landing lights, the builder drone
## idling over its docking cradle, its rotors a spinning blur, a raised control booth on the far corner
## with a scrolling screen and a rotating beacon on its roof, a fuel tank and a stack of
## crates. The booth's roof is gold from the Gold tier.
##
## L2 (Chrome): the deck plated in chrome, its landing lights become a chase of landing strips
## round its rim with two cyan strips across it, a raised chrome pad over the crates carrying a
## second cradle and a second parked drone (builders stay one: it is for show), and the booth clad
## in chrome under a chrome roof. L3 (Crown): the deck edged in gold filigree, the strips violet
## and gold, both drones gold-trimmed, and a violet core pulsing on a gold mount over the booth's
## beacon, whose lenses turn violet. It has no escort: its own drones are its life.
static func build_drone_bay(p: Parts, level: int) -> void:
	var m := p.body
	var crown := p.tier >= Parts.Tier.CROWN
	var deck_plating := Parts.CHROME_ROUND if p.tier >= Parts.Tier.CHROME else Parts.HULL_MID_ROUND
	Parts.foundation(m, 2)
	# The deck at 16 sides, its hazard ring a flat band, and the landing lights at the small-part
	# side counts, a housing 10 round and a lens 8 round (Parts.landing_light's 16 are over the
	# bay's budget with the drone).
	m.lathe(PackedVector2Array([
		Vector2(0.66, 0), Vector2(0.66, 0.1), Vector2(0.62, BAY_DECK_TOP - Parts.PAD_HEIGHT),
		Vector2(0, BAY_DECK_TOP - Parts.PAD_HEIGHT),
	]), 16, BAY_DECK + Vector3(0, Parts.PAD_HEIGHT, 0), deck_plating)
	var top := BAY_DECK + Vector3(0, BAY_DECK_TOP, 0)
	m.disc(0.5, 16, top + Vector3(0, 0.005, 0), DECK_PLATE)
	m.lathe(PackedVector2Array([Vector2(0.56, 0.02), Vector2(0.44, 0.02)]), 16, top, HAZARD_RING)
	if level < 2:
		for k: int in 6:
			var light := top + Parts.around(0.6, 30 + 60 * k, 0)
			m.prism(0.09, 0.0765, 0.045, 10, light, Parts.GUNMETAL)
			m.dome(0.063, 0.063, 8, 3, light + Vector3(0, 0.045, 0), BAY_LAMP.phased(k / 6.0))
	else:
		_landing_strips(m, top, crown)
	if level >= 3:
		m.lathe(PackedVector2Array([Vector2(0.675, 0.12), Vector2(0.675, 0.2), Vector2(0.63, 0.2)]), 16,
			BAY_DECK + Vector3(0, Parts.PAD_HEIGHT - 0.06, 0), Parts.FILIGREE)
	_cradle(m, top)
	# High enough that at the bottom of its bob its tool arm's lens just clears the deck.
	DroneModels.add_drone(m, top + Vector3(0, 0.28, 0), true)
	if level >= 2:
		_raised_pad(m, level, p.tier)
	if level >= 3:
		for at: Vector3 in [top, BAY_PAD + Vector3(0, BAY_PAD_TOP, 0)]:
			# Over the saucer's top shoulder, round the canopy.
			m.ring(0.095, 0.16, 0.03, 12, at + Vector3(0, 0.28 + 0.06, 0), PARKED_GOLD)

	# The control booth on the far corner: a column, a glazed cab, a roof rimmed gold from the
	# Gold tier, and a ladder. From L2 the column and the cab are clad in chrome under a chrome
	# roof, gold again at the Crown tier.
	var cladding := Parts.CHROME if p.tier >= Parts.Tier.CHROME else Parts.HULL_LIGHT
	var booth := Vector3(-0.5, Parts.PAD_HEIGHT, -0.5)
	m.box_chamfered(Vector3(0.44, 0.7, 0.44), 0.05, booth, cladding)
	var cab := booth + Vector3(0, 0.7, 0)
	m.box_chamfered(Vector3(0.62, 0.34, 0.62), 0.06, cab, cladding)
	m.box(Vector3(0.64, 0.14, 0.64), cab + Vector3(0, 0.12, 0), BAY_WINDOWS)
	m.box(Vector3(0.28, 0.2, 0.02), booth + Vector3(0, 0.36, 0.22), BAY_SCREEN)
	var roof := Parts.HULL_MID
	if crown or p.tier == Parts.Tier.GOLD:
		roof = Parts.GOLD_TRIM
	elif p.tier >= Parts.Tier.CHROME:
		roof = Parts.CHROME
	m.box_chamfered(Vector3(0.68, 0.06, 0.68), 0.03, cab + Vector3(0, 0.34, 0), roof)
	Parts.ladder(m, booth + Vector3(0.24, 0, 0.05), 0.7, 0.2, 90.0, Parts.ROD)
	if level >= 2:
		# A second screen on the cab's front under the windows, and a cyan strip up the column's
		# corner facing the camera.
		m.box(Vector3(0.36, 0.06, 0.02), cab + Vector3(0, 0.03, 0.31), BAY_SCREEN.phased(0.7))
		m.box(Vector3(0.08, 0.56, 0.06), booth + Vector3(0.19, 0.08, 0.19), Parts.CORE_GLOW if crown else Parts.CYAN_STRIP,
			Vector3(0, 45, 0))
	var beacon := cab + Vector3(0, 0.4, 0)
	_beacon(p.moving(beacon, Motion.spin(Vector3.UP, 2.4)), CORE_BEACON if crown else BAY_GLOW)
	if level >= 3:
		# The violet core over the beacon, on a gold mount: the bay's crown.
		m.prism(0.03, 0.02, 0.2, 8, beacon + Vector3(0, 0.24, 0), Parts.ROD)
		m.ring(0.05, 0.09, 0.04, 12, beacon + Vector3(0, 0.42, 0), Parts.GOLD_ROUND)
		m.orb(0.09, 12, 6, beacon + Vector3(0, 0.52, 0), Parts.CORE_GLOW)

	# A fuel tank on the left corner, crates on the right.
	var tank := Vector3(-0.58, Parts.PAD_HEIGHT, 0.5)
	for end: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.24, 0.1, 0.08), 0.02, tank + Vector3(0, 0, end * 0.14), Parts.HULL_DARK)
	m.tube(0, 0.13, 0.5, 12, tank + Vector3(0, 0.2, -0.25), Parts.HULL_LIGHT_ROUND, Vector3(90, 0, 0))
	m.box_chamfered(Vector3(0.3, 0.26, 0.3), 0.04, Vector3(0.55, Parts.PAD_HEIGHT, -0.55), CRATE, Vector3(0, 20, 0))
	m.box_chamfered(Vector3(0.22, 0.2, 0.22), 0.04, Vector3(0.6, Parts.PAD_HEIGHT + 0.26, -0.52), CRATE, Vector3(0, -10, 0))


## The docking cradle on a deck whose top is `top`: two rails under the drone, either side of its
## tool arm, and a clamp past each end, clear of the arm's lens.
static func _cradle(m: LowPolyMesh, top: Vector3) -> void:
	for side: float in [-1.0, 1.0]:
		var rail := top + LowPolyMesh.turn(Vector3(side * 0.13, 0, 0), Vector3(0, 45, 0))
		m.box_chamfered(Vector3(0.07, 0.06, 0.5), 0.02, rail, Parts.GUNMETAL, Vector3(0, 45, 0))
		var clamp_pos := top + LowPolyMesh.turn(Vector3(0, 0, side * 0.33), Vector3(0, 45, 0))
		m.box_chamfered(Vector3(0.16, 0.16, 0.06), 0.02, clamp_pos, Parts.HAZARD, Vector3(0, 45, 0))


## The landing strips from L2 round the deck's rim, lit in turn (a chase), where L1's six lights
## stood, and two strips across the deck either side of the cradle; at the Crown tier the rim's
## strips are violet between gold ones and the strips across are gold.
static func _landing_strips(m: LowPolyMesh, top: Vector3, crown: bool) -> void:
	for k: int in 12:
		var degrees := 15.0 + 30.0 * k
		var yaw := Vector3(0, 90.0 - degrees, 0)
		var at := top + Parts.around(0.6, degrees, 0)
		if k % 2 == 0:
			m.box(Vector3(0.18, 0.03, 0.07), at, (BAY_CORE_LAMP if crown else BAY_STRIP_LAMP).phased(Parts.chase(k / 2, 6)), yaw)
		elif crown:
			m.box(Vector3(0.14, 0.025, 0.05), at, Parts.GOLD_TRIM, yaw)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.06, 0.012, 0.62), top + LowPolyMesh.turn(Vector3(side * 0.33, 0.005, 0), Vector3(0, 45, 0)),
			Parts.GOLD_TRIM if crown else Parts.CYAN_STRIP, Vector3(0, 45, 0))


## The second cradle's raised pad from L2, over the crates: four chrome legs braced under a round
## deck with a hazard ring, the cradle and the second parked drone on it.
static func _raised_pad(m: LowPolyMesh, level: int, tier: int) -> void:
	var plating := Parts.CHROME_ROUND if tier >= Parts.Tier.CHROME else Parts.HULL_MID_ROUND
	var legs := Parts.CHROME if tier >= Parts.Tier.CHROME else Parts.HULL_MID
	var deck := BAY_PAD + Vector3(0, BAY_PAD_TOP - 0.1, 0)
	for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var foot := BAY_PAD + Vector3(corner.x * BAY_PAD_LEGS, Parts.PAD_HEIGHT, corner.y * BAY_PAD_LEGS)
		m.box(Vector3(0.07, deck.y - foot.y, 0.07), foot, legs)
	m.lathe(PackedVector2Array([
		Vector2(0.4, 0), Vector2(0.4, 0.06), Vector2(0.37, 0.1), Vector2(0, 0.1),
	]), 16, deck, plating)
	var top := BAY_PAD + Vector3(0, BAY_PAD_TOP, 0)
	m.lathe(PackedVector2Array([Vector2(0.36, 0.008), Vector2(0.28, 0.008)]), 16, top, HAZARD_RING)
	if level >= 3:
		m.lathe(PackedVector2Array([Vector2(0.41, 0.0), Vector2(0.41, 0.06)]), 16, deck, Parts.FILIGREE)
	_cradle(m, top)
	DroneModels.add_drone(m, top + Vector3(0, 0.28, 0), true)


## The booth's rotating beacon: a dark housing with two lenses glowing in `glow` back to back under a cap.
static func _beacon(s: LowPolyMesh, glow: Surf) -> void:
	s.prism(0.1, 0.09, 0.05, 12, Vector3.ZERO, Parts.HULL_DARK_ROUND)
	s.prism(0.06, 0.06, 0.14, 12, Vector3(0, 0.05, 0), glow)
	for side: float in [-1.0, 1.0]:
		s.box(Vector3(0.09, 0.12, 0.06), Vector3(side * 0.07, 0.06, 0), glow, Vector3(0, 90, 0))
	s.prism(0.11, 0.08, 0.05, 12, Vector3(0, 0.19, 0), Parts.HULL_DARK_ROUND)


## Each resource building's accent (a lit plate) and its emissive, in its resource's colour.
static var METAL_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL)
static var METAL_ACCENT_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL, 1.0, Surf.LIT, true)
static var METAL_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.METAL, 1.0, Surf.UNLIT, true)
static var METAL_ORE := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.METAL, 2.0, Surf.PULSE)
## The ore nuggets riding the conveyors, pulsing.
static var NUGGET := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.METAL, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var CRYSTAL_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.CRYSTAL)
## The emitter's prongs: too thin for the outline.
static var CRYSTAL_PRONG := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.CRYSTAL, 1.0, Surf.LIT, false, false)
static var CRYSTAL_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT, true)
## The shards pulse, each on a phase of its own.
static var CRYSTAL_SHARD := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.5, Surf.GLOSSY | Surf.PULSE)
## A laser beam: a solid, steady glow, white-hot over the crystal pink so it reads against the
## shards it cuts; no outline, which would darken a part this thin.
const HOT_CRYSTAL := Color("f6dcff")
static var CRYSTAL_BEAM := Surf.make(MaterialKit.Layer.GLOW, HOT_CRYSTAL, 1.0, Surf.UNLIT, true, false)
## The sparks where the beam cuts, and the L4 pylons' lamps, which blink in a chase.
static var CUT_SPARK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLICKER)
static var CRYSTAL_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var LEG := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
## The conveyor belt: grating running up towards the hopper.
static var BELT := Surf.make(MaterialKit.Layer.GRATING, MaterialKit.GUNMETAL, 3.0, Surf.FLOW, false, true, 0.7)
static var STACK := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var SOOT := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.INK)
static var ENGINE_VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 2.0)
static var ROCK := Surf.make(MaterialKit.Layer.ROCK, MaterialKit.ROCK_LIT)
static var DRILL_BIT := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_LIGHT, 3.0, Surf.LIT, true)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var PYLON_ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)

## The metal extractor's drill axis, its derrick's legs (degrees around the axis, meeting
## LEG_TOP from the axis under the crown), the derrick's height by level, and the share of the
## legs' height the drill's top drive reaches (low enough that its sweep clears the legs).
const DRILL := Vector3(-0.3, 0, -0.3)
const DERRICK_LEGS := [80.0, 200.0, 320.0]
const DERRICK_HEIGHTS := [1.65, 1.75, 1.95, 2.05, 2.15, 2.75, 2.95, 3.3, 3.5, 3.8]
const LEG_TOP := 0.22
const DRIVE_TOP := 0.75
const BRACE := 0.42
## The second ring of braces from L6, higher up the legs.
const UPPER_BRACE := 0.7
## Its hoppers (the second from L4, each fed by a conveyor from the collar), the height of a
## hopper's rim, and the exhaust stacks on its engine house by level:
## [x, z, height above the roof].
const HOPPERS := [Vector3(-0.82, 0, 0.8), Vector3(0.55, 0, 0.95)]
const HOPPER_RIM := 0.72
const ENGINE_HOUSE := Vector3(0.8, 0, 0.05)
const STACKS := [[0.95, -0.15, 0.7], [0.98, 0.25, 0.85], [0.62, -0.2, 0.55]]
## The walking beam on the derrick's crown: its pin's height over the crown block's foot, its
## length, and its swing. It lies across the camera's view (ACROSS) and rocks about the
## horizontal axis square to it (ROCKER_AXIS), so it is seen in profile.
const ROCKER_PIN := 0.62
const ROCKER_LENGTH := 0.9
const ACROSS := Vector3(0.70710678, 0, -0.70710678)
const ROCKER_AXIS := Vector3(0.70710678, 0, 0.70710678)
## The L7 pumpjack on the right corner, its pin's height over the pad and its walking beam's
## length, rocking out of step with the derrick's.
const PUMPJACK := Vector3(0.95, 0, -0.95)
const PUMPJACK_PIN := 0.7
const PUMPJACK_LENGTH := 0.62
## The L9 collar hovering round the derrick, this far under the crown block's foot.
const COLLAR_DROP := 0.4
## The L10 ore hauler's track over the first hopper's conveyor, across the camera's view: where
## its middle is at either end, along the line from the drill to that hopper (the near end inside
## the derrick, between its legs, over the drill's auger; the far end over the hopper), and how
## high; and how far the track lies to the side of the belt's line, away from the derrick's leg it
## passes.
const HAULER_NEAR := 0.66
const HAULER_FAR := 1.2
const HAULER_NEAR_HEIGHT := 1.3
const HAULER_FAR_HEIGHT := 1.55
const HAULER_ASIDE := 0.05
## Seconds for a round trip, drill to hopper and back, and the hauler's size, so it reads at the
## gameplay zoom.
const HAULER_PERIOD := 5.0
const HAULER_SCALE := 1.35
## The L10 antimatter core on the engine house's roof, clear of its stacks.
const HOUSE_CORE := Vector3(0.62, 0, 0.27)

## The high levels' own: the L8 ore crystals hovering over the hoppers, metal like all the ore; the
## L9 collar, obsidian with veins across its top and a violet rim, bobbing together; and the
## crystal inlays on the engine house.
static var FLOATING_ORE := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.METAL, 1.0, Surf.GLOSSY | Surf.PULSE | Surf.BOB)
static var HOVER_RING := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
static var HOVER_VEINS := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW | Surf.BOB, true, true,
	0.7)
static var HOVER_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
## The L10 ore hauler's thrusters, pulsing.
static var HAULER_THRUST := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The Crown tier's antimatter core where it is the model's crown (the extractor's crown and engine
## house): the glow layer in a light violet, unlit and steady, so it is the brightest thing on the
## model where CORE_GLOW's pulse would dim it.
const CORE_LIGHT := Color("c9a2ff")
static var BRIGHT_CORE := Surf.make(MaterialKit.Layer.GLOW, CORE_LIGHT, 1.0, Surf.UNLIT, true)


## A drill rig: a tripod derrick over a spinning drill head with a walking beam rocking on its
## crown, a conveyor running pulsing ore up into a hopper with a metal accent strip and
## glowing ore, and an engine house with exhaust stacks puffing smoke. L2 adds a stack and
## armour, L3 a bigger derrick with braces and a winch, L4 a second hopper and a third stack,
## L5 gold trim.
##
## L6 (Chrome): a taller derrick in chrome, cyan strips up its legs and a second ring of braces, its
## crown block clad in chrome; chrome hoppers, each tipping ore down a cyan-lit chute into a tub. L7
## a taller derrick still and a pumpjack on the right corner, its walking beam rocking out of step
## with the crown's. L8 (Obsidian): a taller derrick, still chrome, its strips violet veins;
## obsidian over the hoppers, the chutes' tubs, the pumpjack's frame and the engine house, crystal
## inlays on the house, the drill's kelly veined violet, and an ore crystal hovering over each
## hopper. The ore is the metal accent at every level, as on the silos. L9 an obsidian collar
## hovering round the derrick under its crown. L10 (Crown): gold filigree on the braces, the crown
## block, the hoppers and the engine house, the antimatter core glowing on a gold mount over the
## crown and in a gold housing on the engine house's roof, and an ore hauler shuttling glowing ore
## from the drill to the first hopper over its conveyor as the escort.
static func build_metal_extractor(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown_tier := p.tier >= Parts.Tier.CROWN
	var height: float = DERRICK_HEIGHTS[level - 1]
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.lathe(PackedVector2Array([
		Vector2(0.48, 0), Vector2(0.48, 0.12), Vector2(0.42, 0.18), Vector2(0.3, 0.18),
		Vector2(0.3, 0.1), Vector2(0, 0.1),
	]), 24, DRILL + Vector3(0, ground, 0), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND)

	# The derrick: three legs on foot plates leaning in to a crown block.
	var leg_width := 0.1 if level < 3 else (0.14 if level < 6 else 0.16)
	var leg := Parts.CHROME if p.tier >= Parts.Tier.CHROME else LEG
	var crown := DRILL + Vector3(0, height - 0.04, 0)
	var feet: Array[Vector3] = []
	var tops: Array[Vector3] = []
	for degrees: float in DERRICK_LEGS:
		var foot := DRILL + Parts.around(0.95, degrees, ground)
		var top := DRILL + Parts.around(LEG_TOP, degrees, height)
		feet.append(foot)
		tops.append(top)
		m.box_chamfered(Vector3(0.24, 0.06, 0.24), 0.02, foot, Parts.HULL_DARK, Vector3(0, 90.0 - degrees, 0))
		m.strut(foot, top, leg_width, leg)
		if level >= 6:
			# A light strip up the leg's outer face.
			var out := Parts.around(leg_width * 0.5 + 0.015, degrees, 0)
			m.strut(foot.lerp(top, 0.06) + out, foot.lerp(top, 0.86) + out, 0.05, _rig_strip(p.tier))
	if level >= 3:
		# Braces from leg to leg, BRACE of the way up.
		for k: int in 3:
			var a := feet[k].lerp(tops[k], BRACE)
			var b := feet[(k + 1) % 3].lerp(tops[(k + 1) % 3], BRACE)
			m.strut(a, b, 0.08, Parts.FILIGREE if crown_tier else LEG)
	if level >= 6:
		for k: int in 3:
			var a := feet[k].lerp(tops[k], UPPER_BRACE)
			var b := feet[(k + 1) % 3].lerp(tops[(k + 1) % 3], UPPER_BRACE)
			m.strut(a, b, 0.07, Parts.FILIGREE if crown_tier else leg)
	m.box_chamfered(Vector3(0.6, 0.26, 0.6), 0.05, crown, Parts.CHROME if p.tier >= Parts.Tier.CHROME else Parts.HULL_LIGHT)
	m.box(Vector3(0.62, 0.07, 0.62), crown + Vector3(0, 0.07, 0), METAL_ACCENT)
	if level >= 10:
		m.box(Vector3(0.62, 0.05, 0.62), crown + Vector3(0, 0.17, 0), Parts.FILIGREE)
	if level >= 5:
		m.box_chamfered(Vector3(0.64, 0.06, 0.64), 0.02, crown + Vector3(0, 0.26, 0),
			Parts.GOLD_TRIM if gold else Parts.HULL_MID)
	if level >= 3:
		# The winch on the crown's back corner, along the rocker's axis, clear of its post.
		Parts.pipe(m, crown + Vector3(-0.27, 0.36, -0.27), crown + Vector3(-0.1, 0.36, -0.1), 0.08, Parts.GUNMETAL)
	if level >= 10:
		# The crown: the antimatter core on a gold mount where the landing light stood.
		m.ring(0.04, 0.11, 0.05, 12, crown + Vector3(0.14, 0.26, 0.14), Parts.GOLD_ROUND)
		m.orb(0.12, 12, 6, crown + Vector3(0.14, 0.42, 0.14), BRIGHT_CORE)
	else:
		Parts.landing_light(m, crown + Vector3(0.14, 0.26, 0.14), 0.09, METAL_GLOW)
	# The walking beam's post: an A-frame along the beam on the crown, a pin through its head.
	var pin := crown + Vector3(0, ROCKER_PIN, 0)
	var crown_top := crown.y + (0.32 if level >= 5 else 0.26)
	for side: float in [-1.0, 1.0]:
		Parts.beam(m, Vector3(crown.x, crown_top, crown.z) + ACROSS * 0.2 * side, pin, 0.06, LEG, 0.02)
	Parts.pipe(m, pin - ROCKER_AXIS * 0.08, pin + ROCKER_AXIS * 0.08, 0.05, Parts.GUNMETAL, 12)
	_rocker(p.moving(pin, Motion.swing(ROCKER_AXIS, 12.0, 2.0)), gold)
	if level >= 9:
		# The obsidian collar hovering round the derrick under its crown, bobbing.
		var collar := crown - Vector3(0, COLLAR_DROP, 0)
		m.ring(0.5, 0.66, 0.06, 24, collar, HOVER_RING)
		m.lathe(PackedVector2Array([Vector2(0.64, 0.062), Vector2(0.52, 0.062)]), 24, collar, HOVER_VEINS)
		m.lathe(PackedVector2Array([Vector2(0.665, 0.01), Vector2(0.665, 0.05)]), 24, collar, HOVER_RIM)

	# The hoppers, each with a conveyor from the collar up over its rim.
	for k: int in 2 if level >= 4 else 1:
		var hopper: Vector3 = HOPPERS[k]
		var heading := (hopper - DRILL).normalized()
		_hopper(m, hopper + Vector3(0, ground, 0), gold, 0.5 * k, level, p.tier)
		_belt(m, DRILL + heading * 0.32 + Vector3(0, ground + 0.2, 0),
			hopper - heading * 0.2 + Vector3(0, ground + HOPPER_RIM + 0.14, 0), 0.5 * k, NUGGET)

	# The engine house and its stacks.
	var house := ENGINE_HOUSE + Vector3(0, ground, 0)
	m.box_chamfered(Vector3(0.66, 0.5, 0.8), 0.06, house, Parts.HULL_LIGHT)
	m.box(Vector3(0.4, 0.24, 0.04), house + Vector3(0, 0.12, 0.4), ENGINE_VENT)
	m.box_chamfered(Vector3(0.7, 0.08, 0.84), 0.03, house + Vector3(0, 0.5, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID)
	if level >= 2:
		m.box_chamfered(Vector3(0.72, 0.18, 0.86), 0.04, house, Parts.OBSIDIAN if obsidian else ARMOUR)
	if level >= 8:
		# Obsidian plates on the house's ends, a vein along each, and crystal inlays on its front.
		for end: float in [-1.0, 1.0]:
			m.box_chamfered(Vector3(0.74, 0.26, 0.08), 0.03, house + Vector3(0, 0.2, end * 0.41), Parts.OBSIDIAN)
			m.box(Vector3(0.6, 0.04, 0.09), house + Vector3(0, 0.31, end * 0.41), Parts.VEINS)
		for k: int in 2:
			m.prism(0.07, 0.07, 0.04, 4, house + Vector3(0.37, 0.3, -0.18 + 0.36 * k), INLAY.phased(k * 0.5), Vector3(0, 0, -90))
	if level >= 10:
		m.box(Vector3(0.71, 0.05, 0.85), house + Vector3(0, 0.42, 0), Parts.FILIGREE)
		# The antimatter core in a gold housing on the roof, a pulsing violet ring round it.
		var core := HOUSE_CORE + Vector3(0, house.y + 0.58, 0)
		m.prism(0.16, 0.13, 0.08, 16, core, Parts.GOLD_ROUND)
		m.orb(0.15, 16, 6, core + Vector3(0, 0.22, 0), BRIGHT_CORE)
		Parts.torus(m, 0.17, 0.035, 16, 6, core + Vector3(0, 0.16, 0), Parts.CORE_GLOW)
	var stacks := 1 + (1 if level >= 2 else 0) + (1 if level >= 4 else 0)
	# Two puffs a stack to L5, where three stacks fill the Base budget; Parts.puffs' full column of
	# four from the Chrome tier, whose budget has room for them.
	var puffs := 4 if p.tier >= Parts.Tier.CHROME else 2
	for k: int in stacks:
		var stack: Array = STACKS[k]
		var stack_height: float = stack[2]
		_stack(m, Vector3(stack[0], house.y + 0.58, stack[1]), stack_height, gold, k / 3.0, puffs)

	var pivot := DRILL + Vector3(0, ground + 0.1, 0)
	_drill(p.moving(pivot, Motion.spin(Vector3.UP, 3.0)), crown.y - pivot.y,
		ground + DRIVE_TOP * (height - ground) - pivot.y, gold, Parts.VEINS if obsidian else Parts.GUNMETAL)
	if level >= 7:
		_pumpjack(p, p.tier)
	if level >= 10:
		_ore_hauler(p)


## The L10 ore hauler: a squat hover-hauler shuttling (a slide) on a track climbing over the first
## hopper's conveyor, from inside the derrick over the drill's auger, where it loads, up to over
## the hopper, where it tips; it lingers at either end, as the slide eases. Built facing along its
## track towards the hopper: a chamfered hull banded in gold filigree under a violet core lamp, an
## open gold-lipped bucket at its front heaped with glowing ore, and two thrusters glowing under it.
static func _ore_hauler(p: Parts) -> void:
	var hopper: Vector3 = HOPPERS[0]
	var along := (hopper - DRILL).normalized()
	var aside := Vector3(-along.z, 0, along.x) * HAULER_ASIDE
	var near := DRILL + along * HAULER_NEAR + aside + Vector3(0, HAULER_NEAR_HEIGHT, 0)
	var far := DRILL + along * HAULER_FAR + aside + Vector3(0, HAULER_FAR_HEIGHT, 0)
	var s := p.moving((near + far) * 0.5, Motion.slide(far - near, near.distance_to(far) * 0.5, HAULER_PERIOD))
	var heading := Vector3(0, rad_to_deg(atan2(along.x, along.z)), 0)
	var z := HAULER_SCALE
	s.box_chamfered(Vector3(0.26, 0.13, 0.26) * z, 0.035 * z, LowPolyMesh.turn(Vector3(0, -0.05, -0.06) * z, heading),
		Parts.HULL_MID, heading)
	s.box(Vector3(0.27, 0.035, 0.27) * z, LowPolyMesh.turn(Vector3(0, 0.0, -0.06) * z, heading), Parts.FILIGREE, heading)
	s.box_chamfered(Vector3(0.16, 0.05, 0.12) * z, 0.02 * z, LowPolyMesh.turn(Vector3(0, 0.08, -0.1) * z, heading),
		Parts.HULL_LIGHT, heading)
	s.orb(0.04 * z, 10, 4, LowPolyMesh.turn(Vector3(0, 0.14, -0.1) * z, heading), BRIGHT_CORE)
	# The bucket: a floor, two cheeks and a front lip, rimmed gold, heaped with ore.
	s.box(Vector3(0.24, 0.03, 0.15) * z, LowPolyMesh.turn(Vector3(0, -0.07, 0.14) * z, heading), Parts.GUNMETAL, heading)
	for side: float in [-1.0, 1.0]:
		s.box_chamfered(Vector3(0.03, 0.12, 0.15) * z, 0.01 * z, LowPolyMesh.turn(Vector3(side * 0.12, -0.07, 0.14) * z, heading),
			Parts.GOLD_TRIM, heading)
	s.box_chamfered(Vector3(0.24, 0.1, 0.03) * z, 0.01 * z, LowPolyMesh.turn(Vector3(0, -0.07, 0.22) * z, heading),
		Parts.GOLD_TRIM, heading)
	s.pyramid(0.2 * z, 0.1 * z, LowPolyMesh.turn(Vector3(0, -0.04, 0.14) * z, heading), NUGGET, heading)
	s.box_chamfered(Vector3(0.07, 0.06, 0.07) * z, 0.02 * z, LowPolyMesh.turn(Vector3(0.05, 0.0, 0.11) * z, heading),
		NUGGET.phased(0.5), heading + Vector3(0, 30, 0))
	# The thrusters: a nozzle under each side of the hull, a glow on its mouth.
	for side: float in [-1.0, 1.0]:
		var nozzle := LowPolyMesh.turn(Vector3(side * 0.08, -0.05, -0.1) * z, heading)
		s.prism(0.045 * z, 0.035 * z, 0.04 * z, 10, nozzle, Parts.GUNMETAL, Vector3(180, 0, 0))
		s.disc(0.03 * z, 10, nozzle - Vector3(0, 0.041, 0) * z, HAULER_THRUST, Vector3(180, 0, 0))


## The collectors' armour by tier: obsidian from the Obsidian tier, chrome at the Chrome tier,
## `below` under it.
static func _rig_armour(tier: int, below: Surf) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN
	if tier >= Parts.Tier.CHROME:
		return Parts.CHROME
	return below


## The light strips up the rig by tier: violet veins from the Obsidian tier, cyan below it.
static func _rig_strip(tier: int) -> Surf:
	return Parts.VEINS if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP


## A square hopper on four legs, a metal accent strip round its rim and glowing ore heaped in it.
## From L6 the bin is chrome (obsidian from the Obsidian tier) and tips ore down a lit chute into a
## tub on the pad; from L8 an ore crystal hovers over the heap; at L10 gold filigree bands the bin.
static func _hopper(m: LowPolyMesh, pos: Vector3, gold: bool, phase: float, level: int, tier: int) -> void:
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.box_chamfered(Vector3(0.07, 0.32, 0.07), 0.02, pos + Vector3(corner.x * 0.17, 0, corner.y * 0.17), Parts.GUNMETAL)
	var bin := pos + Vector3(0, HOPPER_RIM - 0.46, 0)
	m.lathe(PackedVector2Array([
		Vector2(0.12, 0), Vector2(0.42, 0.34), Vector2(0.42, 0.46), Vector2(0.36, 0.46),
		Vector2(0.36, 0.38), Vector2(0, 0.38),
	]), 4, bin, _rig_armour(tier, Parts.HULL_MID), Vector3(0, 45, 0))
	m.lathe(PackedVector2Array([Vector2(0.43, 0), Vector2(0.43, 0.08), Vector2(0.36, 0.08)]), 4,
		bin + Vector3(0, 0.36, 0), Parts.GOLD_TRIM if gold else METAL_ACCENT, Vector3(0, 45, 0))
	m.pyramid(0.48, 0.14, bin + Vector3(0, 0.38, 0), METAL_ORE.phased(phase))
	if level >= 10:
		m.lathe(PackedVector2Array([Vector2(0.43, 0), Vector2(0.43, 0.06)]), 4, bin + Vector3(0, 0.27, 0), Parts.FILIGREE,
			Vector3(0, 45, 0))
	if level >= 6:
		# The chute from the bin's front face down towards the camera into a tub, its rails lit.
		_chute(m, bin + Vector3(0, 0.12, 0.2), Vector3(pos.x, Parts.PAD_HEIGHT + 0.24, pos.z + 0.48), _rig_strip(tier),
			NUGGET.phased(phase))
		var tub := Vector3(pos.x, Parts.PAD_HEIGHT, pos.z + 0.52)
		m.box_chamfered(Vector3(0.3, 0.2, 0.22), 0.04, tub, _rig_armour(tier, Parts.HULL_MID))
		m.box(Vector3(0.24, 0.04, 0.16), tub + Vector3(0, 0.18, 0), METAL_ORE.phased(phase + 0.25))
	if level >= 8:
		m.orb(0.1, 4, 2, bin + Vector3(0, 0.74, 0), FLOATING_ORE.phased(phase))


## A chute from `from` down to `to`: a trough between two lit rails, ore sliding down it.
static func _chute(m: LowPolyMesh, from: Vector3, to: Vector3, rail: Surf, ore: Surf) -> void:
	var along := to - from
	var run := Vector2(along.x, along.z)
	var rot := Vector3(-rad_to_deg(atan2(along.y, run.length())), rad_to_deg(atan2(along.x, along.z)), 0)
	var length := along.length()
	var middle := (from + to) * 0.5
	m.box_chamfered(Vector3(0.2, 0.04, length), 0.015, middle, Parts.GUNMETAL, rot)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.035, 0.06, length), middle + LowPolyMesh.turn(Vector3(side * 0.11, 0, 0), rot), rail, rot)
	for t: float in [0.3, 0.7]:
		m.box_chamfered(Vector3(0.1, 0.07, 0.1), 0.03, from.lerp(to, t) + LowPolyMesh.turn(Vector3(0, 0.04, 0), rot), ore,
			rot + Vector3(0, 40 * t, 0))


## A conveyor from `from` up to `to`: a belt running between two rails, pulsing ore on it, a
## trestle under its middle.
static func _belt(m: LowPolyMesh, from: Vector3, to: Vector3, phase: float, nugget: Surf) -> void:
	var along := to - from
	var run := Vector2(along.x, along.z)
	var rot := Vector3(-rad_to_deg(atan2(along.y, run.length())), rad_to_deg(atan2(along.x, along.z)), 0)
	var length := along.length()
	var middle := (from + to) * 0.5
	m.box_chamfered(Vector3(0.26, 0.05, length), 0.015, middle, BELT, rot)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.06, 0.1, length), 0.02, middle + LowPolyMesh.turn(Vector3(side * 0.15, -0.02, 0), rot), Parts.HULL_MID, rot)
	for t: float in [0.25, 0.55, 0.85]:
		m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, from.lerp(to, t) + LowPolyMesh.turn(Vector3(0, 0.05, 0), rot),
			nugget.phased(fposmod(phase + t, 1.0)), rot + Vector3(0, 30 * t, 0))
	var foot := Vector3(middle.x, Parts.PAD_HEIGHT, middle.z)
	m.box(Vector3(0.08, middle.y - foot.y, 0.08), foot, Parts.GUNMETAL)


## An exhaust stack: a collar, a ribbed pipe, a lipped mouth with soot inside, and `puffs` puffs of
## smoke rising from it, climbing, drifting and fading on phases from `phase` (Parts.puffs).
static func _stack(m: LowPolyMesh, pos: Vector3, height: float, gold: bool, phase: float, puffs: int) -> void:
	m.prism(0.14, 0.13, 0.08, 16, pos - Vector3(0, 0.04, 0), Parts.HULL_DARK_ROUND)
	m.prism(0.09, 0.09, height, 16, pos, STACK)
	m.ring(0.07, 0.12, 0.08, 16, pos + Vector3(0, height, 0), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND)
	m.disc(0.07, 16, pos + Vector3(0, height + 0.04, 0), SOOT)
	Parts.puffs(m, pos + Vector3(0, height + 0.08, 0), phase, puffs)


## The walking beam rocking on its pin, built along ACROSS: a beam with a horse head over the
## drill and a counterweight at its other end.
static func _rocker(s: LowPolyMesh, gold: bool) -> void:
	var yaw := Vector3(0, 135, 0)
	var half := ROCKER_LENGTH * 0.5
	s.box_chamfered(Vector3(0.08, 0.08, ROCKER_LENGTH), 0.02, Vector3(0, -0.04, 0), Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT, yaw)
	s.box_chamfered(Vector3(0.1, 0.22, 0.12), 0.03, ACROSS * (half - 0.04) + Vector3(0, -0.16, 0), METAL_ACCENT, yaw)
	s.box_chamfered(Vector3(0.14, 0.16, 0.18), 0.03, ACROSS * -(half - 0.08) + Vector3(0, -0.14, 0), Parts.GUNMETAL, yaw)


## The drill string that spins round the collar: a ribbed bit, auger flights, a square kelly
## `length` tall up into the crown on `kelly`, and a finned round top drive whose top is at
## `drive_top`.
static func _drill(s: LowPolyMesh, length: float, drive_top: float, gold: bool, kelly: Surf) -> void:
	s.lathe(PackedVector2Array([
		Vector2(0.04, -0.04), Vector2(0.18, 0.08), Vector2(0.27, 0.16), Vector2(0.27, 0.24),
		Vector2(0.16, 0.3), Vector2(0, 0.3),
	]), 16, Vector3.ZERO, DRILL_BIT)
	for k: int in 3:
		s.box_chamfered(Vector3(0.44, 0.05, 0.16), 0.02, Vector3(0, 0.36 + 0.14 * k, 0),
			Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT, Vector3(10, 60 * k, 0))
	s.box_chamfered(Vector3(0.12, length - 0.2, 0.12), 0.03, Vector3(0, 0.2, 0), kelly)
	var drive := Vector3(0, drive_top - 0.28, 0)
	s.lathe(PackedVector2Array([
		Vector2(0.15, 0), Vector2(0.15, 0.24), Vector2(0.12, 0.28), Vector2(0, 0.28),
	]), 16, drive, Parts.HULL_MID_ROUND)
	s.lathe(PackedVector2Array([Vector2(0.16, 0), Vector2(0.16, 0.07)]), 16, drive + Vector3(0, 0.15, 0), METAL_ACCENT_ROUND)
	for k: int in 4:
		s.box_chamfered(Vector3(0.06, 0.2, 0.08), 0.02, drive + Parts.around(0.17, 90 * k + 45, 0.02), Parts.HULL_DARK,
			Vector3(0, 45 - 90 * k, 0))


## The L7 pumpjack on the right corner: a skid along ACROSS, an A-frame up to a pin, a motor box
## with a lit vent, and a wellhead under the horse head's end; its walking beam rocks as a moving
## part, out of step with the derrick's.
static func _pumpjack(p: Parts, tier: int) -> void:
	var m := p.body
	var yaw := Vector3(0, 135, 0)
	var frame := _rig_armour(tier, Parts.HULL_MID)
	var base := PUMPJACK + Vector3(0, Parts.PAD_HEIGHT, 0)
	m.box_chamfered(Vector3(0.3, 0.08, 0.72), 0.03, base, Parts.HULL_DARK, yaw)
	var pin := base + Vector3(0, PUMPJACK_PIN, 0)
	for side: float in [-1.0, 1.0]:
		Parts.beam(m, base + Vector3(0, 0.08, 0) + ROCKER_AXIS * 0.12 * side, pin + ROCKER_AXIS * 0.06 * side, 0.06, frame, 0.02)
	Parts.pipe(m, pin - ROCKER_AXIS * 0.1, pin + ROCKER_AXIS * 0.1, 0.045, Parts.GUNMETAL, 12)
	var motor := base + ACROSS * -0.22 + Vector3(0, 0.08, 0)
	m.box_chamfered(Vector3(0.24, 0.22, 0.2), 0.04, motor, Parts.HULL_LIGHT, yaw)
	m.box(Vector3(0.14, 0.06, 0.21), motor + Vector3(0, 0.12, 0), _rig_strip(tier), yaw)
	var well := base + ACROSS * (PUMPJACK_LENGTH * 0.5 - 0.02) + Vector3(0, 0.08, 0)
	m.prism(0.07, 0.06, 0.14, 12, well, Parts.GUNMETAL)
	m.prism(0.022, 0.022, PUMPJACK_PIN - 0.4, 8, well + Vector3(0, 0.14, 0), Parts.ROD)
	var s := p.moving(pin, Motion.swing(ROCKER_AXIS, 14.0, 2.0, 0.5))
	var half := PUMPJACK_LENGTH * 0.5
	s.box_chamfered(Vector3(0.07, 0.07, PUMPJACK_LENGTH), 0.02, Vector3(0, -0.035, 0), Parts.GOLD_TRIM if tier >= Parts.Tier.GOLD else Parts.HULL_LIGHT, yaw)
	s.box_chamfered(Vector3(0.09, 0.2, 0.1), 0.03, ACROSS * (half - 0.03) + Vector3(0, -0.15, 0), METAL_ACCENT, yaw)
	s.box_chamfered(Vector3(0.12, 0.14, 0.16), 0.03, ACROSS * -(half - 0.06) + Vector3(0, -0.13, 0), Parts.GUNMETAL, yaw)


## [x, z, height, radius, tilt x, tilt z] of each crystal shard, in the order levels add them:
## two per level from three at L1, taller the later they come.
const SHARDS := [
	[0.0, 0.0, 1.05, 0.2, 0, 0],
	[-0.3, 0.22, 0.75, 0.15, 10, -16],
	[0.28, -0.2, 0.7, 0.14, -14, 14],
	[0.3, 0.32, 0.6, 0.13, 18, 16],
	[-0.38, -0.28, 0.72, 0.14, -16, -14],
	[0.05, 0.45, 0.62, 0.12, 24, 4],
	[0.48, 0.05, 0.66, 0.12, 2, 24],
	[-0.5, 0.02, 0.6, 0.12, 0, -22],
	[-0.02, -0.5, 0.64, 0.12, -24, 0],
	[0.42, 0.42, 0.5, 0.1, 20, 20],
	[-0.42, 0.42, 0.52, 0.1, 20, -20],
]
## The gantry's two legs, either side of the cluster across the camera's view, and the
## height of its beam by level.
const GANTRY_LEGS := [Vector3(-0.98, 0, 0.98), Vector3(0.98, 0, -0.98)]
const GANTRY_HEIGHTS := [1.9, 1.95, 2.0, 2.05, 2.1, 2.35, 2.45, 2.85, 2.95, 3.1]
## The laser ring over the crystal, on struts from a hub under the gantry's carriage, turning about
## the cluster's axis with the emitters on it: how far under the beam the hub turns, the share of
## the aimed crystal's height the ring rides at (just over its tip, so each emitter sits above and
## outside it and its beam angles down into it), its radius by level (one emitter to L5, two
## opposite from L6; wider as the crystal grows taller, so the beams keep their angle), its
## section's radius and the struts', and its turn (radians a second).
const RING_DROP := 0.32
const RING_SHARE := 1.1
const RING_RADII := [0.7, 0.7, 0.7, 0.7, 0.7, 0.8, 0.8, 1.0, 1.0, 1.0]
const RING_THICKNESS := 0.04
const STRUT_RADIUS := 0.03
const RING_RATE := 0.35
## Where the emitters aim on the crystal they cut (the biggest shard, the mega-shard from L8): this
## share of its height up, on its face towards each emitter, where the beam ends just inside its
## surface (this share of its radius there); at L10 higher, over the mega-shard's gold collar.
const AIM_SHARE := 0.62
const CROWN_AIM_SHARE := 0.77
const AIM_DEPTH := 0.8
## A beam's radius: thick enough to read from the emitters to the crystal at the gameplay zoom.
const BEAM_RADIUS := 0.08
## The L8 vein conduits up the legs, this far out from each leg's middle along the gantry.
const CONDUIT_OUT := 0.18
## The mega-shard that crowns the cluster from L8, in place of the first shard: its height at L8
## and its growth a level, its radius.
const MEGA_HEIGHT := 2.1
const MEGA_GROWTH := 0.1
const MEGA_RADIUS := 0.28
## The L9 ring hovering over the cluster: its radii and its height over the pad.
const HOVER_INNER := 0.62
const HOVER_OUTER := 0.76
const HOVER_HEIGHT := 1.5
## The L10 mega-shard's core band: its foot's height over the pad, clear of the hovering ring at
## the top of its bob.
const CROWN_BAND := 1.68
## The L10 collector's round about the mega-shard, outside the pylons' lamps and inside the
## gantry's legs, over the lamps and under the hovering ring and the beams; its turn, the other way
## from the laser ring's; its size; and the phase its parts bob and pulse on together.
const COLLECTOR_RADIUS := 1.08
const COLLECTOR_HEIGHT := 1.3
const COLLECTOR_RATE := -0.5
const COLLECTOR_SCALE := 1.2
const COLLECTOR_PHASE := 0.4

## The high levels' own: the emitters' beams and lenses, cyan at the Chrome tier and violet from the
## Obsidian tier, the beams white-hot over their tint so they read against the crystal; the
## L8 chips hovering round the mega-shard; and the L10 collector's hull, gold claw, violet eye, the
## cut shard it carries and its thruster, all bobbing together.
const HOT_VIOLET := Color("e4d2ff")
const HOT_CYAN := Color("bcf6ff")
static var CYAN_BEAM := Surf.make(MaterialKit.Layer.GLOW, HOT_CYAN, 1.0, Surf.UNLIT, true, false)
static var VIOLET_BEAM := Surf.make(MaterialKit.Layer.GLOW, HOT_VIOLET, 1.0, Surf.UNLIT, true, false)
static var CYAN_LENS := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, true)
static var VIOLET_LENS := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT, true)
static var CHIP := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.GLOSSY | Surf.PULSE | Surf.BOB)
static var COLLECTOR_HULL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT | Surf.BOB, true, true,
	COLLECTOR_PHASE)
static var COLLECTOR_GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true,
	COLLECTOR_PHASE)
static var COLLECTOR_EYE := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, COLLECTOR_PHASE)
static var COLLECTOR_SHARD := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.5, Surf.GLOSSY | Surf.PULSE | Surf.BOB,
	false, true, COLLECTOR_PHASE)
static var COLLECTOR_THRUST := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BOB, true, true,
	COLLECTOR_PHASE)


## A laser cutting gantry over a cluster of pulsing crystal shards on a rock bed, a laser ring
## riding just over the crystal's tip under its carriage and turning about the cluster's axis,
## its focusing emitter aimed down at the biggest shard, so its glowing beam stays on it as the
## ring turns, sparks flying where it cuts. Every level adds two shards and the shards grow; L3
## adds a containment ring round the cluster, L4 pylons on it with lamps chasing round, L5 gold
## trim.
##
## L6 (Chrome): a taller gantry in chrome (the beam chrome over a gold band) with cyan strips up its
## legs, a wider ring carrying two emitters at opposite points with cyan beams, the shards growing
## faster, the pylons in chrome. L7 taller chrome containment pylons with cyan strips and a second
## power box. L8 (Obsidian): obsidian containment set with crystal inlays and pylons veined violet,
## violet beams aimed at a crowning mega-shard in the cluster's middle with three crystal chips
## hovering round it, and violet vein conduits up the gantry's legs. L9 an obsidian ring hovering
## over the cluster. L10 (Crown): the gantry's beam in gold filigree, a pulsing core band and a gold
## collar round the mega-shard, gold-capped pylons, gold filigree round the containment, and a
## collector, a hover-bot carrying a cut shard in its claw, circling the mega-shard low under the
## beams as the escort.
static func build_crystal_harvester(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.dome(0.8, 0.22, 8, 2, Vector3(0, ground, 0), ROCK)
	var growth := 1.0 + 0.05 * (level - 1) if level <= 5 else 1.2 + 0.08 * (level - 5)
	var girth := 1.0 if level <= 5 else 1.0 + 0.04 * (level - 5)
	for i: int in mini(1 + 2 * level, SHARDS.size()):
		if i == 0 and level >= 8:
			continue
		var shard: Array = SHARDS[i]
		var foot := Vector3(shard[0], ground + 0.12, shard[1])
		var shard_height: float = shard[2]
		var radius: float = shard[3]
		_shard(m, foot, shard_height * growth, radius * girth, Vector3(shard[4], 15 * i, shard[5]),
			CRYSTAL_SHARD.phased(fposmod(0.37 * i, 1.0)))
	if level >= 8:
		_mega_shard(m, level, crown)
	if level >= 3:
		var containment := Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND
		m.ring(0.86, 0.98, 0.16, 24, Vector3(0, ground, 0), Parts.OBSIDIAN_ROUND if obsidian else containment)
		m.ring(0.88, 0.96, 0.03, 24, Vector3(0, ground + 0.16, 0), Parts.CORE_GLOW if obsidian else CRYSTAL_GLOW)
	if level >= 8:
		# Crystal inlays round the containment's face, between the pylons.
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.prism(0.07, 0.07, 0.04, 4, Parts.around(0.97, degrees, ground + 0.08), INLAY.phased(k / 4.0),
				Vector3(90, 90.0 - degrees, 0))
	if level >= 10:
		m.lathe(PackedVector2Array([Vector2(0.99, 0.0), Vector2(0.99, 0.06)]), 24, Vector3(0, ground + 0.04, 0), Parts.FILIGREE)
	if level >= 4:
		var post_height := 0.42 if level < 7 else 0.7
		for k: int in 4:
			var post := Parts.around(0.92, 90 * k, ground)
			var yaw := Vector3(0, -90 * k, 0)
			m.box_chamfered(Vector3(0.14, post_height, 0.14), 0.03, post, _rig_armour(p.tier, Parts.HULL_LIGHT), yaw)
			if level >= 7:
				# A light strip up the pylon's outer face.
				m.box(Vector3(0.05, post_height - 0.16, 0.02), Parts.around(0.995, 90 * k, ground + 0.08), _rig_strip(p.tier), yaw)
			if level >= 10:
				m.prism(0.09, 0.07, 0.06, 12, post + Vector3(0, post_height, 0), Parts.GOLD_ROUND)
			m.orb(0.07, 12, 6, post + Vector3(0, post_height + 0.08, 0), CRYSTAL_LAMP.phased(k / 4.0))

	# The gantry: two legs on feet, a beam across with a crystal accent stripe, a carriage.
	var beam_y: float = GANTRY_HEIGHTS[level - 1]
	var yaw := Vector3(0, 45, 0)
	for leg: Vector3 in GANTRY_LEGS:
		var foot := leg + Vector3(0, ground, 0)
		m.box_chamfered(Vector3(0.42, 0.14, 0.42), 0.04, foot, Parts.HULL_DARK, yaw)
		m.box_chamfered(Vector3(0.24, beam_y - ground, 0.24), 0.05, foot, Parts.CHROME if chrome else Parts.HULL_LIGHT, yaw)
		m.box(Vector3(0.26, 0.1, 0.26), foot + Vector3(0, 0.3, 0), Parts.HAZARD, yaw)
		if level >= 6:
			# A light strip up the leg's face towards the camera.
			m.box(Vector3(0.06, beam_y - ground - 0.6, 0.02), foot + LowPolyMesh.turn(Vector3(0, 0.45, 0.125), yaw),
				_rig_strip(p.tier), yaw)
		if level >= 8:
			# A violet vein conduit up the leg's outer side, along the gantry.
			var conduit := foot + leg.normalized() * CONDUIT_OUT
			Parts.pipe(m, conduit + Vector3(0, 0.14, 0), conduit + Vector3(0, beam_y - ground - 0.1, 0), 0.045, Parts.VEINS, 8, false)
	var beam := Vector3(0, beam_y, 0)
	var beam_surface := Parts.GOLD_TRIM if gold else Parts.HULL_LIGHT
	if crown:
		beam_surface = Parts.FILIGREE
	elif chrome:
		beam_surface = Parts.CHROME
	m.box_chamfered(Vector3(2.96, 0.24, 0.3), 0.05, beam, beam_surface, yaw)
	m.box(Vector3(2.4, 0.08, 0.32), beam + Vector3(0, 0.08, 0), CRYSTAL_ACCENT, yaw)
	if level >= 6:
		m.box(Vector3(2.98, 0.05, 0.32), beam + Vector3(0, 0.0, 0), Parts.GOLD_TRIM, yaw)
	m.box_chamfered(Vector3(0.44, 0.2, 0.44), 0.05, beam + Vector3(0, -0.06, 0), Parts.HULL_MID, yaw)
	m.box(Vector3(0.6, 0.12, 0.06), beam + LowPolyMesh.turn(Vector3(0, 0.06, 0.17), yaw), Parts.HAZARD, yaw)
	# A power box at the left leg's foot.
	m.box_chamfered(Vector3(0.3, 0.32, 0.22), 0.04, Vector3(-0.55, ground, 1.15), Parts.HULL_MID, Vector3(0, 0, 0))
	m.box(Vector3(0.18, 0.14, 0.03), Vector3(-0.55, ground + 0.1, 1.26), CRYSTAL_GLOW)
	if level >= 7:
		# A second power box at the right leg's foot, its screen to the camera.
		m.box_chamfered(Vector3(0.22, 0.32, 0.3), 0.04, Vector3(1.15, ground, -0.55), Parts.HULL_MID)
		m.box(Vector3(0.03, 0.14, 0.18), Vector3(1.26, ground + 0.1, -0.55), CRYSTAL_GLOW)
	if level >= 8:
		# Its conduit across to the left leg's.
		var leg_conduit: Vector3 = GANTRY_LEGS[0] + (GANTRY_LEGS[0] as Vector3).normalized() * CONDUIT_OUT
		Parts.pipe(m, Vector3(-0.7, ground + 0.2, 1.15), leg_conduit + Vector3(0, ground + 0.2, 0), 0.045, Parts.VEINS, 8, false)

	# The laser ring rides on struts from a hub turning on the foot of a post under the carriage.
	var hub := Vector3(0, beam_y - RING_DROP, 0)
	m.prism(0.06, 0.06, beam_y - 0.06 - (hub.y - 0.03), 12, hub - Vector3(0, 0.03, 0), Parts.GUNMETAL)
	var crystal_height := float(SHARDS[0][2]) * growth
	var crystal_radius := float(SHARDS[0][3]) * girth
	if level >= 8:
		crystal_height = MEGA_HEIGHT + MEGA_GROWTH * (level - 8)
		crystal_radius = MEGA_RADIUS
	var drop := hub.y - (ground + 0.12 + crystal_height * RING_SHARE)
	var aim_share := CROWN_AIM_SHARE if crown else AIM_SHARE
	# The crystal's radius there: full to 0.7 of its height, tapering to its tip above (_shard).
	var aim_radius := crystal_radius * minf(1.0, (1.0 - aim_share) / 0.3) * AIM_DEPTH
	var aim := Vector3(aim_radius, ground + 0.12 + crystal_height * aim_share - hub.y, 0)
	var trim := Parts.HULL_MID_ROUND
	if crown or p.tier == Parts.Tier.GOLD:
		trim = Parts.GOLD_ROUND
	elif obsidian:
		trim = Parts.OBSIDIAN_ROUND
	elif chrome:
		trim = Parts.CHROME_ROUND
	var laser := p.moving(hub, Motion.spin(Vector3.UP, RING_RATE))
	if level < 6:
		_laser_ring(laser, RING_RADII[level - 1], drop, 1, aim, trim, gold, CRYSTAL_BEAM, CRYSTAL_GLOW)
	else:
		_laser_ring(laser, RING_RADII[level - 1], drop, 2, aim, trim, gold, VIOLET_BEAM if obsidian else CYAN_BEAM,
			VIOLET_LENS if obsidian else CYAN_LENS)
	if level >= 9:
		# The obsidian ring hovering over the cluster, bobbing.
		var hover := Vector3(0, HOVER_HEIGHT, 0)
		m.ring(HOVER_INNER, HOVER_OUTER, 0.06, 24, hover, HOVER_RING)
		m.lathe(PackedVector2Array([Vector2(HOVER_OUTER - 0.02, 0.062), Vector2(HOVER_INNER + 0.02, 0.062)]), 24, hover, HOVER_VEINS)
		m.lathe(PackedVector2Array([Vector2(HOVER_OUTER + 0.005, 0.01), Vector2(HOVER_OUTER + 0.005, 0.05)]), 24, hover, HOVER_RIM)
	if level >= 10:
		_collector(p.moving(Vector3(0, COLLECTOR_HEIGHT, 0), Motion.spin(Vector3.UP, COLLECTOR_RATE)))


## The mega-shard crowning the cluster from L8, standing where the first shard stood, with three
## crystal chips hovering round its middle, under the beams; at L10 a pulsing core band and a gold
## collar round it over the hovering ring.
static func _mega_shard(m: LowPolyMesh, level: int, crown: bool) -> void:
	var foot := Vector3(0, Parts.PAD_HEIGHT + 0.12, 0)
	var height := MEGA_HEIGHT + MEGA_GROWTH * (level - 8)
	_shard(m, foot, height, MEGA_RADIUS, Vector3(0, 0, 0), CRYSTAL_SHARD)
	if crown:
		# Over the hovering ring: a pulsing core band round the shard under a gold collar.
		var band := Vector3(0, CROWN_BAND, 0)
		m.lathe(PackedVector2Array([Vector2(MEGA_RADIUS + 0.015, 0), Vector2(MEGA_RADIUS + 0.015, 0.14)]), 6, band, Parts.CORE_GLOW)
		m.ring(MEGA_RADIUS - 0.02, MEGA_RADIUS + 0.07, 0.08, 12, band + Vector3(0, 0.14, 0), Parts.FILIGREE)
	for k: int in 3:
		m.orb(0.07, 4, 2, foot + Parts.around(MEGA_RADIUS + 0.12, 30.0 + 120.0 * k, height * (0.4 + 0.05 * k)),
			CHIP.phased(k / 3.0))


## The L10 collector, in its own space about the mega-shard's axis: a hover-bot COLLECTOR_RADIUS
## out, its nose to its heading, a round hull banded gold with a violet eye, a gold claw under its
## nose holding a cut shard, glowing and pulsing, and a thruster glowing under its tail; every part
## bobs together.
static func _collector(s: LowPolyMesh) -> void:
	var at := Vector3(COLLECTOR_RADIUS, 0, 0)
	var z := COLLECTOR_SCALE
	var heading := Vector3(0, 180.0 if COLLECTOR_RATE > 0.0 else 0.0, 0)
	s.lathe(PackedVector2Array([
		Vector2(0, -0.07) * z, Vector2(0.08, -0.07) * z, Vector2(0.12, -0.02) * z, Vector2(0.12, 0.03) * z,
		Vector2(0.08, 0.075) * z, Vector2(0, 0.085) * z,
	]), 12, at, COLLECTOR_HULL)
	s.lathe(PackedVector2Array([Vector2(0.123, -0.015) * z, Vector2(0.123, 0.02) * z]), 12, at, COLLECTOR_GOLD)
	s.box(Vector3(0.12, 0.035, 0.03) * z, at + LowPolyMesh.turn(Vector3(0, 0.025, 0.1) * z, heading), COLLECTOR_EYE, heading)
	for side: float in [-1.0, 1.0]:
		var root := at + LowPolyMesh.turn(Vector3(side * 0.05, -0.05, 0.05) * z, heading)
		var grip := at + LowPolyMesh.turn(Vector3(side * 0.055, -0.17, 0.05) * z, heading)
		s.strut(root, grip, 0.025 * z, COLLECTOR_GOLD)
		s.box(Vector3(0.03, 0.025, 0.025) * z, grip - Vector3(0, 0.0125, 0) * z + LowPolyMesh.turn(Vector3(-side * 0.015, 0, 0) * z,
			heading), COLLECTOR_GOLD, heading)
	s.lathe(PackedVector2Array([
		Vector2(0, -0.09) * z, Vector2(0.045, -0.035) * z, Vector2(0.045, 0.035) * z, Vector2(0, 0.09) * z,
	]), 6, at + LowPolyMesh.turn(Vector3(0, -0.16, 0.05) * z, heading), COLLECTOR_SHARD)
	s.disc(0.04 * z, 10, at + LowPolyMesh.turn(Vector3(0, -0.072, -0.05) * z, heading), COLLECTOR_THRUST, Vector3(180, 0, 0))


## A crystal shard: a six-sided column with a pointed tip, tilted, its facets glowing within.
static func _shard(m: LowPolyMesh, foot: Vector3, height: float, radius: float, rot: Vector3, surface: Surf) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius * 0.85, 0), Vector2(radius, height * 0.2), Vector2(radius, height * 0.7),
		Vector2(0, height),
	]), 6, foot, surface, rot)


## The laser ring, in its own space about its hub over the crystal's tip: a ring of `radius` in the
## tier's `trim` `drop` under the hub (over it where negative), just over the crystal's tip, on
## three thin struts out from the hub (clear of the crystal and of the emitters' beams), and `count`
## emitters on its outside at opposite points, each aimed down at `aim` (a point in the hub's space
## on the crystal's face towards an emitter at +X, turned with the emitter), its beam ending
## there. The ring turns about the crystal's own axis, so every beam keeps on it.
static func _laser_ring(s: LowPolyMesh, radius: float, drop: float, count: int, aim: Vector3, trim: Surf, gold: bool,
		beam: Surf, lens: Surf) -> void:
	Parts.torus(s, radius, RING_THICKNESS, 24, 8, Vector3(0, -drop - RING_THICKNESS, 0), trim)
	s.prism(0.11, 0.11, 0.1, 16, Vector3(0, -0.05, 0), Parts.HULL_DARK_ROUND)
	for k: int in 3:
		var degrees := 90.0 + 120.0 * k
		Parts.pipe(s, Parts.around(0.1, degrees, -0.03), Parts.around(radius - RING_THICKNESS, degrees, -drop), STRUT_RADIUS,
			trim, 8, false)
	for k: int in count:
		var degrees := 180.0 * k
		s.box_chamfered(Vector3(0.16, 0.14, 0.1), 0.02, Parts.around(radius + 0.05, degrees, -drop - 0.05), trim,
			Vector3(0, -degrees, 0))
		var at := Parts.around(radius + 0.1, degrees, -drop + 0.1)
		var target := Parts.around(aim.x, degrees, aim.y)
		_emitter(s, at, target, gold, beam, lens)


## A focusing emitter hanging at `at`, aimed at `target`: a hub with three prongs round a glowing
## lens, the beam from the lens to `target`, and a cluster of sparks there. Built along -Y and
## turned so -Y points at the target.
static func _emitter(s: LowPolyMesh, at: Vector3, target: Vector3, gold: bool, beam: Surf, lens: Surf) -> void:
	var turn := Parts.facing(at - target)
	var reach := at.distance_to(target)
	var flip := Basis.from_euler(Vector3(deg_to_rad(turn.x), deg_to_rad(turn.y), deg_to_rad(turn.z))) \
		* Basis.from_euler(Vector3(PI, 0, 0))
	var flipped := flip.get_euler() * (180.0 / PI)
	s.prism(0.16, 0.12, 0.1, 16, at + LowPolyMesh.turn(Vector3(0, -0.1, 0), turn), Parts.GOLD_ROUND if gold else Parts.HULL_DARK_ROUND,
		turn)
	s.cone(0.12, 0.16, 16, at + LowPolyMesh.turn(Vector3(0, -0.1, 0), turn), Parts.HULL_MID_ROUND, flipped)
	for k: int in 3:
		var root := at + LowPolyMesh.turn(Parts.around(0.12, 120 * k, -0.1), turn)
		var elbow := at + LowPolyMesh.turn(Parts.around(0.2, 120 * k, -0.22), turn)
		var tip := at + LowPolyMesh.turn(Parts.around(0.07, 120 * k, -0.36), turn)
		s.strut(root, elbow, 0.05, CRYSTAL_PRONG)
		s.strut(elbow, tip, 0.05, CRYSTAL_PRONG)
	s.orb(0.07, 12, 6, at + LowPolyMesh.turn(Vector3(0, -0.3, 0), turn), lens)
	s.prism(BEAM_RADIUS, BEAM_RADIUS, reach - 0.3, 8, target, beam, turn)
	for k: int in 6:
		s.orb(0.035, 8, 3, target + LowPolyMesh.turn(Parts.around(0.07 + 0.03 * (k % 2), 60.0 * k, 0.03 * (k % 3)), turn),
			CUT_SPARK.phased(k / 6.0 + 0.05))


static var ANTIMATTER_ACCENT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ANTIMATTER)
static var ANTIMATTER_ACCENT_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.ANTIMATTER, 1.0, Surf.LIT, true)
static var ANTIMATTER_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT, true)
static var ANTIMATTER_GLASS := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.ANTIMATTER, 2.0, Surf.GLOSSY)
## The siphon's core, pulsing as it floats; the current through its coils, running round the
## torus's section (along the strips: the screen layer's rows, carried by FLOW, as the glow
## layer's faint stripes barely show); and the arcs that jump to it, and on the vault between
## its pylons.
static var SIPHON_CORE_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true)
static var COIL_CURRENT := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ANTIMATTER, 3.0, Surf.UNLIT | Surf.FLOW, true, true, 0.75)
static var ARC := Parts.spark(MaterialKit.ANTIMATTER)

## The antimatter siphon's core (the torus turns round it), its field pylons (degrees, the
## camera's corner left open) and the coils on the torus by level.
const SIPHON_CORE := 1.3
const SIPHON_PYLONS := [105.0, 225.0, 345.0]
const SIPHON_COILS := [6, 9, 9, 12, 12, 12, 12, 12]
## From L4 the core floats higher and grows, by level from L4: its height and its radius; the
## pylons grow PYLON_GROWTH a level from L3's height.
const RAISED_CORES := [1.45, 1.55, 1.7, 1.8, 1.95]
const CORE_RADII := [0.31, 0.34, 0.36, 0.36, 0.38]
const PYLON_GROWTH := 0.4
## The L5 third capacitor, on the right corner past the right pylon, where the camera sees it, and
## where its pipe meets the pedestal.
const THIRD_CAPACITOR := Vector3(0.72, 0, -1.12)
const THIRD_PIPE_END := Vector3(0.37, 0, -0.57)
## The horizontal direction towards the camera (IsoCamera's yaw): the obsidian pylons' vein panels
## go on the faces turned to it.
const TOWARD_CAMERA := Vector3(0.70710678, 0, 0.70710678)
## The L6 ring hovering over the core and the L8 halo over it: their heights over the core.
const SIPHON_HOVER_LIFT := 0.55
const HALO_LIFT := 0.95

## The high levels' arcs: cyan at the Chrome tier, violet from the Obsidian tier. From the Obsidian
## tier the pylons' faces to the camera carry glowing violet vein panels (the walls' violet field:
## the glow layer's stripes drawn a third as fine and lifted up the panel by FLOW).
static var CYAN_ARC := Parts.spark(MaterialKit.ENERGY)
static var VIOLET_ARC := Parts.spark(Parts.CORE_GLOW_TINT)
static var VEIN_PANEL := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0 / 3.0, Surf.UNLIT | Surf.FLOW, false, true, 0.45)


## A magnetic torus turning round a pulsing violet core floating on a pedestal, wound with
## field coils whose current flows, three field pylons aiming glowing emitters at it with arcs
## crackling from their tips to the core, a capacitor piped to the pedestal.
## Unlocked at Command Center 4, so it looks advanced from L1. L2 adds coils, pylon armour and
## a second capacitor; L3 a second, larger torus tilted round the first, and gold trim.
##
## From L4 the pylons grow PYLON_GROWTH a level, their heads aimed down at the core, which floats
## higher and grows. L4 (Chrome): chrome pylons with cyan strips up them, a chrome torus with twelve
## coils, cyan arcs. L5 two cyan rings round each pylon and a third capacitor on the right
## corner. L6 (Obsidian): obsidian pylons with glowing violet vein panels and violet rings, an
## obsidian ring hovering over the core, violet arcs. L7 crystal inlays at the pylons' feet and
## crystal crowns on their heads. L8 (Crown): gold filigree bands round the pylons, a halo glowing over the core (its crown),
## and the loudest arcs (a second from each tip to the halo, and one between each two tips). It
## has no escort: its arcs and halo are its life.
static func build_antimatter_siphon(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var core_y := SIPHON_CORE if level < 4 else float(RAISED_CORES[level - 4])
	var core_radius := 0.27 if level < 4 else float(CORE_RADII[level - 4])
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.lathe(PackedVector2Array([
		Vector2(1.0, 0), Vector2(1.0, 0.14), Vector2(0.62, 0.26), Vector2(0.44, 0.5),
		Vector2(0.42, 0.66), Vector2(0.54, 0.78), Vector2(0, 0.78),
	]), 24, Vector3(0, ground, 0), Parts.HULL_MID_ROUND)
	m.lathe(PackedVector2Array([Vector2(1.04, 0), Vector2(1.04, 0.07), Vector2(0.99, 0.07)]), 24,
		Vector3(0, ground + 0.05, 0), Parts.GOLD_ROUND if gold else ANTIMATTER_ACCENT_ROUND)
	for k: int in 6:
		var degrees := 30.0 + 60.0 * k
		m.box(Vector3(0.1, 0.16, 0.04), Parts.around(0.44, degrees, ground + 0.42), ANTIMATTER_GLOW, Vector3(-8, 90.0 - degrees, 0))
	var cap := ground + 0.78
	m.prism(0.1, 0.08, core_y - cap, 16, Vector3(0, cap, 0), Parts.GUNMETAL)
	m.orb(core_radius, 16, 8, Vector3(0, core_y, 0), SIPHON_CORE_GLOW)

	var arc := ARC
	if obsidian:
		arc = VIOLET_ARC
	elif chrome:
		arc = CYAN_ARC
	var core := Vector3(0, core_y + 0.1, 0)
	var tips: Array[Vector3] = []
	for k: int in SIPHON_PYLONS.size():
		var tip := _field_pylon(m, SIPHON_PYLONS[k], level, gold, p.tier, core)
		tips.append(tip)
		Parts.arc(m, tip, core + (tip - core).normalized() * (0.2 + core_radius - 0.27), 4, 0.05, arc.phased(k / 3.0))

	# Capacitors piped to the pedestal.
	_capacitor(m, Vector3(0.95, ground, 0.95), gold)
	Parts.pipe_run(m, PackedVector3Array([Vector3(0.82, ground + 0.26, 0.82), Vector3(0.48, ground + 0.32, 0.48)]),
		0.06, Parts.GUNMETAL, 8)
	if level >= 2:
		_capacitor(m, Vector3(-1.0, ground, 0.55), gold)
		Parts.pipe_run(m, PackedVector3Array([Vector3(-0.84, ground + 0.26, 0.47), Vector3(-0.58, ground + 0.32, 0.32)]),
			0.06, Parts.GUNMETAL, 8)
	if level >= 5:
		_capacitor(m, THIRD_CAPACITOR + Vector3(0, ground, 0), gold)
		var inward := (THIRD_PIPE_END - THIRD_CAPACITOR).normalized()
		Parts.pipe_run(m, PackedVector3Array([THIRD_CAPACITOR + inward * 0.17 + Vector3(0, ground + 0.26, 0),
			THIRD_PIPE_END + Vector3(0, ground + 0.32, 0)]), 0.06, Parts.GUNMETAL, 8)
	if level >= 6:
		# The obsidian ring hovering over the core, bobbing.
		var hover := Vector3(0, core_y + SIPHON_HOVER_LIFT, 0)
		m.ring(0.38, 0.52, 0.05, 24, hover, HOVER_RING)
		m.lathe(PackedVector2Array([Vector2(0.5, 0.052), Vector2(0.4, 0.052)]), 24, hover, HOVER_VEINS)
		m.lathe(PackedVector2Array([Vector2(0.525, 0.008), Vector2(0.525, 0.042)]), 24, hover, HOVER_RIM)
	if level >= 8:
		# The halo over the core: a glowing ring in a gold one, the siphon's crown; arcs from each tip
		# to it and from tip to tip.
		var halo := Vector3(0, core_y + HALO_LIFT, 0)
		Parts.torus(m, 0.3, 0.045, 24, 8, halo, Parts.CORE_GLOW)
		m.ring(0.36, 0.42, 0.06, 24, halo + Vector3(0, 0.015, 0), Parts.GOLD_ROUND)
		for k: int in tips.size():
			var to_halo := halo + Vector3(0, 0.045, 0)
			Parts.arc(m, tips[k], to_halo + (tips[k] - to_halo).normalized() * 0.45, 4, 0.05, arc.phased(fposmod(k / 3.0 + 0.5, 1.0)))
			Parts.arc(m, tips[k], tips[(k + 1) % tips.size()], 6, 0.06, arc.phased(fposmod(k / 3.0 + 0.17, 1.0)))

	var s := p.moving(Vector3(0, core_y, 0), Motion.spin(Vector3.UP, 1.4))
	Parts.torus(s, 0.72, 0.12, 24, 10, Vector3(0, -0.12, 0), Parts.CHROME_ROUND if chrome else Parts.HULL_LIGHT_ROUND)
	var coils: int = SIPHON_COILS[level - 1]
	for k: int in coils:
		var degrees := 360.0 * k / coils
		var yaw := Vector3(0, 90.0 - degrees, 0)
		s.box_chamfered(Vector3(0.12, 0.34, 0.36), 0.04, Parts.around(0.72, degrees, -0.17), Parts.HULL_DARK, yaw)
		s.box(Vector3(0.13, 0.06, 0.37), Parts.around(0.72, degrees, 0.04), COIL_CURRENT, yaw)
	if level >= 3:
		var tilt := Vector3(12, 0, 0)
		Parts.torus(s, 1.05, 0.07, 24, 10, -LowPolyMesh.turn(Vector3(0, 0.07, 0), tilt),
			Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND, tilt)


## A field pylon on the pedestal's rim: a column on a foot with an antimatter band, its
## emitter head leaning in towards the torus with a glowing tip. Returns the tip's centre.
## From L4 it grows PYLON_GROWTH a level and its head aims down at `core`; its column is chrome
## with a cyan strip up its outer face, from the Obsidian tier obsidian with a glowing violet vein
## panel on each face turned to the camera; from L5 two glowing rings round it (cyan, violet from
## the Obsidian tier); from L7 a crystal inlaid in its foot and a crown of crystals on its head,
## at L8 two gold filigree bands round it.
static func _field_pylon(m: LowPolyMesh, degrees: float, level: int, gold: bool, tier: int, core: Vector3) -> Vector3:
	var yaw := Vector3(0, 90.0 - degrees, 0)
	var foot := Parts.around(1.22, degrees, Parts.PAD_HEIGHT)
	var height := 1.3 + 0.08 * level if level < 4 else 1.54 + PYLON_GROWTH * (level - 3)
	var column := Parts.HULL_LIGHT
	if tier >= Parts.Tier.OBSIDIAN:
		column = Parts.OBSIDIAN
	elif tier >= Parts.Tier.CHROME:
		column = Parts.CHROME
	m.box_chamfered(Vector3(0.32, 0.12, 0.32), 0.04, foot, Parts.HULL_DARK, yaw)
	m.box_chamfered(Vector3(0.18, height, 0.18), 0.04, foot, column, yaw)
	m.box(Vector3(0.2, 0.1, 0.2), foot + Vector3(0, height * 0.62, 0), ANTIMATTER_ACCENT, yaw)
	if level >= 2:
		m.box_chamfered(Vector3(0.24, 0.42, 0.24), 0.04, foot + Vector3(0, 0.12, 0), _rig_armour(tier, PYLON_ARMOUR), yaw)
	if level >= 4 and tier < Parts.Tier.OBSIDIAN:
		m.box(Vector3(0.06, height - 0.75, 0.02), foot + LowPolyMesh.turn(Vector3(0, 0.6, 0.095), yaw), _rig_strip(tier), yaw)
	elif level >= 4:
		# A glowing violet vein panel on each face turned to the camera.
		for normal: Vector3 in [Vector3.BACK, Vector3.FORWARD, Vector3.RIGHT, Vector3.LEFT]:
			if LowPolyMesh.turn(normal, yaw).dot(TOWARD_CAMERA) > 0.2:
				var size := Vector3(0.12, height - 0.77, 0.02) if normal.x == 0.0 else Vector3(0.02, height - 0.77, 0.12)
				m.box(size, foot + LowPolyMesh.turn(normal * 0.1 + Vector3(0, 0.62, 0), yaw), VEIN_PANEL, yaw)
	if level >= 5:
		# Two glowing rings round the column, between the accent band and the filigree's places.
		for ring: float in [0.42, 0.78]:
			m.box(Vector3(0.22, 0.05, 0.22), foot + Vector3(0, height * ring, 0),
				Parts.CORE_GLOW if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP, yaw)
	if level >= 7:
		m.prism(0.07, 0.07, 0.04, 4, foot + LowPolyMesh.turn(Vector3(0, 0.06, 0.165), yaw), INLAY.phased(degrees / 360.0),
			Vector3(90, yaw.y, 0))
	if level >= 8:
		for band: float in [0.3, 0.85]:
			m.box(Vector3(0.24, 0.06, 0.24), foot + Vector3(0, height * band, 0), Parts.FILIGREE, yaw)
	var head := foot + Vector3(0, height, 0)
	m.box_chamfered(Vector3(0.24, 0.12, 0.24), 0.04, head, Parts.GOLD_TRIM if gold else Parts.HULL_MID, yaw)
	if level >= 7:
		# A crown of crystals on the head's outer half, leaning out.
		for k: int in 3:
			var lean := Parts.facing(LowPolyMesh.turn(Vector3((k - 1) * 0.35, 1, 0.3), yaw))
			m.cone(0.045, 0.2 - 0.05 * absf(k - 1), 8, head + LowPolyMesh.turn(Vector3((k - 1) * 0.07, 0.12, 0.06), yaw),
				INLAY.phased(fposmod(degrees / 360.0 + k / 3.0, 1.0)), lean)
	var tilt := yaw + Vector3(-50, 0, 0)
	var neck := head + Vector3(0, 0.08, 0)
	if level >= 4:
		tilt = Parts.facing(core - neck)
	var inward := LowPolyMesh.turn(Vector3.UP, tilt)
	m.prism(0.08, 0.06, 0.26, 12, neck, Parts.HULL_MID_ROUND, tilt)
	var tip := neck + inward * 0.3
	m.orb(0.07 + 0.015 * level, 10, 4, tip, ANTIMATTER_GLOW)
	return tip


## A capacitor: an armoured block with a violet glass window and a glowing cap.
static func _capacitor(m: LowPolyMesh, pos: Vector3, gold: bool) -> void:
	m.box_chamfered(Vector3(0.38, 0.4, 0.38), 0.05, pos, Parts.HULL_MID)
	m.box(Vector3(0.24, 0.2, 0.4), pos + Vector3(0, 0.1, 0), ANTIMATTER_GLASS)
	m.box_chamfered(Vector3(0.26, 0.05, 0.26), 0.02, pos + Vector3(0, 0.4, 0), Parts.GOLD_TRIM if gold else ANTIMATTER_GLOW)


static var TANK := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_LIGHT, 1.5, Surf.LIT, true)
## The valve handwheels: too thin for the outline.
static var WHEEL := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.METAL, 1.0, Surf.LIT, true, false)
static var GOLD_WHEEL := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true, false)
## The fill gauge pulses, the lid's warning lamp blinks, and from L4 liquid metal runs through
## the pipe between the twin tanks.
static var GAUGE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.METAL, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var WARNING_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var LIQUID_METAL := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.METAL, 2.0, Surf.UNLIT | Surf.FLOW, true, true, 0.75)
## The high levels' own: the L7 catwalk lamps, chasing along each catwalk; the L8 gauge lenses in
## the metal accent, pulsing; the L9 gauge ring hovering over the tanks, obsidian with a metal-lit
## dial and a violet rim (gold at L10), bobbing together (their one phase is also the dial's and the
## rim's PULSE offset).
static var CATWALK_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var GAUGE_LENS := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.METAL, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var GAUGE_RING := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
static var GAUGE_TICK := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.METAL, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true, 0.7)
static var GAUGE_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var GAUGE_GOLD_RIM := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)

## The metal silo's shell height by level; from L4 it stands as twin tanks.
const METAL_SILO_HEIGHTS := [0.9, 1.15, 1.4, 1.45, 1.45, 1.9, 2.2, 2.5, 2.6, 3.0]
const TWIN_TANKS := [Vector3(-0.56, 0, 0.56), Vector3(0.56, 0, -0.56)]
## From L6: the pump's housing on the pipe between the tanks (its middle), and its flywheel's
## axis, towards the camera.
const PUMP := Vector3(0.38, 0, 0.38)
const PUMP_FACING := Vector3(0.70710678, 0, 0.70710678)
## The L9 gauge ring's lift over the tanks' shells and its radius, over the deck between them.
const GAUGE_RING_LIFT := 0.56
const GAUGE_RING_RADIUS := 0.5
## The L7 beacon mast's height over the deck: its beacon clears the L9 gauge ring,
## which turns round the mast.
const BEACON_MAST := 0.8
## The L10 security bot's patrol: a tight round at the tanks' mid-height in the open corner between
## them towards the camera, over the pump, since a round about the middle at that height would
## pass through the tanks (they reach 1.45 out).
const SILO_GUARD_CENTRE := Vector3(0.85, 0, 0.85)
const SILO_GUARD_RADIUS := 0.3
const SILO_GUARD_HEIGHT := 2.6
const SILO_GUARD_RATE := 0.4


## A squat riveted tank in plate bands on a round plinth, with an access ladder up its lit
## side and a pulsing metal fill gauge, a hatch, a vent and a blinking warning lamp on its
## domed top. It grows taller to L3, stands as twin tanks joined by a catwalk and a pipe of
## flowing liquid metal from L4, and wears gold caps at L5.
##
## From L6 the tanks grow taller each level, their shells 1.9 to 3.0: L6 chrome shells banded in the
## metal accent, cyan level gauges up them beside the fill gauges, a chrome catwalk ring round each
## tank's top, and a chrome pump on the pipe, fed by the valves, cyan-lit, its flywheel spinning (a
## moving part); L7 lamps chasing along the catwalks and a chrome beacon mast on the deck between
## the tanks, its cyan beacon pulsing; L8 obsidian armour bands veined violet, veined risers up the
## tanks, metal-lit lenses on the gauges and an obsidian pump housing; L9 an obsidian gauge ring
## hovering over the deck between the tanks, turning; L10 gold filigree bands, gold rims and
## railings, the violet antimatter core glowing in a gold cage on the pump at the pipe's junction,
## gold-capped vents, and a security bot patrolling between the tanks at their mid-height as its
## escort.
static func build_metal_silo(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var height: float = METAL_SILO_HEIGHTS[level - 1]
	Parts.foundation(m, 3)
	if level < 4:
		_metal_tank(m, Vector3(0, Parts.PAD_HEIGHT, 0), 0.95, height, level, p.tier, 0.0)
		if level >= 3:
			_valves(m, Vector3(0.62, Parts.PAD_HEIGHT, 0.62), gold)
		return
	for k: int in TWIN_TANKS.size():
		var spot: Vector3 = TWIN_TANKS[k]
		_metal_tank(m, spot + Vector3(0, Parts.PAD_HEIGHT, 0), 0.66, height, level, p.tier, 0.5 * k)
	# The pipe between the tanks, out of each at its side and looping towards the camera, clear
	# of the gauges and the ladders.
	var a: Vector3 = TWIN_TANKS[0]
	var b: Vector3 = TWIN_TANKS[1]
	var pipe_y := Parts.PAD_HEIGHT + 0.12 + height * 0.55
	Parts.pipe_run(m, PackedVector3Array([
		a + Parts.around(0.62, -10, pipe_y), a + Parts.around(0.86, -10, pipe_y),
		b + Parts.around(0.86, 100, pipe_y), b + Parts.around(0.62, 100, pipe_y),
	]), 0.06, LIQUID_METAL, 12)
	var deck := Parts.PAD_HEIGHT + 0.12 + height
	m.box_chamfered(Vector3(0.3, 0.06, 1.0), 0.02, Vector3(0, deck - 0.02, 0), DECK_PLATE, Vector3(0, 135, 0))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.05, 0.12, 1.0), LowPolyMesh.turn(Vector3(side * 0.15, 0, 0), Vector3(0, 135, 0)) + Vector3(0, deck, 0),
			Parts.ROD, Vector3(0, 135, 0))
	_valves(m, Vector3(0.66, Parts.PAD_HEIGHT, 0.66), gold)
	if level >= 6:
		_metal_pump(p, PUMP + Vector3(0, pipe_y, 0), level)
	if level >= 7:
		# A chrome beacon mast on the deck between the tanks, its cyan beacon pulsing.
		var foot := Vector3(0, deck + 0.04, 0)
		m.prism(0.06, 0.04, BEACON_MAST, 8, foot, Parts.CHROME_ROUND)
		m.orb(0.1, 8, 4, foot + Vector3(0, 0.1 + BEACON_MAST, 0), Parts.CYAN_STRIP)
		m.prism(0.07, 0.03, 0.05, 8, foot + Vector3(0, 0.19 + BEACON_MAST, 0),
			Parts.GOLD_ROUND if p.tier >= Parts.Tier.CROWN else Parts.CHROME_ROUND)
	if level >= 9:
		_gauge_ring(p, Vector3(0, deck + GAUGE_RING_LIFT, 0), GAUGE_RING_RADIUS, p.tier)
	if level >= 10:
		Parts.escort_guard(p, SILO_GUARD_RADIUS, SILO_GUARD_HEIGHT, SILO_GUARD_RATE, SILO_GUARD_CENTRE)


## One metal tank standing at `base`: plinth, banded shell, gauge, ladder, domed top with its
## lamp; its gauge and lamp on `phase`. From L6 its shell is the tier's (chrome) and it gains
## cyan level gauges and a catwalk ring, and the higher levels' parts (build_metal_silo).
static func _metal_tank(m: LowPolyMesh, base: Vector3, radius: float, height: float, level: int, tier: int,
		phase: float) -> void:
	var gold := tier >= Parts.Tier.GOLD
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.14, 0), Vector2(radius + 0.14, 0.08), Vector2(radius + 0.08, 0.12), Vector2(0, 0.12),
	]), 24, base, Parts.HULL_DARK_ROUND)
	if level >= 10:
		m.lathe(PackedVector2Array([Vector2(radius + 0.15, 0.02), Vector2(radius + 0.15, 0.07)]), 24, base, Parts.GOLD_ROUND)
	var shell := base + Vector3(0, 0.12, 0)
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, height)]), 24, shell,
		Parts.CHROME_ROUND if tier >= Parts.Tier.CHROME else TANK)
	var band_y := 0.0
	var k := 0
	while band_y < height - 0.2:
		if level >= 8:
			_armour_band(m, radius, shell + Vector3(0, band_y, 0), tier, k)
		elif level >= 6:
			_band(m, radius, shell + Vector3(0, band_y, 0), METAL_ACCENT_ROUND if k % 2 == 1 else Parts.HULL_MID_ROUND)
		else:
			_band(m, radius, shell + Vector3(0, band_y, 0), METAL_ACCENT_ROUND if k == 1 else Parts.HULL_MID_ROUND)
		band_y += 0.6 if level >= 8 else 0.4
		k += 1
	_band(m, radius, shell + Vector3(0, height - 0.08, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)
	var top := shell + Vector3(0, height, 0)
	m.dome(radius, radius * 0.32, 24, 4, top, Parts.GOLD_ROUND if gold else TANK)
	m.prism(0.15, 0.13, 0.08, 16, top + Vector3(-0.12, radius * 0.3, -0.12), Parts.HULL_MID_ROUND)
	var vent := top + Vector3(0.2, radius * 0.24, -0.25)
	Parts.pipe_run(m, PackedVector3Array([vent, vent + Vector3(0, 0.2, 0), vent + Vector3(0.14, 0.2, 0)]), 0.045, Parts.GUNMETAL, 12)
	if level >= 10:
		m.prism(0.065, 0.075, 0.07, 12, vent + Vector3(0.13, 0.2, 0), Parts.GOLD_ROUND, Parts.facing(Vector3.RIGHT))
	# The warning lamp on the lid's front, sunk to sit on the dome's slope.
	var lamp := radius * 0.33
	var lamp_y := radius * 0.32 * sqrt(1.0 - 2.0 * lamp * lamp / (radius * radius)) - 0.02
	Parts.landing_light(m, top + Vector3(lamp, lamp_y, lamp), 0.08, WARNING_LAMP.phased(phase))
	# The fill gauge on the camera's right, the ladder on the lit left.
	var gauge := Parts.around(radius, 15, 0.1) + shell
	var yaw := Vector3(0, 75, 0)
	m.box_chamfered(Vector3(0.18, height * 0.74, 0.08), 0.03, gauge, Parts.HULL_DARK, yaw)
	m.box(Vector3(0.09, height * 0.52, 0.1), gauge + Vector3(0, 0.04, 0), GAUGE.phased(phase), yaw)
	Parts.ladder(m, Parts.around(radius + 0.06, 118, 0) + shell, height + 0.06, 0.2, 90.0 - 118.0, Parts.ROD)
	if level < 6:
		return
	# Cyan level gauges either side of the fill gauge, each on its own phase.
	for side: int in [-1, 1]:
		var degrees := 15.0 + 19.0 * side
		m.box(Vector3(0.05, height * 0.84, 0.04), Parts.around(radius, degrees, 0.08) + shell,
			Parts.CYAN_STRIP.phased(fposmod(phase + 0.25 * side, 1.0)), Vector3(0, 90.0 - degrees, 0))
	if level >= 8:
		# Metal-lit lenses over the fill gauge, and a veined riser up the tank's front.
		for i: int in 2:
			m.orb(0.05, 8, 3, Parts.around(radius + 0.05, 15, 0.1 + height * (0.6 + 0.08 * i)) + shell,
				GAUGE_LENS.phased(fposmod(phase + 0.5 * i, 1.0)))
		var riser := Parts.around(radius + 0.06, 62, 0.0) + shell
		Parts.pipe(m, riser, riser + Vector3(0, height - 0.1, 0), 0.045, Parts.VEINS, 12)
	_catwalk(m, shell + Vector3(0, height - 0.3, 0), radius, level, tier, phase)


## A plate band round a tank: its outer wall only, the shell fills it from above.
static func _band(m: LowPolyMesh, radius: float, pos: Vector3, surf: Surf) -> void:
	m.lathe(PackedVector2Array([Vector2(radius + 0.04, 0), Vector2(radius + 0.04, 0.08)]), 24, pos, surf)


## An armour band round a tank from L8, the `k`th up it (every 0.6): a thick obsidian band with a
## violet vein running round its middle; at the Crown tier every other band is gold filigree
## instead.
static func _armour_band(m: LowPolyMesh, radius: float, pos: Vector3, tier: int, k: int) -> void:
	var filigree := tier >= Parts.Tier.CROWN and k % 2 == 1
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.06, 0), Vector2(radius + 0.06, 0.14), Vector2(radius, 0.14),
	]), 24, pos, Parts.FILIGREE if filigree else Parts.OBSIDIAN_ROUND)
	if not filigree:
		m.lathe(PackedVector2Array([Vector2(radius + 0.065, 0.035), Vector2(radius + 0.065, 0.105)]), 24, pos, Parts.VEINS)


## The catwalk ring round a tank's top from L6, its deck at `pos`: a grating deck with a chrome
## kick rail (gold at the Crown tier) round the tank but for the side facing the other tank, on
## three brackets; from L7 three lamps chasing along its side to the camera on `phase`.
static func _catwalk(m: LowPolyMesh, pos: Vector3, radius: float, level: int, tier: int, phase: float) -> void:
	# The side facing the other tank, which the catwalk leaves open: the tanks stand on a diagonal.
	var inward := rad_to_deg(atan2(-pos.z, -pos.x))
	var from := inward + 50.0
	var to := inward + 310.0
	m.ring(radius, radius + 0.22, 0.04, 24, pos, DECK_PLATE, Vector3.ZERO, from, to)
	m.ring(radius + 0.18, radius + 0.22, 0.12, 24, pos + Vector3(0, 0.04, 0),
		Parts.GOLD_ROUND if tier >= Parts.Tier.CROWN else Parts.CHROME_ROUND, Vector3.ZERO, from, to)
	for i: int in 3:
		var degrees := from + 65.0 + 65.0 * i
		Parts.beam(m, Parts.around(radius, degrees, pos.y - 0.28) + Vector3(pos.x, 0, pos.z),
			Parts.around(radius + 0.16, degrees, pos.y) + Vector3(pos.x, 0, pos.z), 0.06, Parts.CHROME)
	if level >= 7:
		# On the side to the camera (round 45 degrees), which the arc always covers.
		for i: int in 3:
			var degrees := 21.0 + 24.0 * i
			m.box(Vector3(0.08, 0.06, 0.08), Parts.around(radius + 0.2, degrees, pos.y + 0.16) + Vector3(pos.x, 0, pos.z),
				CATWALK_LAMP.phased(fposmod(phase + Parts.chase(i, 3), 1.0)), Vector3(0, 90.0 - degrees, 0))


## The pump on the liquid-metal pipe from L6, its housing's middle at `centre`, standing on a
## chrome riser the valves feed: a chrome housing (obsidian from the Obsidian tier) with a cyan
## belt round its top and a flywheel spinning on its face to the camera, chrome (gold at the Crown
## tier) round a cyan hub; at L10 the violet antimatter core glowing in a gold cage on its top.
static func _metal_pump(p: Parts, centre: Vector3, level: int) -> void:
	var m := p.body
	var crown := p.tier >= Parts.Tier.CROWN
	var yaw := Vector3(0, 45, 0)
	var bottom := centre - Vector3(0, 0.22, 0)
	m.prism(0.11, 0.11, bottom.y - Parts.PAD_HEIGHT, 16, Vector3(centre.x, Parts.PAD_HEIGHT, centre.z), Parts.CHROME_ROUND)
	m.box_chamfered(Vector3(0.44, 0.44, 0.3), 0.05, bottom, Parts.OBSIDIAN if p.tier >= Parts.Tier.OBSIDIAN else Parts.CHROME, yaw)
	m.box(Vector3(0.46, 0.06, 0.32), bottom + Vector3(0, 0.32, 0), Parts.CYAN_STRIP, yaw)
	var face := centre + PUMP_FACING * 0.15
	var wheel := p.moving(face, Motion.spin(PUMP_FACING, 1.6))
	var rim := Parts.GOLD_ROUND if crown else Parts.CHROME_ROUND
	Parts.torus(wheel, 0.15, 0.035, 12, 6, Vector3.ZERO, rim, Parts.facing(PUMP_FACING))
	var axle := PUMP_FACING * 0.035
	for spoke: Vector3 in [Vector3(0.70710678, 0, -0.70710678), Vector3.UP]:
		wheel.strut(axle - spoke * 0.14, axle + spoke * 0.14, 0.04, rim)
	wheel.orb(0.065, 12, 4, PUMP_FACING * 0.05, Parts.CYAN_STRIP)
	if level >= 10:
		var top := centre + Vector3(0, 0.22, 0)
		m.prism(0.13, 0.11, 0.05, 16, top, Parts.GOLD_ROUND)
		m.orb(0.12, 16, 6, top + Vector3(0, 0.18, 0), Parts.CORE_GLOW)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.strut(top + Parts.around(0.11, degrees, 0.05), top + Parts.around(0.14, degrees, 0.19), 0.035, Parts.GOLD_TRIM)
			m.strut(top + Parts.around(0.14, degrees, 0.19), top + Parts.around(0.03, degrees, 0.33), 0.035, Parts.GOLD_TRIM)
		m.prism(0.05, 0.02, 0.06, 12, top + Vector3(0, 0.32, 0), Parts.GOLD_ROUND)


## The gauge ring hovering over the deck between the tanks (L9), its middle at `centre`, turning:
## an obsidian ring of `radius` spanning both domes, a metal-lit dial on its top marked by six
## obsidian ticks, and a violet rim (gold at the Crown tier), all bobbing together.
static func _gauge_ring(p: Parts, centre: Vector3, radius: float, tier: int) -> void:
	var ring := p.moving(centre, Motion.spin(Vector3.UP, 0.3))
	ring.ring(radius - 0.08, radius + 0.1, 0.05, 24, Vector3.ZERO, GAUGE_RING)
	ring.lathe(PackedVector2Array([Vector2(radius + 0.105, 0.008), Vector2(radius + 0.105, 0.042)]), 24, Vector3.ZERO,
		GAUGE_GOLD_RIM if tier >= Parts.Tier.CROWN else GAUGE_RIM)
	ring.lathe(PackedVector2Array([Vector2(radius + 0.06, 0.052), Vector2(radius - 0.04, 0.052)]), 24, Vector3.ZERO, GAUGE_TICK)
	for k: int in 6:
		var degrees := 60.0 * k
		ring.box(Vector3(0.16, 0.03, 0.05), Parts.around(radius + 0.01, degrees, 0.05), GAUGE_RING, Vector3(0, 90.0 - degrees, 0))


## A valve manifold on the near corner: two pipes from the ground with handwheels.
static func _valves(m: LowPolyMesh, pos: Vector3, gold: bool) -> void:
	m.box_chamfered(Vector3(0.36, 0.08, 0.36), 0.03, pos, Parts.HULL_DARK, Vector3(0, 45, 0))
	for side: float in [-1.0, 1.0]:
		var foot := pos + LowPolyMesh.turn(Vector3(side * 0.1, 0.08, 0), Vector3(0, 45, 0))
		Parts.pipe_run(m, PackedVector3Array([foot, foot + Vector3(0, 0.26, 0), foot + Vector3(-0.22, 0.26, -0.22)]), 0.05, Parts.GUNMETAL, 12)
		Parts.torus(m, 0.07, 0.02, 10, 4, foot + Vector3(0, 0.14, 0), GOLD_WHEEL if gold else WHEEL)


## The glass panels shimmer, each pulsing on a phase of its own; the finial pulses as it turns.
static var CRYSTAL_PANEL := Surf.make(MaterialKit.Layer.GLASS, MaterialKit.CRYSTAL, 1.0, Surf.GLOSSY | Surf.PULSE)
## The high levels' own: the L7 lid lamps, pulsing in a wave round it; from the Obsidian tier the panels in
## a deeper pink, and the L8 crystal inlays round the plinth; the L9 crystal crown hovering over
## the finial, its shards and its obsidian ring bobbing together (their one phase is also the
## shards' PULSE offset), its ring gold at L10; the L10 mega crystal, a hologram shell of crystal
## round the violet core.
const DEEP_CRYSTAL := Color("e270ff")
static var LID_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var DEEP_PANEL := Surf.make(MaterialKit.Layer.GLASS, DEEP_CRYSTAL, 1.0, Surf.GLOSSY | Surf.PULSE)
static var SILO_INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
static var CROWN_SHARD := Surf.make(MaterialKit.Layer.CRYSTAL, DEEP_CRYSTAL, 1.5, Surf.GLOSSY | Surf.PULSE | Surf.BOB, false, true, 0.3)
static var CROWN_RING := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.3)
static var CROWN_GOLD_RING := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.3)
static var MEGA_SHELL := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.HOLO)

## The crystal silo's hexagons are turned so a flat face looks at the camera; its container's
## corner radius and the height of one row of panels (a row per level, plus two).
const HEXAGON := Vector3(0, -15, 0)
const CRYSTAL_SILO_RADIUS := 0.86
const PANEL_ROW := 0.2
## From L6 the container is wider, of bigger panels in fewer rows, by level from L6: its corner
## radius, the height of a row and the rows.
const GROWN_SILO_RADIUS := [0.96, 0.96, 1.0, 1.0, 1.0]
const GROWN_PANEL_ROW := [0.32, 0.32, 0.36, 0.36, 0.36]
const GROWN_ROWS := [5, 6, 6, 6, 6]
## The L10 mega crystal's height on the lid, and the security bot's round about the container.
const MEGA_CRYSTAL := 1.1
const CRYSTAL_GUARD_RADIUS := 1.38
const CRYSTAL_GUARD_HEIGHT := 2.0
const CRYSTAL_GUARD_RATE := 0.5


## A tall hexagonal container of glass panels shimmering with the crystal inside, framed by
## corner posts and bands, under a chamfered lid with a turning crystal finial, on a hexagonal
## plinth with a feed pump at its side. It grows a row of panels a level; L5 adds gold on the
## lid and the bands.
##
## From L6 it grows wider, of bigger panels: L6 a chrome frame and lid, cyan light bars between
## the rows, a chrome pump and a bigger finial turning in a chrome collar; L7 a row more, cyan
## strips up the corner posts and lamps pulsing in a wave round the lid; L8 an obsidian frame veined violet,
## the panels deeper pink and taller, crystal inlays round the plinth; L9 a crystal crown hovering
## over the finial, turning the other way; L10 a gold filigree frame and violet light bars, a mega
## crystal on the lid lit from within by the violet core in a gold cradle, a gold finial over it
## with the crown hovering round the crystal, and a security bot patrolling round the container.
static func build_crystal_silo(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	if level >= 6:
		_grown_crystal_silo(p, level)
		return
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	var radius := CRYSTAL_SILO_RADIUS
	m.lathe(PackedVector2Array([
		Vector2(1.12, 0), Vector2(1.12, 0.1), Vector2(1.04, 0.18), Vector2(0, 0.18),
	]), 6, Vector3(0, ground, 0), Parts.HULL_DARK, HEXAGON)
	var base := ground + 0.18
	var rows := level + 2
	var height := rows * PANEL_ROW
	# The panels, one per face and row, each on its own phase.
	for row: int in rows:
		for k: int in 6:
			var a := Parts.around(radius, 15.0 + 60.0 * k, base + row * PANEL_ROW)
			var b := Parts.around(radius, 75.0 + 60.0 * k, base + row * PANEL_ROW)
			m.polygon(PackedVector3Array([a, a + Vector3(0, PANEL_ROW, 0), b + Vector3(0, PANEL_ROW, 0), b]),
				CRYSTAL_PANEL.phased(fposmod(0.23 * k + 0.41 * row, 1.0)))
	for k: int in 6:
		var degrees := 15.0 + 60.0 * k
		m.box_chamfered(Vector3(0.13, height, 0.13), 0.03, Parts.around(radius, degrees, base), Parts.HULL_LIGHT,
			Vector3(0, 90.0 - degrees, 0))
	for row: int in rows + 1:
		var band := Parts.GOLD_TRIM if gold and row == rows else (CRYSTAL_ACCENT if row == 0 else Parts.HULL_LIGHT)
		m.lathe(PackedVector2Array([Vector2(radius + 0.04, 0), Vector2(radius + 0.04, 0.035), Vector2(radius, 0.035)]), 6,
			Vector3(0, base + row * PANEL_ROW - 0.0175, 0), band, HEXAGON)
	var lid := base + height + 0.03
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.08, 0), Vector2(radius + 0.08, 0.1), Vector2(radius - 0.12, 0.22), Vector2(0, 0.22),
	]), 6, Vector3(0, lid, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID, HEXAGON)
	m.lathe(PackedVector2Array([Vector2(0.24, 0), Vector2(0.24, 0.05), Vector2(0.2, 0.08), Vector2(0, 0.08)]), 6,
		Vector3(0, lid + 0.22, 0), Parts.HULL_DARK, HEXAGON)
	var finial := p.moving(Vector3(0, lid + 0.28, 0), Motion.spin(Vector3.UP, 0.5))
	_shard(finial, Vector3.ZERO, 0.46, 0.12, Vector3(0, 15, 0), CRYSTAL_SHARD)
	Parts.landing_light(m, Vector3(0.4, lid + 0.18, 0.24), 0.09, CRYSTAL_GLOW)
	# A ladder up the face on the camera's right.
	var apothem := radius * cos(PI / 6.0)
	Parts.ladder(m, Parts.around(apothem + 0.05, 345, base), height + 0.06, 0.2, 90.0 - 345.0, Parts.ROD)

	# The feed pump on the lit side, piped into the bottom row.
	var pump := Vector3(-1.08, ground, 0.62)
	m.box_chamfered(Vector3(0.34, 0.36, 0.42), 0.05, pump, Parts.HULL_MID)
	m.box(Vector3(0.2, 0.1, 0.44), pump + Vector3(0, 0.2, 0), CRYSTAL_GLOW)
	Parts.pipe_run(m, PackedVector3Array([pump + Vector3(0.12, 0.26, -0.12), Vector3(-0.66, base + 0.15, 0.36)]), 0.055, Parts.GUNMETAL, 12)


## The crystal silo from L6 (build_crystal_silo): the same container grown wider of bigger panels,
## its frame, lid and pump in the tier's armour.
static func _grown_crystal_silo(p: Parts, level: int) -> void:
	var m := p.body
	var tier := p.tier
	var crown := tier >= Parts.Tier.CROWN
	var frame := _silo_frame(tier, false)
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	var radius: float = GROWN_SILO_RADIUS[level - 6]
	var row_height: float = GROWN_PANEL_ROW[level - 6]
	var rows: int = GROWN_ROWS[level - 6]
	var plinth := radius + 0.26
	m.lathe(PackedVector2Array([
		Vector2(plinth, 0), Vector2(plinth, 0.1), Vector2(plinth - 0.08, 0.18), Vector2(0, 0.18),
	]), 6, Vector3(0, ground, 0), Parts.HULL_DARK, HEXAGON)
	var base := ground + 0.18
	var height := rows * row_height
	var panel := DEEP_PANEL if tier >= Parts.Tier.OBSIDIAN else CRYSTAL_PANEL
	for row: int in rows:
		for k: int in 6:
			var a := Parts.around(radius, 15.0 + 60.0 * k, base + row * row_height)
			var b := Parts.around(radius, 75.0 + 60.0 * k, base + row * row_height)
			m.polygon(PackedVector3Array([a, a + Vector3(0, row_height, 0), b + Vector3(0, row_height, 0), b]),
				panel.phased(fposmod(0.23 * k + 0.41 * row, 1.0)))
	for k: int in 6:
		var degrees := 15.0 + 60.0 * k
		var yaw := Vector3(0, 90.0 - degrees, 0)
		m.box_chamfered(Vector3(0.17, height, 0.17), 0.04, Parts.around(radius, degrees, base), frame, yaw)
		if level >= 7:
			m.box(Vector3(0.06, height - 0.12, 0.03), Parts.around(radius + 0.085, degrees, base + 0.06),
				_silo_strip(tier).phased(fposmod(k / 6.0, 1.0)), yaw)
	# The rims at the foot and the top, the light bars between the rows.
	for row: int in rows + 1:
		var band := _silo_strip(tier)
		if row == 0:
			band = CRYSTAL_ACCENT
		elif row == rows:
			band = Parts.GOLD_TRIM
		m.lathe(PackedVector2Array([Vector2(radius + 0.05, 0), Vector2(radius + 0.05, 0.05), Vector2(radius, 0.05)]), 6,
			Vector3(0, base + row * row_height - 0.025, 0), band, HEXAGON)
	if level >= 8:
		# Crystal inlays on the plinth's corners.
		for k: int in 6:
			_shard(m, Parts.around(plinth - 0.1, 15.0 + 60.0 * k, base - 0.02), 0.2, 0.06, Vector3.ZERO,
				SILO_INLAY.phased(k / 6.0))

	var lid := base + height + 0.03
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.1, 0), Vector2(radius + 0.1, 0.12), Vector2(radius - 0.14, 0.26), Vector2(0, 0.26),
	]), 6, Vector3(0, lid, 0), _silo_frame(tier, true), HEXAGON)
	m.lathe(PackedVector2Array([Vector2(radius + 0.115, 0.02), Vector2(radius + 0.115, 0.1)]), 6, Vector3(0, lid, 0),
		Parts.FILIGREE if crown else Parts.GOLD_TRIM, HEXAGON)
	var cap := lid + 0.26
	m.lathe(PackedVector2Array([Vector2(0.3, 0), Vector2(0.3, 0.06), Vector2(0.25, 0.1), Vector2(0, 0.1)]), 6,
		Vector3(0, cap, 0), Parts.GOLD_TRIM if crown else Parts.HULL_DARK, HEXAGON)
	if level >= 7:
		for k: int in 6:
			var degrees := 45.0 + 60.0 * k
			m.orb(0.06, 10, 4, Parts.around(radius - 0.02, degrees, lid + 0.2), LID_LAMP.phased(k / 6.0))
	var top := cap + 0.1
	var finial_at := top
	if crown:
		# The mega crystal on the lid: the violet core glowing up through a hologram crystal, in a
		# gold cradle; the finial turns on its tip.
		m.prism(0.3, 0.26, 0.08, 16, Vector3(0, top, 0), Parts.GOLD_ROUND)
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			Parts.beam(m, Parts.around(0.22, degrees, top + 0.04), Parts.around(0.36, degrees, top + 0.4), 0.07, Parts.GOLD_TRIM)
		_shard(m, Vector3(0, top + 0.06, 0), MEGA_CRYSTAL * 0.92, 0.22, Vector3(0, 15, 0), Parts.CORE_GLOW)
		_shard(m, Vector3(0, top + 0.02, 0), MEGA_CRYSTAL, 0.34, Vector3(0, 15, 0), MEGA_SHELL)
		finial_at = top + MEGA_CRYSTAL - 0.04
	var finial := p.moving(Vector3(0, finial_at, 0), Motion.spin(Vector3.UP, 0.5))
	var collar := Parts.GOLD_ROUND if crown else Parts.CHROME_ROUND
	Parts.torus(finial, 0.13, 0.035, 16, 6, Vector3.ZERO, collar)
	for k: int in 3:
		var degrees := 120.0 * k
		finial.strut(Parts.around(0.13, degrees, 0.05), Parts.around(0.07, degrees, 0.3), 0.045, collar)
	if crown:
		finial.prism(0.07, 0.0, 0.34, 12, Vector3(0, 0.06, 0), Parts.GOLD_ROUND)
	else:
		_shard(finial, Vector3(0, 0.02, 0), 0.62, 0.16, Vector3(0, 15, 0), CRYSTAL_SHARD)
	if level >= 9:
		# The crystal crown hovering over the finial, round the mega crystal at L10.
		var crown_at := top + MEGA_CRYSTAL * 0.45 if crown else finial_at + 0.82
		var hover := p.moving(Vector3(0, crown_at, 0), Motion.spin(Vector3.UP, -0.35))
		var ring_radius := 0.5 if crown else 0.26
		Parts.torus(hover, ring_radius, 0.035, 24, 6, Vector3.ZERO, CROWN_GOLD_RING if crown else CROWN_RING)
		for k: int in 6:
			var degrees := 60.0 * k
			_shard(hover, Parts.around(ring_radius, degrees, 0.03), 0.26, 0.055, Vector3(0, 15, 0),
				CROWN_SHARD)
	Parts.landing_light(m, Parts.around(radius - 0.06, 30, lid + 0.13), 0.1, CRYSTAL_GLOW)
	var apothem := radius * cos(PI / 6.0)
	Parts.ladder(m, Parts.around(apothem + 0.05, 345, base), height + 0.06, 0.2, 90.0 - 345.0, Parts.ROD)

	# The feed pump on the lit side, piped into the bottom row.
	var pump := Vector3(-1.18, ground, 0.68)
	m.box_chamfered(Vector3(0.38, 0.42, 0.46), 0.05, pump, frame)
	m.box(Vector3(0.24, 0.12, 0.48), pump + Vector3(0, 0.22, 0), CRYSTAL_GLOW)
	m.box(Vector3(0.4, 0.04, 0.48), pump + Vector3(0, 0.36, 0), _silo_strip(tier))
	Parts.pipe_run(m, PackedVector3Array([pump + Vector3(0.14, 0.3, -0.14), Parts.around(radius - 0.05, 150, base + 0.18)]),
		0.065, Parts.GUNMETAL, 12)
	if crown:
		Parts.escort_guard(p, CRYSTAL_GUARD_RADIUS, CRYSTAL_GUARD_HEIGHT, CRYSTAL_GUARD_RATE)


## The crystal silo's frame by tier from L6: chrome, obsidian from the Obsidian tier, gold
## filigree at the Crown (the lid, `lid`, stays obsidian under its filigree band).
static func _silo_frame(tier: int, lid: bool) -> Surf:
	if tier >= Parts.Tier.CROWN and not lid:
		return Parts.FILIGREE
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN
	return Parts.CHROME


## The crystal silo's light bars and strips by tier from L6: cyan, violet veins from the Obsidian
## tier, the violet core's glow at the Crown.
static func _silo_strip(tier: int) -> Surf:
	if tier >= Parts.Tier.CROWN:
		return Parts.CORE_GLOW
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.VEINS
	return Parts.CYAN_STRIP


static var VAULT_ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var VAULT_DOOR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var LID := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 1.5, Surf.LIT, true)
static var VAULT_SCREEN := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ANTIMATTER, 3.0)
static var VENT_CAP := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID, 3.0)
## The glow seams' current, the screen layer's lit segments: rising up the corners (FLOW) and
## running round the band (FLOW_U). Thin enough to need no outline.
static var SEAM := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ANTIMATTER, 3.0, Surf.UNLIT | Surf.FLOW, false, false, 0.75)
static var SEAM_BAND := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ANTIMATTER, 3.0, Surf.UNLIT | Surf.FLOW_U, false, false, 0.75)
## The containment pylons' cells pulse and their tips blink in a chase round the vault.
static var CELL := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE, true)
static var PYLON_TIP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.BLINK, true)
## The high levels' own: the core floating in its cradle from L4, pulsing and bobbing, in the
## violet core's glow at the Crown; the containment rings hovering round it from L6, obsidian with
## veins across their tops and a violet rim, bobbing with it (one phase for all of them, which is
## also the veins' FLOW speed and the PULSE offset); the L6 crystal inlays at the pylons' feet.
## The arcs are the siphon's high-level arcs (CYAN_ARC, VIOLET_ARC).
static var VAULT_CORE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true, 0.7)
static var VAULT_CROWN_CORE := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var CONTAINMENT_RING := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
static var CONTAINMENT_VEINS := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW | Surf.BOB, true,
	true, 0.7)
static var CONTAINMENT_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true,
	true, 0.7)
static var PYLON_INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)

## The antimatter vault's armoured cube, and its containment pylons' corners.
const VAULT_SIZE := 1.7
const VAULT_HEIGHT := 1.15
const VAULT_CHAMFER := 0.14
const VAULT_CORNERS := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]
## The pylons' corners in order round the vault, for the chase and the arcs.
const VAULT_ROUND := [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]
## From L4: the core's radius by level from L4, its lift over its cradle, and at L8 the gold
## pedestal raising the cradle off the lid's cap, so the core clears the front pylon's cap; the
## containment rings' radii about it (the L7 second ring wider, a gimbal round the first); the L8
## security bot's round, the other way from the rings, over the pylons' caps and their arcs (lower,
## it would pass through the corner pylons) and outside the rings.
const VAULT_CORE_RADII := [0.2, 0.24, 0.26, 0.28, 0.3]
const VAULT_CORE_LIFT := 0.12
const VAULT_PEDESTAL := 0.5
const CONTAINMENT_RADIUS := 0.46
const OUTER_CONTAINMENT_RADIUS := 0.64
const VAULT_GUARD_RADIUS := 1.25
const VAULT_GUARD_HEIGHT := 3.3
const VAULT_GUARD_RATE := -0.5


## A heavy chamfered armoured cube on a skirt, violet glow seams with current flowing round it
## and up its corners, a round vault door with a handwheel facing the lit side, a control
## screen on the other, and a containment pylon on each corner, their cells pulsing and their
## tips blinking in a chase round it. L2 adds an armoured domed lid and bigger pylons, L3
## bigger pylons again, gold trim, and arcs crackling between the pylons' tips.
##
## From L4 the pylons keep growing and an antimatter core floats in a cradle on the lid: L4 chrome
## plating on the cube (from then on), chrome pylons with cyan seams up them, a chrome lid, the core
## and cyan arcs between the tips; L5 a bigger core and cyan arcs from the tips down to it; L6
## obsidian pylons and skirt veined violet, crystal inlays at the pylons' feet, veins up the lid, a
## containment ring hovering round the core, turning (a moving part), and violet arcs; L7 a second,
## wider ring tilted the other way, counter-turning, a gyroscope round the core; L8 gold filigree
## over the pylons' heads and round the lid, the core raised on a gold pedestal clear of the pylons'
## caps, in the violet core's glow under a halo, the loudest arcs (doubled between the tips) and a
## security bot patrolling over the pylons' caps.
static func build_antimatter_vault(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	Parts.foundation(m, 3)
	var ground := Parts.PAD_HEIGHT
	m.box_chamfered(Vector3(2.1, 0.14, 2.1), 0.05, Vector3(0, ground, 0), Parts.OBSIDIAN if obsidian else ARMOUR)
	var floor_y := ground + 0.14
	var half := VAULT_SIZE * 0.5
	m.box_chamfered(Vector3(VAULT_SIZE, VAULT_HEIGHT, VAULT_SIZE), VAULT_CHAMFER, Vector3(0, floor_y, 0),
		Parts.CHROME if p.tier >= Parts.Tier.CHROME else VAULT_ARMOUR)
	# Seams: a band round the four faces, and one up each chamfered corner.
	for k: int in 4:
		var yaw := Vector3(0, 90 * k, 0)
		m.box(Vector3(VAULT_SIZE - 2 * VAULT_CHAMFER, 0.05, 0.02), LowPolyMesh.turn(Vector3(0, floor_y + 0.86, half), yaw), SEAM_BAND, yaw)
	for corner: Vector2 in VAULT_CORNERS:
		var edge := Vector3(corner.x, 0, corner.y) * (half - VAULT_CHAMFER * 0.5)
		m.box(Vector3(0.05, VAULT_HEIGHT - 0.2, 0.03), edge + Vector3(corner.x, 0, corner.y) * 0.012 + Vector3(0, floor_y + 0.06, 0),
			SEAM, Vector3(0, rad_to_deg(atan2(corner.x, corner.y)), 0))
	_vault_door(m, Vector3(0, floor_y + 0.52, half), gold)
	# The control screen on the shadowed face.
	m.box_chamfered(Vector3(0.06, 0.36, 0.56), 0.02, Vector3(half, floor_y + 0.5, 0), Parts.HULL_DARK)
	m.box(Vector3(0.02, 0.26, 0.44), Vector3(half + 0.05, floor_y + 0.55, 0), VAULT_SCREEN)

	var top := floor_y + VAULT_HEIGHT
	if level >= 2:
		m.prism(0.72, 0.68, 0.1, 24, Vector3(0, top, 0), Parts.HULL_DARK_ROUND)
		Parts.torus(m, 0.66, 0.035, 24, 6, Vector3(0, top + 0.065, 0), ANTIMATTER_GLOW)
		m.dome(0.62, 0.3, 24, 5, Vector3(0, top + 0.1, 0), _vault_lid(p.tier))
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			m.box_chamfered(Vector3(0.14, 0.2, 0.26), 0.03, Parts.around(0.6, degrees, top + 0.04),
				Parts.GOLD_TRIM if gold else Parts.HULL_MID, Vector3(0, 90.0 - degrees, 0))
		m.prism(0.18, 0.16, 0.06, 16, Vector3(0, top + 0.38, 0), Parts.HULL_DARK_ROUND)
		if level < 4:
			m.disc(0.12, 16, Vector3(0, top + 0.441, 0), ANTIMATTER_GLOW)
	else:
		m.box_chamfered(Vector3(0.7, 0.1, 0.7), 0.04, Vector3(0, top, 0), Parts.HULL_DARK)
		m.box(Vector3(0.5, 0.02, 0.5), Vector3(0, top + 0.1, 0), ANTIMATTER_GLOW)
	for k: int in 2:
		m.box_chamfered(Vector3(0.3, 0.08, 0.16), 0.02, Vector3(-0.5 + k, top, -0.62), VENT_CAP)

	var width := 0.24 + 0.05 * level
	var pylon_height := 0.85 + 0.2 * level
	var tips := PackedVector3Array()
	for k: int in VAULT_ROUND.size():
		var corner: Vector2 = VAULT_ROUND[k]
		tips.append(_containment_pylon(m, Vector3(corner.x * 1.06, ground + 0.14, corner.y * 1.06), width, pylon_height,
			level, p.tier, k / 4.0))
	if level == 3:
		for k: int in tips.size():
			Parts.arc(m, tips[k], tips[(k + 1) % tips.size()], 5, 0.07, ARC.phased(k / 4.0 + 0.1))
	if level < 4:
		return

	# The core floating in its cradle on the lid's cap, the arcs round it.
	var cradle := top + 0.44
	if crown:
		m.prism(0.13, 0.11, VAULT_PEDESTAL, 16, Vector3(0, cradle, 0), Parts.GOLD_ROUND)
		cradle += VAULT_PEDESTAL
	var core_radius: float = VAULT_CORE_RADII[level - 4]
	var core := Vector3(0, cradle + VAULT_CORE_LIFT + core_radius, 0)
	m.prism(0.22, 0.26, 0.08, 16, Vector3(0, cradle, 0), Parts.GOLD_ROUND if crown else _vault_lid(p.tier))
	for k: int in 3:
		var degrees := 30.0 + 120.0 * k
		Parts.beam(m, Parts.around(0.2, degrees, cradle + 0.04), Parts.around(core_radius + 0.06, degrees, core.y), 0.05,
			Parts.GOLD_TRIM if crown else Parts.CHROME)
	m.orb(core_radius, 16, 6, core, VAULT_CROWN_CORE if crown else VAULT_CORE)
	var arc := VIOLET_ARC if obsidian else CYAN_ARC
	for k: int in tips.size():
		Parts.arc(m, tips[k], tips[(k + 1) % tips.size()], 5, 0.07, arc.phased(k / 4.0 + 0.1))
		if crown:
			Parts.arc(m, tips[k], tips[(k + 1) % tips.size()], 6, 0.12, arc.phased(k / 4.0 + 0.6))
		if level >= 5:
			Parts.arc(m, tips[k], core + (tips[k] - core).normalized() * (core_radius + 0.04), 4, 0.05,
				arc.phased(k / 4.0 + 0.35))
	if level >= 6:
		# Veins up the lid between its blocks.
		for k: int in 4:
			Parts.dome_seam(m, 0.62, 0.3, Vector3(0, top + 0.1, 0), 90.0 * k, Parts.VEINS)
		_containment_ring(p, core, CONTAINMENT_RADIUS, Vector3(18, 0, 0), 0.4)
	if level >= 7:
		_containment_ring(p, core, OUTER_CONTAINMENT_RADIUS, Vector3(0, 0, 28), -0.55)
	if crown:
		m.lathe(PackedVector2Array([Vector2(0.725, 0.0), Vector2(0.725, 0.08)]), 24, Vector3(0, top + 0.01, 0), Parts.FILIGREE)
		# The halo over the core.
		Parts.torus(m, core_radius + 0.08, 0.04, 24, 6, core + Vector3(0, core_radius + 0.22, 0), Parts.CORE_GLOW)
		Parts.escort_guard(p, VAULT_GUARD_RADIUS, VAULT_GUARD_HEIGHT, VAULT_GUARD_RATE)


## The vault's lid by tier: hull mid, chrome from the Chrome tier, obsidian from the Obsidian tier.
static func _vault_lid(tier: int) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN_ROUND
	if tier >= Parts.Tier.CHROME:
		return Parts.CHROME_ROUND
	return LID


## A containment ring of radius `r` hovering round the vault's core (L6), tilted `tilt` and
## turning about the vertical at `rate`: an obsidian ring with veins across its top and a violet
## rim, bobbing with the core.
static func _containment_ring(p: Parts, core: Vector3, r: float, tilt: Vector3, rate: float) -> void:
	var ring := p.moving(core, Motion.spin(Vector3.UP, rate))
	ring.ring(r - 0.06, r + 0.06, 0.05, 24, Vector3(0, -0.025, 0), CONTAINMENT_RING, tilt)
	ring.lathe(PackedVector2Array([Vector2(r + 0.05, 0.027), Vector2(r - 0.05, 0.027)]), 24, Vector3.ZERO, CONTAINMENT_VEINS, tilt)
	ring.lathe(PackedVector2Array([Vector2(r + 0.065, -0.017), Vector2(r + 0.065, 0.017)]), 24, Vector3.ZERO, CONTAINMENT_RIM, tilt)


## The vault door: a round plate in a rim, a hub and a three-spoke handwheel, violet lock
## lights round it.
static func _vault_door(m: LowPolyMesh, centre: Vector3, gold: bool) -> void:
	var facing := Vector3(90, 0, 0)
	m.tube(0, 0.4, 0.06, 24, centre, VAULT_DOOR, facing)
	Parts.torus(m, 0.42, 0.05, 24, 10, centre + Vector3(0, 0, -0.01), Parts.GOLD_ROUND if gold else Parts.GUNMETAL, facing)
	m.tube(0, 0.1, 0.08, 16, centre + Vector3(0, 0, 0.06), Parts.HULL_DARK_ROUND, facing)
	for k: int in 3:
		var spoke := Vector3(cos(PI * k / 3), sin(PI * k / 3), 0) * 0.24
		m.strut(centre + Vector3(0, 0, 0.11) - spoke, centre + Vector3(0, 0, 0.11) + spoke, 0.05, Parts.ROD)
	for k: int in 6:
		var angle := TAU * (k + 0.5) / 6
		m.box(Vector3(0.06, 0.06, 0.04), centre + Vector3(cos(angle) * 0.32, sin(angle) * 0.32 - 0.03, 0.05), ANTIMATTER_GLOW)


## A containment pylon: an armoured column on a foot with its glowing containment cell bared
## between two bars, under a cap whose emitter leans in towards the vault; its cell and its
## tip on `phase`. Returns the tip's centre. From L4 its armour is the tier's (chrome, obsidian
## from the Obsidian tier, gold filigree over its head at the Crown) with a light seam up each face
## of it (cyan, violet veins from the Obsidian tier); from L6 crystal inlays stand on its foot.
static func _containment_pylon(m: LowPolyMesh, foot: Vector3, width: float, height: float, level: int, tier: int,
		phase: float) -> Vector3:
	var gold := tier >= Parts.Tier.GOLD
	var square := Vector3(0, 45, 0)
	var lower := PYLON_ARMOUR
	if tier >= Parts.Tier.OBSIDIAN:
		lower = Parts.OBSIDIAN
	elif tier >= Parts.Tier.CHROME:
		lower = Parts.CHROME
	var upper := Parts.FILIGREE if tier >= Parts.Tier.CROWN else lower
	m.box_chamfered(Vector3(width + 0.14, 0.12, width + 0.14), 0.04, foot, Parts.HULL_DARK)
	m.box_chamfered(Vector3(width, height * 0.36, width), 0.04, foot, lower, square)
	m.prism(width * 0.36, width * 0.36, height * 0.34, 16, foot + Vector3(0, height * 0.36, 0), CELL.phased(phase))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.05, height * 0.34, 0.05), foot + LowPolyMesh.turn(Vector3(side * width * 0.4, height * 0.36, 0), square),
			Parts.ROD, square)
	m.box_chamfered(Vector3(width, height * 0.3, width), 0.04, foot + Vector3(0, height * 0.7, 0), upper, square)
	if level >= 4:
		var seam := Parts.VEINS if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP.phased(phase)
		for k: int in 4:
			var yaw := Vector3(0, 45.0 + 90.0 * k, 0)
			for section: Vector2 in [Vector2(0.0, 0.36), Vector2(0.7, 0.3)]:
				m.box(Vector3(0.06, height * section.y - 0.1, 0.02),
					foot + LowPolyMesh.turn(Vector3(0, height * section.x + 0.05, width * 0.5 + 0.005), yaw), seam, yaw)
	if level >= 6:
		var out := Vector2(signf(foot.x), signf(foot.z))
		for side: Vector2 in [Vector2(out.x, -out.y), Vector2(-out.x, out.y)]:
			var corner := Vector3(side.x, 0, side.y) * (width * 0.5 + 0.02)
			_shard(m, foot + corner + Vector3(0, 0.12, 0), 0.2, 0.05, Vector3.ZERO, PYLON_INLAY.phased(phase))
	var cap := foot + Vector3(0, height, 0)
	m.box_chamfered(Vector3(width + 0.08, 0.08, width + 0.08), 0.03, cap, Parts.GOLD_TRIM if gold else Parts.HULL_DARK, square)
	var inward := Vector3(-foot.x, 0, -foot.z).normalized()
	var lean := Vector3(40, rad_to_deg(atan2(inward.x, inward.z)), 0)
	var horn := cap + Vector3(0, 0.08, 0)
	m.prism(0.07, 0.05, 0.24, 16, horn, Parts.HULL_MID_ROUND, lean)
	var tip := horn + LowPolyMesh.turn(Vector3(0, 0.24, 0), lean)
	m.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, tip, PYLON_TIP.phased(phase), lean)
	return tip + LowPolyMesh.turn(Vector3(0, 0.03, 0), lean)
