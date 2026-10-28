# HUD

`src/game/hud.gd`: the on-screen UI, a `CanvasLayer` built in code. It reads `BaseState` for
display and reports presses as signals; it never changes game state. `main.gd` wires the
signals to `PlacementController` (`input-camera.md`). Two controls of its own draw in code:
`HudIcon` (`hud_icon.gd`), the vector icons and the unit glyphs, and `DroneRing`
(`drone_ring.gd`), the drones.
`ModelPreview` (`model_preview.gd`), a node under it, renders the cards' pictures, the buildings'
and the units'. The battle's attack HUD, `BattleHud` (`battle_hud.gd`), is a `CanvasLayer` of its
own in the same theme (**Battle HUD**).
`SectorMap` (`sector_map.gd`), the expeditions' screen, is a full panel the HUD hosts
(**Sector map**).

## The touch rule

`WorldInput` uses `_unhandled_input`, so any `Control` that is not `MOUSE_FILTER_IGNORE`
swallows every touch over it and the world underneath stops responding. Layout-only containers
that span empty screen space — the root, the top bar's column and its rows, the place bar's
row, the build panel's rows, the army panel's rows and pages — are set to `MOUSE_FILTER_IGNORE`. Panels and buttons keep the
default and block, which is what they should do. A new container must be IGNORE unless it is
meant to block. The meters and the drone meter block too, like the panels: an opaque part of the
HUD never lets a tap through to select or drag what lies under it. Each meter's root and the
drone meter are `MOUSE_FILTER_STOP`, and a meter's own parts (trough, fill, amount, coin) are IGNORE,
so the root is what a touch lands on; the strip they sit on stops a touch between them. The toast is IGNORE, so it never blocks the world while it
shows. The Expedition button's badge is IGNORE, so a touch on it presses the button. The sector map
is `STOP` over the whole safe area and its layout containers IGNORE (**Sector map**).

The build cards are the one exception: they are `MOUSE_FILTER_PASS`, so a drag that starts on
a card also reaches the `ScrollContainer` and scrolls the strip (with the default `STOP` it
does not). The build panel's `PanelContainer` behind them is `STOP`, so a touch anywhere on the
open panel never reaches the world. Each card's content (its drawn parts, its picture, its chips
and a `VBoxContainer` of labels) is IGNORE, so the button itself is what a touch lands on. The army
panel's unit cards and queue entries are the same: `PASS` buttons whose content is IGNORE, on a
`STOP` panel.

## Theme

One `Theme`, built in `_make_theme`, styles every part: its fonts, sizes, colours and
`StyleBoxFlat`s, in the skin `Hud.skin` names (**Skins**). Controls take their style from it by
type variation (`theme_type_variation`: `BuildButton`, `TabButton`, `MeterText` and so on), not by
overrides of their own; only a cost amount takes its resource's colour as an override, since that
colour is data, and a full meter its digits' gold. The buttons take no focus. The build and army
cards take `CardButton`, a button's shape in skin A, so a skin can give them one of their own.

**Fonts** (`assets/fonts/`, Google Fonts under the SIL Open Font License, each with its
`OFL.txt`, imported with Godot's default dynamic font settings): **Bangers** for the Build
and Expedition buttons, the category tabs, the panel's close button, the info panel's title and
the place bar's buttons; **Lilita One**, the theme's default, for every other text, the debug
row's included.

**Type scale** (720p): nothing smaller than 17 px but the debug row's (**Layout**); body lines 19
to 20 (`CardCost` 20, `CardCount` and `CardReason` 19, `MeterText` 20, `InfoDetail`, `InfoNote`,
`QueueName`, `HousingText`, `ToastText` and `BadgeText` 19; the sector map's `SectorRow` 20 and
`SectorRibbon`, Bangers 20 in ink); the build cards' small lines 17 (`CardTime`, `CardWarning`,
`CardChip`, `LockText`); names 22 (`CardName`, and the sector detail's loot, `SectorLoot`); titles 30
(`InfoTitle`); button labels 24 to 30 (the tabs, `BarButton`, `ConfirmButton`, `CommitButton` and
`UpgradeButton` 24, `CloseButton` 28, `BuildButton` and `ExpeditionButton` 30). The HUD is 720 px
tall under the `canvas_items` stretch, so on a 6.1-inch phone a pixel is about 0.09 mm: 17 px is a
1.5 mm em, 22 a 2 mm one, and a 56 px button 5 mm.

Lilita One has no `∞`, which the meters show under the dev cheats, so the meters' amounts take a
`FontVariation` of it (`_meter_font`) whose fallback is the engine's own font, `ThemeDB.fallback_font`: the sign draws the same on every platform rather
than from whatever font the system has. Only the meters fall back. The shared Lilita One
resource has no fallback, since a fallback's taller line metrics would space every other text,
the building view's timer label included, wider.

**Palette** (constants on `Hud`):

| Role | Value | Where |
| --- | --- | --- |
| Ink `INK` | `1B1A2E` | every outline, text outlines; `SHADOW` is the ink at 60 %, every flat shadow |
| Panel `PANEL` | `262348` at 96 % | the build panel, the info panel, the place bar, the toast |
| Card `CARD` | `3B3670` | cards, unselected tabs, the close button, Cancel, Close |
| Card disabled `CARD_DISABLED` | `2E2B55` | a card or button that cannot be pressed now, a busy drone, a card's count chip, the debug row's chips |
| Text `TEXT` | `F4F2FF` | names, amounts |
| Text dim `TEXT_DIM` | `9A95C4` | counts, reasons, the scroll bar's grabber |
| Accent `ACCENT` | `58E8FF` | the selected and the safe: the selected tab, Done, Train, Make and Research, Scan, Keep fighting, free drones, the unit glyphs' visors, canopies and eyes |
| Build gold `GOLD` | `FFC13B` | commit and spend: the Build button, Place, the upgrade button, Attack, the battle's Return, a full meter's line and digits, the cleared stamp, storages on the minimap, won stars and a victory's banner |
| Trough `TROUGH` | `17162A` | the meters' troughs |
| Warning `WARNING` | `FFB37A` | the info panel's note, a research card's lab level the lab lacks, a build card's reason and its Command Center chip |
| Resource colours | `rules.json`, `Catalog.resource_color` | costs, the meters' fills and icons |
| Category stripes `CATEGORY_STRIPE` | `MaterialKit` roles: resources `ENERGY`, army `ARMY`, defense `DEFENCE`, traps `HAZARD` | the stripe along a card's top and its plinth; a category not listed takes `ACCENT` |
| Army accent | `MaterialKit.ARMY`, `FF7F11` | raid and battle: the Expedition button; the training header's housing bar and figure, the unit glyphs, the stripe along a unit card's top |

**Colour roles.** Gold commits a spend (Build, Place, Upgrade, Attack), the army's orange starts
a raid (Expedition), cyan is the selected or the safe choice only (the selected tab, Done, Keep
fighting); each of the three carries ink text. The battle's End, a defeat's banner and a refused
deploy's toast edge take the defence red (`MaterialKit.DEFENCE`), End with ink text, so it reads as
stop. Place takes `CommitButton` and swaps to the cyan
`ConfirmButton` while walls are painted, when it reads Done.

**Shapes.** A `StyleBoxFlat` with a flat fill, a 3 px ink border (`BORDER`), round corners
(12; tabs and the toast 10, the meters a pill) and a flat shadow, the ink at 60 % offset 4 px down
and right (`_shape`). A pressed button or card is 15 % lighter (`PRESSED_LIGHTEN`) and sinks 4 px
(`PRESSED_SINK`) down and right onto its shadow, its text with it; a card's content, which is not
the button's text, sinks with it (`_sink`, on the button's draw). Hover is a shade lighter;
disabled takes the disabled fill with its text at 55 %. The panels have a cel edge, drawn over
their shape as one triangle array (`_draw_edge`): a 1 px light line just inside the ink border
(`EDGE_LIGHT`, the text colour at 12 %), and on the bottom panels (the build panel and the army
panel) a band a shade lighter across their top, down to the gap under the tabs (`MENU_BAND`, 74 px
at 720p). The build cards draw the same line themselves.

**The outline rule.** White text takes an ink outline only over a bright fill or over the world:
the meters' digits (2.5 px), the badge's count (2 px), the debug row's "DEV" (2 px). Text on a dark
panel or card (the tabs, the close button, card names, costs, titles) takes none, and ink text on a
bright fill (Build, Expedition, Place, the upgrade button, the selected tab) needs none. A label's
`outline_size` is four times the outline's width in pixels (`OUTLINE_PER_PX`), since the font's
stroke reaches a quarter of `outline_size` out from each glyph.

