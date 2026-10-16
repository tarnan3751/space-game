extends SceneTree
## Draws the material kit: the 20 layers of the Texture2DArray every building and the rocks are
## painted from (docs/reference/art-style.md, **The material kit**), saved as
## assets/textures/kit/<index>_<name>.png; the field texture the buildable ground and the terrain's
## marks are drawn from, assets/textures/field.png (**The field**); and the rock texture the
## terrain's steep faces are drawn from, assets/textures/terrain_rock.png (**Environment**). Run it
## after an import (tools/gates.sh does one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/gen_textures.gd
##
## Each layer is SIZE x SIZE RGBA8. RGB is the albedo: near-white greys (0.78 to 1.0, the bands
## layer's ground 0.62; ink lines at the ink colour) for the layers a tint multiplies, real
## colours for the fixed ones (hazard, solar). A is the emission mask: 0 on plain surfaces, up to
## 1 where the surface glows. The field texture is FIELD_SIZE square, an atlas of four tiles,
## and holds weights, not colours (_draw_field); the rock texture is ROCK_SIZE square, a single
## tile in the same channels (_draw_terrain_rock).
##
## Everything is drawn from SEED with SeededRng, so a run gives byte-identical PNGs. Every
## primitive wraps modulo the image's size, so every layer and the rock texture tile seamlessly;
## the field's tiles keep their marks off their edges instead. One layer covers one world unit at
## the default UV scale: an ink line of INK_WIDTH pixels is about 0.012 units wide.

const SIZE := 256
const SEED := 20261014
const OUT_DIR := "res://assets/textures/kit"
## The field texture: an atlas of four tiles of the ground (4x4 cells each), drawn after the kit
## from its own seed.
const FIELD_PATH := "res://assets/textures/field.png"
const FIELD_SIZE := 1024
## A tile of the field atlas (TILE_CELL pixels a cell), and how far its marks keep from its edges
## and from each other.
const TILE := 512
const TILE_CELL := 128
const TILE_MARGIN := 8.0
const MARK_GAP := 6.0
## The ejecta stipple round a crater: the spacing of its rings and of the dots round each, how far
## out from the rim it thins out to nothing, and its dots' chance in a hundred just outside the rim.
const HALO_STEP := 3
const HALO_DEPTH := TILE_CELL * 3 / 10
const HALO_DENSITY := 75
## The radius the pebbly tile's cluster of pebbles and shards lies within.
const CLUSTER := TILE_CELL * 8 / 10
## The four tiles, tile q at column q % 2 and row q / 2 of the atlas (plain, cracked, cratered and
## pebbly), each: its crater's radius (0 for none) and the cracks running out from its rim, its
## pits, short cracks and pebbles, whether it has a long branching crack, whether a cluster, and
## where its crater lies in it (pixels). Each crater's spot is its own, off the tile's diagonals
## and no turn or mirror of another's, so that, turned eight ways, the field's craters line up
## neither in the view's columns and rows nor along the grid.
const FIELD_TILES := [
	[0, 0, 3, 1, 6, false, false, Vector2.ZERO],
	[45, 0, 2, 0, 5, true, false, Vector2(96, 214)],
	[64, 2, 3, 0, 8, false, false, Vector2(269, 328)],
	[45, 0, 2, 1, 0, false, true, Vector2(155, 387)],
]
## The rock texture: one tile of the terrain's steep faces, drawn after the field from its own
## seed. Its strata: how many bands a tile, the spacing of the corners along a band's jagged edge
## and how far they wander up or down, and how deep the lean runs below a band's top edge (its lit
## edge) and above its bottom (its shaded underside), all in pixels; and how many cracks and
## outcrop plates.
const ROCK_PATH := "res://assets/textures/terrain_rock.png"
const ROCK_SIZE := 512
const STRATA := Vector2i(4, 7)
const STRATA_STEP := Vector2i(18, 34)
const STRATA_JAG := 7
const STRATA_TOP := 7.0
const STRATA_UNDER := 9.0
const ROCK_CRACKS := Vector2i(3, 5)
const ROCK_PLATES := Vector2i(2, 3)
## The layers, in array order. MaterialKit.LAYERS must match.
const LAYERS := [
	"flat", "hull", "hull_dense", "plate", "vent", "pipe", "grating", "concrete",
	"hazard", "solar", "glass", "glow", "screen", "crystal", "rock", "regolith", "bands",
	"chrome", "obsidian", "veins",
]
## The field's and the rock texture's seeds, fixed where the first sixteen layers left them so a
## new layer does not redraw them.
const FIELD_SEED := SEED + 16
const ROCK_SEED := SEED + 17
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
	_begin(FIELD_SIZE, FIELD_SIZE, FIELD_SEED)
	_draw_field()
	if not _save(FIELD_PATH):
		return
	_begin(ROCK_SIZE, ROCK_SIZE, ROCK_SEED)
	_draw_terrain_rock()
	if not _save(ROCK_PATH):
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


