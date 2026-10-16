extends RefCounted
## Wall models, one piece per level and neighbour mask. A piece is a post on the cell centre
## and, for each neighbour in its mask, a half-segment from the post to that cell edge, lower
## than the post, so two adjacent walls meet on their shared edge and each draws its own
## level's style. WallMesh merges the pieces of every finished wall into one mesh;
## BuildingModels.create("barrier_wall", level, 1, tier) is the lone post (mask 0), which the
## paint brush, a lifted wall and the gallery show. A piece is built for its level's tier
## (BuildingModels.tier_of), which paints level 5's crown gold from the Gold tier and levels 6
## to 10 from their tier's palette (PALETTES).
##
## The mask has one bit per orthogonal neighbour in cell space, where cell (x, y) is world
## (x, z): PLUS_X the cell at x + 1, MINUS_X at x - 1, PLUS_Z at y + 1 (world +z), MINUS_Z at
## y - 1. NEIGHBOURS lists the offsets in bit order: bit i is the cell at NEIGHBOURS[i].
##
## The look (docs/reference/art-style.md, **Walls**): a slim hull post on a concrete footing,
## and slate segments 0.4 of the cell thick and 0.85 of the post's height on a concrete curb
## that runs on from one wall to the next, so a run reads as one thick slab with the posts
## standing just proud as joints. Each level adds to the same wall: L1 slate plates on a squat
## post; L2 riveted armour with a band, and a taller post with a gunmetal cap; L3 ribbed
## segments with an energy strip along the top, and a ribbed post; L4 a chamfered pylon post and
## double-plated segments with a brighter strip; L5 a crown on the cap and an energy field
## above a low plated base. Levels 6 to 10 are the same wall in the higher tiers (surfaces follow
## the tier, geometry the level), a little taller at each tier and never above 1.4: L6 and L7
## chrome with cyan strips and lamps, L8 and L9 obsidian with glowing violet fields, vein strips and
## crystal shards, L10 obsidian railed in gold filigree under a gold crown cup holding a violet core
## (_tier_post, _tier_segments). Caps are never wider than their post. Every segment ends on the cell
## edge in a cap left out of the ink outline, so two segments that meet there draw one unbroken
## outline, except towards a wall whose solid segment is lower (`lower_mask`, the same bits;
## solid_top() says how high each level's stands, level 5's being the low slab under its field,
## the lowest): there the taller segment's end is a step, and its caps are outlined. Every level
## shares the curb, whose cap is never outlined, so mixed levels still meet at the base.
##
## The energy is animated by its surfaces (**Animation**): the strips of L3 and L4 carry a current
## that runs along the wall, towards world +x or +z whichever way the segment points, so it runs on
## unbroken along a straight run, as do the strips of L6 to L10; L5's field shimmers upward and
## pulses; the violet fields of L8 to L10 rise without pulsing.

const PLUS_X := 1
const MINUS_X := 2
const PLUS_Z := 4
const MINUS_Z := 8
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The levels with a look of their own; a higher level shows the top one.
const LEVELS := 10
## The Gold tier's level: a crown on its cap, and its segment an energy field over a low slab,
## the lowest solid top of any level.
const FIELD_LEVEL := 5
## Where a segment starts, inside the post, measured from the cell centre.
const SEGMENT_FROM := 0.12
## A segment is this share of its post's height, so the post stands just proud as a joint...
const SEGMENT_SHARE := 0.85
## ... and about 0.4 of the cell thick, so a run reads as one thick slab.
const SEGMENT_HALF := 0.2
const FOOTING_WIDTH := 0.5
const FOOTING_HEIGHT := 0.08
## The curb every segment stands on: a trapezoid, (half width, height) at its foot and top.
const CURB_FOOT := Vector2(0.24, 0.0)
const CURB_TOP := Vector2(0.22, 0.06)
## Level 5's plated base: this share of its segment's height, the field above it.
const SLAB_SHARE := 0.4

