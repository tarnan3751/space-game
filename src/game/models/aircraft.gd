extends RefCounted
## The air units' models (docs/reference/art-style.md, **Units**): the skimmer, an autonomous hover
## drone, and the gunship and the bomber, each flown by a colonist seated behind a glass windscreen
## (UnitModels.pilot, UnitModels.canopy). Every one flies at its height over its origin and bobs,
## every part of it, its pilot and the gunship's rotors included, on the one phase (LowPolyMesh.flags
## set to Surf.BOB for the build), so nothing comes apart as it bobs. Every rotor, wing, engine and
## canopy is a function of its own taking its pivot's transform. The tier repaints the hull, the
## panels, the trim and the glows (UnitModels.hull, panel, trim, glow).

## How high each flies: its lowest point over the ground, at rest.
const SKIMMER_HOVER := 0.62
const GUNSHIP_HOVER := 1.24
const BOMBER_HOVER := 1.6

## The gunship's rotors: radians a second, counter-rotating, the blades' reach and the glow
## ring's width at their tips.
const ROTOR_RATE := 9.0
const ROTOR_RADIUS := 0.32
const ROTOR_RING := 0.08

static var ORANGE := Parts.surf("orange")
static var ORANGE_ROUND := Figures.ARMY_PLATE
## The rotor blades: dark hull, too thin for an outline.
static var BLADE := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.LIT, false, false)


# --- The skimmer ----------------------------------------------------------------------

## The skimmer's lens: its radius to the rim's outside, and the radius of the trim ring round its
## crown.
const SKIMMER_RADIUS := 0.35
const SKIMMER_DECK := 0.21

## The skimmer: a hover drone that hunts defences, a lens-shaped saucer, its underside the tier's
## hull and its top veined (UnitModels.veined), a rim of the tier's trim and a second trim ring round
## its crown, four glow slots round a glass sensor dome with a dark
## iris and a glowing pupil, a tall orange heading fin behind, two gunmetal gun pods under its front
## rim with glowing tips and a glowing ring under it; hovering and bobbing.
static func build_skimmer(p: Parts) -> void:
	var m := p.body
	m.flags = Surf.BOB
	_saucer(m, UnitModels.pivot(Vector3(0, SKIMMER_HOVER + 0.05, 0)), p.tier)
	m.flags = 0


## The saucer on the pivot `xf` (the lens's underside), facing its +Z.
static func _saucer(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	const R := SKIMMER_RADIUS - 0.005
	var rot := UnitModels.euler(xf)
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.18, 0.016), Vector2(0.29, 0.05), Vector2(R, 0.085),
	]), 24, xf.origin, UnitModels.hull(tier, true), rot)
	m.lathe(PackedVector2Array([
		Vector2(R, 0.085), Vector2(0.3, 0.12), Vector2(SKIMMER_DECK, 0.15),
	]), 24, xf.origin, UnitModels.veined(tier, true), rot)
	m.lathe(PackedVector2Array([
		Vector2(SKIMMER_DECK, 0.15), Vector2(0.12, 0.165), Vector2(0, 0.168),
	]), 24, xf.origin, UnitModels.veined(tier, true), rot)
	m.lathe(PackedVector2Array([Vector2(SKIMMER_RADIUS, 0.068), Vector2(SKIMMER_RADIUS, 0.102)]), 24, xf.origin,
		UnitModels.trim(tier, true), rot)
	m.ring(SKIMMER_DECK - 0.012, SKIMMER_DECK + 0.02, 0.022, 24, xf * Vector3(0, 0.138, 0), UnitModels.trim(tier, true), rot)
	for k: int in 4:
		var degrees := 45.0 + 90.0 * k
		m.box(Vector3(0.1, 0.03, 0.03), xf * Parts.around(0.27, degrees, 0.118), UnitModels.glow(tier, Surf.PULSE, false),
			UnitModels.euler(xf, Vector3(0, -degrees - 90.0, 0)))
	Parts.torus(m, 0.24, 0.03, 20, 4, xf * Vector3(0, -0.05, 0), UnitModels.glow(tier, Surf.PULSE), rot)
	m.box_chamfered(Vector3(0.045, 0.2, 0.26), 0.015, xf * Vector3(0, 0.1, -0.18), ORANGE, UnitModels.euler(xf, Vector3(-18, 0, 0)))
	_dome_eye(m, xf * UnitModels.pivot(Vector3(0, 0.162, -0.01)), tier)
	for side: float in [1.0, -1.0]:
		_gun_pod(m, xf * UnitModels.pivot(Vector3(side * 0.15, -0.012, 0.13)), tier)


