class_name Weapons
extends RefCounted
## How each defence, trap and unit attacks in the battle view (docs/reference/battle-view.md,
## **Weapons**): one record a type id, read by BattleView and BattleUnits when a shot, a shell, a
## hit, a spring or a death comes from the sim, and drawn by BattleEffects. The sim decides what
## hits what and when; a record decides only how it looks: the projectile (`kind`, its colour and
## size, its speed or arc, a burst of several for one hit, its trail), the flash at the muzzle,
## the sockets a shot leaves in turn, the impact where it lands and the fake light under it (a
## glow decal on the ground, no light node), the kick its gun takes (a hint the aim lanes may
## read), and how a unit of the type dies (timed by BattleUnits.death_seconds).
##
## Presentation only, so it lives in code rather than in data/: the server never reads it. Every
## type in the catalog that attacks, springs, shields or self-destructs has an entry (the
## anim_defences scenario checks it); of() gives a type with none a record that draws nothing.

## What leaves the weapon. BOLT, LASER, TRACER, PLASMA, BALL and SHELL are glowing bolts of their
## own size (a straight flight at `speed`, or an arc); MISSILE and BOMB their own meshes (a lofted
## arc with a flame; a fall from the bay); STREAK and BEAM a stretched glow between the two ends
## (an instant streak fading in STREAK_SECONDS; a beam held `hold` seconds); LIGHTNING the arc
## tower's; PULSE a ring travelling to the target; VORTEX the gravity well's beam to each air unit
## it holds; MELEE a blow at the building's side; CHARGE the breacher's blast. The traps: MINE,
## FLAK_MINE, MEGA_MINE, GRAV_TRAP. SHIELD draws its dome (BattleEffects.add_shield), NONE nothing.
enum Kind { NONE, BOLT, LASER, TRACER, PLASMA, BALL, SHELL, MISSILE, BOMB, STREAK, BEAM, LIGHTNING,
	PULSE, VORTEX, MELEE, CHARGE, MINE, FLAK_MINE, MEGA_MINE, GRAV_TRAP, SHIELD }
## What a projectile leaves behind in flight: grey smoke puffs, or glowing wisps of its colour.
enum Trail { NONE, SMOKE, GLOW }
## The muzzle flash: a comic star, or a ring swelling (a lens, a coil, a chamber).
enum Flash { NONE, STAR, RING }
## What happens where it lands: a burst of sparks; a ring; a blast, small, medium or big (a
## fireball, rings, smoke, a scorch from medium up, debris when big); a burst in the air (a dark
## puff and a flash); a plasma splash (a ring as wide as the splash, a scorch, wisps); a burn (a
## ring and the glow); EMP arcs on the unit.
enum Impact { NONE, SPARKS, RING, BLAST_S, BLAST_M, BLAST_L, AIR_BURST, SPLASH, BURN, EMP }
## How a unit of the type dies, past its body's own motion (BattleUnits): nothing more (a figure
## topples), a wreck (a fireball, a ring, smoke, a scorch left), a crash (smoke trailing as it
## spirals down, a blast where it ends), a small blast.
enum Death { NONE, WRECK, CRASH, BLAST }

## The colours the kit has no name for: the plasma mortar's violet, the flak's tracers, the ion
## weapons' white-hot cyan, a missile's flame, a blast's core and its rim, smoke and dust.
const PLASMA_VIOLET := Color("c77dff")
const FLAK_YELLOW := Color("ffe14d")
const ION_WHITE := Color("d9fbff")
const FLAME_ORANGE := Color("ff9a2e")
const BLAST_CORE := Color("fff1c2")
const BLAST_RIM := Color("ff7a2e")
const SMOKE := Color("6e6a80")
const DARK_SMOKE := Color("2e2b3a")
const DUST := Color("c9c2e0")
const TRACER_CYAN := Color("b8ffe8")

