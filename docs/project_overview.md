# Space Game — project overview

Last updated: 2026-10-16. Snapshot taken after the upgrade pass to Command Center 10, save format
version 2.

This file answers three questions: what the project is meant to become, how far along it is, and
what has been decided. It is written for a human reader and for an AI agent picking up the
codebase.

It is a summary, not the reference. The reference files under `docs/reference/` and the code's
module header comments are the authority on how each mechanism works, and the map, `CLAUDE.md`,
on the conventions to follow when changing code. Where they disagree, check the code.

## Status vocabulary

Every item below carries one of these three statuses.

| Status      | Meaning                                           |
| ----------- | ------------------------------------------------- |
| Built       | Implemented and working at HEAD.                  |
| In progress | Partly implemented. The remaining work is listed. |
| Planned     | In scope with a known shape. Not started.         |

## 1. What the project is

A mobile space base-builder in the style of Clash of Clans, for native iOS and Android, light
enough for mid-range phones. "Space Game" is a working title. It is built by a solo developer
with Claude, in Godot 4.7 with statically typed GDScript.

### 1.1 Scope

Three loops, of which the first is built:

1. **Base** — build and upgrade a base on a grid: placement, construction and upgrade timers,
   drones (builders) as the limit on parallel work, a Command Center whose level gates what can
   be built, an integer economy with production rates and storage caps, and a local save with
   offline progress.
2. **Expeditions (PvE)** — send expeditions into procedurally generated fields (asteroids,
   deposits, hazards) generated from a seed, and bring loot back into the base.
3. **Attacks (async PvP)** — attack other players' saved bases, which defend themselves with AI;
   a deterministic battle simulation that the server can replay to verify the result.

Later: a server (accounts, base storage, command validation, replay verification), matchmaking,
an attack log, revenge and shields.

### 1.2 Design philosophy

- **A pure, deterministic core.** Game logic (`src/core`) is plain data and functions with no
  engine state: it never reads a clock, uses integers only for anything that affects state,
  draws randomness from a seeded generator, and orders ties by id. The same inputs give the same
  state on every device and on the server. This is what makes server-side validation and
  replayable battles possible later, so it is treated as a hard rule from the first commit.
- **Commands, not mutations.** Every state change is a plain dictionary applied through one
  function, because those dictionaries become the server RPCs. Each command has a matching
  check so the UI can show why something is not allowed before trying it.
- **Data-driven balance.** Costs, times, rates, caps and the build menu live in JSON that the
  server will load too; rebalancing is a data change, never a code change. Tests use their own
  fixture catalog so rebalancing never breaks them.
- **Light on the phone.** Fixed orthographic camera, models built in code from one generated
  material kit (at most eight mesh instances a building, ten at Crown: a body and up to three
  moving parts, four at Crown, each with an outline that casts no shadow; surface effects
  animated in the shaders), the GL Compatibility renderer, no addons, no per-frame allocation.
- **One code path for desktop and phone.** Mouse clicks arrive as touches, so every gesture is
  written once and tested on a Mac before it reaches a device.
- **Agent-editable.** Scenes are built in code and the project is text, so an agent can read and
  change everything; hand-written `.tscn` files stay to one node.

## 2. Status

### 2.1 Built — milestone 1, the offline base