## Per level: [post width, body top, post chamfer, cap width (0 for none), cap height]. A post
## is at most 0.46 of the cell and its cap never wider than it.
const POSTS := [
	[0.42, 0.55, 0.05, 0.0, 0.0],
	[0.44, 0.6, 0.05, 0.4, 0.04],
	[0.45, 0.67, 0.05, 0.41, 0.05],
	[0.46, 0.76, 0.08, 0.42, 0.05],
	[0.46, 0.76, 0.06, 0.42, 0.04],
	[0.46, 0.88, 0.06, 0.44, 0.08],
	[0.46, 0.95, 0.06, 0.44, 0.07],
	[0.46, 1.0, 0.07, 0.44, 0.08],
	[0.46, 1.03, 0.07, 0.44, 0.12],
	[0.46, 1.1, 0.07, 0.44, 0.08],
]
## Levels 6 to 10's lamp bands: the height of the course of lamps under the cap, 0 for none.
const LAMP_BANDS: Array[float] = [0.05, 0.06, 0.08, 0.08, 0.0]
## Level 5's crown on the cap, gold from the Gold tier: width and height.
const CROWN := Vector2(0.34, 0.1)

static var CONCRETE := Parts.CONCRETE_PAD
static var POST := Parts.HULL_MID
static var POST_RIBBED := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.HULL_MID, 2.0)
static var POST_PLATED := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.HULL_MID, 2.0)
static var CAP := Surf.make(MaterialKit.Layer.FLAT, MaterialKit.GUNMETAL)
static var GOLD := Parts.GOLD_TRIM
static var SLATE := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.WALL, 1.5)
static var SLATE_RIVETED := Surf.make(MaterialKit.Layer.PLATE, MaterialKit.WALL, 2.5)
static var SLATE_RIBBED := Surf.make(MaterialKit.Layer.PIPE, MaterialKit.WALL, 2.0)
## Emissive strips and the field are too thin to ink. The glow layer's stripes are drawn a third
## as fine (FLOW_SCALE), so a current shows at the closest zoom, and a half-segment is then about
## two whole stripes long, so the stripes run on unbroken from one wall to the next. The strips'
## stripes cross them, so their FLOW runs along the strip: at 0.6 about 1.2 units a second, the
## brighter strip a little faster.
const FLOW_SCALE := 1.0 / 3.0
static var ENERGY := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, FLOW_SCALE,
	Surf.UNLIT | Surf.FLOW, false, false, 0.6)
static var ENERGY_BRIGHT := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY.lightened(0.4), FLOW_SCALE,
	Surf.UNLIT | Surf.FLOW, false, false, 0.65)
## The field: its stripes run along it, so its FLOW lifts them up the panel (V runs down a side
## face), about 0.6 units a second, as it pulses.
static var FIELD := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, FLOW_SCALE,
	Surf.UNLIT | Surf.FLOW | Surf.PULSE, false, false, 0.45)

## Levels 6 to 10. From the Obsidian tier the field is a glowing violet panel, its stripes lifted
## up it as level 5's are, and the strip along the top is the veins layer, too thin to ink, its
## veins running along the wall and their current running on them (Parts.VEINS' 0.7); the lamps
## and the shards pulse.
static var VIOLET_FIELD := Surf.make(MaterialKit.Layer.GLOW, Parts.CORE_GLOW_TINT, FLOW_SCALE, Surf.UNLIT | Surf.FLOW,
	false, true, 0.45)
static var VEIN_STRIP := Surf.make(MaterialKit.Layer.VEINS, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.FLOW, false,
	false, 0.7)
static var VIOLET_LAMP := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ANTIMATTER, 1.0, Surf.UNLIT | Surf.PULSE)
static var SHARD := Surf.make(MaterialKit.Layer.CRYSTAL, MaterialKit.CRYSTAL, 1.5, Surf.GLOSSY | Surf.PULSE)
## The surfaces levels 6 to 10 take from their tier (surfaces follow the tier, geometry the
## level), one row per tier from Chrome, a lower tier taking Chrome's: [plating, rail, the strip
## along the top, lamp, field, crystal, trim] (Role).
enum Role { PLATING, RAIL, STRIP, LAMP, FIELD, CRYSTAL, TRIM }
static var PALETTES: Array[Array] = [
	[Parts.CHROME, Parts.CHROME, ENERGY_BRIGHT, Parts.CYAN_STRIP, FIELD, Parts.CYAN_STRIP, Parts.CHROME],
	[Parts.OBSIDIAN, Parts.OBSIDIAN, VEIN_STRIP, VIOLET_LAMP, VIOLET_FIELD, SHARD, GOLD],
	[Parts.OBSIDIAN, Parts.FILIGREE, VEIN_STRIP, Parts.CORE_GLOW, VIOLET_FIELD, SHARD, GOLD],
]

