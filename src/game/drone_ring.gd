class_name DroneRing
extends Control
## The top bar's drones (docs/reference/hud.md, **Top bar**): the drone icon inside a ring of
## one sector per drone, laid out symmetrically round the whole circle from the top, clockwise,
## with a gap between neighbours. The first `free` sectors are filled in the accent colour with
## a highlight along their outer third; the busy ones take the card-disabled tone. Every sector
## is ink-outlined, over an offset shadow under the whole ring. Drawn in code, vector, as one
## triangle array with the icon (`HudIcon.Pen`); it is redrawn only when set_counts changes a
## count, never per frame. It stops a touch on it, as any opaque part of the HUD does.

const SIZE := Vector2(56, 56)
const OUTER := 26.0
const INNER := 18.0
## Between neighbouring sectors, 6 degrees; a lone sector keeps it as a seam at the top.
const GAP := PI / 30.0
## Steps along each arc of a sector: at least 8, and one per 12 degrees of a longer one, so
## that the one or two sectors of a small base stay round.
const MIN_STEPS := 8
const STEP_ANGLE := PI / 15.0
const OUTLINE := 2.5
const SHADOW_OFFSET := Vector2(2, 2)
## A filled sector's highlight: a thin arc in the outer third of the ring, short of its ends.
const HIGHLIGHT := Color(1, 1, 1, 0.35)
const HIGHLIGHT_RADIUS := 23.6
const HIGHLIGHT_WIDTH := 1.6
const HIGHLIGHT_INSET := PI / 60.0
const ICON_SIZE := 30.0

var _free: int = 0
var _total: int = 0


func _init() -> void:
	custom_minimum_size = SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP


## Redraws only when a count changed.
func set_counts(free_drones: int, all_drones: int) -> void:
	if free_drones == _free and all_drones == _total:
		return
	_free = free_drones
	_total = all_drones
	queue_redraw()


func free_count() -> int:
	return _free


func total_count() -> int:
	return _total


func _draw() -> void:
	var centre := size * 0.5
	var pen := HudIcon.Pen.new()
	var sectors: Array[PackedVector2Array] = []
	for i: int in _total:
		var span := _span(i)
		sectors.append(_sector(centre, span.x, span.y))
	for sector: PackedVector2Array in sectors:
		pen.add_fill(_moved(sector, SHADOW_OFFSET), Hud.SHADOW, true)
	for i: int in sectors.size():
		var filled := i < _free
		pen.add_fill(sectors[i], Hud.ACCENT if filled else Hud.CARD_DISABLED, false)
		if filled:
			var span := _span(i)
			var arc := _arc(centre, HIGHLIGHT_RADIUS, span.x + HIGHLIGHT_INSET, span.y - HIGHLIGHT_INSET)
			pen.add_stroke(arc, HIGHLIGHT_WIDTH, HIGHLIGHT, false)
		pen.add_stroke(sectors[i], OUTLINE, Hud.INK, true)
	var icon := Vector2(ICON_SIZE, ICON_SIZE)
	HudIcon.paint(pen, "drones", Rect2(centre - icon * 0.5, icon), Hud.ACCENT)
	pen.draw(self)


## Sector `i`'s start and end angles: clockwise from the top, the gap split between its ends.
func _span(i: int) -> Vector2:
	var share := TAU / _total
	var start := -PI / 2.0 + share * i + GAP / 2.0
	return Vector2(start, start + share - GAP)


## The outer arc from `from` to `to`, then the inner arc back.
static func _sector(centre: Vector2, from: float, to: float) -> PackedVector2Array:
	var points := _arc(centre, OUTER, from, to)
	var inner := _arc(centre, INNER, from, to)
	inner.reverse()
	points.append_array(inner)
	return points


static func _arc(centre: Vector2, radius: float, from: float, to: float) -> PackedVector2Array:
	var steps := maxi(MIN_STEPS, ceili((to - from) / STEP_ANGLE))
	var points := PackedVector2Array()
	for i: int in steps + 1:
		var angle := from + (to - from) * i / steps
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


static func _moved(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var moved := PackedVector2Array()
	for point: Vector2 in points:
		moved.append(point + offset)
	return moved
