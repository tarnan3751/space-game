class_name BattleHud
extends CanvasLayer
## The attack HUD (docs/reference/hud.md, **Battle HUD**; docs/reference/battle-view.md), built in
## code in the base HUD's theme (Hud.ui_theme): it reads the battle (BattleView and its sim) and
## reports presses to the view; it never changes the sim itself.
##
## - Top left, a panel: the time left (seconds_left), the destruction and the three stars, each
##   lit as it is won.
## - Top right: the speed button (1x, 2x: BattleView.speed) and End, which asks before it
##   surrenders; under them, the loot taken so far per resource, each with its icon.
## - Along the bottom, the deploy bar: a card per unit type the attacker brought, its picture
##   (ModelPreview, the unit at the attacker's level's tier), its name and how many are left; a
##   press selects it (BattleView.select_unit) or, pressed again, lets it go. The first type is
##   selected at the start; a type that runs out is let go and its card dimmed.
## - When the battle ends, the result panel: the stars, the destruction, the loot per resource, the
##   units deployed by type, and Return, which leaves the battle (BattleView.leave).
## - A toast for a refused deploy.
##
## Everything sits inside the device's safe area (Hud.safe_area), the deploy bar with a column kept
## clear at its right where the base's Build button stands. Layout containers take no touch, so
## the field under them gets it; the panels and buttons take theirs. Text is set only when what it
## shows changed, on the view's `stepped`.

## A deploy card and its picture; a star in the top panel and on the result panel; a deployed
## unit's picture there.
const CARD_SIZE := Vector2(124, 136)
const PICTURE_SIZE := Vector2(64, 64)
const STAR_SIZE := Vector2(30, 30)
const RESULT_STAR_SIZE := Vector2(64, 64)
const RESULT_PICTURE_SIZE := Vector2(48, 48)
const ICON_SIZE := Vector2(28, 28)
const CARD_GAP := 10
## Between the deploy bar and the abilities bar.
const BAR_GAP := 16
## The dim behind the End confirmation, which takes every touch while it is open.
const BACKDROP := Color(0.106, 0.102, 0.18, 0.35)
const SPEED_SIZE := Vector2(88, 52)
const END_SIZE := Vector2(120, 52)
## The refused deploys' toasts. A card run out is let go on the next refresh, so a tap never meets
## `none_left`; a smear can, when a frame steps several ticks and the type runs out between two
## of them, before the refresh: that is the toast it keeps.
const CAST_TEXT := {
	BattleSim.ERR_BLOCKED: "Can't cast there",
	BattleSim.ERR_NONE_LEFT: "None of those left",
}
const DEPLOY_TEXT := {
	BattleSim.ERR_BLOCKED: "Can't deploy there",
	BattleSim.ERR_NONE_LEFT: "None of those left",
}

var _view: BattleView
var _catalog: Catalog
var _preview: ModelPreview
var _root: Control
var _fitted: Rect2 = Rect2()
var _timer: Label
var _destruction: Label
var _stars: Array[Star] = []
var _loot: Dictionary[String, Label] = {}
var _speed_button: Button
var _end_button: Button
var _bar: PanelContainer
var _scroll: ScrollContainer
## The cards' row's width, which the bar shrinks to, up to the room left of the Build column.
var _cards_width: float = 0.0
var _cards: Dictionary[String, Button] = {}
var _counts: Dictionary[String, Label] = {}
var _pictures: Dictionary[String, TextureRect] = {}
## Each type's picture key (ModelPreview.unit_key).
var _keys: Dictionary[String, String] = {}
var _ability_bar: PanelContainer
var _ability_cards: Dictionary[String, Button] = {}
var _ability_counts: Dictionary[String, Label] = {}
var _shown_uses: Dictionary[String, int] = {}
## The abilities bar's row width, and the gap between it and the deploy bar.
var _abilities_width: float = 0.0
var _confirm: PanelContainer
var _confirm_backdrop: ColorRect
var _keep_button: Button
var _confirm_end_button: Button
var _result: PanelContainer
var _result_title: Label
var _result_stars: Array[Star] = []
var _result_lines: VBoxContainer
var _return_button: Button
var _toast: PanelContainer
var _toast_label: Label
var _toast_tween: Tween
## What the top bar shows now, so text changes only when it does.
var _shown_seconds: int = -1
var _shown_pct: int = -1
var _shown_stars: int = -1
var _shown_loot: Dictionary[String, int] = {}
var _shown_falls: int = -1
var _shown_left: Dictionary[String, int] = {}


