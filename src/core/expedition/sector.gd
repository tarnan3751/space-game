class_name Sector
extends RefCounted
## A base's sector (docs/reference/expeditions.md): the fields an expedition can raid. Pure logic,
## like all of src/core: no clock, integers only.
##
## The fields are derived, never stored: field `index` of `epoch` is laid out by OutpostGenerator
## from field_seed(index), with the band rules.expedition gives the index, against the player's
## Command Center level and storage capacity as they were at the epoch's scan (`cc`, `capacity`),
## so a field stays the same however the base grows until the next scan, and the server can lay it
## out again from the save. A field is raided once an epoch: a raid with a star clears it. A scan
## starts the next epoch: new fields, none cleared.

## Mixed with the base's creation time into its sector seed, and with each field's inputs.
const SEED_SALT := 0x5EC7012D
const FIELD_SALT := 0x0F1E1D50

var sector_seed: int = 0
## The scans so far; 0 before the first, which is free of the cooldown.
var epoch: int = 0
## The field indices cleared this epoch, sorted.
var cleared: PackedInt32Array = PackedInt32Array()
## Unix time of the last scan; meaningful once epoch > 0.
var last_scan: int = 0
## The player's Command Center level and storage capacity at the epoch's scan.
var cc: int = 1
var capacity: Dictionary[String, int] = {}


## The sector seed of a base created (or first loaded with no sector) at unix time `time`.
static func seed_from_time(time: int) -> int:
	return mix(SEED_SALT, time)


## One 32-bit FNV-1a step per half of `value`: the arithmetic of BattleSim's hash, so every
## device gives the same seeds.
static func mix(h: int, value: int) -> int:
	h = ((h ^ (value & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF
	return ((h ^ ((value >> 32) & 0xFFFFFFFF)) * 16777619) & 0xFFFFFFFF


## The seed of one field: the outpost generator's and its battle's.
static func field_seed_of(sector_seed_value: int, epoch_value: int, index: int) -> int:
	return mix(mix(mix(FIELD_SALT, sector_seed_value), epoch_value), index)


func field_seed(index: int) -> int:
	return field_seed_of(sector_seed, epoch, index)


func is_cleared(index: int) -> bool:
	return cleared.has(index)


## Marks a field cleared, keeping the list sorted.
func clear_field(index: int) -> void:
	if cleared.has(index):
		return
	cleared.append(index)
	cleared.sort()


## Records the base the epoch's fields are laid out against.
func snapshot(cc_level: int, capacities: Dictionary[String, int]) -> void:
	cc = cc_level
	capacity = capacities.duplicate()


func to_dict() -> Dictionary:
	var cleared_list := []
	for index: int in cleared:
		cleared_list.append(index)
	var capacity_data := {}
	for res: String in capacity:
		capacity_data[res] = capacity[res]
	return {"seed": sector_seed, "epoch": epoch, "cleared": cleared_list, "last_scan": last_scan,
		"cc": cc, "capacity": capacity_data}


## A sector from to_dict() output (JSON-parsed numbers included), cleaned against the catalog and
## the base's `now`: the level clamped into the Command Center's, cleared entries kept only when
## they are whole field indices, once each and sorted, capacity only for the catalog's resources
## (0 when missing), and the last scan no later than `now`, so a clock set back costs at most one
## cooldown.
static func from_dict(catalog: Catalog, data: Dictionary, now: int) -> Sector:
	var sector := Sector.new()
	sector.sector_seed = int(data.get("seed", 0))
	sector.epoch = maxi(0, int(data.get("epoch", 0)))
	sector.last_scan = mini(int(data.get("last_scan", 0)), now)
	sector.cc = clampi(int(data.get("cc", 1)), 1, maxi(1, catalog.max_cc_level()))
	var cleared_data: Variant = data.get("cleared", [])
	if typeof(cleared_data) == TYPE_ARRAY:
		for value: Variant in cleared_data:
			var index := BattleMath.whole(value)
			if index >= 0 and index < catalog.expedition_field_count():
				sector.clear_field(index)
	var capacity_data: Variant = data.get("capacity", {})
	var capacity_dict: Dictionary = capacity_data if typeof(capacity_data) == TYPE_DICTIONARY else {}
	for res: String in catalog.resources:
		sector.capacity[res] = maxi(0, int(capacity_dict.get(res, 0)))
	return sector