const DEFENCE_MUZZLES: Array[String] = ["muzzle", "muzzle_2", "muzzle_3", "muzzle_4"]
## The missile battery's tubes, as many as its biggest launcher has (twenty at L7): its shots leave
## them in turn along the tip lamps' chase, as many as the model has.
const MISSILE_TUBES: Array[String] = ["muzzle", "muzzle_2", "muzzle_3", "muzzle_4", "muzzle_5", "muzzle_6", "muzzle_7",
	"muzzle_8", "muzzle_9", "muzzle_10", "muzzle_11", "muzzle_12", "muzzle_13", "muzzle_14", "muzzle_15", "muzzle_16",
	"muzzle_17", "muzzle_18", "muzzle_19", "muzzle_20"]
## The flak cannon's barrels, as many as its four a side from L7: its shots leave them in turn,
## the sides alternating, as many as the model has.
const FLAK_BARRELS: Array[String] = ["muzzle", "muzzle_2", "muzzle_3", "muzzle_4", "muzzle_5", "muzzle_6", "muzzle_7",
	"muzzle_8"]
const TWIN: Array[String] = ["muzzle", "muzzle_2"]
const ONE: Array[String] = ["muzzle"]

## The records by type id, each field over DEFAULT's.
const DEFAULT := {
	"kind": Kind.NONE, "color": Color.WHITE, "width": 0.1, "length": 0.4, "speed": 22.0, "arc": 0.0,
	"burst": 1, "burst_gap": 0.07, "trail": Trail.NONE, "flash": 0.0, "flash_shape": Flash.STAR,
	"sockets": [], "impact": Impact.NONE, "impact_size": 0.3, "light": 0.0, "recoil": 0.0,
	"death": Death.NONE, "hold": 0.0,
}
const TABLE := {
	# The defences.
	"laser_turret": {"kind": Kind.LASER, "color": MaterialKit.DEFENCE, "width": 0.1, "length": 1.1, "speed": 40.0,
		"flash": 0.24, "sockets": DEFENCE_MUZZLES, "impact": Impact.SPARKS, "impact_size": 0.45, "light": 0.5,
		"recoil": 0.04},
	"missile_battery": {"kind": Kind.MISSILE, "color": FLAME_ORANGE, "width": 1.8, "speed": 9.0, "arc": 0.25,
		"trail": Trail.SMOKE, "flash": 0.18, "sockets": MISSILE_TUBES, "impact": Impact.BLAST_M,
		"impact_size": 1.0, "light": 0.9, "recoil": 0.03},
	"plasma_mortar": {"kind": Kind.PLASMA, "color": PLASMA_VIOLET, "width": 0.4, "length": 0.5, "arc": 0.35,
		"trail": Trail.GLOW, "flash": 0.35, "flash_shape": Flash.RING, "sockets": ONE, "impact": Impact.SPLASH,
		"impact_size": 0.8, "light": 1.2, "recoil": 0.08},
	"flak_cannon": {"kind": Kind.TRACER, "color": FLAK_YELLOW, "width": 0.09, "length": 0.5, "speed": 35.0,
		"burst": 2, "burst_gap": 0.06, "flash": 0.22, "sockets": FLAK_BARRELS, "impact": Impact.AIR_BURST,
		"impact_size": 0.8, "recoil": 0.06},
	"arc_tower": {"kind": Kind.LIGHTNING, "color": MaterialKit.ARC_BLUE, "flash": 0.35, "flash_shape": Flash.RING,
		"sockets": ONE, "impact": Impact.SPARKS, "impact_size": 0.35, "light": 0.6},
	"cloaked_sentry": {"kind": Kind.LASER, "color": MaterialKit.DEFENCE, "width": 0.08, "length": 0.6,
		"speed": 40.0, "flash": 0.12, "sockets": TWIN, "impact": Impact.SPARKS, "impact_size": 0.3, "light": 0.3},
	"gravity_well": {"kind": Kind.VORTEX, "color": MaterialKit.ANTIMATTER, "width": 0.18, "sockets": ONE},
	"emp_tower": {"kind": Kind.PULSE, "color": MaterialKit.HAZARD, "width": 0.5, "speed": 14.0, "flash": 0.3,
		"flash_shape": Flash.RING, "sockets": ONE, "impact": Impact.EMP, "impact_size": 0.35, "light": 0.5},
	"railgun": {"kind": Kind.STREAK, "color": MaterialKit.ENERGY, "width": 0.12, "flash": 0.3, "sockets": ONE,
		"impact": Impact.SPARKS, "impact_size": 0.35, "light": 0.5, "recoil": 0.12},
	"ion_beam": {"kind": Kind.BEAM, "color": ION_WHITE, "width": 0.18, "hold": 0.2, "flash": 0.32,
		"flash_shape": Flash.RING, "sockets": ONE, "impact": Impact.BURN, "impact_size": 0.4, "light": 0.7},
	"orbital_cannon": {"kind": Kind.BALL, "color": MaterialKit.CRYSTAL, "width": 0.6, "length": 0.7, "arc": 0.35,
		"trail": Trail.GLOW, "flash": 0.6, "sockets": ONE, "impact": Impact.BLAST_L, "impact_size": 1.6,
		"light": 1.8, "recoil": 0.15},
	"shield_generator": {"kind": Kind.SHIELD, "color": MaterialKit.ENERGY},
	# The traps.
	"proximity_mine": {"kind": Kind.MINE, "color": MaterialKit.HAZARD, "impact": Impact.BLAST_M, "impact_size": 1.0,
		"light": 1.2},
	"flak_mine": {"kind": Kind.FLAK_MINE, "color": FLAK_YELLOW, "width": 0.14, "impact": Impact.AIR_BURST,
		"impact_size": 0.7, "light": 0.8},
	"mega_mine": {"kind": Kind.MEGA_MINE, "color": MaterialKit.HAZARD, "impact": Impact.BLAST_L, "impact_size": 1.8,
		"light": 2.2},
	"grav_trap": {"kind": Kind.GRAV_TRAP, "color": MaterialKit.ANTIMATTER, "impact_size": 1.0, "light": 0.8},
	# The units.
	"ranger": {"kind": Kind.BOLT, "color": MaterialKit.ENERGY, "width": 0.06, "length": 0.45, "speed": 30.0,
		"flash": 0.14, "sockets": ONE, "impact": Impact.SPARKS, "impact_size": 0.2, "light": 0.25},
	"breacher": {"kind": Kind.CHARGE, "color": MaterialKit.HAZARD, "impact": Impact.BLAST_M, "impact_size": 1.0,
		"light": 1.2},
	"jet_trooper": {"kind": Kind.BOLT, "color": MaterialKit.ENERGY, "width": 0.05, "length": 0.3, "speed": 30.0,
		"burst": 2, "burst_gap": 0.08, "flash": 0.1, "sockets": ONE, "impact": Impact.SPARKS, "impact_size": 0.2,
		"light": 0.2, "death": Death.BLAST},
	"brawler": {"kind": Kind.MELEE, "color": MaterialKit.ARMY, "impact_size": 0.45},
	"dune_runner": {"kind": Kind.TRACER, "color": TRACER_CYAN, "width": 0.05, "length": 0.3, "speed": 32.0,
		"burst": 3, "burst_gap": 0.06, "flash": 0.1, "sockets": TWIN, "impact": Impact.SPARKS, "impact_size": 0.2,
		"death": Death.WRECK},
	"skimmer": {"kind": Kind.BEAM, "color": MaterialKit.ENERGY, "width": 0.07, "hold": 0.15, "flash": 0.12,
		"flash_shape": Flash.RING, "sockets": ["eye"], "impact": Impact.BURN, "impact_size": 0.3, "light": 0.4,
		"death": Death.CRASH},
	"siege_walker": {"kind": Kind.BOLT, "color": MaterialKit.ARMY, "width": 0.14, "length": 0.5, "speed": 24.0,
		"flash": 0.3, "sockets": TWIN, "impact": Impact.BLAST_S, "impact_size": 0.5, "light": 0.6, "recoil": 0.1,
		"death": Death.WRECK},
	"hover_tank": {"kind": Kind.SHELL, "color": MaterialKit.ARMY, "width": 0.2, "length": 0.4, "speed": 18.0,
		"arc": 0.12, "flash": 0.35, "sockets": ONE, "impact": Impact.BLAST_M, "impact_size": 1.0, "light": 0.9,
		"recoil": 0.12, "death": Death.WRECK},
	"titan": {"kind": Kind.SHELL, "color": MaterialKit.ARMY, "width": 0.26, "length": 0.5, "speed": 18.0,
		"arc": 0.1, "flash": 0.45, "sockets": TWIN, "impact": Impact.BLAST_L, "impact_size": 1.5, "light": 1.3,
		"recoil": 0.15, "death": Death.WRECK},
	"gunship": {"kind": Kind.TRACER, "color": FLAK_YELLOW, "width": 0.06, "length": 0.35, "speed": 30.0,
		"burst": 3, "burst_gap": 0.07, "flash": 0.12, "sockets": TWIN, "impact": Impact.BLAST_S, "impact_size": 0.5,
		"light": 0.5, "death": Death.CRASH},
	"bomber": {"kind": Kind.BOMB, "color": MaterialKit.ARMY, "width": 1.5, "sockets": ["bay"],
		"impact": Impact.BLAST_L, "impact_size": 1.5, "light": 1.5, "death": Death.CRASH},
}


