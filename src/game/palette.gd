class_name Palette
extends RefCounted
## The one colour table every low-poly mesh is painted from. Each entry is an 8x8 cell of a
## small albedo texture; a glow entry also lights its cell of an emission texture. A mesh picks
## a colour by putting a face's UVs at that cell's centre (uv()), so every building, the terrain
## and the rocks share one StandardMaterial3D (material()). The textures are generated at run
## time; swapping in a painted texture later changes this file only.

const CELL := 8
const COLUMNS := 8
## Emission energy of the glow entries, enough for them to read as lit on GL Compatibility.
const GLOW_ENERGY := 1.1
## A glow entry's albedo is its colour this much darker, so the light falling on it does not
## wash its hue out to white; the emission carries the colour.
const GLOW_ALBEDO_DARKENING := 0.6

## [name, colour, glows]. Order is the cell order; names are what meshes ask for.
const ENTRIES := [
	["hull_dark", Color("2b2e42"), false],
	["hull", Color("434a68"), false],
	["hull_light", Color("667090"), false],
	["metal", Color("848fa3"), false],
	["metal_dark", Color("6d7688"), false],
	["white", Color("9ea7b8"), false],
	["window", Color("141826"), false],
	["orange", Color("e0843a"), false],
	["red", Color("b23f3c"), false],
	["hazard", Color("f2cf3e"), false],
	["gold", Color("c99232"), false],
	["glow_cyan", Color("4fe0f0"), true],
	["glow_orange", Color("ff9640"), true],
	["glow_magenta", Color("f25ce2"), true],
	["glow_violet", Color("7a5cff"), true],
	["glow_green", Color("5cf08c"), true],
	["glow_red", Color("ff4848"), true],
	["glow_blue", Color("cfe2ff"), true],
	["glow_gold", Color("ffcb52"), true],
	["regolith_dark", Color("2f2a3b"), false],
	["regolith", Color("3a3448"), false],
	["regolith_light", Color("474057"), false],
	["rock", Color("363044"), false],
	["rock_dark", Color("27222f"), false],
	["crater", Color("1e1a27"), false],
]

static var _index: Dictionary[String, int] = {}
static var _material: StandardMaterial3D


## UV of the centre of a colour's cell. Every vertex of a face takes the same one.
static func uv(entry: String) -> Vector2:
	var index := _lookup(entry)
	var rows := _rows()
	return Vector2((index % COLUMNS + 0.5) / COLUMNS, (index / COLUMNS + 0.5) / rows)


## The colour itself, for shaders that must match the palette (the ground).
static func color(entry: String) -> Color:
	var row: Array = ENTRIES[_lookup(entry)]
	return row[1]


## The shared material for every mesh painted from the palette.
static func material() -> StandardMaterial3D:
	if _material != null:
		return _material
	var size := Vector2i(COLUMNS * CELL, _rows() * CELL)
	var albedo := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	var emission := Image.create_empty(size.x, size.y, false, Image.FORMAT_RGB8)
	emission.fill(Color.BLACK)
	for index: int in ENTRIES.size():
		var row: Array = ENTRIES[index]
		var cell := Rect2i((index % COLUMNS) * CELL, (index / COLUMNS) * CELL, CELL, CELL)
		var paint: Color = row[1]
		var glows: bool = row[2]
		albedo.fill_rect(cell, paint.darkened(GLOW_ALBEDO_DARKENING) if glows else paint)
		if glows:
			emission.fill_rect(cell, paint)
	_material = StandardMaterial3D.new()
	_material.albedo_texture = ImageTexture.create_from_image(albedo)
	_material.emission_enabled = true
	_material.emission = Color.BLACK
	_material.emission_texture = ImageTexture.create_from_image(emission)
	_material.emission_energy_multiplier = GLOW_ENERGY
	_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_material.roughness = 1.0
	return _material


static func _rows() -> int:
	return (ENTRIES.size() + COLUMNS - 1) / COLUMNS


static func _lookup(entry: String) -> int:
	if _index.is_empty():
		for index: int in ENTRIES.size():
			var row: Array = ENTRIES[index]
			_index[row[0]] = index
	if not _index.has(entry):
		push_error("Palette has no colour '%s'" % entry)
		return 0
	return _index[entry]
