extends SceneTree
## Renders the game's sound effects: every recipe in Sounds.TABLE (src/game/sounds.gd) to
## assets/audio/sfx/<key>.wav, 44.1 kHz 16-bit mono, with the .import file beside it, then checks
## every file and prints a table (docs/reference/audio.md, **The generator**). Run it after an
## import (tools/gates.sh does one), from the project root:
##
##   $GODOT --headless --path . -s res://tools/gen_sounds.gd [-- --only=laser_fire,ui_tap]
##
## `--only` renders the keys named and leaves the other files alone. Exits 1 when a recipe is
## unknown or a file fails a check (check()), naming the check.
##
## A recipe's layers are summed (render_layer: an oscillator, its ADSR envelope, pitch sweep and
## vibrato, FM or ring modulation, a swept filter, a start delay and a gain), then the master
## chain runs (master()): chorus, echo, drive, DC removal, normalisation to the category's
## loudness capped at the recipe's peak, a trim of the silence at both ends, and the fades (a
## loop gets its tail crossfaded into its head instead). Noise comes from SeededRng seeded by the
## key, so a run writes byte-identical files. The .import file asks for PCM (no compression) and
## the loop the recipe asks for; written whole, with the uid the file had (or one made from its
## path), the editor's import leaves it as it is.

const RATE := 44100
const OUT_DIR := "res://assets/audio/sfx"
const ONLY_ARG := "--only="
## A layer's defaults: the oscillator (sine, triangle, saw, square, noise, pink), its pitch (Hz,
## or [start, end] swept exponentially or linearly over `glide` seconds, the layer's length when
## 0), the square's pulse width, vibrato [rate Hz, depth cents], the envelope (attack, decay to
## the sustain level, the gate length before the release, the release; decay and release are
## exponential and given as the seconds to fall 60 dB; a gate of 0 is attack plus decay), its
## start delay, its gain (dB), and its filter, FM and ring modulation (none).
const LAYER := {
	"wave": "sine", "hz": 440.0, "sweep": "exp", "glide": 0.0, "pulse": 0.5, "vibrato": [0.0, 0.0],
	"a": 0.005, "d": 0.1, "s": 0.0, "len": 0.0, "r": 0.05, "at": 0.0, "db": 0.0,
	"filter": {}, "fm": {}, "ring": {},
}
## A filter's defaults: lp, hp or bp (biquads) or lp1 (one pole), its cutoff (Hz, or [start, end]
## swept exponentially over the layer) and its Q.
const FILTER := {"type": "lp", "hz": 1000.0, "q": 0.707}
## The master chain's defaults: the peak the normalisation never passes (dBFS), quiet (a lower
## peak floor), the chorus, the echo and the drive (0 none, 1 hard).
const RECIPE := {"peak_db": -3.0, "quiet": false, "loop": false, "chorus": {}, "echo": {}, "drive": 0.0}
const CHORUS := {"ms": 12.0, "depth_ms": 3.0, "rate": 0.8, "mix": 0.4}
const ECHO := {"ms": 120.0, "feedback": 0.3, "mix": 0.25}
## -60 dB: the envelope's decay constant, and the level the trim and the silence check count as
## silent.
const LN_1000 := 6.907755
const SILENT := 0.001
## The trim's margin and the shortest fades (seconds); the loop's crossfade.
const TRIM_MARGIN := 0.002
const FADE_IN := 0.002
const FADE_OUT := 0.005
const LOOP_CROSSFADE := 0.03
## The checks (check()): the peak's ceiling and floors (dBFS), the DC limit (full scale), the
## first and last samples' limit, the edge steps' floor and the edge's length, the longest
## silence inside a one-shot, the loudness window and its tolerance (dB).
const PEAK_MAX_DB := -0.5
const PEAK_MIN_DB := -12.0
const PEAK_MIN_QUIET_DB := -30.0
const DC_MAX := 0.005
const EDGE_MAX := 0.001
const EDGE_STEP := 0.05
const EDGE_SECONDS := 0.002
const SILENCE_MAX := 0.05
const WINDOW := 0.05
const RMS_TOLERANCE := 3.0


