# The UI pass (2026-10-27)

The record of the pass the owner asked for after the performance pass: "the general UI across the board
needs improvements", naming all the menus, the expedition UI and the enemy base icons, the building and
troop training menus and their icons ("mainly the spell icons"), the resource bars and the builder drone
meter ("still looks bad, I don't know how to fix it"). `docs/project_overview.md` §3.1 holds the
decisions; `docs/reference/hud.md` describes the HUD as it is now; this file holds the method, what was
built, the numbers and what was left.

## 1. The ask and the method

Candidates first, then the roll-out. Every surface was shot on main `426dc8f` (the harness's `hud_menu`,
`hud_layout`, `place_and_build`, `train_units`, `make_abilities`, `expedition_flow` and `battle_view`),
a scout mapped the HUD's code, and an art-and-UX critique judged the shots against the world's comic
look with one measure: the HUD is authored at 720 virtual pixels tall under `canvas_items` stretch with
`aspect` `expand`, so on a 6.1-inch phone 1 vpx is about 0.09 mm, a 9 mm touch target is 100 vpx and a
2 mm em is 22 vpx. Against that, every button but the cards and Place/Cancel was under the platform
floors and every 15–18 px line was under 2 mm; the busy drone segments and the unearned battle stars
sat at 1.12:1 against their panel; cyan served as selection, confirmation and the raid button at once.

The drone meter was a compare-candidates problem: five styles (a bold ring with a count badge, dots
around the icon, a pill with a slot per drone, an icon card with a count badge, a row of drone glyphs)
plus two icons were built behind a style switch and rendered by the game in the real top bar and on a
sheet at every count, and the owner picked **the pill with slots and "2 / 5"** with the front-view icon.
The whole HUD was rendered in three skins on the same five screens (the critique's directions: A "the
same comic console, finally in focus", B "halftone console", C "pulp page"); A is the foundation the
other two build on, so it was landed as the default and the roll-out proceeded on it while the skin
pick stayed open with the owner.

## 2. What was built

Reviewed and landed on main in this order:

1. **The expedition tint check** (`b18dae6`): found on the way. One defender body counted as plain in
   `expedition_flow`: an EMP-disabled shield generator wearing a held material copy that carries the
   rival tint correctly; the check now recognises held copies. The game was right.
2. **The icons** (`783e842`): a coin backing any `HudIcon` can wear (a disc at the colour's capped value,
   a 3 px ink ring, a light band over its upper 40 %, a drop shadow); the three ability glyphs redrawn as
   emblems with mass on their own coins (three nanite blobs with a white cross on green; three arcs and
   a white bolt on arc blue; a white crosshair broken by a hazard bolt on red); the unit glyphs on the
   army coin; the metal ingot always steel; new marks `lock`, `clock`, `chevron`, `star`, `skull`,
   later `cross`; one triangle array per icon, so one draw each; the `icon_sheet` scenario.
3. **The theme foundation and the skins** (`36a81f8`): a type scale with nothing under 17 px; ink
   outlines only over bright fills or the world; touch sizes (tabs 160×56, close 56, Build 136×72,
   Expedition 184×72, place bar 170×72); colour roles (gold spends, army orange raids, cyan only selects);
   a light inner line and a lighter top band on the panels; pressed = +15 % fill and a 4 px sink; the
   meters as 240×44 pills with the icon on a 48 px coin, deeper fills, 20 px outlined digits, a gold full
   state, the glint kept at half alpha every 8 s, on one shared strip; the build cards 200×200 with a
   112 px picture on a category plinth, a count chip, cost rows with resource-coloured coins, the build
   time with the clock mark, locked cards desaturated (`locked.gdshader`) with a lock chip and never a
   55 % fade; the debug row demoted to grey chips under "DEV"; the Expedition badge 36 px centred on the
   corner; skins B (9-slice `StyleBoxTexture`s generated into `assets/textures/kit/hud_*.png`) and C
   (cream menus, ink text, a torn-edge tray, trading-card cards) behind `Hud.Look` with A the default and
   `set_skin` for the harness; the `hud_directions` scenario (fifteen shots).
4. **The drone meter** (`743ac0a`): the `drones` icon as the construction drone seen from the front;
   the meter a 200×44 pill in the meters' language with one slot per drone (free cyan with the gloss,
   busy striped trough), "2 / 5" in the meters' text, in the strip's right slot, restyled per skin
   through the same helpers; the `drone_meter` scenario.
