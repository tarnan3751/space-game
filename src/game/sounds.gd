class_name Sounds
extends RefCounted
## The game's sound effects as recipes (docs/reference/audio.md): one entry a key, which
## tools/gen_sounds.gd renders to assets/audio/sfx/<key>.wav and Audio loads and plays by the same
## key. Presentation only, like Weapons: the server never reads it.
##
## A recipe is a category (CATEGORIES: its bus, loudness, length bounds, priority and cooldown), a
## length in seconds and a list of layers summed, each an oscillator with its own envelope, pitch
## sweep, filter and modulation; then the master effects (chorus, echo, drive). Every field has a
## default (the tool's LAYER and RECIPE), so a recipe names only what it changes. audio.md,
## **Recipes**, lists the fields.
##
## The identity: friendly comic synth, toy-like rather than 8-bit harsh: sine and triangle bodies,
## soft attacks on the UI, a short bright transient on a hit, pitch glides for shots and whooshes,
## noise under a falling low-pass with a sub thump for a blast, a little chorus on chimes.

## Per category: the bus it plays on, the loudness the generator normalises it to (the loudest
## 50 ms window's RMS, dBFS), the bounds its length must fall in (seconds), the priority a full
## voice pool compares (higher wins), and the cooldown between two plays of one key (seconds).
const CATEGORIES := {
	"ui": {"bus": &"UI", "rms_db": -20.0, "min": 0.06, "max": 0.15, "priority": 3, "cooldown": 0.04},
	"shot": {"bus": &"SFX", "rms_db": -16.0, "min": 0.1, "max": 0.3, "priority": 1, "cooldown": 0.04},
	"impact": {"bus": &"SFX", "rms_db": -15.0, "min": 0.15, "max": 0.4, "priority": 2, "cooldown": 0.04},
	"explosion": {"bus": &"SFX", "rms_db": -12.0, "min": 0.6, "max": 1.5, "priority": 3, "cooldown": 0.06},
	"chime": {"bus": &"SFX", "rms_db": -18.0, "min": 0.5, "max": 2.0, "priority": 3, "cooldown": 0.1},
	"sting": {"bus": &"Music", "rms_db": -14.0, "min": 0.5, "max": 2.0, "priority": 4, "cooldown": 0.5},
	"loop": {"bus": &"SFX", "rms_db": -22.0, "min": 0.5, "max": 8.0, "priority": 5, "cooldown": 0.0},
}

## The notes the chimes and stings use (Hz).
const C5 := 523.25
const E5 := 659.26
const G5 := 783.99
const C6 := 1046.5
const E6 := 1318.51
const G6 := 1567.98

