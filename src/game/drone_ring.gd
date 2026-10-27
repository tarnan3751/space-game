class_name DroneRing
extends Control
## The top bar's drones (docs/reference/hud.md, **Drone meter**): how many of the base's drones
## are free, as a resource meter's twin at the strip's right end, built from the same parts as
## Hud._build_meter so every skin styles it as it styles them: the pill-shaped trough
## (`MeterTrough`), its ink border again over what is inside it (`MeterFrame`), the drone icon on
## its coin in the trough's colour over the left end, and "free / all" right-aligned in
## `MeterText`. Inside the trough, a slot per drone split by ink lines: free ones in the accent
## cyan as a meter's fill takes it (Hud.meter_fill) with the meters' gloss over their top third,
## busy ones the trough's own fill crossed by the meters' 45-degree stripes (at work). The slots
## are one triangle array (`HudIcon.Pen`), redrawn only when set_counts changes a count or the
## theme changes (a skin), never per frame. It stops a touch on it, as any opaque part of the HUD
## does; its parts take none.

const SIZE := Vector2(200, Hud.METER_SIZE.y)
## The slots start at the coin's edge, their first ink line on the coin's ink ring, and end where
## the text's place begins (in the meter's coordinates; the slots are drawn in the trough's,
## METER_TROUGH_LEFT in).
const SLOTS_LEFT := Hud.METER_COIN - 0.5
const TEXT_WIDTH := 52.0
## The meters' stripes (Hud.STRIPE_TILE, Hud.STRIPE_BAND), static, this much off the trough's fill:
## lighter on a dark trough, darker on a light one.
const STRIPE_SHIFT := 0.14
## Steps round the circle the pill's round end is cut from.
const END_STEPS := 32
## The meters' gloss: white at 10 % over the track's top third (meter.gdshader).
const GLOSS := Color(1, 1, 1, 0.1)

var _free: int = 0
var _total: int = 0
var _slots: Control
var _text: Label


func _init() -> void:
	custom_minimum_size = SIZE
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mouse_filter = Control.MOUSE_FILTER_STOP
	var trough := Panel.new()
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.theme_type_variation = &"MeterTrough"
	add_child(trough)
	trough.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trough.offset_left = Hud.METER_TROUGH_LEFT
	_slots = Control.new()
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_slots.draw.connect(_draw_slots)
	trough.add_child(_slots)
	_slots.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme_type_variation = &"MeterFrame"
	trough.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text = Label.new()
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_text.theme_type_variation = &"MeterText"
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.text = "0 / 0"
	trough.add_child(_text)
	_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_text.offset_left = Hud.METER_COIN - Hud.METER_TROUGH_LEFT
	_text.offset_right = -Hud.METER_TEXT_RIGHT
	var coin := HudIcon.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.kind = "drones"
	coin.color = Hud.ACCENT
	coin.coin = Hud.TROUGH
	coin.position = Vector2(0, (SIZE.y - Hud.METER_COIN) / 2.0)
	coin.size = Vector2.ONE * Hud.METER_COIN
	add_child(coin)


## Redraws only when a count changed.
func set_counts(free_drones: int, all_drones: int) -> void:
	if free_drones == _free and all_drones == _total:
		return
	_free = free_drones
	_total = all_drones
	_text.text = "%d / %d" % [_free, _total]
	_slots.queue_redraw()


func free_count() -> int:
	return _free


func total_count() -> int:
	return _total


## A skin's theme changes the trough's fill and border, which the slots follow.
func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and _slots != null:
		_slots.queue_redraw()


## Between the trough's border, from just past the coin to the text: a slot per drone, free
## ones the accent's fill with the gloss, busy ones the trough's fill striped, an ink line
## between neighbours and one at either end, the pill's round end inked up to the first, so no
## sliver of trough shows by the coin.
func _draw_slots() -> void:
	if _total == 0:
		return
	# A skin whose trough is not a flat shape (a texture) gets skin A's trough colour and border.
	var box := get_theme_stylebox(&"panel", &"MeterTrough") as StyleBoxFlat
	var trough_fill := box.bg_color if box != null else Hud.TROUGH
	var border := float(box.border_width_top) if box != null else float(Hud.BORDER)
	var stripe := trough_fill.darkened(STRIPE_SHIFT) if trough_fill.get_luminance() > 0.5 \
		else trough_fill.lightened(STRIPE_SHIFT)
	var free_fill := Hud.meter_fill(Hud.ACCENT)
	var pen := HudIcon.Pen.new()
	var left := SLOTS_LEFT - Hud.METER_TROUGH_LEFT
	var right := SIZE.x - Hud.METER_TEXT_RIGHT - TEXT_WIDTH - Hud.METER_TROUGH_LEFT
	var top := border
	var bottom := SIZE.y - border
	# Ink in the pill's round end up to the first slot, behind the coin, so the trough shows
	# nowhere between the coin and the slots.
	var end := PackedVector2Array()
	for k: int in END_STEPS:
		end.append(Vector2.ONE * SIZE.y * 0.5 + Vector2.from_angle(TAU * k / END_STEPS) * (SIZE.y * 0.5 - border))
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(end, _box(Rect2(0, top, left, bottom - top))):
		pen.add_fill(piece, Hud.INK, false)
	pen.add_fill(_box(Rect2(SIZE.y * 0.5, top, left - SIZE.y * 0.5, bottom - top)), Hud.INK, false)
	for i: int in _total:
		var x0 := left + (right - left) * i / _total
		var x1 := left + (right - left) * (i + 1) / _total
		var slot := _box(Rect2(x0, top, x1 - x0, bottom - top))
		if i < _free:
			pen.add_fill(slot, free_fill, false)
			pen.add_fill(_box(Rect2(x0, top, x1 - x0, (bottom - top) / 3.0)), GLOSS, false)
		else:
			_striped(pen, slot, trough_fill, stripe)
	for i: int in _total + 1:
		var x := left + (right - left) * i / _total
		pen.add_stroke(PackedVector2Array([Vector2(x, top), Vector2(x, bottom)]), Hud.BORDER, Hud.INK, false)
	pen.draw(_slots)


## A busy slot: `fill` crossed by `stripe` in the meters' 45-degree bands, cut to `shape`.
static func _striped(pen: HudIcon.Pen, shape: PackedVector2Array, fill: Color, stripe: Color) -> void:
	pen.add_fill(shape, fill, false)
	var box := Rect2(shape[0], Vector2.ZERO)
	for point: Vector2 in shape:
		box = box.expand(point)
	var at := floorf((box.position.x + box.position.y) / Hud.STRIPE_TILE) * Hud.STRIPE_TILE
	while at < box.end.x + box.end.y:
		# The band x + y in [at, at + STRIPE_BAND], across the box.
		var band := PackedVector2Array([
			Vector2(at - box.position.y, box.position.y), Vector2(at + Hud.STRIPE_BAND - box.position.y, box.position.y),
			Vector2(at + Hud.STRIPE_BAND - box.end.y, box.end.y), Vector2(at - box.end.y, box.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(band, shape):
			pen.add_fill(piece, stripe, false)
		at += Hud.STRIPE_TILE


static func _box(rect: Rect2) -> PackedVector2Array:
	return PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end,
		Vector2(rect.position.x, rect.end.y)])
