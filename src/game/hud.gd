class_name Hud
extends CanvasLayer
## On-screen UI, built in code. Reads BaseState for display and reports presses as
## signals; it never changes game state itself.
##
## The look is the comic style's: one Theme (_make_theme) holds the two fonts, the UI palette
## and the ink-outlined shapes, and every control takes its style from it by type variation
## (docs/reference/hud.md, **Theme**).
##
## Touch rule: any Control that isn't IGNORE swallows touches over it, so layout-only
## containers that span empty screen space must use MOUSE_FILTER_IGNORE or the world
## underneath stops responding.
##
## Every part sits inside the device's safe area (clear of notches and the home
## indicator), refitted when the window resizes; apply_safe_area() sets it directly. The
## build panel alone reaches the screen's edges, with its content inside the safe area.

signal build_pressed(type: String)
signal confirm_pressed
signal cancel_pressed
signal upgrade_pressed
signal close_pressed
signal reset_pressed
signal template_pressed

const ERROR_TEXT := {
	BaseState.ERR_BLOCKED: "That spot is taken",
	BaseState.ERR_LIMIT: "You've built the maximum for your Command Center level",
	BaseState.ERR_CC_LEVEL: "Upgrade your Command Center first",
	BaseState.ERR_NO_BUILDER: "All drones are busy",
	BaseState.ERR_FUNDS: "Not enough resources",
	BaseState.ERR_BUSY: "Already under construction",
	BaseState.ERR_MAX_LEVEL: "Already at max level",
}

# The UI palette (docs/reference/hud.md, **Theme**).
const INK := Color("1b1a2e")
## Every flat shadow: the ink at 60 %.
const SHADOW := Color("1b1a2e", 0.6)
const PANEL := Color("262348", 0.96)
const CARD := Color("3b3670")
const CARD_DISABLED := Color("2e2b55")
const TEXT := Color("f4f2ff")
const TEXT_DIM := Color("9a95c4")
const ACCENT := Color("58e8ff")
const GOLD := Color("ffc13b")
const GOLD_PRESSED := Color("e0a52a")
const TROUGH := Color("17162a")
## The info panel's note when an upgrade is refused.
const WARNING := Color("ffb37a")
## The stripe along the top of a build card, by category: the category's MaterialKit role.
const CATEGORY_STRIPE := {
	"resources": MaterialKit.ENERGY,
	"army": MaterialKit.ARMY,
	"defense": MaterialKit.DEFENCE,
	"traps": MaterialKit.HAZARD,
	"walls": MaterialKit.WALL,
}
## Text on a disabled button, and a card's name and cost while it cannot be built.
const DISABLED_ALPHA := 0.55
## outline_size per pixel of ink round a text: the font's stroke reaches a quarter of
## outline_size out from each glyph.
const OUTLINE_PER_PX := 4
const BUTTON_TEXT_COLORS := ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color",
	"font_focus_color"]

## Bangers for the Build button, the tabs, the close button and the titles; Lilita One for
## every other text.
const DISPLAY_FONT: FontFile = preload("res://assets/fonts/bangers/Bangers-Regular.ttf")
const BODY_FONT: FontFile = preload("res://assets/fonts/lilitaone/LilitaOne-Regular.ttf")

const MARGIN := 16
## Every shape's ink border.
const BORDER := 3
## Round a button's text: its minimum size, not its text, sets how big it is.
const BUTTON_MARGIN := 6.0
const TAB_SIZE := Vector2(140, 48)
const CLOSE_SIZE := Vector2(48, 48)
const CARD_SIZE := Vector2(200, 120)
## The category stripe along a card's top, inside its border.
const STRIPE_HEIGHT := 6
const BUILD_SIZE := Vector2(128, 64)
const METER_SIZE := Vector2(220, 36)
## A meter's icon sits over the left end of its trough, which starts this far in.
const METER_ICON := Vector2(40, 40)
const METER_TROUGH_LEFT := 20.0
## What the fill grows across: the trough inside its border.
const METER_TRACK := Vector2(METER_SIZE.x - METER_TROUGH_LEFT - 2 * BORDER, METER_SIZE.y - 2 * BORDER)
## The fill's texture: a tile this many pixels square crossed by a 45-degree band this wide.
## The band is white and the rest STRIPE_BASE grey, so the band is 25 % lighter; the fill's
## modulate is the resource's colour over STRIPE_BASE, so the rest reads as the colour itself.
const STRIPE_TILE := 16
const STRIPE_BAND := 6
const STRIPE_BASE := 0.8
## Across the top third of the fill.
const GLOSS := Color(1, 1, 1, 0.25)
## The build panel's height, never past a share of the screen's.
const MENU_HEIGHT := 300.0
const MENU_MAX_SHARE := 0.4
const MENU_OPEN_SECONDS := 0.18
const MENU_CLOSE_SECONDS := 0.14
## Pressing the selected tab again scrolls its strip back to the start over this long.
const STRIP_RETURN_SECONDS := 0.2

