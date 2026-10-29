class_name Audio
extends Node
## Plays the game's sounds (docs/reference/audio.md): main's child, made in code, found as
## main.audio. Every sound in Sounds.TABLE is loaded once at boot from assets/audio/sfx/<key>.wav
## (rendered by tools/gen_sounds.gd) and played by its key through a pool of VOICES players on
## the buses it adds (SFX, UI and Music, each into Master, which a limiter keeps from clipping).
##
## A play is dropped while its key's cooldown runs; a key already sounding on its `voices` reuses
## its oldest; with every voice busy it takes the least important, oldest one-shot no more
## important than itself, or is dropped. schedule() plays a key later (a burst's later shots, a
## trap's pop), loop() holds a looping sound until stop(), music() crossfades between two tracks
## on Music and sting() plays a fanfare there, ducking the music under it. The volumes of the
## buses and the mute are the player's settings (the HUD's settings panel), kept in a ConfigFile
## at settings_path (not in the save).
##
## A play allocates nothing: the players are made at boot and the tables filled then. Plays are
## recorded whatever the device (a headless run's dummy driver plays too), for the harness:
## recent_plays(), recent_times(), play_count(), playing_count().

const VOICES := 24
## How many plays recent_plays() remembers, and how many schedule() holds at once.
const RECENT := 32
const SCHEDULED := 64
const SFX_DIR := "res://assets/audio/sfx"
## Music tracks, loaded by path when music() asks for one: <key>.ogg, else <key>.mp3.
const MUSIC_DIR := "res://assets/audio/music"
const DEFAULT_SETTINGS_PATH := "user://settings.cfg"
const SETTINGS_SECTION := "volume"
## Where the Master volume a mute took away is kept, to bring back on unmute.
const MUTE_SECTION := "mute"
## The buses added under Master, and the limiter's ceiling on Master (dBFS).
const BUSES: Array[StringName] = [&"SFX", &"UI", &"Music"]
const LIMIT_DB := -0.3
## How far a sting ducks the music (dB), and how fast it goes down and comes back (seconds).
const DUCK_DB := -8.0
const DUCK_DOWN := 0.1
const DUCK_UP := 0.5
## A button tap's pitch variation (Hud._button, SectorMap._button, tap_buttons).
const TAP_JITTER := 0.03

## Where the volumes are kept; main points it beside the save when the run has its own.
var settings_path := DEFAULT_SETTINGS_PATH
## The Master volume an unmute brings back (set_muted).
var _unmuted := 1.0

var _streams: Dictionary[StringName, AudioStreamWAV] = {}
var _bus: Dictionary[StringName, StringName] = {}
var _priority: Dictionary[StringName, int] = {}
var _cooldown_ms: Dictionary[StringName, int] = {}
var _max_voices: Dictionary[StringName, int] = {}
var _last_ms: Dictionary[StringName, int] = {}
var _counts: Dictionary[StringName, int] = {}
## The pool: each voice's player, the key it last played, when (ms) and its loop's id (0 a one-shot).
var _voices: Array[AudioStreamPlayer] = []
var _voice_key: Array[StringName] = []
var _voice_started := PackedInt64Array()
var _voice_loop := PackedInt32Array()
## Each voice's running fade (a loop's in or out), killed when the voice is taken again.
var _voice_tweens: Array[Tween] = []
var _next_loop := 0
## The last RECENT plays, a ring from _recent_head.
var _recent: Array[StringName] = []
var _recent_ms := PackedInt64Array()
var _recent_head := 0
var _recent_count := 0
## Scheduled plays, a ring in the order they were asked for, _due_count of them from _due_head.
var _due_key: Array[StringName] = []
var _due_ms := PackedInt64Array()
var _due_jitter := PackedFloat32Array()
var _due_db := PackedFloat32Array()
var _due_head := 0
var _due_count := 0
var _due_warned := false
## The two music players, which is current, its key, each one's crossfade level, and the duck.
var _music: Array[AudioStreamPlayer] = []
var _music_current := 0
var _music_key: StringName = &""
var _fade := PackedFloat32Array([0.0, 0.0])
var _fade_tweens: Array[Tween] = [null, null]
var _duck := 1.0
var _duck_tween: Tween
var _sting: AudioStreamPlayer
var _rng := RandomNumberGenerator.new()
## Set by shut_down(): the game is quitting, and nothing starts again.
var _shut := false