## The sensor dome on the pivot `xf` (its foot), looking along its +Z: a glass dome with a dark iris
## on its front and a pupil glowing in the tier's glow.
static func _dome_eye(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.dome(0.14, 0.1, 16, 3, xf.origin, Parts.GLASS, UnitModels.euler(xf))
	var iris := xf * Vector3(0, 0.055, 0.105)
	m.orb(0.052, 12, 4, iris, Figures.VISOR, UnitModels.euler(xf))
	m.orb(0.022, 8, 3, iris + xf.basis * Vector3(0, 0.008, 0.042), UnitModels.glow(tier, Surf.PULSE, false))


## A gun pod on the pivot `xf` (its back, under the lens), firing along its +Z: a stubby gunmetal
## barrel and a tip glowing in the tier's glow.
static func _gun_pod(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	var tip := xf * Vector3(0, 0, 0.15)
	Parts.pipe(m, xf.origin, tip, 0.04, Parts.GUNMETAL, 10, false)
	m.orb(0.03, 10, 3, tip, UnitModels.glow(tier, Surf.PULSE))


# --- The gunship ----------------------------------------------------------------------

## The gunship: a rotor-pod aircraft. A tier-hull chamfered fuselage with a dark belly band and its
## deck plate on the roof (UnitModels.deck), a nose with a colonist pilot sunk behind the glass
## windscreen, a twin chin gun, stub wings of the tier's panels carrying a nacelle at each tip with a
## band of the tier's glow and a cap of the tier's trim, the two rotors spinning on them (parts of
## the body tagged with LowPolyMesh.spin, which the shaders turn), and a tail boom (the hull, the
## trim from Obsidian) with orange fins; hovering and bobbing.
static func build_gunship(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	var bottom := GUNSHIP_HOVER + 0.06
	m.flags = Surf.BOB
	m.box_chamfered(Vector3(0.38, 0.32, 0.72), 0.08, Vector3(0, bottom, -0.02), UnitModels.hull(tier))
	m.box_chamfered(Vector3(0.39, 0.08, 0.73), 0.02, Vector3(0, bottom - 0.002, -0.02), Parts.HULL_DARK)
	UnitModels.deck(m, Vector3(0.22, 0.016, 0.56), Vector3(0, bottom + 0.32, -0.04), tier)
	m.box_chamfered(Vector3(0.3, 0.24, 0.3), 0.07, Vector3(0, bottom, 0.4), UnitModels.hull(tier))
	var boom := UnitModels.trim(tier) if tier >= Parts.Tier.OBSIDIAN else UnitModels.hull(tier)
	Parts.beam(m, Vector3(0, bottom + 0.18, -0.34), Vector3(0, bottom + 0.22, -0.6), 0.12, boom, 0.035)
	m.box_chamfered(Vector3(0.04, 0.22, 0.16), 0.015, Vector3(0, bottom + 0.22, -0.54), ORANGE, Vector3(-12, 0, 0))
	m.box_chamfered(Vector3(0.36, 0.035, 0.12), 0.012, Vector3(0, bottom + 0.2, -0.54), ORANGE)
	m.box_chamfered(Vector3(0.86, 0.06, 0.2), 0.025, Vector3(0, bottom + 0.16, -0.02), UnitModels.panel(tier))
	var seat := UnitModels.seat_under(bottom + 0.24 + UnitModels.canopy_top(0.14, 60.0), 0.4)
	UnitModels.pilot(m, Vector3(0, seat, 0.38), 0.0, 0.4)
	UnitModels.canopy(m, UnitModels.pivot(Vector3(0, bottom + 0.24, 0.39)), 0.14, 0.018, 60.0, 10.0, 170.0, tier, 16)
	_chin_gun(m, UnitModels.pivot(Vector3(0, bottom, 0.45)), tier)
	for side: float in [1.0, -1.0]:
		var hub := Vector3(side * 0.48, bottom + 0.06, -0.02)
		_nacelle(m, UnitModels.pivot(hub), tier)
		var pivot := hub + Vector3(0, 0.34, 0)
		m.spin = Vector4(pivot.x, pivot.y, pivot.z, side * ROTOR_RATE)
		_rotor(m, UnitModels.pivot(pivot), tier)
		m.spin = Vector4.ZERO
	m.flags = 0


## The chin gun on the pivot `xf` under the nose: a gunmetal ball turret and two fat barrels
## forward side by side, glowing at their muzzles.
static func _chin_gun(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.orb(0.075, 12, 4, xf.origin, Parts.GUNMETAL)
	for k: float in [-1.0, 1.0]:
		var muzzle := xf * Vector3(k * 0.044, -0.015, 0.29)
		Parts.pipe(m, xf * Vector3(k * 0.044, -0.015, 0.03), muzzle, 0.04, Parts.GUNMETAL, 10)
		m.disc(0.028, 8, muzzle + xf.basis * Vector3(0, 0, 0.002), UnitModels.glow(tier, Surf.PULSE, false),
			UnitModels.euler(xf, Vector3(90, 0, 0)))


## A nacelle standing on the pivot `xf` at a wing's tip: a tier-hull capsule with a band of the tier's
## glow round it and a cap of the tier's trim, the rotor's hub on its top.
static func _nacelle(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	var rot := UnitModels.euler(xf)
	m.lathe(PackedVector2Array([
		Vector2(0.05, 0.0), Vector2(0.085, 0.05), Vector2(0.085, 0.24), Vector2(0.07, 0.29), Vector2(0, 0.29),
	]), 12, xf.origin, UnitModels.hull(tier, true), rot)
	m.lathe(PackedVector2Array([Vector2(0.088, 0.1), Vector2(0.088, 0.15)]), 12, xf.origin, UnitModels.glow(tier), rot)
	m.ring(0.04, 0.074, 0.03, 12, xf * Vector3(0, 0.275, 0), UnitModels.trim(tier, true), rot)


## A rotor on the pivot `xf` on its nacelle's top: a gunmetal hub sunk in the nacelle under a cap
## of the tier's trim, three dark blades and a thin ring glowing in the tier's glow (PULSE) round
## their tips, so the body shows through the turning rotor.
static func _rotor(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	Parts.drum(m, 0.045, 0.07, 0.02, 12, xf * Vector3(0, -0.05, 0), Parts.GUNMETAL, UnitModels.euler(xf))
	m.dome(0.04, 0.03, 10, 2, xf * Vector3(0, 0.018, 0), UnitModels.trim(tier, true), UnitModels.euler(xf))
	m.ring(ROTOR_RADIUS - ROTOR_RING, ROTOR_RADIUS, 0.012, 24, xf * Vector3(0, 0.004, 0), UnitModels.glow(tier, Surf.PULSE),
		UnitModels.euler(xf))
	for k: int in 3:
		var degrees := 120.0 * k
		m.box(Vector3(ROTOR_RADIUS - 0.04, 0.012, 0.065), xf * Parts.around(ROTOR_RADIUS * 0.5 + 0.01, degrees, 0.008), BLADE,
			UnitModels.euler(xf, Vector3(0, -degrees, 0)))


# --- The bomber ---------------------------------------------------------------------

## The bomber: a broad flying wing, a tier-hull centre body with its deck plate along the top
## (UnitModels.deck), two swept wings edged in the tier's trim with orange winglets, two engines sunk
## in the wing roots with intake rings of the tier's trim and glowing tails, its bombs on show: two
## in the bay under the body, one under each wing outboard of its engine and one on a pylon under
## each wingtip; the pilot sunk behind a small windscreen; hovering and bobbing.
static func build_bomber(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	var bottom := BOMBER_HOVER + 0.15
	m.flags = Surf.BOB
	m.box_chamfered(Vector3(0.44, 0.2, 0.92), 0.07, Vector3(0, bottom, -0.02), UnitModels.hull(tier))
	UnitModels.deck(m, Vector3(0.26, 0.014, 0.72), Vector3(0, bottom + 0.2, -0.08), tier)
	for side: float in [1.0, -1.0]:
		var root := UnitModels.pivot(Vector3(side * 0.2, bottom + 0.02, 0.08), Vector3(0, side * 34.0, 0))
		_wing(m, root, side, tier)
		_engine(m, UnitModels.pivot(Vector3(side * 0.3, bottom + 0.125, 0.12), Vector3(-90, 0, 0)), tier)
		for out: float in [0.3, 0.6]:
			_bomb(m, root * Vector3(side * out, -0.004, 0.1), 0.03 if out < 0.5 else 0.06)
	_bomb_bay(m, UnitModels.pivot(Vector3(0, bottom, -0.02)))
	var seat := UnitModels.seat_under(bottom + 0.2 + UnitModels.canopy_top(0.14, 60.0), 0.44)
	UnitModels.pilot(m, Vector3(0, seat, 0.25), 0.0, 0.44)
	UnitModels.canopy(m, UnitModels.pivot(Vector3(0, bottom + 0.2, 0.26)), 0.14, 0.016, 60.0, 10.0, 170.0, tier, 16)
	m.flags = 0


## A wing from the root pivot `xf` out along its X to side `side` (the pivot swept back): a tier-hull
## panel, a leading edge of the tier's trim and an orange winglet at the tip.
static func _wing(m: LowPolyMesh, xf: Transform3D, side: float, tier: int) -> void:
	var rot := UnitModels.euler(xf)
	m.box_chamfered(Vector3(0.74, 0.07, 0.42), 0.03, xf * Vector3(side * 0.37, 0, 0), UnitModels.veined(tier), rot)
	m.box_chamfered(Vector3(0.7, 0.045, 0.06), 0.015, xf * Vector3(side * 0.37, 0.03, 0.2), UnitModels.trim(tier), rot)
	m.box_chamfered(Vector3(0.04, 0.16, 0.24), 0.015, xf * Vector3(side * 0.72, 0.05, -0.03), ORANGE, rot)


## An engine on the pivot `xf`, its thrust along the pivot's +Y (backwards), sunk in the wing: a
## tier-hull nacelle with a dark intake in a ring of the tier's trim and a glowing exhaust, a short
## flame cone out of it.
static func _engine(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	var rot := UnitModels.euler(xf)
	m.lathe(PackedVector2Array([
		Vector2(0.065, 0.0), Vector2(0.085, 0.05), Vector2(0.085, 0.38), Vector2(0.072, 0.44),
	]), 16, xf.origin, UnitModels.hull(tier, true), rot)
	m.tube(0.06, 0.094, 0.05, 16, xf * Vector3(0, -0.02, 0), UnitModels.trim(tier, true), rot)
	m.disc(0.064, 16, xf * Vector3(0, 0.004, 0), Parts.HULL_DARK, UnitModels.euler(xf, Vector3(180, 0, 0)))
	var glow := UnitModels.glow(tier, Surf.PULSE, false)
	m.disc(0.072, 16, xf * Vector3(0, 0.435, 0), glow, rot)
	m.cone(0.055, 0.12, 12, xf * Vector3(0, 0.435, 0), glow, rot)


## The bomb bay on the pivot `xf` (the body's underside): a gunmetal rack across the body and two
## fat orange bombs slung under it (_bomb), nose forward.
static func _bomb_bay(m: LowPolyMesh, xf: Transform3D) -> void:
	m.box_chamfered(Vector3(0.4, 0.05, 0.2), 0.02, xf * Vector3(0, -0.05, 0.1), Parts.GUNMETAL, UnitModels.euler(xf))
	for x: float in [-0.11, 0.11]:
		_bomb(m, xf * Vector3(x, -0.05, 0.08), 0.0)


## A fat orange bomb slung `drop` under `hang`, the middle of its top, on a gunmetal pylon, nose
## forward (+Z).
static func _bomb(m: LowPolyMesh, hang: Vector3, drop: float) -> void:
	if drop > 0.0:
		m.box_chamfered(Vector3(0.03, drop + 0.01, 0.1), 0.008, hang - Vector3(0, drop, 0), Parts.GUNMETAL)
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.034, 0.03), Vector2(0.046, 0.08), Vector2(0.046, 0.17), Vector2(0.03, 0.23), Vector2(0, 0.24),
	]), 8, hang - Vector3(0, drop + 0.046, 0.12), ORANGE_ROUND, Vector3(90, 0, 0))
