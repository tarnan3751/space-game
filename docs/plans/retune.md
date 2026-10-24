# The retune: real timers and a tuned economy (step 6a)

The record of the first real tuning of `data/`, which replaced the development values (builds of
seconds to an hour, training of seconds, research of minutes, a 60-second scan). Status:
**built**, 2026-10-24, the coordinator deciding under the owner's mandate
(`docs/project_overview.md` §3.1, **The retune**). It is written so a later retune can re-derive
every table from the development values and the rules below without the scripts that applied
them (§7).

## 1. Goals

From `docs/vision.md` §5 and the brief:

- **Pace.** Command Center 1 to 3 in the first two days of casual play; 4 to 6 over the
  following two weeks; 7 to 10 over two to three months. A top-level upgrade takes one to two
  days, the Command Center's last levels two to three, nothing above three days. The builders
  (the Drone Bays) are the parallelism limit.
- **Sessions.** Three or four ten-minute sessions a day always have something to do: queue a
  build, train an army (15 to 30 minutes at the top, faster low down), run an expedition or two.
  The battle stays at 180 seconds.
- **Expeditions are the loot engine**, and a full army of a Command Center level can beat its
  fields (§4).
- **Research is the long tail**: hours to a day a level at the top, at storage-scale prices.
  Making an ability takes minutes.
- A level's main upgrades need several hours of collecting or two or three raids.

## 2. What changed, and the rules that produce it

Everything is derived from the development values in `data/` at 300eec4. Rounding: prices to
two significant figures, half to even (1,850 becomes 1,800 and 1,950 becomes 2,000; about fifty
prices sit on an exact half); times below 2 minutes to 10 s, below an hour to the minute, below 10
hours to 5 minutes, above to 15 minutes. **Unchanged**: storage, counts, unlocks
(`requires_cc`, `requires_lab`, `producer_level`, `requires_foundry`), every building's combat
field, the Siphon's antimatter rates, the Hangar's and the Foundry's capacity, research prices,
the abilities' effects, the units' speeds, ranges, fire rates and splash, `rules.battle`, the
expedition bands, the starting resources and layout.

### Buildings (`buildings.json`)

- **Build times.** T(c) is the time of a 3×3 or bigger building's highest level requiring
  Command Center c: 15 min, 1 h 30, 3 h, 5 h, 8 h, 14 h, 22 h, 30 h and 40 h for c = 2 to 10.
  Each lower level of the type requiring the same c takes half the one above it; a 2×2 building
  or a trap takes two thirds; no level is shorter than the type's level before. Levels requiring
  Command Center 1 keep their 10 to 20 s, walls and the Drone Bay stay instant. The Command
  Center takes 5 min, 1 h, 4 h, 8 h, 14 h, 20 h, 30 h, 48 h and 66 h to reach levels 2 to 10.
  `test_shipped_build_times_stay_within_three_days` holds the three-day ceiling.
- **Costs.** Every level but the Command Center's own is multiplied by a factor set by its
  `requires_cc`: ×1 up to 4, then ×0.55, ×0.65, ×0.8, ×1.1, ×1.3 and ×1.5 at 5 to 10 (antimatter
  and walls included), rounded, capped at 95% of the storage reachable at that Command Center
  level rounded to two figures (1,900,000 metal at 9, 3,600,000 at 10), and never below the
  type's level before. Command Center 5 opens 136 timed jobs costing 24 times its
  storage in development prices, so it is made cheaper; the late levels are made dearer so that
  a top base spends what the raids bring rather than sitting on full storage. The walls take the
  factors too and are the late sink (13 times the storage at Command Center 10).
- **Production.** The Extractor and the Harvester produce 900, 1,000, 1,300, 1,800, 2,600,
  3,600, 5,000, 6,500, 9,000 and 14,000 an hour at levels 1 to 10. At the maxed count of each
  Command Center level that is 72%, 32%, 20%, 14%, 13%, 9%, 6%, 5%, 3% and 2.5% of the reachable
  storage an hour: generous while the player learns, then about half the income from Command
  Center 7 on, the raids the other half.

