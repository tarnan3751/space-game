class_name MaterialKit
extends RefCounted
## The comic style's shared look (docs/reference/art-style.md): the material kit, the colour
## roles every model is tinted from, and the few shared materials every mesh is drawn with.
##
## The kit is one Texture2DArray of the twenty layers tools/gen_textures.gd draws into
## assets/textures/kit/, imported as Images and given their mipmaps here (the Compatibility
## renderer generates none for a layered texture). A mesh picks a layer per vertex in UV2.x
## and its surface flags in UV2.y (LowPolyMesh does this from a Surf), and carries its tint in
## the vertex colour, so every building, the scaffold and the rocks share the toon material.
## Per-view states swap in another shared material through set_surface_override_material,
## never a new one.

## The kit's layers, in array order (the PNGs' index prefixes).
enum Layer {
	FLAT, HULL, HULL_DENSE, PLATE, VENT, PIPE, GRATING, CONCRETE,
	HAZARD, SOLAR, GLASS, GLOW, SCREEN, CRYSTAL, ROCK, REGOLITH, BANDS,
	CHROME, OBSIDIAN, VEINS,
}
const LAYERS := [
	"flat", "hull", "hull_dense", "plate", "vent", "pipe", "grating", "concrete",
	"hazard", "solar", "glass", "glow", "screen", "crystal", "rock", "regolith", "bands",
	"chrome", "obsidian", "veins",
]
const TEXTURE_DIR := "res://assets/textures/kit"

## Colour roles, sRGB. A tint multiplies a near-white layer.
const INK := Color("1b1a2e")
const HULL_LIGHT := Color("e8e4da")
const HULL_MID := Color("9aa3b8")
const HULL_DARK := Color("4a5168")
const GUNMETAL := Color("353b4d")
const CONCRETE := Color("8e8a95")
const CORE_GOLD := Color("f2b134")
const CORE_GLASS := Color("7fe7ff")
const METAL := Color("3fc9c0")
const CRYSTAL := Color("e2a4ff")
const ANTIMATTER := Color("b48cff")
const ARMY := Color("ff7f11")
const DEFENCE := Color("e63946")
const HAZARD := Color("ffd60a")
const WALL := Color("6b7fa3")
const ENERGY := Color("58e8ff")
const NANITE_GREEN := Color("8cff5a")
const ARC_BLUE := Color("5b8cff")
## The buildable field: its dust, the light and dark sides of its marks (crater walls, pebbles,
## shards) and its light and dark tones, and the levelled ground under the dust. The ground's and
## the terrain's roles are picked so that, under the warm key light and over their textures, they
## render at the art style's colours (docs/reference/art-style.md, **Colour**): bluer and more
## saturated than they show. FIELD covers the ground at 60 percent, so it is the most saturated.
const FIELD := Color("4733c9")
const FIELD_LIGHT := Color("746cdb")
const FIELD_DARK := Color("443ba2")
const FIELD_PLATE := Color("6d6cc0")
## The terrain around the field, rendering in the field's shade: its dust, its lit slopes and the
## light sides of its marks and ripples, and its crater floors, shadow sides and the dark sides of
## its marks, ripples and strata; and rock, its faces, and its lit faces and strata.
const TERRAIN := Color("564ac5")
const TERRAIN_LIGHT := Color("7a73e3")
const TERRAIN_DARK := Color("3e388c")
const ROCK := Color("50619b")
const ROCK_LIT := Color("768bc9")
## The scene: the sky's base colour (deep space), the environment's ambient light and the key light.
const SPACE := Color("0d0b1a")
const AMBIENT := Color("8c8cff")
const SUN := Color("fff4e0")

## How much of its tint a placement ghost's body takes.
const GHOST_MIX := 0.65

