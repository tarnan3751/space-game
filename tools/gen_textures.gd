extends SceneTree
## Draws the material kit: the 16 layers of the Texture2DArray every building, the terrain and
## the rocks are painted from (docs/reference/art-style.md, **The material kit**), saved as
## assets/textures/kit/<index>_<name>.png. Run it after an import (tools/gates.sh does one), from
## the project root:
##
##   $GODOT --headless --path . -s res://tools/gen_textures.gd
##
## Each layer is SIZE x SIZE RGBA8. RGB is the albedo: near-white greys (0.78 to 1.0, ink lines
## at the ink colour) for the layers a tint multiplies, real colours for the fixed ones (hazard,
## solar). A is the emission mask: 0 on plain surfaces, up to 1 where the surface glows.
##
## Everything is drawn from SEED with SeededRng, so a run gives byte-identical PNGs. Every
## primitive wraps modulo SIZE, so every layer tiles seamlessly. One layer covers one world unit
## at the default UV scale: an ink line of INK_WIDTH pixels is about 0.012 units wide.

const SIZE := 256
const SEED := 20261014
const OUT_DIR := "res://assets/textures/kit"
## The layers, in array order. MaterialKit.LAYERS must match.
const LAYERS := [
	"flat", "hull", "hull_dense", "plate", "vent", "pipe", "grating", "concrete",
	"hazard", "solar", "glass", "glow", "screen", "crystal", "rock", "regolith",
]
const INK := Color("1b1a2e")
const INK_WIDTH := 3.0
const HAZARD_YELLOW := Color("ffd60a")

var _rgb := PackedColorArray()
var _mask := PackedFloat32Array()
var _rng: SeededRng


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	for index: int in LAYERS.size():
		var layer_name: String = LAYERS[index]
		_rgb.resize(SIZE * SIZE)
		_mask.resize(SIZE * SIZE)
		_mask.fill(0.0)
		_rng = SeededRng.new(SEED + index)
		call("_draw_" + layer_name)
		var path := OUT_DIR.path_join("%02d_%s.png" % [index, layer_name])
		var error := _image().save_png(path)
		if error != OK:
			printerr("gen_textures: could not save %s: %s" % [path, error_string(error)])
			quit(1)
			return
		print("gen_textures: %s" % path)
	quit(0)


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


## Rock grain in three posterised tones, ink cracks and dark speckles.
func _draw_rock() -> void:
	var noise := _noise_field([64, 32, 16, 8], [0.5, 0.25, 0.15, 0.1])
	for i: int in noise.size():
		var n := noise[i]
		var tone := 0.97 if n > 0.6 else (0.9 if n > 0.42 else 0.83)
		_rgb[i] = _grey(tone)
	_grain(0.012, 1)
	for i: int in 7:
		_crack(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), _rng.range_int(4, 8), 2.5, INK)
	for i: int in 160:
		_disc(Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1)), 0.7, _grey(0.78))


## Fine dust, faint craterlets with a lit rim, and pebbles with a highlight.
func _draw_regolith() -> void:
	var noise := _noise_field([32, 16, 8], [0.5, 0.3, 0.2])
	for i: int in noise.size():
		_rgb[i] = _grey(0.9 + 0.08 * noise[i])
	_grain(0.012, 1)
	for i: int in 6:
		var centre := Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1))
		var radius := _rng.range_int(8, 20)
		_disc(centre, radius, _grey(0.86))
		_disc(centre + Vector2(radius * 0.25, radius * 0.25), radius * 0.8, _grey(0.89))
		_ring(centre, radius, 2.0, _grey(1.0))
	for i: int in 40:
		var spot := Vector2(_rng.range_int(0, SIZE - 1), _rng.range_int(0, SIZE - 1))
		var radius := _rng.range_int(15, 35) / 10.0
		_disc(spot, radius, _grey(0.8 + _rng.range_int(0, 6) / 100.0))
		_disc(spot - Vector2(radius * 0.35, radius * 0.35), 0.8, _grey(1.0))


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


## A crack: a jagged polyline of `segments` steps from `start`, drifting in direction.
func _crack(start: Vector2, segments: int, width: float, color: Color) -> void:
	var angle := TAU * _rng.range_int(0, 359) / 360.0
	var at := start
	for i: int in segments:
		angle += deg_to_rad(_rng.range_int(-50, 50))
		var step := Vector2(cos(angle), sin(angle)) * _rng.range_int(10, 22)
		_line(at, at + step, width, color)
		at += step


# --- Primitives (all wrap modulo SIZE) ---------------------------------------------

func _grey(value: float) -> Color:
	return Color(value, value, value, 1.0)


func _fill(color: Color) -> void:
	_rgb.fill(color)


## Paints one pixel, blending `color` over it by `coverage`; a non-negative `mask` is blended
## into the emission mask the same way.
func _paint(x: int, y: int, color: Color, coverage: float, mask: float = -1.0) -> void:
	if coverage <= 0.0:
		return
	var i := posmod(y, SIZE) * SIZE + posmod(x, SIZE)
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


## Tileable value noise in [0, 1]: one octave per lattice cell size (each dividing SIZE),
## weighted and summed.
func _noise_field(cells: Array, weights: Array) -> PackedFloat32Array:
	var field := PackedFloat32Array()
	field.resize(SIZE * SIZE)
	field.fill(0.0)
	for octave: int in cells.size():
		var cell: int = cells[octave]
		var weight: float = weights[octave]
		var count := SIZE / cell
		var lattice := PackedFloat32Array()
		for i: int in count * count:
			lattice.append(_rng.range_int(0, 1000) / 1000.0)
		for y: int in SIZE:
			for x: int in SIZE:
				var gx := float(x) / cell
				var gy := float(y) / cell
				var ix := floori(gx)
				var iy := floori(gy)
				var fx := smoothstep(0.0, 1.0, gx - ix)
				var fy := smoothstep(0.0, 1.0, gy - iy)
				var top := lerpf(lattice[(iy % count) * count + ix % count], lattice[(iy % count) * count + (ix + 1) % count], fx)
				var bottom := lerpf(lattice[((iy + 1) % count) * count + ix % count],
					lattice[((iy + 1) % count) * count + (ix + 1) % count], fx)
				field[y * SIZE + x] += weight * lerpf(top, bottom, fy)
	return field


## 1 inside [low, high] along a coordinate, fading over a pixel at each side.
func _band(at: float, low: float, high: float) -> float:
	return clampf(at - low + 0.5, 0.0, 1.0) * clampf(high - at + 0.5, 0.0, 1.0)


## The shortest offset equivalent to `d` on the wrapping texture.
func _wrapped(d: Vector2) -> Vector2:
	return Vector2(wrapf(d.x, -SIZE * 0.5, SIZE * 0.5), wrapf(d.y, -SIZE * 0.5, SIZE * 0.5))


func _image() -> Image:
	var data := PackedByteArray()
	data.resize(SIZE * SIZE * 4)
	for i: int in SIZE * SIZE:
		var c := _rgb[i]
		data[i * 4] = roundi(clampf(c.r, 0.0, 1.0) * 255.0)
		data[i * 4 + 1] = roundi(clampf(c.g, 0.0, 1.0) * 255.0)
		data[i * 4 + 2] = roundi(clampf(c.b, 0.0, 1.0) * 255.0)
		data[i * 4 + 3] = roundi(clampf(_mask[i], 0.0, 1.0) * 255.0)
	return Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_RGBA8, data)
