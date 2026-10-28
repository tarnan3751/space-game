class_name SectorMap
extends PanelContainer
## The sector map (docs/reference/hud.md, **Sector map**): the expeditions' screen, a full panel
## over the base opened by the HUD's Expedition button, built in code and styled by the HUD's
## theme (Hud.add_screen puts it under the HUD's root, on the safe area). It reads BaseState and
## the outpost generator and reports presses as signals; it never changes game state: main.gd
## applies the scan and starts the battle, through PlacementController.
##
## One header (the title, Scan with its countdown, the close button) over one of two pages:
##   the fields: a card per field of state.sector_fields(), three to a row, each a thumbnail of
##     its outpost, its band as a word and a colour, the outpost's Command Center and its loot
##     targets; a cleared field is stamped with a star, dimmed and cannot be pressed;
##   a field's detail, opened from its card: a minimap of the outpost, the field's header again,
##     its loot, what it holds, the minimap's legend, Back and Attack.
## The fields are laid out (OutpostGenerator.generate_field, up to 25 ms for a hard field, about
## 100 ms for six at Command Center 10) off the main thread, one WorkerThreadPool task per field
## (LayoutJob), started the frame after the map opens and collected in _process as they finish,
## one a frame. They are kept for the sector's seed and epoch, so a scan or another base lays them
## out again (a task of an older epoch is collected and dropped). The generator touches only its
## own state, its SeededRng and the Catalog, which nothing writes after loading, and a task is
## handed the sector's numbers, not the BaseState. Each card's thumbnail is drawn as its field
## arrives, and the detail takes the field kept (waiting for its task, or laying it out then if
## none is running). Closing the map leaves the tasks running and collected; leaving the tree waits
## for every one, so the game quits cleanly with tasks in flight. Nothing is laid out or drawn per
## frame once they are all in.
## Under the header, "Scan to refresh: your Command Center has grown" while the sector's snapshot
## is of a lower Command Center than the base's.
##
## Touch: the panel is MOUSE_FILTER_STOP over the whole safe area, so no touch on it reaches the
## world (main.gd also takes the world's input out of the tree while it is open); its layout
## containers are IGNORE.

signal closed
signal scan_pressed
## Attack on the field the detail shows: its index and its layout (OutpostGenerator.generate).
signal attack_pressed(index: int, field: Dictionary)

## Each band's colour; a band not listed takes the HUD's accent.
const BAND_COLORS := {"easy": MaterialKit.ENERGY, "even": MaterialKit.ARMY, "hard": MaterialKit.DEFENCE}
const HINT := "Scan to refresh: your Command Center has grown"
const SCAN_SIZE := Vector2(190, 48)
const CARD_SIZE := Vector2(360, 200)
const THUMBNAIL_SIZE := Vector2(160, 160)
const LOOT_ICON_SIZE := Vector2(28, 28)
const STAMP_SIZE := Vector2(60, 60)
const MINIMAP_SIZE := Vector2(480, 480)
const SWATCH_SIZE := Vector2(18, 18)
const ATTACK_SIZE := Vector2(200, 64)
const BACK_SIZE := Vector2(140, 64)
## What the minimap draws, by the role of the building: its colour and its legend's word.
const WALL_COLOR := MaterialKit.HULL_MID
const DEFENCE_COLOR := MaterialKit.DEFENCE
const STORAGE_COLOR := Hud.GOLD
const HQ_COLOR := MaterialKit.ANTIMATTER
const OTHER_COLOR := MaterialKit.HULL_LIGHT
const GROUND_COLOR := MaterialKit.FIELD_DARK
const LEGEND := [["Command Center", HQ_COLOR], ["Defences", DEFENCE_COLOR], ["Storages and deposits", STORAGE_COLOR],
	["Walls", WALL_COLOR], ["Other buildings", OTHER_COLOR]]

var _catalog: Catalog
## The state of the last refresh.
var _state: BaseState
var _title: Label
var _scan_button: Button
var _close_button: Button
var _hint: Label
var _grid: GridContainer
var _cards: Array[FieldCard] = []
var _detail: Control
var _detail_header: FieldCard
var _minimap: Minimap
## What the detail's field holds (_holds).
var _detail_holds: Label
var _back_button: Button
var _attack_button: Button
## The field the detail shows, its index and epoch (-1 while the fields show), and its layout.
var _detail_index: int = -1
var _detail_epoch: int = -1
var _field: Dictionary = {}
## The seconds the Scan button last showed, so a tick sets its text only when they changed.
var _scan_seconds: int = -1
## Each band's skulls on the ribbon: its place in the catalog's order of bands, from 1.
var _band_skulls: Dictionary[String, int] = {}
## The fields laid out, by index ({} until laid out), for the sector's seed and epoch below.
var _layouts: Array[Dictionary] = []
var _layouts_seed: int = -1
var _layouts_epoch: int = -1
## The layout tasks running or finished and not collected yet, oldest first.
var _jobs: Array[LayoutJob] = []


