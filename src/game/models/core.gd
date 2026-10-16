extends RefCounted
## Models of the core: the Command Center, plus the scaffold shown while a building is first
## built and the hull block an unknown type gets (both by footprint size, not level).
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
## The sensor masts' bulbs blink, each on its own phase; the L5 beacon pulses.
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


## A broad two-tier stepped foundation under a tall hull-light drum with pilasters and two
## rows of windows, crowned by a core glass dome ringed in gold; a hangar door with hazard
## stripes and a chase of warning lamps facing the camera, two sensor masts with blinking
## bulbs and a spinning comms dish behind. Each level adds to it: L2 two wing modules flanking
## the drum, their screens scrolling, L3 a ring of rooms with scrolling screens round the
## drum's foot and the hologram of the base's planet floating over the dome, its ring turning,
## L4 a glowing antimatter containment ring round the drum, its current flowing, and two more
## masts, L5 gold trim and a beacon spire up to 3.2, the tallest building on the base, its
## beacon pulsing.
static func build_command_center(p: Parts, level: int) -> void:
	var m := p.body
	var gold := p.tier >= Parts.Tier.GOLD
	Parts.foundation(m, 4)
	m.box_chamfered(Vector3(3.7, 0.2, 3.7), 0.08, Vector3(0, Parts.PAD_HEIGHT, 0), STEP)
	m.box_chamfered(Vector3(3.3, 0.2, 3.3), 0.08, Vector3(0, 0.32, 0), Parts.HULL_MID)
	var trim := Parts.GOLD_TRIM if gold else Parts.HULL_MID
	if level >= 5:
		m.box_chamfered(Vector3(3.76, 0.05, 3.76), 0.03, Vector3(0, 0.24, 0), trim)
		m.box_chamfered(Vector3(3.36, 0.05, 3.36), 0.03, Vector3(0, 0.44, 0), trim)
	for k: int in 4:
		# Landing lights on the deck's corners.
		Parts.landing_light(m, Parts.around(1.46 * sqrt(2.0), 45 + 90 * k, DECK), 0.09, GLOW)

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
	var dome_base := DECK + DRUM_HEIGHT
	Parts.torus(m, DOME_RADIUS + 0.02, 0.08, 24, 10, Vector3(0, dome_base - 0.06, 0), Parts.GOLD_ROUND)
	m.dome(DOME_RADIUS, DOME_HEIGHT, 16, 7, Vector3(0, dome_base, 0), Parts.GLASS)
	var apex := dome_base + DOME_HEIGHT
	m.prism(0.2, 0.16, 0.08, 16, Vector3(0, apex - 0.03, 0), Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND)

	_hangar_door(m, gold)
	if level >= 2:
		for degrees: float in WINGS:
			_wing(m, degrees, level, gold)
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
	if level >= 5:
		# The beacon spire: a tapered mast 0.8 above the dome's apex, gold from the Gold tier, a
		# collar at its foot, a pulsing orb at 3.2; it runs up through the hologram's globe as its
		# axis.
		var spire := Parts.GOLD_ROUND if gold else Parts.HULL_MID_ROUND
		m.prism(0.075, 0.03, 0.66, 16, Vector3(0, apex + 0.05, 0), spire)
		Parts.torus(m, 0.08, 0.03, 12, 6, Vector3(0, apex + 0.1, 0), spire)
		m.orb(0.09, 12, 6, Vector3(0, apex + 0.69, 0), BEACON)
	if level >= 3:
		_hologram(p, m, apex)

	# Two sensor masts on the deck and the dish's pylon, behind the dome.
	for k: int in MASTS.size():
		var degrees: float = MASTS[k]
		var foot := Parts.around(1.47, degrees, DECK)
		m.box_chamfered(Vector3(0.18, 0.14, 0.18), 0.04, foot, Parts.HULL_DARK, Vector3(0, 90.0 - degrees, 0))
		Parts.mast(m, foot + Vector3(0, 0.14, 0), apex - 0.56 + 0.12 * k, 0.08, (GOLD_MAST_LAMP if gold else MAST_LAMP).phased(0.5 * k))
	var pylon := Parts.around(1.5, DISH_CORNER, DECK)
	var pylon_height := DRUM_HEIGHT + 0.2
	m.box_chamfered(Vector3(0.34, 0.16, 0.34), 0.05, pylon, Parts.HULL_DARK, Vector3(0, 45, 0))
	m.prism(0.13, 0.09, pylon_height, 16, pylon + Vector3(0, 0.16, 0), Parts.HULL_MID_ROUND)
	_comms_dish(p.moving(pylon + Vector3(0, 0.16 + pylon_height, 0), Motion.spin(Vector3.UP, 0.8)), gold)


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
## both bobbing together. At L5 the beacon spire runs up through the globe as its axis.
static func _hologram(p: Parts, m: LowPolyMesh, apex: float) -> void:
	m.disc(0.15, 16, Vector3(0, apex + 0.051, 0), PROJECTOR)
	var centre := Vector3(0, apex + HOLO_LIFT, 0)
	m.orb(HOLO_RADIUS, 16, 5, centre, HOLO_GLOBE)
	var ring := p.moving(centre, Motion.spin(Vector3.UP, 0.35))
	ring.lathe(PackedVector2Array([Vector2(HOLO_RADIUS + 0.16, 0), Vector2(HOLO_RADIUS + 0.08, 0)]), 24, Vector3.ZERO,
		HOLO_RING, HOLO_TILT)


## A wing module flanking the drum: a chamfered block 1.2 long, its long side to the camera
## with a row of windows and a vent on its roof. From L4 a sensor mast stands on its far end.
static func _wing(m: LowPolyMesh, degrees: float, level: int, gold: bool) -> void:
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
static func _comms_dish(s: LowPolyMesh, gold: bool) -> void:
	s.prism(0.16, 0.14, 0.08, 16, Vector3.ZERO, Parts.HULL_DARK_ROUND)
	s.box_chamfered(Vector3(0.1, 0.22, 0.14), 0.03, Vector3(0, 0.06, 0), Parts.HULL_DARK)
	var tilt := Vector3(-35, 0, 0)
	var bowl := Vector3(0, 0.22, 0.04)
	Parts.dish(s, 0.46, 0.18, bowl, Parts.GOLD_ROUND if gold else Parts.HULL_LIGHT_ROUND, tilt)
	var axis := LowPolyMesh.turn(Vector3.UP, tilt)
	s.strut(bowl + axis * 0.05, bowl + axis * 0.38, 0.04, Parts.ROD)
	s.orb(0.06, 12, 6, bowl + axis * 0.4, GOLD_GLOW if gold else GLOW)


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
