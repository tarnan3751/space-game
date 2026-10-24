# Space Game — vision

Last updated: 2026-10-24. Written when the owner settled the six design calls that open
Milestone 2, after the model feedback pass (main at 7be07cf).

This file says what the game is meant to become, in enough detail to plan the steps that build
it. `docs/project_overview.md` holds the status, the roadmap table and the list of decisions;
this file holds the design behind them. The reference files under `docs/reference/` and the
code are the authority on how a built mechanism works. Where this file and the overview
disagree, the overview's roadmap and decisions win; where either disagrees with the code, the
code wins.

## 1. The fantasy

The player commands a frontier colony on a regolith world: a base of chunky, brightly painted
machines under a warm sun, drawn as a pulp sci-fi comic. They mine metal and crystal, later
siphon antimatter, and spend it on a base that grows from a Command Center and two extractors
into a black-and-gold fortress ringed by walls, turrets and an orbital cannon. They raise an
army of machines crewed by their colonists, send it out to raid the rival colonies of the
sector for loot, and later attack other players' colonies, which defend themselves while their
owners are away.

The tone is bright and adventurous, never grim. Every tier, every unit and every effect keeps
the comic style (`docs/reference/art-style.md`): bold masses, ink outlines, saturated accents,
glows that pop, restraint in detail.

## 2. Pillars

The overview's design philosophy (§1.2) stands: a pure deterministic core, commands not
mutations, data-driven balance, light on the phone, one code path for desktop and phone,
agent-editable. The vision adds four pillars, settled by the owner on 2026-10-24.

- **Offline first.** The base, the army and expeditions run entirely on the local save and the
  local battle sim. Nothing in Milestone 2 needs a server. PvP is the first feature that does,
  and it comes after the loop is proven fun.
- **One battle sim, two opponents.** There is one deterministic battle simulation in
  `src/core/`. In expeditions it defends a generated outpost; in PvP it defends a player's saved
  base. The sim does not know which. A replay is a seed, two layouts and a list of commands,
  and the server will later verify battles by replaying them in headless Godot.
- **Clash's control model.** The attacker deploys units at the edge of the field and the units
  path and pick targets on their own. The attacker's other input is a small set of abilities.
  There is no direct unit control, which would need a second input system and defeat replays.
- **A machine army with a human crew.** The visible army is mostly machines piloted by
  humanoids, with some autonomous machines. Humans and humanoid robots appear as figures: as
  pilots, as crew round the base and as units of their own where a design calls for one. The
  figures are built from rigid parts in code, in the comic style, like everything else.

## 3. The loops

### 3.1 The base

Built (Milestone 1; `docs/project_overview.md` §2.1). Placement, timers, builders, the integer
economy, the Command Center gates, the 33-type roster to Command Center 10 in five tiers, the
save with offline progress. Milestone 2 adds to it: training, research and the loot that
expeditions bring home all land in `BaseState` through new commands.

### 3.2 The army

The army buildings already in the roster take these roles:

| Building | Role |
| --- | --- |
| Cadet Academy | Trains the human crew: the colonists who pilot the machines, and any human unit the roster calls for. Unlocks at Command Center 1. |
| Fabricator | Builds light machines. |
| Heavy Fabricator | Builds heavy machines (from Command Center 4). |
| Drydock | Builds ships, the air units (from Command Center 5). |
| Hangar | Houses the army; its `capacity` is the army size in housing units. |
| Research Lab | Upgrades unit types level by level. |
| Nanite Foundry | Makes the abilities the attacker uses in battle: a repair swarm, an EMP burst, an orbital strike and the like. |
| Alliance Beacon | Holds borrowed units. Reserved for Milestone 4; it does nothing in Milestone 2. |

The unit roster itself (which machines, which crewed and which autonomous, which are ground
and which air, how many housing units each takes, their stats) is designed in the step 3 plan,
along with training as a timed queue of commands and the housing rule. Defences and traps
already carry `targets` (ground, air, both), so the roster's ground/air split is fixed by the
data that exists.

### 3.3 Battle

A battle is the attacker's army against a defended layout on a 48×48 field. The attacker
chooses where along the edge to deploy and when to use an ability; everything else is the sim.

- **Fixed-point and fixed tick.** Positions in integer field units (1 cell = 1000 units),
  a fixed tick, `SeededRng` for every random choice, ties broken by id. The same seed, layouts
  and commands give byte-identical results on every device.
- **Units** path round walls or break through them, pick targets by their type's preference,
  and fight with the stats of their level. Ground units are stopped by walls; air units are not.
- **Defences** fire at what they can target (`targets`) within `range_cells` every `fire_ms`,
  for `damage`. Buildings with range and no damage are status effects: the Shield Generator
  protects what is in range, the Gravity Well holds air units, the Grav Trap displaces. The
  Cloaked Sentry and every trap are `hidden` until they act. The exact rule of each is set in
  the step 4 plan.
