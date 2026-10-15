extends SceneTree
## Draws the material kit: the 16 layers of the Texture2DArray every building, the terrain and
## the rocks are painted from (docs/reference/art-style.md, **The material kit**), saved as
## assets/textures/kit/<index>_<name>.png; and the field texture the buildable ground is drawn
## from, assets/textures/field.png (**The field**). Run it after an import (tools/gates.sh does
## one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/gen_textures.gd
##
## Each layer is SIZE x SIZE RGBA8. RGB is the albedo: near-white greys (0.78 to 1.0, ink lines
## at the ink colour) for the layers a tint multiplies, real colours for the fixed ones (hazard,
## solar). A is the emission mask: 0 on plain surfaces, up to 1 where the surface glows. The
## field texture is FIELD_SIZE square, an atlas of four plates, and holds weights, not colours
## (_draw_field).
##
## Everything is drawn from SEED with SeededRng, so a run gives byte-identical PNGs. Every
## primitive wraps modulo the image's size, so every layer tiles seamlessly; the field's plates
## keep their marks off their edges instead. One layer covers one world unit at the default UV
## scale: an ink line of INK_WIDTH pixels is about 0.012 units wide.

const SIZE := 256
const SEED := 20261014
const OUT_DIR := "res://assets/textures/kit"
## The field texture: an atlas of four landing plates of the ground (4x4 cells each), drawn after
## the kit from its own seed.
const FIELD_PATH := "res://assets/textures/field.png"
const FIELD_SIZE := 1024
## A plate's tile in the field atlas (TILE_CELL pixels a cell), how far its marks keep from its
## edges and from each other, and the plus or minus of its grain.
const TILE := 512
const TILE_CELL := 128
const TILE_MARGIN := 12.0
const MARK_GAP := 6.0
const FIELD_GRAIN := 0.04
## A bolt's radius; and the stipple's lattice, how far in from its side it thins out to nothing,
## and its dots' chance in a hundred at the side.
const BOLT := 7.0
const STIPPLE_STEP := 4
const STIPPLE_DEPTH := TILE_CELL * 6 / 10
const STIPPLE_DENSITY := 60
## The four plates, tile q at column q % 2 and row q / 2 of the atlas, each: its crater's radius
## (0 for none) and the cracks running out from its rim, its pits, loose cracks and pebbles, how
## many sides are stippled, and whether it has a joint with a bolt in each corner, and a patch.
const PLATES := [
	[0, 0, 3, 1, 6, 1, false, false],
	[45, 0, 2, 0, 4, 0, true, false],
	[64, 2, 3, 0, 8, 0, false, false],
	[45, 0, 0, 1, 5, 2, false, true],
]
## The layers, in array order. MaterialKit.LAYERS must match.
const LAYERS := [
	"flat", "hull", "hull_dense", "plate", "vent", "pipe", "grating", "concrete",
	"hazard", "solar", "glass", "glow", "screen", "crystal", "rock", "regolith",
]
const INK := Color("1b1a2e")
const INK_WIDTH := 3.0
const HAZARD_YELLOW := Color("ffd60a")
## Towards the key light across the ground, in the ground's texture space (u along world x, v
## along world z, so image y is world z): the rock's plates and the dust's pebbles are shaded from
## it. The field texture is not: the ground shader lights its lean.
const SUN := Vector2(-0.5, 0.866)

var _rgb := PackedColorArray()
var _mask := PackedFloat32Array()
var _rng: SeededRng
## The size of the image being drawn.
var _width: int = SIZE
var _height: int = SIZE


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for index: int in LAYERS.size():
		var layer_name: String = LAYERS[index]
		_begin(SIZE, SIZE, SEED + index)
		call("_draw_" + layer_name)
		if not _save(OUT_DIR.path_join("%02d_%s.png" % [index, layer_name])):
			return
	_begin(FIELD_SIZE, FIELD_SIZE, SEED + LAYERS.size())
	_draw_field()
	if not _save(FIELD_PATH):
		return
	quit(0)


func _begin(width: int, height: int, image_seed: int) -> void:
	_width = width
	_height = height
	_rgb.resize(width * height)
	_mask.resize(width * height)
	_mask.fill(0.0)
	_rng = SeededRng.new(image_seed)


func _save(path: String) -> bool:
	var error := _image().save_png(path)
	if error != OK:
		printerr("gen_textures: could not save %s: %s" % [path, error_string(error)])
		quit(1)
		return false
	print("gen_textures: %s" % path)
	return true


# --- Layers ------------------------------------------------------------------------

func _draw_flat() -> void:
	_fill(_grey(0.95))
	_grain(0.025, 32)
	_grain(0.012, 1)


## Large panels in two staggered rows, a lit and a shaded inner edge on each, ink seams and a
## rivet in each corner.
func _draw_hull() -> void:
	_fill(_grey(0.95))
	var rows: Array[PackedInt32Array] = [PackedInt32Array([0, 160]), PackedInt32Array([32, 96])]
	for row: int in rows.size():
		_panel_row(rows[row], row * 128, 128, 2, 8, true)
	_grain(0.02, 32)