**Touch sizes.** The tabs are 160×56, the close buttons 56×56, Build 136×72 and Expedition 184×72,
the info panel's Train, Make or Research 112×56 and its Close 96×56 (`ACTION_SIZE`,
`INFO_CLOSE_SIZE`), the place bar's Cancel and Place 170×72; the build cards 200×200; the sector
map's Scan 190×56, its cards 360×200 at least, Back 140×72 and Attack 240×72. In battle (**Battle HUD**): speed
96×64 and End 140×64, Keep fighting 200×72 and End battle 180×72, Return 240×72, the deploy and
ability cards 124×136.

## Skins

The UI pass's three directions for the menu family (the top bar, the build panel and its cards,
the tabs and buttons, the army panel's frame), for the owner to pick from (`Hud.Look`; the
engine's own `Skin` class takes that name). `Hud.skin`, static, names the one `_make_theme` builds
and the parts that draw themselves read: set it before `setup`, or call `set_skin(look)` on a HUD
already built, which builds the theme again, hands it to the root and the two bottom panels, and
redraws what the cards, the panels and the meters draw themselves. The `hud_directions` scenario
shoots each (`tools/harness/README.md`). The battle's HUD is the dark family over the field under
every skin: its variations are its own, built after the skin's in a Battle HUD block at the end of
`_make_theme` (**Battle HUD**), so no skin reaches them.

- **A, the comic console** (the default): everything above.
- **B, the halftone console**: the bottom panels, the cards and the buttons drawn from 9-slice
  `StyleBoxTexture`s that `tools/gen_textures.gd` draws into `assets/textures/kit/hud_*.png`
  (panel, card, card-disabled, button, button-bright): two bands meeting in a hard edge at 40 %
  of the height, the lower one with a dot screen at an 8 px pitch darkening it by 10 %, a 3 px ink
  border, a 1 px light line and the flat shadow outside the shape (`SLICE_SHADOW`). Each 9-slice's
  middle is tile-fitted on both axes (`TILE_FIT`: a whole number of tiles scaled to fit), so where
  a control's middle is not a whole number of tiles the dots are scaled a little. The dark shapes are drawn in their
  own fills; the bright buttons share one near-white texture with its top right corner cut,
  tinted to their role (`modulate_color`); anything disabled takes the flat card-disabled shape.
  Pressed, a shape is 15 % lighter and squashes 4 % about its centre (`SQUASH`, `_squash`)
  instead of sinking; a toggle (a tab) never squashes. The panels' and cards' light line and band
  are the textures'. The info panel, the place bar, the toast and the sector map keep A's shapes, but for the sector
  map's cards, which take B's card as `CardButton`.