## A star drawn in code: a five-pointed fill, gold when lit and the card's violet when not, in an
## ink outline over an offset ink shadow, as the HUD's icons are.
class Star:
	extends Control
	var lit: bool = false:
		set(value):
			if value != lit:
				lit = value
				queue_redraw()

	func _draw() -> void:
		var centre := size * 0.5
		var outer := minf(size.x, size.y) * 0.5 - 3.0
		var points := PackedVector2Array()
		for k: int in 10:
			var radius := outer if k % 2 == 0 else outer * 0.45
			var angle := -PI * 0.5 + PI * k / 5.0
			points.append(centre + Vector2(cos(angle), sin(angle)) * radius)
		var shadow := PackedVector2Array()
		for point: Vector2 in points:
			shadow.append(point + Vector2(2, 2))
		draw_colored_polygon(shadow, Hud.SHADOW)
		draw_colored_polygon(points, Hud.GOLD if lit else Hud.CARD_DISABLED)
		points.append(points[0])
		draw_polyline(points, Hud.INK, 2.5, true)


## Call once, before adding to the tree: the HUD of `view`'s battle on `catalog`, in `theme` (the
## base HUD's), its pictures from `preview` (the base HUD's ModelPreview).
func setup(catalog: Catalog, theme: Theme, preview: ModelPreview, view: BattleView) -> void:
	_catalog = catalog
	_preview = preview
	_view = view
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = theme
	add_child(_root)
	_build_top()
	_build_deploy_bar()
	_build_confirm()
	_build_result()
	_build_toast()
	view.stepped.connect(_refresh)
	view.ended.connect(_show_result)
	view.deploy_failed.connect(_on_deploy_failed)
	view.cast_failed.connect(_on_cast_failed)
	preview.rendered.connect(_on_rendered)
	var keys := PackedStringArray()
	for unit: String in _keys:
		keys.append(_keys[unit])
	preview.request(keys)
	preview.run(true)
	for unit: String in _keys:
		_pictures[unit].texture = preview.texture_of(_keys[unit])
	var first := view.units_brought()
	_select(first[0] if not first.is_empty() else "")
	_refresh()


func _ready() -> void:
	get_viewport().size_changed.connect(_fit)
	_fit()


# --- Queries for the harness ------------------------------------------------------

func card(unit: String) -> Button:
	return _cards[unit]


## An ability's card on the abilities bar, and its count left.
func ability_card(ability: String) -> Button:
	return _ability_cards[ability]


func ability_count(ability: String) -> String:
	return _ability_counts[ability].text


## A deploy card's count left.
func card_count(unit: String) -> String:
	return _counts[unit].text


## A deploy card's picture, null until rendered (always, headless).
func card_picture(unit: String) -> Texture2D:
	return _pictures[unit].texture


func timer_text() -> String:
	return _timer.text


func destruction_text() -> String:
	return _destruction.text


## Stars lit in the top panel.
func stars_lit() -> int:
	var lit := 0
	for star: Star in _stars:
		lit += 1 if star.lit else 0
	return lit


func loot_text(res: String) -> String:
	return _loot[res].text


func speed_button() -> Button:
	return _speed_button


func end_button() -> Button:
	return _end_button


func is_confirm_open() -> bool:
	return _confirm_backdrop.visible


## The confirmation's End battle and Keep fighting.
func confirm_end_button() -> Button:
	return _confirm_end_button


func keep_button() -> Button:
	return _keep_button


func is_result_open() -> bool:
	return _result.visible


## The result panel's title, then every text under the stars in order.
func result_lines() -> PackedStringArray:
	var lines := PackedStringArray([_result_title.text])
	for label: Node in _result_lines.find_children("*", "Label", true, false):
		lines.append((label as Label).text)
	return lines


func return_button() -> Button:
	return _return_button


func deploy_bar() -> Control:
	return _bar


func ability_bar() -> Control:
	return _ability_bar


## The toast's text while it shows; "" once it has faded.
func toast_text() -> String:
	return _toast_label.text if _toast.visible else ""


# --- Building -----------------------------------------------------------------------