| Area | Status | Notes |
| --- | --- | --- |
| Catalog and game data | Built | `data/rules.json`, `data/buildings.json`; validated on load; all numbers ints |
| Building roster | Built | 33 types: the Command Center (levels 1–10) and 32 more in four build-menu categories, each with the levels and counts of the upgrade pass's level map (`docs/plans/upgrade-pass.md` §3), every level of every type modelled (259 models); metal, crystal and antimatter (from CC 4); one development-scale curve, checked by tests for affordability and for never going down; the build menu has a tab per category |
| Tiers | Built | Each level's theme by the Command Center band it unlocks in (its `requires_cc`; the Command Center's by its own level): Base, Gold, Chrome, Obsidian and Crown, so a maxed base reads black and gold with violet cores, crowns and escorts (`docs/reference/art-style.md`, **Tiers**) |
| The field | Built | 48×48 cells (`data/rules.json`), the start layout at its centre, inside the perimeter (kerb, pylons, hologram fence) and the terrain ring; the debug build's template base lays out every type at its Command Center 10 count in 46 of its 48 rows |
| Base state: place, move, upgrade | Built | Commands through `BaseState.apply`; `check_*` for the UI; error codes |
| Timers and builders | Built | Construction and upgrade timers; drone bays supply builders; instant builds skip the builder check |
| Economy | Built | Per-hour integer rates; remainders carried in resource-seconds; storage caps; busy buildings don't produce |
| Command Center gates | Built | `requires_cc` per level; `max_count` per CC level |
| Grid occupancy | Built | `BaseGrid`; footprints; a move may overlap its own old spot |
| Seeded RNG | Built | `SeededRng`, xorshift32; sequence frozen by test; used for scenery today |
| Save and load | Built | `user://base.json`, version 2 (records the field; a version 1 base is centred on a grown field); offline progress on load; buildings that no longer fit are dropped |
| Camera | Built | Fixed isometric orthographic; pan, pinch and wheel zoom; focus clamped to the grid |
| Touch input | Built | Tap, drag, two-finger pinch and pan; trackpad gestures; HUD gets touches first |
| Placement | Built | Ghost with valid/invalid footprint, Place/Cancel; select; drag the selected building to move; walls painted by tapping and dragging until Done; the camera scrolls while a drag nears the screen edge |
| HUD | Built | Resources and drones (a resource appears once the base can store it), build menu with category tabs and entries showing cost, count and why one is unavailable, place bar, info panel with every stat and the next level's, toasts, debug reset; laid out inside the safe area |
| Visuals | Built | A pulp sci-fi comic style: three-band toon light with cool halftoned shadows from one warm key light, ink outlines, a material kit of twenty texture layers generated by `tools/gen_textures.gd`; models per type and level built in code onto the kit, every level of all 33 types built in the comic style by the model passes and the upgrade pass, in five tiers (`docs/reference/art-style.md`); walls drawn as one merged mesh in which neighbours join (corners, T-junctions and crossings close); scaffold while building, with a builder drone flying round every busy site and cutting at it with a laser; a seamless levelled field of regolith with inked craters, pebbles and cracks and a grid shown only while building, ringed by a perimeter of a concrete kerb, lamp-topped pylons and a low hologram fence; a seeded landscape round it of ridged dunes, craters, mesas and a dry channel, smooth shaded with inked ridges and drawn with the field's marks, wind ripples and inked rock strata, with chamfered rocks and glowing crystal outcrops |
| Tests | Built | Own headless runner; fixture catalog; one test file per core area |
| Tooling | Built | Gate script, landing script, behaviour harness (`tools/`), API dump |

Balance numbers in `data/` are fast development values, not tuned. A debug build goes further:
every level is free and builds in one second at most (`Catalog.apply_dev_cheats`; `-- --no-cheats`
for the real numbers).

### 2.2 Roadmap

| Step | What | Status |
| --- | --- | --- |
| 1 | Offline base: placement, timers, economy | Built |
| 2 | Base polish: the building roster, build-menu categories, a third resource (antimatter), low-poly models built in code, HUD category tabs, safe-area margins for notches, painting walls by dragging, edge auto-scroll while dragging | Built |
| 2a | The upgrade pass (`docs/plans/upgrade-pass.md`): the Command Center and every type to Command Center 10 (ten levels for the staples), the five tiers, 138 new level models with Crown escorts, the 48×48 field with a version 2 save migration, the maxed base measured | Built |
| 2b | The model feedback pass (`docs/plans/model-feedback.md`): the owner's review of every max-level model folded in: no robot above defence buildings, every robot tailored to its building (a security bot, an ore hauler, a collector, a marshaller, welders), one slow lightning crackle, rising smoke, the Command Center's broader base, the academy and fabricator reshaped, the mortar's plasma and the orbital cannon's spire | Built |
| 3 | Seeded PvE expeditions: a field generated from a seed with `SeededRng` (asteroids, deposits, hazards); loot returns into `BaseState` through a new command | Planned |
| 4 | Deterministic battle sim in `src/core/battle/`: fixed-point integer positions (1 cell = 1000 units), fixed tick; replay = seed + base layout + list of deploy commands; tested headless against AI-built bases; same inputs give byte-identical results | Planned |
| 5 | Server: Nakama with accounts, base storage and command validation; battles verified by replaying them in headless Godot running the same `src/core` | Planned |
| 6 | PvP matchmaking, attack log, revenge, shields | Planned |

### 2.3 Known limitations

- **The local clock is trusted.** Time comes from the device; changing the device time can cheat
  today. The server will own time (step 5).
- **Models are built in code** (`BuildingModels`, from `LowPolyMesh` parts painted from the
  generated material kit); imported models in `assets/` may replace them later, keeping the
  model contract in `docs/reference/art-style.md`.
