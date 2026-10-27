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
## A making card: queue one `ability` at Foundry `id`.
signal make_pressed(id: int, ability: String)
## A queue entry on the making page: cancel the newest queued `ability` at Foundry `id`.
signal cancel_making_pressed(id: int, ability: String)
## An ability's research card: research `ability`'s next level.
signal research_ability_pressed(ability: String)
## The Expedition button: open the sector map.
signal expedition_pressed

## What the army panel shows: nothing (closed or closing), a producer's training, the lab's
## research, or the Foundry's making.
enum ArmyPage { NONE, TRAIN, RESEARCH, MAKE }

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
	BaseState.ERR_SCAN_COOLDOWN: "The scanner is still cooling down",
	BaseState.ERR_BAD_EXPEDITION: "That expedition does not add up",
	BaseState.ERR_NOT_ENOUGH_ABILITIES: "Not enough abilities for that battle",
	BaseState.ERR_NOT_FOUNDRY: "This building does not make that",
	BaseState.ERR_FOUNDRY_LEVEL: "Needs a higher Nanite Foundry",
	BaseState.ERR_STOCK_ROOM: "The Foundry's stock is full",
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
## The selected and the safe: the selected tab and card, Train, Done, Scan, Keep fighting.
const ACCENT := Color("58e8ff")
## Commit and spend: Build, Place, Upgrade, Attack. Raid and battle take MaterialKit.ARMY's orange.
const GOLD := Color("ffc13b")
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
## A pressed button or card: its fill this much lighter, the shape and its content sunk this far
## onto its shadow.
const PRESSED_LIGHTEN := 0.15
const PRESSED_SINK := 4.0
## A panel's inner edge: a line this light just inside its ink border.
const EDGE_LIGHT := Color("f4f2ff", 0.12)
## The bottom panels' top band, a shade lighter than the rest, down to the gap under the tabs.
const MENU_BAND := 74.0
const MENU_BAND_LIGHTEN := 0.06
const TAB_SIZE := Vector2(160, 56)
const CLOSE_SIZE := Vector2(56, 56)
const CARD_SIZE := Vector2(200, 200)
## The building's picture at the top of a card (ModelPreview), shown at this size on a round plinth
## of the category's colour at PLINTH_ALPHA over the card, PLINTH across, with a thin ink ring.
const PREVIEW_SIZE := Vector2(112, 112)
const PLINTH := 120.0
const PLINTH_ALPHA := 0.22
const PLINTH_RING := 2.0
## The category stripe along a card's top, inside its border.
const STRIPE_HEIGHT := 6
## Where a card's lines (the name, the cost row and the last line) start, from its top.
const CARD_LINES_TOP := 127.0
## A cost row's icons, each on a coin of its resource's own colour (darkened to the coin's value
## cap), so the colour says which resource it is; and the clock before a card's build time.
const COST_ICON := Vector2(22, 22)
const CLOCK_SIZE := 16.0
## A card's chips (its count, a locked card's Command Center level): an ink ring this wide round
## the text with this much room either side.
const CHIP_RING := 2.0
const CHIP_PAD := Vector2(7, 2)
## The padlock on a locked card's chip.
const LOCK_ICON := 18.0
## A locked card's name.
const LOCKED_NAME_ALPHA := 0.7
## A locked card's picture (locked.gdshader).
const LOCKED_SHADER: Shader = preload("res://src/game/locked.gdshader")
const BUILD_SIZE := Vector2(136, 72)
## The Expedition button, bottom left, and the badge of open fields on its corner.
const EXPEDITION_SIZE := Vector2(184, 72)
const BADGE_SIZE := Vector2(30, 30)
## A meter: a pill-shaped trough (its radius half its height) with the resource's coin over its
## left end, the coin's centre on the trough's left edge, so it overlaps the trough by half.
const METER_SIZE := Vector2(240, 44)
const METER_COIN := 48.0
const METER_TROUGH_LEFT := METER_COIN / 2.0
## The amount ends this far in from the trough's right end.
const METER_TEXT_RIGHT := 12.0
## What the fill grows across: the trough inside its border.
const METER_TRACK := Vector2(METER_SIZE.x - METER_TROUGH_LEFT - 2 * BORDER, METER_SIZE.y - 2 * BORDER)
## The fill is the resource's colour at this share of its value, so it stays a colour under the
## stripes and the digits read on it.
const METER_VALUE := 0.85
## The meters sit on one strip, the panel's fill at this alpha, so the top bar reads as one
## instrument.
const STRIP_ALPHA := 0.6
const STRIP_RADIUS := 24
const STRIP_PADDING := 8
## The fill's texture: a tile this many pixels square crossed by a 45-degree band this wide.
## The band is white and the rest STRIPE_BASE grey, so the band is 12 % lighter; the stripes'
## shader tints it by the fill's colour over STRIPE_BASE, so the rest reads as the colour itself.
const STRIPE_TILE := 16
const STRIPE_BAND := 6
const STRIPE_BASE := 1.0 / 1.12
## Across the top third of the training header's housing bar.
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
## The build panel's height, never past a share of the screen's.
const MENU_HEIGHT := 324.0
const MENU_MAX_SHARE := 0.45
const MENU_OPEN_SECONDS := 0.18
const MENU_CLOSE_SECONDS := 0.14
## Pressing the selected tab again scrolls its strip back to the start over this long.
const STRIP_RETURN_SECONDS := 0.2
## Each ability effect's colour (HudIcon kinds "swarm", "emp", "strike"): its glyph's, and its
## coin's, which HudIcon holds to its coin value.
const ABILITY_COLORS := {
	"swarm": MaterialKit.NANITE_GREEN,
	"emp": MaterialKit.ARC_BLUE,
	"strike": MaterialKit.DEFENCE,
}
## A unit level with no train_cost, shared so a lookup builds none.
const _NO_COST := {}
## The info panel's Train button, and its Close beside it.
const ACTION_SIZE := Vector2(112, 56)
const INFO_CLOSE_SIZE := Vector2(96, 56)
## A unit card in the army panel, and its picture (ModelPreview) at the top.
const TRAIN_CARD_SIZE := Vector2(200, 140)
const PICTURE_SIZE := Vector2(48, 48)
## An entry of the queue strip under the training cards, and its glyph.
const QUEUE_ENTRY_SIZE := Vector2(180, 48)
const QUEUE_GLYPH_SIZE := Vector2(32, 32)
## A research card: a training card's with a line for the unit's level and one for the lab level
## its next level needs.
const RESEARCH_CARD_SIZE := Vector2(200, 164)
## The training header's housing line: the army's figure in front of it and the bar at its end.
const HOUSING_ICON := Vector2(20, 20)
const HOUSING_BAR_SIZE := Vector2(120, 14)
## The training header's and a producer's info panel's line while the base has no Hangar.
const NO_HANGAR := "No Hangar: build one to house units"
## The bar's fill while any unit is housed, however few, in pixels.
const HOUSING_MIN_FILL := 2.0

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
## Each meter's stripes' material, and the amount it last showed, which a change flashes.
var _meter_shaders: Dictionary[String, ShaderMaterial] = {}
## Whether each meter shows its full state (its amount at its cap).
var _meter_full: Dictionary[String, bool] = {}
var _meter_amounts: Dictionary[String, int] = {}
## The capacity each meter's text last showed (-1 before the first), so a refresh sets the text
## only when its amount or its capacity changed.
var _meter_capacities: Dictionary[String, int] = {}
## The state's time at the meters' last refresh, so a rise is weighed against the production of
## the seconds since.
var _meters_now: int = 0
## What the buildings add up to, as the state and its buildings_revision were when they were
## read: kept while neither moves, so a refresh with no building changed reads none of them again.
## The rates are read only when a meter rises, and then once (_rates_read).
var _counted: BaseState = null
var _counted_revision: int = -1
var _capacities: Dictionary[String, int] = {}
var _drones_total: int = 0
var _drones_busy: int = 0
var _rates: Dictionary[String, int] = {}
var _rates_read: bool = false
## What the info panel's text was built from: the building, its level, its target, its seconds
## left, the state and its revision, the army's housing and the stock; unchanged, the text stays.
var _info_key: Array = []
var _drone_ring: DroneRing
var _build_button: Button
var _expedition_button: Button
var _expedition_badge: Control
var _expedition_count: Label
## The open fields the badge last showed, -1 before the first refresh.
var _open_fields: int = -1
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
## The pictures render in the base's idle frames too (prerender), so a panel finds them made.
var _prerender: bool = false
## Each card's parts that a refresh sets.
var _cards: Dictionary[String, BuildCard] = {}
## A locked card's picture's material, shared by every locked card.
var _locked_material: ShaderMaterial
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
## The training page's housing line under the title: its text, and its bar, whose fill grows
## across the track by housing used over capacity.
var _housing_row: HBoxContainer
var _housing_label: Label
var _housing_bar: Control
var _housing_fill: Control
var _train_page: Control
var _train_scroll: ScrollContainer
## The making page's cards, in the training page's place over the same queue strip.
var _make_scroll: ScrollContainer
var _make_cards: Dictionary[String, ArmyCard] = {}
## The research page's ability cards, after the units'.
var _research_ability_cards: Dictionary[String, ArmyCard] = {}
## One card per unit type, in units.json order; the panel shows its producer's.
var _train_cards: Dictionary[String, ArmyCard] = {}
## The queue strip's entries, made as the queue first grows that long and reused after; the
## units they show, oldest first.
var _queue_strip: HBoxContainer
var _queue_entries: Array[ArmyCard] = []
var _queue_units: PackedStringArray = PackedStringArray()
## The producer whose queue the strip last showed, 0 when the panel has opened since: a rebuild
## whose queue is the one shown only counts the head down.
var _queue_id: int = 0
var _queue_empty: Label
## What the head entry last showed: its status and its seconds left, so a tick that changes
## neither sets no text.
var _head_status: String = ""
var _head_seconds: int = -1
## The state whose `changed` rebuilds the army panel's content, at the next refresh (main.gd
## refreshes once a frame after any change); a tick only counts down.
var _watched: BaseState
var _army_stale: bool = false
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