## Dust for a large surface, a layer covering five to six units: large soft blobs in two tones
## and two pebbles, shaded from SUN, no ink. Unused since the terrain took its own shader.
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


## Polished chrome plating: near-white plates brushed in streaks along U, in bands two to four
## pixels high from 0.86 to 1.0 with strokes of white and of 0.76 over them, so the brushing shows at
## the closest zoom; a lit chamfer along each plate's top edge and a shaded one along its bottom,
## parted by ink seams, no rivets. Tinted pale cyan-white and GLOSSY, it reads polished.
func _draw_chrome() -> void:
	_fill(_grey(0.9))
	var top := 0
	while top < SIZE:
		var band := _rng.range_int(2, 4)
		_rect(0, top, SIZE, band, _grey(0.86 + _rng.range_int(0, 14) / 100.0))
		top += band
	# Brushed strokes along U over the bands, half of them bright, half dark.
	for i: int in 260:
		var at := Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1))
		var light := _rng.range_int(0, 2) == 0
		_line(at, at + Vector2(_rng.range_int(24, 110), 0), 1.5, _grey(1.0 if light else 0.76))
	# Two rows of plates, the lower row's seams staggered.
	for row: int in 2:
		var y := row * 128
		_rect(0, y + 2, SIZE, 4, _grey(1.0))
		_rect(0, y + 122, SIZE, 4, _grey(0.76))
		_line(Vector2(0, y), Vector2(SIZE, y), INK_WIDTH, INK)
		for x: int in [0, 160] if row == 0 else [64, 192]:
			_line(Vector2(x, y), Vector2(x, y + 128), INK_WIDTH, INK)
			_rect(x + 2, y + 2, 3, 124, _grey(1.0))
	_grain(0.01, 1)


## Obsidian armour: a dark glassy ground (about 0.38, so a tint stays dark) in large faint facets
## (a wrapped Voronoi diagram, each facet a tone of its own, a pale glint along the edge facing the
## light), parted by hairline ink cracks. GLOSSY, it reads as volcanic glass.
func _draw_obsidian() -> void:
	var seeds := PackedVector2Array()
	var tones := PackedFloat32Array()
	for gy: int in 3:
		for gx: int in 3:
			seeds.append(Vector2(gx * 85 + _rng.range_int(10, 75), gy * 85 + _rng.range_int(10, 75)))
			tones.append(0.32 + _rng.range_int(0, 12) / 100.0)
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
			var glint := 0.18 * clampf(1.0 - absf(edge - 4.0) / 3.0, 0.0, 1.0) * clampf(-to_near.dot(SUN) / 40.0, 0.0, 1.0)
			var tone := tones[nearest] + glint
			_rgb[y * SIZE + x] = _grey(tone).lerp(INK, clampf(1.5 - edge, 0.0, 1.0))
	_grain(0.015, 1)
	for i: int in 5:
		_crack(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), _rng.range_int(3, 6), 1.0, INK,
			Vector2i(8, 18))


