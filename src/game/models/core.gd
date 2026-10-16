extends RefCounted
## Models of the core: the Command Center, plus the scaffold shown while a building is first
## built and the hull block an unknown type gets (both by footprint size, not level).
##
## The Command Center has ten levels, each its own level's tier (BuildingModels.tier_of): Base to
## L4, Gold at L5, Chrome at L6 and 7, Obsidian at L8 and 9, Crown at L10. Its parts follow the
## level and their paint the tier; from L6 the dome rides a tower of storeys that grows to the
## crown spire, within 7 units.
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type.

## The Command Center's own surfaces: core glass and core gold are its accents, its glows are
## core glass, the L4 containment ring antimatter, the L5 beacon gold.
static var STEP := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID)
static var WINDOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, 1.0, Surf.UNLIT)
static var GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, 1.0, Surf.UNLIT, true)
static var GOLD_GLOW := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, 1.0, Surf.UNLIT, true)
## The containment ring's current runs round it: the crystal layer's inked facets, which vary
## along U (the glow layer's faint stripes do not), carried by FLOW_U. Its clamps' nodes pulse.
static var CONTAINMENT := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ANTIMATTER, 2.0, Surf.UNLIT | Surf.FLOW_U, true, true, 0.75)
static var CONTAINMENT_NODE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The screens' rows scroll.
static var SCREENS := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.CORE_GLASS, 2.0, Surf.FLOW, true, true, 0.6)
## The sensor masts' bulbs blink, each on its own phase (and the landing lamps chase on it from
## the Chrome tier); the L5 beacon pulses.
static var MAST_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var GOLD_MAST_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, 1.0, Surf.UNLIT | Surf.BLINK, true)
static var BEACON := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The hangar door's warning lamps, which chase across its lintel.
static var DOOR_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.BLINK)
## The hologram of the base's own planet over the dome (L3+): the globe in the planet's violet,
## so it stands off the cyan dome, its ring and its projector in core glass.
static var HOLO_GLOBE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.HOLO | Surf.BOB, true)
static var HOLO_RING := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, 1.0, Surf.HOLO | Surf.BOB, true)
static var PROJECTOR := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GLASS, 1.0, Surf.UNLIT | Surf.PULSE)
static var DOOR := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK, 2.0)
static var ROOF_VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_MID, 2.0)
## The high levels' own: the L7 conduits' current flowing up the tower; the L8 crystal inlays on
## the wing tips, pulsing; the L8 ring hovering over the dome's gold ring, obsidian with veins
## across its top and a violet rim glowing round it, bobbing together (their one phase is also the
## veins' FLOW speed and the rim's PULSE offset); the L9 station orbiting the hologram, in core
## gold; the L9 arcs from the spire, in the core's violet; the L10 violet glass round the
## antimatter core and the beam over the crown, holograms.
static var CONDUIT := Parts.current(MaterialKit.ENERGY, 0.75)
static var INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
static var HOVER_RING := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
static var HOVER_VEINS := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW | Surf.BOB, true, true,
	0.7)
static var HOVER_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var HOLO_STATION := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CORE_GOLD, 1.0, Surf.HOLO | Surf.BOB, true)
static var ARC := Parts.spark(Parts.CORE_GLOW_TINT)
static var CORE_GLASS_BAND := Surf.make(MaterialKit.Layer.GLASS, Parts.CORE_GLOW_TINT, 1.0, Surf.HOLO, true)
static var BEAM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.HOLO, true)

## The Command Center's deck (the top of its stepped foundation) and the tall drum on it.
const DECK := 0.52
const DRUM_RADIUS := 1.05
const DRUM_HEIGHT := 1.17
const DOME_RADIUS := 1.0
const DOME_HEIGHT := 0.73
## The ring of rooms L3 adds round the drum's foot, out to this radius.
const ROOMS_RADIUS := 1.55
const ROOMS_HEIGHT := 0.55
## Where the hangar door faces (degrees around Y from +X towards +Z, as Parts.around): the
## corner nearest the camera. The L2 wings stand on the corners either side of it, the
## drum's pilasters between them.
const DOOR_FACING := 45.0
const WINGS := [135.0, 315.0]
const PILASTERS := [0.0, 90.0, 180.0, 270.0]
## The sensor masts stand on the deck behind the dome (L4 adds one on each wing), and the
## dish pylon on the deck behind the dome's right, so the dish never hides the L5 spire.
const MASTS := [170.0, 280.0]
const DISH_CORNER := 250.0
## The hologram's centre above the dome's apex, its globe's radius, and its ring's tilt.
const HOLO_LIFT := 0.42
const HOLO_RADIUS := 0.28
const HOLO_TILT := Vector3(20, 0, 0)
## The tower the dome rides from L6: its storeys, the level each is added at and its height, on
## the drum and under the dome; at L10 the antimatter core's band between the drum and them.
const STOREY_RADIUS := 0.98
const STOREY_LEVELS := [6, 7, 9]
const STOREY_HEIGHTS := [0.7, 0.5, 0.5]
const CORE_BAND := 0.32
## The wing the second comms dish (L6) stands on, across the dome from the first dish's pylon.
const WING_DISH := 135.0
## The L10 hover skiff's round: out past the dish pylon, between the dishes' heights.
const SKIFF_RADIUS := 1.85
const SKIFF_HEIGHT := 3.0