- **The save is local, at `"version": 2`** (one migration: version 1 bases are centred on the
  grown field); the server will hold the base
  later and nothing below `main.gd` changes.
- **Phones are unmeasured for the maxed base.** At the Command Center 10 counts the template
  base is 1,140 draw calls and 1.7 million primitives a frame at the widest zoom on the
  development Mac (`docs/reference/art-style.md`, **Cost**); no phone has run it, and that
  measurement decides whether the Crown robots stay.
- **Build times are on the development scale**: 27 to 40 minutes at the top levels (the walls
  and the Drone Bay instant), the Command Center's 75 to 150 minutes at levels 6 to 10
  (`docs/reference/data-format.md`); the retune is parked until the economy is tuned.
- **The template base fills 46 of the field's 48 rows** at the Command Center 10 counts, so more
  walls or another type at the top needs its layout reworked (`docs/reference/input-camera.md`).
- `hp`, `damage`, `range_cells`, `fire_ms`, `hidden`, `targets` and `capacity` in
  `data/buildings.json` are display-only: the HUD's info panel shows each where it exists, and
  none of them drives anything until the battle sim (step 4).

## 3. Decisions

### 3.1 Recorded

- **Godot over Unity and three.js.** Text scenes and scripts an agent can edit, free, native
  mobile export.
- **GDScript, not C#.** Godot still marks C# on iOS and Android experimental. Statically typed
  throughout.
- **GL Compatibility renderer**, for the widest range of phones.
- **No addons.** Tests run on the project's own runner in `tools/`; the harness is the
  project's own.
- **Two layers, kept apart.** `src/core` is pure logic (`RefCounted`, no clock, ints, seeded
  randomness, commands); `src/game` is presentation and the only caller of `apply()` is
  `PlacementController`. See `CLAUDE.md`, **Architecture rules**.
- **Integer economy with carried remainders.** Rates are per hour; unpaid production is carried
  in resource-seconds so that ticking every second or once a day gives the same total.
- **Commands are dictionaries** (`{"op": "place", "type": ..., "cell": [x, y]}`) because they
  become the server RPCs; new actions are new ops with a matching `check_*`.
- **Game data is JSON shared with the server**, converted to ints on load because Godot parses
  every JSON number as a float.
- **Tests use fixtures, never `data/`**, so rebalancing never breaks them.
- **One battle sim, not two.** The sim is never ported to TypeScript; the server runs headless
  Godot for replays.
- **Server: Nakama with its TypeScript runtime**, in `server/` (a `.gdignore` keeps Godot out).
- **Scenes are built in code.** `scenes/main.tscn` is one node with `main.gd`.
- **A `--save-path` user argument** lets the gate and the harness boot the game on an isolated
  save, so the owner's `user://base.json` is never opened by a tool run.
- **Tiers come from the data** (the upgrade pass, 2026-10-16): a level's theme is set by the
  Command Center level it requires (`requires_cc`), through one mapping, so every type's levels of
  one band share a look; the Command Center takes its own level, since its level k requires k − 1.
- **The field is 48×48** (the owner, 2026-10-16), for a maxed base's 1,100 cells with room left;
  version 1 saves, laid out on the 40×40 field, are shifted by (4, 4) on load so a base stays
  centred, and the perimeter and the terrain ring kept their look round the wider field.
- **The comic style at every tier** (the owner, 2026-10-16): the tiers change the palette, never
  the style; a level that reads grim, grey, realistic or cluttered fails its review whatever its
  budgets say (`docs/plans/upgrade-pass.md`, §2a).
- **The visibility and clash rules** (the upgrade pass's batch reviews): every addition where the
  camera lands, one unmistakable step a level, restraint, animation that never drops; no moving
  part crossing another or the body over its whole motion, a sunk pivot the one allowed contact,
  checked by the `model_clash` scenario (`docs/reference/art-style.md`, **The visibility rule**,
  **The clash rule**).
- **A model's reach is measured per axis**: its extent in x and in z separately, a spinning
  part's as its pivot's offset plus its sweep in each axis, so a round off the centre along a
  diagonal is not over-counted (`docs/reference/art-style.md`, **Budget and checks**).

### 3.2 Open

- **Economy validation on the server.** Either port the small economy rules to TypeScript,
  checked against shared golden test cases, or run headless Godot for that too. Decide in step 5.
- **The name.** "Space Game" is a placeholder.
