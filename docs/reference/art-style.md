# Art style

The comic style every model, the ground and the scenery are drawn in: the look, the light, the
colours, the material kit, how `LowPolyMesh` paints a part, the ink outline, the modelling
vocabulary and budgets, and the view states. Every model brief points here. The scene, the
camera and the views' wiring are in `input-camera.md`.

| File | What |
| --- | --- |
| `src/game/material_kit.gd` | `MaterialKit`: the kit's `Texture2DArray`, the colour roles, the shared materials |
| `src/game/surf.gd` | `Surf`: how a part is painted |
| `src/game/low_poly_mesh.gd` | `LowPolyMesh`: parts, UVs, smoothing, the body and outline meshes |
| `src/game/toon.gdshader`, `toon_common.gdshaderinc` | the body shader and the light it shares with the ground |
| `src/game/ink.gdshader` | the outline shader |
| `src/game/ground.gdshader` | the buildable ground |
| `src/game/building_models.gd`, `src/game/models/` | the dispatcher and one model file per category, `Parts` in `models/parts.gd` |
| `assets/textures/kit/` | the sixteen layers, committed PNGs |
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

`main.gd` builds the environment: deep space behind (`SPACE`, `0D0B1A`), a cool ambient
(`AMBIENT`, `8C8CFF` at 0.35), linear tonemapping (filmic desaturates the accents), and one
`DirectionalLight3D`, the key light: warm white (`SUN`, `FFF4E0`) at energy 1.0, from the upper
left of the view (rotation −55°, −30°), casting one hard `SHADOW_ORTHOGONAL` split out to 80
units. `project.godot` sets the directional shadow map to 2048 with no soft filtering. There is
no second light: bands are per light and add up, so a second light doubles the tones.

The toon and ground shaders take no ambient light (`render_mode ambient_light_disabled`). The
Compatibility renderer adds the ambient pass and the shadowed key light's pass separately, each
already in sRGB, so even a little ambient lifts every band past the shadow band's whole tone and
washes it blue; the cool side lives in the shadow band's tint instead. The environment's ambient
still lights anything else (none of the scene today).

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
| Ground | `6E6684` | `GROUND` | the regolith ground and dust; craters `5A5370` (`CRATER`) |
| Rock | `585466` | `ROCK` | scenery rocks and ridges; lit face `7A7588` (`ROCK_LIT`) |

A building uses hull light or hull mid for its main mass, gunmetal or hull dark for mechanical
parts, its category accent on one or two surfaces, and one emissive element in its accent colour.
The top level of every type adds core gold trim (edges, rings, caps), so a maxed building reads as
maxed from across the base. Under the warm key light every lit colour leans warm: the ground reads
grey-mauve rather than violet.

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
| 14 | `rock` | rock grain with ink cracks | yes |
| 15 | `regolith` | fine dust, pebbles, faint craterlets | yes |

At the default UV scale a layer covers one world unit. Large surfaces take `hull` or `plate`:
`hull_dense` is for parts under a unit, and on a large one it aliases into a checker at the widest
zoom. A large, plain area can ask for a smaller `uv_scale` (the terrain uses 0.3 and 0.5).

`MaterialKit.texture()` builds the array on first use: it loads each layer as an `Image` (the PNGs'
`.import` files use the image importer, so `load()` returns an `Image` in exports), generates its
mipmaps (the Compatibility renderer makes none for a layered texture) and calls
`create_from_images`. That takes about 12 ms on the development Mac, once.

**Regenerating.** `tools/gen_textures.gd` draws every layer with its own wrapped line, disc, ring,
polygon and value-noise helpers, from one seed through `SeededRng`, so two runs write
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