## A broad two-tier stepped foundation under a tall hull-light drum with pilasters and two
## rows of windows, crowned by a core glass dome ringed in gold; a hangar door with hazard
## stripes and a chase of warning lamps facing the camera, two sensor masts with blinking
## bulbs and a spinning comms dish behind. Each level adds to it: L2 two wing modules flanking
## the drum, their screens scrolling, L3 a ring of rooms with scrolling screens round the
## drum's foot and the hologram of the base's planet floating over the dome, its ring turning,
## L4 a glowing antimatter containment ring round the drum, its current flowing, and two more
## masts, L5 gold trim and a beacon spire up to 3.2, the tallest building on the base, its
## beacon pulsing.
##
## From L6 the dome rides a tower (_storey), the dish's pylon carrying it up beside the dome:
## L6 a chrome storey with a band of windows and cyan strips, chrome caps on the wings, a second
## dish on a wing (a third moving part) and the landing lamps chasing in two rings, up to 3.9;
## L7 a second storey with a lit observation band, cyan conduits up the tower into the dome's
## ring, three hologram moons turning with the ring and a chrome collar on the spire, 4.4; L8
## obsidian over the storeys and the wing caps, violet veins up them, crystal inlays on the wing
## tips, an obsidian ring hovering over the dome's gold ring and the spire grown on an obsidian
## shaft, 5.2; L9 a third storey, a second containment ring over the first, its current running
## the other way, violet arcs from the spire to the dome's gold ring and a station orbiting the
## hologram, 6.0; L10 gold filigree over the storeys and the wing caps, filigree banners on the
## wings, the antimatter core glowing in a glass band at the tower's foot, a crown spire with a
## hologram beam up to 6.94 and a hover skiff circling the tower as its escort.
static func build_command_center(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	Parts.foundation(m, 4)
	m.box_chamfered(Vector3(3.7, 0.2, 3.7), 0.08, Vector3(0, Parts.PAD_HEIGHT, 0), STEP)
	m.box_chamfered(Vector3(3.3, 0.2, 3.3), 0.08, Vector3(0, 0.32, 0), Parts.HULL_MID)
	var trim := Parts.GOLD_TRIM if gold else Parts.HULL_MID
	if level >= 5:
		m.box_chamfered(Vector3(3.76, 0.05, 3.76), 0.03, Vector3(0, 0.24, 0), trim)
		m.box_chamfered(Vector3(3.36, 0.05, 3.36), 0.03, Vector3(0, 0.44, 0), trim)
	for k: int in 4:
		# Landing lights on the deck's corners, chasing round it from the Chrome tier.
		Parts.landing_light(m, Parts.around(1.46 * sqrt(2.0), 45 + 90 * k, DECK), 0.09,
			MAST_LAMP.phased(Parts.chase(k, 4)) if chrome else GLOW)
	if level >= 6:
		# A second ring of lamps on the lower step, chasing the other way.
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			var out := 1.75 / maxf(absf(cos(deg_to_rad(degrees))), absf(sin(deg_to_rad(degrees))))
			m.prism(0.06, 0.05, 0.05, 8, Parts.around(out, degrees, 0.32), MAST_LAMP.phased(Parts.chase(7 - k, 8)),
				Parts.OCTAGON)

	# The drum: a flared skirt, a wall with a band and two rows of windows between pilasters,
	# a lip.
	m.lathe(PackedVector2Array([
		Vector2(DRUM_RADIUS + 0.12, 0), Vector2(DRUM_RADIUS + 0.05, 0.14), Vector2(DRUM_RADIUS, 0.17),
		Vector2(DRUM_RADIUS, DRUM_HEIGHT - 0.06), Vector2(DRUM_RADIUS + 0.05, DRUM_HEIGHT - 0.04),
		Vector2(DRUM_RADIUS + 0.05, DRUM_HEIGHT), Vector2(0, DRUM_HEIGHT),
	]), 24, Vector3(0, DECK, 0), Parts.HULL_LIGHT_ROUND)
	m.lathe(PackedVector2Array([Vector2(DRUM_RADIUS + 0.03, 0), Vector2(DRUM_RADIUS + 0.03, 0.07)]), 24,
		Vector3(0, DECK + 0.62, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)
	for degrees: float in PILASTERS:
		m.box_chamfered(Vector3(0.2, DRUM_HEIGHT - 0.12, 0.16), 0.04, Parts.around(DRUM_RADIUS + 0.02, degrees, DECK + 0.06),
			Parts.HULL_MID, Vector3(0, 90.0 - degrees, 0))
	for row: int in 2:
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			m.box(Vector3(0.2, 0.16, 0.04), Parts.around(DRUM_RADIUS - 0.01, degrees, DECK + 0.36 + 0.46 * row),
				WINDOW, Vector3(0, 90.0 - degrees, 0))
	# The tower the dome rides from L6: the core's band at L10, then the storeys.
	var dome_base := DECK + DRUM_HEIGHT
	if level >= 10:
		_core_band(m, dome_base)
		dome_base += CORE_BAND
	for i: int in STOREY_LEVELS.size():
		var from_level: int = STOREY_LEVELS[i]
		if level >= from_level:
			var height: float = STOREY_HEIGHTS[i]
			_storey(m, i, dome_base, height, level, p.tier)
			dome_base += height
	if level >= 7:
		# Cyan conduits up the tower from the drum's lip into the dome's gold ring.
		for degrees: float in PILASTERS:
			Parts.pipe(m, Parts.around(1.09, degrees, DECK + DRUM_HEIGHT - 0.04), Parts.around(1.09, degrees, dome_base - 0.02),
				0.04, CONDUIT, 8, false)
	Parts.torus(m, DOME_RADIUS + 0.02, 0.08, 24, 10, Vector3(0, dome_base - 0.06, 0), Parts.GOLD_ROUND)
	m.dome(DOME_RADIUS, DOME_HEIGHT, 16, 7, Vector3(0, dome_base, 0), Parts.GLASS)
	var apex := dome_base + DOME_HEIGHT
	m.prism(0.2, 0.16, 0.08, 16, Vector3(0, apex - 0.03, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)

	_hangar_door(m, gold)
	if level >= 2:
		for degrees: float in WINGS:
			_wing(m, degrees, level, p.tier)
	if level >= 3:
		_rooms(m, gold)
	if level >= 4:
		# The antimatter containment ring round the drum's upper half, clamped to the pilasters,
		# a glowing node on each clamp.
		var ring_y := DECK + 1.0
		Parts.torus(m, DRUM_RADIUS + 0.2, 0.08, 24, 6, Vector3(0, ring_y - 0.08, 0), CONTAINMENT)
		for degrees: float in PILASTERS:
			var yaw := Vector3(0, 90.0 - degrees, 0)
			m.box_chamfered(Vector3(0.16, 0.24, 0.3), 0.03, Parts.around(DRUM_RADIUS + 0.16, degrees, ring_y - 0.12), Parts.HULL_DARK, yaw)
			m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, Parts.around(DRUM_RADIUS + 0.2, degrees, ring_y + 0.1),
				CONTAINMENT_NODE.phased(degrees / 360.0), yaw)
	if level >= 9:
		# A second containment ring over the first, its current running the other way, clamped
		# between the first's clamps.
		var upper_y := DECK + 1.1
		Parts.torus(m, DRUM_RADIUS + 0.2, 0.08, 24, 6, Vector3(0, upper_y, 0), CONTAINMENT.phased(0.25))
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			var yaw := Vector3(0, 90.0 - degrees, 0)
			m.box_chamfered(Vector3(0.16, 0.22, 0.3), 0.03, Parts.around(DRUM_RADIUS + 0.16, degrees, upper_y - 0.04), Parts.HULL_DARK, yaw)
			m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, Parts.around(DRUM_RADIUS + 0.2, degrees, upper_y + 0.18),
				CONTAINMENT_NODE.phased(degrees / 360.0), yaw)
	if level >= 5:
		_spire(m, apex, level, p.tier)
	if level >= 3:
		_hologram(p, m, apex, level)

	# Two sensor masts on the deck and the dish's pylon, behind the dome. The masts keep their
	# height as the tower grows; from L6 the pylon carries the dish up beside the lifted dome on a
	# chrome section.
	var base_apex := DECK + DRUM_HEIGHT + DOME_HEIGHT
	for k: int in MASTS.size():
		var degrees: float = MASTS[k]
		var foot := Parts.around(1.47, degrees, DECK)
		m.box_chamfered(Vector3(0.18, 0.14, 0.18), 0.04, foot, Parts.HULL_DARK, Vector3(0, 90.0 - degrees, 0))
		Parts.mast(m, foot + Vector3(0, 0.14, 0), base_apex - 0.56 + 0.12 * k, 0.08, (GOLD_MAST_LAMP if gold else MAST_LAMP).phased(0.5 * k))
	var pylon := Parts.around(1.5, DISH_CORNER, DECK)
	var pylon_height := DRUM_HEIGHT + 0.2
	m.box_chamfered(Vector3(0.34, 0.16, 0.34), 0.05, pylon, Parts.HULL_DARK, Vector3(0, 45, 0))
	m.prism(0.13, 0.09, pylon_height, 16, pylon + Vector3(0, 0.16, 0), Parts.HULL_MID_ROUND)
	var lift := dome_base - (DECK + DRUM_HEIGHT)
	if level >= 6:
		var joint := pylon + Vector3(0, 0.16 + pylon_height, 0)
		var section := Parts.CHROME_ROUND if chrome else Parts.HULL_MID_ROUND
		m.prism(0.09, 0.075, lift, 16, joint, section)
		m.ring(0.085, 0.13, 0.07, 16, joint - Vector3(0, 0.035, 0), section)
	_comms_dish(p.moving(pylon + Vector3(0, 0.16 + pylon_height + lift, 0), Motion.spin(Vector3.UP, 0.8)), gold)
	if level >= 6:
		_wing_dish(p, gold)
	if level >= 8:
		# An obsidian ring hovering over the dome's gold ring, bobbing, veins running across its top
		# and a violet rim glowing round it.
		var hover := Vector3(0, dome_base + 0.14, 0)
		m.ring(1.16, 1.3, 0.05, 24, hover, HOVER_RING)
		m.lathe(PackedVector2Array([Vector2(1.28, 0.052), Vector2(1.18, 0.052)]), 24, hover, HOVER_VEINS)
		m.lathe(PackedVector2Array([Vector2(1.305, 0.008), Vector2(1.305, 0.042)]), 24, hover, HOVER_RIM)
	if level >= 9:
		# Violet arcs crackling from the spire down to the dome's gold ring, which stays still
		# under the bobbing hovering ring.
		for k: int in 4:
			var degrees := 90.0 * k
			Parts.arc(m, Parts.around(0.08, degrees, apex + 0.95), Parts.around(1.06, degrees, dome_base + 0.09), 6, 0.06,
				ARC.phased(k / 4.0))
	if level >= 10:
		Parts.escort_skiff(p, SKIFF_RADIUS, SKIFF_HEIGHT, 0.45)


## The hangar door facing the camera: a block off the drum with a roll-up door framed in
## hazard stripes, and a hazard-striped apron on the deck before it.
static func _hangar_door(m: LowPolyMesh, gold: bool) -> void:
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var block := Parts.around(1.27, DOOR_FACING, DECK)
	m.box_chamfered(Vector3(0.8, 0.75, 0.76), 0.06, block, Parts.HULL_LIGHT, yaw)
	m.box_chamfered(Vector3(0.86, 0.06, 0.82), 0.03, block + Vector3(0, 0.75, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID, yaw)
	var front := block + LowPolyMesh.turn(Vector3(0, 0, 0.38), yaw)
	m.box(Vector3(0.52, 0.5, 0.04), front, DOOR, yaw)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.1, 0.56, 0.06), front + LowPolyMesh.turn(Vector3(side * 0.31, 0, 0), yaw), Parts.HAZARD, yaw)
	m.box(Vector3(0.72, 0.08, 0.06), front + Vector3(0, 0.52, 0), Parts.HAZARD, yaw)
	# Four warning lamps over the lintel, chasing across it.
	for k: int in 4:
		m.box(Vector3(0.09, 0.06, 0.05), front + LowPolyMesh.turn(Vector3(-0.24 + 0.16 * k, 0.62, 0.0), yaw),
			DOOR_LAMP.phased(k / 4.0), yaw)
	m.box(Vector3(0.7, 0.012, 0.26), Parts.around(1.8, DOOR_FACING, DECK), Parts.HAZARD, yaw)


