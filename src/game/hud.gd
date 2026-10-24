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
## build panel alone reaches the screen's edges, with its content inside the safe area, and so
## does the army panel, which slides up in the same place: a producer's training (its unit
## cards and its queue) or the research lab's research.

signal build_pressed(type: String)
signal confirm_pressed
signal cancel_pressed
signal upgrade_pressed
signal close_pressed
signal reset_pressed
signal template_pressed
## Debug builds: a practice raid on the template base.
signal practice_pressed
## A training card: queue one `unit` at producer `id`.
signal train_pressed(id: int, unit: String)
## A queue entry: cancel the newest queued `unit` at producer `id`.
signal cancel_training_pressed(id: int, unit: String)
## A research card: research `unit`'s next level.
signal research_pressed(unit: String)

## What the army panel shows: nothing (closed or closing), a producer's training or the lab's
## research.
enum ArmyPage { NONE, TRAIN, RESEARCH }

const ERROR_TEXT := {
	BaseState.ERR_BLOCKED: "That spot is taken",
	BaseState.ERR_LIMIT: "You've built the maximum for your Command Center level",
	BaseState.ERR_CC_LEVEL: "Upgrade your Command Center first",
	BaseState.ERR_NO_BUILDER: "All drones are busy",
	BaseState.ERR_FUNDS: "Not enough resources",
	BaseState.ERR_BUSY: "Already under construction",
	BaseState.ERR_MAX_LEVEL: "Already at max level",
	BaseState.ERR_UNKNOWN_UNIT: "Unknown unit",
	BaseState.ERR_NOT_PRODUCER: "This building does not train that",
	BaseState.ERR_BAD_COUNT: "Bad count",
	BaseState.ERR_PRODUCER_LEVEL: "Needs a higher building level",
	BaseState.ERR_HOUSING: "Not enough room in the Hangars",
	BaseState.ERR_NOT_QUEUED: "Nothing like that is queued",
	BaseState.ERR_LAB_LEVEL: "Needs a higher Research Lab",
	BaseState.ERR_BAD_RAID: "That battle does not add up",
	BaseState.ERR_NOT_ENOUGH_UNITS: "Not enough units for that battle",
	BaseState.ERR_UNKNOWN_ABILITY: "Unknown ability",
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
## The info panel's note when an upgrade is refused, and a research card's lab level the lab
## does not have yet.
const WARNING := Color("ffb37a")
## The stripe along the top of a build card, by category: the category's MaterialKit role.
const CATEGORY_STRIPE := {
	"resources": MaterialKit.ENERGY,
	"army": MaterialKit.ARMY,
	"defense": MaterialKit.DEFENCE,
	"traps": MaterialKit.HAZARD,
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
const CARD_SIZE := Vector2(200, 176)
## The building's picture at the top of a card (ModelPreview), shown at this size.
const PREVIEW_SIZE := Vector2(84, 84)
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
## The band is white and the rest STRIPE_BASE grey, so the band is 25 % lighter; the stripes'
## shader tints it by the resource's colour over STRIPE_BASE, so the rest reads as the colour itself.
const STRIPE_TILE := 16
const STRIPE_BAND := 6
const STRIPE_BASE := 0.8
## Across the top third of the fill.
const GLOSS := Color(1, 1, 1, 0.25)
## The stripes' shader: their drift, the glint and the flash on a change (meter.gdshader).
const METER_SHADER: Shader = preload("res://src/game/meter.gdshader")
## Each meter glints this share of the glint's period after the one before it.
const GLINT_STAGGER := 1.0 / 3.0
## A meter flashes on a rise larger than this many seconds' (ticks') production.
const FLASH_RISE_TICKS := 1.5
## The seconds since the last refresh weighed against a rise are capped here: a stalled tick or
## two still never flashes, while a longer gap's catch-up (the app resumed) does.
const FLASH_MAX_SECONDS := 5
## The army meter's key among the meters: no resource id begins with "@".
const ARMY_METER := "@army"
## The build panel's height, never past a share of the screen's.
const MENU_HEIGHT := 300.0
const MENU_MAX_SHARE := 0.4
const MENU_OPEN_SECONDS := 0.18
const MENU_CLOSE_SECONDS := 0.14
## Pressing the selected tab again scrolls its strip back to the start over this long.
const STRIP_RETURN_SECONDS := 0.2
## A unit level with no train_cost, shared so a lookup builds none.
const _NO_COST := {}
## The info panel's Train button, beside Close.
const ACTION_SIZE := Vector2(112, 44)
## A unit card in the army panel, and its picture (ModelPreview) at the top.
const TRAIN_CARD_SIZE := Vector2(200, 140)
const PICTURE_SIZE := Vector2(48, 48)
## An entry of the queue strip under the training cards, and its glyph.
const QUEUE_ENTRY_SIZE := Vector2(180, 48)
const QUEUE_GLYPH_SIZE := Vector2(32, 32)
## A research card: a training card's with a line for the unit's level and one for the lab level
## its next level needs.
const RESEARCH_CARD_SIZE := Vector2(200, 164)

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
## Each resource's meter, and the army's under ARMY_METER, the fill that grows across it, and its
## amount.
var _meters: Dictionary[String, Control] = {}
var _meter_fills: Dictionary[String, Control] = {}
var _meter_labels: Dictionary[String, Label] = {}
## Each meter's stripes' material, and the amount it last showed, which a change flashes.
var _meter_shaders: Dictionary[String, ShaderMaterial] = {}
var _meter_amounts: Dictionary[String, int] = {}
## The state's time at the meters' last refresh, so a rise is weighed against the production of
## the seconds since.
var _meters_now: int = 0
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
## Each card's picture of its building, empty until ModelPreview has rendered it.
var _entry_preview: Dictionary[String, TextureRect] = {}
var _preview: ModelPreview
## Each card's picture, name and cost, dimmed while it cannot be built.
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
var _practice_button: Button
## The building selected at the last refresh, 0 for none.
var _selected_id: int = 0
## The info panel's Train or Research button, shown for a finished producer or research building.
var _action_button: Button
## The building types that train units (Catalog.units_of_producer is not empty).
var _producers: Dictionary[String, bool] = {}
## The army panel, outside the root like the build panel, and what it shows for which building.
var _army: PanelContainer
var _army_inset: MarginContainer
var _army_page: ArmyPage = ArmyPage.NONE
var _army_id: int = 0
var _army_tween: Tween
var _army_title: Label
var _army_close: Button
var _train_page: Control
var _train_scroll: ScrollContainer
## One card per unit type, in units.json order; the panel shows its producer's.
var _train_cards: Dictionary[String, ArmyCard] = {}
## The queue strip's entries, made as the queue first grows that long and reused after; the
## units they show, oldest first.
var _queue_strip: HBoxContainer
var _queue_entries: Array[ArmyCard] = []
var _queue_units: PackedStringArray = PackedStringArray()
var _queue_empty: Label
## What the head entry last showed: its status and its seconds left, so a tick that changes
## neither sets no text.
var _head_status: String = ""
var _head_seconds: int = -1
## The state whose `changed` rebuilds the army panel's content; a tick only counts down.
var _watched: BaseState
var _research_page: Control
var _research_scroll: ScrollContainer
## The research running and its time left, or that none is.
var _research_line: Label
## One card per unit type, in units.json order; the panel shows the unlocked ones.
var _research_cards: Dictionary[String, ArmyCard] = {}
## The research line's words before its time left, "" with no research running, and the seconds it
## last showed, so a tick sets its text only when they changed.
var _research_prefix: String = ""
var _research_seconds: int = -1


## A unit card or a queue entry: the button, what dims while it cannot be pressed, the picture
## (a card's) or the glyph (an entry's), the name, the cost (a label per resource, "Free" when it
## has none) and the time, and the lines under them.
class ArmyCard:
	var button: Button
	var heading: Control
	var picture: TextureRect
	var glyph: HudIcon
	var title: Label
	## A research card's "Level N"; null on a training card.
	var level: Label
	var cost_row: Control
	var costs: Dictionary[String, Label] = {}
	var free: Label
	var time: Label
	var info: Label


func setup(catalog: Catalog) -> void:
	_catalog = catalog
	_theme = _make_theme()
	for type: String in catalog.types():
		if not catalog.units_of_producer(type).is_empty():
			_producers[type] = true
	_build_menu()
	_build_army_panel()
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
	_watch(state)
	# The safe area can move without a resize: turning a phone over moves the notch to the
	# other side. Every refresh, the 1 s tick's included, checks it.
	_fit_safe_area()
	var elapsed := clampi(state.now - _meters_now, 1, FLASH_MAX_SECONDS)
	_meters_now = state.now
	for res: String in _catalog.resources:
		# A resource the base has no storage for yet (antimatter, early on) is hidden, unless
		# the cheats make every resource infinite.
		var capacity := state.capacity(res)
		_meters[res].visible = capacity > 0 or cheats
		var amount: int = state.resources[res]
		var fraction := clampf(float(amount) / capacity, 0.0, 1.0) if capacity > 0 else 0.0
		if cheats:
			fraction = 1.0
		_set_fill(res, fraction)
		# A drop (a purchase) or a rise past FLASH_RISE_TICKS ticks' production (a payout, an
		# offline catch-up) flashes the fill; the per-tick trickle does not. Under the cheats the
		# meter reads "∞" whatever it holds.
		if not cheats and _meter_amounts.has(res) and _flashes(res, amount - _meter_amounts[res], elapsed):
			_meter_shaders[res].set_shader_parameter(&"flash_time", Motion.clock())
		_meter_amounts[res] = amount
		_meter_labels[res].text = "∞" if cheats else "%s / %s" % [Format.short(amount), Format.short(capacity)]
	# The army's housing shows once a Hangar is built; the cheats leave it as it is.
	var housing := state.housing_capacity()
	_meters[ARMY_METER].visible = housing > 0
	if housing > 0:
		var used := state.housing_used()
		_set_fill(ARMY_METER, clampf(float(used) / housing, 0.0, 1.0))
		_meter_labels[ARMY_METER].text = "%s / %s" % [Format.short(used), Format.short(housing)]
	_drone_ring.set_counts(state.builders_free(), state.builders_total())

	var has_selection := selected_id != 0 and state.buildings.has(selected_id)
	_selected_id = selected_id if has_selection else 0
	# Placing, painting or selecting a building in the world closes the build panel.
	if placing or has_selection:
		_slide_menu(false)
	# The army panel belongs to the building it opened on: placing, a deselection or another
	# selection closes it.
	if _army_page != ArmyPage.NONE and (placing or _selected_id != _army_id):
		_close_army()
	_build_button.visible = not placing
	_place_bar.visible = placing
	_place_button.text = "Done" if painting else "Place"
	_place_button.disabled = not ghost_ok and not painting
	_info_panel.visible = not placing and has_selection and _army_page == ArmyPage.NONE
	if _menu_open:
		_refresh_entries(state)
	if _info_panel.visible:
		_refresh_info(state, state.buildings[selected_id])
	# Its content is rebuilt on a state change (_on_state_changed); the tick only counts down.
	if _army_page != ArmyPage.NONE:
		_tick_army(state)


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
	# The army panel likewise.
	for padding: MarginContainer in [_menu_inset, _army_inset]:
		padding.add_theme_constant_override("margin_left", roundi(inset.position.x))
		padding.add_theme_constant_override("margin_right", roundi(full.x - inset.end.x))
		padding.add_theme_constant_override("margin_bottom", roundi(full.y - inset.end.y))
	_menu.custom_minimum_size.y = minf(MENU_HEIGHT, full.y * MENU_MAX_SHARE)
	_army.custom_minimum_size.y = _menu.custom_minimum_size.y
	if _menu_open:
		# Open, or opening: on the bottom edge at its own height, which the panel grows upward
		# to. A slide under way was aimed at the old screen's bottom edge, so it stops here.
		_menu_tween.kill()
		_menu.offset_top = 0.0
		_menu.offset_bottom = 0.0
	if _army_page != ArmyPage.NONE:
		_army_tween.kill()
		_army.offset_top = 0.0
		_army.offset_bottom = 0.0


## The device's safe area in `viewport`'s visible rect, as _fit_safe_area fits it: the battle's HUD
## (BattleHud) fits itself to it too.
static func safe_area(viewport: Viewport) -> Rect2:
	var visible_rect := viewport.get_visible_rect()
	var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
	var safe := DisplayServer.get_display_safe_area().intersection(window)
	if not safe.has_area():
		return visible_rect
	var ui_scale := visible_rect.size / Vector2(window.size)
	return Rect2(Vector2(safe.position - window.position) * ui_scale, Vector2(safe.size) * ui_scale)


## DisplayServer reports the safe area in screen pixels; on desktop it is the screen's
## usable rect, so it is clipped to the window first. The canvas_items stretch maps the
## window onto the visible rect, so the scale between them is their size ratio. A window
## with no size (headless) gets the whole rect. It applies only a rect that differs from
## the last one it fitted, so an inset the harness applied stays until the device's changes.
func _fit_safe_area() -> void:
	var area := safe_area(get_viewport())
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


## A research's error: `busy` there is the lab's one research slot, not construction.
static func research_error_text(code: String) -> String:
	return "Research already running" if code == BaseState.ERR_BUSY else error_text(code)


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


## A card's picture of its building; null until it is rendered.
func entry_preview(type: String) -> Texture2D:
	return _entry_preview[type].texture


## Whether every card's picture has been rendered (in a headless run, attempted: nothing draws).
func previews_done() -> bool:
	return _preview.is_done()


## The horizontal strip the cards scroll in.
func entry_strip() -> ScrollContainer:
	return _entry_scroll


## The top bar's meter for one resource; hidden while the base cannot store it.
func resource_panel(res: String) -> Control:
	return _meters[res]


## The top bar's army meter; hidden while the base houses no army.
func army_meter() -> Control:
	return _meters[ARMY_METER]


## The army meter's text: housing used / capacity.
func army_meter_text() -> String:
	return _meter_labels[ARMY_METER].text


## The army meter's fill; its parent is the track it grows across.
func army_fill() -> Control:
	return _meter_fills[ARMY_METER]


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


## The debug Practice raid button; null in a release build.
func practice_button() -> Button:
	return _practice_button


## The debug Template base button; null in a release build.
func template_button() -> Button:
	return _template_button


## The info panel's Train or Research button; hidden unless a finished producer or research
## building is selected.
func action_button() -> Button:
	return _action_button


## The army panel itself; hidden while closed.
func army_panel() -> Control:
	return _army


## Whether the army panel shows a producer's training (open or opening).
func is_training_open() -> bool:
	return _army_page == ArmyPage.TRAIN


## Whether the army panel shows the research (open or opening).
func is_research_open() -> bool:
	return _army_page == ArmyPage.RESEARCH


func army_close_button() -> Button:
	return _army_close


## The army panel's title: the building's name and level.
func army_title() -> String:
	return _army_title.text


## A unit's training card.
func train_card(unit: String) -> Button:
	return _train_cards[unit].button


## A training card's picture of its unit, null until rendered (always, headless).
func train_card_picture(unit: String) -> Texture2D:
	return _train_cards[unit].picture.texture


## The HUD's theme, for the battle's HUD (BattleHud), which takes its look.
func ui_theme() -> Theme:
	return _theme


## The cards' pictures, shared with the battle's deploy bar (BattleHud).
func preview() -> ModelPreview:
	return _preview


## A training card's last line: the housing and the count housed, or why it is locked.
func train_card_info(unit: String) -> String:
	return _train_cards[unit].info.text


## The units the queue strip shows, oldest first.
func queue_shown() -> PackedStringArray:
	return _queue_units


## The queue strip's entry `index` (0 is the head); only the first queue_shown().size() show.
func queue_entry(index: int) -> Button:
	return _queue_entries[index].button


## The head entry's state: the time left, "Waiting for room" or "Paused"; "" with no queue.
func queue_head_status() -> String:
	return _queue_entries[0].info.text if not _queue_units.is_empty() else ""


## The toast's text while it shows; "" once it has faded.
func toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


## A unit's research card; shown while the unit is unlocked.
func research_card(unit: String) -> Button:
	return _research_cards[unit].button


## A research card's level line and last line ("Needs Lab L", "Researching" or "Max level").
func research_card_lines(unit: String) -> PackedStringArray:
	return PackedStringArray([_research_cards[unit].level.text, _research_cards[unit].info.text])


## The research panel's progress line.
func research_line() -> String:
	return _research_line.text


# --- The build panel -------------------------------------------------------------

## Build toggles the panel. Opening it closes a selected building's info panel, or the army
## panel, first, as the info panel's Close would: the two never show together.
func _on_build_button() -> void:
	if not _menu_open and (_info_panel.visible or _army_page != ArmyPage.NONE):
		close_pressed.emit()
	_slide_menu(not _menu_open)


func _on_card_pressed(type: String) -> void:
	_slide_menu(false)
	build_pressed.emit(type)


## Slides the panel up from below the screen's bottom edge, or back down and out of the
## way (_slide).
func _slide_menu(open: bool) -> void:
	if open == _menu_open:
		return
	_menu_open = open
	if open and _state != null:
		_refresh_entries(_state)
	# The cards' pictures render while the panel is open, the selected tab's first.
	if open:
		_preview.prioritize(_tab_types(_tab))
	_run_preview()
	_menu_tween = _slide(_menu, open, _menu_tween)


## The pictures render while a panel that shows them is open: the build panel or the army panel.
func _run_preview() -> void:
	_preview.run(_menu_open or _army_page != ArmyPage.NONE)


## Slides a bottom panel up from below the screen's bottom edge, or back down and out of the
## way: hidden once down, so it blocks nothing. The new slide replaces `under_way`.
func _slide(panel: Control, open: bool, under_way: Tween) -> Tween:
	if under_way != null:
		under_way.kill()
	var bottom := get_viewport().get_visible_rect().size.y
	if open and not panel.visible:
		# On the bottom edge at its own height, then moved down out of sight.
		panel.offset_top = 0.0
		panel.offset_bottom = 0.0
		panel.position.y = bottom
		panel.show()
	var tween := create_tween()
	# The panel's size catches up with its content only at the next layout pass; its minimum size
	# already has (the army panel's pages differ in height).
	var height := maxf(panel.size.y, panel.get_combined_minimum_size().y)
	var target := bottom - height if open else bottom
	tween.tween_property(panel, "position:y", target, MENU_OPEN_SECONDS if open else MENU_CLOSE_SECONDS) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
	if open:
		# Up, it rests on its anchors, on the bottom edge at its own height, whatever its content
		# has done to that height since.
		tween.tween_callback(func() -> void:
			panel.offset_top = 0.0
			panel.offset_bottom = 0.0)
	else:
		tween.tween_callback(panel.hide)
	return tween


# --- The army panel --------------------------------------------------------------

## The info panel's Train or Research: the army panel slides up in its place, on the selected
## building.
func _on_action_pressed() -> void:
	if _selected_id == 0 or _state == null:
		return
	_open_army(_page_for(_state.buildings[_selected_id].type))


## The army panel's page for a building type: a producer's training, the research, or none.
func _page_for(type: String) -> ArmyPage:
	if _producers.has(type):
		return ArmyPage.TRAIN
	return ArmyPage.RESEARCH if type == _catalog.research_type else ArmyPage.NONE


func _open_army(page: ArmyPage) -> void:
	if page == ArmyPage.NONE:
		return
	_army_page = page
	_army_id = _selected_id
	_train_page.visible = page == ArmyPage.TRAIN
	_research_page.visible = page == ArmyPage.RESEARCH
	_info_panel.visible = false
	_train_scroll.scroll_horizontal = 0
	_research_scroll.scroll_horizontal = 0
	_refresh_army(_state)
	_run_preview()
	_army_tween = _slide(_army, true, _army_tween)


## Slides the army panel down. The selection stays as it is: refresh() shows its info panel.
func _close_army() -> void:
	if _army_page == ArmyPage.NONE:
		return
	_army_page = ArmyPage.NONE
	_run_preview()
	_army_tween = _slide(_army, false, _army_tween)


## The panel's close button: back to the building's info panel, still selected.
func _on_army_close() -> void:
	_close_army()
	if _state != null and _state.buildings.has(_selected_id):
		_info_panel.visible = true
		_refresh_info(_state, _state.buildings[_selected_id])


## Rebuilds the army panel's content on `state.changed`, which the HUD connects to itself from
## the state it is given (main.gd's handler, connected first, has refreshed by then).
func _watch(state: BaseState) -> void:
	if state == _watched:
		return
	if _watched != null and _watched.changed.is_connected(_on_state_changed):
		_watched.changed.disconnect(_on_state_changed)
	_watched = state
	state.changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if _army_page != ArmyPage.NONE:
		_refresh_army(_watched)


## The one-second tick while the panel is open: only the countdown. It calls no query that
## copies (queue_of does) and sets text only where the shown value changed.
func _tick_army(state: BaseState) -> void:
	if _army_page == ArmyPage.TRAIN:
		_refresh_head(state)
	else:
		_tick_research(state)


## Everything the army panel shows, on opening it and on each state change.
func _refresh_army(state: BaseState) -> void:
	var building: BuildingState = state.buildings[_army_id]
	_army_title.text = "%s   Lv %d" % [_catalog.display_name(building.type), building.level]
	if _army_page == ArmyPage.TRAIN:
		_refresh_training(state, building)
	else:
		_refresh_research(state)
	_set_pictures(state)


## The shown cards' pictures, each its unit at its researched level's tier (UnitModels.tier_of);
## those not rendered yet are asked of the preview, and come in _on_preview_rendered.
func _set_pictures(state: BaseState) -> void:
	var cards := _train_cards if _army_page == ArmyPage.TRAIN else _research_cards
	var missing := PackedStringArray()
	for unit: String in cards:
		var card := cards[unit]
		if not card.button.visible:
			continue
		var key := ModelPreview.unit_key(unit, UnitModels.tier_of(_catalog, unit, state.unit_level(unit)))
		card.picture.texture = _preview.texture_of(key)
		if card.picture.texture == null:
			missing.append(key)
	if not missing.is_empty():
		_preview.request(missing)
		_run_preview()


## The producer's unit cards, then its queue. A card is locked, disabled with its picture, name
## and cost dimmed, until the producer's finished level trains the unit.
func _refresh_training(state: BaseState, building: BuildingState) -> void:
	for unit: String in _train_cards:
		var card := _train_cards[unit]
		card.button.visible = _catalog.unit_producer(unit) == building.type
		if not card.button.visible:
			continue
		var stats := _catalog.unit_level_stats(unit, state.unit_level(unit))
		_set_card_cost(card, stats.get("train_cost", _NO_COST), _catalog.unit_train_seconds(unit))
		var needed := _catalog.unit_producer_level(unit)
		var locked := building.level < needed
		card.button.disabled = locked
		card.heading.modulate.a = DISABLED_ALPHA if locked else 1.0
		card.info.theme_type_variation = &"CardReason" if locked else &"CardCount"
		if locked:
			card.info.text = "Needs %s %d" % [_catalog.display_name(building.type), needed]
		else:
			card.info.text = "Housing %d   Housed %d" % [_catalog.unit_housing(unit), state.army_count(unit)]
	_refresh_queue(state)


## The queue strip: an entry per queued unit, oldest first, the head's with its state. Entries
## are made only as the queue first grows that long; after that a rebuild only sets text.
func _refresh_queue(state: BaseState) -> void:
	# A copy, built per call: taken here, on a state change, and kept for the ticks between.
	_queue_units = state.queue_of(_army_id)
	while _queue_entries.size() < _queue_units.size():
		_queue_entries.append(_build_queue_entry(_queue_entries.size()))
	for i: int in _queue_entries.size():
		var entry := _queue_entries[i]
		entry.button.visible = i < _queue_units.size()
		if not entry.button.visible:
			continue
		var unit := _queue_units[i]
		entry.glyph.show_icon(_catalog.unit_crew(unit), _catalog.unit_class(unit) == "air")
		entry.title.text = _catalog.unit_name(unit)
		entry.info.visible = i == 0
	_head_seconds = -1
	_refresh_head(state)
	_queue_empty.visible = _queue_units.is_empty()


## The head entry's state: its time left, "Waiting for room" or "Paused". The queries it reads
## build nothing; the text is set only when the status or the seconds changed.
func _refresh_head(state: BaseState) -> void:
	if _queue_units.is_empty():
		return
	var status := state.training_status(_army_id)
	var seconds := state.training_seconds_left(_army_id)
	if status == _head_status and seconds == _head_seconds:
		return
	_head_status = status
	_head_seconds = seconds
	var head := _queue_entries[0].info
	if status == BaseState.TRAINING_WAITING:
		head.text = "Waiting for room"
	elif status == BaseState.TRAINING_PAUSED:
		head.text = "Paused"
	else:
		head.text = "%s left" % Format.duration(seconds)


## The research running, then a card per unlocked unit: its level and its next level's cost, time
## and the lab level it needs, or "Max level". A card whose next level the lab cannot research
## yet, or at the top, is dimmed but still takes a tap, which toasts why.
func _refresh_research(state: BaseState) -> void:
	var running := state.research_unit
	_research_prefix = ""
	if running == "":
		_research_line.text = "No research running"
	else:
		_research_prefix = "Researching %s to Lv %d: " % [_catalog.unit_name(running), state.unit_level(running) + 1]
		_research_seconds = -1
		_tick_research(state)
	for unit: String in _research_cards:
		var card := _research_cards[unit]
		card.button.visible = state.is_unit_unlocked(unit)
		if not card.button.visible:
			continue
		var level := state.unit_level(unit)
		card.level.text = "Level %d" % level
		var top := level >= _catalog.unit_max_level(unit)
		card.cost_row.visible = not top
		var dim := top
		if top:
			card.info.text = "Max level"
			card.info.theme_type_variation = &"CardCount"
		else:
			var stats := _catalog.unit_level_stats(unit, level + 1)
			_set_card_cost(card, stats.get("research_cost", _NO_COST), int(stats.get("research_seconds", 0)))
			var lab := int(stats.get("requires_lab", 1))
			dim = state.lab_level() < lab
			card.info.text = "Researching" if unit == running else "Needs Lab %d" % lab
			card.info.theme_type_variation = &"CardWarning" if dim else &"CardCount"
		card.heading.modulate.a = DISABLED_ALPHA if dim else 1.0


## The research line's time left; text only when the seconds changed.
func _tick_research(state: BaseState) -> void:
	if _research_prefix == "":
		return
	var seconds := state.research_seconds_left()
	if seconds == _research_seconds:
		return
	_research_seconds = seconds
	_research_line.text = "%s%s left" % [_research_prefix, Format.duration(seconds)]


## A card's cost, each amount in its resource's colour, or "Free"; and its time.
func _set_card_cost(card: ArmyCard, cost: Dictionary, seconds: int) -> void:
	var free := true
	for res: String in _catalog.resources:
		var amount := int(cost.get(res, 0))
		var label := card.costs[res]
		label.visible = amount > 0
		if amount > 0:
			label.text = Format.amount(amount)
			free = false
	card.free.visible = free
	card.time.text = Format.duration(seconds)


func _on_train_card(unit: String) -> void:
	train_pressed.emit(_army_id, unit)


func _on_research_card(unit: String) -> void:
	research_pressed.emit(unit)


## An entry cancels the newest queued unit of its type, not necessarily itself.
func _on_queue_entry(index: int) -> void:
	if index < _queue_units.size():
		cancel_training_pressed.emit(_army_id, _queue_units[index])


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
		_preview.prioritize(_tab_types(category))


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


## The menu's types in a category, in menu_order order.
func _tab_types(category: String) -> PackedStringArray:
	var types := PackedStringArray()
	for type: String in _catalog.menu_order:
		if _catalog.category_of(type) == category:
			types.append(type)
	return types


## A picture rendered: a build card's, or a unit's at a tier, which the army panel's cards take if
## it is open.
func _on_preview_rendered(key: String, texture: Texture2D) -> void:
	if _entry_preview.has(key):
		_entry_preview[key].texture = texture
	elif _army_page != ArmyPage.NONE and _state != null:
		_set_pictures(_state)


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
	if type == _catalog.housing_type:
		lines.append("Army housed %s / %s" % [Format.amount(state.housing_used()), Format.amount(state.housing_capacity())])
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
	# A finished producer trains; a finished research building researches.
	var page := _page_for(type)
	_action_button.visible = page != ArmyPage.NONE and building.level >= 1
	_action_button.text = "Research" if page == ArmyPage.RESEARCH else "Train"

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

## The top-left row: a meter per resource, the army's, then the drone ring.
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
	for i: int in _catalog.resources.size():
		var res := _catalog.resources[i]
		_build_meter(bar, res, res, _resource_color(res), stripe, fmod(i * GLINT_STAGGER, 1.0))
	_build_meter(bar, ARMY_METER, "army", MaterialKit.ARMY, stripe,
		fmod(_catalog.resources.size() * GLINT_STAGGER, 1.0))
	_drone_ring = DroneRing.new()
	bar.add_child(_drone_ring)


## One meter, under `key` (a resource's id, or ARMY_METER): a trough that the fill, textured with
## `stripe` and tinted `color`, grows across by amount over storage, the amount on it, and the
## HudIcon `icon_kind` over its left end. The stripes drift and glint (meter.gdshader), the glint
## at `phase` of its period. The meter stops a touch on it, as any opaque part does, so it never
## selects or drags what lies under it; its parts take none.
func _build_meter(parent: Control, key: String, icon_kind: String, color: Color, stripe: Texture2D,
		phase: float) -> void:
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
	var shader := ShaderMaterial.new()
	shader.shader = METER_SHADER
	shader.set_shader_parameter(&"tint", Color(color.r / STRIPE_BASE, color.g / STRIPE_BASE, color.b / STRIPE_BASE))
	shader.set_shader_parameter(&"phase", phase)
	shader.set_shader_parameter(&"track_height", METER_TRACK.y)
	stripes.material = shader
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
	icon.kind = icon_kind
	icon.color = color
	icon.position = Vector2(0, (METER_SIZE.y - METER_ICON.y) / 2.0)
	icon.size = METER_ICON
	meter.add_child(icon)
	_meters[key] = meter
	_meter_fills[key] = fill
	_meter_labels[key] = label
	_meter_shaders[key] = shader


## Sizes a meter's fill to `fraction` of its track, to the pixel; untouched when that is its width.
func _set_fill(key: String, fraction: float) -> void:
	var width := roundf(METER_TRACK.x * fraction)
	if _meter_fills[key].size.x != width:
		_meter_fills[key].size = Vector2(width, METER_TRACK.y)
		_meter_shaders[key].set_shader_parameter(&"fill_width", width)


## Whether a change of `change` in a resource's amount over `elapsed` seconds flashes its meter:
## any drop, or a rise larger than FLASH_RISE_TICKS times the production of those seconds, rounded
## up to a whole unit, since a slow trickle still rises a whole unit at a time. Only a rise sums
## the production.
func _flashes(res: String, change: int, elapsed: int) -> bool:
	if change <= 0:
		return change < 0
	return change > ceili(FLASH_RISE_TICKS * _state.production_per_hour(res) * elapsed / 3600.0)


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
	_preview = ModelPreview.new()
	_preview.setup(_catalog, _catalog.menu_order)
	_preview.rendered.connect(_on_preview_rendered)
	add_child(_preview)
	# The Build button stays over the open panel at the safe area's corner; nothing goes under it.
	var clear := Control.new()
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear.custom_minimum_size = Vector2(BUILD_SIZE.x + MARGIN, 0)
	row.add_child(clear)
	_select_tab(_catalog.categories[0])


## A card: the category's stripe along its top, then the building's picture (ModelPreview's,
## empty until it is rendered), and three lines: the name, the level 1 cost (each amount in its
## resource's colour), and the status line `_refresh_entries` fills.
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
	var preview := TextureRect.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.custom_minimum_size = PREVIEW_SIZE
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(preview)
	_entry_preview[type] = preview
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


## The army panel: like the build panel, the screen's full width at its bottom edge, its content
## padded into the safe area and a column kept clear for the Build button. A header of the
## building's name and level and a close button, over one of two pages: the training page, a
## strip of unit cards and, under it, the queue strip; or the research page, the research
## running over a strip of unit cards. Built hidden; _open_army shows a page.
func _build_army_panel() -> void:
	_army = PanelContainer.new()
	_army.theme = _theme
	_army.theme_type_variation = &"MenuPanel"
	_army.mouse_filter = Control.MOUSE_FILTER_STOP
	_army.visible = false
	add_child(_army)
	_army.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_army.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_army.offset_left = 0.0
	_army.offset_right = 0.0
	_army.offset_top = 0.0
	_army.offset_bottom = 0.0
	_army_inset = MarginContainer.new()
	_army_inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_army.add_child(_army_inset)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	_army_inset.add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 10)
	column.add_child(header)
	_army_title = Label.new()
	_army_title.theme_type_variation = &"InfoTitle"
	_army_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_army_title)
	_army_close = _button("X", CLOSE_SIZE, &"CloseButton")
	_army_close.pressed.connect(_on_army_close)
	header.add_child(_army_close)

	var body := HBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	column.add_child(body)
	var pages := VBoxContainer.new()
	pages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pages.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(pages)
	# The Build button stays over the open panel at the safe area's corner; nothing goes under it.
	var clear := Control.new()
	clear.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clear.custom_minimum_size = Vector2(BUILD_SIZE.x + MARGIN, 0)
	body.add_child(clear)

	_train_page = VBoxContainer.new()
	_train_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_train_page.add_theme_constant_override("separation", 6)
	pages.add_child(_train_page)
	var cards := _strip(_train_page, TRAIN_CARD_SIZE.y + 18)
	_train_scroll = cards.get_parent().get_parent() as ScrollContainer
	for unit: String in _catalog.unit_types():
		var card := _build_army_card(unit, TRAIN_CARD_SIZE)
		card.button.pressed.connect(_on_train_card.bind(unit))
		cards.add_child(card.button)
		_train_cards[unit] = card
	_queue_strip = _strip(_train_page, QUEUE_ENTRY_SIZE.y + 12)
	_queue_strip.add_theme_constant_override("separation", 8)
	_queue_empty = _card_label(_queue_strip, "Nothing in training", &"CardCount")
	_queue_empty.custom_minimum_size.y = QUEUE_ENTRY_SIZE.y
	_queue_empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

	_research_page = VBoxContainer.new()
	_research_page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_research_page.add_theme_constant_override("separation", 6)
	pages.add_child(_research_page)
	_research_line = Label.new()
	_research_line.theme_type_variation = &"InfoDetail"
	_research_page.add_child(_research_line)
	var research_cards := _strip(_research_page, RESEARCH_CARD_SIZE.y + 18)
	_research_scroll = research_cards.get_parent().get_parent() as ScrollContainer
	for unit: String in _catalog.unit_types():
		var card := _build_army_card(unit, RESEARCH_CARD_SIZE)
		# "Level N" under the name.
		card.level = _card_label(card.heading, "", &"CardCost")
		card.heading.move_child(card.level, card.title.get_index() + 1)
		card.button.pressed.connect(_on_research_card.bind(unit))
		research_cards.add_child(card.button)
		_research_cards[unit] = card