## One type's record (TABLE over DEFAULT).
class Weapon:
	extends RefCounted
	var type := ""
	var kind: Kind = Kind.NONE
	var color := Color.WHITE
	## Across and along (world units) for a bolt or a beam; a scale for the missile and bomb meshes.
	var width := 0.1
	var length := 0.4
	## World units a second for a straight flight; an arc's peak as a share of the distance.
	var speed := 22.0
	var arc := 0.0
	## Projectiles drawn for one hit of the sim, `burst_gap` seconds apart.
	var burst := 1
	var burst_gap := 0.07
	var trail: Trail = Trail.NONE
	## The muzzle flash's radius (0 for none) and shape.
	var flash := 0.0
	var flash_shape: Flash = Flash.STAR
	## The sockets shots leave in turn, one a shot from the first; none: the model's middle or
	## the defence's top.
	var sockets: Array[String] = []
	var impact: Impact = Impact.NONE
	var impact_size := 0.3
	## The glow decal's radius under a blast or a flash (0 for none).
	var light := 0.0
	## How far the gun kicks back on a shot (world units), for the aim lanes.
	var recoil := 0.0
	var death: Death = Death.NONE
	## A beam's hold (seconds of battle).
	var hold := 0.0


static var _cache: Dictionary[String, Weapon] = {}


