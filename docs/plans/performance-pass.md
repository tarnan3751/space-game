# The performance pass (2026-10-27)

The record of the pass the owner asked for before Milestone 3: measure on the Mac, fast, approximate the
phone, then make the game cheaper without making it worse. The UI pass and sound were explicitly not
started. `docs/project_overview.md` §3.1 holds the decisions; this file holds the method, the numbers and
what was left.

## 1. The ask and the order

On 2026-10-27 the owner listed four things to improve before Milestone 3: a UI pass, a model pass "focused
on quality, animation, and PERFORMANCE" (bugs and errors in the models, efficiency and polygon count where
the quality is not needed, never making the models worse), sound, and "code compression, efficiency, and
improvements in performance across the codebase". The order agreed: measure (on this Mac only, kept short,
with approximations for mobile), then the performance passes (models and code together), then stop before
the UI and sound steps.

## 2. Method

Four measurement lanes ran in parallel on main `18caa46`:

- **The profile** (`tools/harness/scenarios/profile.gd`, `src/game/profile.gd`): a per-system cost table
  over base at sizes 44/24/10 (with and without the shadow), the sector map, the training panel, and the
  battle at ticks 200 and 1000 at sizes 44 and 24, in a 1600×900 window with vsync off; primitives and
  draws by source; alpha fill; direct calls (`Hud.refresh`, `BaseView.sync`, the `changed` chain, a second
  of production, the save, the sector map's outposts, MultiMesh uploads). Each sample checks the window
  drew at least 99% of its frames, so a stalled window fails the run instead of logging stale numbers.
- **The code-efficiency inventory** (scout, read-only): every per-frame site, the once-a-second work, dead
  and duplicate code, file sizes, stale docs.
- **The model audit** (`tools/harness/scenarios/model_audit.gd`): every model probed by rays for defects
  (brushes in motion, parts below ground, floating pieces, z-fighting, duplicate and degenerate triangles,
  hidden parts) and for triangles the camera never sees, with round parts judged at the closest zoom the
  model is drawn at.
- **The sim's worst tick**: a plan that measured where the slow ticks came from before proposing fixes.

The mobile approximation is a rule of thumb against a 2021 mid-range phone (Snapdragon 695, GLES3): CPU
at a tenth of the Mac, GPU at a tenth to a twentieth, draw calls at 20–100 µs each; the shadow pass adds
depth-only vertex work and the tile GPU's binning pass processes vertices again.

## 3. What the Mac showed (main 18caa46, M5, 1600×900, vsync off)

| sample | frame ms avg / worst | main thread | render CPU | draws (shadow) | kprims (shadow) | video MB |
|---|---|---|---|---|---|---|
| base 44 | 7.06 / 11.8 | 0.56 | 2.13 | 1198 (371) | 1646 (533) | 86.5 |
| base 24 | 5.85 / 14.9 | 0.57 | 1.86 | 980 | 1440 (485) | 86.5 |
| base 10 | 3.60 / 8.4 | 0.49 | 0.82 | 357 | 742 (253) | 86.5 |
| battle t200 44 | 8.26 / 11.6 | 1.25 | 1.95 | 1017 | 1764 (566) | 140.1 |
| battle t1000 44 | 6.39 / 9.0 | 0.90 | 1.61 | 767 (244) | 1303 (410) | 155.7 |

The Mac is GPU-bound: the main thread takes 0.5–1.25 ms, render CPU about 2 ms, and the rest of the frame
is the driver waiting on the GPU, following the visible primitives. Turning the shadow off removed 533k
primitives and 371 draws and left the frame time unchanged, so on the Mac the cost is the main pass's
vertices. The scripts' once-a-second work (`main._on_tick`) took 2.3–7.4 ms: a stutter every second.

Primitives by source at size 44: static buildings 54% (301k body, 284k outline, 301k shadow, 403 draws),
the 240 moving parts 25% (789 draws), walls 14% (3 draws), terrain 5%. Outlines are a third of all
primitives and the shadow another third. Alpha-blended effects cover under 0.1 screens.

Phone approximation for base 44 against a 16.7 ms target: main thread ~5.6 ms, render CPU 21 ms (60–120 ms
by the per-draw rule), GPU 43–86 ms. Battle 44 against 33 ms: 12.5 / 20 (50–100) / 50–100 ms. The scripts
fit; the draw calls and the vertices do not. Ranked levers: moving parts (65% of draws), far-detail
buildings, outlines, the shadow pass, the once-a-second HUD and view rebuild, the sector map and training
panel opening, the battle scripts, the sim's worst tick, buffer uploads, overdraw, texture memory.

The audit found real defects in about a dozen building types and estimated that about 150k of 922k body
triangles (and their outline copies) are never seen: undersides on the ground or on another part, the
inner faces of rings, parts buried inside other parts, round parts with more sides than their size on
screen can show (40,846 surplus triangles at the closest zoom for buildings).

The sim plan found the docs wrong about the slow ticks: most came from air units scanning all 363
buildings for a target (about 165 µs each) and from end-of-battle ground searches flooding the whole field
(16 ms in one tick), not from the path searches `PATHS_PER_TICK` budgeted.

## 4. What was built

Eight series, each reviewed and landed on main the same day, in this order:

1. **The profile tooling** (`ae587ef`): the scenario and `Profile`, the static timer every timed site
   reads once in play.
2. **The sim's tick budget** (`169b0f3`, tier A): air units pick targets from per-set member lists
   (165 → 25 µs); no search runs when a set has nothing standing, and a search in flight is dropped when
   its set empties; ground searches are budgeted in cells (`rules.battle.search_cells` 300) with one
   resumable search in flight, served in id order, continuing over a changed field, covered by the state
   hash. Pinned hashes changed. The `battle` scenario's slowest tick: 2.3–3.3 → 1.2–1.3 ms; the
   outposts' worst ticks 11–18 → 1–1.5 ms; `sim_battles.gd` gained `max_tick_ms`.
3. **The model audit tooling** (`f840845`): the scenario (about 3–4 minutes headless), its marked rendered
   shots, the `projection` kind for holograms and spark effects.
4. **The battle view's per-frame work** (`fd23eab`): buffers upload only when they changed (bars,
   impacts, arcs, shields, scorches; unit types only while they draw), aimer records built at setup, the
   deploy mask set only when it moves; the 30 MB "growth" through a battle was the profile scenario's own
   mesh caches; six shared harness helpers replaced byte-identical copies in 16 scenarios. The battle
   view's CPU stayed at about 0.8 ms (the cost is per-entry script work, not uploads).
