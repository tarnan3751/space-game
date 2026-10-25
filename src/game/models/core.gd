extends RefCounted
## Models of the core: the Command Center, plus the scaffold shown while a building is first
## built and the hull block an unknown type gets (both by footprint size, not level).
##
## The Command Center has ten levels, each its own level's tier (BuildingModels.tier_of): Base to
## L4, Gold at L5, Chrome at L6 and 7, Obsidian at L8 and 9, Crown at L10. Its parts follow the
## level and their paint the tier; from L6 the drum gives way to a stack of floors, two wide and
## two mid by L9, under a tower of storeys that grows to the crown spire, within 7 units.
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
## The hologram of the base's own planet over the dome (L3+): the globe in a light violet round a
## solid violet core that bobs with it, so it stands off the cyan dome and reads at mid zoom, its
## ring and its projector in core glass.
static var HOLO_GLOBE := Surf.make(MaterialKit.Layer.GLOW, Color("c9a2ff"), 1.0, Surf.HOLO | Surf.BOB, true)
static var HOLO_CORE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.BOB, true)
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

## The Command Center's stepped foundation: the lower step's width and the height of its top, the
## upper step's width, and the deck (the upper step's top, a plinth 0.5 tall) with the tall drum on
## it. The steps stop well inside the pad, so the building, not a platform, fills the lot.
const LOWER_STEP := 3.0
const LOWER_TOP := 0.32
const UPPER_STEP := 2.6
const DECK := 0.82
const DRUM_RADIUS := 1.05
const DRUM_HEIGHT := 1.17
const DOME_RADIUS := 1.0
const DOME_HEIGHT := 0.73
## The dome's radius by level, a share of DOME_RADIUS, so it grows with the tower (1.25 by L7, 1.5
## by L10) and its gold ring with it; its height grows by DOME_RISE of that share.
const DOME_SCALES := [1.0, 1.0, 1.0, 1.0, 1.0, 1.12, 1.25, 1.33, 1.42, 1.5]
const DOME_RISE := 0.6
## How far out on the lower step's ledge, along each axis, its lamps and (from L6) the masts stand.
const LEDGE := 1.4
## The ring of rooms L3 adds round the drum's foot, out to this radius.
const ROOMS_RADIUS := 1.28
const ROOMS_HEIGHT := 0.55
## Where the hangar door faces (degrees around Y from +X towards +Z, as Parts.around): the
## corner nearest the camera. The L2 wings stand on the corners either side of it, the
## drum's pilasters between them.
const DOOR_FACING := 45.0
const WINGS := [135.0, 315.0]
const PILASTERS := [0.0, 90.0, 180.0, 270.0]
## The sensor masts stand on the deck behind the dome (L4 adds one on each wing), MAST_FOOT out,
## and the dish pylon on the lower step's ledge behind the dome's right, so the dish never hides the
## L5 spire and its sweep clears the dome.
const MASTS := [170.0, 280.0]
const MAST_FOOT := 1.18
const DISH_CORNER := 250.0
## The hologram's centre above the dome's apex, its globe's radius, and its ring's tilt.
const HOLO_LIFT := 0.5
const HOLO_RADIUS := 0.38
const HOLO_TILT := Vector3(20, 0, 0)
## The L9 arcs leave the spire this far over the dome's apex and land on the top of its gold ring,
## so they clear the grown dome.
const ARC_FROM := 1.1
## The floors that replace the drum from L6, bottom up: A and B wide, C and D mid, each wider
## than the tower; the level each is added at, its radius and its height. A is the rooms grown,
## C the drum's successor, taller (C_ALONE, its top where the drum's was) until B lifts it at L8.
const FLOOR_LEVELS := [6, 8, 6, 9]
const FLOOR_RADII := [ROOMS_RADIUS, 1.22, 1.14, 1.06]
const FLOOR_HEIGHTS := [ROOMS_HEIGHT, 0.45, 0.45, 0.4]
const C_ALONE := 0.62
## The tower the dome rides from L6, on the floors: its storeys' heights by level from L6, so each
## level keeps its height as the floors grow under it; at L10 the antimatter core's band between
## the floors and them.
const STOREY_RADIUS := 0.98
const TOWER_STOREYS := [[0.7], [0.7, 0.5], [0.5, 0.42], [0.52, 0.5], [0.52, 0.5]]
const CORE_BAND := 0.32
## From L6 the floors would swallow the deck's sensor masts and the dish's pylon: the masts stand
## on the lower step's ledge (LEDGE) instead, and the pylon, a chrome column, on the pad past the
## steps, PYLON_RADIUS out.
const PYLON_RADIUS := 1.75
## The wing the second comms dish (L6) stands on, across the dome from the first dish's pylon,
## and at L10, where it stands still, the way it is aimed (degrees about Y): towards the camera.
const WING_DISH := 135.0
const WING_DISH_AIM := -135.0
## The L10 security bots' round, between the tower's conduits and the dish's pylon, and their
## heights: one low over floor D, one high under the dome, flying opposite ways.
const GUARD_RADIUS := 1.39
const GUARD_LOW := 2.95
const GUARD_HIGH := 3.65
## Where the masts stop at L10 (the deck's second 0.06 higher), under the low bot's round, which
## passes over them.
const MAST_TOP_CROWN := 2.5