## Smaller panels in four staggered rows, rivets on every corner and slotted vents on a few.
func _draw_hull_dense() -> void:
	_fill(_grey(0.94))
	for row: int in 4:
		var offset := 32 * (row % 2) + 16 * (row / 2)
		_panel_row(PackedInt32Array([offset, offset + 64, offset + 128, offset + 192]), row * 64, 64, 2, 6, true)
	for i: int in 3:
		var row := _rng.range_int(0, 3)
		var x := 64 * _rng.range_int(0, 3) + 32 * (row % 2) + 16 * (row / 2) + 16
		var y := 64 * row + 18
		for slot: int in 4:
			_rect(x, y + slot * 7, 32, 3, INK)
			_rect(x, y + slot * 7 + 3, 32, 1, _grey(1.0))
	_grain(0.02, 32)


## Bolted armour plates: a chamfer band lit along the top and left, shaded along the bottom and
## right, ink seams and a bolt in each corner.
func _draw_plate() -> void:
	_fill(_grey(0.9))
	var k := 7.0
	for py: int in 2:
		for px: int in 2:
			var a := Vector2(px * 128.0, py * 128.0)
			var b := a + Vector2(128, 0)
			var c := a + Vector2(128, 128)
			var d := a + Vector2(0, 128)
			_rect(int(a.x), int(a.y), 128, 128, _grey(0.88 + _rng.range_int(0, 6) / 100.0))
			var a2 := a + Vector2(k, k)
			var b2 := b + Vector2(-k, k)
			var c2 := c + Vector2(-k, -k)
			var d2 := d + Vector2(k, -k)
			_polygon(PackedVector2Array([a, b, b2, a2]), _grey(1.0))
			_polygon(PackedVector2Array([a, a2, d2, d]), _grey(0.98))
			_polygon(PackedVector2Array([d2, c2, c, d]), _grey(0.8))
			_polygon(PackedVector2Array([b2, b, c, c2]), _grey(0.82))
			for corner: Vector2 in [a2 + Vector2(9, 9), b2 + Vector2(-9, 9), c2 + Vector2(-9, -9), d2 + Vector2(9, -9)]:
				_rivet(corner)
	for i: int in 3:
		_line(Vector2(0, 128 * i), Vector2(SIZE, 128 * i), INK_WIDTH, INK)
		_line(Vector2(128 * i, 0), Vector2(128 * i, SIZE), INK_WIDTH, INK)
	_grain(0.02, 32)


## A louvred grille: slats lit along their top edge, an ink gap under each, a frame every half
## unit.
func _draw_vent() -> void:
	_fill(_grey(0.9))
	for y: int in range(0, SIZE, 16):
		for t: int in 10:
			_rect(0, y + t, SIZE, 1, _grey(1.0 - 0.014 * t))
		_rect(0, y + 10, SIZE, 3, INK)
		_rect(0, y + 13, SIZE, 3, _grey(0.8))
	for x: int in [0, 128]:
		_rect(x - 1, 0, 3, SIZE, INK)
		_rect(x + 2, 0, 2, SIZE, _grey(0.98))


## Ribbed bands across V, so on a lathe (U around the axis) they wrap the cylinder.
func _draw_pipe() -> void:
	for y: int in range(0, SIZE, 64):
		for t: int in 64:
			_rect(0, y + t, SIZE, 1, _grey(0.98 - 0.12 * absf(t - 24.0) / 40.0))
		_rect(0, y - 1, SIZE, 3, INK)
		_rect(0, y + 2, SIZE, 3, _grey(1.0))
	_grain(0.01, 16)


## Floor grating: staggered ink slots with a lit lip under each, a frame every half unit.
func _draw_grating() -> void:
	_fill(_grey(0.94))
	_grain(0.012, 32)
	for row: int in 16:
		var offset := 16 * (row % 2)
		for column: int in 8:
			var x := column * 32 + offset + 4
			var y := row * 16 + 4
			_rect(x, y, 24, 8, INK)
			_rect(x, y + 8, 24, 1, _grey(1.0))
	for i: int in 2:
		_rect(128 * i - 2, 0, 4, SIZE, _grey(0.86))
		_rect(0, 128 * i - 2, SIZE, 4, _grey(0.86))
		_line(Vector2(128 * i - 3, 0), Vector2(128 * i - 3, SIZE), 1.5, INK)
		_line(Vector2(0, 128 * i - 3), Vector2(SIZE, 128 * i - 3), 1.5, INK)


## A slab per unit: blotchy grit, a few hairline cracks, an ink expansion joint at the edge.
func _draw_concrete() -> void:
	_fill(_grey(0.9))
	_grain(0.035, 64)
	_grain(0.02, 16)
	_grain(0.012, 1)
	for i: int in 500:
		var spot := Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1))
		var light := _rng.range_int(0, 2) == 0
		_disc(spot, _rng.range_int(5, 12) / 10.0, _grey(0.98 if light else 0.8 + _rng.range_int(0, 6) / 100.0))
	for i: int in 3:
		_crack(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), 4, 1.2, _grey(0.78))
	_line(Vector2(0, 0), Vector2(SIZE, 0), INK_WIDTH, INK)
	_line(Vector2(0, 0), Vector2(0, SIZE), INK_WIDTH, INK)
	_rect(2, 2, SIZE - 2, 2, _grey(1.0))
	_rect(2, 2, 2, SIZE - 2, _grey(1.0))