func _ready() -> void:
	_make_buses()
	for name: String in Sounds.TABLE:
		var key := StringName(name)
		var stream := load("%s/%s.wav" % [SFX_DIR, name]) as AudioStreamWAV
		if stream == null:
			push_error("Audio: no sound file for %s (run tools/gen_sounds.gd)" % name)
			continue
		_streams[key] = stream
		_bus[key] = Sounds.field(key, "bus")
		_priority[key] = Sounds.field(key, "priority")
		_cooldown_ms[key] = roundi(float(Sounds.field(key, "cooldown")) * 1000.0)
		_max_voices[key] = Sounds.TABLE[name].get("voices", 4)
		_last_ms[key] = -1000000
		_counts[key] = 0
	for i: int in VOICES:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_voices.append(player)
		_voice_key.append(&"")
	_voice_started.resize(VOICES)
	_voice_loop.resize(VOICES)
	_voice_tweens.resize(VOICES)
	_recent.resize(RECENT)
	_recent_ms.resize(RECENT)
	_due_key.resize(SCHEDULED)
	_due_ms.resize(SCHEDULED)
	_due_jitter.resize(SCHEDULED)
	_due_db.resize(SCHEDULED)
	for i: int in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.volume_linear = 0.0
		add_child(player)
		_music.append(player)
	_sting = AudioStreamPlayer.new()
	_sting.bus = &"Music"
	add_child(_sting)
	_load_settings()
	set_process(false)