## The dev cheats are on (main.gd): every meter shows, full, reading "∞" instead of amount / cap.
var cheats: bool = false
var _catalog: Catalog
var _theme: Theme
## Holds every part but the build panel; positioned on the safe area.
var _root: Control
## The last safe area fitted from the device, in the HUD's coordinates.
var _fitted_area: Rect2 = Rect2()
## The top bar's rows: the meters and the drone ring, then the debug buttons in debug builds.
var _top: VBoxContainer
## Each resource's meter, the fill that grows across it, and its amount.
var _meters: Dictionary[String, Control] = {}
var _meter_fills: Dictionary[String, Control] = {}
var _meter_labels: Dictionary[String, Label] = {}
var _drone_ring: DroneRing
var _build_button: Button
## The build panel, outside the root and under it, so the Build button draws over it.
var _menu: PanelContainer
## Pads the panel's content to the safe area.
var _menu_inset: MarginContainer
## Whether the panel is open or opening.
var _menu_open: bool = false
var _menu_tween: Tween
var _close_button: Button
var _tab_buttons: Dictionary[String, Button] = {}
var _entry_scroll: ScrollContainer
var _strip_tween: Tween
var _entries: Dictionary[String, Button] = {}
## Each card's name and cost, dimmed while it cannot be built.
var _entry_heading: Dictionary[String, Control] = {}
## Each card's last line: built / max, or why it cannot be built.
var _entry_status: Dictionary[String, Label] = {}
## The selected build-menu category. Remembered while the game runs, not saved.
var _tab: String = ""
## The state of the last refresh, so a tab change can fill its cards.
var _state: BaseState
var _place_bar: Control
var _place_button: Button
var _info_panel: Control
var _info_title: Label
var _info_detail: Label
var _upgrade_button: Button
var _upgrade_note: Label
## Between a stat and the next level's: " → " when the theme's font has the arrow, else " > ".
var _arrow: String = " > "
var _toast: Control
var _toast_label: Label
var _toast_tween: Tween
var _reset_button: Button
var _template_button: Button


func setup(catalog: Catalog) -> void:
	_catalog = catalog
	_theme = _make_theme()
	_build_menu()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _theme
	add_child(_root)
	if _root.get_theme_default_font().has_char(0x2192):
		_arrow = " → "
	_build_top_bar()
	_build_build_button()
	_build_place_bar()
	_build_info_panel()
	_build_toast()
	if OS.is_debug_build():
		_build_debug_buttons()
	get_viewport().size_changed.connect(_fit_safe_area)
	_fit_safe_area()


## `painting`: walls are being painted, so Place reads Done and is always enabled; there is
## nothing to confirm, and Done ends the mode.
func refresh(state: BaseState, selected_id: int, placing: bool, ghost_ok: bool, painting: bool) -> void:
	_state = state
	# The safe area can move without a resize: turning a phone over moves the notch to the
	# other side. Every refresh, the 1 s tick's included, checks it.
	_fit_safe_area()
	for res: String in _meters:
		# A resource the base has no storage for yet (antimatter, early on) is hidden, unless
		# the cheats make every resource infinite.
		var capacity := state.capacity(res)
		_meters[res].visible = capacity > 0 or cheats
		var amount: int = state.resources[res]
		var fraction := clampf(float(amount) / capacity, 0.0, 1.0) if capacity > 0 else 0.0
		if cheats:
			fraction = 1.0
		_meter_fills[res].size = Vector2(roundf(METER_TRACK.x * fraction), METER_TRACK.y)
		_meter_labels[res].text = "∞" if cheats else "%s / %s" % [Format.amount(amount), Format.amount(capacity)]
	_drone_ring.set_counts(state.builders_free(), state.builders_total())

	var has_selection := selected_id != 0 and state.buildings.has(selected_id)
	# Placing, painting or selecting a building in the world closes the build panel.
	if placing or has_selection:
		_slide_menu(false)
	_build_button.visible = not placing
	_place_bar.visible = placing
	_place_button.text = "Done" if painting else "Place"
	_place_button.disabled = not ghost_ok and not painting
	_info_panel.visible = not placing and has_selection
	if _menu_open:
		_refresh_entries(state)
	if _info_panel.visible:
		_refresh_info(state, state.buildings[selected_id])


## Placement began, ended or its ghost moved. A move changes only the Place button, so
## the top bar and the cards wait for the next state change or tick; a start or an end
## swaps the bottom bar, which takes the full refresh.
func refresh_placing(state: BaseState, selected_id: int, placing: bool, ghost_ok: bool, painting: bool) -> void:
	if placing and _place_bar.visible:
		_place_button.disabled = not ghost_ok and not painting
		return
	refresh(state, selected_id, placing, ghost_ok, painting)