- **Abilities** come from the Nanite Foundry and are the only other thing the attacker does.
- **Ending.** A fixed battle length. Three stars: destruction past a threshold, the Command
  Center destroyed, and everything destroyed. Loot is a share of the defender's stored
  resources, capped by what the attacker can carry.
- **The view** draws the sim: units moving, projectiles, buildings taking damage and falling,
  a battle HUD with the deploy bar, the timer, the stars and the loot. The view never decides
  anything; it reads the sim's state each tick.

### 3.4 Expeditions

An expedition is a battle against a generated outpost. The player opens a sector map of fields
generated from seeds, each with a difficulty band, a loot profile and a terrain. They pick one,
pay the expedition's cost, fight the battle, and the loot lands in the base through a command.

- **The outpost generator** lays out a rival colony on a 48×48 field from a seed: buildings
  from the player's own roster at levels set by the difficulty band, walls, defences and traps,
  plus loot deposits (destroyable caches that drop resources) and hazards that act as
  defences. The field's terrain comes from the same seed.
- **The enemy** in Milestone 2 is rival colonies built from the player's roster with a faction
  tint, so all 259 models and every defence stat are reused. A distinct alien or pirate faction
  with models of its own is a later content pass, after the online game.
- **Difficulty** tracks the Command Center level, so a sector always offers fields the player
  can beat and fields that stretch them.
- Expeditions are the sim's first consumer and the first time the game has a complete loop:
  build, train, raid, loot, upgrade.

### 3.5 Attacks on players (Milestone 3)

The same battle against another player's saved base, through the server: accounts, the base
stored on the server, commands validated there, matchmaking, a defence log with replays,
shields after a loss, revenge, a league ladder. The local save migrates to the account on first
sign-in. Nothing in the sim changes; the defender's layout comes from the server instead of the
generator.

### 3.6 Alliances (Milestone 4)

Membership, unit donations through the Alliance Beacon, alliance wars later.

## 4. The figures

The humans and humanoid robots the army needs are a design of their own, and it comes first in
Milestone 2 at the owner's request. The earlier figure, the troopers of the model passes,
read as a blocky toy and was rejected; a figure has to read as a character in the comic style
at the game camera's zoom: a strong silhouette, a few big masses, chamfered and rounded forms,
ink outlines, a readable accent, and parts pivoted so it can walk. A spacesuit with a visor is
the natural human of this world; a humanoid robot shares the skeleton with a sensor head and
visible joints. The study delivers both, rendered for the owner to judge, before any unit model
is built on them. It is built and approved (2026-10-24; `docs/reference/art-style.md`,
**Figures**): the colonist at 3.5 heads and the automaton are the base of every figure, and
figures carry a thinner ink line than buildings so they stay readable at the gameplay zoom.

## 5. Progression, time and money

- The Command Center's ten levels and five tiers are the spine of progression; the army and
  the research tree hang off them.
- Sessions are short and frequent: check the base, collect, queue builds and training, run an
  expedition. A battle is a few minutes.
- Build and training times are on the development scale until Milestone 2 plays end to end;
  then one data-only retune sets the real curve.
- The economy keeps a slot for a premium currency (skipping timers, cosmetics), but nothing is
  sold until PvP exists. The retune is designed with that slot in mind.

## 6. Platform

Native iOS and Android on the GL Compatibility renderer, light enough for mid-range phones.
The maxed base is unmeasured on a phone, and a battle with a full army at the top (the Hangars'
280 housing) over a hundred buildings is the real test, so Milestone 2 fixes a target device and frame rate and
measures on it when the battle view exists (step 5). That measurement decides whether the
Crown robots stay and what the unit budgets are.

## 7. Milestones

| Milestone | What it delivers | Steps |
| --- | --- | --- |
| 1. The offline base | Build and upgrade a base; save with offline progress | 1, 2, 2a, 2b (built) |
| 2. The offline game | A complete loop with no server: army, battles, expeditions, real timers | 3 figures and army, 4 battle sim, 5 battle view, 6 expeditions, 6a retune |
| 3. The online game | Accounts, the base on the server, async PvP | 7 server, 8 PvP |
| 4. The social game | Alliances; a distinct PvE faction; the store release | 9 alliances, then content |

The step table with statuses is `docs/project_overview.md` §2.2. Each step gets a plan under
`docs/plans/` when it starts, as the upgrade pass did.

## 8. Out of scope

Not planned, so an agent that meets one of these stops and reports rather than building it:

- Direct control of units in battle, or any real-time multiplayer.
- An expedition mini-game separate from the battle sim, or expeditions that resolve without a
  battle.
- A distinct enemy faction with its own models before Milestone 3 is done.
- Anything sold, or a store, before PvP exists.
- C#, addons, downloaded assets, hand-written scenes.

## 9. Open

- **The name.** "Space Game" is a placeholder.
- **The phone target** (device and frame rate), to be fixed before step 5.
- **The unit roster and the housing rule**, and whether deployed units are spent (Clash's
  model) or survive with repairs: the step 3 plan.
- **The humanoid design**: the study of §4.