## Energy veins: a dark ground (about 0.35) with bright branching channels running along V, the
## axis FLOW scrolls, their emission (A) beaded with pulses a quarter of the repeat apart, so a FLOW
## surface on it reads as energy running through the veins; the ground does not glow.
func _draw_veins() -> void:
	_fill(_grey(0.35))
	_grain(0.03, 32)
	# Every run as (from, to, width), its ink rims drawn under all the cores so joints stay open.
	var runs: Array[Array] = []
	for trunk: int in 4:
		var at := Vector2(trunk * 64 + _rng.range_int(8, 56), 0)
		var points := PackedVector2Array([at])
		# A trunk meanders down the whole repeat and ends where it began, so it tiles.
		var start_x := at.x
		for step: int in 8:
			var y := 32.0 * (step + 1)
			var x := start_x if step == 7 else points[step].x + _rng.range_int(-14, 14)
			points.append(Vector2(x, y))
		for k: int in points.size() - 1:
			runs.append([points[k], points[k + 1], 5.0])
		# Two branches setting off down and to the side, thinner, ending in the ground.
		for b: int in 2:
			var from := points[_rng.range_int(1, 6)]
			var side := -1.0 if b == 0 else 1.0
			var mid := from + Vector2(side * _rng.range_int(10, 20), _rng.range_int(16, 26))
			runs.append([from, mid, 3.0])
			runs.append([mid, mid + Vector2(side * _rng.range_int(4, 12), _rng.range_int(14, 22)), 2.0])
	for run: Array in runs:
		var width: float = run[2]
		_line(run[0], run[1], width + 2.0, INK)
	for run: Array in runs:
		_vein(run[0], run[1], run[2])


## The core of one straight run of a vein from `from` to `to`, `width` across: bright, its emission
## beaded along V with a pulse every 64 pixels (four a repeat).
func _vein(from: Vector2, to: Vector2, width: float) -> void:
	var half := width * 0.5
	var low := Vector2(minf(from.x, to.x), minf(from.y, to.y)) - Vector2(half + 1, half + 1)
	var high := Vector2(maxf(from.x, to.x), maxf(from.y, to.y)) + Vector2(half + 1, half + 1)
	for py: int in range(floori(low.y), ceili(high.y)):
		for px: int in range(floori(low.x), ceili(high.x)):
			var p := Vector2(px + 0.5, py + 0.5)
			var d := p.distance_to(Geometry2D.get_closest_point_to_segment(p, from, to))
			var bead := 0.5 + 0.5 * cos(TAU * fposmod(p.y, 64.0) / 64.0)
			_paint(px, py, _grey(lerpf(0.8, 1.0, bead)), half + 0.5 - d, lerpf(0.45, 1.0, bead))


## Broad bands across V for a flow to carry: each repeat a band a third of it at 1.0 on 0.62,
## ink-edged on its leading side (its top: a FLOW at a phase below 0.5 carries the bands towards
## smaller V), so a scrolling beam or conduit reads as pulses travelling. Fully emissive.
func _draw_bands() -> void:
	_fill(_grey(0.62))
	_rect(0, 0, SIZE, SIZE / 3, _grey(1.0))
	_rect(0, 0, SIZE, int(INK_WIDTH), INK)
	_mask.fill(1.0)


