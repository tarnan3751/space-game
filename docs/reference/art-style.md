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
| `src/game/holo.gdshader` | the hologram surface (**Animation**) |
| `src/game/motion.gd` | `Motion`: how a moving part moves (**Animation**) |
| `src/game/ground.gdshader` | the buildable field: its ground, its marks, the grid |
| `src/game/terrain.gdshader` | the terrain ring's body: its marks, ripples and rock strata over the vertex tint |
| `src/game/field_marks.gdshaderinc` | the field texture's tiles, the marks' light and the grain, shared by the ground and the terrain |
| `src/game/base_view.gd` | builds the ground, the curb, the terrain ring, the rocks and the outcrops (**Environment**) |
| `src/game/building_models.gd`, `src/game/models/` | the dispatcher and one model file per category, `Parts` in `models/parts.gd` |
| `assets/textures/kit/` | the sixteen layers, committed PNGs |
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

`main.gd` builds the environment: deep space behind (`SPACE`, `0D0B1A`, the clear colour, which
the terrain ring hides at every zoom on screens up to about 2.98:1; there is no sky), a cool ambient
(`AMBIENT`, `8C8CFF` at 0.35), linear tonemapping (filmic desaturates the accents), and one
`DirectionalLight3D`, the key light: warm white (`SUN`, `FFF4E0`) at energy 1.0, from the upper
left of the view (rotation −55°, −30°), casting one hard `SHADOW_ORTHOGONAL` split out to 80
units. `project.godot` sets the directional shadow map to 2048 with no soft filtering. There is
no second light: bands are per light and add up, so a second light doubles the tones.

The toon, ground and terrain shaders take no ambient light (`render_mode
ambient_light_disabled`). The Compatibility renderer adds the ambient pass and the shadowed key
light's pass separately, each already in sRGB, so even a little ambient lifts every band past the
shadow band's whole tone and washes it blue; the cool side lives in the shadow band's tint
instead. The environment's ambient still lights anything else (none of the scene today).

`light()` in `toon_common.gdshaderinc` quantises the key light, its shadow included (`NdotL`
times the shadow term, which is first stepped at 0.5 so a shadow's edge is crisp rather than a
one-texel fringe of the mid band), into three bands with 0.02-wide smoothstep edges:

| Band | NdotL × shadow | Tone (sRGB, of the albedo) | Measured on a flat box |
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
- **Cel specular**: on glossy surfaces only (glass, metal trim): a hard-edged disc where NdotH
  passes 0.92, white at 0.35, in the lit band.
- **Emissive surfaces** (flag unlit): pure emission, full tint: no bands, no halftone. A lit
  surface glows by the texture's alpha (glass 0.3, a screen's rows, a crystal's facets).

There is no rim light: with the orthographic camera a fresnel rim falls under the ink outline,
which already lifts every silhouette off what is behind it.

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
| Core gold | `F2B134` | `CORE_GOLD` | Command Center trim, top-level trim on every type, the selected outline |
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
The top level of every type adds core gold trim (edges, rings, caps), so a maxed building reads as
maxed from across the base. Under the warm key light every lit colour leans warm.

