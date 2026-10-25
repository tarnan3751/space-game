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

## The gunship's rotors: radians a second, counter-rotating, and the blur's radius.
const ROTOR_RATE := 9.0
const ROTOR_RADIUS := 0.32

static var ORANGE := Parts.surf("orange")
static var ORANGE_ROUND := Figures.ARMY_PLATE
## The rotor blur: the screen layer's segments in ENERGY, unlit, as the escort drone's rotors, but
## still and at phase 0, so it bobs with the body; the spin turns it.
static var ROTOR_BLUR := Surf.make(MaterialKit.Layer.SCREEN, MaterialKit.ENERGY, 4.0, Surf.UNLIT)
## The rotor blades: dark hull, too thin for an outline.
static var BLADE := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.LIT, false, false)


# --- The skimmer ----------------------------------------------------------------------

## The skimmer: a small hover drone, a lens-shaped tier-hull saucer with a rim of the tier's trim, a
## glass sensor dome, an orange dive fin, one glowing eye in front and a glowing ring under it,
## hovering and bobbing.
static func build_skimmer(p: Parts) -> void:
	var m := p.body
	m.flags = Surf.BOB
	_saucer(m, UnitModels.pivot(Vector3(0, SKIMMER_HOVER + 0.04, 0)), p.tier)
	m.flags = 0


## The saucer on the pivot `xf` (the lens's underside), facing its +Z.
static func _saucer(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	var rot := UnitModels.euler(xf)
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.16, 0.015), Vector2(0.27, 0.05), Vector2(0.3, 0.075), Vector2(0.27, 0.1),
		Vector2(0.16, 0.135), Vector2(0, 0.15),
	]), 20, xf.origin, UnitModels.veined(tier, true), rot)
	m.lathe(PackedVector2Array([Vector2(0.304, 0.058), Vector2(0.304, 0.092)]), 20, xf.origin, UnitModels.trim(tier, true), rot)
	Parts.torus(m, 0.19, 0.022, 16, 4, xf * Vector3(0, -0.04, 0), UnitModels.glow(tier, Surf.PULSE), rot)
	m.dome(0.1, 0.07, 16, 3, xf * Vector3(0, 0.142, -0.02), Parts.GLASS, rot)
	m.box_chamfered(Vector3(0.035, 0.13, 0.18), 0.012, xf * Vector3(0, 0.1, -0.15), ORANGE, UnitModels.euler(xf, Vector3(-18, 0, 0)))
	_eye(m, xf * UnitModels.pivot(Vector3(0, 0.075, 0.27), Vector3(90, 0, 0)), tier)