- **C, the pulp page**: the menu family in the buildings' cream (`CREAM`, `MaterialKit.HULL_LIGHT`)
  with ink text and no outlines, a 4 px ink border, a disabled shape a darker cream, dim text and
  warnings in inks that read on cream; the bright buttons in their roles' colours with ink. The
  bottom panels are a cream tray the panel draws itself (`_draw_tray`, one triangle array): its
  top edge stepped every 168 px and torn every 42, inked. A build card is a trading card: its
  category's colour across its top third under an ink dot screen and an ink line, the picture
  standing on it with no plinth, the name on an ink ribbon (`CardName`'s `normal` style), the
  costs in ink (`_cost_color`, which a card's amounts take when built and on `set_skin`). The
  meters, the drone meter among them, are cream troughs with saturated fills and ink digits on an ink strip; a full meter keeps
  its gold line, its digits ink. The info panel and the sector map go cream
  too, as they share the titles' and the lines' variations; the toast stays dark.

## Layout

`setup(catalog)` builds the build panel, then, under a root `Control` carrying the theme and
laid out on the safe area (**Safe area**), every other part. The root comes after the panel,
so its parts — the Build button above all — draw over the panel.

| Part | Where | Contents |
| --- | --- | --- |
| Top bar | top, `MARGIN` (16) in, a column across the width | First row, from the left: a meter per resource in catalog order, then the drone meter (**Top bar**). The army's housing is not here: it shows in the training facilities' UI (**Info panel**, **Army panel**). |
| Build button | bottom right, `MARGIN` from the safe area's corner, 136×72 | "BUILD" in ink on gold; toggles the build panel (**Build panel**). Hidden while placing or painting. |
| Expedition button | bottom left, `MARGIN` from the safe area's corner, 184×72 | "EXPEDITION" in Bangers 30 on the army's orange, ink text, with a badge centred on its top right corner: the open fields' count in `BadgeText` (Lilita One 19, 2 px of ink) on a defence-red circle (`Badge`, 36×36) with a 2 px light ring inside its ink (`BadgeRing`), hidden at none. Emits `expedition_pressed`. Shown with Build, and hidden while the build panel or the army panel is open across its corner (`_show_expedition`). |
| Build panel | bottom, the screen's full width | Slides up over the bottom of the screen (**Build panel**). |
| Place bar | bottom centre | A panel holding `Cancel` and `Place` (170×72); `Place`, gold, is disabled unless the ghost is valid. While walls are painted it reads `Done`, cyan, and is always enabled: there is nothing to confirm. |
| Info panel | bottom centre, 460 wide | Title `"Name   Lv N"` with Train, Make or Research (a finished producer, Foundry or research building only) and a `Close` button; detail lines (**Info panel**); the upgrade button; a note under it. |
| Army panel | bottom, the screen's full width | Slides up in the build panel's place: a producer's training or the lab's research (**Army panel**). |
| Toast | top centre, 96 down | A small panel with a centred line that fades out after 1.8 s over 0.6 s, then hides. |
| Debug row | debug builds only (`OS.is_debug_build()`): under the top bar's strip, at the left | A "DEV" label (Lilita One 14, dim, outlined over the world) over three grey chips, 132×40 (`DEBUG_SIZE`; `CARD_DISABLED`, a 2 px ink border, dim Lilita One 16), 10 apart: Practice raid, which emits `practice_pressed`, Template base, which emits `template_pressed`, then Reset base, which emits `reset_pressed`. Demoted so a tester never takes them for the game's; the only text under 17 px. |

The army panel is built after the build panel and before the root, outside it like the build
panel, so the Build button draws over it too. `add_screen(control)` adds a full screen (the sector
map) under the root, so it sits on the safe area and takes the theme, and moves the toast after
it, so a toast shows over it. The place bar and the info panel are anchored to the bottom edge and grow upward
(`_anchor_bottom`).

The game is landscape only (`window/handheld/orientation`). Under the `aspect` expand stretch the
visible rect is never narrower than 1,280 px: a screen squarer than 16:9 grows taller (a 4:3 tablet
is 1280×960), one wider grows wider. Only the safe area takes width away; the sector map's grid
drops to two columns, scrolling, when that leaves it under about 1,180 px (**Sector map**).
Portrait fits none of the bottom panels, the top bar or the sector map.

## Top bar

**Meters.** One per resource, 240×44 (`METER_SIZE`), hidden while the resource's capacity
(`state.capacities()`, **Refresh**) is 0, so antimatter appears once something stores it. The
meters and the drone meter sit on one strip (`MeterStrip`: the panel's fill at 60 %, radius 24, 8 px
of padding), so the top bar reads as one instrument; the drone meter keeps the strip's right end. A
meter's trough (`TROUGH`, a pill: its radius half its height, its shadow) starts 24 px in from the
meter's left, under the resource's icon on its coin (a `HudIcon` 48 across wearing a coin in the
trough's colour, **Coins**), whose centre sits on the trough's left edge, so the coin overlaps
the pill's end by half. Inside its border a fill grows from the left to `amount / capacity` of
the track (full at the cap), resized only on `refresh`. The fill is a `Control` with
`clip_contents` holding a `TextureRect` that tiles a 16×16 stripe image across the whole track —
a 45-degree white band over a grey 12 % darker, built once in `setup` (`_make_stripe`) and tinted
by the fill's colour over that grey, so the base reads as the colour itself and the band 12 %
lighter. The fill's colour is the resource's at 85 % of its value (`METER_VALUE`), so it stays a
colour under the white digits. The shader cuts the stripes to the pill's round ends and lays a
gloss (white at 10 %) across the track's top third. The trough's ink border is drawn again over
the fill. The amount, `"750 / 1,000"` (`Format.short`: in full below a million, then `"1.2M"`,
`"4M"`, `"12.5M"` and from a thousand million `"1.2B"`, one decimal cut and its `.0` dropped; the
cards and the info panel keep full numbers), set only when the amount or the capacity changed,
sits right-aligned 12 px in from the trough's end (`METER_TEXT_RIGHT`), clear of the coin, in
Lilita One 20 px white with a 2.5 px ink outline. **Full:** when the amount reaches the cap, a 2 px
gold line runs inside the pill (the shader's `full`) and the digits turn gold, set only when that
changes (`_set_full`). With the dev cheats on (`Hud.cheats`, set by `main.gd`) every meter shows,
full, reading `∞` (Lilita One has no `∞`; the meters' fallback, the engine's font, draws it,
**Theme**), with no full state.

**The meters move.** The stripes are drawn through `meter.gdshader`, one `ShaderMaterial` per
meter (its tint, its phase, the track's size, the fill's width, the full state), all on the one
animation clock, `anim_time` (`art-style.md`, **Animation**, "One clock"), so nothing animates them
per frame in GDScript. The stripes drift along the bar, one tile (16 px) every 4 s. Once every 8 s
a glint sweeps across the filled part from left to right in 0.6 s: a hard-edged band 26 px wide,
leaning right at the top, in the near-white text colour at 35 % with a 6 px core at 50 %, each
with a 1 px soft edge (the owner likes the motion; it is kept at half its old strength and less
often, for a value that changes once an hour). Each meter's glint comes a third of the period
after the one before it (`GLINT_STAGGER`), so they never flash together. When a refresh finds a
meter's amount dropped (a purchase), or
risen (a payout, an offline catch-up, loot) by more than 1.5 times what the resource produces in
the seconds the state advanced since the last refresh, counted as at least one and at most five
(`FLASH_RISE_TICKS`, `FLASH_MAX_SECONDS`) and rounded up to a whole unit, since a slow trickle
still rises a whole unit at a time, its whole fill flashes once, brightening 45 % towards white
and fading back over 0.25 s (`flash_time`, set to `Motion.clock()`). The per-tick trickle, a
stalled tick's included, never flashes; a longer gap's catch-up does. The first refresh only records the
amounts, and under the cheats, whose meters read `∞`, nothing flashes. The glint and the flash
are in the stripes, so the fill's clip keeps them off the border, the shadow and the coin. The
drift's and the glint's periods both divide the clock's hour. The shader adds no draw call
(`art-style.md`, **Cost**).

**Icons.** `HudIcon` draws its silhouette in `_draw`, vector, from no asset file, and only when it
is built or resized. Each part is a flat fill in the icon's colour with a lighter highlight facet
and a 2.5 px ink outline, over a 2 px ink offset shadow under the whole icon, laid out in a
40-unit box scaled to its rect: **metal** an ingot (a trapezoid bar with a lighter top face and a
darker end), always in steel `7FA6CC` (`HudIcon.STEEL`) whatever the icon's colour, deeper than
the metal's text colour so it does not match the crystal in value; **crystal** a pair of shards (a
tall kite and a smaller one leaning on it, each with a lighter left face); **antimatter** an orb
with an orbit ring tilted across it, a lighter band over the orb's upper half and a white
highlight, so it is no dark blob when small; **drones** the
construction drone (`art-style.md`, **Construction drone**) from the front and a little above:
a domed hull in the icon's colour with a light rim inside its ink round the dome, a slightly
darker belly, a highlight lobe at its top left and an ink visor band round its middle holding a
white eye; a rotor arm from each upper flank, over the hull, out to a light rotor disc seen at an
angle; and the tool's nozzle under the belly, a light lens at its end; few, big
shapes, so it reads on its 48 px coin. Any other
resource gets a plain cut gem. **army**, in front of the training header's housing line (**Army
panel**), is a figure: a head over a pair of rounded shoulders, each with a lighter facet.
`HudIcon.paint(pen, kind, rect, color, wing, coin)` adds one to a `HudIcon.Pen`.

**Marks.** Small glyphs for the surfaces that need them, drawn the same way: **lock** a padlock, a
lighter thick shackle over a chunky body with a lighter left face and an ink keyhole; **clock** a
disc with a lighter band across its top, four ink ticks, a long ink hand up, a short one to the
right and an ink hub; **chevron** a right-pointing chevron, two thick arms meeting 12 units ahead
of their notch, the upper arm lighter; **star** a five-point star with a lighter facet down one
side of each point, filled in its colour (gold for a star won, `MaterialKit.HULL_DARK` for one not
yet); **skull** a comic skull, a round cranium over a narrower jaw with ink eye sockets, nose and
teeth, for difficulty marks.

**Coins.** Any icon can wear a coin, the badge the icon families share (`HudIcon.coin`, or
`paint`'s `coin`; transparent, the default, for none): a disc filling the rect (18.5 units of the
box's 20) in the coin's colour held to at most 55 % HSV value (`COIN_VALUE`), a lighter band
across its upper 40 % (the cel band, the fill lightened 15 %), a 3 px ink ring and the icon's
2 px ink offset shadow, with the silhouette inset on it to 70 % of the rect (`COIN_INSET`).
The coin is part of the icon's one triangle array. A coin keeps its own backing on any fill, so a
selected card's cyan does not swallow the emblem on it. The unit glyphs wear the army orange's
coin, the abilities their effect's.

**Unit glyphs.** The queue entries show a unit by its crew (`catalog.unit_crew`), drawn the same
way in the army accent on an army coin (the army panel's cards show the unit's picture instead, **Pictures**): **human** a space helmet from the front, a dome over two cheek guards
with a cyan visor across it; **piloted** a cyan cockpit canopy on a hull over a track with three
wheels; **autonomous** a block head with an ink sensor slit and a cyan eye, an antenna with a cyan
bulb on top, over a darker shoulder bar. An air unit (`unit_class` `air`, `HudIcon.winged`) adds a
wing mark at the box's lower right, a swept white wing with its ink outline. `show_icon(kind,
winged)` swaps a glyph in place, redrawing only when either changed, as a queue entry does when
the queue moves.

**Ability glyphs.** An ability has no model, so the making and research cards, the making queue's
entries and the battle's abilities bar and result panel show its emblem by its effect
(`catalog.ability_effect`), in its effect's colour on a coin of that colour (`Hud.ABILITY_COLORS`,
set by `Hud.show_ability_glyph`), each drawn with mass rather than lines: **swarm** three fat nanites of
three sizes overlapping, each with a darker lower band and a white highlight, the largest in front
with a white "+" on it, in nanite green; **emp** three thick concentric arcs opening upward, each
with a lighter inner edge, and a slim white zigzag bolt down through them, its jog below the
innermost arc so all three show either side of it, in arc blue; **strike** a thick white crosshair
(a ring in four arcs between four bars) round a dot of defence red, broken by a hazard-yellow bolt
falling into it from the upper right, its corner kept inside a coin's ring.

**One draw call each.** The renderer draws every `draw_colored_polygon` and `draw_polyline` on
its own, so an icon drawn with them would cost a draw call per part. `HudIcon.Pen` builds a whole
icon, or the drone meter's slots, as one triangle array instead
(`RenderingServer.canvas_item_add_triangle_array`, per-vertex colours): fills triangulated with
`Geometry2D.triangulate_polygon`, strokes as quads with mitred corners (capped at three times
their width), and in place of the renderer's antialiasing a 1 px feather that fades to nothing
along every stroke and shadow. Fills are left hard, since their outlines cover their edges.
`Pen.triangle_count()` says how many triangles have been added, for the harness (`icon_sheet`).

**Drone meter.** `DroneRing`, 200×44, at the strip's right end, shows how many of the base's drones
(`state.builders_total()`, kept with the capacities, **Refresh**) are free
(`state.builders_free()`). It is a resource meter's twin, built from the same parts, so a skin
styles it as it styles the meters: the pill-shaped trough (`MeterTrough`), the drone icon in the
accent cyan on its coin in the trough's colour over the left end, the trough's ink border again
over what is inside it (`MeterFrame`), and "free / all" right-aligned 12 px in from the end in
`MeterText`. Inside the border, from the coin's edge to 52 px short of the text's end, a slot per
drone split by 3 px ink lines, with one at either end, the first on the coin's ink ring and the pill's round end inked up to it behind the coin: free slots
in the accent as a meter's fill takes a colour (`Hud.meter_fill`: 85 % of its value, or under skin
C saturated), with the meters' gloss (white at 10 %) over their top third; busy slots the trough's
own fill crossed by the meters' 45-degree stripes (16 px apart, 6 wide, static), 14 % lighter on a
dark trough or darker on a light one (skin C's cream): at work. Like a resource meter it costs six
draws: the trough, the slots, the frame, the text and its outline, and the coin; only the slots are
one triangle array (**One draw call each**). The slots read the theme's `MeterTrough` when drawn
(skin A's trough colour and border if a skin's is not a flat shape) and are redrawn only when
`refresh` changes a count (`set_counts`) or the theme changes (`set_skin`), never per frame. The
"All drones are busy" toast and the cards' "No free drone" also name the drones.

## Refresh

`refresh(state, selected_id, placing, ghost_ok, painting)` is called by `main.gd` once in a
frame after the tick or any state change (`main._process`, `input-camera.md`), and on every
selection change; `painting` is `PlacementController.is_painting()`, which turns `Place` into
`Done`. It updates the meters, the drone meter and the Expedition button's badge (the field count
less the sector's cleared fields), each text set only when what it shows changed, then:

- **placing** (painting included) → the build panel closes, Build hides and the place bar shows;
- **a building selected** (`selected_id` in `state.buildings`) → the build panel closes and the
  info panel shows, unless the army panel is open on that building;
- **otherwise** → neither bar nor panel shows; Build does.

The army panel belongs to the building it opened on: placing, a deselection or the selection of
another building closes it. The cards are refreshed only while the build panel is open (and when
it opens), and only the selected tab's, the buildings counted by type once for every card's
"built / max". The army panel's content is rebuilt after `BaseState.changed`, which the HUD
connects to itself from the state `refresh` is given (`_watch`): a change marks it stale, and the
next `refresh` (`main.gd`'s, at the end of that frame) rebuilds it once however many changes came;
and when it opens: the housing line, the cards, the queue (copied once by `queue_of` and kept
until the next change; its entries set again only when the copy differs from the queue shown) and
the research line's words. A `refresh` while it is open with nothing changed, the one-second
tick's, only counts down (`_tick_army`): it reads the head's `training_status` and
`training_seconds_left`, or `research_seconds_left`, none of which copies anything, and sets the
head's or the research line's text only when the value it shows changed. So a tick with no state
change copies nothing from the state and builds one short string, the new time left, while a
countdown runs; a tick that changes the state (production paid, a unit trained) emits `changed`
and rebuilds.

What the buildings add up to, the capacities (`state.capacities()`), the builders' total and the
busy ones, is read once and kept with the `BaseState` and its `buildings_revision`
(`core-economy.md`) it was read at, until either moves; the production rates
(`state.production_rates()`), which the meters' flash weighs a rise against, are read once per
revision and only when a meter rises. So a refresh with no building changed reads none of them
again. The info panel rebuilds its text only when the building, its level, its target, its
seconds left, the state, its revision, the army's housing or the stock changed; its upgrade
button's check (`state.check_upgrade`), which the resources move, runs on every refresh.

`refresh_placing(state, selected_id, placing, ghost_ok, painting)` takes `placing_changed`,
which fires when placement begins or ends and on every move of the ghost
(`main._on_placing_changed`). While the place bar is already shown it only enables or disables
`Place`; when placement begins or ends it does the full `refresh`, which swaps the bottom part.
A ghost drag therefore never recomputes the top bar or re-runs `check_can_build` for the menu;
they catch up on the next state change or tick.

## Build panel

**Opening and closing.** Closed at start. The Build button toggles it; opening it over a
selected building's info panel, or over the army panel, first emits `close_pressed`, as the info
panel's Close would, so the two never show together. The close button closes it, and so do picking a card, starting
placement or painting, and selecting a building in the world (`refresh`). `is_menu_open()` is
true from the press that opens it until the one that closes it. It slides by a `Tween` on its
position: up from below the screen's bottom edge over 0.18 s (`MENU_OPEN_SECONDS`, cubic ease
out), down over 0.14 s (`MENU_CLOSE_SECONDS`, cubic ease in), after which it is hidden so it
blocks nothing; a new slide kills the one under way. A resize, or a new safe area, while it
slides open stops the slide and sets it open on the new bottom edge (`apply_safe_area`). Once up, a panel rests on its anchors, so it stays on
the bottom edge if its content's height changes; the slide aims at its minimum size, which has
caught up with its content before its size has (`_slide`, which the army panel shares).

**Shape.** A `PanelContainer` under the `CanvasLayer` itself, outside the root: it spans the
screen's whole width and reaches its bottom edge, and a `MarginContainer` pads its content into
the safe area (`apply_safe_area`). It is 324 px high at 720p (`MENU_HEIGHT`), never more than
45 % of the screen's height (`MENU_MAX_SHARE`, so 324 at 720p), and grows upward if its content
needs more. Panel fill, a 3 px ink border along its top edge only, its top corners rounded 16,
no shadow, and the cel edge (**Shapes**): the light line and the lighter band behind the tabs.

**Tabs.** The top row: one toggle button (160×56, Bangers 24) per `catalog.categories` id, in
that order, labelled with `catalog.category_name`, in one `ButtonGroup`; then, at the right, the
close button (56×56, "X" in Bangers 28). An unselected tab is a card with white text and no
outline (`TabButton`); the selected one is cyan with ink text (`TabSelected`). The first is selected when the HUD is built; the selection is remembered while
the game runs (not saved). Selecting a tab shows the cards of the `catalog.menu_order` types
whose `catalog.category_of(type)` is that tab, in `menu_order` order, scrolls the strip back to
its start, and refreshes those cards from the last state `refresh` was given. Pressing the tab
that is already selected scrolls its strip back to the start, a tween of `scroll_horizontal` over
0.2 s (`STRIP_RETURN_SECONDS`, cubic ease out), which selecting another tab stops; the tab stays
selected.

**Cards.** Under the tabs, a horizontal `ScrollContainer` of cards, scrolled by a drag, with a
thin scroll bar under it; to its right a column as wide as the Build button stays clear, since
Build stays over the open panel at the safe area's corner. Every menu type gets a 200×200 card
(`CARD_SIZE`) when the HUD is built; a tab only shows or hides them. A card is a card-filled
button (`CardButton`) with the ink border and shadow, and on it:

- its category's stripe (6 px, `CATEGORY_STRIPE`) along its top inside the border;
- the building's picture (112×112, `PREVIEW_SIZE`; **Pictures**) on a round plinth, a disc 120
  across (`PLINTH`) of the category's colour at 22 % over the card with a 2 px ink ring;
- its count on a chip at the top right, `"0/2"` (`CardChip`, 17 px, on a `CARD_DISABLED` pill
  with a 2 px ink ring): the buildings of its type, counted once for every card by
  `_refresh_entries`, over `catalog.max_count(type, state.cc_level())`;
- three centred lines under the plinth: the display name (Lilita One 22, white, no outline); the
  level 1 cost, each amount (20 px) in its resource's colour (`resource_color`, the text colour
  when there is none) after its resource's icon on a coin of that colour (22 px, the coin
  darkened to `HudIcon`'s value cap, so the colour says which resource it is), or
  "Free"; and the build time, level 1's `build_seconds` through `Format.duration` (the dev
  cheats' times show as they do everywhere else) after the `clock` mark (`CardTime`, 17 px, dim),
  or in its place, while the card cannot be built, the reason in the warning colour
  (`CardWarning`, 17 px).

Everything the card draws itself (the light edge, the stripe, the plinth, the chip's pill, the
coins with their icons, the clock) is one triangle array under the picture (`Hud.CardArt`,
through `HudIcon.Pen`), redrawn only when the card's rows are laid out or its state changes, so a
card costs the draw calls it did with its plain stripe. When `state.check_can_build(type)` fails
the card is disabled (the disabled fill) and its last line gives the reason:

| `check_can_build` | Last line |
| --- | --- |
| `needs_command_center_level` | (none: the card is locked, below) |
| `limit_reached` | Max built |
| `no_free_builder` | No free drone |
| `insufficient_resources` | Not enough <name of the first resource, in catalog order, the base is short of> |
| anything else | `error_text(code)` |

**Locked.** A type the Command Center has not unlocked (`max_count` 0 at the current level) is
still listed, its picture at full alpha but greyed half way towards a violet grey
(`locked.gdshader`, one material shared by every locked card), a warning chip over the plinth's
foot with the `lock` mark and the Command Center level it needs, "CC 4" (`LockChip`, `LockText`
17 px in ink), its name at 70 % and no count; its last line keeps the build time. Nothing on a
card fades to 55 %. `entry_status(type)` keeps the card's state in words: `"built / max"`, or
"Needs Command Center N" (N is level 1's `requires_cc`) or the reason above.

Pressing a card closes the panel and emits `build_pressed(type)`; a drag across the strip scrolls it and presses nothing. The Barrier
Wall, the Defence tab's last card, is a card like any other, and placement paints it
(`input-camera.md`).

**Pictures.** `ModelPreview` renders each type's level 1 model into a 160×160 texture once and
keeps it for the session. The model is built for its picture alone, outside `BuildingModels`'
cache, and freed after the readback, and it is built off the main thread: one `WorkerThreadPool`
task at a time (`ModelPreview.PictureJob`) builds its parts (`BuildingModels.parts_of`) and every
array of its meshes (`BuildingModels.mesh_data`, the idle moving parts folded in), which read no
cache, write none and make no resource or node; the main thread only makes the meshes from those
arrays (`meshes_from`, the kit's materials) and the nodes. The pictures come out byte for byte as a
main-thread build makes them. It owns one `SubViewport` with a world of its
own (`own_world_3d`), a transparent background and 4× MSAA: an orthographic camera at the world's
angle (`IsoCamera.PITCH_DEG`, `YAW_DEG`) framing the model's bounds with 8 % to spare on each
side, the key light from `main.gd`'s direction and colour with no shadow, and an environment with
no ambient and linear tonemapping. The models keep the world's toon materials; their outlines take
a copy of the ink material whose `ink_px` is scaled by 720 / 160, so the line is as many pixels on
the texture as it is on a 720p screen. A moving part stands where `Motion.transform_at(0)` puts
it; a part folded into the body moves on the clock (`art-style.md`, **Folded parts**), and the
picture shows it where the clock had it when drawn. It renders one model at a time, only while the panel is open or the base is idle (below):
the frame that finds a build finished puts the model in front of the camera and has the viewport
draw once (`UPDATE_ONCE`), the next reads the image back into an `ImageTexture`, caches it by
type, hands it to the card and starts the next build. A build still running when the preview
stops is staged when it runs again; leaving the tree waits for it. Opening the panel, and selecting a
tab while it is open, moves that tab's types to the front of the queue, so the visible cards fill
first. A card shows no picture, only its stripe, until its own is ready. Once every type is
cached the viewport is freed and the node stops processing, so the panel costs nothing more per
frame. A headless run draws nothing: the queue is gone through but no picture is made.

Units' pictures are keyed `ModelPreview.unit_key(unit, tier)` and rendered from
`UnitModels.build(unit, tier)` the same way, on the same worker thread (the task also works out the
extent of the unit's body in the camera's plane, which frames it), asked for with `request(keys)`,
which puts them at the queue's front and builds the viewport again if it was freed. A unit's
model, too, is built for its picture alone, outside `UnitModels`' cache, and freed after the
readback: the texture is all the picture keeps (the battle builds and caches its own meshes). The army panel asks for its shown
cards' pictures (each unit at its researched level's tier, `UnitModels.tier_of`) when it opens
and on each refresh, and the preview runs while the build panel or the army panel is open
(`_run_preview`); a card is blank until its picture comes (`rendered`). The battle's deploy bar
shares the preview (`Hud.preview()`).

The pictures are also made ahead, in the base's idle frames: `main.gd` calls `prerender(on)`
when the base turns idle (a second after boot, no drag, nothing being placed, no battle, the
sector map closed) and when it stops being, and while it is idle the preview runs, one model at a
time, every unit's picture at its researched tier first (asked for when it turns on), then the
build cards' in their order. A panel opened after that finds its pictures made; opened before,
it fills them as it always did. Opening a battle stops the prerender before the battle's HUD runs
the preview for its deploy cards, so it never stops that run. On the Mac the boot's frames stay
under 17 ms while they are made but for the preview viewport's first draw, about 40 ms once; the
base at rest then holds the pictures' textures, about 5.6 MB of video memory, whether or not a
panel opens.

## Info panel

For the selected building, the stats of its current level (level 1's while it is first being
constructed), one line each, only when the level has the stat, in this order:

| Line | From |
| --- | --- |
| Hull 600 | `hp` |
| Produces 1,800 Metal/h | `produces`, one line per resource above 0 |
| Stores 1,500 Metal | `storage`, one line per resource above 0 |
| Houses 1 drone | `builders` above 0 |
| Capacity 20 | `capacity` (army) |
| Army housed 12 / 20 | the Hangar (`catalog.housing_type`): the base's `housing_used()` / `housing_capacity()` |
| Housing 12 / 280 | a training facility (a type `catalog.units_of_producer` names: the Cadet Academy, the Drydock, the Fabricator, the Heavy Fabricator): the same, the army's housing where it is trained; with no Hangar (capacity 0) "No Hangar: build one to house units", as the training header says (`Hud.NO_HANGAR`) |
| Stock 2 / 6 | the Nanite Foundry (`catalog.foundry_type`): the base's `stock_total()` / `foundry_capacity()` |
| Damage 12   Range 7 | `damage` and `range_cells`; either alone when the level has only one |
| Fires every 0.8 s | `fire_ms` |
| Targets ground / air / air and ground | `catalog.targets_of(type)` |
| Hidden from attackers | `catalog.is_hidden(type)` |

Once built and below its top level, a value the next level changes is followed by the next
level's after an arrow: "Hull 600 → 800", "Produces 1,800 → 3,000 Metal/h"; while first being
built it shows level 1's values with no arrow. The arrow is " → " when the theme's font has the
glyph and " > " when it does not (Lilita One does not), checked once in `setup`. Resources are
named with `catalog.resource_name`. While busy, a last line reads "Under construction: 10s left" or
"Upgrading to Lv N: 1m 00s left".

The title is in Bangers 30 and the detail lines in Lilita One 19. The upgrade button, gold
like Build with its text in ink (Lilita One 24), reads "Under construction" (disabled) while
busy, "Max level" (disabled) at
the top level, else "Upgrade to Lv N   cost   (duration)", disabled with the reason in the
note when `state.check_upgrade` fails. Pressing emits `upgrade_pressed`; `Close` emits
`close_pressed`.

Beside `Close`, a finished producer (a type `catalog.units_of_producer` names, at level 1 or
more) shows **Train**, the finished Foundry (`catalog.foundry_type`) **Make** and the finished
research building (`catalog.research_type`) **Research**,
112×56, cyan with ink text in Bangers 24 (`ConfirmButton`, like Done); `Close` is 96×56. Pressing it opens the army panel on that page
in the info panel's place (**Army panel**).

## Army panel

Shaped like the build panel and in its place: a `PanelContainer` outside the root, the screen's
full width at its bottom edge, its content padded into the safe area (`apply_safe_area`), the same
slide (`_slide`, **Build panel**), and the same column kept clear on the right for the Build
button. Its height is its content's, with the build panel's (324 at 720p) as the minimum, which
the training and research pages fit in. A header, the building's `"Name   Lv N"` in Bangers 30 with the close button (56×56,
"X") at the right, over one of three pages: training, making (the training page's, its unit
cards swapped for the ability cards) or research. The panel stops every touch on it; its layout
containers take none. The close button slides it down and shows the building's info panel again,
still selected. Hidden while closed.

On the training page the header carries a second line under the title, the army's housing
(`_refresh_housing`, rebuilt with the panel after every `BaseState.changed`): the army's figure
(`HudIcon` "army", 20×20, the army accent), "Housing 12 / 280" (19 px, `HousingText`:
`housing_used()` / `housing_capacity()`, `Format.amount`) and after it a bar 120×14
(`HOUSING_BAR_SIZE`), a meter's trough and ink frame round a flat fill in the army accent with the
meters' gloss, grown across its track by used over capacity, and at least 2 px
(`HOUSING_MIN_FILL`) while any unit is housed. With no Hangar (capacity 0) the line
reads "No Hangar: build one to house units" (`NO_HANGAR`) in the dim style (`CardCount`) and the
bar hides. The
making and research pages leave the line out.

**Training panel.** A horizontal strip of unit cards (200×140), one per unit the producer's type
trains, in `units.json` order (`catalog.unit_types()`; a card per unit is built up front and the
page shows its producer's). A card has the army accent's stripe along its top, the unit's picture
(48×48, `PICTURE_SIZE`, **Pictures**: the unit at its researched level's tier), its name (Lilita One 22), a row of its train cost at
its current level (`unit_level`), each amount in its resource's colour, or "Free", and its train
time (`Format.duration`, dim), then "Housing N   Housed M" (19 px, dim: the unit's housing and
`army_count`). A unit the producer's finished level does not train yet (`unit_producer_level`) is
locked: the card is disabled, its picture, name and cost at 55 %, its last line "Needs <producer>
<level>" (19 px, dim). Tapping a card emits `train_pressed(id, unit)`; `main.gd` queues one through
`PlacementController.train` and toasts the error when it fails.

Under the cards, the **queue strip**, scrolled like the cards: an entry (180×48) per queued unit,
oldest first (`queue_of`), each a 32 px glyph beside the unit's name (19 px); the head adds its
state under the name (19 px, dim): its time left, "12s left" (`training_seconds_left`), "Waiting
for room" (`training_status` `waiting`) or "Paused" (`paused`, its producer upgrading). With no
queue the strip reads "Nothing in training". Tapping an entry emits
`cancel_training_pressed(id, unit)`; `main.gd` cancels the newest queued unit of that type
(`PlacementController.cancel_training`, which need not be the entry tapped) and toasts
"Refunded". Entries are made as the queue first grows that long and kept; after that a rebuild
only sets text and swaps glyphs, and nothing is allocated per frame (**Refresh**).

**Making panel.** The Foundry's page: a strip of ability cards (200×140), one per ability in
`catalog.ability_types()` order, laid out as a training card: the stripe, the ability's glyph
(48×48, **Ability glyphs**), its name, its make cost at its current level (`ability_level`) in its
resources' colours and its make time (`ability_make_seconds`), then "In stock N" (`stock`). An
ability the Foundry's finished level does not make yet (`ability_requires_foundry`) is locked:
disabled, at 55 %, its last line "Needs Nanite Foundry L". Tapping a card emits
`make_pressed(id, ability)`; `main.gd` queues one through `PlacementController.make` and toasts
the error when it fails. Under the cards the training page's queue strip, its entries the queued
abilities (`making_queue_of`) with their glyphs and names, the head's state from `making_status`
and `making_seconds_left` ("Waiting for room": the stock is full), "Nothing being made" when
empty; tapping an entry emits `cancel_making_pressed(id, ability)`, which cancels the newest of
that ability (`PlacementController.cancel_making`) and toasts "Refunded".

**Research panel.** Under the header a line naming the research running, "Researching Ranger to
Lv 2: 30s left" (`research_unit`, `research_seconds_left`), or "No research running"; under it a
strip of cards (200×164), one per unit the base has unlocked (`is_unit_unlocked`), in `units.json`
order: the picture, the name, "Level N" (20 px), then the next level's research cost and time, and
"Needs Lab L" (its `requires_lab`), "Researching" on the unit being researched, or, at the unit's
top level, "Max level" with no cost. A card whose lab level the lab lacks, or at the top, is shown
at 55 % with its lab level in the warning colour, but still takes a tap. Tapping a card emits
`research_pressed(unit)`; `main.gd` starts the research through `PlacementController.research`
or toasts why not, in `research_error_text` (**Messages**). There is nothing to cancel.

After the units' cards come the abilities', every ability in `catalog.ability_types()` order: the
glyph, the name, "Level N", the next level's research cost and time, and "Needs Lab L", "Needs
Nanite Foundry L" while no Foundry makes it yet (`is_ability_unlocked`), "Researching", or "Max
level"; dimmed in the same cases. Tapping one emits `research_ability_pressed(ability)`, which
`main.gd` sends through `PlacementController.research_ability`, toasting in `research_error_text`.
The progress line names an ability's research too ("Researching Repair Swarm to Lv 2: …",
`research_ability`); a unit's and an ability's share the one slot.

## Sector map

`SectorMap` (`sector_map.gd`), the expeditions' screen (`expeditions.md`, **The expedition flow**):
a `PanelContainer` built in code, added by `main.gd` through `add_screen`, so it lies on the safe
area, `MARGIN` in from its edges, styled by the theme's `ScreenPanel` (the panel's fill, opaque, as
the info panel's shape). Hidden until the Expedition button opens it. It reads `BaseState` and
`OutpostGenerator` and changes nothing: Scan, Attack and its close button are signals that
`main.gd` applies through `PlacementController` (`battle-view.md`, **Expeditions**).

| Part | Contents |
| --- | --- |
| Header | "SECTOR" (`InfoTitle`); **Scan** (`ConfirmButton`, 190×56): "SCAN" while a scan is allowed (the first always), else disabled and counting down, "SCAN  3h 00m" (`scan_seconds_left`, `Format.duration`), hidden while a field's detail shows; the close button "X" (`CloseButton`). |
| Hint | "Scan to refresh: your Command Center has grown" (`InfoNote`) while the sector's snapshot is of a lower Command Center than the base's (`state.sector.cc < state.cc_level()`). |
| Fields | A card per field of `state.sector_fields()` in a grid (`GridContainer`, 16 apart) of three columns where the area the panel is laid out in leaves at least 1,180 px across (`WIDE_PANEL`), else two (a narrow safe area), set on `open` and on a resize; the grid sits in a `ScrollContainer` (vertical, its bar hidden) for the third row two columns need, and its rows are centred where they leave room. Each card (`CardButton`, `MOUSE_FILTER_PASS` so a drag on it scrolls) fills its column's width and is 200 tall (360×200 at least): a stripe along its top in the band's colour (easy `MaterialKit.ENERGY` cyan, even `ARMY` orange, hard `DEFENCE` red, any other the accent); on the left a 160×160 **scan plate** of its outpost (the `Minimap` at a card's size, below); beside it "Rival colony · CC N" (`InfoDetail`), the outpost's Command Center level, over a row per resource with a loot target above 0, its icon on a 24 px coin of its colour (as the build cards' costs) and the amount in `CardCost`, in the text colour ("No loot" when none has one). Pressed, a card is 15 % lighter and its content sinks 4 px with it, as a build card's (`Hud._sink`). A cleared field's card is disabled (the disabled fill), its stripe and content at 75 %, and stamped at its bottom right with a gold star (60×60, tilted, a lighter facet, ink outline and shadow, drawn as `HudIcon` draws). |
| Detail | A field's card opens it (`show_field(index)`; a cleared field, or one that is not a field, opens nothing and returns false), with the field already laid out (below), or laid out then if it has not come yet. On the left the **minimap**, 480×480, in its chunky drawing (below). On the right the outpost as the title, "Rival colony · CC N" (`InfoTitle`); the loot, a row per resource with a target, its icon on a 28 px coin and the amount at 22 (`SectorLoot`); what the field holds as a two-column table at 20 (`SectorRow`): "N defences" and "N storages" over "N walls" and "N of them outside the walls", the deposits under the storages they are among, singular at one (traps stay hidden); a legend of the five colours at 19 (`CardCount`), each swatch an 18 px coin of its colour with an ink ring; and at the bottom **Back** (`BarButton`, 140×72), back to the fields, and **ATTACK** (`CommitButton`, gold, 240×72), which emits `attack_pressed(index, field)`. |

**The minimap** (`SectorMap.Minimap`) draws a field from above with `HudIcon.Pen`, one triangle array,
in one of two looks by its size. Under 6 px a cell (`BOLD_CELL`: a card's plate) it is a **scan
plate**: the field's ground (`FIELD_DARK`) in a 4 px frame of the band's colour inside a 2 px ink
edge, with a flat shadow; a stepped vignette, three discs darkening it towards the rim; a faint 6×6
ink grid (10 %); the walled compound as one polygon, the convex hull of the wall cells, in the walls'
grey (`HULL_MID`) at 40 % with a 2 px ink line; then every defence a 6 px red disc with no outline
(on a hard field they cluster into a red ring inside the compound), every storage (a deposit is one)
a 7 px gold square, and the Command Center a 16 px violet (`ANTIMATTER`) diamond in a 2 px ink ring,
drawn over both; nothing else. At the detail's size it keeps the **chunky drawing**: the field (48×48
cells and one cell of margin) as a field-dark rounded square with an ink outline and a shadow,
every building but the traps a flat fill in its role's colour inset a little from its footprint,
with an ink outline and a shadow: the Command Center violet, defences red, storages gold, other
buildings cream (`HULL_LIGHT`), walls a plain grey fill. Over either, once the band is shown
(`show_band`), the band's word in `SectorRibbon` on a ribbon of its colour across the top-left
corner, reaching 6 px out past the left edge and folded round it, notched at its right end, with a
skull (20 px, `HudIcon`'s mark in the text colour) per step of difficulty, the band's place in
the catalog's order of bands (easy one, even two, hard three); and "CC N" in `CardChip` on a pill
(`CARD_DISABLED`, skin C's darker cream, a 2 px ink ring) over the top-right corner. Its drawing is
kept (**Known cost**).

**Layouts.** The fields are laid out (`OutpostGenerator.generate_field`, up to 25 ms for a hard
field, about 100 ms for the six at Command Center 10) off the main thread: one `WorkerThreadPool`
task per field (`SectorMap.LayoutJob`), started the frame after the map opens, handed the sector's
seed, epoch, Command Center and a copy of its capacity (never the `BaseState`), and collected in
`_process` as they finish, one a frame, each card's plate drawn as its field arrives. The
generator touches only its own state, its own `SeededRng` and the `Catalog`, which nothing writes
after loading, so a layout is the same, byte for byte, as on the main thread. The fields are kept
for the sector's seed and epoch: a scan or another base (Reset, Template) lays them out again, and
a task of an older epoch is collected and dropped. The detail opened before its field arrived
waits for that field's task, or lays the field out at once when none runs. Closing the map leaves
the tasks to finish and be collected (none starts while it is closed); leaving the tree waits for
every one, so quitting with tasks in flight is safe. Once all six are in, processing stops and
nothing is laid out or drawn per frame.

**Known cost.** Every drawing the map holds is kept: a plate or the minimap keeps its `HudIcon.Pen`
and builds it again only when its field, its band, its size or the skin changes (showing the field
already shown changes nothing); the stamps and the swatches when their size does, and the loot icons
(`LootIcon`, a `HudIcon` that keeps its drawing) when their size, kind, colour, wing or coin does. Showing a control draws it again, so without this every
open rebuilt them all, the 21 loot icons alone about 8 ms. The cards and the detail are built once in
`setup`. The fields' summaries are kept for the snapshot they come from (the sector's seed, epoch,
Command Center and capacity), each card's cleared flag read from the sector; the detail's header
takes the same kept summary. On the development Mac,
rendered, the frame the map opens in costs about 6.7 ms against an idle frame's 4.7 (it was 13.4
against 5.5), `open()` itself 0.3 ms (2.7); the base is still drawn behind the panel. The open map
draws about 78 more draw calls than the base alone (630 against 552). A field's detail, shown for
another field than last time, builds its minimap's drawing: a frame of about 8 to 12 ms.

`open(state)` shows it on the fields; `refresh(state)` fills the cards and the hint (after
`BaseState.changed` while it is open, once in the frame, `main._process`: a scan, a raid), and sends a detail whose field is no longer
open (cleared, or the epoch moved on) back to the fields; `tick(state)` (the one-second tick) sets
Scan's countdown, its text only when the seconds changed; `close()` hides it and emits `closed`.

**Touch.** The panel is `MOUSE_FILTER_STOP` over the whole safe area and every layout container in
it IGNORE, but the fields' `ScrollContainer`, which takes the drags it scrolls by; the buttons keep
`STOP` and the cards are `PASS`. `main.gd` also takes the base's `WorldInput` out of
the tree while the map is open and puts it back on `closed`, so no touch reaches the base, a pinch
included.

**Queries for the harness** (on `main.sector_map`): `is_open()`, `is_detail_open()`,
`detail_index()` (-1 for none) and `detail_field()` (the field laid out); `card(index)` and
`card_cleared(index)`, whether the stamp shows; `card_lines(index)`, the band (its plate's ribbon,
`Minimap.band_text()`), the outpost and each loot shown; `scan_button()`, `close_button()`, `attack_button()`; `hint_shown()`;
`minimap()`, whose `drawn()` counts the buildings laid out for drawing (walls and traps apart; a
plate shows only the Command Center, the defences and the storages of them) and `walls_drawn()` the
walls; `card_thumbnail(index)`, a card's plate (`Minimap` too); `layouts_done()`, whether all six fields are laid out.

## Safe area

The root holds every part but the build panel and the army panel, so their anchors and margins are relative to the
safe area, the part of the screen clear of notches and the home indicator.

`apply_safe_area(inset: Rect2)` lays the root out inside `inset`, a rect in the HUD's own
coordinates (the viewport's visible rect: 1280×720 on a 16:9 screen under the `canvas_items`
stretch), by setting its offsets. It pads the build panel's content, and the army panel's, by
the same inset on the left, the right and the bottom, and sets their height for the screen's.
`fit_safe_area`
fits it to the device (the rect is `Hud.safe_area(viewport)`, static, which `BattleHud` uses too) in `setup`, on `get_viewport().size_changed`, and once a second from `main.gd`'s
tick (not on every `refresh`), since turning a phone over moves the notch to the other side
without a resize: `DisplayServer.get_display_safe_area()`, in screen pixels, is clipped to the window
(`window_get_position`, `window_get_size`), made relative to it, and scaled by the visible
rect's size over the window's. It is applied only when it differs from the last rect fitted
this way. On desktop the safe area is the screen's usable rect: while the window lies inside
it the result is the whole visible rect, and a window reaching outside it (over the menu bar,
say) is inset to the part inside. A window with no size (a headless run) gets the whole
visible rect. The harness calls `apply_safe_area` to try a notch-like inset on a desktop window;
that inset stays until the device's safe area changes.

## Battle HUD

`src/game/battle_hud.gd`, `BattleHud`: the attack HUD, a `CanvasLayer` `main.gd` adds beside a
battle (`battle-view.md`) while the base's HUD is hidden. It takes the base HUD's theme
(`Hud.ui_theme()`) and its pictures (`Hud.preview()`), reads the `BattleView` and its sim, and
reports presses to the view (`select_unit`, `select_ability`, `speed`, `surrender`, `leave`); it
never changes the sim itself. Its root takes no touch and sits in the safe area (`Hud.safe_area`, fitted on a resize
and when the timer's second changes); its panels and buttons take theirs.

| Part | Where | What |
| --- | --- | --- |
| Status panel | top left | the time left as `m:ss` (`seconds_left`, Bangers 28), the destruction as "41%" (`destruction_pct`, Bangers 28) with "destruction" dim beside it at 17, and the three stars, `HudIcon`'s `star` at 36 px: the buildings' dark hull grey (`MaterialKit.HULL_DARK`, `BattleHud.UNEARNED`) with the ink outline until won, gold once won |
| Loot | top centre, one pill in the status panel's shape | per resource its icon in its colour on a trough coin (40 px, the silhouette 28) and the amount taken so far (`loot()`, `Format.short`) at 20 px in the text colour |
| Speed and End | top right, 24 apart | speed 96×64 (`1x`/`2x`, toggling `BattleView.speed` through `SPEEDS`), End 140×64 in the defence red with ink text (`EndButton`), which opens the confirmation; both disabled once the battle ends |
| Deploy bar | along the bottom from the left margin, as wide as its cards (and scrolling when they would reach the Build button's column, which stays clear), the rest of the bottom edge left to the field | a panel (`BattleBar`, skin A's bottom panel) with a strip of cards (124×136), one per unit type brought in sorted order: the unit's picture (64×64, its attacker's level's tier), its name (17) and "xN" left (22, `left_to_deploy`). A press selects the type (`BattleCardSelected`: the cyan fill, a 3 px ink ring 5 px inside its edge framing the picture, its text in ink) or, on the selected card, lets it go; the first card starts selected. A type run out is let go and its card shown at 55 %. Cards PASS, so a drag on one scrolls the strip |
| Abilities bar | along the bottom, right of the deploy bar after a 16-unit gap, as wide as its cards; the deploy bar scrolls in what is left, the Build column still clear; hidden when no ability is brought | the same panel with a card per ability brought (above 0) in the catalog's order: its emblem on its coin (**Ability glyphs**, 64 px), its name and "xN" left (`left_to_use`) as the deploy cards'. A press selects the ability and lets the unit type go, so the red zone hides (a unit card's press does the reverse); on the selected card it lets it go. A tap on the field then casts it at the cell, anywhere on the field (`BattleView.cast`); a drag pans. An ability run out is let go and its card shown at 55 % |
| Confirmation | centred, over the ink at 55 % across the whole screen that takes every touch while it is open, so no tap or drag beside the panel reaches the field | "End the battle?" (Bangers 30), Keep fighting (cyan, the safe choice, 200×72) and End battle (the card's fill, 180×72), which surrenders (`BattleView.surrender`) |
| Result panel | top centre, 12 under the loot pill, on `ended`, 720 wide, its height capped so Return ends `MARGIN` above the safe area's bottom, the panel's shape with the light inner line the base's panels have (`_draw_edge`) | the title on a rounded banner across the top, gold with "Victory!" when a star was won, else red with "Defeat", in Bangers 48 in ink; the stars at 80 px (won gold, the rest the dark hull grey) over the destruction as "41%" (Bangers 40) with "destruction" dim, beside the loot as three rows of a coin and "+amount" at 24 px; "Units deployed" (or "No units deployed") over a strip of each type's picture (64 px, the deploy cards') with its count "xN" on a chip at its lower right corner (17 px, the disabled card's fill, an ink ring) and its name under it at 17 (the result's `deployed`); "Abilities used", when any was, the same with each ability's emblem at 48 px (the result's `abilities_used`); a strip too wide for the panel wraps. All between the banner and Return sits in a vertical scroll that scrolls only when it would not fit (`_fit_result`, again on a resize and once a wrapped strip knows its height), so the banner and Return stay in place. Return, gold, 240×72, leaves the battle (`BattleView.leave`). The deploy and abilities bars hide and Speed and End are disabled |
| Toast | top centre, 96 down | a refused cast (`cast_failed`): "Can't cast there" (`blocked`, off the field), "None of those left" (`none_left`); a refused deploy (`deploy_failed`): "Can't deploy there" (`blocked`), "None of those left" (`none_left`: a tap never meets it, since a card run out is let go at once, but a smear can when a frame steps several ticks and the type runs out between two), faded after a second. Text at 19 on the panel's fill, with a 4 px band down its left edge in its kind's colour (`ToastKind`, the show function's argument, `INFO` by default): the defence red for a refusal, as every toast here is, cyan for anything else |

Every part takes a variation of its own (`BattlePanel`, `BattleBar`, `BattleCard`, `BattleBarButton`,
`EndButton`, `BattleConfirmButton`, `BattleCommitButton`, the `Battle*` labels, the banners, the
chip, the result's scroll bar and the toast's, its text `BattleToastText` included), made in the Battle HUD block at the end of `_make_theme` after the skin's,
so the attack HUD is the same under every skin (**Skins**). Every control tapped mid-battle is at
least 64 tall; no text is under 17 px.

The top bar's text is set on the view's `stepped`, only where what it shows changed: the time,
the destruction, the stars and each card's count are kept as ints and formatted only when one
moves, and the loot is read (`BattleSim.loot()` builds a dictionary) only after a building has
fallen (`BattleView.falls()`), so a refresh with nothing changed allocates nothing. Queries for
the harness: `card(unit)`, `card_count(unit)`, `card_picture(unit)`, `timer_text()`,
`ability_card(ability)`, `ability_count(ability)`, `destruction_text()` (the number, "41%"), `stars_lit()` (the stars won), `speed_button()`, `end_button()`,
`is_confirm_open()`, `confirm_end_button()`, `keep_button()`, `is_result_open()`,
`result_lines()` (the title, then every text under the banner in order: a chip's "xN" comes just
before the name under its picture), `return_button()`, `deploy_bar()`, `ability_bar()`, `toast_text()`.

## Signals

| Signal | Emitted by | `main.gd` connects it to |
| --- | --- | --- |
| `build_pressed(type)` | a build card | `placement.begin_place` |
| `confirm_pressed` | Place (Done while painting) | `placement.confirm_place`, which ends paint mode while painting |
| `cancel_pressed` | Cancel | `placement.cancel_place` |
| `upgrade_pressed` | the upgrade button | `placement.upgrade_selected` |
| `close_pressed` | Close; Build, opening the panel over the info panel | `placement.select(0)` |
| `reset_pressed` | Reset base | `main._reset_base` |
| `template_pressed` | Template base | `main._template_base` |
| `practice_pressed` | Practice raid | `main._practice_raid` (`battle-view.md`) |
| `train_pressed(id, unit)` | a training card | `main._on_train_pressed`: `placement.train`, an error toasted |
| `cancel_training_pressed(id, unit)` | a queue entry | `main._on_cancel_training_pressed`: `placement.cancel_training`, "Refunded" or the error toasted |
| `research_pressed(unit)` | a research card | `main._on_research_pressed`: `placement.research`, an error toasted in `research_error_text` |
| `make_pressed(id, ability)` | a making card | `main._on_make_pressed`: `placement.make`, an error toasted |
| `cancel_making_pressed(id, ability)` | a making queue entry | `main._on_cancel_making_pressed`: `placement.cancel_making`, "Refunded" or the error toasted |
| `research_ability_pressed(ability)` | an ability's research card | `main._on_research_ability_pressed`: `placement.research_ability`, an error toasted in `research_error_text` |
| `expedition_pressed` | the Expedition button | `main.open_sector_map` (**Sector map**) |

## Queries for the harness

Read-only, so a scenario never reads a private member (`tools/harness/README.md`):
`build_button()` is the Build button; `is_menu_open()` whether the build panel is open or opening;
`build_panel()` the panel itself; `close_button()` the panel's close button;
`tab_button(category)` and `entry_button(type)` return the tab's and the card's `Button`;
`entry_status(type)` is a card's state in words (**Cards**); `entry_preview(type)` its picture (null until
rendered); `previews_done()` whether every type's picture has been made (in a headless run,
gone through); `entry_strip()` the `ScrollContainer` the cards scroll in; `resource_panel(res)`
is the top bar's meter for a resource and `resource_fill(res)` its fill, whose parent is the track it grows across
(its first child carries the stripes' `ShaderMaterial`, whose `full` is the full state);
`place_button()` is the place bar's `Place` (or `Done`); `drones_panel()` is the `DroneRing`,
whose `free_count()` and `total_count()` are the counts it shows; `reset_button()` and
`template_button()` are the debug row's Reset base and Template base, and `practice_button()` its
Practice raid (null in a release build). `ui_theme()` and `preview()` hand the theme and the
pictures to the battle's HUD. `Hud.skin` is the skin the theme is built in and `set_skin(look)`
restyles the HUD in another (**Skins**).
The army: `housing_text()`, `housing_bar()` and `housing_fill()` are the training header's
housing line, its bar (hidden with no Hangar) and the bar's fill, whose parent is the track it
grows across; `action_button()` is the info panel's Train, Make or Research and `info_detail()` its
lines; `army_panel()` the army panel, `is_training_open()`, `is_making_open()` and
`is_research_open()` which page it shows (open or opening),
`army_close_button()` its close button and `army_title()` its header; `train_card(unit)` and
`train_card_info(unit)` a training card and its last line; `queue_shown()` the queued units the
strip shows, `queue_entry(index)` an entry and `queue_head_status()` the head's state;
`make_card(ability)` and `make_card_info(ability)` a making card and its last line;
`research_card(unit)`, `research_card_lines(unit)` (its level line and its last line), the same for
an ability (`research_ability_card(ability)`, `research_ability_card_lines(ability)`) and
`research_line()` the research page's; `toast_text()` the toast's text while it shows.
`expedition_button()` is the Expedition button and `expedition_badge()` its badge's count ("" while
the badge is hidden). The sector map's own queries are under **Sector map**.
`MENU_OPEN_SECONDS` and `MENU_CLOSE_SECONDS` say how long to wait for a slide.

## Messages

`show_message(text)` shows the toast; `show_error(code)` shows `error_text(code)`, the
player-facing text for a `BaseState` error code from `ERROR_TEXT`, or the code itself when there
is none:

| Code | Text |
| --- | --- |
| `blocked` | That spot is taken |
| `limit_reached` | You've built the maximum for your Command Center level |
| `needs_command_center_level` | Upgrade your Command Center first |
| `no_free_builder` | All drones are busy |
| `insufficient_resources` | Not enough resources |
| `busy` | Already under construction |
| `max_level` | Already at max level |
| `unknown_unit` | Unknown unit |
| `not_a_producer` | This building does not train that |
| `bad_count` | Bad count |
| `needs_producer_level` | Needs a higher building level |
| `not_enough_housing` | Not enough room in the Hangars |
| `not_queued` | Nothing like that is queued |
| `needs_lab_level` | Needs a higher Research Lab |
| `bad_raid` | That battle does not add up |
| `not_enough_units` | Not enough units for that battle |
| `unknown_ability` | Unknown ability |
| `scan_cooldown` | The scanner is still cooling down |
| `bad_expedition` | That expedition does not add up |
| `not_enough_abilities` | Not enough abilities for that battle |
| `not_a_foundry` | This building does not make that |
| `needs_foundry_level` | Needs a higher Nanite Foundry |
| `not_enough_stock_room` | The Foundry's stock is full |

`research_error_text(code)` is the research panel's: `busy` there means the lab's one research
slot is taken, "Research already running"; any other code is `error_text(code)`.

`PlacementController.command_failed` is connected to `show_error`; the army's commands return
their error to `main.gd`, which toasts it (**Army panel**) and "Refunded" on a cancel;
`_reset_base` shows "Base reset" and `_template_base` "Template base"; a Practice raid with no
units "Train some units first", and its end "Practice: nothing applied" (`battle-view.md`); an
expedition's Attack with no units the same "Train some units first", and its end "Field cleared: N
star(s)" or "Field still open", with a second line of what came home, "+N metal, +M crystal", when
anything did (`battle-view.md`, **Expeditions**).
Amounts, costs and durations are formatted by `Format` (`input-camera.md`): a duration in seconds
under a minute ("45s"), minutes and seconds under an hour ("1m 15s"), hours and minutes under a
day ("18h 30m"), then days and hours ("2d 18h").