func _initialize() -> void:
	var keys := PackedStringArray()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(ONLY_ARG):
			keys = arg.trim_prefix(ONLY_ARG).split(",", false)
	if keys.is_empty():
		for key: String in Sounds.TABLE:
			keys.append(key)
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var failed := 0
	print("gen_sounds: %-18s %-9s %7s %8s %8s %8s  %s" % ["key", "category", "seconds", "peak", "rms_50ms", "rms",
		"result"])
	for key: String in keys:
		if not Sounds.TABLE.has(key):
			printerr("gen_sounds: no recipe %s" % key)
			failed += 1
			continue
		var recipe: Dictionary = Sounds.TABLE[key]
		var samples := render(key, recipe)
		var path := "%s/%s.wav" % [OUT_DIR, key]
		var error := write(path, samples, bool(_field(recipe, RECIPE, "loop")))
		if error != "":
			printerr("gen_sounds: %s: %s" % [key, error])
			failed += 1
			continue
		var stats := {}
		var problems := check(key, recipe, path, samples, stats)
		print("gen_sounds: %-18s %-9s %7.3f %8.1f %8.1f %8.1f  %s" % [key, recipe["category"], stats["seconds"],
			stats["peak_db"], stats["window_db"], stats["rms_db"], "ok" if problems.is_empty() else "; ".join(problems)])
		if not problems.is_empty():
			failed += 1
	if failed > 0:
		printerr("gen_sounds: %d of %d failed" % [failed, keys.size()])
		quit(1)
		return
	print("gen_sounds: %d written to %s" % [keys.size(), OUT_DIR])
	quit(0)


# --- Rendering ---------------------------------------------------------------------

## `recipe` (of `key`) as 16-bit samples, the master chain run.
static func render(key: String, recipe: Dictionary) -> PackedInt32Array:
	var seconds: float = recipe["seconds"]
	var loop: bool = _field(recipe, RECIPE, "loop")
	if loop:
		seconds += LOOP_CROSSFADE
	var count := int(seconds * RATE)
	var mix := PackedFloat32Array()
	mix.resize(count)
	var rng := SeededRng.new(int(_field(recipe, {"seed": fnv(key)}, "seed")))
	for layer: Dictionary in recipe["layers"]:
		var voice := render_layer(layer, count, rng)
		for i: int in count:
			mix[i] += voice[i]
	return master(key, recipe, mix)