## Built pieces by ((tier * 16 + level) * 16 + mask) * 16 + lower_mask.
static var _pieces: Dictionary[int, Piece] = {}


## A piece's surface arrays (LowPolyMesh.to_arrays and to_outline_arrays), shared by every
## wall it is drawn for; WallMesh copies them into the merged mesh.
class Piece:
	var body: Array
	var outline: Array


## The piece for `level`, built for its `tier` (BuildingModels.tier_of), and `mask`, its
## segments towards the neighbours in `lower_mask` (walls whose solid_top() is lower, a subset of
## `mask`) ending in an outlined step; built on first use and kept, by tier, level and masks. The
## body is the same whatever `lower_mask` says: only the outline differs.
static func piece(level: int, tier: int, mask: int, lower_mask: int = 0) -> Piece:
	var shown := clampi(level, 1, LEVELS)
	var key := ((tier * 16 + shown) * 16 + mask) * 16 + lower_mask
	var built: Piece = _pieces.get(key)
	if built == null:
		var m := LowPolyMesh.new()
		_add_piece(m, shown, tier, mask, lower_mask)
		built = Piece.new()
		built.body = m.to_arrays()
		built.outline = m.to_outline_arrays()
		_pieces[key] = built
	return built


## A wall's own model: the lone post.
static func build_barrier_wall(p: Parts, level: int) -> void:
	_add_piece(p.body, level, p.tier, 0)


static func _add_piece(m: LowPolyMesh, level: int, tier: int, mask: int, lower_mask: int = 0) -> void:
	_post(m, level, tier)
	for bit: int in NEIGHBOURS.size():
		if mask & (1 << bit) != 0:
			_segments(m, level, tier, bit, lower_mask & (1 << bit) != 0)


## The footing, the post, its cap and, on level 5, the crown, gold from the Gold tier; levels 6
## to 10 in their tier's surfaces (_tier_post).
static func _post(m: LowPolyMesh, level: int, tier: int) -> void:
	var spec: Array = POSTS[level - 1]
	var width: float = spec[0]
	var top: float = spec[1]
	var chamfer: float = spec[2]
	var cap_width: float = spec[3]
	var cap_height: float = spec[4]
	m.box_chamfered(Vector3(FOOTING_WIDTH, FOOTING_HEIGHT, FOOTING_WIDTH), 0.03, Vector3.ZERO, CONCRETE)
	if level > FIELD_LEVEL:
		_tier_post(m, level, tier, width, top, chamfer, cap_width, cap_height)
		return
	var surf: Surf = [POST, POST, POST_RIBBED, POST_PLATED, POST_PLATED][level - 1]
	m.box_chamfered(Vector3(width, top - FOOTING_HEIGHT, width), chamfer, Vector3(0, FOOTING_HEIGHT, 0), surf)
	if cap_width > 0.0:
		m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.02, Vector3(0, top, 0), CAP)
	if level == FIELD_LEVEL:
		m.box_chamfered(Vector3(CROWN.x, CROWN.y, CROWN.x), 0.03, Vector3(0, top + cap_height, 0),
			GOLD if tier >= Parts.Tier.GOLD else CAP)