## A horizontal ScrollContainer under `parent`, `height` high (its cards' with room for their
## shadows and the scroll bar), holding the row it returns.
func _strip(parent: Control, height: float) -> HBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, height)
	parent.add_child(scroll)
	# Room for the cards' shadows, which fall outside them, at the strip's end and bottom.
	var room := MarginContainer.new()
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	room.add_theme_constant_override("margin_right", 6)
	room.add_theme_constant_override("margin_bottom", 6)
	scroll.add_child(room)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 12)
	room.add_child(row)
	return row


## A unit card, `card_size`: the army's stripe along its top, the unit's picture (set by
## _set_pictures, empty until the preview has rendered it), its name and a
## row of its cost and time, then the line under them that the refresh fills. PASS, like a build
## card, so a drag on it scrolls the strip; its content takes no touch.
func _build_army_card(unit: String, card_size: Vector2) -> ArmyCard:
	var card := ArmyCard.new()
	card.button = _button("", card_size)
	card.button.mouse_filter = Control.MOUSE_FILTER_PASS
	var stripe := Panel.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.theme_type_variation = &"CardStripe"
	stripe.self_modulate = MaterialKit.ARMY
	card.button.add_child(stripe)
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_left = BORDER
	stripe.offset_right = -BORDER
	stripe.offset_top = BORDER
	stripe.offset_bottom = BORDER + STRIPE_HEIGHT
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	card.button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 10
	content.offset_top = BORDER + STRIPE_HEIGHT + 2
	content.offset_right = -10
	content.offset_bottom = -BORDER - 2
	var heading := VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.add_theme_constant_override("separation", 0)
	content.add_child(heading)
	card.heading = heading
	card.picture = TextureRect.new()
	card.picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.picture.custom_minimum_size = PICTURE_SIZE
	card.picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	heading.add_child(card.picture)
	card.title = _card_label(heading, _catalog.unit_name(unit), &"CardName")
	card.title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 10)
	heading.add_child(cost_row)
	card.cost_row = cost_row
	for res: String in _catalog.resources:
		var amount := _card_label(cost_row, "", &"CardCost")
		amount.add_theme_color_override("font_color", _resource_color(res))
		card.costs[res] = amount
	card.free = _card_label(cost_row, "Free", &"CardCost")
	card.time = _card_label(cost_row, "", &"CardCount")
	card.info = _card_label(content, "", &"CardCount")
	card.info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return card