const TOON_SHADER := preload("res://src/game/toon.gdshader")
const INK_SHADER := preload("res://src/game/ink.gdshader")
const HOLO_SHADER := preload("res://src/game/holo.gdshader")
const TERRAIN_SHADER := preload("res://src/game/terrain.gdshader")
## The rock texture the terrain's steep faces are drawn from, imported as an Image
## (tools/gen_textures.gd).
const TERRAIN_ROCK_TEXTURE := "res://assets/textures/terrain_rock.png"

static var _texture: Texture2DArray
static var _toon: ShaderMaterial
static var _ink: ShaderMaterial
static var _ink_selected: ShaderMaterial
static var _holo: ShaderMaterial
static var _ghost_valid: ShaderMaterial
static var _ghost_invalid: ShaderMaterial
static var _terrain: ShaderMaterial


## The kit: one layer per entry of LAYERS, mipmapped, built on first use.
static func texture() -> Texture2DArray:
	if _texture != null:
		return _texture
	var images: Array[Image] = []
	for index: int in LAYERS.size():
		var image: Image = load("%s/%02d_%s.png" % [TEXTURE_DIR, index, LAYERS[index]])
		image.generate_mipmaps()
		images.append(image)
	_texture = Texture2DArray.new()
	_texture.create_from_images(images)
	return _texture


## The body material of every kit mesh: toon shading of the layer and tint each vertex names.
static func toon() -> ShaderMaterial:
	if _toon == null:
		_toon = _toon_material(Color(1, 1, 1, 0))
	return _toon


## The outline material: the inverted hull in ink.
static func ink() -> ShaderMaterial:
	if _ink == null:
		_ink = _ink_material(INK)
	return _ink


## The outline of a selected or lifted building.
static func ink_selected() -> ShaderMaterial:
	if _ink_selected == null:
		_ink_selected = _ink_material(CORE_GOLD)
	return _ink_selected


## The hologram surface of a kit mesh: its HOLO parts, transparent and unlit.
static func holo() -> ShaderMaterial:
	if _holo == null:
		_holo = ShaderMaterial.new()
		_holo.shader = HOLO_SHADER
		_holo.set_shader_parameter("kit", texture())
	return _holo


## The body of a placement ghost on a free spot.
static func ghost_valid() -> ShaderMaterial:
	if _ghost_valid == null:
		_ghost_valid = _toon_material(Color(ENERGY, GHOST_MIX))
	return _ghost_valid


## The body of a placement ghost on a spot it cannot take.
static func ghost_invalid() -> ShaderMaterial:
	if _ghost_invalid == null:
		_ghost_invalid = _toon_material(Color(DEFENCE, GHOST_MIX))
	return _ghost_invalid


## The terrain ring's body: its vertex tint drawn over with the field texture's marks and the rock
## texture's strata, in the terrain's roles. Built on first use, the rock texture set then;
## BaseView sets the field texture (the ground's), the field's size and the sun's direction on it.
static func terrain() -> ShaderMaterial:
	if _terrain == null:
		var rock: Image = load(TERRAIN_ROCK_TEXTURE)
		# Mipmapped here: the image importer keeps the PNG as it is.
		rock.generate_mipmaps()
		_terrain = ShaderMaterial.new()
		_terrain.shader = TERRAIN_SHADER
		_terrain.set_shader_parameter("rock", ImageTexture.create_from_image(rock))
		_terrain.set_shader_parameter("terrain_light", TERRAIN_LIGHT)
		_terrain.set_shader_parameter("terrain_dark", TERRAIN_DARK)
		_terrain.set_shader_parameter("rock_lit", ROCK_LIT)
		_terrain.set_shader_parameter("ink_color", INK)
	return _terrain


static func _toon_material(ghost_tint: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = TOON_SHADER
	material.set_shader_parameter("kit", texture())
	material.set_shader_parameter("ghost_tint", ghost_tint)
	return material


static func _ink_material(color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = INK_SHADER
	material.set_shader_parameter("ink_color", color)
	return material