## Levels 6 to 10's post on its footing: L6 a chrome post with a chamfered cap over a band of
## cyan lamps; L7 taller and heavier, chrome fins up its corners, its cap a raised hip over a
## taller lamp band and crowned with a glowing cyan lens; L8 obsidian, a glowing crystal shard on
## its cap over a tall violet lamp band; L9 a cap half again as thick, two shards leaning apart
## and crystal inlays up its four corners; L10 the inlays, a gold cap and on it a gold crown cup
## with four points holding a violet core bead. A lamp band is a course of the post itself, as
## wide as it, between its body and its cap.
static func _tier_post(m: LowPolyMesh, level: int, tier: int, width: float, top: float, chamfer: float,
		cap_width: float, cap_height: float) -> void:
	var palette := _palette(tier)
	var plating: Surf = palette[Role.PLATING]
	var lamp: Surf = palette[Role.LAMP]
	var crystal: Surf = palette[Role.CRYSTAL]
	var trim: Surf = palette[Role.TRIM]
	var band: float = LAMP_BANDS[level - FIELD_LEVEL - 1]
	m.box_chamfered(Vector3(width, top - band - FOOTING_HEIGHT, width), chamfer, Vector3(0, FOOTING_HEIGHT, 0), plating)
	if band > 0.0:
		m.box(Vector3(width, band, width), Vector3(0, top - band, 0), lamp)
	var cap_top := top + cap_height
	match level:
		6:
			m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.03, Vector3(0, top, 0), plating)
		7:
			m.prism(cap_width * 0.5 * sqrt(2.0), 0.15, cap_height, 4, Vector3(0, top, 0), plating, Vector3(0, 45, 0))
			m.prism(0.15, 0.1, 0.14, 8, Vector3(0, cap_top, 0), lamp, Parts.OCTAGON)
			_corners(m, width, top, plating)
		8:
			m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.03, Vector3(0, top, 0), plating)
			_shard(m, Vector3(0, cap_top, 0), 0.2, 0.09, Vector3.ZERO, crystal)
		9:
			m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.04, Vector3(0, top, 0), plating)
			_shard(m, Vector3(-0.08, cap_top, 0.08), 0.2, 0.08, Vector3(-14, 0, 14), crystal)
			_shard(m, Vector3(0.08, cap_top, -0.08), 0.17, 0.07, Vector3(14, 30, -14), crystal.phased(0.5))
			_corners(m, width, top, crystal)
		10:
			m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.03, Vector3(0, top, 0), trim)
			_corners(m, width, top, crystal)
			m.prism(0.11, 0.15, 0.07, 8, Vector3(0, cap_top, 0), trim, Parts.OCTAGON)
			for k: int in 4:
				m.pyramid(0.05, 0.07, Parts.around(0.13, 45 + 90 * k, cap_top + 0.07), trim)
			m.orb(0.075, 8, 4, Vector3(0, cap_top + 0.1, 0), lamp)


## A crystal shard: a six-sided column tapering to a point from `foot`, turned by `rot`.
static func _shard(m: LowPolyMesh, foot: Vector3, height: float, radius: float, rot: Vector3, surf: Surf) -> void:
	m.lathe(PackedVector2Array([Vector2(radius * 0.8, 0), Vector2(radius, height * 0.3), Vector2(0, height)]), 6,
		foot, surf, rot)


## Fins or inlays up the post's four corners, from its footing to `top`: two thin boxes crossing
## on the diagonals, their ends standing out of the chamfered corners.
static func _corners(m: LowPolyMesh, width: float, top: float, surf: Surf) -> void:
	var size := Vector3(0.05, top - FOOTING_HEIGHT - 0.04, width * 0.5 * sqrt(2.0) * 2.0 - 0.04)
	for yaw: float in [45.0, -45.0]:
		m.box(size, Vector3(0, FOOTING_HEIGHT, 0), surf, Vector3(0, yaw, 0))


## The surfaces of `tier` for levels 6 to 10 (PALETTES, by Role).
static func _palette(tier: int) -> Array:
	return PALETTES[clampi(tier - Parts.Tier.CHROME, 0, PALETTES.size() - 1)]


## How high the solid part of a level's segment stands: the segment's top, or on level 5 the
## top of the low slab under its unoutlined field. A wall's segment steps down to a
## neighbour whose solid top is lower (WallMesh's lower mask).
static func solid_top(level: int) -> float:
	var shown := clampi(level, 1, LEVELS)
	var top := SEGMENT_SHARE * _post_height(shown)
	if shown != FIELD_LEVEL:
		return top
	return CURB_TOP.y + SLAB_SHARE * (top - CURB_TOP.y)


