class_name Hud
extends CanvasLayer
## On-screen UI, built in code. Reads BaseState for display and reports presses as
## signals; it never changes game state itself.
##
## Touch rule: any Control that isn't IGNORE swallows touches over it, so layout-only
## containers that span empty screen space must use MOUSE_FILTER_IGNORE or the world
## underneath stops responding.

signal build_pressed(type: String)
signal confirm_pressed
signal cancel_pressed
signal upgrade_pressed
signal close_pressed
signal reset_pressed

const ERROR_TEXT := {
	BaseState.ERR_BLOCKED: "That spot is taken",
	BaseState.ERR_LIMIT: "You've built the maximum for your Command Center level",
	BaseState.ERR_CC_LEVEL: "Upgrade your Command Center first",
	BaseState.ERR_NO_BUILDER: "All drones are busy",
	BaseState.ERR_FUNDS: "Not enough resources",
	BaseState.ERR_BUSY: "Already under construction",
	BaseState.ERR_MAX_LEVEL: "Already at max level",
}
const TEXT_COLOR := Color("e9f6ff")
const ACCENT := Color("4fd6e6")
const PANEL_COLOR := Color(0.07, 0.08, 0.14, 0.88)
const MARGIN := 16
const TAB_SIZE := Vector2(140, 48)
const ENTRY_SIZE := Vector2(224, 96)

var _catalog: Catalog
var _root: Control
var _resource_labels: Dictionary[String, Label] = {}
var _builders_label: Label
var _build_bar: Control
var _tab_buttons: Dictionary[String, Button] = {}
var _entry_scroll: ScrollContainer
var _entries: Dictionary[String, Button] = {}
## Each entry's third line: built/max, or why it cannot be built.
var _entry_status: Dictionary[String, Label] = {}
## The selected build-menu category. Remembered while the game runs, not saved.
var _tab: String = ""
## The state of the last refresh, so a tab change can fill its entries.
var _state: BaseState
var _place_bar: Control
var _place_button: Button
var _info_panel: Control
var _info_title: Label
var _info_detail: Label
var _upgrade_button: Button
var _upgrade_note: Label
var _toast: Label
var _toast_tween: Tween


func setup(catalog: Catalog) -> void:
	_catalog = catalog
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = _make_theme()
	add_child(_root)
	_build_top_bar()
	_build_build_bar()
	_build_place_bar()
	_build_info_panel()
	_build_toast()
	if OS.is_debug_build():
		_build_debug_buttons()


func refresh(state: BaseState, selected_id: int, placing: bool, ghost_ok: bool) -> void:
	_state = state
	for res: String in _resource_labels:
		var rate := state.production_per_hour(res)
		var rate_text := "   +%s/h" % Format.amount(rate) if rate > 0 else ""
		_resource_labels[res].text = "%s  %s / %s%s" % [
			_catalog.resource_name(res),
			Format.amount(state.resources[res]),
			Format.amount(state.capacity(res)),
			rate_text,
		]
	_builders_label.text = "Drones  %d / %d" % [state.builders_free(), state.builders_total()]

	var has_selection := selected_id != 0 and state.buildings.has(selected_id)
	_build_bar.visible = not placing and not has_selection
	_place_bar.visible = placing
	_place_button.disabled = not ghost_ok
	_info_panel.visible = not placing and has_selection
	if _build_bar.visible:
		_refresh_entries(state)
	if _info_panel.visible:
		_refresh_info(state, state.buildings[selected_id])


func show_message(text: String) -> void:
	_toast.text = text
	_toast.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6).set_delay(1.8)


func show_error(code: String) -> void:
	show_message(error_text(code))


static func error_text(code: String) -> String:
	return str(ERROR_TEXT.get(code, code))


# --- Refresh helpers -------------------------------------------------------------

## Only the selected tab's entries; the others are hidden.
func _refresh_entries(state: BaseState) -> void:
	for type: String in _entries:
		if _catalog.category_of(type) != _tab:
			continue
		var button: Button = _entries[type]
		var error := state.check_can_build(type)
		var status: Label = _entry_status[type]
		status.text = _entry_status_text(state, type, error)
		button.disabled = error != ""
		var content: Control = status.get_parent()
		content.modulate.a = 1.0 if error == "" else 0.45


func _entry_status_text(state: BaseState, type: String, error: String) -> String:
	if error == "":
		return "%d/%d" % [state.count_of(type), _catalog.max_count(type, state.cc_level())]
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