The field's and the terrain's roles are picked so that, under the warm key light and over their
textures, they render as the art direction asks: each is bluer and more saturated than it shows.
The rendered column is the average over flat ground at the widest zoom (the `environment`
scenario's widest shot, measured in HSL): the field as a whole, ground, marks and grid together,
over each quarter of it clear of the HUD and the buildings; and the ring's flat dust. The field is
the lighter, cooler plain; the ring the deeper, more saturated land round it; the buildings' hulls
the lightest things on screen.

| Role | Constant | Value | Rendered | Where |
| --- | --- | --- | --- | --- |
| Field dust | `FIELD` | `543FCC` | the field: `5B509F` to `5F54A6` (L 0.47 to 0.49, S 0.33) | the field's dust, covering the ground at 60 %; the most saturated, as the plate tint greys it |
| Field light | `FIELD_LIGHT` | `827FD7` | | the lit sides of the field's marks (crater walls, pebbles, shards), its light tones |
| Field dark | `FIELD_DARK` | `4D479F` | | the shadow sides of the field's marks, its dark tones (crater and pit floors) |
| Field plate | `FIELD_PLATE` | `8083C3` | | the levelled ground under the dust (a cooler grey-violet) |
| Terrain | `TERRAIN` | `564AC5` | the ring's flats, marks and grain included: `5346A2` to `5747AE` (L 0.46 to 0.48, S 0.40 to 0.42) | the ring's dust |
| Terrain light | `TERRAIN_LIGHT` | `7A73E3` | | the lit side of slopes over 25 degrees; the light sides and tones of the ring's marks, the lit sides of its ripples |
| Terrain dark | `TERRAIN_DARK` | `3E388C` | | crater floors and the shadow side of slopes over 18 degrees; the dark sides and tones of the ring's marks, the shaded sides of its ripples, the strata's undersides |
| Rock | `ROCK` | `50619B` | | slopes over 35 degrees (crater walls, mesa sides), the scenery rocks' sides, the crystal harvester's rock bed |
| Rock lit | `ROCK_LIT` | `768BC9` | | the scenery rocks' chamfers and tops; the strata's lit top edges, light bands and outcrop plates |

The field's row is lighter than when ink seams ran between its tiles: away from where they ran
the plain renders as it did (L 0.485 against 0.486). The ring's row was re-measured when its
surface was drawn (marks, ripples, strata): over the same three stretches of flat ring the
untextured ring rendered `5547A6` to `5A4CA8` (L 0.46 to 0.48, S 0.38 to 0.40), and the field's
four quarters rendered pixel for pixel as before. The curb is `CONCRETE` with `ENERGY` studs;
the outcrops are `CRYSTAL`, `METAL` and `ANTIMATTER`.

## The material kit

One `Texture2DArray` of sixteen 256×256 RGBA8 layers. RGB is the albedo: near-white greys (0.78
to 1.0) with ink-coloured lines for the layers a tint multiplies, real colours for the fixed ones,
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
`MaterialKit.Layer` and `MaterialKit.LAYERS`. Run the generator, then the gate, which imports the
new PNG and writes its `.import`; edit that file to `importer="image"` as the others are, run the
gate again, and commit the PNG and its `.import`. The gallery checks that no vertex names a layer
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
| `prism(bottom_radius, top_radius, height, sides, pos, surf, rot)` | a cylinder or a tapered one, capped |
| `cone`, `pyramid` | a cone, a four-sided cone |
| `dome(radius, height, sides, rings, pos, surf, rot)` | a hemisphere squashed to `height` |
| `orb(radius, sides, rings, pos, surf, rot)` | a sphere centred on `pos` |
| `ring(inner_radius, outer_radius, height, sides, pos, surf, rot)` | an annulus with walls, open underneath |
| `tube(inner_radius, outer_radius, height, sides, pos, surf, rot)` | a hollow cylinder closed at both ends, for pipes and bores turned on their side |
| `disc(radius, sides, pos, surf, rot)` | a flat polygon facing up |
| `lathe(profile, sides, pos, surf, rot)` | the general round part |
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

`BuildingModels.create(type, level, size)` dispatches to one static `build_<type>(p: Parts,
level: int)` in its category's file under `src/game/models/` (`core.gd`, `resources.gd`,
`army.gd`, `defense.gd`, `traps.gd`, `walls.gd`); `MODELS` gives each type the footprint its
models are built for and its level count. `Parts` holds the model while it is built: `body` (a
`LowPolyMesh`), up to three moving parts (`moving(pivot, motion)`, **Animation**), and the shared
helpers. A model is a `Node3D` with the body's `MeshInstance3D` and its outline's beside it, and
a `Node3D` per moving part at its pivot carrying `MOVE_META` (its `Motion`), with the part's mesh
and its outline under it. That is at most **eight** `MeshInstance3D`: the body and up to three
moving parts, each with an outline (`OUTLINE_META`, no shadow); a moving part made only of
parts that are never outlined has no outline instance. Meshes are built once per type and level
and cached; `BuildingModels.instantiate(parts)` assembles an uncached model from parts a caller
built itself (the `effects` rig). The contract any model keeps, built or imported:
origin at the footprint centre on the ground, +Y up, fitting inside `size × size` cells.

The `model_gallery` harness scenario lays out every type and level and checks each: one to four
body instances, each with its outline instance on the ink material casting no shadow unless all
its parts are never outlined, every layer within the kit, and the body triangles (both surfaces)
and the extent over every moving part's whole motion within the budgets below. Its detail shots
at the closest zoom are where a model is judged.

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

### Model table