## A two-tier stepped foundation, a grey lower step under a cream plinth 0.5 tall (its top gold
## from the Gold tier), well inside the pad, carrying a tall hull-light drum with pilasters and two
## rows of windows, crowned by a core glass dome ringed in gold; a hangar door with hazard stripes
## and a chase of warning lamps facing the camera, two tapered sensor masts with blinking bulbs
## and a spinning comms dish behind. Each level adds to it: L2 two wing modules flanking the drum,
## their screens scrolling, L3 a ring of rooms with scrolling screens round the drum's foot and the
## hologram of the base's planet floating over the dome, a light violet globe round a solid core,
## its ring turning, L4 a glowing antimatter containment ring round the drum, its current flowing,
## and two more masts, L5 gold on the deck's top, the drum's band and the wings' roofs, and a beacon
## spire up to 3.74, the tallest building on the base, its beacon pulsing.
##
## From L6 the drum gives way to floors, stepping in from the base to the tower the dome rides
## (_storey), the dome growing with the tower (DOME_SCALES), the masts moved out to the lower
## step's ledge and the dish's pylon to a chrome column on the pad, carrying the dish up beside
## the dome: L6 the rooms grown into floor A and the drum widened into floor C, the containment
## ring on A's roof round it, a chrome storey with a band of windows and cyan strips, chrome caps
## on the wings, a second dish on a wing (a third moving part) and the landing lamps chasing in
## two rings, up to 4.49; L7 a second storey with a lit observation band, cyan conduits up the
## tower to the dome, three hologram moons turning with the ring and a chrome collar on the spire,
## 5.05; L8 a second wide floor, B, lifting C, obsidian over B, the storeys and the wing caps, one
## violet vein band round each storey under its gold lip, crystal inlays on the wing tips, an
## obsidian ring hovering over the dome's gold ring and the spire grown on an obsidian shaft,
## 5.64; L9 a second mid floor, D, with a lit band, a second containment ring round it, its
## current running the other way, violet arcs from the spire to the dome's gold ring and a station
## orbiting the hologram, 6.48; L10 gold filigree bands round floor B and the storeys in the veins'
## place and on the wing caps' tops, filigree banners on the wings, the antimatter core glowing in a
## glass band at the tower's foot, a crown spire with a hologram beam up to 6.91, the wing dish
## standing still, aimed at the camera, and two security bots circling the tower as its escort,
## one low and one high, opposite ways. Each level keeps its height as the floors grow under the
## tower: its storeys are squeezed (TOWER_STOREYS).
static func build_command_center(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	var chrome := p.tier >= Parts.Tier.CHROME
	Parts.foundation(m, 4)
	m.box_chamfered(Vector3(LOWER_STEP, LOWER_TOP - Parts.PAD_HEIGHT, LOWER_STEP), 0.08, Vector3(0, Parts.PAD_HEIGHT, 0), STEP)
	m.box_chamfered(Vector3(UPPER_STEP, DECK - LOWER_TOP, UPPER_STEP), 0.08, Vector3(0, LOWER_TOP, 0), Parts.HULL_LIGHT)
	if gold:
		# The deck's top in core gold from the Gold tier: gold on a part, lapping over its edge.
		m.box_chamfered(Vector3(UPPER_STEP + 0.02, 0.06, UPPER_STEP + 0.02), 0.03, Vector3(0, DECK - 0.05, 0), Parts.GOLD_TRIM)
	for k: int in 4:
		# Landing lights on the lower step's corners, chasing round it from the Chrome tier.
		Parts.landing_light(m, Parts.around(LEDGE * sqrt(2.0), 45 + 90 * k, LOWER_TOP), 0.09,
			MAST_LAMP.phased(Parts.chase(k, 4)) if chrome else GLOW)
	if level >= 6:
		# A second ring of lamps on the lower step, chasing the other way.
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			var out := LEDGE / maxf(absf(cos(deg_to_rad(degrees))), absf(sin(deg_to_rad(degrees))))
			m.prism(0.06, 0.05, 0.05, 8, Parts.around(out, degrees, LOWER_TOP), MAST_LAMP.phased(Parts.chase(7 - k, 8)),
				Parts.OCTAGON)

	# The drum to L5; from L6 the floors in its place, each roofed up to the next, and on them the
	# tower the dome rides: the core's band at L10, then the storeys. The containment rings ride
	# the drum, or from L6 the floors C and D.
	var dome_base := DECK + DRUM_HEIGHT
	var ring_core := DRUM_RADIUS
	var ring_y := DECK + 1.0
	var upper_core := DRUM_RADIUS
	var upper_y := DECK + 1.1
	if level < 6:
		_drum(m, DRUM_RADIUS, DECK, DRUM_HEIGHT, 0.0, gold)
	else:
		var floors: Array[int] = []
		for i: int in FLOOR_LEVELS.size():
			var from_level: int = FLOOR_LEVELS[i]
			if level >= from_level:
				floors.append(i)
		var y := DECK
		for k: int in floors.size():
			var i := floors[k]
			var radius: float = FLOOR_RADII[i]
			var height: float = C_ALONE if i == 2 and level < 8 else FLOOR_HEIGHTS[i]
			var inner: float = FLOOR_RADII[floors[k + 1]] if k + 1 < floors.size() else STOREY_RADIUS
			match i:
				0:
					_rooms(m, gold, radius, inner)
				2:
					_drum(m, radius, y, height, inner, gold)
					ring_core = radius
					ring_y = y + 0.08
				_:
					_storey(m, y, height, radius, inner, i == 3, level, p.tier)
					if i == 3:
						upper_core = radius
						upper_y = y
			y += height
		dome_base = y
		if level >= 10:
			_core_band(m, dome_base)
			dome_base += CORE_BAND
		var storeys: Array = TOWER_STOREYS[level - 6]
		for k: int in storeys.size():
			var height: float = storeys[k]
			_storey(m, dome_base, height, STOREY_RADIUS, STOREY_RADIUS - 0.08, k == 1, level, p.tier)
			dome_base += height
		if level >= 7:
			# Cyan conduits up the tower from the top floor's roof into the dome's gold ring.
			for degrees: float in PILASTERS:
				Parts.pipe(m, Parts.around(1.09, degrees, y - 0.04), Parts.around(1.09, degrees, dome_base - 0.02),
					0.04, CONDUIT, 8, false)
	var scale: float = DOME_SCALES[level - 1]
	var dome_radius := DOME_RADIUS * scale
	var dome_height := DOME_HEIGHT * (1.0 + DOME_RISE * (scale - 1.0))
	Parts.torus(m, dome_radius + 0.02, 0.08 * scale, 24, 10, Vector3(0, dome_base - 0.06 * scale, 0), Parts.GOLD_ROUND)
	m.dome(dome_radius, dome_height, 16, 7, Vector3(0, dome_base, 0), Parts.GLASS)
	var apex := dome_base + dome_height
	m.prism(0.2, 0.16, 0.08, 16, Vector3(0, apex - 0.03, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)

	_hangar_door(m, gold)
	if level >= 2:
		for degrees: float in WINGS:
			_wing(m, degrees, level, p.tier)
	if level >= 3 and level < 6:
		_rooms(m, gold, ROOMS_RADIUS, DRUM_RADIUS)
	if level >= 4:
		# The antimatter containment ring round the drum's upper half (from L6 round floor C, on the
		# roof below it), clamped to the pilasters, a glowing node on each clamp.
		var ring_radius := ring_core + (0.2 if level < 6 else 0.1)
		Parts.torus(m, ring_radius, 0.1, 24, 6, Vector3(0, ring_y - 0.1, 0), CONTAINMENT)
		for degrees: float in PILASTERS:
			var yaw := Vector3(0, 90.0 - degrees, 0)
			m.box_chamfered(Vector3(0.16, 0.24, 0.3), 0.03, Parts.around(ring_radius - 0.04, degrees, ring_y - 0.12), Parts.HULL_DARK, yaw)
			m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, Parts.around(ring_radius, degrees, ring_y + 0.1),
				CONTAINMENT_NODE.phased(degrees / 360.0), yaw)
	if level >= 9:
		# A second containment ring over the first, round floor D, its current running the other
		# way, clamped between the first's clamps.
		var upper_radius := upper_core + 0.13
		Parts.torus(m, upper_radius, 0.1, 24, 6, Vector3(0, upper_y, 0), CONTAINMENT.phased(0.25))
		for k: int in 4:
			var degrees := 45.0 + 90.0 * k
			var yaw := Vector3(0, 90.0 - degrees, 0)
			m.box_chamfered(Vector3(0.16, 0.22, 0.3), 0.03, Parts.around(upper_radius - 0.04, degrees, upper_y - 0.04), Parts.HULL_DARK, yaw)
			m.box_chamfered(Vector3(0.12, 0.08, 0.12), 0.03, Parts.around(upper_radius, degrees, upper_y + 0.18),
				CONTAINMENT_NODE.phased(degrees / 360.0), yaw)
	if level >= 5:
		_spire(m, apex, level, p.tier)
	if level >= 3:
		_hologram(p, m, apex, level)

	# Two sensor masts (tapered, Parts.tapered_mast) on the deck and the dish's pylon, behind the
	# dome. The masts keep their height as the tower grows, from L6 standing on the lower step's
	# ledge; from L6 the pylon is a single chrome column standing on the pad past the steps,
	# carrying the dish up beside the lifted dome.
	var base_apex := DECK + DRUM_HEIGHT + DOME_HEIGHT
	for k: int in MASTS.size():
		var degrees: float = MASTS[k]
		var lamp := (GOLD_MAST_LAMP if gold else MAST_LAMP).phased(0.5 * k)
		var top := base_apex + 0.1 + 0.12 * k
		if level >= 10:
			top = MAST_TOP_CROWN + 0.06 * k
		var foot := Parts.around(MAST_FOOT, degrees, DECK)
		if level >= 6:
			# On the ledge, LEDGE out along the axis the mast stands nearest.
			var out := LEDGE / maxf(absf(cos(deg_to_rad(degrees))), absf(sin(deg_to_rad(degrees))))
			foot = Parts.around(out, degrees, LOWER_TOP)
		Parts.tapered_mast(m, foot, top - foot.y, Parts.HULL_LIGHT_ROUND, 0.08, lamp)
	var pylon_height := DRUM_HEIGHT + 0.2
	var lift := dome_base - (DECK + DRUM_HEIGHT)
	var pylon := Parts.around(LEDGE / sin(deg_to_rad(DISH_CORNER - 180.0)), DISH_CORNER, DECK)
	if level < 6:
		# On the ledge, its foot on the lower step, its top where the deck's pylon's was.
		var foot := Vector3(pylon.x, LOWER_TOP, pylon.z)
		m.box_chamfered(Vector3(0.2, 0.16, 0.2), 0.05, foot, Parts.HULL_DARK, Vector3(0, 90.0 - DISH_CORNER, 0))
		m.prism(0.1, 0.08, DECK + pylon_height - foot.y, 16, foot + Vector3(0, 0.16, 0), Parts.HULL_MID_ROUND)
	else:
		# A single chamfered chrome column from the pad up to the dish.
		var column := Parts.around(PYLON_RADIUS, DISH_CORNER, Parts.PAD_HEIGHT)
		pylon = Parts.around(PYLON_RADIUS, DISH_CORNER, DECK)
		m.box_chamfered(Vector3(0.2, DECK + 0.16 + pylon_height + lift - column.y, 0.2), 0.05, column, Parts.CHROME,
			Vector3(0, 90.0 - DISH_CORNER, 0))
	_comms_dish(p.moving(pylon + Vector3(0, 0.16 + pylon_height + lift, 0), Motion.spin(Vector3.UP, Parts.DISH_RATE)), gold)
	if level >= 6:
		_wing_dish(p, gold)
	if level >= 8:
		# An obsidian ring hovering over the dome's gold ring, bobbing, veins running across its top
		# and a violet rim glowing round it.
		var hover := Vector3(0, dome_base + 0.14, 0)
		var r := dome_radius
		m.ring(r + 0.16, r + 0.3, 0.05, 24, hover, HOVER_RING)
		m.lathe(PackedVector2Array([Vector2(r + 0.28, 0.052), Vector2(r + 0.18, 0.052)]), 24, hover, HOVER_VEINS)
		m.lathe(PackedVector2Array([Vector2(r + 0.305, 0.008), Vector2(r + 0.305, 0.042)]), 24, hover, HOVER_RIM)
	if level >= 9:
		# Violet arcs crackling from the spire down to the dome's gold ring, which stays still
		# under the bobbing hovering ring.
		for k: int in 4:
			var degrees := 90.0 * k
			Parts.arc(m, Parts.around(0.08, degrees, apex + ARC_FROM), Parts.around(dome_radius + 0.06, degrees, dome_base + 0.18),
				6, 0.06, ARC.phased(k / 4.0))
	if level >= 10:
		Parts.escort_guard(p, GUARD_RADIUS, GUARD_LOW, 0.5)
		Parts.escort_guard(p, GUARD_RADIUS, GUARD_HIGH, -0.4)


## The hangar door facing the camera: a block off the drum with a roll-up door framed in
## hazard stripes, and a hazard-striped apron in the deck's corner before it.
static func _hangar_door(m: LowPolyMesh, gold: bool) -> void:
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var block := Parts.around(1.1, DOOR_FACING, DECK)
	m.box_chamfered(Vector3(0.8, 0.75, 0.7), 0.06, block, Parts.HULL_LIGHT, yaw)
	m.box_chamfered(Vector3(0.86, 0.06, 0.76), 0.03, block + Vector3(0, 0.75, 0), Parts.GOLD_TRIM if gold else Parts.HULL_MID, yaw)
	var front := block + LowPolyMesh.turn(Vector3(0, 0, 0.35), yaw)
	m.box(Vector3(0.52, 0.5, 0.04), front, DOOR, yaw)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.1, 0.56, 0.06), front + LowPolyMesh.turn(Vector3(side * 0.31, 0, 0), yaw), Parts.HAZARD, yaw)
	m.box(Vector3(0.72, 0.08, 0.06), front + Vector3(0, 0.52, 0), Parts.HAZARD, yaw)
	# Four warning lamps over the lintel, chasing across it.
	for k: int in 4:
		m.box(Vector3(0.09, 0.06, 0.05), front + LowPolyMesh.turn(Vector3(-0.24 + 0.16 * k, 0.62, 0.0), yaw),
			DOOR_LAMP.phased(k / 4.0), yaw)
	var corner := UPPER_STEP * 0.5
	m.box(Vector3(0.3, 0.012, 0.3), Vector3(corner - 0.15, DECK + 0.01, corner - 0.15), Parts.HAZARD)


