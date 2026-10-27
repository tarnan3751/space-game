class_name Profile
extends RefCounted
## Per-system CPU timing for the `profile` harness scenario (tools/harness/README.md): a system's
## per-frame entry point reads Time.get_ticks_usec() before its work and hands it to since() after,
## which adds the microseconds and one call under the system's key. Only while `enabled`, which
## nothing but that scenario sets: in play each site costs one static read. A run of sections in one
## function chains, each since() returning the time the next section starts from. take() hands the
## sums over and starts again.

static var enabled: bool = false
static var _usec: Dictionary[StringName, int] = {}
static var _calls: Dictionary[StringName, int] = {}


## Adds the microseconds since `started` (a Time.get_ticks_usec()) and one call under `key`; returns
## the time now, for the next section.
static func since(key: StringName, started: int) -> int:
	var now := Time.get_ticks_usec()
	var spent: int = _usec.get(key, 0)
	var calls: int = _calls.get(key, 0)
	_usec[key] = spent + now - started
	_calls[key] = calls + 1
	return now


## The sums since the last take(), per key as (microseconds, calls), and starts again.
static func take() -> Dictionary[StringName, Vector2i]:
	var sums: Dictionary[StringName, Vector2i] = {}
	for key: StringName in _usec:
		sums[key] = Vector2i(_usec[key], _calls[key])
	_usec.clear()
	_calls.clear()
	return sums
