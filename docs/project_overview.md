# Space Game — project overview

Last updated: 2026-10-25. Snapshot taken when Milestone 2, the offline game, was built (main at
a607432): every step from the humanoid study to the retune landed between 2026-10-24 and
2026-10-25 under the owner's mandate that the coordinator decide for the milestone.

This file answers three questions: what the project is meant to become, how far along it is, and
what has been decided. It is written for a human reader and for an AI agent picking up the
codebase.

It is a summary, not the reference. The design the roadmap builds towards (the fantasy, the
loops, the pillars, the milestones) is in `docs/vision.md`. The reference files under `docs/reference/` and the code's
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
2. **Expeditions (PvE)** — fight the battle sim against rival outposts generated from a seed on
   a sector map (buildings from the player's own roster, loot deposits, hazards), and bring the
   loot back into the base. Offline, on the local save.
3. **Attacks (async PvP)** — the same battle against other players' saved bases, which defend
   themselves with AI, through a server that replays the deterministic sim to verify the result.

Between them sits the army: machines crewed by humans, with some autonomous machines, trained
in the base. Later: a server (accounts, base storage, command validation, replay verification),
matchmaking, an attack log, revenge and shields, then alliances. The design of each loop is in
`docs/vision.md`.

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
| Catalog and game data | Built | `data/rules.json`, `data/buildings.json`, `data/units.json`; validated on load; all numbers ints |
| Building roster | Built | 33 types: the Command Center (levels 1–10) and 32 more in four build-menu categories, each with the levels and counts of the upgrade pass's level map (`docs/plans/upgrade-pass.md` §3), every level of every type modelled (259 models); metal, crystal and antimatter (from CC 4); one development-scale curve, checked by tests for affordability and for never going down; the build menu has a tab per category |
| Tiers | Built | Each level's theme by the Command Center band it unlocks in (its `requires_cc`; the Command Center's by its own level): Base, Gold, Chrome, Obsidian and Crown, so a maxed base reads black and gold with violet cores, crowns and escorts (`docs/reference/art-style.md`, **Tiers**) |
| The field | Built | 48×48 cells (`data/rules.json`), the start layout at its centre, inside the perimeter (kerb, pylons, hologram fence) and the terrain ring; the debug build's template base lays out every type at its Command Center 10 count in 46 of its 48 rows |
| Base state: place, move, upgrade | Built | Commands through `BaseState.apply`; `check_*` for the UI; error codes |
| Timers and builders | Built | Construction and upgrade timers; drone bays supply builders; instant builds skip the builder check |
| Economy | Built | Per-hour integer rates; remainders carried in resource-seconds; storage caps; busy buildings don't produce |
| Command Center gates | Built | `requires_cc` per level; `max_count` per CC level |
| Grid occupancy | Built | `BaseGrid`; footprints; a move may overlap its own old spot |
| Seeded RNG | Built | `SeededRng`, xorshift32; sequence frozen by test; used for scenery today |
| Save and load | Built | `user://base.json`, version 6 (records the field, the army, the last five raids, the expedition sector and the abilities; a version 1 base is centred on a grown field, a version 1 or 2 base loads with no army, a version 1 to 3 base with no raids, a version 1 to 4 base with a sector seeded from its saved time, and a version 1 to 5 base with no abilities); offline progress on load; buildings that no longer fit are dropped |
| Camera | Built | Fixed isometric orthographic; pan, pinch and wheel zoom; focus clamped to the grid |
| Touch input | Built | Tap, drag, two-finger pinch and pan; trackpad gestures; HUD gets touches first |
| Placement | Built | Ghost with valid/invalid footprint, Place/Cancel; select; drag the selected building to move; walls painted by tapping and dragging until Done; the camera scrolls while a drag nears the screen edge |
| HUD | Built | Resources and drones (a resource appears once the base can store it), build menu with category tabs and entries showing cost, count and why one is unavailable, place bar, info panel with every stat and the next level's, toasts, debug reset; laid out inside the safe area |
| Visuals | Built | A pulp sci-fi comic style: three-band toon light with cool halftoned shadows from one warm key light, ink outlines, a material kit of twenty texture layers generated by `tools/gen_textures.gd`; models per type and level built in code onto the kit, every level of all 33 types built in the comic style by the model passes and the upgrade pass, in five tiers (`docs/reference/art-style.md`); walls drawn as one merged mesh in which neighbours join (corners, T-junctions and crossings close); scaffold while building, with a builder drone flying round every busy site and cutting at it with a laser; a seamless levelled field of regolith with inked craters, pebbles and cracks and a grid shown only while building, ringed by a perimeter of a concrete kerb, lamp-topped pylons and a low hologram fence; a seeded landscape round it of ridged dunes, craters, mesas and a dry channel, smooth shaded with inked ridges and drawn with the field's marks, wind ripples and inked rock strata, with chamfered rocks and glowing crystal outcrops |
| Tests | Built | Own headless runner; fixture catalog; one test file per core area |
| Tooling | Built | Gate script, landing script, behaviour harness (`tools/`), API dump |