## Plays `key` once, its pitch varied up to `pitch_jitter` either way, `volume_db` louder or
## softer: whether it played (not dropped by its cooldown or a full pool). &"" (a silent entry of
## Sounds' maps) plays nothing.
func play(key: StringName, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> bool:
	if _shut or key == &"":
		return false
	var started := Time.get_ticks_usec() if Profile.enabled else 0
	var played := _play(key, pitch_jitter, volume_db)
	if Profile.enabled:
		Profile.since(&"audio", started)
	return played


## Plays `key` `delay_seconds` from now, through play() then. With SCHEDULED waiting, the oldest
## is dropped.
func schedule(key: StringName, delay_seconds: float, pitch_jitter: float = 0.06, volume_db: float = 0.0) -> void:
	if _shut:
		return
	if _due_count == SCHEDULED:
		if not _due_warned:
			_due_warned = true
			push_warning("Audio: more than %d plays scheduled; dropping the oldest" % SCHEDULED)
		_due_head = (_due_head + 1) % SCHEDULED
		_due_count -= 1
	var at := (_due_head + _due_count) % SCHEDULED
	_due_key[at] = key
	_due_ms[at] = Time.get_ticks_msec() + roundi(delay_seconds * 1000.0)
	_due_jitter[at] = pitch_jitter
	_due_db[at] = volume_db
	_due_count += 1
	set_process(true)


## Starts `key` looping, fading in over `fade` seconds: an id for stop(), 0 when it could not.
func loop(key: StringName, fade: float = 0.15) -> int:
	if _shut:
		return 0
	if not _streams.has(key):
		push_error("Audio: no sound %s" % key)
		return 0
	var voice := _pick(key, Time.get_ticks_msec())
	if voice < 0:
		return 0
	_next_loop += 1
	_start(voice, key, 0.0, 0.0)
	_voice_loop[voice] = _next_loop
	var player := _voices[voice]
	player.volume_linear = 0.0
	_voice_tweens[voice] = create_tween()
	_voice_tweens[voice].tween_property(player, ^"volume_linear", 1.0, fade)
	return _next_loop


## Fades loop `id` out over `fade` seconds and frees its voice.
func stop(id: int, fade: float = 0.15) -> void:
	var voice := _voice_loop.find(id)
	if id == 0 or voice < 0:
		return
	_kill_fade(voice)
	var tween := create_tween()
	tween.tween_property(_voices[voice], ^"volume_linear", 0.0, fade)
	tween.tween_callback(_end_loop.bind(voice, id))
	_voice_tweens[voice] = tween


## Fades loop `id` to `db` (0 its full level) over `fade` seconds, its fade-in included: a bed
## ducked under a panel and brought back.
func set_loop_volume(id: int, db: float, fade: float = 0.15) -> void:
	var voice := _voice_loop.find(id)
	if id == 0 or voice < 0:
		return
	_kill_fade(voice)
	_voice_tweens[voice] = create_tween()
	_voice_tweens[voice].tween_property(_voices[voice], ^"volume_linear", db_to_linear(db), fade)


## Crossfades the music to track `key` over `fade` seconds; &"" fades it out. False when the
## track has no file.
func music(key: StringName, fade: float = 1.0) -> bool:
	if _shut:
		return false
	if key == _music_key:
		return true
	var stream: AudioStream = null
	if key != &"":
		for extension: String in ["ogg", "mp3"]:
			var path := "%s/%s.%s" % [MUSIC_DIR, key, extension]
			if ResourceLoader.exists(path):
				stream = load(path)
				break
		if stream == null:
			push_warning("Audio: no music track %s" % key)
			return false
	_fade_to(_music_current, 0.0, fade, true)
	_music_key = key
	if stream != null:
		_music_current = 1 - _music_current
		var player := _music[_music_current]
		player.stream = stream
		_set_fade(0.0, _music_current)
		player.play()
		_fade_to(_music_current, 1.0, fade, false)
	return true


## The music track playing (or fading in), &"" for none.
func current_music() -> StringName:
	return _music_key


## Whether the current track's player is playing (for the harness).
func music_playing() -> bool:
	return _music_key != &"" and _music[_music_current].playing


## Plays the fanfare `key` on Music, the music ducked under it: whether it played.
func sting(key: StringName) -> bool:
	if _shut:
		return false
	if not _streams.has(key):
		push_error("Audio: no sound %s" % key)
		return false
	var now := Time.get_ticks_msec()
	if now - _last_ms[key] < _cooldown_ms[key]:
		return false
	_sting.stream = _streams[key]
	_sting.play()
	_record(key, now)
	if _duck_tween != null:
		_duck_tween.kill()
	_duck_tween = create_tween()
	_duck_tween.tween_method(_set_duck, _duck, db_to_linear(DUCK_DB), DUCK_DOWN)
	_duck_tween.tween_interval(maxf(_streams[key].get_length() - DUCK_DOWN, 0.0))
	_duck_tween.tween_method(_set_duck, db_to_linear(DUCK_DB), 1.0, DUCK_UP)
	return true


## Sets bus `bus`'s volume (0 to 1; 0 mutes it) and, with `keep`, keeps it in the settings: a
## slider being dragged sets it without, and keeps it when let go.
func set_volume(bus: StringName, linear: float, keep: bool = true) -> void:
	_apply_volume(bus, linear)
	if keep:
		_keep(SETTINGS_SECTION, String(bus), linear)


## Bus `bus`'s volume, 0 to 1.
func volume(bus: StringName) -> float:
	return AudioServer.get_bus_volume_linear(AudioServer.get_bus_index(bus))


## Mutes every sound (Master to 0), keeping the volume Master had to bring back on unmute; both
## kept in the settings, so a mute outlasts the run.
func set_muted(on: bool) -> void:
	if on == is_muted():
		return
	if on:
		_unmuted = volume(&"Master")
		_keep(MUTE_SECTION, "Master", _unmuted)
	set_volume(&"Master", 0.0 if on else _unmuted)


func is_muted() -> bool:
	return volume(&"Master") <= 0.0


## Every button under `root` plays ui_tap when pressed, once however often it is asked: the attack
## HUD's, a stopgap until its button helper plays the tap itself as the base HUD's and the sector
## map's do (audio.md, **Hooks**).
func tap_buttons(root: Node) -> void:
	for node: Node in root.find_children("*", "BaseButton", true, false):
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_tap):
			button.pressed.connect(_on_tap)