## The half-segment toward neighbour `bit`, in the level's style, on the shared curb. A `step`
## (the neighbour's solid segment is lower) outlines its end caps but the curb's.
static func _segments(m: LowPolyMesh, level: int, tier: int, bit: int, step: bool) -> void:
	_sweep(m, bit, _trapezoid(CURB_FOOT, CURB_TOP), 0.0, CONCRETE, false)
	var base := CURB_TOP.y
	var top := SEGMENT_SHARE * _post_height(level)
	var height := top - base
	match level:
		1:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE, step)
		2:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE_RIVETED, step)
			var band := Vector2(SEGMENT_HALF + 0.02, 0.25 * height)
			_sweep(m, bit, _trapezoid(Vector2(band.x, 0.0), band), base + 0.35 * height, SLATE, step)
		3:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE_RIBBED, step)
			_strip(m, bit, 0.1, top, ENERGY)
		4:
			var skirt := 0.45 * height
			_sweep(m, bit, _trapezoid(Vector2(SEGMENT_HALF + 0.02, 0.0), Vector2(SEGMENT_HALF, skirt)),
				base, SLATE_RIVETED, step)
			_sweep(m, bit, _chamfered(SEGMENT_HALF - 0.03, height - skirt, 0.04), base + skirt, SLATE, step)
			_strip(m, bit, 0.12, top, ENERGY_BRIGHT)
		5:
			# A low plated base, and the energy field above it.
			var slab := SLAB_SHARE * height
			_sweep(m, bit, _chamfered(SEGMENT_HALF, slab, 0.03), base, SLATE_RIVETED, step)
			_sweep(m, bit, _trapezoid(Vector2(0.03, 0.0), Vector2(0.03, height - slab)), base + slab, FIELD, step)
		_:
			_tier_segments(m, level, tier, bit, step, base, top)


## Levels 6 to 10's half-segment above the curb, in its tier's surfaces, its solid top `top`: L6 a
## chrome slab on a sloped skirt with a cyan strip along the top; L7 a heavier battered chrome slab,
## wider at its foot, with a strip along its top and another across both its faces, so a run of
## it glows along its sides; L8 an obsidian
## wall, a glowing violet field between a low rail and a chamfered top rail, a broad vein strip
## along it; L9 the field wider between thinner rails, the low rail heavier, the strip broader;
## L10 L9's wall with gold filigree rails.
static func _tier_segments(m: LowPolyMesh, level: int, tier: int, bit: int, step: bool, base: float,
		top: float) -> void:
	var palette := _palette(tier)
	var plating: Surf = palette[Role.PLATING]
	var rail: Surf = palette[Role.RAIL]
	var strip: Surf = palette[Role.STRIP]
	var field: Surf = palette[Role.FIELD]
	var height := top - base
	if level == 6:
		var skirt := 0.3 * height
		_sweep(m, bit, _trapezoid(Vector2(SEGMENT_HALF + 0.02, 0.0), Vector2(SEGMENT_HALF, skirt)), base, plating, step)
		_sweep(m, bit, _chamfered(SEGMENT_HALF - 0.02, height - skirt, 0.05), base + skirt, plating, step)
		_strip(m, bit, 0.14, top, strip)
		return
	if level == 7:
		# A battered slab, wider at its foot, a strip along its top and one across both its faces.
		var foot := SEGMENT_HALF + 0.03
		var shoulder := SEGMENT_HALF - 0.02
		_sweep(m, bit, PackedVector2Array([Vector2(-foot, 0.0), Vector2(-shoulder, height - 0.05),
			Vector2(-shoulder + 0.05, height), Vector2(shoulder - 0.05, height), Vector2(shoulder, height - 0.05),
			Vector2(foot, 0.0)]), base, plating, step)
		_strip(m, bit, 2.0 * (shoulder - 0.05) - 0.06, top, strip)
		var face := 0.4 * height
		var across := lerpf(foot, shoulder, face / (height - 0.05))
		_strip(m, bit, 2.0 * across + 0.02, base + face, strip, 0.1)
		return
	var rails := (0.22 if level == 8 else 0.16) * height
	var heavy := 0.02 if level == 8 else 0.035
	_sweep(m, bit, _trapezoid(Vector2(SEGMENT_HALF + heavy, 0.0), Vector2(SEGMENT_HALF, rails)), base, rail, step)
	_sweep(m, bit, _trapezoid(Vector2(SEGMENT_HALF - 0.02, 0.0), Vector2(SEGMENT_HALF - 0.02, height - 2.0 * rails)),
		base + rails, field, step)
	_sweep(m, bit, _chamfered(SEGMENT_HALF, rails, 0.04), top - rails, rail, step)
	_strip(m, bit, 0.24 if level == 8 else 0.3, top, strip)