The numbers in `data/` are the retune's real timers and economy (`docs/plans/retune.md`). A debug
build makes them fast:
every level is free and builds in one second at most, and every unit trains and researches free
in one second at most (`Catalog.apply_dev_cheats`; `-- --no-cheats` for the real numbers).

### 2.2 Roadmap

| Step | What | Status |
| --- | --- | --- |
| 1 | Offline base: placement, timers, economy | Built |
| 2 | Base polish: the building roster, build-menu categories, a third resource (antimatter), low-poly models built in code, HUD category tabs, safe-area margins for notches, painting walls by dragging, edge auto-scroll while dragging | Built |
| 2a | The upgrade pass (`docs/plans/upgrade-pass.md`): the Command Center and every type to Command Center 10 (ten levels for the staples), the five tiers, 138 new level models with Crown escorts, the 48×48 field with a version 2 save migration, the maxed base measured | Built |
| 2b | The model feedback pass (`docs/plans/model-feedback.md`): the owner's review of every max-level model folded in: no robot above defence buildings, every robot tailored to its building (a security bot, an ore hauler, a collector, a marshaller, welders), one slow lightning crackle, rising smoke, the Command Center's broader base, the academy and fabricator reshaped, the mortar's plasma and the orbital cannon's spire | Built |
| 3 | Milestone 2, the offline game (`docs/vision.md` §7) — the figures and the army: the humanoid design study (a human in a spacesuit and a humanoid robot, in the comic style, rendered for the owner to approve), then the unit roster in data, training queues, Hangar housing, Research Lab upgrades and unit models | Built: the humanoid study is built (`Figures`, the `figures` harness scenario) and approved at 3.5 heads; the figures' thinner ink line is built (`Figures.FIGURE_INK`); the army is built in core (`docs/reference/core-economy.md`, **The army**): eleven unit types in `data/units.json`, a training queue per producer building, Hangar housing, Research Lab levels, save version 3; the training HUD is built (`docs/reference/hud.md`, **Army panel**: Train and Research from the info panel, unit cards with drawn glyphs, the queue strip, the army meter, its housing later moved off the top bar into the training panels; the `train_units` harness scenario); the unit models are built (`UnitModels`, one per type, the tier as palette; the `unit_gallery` harness scenario; `docs/reference/art-style.md`, **Units**) |
| 4 | The battle sim in `src/core/battle/`: fixed-point integer positions (1 cell = 1000 units), fixed tick, pathing round and through walls, targeting, defences, traps, status effects; replay = seed + layouts + deploy commands; byte-identical results tested headless; batch simulations for balance; the result applied to the base (`raid_result`) | Built (`docs/reference/battle.md`): 20 ticks a second, the deploy zone opening as buildings fall, every special and trap, loot by storage, save version 4 keeping the last five raids, the `battle` harness scenario and `tools/sim_battles.gd`; a full battle simulates in 0.15 to 1.6 s headless on the development Mac |
| 4b | Abilities: `data/abilities.json` (a repair swarm, an EMP burst, an orbital strike), made in the Nanite Foundry as a timed queue with a stock, their effects in the battle sim, spent through `raid_result` | Built (`docs/reference/core-economy.md`, **The Foundry**; `docs/reference/battle.md`, **Abilities**): three abilities of five levels, the Foundry's making queue and its stock capped by its `capacity`, ability levels researched in the lab's one slot, the swarm, the burst and the strike in the sim, the spend through `raid_result`, save version 6, a strike in the `battle` harness scenario and `--abilities` in `tools/sim_battles.gd`. The Foundry's making page, the abilities' research cards, the attack HUD's abilities bar and the effects in the battle view (`hud.md`, `battle-view.md`), the `make_abilities` harness scenario and the abilities in `battle_view` |
| 5 | The battle view: units moving, projectiles, damage and destruction, the attack HUD; the phone target fixed, and the maxed base and a full battle measured on it | Built (`docs/reference/battle-view.md`, `hud.md` **Battle HUD**): the sim driven at its tick with interpolation, units from one MultiMesh pair a type with a shader gait, flash and death, shots, shells, lightning, impacts, rubble, shields, the attack HUD with tap and smear deploys over the red zone, End and the result panel, the debug Practice raid; the phone target fixed (§3.1). On the development Mac, the maxed template base and a full army at the widest zoom: 557 draw calls with the attack HUD and the abilities bar and 1.9 million primitives after the performance and UI passes (974 and about 1,045, 2.0 million before them), 1.6 to 1.9 ms render CPU and 155 to 185 fps as measured before them; the sim's step 0.2 to 0.5 ms a tick on average. The phone measurement stays with the owner |
| 6 | Expeditions: the sector map, the outpost generator (the player's roster with a faction tint, loot deposits, hazards), loot into `BaseState` through a new command, re-training; then the real-timer retune (6a). Milestone 2 complete: a game that plays end to end offline | Built. The retune (6a, `docs/plans/retune.md`): real build, training, research and making times, prices and production tuned to the pace of `docs/vision.md` §5, a 3 h scan, the units' battle stats set so a full army beats its level's fields, measured with `tools/sim_matrix.sh`. Core built (`docs/reference/expeditions.md`): the sector of six fields (two easy, two even, two hard) derived from a seed, the `scan` command on a cooldown, the outpost generator (walled compound, defences, collectors, deposits and hazards outside the walls, traps; loot sized to the player's capacity), `raid_result` clearing a field with a star, save version 5, the `expedition` harness scenario and `tools/gen_outposts.gd`. Built with the UI: the Expedition button and the sector map with its field cards, Scan and a field's detail with the outpost's minimap (`docs/reference/hud.md`, **Sector map**); the battle against the outpost drawn as a rival colony with the faction tint in its field's landscape, its result applied through the controller with toasts, the map reopened (`docs/reference/battle-view.md`, **Expeditions**, **The faction tint**); the `expedition_flow` harness scenario. |
| 6b | The performance pass (`docs/plans/performance-pass.md`): the Mac measured fast (the `profile` and `model_audit` harness scenarios, a code inventory, the sim's slow ticks traced) with approximations for a mid-range phone, then eight series: the sim's search budget in cells, the battle view's buffers uploaded only on change, idle building parts folded into their meshes and moved in the vertex shader, the base's once-a-frame redraw with `buildings_revision` and the pictures built off the main thread, the models' defects fixed and their unseen triangles trimmed, the hold on per-building material copies | Built: the maxed base at the widest zoom from 1,198 to 615 draw calls, the once-a-second spike from 4.5 to 0.15 ms, the sim's slowest tick from 2.3–3.3 to 1.2–1.3 ms, body triangles down 9.5% with no visible change; the UI pass followed (6c) |
| 6c | The UI pass (`docs/plans/ui-pass.md`): every surface shot and critiqued against the comic world with the phone's measure (1 vpx about 0.09 mm), the drone meter picked by the owner from five rendered candidates, the theme foundation (nothing under 17 px, controls 56 px and primaries 72, ink outlines only over bright fills or the world, gold spends and orange raids with cyan for selection only, pill-and-coin meters on one strip, card plinths, chips and coin cost rows, locked cards kept visible) with three skins rendered on the same screens, then the icons as emblems on coins, the drone pill, the attack HUD's visible stars and result ceremony, the sector map's scan plates, the army and info panels, the queue and the toasts | Built: nothing under 17 px or under 56 px in play, the attack HUD's own draws 69 → 54 mid-battle and 82 → 60 on the result, the sector map's opening frame 13.4 → 6.7 ms, the build panel's draws unchanged; skin A chosen by the owner on 2026-10-29 (B and C deleted); sound follows |
| 6d | The sound pass: every sound effect generated in code at build time (`tools/gen_sounds.gd` from the recipes in `src/game/sounds.gd`, friendly comic synth, checked for peak, DC, clicks, silence, length and loudness), played by the `Audio` node (24 voices, buses, cooldowns, priority, loops, scheduled plays, music crossfades, stings, volume settings); free music chosen separately (`docs/reference/audio.md`) | Started: the audio foundation and the first sounds; the music (Gravity Turn, calm for the base and action for battle, crossfaded); the UI and base: every tap by its kind, the panels, the toasts and a refusal's buzz, placing and moving, a building tapped by its category, completions (construction, training, research, making), a meter filling, the boot's sting, the construction laser, the base's ambience, the sector map's sounds, and the settings gear (Music, Sound, Mute); the battle's sounds (every weapon's shot and landing, the hits, falls, deaths, traps, shields, EMP, gravity well, abilities and deploys, the attack HUD's, generated victory and defeat stings, the battle's bed and loops) |
| 7 | Milestone 3, the online game — the server: Nakama with accounts, base storage, migration of the local save and command validation; battles verified by replaying them in headless Godot running the same `src/core` | Planned |
| 8 | Async PvP: matchmaking, attacking saved bases, a defence log with replays, shields, revenge, a league ladder | Planned |
| 9 | Milestone 4, the social game — alliances through the Alliance Beacon: membership, donations, later wars; then a distinct PvE faction and the store release | Planned |