## One field laid out on a WorkerThreadPool thread: its inputs, copied from the sector on the main
## thread, and, once the task has finished, its layout. Only the task writes `field`, and the main
## thread reads it only after wait_for_task_completion.
class LayoutJob:
	var catalog: Catalog
	var sector_seed: int
	var epoch: int
	var index: int
	var cc: int
	var capacity: Dictionary[String, int]
	var task: int = -1
	var field: Dictionary = {}

	func run() -> void:
		field = OutpostGenerator.generate_field(catalog, sector_seed, epoch, index, cc, capacity)


## A field's band, its outpost and its loot, on a card or over the detail: what dims while it is
## cleared, and the stamp.
class FieldCard:
	var button: Button
	var stripe: Control
	var content: Control
	var band: Label
	var colony: Label
	var loot_row: Control
	var loot: Dictionary[String, Label] = {}
	var loot_icons: Dictionary[String, HudIcon] = {}
	var no_loot: Label
	var stamp: Control
	## The card's thumbnail of its outpost, the detail's minimap on the detail; it carries the band.
	var thumbnail: Minimap


func setup(catalog: Catalog) -> void:
	_catalog = catalog
	theme_type_variation = &"ScreenPanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	offset_left = Hud.MARGIN
	offset_top = Hud.MARGIN
	offset_right = -Hud.MARGIN
	offset_bottom = -Hud.MARGIN
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 10)
	add_child(column)

	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_title = Label.new()
	_title.theme_type_variation = &"InfoTitle"
	_title.text = "SECTOR"
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_scan_button = _button("SCAN", SCAN_SIZE, &"ConfirmButton")
	_scan_button.pressed.connect(func() -> void: scan_pressed.emit())
	header.add_child(_scan_button)
	_close_button = _button("X", Hud.CLOSE_SIZE, &"CloseButton")
	_close_button.pressed.connect(close)
	header.add_child(_close_button)
	_hint = Label.new()
	_hint.theme_type_variation = &"InfoNote"
	_hint.text = HINT
	column.add_child(_hint)

	_grid = GridContainer.new()
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.columns = 3
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_grid.add_theme_constant_override("h_separation", 16)
	_grid.add_theme_constant_override("v_separation", 16)
	column.add_child(_grid)
	for index: int in catalog.expedition_field_count():
		var band := str(catalog.expedition_band(index).get("id", ""))
		if not _band_skulls.has(band):
			_band_skulls[band] = _band_skulls.size() + 1
		var card := _build_card()
		card.button.pressed.connect(func() -> void: show_field(index))
		_grid.add_child(card.button)
		_cards.append(card)
		_layouts.append({})
	_build_detail(column)
	set_process(false)


## Shows the map on the fields' page.
func open(state: BaseState) -> void:
	_show_fields()
	visible = true
	refresh(state)


## Hides the map and says so (main.gd gives the world its input back).
func close() -> void:
	if not visible:
		return
	visible = false
	_show_fields()
	closed.emit()


## Fills every card from the state (a scan, a cleared field), and the header. A detail whose field
## is no longer open (cleared, or the epoch moved on) goes back to the fields.
func refresh(state: BaseState) -> void:
	_state = state
	var fields := state.sector_fields()
	for i: int in mini(fields.size(), _cards.size()):
		_fill(_cards[i], fields[i])
		var cleared: bool = fields[i]["cleared"]
		_cards[i].button.disabled = cleared
		var tint := Color(1, 1, 1, Hud.DISABLED_ALPHA) if cleared else Color.WHITE
		_cards[i].content.modulate = tint
		_cards[i].stripe.modulate = tint
		_cards[i].stamp.visible = cleared
	if _detail_index >= 0 and (state.sector.epoch != _detail_epoch or state.sector.is_cleared(_detail_index)):
		_show_fields()
	_hint.visible = state.sector.cc < state.cc_level()
	if state.sector.sector_seed != _layouts_seed or state.sector.epoch != _layouts_epoch:
		_layouts_seed = state.sector.sector_seed
		_layouts_epoch = state.sector.epoch
		for i: int in _layouts.size():
			_layouts[i] = {}
			_cards[i].thumbnail.show_field(_catalog, {})
	# The tasks start in the next frame, not in the one the map opens and is laid out in.
	set_process(not _jobs.is_empty() or (visible and _layouts.has({})))
	tick(state)


## The 1 s tick: Scan's countdown.
func tick(state: BaseState) -> void:
	var left := state.scan_seconds_left()
	if left == _scan_seconds:
		return
	_scan_seconds = left
	_scan_button.disabled = left > 0
	_scan_button.text = "SCAN" if left == 0 else "SCAN  %s" % Format.duration(left)