## The hologram over the dome from L3: a projector lens on the apex cap, a globe of the base's
## own planet floating over it, and a ring round the globe, tilted, turning as a moving part,
## both bobbing together. At L5 the beacon spire runs up through the globe as its axis. L7 puts
## three moons on the ring's plane and L9 a station further out, in core gold, turning with it.
static func _hologram(p: Parts, m: LowPolyMesh, apex: float, level: int) -> void:
	m.disc(0.15, 16, Vector3(0, apex + 0.051, 0), PROJECTOR)
	var centre := Vector3(0, apex + HOLO_LIFT, 0)
	m.orb(HOLO_RADIUS, 16, 5, centre, HOLO_GLOBE)
	var ring := p.moving(centre, Motion.spin(Vector3.UP, 0.35))
	ring.lathe(PackedVector2Array([Vector2(HOLO_RADIUS + 0.16, 0), Vector2(HOLO_RADIUS + 0.08, 0)]), 24, Vector3.ZERO,
		HOLO_RING, HOLO_TILT)
	if level >= 7:
		for k: int in 3:
			ring.orb(0.075, 10, 4, LowPolyMesh.turn(Parts.around(HOLO_RADIUS + 0.3, 120.0 * k, 0.0), HOLO_TILT), HOLO_RING)
	if level >= 9:
		# The station: a core in a flat ring with a solar panel either side.
		var at := LowPolyMesh.turn(Parts.around(HOLO_RADIUS + 0.46, 60.0, 0.0), HOLO_TILT)
		ring.orb(0.05, 8, 4, at, HOLO_STATION)
		ring.ring(0.07, 0.11, 0.02, 12, at - LowPolyMesh.turn(Vector3(0, 0.01, 0), HOLO_TILT), HOLO_STATION, HOLO_TILT)
		for side: float in [-1.0, 1.0]:
			ring.box(Vector3(0.12, 0.012, 0.06), at + LowPolyMesh.turn(Vector3(side * 0.18, -0.006, 0), HOLO_TILT), HOLO_STATION,
				HOLO_TILT)