### 2.3 Known limitations

- **The local clock is trusted.** Time comes from the device; changing the device time can cheat
  today. The server will own time (step 5).
- **Models are built in code** (`BuildingModels`, from `LowPolyMesh` parts painted from the
  generated material kit); imported models in `assets/` may replace them later, keeping the
  model contract in `docs/reference/art-style.md`.
- **The save is local, at `"version": 6`** (five migrations: version 1 bases are centred on the
  grown field, version 1 and 2 bases load with no army, version 1 to 3 bases with no raids,
  version 1 to 4 bases with a sector seeded from their saved time, and version 1 to 5 bases with
  no abilities); the server will hold the base
  later and nothing below `main.gd` changes.
- **Phones are unmeasured.** The phone target is fixed (§3.1) and the maxed base and a full battle
  meet its Mac proxies (the template base in the profile scenario 1,198 draw calls at the widest
  zoom before its idle parts moved into the shaders, 615 after, and 1.65 million primitives; a
  battle on it with a full army 532 and 1.75 million at tick 200, `docs/reference/art-style.md`, **Cost**), but
  no phone has run them: the measurement needs a device and stays with the owner
  (`docs/reference/testing-tools.md`, **Measuring on a phone**), and it decides whether the Crown
  robots stay and what the unit budgets are. The sim's slowest tick is about 1 to 1.5 ms on the
  Mac since the search budget in cells (§3.1), under the 5 ms a tick proxy. A tick of scripted
  deploys still costs about 8 µs a unit, 1.5 to 2 ms for a wave of 260 in one tick; the view sends
  deploys live, outside the step, so only a setup's commands pay it (`docs/reference/battle.md`,
  **Determinism and performance**).
