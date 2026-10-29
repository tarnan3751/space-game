# The sound pass (2026-10-29)

The record of the pass the owner asked for after the UI pass: "the defenses, army, shooting,
explosions/impacts to all have specific and well made generated sounds", "sound effects across the game
when clicking into menus, starting battles, and clicking on buildings", "sounds for anything I forgot",
and for combat and the base "free music that fits the style and setting of the game", reviewed for gaps
("missing sounds, weird stutters/hitches") before coming back. `docs/project_overview.md` §3.1 holds the
decisions; `docs/reference/audio.md` describes the sound as it is now; this file holds the method, what
was built, the numbers and what was left.

## 1. The ask and the method

Nobody on the building side can listen, so the pass was run on objective checks and the owner's ear at
the end. The order: an inventory of every moment that could sound, written from the code (every hook as
`path:line`, by surface); the engine facts (an `AudioStreamWAV` written by a tool script must set its
16-bit format, `save_to_wav` writes the file, the default WAV import is QOA so the `.import` files pin
PCM, no runtime synthesis on phones); a sound identity written down before any recipe (`audio.md`, **The
identity**: friendly comic synth, toy-like rather than 8-bit harsh, short); then the foundation, then
three hook lanes on it, each reviewed.

- **The generator and the node first.** `tools/gen_sounds.gd` renders every recipe of `Sounds.TABLE`
  to `assets/audio/sfx/<key>.wav` deterministically (a seed per key, byte-reproducible: a regeneration
  leaves `git status` clean) and refuses a file that fails its checks: peak between -0.5 and -12 dBFS,
  DC under 0.5 %, no click at either edge, no silence over 50 ms inside a sound, duration within its
  category's bounds, loudness within 3 dB of the category's RMS target, a loop's seam. The `Audio` node
  plays by key with 24 voices, three buses and a limiter, per-key cooldowns and voice counts, priority
  stealing, loops, a ring of scheduled plays, music crossfades, stings that duck the music, and the
  volumes in a `ConfigFile`. The harness records every play, so a scenario checks what sounded, when,
  and how many times (`heard_counts`, `check_heard`).
- **Silent testing.** The owner's rule, set on the first day: no test sound through the Mac's
  speakers. `tools/harness/run.sh` runs every scenario on Godot's Dummy audio driver, on which players
  play and finish as on a real one; `--audible` exists for a person listening and no lane uses it.
- **The music**, from 17 CC0 candidates downloaded with their licence records and put on a page of
  60 s loudness-matched previews for the owner, who picked the Gravity Turn pair (vitalezzz, calm for
  the base, action for battle, written to crossfade) and rejected the CC0 victory sting in favour of a
  generated one. The composer's lossless loop files, kept whole (bar-exact: 96 and 176 bars at
  130 BPM), a 10 ms tail fade, -18 and -16 LUFS, Ogg Vorbis through `oggenc`, `LICENSES.md` beside
  them. Landing the music showed that the engine reports a playing sound as leaked at exit, so `main`
  now owns quitting: `Audio.shut_down()` (silence, then refuse every later play) and a 0.3 s settle
  before `quit()`, the gate's boot through `--quit-frames`.
- **The UI, the base and the expedition**: every tap from the HUD's and the sector map's button
  helpers by the kind of button, the panels, the toasts by kind and the refusal's buzz once a frame,
  placing (the ghost ticking from cell to cell, lower over a cell it cannot take, the confirm's thunk
  then the drone's whoosh, a ratchet per wall painted, lift and drop), a building tapped by its
  category, completions by a state diff (construction, training, research, making, a full housing), a
  meter filling, the boot's sting or the offline welcome, the construction laser, the base's ambience
  bed ducked under a panel and stopped for a battle, the sector map's opening, scan and field detail,
  and the settings gear (Music and Sound sliders, Mute, kept in the settings file beside the save). On
  the way, the construction drone's release while the base view is out of the tree (the
  `!is_inside_tree()` error every battle had logged since the model pass) was fixed.
- **The battle**: a shot per weapon kind with overrides per type, a landing per impact kind, hits by
  what was hit, falls and collapses, deaths by class with their fireball, traps springing and blasting,
  shields up and down, the EMP, the gravity well, the strike's whine and landing, the swarm, deploys by
  class, the air units' hum, the attack HUD's stars, loot, timer warning, speed and End, the stings
  redone (a C major arpeggio into a chorused chord with a sparkle; a slow A minor fall), a battle bed.
  Every dated sound goes through `BattleEffects.sound(key, at)`, scheduled in real seconds divided by
  the view's speed, and the ring is dropped when the battle ends, on a surrender and on Return, so
  nothing in flight sounds over the result or the base.

Each lane's review measured the files independently (ffmpeg and numpy, never ears): format, peak, DC,
edge samples, gaps, durations against their use, loop seams against the ordinary step, the loudness
envelope's autocorrelation for a loop's periodicity, and the shots' spectral centroids and pairwise
correlations for distinctness; walked the inventory hook by hook for coverage and doubles; and drove
the scenarios headless and rendered on the Dummy driver. Three findings went back and were fixed
before landing: a meter filling during a battle dinged (the HUD's refresh-driven sounds are now gated on
its visibility), the two 20 s beds swelled on a regular 10 s and 5 s beat (their gusts are now uneven
within the loop), and a strike's whine scheduled before a surrender played over the result panel (the
scheduled plays are dropped at every end of a battle, and the scenario that proves it first checks the
whine was waiting).

## 2. What was built