## The ground's field texture: an atlas of four tiles (FIELD_TILES), TILE pixels square, which the
## ground shader picks from and turns per tile of the field (ground.gdshader), so the plain does
## not repeat. Not colours but weights, so the tints stay MaterialKit roles, and no light is baked
## in; away from the marks every channel is flat, so nothing shows where a tile ends:
## - R and G, lean: the way the surface's normal leans across the tile (x, y), 0.5 flat, 0 and 1 a
##   full lean of -1 and +1: out from a pebble's or a shard's middle, in down a crater's wall, out
##   down its rim's outer slope. The shader lights the side leaning towards the sun and shades the
##   side leaning away, however the tile is turned.
## - B, ink: crater and pit rims, pebble and shard outlines, cracks, the craters' ejecta stipple.
## - A, tone: 0.5 neutral; below it darker (crater and pit floors), above it lighter (pebbles,
##   shards). The grain is the shader's, in world space.
## Every mark is a hard-edged drawn shape (sizes in pixels, TILE_CELL a cell): a crater, radius 45
## or 64, an ink rim 3 wide, its wall leaning in at 0.8 from 0.45 radii, its rim's outer slope,
## from 1.0 to 1.3 radii, leaning out at 0.45, its floor at tone 0.35, and a ring of ejecta stipple
## round it, dots 2 across covering about HALO_DENSITY / 3 percent just outside the rim and
## thinning out to nothing HALO_DEPTH out; a pit, a crater of 10 to 19 with a rim 2 wide, its floor
## at 0.4 and no stipple; a pebble, a jittered hexagon of 6 to 15 outlined in 1.5, leaning out at
## 0.7, tone 0.6; a shard, the same as a jittered triangle of 8 to 14; a crack, 1.5 wide, 15 to 30
## long, or a long one, a run of 50 to 70 with two branches of 15 to 25. Marks never overlap and
## keep TILE_MARGIN clear of a tile's edges. The lean is drawn in R and G in its own pass, and tone
## and ink in greys, each in its own pass, read off the red.
func _draw_field() -> void:
	# Craters and pits as (x, y, radius, rim width); pebbles' and shards' corners, and each one's
	# (x, y, reach); short cracks as (x, y, heading), any way when the heading is negative; long
	# cracks' starts and headings, the same; stipple dots.
	var bowls: Array[Vector4] = []
	var pebbles: Array[PackedVector2Array] = []
	var pebble_spots: Array[Vector3] = []
	var cracks: Array[Vector3] = []
	var long_cracks: Array[Vector3] = []
	var dots: Array[Vector2] = []
	for q: int in FIELD_TILES.size():
		var tile: Array = FIELD_TILES[q]
		var area := Rect2i(TILE * (q % 2), TILE * (q / 2), TILE, TILE)
		var inner := Rect2(area).grow(-TILE_MARGIN)
		# Every mark on this tile so far, as (x, y, reach).
		var taken: Array[Vector3] = []
		var crater: int = tile[0]
		var rim_cracks: int = tile[1]
		if crater > 0:
			# The stipple reaches HALO_DEPTH past the rim, past the rim's outer slope and the cracks
			# running out from the rim, which reach 32.
			var at: Vector2 = Vector2(area.position) + tile[7]
			var spot := Vector3(at.x, at.y, crater + 3.0 + HALO_DEPTH)
			taken.append(spot)
			bowls.append(Vector4(spot.x, spot.y, crater, 3.0))
			var heading := TAU * _rng.range_int(0, 359) / 360.0
			for k: int in rim_cracks:
				var angle := heading + TAU * k / rim_cracks + deg_to_rad(_rng.range_int(-40, 40))
				var out := Vector2(cos(angle), sin(angle)) * (crater + 2.0)
				cracks.append(Vector3(spot.x + out.x, spot.y + out.y, fposmod(angle, TAU)))
			# The ejecta: dots on rings HALO_STEP apart, as many round each as fit HALO_STEP apart,
			# fewer the further out.
			for depth: int in range(0, HALO_DEPTH, HALO_STEP):
				var ring := crater + 3.0 + depth
				var count := roundi(TAU * ring / HALO_STEP)
				var chance := roundi(HALO_DENSITY * (1.0 - float(depth) / HALO_DEPTH))
				for k: int in count:
					if _rng.range_int(0, 99) >= chance:
						continue
					var angle := TAU * (k + _rng.range_int(-30, 30) / 100.0) / count
					var reach := ring + _rng.range_int(-10, 10) / 10.0
					dots.append(Vector2(spot.x, spot.y) + Vector2(cos(angle), sin(angle)) * reach)
		var clustered: bool = tile[6]
		if clustered:
			# A cluster of pebbles and three shards among them, within CLUSTER of its middle.
			var cluster := _free_spot(taken, CLUSTER, inner)
			taken.append(cluster)
			var members: Array[Vector3] = []
			var count := _rng.range_int(10, 14)
			for k: int in count + 3:
				var shard := k < 3
				var spot := _free_spot(members, _rng.range_int(80 if shard else 60, 140 if shard else 120) / 10.0,
					inner, cluster)
				members.append(spot)
				pebble_spots.append(spot)
				pebbles.append(_chunk(spot, 3 if shard else 6))
		var long_crack: bool = tile[5]
		if long_crack:
			# A run of up to 70 and a branch of up to 25 from its fourth corner at the furthest.
			var spot := _free_spot(taken, 82.0, inner)
			taken.append(spot)
			long_cracks.append(Vector3(spot.x, spot.y, TAU * _rng.range_int(0, 359) / 360.0))
		var pits: int = tile[2]
		for k: int in pits:
			var radius := _rng.range_int(10, 19)
			var spot := _free_spot(taken, radius * 1.3, inner)
			taken.append(spot)
			bowls.append(Vector4(spot.x, spot.y, radius, 2.0))
		var loose: int = tile[3]
		for k: int in loose:
			var spot := _free_spot(taken, 30.0, inner)
			taken.append(spot)
			cracks.append(Vector3(spot.x, spot.y, -1.0))
		var pebble_count: int = tile[4]
		for k: int in pebble_count:
			var spot := _free_spot(taken, _rng.range_int(60, 150) / 10.0, inner)
			taken.append(spot)
			pebble_spots.append(spot)
			pebbles.append(_chunk(spot, 6))

	_fill(Color(0.5, 0.5, 0.0))
	for bowl: Vector4 in bowls:
		var centre := Vector2(bowl.x, bowl.y)
		_lean(centre, bowl.z * 0.45, bowl.z, -0.8)
		_lean(centre, bowl.z, bowl.z * 1.3, 0.45)
	for i: int in pebbles.size():
		_lean(Vector2(pebble_spots[i].x, pebble_spots[i].y), 0.0, pebble_spots[i].z, 0.7, pebbles[i])
	var lean := _rgb.duplicate()

	_fill(_grey(0.5))
	for bowl: Vector4 in bowls:
		_disc(Vector2(bowl.x, bowl.y), bowl.z * 0.45, _grey(0.35 if bowl.w > 2.0 else 0.4))
	for corners: PackedVector2Array in pebbles:
		_polygon(corners, _grey(0.6))
	var tone := _channel()

	_fill(_grey(0.0))
	for bowl: Vector4 in bowls:
		_ring(Vector2(bowl.x, bowl.y), bowl.z, bowl.w, _grey(1.0))
	for corners: PackedVector2Array in pebbles:
		for k: int in corners.size():
			_line(corners[k], corners[(k + 1) % corners.size()], 1.5, _grey(1.0))
	for crack: Vector3 in cracks:
		_crack(Vector2(crack.x, crack.y), 3, 1.5, _grey(1.0), Vector2i(5, 10), crack.z)
	for crack: Vector3 in long_cracks:
		# The run, then a branch from its second and its fourth corner, one to each side, setting off
		# 55 to 80 degrees from the run's direction there.
		var run := _crack(Vector2(crack.x, crack.y), 5, 1.5, _grey(1.0), Vector2i(10, 14), crack.z)
		for k: int in 2:
			var at := 2 + k * 2
			var along := ((run[at] - run[at - 1]).normalized() + (run[at + 1] - run[at]).normalized()).angle()
			var side := 1.0 if k == 0 else -1.0
			_crack(run[at], 2, 1.5, _grey(1.0), Vector2i(8, 12),
				fposmod(along + side * deg_to_rad(_rng.range_int(55, 80)), TAU))
	for dot: Vector2 in dots:
		_disc(dot, 1.0, _grey(1.0))
	var ink := _channel()

	for i: int in _rgb.size():
		_rgb[i] = Color(lean[i].r, lean[i].g, ink[i], 1.0)
		_mask[i] = tone[i]