## One layer, `count` samples long (silent before its start and after its release).
static func render_layer(layer: Dictionary, count: int, rng: SeededRng) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(count)
	var wave: String = _field(layer, LAYER, "wave")
	var attack: float = _field(layer, LAYER, "a")
	var decay: float = _field(layer, LAYER, "d")
	var sustain: float = _field(layer, LAYER, "s")
	var release: float = _field(layer, LAYER, "r")
	var gate: float = _field(layer, LAYER, "len")
	if gate <= 0.0:
		gate = attack + decay
	var start := int(float(_field(layer, LAYER, "at")) * RATE)
	var length := mini(int((gate + release) * RATE), count - start)
	if length <= 0:
		return out
	var lasts := float(length) / RATE
	var hz: Variant = _field(layer, LAYER, "hz")
	var hz_from := _first(hz)
	var hz_to := _last(hz)
	var exponential: bool = _field(layer, LAYER, "sweep") == "exp"
	var glide: float = _field(layer, LAYER, "glide")
	if glide <= 0.0:
		glide = lasts
	var pulse: float = _field(layer, LAYER, "pulse")
	var vibrato: Array = _field(layer, LAYER, "vibrato")
	var vibrato_rate: float = vibrato[0]
	var vibrato_cents: float = vibrato[1]
	var gain := db_to_linear(float(_field(layer, LAYER, "db")))
	var fm: Dictionary = _field(layer, LAYER, "fm")
	var fm_ratio: float = fm.get("ratio", 1.0)
	var index_from := _first(fm.get("index", 0.0))
	var index_to := _last(fm.get("index", 0.0))
	var ring: Dictionary = _field(layer, LAYER, "ring")
	var ring_hz: float = ring.get("hz", 0.0)
	var filter: Dictionary = _field(layer, LAYER, "filter")
	var filtered := not filter.is_empty()
	var filter_type: String = _field(filter, FILTER, "type")
	var cut: Variant = _field(filter, FILTER, "hz")
	var cut_from := _first(cut)
	var cut_to := _last(cut)
	var q: float = _field(filter, FILTER, "q")
	var biquad := Biquad.new()
	var low := 0.0
	var phase := 0.0
	var mod_phase := 0.0
	var pink := PackedFloat32Array([0.0, 0.0, 0.0])
	var level := 0.0
	var held := 0.0
	for n: int in length:
		var t := float(n) / RATE
		var g := clampf(t / glide, 0.0, 1.0)
		var f := hz_from * pow(hz_to / hz_from, g) if exponential else lerpf(hz_from, hz_to, g)
		if vibrato_cents != 0.0:
			f *= pow(2.0, vibrato_cents / 1200.0 * sin(TAU * vibrato_rate * t))
		var offset := 0.0
		if not fm.is_empty():
			mod_phase = fmod(mod_phase + f * fm_ratio / RATE, 1.0)
			offset = lerpf(index_from, index_to, t / lasts) * sin(TAU * mod_phase) / TAU
		phase = fmod(phase + f / RATE, 1.0)
		var x := 0.0
		var p := fposmod(phase + offset, 1.0)
		match wave:
			"sine":
				x = sin(TAU * p)
			"triangle":
				x = 1.0 - 4.0 * absf(p - 0.5)
			"saw":
				x = 2.0 * p - 1.0
			"square":
				x = 1.0 if p < pulse else -1.0
			"noise":
				x = _white(rng)
			"pink":
				var w := _white(rng)
				pink[0] = 0.99765 * pink[0] + w * 0.099046
				pink[1] = 0.963 * pink[1] + w * 0.2965164
				pink[2] = 0.57 * pink[2] + w * 1.0526913
				x = (pink[0] + pink[1] + pink[2] + w * 0.1848) * 0.25
		if ring_hz > 0.0:
			x *= sin(TAU * ring_hz * t)
		if filtered:
			var c := clampf(cut_from * pow(cut_to / cut_from, t / lasts), 10.0, RATE * 0.45)
			if filter_type == "lp1":
				low += (1.0 - exp(-TAU * c / RATE)) * (x - low)
				x = low
			else:
				if n % 16 == 0:
					biquad.design(filter_type, c, q)
				x = biquad.run(x)
		# The envelope: attack, decay to the sustain, held to the gate, then the release.
		if t < attack:
			level = t / attack
			held = level
		elif t < gate:
			level = sustain + (1.0 - sustain) * exp(-LN_1000 * (t - attack) / maxf(decay, 0.0001))
			held = level
		else:
			level = held * exp(-LN_1000 * (t - gate) / maxf(release, 0.0001))
		out[start + n] = x * level * gain
	return out


## The master chain over the summed layers: chorus, echo, drive, DC removal, normalisation, then
## the trim and the fades (a one-shot) or the crossfade (a loop); 16-bit samples. `key` names the
## loudness target.
static func master(key: String, recipe: Dictionary, mix: PackedFloat32Array) -> PackedInt32Array:
	var chorus: Dictionary = _field(recipe, RECIPE, "chorus")
	if not chorus.is_empty():
		mix = _chorus(mix, chorus)
	var echo: Dictionary = _field(recipe, RECIPE, "echo")
	if not echo.is_empty():
		mix = _echo(mix, echo)
	var drive: float = _field(recipe, RECIPE, "drive")
	if drive > 0.0:
		var top := _peak(mix)
		var k := 1.0 + drive * 6.0
		for i: int in mix.size():
			mix[i] = tanh(k * mix[i] / top) / tanh(k)
	# DC: a one-pole high-pass at 20 Hz, then what mean is left.
	var r := exp(-TAU * 20.0 / RATE)
	var previous := 0.0
	var y := 0.0
	var sum := 0.0
	for i: int in mix.size():
		y = mix[i] - previous + r * y
		previous = mix[i]
		mix[i] = y
		sum += y
	var mean := sum / mix.size()
	for i: int in mix.size():
		mix[i] -= mean
	# Normalised to the category's loudness, the peak never past the recipe's.
	var target := db_to_linear(float(Sounds.field(StringName(key), "rms_db")))
	var gain := minf(target / maxf(window_rms(mix), 1e-9), db_to_linear(float(_field(recipe, RECIPE, "peak_db"))) / _peak(mix))
	for i: int in mix.size():
		mix[i] *= gain
	if bool(_field(recipe, RECIPE, "loop")):
		mix = _crossfade(mix, int(LOOP_CROSSFADE * RATE))
	else:
		mix = _trim(mix)
		_fade(mix)
	var out := PackedInt32Array()
	out.resize(mix.size())
	for i: int in mix.size():
		out[i] = clampi(roundi(mix[i] * 32767.0), -32768, 32767)
	return out


