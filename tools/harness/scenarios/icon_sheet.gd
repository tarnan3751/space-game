extends HarnessScenario
## The HUD icons' sheet (docs/reference/hud.md, **Icons**): every HudIcon kind at 24, 36, 48 and
## 64 px, bare and on its coin, on a page per background, the panel's, the card's and the accent's
## (a selected card), with each kind's name in InfoTitle; then a block of the three ability emblems
## and the three unit glyphs on their coins at twice the largest size.
##
## In both modes it paints every kind into a Pen of its own and checks that it adds triangles, that
## no kind but the fallback draws the fallback's gem, and that a coin adds to an icon. Rendered, it
## shoots the pages and the block and checks that a row of coined icons costs at most a draw call
## each (the Pen's one triangle array, **One draw call each**).

## The kinds, each with its colour, its coin's and its name on the sheet, in the sheet's order.
const KINDS := [
	["metal", "a8c0dc", "17162a", "metal"], ["crystal", "e2a4ff", "17162a", "crystal"],
	["antimatter", "b48cff", "17162a", "antimatter"], ["drones", "58e8ff", "17162a", "drones"],
	["army", "ff7f11", "ff7f11", "army"], ["human", "ff7f11", "ff7f11", "human"],
	["piloted", "ff7f11", "ff7f11", "piloted"], ["autonomous", "ff7f11", "ff7f11", "autonomous"],
	["swarm", "8cff5a", "8cff5a", "swarm"], ["emp", "5b8cff", "5b8cff", "emp"],
	["strike", "e63946", "e63946", "strike"], ["lock", "9aa3b8", "17162a", "lock"],
	["clock", "e8e4da", "17162a", "clock"], ["chevron", "ffc13b", "17162a", "chevron"],
	["star", "ffc13b", "17162a", "star"], ["star", "4a5168", "17162a", "star off"],
	["skull", "e8e4da", "17162a", "skull"],
]
const SIZES := [24, 36, 48, 64]
const ROWS_PER_COLUMN := 9
const ROW_HEIGHT := 72
const NAME_WIDTH := 120
const GAP := 8
const BLOCK := ["swarm", "emp", "strike", "human", "piloted", "autonomous"]
const BLOCK_SIZE := 128


func run(main: MainScript) -> void:
	await frames(2)
	# The fallback gem, drawn once, which no named kind should match.
	var gem := _triangles("", Color.WHITE, Color.TRANSPARENT)
	for entry: Array in KINDS:
		var kind: String = entry[0]
		var plain := _triangles(kind, Color(entry[1] as String), Color.TRANSPARENT)
		var coined := _triangles(kind, Color(entry[1] as String), Color(entry[2] as String))
		check(plain > 0 and plain != gem and coined > plain,
			"%s paints %d triangles, %d on its coin (the fallback gem %d)" % [kind, plain, coined, gem])

	var layer := CanvasLayer.new()
	layer.layer = 100
	main.add_child(layer)
	var backgrounds := {"panel": Hud.PANEL, "card": Hud.CARD, "accent": Hud.ACCENT}
	for name: String in backgrounds:
		var page := _page(main, layer, backgrounds[name])
		_sheet(page, name == "accent")
		await frames(4)
		await screenshot("sheet-%s" % name)
		page.queue_free()
	var block := _page(main, layer, Hud.CARD)
	for k: int in BLOCK.size():
		var kind: String = BLOCK[k]
		var tint: Color = Hud.ABILITY_COLORS.get(kind, MaterialKit.ARMY)
		var icon := _icon(block, kind, tint, tint, BLOCK_SIZE)
		icon.position = Vector2(200 + (k % 3) * (BLOCK_SIZE + 120), 120 + (k / 3) * (BLOCK_SIZE + 100))
	await frames(4)
	await screenshot("emblems-2x")
	block.queue_free()

	if DisplayServer.get_name() == "headless":
		return
	var row := _page(main, layer, Hud.CARD)
	var icons: Array[HudIcon] = []
	for k: int in KINDS.size():
		var entry: Array = KINDS[k]
		var icon := _icon(row, entry[0], Color(entry[1] as String), Color(entry[2] as String), 48)
		icon.position = Vector2(40 + k * 60, 300)
		icons.append(icon)
	await frames(6)
	var with_icons := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	for icon: HudIcon in icons:
		icon.visible = false
	await frames(6)
	var without := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	check(with_icons - without <= icons.size(), "%d coined icons cost %d draw calls (%d with, %d without)"
		% [icons.size(), with_icons - without, with_icons, without])
	row.queue_free()


## The triangles `kind` paints at 48 px in `tint`, on a coin of `coin` unless it is transparent.
func _triangles(kind: String, tint: Color, coin: Color) -> int:
	var pen := HudIcon.Pen.new()
	HudIcon.paint(pen, kind, Rect2(0, 0, 48, 48), tint, false, coin)
	return pen.triangle_count()


## A full-screen page in the HUD's theme, filled with `color`, over everything.
func _page(main: MainScript, layer: CanvasLayer, color: Color) -> Control:
	var page := ColorRect.new()
	page.color = Color(color, 1.0)
	page.theme = main.hud.ui_theme()
	layer.add_child(page)
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return page


## The kinds in two columns, each row its name, the four sizes bare, then the four on coins; the
## accent page's names in ink.
func _sheet(page: Control, accent: bool) -> void:
	for k: int in KINDS.size():
		var entry: Array = KINDS[k]
		var at := Vector2(24 + (k / ROWS_PER_COLUMN) * 620, 12 + (k % ROWS_PER_COLUMN) * ROW_HEIGHT)
		var label := Label.new()
		label.theme_type_variation = &"InfoTitle"
		label.text = entry[3]
		if accent:
			label.add_theme_color_override("font_color", Hud.INK)
		label.position = at + Vector2(0, 18)
		page.add_child(label)
		var x := at.x + NAME_WIDTH
		for coined: bool in [false, true]:
			for size: int in SIZES:
				var coin := Color(entry[2] as String) if coined else Color.TRANSPARENT
				var icon := _icon(page, entry[0], Color(entry[1] as String), coin, size)
				icon.position = Vector2(x, at.y + (64 - size) * 0.5)
				x += size + GAP
			x += GAP * 2


func _icon(parent: Control, kind: String, tint: Color, coin: Color, side: int) -> HudIcon:
	var icon := HudIcon.new()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.kind = kind
	icon.color = tint
	icon.coin = coin
	icon.size = Vector2(side, side)
	parent.add_child(icon)
	return icon
