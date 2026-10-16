class_name Format
extends RefCounted
## Display formatting for amounts, costs and timers.


## 12345 -> "12,345"
static func amount(value: int) -> String:
	var digits := str(absi(value))
	var grouped := ""
	while digits.length() > 3:
		grouped = "," + digits.right(3) + grouped
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + grouped


## Short, for the meters: as amount() below a million, then millions and thousand millions with
## one decimal, cut (never rounded up) and its ".0" dropped. 999999 -> "999,999",
## 1250000 -> "1.2M", 4000000 -> "4M", 12500000 -> "12.5M", 1200000000 -> "1.2B".
static func short(value: int) -> String:
	var size := absi(value)
	if size < 1000000:
		return amount(value)
	var unit := "B" if size >= 1000000000 else "M"
	var tenths := size / (100000000 if unit == "B" else 100000)
	var text := str(tenths / 10) + ("" if tenths % 10 == 0 else ".%d" % (tenths % 10))
	return ("-" if value < 0 else "") + text + unit


## 75 -> "1m 15s", 4000 -> "1h 06m"
static func duration(seconds: int) -> String:
	var total := maxi(seconds, 0)
	if total >= 3600:
		return "%dh %02dm" % [total / 3600, (total % 3600) / 60]
	if total >= 60:
		return "%dm %02ds" % [total / 60, total % 60]
	return "%ds" % total


## {"metal": 150, "crystal": 20} -> "150 Metal  20 Crystal", named from the catalog.
static func cost(costs: Dictionary, catalog: Catalog) -> String:
	if costs.is_empty():
		return "Free"
	var parts := PackedStringArray()
	for res: Variant in costs:
		parts.append("%s %s" % [amount(int(costs[res])), catalog.resource_name(str(res))])
	return "  ".join(parts)