## A build card's parts that a refresh sets, and what it last showed.
class BuildCard:
	var art: CardArt
	var picture: TextureRect
	var title: Label
	## The count chip's text, and the chip of the Command Center level a locked card needs.
	var count: Label
	var lock: Control
	## The cost row's room for each icon (its resource in `kinds`, its colour in `colors`), and the
	## clock's on the last line, which reads the build time (`time`) or why the card cannot be built.
	var icons: Array[Control] = []
	var kinds: PackedStringArray = PackedStringArray()
	var colors: PackedColorArray = PackedColorArray()
	var clock: Control
	var line: Label
	var time: String = ""
	## The state in words (entry_status), and whether the card is locked or shows a reason.
	var status: String = ""
	var locked: bool = false
	var reason: bool = false


## What a build card draws under its picture, as one triangle array (HudIcon.Pen): a light line
## inside its border, its category's stripe along its top, the plinth, the count chip's shape,
## the cost row's icons on their coins and the clock. Redrawn when the card's rows are laid out
## or its state changes, never per frame.
class CardArt:
	extends Control

	const SIDES := 48

	var card: BuildCard
	## The category's colour.
	var tint: Color = Color.WHITE

	## The plinth's centre, under the stripe.
	func plinth_centre() -> Vector2:
		return Vector2(Hud.CARD_SIZE.x / 2.0, Hud.BORDER + Hud.STRIPE_HEIGHT + 4 + Hud.PLINTH / 2.0)

	func _draw() -> void:
		var pen := HudIcon.Pen.new()
		var inside := Rect2(Vector2.ZERO, size).grow(-Hud.BORDER)
		pen.add_stroke(Hud._round_rect(inside.grow(-0.5), Vector2.ONE * (12 - Hud.BORDER - 0.5), false), 1.0,
			Hud.EDGE_LIGHT, true)
		var stripe := Rect2(inside.position, Vector2(inside.size.x, Hud.STRIPE_HEIGHT))
		pen.add_fill(Hud._round_rect(stripe, Vector2(12 - Hud.BORDER, Hud.STRIPE_HEIGHT), true), tint, false)
		var centre := plinth_centre()
		var radius := Hud.PLINTH / 2.0
		pen.add_fill(Hud._circle(centre, radius, SIDES), Color(tint, Hud.PLINTH_ALPHA), false)
		pen.add_stroke(Hud._circle(centre, radius - Hud.PLINTH_RING / 2.0, SIDES), Hud.PLINTH_RING, Hud.INK, true)
		if card.count.visible:
			_chip(pen, _rect_of(card.count).grow_individual(Hud.CHIP_PAD.x, Hud.CHIP_PAD.y, Hud.CHIP_PAD.x,
				Hud.CHIP_PAD.y), Hud.CARD_DISABLED)
		for i: int in card.icons.size():
			HudIcon.paint(pen, card.kinds[i], _rect_of(card.icons[i]), card.colors[i], false, card.colors[i])
		if card.clock.visible:
			HudIcon.paint(pen, "clock", _rect_of(card.clock), Hud.TEXT_DIM)
		pen.draw(self)

	## A pill round `rect`: `fill`, an ink ring.
	func _chip(pen: HudIcon.Pen, rect: Rect2, fill: Color) -> void:
		var radius := Vector2.ONE * rect.size.y / 2.0
		pen.add_fill(Hud._round_rect(rect, radius, false), fill, false)
		pen.add_stroke(Hud._round_rect(rect.grow(-Hud.CHIP_RING / 2.0), radius - Vector2.ONE * Hud.CHIP_RING / 2.0,
			false), Hud.CHIP_RING, Hud.INK, true)

	## Where `control` lies in this one's space.
	func _rect_of(control: Control) -> Rect2:
		return get_global_transform().affine_inverse() * control.get_global_rect()


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
	_build_expedition_button()
	_build_place_bar()
	_build_info_panel()
	_build_toast()
	if OS.is_debug_build():
		_build_debug_buttons()
	get_viewport().size_changed.connect(fit_safe_area)
	fit_safe_area()


