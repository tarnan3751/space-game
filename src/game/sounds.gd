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

	# The battle: shots, impacts and blasts.
	"laser_fire": {"category": "shot", "seconds": 0.2, "layers": [
		{"wave": "triangle", "hz": [2200, 380], "glide": 0.14, "a": 0.002, "d": 0.15, "fm": {"ratio": 2.0, "index": [1.0, 0.0]}},
		{"wave": "sine", "hz": [1100, 250], "glide": 0.14, "a": 0.002, "d": 0.14, "db": -6},
		{"wave": "noise", "a": 0.001, "d": 0.02, "filter": {"type": "hp", "hz": 5000}, "db": -14}]},
	"shell_fire": {"category": "shot", "seconds": 0.28, "layers": [
		{"wave": "sine", "hz": [180, 60], "glide": 0.12, "a": 0.002, "d": 0.2},
		{"wave": "noise", "a": 0.002, "d": 0.12, "filter": {"type": "lp", "hz": [3000, 400]}, "db": -6},
		{"wave": "triangle", "hz": 90, "a": 0.004, "d": 0.2, "db": -6}]},
	"missile_fire": {"category": "shot", "seconds": 0.3, "layers": [
		{"wave": "noise", "a": 0.015, "d": 0.26, "filter": {"type": "bp", "hz": [500, 2200], "q": 2.0}},
		{"wave": "saw", "hz": [200, 520], "a": 0.01, "d": 0.2, "filter": {"type": "lp", "hz": 1200}, "db": -14},
		{"wave": "sine", "hz": [120, 70], "a": 0.002, "d": 0.08, "db": -6}]},
	"impact_small": {"category": "impact", "seconds": 0.3, "layers": [
		{"wave": "noise", "a": 0.001, "d": 0.04, "filter": {"type": "hp", "hz": 2500}, "db": -3},
		{"wave": "triangle", "hz": [1600, 600], "glide": 0.06, "a": 0.001, "d": 0.12, "db": -4},
		{"wave": "sine", "hz": [300, 170], "glide": 0.15, "a": 0.002, "d": 0.28}]},
	"explosion_medium": {"category": "explosion", "seconds": 1.2, "drive": 0.3,
		"echo": {"ms": 90, "feedback": 0.2, "mix": 0.15}, "layers": [
		{"wave": "noise", "a": 0.002, "d": 0.7, "filter": {"type": "lp", "hz": [5000, 300]}},
		{"wave": "pink", "a": 0.004, "d": 0.9, "filter": {"type": "lp", "hz": [1200, 200]}, "db": -4},
		{"wave": "sine", "hz": [90, 40], "glide": 0.3, "a": 0.002, "d": 0.45, "db": -2}]},

	# The battle's end.
	"victory": {"category": "sting", "seconds": 1.7, "chorus": {"mix": 0.3},
		"echo": {"ms": 140, "feedback": 0.2, "mix": 0.15}, "layers": [
		{"wave": "triangle", "hz": G5, "a": 0.004, "d": 0.25},
		{"wave": "triangle", "hz": C6, "at": 0.12, "a": 0.004, "d": 0.25},
		{"wave": "triangle", "hz": E6, "at": 0.24, "a": 0.004, "d": 0.25},
		{"wave": "sine", "hz": G6, "at": 0.36, "a": 0.004, "d": 0.4},
		{"wave": "triangle", "hz": C5, "at": 0.48, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.6, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -3},
		{"wave": "triangle", "hz": E5, "at": 0.48, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.6, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -4},
		{"wave": "sine", "hz": G5, "at": 0.48, "a": 0.02, "d": 0.3, "s": 0.5, "len": 0.6, "r": 0.5,
			"vibrato": [5.0, 12.0], "db": -4}]},
	"defeat": {"category": "sting", "seconds": 1.5, "chorus": {"mix": 0.25}, "layers": [
		{"wave": "triangle", "hz": [392, 370], "a": 0.02, "d": 0.2, "s": 0.6, "len": 0.25, "r": 0.08,
			"filter": {"type": "lp", "hz": 1800}},
		{"wave": "triangle", "hz": [349, 330], "at": 0.3, "a": 0.02, "d": 0.2, "s": 0.6, "len": 0.25, "r": 0.08,
			"filter": {"type": "lp", "hz": 1800}},
		{"wave": "triangle", "hz": [330, 247], "sweep": "lin", "glide": 0.7, "at": 0.6, "a": 0.02, "d": 0.3, "s": 0.6,
			"len": 0.6, "r": 0.25, "vibrato": [6.0, 30.0], "filter": {"type": "lp", "hz": [1800, 700]}},
		{"wave": "sine", "hz": [165, 124], "sweep": "lin", "glide": 0.7, "at": 0.6, "a": 0.02, "d": 0.3, "s": 0.6,
			"len": 0.6, "r": 0.25, "db": -8}]},

	# Continuous: a shield generator's dome while it is up (for the battle lane to hook).
	"shield_hum": {"category": "loop", "seconds": 2.0, "loop": true, "quiet": true, "chorus": {"mix": 0.4}, "layers": [
		{"wave": "sine", "hz": 110, "a": 0.0, "s": 1.0, "len": 2.1, "vibrato": [0.5, 8.0]},
		{"wave": "sine", "hz": 165.5, "a": 0.0, "s": 1.0, "len": 2.1, "db": -6, "vibrato": [1.0, 6.0]},
		{"wave": "pink", "a": 0.0, "s": 1.0, "len": 2.1, "filter": {"type": "lp", "hz": 500}, "db": -14}]},
}

## The sound a weapon's shot and its landing make, by its type id (Weapons.Weapon.type): read by
## BattleEffects.fire() and land(). A type with none is silent.
const FIRE := {
	"laser_turret": &"laser_fire",
	"plasma_mortar": &"shell_fire",
	"missile_battery": &"missile_fire",
}
const LAND := {
	"laser_turret": &"impact_small",
	"plasma_mortar": &"explosion_medium",
	"missile_battery": &"explosion_medium",
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
	var key: StringName = FIRE.get(type, &"")
	return key


## The key `type`'s landing plays, &"" for none.
static func land_key(type: String) -> StringName:
	var key: StringName = LAND.get(type, &"")
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