static func _chorus(mix: PackedFloat32Array, chorus: Dictionary) -> PackedFloat32Array:
	var base: float = _field(chorus, CHORUS, "ms")
	var depth: float = _field(chorus, CHORUS, "depth_ms")
	var rate: float = _field(chorus, CHORUS, "rate")
	var wet: float = _field(chorus, CHORUS, "mix")
	var out := mix.duplicate()
	for i: int in mix.size():
		var back := (base + depth * sin(TAU * rate * i / RATE)) * 0.001 * RATE
		var at := float(i) - back
		if at < 0.0:
			continue
		var j := int(at)
		var frac := at - j
		var later := mix[j + 1] if j + 1 < mix.size() else 0.0
		out[i] += wet * lerpf(mix[j], later, frac)
	return out


static func _echo(mix: PackedFloat32Array, echo: Dictionary) -> PackedFloat32Array:
	var gap := int(float(_field(echo, ECHO, "ms")) * 0.001 * RATE)
	var feedback: float = _field(echo, ECHO, "feedback")
	var wet: float = _field(echo, ECHO, "mix")
	var taps := PackedFloat32Array()
	taps.resize(mix.size())
	var out := mix.duplicate()
	for i: int in range(gap, mix.size()):
		taps[i] = mix[i - gap] + feedback * taps[i - gap]
		out[i] += wet * taps[i]
	return out


## The samples from the first to the last above SILENT, with TRIM_MARGIN either side.
static func _trim(mix: PackedFloat32Array) -> PackedFloat32Array:
	var first := 0
	while first < mix.size() and absf(mix[first]) < SILENT:
		first += 1
	var last := mix.size() - 1
	while last > first and absf(mix[last]) < SILENT:
		last -= 1
	var margin := int(TRIM_MARGIN * RATE)
	return mix.slice(maxi(first - margin, 0), mini(last + margin + 1, mix.size()))


## Raised-cosine fades: in over FADE_IN, out over FADE_OUT to exactly zero at the last sample.
static func _fade(mix: PackedFloat32Array) -> void:
	var fade_in := mini(int(FADE_IN * RATE), mix.size())
	for i: int in fade_in:
		mix[i] *= 0.5 - 0.5 * cos(PI * i / fade_in)
	var fade_out := mini(int(FADE_OUT * RATE), mix.size())
	var n := mix.size()
	for i: int in fade_out:
		mix[n - 1 - i] *= 0.5 - 0.5 * cos(PI * i / fade_out)


## A loop `fade` samples shorter: its tail, past the loop's end, crossfaded into its head, so the
## wrap from the last sample to the first continues the waveform.
static func _crossfade(mix: PackedFloat32Array, fade: int) -> PackedFloat32Array:
	var n := mix.size() - fade
	var out := mix.slice(0, n)
	for i: int in fade:
		var w := float(i) / fade
		out[i] = mix[i] * w + mix[n + i] * (1.0 - w)
	return out


static func _white(rng: SeededRng) -> float:
	return float(rng.next_u32()) / 2147483648.0 - 1.0


## FNV-1a over the key's bytes: the default noise seed, the same in every engine version.
static func fnv(key: String) -> int:
	var h := 2166136261
	for b: int in key.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & SeededRng.MASK_32
	return h


# --- Writing -----------------------------------------------------------------------