Samples (development → tuned): Laser Turret level 5, 15,000m 4,000c 50a in 15 min → 8,200m
2,200c 28a in 5 h; level 10, 770,000m 190,000c 3,900a in 40 min → 1,200,000m 280,000c 5,800a in
1 d 16 h; Command Center to level 10, 2 h 30 → 2 d 18 h at the same price; Metal Extractor level
10, 310,000c in 40 min producing 48,200 → 460,000c in 1 d 16 h producing 14,000.

### Units (`units.json`)

The Command Center level of a unit level is the one its lab level needs (`requires_lab`'s
`requires_cc` on the Research Lab), or, for level 1, the one its producer level needs.

- **Training time**: `train_seconds` ×6 (a Ranger 30 s, a Hover Tank 4 min 30, a Titan 12 min).
  The top army trains in about 26 minutes on its slowest producer, a Command Center 3 army in
  about 10.
- **Training price**: ×0.6 up to Command Center 3, ×0.7 at 4 and 5, then ×0.8, ×0.9, ×1.2, ×1.5
  and ×1.9 at 6 to 10, never below the level before. A full army costs 7.7%, 6.7%, 6.5% and 4.9%
  of the crystal storage at Command Center 3, 5, 7 and 10, about 30% of an even raid's crystal.
- **Research time** by the lab level a level needs, 1 to 10: 15 min, 30 min, 1 h, 2 h, 4 h, 6 h,
  9 h, 12 h, 18 h, 24 h.
- **Hull and damage** (the beatability lever, §4): ×0.85 up to Command Center 3, then ×1.35,
  ×1.6, ×1.45, ×1.3, ×1.3, ×1.28 and ×1.25 at 4 to 10, rounded, each level at least 5% above
  the one before. The development curve grew about ×1.12 a level against the defences' ×1.2, and
  lagged the five defence types Command Center 5 opens; the defences were left alone because
  they also defend players' bases in PvP, and the bands because an outpost should look like a
  real base.

Samples, the Ranger at levels 1, 4 and 8: hull 60, 84, 133 → 51, 113, 166; price 20, 49, 160 →
12, 34, 300 crystal; level 8's research 30 min → 1 day.

### Abilities (`abilities.json`)