## Lays every part out inside `inset`, a rect in the HUD's own coordinates (the
## viewport's visible rect, 1280x720 on a 16:9 screen). The HUD fits the device's safe
## area itself; the harness calls this to try a notch-like inset.
func apply_safe_area(inset: Rect2) -> void:
	var full := get_viewport().get_visible_rect().size
	_root.offset_left = inset.position.x
	_root.offset_top = inset.position.y
	_root.offset_right = inset.end.x - full.x
	_root.offset_bottom = inset.end.y - full.y
	# The build panel spans the screen's width and reaches its bottom edge, with its content
	# padded into the safe area.
	_menu_inset.add_theme_constant_override("margin_left", roundi(inset.position.x))
	_menu_inset.add_theme_constant_override("margin_right", roundi(full.x - inset.end.x))
	_menu_inset.add_theme_constant_override("margin_bottom", roundi(full.y - inset.end.y))
	_menu.custom_minimum_size.y = minf(MENU_HEIGHT, full.y * MENU_MAX_SHARE)
	if _menu_open:
		# Open, or opening: on the bottom edge at its own height, which the panel grows upward
		# to. A slide under way was aimed at the old screen's bottom edge, so it stops here.
		_menu_tween.kill()
		_menu.offset_top = 0.0
		_menu.offset_bottom = 0.0


## DisplayServer reports the safe area in screen pixels; on desktop it is the screen's
## usable rect, so it is clipped to the window first. The canvas_items stretch maps the
## window onto the visible rect, so the scale between them is their size ratio. A window
## with no size (headless) gets the whole rect. It applies only a rect that differs from
## the last one it fitted, so an inset the harness applied stays until the device's changes.
func _fit_safe_area() -> void:
	var visible_rect := get_viewport().get_visible_rect()
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area().intersection(window)
	var area := visible_rect
	if safe.has_area():
		var ui_scale := visible_rect.size / Vector2(window.size)
		area = Rect2(Vector2(safe.position - window.position) * ui_scale, Vector2(safe.size) * ui_scale)
	if area == _fitted_area:
		return
	_fitted_area = area
	apply_safe_area(area)


func show_message(text: String) -> void:
	_toast_label.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6).set_delay(1.8)
	_toast_tween.tween_callback(_toast.hide)


func show_error(code: String) -> void:
	show_message(error_text(code))


static func error_text(code: String) -> String:
	return str(ERROR_TEXT.get(code, code))


# --- Queries for the harness -----------------------------------------------------

func build_button() -> Button:
	return _build_button


## Whether the build panel is open, or sliding open.
func is_menu_open() -> bool:
	return _menu_open


## The build panel itself; hidden while closed.
func build_panel() -> Control:
	return _menu


func close_button() -> Button:
	return _close_button


func tab_button(category: String) -> Button:
	return _tab_buttons[category]


## A build card.
func entry_button(type: String) -> Button:
	return _entries[type]


## A card's last line: built / max, or why it cannot be built.
func entry_status(type: String) -> String:
	return _entry_status[type].text


## The horizontal strip the cards scroll in.
func entry_strip() -> ScrollContainer:
	return _entry_scroll


## The top bar's meter for one resource; hidden while the base cannot store it.
func resource_panel(res: String) -> Control:
	return _meters[res]


## A meter's fill; its parent is the track it grows across.
func resource_fill(res: String) -> Control:
	return _meter_fills[res]


func place_button() -> Button:
	return _place_button


func drones_panel() -> DroneRing:
	return _drone_ring


## The debug Reset base button; null in a release build.
func reset_button() -> Button:
	return _reset_button


## The debug Template base button; null in a release build.
func template_button() -> Button:
	return _template_button


# --- The build panel -------------------------------------------------------------

## Build toggles the panel. Opening it closes a selected building's info panel first, as
## its Close would: the two never show together.
func _on_build_button() -> void:
	if not _menu_open and _info_panel.visible:
		close_pressed.emit()
	_slide_menu(not _menu_open)


func _on_card_pressed(type: String) -> void:
	_slide_menu(false)
	build_pressed.emit(type)