## Saves `samples` as a 16-bit mono WAV at `path` and the .import beside it: "" or the error.
static func write(path: String, samples: PackedInt32Array, loop: bool) -> String:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i: int in samples.size():
		data.encode_s16(i * 2, samples[i])
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	var error := wav.save_to_wav(path)
	if error != OK:
		return "could not save %s: %s" % [path, error_string(error)]
	var import_path := path + ".import"
	var uid := ""
	if FileAccess.file_exists(import_path):
		var old := ConfigFile.new()
		if old.load(import_path) == OK:
			uid = old.get_value("remap", "uid", "")
	if uid == "":
		uid = ResourceUID.id_to_text(ResourceUID.create_id_for_path(path))
	var imported := "res://.godot/imported/%s-%s.sample" % [path.get_file(), path.md5_text()]
	var text := "[remap]\n\nimporter=\"wav\"\ntype=\"AudioStreamWAV\"\nuid=\"%s\"\npath=\"%s\"\n\n" % [uid, imported]
	text += "[deps]\n\nsource_file=\"%s\"\ndest_files=[\"%s\"]\n\n" % [path, imported]
	text += "[params]\n\nforce/8_bit=false\nforce/mono=false\nforce/max_rate=false\nforce/max_rate_hz=44100\n"
	text += "edit/trim=false\nedit/normalize=false\n"
	# The importer's loop modes: 1 disabled, 2 forward; compress mode 0 is PCM.
	text += "edit/loop_mode=%d\nedit/loop_begin=0\nedit/loop_end=%d\ncompress/mode=0\n" \
		% [2 if loop else 1, samples.size() if loop else -1]
	var file := FileAccess.open(import_path, FileAccess.WRITE)
	if file == null:
		return "could not write %s" % import_path
	file.store_string(text)
	return ""


# --- Checking ----------------------------------------------------------------------