## A queue strip entry: a small glyph beside the unit's name and, on the head, its state. A press
## cancels one of its unit (_on_queue_entry). PASS, so a drag on it scrolls the strip.
func _build_queue_entry(index: int) -> ArmyCard:
	var entry := ArmyCard.new()
	entry.button = _button("", QUEUE_ENTRY_SIZE)
	entry.button.mouse_filter = Control.MOUSE_FILTER_PASS
	entry.button.pressed.connect(_on_queue_entry.bind(index))
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	entry.button.add_child(row)
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_top = BORDER
	row.offset_right = -10
	row.offset_bottom = -BORDER
	entry.glyph = _glyph(row, "", QUEUE_GLYPH_SIZE)
	entry.glyph.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.alignment = BoxContainer.ALIGNMENT_CENTER
	lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lines.add_theme_constant_override("separation", -2)
	row.add_child(lines)
	entry.title = Label.new()
	entry.title.theme_type_variation = &"QueueName"
	entry.title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lines.add_child(entry.title)
	entry.info = Label.new()
	entry.info.theme_type_variation = &"CardReason"
	entry.info.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	lines.add_child(entry.info)
	_queue_strip.add_child(entry.button)
	return entry


## A unit's glyph (HudIcon, by its crew, winged for an air unit) in the army accent, `glyph_size`,
## centred across `parent`; `unit` "" leaves it blank until show_icon.
func _glyph(parent: Control, unit: String, glyph_size: Vector2) -> HudIcon:
	var glyph := HudIcon.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = glyph_size
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.color = MaterialKit.ARMY
	if unit != "":
		glyph.show_icon(_catalog.unit_crew(unit), _catalog.unit_class(unit) == "air")
	parent.add_child(glyph)
	return glyph


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
	_action_button = _button("Train", ACTION_SIZE, &"ConfirmButton")
	_action_button.pressed.connect(_on_action_pressed)
	header.add_child(_action_button)
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


## Debug builds only: start over without digging through user:// for the save file, swap the
## base for the template, every type at its top level (TemplateBase), or raid the template with
## the army in the Hangars (Practice raid, main.gd). On a row of its own under the top bar,
## right-aligned, so a long top bar never runs under it.
func _build_debug_buttons() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 16)
	_top.add_child(row)
	var practice := _button("Practice raid", Vector2(150, 48), &"DebugButton")
	practice.pressed.connect(func() -> void: practice_pressed.emit())
	row.add_child(practice)
	_practice_button = practice
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
	_label_variation(ui, &"QueueName", 16, TEXT, 0)
	_label_variation(ui, &"CardWarning", 15, WARNING, 0)
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