## Slides the panel up from below the screen's bottom edge, or back down and out of the
## way: hidden once down, so it blocks nothing. A new slide replaces one under way.
func _slide_menu(open: bool) -> void:
	if open == _menu_open:
		return
	_menu_open = open
	if _menu_tween != null:
		_menu_tween.kill()
	var bottom := get_viewport().get_visible_rect().size.y
	if open:
		if not _menu.visible:
			# On the bottom edge at its own height, then moved down out of sight.
			_menu.offset_top = 0.0
			_menu.offset_bottom = 0.0
			_menu.position.y = bottom
			_menu.show()
		if _state != null:
			_refresh_entries(_state)
	_menu_tween = create_tween()
	var target := bottom - _menu.size.y if open else bottom
	_menu_tween.tween_property(_menu, "position:y", target, MENU_OPEN_SECONDS if open else MENU_CLOSE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if not open:
		_menu_tween.tween_callback(_menu.hide)


# --- Refresh helpers -------------------------------------------------------------

## Only the selected tab's cards; the others are hidden. A card that cannot be built now
## dims its name and cost and gives its reason, still readable, in place of its count.
func _refresh_entries(state: BaseState) -> void:
	for type: String in _entries:
		if _catalog.category_of(type) != _tab:
			continue
		var error := state.check_can_build(type)
		var status: Label = _entry_status[type]
		status.text = _entry_status_text(state, type, error)
		status.theme_type_variation = &"CardCount" if error == "" else &"CardReason"
		_entries[type].disabled = error != ""
		_entry_heading[type].modulate.a = 1.0 if error == "" else DISABLED_ALPHA


func _entry_status_text(state: BaseState, type: String, error: String) -> String:
	if error == "":
		return "%d / %d" % [state.count_of(type), _catalog.max_count(type, state.cc_level())]
	var first := _catalog.level_stats(type, 1)
	if error == BaseState.ERR_CC_LEVEL:
		return "Needs Command Center %d" % int(first.get("requires_cc", 1))
	if error == BaseState.ERR_LIMIT:
		return "Max built"
	if error == BaseState.ERR_NO_BUILDER:
		return "No free drone"
	if error == BaseState.ERR_FUNDS:
		var cost: Dictionary = first.get("cost", {})
		for res: String in _catalog.resources:
			if state.resources[res] < int(cost.get(res, 0)):
				return "Not enough %s" % _catalog.resource_name(res)
	return error_text(error)


## The selected tab takes the TabSelected style, the others TabButton's.
func _select_tab(category: String) -> void:
	_tab = category
	for id: String in _tab_buttons:
		_tab_buttons[id].theme_type_variation = &"TabSelected" if id == category else &"TabButton"
	_tab_buttons[category].button_pressed = true
	for type: String in _entries:
		_entries[type].visible = _catalog.category_of(type) == category
	# A return still under way on the last tab would go on scrolling this one.
	if _strip_tween != null:
		_strip_tween.kill()
	_entry_scroll.scroll_horizontal = 0
	if _state != null and _menu_open:
		_refresh_entries(_state)


## A press on the selected tab scrolls its strip back to the start; on another, selects it.
func _on_tab_pressed(category: String) -> void:
	if category != _tab:
		_select_tab(category)
		return
	if _strip_tween != null:
		_strip_tween.kill()
	_strip_tween = create_tween()
	_strip_tween.tween_property(_entry_scroll, "scroll_horizontal", 0, STRIP_RETURN_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _refresh_info(state: BaseState, building: BuildingState) -> void:
	var type := building.type
	_info_title.text = "%s   Lv %d" % [_catalog.display_name(type), building.level]

	# The current level's stats (level 1's while it is first being built), each with the
	# next level's value after an arrow where it changes. `next` is {} at the top level,
	# and level 1 itself while the building is first being built, so no arrow shows then.
	var lines := PackedStringArray()
	var stats := _catalog.level_stats(type, maxi(building.level, 1))
	var next := _catalog.level_stats(type, building.level + 1)
	if stats.has("hp"):
		lines.append("Hull %s" % _level_stat(stats, next, "hp"))
	var production: Dictionary = stats.get("produces", {})
	var next_production: Dictionary = next.get("produces", {})
	for res: String in _catalog.resources:
		var produces := int(production.get(res, 0))
		if produces > 0:
			var rate := _with_next(Format.amount(produces), Format.amount(int(next_production.get(res, produces))))
			lines.append("Produces %s %s/h" % [rate, _catalog.resource_name(res)])
	var storage: Dictionary = stats.get("storage", {})
	var next_storage: Dictionary = next.get("storage", {})
	for res: String in _catalog.resources:
		var stores := int(storage.get(res, 0))
		if stores > 0:
			var held := _with_next(Format.amount(stores), Format.amount(int(next_storage.get(res, stores))))
			lines.append("Stores %s %s" % [held, _catalog.resource_name(res)])
	if int(stats.get("builders", 0)) > 0:
		lines.append("Houses %s drone" % _level_stat(stats, next, "builders"))
	if stats.has("capacity"):
		lines.append("Capacity %s" % _level_stat(stats, next, "capacity"))
	var combat := PackedStringArray()
	if stats.has("damage"):
		combat.append("Damage %s" % _level_stat(stats, next, "damage"))
	if stats.has("range_cells"):
		combat.append("Range %s" % _level_stat(stats, next, "range_cells"))
	if not combat.is_empty():
		lines.append("   ".join(combat))
	if stats.has("fire_ms"):
		var fire_ms := int(stats["fire_ms"])
		var interval := _with_next(_seconds(fire_ms), _seconds(int(next.get("fire_ms", fire_ms))))
		lines.append("Fires every %s s" % interval)
	var targets := _catalog.targets_of(type)
	if targets != "":
		lines.append("Targets %s" % ("air and ground" if targets == "both" else targets))
	if _catalog.is_hidden(type):
		lines.append("Hidden from attackers")
	if building.is_busy():
		var what := "Under construction" if building.level == 0 else "Upgrading to Lv %d" % building.target_level
		lines.append("%s: %s left" % [what, Format.duration(state.seconds_left(building.id))])
	_info_detail.text = "\n".join(lines)

	_upgrade_note.text = ""
	if building.is_busy():
		_upgrade_button.text = "Under construction"
		_upgrade_button.disabled = true
		return
	if building.level >= _catalog.max_level(type):
		_upgrade_button.text = "Max level"
		_upgrade_button.disabled = true
		return
	_upgrade_button.text = "Upgrade to Lv %d   %s   (%s)" % [
		building.level + 1,
		Format.cost(next.get("cost", {}), _catalog),
		Format.duration(int(next.get("build_seconds", 0))),
	]
	var error := state.check_upgrade(building.id)
	_upgrade_button.disabled = error != ""
	_upgrade_note.text = "" if error == "" else error_text(error)


## A whole-number stat of this level, with the next level's after an arrow when it changes.
func _level_stat(stats: Dictionary, next: Dictionary, field: String) -> String:
	var value := int(stats[field])
	return _with_next(Format.amount(value), Format.amount(int(next.get(field, value))))


## "600", or "600 → 800" when the next level's value differs.
func _with_next(value: String, next_value: String) -> String:
	return value if next_value == value else value + _arrow + next_value


## 800 -> "0.8", 5000 -> "5"
static func _seconds(ms: int) -> String:
	return ("%.2f" % (ms / 1000.0)).rstrip("0").rstrip(".")


# --- Construction ----------------------------------------------------------------

## The top-left row: a meter per resource, then the drone ring.
func _build_top_bar() -> void:
	_top = VBoxContainer.new()
	_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_top.add_theme_constant_override("separation", 10)
	_root.add_child(_top)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.offset_left = MARGIN
	_top.offset_right = -MARGIN
	_top.offset_top = MARGIN
	_top.offset_bottom = MARGIN
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 14)
	_top.add_child(bar)
	var stripe := _make_stripe()
	for res: String in _catalog.resources:
		_build_meter(bar, res, stripe)
	_drone_ring = DroneRing.new()
	bar.add_child(_drone_ring)


## One resource's meter: a trough that the fill, textured with `stripe`, grows across by
## amount over storage, the amount on it, and the resource's icon over its left end. The meter
## stops a touch on it, as any opaque part does, so it never selects or drags what lies under
## it; its parts take none.
func _build_meter(parent: Control, res: String, stripe: Texture2D) -> void:
	var color := _resource_color(res)
	var meter := Control.new()
	meter.mouse_filter = Control.MOUSE_FILTER_STOP
	meter.custom_minimum_size = METER_SIZE
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(meter)
	var trough := Panel.new()
	trough.mouse_filter = Control.MOUSE_FILTER_IGNORE
	trough.theme_type_variation = &"MeterTrough"
	meter.add_child(trough)
	trough.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trough.offset_left = METER_TROUGH_LEFT
	var track := Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.position = Vector2(BORDER, BORDER)
	track.size = METER_TRACK
	trough.add_child(track)
	var fill := Control.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.clip_contents = true
	fill.size = Vector2(0, METER_TRACK.y)
	track.add_child(fill)
	# The stripes and the gloss span the whole track; the fill's clip cuts them to the amount.
	var stripes := TextureRect.new()
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripes.texture = stripe
	stripes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stripes.stretch_mode = TextureRect.STRETCH_TILE
	stripes.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	stripes.modulate = Color(color.r / STRIPE_BASE, color.g / STRIPE_BASE, color.b / STRIPE_BASE)
	stripes.size = METER_TRACK
	fill.add_child(stripes)
	var gloss := ColorRect.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.color = GLOSS
	gloss.size = Vector2(METER_TRACK.x, METER_TRACK.y / 3.0)
	fill.add_child(gloss)
	# The ink border again over the fill, so the fill's square ends never cover its corners.
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme_type_variation = &"MeterFrame"
	trough.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"MeterText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trough.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = METER_ICON.x - METER_TROUGH_LEFT
	var icon := HudIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.kind = res
	icon.color = color
	icon.position = Vector2(0, (METER_SIZE.y - METER_ICON.y) / 2.0)
	icon.size = METER_ICON
	meter.add_child(icon)
	_meters[res] = meter
	_meter_fills[res] = fill
	_meter_labels[res] = label


## Bottom right: toggles the build panel.
func _build_build_button() -> void:
	_build_button = _button("BUILD", BUILD_SIZE, &"BuildButton")
	_build_button.pressed.connect(_on_build_button)
	_root.add_child(_build_button)
	_build_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_build_button.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_build_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_build_button.offset_left = -MARGIN - BUILD_SIZE.x
	_build_button.offset_right = -MARGIN
	_build_button.offset_top = -MARGIN - BUILD_SIZE.y
	_build_button.offset_bottom = -MARGIN


## The tabs and the close button over a horizontal strip of cards, beside a column kept clear
## for the Build button. Every menu type gets a card up front; a tab shows its category's
## cards, in menu_order order. The panel stops every touch on it from reaching the world;
## its layout containers pass touches on to it.
func _build_menu() -> void:
	_menu = PanelContainer.new()
	_menu.theme = _theme
	_menu.theme_type_variation = &"MenuPanel"
	_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_menu.visible = false
	add_child(_menu)
	_menu.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_menu.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_menu.offset_left = 0.0
	_menu.offset_right = 0.0
	_menu.offset_top = 0.0
	_menu.offset_bottom = 0.0
	_menu_inset = MarginContainer.new()
	_menu_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.add_child(_menu_inset)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 12)
	_menu_inset.add_child(column)

	var tabs := HBoxContainer.new()
	tabs.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tabs.add_theme_constant_override("separation", 10)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for category: String in _catalog.categories:
		var tab := _button(_catalog.category_name(category), TAB_SIZE, &"TabButton")
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(_on_tab_pressed.bind(category))
		tabs.add_child(tab)
		_tab_buttons[category] = tab
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(gap)
	_close_button = _button("X", CLOSE_SIZE, &"CloseButton")
	_close_button.pressed.connect(func() -> void: _slide_menu(false))
	tabs.add_child(_close_button)

	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 0)
	column.add_child(row)
	_entry_scroll = ScrollContainer.new()
	_entry_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_entry_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_entry_scroll.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_entry_scroll.custom_minimum_size = Vector2(0, CARD_SIZE.y + 22)
	row.add_child(_entry_scroll)
	# Room for the cards' shadows, which fall outside them, at the strip's end and bottom.
	var room := MarginContainer.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_theme_constant_override("margin_right", 6)
	room.add_theme_constant_override("margin_bottom", 6)
	_entry_scroll.add_child(room)
	var cards := HBoxContainer.new()
	cards.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards.add_theme_constant_override("separation", 12)
	room.add_child(cards)
	for type: String in _catalog.menu_order:
		cards.add_child(_build_entry(type))
	# The Build button stays over the open panel at the safe area's corner; nothing goes under it.
	var clear := Control.new()
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear.custom_minimum_size = Vector2(BUILD_SIZE.x + MARGIN, 0)
	row.add_child(clear)
	_select_tab(_catalog.categories[0])