## The time, destruction and stars at the top left; speed and End, and the loot under them, at
## the top right.
func _build_top() -> void:
	var left := PanelContainer.new()
	left.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(left)
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.offset_left = Hud.MARGIN
	left.offset_top = Hud.MARGIN
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 2)
	left.add_child(column)
	_timer = _label(column, "", &"InfoTitle")
	_destruction = _label(column, "", &"InfoDetail")
	var stars := HBoxContainer.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.add_theme_constant_override("separation", 4)
	column.add_child(stars)
	for k: int in 3:
		_stars.append(_star(stars, STAR_SIZE))

	var right := VBoxContainer.new()
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.alignment = BoxContainer.ALIGNMENT_BEGIN
	right.add_theme_constant_override("separation", 10)
	_root.add_child(right)
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_right = -Hud.MARGIN
	right.offset_left = -Hud.MARGIN
	right.offset_top = Hud.MARGIN
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_END
	buttons.add_theme_constant_override("separation", 12)
	right.add_child(buttons)
	_speed_button = _button("1x", SPEED_SIZE, &"BarButton")
	_speed_button.pressed.connect(_on_speed)
	buttons.add_child(_speed_button)
	_end_button = _button("End", END_SIZE, &"BarButton")
	_end_button.pressed.connect(_on_end)
	buttons.add_child(_end_button)
	var loot := PanelContainer.new()
	loot.mouse_filter = Control.MOUSE_FILTER_STOP
	loot.size_flags_horizontal = Control.SIZE_SHRINK_END
	right.add_child(loot)
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 2)
	loot.add_child(rows)
	_label(rows, "Loot", &"CardCount")
	for res: String in _catalog.resources:
		_loot[res] = _resource_row(rows, res, "0")
		_shown_loot[res] = 0


## The deploy bar along the bottom: a card per unit type brought, in sorted order.
func _build_deploy_bar() -> void:
	_bar = PanelContainer.new()
	_bar.theme_type_variation = &"MenuPanel"
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_bar)
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bar.grow_horizontal = Control.GROW_DIRECTION_END
	_bar.offset_left = Hud.MARGIN
	_bar.offset_right = Hud.MARGIN
	_bar.offset_bottom = -Hud.MARGIN
	_bar.offset_top = -Hud.MARGIN
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size = Vector2(0, CARD_SIZE.y + 14)
	_bar.add_child(scroll)
	_scroll = scroll
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CARD_GAP)
	scroll.add_child(row)
	var levels: Dictionary = (_view.battle_setup.get("attacker", {}) as Dictionary).get("unit_levels", {})
	for unit: String in _view.units_brought():
		var level := clampi(BattleMath.whole(levels.get(unit, 1)), 1, _catalog.unit_max_level(unit))
		_keys[unit] = ModelPreview.unit_key(unit, UnitModels.tier_of(_catalog, unit, level))
		var button := _card(row, _on_card.bind(unit))
		var content := button.get_child(0) as Control
		_pictures[unit] = _picture(content, PICTURE_SIZE)
		_counts[unit] = _card_lines(content, _catalog.unit_name(unit))
		_cards[unit] = button
		_shown_left[unit] = -1
	_cards_width = _cards.size() * (CARD_SIZE.x + CARD_GAP) - CARD_GAP
	_build_ability_bar()


## The abilities bar, right of the deploy bar: a card per ability brought (above 0), in the
## catalog's order; hidden when none is.
func _build_ability_bar() -> void:
	_ability_bar = PanelContainer.new()
	_ability_bar.theme_type_variation = &"MenuPanel"
	_ability_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_ability_bar)
	_ability_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_ability_bar.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_ability_bar.grow_horizontal = Control.GROW_DIRECTION_END
	_ability_bar.offset_bottom = -Hud.MARGIN
	_ability_bar.offset_top = -Hud.MARGIN
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", CARD_GAP)
	row.custom_minimum_size.y = CARD_SIZE.y + 14
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	_ability_bar.add_child(row)
	for ability: String in _view.abilities_brought():
		var button := _card(row, _on_ability_card.bind(ability))
		button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var content := button.get_child(0) as Control
		var glyph := HudIcon.new()
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.custom_minimum_size = PICTURE_SIZE
		glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		content.add_child(glyph)
		Hud.show_ability_glyph(glyph, _catalog, ability)
		_ability_counts[ability] = _card_lines(content, _catalog.ability_name(ability))
		_ability_cards[ability] = button
		_shown_uses[ability] = -1
	_ability_bar.visible = not _ability_cards.is_empty()
	_abilities_width = _ability_cards.size() * (CARD_SIZE.x + CARD_GAP) - CARD_GAP