| Area | Commits |
|---|---|
| The silent harness: `run.sh` on the Dummy audio driver, `--audible` for a person | `7670e81` |
| The foundation: the `Audio` node (`3ba9c33`), the generator and the first 14 effects (`6c28050`), the first hooks (`b9300b0`), the `sounds` scenario and the profile's audio column (`f7bc42a`), `docs/reference/audio.md` (`1ccf991`) | `3ba9c33`..`1ccf991` |
| The music: the Gravity Turn tracks with `LICENSES.md` (`2308d95`), `main` owning the quit (`b9c4f52`), the crossfades at boot, battle and return (`6814801`), docs (`9251507`) | `2308d95`..`9251507` |
| The UI, base and expedition: taps from the button helpers (`81dd5ed`), placing and moving (`52f1410`), completions, toasts, a full meter and the boot (`85f46db`), the laser and the ambience (`52cb248`), the drone's out-of-tree release (`b38ba4a`), the sector map (`ec04949`), the settings gear (`35cc84d`), every scenario's sound checks (`6974adb`), the 0.3 s settle (`91b6d28`), docs (`9546e35`) | `81dd5ed`..`9546e35` |
| The battle: weapons and impacts (`3c5568b`), hits, collapses, deaths and traps (`7533a75`), shields, EMP, gravity well and abilities (`9e57a60`), the attack HUD, the stings and the beds (`e48b088`), every hook with `drop_scheduled` (`b9cb0d1`), the `sounds_battle` scenario (`1764edf`), docs (`f17bd62`) | `3c5568b`..`f17bd62` |

## 3. Numbers

- Sound effects: 104 keys in `Sounds.TABLE` (37 for the base and the sector map, 67 for the battle),
  7.9 MB of PCM WAV under `assets/audio/sfx/`; music 7.8 MB of Ogg Vorbis (2.54 MB base, 5.66 MB
  combat, bar-exact loops, -18 and -16 LUFS, true peak -6.2 and -2.6 dBTP).
- Loudness targets by category (RMS of the loudest 50 ms, dBFS): UI -20, shots -16, impacts -15,
  explosions -12, chimes -18, stings -14, loops -22, the beds -26, the construction laser -26.
- Distinctness, measured by the review: the shots' spectral centroids spread from 550 to 8,089 Hz; no
  pair of files is identical and no pair's log-band spectral correlation exceeds 0.97.
- The beds: 20 s loops whose seam step is under the ordinary step and whose loudness envelope's
  circular autocorrelation beyond 2 s stays under about 0.3 (base) and shows no regular cycle (battle).
- Audio cost: 0.000 ms a frame idle in the base; 0.002 to 0.03 ms a frame in a full battle (about
  8,000 plays over a battle, never more than 24 voices; hits dropped first, explosions and the strike
  never). Opening a battle loads the combat track in about 11 ms cold.
- Every scenario of the harness now counts its steps' sounds; `sounds` and `sounds_battle` check the
  node, the hooks and the coverage of every weapon kind, impact, death, trap and event.

## 4. Decisions

Recorded in `docs/project_overview.md` §3.1, in short:

- **Hybrid**: effects generated in code at build time, music free under CC0 with the licence beside
  the file; the stings and the ambience generated, so every short sound is one voice in one identity.
- **The identity** is written down and every recipe is held to it; nothing harsh for its own sake.
- **No runtime synthesis**: WAVs rendered by a tool script, imported as PCM, loaded by path.
- **Objective checks stand in for ears**: the generator refuses a bad file; the reviews measure; the
  owner auditions at the end.
- **The harness is silent**; `--audible` is for a person.
- **`main` owns quitting**, with a 0.3 s settle after `Audio.shut_down()`.
- **A tap and its outcome layer** (the click, then the open or the thunk); a place is the confirm's
  thunk then the drone's whoosh 0.2 s later; the construction laser's cap is the recipe's two voices,
  not a ranking by distance to the camera.
- **The base is silent in battle**: its hooks go through `main._base_sound`, and the HUD's
  refresh-driven sounds through its visibility; a battle's scheduled plays are dropped at its end.
- **Settings live in a `ConfigFile`, not the save**; Mute keeps the pre-mute level.

## 5. Levers not pulled, and what is left

- **The owner's audition.** Every effect is on the sound board page (below); flagged recipes come back
  for retuning, `-- --only=<key,...>` regenerating the few that change.
- Android's back button quits the engine directly (`SceneTree.quit_on_go_back`), skipping `main`'s
  save and quit; handle `NOTIFICATION_WM_GO_BACK_REQUEST` when the phone build comes.
- A battle sound scheduled in real time mistimes if the speed toggles while it waits.
- Not exercised by any scenario: `housing_full`, `offline_boot`, the settings' restore on a second boot,
  `timer_warning`.
- The attack HUD's taps still come from the `tap_buttons` walk; the base HUD's come from its helpers.
- Godot's own Vorbis decoder was not measured at the music's seam (ffmpeg's was).
- A brand-new clone's very first import segfaulted twice for one lane; a rerun passed each time.
- Optional loops of the inventory not made: a ground bed under the battle, the smoke columns.
- Phone audio latency and the mixer's cost on a phone are unmeasured, like the rest of the phone step.
- From the UI pass: the strike's quake unconfirmed, the loot pill at narrow widths, the info picture's
  first frames, the result scroll's fade.

## 6. Hearing it again

The owner's sound board (every effect playable, grouped by where it plays, with flags to copy back):
https://claude.ai/artifact/4PyEyvYCkHVz38DoRD4ZX6. The music audition page:
https://claude.ai/artifact/Rr4MpdHBpSYUZnDRXiWk7b. In the game: `tools/harness/run.sh sounds --rendered
--audible` or `sounds_battle --rendered --audible`, for a person listening only. Regenerate after a
recipe change with `$GODOT --headless --path . -s res://tools/gen_sounds.gd`, which prints a row per key
(seconds, peak, loudness, `ok` or the check it failed).