## Opens field `index`'s detail, laying the field out once: false, and nothing changes, for a
## field that is not open (cleared, or not a field).
func show_field(index: int) -> bool:
	if _state == null or index < 0 or index >= _cards.size() or _state.sector.is_cleared(index):
		return false
	if _layouts[index].is_empty():
		_lay_out_now(index)
	_field = _layouts[index]
	if _field.is_empty():
		return false
	_detail_index = index
	_detail_epoch = _state.sector.epoch
	var summary := OutpostGenerator.summary(_catalog, _state.sector, index)
	_fill(_detail_header, summary)
	_minimap.show_field(_catalog, _field)
	_detail_holds.text = _holds(_field)
	_grid.visible = false
	_scan_button.visible = false
	_detail.visible = true
	return true


## While the map is open with fields missing, or tasks run: the missing fields' tasks started, and
## one finished task a frame collected, its field kept and its card's thumbnail drawn when it is of
## the sector shown; it stops once none is left.
func _process(_delta: float) -> void:
	if visible and _state != null:
		_start_jobs()
	for i: int in _jobs.size():
		if WorkerThreadPool.is_task_completed(_jobs[i].task):
			_collect(i)
			break
	if _jobs.is_empty():
		set_process(false)


func _exit_tree() -> void:
	for i: int in range(_jobs.size() - 1, -1, -1):
		_collect(i)


## A task for every field of the sector shown that is not laid out and has no task running.
func _start_jobs() -> void:
	var sector := _state.sector
	for index: int in _layouts.size():
		if _layouts[index].is_empty() and _running(index) == -1:
			var job := LayoutJob.new()
			job.catalog = _catalog
			job.sector_seed = sector.sector_seed
			job.epoch = sector.epoch
			job.index = index
			job.cc = sector.cc
			job.capacity = sector.capacity.duplicate()
			job.task = WorkerThreadPool.add_task(job.run, false, "Lay out an expedition field")
			_jobs.append(job)


## The position in _jobs of field `index`'s task for the sector shown, -1 for none.
func _running(index: int) -> int:
	for i: int in _jobs.size():
		var job := _jobs[i]
		if job.index == index and job.sector_seed == _layouts_seed and job.epoch == _layouts_epoch:
			return i
	return -1


## Waits for task `i` of _jobs (at once when it has finished) and takes it out; its field is kept
## when it is of the sector shown and still missing.
func _collect(i: int) -> void:
	var job := _jobs[i]
	_jobs.remove_at(i)
	WorkerThreadPool.wait_for_task_completion(job.task)
	if job.sector_seed == _layouts_seed and job.epoch == _layouts_epoch and _layouts[job.index].is_empty():
		_layouts[job.index] = job.field
		_cards[job.index].thumbnail.show_field(_catalog, job.field)


## Field `index` now, for the detail: its task's result, waited for, or laid out here with none.
func _lay_out_now(index: int) -> void:
	var running := _running(index)
	if running >= 0:
		_collect(running)
		return
	_layouts[index] = OutpostGenerator.generate(_catalog, _state, index)
	_cards[index].thumbnail.show_field(_catalog, _layouts[index])


## What a field holds, for the detail: its defences, storages, deposits and walls (traps hidden).
func _holds(field: Dictionary) -> String:
	var defences := 0
	var storages := 0
	var walls := 0
	for entry: Variant in (field["defender"] as Dictionary)["buildings"]:
		var building: Dictionary = entry
		var type := str(building["type"])
		match _catalog.battle_class(type):
			Catalog.CLASS_DEFENSE:
				defences += 1
			Catalog.CLASS_WALL:
				walls += 1
			Catalog.CLASS_RESOURCE:
				var storage: Dictionary = _catalog.level_stats(type, int(building["level"])).get("storage", {})
				if not storage.is_empty():
					storages += 1
	return "%d defences   %d storages, %d of them loot deposits outside the walls   %d walls" % [defences,
		storages, (field["deposits"] as Array).size(), walls]


# --- Queries for the harness -----------------------------------------------------

func is_open() -> bool:
	return visible


## Whether a field's detail shows.
func is_detail_open() -> bool:
	return _detail_index >= 0


## The field the detail shows, -1 for none, and its layout.
func detail_index() -> int:
	return _detail_index


func detail_field() -> Dictionary:
	return _field


## Field `index`'s card.
func card(index: int) -> Button:
	return _cards[index].button


## Whether field `index`'s card shows the cleared stamp.
func card_cleared(index: int) -> bool:
	return _cards[index].stamp.visible


## A card's lines: its band, its outpost and its loot, as shown.
func card_lines(index: int) -> PackedStringArray:
	var card_shown := _cards[index]
	var lines := PackedStringArray([card_shown.band.text, card_shown.colony.text])
	for res: String in card_shown.loot:
		if card_shown.loot[res].visible:
			lines.append("%s %s" % [res, card_shown.loot[res].text])
	return lines