## An energy strip `width` wide and `height` high on the half-segment toward neighbour `bit`, its
## foot at height `y`: a box built along its own z and turned onto world +x or +z, so its top's texture
## V runs along the wall the same way on both halves of every segment and a FLOW current runs on
## from one wall to the next. (A swept face takes its UVs in the piece's space, where a strip
## along x would have its glow stripes running along it, and its flow across.)
static func _strip(m: LowPolyMesh, bit: int, width: float, y: float, surf: Surf, height: float = 0.025) -> void:
	var along := Vector3(NEIGHBOURS[bit].x, 0, NEIGHBOURS[bit].y)
	var length := 0.5 - SEGMENT_FROM
	var yaw := 90.0 if along.x != 0.0 else 0.0
	m.box(Vector3(width, height, length), along * (SEGMENT_FROM + 0.5) * 0.5 + Vector3(0, y, 0), surf,
		Vector3(0, yaw, 0))


## The post's height, which its segments take a share of: its body, its cap and, on level 5, the
## crown (the shards and the crown cup above levels 6 to 10's caps stand clear of it).
static func _post_height(level: int) -> float:
	var spec: Array = POSTS[level - 1]
	var top: float = spec[1]
	var cap_height: float = spec[4]
	return top + cap_height + (CROWN.y if level == FIELD_LEVEL else 0.0)


## A cross-section with chamfered top edges, `half` wide each side and `height` tall.
static func _chamfered(half: float, height: float, chamfer: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half, 0.0), Vector2(-half, height - chamfer), Vector2(-half + chamfer, height),
		Vector2(half - chamfer, height), Vector2(half, height - chamfer), Vector2(half, 0.0),
	])


## A cross-section `foot` (half width, 0) at the bottom and `top` (half width, height) above.
static func _trapezoid(foot: Vector2, top: Vector2) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-foot.x, 0.0), Vector2(-top.x, top.y), Vector2(top.x, top.y),
		Vector2(foot.x, 0.0)])


## Sweeps `profile`, a convex cross-section of (across, height) points from one bottom corner
## over the top to the other, from SEGMENT_FROM to the cell edge toward neighbour `bit`, lifted
## by `y`. The bottom and the end inside the post are left out; the end on the cell edge is a
## cap in the same paint and phase, left out of the outline unless it is `inked` (a step down to
## a lower wall) and the segment is outlined.
static func _sweep(m: LowPolyMesh, bit: int, profile: PackedVector2Array, y: float, surf: Surf,
		inked: bool) -> void:
	var along := Vector3(NEIGHBOURS[bit].x, 0, NEIGHBOURS[bit].y)
	var across := Vector3(along.z, 0, -along.x)
	var inner := PackedVector3Array()
	var outer := PackedVector3Array()
	var middle := Vector2.ZERO
	for point: Vector2 in profile:
		var offset := across * point.x + Vector3(0, y + point.y, 0)
		inner.append(along * SEGMENT_FROM + offset)
		outer.append(along * 0.5 + offset)
		middle += point / profile.size()
	var axis := across * middle.x + Vector3(0, y + middle.y, 0)
	for i: int in profile.size() - 1:
		var side := PackedVector3Array([inner[i], outer[i], outer[i + 1], inner[i + 1]])
		var out := (inner[i] + inner[i + 1]) * 0.5 - along * SEGMENT_FROM - axis
		m.polygon(_facing(side, out), surf)
	var cap := Surf.make(surf.layer, surf.tint, surf.uv_scale, surf.flags, surf.smooth, inked and surf.outline,
		surf.phase)
	m.polygon(_facing(outer, along), cap)


## `corners` (a convex face) in the order that faces `out`.
static func _facing(corners: PackedVector3Array, out: Vector3) -> PackedVector3Array:
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(out) < 0.0:
		corners.reverse()
	return corners