Making takes 180, 300 and 360 s (the Repair Swarm, the EMP Burst, the Orbital Strike), so a top
Foundry's six refill in about the army's time. Make prices take the units' training factors at
the same Command Center level (the Foundry level's for level 1); research levels take the units'
research times. Samples, the EMP Burst at levels 1, 3 and 5: 2,500c → 1,800c; 4,300c 10a →
5,200c 12a; 7,000c 35a → 13,000c 66a.

### Rules (`rules.json`)

- `expedition.scan_seconds` 60 → 10,800: three hours, so each of three or four daily sessions
  finds a fresh sector of six fields.
- `premium`: `{"currency": "antimatter_shards", "skip_minutes_per_shard": 10}`, reserved and read
  by no code. The timers were chosen with it in mind: a top level's 40 hours is 240 units, the
  Command Center's 66 hours 396.
- No `expedition.cost`: charging one is a rule change. The spent army and the scan are the gates.

## 3. The progression model

The pace was checked with a model of maxing each Command Center level, from a base maxed at the
level below:

- **Jobs at level k**: for each type, the copies the level below allowed take every level its
  new best allows; the new copies take every level from 1; then the Command Center's own upgrade
  to k + 1. Walls are counted apart (instant, metal only). Research is every unit and ability
  level whose lab level the lab of k reaches and the lab of k − 1 did not.
- **Builders**: the Drone Bay count at k (2, 3, 4, then 5), each busy 75% of the time. Days by
  builders = the jobs' build seconds ÷ (builders × 86,400 × 0.75).
- **Income a day**, per resource: the maxed production of k − 1 and of k averaged, × 24 × 0.8
  (some lost to full storage overnight), plus four raids a day at 17% of the reachable storage of
  k each (the measured mean, §4), less four armies' training price. Days by resources = the jobs'
  price ÷ that income.
- **The armies** are the matrix's (§4); levels are the best the lab of k can have researched.

| CC | timed jobs | days by builders | price ÷ storage (m / c) | days by resources (m / c) | without raids (m) | walls (÷ storage) | research jobs, lab days | reached on day |
|---|---|---|---|---|---|---|---|---|
| 1 | 10 | 0.0 | 1.5 / 0.3 | 0.1 / 0.0 | 0.1 | 0.5 | 0, 0.0 | 0 |
| 2 | 30 | 0.1 | 2.1 / 2.0 | 0.4 / 0.4 | 0.4 | 0.9 | 4, 0.1 | 0.1 |
| 3 | 58 | 0.8 | 4.3 / 2.3 | 1.2 / 0.7 | 1.4 | 1.3 | 3, 0.1 | 0.5 |
| 4 | 94 | 2.1 | 7.6 / 4.3 | 2.8 / 1.7 | 3.7 | 1.7 | 5, 0.4 | 1.7 |
| 5 | 136 | 5.1 | 14.4 / 6.1 | 5.4 / 2.6 | 7.3 | 2.4 | 6, 1.0 | 4.5 |
| 6 | 71 | 6.1 | 11.7 / 7.7 | 5.4 / 4.0 | 7.9 | 2.9 | 12, 3.0 | 9.9 |
| 7 | 139 | 14.3 | 19.9 / 9.0 | 11.6 / 6.2 | 19.3 | 4.3 | 7, 2.6 | 16 |
| 8 | 101 | 18.8 | 19.5 / 10.4 | 13.6 / 8.5 | 25.9 | 7.2 | 9, 4.5 | 30 |
| 9 | 123 | 29.6 | 24.9 / 13.3 | 20.8 / 13.4 | 47.9 | 9.8 | 12, 9.0 | 49 |
| 10 | 114 | 44.2 | 33.6 / 18.2 | 31.0 / 20.6 | 83.5 | 13.0 | 14, 14.0 | 79 (maxed about 123) |

"Reached on day" adds up the larger of the two days columns. So Command Center 3 comes in half a
day, 7 on day 16, 10 on day 79. With raids, resources keep up with the builders from Command
Center 6 on (0.7 to 0.9 of the builder days, the walls absorbing the rest); without them a
player falls 1.4 to 1.9 times behind. A median level costs 0.5 h of production at Command Center
3, 1.2 h at 5, 4.7 h at 7 and 12 h at 10, or one or two raids; the dearest level and the Command
Center's own next level cost two or three raids to Command Center 5 and four to six (or a day to
a day and a half of production) at 7 to 9, saved for across the stage while the builders work.
Antimatter takes 2.8 days at Command Center 9 and 10 at 10.

## 4. Beatability

**Measured with** `tools/sim_matrix.sh` (`testing-tools.md`): `tools/sim_battles.gd` against
fields 0 (easy), 2 (even) and 4 (hard) of sector seeds 1 to 20, epoch 0, laid out against a
player at full capacity, at Command Center 3, 5, 7 and 10, each with the strategies `edge`,
`two_edges` and `waves` (`random` is reported, not judged: it scatters over inner pockets). The
army is the full housing of the level, at the levels its lab allows:

- 3 (70): 30 Rangers, 4 Breachers, 12 Brawlers, 4 Dune Runners.
- 5 (135): 2 Hover Tanks, 2 Siege Walkers, 1 Gunship, 6 Breachers, 15 Brawlers, 10 Jet
  Troopers, 35 Rangers.
- 7 (220): 1 Titan, 4 Hover Tanks, 2 Siege Walkers, 2 Gunships, 2 Bombers, 8 Breachers, 20
  Brawlers, 10 Jet Troopers, 5 Skimmers, 33 Rangers.
- 10 (280): 2 Titans, 5 Hover Tanks, 2 Siege Walkers, 2 Gunships, 3 Bombers, 8 Breachers, 20
  Brawlers, 10 Jet Troopers, 10 Skimmers, 44 Rangers.

**The acceptance rules**: on the even field, two stars or more with the best strategy and one
or more with every strategy, each on most seeds; on the hard field one or more with the best on
most seeds; on the easy field three stars with most strategies.