One line per type, in roster order: the signature element that names it from across the base,
its animation (moving parts and surface effects, **Animation**), and its top level's body
triangles as the gallery counts them.

| Type | Signature element | Animation | Top level, body triangles |
| --- | --- | --- | --- |
| `command_center` | glass dome ringed in gold on a tall drum over a stepped foundation, a hazard-striped hangar door; wings, a ring of rooms, a violet containment ring and a gold beacon spire as it grows | spin: the comms dish on its pylon | 4,830 |
| `drone_bay` | landing deck in a hazard ring of cyan lights, a parked drone, a control booth with a gold roof; the drone's body, 0.42 across at 12 sides, is the one exception to the small-part side counts | spin: the beacon on the booth | 1,968 |
| `metal_extractor` | tripod derrick over a drill, conveyors carrying glowing ore into hoppers, exhaust stacks | spin: the drill string and its top drive | 2,610 |
| `crystal_harvester` | laser gantry over a cluster of glowing crystal shards | spin: the focusing emitter and its beam | 1,800 |
| `antimatter_siphon` | coiled torus round a glowing violet core, field pylons leaning in | spin: the torus and its coils | 2,968 |
| `metal_silo` | squat banded tank with a glowing fill gauge and a ladder; twin tanks from L4 | none | 2,346 |
| `crystal_silo` | tall hexagonal tank of crystal-lit glass panels under a chamfered lid and a crystal finial | none | 838 |
| `antimatter_vault` | armoured chamfered cube with a round vault door, violet seams and a containment pylon on each corner | none | 2,824 |
| `hangar` | barrel-vaulted bays with orange ribs and hazard-striped doors, a glass-cabbed control tower | none | 4,362 |
| `fabricator` | sawtooth-roofed factory, an orange gantry crane over a loading dock, smokestacks | none | 1,950 |
| `heavy_fabricator` | armoured hall with orange press arms hammering anvils, a glowing furnace mouth | none | 2,024 |
| `research_lab` | observatory dome with a telescope, in a ring of screens | spin: the radar dish on its mast | 2,704 |
| `nanite_foundry` | vats with bands of glowing nanite-green goo, piped with ball elbows | none | 2,870 |
| `drydock` | half-built ship in a cradle under orange gantries, welders throwing sparks | none | 2,946 |
| `alliance_beacon` | braced transmitter tower with rings of light, a big dish and an emitter orb | none | 2,096 |
| `laser_turret` | domed head on the red-belted plinth, twin barrels ending in red emitters | spin: the head | 2,722 |
| `missile_battery` | tilted box launcher of red-tipped tubes (4, 6 at L3, 9 at L4) with a hazard band | none | 2,174 |
| `plasma_mortar` | fat short barrel rising from a caged violet plasma chamber on a heavy ring | none | 2,782 |
| `shield_generator` | cyan energy orb held over an emitter dome by three coil arms | none | 2,914 |
| `flak_cannon` | barrels angled at the sky on a tall bell mount | spin: the radar dish on its mast | 2,900 |
| `arc_tower` | tesla coil of white insulator skirts under an arc-blue sphere; twin coils at L4 | none | 2,794 |
| `cloaked_sentry` | low dark hexagonal pod with a lid gun and a dim cyan shimmer ring | none | 854 |
| `gravity_well` | dark core floating over a violet well, ringed by gyro rings | spin: the rotor over the core | 1,978 |
| `emp_tower` | yellow core in a bar cage atop a stepped tower ringed by capacitor cans | none | 2,854 |
| `railgun` | two long rails across the screen with a cyan strip between them, capacitor banks | none | 2,088 |
| `ion_beam` | big crystal lens and focusing rings on a tripod | none | 1,964 |
| `orbital_cannon` | massive gunmetal barrel aimed at the sky with cyan coils, on a two-tier bunker | none | 4,496 |
| `proximity_mine` | spiked domed disc on a hazard rim with a red warning light | none | 542 |
| `grav_trap` | ring emitter round a dark funnel with a violet swirl | none | 580 |
| `flak_mine` | hazard-banded pod, upward barrels with glowing bores round a lens | none | 574 |
| `mega_mine` | big armoured dome on a hazard band ringed with red lights | none | 1,214 |

## Animation

Two ways for a model to move: **surface effects**, which the shaders animate from `TIME` per
part, and **moving parts**, nodes `BuildingView` moves. What each costs in draws:

