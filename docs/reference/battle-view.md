# Battle view

How a battle is drawn and driven: the scene that runs a `BattleSim` (`battle.md`) at its fixed
tick and draws the defender's field, the units, the shots and the falls, and how it takes the
base's place. The sim's rules and the API the view reads are in `battle.md`; the look (the kit, the
outlines, the shader effects) in `art-style.md`; the camera and the gestures in `input-camera.md`.
The attack HUD, `BattleHud`, is in `hud.md`, **Battle HUD**.

| File | What |
| --- | --- |
| `src/game/battle_view.gd` | `BattleView`: the sim, its clock, the field and the buildings, the events read into effects, the input |
| `src/game/battle_units.gd` | `BattleUnits`: every unit of a type from one MultiMesh pair, interpolated, with the gait, the aim, the flash and the death, and its shots from its muzzle |
| `src/game/battle_effects.gd` | `BattleEffects`: bolts, impacts, lightning, scorch marks, fallen walls' strips, health bars and shield domes, each kind batched |
| `src/game/models/rubble.gd` | the heap a fallen building leaves (one per footprint size) and a fallen wall's strip |

## Entering and leaving

`main.gd` runs a battle in the base's place: `open_battle(setup, practice, expedition = {})` makes
a `BattleView` from the setup (a refused setup returns `BattleSim.setup_error` and changes nothing), cancels any
placement, takes the base's `BaseView` and `WorldInput` out of the tree, hides the HUD, adds the
battle and its `BattleHud` (`main.battle`, `main.battle_hud`) and bounds the camera to its field.
When the battle ends the view emits `ended(result)` and the HUD shows its result panel; its Return
calls `leave()`, which emits `finished(setup, result)` once, and the battle and its HUD are freed
and the base's view, input and HUD come back. The base keeps running meanwhile:
the game's tick advances it and saves it as ever.

A battle is an expedition's (**Expeditions**, below) or the debug build's **Practice raid** (the
HUD's debug row, `hud.md`): `practice_setup()` is the template base (`TemplateBase`, as the
`battle` harness scenario builds it) defending with its resources, the Hangars' army at its
researched levels attacking with the Foundry's stock (`attacker.abilities`, every ability above 0)
at its levels (`attacker.ability_levels`), and a seed from the clock, so each practice stands in a landscape of
its own. With no units it is refused ("Train some units first"). Its result is never applied:
`finished` returns to the base with the toast "Practice: nothing applied", and the save and the
real base are untouched.

## Expeditions

The sector map's Attack (`hud.md`, **Sector map**) emits the field's index and its layout;
`main._on_attack_pressed` takes the field the map laid out and builds the battle with
`OutpostGenerator.battle_setup(field, army, state.unit_levels, abilities, state.ability_levels)`,
the army being the Hangars' units with a count above 0 (none: refused with "Train some units
first", the map left open) and the abilities the stock's entries above 0, for the abilities bar
(`hud.md`, **Battle HUD**); it closes the map and opens the battle with
`expedition` `{"epoch": state.sector.epoch, "index": index}`; a setup the sim refuses is toasted
(`hud.show_error`) and the map opens again. The setup's seed is the field's, so
the field stands in the landscape of its seed (`BaseView.setup(size, seed)`), and the view is made
with `rival` set, which draws the defender as a rival colony (**The faction tint**). On `finished`
the base comes back as after any battle, then `_apply_expedition` applies the result once through
`PlacementController.raid_result(setup, result, expedition)` (the check lays the field out again,
so it is not checked first: `expeditions.md`) and toasts the outcome: "Field cleared: N star(s)"
or "Field still open", with a second line of what came home, each resource's rise up to storage,
"+N metal, +M crystal", when anything did; a refusal toasts its error ("That expedition does not add up"
for `bad_expedition`). Then the sector map opens again, the field stamped once cleared. A battle's
`expedition` is kept from its start, so the result names the epoch it was fought in.

## The faction tint

Rival colonies are the player's roster with a faction tint (`docs/vision.md` §3.4). The toon
shader's `rival` uniform (0 or 1), set, passes each vertex tint through `toon_common`'s
`rival_tint` in `vertex()`, which makes a rival colony a green faction at every tier, Base to
Crown. Each role is a window on the tint's hue, full within a first distance and gone by a second,
over a saturation floor; the hues are of the tint as the shader reads it, the stored sRGB value:

| Role | Its tint's hue (sRGB) | Window | Becomes |
| --- | --- | --- | --- |
| Army orange (`ARMY`, the orange plates and glows) | 0.078 | 0.012, gone by 0.025; saturation from 0.5 | teal: hue 0.47 at 0.8 of its value |
| Core gold (`CORE_GOLD`: the Gold tier's trim, the Crown's filigree, the gold glows) | 0.110 | 0.010, gone by 0.020; saturation from 0.5 | verdigris green-gold: hue 0.24, 0.75 of its saturation and value |
| The violets (`ANTIMATTER`, the veins, the antimatter core's `CORE_GLOW_TINT`, the bright cores) | 0.72 to 0.74 | round 0.728: 0.018, gone by 0.032; saturation from 0.22 | emerald: hue 0.40, 1.5 times its saturation (at most 0.9), 0.9 of its value; a glow stays unlit and bright |
| The warm cream hull (`HULL_LIGHT`) | about 0.12, faintly coloured | warm, saturation 0.02 to 0.3, light | cooled a little, times `0.92, 0.97, 1.07` |

What lies just outside the windows keeps its colour: hazard yellow (0.139, the traps' lights; the
hazard stripes are a white-tinted layer), defence red (0.988), crystal (0.78), the cool greys and
the energy cyan. So do three layers whatever their tint, glass, chrome and obsidian (which is
violet-tinted, at 0.715), and the outlines (`ink.gdshader`), the holograms (`holo.gdshader`) and
the ground, which have no such uniform. The `expedition_flow` scenario measures it: at Command
Center 10, the share of the middle of the screen in the green band (hue 0.17 to 0.47, saturated)
is about 0.24 over a tinted outpost against under 0.01 over the template base.

`MaterialKit.rival()`, `hit_flash_rival()` and `disabled_rival()` are three shared materials made
once, the toon's, the hit flash's and the EMP's grey's with `rival` 1: the grey and the white are
mixed in after the tint, so a disabled or flashing rival building shows both. A `BattleView` given
`rival` before `setup` calls `BuildingView.set_rival(true)` on every defender building;
`BuildingView._apply_tint` then picks its toon bodies' surface 0 from the flash over the grey over
the plain body, each in its rival version, `rival()` being the plain body's, so a flash or a wake
never clears the tint. A third variant costs one more shared material and no per-building state;
the alternative, the grey as a per-instance shader parameter, would need instance uniforms on
every body for the few seconds an EMP lasts; the merged walls' body
takes `rival()` as its material override (`GeometryInstance3D.material_override`), which, unlike a
surface's, survives the mesh being rebuilt as walls fall. No material is made per building. The
units, every outline, the rubble, the wall strips and the scenery are never tinted, and a practice
battle leaves `rival` off.

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
  in the base but for an aiming head (**Aim and muzzles**). A hit whitens its bodies for `FLASH_SECONDS` (`BuildingView.set_flash`, the shared
  `MaterialKit.hit_flash` material on surface 0, no material per building) and shakes it for
  `SHAKE_SECONDS`, `SHAKE` either way; its health bar shows for `BAR_SECONDS` after the last hit.
  An expedition's buildings carry the faction tint and flash on `MaterialKit.hit_flash_rival`
  (**The faction tint**). At zero hull it is freed and replaced by its **rubble** (`BuildingModels.create_rubble(size)`,
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
(`LowPolyMesh.spin`, `art-style.md`), and a rigged model's parts moved by them (the rig,
`art-style.md`, **Rig**: legs, arms, wheels, guns, banks and bay doors).

- **Transform**: the interpolated position, the heading turned smoothly (`TURN_RATE`) towards the
  last move (`unit_heading`) or, while attacking, towards the target's centre. Every unit is
  deployed facing `DEPLOY_YAW` and turns onto its course from there. While a unit aims, a type whose
  aimed `muzzle` (on `Rig.AIM`) does not point straight ahead (the ranger's rifle, carried 15
  degrees across its body) turns further by the yaw of the muzzle's level direction off +Z at full
  aim, times the aim's share, so the muzzle points at its target; the yaw is derived from the
  socket, not a constant, and a muzzle within `AIM_YAW_VERTICAL` (30 degrees) of vertical, or not on
  `AIM` (the brawler's fists), gives none.
- **Custom data** (`INSTANCE_CUSTOM`, read by the toon, ink and hologram shaders through
  `effects.gdshaderinc`): x the gait's phase in steps walked, y the gait's share, z the hit flash, w
  the death's fade. A walking ground unit hops once a step (a step is `STRIDE`, 0.45, of its model's
  height), leans forward and sways, the shear growing with the vertex's height; the share follows
  walking or standing at `GAIT_EASE` a second. A wheeled unit only jolts (`WHEELED`) and steps at
  `WHEEL_STRIDE`, half its wheels' circumference, so its wheels (`WHEEL`, half a turn a step) roll
  with the ground. A hovering or flying one (its mesh bobs) bobs by its own surface flags, and its x
  is `Rig.BANK_BASE` (4) plus its bank in radians instead of a phase (so the shaders tell a level
  flight from the zero state of a model outside a battle, and a flame flickers only in battle): its
  drawn heading's turn rate times `BANK_GAIN` (0.2), at most `BANK_MAX` (25 degrees) in the air and
  `BANK_MAX_GROUND` (12) for a ground unit hovering low, eased at `BANK_EASE` (10) a second. A hit
  (a defence's shot arriving, a lightning strike) whitens it over `HIT_SECONDS` (0.12). A rigged
  type walks with its legs while the gait shows (the hip and knee channels read x and y as above). A
  type whose mesh carries a channel that reads the aim (`Rig.AIMING`: the ranger's and the jet
  trooper's arms, the brawler's punch, a slide's recoil, the bomber's bay, the jet's thrust) aims
  while it attacks (`unit_state` `ATTACKING`): its gait's share and its bank ease to 0 first, then
  its aim's share rises to 1 at `AIM_EASE` (10) a second, and while the aim shows, y is minus its
  share and x the fire phase, 0 at its last shot and 1 by the next (the seconds since over its
  `fire_ms` at its level), plus 2 after an odd shot (the shot's index from 0, mod 2: the parity a
  twin weapon's sides take turns on, `muzzle` on the left on even shots, `muzzle_2` on the right on
  odd ones), which raises the gun and kicks it, recoils a barrel or throws a punch on each shot.
  Leaving the attack, the aim eases to 0 before the gait or the bank comes back, so nothing snaps.
  `drawn_state(id)` gives a unit's state as last drawn. Any other type's data is as before.
- **Deaths**: a death plays over its class's seconds, `death_seconds(id)`: `FIGURE_DEATH` (0.45) for
  a figure (a ground type walking on `HIP_L` and `HIP_R`), `MACHINE_DEATH` (0.6) for every other
  ground unit and every air unit; the effects that go with it (blasts, smoke, wrecks) are A3's,
  which read `death_seconds`. The fall is the instance's transform, so every part and the outline go
  together: a figure topples backwards about its ankles (`TOPPLE`, 80 degrees); a walker (on the
  heavy hips) pitches forward 30 degrees (`KNEEL_PITCH`) and comes down onto the ground; any other
  ground machine rolls over a side's bottom edge (the dune runner 110 degrees, onto its back, the
  rest 35; by its id's parity) and settles to the ground; an aircraft (the jet trooper too) spirals
  down `SPIRAL_TURNS` (1.5) turns, nose down 25 degrees and rolled 30, to the ground. Each falls
  over the first `FALL_SHARE` (0.6) of its death, faster as it goes, then holds and shrinks away
  over the last `SHRINK_SHARE` (0.15); throughout, it is kept so the lowest of its model's extreme
  points (the vertices furthest along 26 directions) stays `GROUND_MARGIN` over the ground as it
  falls, so no part shows through it and a falling one comes to rest on it. The fade (w) thins its
  outline to nothing, after which it is not drawn.
- **Shots**: a unit's hit (`UNIT_HIT`) goes through `BattleUnits.shoot`, which fires its bolt on
  the next draw (the same frame): from its `muzzle` socket, or on an odd shot its `muzzle_2` where
  it has one, posed by the state it is drawn in (`Rig.posed`, the CPU mirror of the shaders'
  angles), with a muzzle flash (`MUZZLE_FLASH`), or from its middle when the model has no socket.
  An aiming unit's is held until its aim's share reaches `AIM_READY` (0.9), so a bolt never leaves a
  rifle still rising; the sim's hit is instant and the bolt is the view's. A melee blow brings no
  shot, so `after_step` also marks each unit's `UNIT_HIT` from the sim's events: a blow no shot
  follows starts the fire phase and counts as a shot all the same (the brawler's punches, the
  walker's recoil). `socket_point(id, name)` gives any of a unit's sockets (`muzzle`, `muzzle_2`,
  `bay`, `exhaust`, `exhaust_2`, `eye`) in the world as last drawn.
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
| `UNIT_HIT` | a cyan bolt from the unit's muzzle socket (with a flash; held until a rigged unit has aimed) or its middle to the building, flying at `BOLT_SPEED`, flashing and shaking the building and making an impact where it lands (as wide as the unit's splash); a unit of reach `MELEE_REACH` (one cell) or less strikes instead: an impact at the building's side at once |
| `SHOT` | a red bolt from the defence's next muzzle socket with a muzzle flash, held until its head faces the unit (**Aim and muzzles**), or from its centre `MUZZLE_SHARE` of its height up when it has no socket, to the unit, flashing it on arrival; the arc tower's is lightning (the LIGHTNING surface without its flicker, on a kinked strip stretched from the tower to the unit, `ARC_SECONDS`) with a blue impact |
| `SHELL`, `SHELL_LAND` | an orange shell on an arc landing where the sim aimed it when it lands; a blast as wide as the splash |
| `HOLD` | a violet pull round the gravity well, half its range |
| `DETONATE`, `THROW` | a hazard-yellow blast as wide as the trap's range, and a scorch mark for a mine; the thrown units' flights |
| `REVEAL` | the sentry shown, a red flash |
| `FALL` | the rubble or the wall's strip, a burst of dust |
| `DEATH` | the unit's fade |
| `ABILITY` | by the ability's effect (`catalog.ability_effect`, the event's source its place in `ability_types()` plus one): a **swarm** a nanite-green hologram dome over its radius (`DOME_HEIGHT` of it high) fading out until its `land_tick`; an **EMP** an arc-blue ring as wide as its radius, and every drawn defence the sim now has disabled (`building_disabled`) dimmed grey (`BuildingView.set_disabled`, the shared `MaterialKit.disabled`, under a hit's flash) until a step finds it awake or fallen; a **strike** a pulsing red ring on the ground as wide as its radius or wider than the footprint under it, the same crosshair standing up facing the camera over the top of the tallest building it will hit, and in the last ten ticks before it lands a bright column falling from the sky (`SKY`, 8 units up) onto its point; all until its `land_tick` |
| `STRIKE_LAND` | the marker, the crosshair and the bolt end; a white-hot fireball (`BattleEffects.Timed`'s POP, an opaque unlit dome, `FIREBALL_SHARE` of the radius) pops over `STRIKE_BLAST_SECONDS` (0.6 s) from half the height of what it hit, so it shows over it, inside an orange ring 1.6 times the radius and a hotter disc, both lasting as long; pale smoke rises and swells from the landing for `SMOKE_SECONDS` (1.1 s), timed from it (not the RISE surface on the global clock), and fades |

Bolts are unlit glow orbs stretched along their flight, tinted per instance (`use_colors`);
muzzle flashes an unlit eight-pointed star facing the camera, at its size on the frame it is fired
and shrinking away over `FLASH_SECONDS` (0.06 s; `Timed`'s FLASH), tinted as the shot;
impacts are hologram discs that grow and fade by their custom data's w (`holo.gdshader`); bars are
unshaded quads facing the fixed camera, drawn over everything; the abilities' domes, crosshairs
and smoke are white holograms the instance colour tints, faded by the custom data's w, each kind
one MultiMesh (`BattleEffects.Timed`). None casts a shadow or has an
outline (sparks and arcs never do, `art-style.md`).

## Aim and muzzles

A model's sockets (`LowPolyMesh.socket`, `art-style.md`, **Sockets**) are named points with a
direction; `BuildingView` collects them from its model's root and moving parts
(`BuildingModels.SOCKETS_META`) and gives one in the world as the view stands now
(`socket_point`, `socket_direction`).

- **Aim**: a defence whose `muzzle` socket is on a moving part (the laser turret's head) aims it
  (`BuildingView.can_aim`); one whose muzzle is on its body, or with none, never does. Each frame
  the view turns the head towards the unit `BattleSim.building_target` names (unless it is dead) at
  the type's `AIM_TURN` rate (10 for the laser turret, `AIM_TURN_DEFAULT` 4 otherwise, as an
  exponential share of the way a second, in seconds of battle), starting from where its idle swing
  had it (`aim_at`). While the defence is disabled it holds its aim. With no target it holds its
  aim for `BuildingView.AIM_IDLE_SECONDS` (2.5), then eases back to its idle `Motion` at
  `AIM_RETURN` and follows it again (`idle_aim`). The head turns about +Y; the yaw that faces a
  point is measured from its pivot, against the way its muzzle faces as built.
- **Muzzles**: a defence with a `muzzle` socket fires from its sockets in turn (`MUZZLES`:
  `muzzle`, `muzzle_2`, `muzzle_3`, `muzzle_4`, as many as it has) with a muzzle flash
  (`DEFENCE_FLASH`); every other defence fires from its centre as before. An aiming defence's shot
  is held until its head faces the unit within `AIM_READY` (0.12 radians), `AIM_HOLD` (0.4 s) at
  most: the sim picks a target and fires on one tick, so the head is still turning to a new target
  when its shot comes; the hit is the sim's at once, the bolt the view's. A defence that falls or
  is disabled while it holds a shot fires it at once, from wherever its head is.

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
Each unit type is three draws (its body, its outline and the body's shadow), each effect kind one
(the muzzle flashes one more since the rig pass);
the buildings cost what they cost in the base, less the traps and the walls' own views.

Two costs are measured fine on the Mac and unmeasured on a phone: every effect MultiMesh uploads
its whole buffer each frame whatever its visible count (the bars 768 instances of 20 floats, the
bolts 384, the impacts 256), and each unit type's buffer is uploaded twice, once for its body's
MultiMesh and once for its outline's.