## The last RECENT keys played, oldest first, and when (Time.get_ticks_msec()).
func recent_plays() -> Array[StringName]:
	var keys: Array[StringName] = []
	for i: int in _recent_count:
		keys.append(_recent[(_recent_head + i) % RECENT])
	return keys


func recent_times() -> PackedInt64Array:
	var times := PackedInt64Array()
	for i: int in _recent_count:
		times.append(_recent_ms[(_recent_head + i) % RECENT])
	return times


## How many times `key` has played since boot.
func play_count(key: StringName) -> int:
	return _counts.get(key, 0)


## Loop `id`'s level now, 0 to 1 (its fade or its duck under way), -1 when it is not sounding.
func loop_level(id: int) -> float:
	var voice := _voice_loop.find(id)
	if id == 0 or voice < 0:
		return -1.0
	return _voices[voice].volume_linear


## How many plays are scheduled and waiting.
func scheduled_count() -> int:
	return _due_count


## How many of the pool's voices are sounding.
func playing_count() -> int:
	var count := 0
	for player: AudioStreamPlayer in _voices:
		if player.playing:
			count += 1
	return count


## Every key in the table.
func keys() -> Array[StringName]:
	var all: Array[StringName] = []
	for key: StringName in _streams:
		all.append(key)
	return all


## `key`'s stream, null for none.
func stream(key: StringName) -> AudioStreamWAV:
	return _streams.get(key, null)


## Drops every scheduled play still waiting (a battle over: nothing it dated later may sound after
## it); what is sounding plays on.
func drop_scheduled() -> void:
	_due_count = 0
	set_process(false)


## Stops every sound at once (loops, music and stings too) and drops the scheduled plays. The
## mixer lets go of what was playing a mix later, so a run that quits waits a moment after this
## (the harness driver does), or the engine reports the playing sounds as leaked.
func silence() -> void:
	for i: int in VOICES:
		_kill_fade(i)
		_voices[i].stop()
		_voice_loop[i] = 0
	for i: int in 2:
		if _fade_tweens[i] != null:
			_fade_tweens[i].kill()
			_fade_tweens[i] = null
		_music[i].stop()
		_fade[i] = 0.0
	_music_key = &""
	if _duck_tween != null:
		_duck_tween.kill()
		_duck_tween = null
	_duck = 1.0
	_sting.stop()
	_due_count = 0
	set_process(false)


## silence() for good, before a quit: from now on play, schedule, loop, music and sting do
## nothing, so no sound starts in the frames the quit waits for the mixer to let go.
func shut_down() -> void:
	silence()
	_shut = true


func _exit_tree() -> void:
	silence()


## The scheduled plays that are due, played and retired, the ones still waiting closed up behind
## the head in their order; off when none are waiting.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	var kept := 0
	for i: int in _due_count:
		var at := (_due_head + i) % SCHEDULED
		if _due_ms[at] <= now:
			play(_due_key[at], _due_jitter[at], _due_db[at])
			continue
		var to := (_due_head + kept) % SCHEDULED
		_due_key[to] = _due_key[at]
		_due_ms[to] = _due_ms[at]
		_due_jitter[to] = _due_jitter[at]
		_due_db[to] = _due_db[at]
		kept += 1
	_due_count = kept
	if _due_count == 0:
		set_process(false)


## A phone sending the game to the background silences it until it comes back.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		AudioServer.set_bus_mute(0, true)
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		AudioServer.set_bus_mute(0, volume(&"Master") <= 0.0)


func _play(key: StringName, pitch_jitter: float, volume_db: float) -> bool:
	if not _streams.has(key):
		push_error("Audio: no sound %s" % key)
		return false
	var now := Time.get_ticks_msec()
	if now - _last_ms[key] < _cooldown_ms[key]:
		return false
	var voice := _pick(key, now)
	if voice < 0:
		return false
	_start(voice, key, pitch_jitter, volume_db)
	_record(key, now)
	return true