func scan_button() -> Button:
	return _scan_button


func close_button() -> Button:
	return _close_button


func attack_button() -> Button:
	return _attack_button


## Whether the hint to scan shows.
func hint_shown() -> bool:
	return _hint.visible


func minimap() -> Minimap:
	return _minimap


## Field `index`'s card thumbnail, and whether every field is laid out.
func card_thumbnail(index: int) -> Minimap:
	return _cards[index].thumbnail


func layouts_done() -> bool:
	return not _layouts.has({})


# --- Construction ----------------------------------------------------------------

func _show_fields() -> void:
	_detail_index = -1
	_detail_epoch = -1
	_field = {}
	_detail.visible = false
	_grid.visible = true
	_scan_button.visible = true


## A field card: the band's stripe along its top, the outpost's thumbnail, the band, the outpost,
## the loot row; the stamp at its top right, over the dimmed content.
func _build_card() -> FieldCard:
	var field_card := FieldCard.new()
	field_card.button = _button("", CARD_SIZE)
	field_card.button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	field_card.button.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 4)
	field_card.button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_top = Hud.BORDER + Hud.STRIPE_HEIGHT + 4
	content.offset_right = -14
	content.offset_bottom = -Hud.BORDER - 2
	var stripe := Panel.new()
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stripe.theme_type_variation = &"CardStripe"
	field_card.button.add_child(stripe)
	stripe.set_anchors_preset(Control.PRESET_TOP_WIDE)
	stripe.offset_left = Hud.BORDER
	stripe.offset_right = -Hud.BORDER
	stripe.offset_top = Hud.BORDER
	stripe.offset_bottom = Hud.BORDER + Hud.STRIPE_HEIGHT
	field_card.stripe = stripe
	field_card.content = content
	field_card.thumbnail = Minimap.new()
	field_card.thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	field_card.thumbnail.custom_minimum_size = THUMBNAIL_SIZE
	field_card.thumbnail.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	content.add_child(field_card.thumbnail)
	_fill_lines(field_card, content, BoxContainer.ALIGNMENT_CENTER)
	var stamp := Stamp.new()
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stamp.visible = false
	field_card.button.add_child(stamp)
	stamp.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	stamp.offset_left = -STAMP_SIZE.x - 10
	stamp.offset_right = -10
	stamp.offset_top = 14
	stamp.offset_bottom = 14 + STAMP_SIZE.y
	field_card.stamp = stamp
	return field_card


## The band, the outpost and the loot row under `parent`, aligned by `alignment`.
func _fill_lines(field_card: FieldCard, parent: Control, alignment: BoxContainer.AlignmentMode) -> void:
	var horizontal: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER if alignment == BoxContainer.ALIGNMENT_CENTER \
		else HORIZONTAL_ALIGNMENT_LEFT
	field_card.band = Label.new()
	field_card.band.theme_type_variation = &"InfoTitle"
	field_card.band.horizontal_alignment = horizontal
	parent.add_child(field_card.band)
	field_card.colony = Label.new()
	field_card.colony.theme_type_variation = &"InfoDetail"
	field_card.colony.horizontal_alignment = horizontal
	parent.add_child(field_card.colony)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.alignment = alignment
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	field_card.loot_row = row
	for res: String in _catalog.resources:
		var icon := HudIcon.new()
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon.kind = res
		icon.color = _resource_color(res)
		icon.custom_minimum_size = LOOT_ICON_SIZE
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(icon)
		var amount := Label.new()
		amount.theme_type_variation = &"CardCost"
		amount.add_theme_color_override("font_color", _resource_color(res))
		row.add_child(amount)
		field_card.loot_icons[res] = icon
		field_card.loot[res] = amount
	field_card.no_loot = Label.new()
	field_card.no_loot.theme_type_variation = &"CardCount"
	field_card.no_loot.text = "No loot"
	row.add_child(field_card.no_loot)


