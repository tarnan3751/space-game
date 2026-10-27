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
| `src/game/weapons.gd` | `Weapons`: how each defence, trap and unit attacks and dies, one record a type id (**Weapons**) |
| `src/game/battle_effects.gd` | `BattleEffects`: each weapon's projectile, flash and impact (`fire`, `land`), and the primitives under them (bolts, missiles, bombs, pulses, beams, lightning, ring flashes, sparks, debris, smoke puffs, glow decals, stun crackles, blasts), impacts, scorch marks, fallen walls' strips, health bars and shield domes, each kind batched |
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
  (**The faction tint**). At zero hull it **collapses**: it leaves the drawn views and over
  `COLLAPSE_SECONDS` (0.35 s) sinks `COLLAPSE_SINK` (0.6) of its height, tilts `COLLAPSE_TILT`
  (12 degrees) about a level axis of its own (from its id) and shakes, in a ring of dust puffs;
  then its view is freed and its **rubble** (`BuildingModels.create_rubble(size)`,
  `models/rubble.gd`: a scorched pad, a heap of chamfered dark chunks, three orange armour plates
  stuck in it, an ember or two) pops up from `RUBBLE_FROM` (0.6) of its size over `RUBBLE_POP`
  (0.15 s), four to six debris chunks thrown out and a column of dark smoke rising for
  `SMOKE_COLUMN_SECONDS` (4 s, `BattleEffects.smoke_column`; the heap has no smoke of its own). No tier: a heap reads the same whatever stood there. A wall that
  breaks throws three chunks and two puffs of dust over its strip.
- **Hidden** buildings: the cloaked sentry is drawn once `is_revealed`, with a shimmer of energy
  rings and pale wisps. **Traps** are hidden until they spring: each has a `BuildingView` made at
  setup (so its meshes are built before the battle) and hidden; on `DETONATE` it pops up out of
  the ground over `TRAP_POP` (0.15 s), then goes off by its weapon record (**Weapons**) and hides
  again: a proximity mine's hazard blast with its ring, scorch and debris; a mega mine's bigger,
  which also shakes the camera (its `h_offset` and `v_offset`, `QUAKE` 0.18 for `QUAKE_SECONDS`
  0.45, easing to exactly zero, and cleared when the view leaves the tree); a flak mine's flash
  column up to each air unit over it, bursting there; a grav trap's funnel spinning for
  `FUNNEL_SECONDS` (0.6 s) in a violet ring as it throws, then sinking away. A glow decal lights
  the ground under each. The sim's rule is untouched: a trap is never shown before it springs.
- **Shields**: the shield generators' pools are faint hologram domes in energy cyan over their
  ranges, one MultiMesh for all of them (`BattleEffects.add_shield`, at most `MAX_SHIELDS`, 16),
  up while the pool is; when the pool absorbs, the dome flickers for 0.3 s between full and
  faded, brighter on the full beats, and never hides; when it is gone it fades out over
  `SHIELD_DROP_SECONDS` (0.4 s), swelling a little, inside an energy ring the size of its range.

## Units