const TABLE := {
	# UI and base: the taps by the kind of button (Hud._button, SectorMap._button), soft attacks,
	# sine and triangle blips, and a refusal's low buzz; the build and army panels sliding.
	"ui_tap": {"category": "ui", "seconds": 0.09, "layers": [
		{"wave": "sine", "hz": [1250, 880], "glide": 0.04, "a": 0.002, "d": 0.07},
		{"wave": "triangle", "hz": 2500, "a": 0.001, "d": 0.02, "db": -12}]},
	"ui_tap_soft": {"category": "ui", "seconds": 0.09, "rms_db": -22.0, "layers": [
		{"wave": "sine", "hz": [820, 600], "glide": 0.04, "a": 0.003, "d": 0.07},
		{"wave": "triangle", "hz": 1640, "a": 0.002, "d": 0.02, "db": -16}]},
	"ui_tab": {"category": "ui", "seconds": 0.12, "layers": [
		{"wave": "sine", "hz": 740, "a": 0.002, "d": 0.05},
		{"wave": "triangle", "hz": 1480, "a": 0.001, "d": 0.015, "db": -14},
		{"wave": "sine", "hz": 1110, "at": 0.045, "a": 0.002, "d": 0.065},
		{"wave": "triangle", "hz": 2220, "at": 0.045, "a": 0.001, "d": 0.015, "db": -14}]},
	"ui_denied": {"category": "ui", "seconds": 0.18, "max": 0.18, "rms_db": -17.0, "layers": [
		{"wave": "square", "pulse": 0.4, "hz": 155, "a": 0.004, "d": 0.03, "s": 0.6, "len": 0.05, "r": 0.025,
			"filter": {"type": "lp", "hz": 1100}},
		{"wave": "triangle", "hz": 77.5, "a": 0.004, "d": 0.03, "s": 0.6, "len": 0.05, "r": 0.025, "db": -6},
		{"wave": "square", "pulse": 0.4, "hz": 130, "at": 0.08, "a": 0.004, "d": 0.03, "s": 0.6, "len": 0.05, "r": 0.03,
			"filter": {"type": "lp", "hz": 1000}},
		{"wave": "triangle", "hz": 65, "at": 0.08, "a": 0.004, "d": 0.03, "s": 0.6, "len": 0.05, "r": 0.03, "db": -6}]},
	"card_press": {"category": "ui", "seconds": 0.08, "min": 0.04, "layers": [
		{"wave": "triangle", "hz": [2000, 1300], "glide": 0.02, "a": 0.001, "d": 0.03},
		{"wave": "sine", "hz": [520, 380], "glide": 0.05, "a": 0.001, "d": 0.065, "db": -3},
		{"wave": "noise", "a": 0.0005, "d": 0.008, "filter": {"type": "hp", "hz": 4000}, "db": -12}]},
	"ui_open": {"category": "ui", "seconds": 0.22, "max": 0.25, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.07, "d": 0.12, "filter": {"type": "bp", "hz": [400, 2600], "q": 1.4}},
		{"wave": "sine", "hz": [320, 760], "a": 0.03, "d": 0.16, "db": -4}]},
	"ui_close": {"category": "ui", "seconds": 0.22, "max": 0.25, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.05, "d": 0.14, "filter": {"type": "bp", "hz": [2600, 450], "q": 1.4}},
		{"wave": "sine", "hz": [760, 300], "a": 0.02, "d": 0.16, "db": -8}]},

	# Placing: the ghost's ticks as it moves (lower over a spot it cannot take), the place's clunk
	# and chime, Cancel's fall, a wall placed (a ratchet along a stroke), a building lifted and set down.
	"ghost_tick": {"category": "ui", "seconds": 0.05, "min": 0.02, "max": 0.06, "rms_db": -24.0,
		"cooldown": 0.05, "voices": 2, "layers": [
		{"wave": "sine", "hz": 1500, "a": 0.001, "d": 0.03},
		{"wave": "triangle", "hz": 3000, "a": 0.001, "d": 0.01, "db": -14}]},
	"ghost_tick_low": {"category": "ui", "seconds": 0.05, "min": 0.02, "max": 0.06, "rms_db": -24.0,
		"cooldown": 0.05, "voices": 2, "layers": [
		{"wave": "sine", "hz": 620, "a": 0.001, "d": 0.035},
		{"wave": "triangle", "hz": 1240, "a": 0.001, "d": 0.012, "db": -14}]},
	"place_ok": {"category": "ui", "seconds": 0.38, "max": 0.4, "rms_db": -18.0, "chorus": {"mix": 0.25}, "layers": [
		{"wave": "sine", "hz": [190, 90], "glide": 0.06, "a": 0.001, "d": 0.12},
		{"wave": "noise", "a": 0.001, "d": 0.03, "filter": {"type": "lp", "hz": [3000, 500]}, "db": -8},
		{"wave": "triangle", "hz": 330, "a": 0.001, "d": 0.06, "filter": {"type": "lp", "hz": 1200}, "db": -6},
		{"wave": "sine", "hz": G5, "at": 0.07, "a": 0.003, "d": 0.2, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}, "db": -6},
		{"wave": "sine", "hz": C6, "at": 0.13, "a": 0.003, "d": 0.22, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}, "db": -6}]},
	"cancel": {"category": "ui", "seconds": 0.12, "rms_db": -21.0, "layers": [
		{"wave": "sine", "hz": [900, 380], "glide": 0.08, "a": 0.002, "d": 0.1},
		{"wave": "triangle", "hz": [1800, 760], "glide": 0.08, "a": 0.002, "d": 0.03, "db": -14}]},
	"wall_paint": {"category": "ui", "seconds": 0.1, "cooldown": 0.05, "layers": [
		{"wave": "sine", "hz": [260, 140], "glide": 0.04, "a": 0.001, "d": 0.08},
		{"wave": "triangle", "hz": 1200, "a": 0.001, "d": 0.02, "db": -10},
		{"wave": "noise", "a": 0.0005, "d": 0.01, "filter": {"type": "bp", "hz": 2500, "q": 1.5}, "db": -10}]},
	"drag_pickup": {"category": "ui", "seconds": 0.14, "rms_db": -19.0, "layers": [
		{"wave": "sine", "hz": [300, 720], "glide": 0.1, "a": 0.02, "d": 0.11},
		{"wave": "pink", "a": 0.03, "d": 0.08, "filter": {"type": "bp", "hz": [600, 2000], "q": 1.2}, "db": -10}]},
	"drag_drop": {"category": "ui", "seconds": 0.14, "layers": [
		{"wave": "sine", "hz": [200, 85], "glide": 0.05, "a": 0.001, "d": 0.12},
		{"wave": "noise", "a": 0.001, "d": 0.025, "filter": {"type": "lp", "hz": [2500, 400]}, "db": -6},
		{"wave": "triangle", "hz": 420, "a": 0.001, "d": 0.03, "db": -10}]},

	# A building tapped, a voice per category (SELECT): the core a warm two-note, resources a bright
	# ping, the army a snare-ish tap, defences a metallic click, traps a low blip.
	"select_building_core": {"category": "ui", "seconds": 0.15, "chorus": {"mix": 0.3}, "layers": [
		{"wave": "triangle", "hz": 392, "a": 0.003, "d": 0.07, "filter": {"type": "lp", "hz": 1800}},
		{"wave": "sine", "hz": 196, "a": 0.003, "d": 0.06, "db": -8},
		{"wave": "triangle", "hz": 587.33, "at": 0.05, "a": 0.003, "d": 0.09, "filter": {"type": "lp", "hz": 2200}}]},
	"select_building_resources": {"category": "ui", "seconds": 0.14, "layers": [
		{"wave": "sine", "hz": G6, "a": 0.001, "d": 0.12, "fm": {"ratio": 3.0, "index": [0.8, 0.0]}},
		{"wave": "triangle", "hz": 3136, "a": 0.001, "d": 0.02, "db": -16}]},
	"select_building_army": {"category": "ui", "seconds": 0.1, "layers": [
		{"wave": "noise", "a": 0.001, "d": 0.075, "filter": {"type": "bp", "hz": 1800, "q": 0.8}},
		{"wave": "triangle", "hz": [330, 180], "glide": 0.04, "a": 0.001, "d": 0.07, "db": -4},
		{"wave": "sine", "hz": 200, "a": 0.001, "d": 0.04, "db": -6}]},
	"select_building_defense": {"category": "ui", "seconds": 0.1, "layers": [
		{"wave": "sine", "hz": 1200, "a": 0.001, "d": 0.07, "ring": {"hz": 1730}},
		{"wave": "triangle", "hz": 600, "a": 0.001, "d": 0.03, "db": -8},
		{"wave": "noise", "a": 0.0005, "d": 0.008, "filter": {"type": "hp", "hz": 5000}, "db": -10}]},
	"select_building_traps": {"category": "ui", "seconds": 0.12, "rms_db": -21.0, "layers": [
		{"wave": "sine", "hz": [300, 220], "glide": 0.05, "a": 0.002, "d": 0.1},
		{"wave": "triangle", "hz": 150, "a": 0.002, "d": 0.06, "db": -10}]},

	# The base: a construction started (an upgrade's too) and finished.
	"build_start": {"category": "ui", "seconds": 0.38, "max": 0.4, "layers": [
		{"wave": "sine", "hz": [150, 85], "glide": 0.08, "a": 0.002, "d": 0.14},
		{"wave": "square", "pulse": 0.3, "hz": [220, 660], "sweep": "lin", "glide": 0.26, "a": 0.01, "d": 0.3,
			"filter": {"type": "lp", "hz": 1800}, "db": -12},
		{"wave": "noise", "a": 0.001, "d": 0.03, "filter": {"type": "hp", "hz": 3000}, "db": -14}]},
	"build_done": {"category": "chime", "seconds": 1.0, "chorus": {"mix": 0.35},
		"echo": {"ms": 120, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "sine", "hz": C6, "a": 0.003, "d": 0.5, "fm": {"ratio": 2.0, "index": [0.8, 0.0]}},
		{"wave": "sine", "hz": E6, "at": 0.11, "a": 0.003, "d": 0.5, "fm": {"ratio": 2.0, "index": [0.8, 0.0]}},
		{"wave": "sine", "hz": G6, "at": 0.22, "a": 0.003, "d": 0.6, "fm": {"ratio": 2.0, "index": [0.8, 0.0]}},
		{"wave": "triangle", "hz": C5, "at": 0.22, "a": 0.01, "d": 0.6, "db": -12}]},

	# The base's other events: a unit trained, a research done, an ability made, a queue entry
	# refunded, a head left waiting for room in the Hangars, a meter full; the toasts by kind (a
	# refusal's is ui_denied); the boot, a short rising logo, or a welcome when the offline catch-up
	# finished anything.
	"train_done": {"category": "chime", "seconds": 0.5, "min": 0.3, "rms_db": -17.5, "chorus": {"mix": 0.3}, "layers": [
		{"wave": "triangle", "hz": 2093.0, "a": 0.001, "d": 0.02, "db": -10},
		{"wave": "sine", "hz": G5, "a": 0.003, "d": 0.22, "fm": {"ratio": 2.0, "index": [0.7, 0.0]}},
		{"wave": "sine", "hz": C6, "at": 0.09, "a": 0.003, "d": 0.36, "fm": {"ratio": 2.0, "index": [0.7, 0.0]}},
		{"wave": "triangle", "hz": 261.63, "at": 0.09, "a": 0.01, "d": 0.3, "db": -14}]},
	"research_done": {"category": "chime", "seconds": 1.1, "chorus": {"mix": 0.35},
		"echo": {"ms": 140, "feedback": 0.3, "mix": 0.25}, "layers": [
		{"wave": "sine", "hz": C6, "a": 0.002, "d": 0.3, "fm": {"ratio": 3.0, "index": [0.6, 0.0]}},
		{"wave": "sine", "hz": E6, "at": 0.06, "a": 0.002, "d": 0.3, "fm": {"ratio": 3.0, "index": [0.6, 0.0]}},
		{"wave": "sine", "hz": G6, "at": 0.12, "a": 0.002, "d": 0.35, "fm": {"ratio": 3.0, "index": [0.6, 0.0]}},
		{"wave": "sine", "hz": 2093.0, "at": 0.18, "a": 0.002, "d": 0.6, "fm": {"ratio": 3.0, "index": [0.6, 0.0]}},
		{"wave": "noise", "at": 0.18, "a": 0.05, "d": 0.5, "filter": {"type": "hp", "hz": 7000}, "db": -22},
		{"wave": "triangle", "hz": C5, "at": 0.18, "a": 0.01, "d": 0.6, "db": -14}]},
	"make_done": {"category": "chime", "seconds": 0.3, "min": 0.2, "rms_db": -19.0, "layers": [
		{"wave": "sine", "hz": [320, 900], "glide": 0.05, "a": 0.002, "d": 0.08},
		{"wave": "sine", "hz": [420, 1200], "glide": 0.05, "at": 0.07, "a": 0.002, "d": 0.08, "db": -2},
		{"wave": "sine", "hz": [560, 1600], "glide": 0.05, "at": 0.14, "a": 0.002, "d": 0.12, "db": -4},
		{"wave": "triangle", "hz": 180, "a": 0.003, "d": 0.12, "db": -12}]},
	"queue_refund": {"category": "ui", "seconds": 0.15, "rms_db": -18.0, "layers": [
		{"wave": "sine", "hz": E6, "a": 0.1, "d": 0.03, "fm": {"ratio": 3.0, "index": [0.2, 1.2]}},
		{"wave": "sine", "hz": 987.77, "a": 0.08, "d": 0.04, "db": -6}]},
	"housing_full": {"category": "ui", "seconds": 0.12, "rms_db": -22.0, "layers": [
		{"wave": "sine", "hz": 880, "a": 0.002, "d": 0.035},
		{"wave": "triangle", "hz": 440, "a": 0.002, "d": 0.03, "db": -10},
		{"wave": "sine", "hz": 880, "at": 0.06, "a": 0.002, "d": 0.045},
		{"wave": "triangle", "hz": 440, "at": 0.06, "a": 0.002, "d": 0.035, "db": -10}]},
	"meter_full": {"category": "chime", "seconds": 0.8, "echo": {"ms": 130, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "sine", "hz": 1760.0, "a": 0.002, "d": 0.6, "fm": {"ratio": 3.5, "index": [1.2, 0.0]}},
		{"wave": "sine", "hz": 880.0, "a": 0.003, "d": 0.5, "db": -8},
		{"wave": "triangle", "hz": 3520.0, "a": 0.001, "d": 0.05, "db": -18}]},
	"toast_info": {"category": "ui", "seconds": 0.12, "rms_db": -22.0, "layers": [
		{"wave": "sine", "hz": 988, "a": 0.004, "d": 0.06},
		{"wave": "sine", "hz": 1480, "at": 0.035, "a": 0.004, "d": 0.08, "db": -4}]},
	"toast_reward": {"category": "chime", "seconds": 0.65, "chorus": {"mix": 0.3},
		"echo": {"ms": 110, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "triangle", "hz": 987.77, "a": 0.002, "d": 0.08, "s": 0.5, "len": 0.07, "r": 0.03},
		{"wave": "sine", "hz": E6, "at": 0.07, "a": 0.002, "d": 0.5, "fm": {"ratio": 3.0, "index": [1.0, 0.0]}},
		{"wave": "triangle", "hz": 2637, "at": 0.07, "a": 0.002, "d": 0.12, "db": -16}]},
	"boot_sting": {"category": "sting", "seconds": 1.1, "chorus": {"mix": 0.3},
		"echo": {"ms": 140, "feedback": 0.2, "mix": 0.15}, "layers": [
		{"wave": "triangle", "hz": [220, 440], "sweep": "lin", "glide": 0.25, "a": 0.08, "d": 0.2, "s": 0.4, "len": 0.25,
			"r": 0.1, "filter": {"type": "lp", "hz": [800, 3000]}, "db": -6},
		{"wave": "triangle", "hz": G5, "at": 0.2, "a": 0.004, "d": 0.2},
		{"wave": "triangle", "hz": C6, "at": 0.3, "a": 0.004, "d": 0.2},
		{"wave": "sine", "hz": E6, "at": 0.4, "a": 0.004, "d": 0.6, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}},
		{"wave": "triangle", "hz": C5, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.35, "r": 0.3,
			"vibrato": [5.0, 10.0], "db": -6}]},
	"offline_boot": {"category": "sting", "seconds": 1.5, "chorus": {"mix": 0.35},
		"echo": {"ms": 150, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "sine", "hz": E6, "a": 0.004, "d": 0.25, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}},
		{"wave": "sine", "hz": C6, "at": 0.12, "a": 0.004, "d": 0.25, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}},
		{"wave": "sine", "hz": G5, "at": 0.24, "a": 0.004, "d": 0.25, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}},
		{"wave": "triangle", "hz": C5, "at": 0.42, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.5, "r": 0.4,
			"vibrato": [5.0, 10.0], "db": -4},
		{"wave": "triangle", "hz": E5, "at": 0.42, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.5, "r": 0.4,
			"vibrato": [5.0, 10.0], "db": -5},
		{"wave": "sine", "hz": C6, "at": 0.42, "a": 0.004, "d": 0.8, "fm": {"ratio": 2.0, "index": [0.6, 0.0]}, "db": -2}]},

	# The construction drone's laser, one shot a firing (ConstructionDrone): a buzz that swells in
	# and crackles, two at most at once.
	"laser_work": {"category": "shot", "seconds": 1.35, "min": 1.0, "max": 1.4, "rms_db": -26.0, "quiet": true, "voices": 2,
		"cooldown": 0.2, "layers": [
		{"wave": "triangle", "hz": 110, "a": 0.18, "d": 0.2, "s": 0.8, "len": 1.1, "r": 0.15, "vibrato": [11.0, 30.0],
			"fm": {"ratio": 1.0, "index": 1.8}, "filter": {"type": "lp", "hz": 1500}},
		{"wave": "sine", "hz": 220, "a": 0.18, "d": 0.2, "s": 0.8, "len": 1.1, "r": 0.15, "vibrato": [7.0, 20.0], "db": -8},
		{"wave": "noise", "a": 0.2, "d": 0.2, "s": 0.7, "len": 1.1, "r": 0.15, "ring": {"hz": 23.0},
			"filter": {"type": "hp", "hz": 3000}, "db": -14}]},

	# The base's bed under everything (main.gd): a soft wind and a faint hum. Its gusts are three
	# swells of their own, one, two and five a loop, so the loudness never repeats inside it; every
	# modulation is whole half-cycles of its 20 s, so the loop's seam is the crossfade's alone.
	"base_bed": {"category": "loop", "seconds": 20.0, "max": 21.0, "loop": true, "quiet": true, "rms_db": -26.0,
		"layers": [
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "filter": {"type": "lp", "hz": 600}},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "ring": {"hz": 0.025},
			"filter": {"type": "bp", "hz": 700, "q": 0.8}, "db": 4},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "ring": {"hz": 0.05},
			"filter": {"type": "bp", "hz": 1000, "q": 0.8}, "db": 4},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "ring": {"hz": 0.125},
			"filter": {"type": "bp", "hz": 1500, "q": 1.0}, "db": 3},
		{"wave": "sine", "hz": 110, "a": 0.0, "s": 1.0, "len": 20.1, "vibrato": [0.1, 6.0], "db": -16},
		{"wave": "sine", "hz": 165, "a": 0.0, "s": 1.0, "len": 20.1, "vibrato": [0.15, 5.0], "db": -22}]},

	# The sector map: open and closed, a scan's radar sweep and ping, a field's detail opened.
	"map_open": {"category": "ui", "seconds": 0.42, "max": 0.45, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.12, "d": 0.25, "filter": {"type": "bp", "hz": [300, 3000], "q": 2.0}},
		{"wave": "sine", "hz": [400, 1200], "a": 0.05, "d": 0.3, "db": -8},
		{"wave": "sine", "hz": 1600, "at": 0.3, "a": 0.002, "d": 0.1, "db": -6}]},
	"map_close": {"category": "ui", "seconds": 0.3, "max": 0.32, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.04, "d": 0.22, "filter": {"type": "bp", "hz": [2500, 350], "q": 1.6}},
		{"wave": "sine", "hz": [1000, 350], "a": 0.02, "d": 0.22, "db": -8}]},
	"scan": {"category": "chime", "seconds": 1.3, "rms_db": -16.0, "echo": {"ms": 180, "feedback": 0.35, "mix": 0.3}, "layers": [
		{"wave": "noise", "a": 0.3, "d": 0.3, "s": 0.5, "len": 0.6, "r": 0.3, "filter": {"type": "bp", "hz": [400, 3200], "q": 3.0},
			"db": -4},
		{"wave": "sine", "hz": [300, 900], "sweep": "lin", "a": 0.2, "d": 0.7, "db": -10},
		{"wave": "sine", "hz": E6, "at": 0.75, "a": 0.002, "d": 0.45, "fm": {"ratio": 2.0, "index": [0.5, 0.0]}}]},
	"field_open": {"category": "ui", "seconds": 0.3, "max": 0.32, "rms_db": -19.0, "layers": [
		{"wave": "triangle", "hz": [1800, 1200], "glide": 0.02, "a": 0.001, "d": 0.03, "db": -2},
		{"wave": "sine", "hz": 110, "a": 0.03, "d": 0.25, "vibrato": [6.0, 15.0]},
		{"wave": "sine", "hz": 220, "a": 0.03, "d": 0.2, "db": -8}]},

	# The battle: the shots (Sounds.FIRE_KIND, FIRE), by the weapon's kind and per type where its
	# character differs. Short and bright for the light guns, a sub under the heavy ones.
	"laser_fire": {"category": "shot", "seconds": 0.2, "layers": [
		{"wave": "triangle", "hz": [2200, 380], "glide": 0.14, "a": 0.002, "d": 0.15, "fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
		{"wave": "sine", "hz": [1100, 250], "glide": 0.14, "a": 0.002, "d": 0.14, "db": -6},
		{"wave": "noise", "a": 0.001, "d": 0.02, "filter": {"type": "hp", "hz": 5000}, "db": -14}]},
	# The laser a fifth higher and thinner; its twin barrel's shot follows 40 ms on (TWIN).
	"sentry_fire": {"category": "shot", "seconds": 0.18, "layers": [
		{"wave": "triangle", "hz": [3300, 570], "glide": 0.12, "a": 0.002, "d": 0.12, "fm": {"ratio": 2.0, "index": [0.8, 0.0]}},
		{"wave": "sine", "hz": [1650, 375], "glide": 0.12, "a": 0.002, "d": 0.11, "db": -9},
		{"wave": "noise", "a": 0.001, "d": 0.015, "filter": {"type": "hp", "hz": 6000}, "db": -14}]},
	# The plasma mortar's hollow thoomp.
	"shell_fire": {"category": "shot", "seconds": 0.28, "layers": [
		{"wave": "sine", "hz": [180, 60], "glide": 0.12, "a": 0.002, "d": 0.2},
		{"wave": "noise", "a": 0.002, "d": 0.12, "filter": {"type": "lp", "hz": [3000, 400]}, "db": -6},
		{"wave": "triangle", "hz": 90, "a": 0.004, "d": 0.2, "db": -6}]},
	# Up to twenty tubes in a salvo: a short cooldown and three voices.
	"missile_fire": {"category": "shot", "seconds": 0.3, "cooldown": 0.06, "voices": 3, "layers": [
		{"wave": "noise", "a": 0.015, "d": 0.26, "filter": {"type": "bp", "hz": [500, 2200], "q": 2.0}},
		{"wave": "saw", "hz": [200, 520], "a": 0.01, "d": 0.2, "filter": {"type": "lp", "hz": 1200}, "db": -14},
		{"wave": "sine", "hz": [120, 70], "a": 0.002, "d": 0.08, "db": -6}]},
	# The flak's crisp pok, one a barrel of its burst (its cooldown under the burst's gap at 2x).
	"flak_fire": {"category": "shot", "seconds": 0.16, "cooldown": 0.025, "layers": [
		{"wave": "sine", "hz": [700, 160], "glide": 0.04, "a": 0.001, "d": 0.11},
		{"wave": "noise", "a": 0.001, "d": 0.045, "filter": {"type": "bp", "hz": 1800, "q": 1.2}, "db": -3},
		{"wave": "triangle", "hz": [320, 140], "a": 0.001, "d": 0.09, "db": -6}]},
	# The dune runner's and the gunship's lighter tat, three a burst.
	"tracer_fire": {"category": "shot", "seconds": 0.1, "min": 0.05, "rms_db": -19.0, "cooldown": 0.03, "layers": [
		{"wave": "sine", "hz": [1250, 420], "glide": 0.03, "a": 0.001, "d": 0.06},
		{"wave": "noise", "a": 0.001, "d": 0.025, "filter": {"type": "hp", "hz": 3000}, "db": -6},
		{"wave": "triangle", "hz": [600, 300], "a": 0.001, "d": 0.05, "db": -8}]},
	# The arc tower's crackle: noise through a resonant band falling, chopped by a ring.
	"arc_zap": {"category": "shot", "seconds": 0.26, "layers": [
		{"wave": "noise", "a": 0.002, "d": 0.24, "filter": {"type": "bp", "hz": [3200, 800], "q": 4.0}, "ring": {"hz": 60}},
		{"wave": "square", "pulse": 0.2, "hz": [220, 110], "a": 0.002, "d": 0.2, "filter": {"type": "lp", "hz": 2500}, "db": -12},
		{"wave": "sine", "hz": [1500, 600], "a": 0.001, "d": 0.08, "db": -8}]},
	# The EMP tower's pulse: a soft square falling, a sine under it.
	"emp_pulse": {"category": "shot", "seconds": 0.32, "layers": [
		{"wave": "square", "pulse": 0.25, "hz": [1600, 200], "glide": 0.25, "a": 0.003, "d": 0.28,
			"filter": {"type": "lp", "hz": 2400}, "db": -4},
		{"wave": "sine", "hz": [800, 100], "glide": 0.25, "a": 0.003, "d": 0.3}]},
	# The railgun: a charge rising, then the snap of the slug.
	"railgun_fire": {"category": "shot", "seconds": 0.3, "layers": [
		{"wave": "sine", "hz": [200, 1800], "glide": 0.11, "a": 0.1, "d": 0.04, "db": -6},
		{"wave": "noise", "at": 0.1, "a": 0.001, "d": 0.12, "filter": {"type": "hp", "hz": 2500}, "db": -2},
		{"wave": "triangle", "at": 0.1, "hz": [2400, 300], "glide": 0.12, "a": 0.001, "d": 0.15, "db": -4},
		{"wave": "sine", "at": 0.1, "hz": [180, 60], "a": 0.001, "d": 0.15, "db": -4}]},
	# The ion beam's held drone, a zing at its start.
	"beam_fire": {"category": "shot", "seconds": 0.3, "chorus": {"mix": 0.4}, "layers": [
		{"wave": "saw", "hz": 220, "a": 0.01, "d": 0.05, "s": 0.7, "len": 0.2, "r": 0.06, "filter": {"type": "lp", "hz": 1800}, "db": -4},
		{"wave": "sine", "hz": 440, "a": 0.01, "d": 0.05, "s": 0.7, "len": 0.2, "r": 0.06, "vibrato": [14.0, 20.0]},
		{"wave": "sine", "hz": [1400, 900], "a": 0.002, "d": 0.06, "db": -8}]},
	# The skimmer's thinner beam.
	"skimmer_beam": {"category": "shot", "seconds": 0.22, "chorus": {"mix": 0.35}, "layers": [
		{"wave": "saw", "hz": 330, "a": 0.008, "d": 0.04, "s": 0.6, "len": 0.15, "r": 0.05, "filter": {"type": "lp", "hz": 2500}, "db": -6},
		{"wave": "sine", "hz": 990, "a": 0.008, "d": 0.04, "s": 0.6, "len": 0.15, "r": 0.05, "vibrato": [16.0, 25.0]}]},
	# The orbital cannon's deep launch: a sub falling and a long exhale.
	"orbital_fire": {"category": "shot", "seconds": 0.55, "max": 0.6, "priority": 2, "layers": [
		{"wave": "sine", "hz": [95, 40], "glide": 0.35, "a": 0.003, "d": 0.45},
		{"wave": "pink", "a": 0.01, "d": 0.5, "filter": {"type": "lp", "hz": [2500, 300]}, "db": -4},
		{"wave": "triangle", "hz": [600, 150], "a": 0.002, "d": 0.12, "db": -8}]},
	# The ranger's soft pew (the jet trooper's too, two a burst).
	"bolt_fire": {"category": "shot", "seconds": 0.13, "layers": [
		{"wave": "triangle", "hz": [1400, 500], "glide": 0.1, "a": 0.002, "d": 0.11},
		{"wave": "sine", "hz": [700, 250], "glide": 0.1, "a": 0.002, "d": 0.1, "db": -8}]},
	# The siege walker's fatter bolt.
	"walker_fire": {"category": "shot", "seconds": 0.2, "layers": [
		{"wave": "triangle", "hz": [900, 300], "glide": 0.14, "a": 0.002, "d": 0.16},
		{"wave": "square", "pulse": 0.3, "hz": [450, 150], "glide": 0.14, "a": 0.002, "d": 0.14,
			"filter": {"type": "lp", "hz": 1500}, "db": -12},
		{"wave": "sine", "hz": [200, 80], "a": 0.002, "d": 0.1, "db": -4}]},
	# The hover tank's cannon: a thump and a crack.
	"tank_fire": {"category": "shot", "seconds": 0.26, "layers": [
		{"wave": "sine", "hz": [140, 50], "glide": 0.15, "a": 0.002, "d": 0.22},
		{"wave": "noise", "a": 0.001, "d": 0.1, "filter": {"type": "lp", "hz": [4000, 500]}, "db": -4},
		{"wave": "triangle", "hz": 70, "a": 0.003, "d": 0.2, "db": -6}]},
	# The titan's: bigger, its sub down to 35 Hz.
	"titan_fire": {"category": "shot", "seconds": 0.38, "max": 0.4, "drive": 0.2, "priority": 2, "layers": [
		{"wave": "sine", "hz": [120, 35], "glide": 0.25, "a": 0.002, "d": 0.32},
		{"wave": "noise", "a": 0.001, "d": 0.16, "filter": {"type": "lp", "hz": [3000, 300]}, "db": -3},
		{"wave": "pink", "a": 0.003, "d": 0.3, "filter": {"type": "lp", "hz": 800}, "db": -6}]},
	# The bomber's bomb whistling down from its bay.
	"bomb_whistle": {"category": "shot", "seconds": 0.42, "max": 0.45, "layers": [
		{"wave": "sine", "hz": [1300, 450], "a": 0.05, "s": 0.8, "len": 0.32, "r": 0.06, "vibrato": [8.0, 15.0]},
		{"wave": "pink", "a": 0.1, "s": 0.6, "len": 0.3, "r": 0.06, "filter": {"type": "bp", "hz": [2500, 900], "q": 2.0}, "db": -12}]},
	# The brawler's swing; its punch lands as punch_land.
	"melee_swing": {"category": "shot", "seconds": 0.14, "min": 0.08, "layers": [
		{"wave": "pink", "a": 0.03, "d": 0.1, "filter": {"type": "bp", "hz": [600, 2000], "q": 1.2}},
		{"wave": "sine", "hz": [250, 400], "a": 0.02, "d": 0.08, "db": -10}]},

	# The landings (Sounds.LAND_IMPACT, LAND), by the weapon's impact and per type. A spark and a
	# hit are the least important sounds of a battle, a blast more, the biggest the most.
	"impact_small": {"category": "impact", "seconds": 0.3, "min": 0.08, "rms_db": -18.0, "priority": 0, "cooldown": 0.03, "voices": 6,
		"layers": [
		{"wave": "noise", "a": 0.001, "d": 0.04, "filter": {"type": "hp", "hz": 4000}, "db": -3},
		{"wave": "sine", "hz": 2400, "a": 0.001, "d": 0.16, "ring": {"hz": 1730}, "db": -2},
		{"wave": "triangle", "hz": [1600, 900], "glide": 0.05, "a": 0.001, "d": 0.07, "db": -6},
		{"wave": "sine", "hz": [300, 170], "a": 0.002, "d": 0.3, "db": -6}]},
	"explosion_small": {"category": "explosion", "seconds": 0.55, "min": 0.35, "drive": 0.25, "layers": [
		{"wave": "noise", "a": 0.001, "d": 0.35, "filter": {"type": "lp", "hz": [5000, 400]}},
		{"wave": "pink", "a": 0.003, "d": 0.45, "filter": {"type": "lp", "hz": [1500, 250]}, "db": -4},
		{"wave": "sine", "hz": [110, 45], "glide": 0.2, "a": 0.002, "d": 0.3, "db": -2}]},
	"explosion_medium": {"category": "explosion", "seconds": 1.2, "drive": 0.3,
		"echo": {"ms": 90, "feedback": 0.2, "mix": 0.15}, "layers": [
		{"wave": "noise", "a": 0.002, "d": 0.7, "filter": {"type": "lp", "hz": [5000, 300]}},
		{"wave": "pink", "a": 0.004, "d": 0.9, "filter": {"type": "lp", "hz": [1200, 200]}, "db": -4},
		{"wave": "sine", "hz": [90, 40], "glide": 0.3, "a": 0.002, "d": 0.45, "db": -2}]},
	# A sub thump, noise under a falling low-pass, a crackle and a little room.
	"explosion_large": {"category": "explosion", "seconds": 1.45, "drive": 0.35,
		"echo": {"ms": 110, "feedback": 0.25, "mix": 0.18}, "layers": [
		{"wave": "sine", "hz": [70, 30], "glide": 0.5, "a": 0.002, "d": 0.8},
		{"wave": "noise", "a": 0.002, "d": 0.9, "filter": {"type": "lp", "hz": [6000, 200]}, "db": -1},
		{"wave": "pink", "a": 0.005, "d": 1.25, "filter": {"type": "lp", "hz": [1500, 150]}, "db": -3},
		{"wave": "noise", "at": 0.05, "a": 0.01, "d": 0.6, "filter": {"type": "bp", "hz": 2500, "q": 2.0},
			"ring": {"hz": 23}, "db": -12}]},
	"air_burst": {"category": "impact", "seconds": 0.32, "rms_db": -17.0, "layers": [
		{"wave": "noise", "a": 0.001, "d": 0.09, "filter": {"type": "lp", "hz": [8000, 1500]}},
		{"wave": "noise", "a": 0.002, "d": 0.28, "filter": {"type": "hp", "hz": 3500}, "db": -8},
		{"wave": "sine", "hz": [500, 150], "a": 0.001, "d": 0.15, "db": -3}]},
	# The plasma's wet splat: a bubbling sine and a falling hiss.
	"plasma_splash": {"category": "impact", "seconds": 0.38, "layers": [
		{"wave": "noise", "a": 0.003, "d": 0.3, "filter": {"type": "bp", "hz": [2500, 600], "q": 1.5}},
		{"wave": "sine", "hz": [420, 160], "glide": 0.2, "a": 0.002, "d": 0.26, "fm": {"ratio": 3.1, "index": [3.0, 0.0]}, "db": -3},
		{"wave": "triangle", "hz": [900, 300], "a": 0.001, "d": 0.1, "db": -8}]},
	# A beam's burn: a buzzing sizzle round 2 kHz.
	"beam_burn": {"category": "impact", "seconds": 0.26, "layers": [
		{"wave": "noise", "a": 0.005, "d": 0.24, "filter": {"type": "bp", "hz": 2200, "q": 3.0}, "ring": {"hz": 47}},
		{"wave": "sine", "hz": 180, "a": 0.005, "d": 0.2, "db": -10}]},
	# EMP arcs on a unit: a square falling and a crackle.
	"emp_zap": {"category": "impact", "seconds": 0.5, "max": 0.55, "layers": [
		{"wave": "square", "pulse": 0.3, "hz": [2000, 100], "glide": 0.4, "a": 0.002, "d": 0.45,
			"filter": {"type": "lp", "hz": 3000}, "db": -5},
		{"wave": "noise", "a": 0.002, "d": 0.4, "filter": {"type": "bp", "hz": 2000, "q": 3.0}, "ring": {"hz": 30}, "db": -6},
		{"wave": "sine", "hz": [600, 120], "a": 0.002, "d": 0.3}]},
	# The brawler's punch landing: a comic bop.
	"punch_land": {"category": "impact", "seconds": 0.16, "min": 0.1, "layers": [
		{"wave": "sine", "hz": [320, 80], "glide": 0.1, "a": 0.003, "d": 0.14},
		{"wave": "noise", "a": 0.003, "d": 0.02, "filter": {"type": "lp", "hz": 3000}, "db": -6},
		{"wave": "triangle", "hz": [600, 200], "a": 0.003, "d": 0.04, "db": -8}]},
	# The mega mine: deeper and longer than the big blast, a sub rumbling after it.
	"mega_blast": {"category": "explosion", "seconds": 1.65, "max": 1.7, "drive": 0.4, "priority": 4, "voices": 2,
		"echo": {"ms": 130, "feedback": 0.3, "mix": 0.2}, "layers": [
		{"wave": "sine", "hz": [60, 28], "glide": 0.6, "a": 0.002, "d": 1.0},
		{"wave": "noise", "a": 0.002, "d": 1.1, "filter": {"type": "lp", "hz": [5000, 150]}, "db": -1},
		{"wave": "pink", "a": 0.05, "d": 1.6, "filter": {"type": "lp", "hz": [700, 80]}, "db": -2},
		{"wave": "noise", "at": 0.08, "a": 0.01, "d": 0.8, "filter": {"type": "bp", "hz": 2000, "q": 2.0},
			"ring": {"hz": 17}, "db": -12}]},

	# A shot arriving (BattleView._on_arrived): a building's dull knock, a unit's thump (a figure)
	# or clank (a machine); soft and the least important.
	"building_hit": {"category": "impact", "seconds": 0.12, "min": 0.06, "rms_db": -18.0, "priority": 0, "layers": [
		{"wave": "sine", "hz": 180, "a": 0.002, "d": 0.09},
		{"wave": "sine", "hz": 437, "a": 0.002, "d": 0.06, "db": -6},
		{"wave": "noise", "a": 0.002, "d": 0.02, "filter": {"type": "lp", "hz": 1500}, "db": -8}]},
	"unit_hit_figure": {"category": "impact", "seconds": 0.1, "min": 0.05, "rms_db": -19.0, "priority": 0, "layers": [
		{"wave": "sine", "hz": [160, 90], "a": 0.002, "d": 0.08},
		{"wave": "noise", "a": 0.002, "d": 0.03, "filter": {"type": "lp", "hz": 900}, "db": -8}]},
	"unit_hit_machine": {"category": "impact", "seconds": 0.1, "min": 0.05, "rms_db": -19.0, "priority": 0, "layers": [
		{"wave": "sine", "hz": 520, "a": 0.002, "d": 0.08, "ring": {"hz": 310}},
		{"wave": "sine", "hz": 200, "a": 0.002, "d": 0.07, "db": -6},
		{"wave": "noise", "a": 0.002, "d": 0.02, "filter": {"type": "hp", "hz": 2000}, "db": -10}]},

	# The falls (BattleView._fall, _settle): a wall's gravel and thud; a building's groan as it
	# sinks, its rubble and a last thud; the rubble settling; a hidden defence decloaking.
	"wall_crumble": {"category": "impact", "seconds": 0.5, "max": 0.55, "layers": [
		{"wave": "noise", "a": 0.003, "d": 0.42, "filter": {"type": "lp", "hz": [3000, 700]}, "ring": {"hz": 31}},
		{"wave": "sine", "hz": [110, 50], "a": 0.002, "d": 0.2, "db": -2},
		{"wave": "pink", "a": 0.005, "d": 0.4, "filter": {"type": "lp", "hz": 600}, "db": -6}]},
	"building_collapse": {"category": "explosion", "seconds": 1.3, "drive": 0.2, "layers": [
		{"wave": "sine", "hz": [95, 40], "glide": 1.0, "a": 0.08, "d": 0.1, "s": 0.7, "len": 0.9, "r": 0.3,
			"vibrato": [5.0, 40.0]},
		{"wave": "saw", "hz": [190, 80], "glide": 1.0, "a": 0.08, "d": 0.1, "s": 0.7, "len": 0.9, "r": 0.3,
			"vibrato": [6.0, 50.0], "filter": {"type": "lp", "hz": 500}, "db": -10},
		{"wave": "pink", "a": 0.03, "d": 1.2, "filter": {"type": "lp", "hz": [2200, 300]}, "ring": {"hz": 13}, "db": -3},
		{"wave": "noise", "a": 0.002, "d": 0.08, "filter": {"type": "lp", "hz": 3000}, "db": -6},
		{"wave": "sine", "at": 0.75, "hz": [80, 35], "a": 0.002, "d": 0.35},
		{"wave": "noise", "at": 0.75, "a": 0.002, "d": 0.3, "filter": {"type": "lp", "hz": 1200}, "db": -4}]},
	"rubble_settle": {"category": "impact", "seconds": 0.3, "layers": [
		{"wave": "sine", "hz": [100, 45], "a": 0.002, "d": 0.25},
		{"wave": "noise", "a": 0.002, "d": 0.2, "filter": {"type": "lp", "hz": [2500, 400]}, "ring": {"hz": 37}, "db": -4}]},
	"reveal_shimmer": {"category": "chime", "seconds": 0.5, "min": 0.35, "rms_db": -16.0, "chorus": {"mix": 0.4}, "layers": [
		{"wave": "sine", "hz": [500, 1500], "a": 0.15, "d": 0.3, "vibrato": [12.0, 40.0]},
		{"wave": "triangle", "hz": 3000, "at": 0.18, "a": 0.003, "d": 0.18, "db": -8},
		{"wave": "triangle", "hz": 4000, "at": 0.26, "a": 0.003, "d": 0.18, "db": -10}]},

	# The deaths (Sounds.DEATH, DEATH_END, by Weapons.Death): a figure's comic "hup" and its fall;
	# a machine's crunch (its fireball follows: explosion_small); an aircraft's falling whine (its
	# crash: explosion_medium). Many die at once: a cooldown and three voices each.
	"figure_down": {"category": "impact", "seconds": 0.3, "cooldown": 0.06, "voices": 3, "layers": [
		{"wave": "saw", "hz": [170, 110], "a": 0.01, "d": 0.15, "filter": {"type": "bp", "hz": 700, "q": 3.0}, "db": -2},
		{"wave": "sine", "hz": [220, 140], "a": 0.01, "d": 0.12, "db": -6},
		{"wave": "sine", "at": 0.14, "hz": [120, 55], "a": 0.002, "d": 0.14},
		{"wave": "noise", "at": 0.14, "a": 0.002, "d": 0.05, "filter": {"type": "lp", "hz": 900}, "db": -8}]},
	"wreck_crunch": {"category": "impact", "seconds": 0.45, "max": 0.5, "cooldown": 0.06, "voices": 3, "layers": [
		{"wave": "noise", "a": 0.002, "d": 0.35, "filter": {"type": "bp", "hz": 1200, "q": 2.0}, "ring": {"hz": 41}},
		{"wave": "square", "pulse": 0.2, "hz": [300, 90], "a": 0.002, "d": 0.3, "filter": {"type": "lp", "hz": 1200}, "db": -8},
		{"wave": "sine", "hz": [140, 60], "a": 0.002, "d": 0.25, "db": -4}]},
	"crash_whine": {"category": "impact", "seconds": 0.62, "max": 0.7, "cooldown": 0.06, "voices": 3, "layers": [
		{"wave": "sine", "hz": [1400, 300], "a": 0.02, "s": 0.8, "len": 0.5, "r": 0.1, "vibrato": [7.0, 30.0]},
		{"wave": "saw", "hz": [1400, 300], "a": 0.02, "s": 0.8, "len": 0.5, "r": 0.1, "vibrato": [7.0, 30.0],
			"filter": {"type": "lp", "hz": 2000}, "db": -12}]},
	# A grav trap throwing a unit: a whoosh up.
	"unit_thrown": {"category": "impact", "seconds": 0.32, "layers": [
		{"wave": "pink", "a": 0.1, "d": 0.2, "filter": {"type": "bp", "hz": [400, 2500], "q": 1.3}},
		{"wave": "sine", "hz": [250, 700], "a": 0.05, "d": 0.2, "db": -10}]},

	# The traps (BattleView._spring): a click as one pops up; then, TRAP_POP on, a mine's blast
	# (its landing), a flak mine's crack, a grav trap's pulling whoosh while its funnel spins.
	"trap_click": {"category": "impact", "seconds": 0.1, "min": 0.06, "rms_db": -18.0, "priority": 3, "layers": [
		{"wave": "triangle", "hz": 2000, "a": 0.001, "d": 0.015},
		{"wave": "triangle", "hz": 1500, "at": 0.04, "a": 0.001, "d": 0.02},
		{"wave": "sine", "hz": 400, "a": 0.002, "d": 0.08, "db": -4}]},
	"flak_crack": {"category": "impact", "seconds": 0.25, "layers": [
		{"wave": "noise", "a": 0.001, "d": 0.08, "filter": {"type": "lp", "hz": [9000, 2000]}},
		{"wave": "noise", "a": 0.002, "d": 0.2, "filter": {"type": "hp", "hz": 3000}, "db": -6},
		{"wave": "sine", "hz": [800, 200], "a": 0.001, "d": 0.08, "db": -4}]},
	"grav_whoosh": {"category": "loop", "seconds": 1.0, "loop": true, "quiet": true, "layers": [
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 1.1, "filter": {"type": "bp", "hz": 700, "q": 1.5}},
		{"wave": "sine", "hz": 70, "a": 0.0, "s": 1.0, "len": 1.1, "vibrato": [2.0, 300.0], "db": -4},
		{"wave": "saw", "hz": 140, "a": 0.0, "s": 1.0, "len": 1.1, "vibrato": [2.0, 300.0], "filter": {"type": "lp", "hz": 400},
			"db": -12}]},

	# The shields (BattleEffects.set_shield): a dome rising, a shot deflected, the dome shattering,
	# and its hum while any dome is up (BattleView).
	"shield_up": {"category": "chime", "seconds": 0.45, "min": 0.35, "rms_db": -17.0, "chorus": {"mix": 0.4}, "layers": [
		{"wave": "sine", "hz": [110, 220], "a": 0.1, "d": 0.3},
		{"wave": "sine", "hz": [165, 330], "a": 0.1, "d": 0.3, "db": -6},
		{"wave": "triangle", "hz": [880, 1320], "at": 0.2, "a": 0.02, "d": 0.2, "db": -12}]},
	"shield_hit": {"category": "impact", "seconds": 0.16, "min": 0.1, "rms_db": -17.0, "priority": 1, "voices": 3, "layers": [
		{"wave": "sine", "hz": 1760, "a": 0.002, "d": 0.14, "fm": {"ratio": 2.76, "index": [2.0, 0.0]}},
		{"wave": "sine", "hz": 2640, "a": 0.002, "d": 0.1, "db": -8},
		{"wave": "noise", "a": 0.001, "d": 0.01, "filter": {"type": "hp", "hz": 5000}, "db": -12}]},
	"shield_down": {"category": "impact", "seconds": 0.6, "max": 0.65, "chorus": {"mix": 0.3}, "layers": [
		{"wave": "noise", "a": 0.002, "d": 0.3, "filter": {"type": "hp", "hz": 2000}, "db": -4},
		{"wave": "sine", "hz": [1800, 300], "a": 0.002, "d": 0.5, "fm": {"ratio": 1.41, "index": [3.0, 0.0]}},
		{"wave": "triangle", "hz": [900, 150], "a": 0.002, "d": 0.4, "db": -6}]},
	"shield_hum": {"category": "loop", "seconds": 2.0, "loop": true, "quiet": true, "chorus": {"mix": 0.4}, "layers": [
		{"wave": "sine", "hz": 110, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [0.5, 8.0]},
		{"wave": "sine", "hz": 165.5, "a": 0.0, "s": 1.0, "len": 2.1, "db": -6, "vibrato": [1.0, 6.0]},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 2.1, "filter": {"type": "lp", "hz": 500}, "db": -14}]},

	# The EMP burst (BattleView._ability_used): its blast, the crackle held while any defence is
	# out, and a power-up chime as each wakes.
	"emp_burst": {"category": "explosion", "seconds": 0.9, "echo": {"ms": 100, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "square", "pulse": 0.3, "hz": [2200, 90], "glide": 0.5, "a": 0.002, "d": 0.7,
			"filter": {"type": "lp", "hz": [4000, 600]}, "db": -2},
		{"wave": "noise", "a": 0.002, "d": 0.7, "filter": {"type": "bp", "hz": 1500, "q": 2.0}, "ring": {"hz": 23}, "db": -4},
		{"wave": "sine", "hz": [300, 50], "a": 0.002, "d": 0.5}]},
	"emp_hold": {"category": "loop", "seconds": 2.0, "loop": true, "quiet": true, "layers": [
		{"wave": "noise", "a": 0.0, "s": 1.0, "len": 2.1, "filter": {"type": "bp", "hz": 2200, "q": 5.0}, "ring": {"hz": 13},
			"db": -2},
		{"wave": "sine", "hz": 55, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [0.5, 30.0], "db": -4},
		{"wave": "square", "pulse": 0.1, "hz": 31, "a": 0.0, "s": 1.0, "len": 2.1, "filter": {"type": "lp", "hz": 600}, "db": -14}]},
	"emp_wake": {"category": "chime", "seconds": 0.38, "min": 0.2, "rms_db": -19.0, "cooldown": 0.08, "layers": [
		{"wave": "sine", "hz": [300, 900], "glide": 0.15, "a": 0.01, "d": 0.22},
		{"wave": "triangle", "hz": 1320, "at": 0.12, "a": 0.003, "d": 0.22, "db": -6}]},

	# The gravity well's hum while it holds anything (BattleView._hold).
	"vortex_hum": {"category": "loop", "seconds": 2.0, "loop": true, "quiet": true, "chorus": {"mix": 0.35}, "layers": [
		{"wave": "sine", "hz": 80, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [1.5, 200.0]},
		{"wave": "triangle", "hz": 160, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [1.5, 200.0],
			"filter": {"type": "lp", "hz": 600}, "db": -8},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 2.1, "filter": {"type": "bp", "hz": 500, "q": 3.0}, "db": -10}]},

	# The abilities (BattleView._ability_used): the repair swarm's bubbling cast and its buzz for
	# its seconds; the orbital strike's beeping marker until it lands, its bolt's whine as it falls
	# from the sky, and its landing, the biggest blast of a battle.
	"swarm_cast": {"category": "chime", "seconds": 0.45, "min": 0.3, "chorus": {"mix": 0.35}, "layers": [
		{"wave": "sine", "hz": 880, "a": 0.002, "d": 0.08, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}},
		{"wave": "sine", "hz": 1175, "at": 0.04, "a": 0.002, "d": 0.08, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}},
		{"wave": "sine", "hz": 990, "at": 0.08, "a": 0.002, "d": 0.08, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}},
		{"wave": "sine", "hz": 1320, "at": 0.12, "a": 0.002, "d": 0.08, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}},
		{"wave": "sine", "hz": 1047, "at": 0.16, "a": 0.002, "d": 0.1, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}},
		{"wave": "sine", "hz": 1480, "at": 0.2, "a": 0.002, "d": 0.18, "fm": {"ratio": 1.5, "index": [1.5, 0.0]}}]},
	"swarm_hum": {"category": "loop", "seconds": 2.0, "loop": true, "quiet": true, "layers": [
		{"wave": "saw", "hz": 220, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [9.0, 25.0], "filter": {"type": "lp", "hz": 1200}},
		{"wave": "saw", "hz": 223, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [7.0, 30.0], "filter": {"type": "lp", "hz": 1200}},
		{"wave": "triangle", "hz": 440, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [11.0, 20.0], "db": -8}]},
	"strike_marker": {"category": "loop", "seconds": 1.0, "loop": true, "quiet": true, "layers": [
		{"wave": "sine", "hz": [1500, 1200], "a": 0.005, "d": 0.03, "s": 0.8, "len": 0.12, "r": 0.03},
		{"wave": "triangle", "hz": [3000, 2400], "a": 0.005, "d": 0.03, "s": 0.8, "len": 0.12, "r": 0.03, "db": -14},
		{"wave": "sine", "hz": [1500, 1200], "at": 0.5, "a": 0.005, "d": 0.03, "s": 0.8, "len": 0.12, "r": 0.03},
		{"wave": "triangle", "hz": [3000, 2400], "at": 0.5, "a": 0.005, "d": 0.03, "s": 0.8, "len": 0.12, "r": 0.03,
			"db": -14}]},
	"strike_bolt": {"category": "impact", "seconds": 0.55, "max": 0.6, "rms_db": -14.0, "layers": [
		{"wave": "sine", "hz": [300, 2400], "glide": 0.5, "a": 0.45, "d": 0.08},
		{"wave": "saw", "hz": [300, 2400], "glide": 0.5, "a": 0.45, "d": 0.08, "filter": {"type": "lp", "hz": 3000}, "db": -12},
		{"wave": "noise", "a": 0.45, "d": 0.08, "filter": {"type": "hp", "hz": [500, 6000]}, "db": -10}]},
	"strike_land": {"category": "explosion", "seconds": 1.75, "max": 1.8, "rms_db": -11.0, "drive": 0.45, "priority": 4,
		"voices": 2, "echo": {"ms": 140, "feedback": 0.3, "mix": 0.22}, "layers": [
		{"wave": "sine", "hz": [75, 26], "glide": 0.7, "a": 0.002, "d": 1.1},
		{"wave": "noise", "a": 0.001, "d": 1.2, "filter": {"type": "lp", "hz": [9000, 200]}},
		{"wave": "pink", "a": 0.04, "d": 1.7, "filter": {"type": "lp", "hz": [900, 70]}, "db": -2},
		{"wave": "triangle", "hz": [1800, 200], "a": 0.001, "d": 0.2, "db": -8},
		{"wave": "noise", "at": 0.06, "a": 0.01, "d": 0.9, "filter": {"type": "bp", "hz": 2500, "q": 2.0},
			"ring": {"hz": 19}, "db": -11}]},

	# Deploying (BattleUnits.after_step): a ground unit's soft drop and step, an air unit's jet
	# whoosh, each varied in pitch so a smear walks. A deploy or a cast refused buzzes the HUD's
	# ui_denied (BattleHud's toast).
	"deploy_ground": {"category": "impact", "seconds": 0.16, "min": 0.08, "rms_db": -19.0, "cooldown": 0.07, "layers": [
		{"wave": "sine", "hz": [500, 180], "glide": 0.06, "a": 0.002, "d": 0.08},
		{"wave": "sine", "hz": [140, 70], "at": 0.05, "a": 0.002, "d": 0.09, "db": -3},
		{"wave": "noise", "at": 0.05, "a": 0.002, "d": 0.02, "filter": {"type": "lp", "hz": 2000}, "db": -10}]},
	"deploy_air": {"category": "impact", "seconds": 0.25, "rms_db": -19.0, "cooldown": 0.07, "layers": [
		{"wave": "pink", "a": 0.04, "d": 0.18, "filter": {"type": "bp", "hz": [800, 3000], "q": 1.5}},
		{"wave": "sine", "hz": [400, 900], "a": 0.03, "d": 0.15, "db": -10}]},

	# The attack HUD (BattleHud): a star won, the loot ticking up, the last ten seconds, the battle
	# opening (main.open_battle), the speed toggled, End asking.
	"star_earned": {"category": "chime", "seconds": 0.75, "chorus": {"mix": 0.35},
		"echo": {"ms": 110, "feedback": 0.25, "mix": 0.2}, "layers": [
		{"wave": "sine", "hz": E6, "a": 0.003, "d": 0.3, "fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
		{"wave": "sine", "hz": G6, "at": 0.07, "a": 0.003, "d": 0.3, "fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
		{"wave": "sine", "hz": 2093.0, "at": 0.14, "a": 0.003, "d": 0.45, "fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
		{"wave": "triangle", "hz": 4186.0, "at": 0.14, "a": 0.003, "d": 0.3, "db": -14}]},
	"loot_tick": {"category": "ui", "seconds": 0.14, "rms_db": -21.0, "cooldown": 0.12, "layers": [
		{"wave": "sine", "hz": 1976.0, "a": 0.002, "d": 0.05},
		{"wave": "sine", "hz": 2637.0, "at": 0.035, "a": 0.002, "d": 0.1}]},
	"timer_warning": {"category": "ui", "seconds": 0.08, "min": 0.04, "layers": [
		{"wave": "triangle", "hz": 1000, "a": 0.001, "d": 0.03},
		{"wave": "sine", "hz": 500, "a": 0.002, "d": 0.05, "db": -6}]},
	# A brass-like stab (a saw chord opening under a rising low-pass) and a whoosh.
	"battle_start": {"category": "chime", "seconds": 0.85, "rms_db": -16.0, "layers": [
		{"wave": "saw", "hz": 261.63, "a": 0.02, "d": 0.4, "s": 0.4, "len": 0.5, "r": 0.3, "filter": {"type": "lp", "hz": [500, 2600]}},
		{"wave": "saw", "hz": 329.63, "a": 0.02, "d": 0.4, "s": 0.4, "len": 0.5, "r": 0.3, "filter": {"type": "lp", "hz": [500, 2600]},
			"db": -2},
		{"wave": "saw", "hz": 392.0, "a": 0.02, "d": 0.4, "s": 0.4, "len": 0.5, "r": 0.3, "filter": {"type": "lp", "hz": [500, 2600]},
			"db": -2},
		{"wave": "sine", "hz": 130.81, "a": 0.02, "d": 0.4, "s": 0.4, "len": 0.5, "r": 0.3, "db": -4},
		{"wave": "pink", "a": 0.15, "d": 0.25, "filter": {"type": "bp", "hz": [400, 3000], "q": 1.3}, "db": -8}]},
	"speed_toggle": {"category": "ui", "seconds": 0.09, "layers": [
		{"wave": "triangle", "hz": [800, 1600], "a": 0.002, "d": 0.05},
		{"wave": "sine", "hz": 1200, "at": 0.03, "a": 0.002, "d": 0.04, "db": -6}]},
	"confirm_open": {"category": "ui", "seconds": 0.13, "layers": [
		{"wave": "sine", "hz": [600, 900], "a": 0.003, "d": 0.08},
		{"wave": "triangle", "hz": 1350, "at": 0.04, "a": 0.002, "d": 0.07, "db": -8}]},

	# The battle's end (BattleHud, with the result's banner): a victory's bright major arpeggio, its
	# chord held with a chorus and a sparkle over its tail; a defeat's slow minor fall over a soft
	# sub.
	"victory": {"category": "sting", "seconds": 1.85, "chorus": {"mix": 0.35},
		"echo": {"ms": 140, "feedback": 0.25, "mix": 0.18}, "layers": [
		{"wave": "triangle", "hz": C5, "a": 0.004, "d": 0.22},
		{"wave": "triangle", "hz": E5, "at": 0.09, "a": 0.004, "d": 0.22},
		{"wave": "triangle", "hz": G5, "at": 0.18, "a": 0.004, "d": 0.22},
		{"wave": "sine", "hz": C6, "at": 0.27, "a": 0.004, "d": 0.3, "fm": {"ratio": 2.0, "index": [0.8, 0.0]}},
		{"wave": "triangle", "hz": C5, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.55, "len": 0.75, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -3},
		{"wave": "triangle", "hz": E5, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.55, "len": 0.75, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -4},
		{"wave": "sine", "hz": G5, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.55, "len": 0.75, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -4},
		{"wave": "sine", "hz": C6, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.55, "len": 0.75, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -6},
		{"wave": "sine", "hz": 261.63, "at": 0.4, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.75, "r": 0.4, "db": -8},
		{"wave": "triangle", "hz": E6 * 2.0, "at": 0.5, "a": 0.002, "d": 0.2, "db": -12},
		{"wave": "triangle", "hz": G6 * 2.0, "at": 0.62, "a": 0.002, "d": 0.2, "db": -12},
		{"wave": "triangle", "hz": C6 * 4.0, "at": 0.74, "a": 0.002, "d": 0.25, "db": -13},
		{"wave": "triangle", "hz": G6 * 2.0, "at": 0.9, "a": 0.002, "d": 0.3, "db": -14}]},
	"defeat": {"category": "sting", "seconds": 1.65, "chorus": {"mix": 0.3}, "layers": [
		{"wave": "triangle", "hz": E5, "a": 0.03, "d": 0.2, "s": 0.6, "len": 0.28, "r": 0.1, "filter": {"type": "lp", "hz": 1800}},
		{"wave": "triangle", "hz": C5, "at": 0.32, "a": 0.03, "d": 0.2, "s": 0.6, "len": 0.28, "r": 0.1,
			"filter": {"type": "lp", "hz": 1600}},
		{"wave": "triangle", "hz": [440.0, 330.0], "sweep": "lin", "glide": 0.8, "at": 0.64, "a": 0.03, "d": 0.3, "s": 0.6,
			"len": 0.6, "r": 0.3, "vibrato": [5.0, 25.0], "filter": {"type": "lp", "hz": [1500, 600]}},
		{"wave": "sine", "hz": [220.0, 165.0], "sweep": "lin", "glide": 0.8, "at": 0.64, "a": 0.03, "d": 0.3, "s": 0.6,
			"len": 0.6, "r": 0.3, "db": -8},
		{"wave": "sine", "hz": [110.0, 82.4], "sweep": "lin", "glide": 0.8, "at": 0.64, "a": 0.08, "d": 0.3, "s": 0.7,
			"len": 0.6, "r": 0.3, "db": -10}]},

	# Beds under a battle (BattleView): a low wind with gusts and a distant hum from setup to the
	# return, and the aircraft's engines while any is up. The wind's gusts come at uneven times and
	# strengths, each over within the loop, so it never repeats inside its 20 s and its seam joins
	# the steady layers alone.
	"battle_bed": {"category": "loop", "seconds": 20.0, "max": 20.0, "loop": true, "quiet": true, "rms_db": -26.0, "layers": [
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "filter": {"type": "lp", "hz": 350}},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 20.1, "filter": {"type": "bp", "hz": 700, "q": 1.0}, "db": -14},
		{"wave": "pink", "at": 0.4, "a": 1.6, "d": 3.0, "s": 0.7, "len": 2.2, "r": 1.5, "filter": {"type": "bp", "hz": 650, "q": 1.0},
			"db": -6},
		{"wave": "pink", "at": 3.9, "a": 1.0, "d": 3.0, "s": 0.7, "len": 1.6, "r": 1.2, "filter": {"type": "bp", "hz": 820, "q": 1.0},
			"db": -9},
		{"wave": "pink", "at": 6.3, "a": 2.2, "d": 3.0, "s": 0.7, "len": 3.0, "r": 2.0, "filter": {"type": "bp", "hz": 560, "q": 1.0},
			"db": -5},
		{"wave": "pink", "at": 11.7, "a": 0.8, "d": 3.0, "s": 0.7, "len": 1.2, "r": 1.0, "filter": {"type": "bp", "hz": 900, "q": 1.0},
			"db": -10},
		{"wave": "pink", "at": 13.6, "a": 1.5, "d": 3.0, "s": 0.7, "len": 2.4, "r": 1.6, "filter": {"type": "bp", "hz": 700, "q": 1.0},
			"db": -7},
		{"wave": "pink", "at": 17.0, "a": 0.9, "d": 3.0, "s": 0.7, "len": 1.0, "r": 0.8, "filter": {"type": "bp", "hz": 760, "q": 1.0},
			"db": -11},
		{"wave": "sine", "hz": 55, "a": 0.0, "s": 1.0, "len": 20.1, "db": -12},
		{"wave": "sine", "hz": 82.5, "a": 0.0, "s": 1.0, "len": 20.1, "vibrato": [0.2, 10.0], "db": -16}]},
	"air_bed": {"category": "loop", "seconds": 3.0, "loop": true, "quiet": true, "rms_db": -26.0, "layers": [
		{"wave": "saw", "hz": 98, "a": 0.0, "s": 1.0, "len": 3.1, "vibrato": [0.33, 15.0], "filter": {"type": "lp", "hz": 500}},
		{"wave": "saw", "hz": 147.5, "a": 0.0, "s": 1.0, "len": 3.1, "filter": {"type": "lp", "hz": 500}, "db": -6},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 3.1, "filter": {"type": "bp", "hz": 1200, "q": 1.0}, "db": -10}]},
}