## A card: the category's stripe along its top, then three lines: the name, the level 1
## cost (each amount in its resource's colour), and the status line `_refresh_entries` fills.
func _build_entry(type: String) -> Button:
	var button := _button("", CARD_SIZE)
	# PASS, so a drag that starts on a card reaches the ScrollContainer and scrolls the
	# strip; the panel behind still stops the touch from reaching the world.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_card_pressed.bind(type))
	var stripe := Panel.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.theme_type_variation = &"CardStripe"
	var stripe_color: Color = CATEGORY_STRIPE.get(_catalog.category_of(type), ACCENT)
	stripe.self_modulate = stripe_color
	button.add_child(stripe)
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_left = BORDER
	stripe.offset_right = -BORDER
	stripe.offset_top = BORDER
	stripe.offset_bottom = BORDER + STRIPE_HEIGHT
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 2)
	button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_top = BORDER + STRIPE_HEIGHT + 2
	content.offset_right = -10
	content.offset_bottom = -BORDER - 2
	var heading := VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 0)
	content.add_child(heading)
	var name_label := _card_label(heading, _catalog.display_name(type), &"CardName")
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 12)
	heading.add_child(cost_row)
	var cost: Dictionary = _catalog.level_stats(type, 1).get("cost", {})
	if cost.is_empty():
		_card_label(cost_row, "Free", &"CardCost")
	for res: Variant in cost:
		var amount := _card_label(cost_row, Format.amount(int(cost[res])), &"CardCost")
		amount.add_theme_color_override("font_color", _resource_color(str(res)))
	var status := _card_label(content, "", &"CardCount")
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_entry_heading[type] = heading
	_entry_status[type] = status
	_entries[type] = button
	return button


