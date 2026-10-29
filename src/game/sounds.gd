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
	# The menus.
	"ui_tap": {"category": "ui", "seconds": 0.09, "layers": [
		{"wave": "sine", "hz": [1250, 880], "glide": 0.04, "a": 0.002, "d": 0.07},
		{"wave": "triangle", "hz": 2500, "a": 0.001, "d": 0.02, "db": -12}]},
	"ui_open": {"category": "ui", "seconds": 0.22, "max": 0.25, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.07, "d": 0.12, "filter": {"type": "bp", "hz": [400, 2600], "q": 1.4}},
		{"wave": "sine", "hz": [320, 760], "a": 0.03, "d": 0.16, "db": -4}]},
	"ui_close": {"category": "ui", "seconds": 0.22, "max": 0.25, "rms_db": -18.0, "layers": [
		{"wave": "pink", "a": 0.05, "d": 0.14, "filter": {"type": "bp", "hz": [2600, 450], "q": 1.4}},
		{"wave": "sine", "hz": [760, 300], "a": 0.02, "d": 0.16, "db": -8}]},

	# The base.
	"select_building": {"category": "ui", "seconds": 0.14, "layers": [
		{"wave": "triangle", "hz": 660, "a": 0.002, "d": 0.06},
		{"wave": "sine", "hz": 990, "at": 0.045, "a": 0.002, "d": 0.08}]},
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

## `key`'s field `name`: the recipe's own, else its category's.
static func field(key: StringName, name: String) -> Variant:
	var recipe: Dictionary = TABLE[String(key)]
	if recipe.has(name):
		return recipe[name]
	var category: Dictionary = CATEGORIES[recipe["category"]]
	return category[name]
