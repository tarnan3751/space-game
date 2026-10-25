extends RefCounted
## Models of the defences (docs/reference/art-style.md). Every defence stands on the family's
## squat armoured plinth, an octagon of gunmetal plate on its concrete pad whose upper third, its
## deck, is plated in defence red, and glows in its weapon's own colour: laser red, plasma violet, arc electric blue, ion
## and railgun cyan, EMP yellow. Levels add barrels, armour, coils or capacitors to the same
## weapon; the Gold tier (Parts.tier) adds gold trim. The laser turret, the missile battery, the
## plasma mortar, the flak cannon, the shield generator, the arc tower, the cloaked sentry, the
## gravity well, the EMP tower, the railgun, the ion beam and the orbital cannon go on to their
## tops through the high tiers: chrome with cyan strips, then obsidian with glowing violet vein
## panels on the faces the camera sees and a hovering ring, then gold filigree, the antimatter
## core and a crown; the plinth keeps its octagon and its red deck over the tier's chrome or
## obsidian plate (the cloaked sentry, which has no plinth, rises on a hex skirt banded in
## red). Where the core is the weapon's heart (the shield's orb, the arc tower's sphere, the well's
## core, the EMP's emitter, the railgun's and the orbital cannon's breech, the ion beam's lens) it
## glows steady and light violet at the Crown (BRIGHT_CORE).
##
## They animate (docs/reference/art-style.md, **Animation**): heads scan and barrels recoil as
## moving parts, emitters pulse, lamps blink in chases, currents flow along conduits, and arcs
## crackle where a weapon holds its charge (Parts.arc).
##
## BuildingModels calls one static build_<type>(p: Parts, level: int) per type. A part's
## heading is a yaw in degrees from +Z towards +X: the camera looks from the +X+Z corner, so
## yaw 45 faces the viewer and SCREEN_RIGHT runs across the screen, where a barrel shows its
## whole length. Parts.around() angles run the other way, from +X towards +Z.

## The yaw that runs a part to the right of the screen.
const SCREEN_RIGHT := 135.0

static var SHELL := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_LIGHT, 1.0, Surf.LIT, true)
static var SHELL_MID := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_MID, 1.0, Surf.LIT, true)
static var SHELL_DARK := Surf.make(MaterialKit.Layer.HULL, MaterialKit.HULL_DARK, 1.0, Surf.LIT, true)
static var DENSE := Surf.make(MaterialKit.Layer.HULL_DENSE, MaterialKit.HULL_MID)
static var VENT := Surf.make(MaterialKit.Layer.VENT, MaterialKit.HULL_DARK)
static var POD := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var ARMOUR := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE)
static var ARMOUR_ROUND := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, 1.0, Surf.LIT, true)
static var BARREL := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.GUNMETAL, 1.0, Surf.LIT, true)
static var RIBBED := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0, Surf.LIT, true)
static var RIBBED_LIGHT := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_LIGHT, 2.0, Surf.LIT, true)
static var HAZARD_FINE := Surf.make(MaterialKit.Layer.HAZARD, Color.WHITE, 3.0)
static var GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY, true)
## The gravity well's dark core: glossy, so it catches a hard highlight; violet, floating and
## swelling.
static var CORE := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.ANTIMATTER.darkened(0.55), 1.0,
	Surf.GLOSSY | Surf.PULSE | Surf.BOB, true)
static var LASER := _glow(MaterialKit.DEFENCE)
static var PLASMA := _glow(MaterialKit.ANTIMATTER)
static var ION := _glow(MaterialKit.ENERGY)
## The cloaked sentry's shimmer: a hologram, phasing.
static var SHIMMER := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO)
## The laser turret's red deck, its plates creeping round it.
static var BELT := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.DEFENCE, 1.0, Surf.FLOW_U, false, true, 0.6)
static var LASER_PULSE := _glow(MaterialKit.DEFENCE, Surf.PULSE)
static var LASER_BLINK := _glow(MaterialKit.DEFENCE, Surf.BLINK)
static var PLASMA_PULSE := _glow(MaterialKit.ANTIMATTER, Surf.PULSE)
## Bubbles surfacing on the plasma chamber: a paler violet, swelling, so they stay lighter than
## the chamber.
static var BUBBLE := _glow(MaterialKit.ANTIMATTER.lightened(0.75), Surf.PULSE)
## The plasma's swirl: a violet-pink hologram shell round the chamber, its crystal blotches
## crawling slowly round it.
static var PLASMA_SWIRL := Surf.make(MaterialKit.Layer.CRYSTAL, Color("e05cff"), 1.5, Surf.HOLO | Surf.FLOW_U, true, true,
	0.58)
## Tongues of plasma licking out of the chamber: the core's glow lifted paler, swelling, and soft,
## with no ink line round them.
static var PLASMA_TONGUE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER.lightened(0.6), 1.0,
	Surf.UNLIT | Surf.PULSE, true, false)
## The mortar's bore lining, its bands running out of the muzzle.
static var BORE := Parts.current(MaterialKit.ANTIMATTER, 0.3)
## The shield generator's orb, floating and swelling.
static var ION_ORB := _glow(MaterialKit.ENERGY, Surf.PULSE | Surf.BOB)
## Current running along a conduit towards where its pipe ends (Parts.pipe's `to`).
static var ION_CURRENT := Parts.current(MaterialKit.ENERGY, 0.8)
static var ION_ARC := Parts.spark(MaterialKit.ENERGY)
static var ION_HOLO := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.HOLO)
## A muzzle's flash: a yellow flare, there and gone.
static var FLARE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.HAZARD, 1.0, Surf.UNLIT | Surf.FLICKER)
static var ARC_PULSE := _glow(MaterialKit.ARC_BLUE, Surf.PULSE)
static var ARC_BLINK := _glow(MaterialKit.ARC_BLUE, Surf.BLINK)
static var ARC_SPARK := Parts.spark(MaterialKit.ARC_BLUE.lightened(0.35))
## The tesla coil's core, its current climbing between the skirts.
static var ARC_CURRENT := Parts.current(MaterialKit.ARC_BLUE, 0.8)
## The gravity well's swirl: crystal facets, which vary along U, turning round the disc and
## drawn in towards its middle.
static var SWIRL := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ANTIMATTER, 1.0,
	Surf.UNLIT | Surf.FLOW | Surf.FLOW_U, false, true, 0.62)
static var PLASMA_BLINK := _glow(MaterialKit.ANTIMATTER, Surf.BLINK)
static var EMP_CORE := _glow(MaterialKit.HAZARD, Surf.PULSE | Surf.BOB)
static var EMP_BLINK := _glow(MaterialKit.HAZARD, Surf.BLINK)
static var EMP_ARC := Parts.spark(MaterialKit.HAZARD.lightened(0.3))
static var ION_PULSE := _glow(MaterialKit.ENERGY, Surf.PULSE)
static var ION_BLINK := _glow(MaterialKit.ENERGY, Surf.BLINK)
## The railgun's strip, its current racing to the muzzle.
static var RAIL_CURRENT := Parts.current(MaterialKit.ENERGY, 0.95)
## The ion beam's tripod conduits: a dimmer current, so the tripod still reads dark.
static var CONDUIT := Parts.current(MaterialKit.ENERGY.darkened(0.35), 0.8)
## The orbital cannon's bore, its bands rippling out.
static var BORE_ION := Parts.current(MaterialKit.ENERGY, 0.3)
static var LENS_PULSE := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ENERGY, 2.0, Surf.GLOSSY | Surf.PULSE, true)
## The high tiers' own (docs/reference/art-style.md, **Tiers**): from the Obsidian tier glowing
## violet vein panels on the faces the camera sees (the walls' and the siphon's violet field: the
## glow layer's stripes a third as fine, lifted by FLOW), crystal inlays, and the violet focusing
## crystals and shell tips; a hovering ring's obsidian, veins, violet rim, red sights and, at the
## Crown, gold rim, bobbing together (their one phase is also the veins' FLOW speed and the
## glows' PULSE offset).
static var VEIN_PANEL := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0 / 3.0, Surf.UNLIT | Surf.FLOW, false, true,
	0.45)
static var INLAY := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.PULSE)
static var FOCUS := Surf.make(MaterialKit.Layer.CRYSTAL, Parts.CORE_GLOW_TINT.lightened(0.3), 1.0, Surf.UNLIT | Surf.PULSE)
static var HOVER := Surf.make(MaterialKit.Layer.OBSIDIAN, Parts.OBSIDIAN_TINT, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
static var HOVER_VEINS := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW | Surf.BOB, true, true,
	0.7)
static var HOVER_RIM := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var HOVER_SIGHT := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.DEFENCE, 1.0, Surf.UNLIT | Surf.PULSE | Surf.BOB, true, true,
	0.7)
static var HOVER_GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true, true, 0.7)
## Lamps blinking violet, and missiles tipped with violet crystals blinking in their chase.
static var CORE_BLINK := _glow(Parts.CORE_GLOW_TINT, Surf.BLINK)
static var CRYSTAL_BLINK := Surf.make(MaterialKit.Layer.CRYSTAL, Parts.CORE_GLOW_TINT.lightened(0.3), 1.0, Surf.UNLIT | Surf.BLINK, true)
## Current running violet along an ammo belt.
static var VIOLET_CURRENT := Parts.current(Parts.CORE_GLOW_TINT, 0.8)
## The Crown's antimatter core where it is a weapon's heart (the shield's orb, the arc tower's
## sphere, the gravity well's core, the EMP's emitter, the sentry's eye): a light violet, unlit
## and steady, so it is the brightest thing on the model where CORE_GLOW's pulse would dim it (as
## the collectors' BRIGHT_CORE in resources.gd); BRIGHT_FLOAT floats as the core it replaces did.
## The Obsidian tier's crystal orb, glowing steady in the crystal inlays' pink (a pulse dims a
## sphere this big to a dull mauve), floating, and the gravity well's, held still in its gyro rings; violet arcs and holograms; the Crown's gold halo,
## floating with the orb under it; chrome and obsidian capacitor cans.
const CORE_LIGHT := Color("c9a2ff")
static var BRIGHT_CORE := Surf.make(MaterialKit.Layer.GLOW, CORE_LIGHT, 1.0, Surf.UNLIT, true)
static var BRIGHT_FLOAT := Surf.make(MaterialKit.Layer.GLOW, CORE_LIGHT, 1.0, Surf.UNLIT | Surf.BOB, true)
static var CRYSTAL_ORB := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT | Surf.BOB, true)
static var CRYSTAL_CORE := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.CRYSTAL, 1.0, Surf.UNLIT, true)
static var VIOLET_ARC := Parts.spark(Parts.CORE_GLOW_TINT.lightened(0.35))
static var VIOLET_HOLO := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, 1.0, Surf.HOLO)
static var HALO_GOLD := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.CORE_GOLD, 1.0, Surf.GLOSSY | Surf.BOB, true)
static var CHROME_RIBBED := Surf.make(MaterialKit.Layer.PIPE, Parts.CHROME_TINT, 2.0, Surf.GLOSSY, true)
static var OBSIDIAN_RIBBED := Surf.make(MaterialKit.Layer.PIPE, Parts.OBSIDIAN_TINT, 2.0, Surf.GLOSSY, true)
## The ion beam's lens from L3: cyan crystal glowing unlit, swelling.
static var ION_LENS := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.ENERGY, 2.0, Surf.UNLIT | Surf.PULSE, true)
## The orbital cannon's spire lens from the Obsidian tier: the light violet of the Crown's cores,
## swelling, so it stays the brightest thing on the spire.
static var LENS_VIOLET := _glow(CORE_LIGHT, Surf.PULSE)

## The horizontal direction towards the camera (IsoCamera's yaw): vein panels go on the faces
## turned to it.
const TOWARD_CAMERA := Vector3(0.70710678, 0, 0.70710678)
## The armoured octagon plinth's faces the camera sees, by the Parts.around() angle of each face's
## normal: the vein panels' and the filigree's places.
const PLINTH_FACES := [0.0, 45.0, 90.0]
## The Crown's filigree band round a plinth's foot: tall enough for its pattern to read.
const PLINTH_FILIGREE := 0.1

## The laser turret to L5: its dome's radius and height, its barrels' radius and length, and
## their red emitter caps' radius.
const LASER_DOME := Vector2(0.68, 0.36)
const LASER_BORE := 0.09
const LASER_LENGTH := 0.8
const LASER_CAP := 0.14
## The laser turret from L6, by level from L6: the plinth's height, and how far the mount lifts
## the head above the turret ring.
const LASER_PLINTHS := [0.5, 0.5, 0.58, 0.58, 0.64]
const LASER_LIFTS := [0.3, 0.54, 0.62, 0.72, 0.86]
## The L9 targeting ring's height over the dome's top.
const LASER_RING_LIFT := 0.45
## The missile battery from L6: its tubes' spacing, half the slot between its pods where the radar
## mast stands, the trunnion's height over the deck, and by level from L6 the dish's height over
## the trunnion.
const MISSILE_SPACING := 0.3
const MISSILE_SLOT := 0.12
const MISSILE_TRUNNION := 0.8
const MISSILE_DISH_LIFTS := [1.0, 1.35, 1.35, 1.55, 1.9]
## The plasma mortar from L5, by level from L5: the plinth's height and the pedestal's lifting the
## bowl; the L6 loader arm's distance out on the near corner; the wider plinth from L7.
const MORTAR_PLINTHS := [0.34, 0.34, 0.52, 0.56]
const MORTAR_RISES := [0.2, 0.3, 0.45, 0.55]
const MORTAR_LOADER := 1.45
const MORTAR_WIDE := 1.38
## From L5 the bowl's outer wall is this much wider; the L6 loader's canister hangs this far over
## the bowl's rim (its seat), more at the Crown, over the crown's spikes.
const MORTAR_BOWL := 1.1
const MORTAR_LOADER_CLEAR := 0.4
## The L7 charge ring: how far past the muzzle's lip it hovers, and its radii.
const MORTAR_CHARGE_OFF := 0.38
const MORTAR_CHARGE_INNER := 0.52
const MORTAR_CHARGE_OUTER := 0.68
## The L8 ammunition rack on the near corner: an octagonal pedestal level with the plinth's top,
## where the loader arm stands, its distance out and its radius; the plasma canisters racked
## beside the arm on the camera's side, their distance from the arm, radius and height.
const MORTAR_BALCONY := 1.5
const MORTAR_BALCONY_RADIUS := 0.56
const MORTAR_RACK := 0.34
const MORTAR_CANISTER := 0.13
const MORTAR_CANISTER_HEIGHT := 0.52
## The flak cannon: the bell mount's height under the head before the 0.12 a level it grows, how
## much higher than the head's top its radar stands, and to L6 its fat barrels' radius and their
## muzzle brakes'.
const FLAK_RISE := 0.65
const FLAK_RADAR_RAISE := 0.25
const FLAK_BORE := 0.11
const FLAK_BRAKE := 0.16
## From L7 the height between the two rows of barrels, and the targeting ring's height over the
## deck.
const FLAK_ROW := 0.22
const FLAK_RING_LIFT := 1.6
## The shield generator from L5, by level from L5: the plinth's height, and how much higher the orb
## floats, the pylons growing with it; the field ring's and the L7 hovering ring's distance out
## from the orb, and the hovering ring's drop under its centre.
const SHIELD_PLINTHS := [0.36, 0.55, 0.58, 0.62]
const SHIELD_LIFTS := [0.5, 0.8, 1.05, 1.3]
const SHIELD_FIELD := 0.42
const SHIELD_RING := 0.5
const SHIELD_RING_DROP := 0.32
## The pylons' width, and the red collars' round them.
const SHIELD_PYLON := 0.2
const SHIELD_COLLAR := 0.3
## The arc tower from L5, by level from L5: the plinth's height, the coil's and the twin coils';
## the L7 discharge ring's distance out from the sphere.
const ARC_PLINTHS := [0.36, 0.4, 0.56, 0.6]
const ARC_HEIGHTS := [1.85, 2.05, 2.3, 2.5]
const ARC_TWINS := [0.85, 1.0, 1.1, 1.2]
const ARC_RING := 0.18
## The cloaked sentry's pod's height, and the radius of the red lens eye on its face towards the camera.
const SENTRY_POD := 0.44
const SENTRY_EYE := 0.07
## The cloaked sentry from L4, by level from L4: how high its armoured hex skirt lifts the pod; the
## L6 cloak ring's radii and its height over the skirt, its sights clear of the shimmer ring under
## it all through its bob; the L5 mantlet's size; the L7 crown's distance behind the guns.
const SENTRY_RISES := [0.15, 0.24, 0.38, 0.5]
const SENTRY_RING_INNER := 0.96
const SENTRY_RING_OUTER := 1.08
const SENTRY_RING_LIFT := 0.2
const SENTRY_MANTLET := Vector3(0.66, 0.08, 0.36)
const SENTRY_CROWN_BACK := 0.3
## The gravity well: how high its core floats over the well to L3 (higher from L4 by WELL_LIFTS),
## the core's radius to L3, the gyro rings' thickness, and the rotor's height over the core,
## clear of the rings' tumble.
const WELL_FLOAT := 1.0
const WELL_CORE := 0.22
const WELL_GYRO := 0.05
const WELL_ROTOR := 0.68
## The gravity well from L4, by level from L4: the plinth's height, how much higher the core
## floats over the well (the pillars growing with it) and the core's radius (bobbing at L4, so
## held at L1's size to clear the inner gyro ring over its bob; bigger and steady from L5); the L5 gyro ring's
## radii and its height under the core.
const WELL_PLINTHS := [0.3, 0.44, 0.48]
const WELL_LIFTS := [0.3, 0.55, 0.85]
const WELL_CORES := [0.22, 0.27, 0.3]
const WELL_RING_INNER := 0.9
const WELL_RING_OUTER := 1.03
const WELL_RING_DROP := 0.6
## The EMP tower from L4, by level from L4: the plinth's height and the storey it gains between
## its two blocks; the L5 pulse ring's radii and how far under the cage it hovers, round the
## tower's neck, so the core shows over it.
const EMP_PLINTHS := [0.36, 0.55, 0.6]
const EMP_RISES := [0.45, 0.9, 1.2]
const EMP_RING_INNER := 0.6
const EMP_RING_OUTER := 0.74
const EMP_RING_DROP := 0.14
## The railgun to L3, by level: how far the mount lifts the gun; the rails' width, the gap
## between them where the strip runs, and the spine under them.
const RAIL_LIFTS_LOW := [0.3, 0.38, 0.46]
const RAIL_WIDE := 0.2
const RAIL_GAP := 0.16
const RAIL_SPINE := 0.3
## The railgun from L4, by level from L4: the plinth's height and how far the mount lifts the gun
## over the drum; the capacitor cans' height on the drum, and how far the rear row and the L5
## front bank stand out on the plinth. The L6 targeting ring's height over the gun's deck.
const RAIL_PLINTHS := [0.34, 0.34, 0.46, 0.5]
const RAIL_LIFTS := [0.55, 0.7, 0.9, 1.1]
const RAIL_CAN := 0.5
const RAIL_ROW := 0.98
const RAIL_RING_LIFT := 1.05
## The ion beam from L3, by level from L3: the plinth's height and how much higher the emitter
## stands; the L3 power cell's distance out on the near corner; the L5 focus ring's distance up
## the beam from the lens.
const ION_PLINTHS := [0.24, 0.44, 0.46, 0.5]
const ION_RISES := [0.3, 0.45, 0.55, 0.65]
const ION_CELL := 1.06
const ION_FOCUS_OFF := 1.0
## The orbital cannon from L3, by level from L3: the plinth's height, the barrel's length and its
## lean from the vertical (steeper as it grows, so the muzzle stays over the footprint).
const ORBITAL_PLINTHS := [0.32, 0.46, 0.5]
const ORBITAL_LENGTHS := [2.0, 2.2, 2.35]
const ORBITAL_PITCHES := [35.0, 31.0, 28.0]
## From L3 the accelerator rings' places up the barrel, and from L4 the uplink ring's between the
## second and the third, as shares of the barrel between its first coil's place and its muzzle.
const ORBITAL_BANDS := [0.08, 0.42, 0.84]
const ORBITAL_RING_AT := 0.63
## The fire-control spire on the left corner: its tower's steps from the foot up, each [width,
## height], its lens's height over the foot, the halo's radius round the lens and its vanes' reach
## out from it, and from L4 the targeting beam's length up from the lens.
const ORBITAL_STEPS := [Vector2(0.34, 0.8), Vector2(0.27, 0.7), Vector2(0.2, 0.5)]
const ORBITAL_SPIRE := 2.2
const ORBITAL_HALO := 0.6
const ORBITAL_VANE := 0.48
const ORBITAL_BEAM := 1.3
## The way the spire's lens faces: towards the camera, tilted up to meet its 35-degree look down.
const TOWARD_LENS := Vector3(0.5792, 0.5736, 0.5792)