- **The balance is modelled, not played**: the retune (`docs/plans/retune.md`) sets the pace
  from a model of maxing each Command Center level (four raids a day, builders busy 75% of the
  time) and the beatability of the expedition fields from scripted attacks without abilities;
  no player has played it through. A maxed base holds well against a maxed army: on the template
  base the three edge strategies reach 16 to 22% mean destruction, a scattered deploy into its
  open pockets about 50% and two stars on about four seeds in ten, which Milestone 3's PvP has to
  weigh.
- **The template base fills 46 of the field's 48 rows** at the Command Center 10 counts, so more
  walls or another type at the top needs its layout reworked (`docs/reference/input-camera.md`).
- **`capacity` is display-only on the Alliance Beacon**; on the Hangar it drives the army's
  housing and on the Nanite Foundry the ability stock's cap.
- **The unit budgets are study values** until the phone measurement; the units articulate on the
  vertex-shader rig (legs, arms, wheels, guns, banks and bay doors: `docs/reference/art-style.md`,
  **Rig**), whose cost on a phone is unmeasured with the rest.

## 3. Decisions

The owner asked, on 2026-10-24, that the rest of Milestone 2 be built without questions. Every
product call the coordinator made under that mandate is a bullet below marked "the coordinator
under the owner's mandate"; those bullets are the owner's review list for the milestone, and
any of them can be reversed as a data or model change.

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
- **The six calls that open Milestone 2** (the owner, 2026-10-24; `docs/vision.md`): the army
  is mostly machines piloted by humanoids, with some autonomous machines, so humans and humanoid
  robots are figures of the game and the humanoid design comes first; battles use Clash's
  control model (deploy at the edge, units act on their own, a few abilities from the Nanite
  Foundry); an expedition is a battle against a generated outpost, so the battle sim precedes
  expeditions; the PvE enemy of Milestone 2 is rival colonies built from the player's roster
  with a faction tint; offline first, with no PvP in Milestone 2; a premium currency slot in the
  economy design, nothing sold until PvP exists.
- **The earlier figure is rejected** (the owner, 2026-10-24): the all-box trooper and cadet read
  as a blocky toy ("a Roblox character"); a figure has to read as a character in the comic
  style, and the humanoid design study replaces them before any unit is modelled.
- **The figures' proportion and ink** (the owner, 2026-10-24, on the study's renders): every
  figure is 3.5 heads tall (`Figures.PRIMARY_HEADS`), and figures carry a thinner ink line than
  buildings, since at the gameplay zoom a figure is about 25 px tall and the full 2.2 px line
  swallowed it. The study's colonist and automaton are approved as the base of every unit and
  crew figure.
- **The army's rules** (the step 3 plan, 2026-10-24): a training queue per producer building,
  trained while it is idle; the army's housing is the sum of every Hangar's `capacity` (20 at
  Command Center 1, 280 at 10); units in training are not housed, and the army plus every queue
  must fit the housing, revisited when battles spend units; a cancel refunds what was paid; a
  unit's level belongs to its whole type, researched one at a time at the Research Lab, which
  keeps researching while it upgrades. `crew` is flavour: the Cadet Academy trains the human
  units, and a piloted machine needs no trained colonist. The roster's names and numbers are
  provisional until the owner has seen them.

- **Deployed units are spent** (the owner, 2026-10-24): every unit deployed in a battle is
  gone afterwards and the rest come home, Clash's model, so training is the steady drain that
  expeditions pay for. The step 4 battle sim and its result command apply it.
- **The roster stands** (the owner, 2026-10-24): the eleven unit types of `data/units.json` keep
  their names and roles; numbers stay development-scale until the retune.
- **The coordinator decides for the rest of Milestone 2** (the owner, 2026-10-24): "work
  independently and stop asking me questions for the duration of Milestone 2 ... stick with the
  correct art style and common sense." Product calls that would otherwise go to the owner are
  made by the coordinator, recorded here with that note, and the owner reviews them after the
  milestone.