## `painting`: walls are being painted, so Place reads Done and is always enabled; there is
## nothing to confirm, and Done ends the mode.
func refresh(state: BaseState, selected_id: int, placing: bool, ghost_ok: bool, painting: bool) -> void:
	_state = state
	_watch(state)
	var elapsed := clampi(state.now - _meters_now, 1, FLASH_MAX_SECONDS)
	_meters_now = state.now
	_count(state)
	for res: String in _catalog.resources:
		# A resource the base has no storage for yet (antimatter, early on) is hidden, unless
		# the cheats make every resource infinite.
		var capacity: int = _capacities[res]
		_meters[res].visible = capacity > 0 or cheats
		var amount: int = state.resources[res]
		var fraction := clampf(float(amount) / capacity, 0.0, 1.0) if capacity > 0 else 0.0
		if cheats:
			fraction = 1.0
		_set_fill(res, fraction)
		# A drop (a purchase) or a rise past FLASH_RISE_TICKS ticks' production (a payout, an
		# offline catch-up) flashes the fill; the per-tick trickle does not. Under the cheats the
		# meter reads "∞" whatever it holds.
		var shown := _meter_amounts.has(res)
		if not cheats and shown and _flashes(res, amount - _meter_amounts[res], elapsed):
			_meter_shaders[res].set_shader_parameter(&"flash_time", Motion.clock())
		if not shown or amount != _meter_amounts[res] or capacity != _meter_capacities[res]:
			_meter_labels[res].text = "∞" if cheats else "%s / %s" % [Format.short(amount), Format.short(capacity)]
			_set_full(res, not cheats and capacity > 0 and amount >= capacity)
		_meter_amounts[res] = amount
		_meter_capacities[res] = capacity
	_drone_ring.set_counts(_drones_total - _drones_busy, _drones_total)

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
	var open_fields := _catalog.expedition_field_count() - state.sector.cleared.size()
	if open_fields != _open_fields:
		_open_fields = open_fields
		_expedition_count.text = str(open_fields)
	_expedition_badge.visible = open_fields > 0
	_show_expedition()
	_place_bar.visible = placing
	# Place commits a spend (gold); Done only ends painting (the safe cyan).
	var place_text := "Done" if painting else "Place"
	if _place_button.text != place_text:
		_place_button.text = place_text
		_place_button.theme_type_variation = &"ConfirmButton" if painting else &"CommitButton"
	_place_button.disabled = not ghost_ok and not painting
	_info_panel.visible = not placing and has_selection and _army_page == ArmyPage.NONE
	if _menu_open:
		_refresh_entries(state)
	if _info_panel.visible:
		_refresh_info(state, state.buildings[selected_id])
	# Its content is rebuilt after a state change (_on_state_changed); the tick only counts down.
	if _army_page != ArmyPage.NONE:
		if _army_stale:
			_refresh_army(state)
		else:
			_tick_army(state)
	_army_stale = false


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


## The device's safe area in `viewport`'s visible rect, as fit_safe_area fits it: the battle's HUD
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
## It runs at ready, on the viewport's size_changed, and once a second from main.gd's tick: the
## safe area can move without a resize (turning a phone over moves the notch to the other side).
func fit_safe_area() -> void:
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


## Adds a full screen over the base's parts (the sector map): under the root, so it sits on the
## safe area and takes the theme, and under the toast, which shows over it.
func add_screen(screen: Control) -> void:
	_root.add_child(screen)
	_root.move_child(_toast, -1)


static func error_text(code: String) -> String:
	return str(ERROR_TEXT.get(code, code))


## A research's error: `busy` there is the lab's one research slot, not construction.
static func research_error_text(code: String) -> String:
	return "Research already running" if code == BaseState.ERR_BUSY else error_text(code)


# --- Queries for the harness -----------------------------------------------------

func build_button() -> Button:
	return _build_button


## The Expedition button, and its badge's count of open fields ("" while it is hidden).
func expedition_button() -> Button:
	return _expedition_button


func expedition_badge() -> String:
	return _expedition_count.text if _expedition_badge.visible else ""


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


## A card's state in words: "built / max", or why it cannot be built (as its chips and its last
## line show it).
func entry_status(type: String) -> String:
	return _cards[type].status


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


## Whether the army panel shows a Foundry's making (open or opening).
func is_making_open() -> bool:
	return _army_page == ArmyPage.MAKE


## An ability's making card.
func make_card(ability: String) -> Button:
	return _make_cards[ability].button


## A making card's last line: "In stock N", or why it is locked.
func make_card_info(ability: String) -> String:
	return _make_cards[ability].info.text


## An ability's research card.
func research_ability_card(ability: String) -> Button:
	return _research_ability_cards[ability].button


## An ability's research card's level line and last line.
func research_ability_card_lines(ability: String) -> PackedStringArray:
	return PackedStringArray([_research_ability_cards[ability].level.text, _research_ability_cards[ability].info.text])


## The info panel's lines of stats, one a line.
func info_detail() -> String:
	return _info_detail.text


## Whether the army panel shows the research (open or opening).
func is_research_open() -> bool:
	return _army_page == ArmyPage.RESEARCH


func army_close_button() -> Button:
	return _army_close


## The army panel's title: the building's name and level.
func army_title() -> String:
	return _army_title.text


## The training header's housing line: "Housing used / capacity", or, with no Hangar, why none.
func housing_text() -> String:
	return _housing_label.text


## The training header's housing bar; hidden while the base has no Hangar.
func housing_bar() -> Control:
	return _housing_bar


## The housing bar's fill; its parent is the track it grows across.
func housing_fill() -> Control:
	return _housing_fill


## A unit's training card.
func train_card(unit: String) -> Button:
	return _train_cards[unit].button


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
	_show_expedition()


## The pictures render while a panel that shows them is open: the build panel or the army panel;
## and while the base is idle (prerender).
func _run_preview() -> void:
	_preview.run(_menu_open or _army_page != ArmyPage.NONE or _prerender)


## main.gd: whether the base is idle (no drag, no placing, no battle or map, after the first
## second), when the pictures not made yet render one a frame. Turned on, it asks first for every
## unit's picture at its researched level's tier, which the training and research cards show,
## then the build cards' go on in their order.
func prerender(on: bool) -> void:
	_prerender = on
	if on and _state != null:
		var keys := PackedStringArray()
		for unit: String in _catalog.unit_types():
			keys.append(ModelPreview.unit_key(unit, UnitModels.tier_of(_catalog, unit, _state.unit_level(unit))))
		_preview.request(keys)
	_run_preview()


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
	if type == _catalog.foundry_type and _catalog.foundry_type != "":
		return ArmyPage.MAKE
	return ArmyPage.RESEARCH if type == _catalog.research_type else ArmyPage.NONE


func _open_army(page: ArmyPage) -> void:
	if page == ArmyPage.NONE:
		return
	_army_page = page
	_army_id = _selected_id
	_queue_id = 0
	_train_page.visible = page == ArmyPage.TRAIN or page == ArmyPage.MAKE
	_housing_row.visible = page == ArmyPage.TRAIN
	_train_scroll.visible = page == ArmyPage.TRAIN
	_make_scroll.visible = page == ArmyPage.MAKE
	_make_scroll.scroll_horizontal = 0
	_research_page.visible = page == ArmyPage.RESEARCH
	_info_panel.visible = false
	_train_scroll.scroll_horizontal = 0
	_research_scroll.scroll_horizontal = 0
	_refresh_army(_state)
	_run_preview()
	_army_tween = _slide(_army, true, _army_tween)
	_show_expedition()


## Slides the army panel down. The selection stays as it is: refresh() shows its info panel.
func _close_army() -> void:
	if _army_page == ArmyPage.NONE:
		return
	_army_page = ArmyPage.NONE
	_run_preview()
	_army_tween = _slide(_army, false, _army_tween)
	_show_expedition()


## The panel's close button: back to the building's info panel, still selected.
func _on_army_close() -> void:
	_close_army()
	if _state != null and _state.buildings.has(_selected_id):
		_info_panel.visible = true
		_refresh_info(_state, _state.buildings[_selected_id])


## Rebuilds the army panel's content after `state.changed`, which the HUD connects to itself from
## the state it is given: the change marks it, and the next refresh (main.gd's, at the end of the
## frame) rebuilds it once however many changes came.
func _watch(state: BaseState) -> void:
	if state == _watched:
		return
	if _watched != null and _watched.changed.is_connected(_on_state_changed):
		_watched.changed.disconnect(_on_state_changed)
	_watched = state
	state.changed.connect(_on_state_changed)
	# What was kept of the last state goes with it, so it is freed (Reset base, Template base).
	_counted = null
	_info_key = []


func _on_state_changed() -> void:
	_army_stale = _army_page != ArmyPage.NONE