- The shader effects (PULSE, BLINK, FLICKER, FLOW, FLOW_U, BOB, JITTER) add no draw: they are
  flags on parts of meshes that are drawn anyway.
- A moving part is two more instances, its body and its outline: two draws, plus the body's draw
  into the shadow map.
- A HOLO part puts one more surface on its mesh: one more draw, in the transparent pass, for each
  mesh (the body or a moving part) that has holograms.

While a building is busy (constructing an upgrade) its moving parts stop and resume where they
stopped; its surface effects keep running, since they come from `TIME` with no per-instance
state. That is intended.

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
| `FLOW` | 32 | the texture scrolls along V at (phase - 0.5) × 4 repeats a second: 0.5 still, 0.75 one repeat a second forward, 0.25 back. Liquids in pipes (the pipe layer's bands), currents (the glow layer's stripes), conveyors (grating), screens |
| `FLOW_U` | 64 | the same along U: discs, rings. It shows only on a layer that varies along U: not the glow layer, whose stripes run along it |
| `BOB` | 128 | the part rises and falls 0.08 along world Y on a sine of period 2.4 s: floating cores, holograms |
| `JITTER` | 256 | each vertex jumps up to 0.04 in a pseudo-random direction (a hash of its position and the time step), 20 times a second; corners shared by faces move together. With UNLIT and FLICKER, a crackling arc: build it of short segments so there are corners to shake |
| `HOLO` | 512 | a hologram (below) |

Effects compose: UNLIT + PULSE, UNLIT + FLICKER + JITTER, FLOW + PULSE. `TIME` wraps every hour
(the project's `time_rollover_secs`); BLINK, PULSE and BOB cycle evenly into the hour, FLOW and
the hologram's dip jump once an hour.

**Holograms.** A HOLO part is transparent, so `LowPolyMesh.to_mesh()` puts it in a surface of its
own on `MaterialKit.holo()` (`holo.gdshader`: unshaded, alpha-blended, no depth writes, back faces
culled): the kit layer times the tint at alpha 0.45; scan bands, a sawtooth 0.5 units long in
world Y drifting up at 0.4 units a second, brightening by up to 0.4; a rim where the view grazes
the surface, up to 0.3 brighter; and a dip of the alpha to 0.2 for 0.1 s every 2.6 s, offset by
the phase. A near-white layer (glow) shows the tint best. A hologram is never outlined, never in a
wall piece (**Walls**), and keeps its look on a placement ghost (**View states**).

### Moving parts

`Parts.moving(pivot, motion) -> LowPolyMesh` makes a moving part: build it in its own space,
the pivot at its origin, as the parts of the body are built. A model has at most three
(`Parts.MAX_MOVING`, asserted). `Motion` (`src/game/motion.gd`) says how it moves:

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

`BuildingView` collects the moving nodes once and sets each one's transform every frame from
`Motion.transform_at(time, rest)`, with no allocation, on a clock that runs only while the
building is finished and idle, so a part stops while the building is busy and resumes where it
stopped. A view with no moving part does no work per frame.

### Budget and checks

A building is at most eight instances: the body, its outline, and up to three moving parts with
their outlines. The `model_gallery` scenario checks every model against it (**Models**), and a
moving part's reach over its whole motion against the extent (**Modelling vocabulary and
budgets**): a spin's circle about its axis, a swing's bounds every 5 degrees from -amplitude to
+amplitude, both ends included, a slide's at both ends.

The `effects` harness scenario (`tools/harness/README.md`) is the rig: a part for every effect and
every kind of motion, in two rows on the field, checked headless and screenshotted at 0.0, 0.3 and
0.9 seconds rendered. Try a new effect combination there first.

## Modelling vocabulary and budgets

- **Budgets**, body triangles (outlines repeat them and are not counted): 4×4 and 5×5 up to
  5,000; 3×3 up to 3,000; 2×2 up to 2,000; 1×1 traps up to 600; one wall piece up to 250. They are
  mobile ceilings, not targets: spend triangles where a silhouette or a curve needs them.
- **Extent**: in x and z a model stays within its footprint plus 0.15 units: the static body's
  bounds, and every moving part's reach over its whole motion (a turning head or dish must clear
  the footprint at every angle, a swinging arm at both ends of its swing). Height is free. The gallery checks it on every type and level.
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
  greeble and a stronger emissive; the top level adds core gold trim. Levels 1 to 5 of a type
  read as one building growing, never as five buildings.