## The beacon spire from L5: a tapered mast 0.8 above the dome's apex, gold from the Gold tier, a
## collar at its foot (a chunkier chrome one from L7), a pulsing orb at 3.2 at L5; it runs up
## through the hologram's globe as its axis. From L8 it grows on an obsidian shaft whose upper
## half is veins, a gold ring at the joint, its beacon at 5.2 (L8) and 6.0 (L9); at L10 it ends in
## a gold crown of six prongs round a glowing antimatter orb, a hologram beam rising from it.
static func _spire(m: LowPolyMesh, apex: float, level: int, tier: int) -> void:
	var spire := Parts.GOLD_ROUND if tier >= Parts.Tier.GOLD else Parts.HULL_MID_ROUND
	var collar := Parts.CHROME_ROUND if tier >= Parts.Tier.CHROME else spire
	if level < 8:
		m.prism(0.075, 0.03, 0.66, 16, Vector3(0, apex + 0.05, 0), spire)
		if level >= 7:
			Parts.torus(m, 0.1, 0.045, 12, 6, Vector3(0, apex + 0.06, 0), collar)
		else:
			Parts.torus(m, 0.08, 0.03, 12, 6, Vector3(0, apex + 0.1, 0), spire)
		m.orb(0.09, 12, 6, Vector3(0, apex + 0.69, 0), BEACON)
		return
	var top := apex + (1.49 if level == 8 else (1.79 if level == 9 else 1.45))
	var joint := apex + 0.75
	m.prism(0.1, 0.075, joint - apex - 0.05, 16, Vector3(0, apex + 0.05, 0), _armour(tier, true))
	m.prism(0.075, 0.045, top - joint, 16, Vector3(0, joint, 0), _strip(tier))
	Parts.torus(m, 0.1, 0.045, 12, 6, Vector3(0, apex + 0.06, 0), collar)
	Parts.torus(m, 0.08, 0.03, 12, 6, Vector3(0, joint - 0.03, 0), spire)
	if level < 10:
		m.orb(0.09, 12, 6, Vector3(0, top, 0), BEACON)
		return
	m.ring(0.07, 0.17, 0.07, 16, Vector3(0, top - 0.04, 0), spire)
	for k: int in 6:
		var degrees := 60.0 * k
		m.cone(0.04, 0.26, 8, Parts.around(0.135, degrees, top), spire, Parts.facing(Parts.around(0.35, degrees, 1.0)))
	m.orb(0.12, 12, 6, Vector3(0, top + 0.16, 0), Parts.CORE_GLOW)
	m.prism(0.08, 0.16, 0.8, 16, Vector3(0, top + 0.25, 0), BEAM)