## The one-second tick while the panel is open: only the countdown. It calls no query that
## copies (queue_of does) and sets text only where the shown value changed.
func _tick_army(state: BaseState) -> void:
	if _army_page == ArmyPage.TRAIN or _army_page == ArmyPage.MAKE:
		_refresh_head(state)
	else:
		_tick_research(state)


## Everything the army panel shows, on opening it and on each state change.
func _refresh_army(state: BaseState) -> void:
	var building: BuildingState = state.buildings[_army_id]
	_army_title.text = "%s   Lv %d" % [_catalog.display_name(building.type), building.level]
	if _army_page == ArmyPage.TRAIN:
		_refresh_training(state, building)
	elif _army_page == ArmyPage.MAKE:
		_refresh_making(state, building)
	else:
		_refresh_research(state)
	_set_pictures(state)


## The shown cards' pictures, each its unit at its researched level's tier (UnitModels.tier_of);
## those not rendered yet are asked of the preview, and come in _on_preview_rendered.
func _set_pictures(state: BaseState) -> void:
	if _army_page == ArmyPage.MAKE:
		return
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
	_refresh_housing(state)
	_refresh_queue(state)


## The header's housing line: the army's housing used over its capacity, on the line and the bar;
## with no Hangar, in the dim style, why no unit can be housed, and no bar.
func _refresh_housing(state: BaseState) -> void:
	var capacity := state.housing_capacity()
	_housing_bar.visible = capacity > 0
	if capacity == 0:
		_housing_label.theme_type_variation = &"CardCount"
		_housing_label.text = NO_HANGAR
		return
	var used := state.housing_used()
	_housing_label.theme_type_variation = &"HousingText"
	_housing_label.text = "Housing %s / %s" % [Format.amount(used), Format.amount(capacity)]
	var track := HOUSING_BAR_SIZE - Vector2(2 * BORDER, 2 * BORDER)
	var width := roundf(track.x * clampf(float(used) / capacity, 0.0, 1.0))
	# One unit housed still shows on the bar.
	if used > 0:
		width = maxf(width, HOUSING_MIN_FILL)
	_housing_fill.size = Vector2(width, track.y)


## The Foundry's ability cards, then its queue (the training page's strip). A card is locked,
## disabled and dimmed, until the Foundry's finished level makes the ability.
func _refresh_making(state: BaseState, building: BuildingState) -> void:
	for ability: String in _make_cards:
		var card := _make_cards[ability]
		var stats := _catalog.ability_level_stats(ability, state.ability_level(ability))
		_set_card_cost(card, stats.get("make_cost", _NO_COST), _catalog.ability_make_seconds(ability))
		var needed := _catalog.ability_requires_foundry(ability)
		var locked := building.level < needed
		card.button.disabled = locked
		card.heading.modulate.a = DISABLED_ALPHA if locked else 1.0
		card.info.theme_type_variation = &"CardReason" if locked else &"CardCount"
		if locked:
			card.info.text = "Needs %s %d" % [_catalog.display_name(building.type), needed]
		else:
			card.info.text = "In stock %d" % state.stock(ability)
	_refresh_queue(state)


## The queue strip: an entry per queued unit (or ability, on the making page), oldest first, the head's with its state. Entries
## are made only as the queue first grows that long; after that a rebuild only sets text, and only
## when the queue is not the one shown.
func _refresh_queue(state: BaseState) -> void:
	# A copy, built per call: taken here, on a state change, and kept for the ticks between.
	var making := _army_page == ArmyPage.MAKE
	var units := state.making_queue_of(_army_id) if making else state.queue_of(_army_id)
	if _queue_id == _army_id and units == _queue_units:
		_refresh_head(state)
		return
	_queue_id = _army_id
	_queue_units = units
	while _queue_entries.size() < _queue_units.size():
		_queue_entries.append(_build_queue_entry(_queue_entries.size()))
	for i: int in _queue_entries.size():
		var entry := _queue_entries[i]
		entry.button.visible = i < _queue_units.size()
		if not entry.button.visible:
			continue
		var unit := _queue_units[i]
		if making:
			show_ability_glyph(entry.glyph, _catalog, unit)
			entry.title.text = _catalog.ability_name(unit)
		else:
			if entry.glyph.color != MaterialKit.ARMY:
				entry.glyph.color = MaterialKit.ARMY
				entry.glyph.coin = MaterialKit.ARMY
				entry.glyph.queue_redraw()
			entry.glyph.show_icon(_catalog.unit_crew(unit), _catalog.unit_class(unit) == "air")
			entry.title.text = _catalog.unit_name(unit)
		entry.info.visible = i == 0
	_head_seconds = -1
	_refresh_head(state)
	_queue_empty.visible = _queue_units.is_empty()
	_queue_empty.text = "Nothing being made" if making else "Nothing in training"


## The head entry's state: its time left, "Waiting for room" or "Paused". The queries it reads
## build nothing; the text is set only when the status or the seconds changed.
func _refresh_head(state: BaseState) -> void:
	if _queue_units.is_empty():
		return
	var making := _army_page == ArmyPage.MAKE
	var status := state.making_status(_army_id) if making else state.training_status(_army_id)
	var seconds := state.making_seconds_left(_army_id) if making else state.training_seconds_left(_army_id)
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
	var running_ability := state.research_ability
	_research_prefix = ""
	if running == "" and running_ability == "":
		_research_line.text = "No research running"
	else:
		if running != "":
			_research_prefix = "Researching %s to Lv %d: " % [_catalog.unit_name(running), state.unit_level(running) + 1]
		else:
			_research_prefix = "Researching %s to Lv %d: " % [_catalog.ability_name(running_ability),
				state.ability_level(running_ability) + 1]
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
	for ability: String in _research_ability_cards:
		var card := _research_ability_cards[ability]
		var level := state.ability_level(ability)
		card.level.text = "Level %d" % level
		var top := level >= _catalog.ability_max_level(ability)
		card.cost_row.visible = not top
		var dim := top
		if top:
			card.info.text = "Max level"
			card.info.theme_type_variation = &"CardCount"
		else:
			var stats := _catalog.ability_level_stats(ability, level + 1)
			_set_card_cost(card, stats.get("research_cost", _NO_COST), int(stats.get("research_seconds", 0)))
			var lab := int(stats.get("requires_lab", 1))
			if not state.is_ability_unlocked(ability):
				dim = true
				card.info.text = "Needs %s %d" % [_catalog.display_name(_catalog.foundry_type),
					_catalog.ability_requires_foundry(ability)]
			else:
				dim = state.lab_level() < lab
				card.info.text = "Researching" if ability == running_ability else "Needs Lab %d" % lab
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


func _on_make_card(ability: String) -> void:
	make_pressed.emit(_army_id, ability)


func _on_research_card(unit: String) -> void:
	research_pressed.emit(unit)


## An entry cancels the newest queued unit of its type, not necessarily itself.
func _on_queue_entry(index: int) -> void:
	if index >= _queue_units.size():
		return
	if _army_page == ArmyPage.MAKE:
		cancel_making_pressed.emit(_army_id, _queue_units[index])
	else:
		cancel_training_pressed.emit(_army_id, _queue_units[index])


# --- Refresh helpers -------------------------------------------------------------