## A card in `row`: a button CARD_SIZE calling `pressed`, holding a centred column (its child 0)
## the caller fills. PASS, as the HUD's cards, so a drag on a card scrolls its strip.
func _card(row: Control, pressed: Callable) -> Button:
	var button := _button("", CARD_SIZE)
	button.mouse_filter = Control.MOUSE_FILTER_PASS
	button.pressed.connect(pressed)
	row.add_child(button)
	var content := VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	button.add_child(content)
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 6
	content.offset_right = -6
	content.offset_top = Hud.BORDER + 2
	content.offset_bottom = -Hud.BORDER - 2
	return button


## A card's name and, under it, its count, which it returns.
func _card_lines(content: Control, title: String) -> Label:
	var name := _label(content, title, &"QueueName")
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var count := _label(content, "", &"CardCost")
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return count


## End's question, centred: Keep fighting or End battle.
func _build_confirm() -> void:
	# Over the whole screen, not the safe area's root, so no touch beside the panel reaches the
	# field: a tap there would deploy, a drag smear or pan.
	_confirm_backdrop = ColorRect.new()
	_confirm_backdrop.color = BACKDROP
	_confirm_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_confirm_backdrop.theme = _root.theme
	_confirm_backdrop.visible = false
	add_child(_confirm_backdrop)
	_confirm_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm = _centred_panel(_confirm_backdrop)
	_confirm.visible = true
	var column := _confirm.get_child(0) as VBoxContainer
	_label(column, "End the battle?", &"InfoTitle").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var buttons := HBoxContainer.new()
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 16)
	column.add_child(buttons)
	_keep_button = _button("Keep fighting", Vector2(190, 60), &"ConfirmButton")
	_keep_button.pressed.connect(func() -> void: _confirm_backdrop.hide())
	buttons.add_child(_keep_button)
	_confirm_end_button = _button("End battle", Vector2(170, 60), &"BarButton")
	_confirm_end_button.pressed.connect(_on_confirm_end)
	buttons.add_child(_confirm_end_button)


## The result panel, centred, filled when the battle ends (_show_result).
func _build_result() -> void:
	_result = _centred_panel(_root)
	var column := _result.get_child(0) as VBoxContainer
	_result_title = _label(column, "", &"InfoTitle")
	_result_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var stars := HBoxContainer.new()
	stars.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 6)
	column.add_child(stars)
	for k: int in 3:
		_result_stars.append(_star(stars, RESULT_STAR_SIZE))
	_result_lines = VBoxContainer.new()
	_result_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_result_lines.add_theme_constant_override("separation", 6)
	column.add_child(_result_lines)
	_return_button = _button("Return", Vector2(200, 64), &"ConfirmButton")
	_return_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_return_button.pressed.connect(func() -> void: _view.leave())
	column.add_child(_return_button)


## Top centre, under the top panels; it takes no touch and hides once faded.
func _build_toast() -> void:
	_toast = PanelContainer.new()
	_toast.theme_type_variation = &"Toast"
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.visible = false
	_root.add_child(_toast)
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toast.offset_top = 96
	_toast.offset_bottom = 96
	_toast_label = _label(_toast, "", &"ToastText")
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _centred_panel(parent: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"MenuPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.visible = false
	parent.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 14)
	panel.add_child(column)
	return panel


# --- Refresh ------------------------------------------------------------------------

## The top bar and the cards' counts, text set only where it changed.
func _refresh() -> void:
	var sim := _view.sim
	var seconds := sim.seconds_left()
	if seconds != _shown_seconds:
		_shown_seconds = seconds
		_timer.text = "%d:%02d" % [seconds / 60, seconds % 60]
		_fit()
	var pct := sim.destruction_pct()
	if pct != _shown_pct:
		_shown_pct = pct
		_destruction.text = "%d%% destruction" % pct
	var stars := sim.stars()
	if stars != _shown_stars:
		_shown_stars = stars
		for k: int in _stars.size():
			_stars[k].lit = k < stars
	# The loot moves only when a building falls, and BattleSim.loot() builds a dictionary, so it
	# is read only then.
	if _view.falls() != _shown_falls:
		_shown_falls = _view.falls()
		var loot := sim.loot()
		for res: String in _catalog.resources:
			var amount: int = loot.get(res, 0)
			if amount != _shown_loot[res]:
				_shown_loot[res] = amount
				_loot[res].text = Format.short(amount)
	for unit: String in _cards:
		var left := sim.left_to_deploy(unit)
		if left != _shown_left[unit]:
			_shown_left[unit] = left
			_counts[unit].text = "x%d" % left
			_cards[unit].modulate.a = Hud.DISABLED_ALPHA if left == 0 else 1.0
			if left == 0 and _view.deploy_unit == unit:
				_select("")
	for ability: String in _ability_cards:
		var uses := sim.left_to_use(ability)
		if uses != _shown_uses[ability]:
			_shown_uses[ability] = uses
			_ability_counts[ability].text = "x%d" % uses
			_ability_cards[ability].modulate.a = Hud.DISABLED_ALPHA if uses == 0 else 1.0
			if uses == 0 and _view.cast_ability == ability:
				_select_ability("")