## The sound a weapon's shot makes (fire_key()), by its kind (Weapons.Kind), or by its type id where
## FIRE has it. Every kind has an entry: &"" is silent, and says why. Read by BattleEffects.fire()
## and, for a melee blow, BattleView._unit_hit().
const FIRE_KIND := {
	Weapons.Kind.NONE: &"",
	Weapons.Kind.BOLT: &"bolt_fire",
	Weapons.Kind.LASER: &"laser_fire",
	Weapons.Kind.TRACER: &"flak_fire",
	Weapons.Kind.PLASMA: &"shell_fire",
	Weapons.Kind.BALL: &"orbital_fire",
	Weapons.Kind.SHELL: &"tank_fire",
	Weapons.Kind.MISSILE: &"missile_fire",
	Weapons.Kind.BOMB: &"bomb_whistle",
	Weapons.Kind.STREAK: &"railgun_fire",
	Weapons.Kind.BEAM: &"beam_fire",
	Weapons.Kind.LIGHTNING: &"arc_zap",
	Weapons.Kind.PULSE: &"emp_pulse",
	# The gravity well's hold is its hum, a loop BattleView holds while it pulls (vortex_hum).
	Weapons.Kind.VORTEX: &"",
	Weapons.Kind.MELEE: &"melee_swing",
	# The breacher's charge goes off where it stands at once: its blast (LAND_IMPACT) is its sound.
	Weapons.Kind.CHARGE: &"",
	# The traps fire nothing: their sounds are their spring's (TRAP) and their blast's (LAND).
	Weapons.Kind.MINE: &"",
	Weapons.Kind.FLAK_MINE: &"",
	Weapons.Kind.MEGA_MINE: &"",
	Weapons.Kind.GRAV_TRAP: &"",
	# A shield generator's dome sounds as it rises, absorbs and falls (BattleEffects.set_shield).
	Weapons.Kind.SHIELD: &"",
}
const FIRE := {
	"cloaked_sentry": &"sentry_fire",
	"dune_runner": &"tracer_fire",
	"gunship": &"tracer_fire",
	"skimmer": &"skimmer_beam",
	"siege_walker": &"walker_fire",
	"titan": &"titan_fire",
}
## The sound where a weapon lands (land_key()), by its impact (Weapons.Impact), or by its type id
## where LAND has it; every impact has an entry. Read by BattleEffects.land() and, for a punch,
## BattleView._land_blows().
const LAND_IMPACT := {
	# A weapon that lands nothing (the gravity well, the grav trap, the shield, the brawler: LAND).
	Weapons.Impact.NONE: &"",
	Weapons.Impact.SPARKS: &"impact_small",
	Weapons.Impact.RING: &"impact_small",
	Weapons.Impact.BLAST_S: &"explosion_small",
	Weapons.Impact.BLAST_M: &"explosion_medium",
	Weapons.Impact.BLAST_L: &"explosion_large",
	Weapons.Impact.AIR_BURST: &"air_burst",
	Weapons.Impact.SPLASH: &"plasma_splash",
	Weapons.Impact.BURN: &"beam_burn",
	Weapons.Impact.EMP: &"emp_zap",
}
const LAND := {
	"brawler": &"punch_land",
	"mega_mine": &"mega_blast",
}


## The sound a building tapped makes, by its category (PlacementController); one not listed takes
## the core's.
const SELECT := {
	"core": &"select_building_core",
	"resources": &"select_building_resources",
	"army": &"select_building_army",
	"defense": &"select_building_defense",
	"traps": &"select_building_traps",
}


## The key `type`'s shot plays, &"" for none.
static func fire_key(type: String) -> StringName:
	var key: StringName = FIRE.get(type, FIRE_KIND[Weapons.of(type).kind])
	return key


## The key `type`'s landing plays, &"" for none.
static func land_key(type: String) -> StringName:
	var key: StringName = LAND.get(type, LAND_IMPACT[Weapons.of(type).impact])
	return key


## The key a building of `category` plays when tapped.
static func select_key(category: String) -> StringName:
	var key: StringName = SELECT.get(category, &"select_building_core")
	return key


## `key`'s field `name`: the recipe's own, else its category's.
static func field(key: StringName, name: String) -> Variant:
	var recipe: Dictionary = TABLE[String(key)]
	if recipe.has(name):
		return recipe[name]
	var category: Dictionary = CATEGORIES[recipe["category"]]
	return category[name]
