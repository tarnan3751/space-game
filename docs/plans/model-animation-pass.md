# The model and animation pass

The record of the pass the owner asked for on 2026-10-25 after reviewing the Milestone 2 renders:
the models "decent" but not good enough, the animation "really bad" (ships and robots without
good animations, figures without walking or shooting, defences that never turn to aim, bullets
and beams that look wrong and leave the wrong place), with the addition that every projectile
must be specific to its source ("the missile battery should shoot missiles") and that traps,
defences and projectiles carry the right lights, models and explosions. Status: **built**,
2026-10-25, every call the coordinator's (`docs/project_overview.md` §3.1, **The model and
animation pass**). Every series shipped frames, read by the coordinator and an independent
reviewer, and a series whose frames did not read failed regardless of the gate.

## 1. Method

- **Frame strips.** `tools/harness` gained `strip(name, count, step_ms, crop)`, `frame_world`
  and `frame_span`, and the `anim_units`, `anim_defences`, `anim_aim`, `anim_base` and
  `anim_effects` scenarios: every unit's move, fire, death and bank; every defence's aim, fire
  and impact; every trap, the building fall and the wall break; every building's idle at three
  levels; the abilities, the shield, smoke and rubble. The strips are the evidence
  (`tools/harness/README.md`).
- **Two art critiques** (units and figures; buildings), judged at the overview zoom first, set
  the standard and the fixes for the model phase.
- **Lanes.** Six model series and five animation series, each a developer in its own clone with
  a targeted or full review, landed in dependency order: harness strips; the rig foundation;
  vehicles and aircraft; figures and infantry; core and resources (with the halftone and the
  post family); army buildings; defences, traps and walls; then the units' motion, the base
  idles, the projectiles and effects, and the defences' aim.

## 2. The model phase (main d595cbd)

The rules adopted (`docs/reference/art-style.md`): the category accent on at least a quarter of
what the camera sees, on a big part, never on trim; no hull-mid main mass; nothing structural
under `Parts.STRUCTURAL_MIN` (0.14) across on new or reworked models, with a post family
(`tapered_mast`, `dish_post`, `lamp_post`); Gold on a part, an Obsidian level keeping its accent
surface, Crown filigree only on bands 0.1 or taller; small parts on the flat layer; a
camera-facing deck plate carrying the tier on every machine; pilots sunk behind framed canopies;
figure ink 0.75 on the big masses and 0.5 on limbs; red on a big part of every defence (the
plinth's upper third and one mass each); the halftone coarsened to a print screen (7 px, 25%,
0.08 darkening). Reworked outright: the hover tank, skimmer, metal extractor, antimatter siphon
and vault, cadet academy (its cadet a hologram on the colonist figure), fabricator, flak
cannon's Base head, railgun L1-3; everything else polished to the same rules. Triangle budgets
and draw calls unchanged.

## 3. The animation phase (main 98d9808)

Three architecture calls, all in the game layer:

- **A part rig in the vertex shader, not skeletons.** Per-vertex `CUSTOM1 = (pivot, channel)`
  and `CUSTOM2 = (pivot2, channel2)` on rigged parts (two hierarchy levels), gated by
  `Surf.RIG`; a channel table in `src/game/rig.gd` mirrored exactly in `effects.gdshaderinc`
  (hips, knees, shoulders, elbows, the aim group, wheels, bank, slide recoils, bay doors, heavy
  legs, thrust); the instance state in INSTANCE_CUSTOM (gait or fire phase with the shot
  parity, gait share or aim share, bank with `BANK_BASE`, flash, fade); the zero state the bake
  pose, so the gallery, cards and base draw unchanged. Deaths by class in the instance
  transform, clamped above the ground: figures topple (0.45 s), machines roll or kneel and
  aircraft spiral down (0.6 s). GLES3 skinning is slow and a MultiMesh cannot be skinned
  (`docs/reference/art-style.md`, **Rig**).
- **Sockets and aimed movers.** Models record named sockets (`muzzle`, `muzzle_2`, `bay`,
  `exhaust`, `eye`); a defence's aiming part is the mover that holds its `muzzle` socket,
  turned by `BuildingView` toward `BattleSim.building_target(id)` (the only core change, a
  read) with a per-type rate, composed as aim yaw × idle Motion × a fire-driven kick; riders
  follow the part they ride; every mover freezes while EMP-disabled and the cloaked sentry fades
  in on reveal (`docs/reference/battle-view.md`, **Aim and muzzles**).
- **A weapon table in the view.** `src/game/weapons.gd` holds one record per defence, trap and
  unit: projectile kind, colour, size, speed or arc, trail, flash, sockets, impact, glow decal
  and death kind. `BattleEffects` draws them from batched lists (bolts, missiles, bombs, pulses,
  beams and streaks, rings, sparks, debris, soft puffs, glow decals, the stun crackle), traps
  pop up and detonate when sprung, buildings sink and tilt into rubble with debris and a smoke
  column, deaths explode by class, the shield flickers without vanishing, blasts stand off the
  face they hit and scorches fade (`docs/reference/battle-view.md`, **Weapons**).

The base's idles were made to read in eight frames at 150 ms for every building, every dish on
one speed (`Parts.DISH_RATE` 1.6), the construction drone's beam a hot core in a sheath with
sparks at the work point.

Cost: a battle at the template base went from about 1,040 to about 1,080 draw calls (new
movers on the mortar, railgun and ion beam; one list per effect kind), against the 1,600
ceiling; the sim is untouched and its hashes unchanged.

## 4. The owner's review list

Calls the coordinator made that the owner may reverse, each a data or model change: the
halftone's numbers; the hologram cadet on the colonist (the box figure stays rejected); the
jet flames in fixed fire colours at every tier; the vault door on the front face; the raised
early walls; the structural minimum of 0.14; the rival-neutral violet holograms; the deaths'
timings; the kick amplitudes (the `recoil` of the defences' records in `weapons.gd`); the kinds and colours in `weapons.gd`.

## 5. The follow-ups, and what is left

Landed the same day: building figures march on the clock (`Surf.MARCH`: the hangar's trooper
patrols its pad, the academy's cadet marches in place, both hidden while the building is busy);
exhaust sockets on the gunship and skimmer so crashes trail from the engines; the kick read from
the weapon record's `recoil`; the `effects` pulse check on any pair of shots; aircraft flying
higher in battle; and the defences' barrel pitch (§3.1 **Aircraft fly higher and defences pitch
their barrels**).

Also landed after the owner's read of the folders (§3.1 **The owner's three corrections after the
pass**): housing out of the top bar into the training panels, the Command Center's broad L7+ tower
with the dome inside it, and the gravity well's vortex.

Left: the `battle` scenario's step budget fails under machine load (core measurement); the phone
measurement still needs a device (`docs/reference/testing-tools.md`). The mortar's L7 loader arm,
which brushed the barrel at two yaws in battle, was moved clear in the performance pass.