## A storey of the tower the dome rides from L6, `index` from the drum up, `height` tall on `y`:
## a drum of the tier's armour (chrome, obsidian from the Obsidian tier) with a flared foot and a
## gold lip, eight light strips up it (cyan, violet veins from the Obsidian tier), between them a
## band of windows, the second storey's a lit observation band instead; at L10 a band of gold
## filigree round its foot. Its top is left open inside the lip, under the dome or the next storey.
static func _storey(m: LowPolyMesh, index: int, y: float, height: float, level: int, tier: int) -> void:
	var r := STOREY_RADIUS
	m.lathe(PackedVector2Array([Vector2(r + 0.04, 0), Vector2(r, 0.06), Vector2(r, height - 0.08)]), 24, Vector3(0, y, 0),
		_armour(tier, true))
	m.lathe(PackedVector2Array([
		Vector2(r, height - 0.08), Vector2(r + 0.06, height - 0.06), Vector2(r + 0.06, height), Vector2(0.9, height),
	]), 24, Vector3(0, y, 0), Parts.GOLD_ROUND if tier >= Parts.Tier.GOLD else Parts.HULL_MID_ROUND)
	for k: int in 8:
		var degrees := 45.0 * k
		m.box(Vector3(0.14, height - 0.2, 0.05), Parts.around(r + 0.005, degrees, y + 0.08), _strip(tier),
			Vector3(0, 90.0 - degrees, 0))
	var middle := y + height * 0.5
	if index == 1:
		m.lathe(PackedVector2Array([Vector2(r + 0.015, 0), Vector2(r + 0.015, 0.16)]), 24, Vector3(0, middle - 0.08, 0), GLOW)
	else:
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			m.box(Vector3(0.24, 0.2, 0.04), Parts.around(r - 0.01, degrees, middle - 0.1), WINDOW, Vector3(0, 90.0 - degrees, 0))
	if level >= 10:
		m.lathe(PackedVector2Array([Vector2(r + 0.035, 0), Vector2(r + 0.035, 0.08)]), 24, Vector3(0, y + 0.07, 0),
			Parts.FILIGREE)