## The detail page: the minimap on the left; on the right the field's lines, the legend, Back and
## Attack.
func _build_detail(parent: Control) -> void:
	var page := HBoxContainer.new()
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 28)
	page.visible = false
	parent.add_child(page)
	_detail = page
	_detail_header = FieldCard.new()
	_minimap = Minimap.new()
	_minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_minimap.custom_minimum_size = MINIMAP_SIZE
	_minimap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	page.add_child(_minimap)
	_detail_header.thumbnail = _minimap
	var side := VBoxContainer.new()
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 10)
	page.add_child(side)
	_fill_lines(_detail_header, side, BoxContainer.ALIGNMENT_BEGIN)
	_detail_holds = Label.new()
	_detail_holds.theme_type_variation = &"InfoDetail"
	_detail_holds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_detail_holds)
	var legend := GridContainer.new()
	legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 10)
	legend.add_theme_constant_override("v_separation", 6)
	side.add_child(legend)
	for entry: Array in LEGEND:
		var swatch := Swatch.new()
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		swatch.color = entry[1]
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		legend.add_child(swatch)
		var word := Label.new()
		word.theme_type_variation = &"CardCount"
		word.text = entry[0]
		legend.add_child(word)
	var gap := Control.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(gap)
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.add_theme_constant_override("separation", 16)
	side.add_child(buttons)
	_back_button = _button("Back", BACK_SIZE, &"BarButton")
	_back_button.pressed.connect(_show_fields)
	buttons.add_child(_back_button)
	_attack_button = _button("ATTACK", ATTACK_SIZE, &"BuildButton")
	_attack_button.pressed.connect(func() -> void:
		if _detail_index >= 0:
			attack_pressed.emit(_detail_index, _field))
	buttons.add_child(_attack_button)


## A card's or the detail's lines from a field's summary (OutpostGenerator.summary, with or without
## "cleared").
func _fill(field_card: FieldCard, field: Dictionary) -> void:
	var band := str(field.get("band", ""))
	var color: Color = BAND_COLORS.get(band, Hud.ACCENT)
	field_card.band.text = band.to_upper()
	field_card.band.add_theme_color_override("font_color", color)
	if field_card.stripe != null:
		field_card.stripe.self_modulate = color
	field_card.thumbnail.show_band(band.to_upper(), color, int(_band_skulls.get(band, 0)), int(field.get("cc", 0)))
	field_card.colony.text = "Rival colony · CC %d" % int(field.get("cc", 0))
	var loot: Dictionary = field.get("loot", {})
	var any := false
	for res: String in field_card.loot:
		var amount := int(loot.get(res, 0))
		field_card.loot[res].visible = amount > 0
		field_card.loot_icons[res].visible = amount > 0
		field_card.loot[res].text = Format.amount(amount)
		any = any or amount > 0
	field_card.no_loot.visible = not any