`Surf.make(layer, tint, uv_scale = 1.0, flags = Surf.LIT, smooth = false, outline = true)` says
how a part is painted: a `MaterialKit.Layer`, an sRGB tint, texture repeats per world unit, the
flags (`Surf.LIT`, `Surf.UNLIT` emissive, `Surf.GLOSSY` with the cel specular), whether the part
is smooth shaded, and whether it is outlined. A `Surf` is shared and never changed once made: make
one per look, keep it in a `static var`, and pass it to every part that looks so.

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
UV2, COLOR) on `MaterialKit.toon()`, `to_outline_mesh()` the outline on `MaterialKit.ink()` (null
when nothing is outlined), and `triangle_count()` the body's triangles. Both meshes are unindexed
triangle lists. `to_arrays()` and `to_outline_arrays()` are the same as surface arrays (the
outline's empty when nothing is outlined), for a caller that merges meshes itself, as `WallMesh`
does.

- **UVs**: a face's corners in the part's own space, before `pos` and `rot`, projected along the
  dominant axis of its normal, times `uv_scale`. Round parts take U from the angle around their
  axis, a whole number of repeats around (about one per world unit at their widest radius), so
  bands wrap without a seam, and V from the distance along the profile; caps and discs are polar
  (V the radius). UV2 is (layer, flags); the vertex colour is the tint.
- **Smoothing**: a smooth part's faces that meet at under 40° share normals, averaged by position
  within the part and weighted by corner angle; caps, discs and sharper edges (chamfers, 45°;
  box corners, 90°) stay hard. A 16- to 24-sided cylinder shades as a curve; an 8-sided one
  (45° between faces) stays faceted. A flat part keeps a normal per face.

## Models

`BuildingModels.create(type, level, size)` dispatches to one static `build_<type>(p: Parts,
level: int)` in its category's file under `src/game/models/` (`core.gd`, `resources.gd`,
`army.gd`, `defense.gd`, `traps.gd`, `walls.gd`); `MODELS` gives each type the footprint its
models are built for and its level count. `Parts` holds the model while it is built: `body` and
`spin` (two `LowPolyMesh`), the spin `pivot` and `speed`, and the shared helpers. A model is a
`Node3D` with the body's `MeshInstance3D` and its outline's beside it, and at most one spinning
part: a `Node3D` at the pivot carrying `SPIN_META`, with the spin mesh and its outline under it.
That is at most four `MeshInstance3D`, two of them outlines (`OUTLINE_META`, no shadow). Meshes
are built once per type and level and cached. The contract any model keeps, built or imported:
origin at the footprint centre on the ground, +Y up, fitting inside `size × size` cells.

The `model_gallery` harness scenario lays out every type and level and checks each: one or two
body instances, each with its outline instance on the ink material casting no shadow, every layer
within the kit, and the body triangles and the extent within the budgets below. Its detail shots at the closest
zoom are where a model is judged.

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

### Model table

One line per type, in roster order: the signature element that names it from across the base,
its spinning part, and its top level's body triangles as the gallery counts them.

| Type | Signature element | Spin | Top level, body triangles |
| --- | --- | --- | --- |
| `hangar` | barrel-vaulted bays with orange ribs and hazard-striped doors, a glass-cabbed control tower | none | 4,362 |
| `fabricator` | sawtooth-roofed factory, an orange gantry crane over a loading dock, smokestacks | none | 1,950 |
| `heavy_fabricator` | armoured hall with orange press arms hammering anvils, a glowing furnace mouth | none | 2,024 |
| `research_lab` | observatory dome with a telescope, in a ring of screens | the radar dish on its mast | 2,704 |
| `nanite_foundry` | vats with bands of glowing nanite-green goo, piped with ball elbows | none | 2,870 |
| `drydock` | half-built ship in a cradle under orange gantries, welders throwing sparks | none | 2,946 |
| `alliance_beacon` | braced transmitter tower with rings of light, a big dish and an emitter orb | none | 2,096 |
| `laser_turret` | domed head on the red-belted plinth, twin barrels ending in red emitters | the head | 2,722 |
| `missile_battery` | tilted box launcher of red-tipped tubes (4, 6 at L3, 9 at L4) with a hazard band | none | 2,174 |
| `plasma_mortar` | fat short barrel rising from a caged violet plasma chamber on a heavy ring | none | 2,782 |
| `shield_generator` | cyan energy orb held over an emitter dome by three coil arms | none | 2,914 |
| `flak_cannon` | barrels angled at the sky on a tall bell mount | the radar dish on its mast | 2,900 |
| `arc_tower` | tesla coil of white insulator skirts under an arc-blue sphere; twin coils at L4 | none | 2,794 |
| `cloaked_sentry` | low dark hexagonal pod with a lid gun and a dim cyan shimmer ring | none | 854 |
| `gravity_well` | dark core floating over a violet well, ringed by gyro rings | the rotor over the core | 1,978 |
| `emp_tower` | yellow core in a bar cage atop a stepped tower ringed by capacitor cans | none | 2,854 |
| `railgun` | two long rails across the screen with a cyan strip between them, capacitor banks | none | 2,088 |
| `ion_beam` | big crystal lens and focusing rings on a tripod | none | 1,964 |
| `orbital_cannon` | massive gunmetal barrel aimed at the sky with cyan coils, on a two-tier bunker | none | 4,496 |
| `proximity_mine` | spiked domed disc on a hazard rim with a red warning light | none | 542 |
| `grav_trap` | ring emitter round a dark funnel with a violet swirl | none | 580 |
| `flak_mine` | hazard-banded pod, upward barrels with glowing bores round a lens | none | 574 |
| `mega_mine` | big armoured dome on a hazard band ringed with red lights | none | 1,214 |

