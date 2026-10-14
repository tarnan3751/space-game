extends RefCounted
## Wall models, one piece per level and neighbour mask. A piece is a post on the cell centre
## and, for each neighbour in its mask, a half-segment from the post to that cell edge, lower
## than the post, so two adjacent walls meet on their shared edge and each draws its own
## level's style. WallMesh merges the pieces of every finished wall into one mesh;
## BuildingModels.create("barrier_wall", level, 1) is the lone post (mask 0), which the paint
## brush, a lifted wall and the gallery show.
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
## double-plated segments with a brighter strip; L5 a gold crown on the cap and an energy field
## above a low plated base. Caps are never wider than their post. Every segment ends on the cell
## edge in a cap left out of the ink outline, so two segments that meet there draw one unbroken
## outline, and every level shares the curb, so mixed levels still meet at the base.

const PLUS_X := 1
const MINUS_X := 2
const PLUS_Z := 4
const MINUS_Z := 8
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The levels with a look of their own; a higher level shows the top one.
const LEVELS := 5
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

## Per level: [post width, body top, post chamfer, cap width (0 for none), cap height]. A post
## is at most 0.46 of the cell and its cap never wider than it.
const POSTS := [
	[0.42, 0.55, 0.05, 0.0, 0.0],
	[0.44, 0.6, 0.05, 0.4, 0.04],
	[0.45, 0.67, 0.05, 0.41, 0.05],
	[0.46, 0.76, 0.08, 0.42, 0.05],
	[0.46, 0.76, 0.06, 0.42, 0.04],
]
## The top level's gold crown on the cap: width and height.
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
## Emissive strips and the field are too thin to ink.
static var ENERGY := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY, 1.0, Surf.UNLIT, false, false)
static var ENERGY_BRIGHT := Surf.make(MaterialKit.Layer.GLOW, MaterialKit.ENERGY.lightened(0.4), 1.0,
	Surf.UNLIT, false, false)

## Built pieces by level * 16 + mask.
static var _pieces: Dictionary[int, Piece] = {}


## A piece's surface arrays (LowPolyMesh.to_arrays and to_outline_arrays), shared by every
## wall it is drawn for; WallMesh copies them into the merged mesh.
class Piece:
	var body: Array
	var outline: Array


## The piece for `level` and `mask`, built on first use and kept (LEVELS * 16 at most).
static func piece(level: int, mask: int) -> Piece:
	var shown := clampi(level, 1, LEVELS)
	var key := shown * 16 + mask
	var built: Piece = _pieces.get(key)
	if built == null:
		var m := LowPolyMesh.new()
		_add_piece(m, shown, mask)
		built = Piece.new()
		built.body = m.to_arrays()
		built.outline = m.to_outline_arrays()
		_pieces[key] = built
	return built


## A wall's own model: the lone post.
static func build_barrier_wall(p: Parts, level: int) -> void:
	_add_piece(p.body, level, 0)


static func _add_piece(m: LowPolyMesh, level: int, mask: int) -> void:
	_post(m, level)
	for bit: int in NEIGHBOURS.size():
		if mask & (1 << bit) != 0:
			_segments(m, level, bit)


## The footing, the post, its cap and, on the top level, the crown.
static func _post(m: LowPolyMesh, level: int) -> void:
	var spec: Array = POSTS[level - 1]
	var width: float = spec[0]
	var top: float = spec[1]
	var chamfer: float = spec[2]
	var cap_width: float = spec[3]
	var cap_height: float = spec[4]
	m.box_chamfered(Vector3(FOOTING_WIDTH, FOOTING_HEIGHT, FOOTING_WIDTH), 0.03, Vector3.ZERO, CONCRETE)
	var surf: Surf = [POST, POST, POST_RIBBED, POST_PLATED, POST_PLATED][level - 1]
	m.box_chamfered(Vector3(width, top - FOOTING_HEIGHT, width), chamfer, Vector3(0, FOOTING_HEIGHT, 0), surf)
	if cap_width > 0.0:
		m.box_chamfered(Vector3(cap_width, cap_height, cap_width), 0.02, Vector3(0, top, 0), CAP)
	if level >= LEVELS:
		m.box_chamfered(Vector3(CROWN.x, CROWN.y, CROWN.x), 0.03, Vector3(0, top + cap_height, 0), GOLD)


## The half-segment toward neighbour `bit`, in the level's style, on the shared curb.
static func _segments(m: LowPolyMesh, level: int, bit: int) -> void:
	_sweep(m, bit, _trapezoid(CURB_FOOT, CURB_TOP), 0.0, CONCRETE)
	var base := CURB_TOP.y
	var top := SEGMENT_SHARE * _post_height(level)
	var height := top - base
	match level:
		1:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE)
		2:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE_RIVETED)
			var band := Vector2(SEGMENT_HALF + 0.02, 0.25 * height)
			_sweep(m, bit, _trapezoid(Vector2(band.x, 0.0), band), base + 0.35 * height, SLATE)
		3:
			_sweep(m, bit, _chamfered(SEGMENT_HALF, height, 0.04), base, SLATE_RIBBED)
			_sweep(m, bit, _trapezoid(Vector2(0.05, 0.0), Vector2(0.05, 0.025)), top, ENERGY)
		4:
			var skirt := 0.45 * height
			_sweep(m, bit, _trapezoid(Vector2(SEGMENT_HALF + 0.02, 0.0), Vector2(SEGMENT_HALF, skirt)),
				base, SLATE_RIVETED)
			_sweep(m, bit, _chamfered(SEGMENT_HALF - 0.03, height - skirt, 0.04), base + skirt, SLATE)
			_sweep(m, bit, _trapezoid(Vector2(0.06, 0.0), Vector2(0.06, 0.025)), top, ENERGY_BRIGHT)
		_:
			# A low plated base, and the energy field above it.
			var slab := 0.4 * height
			_sweep(m, bit, _chamfered(SEGMENT_HALF, slab, 0.03), base, SLATE_RIVETED)
			_sweep(m, bit, _trapezoid(Vector2(0.03, 0.0), Vector2(0.03, height - slab)), base + slab, ENERGY)


## The post's full height: its body, its cap and, on the top level, the crown.
static func _post_height(level: int) -> float:
	var spec: Array = POSTS[level - 1]
	var top: float = spec[1]
	var cap_height: float = spec[4]
	return top + cap_height + (CROWN.y if level >= LEVELS else 0.0)


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
## cap in the same paint, left out of the outline.
static func _sweep(m: LowPolyMesh, bit: int, profile: PackedVector2Array, y: float, surf: Surf) -> void:
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
	var cap := Surf.make(surf.layer, surf.tint, surf.uv_scale, surf.flags, surf.smooth, false)
	m.polygon(_facing(outer, along), cap)


## `corners` (a convex face) in the order that faces `out`.
static func _facing(corners: PackedVector3Array, out: Vector3) -> PackedVector3Array:
	if (corners[1] - corners[0]).cross(corners[2] - corners[0]).dot(out) < 0.0:
		corners.reverse()
	return corners
