extends RefCounted
## What a building leaves when it falls in battle (BattleView), in the comic style
## (docs/reference/art-style.md): one heap per footprint size, 1 to 5, and the low strip a wall
## leaves. No tier: a heap reads the same whatever stood there. A heap is a low, scorched pad with
## a pile of chamfered dark chunks on it, a few orange armour plates sticking out at angles, a
## glowing ember or two and a column of dark smoke rising from it (RISE puffs on the hologram
## surface, which fade as they climb). Every chunk's place comes from a SeededRng on the size, so a
## heap is the same every time.
##
## BuildingModels calls build_rubble(p, size) and build_wall_rubble(p) and caches the meshes.

## The pad's tint, scorched concrete, and the heap's: dark hull and gunmetal chunks.
static var SCORCHED := Surf.make(MaterialKit.Layer.CONCRETE, Color("4a4658"))
static var CHUNK := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_DARK)
static var CHUNK_DARK := Surf.make(MaterialKit.Layer.HULL, MaterialKit.GUNMETAL)
static var SHARD := Parts.surf("orange")
static var EMBER := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ARMY, 1.0, Surf.UNLIT | Surf.PULSE, true)
## The smoke: dark grey puffs on the hologram surface, rising and fading.
static var SMOKE := Surf.make(MaterialKit.Layer.GLOW, Color("6c6884"), 1.0, Surf.HOLO | Surf.RISE, true)
## A wall's strip: its stones in the walls' colour and dark hull.
static var WALL_STONE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.WALL)
const SEED := 4111
## The smoke's puffs, and how far over the first column the second starts.
const PUFFS := 6
const PUFF_STEP := 0.45


## The heap a building of `size` cells leaves: within the footprint, about a third of a cell
## high plus a tenth a cell of size.
static func build_rubble(p: Parts, size: int) -> void:
	var m := p.body
	var n := float(size)
	var rng := SeededRng.new(SEED + size)
	m.box_chamfered(Vector3(0.84 * n, 0.06, 0.84 * n), 0.03, Vector3.ZERO, SCORCHED)
	var top := 0.06
	var chunks := 3 + 2 * size
	for k: int in chunks:
		# The first chunks in the middle, the rest further out and lower, so it piles up.
		var reach := 0.32 * n * float(k) / chunks
		var angle := 360.0 * k / chunks + rng.range_int(0, 40)
		var width := (0.22 + rng.range_int(0, 18) / 100.0) * sqrt(n)
		var height := (0.14 + rng.range_int(0, 12) / 100.0) * sqrt(n) * (1.2 - 0.6 * float(k) / chunks)
		var at := Parts.around(reach, angle, 0.04)
		var tilt := Vector3(rng.range_int(-18, 18), rng.range_int(0, 359), rng.range_int(-18, 18))
		m.box_chamfered(Vector3(width, height, width * (0.7 + rng.range_int(0, 40) / 100.0)), 0.04, at,
			CHUNK if k % 2 == 0 else CHUNK_DARK, tilt)
		top = maxf(top, 0.04 + height)
	for k: int in 3:
		var angle := 120.0 * k + rng.range_int(0, 50)
		var at := Parts.around(0.2 * n, angle, 0.05)
		var plate := Vector3(0.28, 0.035, 0.18) * sqrt(n)
		m.box_chamfered(plate, 0.012, at, SHARD, Vector3(rng.range_int(25, 45), angle + 90.0, rng.range_int(-20, 20)))
	for k: int in mini(size, 2):
		m.orb(0.05 * sqrt(n), 8, 3, Parts.around(0.12 * n, 200.0 + 140.0 * k, 0.06), EMBER.phased(0.5 * k))
	# Two columns of puffs, one rising from the heap and one from about where the first fades, their
	# phases spread evenly, so the smoke climbs about twice RISE's height.
	for k: int in PUFFS:
		var lift := top * 0.8 + (PUFF_STEP if k >= PUFFS / 2 else 0.0)
		m.orb((0.13 + 0.03 * (k % 3)) * sqrt(n), 8, 3, Vector3(0.05 * (k % 2), lift, 0), SMOKE.phased(float(k) / PUFFS))


## The low strip a fallen wall leaves on its cell: a few stones in the walls' colour, under 0.16 high.
static func build_wall_rubble(p: Parts) -> void:
	var m := p.body
	var rng := SeededRng.new(SEED)
	m.box_chamfered(Vector3(0.8, 0.04, 0.8), 0.02, Vector3.ZERO, SCORCHED)
	for k: int in 4:
		var at := Vector3(-0.27 + 0.18 * k, 0.03, (rng.range_int(-12, 12)) / 100.0)
		var size := Vector3(0.2 + rng.range_int(0, 6) / 100.0, 0.07 + rng.range_int(0, 6) / 100.0, 0.22)
		m.box_chamfered(size, 0.025, at, WALL_STONE if k % 2 == 0 else CHUNK_DARK,
			Vector3(rng.range_int(-12, 12), rng.range_int(0, 359), rng.range_int(-12, 12)))