## Cancel and Place on a panel at the bottom centre.
func _build_place_bar() -> void:
	var panel := PanelContainer.new()
	_root.add_child(panel)
	_anchor_bottom(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var cancel := _button("Cancel", Vector2(170, 72), &"BarButton")
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	row.add_child(cancel)
	_place_button = _button("Place", Vector2(170, 72), &"ConfirmButton")
	_place_button.pressed.connect(func() -> void: confirm_pressed.emit())
	row.add_child(_place_button)
	_place_bar = panel


func _build_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	_root.add_child(panel)
	_anchor_bottom(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_info_title = Label.new()
	_info_title.theme_type_variation = &"InfoTitle"
	_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_info_title)
	var close := _button("Close", Vector2(96, 44))
	close.pressed.connect(func() -> void: close_pressed.emit())
	header.add_child(close)

	_info_detail = Label.new()
	_info_detail.theme_type_variation = &"InfoDetail"
	column.add_child(_info_detail)
	_upgrade_button = _button("", Vector2(0, 64), &"UpgradeButton")
	_upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit())
	column.add_child(_upgrade_button)
	_upgrade_note = Label.new()
	_upgrade_note.theme_type_variation = &"InfoNote"
	column.add_child(_upgrade_note)
	_info_panel = panel


## Top centre, 96 down. It takes no touch, and is hidden once it has faded.
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_left = 0
	_toast.offset_right = 0
	_toast.offset_top = 96
	_toast.offset_bottom = 96
	_toast_label = Label.new()
	_toast_label.theme_type_variation = &"ToastText"
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_child(_toast_label)


## Debug builds only: start over without digging through user:// for the save file, or swap
## the base for the template, every type at its top level (TemplateBase). On a row of its own
## under the top bar, right-aligned, so a long top bar never runs under it.
func _build_debug_buttons() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	_top.add_child(row)
	var template := _button("Template base", Vector2(150, 48), &"DebugButton")
	template.pressed.connect(func() -> void: template_pressed.emit())
	row.add_child(template)
	_template_button = template
	var reset := _button("Reset base", Vector2(150, 48), &"DebugButton")
	reset.pressed.connect(func() -> void: reset_pressed.emit())
	row.add_child(reset)
	_reset_button = reset