## The terrain's rock texture (ROCK_SIZE square, tiling both ways), in the field texture's
## channels: R and G the lean (x along the face, y down it), B ink, A tone. The terrain shader
## projects it onto the steep faces with image y down the slope and lights the lean from the sun,
## which stands high, so a face leaning up is lit. Strata: STRATA bands across the tile, their
## edges jagged ink lines 3 wide; each band leans up for STRATA_TOP below its top edge (its lit
## edge) and down for STRATA_UNDER above its bottom (its shaded underside), in one of two tones,
## 0.5 or 0.8, never the same as the band above (but across the tile's wrap). A few cracks, ink 2
## wide, run down from a band's top edge most of the way through it. Two or three chunky outcrop
## plates, jittered polygons of five or six corners 44 to 64 out, lean out from their middles at
## 0.7 in tone 0.8 with an ink outline 3 wide, over the strata.
func _draw_terrain_rock() -> void:
	# Each band's top edge as its corners' heights at x = 0, step, 2 step ... ROCK_SIZE (the last
	# the first again, so the edge wraps).
	var count := _rng.range_int(STRATA.x, STRATA.y)
	var edges: Array[PackedVector2Array] = []
	var tones := PackedFloat32Array()
	for k: int in count:
		var middle := (k + 0.5 + _rng.range_int(-15, 15) / 100.0) * ROCK_SIZE / count
		var edge := PackedVector2Array()
		var x := 0
		while x < ROCK_SIZE:
			edge.append(Vector2(x, middle + _rng.range_int(-STRATA_JAG, STRATA_JAG)))
			x += _rng.range_int(STRATA_STEP.x, STRATA_STEP.y)
		edge.append(Vector2(ROCK_SIZE, edge[0].y))
		edges.append(edge)
		var tone := 0.5 if _rng.range_int(0, 1) == 0 else 0.8
		if k > 0 and tone == tones[k - 1]:
			tone = 1.3 - tone
		tones.append(tone)
	var plates: Array[PackedVector2Array] = []
	var plate_spots: Array[Vector3] = []
	for k: int in _rng.range_int(ROCK_PLATES.x, ROCK_PLATES.y):
		var spot := _free_spot(plate_spots, _rng.range_int(44, 64), Rect2(0, 0, ROCK_SIZE, ROCK_SIZE))
		plate_spots.append(spot)
		plates.append(_chunk(spot, _rng.range_int(5, 6)))
	# Each crack: its start on a band's top edge and its corners down from there.
	var cracks: Array[PackedVector2Array] = []
	for k: int in _rng.range_int(ROCK_CRACKS.x, ROCK_CRACKS.y):
		var band := _rng.range_int(0, count - 1)
		var x := float(_rng.range_int(0, ROCK_SIZE - 1))
		var top := _edge_height(edges[band], x)
		var bottom := _edge_height(edges[(band + 1) % count], x)
		if bottom < top:
			bottom += ROCK_SIZE
		var crack := PackedVector2Array([Vector2(x, top)])
		var at := Vector2(x, top)
		while at.y < top + (bottom - top) * 0.8:
			at += Vector2(_rng.range_int(-4, 4), _rng.range_int(8, 14))
			crack.append(at)
		cracks.append(crack)

	# Each edge's height at the middle of each column of pixels, and each pixel's band.
	var heights: Array[PackedFloat32Array] = []
	for edge: PackedVector2Array in edges:
		var column := PackedFloat32Array()
		for x: int in ROCK_SIZE:
			column.append(_edge_height(edge, x + 0.5))
		heights.append(column)
	var bands := PackedInt32Array()
	bands.resize(ROCK_SIZE * ROCK_SIZE)
	for y: int in ROCK_SIZE:
		for x: int in ROCK_SIZE:
			# The last band whose top edge is above the pixel; above the first edge, the last band.
			var band := count - 1
			for k: int in count:
				if heights[k][x] <= y + 0.5:
					band = k
			bands[y * ROCK_SIZE + x] = band

	# The lean, then the tone and the ink each in greys, read off the red.
	for y: int in ROCK_SIZE:
		for x: int in ROCK_SIZE:
			var band := bands[y * ROCK_SIZE + x]
			var below_top := wrapf(y + 0.5 - heights[band][x], 0.0, ROCK_SIZE)
			var above_bottom := wrapf(heights[(band + 1) % count][x] - y - 0.5, 0.0, ROCK_SIZE)
			var tilt := 0.4 * clampf(STRATA_TOP + 0.5 - below_top, 0.0, 1.0) \
				- 0.4 * clampf(STRATA_UNDER + 0.5 - above_bottom, 0.0, 1.0)
			_rgb[y * ROCK_SIZE + x] = Color(0.5, 0.5 - tilt, 0.0)
	for i: int in plates.size():
		_lean(Vector2(plate_spots[i].x, plate_spots[i].y), 0.0, plate_spots[i].z, 0.7, plates[i])
	var lean := _rgb.duplicate()

	for i: int in _rgb.size():
		_rgb[i] = _grey(tones[bands[i]])
	for corners: PackedVector2Array in plates:
		_polygon(corners, _grey(0.8))
	var tone := _channel()

	_fill(_grey(0.0))
	for edge: PackedVector2Array in edges:
		for k: int in edge.size() - 1:
			_line(edge[k], edge[k + 1], INK_WIDTH, _grey(1.0))
	for crack: PackedVector2Array in cracks:
		for k: int in crack.size() - 1:
			_line(crack[k], crack[k + 1], 2.0, _grey(1.0))
	for corners: PackedVector2Array in plates:
		_polygon(corners, _grey(0.0))
		for k: int in corners.size():
			_line(corners[k], corners[(k + 1) % corners.size()], INK_WIDTH, _grey(1.0))
	var ink := _channel()

	for i: int in _rgb.size():
		_rgb[i] = Color(lean[i].r, lean[i].g, ink[i], 1.0)
		_mask[i] = tone[i]


