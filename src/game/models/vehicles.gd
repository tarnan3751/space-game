extends RefCounted
## The ground machines' models (docs/reference/art-style.md, **Units**): the dune runner, the siege
## walker, the hover tank and the titan, each crewed by colonists seated at the controls
## (UnitModels.pilot, the figures' thin ink) in an open seat or behind a windscreen
## (UnitModels.canopy), the machine on the full ink line. Every wheel, leg, gun arm, turret and
## canopy is a function of its own taking its pivot's transform, so the battle view can later move
## it. The tier repaints the hull, the panels, the trim and the glows (UnitModels.hull, panel, trim,
## glow).

## The army-orange plates: flat and smooth.
static var ORANGE := Parts.surf("orange")
static var ORANGE_ROUND := Figures.ARMY_PLATE
## The dune runner's tyres: dark hull, smooth, so they read as rubber.
static var TYRE := Parts.HULL_DARK_ROUND


# --- The dune runner -------------------------------------------------------------------

## The dune runner: an open four-wheel buggy, a tier-hull chamfered hull on four big dark tyres, an
## orange bonnet and roll cage, a colonist driver at the wheel behind the dash, and a lamp bar of
## the tier's glow on the cage.
static func build_dune_runner(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	m.box_chamfered(Vector3(0.4, 0.15, 0.78), 0.05, Vector3(0, 0.1, 0), UnitModels.hull(tier))
	m.box_chamfered(Vector3(0.34, 0.07, 0.2), 0.03, Vector3(0, 0.25, 0.27), ORANGE)
	m.box_chamfered(Vector3(0.32, 0.06, 0.06), 0.025, Vector3(0, 0.12, 0.41), UnitModels.trim(tier))
	m.box_chamfered(Vector3(0.28, 0.1, 0.15), 0.035, Vector3(0, 0.25, -0.3), Parts.GUNMETAL)
	for z: float in [0.27, -0.27]:
		for side: float in [1.0, -1.0]:
			_wheel(m, UnitModels.pivot(Vector3(side * 0.245, 0.15, z), Vector3(0, 0, -side * 90.0)), 0.15, 0.11, tier)
	m.box_chamfered(Vector3(0.22, 0.2, 0.05), 0.02, Vector3(0, 0.25, -0.19), Parts.HULL_DARK)
	m.box_chamfered(Vector3(0.3, 0.1, 0.1), 0.03, Vector3(0, 0.25, 0.13), UnitModels.panel(tier))
	var driver := UnitModels.pilot(m, Vector3(0, 0.27, -0.05), 0.0, 0.6)
	_steering_wheel(m, (driver.wrists[0].origin + driver.wrists[1].origin) * 0.5 + Vector3(0, -0.01, 0.025))
	_roll_cage(m, tier)


## A wheel on the hub pivot `xf`, its axle along the pivot's +Y (outwards): a chunky dark tyre of
## `radius` and `width`, rounded at its shoulders, and a hub cap of the tier's trim on its outer
## face.
static func _wheel(m: LowPolyMesh, xf: Transform3D, radius: float, width: float, tier: int) -> void:
	var half := width * 0.5
	m.lathe(PackedVector2Array([
		Vector2(radius * 0.45, -half), Vector2(radius * 0.9, -half), Vector2(radius, -half + width * 0.15),
		Vector2(radius, half - width * 0.15), Vector2(radius * 0.9, half), Vector2(radius * 0.45, half),
	]), 12, xf.origin, TYRE, UnitModels.euler(xf))
	m.dome(radius * 0.5, width * 0.28, 10, 2, xf * Vector3(0, half - 0.004, 0), UnitModels.trim(tier, true),
		UnitModels.euler(xf))


## The steering wheel at `centre`, between the driver's hands: a gunmetal hoop tilted towards it.
static func _steering_wheel(m: LowPolyMesh, centre: Vector3) -> void:
	Parts.torus(m, 0.045, 0.012, 12, 4, centre + Vector3(0, -0.01, 0), Parts.GUNMETAL, Vector3(-62, 0, 0))


## The roll cage: an orange hoop over the seat braced back to the tail, and on its top bar a
## gunmetal lamp bar with two lamps of the tier's glow facing forward.
static func _roll_cage(m: LowPolyMesh, tier: int) -> void:
	const R := 0.028
	var top := 0.6
	Parts.pipe_run(m, PackedVector3Array([
		Vector3(0.17, 0.25, -0.2), Vector3(0.15, top, -0.15), Vector3(-0.15, top, -0.15), Vector3(-0.17, 0.25, -0.2),
	]), R, ORANGE_ROUND, 10)
	for side: float in [1.0, -1.0]:
		Parts.pipe(m, Vector3(side * 0.15, top, -0.15), Vector3(side * 0.15, 0.3, -0.36), R, ORANGE_ROUND, 10, false)
	m.box_chamfered(Vector3(0.26, 0.05, 0.06), 0.015, Vector3(0, top + 0.015, -0.15), Parts.GUNMETAL)
	for side: float in [1.0, -1.0]:
		m.disc(0.02, 8, Vector3(side * 0.07, top + 0.04, -0.119), UnitModels.glow(tier, 0, false), Vector3(90, 0, 0))


# --- The siege walker -----------------------------------------------------------------

## The siege walker: an armoured biped, a tier-hull chamfered hull on two thick digitigrade legs with
## orange hip caps, knee joints and broad feet, a gun arm on each side with twin gunmetal barrels,
## a colonist pilot on top behind a glass windscreen, and a short mast with a lamp of the tier's
## glow.
static func build_siege_walker(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	m.box_chamfered(Vector3(0.54, 0.36, 0.56), 0.07, Vector3(0, 0.78, 0), UnitModels.hull(tier))
	m.box_chamfered(Vector3(0.44, 0.13, 0.05), 0.02, Vector3(0, 0.84, 0.27), UnitModels.trim(tier))
	m.box_chamfered(Vector3(0.44, 0.12, 0.18), 0.04, Vector3(0, 1.14, -0.17), Parts.HULL_DARK)
	for side: float in [1.0, -1.0]:
		_walker_leg(m, UnitModels.pivot(Vector3(side * 0.31, 0.86, -0.02)), side, tier)
		_gun_arm(m, UnitModels.pivot(Vector3(side * 0.25, 1.04, 0.04)), side, tier)
	UnitModels.pilot(m, Vector3(0, 1.14, 0.05), 0.0, 0.55)
	UnitModels.canopy(m, UnitModels.pivot(Vector3(0, 1.14, 0.04)), 0.2, 0.02, 46.0, 15.0, 165.0, tier)
	Parts.mast(m, Vector3(-0.16, 1.26, -0.2), 0.2, 0.035, UnitModels.glow(tier, Surf.BLINK))


## A walker leg from the hip pivot `xf` on side `side`: an orange-capped gunmetal hip joint, a
## thigh down and forward to the knee's joint and the knee cap of the tier's trim, a shin down and
## back to the ankle with a piston behind it, and a broad dark foot flat on the ground.
static func _walker_leg(m: LowPolyMesh, xf: Transform3D, side: float, tier: int) -> void:
	var knee := Vector3(side * 0.02, -0.36, 0.2)
	var ankle := Vector3(side * 0.03, -0.72, -0.04)
	m.orb(0.1, 12, 4, xf.origin, Parts.GUNMETAL)
	Parts.drum(m, 0.1, 0.05, 0.02, 16, xf * Vector3(side * 0.05, 0, 0), ORANGE_ROUND,
		UnitModels.euler(xf, Vector3(0, 0, -side * 90.0)))
	Parts.beam(m, xf.origin, xf * knee, 0.15, UnitModels.panel(tier), 0.04)
	m.orb(0.085, 12, 4, xf * knee, Parts.GUNMETAL)
	m.dome(0.07, 0.05, 12, 2, xf * (knee + Vector3(0, 0, 0.05)), UnitModels.trim(tier, true), UnitModels.euler(xf, Vector3(90, 0, 0)))
	Parts.beam(m, xf * knee, xf * ankle, 0.12, UnitModels.hull(tier), 0.035)
	Parts.pipe(m, xf * (knee + Vector3(0, -0.04, -0.08)), xf * (ankle + Vector3(0, 0.06, -0.07)), 0.018, Parts.ROD, 8)
	m.orb(0.06, 10, 3, xf * ankle, Parts.GUNMETAL)
	m.box_chamfered(Vector3(0.22, 0.08, 0.36), 0.035, xf * Vector3(side * 0.03, -xf.origin.y, 0.02), Parts.HULL_DARK,
		UnitModels.euler(xf))


## A gun arm from the shoulder pivot `xf` on side `side`: a gunmetal shoulder drum out of the hull,
## a tier-hull pod with an orange top plate, twin gunmetal barrels forward and their muzzles glowing in
## the tier's glow.
static func _gun_arm(m: LowPolyMesh, xf: Transform3D, side: float, tier: int) -> void:
	Parts.drum(m, 0.075, 0.08, 0.02, 16, xf.origin, Parts.GUNMETAL, UnitModels.euler(xf, Vector3(0, 0, -side * 90.0)))
	var pod := Vector3(side * 0.15, -0.07, 0.06)
	m.box_chamfered(Vector3(0.13, 0.14, 0.34), 0.04, xf * pod, UnitModels.hull(tier), UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.1, 0.03, 0.26), 0.012, xf * (pod + Vector3(0, 0.14, -0.01)), ORANGE, UnitModels.euler(xf))
	for k: float in [-1.0, 1.0]:
		var from := xf * (pod + Vector3(k * 0.034, 0.07, 0.16))
		var to := xf * (pod + Vector3(k * 0.034, 0.07, 0.4))
		Parts.pipe(m, from, to, 0.03, Parts.GUNMETAL, 12)
		m.disc(0.02, 8, to + xf.basis * Vector3(0, 0, 0.002), UnitModels.glow(tier, Surf.PULSE, false),
			UnitModels.euler(xf, Vector3(90, 0, 0)))


# --- The hover tank -----------------------------------------------------------------

## The hover tank: a low tier-hull hull hovering on orange chamfered skirts, their lower edges and the
## underside glowing in the tier's glow (PULSE), two rear thrusters, a turret with one fat plasma
## barrel glowing at the muzzle and a hatch with the pilot's helmet and shoulders showing behind a
## small windscreen; it bobs as it hovers.
static func build_hover_tank(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	var glow := UnitModels.glow(tier, Surf.PULSE)
	m.flags = Surf.BOB
	m.box_chamfered(Vector3(0.6, 0.02, 0.96), 0.008, Vector3(0, 0.17, -0.03), glow)
	m.box_chamfered(Vector3(0.7, 0.22, 1.08), 0.07, Vector3(0, 0.18, -0.03), UnitModels.hull(tier))
	for side: float in [1.0, -1.0]:
		m.box_chamfered(Vector3(0.1, 0.03, 1.1), 0.01, Vector3(side * 0.39, 0.12, -0.03), glow)
		m.box_chamfered(Vector3(0.12, 0.17, 1.16), 0.04, Vector3(side * 0.39, 0.15, -0.03), ORANGE)
		_thruster(m, UnitModels.pivot(Vector3(side * 0.18, 0.29, -0.57), Vector3(-90, 0, 0)), tier)
	_turret(m, UnitModels.pivot(Vector3(0, 0.4, -0.1)), tier)
	m.flags = 0


## A rear thruster on the pivot `xf`, blowing along its +Y: a gunmetal drum and its glowing mouth.
static func _thruster(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	Parts.drum(m, 0.075, 0.07, 0.02, 16, xf * Vector3(0, -0.05, 0), Parts.GUNMETAL, UnitModels.euler(xf))
	m.disc(0.05, 12, xf * Vector3(0, 0.022, 0), UnitModels.glow(tier, Surf.PULSE, false), UnitModels.euler(xf))


## The turret on the pivot `xf` (its ring on the hull): a tier-hull drum on a ring of the tier's trim,
## a gunmetal mantlet, the fat barrel with a muzzle collar of the tier's trim and a glowing bore,
## and the hatch (_hatch).
static func _turret(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.ring(0.25, 0.3, 0.04, 16, xf.origin, UnitModels.trim(tier, true), UnitModels.euler(xf))
	Parts.drum(m, 0.27, 0.17, 0.06, 16, xf.origin, UnitModels.hull(tier, true), UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.2, 0.13, 0.1), 0.03, xf * Vector3(0, 0.025, 0.25), Parts.GUNMETAL, UnitModels.euler(xf))
	var bore := Vector3(0, 0.09, 0.0)
	Parts.pipe(m, xf * (bore + Vector3(0, 0, 0.28)), xf * (bore + Vector3(0, 0, 0.68)), 0.06, Parts.GUNMETAL, 12, false)
	m.tube(0.04, 0.085, 0.1, 16, xf * (bore + Vector3(0, 0, 0.64)), UnitModels.trim(tier, true),
		UnitModels.euler(xf, Vector3(90, 0, 0)))
	m.disc(0.042, 12, xf * (bore + Vector3(0, 0, 0.7)), UnitModels.glow(tier, Surf.PULSE, false),
		UnitModels.euler(xf, Vector3(90, 0, 0)))
	_hatch(m, xf * UnitModels.pivot(Vector3(0.08, 0.17, -0.08)), tier)


## The hatch on the pivot `xf` (the turret's top): a ring of the tier's trim, the pilot seated
## below it so the helmet and shoulders show, and a small windscreen before them.
static func _hatch(m: LowPolyMesh, xf: Transform3D, tier: int) -> void:
	m.ring(0.085, 0.11, 0.03, 16, xf.origin, UnitModels.trim(tier, true), UnitModels.euler(xf))
	UnitModels.pilot(m, xf * Vector3(0, -0.11, 0), 0.0, 0.42)
	UnitModels.canopy(m, xf * UnitModels.pivot(Vector3(0, 0.02, 0)), 0.1, 0.015, 50.0, 30.0, 150.0, tier, 16)


# --- The titan ---------------------------------------------------------------------

## The titan: a giant biped walker, the loudest unit. Massive legs with orange plates, knee joints
## and big feet under a crewed bridge: a tier-hull hull with an orange rear block, two colonists seated
## on seats behind a wide glass windscreen, two huge cannon arms glowing at their muzzles and an antenna mast
## with a blinking lamp.
static func build_titan(p: Parts) -> void:
	var m := p.body
	var tier := p.tier
	Parts.drum(m, 0.3, 0.22, 0.05, 16, Vector3(0, 1.1, 0), Parts.GUNMETAL)
	for side: float in [1.0, -1.0]:
		_titan_leg(m, UnitModels.pivot(Vector3(side * 0.42, 1.2, 0)), side, tier)
	m.box_chamfered(Vector3(1.04, 0.42, 0.86), 0.09, Vector3(0, 1.3, 0), UnitModels.hull(tier))
	m.box_chamfered(Vector3(1.04, 0.32, 0.36), 0.08, Vector3(0, 1.72, -0.25), ORANGE)
	m.box_chamfered(Vector3(0.9, 0.05, 0.3), 0.02, Vector3(0, 2.04, -0.25), UnitModels.trim(tier))
	for side: float in [1.0, -1.0]:
		m.box_chamfered(Vector3(0.16, 0.06, 0.16), 0.025, Vector3(side * 0.2, 1.72, 0.04), Parts.HULL_DARK)
		UnitModels.pilot(m, Vector3(side * 0.2, 1.78, 0.06), 0.0, 0.42)
		_cannon_arm(m, UnitModels.pivot(Vector3(side * 0.5, 1.62, 0.0)), side, tier)
	UnitModels.canopy(m, UnitModels.pivot(Vector3(0, 1.72, -0.14)), 0.54, 0.03, 22.0, 32.0, 148.0, tier)
	Parts.mast(m, Vector3(0.32, 2.09, -0.33), 0.32, 0.05, UnitModels.glow(tier, Surf.BLINK))


## A titan leg from the hip pivot `xf` on side `side`: a gunmetal hip joint, a thigh down to the
## knee with an orange plate on its front, the knee's joint and its cap of the tier's trim, a shin
## with an orange guard, the ankle, and a big dark foot with a toe cap of the tier's trim.
static func _titan_leg(m: LowPolyMesh, xf: Transform3D, side: float, tier: int) -> void:
	var knee := Vector3(side * 0.04, -0.52, 0.14)
	var ankle := Vector3(side * 0.05, -1.02, -0.02)
	m.orb(0.16, 16, 4, xf.origin, Parts.GUNMETAL)
	Parts.beam(m, xf.origin, xf * knee, 0.26, UnitModels.panel(tier), 0.06)
	_leg_plate(m, xf * Vector3(0, -0.06, 0), xf * knee, 0.3, 0.13)
	m.orb(0.15, 16, 4, xf * knee, Parts.GUNMETAL)
	m.dome(0.12, 0.08, 16, 2, xf * (knee + Vector3(0, 0, 0.1)), UnitModels.trim(tier, true), UnitModels.euler(xf, Vector3(90, 0, 0)))
	Parts.beam(m, xf * knee, xf * ankle, 0.24, UnitModels.hull(tier), 0.06)
	_leg_plate(m, xf * (knee + Vector3(0, -0.12, 0)), xf * (ankle + Vector3(0, 0.08, 0)), 0.27, 0.12)
	m.orb(0.1, 12, 4, xf * ankle, Parts.GUNMETAL)
	var foot := Vector3(side * 0.05, -xf.origin.y, 0.06)
	m.box_chamfered(Vector3(0.38, 0.13, 0.6), 0.06, xf * foot, Parts.HULL_DARK, UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.34, 0.08, 0.14), 0.035, xf * (foot + Vector3(0, 0.07, 0.22)), UnitModels.trim(tier),
		UnitModels.euler(xf, Vector3(-14, 0, 0)))


## An orange armour plate along a leg segment from `from` to `to`, `width` across and standing
## `out` in front of the segment's axis.
static func _leg_plate(m: LowPolyMesh, from: Vector3, to: Vector3, width: float, out: float) -> void:
	var along := to - from
	var front := Vector3.RIGHT.cross(along).normalized()
	if front.z < 0.0:
		front = -front
	m.box_chamfered(Vector3(width, along.length(), 0.06), 0.025, from + front * (out - 0.03), ORANGE, Parts.facing(along))


## A cannon arm from the shoulder pivot `xf` on side `side`: a gunmetal shoulder drum, a big tier-hull
## housing with an orange top plate, a fat gunmetal barrel, a muzzle collar of the tier's trim and a
## glowing bore.
static func _cannon_arm(m: LowPolyMesh, xf: Transform3D, side: float, tier: int) -> void:
	Parts.drum(m, 0.14, 0.12, 0.03, 16, xf.origin, Parts.GUNMETAL, UnitModels.euler(xf, Vector3(0, 0, -side * 90.0)))
	var housing := Vector3(side * 0.26, -0.15, 0.0)
	m.box_chamfered(Vector3(0.3, 0.3, 0.64), 0.07, xf * housing, UnitModels.hull(tier), UnitModels.euler(xf))
	m.box_chamfered(Vector3(0.22, 0.05, 0.5), 0.02, xf * (housing + Vector3(0, 0.3, -0.02)), ORANGE, UnitModels.euler(xf))
	var bore := housing + Vector3(0, 0.15, 0)
	Parts.pipe(m, xf * (bore + Vector3(0, 0, 0.3)), xf * (bore + Vector3(0, 0, 0.78)), 0.1, Parts.GUNMETAL, 16, false)
	m.tube(0.065, 0.13, 0.14, 16, xf * (bore + Vector3(0, 0, 0.72)), UnitModels.trim(tier, true),
		UnitModels.euler(xf, Vector3(90, 0, 0)))
	m.disc(0.068, 16, xf * (bore + Vector3(0, 0, 0.8)), UnitModels.glow(tier, Surf.PULSE, false),
		UnitModels.euler(xf, Vector3(90, 0, 0)))