## Hazard yellow and ink stripes at 45 degrees, a period of a quarter unit.
func _draw_hazard() -> void:
	for y: int in SIZE:
		for x: int in SIZE:
			# Distance to the nearest stripe edge along the diagonal, in pixels.
			var along := fposmod(x + y + 1.0, 64.0)
			var edge := minf(absf(along - 32.0), minf(along, 64.0 - along)) / sqrt(2.0)
			var yellow := along < 32.0
			var coverage := clampf(edge + 0.5, 0.0, 1.0)
			var inside := HAZARD_YELLOW if yellow else INK
			var outside := INK if yellow else HAZARD_YELLOW
			_rgb[y * SIZE + x] = outside.lerp(inside, coverage)


## Blue photovoltaic cells: ink gaps, two busbars a cell, an aluminium frame every half unit.
func _draw_solar() -> void:
	_fill(INK)
	for cy: int in 8:
		for cx: int in 8:
			var x := cx * 32 + 2
			var y := cy * 32 + 2
			for t: int in 28:
				_rect(x, y + t, 28, 1, Color("2f5dba").lerp(Color("21458f"), t / 27.0))
			_rect(x, y, 28, 1, Color("5383db"))
			for bar: int in [9, 18]:
				_rect(x + bar, y, 1, 28, Color("8fb3f0"))
	for i: int in 2:
		_rect(128 * i - 2, 0, 4, SIZE, Color("c9cfdb"))
		_rect(0, 128 * i - 2, SIZE, 4, Color("c9cfdb"))


## Pale glass with a wide and a thin diagonal streak; the whole layer glows faintly.
func _draw_glass() -> void:
	_fill(_grey(0.88))
	for y: int in SIZE:
		for x: int in SIZE:
			var along := fposmod(float(x - y), float(SIZE))
			var streak := _band(along, 40.0, 76.0) + _band(along, 90.0, 98.0)
			var i := y * SIZE + x
			_rgb[i] = _rgb[i].lerp(_grey(1.0), clampf(streak, 0.0, 1.0))
			_mask[i] = 0.3


## Fully emissive, with faint stripes across V.
func _draw_glow() -> void:
	_fill(_grey(0.92))
	for y: int in range(0, SIZE, 16):
		_rect(0, y, SIZE, 4, _grey(1.0))
	_mask.fill(1.0)


## A display: ink background, rows of lit segments like text, every other pixel row dimmer.
func _draw_screen() -> void:
	_fill(INK)
	for row: int in range(0, SIZE, 8):
		var bright := 1.0 if _rng.range_int(0, 3) > 0 else 0.86
		var x := _rng.range_int(0, 15)
		while x < SIZE - 8:
			var length := _rng.range_int(8, 48)
			length = mini(length, SIZE - 4 - x)
			_rect(x, row + 2, length, 4, _grey(bright), bright)
			x += length + _rng.range_int(4, 16)
	for y: int in range(1, SIZE, 2):
		for x: int in SIZE:
			var i := y * SIZE + x
			_rgb[i] = _rgb[i] * Color(0.9, 0.9, 0.9, 1.0)


## Faceted shards: a wrapped Voronoi diagram, each facet shaded along its own direction, ink
## along the facet edges, glowing towards each facet's middle.
func _draw_crystal() -> void:
	var seeds := PackedVector2Array()
	var tones := PackedFloat32Array()
	var slopes := PackedVector2Array()
	for gy: int in 4:
		for gx: int in 4:
			seeds.append(Vector2(gx * 64 + _rng.range_int(10, 54), gy * 64 + _rng.range_int(10, 54)))
			tones.append(0.84 + _rng.range_int(0, 14) / 100.0)
			var angle := TAU * _rng.range_int(0, 359) / 360.0
			slopes.append(Vector2(cos(angle), sin(angle)) * 0.0025)
	for y: int in SIZE:
		for x: int in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var nearest := -1
			var second := -1
			var best := INF
			var next := INF
			for s: int in seeds.size():
				var d := _wrapped(seeds[s] - p)
				var distance := d.length_squared()
				if distance < best:
					next = best
					second = nearest
					best = distance
					nearest = s
				elif distance < next:
					next = distance
					second = s
			var to_near := _wrapped(seeds[nearest] - p)
			var to_second := _wrapped(seeds[second] - p)
			# Distance from p to the bisector between the two nearest seeds.
			var edge := (to_second.length_squared() - to_near.length_squared()) / (2.0 * (to_second - to_near).length())
			var tone := clampf(tones[nearest] - slopes[nearest].dot(to_near) * 40.0, 0.78, 1.0)
			var i := y * SIZE + x
			_rgb[i] = _grey(tone).lerp(INK, clampf(INK_WIDTH * 0.5 + 0.5 - edge, 0.0, 1.0))
			_mask[i] = 0.8 * smoothstep(5.0, 18.0, edge)


