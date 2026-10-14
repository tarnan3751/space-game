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

const PLUS_X := 1
const MINUS_X := 2
const PLUS_Z := 4
const MINUS_Z := 8
const NEIGHBOURS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
## The levels with a look of their own; a higher level shows the top one.
const LEVELS := 5
## The glow strip of a wall, by level.
const WALL_GLOWS := ["glow_cyan", "glow_green", "glow_magenta", "glow_red", "glow_gold"]
## A half-segment runs from inside the post to the cell edge, SEGMENT_WIDTH across, and stands
## SEGMENT_DROP lower than the post's body.
const SEGMENT_FROM := 0.3
const SEGMENT_WIDTH := 0.6
const SEGMENT_DROP := 0.12

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
	var height := 0.5 + 0.06 * level
	m.box(Vector3(0.86, height, 0.86), Vector3.ZERO, Parts.surf("hull"))
	m.box(Vector3(0.74, 0.22, 0.74), Vector3(0, height, 0), Parts.surf("hull_light"))
	m.box(Vector3(0.76, 0.06, 0.34), Vector3(0, height + 0.2, 0), Parts.surf(WALL_GLOWS[level - 1]))
	var length := 0.5 - SEGMENT_FROM
	for bit: int in NEIGHBOURS.size():
		if mask & (1 << bit) == 0:
			continue
		var along := Vector3(NEIGHBOURS[bit].x, 0, NEIGHBOURS[bit].y)
		var across := Vector3(absf(along.z), 0, absf(along.x))
		var size := along.abs() * length + across * SEGMENT_WIDTH + Vector3(0, height - SEGMENT_DROP, 0)
		m.box(size, along * (SEGMENT_FROM + length * 0.5), Parts.surf("hull_dark"))