`BattleUnits` draws every unit of a type from one MultiMesh of its body and one of its outline
(`UnitModels.meshes(type, tier)`, in the tier of the attacker's level), with colours and custom
data, sized to the type's count in the army; units not yet deployed or gone are left out with
`visible_instance_count`. Each frame it writes one buffer a type and hands it to both, while the
type draws a unit or drew one the frame before (that last hand-over empties it): a type with none
drawn two frames running, as every type once its army is gone, uploads nothing. A unit has no
moving part (`UnitModels.MAX_MOVING` is 0); the gunship's rotors are spun by the shaders
(`LowPolyMesh.set_motion`, `art-style.md`), and a rigged model's parts moved by them (the rig,
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
  ground unit and every air unit; the effects that go with it (blasts, smoke, wrecks: **Weapons**)
  are timed by `death_seconds`. The fall is the instance's transform, so every part and the outline go
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
- **Shots**: a unit's hit (`UNIT_HIT`) that is a shot (**Weapons**: not a blow or a charge) goes
  through `BattleUnits.shoot`, which fires it on the next draw (the same frame) through
  `BattleEffects.fire` with its type's weapon record: from the record's sockets in turn, the shot's
  index from 0 picking one (`muzzle` on even shots and `muzzle_2` on odd ones for a twin weapon,
  the parity the rig's sides take turns on; the bomber's `bay`, the skimmer's `eye`), posed by the
  state it is drawn in (`Rig.posed`, the CPU mirror of the shaders' angles), with the record's
  muzzle flash, or from its middle, with none, where the model has no such socket. An aiming
  unit's is held until its aim's share reaches `AIM_READY` (0.9), so a shot never leaves a rifle
  still rising; the sim's hit is instant and the shot is the view's. A melee blow brings no shot,
  so `after_step` also marks each unit's `UNIT_HIT` from the sim's events: a blow no shot follows
  starts the fire phase and counts as a shot all the same (the brawler's punches, the walker's
  recoil). `socket_point(id, name)` gives any of a unit's sockets (`muzzle`, `muzzle_2`, `bay`,
  `exhaust`, `exhaust_2`, `eye`) in the world as last drawn, and `has_socket(id, name)` whether its
  model has one.
- **Flight**: an air unit flies higher than its model is built, its middle `FLIGHT_MIDDLE` over
  the ground (the jet trooper 1.5, the skimmer 2.0, the gunship and the bomber 4.0, so even the
  tall top-level anti-air guns look up at them), over the walls and most roofs: a lift on its
  instance's transform (`_altitude`, the target less the model's own middle), so its sockets
  (`socket_point`), its aim point, its bar, its shadow, its bank and its
  shots go with it; `rest_point(id)` is its middle as built, unlifted, where its death's effects go. It appears at that height and its death spirals down from it to the ground over
  the same 0.6 s. Ground units, the hover tank included, keep their built height; outside a battle
  (the gallery, the cards) nothing is lifted. The sim is 2D and untouched.
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

The events of each tick (`BattleEvents`, `battle.md`) become effects by the weapon record of the
type that made them (**Weapons**), each primitive one MultiMesh of `BattleEffects`, fixed in size
(`MAX_*`), an ended entry swapped with the last, an entry that starts later (a burst's later
shots, a death's blast) drawn at no size until then; nothing is allocated a frame. A list hands
its buffer over only when what it draws changed: one empty since its last hand-over skips it; the
lightning arcs, which stand still for their lives (their shader moves them), skip it until one is
added or ends; the scorch marks, still for their first three quarters, until one is added or ends,
and while one is still to start or shrinking and once more after; the health bars until one is
added, dropped or moved; the shield domes until one is added or its pool moves, and while one
flickers or fades and once more after:

| Event | Drawn as |
| --- | --- |
| `UNIT_HIT` | by the unit's record: a blow (the brawler's), landing `PUNCH_DELAY` (60 ms) later at the fist that throws it (`muzzle`, or `muzzle_2` on an odd blow by its drawn state's parity, `BattleUnits.socket_point`): a ring `PUNCH_RING` (1.5) times its record's impact size, sparks, a short white flash and dust, the building flashed and shaken; the breacher's charge going off at the building's near face, its fireball standing off it by its radius (its record's blast, with debris); any other a shot through `BattleUnits.shoot` (**Units**) aimed at the building's near face (`HIT_FACE`, 0.48 of its footprint from its centre towards the unit, `HIT_HEIGHT` up; a bomb lower), flashing and shaking the building when it arrives |
| `SHOT` | the defence's record's projectile from its next muzzle socket, held until its head faces the unit (**Aim and muzzles**), or from its centre `MUZZLE_SHARE` of its height up when it has no socket, to the unit, flashing it on arrival; a shot that stuns (the EMP tower's) leaves the unit crackling yellow for the defence's `stun_ms` from when its pulse arrives |
| `SHELL`, `SHELL_LAND` | the record's projectile (the mortar's plasma, the orbital cannon's ball) on an arc landing where the sim aimed it when it lands; its impact as wide as the splash |
| `HOLD` | a violet pull round the gravity well, half its range, and its vortex from it to each unit of its targets' class in its reach, held `hold_ms` (**Vortices**) |
| `DETONATE`, `THROW` | the trap sprung (**The field and the buildings**); the thrown units' flights |
| `REVEAL` | the sentry shown, fading in over 0.3 s (**Aim and muzzles**), in a shimmer of energy rings and wisps |
| `FALL` | the building's collapse and rubble, or the wall's strip with chunks and dust |
| `DEATH` | the unit's fade, and its record's death: a wreck, a crash or a blast (**Weapons**) |
| `ABILITY` | by the ability's effect (`catalog.ability_effect`, the event's source its place in `ability_types()` plus one): a **swarm** a nanite-green hologram dome over its radius (`DOME_HEIGHT` of it high) fading out until its `land_tick`; an **EMP** an arc-blue ring as wide as its radius, and every drawn defence the sim now has disabled (`building_disabled`) dimmed grey (`BuildingView.set_disabled`, the shared `MaterialKit.disabled`, under a hit's flash), its moving parts frozen (the nodes left unposed, the parts folded into its body held by copies of its materials with the hold set, `MaterialKit.moving`, `art-style.md`, **Folded parts**), until a step finds it awake or fallen, when it flashes awake (an energy star and ring over it and a glow on the ground); a **strike** a pulsing red ring on the ground as wide as its radius or wider than the footprint under it, the same crosshair standing up facing the camera over the top of the tallest building it will hit, and in the last ten ticks before it lands a bright column falling from the sky (`SKY`, 8 units up) onto its point; all until its `land_tick` |
| `STRIKE_LAND` | the marker, the crosshair and the bolt end; a white-hot fireball (`BattleEffects.Timed`'s POP, an opaque unlit dome, `FIREBALL_SHARE` of the radius) pops over `STRIKE_BLAST_SECONDS` (0.6 s) from half the height of what it hit, so it shows over it, inside an orange ring 1.6 times the radius and a hotter disc, both lasting as long; pale smoke rises and swells from the landing for `SMOKE_SECONDS` (1.1 s), timed from it (not the RISE surface on the global clock), and fades |

The primitives (`BattleEffects`), none with a shadow or an outline:

- **Bolts** (`MAX_BOLTS` 384): a bright unlit core in a soft hologram sheath, a unit across,
  stretched to the record's width and length along its flight, tinted per instance; straight at
  the record's speed, or on an arc (its peak the record's `arc` times the distance) over a flight
  the record's speed or the sim times. Lasers, rifle and carbine bolts, tracers, plasma, the
  orbital cannon's ball and shells are all bolts of their own sizes. A trail leaves a puff every
  `TRAIL_STEP` (40 ms): grey smoke, or glowing wisps of the bolt's colour.
- **Missiles** (64): a white hull, a red nose, four gunmetal fins and an orange flame with a hot
  core, on a lofted arc (`MISSILE_MIN_LOFT` at least) with a smoke trail and a puff at the tube.
  **Bombs** (32): an orange casing with a hazard band and fins, carried along at their speed while
  they fall under `BOMB_GRAVITY` from the bay, nose turning down. **Pulses** (32): a ring standing
  across its flight, growing as it goes.
- **Beams** (64): a six-sided unlit rod with FLOW, stretched between the two ends and thinning to
  nothing: at once for a streak (`STREAK_SECONDS`, 0.12 s), after a hold for a beam (the record's
  `hold`).
- **Vortices** (`MAX_VORTICES` 24, two instances each, one draw): the gravity well's hold, from
  its core to each held unit (`BattleEffects.vortex`). One mesh in two parts, which its own small
  shader (`VORTEX_SHADER`: unshaded, alpha-blended) picks between by the instance's custom data x:
  - the sheath: a soft violet tube whose alpha falls from about 0.5 at the core's edge to nothing
    at its rim, pulsing `VORTEX_SWELL` (15%) at `VORTEX_PULSE` (1.5 Hz);
  - the strands: a pale core and a double helix of two strands the same way round it,
    `VORTEX_TURNS` (3) turns over the beam's length, banded lilac and violet with the bands wider
    than their gaps, turning at `VORTEX_SPIN` so the bands scroll from the unit to the well.

  Every sheath takes the low instances and every strand the ones after, so no sheath is drawn over
  a strand. A vortex fades in over `VORTEX_FADE_IN` (0.15 s) and out over `VORTEX_FADE_OUT` (0.3 s),
  at its hold's end, or at once when its unit dies or its well falls (`end_vortices`).

  While it holds, a violet ring tightens round the unit every 0.5 s, and a thick violet ring
  slides down the beam to the well every `VORTEX_SLIDE_STEP` (0.3 s), narrowing as it goes. The
  rings are worked out from the vortex's own clock each frame into a list of their own
  (`VORTEX_RINGS`, 4, a vortex; one more draw), so they stop the moment it starts to fade and
  never take the EMP pulses' places. The shader collapses the part an instance does not draw to a
  point in `vertex()`, so it costs no fragments. A unit's death ends only its vortices; its well
  glows on while it holds any other. An EMP burst does not release a hold (the sim keeps
  `hold_until`), so a disabled well's vortices run on to their hold's end. Each well holding anything, once however many it holds, glows
  round its plinth (a pale violet decal `WELL_RIM` (0.8) of its footprint across, pulsing) and
  swirls at its mouth (a ring 0.75 across, every 0.6 s).
- **Lightning** (`MAX_ARCS` 96): the LIGHTNING surface on a kinked strip from the tower to the
  unit, `ARC_MAIN` (1.3) times as thick, and two thinner branches forking off it towards the
  target, for `ARC_SECONDS`, tinted `ARC_TINT`.
- **Muzzle flashes**: an unlit eight-pointed star facing the camera at its size on the frame it is
  fired, shrinking away over `FLASH_SECONDS` (0.06 s); **ring flashes** (64): a flat unlit ring
  facing the camera, swelling over `RING_SECONDS` (a lens, a coil, a chamber, a waking defence).
- **Sparks** (96): ten rays facing the camera, flying out past their radius and gone by
  `SPARK_SECONDS`. **Debris** (192): lit chamfered chunks thrown on arcs under `DEBRIS_GRAVITY`,
  settling where they reach the ground and shrinking away over the last quarter of
  `DEBRIS_SECONDS`. **Smoke puffs** (384): soft discs facing the camera (`Timed`'s CLOUD), opaque
  in the middle and gone at the rim by their vertex colours, on one shared unshaded alpha-blended
  material (no rim light or scan bands), tinted per instance and faded by the instance colour's
  alpha, rising as they swell and fade: trails, dust, an air burst's dark puffs, smoke columns,
  wreck smoke.
- **Blasts** (`blast`, small, medium, big): a star flash and a white-hot opaque fireball popping
  (`Timed`'s POP, near full size a third of the way in), the orange one inside it showing as it
  shrinks, an orange ring on the ground and sparks; from medium smoke; a big one a second ring,
  debris and a scorch. An **air burst**: two flashes, a small fireball, sparks and dark puffs
  hanging where it went off.
- **Glow decals** (128): the fake light under a flash or a blast, an additive unshaded disc on the
  ground fading from the middle out by its vertex colours, its colour fading over its life; there
  is no light node.
- **Stun crackles** (64): three jittering zigzag arcs round a stunned unit for its stun.
- **Impacts** (256): hologram discs that grow and fade by their custom data's w (`holo.gdshader`).
  **Scorch marks** (64): dark discs, each from its start for `SCORCH_SECONDS` (20 s), shrinking
  away over the last quarter (`Timed`'s MARK), so the field clears: left by big blasts (the
  bomber's bomb, the titan's and the orbital cannon's shells), mines, crashes and wrecks only.

A projectile's impact lands short of the point it was aimed at (a unit's middle, a building's
near face), on the side it came from and a little up, so it shows in front of what it hits rather
than inside it: `SURFACE` (0.35), or a blast's fireball's radius when that is more
(`BattleEffects.stand_off`), so no fireball cuts into the building it hits. Bars are
unshaded quads facing the fixed camera, drawn over everything; the abilities' domes, crosshairs
and smoke are white holograms the instance colour tints, faded by the custom data's w, each kind
one MultiMesh (`BattleEffects.Timed`).

## Weapons

`Weapons` (`src/game/weapons.gd`) gives every defence, trap and unit type a record of how it
attacks, read by `BattleView` and `BattleUnits` and drawn by `BattleEffects`: presentation only,
so it lives in code, not in `data/` (the server never reads it). `Weapons.of(type)` builds a
type's record once (its `TABLE` entry over `DEFAULT`) and caches it; a type with no entry gets a
record that draws nothing. The `anim_defences` scenario checks that every armed type (one that
targets, holds, throws or shields) and every unit has an entry (`Weapons.has`).

A record: `kind` (the projectile: `BOLT`, `LASER`, `TRACER`, `PLASMA`, `BALL`, `SHELL`,
`MISSILE`, `BOMB`, `STREAK`, `BEAM`, `LIGHTNING`, `PULSE`, `VORTEX`, `MELEE`, `CHARGE`; the traps'
`MINE`, `FLAK_MINE`, `MEGA_MINE`, `GRAV_TRAP`; `SHIELD`, `NONE`), `color`, `width` and `length`,
`speed` (world units a second) and `arc` (a share of the distance), `burst` and `burst_gap` (shots
drawn for one hit of the sim; only the first tells its target), `trail` (none, smoke, glow),
`flash` and `flash_shape` (star or ring), `sockets` (taken in turn, one a shot), `impact` (sparks,
ring, blast small, medium or big, air burst, splash, burn, EMP) and `impact_size`, `light` (the
glow decal's radius), `recoil` (how far an aiming defence's head kicks back on a shot, world units:
the one source of the kick, **Aim and muzzles**; a unit's kick is its rig's), `death` (none, wreck, crash, blast,
timed by `BattleUnits.death_seconds`), `hold` (a beam's).

| Type | Attacks with | Impact |
| --- | --- | --- |
| laser turret | a thin long red laser from its four barrel tips in turn, a red star flash | red sparks |
| missile battery | missiles on a lofted arc with a smoke trail, a puff at the tube | a medium blast |
| plasma mortar | a violet plasma blob on the sim's high arc trailing wisps, a ring flash at the chamber | a violet splash as wide as the splash, wisps |
| flak cannon | yellow tracers, two a shot | an air burst at the unit |
| arc tower | lightning with two branches, a ring flash at the coil | blue sparks |
| cloaked sentry | short red laser bolts | red sparks |
| gravity well | a twisting double-helix vortex to each air unit it holds, rings sliding along it to the well, its plinth glowing | a ring tightening round the unit |
| EMP tower | a yellow pulse ring travelling to the unit | EMP arcs, then the stun crackle |
| railgun | a cyan streak, instant, fading in 0.12 s | cyan sparks |
| ion beam | a white-cyan beam held 0.2 s, a ring flash at the lens | a burn |
| orbital cannon | a big bright ball on a high arc with a glowing trail, a big star flash | a big blast |
| shield generator | (its dome) | |
| proximity, mega mine | the trap popping up | a medium, a big blast (the mega mine shakes the camera) |
| flak mine | a flash column to each air unit over it | an air burst there |
| grav trap | its funnel spinning in a violet ring | (the throw) |
| ranger | cyan rifle bolts | sparks |
| breacher | its charge at the wall | a medium blast with debris (its death) |
| jet trooper | two short cyan bolts a shot | sparks; dies in a small blast |
| brawler | a punch, landing at its fist | a ring, sparks, a white flash, dust, the building shaken |
| dune runner | three cyan tracers a shot from its twin guns | sparks; dies a wreck |
| skimmer | a short cyan beam from its eye | a burn; crashes |
| siege walker | fat orange cannon bolts from its two arms in turn | a small blast; dies a wreck |
| hover tank | an orange shell on a low arc | a medium blast; dies a wreck |
| titan | orange shells from its two cannons in turn | a big blast; dies a wreck |
| gunship | yellow tracer bursts of three from its chin guns | small blasts; crashes |
| bomber | a bomb falling from its bay | a big blast; crashes |

Deaths, timed by the body's fall (`BattleUnits.death_seconds`) and drawn where the body is drawn
(its `muzzle` socket as last drawn, `BattleUnits.socket_point`, which turns with the body as it
rolls; where its fall left it once it is over), at its model's middle's height as built, an air
unit's flight lift left out (`BattleUnits.rest_point`), which sizes them too: a
**wreck** is a fireball and a glow `WRECK_BLAST` (0.3) of the way through, then dark smoke and a
scorch where it came to rest; a **crash** trails smoke from the aircraft as it spirals down (a puff
every `CRASH_STEP`, 60 ms, at the first of `CRASH_SOCKETS` its model has, as last drawn: its
`exhaust`, which the skimmer, the gunship and the bomber all have, else its `muzzle`, else the
model's middle), then a blast and a scorch land where
it comes to rest; a **blast** is a small one at the end. A figure gets nothing
beyond its topple.

## Aim and muzzles

A model's sockets (`LowPolyMesh.socket`, `art-style.md`, **Sockets**) are named points with a
direction; `BuildingView` collects them from its model's root and moving parts
(`BuildingModels.SOCKETS_META`) and gives one in the world as the view stands now
(`socket_point`, `socket_direction`).

- **Aim**: a defence whose `muzzle` socket is on a moving part aims it (`BuildingView.can_aim`):
  the laser turret's head, the missile battery's launcher, the plasma mortar's barrel, the flak
  cannon's head, the cloaked sentry's lid, the railgun's rail assembly, the ion beam's emitter and
  the orbital cannon's mount, which carries its gun and its fire-control spire (`art-style.md`,
  **Moving parts**). One whose muzzle is on its body (the
  arc tower, the EMP tower, the gravity well), or with none, never does. Each frame the view turns
  the head towards the unit `BattleSim.building_target` names (unless it is dead) at the type's
  `AIM_TURN` rate, as an exponential share of the way a second, in seconds of battle: 10 for the
  laser turret and the cloaked sentry, 6 for the flak cannon, 5 for the railgun and the ion beam, 3
  for the missile battery, 2 for the plasma mortar, 1.5 for the orbital cannon (`AIM_TURN_DEFAULT` 4
  for any other), starting from where its idle scan had it (`aim_at`). With no target it holds its
  aim for `BuildingView.AIM_IDLE_SECONDS` (2.5), then eases back to its idle `Motion` at
  `AIM_RETURN` and follows it again (`idle_aim`). The head turns about +Y; the yaw that faces a
  point is measured from its pivot, against the way its muzzle faces as built. An idle Motion that
  is not a scan about +Y (the orbital cannon's elevation) runs on under the aim, until the gun
  pitches.
- **Pitch**: a defence whose aiming part has a `trunnion` socket also pitches its barrels
  (`BuildingView.can_pitch`, `art-style.md`, **Aiming parts**) towards the elevation `_elevation`
  gives, easing from their built elevation and back to it with the yaw. A direct-fire gun aims
  straight at the unit's drawn middle (`BattleUnits.aim_point`, an aircraft's height and a hovering
  machine's lift in it) from its trunnion (`pitch_origin`), within `PITCH_LIMITS` (degrees over
  level: the laser turret and the cloaked sentry -15 to 45, the flak cannon 0 to 75, the missile
  battery 0 to 60, the railgun 0 to 20, its mount lifting it clear of its capacitors at every level and
  its L6 targeting ring hovering clear over its raised rails, the
  ion beam -15 to 45), at its `AIM_TURN` rate. A lobbing gun elevates by the unit's range instead
  (`LOB_ELEVATION`, straight from the elevation at its full range to the one at its foot: the
  orbital cannon 20 to 70 degrees, the plasma mortar 45 to 70; the orbital cannon's far end at 0.7
  of its 50 cells, `LOB_REACH`, since the field's farthest unit is about 34 cells off), at
  `LOB_TURN` (1.5). The orbital cannon's barrel starts from where its elevation swing has it and
  eases back into the swing, so it never snaps. `aim_error`
  is the larger of the yaw's and the pitch's, so a held shot waits for both.
- **Kick**: as a shot leaves a muzzle socket (`_muzzle`) the view calls `BuildingView.fired(now,
  reach)` on the battle's clock with its type's weapon record's `recoil` (**Weapons**: the laser
  turret 0.18, the missile battery 0.1, the plasma mortar 0.25, the flak cannon 0.2, the cloaked
  sentry 0.1, the railgun 0.35, the ion beam 0.075, the orbital cannon 0.45 world units; 0, no
  kick, for a type with none), and the aiming part (the pitching barrels when they pitch on their
  own) kicks back along its pitched muzzle by it over
  `RECOIL_SECONDS` (0.25 s), then eases back; the head's pose is its
  aim's yaw, its idle Motion, then the kick. `recoil_share()` says how far into its kick it is.
- **EMP**: while a defence is disabled (`BattleSim.building_disabled`) every one of its moving parts
  holds its pose, its aim included; when a step finds it awake, `_woke(id)` takes its grey off and
  its parts snap back to the clock (the wake's flash is drawn there).
- **Reveal**: a hidden defence revealed (`REVEAL`) shows and fades in over `REVEAL_SECONDS` (0.3 s
  of battle, `_reveal`, driven from `_draw_buildings`): `BuildingView.set_reveal` steps its bodies
  through `MaterialKit.reveal`'s three shared materials, the shimmer's pale cyan mixed in at 0.8,
  0.55 and 0.3, its outlines hidden for the first, under a hit's flash; then it is itself.
- **Muzzles**: a defence with its record's first socket fires from its record's sockets in turn
  (`MUZZLES` for most: `muzzle`, `muzzle_2`, `muzzle_3`, `muzzle_4`; the missile battery's
  `MISSILE_TUBES`, up to `muzzle_20`, and the flak cannon's `FLAK_BARRELS`, up to `muzzle_8`; as
  many as the model has, starting over at the first it lacks) with its record's muzzle flash; every other defence fires from its centre `MUZZLE_SHARE` of its
  height up. An aiming defence's shot
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
about 1,046 with the attack HUD and the abilities bar over it (1,040 before the weapons pass:
the bolts' sheath, the effect lists live at that moment and one MultiMesh for the shields), 2.00
million primitives and about 2.1 to 2.4 ms of render CPU a frame, 110 to 120 fps on a loaded
machine (the same as before the pass, measured alternately), against the maxed base's ceilings
(`art-style.md`, **Cost**: 1,600, 2.1 million, 6 ms). The units in their near versions would have
been 2.40 million primitives (2.12 million without their shadows). The sim's step averages about
0.2 to 0.4 ms a tick over the battle; the longest is a deploy wave's tick with the searches'
budget of cells spent (`battle.md`, **Determinism and performance**): 1.24 to 1.28 ms in the
`battle` scenario (the faster of two runs per tick); this scenario's single run, measured at 2.6
to 4.8 ms before the budget in cells, has not been measured again. The frame's process time at its slowest is about 10 ms.
Each unit type is three draws (its body, its outline and the body's shadow), each effect kind one
while it has anything to draw (the bolts two, core and sheath; at most about a dozen more than
before the weapons pass with every kind live at once), a sprung trap its own view's draws while it
shows;
the buildings cost what they cost in the base, less the traps and the walls' own views.

Two costs are measured fine on the Mac and unmeasured on a phone: an effect MultiMesh that hands
its buffer over (**Shots and impacts**: each frame while what it draws changes) uploads the whole
buffer whatever its visible count (the bars 768 instances of 20 floats, the bolts and the puffs
384, the impacts 256), and a unit type's buffer, while the type draws, is uploaded twice, once for
its body's MultiMesh and once for its outline's.