- **The unit models** (the coordinator, 2026-10-24, under the delegation above): one model per
  unit type in the comic style on the approved figures, its tier changing only its machine's
  paint as the buildings' tiers do (cream, chrome, then obsidian with violet veins; the trim and
  the glows with them; a level's tier the band of the Command Center level its Research Lab level
  requires);
  humans in machines are the colonist seated, under the figures' thin ink; hovering and flames are
  surface flags, with no moving part (the gunship's rotors are spun by the shaders, step 5); budgets are study values
  until step 5. The glass stays opaque, so a pilot sits sunk behind its windscreen with its helmet
  showing over it rather than behind a see-through canopy, which would cost a draw a unit (the
  developer's call, for review; sunk by the vehicle model pass).

- **The battle sim's rules** (the coordinator under the owner's mandate, 2026-10-24; the step 4
  plan; `docs/reference/battle.md`): a surrender command ends a battle on its tick and is logged
  like any command; the sim draws no random number, and its seed is kept for later rules; a
  wall cell costs a ground unit's path a fixed 8,000 units (eight cells) from the data, so a
  short detour is walked and a long one broken through; defences keep their target while it is
  alive and in range; the buildings' battle classes are hq, wall, trap, defense (a type with
  `targets` or a range), resource (with `produces` or `storage`) and other; a collector's loot
  weight is one hour of its production; abilities are step 4b; the base keeps its last five
  raids in save version 4; the battle tools may read the wall clock, the sim never does; the
  sim has a reference file of its own; the deploy zone (every footprint, walls in, grown by one
  cell) opens as buildings fall, cell by cell, and traps stay out of it, so a deploy on a trap's
  cell is allowed and sets it off.

- **Abilities** (the coordinator under the owner's mandate, 2026-10-24; the step 4b plan;
  `docs/reference/battle.md`, **Abilities**; `docs/reference/core-economy.md`, **The Foundry**):
  three abilities in `data/abilities.json`, each with an `effect` (swarm, emp, strike) the sim
  runs, so it never keys on an id; `rules.army.foundry` names the making building; the Foundry's
  queue is a `TrainingQueue` reused unchanged, its `units` holding ability ids; the stock is by
  id and carries no level, capped in total by the Foundry's `capacity` (2 to 6), the queue limit
  the capacity as housing is the training's; ability research is `{"op": "research", "ability"}`
  in the lab's one slot, `research_ability` beside `research_unit` sharing `research_done_at`;
  the repair swarm heals every unit in its radius each tick for its duration; the EMP burst
  disables every defence whose centre is in its radius, a disabled shield generator neither
  recharging nor counting its delay while its pool still absorbs; the orbital strike lands after
  its delay on buildings and walls, hidden ones without revealing them, traps left out, through
  the shields, and on the attacker's own units too (friendly fire, the comic and tactical
  choice); effect times are floored to ticks; a battle with no unit standing goes on while an
  ability is left or a strike is on its way; `raid_result` spends `abilities_used`, which must
  match the battle's ability commands; save version 6; an expedition's setup brings no abilities
  until the HUD wiring; the numbers are development values (retuned in step 6a).
- **The abilities' HUD and effects** (the coordinator under the owner's mandate, 2026-10-24): the
  Foundry's making page and the abilities' research in the army panel, ability glyphs drawn by
  effect (no pictures), an abilities bar beside the deploy bar whose selection lets the unit type
  go, a cast anywhere on the field, the effects drawn from the sim's events (a swarm's dome, an
  EMP's ring with its defences dimmed, a strike's crosshair, blast and smoke), and the stock
  carried into a battle's setup (the practice raid's, and `OutpostGenerator.battle_setup`'s
  optional abilities for the sector map's).
