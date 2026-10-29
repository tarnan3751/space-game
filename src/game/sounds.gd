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

const TABLE := {}


## `key`'s field `name`: the recipe's own, else its category's.
static func field(key: StringName, name: String) -> Variant:
	var recipe: Dictionary = TABLE[String(key)]
	if recipe.has(name):
		return recipe[name]
	var category: Dictionary = CATEGORIES[recipe["category"]]
	return category[name]