5. **Idle building parts move in the vertex shader** (`2214ba6`): time-driven idles (spins about any
   axis, swings, slides) are folded into their building's body and outline meshes as per-vertex motion
   data (CUSTOM0 pivot and code, CUSTOM3 axis and period) evaluated by `effect_move` with `Motion`'s math;
   aimers, pitching riders and their riders, marching figures, rigged parts and socket carriers stay
   nodes; busy and EMP holds through a per-building hold (item 8). 198 of 257 template-base movers
   folded (292 of 417 across every model). Base 44: 1,198 → 615 draws, render CPU 2.25 → 1.5 ms, posing
   0.38 → 0.13 ms; video memory +21 MB (full-float channels on every vertex of a body with a fold;
   accepted, two levers recorded). Pose identity proved by `anim_identity` on a fixed clock: 294 shots,
   217 byte-identical, none at a different pose.
6. **The base's once-a-second spike and the HUD's rebuilds** (`7a21f4f`): one redraw a frame after
   changes (`_on_tick` 4.5 → 0.15 ms; a second's work 4.0 → 1.7 ms); `Hud.refresh` 1.25 → 0.006 ms on an
   unchanged tick (0.86 on a building change) through `buildings_revision` in core and one-pass
   `production_rates()`/`capacities()` (tier A, bit-identical); `BaseView.sync` 0.85 → 0.001 ms when
   nothing changed; the sector map's outposts generated on worker threads; the cards' pictures built off
   the main thread in idle frames (training panel first open 70 → 16 ms, −11.5 MB video; boot's worst
   main-thread frame 33 → 1 ms); dead HUD helpers removed.
7. **Model defects and polygon waste** (`428f8e4`): degenerate triangles dropped at emit; faces more
   than 67° below horizontal left out of upright bodies but kept in the outline (the ink is drawn by
   exactly those faces), with opt-ins for ring inner walls and parts buried in static opaque enclosers;
   round parts given the sides their size at the closest zoom warrants (floors of 10 for smooth parts,
   8 for flat); holograms and spark surfaces treated as projections in the audit's clash rule; every
   defect the audit found fixed except the contacts listed as intended. Body triangles 921,707 →
   834,449 (−9.5%), outline 860,759 → 803,150; brushes 520 → 57, all intended and named; z-fights of
   matter on matter 296 → 0; parts below ground 66 → 0; duplicates and degenerates to 0. Invisibility
   proven by 259 pixel-identical shots with and without the filter; the defect fixes shown in a
   before/after folder.
8. **The hold's storage** (`626c334`): the fold's hold was first an instance uniform, and the engine
   reserves 16 vec4s of the global shader buffer for every instance whose shader declares one, so on this
   Mac only about 255 instances can carry it (a 16 KB phone block holds about 63) and the blocks are freed
   only with the instance; most folded buildings silently lost their holds behind a flood of "Too many
   instances using shader instance variables" warnings. Holds now wear per-hold material copies carrying
   a plain uniform on twin shaders, made only while a building is busy or EMP-disabled, so no instance
   uniform remains in the project. Verified by the reviewer's 480-instance probe (no warning) and in
   pixels for the busy, EMP and flash-under-EMP holds; identity and the profile unchanged.

## 5. Levers not pulled, and what is left

- **Far-detail building meshes** at wide zoom and **cheaper outlines** at a distance: each a visible
  trade-off the owner has not been asked about; the trims and the fold took the invisible savings first.
- **The shadow pass** (a third of primitives): a per-platform shadow resolution and a coarser caster set
  are export-time settings for the phone step.
- **Timed effects animated in the shader** and **cheaper per-unit math** in `BattleUnits.draw`: the battle
  view's remaining 0.8 ms (about 8 ms on the phone); fine at 30 fps.
- **The sector map's opening frame** (about 13 ms on the Mac: the panel's own first layout and drawing):
  for the UI pass.
- **Video memory of the fold**: CUSTOM3 as half floats, or folded parts in a second body surface; the
  phone measurement decides.
- **The fall test** `test_a_search_in_flight_goes_on_over_a_fall`: its opened cells play no part in the
  result (low); `TICK_BUDGET_MS` 2.0 in the `battle` scenario may flake under heavy load (1.9 ms seen at
  load 20); the audit's headless run sits at about 225 s of the 300 s watchdog.
- **The phone measurement** itself, with the procedure in `testing-tools.md`; the fold's vertex memory
  and the first hold's shader compile are the two things to watch there.

## 6. Measuring again

`tools/harness/run.sh profile --rendered` (the table), `model_audit` (defects and waste),
`anim_identity --rendered` (pose identity on the fixed clock), `battle` (the sim's slowest tick) and
`tools/sim_battles.gd` (`max_tick_ms`). Rendered runs take the machine-wide lock and want
`caffeinate -d -i -u`.
