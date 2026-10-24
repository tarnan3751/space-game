# Battle view

How a battle is drawn and driven: the scene that runs a `BattleSim` (`battle.md`) at its fixed
tick and draws the defender's field, the units, the shots and the falls, and how it takes the
base's place. The sim's rules and the API the view reads are in `battle.md`; the look (the kit, the
outlines, the shader effects) in `art-style.md`; the camera and the gestures in `input-camera.md`.
The attack HUD is step 5's second half; until then a tap deploys.

| File | What |
| --- | --- |
| `src/game/battle_view.gd` | `BattleView`: the sim, its clock, the field and the buildings, the events read into effects, the input |
| `src/game/battle_units.gd` | `BattleUnits`: every unit of a type from one MultiMesh pair, interpolated, with the gait, the flash and the death |
| `src/game/battle_effects.gd` | `BattleEffects`: bolts, impacts, lightning, scorch marks, fallen walls' strips, health bars and shield domes, each kind batched |
| `src/game/models/rubble.gd` | the heap a fallen building leaves (one per footprint size) and a fallen wall's strip |

## Entering and leaving

`main.gd` runs a battle in the base's place: `open_battle(setup, practice)` makes a `BattleView`
from the setup (a refused setup returns `BattleSim.setup_error` and changes nothing), cancels any
placement, takes the base's `BaseView` and `WorldInput` out of the tree, hides the HUD, adds the
battle and bounds the camera to its field. When the view emits `finished(setup, result)` the
battle is freed and the base's view, input and HUD come back. The base keeps running meanwhile:
the game's tick advances it and saves it as ever.

Until the sector map exists (step 6) the only battle is the debug build's **Practice raid** (the
HUD's debug row, `hud.md`): `practice_setup()` is the template base (`TemplateBase`, as the
`battle` harness scenario builds it) defending with its resources, the Hangars' army at its
researched levels attacking, and a seed from the clock, so each practice stands in a landscape of
its own. With no units it is refused ("Train some units first"). Its result is never applied:
`finished` returns to the base with the toast "Practice: nothing applied", and the save and the
real base are untouched.

## Driving the sim

`BattleView.setup(catalog, setup, camera)` creates the sim (`BattleSim.create`). `_process` adds
the frame's time, times `speed` (1 or 2, `SPEEDS`), to an accumulator and steps the sim once for
every 50 ms in it (`TICK_SECONDS`), at most `MAX_STEPS_PER_FRAME` (4) a frame: a slow frame slows
the battle rather than skipping the sim's order, and the accumulator is clipped so it never runs
ahead. After each step the view reads the units' positions (`BattleUnits.after_step`), the events
of the tick (`_read_events`) and the shields' pools; it never writes to the sim. Commands go in
through `command(cmd)` at the current tick (`deploy(unit, cell)`, `surrender()`); the harness's
`script_commands(list)` sends a list each at its own tick, before that tick's step, as a player
would. The accepted commands are the sim's log, so the result replays headless to the same hash
(the `battle_view` scenario checks it).

`speed` 0 pauses the battle: no tick is stepped and the effects' clock stands still, while the
scene still draws (the `battle_view` scenario measures a paused battle). Everything drawn runs on
the view's clock (`clock()`), seconds of battle shown, `speed` times as fast as real time, and running on after the end so the last deaths and impacts finish. Positions
and headings are interpolated between the last two ticks by `alpha`, the accumulator's share of a
tick; a shell's flight is the ticks between its `SHELL` and its landing. The sim's step time is
measured round each `step()` (`step_ms()`: the average and the longest).

`finished` is emitted `END_HOLD_SECONDS` (3) of real time after the sim ends.

## The field and the buildings

- **The field** is a `BaseView` of the view's own, built with the battle's seed
  (`BaseView.setup(size, seed)`, `input-camera.md`), the grid off: the base's landscape when the
  seed is `SCENERY_SEED`, another for any other.
- **Walls** are the field's merged `WallMesh`, built from the standing walls' levels by cell
  (`rebuild_cells`); a fallen wall leaves it (one rebuild at the end of a frame, however many fell)
  and a low strip of stones takes its cell (`BattleEffects.wall_rubble`, one MultiMesh pair).
- **Every other building** is a `BuildingView` at its level and tier, its moving parts turning as
  in the base. A hit whitens its bodies for `FLASH_SECONDS` (`BuildingView.set_flash`, the shared
  `MaterialKit.hit_flash` material on surface 0, no material per building) and shakes it for
  `SHAKE_SECONDS`, `SHAKE` either way; its health bar shows for `BAR_SECONDS` after the last hit.
  At zero hull it is freed and replaced by its **rubble** (`BuildingModels.create_rubble(size)`,
  `models/rubble.gd`): a scorched pad, a heap of chamfered dark chunks, three orange armour plates
  stuck in it, an ember or two and a column of dark smoke (RISE puffs on the hologram surface, two
  tiers of them), with a burst of dust. No tier: a heap reads the same whatever stood there.
- **Hidden** buildings: the cloaked sentry is drawn once `is_revealed`, with a red flash; traps are
  never drawn. A mine going off (`DETONATE` with damage) leaves a blast and a scorch mark; a throw
  trap only the blast.
- **Shields**: each shield generator's pool is a faint hologram dome in energy cyan over its range
  (`BattleEffects.add_shield`), shown while the pool is up and flickering for 0.3 s when it drops.

## Units

