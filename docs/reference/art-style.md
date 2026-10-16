# Art style

The comic style every model, the ground and the scenery are drawn in: the look, the light, the
colours, the material kit, how `LowPolyMesh` paints a part, the ink outline, the modelling
vocabulary and budgets, the animation, and the view states. Every model brief points here. The scene, the
camera and the views' wiring are in `input-camera.md`.

| File | What |
| --- | --- |
| `src/game/material_kit.gd` | `MaterialKit`: the kit's `Texture2DArray`, the colour roles, the shared materials |
| `src/game/surf.gd` | `Surf`: how a part is painted |
| `src/game/low_poly_mesh.gd` | `LowPolyMesh`: parts, UVs, smoothing, the body and outline meshes |
| `src/game/toon.gdshader`, `toon_common.gdshaderinc` | the body shader and the light it shares with the ground and the terrain |
| `src/game/effects.gdshaderinc` | the surface flags and their time-driven effects, shared by the toon, ink and holo shaders (**Animation**) |
| `src/game/ink.gdshader` | the outline shader |
| `src/game/sky.gdshader` | the sky beyond the terrain ring (**Light and shading**) |
| `src/game/holo.gdshader` | the hologram surface (**Animation**) |
| `src/game/motion.gd` | `Motion`: how a moving part moves (**Animation**) |
| `src/game/ground.gdshader` | the buildable field: its ground, its marks, the grid |
| `src/game/terrain.gdshader` | the terrain ring's body: its marks, ripples and rock strata over the vertex tint |
| `src/game/field_marks.gdshaderinc` | the field texture's tiles, the marks' light and the grain, shared by the ground and the terrain |
| `src/game/base_view.gd` | builds the ground, the perimeter, the terrain ring, the rocks and the outcrops (**Environment**) |
| `src/game/building_models.gd`, `src/game/models/` | the dispatcher and one model file per category, `Parts` in `models/parts.gd` |
| `src/game/construction_drone.gd`, `src/game/models/drone.gd` | the builder drone over a busy site, its flight and its laser (**Construction drone**) |
| `assets/textures/kit/` | the twenty layers, committed PNGs |
| `assets/textures/field.png` | the field texture, a committed PNG |
| `assets/textures/terrain_rock.png` | the terrain's rock texture, a committed PNG |
| `tools/gen_textures.gd` | the generator that draws them |

## The look

A pulp science-fiction comic panel: every object has a dark ink outline, surfaces are coloured
in three flat bands of light with hard edges, shadows lean cool (blue-violet) and lit sides lean
warm, and the shadow band carries a faint halftone dot screen like printed paper. Colours are
saturated and few, each building category owns an accent colour, and surface detail (panel
seams, rivets, vents, hazard stripes) is drawn as ink lines in the textures, not modelled.
Shapes are chunky and a little exaggerated: fat barrels, thick legs, oversized bolts, bevelled
edges on every box. Curved surfaces (cylinders, domes, dishes, pipes) are smooth shaded so the
cel bands sweep across them in clean arcs; boxes and chamfers keep hard edges. Nothing reads as
a faceted primitive.

## Light and shading

`main.gd` builds the environment: deep space behind (**The sky**, below), a cool ambient
(`AMBIENT`, `8C8CFF` at 0.35), linear tonemapping (filmic desaturates the accents), and one
`DirectionalLight3D`, the key light: warm white (`SUN`, `FFF4E0`) at energy 1.0, from the upper
left of the view (rotation −55°, −30°), casting one `SHADOW_ORTHOGONAL` split. There is no second
light: bands are per light and add up, so a second light doubles the tones.

**The shadow.** The Compatibility renderer fits the directional shadow map to the camera's slice
between its near and far planes (a bounding sphere, snapped to texels, so a pan does not make
the edges crawl and a zoom re-fits it); with an orthographic camera
`directional_shadow_max_distance` (left at 80) does nothing. `IsoCamera` keeps that slice tight
round the scene at every zoom (`input-camera.md`, **IsoCamera**), which is what keeps the texel
small: about 0.05 units at the closest zoom, 0.08 at the start and 0.12 at the widest, where a
loose slice made it blocky. `project.godot` sets the map to 1024 (16-bit depth, the engine's
default) and `soft_shadow_filter_quality` to 4, both on mobile too (`.mobile`; the filter's
mobile default is 0, hard): a 13-tap PCF about two texels wide. The map is 1024 rather than 2048
for the softness: the filter's footprint is what sets the penumbra's width (**The penumbra**), and
2048 left it about 2 px at the start zoom; at 1024 the edges stay smooth, with no new acne.
`DirectionalLight3D.shadow_blur` and `light_angular_distance` do nothing in Compatibility. The
light's biases, both in texels, are `shadow_normal_bias` 5 and `shadow_bias` 0.3: with filtering on,
the defaults (2 and 0.1) left acne on grazing faces (the Command Center's step risers, the hangars'
vaults, plinth edges) as patches of dots; at these values the wall and pylon feet still meet their
shadows.

The toon, ground and terrain shaders take no ambient light (`render_mode
ambient_light_disabled`). The Compatibility renderer adds the ambient pass and the shadowed key
light's pass separately, each already in sRGB, so even a little ambient lifts every band past the
shadow band's whole tone and washes it blue; the cool side lives in the shadow band's tint
instead. The environment's ambient still lights anything else (none of the scene today).

`light()` in `toon_common.gdshaderinc` quantises the key light into three bands on `NdotL`, with
0.02-wide smoothstep edges, and lays the cast shadow over them as the shadow band (below, **The
penumbra**):

| Band | NdotL | Tone (sRGB, of the albedo) | Measured on a flat box |
| --- | --- | --- | --- |
| Lit | above 0.55 | 1.0, warm from the key light | 0.95, 0.90, 0.83 |
| Mid | 0.15 to 0.55 | 0.78 | 0.74, 0.70, 0.65 |
| Shadow | below 0.15 | 0.55 in the cool tint (0.82, 0.84, 1.0), with the halftone | 0.40, 0.41, 0.49 |

The constants are these tones raised to 2.2 (the shader works in linear), the shadow band's cool
tint divided by the key light's warm colour so it stays cool, and the shadow band nudged up by
eye to make up for its dots. The measured column is the rendered pixel over the tint on the flat
layer, whose own grey is about 0.95; it holds for every tint but the darkest, where sRGB's linear
toe makes the shadow a little darker.