func _card_label(parent: Control, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(label)
	return label


func _button(text: String, min_size: Vector2, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


## Pins a control to the bottom centre; it grows upward to fit its content.
func _anchor_bottom(control: Control) -> void:
	control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	control.grow_horizontal = Control.GROW_DIRECTION_BOTH
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control.offset_left = 0
	control.offset_right = 0
	control.offset_top = -MARGIN
	control.offset_bottom = -MARGIN


## A resource's colour from the catalog; the text colour when it has none.
func _resource_color(res: String) -> Color:
	return Color.from_string(_catalog.resource_color(res), TEXT)


## The fill's texture: a 45-degree band, white, across the STRIPE_BASE grey, its edges
## smoothed by sampling each pixel 4 x 4. It tiles seamlessly both ways.
static func _make_stripe() -> ImageTexture:
	var image := Image.create_empty(STRIPE_TILE, STRIPE_TILE, false, Image.FORMAT_RGBA8)
	for y: int in STRIPE_TILE:
		for x: int in STRIPE_TILE:
			var covered := 0
			for sample: int in 16:
				var along := fposmod(x + y + (sample % 4 + 0.5) / 4.0 + (sample / 4 + 0.5) / 4.0, STRIPE_TILE)
				if along < STRIPE_BAND:
					covered += 1
			var value := lerpf(STRIPE_BASE, 1.0, covered / 16.0)
			image.set_pixel(x, y, Color(value, value, value))
	return ImageTexture.create_from_image(image)


# --- Theme -----------------------------------------------------------------------

## The comic theme: Lilita One by default, Bangers where a variation says so; flat fills
## with a 3 px ink border and a flat ink shadow; text in the UI palette.
func _make_theme() -> Theme:
	var ui := Theme.new()
	ui.default_font = BODY_FONT
	ui.default_font_size = 20
	ui.set_color("font_color", "Label", TEXT)
	ui.set_color("font_outline_color", "Label", INK)

	# Panels: the info panel and the place bar take PanelContainer's; the rest are variations.
	ui.set_stylebox("panel", "PanelContainer", _shape(PANEL, 12))
	var menu := StyleBoxFlat.new()
	menu.bg_color = PANEL
	menu.border_color = INK
	menu.border_width_top = BORDER
	menu.corner_radius_top_left = 16
	menu.corner_radius_top_right = 16
	menu.content_margin_left = MARGIN
	menu.content_margin_right = MARGIN
	menu.content_margin_top = 12
	menu.content_margin_bottom = MARGIN
	ui.set_type_variation(&"MenuPanel", &"PanelContainer")
	ui.set_stylebox("panel", &"MenuPanel", menu)
	var toast := _shape(PANEL, 10)
	toast.content_margin_left = 18
	toast.content_margin_right = 18
	toast.content_margin_top = 8
	toast.content_margin_bottom = 8
	ui.set_type_variation(&"Toast", &"PanelContainer")
	ui.set_stylebox("panel", &"Toast", toast)

	# The meters: the trough under the fill, and its ink border again over it.
	ui.set_type_variation(&"MeterTrough", &"Panel")
	ui.set_stylebox("panel", &"MeterTrough", _shape(TROUGH, 10))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = INK
	frame.set_border_width_all(BORDER)
	frame.set_corner_radius_all(10)
	ui.set_type_variation(&"MeterFrame", &"Panel")
	ui.set_stylebox("panel", &"MeterFrame", frame)
	# White, tinted to the category by the stripe's self_modulate; its top corners follow the
	# card's inside its border.
	var stripe := StyleBoxFlat.new()
	stripe.bg_color = Color.WHITE
	stripe.corner_radius_top_left = 12 - BORDER
	stripe.corner_radius_top_right = 12 - BORDER
	ui.set_type_variation(&"CardStripe", &"Panel")
	ui.set_stylebox("panel", &"CardStripe", stripe)

	# Buttons: a card unless a variation says otherwise. None takes focus.
	_button_shapes(ui, &"Button", CARD, CARD, 12)
	ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for item: String in BUTTON_TEXT_COLORS:
		ui.set_color(item, "Button", TEXT)
	ui.set_color("font_disabled_color", "Button", Color(TEXT, DISABLED_ALPHA))
	ui.set_color("font_outline_color", "Button", INK)
	_button_variation(ui, &"BuildButton", GOLD, GOLD_PRESSED, 12, DISPLAY_FONT, 30, 4)
	_button_variation(ui, &"UpgradeButton", GOLD, GOLD_PRESSED, 12, BODY_FONT, 20, 3)
	_button_variation(ui, &"ConfirmButton", ACCENT, ACCENT.darkened(0.15), 12, DISPLAY_FONT, 22, 0, INK)
	_button_variation(ui, &"BarButton", CARD, CARD, 12, DISPLAY_FONT, 22, 0)
	_button_variation(ui, &"DebugButton", CARD, CARD, 12, DISPLAY_FONT, 20, 0)
	_button_variation(ui, &"CloseButton", CARD, CARD, 12, DISPLAY_FONT, 28, 3)
	_button_variation(ui, &"TabButton", CARD, CARD, 10, DISPLAY_FONT, 24, 3)
	# The selected tab: cyan in every state, ink text with no outline.
	_button_variation(ui, &"TabSelected", ACCENT, ACCENT, 10, DISPLAY_FONT, 24, 0, INK)
	for item: String in ["normal", "hover", "pressed", "hover_pressed"]:
		ui.set_stylebox(item, &"TabSelected", _shape(ACCENT, 10, BUTTON_MARGIN))

	_label_variation(ui, &"CardName", 20, TEXT, 2)
	_label_variation(ui, &"CardCost", 18, TEXT, 0)
	_label_variation(ui, &"CardCount", 16, TEXT_DIM, 0)
	_label_variation(ui, &"CardReason", 15, TEXT_DIM, 0)
	_label_variation(ui, &"MeterText", 18, TEXT, 2, _meter_font())
	_label_variation(ui, &"InfoTitle", 24, TEXT, 0, DISPLAY_FONT)
	_label_variation(ui, &"InfoDetail", 17, TEXT, 0)
	_label_variation(ui, &"InfoNote", 17, WARNING, 0)
	_label_variation(ui, &"ToastText", 18, TEXT, 0)

	# The card strip's scroll bar: a dim grabber on an ink track.
	var track := _flat(Color(INK, 0.6), 4)
	ui.set_stylebox("scroll", "HScrollBar", track)
	ui.set_stylebox("scroll_focus", "HScrollBar", track)
	ui.set_stylebox("grabber", "HScrollBar", _flat(TEXT_DIM, 4))
	ui.set_stylebox("grabber_highlight", "HScrollBar", _flat(TEXT, 4))
	ui.set_stylebox("grabber_pressed", "HScrollBar", _flat(ACCENT, 4))
	return ui


## `outline`: the ink round the text, in pixels; 0 for none.
static func _button_variation(ui: Theme, variation: StringName, fill: Color, pressed: Color, radius: int,
		font: Font, font_size: int, outline: int, text: Color = TEXT) -> void:
	ui.set_type_variation(variation, &"Button")
	_button_shapes(ui, variation, fill, pressed, radius)
	ui.set_font("font", variation, font)
	ui.set_font_size("font_size", variation, font_size)
	ui.set_constant("outline_size", variation, outline * OUTLINE_PER_PX)
	for item: String in BUTTON_TEXT_COLORS:
		ui.set_color(item, variation, text)


## Every state but focus: hover a shade lighter, pressed sunk onto its shadow, disabled in the
## card-disabled fill.
static func _button_shapes(ui: Theme, type: StringName, fill: Color, pressed: Color, radius: int) -> void:
	ui.set_stylebox("normal", type, _shape(fill, radius, BUTTON_MARGIN))
	ui.set_stylebox("hover", type, _shape(fill.lightened(0.08), radius, BUTTON_MARGIN))
	ui.set_stylebox("pressed", type, _shape(pressed, radius, BUTTON_MARGIN, true))
	ui.set_stylebox("hover_pressed", type, _shape(pressed, radius, BUTTON_MARGIN, true))
	ui.set_stylebox("disabled", type, _shape(CARD_DISABLED, radius, BUTTON_MARGIN))


## `outline`: the ink round the text, in pixels; 0 for none.
static func _label_variation(ui: Theme, variation: StringName, font_size: int, color: Color, outline: int,
		font: Font = null) -> void:
	ui.set_type_variation(variation, &"Label")
	ui.set_font_size("font_size", variation, font_size)
	ui.set_color("font_color", variation, color)
	ui.set_constant("outline_size", variation, outline * OUTLINE_PER_PX)
	if font != null:
		ui.set_font("font", variation, font)


## Lilita One for the meters' amounts, falling back to the engine's own font for the "∞" the
## dev cheats show, which Lilita One lacks, so it draws the same on every platform rather than
## from a system font. Only the meters fall back: a fallback's taller line metrics would space
## every other text wider.
static func _meter_font() -> FontVariation:
	var font := FontVariation.new()
	font.base_font = BODY_FONT
	var fallbacks: Array[Font] = [ThemeDB.fallback_font]
	font.fallbacks = fallbacks
	return font


## The comic shape: a flat fill, a 3 px ink border, round corners and a flat ink shadow
## offset 4 px down and right, with `margin` round its content. Sunk (pressed), the shape and
## its content move 2 px onto the shadow, which stays where it was: 2 px from the shape.
static func _shape(fill: Color, radius: int, margin: float = 12.0, sunk: bool = false) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = INK
	box.set_border_width_all(BORDER)
	box.set_corner_radius_all(radius)
	box.shadow_color = SHADOW
	box.shadow_size = 1
	box.shadow_offset = Vector2(4, 4)
	box.set_content_margin_all(margin)
	if sunk:
		box.shadow_offset = Vector2(2, 2)
		box.expand_margin_left = -2.0
		box.expand_margin_top = -2.0
		box.expand_margin_right = 2.0
		box.expand_margin_bottom = 2.0
		box.content_margin_left = margin + 2.0
		box.content_margin_top = margin + 2.0
		box.content_margin_right = margin - 2.0
		box.content_margin_bottom = margin - 2.0
	return box


## A plain rounded fill, for the scroll bar.
static func _flat(fill: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(4.0)
	return box
