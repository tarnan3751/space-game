# Battle view

How a battle is drawn and driven: the scene that runs a `BattleSim` (`battle.md`) at its fixed
tick and draws the defender's field, the units, the shots and the falls, and how it takes the
base's place. The sim's rules and the API the view reads are in `battle.md`; the look (the kit, the
outlines, the shader effects) in `art-style.md`; the camera and the gestures in `input-camera.md`.
The attack HUD, `BattleHud`, is in `hud.md`, **Battle HUD**.

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
battle and its `BattleHud` (`main.battle`, `main.battle_hud`) and bounds the camera to its field.
When the battle ends the view emits `ended(result)` and the HUD shows its result panel; its Return
calls `leave()`, which emits `finished(setup, result)` once, and the battle and its HUD are freed
and the base's view, input and HUD come back. The base keeps running meanwhile:
the game's tick advances it and saves it as ever.

Until the sector map exists (step 6) the only battle is the debug build's **Practice raid** (the
HUD's debug row, `hud.md`): `practice_setup()` is the template base (`TemplateBase`, as the
`battle` harness scenario builds it) defending with its resources, the Hangars' army at its
researched levels attacking with the Foundry's stock (`attacker.abilities`, every ability above 0)
at its levels (`attacker.ability_levels`), and a seed from the clock, so each practice stands in a landscape of
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

The view stays on the field after the end, its last effects finishing, until `leave()`.

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
| `ABILITY` | by the ability's effect (`catalog.ability_effect`, the event's source its place in `ability_types()` plus one): a **swarm** a nanite-green hologram dome over its radius (`DOME_HEIGHT` of it high) fading out until its `land_tick`; an **EMP** an arc-blue ring as wide as its radius, and every drawn defence the sim now has disabled (`building_disabled`) dimmed grey (`BuildingView.set_disabled`, the shared `MaterialKit.disabled`, under a hit's flash) until a step finds it awake or fallen; a **strike** a pulsing red ring on the ground as wide as its radius or wider than the footprint under it, the same crosshair standing up facing the camera over the top of the tallest building it will hit, and in the last ten ticks before it lands a bright column falling from the sky (`SKY`, 8 units up) onto its point; all until its `land_tick` |
| `STRIKE_LAND` | the marker, the crosshair and the bolt end; a white-hot fireball (`BattleEffects.Timed`'s POP, an opaque unlit dome, `FIREBALL_SHARE` of the radius) pops over `STRIKE_BLAST_SECONDS` (0.6 s) from half the height of what it hit, so it shows over it, inside an orange ring 1.6 times the radius and a hotter disc, both lasting as long; pale smoke rises and swells from the landing for `SMOKE_SECONDS` (1.1 s), timed from it (not the RISE surface on the global clock), and fades |

Bolts are unlit glow orbs stretched along their flight, tinted per instance (`use_colors`);
impacts are hologram discs that grow and fade by their custom data's w (`holo.gdshader`); bars are
unshaded quads facing the fixed camera, drawn over everything; the abilities' domes, crosshairs
and smoke are white holograms the instance colour tints, faded by the custom data's w, each kind
one MultiMesh (`BattleEffects.Timed`). None casts a shadow or has an
outline (sparks and arcs never do, `art-style.md`).

## Input, deploying and the camera

The view has a `WorldInput` of its own (main's is out of the tree): a pinch, the wheel or a
two-finger pan zooms and pans the base's `IsoCamera`, bounded to the field.

- **Casting.** `select_ability(ability)` (the abilities bar) sets `cast_ability` and lets the unit
  type go, so the red zone hides; `select_unit` with a type lets the ability go. With an ability
  selected a tap casts it at the cell under it (`cast(ability, cell)`, the sim's `ability`
  command at the current tick), anywhere on the field, buildings included; a refusal is emitted as
  `cast_failed(code)`. A drag pans. `abilities_brought()` lists the abilities brought above 0.
- **Queries** for the HUD and the harness: `building_type(id)`, `building_centre(id)` (on the
  ground), `is_revealed_defence(id)` (a drawn defence not hidden now), `is_shown_disabled(id)` (an
  EMP's grey on it), `cast_ability` and `deploy_unit` (what is selected), `cast(ability, cell)`,
  `select_ability(ability)`, `select_unit(unit)`, `abilities_brought()`, `units_brought()`.

- **Selecting.** `select_unit(unit)` (the deploy bar's cards) sets `deploy_unit`, the type a tap or
  a drag deploys; "" selects none. While one is selected the ground shows the deploy mask: a
  48×48 texture, one texel a cell, white where `is_deploy_cell` refuses, drawn by `ground.gdshader`
  as a faint hatched red (`BaseView.set_deploy_mask`, strength `MASK_STRENGTH` 0.32) over the
  zone; it is rewritten from the sim at the end of a frame in which a building fell, so the zone
  opens as the base falls (`is_masked(cell)` reads it). The ends of the battle let the type go.
- **A tap** with a type selected deploys one on the cell under it (`deploy`), now. With none
  selected it does nothing.
- **A drag** with a type selected smears: the cell pressed and every cell the finger crosses (the
  ones between two drag events filled in, so a fast stroke leaves no gap) are queued, each once a
  drag (a cell crossed again, back and forth, takes no second unit), and before each step the first
  one that takes a unit gets one: one unit a tick at most, as Clash's smear. Cells refused for the
  zone are skipped; running out of the type, or letting it go, ends the smear and the rest of the
  drag pans. With none selected a drag pans.
- **Refusals** are emitted as `deploy_failed(code)` (the HUD toasts `blocked` and `none_left`); a
  refusal for the zone (`blocked`) flashes the red to `MASK_FLASH` (0.75), fading back over
  `MASK_FLASH_SECONDS`.

The harness also sends commands each at its own tick (`script_commands`). `falls()` counts the
buildings fallen so far, so the HUD reads the loot (`BattleSim.loot()`, which builds a dictionary)
only when it can have moved; the HUD's refresh on `stepped` allocates nothing when nothing it
shows changed (`hud.md`, **Battle HUD**).

## Cost

Measured by the `battle_view` scenario (`tools/harness/README.md`) in a 1600×900 window at the
widest zoom (camera size 44), the battle paused once the whole scripted army (the battle scenario's
167 units, 280 housing) is down, the template base standing: 974 draw calls without the HUD and
about 1,045 with the attack HUD and the abilities bar over it, 2.00 million primitives and about
1.6 to 1.9 ms of render CPU a frame, 155 to 185 fps, against the maxed base's ceilings
(`art-style.md`, **Cost**: 1,600, 2.1 million, 6 ms). The units in their near versions would have
been 2.40 million primitives (2.12 million without their shadows). The sim's step averages about
0.2 to 0.4 ms a tick over the battle; the longest is a tick of four full path searches
(`battle.md`, **Determinism and performance**), the reach maps being built at setup so the first
tick no longer pays for them: 2.3 to 3.3 ms in the `battle` scenario (the faster of two runs per
tick), about 2.6 to 4.8 ms in this scenario's single run, depending on the machine's load. The frame's process time at its slowest is about 10 ms.
Each unit type is three draws (its body, its outline and the body's shadow), each effect kind one;
the buildings cost what they cost in the base, less the traps and the walls' own views.

Two costs are measured fine on the Mac and unmeasured on a phone: every effect MultiMesh uploads
its whole buffer each frame whatever its visible count (the bars 768 instances of 20 floats, the
bolts 384, the impacts 256), and each unit type's buffer is uploaded twice, once for its body's
MultiMesh and once for its outline's.