## Only the selected tab's cards; the others are hidden. A card shows its count on a chip; one
## that cannot be built now is disabled, and says why on its last line in place of its build time;
## one the Command Center has not unlocked shows its picture greyed under a chip of the level it
## needs, its name dimmed, and no count. The buildings are counted by type once, for every card.
func _refresh_entries(state: BaseState) -> void:
	var counts: Dictionary[String, int] = {}
	for id: int in state.buildings:
		var type := state.buildings[id].type
		counts[type] = counts.get(type, 0) + 1
	for type: String in _entries:
		if _catalog.category_of(type) != _tab:
			continue
		var error := state.check_can_build(type)
		var card := _cards[type]
		var count: int = counts.get(type, 0)
		card.status = _entry_status_text(state, type, error, count)
		_entries[type].disabled = error != ""
		var locked := error == BaseState.ERR_CC_LEVEL
		var reason := error != "" and not locked
		card.count.text = "%d/%d" % [count, _catalog.max_count(type, state.cc_level())]
		card.line.text = card.status if reason else card.time
		card.line.theme_type_variation = &"CardWarning" if reason else &"CardTime"
		if locked != card.locked or reason != card.reason:
			card.locked = locked
			card.reason = reason
			card.count.visible = not locked
			card.lock.visible = locked
			card.clock.visible = not reason
			card.picture.material = _locked_material if locked else null
			card.title.modulate.a = LOCKED_NAME_ALPHA if locked else 1.0
			card.art.queue_redraw()


## `count`: the buildings of `type` the base has.
func _entry_status_text(state: BaseState, type: String, error: String, count: int) -> String:
	if error == "":
		return "%d / %d" % [count, _catalog.max_count(type, state.cc_level())]
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
	var key := [building.id, building.level, building.target_level, state.seconds_left(building.id), state,
		state.buildings_revision, state.housing_used(), state.stock_total()]
	if key == _info_key:
		_refresh_upgrade(state, building, false)
		return
	_info_key = key
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
	if _producers.has(type):
		# With no Hangar, what the training header says.
		if state.housing_capacity() == 0:
			lines.append(NO_HANGAR)
		else:
			lines.append("Housing %s / %s" % [Format.amount(state.housing_used()), Format.amount(state.housing_capacity())])
	if type == _catalog.foundry_type:
		lines.append("Stock %d / %d" % [state.stock_total(), state.foundry_capacity()])
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
	_action_button.text = "Train"
	if page == ArmyPage.RESEARCH:
		_action_button.text = "Research"
	elif page == ArmyPage.MAKE:
		_action_button.text = "Make"
	_refresh_upgrade(state, building, true)


## The info panel's upgrade button and its note: its text (`with_text`, when the panel's text is
## rebuilt) from the level, and whether it can be pressed from the state's check, which the
## resources move every second.
func _refresh_upgrade(state: BaseState, building: BuildingState, with_text: bool) -> void:
	var type := building.type
	_upgrade_note.text = ""
	if building.is_busy():
		_upgrade_button.text = "Under construction"
		_upgrade_button.disabled = true
		return
	if building.level >= _catalog.max_level(type):
		_upgrade_button.text = "Max level"
		_upgrade_button.disabled = true
		return
	if with_text:
		var next := _catalog.level_stats(type, building.level + 1)
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

## The top-left row: a meter per resource, then the drone ring, on one strip that stops a touch
## on it as any opaque part does.
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
	var strip := PanelContainer.new()
	strip.theme_type_variation = &"MeterStrip"
	strip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_top.add_child(strip)
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 14)
	strip.add_child(bar)
	var stripe := _make_stripe()
	for i: int in _catalog.resources.size():
		var res := _catalog.resources[i]
		_build_meter(bar, res, res, _resource_color(res), stripe, fmod(i * GLINT_STAGGER, 1.0))
	_drone_ring = DroneRing.new()
	bar.add_child(_drone_ring)


## One meter, under `key` (a resource's id): a pill-shaped trough that the fill, textured with
## `stripe` and tinted `color` at METER_VALUE, grows across by amount over storage, the amount on
## it, and the HudIcon `icon_kind` on its coin (in the trough's fill) over its left end. The stripes drift and glint
## (meter.gdshader), the glint at `phase` of its period. The meter stops a touch on it, as any
## opaque part does, so it never selects or drags what lies under it; its parts take none.
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
	# The stripes span the whole track; the fill's clip cuts them to the amount, and the shader to
	# the pill's round ends, with the gloss over its top third.
	var stripes := TextureRect.new()
	stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripes.texture = stripe
	stripes.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stripes.stretch_mode = TextureRect.STRETCH_TILE
	stripes.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var shader := ShaderMaterial.new()
	shader.shader = METER_SHADER
	var deep := Color.from_hsv(color.h, color.s, color.v * METER_VALUE)
	shader.set_shader_parameter(&"tint", Color(deep.r / STRIPE_BASE, deep.g / STRIPE_BASE, deep.b / STRIPE_BASE))
	shader.set_shader_parameter(&"phase", phase)
	shader.set_shader_parameter(&"track_height", METER_TRACK.y)
	shader.set_shader_parameter(&"track_width", METER_TRACK.x)
	shader.set_shader_parameter(&"full_color", GOLD)
	stripes.material = shader
	stripes.size = METER_TRACK
	fill.add_child(stripes)
	# The ink border again over the fill.
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme_type_variation = &"MeterFrame"
	trough.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"MeterText"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	trough.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = METER_COIN - METER_TROUGH_LEFT
	label.offset_right = -METER_TEXT_RIGHT
	var coin := HudIcon.new()
	coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.kind = icon_kind
	coin.color = color
	coin.coin = TROUGH
	coin.position = Vector2(0, (METER_SIZE.y - METER_COIN) / 2.0)
	coin.size = Vector2.ONE * METER_COIN
	meter.add_child(coin)
	_meters[key] = meter
	_meter_fills[key] = fill
	_meter_labels[key] = label
	_meter_shaders[key] = shader


## The full state, when a meter's amount reaches its cap: a gold line inside the pill and the
## digits in gold. Set only when it changes.
func _set_full(key: String, full: bool) -> void:
	if _meter_full.get(key, false) == full:
		return
	_meter_full[key] = full
	_meter_shaders[key].set_shader_parameter(&"full", full)
	if full:
		_meter_labels[key].add_theme_color_override("font_color", GOLD)
	else:
		_meter_labels[key].remove_theme_color_override("font_color")


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
	if not _rates_read:
		_rates = _state.production_rates()
		_rates_read = true
	return change > ceili(FLASH_RISE_TICKS * _rates[res] * elapsed / 3600.0)


## Reads the capacities and the builders again when the state or its buildings_revision moved since
## they were read, and lets the rates be read again then.
func _count(state: BaseState) -> void:
	if state == _counted and state.buildings_revision == _counted_revision:
		return
	_counted = state
	_counted_revision = state.buildings_revision
	_capacities = state.capacities()
	_drones_total = state.builders_total()
	_drones_busy = state.builders_busy()
	_rates_read = false


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
	_menu.draw.connect(_draw_edge.bind(_menu, true))
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
	_locked_material = ShaderMaterial.new()
	_locked_material.shader = LOCKED_SHADER
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