## What is wrong with the file at `path`, rendered from `recipe` (of `key`) as `samples`: each
## failed check named; empty when it passes. Fills `stats` with its seconds, peak and loudness.
static func check(key: String, recipe: Dictionary, path: String, samples: PackedInt32Array,
		stats: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var read := AudioStreamWAV.load_from_file(path)
	if read == null or read.format != AudioStreamWAV.FORMAT_16_BITS or read.mix_rate != RATE or read.stereo:
		problems.append("format")
	elif read.data.size() != samples.size() * 2:
		problems.append("read back %d bytes, wrote %d" % [read.data.size(), samples.size() * 2])
	else:
		for i: int in samples.size():
			if read.data.decode_s16(i * 2) != samples[i]:
				problems.append("read back differs at %d" % i)
				break
	var x := PackedFloat32Array()
	x.resize(samples.size())
	for i: int in samples.size():
		x[i] = samples[i] / 32768.0
	problems.append_array(check_samples(key, recipe, x, stats))
	return problems


## The checks on the samples themselves (check()): peak, DC, clicks, silence, length, loudness.
static func check_samples(key: String, recipe: Dictionary, x: PackedFloat32Array, stats: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	var n := x.size()
	var seconds := float(n) / RATE
	var peak := _peak(x)
	var sum := 0.0
	var squares := 0.0
	for v: float in x:
		sum += v
		squares += v * v
	var peak_db := linear_to_db(maxf(peak, 1e-9))
	var window_db := linear_to_db(maxf(window_rms(x), 1e-9))
	stats["seconds"] = seconds
	stats["peak_db"] = peak_db
	stats["window_db"] = window_db
	stats["rms_db"] = linear_to_db(maxf(sqrt(squares / maxi(n, 1)), 1e-9))
	if n == 0:
		problems.append("empty")
		return problems
	var quiet: bool = _field(recipe, RECIPE, "quiet")
	if peak_db > PEAK_MAX_DB:
		problems.append("peak %.1f dB over %.1f" % [peak_db, PEAK_MAX_DB])
	if peak_db < (PEAK_MIN_QUIET_DB if quiet else PEAK_MIN_DB):
		problems.append("peak %.1f dB too low" % peak_db)
	if absf(sum / n) > DC_MAX:
		problems.append("DC %.4f" % (sum / n))
	var loop: bool = _field(recipe, RECIPE, "loop")
	if loop:
		var biggest := 0.0
		for i: int in range(1, n):
			biggest = maxf(biggest, absf(x[i] - x[i - 1]))
		if absf(x[0] - x[n - 1]) > biggest * 1.5:
			problems.append("loop click %.4f" % absf(x[0] - x[n - 1]))
	else:
		if absf(x[0]) > EDGE_MAX or absf(x[n - 1]) > EDGE_MAX:
			problems.append("click at an end (%.4f, %.4f)" % [x[0], x[n - 1]])
		var edge := mini(int(EDGE_SECONDS * RATE), n - 1)
		var beside := mini(int(0.02 * RATE), n - 1)
		if _max_step(x, 1, edge) > maxf(EDGE_STEP, 1.5 * _max_step(x, edge, beside)):
			problems.append("click at the start")
		if _max_step(x, n - edge, n) > maxf(EDGE_STEP, 1.5 * _max_step(x, n - beside, n - edge)):
			problems.append("click at the end")
		var run := 0
		var longest := 0
		for v: float in x:
			run = run + 1 if absf(v) < SILENT else 0
			longest = maxi(longest, run)
		# The trim leaves at most its margin silent at each end; a longer run is inside.
		if float(longest) / RATE > SILENCE_MAX:
			problems.append("silence of %.3f s" % (float(longest) / RATE))
	var low: float = Sounds.field(StringName(key), "min")
	var high: float = Sounds.field(StringName(key), "max")
	if seconds < low or seconds > high:
		problems.append("%.3f s outside %.2f-%.2f" % [seconds, low, high])
	var target: float = Sounds.field(StringName(key), "rms_db")
	if absf(window_db - target) > RMS_TOLERANCE:
		problems.append("loudness %.1f dB, target %.1f" % [window_db, target])
	return problems


## The loudest WINDOW's RMS, the windows a fifth of one apart (the whole when shorter).
static func window_rms(x: PackedFloat32Array) -> float:
	var size := mini(int(WINDOW * RATE), x.size())
	if size == 0:
		return 0.0
	var hop := maxi(size / 5, 1)
	var best := 0.0
	var at := 0
	while at + size <= x.size():
		var squares := 0.0
		for i: int in range(at, at + size):
			squares += x[i] * x[i]
		best = maxf(best, squares / size)
		at += hop
	return sqrt(best)


static func _peak(x: PackedFloat32Array) -> float:
	var top := 0.0
	for v: float in x:
		top = maxf(top, absf(v))
	return maxf(top, 1e-9)


static func _max_step(x: PackedFloat32Array, from: int, to: int) -> float:
	var biggest := 0.0
	for i: int in range(maxi(from, 1), to):
		biggest = maxf(biggest, absf(x[i] - x[i - 1]))
	return biggest


## `field` of `fields`, else of `defaults`.
static func _field(fields: Dictionary, defaults: Dictionary, field: String) -> Variant:
	return fields[field] if fields.has(field) else defaults[field]


static func _first(value: Variant) -> float:
	return float(value[0]) if typeof(value) == TYPE_ARRAY else float(value)


static func _last(value: Variant) -> float:
	return float(value[value.size() - 1]) if typeof(value) == TYPE_ARRAY else float(value)


## A biquad (the RBJ cookbook's low-pass, high-pass and band-pass with 0 dB peak), redesigned as
## its cutoff sweeps without resetting its state.
class Biquad:
	var b0 := 1.0
	var b1 := 0.0
	var b2 := 0.0
	var a1 := 0.0
	var a2 := 0.0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0

	func design(type: String, hz: float, q: float) -> void:
		var w := TAU * hz / RATE
		var c := cos(w)
		var alpha := sin(w) / (2.0 * q)
		var a0 := 1.0 + alpha
		match type:
			"hp":
				b0 = (1.0 + c) / 2.0
				b1 = -(1.0 + c)
				b2 = (1.0 + c) / 2.0
			"bp":
				b0 = alpha
				b1 = 0.0
				b2 = -alpha
			_:
				b0 = (1.0 - c) / 2.0
				b1 = 1.0 - c
				b2 = (1.0 - c) / 2.0
		b0 /= a0
		b1 /= a0
		b2 /= a0
		a1 = -2.0 * c / a0
		a2 = (1.0 - alpha) / a0

	func run(x: float) -> float:
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		return y