- **The phone target** (the coordinator under the owner's mandate, 2026-10-24): a 2021 mid-range
  Android (Snapdragon 695 or Dimensity 700 class, 6 GB, 1080p) and an iPhone 11 as the floor; at
  least 30 fps in battle at the widest zoom with a maxed outpost and a full 280-housing army on
  screen, 60 fps the target in the base view. On the development Mac the proxies are the Cost
  ceilings (1,600 draw calls, 2.1 million primitives, 6 ms of render CPU a frame) and the sim's
  step under 5 ms a tick. The phone measurement needs a device and stays with the owner
  (`docs/reference/testing-tools.md`, **Measuring on a phone**).
- **Expeditions in core** (the coordinator under the owner's mandate, 2026-10-24; the step 6
  core plan; `docs/reference/expeditions.md`): the sector is renewable: six fields from
  `(sector seed, epoch, index)`, a field raided once an epoch (a star clears it, none leaves it
  open), a `scan` starting the next epoch on a cooldown from the last, the first free (epoch 0);
  the sector seed comes from the base's creation time, or a migrated save's `now`; the fields are
  laid out against a snapshot of the player's Command Center level and capacity taken at each
  scan (and at creation and migration), not the live base; `check_raid_result` lays the field out
  again and compares the battle's seed and defender as sorted-key JSON after `Catalog.ints`; no
  expedition cost in this step (a `rules.expedition.cost` slot is the retune's); deposits and
  hazards come out of the outpost's counts; the field count is the sum of the bands' `fields`;
  the raid log keeps an expedition's battle without its defender, with the field's inputs; a
  catalog without `rules.expedition` has no fields and `scan` still works; the hard band's
  density is 85% of `max_count`, a density that lays out with nothing dropped on every seed tried;
  drops begin around 88%.

- **The retune** (the coordinator under the owner's mandate, 2026-10-24; step 6a;
  `docs/plans/retune.md`): one data-only pass sets real timers and a tuned economy to the pace of
  `docs/vision.md` §5 (Command Center 3 in about half a day, 7 by day 16, 10 by about day 80);
  build times by a per-Command-Center curve up to 40 hours a top level and 66 hours for the
  Command Center's level 10, nothing above three days (a shipped-data test); prices from Command
  Center 5 up scaled by a factor per level (×0.55 to ×1.5), the walls included as the late sink;
  production generous early and about half the income from Command Center 7 on, the raids the
  other half; storage, counts and unlocks unchanged; training ×6 and priced at 5 to 8% of the
  crystal storage per full army; research 15 minutes to a day; abilities made in minutes; a 3 h
  scan; `rules.premium` reserved and unused, the timers chosen with a ten-minute skip in mind.
  The beatability lever is the units' hull and damage, a factor per Command Center level, not the
  defences (which defend players' bases in PvP) nor the bands; it is judged with the `edge`,
  `two_edges` and `waves` strategies of `tools/sim_battles.gd` (`random` reported only) through
  `tools/sim_matrix.sh`, and the model assumes four raids a day at about 17% of the storage,
  builders busy 75% of the time. No expedition cost is added. The scripts that applied it stayed
  in the developer's scratch directory; the plan states every rule they used.

- **The expedition flow and the faction tint** (the coordinator under the owner's mandate,
  2026-10-24; `docs/reference/hud.md`, **Sector map**; `docs/reference/battle-view.md`,
  **Expeditions**): an Expedition button at the bottom left of the base HUD, opposite Build, with
  a badge of the open fields, opens the sector map, a full panel over the base: six field cards
  (the band as a word and a colour, the outpost's Command Center, the loot targets; a cleared field
  stamped and dimmed), Scan with its countdown, a hint to scan when the Command Center has grown,
  each card with a thumbnail of its outpost (the six laid out on worker threads when the map
  opens, kept per epoch), and a field's detail with a minimap of its outpost and Attack (refused with no
  units). The battle
  takes the field's seed for its landscape and its result is applied once through
  `PlacementController.raid_result` with the expedition key, with toasts, and the map opens again.
  The tint makes a rival colony a green faction at every tier: a `rival` uniform on the toon
  shader turns the army orange teal, the core gold a verdigris green-gold and the violet roles
  (antimatter, the veins, the cores, glows included) emerald, and cools the cream hull, leaving
  chrome, obsidian, glass, ink, the hazard stripes and the ground alone; hues tuned on the sRGB
  vertex colour; through two shared materials (`MaterialKit.rival`, `hit_flash_rival`) on the
  defender's buildings and walls only, never on the units, outlines, rubble or the base, and
  never in a practice battle; no material per building.

- **The model and animation pass, the model phase** (the owner's ask of 2026-10-25, the calls
  the coordinator's; `docs/reference/art-style.md`): reviewing the Milestone 2 renders the owner
  judged the models decent but not good enough and the animation "really bad", and asked for a
  long pass, models first, then every animation, each verified from frames to a high standard;
  projectiles must be specific to their source (a missile battery fires missiles) with the right
  lights, models and explosions. Two art critiques (units and figures; buildings) set the standard
  and the fixes, and the model phase landed them (vehicles and aircraft, figures and infantry,
  defences, core and resources, army; main d595cbd): the category accent on at least a quarter of
  what the camera sees, on a big part, never on trim; no hull-mid main mass; nothing structural
  under 0.14 across on new or reworked models (`Parts.STRUCTURAL_MIN`, the post family); Gold on a
  part, an Obsidian level keeping its accent surface, Crown filigree only on bands 0.1 or taller;
  a camera-facing deck plate on every machine; pilots sunk behind framed canopies; a per-part
  figure ink (0.75 on the big masses, 0.5 on limbs); red on a big part of every defence; the
  halftone coarsened to a print screen (7 px, 25%, 0.08) after a measured pair; the academy's
  cadet rebuilt as a hologram on the colonist (the box figure stays rejected); the jet flames
  fixed as fire colours at every tier. Judged at the overview zoom first. The animation phase
  that follows rests on three calls: rigid-part animation in the vertex shader rather than
  skeletons (per-vertex channels with pivots, a channel table mirrored in `src/game/rig.gd`,
  instance state in INSTANCE_CUSTOM; GLES3 skinning is slow and a MultiMesh cannot be skinned),
  sockets on models with defence heads aimed as the mover holding the `muzzle` socket
  (`BattleSim.building_target`, the only core change, a read), and a weapon table in the view
  (`src/game/weapons.gd`) with one projectile, muzzle effect and impact per type. Every series
  ships frame strips (`tools/harness` `strip()`, the `anim_*` scenarios) that the coordinator and
  the reviewer read; a series whose frames do not read fails. The owner's review list: the
  halftone, the hologram cadet, the structural rule, the rival-tint-neutral flames, and the
  animation architecture.

- **The model and animation pass, the animation phase** (the coordinator, 2026-10-25;
  `docs/plans/model-animation-pass.md` §3): rigid-part animation in the vertex shader rather
  than skeletons (`src/game/rig.gd`, the channel table mirrored in the shaders, the instance
  state in INSTANCE_CUSTOM, deaths by class in the instance transform); sockets on models with a
  defence's aiming part the mover holding its `muzzle` socket, turned toward
  `BattleSim.building_target` (the only core change, a read) with a per-type rate and a
  fire-driven kick, movers frozen while EMP-disabled, the sentry fading in on reveal; a weapon
  table in the view (`src/game/weapons.gd`) with one projectile, muzzle effect, impact and death
  kind per type, traps drawn when sprung, buildings collapsing into rubble, blasts standing off
  the face they hit, scorches fading, the shield never vanishing; every building's idle made to
  read and every dish on one speed. The owner's review list is §4 of the plan record.

- **Aircraft fly higher and defences pitch their barrels** (the coordinator, 2026-10-25, after the
  owner asked that "some of the defenses also need to have their barrels tilt up and down to angle
  towards what they're shooting at"; `docs/reference/battle-view.md`, **Aim and muzzles**, **Units**):
  every direct-fire defence elevates its barrels toward its target's drawn height and the lobbing
  guns by range, with honest geometry (no view-only floors): the laser, flak and sentry barrels pitch
  as riders while the dome, carriage and radar stay level; the missile launcher, railgun rails, ion
  emitter and mortar barrel pitch whole; the orbital's gun rides a yawing mount with its fire-control
  spire behind the breech. The clash check sweeps every pitching part across its whole travel. Since
  the anti-air guns' trunnions sat at the aircraft's drawn height, aircraft now fly higher in battle
  (`BattleUnits.FLIGHT_MIDDLE`: jet trooper 1.5, skimmer 2.0, gunship and bomber 4.0 units), view
  only, the sim untouched; the top-level flak and ion still sit near level against a gunship holding
  at range, and the lever is that table. Reversible as data: the limits and lob spans in
  `battle_view.gd`, the heights in `battle_units.gd`.

- **The owner's three corrections after the pass** (the owner, 2026-10-25; `docs/reference/hud.md`
  **Army panel**; `docs/reference/art-style.md`, the Command Center's row; `docs/reference/battle-view.md`,
  **Vortices**): the army's housing leaves the top bar, which holds the resource meters and the drone
  ring only, and shows as "Housing used / capacity" with a bar in the training panel's header and as a
  line on the training facilities' info panels (the Cadet Academy, Drydock, Fabricator and Heavy
  Fabricator), "No Hangar: build one to house units" while the capacity is 0; the Command Center's
  dome never overhangs the storey it rides at any level (`dome_fit`, checked in the gallery), and from
  L7 the tower and base are broad with the dome a cap, which reverses the critique's growing dome; the
  gravity well's hold is a vortex (a same-handed double helix in a soft gradient sheath with bands
  scrolling toward the well, rings sliding along it, a tightening ring at the aircraft and one glowing
  source per well), after a counter-twisting version read as a diamond lattice. The HUD principle
  recorded: a capacity that belongs to a building family shows in that family's panels, not the top
  bar.

- **The search budget in cells** (the coordinator, 2026-10-27, for the phone's frame; the owner
  asked for performance across the codebase for a 2021 mid-range phone; `docs/reference/battle.md`,
  **Pathing**): the ground units' path searches settle at most `rules.battle.search_cells` = 300
  cells a tick between them, one search in flight at a time, cut short and going on next tick,
  the waiting units served in id order, replacing four searches a tick. A search in flight goes
  on over a fall rather than starting again, which could starve while buildings fall every few
  ticks. It bounds the searches' share of a tick to about 0.45 ms on the Mac and moves when units
  start walking: a whole army deployed on many cells of a sparse outpost at once waits 2 to 3 s
  for its last groups' paths. Two refactors with it change nothing a battle does: an air unit's
  pick reads its set's members rather than every building, and a search for a set with nothing
  standing is not run. Reversible as data (`search_cells`).

- **Idle building parts move in the vertex shader** (the coordinator, 2026-10-27, the performance
  pass; `docs/reference/art-style.md`, **Folded parts**): a building's moving part that moves on the
  clock alone (no socket, riding nothing and ridden by nothing, no marching figure) is folded into
  its body and outline at build time and moved by the shaders from per-vertex motion data (`CUSTOM0`,
  `CUSTOM3`) with `Motion`'s exact math, at the same pose at the same clock as the node it replaces;
  the rotor of the gunship moved onto the same path. What stays a node is what needs the view's
  state: the aiming heads and what rides them, and the marching figures (198 of the template base's
  257 moving parts fold, 59 stay). Busy and EMP-disabled buildings hold their folded parts by
  wearing their own copies of their materials on move shaders with the hold time set (`move_hold`, a
  plain material uniform), made as they hold and when their state changes while held, never a
  frame; the few held buildings pay a material copy per surface. Holds no longer rely on instance
  uniforms: the first version used one, but every instance on such a shader takes 16 vec4s of a
  global buffer that fits 255 of them on the Mac and fewer on a phone, kept until the instance is
  freed, so the maxed base ran out and holds silently failed. On the Mac the maxed base fell from
  1,198 draw calls to 615 at the widest zoom and its frame from about 7 ms to 5, for 21 MB more video
  memory; moving parts were two thirds of the draw calls, the first thing a phone would have broken
  on. The video memory is accepted for now; the phone measurement decides between two
  follow-ups: `CUSTOM3` as half floats (with a precision check), or the folded parts in a second body
  surface (about three more draws a folded building, the channels on their vertices only).

- **The HUD's rules** (the coordinator, 2026-10-27, the UI pass; `docs/reference/hud.md`, **Theme**):
  the HUD is authored at 720 virtual pixels tall under `canvas_items` stretch with `aspect` `expand`,
  so on a 6.1-inch phone 1 vpx is about 0.09 mm; from that, nothing under 17 px, every control the
  player taps in play at least 56 px tall and the primaries 72, ink outlines on text only over a
  bright fill or over the world, and colour roles (gold spends: Build, Place, Upgrade, Attack, Return;
  army orange raids: Expedition; cyan selects or confirms the safe choice; defence red stops: End, a
  defeat, a refusal's edge). Cards share one anatomy: the picture on a plinth of the category's
  colour, chips for counts and levels, cost rows with the resource's coin, a locked card desaturated
  with a lock chip and never a 55 % fade. The meters are pills with the icon on a coin, on one strip,
  with a gold full state; the glint stays but rarer and fainter (the owner likes motion). The ability
  icons are emblems with mass on coins, not rendered stills of the effects (a frozen translucent
  ring reads worse than an emblem). The sector map's thumbnails are stylised scan plates (one
  polygon for the compound, a diamond, discs and squares, a ribbon and a chip); a rendered outpost
  picture is worth it only for the detail view's 480 px, later. The attack HUD keeps its own
  variations as the dark in-field family under every skin. The debug row is demoted to grey chips
  but stays one tap away. The difficulty words are the owner's.
- **The drone meter** (the owner, 2026-10-27): from five candidates rendered in the real top bar (a
  bold ring with a count badge, dots around the icon, a pill with a slot per drone, an icon card with
  a count badge, a row of drone glyphs) the owner picked the pill with slots and "2 / 5" in the
  meters' language, with the construction drone seen from the front as its icon; the ring is gone.
- **The HUD skins** (the coordinator, 2026-10-27): three directions were rendered on the same five
  screens: A, the same comic console executed properly; B, A with the world's two-band fills and
  halftone as printed 9-slice textures; C, a cream comic page over the world with ink text. A is the
  foundation the other two build on, so it landed as the default and the roll-out went on it; B and
  C stay behind `Hud.Look` until the owner picks, when the follow-up is their deletion or a cream
  pass over the rolled-out surfaces. On 2026-10-29 the owner chose A; B and C were deleted.
- **The music** (the owner, 2026-10-29; `docs/reference/audio.md`, **Music**): from CC0 candidates
  the owner picked "Gravity Turn" by vitalezzz, its calm version for the base and its action version
  for battle, written by the composer to crossfade from the calm into the start of the action. Both
  ship as whole-file, bar-exact Ogg Vorbis loops, the base at -18 LUFS and the battle at -16, under
  the effects; the victory and defeat stings stay generated, no music asset for them.

### 3.2 Open

- **Economy validation on the server.** Either port the small economy rules to TypeScript,
  checked against shared golden test cases, or run headless Godot for that too. Decide in step 5.
- **The name.** "Space Game" is a placeholder.
- **Versioning the battle rules** (Milestone 3): a battle's result depends on the sim's rules
  (the search budget in cells changed when units start walking), and nothing in a raid says which
  rules played it; the server will need to know before it replays a raid.
- **The phone measurement** itself: the target and the procedure are recorded
  (`docs/reference/testing-tools.md`, **Measuring on a phone**); it needs a device in hand.