## Rock at the scale of the terrain's slopes and the scenery rocks: four big plates (a wrapped
## Voronoi diagram) in three tones, each lighter towards the light, parted by faint seams, with
## three bold ink cracks across them and a little dark grit.
func _draw_rock() -> void:
	var seeds := PackedVector2Array()
	var tones := PackedFloat32Array()
	for gy: int in 2:
		for gx: int in 2:
			seeds.append(Vector2(gx * 128 + _rng.range_int(20, 108), gy * 128 + _rng.range_int(20, 108)))
			tones.append([0.84, 0.9, 0.96][_rng.range_int(0, 2)])
	for y: int in SIZE:
		for x: int in SIZE:
			var p := Vector2(x + 0.5, y + 0.5)
			var nearest := 0
			var second := 0
			var best := INF
			var next := INF
			for s: int in seeds.size():
				var distance := _wrapped(seeds[s] - p).length_squared()
				if distance < best:
					next = best
					second = nearest
					best = distance
					nearest = s
				elif distance < next:
					next = distance
					second = s
			var to_near := _wrapped(seeds[nearest] - p)
			var to_second := _wrapped(seeds[second] - p)
			# Distance from p to the bisector between the two nearest seeds.
			var edge := (to_second.length_squared() - to_near.length_squared()) / (2.0 * (to_second - to_near).length())
			var tone := clampf(tones[nearest] - 0.06 * to_near.dot(SUN) / 128.0, 0.8, 1.0)
			_rgb[y * SIZE + x] = _grey(tone).lerp(_grey(0.76), clampf(1.25 - edge, 0.0, 1.0))
	_grain(0.02, 16)
	_grain(0.012, 1)
	for i: int in 3:
		_crack(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), _rng.range_int(5, 8), 3.5, INK)
	for i: int in 40:
		_disc(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), 0.9, _grey(0.76))


## The terrain's dust, at the ring's scale (the terrain takes it at 0.18 repeats a unit): large
## soft blobs in two tones and two pebbles, shaded from SUN. No ink: the ring's craters and ridges
## are its shapes.
func _draw_regolith() -> void:
	var noise := _noise_field([128, 64], [0.7, 0.3])
	for i: int in noise.size():
		_rgb[i] = _grey(lerpf(0.93, 1.0, smoothstep(0.45, 0.6, noise[i])))
	_grain(0.012, 1)
	for i: int in 2:
		var spot := Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1))
		var radius := _rng.range_int(50, 80) / 10.0
		_disc(spot - SUN * radius * 0.55, radius * 0.9, _grey(0.78))
		_disc(spot, radius, _grey(0.88))
		_disc(spot + SUN * radius * 0.3, radius * 0.5, _grey(1.0))