## A card: the category's stripe along its top and the building's picture (ModelPreview's, empty
## until it is rendered) on a plinth of the category's colour, its count on a chip at the top
## right, and three lines: the name, the level 1 cost (each amount after its resource's icon, in
## its resource's colour) and the build time after a small clock, or why it cannot be built.
## A locked card adds a chip of the Command Center level it needs over the plinth.
## `_refresh_entries` fills them. The card's drawn parts (CardArt) are one triangle array under the
## picture; its content sinks with it when pressed.
func _build_entry(type: String) -> Button:
	var button := _button("", CARD_SIZE)
	# PASS, so a drag that starts on a card reaches the ScrollContainer and scrolls the
	# strip; the panel behind still stops the touch from reaching the world.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(_on_card_pressed.bind(type))
	var card := BuildCard.new()
	var body := _card_body(button)
	card.art = CardArt.new()
	card.art.card = card
	card.art.tint = CATEGORY_STRIPE.get(_catalog.category_of(type), ACCENT)
	card.art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(card.art)
	card.art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card.picture = TextureRect.new()
	card.picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card.picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	card.picture.position = card.art.plinth_centre() - PREVIEW_SIZE / 2.0
	card.picture.size = PREVIEW_SIZE
	body.add_child(card.picture)
	_entry_preview[type] = card.picture

	card.count = Label.new()
	card.count.theme_type_variation = &"CardChip"
	card.count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(card.count)
	card.count.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	card.count.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	card.count.offset_right = -BORDER - 4 - CHIP_PAD.x
	card.count.offset_top = BORDER + STRIPE_HEIGHT + 4 + CHIP_PAD.y
	card.count.resized.connect(card.art.queue_redraw)
	# Over the plinth's foot, centred.
	var lock_row := CenterContainer.new()
	lock_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(lock_row)
	lock_row.set_anchors_preset(Control.PRESET_TOP_WIDE)
	lock_row.offset_top = card.art.plinth_centre().y + PLINTH / 2.0 - 30
	card.lock = PanelContainer.new()
	card.lock.theme_type_variation = &"LockChip"
	card.lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.lock.visible = false
	lock_row.add_child(card.lock)
	var lock_line := HBoxContainer.new()
	lock_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_line.add_theme_constant_override("separation", 3)
	card.lock.add_child(lock_line)
	var padlock := HudIcon.new()
	padlock.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padlock.kind = "lock"
	padlock.color = TEXT
	padlock.custom_minimum_size = Vector2.ONE * LOCK_ICON
	padlock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	lock_line.add_child(padlock)
	var level := Label.new()
	level.theme_type_variation = &"LockText"
	level.text = "CC %d" % int(_catalog.level_stats(type, 1).get("requires_cc", 1))
	lock_line.add_child(level)

	var lines := VBoxContainer.new()
	lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lines.add_theme_constant_override("separation", -2)
	body.add_child(lines)
	lines.set_anchors_preset(Control.PRESET_FULL_RECT)
	lines.offset_left = 8
	lines.offset_top = CARD_LINES_TOP
	lines.offset_right = -8
	lines.offset_bottom = -BORDER - 2
	card.title = _card_label(lines, _catalog.display_name(type), &"CardName")
	card.title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 4)
	lines.add_child(cost_row)
	var stats := _catalog.level_stats(type, 1)
	var cost: Dictionary = stats.get("cost", {})
	if cost.is_empty():
		_card_label(cost_row, "Free", &"CardCost")
	for res: Variant in cost:
		if cost_row.get_child_count() > 0:
			_spacer(cost_row, Vector2(8, 0))
		card.icons.append(_spacer(cost_row, COST_ICON))
		card.kinds.append(str(res))
		card.colors.append(_resource_color(str(res)))
		var amount := _card_label(cost_row, Format.amount(int(cost[res])), &"CardCost")
		amount.add_theme_color_override("font_color", _resource_color(str(res)))
	cost_row.sort_children.connect(card.art.queue_redraw)
	var last_row := HBoxContainer.new()
	last_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	last_row.alignment = BoxContainer.ALIGNMENT_CENTER
	last_row.add_theme_constant_override("separation", 4)
	lines.add_child(last_row)
	card.clock = _spacer(last_row, Vector2.ONE * CLOCK_SIZE)
	card.time = Format.duration(int(stats.get("build_seconds", 0)))
	card.line = _card_label(last_row, card.time, &"CardTime")
	last_row.sort_children.connect(card.art.queue_redraw)
	_cards[type] = card
	_entries[type] = button
	return button


## A card's content, which sinks with the card's shape while it is pressed (_sink).
func _card_body(button: Button) -> Control:
	var body := Control.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(body)
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.draw.connect(_sink.bind(button, body))
	return body


## Moves a card's content with its shape: PRESSED_SINK down and right while it is pressed. The
## button redraws whenever its state changes, so its draw signal says when.
static func _sink(button: Button, body: Control) -> void:
	var mode := button.get_draw_mode()
	var pressed := mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
	body.position = Vector2.ONE * PRESSED_SINK if pressed else Vector2.ZERO


## An empty control `size` big in `parent`: room in a row for something the card draws there.
static func _spacer(parent: Control, size: Vector2) -> Control:
	var spacer := Control.new()
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	spacer.custom_minimum_size = size
	spacer.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(spacer)
	return spacer


## Bottom left, opposite Build: opens the sector map, with a badge of the open fields on its top
## right corner. The badge takes no touch.
func _build_expedition_button() -> void:
	_expedition_button = _button("EXPEDITION", EXPEDITION_SIZE, &"ExpeditionButton")
	_expedition_button.pressed.connect(func() -> void: expedition_pressed.emit())
	_root.add_child(_expedition_button)
	_expedition_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_expedition_button.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_expedition_button.offset_left = MARGIN
	_expedition_button.offset_right = MARGIN + EXPEDITION_SIZE.x
	_expedition_button.offset_top = -MARGIN - EXPEDITION_SIZE.y
	_expedition_button.offset_bottom = -MARGIN
	_expedition_badge = PanelContainer.new()
	_expedition_badge.theme_type_variation = &"Badge"
	_expedition_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_expedition_badge.custom_minimum_size = BADGE_SIZE
	_expedition_button.add_child(_expedition_badge)
	_expedition_badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_expedition_badge.offset_left = -BADGE_SIZE.x + 10
	_expedition_badge.offset_right = 10
	_expedition_badge.offset_top = -12
	_expedition_badge.offset_bottom = -12 + BADGE_SIZE.y
	_expedition_count = Label.new()
	_expedition_count.theme_type_variation = &"BadgeText"
	_expedition_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_expedition_count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_expedition_badge.add_child(_expedition_count)


## The Expedition button shows with Build, and not while a bottom panel (the build panel or the
## army panel) is open across its corner.
func _show_expedition() -> void:
	_expedition_button.visible = _build_button.visible and not _menu_open and _army_page == ArmyPage.NONE


## The army panel: like the build panel, the screen's full width at its bottom edge, its content
## padded into the safe area and a column kept clear for the Build button. A header of the
## building's name and level (and, on the training page, the army's housing under it) and a
## close button, over one of two pages: the training page, a strip of unit cards and, under it,
## the queue strip; or the research page, the research running over a strip of unit cards. Built
## hidden; _open_army shows a page.
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
	_army.draw.connect(_draw_edge.bind(_army, true))
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
	var heading := VBoxContainer.new()
	heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Centred on the close button, as the title alone was on the pages without the housing line.
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_theme_constant_override("separation", 0)
	header.add_child(heading)
	_army_title = Label.new()
	_army_title.theme_type_variation = &"InfoTitle"
	heading.add_child(_army_title)
	_build_housing_line(heading)
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
	var make_cards := _strip(_train_page, TRAIN_CARD_SIZE.y + 18)
	_make_scroll = make_cards.get_parent().get_parent() as ScrollContainer
	for ability: String in _catalog.ability_types():
		var card := _build_army_card(ability, TRAIN_CARD_SIZE, true)
		card.button.pressed.connect(_on_make_card.bind(ability))
		make_cards.add_child(card.button)
		_make_cards[ability] = card
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
	for ability: String in _catalog.ability_types():
		var card := _build_army_card(ability, RESEARCH_CARD_SIZE, true)
		card.level = _card_label(card.heading, "", &"CardCost")
		card.heading.move_child(card.level, card.title.get_index() + 1)
		card.button.pressed.connect(func() -> void: research_ability_pressed.emit(ability))
		research_cards.add_child(card.button)
		_research_ability_cards[ability] = card


