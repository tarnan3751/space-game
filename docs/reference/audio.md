# Audio

The game's sound: effects generated in code at build time, two free music tracks (**Music**) and
the node that plays them. Files:
`tools/gen_sounds.gd` (the generator), `src/game/sounds.gd` (`Sounds`, the recipes and the
weapons' sounds), `src/game/audio.gd` (`Audio`, the player), `assets/audio/sfx/` (the rendered
WAVs, each with its `.import`, committed), `assets/audio/music/` (the tracks, each with its `.import`, and `LICENSES.md`).

## The identity

Friendly comic synth, as vibrant as the comic look and toy-like rather than 8-bit harsh: sine and
triangle bodies, soft attacks on the UI, a short bright transient on a hit, pitch glides for shots
and whooshes, noise under a falling low-pass with a sub thump for a blast, a little chorus and echo
on chimes and fanfares. Nothing harsh for its own sake, nothing realistic and gritty. Short: UI
60–150 ms (a whoosh up to 250), shots 100–300 ms, impacts 150–400 ms, explosions 0.6–1.5 s, chimes
and stings 0.5–2 s.

## The generator

```
$GODOT --headless --path . -s res://tools/gen_sounds.gd [-- --only=laser_fire,ui_tap]
```

A `SceneTree` script, run after an import like `gen_textures.gd`. It renders every recipe in
`Sounds.TABLE` (or the keys `--only` names, leaving the other files alone) to
`assets/audio/sfx/<key>.wav`, 44.1 kHz, 16-bit, mono (`AudioStreamWAV.save_to_wav`), writes the
`.import` beside it, checks every file and prints a table: key, category, seconds, peak (dBFS),
the loudest 50 ms window's RMS, the whole file's RMS, and `ok` or the failed checks. It exits 1
when a recipe is unknown or a file fails a check. The gate does not run it.

**Deterministic.** Noise comes from `SeededRng`, seeded by an FNV-1a hash of the key (or the
recipe's `seed`), so a run writes byte-identical files. Floating-point `sin` may differ in its last
bit on another CPU; the files are committed, so only a regeneration on one machine is compared.

**The `.import` file** is written whole, in the importer's own format: PCM (`compress/mode=0`, not
the default QOA), no trim or normalise, `edit/loop_mode=1` (disabled) for a one-shot or `2`
(forward) with the loop over the whole file for a loop, the imported path
`res://.godot/imported/<file>-<md5 of the res:// path>.sample`, and the uid the file had (or
`ResourceUID.create_id_for_path`). The editor's import, the gate's first step included, leaves it
unchanged, so after a regeneration and the gate `git status` shows only the sounds that changed.

### Recipes

A recipe is a dictionary in `Sounds.TABLE`; every field has a default, so a recipe names only what
it changes:

```
"laser_fire": {"category": "shot", "seconds": 0.2, "layers": [
	{"wave": "triangle", "hz": [2200, 380], "glide": 0.14, "a": 0.002, "d": 0.15,
		"fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
	{"wave": "noise", "a": 0.001, "d": 0.02, "filter": {"type": "hp", "hz": 5000}, "db": -14}]},
```

| Recipe field | What | Default |
| --- | --- | --- |
| `category` | `ui`, `shot`, `impact`, `explosion`, `chime`, `sting` or `loop` (**Categories**) | required |
| `seconds` | the length rendered, before the trim | required |
| `layers` | the voices summed | required |
| `chorus` | `{ms, depth_ms, rate, mix}`: one delayed copy, its delay swinging | none (`12, 3, 0.8, 0.4`) |
| `echo` | `{ms, feedback, mix}`: decaying taps, a little room | none (`120, 0.3, 0.25`) |
| `drive` | tanh saturation, 0 to 1 | 0 |
| `peak_db` | the peak the normalisation never passes | -3 |
| `rms_db`, `min`, `max`, `priority`, `cooldown`, `bus` | the category's, overridden | the category's |
| `quiet` | the peak may sit down to -30 dBFS (a soft bed) | false |
| `loop` | a loop: no fades, its tail crossfaded into its head (30 ms), looped by the importer | false |
| `voices` | how many of this key sound at once (a further play takes its oldest) | 4 |
| `seed` | the noise's seed | FNV-1a of the key |