## The antimatter core's band at the tower's foot (L10), CORE_BAND tall on `y`: the core glowing
## violet and pulsing behind a hologram glass band, between gold rims, with eight gold mullions.
static func _core_band(m: LowPolyMesh, y: float) -> void:
	var at := Vector3(0, y, 0)
	m.prism(0.92, 0.92, CORE_BAND, 24, at, Parts.CORE_GLOW)
	m.lathe(PackedVector2Array([Vector2(0.99, 0.04), Vector2(0.99, CORE_BAND - 0.04)]), 24, at, CORE_GLASS_BAND)
	for rim: float in [0.0, CORE_BAND - 0.05]:
		m.lathe(PackedVector2Array([Vector2(1.02, 0), Vector2(1.02, 0.05), Vector2(0.92, 0.05)]), 24, at + Vector3(0, rim, 0),
			Parts.GOLD_ROUND)
	for k: int in 8:
		var degrees := 45.0 * k
		m.box(Vector3(0.07, CORE_BAND, 0.07), Parts.around(0.99, degrees, y), Parts.GOLD_TRIM, Vector3(0, 90.0 - degrees, 0))


## The tower's and the wing caps' armour by tier: obsidian from the Obsidian tier, chrome at the
## Chrome tier, hull below it (no level that adds it is below Chrome).
static func _armour(tier: int, smooth: bool) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return Parts.OBSIDIAN_ROUND if smooth else Parts.OBSIDIAN
	if tier >= Parts.Tier.CHROME:
		return Parts.CHROME_ROUND if smooth else Parts.CHROME
	return Parts.HULL_MID_ROUND if smooth else Parts.HULL_MID


## The light strips up the armour by tier: violet veins from the Obsidian tier, cyan below it.
static func _strip(tier: int) -> Surf:
	return Parts.VEINS if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP


## A wing module flanking the drum: a chamfered block 1.2 long, its long side to the camera
## with a row of windows and a vent on its roof. From L4 a sensor mast stands on its far end;
## from L6 an armoured cap clads that end (_wing_cap).
static func _wing(m: LowPolyMesh, degrees: float, level: int, tier: int) -> void:
	var gold := tier >= Parts.Tier.GOLD
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var block := Parts.around(1.25, degrees, DECK)
	m.box_chamfered(Vector3(1.2, 0.8, 0.7), 0.07, block, Parts.HULL_LIGHT, yaw)
	m.box(Vector3(0.9, 0.12, 0.04), block + LowPolyMesh.turn(Vector3(0, 0.46, 0.35), yaw), WINDOW, yaw)
	m.box(Vector3(0.9, 0.06, 0.04), block + LowPolyMesh.turn(Vector3(0, 0.22, 0.35), yaw), SCREENS, yaw)
	var roof := block + Vector3(0, 0.8, 0)
	m.box_chamfered(Vector3(0.5, 0.08, 0.4), 0.02, roof, ROOF_VENT, yaw)
	if level >= 5:
		m.box_chamfered(Vector3(1.26, 0.05, 0.76), 0.02, block + Vector3(0, 0.1, 0),
			Parts.GOLD_TRIM if gold else Parts.HULL_MID, yaw)
	if level >= 4:
		var foot := Parts.around(1.62, degrees, roof.y)
		m.box_chamfered(Vector3(0.16, 0.1, 0.16), 0.03, foot, Parts.HULL_DARK, yaw)
		Parts.mast(m, foot + Vector3(0, 0.1, 0), 1.0, 0.07, (GOLD_MAST_LAMP if gold else MAST_LAMP).phased(fposmod(0.25 + degrees / 360.0, 1.0)))
	if level >= 6:
		_wing_cap(m, block, degrees, yaw, level, tier)


## The armoured cap over a wing's outer end from L6 (`block` the wing's foot, `yaw` its turn): a
## block of the tier's armour, the mast rising through it, a light strip up its face; from L8 a
## crystal inlaid over the strip and three crystal shards on its top; at L10 gold filigree round
## its top and along the wing's front edge, and a filigree banner with a glowing antimatter emblem
## on a pole on the cap.
static func _wing_cap(m: LowPolyMesh, block: Vector3, degrees: float, yaw: Vector3, level: int, tier: int) -> void:
	# The wing's local +X runs outward on one wing and inward on the other.
	var out := signf(LowPolyMesh.turn(Vector3.RIGHT, yaw).dot(Parts.around(1.0, degrees, 0.0)))
	var cap := block + LowPolyMesh.turn(Vector3(out * 0.45, 0, 0), yaw)
	m.box_chamfered(Vector3(0.36, 0.9, 0.8), 0.06, cap, _armour(tier, false), yaw)
	var face := cap + LowPolyMesh.turn(Vector3(0, 0, 0.4), yaw)
	m.box(Vector3(0.08, 0.36, 0.04), face + Vector3(0, 0.08, 0), _strip(tier), yaw)
	if level >= 8:
		m.prism(0.13, 0.13, 0.04, 4, face + Vector3(0, 0.6, 0), INLAY, Vector3(90, yaw.y, 0))
		# Three crystal shards growing from the cap's top behind the mast, leaning outward.
		var lean := Parts.facing(LowPolyMesh.turn(Vector3(out * 0.3, 1, 0), yaw))
		for k: int in 3:
			var shard := cap + LowPolyMesh.turn(Vector3(out * (0.04 + 0.08 * k), 0.9, -0.28 + 0.1 * k), yaw)
			m.cone(0.05, 0.22 - 0.05 * absf(k - 1), 8, shard, INLAY.phased(k / 3.0), lean)
	if level >= 10:
		m.box(Vector3(0.38, 0.07, 0.82), cap + Vector3(0, 0.76, 0), Parts.FILIGREE, yaw)
		m.box(Vector3(0.84, 0.06, 0.03), block + LowPolyMesh.turn(Vector3(-out * 0.18, 0.68, 0.35), yaw), Parts.FILIGREE, yaw)
		var pole := cap + LowPolyMesh.turn(Vector3(out * 0.12, 0.9, 0.22), yaw)
		m.prism(0.025, 0.02, 0.75, 8, pole, Parts.ROD)
		m.orb(0.045, 8, 4, pole + Vector3(0, 0.77, 0), Parts.GOLD_ROUND)
		var flag := pole + LowPolyMesh.turn(Vector3(-out * 0.15, 0.3, 0), yaw)
		m.box(Vector3(0.26, 0.4, 0.025), flag, Parts.FILIGREE, yaw)
		m.prism(0.07, 0.07, 0.02, 12, flag + LowPolyMesh.turn(Vector3(0, 0.2, 0.0125), yaw), Parts.CORE_GLOW,
			Vector3(90, yaw.y, 0))