`BattleUnits` draws every unit of a type from one MultiMesh of its body and one of its outline
(`UnitModels.meshes(type, tier)`, in the tier of the attacker's level), with colours and custom
data, sized to the type's count in the army; units not yet deployed or gone are left out with
`visible_instance_count`. Each frame it writes one buffer a type and hands it to both. A unit has no
moving part (`UnitModels.MAX_MOVING` is 0); the gunship's rotors are spun by the shaders
(`LowPolyMesh.spin`, `art-style.md`).

- **Transform**: the interpolated position, the heading turned smoothly (`TURN_RATE`) towards the
  last move (`unit_heading`) or, while attacking, towards the target's centre.
- **Custom data** (`INSTANCE_CUSTOM`, read by the toon, ink and hologram shaders through
  `effects.gdshaderinc`): x the gait's phase in steps walked, y the gait's share, z the hit flash,
  w the death's fade. A walking ground unit hops once a step (a step is `STRIDE`, 0.45, of its
  model's height), leans forward and sways, the shear growing with the vertex's height; the share
  follows walking or standing at `GAIT_EASE` a second. A wheeled unit only jolts (`WHEELED`); a
  hovering or flying one (its mesh bobs) bobs by its own surface flags. A hit (a defence's shot
  arriving, a lightning strike) whitens it over `HIT_SECONDS` (0.12); a death shrinks, sinks and
  fades it over `DEATH_SECONDS` (0.3), its outline thinning to nothing, after which it is not drawn.
- **Throws**: a unit a grav trap throws flies from where it stood to where it landed on an arc
  `THROW_HEIGHT` high over `THROW_SECONDS`.
- **Health bars**: a damaged unit carries a cyan bar over its head, its fill easing towards the
  hull left.
- **The far version**: from camera size `FAR_ZOOM` (20) out, the MultiMeshes draw each type's far
  version (`UnitModels.meshes(type, tier, true)`: the model built at `LowPolyMesh.detail` 0.5, its
  round parts with half their sides and rings and smoothed to 65 degrees), about half the
  triangles, where a unit is a few dozen pixels tall. Every instance of a MultiMesh is drawn wherever
  the camera looks, so a full army in its near version would take the battle over the Cost ceilings.

## Shots and impacts

The events of each tick (`BattleEvents`, `battle.md`) become effects, each kind one MultiMesh of
`BattleEffects`, fixed in size (`MAX_*`), an ended entry swapped with the last, nothing allocated
a frame:

| Event | Drawn as |
| --- | --- |
| `UNIT_HIT` | a cyan bolt from the unit's middle to the building, flying at `BOLT_SPEED`, flashing and shaking the building and making an impact where it lands (as wide as the unit's splash); a unit of reach `MELEE_REACH` (one cell) or less strikes instead: an impact at the building's side at once |
| `SHOT` | a red bolt from the defence's muzzle (`MUZZLE_SHARE` of its height) to the unit, flashing it on arrival; the arc tower's is lightning (the LIGHTNING surface without its flicker, on a kinked strip stretched from the tower to the unit, `ARC_SECONDS`) with a blue impact |
| `SHELL`, `SHELL_LAND` | an orange shell on an arc landing where the sim aimed it when it lands; a blast as wide as the splash |
| `HOLD` | a violet pull round the gravity well, half its range |
| `DETONATE`, `THROW` | a hazard-yellow blast as wide as the trap's range, and a scorch mark for a mine; the thrown units' flights |
| `REVEAL` | the sentry shown, a red flash |
| `FALL` | the rubble or the wall's strip, a burst of dust |
| `DEATH` | the unit's fade |

Bolts are unlit glow orbs stretched along their flight, tinted per instance (`use_colors`);
impacts are hologram discs that grow and fade by their custom data's w (`holo.gdshader`); bars are
unshaded quads facing the fixed camera, drawn over everything. None casts a shadow or has an
outline (sparks and arcs never do, `art-style.md`).

## Input and the camera

The view has a `WorldInput` of its own (main's is out of the tree): a pinch, the wheel or a
two-finger pan zooms and pans the base's `IsoCamera`, bounded to the field; a one-finger drag
pans; a tap deploys one unit of `deploy_unit` on the cell under it (the first type in sorted order
with units left when it is ""), refused silently where the sim refuses it.

## Cost

Measured by the `battle_view` scenario (`tools/harness/README.md`) in a 1600×900 window at the
widest zoom (camera size 44), the battle paused once the whole scripted army (the battle scenario's
167 units, 280 housing) is down, the template base standing: 974 draw calls, 2.00 million
primitives and 1.6 ms of render CPU a frame, 174 fps, against the maxed base's ceilings
(`art-style.md`, **Cost**: 1,600, 2.1 million, 6 ms). The units in their near versions would have
been 2.40 million primitives (2.12 million without their shadows). The sim's step averages about
0.2 ms a tick over the battle; the longest, 7.5 to 10 ms, falls on the first tick or on the one
after the last group lands, when tens of units first ask for targets (their reach maps built, their
paths searched: `battle.md`, **Pathing**). The frame's process time at its slowest is about 10 ms.
Each unit type is three draws (its body, its outline and the body's shadow), each effect kind one;
the buildings cost what they cost in the base, less the traps and the walls' own views.

Two costs are measured fine on the Mac and unmeasured on a phone: every effect MultiMesh uploads
its whole buffer each frame whatever its visible count (the bars 768 instances of 20 floats, the
bolts 384, the impacts 256), and each unit type's buffer is uploaded twice, once for its body's
MultiMesh and once for its outline's. And the sim's first-tick spike (7.0 to 9.6 ms on the Mac,
on the first tick or when a large group first searches) is a core item parked for the next core
batch (`battle.md`, **Determinism and performance**, its levers).