## The ground's field texture: an atlas of four landing plates (PLATES), TILE pixels square, which
## the ground shader picks from and turns per plate (ground.gdshader). Not colours but weights, so
## the tints stay MaterialKit roles, and no light is baked in:
## - R and G, lean: the way the surface's normal leans across the tile (x, y), 0.5 flat, 0 and 1 a
##   full lean of -1 and +1: out from a pebble's or a bolt's middle, in down a crater's wall, out
##   down its rim's outer slope. The shader lights the side leaning towards the sun and shades the
##   side leaning away, however the tile is turned.
## - B, ink: crater and pit rims, pebble outlines, bolt rings, a joint, a patch's border, cracks
##   and stipple.
## - A, tone: 0.5 neutral; below it darker (crater and pit floors, a patch, a joint's one side,
##   stipple), above it lighter (pebbles, bolt heads, a joint's other side); a fine grain over all.
## Every mark is a hard-edged drawn shape (sizes in pixels, TILE_CELL a cell): a crater, radius 45
## or 64, an ink rim 3 wide, its wall leaning in at 0.8 from 0.45 radii, its rim's outer slope, from
## 1.0 to 1.3 radii, leaning out at 0.45, its floor at tone 0.35; a pit, the same at 10 to 19 with a
## rim 2 wide and its floor at 0.4; a pebble, a jittered hexagon of 6 to 15 outlined in 1.5, leaning
## out at 0.7, tone 0.6; a bolt, a disc of BOLT ringed in 1.5, leaning out at 0.6, its head tone
## 0.6; a joint, a line 2 wide right across the plate at 0.3 to 0.7 of it (not on the middle cell
## line), its sides at tone 0.47 and 0.53; a crack, 1.5 wide and 15 to 30 long; a patch, 1 to 1.4
## cells by 0.6 to 0.9, bordered in 2, tone 0.44, a bolt in each corner; stipple, dots 2 across
## thinning out from a side over STIPPLE_DEPTH; grain, FIELD_GRAIN either way on lattices of 8 and
## 16.
## Marks never overlap and keep TILE_MARGIN clear of a tile's edges (but stipple, which runs from
## a side, and a joint, which runs across), so none straddles a seam. The lean is drawn in R and G
## in its own pass, and tone and ink in greys, each in its own pass, read off the red.
func _draw_field() -> void:
	# Craters and pits as (x, y, radius, rim width); pebbles' corners, and each one's (x, y, reach);
	# bolts; joints, each the darker side of its tile, the joint along its inner edge; patches;
	# cracks as (x, y, heading), any way when the heading is negative; stipple dots.
	var bowls: Array[Vector4] = []
	var pebbles: Array[PackedVector2Array] = []
	var pebble_spots: Array[Vector3] = []
	var bolts: Array[Vector2] = []
	var joints: Array[Rect2i] = []
	var patches: Array[Rect2i] = []
	var cracks: Array[Vector3] = []
	var dots: Array[Vector2] = []
	for q: int in PLATES.size():
		var plate: Array = PLATES[q]
		var tile := Rect2i(TILE * (q % 2), TILE * (q / 2), TILE, TILE)
		var inner := Rect2(tile).grow(-TILE_MARGIN)
		# Every mark on this tile so far, as (x, y, reach).
		var taken: Array[Vector3] = []
		var jointed: bool = plate[6]
		if jointed:
			# 0.3 to 0.7 of the way across, clear of the middle cell line.
			var at := TILE / 2 + (1 if _rng.range_int(0, 1) == 0 else -1) * _rng.range_int(20, TILE / 5)
			var upright := _rng.range_int(0, 1) == 0
			joints.append(Rect2i(tile.position, Vector2i(at, TILE) if upright else Vector2i(TILE, at)))
			for k: int in range(0, TILE, 8):
				taken.append(Vector3(tile.position.x + (at if upright else k), tile.position.y + (k if upright else at), 1.0))
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				var bolt := Vector2(tile.position) + Vector2(14.0 + corner.x * (TILE - 28), 14.0 + corner.y * (TILE - 28))
				bolts.append(bolt)
				taken.append(Vector3(bolt.x, bolt.y, BOLT))
		var patched: bool = plate[7]
		if patched:
			var size := Vector2i(_rng.range_int(TILE_CELL, TILE_CELL * 14 / 10),
				_rng.range_int(TILE_CELL * 6 / 10, TILE_CELL * 9 / 10))
			if _rng.range_int(0, 1) == 0:
				size = Vector2i(size.y, size.x)
			var spot := _free_spot(taken, Vector2(size).length() * 0.5, inner)
			taken.append(spot)
			var patch := Rect2i(Vector2i(roundi(spot.x - size.x * 0.5), roundi(spot.y - size.y * 0.5)), size)
			patches.append(patch)
			# A bolt in each corner, inside the border.
			var inset := 2.0 + BOLT + 3.0
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
				bolts.append(Vector2(patch.position) + Vector2(inset + corner.x * (size.x - 2.0 * inset),
					inset + corner.y * (size.y - 2.0 * inset)))
		var crater: int = plate[0]
		var rim_cracks: int = plate[1]
		if crater > 0:
			# The rim's outer slope reaches 1.3 radii, and a crack from the rim up to 30 beyond it.
			var spot := _free_spot(taken, crater + 32.0 if rim_cracks > 0 else crater * 1.3, inner)
			taken.append(spot)
			bowls.append(Vector4(spot.x, spot.y, crater, 3.0))
			var heading := TAU * _rng.range_int(0, 359) / 360.0
			for k: int in rim_cracks:
				var angle := heading + TAU * k / rim_cracks + deg_to_rad(_rng.range_int(-40, 40))
				var out := Vector2(cos(angle), sin(angle)) * (crater + 2.0)
				cracks.append(Vector3(spot.x + out.x, spot.y + out.y, fposmod(angle, TAU)))
		var pits: int = plate[2]
		for k: int in pits:
			var radius := _rng.range_int(10, 19)
			var spot := _free_spot(taken, radius * 1.3, inner)
			taken.append(spot)
			bowls.append(Vector4(spot.x, spot.y, radius, 2.0))
		var loose: int = plate[3]
		for k: int in loose:
			var spot := _free_spot(taken, 30.0, inner)
			taken.append(spot)
			cracks.append(Vector3(spot.x, spot.y, -1.0))
		var pebble_count: int = plate[4]
		for k: int in pebble_count:
			var spot := _free_spot(taken, _rng.range_int(60, 150) / 10.0, inner)
			taken.append(spot)
			pebble_spots.append(spot)
			var corners := PackedVector2Array()
			var turn := TAU * _rng.range_int(0, 59) / 360.0
			for c: int in 6:
				var angle := turn + TAU * c / 6.0
				var reach := spot.z * _rng.range_int(72, 100) / 100.0
				corners.append(Vector2(spot.x, spot.y) + Vector2(cos(angle), sin(angle)) * reach)
			pebbles.append(corners)
		# Stipple along `sides` sides in a row from a random one (0 top, 1 right, 2 bottom, 3 left):
		# dots on a jittered lattice, fewer the further in, none on a mark, and none in the tile's
		# first or last two pixels along the side, so none paints a neighbouring tile.
		var sides: int = plate[5]
		var first := _rng.range_int(0, 3)
		for k: int in sides:
			var side := (first + k) % 4
			for along: int in range(3, TILE - 3, STIPPLE_STEP):
				for depth: int in range(0, STIPPLE_DEPTH, STIPPLE_STEP):
					var chance := roundi(STIPPLE_DENSITY * (1.0 - float(depth) / STIPPLE_DEPTH))
					if _rng.range_int(0, 99) >= chance:
						continue
					var u := along + _rng.range_int(0, 2)
					var v := 1.5 + depth + _rng.range_int(0, 2)
					var dot: Vector2 = Vector2(tile.position) + [Vector2(u, v), Vector2(TILE - v, u),
						Vector2(u, TILE - v), Vector2(v, u)][side]
					var free := true
					for other: Vector3 in taken:
						free = free and dot.distance_to(Vector2(other.x, other.y)) > other.z + MARK_GAP * 0.5
					if free:
						dots.append(dot)

	_fill(Color(0.5, 0.5, 0.0))
	for bowl: Vector4 in bowls:
		var centre := Vector2(bowl.x, bowl.y)
		_lean(centre, bowl.z * 0.45, bowl.z, -0.8)
		_lean(centre, bowl.z, bowl.z * 1.3, 0.45)
	for i: int in pebbles.size():
		_lean(Vector2(pebble_spots[i].x, pebble_spots[i].y), 0.0, pebble_spots[i].z, 0.7, pebbles[i])
	for bolt: Vector2 in bolts:
		_lean(bolt, 0.0, BOLT, 0.6)
	var lean := _rgb.duplicate()

	_fill(_grey(0.5))
	for half: Rect2i in joints:
		_rect(half.position.x, half.position.y, TILE, TILE, _grey(0.53))
		_rect(half.position.x, half.position.y, half.size.x, half.size.y, _grey(0.47))
	for patch: Rect2i in patches:
		_rect(patch.position.x, patch.position.y, patch.size.x, patch.size.y, _grey(0.44))
	for bowl: Vector4 in bowls:
		_disc(Vector2(bowl.x, bowl.y), bowl.z * 0.45, _grey(0.35 if bowl.w > 2.0 else 0.4))
	for corners: PackedVector2Array in pebbles:
		_polygon(corners, _grey(0.6))
	for bolt: Vector2 in bolts:
		_disc(bolt, BOLT * 0.45, _grey(0.6))
	for dot: Vector2 in dots:
		_disc(dot, 1.0, _grey(0.35))
	var tone := _channel()

	_fill(_grey(0.0))
	for half: Rect2i in joints:
		# The joint runs along the darker side's inner edge, its round ends inside the tile.
		var end := Vector2(half.end)
		if half.size.x < TILE:
			_line(Vector2(end.x, half.position.y + 1), Vector2(end.x, end.y - 1), 2.0, _grey(1.0))
		else:
			_line(Vector2(half.position.x + 1, end.y), Vector2(end.x - 1, end.y), 2.0, _grey(1.0))
	for patch: Rect2i in patches:
		_rect(patch.position.x, patch.position.y, patch.size.x, 2, _grey(1.0))
		_rect(patch.position.x, patch.end.y - 2, patch.size.x, 2, _grey(1.0))
		_rect(patch.position.x, patch.position.y, 2, patch.size.y, _grey(1.0))
		_rect(patch.end.x - 2, patch.position.y, 2, patch.size.y, _grey(1.0))
	for bowl: Vector4 in bowls:
		_ring(Vector2(bowl.x, bowl.y), bowl.z, bowl.w, _grey(1.0))
	for corners: PackedVector2Array in pebbles:
		for k: int in corners.size():
			_line(corners[k], corners[(k + 1) % corners.size()], 1.5, _grey(1.0))
	for bolt: Vector2 in bolts:
		_ring(bolt, BOLT - 0.75, 1.5, _grey(1.0))
	for crack: Vector3 in cracks:
		_crack(Vector2(crack.x, crack.y), 3, 1.5, _grey(1.0), Vector2i(5, 10), crack.z)
	for dot: Vector2 in dots:
		_disc(dot, 1.0, _grey(1.0))
	var ink := _channel()

	var grain := _noise_field([8, 16], [0.5, 0.5])
	for i: int in _rgb.size():
		_rgb[i] = Color(lean[i].r, lean[i].g, ink[i], 1.0)
		_mask[i] = tone[i] + FIELD_GRAIN * (2.0 * grain[i] - 1.0)