func _select_tab(category: String) -> void:
	_tab = category
	_tab_buttons[category].button_pressed = true
	for type: String in _entries:
		_entries[type].visible = _catalog.category_of(type) == category
	_entry_scroll.scroll_horizontal = 0
	if _state != null and _build_bar.visible:
		_refresh_entries(_state)


func _refresh_info(state: BaseState, building: BuildingState) -> void:
	var type := building.type
	_info_title.text = "%s   Lv %d" % [_catalog.display_name(type), building.level]

	var lines := PackedStringArray()
	var stats := _catalog.level_stats(type, maxi(building.level, 1))
	var production: Dictionary = stats.get("produces", {})
	var storage: Dictionary = stats.get("storage", {})
	for res: String in _catalog.resources:
		var produces := int(production.get(res, 0))
		if produces > 0:
			lines.append("Produces %s %s/h" % [Format.amount(produces), _catalog.resource_name(res)])
		var stores := int(storage.get(res, 0))
		if stores > 0:
			lines.append("Stores %s %s" % [Format.amount(stores), _catalog.resource_name(res)])
	if int(stats.get("builders", 0)) > 0:
		lines.append("Houses %d drone" % int(stats["builders"]))
	if stats.has("damage"):
		lines.append("Damage %d   Range %d" % [int(stats["damage"]), int(stats.get("range_cells", 0))])
	if stats.has("hp"):
		lines.append("Hull %s" % Format.amount(int(stats["hp"])))
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
	var next := _catalog.level_stats(type, building.level + 1)
	_upgrade_button.text = "Upgrade to Lv %d   %s   (%s)" % [
		building.level + 1,
		Format.cost(next.get("cost", {}), _catalog),
		Format.duration(int(next.get("build_seconds", 0))),
	]
	var error := state.check_upgrade(building.id)
	_upgrade_button.disabled = error != ""
	_upgrade_note.text = "" if error == "" else error_text(error)


# --- Construction ----------------------------------------------------------------

func _build_top_bar() -> void:
	var bar := HBoxContainer.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_constant_override("separation", 10)
	bar.position = Vector2(MARGIN, MARGIN)
	_root.add_child(bar)
	for res: String in _catalog.resources:
		var label := _panel_label(bar)
		label.add_theme_color_override("font_color", Color.from_string(_catalog.resource_color(res), TEXT_COLOR))
		_resource_labels[res] = label
	_builders_label = _panel_label(bar)
	_builders_label.add_theme_color_override("font_color", ACCENT)


## A row of category tabs over a horizontal strip of entries. Every menu type gets an
## entry up front; a tab shows its category's entries, in menu_order order.
func _build_build_bar() -> void:
	var panel := PanelContainer.new()
	_root.add_child(panel)
	_anchor_bottom(panel, true)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	column.add_child(tabs)
	var group := ButtonGroup.new()
	for category: String in _catalog.categories:
		var tab := _button(_catalog.category_name(category), TAB_SIZE)
		tab.toggle_mode = true
		tab.button_group = group
		tab.pressed.connect(func() -> void: _select_tab(category))
		tabs.add_child(tab)
		_tab_buttons[category] = tab
	_entry_scroll = ScrollContainer.new()
	_entry_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_entry_scroll.custom_minimum_size = Vector2(0, ENTRY_SIZE.y + 8)
	column.add_child(_entry_scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_entry_scroll.add_child(row)
	for type: String in _catalog.menu_order:
		row.add_child(_build_entry(type))
	_build_bar = panel
	_select_tab(_catalog.categories[0])


## Three lines: the name, the level 1 cost (each amount in its resource's colour), and
## the status line `_refresh_entries` fills.
func _build_entry(type: String) -> Button:
	var button := _button("", ENTRY_SIZE)
	# PASS, so a drag that starts on an entry reaches the ScrollContainer and scrolls the
	# strip; the panel behind still stops the touch from reaching the world.
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(func() -> void: build_pressed.emit(type))
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 8
	content.offset_top = 8
	content.offset_right = -8
	content.offset_bottom = -8
	var name_label := _entry_label(content, _catalog.display_name(type), 18, TEXT_COLOR)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var cost_row := HBoxContainer.new()
	cost_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_row.alignment = BoxContainer.ALIGNMENT_CENTER
	cost_row.add_theme_constant_override("separation", 12)
	content.add_child(cost_row)
	var cost: Dictionary = _catalog.level_stats(type, 1).get("cost", {})
	if cost.is_empty():
		_entry_label(cost_row, "Free", 16, TEXT_COLOR)
	for res: Variant in cost:
		var color := Color.from_string(_catalog.resource_color(str(res)), TEXT_COLOR)
		_entry_label(cost_row, Format.amount(int(cost[res])), 16, color)
	var status := _entry_label(content, "", 16, TEXT_COLOR)
	status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_entry_status[type] = status
	_entries[type] = button
	return button


func _build_place_bar() -> void:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	_root.add_child(row)
	_anchor_bottom(row, false)
	var cancel := _button("Cancel", Vector2(170, 72))
	cancel.pressed.connect(func() -> void: cancel_pressed.emit())
	row.add_child(cancel)
	_place_button = _button("Place", Vector2(170, 72))
	_place_button.pressed.connect(func() -> void: confirm_pressed.emit())
	row.add_child(_place_button)
	_place_bar = row


func _build_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(460, 0)
	_root.add_child(panel)
	_anchor_bottom(panel, false)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	_info_title = Label.new()
	_info_title.add_theme_font_size_override("font_size", 26)
	_info_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_info_title)
	var close := _button("Close", Vector2(96, 44))
	close.pressed.connect(func() -> void: close_pressed.emit())
	header.add_child(close)

	_info_detail = Label.new()
	column.add_child(_info_detail)
	_upgrade_button = _button("", Vector2(0, 64))
	_upgrade_button.pressed.connect(func() -> void: upgrade_pressed.emit())
	column.add_child(_upgrade_button)
	_upgrade_note = Label.new()
	_upgrade_note.add_theme_color_override("font_color", Color("ffb37a"))
	column.add_child(_upgrade_note)
	_info_panel = panel


