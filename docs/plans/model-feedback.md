# Model feedback pass (after the upgrade pass)

Status: **built, 2026-10-16** (main f11b8d4; §3 says what landed). The owner reviewed every
max-level model after the upgrade pass (`upgrade-pass.md`) and gave a list of problems. This file sorts that list, records the
decisions, and names the lanes that fix it. The owner's rules for the pass:

- A problem seen at the max level is checked at **every level** of that type; lower levels that
  are already fine stay untouched.
- The purple lightning's flicker is slowed to **one speed, the same on every building**.
- Robots: **no robot flies above any defence building**, the drone bay, the research lab, the
  nanite foundry, the alliance beacon or either fabricator. Every robot that stays is
  **tailored to its building**: its look, its motion and what it does belong to that building.
  The generic escorts (drone, skiff) read as copies and go.

## 1. The sorted list

Ordered by what the rest depends on: shared mechanisms first, then the removals, then the new
robots, then the reshapes, then the surface fixes.

### A. Shared mechanisms (one place each)

| # | Problem | Where it lives | Decision |
| --- | --- | --- | --- |
| A1 | Purple lightning flickers too fast: Command Center, antimatter siphon, antimatter vault, arc tower (and every other arc) | `Parts.spark()` surfaces, `effects.gdshaderinc` `FLICKER_RATE` 24 / `JITTER_RATE` 20, global | A new surface flag `Surf.LIGHTNING` (1024) that `Parts.spark()` carries: arcs flicker at `LIGHTNING_FLICKER_RATE` 7 a second, on 0.6 of the time, and jitter at 5 a second. Point sparks (welding, cutting, flares, grids) keep the fast rates. |
| A2 | Radar dishes spin faster than the Command Center's: missile battery 1.2, flak cannon 1.2 (the hangar's 1.2 and the lab's 0.9 too) | `Motion.spin(Vector3.UP, rate)` per model | `Parts.DISH_RATE := 0.8` (the Command Center's rate); every spinning dish uses it. |
| A3 | Smoke looks fake: static bobbing orbs | `Parts.puffs`, `Parts.SMOKE` HOLO|BOB | A new flag `Surf.RISE` (2048): the part climbs world Y over `RISE_PERIOD` seconds from its phase, drifting a little, and (on the hologram surface) fades as it climbs, then starts again. `Parts.puffs` is rewritten on it, with a `surface` argument. |
| A4 | The security bot (shared by the Command Center, both silos and the vault) | new `Parts.escort_guard` | A robust hover sentinel, unlike the saucer drone and the skiff: a chunky chamfered armoured body wider than tall, a wide visor strip, two shoulder pods, one thruster glow beneath; no rotors, no canopy. Same signature as the other escorts; a negative rate orbits the other way. At most 300 triangles. |

### B. Removals (each a single top-level call; every escort sits only at its type's top level)

Defence, all of it: laser turret, missile battery, shield generator, flak cannon, arc tower,
cloaked sentry, gravity well, EMP tower, railgun, ion beam, orbital cannon (the plasma mortar's
two troopers walk its balcony as a gun crew, so they stay: a judgment call for the owner to veto).
Resources: drone bay, antimatter siphon (no tailored replacement; its arcs and halo are its life).
Army: fabricator, heavy fabricator (with its hauled plate), research lab, nanite foundry, alliance
beacon. Replaced rather than removed: Command Center, metal extractor, crystal harvester, metal
silo, crystal silo, antimatter vault, hangar, dry dock.

### C. Tailored robots

| Building | Robot | Motion |
| --- | --- | --- |
| Command Center (L10) | two security bots at the narrow tower, one high, one low | opposite directions; the wing dish stops spinning at L10 to free the slot |
| Metal silo, crystal silo, antimatter vault (top level) | one security bot each | a patrol round at mid-height |
| Metal extractor (L10) | an ore hauler: a squat hover-hauler with an open bucket of glowing metal ore | shuttles between the drill head and a hopper (slide), else a low tight round |
| Crystal harvester (L10) | a collector: a hover-bot with a claw holding a cut shard | a low round under the laser ring |
| Hangar (L10) | a marshaller: a stubby bot with two glowing orange wands | hovers before the main door, rocking as it waves ships in (swing) |
| Dry dock (L7) | two welders: compact hover-welders with a lens eye, arm nozzles and a weld spark at the hull | along the hull's flank at two heights in opposite directions (slide), else rounds about the hull's axis |

### D. Reshapes

| Building | Problem | Decision |
| --- | --- | --- |
| Command Center | the step from the wide base ring to the narrow tower is jarring | at L10: two wide floors, two narrower floors still wider than the tower, then the tower; the height stays 6.94; L6–9 grow into that stack at their own heights |
| Cadet academy | chaotic, crowded, and the hall is a thin slab | the hall becomes a real building 1.3 deep with a porch and courtyard in front; a stocky corner tower instead of the pencil; the yard holds a few things |
| Fabricator | chaotic at max, same size as the heavy | fewer masses, a smaller hall, shorter and fewer stacks, so its silhouette fits under the heavy's |
| Dry dock | the hovering violet platform adds nothing | gone (L6 and L7) |
| Plasma mortar | lightning round the orb does not read as plasma | a swirling, boiling ball: the core, a translucent swirl shell, tongues on its surface; no bolts |
| Orbital cannon | the dish is too plain for it | a fire-control spire: a stepped mast, a big glowing targeting lens, a slow halo of three pointed vanes |

