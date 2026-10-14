# Space Game — project overview

Last updated: 2026-10-14. Snapshot taken at milestone 1 (offline base), save format version 1.

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
- **Light on the phone.** Fixed orthographic camera, primitive placeholder models, the GL
  Compatibility renderer, no addons, no per-frame allocation.
- **One code path for desktop and phone.** Mouse clicks arrive as touches, so every gesture is
  written once and tested on a Mac before it reaches a device.
- **Agent-editable.** Scenes are built in code and the project is text, so an agent can read and
  change everything; hand-written `.tscn` files stay to one node.

## 2. Status

### 2.1 Built — milestone 1, the offline base

| Area | Status | Notes |
| --- | --- | --- |
| Catalog and game data | Built | `data/rules.json`, `data/buildings.json`; validated on load; all numbers ints |
| Base state: place, move, upgrade | Built | Commands through `BaseState.apply`; `check_*` for the UI; error codes |
| Timers and builders | Built | Construction and upgrade timers; drone bays supply builders; instant builds skip the builder check |
| Economy | Built | Per-hour integer rates; remainders carried in resource-seconds; storage caps; busy buildings don't produce |
| Command Center gates | Built | `requires_cc` per level; `max_count` per CC level |
| Grid occupancy | Built | `BaseGrid`; footprints; a move may overlap its own old spot |
| Seeded RNG | Built | `SeededRng`, xorshift32; sequence frozen by test; used for scenery today |
| Save and load | Built | `user://base.json`, version 1; offline progress on load; buildings that no longer fit are dropped |
| Camera | Built | Fixed isometric orthographic; pan, pinch and wheel zoom; focus clamped to the grid |
| Touch input | Built | Tap, drag, two-finger pinch and pan; trackpad gestures; HUD gets touches first |
| Placement | Built | Ghost with valid/invalid footprint, Place/Cancel; select; drag the selected building to move |
| HUD | Built | Resources and drones, build bar, place bar, info panel with upgrade, toasts, debug reset |
| Visuals | Built | Placeholder primitive models per type, scaffold while building, seeded rocks, grid shader |
| Tests | Built | Own headless runner; fixture catalog; one test file per core area |
| Tooling | Built | Gate script, landing script, behaviour harness (`tools/`), API dump |

Balance numbers in `data/` are fast development values, not tuned.

### 2.2 Roadmap

| Step | What | Status |
| --- | --- | --- |
| 1 | Offline base: placement, timers, economy | Built |
| 2 | Base polish: walls (1x1, drag-to-paint), building info art, safe-area margins for notches, edge auto-scroll while dragging, real low-poly models in `assets/` | Planned |
| 3 | Seeded PvE expeditions: a field generated from a seed with `SeededRng` (asteroids, deposits, hazards); loot returns into `BaseState` through a new command | Planned |
| 4 | Deterministic battle sim in `src/core/battle/`: fixed-point integer positions (1 cell = 1000 units), fixed tick; replay = seed + base layout + list of deploy commands; tested headless against AI-built bases; same inputs give byte-identical results | Planned |
| 5 | Server: Nakama with accounts, base storage and command validation; battles verified by replaying them in headless Godot running the same `src/core` | Planned |
| 6 | PvP matchmaking, attack log, revenge, shields | Planned |

### 2.3 Known limitations

- **The local clock is trusted.** Time comes from the device; changing the device time can cheat
  today. The server will own time (step 5).
- **Models are placeholders** built from primitives (`BuildingModels`); real low-poly models
  come with step 2.
- **The save is local and unversioned beyond `"version": 1`**; the server will hold the base
  later and nothing below `main.gd` changes.
- `hp`, `damage`, `range_cells` and `fire_ms` in `data/buildings.json` are shown in the HUD
  where they exist but drive nothing until the battle sim (step 4).

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

### 3.2 Open

- **Economy validation on the server.** Either port the small economy rules to TypeScript,
  checked against shared golden test cases, or run headless Godot for that too. Decide in step 5.
- **The name.** "Space Game" is a placeholder.