## The hologram over the dome from L3: a projector lens on the apex cap, a globe of the base's
## own planet floating over it, and a ring round the globe, tilted, turning as a moving part,
## both bobbing together. At L5 the beacon spire runs up through the globe as its axis. L7 puts
## three moons on the ring's plane and L9 a station further out, in core gold, turning with it.
static func _hologram(p: Parts, m: LowPolyMesh, apex: float, level: int) -> void:
	m.disc(0.15, 16, Vector3(0, apex + 0.051, 0), PROJECTOR)
	var centre := Vector3(0, apex + HOLO_LIFT, 0)
	m.orb(HOLO_RADIUS, 16, 5, centre, HOLO_GLOBE)
	m.orb(HOLO_RADIUS * 0.45, 12, 5, centre, HOLO_CORE)
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


## The beacon spire from L5: a tapered mast 1.0 above the dome's apex, gold from the Gold tier, a
## collar at its foot (a chunkier chrome one from L7), a pulsing orb clear of the hologram's globe;
## it runs up through the globe as its axis. From L8 it grows on an obsidian shaft whose upper
## half is veins, a gold ring at the joint, its beacon at 5.64 (L8) and 6.48 (L9); at L10 it ends in
## a gold crown of six prongs round a glowing antimatter orb, a hologram beam rising from it.
static func _spire(m: LowPolyMesh, apex: float, level: int, tier: int) -> void:
	var spire := Parts.GOLD_ROUND if tier >= Parts.Tier.GOLD else Parts.HULL_MID_ROUND
	var collar := Parts.CHROME_ROUND if tier >= Parts.Tier.CHROME else spire
	if level < 8:
		m.prism(0.075, 0.03, 0.9, 16, Vector3(0, apex + 0.05, 0), spire)
		if level >= 7:
			Parts.torus(m, 0.1, 0.045, 12, 6, Vector3(0, apex + 0.06, 0), collar)
		else:
			Parts.torus(m, 0.08, 0.03, 12, 6, Vector3(0, apex + 0.1, 0), spire)
		m.orb(0.09, 12, 6, Vector3(0, apex + 0.93, 0), BEACON)
		return
	var top := apex + (1.49 if level == 8 else (1.79 if level == 9 else 1.2))
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
	m.prism(0.08, 0.16, 0.5, 16, Vector3(0, top + 0.25, 0), BEAM)


