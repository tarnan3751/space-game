class_name Surf
extends RefCounted
## How a LowPolyMesh part is painted (docs/reference/art-style.md, **Surfaces**): the kit layer
## and the tint that multiplies it, the texture's scale, the surface flags the toon shader
## reads, whether the part is smooth shaded, and whether it goes into the ink outline.
##
## Build one with make() and share it: a Surf is never changed once made.

## Surface flags, carried in UV2.y.
const LIT := 0
## Pure emission: no bands, no halftone, no rim.
const UNLIT := 1
## Lit, with the cel specular disc.
const GLOSSY := 2

## A MaterialKit.Layer.
var layer: int = MaterialKit.Layer.FLAT
## sRGB; multiplies the layer. White for the fixed-colour layers (hazard, solar).
var tint: Color = Color.WHITE
## Texture repeats per world unit.
var uv_scale: float = 1.0
var flags: int = LIT
## Curved faces share normals (averaged by position within the part); edges sharper than
## LowPolyMesh.SMOOTH_ANGLE and flat caps stay hard.
var smooth: bool = false
## Part of the ink outline. Off for very thin parts (rods under 0.06 units, wires).
var outline: bool = true


static func make(new_layer: int, new_tint: Color, new_uv_scale: float = 1.0, new_flags: int = LIT,
		new_smooth: bool = false, new_outline: bool = true) -> Surf:
	var surf := Surf.new()
	surf.layer = new_layer
	surf.tint = new_tint
	surf.uv_scale = new_uv_scale
	surf.flags = new_flags
	surf.smooth = new_smooth
	surf.outline = new_outline
	return surf