## The training header's housing line under `parent`: the army's figure, the text the refresh
## fills, and a small bar like a meter's, the army accent's fill with its gloss in a trough, the
## ink border drawn again over it.
func _build_housing_line(parent: Control) -> void:
	_housing_row = HBoxContainer.new()
	_housing_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_housing_row.add_theme_constant_override("separation", 8)
	parent.add_child(_housing_row)
	var icon := HudIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.kind = "army"
	icon.color = MaterialKit.ARMY
	icon.custom_minimum_size = HOUSING_ICON
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_housing_row.add_child(icon)
	_housing_label = Label.new()
	_housing_label.theme_type_variation = &"HousingText"
	_housing_row.add_child(_housing_label)
	var bar := Panel.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.theme_type_variation = &"MeterTrough"
	bar.custom_minimum_size = HOUSING_BAR_SIZE
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_housing_row.add_child(bar)
	_housing_bar = bar
	var track := Control.new()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	track.position = Vector2(BORDER, BORDER)
	track.size = HOUSING_BAR_SIZE - Vector2(2 * BORDER, 2 * BORDER)
	bar.add_child(track)
	var fill := ColorRect.new()
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.color = MaterialKit.ARMY
	fill.clip_contents = true
	fill.size = Vector2(0, track.size.y)
	track.add_child(fill)
	_housing_fill = fill
	var gloss := ColorRect.new()
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gloss.color = GLOSS
	gloss.size = Vector2(track.size.x, track.size.y / 3.0)
	fill.add_child(gloss)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.theme_type_variation = &"MeterFrame"
	bar.add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


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
func _build_army_card(unit: String, card_size: Vector2, ability: bool = false) -> ArmyCard:
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
	if ability:
		card.glyph = _glyph(heading, "", PICTURE_SIZE)
		show_ability_glyph(card.glyph, _catalog, unit)
	else:
		card.picture = TextureRect.new()
		card.picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.picture.custom_minimum_size = PICTURE_SIZE
		card.picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		card.picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heading.add_child(card.picture)
	card.title = _card_label(heading, _catalog.ability_name(unit) if ability else _catalog.unit_name(unit),
		&"CardName")
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


## A unit's glyph (HudIcon, by its crew, winged for an air unit) in the army accent on an army
## coin, `glyph_size`, centred across `parent`; `unit` "" leaves it blank until show_icon.
func _glyph(parent: Control, unit: String, glyph_size: Vector2) -> HudIcon:
	var glyph := HudIcon.new()
	glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glyph.custom_minimum_size = glyph_size
	glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	glyph.color = MaterialKit.ARMY
	glyph.coin = MaterialKit.ARMY
	if unit != "":
		glyph.show_icon(_catalog.unit_crew(unit), _catalog.unit_class(unit) == "air")
	parent.add_child(glyph)
	return glyph


## Shows `ability`'s glyph on `glyph` (HudIcon): its effect's emblem in its effect's colour
## (ABILITY_COLORS) on a coin of it. Shared with the battle's abilities bar and result (BattleHud).
static func show_ability_glyph(glyph: HudIcon, catalog: Catalog, ability: String) -> void:
	var effect := catalog.ability_effect(ability)
	glyph.color = ABILITY_COLORS.get(effect, MaterialKit.ARMY)
	glyph.coin = glyph.color
	glyph.show_icon(effect, false)
	glyph.queue_redraw()