| Layer field | What | Default |
| --- | --- | --- |
| `wave` | `sine`, `triangle`, `saw`, `square`, `noise` (white), `pink` | `sine` |
| `hz` | the pitch, or `[start, end]` swept | 440 |
| `sweep`, `glide` | `exp` or `lin`; the seconds the sweep takes (0: the layer's length) | `exp`, 0 |
| `pulse` | the square's width | 0.5 |
| `vibrato` | `[rate Hz, depth cents]` | none |
| `a`, `d`, `s`, `len`, `r` | the envelope: attack (linear), decay to the sustain level, the gate before the release (0: attack plus decay), the release; decay and release are exponential, given as the seconds to fall 60 dB | 0.005, 0.1, 0, 0, 0.05 |
| `filter` | `{type, hz, q}`: `lp`, `hp`, `bp` (biquads) or `lp1` (one pole); `hz` a cutoff or `[start, end]` swept exponentially over the layer | none (`lp`, 1000, 0.707) |
| `fm` | `{ratio, index}`: a sine at `ratio` times the pitch modulating the phase, `index` or `[start, end]` | none |
| `ring` | `{hz}`: ring modulation | none |
| `at` | the start delay, seconds (a chime's notes are layers at their times) | 0 |
| `db` | the layer's gain | 0 |

**The master chain**, after the layers are summed: chorus, echo, drive; DC removal (a one-pole
high-pass at 20 Hz, then what mean is left); normalisation to the category's loudness (the loudest
50 ms window's RMS) capped so the peak stays at `peak_db`; then, for a one-shot, the trim (silence
under -60 dBFS cut at both ends, 2 ms kept) and the fades (a raised cosine in over 2 ms and out over
5 ms to exactly zero), or for a loop the crossfade; then 16 bits.

### The checks

Every file, read back with `AudioStreamWAV.load_from_file`:

- **format**: 44,100 Hz, 16-bit, mono, the samples as rendered;
- **peak**: at most -0.5 dBFS, at least -12 (-30 when `quiet`);
- **DC**: the mean at most 0.5% of full scale;
- **clicks**: a one-shot's first and last samples within 0.001 of zero, and no step in its first or
  last 2 ms above the larger of 0.05 and 1.5 times the largest step in the 20 ms beside them; a
  loop's wrap, last sample to first, no bigger than 1.5 times its largest step inside;
- **silence**: no run under -60 dBFS longer than 50 ms inside a one-shot;
- **length**: within the recipe's bounds (its category's unless it sets `min` or `max`);
- **loudness**: the loudest 50 ms window's RMS within 3 dB of the target; normalisation aims at it,
  so a miss is a recipe so peaky that the peak cap held it down (give it more body, or its own
  `rms_db`).

### Categories

`Sounds.CATEGORIES`, the defaults of the recipes in each:

| Category | Bus | Loudness (dBFS, 50 ms RMS) | Length (s) | Priority | Cooldown (s) |
| --- | --- | --- | --- | --- | --- |
| `ui` | UI | -20 | 0.06–0.15 | 3 | 0.04 |
| `shot` | SFX | -16 | 0.10–0.30 | 1 | 0.04 |
| `impact` | SFX | -15 | 0.15–0.40 | 2 | 0.04 |
| `explosion` | SFX | -12 | 0.6–1.5 | 3 | 0.06 |
| `chime` | SFX | -18 | 0.5–2.0 | 3 | 0.1 |
| `sting` | Music | -14 | 0.5–2.0 | 4 | 0.5 |
| `loop` | SFX | -22 | 0.5–8.0 | 5 | 0 |

## The Audio node