- **Halftone**: in the shadow band only, a dot grid turned 45°, period 4 px at a 720 px viewport
  height and scaled with it (`FRAGCOORD.xy * 720 / VIEWPORT_SIZE.y`), dots covering 35 % of a
  cell, each darkening the band by 0.12 of its tone. Its edge is antialiased analytically (one
  pixel's width in grid cells is known), not with `fwidth`: derivatives inside `light()` are not
  safe, since it can run in non-uniform control flow. It is a screen-space pattern, so the dots
  are the same size at every zoom. Print grain, not polka dots.
- **The penumbra**: the cast shadow's filtered term (`ATTENUATION`) never scales `NdotL`, which
  would grey its edge and fringe it with the mid band. Its complement, linearly between
  `PENUMBRA_DARK` (0) and `PENUMBRA_LIT` (1), thresholds the halftone's own dot grid
  (`shadow_cover()`): the shadow band's dots grow from nothing to the whole cell across the
  penumbra, so a shadow's edge is drawn as a dot screen, the shadow band with its halftone
  inside them and the surface's own band between them. The edge's width is the filter's
  footprint, about two shadow texels, so it follows the texel: at 720p about 7 px at the
  closest zoom (size 10), 5 px at size 16 and at the start (24), and 4 px at the widest (44).
  The shader cannot widen it: its window already spans the whole filtered term. The ground and
  the terrain share `light()`, so every surface's shadow edge matches. The specular disc is cut
  where the shadow covers.
- **Cel specular**: on glossy surfaces only (glass, metal trim): a hard-edged disc where NdotH
  passes 0.92, white at 0.35, in the lit band.
- **Emissive surfaces** (flag unlit): pure emission, full tint: no bands, no halftone. A lit
  surface glows by the texture's alpha (glass 0.3, a screen's rows, a crystal's facets).

There is no rim light: with the orthographic camera a fresnel rim falls under the ink outline,
which already lifts every silhouette off what is behind it.

**The sky** (`sky.gdshader`, a `ShaderMaterial` in the environment's `Sky`, background `BG_SKY`):
deep space (`SPACE`, `0D0B1A`) with one faint band of nebula haze, `TERRAIN` violet at most 16 %
over it, broken into clouds by two octaves of value noise, and a sparse field of small hard-edged
stars, about 0.8 % of the sky, white and pale cyan (`ENERGY` mixed 55 % towards white): dots of two sizes and, the largest, four-pointed
comic sparkles. Nothing moves. The terrain
ring hides it at every zoom on screens up to about 2.87:1, so it shows only beyond the ring on
wider screens (**Environment**). The camera is orthographic, and for one the renderer hands the
sky shader the direction `basis * (x, y, -1)` at a point x, y world units from the view's middle,
so the shader draws the sky on the view's plane (`view_basis`, from `IsoCamera`'s fixed angle,
turns the direction back into x and y): it lies still behind the panning ground like a sky at
infinity and scales with the zoom, at which it shows only near the widest, a world unit about
16 px. It lights nothing: the ambient light is a colour, reflections are off
(`REFLECTION_SOURCE_DISABLED`) and its radiance map is the smallest. It costs one hash, two value
noises and a few dozen instructions per background pixel, and no texture.

Engine notes, each learned the hard way: `light()` may not `return`; the renderer hands
`COLOR` to the shader already in linear (converting it again crushes dark tints to black);
`PROJECTION_MATRIX[1][1]` is negative when the renderer draws into a render target, so take its
`abs()`; never enable `force_vertex_shading`, which skips `light()`.

## Ink outlines

Every mesh with an outlined part has a second mesh, `LowPolyMesh.to_outline_mesh()`: the same
triangles of every part whose `Surf` has `outline` on, with the face normals averaged by position
across the whole mesh (weighted by each corner's angle), so the hull stays closed at the hard
edges of a flat-shaded box. `ink.gdshader` (`cull_front, unshaded`) pushes each vertex out along
that normal and draws the back faces in ink (`INK`, `1B1A2E`, never black):

- The line is `ink_px` (2.2) pixels at a 720 px viewport height and scales with the viewport
  height. The camera is orthographic, so that is a share of its vertical extent:
  `ink_px * 2 / (720 * abs(PROJECTION_MATRIX[1][1]))` world units.
- The push never takes a vertex below the ground (world y = 0) unless it already was, so a bottom
  edge does not dip into it. This assumes instances turn only about Y and scale uniformly, as all
  do.
- The outline is its own `MeshInstance3D` with `cast_shadow` off: every surface of a
  shadow-casting instance also draws into the shadow map.
- Very thin parts (rods under 0.06 units, antenna wires) take `outline = false`; end them in a
  bulb or a plate that is outlined instead.
- Parts flagged FLICKER, JITTER or HOLO (`Surf.NO_OUTLINE`) are never outlined, whatever their
  `outline` says: a spark or an arc is too small and too quick for a line, and a hologram is
  see-through.
- The outline mesh carries each part's UV2 (its flags) and colour (its phase in the alpha), and
  `ink.gdshader` moves each vertex as the body's shader does (BOB, JITTER, from
  `effects.gdshaderinc`) before the push, so an outline never comes off a bobbing part. It takes
  the instance's scale from the length of its basis's X axis, so a part tilted by a swing keeps
  its line width.
- Interior lines (panel seams, hatches, plate edges) come from the textures. A part sitting on
  another gets an ink contact line where its outline shows against the part below.

## Colour

Every value is sRGB; a tint multiplies a near-white layer. The constants are on `MaterialKit`.

| Role | Value | Constant | Where |
| --- | --- | --- | --- |
| Ink | `1B1A2E` | `INK` | outlines, texture seams |
| Hull light | `E8E4DA` | `HULL_LIGHT` | primary building skin (warm white) |
| Hull mid | `9AA3B8` | `HULL_MID` | secondary masses |
| Hull dark | `4A5168` | `HULL_DARK` | undersides, mechanical parts |
| Gunmetal | `353B4D` | `GUNMETAL` | barrels, legs, pipes |
| Concrete | `8E8A95` | `CONCRETE` | foundation pads |
| Core gold | `F2B134` | `CORE_GOLD` | Command Center trim, the Gold tier's trim on every type, the selected outline |
| Core glass | `7FE7FF` | `CORE_GLASS` | domes, windows |
| Metal (resource) | `3FC9C0` | `METAL` | metal extractor and silo accents |
| Crystal (resource) | `E2A4FF` | `CRYSTAL` | crystal harvester and silo accents (HUD `e2a4ff`) |
| Antimatter | `B48CFF` | `ANTIMATTER` | siphon and vault accents (HUD `b48cff`) |
| Army orange | `FF7F11` | `ARMY` | army category accent |
| Defence red | `E63946` | `DEFENCE` | defence category accent, the invalid ghost |
| Hazard yellow | `FFD60A` | `HAZARD` | traps, hazard stripes, warning lights |
| Wall slate | `6B7FA3` | `WALL` | wall segments |
| Energy cyan | `58E8FF` | `ENERGY` | shields, energy fields, wall tops at high level, the valid ghost |
| Nanite green | `8CFF5A` | `NANITE_GREEN` | nanite foundry goo and nanite-themed glows |
| Arc blue | `5B8CFF` | `ARC_BLUE` | arc tower coils and electric effects |

The field's and the terrain's roles, and rock, are in their own table below.

A building uses hull light or hull mid for its main mass, gunmetal or hull dark for mechanical
parts, its category accent on one or two surfaces, and one emissive element in its accent colour.
From the Gold tier, the levels unlocked at Command Center 5 (**Tiers**), every type adds core gold
trim (edges, rings, caps), so a building of that band reads as such from across the base. Under the warm key light every lit colour leans warm.

The field's and the terrain's roles are picked so that, under the warm key light and over their
textures, they render as the art direction asks: each is bluer and more saturated than it shows.
The rendered column is the average over flat ground at the widest zoom (the `environment`
scenario's widest shot, measured in HSL): the field as a whole, ground and marks together (the
grid is hidden outside building), over each quarter of it clear of the HUD and the buildings; and
the ring's flat dust. The field renders in the ring's shade, within 0.01 in L and 0.02 in S (the
`environment` scenario checks it, rendered, each spot's average divided by the large value noise's
factor there, which the field and the ring share but which lies darker at the field's four spots
than at the ring's two): it reads as a plain of its own by its marks, and the kerb is its border,
not its tone. Where they meet there is no step: at the start zoom, focused 20 in from the field's
far corner along each axis, half a cell inside the field's
edge and half a unit outside it, along each of the two sides far from the camera, the ground's
median colour (marks excluded) differs by under 3/255 in every channel (checked there too). The
buildings' hulls are the lightest things on screen.

| Role | Constant | Value | Rendered | Where |
| --- | --- | --- | --- | --- |
| Field dust | `FIELD` | `4733C9` | the field: `5646AD` (L 0.47 to 0.48, S 0.42) with the value noise divided out; `5142A3` to `5545AB` at the four spots as drawn | the field's dust, covering the ground at 60 %; the most saturated, as the plate tint greys it |
| Field light | `FIELD_LIGHT` | `746CDB` | | the lit sides of the field's marks (crater walls, pebbles, shards), its light tones |
| Field dark | `FIELD_DARK` | `443BA2` | | the shadow sides of the field's marks, its dark tones (crater and pit floors) |
| Field plate | `FIELD_PLATE` | `6D6CC0` | | the levelled ground under the dust (a cooler grey-violet) |
| Terrain | `TERRAIN` | `564AC5` | the ring's flats, marks and grain included: `5346A2` to `5747AE` (L 0.46 to 0.48, S 0.40 to 0.42) | the ring's dust |
| Terrain light | `TERRAIN_LIGHT` | `7A73E3` | | the lit side of slopes over 25 degrees; the light sides and tones of the ring's marks, the lit sides of its ripples |
| Terrain dark | `TERRAIN_DARK` | `3E388C` | | crater floors and the shadow side of slopes over 18 degrees; the dark sides and tones of the ring's marks, the shaded sides of its ripples, the strata's undersides |
| Rock | `ROCK` | `50619B` | | slopes over 35 degrees (crater walls, mesa sides), the scenery rocks' sides, the crystal harvester's rock bed |
| Rock lit | `ROCK_LIT` | `768BC9` | | the scenery rocks' chamfers and tops; the strata's lit top edges, light bands and outcrop plates |

The field's roles were moved to the ring's shade from a lighter, paler plain that rendered
`5F52A5` to `6355AC` (L 0.48 to 0.50, S 0.34): all four scaled per channel, in linear light, by
the ring's flats over the field's average, so the marks keep their contrast against the plain.
Measured over the same four quarters and two flat stretches of the ring (`5646AC`, `5747AD`), the
field now averages L 0.477, S 0.417 against the ring's L 0.478, S 0.420. The ring's row was re-measured when its
surface was drawn (marks, ripples, strata): over the same three stretches of flat ring the
untextured ring rendered `5547A6` to `5A4CA8` (L 0.46 to 0.48, S 0.38 to 0.40), and the field's
four quarters rendered pixel for pixel as before. The field's darkening towards its edge (10 %
from half way out) then left it darker than the ring's first unit, a step of 13/255 along the
whole edge; with the darkening gone it was 6 to 7/255 lighter, as its roles had been matched to the
ring's at spots where the value noise lies 3 % darker on the field. `FIELD` and `FIELD_PLATE` were
scaled down to the ring's tone at the edge (within 1/255), which with the noise divided out is the
ring's flats' shade as well (L 0.473 against 0.476). The perimeter's kerb is `CONCRETE`, its
pylons `HULL_MID` with `ENERGY` lamps and `HAZARD` beacons, its fence `ENERGY`; the outcrops are
`CRYSTAL`, `METAL` and `ANTIMATTER`.

## The material kit

One `Texture2DArray` of twenty 256×256 RGBA8 layers. RGB is the albedo: near-white greys (0.78
to 1.0; the bands layer's ground is 0.62, the obsidian's about 0.38 and the veins' 0.35) with ink-coloured lines for the layers a tint multiplies, real colours for the fixed ones,
which are tinted white. A is the emission mask. Ink lines are about 3 px; rivets are 5 px discs
with a 1 px highlight. Every layer tiles seamlessly.

| # | Name | Content | Tint |
| --- | --- | --- | --- |
| 0 | `flat` | plain, a hint of paper grain | yes |
| 1 | `hull` | large panels, ink seams, a rivet in each corner | yes |
| 2 | `hull_dense` | smaller panels, slotted vents, more rivets | yes |
| 3 | `plate` | bolted armour plates with chamfer highlights | yes |
| 4 | `vent` | louvred grille | yes |
| 5 | `pipe` | ribbed bands across V, which wrap around a cylinder | yes |
| 6 | `grating` | floor grating | yes |
| 7 | `concrete` | slab with an expansion joint and grit | yes |
| 8 | `hazard` | yellow and ink diagonal stripes | white |
| 9 | `solar` | blue photovoltaic cells | white |
| 10 | `glass` | pale glass with a diagonal streak; emission 0.3 | yes |
| 11 | `glow` | emission 1.0 with faint stripes | yes |
| 12 | `screen` | a display: ink with rows of lit segments, emission on the rows | yes |
| 13 | `crystal` | faceted shards with a glow towards each facet's middle | yes |
| 14 | `rock` | four big plates in three tones with faint seams, three bold ink cracks | yes |
| 15 | `regolith` | dust: large soft blobs in two tones, two pebbles, no ink (unused since the terrain took its own shader) | yes |
| 16 | `bands` | a broad band across V, a third of the repeat, at 1.0 on 0.62 (darker than the other layers' greys, so the band reads as a pulse), ink-edged on its leading side (towards smaller V, where a FLOW below 0.5 carries it); emission 1.0. For a beam or a conduit, where a flow reads as pulses travelling | yes |
| 17 | `chrome` | polished plating: near-white (about 0.9) plates brushed in fine streaks along U, a lit chamfer along each plate's top and a shaded one along its bottom, ink seams, no rivets. GLOSSY, tinted white or pale cyan (`Parts.CHROME`) | yes |
| 18 | `obsidian` | dark glassy armour (about 0.38, so a tint stays dark): large faint facets, each a tone of its own with a pale glint along its edge towards the light, hairline ink cracks. GLOSSY (`Parts.OBSIDIAN`) | yes |
| 19 | `veins` | a dark ground (0.35) with bright branching channels running along V, ink-rimmed, their emission beaded with a pulse every quarter of the repeat, so a FLOW surface on it reads as energy running through the veins (`Parts.VEINS`); the ground does not glow | yes |

At the default UV scale a layer covers one world unit. Large surfaces take `hull` or `plate`:
`hull_dense` is for parts under a unit, and on a large one it aliases into a checker at the widest
zoom. A large, plain area can ask for a smaller `uv_scale`.

`MaterialKit.texture()` builds the array on first use: it loads each layer as an `Image` (the PNGs'
`.import` files use the image importer, so `load()` returns an `Image` in exports), generates its
mipmaps (the Compatibility renderer makes none for a layered texture) and calls
`create_from_images`. That takes about 12 ms on the development Mac, once.

**Regenerating.** `tools/gen_textures.gd` draws every layer, and then the field texture and the
terrain's rock texture (**Environment**), with its own wrapped line, disc, ring, polygon, lean and
value-noise helpers, each image from its own seed through `SeededRng`, so two runs write
byte-identical PNGs. After an import (the gate does one):

```
$GODOT --headless --path . -s res://tools/gen_textures.gd
```

Commit the PNGs that changed. The gate does not run the generator.

**Adding a layer.** Append it, never insert, so existing indices hold: a `_draw_<name>()` in the
generator and the name at the end of its `LAYERS`, and the same name at the end of
`MaterialKit.Layer` and `MaterialKit.LAYERS`; the field and the rock texture draw from seeds of
their own (`FIELD_SEED`, `ROCK_SEED`), so they stay as they are. Run the generator, then the
gate, which imports the new PNG and writes its `.import`; edit that file to `importer="image"` as
the others are, run the gate again, and commit the PNG and its `.import`. The gallery checks that no vertex names a layer
past the last.

## Surfaces: `Surf`

`Surf.make(layer, tint, uv_scale = 1.0, flags = Surf.LIT, smooth = false, outline = true,
phase = 0.0)` says how a part is painted: a `MaterialKit.Layer`, an sRGB tint, texture repeats
per world unit, the flags, whether the part is smooth shaded, whether it is outlined, and the
phase of its animation. The flags are bits, combined with `|`: `Surf.LIT` (0), `Surf.UNLIT` (1,
emissive), `Surf.GLOSSY` (2, with the cel specular), and the effects in **Animation** (`PULSE`,
`BLINK`, `FLICKER`, `FLOW`, `FLOW_U`, `BOB`, `JITTER`, `HOLO`). A `Surf` is shared and never
changed once made: make one per look, keep it in a `static var`, and pass it to every part that
looks so; `surf.phased(phase)` returns a copy with another phase, for lamps that chase or sparks
that flicker apart. A phase is stored at 1/254 steps (**Animation**).

`Parts` (`models/parts.gd`) names the common ones: `CONCRETE_PAD`, `HULL_LIGHT`, `HULL_MID`,
`HULL_DARK`, `GUNMETAL` (smooth), `HAZARD`, `GOLD_TRIM` (glossy), `GLASS` (glossy, smooth),
`ROD` (smooth and not outlined, for rods and wires under 0.06 thick: **Ink outlines**).
`Parts.surf(name)` turns the colour names the first models were written with into kit surfaces
through its `SURFACES` table (hulls on the hull layer, metals on the plate layer, the glows unlit
on the glow layer in their accent colour, hazard on the hazard layer); new models pass a `Surf`.

## `LowPolyMesh`

`LowPolyMesh` builds a model's meshes out of parts. A part is placed by `pos`, the centre of its
base (an orb's centre), and `rot`, Euler degrees applied Z, then X, then Y; its size arguments
scale it. Round parts are lathes, a profile of (radius, height) points spun around +Y. Bottom
faces are left out of boxes and lathes, since the camera always looks down.

| Builder | What |
| --- | --- |
| `triangle(a, b, c, surf)`, `polygon(corners, surf)` | single faces, counter-clockwise from the front |
| `box(size, pos, surf, rot)` | a box on its base |
| `box_chamfered(size, chamfer, pos, surf, rot)` | a box with its top and vertical edges bevelled; the bottom edges stay square, since a part stands on something (30 triangles) |
| `wedge(size, pos, surf, rot)` | a ramp, full height along −Z |
| `strut(from, to, width, surf)` | a box from one point to another |
| `prism(bottom_radius, top_radius, height, sides, pos, surf, rot, from_deg, to_deg)` | a cylinder or a tapered one, capped; the angles sweep part of it, as `lathe` does |
| `cone`, `pyramid` | a cone, a four-sided cone |
| `dome(radius, height, sides, rings, pos, surf, rot, from_deg, to_deg)` | a hemisphere squashed to `height`; the angles sweep part of it, as `lathe` does |
| `orb(radius, sides, rings, pos, surf, rot)` | a sphere centred on `pos` |
| `ring(inner_radius, outer_radius, height, sides, pos, surf, rot, from_deg, to_deg)` | an annulus with walls, open underneath; the angles sweep part of it, as `lathe` does |
| `tube(inner_radius, outer_radius, height, sides, pos, surf, rot, from_deg, to_deg)` | a hollow cylinder closed at both ends, for pipes and bores turned on their side; the angles sweep part of it, as `lathe` does |
| `disc(radius, sides, pos, surf, rot)` | a flat polygon facing up |
| `lathe(profile, sides, pos, surf, rot, from_deg = 0.0, to_deg = 360.0)` | the general round part; given angles less than a turn apart (degrees from +X towards +Z, as `Parts.around`), it sweeps only that arc, in the share of `sides` steps the arc spans, and closes each end with a flat face, outlined like the rest: the profile, closed through the axis when one of its ends is on it (keep that section convex). U still comes from the angle. A half-vault: a `prism` turned onto its side and swept over its upper half |
| `turn(offset, rot)` | an offset turned like a part, to place a part on a turned one |

`sides` goes up to 24 and `rings` to 8 anywhere. `to_mesh()` is the body (VERTEX, NORMAL, UV,
UV2, COLOR): its opaque parts on `MaterialKit.toon()` and, when there are any, its HOLO parts in
a surface of their own on `MaterialKit.holo()` (with no opaque part, the holograms are surface
0). `to_outline_mesh()` is the outline (VERTEX, NORMAL, UV2, COLOR) on `MaterialKit.ink()`, null
when nothing is outlined, and `triangle_count()` the body's triangles, both surfaces. Both meshes
are unindexed triangle lists. `to_arrays()` (the opaque parts only) and `to_outline_arrays()` are
the same as surface arrays (the outline's empty when nothing is outlined), for a caller that
merges meshes itself, as `WallMesh` does.

- **UVs**: a face's corners in the part's own space, before `pos` and `rot`, projected along the
  dominant axis of its normal, times `uv_scale`. Round parts take U from the angle around their
  axis, a whole number of repeats around (about one per world unit at their widest radius), so
  bands wrap without a seam, and V from the distance along the profile; caps and discs are polar
  (V the radius). UV2 is (layer, flags); the vertex colour is the tint, its alpha the phase.
- **Smoothing**: a smooth part's faces that meet at under 40° share normals, averaged by position
  within the part and weighted by corner angle; caps, discs and sharper edges (chamfers, 45°;
  box corners, 90°) stay hard. A 16- to 24-sided cylinder shades as a curve; an 8-sided one
  (45° between faces) stays faceted. A flat part keeps a normal per face.

## Models

`BuildingModels.create(type, level, size, tier)` dispatches to one static `build_<type>(p: Parts,
level: int)` in its category's file under `src/game/models/` (`core.gd`, `resources.gd`,
`army.gd`, `defense.gd`, `traps.gd`), but for the wall, a defence type whose builder has a file
of its own (`walls.gd`); `MODELS` gives each type the footprint its
models are built for and its level count. `Parts` holds the model while it is built: `tier`, the
level's theme (**Tiers**), set before the builder runs; `body` (a `LowPolyMesh`), up to three
moving parts, four at Crown (`moving(pivot, motion)`, **Animation**), and the shared helpers. A
model is a `Node3D` with the body's `MeshInstance3D` and its outline's beside it, and a `Node3D`
per moving part at its pivot carrying `MOVE_META` (its `Motion`), with the part's mesh and its
outline under it. That is at most **eight** `MeshInstance3D`, ten at Crown: the body and its
moving parts, each with an outline (`OUTLINE_META`, no shadow); a moving part made only of
parts that are never outlined has no outline instance. Meshes are built once per type, level
and tier and cached; `BuildingModels.instantiate(parts)` assembles an uncached model from parts a caller
built itself (the `effects` rig). The contract any model keeps, built or imported:
origin at the footprint centre on the ground, +Y up, fitting inside `size × size` cells.

The `model_gallery` harness scenario lays out every type and level and checks each, built for
its level's tier: one body instance and up to `Parts.max_moving(tier)` more, each with its outline
instance on the ink material casting no shadow unless all its parts are never outlined, every
layer within the kit, the body triangles (both surfaces) within its footprint's and tier's budget,
and the extent and the height over every moving part's whole motion within the bounds below. Its
detail shots at the closest zoom are where a model is judged.

### Tiers

A level's **tier** (`Parts.Tier`: `BASE`, `GOLD`, `CHROME`, `OBSIDIAN`, `CROWN`) is its theme,
set by the Command Center band it is unlocked in, so every type's levels of one band share a
look and a maxed base shares one too. `BuildingModels.tier_of(catalog, type, level)` takes the
Command Center level the level requires (`requires_cc` in the data, 1 when it has none) through
`tier_for_cc`, the one mapping; the Command Center alone takes its own level, since its level k
requires k − 1 (its level 5, which requires 4, is Gold; its level 10 is Crown). Every caller of
`create`, `BuildingView.setup` and `WallModels.piece` passes it (a required parameter).

| Tier | Levels requiring CC | Look | Shared elements |
| --- | --- | --- | --- |
| Base | 1–4 | hull-light masses, the category accent, gunmetal machinery | — |
| Gold | 5 | core-gold trim on rims, caps and crowns | gold trim |
| Chrome | 6–7 | polished chrome plating with brushed highlights, cyan light strips; more mass, a second storey or mast; stronger emissives | chrome plates, cyan strips, a chrome cap on the signature element |
| Obsidian | 8–9 | dark obsidian armour veined with violet antimatter energy (FLOW), crystal inlays; hovering parts (rings, plates) on HOLO or BOB; taller | obsidian plates, violet veins, one hovering element |
| Crown | 10 | an obsidian base under gold filigree, a violet antimatter core glowing in the body, a crowning element (spire, halo, banner or beacon beam) and an escort, a fourth moving part that patrols or orbits | gold filigree, antimatter core, crown, escort |

The rule: **surfaces follow the tier, geometry follows the level.** A builder picks the tier's
surfaces from `p.tier` (`p.tier >= Parts.Tier.GOLD` for gold trim, so a higher tier keeps the
gold below it) and its parts from the level, so a level's geometry never depends on the data; a
gold part a level adds stays on its level test, painted by the tier. Every level unlocked at
Command Center 5 is therefore Gold tier, the band's cohesion, and the progression within the
band is geometry: gold follows the band, not the top level, so the Drydock 1, EMP Tower 1–2,
Railgun 1–2, Ion Beam 1, Orbital Cannon 1, Flak Cannon 3, Arc Tower 3 and the Heavy Fabricator
3's stacks wear it. The Drone Bay 1, the Proximity Mine's L3 and the Gravity Trap's L2, which
require less than Command Center 5, are Base: the booth's roof is hull mid and the traps' gold
rings hull-mid casing there (the Drone Bay gained its gold again at its Crown level 3, in the
collectors batch).
The Command Center's gold ring round its dome is its signature at every level, not tier trim.
Meshes are cached by type, level and tier, so a level above a type's modelled top, which shows
its top model, is painted for its own tier.

**The style at every tier** (`docs/plans/upgrade-pass.md`, §2a): every level is drawn in the
comic style above, chunky readable masses, a few big shapes before many small ones, bold
saturated accents, ink outlines and glows that pop. The tiers change the palette, never the
style: **Chrome** is bright white with a cool cyan cast and cyan light strips, never grey or dull;
**Obsidian** is ink-black glass kept vibrant by saturated violet veins, bright glints and gold or
cyan accents, at least a third of a model's visible surface bright or glowing, never a muddy or
realistic metal; **Crown** is the loudest, gold filigree, a violet core, a crown and an escort,
bigger and bolder than anything below it. A level that reads grim, grey, realistic or cluttered
fails its review whatever its budgets say; the rendered gallery shots are judged for this first.

The shared elements are named once on `Parts`, for every model batch:

| Tier | Surface or helper | What |
| --- | --- | --- |
| Gold | `GOLD_TRIM`, `GOLD_ROUND` | core gold on the flat layer, glossy; flat and smooth |
| Chrome | `CHROME`, `CHROME_ROUND` | the chrome layer in `CHROME_TINT` (`E6F4FF`, a cool pale cyan-white, so it parts from the cream hull-light), glossy; flat and smooth |
| Chrome | `CYAN_STRIP` | the glow layer in `ENERGY` cyan, unlit, PULSE: light strips |
| Obsidian | `OBSIDIAN`, `OBSIDIAN_ROUND` | the obsidian layer in `OBSIDIAN_TINT` (`8A6AD8`, a deep ink violet, so it reads as dark violet glass), glossy; flat and smooth |
| Obsidian | `VEINS` | the veins layer in `ANTIMATTER` violet, unlit, FLOW at 0.7: energy running through veins |
| Crown | `FILIGREE` | the bands layer in core gold at 2 repeats a unit, glossy: gold filigree over the obsidian |
| Crown | `CORE_GLOW` | the glow layer in `CORE_GLOW_TINT` (`9B5CFF`, a saturated violet), unlit, PULSE: the antimatter core |
| Crown | `escort_drone(p, radius, height, rate, centre = Vector3.ZERO, scale = 1.0)` | a small quadrotor guard drone, a third the size of the drone bay's (about 0.12 across from its centre), its rotors unlit screen-layer blurs (FLOW_U, no hologram surface): 166 body triangles |
| Crown | `escort_skiff(p, radius, height, rate, centre = Vector3.ZERO, scale = 1.0)` | a hover skiff: a chamfered hull, a glass canopy, two engine pods and a glowing underside (PULSE), every part bobbing together (about 0.3 from its centre to its engines' ends): 170 |
| Crown | `escort_troopers(p, radius, height, rate, centre = Vector3.ZERO, scale = 1.0)` | two solid troopers in the cadets' proportions, army orange plating, a hull-light helmet with an `ENERGY` visor and a rifle, each `TROOPER_HEIGHT` (0.8) tall so it reads as a soldier at the gameplay zoom, one 0.5 behind the other on the round (each about 0.26 from its centre to its arms): 260 |

Each escort is a moving part built in its own space, the Crown tier's fourth: it spins about +Y
through the footprint's centre (or through `centre`, an optional point on the ground, where the
building's round lies off its middle) at `rate` radians a second, its figure `radius` out and
`height` up and `scale` times its own size (an optional factor, for a big building's escort),
facing its heading, and is at most 300 body triangles. A caller keeps the round plus
the figure's reach within the extent. The `kit_swatches` harness scenario (`tools/harness/README.md`)
shows every tier surface on a cube and a drum in a row, and the three escorts orbiting a 3×3 pad:
the batches' reference.

### Shared shapes

The shapes more than one category builds are helpers on `Parts`, for any model file to use. A
new one goes there under a generic name, after a look at this list for one that already does the
job; a helper is added, never renamed or removed.

| Helper | What |
| --- | --- |
| `PAD_HEIGHT`, `PAD_INSET` | the foundation pad's height (0.12) and its inset from the footprint's edge (0.1) |
| `foundation(m, size)` | the chamfered concrete pad under the whole footprint of `size` cells, inset `PAD_INSET`, `PAD_HEIGHT` high: what every building stands on |
| `facing(dir)` | the rotation (Euler degrees, as the parts take it) that turns a part's +Y onto `dir` |
| `pipe(m, from, to, radius, surf, sides = 16, capped = true)` | one straight round pipe, capped at `to` unless that end is inside something |
| `pipe_run(m, points, radius, surf, sides = 16)` | a pipe through `points` with a ball elbow at each bend |
| `beam(m, from, to, width, surf, chamfer = 0.03)` | a chamfered square beam between two points: girders, booms, legs, rails |
| `tank(m, radius, height, pos, surf, chamfer = 0.06, sides = 16)` | a round tank whose top edge is chamfered into a flat lid |
| `dish(m, radius, depth, pos, surf, rot)` | a dish opening along +Y before `rot`, the centre of its back on `pos`; 24 segments |
| `landing_light(m, pos, radius, lens, housing = GUNMETAL)` | a squat housing with a glowing lens dome |
| `mast(m, foot, height, bulb_radius, bulb)` | a thin `ROD` pole ending in a bulb, which carries the outline the rod is too thin for |
| `drum(m, radius, height, chamfer, sides, pos, surf, rot)` | a cylinder whose top edge is bevelled `chamfer` wide, turnable: a turret ring, a tilted housing; with 8 sides and `OCTAGON`, an armoured octagon |
| `torus(m, major, minor, sides, segments, pos, surf, rot)` | a closed ring of round section resting on `pos` (its bottom at `pos.y`): coils, coronas, gyro rings; 10 or more `segments` for a ring that shows |
| `HULL_LIGHT_ROUND`, `HULL_MID_ROUND`, `HULL_DARK_ROUND`, `GOLD_ROUND` | the hull and gold surfaces smooth shaded, for drums, tanks, collars and caps |
| `ladder(m, foot, height, width, yaw, surf)` | two rails and a rung every 0.16 up a wall, its face turned `yaw` degrees from +Z; on `ROD`, too thin to ink |
| `dome_seam(m, radius, height, pos, degrees, surf)` | a seam up a dome of `radius` and `height` standing on `pos`, at `degrees` round it: a chain of thin struts just proud of the surface, from its foot to within 0.15 of the axis |
| `on_sphere(radius, at)` | the point `radius` from a sphere's centre at `around()` angle `at.x` and elevation `at.y` (degrees) |
| `chase(k, count)` | the BLINK phase of lamp `k` of `count` lit in turn, lamp 0 first: a chase |
| `spark(tint)`, `current(tint, phase)` | new surfaces: a crackling arc's (unlit glow, FLICKER and JITTER, so never inked) and a current's (the pipe layer's bands, unlit, FLOW at `phase`: above 0.5 towards a pipe's far end) |
| `arc(m, from, to, segments, kink, surf)` | a crackling arc on a `spark` surface: `segments` three-sided tubes of `ARC_RADIUS` (0.02), the corners between them kinked `kink` to either side in turn, so JITTER has corners to shake; give each arc its own phase |
| `puffs(m, mouth, phase, count = 3, sides = 10, rings = 4)`, `SMOKE` | `count` hologram smoke puffs (`SMOKE`: HOLO and BOB, pale `HULL_LIGHT` smoke, as HULL_MID is too faint on the violet ground), orbs of `sides` and `rings`, over a stack's `mouth`, growing as they rise, each bobbing out of step from `phase` |

### Model table

One line per type, in roster order: the signature element that names it from across the base,
its animation (moving parts and surface effects, **Animation**), and its top level's body
triangles as the gallery counts them.

| Type | Signature element | Animation | Top level, body triangles |
| --- | --- | --- | --- |
| `command_center` | glass dome ringed in gold on a tall drum over a stepped foundation, a hazard-striped hangar door; wings, a ring of rooms, a hologram of the base's planet over the dome, a violet containment ring and a gold beacon spire as it grows; from L6 the dome rides a tower of gold-lipped storeys (chrome, obsidian from L8, gold filigree at L10) and the wings take armoured caps, up to a crown spire with a hologram beam at 6.94 | spin: the comms dish on its pylon (carried up beside the lifted dome from L6); from L3 spin: the hologram's tilted HOLO ring round its violet HOLO + BOB globe (no outline). BLINK: the door's four lamps (a chase), the masts' bulbs; FLOW: the wing and room screens; PULSE: the hologram's projector lens; L4 FLOW_U on the containment ring (crystal layer), PULSE on its clamp nodes; L5 PULSE on the beacon. L6 spin: a second, smaller dish on a wing; BLINK: the landing lamps chase in two rings; PULSE: the cyan strips. L7 FLOW up the cyan conduits; three HOLO moons turn with the hologram's ring. L8 FLOW on the veins up the storeys and caps; PULSE on the crystal inlays and shards; BOB: an obsidian ring hovering over the dome's gold ring, FLOW on its veins and PULSE on its violet rim. L9 a second containment ring over the first, its FLOW_U the other way; UNLIT + FLICKER + JITTER arcs from the spire to the dome's gold ring, under the hovering ring; a HOLO station on the hologram's ring. L10 PULSE on the antimatter core (behind HOLO violet glass) and the crown's orb, a HOLO beam over the crown; spin: a hover skiff escort circling the tower (the fourth moving part) | 9,762 |
| `drone_bay` | landing deck in a hazard ring of cyan lights, the builder drone (**Construction drone**) parked over its cradle, a control booth with a roof rimmed gold from the Gold tier (hull mid at its Base-tier L1); the drone's body, 0.42 across at 12 sides, is the one exception to the small-part side counts, and the deck lights take them (10 and 8) to keep the bay in its budget; L2 (Chrome) a chrome deck whose lights become landing strips, a raised chrome pad over the crates with a second cradle and a second parked drone (for show: builders stay one), the booth clad in chrome under a chrome roof; L3 (Crown) the deck edged in gold filigree, violet and gold strips, both drones gold-trimmed, a violet core on a gold mount over the beacon | spin: the beacon on the booth. BLINK: the six deck lights (a chase); BOB: the whole drone, idling over its cradle; FLOW_U: its rotor blurs (screen layer, unlit, not holograms); FLOW: the booth's screen. L2 BLINK: six landing strips round the rim (a chase); BOB and FLOW_U: the second drone; FLOW: a second screen on the cab; PULSE: the cyan strips across the deck and up the booth. L3 the strips BLINK violet, the beacon's lenses glow violet, PULSE on the core over it; BOB: the drones' gold trim; spin: a guard drone circling the deck (the escort) | 3,460 |
| `metal_extractor` | tripod derrick over a drill with a walking beam on its crown, conveyors carrying glowing ore into hoppers, exhaust stacks; from L6 a taller chrome derrick with cyan strips up its legs and a second ring of braces, chrome hoppers tipping ore down lit chutes into tubs, a pumpjack on the right corner from L7; from L8 obsidian over the hoppers and the engine house with crystal inlays, the ore crystal pink, violet strips; L9 an obsidian collar hovering round the derrick; L10 gold filigree on the braces, crown, hoppers and engine house, the antimatter core glowing steady and light violet over the crown and in a gold housing on the engine house's roof, up to 4.54 | spin: the drill string and its top drive; swing: the walking beam, ±12° about its pin, 2 s. FLOW: the belts (grating); PULSE: the ore nuggets and the hoppers' ore; HOLO + BOB: two smoke puffs over each stack. L6 PULSE: the cyan strips and the chutes' rails, the ore sliding down them and in the tubs. L7 swing: the pumpjack's walking beam, ±14°, 2 s, half a cycle out of step. L8 FLOW: the veins up the legs and the kelly; PULSE: the crystal inlays; BOB + PULSE: an ore crystal hovering over each hopper. L9 BOB: the collar, FLOW on its veins, PULSE on its violet rim. L10 PULSE: a violet ring round the engine house's core; spin: a hover skiff hauling ore round the rig over the hoppers and the stacks (the escort) | 4,678 |
| `crystal_harvester` | laser gantry over a cluster of glowing crystal shards; from L6 a taller chrome gantry with cyan strips and twin emitters, the shards bigger, chrome pylons (taller, with cyan strips, from L7); from L8 obsidian containment set with crystal inlays, violet vein conduits up the legs and a mega-shard crowning the cluster; L9 an obsidian ring hovering over it; L10 the beam in gold filigree, gold-capped pylons, the mega-shard glowing light violet from within (unlit and steady, the brightest thing on the model) with a core band and a gold collar over the hovering ring | swing: the focusing emitter and its beam, ±25° along the gantry, 5 s. FLOW + PULSE: the beam (pipe layer); FLICKER: the sparks at its end; PULSE: every shard, each on its own phase; L4 BLINK: the pylon lamps (a chase). L6 swing: twin emitters either side of the carriage, half a cycle apart, their beams cyan (violet from L8); PULSE: the cyan strips. L8 FLOW: the vein conduits; PULSE: the inlays and the violet containment glow; BOB + PULSE: three crystal chips hovering round the mega-shard. L9 BOB: the hovering ring, FLOW on its veins, PULSE on its rim. L10 PULSE: the mega-shard's core band; spin: a guard drone circling over the gantry (the escort) | 3,364 |
| `antimatter_siphon` | coiled torus round a glowing violet core, field pylons leaning in; from L4 the pylons grow taller each level, their heads aimed down at a larger core floating higher, chrome with cyan strips, a chrome torus of twelve coils; L5 two glowing rings round each pylon and a third capacitor; from L6 obsidian pylons with glowing violet vein panels on the faces the camera sees and an obsidian ring hovering over the core, crystal inlays at their feet and crystal crowns on their heads from L7; L8 gold filigree bands on the pylons and a halo glowing over the core in a gold ring | spin: the torus and its coils. FLOW: the coils' current (screen layer); PULSE + BOB: the core; UNLIT + FLICKER + JITTER: an arc from each pylon's tip to the core, cyan from L4, violet from L6. L4 PULSE: the cyan strips (L5 the rings, violet from L6). L6 FLOW: the vein panels (the walls' violet field); BOB: the hovering ring, FLOW on its veins, PULSE on its rim. L7 PULSE: the inlays and the crystal crowns. L8 PULSE: the halo; the loudest arcs, a second from each tip to the halo and one between each two tips; spin: a guard drone orbiting round the pylons (the escort) | 4,586 |
| `metal_silo` | squat banded tank with a glowing fill gauge and a ladder; twin tanks from L4, growing taller from L6 (their shells 1.9 to 3.0): chrome shells banded in the metal accent with cyan level gauges, a catwalk ring round each top, a pump on the pipe between them and from L7 a beacon mast on the deck between the tops; obsidian armour bands veined violet, veined risers and crystal-pink gauge lenses from L8; gold filigree bands, rims and railings, gold-capped vents and the antimatter core in a gold cage on the pump at L10 | to L5 none moving. PULSE: the gauge; BLINK: a warning lamp on each lid; L4 FLOW: liquid metal in the pipe between the tanks. L6 spin: the pump's flywheel; PULSE: the cyan level gauges, the pump's cyan belt and hub. L7 BLINK: three lamps chasing along each catwalk's side to the camera; PULSE: the cyan beacon on a chrome mast between the tanks, which the L9 gauge ring turns round. L8 FLOW on the veins round the bands and up the risers; PULSE on the gauge lenses. L9 spin: an obsidian gauge ring hovering over the deck between the tanks, BOB on all of it, PULSE on its metal-lit dial and violet rim. L10 PULSE on the core; the ring's rim gold; spin: a hover skiff escort circling over the tanks at 4.1 | 6,104 |
| `crystal_silo` | tall hexagonal tank of crystal-lit glass panels under a chamfered lid and a crystal finial; from L6 a wider container of bigger panels in a chrome frame and lid with cyan light bars between the rows, obsidian veined violet with deeper pink panels and crystal inlays round the plinth from L8, a gold filigree frame with violet light bars at L10 under a mega crystal lit from within by the violet core, a gold finial on its tip | spin: the finial, 0.5 rad/s (in a chrome collar from L6). PULSE: the finial and every glass panel, each on its own phase. L6 PULSE: the cyan light bars. L7 PULSE: cyan strips up the posts and six lamps in a wave round the lid. L8 FLOW on the veins; PULSE on the inlays. L9 spin: a crystal crown hovering over the finial, counter-turning, BOB on its obsidian ring and shards, PULSE on the shards. L10 PULSE on the core inside the HOLO mega crystal and on the violet bars; the crown round the crystal on a gold ring; spin: an escort drone circling the container | 2,612 |
| `antimatter_vault` | armoured chamfered cube with a round vault door, violet seams and a containment pylon on each corner, the pylons growing every level; from L4 chrome plating on the cube and the pylons with cyan seams up them, an antimatter core floating in a cradle on a chrome lid; obsidian pylons, skirt and lid veined violet, crystal inlays at the pylons' feet and containment rings hovering round the core from L6; gold filigree over the pylons' heads and round the lid and a halo over the core at L8 | to L5 none moving. FLOW: the corner seams, FLOW_U: the seam band (screen layer); PULSE: the pylons' cells; BLINK: their tips (a chase); L3 UNLIT + FLICKER + JITTER: arcs between adjacent tips. L4 PULSE + BOB: the core; PULSE: the cyan seams; the arcs cyan. L5 cyan arcs from each tip to the core. L6 the arcs violet; FLOW on the veins; PULSE on the inlays; spin: an obsidian containment ring round the core, tilted, BOB, FLOW on its veins and PULSE on its rim. L7 spin: a second, wider ring tilted the other way, counter-turning, so the pair reads as a gyroscope. L8 PULSE on the core, raised on a gold pedestal, in the violet core's glow, and on its halo; a second, wider arc between each pair of tips; spin: an escort drone circling over the pylons' caps and the halo | 5,168 |
| `hangar` | barrel-vaulted bays with orange ribs and hazard-striped doors, a glass-cabbed control tower; from L6 the tower grows (its cab 2.2 to 3.4 up) and the apron's lamps stand in two rows before the main door: chrome roofs with cyan ribs, a chrome tower with cyan strips and a bigger radar dish, a skiff parked on a pad on the apron, a third, small bay on the apron and a gallery round the tower from L7; obsidian walls, tower and violet-veined doors, ribs glowing violet, crystal beacons on the apron and crystal inlays on the tower from L8, a landing ring hovering over the skiff and a second gallery at L9; at L10 an obsidian roof under gold filigree ribs with the core glowing in broad light-violet bands along its crests, filigree banners on the gables and bands up the tower, a violet core beacon on a gold spire | slide: the main bay's door, up under a hood over its lit inside (FLOW); spin: a radar on the cab's roof; swing, from L4: the big roof dish. The apron lights BLINK in a chase, the cab's glass PULSEs. L6 the two rows of lamps chase apart (BLINK, orange and cyan), PULSE on the cyan ribs, strips and the skiff's nozzles. L8 FLOW on the veined doors and the tower's veins; PULSE on the violet ribs, the crystal beacons (in a chase) and inlays. L9 BOB: the landing ring, PULSE on its violet rim, a HOLO ring over it. L10 PULSE on the banners' emblems and the beacon's core; spin: a hover skiff escort at 1.5 times the helpers' size, circling out over the apron and the bays at 3.3 (its round centred towards the apron) | 7,214 |
| `cadet_academy` | a training ground for human cadets: a barracks hall of orange bunk windows behind a drill yard, a hologram cadet standing to attention on an octagonal parade plinth, holographic target posts and a flagpole with a stiff orange pennant; a gimballed flight-simulator pod, a lecture room on the hall and a watchtower as it grows; from L6 the watchtower grows 0.15 a level: a chrome hall, plinth, lecture room and tower, a cyan band between the window rows, a second, still simulator pod behind the plinth's left with a second column of target posts in front of it, so the yard's front stays open; a third storey with a broad window band from L7; an obsidian hall and tower, violet vein strips down its front, the band violet and crystal shards on the tower from L8; a drill drone hovering over the yard at L9; at L10 gold filigree on the trims and round the plinth, the band in the core's bright light violet, a gold ring round the cadet under a solid light-violet halo, a violet core beacon on the tower and a gold parade circle in the yard's front corner | spin: the HOLO cadet, slowly about the vertical over the plinth (a part with no outline); spin, from L2: the simulator's two gimbal rings about a tilted axis; swing, from L4: the tower's searchlight, ±25° (6 s), its HOLO beam over the yard. The bunk windows PULSE each on its own phase, the HOLO target silhouettes BLINK on in turn, the cadet BOBs over the plinth's PULSE lens, the finial lamp BLINKs; L3 FLOW on the lecture room's board and FLICKER on the drill grid's lines; L5 the cadet salutes under a HOLO halo bobbing out of step, and the pennant's crest PULSEs. Its hologram boxes go unchamfered (never inked) to keep it in budget. L6 the searchlight's lens PULSEs cyan and its beam is cyan, PULSE on the cyan band and strips, the second column's targets BLINK in their own chase. L8 FLOW on the veins and the violet band; the grid FLICKERs violet; PULSE on the shards. L9 BOB: the drill drone, PULSE on its violet rim, a HOLO scan cone under it. L10 the halo BOBs out of step, solid and light violet; PULSE on the beacon; spin: two troopers, 0.8 tall, marching round the parade circle as the escort (its orbit centred there) | 5,434 |
| `fabricator` | sawtooth-roofed factory, an orange gantry crane over a loading dock, smokestacks; from L6 the stacks stand taller with chrome collars: a chrome block, storey and roof, chrome roller doors, cyan lamps along the conveyor; a second gantry crane over crates in the front yard from L7; an obsidian roof and storey with violet panels, obsidian armour on the block and a veined furnace box from L8, crystal inlays and an assembler ring hovering over the dock at L9; at L10 a gold filigree roof and bridges, the antimatter core a bright light-violet orb between gold prongs on the storey's roofline, a violet ring round it | slide: the crane's trolley and hook along its bridge. The roof windows PULSE orange, the dock lamp BLINKs, HOLO smoke puffs BOB over every stack. L6 BLINK: the conveyor's cyan lamps in a chase. L7 slide: the second crane's trolley, out of step. L8 FLOW on the violet panels and the furnace box's veins, PULSE on its violet band; the smoke crystal pink. L9 BOB: the assembler ring, PULSE on its violet rim; PULSE on the inlays. L10 PULSE on the ring round the steady core; spin: a guard drone escort at 1.5 times the helpers' size, circling wide over the dock at 3.2, above the smoke | 5,216 |
| `heavy_fabricator` | armoured hall with orange press arms hammering anvils, a glowing furnace mouth; from L4 the stacks stand taller with chrome collars: a chrome hall and roof block, cyan strips up the furnace's posts, chrome press heads and slab caps; a fourth stack and a cyan band round the roof block at L5; an obsidian hall under chrome slabs, violet veins and a violet band, the pour crystal pink from L6; a forge ring hovering round each press head at L7; at L8 a gold filigree roof block and band, the antimatter core glowing in a crowned gold ring on it | slide (HAMMER, out of step): each press arm's head and piston onto its anvil. FLICKER sparks off the anvils, the furnace mouth PULSEs, the molten pour FLOWs. L4 PULSE on the cyan strips. L6 FLOW on the veins and the crystal pour, PULSE on the violet band. L7 BOB: the forge rings, PULSE on their violet rims. L8 the sparks violet; PULSE on the core; spin: a hover skiff escort hauling a chrome plate round the hall at 3.6, clear of the smoke | 4,276 |
| `research_lab` | observatory dome with a telescope, in a ring of screens; from L6 the observatory rises as a tower, a wider chrome storey on its drum taller each level (0.45 to 1.5) under a bigger chrome dome, its telescope longer and turned out of the slit towards the camera, clear of the radar's sweep, cyan screens all round the ring under a band of light, chrome antennas growing each level; a third ring storey under a broad band of light from L7; obsidian rings with violet vein panels between the screens, a crystal lens in the telescope and a violet hologram from L8; a ring of rings hovering round the hologram at L9, obsidian rimmed in violet, the hologram raised so it clears the telescope's nod; at L10 gold filigree bands on the rings and the storey and seams on the dome, the antimatter core a bright light-violet orb in gold prongs on the dome's crown, the hologram's rings gold, up to 4.57 | spin: the radar dish on its mast; swing: the telescope along the slit. The screens FLOW at their own speeds, the slit glows and PULSEs; from L3 a HOLO orb in two rings BOBs over the dome. L6 FLOW: the cyan screens; PULSE: the cyan bands (L7 the broad band round the third storey) and the storey's window slits; BLINK: the antennas' cyan lamps and the radar's feed. L8 FLOW: the violet panels and veins; PULSE: the crystal lens, the antennas' crystal lamps, the slits violet. L9 spin: the ring of rings round the hologram, counter-turning, BOB on it, PULSE on its violet rings. L10 PULSE on the violet ring round the steady core; BOB: the hologram's gold rings; spin: a probe drone escort at twice the helpers' size circling above the dome at the hologram's height | 5,342 |
| `nanite_foundry` | vats with bands of glowing nanite-green goo, piped with ball elbows; the big vat open over swirling goo; from L5 the vats taller each level (to 1.65 times) round a chrome pump tower with goo screens: chrome vats with cyan rims and cyan pipes, a sixth vat from L6, a tall column on the right; obsidian vats veined violet with violet rims, crystal elbows on the pipes, the goo brighter in taller glass and a stirrer ring hovering over the big vat from L7; at L8 gold filigree rims, gold caps and the antimatter core, a bright light-violet orb in gold prongs, on the pump tower | spin: the stirrer in the big vat. The goo FLOWs up every vat (and FLOW_U round the open top), bubbles BLINK on it, the pipes and the pump's screens FLOW. L5 FLOW: the cyan pipes; PULSE: the cyan rims and the tower's band. L7 FLOW: the veins; PULSE: the violet rims and the crystal elbows; spin: the stirrer ring, counter-turning, BOB on it, PULSE on its violet rim and crystal vanes. L8 PULSE on the violet ring round the steady core; spin: a guard drone escort at twice the helpers' size circling over the vats and the ring | 5,574 |
| `drydock` | half-built ship in a cradle under orange gantries, welders throwing sparks; the unbuilt stern a cyan hologram; from L3 the gantries taller each level (their beams 2.3 to 3.05 up), the ship lifted higher in its cradle (0.1 to 0.3) and the plating further aft: the gantries slim chrome cantilevers on braced posts at the back with cyan strips up their faces to the camera, their beams reaching out over the hull so the camera sees the ship under them, a chrome hull, cradle and booth, an engine bank of three bells ringed in cyan on the stern, the reactor glowing through a port on the near flank, aft; a fourth gantry from L4; obsidian plates veined violet along the hull's spine and a broad violet band glowing on the chrome flank to the camera, a bigger hull, an obsidian cradle and crystal arcs off the welders from L5; a crane platform hovering over the hull between the gantries at L6, obsidian with a violet deck and a chrome cab; at L7 the ship complete, gold filigree gantries, gold fins, the antimatter reactor glowing light violet in the port, in the broad band along the near flank, in a band round the stern and in a blister on its top in a gold ring | slide: the first gantry along its rails. The welds BLINK, FLICKER and JITTER sparks fly off them, the reactor PULSEs (in the bare ribs to L2, in the port on the near flank at L3 to L6, where at L7 it glows steady in the core's light violet; the engines at L2, from L3 the engine bank's nozzles). L3 the sparks cyan; PULSE: the cyan strips and the bells' rings. L5 FLOW: the plates' veins and the flank's violet band; UNLIT + FLICKER + JITTER: crystal arcs and sparks off each welder. L6 BOB: the platform, PULSE on its violet rim and crystal lamps, a HOLO tractor beam under it to the hull. L7 spin: a hover skiff escort at 1.5 times the helpers' size circling above the gantries and the platform | 4,822 |
| `alliance_beacon` | braced transmitter tower with rings of light, a big dish and an emitter orb; from L4 the tower climbs faster (to 3.0 at L7) and the dish's collar sits half way between two rings: chrome legs, base and ring housings, the rings' lights cyan; a bigger dish and a broad band of light under each ring from L5; obsidian legs with violet vein strips, an obsidian base banded violet, a crystal emitter orb and an obsidian ring hovering round the tower's upper reach at L6; at L7 gold filigree legs, the orb the antimatter core's bright light violet under a gold halo, a violet hologram beam rising from it, up to 4.90 | spin: the big dish on a collar, circling the tower. The rings BLINK in a chase up it, the orb PULSEs and BOBs with its spike, a HOLO halo BOBs over them. L4 the chase cyan. L5 PULSE: the broad bands, in turn up the tower. L6 the chase violet, the bands violet; FLOW on the leg veins and the base's band; PULSE + BOB: the crystal orb; spin: the hovering ring, counter-turning, BOB on it, PULSE on its violet rim and crystal studs. L7 the orb steady on BOB under the gold halo bobbing out of step, a HOLO beam over it; spin: a hover skiff escort at 1.5 times the helpers' size circling the tower over the dish, the allies arriving | 5,454 |
| `laser_turret` | domed head on the red-belted plinth, twin barrels ending in red emitters; from L6 the head rides a mount that lifts it higher each level on a taller plinth: chrome plinth, mount, head and barrels with cyan strips along the barrels, cyan capacitor rings round their breeches and bigger chrome cheeks, a much taller mount with a broad glowing band under the head and a second pair of barrels over the first on a mantlet from L7; obsidian plinth, mount and head from L8, glowing violet vein panels on the plinth's faces the camera sees, veins round the deck, the mount and the head and up the dome, crystal inlays at the mount's foot and a violet focusing crystal in every muzzle; gold filigree round the plinth, its deck and the head and a big gold crown on a stem over the dome, in the targeting ring, holding the antimatter core up at L10, up to 3.30 | swing: the head scans ±45° (6 s). The emitters pulse in turn, the pad's cells pulse, the belt's plates creep round it (FLOW_U), the head's mast lamp (L4) blinks. L6 PULSE: the cyan strips, the capacitor rings and the band under the head (broad from L7). L8 FLOW on the vein panels and the deck's veins; PULSE on the inlays, the focusing crystals and the violet strips, rings and dome seams. L9 spin: a targeting ring hovering over the head, BOB on all of it, PULSE on its violet top and four red sights, FLOW on its veined rim. L10 PULSE on the core; the ring's rim gold; spin: a spotter drone, twice the shared one's size, circling above (the escort) | 5,308 |
| `missile_battery` | tilted box launcher of red-tipped tubes (4, 6 at L3, 9 at L4) with a hazard band; from L6 a radar mast rises through the launcher's centre with a dish on top and the pods stand either side of it, their tubes closer set: one chrome pod of twelve tubes at L6 on chrome arms, plinth and ring, a second rack of eight at L7 and the mast much taller with a bigger dish and a second glowing band; obsidian from L8 on a taller plinth, the plinth's faces and the pods' faces and sides glowing violet, the missiles tipped with violet crystals, crystal inlays on the deck; gold filigree round the plinth, the deck and the pods' faces, the mast gold with a gold crown over the racks holding the antimatter core up clear of the pods at L10, up to 4.30 | swing: the launcher, arms and tubes, scans ±15° (7 s). The tips blink in a chase snaking along the rows, the mast lamp (L2) pulses. L6 spin: the radar dish on the central mast; BLINK: three cyan loading lights chasing up the arm the camera sees; PULSE: the cyan band and the dish's lamp (a second band from L7). L8 FLOW on the vein panels and the deck's veins; PULSE on the inlays; the tips and the loading lights blink violet. L9 spin: a radar ring hovering round the mast under the dish, counter-turning, BOB on all of it, PULSE on its top and sights, FLOW on its rim. L10 PULSE on the core; the ring's rim gold; spin: a hover skiff, 1.75 times the shared one, circling over it all as the loader (the escort) | 4,798 |
| `plasma_mortar` | fat short barrel rising from a caged violet plasma chamber on a heavy ring; from L5 a bigger bowl stands on a pedestal that lifts it more each level: chrome plinth, pedestal, bowl and barrel with cyan plasma coils round the breech, a third coil and a chrome loader arm on the near corner from L6, standing as tall as the bowl's rise, its long boom holding a plasma canister over the bowl; obsidian at L7 on a taller, wider plinth with glowing violet vein panels, veins round the breech and across the bowl's flank, the coils violet, a violet plasma pool on the bowl round the chamber's foot; gold filigree round the plinth and the pedestal, the pool the antimatter core with a core ring round the chamber, a gold crown of spikes round the bowl's rim and a gold-topped balcony on the near corner where the loader arm stands taller at L8, up to 4.55 | spin: a cooling fan on the heavy ring's flank. The chamber pulses, bubbles swell on it between the cage's ribs, arcs crackle from the ribs, the bore's lining flows up out of the muzzle. L5 PULSE: the cyan strip and coils. L6 swing: the loader arm, ±12° (5 s), PULSE on its canister and strips. L7 FLOW on the vein panels; PULSE on the pool and the violet coils; spin: a glowing violet charge ring hovering well past the muzzle, turning about the barrel, BOB and PULSE on all of it, its studs red. L8 PULSE on the core and its ring; the studs gold; spin: two troopers (0.85 of the shared size) marching round the loader arm on the balcony as the loaders (the escort) | 6,120 |
| `shield_generator` | cyan energy orb held over an emitter dome by three coil arms, their upper runs glowing conduits; from L5 the orb floats higher every level and the arms' lower runs stand as tall emitter pylons growing with it: chrome plinth, drum, dome and pylons, cyan strips up the pylons over red armour collars, a bigger orb in a cyan field ring at L5; obsidian from L6 on a taller plinth with glowing violet vein panels, violet seams up the dome, crystal inlays on the deck, a glowing pink crystal orb, the conduits, the field ring and the hologram band violet, violet crystal emitters; a second collar on every pylon at L7; gold filigree round the plinth and the pylons, the orb the antimatter core under a gold halo and a gold field ring outside the violet one at L8, up to 4.79 | spin: a hologram band round the orb, tilted off its axis so it wobbles as it turns. The orb bobs and pulses, current flows up the arms, arcs jump from the arm tips to the orb. L5 PULSE: the cyan strips and the field ring. L6 FLOW on the vein panels and the deck's veins; PULSE on the inlays, the crystal emitters, the dome seams and the violet strips and field ring; the crystal orb steady (a pulse dulls a sphere that big), BOB. L7 spin: a field ring hovering round the orb's lower half, BOB on all of it, PULSE on its violet top and four red sights, FLOW on its veined rim. L8 the orb the antimatter core, steady and light violet, BOB, under a gold halo bobbing with it; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling beside the orb's crown (the escort) | 6,552 |
| `flak_cannon` | barrels angled at the sky on a tall bell mount, the mount growing every level; from L5 chrome plinth, mount, carriage and barrels and a glowing ammo belt into the carriage from the crate, a second crate on the near corner with its belt into the near armour pack and a bigger chrome radar raised over the packs at L6; obsidian at L7 on a taller plinth with glowing violet vein panels on its faces, the carriage's side and the mount's neck, four barrels a side in two rows of two, tipped with violet crystal shells, the belts violet; gold filigree round the plinth and the mount's foot, the antimatter core round the mount's foot and in a gold housing on its near side, and a gold crown on the radar at L8, up to 4.27 | spin: the radar dish on its mast; slide: the barrels recoil (`RECOIL`, 1.2 s). Their muzzles blink once a recoil, on the kick (BLINK and the recoil share the 1.2 s period at phase 0 on the one clock), and flare (FLICKER), the radar lamp pulses. L5 FLOW: the current along the cyan belt into the guns. L7 FLOW on the vein panels and the violet belts; the shell tips blink violet; spin: a targeting ring hovering over the guns, BOB on all of it, PULSE on its top and sights, FLOW on its rim. L8 PULSE on the core; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling above (the escort) | 5,230 |
| `arc_tower` | tesla coil of white insulator skirts round a glowing core under an arc-blue sphere; twin coils at L4; from L5 the coil stands taller every level, more skirts up it, the twin coils growing: chrome plinth, drum and skirts, cyan crests along the gold coronas and a cyan band over a red one round the drum at L5, a second twin coil on the right in the third cell's place at L6; obsidian at L7 on a taller plinth with glowing violet vein panels, the drum and skirts obsidian with a violet band round every second skirt's lip, violet crystal crests; gold filigree round the plinth and the same skirts' lips, the sphere the antimatter core in a gold corona ring at L8, up to 4.66 | none to L6. Arcs climb the coil from skirt to skirt and leap from the corona to the sphere, an arc jumps between the twin spheres (L4), the core's current flows up, the spheres and the cells (L3) pulse, the corona's spike tips (L2) blink in a chase. L5 PULSE: the cyan crests and band; the arcs zigzag up the front of the taller coil. L6 a second twin's arc to the sphere. L7 the arcs between the coils violet; PULSE on the violet bands and crystal crests, FLOW on the vein panels and the drum's veins; spin: a discharge ring hovering round the sphere, BOB on all of it, PULSE on its violet top and four red sights, FLOW on its veined rim. L8 the sphere steady and light violet; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling over the crown (the escort) | 5,464 |
| `cloaked_sentry` | low dark hexagonal pod with a lid gun and a hologram shimmer ring; from L4 an armoured hex skirt banded in defence red lifts the pod higher every level: a chrome skirt, lid and gun heads with chrome barrels, cyan seams up the pod's corners and round its shoulder, a cyan hologram cloak over its walls at L4; a broad chrome mantlet bridging the gun heads with a glowing cyan sensor dome on it, and twin, longer barrels on each gun at L5; obsidian at L6, glowing violet vein panels on the shoulder and the skirt, veins round the lid, violet crystal sights, the cloak and the mantlet's edge and dome violet; gold filigree round the lid and the skirt, the antimatter core in the sights and, big, held up in one gold crown on a stem behind the guns at L7, up to 1.71 | swing: the lid gun scans ±30° (5 s). The shimmer rings are holograms, the pod's lamp and the mast lamp (L3) blink. L4 HOLO: the cloak over the walls; PULSE: the cyan seams. L5 PULSE: the mantlet's cyan edge and dome, which turn with the guns. L6 FLOW on the vein panels and the lid's veins; PULSE on the crystal sights, the violet seams and the mantlet's violet edge and dome; spin: a cloak ring hovering round the pod, BOB on all of it, PULSE on its violet top and four red sights, FLOW on its veined rim. L7 the core steady and light violet in its crown, turning with the guns; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling above (the escort) | 2,094 |
| `gravity_well` | dark violet core floating over a violet well, ringed by gyro rings; from L4 the core floats higher over the well every level, the pillars growing with it and a housing ring joining them low over the well: chrome plinth, well, pillars and housing, cyan strips up the pillars, a red band round the housing, the first gyro ring cyan and the rotor chrome at L4; obsidian at L5 on a taller plinth with glowing violet vein panels, violet strips up the pillars, veins round the housing, a bigger glowing pink crystal core held still in the gyro rings (L4's core bobs, so it keeps L1's size to clear the inner ring); gold filigree round the plinth and the housing, the core the antimatter core, bigger again and still, the gyro rings and the rotor gold at L6, up to 3.14 | spin: the rotor over the core, the gyro rings tumbling about X (L2) and about Z (L3). The core bobs and pulses, the well's swirl turns and draws in (FLOW and FLOW_U on the crystal layer), the pillar caps blink in a chase. L4 PULSE: the cyan strips and the cyan gyro ring. L5 FLOW on the vein panels and the housing's veins; PULSE on the violet strips; the crystal core steady and still; a gyro ring hovering round the pillars, turning with the rotor (its moving part), BOB on all of it, PULSE on its violet top and three red sights, FLOW on its veined rim. L6 the core steady, light violet and still; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling over the rotor (the escort) | 2,898 |
| `emp_tower` | yellow core in a bar cage atop a stepped tower ringed by capacitor cans; from L4 a storey between the blocks, taller every level, red armour plates on its corners, and a third can on each stack: chrome blocks, storey and cans, cyan bands round the storey's top and each stack's foot at L4; obsidian at L5 on a taller plinth with glowing violet vein panels on the plinth's and the tower's faces the camera sees, obsidian cans tipped with crystals; gold filigree round the plinth and the storey, the core the antimatter core under a gold crown on the cage's ring at L6; the core grows no further than L4's 0.34, so the cage's bars show round it, up to 4.39 | none to L4. The core bobs and pulses, the cans' bands blink in a chase round the ring, arcs crackle between the cage bars, the mast lamp blinks. L4 the bands BLINK cyan; PULSE: the cyan bands. L5 the bands BLINK violet crystal; FLOW on the vein panels and the stacks' veins; PULSE on the crystal tips and the storey's violet band; spin: a pulse ring hovering round the tower's neck under the cage, BOB on all of it, PULSE on its violet top and four red sights, FLOW on its veined rim. L6 the core steady and light violet, BOB; the ring's rim gold; spin: a guard drone, twice the shared one's size, circling over the tower (the escort) | 4,360 |
| `railgun` | two long rails across the screen with a cyan strip between them, capacitor banks | none. The strip's current races to the muzzle, the capacitors blink in a charging sequence towards it, the muzzle's emitter pulses | 2,098 |
| `ion_beam` | big crystal lens and focusing rings on a tripod of glowing conduits, a hologram column along the beam | spin: two, the focusing rings turning about the beam in opposite directions, each ring with two glowing studs. The lens and the emitter pulse, current flows up the conduits | 1,866 |
| `orbital_cannon` | massive gunmetal barrel aimed at the sky with cyan coils, on a two-tier bunker | swing: the gun elevates ±4° about its trunnion (9 s); spin: the radar dish. The coils pulse one after another up the barrel, a hologram ring glows at the muzzle, the bore ripples, the bunker's lights blink in a chase, the cells pulse | 4,896 |
| `proximity_mine` | spiked domed disc on a hazard rim with a red warning light; from L4 a wider, taller dome, a spike more a level and six lamps round the rim: L4 a chrome dome banded in cyan with chrome spikes and a chrome cap round the light, L5 an obsidian dome with glowing violet vein panels on the faces the camera sees, glowing crystal spikes and a violet warning ring hovering round the dome at mid-height, L6 the dome banded in gold filigree, gold spikes, a big light-violet core lens in place of the red light under a small gold crown | none moving. Blink: the warning light (and the rim light at L3, half a cycle apart). Its L3 requires Command Center 4, so it is Base tier: the ring round the light is hull-mid casing. L4 BLINK: six lamps chasing round the rim (cyan, violet at L5, gold and violet at L6); PULSE: the cyan band. L5 FLOW: the vein panels; PULSE: the crystal spikes and the violet band; PULSE + BOB: the hovering ring. L6 PULSE: the core lens | 1,054 |
| `grav_trap` | ring emitter round a dark funnel with a violet swirl; from L3 a wider, taller emitter, six swirl strips, round coils banded in light, the strut ring higher: L3 chrome with a cyan lip and a cyan vortex, L4 an obsidian funnel with glowing violet vein panels, the vortex violet, crystals on the coils and a crystal ring with crystal shards hovering round the emitter outside the coils, L5 a gold filigree rim, a violet core at the funnel's bottom, the hovering ring gold with violet shards | pulse: the emitter's violet lip, and the hovering ring from L2; flow: the vortex's throat and swirl strips stream inward. Its L2 requires Command Center 4, so it is Base tier: the hovering ring's outer band is hull-mid casing. L3 PULSE: the cyan lip, the coils' bands in turn. L4 FLOW: the vein panels; PULSE: the crystals; spin: the hovering ring and its shards (the one moving part), BOB and PULSE on all of it. L5 PULSE: the core and the coils' violet bands | 1,280 |
| `flak_mine` | hazard-banded pod, upward barrels with glowing bores round a lens; from L4 a wider, taller pod, a barrel more a level, a bigger lens raised on a collar over the barrels and four lamps round the pod: L4 a chrome pod banded in cyan with chrome barrels and cyan bores, L5 an obsidian pod banded in gold filigree with glowing violet vein panels, gold barrels with violet bores, a taller gold collar raising a big light-violet core lens under a small gold crown | none moving. Pulse: the bores, phased in turn; blink: the sensor lens. L4 BLINK: the pod's lamps in turn (cyan, gold and violet at L5); PULSE: the cyan band. L5 FLOW: the vein panels; PULSE: the core lens | 994 |
| `mega_mine` | big armoured dome on a hazard band ringed with red lights, dim red seams up the dome between them; from L3 a wider, taller dome, eight lights, a bigger fuse cap with a sensor mast: L3 a chrome dome with cyan seams and a chrome cap round the red fuse light, L4 an obsidian dome with violet vein seams and glowing violet vein panels, a crystal fuse glowing light violet and an obsidian ring hovering round the dome's waist, L5 gold filigree seams and band, a violet core fuse under a gold crown on a gold cap, the hovering ring's rim gold | blink: the band's lights in a chase; pulse: the seams, faintly and in turn, and the fuse light. L3 the lights and the mast's bulb cyan, the seams cyan, pulsing in turn. L4 the lights violet; FLOW: the vein panels; UNLIT: the crystal fuse, steady; spin: the hovering ring with four crystal studs (the one moving part), BOB on all of it, PULSE on its violet rim and studs. L5 the lights gold and violet in turn; PULSE: the core fuse | 2,510 |
| `barrier_wall` | posts joined by thick segments on a shared curb (**Walls**): slate with a cyan strip and field to level 5, chrome with cyan strips at 6–7 (a cyan lens on the post and strips along the sides at 7), obsidian with glowing violet fields, vein strips and crystal shards at 8–9, gold filigree rails and a crown cup holding a violet core at 10 | none moving. FLOW: the strips along the top and sides, the fields; PULSE: level 5's field, the lamp bands, level 7's lens, the shards and inlays, the core bead | the lone post 198, the full cross 390 |

### Construction drone

While a building is constructed or upgraded, a builder drone works over it
(`ConstructionDrone`; `input-camera.md`, **BuildingView**, for when it is spawned and freed).

- **The model** (`models/drone.gd`, `DroneModels.build_drone`), the drone the drone bay parks
  too (`add_drone(m, pos, parked)`: turned 45 degrees so its rotors stand on the axes, every part
  bobbing together on phase 0.9, its rotor blurs unlit screen-layer discs turning at that phase,
  so the bay has no hologram surface). A 12-sided saucer on `HULL_LIGHT_ROUND`, a `GLASS` canopy, an `ENERGY` eye
  at its front (+Z), four `ROD` arms on the diagonals to `HULL_MID_ROUND` ducts, each banded in
  hazard stripes round a rotor blur disc (`ROTOR`, a hologram: below), and a gunmetal tool arm
  under the nose ending in an `ENERGY` emitter lens (`EMITTER`). It is built round its own centre
  at the bay's size and shown 1.4 times larger (`SCALE`), so it reads at the starting zoom.
  `BuildingModels.create_drone()` builds and caches it like a model: a body, whose rotors are its
  mesh's second surface (**Animation**, **Holograms**), and its outline.
- **The flight** (constants on `ConstructionDrone`): it descends over 0.8 s, easing out, from 3.5
  above the orbit's height over the footprint's centre, then cycles. It orbits the centre at
  half the footprint plus 0.45, 1.4 high (higher over a tall site: the same clearance as the
  hover, below), bobbing 0.08 (period 1.8 s), at 0.9 units a second, facing its motion and banked
  12 degrees into the turn. After 2.2 s it picks a work point, flies to it easing in and out,
  tilts its nose down 15 degrees, fires for 1.3 s and flies back to the orbit. Leaving, it stops
  firing, rises 3.5 over 0.7 s and frees itself; the climb starts no lower than clear of what the
  site shows by then, so a drone whose build just finished starts above the new model. When its
  view is lifted or set down (dragged), the view tells it the site's new top (`set_site_top`): the
  orbit and hover heights re-clamp, the work point moves with the site, and the drone eases there
  as between any two points (a shot in progress is aimed again once it arrives).
- **The work points.** At spawn it keeps the faces of the shown site's body mesh (the scaffold or
  the model) that face the camera (the normal's dot with the view direction above 0.3, so up-
  facing ones too) and reach between 0.3 and 0.8 of its height. Each shot picks one of them, a
  height in that band within the face and a point across the face there, from a hash of the
  building's id and the shot count, so a run repeats. It hovers 0.9 above the point, nudged 0.3
  outward along the face's horizontal normal, with its lowest point (tilted to fire, at the bottom
  of its bob) held at least 0.3 above the site's top; the beam slants down to the point. The
  highest it reaches at work, on the orbit or over the highest work point, at the top of its bob
  and tilted or banked, is `ceiling()`, which the view's timer label is held above.
- **The laser**: a thin unlit `ENERGY` square rod (0.05 across, not outlined), one unit long
  (`create_drone_effect("beam")`) under a node stretched from the emitter to the work point, so
  no mesh is rebuilt per shot; at the point a flare (`create_drone_effect("flare")`): an unlit
  cyan dome (radius 0.14) and five hazard-yellow spark shards fanned round it, 0.08 to 0.14 long
  past its edge so their tips reach about 0.25 out, each seen from both sides. Both are shown
  only while firing (`visible`). At each shot the flare is turned so its up axis is the hit
  face's normal (one basis, no allocation), so the burst fans along the surface instead of half
  of it entering a wall.
- **Its animation** (**Animation**; each on a surface of its own on `DroneModels`): the beam is
  UNLIT, FLOW and PULSE on the bands layer at 2 repeats a unit and phase 0.15: its bright bands,
  a sixth of a unit long, each led by an ink edge, travel from the emitter to the hit point at
  0.7 units a second (a face's V is minus its height, so the phase is below 0.5) while it pulses,
  so the beam reads as pulses fired down it. The rod is a box, not a prism: a lathe takes a whole
  repeat round, which on so thin a rod mips the bands away, where a box's planar UVs keep the
  texture as dense across it as along it. The glow layer's stripes and the pipe layer's rib lines
  are too faint or too fine on so thin a rod to show the flow. The hit dome is UNLIT and PULSE; the sparks are UNLIT, FLICKER and JITTER on the glow layer in
  hazard yellow, each shard at phase k/5, so the burst pops and crackles; the rotor discs are HOLO
  and FLOW_U on the glass layer untinted (its pale glass and diagonal streak as they are), at
  phases 0.92, 0.08, 0.96 and 0.04, so they read as pale translucent discs whose streak sweeps
  round as a blur arc, turning at different speeds, the pairs counter-rotating.
- **Instances**: the body (two surfaces, the second the rotors' holograms), its outline, the beam
  and the flare, four, made at spawn; nothing is allocated per frame. The holograms add one draw
  in the transparent pass. Only the body casts a shadow. Drones exist only while a building is busy
  (and for the 0.7 s of leaving), so there are about as many as the base has busy drones.

## Animation

Two ways for a model to move: **surface effects**, which the shaders animate from `anim_time` per
part, and **moving parts**, nodes `BuildingView` moves. What each costs in draws:

- The shader effects (PULSE, BLINK, FLICKER, FLOW, FLOW_U, BOB, JITTER) add no draw: they are
  flags on parts of meshes that are drawn anyway.
- A moving part is two more instances, its body and its outline: two draws, plus the body's draw
  into the shadow map.
- A HOLO part puts one more surface on its mesh: one more draw, in the transparent pass, for each
  mesh (the body or a moving part) that has holograms.

**One clock.** Both run on the game's animation clock: `Motion.tick()` reads a monotonic clock
(`Time.get_ticks_usec()`) into seconds wrapping every hour (`Motion.WRAP_SECONDS`, 3600), and
`main.gd` calls it once a frame in its `_process`, before any view animates (main is their
ancestor), and hands the value to the shaders as the global uniform `anim_time` (declared under
`[shader_globals]` in `project.godot`, set with `RenderingServer.global_shader_parameter_set`).
The shaders use `anim_time`, never `TIME`, whose zero is the engine's first drawn frame and so
falls anywhere from a fraction of a second to seconds after the ticks' zero. Moving parts are
posed at `Motion.clock()`, the same value, so the two agree to within a frame: a part and its
surface effects keep step (the flak cannon's muzzles flash on the barrels' kick). A model with no
`main.gd` above it (a HUD preview) poses its parts at 0.

While a building is busy (constructing an upgrade) its moving parts hold their last pose and on
resuming snap to the clock's (the view is normally replaced when the work finishes); its surface
effects keep running, since they come from `anim_time` with no per-instance state. That is
intended.

### Surface effects

A part's flags (UV2.y, `Surf.flags`) are bits; `effects.gdshaderinc` holds the effects and their
constants, shared by `toon.gdshader`, `ink.gdshader` and `holo.gdshader`, so an outline follows
its part and a hologram moves like any other part. A part's phase (`Surf.phase`, 0 to 1) offsets
its cycle by phase times the period. It is stored in the vertex colour's alpha, 8 bits, in 1/254
steps: `LowPolyMesh` writes (round(phase × 254) + 0.25) / 255, the same byte whether the store
rounds or truncates, and `surf_phase()` in `effects.gdshaderinc` reads round(alpha × 255) / 254,
so 0.5 (a FLOW part standing still) is exact. There are no per-instance uniforms: every instance
of a mesh animates alike.

| Flag | Bit | Effect |
| --- | --- | --- |
| `UNLIT` | 1 | pure emission (**Surfaces**) |
| `GLOSSY` | 2 | the cel specular disc |
| `PULSE` | 4 | the colour, emission included, swells between 0.55 and 1.0 on a sine of period 1.6 s: cores, lenses, beacons |
| `BLINK` | 8 | lit 0.2 s of every 1.2 s, at 0.35 the rest; lamps with phases k/n chase round a ring |
| `FLICKER` | 16 | on or off at random 24 times a second (a hash of the time step and the phase), on about 40 % of the time; while off the vertex shader collapses the part to a point, so it draws nothing (no `discard`, which would cost the shared toon material its early depth test): sparks, welding arcs |
| `FLOW` | 32 | the texture scrolls along V at (phase - 0.5) × 4 repeats a second: 0.5 still, 0.75 one repeat a second forward, 0.25 back. Liquids in pipes (the pipe layer's bands), conveyors (grating), screens; the glow layer's stripes are too faint to show a scroll and run along U, so FLOW_U shows nothing on it: currents and bands use the bands, screen, pipe or crystal layer |
| `FLOW_U` | 64 | the same along U: discs, rings. It shows only on a layer that varies along U: not the glow layer, whose stripes run along it |
| `BOB` | 128 | the part rises and falls 0.08 along world Y on a sine of period 2.4 s: floating cores, holograms |
| `JITTER` | 256 | each vertex jumps up to 0.04 in a pseudo-random direction (a hash of its position and the time step), 20 times a second; corners shared by faces move together. With UNLIT and FLICKER, a crackling arc: build it of short segments so there are corners to shake |
| `HOLO` | 512 | a hologram (below) |

Effects compose: UNLIT + PULSE, UNLIT + FLICKER + JITTER, FLOW + PULSE. `anim_time` wraps every
hour (**One clock**, above); BLINK, PULSE and BOB cycle evenly into the hour, FLOW and the
hologram's dip jump once an hour, and so does a spin or a swing whose period does not divide it.

**Holograms.** A HOLO part is transparent, so `LowPolyMesh.to_mesh()` puts it in a surface of its
own on `MaterialKit.holo()` (`holo.gdshader`: unshaded, alpha-blended, no depth writes, back faces
culled): the kit layer times the tint at alpha 0.45; scan bands, a sawtooth 0.5 units long in
world Y drifting up at 0.4 units a second, brightening by up to 0.4; a rim where the view grazes
the surface, up to 0.3 brighter; and a dip of the alpha to 0.2 for 0.1 s every 2.6 s, offset by
the phase. A near-white layer (glow) shows the tint best. A hologram is never outlined, never in a
wall piece (**Walls**), and keeps its look on a placement ghost (**View states**).

### Moving parts

`Parts.moving(pivot, motion) -> LowPolyMesh` makes a moving part: build it in its own space,
the pivot at its origin, as the parts of the body are built. A model has at most three, four at
Crown, the fourth its escort (`Parts.max_moving(tier)`, asserted). `Motion` (`src/game/motion.gd`) says how it moves:

| Constructor | Motion |
| --- | --- |
| `Motion.spin(axis, rate)` | continuous rotation about `axis` through the pivot, `rate` radians a second |
| `Motion.swing(axis, amplitude, period, phase = 0.0, ease = SMOOTH)` | rotation about `axis` between -`amplitude` and +`amplitude` degrees |
| `Motion.slide(axis, amplitude, period, phase = 0.0, ease = SMOOTH)` | translation along `axis` between -`amplitude` and +`amplitude` units |

A swing or a slide follows a wave from -1 to 1 over each `period` seconds, offset by `phase`
(0 to 1), shaped by its ease (`Motion.Ease`, the `easing` field): `LINEAR` a triangle wave,
`SMOOTH` a sine, `HAMMER` a slow rise over 70 % of the period, a fast fall over 10 % and a hold of
20 %, `RECOIL` its mirror: a fast rise over 10 %, a slow fall over 70 % and a hold of 20 %. At -1
the part sits at its rest moved by -amplitude along (or turned -amplitude about) the axis, so a
hammer strikes and rests at -amplitude and is lifted at +amplitude, and a recoiling barrel rests
at -amplitude and kicks out to +amplitude: point the axis the way the part kicks.

`BuildingView` collects the moving nodes once and, while the building is finished and idle, sets
each one's transform every frame from `Motion.transform_at(Motion.clock(), rest)`, with no
allocation; while it is busy the parts hold their last pose. A view with no moving part does no
work per frame.

### Budget and checks

A building is at most eight instances, ten at Crown: the body, its outline, and up to three
moving parts (four at Crown) with their outlines. The `model_gallery` scenario checks every model
against it (**Models**), and a
moving part's reach over its whole motion against the extent (**Modelling vocabulary and
budgets**): a spin's circle about its axis, its radius added to the pivot's x and to its z in
turn (the extent is per axis, so a round off the centre along a diagonal is not over-counted), a
swing's bounds every 5 degrees from -amplitude to +amplitude, both ends included, a slide's at both
ends.

The `effects` harness scenario (`tools/harness/README.md`) is the rig: a part for every effect and
every kind of motion, in two rows on the field, checked headless and screenshotted at 0.0, 0.3 and
0.9 seconds rendered. Try a new effect combination there first.

## Modelling vocabulary and budgets

- **Budgets**, body triangles (outlines repeat them and are not counted), by footprint and tier
  (**Tiers**). They are mobile ceilings, not targets: spend triangles where a silhouette or a
  curve needs them. Draw calls, not triangles, are the phone's cost, so a Crown model's fourth
  moving part is spent only where the type's story needs it.

  | Footprint | Base / Gold | Chrome | Obsidian | Crown |
  | --- | --- | --- | --- | --- |
  | 1×1 trap | 600 | 840 | 1,080 | 1,320 |
  | 2×2 | 2,000 | 2,800 | 3,600 | 4,400 |
  | 3×3 | 3,000 | 4,200 | 5,400 | 6,600 |
  | 4×4, 5×5 | 5,000 | 7,000 | 9,000 | 11,000 |
  | wall piece | 250 | 300 | 350 | 400 |
- **Extent**: in x and z a model stays within its footprint plus 0.15 units: the static body's
  bounds, and every moving part's reach over its whole motion (a turning head or dish must clear
  the footprint at every angle, a swinging arm at both ends of its swing). The gallery checks it on every type and level.
- **Height**: at most 7 units for the Command Center and 5 for every other type, the body's top
  and every moving part's over its whole motion (the camera's scene top is 13, and the
  construction drone hovers 3.5 above a site). The gallery checks it on every type and level.
- Every box edge gets a chamfer (0.04 to 0.08 units). Cylinders have 16 to 24 sides, domes 16
  sides and 6 to 8 rings, rings and dishes 24 segments, all smooth. Parts under about 0.3 across
  may use 10 to 12 sides when smooth, and under 0.15 as few as 8; small light domes 3 rings.
  Nothing is a bare 6-sided prism.
- Every building: a foundation pad (`CONCRETE_PAD`, a chamfered slab 0.12 high, inset 0.1 from
  the footprint, covering it so the building sits in its cell), one main mass, two to four
  secondary masses, three to six greebles (vents, pipes, lights, antennas, hatches, tanks,
  ladders), one signature element that names the type from across the base, one accent surface
  and one emissive element.
- Levels: each adds mass or height within the footprint, more armour (the plate layer), one more
  greeble and a stronger emissive; its tier sets its theme (**Tiers**): gold trim from the Gold
  tier, then the Chrome, Obsidian and Crown looks. Every level of a type reads as one building
  growing, never as separate buildings.
- Moving parts (radar dishes, turbines, gyros, press arms, recoiling barrels): three per
  building at most, four at Crown, the fourth the escort (**Animation**).
- Scale: at Base and Gold a size-2 building stands 1.2 to 2.0 units tall, a 3×3 about 1.6 to 2.2,
  a 4×4 Command Center up to 3.2. As guidance, Chrome grows to about 1.3 times the type's Gold
  height, Obsidian 1.6 and Crown 2; the height caps above govern (7 units for the Command Center,
  5 for every other type). The Command Center is the one type given more than the guidance, since
  verticality there is the owner's ask: 3.90, 4.40, 5.20, 6.00 and 6.94 at levels 6–10. Verticality goes to the Command Center (stacked
  storeys, and a spire from 8), the Alliance Beacon, the Research Lab, the Hangar's control tower,
  the Antimatter Siphon's pylons, the Metal Silo, the Railgun, the Shield Generator, the Orbital
  Cannon and the Drydock's gantry; the rest grow in mass and detail.
- Walls connect: a post plus a half-segment towards each orthogonal neighbour that is also a
  wall, meeting at the cell boundary, so neighbours of different levels each draw their own
  (**Walls**).

## Walls

`models/walls.gd` builds the wall pieces, one per level and neighbour mask, and `WallMesh`
(`input-camera.md`, **Walls**) merges the pieces of every finished wall into one mesh. A piece is
a post on the cell centre and, for each neighbour in its mask, a half-segment from the post to
that cell edge, lower than the post; two adjacent walls meet on their shared edge, each in its own
level's style.

The mask has one bit per orthogonal neighbour in cell space, where cell (x, y) is world (x, z);
`NEIGHBOURS` lists the offsets in bit order:

| Bit | Constant | Neighbour |
| --- | --- | --- |
| 1 | `PLUS_X` | cell (x + 1, y), world +x |
| 2 | `MINUS_X` | cell (x - 1, y), world -x |
| 4 | `PLUS_Z` | cell (x, y + 1), world +z |
| 8 | `MINUS_Z` | cell (x, y - 1), world -z |

Each level is the same wall grown: a slim hull post (at most 0.46 of the cell, its chamfered cap
never wider than itself) on a concrete footing, and slate segments 0.4 of the cell thick and
0.85 of the post's height on a concrete curb that runs on from wall to wall, so a run reads as
one thick slab with the posts standing just proud as joints. Levels 6 to 10 are the same wall
in the higher tiers' surfaces (**Tiers**): the surfaces follow the tier, from a palette per tier
(`PALETTES`: plating, rail, the strip along the top, lamp, field, crystal, trim), and the
geometry the level. They grow a little at each tier, not at each level, and stay low, so a wall
never hides what stands behind it: the top post stands 1.36 with its crown. Heights are the
post's top, cap included (the shards and the crown cup above levels 6 to 10's caps not):

| Level | Post | Segments |
| --- | --- | --- |
| 1 | Squat, 0.55 | Slate plates |
| 2 | 0.64, gunmetal cap | Riveted slate armour with a band |
| 3 | Ribbed (the `pipe` layer), 0.72, gunmetal cap | Ribbed slate, an energy cyan strip along the top, a current flowing along it |
| 4 | A plated pylon with wide chamfers, 0.81, gunmetal cap | Double plated: a sloped riveted skirt under a slate plate, a brighter strip, its current a little faster |
| 5 | The level 4 post with a gold crown, 0.9 | A low riveted base under an energy field panel, shimmering upward as it pulses |
| 6 | Chrome, 0.96, a chamfered chrome cap over a band of cyan lamps (`CYAN_STRIP`, PULSE) | A chrome slab on a sloped chrome skirt, a cyan strip along the top, its current as level 4's |
| 7 | Chrome, 1.02, heavier: chrome fins up its four corners, its cap a raised chrome hip over a taller lamp band, crowned with a glowing cyan lens (1.16 with it) | A battered chrome slab, wider at its foot, a cyan strip along its top and a broad one across both its faces, so a run glows along its sides |
| 8 | Obsidian, 1.08, a glowing crystal shard (the `crystal` layer, PULSE) on its cap over a tall violet lamp band | Obsidian: a glowing violet field (`CORE_GLOW_TINT` on the `glow` layer, FLOW) between a low rail and a chamfered top rail, a broad vein strip along the top (the `veins` layer, FLOW, its veins running along the wall) |
| 9 | Obsidian, 1.15, a cap half again as thick, two shards leaning apart, crystal inlays up its four corners | Level 8's, the field wider between thinner rails, the low rail heavier, the strip broader |
| 10 | Obsidian with the inlays, 1.18, a gold cap and on it a gold crown cup with four points holding a violet core bead (`CORE_GLOW`, PULSE) | Level 9's with gold filigree rails (`FILIGREE`): black, gold and violet |

A lamp band is a course of the post itself, as wide as it, between its body and its cap. No level has a moving
part, and no part is HOLO, BOB or JITTER (below).

The strips and the field are unlit on the `glow` layer at a third of its scale (`FLOW_SCALE`), so
its stripes are coarse enough to see move, and, being thin, have no ink. A strip is a box built
along its own z and turned onto world +x or +z, so its top's stripes cross it on every segment and
its FLOW (0.6; 0.65 on level 4 and on the cyan strips of levels 6 and 7) carries them towards +x
or +z on both halves of a segment: the
current runs on along a run, from wall to wall, a half-segment being about two whole stripes long.
From the Obsidian tier the strip is on the `veins` layer at full scale instead, unlit and not
inked, its channels running along the wall and its FLOW (0.7) carrying their beads along them.
The field is a swept panel whose stripes run along it, so its FLOW (0.45) lifts them up the panel,
with PULSE on level 5; the violet fields of levels 8 to 10 are the same, inked as they are thick,
and do not pulse, so they stay bright: the glowing side of an obsidian wall. A segment's
end on the cell edge is a cap painted like the segment but left out of the outline, so two
segments that meet there draw one unbroken ink line. Where walls of different levels meet, the
taller segment's end shows as a step, and its caps are outlined (the curb's excepted, so every
level's curb meets the next unbroken). Taller goes by height, not level: `solid_top(level)` is
the top of a level's solid segment, the segment itself (rails included) on levels 1 to 4 (about
0.47 to 0.69) and 6 to 10 (0.82, 0.87, 0.92, 0.98, 1.0), and on level 5 the low slab under its
unoutlined field (about 0.34), so a level 5 wall is the lowest and every other level steps down
to it, and otherwise of two adjacent levels the higher steps down to the lower. A piece takes a second mask, `lower_mask`, of
the neighbours whose solid top is lower (the same bits, a subset of the mask). Only the outline
differs; the body is the same whatever `lower_mask` says (each cap keeps its segment's paint
and phase). The step's ink edge shows where its
end stands above the lower wall; beside a post nearly as high as the step (an L4 segment next
to an L2 post) it is a short dark mark over the post's cap.

`piece(level, tier, mask, lower_mask = 0)` builds a piece on first use for its level's tier (level
5's crown is gold from the Gold tier, `CAP` gunmetal below it; levels 6 to 10 take their tier's
palette, a tier below Chrome taking Chrome's) and keeps its body and outline arrays
(`to_arrays`, `to_outline_arrays`), cached by tier, level, mask and lower mask (a higher level
shows level 10's, built for its own tier); every piece stays within its tier's budget for a wall
piece (250 at Base and Gold, 300 at Chrome, 350 at Obsidian, 400 at Crown; the full crosses of
levels 1 to 10 are 148, 210, 218, 250, 240, 260, 294, 310, 348 and 390 triangles)
(`wall_junctions` checks all 160 masks and levels, that each piece's body is the same whatever
its lower mask, and the merged outline against its pieces' with their steps). `build_barrier_wall`, which `BuildingModels.create("barrier_wall", level, 1, tier)` dispatches
to, is the lone post (mask 0): the paint brush, a lifted wall and the gallery show it.

The merged mesh keeps each piece's UV2 and colour, so PULSE, BLINK and FLOW work on wall pieces.
It takes a piece's opaque surface only, so a HOLO part is not allowed in a wall piece, and its
merged outline carries no flags (`WallMesh` copies UV2 and colour only with UV), so BOB and
JITTER are not for walls either.

## View states

A view never makes a material: a state overrides an instance's surface 0 with a shared one from
`MaterialKit` through `set_surface_override_material`, and clears it with `null` when the state
ends (`BuildingView`). A hologram surface is never overridden: a ghost tints a body's surface 0
only when it is the toon surface, so its holograms keep their look.

| State | What changes |
| --- | --- |
| Selected (`set_footprint(SELECTED)`) or lifted (`set_lifted(true)`, while dragged) | the outline instances take `ink_selected` (core gold); the footprint tile shows as before |
| Placement ghost (`set_ghost(valid)`, from `PlacementController` as its spot is checked) | the body instances take `ghost_valid` or `ghost_invalid`: the toon shader with energy cyan or defence red mixed in at 0.65; the outline stays plain ink, though the ghost is lifted |
| Under construction | the scaffold, a model like any other, outlined; a construction drone works over it, and over a building being upgraded (**Construction drone**) |

A wall drawn by the merged wall mesh hides its own model, outlines included (`set_merged`), so a
selected merged wall shows its footprint tile and no gold, and the merged outline stays plain ink.
A dragged wall leaves the mesh and shows its own post, lifted with gold outlines like any dragged
building; the paint brush is a ghost and keeps plain ink.

## Environment

The ground and everything round it, drawn in the buildings' language: a levelled, lit landing
plain inside a wilder landscape of the same ground, so the base reads as a settlement. `BaseView.setup`
builds it all once; the terrain, the rocks and the outcrops come from `SeededRng` on
`SCENERY_SEED` (7), so every base sits in the same landscape (`input-camera.md`, **BaseView**).

**The field** (`ground.gdshader`, on the 48×48 `PlaneMesh` at y = 0): one seamless levelled plain
of regolith with natural marks scattered over it. Everywhere the ground is the plate tint covered
at 60 % by the dust, with a fine grain drawn by the shader in world space, so it runs on unbroken
across the field: two octaves of value noise at 6 and 12 repeats a cell, each 3.5 % either way, each
fading out as its lattice falls under a pixel so it does not shimmer at the widest zooms. A value
noise twelve cells across varies the plain 6 % either way, the ring's own on the same cells, so the
field's tone runs on unbroken into the ring's at its edge. The 1-cell grid is drawn in holographic
cyan only while building (`line_strength` 0.45 while placing, painting walls or moving a
building, 0 otherwise), and its outermost line, along the field's edge, is drawn like the inner
ones, at the same width (the plane ends there, so it lies just inside). There is no other line, seam or square on it. The lighting is `light()`
from `toon_common`, as on the buildings. The hash, the noise, the grain and the tiles' sampling and
lighting live in `field_marks.gdshaderinc`, which the terrain shader shares.

The marks come from the field texture, `assets/textures/field.png` (1024×1024, the image importer
like the kit), an atlas of four tiles, 512 pixels square (128 a cell), tile q at column q % 2 and
row q / 2. It holds weights, not colours, so the tints stay `MaterialKit` roles, and no light is
baked in:

- R and G, the lean: the way the surface's normal leans across the tile, along its x and y, 0.5
  flat and 0 and 1 a full lean of −1 and +1. A dome leans out from its middle; a crater's wall
  leans in, towards its centre.
- B, ink.
- A, tone: 0.5 neutral; below it mixes towards `FIELD_DARK` and above it towards `FIELD_LIGHT`,
  each in full at 0 and 1.

Away from the marks every channel is flat, and marks keep 8 pixels clear of a tile's edges, so
every channel is flat along every edge and nothing shows where one tile meets the next. The four
tiles are 0 *plain*: three pits, a crack and six pebbles; 1 *cracked*: a long branching crack, a
crater of 45, two pits and five pebbles; 2 *cratered*: a crater of 64 with two cracks running out
from its rim, three pits and eight pebbles; 3 *pebbly*: a cluster of ten to fourteen pebbles with
three angular shards among them, a crater of 45, a crack and two pits. Each crater lies at a spot
of its own (96, 214; 269, 328; 155, 387 pixels into its tile), off the tile's diagonals and no turn
or mirror of another's, so that, turned eight ways, the field's craters line up neither in the
view's columns and rows nor along the grid: none of the field's 107 lies within 0.2 cells of a
diagonal through the tiles' corners. Every mark is a hard-edged, inked shape (sizes in pixels of
the tile):

- a crater, radius 45 or 64: an ink rim 3 wide, the wall leaning in at 0.8 from 0.45 radii to the
  rim, the rim's outer slope, from 1.0 to 1.3 radii, leaning out at 0.45, a flat floor at tone
  0.35, and round it a ring of ejecta stipple, ink dots 2 across covering about a quarter of the
  ground just outside the rim and thinning out to nothing 0.3 cells out, the same all round so it
  is right however the tile is turned;
- a pit, a crater of 10 to 19 with a rim 2 wide, its floor at 0.4 and no stipple;
- a pebble, a jittered hexagon of 6 to 15 outlined in 1.5, leaning out at 0.7, tone 0.6 (6 to 12
  in the pebbly tile's cluster, which lies within 0.8 cells of its middle);
- a shard, a jittered triangle of 8 to 14, the same;
- a crack, 1.5 wide, 15 to 30 long; the cracked tile's long one is a run of 50 to 70 with a branch
  of 15 to 25 setting off 55 to 80 degrees to each side of it from two of its corners.

Marks never overlap.

Each tile of the field, four cells square, takes one of the four (its variant, 0 to 3) and an
orientation (0 to 7: a quarter turn count 0 to 3, mirrored from 4 on): 32 looks. The variant and
the mirror come from its cell hash (offsets 30 and 88), the quarter turn from its place, as on the
terrain ring: (column mod 2) + 2 × (row mod 2) − variant, mod 4 (`field_marks`' `turn_by_place`).
Tiles touching along a side or at a corner differ in (column mod 2, row mod 2), so two with the
same variant never share a turn, and no two touching tiles look the same at any field size: over
the 48×48 field's 12×12 tiles none of the 506 touching pairs does (checked on the development
Mac's GPU). The field once took its orientation from the hash too, at offsets picked so that no
touching tiles of the 40×40 field matched; at 12×12 those offsets left 4 matching pairs, and with
506 pairs each alike one time in 32, offsets that leave none come about once in seven million, so
that scheme was abandoned. The mirror's offset, 88, is the one of those tried (27, 11, 41, 63,
71, 88) whose tiles leave the least step where the field meets the ring along its far sides
(under 3/255, the check below): turned by place, the tiles along an edge show it only some of
their sides. The shader
turns the tile's own coordinates into the variant's about its middle and samples the atlas with
the gradients of the unturned coordinates, so the mipmap does not jump where tiles meet. It turns
the stored lean back into the field's axes (the turn's transpose) and lights it from `sun_across`
(`BaseView.SUN_ACROSS`, the key light's direction across the ground): where the lean towards the
sun passes 0.25 it mixes towards `FIELD_LIGHT`, in full by 0.4, and away from it towards
`FIELD_DARK` the same way. So however a tile lies, a crater's wall is lit on the side away from
the sun and a pebble on the side towards it. Then the tone, then the ink. The tiles are only what
keeps the plain from repeating: there is no seam between them, no tint of their own, no grain of
their own, and no made thing (patch, bolt or joint) among the marks.

**The perimeter** (`boundary`, `_build_boundary`): a fence round the field in the buildings'
language, with no gate.

- **The kerb**: a concrete band (`CONCRETE_PAD`) 0.25 high and 0.35 wide, 1.1 outside the field's
  edge (`CURB_GAP`), its top edges chamfered 0.05 and its corners cut at 45 degrees. The kerb stands
  that far out so that from the camera no pylon covers a field cell at any zoom. The camera looks
  down 35 degrees along the view's diagonal, so a point h up hides the ground 1.43 h (h / tan 35)
  beyond it along the diagonal, 1.01 h across a side. A side pylon's cap, 0.98 up and 0.23 from the
  pylon's middle to its edge, reaches 0.23 + 1.01 × 0.98 = 1.22 inwards, 1.25 with its ink line at
  the closest zoom, which the pylons' middle line (`CURB_GAP` + half the kerb's width, 1.275)
  clears. At the corner nearest the camera the reach is along the diagonal: the corner beacon, 1.44
  up and 0.12 in radius, reaches 0.12 + 1.43 × 1.44 + 0.03 = 2.21 (the corner cap 2.09), while the
  middle of the kerb's corner cut lies 1.31 from the field's corner, so each corner pylon stands 0.9
  further out along the diagonal (`CORNER_PYLON_OUT`) on a chamfered concrete footing, 0.6 wide,
  that runs out to it from the cut.
- **Pylons**: on the kerb's middle line, one every four cells along each side (where the field
  texture's tiles meet) and one at each corner, on its footing out from the middle of the cut, 48
  on the 48×48 field (12 plates a side): a
  chamfered post 0.4 square and 0.9 tall on the plate layer in `HULL_MID`, a hazard-striped band
  near its top, a gunmetal cap, and on the cap an energy cyan lamp (unlit, PULSE) whose phase is
  the pylon's place round the loop over the count, so the pulse travels round the perimeter. The
  corner pylons stand 1.2 tall, turned across the cut, and carry a hazard yellow beacon (unlit,
  BLINK) in place of the lamp; at phases a quarter apart they flash in turn.
- **The fence**: between each pylon and the next, following the kerb round its corners, a
  gunmetal rail (`ROD`, radius 0.03, not outlined) 0.75 up, below the pylons' caps, with a ball
  joint of its radius at each of the kerb's eight bends, and under it, from the kerb's top to the
  rail, an energy panel 0.5 tall: HOLO quads in `ENERGY` on the glow layer, built as a face each
  way since the hologram culls back faces, its scan bands drifting up and its dip phased a quarter apart from
  one side to the next. It is folded half way up into a shallow V in section (`FENCE_LEAN`): its
  lower half leans 20 degrees in towards the field and its upper half 20 degrees out, the fold
  mitred round the bends, so on every side one half faces the camera and the panel reads, where
  a flat one would be seen nearly edge-on on the two sides nearest it. It is low and see-through,
  so the field's edge cells show through and over it.

One `LowPolyMesh`, about 7,800 triangles on its toon surface and 450 on its hologram surface,
and its outline. The body casts a shadow (the pylons are real masses; the transparent fence casts
none); the outline does not.

**The terrain ring**: one indexed mesh from the field's edge to ±104, on a lattice of points 1
unit apart within 54 of the centre and 2 apart beyond: 80 and 30 beyond the field's edge. A cell beside smaller ones fans out from
the point in the middle of its edge, so no point lies on another cell's edge. Its
height function is flat out to 2.4 (`TERRAIN_FLAT`), about a unit past the kerb's outer face (1.45
out), so the ground under the kerb and the corner footings is flat. From there
the relief rises to its full height by a distance out that wanders along the edge between 4 and
11 units (`TERRAIN_BLEND_NEAR`, `TERRAIN_BLEND_FAR`, on a noise whose lattice is 4 units across), so no
ramp, and no band of slope or shadow, runs straight along a side; and rubble, a noise 0.12 either
way (`RUBBLE`) on a lattice 2.3 units across, roughens the ground from 2.4 out, in full by 4.4,
whatever the relief, so the ground by the curb is low (under 0.3 at 3.8 out) and uneven. Its
shapes:

- ridged dunes, 0.3 high beside the field and growing from where the relief is full to 5 units high
  20 out, whose flanks fall into the mid band on their shadow side;
- three to five craters, radius 6 to 12, each a flat floor 0.18 radii deep, a wall steepening to
  a rim 0.15 radii high and a gentler outer slope, in ground flattened round it; three of the
  four drawn place today, at −33, 47 and 153 degrees round the field (on the 40×40 field the third
  lay at 140 degrees: the wider fine reach of the 48×48 field admits the 153-degree candidate the
  smaller one refused, which then crowds the 140-degree one out);
- two irregular flat-topped mesas towards the far edge of the view, 4 to 6 above the dunes' crests,
  with jagged rims, rough steep walls and feet that run out into the ground (below);
- a meandering dry channel running out from near the field, away from the mesas.

Each point's normal comes once from its lattice neighbours' heights, so the ring is smooth shaded
and the cel bands sweep across the dunes. The lattice runs on under the mesas, on the ground
without them, and leaves out the cells a quarter unit or more inside the outer edge of a mesa's
fillet.

**The mesas** are geometry of their own in the terrain's mesh, following their outlines rather than
the lattice, sampled every 3 degrees round them (`MESA_STEP`). Each sample is a profile
(`mesa_profile`), the same function giving the mesh's rings and `terrain_height`:

- **The rim** lies on average 1.4 inside the outline (`MESA_WALL`), its radius wandering 12 % of
  the mesa's radius either way on a noise round the outline whose lattice is 20 degrees apart
  (`MESA_JAG`), with three to five sharper V notches cut in, 0.5 to 0.9 deep and 4 to 8 degrees
  either side of their middles; its height wanders 0.3 either way on the same noise
  (`MESA_RIM_RISE`). So the top's edge dips and rises unevenly.
- **The top** is flat at the mesa's height: a fan from its middle to a ring 1 inside the rim
  (`MESA_TOP_EDGE`), straight up, then a band out to the rim, smooth shaded from straight up to
  the band's lean, so only the edge rolls.
- **The wall** runs from the rim down a straight line to 0.4 outside the outline on the ground
  (`MESA_FOOT`), in four bands between the rim, three rings at 0.2, 0.28 and 0.48 of the skirt's
  height (`MESA_RINGS`) and the fillet's top, each ring's radius moved up to 0.15 either way on a
  noise of its own round the outline (`MESA_ROUGH`, lattice 15 degrees). Each band has points of
  its own, their normals leaning as the band does, so the shading is hard between the bands and
  smooth round the mesa: angular bands, like the rocks' chamfers. One ledge per mesa steps the
  wall out 0.5 to 0.7 between the first ring and the second, a shelf, along 75 to 105 degrees of the
  outline, tapering in and out over 8 degrees (`mesa_ledges`). Its middle is seeded within 30
  degrees of the side facing the camera, since the camera never turns and a ledge on the far side
  would never be seen. Each point lies at least a little further out than the one above it,
  so the wall never overhangs.
- **The foot**: the lowest 35 % of the skirt's height (`MESA_FILLET`) is a fillet, a
  quarter-ellipse in profile, sheared so that it leaves the wall at the wall's slope, flattening
  to the ground 1.5 beyond the wall's line (`MESA_APRON`), in four segments; its height follows
  the ground under it as it flattens, and its outer edge is sunk 0.05 under the ground
  (`MESA_SINK`), its normals the ground's. It is smooth shaded throughout, so the cel bands and
  the terrain shader's slope blend (marks below about 28 degrees, strata above) run down it into
  the ground with no line.

The rim is the one hard crease: the top's points and the wall's are separate there. The
terrain's ink outline adds a fin along it, two triangles between the two faces' points, which
lie on one line until the ink shader pushes each point along its own normal and opens the fin
into a line of the outline's width; so the rim is inked from every side, beside the hull's
silhouette lines, and follows its jags. The rocks and the harness read the same shape through
`terrain_height`, which takes the profiles of the two samples either side of a point and
interpolates in the triangle of the mesh that holds it, split as the mesh splits it, so it
matches the mesh everywhere, not only at its points (the fillet's outer edge on the ground, not
sunk). The `environment` scenario checks that every point of the mesas' own geometry but the
sunk edge, and four points inside each triangle, lie on it within 0.02, that the geometry has no
open edge but that edge and no degenerate triangle, and that the rim stays within 0.3 of the
top. Each point is tinted by slope and place: `TERRAIN`,
blended towards `TERRAIN_DARK` on crater floors and the shadow side of slopes over 18 degrees,
towards `TERRAIN_LIGHT` on the lit side of slopes over 25 degrees, and towards `ROCK` on slopes
over 35 degrees (crater walls, mesa sides). The blends are soft over a few points, so the patches
are rounded, not triangles; the mesas' walls are rock and their tops the plain tint. Its ink
outline is a second mesh on the same points and normals, with the mesas' rim fins, so it inks the
crater rims and the ridges the camera looks over. The body receives shadows and casts
none.

Its surface is drawn over the tint by `terrain.gdshader` (`MaterialKit.terrain()`, its outline on
`ink()`), lit by `toon_common`'s `light()` like everything else; it samples no kit layer. In world
space, by the slope of the smooth normal:

- **Grain**: the field's, the same two octaves of value noise at 6 and 12 repeats a unit (3.5 %
  either way, each fading as its lattice falls under a pixel) and its 12-unit value noise at ±6 %,
  on the field's own cells carried outwards, so the grain runs on unbroken under the curb.
- **Marks**, on flats and dunes: the field texture's atlas, projected from above in tiles 6 units
  square (the field's are 4), in `TERRAIN_LIGHT` and `TERRAIN_DARK`, lit by its lean against
  `sun_across` exactly as on the field. A tile's variant and whether it is mirrored come from its
  cell hash (offsets 95 and 79), but its quarter-turn count from its place: (column mod 2) +
  2 × (row mod 2) − variant, mod 4 (`field_marks`' `turn_by_place`, as on the field). Tiles touching along a side or at a corner differ in (column mod 2, row mod 2), so two
  with the same variant never share a turn: over the ring's 36×36 tiles, none of the 4,970
  touching pairs shares variant and orientation (checked on the development Mac's GPU, as the
  field's were; hash picks alone, at the best offsets, left 101 on
  the 40×40 field's ring).
- **Wind ripples**, across slopes of 14 to 26 degrees (in full from 18 to 22): ridges
  along the height's contours, so they run across the slope, perpendicular to its fall. Each
  period (0.6 units on a 22-degree slope, about 0.75 at 16 degrees and 0.4 at 28, wandering by up
  to three and a half ripples either way on a value noise 5 units across) is a gentle side leaning
  0.3 towards the fall and a steep side, the last 30 %, leaning 0.9 against it; a side leaning
  towards the sun (as on the field's marks) mixes towards `TERRAIN_LIGHT`, one leaning away
  towards `TERRAIN_DARK`, at 0.8. A thin ink line (1 px at a 720 px viewport height, at 60 % of
  the marks' ink) runs along the crest on its shaded side, broken into strokes on a value noise of
  each ripple's own. They fade out where a period falls under 3 px.
- **Rock strata**, on steep faces (mesa and crater walls): the marks give way to them from 28
  degrees, in full by 38. The rock texture, `assets/textures/terrain_rock.png`
  (512×512, the image importer, mipmapped on load), in the field texture's channels: four to seven
  near-horizontal bands with jagged ink edges in two tones, each leaning up just below its top edge
  and down just above its bottom, a few cracks running down through a band, and two or three
  chunky outcrop plates leaning out from their middles with an ink outline; drawn by
  `tools/gen_textures.gd` from its own seed. It is projected along the face's facing axis (the x-
  or z-facing projection by the normal's larger horizontal part, blended where they differ by
  under 0.1), image y down the face, 4 units a tile. Its lean is lit from the sun in three
  dimensions (the key light 55 degrees up), so a band's top edge is lit (`ROCK_LIT`) and its
  underside shaded in `TERRAIN_DARK` (the faces' own tint is already `ROCK`, so a darker role
  shows the underside); tone over 0.5 mixes towards `ROCK_LIT`.

The noise-chosen dust drifts the tint once had are gone: they were soft single-tone blobs.

At the widest zoom the ring fills the view with the focus anywhere on the grid on every aspect up
to about 2.87:1 (2.98:1 on the 40×40 field: the ring's outer edge rises on noise laid in world
units, which the larger field moved), measured by marching the rays from the screen's corners over the terrain with the
focus at each corner of its bounds (a 19.5:9 phone is 2.17:1, and the `environment` scenario checks
1560x720). Beyond that the sky (**Light and shading**) shows first along the bottom of the screen,
where the rays pass under the ring's raised outer edge.

**The scenery**:

- **Rocks**: 88 chamfered chunks drawn, 0.8 to 5 units across and most of them small, of five to seven
  sides, a shoulder ring, a chamfer and a low peak, flat shaded, sides in `ROCK` and chamfers and
  tops in `ROCK_LIT`; about a quarter of those over 1.6 units across carry a smaller rock on top.
  Each sits on the lowest ground under it. A rock whose footprint meets a mesa (within its
  fillet's outer edge) is left out, built into a mesh that is thrown away so that the rest keep
  their places: nine today, which the `environment` scenario checks by every rock vertex lying
  outside the mesas' reach. One mesh with its outline; the body casts shadows.
  Their rule keeps a rock only its radius plus 1.5 outside the field, which does not by itself
  keep it off the perimeter; that clearance is checked (the `environment` scenario), not enforced.
- **Rubble**: 44 more rocks of the same make, 0.3 to 0.8 units across, strewn beside the curb
  between 2.4 and 7.4 units outside the field (`RUBBLE_ROCKS`, `RUBBLE_ROCK_RADIUS`,
  `RUBBLE_ROCK_OUT`), eleven along each side, each in a stretch of the side of its own at a random
  distance out, so they spread evenly, form no line, and none comes within about half a unit of
  the curb's outer face, the nearest centres about a unit past it. Each keeps clear of the craters,
  the mesas, the channel, the other rocks and the outcrops, and rests on the lowest ground under it, sunk by a fifth of its radius. They are in
  the rocks' mesh, and draw from the seed after the outcrops, so the rocks and the outcrops keep
  their places.
- **Crystal outcrops**: six to ten clusters of three to seven shards, each a six-sided crystal 0.6
  to 2 units long leaning out from the cluster's middle, on the crystal layer, unlit, in
  `CRYSTAL`, `METAL` and `ANTIMATTER` in turn from a seeded start, outlined. No part of one comes
  within 4 units of the field; they keep off the mesas and out of the craters' bowls. One mesh with
  its outline; the body casts shadows.

**Budgets**: the field 1 draw; the perimeter, the terrain, the rocks and the outcrops a body and an
outline each, the perimeter's body two surfaces (its fence a hologram) and drawn into the shadow
map. The terrain is 38,522 triangles on 20,950 points, its outline 39,002 with the mesas' fins
(the `environment` scenario allows the body 40,000), the rocks about 4,200 (about 1,350 of them
the rubble) and the outcrops about 800. It is
all built once, in about 135 ms on the development Mac (112 to 138 on the 40×40 field, measured
side by side; 88 to 97 warm before the perimeter's
pylons and fence added about 22, and 74 to 79 before a half-unit lattice round the mesas, since
gone, and the rock texture,
each measured side by side; the kit's build and the field and rock textures' loads and mipmaps
included; the mesas' fillets, rough walls and jagged rims left it about the same), the terrain 59
to 66 ms of it (45 to 49 before), the perimeter about 25 and the rubble about 5; phones are
unmeasured. Nothing runs per frame beyond the shaders.

## HUD

The HUD follows the same comic look in 2D (`hud.md`, **Theme**): two display fonts, Bangers
for its loudest labels and Lilita One for the rest; a UI palette of the same ink (`1B1A2E`), deep
violet panels and cards, a near-white text, the energy cyan for the selected and the confirming
and a build gold; every shape a flat fill with a 3 px ink border, round corners and a flat ink
shadow offset down and right; text on a bright fill or over the world outlined in ink. Its
icons (the resource meters' ingot, shards and orb, seen from an angle, and the drone ring's
quadcopter, seen from above)
are vector shapes drawn in code, flat fills with a lighter facet and an ink outline, with no
asset file. The meters' stripes drift, a hard-edged glint crosses each fill in turn and a change
flashes it, all from `anim_time` (`meter.gdshader`, `hud.md`, **Top bar**).
The build cards carry their category's accent from **Colour** as a stripe.

## Cost

A building's body instances draw for the light and into the shadow map; its outline instances
draw once and never cast. Measured with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`: a fresh
base is 48 draw calls with the HUD's build panel closed (46 before the perimeter gained its
hologram fence and its shadow; earlier, 63 with the always-visible build bar it replaced, 57 of
those before the environment's curb, terrain outline and outcrops). The panel costs only while
it is open: a fresh base with it open is 107 draw calls on a full tab (resources, army, defence)
and 91 on traps, the cards' pictures included (110, 94 and 73 on a walls tab while it had five
tabs; 100, 86 and 68 before the pictures). The pictures cost one 160×160 render per type, one a
frame, the first time the panel opens, each read back into a 100 KB texture (about 3 MB for
today's menu), and nothing per frame once every type is cached and the preview's viewport is
freed (`hud.md`, **Pictures**). The model gallery lays out 259 models (every type to its ten-level
data, a level above a type's modelled top showing its top model) over three pages, whose
overviews are 527, 680 and 566 draw calls with every type animated (76, 83 and 100 models at
once); with two pages and 121 models it was 552 and 275 (565 and 217 before the Cadet Academy's
levels moved rows between the pages; 362 and 158 before the animation pass, when nine types had
one spinner each; 381 and 177 with the build bar, 375 and 171 before the environment, 294 and
157 before the kit): every moving part is two more draws and a shadow draw, and every mesh with
holograms one more. The render thread's CPU time on the development Mac is about 0.7 to 0.9 ms a
frame on page 1, 0.9 to 1.3 ms on page 2 and 0.9 to 1.1 ms on page 3, measured with the
gallery's own line over two runs (with two pages, 1.2 to 1.5 ms on page 1, 74 of the 121 models,
and 0.4 to 0.7 ms on page 2); it
does not move with the shadow's filter (0, 2 or 4 measure the same within that noise), since PCF
costs on the GPU: 13 shadow taps a fragment near a shadow edge (fewer where the first taps
agree), and the penumbra's dot screen a few more instructions in `light()`. The shadow map,
1024² at 16 bits, is 2 MB. The kit's texture array, twenty 256×256 RGBA8 layers, is about 6.7
MB with its mipmaps (5.7 with seventeen); the field texture, one 1024×1024 RGBA8 image, is about 5.3 MB with its
mipmaps too, and the ground and the terrain share it; the terrain's rock texture, one 512×512
RGBA8 image, is about 1.4 MB with its mipmaps. The terrain's shader has two samplers (the field
texture and the rock texture) and takes three texture reads a fragment (the field's marks and
the rock texture along x and along z), with five value noises. Keep `_process` free of
allocation, and keep every building to its eight instances, ten at Crown (**Animation**); a busy building adds
its construction drone's four. The shader effects cost a few integer tests and a sine or two a
vertex and a fragment, and no draw; a moving part costs two draws (its body and its outline)
plus the body's shadow draw, and a mesh with HOLO parts one more draw in the transparent pass.
The finished walls are one merged mesh, a fixed handful of draws however many there are
(`input-camera.md`, **Walls**).