# --- Shared motifs ------------------------------------------------------------------

## One row of panels between the vertical seams at `seams` (pixels, ascending, wrapping):
## a tone per panel, a lit edge at the top and left, a shaded one at the bottom and right, ink
## seams, and a rivet `inset` pixels in from each corner when `rivets`.
func _panel_row(seams: PackedInt32Array, y: int, height: int, edge: int, inset: int, rivets: bool) -> void:
	for s: int in seams.size():
		var x0 := seams[s]
		var x1 := seams[(s + 1) % seams.size()]
		if x1 <= x0:
			x1 += SIZE
		var width := x1 - x0
		_rect(x0, y, width, height, _grey(0.9 + _rng.range_int(0, 8) / 100.0))
		_rect(x0 + 2, y + 2, width - 4, edge, _grey(1.0))
		_rect(x0 + 2, y + 2, edge, height - 4, _grey(1.0))
		_rect(x0 + 2, y + height - 2 - edge, width - 4, edge, _grey(0.82))
		_rect(x0 + width - 2 - edge, y + 2, edge, height - 4, _grey(0.82))
		if rivets:
			for corner: Vector2 in [
				Vector2(x0 + inset, y + inset), Vector2(x1 - inset, y + inset),
				Vector2(x0 + inset, y + height - inset), Vector2(x1 - inset, y + height - inset),
			]:
				_rivet(corner)
	_line(Vector2(0, y), Vector2(SIZE, y), INK_WIDTH, INK)
	for x: int in seams:
		_line(Vector2(x, y), Vector2(x, y + height), INK_WIDTH, INK)