## To L5 a big red dome on a cream drum (gold at L5) heads the turret, its twin barrels long and
## fat with red emitter caps. From L6 the head rides a mount that lifts it a little more each
## level, on a taller plinth. L6 (Chrome): chrome plinth, mount, head and barrels, cyan strips along the barrels and cyan
## capacitor rings round their breeches, the cheeks chrome armour and bigger. L7 a much taller
## mount with a broad glowing band under the head, and a second pair of barrels over the first on
## a mantlet. L8 (Obsidian): the plinth, mount and head obsidian, glowing violet vein panels on the
## plinth's faces the camera sees and veins round the deck, the mount and the head, crystal inlays
## at the mount's foot, a violet focusing crystal at every muzzle. L9 a targeting ring hovering
## over the head, turning. L10 (Crown): gold filigree round the plinth and the head, a big gold
## crown on a stem over the dome, in the targeting ring, holding the antimatter core up. Each
## barrel's tip is a muzzle socket on the head (muzzle, muzzle_2, and from L7 muzzle_3 and
## muzzle_4), so in battle the head aims and its shots leave the barrels in turn.
static func build_laser_turret(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.42 if level < 6 else float(LASER_PLINTHS[level - 6])
	var lift := 0.0 if level < 6 else float(LASER_LIFTS[level - 6])
	var plate := _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	var glow := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	var top := _plinth(m, 3, 1.2, plinth, BELT, plate)
	Parts.drum(m, 0.84, 0.12, 0.04, 24, Vector3(0, top, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	for k: int in 2:
		_cell(m, Parts.around(1.42, 135.0 + 180.0 * k, Parts.PAD_HEIGHT), 0.3, LASER_PULSE.phased(k / 3.0))
	if level >= 3:
		_cell(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT), 0.38, LASER_PULSE.phased(2 / 3.0))
	if level >= 4:
		for degrees: float in [0.0, 90.0]:
			m.box_chamfered(Vector3(0.62, 0.22, 0.08), 0.02, Parts.around(1.1, degrees, Parts.PAD_HEIGHT + 0.06), ARMOUR,
				Vector3(0, 90.0 - degrees, 0))
	var foot := top + 0.12
	if level >= 6:
		# The mount: a column flared at its foot, a red band round the flare and a glowing band
		# (cyan, violet from the Obsidian tier) under the head.
		m.lathe(PackedVector2Array([Vector2(0.74, 0), Vector2(0.74, 0.05), Vector2(0.6, 0.13), Vector2(0.6, lift)]), 24,
			Vector3(0, foot, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
		m.ring(0.59, 0.64, 0.07, 24, Vector3(0, foot + 0.15, 0), ARMOUR_ROUND)
		var band := 0.06 if level < 7 else 0.16
		m.ring(0.59, 0.625, band, 24, Vector3(0, foot + lift - 0.04 - band, 0), glow)
	if level >= 8:
		_plinth_panels(m, 1.2, plinth)
		m.ring(0.9, 1.08, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
		m.ring(0.595, 0.615, lift - 0.45, 24, Vector3(0, foot + 0.2, 0), VEIN_PANEL)
		for degrees: float in [15.0, 45.0, 75.0]:
			m.prism(0.07, 0.07, 0.05, 4, Parts.around(0.8, degrees, top + 0.08), INLAY.phased(degrees / 90.0),
				Vector3(90, 90.0 - degrees, 0))
	if level >= 10:
		_plinth_filigree(m, 1.2)
		m.ring(0.98, 1.12, 0.02, 8, Vector3(0, top, 0), Parts.FILIGREE, Parts.OCTAGON)
	var pivot := Vector3(0, foot + lift, 0)
	# The head is built turned to SCREEN_RIGHT - 25, so the middle of its scan shows the barrels'
	# length.
	var head := p.moving(pivot, Motion.swing(Vector3.UP, 45.0, 6.0))
	var heading := Vector3(0, SCREEN_RIGHT - 25.0, 0)
	var along := Vector3(90, SCREEN_RIGHT - 25.0, 0)
	var shell := _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	# To L5 the head is a big red dome on a cream drum (a gold one at L5), its barrels long and fat
	# with red emitter caps, so the turret reads red from across the base.
	var low := level < 6
	var drum := shell
	if level == 5:
		drum = Parts.GOLD_ROUND
	Parts.drum(head, LASER_DOME.x if low else 0.62, 0.32, 0.05, 20, Vector3.ZERO, drum)
	if low:
		head.dome(LASER_DOME.x, LASER_DOME.y, 20, 6, Vector3(0, 0.32, 0), ARMOUR_ROUND)
	else:
		head.dome(0.57, 0.3, 20, 6, Vector3(0, 0.32, 0), shell)
	head.box_chamfered(Vector3(0.72, 0.38, 0.3), 0.06, LowPolyMesh.turn(Vector3(0, 0.1, 0.5), heading), DENSE, heading)
	var bore := LASER_BORE if low else 0.07 + 0.012 * mini(level, 5)
	var length := LASER_LENGTH if low else 0.5 + 0.04 * mini(level, 5)
	var barrel := BARREL if p.tier < Parts.Tier.CHROME else Parts.CHROME_ROUND
	var pairs: Array[Vector3] = [Vector3(0.18, 0.29, 0.5)]
	if level >= 7:
		pairs.append(Vector3(0.15, 0.58, 0.5))
		head.box_chamfered(Vector3(0.6, 0.2, 0.34), 0.04, LowPolyMesh.turn(Vector3(0, 0.45, 0.46), heading),
			_by_tier(p.tier, DENSE, Parts.CHROME, Parts.OBSIDIAN), heading)
	for pair: int in pairs.size():
		var scale := 1.0 if pair == 0 else 0.85
		var thick := bore * scale
		var long := length * (1.0 if pair == 0 else 0.9)
		# The upper pair is thinner, so it takes fewer sides.
		var sides := 16 if pair == 0 else 12
		for k: int in 2:
			var root := LowPolyMesh.turn(Vector3((2 * k - 1) * pairs[pair].x, pairs[pair].y, pairs[pair].z), heading)
			head.prism(thick, thick, long, sides, root, barrel, along)
			if low:
				# A red emitter cap round the muzzle.
				head.tube(thick * 0.5, LASER_CAP, 0.14, sides, _at(root, Vector3(0, long - 0.12, 0), along), ARMOUR_ROUND, along)
			else:
				head.tube(thick * 0.5, thick + 0.035, 0.12, sides, _at(root, Vector3(0, long - 0.1, 0), along),
					GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL, along)
			# The muzzle sockets, the shots leaving them in turn: the lower pair's, then the upper's. To L5
			# each sits at its red cap's end.
			var barrel_index := pair * 2 + k
			head.socket("muzzle" if barrel_index == 0 else "muzzle_%d" % (barrel_index + 1),
				_at(root, Vector3(0, long + (0.02 if low else 0.03), 0), along), LowPolyMesh.turn(Vector3.UP, along))
			if level < 8:
				head.orb(thick * 0.85, sides if pair == 0 else 10, 8 if pair == 0 else 4, _at(root, Vector3(0, long + 0.03, 0), along),
					LASER_PULSE.phased(0.5 * k))
			else:
				# A violet focusing crystal in the muzzle: a long point out, a short one back.
				head.cone(thick * 0.8, 0.2 * scale, 8, _at(root, Vector3(0, long + 0.02, 0), along), FOCUS.phased(0.5 * k), along)
				head.cone(thick * 0.8, 0.06, 8, _at(root, Vector3(0, long + 0.02, 0), along), FOCUS.phased(0.5 * k),
					Vector3(-90, along.y, 0))
			if level >= 6:
				head.box(Vector3(0.04, 0.025, long * 0.5), _at(root, Vector3(0, thick - 0.012, long * 0.25), heading), glow,
					heading)
				if pair == 0:
					for ring: float in [0.2, 0.32]:
						Parts.torus(head, thick + 0.012, 0.026, 12, 6, _at(root, Vector3(0, ring, 0), along), glow, along)
	if level >= 2:
		var cheek := Vector3(0.14, 0.34, 0.62) if level < 6 else Vector3(0.16, 0.44, 0.72)
		# To L5 the cheeks are cream, so they part from the red dome and deck.
		var cheek_surf := _by_tier(p.tier, SHELL, Parts.CHROME, Parts.OBSIDIAN)
		for side: float in [-1.0, 1.0]:
			var out := 0.72 if level < 6 else 0.64
			head.box_chamfered(cheek, 0.04, LowPolyMesh.turn(Vector3(side * out, 0.04, 0.02), heading), cheek_surf, heading)
			if level >= 8 and LowPolyMesh.turn(Vector3(side, 0, 0), heading).dot(TOWARD_CAMERA) > 0.2:
				head.box(Vector3(0.02, cheek.y - 0.14, cheek.z - 0.16),
					LowPolyMesh.turn(Vector3(side * (out + cheek.x * 0.5 + 0.01), 0.11, 0.02), heading), VEIN_PANEL, heading)
	if level >= 3:
		head.box_chamfered(Vector3(0.66, 0.3, 0.34), 0.05, LowPolyMesh.turn(Vector3(0, 0.14, 0.8), heading), VENT, heading)
		head.box(Vector3(0.42, 0.05, 0.02), LowPolyMesh.turn(Vector3(0, 0.33, 0.655), heading), LASER, heading)
	if level >= 4:
		head.box_chamfered(Vector3(0.62, 0.36, 0.34), 0.06, LowPolyMesh.turn(Vector3(0, 0.12, -0.62), heading), DENSE, heading)
		_lamp_post(head, LowPolyMesh.turn(Vector3(-0.28, 0.5, -0.25), heading), 0.4, LASER_BLINK)
	if level >= 6:
		Parts.torus(head, 0.63, 0.035, 24, 10, Vector3(0, 0.27, 0), GOLD)
	if level >= 8:
		# Veins round the head's drum and up its dome.
		head.ring(0.615, 0.64, 0.12, 20, Vector3(0, 0.08, 0), VEIN_PANEL)
		for degrees: float in [20.0, 110.0, 200.0, 290.0]:
			Parts.dome_seam(head, 0.57, 0.3, Vector3(0, 0.32, 0), degrees, Parts.CORE_GLOW)
	if level >= 10:
		# Filigree round the drum, and a gold crown on a stem over the dome, in the targeting ring,
		# holding the antimatter core up where it shows.
		head.ring(0.625, 0.645, 0.1, 20, Vector3(0, 0.2, 0), Parts.FILIGREE)
		head.prism(0.07, 0.05, 0.4, 12, Vector3(0, 0.56, 0), Parts.GOLD_ROUND)
		_crown(head, Vector3(0, 0.94, 0), 0.25, 6, 0.18)
		head.orb(0.19, 16, 6, Vector3(0, 1.08, 0), Parts.CORE_GLOW)
	if level >= 9:
		var ring_y := pivot.y + 0.62 + LASER_RING_LIFT
		var ring := p.moving(Vector3(0, ring_y, 0), Motion.spin(Vector3.UP, 0.6))
		_hover_ring(ring, 0.5, 0.62, p.tier)


## From L6 a chrome radar mast rises through the launcher's centre with a dish turning on top, and
## the launcher's pods stand either side of it, their tubes closer set. L6 (Chrome): chrome plinth,
## turret ring, arms and pods, one pod of twelve tubes left of the mast, cyan loading lights
## blinking up the arm the camera sees. L7 a second rack, a pod of eight tubes right of the mast,
## and the mast much taller with a bigger dish and a second glowing band.
## L8 (Obsidian): obsidian plinth, ring, arms and pods, glowing violet vein panels on the
## plinth's and the pods' faces the camera sees, veins round the deck, crystal inlays on it, the
## missiles tipped with violet crystals. L9 a radar ring hovering round the mast under the dish,
## turning. L10 (Crown): gold filigree round the plinth, the deck and the pods' faces, a gold mast
## with a gold crown over the racks holding the antimatter core up clear of the pods.
static func build_missile_battery(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.36 if level < 8 else (0.56 if level < 10 else 0.62)
	var top := _plinth(m, 3, 1.2, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	Parts.drum(m, 0.8, 0.2, 0.05, 24, Vector3(0, top, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var deck := top + 0.2
	_crate(m, Parts.around(1.42, 315.0, Parts.PAD_HEIGHT))
	if level >= 3:
		_crate(m, Parts.around(1.42, 135.0, Parts.PAD_HEIGHT))
	# The pods, each [x across the trunnion, columns, rows], and the tubes' spacing.
	var pods: Array[Vector3] = []
	var spacing := 0.34
	if level < 6:
		pods.append(Vector3(0, 2 if level < 3 else 3, 2 if level < 4 else 3))
	else:
		spacing = MISSILE_SPACING
		pods.append(Vector3(-MISSILE_SLOT - (3 * spacing + 0.2) * 0.5, 3, 4))
		if level >= 7:
			pods.append(Vector3(MISSILE_SLOT + (2 * spacing + 0.2) * 0.5, 2, 4))
	var left := INF
	var right := -INF
	for pod: Vector3 in pods:
		left = minf(left, pod.x - (pod.y * spacing + 0.2) * 0.5)
		right = maxf(right, pod.x + (pod.y * spacing + 0.2) * 0.5)
	if level == 6:
		# The right arm stands across the slot from the one pod.
		right = MISSILE_SLOT
	var yaw := 100.0
	var heading := Vector3(0, yaw, 0)
	var aim := Vector3(-32, yaw, 0)
	# The launcher scans on the deck: its arms, the pods and their tubes, built about the deck's centre.
	var launcher := p.moving(Vector3(0, deck, 0), Motion.swing(Vector3.UP, 15.0, 7.0))
	var trunnion := Vector3(0, 0.62 if level < 6 else MISSILE_TRUNNION, 0)
	var trim := GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL
	for side: float in [-1.0, 1.0]:
		var edge := right if side > 0.0 else -left
		var arm := LowPolyMesh.turn(Vector3(side * (edge + 0.1), 0, 0), heading)
		launcher.box_chamfered(Vector3(0.16, trunnion.y + 0.1, 0.46), 0.04, arm, _by_tier(p.tier, SHELL, Parts.CHROME, Parts.OBSIDIAN),
			heading)
		launcher.prism(0.12, 0.12, 0.06, 16,
			trunnion + LowPolyMesh.turn(Vector3(side * (edge + 0.17), 0, 0), heading), trim,
			heading + Vector3(0, 0, -90 * side))
		if level >= 6 and LowPolyMesh.turn(Vector3(side, 0, 0), heading).dot(TOWARD_CAMERA) > 0.2:
			# Loading lights blinking up the arm's outer face, cyan (violet from the Obsidian tier).
			for k: int in 3:
				launcher.box(Vector3(0.02, 0.1, 0.24), LowPolyMesh.turn(Vector3(side * (edge + 0.185), 0.2 + 0.24 * k, 0), heading),
					(CORE_BLINK if p.tier >= Parts.Tier.OBSIDIAN else ION_BLINK).phased(Parts.chase(k, 3)), heading)
	for pod: Vector3 in pods:
		_pod(launcher, trunnion, aim, pod.x, int(pod.y), int(pod.z), spacing, level, p.tier)
	if level >= 2:
		_lamp_post(m, Parts.around(0.95, 225.0, top), 0.7, LASER_PULSE)
	if level >= 5:
		_crate(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT))
	if level < 6:
		return
	if level >= 8:
		_plinth_panels(m, 1.2, plinth)
		m.ring(0.86, 1.08, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
		for degrees: float in [15.0, 45.0, 75.0]:
			m.prism(0.07, 0.07, 0.05, 4, Parts.around(0.96, degrees, top), INLAY.phased(degrees / 90.0),
				Vector3(90, 90.0 - degrees, 0))
	if level >= 10:
		_plinth_filigree(m, 1.2)
		m.ring(0.86, 1.1, 0.02, 8, Vector3(0, top, 0), Parts.FILIGREE, Parts.OCTAGON)
	# The radar mast up the launcher's centre, through the slot between its pods.
	var dish_y: float = deck + trunnion.y + float(MISSILE_DISH_LIFTS[level - 6])
	var mast := Parts.GOLD_ROUND if p.tier >= Parts.Tier.CROWN else _by_tier(p.tier, BARREL, Parts.CHROME_ROUND, Parts.CHROME_ROUND)
	m.prism(0.08, 0.07, dish_y - deck, 16, Vector3(0, deck, 0), mast)
	var band_glow := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	m.ring(0.07, 0.1, 0.06, 16, Vector3(0, dish_y - 0.25, 0), band_glow)
	if level >= 7:
		m.ring(0.07, 0.105, 0.1, 16, Vector3(0, dish_y - 0.5, 0), band_glow)
	if level >= 10:
		# A gold crown on the mast over the racks, inside the radar ring, holding the antimatter core up
		# clear of the pods.
		_crown(m, Vector3(0, deck + trunnion.y + 1.0, 0), 0.17, 6, 0.14)
		m.orb(0.19, 16, 6, Vector3(0, deck + trunnion.y + 1.3, 0), Parts.CORE_GLOW)
	var radar := p.moving(Vector3(0, dish_y, 0), Motion.spin(Vector3.UP, Parts.DISH_RATE))
	var face := Vector3(70, 0, 0)
	# From L7 a bigger dish.
	var dish := 1.0 if level < 7 else 1.3
	radar.lathe(PackedVector2Array([
		Vector2(0.06, 0) * dish, Vector2(0.34, 0.1) * dish, Vector2(0.32, 0.13) * dish, Vector2(0, 0.04) * dish,
	]), 24, Vector3(0, 0.12, -0.08), _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.CHROME_ROUND), face)
	radar.prism(0.05, 0.05, 0.14, 16, Vector3.ZERO, Parts.GUNMETAL)
	radar.orb(0.055 * dish, 12, 6, Vector3(0, 0.12, 0) + LowPolyMesh.turn(Vector3(0, 0.27 * dish, 0), face),
		Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP)
	if level >= 9:
		var ring := p.moving(Vector3(0, deck + trunnion.y + 1.0, 0), Motion.spin(Vector3.UP, -0.5))
		_hover_ring(ring, 0.3, 0.42, p.tier)


## A missile pod on the launcher, `columns` by `rows` tubes `spacing` apart, centred `x` across
## the trunnion: a box (chrome or obsidian at the high tiers) in a red armour frame round its face
## (gold filigree at the Crown), so the dark tubes stand out on it at every tier, red-tipped tubes
## whose tips blink in a chase snaking along the rows (violet crystals from L8); from L2 a hazard
## striped plate on its top, from L5 a gold plate
## on its back, from L8 a glowing violet vein panel across its face and on its side the camera
## sees. From L6 the tubes take fewer sides.
static func _pod(s: LowPolyMesh, trunnion: Vector3, aim: Vector3, x: float, columns: int, rows: int, spacing: float,
		level: int, tier: int) -> void:
	var k := spacing / 0.34
	var width := columns * spacing + 0.2
	var height := rows * spacing + 0.2
	var depth := 0.9
	var sides := 16 if level < 6 else 12
	s.box_chamfered(Vector3(width, height, depth), 0.06, _at(trunnion, Vector3(x, -height * 0.5, 0), aim),
		_by_tier(tier, SHELL, Parts.CHROME, Parts.OBSIDIAN), aim)
	s.box_chamfered(Vector3(width + 0.04, height + 0.04, 0.16), 0.03,
		_at(trunnion, Vector3(x, -height * 0.5 - 0.02, depth * 0.5 - 0.22), aim),
		Parts.FILIGREE if tier >= Parts.Tier.CROWN else ARMOUR, aim)
	var tube_aim := aim + Vector3(90, 0, 0)
	var tip := LASER_BLINK if level < 8 else CRYSTAL_BLINK
	for row: int in rows:
		for column: int in columns:
			var face := Vector3(x + (column - (columns - 1) * 0.5) * spacing, (row - (rows - 1) * 0.5) * spacing, depth * 0.5 - 0.04)
			var mouth := _at(trunnion, face, aim)
			var turn_order := column if row % 2 == 0 else columns - 1 - column
			s.tube(0.1 * k, 0.14 * k, 0.1, sides, mouth, Parts.GUNMETAL, tube_aim)
			s.cone(0.085 * k, 0.2 * k, sides, mouth, tip.phased(Parts.chase(row * columns + turn_order, rows * columns)),
				tube_aim)
	if level >= 2:
		s.box_chamfered(Vector3(width * 0.8, 0.05, depth * 0.45), 0.02,
			_at(trunnion, Vector3(x, height * 0.5, -0.12), aim), HAZARD_FINE, aim)
	if level >= 5:
		s.box_chamfered(Vector3(width + 0.05, height + 0.05, 0.08), 0.02,
			_at(trunnion, Vector3(x, -height * 0.5 - 0.025, -depth * 0.5 + 0.02), aim),
			GOLD if tier >= Parts.Tier.GOLD else Parts.HULL_MID, aim)
	if level >= 8:
		# The face glows violet round the tubes' mouths.
		s.box(Vector3(width - 0.1, height - 0.1, 0.02), _at(trunnion, Vector3(x, -(height - 0.1) * 0.5, depth * 0.5 - 0.005), aim),
			VEIN_PANEL, aim)
		for side: float in [-1.0, 1.0]:
			if LowPolyMesh.turn(Vector3(side, 0, 0), aim).dot(TOWARD_CAMERA) > 0.2:
				s.box(Vector3(0.02, height - 0.24, depth - 0.3),
					_at(trunnion, Vector3(x + side * (width * 0.5 + 0.01), -(height - 0.24) * 0.5, -0.05), aim), VEIN_PANEL, aim)


## The chamber is a ball of boiling plasma at every level: the glowing core, tongues licking out of
## it and a translucent swirl shell crawling round it. From L5 a bigger bowl stands on a pedestal
## that lifts it more each level, the buttresses round its foot giving way to it. L5 (Chrome):
## chrome plinth, pedestal, bowl and barrel, a cyan strip round the pedestal and cyan plasma coils
## round the barrel's breech. L6 a third coil and a chrome loader arm on the near corner, standing
## as tall as the bowl's rise, its boom swinging a plasma canister over the bowl. L7 (Obsidian): a
## taller plinth with glowing violet vein panels on its faces the camera sees, the pedestal, bowl
## and barrel obsidian veined violet, the coils violet, a violet plasma pool glowing on the bowl
## round the chamber, and a glowing charge ring hovering well past the muzzle, turning about the
## barrel. L8 (Crown): gold filigree round the plinth and the pedestal, the pool the antimatter core
## with a core ring round the chamber's foot, a gold crown round the bowl's rim, and an ammunition
## rack on the near corner: an obsidian octagonal pedestal, gold-topped, where the loader arm
## stands, three upright plasma canisters banded gold in a gunmetal cradle beside it.
static func build_plasma_mortar(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.3 if level < 5 else float(MORTAR_PLINTHS[level - 5])
	var rise := 0.0 if level < 5 else float(MORTAR_RISES[level - 5])
	var radius := 1.25 if level < 7 else MORTAR_WIDE
	var top := _plinth(m, 3, radius, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	if level >= 5:
		# The pedestal, flaring out under the bowl.
		m.lathe(PackedVector2Array([Vector2(0.88, 0), Vector2(0.88, rise - 0.1), Vector2(1.1, rise)]), 20, Vector3(0, top, 0),
			_by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
		m.ring(0.87, 0.9, 0.05, 20, Vector3(0, top + rise * 0.4, 0),
			VEIN_PANEL if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP)
	var base := top + rise
	# From L5 a bigger bowl: its outer wall wider, its inner lip where it was.
	var bowl := 1.0 if level < 5 else MORTAR_BOWL
	m.lathe(PackedVector2Array([
		Vector2(1.0 * bowl, 0), Vector2(1.06 * bowl, 0.12), Vector2(1.0 * bowl, 0.26), Vector2(0.86 * bowl, 0.32),
		Vector2(0.62, 0.32), Vector2(0.54, 0.2), Vector2(0.54, 0),
	]), 20, Vector3(0, base, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var seat := base + 0.32
	if level >= 2:
		for degrees: float in [135.0, 315.0]:
			_cell(m, Parts.around(1.42, degrees, Parts.PAD_HEIGHT), 0.32, PLASMA)
		if level < 5:
			for degrees: float in [0.0, 90.0, 180.0, 270.0]:
				m.box_chamfered(Vector3(0.14, 0.3, 0.3), 0.04, Parts.around(1.0, degrees + 45.0, top + 0.02), Parts.GUNMETAL,
					Vector3(0, 45.0 - degrees, 0))
	if level >= 3:
		m.lathe(PackedVector2Array([
			Vector2(0.86, 0), Vector2(0.86, 0.14), Vector2(0.78, 0.2), Vector2(0.6, 0.2),
			Vector2(0.54, 0.12), Vector2(0.54, 0),
		]), 20, Vector3(0, seat, 0), ARMOUR_ROUND)
		seat += 0.2
	# The plasma chamber: a glowing sphere sitting up on the ring, the barrel rising out of its
	# far side, so its near side shows over the cradle's low cheeks at every level.
	var chamber := 0.3 + 0.04 * level
	var breech := Vector3(0, seat + chamber, 0)
	var tilt := Vector3(34, SCREEN_RIGHT, 0)
	var heading := Vector3(0, SCREEN_RIGHT, 0)
	m.orb(chamber, 16, 6, breech, PLASMA_PULSE)
	var band := GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL
	Parts.torus(m, chamber + 0.01, 0.045, 20, 10, breech - Vector3(0, 0.045, 0), band)
	# The cage's ribs cross the band at Parts.around() angles 15, 105, 195 and 285; the quarter
	# between 15 and 105 faces the viewer, the barrel and the cheeks hiding its top and its foot.
	for yaw: float in [30.0, 120.0]:
		var rib := Vector3(0, SCREEN_RIGHT + yaw, 90)
		Parts.torus(m, chamber + 0.01, 0.035, 16, 6, _at(breech, Vector3(0, -0.035, 0), rib), Parts.GUNMETAL, rib)
	# Plasma bubbles surfacing between the bars, and tongues of plasma licking out of the core round
	# its rim as the camera sees it, swelling out of step.
	var bubbles: Array[Vector2] = [Vector2(35, 22), Vector2(70, 40), Vector2(92, 14)]
	for k: int in bubbles.size():
		m.orb(0.05, 8, 3, breech + Parts.on_sphere(chamber - 0.01, bubbles[k]), BUBBLE.phased(k / 3.0 + 0.1))
	var tongues: Array[Vector2] = [Vector2(140, 4), Vector2(180, 40), Vector2(30, -18)]
	for k: int in tongues.size():
		var out := Parts.on_sphere(1.0, tongues[k])
		m.lathe(PackedVector2Array([
			Vector2(0.07, 0), Vector2(0.1, 0.06), Vector2(0.09, 0.13), Vector2(0.055, 0.19), Vector2(0, 0.21),
		]), 8, breech + out * (chamber - 0.03), PLASMA_TONGUE.phased(k / 3.0), Parts.facing(out))
	# The swirl: a translucent shell round the core and its cage, its blotches crawling round it, so
	# the ball reads as boiling plasma.
	m.orb(chamber + 0.06, 16, 5, breech, PLASMA_SWIRL)
	# A cooling fan on the heavy ring's flank, turning about the outward +Z.
	var fan := Vector3(0, base + 0.15, 1.08 * bowl)
	m.ring(0.1, 0.13, 0.07, 12, fan - Vector3(0, 0, 0.06), Parts.GUNMETAL, Vector3(90, 0, 0))
	var rotor := p.moving(fan, Motion.spin(Vector3.BACK, 7.0))
	Parts.drum(rotor, 0.045, 0.05, 0.015, 8, Vector3(0, 0, -0.03), Parts.GUNMETAL, Vector3(90, 0, 0))
	for k: int in 3:
		rotor.box(Vector3(0.06, 0.1, 0.02), Vector3(0, 0, -0.01), SHELL_MID, Vector3(0, 0, 120.0 * k))
	for side: float in [-1.0, 1.0]:
		var cheek := LowPolyMesh.turn(Vector3(side * (chamber + 0.12), 0, 0.05), heading)
		m.box_chamfered(Vector3(0.14, 0.24, 0.5), 0.04, Vector3(cheek.x, seat - 0.1, cheek.z), SHELL, heading)
	var muzzle := 0.95
	var mouth := _at(breech, Vector3(0, chamber * 0.85, 0), tilt)
	var shell := _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	m.lathe(PackedVector2Array([Vector2(0.3, -0.12), Vector2(0.44, 0.0), Vector2(0.44, muzzle - 0.24)]),
		20, mouth, shell, tilt)
	m.lathe(PackedVector2Array([
		Vector2(0.44, muzzle - 0.24), Vector2(0.52, muzzle - 0.18), Vector2(0.52, muzzle), Vector2(0.42, muzzle + 0.04),
		Vector2(0.32, muzzle - 0.04),
	]), 20, mouth, GOLD if p.tier >= Parts.Tier.GOLD else SHELL, tilt)
	# The bore's lining glows, its bands running up and out of the muzzle.
	m.lathe(PackedVector2Array([Vector2(0.32, muzzle - 0.04), Vector2(0.32, muzzle - 0.3)]), 20, mouth, BORE, tilt)
	m.disc(0.32, 20, _at(mouth, Vector3(0, muzzle - 0.3, 0), tilt), PLASMA_PULSE.phased(0.5), tilt)
	m.tube(0.44, 0.47, 0.12, 20, _at(mouth, Vector3(0, 0.22, 0), tilt), ARMOUR_ROUND, tilt)
	if level < 5:
		return
	# Plasma coils round the breech: cyan, violet from the Obsidian tier.
	var coil := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	for along: float in ([0.4, 0.5] if level < 6 else [0.38, 0.47, 0.56]):
		Parts.torus(m, 0.455, 0.032, 12, 6, _at(mouth, Vector3(0, along, 0), tilt), coil, tilt)
	if level >= 6:
		if level < 8:
			_loader_arm(p, Parts.around(MORTAR_LOADER, 45.0, Parts.PAD_HEIGHT), Parts.around(0.95, 108.0, 0.0), p.tier,
				seat + MORTAR_LOADER_CLEAR - Parts.PAD_HEIGHT)
	if level >= 7:
		_plinth_panels(m, radius, plinth)
		# Veins round the barrel's breech and across the bowl's flank the camera sees.
		m.lathe(PackedVector2Array([Vector2(0.446, 0.02), Vector2(0.446, 0.2)]), 20, mouth, VEIN_PANEL, tilt)
		m.lathe(PackedVector2Array([Vector2(1.068 * bowl, 0.07), Vector2(1.068 * bowl, 0.17)]), 20, Vector3(0, base, 0), VEIN_PANEL,
			Vector3.ZERO, -5.0, 80.0)
		# The plasma pool on the armour ring round the chamber's foot, the antimatter core at the Crown.
		m.lathe(PackedVector2Array([Vector2(0.775, 0.205), Vector2(0.58, 0.205)]), 20, Vector3(0, seat - 0.2, 0),
			Parts.CORE_GLOW if p.tier >= Parts.Tier.CROWN else PLASMA_PULSE)
		# The charge ring hovering well past the muzzle, glowing violet all over, turning about the barrel.
		var axis := LowPolyMesh.turn(Vector3.UP, tilt)
		var charge := p.moving(_at(mouth, Vector3(0, muzzle + MORTAR_CHARGE_OFF, 0), tilt), Motion.spin(axis, 1.6))
		charge.ring(MORTAR_CHARGE_INNER, MORTAR_CHARGE_OUTER, 0.1, 24, LowPolyMesh.turn(Vector3(0, -0.05, 0), tilt), HOVER_RIM, tilt)
		charge.lathe(PackedVector2Array([Vector2(MORTAR_CHARGE_OUTER - 0.02, 0.052), Vector2(MORTAR_CHARGE_INNER + 0.02, 0.052)]),
			24, Vector3.ZERO, HOVER_RIM, tilt)
		charge.lathe(PackedVector2Array([Vector2(MORTAR_CHARGE_OUTER + 0.006, -0.04), Vector2(MORTAR_CHARGE_OUTER + 0.006, 0.04)]),
			24, Vector3.ZERO, HOVER_RIM, tilt)
		for k: int in 4:
			charge.orb(0.07, 8, 4, LowPolyMesh.turn(Parts.around((MORTAR_CHARGE_INNER + MORTAR_CHARGE_OUTER) * 0.5, 90.0 * k, 0.06),
				tilt), (HOVER_GOLD if p.tier >= Parts.Tier.CROWN else HOVER_SIGHT))
	if level >= 8:
		_plinth_filigree(m, radius)
		m.ring(0.885, 0.905, 0.1, 20, Vector3(0, top + rise * 0.6, 0), Parts.FILIGREE)
		Parts.torus(m, chamber + 0.04, 0.06, 20, 8, Vector3(0, seat, 0), Parts.CORE_GLOW)
		# The gold crown round the bowl's rim.
		Parts.torus(m, 0.86, 0.04, 24, 8, Vector3(0, seat - 0.06, 0), Parts.GOLD_ROUND)
		for k: int in 8:
			m.cone(0.05, 0.16, 8, Parts.around(0.86, 22.5 + 45.0 * k, seat), Parts.GOLD_ROUND)
		# The ammunition rack on the near corner: the loader arm stands on its pedestal, taller, and
		# feeds the mortar from the canisters racked beside it on the camera's side.
		var balcony := Parts.around(MORTAR_BALCONY, 45.0, Parts.PAD_HEIGHT)
		Parts.drum(m, MORTAR_BALCONY_RADIUS, top - Parts.PAD_HEIGHT, 0.04, 8, balcony, Parts.OBSIDIAN_ROUND, Parts.OCTAGON)
		m.ring(MORTAR_BALCONY_RADIUS - 0.01, MORTAR_BALCONY_RADIUS + 0.025, 0.06, 8, Vector3(balcony.x, top - 0.1, balcony.z),
			Parts.FILIGREE, Parts.OCTAGON)
		m.disc(MORTAR_BALCONY_RADIUS - 0.04, 8, Vector3(balcony.x, top + 0.002, balcony.z), Parts.GOLD_ROUND, Parts.OCTAGON)
		var deck := Vector3(balcony.x, top, balcony.z)
		# The cradle: a gunmetal tray under the canisters and a cup round each one's foot.
		m.ring(MORTAR_RACK - MORTAR_CANISTER - 0.04, MORTAR_RACK + MORTAR_CANISTER + 0.04, 0.05, 16, deck, Parts.GUNMETAL,
			Vector3.ZERO, -45.0, 135.0)
		for k: int in 3:
			var stand := deck + Parts.around(MORTAR_RACK, 60.0 * k - 15.0, 0.05)
			m.ring(MORTAR_CANISTER - 0.005, MORTAR_CANISTER + 0.03, 0.1, 12, stand, Parts.GUNMETAL)
			m.lathe(PackedVector2Array([
				Vector2(MORTAR_CANISTER, 0), Vector2(MORTAR_CANISTER, MORTAR_CANISTER_HEIGHT - 0.06),
				Vector2(MORTAR_CANISTER * 0.7, MORTAR_CANISTER_HEIGHT - 0.01), Vector2(0, MORTAR_CANISTER_HEIGHT),
			]), 12, stand, PLASMA_PULSE.phased(k / 3.0))
			m.ring(MORTAR_CANISTER - 0.005, MORTAR_CANISTER + 0.02, 0.05, 12, stand + Vector3(0, MORTAR_CANISTER_HEIGHT * 0.55, 0),
				Parts.GOLD_ROUND)
		# The canister clears the crown's spikes.
		_loader_arm(p, Vector3(balcony.x, top, balcony.z), Parts.around(0.95, 108.0, 0.0), p.tier,
			seat + MORTAR_LOADER_CLEAR + 0.16 - top, false)


## The plasma mortar's L6 loader arm standing on `foot`, a moving part swinging about its column: a
## chrome column (obsidian from the Obsidian tier) on a gunmetal base, a long boom reaching across
## the screen to over the bowl's left flank (`reach`, on the ground) and a plasma canister hanging
## from its end; a glowing band round the column and a strip along the boom. Its shoulder stands
## `shoulder_y` over `foot`, which the caller sets from the bowl's rim, so the canister hangs over
## the bowl at every level; `base` gives it a gunmetal base on the ground.
static func _loader_arm(p: Parts, foot: Vector3, reach: Vector3, tier: int, shoulder_y: float,
		base: bool = true) -> void:
	var arm := p.moving(foot, Motion.swing(Vector3.UP, 12.0, 5.0))
	var plate := _by_tier(tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	var glow := Parts.CORE_GLOW if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	var across := Vector3(reach.x - foot.x, 0, reach.z - foot.z)
	var start := 0.14 if base else 0.0
	if base:
		Parts.drum(arm, 0.17, 0.14, 0.03, 12, Vector3.ZERO, Parts.GUNMETAL)
	# On the rack's pedestal (no base) the column is slimmer, clear of the canisters.
	var column := 0.11 if base else 0.08
	arm.prism(column, column - 0.02, shoulder_y - 0.06 - start, 12, Vector3(0, start, 0), plate)
	arm.ring(column - 0.01, column + 0.01, 0.06, 12, Vector3(0, shoulder_y - 0.6, 0), glow)
	var shoulder := Vector3(0, shoulder_y, 0)
	arm.orb(0.13, 10, 5, shoulder, Parts.GUNMETAL)
	var tip := shoulder + Vector3(0, 0.12, 0) + across
	Parts.beam(arm, shoulder, tip, 0.12, plate)
	Parts.beam(arm, shoulder + Vector3(0, 0.065, 0), tip + Vector3(0, 0.065, 0), 0.04, glow, 0.01)
	arm.prism(0.05, 0.05, 0.16, 12, tip - Vector3(0, 0.16, 0), Parts.GUNMETAL)
	arm.orb(0.13, 12, 6, tip - Vector3(0, 0.28, 0), PLASMA_PULSE)
	Parts.torus(arm, 0.13, 0.03, 12, 6, tip - Vector3(0, 0.29, 0), plate)


## Each arm is a chamfered pylon 0.2 across, collared in red at its foot, and a glowing conduit
## up to its tip by the orb. From L5 the orb floats higher every level and the pylons stand
## taller, growing with it. L5 (Chrome): chrome plinth, drum, dome and pylons, a cyan strip up each
## pylon's outer face over a red armour collar, a bigger orb and a cyan field ring round it. L6
## (Obsidian): a taller plinth with glowing violet vein panels on its faces the camera sees, the
## dome, drum and pylons obsidian, veins round the deck, up the dome and the pylons, crystal
## inlays on the deck, a pink crystal orb, the conduits, the field ring and the hologram band violet,
## violet crystal emitters and arcs. L7 a field ring hovering round the orb's lower half, turning,
## and a second collar on every pylon. L8 (Crown): gold filigree round the plinth and the
## pylons, the orb the antimatter core under a gold halo, and a gold field ring outside the violet
## one.
static func build_shield_generator(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.3 if level < 5 else float(SHIELD_PLINTHS[level - 5])
	var lift := 0.0 if level < 5 else float(SHIELD_LIFTS[level - 5])
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var top := _plinth(m, 3, 1.15, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	Parts.drum(m, 0.9, 0.16, 0.04, 24, Vector3(0, top, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var foot := top + 0.16
	m.dome(0.84, 0.55, 20, 6, Vector3(0, foot, 0), _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	m.ring(0.8, 0.88, 0.05, 24, Vector3(0, foot, 0), Parts.CORE_GLOW if obsidian else ION)
	var orb_radius := 0.3 + 0.05 * level
	var orb := Vector3(0, top + 1.45 + 0.05 * level + lift, 0)
	var knuckle := GOLD if p.tier >= Parts.Tier.GOLD else ARMOUR_ROUND
	var pylon := _by_tier(p.tier, SHELL_DARK, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	for k: int in 3:
		var degrees := 75.0 + 120.0 * k
		var root := Parts.around(0.6, degrees, foot + 0.35)
		var elbow := Parts.around(1.0, degrees, foot + 0.72 + lift)
		# The tip stands off the orb, its cone's point 0.12 short of it, for an arc to jump.
		var toward := (Parts.around(0.44, degrees, orb.y - orb_radius * 0.75) - orb).normalized()
		var tip := orb + toward * (orb_radius + 0.3)
		# A chamfered pylon and a glowing conduit meeting under the knuckle, which hides the bend;
		# current runs up the conduit to the tip. A red armour collar round the pylon's foot.
		var up := Parts.facing(elbow - root)
		Parts.beam(m, root, elbow, SHIELD_PYLON, pylon, 0.04)
		Parts.pipe_run(m, PackedVector3Array([elbow, tip]), 0.09, VIOLET_CURRENT if obsidian else ION_CURRENT)
		m.orb(0.15, 12, 5, elbow, knuckle)
		m.box_chamfered(Vector3(SHIELD_COLLAR, 0.15, SHIELD_COLLAR), 0.03, root.lerp(elbow, 0.08), ARMOUR, up)
		m.cone(0.11, 0.18, 16, tip, FOCUS.phased(k / 3.0) if obsidian else ION, Parts.facing(orb - tip))
		Parts.arc(m, orb + toward * (orb_radius + 0.12), orb + toward * (orb_radius - 0.02), 3, 0.03,
			(VIOLET_ARC if obsidian else ION_ARC).phased(k / 3.0))
		if level >= 2:
			Parts.torus(m, 0.13, 0.04, 12, 6, elbow.lerp(tip, 0.45), Parts.CORE_GLOW if obsidian else ION, Parts.facing(tip - elbow))
		if level >= 3:
			var short_degrees := degrees + 60.0
			var short_root := Parts.around(0.62, short_degrees, foot + 0.3)
			var short_tip := Parts.around(0.84, short_degrees, foot + 0.72)
			Parts.beam(m, short_root, short_tip, 0.16, pylon, 0.03)
			m.orb(0.11, 12, 5, short_tip, knuckle)
		if level >= 5:
			# A glowing strip up the pylon's outer face (cyan, violet from the Obsidian tier); a
			# second collar under the knuckle from L7.
			var out := Parts.around(1.0, degrees, 0.0)
			Parts.beam(m, root.lerp(elbow, 0.2) + out * 0.11, elbow.lerp(root, 0.12) + out * 0.11, 0.05,
				Parts.CORE_GLOW if obsidian else Parts.CYAN_STRIP, 0.01)
			if level >= 7:
				m.box_chamfered(Vector3(SHIELD_COLLAR, 0.15, SHIELD_COLLAR), 0.03, elbow.lerp(root, 0.2), ARMOUR, up)
			if level >= 8:
				m.box_chamfered(Vector3(SHIELD_COLLAR - 0.04, 0.1, SHIELD_COLLAR - 0.04), 0.02, root.lerp(elbow, 0.5), Parts.FILIGREE,
					up)
	var core_surf := ION_ORB
	if level >= 8:
		core_surf = BRIGHT_FLOAT
	elif obsidian:
		core_surf = CRYSTAL_ORB
	m.orb(orb_radius, 20, 8, orb, core_surf)
	if level >= 4:
		Parts.torus(m, orb_radius + 0.16, 0.035, 20, 10, orb - Vector3(0, 0.035, 0),
			GOLD if p.tier >= Parts.Tier.GOLD else SHELL_MID, Vector3(18, 0, 10))
	# A hologram band round the orb, tilted off the axis it turns about, so it wobbles as it turns.
	# The arm tips sit lower round a bigger orb, so the tilt grows with the level and the band's
	# lowest edge stays above them all the way round.
	var halo := p.moving(orb, Motion.spin(Vector3.UP, 1.1))
	var lean := Vector3(8.0 + 4.0 * level, 0, 0)
	halo.ring(orb_radius + 0.28, orb_radius + 0.3, 0.1, 20, LowPolyMesh.turn(Vector3(0, -0.05, 0), lean),
		VIOLET_HOLO if obsidian else ION_HOLO, lean)
	if level < 5:
		return
	# The field ring round the orb's equator, outside the band's sweep: cyan, violet from the
	# Obsidian tier, a gold one outside it at the Crown.
	Parts.torus(m, orb_radius + SHIELD_FIELD, 0.035, 24, 8, orb - Vector3(0, 0.035, 0),
		Parts.CORE_GLOW if obsidian else Parts.CYAN_STRIP)
	if level >= 6:
		_plinth_panels(m, 1.15, plinth)
		m.ring(0.9, 1.06, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
		for degrees: float in [15.0, 45.0, 135.0, 255.0]:
			Parts.dome_seam(m, 0.84, 0.55, Vector3(0, foot, 0), degrees, Parts.CORE_GLOW)
		for degrees: float in [15.0, 45.0, 75.0]:
			m.prism(0.07, 0.07, 0.05, 4, Parts.around(0.98, degrees + 5.0, top), INLAY.phased(degrees / 90.0),
				Vector3(90, 85.0 - degrees, 0))
	if level >= 7:
		var ring := p.moving(orb - Vector3(0, SHIELD_RING_DROP, 0), Motion.spin(Vector3.UP, 0.5))
		_hover_ring(ring, orb_radius + SHIELD_RING, orb_radius + SHIELD_RING + 0.14, p.tier)
	if level >= 8:
		_plinth_filigree(m, 1.15)
		m.ring(0.96, 1.08, 0.02, 8, Vector3(0, top, 0), Parts.FILIGREE, Parts.OCTAGON)
		Parts.torus(m, orb_radius + SHIELD_FIELD + 0.09, 0.03, 24, 8, orb - Vector3(0, 0.03, 0), Parts.GOLD_ROUND)
		# The gold halo floating over the orb, bobbing with it.
		Parts.torus(m, 0.3, 0.05, 20, 8, orb + Vector3(0, orb_radius + 0.1, 0), HALO_GOLD)


## The head stands high on a bell mount that keeps growing taller every level: to L6 a red
## carriage (the tier's plate from L5) between armour packs, cream to the Gold tier and red above,
## with fat barrels angled 50 degrees up, one a side and two a side from L3, each with a muzzle
## brake (gold from the Gold tier), and a big radar on a fat mast beside it. L5 (Chrome): chrome
## plinth, mount, carriage and barrels, and a glowing cyan ammo belt feeding the carriage from
## the crate. L6 a second crate on the near corner with its belt into the near armour pack, and a
## bigger chrome radar. L7 (Obsidian): a taller plinth with glowing violet vein panels on its faces the
## camera sees, the mount and carriage obsidian veined violet, four barrels a side in two rows of
## two tipped with violet crystal shells, the belts violet, and a targeting ring hovering over the
## guns, turning.
## L8 (Crown): gold filigree round the plinth and the mount, the antimatter core glowing round the
## mount's foot and in a gold housing on its near side, and a gold crown on the radar.
static func build_flak_cannon(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.35 if level < 7 else (0.55 if level < 8 else 0.6)
	var top := _plinth(m, 3, 1.15, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var rise := FLAK_RISE + 0.12 * level
	m.lathe(PackedVector2Array([
		Vector2(0.62, 0), Vector2(0.62, 0.12), Vector2(0.4, 0.26), Vector2(0.3, rise), Vector2(0, rise),
	]), 20, Vector3(0, top, 0), _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var deck := top + rise
	if level >= 2:
		for degrees: float in [45.0, 225.0, 315.0]:
			Parts.pipe_run(m, PackedVector3Array([Parts.around(0.95, degrees, top), Parts.around(0.34, degrees, deck - 0.05)]),
				0.07, Parts.GUNMETAL)
	_crate(m, Parts.around(1.42, 315.0, Parts.PAD_HEIGHT))
	var yaw := 120.0
	var heading := Vector3(0, yaw, 0)
	# To L6 two fat barrels, or four, angled 50 degrees up; from L7 the quad's thinner barrels.
	var fat := level < 7
	var tilt := Vector3(40.0 if fat else 38.0, yaw, 0)
	var centre := Vector3(0, deck, 0)
	Parts.drum(m, 0.44, 0.1, 0.03, 20, centre, Parts.GUNMETAL)
	# The carriage: red to the Gold tier, between cream armour packs; the tier's plate above, between
	# red ones.
	m.box_chamfered(Vector3(0.66, 0.54, 0.8), 0.07, centre + Vector3(0, 0.1, 0), _by_tier(p.tier, ARMOUR, Parts.CHROME, Parts.OBSIDIAN),
		heading)
	m.box(Vector3(0.36, 0.05, 0.02), _at(centre, Vector3(0, 0.5, 0.401), heading), _by_tier(p.tier, ION, LASER, LASER), heading)
	if level >= 4:
		m.box_chamfered(Vector3(0.7, 0.07, 0.84), 0.02, centre + Vector3(0, 0.56, 0),
			GOLD if p.tier >= Parts.Tier.GOLD else Parts.HULL_MID, heading)
	var per_side := 1 if level < 3 else (2 if level < 7 else 4)
	# From L7 the four barrels a side stand in two rows of two, so the quad shows.
	var columns := per_side if level < 7 else 2
	var rows := 1 if level < 7 else 2
	var bore := FLAK_BORE if fat else 0.06
	var spacing := 2.0 * FLAK_BRAKE + 0.02 if fat else 0.13
	var pack := 0.08 + spacing * columns
	var first := 0.37 + spacing * 0.5 if fat else 0.41
	# The barrels recoil together, kicking back `kick` from where they rest and easing out again;
	# their muzzles blink and flare. The recoil takes BLINK's period, 1.2 s, at phase 0, and both
	# run on the one animation clock (Motion.clock(), the shaders' anim_time), so each muzzle
	# flashes on its barrel's kick.
	var along := LowPolyMesh.turn(Vector3.UP, tilt)
	var kick := 0.06
	var guns := p.moving(centre, Motion.slide(-along, kick, 1.2, 0.0, Motion.Ease.RECOIL))
	var breech := -along * kick
	var flare := 0
	var barrel := BARREL if p.tier < Parts.Tier.CHROME else Parts.CHROME_ROUND
	var shell := LASER_BLINK if level < 7 else CRYSTAL_BLINK
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(pack, 0.38 + FLAK_ROW * (rows - 1), 0.56), 0.04,
			_at(centre, Vector3(side * (0.33 + pack * 0.5), 0.12, 0), heading), _by_tier(p.tier, SHELL, ARMOUR, ARMOUR), heading)
		for k: int in per_side:
			var root := _at(breech, Vector3(side * (first + spacing * (k % columns)), 0.4 + FLAK_ROW * (k / columns), 0.05),
				heading)
			var length := 1.05
			guns.prism(bore, bore, length, 16, root, barrel, tilt)
			# A muzzle brake: gunmetal, gold from the Gold tier.
			var brake := GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL
			if fat:
				guns.tube(bore * 0.5, FLAK_BRAKE, 0.2, 16, _at(root, Vector3(0, length - 0.16, 0), tilt), brake, tilt)
			else:
				guns.tube(0.04, 0.085, 0.16, 16, _at(root, Vector3(0, length - 0.12, 0), tilt), brake, tilt)
			guns.orb(bore * 0.85, 12, 6, _at(root, Vector3(0, length + 0.05, 0), tilt), shell)
			guns.cone(bore, bore * 2.6, 8, _at(root, Vector3(0, length + 0.08, 0), tilt),
				FLARE.phased(flare / (2.0 * per_side)), tilt)
			flare += 1
		if level >= 3:
			m.prism(0.18, 0.18, 0.2, 16, _at(centre, Vector3(side * (0.33 + pack), 0.22, -0.12), heading),
				SHELL_MID, heading + Vector3(0, 0, -90 * side))
	var mast_foot := Parts.around(0.92, 135.0, top)
	var mast := deck + 0.45 - top + FLAK_RADAR_RAISE
	_mast(m, mast_foot, mast, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.CHROME_ROUND))
	var radar := p.moving(mast_foot + Vector3(0, mast, 0), Motion.spin(Vector3.UP, Parts.DISH_RATE))
	var face := Vector3(70, 0, 0)
	var dish := 1.5 if level < 6 else 1.8
	radar.lathe(PackedVector2Array([
		Vector2(0.06, 0) * dish, Vector2(0.32, 0.1) * dish, Vector2(0.3, 0.13) * dish, Vector2(0, 0.04) * dish,
	]), 24, Vector3(0, 0.12, -0.08), _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.CHROME_ROUND), face)
	radar.prism(0.05, 0.05, 0.14, 16, Vector3.ZERO, Parts.GUNMETAL)
	var feed := Vector3(0, 0.12, 0) + LowPolyMesh.turn(Vector3(0, 0.25 * dish, 0), face)
	# A short gunmetal strut holds the feed out over the dish's face.
	radar.strut(Vector3(0, 0.12, -0.08) + LowPolyMesh.turn(Vector3(0, 0.08 * dish, 0), face), feed, 0.04, Parts.GUNMETAL)
	radar.orb(0.05 * dish, 12, 6, feed, LASER_PULSE)
	if level < 5:
		return
	# Glowing ammo belts feeding the guns from the crates: cyan, violet from the Obsidian tier.
	var belt := VIOLET_CURRENT if p.tier >= Parts.Tier.OBSIDIAN else ION_CURRENT
	_belt(m, Parts.around(1.42, 315.0, Parts.PAD_HEIGHT + 0.32), Parts.around(0.98, 330.0, top + 0.1),
		_at(centre, Vector3(0, 0.18, 0.4), heading), belt)
	if level >= 6:
		_crate(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT))
		_belt(m, Parts.around(1.42, 45.0, Parts.PAD_HEIGHT + 0.32), Parts.around(0.98, 55.0, top + 0.1),
			_at(centre, Vector3(-(0.33 + pack), 0.24, 0), heading), belt)
	if level >= 7:
		_plinth_panels(m, 1.15, plinth)
		# Veins on the carriage's side and up the mount's neck, where the camera sees them.
		m.box(Vector3(0.02, 0.34, 0.6), _at(centre, Vector3(-0.34, 0.2, 0), heading), VEIN_PANEL, heading)
		var low := 0.32
		var high := rise - 0.1
		m.lathe(PackedVector2Array([Vector2(_neck(low, rise) + 0.012, low), Vector2(_neck(high, rise) + 0.012, high)]), 20,
			Vector3(0, top, 0), VEIN_PANEL, Vector3.ZERO, -30.0, 120.0)
		var ring := p.moving(Vector3(0, deck + FLAK_RING_LIFT, 0), Motion.spin(Vector3.UP, 0.7))
		_hover_ring(ring, 0.36, 0.48, p.tier)
	if level >= 8:
		_plinth_filigree(m, 1.15)
		m.ring(0.6, 0.64, 0.1, 20, Vector3(0, top + 0.04, 0), Parts.FILIGREE)
		# The antimatter core round the mount's foot and in a gold housing on its near side.
		Parts.torus(m, 0.52, 0.06, 20, 8, Vector3(0, top + 0.12, 0), Parts.CORE_GLOW)
		var housing := Parts.around(0.86, 15.0, top)
		m.box_chamfered(Vector3(0.3, 0.16, 0.3), 0.04, housing, Parts.GOLD_TRIM, Vector3(0, 75, 0))
		m.orb(0.15, 16, 6, housing + Vector3(0, 0.26, 0), Parts.CORE_GLOW)
		_crown(m, mast_foot + Vector3(0, mast - 0.2, 0), 0.13, 5)


## A glowing ammo belt from a crate's lid `from` over the plinth's edge at `over` to `to` on the
## guns: a pipe of `surf` (a current running towards the guns), its ends tucked in.
static func _belt(m: LowPolyMesh, from: Vector3, over: Vector3, to: Vector3, surf: Surf) -> void:
	Parts.pipe_run(m, PackedVector3Array([from + Vector3(0, 0.04, 0), over, to]), 0.065, surf, 10)


## The radius of the flak cannon's bell mount, `rise` tall, at height `h` up its neck (from 0.26).
static func _neck(h: float, rise: float) -> float:
	return lerpf(0.4, 0.3, (h - 0.26) / (rise - 0.26))


## From L5 the coil stands taller every level, more insulator skirts up it, and the twin coils
## grow. L5 (Chrome): chrome plinth, drum and skirts, a cyan crest along the gold corona and on the
## twin's, a cyan band round the drum. L6 a second twin coil on the right, in the third cell's
## place, its own arc to the sphere. L7 (Obsidian): a taller plinth with glowing violet vein panels
## on its faces the camera sees, the drum and skirts obsidian with a violet band round every second
## skirt's lip, crystal crests on the coronas, the arcs between the coils violet, and a discharge
## ring hovering round the sphere, turning. L8 (Crown): gold filigree round the plinth and the same
## skirts' lips, and the sphere the antimatter core in a gold corona ring.
static func build_arc_tower(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.3 if level < 5 else float(ARC_PLINTHS[level - 5])
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var plate := _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	var skirt := _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	var top := _plinth(m, 3, 1.1, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	Parts.drum(m, 0.62, 0.24, 0.06, 20, Vector3(0, top, 0), plate)
	var height := 0.85 + 0.2 * mini(level, 3) if level < 5 else float(ARC_HEIGHTS[level - 5])
	var foot := Vector3(0, top + 0.24, 0)
	var crown := _coil(m, foot, height, 0.5, p.tier >= Parts.Tier.GOLD, skirt)
	var sphere := 0.28 + 0.03 * level
	var centre := crown + Vector3(0, sphere * 0.85, 0)
	m.orb(sphere, 16, 8, centre, BRIGHT_CORE if level >= 8 else ARC_PULSE)
	# Arcs climb the coil from skirt to skirt on the side facing the viewer, then leap from the
	# corona to the sphere. From L5 they zigzag over the front, so the taller coil's arcs show.
	var skirts := _skirts(height)
	var strip := 0
	for i: int in skirts - 1:
		var degrees := 20.0 + 32.0 * (i if level < 5 else i % 3)
		Parts.arc(m, foot + _skirt_rim(height, 0.5, i, degrees), foot + _skirt_rim(height, 0.5, i + 1, degrees + 28.0),
			3, 0.04, ARC_SPARK.phased(strip / 6.0))
		strip += 1
	for degrees: float in [30.0, 95.0]:
		Parts.arc(m, crown + Parts.around(0.48, degrees, 0.06),
			centre + Parts.on_sphere(sphere - 0.02, Vector2(degrees + 15.0, 38.0)), 3, 0.04, ARC_SPARK.phased(strip / 6.0))
		strip += 1
	if level >= 2:
		for k: int in 4:
			var root := crown + Parts.around(0.42, 90.0 * k, 0.0)
			var tip := crown + Parts.around(0.66, 90.0 * k, -0.08)
			m.prism(0.025, 0.015, root.distance_to(tip), 8, root, Parts.ROD, Parts.facing(tip - root))
			m.orb(0.05, 8, 4, tip, ARC_BLINK.phased(Parts.chase(k, 4)))
	if level >= 3:
		var cells: Array[float] = [45.0, 225.0, 315.0]
		if level >= 6:
			cells = [45.0, 225.0]
		for k: int in cells.size():
			_cell(m, Parts.around(1.42, cells[k], Parts.PAD_HEIGHT), 0.42, ARC_PULSE.phased(0.25 + k / 3.0))
	# The crest along a corona: cyan from the Chrome tier, violet crystal from the Obsidian tier.
	var crest := FOCUS if obsidian else Parts.CYAN_STRIP
	if level >= 4:
		var twins: Array[float] = [135.0]
		if level >= 6:
			twins.append(315.0)
		var twin_height := 0.85 if level < 5 else float(ARC_TWINS[level - 5])
		for k: int in twins.size():
			var twin := Parts.around(1.38, twins[k], Parts.PAD_HEIGHT)
			Parts.drum(m, 0.26, 0.16, 0.04, 16, twin, plate)
			var twin_crown := _coil(m, twin + Vector3(0, 0.16, 0), twin_height, 0.26, true, skirt)
			var twin_centre := twin_crown + Vector3(0, 0.17, 0)
			m.orb(0.2, 16, 8, twin_centre, ARC_PULSE.phased(0.5 + 0.25 * k))
			# An arc jumps between the twin spheres.
			var jump := (centre - twin_centre).normalized()
			Parts.arc(m, twin_centre + jump * 0.18, centre - jump * (sphere - 0.02), 6 if level < 5 else 8, 0.07,
				(VIOLET_ARC if obsidian else ARC_SPARK).phased(0.95 - 0.4 * k))
			if level >= 5:
				Parts.torus(m, 0.2, 0.025, 12, 4, twin_crown + Vector3(0, 0.01, 0), crest)
	if level < 5:
		return
	Parts.torus(m, 0.4, 0.03, 20, 6, crown + Vector3(0, 0.05, 0), crest)
	# Round the drum, a glowing band over a red armour band: outer walls only, the drum behind them.
	m.lathe(PackedVector2Array([Vector2(0.632, 0), Vector2(0.632, 0.06)]), 20, Vector3(0, top + 0.1, 0),
		Parts.VEINS if obsidian else Parts.CYAN_STRIP)
	m.lathe(PackedVector2Array([Vector2(0.635, 0), Vector2(0.635, 0.07)]), 20, Vector3(0, top + 0.01, 0), ARMOUR_ROUND)
	if level >= 7:
		_plinth_panels(m, 1.1, plinth)
		# A violet band round every second skirt's lip (gold filigree at the Crown): a band on each
		# would stripe the tall coil busily.
		for i: int in range(0, skirts, 2):
			var t := float(i) / skirts
			var rim := lerpf(0.5, 0.31, t)
			m.lathe(PackedVector2Array([Vector2(rim + 0.012, 0), Vector2(rim + 0.012, 0.04)]), 16,
				foot + Vector3(0, height * t + 0.065, 0), Parts.FILIGREE if level >= 8 else Parts.CORE_GLOW)
		var ring := p.moving(centre - Vector3(0, 0.035, 0), Motion.spin(Vector3.UP, 0.7))
		_hover_ring(ring, sphere + ARC_RING, sphere + ARC_RING + 0.14, p.tier)
	if level >= 8:
		_plinth_filigree(m, 1.1)
		Parts.torus(m, sphere - 0.01, 0.035, 20, 6, centre - Vector3(0, 0.035, 0), Parts.GOLD_ROUND)


## A tall hex pod with a red lens eye on the face towards the camera, a red band round it and a
## glowing cyan ring round its foot. From L4 an armoured hex skirt lifts the pod higher every
## level. L4 (Chrome): a chrome skirt
## banded in defence red, a chrome lid and gun heads with chrome barrels, cyan seams up the pod's
## corners the camera sees and round its shoulder, and a cyan cloak shimmering over the pod's
## walls (a hologram). L5 a broad chrome mantlet bridging the gun heads, its front edge and a
## sensor dome on it glowing cyan, and twin, longer barrels on each gun. L6 (Obsidian): an obsidian pod, skirt, lid, heads and
## mantlet, glowing violet vein panels on the shoulder and the skirt the camera sees, veins round
## the lid, violet crystal sights, the cloak and the mantlet's edge and dome violet, and a cloak ring
## hovering round the pod, turning. L7 (Crown): gold filigree round the lid and the skirt, the
## antimatter core glowing in the sights, one gold crown on a stem on the lid behind the guns
## holding the core up where the camera sees it.
static func build_cloaked_sentry(p: Parts, level: int) -> void:
	var m := p.body
	Parts.foundation(m, 2)
	var rise := 0.0 if level < 4 else float(SENTRY_RISES[level - 4])
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var base := Vector3(0, Parts.PAD_HEIGHT + rise, 0)
	if level >= 4:
		# The armoured hex skirt the pod stands on, banded in defence red.
		var ground := Vector3(0, Parts.PAD_HEIGHT, 0)
		m.lathe(PackedVector2Array([Vector2(0.78, 0), Vector2(0.78, rise - 0.03), Vector2(0.75, rise), Vector2(0, rise)]), 6,
			ground, _by_tier(p.tier, POD, Parts.CHROME, Parts.OBSIDIAN))
		m.lathe(PackedVector2Array([Vector2(0.79, 0), Vector2(0.79, 0.05)]), 6, ground + Vector3(0, rise * 0.4 - 0.025, 0), ARMOUR)
	# The shimmer ring round the pod's foot: a steady cyan glow, so it shows in build mode too.
	Parts.torus(m, 0.83, 0.04, 6, 8, base, ION_PULSE)
	var pod := POD if level < 6 else Parts.OBSIDIAN
	var top := SENTRY_POD
	m.lathe(PackedVector2Array([
		Vector2(0.74, 0), Vector2(0.74, top - 0.14), Vector2(0.58, top), Vector2(0, top),
	]), 6, base, pod)
	m.ring(0.72, 0.77, 0.1, 6, base + Vector3(0, 0.1, 0), ARMOUR)
	for degrees: float in [30.0, 90.0]:
		m.box_chamfered(Vector3(0.36, 0.1, 0.03), 0.01, Parts.around(0.65, degrees, base.y + 0.07), VENT,
			Vector3(0, 90.0 - degrees, 0))
	# The red lens eye on the face towards the camera.
	var eye := Parts.around(1.0, 30.0, 0.0)
	m.dome(SENTRY_EYE, 0.05, 12, 3, eye * 0.645 + base + Vector3(0, 0.28, 0), LASER_PULSE, Parts.facing(eye))
	Parts.drum(m, 0.44, 0.05, 0.02, 6, base + Vector3(0, top, 0), _by_tier(p.tier, Parts.HULL_DARK, Parts.CHROME, Parts.OBSIDIAN))
	if level >= 3:
		m.ring(0.43, 0.47, 0.1, 6, base + Vector3(0, top - 0.04, 0), GOLD if p.tier >= Parts.Tier.GOLD else Parts.HULL_DARK)
	# The lid gun scans, turning about the pod's axis.
	var lid := p.moving(base + Vector3(0, top + 0.05, 0), Motion.swing(Vector3.UP, 30.0, 5.0))
	var guns: Array[float] = [0.0]
	if level >= 2:
		guns = [-0.17, 0.17]
	var yaw := SCREEN_RIGHT - 30.0
	for offset: float in guns:
		_sentry_gun(lid, LowPolyMesh.turn(Vector3(offset, 0, 0), Vector3(0, yaw, 0)), yaw, level, p.tier)
	if level >= 5:
		# A broad armoured mantlet bridging the two gun heads, its front edge and a sensor dome on it
		# lit (cyan, violet from the Obsidian tier).
		var heading := Vector3(0, yaw, 0)
		lid.box_chamfered(SENTRY_MANTLET, 0.03, Vector3(0, 0.17, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME, Parts.OBSIDIAN),
			heading)
		var lit := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
		lid.box(Vector3(SENTRY_MANTLET.x - 0.08, 0.04, 0.02), LowPolyMesh.turn(Vector3(0, 0.19, SENTRY_MANTLET.z * 0.5 + 0.005), heading),
			lit, heading)
		# A glowing sensor dome on top, the step that reads from across the base.
		lid.dome(0.13, 0.1, 16, 4, Vector3(0, 0.17 + SENTRY_MANTLET.y, 0), lit)
	if level >= 7:
		# One gold crown on a stem behind the guns, holding the antimatter core up where the camera
		# sees it.
		var stem := LowPolyMesh.turn(Vector3(0, 0, -SENTRY_CROWN_BACK), Vector3(0, yaw, 0))
		lid.prism(0.04, 0.035, 0.2, 8, stem, Parts.GOLD_ROUND)
		_crown(lid, stem + Vector3(0, 0.2, 0), 0.14, 6, 0.14)
		lid.orb(0.15, 16, 6, stem + Vector3(0, 0.33, 0), BRIGHT_CORE)
	# The lamp and the mast stand near the lid's rim, outside the guns' sweep: past the heads'
	# reach (0.35 from the axis) and away from the barrels' arc in front.
	Parts.drum(m, 0.05, 0.14, 0.02, 16, base + Parts.around(0.525, 225.0, top), Parts.GUNMETAL)
	m.orb(0.05, 12, 6, base + Parts.around(0.525, 225.0, top + 0.18), LASER_BLINK)
	if level >= 2:
		m.ring(0.6, 0.64, 0.04, 6, base + Vector3(0, top + 0.02, 0), SHIMMER.phased(0.5))
	if level >= 3:
		_lamp_post(m, base + Parts.around(0.525, 165.0, top), 0.32, LASER_BLINK.phased(0.5))
	if level < 4:
		return
	# Glowing seams up the pod's corners the camera sees and round its shoulder (cyan, violet from
	# the Obsidian tier), and the cloak shimmering over its walls.
	var seam := Parts.CORE_GLOW if obsidian else Parts.CYAN_STRIP
	for degrees: float in [0.0, 60.0]:
		m.box(Vector3(0.03, top - 0.17, 0.03), Parts.around(0.745, degrees, base.y + 0.02), seam, Vector3(0, 90.0 - degrees, 0))
	m.lathe(PackedVector2Array([Vector2(0.748, 0), Vector2(0.748, 0.03)]), 6, base + Vector3(0, top - 0.17, 0), seam)
	m.lathe(PackedVector2Array([Vector2(0.8, 0.0), Vector2(0.8, top - 0.12), Vector2(0.63, top + 0.03)]), 6, base,
		VIOLET_HOLO if obsidian else SHIMMER.phased(0.25))
	if level >= 6:
		# Vein panels on the shoulder's and the skirt's faces the camera sees, veins round the lid.
		m.lathe(PackedVector2Array([Vector2(0.75, top - 0.135), Vector2(0.59, top + 0.005)]), 6, base, VEIN_PANEL, Vector3.ZERO, 0.0,
			120.0)
		for degrees: float in [30.0, 90.0]:
			m.box(Vector3(0.5, rise * 0.4 - 0.07, 0.02), Parts.around(0.68, degrees, Parts.PAD_HEIGHT + 0.03), VEIN_PANEL,
				Vector3(0, 90.0 - degrees, 0))
		m.lathe(PackedVector2Array([Vector2(0.445, 0), Vector2(0.445, 0.03)]), 6, base + Vector3(0, top, 0), Parts.VEINS)
		var ring := p.moving(base + Vector3(0, SENTRY_RING_LIFT, 0), Motion.spin(Vector3.UP, 0.6))
		_hover_ring(ring, SENTRY_RING_INNER, SENTRY_RING_OUTER, p.tier)
	if level >= 7:
		m.lathe(PackedVector2Array([Vector2(0.475, 0), Vector2(0.475, 0.1)]), 6, base + Vector3(0, top - 0.035, 0), Parts.FILIGREE)
		m.lathe(PackedVector2Array([Vector2(0.785, 0), Vector2(0.785, 0.1)]), 6,
			Vector3(0, Parts.PAD_HEIGHT + rise - 0.14, 0), Parts.FILIGREE)


## A red-rimmed well with its violet core floating high over it in fat gyro rings. From L4 the core
## floats higher over the well every level, the pillars growing with it and a
## housing ring joining them low over the well. L4 (Chrome): chrome plinth, well, pillars and
## housing, cyan strips up the pillars, a red armour band round the housing, the first gyro ring
## glowing cyan and the rotor chrome. L5 (Obsidian): a taller plinth with glowing violet vein
## panels on its faces the camera sees, the well, pillars and housing obsidian, violet strips up the
## pillars and veins round the housing, a bigger pink crystal core held still in the gyro rings,
## and a gyro ring hovering round the pillars, turning with the rotor. L6 (Crown): gold filigree
## round the plinth and the housing, the core the antimatter core, bigger again and still, the gyro
## rings and the rotor gold.
static func build_gravity_well(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.22 if level < 4 else float(WELL_PLINTHS[level - 4])
	var lift := 0.0 if level < 4 else float(WELL_LIFTS[level - 4])
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var top := _plinth(m, 2, 0.8, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	# The well's rim, a fat red ring at every tier.
	Parts.torus(m, 0.5, 0.08, 16, 10, Vector3(0, top, 0), ARMOUR_ROUND)
	m.disc(0.44, 20, Vector3(0, top + 0.01, 0), SWIRL)
	var core := Vector3(0, top + WELL_FLOAT + lift, 0)
	var pillar := WELL_FLOAT + 0.12 + lift
	var pillar_surf := _by_tier(p.tier, SHELL_MID, Parts.CHROME, Parts.OBSIDIAN)
	for k: int in 3:
		var degrees := 30.0 + 120.0 * k
		var foot := Parts.around(0.66, degrees, top)
		m.box_chamfered(Vector3(0.14, pillar, 0.18), 0.04, foot, pillar_surf, Vector3(0, 90.0 - degrees, 0))
		m.box_chamfered(Vector3(0.1, 0.08, 0.12), 0.02, foot + Vector3(0, pillar, 0), PLASMA_BLINK.phased(Parts.chase(k, 3)),
			Vector3(0, 90.0 - degrees, 0))
		if level >= 4:
			# A strip up the pillar's outer face: cyan, violet from the Obsidian tier.
			m.box(Vector3(0.07, pillar - 0.36, 0.02), Parts.around(0.755, degrees, top + 0.08),
				Parts.CORE_GLOW if obsidian else Parts.CYAN_STRIP, Vector3(0, 90.0 - degrees, 0))
	var core_surf := CORE
	var core_radius := WELL_CORE
	if level >= 4:
		core_radius = WELL_CORES[level - 4]
		core_surf = BRIGHT_CORE if crown else (CRYSTAL_CORE if obsidian else CORE)
	m.orb(core_radius, 12 if level < 4 else 16, 6, core, core_surf)
	if level >= 4:
		# The housing ring joining the pillars low over the well, under the core, so the core shows
		# over it; a red armour band round it.
		var housing := Vector3(0, top + 0.2, 0)
		m.ring(0.56, 0.76, 0.1, 24, housing, _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
		m.lathe(PackedVector2Array([Vector2(0.765, 0), Vector2(0.765, 0.05)]), 24, housing + Vector3(0, 0.025, 0),
			Parts.FILIGREE if crown else (Parts.VEINS if obsidian else ARMOUR_ROUND))
	# The gyro rings tumble about the core: each lies across the axis it turns about.
	var gold := GOLD if p.tier >= Parts.Tier.GOLD else SHELL
	if level >= 2:
		var first := SHELL
		if level >= 4:
			first = GOLD if crown else Parts.CYAN_STRIP
		_gyro(p.moving(core, Motion.spin(Vector3.RIGHT, 1.3)), Vector3.ZERO, 0.49, WELL_GYRO, Vector3(62, 0, 0), first)
	if level >= 3:
		_gyro(p.moving(core, Motion.spin(Vector3.BACK, -0.9)), Vector3.ZERO, 0.37, WELL_GYRO, Vector3(0, 0, -35), gold)
	var rotor := p.moving(core + Vector3(0, WELL_ROTOR, 0), Motion.spin(Vector3.UP, 1.5))
	var rotor_surf := SHELL
	if level >= 4:
		rotor_surf = GOLD if crown else _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND)
	Parts.torus(rotor, 0.42, 0.05, 16, 10, Vector3(0, -0.05, 0), rotor_surf)
	Parts.drum(rotor, 0.1, 0.1, 0.03, 16, Vector3(0, -0.05, 0), Parts.GUNMETAL)
	for k: int in 3:
		var degrees := 120.0 * k
		rotor.box_chamfered(Vector3(0.36, 0.04, 0.09), 0.015, Parts.around(0.24, degrees, -0.02), SHELL_MID,
			Vector3(0, -degrees, 0))
		rotor.box_chamfered(Vector3(0.1, 0.06, 0.1), 0.02, Parts.around(0.42, degrees, 0.04), PLASMA, Vector3(0, -degrees, 0))
	if level < 5:
		return
	_plinth_panels(m, 0.8, plinth)
	m.ring(0.6, 0.72, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
	# The gyro ring hovering round the pillars at their middle, turning with the rotor.
	var ring_y := -WELL_ROTOR - WELL_RING_DROP
	rotor.ring(WELL_RING_INNER, WELL_RING_OUTER, 0.07, 24, Vector3(0, ring_y, 0), HOVER)
	rotor.lathe(PackedVector2Array([Vector2(WELL_RING_OUTER - 0.02, 0.072), Vector2(WELL_RING_INNER + 0.02, 0.072)]), 24,
		Vector3(0, ring_y, 0), HOVER_RIM)
	rotor.lathe(PackedVector2Array([Vector2(WELL_RING_OUTER + 0.006, 0.006), Vector2(WELL_RING_OUTER + 0.006, 0.064)]), 24,
		Vector3(0, ring_y, 0), HOVER_GOLD if crown else HOVER_VEINS)
	for k: int in 3:
		rotor.box(Vector3(0.06, 0.05, 0.12), Parts.around(WELL_RING_INNER - 0.02, 60.0 + 120.0 * k, ring_y + 0.01), HOVER_SIGHT,
			Vector3(0, 30.0 - 120.0 * k, 0))
	if level >= 6:
		_plinth_filigree(m, 0.8)
		m.ring(0.64, 0.76, 0.02, 8, Vector3(0, top, 0), Parts.FILIGREE, Parts.OCTAGON)


## From L4 the tower gains a storey between its blocks, taller every level, and its capacitor
## stacks a third can. L4 (Chrome): chrome plinth, blocks, storey and cans, the cans' bands
## blinking cyan in their chase, a cyan band round each stack's foot and round the storey's top,
## red armour plates on the storey's corners. L5 (Obsidian): a taller plinth with glowing violet
## vein panels on its faces the camera sees, the tower and the cans obsidian with vein panels on
## the faces the camera sees, the bands violet crystal, crystal tips on the cans, and a pulse ring
## hovering round the tower's neck under the cage, turning. L6 (Crown): gold filigree round the plinth and the storey, the
## core the antimatter core under a gold crown on the cage's ring, and the pulse ring violet and
## gold.
static func build_emp_tower(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.3 if level < 4 else float(EMP_PLINTHS[level - 4])
	var rise := 0.0 if level < 4 else float(EMP_RISES[level - 4])
	var obsidian := p.tier >= Parts.Tier.OBSIDIAN
	var crown := p.tier >= Parts.Tier.CROWN
	var top := _plinth(m, 3, 1.2, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var block := _by_tier(p.tier, Parts.HULL_LIGHT, Parts.CHROME, Parts.OBSIDIAN)
	m.box_chamfered(Vector3(0.9, 0.56, 0.9), 0.07, Vector3(0, top, 0), block)
	m.box_chamfered(Vector3(0.94, 0.12, 0.94), 0.03, Vector3(0, top + 0.38, 0), HAZARD_FINE)
	if level >= 4:
		# The storey between the blocks, red armour plates on its corners and a glowing band round
		# its top.
		m.box_chamfered(Vector3(0.82, rise, 0.82), 0.06, Vector3(0, top + 0.56, 0), block)
		for k: int in 4:
			m.box_chamfered(Vector3(0.12, rise - 0.1, 0.12), 0.03, Parts.around(0.56, 45.0 + 90.0 * k, top + 0.61), ARMOUR,
				Vector3(0, 45.0 - 90.0 * k, 0))
		m.box(Vector3(0.84, 0.05, 0.84), Vector3(0, top + 0.56 + rise - 0.1, 0), Parts.CORE_GLOW if obsidian else Parts.CYAN_STRIP)
	m.box_chamfered(Vector3(0.72, 0.5, 0.72), 0.06, Vector3(0, top + 0.56 + rise, 0), block)
	m.box_chamfered(Vector3(0.74, 0.16, 0.04), 0.01, Vector3(0, top + 0.16, 0.45), VENT)
	var neck := top + 1.06 + rise
	Parts.drum(m, 0.28, 0.12, 0.04, 16, Vector3(0, neck, 0), SHELL_MID)
	var cage := Vector3(0, neck + 0.12, 0)
	Parts.drum(m, 0.46, 0.08, 0.02, 16, cage, Parts.GUNMETAL)
	# The core grows to L4's 0.34, where the cage's bars (at 0.4) still show round it.
	m.orb(0.22 + 0.03 * mini(level, 4), 16, 6, cage + Vector3(0, 0.34, 0), BRIGHT_FLOAT if crown else EMP_CORE)
	for k: int in 8:
		m.box(Vector3(0.05, 0.56, 0.05), Parts.around(0.4, 22.5 + 45.0 * k, cage.y + 0.08), Parts.ROD,
			Vector3(0, -22.5 - 45.0 * k, 0))
	# Arcs crackle from bar to bar on the side facing the viewer.
	for k: int in 3:
		var from := Parts.around(0.4, 337.5 + 45.0 * k, cage.y + (0.18 if k % 2 == 0 else 0.52))
		var to := Parts.around(0.4, 22.5 + 45.0 * k, cage.y + (0.52 if k % 2 == 0 else 0.18))
		Parts.arc(m, from, to, 3, 0.03, EMP_ARC.phased(k / 3.0))
	Parts.torus(m, 0.4, 0.05, 16, 10, cage + Vector3(0, 0.62, 0), GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL)
	m.dome(0.22, 0.12, 16, 6, cage + Vector3(0, 0.67, 0), SHELL_MID)
	Parts.mast(m, cage + Vector3(0, 0.78, 0), 0.22, 0.05, EMP_BLINK.phased(0.5))
	# The cans' bands blink in a chase round the ring: yellow, cyan from the Chrome tier, violet
	# crystal from the Obsidian tier.
	var cans: Array[float] = [135.0, 315.0]
	if level >= 2:
		cans = [45.0, 135.0, 225.0, 315.0]
	var blink := EMP_BLINK
	var ribbed := RIBBED
	if level >= 4:
		blink = CRYSTAL_BLINK if obsidian else ION_BLINK
		ribbed = OBSIDIAN_RIBBED if obsidian else CHROME_RIBBED
	for k: int in cans.size():
		var degrees := cans[k]
		var band := blink.phased(Parts.chase(k, cans.size()))
		var foot := Parts.around(0.94, degrees, top)
		var can_top := _capacitor(m, foot, 0.5, level < 3, band, ribbed)
		if level >= 3:
			can_top = _capacitor(m, can_top, 0.36, level < 4, band, ribbed)
		if level >= 4:
			can_top = _capacitor(m, can_top, 0.3, true, band, ribbed)
			m.lathe(PackedVector2Array([Vector2(0.205, 0), Vector2(0.205, 0.05)]), 16, foot + Vector3(0, 0.08, 0),
				Parts.VEINS if obsidian else Parts.CYAN_STRIP)
			if obsidian:
				m.cone(0.07, 0.16, 8, can_top, INLAY.phased(k / 4.0))
		Parts.pipe_run(m, PackedVector3Array([can_top, Parts.around(0.3, degrees, can_top.y)]), 0.035, Parts.GUNMETAL)
	if level < 5:
		return
	_plinth_panels(m, 1.2, plinth)
	# Vein panels on the tower's faces the camera sees (+X and +Z), the storey's and the upper block's.
	for face: float in [0.0, 90.0]:
		m.box(Vector3(0.5, rise - 0.3, 0.02), Parts.around(0.415, face, top + 0.68), VEIN_PANEL, Vector3(0, 90.0 - face, 0))
		m.box(Vector3(0.44, 0.3, 0.02), Parts.around(0.365, face, top + 0.66 + rise), VEIN_PANEL, Vector3(0, 90.0 - face, 0))
	var ring := p.moving(cage - Vector3(0, EMP_RING_DROP, 0), Motion.spin(Vector3.UP, 0.7))
	_hover_ring(ring, EMP_RING_INNER, EMP_RING_OUTER, p.tier)
	if level >= 6:
		_plinth_filigree(m, 1.2)
		m.box(Vector3(0.86, 0.04, 0.86), Vector3(0, top + 0.62, 0), Parts.FILIGREE)
		# The gold crown on the cage's ring, over the core.
		_crown(m, cage + Vector3(0, 0.68, 0), 0.44, 8, 0.16)


## A mount lifts the gun over its capacitor banks, higher each level: to L3 a red housing and a
## wide barrel, two cream rails on a gunmetal spine with the strip between them, three gunmetal
## collars and gold rail ends, and ribbed cream capacitors banded in cyan, a bank at L1, two at
## L2 and a rear row at L3. L4 (Chrome): chrome plinth, drum, mount, housing and slimmer rails,
## cyan strips along the rails, taller chrome capacitors and a longer barrel. L5
## a third bank on the plinth's front under the barrel, a taller mount and a broad band. L6
## (Obsidian): a taller plinth with glowing violet vein panels on its faces the camera sees, the
## drum, mount, housing and rails obsidian, veins up the mount, round the drum and across its top,
## and across the housing's top, crystal inlays on the plinth, the capacitors capped with violet
## crystals swelling in turn, and a targeting ring hovering over the gun, turning. L7 (Crown): gold
## filigree round the plinth, the mount and the barrel's collars, the breech the antimatter core
## glowing light violet in gold rings, and a gold crown on the muzzle.
static func build_railgun(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.34 if level < 4 else float(RAIL_PLINTHS[level - 4])
	var lift := float(RAIL_LIFTS_LOW[level - 1]) if level < 4 else float(RAIL_LIFTS[level - 4])
	# To L3 the barrel is wider: cream rails on a gunmetal spine, a red housing under it.
	var low := level < 4
	var glow := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	var top := _plinth(m, 3, 1.2, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	Parts.drum(m, 0.86, 0.14, 0.04, 24, Vector3(0, top, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var lower := Vector3(0, top + 0.14, 0)
	var deck := lower + Vector3(0, lift, 0)
	var heading := Vector3(0, SCREEN_RIGHT, 0)
	var aim := Vector3(-6, SCREEN_RIGHT, 0)
	var along := aim + Vector3(90, 0, 0)
	var foot := _at(lower, Vector3(0, 0, -0.3), heading)
	# The mount under the housing: a column flared at its foot, a red band round the flare and a
	# glowing band (cyan, violet from the Obsidian tier) under the gun, broad from L5.
	m.lathe(PackedVector2Array([Vector2(0.5, 0), Vector2(0.5, 0.05), Vector2(0.36, 0.15), Vector2(0.36, lift), Vector2(0, lift)]),
		24, foot, _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	m.ring(0.35, 0.4, 0.07, 24, foot + Vector3(0, 0.16, 0), ARMOUR_ROUND)
	var band := 0.08 if level < 5 else 0.16
	m.ring(0.35, 0.385, band, 24, foot + Vector3(0, lift - 0.04 - band, 0), glow)
	m.box_chamfered(Vector3(0.95, 0.46, 1.1), 0.08, _at(deck, Vector3(0, 0, -0.3), heading),
		_by_tier(p.tier, ARMOUR, Parts.CHROME, Parts.OBSIDIAN), heading)
	m.box_chamfered(Vector3(0.7, 0.3, 0.34), 0.05, _at(deck, Vector3(0, 0.46, -0.62), heading), VENT, heading)
	m.box(Vector3(0.36, 0.05, 0.02), _at(deck, Vector3(0, 0.6, -0.449), heading), ION, heading)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(0.05, 0.3, 0.8), 0.015, _at(deck, Vector3(side * 0.49, 0.08, -0.3), heading),
			_by_tier(p.tier, SHELL, ARMOUR, ARMOUR), heading)
	m.box_chamfered(Vector3(0.6, 0.06, 0.3), 0.02, _at(deck, Vector3(0, 0.46, 0.0), heading), HAZARD_FINE, heading)
	var length := 1.8 + 0.3 * mini(level, 4)
	var root := _at(deck, Vector3(0, 0.42, -1.0), heading)
	var rail := Vector3(RAIL_WIDE, 0.3, RAIL_WIDE + 0.02) if low else Vector3(0.14, 0.26, 0.16)
	var across := RAIL_WIDE * 0.5 + RAIL_GAP * 0.5 if low else 0.16
	if low:
		# The spine the two rails stand on, so they read as one barrel.
		m.box_chamfered(Vector3(RAIL_SPINE, RAIL_SPINE, length - 0.1), 0.04, _at(root, Vector3(0, -0.1, length * 0.5 - 0.05), aim),
			Parts.GUNMETAL, aim)
	for side: float in [-1.0, 1.0]:
		m.box_chamfered(Vector3(rail.x, rail.y, length), 0.04, _at(root, Vector3(side * across, 0, length * 0.5), aim),
			_by_tier(p.tier, Parts.HULL_LIGHT if low else Parts.GUNMETAL, Parts.CHROME, Parts.OBSIDIAN), aim)
		m.box_chamfered(Vector3(rail.z, rail.y + 0.02, 0.16), 0.04, _at(root, Vector3(side * across, -0.01, length - 0.08), aim),
			GOLD if p.tier >= Parts.Tier.GOLD else ARMOUR, aim)
		if level >= 4:
			# A light strip down the rail's outer face.
			m.box(Vector3(0.02, 0.08, length - 0.6), _at(root, Vector3(side * 0.24, 0.1, length * 0.5), aim), glow, aim)
	m.box(Vector3(RAIL_GAP if low else 0.14, 0.08, length - 0.5), _at(root, Vector3(0, 0.14 if low else 0.08, length * 0.5 + 0.15), aim),
		RAIL_CURRENT, aim)
	m.box(Vector3(0.16, 0.18, 0.06), _at(root, Vector3(0, 0.03, length - 0.06), aim), ION_PULSE, aim)
	# Three bold collars along the barrel, wider round the wider barrel to L3.
	var pitch := (length - 0.75) / 3.0 if low else 0.75
	var collar := Parts.FILIGREE if p.tier >= Parts.Tier.CROWN else _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME, Parts.OBSIDIAN)
	for i: int in 3:
		m.box_chamfered(Vector3(0.74, 0.44, 0.16) if low else Vector3(0.6, 0.4, 0.16), 0.03,
			_at(root, Vector3(0, -0.12 if low else -0.08, 0.75 + pitch * i), aim), collar, aim)
	# The banks stand on the drum either side of the mount (one at L1), the rear row on the plinth
	# behind it from L3, and from L5 a third bank on the plinth's front under the barrel: the charge
	# runs from the rear row through the banks to the front.
	for side: float in ([-1.0] if level < 2 else [-1.0, 1.0]):
		for k: int in 3:
			_rail_cell(m, _at(lower, Vector3(side * 0.66, 0, -0.62 + 0.3 * k), heading), RAIL_CAN, k + 1, p.tier)
	var rise := lower.y - top
	if level >= 3:
		for k: int in 3:
			_rail_cell(m, _at(Vector3(0, top, 0), Vector3(-0.28 + 0.28 * k, 0, -RAIL_ROW), heading), RAIL_CAN + rise, 0, p.tier)
	if level >= 5:
		for k: int in 3:
			_rail_cell(m, _at(Vector3(0, top, 0), Vector3(-0.3 + 0.3 * k, 0, RAIL_ROW), heading), RAIL_CAN + rise, 4, p.tier)
	if level < 6:
		return
	_plinth_panels(m, 1.2, plinth)
	# Veins round the plinth's top, up the mount on the side the camera sees, round the drum, across
	# its top round the mount and across the housing's top either side of the rails; crystal inlays
	# on the plinth.
	m.ring(0.88, 1.08, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
	m.lathe(PackedVector2Array([Vector2(0.372, 0.3), Vector2(0.372, lift - 0.26)]), 24, foot, VEIN_PANEL, Vector3.ZERO, -30.0, 120.0)
	m.ring(0.855, 0.875, 0.07, 24, Vector3(0, top + 0.03, 0), VEIN_PANEL)
	m.ring(0.5, 0.84, 0.012, 24, lower, VEIN_PANEL)
	for side: float in [-1.0, 1.0]:
		m.box(Vector3(0.18, 0.02, 0.6), _at(deck, Vector3(side * 0.36, 0.46, -0.1), heading), VEIN_PANEL, heading)
	for degrees: float in [15.0, 75.0]:
		m.prism(0.07, 0.07, 0.05, 4, Parts.around(1.0, degrees, top), INLAY.phased(degrees / 90.0), Vector3(90, 90.0 - degrees, 0))
	var ring_y := deck.y + RAIL_RING_LIFT
	var ring := p.moving(Vector3(0, ring_y, 0), Motion.spin(Vector3.UP, 0.6))
	_hover_ring(ring, 0.56, 0.7, p.tier)
	if level < 7:
		return
	_plinth_filigree(m, 1.2)
	m.ring(0.37, 0.39, 0.1, 24, foot + Vector3(0, 0.24, 0), Parts.FILIGREE)
	# The breech: the antimatter core glowing light violet behind the rails, in gold rings, where the
	# camera sees it; a gold crown on the muzzle.
	var breech := _at(root, Vector3(0, 0.13, -0.3), aim)
	m.prism(0.22, 0.22, 0.3, 20, breech, BRIGHT_CORE, along)
	m.dome(0.22, 0.12, 20, 3, breech, BRIGHT_CORE, aim + Vector3(-90, 0, 0))
	for k: int in 2:
		Parts.torus(m, 0.22, 0.035, 20, 8, _at(breech, Vector3(0, 0, 0.27 * k), aim), Parts.GOLD_ROUND, along)
	_crown(m, _at(root, Vector3(0, 0.26, length - 0.1), aim), 0.2, 5, 0.18)


## From L3 the emitter stands higher each level on a taller tripod. L3 (Chrome): chrome plinth,
## feet, housing and focusing rings, a chrome cowl behind the housing banded in cyan, the lens
## glowing cyan, the conduits brighter, and a ribbed chrome power cell on the near corner. L4
## (Obsidian): a taller plinth with glowing violet vein panels on its faces the camera sees, the
## housing, cowl, cell, feet and rings obsidian, the cowl's band violet, veins round the plinth's
## top, the conduits violet, crystal inlays on the feet, a crystal focusing array of three violet
## points round the lens and violet crystal studs on the rings. L5 a focus ring hovering round the
## beam, turning about it. L6 (Crown): gold filigree round the plinth and on the cowl, the
## antimatter core glowing light violet in the lens, in a gold crown, and in a broad band round the
## cowl, where the camera sees it.
static func build_ion_beam(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.2 if level < 3 else float(ION_PLINTHS[level - 3])
	var rise := 0.0 if level < 3 else float(ION_RISES[level - 3])
	var top := _plinth(m, 2, 0.78, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var head := Vector3(0, top + 0.85 + rise, 0)
	var conduit := CONDUIT if level < 3 else (VIOLET_CURRENT if p.tier >= Parts.Tier.OBSIDIAN else ION_CURRENT)
	for k: int in 3:
		var degrees := 105.0 + 120.0 * k
		var foot := Parts.around(0.6, degrees, top)
		m.box_chamfered(Vector3(0.18, 0.08, 0.18), 0.03, foot, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME, Parts.OBSIDIAN),
			Vector3(0, -degrees, 0))
		Parts.pipe_run(m, PackedVector3Array([foot, Parts.around(0.18, degrees, head.y - 0.12)]), 0.05, conduit)
		if level >= 4:
			m.prism(0.06, 0.06, 0.04, 4, foot + Vector3(0, 0.08, 0), INLAY.phased(k / 3.0), Vector3(0, 45.0 - degrees, 0))
	var aim := Vector3(40, 100, 0)
	var housing := head - LowPolyMesh.turn(Vector3(0, 0.2, 0), aim)
	Parts.drum(m, 0.3, 0.34, 0.05, 20, housing, _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND), aim)
	m.tube(0.26, 0.34, 0.06, 20, _at(housing, Vector3(0, 0.08, 0), aim), ARMOUR_ROUND, aim)
	var lens := _at(housing, Vector3(0, 0.3, 0), aim)
	var lens_surf := LENS_PULSE
	if p.tier >= Parts.Tier.CROWN:
		lens_surf = BRIGHT_CORE
	elif level >= 3:
		lens_surf = ION_LENS
	m.lathe(PackedVector2Array([
		Vector2(0, 0), Vector2(0.18, 0.04), Vector2(0.3, 0.1), Vector2(0.18, 0.17), Vector2(0, 0.21),
	]), 20, lens, lens_surf, aim)
	# The focusing rings turn about the beam, alternate rings the other way, each with two glowing
	# studs that show it turning. The studs stand out from the ring's outer edge, beyond the
	# spokes, which run inside the rings.
	var along := LowPolyMesh.turn(Vector3.UP, aim)
	var turning: Array[LowPolyMesh] = [p.moving(lens, Motion.spin(along, 1.6)), p.moving(lens, Motion.spin(along, -1.1))]
	var rings := 2 if level < 2 else 4
	var reach := 0.0
	var stud := FOCUS if p.tier >= Parts.Tier.OBSIDIAN else ION
	for i: int in rings:
		reach = 0.32 + 0.15 * i
		var major := 0.26 - 0.035 * i
		var ring := turning[i % 2]
		Parts.torus(ring, major, 0.035, 16 - 2 * i, 8, LowPolyMesh.turn(Vector3(0, reach, 0), aim),
			GOLD if p.tier >= Parts.Tier.GOLD and i == 0 else _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND),
			aim)
		for k: int in 2:
			var degrees := 60.0 * i + 180.0 * k
			ring.strut(LowPolyMesh.turn(Parts.around(major + 0.03, degrees, reach + 0.035), aim),
				LowPolyMesh.turn(Parts.around(major + 0.08, degrees, reach + 0.035), aim), 0.05, stud)
	m.prism(0.07, 0.05, 1.0, 10, _at(lens, Vector3(0, 0.21, 0), aim), ION_HOLO, aim)
	for k: int in 3:
		var spoke := _at(lens, Parts.around(0.27, 120.0 * k, 0.1), aim)
		var spoke_end := _at(lens, Parts.around(0.26 - 0.035 * (rings - 1), 120.0 * k, reach + 0.03), aim)
		m.prism(0.02, 0.02, spoke.distance_to(spoke_end), 8, spoke, Parts.ROD, Parts.facing(spoke_end - spoke))
	m.orb(0.07, 12, 6, _at(lens, Vector3(0, reach + 0.12, 0), aim), ION_PULSE.phased(0.5))
	if level < 3:
		return
	# A cowl behind the housing banded in the tier's glow, and a power cell on the near corner.
	var glow := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
	Parts.drum(m, 0.36, 0.14, 0.04, 20, _at(housing, Vector3(0, -0.12, 0), aim),
		Parts.FILIGREE if p.tier >= Parts.Tier.CROWN else _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND), aim)
	# At the Crown the band is the antimatter core, broad and glowing light violet where it shows.
	if p.tier >= Parts.Tier.CROWN:
		m.ring(0.355, 0.395, 0.18, 20, _at(housing, Vector3(0, -0.14, 0), aim), BRIGHT_CORE, aim)
	else:
		m.ring(0.355, 0.375, 0.06, 20, _at(housing, Vector3(0, -0.08, 0), aim), glow, aim)
	var cell := Parts.around(ION_CELL, 45.0, Parts.PAD_HEIGHT)
	Parts.drum(m, 0.13, 0.42, 0.03, 16, cell, _by_tier(p.tier, RIBBED, CHROME_RIBBED, OBSIDIAN_RIBBED))
	m.ring(0.125, 0.145, 0.06, 16, cell + Vector3(0, 0.26, 0), glow)
	Parts.drum(m, 0.08, 0.06, 0.02, 16, cell + Vector3(0, 0.42, 0), glow)
	if level < 4:
		return
	_plinth_panels(m, 0.78, plinth)
	m.ring(0.5, 0.68, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
	# The focusing array: three violet crystal points round the lens's rim, along the beam, between
	# the spokes.
	for k: int in 3:
		m.cone(0.05, 0.2, 8, _at(lens, Parts.around(0.28, 60.0 + 120.0 * k, 0.06), aim), FOCUS.phased(k / 3.0), aim)
	if level >= 5:
		var focus := p.moving(_at(lens, Vector3(0, ION_FOCUS_OFF, 0), aim), Motion.spin(along, 0.7))
		_ion_focus(focus, 0.22, 0.32, aim, p.tier)
	if level < 6:
		return
	_plinth_filigree(m, 0.78)
	_ion_crown(m, _at(lens, Vector3(0, 0.02, 0), aim), 0.36, 5, 0.24, aim)


## A fire-control spire stands on the bunker's left corner at every level: a tower of three square
## steps with trim lips, the top one glowing, a big glowing targeting lens in a gold rim, in a
## chunky housing on top facing the camera, and round the lens a halo of three big pointed red vanes
## turning slowly. From L3 the barrel grows longer each level and stands steeper, so it climbs
## higher within the footprint, one clean mass with three bold accelerator rings in place of the
## coils. L3 (Chrome): chrome plinth, bunker, breech and barrel, the rings chrome banded in cyan,
## the pad's cells ribbed chrome. L4 (Obsidian): a taller plinth with glowing violet vein panels on
## its faces the camera sees, the bunker, breech, barrel and cells obsidian, veins round the
## plinth's top and the bunker, crystal inlays on the plinth's corners, the rings banded and the
## bunker's lamps and the cells' caps violet, the spire's lens and lip violet, a violet targeting
## beam rising from the lens, and an uplink ring hovering round the barrel, turning about it. L5
## (Crown): gold filigree round the plinth and on the rings' collars, the antimatter core glowing
## light violet in the breech, and a gold crown round the muzzle.
static func build_orbital_cannon(p: Parts, level: int) -> void:
	var m := p.body
	var plinth := 0.32 if level < 3 else float(ORBITAL_PLINTHS[level - 3])
	var top := _plinth(m, 4, 1.78, plinth, ARMOUR, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	Parts.drum(m, 1.38, 0.24, 0.07, 8, Vector3(0, top, 0), _by_tier(p.tier, DENSE, Parts.CHROME, Parts.OBSIDIAN), Parts.OCTAGON)
	m.ring(1.34, 1.42, 0.07, 8, Vector3(0, top, 0), HAZARD_FINE, Parts.OCTAGON)
	var bunker := top + 0.24
	Parts.drum(m, 1.0, 0.16, 0.05, 24, Vector3(0, bunker, 0), _by_tier(p.tier, SHELL_MID, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND))
	var deck := bunker + 0.16
	var yaw := SCREEN_RIGHT + 12.0
	var heading := Vector3(0, yaw, 0)
	var aim := Vector3(47.0 if level < 3 else float(ORBITAL_PITCHES[level - 3]), yaw, 0)
	var trunnion := Vector3(0, deck + 0.36, 0)
	for side: float in [-1.0, 1.0]:
		var cheek := LowPolyMesh.turn(Vector3(side * 0.6, 0, 0), heading)
		m.box_chamfered(Vector3(0.2, 0.78, 1.15), 0.06, Vector3(cheek.x, deck, cheek.z), ARMOUR, heading)
		m.prism(0.22, 0.22, 0.1, 20, trunnion + LowPolyMesh.turn(Vector3(side * 0.7, 0, 0), heading),
			GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL, heading + Vector3(0, 0, -90 * side))
	# The gun elevates slowly about its trunnion: the breech block, the barrel and what it carries.
	# The block's foot sits 0.3 down in the deck and the elevation slides it a further 0.06 through
	# the deck's top, between the cheeks, which hide where it meets the deck: by construction.
	var gun := p.moving(trunnion, Motion.swing(LowPolyMesh.turn(Vector3.RIGHT, heading), 4.0, 9.0))
	gun.box_chamfered(Vector3(0.96, 0.95, 0.96), 0.08, LowPolyMesh.turn(Vector3(0, -0.45, 0), aim),
		_by_tier(p.tier, Parts.HULL_LIGHT, Parts.CHROME, Parts.OBSIDIAN), aim)
	var length := 1.2 + 0.15 * level if level < 3 else float(ORBITAL_LENGTHS[level - 3])
	var barrel := LowPolyMesh.turn(Vector3(0, 0.5, 0), aim)
	gun.lathe(PackedVector2Array([
		Vector2(0.42, 0), Vector2(0.42, 0.22), Vector2(0.32, 0.36), Vector2(0.3, length),
	]), 24, barrel, _by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND), aim)
	gun.lathe(PackedVector2Array([
		Vector2(0.3, 0), Vector2(0.42, 0.06), Vector2(0.42, 0.34), Vector2(0.26, 0.38), Vector2(0.22, 0.3),
	]), 24, _at(barrel, Vector3(0, length, 0), aim), _by_tier(p.tier, SHELL, Parts.CHROME_ROUND, Parts.OBSIDIAN_ROUND), aim)
	gun.disc(0.22, 20, _at(barrel, Vector3(0, length + 0.3, 0), aim), BORE_ION, aim)
	gun.tube(0.42, 0.44, 0.08, 24, _at(barrel, Vector3(0, length + 0.12, 0), aim), GOLD if p.tier >= Parts.Tier.GOLD else ARMOUR_ROUND,
		aim)
	gun.ring(0.5, 0.53, 0.1, 24, _at(barrel, Vector3(0, length + 0.44, 0), aim), ION_HOLO, aim)
	# The coils swell one after another up the barrel: the current running to the muzzle. From L3
	# they give way to three bold accelerator rings, a collar in the tier's plate (gold filigree at
	# the Crown) under a glowing band (cyan, violet from the Obsidian tier), swelling in turn.
	if level < 3:
		var coils := 2 + level
		for i: int in coils:
			var at := 0.5 + (length - 0.7) * i / (coils - 1)
			Parts.torus(gun, 0.315, 0.04, 24, 6, _at(barrel, Vector3(0, at, 0), aim), ION_PULSE.phased(Parts.chase(i, coils)),
				aim)
	else:
		var collar := Parts.FILIGREE if p.tier >= Parts.Tier.CROWN else _by_tier(p.tier, Parts.CHROME_ROUND, Parts.CHROME_ROUND,
			Parts.OBSIDIAN_ROUND)
		var band := Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP
		for k: int in ORBITAL_BANDS.size():
			var at := _at(barrel, Vector3(0, 0.5 + (length - 0.7) * float(ORBITAL_BANDS[k]), 0), aim)
			gun.tube(0.29, 0.4, 0.14, 24, at, collar, aim)
			Parts.torus(gun, 0.4, 0.05, 24, 10, _at(at, Vector3(0, 0.02, 0), aim), band.phased(Parts.chase(k, 3)), aim)
	if level >= 2:
		Parts.torus(m, 1.0, 0.04, 24, 6, Vector3(0, deck - 0.04, 0), GOLD if p.tier >= Parts.Tier.GOLD else SHELL_MID)
	# The fire-control spire: a stepped tower, chrome from the Chrome tier up, a bright mark on the
	# dark Obsidian and Crown bunkers, a trim lip at each step and a glowing one at its top; its lens
	# and lip glow cyan, violet from the Obsidian tier.
	var spire := Parts.around(1.3, 135.0, top + 0.24)
	var lens_glow := _by_tier(p.tier, ION_PULSE, Parts.CYAN_STRIP, LENS_VIOLET)
	var trim := GOLD if p.tier >= Parts.Tier.GOLD else Parts.GUNMETAL
	var rise := 0.0
	for k: int in ORBITAL_STEPS.size():
		var step: Vector2 = ORBITAL_STEPS[k]
		m.box_chamfered(Vector3(step.x, step.y, step.x), 0.04, spire + Vector3(0, rise, 0),
			_by_tier(p.tier, Parts.GUNMETAL, Parts.CHROME, Parts.CHROME))
		rise += step.y
		if k < ORBITAL_STEPS.size() - 1:
			m.box_chamfered(Vector3(step.x + 0.06, 0.06, step.x + 0.06), 0.02, spire + Vector3(0, rise - 0.06, 0),
				lens_glow if k == ORBITAL_STEPS.size() - 2 else trim)
	var lens := spire + Vector3(0, ORBITAL_SPIRE, 0)
	var lens_aim := Parts.facing(TOWARD_LENS)
	Parts.drum(m, 0.48, 0.2, 0.05, 16, lens - TOWARD_LENS * 0.14, _by_tier(p.tier, ARMOUR_ROUND, Parts.CHROME_ROUND,
		Parts.CHROME_ROUND), lens_aim)
	m.tube(0.4, 0.47, 0.05, 16, lens + TOWARD_LENS * 0.06, trim, lens_aim)
	m.disc(0.4, 16, lens + TOWARD_LENS * 0.065, lens_glow, lens_aim)
	# The halo turns slowly round the lens: a ring and three pointed vanes swept back from it.
	var halo := p.moving(lens, Motion.spin(Vector3.UP, 0.4))
	Parts.torus(halo, ORBITAL_HALO, 0.04, 16, 4, Vector3(0, -0.04, 0), trim)
	for k: int in 3:
		var degrees := 120.0 * k + 30.0
		_vane(halo, Parts.around(ORBITAL_HALO, degrees, 0.0), Parts.around(ORBITAL_HALO + ORBITAL_VANE, degrees + 28.0, 0.2),
			0.26, 0.1, ARMOUR)
	if level >= 4:
		m.prism(0.07, 0.03, ORBITAL_BEAM, 12, lens + TOWARD_LENS * 0.07, Parts.CORE_GLOW)
	# Lights round the bunker's lower tier blink in a chase.
	for k: int in 8:
		m.orb(0.07, 8, 3, Parts.around(1.2, 22.5 + 45.0 * k, bunker + 0.01),
			(CORE_BLINK if p.tier >= Parts.Tier.OBSIDIAN else ION_BLINK).phased(Parts.chase(k, 8)))
	for degrees: float in [45.0, 315.0]:
		m.box_chamfered(Vector3(0.5, 0.18, 0.04), 0.01, Parts.around(1.3, degrees, top + 0.05), VENT,
			Vector3(0, 90.0 - degrees, 0))
	var cells: Array[float] = [45.0, 315.0]
	if level >= 2:
		cells.append_array([135.0, 225.0])
	for k: int in cells.size():
		var cell := Parts.around(2.2, cells[k], Parts.PAD_HEIGHT)
		if level < 3:
			_cell(m, cell, 0.4, ION_PULSE.phased(k / 4.0))
		else:
			# From L3 the cells take the tier's ribbed plate and glow.
			Parts.drum(m, 0.17, 0.4, 0.03, 16, cell, _by_tier(p.tier, RIBBED, CHROME_RIBBED, OBSIDIAN_RIBBED))
			Parts.drum(m, 0.102, 0.06, 0.02, 16, cell + Vector3(0, 0.4, 0),
				(Parts.CORE_GLOW if p.tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP).phased(k / 4.0))
	if level < 4:
		return
	_plinth_panels(m, 1.78, plinth)
	# Veins round the plinth's top and the bunker's lower tier, and round the bunker's side.
	m.ring(1.44, 1.66, 0.012, 8, Vector3(0, top, 0), Parts.VEINS, Parts.OCTAGON)
	m.ring(1.02, 1.3, 0.012, 8, Vector3(0, bunker, 0), Parts.VEINS, Parts.OCTAGON)
	m.ring(0.995, 1.015, 0.09, 24, Vector3(0, bunker + 0.02, 0), VEIN_PANEL)
	# Crystal inlays on the plinth's corners the camera sees.
	for degrees: float in [-22.5, 22.5, 67.5, 112.5]:
		m.prism(0.11, 0.11, 0.06, 4, Parts.around(1.58, degrees, top), INLAY.phased(fposmod(degrees, 90.0) / 90.0),
			Vector3(90, 90.0 - degrees, 0))
	var along := LowPolyMesh.turn(Vector3.UP, aim)
	# The uplink ring hovers between the second and the third accelerator ring.
	var uplink := p.moving(trunnion + _at(barrel, Vector3(0, 0.5 + (length - 0.7) * ORBITAL_RING_AT, 0), aim),
		Motion.spin(along, 0.5))
	_ion_focus(uplink, 0.62, 0.78, aim, p.tier)
	if level < 5:
		return
	_plinth_filigree(m, 1.78)
	# The antimatter core: light violet in a gold rim on the breech block's back, where the camera
	# sees it; a gold crown round the muzzle.
	var back := LowPolyMesh.turn(Vector3(0, 0, -1), aim)
	var window := LowPolyMesh.turn(Vector3(0, 0.03, -0.48), aim)
	gun.prism(0.3, 0.3, 0.04, 20, window, BRIGHT_CORE, Parts.facing(back))
	gun.tube(0.3, 0.36, 0.05, 20, window, Parts.GOLD_ROUND, Parts.facing(back))
	_ion_crown(gun, _at(barrel, Vector3(0, length + 0.32, 0), aim), 0.45, 8, 0.26, aim)


# --- Shared parts --------------------------------------------------------------------

## The family's plinth on its pad: an armoured octagon of gunmetal plate (`plate`: chrome or
## obsidian at the high tiers), `radius` to its corners and `height` tall, its upper third, deck
## and chamfer, plated in defence red (`belt_surf`) at every tier, so the family reads red from
## across the base. Returns the height of its top.
static func _plinth(m: LowPolyMesh, size: int, radius: float, height: float, belt_surf: Surf = ARMOUR,
		plate: Surf = Parts.GUNMETAL) -> float:
	Parts.foundation(m, size)
	var base := Vector3(0, Parts.PAD_HEIGHT, 0)
	var deck := _deck(height)
	m.lathe(PackedVector2Array([Vector2(radius, 0), Vector2(radius, height - deck)]), 8, base, plate, Parts.OCTAGON)
	Parts.drum(m, radius, deck, minf(0.08, deck * 0.5), 8, base + Vector3(0, height - deck, 0), belt_surf, Parts.OCTAGON)
	return Parts.PAD_HEIGHT + height


## The height of a plinth's red deck (_plinth): its upper third.
static func _deck(height: float) -> float:
	return height / 3.0


## Glowing violet vein panels on the faces of a plinth (_plinth) the camera sees, on its plate
## under the red deck, clear of the filigree band round its foot; too short a plinth has none.
static func _plinth_panels(m: LowPolyMesh, radius: float, height: float) -> void:
	var apothem := radius * cos(deg_to_rad(22.5))
	var width := 2.0 * radius * sin(deg_to_rad(22.5)) * 0.7
	var row := Vector2(PLINTH_FILIGREE + 0.02, height - _deck(height) - 0.03)
	if row.y - row.x < 0.08:
		return
	for degrees: float in PLINTH_FACES:
		m.box(Vector3(width, row.y - row.x, 0.02), Parts.around(apothem + 0.008, degrees, Parts.PAD_HEIGHT + row.x),
			VEIN_PANEL, Vector3(0, 90.0 - degrees, 0))


## A broad gold filigree band round a plinth's foot (_plinth), under its vein panels.
static func _plinth_filigree(m: LowPolyMesh, radius: float) -> void:
	m.ring(radius - 0.03, radius + 0.025, PLINTH_FILIGREE, 8, Vector3(0, Parts.PAD_HEIGHT, 0), Parts.FILIGREE, Parts.OCTAGON)


## A mast standing on `foot`, `height` tall, of `surf`: a tapered round post 0.14 across at its
## top on a fat flared foot, so it reads as a post at the overview, not a hair.
static func _mast(m: LowPolyMesh, foot: Vector3, height: float, surf: Surf) -> void:
	m.lathe(PackedVector2Array([
		Vector2(0.14, 0), Vector2(0.14, 0.05), Vector2(0.095, 0.13), Vector2(0.07, height), Vector2(0, height),
	]), 12, foot, surf)


## A lamp post standing on `foot`, `height` tall: a gunmetal post 0.1 across at its foot, tapering,
## thick enough to read as a post rather than an ink line, and a bulb 0.12 across of `bulb` on its
## top.
static func _lamp_post(m: LowPolyMesh, foot: Vector3, height: float, bulb: Surf) -> void:
	m.prism(0.05, 0.04, height, 10, foot, Parts.GUNMETAL)
	m.orb(0.06, 12, 5, foot + Vector3(0, height, 0), bulb)


## A gold crown standing on `pos`: a band `radius` round with `points` spikes `spike` tall on it.
static func _crown(m: LowPolyMesh, pos: Vector3, radius: float, points: int, spike: float = 0.1) -> void:
	m.ring(radius - 0.035, radius, 0.06, 16, pos, Parts.GOLD_ROUND)
	for k: int in points:
		m.cone(spike * 0.35, spike, 8, pos + Parts.around(radius - 0.0175, 360.0 * k / points + 90.0, 0.06), Parts.GOLD_ROUND)


## A ring hovering over a weapon, built about its own centre on a moving part: obsidian between
## `inner` and `outer`, glowing violet across its top, veins round its rim (gold at the Crown) and
## four red sights pointing in, all bobbing together.
static func _hover_ring(s: LowPolyMesh, inner: float, outer: float, tier: int) -> void:
	s.ring(inner, outer, 0.07, 24, Vector3.ZERO, HOVER)
	s.lathe(PackedVector2Array([Vector2(outer - 0.02, 0.072), Vector2(inner + 0.02, 0.072)]), 24, Vector3.ZERO, HOVER_RIM)
	s.lathe(PackedVector2Array([Vector2(outer + 0.006, 0.006), Vector2(outer + 0.006, 0.064)]), 24, Vector3.ZERO,
		HOVER_GOLD if tier >= Parts.Tier.CROWN else HOVER_VEINS)
	for k: int in 4:
		var degrees := 90.0 * k
		s.box(Vector3(0.06, 0.05, 0.16), Parts.around(inner - 0.05, degrees, 0.01), HOVER_SIGHT, Vector3(0, 90.0 - degrees, 0))


## A surface by tier: `base` below the Chrome tier, `chrome` at it, `obsidian` from the Obsidian
## tier up.
static func _by_tier(tier: int, base: Surf, chrome: Surf, obsidian: Surf) -> Surf:
	if tier >= Parts.Tier.OBSIDIAN:
		return obsidian
	if tier >= Parts.Tier.CHROME:
		return chrome
	return base


## A power cell: a ribbed can `height` tall with a glowing cap.
static func _cell(m: LowPolyMesh, pos: Vector3, height: float, glow: Surf, radius: float = 0.17) -> void:
	Parts.drum(m, radius, height, 0.03, 16, pos, RIBBED)
	Parts.drum(m, radius * 0.6, 0.06, 0.02, 16, pos + Vector3(0, height, 0), glow)


## An ammunition crate on the pad, turned to the diagonal, with a hazard-striped lid.
static func _crate(m: LowPolyMesh, pos: Vector3) -> void:
	m.box_chamfered(Vector3(0.36, 0.26, 0.36), 0.04, pos, DENSE, Vector3(0, 45, 0))
	m.box_chamfered(Vector3(0.38, 0.06, 0.38), 0.02, pos + Vector3(0, 0.26, 0), HAZARD_FINE, Vector3(0, 45, 0))


## A capacitor can standing on `pos`, `height` tall, of `body` (ribbed: chrome or obsidian at the
## high tiers). The can on top of a stack (`top`) wears the glowing `band` and the insulator cap.
## Returns the can's top.
static func _capacitor(m: LowPolyMesh, pos: Vector3, height: float, top: bool, band: Surf,
		body: Surf = RIBBED) -> Vector3:
	Parts.drum(m, 0.2, height, 0.04, 16, pos, body)
	if not top:
		return pos + Vector3(0, height, 0)
	m.ring(0.19, 0.225, 0.07, 16, pos + Vector3(0, height * 0.5, 0), band)
	Parts.drum(m, 0.12, 0.08, 0.02, 16, pos + Vector3(0, height, 0), Parts.GUNMETAL)
	return pos + Vector3(0, height + 0.08, 0)


## A capacitor can of the railgun standing on `pos`, `height` tall and 12 sides round (small, and
## up to twelve of them): ribbed cream (chrome from the Chrome tier, obsidian from the Obsidian
## tier) banded in
## the tier's glow, its cap lit at step `step` of the six-step charging sequence: a cyan lamp
## blinking, a violet crystal swelling from the Obsidian tier.
static func _rail_cell(m: LowPolyMesh, pos: Vector3, height: float, step: int, tier: int) -> void:
	Parts.drum(m, 0.12, height, 0.03, 12, pos, _by_tier(tier, RIBBED_LIGHT, CHROME_RIBBED, OBSIDIAN_RIBBED))
	m.ring(0.115, 0.135, 0.06, 12, pos + Vector3(0, height - 0.16, 0),
		Parts.CORE_GLOW if tier >= Parts.Tier.OBSIDIAN else Parts.CYAN_STRIP)
	var phase := Parts.chase(step, 6)
	if tier < Parts.Tier.OBSIDIAN:
		Parts.drum(m, 0.075, 0.07, 0.02, 12, pos + Vector3(0, height, 0), ION_BLINK.phased(phase))
	else:
		m.cone(0.08, 0.2, 8, pos + Vector3(0, height, 0), FOCUS.phased(phase))

## A hovering ring built about its own centre and turned by `rot` so it rings a beam or a barrel
## (the ion beam's focus ring from L5, the orbital cannon's uplink ring from L4): _hover_ring's
## obsidian, its glowing violet face, its veined rim (gold at the Crown) and four red sights round
## its inner edge, bobbing together.
static func _ion_focus(s: LowPolyMesh, inner: float, outer: float, rot: Vector3, tier: int) -> void:
	s.ring(inner, outer, 0.07, 24, Vector3.ZERO, HOVER, rot)
	s.lathe(PackedVector2Array([Vector2(outer - 0.02, 0.072), Vector2(inner + 0.02, 0.072)]), 24, Vector3.ZERO, HOVER_RIM, rot)
	s.lathe(PackedVector2Array([Vector2(outer + 0.006, 0.006), Vector2(outer + 0.006, 0.064)]), 24, Vector3.ZERO,
		HOVER_GOLD if tier >= Parts.Tier.CROWN else HOVER_VEINS, rot)
	for k: int in 4:
		s.orb(0.035, 8, 4, LowPolyMesh.turn(Parts.around(inner - 0.01, 90.0 * k, 0.035), rot), HOVER_SIGHT)


## A gold crown like _crown, turned by `rot`: its band round the turned +Y through `pos`, its
## spikes along it. The ion beam's round its lens, the orbital cannon's round its muzzle.
static func _ion_crown(m: LowPolyMesh, pos: Vector3, radius: float, points: int, spike: float, rot: Vector3) -> void:
	m.ring(radius - 0.035, radius, 0.06, 16, pos, Parts.GOLD_ROUND, rot)
	for k: int in points:
		m.cone(spike * 0.35, spike, 8, pos + LowPolyMesh.turn(Parts.around(radius - 0.0175, 360.0 * k / points + 90.0, 0.06), rot),
			Parts.GOLD_ROUND, rot)


## A pointed vane from `root` to `tip`: a blade `width` wide and `thick` thick at its widest, a
## third of the way out, tapering to a point at either end, lying flat across the up direction.
static func _vane(s: LowPolyMesh, root: Vector3, tip: Vector3, width: float, thick: float, surf: Surf) -> void:
	var along := tip - root
	var side := Vector3.UP.cross(along).normalized() * width * 0.5
	var up := along.cross(side).normalized() * thick * 0.5
	var mid := root + along * 0.33
	var waist: Array[Vector3] = [mid + side, mid + up, mid - side, mid - up]
	for i: int in 4:
		for end: Vector3 in [tip, root]:
			var a := waist[i]
			var b := waist[(i + 1) % 4]
			if (b - a).cross(end - a).dot((a + b + end) / 3.0 - mid) < 0.0:
				s.triangle(a, end, b, surf)
			else:
				s.triangle(a, b, end, surf)


## The cloaked sentry's gun: a low head on the lid with a short barrel and a red sight. From L4 a
## chrome head and barrel (obsidian and a violet crystal sight from the Obsidian tier), twin
## longer barrels from L5, and at the Crown the antimatter core glowing in its sight.
static func _sentry_gun(m: LowPolyMesh, pos: Vector3, yaw: float, level: int = 1, tier: int = Parts.Tier.BASE) -> void:
	var heading := Vector3(0, yaw, 0)
	m.box_chamfered(Vector3(0.26, 0.15, 0.34), 0.04, pos, _by_tier(tier, SHELL_MID, Parts.CHROME, Parts.OBSIDIAN), heading)
	var aim := Vector3(84, yaw, 0)
	var barrel := BARREL if tier < Parts.Tier.CHROME else Parts.CHROME_ROUND
	var across: Array[float] = [0.0]
	if level >= 5:
		across = [-0.055, 0.055]
	for x: float in across:
		m.prism(0.045 if level < 5 else 0.038, 0.045 if level < 5 else 0.038, 0.42 if level < 5 else 0.52, 16,
			_at(pos, Vector3(x, 0.08, 0.12), heading), barrel, aim)
	var sight := LASER
	if tier >= Parts.Tier.CROWN:
		sight = BRIGHT_CORE
	elif tier >= Parts.Tier.OBSIDIAN:
		sight = FOCUS
	m.box(Vector3(0.1, 0.04, 0.02), _at(pos, Vector3(0, 0.08 if level < 5 else 0.125, 0.171), heading), sight, heading)


## A tesla coil standing on `base`: a dark column `height` tall stacked with white insulator
## skirts `flare` wide at the foot (`skirt`: chrome or obsidian at the high tiers), crowned with a
## corona ring. Returns the crown's centre.
static func _coil(m: LowPolyMesh, base: Vector3, height: float, flare: float, gold: bool,
		skirt: Surf = SHELL) -> Vector3:
	m.prism(flare * 0.4, flare * 0.28, height, 16, base, ARC_CURRENT)
	var skirts := _skirts(height)
	for i: int in skirts:
		var t := float(i) / skirts
		var column := lerpf(flare * 0.4, flare * 0.28, t + 0.3 / skirts)
		m.lathe(PackedVector2Array([
			Vector2(lerpf(flare, flare * 0.62, t), 0), Vector2(lerpf(flare, flare * 0.62, t), 0.05),
			Vector2(column, 0.09),
		]), 16, base + Vector3(0, height * t + 0.06, 0), skirt)
	var crown := base + Vector3(0, height, 0)
	# A small coil's corona is a tiny ring, and takes fewer faces.
	var big := flare >= 0.4
	Parts.torus(m, flare * 0.8, flare * 0.16, 20 if big else 16, 10 if big else 6, crown - Vector3(0, flare * 0.16, 0),
		GOLD if gold else Parts.GUNMETAL)
	return crown


## How many insulator skirts a tesla coil `height` tall carries.
static func _skirts(height: float) -> int:
	return maxi(3, int(height / 0.26))


## The point on the rim of skirt `i` of a tesla coil `height` tall and `flare` wide (_coil), just
## outside it at Parts.around() angle `degrees`, from the coil's base.
static func _skirt_rim(height: float, flare: float, i: int, degrees: float) -> Vector3:
	var t := float(i) / _skirts(height)
	return Parts.around(lerpf(flare, flare * 0.62, t) + 0.03, degrees, height * t + 0.06 + 0.05)


## A ring round the gravity well's core, tilted by `rot`, centred on `centre`.
static func _gyro(m: LowPolyMesh, centre: Vector3, major: float, minor: float, rot: Vector3, surf: Surf) -> void:
	Parts.torus(m, major, minor, 16, 10, centre - LowPolyMesh.turn(Vector3(0, minor, 0), rot), surf, rot)


## `origin` plus `local` turned by `rot`: a point on a turned part.
static func _at(origin: Vector3, local: Vector3, rot: Vector3) -> Vector3:
	return origin + LowPolyMesh.turn(local, rot)


static func _glow(tint: Color, flags: int = 0) -> Surf:
	return Surf.make(MaterialKit.Layer.GLOW, tint, 1.0, Surf.UNLIT | flags, true)