## The eye on the pivot `xf`, looking along its +Y: a gunmetal socket and a glowing lens.
static func _eye(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	Parts.drum(m, 0.06, 0.05, 0.015, 12, xf.origin, Parts.GUNMETAL, UnitModels.euler(xf))
	m.orb(0.042, 10, 4, xf * Vector3(0, 0.05, 0), UnitModels.glow(tier, Surf.PULSE))


# --- The gunship ----------------------------------------------------------------------

## The gunship: a rotor-pod aircraft. A tier-hull chamfered fuselage and nose, a colonist pilot sunk
## behind the glass windscreen on the nose, a chin gun, stub wings carrying a nacelle at each tip with a
## band of the tier's glow, the two rotors spinning on them (parts of the body tagged with
## LowPolyMesh.spin, which the shaders turn), and a tail boom with orange fins; hovering and bobbing.
static func build_gunship(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	var bottom := GUNSHIP_HOVER + 0.06
	m.flags = Surf.BOB
	m.box_chamfered(Vector3(0.38, 0.32, 0.72), 0.08, Vector3(0, bottom, -0.02), UnitModels.hull(tier))
	m.box_chamfered(Vector3(0.3, 0.24, 0.3), 0.07, Vector3(0, bottom, 0.4), UnitModels.hull(tier))
	Parts.beam(m, Vector3(0, bottom + 0.18, -0.34), Vector3(0, bottom + 0.22, -0.6), 0.12, UnitModels.hull(tier), 0.035)
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
		_rotor(m, UnitModels.pivot(pivot))
		m.spin = Vector4.ZERO
	m.flags = 0


## The chin gun on the pivot `xf` under the nose: a gunmetal ball turret and one barrel forward,
## glowing at its muzzle.
static func _chin_gun(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.orb(0.065, 12, 4, xf.origin, Parts.GUNMETAL)
	var muzzle := xf * Vector3(0, -0.01, 0.17)
	Parts.pipe(m, xf * Vector3(0, -0.01, 0.03), muzzle, 0.03, Parts.GUNMETAL, 10)
	m.disc(0.018, 8, muzzle + xf.basis * Vector3(0, 0, 0.002), UnitModels.glow(tier, Surf.PULSE, false),
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


## A rotor on the pivot `xf` on its nacelle's top: a gunmetal hub sunk in the nacelle, the blur disc
## of ROTOR_RADIUS just above it and three dark blades over the blur.
static func _rotor(m: LowPolyMesh, xf: Transform3D) -> void:
	Parts.drum(m, 0.045, 0.07, 0.02, 12, xf * Vector3(0, -0.05, 0), Parts.GUNMETAL, UnitModels.euler(xf))
	m.disc(ROTOR_RADIUS, 16, xf * Vector3(0, 0.006, 0), ROTOR_BLUR, UnitModels.euler(xf))
	for k: int in 3:
		var degrees := 120.0 * k
		m.box(Vector3(ROTOR_RADIUS - 0.04, 0.012, 0.045), xf * Parts.around(ROTOR_RADIUS * 0.5 + 0.01, degrees, 0.008), BLADE,
			UnitModels.euler(xf, Vector3(0, -degrees, 0)))


# --- The bomber ---------------------------------------------------------------------

## The bomber: a broad flying wing, a tier-hull centre body with two swept wings edged in the tier's
## trim and orange winglets, two engines on the wing roots glowing at their tails, a bomb bay with
## a row of orange bombs underneath and the pilot sunk behind a small windscreen; hovering and bobbing.
static func build_bomber(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	var bottom := BOMBER_HOVER + 0.15
	m.flags = Surf.BOB
	m.box_chamfered(Vector3(0.44, 0.2, 0.92), 0.07, Vector3(0, bottom, -0.02), UnitModels.hull(tier))
	for side: float in [1.0, -1.0]:
		_wing(m, UnitModels.pivot(Vector3(side * 0.2, bottom + 0.02, 0.08), Vector3(0, side * 34.0, 0)), side, tier)
		_engine(m, UnitModels.pivot(Vector3(side * 0.3, bottom + 0.16, 0.12), Vector3(-90, 0, 0)), tier)
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


## An engine on the pivot `xf`, its thrust along the pivot's +Y (backwards): a tier-hull nacelle with a
## dark intake and a glowing exhaust, a short flame cone out of it.
static func _engine(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	var rot := UnitModels.euler(xf)
	m.lathe(PackedVector2Array([
		Vector2(0.075, 0.0), Vector2(0.1, 0.06), Vector2(0.1, 0.4), Vector2(0.085, 0.46),
	]), 16, xf.origin, UnitModels.hull(tier, true), rot)
	m.disc(0.078, 16, xf * Vector3(0, 0.01, 0), Parts.HULL_DARK, UnitModels.euler(xf, Vector3(180, 0, 0)))
	var glow := UnitModels.glow(tier, Surf.PULSE, false)
	m.disc(0.085, 16, xf * Vector3(0, 0.455, 0), glow, rot)
	m.cone(0.06, 0.12, 12, xf * Vector3(0, 0.455, 0), glow, rot)


## The bomb bay on the pivot `xf` (the body's underside): a gunmetal rack across the body and the
## wing roots, wider than the body, and a row of four fat orange bombs slung under it, nose forward,
## the outer two under the wings, so the row shows past the body.
static func _bomb_bay(m: LowPolyMesh, xf: Transform3D) -> void:
	m.box_chamfered(Vector3(0.78, 0.05, 0.2), 0.02, xf * Vector3(0, -0.05, 0.1), Parts.GUNMETAL, UnitModels.euler(xf))
	for x: float in [-0.33, -0.11, 0.11, 0.33]:
		m.lathe(PackedVector2Array([
			Vector2(0, 0), Vector2(0.034, 0.03), Vector2(0.046, 0.08), Vector2(0.046, 0.17), Vector2(0.03, 0.23), Vector2(0, 0.24),
		]), 8, xf * Vector3(x, -0.096, -0.02), ORANGE_ROUND, UnitModels.euler(xf, Vector3(90, 0, 0)))