## Cancel and Place on a panel at the bottom centre.
func _build_place_bar() -> void:
	var panel := PanelContainer.new()
	panel.draw.connect(_draw_edge.bind(panel, false))
	_root.add_child(panel)
	_anchor_bottom(panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	panel.add_child(row)
	var cancel := _button("Cancel", Vector2(170, 72), &"BarButton")
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	row.add_child(cancel)
	_place_button = _button("Place", Vector2(170, 72), &"CommitButton")
	_place_button.pressed.connect(func() -> void: confirm_pressed.emit())
	row.add_child(_place_button)
	_place_bar = panel


func _build_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	panel.draw.connect(_draw_edge.bind(panel, false))
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
	var close := _button("Close", INFO_CLOSE_SIZE)
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
## with a 3 px ink border and a flat ink shadow; text in the UI palette. White text takes an ink
## outline only over a bright fill or over the world; text on a dark panel or card, and ink text,
## take none.
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
	# A full screen over the base (the sector map, add_screen): the panel's fill, opaque.
	ui.set_type_variation(&"ScreenPanel", &"PanelContainer")
	ui.set_stylebox("panel", &"ScreenPanel", _shape(Color(PANEL, 1.0), 12))
	ui.set_type_variation(&"Badge", &"PanelContainer")
	ui.set_stylebox("panel", &"Badge", _shape(MaterialKit.DEFENCE, 15, 0.0))

	# The meters: one strip behind them, a pill-shaped trough under each fill, and its ink border
	# again over it.
	var strip := _flat(Color(PANEL, STRIP_ALPHA), STRIP_RADIUS)
	strip.set_content_margin_all(STRIP_PADDING)
	ui.set_type_variation(&"MeterStrip", &"PanelContainer")
	ui.set_stylebox("panel", &"MeterStrip", strip)
	ui.set_type_variation(&"MeterTrough", &"Panel")
	ui.set_stylebox("panel", &"MeterTrough", _shape(TROUGH, roundi(METER_SIZE.y / 2.0)))
	var frame := StyleBoxFlat.new()
	frame.draw_center = false
	frame.border_color = INK
	frame.set_border_width_all(BORDER)
	frame.set_corner_radius_all(roundi(METER_SIZE.y / 2.0))
	ui.set_type_variation(&"MeterFrame", &"Panel")
	ui.set_stylebox("panel", &"MeterFrame", frame)
	# White, tinted to the category by the stripe's self_modulate; its top corners follow the
	# card's inside its border.
	var card_stripe := StyleBoxFlat.new()
	card_stripe.bg_color = Color.WHITE
	card_stripe.corner_radius_top_left = 12 - BORDER
	card_stripe.corner_radius_top_right = 12 - BORDER
	ui.set_type_variation(&"CardStripe", &"Panel")
	ui.set_stylebox("panel", &"CardStripe", card_stripe)

	# Buttons: a card unless a variation says otherwise. None takes focus. Gold commits a spend,
	# the army's orange starts a raid, cyan is the selected or the safe choice; each carries ink
	# text, and only white text on a dark fill is left without an outline.
	_button_shapes(ui, &"Button", CARD, 12)
	ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	for item: String in BUTTON_TEXT_COLORS:
		ui.set_color(item, "Button", TEXT)
	ui.set_color("font_disabled_color", "Button", Color(TEXT, DISABLED_ALPHA))
	ui.set_color("font_outline_color", "Button", INK)
	_button_variation(ui, &"BuildButton", GOLD, 12, DISPLAY_FONT, 30, 0, INK)
	_button_variation(ui, &"ExpeditionButton", MaterialKit.ARMY, 12, DISPLAY_FONT, 30, 0, INK)
	_button_variation(ui, &"UpgradeButton", GOLD, 12, BODY_FONT, 24, 0, INK)
	_button_variation(ui, &"CommitButton", GOLD, 12, DISPLAY_FONT, 24, 0, INK)
	_button_variation(ui, &"ConfirmButton", ACCENT, 12, DISPLAY_FONT, 24, 0, INK)
	_button_variation(ui, &"BarButton", CARD, 12, DISPLAY_FONT, 24, 0)
	_button_variation(ui, &"DebugButton", CARD, 12, DISPLAY_FONT, 20, 0)
	_button_variation(ui, &"CloseButton", CARD, 12, DISPLAY_FONT, 28, 0)
	_button_variation(ui, &"TabButton", CARD, 10, DISPLAY_FONT, 24, 0)
	# The selected tab: cyan in every state, ink text.
	_button_variation(ui, &"TabSelected", ACCENT, 10, DISPLAY_FONT, 24, 0, INK)
	for item: String in ["normal", "hover", "pressed", "hover_pressed"]:
		ui.set_stylebox(item, &"TabSelected", _shape(ACCENT, 10, BUTTON_MARGIN))

	_label_variation(ui, &"CardName", 22, TEXT, 0)
	_label_variation(ui, &"CardCost", 20, TEXT, 0)
	_label_variation(ui, &"CardCount", 19, TEXT_DIM, 0)
	_label_variation(ui, &"CardReason", 19, TEXT_DIM, 0)
	_label_variation(ui, &"QueueName", 19, TEXT, 0)
	_label_variation(ui, &"HousingText", 19, TEXT, 0)
	_label_variation(ui, &"CardWarning", 17, WARNING, 0)
	_label_variation(ui, &"CardTime", 17, TEXT_DIM, 0)
	_label_variation(ui, &"CardChip", 17, TEXT, 0)
	_label_variation(ui, &"LockText", 17, INK, 0)
	var lock := _flat(WARNING, 12)
	lock.border_color = INK
	lock.set_border_width_all(roundi(CHIP_RING))
	lock.content_margin_left = CHIP_PAD.x + CHIP_RING
	lock.content_margin_right = CHIP_PAD.x + CHIP_RING
	lock.content_margin_top = CHIP_PAD.y
	lock.content_margin_bottom = CHIP_PAD.y
	ui.set_type_variation(&"LockChip", &"PanelContainer")
	ui.set_stylebox("panel", &"LockChip", lock)
	_label_variation(ui, &"MeterText", 20, TEXT, 2.5, _meter_font())
	_label_variation(ui, &"InfoTitle", 30, TEXT, 0, DISPLAY_FONT)
	_label_variation(ui, &"InfoDetail", 19, TEXT, 0)
	_label_variation(ui, &"InfoNote", 19, WARNING, 0)
	_label_variation(ui, &"ToastText", 19, TEXT, 0)
	_label_variation(ui, &"BadgeText", 19, TEXT, 2)

	# The card strip's scroll bar: a dim grabber on an ink track.
	var track := _flat(Color(INK, 0.6), 4)
	ui.set_stylebox("scroll", "HScrollBar", track)
	ui.set_stylebox("scroll_focus", "HScrollBar", track)
	ui.set_stylebox("grabber", "HScrollBar", _flat(TEXT_DIM, 4))
	ui.set_stylebox("grabber_highlight", "HScrollBar", _flat(TEXT, 4))
	ui.set_stylebox("grabber_pressed", "HScrollBar", _flat(ACCENT, 4))
	return ui


## `outline`: the ink round the text, in pixels; 0 for none.
static func _button_variation(ui: Theme, variation: StringName, fill: Color, radius: int, font: Font,
		font_size: int, outline: float, text: Color = TEXT) -> void:
	ui.set_type_variation(variation, &"Button")
	_button_shapes(ui, variation, fill, radius)
	ui.set_font("font", variation, font)
	ui.set_font_size("font_size", variation, font_size)
	ui.set_constant("outline_size", variation, roundi(outline * OUTLINE_PER_PX))
	for item: String in BUTTON_TEXT_COLORS:
		ui.set_color(item, variation, text)


## Every state but focus: hover a shade lighter, pressed lighter still and sunk onto its shadow,
## disabled in the card-disabled fill.
static func _button_shapes(ui: Theme, type: StringName, fill: Color, radius: int) -> void:
	var pressed := fill.lightened(PRESSED_LIGHTEN)
	ui.set_stylebox("normal", type, _shape(fill, radius, BUTTON_MARGIN))
	ui.set_stylebox("hover", type, _shape(fill.lightened(0.08), radius, BUTTON_MARGIN))
	ui.set_stylebox("pressed", type, _shape(pressed, radius, BUTTON_MARGIN, true))
	ui.set_stylebox("hover_pressed", type, _shape(pressed, radius, BUTTON_MARGIN, true))
	ui.set_stylebox("disabled", type, _shape(CARD_DISABLED, radius, BUTTON_MARGIN))


## `outline`: the ink round the text, in pixels; 0 for none.
static func _label_variation(ui: Theme, variation: StringName, font_size: int, color: Color, outline: float,
		font: Font = null) -> void:
	ui.set_type_variation(variation, &"Label")
	ui.set_font_size("font_size", variation, font_size)
	ui.set_color("font_color", variation, color)
	ui.set_constant("outline_size", variation, roundi(outline * OUTLINE_PER_PX))
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
## its content move PRESSED_SINK px down and right, onto the shadow, which stays where it was.
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
		box.shadow_size = 0
		box.expand_margin_left = -PRESSED_SINK
		box.expand_margin_top = -PRESSED_SINK
		box.expand_margin_right = PRESSED_SINK
		box.expand_margin_bottom = PRESSED_SINK
		box.content_margin_left = margin + PRESSED_SINK
		box.content_margin_top = margin + PRESSED_SINK
		box.content_margin_right = margin - PRESSED_SINK
		box.content_margin_bottom = margin - PRESSED_SINK
	return box


## A panel's cel edge, drawn over its shape as one triangle array (HudIcon.Pen): a light line just
## inside its ink border, and on a bottom panel (`menu`: the build panel's and the army panel's
## shape, its border along the top only) a band a shade lighter across its top, down to MENU_BAND.
func _draw_edge(panel: Control, menu: bool) -> void:
	var pen := HudIcon.Pen.new()
	var inside := Rect2(Vector2.ZERO, panel.size).grow(-BORDER)
	if menu:
		# Inside a border along the top only, the shape's top corners (radius 16) are 16 across
		# and 13 down.
		var band := Rect2(Vector2(0, BORDER), Vector2(panel.size.x, MENU_BAND - BORDER))
		pen.add_fill(_round_rect(band, Vector2(16, 16 - BORDER), true),
			Color(PANEL.lightened(MENU_BAND_LIGHTEN), PANEL.a), false)
		var line := Rect2(Vector2(0, BORDER + 0.5), Vector2(panel.size.x, 0))
		pen.add_stroke(_round_rect(line, Vector2(16, 16 - BORDER - 0.5), true), 1.0, EDGE_LIGHT, false)
	else:
		pen.add_stroke(_round_rect(inside.grow(-0.5), Vector2.ONE * (12 - BORDER - 0.5), false), 1.0, EDGE_LIGHT, true)
	pen.draw(panel)


## The outline of `rect` with its corners rounded by `radius` (across, down), clockwise from its
## left side; with `top_only` its bottom corners stay square, and a rect with no height gives only
## its top edge.
static func _round_rect(rect: Rect2, radius: Vector2, top_only: bool) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 6
	var corners := [
		[rect.position + radius, PI],
		[Vector2(rect.end.x - radius.x, rect.position.y + radius.y), 1.5 * PI],
	]
	for corner: Array in corners:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		for i: int in steps + 1:
			var angle := from + 0.5 * PI * i / steps
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	if rect.size.y <= 0.0:
		return points
	if top_only:
		points.append(rect.end)
		points.append(Vector2(rect.position.x, rect.end.y))
		return points
	for corner: Array in [[rect.end - radius, 0.0], [Vector2(rect.position.x + radius.x, rect.end.y - radius.y), 0.5 * PI]]:
		var centre: Vector2 = corner[0]
		var from: float = corner[1]
		for i: int in steps + 1:
			var angle := from + 0.5 * PI * i / steps
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## A closed circle of `sides` points.
static func _circle(centre: Vector2, radius: float, sides: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i: int in sides:
		var angle := TAU * i / sides
		points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
	return points


## A plain rounded fill, for the scroll bar.
static func _flat(fill: Color, radius: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(4.0)
	return box