func _build_toast() -> void:
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 26)
	_toast.add_theme_color_override("font_outline_color", Color.BLACK)
	_toast.add_theme_constant_override("outline_size", 8)
	_toast.modulate.a = 0.0
	_root.add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_left = 0
	_toast.offset_right = 0
	_toast.offset_top = 96
	_toast.offset_bottom = 96


## Debug builds only: start over without digging through user:// for the save file.
func _build_debug_buttons() -> void:
	var reset := _button("Reset base", Vector2(150, 48))
	reset.pressed.connect(func() -> void: reset_pressed.emit())
	_root.add_child(reset)
	reset.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	reset.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	reset.offset_left = -MARGIN
	reset.offset_right = -MARGIN
	reset.offset_top = MARGIN
	reset.offset_bottom = MARGIN


func _panel_label(parent: Control) -> Label:
	var panel := PanelContainer.new()
	parent.add_child(panel)
	var label := Label.new()
	panel.add_child(label)
	return label


func _entry_label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(text: String, min_size: Vector2) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


## Pins a control to the bottom edge; it grows upward to fit its content.
func _anchor_bottom(control: Control, full_width: bool) -> void:
	if full_width:
		control.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		control.offset_left = MARGIN
		control.offset_right = -MARGIN
	else:
		control.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
		control.grow_horizontal = Control.GROW_DIRECTION_BOTH
		control.offset_left = 0
		control.offset_right = 0
	control.grow_vertical = Control.GROW_DIRECTION_BEGIN
	control.offset_top = -MARGIN
	control.offset_bottom = -MARGIN


func _make_theme() -> Theme:
	var ui := Theme.new()
	ui.default_font_size = 20
	ui.set_stylebox("panel", "PanelContainer", _style(PANEL_COLOR, Color(0, 0, 0, 0)))
	ui.set_stylebox("normal", "Button", _style(Color(0.13, 0.15, 0.26, 0.95), ACCENT.darkened(0.55)))
	ui.set_stylebox("hover", "Button", _style(Color(0.17, 0.2, 0.34, 0.95), ACCENT.darkened(0.2)))
	ui.set_stylebox("pressed", "Button", _style(Color(0.08, 0.3, 0.36, 0.95), ACCENT))
	ui.set_stylebox("disabled", "Button", _style(Color(0.09, 0.09, 0.13, 0.85), Color(0, 0, 0, 0)))
	ui.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	ui.set_color("font_color", "Button", TEXT_COLOR)
	ui.set_color("font_hover_color", "Button", TEXT_COLOR)
	ui.set_color("font_pressed_color", "Button", TEXT_COLOR)
	ui.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	ui.set_color("font_color", "Label", TEXT_COLOR)
	return ui


static func _style(fill: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_corner_radius_all(12)
	box.set_content_margin_all(12.0)
	if border.a > 0.0:
		box.border_color = border
		box.set_border_width_all(2)
	return box