### E. Surface fixes

| Building | Problem | Decision |
| --- | --- | --- |
| Metal extractor | the ore turns pink from L8 while metal is blue everywhere else | the ore, nuggets and floating ore use the metal tint at every level |
| Crystal harvester | the lasers wave sideways; the big crystal at L10 is flat | the emitters ride a ring spinning about the big crystal, always aimed at it; the L10 crystal uses the patterned, pulsing shard surface |
| Heavy fabricator | no smoke | the new smoke on its stacks |
| Nanite foundry | the goop does not read as liquid | a meniscus at the surface, a slow sideways flow, bubbles rising through it |

## 2. Lanes

Five developer lanes on disjoint files, each a tier B brief with its own review:

- **parts**: `parts.gd`, `surf.gd`, `effects.gdshaderinc`, `holo.gdshader`, `kit_swatches`,
  art-style docs: A1–A4. Lands first; the others code against its names and rebase.
- **core**: `core.gd`: the Command Center reshape and its two guards.
- **resources**: `resources.gd`: the drone bay and siphon removals, the extractor, the harvester,
  the three storages' guards.
- **army**: `army.gd`: the removals, the hangar's marshaller, the academy, both fabricators and
  the smoke, the foundry's goop, the dry dock.
- **defense**: `defense.gd`: the removals, the dish rates, the mortar's plasma, the orbital
  cannon's spire.

Every lane: no new footprint, the per-tier budgets, the height caps, the reach bound, the clash
scenario clean, the comic style, and the visibility rule of `docs/reference/art-style.md`.

## 3. What landed

Five series, each with its own tier B review and the review's findings folded before landing:
parts (5 commits, to 3c582d2), core (3, to 76062d5), defense (5, to d204552), army (11, to
893923f), resources (8, to f11b8d4). Departures from §1 and §2, decided on the way:

- The Command Center's two guards fly at scale 1.0 on r 1.39, between the tower's conduits
  (r 1.13) and the dish pylon moved to the pad's edge (r 1.66 at their heights), with 0.01 to
  spare each side; the L10 wing dish is built into the body and the L10 masts are lowered so the
  low guard clears them. The guards are about 10 px at the widest zoom and clear at close zoom.
- The harvester's ring was laid out three times: over the carriage (beams hidden against the
  crystal), low round the crystal (the owner: "the lasers are angled upwards"), and finally at
  1.1× the aimed shard's height, radius 0.7 / 0.8 / 1.0 by level, each beam running down into the
  crystal at 43–53°, aimed at 0.62 of its height (0.77 at L10, over the gold collar).
- The metal silo's guard first flew a tight round in the front gap at mid-height (no round about
  the middle clears the twin tanks), which the owner read as "spinning in place"; it now flies the
  crystal silo's round (r 1.38, rate 0.5) at 3.95, the lowest height over the far tank's vent cap
  (§4). The vault's flies over the pylon caps at 3.3.
- The extractor's stacks keep 2 puffs below Chrome (the Base budget) and 4 from L6.
- The dry dock's low welder arrives at L6 and the high one at L7, so L6 keeps a bold change.
- The academy's L10 parade (troopers at scale 0.8) replaced the target posts for a day; it is
  gone again (§4) and L10 keeps L9's courtyard.
- `Parts.puffs` defaults to 8×3 orbs so four puffs fit the fabricator's Base budget.
- The plasma mortar's balcony troopers and the academy's marching cadets were kept for the
  owner to veto, and the owner vetoed both (§4); the siphon lost its drone with no replacement.

Parked (memory, `model-feedback-leftovers`): a per-part RISE drift, the harness blind to RISE's
climb and to black rendered frames, the HUD meter's steel blue against the models' teal metal.

## 4. The owner's second round (2026-10-16)

Five small changes after seeing the pass in the game, four lanes in parallel, each reviewed:

- **No human figures yet.** "We haven't finalized the design of what the humans will look like,
  so it's not the time for that yet." The plasma mortar's troopers are gone and its balcony is
  an ammunition rack: an obsidian octagonal pedestal where the loader arm stands, three upright
  plasma canisters banded gold in a gunmetal cradle beside it. The academy's marching cadets and
  their parade ring are gone; its L10 keeps L9's courtyard (posts and plinth in place). The
  hologram cadet on the plinth was not named and stays. `Parts.escort_troopers` stays in
  `parts.gd` for the day the human design is settled.
- **The metal silo's guard flies round the silo** like the crystal silo's: r 1.38, rate 0.5,
  at 3.95, the lowest height whose skirt clears the far tank's gold vent cap (3.67) at the bob's
  low point; a round at the body's mid-height would reach past the 1.65 bound.
- **Four antimatter siphons** at Command Center 10 (`max_count` `[0,0,0,1,2,2,3,3,3,4]`); the
  template base lays the fourth out by itself (113 buildings, the bands unchanged; 1,140 draw
  calls and 1.71M primitives at the widest zoom on the Mac).
- **The vault's pylon caps** from the Obsidian tier are obsidian slabs on a thin gold lip; at L8
  the head is veined obsidian ringed by a gold filigree band at its foot, the emitter horn gold.
