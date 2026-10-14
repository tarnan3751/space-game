class_name Palette
extends RefCounted
## The named colours the building models, the terrain and the rocks were painted with before
## the material kit. surf() turns one into a Surf on the kit's flat layer (a glow entry is
## unlit), so the models keep their colours while they move onto the kit.

## [name, colour, glows]. Names are what the models and the scenery ask for.
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
static var _surfs: Dictionary[String, Surf] = {}


## A colour as a surface: the flat layer tinted with it, unlit for a glow entry.
static func surf(entry: String, outline: bool = true) -> Surf:
	var key := entry if outline else entry + "/bare"
	if not _surfs.has(key):
		var row: Array = ENTRIES[_lookup(entry)]
		var glows: bool = row[2]
		_surfs[key] = Surf.make(MaterialKit.Layer.FLAT, row[1], 1.0, Surf.UNLIT if glows else Surf.LIT,
			false, outline)
	return _surfs[key]


## The colour itself, for shaders that must match the palette (the ground).
static func color(entry: String) -> Color:
	var row: Array = ENTRIES[_lookup(entry)]
	return row[1]


static func _lookup(entry: String) -> int:
	if _index.is_empty():
		for index: int in ENTRIES.size():
			var row: Array = ENTRIES[index]
			_index[row[0]] = index
	if not _index.has(entry):
		push_error("Palette has no colour '%s'" % entry)
		return 0
	return _index[entry]