5. **The attack HUD** (`35e0a79`): stars as the `star` mark at 36 px (hull-dark until won, gold won;
   `BattleHud.Star`'s three draws each gone), time and "41%" in Bangers 28; speed 96×64 and End
   140×64 in defence red; the loot as one pill across the top centre; deploy card names 17 and counts
   22 with a 3 px ink ring on the selected card; the confirm dialog at 55 % dim with 72 px buttons; the
   result a ceremony (a gold or red banner in Bangers 48, 80 px stars, "41%" at 40, loot rows with "+",
   64 px unit pictures and 48 px emblems with count chips, Return gold 240×72) anchored under the loot
   pill with a middle that scrolls only when every type was deployed; toast kinds with a coloured
   edge; battle-only theme variations so the attack HUD stays the dark in-field family under every
   skin. The attack HUD's own draws fell (mid-battle about 69 → 54, the result 82 → 60 on a full army).
6. **The sector map** (`6cb6175`): the cards' thumbnails as 160 px scan plates drawn as one triangle
   array each (the ground with a faint grid and vignette, the walled compound as one polygon, the
   Command Center a violet diamond, defences a red halo of discs, storages gold squares, a band-coloured
   frame, a ribbon with the band word and one to three skulls, a "CC N" chip); loot rows on
   resource-coloured coins; the grid flows to two columns only when a safe-area inset narrows it (under
   `aspect` `expand` the width never drops below 1,280); SCAN 190×56, Back 140×72, Attack 240×72 gold;
   the detail's right column filled (loot rows at 22, a holdings table, the legend on coins); the
   plates, minimap, stamps and summaries kept across opens: the opening frame about 13.4 → 6.7 ms,
   `open()` 2.7 → 0.3 ms.
7. **The army panel, queue, info panel and toasts** (`6ab6c59`): the build cards' drawn parts
   generalised for any card; army cards 200×184 with a 96 px picture (a 64 px emblem for abilities) on
   the category plinth, "Lv N" and "Housed N" / "In stock N" chips, the cost with its coin, the time
   with the clock, locked cards like locked build cards; the housing line a 220×32 meter with the gold
   full state; the queue's entries 220×56 with the glyph on its coin, a progress fill on the head
   (`Hud.Fill`, the meter shader's stripes) and a cross; the abilities pages in the Foundry's nanite
   green; a research progress bar beside the title; the info panel with a 64 px picture, "Building…"
   while first constructing, chevron rows with the next value in the accent, a gold MAX chip in place
   of a dead button, a progress fill in the upgrade button while it builds, Train/Make/Research 128×56
   and Close 112×56; `show_message(text, kind)` with refusal (red), info (cyan) and reward (gold)
   edges and every caller classified.

## 3. Numbers

| measure | before | after |
|---|---|---|
| smallest text on a card or status line | 15 px (0.95 mm cap height on a 6.1-inch phone) | 17 px, the floor |
| smallest control the player taps in play | 44 px (4.0 mm) | 56 px (5.0 mm); primaries 72 (6.5 mm) |
| the maxed base, Army tab open, draw calls | 605 | 599 |
| a fresh base's build tabs, draw calls | 103 | 102–110 (a lock mark per locked card) |
| the attack HUD's own draws, mid-battle / result | 69 / 82 | 54 / 60 |
| the sector map's opening frame | 13.4 ms | about 6.7 ms |
| the training page's draws over the base | +28 | +40 (chips and crosses) |
| a coined icon | n/a | 1 draw (17 coined icons measured at 17) |

## 4. Decisions

Recorded in `docs/project_overview.md` §3.1: the colour roles; the outline rule; the type and touch
floors; the meters as pill and coin on a strip; the drone meter as the pill the owner picked; emblems on
coins rather than rendered stills of the effects; the sector thumbnails as scan plates (a rendered
outpost picture only for the detail view, later); the attack HUD's own variations; the skins behind
`Hud.Look` with A the default; the glint kept rarer rather than dropped; the debug row demoted but one
tap away; the difficulty words unchanged.

## 5. Levers not pulled, and what is left

- **The skin pick**: the owner has not chosen between A, B and C; A is landed as the default and the
  roll-out is on it. B and C stay behind `Hud.Look` until the pick; the pick's follow-up is either
  deleting B and C (two small commits and the `hud_*.png` textures) or a cream pass over the army
  panel, queue, info panel and sector map for C. On 2026-10-29 the owner chose A; B and C were deleted.
- **The info panel's picture** is blank for the first frames after selecting a building whose picture
  is not made yet, then fills on its own; and it is the level-1 picture of the type.
- **The result panel**: a fade at the scroll's bottom edge would say "more below" better than the bar.
- **The sector map** still draws the base behind the panel (about 5 ms of its opening frame); two fields
  of the same band look alike because the generator's parameters are the same (data, not drawing); the
  detail's right column has room to spare.
- **The phone**: the touch and text sizes are from the critique's measure, not a phone in hand; the
  phone measurement procedure in `testing-tools.md` still waits, and the fold's video memory with it.
- **Sound** comes next (hybrid: a build-time synth to WAV by a tool script, CC0 assets for music and
  ambience; the research is in the session notes).

## 6. Seeing it again

`tools/harness/run.sh hud_directions --rendered` (the HUD's gallery: five screens), `drone_meter
--rendered`, `icon_sheet --rendered`, and the surfaces' own scenarios: `hud_menu`, `hud_layout`,
`place_and_build`, `train_units`, `make_abilities`, `expedition_flow`, `battle_view`. Rendered runs
take the machine-wide lock and want `caffeinate -d -i -u`, with the window visible.
