# HUD

`src/game/hud.gd`: the on-screen UI, a `CanvasLayer` built in code. It reads `BaseState` for
display and reports presses as signals; it never changes game state. `main.gd` wires the
signals to `PlacementController` (`input-camera.md`). Two controls of its own draw in code:
`HudIcon` (`hud_icon.gd`), the vector icons and the unit glyphs, and `DroneRing`
(`drone_ring.gd`), the drones.
`ModelPreview` (`model_preview.gd`), a node under it, renders the build cards' pictures.

## The touch rule

`WorldInput` uses `_unhandled_input`, so any `Control` that is not `MOUSE_FILTER_IGNORE`
swallows every touch over it and the world underneath stops responding. Layout-only containers
that span empty screen space — the root, the top bar's column and its rows, the place bar's
row, the build panel's rows, the army panel's rows and pages — are set to `MOUSE_FILTER_IGNORE`. Panels and buttons keep the
default and block, which is what they should do. A new container must be IGNORE unless it is
meant to block. The meters and the drone ring block too, like the panels: an opaque part of the
HUD never lets a tap through to select or drag what lies under it. Each meter's root and the
ring are `MOUSE_FILTER_STOP`, and a meter's own parts (trough, fill, amount, icon) are IGNORE,
so the root is what a touch lands on. The toast is IGNORE, so it never blocks the world while it
shows.

The build cards are the one exception: they are `MOUSE_FILTER_PASS`, so a drag that starts on
a card also reaches the `ScrollContainer` and scrolls the strip (with the default `STOP` it
does not). The build panel's `PanelContainer` behind them is `STOP`, so a touch anywhere on the
open panel never reaches the world. Each card's content (its stripe, its picture and a
`VBoxContainer` of labels) is IGNORE, so the button itself is what a touch lands on. The army
panel's unit cards and queue entries are the same: `PASS` buttons whose content is IGNORE, on a
`STOP` panel.

## Theme

One `Theme`, built in `_make_theme`, styles every part: its fonts, sizes, colours and
`StyleBoxFlat`s. Controls take their style from it by type variation (`theme_type_variation`:
`BuildButton`, `TabButton`, `MeterText` and so on), not by overrides of their own; only a cost
amount takes its resource's colour as an override, since that colour is data. The buttons take
no focus.