- Moving parts (radar dishes, turbines, gyros, press arms, recoiling barrels): three per
  building at most (**Animation**).
- Scale: a size-2 building stands 1.2 to 2.0 units tall, a 4×4 Command Center up to 3.2.
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
one thick slab with the posts standing just proud as joints. Heights are the post's top, cap
included:

| Level | Post | Segments |
| --- | --- | --- |
| 1 | Squat, 0.55 | Slate plates |
| 2 | 0.64, gunmetal cap | Riveted slate armour with a band |
| 3 | Ribbed (the `pipe` layer), 0.72, gunmetal cap | Ribbed slate, an energy cyan strip along the top |
| 4 | A plated pylon with wide chamfers, 0.81, gunmetal cap | Double plated: a sloped riveted skirt under a slate plate, a brighter strip |
| 5 | The level 4 post with a gold crown, 0.9 | A low riveted base under an energy field panel |

The strips and the field are unlit (`glow`, flags 1) and, being thin, have no ink. A segment's
end on the cell edge is a cap painted like the segment but left out of the outline, so two
segments that meet there draw one unbroken ink line; where walls of different levels meet, the
taller segment's end shows as a step without an ink edge, and every level's curb meets the next.

`piece(level, mask)` builds a piece on first use and keeps its body and outline arrays
(`to_arrays`, `to_outline_arrays`), 5 levels by 16 masks at most (a higher level shows level
5's); every piece stays within the 250 body triangles of a wall piece (`wall_junctions` checks
all 80). `build_barrier_wall`, which `BuildingModels.create("barrier_wall", level, 1)` dispatches
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
| Under construction | the scaffold, a model like any other, outlined |

A wall drawn by the merged wall mesh hides its own model, outlines included (`set_merged`), so a
selected merged wall shows its footprint tile and no gold, and the merged outline stays plain ink.
A dragged wall leaves the mesh and shows its own post, lifted with gold outlines like any dragged
building; the paint brush is a ghost and keeps plain ink.

## Environment

The ground and everything round it, drawn in the buildings' language: a levelled, lit landing
plain inside a deeper, wilder landscape, so the base reads as a settlement. `BaseView.setup`
builds it all once; the terrain, the rocks and the outcrops come from `SeededRng` on
`SCENERY_SEED` (7), so every base sits in the same landscape (`input-camera.md`, **BaseView**).