## The second comms dish from L6, two thirds the size, on the WING_DISH wing's roof behind its
## vent, turning the other way on its own short pylon.
static func _wing_dish(p: Parts, gold: bool) -> void:
	var m := p.body
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var foot := Parts.around(1.4, WING_DISH, DECK + 0.8) + LowPolyMesh.turn(Vector3(0, 0, -0.28), yaw)
	m.box_chamfered(Vector3(0.2, 0.08, 0.2), 0.03, foot, Parts.HULL_DARK, yaw)
	var height := 1.95 - foot.y - 0.08
	m.prism(0.08, 0.06, height, 16, foot + Vector3(0, 0.08, 0), Parts.HULL_MID_ROUND)
	_comms_dish(p.moving(foot + Vector3(0, 0.08 + height, 0), Motion.spin(Vector3.UP, -0.6)), gold, 0.65)


## The ring of rooms round the drum's foot: a low round wall with a band of screens and a
## chamfered roof edge, the door, wings, masts and pylon rising through it.
static func _rooms(m: LowPolyMesh, gold: bool) -> void:
	m.lathe(PackedVector2Array([
		Vector2(ROOMS_RADIUS, 0), Vector2(ROOMS_RADIUS, ROOMS_HEIGHT - 0.06),
		Vector2(ROOMS_RADIUS - 0.06, ROOMS_HEIGHT), Vector2(DRUM_RADIUS, ROOMS_HEIGHT),
	]), 24, Vector3(0, DECK, 0), Parts.HULL_LIGHT_ROUND)
	m.lathe(PackedVector2Array([Vector2(ROOMS_RADIUS + 0.01, 0), Vector2(ROOMS_RADIUS + 0.01, 0.18)]), 24,
		Vector3(0, DECK + 0.2, 0), SCREENS)
	m.lathe(PackedVector2Array([Vector2(ROOMS_RADIUS + 0.03, 0), Vector2(ROOMS_RADIUS + 0.03, 0.05)]), 24,
		Vector3(0, DECK + ROOMS_HEIGHT - 0.11, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)


## The comms dish on its turntable, tilted up, with a glowing feed horn; it turns round the pylon.
## `size` scales it (the L6 wing dish's).
static func _comms_dish(s: LowPolyMesh, gold: bool, size: float = 1.0) -> void:
	s.prism(0.16 * size, 0.14 * size, 0.08 * size, 16, Vector3.ZERO, Parts.HULL_DARK_ROUND)
	s.box_chamfered(Vector3(0.1, 0.22, 0.14) * size, 0.03 * size, Vector3(0, 0.06, 0) * size, Parts.HULL_DARK)
	var tilt := Vector3(-35, 0, 0)
	var bowl := Vector3(0, 0.22, 0.04) * size
	Parts.dish(s, 0.46 * size, 0.18 * size, bowl, Parts.GOLD_ROUND if gold else Parts.HULL_LIGHT_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	s.strut(bowl + axis * 0.05 * size, bowl + axis * 0.38 * size, 0.04 * size, Parts.ROD)
	s.orb(0.06 * size, 12, 6, bowl + axis * 0.4 * size, GOLD_GLOW if gold else GLOW)


static func build_scaffold(p: Parts, size: int) -> void:
	var m := p.body
	var n := float(size)
	var half := 0.4 * n
	m.box(Vector3(0.9 * n, 0.12, 0.9 * n), Vector3.ZERO, Parts.surf("hull_dark"))
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		m.box(Vector3(0.12, 1.0, 0.12), Vector3(corner.x * half, 0.12, corner.y * half), Parts.surf("hazard"))
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.9 * n, 0.1, 0.1), Vector3(0, 1.05, side * half), Parts.surf("hazard"))
		m.box(Vector3(0.1, 0.1, 0.9 * n), Vector3(side * half, 0.95, 0), Parts.surf("hazard"))
	m.strut(Vector3(-half, 0.12, half), Vector3(half, 1.05, half), 0.08, Parts.surf("hazard"))


## Unknown types: a hull block with a hazard stripe.
static func build_generic(p: Parts, size: int) -> void:
	var n := float(size)
	p.body.box(Vector3(0.8 * n, 0.8, 0.8 * n), Vector3.ZERO, Parts.surf("hull_light"))
	p.body.box(Vector3(0.82 * n, 0.14, 0.82 * n), Vector3(0, 0.45, 0), Parts.surf("hazard"))