## Modelling vocabulary and budgets

- **Budgets**, body triangles (outlines repeat them and are not counted): 4×4 and 5×5 up to
  5,000; 3×3 up to 3,000; 2×2 up to 2,000; 1×1 traps up to 600; one wall piece up to 250. They are
  mobile ceilings, not targets: spend triangles where a silhouette or a curve needs them.
- **Extent**: in x and z a model stays within its footprint plus 0.15 units: the static body's
  bounds, and a spinning part's whole sweep around its pivot (a turning head or dish must clear
  the footprint at every angle). Height is free. The gallery checks it on every type and level.
- Every box edge gets a chamfer (0.04 to 0.08 units). Cylinders have 16 to 24 sides, domes 16
  sides and 6 to 8 rings, rings and dishes 24 segments, all smooth. Nothing is a bare 6-sided
  prism.
- Every building: a foundation pad (`CONCRETE_PAD`, a chamfered slab 0.12 high, inset 0.1 from
  the footprint, covering it so the building sits in its cell), one main mass, two to four
  secondary masses, three to six greebles (vents, pipes, lights, antennas, hatches, tanks,
  ladders), one signature element that names the type from across the base, one accent surface
  and one emissive element.
- Levels: each adds mass or height within the footprint, more armour (the plate layer), one more
  greeble and a stronger emissive; the top level adds core gold trim. Levels 1 to 5 of a type
  read as one building growing, never as five buildings.
- Spinning parts (radar dishes, turbines, gyros): one per building at most.
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

## View states

A view never makes a material: a state overrides an instance's surface 0 with a shared one from
`MaterialKit` through `set_surface_override_material`, and clears it with `null` when the state
ends (`BuildingView`).

| State | What changes |
| --- | --- |
| Selected (`set_footprint(SELECTED)`) or lifted (`set_lifted(true)`, while dragged) | the outline instances take `ink_selected` (core gold); the footprint tile shows as before |
| Placement ghost (`set_ghost(valid)`, from `PlacementController` as its spot is checked) | the body instances take `ghost_valid` or `ghost_invalid`: the toon shader with energy cyan or defence red mixed in at 0.65; the outline stays plain ink, though the ghost is lifted |
| Under construction | the scaffold, a model like any other, outlined |

A wall drawn by the merged wall mesh hides its own model, outlines included (`set_merged`), so a
selected merged wall shows its footprint tile and no gold, and the merged outline stays plain ink.
A dragged wall leaves the mesh and shows its own post, lifted with gold outlines like any dragged
building; the paint brush is a ghost and keeps plain ink.

## Ground and scenery

- **The ground** (`ground.gdshader`): the regolith layer in the ground tint, sampled twice at
  different scales and angles (a repeat per 4 cells and about one per 7, turned 37°) so no cell
  repeats its neighbour, a slight tone per cell, and the cell grid in holographic cyan, not ink
  (`line_strength` 0.1 by default, 0.45 while placing), all under the same `light()`. `BaseView` sets `kit` and `layer` from
  `MaterialKit`.
- **The terrain** ring: flat, not outlined, casting no shadow. Its lower bands are dust (the
  regolith layer at 0.3, a craterlet about every two cells, in the ground tints); only the two
  highest bands and the crater floors take the rock layer (at 0.5, in the rock and crater tints),
  so its ink cracks show only where it is steep.
- **The rocks**: one merged mesh on the rock layer, sides in `ROCK` and tops in `ROCK_LIT`,
  outlined.

## Cost

A building's body instances draw for the light and into the shadow map; its outline instances
draw once and never cast. Measured with `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME`: a fresh
base is 57 draw calls, as it was before the kit; the model gallery's overview is 375 draw calls on
page 1 and 171 on page 2 (294 and 157 before the kit; the research lab's spinning dish adds 15 on
page 1), and the render thread's CPU time is about 0.5 ms a frame either way. Keep `_process` free
of allocation, and keep every building to its four instances. The finished walls are one merged
mesh, a fixed handful of draws however many there are (`input-camera.md`, **Walls**).