**No abilities are brought**: an expedition's setup carries none until the Foundry HUD lane
wires them, so these numbers are the conservative measure; abilities only add headroom.

The final tree (share of seeds at ≥ 1 / ≥ 2 / 3 stars; mean metal loot as % of capacity):

| CC | band | edge | two_edges | waves | loot (best) |
|---|---|---|---|---|---|
| 3 | easy | 100 / 100 / 100 | 100 / 100 / 100 | 100 / 100 / 100 | 15 |
| 3 | even | 100 / 100 / 80 | 95 / 95 / 80 | 100 / 95 / 70 | 24 |
| 3 | hard | 70 / 10 / 0 | 45 / 10 / 0 | 55 / 5 / 0 | 12 |
| 5 | easy | 100 / 100 / 100 | 100 / 100 / 100 | 100 / 100 / 100 | 15 |
| 5 | even | 95 / 75 / 15 | 90 / 60 / 5 | 90 / 70 / 15 | 17 |
| 5 | hard | 70 / 40 / 0 | 65 / 25 / 5 | 90 / 65 / 0 | 25 |
| 7 | easy | 100 / 100 / 100 | 100 / 100 / 100 | 100 / 100 / 100 | 15 |
| 7 | even | 100 / 95 / 40 | 100 / 85 / 35 | 100 / 100 / 30 | 23 |
| 7 | hard | 100 / 55 / 0 | 90 / 45 / 0 | 95 / 70 / 0 | 27 |
| 10 | easy | 100 / 100 / 95 | 100 / 100 / 100 | 100 / 100 / 100 | 15 |
| 10 | even | 100 / 75 / 0 | 100 / 70 / 0 | 100 / 85 / 5 | 20 |
| 10 | hard | 70 / 35 / 0 | 40 / 30 / 0 | 75 / 25 / 0 | 23 |

Every rule passes. The loot column is the mean metal taken as a percent of the player's
capacity, the Command Center at the player's level (the tools first counted it one level high,
which scaled the loot targets and the capacity alike, so the percentages did not move when it was
corrected). The median battle length of a cell (one Command Center level, band and strategy,
`edge`, `two_edges` or `waves`) runs 25 to 77 seconds on the easy fields, 90 to 172 on the even
and 105 to 180 on the hard; a battle simulates in 250 to 400 ms headless on the development Mac.
The sim's path-search change (482e988) changed no outcome of the matrix.

**Before** (the development data, the same matrix): even fields gave one star or more on 10 to
20% of seeds at Command Center 5 and two stars on at most 10%; hard fields at 5 gave none; even
at 10 gave two stars on 25 to 35%; even at 3 gave three stars on 85 to 95%.

**The template base** (every type at its Command Center 10 count and top level, 250 walls)
against the Command Center 10 army above, ten seeds: the three edge strategies reach 16 to 22%
mean destruction (two stars on one seed in ten each), a scattered deploy into its open pockets
(`random`) about 50% and two stars on about four seeds in ten. Raids on maxed player bases are
Milestone 3's tuning.

## 5. Saves

No save format changes. Timers in flight (`finish_at`, a queue head's `done_at` or `left`,
`research_done_at`, the sector's `last_scan`) finish at their saved times; the new times apply
from the next start. A unit or ability queued before the retune and cancelled after it is
refunded at the tuned price of the level it was paid at (`core-economy.md`, **Cancel**).

## 6. Findings left for other briefs

- `Format.duration` has no days ("66h 00m"); the Foundry HUD lane adds them.
- An expedition cost stays unadded (§2, Rules).

## 7. The scripts

The tables were applied by Python scripts kept in the developer's scratch directory, not in the
repository (the project has no Python tooling): `retune.py` (the development data in, the tuned
data out, by the rules of §2), `patch_numbers.py` (rewrote the numbers into the hand-formatted
JSON), `econ.py` (the model of §3), `tables.py` (the before and after tables, level by level),
`report.py` (the matrix's summary) and `scale_units.py` (the experiments that set the unit
factors). §2 and §3 state everything they computed; `tools/sim_matrix.sh` re-runs §4.