## A 5 px rivet: a grey disc with a 1 px highlight up and to the left.
func _rivet(centre: Vector2) -> void:
	_disc(centre, 2.5, _grey(0.8))
	_disc(centre - Vector2(0.8, 0.8), 0.6, _grey(1.0))


## A spot for a mark reaching `radius` (x, y, radius) whose reach lies inside `within` and stays
## MARK_GAP clear of every one in `taken`; the last try if none is free.
func _free_spot(taken: Array[Vector3], radius: float, within: Rect2) -> Vector3:
	var spot := Vector3.ZERO
	for attempt: int in 200:
		spot = Vector3(_rng.range_int(ceili(within.position.x + radius), floori(within.end.x - radius)),
			_rng.range_int(ceili(within.position.y + radius), floori(within.end.y - radius)), radius)
		var free := true
		for other: Vector3 in taken:
			if Vector2(other.x - spot.x, other.y - spot.y).length() < other.z + radius + MARK_GAP:
				free = false
				break
		if free:
			break
	return spot


## The buffer's red channel: a channel of the field texture, drawn in greys.
func _channel() -> PackedFloat32Array:
	var channel := PackedFloat32Array()
	channel.resize(_rgb.size())
	for i: int in _rgb.size():
		channel[i] = _rgb[i].r
	return channel


## A crack: a jagged polyline of `segments` steps, each `steps.x` to `steps.y` pixels, from
## `start`, setting off along `heading` (radians; any way when negative) and drifting in direction.
func _crack(start: Vector2, segments: int, width: float, color: Color, steps := Vector2i(10, 22),
		heading := -1.0) -> void:
	var angle := heading
	if heading < 0.0:
		angle = TAU * _rng.range_int(0, 359) / 360.0
	var at := start
	for i: int in segments:
		angle += deg_to_rad(_rng.range_int(-50, 50))
		var step := Vector2(cos(angle), sin(angle)) * _rng.range_int(steps.x, steps.y)
		_line(at, at + step, width, color)
		at += step


# --- Primitives (all wrap modulo the image's size) ---------------------------------

func _grey(value: float) -> Color:
	return Color(value, value, value, 1.0)


func _fill(color: Color) -> void:
	_rgb.fill(color)


## Paints one pixel, blending `color` over it by `coverage`; a non-negative `mask` is blended
## into the emission mask the same way.
func _paint(x: int, y: int, color: Color, coverage: float, mask: float = -1.0) -> void:
	if coverage <= 0.0:
		return
	var i := posmod(y, _height) * _width + posmod(x, _width)
	_rgb[i] = _rgb[i].lerp(color, minf(coverage, 1.0))
	if mask >= 0.0:
		_mask[i] = lerpf(_mask[i], mask, minf(coverage, 1.0))


func _rect(x: int, y: int, width: int, height: int, color: Color, mask: float = -1.0) -> void:
	for py: int in range(y, y + height):
		for px: int in range(x, x + width):
			_paint(px, py, color, 1.0, mask)


## An antialiased disc.
func _disc(centre: Vector2, radius: float, color: Color, mask: float = -1.0) -> void:
	for py: int in range(floori(centre.y - radius - 1), ceili(centre.y + radius + 1)):
		for px: int in range(floori(centre.x - radius - 1), ceili(centre.x + radius + 1)):
			var d := Vector2(px + 0.5, py + 0.5).distance_to(centre)
			_paint(px, py, color, radius + 0.5 - d, mask)


## A lean brush, for the field texture: over the ring from `inner` to `outer` pixels round
## `centre` (a disc when `inner` is 0), clipped to the polygon `clip` when it has corners, the
## surface leans straight out from the centre by `strength` (in when negative), written into R and
## G as 0.5 plus half the lean, antialiased.
func _lean(centre: Vector2, inner: float, outer: float, strength: float,
		clip: PackedVector2Array = PackedVector2Array()) -> void:
	for py: int in range(floori(centre.y - outer - 1), ceili(centre.y + outer + 1)):
		for px: int in range(floori(centre.x - outer - 1), ceili(centre.x + outer + 1)):
			var offset := Vector2(px + 0.5, py + 0.5) - centre
			var d := offset.length()
			var coverage := clampf(outer + 0.5 - d, 0.0, 1.0)
			if inner > 0.0:
				coverage *= clampf(d - inner + 0.5, 0.0, 1.0)
			if coverage > 0.0 and not clip.is_empty():
				var inside := 0
				for sy: int in 4:
					for sx: int in 4:
						if Geometry2D.is_point_in_polygon(Vector2(px + (sx + 0.5) / 4.0, py + (sy + 0.5) / 4.0), clip):
							inside += 1
				coverage *= inside / 16.0
			var lean := offset / maxf(d, 0.001) * strength * 0.5
			_paint(px, py, Color(0.5 + lean.x, 0.5 + lean.y, 0.0), coverage)