## The height of a band's top edge (its corners, as _draw_terrain_rock keeps them) at `x`.
func _edge_height(edge: PackedVector2Array, x: float) -> float:
	for k: int in edge.size() - 1:
		if x <= edge[k + 1].x:
			return lerpf(edge[k].y, edge[k + 1].y, (x - edge[k].x) / (edge[k + 1].x - edge[k].x))
	return edge[edge.size() - 1].y


## A pebble or a shard of `corners` corners round `spot` (x, y, reach): jittered in angle and in
## reach.
func _chunk(spot: Vector3, corners: int) -> PackedVector2Array:
	var chunk := PackedVector2Array()
	var turn := TAU * _rng.range_int(0, 359) / 360.0
	for c: int in corners:
		var angle := turn + TAU * (c + _rng.range_int(-15, 15) / 100.0) / corners
		var reach := spot.z * _rng.range_int(72, 100) / 100.0
		chunk.append(Vector2(spot.x, spot.y) + Vector2(cos(angle), sin(angle)) * reach)
	return chunk


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


## A spot for a mark reaching `radius` (x, y, radius) whose reach lies inside `within`, and inside
## the circle `inside` (x, y, radius) when that has a radius, and stays MARK_GAP clear of every one
## in `taken`; the last try if none is free.
func _free_spot(taken: Array[Vector3], radius: float, within: Rect2, inside := Vector3.ZERO) -> Vector3:
	var bounds := within.grow(-radius)
	if inside.z > 0.0:
		bounds = bounds.intersection(Rect2(inside.x, inside.y, 0.0, 0.0).grow(inside.z - radius))
	var spot := Vector3.ZERO
	for attempt: int in 200:
		spot = Vector3(_rng.range_int(ceili(bounds.position.x), floori(bounds.end.x)),
			_rng.range_int(ceili(bounds.position.y), floori(bounds.end.y)), radius)
		var free := inside.z <= 0.0 or Vector2(spot.x - inside.x, spot.y - inside.y).length() + radius <= inside.z
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
## `start`, setting off straight along `heading` (radians; any way when negative) and drifting in
## direction after that. Returns its corners, `start` first.
func _crack(start: Vector2, segments: int, width: float, color: Color, steps := Vector2i(10, 22),
		heading := -1.0) -> PackedVector2Array:
	var angle := heading
	if heading < 0.0:
		angle = TAU * _rng.range_int(0, 359) / 360.0
	var corners := PackedVector2Array([start])
	var at := start
	for i: int in segments:
		var drift := deg_to_rad(_rng.range_int(-50, 50))
		if i > 0 or heading < 0.0:
			angle += drift
		var step := Vector2(cos(angle), sin(angle)) * _rng.range_int(steps.x, steps.y)
		_line(at, at + step, width, color)
		at += step
		corners.append(at)
	return corners


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