**The field** (`ground.gdshader`, on the 40×40 `PlaneMesh` at y = 0): one seamless levelled plain
of regolith with natural marks scattered over it. Everywhere the ground is the plate tint covered
at 60 % by the dust, with a fine grain drawn by the shader in world space, so it runs on unbroken
across the field: two octaves of value noise at 6 and 12 repeats a cell, each 3.5 % either way, each
fading out as its lattice falls under a pixel so it does not shimmer at the widest zooms. A value
noise twelve cells across varies the plain 6 % either way, and it darkens by 10 % from half way out
to its edge. An ink line 3 px wide runs along the field's edge, at a 720 px viewport height and
scaled with it, like the ink outline; the 1-cell grid stays in holographic cyan (`line_strength`
0.1, 0.45 while placing). There is no other line, seam or square on it. The lighting is `light()`
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
view's columns and rows nor along the grid: none of the field's 75 lies within 0.2 cells of a
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
orientation (0 to 7: a quarter turn count 0 to 3, mirrored from 4 on) from its cell hash at two
offsets: 32 looks, and the hash offsets are picked so that no two tiles of the 40×40 field that
touch, along a side or at a corner, share both (checked on the development Mac's GPU). The shader
turns the tile's own coordinates into the variant's about its middle and samples the atlas with
the gradients of the unturned coordinates, so the mipmap does not jump where tiles meet. It turns
the stored lean back into the field's axes (the turn's transpose) and lights it from `sun_across`
(`BaseView.SUN_ACROSS`, the key light's direction across the ground): where the lean towards the
sun passes 0.25 it mixes towards `FIELD_LIGHT`, in full by 0.4, and away from it towards
`FIELD_DARK` the same way. So however a tile lies, a crater's wall is lit on the side away from
the sun and a pebble on the side towards it. Then the tone, then the ink. The tiles are only what
keeps the plain from repeating: there is no seam between them, no tint of their own, no grain of
their own, and no made thing (patch, bolt or joint) among the marks.

**The curb** (`boundary`): a concrete band 0.2 high and 0.3 wide, 0.3 outside the field's edge,
its corners cut at 45 degrees and its top edges bevelled, with a glowing energy cyan stud (unlit,
not outlined) on it every four cells along each side and on each corner cut. One mesh with its
outline; neither casts a shadow.

**The terrain ring**: one indexed mesh from the field's edge to ±100, on a lattice of points 1
unit apart within 50 of the centre and 2 apart beyond, cut to half a unit within 3 units of a
mesa's outline (`TERRAIN_MESA_REACH`, measured from `_mesa_edge`; a half-unit cell keeps a
one-unit cell from the coarse ones). A cell beside smaller ones fans out from the point in the
middle of its edge, so no point lies on another cell's edge. Its
height function is flat out to 0.8 (`TERRAIN_FLAT`) and the mesh is within 0.03 of flat under the
curb (it has no point between the field's edge and a unit out). From there the relief rises to its
full height by a distance out that wanders along the edge between 4 and 11 units
(`TERRAIN_BLEND_NEAR`, `TERRAIN_BLEND_FAR`, on a noise whose lattice is 4 units across), so no
ramp, and no band of slope or shadow, runs straight along a side; and rubble, a noise 0.12 either
way (`RUBBLE`) on a lattice 2.3 units across, roughens the ground from 0.8 out, in full by 2.8,
whatever the relief, so the ground by the curb is low (under 0.3 three units out) and uneven. Its
shapes:

- ridged dunes, 0.3 high beside the field and growing from where the relief is full to 5 units high
  20 out, whose flanks fall into the mid band on their shadow side;
- three to five craters, radius 6 to 12, each a flat floor 0.18 radii deep, a wall steepening to
  a rim 0.15 radii high and a gentler outer slope, in ground flattened round it;
- two irregular flat-topped mesas towards the far edge of the view, 4 to 6 above the dunes' crests,
  with steep walls;
- a meandering dry channel running out from near the field, away from the mesas.

Each point's normal comes once from its lattice neighbours' heights, so the ring is smooth shaded
and the cel bands sweep across the dunes. Each point is tinted by slope and place: `TERRAIN`,
blended towards `TERRAIN_DARK` on crater floors and the shadow side of slopes over 18 degrees,
towards `TERRAIN_LIGHT` on the lit side of slopes over 25 degrees, and towards `ROCK` on slopes
over 35 degrees (crater walls, mesa sides). The blends are soft over a few points, so the patches
are rounded, not triangles. Its ink outline is a second mesh on the same points and normals, so it
inks the crater rims and the ridges the camera looks over. The body receives shadows and casts
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
  2 × (row mod 2) − variant, mod 4 (`field_marks`' `turn_by_place`; the field keeps its own hash
  picks). Tiles touching along a side or at a corner differ in (column mod 2, row mod 2), so two
  with the same variant never share a turn: over the ring's 35×35 tiles, none of the 4,692
  touching pairs shares variant and orientation (checked on the development Mac's GPU, as the
  field's were; hash picks alone, at the best offsets, left 101).
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
to about 2.98:1, measured by marching the rays from the screen's corners over the terrain with the
focus at each corner of its bounds (a 19.5:9 phone is 2.17:1, and the `environment` scenario checks
1560x720). Beyond that the clear colour shows first along the bottom of the screen, where the rays
pass under the ring's raised outer edge. There is no sky.

A known limitation: at a mesa's foot the steep wall meets level ground within a few lattice
steps, so the normal turns from wall to flat over a few points and, where the wall's shadow band
tapers to the foot, the edge of the cel bands breaks into small triangular teeth. The half-unit
lattice within the mesas' reach spreads the turn over twice as many points and reduces the teeth
to about half their size; it does not remove them. Beside them, at the mesas' rims, where the wall
meets the flat top, small notches show along the line where the strata give way to the marks, as
the slope crosses 28 to 38 degrees within a few points. A hard crease along the foot and the rim
(the wall and the ground each with their own vertices and normals) was tried and is worse: on the
square lattice the crease follows the triangles' edges, so it runs as a sawtooth. Removing both
would take wall geometry that follows the mesa's outline rather than the lattice.

**The scenery**:

- **Rocks**: 80 chamfered chunks, 0.8 to 5 units across and most of them small, of five to seven
  sides, a shoulder ring, a chamfer and a low peak, flat shaded, sides in `ROCK` and chamfers and
  tops in `ROCK_LIT`; about a quarter of those over 1.6 units across carry a smaller rock on top.
  Each sits on the lowest ground under it. One mesh with its outline; the body casts shadows.
- **Rubble**: 36 more rocks of the same make, 0.3 to 0.8 units across, strewn beside the curb
  between 1.6 and 6.6 units outside the field (`RUBBLE_ROCKS`, `RUBBLE_ROCK_RADIUS`,
  `RUBBLE_ROCK_OUT`), nine along each side, each in a stretch of the side of its own at a random
  distance out, so they spread evenly, form no line, and the nearest is about a unit past the
  curb's outer face. Each keeps clear of the craters, the mesas, the channel, the other rocks and
  the outcrops, and rests on the lowest ground under it, sunk by a fifth of its radius. They are in
  the rocks' mesh, and draw from the seed after the outcrops, so the rocks and the outcrops keep
  their places.
- **Crystal outcrops**: six to ten clusters of three to seven shards, each a six-sided crystal 0.6
  to 2 units long leaning out from the cluster's middle, on the crystal layer, unlit, in
  `CRYSTAL`, `METAL` and `ANTIMATTER` in turn from a seeded start, outlined. No part of one comes
  within 4 units of the field; they keep off the mesas and out of the craters' bowls. One mesh with
  its outline; the body casts shadows.

**Budgets**: the field 1 draw; the curb, the terrain, the rocks and the outcrops a body and an
outline each. The terrain is 35,820 triangles on 18,190 points (the `environment` scenario allows
38,000), the rocks about 3,900 (about 1,100 of them the rubble) and the outcrops about 900. It is
all built once, in about 90 ms on the development Mac (88 to 97 warm, against 74 to 79 before the
half-unit lattice and the rock texture, measured side by side; the kit's build and the field and
rock textures' loads and mipmaps included), the terrain 59 to 66 ms of it (45 to 49 before) and the
rubble about 5; phones are unmeasured. Nothing runs per frame beyond the shaders.

## HUD

The HUD follows the same comic look in 2D (`hud.md`, **Theme**): two display fonts, Bangers
for its loudest labels and Lilita One for the rest; a UI palette of the same ink (`1B1A2E`), deep
violet panels and cards, a near-white text, the energy cyan for the selected and the confirming
and a build gold; every shape a flat fill with a 3 px ink border, round corners and a flat ink
shadow offset down and right; text on a bright fill or over the world outlined in ink. Its
icons (the resource meters' ingot, shards and orb, the drone ring's drone, seen from an angle)
are vector shapes drawn in code, flat fills with a lighter facet and an ink outline, with no
asset file.
The build cards carry their category's accent from **Colour** as a stripe.

## Cost

A building's body instances draw for the light and into the shadow map; its outline instances
draw once and never cast. Measured with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`: a fresh
base is 44 draw calls with the HUD's build panel closed (63 with the always-visible build bar it
replaced, 57 of those before the environment's curb, terrain outline and outcrops). The panel
costs only while it is open: a fresh base with it open is 100 draw calls on a full tab
(resources, army, defence), 86 on traps and 68 on walls. The model gallery's overview is 362
draw calls on page 1 and 158 on page 2 (381 and 177 with the build bar, 375 and 171 before the
environment, 294 and 157 before the kit; the research lab's spinning dish adds 15 on page 1),
and the render thread's CPU time is about 0.5 ms a frame either way. The kit's texture array,
sixteen 256×256 RGBA8 layers, is about 5.3 MB with its mipmaps; the field texture, one 1024×1024
RGBA8 image, is about 5.3 MB with its mipmaps too, and the ground and the terrain share it; the
terrain's rock texture, one 512×512 RGBA8 image, is about 1.4 MB with its mipmaps. The terrain's
shader has two samplers (the field texture and the rock texture) and takes three texture reads a
fragment (the field's marks and the rock texture along x and along z), with five value noises.
Keep `_process` free of allocation, and keep every building to its eight instances
(**Animation**). The shader effects cost a few integer tests and a sine or two a vertex and a
fragment, and no draw; a moving part costs two draws (its body and its outline) plus the body's
shadow draw, and a mesh with HOLO parts one more draw in the transparent pass. The finished walls
are one merged mesh, a fixed handful of draws however many there are (`input-camera.md`,
**Walls**).