func _show_result(result: Dictionary) -> void:
	_refresh()
	_confirm_backdrop.hide()
	_bar.hide()
	_ability_bar.hide()
	_end_button.disabled = true
	_speed_button.disabled = true
	var stars := int(result.get("stars", 0))
	_result_title.text = "Victory!" if stars > 0 else "Defeat"
	for k: int in _result_stars.size():
		_result_stars[k].lit = k < stars
	_label(_result_lines, "%d%% destruction" % int(result.get("destruction", 0)), &"InfoDetail") \
		.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var loot_row := HBoxContainer.new()
	loot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	loot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	loot_row.add_theme_constant_override("separation", 18)
	_result_lines.add_child(loot_row)
	var loot: Dictionary = result.get("loot", {})
	for res: String in _catalog.resources:
		_resource_row(loot_row, res, Format.short(int(loot.get(res, 0))))
	var deployed: Dictionary = result.get("deployed", {})
	if deployed.is_empty():
		_label(_result_lines, "No units deployed", &"CardCount").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		_label(_result_lines, "Units deployed", &"CardCount").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var units := HBoxContainer.new()
		units.mouse_filter = Control.MOUSE_FILTER_IGNORE
		units.alignment = BoxContainer.ALIGNMENT_CENTER
		units.add_theme_constant_override("separation", 14)
		_result_lines.add_child(units)
		for unit: String in deployed:
			var cell := VBoxContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_constant_override("separation", 0)
			units.add_child(cell)
			var picture := _picture(cell, RESULT_PICTURE_SIZE)
			picture.texture = _preview.texture_of(_keys.get(unit, ""))
			_label(cell, "%s x%d" % [_catalog.unit_name(unit), int(deployed[unit])], &"CardCost") \
				.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var used: Dictionary = result.get("abilities_used", {})
	if not used.is_empty():
		_label(_result_lines, "Abilities used", &"CardCount").horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var abilities := HBoxContainer.new()
		abilities.mouse_filter = Control.MOUSE_FILTER_IGNORE
		abilities.alignment = BoxContainer.ALIGNMENT_CENTER
		abilities.add_theme_constant_override("separation", 14)
		_result_lines.add_child(abilities)
		for ability: String in used:
			var cell := VBoxContainer.new()
			cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cell.add_theme_constant_override("separation", 0)
			abilities.add_child(cell)
			var glyph := HudIcon.new()
			glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glyph.custom_minimum_size = RESULT_PICTURE_SIZE
			glyph.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			cell.add_child(glyph)
			Hud.show_ability_glyph(glyph, _catalog, ability)
			_label(cell, "%s x%d" % [_catalog.ability_name(ability), int(used[ability])], &"CardCost") \
				.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result.show()


# --- Presses --------------------------------------------------------------------------

func _on_card(unit: String) -> void:
	if _view.sim.is_over():
		return
	_select("" if _view.deploy_unit == unit else unit)


## Selects `unit` in the view and on its card (the selected card takes the accent), "" for none.
func _select(unit: String) -> void:
	if unit != "" and _view.sim.left_to_deploy(unit) == 0:
		unit = ""
	_view.select_unit(unit)
	_highlight()


## Selects `ability` to cast, "" for none: the unit type is let go (BattleView.select_ability).
func _select_ability(ability: String) -> void:
	if ability != "" and _view.sim.left_to_use(ability) == 0:
		ability = ""
	_view.select_ability(ability)
	_highlight()


func _on_ability_card(ability: String) -> void:
	if _view.sim.is_over():
		return
	_select_ability("" if _view.cast_ability == ability else ability)