`Audio` (`extends Node`) is a child of `main`, made in code before the base's view, found as
`main.audio`. At boot it adds the buses `SFX`, `UI` and `Music`, each sending to `Master`, with no
bus layout resource, and an `AudioEffectHardLimiter` on `Master` (ceiling -0.3 dB) so many voices
summed never clip; it loads every file of the table once (`Dictionary[StringName, AudioStreamWAV]`;
a missing file is an error, which the gate's boot catches), makes `VOICES` (24)
`AudioStreamPlayer`s, two music players and a sting player, and reads the volumes.

| Call | What |
| --- | --- |
| `play(key, pitch_jitter = 0.06, volume_db = 0.0) -> bool` | Plays `key` once on its bus, its pitch varied up to `pitch_jitter` either way; whether it played. `&""` (a silent entry of `Sounds`' maps) plays nothing. Dropped while the key's cooldown runs (real time); a key already sounding on its `voices` takes its own oldest voice; else a free voice; else the least important, oldest one-shot no more important than it (loops are never taken); else dropped. Allocates nothing. |
| `schedule(key, delay_seconds, pitch_jitter = 0.06, volume_db = 0.0)` | Plays `key` through `play()` `delay_seconds` from now (real time), so cooldowns, voices and the log apply then: a burst's later shots, a trap's pop. A ring of `SCHEDULED` (64) entries, filled at boot; when it is full the oldest is dropped with a warning (once a run). Each drain plays and retires every entry that is due, those still waiting closed up behind the head in their order; it turns `_process` on and the drain turns it off when nothing waits. `scheduled_count()` says how many wait. |
| `loop(key, fade = 0.15) -> int`, `stop(id, fade = 0.15)` | A looping sound held on a voice of its own, faded in; stopped with a fade, freeing the voice. `loop` returns 0 when no voice could be had. A voice's fade is kept and ended when the voice is taken again or silenced, so it never runs on over the next sound there. |
| `set_loop_volume(id, db, fade = 0.15)`, `loop_level(id)` | Fades loop `id` to `db` (0 its full level), its fade-in included: the base's ambience ducked under a panel and back. `loop_level` is its level now, 0 to 1, or -1 when it is not sounding. |
| `music(key, fade = 1.0) -> bool`, `current_music()`, `music_playing()` | Crossfades to `assets/audio/music/<key>.ogg` (else `.mp3`), loaded by path, on the two music players, the new track from its start; `&""` fades the music out; the track already current is left playing. False, with a warning, when the track has no file. `music_playing()`: whether the current track's player is playing. |
| `sting(key) -> bool` | Plays the fanfare `key` (a `sting` recipe) on Music, the music ducked 8 dB under it (down in 0.1 s, back over 0.5 s after it). |
| `set_volume(bus, linear, keep = true)`, `volume(bus)` | A bus's volume, 0 to 1 (0 mutes it), for `Master`, `SFX`, `UI` and `Music`; with `keep` it is kept at once in `settings_path` (a slider being dragged sets it without, and keeps it when let go). |
| `set_muted(on)`, `is_muted()` | Mutes every sound, Master to 0, keeping the volume Master had (section `mute` of the settings) to bring back on unmute; so a mute outlasts the run. |
| `tap_buttons(root)` | Every `BaseButton` under `root` plays `ui_tap` (pitch varied 3%) when pressed, connected once however often it is asked: the attack HUD's buttons, until `BattleHud._button` plays the tap itself. |
| `drop_scheduled()` | Drops every scheduled play still waiting; what sounds plays on. A battle's end calls it (**Battle**). |
| `silence()` | Stops every sound (loops, music, stings), ends every fade and the duck, and drops the scheduled plays. |
| `shut_down()` | `silence()` for good, before a quit: every later `play`, `schedule`, `loop`, `music` and `sting` returns at once (**Quitting**). |

**Settings.** The volumes live in a `ConfigFile` at `settings_path`, section `volume`, one key a
bus, and section `mute`, the Master volume a mute took away; read at boot, written on every kept
`set_volume` and every mute; never in the save. It is `user://settings.cfg`,
except when `main.gd` runs with `--save-path`: then `settings.cfg` beside that save, so the gate and
the harness never read or write the owner's settings. The HUD's settings panel (the gear at the
top right, `hud.md`, **Settings**) calls these setters.

**Phones.** On `NOTIFICATION_APPLICATION_PAUSED` the Master bus is muted, and unmuted on
`RESUMED` (unless its volume is 0); a desktop window losing focus is not muted. `project.godot`
sets nothing for audio: the mix rate is the device's, the iOS session category the default.

**Quitting.** When `Audio` leaves the tree it silences everything. The mixer lets go of a stopped
sound a mix later, so a run that quits right after a sound played reports it as leaked resources at
exit; the harness driver shuts the sounds down and waits `SILENCE_SECONDS` (0.3 s) before it
quits, and `main` owns every other quit (`auto_accept_quit` off): a window's close request (after
the save) and the gate's boot (`--quit-frames`) shut down and wait `QUIT_SETTLE_SECONDS` (0.3 s)
before `quit()`: a count of frames is not enough, since headless they can all pass inside one mix.
Both waits are 0.3 s, not 0.1: a stopped playback is released by the audio thread's next mix step
(the Dummy driver mixes in large buffers, about 90 ms) and then collected by `AudioServer.update()` on
a later frame, and 0.1 s leaked in rendered runs.
`shut_down()` is `silence()` for good: after it `play`, `schedule`, `loop`, `music` and `sting`
return at once, so a shot or a finished building in those frames starts nothing to leak. Phones
mostly do not close through the window manager (the system ends the app, and nothing is reported),
but Android's back button quits the engine directly (`SceneTree.quit_on_go_back`, on by default),
skipping `main`'s quit, so a sound playing then is reported as leaked in logcat.

## Hooks

Where the game plays its sounds now. The hook lanes extend these; keep each file's sound calls in
one place.

| Event | Sound | Where |
| --- | --- | --- |
| A base HUD or sector map button pressed, by its kind | `ui_tap` (a primary), `ui_tap_soft` (a secondary or a close), `ui_tab` (a tab), `card_press` (a card), `cancel` (the place bar's Cancel), `map_close` (the map's close), none (a queue entry: its refund or refusal sounds) | `Hud._button`, `SectorMap._button` (their `tap` argument) |
| Any attack HUD button pressed | `ui_tap` | `main.open_battle`: `Audio.tap_buttons` |
| The build panel, the army panel or the settings panel opening, closing (every path: a button, a selection, placing), while the HUD shows (a battle opening hides it first, so a panel its deselection closes is not heard) | `ui_open`, `ui_close` | `Hud._slide_menu`, `_open_army`, `_close_army`, `_show_settings` |
| A disabled card (locked, unaffordable, no drone) tapped: the finger lifted within 16 px of where it came down, so a scroll says nothing | `ui_denied`, once a frame with a refusal's toast | `Hud._on_card_input`, `Hud._deny` |
| A toast, by kind | `toast_info`, `ui_denied` (a refusal, through `_deny`), `toast_reward`; a refund's `queue_refund` in its place | `Hud.show_message` (its `sound` argument) |
| A resource's meter filling (not on the first refresh, and not while the HUD is hidden: the base ticks on behind a battle) | `meter_full` | `Hud._set_full` |
| The ghost (or a dragged building) moving to another cell | `ghost_tick`, `ghost_tick_low` over a spot it cannot take; the wall brush's moves are quiet | `PlacementController._set_ghost_cell`, `_on_dragged` |
| A place applied | `place_ok`, then `build_start` 0.2 s later (`PLACE_TO_BUILD`, scheduled): the confirm's thunk, then the drone's whoosh | `PlacementController.confirm_place`, through `main._base_sound`'s delay |
| A wall placed (its 50 ms cooldown makes a fast stroke a ratchet; the brush's moves are quiet) | `wall_paint` | `PlacementController._paint` |
| A selected building lifted, set down (moved or not; a refused move's toast buzzes instead) | `drag_pickup`, `drag_drop` | `PlacementController._on_drag_started`, `_on_drag_ended` |
| A building tapped that was not selected (a re-tap is quiet), by its category | `select_building_<core, resources, army, defense, traps>` (`Sounds.SELECT`, `select_key`) | `PlacementController._on_tapped` |
| An upgrade applied | `build_start` | `PlacementController.upgrade_selected` |
| A construction finished (its view replaced with its drone) | `build_done`, unjittered | `BaseView.building_finished` → `main._base_sound` |
| The construction drone starting to fire. The cap is the recipe's, `voices` 2 and a 0.2 s cooldown: the first drones to fire sound, a third firing within 0.2 s is dropped, and one firing later takes the oldest of the two voices (no ranking by distance to the camera) | `laser_work` | `ConstructionDrone.advance`, through the `sound` `BaseView` hands its views (none on a battle's field) |
| A research done, a unit trained, an ability made, a trained head left waiting for room | `research_done`, `train_done`, `make_done`, `housing_full` | `main._hear_completions`, on `BaseState.changed`: counts compared, no event from core; a new base (boot, Reset, Template) counted quietly |
| The boot, after the HUD is up | `offline_boot` when the save's offline catch-up finished anything (its `buildings_revision` moved), else `boot_sting` | `main._ready`, `Audio.sting` |
| The base's ambience | `base_bed`, looping from the first frame, ducked 8 dB under the build, army or settings panel or the sector map, stopped while a battle runs, faded 0.6 s | `main._process` → `_set_bed` (`ambience()` is its loop's id, for the harness) |
| The sector map opening; a field's detail opening; a scan applied | `map_open`, `field_open`, `scan`; Attack plays only its tap, and the map closing for the battle is quiet | `SectorMap.open`, `show_field`; `main._on_scan_pressed` |
| A battle opening | `battle_start`, unjittered | `main.open_battle` |
| Everything in a battle | **Battle**, below | `BattleEffects`, `BattleView`, `BattleUnits`, `BattleHud` |
| Boot, once the save is loaded and the HUD up | music `base` | the end of `main._ready` |
| A battle opened | music `combat`, crossfaded over 1.5 s | `main.open_battle`, once the battle is added |
| A battle left (the result panel's Return) | music `base`, crossfaded over 2 s | `main._on_battle_finished` |

The base's sounds go through `main._base_sound`, which plays nothing while a battle runs in the
base's place: the base view keeps syncing out of the tree, so a construction finishing then would
otherwise chime over the battle.

**Temporary:** `tap_buttons` walks the attack HUD once, so a button built after its setup makes no
tap. Once `BattleHud._button` plays the tap itself, as `Hud._button` and `SectorMap._button` do, the
walk goes.

**Adding a sound:** a recipe line in `Sounds.TABLE` (and an entry in the battle's maps for a
weapon, a death or a trap: **Battle**);
`$GODOT --headless --path . -s res://tools/gen_sounds.gd -- --only=<key>` until its row reads `ok`;
one `audio.play(&"<key>")` at the event; commit the WAV and its `.import`.

## Music

Two tracks by vitalezzz, CC0 1.0 from OpenGameArt (https://opengameart.org/content/gravity-turn),
picked by the owner: written as a pair, the calm version for the base and the action version for
battle, "to crossfade from any point of calm version to the beginning of the action version",
which is why a battle's music starts from its beginning. Their source, licence and processing
are recorded in `assets/audio/music/LICENSES.md`, which ships beside them.

| Key | Track | Length | Loudness | True peak | Size |
| --- | --- | --- | --- | --- | --- |
| `base` | Gravity Turn (calm) | 177.231 s, 96 bars at 130 BPM | -18 LUFS integrated | -6.2 dBTP | 2.5 MB |
| `combat` | Gravity Turn (action) | 324.923 s, 176 bars at 130 BPM | -16 LUFS integrated | -2.6 dBTP | 5.7 MB |

**Loop points.** Each file is the composer's lossless loop file kept whole, an exact number of
bars, so the loop is the whole file (imported with `loop` on, `loop_offset` 0). The source files
start from silence and end mid-waveform, a step of up to 0.15 at the seam; a 10 ms raised-cosine
fade-out on the last 441 samples meets the silent start instead, keeping the bar-exact length a
crossfade would have shortened. Decoded, the seam's step is under 0.009, inside the waveform's
ordinary sample-to-sample motion.

**Loudness and encoding.** A plain gain to the targets (-0.5 dB and -3.0 dB, no limiter, so the
dynamics are the composer's), base below combat so the effects sit over both. Ogg Vorbis from the
FLACs with `oggenc` (vorbis-tools 1.4.3, `-q 4`, about 115 and 139 kb/s), 44.1 kHz stereo; Vorbis
adds no encoder delay (the decoded files match the sources sample for sample in length and
alignment), so no loop offset is needed, which MP3 would have. Replacing a track: the same
processing, the file as `<key>.ogg`, its `.import` with `loop=true`, and a line in `LICENSES.md`.

## Battle

Every event of a battle sounds, and every one is specific: by the weapon, the impact, the death, the
trap or the ability. The recipes are the table's battle section; the maps that pick them are beside
it in `Sounds`, every key of an enum present, a silence an explicit `&""` with its reason beside it:

| Map | Keyed by | What |
| --- | --- | --- |
| `FIRE_KIND`, `FIRE` | `Weapons.Kind`; a type id over it | a shot (`fire_key(type)`): `laser_fire`, `sentry_fire`, `missile_fire`, `shell_fire` (the plasma mortar's), `flak_fire`, `tracer_fire` (the dune runner's and the gunship's), `arc_zap`, `emp_pulse`, `railgun_fire`, `beam_fire`, `skimmer_beam`, `orbital_fire`, `bolt_fire` (the ranger's, the jet trooper's), `walker_fire`, `tank_fire`, `titan_fire`, `bomb_whistle`, `melee_swing`; silent: the gravity well (its hum is a loop), the breacher's charge (its blast is its sound), the traps, the shield, none |
| `LAND_IMPACT`, `LAND` | `Weapons.Impact`; a type id over it | a landing (`land_key(type)`): sparks and a ring `impact_small`, the blasts `explosion_small`, `_medium`, `_large`, `air_burst`, `plasma_splash`, `beam_burn`, `emp_zap`; the brawler's punch `punch_land`, the mega mine's `mega_blast`; none silent |
| `TWIN` | type id | a second play of the shot that many seconds on (the cloaked sentry's twin barrels, 40 ms) |
| `DEATH`, `DEATH_END` | `Weapons.Death` | a unit's death (`figure_down` for a figure and a jet trooper, `wreck_crunch`, `crash_whine`), and its effect's when it comes (a wreck's fireball `explosion_small` `WRECK_BLAST` of the way through, a crash's `explosion_medium` where it comes to rest, a jet trooper's `explosion_small`) |
| `TRAP_SPRING`, `TRAP` | `Weapons.Kind` of a trap | `trap_click` as any trap pops up, then `TRAP_POP` later by its kind: a mine's blast is its landing, the flak mine's `flak_crack`, the grav trap's `grav_whoosh` loop while its funnel spins |
| `EVENTS` | `BattleEvents` kind | the keys each arm of `BattleView._read_events` plays itself, past the maps above, for the `sounds_battle` scenario's coverage |

**Dated sounds.** Every sound of the field goes through `BattleEffects.sound(key, at, ...)`, `at` on
the battle's clock (seconds of battle, which 2x runs twice as fast): due now it plays, dated later it
is scheduled `(at - clock) / speed` real seconds ahead, the view handing the effects its clock and
speed each frame. So a burst's later shots keep their `burst_gap` at the battle's speed, the
cloaked sentry's twin its 40 ms, a trap's blast lands `TRAP_POP` after its click, and the strike's
bolt whine (`strike_bolt`) starts `STRIKE_WHINE` (0.5 s) of real time before it lands, peaking as it
does. A play is dated in real time at the speed when it is scheduled: toggling the speed before it
sounds leaves it as it was (a leftover, accepted). The battle ending (in the steps that end it,
before the attack HUD refreshes and schedules its stars' chimes, or at once on a surrender, which
ends it outside the steps), `leave()` and the view leaving the tree each call
`Audio.drop_scheduled()`, so nothing the field dated later (a strike's whine, a trap's blast, a
burst's later shots) sounds over the result or the base after Return.

| Event | Sound | Where |
| --- | --- | --- |
| A shot, its landing (a burst's later shots on their gap; a shell's launch and landing; a punch's swing and its landing) | by `FIRE`/`LAND` | `BattleEffects.fire`, `land`; `BattleView._unit_hit`, `_land_blows` |
| A shot arriving at a building; at a unit (a machine dies by wreck or crash) | `building_hit`; `unit_hit_figure`, `unit_hit_machine` | `BattleView._on_arrived` |
| A wall falling; a building falling, its rubble popping up; a trap's fall is silent | `wall_crumble`; `building_collapse`, `rubble_settle` | `BattleView._fall`, `_settle` |
| A cloaked sentry revealed | `reveal_shimmer` | `BattleView._decloak` |
| A unit dying, its death's effect | by `DEATH`, `DEATH_END` | `BattleView._death`, `_finish_deaths` |
| A trap springing; a unit thrown | by `TRAP_SPRING`, `TRAP`; `unit_thrown` | `BattleView._spring`; the `THROW` arm |
| A shield up (from none: at setup, and when its pool comes back), a shot absorbed, the dome gone | `shield_up`, `shield_hit`, `shield_down` | `BattleEffects.set_shield` |
| The EMP burst; each defence waking | `emp_burst`; `emp_wake` (cooldown 80 ms) | `BattleView._ability_used`, `_woke` |
| The repair swarm cast; the strike landing | `swarm_cast`; `strike_land` (with `strike_bolt` before it) | `BattleView._ability_used`, the `STRIKE_LAND` arm |
| A unit deployed (a tap, a smear, a script), by its class | `deploy_ground`, `deploy_air`, pitch varied 10% | `BattleUnits.after_step` |
| A star won (several at once 0.15 s apart); the loot rising; each of the last ten seconds; the speed toggled; End asking; a refused deploy's or cast's toast | `star_earned`, `loot_tick` (cooldown 120 ms), `timer_warning`, `speed_toggle`, `confirm_open`, `ui_denied` | `BattleHud._refresh`, `_on_speed`, `_on_end`, `_show_toast` |
| The battle over: the result's banner | `victory` (a star or more), `defeat`, as `Audio.sting` | `BattleHud._show_result` |

**Loops.** The view holds the sustained sounds as loops, one voice a key however many things keep it
on (`_hold_loop(key, on)`, started and stopped only on a change; `_loop_for(key, until)` for one
timed on the clock, stopped when it is up):

| Loop | Held |
| --- | --- |
| `battle_bed` | from `setup` to `leave()` (a low wind with gusts and a distant hum, -26 dBFS) |
| `air_bed` | while any air unit lives (`BattleUnits.air_alive()`) |
| `shield_hum` | while any shield generator's pool is up |
| `vortex_hum` | while a gravity well holds a unit, for its `hold_ms` from each pull |
| `emp_hold` | while any defence an EMP burst disabled is still out |
| `swarm_hum` | for a repair swarm's seconds |
| `strike_marker` | from a strike's cast until it lands |
| `grav_whoosh` | from a grav trap's spring until its funnel stops (`TRAP_POP` + `FUNNEL_SECONDS`) |

The battle's end stops every loop but the bed; `leave()` and the view leaving the tree stop that,
so no voice sounds after Return.

**Throttles.** A full army fires hundreds of shots a second; the categories' cooldowns and each
key's `voices` hold it to a sound a key every few frames, and the recipes' `priority` decides what a
full pool lets go first: the hits and a spark's `impact_small` (six voices) lowest (0), the shots
(1, the heavy ones 2), the impacts and the deploys (2), the blasts and the trap's click (3), the
mega mine's and the strike's landings highest (4, with the stings). The deaths have a 60 ms
cooldown and three voices each, a missile salvo 60 ms and three, the flak's pok 25 ms, the
tracers' tat 30 ms. A shot's
cooldown sits under its burst's gap at 2x, so a burst's shots all sound.

## The harness

Plays are recorded whatever the device: `run.sh` runs every scenario on Godot's Dummy audio driver,
on which players play and finish as on a real one, so the checks hold and nothing reaches the
speakers; a rendered run with `--audible` plays aloud, for a person listening.
The queries: `recent_plays()` (the last `RECENT`, 32, keys, oldest first) and `recent_times()`
beside it (`Time.get_ticks_msec()`), `play_count(key)` since boot, `playing_count()` (the pool's
voices sounding), `scheduled_count()`, `keys()`, `stream(key)`, `current_music()`, `music_playing()`. The `sounds` scenario checks the files, the buses, the
cooldown, the cap, a loop, scheduled plays, the music, the settings and every hook; `sounds_battle` the
battle's: the maps' coverage and a battle with every defence, trap, unit and ability, each of their
sounds heard, every loop held and none after Return (`tools/harness/README.md`). A loop is not a
play, so `BattleView.loop_starts(key)` and `loops_held()` say which the view held.

## Cost

`Audio` does no per-frame work while idle: no `_process` runs unless a play is scheduled (the
`sounds` scenario checks that the drain is off and no voice sounds); fades are Tweens. `play()` is timed under `Profile`'s
`audio` key, a column of the `profile` scenario's table. Mixing runs on the engine's audio thread,
which GDScript does not time. The effects' files are PCM, about 88 KB a second of sound; the music
is streamed Ogg Vorbis, decoded on the audio thread, loaded when `music()` first asks for a track.
