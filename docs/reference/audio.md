# Audio

The game's sound: effects generated in code at build time and the node that plays them. Music is
free tracks chosen separately (none are in yet; the API takes them by key). Files:
`tools/gen_sounds.gd` (the generator), `src/game/sounds.gd` (`Sounds`, the recipes and the
weapons' sounds), `src/game/audio.gd` (`Audio`, the player), `assets/audio/sfx/` (the rendered
WAVs, each with its `.import`, committed), `assets/audio/music/` (the tracks, later).

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
| `play(key, pitch_jitter = 0.06, volume_db = 0.0) -> bool` | Plays `key` once on its bus, its pitch varied up to `pitch_jitter` either way; whether it played. Dropped while the key's cooldown runs (real time); a key already sounding on its `voices` takes its own oldest voice; else a free voice; else the least important, oldest one-shot no more important than it (loops are never taken); else dropped. Allocates nothing. |
| `schedule(key, delay_seconds, pitch_jitter = 0.06, volume_db = 0.0)` | Plays `key` through `play()` `delay_seconds` from now (real time), so cooldowns, voices and the log apply then: a burst's later shots, a trap's pop. A ring of `SCHEDULED` (64) entries, filled at boot; when it is full the oldest is dropped with a warning (once a run). Each drain plays and retires every entry that is due, those still waiting closed up behind the head in their order; it turns `_process` on and the drain turns it off when nothing waits. `scheduled_count()` says how many wait. |
| `loop(key, fade = 0.15) -> int`, `stop(id, fade = 0.15)` | A looping sound held on a voice of its own, faded in; stopped with a fade, freeing the voice. `loop` returns 0 when no voice could be had. A voice's fade is kept and ended when the voice is taken again or silenced, so it never runs on over the next sound there. |
| `music(key, fade = 1.0) -> bool`, `current_music()` | Crossfades to `assets/audio/music/<key>.ogg` (else `.mp3`), loaded by path, on the two music players; `&""` fades the music out. False, with a warning, when the track has no file. |
| `sting(key) -> bool` | Plays the fanfare `key` (a `sting` recipe) on Music, the music ducked 8 dB under it (down in 0.1 s, back over 0.5 s after it). |
| `set_volume(bus, linear)`, `volume(bus)` | A bus's volume, 0 to 1 (0 mutes it), for `Master`, `SFX`, `UI` and `Music`; set is kept at once in `settings_path`. |
| `tap_buttons(root)` | Every `BaseButton` under `root` plays `ui_tap` (pitch varied 3%) when pressed, connected once however often it is asked. |
| `silence()` | Stops every sound (loops, music, stings), ends every fade and the duck, and drops the scheduled plays. |
| `shut_down()` | `silence()` for good, before a quit: every later `play`, `schedule`, `loop`, `music` and `sting` returns at once (**Quitting**). |

**Settings.** The volumes live in a `ConfigFile` at `settings_path`, section `volume`, one key a
bus; read at boot, written on every `set_volume`; never in the save. It is `user://settings.cfg`,
except when `main.gd` runs with `--save-path`: then `settings.cfg` beside that save, so the gate and
the harness never read or write the owner's settings. There is no settings screen yet; it calls
these setters.

**Phones.** On `NOTIFICATION_APPLICATION_PAUSED` the Master bus is muted, and unmuted on
`RESUMED` (unless its volume is 0); a desktop window losing focus is not muted. `project.godot`
sets nothing for audio: the mix rate is the device's, the iOS session category the default.

**Quitting.** When `Audio` leaves the tree it silences everything. The mixer lets go of a stopped
sound a mix later, so a run that quits right after a sound played reports it as leaked resources at
exit; the harness driver shuts the sounds down and waits `SILENCE_SECONDS` (0.1 s) before it
quits, and `main` owns every other quit (`auto_accept_quit` off): a window's close request (after
the save) and the gate's boot (`--quit-frames`) shut down and wait `QUIT_SETTLE_SECONDS` (0.1 s)
before `quit()`: a count of frames is not enough, since headless they can all pass inside one mix.
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
| Any HUD button pressed (the base's HUD and the sector map, at setup; the attack HUD, when a battle opens) | `ui_tap` | `main._wire_audio`, `main.open_battle`: `Audio.tap_buttons` |
| Build pressed, the panel opening or closing | `ui_open`, `ui_close` | `main._wire_audio`, reading `hud.is_menu_open()` after the HUD's own handler |
| The build panel's Close | `ui_close` | `main._wire_audio` |
| A building tapped that was not selected (a re-tap is quiet) | `select_building` | `PlacementController._on_tapped`, through its `sound` (`main._base_sound`) |
| A place or an upgrade applied | `build_start` | `PlacementController.confirm_place`, `upgrade_selected`, through its `sound` |
| A construction finished (its view replaced with its drone) | `build_done`, unjittered | `BaseView.building_finished` → `main._base_sound` |
| A shot (`Sounds.FIRE`: laser_turret → `laser_fire`, plasma_mortar → `shell_fire`, missile_battery → `missile_fire`) | by type | `BattleEffects.fire`, a burst's later shots scheduled `burst_gap` apart |
| A landing (`Sounds.LAND`: laser_turret → `impact_small`, plasma_mortar and missile_battery → `explosion_medium`) | by type | `BattleEffects.land` |
| The battle's end | `victory` (a star or more), `defeat` | `BattleView.ended` → `main._on_battle_ended`, `Audio.sting` |

The base's sounds go through `main._base_sound`, which plays nothing while a battle runs in the
base's place: the base view keeps syncing out of the tree, so a construction finishing then would
otherwise chime over the battle. `shield_hum`, a loop, has no hook yet (the battle lane's).

**Temporary:** `tap_buttons` walks the HUD once, so a button built after setup makes no tap and a
disabled one (a locked card) makes no sound. Once the HUD's three button helpers (`Hud._button`,
`BattleHud._button`, `SectorMap._button`) play the tap themselves, the walk goes.

**`land()` at a later time.** `BattleEffects.land` plays at the call; a landing dated later (a
trap's, after `TRAP_POP`) needs `schedule` with the delay instead.

**Adding a sound:** a recipe line in `Sounds.TABLE` (and a `FIRE` or `LAND` entry for a weapon);
`$GODOT --headless --path . -s res://tools/gen_sounds.gd -- --only=<key>` until its row reads `ok`;
one `audio.play(&"<key>")` at the event; commit the WAV and its `.import`.

## The harness

Plays are recorded whatever the device: `run.sh` runs every scenario on Godot's Dummy audio driver,
on which players play and finish as on a real one, so the checks hold and nothing reaches the
speakers; a rendered run with `--audible` plays aloud, for a person listening.
The queries: `recent_plays()` (the last `RECENT`, 32, keys, oldest first) and `recent_times()`
beside it (`Time.get_ticks_msec()`), `play_count(key)` since boot, `playing_count()` (the pool's
voices sounding), `scheduled_count()`, `keys()`, `stream(key)`. The `sounds` scenario checks the files, the buses, the
cooldown, the cap, a loop, scheduled plays, the settings and every hook
(`tools/harness/README.md`).

## Cost

`Audio` does no per-frame work while idle: no `_process` runs unless a play is scheduled (the
`sounds` scenario checks that the drain is off and no voice sounds); fades are Tweens. `play()` is timed under `Profile`'s
`audio` key, a column of the `profile` scenario's table. Mixing runs on the engine's audio thread,
which GDScript does not time. The files are PCM, about 88 KB a second of sound.