## The voice `key` plays on at `now` (ms): its own oldest when it already has its `voices`; a free
## one; else the least important, oldest one-shot no more important than it. -1 when none.
func _pick(key: StringName, now: int) -> int:
	var own := 0
	var own_oldest := -1
	var free := -1
	var steal := -1
	var priority: int = _priority[key]
	for i: int in VOICES:
		if _voice_loop[i] != 0:
			continue
		if not _voices[i].playing:
			if free < 0:
				free = i
			continue
		if _voice_key[i] == key:
			own += 1
			if own_oldest < 0 or _voice_started[i] < _voice_started[own_oldest]:
				own_oldest = i
		var rank: int = _priority[_voice_key[i]]
		if rank <= priority and (steal < 0 or rank < _priority[_voice_key[steal]]
				or (rank == _priority[_voice_key[steal]] and _voice_started[i] < _voice_started[steal])):
			steal = i
	if own >= _max_voices[key]:
		return own_oldest
	return free if free >= 0 else steal


func _start(voice: int, key: StringName, pitch_jitter: float, volume_db: float) -> void:
	_kill_fade(voice)
	var player := _voices[voice]
	player.stop()
	player.stream = _streams[key]
	player.bus = _bus[key]
	player.pitch_scale = 1.0 + _rng.randf_range(-pitch_jitter, pitch_jitter) if pitch_jitter > 0.0 else 1.0
	player.volume_db = volume_db
	player.play()
	_voice_key[voice] = key
	_voice_started[voice] = Time.get_ticks_msec()


func _kill_fade(voice: int) -> void:
	if _voice_tweens[voice] != null:
		_voice_tweens[voice].kill()
		_voice_tweens[voice] = null


func _record(key: StringName, now: int) -> void:
	_last_ms[key] = now
	_counts[key] += 1
	var at := (_recent_head + _recent_count) % RECENT
	_recent[at] = key
	_recent_ms[at] = now
	if _recent_count < RECENT:
		_recent_count += 1
	else:
		_recent_head = (_recent_head + 1) % RECENT


func _end_loop(voice: int, id: int) -> void:
	if _voice_loop[voice] != id:
		return
	_voices[voice].stop()
	_voice_loop[voice] = 0


func _on_tap() -> void:
	play(&"ui_tap", TAP_JITTER)


func _fade_to(index: int, level: float, seconds: float, stop_after: bool) -> void:
	if _fade_tweens[index] != null:
		_fade_tweens[index].kill()
	var tween := create_tween()
	tween.tween_method(_set_fade.bind(index), _fade[index], level, seconds)
	if stop_after:
		tween.tween_callback(_music[index].stop)
	_fade_tweens[index] = tween


func _set_fade(level: float, index: int) -> void:
	_fade[index] = level
	_music[index].volume_linear = level * _duck


func _set_duck(level: float) -> void:
	_duck = level
	for i: int in 2:
		_music[i].volume_linear = _fade[i] * _duck


func _apply_volume(bus: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		push_warning("Audio: no bus %s" % bus)
		return
	AudioServer.set_bus_volume_linear(index, linear)
	AudioServer.set_bus_mute(index, linear <= 0.0)


func _keep(section: String, key: String, value: float) -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value(section, key, value)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Audio: could not save %s: %s" % [settings_path, error_string(error)])


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(settings_path) != OK:
		return
	_unmuted = config.get_value(MUTE_SECTION, "Master", 1.0)
	if not config.has_section(SETTINGS_SECTION):
		return
	for bus: String in config.get_section_keys(SETTINGS_SECTION):
		var linear: float = config.get_value(SETTINGS_SECTION, bus, 1.0)
		_apply_volume(StringName(bus), linear)


## SFX, UI and Music into Master, added once; a hard limiter on Master.
func _make_buses() -> void:
	for bus: StringName in BUSES:
		if AudioServer.get_bus_index(bus) >= 0:
			continue
		AudioServer.add_bus()
		var index := AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, bus)
		AudioServer.set_bus_send(index, &"Master")
	for i: int in AudioServer.get_bus_effect_count(0):
		if AudioServer.get_bus_effect(0, i) is AudioEffectHardLimiter:
			return
	var limiter := AudioEffectHardLimiter.new()
	limiter.ceiling_db = LIMIT_DB
	AudioServer.add_bus_effect(0, limiter)