func _button(text: String, min_size: Vector2, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


func _resource_color(res: String) -> Color:
	return Color.from_string(_catalog.resource_color(res), Hud.TEXT)


## The outpost of a field seen from above, drawn as the HUD's icons are (HudIcon.Pen), in one of two
## looks by its size, and built once per field (show_field) and drawn only then, on a resize and
## when its band changes: one triangle array. At a card's size (under BOLD_CELL pixels a cell) a
## scan plate: the field's ground in a frame of its band's colour, a faint ink grid over it and a
## vignette darkening it towards the rim; the walled compound as one polygon, the hull of the wall
## cells, in the walls' grey with an ink line; the Command Center a violet diamond in an ink ring,
## each defence a red disc, each storage (a deposit is one) a gold square, nothing else. Larger
## (the detail's), the chunky drawing: the ground a rounded square with an ink outline and a flat
## shadow, each building a flat fill in its role's colour with an ink outline and a shadow, walls a
## plain fill, traps not at all (they are hidden). Over either, once the band is shown (show_band),
## the band's word on a ribbon of its colour across the top-left corner with a skull per step of
## difficulty on it, and the outpost's Command Center level as a chip at the top-right. An empty
## field ({}) draws the ground alone.
class Minimap:
	extends Control

	## The cells of margin round the field, and how far a building's and a wall's fill stand in from
	## their footprint's edge, in cells.
	const PAD := 1.0
	const INSET := 0.14
	const WALL_INSET := 0.06
	const BOLD_CELL := 6.0
	## The plate, in pixels: its ink edge and the band's frame inside it, its corners and its shadow; the grid's lines each way and
	## their ink; the vignette's steps, each a disc of the half side's share and how much darker
	## than the ground it is, the outermost first, over the corners darker still (PLATE_RIM).
	const EDGE := 2.0
	const FRAME := 4.0
	const PLATE_RADIUS := 10.0
	const PLATE_SHADOW := Vector2(4, 4)
	const GRID_LINES := 6
	const GRID_INK := Color(Hud.INK, 0.1)
	const PLATE_RIM := 0.32
	const VIGNETTE := [[1.0, 0.2], [0.8, 0.1], [0.6, 0.0]]
	## The compound's fill and line, and the marks' sizes.
	const HULL_FILL := Color(WALL_COLOR, 0.4)
	const HULL_LINE := 2.0
	const HQ_MARK := 16.0
	const HQ_RING := 2.0
	const DEFENCE_MARK := 6.0
	const STORAGE_MARK := 7.0
	## The ribbon: its top, how far it reaches out past the left edge, the room round its word, the
	## notch cut into its right end; its skulls' size and step; the chip's corner.
	const RIBBON_TOP := 6.0
	const RIBBON_OUT := 6.0
	const RIBBON_PAD := Vector2(8, 0)
	const RIBBON_NOTCH := 7.0
	const SKULL := 20.0
	const SKULL_STEP := 17.0
	const CHIP_CORNER := Vector2(6, -6)

	enum Role { HQ, DEFENCE, STORAGE, OTHER }

	## Per building drawn: its footprint in cells (x, y, size) and its role; walls apart, drawn
	## first, without outlines, and the hull of their cells.
	var _rects: Array[Rect2] = []
	var _roles: PackedInt32Array = PackedInt32Array()
	var _walls: Array[Rect2] = []
	var _hull: PackedVector2Array = PackedVector2Array()
	var _grid: Vector2i = Vector2i(48, 48)
	## The band: its colour, its skulls, its word on the ribbon and the Command Center on the chip.
	var _band_color: Color = Hud.ACCENT
	var _skulls: int = 0
	var _ribbon: Label
	var _chip: Label

	func _init() -> void:
		_ribbon = Label.new()
		_ribbon.theme_type_variation = &"SectorRibbon"
		_ribbon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ribbon.position = Vector2(RIBBON_PAD.x - RIBBON_OUT, RIBBON_TOP + RIBBON_PAD.y)
		_ribbon.visible = false
		_ribbon.resized.connect(queue_redraw)
		add_child(_ribbon)
		_chip = Label.new()
		_chip.theme_type_variation = &"CardChip"
		_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_chip.visible = false
		add_child(_chip)
		_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		_chip.offset_right = CHIP_CORNER.x - Hud.CHIP_PAD.x
		_chip.offset_top = CHIP_CORNER.y + Hud.CHIP_PAD.y
		_chip.resized.connect(queue_redraw)

	## Lays out `field` (OutpostGenerator.generate) for drawing.
	func show_field(catalog: Catalog, field: Dictionary) -> void:
		_grid = catalog.grid_size
		_rects.clear()
		_roles.clear()
		_walls.clear()
		var corners := PackedVector2Array()
		var defender: Dictionary = field.get("defender", {})
		for entry: Variant in defender.get("buildings", []):
			var building: Dictionary = entry
			var type := str(building["type"])
			var cell: Array = building["cell"]
			var size := catalog.size_of(type)
			var rect := Rect2(float(cell[0]), float(cell[1]), size, size)
			match catalog.battle_class(type):
				Catalog.CLASS_TRAP:
					continue
				Catalog.CLASS_WALL:
					_walls.append(rect)
					corners.append_array(PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y),
						rect.end, Vector2(rect.position.x, rect.end.y)]))
					continue
				Catalog.CLASS_HQ:
					_roles.append(Role.HQ)
				Catalog.CLASS_DEFENSE:
					_roles.append(Role.DEFENCE)
				Catalog.CLASS_RESOURCE:
					# A storage, as the generator's role has it; a deposit is one. A collector is
					# the rest.
					var storage: Dictionary = catalog.level_stats(type, int(building["level"])).get("storage", {})
					_roles.append(Role.STORAGE if not storage.is_empty() else Role.OTHER)
				_:
					_roles.append(Role.OTHER)
			_rects.append(rect)
		_hull = Geometry2D.convex_hull(corners) if corners.size() >= 3 else PackedVector2Array()
		# The hull comes back closed, its first point again at its end.
		if _hull.size() > 1 and _hull[0] == _hull[_hull.size() - 1]:
			_hull.remove_at(_hull.size() - 1)
		queue_redraw()

	## Shows the band: `word` on the ribbon in `color`, `skulls` skulls on it, and Command Center
	## `cc` on the chip.
	func show_band(word: String, color: Color, skulls: int, cc: int) -> void:
		_ribbon.text = word
		_ribbon.visible = word != ""
		_chip.text = "CC %d" % cc
		_chip.visible = cc > 0
		if color != _band_color or skulls != _skulls:
			_band_color = color
			_skulls = skulls
			queue_redraw()

	## The band's word on the ribbon.
	func band_text() -> String:
		return _ribbon.text

	## The buildings laid out for drawing (walls and traps not counted; the plate shows the
	## Command Center, the defences and the storages of them), and the walls.
	func drawn() -> int:
		return _rects.size()

	func walls_drawn() -> int:
		return _walls.size()

	func _draw() -> void:
		var pen := HudIcon.Pen.new()
		if size.x / (maxf(_grid.x, _grid.y) + 2.0 * PAD) < BOLD_CELL:
			_draw_plate(pen)
		else:
			_draw_chunky(pen)
		_draw_band(pen)
		pen.draw(self)

	## The scan plate, in pixels.
	func _draw_plate(pen: HudIcon.Pen) -> void:
		var plate := Rect2(Vector2.ZERO, size)
		var outer := Hud._round_rect(plate, Vector2.ONE * PLATE_RADIUS, false)
		pen.add_fill(_moved(outer, PLATE_SHADOW), Hud.SHADOW, true)
		pen.add_fill(outer, _band_color, false)
		var inner := plate.grow(-EDGE - FRAME)
		var ground := Hud._round_rect(inner, Vector2.ONE * (PLATE_RADIUS - EDGE - FRAME), false)
		pen.add_fill(ground, GROUND_COLOR.darkened(PLATE_RIM), false)
		var centre := inner.get_center()
		var half := minf(inner.size.x, inner.size.y) / 2.0
		for step: Array in VIGNETTE:
			var share: float = step[0]
			var dark: float = step[1]
			pen.add_fill(Hud._circle(centre, half * share, 48), GROUND_COLOR.darkened(dark), true)
		for i: int in range(1, GRID_LINES):
			var x := inner.position.x + inner.size.x * i / GRID_LINES
			var y := inner.position.y + inner.size.y * i / GRID_LINES
			pen.add_stroke(PackedVector2Array([Vector2(x, inner.position.y), Vector2(x, inner.end.y)]), 1.0, GRID_INK, false)
			pen.add_stroke(PackedVector2Array([Vector2(inner.position.x, y), Vector2(inner.end.x, y)]), 1.0, GRID_INK, false)
		var cell := inner.size / Vector2(_grid)
		if _hull.size() >= 3:
			var hull := PackedVector2Array()
			for point: Vector2 in _hull:
				hull.append(inner.position + point * cell)
			pen.add_fill(hull, HULL_FILL, false)
			pen.add_stroke(hull, HULL_LINE, Hud.INK, true)
		# The defences under the storages, the Command Center over both.
		for role: int in [Role.DEFENCE, Role.STORAGE, Role.HQ]:
			for i: int in _rects.size():
				if _roles[i] != role:
					continue
				var at := inner.position + _rects[i].get_center() * cell
				match role:
					Role.DEFENCE:
						pen.add_fill(Hud._circle(at, DEFENCE_MARK / 2.0, 10), DEFENCE_COLOR, true)
					Role.STORAGE:
						var side := STORAGE_MARK / 2.0
						pen.add_fill(PackedVector2Array([at + Vector2(-side, -side), at + Vector2(side, -side),
							at + Vector2(side, side), at + Vector2(-side, side)]), STORAGE_COLOR, true)
					Role.HQ:
						var reach := HQ_MARK / 2.0
						var diamond := PackedVector2Array([at + Vector2(0, -reach), at + Vector2(reach, 0),
							at + Vector2(0, reach), at + Vector2(-reach, 0)])
						pen.add_fill(diamond, HQ_COLOR, false)
						pen.add_stroke(diamond, HQ_RING, Hud.INK, true)
		pen.add_stroke(Hud._round_rect(inner, Vector2.ONE * (PLATE_RADIUS - EDGE - FRAME), false), 1.5, Hud.INK, true)
		pen.add_stroke(Hud._round_rect(plate.grow(-EDGE / 2.0), Vector2.ONE * (PLATE_RADIUS - EDGE / 2.0), false), EDGE,
			Hud.INK, true)

	## The chunky drawing, in the 40-unit box fitted to the control.
	func _draw_chunky(pen: HudIcon.Pen) -> void:
		pen.fit(Rect2(Vector2.ZERO, size))
		var unit := HudIcon.BOX / (maxf(_grid.x, _grid.y) + 2.0 * PAD)
		var ground := _corners(Rect2(Vector2.ZERO, Vector2.ONE * HudIcon.BOX), 1.2)
		for shadow: bool in [true, false]:
			pen.shadow = shadow
			pen.shape(ground, GROUND_COLOR)
			pen.outline(ground)
		pen.shadow = false
		for rect: Rect2 in _walls:
			pen.facet(_square(rect, WALL_INSET, unit), WALL_COLOR)
		for shadow: bool in [true, false]:
			pen.shadow = shadow
			for i: int in _rects.size():
				var points := _square(_rects[i], INSET, unit)
				pen.shape(points, _role_color(_roles[i]))
				pen.outline(points)
		pen.shadow = false

	## The ribbon with its skulls, and the chip, in pixels, over either drawing.
	func _draw_band(pen: HudIcon.Pen) -> void:
		if _ribbon.visible:
			var word := Rect2(_ribbon.position, _ribbon.size)
			var top := word.position.y - RIBBON_PAD.y
			var bottom := word.end.y + RIBBON_PAD.y
			var left := -RIBBON_OUT
			var right := word.end.x + RIBBON_PAD.x + _skulls * SKULL_STEP
			var middle := (top + bottom) / 2.0
			var ribbon := PackedVector2Array([Vector2(left, top), Vector2(right + RIBBON_NOTCH, top),
				Vector2(right, middle), Vector2(right + RIBBON_NOTCH, bottom), Vector2(left, bottom)])
			# Its end folded round the plate's left edge.
			var fold := PackedVector2Array([Vector2(left, bottom), Vector2(0, bottom), Vector2(0, bottom + RIBBON_OUT)])
			pen.add_fill(_moved(ribbon, PLATE_SHADOW / 2.0), Hud.SHADOW, true)
			pen.add_fill(fold, _band_color.darkened(0.45), false)
			pen.add_stroke(fold, 2.0, Hud.INK, true)
			pen.add_fill(ribbon, _band_color, false)
			pen.add_stroke(ribbon, 2.0, Hud.INK, true)
			for k: int in _skulls:
				var x := word.end.x + RIBBON_PAD.x / 2.0 + k * SKULL_STEP - (SKULL - SKULL_STEP) / 2.0
				HudIcon.paint(pen, "skull", Rect2(Vector2(x, middle - SKULL / 2.0), Vector2.ONE * SKULL), Hud.TEXT)
		if _chip.visible:
			var rect := Rect2(_chip.position, _chip.size).grow_individual(Hud.CHIP_PAD.x, Hud.CHIP_PAD.y,
				Hud.CHIP_PAD.x, Hud.CHIP_PAD.y)
			var radius := Vector2.ONE * rect.size.y / 2.0
			var fill := Hud.CREAM_DISABLED if Hud.skin == Hud.Look.C else Hud.CARD_DISABLED
			var pill := Hud._round_rect(rect, radius, false)
			pen.add_fill(_moved(pill, PLATE_SHADOW / 2.0), Hud.SHADOW, true)
			pen.add_fill(pill, fill, false)
			pen.add_stroke(Hud._round_rect(rect.grow(-Hud.CHIP_RING / 2.0), radius - Vector2.ONE * Hud.CHIP_RING / 2.0,
				false), Hud.CHIP_RING, Hud.INK, true)

	static func _role_color(role: int) -> Color:
		match role:
			Role.HQ:
				return HQ_COLOR
			Role.DEFENCE:
				return DEFENCE_COLOR
			Role.STORAGE:
				return STORAGE_COLOR
		return OTHER_COLOR

	## `points` moved by `by`.
	static func _moved(points: PackedVector2Array, by: Vector2) -> PackedVector2Array:
		var moved := PackedVector2Array()
		for point: Vector2 in points:
			moved.append(point + by)
		return moved

	## A footprint in box units, `inset` cells in from each side.
	static func _square(rect: Rect2, inset: float, unit: float) -> PackedVector2Array:
		var from := (rect.position + Vector2.ONE * (PAD + inset)) * unit
		var to := (rect.end + Vector2.ONE * (PAD - inset)) * unit
		return PackedVector2Array([from, Vector2(to.x, from.y), to, Vector2(from.x, to.y)])

	## A rect with its corners cut at `cut` box units: the ground's rounded look at this scale.
	static func _corners(rect: Rect2, cut: float) -> PackedVector2Array:
		var a := rect.position
		var b := rect.end
		return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(b.x - cut, a.y), Vector2(b.x, a.y + cut),
			Vector2(b.x, b.y - cut), Vector2(b.x - cut, b.y), Vector2(a.x + cut, b.y), Vector2(a.x, b.y - cut),
			Vector2(a.x, a.y + cut)])


