# Model feedback pass (after the upgrade pass)

Status: **in progress, 2026-10-16**. The owner reviewed every max-level model after the upgrade
pass (`upgrade-pass.md`) and gave a list of problems. This file sorts that list, records the
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