## The record of `type` (a building or unit type id); a record of Kind.NONE for a type with none.
static func of(type: String) -> Weapon:
	if _cache.has(type):
		return _cache[type]
	var weapon := Weapon.new()
	weapon.type = type
	var fields: Dictionary = DEFAULT.duplicate()
	fields.merge(TABLE.get(type, {}), true)
	weapon.kind = fields["kind"]
	weapon.color = fields["color"]
	weapon.width = fields["width"]
	weapon.length = fields["length"]
	weapon.speed = fields["speed"]
	weapon.arc = fields["arc"]
	weapon.burst = fields["burst"]
	weapon.burst_gap = fields["burst_gap"]
	weapon.trail = fields["trail"]
	weapon.flash = fields["flash"]
	weapon.flash_shape = fields["flash_shape"]
	for name: Variant in fields["sockets"]:
		weapon.sockets.append(str(name))
	weapon.impact = fields["impact"]
	weapon.impact_size = fields["impact_size"]
	weapon.light = fields["light"]
	weapon.recoil = fields["recoil"]
	weapon.death = fields["death"]
	weapon.hold = fields["hold"]
	_cache[type] = weapon
	return weapon


## Whether `type` has an entry of its own.
static func has(type: String) -> bool:
	return TABLE.has(type)