## A legend's swatch: a flat fill with an ink outline and a shadow, as the minimap's buildings.
class Swatch:
	extends Control

	var color: Color = Color.WHITE

	func _draw() -> void:
		var pen := HudIcon.Pen.new()
		pen.fit(Rect2(Vector2.ZERO, size))
		var square := PackedVector2Array([Vector2(4, 4), Vector2(36, 4), Vector2(36, 36), Vector2(4, 36)])
		for shadow: bool in [true, false]:
			pen.shadow = shadow
			pen.shape(square, color)
			pen.outline(square)
		pen.shadow = false
		pen.draw(self)


## The cleared stamp: a gold star, tilted, with a lighter facet, an ink outline and a shadow, in the
## HUD's icon style.
class Stamp:
	extends Control

	const TILT := -0.2

	func _draw() -> void:
		var pen := HudIcon.Pen.new()
		pen.fit(Rect2(Vector2.ZERO, size))
		var star := PackedVector2Array()
		for i: int in 10:
			var angle := TILT - PI / 2.0 + i * PI / 5.0
			var reach := 18.0 if i % 2 == 0 else 7.5
			star.append(Vector2(20, 21) + Vector2(cos(angle), sin(angle)) * reach)
		for shadow: bool in [true, false]:
			pen.shadow = shadow
			pen.shape(star, Hud.GOLD)
			pen.facet(PackedVector2Array([star[9], star[0], star[1], Vector2(20, 21)]), Hud.GOLD.lightened(0.45))
			pen.outline(star)
		pen.shadow = false
		pen.draw(self)
