class_name Surf
extends RefCounted
## How a LowPolyMesh part is painted (docs/reference/art-style.md, **Surfaces**): the kit layer
## and the tint that multiplies it, the texture's scale, the surface flags the shaders read,
## the phase of its animation, whether the part is smooth shaded, and whether it goes into the
## ink outline.
##
## Build one with make() and share it: a Surf is never changed once made; phased() makes a copy
## with another phase.

## Surface flags, carried in UV2.y: bits, combined with |. Their effects are in
## src/game/effects.gdshaderinc and docs/reference/art-style.md, **Animation**.
const LIT := 0
## Pure emission: no bands, no halftone, no rim.
const UNLIT := 1
## Lit, with the cel specular disc.
const GLOSSY := 2
## The colour swells and fades on a slow sine: cores, lenses, beacons.
const PULSE := 4
## A hard blink, dim between: warning lamps; phases k/n chase round a ring.
const BLINK := 8
## Irregular fast on/off, gone while off: sparks, welding arcs. Never outlined.
const FLICKER := 16
## The texture scrolls along V: liquids, currents, conveyors, screens.
const FLOW := 32
## The texture scrolls along U: discs, rings.
const FLOW_U := 64
## The part floats up and down.
const BOB := 128
## The vertices shake: with UNLIT and FLICKER, a crackling arc. Never outlined.
const JITTER := 256
## A transparent, unlit, phasing hologram, drawn on a surface of its own. Never outlined.
const HOLO := 512
## The flags whose parts are never outlined, whatever `outline` says.
const NO_OUTLINE := FLICKER | JITTER | HOLO

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
## 0 to 1, stored in 1/254 steps: where in its effect's cycle the part is at time 0 (in
## COLOR.a). For FLOW and FLOW_U it is the speed and direction instead: 0.5 still, 0.75 one
## repeat a second forward, 0.25 back.
var phase: float = 0.0


static func make(new_layer: int, new_tint: Color, new_uv_scale: float = 1.0, new_flags: int = LIT,
		new_smooth: bool = false, new_outline: bool = true, new_phase: float = 0.0) -> Surf:
	var surf := Surf.new()
	surf.layer = new_layer
	surf.tint = new_tint
	surf.uv_scale = new_uv_scale
	surf.flags = new_flags
	surf.smooth = new_smooth
	surf.outline = new_outline
	surf.phase = new_phase
	return surf


## A copy of this surface with another phase.
func phased(new_phase: float) -> Surf:
	return Surf.make(layer, tint, uv_scale, flags, smooth, outline, new_phase)