## An antialiased circle outline `width` pixels thick.
func _ring(centre: Vector2, radius: float, width: float, color: Color) -> void:
	var reach := radius + width
	for py: int in range(floori(centre.y - reach - 1), ceili(centre.y + reach + 1)):
		for px: int in range(floori(centre.x - reach - 1), ceili(centre.x + reach + 1)):
			var d := Vector2(px + 0.5, py + 0.5).distance_to(centre)
			_paint(px, py, color, width * 0.5 + 0.5 - absf(d - radius))


## An antialiased line with round ends, `width` pixels thick.
func _line(from: Vector2, to: Vector2, width: float, color: Color) -> void:
	var half := width * 0.5
	var low := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2(half + 1, half + 1)
	var high := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2(half + 1, half + 1)
	for py: int in range(floori(low.y), ceili(high.y)):
		for px: int in range(floori(low.x), ceili(high.x)):
			var p := Vector2(px + 0.5, py + 0.5)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, from, to))
			_paint(px, py, color, half + 0.5 - d)


## A filled polygon, antialiased by 4x4 supersampling.
func _polygon(corners: PackedVector2Array, color: Color) -> void:
	var low := corners[0]
	var high := corners[0]
	for corner: Vector2 in corners:
		low = low.min(corner)
		high = high.max(corner)
	for py: int in range(floori(low.y), ceili(high.y)):
		for px: int in range(floori(low.x), ceili(high.x)):
			var inside := 0
			for sy: int in 4:
				for sx: int in 4:
					if Geometry2D.is_point_in_polygon(Vector2(px + (sx + 0.5) / 4.0, py + (sy + 0.5) / 4.0), corners):
						inside += 1
			_paint(px, py, color, inside / 16.0)


## Multiplies every pixel by 1 +/- `amount`, from value noise on a lattice of `cell` pixels
## (1: a value per pixel).
func _grain(amount: float, cell: int) -> void:
	var noise := _noise_field([cell], [1.0])
	for i: int in noise.size():
		var k := 1.0 + amount * (noise[i] * 2.0 - 1.0)
		var c := _rgb[i]
		_rgb[i] = Color(c.r * k, c.g * k, c.b * k, 1.0)


## Tileable value noise in [0, 1]: one octave per lattice cell size (each dividing the image's
## size), weighted and summed.
func _noise_field(cells: Array, weights: Array) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(_width * _height)
	field.fill(0.0)
	for octave: int in cells.size():
		var cell: int = cells[octave]
		var weight: float = weights[octave]
		var across := _width / cell
		var down := _height / cell
		var lattice := PackedFloat32Array()
		for i: int in across * down:
			lattice.append(_rng.range_int(0, 1000) / 1000.0)
		for y: int in _height:
			for x: int in _width:
				var gx := float(x) / cell
				var gy := float(y) / cell
				var ix := floori(gx)
				var iy := floori(gy)
				var fx := smoothstep(0.0, 1.0, gx - ix)
				var fy := smoothstep(0.0, 1.0, gy - iy)
				var top := lerpf(lattice[(iy % down) * across + ix % across],
					lattice[(iy % down) * across + (ix + 1) % across], fx)
				var bottom := lerpf(lattice[((iy + 1) % down) * across + ix % across],
					lattice[((iy + 1) % down) * across + (ix + 1) % across], fx)
				field[y * _width + x] += weight * lerpf(top, bottom, fy)
	return field


## 1 inside [low, high] along a coordinate, fading over a pixel at each side.
func _band(at: float, low: float, high: float) -> float:
	return clampf(at - low + 0.5, 0.0, 1.0) * clampf(high - at + 0.5, 0.0, 1.0)


## The shortest offset equivalent to `d` on the wrapping texture.
func _wrapped(d: Vector2) -> Vector2:
	return Vector2(wrapf(d.x, -_width * 0.5, _width * 0.5), wrapf(d.y, -_height * 0.5, _height * 0.5))


func _image() -> Image:
	var data := PackedByteArray()
	data.resize(_width * _height * 4)
	for i: int in _width * _height:
		var c := _rgb[i]
		data[i * 4] = roundi(clampf(c.r, 0.0, 1.0) * 255.0)
		data[i * 4 + 1] = roundi(clampf(c.g, 0.0, 1.0) * 255.0)
		data[i * 4 + 2] = roundi(clampf(c.b, 0.0, 1.0) * 255.0)
		data[i * 4 + 3] = roundi(clampf(_mask[i], 0.0, 1.0) * 255.0)
	return Image.create_from_data(_width, _height, false, Image.FORMAT_RGBA8, data)