## The drum, `radius` round and `height` tall on `y` (to L5 on the deck; from L6 floor C): a
## flared skirt, a wall with a gold band and rows of windows (two on the full drum, one on floor
## C) between pilasters, a lip, its roof closed in to `inner` (what stands on it).
static func _drum(m: LowPolyMesh, radius: float, y: float, height: float, inner: float, gold: bool) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius + 0.12, 0), Vector2(radius + 0.05, 0.14), Vector2(radius, 0.17),
		Vector2(radius, height - 0.06), Vector2(radius + 0.05, height - 0.04),
		Vector2(radius + 0.05, height), Vector2(inner, height),
	]), 24, Vector3(0, y, 0), Parts.HULL_LIGHT_ROUND)
	# The full drum's band runs between its rows of windows, 0.12 tall: gold on a part, not a line;
	# floor C's caps its lip.
	var full := height > DRUM_HEIGHT - 0.01
	var band := 0.03 if full else 0.06
	m.lathe(PackedVector2Array([Vector2(radius + band, 0), Vector2(radius + band, 0.12 if full else 0.07)]), 24,
		Vector3(0, y + (0.62 if full else height - 0.05), 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)
	for degrees: float in PILASTERS:
		m.box_chamfered(Vector3(0.2, height - 0.12, 0.16), 0.04, Parts.around(radius + 0.02, degrees, y + 0.06),
			Parts.HULL_MID, Vector3(0, 90.0 - degrees, 0))
	var rows := [0.36, 0.82] if full else [height - 0.27]
	for row: float in rows:
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			m.box(Vector3(0.2, 0.16, 0.04), Parts.around(radius - 0.01, degrees, y + row), WINDOW, Vector3(0, 90.0 - degrees, 0))


## A storey `height` tall on `y`, `radius` round: from L6 each of the tower's under the dome, and
## floors B and D under the tower. A drum of the tier's armour (chrome, obsidian from the Obsidian
## tier) with a flared foot and a gold lip 0.12 tall. To L7 eight cyan light strips run up it,
## between them a band of windows, or a lit observation band where `lit`; from L8 each storey
## carries one accent band round its middle: the lit band where `lit`, else violet veins, gold
## filigree at L10. Its roof runs in from the lip to `inner`, under the dome or what stands on it.
static func _storey(m: LowPolyMesh, y: float, height: float, radius: float, inner: float, lit: bool, level: int,
		tier: int) -> void:
	var r := radius
	m.lathe(PackedVector2Array([Vector2(r + 0.04, 0), Vector2(r, 0.06), Vector2(r, height - 0.14)]), 24, Vector3(0, y, 0),
		_armour(tier, true))
	m.lathe(PackedVector2Array([
		Vector2(r, height - 0.14), Vector2(r + 0.06, height - 0.12), Vector2(r + 0.06, height), Vector2(inner, height),
	]), 24, Vector3(0, y, 0), Parts.GOLD_ROUND if tier >= Parts.Tier.GOLD else Parts.HULL_MID_ROUND)
	var middle := y + (height - 0.08) * 0.5
	if level >= 8:
		var accent := GLOW
		if not lit:
			accent = Parts.FILIGREE if level >= 10 else Parts.VEINS
		m.lathe(PackedVector2Array([Vector2(r + 0.015, 0), Vector2(r + 0.015, 0.16)]), 24, Vector3(0, middle - 0.08, 0), accent)
		return
	for k: int in 8:
		var degrees := 45.0 * k
		m.box(Vector3(0.14, height - 0.26, 0.05), Parts.around(r + 0.005, degrees, y + 0.08), _strip(tier),
			Vector3(0, 90.0 - degrees, 0))
	if lit:
		m.lathe(PackedVector2Array([Vector2(r + 0.015, 0), Vector2(r + 0.015, 0.16)]), 24, Vector3(0, middle - 0.08, 0), GLOW)
	else:
		for k: int in 8:
			var degrees := 22.5 + 45.0 * k
			m.box(Vector3(0.24, 0.2, 0.04), Parts.around(r - 0.01, degrees, middle - 0.1), WINDOW, Vector3(0, 90.0 - degrees, 0))


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


## A wing module flanking the drum: a chamfered block 0.96 long reaching out to the deck's
## corner, its long side to the camera with a row of windows and a vent on its roof; from the
## Gold tier a gold cap on its roof. From L4 a sensor mast (tapered) stands on its far end; from
## L6 an armoured cap clads that end (_wing_cap).
static func _wing(m: LowPolyMesh, degrees: float, level: int, tier: int) -> void:
	var gold := tier >= Parts.Tier.GOLD
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var block := Parts.around(1.1, degrees, DECK)
	m.box_chamfered(Vector3(0.96, 0.8, 0.62), 0.07, block, Parts.HULL_LIGHT, yaw)
	m.box(Vector3(0.74, 0.12, 0.04), block + LowPolyMesh.turn(Vector3(0, 0.46, 0.31), yaw), WINDOW, yaw)
	m.box(Vector3(0.74, 0.06, 0.04), block + LowPolyMesh.turn(Vector3(0, 0.22, 0.31), yaw), SCREENS, yaw)
	var roof := block + Vector3(0, 0.8, 0)
	if gold:
		m.box_chamfered(Vector3(1.0, 0.1, 0.66), 0.03, block + Vector3(0, 0.72, 0), Parts.GOLD_TRIM, yaw)
	m.box_chamfered(Vector3(0.44, 0.08, 0.36), 0.02, roof, ROOF_VENT, yaw)
	if level >= 4:
		var foot := Parts.around(1.45, degrees, roof.y)
		var height := MAST_TOP_CROWN - foot.y if level >= 10 else 1.1
		Parts.tapered_mast(m, foot, height, Parts.HULL_LIGHT_ROUND, 0.07,
			(GOLD_MAST_LAMP if gold else MAST_LAMP).phased(fposmod(0.25 + degrees / 360.0, 1.0)))
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
	var cap := block + LowPolyMesh.turn(Vector3(out * 0.33, 0, 0), yaw)
	m.box_chamfered(Vector3(0.32, 0.9, 0.68), 0.06, cap, _armour(tier, false), yaw)
	var face := cap + LowPolyMesh.turn(Vector3(0, 0, 0.34), yaw)
	m.box(Vector3(0.08, 0.36, 0.04), face + Vector3(0, 0.08, 0), _strip(tier), yaw)
	if level >= 8:
		m.prism(0.13, 0.13, 0.04, 4, face + Vector3(0, 0.6, 0), INLAY, Vector3(90, yaw.y, 0))
		# Three crystal shards growing from the cap's top behind the mast, leaning outward.
		var lean := Parts.facing(LowPolyMesh.turn(Vector3(out * 0.3, 1, 0), yaw))
		for k: int in 3:
			var shard := cap + LowPolyMesh.turn(Vector3(out * (0.04 + 0.08 * k), 0.9, -0.28 + 0.1 * k), yaw)
			m.cone(0.05, 0.22 - 0.05 * absf(k - 1), 8, shard, INLAY.phased(k / 3.0), lean)
	if level >= 10:
		m.box(Vector3(0.34, 0.12, 0.7), cap + Vector3(0, 0.7, 0), Parts.FILIGREE, yaw)
		var pole := cap + LowPolyMesh.turn(Vector3(out * 0.08, 0.9, 0.2), yaw)
		m.prism(Parts.LAMP_POLE_WIDTH * 0.5, Parts.LAMP_POLE_WIDTH * 0.5, 0.75, 8, pole, Parts.LAMP_POLE)
		m.orb(0.045, 8, 4, pole + Vector3(0, 0.77, 0), Parts.GOLD_ROUND)
		var flag := pole + LowPolyMesh.turn(Vector3(-out * 0.15, 0.3, 0), yaw)
		m.box(Vector3(0.26, 0.4, 0.025), flag, Parts.FILIGREE, yaw)
		m.prism(0.07, 0.07, 0.02, 12, flag + LowPolyMesh.turn(Vector3(0, 0.2, 0.0125), yaw), Parts.CORE_GLOW,
			Vector3(90, yaw.y, 0))


## The second comms dish from L6, two thirds the size, on a dish post on the WING_DISH wing's cap
## behind its mast, its turntable at 2.1, under the grown dome's gold ring, turning the other way;
## at L10, where the security bots take the moving parts, built into the body and aimed at the
## camera: its top (about 2.5) stays under the low bot's skirt (2.825 at rest).
static func _wing_dish(p: Parts, gold: bool) -> void:
	var m := p.body
	var yaw := Vector3(0, 90.0 - DOOR_FACING, 0)
	var foot := Parts.around(1.5, WING_DISH, DECK + 0.9) + LowPolyMesh.turn(Vector3(0, 0, -0.22), yaw)
	var turntable := Parts.dish_post(m, foot, 2.1 - foot.y, Parts.CHROME, yaw.y)
	if p.tier >= Parts.Tier.CROWN:
		_comms_dish(m, gold, 0.65, turntable, WING_DISH_AIM)
	else:
		_comms_dish(p.moving(turntable, Motion.spin(Vector3.UP, -0.6)), gold, 0.65)


## The ring of rooms round the drum's foot, `radius` round (from L6 grown into floor A): a low
## round wall with a band of screens and a chamfered roof edge, its roof closed in to `inner`, the
## door and wings (and to L5 the masts and pylon) rising through it.
static func _rooms(m: LowPolyMesh, gold: bool, radius: float, inner: float) -> void:
	m.lathe(PackedVector2Array([
		Vector2(radius, 0), Vector2(radius, ROOMS_HEIGHT - 0.06),
		Vector2(radius - 0.06, ROOMS_HEIGHT), Vector2(inner, ROOMS_HEIGHT),
	]), 24, Vector3(0, DECK, 0), Parts.HULL_LIGHT_ROUND)
	m.lathe(PackedVector2Array([Vector2(radius + 0.01, 0), Vector2(radius + 0.01, 0.18)]), 24,
		Vector3(0, DECK + 0.2, 0), SCREENS)
	m.lathe(PackedVector2Array([Vector2(radius + 0.03, 0), Vector2(radius + 0.03, 0.1)]), 24,
		Vector3(0, DECK + ROOMS_HEIGHT - 0.16, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)


## The comms dish on its turntable, tilted up, with a glowing feed horn; it turns round the pylon.
## `size` scales it (the L6 wing dish's); `at` and `yaw` (degrees) place and aim it when it is
## built into the body (the L10 wing dish's).
static func _comms_dish(s: LowPolyMesh, gold: bool, size: float = 1.0, at: Vector3 = Vector3.ZERO,
		yaw: float = 0.0) -> void:
	var turn := Vector3(0, yaw, 0)
	s.prism(0.16 * size, 0.14 * size, 0.08 * size, 16, at, Parts.HULL_DARK_ROUND)
	s.box_chamfered(Vector3(0.1, 0.22, 0.14) * size, 0.03 * size, at + Vector3(0, 0.06, 0) * size, Parts.HULL_DARK, turn)
	var tilt := Vector3(-35, yaw, 0)
	var bowl := at + LowPolyMesh.turn(Vector3(0, 0.22, 0.04) * size, turn)
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