## The selected card, unit or ability, takes the accent fill and ink text; the others the card's.
func _highlight() -> void:
	for type: String in _cards:
		_mark(_cards[type], type == _view.deploy_unit)
	for ability: String in _ability_cards:
		_mark(_ability_cards[ability], ability == _view.cast_ability)


func _mark(card: Button, on: bool) -> void:
	card.theme_type_variation = &"TabSelected" if on else &""
	var name_color := Hud.INK if on else Hud.TEXT
	for child: Node in card.get_child(0).get_children():
		if child is Label:
			(child as Label).add_theme_color_override("font_color", name_color)


func _on_speed() -> void:
	var at := BattleView.SPEEDS.find(_view.speed)
	_view.speed = BattleView.SPEEDS[(at + 1) % BattleView.SPEEDS.size()]
	_speed_button.text = "%dx" % _view.speed


func _on_end() -> void:
	if not _view.sim.is_over():
		_confirm_backdrop.show()


func _on_confirm_end() -> void:
	_confirm_backdrop.hide()
	_view.surrender()


func _on_deploy_failed(error: String) -> void:
	if DEPLOY_TEXT.has(error):
		_show_toast(DEPLOY_TEXT[error])


func _on_cast_failed(error: String) -> void:
	if CAST_TEXT.has(error):
		_show_toast(CAST_TEXT[error])


func _show_toast(text: String) -> void:
	_toast_label.text = text
	_toast.modulate.a = 1.0
	_toast.show()
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.5).set_delay(1.0)
	_toast_tween.tween_callback(_toast.hide)


func _on_rendered(key: String, texture: Texture2D) -> void:
	for unit: String in _keys:
		if _keys[unit] == key:
			_pictures[unit].texture = texture


## Lays the HUD inside the safe area; the deploy bar's right end stays clear of the Build column.
func _fit() -> void:
	if not is_inside_tree():
		return
	var area := Hud.safe_area(get_viewport())
	if area == _fitted:
		return
	_fitted = area
	var full := get_viewport().get_visible_rect().size
	_root.offset_left = area.position.x
	_root.offset_top = area.position.y
	_root.offset_right = area.end.x - full.x
	_root.offset_bottom = area.end.y - full.y
	# The room for the cards: the safe area's width less the bar's left margin, the Build column
	# with its margins, and the panel's own content margins either side of the strip.
	var panel := _bar.get_theme_stylebox(&"panel")
	var margins := panel.get_margin(SIDE_LEFT) + panel.get_margin(SIDE_RIGHT)
	var room := area.size.x - Hud.MARGIN - (Hud.BUILD_SIZE.x + 2 * Hud.MARGIN) - margins
	# The abilities bar takes its whole width and the gap first; the deploy bar scrolls in the rest.
	var abilities := _abilities_width + margins + BAR_GAP if _ability_bar.visible else 0.0
	_scroll.custom_minimum_size.x = minf(_cards_width, maxf(room - abilities, CARD_SIZE.x))
	_ability_bar.offset_left = Hud.MARGIN + _scroll.custom_minimum_size.x + margins + BAR_GAP
	_ability_bar.offset_right = _ability_bar.offset_left


# --- Pieces -------------------------------------------------------------------------

func _label(parent: Control, text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	parent.add_child(label)
	return label


func _button(text: String, min_size: Vector2, variation: StringName = &"") -> Button:
	var button := Button.new()
	button.text = text
	button.theme_type_variation = variation
	button.custom_minimum_size = min_size
	button.focus_mode = Control.FOCUS_NONE
	return button


func _star(parent: Control, star_size: Vector2) -> Star:
	var star := Star.new()
	star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star.custom_minimum_size = star_size
	parent.add_child(star)
	return star


func _picture(parent: Control, picture_size: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	picture.custom_minimum_size = picture_size
	picture.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	parent.add_child(picture)
	return picture


## A resource's icon (HudIcon) beside `text` in its colour, in a row under `parent`; returns the
## label.
func _resource_row(parent: Control, res: String, text: String) -> Label:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var icon := HudIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.custom_minimum_size = ICON_SIZE
	icon.color = Color.from_string(_catalog.resource_color(res), Hud.TEXT)
	icon.show_icon(res, false)
	row.add_child(icon)
	var label := _label(row, text, &"MeterText")
	label.add_theme_color_override("font_color", Color.from_string(_catalog.resource_color(res), Hud.TEXT))
	return label