**Fonts** (`assets/fonts/`, Google Fonts under the SIL Open Font License, each with its
`OFL.txt`, imported with Godot's default dynamic font settings): **Bangers** for the Build
button, the category tabs, the panel's close button, the info panel's title and the place bar's
and the debug row's buttons; **Lilita One**, the theme's default, for every other text. No text is
smaller than 15 px at 720p. Lilita One has no `∞`, which the meters show under the dev cheats,
so the meters' amounts take a `FontVariation` of it (`_meter_font`) whose fallback is the
engine's own font, `ThemeDB.fallback_font`: the sign draws the same on every platform rather
than from whatever font the system has. Only the meters fall back. The shared Lilita One
resource has no fallback, since a fallback's taller line metrics would space every other text,
the building view's timer label included, wider.

**Palette** (constants on `Hud`):

| Role | Value | Where |
| --- | --- | --- |
| Ink `INK` | `1B1A2E` | every outline, text outlines; `SHADOW` is the ink at 60 %, every flat shadow |
| Panel `PANEL` | `262348` at 96 % | the build panel, the info panel, the place bar, the toast |
| Card `CARD` | `3B3670` | cards, unselected tabs, the close button, Cancel, Close, Practice raid, Template base, Reset base |
| Card disabled `CARD_DISABLED` | `2E2B55` | a card or button that cannot be pressed now, a busy drone |
| Text `TEXT` | `F4F2FF` | names, amounts |
| Text dim `TEXT_DIM` | `9A95C4` | counts, reasons, the scroll bar's grabber |
| Accent `ACCENT` | `58E8FF` | the selected tab, Place, Train and Research, free drones, the unit glyphs' visors, canopies and eyes |
| Build gold `GOLD` | `FFC13B`, pressed `E0A52A` | the Build button, the upgrade button |
| Trough `TROUGH` | `17162A` | the meters' troughs |
| Warning `WARNING` | `FFB37A` | the info panel's note, a research card's lab level the lab lacks |
| Resource colours | `rules.json`, `Catalog.resource_color` | costs, the meters' fills and icons |
| Category stripes `CATEGORY_STRIPE` | `MaterialKit` roles: resources `ENERGY`, army `ARMY`, defense `DEFENCE`, traps `HAZARD` | the stripe along a card's top; a category not listed takes `ACCENT` |
| Army accent | `MaterialKit.ARMY`, `FF7F11` | the army meter's fill and figure, the unit glyphs, the stripe along a unit card's top |

**Shapes.** A `StyleBoxFlat` with a flat fill, a 3 px ink border (`BORDER`), round corners
(12; tabs, the meters and the toast 10) and a flat shadow, the ink at 60 % offset 4 px down
and right (`_shape`). A pressed button sinks: the shape and its text move 2 px down and right,
onto a shadow then 2 px away. Hover is a shade lighter; disabled takes the disabled fill with
its text at 55 %. Text gets an ink outline where it sits on a bright fill or over the world —
the Build label 4 px at 30 px, the tabs and the close button 3 px, the upgrade button 3 px, card
names and meter amounts 2 px — and none on a dark panel. A label's `outline_size` is four times
the outline's width in pixels (`OUTLINE_PER_PX`), since the font's stroke reaches a quarter of
`outline_size` out from each glyph.

## Layout

`setup(catalog)` builds the build panel, then, under a root `Control` carrying the theme and
laid out on the safe area (**Safe area**), every other part. The root comes after the panel,
so its parts — the Build button above all — draw over the panel.

| Part | Where | Contents |
| --- | --- | --- |
| Top bar | top, `MARGIN` (16) in, a column across the width | First row, from the left: a meter per resource in catalog order, the army meter, then the drone ring (**Top bar**). |
| Build button | bottom right, `MARGIN` from the safe area's corner, 128×64 | "BUILD" on gold; toggles the build panel (**Build panel**). Hidden while placing or painting. |
| Build panel | bottom, the screen's full width | Slides up over the bottom of the screen (**Build panel**). |
| Place bar | bottom centre | A panel holding `Cancel` and `Place` (170×72); `Place` is disabled unless the ghost is valid. While walls are painted it reads `Done` and is always enabled: there is nothing to confirm. |
| Info panel | bottom centre, 460 wide | Title `"Name   Lv N"` with Train or Research (a finished producer or research building only) and a `Close` button; detail lines (**Info panel**); the upgrade button; a note under it. |
| Army panel | bottom, the screen's full width | Slides up in the build panel's place: a producer's training or the lab's research (**Army panel**). |
| Toast | top centre, 96 down | A small panel with a centred line that fades out after 1.8 s over 0.6 s, then hides. |
| Debug row | debug builds only (`OS.is_debug_build()`): the top bar's second row, right-aligned | Practice raid, which emits `practice_pressed`, Template base, which emits `template_pressed`, then Reset base, which emits `reset_pressed`, 16 apart. On a row of its own so a long top bar never runs under it. |

The army panel is built after the build panel and before the root, outside it like the build
panel, so the Build button draws over it too. The place bar and the info panel are anchored to the bottom edge and grow upward
(`_anchor_bottom`).

## Top bar

**Meters.** One per resource, 220×36 (`METER_SIZE`), hidden while `state.capacity(res)` is 0, so
antimatter appears once something stores it. A trough (`TROUGH`, radius 10, its shadow) starts
20 px in from the meter's left; inside its border a fill grows from the left to `amount /
capacity` of the track (full at the cap), resized only on `refresh`. The fill is a `Control`
with `clip_contents` holding a `TextureRect` that tiles a 16×16 stripe image across the whole
track — a 45-degree white band over a grey 25 % darker, built once in `setup`
(`_make_stripe`) and tinted by the resource's colour over that grey, so the base reads as the
colour itself and the band 25 % lighter — and a gloss band (white at 25 %) across its top
third. The trough's ink border is drawn again over the fill, so the fill's square ends never
cover its round corners. The amount, `"750 / 1,000"` (`Format.short`: in full below a million,
then `"1.2M"`, `"4M"`, `"12.5M"` and from a thousand million `"1.2B"`, one decimal cut and its `.0`
dropped, so the widest text fits the label's 180 px; the cards and the info panel keep full
numbers), sits centred on the
part of the trough right of the icon, in Lilita One 18 px white with a 2 px ink outline. The
resource's icon (a `HudIcon`, 40×40) sits over the trough's left end like a badge. With the dev
cheats on (`Hud.cheats`, set by `main.gd`) every meter shows, full, reading `∞` (Lilita One has
no `∞`; the meters' fallback, the engine's font, draws it, **Theme**).

**Army meter.** Right of the resource meters, a meter like theirs: its icon the army's figure
and its fill the army accent, filled by `state.housing_used()` over `state.housing_capacity()`
and reading `"used / capacity"` (`Format.short`). It is hidden while the housing capacity is 0,
so it appears once a Hangar is finished, as a resource's meter appears once the base can store
it; the dev cheats leave it as it is. Its glint follows the last resource's by `GLINT_STAGGER`;
it never flashes.

**The meters move.** The stripes are drawn through `meter.gdshader`, one `ShaderMaterial` per
meter (its tint, its phase, the fill's width), all on the one animation clock, `anim_time`
(`art-style.md`, **Animation**, "One clock"), so nothing animates them per frame in GDScript. The
stripes drift along the bar, one tile (16 px) every 4 s. Once every 3.5 s a glint sweeps across
the filled part from left to right in 0.6 s: a hard-edged band 26 px wide, leaning right at the
top, in the near-white text colour at 70 % with a 6 px core at full, each with a 1 px soft edge.
Each meter's glint comes a third of the period after the one before it (`GLINT_STAGGER`), so they
never flash together. When a refresh finds a meter's amount dropped (a purchase), or
risen (a payout, an offline catch-up, loot) by more than 1.5 times what the resource produces in
the seconds the state advanced since the last refresh, counted as at least one and at most five
(`FLASH_RISE_TICKS`, `FLASH_MAX_SECONDS`) and rounded up to a whole unit, since a slow trickle
still rises a whole unit at a time, its whole fill flashes once, brightening 45 % towards white
and fading back over 0.25 s (`flash_time`, set to `Motion.clock()`). The per-tick trickle, a
stalled tick's included, never flashes; a longer gap's catch-up does. The first refresh only records the
amounts, and under the cheats, whose meters read `∞`, nothing flashes. The glint and the flash
are in the stripes, so the fill's clip keeps them off the border, the shadow and the icon. The
drift's period divides the clock's hour; the glint's does not, so it jumps once an hour. The
shader adds no draw call (`art-style.md`, **Cost**).

**Icons.** `HudIcon` draws its silhouette in `_draw`, vector, from no asset file, and only when it
is built or resized. Each part is a flat fill in the icon's colour with a lighter highlight facet
and a 2.5 px ink outline, over a 2 px ink offset shadow under the whole icon, laid out in a
40-unit box scaled to its rect: **metal** an ingot (a trapezoid bar with a lighter top face and a
darker end), **crystal** a pair of shards (a tall kite and a smaller one leaning on it, each with
a lighter left face), **antimatter** an orb with an orbit ring tilted across it, **drones** a
quadcopter seen from above, the classic drone glyph: a large light rotor disc on each diagonal
with a white highlight and an ink hub, round a rounded square body in the icon's colour with a
lighter facet and an ink eye at its front. Its parts keep inside a circle of about 18.5 units
round the box's centre, so at the ring's 30 px about 2 px lie between the rotors and the
sectors (on two diagonals the ring's and the icon's own shadows fall there) and they read as
four rotors round a small body. Any other
resource gets a plain cut gem. **army**, the army meter's, is a figure: a head over a pair of
rounded shoulders, each with a lighter facet. `HudIcon.paint(pen, kind, rect, color, wing)` adds
one to a `HudIcon.Pen`.

**Unit glyphs.** The army panel's cards and queue entries show a unit by its crew
(`catalog.unit_crew`), drawn the same way in the army accent until the unit models exist and
`ModelPreview` renders them: **human** a space helmet from the front, a dome over two cheek guards
with a cyan visor across it; **piloted** a cyan cockpit canopy on a hull over a track with three
wheels; **autonomous** a block head with an ink sensor slit and a cyan eye, an antenna with a cyan
bulb on top, over a darker shoulder bar. An air unit (`unit_class` `air`, `HudIcon.winged`) adds a
wing mark at the box's lower right, a swept white wing with its ink outline. `show_icon(kind,
winged)` swaps a glyph in place, redrawing only when either changed, as a queue entry does when
the queue moves.

**One draw call each.** The renderer draws every `draw_colored_polygon` and `draw_polyline` on
its own, so an icon drawn with them would cost a draw call per part. `HudIcon.Pen` builds a whole
icon, or the whole drone ring with its icon, as one triangle array instead
(`RenderingServer.canvas_item_add_triangle_array`, per-vertex colours): fills triangulated with
`Geometry2D.triangulate_polygon`, strokes as quads with mitred corners (capped at three times
their width), and in place of the renderer's antialiasing a 1 px feather that fades to nothing
along every stroke and shadow. Fills are left hard, since their outlines cover their edges.

**Drone ring.** `DroneRing`, 56×56, at the row's right end: one annular sector per drone
(`state.builders_total()`; outer radius 26, inner 18), laid out symmetrically round the whole
circle from the top, clockwise, with 6 degrees between neighbours, so a lone drone is a ring with
a seam at the top. Each sector is a closed polygon, at least 8 steps per arc and one per 12
degrees of a longer one, with a 2.5 px ink outline, over a 2 px ink offset shadow under the whole
ring, all one triangle array with the icon (**One draw call each**). The first
`state.builders_free()` sectors clockwise from the top are filled in the accent cyan with a thin
highlight arc (white at 35 %) in their outer third; the busy ones take the card-disabled fill. The
drone icon, 30 across, sits in the middle; with no drones the icon shows alone. It is redrawn
only when `refresh` changes a count (`set_counts`), never per frame, and shows no text: the "All
drones are busy" toast and the cards' "No free drone" name the drones.

## Refresh

`refresh(state, selected_id, placing, ghost_ok, painting)` is called by `main.gd` every tick,
after every state change, and on every selection change; `painting` is
`PlacementController.is_painting()`, which turns `Place` into `Done`. It refits the safe area if
the device's changed (**Safe area**), updates the meters and the drone ring, then:

- **placing** (painting included) → the build panel closes, Build hides and the place bar shows;
- **a building selected** (`selected_id` in `state.buildings`) → the build panel closes and the
  info panel shows, unless the army panel is open on that building;
- **otherwise** → neither bar nor panel shows; Build does.

The army panel belongs to the building it opened on: placing, a deselection or the selection of
another building closes it. The cards are refreshed only while the build panel is open (and when
it opens), and only the selected tab's. The army panel's content is rebuilt on `BaseState.changed`,
which the HUD connects to itself from the state `refresh` is given (`_watch`; `main.gd`'s handler,
connected first, has refreshed by then), and when it opens: the cards, the queue (copied once by
`queue_of` and kept until the next change) and the research line's words. A `refresh` while it is
open, the one-second tick's included, only counts down (`_tick_army`): it reads the head's
`training_status` and `training_seconds_left`, or `research_seconds_left`, none of which copies
anything, and sets the head's or the research line's text only when the value it shows changed. So
a tick with no state change copies nothing from the state and builds one short string, the new
time left, while a countdown runs; a tick that changes the state (production paid, a unit trained)
emits `changed` and rebuilds.

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
the safe area (`apply_safe_area`). It is 300 px high at 720p (`MENU_HEIGHT`), never more than
40 % of the screen's height (`MENU_MAX_SHARE`, so 288 at 720p), and grows upward if its content
needs more. Panel fill, a 3 px ink border along its top edge only, its top corners rounded 16,
no shadow.

**Tabs.** The top row: one toggle button (140×48, Bangers 24) per `catalog.categories` id, in
that order, labelled with `catalog.category_name`, in one `ButtonGroup`; then, at the right, the
close button (48×48, "X" in Bangers 28). An unselected tab is a card with white text in a 3 px
ink outline (`TabButton`); the selected one is cyan with ink text and no outline
(`TabSelected`). The first is selected when the HUD is built; the selection is remembered while
the game runs (not saved). Selecting a tab shows the cards of the `catalog.menu_order` types
whose `catalog.category_of(type)` is that tab, in `menu_order` order, scrolls the strip back to
its start, and refreshes those cards from the last state `refresh` was given. Pressing the tab
that is already selected scrolls its strip back to the start, a tween of `scroll_horizontal` over
0.2 s (`STRIP_RETURN_SECONDS`, cubic ease out), which selecting another tab stops; the tab stays
selected.

**Cards.** Under the tabs, a horizontal `ScrollContainer` of cards, scrolled by a drag, with a
thin scroll bar under it; to its right a column as wide as the Build button stays clear, since
Build stays over the open panel at the safe area's corner. Every menu type gets a 200×176 card
when the HUD is built; a tab only shows or hides them. A card is a card-filled button with the
ink border and shadow, its category's stripe (6 px, `CATEGORY_STRIPE`) along its top inside the
border, the building's picture (84×84, `PREVIEW_SIZE`; **Pictures**), and three centred lines
under it:

1. the display name (Lilita One 20 px, white, a 2 px ink outline);
2. the level 1 cost, each amount in its resource's colour (`resource_color`, the text colour
   when there is none), or "Free" (18 px);
3. the status: `"built / max"` (16 px, dim), from `state.count_of(type)` and
   `catalog.max_count(type, state.cc_level())`, when `state.check_can_build(type)` passes; else
   the reason (15 px, dim), and the card is disabled: the disabled fill, its picture, name and
   cost at 55 %:

| `check_can_build` | Status line |
| --- | --- |
| `needs_command_center_level` | Needs Command Center N (N is level 1's `requires_cc`) |
| `limit_reached` | Max built |
| `no_free_builder` | No free drone |
| `insufficient_resources` | Not enough <name of the first resource, in catalog order, the base is short of> |
| anything else | `error_text(code)` |

A type the Command Center has not unlocked (`max_count` 0 at the current level) is still
listed, disabled with its "Needs Command Center N" line. Pressing a card closes the panel and
emits `build_pressed(type)`; a drag across the strip scrolls it and presses nothing. The Barrier
Wall, the Defence tab's last card, is a card like any other, and placement paints it
(`input-camera.md`).

**Pictures.** `ModelPreview` renders each type's level 1 model (`BuildingModels.create`) into a
160×160 texture once and keeps it for the session. It owns one `SubViewport` with a world of its
own (`own_world_3d`), a transparent background and 4× MSAA: an orthographic camera at the world's
angle (`IsoCamera.PITCH_DEG`, `YAW_DEG`) framing the model's bounds with 8 % to spare on each
side, the key light from `main.gd`'s direction and colour with no shadow, and an environment with
no ambient and linear tonemapping. The models keep the world's toon materials; their outlines take
a copy of the ink material whose `ink_px` is scaled by 720 / 160, so the line is as many pixels on
the texture as it is on a 720p screen. A moving part stands where `Motion.transform_at(0)` puts
it. It renders one model a frame, and only while the panel is open: a frame puts the model in front
of the camera and has the viewport draw once (`UPDATE_ONCE`), the next reads the image back into
an `ImageTexture`, caches it by type and hands it to the card. Opening the panel, and selecting a
tab while it is open, moves that tab's types to the front of the queue, so the visible cards fill
first. A card shows no picture, only its stripe, until its own is ready. Once every type is
cached the viewport is freed and the node stops processing, so the panel costs nothing more per
frame. A headless run draws nothing: the queue is gone through but no picture is made.

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

The title is in Bangers 24 and the detail lines in Lilita One 17. The upgrade button, gold
like Build with its text in a 3 px ink outline, reads "Under construction" (disabled) while
busy, "Max level" (disabled) at
the top level, else "Upgrade to Lv N   cost   (duration)", disabled with the reason in the
note when `state.check_upgrade` fails. Pressing emits `upgrade_pressed`; `Close` emits
`close_pressed`.

Beside `Close`, a finished producer (a type `catalog.units_of_producer` names, at level 1 or
more) shows **Train** and the finished research building (`catalog.research_type`) **Research**,
112×44, cyan with ink text in Bangers 22 like Place. Pressing it opens the army panel on that page
in the info panel's place (**Army panel**).

## Army panel

Shaped like the build panel and in its place: a `PanelContainer` outside the root, the screen's
full width at its bottom edge, its content padded into the safe area (`apply_safe_area`), the same
slide (`_slide`, **Build panel**), and the same column kept clear on the right for the Build
button. Its height is its content's, with the build panel's (288 at 720p) as the minimum: the
training page is about 308 at 720p (310 once the queue strip scrolls and shows its bar), the
research page about 290. A header, the building's `"Name   Lv N"` in Bangers 24 with the close button (48×48,
"X") at the right, over one of two pages. The panel stops every touch on it; its layout
containers take none. The close button slides it down and shows the building's info panel again,
still selected. Hidden while closed.

**Training panel.** A horizontal strip of unit cards (200×140), one per unit the producer's type
trains, in `units.json` order (`catalog.unit_types()`; a card per unit is built up front and the
page shows its producer's). A card has the army accent's stripe along its top, the unit's glyph
(48×48, **Unit glyphs**), its name (Lilita One 20, a 2 px ink outline), a row of its train cost at
its current level (`unit_level`), each amount in its resource's colour, or "Free", and its train
time (`Format.duration`, dim), then "Housing N   Housed M" (16 px, dim: the unit's housing and
`army_count`). A unit the producer's finished level does not train yet (`unit_producer_level`) is
locked: the card is disabled, its glyph, name and cost at 55 %, its last line "Needs <producer>
<level>" (15 px, dim). Tapping a card emits `train_pressed(id, unit)`; `main.gd` queues one through
`PlacementController.train` and toasts the error when it fails.

Under the cards, the **queue strip**, scrolled like the cards: an entry (180×48) per queued unit,
oldest first (`queue_of`), each a 32 px glyph beside the unit's name (16 px); the head adds its
state under the name (15 px, dim): its time left, "12s left" (`training_seconds_left`), "Waiting
for room" (`training_status` `waiting`) or "Paused" (`paused`, its producer upgrading). With no
queue the strip reads "Nothing in training". Tapping an entry emits
`cancel_training_pressed(id, unit)`; `main.gd` cancels the newest queued unit of that type
(`PlacementController.cancel_training`, which need not be the entry tapped) and toasts
"Refunded". Entries are made as the queue first grows that long and kept; after that a rebuild
only sets text and swaps glyphs, and nothing is allocated per frame (**Refresh**).

**Research panel.** Under the header a line naming the research running, "Researching Ranger to
Lv 2: 30s left" (`research_unit`, `research_seconds_left`), or "No research running"; under it a
strip of cards (200×164), one per unit the base has unlocked (`is_unit_unlocked`), in `units.json`
order: the glyph, the name, "Level N" (18 px), then the next level's research cost and time, and
"Needs Lab L" (its `requires_lab`), "Researching" on the unit being researched, or, at the unit's
top level, "Max level" with no cost. A card whose lab level the lab lacks, or at the top, is shown
at 55 % with its lab level in the warning colour, but still takes a tap. Tapping a card emits
`research_pressed(unit)`; `main.gd` starts the research through `PlacementController.research`
or toasts why not, in `research_error_text` (**Messages**). There is nothing to cancel.

## Safe area

The root holds every part but the build panel and the army panel, so their anchors and margins are relative to the
safe area, the part of the screen clear of notches and the home indicator.

`apply_safe_area(inset: Rect2)` lays the root out inside `inset`, a rect in the HUD's own
coordinates (the viewport's visible rect: 1280×720 on a 16:9 screen under the `canvas_items`
stretch), by setting its offsets. It pads the build panel's content, and the army panel's, by
the same inset on the left, the right and the bottom, and sets their height for the screen's.
`_fit_safe_area`
fits it to the device in `setup`, on `get_viewport().size_changed`, and on every `refresh` (the
1 s tick's included), since turning a phone over moves the notch to the other side without a
resize: `DisplayServer.get_display_safe_area()`, in screen pixels, is clipped to the window
(`window_get_position`, `window_get_size`), made relative to it, and scaled by the visible
rect's size over the window's. It is applied only when it differs from the last rect fitted
this way. On desktop the safe area is the screen's usable rect: while the window lies inside
it the result is the whole visible rect, and a window reaching outside it (over the menu bar,
say) is inset to the part inside. A window with no size (a headless run) gets the whole
visible rect. The harness calls `apply_safe_area` to try a notch-like inset on a desktop window;
that inset stays until the device's safe area changes.

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

## Queries for the harness

Read-only, so a scenario never reads a private member (`tools/harness/README.md`):
`build_button()` is the Build button; `is_menu_open()` whether the build panel is open or opening;
`build_panel()` the panel itself; `close_button()` the panel's close button;
`tab_button(category)` and `entry_button(type)` return the tab's and the card's `Button`;
`entry_status(type)` is a card's status line; `entry_preview(type)` its picture (null until
rendered); `previews_done()` whether every type's picture has been made (in a headless run,
gone through); `entry_strip()` the `ScrollContainer` the cards scroll in; `resource_panel(res)`
is the top bar's meter for a resource and `resource_fill(res)` its fill, whose parent is the track it grows across;
`place_button()` is the place bar's `Place` (or `Done`); `drones_panel()` is the `DroneRing`,
whose `free_count()` and `total_count()` are the counts it shows; `reset_button()` and
`template_button()` are the debug row's Reset base and Template base, and `practice_button()` its
Practice raid (null in a release build).
The army: `army_meter()`, `army_meter_text()` and `army_fill()` are the army meter, its text and
its fill; `action_button()` is the info panel's Train or Research; `army_panel()` the army panel,
`is_training_open()` and `is_research_open()` which page it shows (open or opening),
`army_close_button()` its close button and `army_title()` its header; `train_card(unit)` and
`train_card_info(unit)` a training card and its last line; `queue_shown()` the queued units the
strip shows, `queue_entry(index)` an entry and `queue_head_status()` the head's state;
`research_card(unit)`, `research_card_lines(unit)` (its level line and its last line) and
`research_line()` the research page's; `toast_text()` the toast's text while it shows.
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

`research_error_text(code)` is the research panel's: `busy` there means the lab's one research
slot is taken, "Research already running"; any other code is `error_text(code)`.

`PlacementController.command_failed` is connected to `show_error`; the army's commands return
their error to `main.gd`, which toasts it (**Army panel**) and "Refunded" on a cancel;
`_reset_base` shows "Base reset" and `_template_base` "Template base"; a Practice raid with no
units "Train some units first", and its end "Practice: nothing applied" (`battle-view.md`). Amounts, costs and durations are formatted by
`Format` (`input-camera.md`).
